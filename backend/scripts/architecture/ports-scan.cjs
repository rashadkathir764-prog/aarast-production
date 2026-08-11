'use strict';

const fs = require('node:fs');
const path = require('node:path');
const ts = require('typescript');

const R0_GLOBAL_MODULES = new Set([
  'backend/src/prisma/prisma.module.ts',
  'backend/src/conversations/conversation-realtime.module.ts',
]);

const BUSINESS_CONTEXTS = new Map([
  ['identity', ['auth', 'users', 'me', 'contexts']],
  ['planning', ['wedding-plans', 'onboarding']],
  ['finance', ['money', 'budget-categories', 'wedding-costs']],
  ['collaboration', ['sharing', 'contribution-history']],
  ['tasks', ['tasks']],
  ['guests', ['guests']],
  ['marketplace', ['marketplace', 'provider-dashboard']],
  ['messaging', ['conversations']],
  ['notifications', ['notifications', 'push']],
  ['catalog', ['catalogs']],
  ['media', ['media']],
  ['insights', ['dashboard', 'timeline']],
  ['backoffice', ['admin']],
]);
const LEGACY_ROOT_TO_CONTEXT = new Map(
  [...BUSINESS_CONTEXTS].flatMap(([context, roots]) => roots.map((root) => [root, context])),
);
const LEGACY_PLATFORM_ROOTS = new Set(['common', 'prisma', 'outbox', 'health']);
const ILLEGAL_IMPORT_KINDS = new Set([
  'non-public-cross-module-import',
  'domain-runtime-import',
  'platform-business-import',
  'shared-kernel-direction-import',
]);

function normalizeFsPath(file) {
  return path.resolve(file).replace(/\\/g, '/');
}

function toRepositoryPath(file, repoRoot) {
  const relative = path.relative(repoRoot, file);
  if (
    !relative
    || path.isAbsolute(relative)
    || relative === '..'
    || relative.startsWith(`..${path.sep}`)
  ) {
    throw new Error('architecture path is outside the repository');
  }
  return relative.split(path.sep).join('/');
}

function repositoryPathOrNull(file, repoRoot) {
  try {
    return toRepositoryPath(file, repoRoot);
  } catch {
    return null;
  }
}

function createProgram(backendRoot) {
  const configPath = path.join(backendRoot, 'tsconfig.json');
  const config = ts.readConfigFile(configPath, ts.sys.readFile);
  if (config.error) throw new Error('backend tsconfig cannot be read');
  const parsed = ts.parseJsonConfigFileContent(config.config, ts.sys, backendRoot, undefined, configPath);
  if (parsed.errors.length > 0) throw new Error('backend tsconfig cannot be parsed');
  if (parsed.fileNames.length === 0) throw new Error('backend TypeScript program has no source files');
  const program = ts.createProgram({ rootNames: parsed.fileNames, options: parsed.options });
  if (program.getOptionsDiagnostics().length > 0) {
    throw new Error('backend TypeScript program options are invalid');
  }
  if (program.getSyntacticDiagnostics().length > 0) {
    throw new Error('backend TypeScript program has syntax errors');
  }
  return { program, checker: program.getTypeChecker() };
}

function compareText(left, right) {
  return left < right ? -1 : left > right ? 1 : 0;
}

function sourceFiles(program, repoRoot) {
  return program.getSourceFiles()
    .map((sourceFile) => ({
      sourceFile,
      repositoryPath: repositoryPathOrNull(sourceFile.fileName, repoRoot),
    }))
    .filter(({ repositoryPath }) => (
      repositoryPath
      && /^backend\/src\/.+\.ts$/.test(repositoryPath)
      && !repositoryPath.endsWith('.d.ts')
    ))
    .sort((left, right) => compareText(left.repositoryPath, right.repositoryPath));
}

function resolveAlias(symbol, checker) {
  let current = symbol || null;
  const seen = new Set();
  while (current && (current.flags & ts.SymbolFlags.Alias) && !seen.has(current)) {
    seen.add(current);
    const resolved = checker.getAliasedSymbol(current);
    if (!resolved || resolved === current) break;
    current = resolved;
  }
  return current;
}

function symbolAtExpression(expression, checker) {
  if (ts.isPropertyAccessExpression(expression)) {
    return resolveAlias(checker.getSymbolAtLocation(expression.name), checker);
  }
  return resolveAlias(checker.getSymbolAtLocation(expression), checker);
}

function declarationComesFromPackage(declaration, packageName) {
  const file = normalizeFsPath(declaration.getSourceFile().fileName).toLowerCase();
  const packagePath = `/node_modules/${packageName.toLowerCase()}/`;
  return file.includes(packagePath);
}

function isNestCommonSymbol(expression, expectedName, checker) {
  const symbol = symbolAtExpression(expression, checker);
  return Boolean(
    symbol
    && symbol.getName() === expectedName
    && (symbol.declarations || []).some((declaration) => (
      declarationComesFromPackage(declaration, '@nestjs/common')
    )),
  );
}

function decoratorsOf(node) {
  return ts.canHaveDecorators(node) ? (ts.getDecorators(node) || []) : [];
}

function matchingDecoratorCall(node, expectedName, checker) {
  for (const decorator of decoratorsOf(node)) {
    if (
      ts.isCallExpression(decorator.expression)
      && isNestCommonSymbol(decorator.expression.expression, expectedName, checker)
    ) {
      return decorator.expression;
    }
  }
  return null;
}

function lineOf(sourceFile, node) {
  return sourceFile.getLineAndCharacterOfPosition(node.getStart(sourceFile)).line + 1;
}

function diagnostic(kind, repositoryPath, sourceFile, node, message, extra = {}) {
  return {
    kind,
    path: repositoryPath,
    line: node ? lineOf(sourceFile, node) : 1,
    message,
    ...extra,
  };
}

function classifyRepositoryPath(repositoryPath) {
  if (!repositoryPath.startsWith('backend/src/')) return { kind: 'external' };
  const segments = repositoryPath.slice('backend/src/'.length).split('/');
  if (segments[0] === 'modules') {
    const context = segments[1];
    if (!BUSINESS_CONTEXTS.has(context)) return { kind: 'unclassified', future: true };
    return {
      kind: 'business',
      context,
      future: true,
      slice: segments[2] || null,
      public: segments[2] === 'public',
      internal: segments[2] === 'internal',
      domain: segments[2] === 'domain',
    };
  }
  if (segments[0] === 'platform') return { kind: 'platform', future: true };
  if (segments[0] === 'shared-kernel') return { kind: 'shared-kernel', future: true };
  if (LEGACY_PLATFORM_ROOTS.has(segments[0])) return { kind: 'platform', future: false };
  const context = LEGACY_ROOT_TO_CONTEXT.get(segments[0]);
  if (context) return { kind: 'business', context, future: false, public: false };
  return { kind: 'unclassified', future: false };
}

function resolveModuleFile(moduleSpecifier, sourceFile, compilerOptions) {
  const resolved = ts.resolveModuleName(
    moduleSpecifier,
    sourceFile.fileName,
    compilerOptions,
    ts.sys,
  ).resolvedModule;
  return resolved ? resolved.resolvedFileName : null;
}

function declarationHasForbiddenDomainRuntime(declaration, symbol) {
  const file = normalizeFsPath(declaration.getSourceFile().fileName).toLowerCase();
  if (file.includes('/node_modules/@nestjs/')) return true;
  if (!file.endsWith('/src/prisma/prisma.service.ts')) return false;
  return symbol.getName() === 'PrismaService'
    || Boolean(declaration.name && declaration.name.getText() === 'PrismaService');
}

function compareSymbols(left, right) {
  const nameOrder = compareText(left.getName(), right.getName());
  if (nameOrder) return nameOrder;
  const leftPath = (left.declarations || [])[0]
    ? normalizeFsPath(left.declarations[0].getSourceFile().fileName)
    : '';
  const rightPath = (right.declarations || [])[0]
    ? normalizeFsPath(right.declarations[0].getSourceFile().fileName)
    : '';
  return compareText(leftPath, rightPath);
}

function symbolHasForbiddenDomainRuntime(symbol, checker, seenSymbols = new Set()) {
  const resolved = resolveAlias(symbol, checker);
  if (!resolved || seenSymbols.has(resolved)) return false;
  seenSymbols.add(resolved);
  if ((resolved.declarations || []).some((declaration) => (
    declarationHasForbiddenDomainRuntime(declaration, resolved)
  ))) return true;
  if (!(resolved.flags & ts.SymbolFlags.Module)) return false;
  const exports = checker.getExportsOfModule(resolved);
  return [...exports]
    .sort(compareSymbols)
    .some((exported) => symbolHasForbiddenDomainRuntime(exported, checker, seenSymbols));
}

function importTargetsForbiddenDomainRuntime(node, checker, specifier) {
  if (specifier.startsWith('@nestjs/')) return true;
  const candidates = [];
  if (ts.isImportDeclaration(node)) {
    const clause = node.importClause;
    if (!clause) {
      candidates.push(checker.getSymbolAtLocation(node.moduleSpecifier));
    } else {
      if (clause.name) candidates.push(checker.getSymbolAtLocation(clause.name));
      const bindings = clause.namedBindings;
      if (bindings && ts.isNamedImports(bindings)) {
        for (const element of bindings.elements) {
          candidates.push(checker.getSymbolAtLocation(element.name));
        }
      } else if (bindings && ts.isNamespaceImport(bindings)) {
        candidates.push(checker.getSymbolAtLocation(bindings.name));
      }
    }
  } else if (ts.isExportDeclaration(node)) {
    const clause = node.exportClause;
    if (!clause) {
      candidates.push(checker.getSymbolAtLocation(node.moduleSpecifier));
    } else if (ts.isNamedExports(clause)) {
      for (const element of clause.elements) {
        candidates.push(checker.getSymbolAtLocation(element.name));
      }
    } else if (ts.isNamespaceExport(clause)) {
      candidates.push(checker.getSymbolAtLocation(clause.name));
    }
  }
  return candidates.some((candidate) => (
    symbolHasForbiddenDomainRuntime(candidate, checker)
  ));
}

function collectImportDiagnostics(files, program, checker, repoRoot) {
  const diagnostics = [];
  const compilerOptions = program.getCompilerOptions();
  for (const { sourceFile, repositoryPath } of files) {
    const source = classifyRepositoryPath(repositoryPath);
    for (const statement of sourceFile.statements) {
      if (
        !(ts.isImportDeclaration(statement) || ts.isExportDeclaration(statement))
        || !statement.moduleSpecifier
        || !ts.isStringLiteralLike(statement.moduleSpecifier)
      ) continue;
      const specifier = statement.moduleSpecifier.text;
      const targetFile = resolveModuleFile(specifier, sourceFile, compilerOptions);
      const targetPath = targetFile ? repositoryPathOrNull(targetFile, repoRoot) : null;
      const target = targetPath ? classifyRepositoryPath(targetPath) : { kind: 'external' };

      if (source.kind === 'business' && source.future && source.domain) {
        if (
          importTargetsForbiddenDomainRuntime(statement, checker, specifier)
          || (target.kind === 'business' && target.context !== source.context)
        ) {
          diagnostics.push(diagnostic(
            'domain-runtime-import',
            repositoryPath,
            sourceFile,
            statement,
            `domain code cannot import runtime or foreign module '${specifier}'`,
          ));
          continue;
        }
      }

      if (
        source.kind === 'shared-kernel'
        && (target.kind === 'platform' || target.kind === 'business')
      ) {
        diagnostics.push(diagnostic(
          'shared-kernel-direction-import',
          repositoryPath,
          sourceFile,
          statement,
          `shared-kernel cannot import '${targetPath}'`,
        ));
        continue;
      }

      if (
        source.kind === 'platform'
        && target.kind === 'business'
        && (source.future || target.future)
      ) {
        diagnostics.push(diagnostic(
          'platform-business-import',
          repositoryPath,
          sourceFile,
          statement,
          `platform cannot import business module '${targetPath}'`,
        ));
        continue;
      }

      if (
        source.kind === 'business'
        && target.kind === 'business'
        && source.context !== target.context
        && (source.future || target.future)
        && !(target.future && target.public)
      ) {
        diagnostics.push(diagnostic(
          'non-public-cross-module-import',
          repositoryPath,
          sourceFile,
          statement,
          `cross-context imports must target the owner's public slice: '${targetPath}'`,
        ));
        continue;
      }

      if (
        target.kind === 'business'
        && target.future
        && target.internal
        && !(source.kind === 'business' && source.context === target.context)
      ) {
        diagnostics.push(diagnostic(
          'non-public-cross-module-import',
          repositoryPath,
          sourceFile,
          statement,
          `another module's internal slice is private: '${targetPath}'`,
        ));
      }
    }
  }
  return diagnostics;
}

function unwrapExpression(expression) {
  let current = expression;
  while (
    ts.isParenthesizedExpression(current)
    || ts.isAsExpression(current)
    || ts.isTypeAssertionExpression(current)
    || ts.isNonNullExpression(current)
    || (ts.isSatisfiesExpression && ts.isSatisfiesExpression(current))
  ) {
    current = current.expression;
  }
  return current;
}

function isConstVariableDeclaration(declaration) {
  return ts.isVariableDeclaration(declaration)
    && ts.isVariableDeclarationList(declaration.parent)
    && Boolean(declaration.parent.flags & ts.NodeFlags.Const);
}

function declarationIsExternal(declaration) {
  return normalizeFsPath(declaration.getSourceFile().fileName).toLowerCase().includes('/node_modules/');
}

function findModuleForSymbol(symbol, checker, moduleByDeclaration) {
  const resolved = resolveAlias(symbol, checker);
  if (!resolved) return null;
  for (const declaration of resolved.declarations || []) {
    if (moduleByDeclaration.has(declaration)) return moduleByDeclaration.get(declaration);
  }
  return null;
}

function resolveExpressionTarget(expression, checker, moduleByDeclaration, seen = new Set()) {
  const current = unwrapExpression(expression);
  const symbol = symbolAtExpression(current, checker);
  const moduleInfo = findModuleForSymbol(symbol, checker, moduleByDeclaration);
  if (moduleInfo) return { kind: 'internal', moduleInfo };
  const resolved = resolveAlias(symbol, checker);
  if (resolved && (resolved.declarations || []).some(declarationIsExternal)) {
    return { kind: 'external' };
  }
  if (resolved && !seen.has(resolved)) {
    seen.add(resolved);
    const declarations = resolved.declarations || [];
    if (declarations.length === 1 && isConstVariableDeclaration(declarations[0]) && declarations[0].initializer) {
      return resolveExpressionTarget(
        declarations[0].initializer,
        checker,
        moduleByDeclaration,
        seen,
      );
    }
  }
  return { kind: 'unresolved' };
}

function propertyNameText(name) {
  if (ts.isIdentifier(name) || ts.isStringLiteralLike(name)) return name.text;
  return null;
}

function collectModuleGraph(files, checker) {
  const modules = [];
  const moduleByDeclaration = new Map();
  for (const { sourceFile, repositoryPath } of files) {
    for (const statement of sourceFile.statements) {
      if (!ts.isClassDeclaration(statement) || !statement.name) continue;
      const decoratorCall = matchingDecoratorCall(statement, 'Module', checker);
      if (!decoratorCall) continue;
      const info = {
        key: `${repositoryPath}#${statement.name.text}`,
        name: statement.name.text,
        path: repositoryPath,
        line: lineOf(sourceFile, statement),
        sourceFile,
        classNode: statement,
        decoratorCall,
        edges: new Set(),
      };
      modules.push(info);
      const symbol = resolveAlias(checker.getSymbolAtLocation(statement.name), checker);
      for (const declaration of (symbol && symbol.declarations) || [statement]) {
        if (ts.isClassDeclaration(declaration)) moduleByDeclaration.set(declaration, info);
      }
    }
  }

  const unresolved = [];
  const addUnresolved = (owner, node) => {
    unresolved.push(diagnostic(
      'unresolved-module-import',
      owner.path,
      owner.sourceFile,
      node,
      `cannot statically resolve Nest module import '${node.getText(owner.sourceFile)}'`,
    ));
  };

  function evaluateExpression(expression, owner, seenSymbols = new Set()) {
    const current = unwrapExpression(expression);
    if (ts.isArrayLiteralExpression(current)) {
      for (const element of current.elements) {
        if (ts.isSpreadElement(element)) evaluateExpression(element.expression, owner, new Set(seenSymbols));
        else evaluateExpression(element, owner, new Set(seenSymbols));
      }
      return;
    }

    if (ts.isConditionalExpression(current)) {
      addUnresolved(owner, current);
      return;
    }

    if (ts.isCallExpression(current)) {
      if (!ts.isPropertyAccessExpression(current.expression)) {
        addUnresolved(owner, current);
        return;
      }
      const target = resolveExpressionTarget(
        current.expression.expression,
        checker,
        moduleByDeclaration,
      );
      if (target.kind === 'internal') owner.edges.add(target.moduleInfo.key);
      else if (target.kind !== 'external') addUnresolved(owner, current);
      return;
    }

    const target = resolveExpressionTarget(current, checker, moduleByDeclaration);
    if (target.kind === 'internal') {
      owner.edges.add(target.moduleInfo.key);
      return;
    }
    if (target.kind === 'external') return;

    const symbol = resolveAlias(symbolAtExpression(current, checker), checker);
    if (symbol && !seenSymbols.has(symbol)) {
      seenSymbols.add(symbol);
      const declarations = symbol.declarations || [];
      if (declarations.length === 1 && isConstVariableDeclaration(declarations[0]) && declarations[0].initializer) {
        evaluateExpression(declarations[0].initializer, owner, seenSymbols);
        return;
      }
    }
    addUnresolved(owner, current);
  }

  for (const moduleInfo of modules) {
    const metadata = moduleInfo.decoratorCall.arguments[0];
    if (!metadata) continue;
    const unwrappedMetadata = unwrapExpression(metadata);
    if (!ts.isObjectLiteralExpression(unwrappedMetadata)) {
      addUnresolved(moduleInfo, metadata);
      continue;
    }
    for (const property of unwrappedMetadata.properties) {
      if (ts.isPropertyAssignment(property) && propertyNameText(property.name) === 'imports') {
        evaluateExpression(property.initializer, moduleInfo);
      } else if (ts.isShorthandPropertyAssignment(property) && property.name.text === 'imports') {
        const symbol = checker.getShorthandAssignmentValueSymbol(property);
        const resolved = resolveAlias(symbol, checker);
        const declarations = (resolved && resolved.declarations) || [];
        if (declarations.length === 1 && isConstVariableDeclaration(declarations[0]) && declarations[0].initializer) {
          evaluateExpression(declarations[0].initializer, moduleInfo);
        } else {
          addUnresolved(moduleInfo, property);
        }
      }
    }
  }

  const byKey = new Map(modules.map((moduleInfo) => [moduleInfo.key, moduleInfo]));
  return { modules, byKey, unresolved };
}

function compareModules(left, right) {
  return compareText(left.name, right.name) || compareText(left.path, right.path);
}

function normalizeCycle(cycle) {
  const body = cycle.slice(0, -1);
  let best = 0;
  for (let index = 1; index < body.length; index += 1) {
    if (compareModules(body[index], body[best]) < 0) best = index;
  }
  const rotated = [...body.slice(best), ...body.slice(0, best)];
  return [...rotated, rotated[0]];
}

function collectCycleDiagnostics(graph) {
  const state = new Map();
  const stack = [];
  const diagnostics = [];
  const seenCycles = new Set();
  const orderedModules = [...graph.modules].sort(compareModules);

  function visit(moduleInfo) {
    state.set(moduleInfo.key, 1);
    stack.push(moduleInfo);
    const targets = [...moduleInfo.edges]
      .map((key) => graph.byKey.get(key))
      .filter(Boolean)
      .sort(compareModules);
    for (const target of targets) {
      if (!state.has(target.key)) {
        visit(target);
      } else if (state.get(target.key) === 1) {
        const index = stack.findIndex((item) => item.key === target.key);
        const normalized = normalizeCycle([...stack.slice(index), target]);
        const cycleKey = normalized.map((item) => item.key).join(' -> ');
        if (!seenCycles.has(cycleKey)) {
          seenCycles.add(cycleKey);
          const cycle = normalized.map((item) => item.name).join(' -> ');
          diagnostics.push({
            kind: 'nest-module-cycle',
            path: normalized[0].path,
            line: normalized[0].line,
            message: `Nest module cycle: ${cycle}`,
            cycle,
          });
        }
      }
    }
    stack.pop();
    state.set(moduleInfo.key, 2);
  }

  for (const moduleInfo of orderedModules) {
    if (!state.has(moduleInfo.key)) visit(moduleInfo);
  }
  return diagnostics;
}

function compareDiagnostics(left, right) {
  return compareText(left.path, right.path)
    || left.line - right.line
    || compareText(left.kind, right.kind)
    || compareText(left.message, right.message);
}

function scanPorts(options) {
  if (!options || !options.repoRoot || !options.backendRoot) {
    throw new Error('scan options require repoRoot and backendRoot');
  }
  const repoRoot = path.resolve(options.repoRoot);
  const backendRoot = path.resolve(options.backendRoot);
  const { program, checker } = createProgram(backendRoot);
  const files = sourceFiles(program, repoRoot);
  const diagnostics = [];
  const resolvedGlobals = new Set();

  for (const { sourceFile, repositoryPath } of files) {
    function visit(node) {
      if (
        ts.isCallExpression(node)
        && isNestCommonSymbol(node.expression, 'forwardRef', checker)
      ) {
        diagnostics.push(diagnostic(
          'forward-ref',
          repositoryPath,
          sourceFile,
          node,
          'forwardRef resolved to @nestjs/common is forbidden',
        ));
      }
      if (
        ts.isDecorator(node)
        && ts.isCallExpression(node.expression)
        && isNestCommonSymbol(node.expression.expression, 'Global', checker)
      ) {
        resolvedGlobals.add(repositoryPath);
        if (!R0_GLOBAL_MODULES.has(repositoryPath)) {
          diagnostics.push(diagnostic(
            'unapproved-global',
            repositoryPath,
            sourceFile,
            node,
            'Global resolved to @nestjs/common is not in the exact R0 global set',
          ));
        }
      }
      ts.forEachChild(node, visit);
    }
    visit(sourceFile);
  }

  for (const required of [...R0_GLOBAL_MODULES].sort()) {
    if (!resolvedGlobals.has(required)) {
      diagnostics.push({
        kind: 'missing-r0-global',
        path: required,
        line: 1,
        message: 'required R0 Global decorator is missing',
      });
    }
  }

  diagnostics.push(...collectImportDiagnostics(files, program, checker, repoRoot));
  const graph = collectModuleGraph(files, checker);
  diagnostics.push(...graph.unresolved);
  diagnostics.push(...collectCycleDiagnostics(graph));
  diagnostics.sort(compareDiagnostics);

  return {
    diagnostics,
    counts: {
      forwardRef: diagnostics.filter((item) => item.kind === 'forward-ref').length,
      globals: resolvedGlobals.size,
      illegalFutureImports: diagnostics.filter((item) => ILLEGAL_IMPORT_KINDS.has(item.kind)).length,
      nestModuleCycles: diagnostics.filter((item) => item.kind === 'nest-module-cycle').length,
    },
  };
}

function sanitizeMessage(value) {
  const firstLine = String(value || 'unknown error').split(/\r?\n/, 1)[0];
  return firstLine
    .replace(/[A-Za-z]:[\\/][^\s:]*/g, '<path>')
    .replace(/\/(?:[^\s/:]+\/)+[^\s:]*/g, '<path>');
}

function writeLine(target, message) {
  if (typeof target === 'function') target(message);
  else if (target && typeof target.write === 'function') target.write(`${message}\n`);
}

function runCli(dependencies) {
  const argv = dependencies.argv || [];
  if (argv.length !== 1 || argv[0] !== '--check') {
    writeLine(dependencies.stderr, 'usage: ports-scan.cjs --check');
    return 2;
  }
  try {
    const result = dependencies.scan();
    if (!result || !Array.isArray(result.diagnostics) || !result.counts) {
      throw new Error('architecture ports scanner returned an invalid result');
    }
    if (result.diagnostics.length > 0) {
      for (const item of [...result.diagnostics].sort(compareDiagnostics)) {
        writeLine(
          dependencies.stderr,
          `${item.path}:${item.line} [${item.kind}] ${sanitizeMessage(item.message)}`,
        );
      }
      return 1;
    }
    writeLine(
      dependencies.stdout,
      `PASS - architecture ports: forwardRef=${result.counts.forwardRef}, globals=${result.counts.globals}, illegal future imports=${result.counts.illegalFutureImports}, Nest module cycles=${result.counts.nestModuleCycles}`,
    );
    return 0;
  } catch (error) {
    writeLine(
      dependencies.stderr,
      `architecture ports error: ${sanitizeMessage(error && error.message)}`,
    );
    return 2;
  }
}

function defaultDependencies(argv) {
  const backendRoot = path.resolve(__dirname, '../..');
  const repoRoot = path.resolve(backendRoot, '..');
  return {
    argv,
    scan: () => scanPorts({ repoRoot, backendRoot }),
    stdout: (message) => process.stdout.write(`${message}\n`),
    stderr: (message) => process.stderr.write(`${message}\n`),
  };
}

module.exports = {
  R0_GLOBAL_MODULES,
  scanPorts,
  runCli,
};

if (require.main === module) {
  process.exitCode = runCli(defaultDependencies(process.argv.slice(2)));
}
