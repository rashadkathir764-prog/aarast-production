import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import ts from 'typescript';

const EXACT = Object.freeze({
  base: 'e560e5784278907dd6bf565327c3abfa0c9b8cab',
  design: '7abc4aecf3cfcceb4a6b601fcbe83377371a4aed58cb0cf06bce7a67d200f76e',
  plan: 'bb302356149839b4c5023d3d483cee7c5ebd957a43ac051db856cdce01e630c9',
  routes: 'a1e3ee774bafca860ee0e95461b9e2384c719fcc6c1fb1eb01d6b4b945672e5e',
  lockfile: 'e663c4fcb3f17a7aeb8923d3563d27ed543267d24f780ae939ba23d0dcb48757',
  requests: 'a740ff61ff987899c5f64520de2f74839c1257314383912929fd93970d77fbf9',
  arabic: 'db93ddc6d31d7e79410fb6e1d711e9cdb56ee69cfd2563dab549124bf398f0d0',
  transportInputs: '68da423fc5fa3e8750b39a1b77fde96d89b9f9244847904f38a1808646a7fce2',
  documents: '011005cf9d8714792973202440be6ff06223aa58aac17154d0d5fa0e21c73505',
  // Re-pinned 2026-10-25 (D56): the notifications feature was deleted with
  // its undrawn page; this pin, the screen list, the public surfaces, the
  // first tasks, the page's fate (now a delete) and its created api.ts
  // follow it. No other entry changed.
  allowedFeatureEdges: '01e8d3c5d719ce8d96042f8c46f02dd9bd3b1028b10c15443e767800ced908c1',
  compositionRoots: '18e34932763ebde50f663bae2c92aeb7a4aea4d7aaa2bc57d7a12247d6174aa5',
  // Re-pinned 2026-10-25: the a07 claims page ProviderClaimsPage (B-12).
  // Re-pinned 2026-10-25: the a17 plans page FeaturedPlacementsPage (B-43).
  // Re-pinned 2026-10-25: NotificationsPage left (D56).
  // Re-pinned 2026-10-26: the a12 bookings page BookingsPage (B-40).
  // Re-pinned 2026-10-26: the n07 photos page PhotosPage (B-16).
  // Re-pinned 2026-10-28: the n06 data requests page DataRequestsPage (A-15, D63).
  appScreenAllowlist: '75d1db9a67c93131d2d8a5c304b52a99ba709f93b31c7b8449c039fcc1dae64e',
  publicSurfaceFirstTask: '84cf74e0a2242688515d08b8c9809596267b16b1d45acd9c8de382499254f2cf',
  // Re-pinned 2026-10-11: providers gained setProviderVerified (V1 checklist 4.11).
  // Re-pinned 2026-10-15: providers gained createListedProvider (V1 checklist 4.18).
  // Re-pinned 2026-10-15: dashboard gained getSuccessReport (V1 checklist 4.21).
  // Re-pinned 2026-10-25: providers gained the review history, per-field
  // notes and the claims of a listing (B-01, B-02, B-12).
  // Re-pinned 2026-10-25: providers gained sentBackAfterRefusal, the one
  // reading of «كان مرفوض» the queue and the inbox share (B-02).
  // Re-pinned 2026-10-25: providers gained the featured placements, their
  // summary, recording one and ending one (B-43).
  // Re-pinned 2026-10-25: the notifications surface left with its page (D56).
  // Re-pinned 2026-10-25: moderation gained updateReviewReplyStatus, a10's
  // «أخفِ الرد» / «أظهر الرد» (B-09); no other surface changed.
  // Re-pinned 2026-10-26: moderation gained the a12 bookings read
  // (AdminBooking, AdminBookingQuery, getBookings, getBooking; B-40).
  // Re-pinned 2026-10-26: moderation gained the n07 photo review
  // (PortfolioPhoto, getPortfolioPhotos, decidePortfolioPhoto; B-16).
  // Re-pinned 2026-10-28: users gained the n06 data requests (DataRequests,
  // PendingDeletion, DataExportRequest, getDataRequests,
  // restoreAccountDeletion; A-15, D63).
  // Re-pinned 2026-11-07: moderation gained the reported assistant answers
  // (AssistantAnswerReport, getAssistantReports, resolveAssistantReport;
  // RA-ST-04, D95); no other surface changed.
  publicSurfaces: '09fd2e9ba0aa00fd692bf8beab87614ae6b14e1270b854e1d8b807f6b57bf4a9',
  // Re-pinned 2026-10-25 (D56): 19 old-kit components and the 2 tests that
  // belonged only to them (DataTable, SearchInput) changed fate from move to
  // delete; no other fate changed.
  sourceFates: '5d8e15adf9eda24d5db4754d708a3382b41597d91ef4f6c9493212f9e15255d3',
  createdTargets: 'c74d09c036596e387e9254d4c2c3f4be9281e76d04bc389eb484416dd9cfa600',
  stages: 'd799c92b42714969d4570dd925a34912ea05ec6b4b4107c4ef0fbb3c93e09ab6',
  paginationStages: 'b48499f606f88062ff02c30e90038fc9a06cd19bec30d5201f62428bafb07e35',
  changedPathFence: '6f07c7232cd8712d693ab7a7ff5d4e12ba287fc15c1747031369ac3f7276a4bc',
});

const EXACT_ADMIN_RUNTIME_SMOKE = Object.freeze({
  path: 'admin-web/scripts/admin-runtime-smoke.mjs',
  sha256: 'e896de8b6894faa14c402fab8bdd304c078278cdde0808db9cc6940af994ff48',
});

const EXACT_FEATURES = Object.freeze([
  'auth', 'audit', 'catalog', 'dashboard', 'moderation', 'providers', 'users',
]);
const EXACT_STAGE_KEYS = Object.freeze([
  'task-1', 'task-2', 'task-3', 'task-4', 'task-5', 'task-6',
  'task-7', 'task-8', 'task-9', 'task-10', 'task-11', 'strict',
]);
const LEGACY_ROOTS = Object.freeze(['api', 'auth', 'components', 'pages']);
const SOURCE_EXTENSIONS = Object.freeze(['.ts', '.tsx', '.mts', '.cts', '.js', '.jsx']);

function sha256(value) {
  return createHash('sha256').update(value).digest('hex');
}

function uniqueSorted(values) {
  return [...new Set(values)].sort();
}

function canonicalPath(value) {
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

function requireExactArray(value, expected) {
  if (!Array.isArray(value) || JSON.stringify(value) !== JSON.stringify(expected)) {
    throw new Error('manifest array mismatch');
  }
}

function taskNumber(stage) {
  if (stage === 'strict') return 11;
  const match = /^task-(\d+)$/.exec(stage || '');
  return match ? Number(match[1]) : null;
}

function deriveChangedPathFence(manifest) {
  const records = [];
  for (const group of Object.values(manifest.changedPathFence)) {
    if (!Array.isArray(group)) throw new Error('invalid changed path group');
    for (const record of group) records.push(record);
  }
  for (const fate of manifest.sourceFates) {
    if (fate.sourceFirstTask <= 11) {
      records.push({ path: `admin-web/src/${fate.source}`, task: fate.sourceFirstTask });
    }
    if (fate.target && fate.target !== fate.source && fate.targetTask > 0) {
      records.push({ path: `admin-web/src/${fate.target}`, task: fate.targetTask });
    }
  }
  for (const target of manifest.createdTargets) {
    records.push({ path: `admin-web/src/${target.path}`, task: target.task });
  }
  const firstTaskByPath = new Map();
  for (const record of records) {
    if (!canonicalPath(record.path) || !Number.isInteger(record.task) || record.task < 1 || record.task > 11) {
      throw new Error('invalid changed path record');
    }
    firstTaskByPath.set(
      record.path,
      Math.min(firstTaskByPath.get(record.path) ?? record.task, record.task),
    );
  }
  return {
    allowedChangedPaths: [...firstTaskByPath.keys()].sort(),
    firstTaskByPath,
  };
}

export function validateR10Manifest(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('manifest invalid');
  if (
    value.version !== 1
    || value.phase !== 'R10'
    || value.base !== EXACT.base
    || value.designSha256 !== EXACT.design
    || value.planSha256 !== EXACT.plan
    || value.adminRoutes?.count !== 22
    || value.adminRoutes?.path !== 'docs/frontend/ADMIN_ROUTES.md'
    || value.adminRoutes?.sha256 !== EXACT.routes
    || value.adminLockfile?.path !== 'admin-web/package-lock.json'
    || value.adminLockfile?.sha256 !== EXACT.lockfile
    || value.requestInventory?.count !== 62
    || value.requestInventory?.sha256 !== EXACT.requests
    || value.arabicLiteralInventory?.count !== 1020
    || value.arabicLiteralInventory?.sha256 !== EXACT.arabic
    || value.existingTests?.files !== 18
    || value.existingTests?.tests !== 96
  ) throw new Error('manifest identity mismatch');
  requireExactArray(value.features, EXACT_FEATURES);
  requireExactArray(Object.keys(value.stages || {}), EXACT_STAGE_KEYS);
  requireExactArray(
    Object.keys(value.adminRuntimeSmoke || {}),
    Object.keys(EXACT_ADMIN_RUNTIME_SMOKE),
  );
  if (
    value.adminRuntimeSmoke.path !== EXACT_ADMIN_RUNTIME_SMOKE.path
    || value.adminRuntimeSmoke.sha256 !== EXACT_ADMIN_RUNTIME_SMOKE.sha256
  ) throw new Error('manifest Admin runtime smoke mismatch');
  if (
    sha256(JSON.stringify(value.transportInputs)) !== EXACT.transportInputs
    || sha256(JSON.stringify(value.documents)) !== EXACT.documents
    || sha256(JSON.stringify(value.allowedFeatureEdges)) !== EXACT.allowedFeatureEdges
    || sha256(JSON.stringify(value.compositionRoots)) !== EXACT.compositionRoots
    || sha256(JSON.stringify(value.appScreenAllowlist)) !== EXACT.appScreenAllowlist
    || sha256(JSON.stringify(value.publicSurfaceFirstTask)) !== EXACT.publicSurfaceFirstTask
    || sha256(JSON.stringify(value.publicSurfaces)) !== EXACT.publicSurfaces
    || !Array.isArray(value.sourceFates)
    || value.sourceFates.length !== 78
    || sha256(JSON.stringify(value.sourceFates)) !== EXACT.sourceFates
    || sha256(JSON.stringify(value.createdTargets)) !== EXACT.createdTargets
    || sha256(JSON.stringify(value.stages)) !== EXACT.stages
    || sha256(JSON.stringify(value.paginationStages)) !== EXACT.paginationStages
    || sha256(JSON.stringify(value.changedPathFence)) !== EXACT.changedPathFence
  ) throw new Error('manifest inventory mismatch');
  for (const [owner, targets] of Object.entries(value.allowedFeatureEdges || {})) {
    if (!EXACT_FEATURES.includes(owner) || !Array.isArray(targets)) throw new Error('feature graph invalid');
    if (JSON.stringify(targets) !== JSON.stringify(uniqueSorted(targets))) throw new Error('feature graph invalid');
    if (targets.some((target) => !EXACT_FEATURES.includes(target) || target === owner)) {
      throw new Error('feature graph invalid');
    }
  }
  requireExactArray(Object.keys(value.allowedFeatureEdges || {}), EXACT_FEATURES);
  if (
    !Array.isArray(value.appScreenAllowlist)
    // 20 -> 21 (2026-10-26): the a12 bookings page (B-40).
    // 21 -> 22 (2026-10-26): the n07 photos page (B-16).
    // 22 -> 23 (2026-10-28): the n06 data requests page (A-15, D63).
    || value.appScreenAllowlist.length !== 23
    || JSON.stringify(value.appScreenAllowlist) !== JSON.stringify(uniqueSorted(value.appScreenAllowlist))
  ) throw new Error('screen allowlist invalid');
  for (const fate of value.sourceFates) {
    if (!canonicalPath(fate.source) || (fate.target !== null && !canonicalPath(fate.target))) {
      throw new Error('source fate path invalid');
    }
  }
  for (const stage of EXACT_STAGE_KEYS) {
    const legacyRoots = value.stages[stage]?.legacyRoots;
    if (!legacyRoots || JSON.stringify(Object.keys(legacyRoots)) !== JSON.stringify(LEGACY_ROOTS)) {
      throw new Error('stage legacy roots invalid');
    }
    for (const root of LEGACY_ROOTS) {
      if (
        !Array.isArray(legacyRoots[root])
        || new Set(legacyRoots[root]).size !== legacyRoots[root].length
        || legacyRoots[root].some((item) => !canonicalPath(item) || !item.startsWith(`${root}/`))
      ) {
        throw new Error('stage legacy roots invalid');
      }
    }
  }
  const { allowedChangedPaths, firstTaskByPath } = deriveChangedPathFence(value);
  if (value.allowedChangedPaths !== undefined) {
    if (JSON.stringify(value.allowedChangedPaths) !== JSON.stringify(allowedChangedPaths)) {
      throw new Error('changed path fence mismatch');
    }
  }
  return Object.freeze({ ...value, allowedChangedPaths, firstTaskByPath });
}

function scriptKind(relativePath) {
  return relativePath.endsWith('.tsx') ? ts.ScriptKind.TSX : ts.ScriptKind.TS;
}

export function parseAdminModuleSpecifiers({ sourceText, relativePath }) {
  const sourceFile = ts.createSourceFile(
    relativePath,
    sourceText,
    ts.ScriptTarget.Latest,
    true,
    scriptKind(relativePath),
  );
  const records = [];
  const add = (kind, node, options = {}) => {
    if (!node || !ts.isStringLiteralLike(node)) {
      records.push({
        kind,
        specifier: null,
        unsupported: true,
        typeOnly: Boolean(options.typeOnly),
        dynamic: Boolean(options.dynamic),
        line: node
          ? sourceFile.getLineAndCharacterOfPosition(node.getStart(sourceFile)).line + 1
          : 1,
      });
      return;
    }
    records.push({
      kind,
      specifier: node.text,
      unsupported: false,
      typeOnly: Boolean(options.typeOnly),
      dynamic: Boolean(options.dynamic),
      line: sourceFile.getLineAndCharacterOfPosition(node.getStart(sourceFile)).line + 1,
    });
  };
  const importMetaLoader = (expression) => {
    let current = expression;
    while (true) {
      while (
        ts.isParenthesizedExpression(current)
        || ts.isAsExpression(current)
        || ts.isTypeAssertionExpression(current)
        || ts.isNonNullExpression(current)
      ) current = current.expression;
      if (!ts.isPropertyAccessExpression(current) && !ts.isElementAccessExpression(current)) return false;
      const member = ts.isPropertyAccessExpression(current)
        ? current.name.text
        : ts.isStringLiteralLike(current.argumentExpression)
          ? current.argumentExpression.text
          : null;
      const computed = ts.isElementAccessExpression(current);
      let base = current.expression;
      while (
        ts.isParenthesizedExpression(base)
        || ts.isAsExpression(base)
        || ts.isTypeAssertionExpression(base)
        || ts.isNonNullExpression(base)
      ) base = base.expression;
      if (
        ts.isMetaProperty(base)
        && base.keywordToken === ts.SyntaxKind.ImportKeyword
        && base.name.text === 'meta'
      ) return computed || member === 'glob' || member === 'globEager';
      current = base;
    }
  };
  const visit = (node) => {
    if (ts.isImportDeclaration(node)) {
      add('import', node.moduleSpecifier, { typeOnly: node.importClause?.isTypeOnly });
    } else if (ts.isImportTypeNode(node)) {
      add(
        'import-type',
        ts.isLiteralTypeNode(node.argument) ? node.argument.literal : node.argument,
        { typeOnly: true },
      );
    } else if (ts.isExportDeclaration(node) && node.moduleSpecifier) {
      add('export', node.moduleSpecifier, { typeOnly: node.isTypeOnly });
    } else if (
      ts.isImportEqualsDeclaration(node)
      && ts.isExternalModuleReference(node.moduleReference)
    ) {
      add('import-equals', node.moduleReference.expression, { typeOnly: node.isTypeOnly });
    } else if (ts.isCallExpression(node)) {
      if (importMetaLoader(node.expression)) {
        add('import-meta-loader', null, { dynamic: true });
      } else if (ts.isIdentifier(node.expression) && node.expression.text === 'require') {
        add('require', node.arguments[0]);
      } else if (node.expression.kind === ts.SyntaxKind.ImportKeyword) {
        add('dynamic-import', node.arguments[0], { dynamic: true });
      }
    }
    ts.forEachChild(node, visit);
  };
  visit(sourceFile);
  return records;
}

function isInside(root, target) {
  const relative = path.relative(root, target);
  return relative === '' || (
    relative !== '..'
    && !relative.startsWith(`..${path.sep}`)
    && !path.isAbsolute(relative)
  );
}

function exactCaseExists(target) {
  const parsed = path.parse(path.resolve(target));
  let current = parsed.root;
  for (const segment of path.resolve(target).slice(parsed.root.length).split(path.sep).filter(Boolean)) {
    if (!fs.existsSync(current)) return false;
    const names = fs.readdirSync(current);
    if (!names.includes(segment)) return false;
    current = path.join(current, segment);
  }
  return true;
}

function caseInsensitiveCandidate(target) {
  const parent = path.dirname(target);
  if (!fs.existsSync(parent)) return false;
  const basename = path.basename(target).toLowerCase();
  return fs.readdirSync(parent).some((entry) => entry.toLowerCase() === basename);
}

function resolvedCandidates(base) {
  const extension = path.extname(base);
  if (SOURCE_EXTENSIONS.includes(extension)) return [base];
  return [
    base,
    ...SOURCE_EXTENSIONS.map((suffix) => `${base}${suffix}`),
    ...SOURCE_EXTENSIONS.map((suffix) => path.join(base, `index${suffix}`)),
  ];
}

export function resolveAdminSpecifier({ srcRoot, sourcePath, specifier }) {
  if (typeof specifier !== 'string' || specifier.length === 0) throw new Error('unsafe-specifier');
  if (path.posix.isAbsolute(specifier) || path.win32.isAbsolute(specifier) || /^[A-Za-z]:[\\/]/.test(specifier)) {
    throw new Error('unsafe-specifier');
  }
  if (!specifier.startsWith('.')) return { external: true };
  const clean = specifier.replace(/[?#].*$/, '');
  const absoluteRoot = path.resolve(srcRoot);
  const base = path.resolve(absoluteRoot, path.dirname(sourcePath), ...clean.split('/'));
  if (!isInside(absoluteRoot, base)) throw new Error('path-escape');
  let caseMismatch = false;
  for (const candidate of resolvedCandidates(base)) {
    if (!fs.existsSync(candidate)) {
      if (caseInsensitiveCandidate(candidate)) caseMismatch = true;
      continue;
    }
    if (!exactCaseExists(candidate)) throw new Error('case-mismatch');
    const realRoot = fs.realpathSync.native(absoluteRoot);
    const realTarget = fs.realpathSync.native(candidate);
    if (!isInside(realRoot, realTarget)) throw new Error('path-escape');
    return {
      external: false,
      targetPath: path.relative(absoluteRoot, candidate).replaceAll('\\', '/'),
    };
  }
  if (caseMismatch) throw new Error('case-mismatch');
  throw new Error('unresolved');
}

export function classifyAdminPath({ relativePath, manifest }) {
  const normalized = relativePath.replaceAll('\\', '/');
  const feature = /^features\/([^/]+)\//.exec(normalized)?.[1] ?? null;
  if (feature) {
    return {
      zone: manifest.features.includes(feature) ? 'feature' : 'unknown',
      feature,
      compositionRoot: false,
    };
  }
  if (normalized.startsWith('platform/')) return { zone: 'platform', feature: null, compositionRoot: false };
  if (normalized.startsWith('design_system/')) return { zone: 'design-system', feature: null, compositionRoot: false };
  if (normalized.startsWith('layout/')) return { zone: 'layout', feature: null, compositionRoot: true };
  if (normalized.startsWith('test/contracts/')) return { zone: 'test-contract', feature: null, compositionRoot: true };
  if (normalized === 'test/setup.ts') return { zone: 'test-setup', feature: null, compositionRoot: false };
  if (normalized === 'App.tsx' || normalized === 'main.tsx') {
    return { zone: 'composition-root', feature: null, compositionRoot: true };
  }
  if (normalized === 'vite-env.d.ts' || normalized.startsWith('styles/')) {
    return { zone: 'neutral', feature: null, compositionRoot: false };
  }
  const legacy = LEGACY_ROOTS.find((root) => normalized.startsWith(`${root}/`));
  if (legacy) return { zone: 'legacy', feature: null, compositionRoot: false, legacyRoot: legacy };
  return { zone: 'unknown', feature: null, compositionRoot: false };
}

function walkSourceTree(srcRoot) {
  const sourceFiles = [];
  const errors = [];
  const visit = (directory) => {
    for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
      const target = path.join(directory, entry.name);
      const relative = path.relative(srcRoot, target).replaceAll('\\', '/');
      if (entry.isSymbolicLink()) {
        errors.push({ kind: 'unsafe-source-link', source: relative });
      } else if (entry.isDirectory()) visit(target);
      else if (entry.isFile() && /\.(?:ts|tsx)$/.test(entry.name)) {
        sourceFiles.push(relative);
      }
    }
  };
  try {
    const rootStat = fs.lstatSync(srcRoot);
    if (rootStat.isSymbolicLink() || !rootStat.isDirectory()) {
      return { sourceFiles: [], errors: [{ kind: 'unsafe-source-root' }] };
    }
    visit(srcRoot);
  } catch {
    return { sourceFiles: [], errors: [{ kind: 'unsafe-source-root' }] };
  }
  return { sourceFiles: sourceFiles.sort(), errors };
}

function rootFiles(srcRoot, root) {
  const directory = path.join(srcRoot, root);
  if (!fs.existsSync(directory)) return [];
  const records = [];
  const visit = (current) => {
    for (const entry of fs.readdirSync(current, { withFileTypes: true })) {
      const target = path.join(current, entry.name);
      const relative = path.relative(srcRoot, target).replaceAll('\\', '/');
      if (entry.isDirectory() && !entry.isSymbolicLink()) visit(target);
      else records.push(relative);
    }
  };
  visit(directory);
  return records.sort();
}

function isFeatureScreen(targetPath, manifest) {
  return manifest.appScreenAllowlist.includes(targetPath)
    || /^features\/[^/]+\/[^/]*Page\.tsx$/.test(targetPath);
}

function exportedSymbols(sourceText, relativePath) {
  const sourceFile = ts.createSourceFile(relativePath, sourceText, ts.ScriptTarget.Latest, true, scriptKind(relativePath));
  const symbols = [];
  let wildcard = false;
  const addBinding = (binding) => {
    if (ts.isIdentifier(binding)) symbols.push(binding.text);
    else for (const element of binding.elements) {
      if (!ts.isOmittedExpression(element)) addBinding(element.name);
    }
  };
  for (const statement of sourceFile.statements) {
    if (ts.isExportAssignment(statement)) {
      symbols.push(statement.isExportEquals ? 'export=' : 'default');
      continue;
    }
    if (ts.isExportDeclaration(statement)) {
      if (!statement.exportClause) wildcard = true;
      else if (ts.isNamedExports(statement.exportClause)) {
        for (const element of statement.exportClause.elements) symbols.push(element.name.text);
      } else if (ts.isNamespaceExport(statement.exportClause)) {
        symbols.push(statement.exportClause.name.text);
      }
      continue;
    }
    const exported = statement.modifiers?.some((modifier) => modifier.kind === ts.SyntaxKind.ExportKeyword);
    if (!exported) continue;
    const defaultExport = statement.modifiers?.some((modifier) => modifier.kind === ts.SyntaxKind.DefaultKeyword);
    if (defaultExport) {
      symbols.push('default');
      continue;
    }
    if (
      ts.isFunctionDeclaration(statement)
      || ts.isClassDeclaration(statement)
      || ts.isInterfaceDeclaration(statement)
      || ts.isTypeAliasDeclaration(statement)
      || ts.isEnumDeclaration(statement)
    ) {
      if (statement.name) symbols.push(statement.name.text);
    } else if (ts.isVariableStatement(statement)) {
      for (const declaration of statement.declarationList.declarations) {
        addBinding(declaration.name);
      }
    } else if (ts.isModuleDeclaration(statement)) {
      symbols.push(statement.name.text);
    } else if (ts.isImportEqualsDeclaration(statement)) {
      symbols.push(statement.name.text);
    }
  }
  return { symbols: uniqueSorted(symbols), wildcard };
}

function isTypeOnlyOwnerDtoComposition({ sourceText, relativePath, specifier }) {
  const sourceFile = ts.createSourceFile(
    relativePath,
    sourceText,
    ts.ScriptTarget.Latest,
    true,
    scriptKind(relativePath),
  );
  const importedBindings = new Set();
  for (const statement of sourceFile.statements) {
    if (
      !ts.isImportDeclaration(statement)
      || !ts.isStringLiteralLike(statement.moduleSpecifier)
      || statement.moduleSpecifier.text !== specifier
      || !statement.importClause?.isTypeOnly
    ) continue;
    for (const element of statement.importClause.namedBindings?.elements ?? []) {
      importedBindings.add(element.name.text);
    }
  }
  if (importedBindings.size === 0) return false;

  let shadowsImportedBinding = false;
  const findImportedBindingShadow = (node) => {
    if (
      ts.isTypeParameterDeclaration(node)
      && ts.isIdentifier(node.name)
      && importedBindings.has(node.name.text)
    ) shadowsImportedBinding = true;
    if (!shadowsImportedBinding) ts.forEachChild(node, findImportedBindingShadow);
  };
  findImportedBindingShadow(sourceFile);
  if (shadowsImportedBinding) return false;

  const importedReferences = (node) => {
    const references = new Set();
    const visit = (current) => {
      if (
        ts.isTypeReferenceNode(current)
        && ts.isIdentifier(current.typeName)
        && importedBindings.has(current.typeName.text)
      ) references.add(current.typeName);
      if (
        ts.isExpressionWithTypeArguments(current)
        && ts.isIdentifier(current.expression)
        && importedBindings.has(current.expression.text)
      ) references.add(current.expression);
      ts.forEachChild(current, visit);
    };
    visit(node);
    return references;
  };
  const allImportedReferences = importedReferences(sourceFile);
  if (allImportedReferences.size === 0) return false;

  const isExported = (statement) => statement.modifiers?.some(
    (modifier) => modifier.kind === ts.SyntaxKind.ExportKeyword,
  );
  const directImportedTypeReference = (node) => (
    ts.isTypeReferenceNode(node)
    && ts.isIdentifier(node.typeName)
    && importedBindings.has(node.typeName.text)
    && (node.typeArguments?.length ?? 0) === 0
  );
  const mergeReferences = (target, source) => {
    for (const reference of source) target.add(reference);
  };
  const allowedMemberTypeReferences = (node) => {
    const references = importedReferences(node);
    if (references.size === 0) return references;
    if (directImportedTypeReference(node)) return references;
    if (ts.isUnionTypeNode(node)) {
      const allowed = new Set();
      for (const part of node.types) {
        const partReferences = allowedMemberTypeReferences(part);
        if (partReferences === null) return null;
        mergeReferences(allowed, partReferences);
      }
      return allowed;
    }
    if (ts.isParenthesizedTypeNode(node)) return allowedMemberTypeReferences(node.type);
    if (ts.isArrayTypeNode(node)) return allowedMemberTypeReferences(node.elementType);
    if (ts.isTupleTypeNode(node)) {
      const allowed = new Set();
      for (const element of node.elements) {
        const elementReferences = allowedMemberTypeReferences(element);
        if (elementReferences === null) return null;
        mergeReferences(allowed, elementReferences);
      }
      return allowed;
    }
    if (ts.isTypeLiteralNode(node)) return allowedOwnerMemberReferences(node.members);
    return null;
  };
  const allowedOwnerMemberReferences = (members) => {
    if (members.length === 0) return null;
    const allowed = new Set();
    for (const member of members) {
      if (!ts.isPropertySignature(member) || !member.type) return null;
      const memberReferences = allowedMemberTypeReferences(member.type);
      if (memberReferences === null) return null;
      mergeReferences(allowed, memberReferences);
    }
    return allowed;
  };
  const allowedOwnerDeclarationReferences = (statement) => {
    if (ts.isTypeAliasDeclaration(statement)) {
      if (ts.isTypeLiteralNode(statement.type)) {
        return allowedOwnerMemberReferences(statement.type.members);
      }
      if (!ts.isIntersectionTypeNode(statement.type) || statement.type.types.length !== 2) {
        return null;
      }
      const [base, ownerShape] = statement.type.types;
      if (!directImportedTypeReference(base) || !ts.isTypeLiteralNode(ownerShape)) return null;
      const ownerReferences = allowedOwnerMemberReferences(ownerShape.members);
      if (ownerReferences === null) return null;
      const allowed = new Set([base.typeName]);
      mergeReferences(allowed, ownerReferences);
      return allowed;
    }
    if (!ts.isInterfaceDeclaration(statement)) return null;
    const ownerReferences = allowedOwnerMemberReferences(statement.members);
    if (ownerReferences === null) return null;
    const extendsTypes = statement.heritageClauses
      ?.filter((clause) => clause.token === ts.SyntaxKind.ExtendsKeyword)
      .flatMap((clause) => [...clause.types]) ?? [];
    if (extendsTypes.length === 0) return ownerReferences;
    if (
      extendsTypes.length !== 1
      || !ts.isIdentifier(extendsTypes[0].expression)
      || !importedBindings.has(extendsTypes[0].expression.text)
      || (extendsTypes[0].typeArguments?.length ?? 0) > 0
    ) {
      return null;
    }
    ownerReferences.add(extendsTypes[0].expression);
    return ownerReferences;
  };

  const allowedImportedReferences = new Set();
  for (const statement of sourceFile.statements) {
    if (ts.isImportDeclaration(statement)) continue;
    if (ts.isExportDeclaration(statement) && !statement.moduleSpecifier) return false;
    const statementReferences = importedReferences(statement);
    if (statementReferences.size === 0) continue;
    if (!isExported(statement)) return false;
    const allowed = allowedOwnerDeclarationReferences(statement);
    if (allowed === null || allowed.size !== statementReferences.size) return false;
    for (const reference of statementReferences) {
      if (!allowed.has(reference)) return false;
    }
    mergeReferences(allowedImportedReferences, allowed);
  }
  const consumedImportedBindings = new Set(
    [...allowedImportedReferences].map((reference) => reference.text),
  );
  return allImportedReferences.size > 0
    && allImportedReferences.size === allowedImportedReferences.size
    && [...allImportedReferences].every((reference) => allowedImportedReferences.has(reference))
    && consumedImportedBindings.size === importedBindings.size
    && [...importedBindings].every((binding) => consumedImportedBindings.has(binding));
}

function pathEntryState(srcRoot, relativePath) {
  const absoluteRoot = path.resolve(srcRoot);
  let current = absoluteRoot;
  try {
    const rootStat = fs.lstatSync(current);
    if (rootStat.isSymbolicLink() || !rootStat.isDirectory()) return 'unsafe';
    for (const segment of relativePath.split('/')) {
      current = path.join(current, segment);
      const stat = fs.lstatSync(current);
      if (stat.isSymbolicLink()) return 'unsafe';
    }
    if (!exactCaseExists(current)) return 'unsafe';
    const realRoot = fs.realpathSync.native(absoluteRoot);
    const realTarget = fs.realpathSync.native(current);
    if (!isInside(realRoot, realTarget)) return 'unsafe';
    return fs.lstatSync(current).isFile() ? 'file' : 'unsafe';
  } catch (error) {
    return error?.code === 'ENOENT' ? 'missing' : 'unsafe';
  }
}

function stageRank(stage) {
  return stage === 'strict' ? 11 : taskNumber(stage);
}

function inventoryErrors(srcRoot, manifest, stage) {
  const errors = [];
  const rank = stageRank(stage);
  const expected = manifest.stages[stage];
  if (!expected || rank === null) return [{ kind: 'unknown-stage' }];
  let legacyMismatch = false;
  for (const root of LEGACY_ROOTS) {
    const actual = rootFiles(srcRoot, root);
    const strictRootStillExists = stage === 'strict' && fs.existsSync(path.join(srcRoot, root));
    if (
      strictRootStillExists
      || JSON.stringify(actual) !== JSON.stringify(uniqueSorted(expected.legacyRoots[root]))
    ) {
      errors.push({ kind: 'legacy-root-inventory-mismatch', source: root });
      legacyMismatch = true;
    }
  }
  if (stage === 'strict' && legacyMismatch) return errors;
  for (const fate of manifest.sourceFates || []) {
    const sourceState = pathEntryState(srcRoot, fate.source);
    if (fate.action.startsWith('retain')) {
      if (sourceState !== 'file') errors.push({ kind: 'source-fate-mismatch', source: fate.source });
      continue;
    }
    const moved = rank >= fate.targetTask;
    if (moved) {
      if (sourceState !== 'missing') errors.push({ kind: 'source-fate-mismatch', source: fate.source });
      if (fate.target) {
        if (pathEntryState(srcRoot, fate.target) !== 'file') {
          errors.push({ kind: 'target-fate-mismatch', target: fate.target });
        }
      }
    } else if (sourceState !== 'file') {
      errors.push({ kind: 'source-fate-mismatch', source: fate.source });
    }
  }
  for (const target of manifest.createdTargets || []) {
    const state = pathEntryState(srcRoot, target.path);
    const exists = state === 'file';
    if ((rank >= target.task) !== exists) {
      errors.push({ kind: 'created-target-mismatch', target: target.path });
    } else if (rank < target.task && state === 'unsafe') {
      errors.push({ kind: 'created-target-mismatch', target: target.path });
    }
  }
  return errors;
}

export function scanAdminBoundaries({ srcRoot, manifest, stage }) {
  const sourceTree = walkSourceTree(srcRoot);
  const sourceFiles = sourceTree.sourceFiles;
  const errors = [...sourceTree.errors, ...inventoryErrors(srcRoot, manifest, stage)];
  const edges = new Set();
  const rank = stageRank(stage) ?? 0;
  for (const sourcePath of sourceFiles) {
    const sourceClass = classifyAdminPath({ relativePath: sourcePath, manifest });
    if (sourceClass.zone === 'unknown') {
      errors.push({ kind: 'unknown-admin-zone', source: sourcePath });
      continue;
    }
    const sourceText = fs.readFileSync(path.join(srcRoot, ...sourcePath.split('/')), 'utf8');
    for (const record of parseAdminModuleSpecifiers({ sourceText, relativePath: sourcePath })) {
      if (record.unsupported) {
        errors.push({ kind: 'computed-module-specifier', source: sourcePath });
        continue;
      }
      if (path.posix.isAbsolute(record.specifier) || path.win32.isAbsolute(record.specifier) || /^[A-Za-z]:[\\/]/.test(record.specifier)) {
        errors.push({ kind: 'unsafe-first-party-specifier', source: sourcePath });
        continue;
      }
      let resolved;
      try {
        resolved = resolveAdminSpecifier({ srcRoot, sourcePath, specifier: record.specifier });
      } catch (error) {
        const kind = error.message === 'path-escape'
          ? 'relative-import-escape'
          : error.message === 'case-mismatch'
            ? 'case-mismatched-relative-import'
            : error.message === 'unsafe-specifier'
              ? 'unsafe-first-party-specifier'
              : 'unresolved-relative-import';
        errors.push({ kind, source: sourcePath });
        continue;
      }
      if (resolved.external) continue;
      const targetPath = resolved.targetPath;
      const targetClass = classifyAdminPath({ relativePath: targetPath, manifest });
      if (targetClass.zone === 'unknown') {
        errors.push({ kind: 'unknown-admin-zone', source: sourcePath, target: targetPath });
        continue;
      }
      if (targetClass.zone === 'test-contract' && sourceClass.zone !== 'test-contract') {
        errors.push({ kind: 'production-imports-test-contract', source: sourcePath, target: targetPath });
      }
      if (sourceClass.zone === 'test-contract') continue;
      if (sourceClass.zone === 'legacy' || targetClass.zone === 'legacy') continue;
      if (sourceClass.zone === 'platform' && ['feature', 'design-system'].includes(targetClass.zone)) {
        errors.push({ kind: 'platform-dependency-violation', source: sourcePath, target: targetPath });
      }
      if (sourceClass.zone === 'design-system' && ['feature', 'layout'].includes(targetClass.zone)) {
        errors.push({ kind: 'design-system-dependency-violation', source: sourcePath, target: targetPath });
      }
      if (targetClass.zone === 'feature' && sourceClass.zone !== 'feature') {
        if (isFeatureScreen(targetPath, manifest)) {
          if (sourcePath === 'App.tsx') {
            if (!manifest.appScreenAllowlist.includes(targetPath)) {
              errors.push({ kind: 'unapproved-app-screen-import', source: sourcePath, target: targetPath });
            }
          } else {
            errors.push({ kind: 'feature-screen-import-outside-app', source: sourcePath, target: targetPath });
          }
        } else if (!['composition-root', 'layout'].includes(sourceClass.zone)) {
          errors.push({ kind: 'unapproved-production-composition', source: sourcePath, target: targetPath });
        } else if (targetPath !== `features/${targetClass.feature}/api.ts`) {
          errors.push({ kind: 'deep-feature-import-from-composition-root', source: sourcePath, target: targetPath });
        }
      }
      if (
        sourceClass.zone === 'feature'
        && targetClass.zone === 'feature'
        && sourceClass.feature !== targetClass.feature
      ) {
        const edge = `${sourceClass.feature} -> ${targetClass.feature}`;
        edges.add(edge);
        if (targetPath !== `features/${targetClass.feature}/api.ts`) {
          errors.push({ kind: 'deep-cross-feature-import', source: sourcePath, target: targetPath });
        }
        if (!(manifest.allowedFeatureEdges[sourceClass.feature] || []).includes(targetClass.feature)) {
          errors.push({ kind: 'undeclared-feature-edge', source: sourcePath, target: targetPath });
        }
        if (
          sourcePath.endsWith('/api.ts')
          && !(
            record.kind === 'import'
            && record.typeOnly
            && (manifest.allowedFeatureEdges[sourceClass.feature] || []).includes(targetClass.feature)
            && isTypeOnlyOwnerDtoComposition({
              sourceText,
              relativePath: sourcePath,
              specifier: record.specifier,
            })
          )
        ) {
          errors.push({ kind: 'cross-feature-public-re-export', source: sourcePath, target: targetPath });
        }
      }
    }
    if (sourceClass.zone === 'feature' && sourcePath === `features/${sourceClass.feature}/api.ts`) {
      const exported = exportedSymbols(sourceText, sourcePath);
      if (exported.wildcard) errors.push({ kind: 'wildcard-public-export', source: sourcePath });
      const firstTask = manifest.publicSurfaceFirstTask?.[sourceClass.feature] ?? 99;
      if (rank >= firstTask) {
        const expectedSymbols = uniqueSorted(manifest.publicSurfaces?.[sourceClass.feature] || []);
        if (JSON.stringify(exported.symbols) !== JSON.stringify(expectedSymbols)) {
          errors.push({ kind: 'public-surface-mismatch', source: sourcePath });
        }
      }
    }
  }
  const uniqueErrors = [];
  const keys = new Set();
  for (const error of errors) {
    const key = `${error.kind}|${error.source || ''}|${error.target || ''}`;
    if (!keys.has(key)) {
      keys.add(key);
      uniqueErrors.push(error);
    }
  }
  uniqueErrors.sort((left, right) => (
    `${left.kind}|${left.source || ''}|${left.target || ''}`
      .localeCompare(`${right.kind}|${right.source || ''}|${right.target || ''}`, 'en')
  ));
  const legacyRoots = Object.fromEntries(LEGACY_ROOTS.map((root) => [root, rootFiles(srcRoot, root).length]));
  return {
    errors: uniqueErrors,
    edges: [...edges].sort(),
    legacyRoots,
    publicApis: sourceFiles.filter((file) => /^features\/[^/]+\/api\.ts$/.test(file)).sort(),
    sourceFiles,
  };
}

function loadManifest(adminRoot) {
  return validateR10Manifest(JSON.parse(fs.readFileSync(
    path.join(adminRoot, 'architecture', 'r10-admin-boundaries.json'),
    'utf8',
  )));
}

function runCli(argv) {
  const stage = argv.length === 2 && argv[0] === '--stage'
    ? argv[1]
    : argv.length === 1 && argv[0] === '--strict'
      ? 'strict'
      : null;
  if (!stage) {
    process.stderr.write('usage: admin-boundaries.mjs --stage task-N | --strict\n');
    return 2;
  }
  try {
    const scriptFile = fileURLToPath(import.meta.url);
    const adminRoot = path.resolve(path.dirname(scriptFile), '..');
    const manifest = loadManifest(adminRoot);
    const result = scanAdminBoundaries({ srcRoot: path.join(adminRoot, 'src'), manifest, stage });
    if (result.errors.length > 0) {
      process.stderr.write(`Admin boundary scan failed (${result.errors.length} violations)\n`);
      for (const error of result.errors) {
        process.stderr.write(`${error.kind}${error.source ? `: ${error.source}` : ''}\n`);
      }
      return 1;
    }
    const roots = result.legacyRoots;
    process.stdout.write(
      `Admin boundary scan passed (${stage}: api=${roots.api}, auth=${roots.auth}, components=${roots.components}, pages=${roots.pages})\n`,
    );
    return 0;
  } catch {
    process.stderr.write('Admin boundary configuration error\n');
    return 2;
  }
}

const invokedDirectly = process.argv[1]
  && pathToFileURL(path.resolve(process.argv[1])).href === import.meta.url;
if (invokedDirectly) process.exitCode = runCli(process.argv.slice(2));
