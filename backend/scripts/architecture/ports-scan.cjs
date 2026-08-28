'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { types: utilTypes } = require('node:util');
const ts = require('typescript');

const APPROVED_GLOBAL_MODULES = new Set();

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
const RETIRED_PLATFORM_ROOTS = new Set(['common', 'outbox']);
const BACKOFFICE_PERMISSION_CONTRACT =
  'backend/src/modules/backoffice/domain/admin-permissions.ts';
const RELOCATED_SAFE_USER = 'backend/src/modules/identity/public/safe-user.ts';
const R5_BOOTSTRAP_JWT_SECRET_EDGE =
  'backend/src/main.ts|backend/src/modules/identity/internal/auth/jwt-secret.ts';
const R5_RELOCATED_IDENTITY_PURE_HELPER_EDGES = new Set([
  'backend/src/modules/identity/internal/profile/contexts.service.ts|backend/src/provider-dashboard/provider-access-policy.ts',
  'backend/src/modules/identity/internal/profile/users.service.ts|backend/src/marketplace/provider-review-rating.ts',
]);
const TRANSITIONAL_PLATFORM_BUSINESS_DEBT = new Set([
  'backend/src/platform/config/runtime-environment.ts|backend/src/auth/jwt-secret.ts',
  'backend/src/platform/health/readiness.service.ts|backend/src/media/media-storage.service.ts',
  'backend/src/platform/outbox/outbox.dispatcher.ts|backend/src/conversations/conversation-realtime.publisher.ts',
  'backend/src/platform/outbox/outbox.dispatcher.ts|backend/src/push/push-delivery.service.ts',
  'backend/src/platform/outbox/outbox.module.ts|backend/src/conversations/conversation-realtime.module.ts',
  'backend/src/platform/outbox/outbox.module.ts|backend/src/push/push.module.ts',
]);
const ILLEGAL_IMPORT_KINDS = new Set([
  'non-public-cross-module-import',
  'domain-runtime-import',
  'platform-business-import',
  'retired-platform-root',
  'shared-kernel-direction-import',
  'application-composition-import',
  'application-composition-direction',
  'cross-public-runtime-import',
]);
const DIAGNOSTIC_MESSAGES = Object.freeze({
  'forward-ref': 'forwardRef resolved to @nestjs/common is forbidden',
  'unapproved-global': 'Global resolved to @nestjs/common is not in the approved global set',
  'non-public-cross-module-import': 'cross-module import must target an allowed public slice',
  'domain-runtime-import': 'domain code cannot import Nest runtime or a foreign business context',
  'platform-business-import': 'platform cannot import business module code',
  'retired-platform-root': 'retired platform root is forbidden',
  'shared-kernel-direction-import': 'shared-kernel cannot import platform or business code',
  'application-composition-import': 'application composition may import only platform and business public slices',
  'application-composition-direction': 'application composition is a root and cannot be imported',
  'cross-public-runtime-import': 'cross-owner public imports must be type-only',
  'nest-module-cycle': 'Nest module import cycle detected',
  'unresolved-module-import': 'cannot statically resolve Nest module import expression',
});
const DIAGNOSTIC_KINDS = new Set(Object.keys(DIAGNOSTIC_MESSAGES));
const COUNT_KEYS = Object.freeze([
  'forwardRef',
  'globals',
  'illegalFutureImports',
  'nestModuleCycles',
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

function isNestCommonSymbol(expression, expectedName, checker, seenSymbols = new Set()) {
  const current = unwrapExpression(expression);
  const symbol = symbolAtExpression(current, checker);
  if (!symbol || seenSymbols.has(symbol)) return false;
  if (
    symbol.getName() === expectedName
    && (symbol.declarations || []).some((declaration) => (
      declarationComesFromPackage(declaration, '@nestjs/common')
    ))
  ) {
    return true;
  }
  seenSymbols.add(symbol);
  const declarations = symbol.declarations || [];
  if (declarations.length !== 1 || !isConstVariableDeclaration(declarations[0])) return false;
  const initializer = declarations[0].initializer;
  return Boolean(
    initializer
    && isNestCommonSymbol(initializer, expectedName, checker, seenSymbols)
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

function diagnostic(kind, repositoryPath, sourceFile, node, extra = {}) {
  return {
    kind,
    path: repositoryPath,
    line: node ? lineOf(sourceFile, node) : 1,
    message: DIAGNOSTIC_MESSAGES[kind],
    ...extra,
  };
}

function classifyRepositoryPath(repositoryPath) {
  if (!repositoryPath.startsWith('backend/src/')) return { kind: 'external' };
  const segments = repositoryPath.slice('backend/src/'.length).split('/');
  if (segments[0] === 'application-composition') {
    return { kind: 'application-composition', future: true };
  }
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
  if (RETIRED_PLATFORM_ROOTS.has(segments[0])) return { kind: 'platform', future: false };
  const context = LEGACY_ROOT_TO_CONTEXT.get(segments[0]);
  if (context) return { kind: 'business', context, future: false, public: false };
  return { kind: 'unclassified', future: false };
}

function isTypeOnlyModuleReference(statement) {
  if (ts.isExportDeclaration(statement)) return Boolean(statement.isTypeOnly);
  const clause = statement.importClause;
  if (!clause) return false;
  if (clause.isTypeOnly) return true;
  const bindings = clause.namedBindings;
  return Boolean(
    bindings
    && ts.isNamedImports(bindings)
    && bindings.elements.length > 0
    && bindings.elements.every((element) => element.isTypeOnly)
  );
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
  if (!file.endsWith('/src/platform/database/prisma.service.ts')) return false;
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

      if (
        source.kind === 'application-composition'
        && target.kind !== 'external'
        && target.kind !== 'platform'
        && !(target.kind === 'business' && target.future && target.public)
      ) {
        diagnostics.push(diagnostic(
          'application-composition-import',
          repositoryPath,
          sourceFile,
          statement,
        ));
        continue;
      }

      if (
        target.kind === 'application-composition'
        && (source.kind === 'platform' || source.kind === 'business' || source.kind === 'shared-kernel')
      ) {
        diagnostics.push(diagnostic(
          'application-composition-direction',
          repositoryPath,
          sourceFile,
          statement,
        ));
        continue;
      }

      if (
        source.kind === 'business'
        && source.future
        && source.public
        && target.kind === 'business'
        && target.future
        && target.public
        && source.context !== target.context
        && !isTypeOnlyModuleReference(statement)
      ) {
        diagnostics.push(diagnostic(
          'cross-public-runtime-import',
          repositoryPath,
          sourceFile,
          statement,
        ));
        continue;
      }

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
        ));
        continue;
      }

      if (
        source.kind === 'platform'
        && target.kind === 'business'
        && (source.future || target.future)
      ) {
        const edge = targetPath ? `${repositoryPath}|${targetPath}` : '';
        if (TRANSITIONAL_PLATFORM_BUSINESS_DEBT.has(edge)) continue;
        diagnostics.push(diagnostic(
          'platform-business-import',
          repositoryPath,
          sourceFile,
          statement,
        ));
        continue;
      }

      if (
        source.kind === 'business'
        && target.kind === 'business'
        && source.context !== target.context
        && (source.future || target.future)
        && !(target.future && target.public)
        && !R5_RELOCATED_IDENTITY_PURE_HELPER_EDGES.has(
          `${repositoryPath}|${targetPath}`,
        )
        && !(
          targetPath === BACKOFFICE_PERMISSION_CONTRACT
          && (repositoryPath.startsWith('backend/src/auth/')
            || repositoryPath.startsWith('backend/src/catalogs/')
            || repositoryPath === RELOCATED_SAFE_USER)
        )
      ) {
        diagnostics.push(diagnostic(
          'non-public-cross-module-import',
          repositoryPath,
          sourceFile,
          statement,
        ));
        continue;
      }

      if (
        target.kind === 'business'
        && target.future
        && target.internal
        && !(source.kind === 'business' && source.context === target.context)
        && `${repositoryPath}|${targetPath}` !== R5_BOOTSTRAP_JWT_SECRET_EDGE
      ) {
        diagnostics.push(diagnostic(
          'non-public-cross-module-import',
          repositoryPath,
          sourceFile,
          statement,
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
          const cycle = normalized.map((item) => item.path).join(' -> ');
          diagnostics.push({
            kind: 'nest-module-cycle',
            path: normalized[0].path,
            line: normalized[0].line,
            message: DIAGNOSTIC_MESSAGES['nest-module-cycle'],
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
    if (
      repositoryPath === 'backend/src/health.controller.ts'
      || repositoryPath.startsWith('backend/src/health/')
      || repositoryPath.startsWith('backend/src/prisma/')
      || repositoryPath.startsWith('backend/src/common/')
      || repositoryPath.startsWith('backend/src/outbox/')
    ) {
      diagnostics.push(diagnostic(
        'retired-platform-root',
        repositoryPath,
        sourceFile,
        null,
      ));
    }
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
        ));
      }
      if (
        ts.isDecorator(node)
        && ts.isCallExpression(node.expression)
        && isNestCommonSymbol(node.expression.expression, 'Global', checker)
      ) {
        resolvedGlobals.add(repositoryPath);
        if (!APPROVED_GLOBAL_MODULES.has(repositoryPath)) {
          diagnostics.push(diagnostic(
            'unapproved-global',
            repositoryPath,
            sourceFile,
            node,
          ));
        }
      }
      ts.forEachChild(node, visit);
    }
    visit(sourceFile);
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

function isPlainObject(value) {
  return Boolean(
    value
    && typeof value === 'object'
    && !Array.isArray(value)
    && !utilTypes.isProxy(value)
    && Object.getPrototypeOf(value) === Object.prototype
  );
}

function exactDataObject(value, expectedKeys, description) {
  if (!isPlainObject(value)) {
    throw new Error(`${description} must be a plain object`);
  }
  const actualKeys = Reflect.ownKeys(value);
  if (
    actualKeys.length !== expectedKeys.length
    || actualKeys.some((key) => typeof key !== 'string' || !expectedKeys.includes(key))
  ) {
    throw new Error(`${description} has an invalid schema`);
  }
  const result = {};
  for (const key of expectedKeys) {
    const descriptor = Object.getOwnPropertyDescriptor(value, key);
    if (!descriptor || !Object.prototype.hasOwnProperty.call(descriptor, 'value')) {
      throw new Error(`${description} cannot contain accessors`);
    }
    result[key] = descriptor.value;
  }
  return result;
}

function plainArrayValues(value, description) {
  if (
    !Array.isArray(value)
    || utilTypes.isProxy(value)
    || Object.getPrototypeOf(value) !== Array.prototype
  ) {
    throw new Error(`${description} must be a plain array`);
  }
  const lengthDescriptor = Object.getOwnPropertyDescriptor(value, 'length');
  const length = lengthDescriptor && lengthDescriptor.value;
  const actualKeys = Reflect.ownKeys(value);
  if (
    !Number.isSafeInteger(length)
    || length < 0
    || actualKeys.length !== length + 1
    || actualKeys[actualKeys.length - 1] !== 'length'
    || actualKeys.slice(0, -1).some((key, index) => key !== String(index))
  ) {
    throw new Error(`${description} must be dense and contain no extra properties`);
  }
  return actualKeys.slice(0, -1).map((key) => {
    const descriptor = Object.getOwnPropertyDescriptor(value, key);
    if (!descriptor || !Object.prototype.hasOwnProperty.call(descriptor, 'value')) {
      throw new Error(`${description} cannot contain accessors`);
    }
    return descriptor.value;
  });
}

function dataProperty(value, key, description) {
  const descriptor = Object.getOwnPropertyDescriptor(value, key);
  if (!descriptor || !Object.prototype.hasOwnProperty.call(descriptor, 'value')) {
    throw new Error(`${description} requires a data property named ${key}`);
  }
  return descriptor.value;
}

function canonicalDiagnosticPath(value) {
  if (
    typeof value !== 'string'
    || !value
    || value.length > 4096
    || !/^backend\/src\/.+\.ts$/.test(value)
    || /[\\:\u0000-\u001f\u007f]/.test(value)
    || value.includes('//')
    || path.posix.normalize(value) !== value
  ) {
    throw new Error('architecture diagnostic path is not canonical');
  }
  const segments = value.split('/');
  if (
    segments[0] !== 'backend'
    || segments[1] !== 'src'
    || segments.some((segment) => !segment || segment === '.' || segment === '..')
  ) {
    throw new Error('architecture diagnostic path is not repository-relative');
  }
  return value;
}

function canonicalDiagnostic(item) {
  if (
    !isPlainObject(item)
  ) {
    throw new Error('architecture diagnostic must be a plain object');
  }
  const kind = dataProperty(item, 'kind', 'architecture diagnostic');
  const diagnosticPath = canonicalDiagnosticPath(
    dataProperty(item, 'path', 'architecture diagnostic'),
  );
  const line = dataProperty(item, 'line', 'architecture diagnostic');
  if (!DIAGNOSTIC_KINDS.has(kind) || !Number.isSafeInteger(line) || line < 1) {
    throw new Error('architecture diagnostic kind or line is invalid');
  }
  return {
    kind,
    path: diagnosticPath,
    line,
    message: DIAGNOSTIC_MESSAGES[kind],
  };
}

function validateScanResult(value) {
  const result = exactDataObject(value, ['diagnostics', 'counts'], 'architecture scan result');
  const diagnostics = plainArrayValues(result.diagnostics, 'architecture diagnostics')
    .map(canonicalDiagnostic)
    .sort(compareDiagnostics);
  const counts = exactDataObject(result.counts, COUNT_KEYS, 'architecture counts');
  for (const key of COUNT_KEYS) {
    if (!Number.isSafeInteger(counts[key]) || counts[key] < 0) {
      throw new Error('architecture counts must be non-negative safe integers');
    }
  }
  return { diagnostics, counts };
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
    const result = validateScanResult(dependencies.scan());
    if (result.diagnostics.length > 0) {
      const lines = result.diagnostics.map((item) => (
        `${item.path}:${item.line} [${item.kind}] ${item.message}`
      ));
      for (const line of lines) {
        writeLine(dependencies.stderr, line);
      }
      return 1;
    }
    writeLine(
      dependencies.stdout,
      `PASS - architecture ports: forwardRef=${result.counts.forwardRef}, globals=${result.counts.globals}, illegal future imports=${result.counts.illegalFutureImports}, Nest module cycles=${result.counts.nestModuleCycles}`,
    );
    return 0;
  } catch {
    writeLine(dependencies.stderr, 'ERROR - architecture ports scan failed');
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
  APPROVED_GLOBAL_MODULES,
  scanPorts,
  runCli,
};

if (require.main === module) {
  process.exitCode = runCli(defaultDependencies(process.argv.slice(2)));
}
