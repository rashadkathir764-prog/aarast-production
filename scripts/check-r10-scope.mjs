import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { createRequire } from 'node:module';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

import {
  parseAdminModuleSpecifiers,
  scanAdminBoundaries,
  validateR10Manifest,
} from '../admin-web/scripts/admin-boundaries.mjs';

const requireFromAdmin = createRequire(new URL('../admin-web/package.json', import.meta.url));
const ts = requireFromAdmin('typescript');
const ARABIC = /[\u0600-\u06FF]/;
const EXACT_GENERIC_TRANSPORT_CALL_SHA256 = '59848b85e203bfad08d78ffd420add5a9cdcf0896d9ec2f8bee55ce8b082ef24';
const PAGINATION_PAGES = Object.freeze([
  'UsersPage.tsx',
  'ProviderApplicationsPage.tsx',
  'ProvidersPage.tsx',
  'ServicesPage.tsx',
  'ReviewsPage.tsx',
  'ConversationReportsPage.tsx',
  'NotificationsPage.tsx',
]);
const PAGINATION_STAGES = Object.freeze({
  'task-2': ['../design_system/Pagination', '../design_system/Pagination', '../design_system/Pagination', '../design_system/Pagination', '../design_system/Pagination', '../design_system/Pagination', '../design_system/Pagination'],
  'task-3': ['../design_system/Pagination', '../design_system/Pagination', '../design_system/Pagination', '../design_system/Pagination', '../design_system/Pagination', '../design_system/Pagination', '../design_system/Pagination'],
  'task-4': ['../../design_system/Pagination', '../../design_system/Pagination', '../../design_system/Pagination', '../design_system/Pagination', '../design_system/Pagination', '../design_system/Pagination', '../design_system/Pagination'],
  'task-5': ['../../design_system/Pagination', '../../design_system/Pagination', '../../design_system/Pagination', '../../design_system/Pagination', '../design_system/Pagination', '../design_system/Pagination', '../design_system/Pagination'],
  'task-6': ['../../design_system/Pagination', '../../design_system/Pagination', '../../design_system/Pagination', '../../design_system/Pagination', '../../design_system/Pagination', '../../design_system/Pagination', '../../design_system/Pagination'],
});

function sha256(value) {
  return createHash('sha256').update(value).digest('hex');
}

function taskNumber(task) {
  const match = /^task-(\d+)$/.exec(task || '');
  return match ? Number(match[1]) : null;
}

function canonicalRepositoryPath(value) {
  return typeof value === 'string'
    && value.length > 0
    && value.length <= 512
    && !value.includes('\\')
    && !/[\u0000-\u001F\u007F-\u009F:=?*"<>|%]/.test(value)
    && !path.posix.isAbsolute(value)
    && !path.win32.isAbsolute(value)
    && path.posix.normalize(value) === value
    && value.split('/').every((segment) => (
      segment !== ''
      && segment !== '.'
      && segment !== '..'
      && /^[A-Za-z0-9_.@+$'{}-]+$/.test(segment)
    ));
}

function isInside(root, target) {
  const relative = path.relative(root, target);
  return relative === '' || (
    relative !== '..'
    && !relative.startsWith(`..${path.sep}`)
    && !path.isAbsolute(relative)
  );
}

function resolveExistingPrefix(target) {
  let current = target;
  const suffix = [];
  while (!fs.existsSync(current)) {
    const parent = path.dirname(current);
    if (parent === current) throw new Error('unresolvable');
    suffix.unshift(path.basename(current));
    current = parent;
  }
  return path.join(fs.realpathSync.native(current), ...suffix);
}

function runGitAt(repoRoot, args, encoding = 'utf8') {
  const result = spawnSync('git', ['-C', repoRoot, ...args], {
    encoding,
    windowsHide: true,
    maxBuffer: 16 * 1024 * 1024,
  });
  if (result.status !== 0 || result.error) throw new Error('git query failed');
  return result.stdout;
}

function parseNameStatusZ(output) {
  const values = String(output).split('\0');
  const paths = [];
  for (let index = 0; index < values.length;) {
    const status = values[index++];
    if (!status) continue;
    if (/^[RC]/.test(status)) {
      const source = values[index++];
      const target = values[index++];
      if (!source || !target) throw new Error('invalid git name-status');
      paths.push(source, target);
    } else {
      const item = values[index++];
      if (!item) throw new Error('invalid git name-status');
      paths.push(item);
    }
  }
  return paths;
}

export function collectChangedPaths({ repoRoot, base, runGit } = {}) {
  const git = runGit || ((args) => runGitAt(repoRoot, args));
  git(['cat-file', '-e', `${base}^{commit}`]);
  const tracked = parseNameStatusZ(git([
    'diff', '--name-status', '--find-renames', '--find-copies', '-z', base, '--',
  ]));
  const untracked = String(git([
    'ls-files', '--others', '--exclude-standard', '-z', '--',
  ])).split('\0').filter(Boolean);
  return [...new Set([...tracked, ...untracked])].sort();
}

export function checkChangedPathFence({ repoRoot, changedPaths, allowedPaths }) {
  const errors = [];
  const accepted = [];
  let realRoot;
  try {
    const rootStat = fs.lstatSync(path.resolve(repoRoot));
    if (rootStat.isSymbolicLink() || !rootStat.isDirectory()) throw new Error('unsafe root');
    realRoot = fs.realpathSync.native(path.resolve(repoRoot));
  } catch {
    return { ok: false, changedPaths: [], errors: [{ kind: 'repository-root-invalid' }] };
  }
  for (const changedPath of changedPaths) {
    if (!canonicalRepositoryPath(changedPath) || !allowedPaths.has(changedPath)) {
      errors.push({ kind: 'unapproved-changed-path' });
      continue;
    }
    accepted.push(changedPath);
    try {
      let current = path.resolve(repoRoot);
      for (const segment of changedPath.split('/')) {
        current = path.join(current, segment);
        try {
          if (fs.lstatSync(current).isSymbolicLink()) throw new Error('path link');
        } catch (error) {
          if (error?.message === 'path link') throw error;
          if (error?.code === 'ENOENT') break;
          throw error;
        }
      }
      const resolved = resolveExistingPrefix(path.join(repoRoot, ...changedPath.split('/')));
      if (!isInside(realRoot, resolved)) errors.push({ kind: 'changed-path-escape', path: changedPath });
    } catch (error) {
      errors.push({
        kind: error?.message === 'path link' ? 'changed-path-link' : 'changed-path-resolution-failure',
        path: changedPath,
      });
    }
  }
  return { ok: errors.length === 0, changedPaths: [...new Set(accepted)].sort(), errors };
}

function sourceFileOf(record) {
  return ts.createSourceFile(
    record.path,
    record.sourceText,
    ts.ScriptTarget.Latest,
    true,
    record.path.endsWith('.tsx') ? ts.ScriptKind.TSX : ts.ScriptKind.TS,
  );
}

function canonicalTemplate(node) {
  if (ts.isStringLiteralLike(node)) return node.text;
  if (!ts.isTemplateExpression(node)) return null;
  let result = node.head.text;
  node.templateSpans.forEach((span, index) => {
    const omitApiBase = index === 0
      && node.head.text === ''
      && ts.isIdentifier(span.expression)
      && span.expression.text === 'apiBaseUrl';
    if (!omitApiBase) result += '<expr>';
    result += span.literal.text;
  });
  return result;
}

function requestMethod(call) {
  const options = call.arguments[1];
  if (!options) return 'GET';
  if (!ts.isObjectLiteralExpression(options)) throw new Error('unsupported request options');
  let method = null;
  for (const property of options.properties) {
    if (ts.isSpreadAssignment(property) || ts.isComputedPropertyName(property.name)) {
      throw new Error('unsupported request options');
    }
    const name = property.name && (
      (ts.isIdentifier(property.name) || ts.isStringLiteralLike(property.name))
        ? property.name.text
        : null
    );
    if (name !== 'method') continue;
    if (
      method !== null
      || !ts.isPropertyAssignment(property)
      || !ts.isStringLiteralLike(property.initializer)
    ) throw new Error('unsupported request method');
    method = property.initializer.text.toUpperCase();
  }
  return method ?? 'GET';
}

function semanticAstFingerprint(node) {
  const record = [node.kind];
  if (
    ts.isIdentifier(node)
    || ts.isPrivateIdentifier(node)
    || ts.isStringLiteralLike(node)
    || ts.isNumericLiteral(node)
    || ts.isTemplateLiteralToken(node)
  ) record.push(node.text);
  ts.forEachChild(node, (child) => {
    record.push(semanticAstFingerprint(child));
  });
  return record;
}

function isExactGenericTransportCall(call) {
  return sha256(JSON.stringify(semanticAstFingerprint(call))) === EXACT_GENERIC_TRANSPORT_CALL_SHA256;
}

function unwrapExpression(node) {
  let current = node;
  while (
    ts.isParenthesizedExpression(current)
    || ts.isAsExpression(current)
    || ts.isTypeAssertionExpression(current)
    || ts.isNonNullExpression(current)
    || ts.isSatisfiesExpression(current)
  ) current = current.expression;
  return current;
}

function constantStringValue(node) {
  const current = unwrapExpression(node);
  if (ts.isStringLiteralLike(current)) return current.text;
  if (ts.isBinaryExpression(current) && current.operatorToken.kind === ts.SyntaxKind.PlusToken) {
    const left = constantStringValue(current.left);
    const right = constantStringValue(current.right);
    return left === null || right === null ? null : `${left}${right}`;
  }
  return null;
}

function globalMemberAccess(expression, member) {
  const current = unwrapExpression(expression);
  if (ts.isPropertyAccessExpression(current)) {
    const base = unwrapExpression(current.expression);
    return ts.isIdentifier(base)
      && ['window', 'globalThis', 'self'].includes(base.text)
      && current.name.text === member;
  }
  if (ts.isElementAccessExpression(current)) {
    const base = unwrapExpression(current.expression);
    return ts.isIdentifier(base)
      && ['window', 'globalThis', 'self'].includes(base.text)
      && constantStringValue(current.argumentExpression) === member;
  }
  return false;
}

function directRequestCallee(expression) {
  const current = unwrapExpression(expression);
  if (ts.isIdentifier(current)) {
    if (current.text === 'apiRequest') return 'apiRequest';
    if (current.text === 'fetch') return 'fetch';
    return null;
  }
  return globalMemberAccess(current, 'fetch') ? 'fetch' : null;
}

function isDirectFetchReference(node) {
  if (!ts.isIdentifier(node) || node.text !== 'fetch') return false;
  const parent = node.parent;
  if (ts.isCallExpression(parent) && unwrapExpression(parent.expression) === node) return true;
  return ts.isPropertyAccessExpression(parent)
    && parent.name === node
    && directRequestCallee(parent) === 'fetch'
    && ts.isCallExpression(parent.parent)
    && unwrapExpression(parent.parent.expression) === parent;
}

function isApprovedApiRequestIdentifier(node, recordPath) {
  if (!ts.isIdentifier(node) || node.text !== 'apiRequest') return false;
  const parent = node.parent;
  if (ts.isCallExpression(parent) && unwrapExpression(parent.expression) === node) return true;
  if (ts.isImportSpecifier(parent) && parent.name === node && parent.propertyName === undefined) return true;
  return ts.isFunctionDeclaration(parent)
    && parent.name === node
    && ['api/client.ts', 'platform/api/client.ts'].includes(recordPath);
}

export function extractAdminRequestInventory({ sourceFiles, genericTransportPaths = [] }) {
  const records = [];
  const allowedGenericPaths = new Set(genericTransportPaths);
  let genericTransportCalls = 0;
  for (const record of sourceFiles) {
    const sourceFile = sourceFileOf(record);
    const visit = (node) => {
      if (
        ts.isElementAccessExpression(node)
        && globalMemberAccess(node, 'fetch')
        && !(ts.isCallExpression(node.parent) && unwrapExpression(node.parent.expression) === node)
      ) throw new Error('unsupported fetch reference');
      if (
        ts.isIdentifier(node)
        && node.text === 'fetch'
        && !isDirectFetchReference(node)
      ) throw new Error('unsupported fetch reference');
      if (
        ts.isIdentifier(node)
        && node.text === 'apiRequest'
        && !isApprovedApiRequestIdentifier(node, record.path)
      ) throw new Error('unsupported apiRequest reference');
      if (ts.isCallExpression(node)) {
        const name = directRequestCallee(node.expression);
        if (name === 'apiRequest' || name === 'fetch') {
          if (name === 'fetch' && !allowedGenericPaths.has(record.path)) {
            throw new Error('fetch outside transport');
          }
          const route = canonicalTemplate(node.arguments[0]);
          if (name === 'apiRequest' && (route === null || !route.startsWith('/'))) {
            throw new Error('unsupported apiRequest route');
          }
          if (name === 'fetch' && (route === null || !route.startsWith('/'))) {
            if (!allowedGenericPaths.has(record.path) || !isExactGenericTransportCall(node)) {
              throw new Error('unsupported fetch route');
            }
            genericTransportCalls += 1;
          } else {
            records.push(`${requestMethod(node)} ${route}`);
          }
        }
      }
      ts.forEachChild(node, visit);
    };
    visit(sourceFile);
  }
  if (allowedGenericPaths.size > 0 && genericTransportCalls !== 1) {
    throw new Error('generic transport contract mismatch');
  }
  return records.sort();
}

export function extractAdminArabicLiteralInventory({ sourceFiles }) {
  const records = [];
  for (const record of sourceFiles) {
    if (/\.test\.(?:ts|tsx)$/.test(record.path) || record.path.startsWith('test/')) continue;
    const sourceFile = sourceFileOf(record);
    const visit = (node) => {
      let value = null;
      if (
        ts.isStringLiteral(node)
        || ts.isNoSubstitutionTemplateLiteral(node)
        || ts.isTemplateHead(node)
        || ts.isTemplateMiddle(node)
        || ts.isTemplateTail(node)
        || ts.isJsxText(node)
      ) value = node.text;
      if (typeof value === 'string' && ARABIC.test(value)) records.push(value);
      ts.forEachChild(node, visit);
    };
    visit(sourceFile);
  }
  return records.sort();
}

function moduleLiteralNodes(sourceFile) {
  const nodes = [];
  const add = (node) => {
    if (node && ts.isStringLiteralLike(node)) nodes.push(node);
  };
  const visit = (node) => {
    if (ts.isImportDeclaration(node) || ts.isExportDeclaration(node)) add(node.moduleSpecifier);
    else if (ts.isImportEqualsDeclaration(node) && ts.isExternalModuleReference(node.moduleReference)) {
      add(node.moduleReference.expression);
    } else if (ts.isCallExpression(node)) {
      const requireCall = ts.isIdentifier(node.expression) && node.expression.text === 'require';
      const dynamicImport = node.expression.kind === ts.SyntaxKind.ImportKeyword;
      const viMock = ts.isPropertyAccessExpression(node.expression)
        && ts.isIdentifier(node.expression.expression)
        && node.expression.expression.text === 'vi'
        && node.expression.name.text === 'mock';
      if (requireCall || dynamicImport || viMock) add(node.arguments[0]);
    }
    ts.forEachChild(node, visit);
  };
  visit(sourceFile);
  return nodes;
}

function applyEdits(sourceText, edits) {
  let output = sourceText;
  for (const edit of edits.sort((left, right) => right.start - left.start)) {
    output = `${output.slice(0, edit.start)}${edit.text}${output.slice(edit.end)}`;
  }
  return output;
}

export function normalizeExistingAdminTest({ sourceText, relativePath }) {
  const normalizedLines = sourceText.replaceAll('\r\n', '\n');
  const sourceFile = ts.createSourceFile(
    relativePath,
    normalizedLines,
    ts.ScriptTarget.Latest,
    true,
    relativePath.endsWith('.tsx') ? ts.ScriptKind.TSX : ts.ScriptKind.TS,
  );
  const edits = moduleLiteralNodes(sourceFile).map((node) => ({
    start: node.getStart(sourceFile),
    end: node.getEnd(),
    text: "'__R10_MODULE__'",
  }));
  return applyEdits(normalizedLines, edits);
}

function paginationRows(sourceText) {
  const rows = [];
  const rowPattern = /^\s*\['([^']+)',\s*([A-Za-z_$][\w$]*)(?:,\s*'([^']+)')?\],\s*$/gm;
  let match;
  while ((match = rowPattern.exec(sourceText)) !== null) {
    rows.push({ page: match[1], source: match[2], expectedImport: match[3] ?? null });
  }
  return rows;
}

function canonicalizePagination(sourceText, candidate) {
  let result = sourceText;
  if (candidate) {
    result = result.replace(
      /^(\s*\['[^']+',\s*[A-Za-z_$][\w$]*),\s*'(?:\.\.\/){1,2}design_system\/Pagination'(\],\s*)$/gm,
      '$1$2',
    );
    result = result.replace(
      '[file, source, expectedPaginationImport]',
      '[file, source]',
    );
    result = result.replace(
      "`from '${expectedPaginationImport}'`",
      '"from \'../components/Pagination\'"',
    );
  }
  return result;
}

function dashboardException(sourceText, candidate) {
  const normalized = sourceText.replaceAll('\r\n', '\n');
  const sourceFile = ts.createSourceFile('DashboardPage.test.tsx', normalized, ts.ScriptTarget.Latest, true, ts.ScriptKind.TSX);
  const edits = [];
  const importGroups = [];
  const mockGroups = [];
  for (const statement of sourceFile.statements) {
    if (ts.isImportDeclaration(statement) && ts.isStringLiteralLike(statement.moduleSpecifier)) {
      const bindings = [];
      const namedBindings = statement.importClause?.namedBindings;
      if (namedBindings && ts.isNamedImports(namedBindings)) {
        for (const element of namedBindings.elements) {
          bindings.push({
            imported: element.propertyName?.text ?? element.name.text,
            local: element.name.text,
            typeOnly: Boolean(statement.importClause?.isTypeOnly || element.isTypeOnly),
          });
        }
      }
      if (bindings.some(({ local }) => ['getStats', 'getProviderApplications', 'AdminStats', 'ProviderApplication'].includes(local))) {
        importGroups.push({
          module: statement.moduleSpecifier.text,
          bindings: bindings.sort((left, right) => left.local.localeCompare(right.local, 'en')),
        });
        edits.push({ start: statement.getFullStart(), end: statement.getEnd(), text: '' });
      }
    }
    if (
      ts.isExpressionStatement(statement)
      && ts.isCallExpression(statement.expression)
      && ts.isPropertyAccessExpression(statement.expression.expression)
      && statement.expression.expression.expression.getText(sourceFile) === 'vi'
      && statement.expression.expression.name.text === 'mock'
    ) {
      const factory = statement.expression.arguments[1];
      if (
        factory
        && ts.isArrowFunction(factory)
        && !factory.modifiers?.some((modifier) => modifier.kind === ts.SyntaxKind.AsyncKeyword)
        && factory.parameters.length === 0
        && ts.isParenthesizedExpression(factory.body)
        && ts.isObjectLiteralExpression(factory.body.expression)
      ) {
        const properties = factory.body.expression.properties;
        const names = [];
        let exactFactories = true;
        for (const property of properties) {
          if (!ts.isPropertyAssignment(property)) {
            exactFactories = false;
            continue;
          }
          const name = property.name.getText(sourceFile).replaceAll(/["']/g, '');
          names.push(name);
          const initializer = property.initializer;
          exactFactories = exactFactories
            && ts.isCallExpression(initializer)
            && initializer.arguments.length === 0
            && ts.isPropertyAccessExpression(initializer.expression)
            && initializer.expression.expression.getText(sourceFile) === 'vi'
            && initializer.expression.name.text === 'fn';
        }
        if (names.some((name) => ['getStats', 'getProviderApplications'].includes(name))) {
          if (!exactFactories || statement.expression.arguments.length !== 2) {
            return { ok: false, canonical: '' };
          }
          const module = statement.expression.arguments[0];
          if (!module || !ts.isStringLiteralLike(module)) return { ok: false, canonical: '' };
          mockGroups.push({ module: module.text, names: names.sort() });
          edits.push({ start: statement.getFullStart(), end: statement.getEnd(), text: '' });
        }
      }
    }
  }
  const expectedImports = candidate ? [
    {
      module: '../providers/api',
      bindings: [
        { imported: 'getProviderApplications', local: 'getProviderApplications', typeOnly: false },
        { imported: 'ProviderApplication', local: 'ProviderApplication', typeOnly: true },
      ],
    },
    {
      module: './api',
      bindings: [
        { imported: 'AdminStats', local: 'AdminStats', typeOnly: true },
        { imported: 'getStats', local: 'getStats', typeOnly: false },
      ],
    },
  ] : [
    {
      module: '../api/admin',
      bindings: [
        { imported: 'AdminStats', local: 'AdminStats', typeOnly: true },
        { imported: 'getProviderApplications', local: 'getProviderApplications', typeOnly: false },
        { imported: 'getStats', local: 'getStats', typeOnly: false },
        { imported: 'ProviderApplication', local: 'ProviderApplication', typeOnly: true },
      ],
    },
  ];
  const expectedMocks = candidate ? [
    { module: '../providers/api', names: ['getProviderApplications'] },
    { module: './api', names: ['getStats'] },
  ] : [
    { module: '../api/admin', names: ['getProviderApplications', 'getStats'] },
  ];
  const byModule = (left, right) => left.module.localeCompare(right.module, 'en');
  if (
    JSON.stringify(importGroups.sort(byModule)) !== JSON.stringify(expectedImports.sort(byModule))
    || JSON.stringify(mockGroups.sort(byModule)) !== JSON.stringify(expectedMocks.sort(byModule))
  ) return { ok: false, canonical: '' };
  return { ok: true, canonical: applyEdits(normalized, edits) };
}

export function compareExistingAdminTest({
  baseSourceText,
  candidateSourceText,
  relativePath,
  stage,
  paginationResolution,
}) {
  const name = path.posix.basename(relativePath);
  if (name === 'AdminPaginationContract.test.ts' && taskNumber(stage) >= 2) {
    const baseRows = paginationRows(baseSourceText);
    const candidateRows = paginationRows(candidateSourceText);
    const expected = PAGINATION_STAGES[stage] || PAGINATION_STAGES['task-6'];
    if (
      baseRows.length !== 7
      || candidateRows.length !== 7
      || JSON.stringify(baseRows.map(({ page }) => page)) !== JSON.stringify(PAGINATION_PAGES)
      || JSON.stringify(candidateRows.map(({ page }) => page)) !== JSON.stringify(PAGINATION_PAGES)
      || JSON.stringify(baseRows.map(({ source }) => source)) !== JSON.stringify(candidateRows.map(({ source }) => source))
      || baseRows.some(({ expectedImport }) => expectedImport !== null)
      || JSON.stringify(candidateRows.map(({ expectedImport }) => expectedImport)) !== JSON.stringify(expected)
      || !baseSourceText.includes("from '../components/Pagination'")
      || !candidateSourceText.includes("`from '${expectedPaginationImport}'`")
    ) return { ok: false, errors: [{ kind: 'pagination-contract-drift' }] };
    for (let index = 0; index < PAGINATION_PAGES.length; index += 1) {
      const resolution = paginationResolution?.[PAGINATION_PAGES[index]];
      if (
        !resolution
        || resolution.expectedImport !== expected[index]
        || resolution.actualImport !== expected[index]
        || resolution.resolvesToDesignSystem !== true
        || resolution.pageIdentityMatches !== true
      ) return { ok: false, errors: [{ kind: 'pagination-resolution-drift' }] };
    }
    const base = normalizeExistingAdminTest({
      sourceText: canonicalizePagination(baseSourceText, false),
      relativePath,
    });
    const candidate = normalizeExistingAdminTest({
      sourceText: canonicalizePagination(candidateSourceText, true),
      relativePath,
    });
    return { ok: base === candidate, errors: base === candidate ? [] : [{ kind: 'behavioral-test-drift' }] };
  }
  if (name === 'DashboardPage.test.tsx' && taskNumber(stage) >= 4) {
    const base = dashboardException(baseSourceText, false);
    const candidate = dashboardException(candidateSourceText, true);
    if (!base.ok || !candidate.ok) return { ok: false, errors: [{ kind: 'dashboard-mock-contract-drift' }] };
    const left = normalizeExistingAdminTest({ sourceText: base.canonical, relativePath });
    const right = normalizeExistingAdminTest({ sourceText: candidate.canonical, relativePath });
    return { ok: left === right, errors: left === right ? [] : [{ kind: 'behavioral-test-drift' }] };
  }
  const base = normalizeExistingAdminTest({ sourceText: baseSourceText, relativePath });
  const candidate = normalizeExistingAdminTest({ sourceText: candidateSourceText, relativePath });
  return { ok: base === candidate, errors: base === candidate ? [] : [{ kind: 'behavioral-test-drift' }] };
}

function gitShow(repoRoot, revision, repositoryPath) {
  return runGitAt(repoRoot, ['show', `${revision}:${repositoryPath}`]);
}

function gitTreeFiles(repoRoot, revision, prefix) {
  return runGitAt(repoRoot, ['ls-tree', '-r', '--name-only', revision, '--', prefix])
    .split(/\r?\n/)
    .filter(Boolean)
    .sort();
}

function currentAdminSourceFiles(repoRoot) {
  const srcRoot = path.join(repoRoot, 'admin-web', 'src');
  const records = [];
  const visit = (directory) => {
    for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
      const target = path.join(directory, entry.name);
      if (entry.isDirectory()) visit(target);
      else if (entry.isFile() && /\.(?:ts|tsx)$/.test(entry.name)) {
        records.push({
          path: path.relative(srcRoot, target).replaceAll('\\', '/'),
          sourceText: fs.readFileSync(target, 'utf8'),
        });
      }
    }
  };
  visit(srcRoot);
  return records.sort((left, right) => left.path.localeCompare(right.path, 'en'));
}

function candidateTestPath(fate, rank) {
  return fate.target && rank >= fate.targetTask ? fate.target : fate.source;
}

function paginationResolution(repoRoot, candidateSourceText, candidateRelativePath) {
  const sourceFile = ts.createSourceFile(candidateRelativePath, candidateSourceText, ts.ScriptTarget.Latest, true, ts.ScriptKind.TS);
  const sources = new Map();
  for (const statement of sourceFile.statements) {
    if (
      ts.isImportDeclaration(statement)
      && statement.importClause?.name
      && ts.isStringLiteralLike(statement.moduleSpecifier)
      && statement.moduleSpecifier.text.endsWith('?raw')
    ) sources.set(statement.importClause.name.text, statement.moduleSpecifier.text.replace(/\?raw$/, ''));
  }
  const rows = paginationRows(candidateSourceText);
  const result = {};
  const resolvedPages = new Set();
  for (const row of rows) {
    const sourceSpecifier = sources.get(row.source);
    if (!sourceSpecifier) continue;
    const pagePath = path.posix.normalize(path.posix.join(path.posix.dirname(candidateRelativePath), sourceSpecifier));
    const pageWithExtension = pagePath.endsWith('.tsx') ? pagePath : `${pagePath}.tsx`;
    const pageIdentityMatches = path.posix.basename(pageWithExtension) === row.page
      && !resolvedPages.has(pageWithExtension);
    resolvedPages.add(pageWithExtension);
    const absolutePage = path.join(repoRoot, 'admin-web', 'src', ...pageWithExtension.split('/'));
    if (!fs.existsSync(absolutePage)) continue;
    const pageText = fs.readFileSync(absolutePage, 'utf8');
    const actualImport = /from\s+['"]((?:\.\.\/){1,2}design_system\/Pagination)['"]/.exec(pageText)?.[1] ?? null;
    const resolved = actualImport
      ? path.posix.normalize(path.posix.join(path.posix.dirname(pageWithExtension), actualImport))
      : null;
    result[row.page] = {
      expectedImport: row.expectedImport,
      actualImport,
      resolvesToDesignSystem: resolved === 'design_system/Pagination',
      pageIdentityMatches,
    };
  }
  return result;
}

function compareAllExistingTests(repoRoot, manifest, task) {
  const rank = taskNumber(task);
  const testFates = manifest.sourceFates.filter(({ source }) => /\.test\.(?:ts|tsx)$/.test(source));
  const candidateRecords = [];
  const errors = [];
  for (const fate of testFates) {
    const candidatePath = candidateTestPath(fate, rank);
    const absoluteCandidate = path.join(repoRoot, 'admin-web', 'src', ...candidatePath.split('/'));
    if (!fs.existsSync(absoluteCandidate)) {
      errors.push({ kind: 'existing-test-missing', path: candidatePath });
      continue;
    }
    const baseSourceText = gitShow(repoRoot, manifest.base, `admin-web/src/${fate.source}`);
    const candidateSourceText = fs.readFileSync(absoluteCandidate, 'utf8');
    candidateRecords.push({ path: candidatePath, sourceText: candidateSourceText });
    const comparison = compareExistingAdminTest({
      baseSourceText,
      candidateSourceText,
      relativePath: fate.source,
      stage: task,
      paginationResolution: fate.source.endsWith('AdminPaginationContract.test.ts') && rank >= 2
        ? paginationResolution(repoRoot, candidateSourceText, candidatePath)
        : undefined,
    });
    if (!comparison.ok) errors.push(...comparison.errors.map((error) => ({ ...error, path: fate.source })));
  }
  if (candidateRecords.length !== manifest.existingTests.files) errors.push({ kind: 'existing-test-file-count-drift' });
  return { ok: errors.length === 0, errors };
}

function defaultInputs(repoRoot, manifest, task) {
  const currentSources = currentAdminSourceFiles(repoRoot);
  const baseProductionPaths = gitTreeFiles(repoRoot, manifest.base, 'admin-web/src')
    .filter((item) => /\.(?:ts|tsx)$/.test(item))
    .filter((item) => !/\.test\.(?:ts|tsx)$/.test(item) && !item.includes('/src/test/'));
  const baseProduction = baseProductionPaths.map((repositoryPath) => ({
    path: repositoryPath.slice('admin-web/src/'.length),
    sourceText: gitShow(repoRoot, manifest.base, repositoryPath),
  }));
  const baseTransport = manifest.transportInputs.map(({ path: repositoryPath }) => ({
    path: repositoryPath.slice('admin-web/src/'.length),
    sourceText: gitShow(repoRoot, manifest.base, repositoryPath),
  }));
  return {
    changedPaths: collectChangedPaths({ repoRoot, base: manifest.base }),
    boundaryResult: scanAdminBoundaries({
      srcRoot: path.join(repoRoot, 'admin-web', 'src'),
      manifest,
      stage: task,
    }),
    baseRequestRecords: extractAdminRequestInventory({
      sourceFiles: baseTransport,
      genericTransportPaths: ['api/client.ts'],
    }),
    candidateRequestRecords: extractAdminRequestInventory({
      sourceFiles: currentSources.filter(({ path: item }) => !/\.test\./.test(item) && !item.startsWith('test/')),
      genericTransportPaths: [taskNumber(task) >= 2 ? 'platform/api/client.ts' : 'api/client.ts'],
    }),
    baseArabicRecords: extractAdminArabicLiteralInventory({ sourceFiles: baseProduction }),
    candidateArabicRecords: extractAdminArabicLiteralInventory({ sourceFiles: currentSources }),
    testComparison: compareAllExistingTests(repoRoot, manifest, task),
  };
}

const defaultInputCache = new Map();

function cachedDefaultInputs(repoRoot, manifest, task) {
  const key = `${path.resolve(repoRoot)}|${manifest.base}|${task}`;
  if (!defaultInputCache.has(key)) {
    defaultInputCache.set(key, defaultInputs(repoRoot, manifest, task));
  }
  return defaultInputCache.get(key);
}

function protectedHashErrors(repoRoot, manifest, overrides = new Map()) {
  const errors = [];
  const records = [
    { path: manifest.adminRoutes.path, sha256: manifest.adminRoutes.sha256 },
    { path: manifest.adminLockfile.path, sha256: manifest.adminLockfile.sha256 },
    manifest.adminRuntimeSmoke,
    ...manifest.documents,
  ];
  for (const record of records) {
    try {
      const value = overrides.has(record.path)
        ? overrides.get(record.path)
        : fs.readFileSync(path.join(repoRoot, ...record.path.split('/')));
      if (sha256(value) !== record.sha256) errors.push({ kind: 'protected-hash-mismatch', path: record.path });
    } catch {
      errors.push({ kind: 'protected-hash-mismatch', path: record.path });
    }
  }
  for (const transport of manifest.transportInputs) {
    try {
      const value = gitShow(repoRoot, manifest.base, transport.path);
      if (sha256(value) !== transport.sha256) errors.push({ kind: 'base-transport-hash-mismatch', path: transport.path });
    } catch {
      errors.push({ kind: 'base-transport-hash-mismatch', path: transport.path });
    }
  }
  return errors;
}

function deduplicateErrors(errors) {
  const result = [];
  const keys = new Set();
  for (const error of errors) {
    const key = `${error.kind}|${error.path || ''}`;
    if (!keys.has(key)) {
      keys.add(key);
      result.push(error);
    }
  }
  return result.sort((left, right) => (
    `${left.kind}|${left.path || ''}`.localeCompare(`${right.kind}|${right.path || ''}`, 'en')
  ));
}

export function checkLegacyRootMilestone({ legacyRoots, stage, manifest }) {
  const errors = [];
  const expected = manifest.stages?.[stage]?.legacyRoots;
  if (!expected) return [{ kind: 'unknown-task' }];
  for (const root of ['api', 'auth', 'components', 'pages']) {
    if (legacyRoots?.[root] !== expected[root].length) {
      errors.push({ kind: 'milestone-mismatch', path: root });
    }
  }
  return errors;
}

export function checkR10Scope({ repoRoot, task }, injected = {}) {
  const errors = [];
  let manifest;
  try {
    manifest = validateR10Manifest(injected.manifest ?? JSON.parse(fs.readFileSync(
      path.join(repoRoot, 'admin-web', 'architecture', 'r10-admin-boundaries.json'),
      'utf8',
    )));
  } catch {
    return { ok: false, task: '<invalid>', changedPaths: [], errors: [{ kind: 'manifest-invalid' }] };
  }
  const rank = taskNumber(task);
  if (rank === null || rank < 1 || rank > 11) errors.push({ kind: 'unknown-task' });
  let inputs = {};
  try {
    if (rank !== null && rank >= 1 && rank <= 11) {
      inputs = cachedDefaultInputs(path.resolve(repoRoot), manifest, task);
    }
  } catch {
    errors.push({ kind: 'scope-input-failure' });
  }
  inputs = { ...inputs, ...injected };
  const allowedPaths = new Set(
    manifest.allowedChangedPaths.filter((item) => manifest.firstTaskByPath.get(item) <= (rank ?? 0)),
  );
  const fence = checkChangedPathFence({
    repoRoot,
    changedPaths: inputs.changedPaths || [],
    allowedPaths,
  });
  errors.push(...fence.errors);
  errors.push(...protectedHashErrors(repoRoot, manifest, injected.protectedTextOverrides));

  const boundary = inputs.boundaryResult || { errors: [], legacyRoots: {} };
  if (boundary.errors?.length > 0) errors.push({ kind: 'admin-boundary-violation' });
  if (rank !== null && rank >= 1 && rank <= 11) {
    errors.push(...checkLegacyRootMilestone({
      legacyRoots: boundary.legacyRoots,
      stage: task,
      manifest,
    }));
  }
  for (const [kind, records, contract] of [
    ['base-request-inventory-drift', inputs.baseRequestRecords, manifest.requestInventory],
    ['candidate-request-inventory-drift', inputs.candidateRequestRecords, manifest.requestInventory],
    ['base-arabic-inventory-drift', inputs.baseArabicRecords, manifest.arabicLiteralInventory],
    ['candidate-arabic-inventory-drift', inputs.candidateArabicRecords, manifest.arabicLiteralInventory],
  ]) {
    if (!Array.isArray(records) || records.length !== contract.count || sha256(JSON.stringify(records)) !== contract.sha256) {
      errors.push({ kind });
    }
  }
  if (!inputs.testComparison?.ok) errors.push({ kind: 'existing-test-drift' });

  const uniqueErrors = deduplicateErrors(errors);
  return {
    ok: uniqueErrors.length === 0,
    task: rank === null ? '<invalid>' : task,
    changedPaths: fence.changedPaths,
    requestHash: Array.isArray(inputs.candidateRequestRecords) ? sha256(JSON.stringify(inputs.candidateRequestRecords)) : null,
    arabicHash: Array.isArray(inputs.candidateArabicRecords) ? sha256(JSON.stringify(inputs.candidateArabicRecords)) : null,
    testDiffs: inputs.testComparison?.errors?.length ?? 0,
    legacyRoots: boundary.legacyRoots || {},
    errors: uniqueErrors,
  };
}

function runCli(argv) {
  if (argv.length !== 2 || argv[0] !== '--task') {
    process.stderr.write('usage: check-r10-scope.mjs --task task-N\n');
    return 2;
  }
  const scriptFile = fileURLToPath(import.meta.url);
  const repoRoot = path.resolve(path.dirname(scriptFile), '..');
  const result = checkR10Scope({ repoRoot, task: argv[1] });
  if (!result.ok) {
    process.stderr.write(`R10 scope check failed (${result.errors.length} categories)\n`);
    for (const error of result.errors) {
      process.stderr.write(`${error.kind}${error.path ? `: ${error.path}` : ''}\n`);
    }
    return 1;
  }
  const roots = result.legacyRoots;
  process.stdout.write(
    `R10 scope check passed (${result.task}: api=${roots.api}, auth=${roots.auth}, components=${roots.components}, pages=${roots.pages})\n`,
  );
  return 0;
}

const invokedDirectly = process.argv[1]
  && pathToFileURL(path.resolve(process.argv[1])).href === import.meta.url;
if (invokedDirectly) process.exitCode = runCli(process.argv.slice(2));
