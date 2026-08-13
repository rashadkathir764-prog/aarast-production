const { execFileSync } = require('node:child_process');
const crypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { pathToFileURL } = require('node:url');
const { readPrismaSchemaFiles } = require('./schema-files.cjs');

const R2_BASE = '8ba0db78ac669bd6d17de878b77a4d1e6c5e542d';
const R2_BASE_SCHEMA_PATH = ['backend', 'prisma', `schema${'.prisma'}`].join('/');
const CLI_FAILURE = 'ERROR - R2 schema scope check failed';
const CLI_SCOPE_FAILURE = 'FAIL - R2 schema scope check';

const R2_ALLOWED_PATHS = new Set([
  'ARCHITECTURE.md',
  'CHANGELOG.md',
  'backend/Dockerfile',
  'backend/architecture/prisma-schema-layout.json',
  'backend/prisma.config.ts',
  R2_BASE_SCHEMA_PATH,
  'backend/prisma/schema/_base.prisma',
  'backend/prisma/schema/backoffice.prisma',
  'backend/prisma/schema/catalog.prisma',
  'backend/prisma/schema/collaboration.prisma',
  'backend/prisma/schema/finance.prisma',
  'backend/prisma/schema/guests.prisma',
  'backend/prisma/schema/identity.prisma',
  'backend/prisma/schema/marketplace.prisma',
  'backend/prisma/schema/media.prisma',
  'backend/prisma/schema/messaging.prisma',
  'backend/prisma/schema/notifications.prisma',
  'backend/prisma/schema/planning.prisma',
  'backend/prisma/schema/platform.prisma',
  'backend/prisma/schema/tasks.prisma',
  'backend/scripts/architecture/ownership-scan.cjs',
  'backend/scripts/prisma/dmmf-fingerprint.cjs',
  'backend/scripts/prisma/r2-schema-scope.cjs',
  'backend/scripts/prisma/schema-files.cjs',
  'backend/scripts/smoke/contributor-history-migration-smoke.js',
  'backend/test/admin-auth-session-security.test.ts',
  'backend/test/admin-rbac-audit.test.ts',
  'backend/test/architecture-ownership.test.ts',
  'backend/test/architecture-r2-schema-layout.test.ts',
  'backend/test/auth-refresh-wiring.test.ts',
  'backend/test/contribution-history-migration.test.ts',
  'backend/test/financial-ledger.test.ts',
  'backend/test/legacy-finance-removal.test.ts',
  'backend/test/marketplace-presenter.test.ts',
  'backend/test/outbox-logic.test.ts',
  'backend/test/prisma-dmmf-fingerprint.test.ts',
  'backend/test/prisma-r2-manifest.test.ts',
  'backend/test/prisma-r2-schema-scope.test.ts',
  'backend/test/prisma-schema-files.test.ts',
  'backend/test/provider-chat-logic.test.ts',
  'backend/test/reference-catalogs.test.ts',
  'backend/test/support/live-prisma-schema.ts',
  'docs/README.md',
  'docs/SCRIPTS.md',
  'docs/backend/DATABASE.md',
  'docs/project/DECISIONS.md',
  'docs/project/EXECUTION_PLAN.md',
  'docs/project/STATUS.md',
  'docs/qa/README.md',
  'docs/superpowers/plans/2026-08-13-modular-monolith-r2-prisma-schema.md',
  'docs/superpowers/specs/2026-08-13-modular-monolith-r2-prisma-schema-design.md',
  'scripts/docs-sync.mjs',
]);

const NEW_TEST_PATHS = new Set([
  'backend/test/architecture-r2-schema-layout.test.ts',
  'backend/test/prisma-dmmf-fingerprint.test.ts',
  'backend/test/prisma-r2-manifest.test.ts',
  'backend/test/prisma-r2-schema-scope.test.ts',
  'backend/test/prisma-schema-files.test.ts',
  'backend/test/support/live-prisma-schema.ts',
]);

const EXISTING_SCHEMA_READER_TESTS = new Set([
  'backend/test/admin-auth-session-security.test.ts',
  'backend/test/admin-rbac-audit.test.ts',
  'backend/test/architecture-ownership.test.ts',
  'backend/test/auth-refresh-wiring.test.ts',
  'backend/test/contribution-history-migration.test.ts',
  'backend/test/financial-ledger.test.ts',
  'backend/test/legacy-finance-removal.test.ts',
  'backend/test/marketplace-presenter.test.ts',
  'backend/test/outbox-logic.test.ts',
  'backend/test/provider-chat-logic.test.ts',
  'backend/test/reference-catalogs.test.ts',
]);

const SCHEMA_SPLIT_ACTIVATION_PATHS = new Set([
  'backend/Dockerfile',
  'backend/scripts/architecture/ownership-scan.cjs',
  'backend/scripts/prisma/schema-files.cjs',
  'backend/scripts/smoke/contributor-history-migration-smoke.js',
  'backend/test/architecture-r2-schema-layout.test.ts',
  'backend/test/prisma-r2-manifest.test.ts',
  'backend/test/prisma-schema-files.test.ts',
  'backend/test/support/live-prisma-schema.ts',
  'scripts/docs-sync.mjs',
  ...EXISTING_SCHEMA_READER_TESTS,
]);

class ScopeViolation extends Error {}

function failScope() {
  throw new ScopeViolation('scope violation');
}

function normalizeRepositoryPath(value) {
  if (typeof value !== 'string') throw new Error('invalid repository path');
  const normalized = value.replaceAll('\\', '/');
  const segments = normalized.split('/');
  if (
    normalized.length === 0
    || normalized.startsWith('/')
    || /^[A-Za-z]:\//.test(normalized)
    || normalized.includes('\0')
    || segments.includes('..')
  ) {
    throw new Error('invalid repository path');
  }
  return normalized;
}

function parseZeroSeparated(output) {
  return String(output).split('\0').filter((entry) => entry.length > 0);
}

function defaultRunGit(repoRoot) {
  return (args) => execFileSync('git', args, {
    cwd: repoRoot,
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
    windowsHide: true,
  });
}

function collectChangedPaths({ runGit, baseRef }) {
  runGit(['cat-file', '-e', `${baseRef}^{commit}`]);
  const changed = parseZeroSeparated(runGit([
    'diff', '--name-only', '-z', '--no-renames', '--diff-filter=ACMRDTUXB', baseRef, '--',
  ])).map(normalizeRepositoryPath);
  const untracked = parseZeroSeparated(runGit([
    'ls-files', '--others', '--exclude-standard', '-z',
  ])).map(normalizeRepositoryPath);
  return [...new Set([...changed, ...untracked])].sort();
}

function parseTopLevelBlocks(schemaText) {
  const lines = String(schemaText).replace(/\r\n?|\n/g, '\n').split('\n');
  const blocks = new Map();
  const covered = new Set();
  for (let index = 0; index < lines.length; index += 1) {
    const match = /^\s*(generator|datasource|enum|model)\s+([A-Za-z][A-Za-z0-9_]*)\s*\{/.exec(lines[index]);
    if (!match) continue;
    const blockStart = index;
    let commentStart = blockStart;
    while (commentStart > 0 && /^\s*\/\//.test(lines[commentStart - 1])) commentStart -= 1;
    let braces = 0;
    let end = index;
    for (; end < lines.length; end += 1) {
      braces += (lines[end].match(/\{/g) || []).length;
      braces -= (lines[end].match(/\}/g) || []).length;
      if (braces === 0) break;
      if (braces < 0) failScope();
    }
    if (braces !== 0 || end >= lines.length) failScope();
    const key = `${match[1]}:${match[2]}`;
    if (blocks.has(key)) failScope();
    blocks.set(key, lines.slice(commentStart, end + 1).join('\n'));
    for (let coveredIndex = commentStart; coveredIndex <= end; coveredIndex += 1) covered.add(coveredIndex);
    index = end;
  }
  for (let index = 0; index < lines.length; index += 1) {
    if (!covered.has(index) && lines[index].trim().length > 0) failScope();
  }
  return blocks;
}

function assertSameBlockSet(baseSchema, candidateSchema) {
  const baseBlocks = parseTopLevelBlocks(baseSchema);
  const candidateBlocks = parseTopLevelBlocks(candidateSchema);
  if (baseBlocks.size !== candidateBlocks.size) failScope();
  for (const [key, baseBlock] of baseBlocks) {
    if (candidateBlocks.get(key) !== baseBlock) failScope();
  }
}

function readCandidateSchema(repoRoot) {
  return readPrismaSchemaFiles({
    backendRoot: path.join(repoRoot, 'backend'),
  }).combinedText;
}

function normalizedLines(value) {
  return String(value).replace(/\r\n?|\n/g, '\n');
}

function dockerDeltaIsApproved(runGit, baseRef, repoRoot) {
  const diff = String(runGit([
    'diff', '--no-ext-diff', '--unified=0', baseRef, '--', 'backend/Dockerfile',
  ]));
  const additions = [];
  const removals = [];
  for (const line of diff.split(/\r\n|\r|\n/)) {
    if (line.startsWith('+++') || line.startsWith('---')) continue;
    if (line.startsWith('+')) additions.push(line.slice(1));
    if (line.startsWith('-')) removals.push(line.slice(1));
  }
  if (additions.length === 0 && removals.length === 0) return true;
  if (!(removals.length === 0
    && additions.length === 2
    && additions[0] === 'COPY prisma.config.ts ./'
    && additions[1] === 'COPY --from=build /app/prisma.config.ts ./')) return false;

  const baseLines = normalizedLines(runGit(['show', `${baseRef}:backend/Dockerfile`])).split('\n');
  const expectedLines = [...baseLines];
  const buildPrismaIndex = expectedLines.indexOf('COPY prisma ./prisma');
  const runtimePrismaIndex = expectedLines.indexOf('COPY --from=build /app/prisma ./prisma');
  if (buildPrismaIndex < 0 || runtimePrismaIndex < 0 || buildPrismaIndex === runtimePrismaIndex) return false;
  expectedLines.splice(buildPrismaIndex + 1, 0, 'COPY prisma.config.ts ./');
  const runtimeIndexAfterBuildInsert = runtimePrismaIndex > buildPrismaIndex ? runtimePrismaIndex + 1 : runtimePrismaIndex;
  expectedLines.splice(runtimeIndexAfterBuildInsert + 1, 0, 'COPY --from=build /app/prisma.config.ts ./');
  const candidate = fs.readFileSync(path.join(repoRoot, 'backend', 'Dockerfile'), 'utf8');
  return normalizedLines(candidate) === expectedLines.join('\n');
}

function retiredSchemaRemainsPlainFile(repoRoot) {
  const retiredPath = path.join(repoRoot, R2_BASE_SCHEMA_PATH);
  try {
    const state = fs.lstatSync(retiredPath);
    return state.isFile()
      && !state.isSymbolicLink()
      && fs.realpathSync(retiredPath) === retiredPath;
  } catch {
    return false;
  }
}

function schemaSplitIsInactive(repoRoot, paths) {
  return retiredSchemaRemainsPlainFile(repoRoot)
    && !paths.some((repositoryPath) => (
      repositoryPath.startsWith('backend/prisma/schema/')
      || SCHEMA_SPLIT_ACTIVATION_PATHS.has(repositoryPath)
    ));
}

function prismaConfigDeltaIsApproved(runGit, baseRef, repoRoot, paths) {
  const repositoryPath = 'backend/prisma.config.ts';
  let base;
  let candidate;
  try {
    base = normalizedLines(runGit(['show', `${baseRef}:${repositoryPath}`]));
    candidate = normalizedLines(fs.readFileSync(path.join(repoRoot, repositoryPath), 'utf8'));
  } catch {
    return false;
  }
  if (candidate === base) return schemaSplitIsInactive(repoRoot, paths);
  const retired = ['schema: "prisma/schema', '.prisma"'].join('');
  const desired = 'schema: "prisma/schema"';
  const first = base.indexOf(retired);
  if (
    first < 0
    || base.indexOf(retired, first + retired.length) >= 0
    || base.includes(desired)
  ) return false;
  const expected = `${base.slice(0, first)}${desired}${base.slice(first + retired.length)}`;
  return candidate === expected;
}

function basePathExists(runGit, baseRef, repositoryPath) {
  try {
    runGit(['cat-file', '-e', `${baseRef}:${repositoryPath}`]);
    return true;
  } catch {
    return false;
  }
}

function changedHunkLines(runGit, baseRef, repositoryPath) {
  const diff = String(runGit([
    'diff', '--no-ext-diff', '--unified=0', baseRef, '--', repositoryPath,
  ]));
  const additions = [];
  const removals = [];
  for (const line of diff.split(/\r\n|\r|\n/)) {
    if (line.startsWith('diff --git ') || line.startsWith('index ') || line.startsWith('+++') || line.startsWith('---') || line.startsWith('@@') || line.length === 0) continue;
    if (line.startsWith('+')) additions.push(line.slice(1).trim());
    else if (line.startsWith('-')) removals.push(line.slice(1).trim());
    else return null;
  }
  return { additions, removals };
}

function schemaReadDeclarations(lines) {
  const source = lines.join('\n').trim();
  const declarations = [];
  const expression = /(?:const|let)\s+([A-Za-z][A-Za-z0-9_]*)\s*=\s*(?:read|readFileSync)\(\s*[\s\S]*?['"](?:[^'"]*\/)?schema\.prisma['"][\s\S]*?\);/g;
  let match;
  while ((match = expression.exec(source)) !== null) {
    declarations.push({ name: match[1], text: match[0] });
  }
  if (declarations.length === 0 || declarations.map((entry) => entry.text).join('\n') !== source) return null;
  return declarations;
}

function testHunkIsMechanical(runGit, baseRef, repoRoot, repositoryPath) {
  const changed = changedHunkLines(runGit, baseRef, repositoryPath);
  if (changed === null) return false;
  if (repositoryPath === 'backend/test/architecture-ownership.test.ts') {
    return architectureFixtureHunkIsMechanical(runGit, baseRef, repoRoot, repositoryPath);
  }
  const removed = schemaReadDeclarations(changed.removals);
  if (removed === null || changed.additions.length !== removed.length + 1) return false;
  const expectedImport = "import { readLivePrismaSchema } from './support/live-prisma-schema';";
  const expectedReads = new Set(removed.map(({ name }) => `const ${name} = readLivePrismaSchema();`));
  return changed.additions.includes(expectedImport)
    && changed.additions.filter((line) => line !== expectedImport).every((line) => expectedReads.has(line))
    && new Set(changed.additions.filter((line) => line !== expectedImport)).size === expectedReads.size;
}

function replaceOnce(value, expression, replacement) {
  let count = 0;
  const result = value.replace(expression, (...args) => {
    count += 1;
    return typeof replacement === 'function' ? replacement(...args) : replacement;
  });
  return count === 1 ? result : null;
}

function nodeFsImportMembers(source) {
  const match = /^import\s*\{([^}]*)\}\s*from\s*['"]node:fs['"];?/m.exec(source);
  if (match === null) return null;
  const members = match[1].split(',').map((entry) => entry.trim()).filter(Boolean);
  if (members.some((member) => !/^[A-Za-z][A-Za-z0-9_]*$/.test(member))) return null;
  return { text: match[0], members };
}

function architectureFixtureHunkIsMechanical(runGit, baseRef, repoRoot, repositoryPath) {
  let base;
  let candidate;
  try {
    base = normalizedLines(runGit(['show', `${baseRef}:${repositoryPath}`]));
    candidate = normalizedLines(fs.readFileSync(path.join(repoRoot, repositoryPath), 'utf8'));
  } catch {
    return false;
  }
  const baseImport = nodeFsImportMembers(base);
  const candidateImport = nodeFsImportMembers(candidate);
  if (baseImport === null || candidateImport === null) return false;
  const baseMembers = [...baseImport.members].sort();
  const candidateMembers = [...candidateImport.members].sort();
  const addedMembers = candidateMembers.filter((member) => !baseMembers.includes(member));
  if (
    baseMembers.some((member) => !candidateMembers.includes(member))
    || addedMembers.length !== 2
    || addedMembers[0] !== 'copyFileSync'
    || addedMembers[1] !== 'cpSync'
  ) return false;
  candidate = candidate.replace(candidateImport.text, baseImport.text);

  const helperImport = "import { readLivePrismaSchema } from './support/live-prisma-schema';";
  if (!candidate.includes(helperImport) || base.includes(helperImport)) return false;
  candidate = replaceOnce(candidate, `${helperImport}\n`, '');
  if (candidate === null) return false;

  const schemaRead = /const\s+schemaText\s*=\s*readFileSync\(\s*path\.join\(backendRoot,\s*['"]prisma['"],\s*['"]schema\.prisma['"]\),\s*['"]utf8['"]\s*\);\s*\n/;
  const baseRead = schemaRead.exec(base);
  if (baseRead === null || schemaRead.test(candidate)) return false;
  candidate = replaceOnce(candidate, /const\s+schemaText\s*=\s*readLivePrismaSchema\(\);\s*\n/, baseRead[0]);
  if (candidate === null) return false;
  const expectedBase = base;

  const fixtureWrite = /\s*write\(root,\s*['"]backend\/prisma\/schema\.prisma['"],\s*schemaText\);/;
  const folderCopy = /\s*cpSync\(\s*path\.join\(backendRoot,\s*['"]prisma['"],\s*['"]schema['"]\),\s*path\.join\(fixtureBackend,\s*['"]prisma['"],\s*['"]schema['"]\),\s*\{\s*recursive:\s*true\s*\},?\s*\);/;
  const fixtureArchitectureMkdir = /\s*mkdirSync\(path\.join\(fixtureBackend,\s*['"]architecture['"]\),\s*\{\s*recursive:\s*true\s*\}\);/;
  const manifestCopy = /\s*copyFileSync\(\s*path\.join\(backendRoot,\s*['"]architecture['"],\s*['"]prisma-schema-layout\.json['"]\),\s*path\.join\(fixtureBackend,\s*['"]architecture['"],\s*['"]prisma-schema-layout\.json['"]\),\s*\);/;
  const baseWrite = fixtureWrite.exec(expectedBase);
  if (baseWrite === null) return false;
  candidate = replaceOnce(candidate, folderCopy, baseWrite[0]);
  if (candidate === null) return false;
  candidate = replaceOnce(candidate, fixtureArchitectureMkdir, '');
  if (candidate === null) return false;
  candidate = replaceOnce(candidate, manifestCopy, '');
  return candidate !== null && candidate === expectedBase;
}

function assertTestPolicy(runGit, baseRef, repoRoot, paths) {
  for (const repositoryPath of paths) {
    if (!repositoryPath.startsWith('backend/test/')) continue;
    if (!R2_ALLOWED_PATHS.has(repositoryPath)) failScope();
    const existsAtBase = basePathExists(runGit, baseRef, repositoryPath);
    if (!existsAtBase && NEW_TEST_PATHS.has(repositoryPath)) continue;
    if (!existsAtBase || !EXISTING_SCHEMA_READER_TESTS.has(repositoryPath)) failScope();
    if (!testHunkIsMechanical(runGit, baseRef, repoRoot, repositoryPath)) failScope();
  }
}

function isWithin(root, candidate) {
  const relation = path.relative(root, candidate);
  return relation === '' || (!relation.startsWith('..') && !path.isAbsolute(relation));
}

function directoryIdentity(directory) {
  const state = fs.statSync(directory);
  return { dev: state.dev, ino: state.ino };
}

function sameDirectoryIdentity(left, right) {
  return left.dev === right.dev && left.ino === right.ino;
}

function fileIdentityFromDescriptor(descriptor) {
  const state = fs.fstatSync(descriptor);
  if (!state.isFile()) failScope();
  return { dev: state.dev, ino: state.ino };
}

function sameFileIdentity(left, right) {
  return left.dev === right.dev && left.ino === right.ino;
}

function resolveReportOutput(reportPath) {
  if (typeof reportPath !== 'string' || reportPath.length === 0 || reportPath.includes('\0') || !path.isAbsolute(reportPath)) {
    throw new Error('invalid report path');
  }
  const resolved = path.resolve(reportPath);
  const name = path.basename(resolved);
  if (!/^[A-Za-z0-9][A-Za-z0-9._-]*\.json$/.test(name) || path.dirname(resolved) === resolved) failScope();
  const temporaryRoot = fs.realpathSync(os.tmpdir());
  const parent = fs.realpathSync(path.dirname(resolved));
  if (!isWithin(temporaryRoot, parent) || fs.existsSync(path.join(parent, name))) failScope();
  const parentContainer = fs.realpathSync(path.dirname(parent));
  return {
    temporaryRoot,
    parent,
    parentIdentity: directoryIdentity(parent),
    parentContainer,
    parentContainerIdentity: directoryIdentity(parentContainer),
    name,
    target: path.join(parent, name),
  };
}

function revalidateReportOutput(output) {
  const currentTemporaryRoot = fs.realpathSync(os.tmpdir());
  const currentParent = fs.realpathSync(output.parent);
  if (
    currentTemporaryRoot !== output.temporaryRoot
    || currentParent !== output.parent
    || !isWithin(output.temporaryRoot, currentParent)
    || !sameDirectoryIdentity(directoryIdentity(currentParent), output.parentIdentity)
  ) failScope();
}

function isCapturedDirectory(candidate, identity) {
  try {
    if (!fs.lstatSync(candidate).isDirectory()) return false;
    return sameDirectoryIdentity(directoryIdentity(candidate), identity);
  } catch {
    return false;
  }
}

function locateCapturedDirectory(output) {
  if (isCapturedDirectory(output.parent, output.parentIdentity)) return output.parent;
  if (!isCapturedDirectory(output.parentContainer, output.parentContainerIdentity)) return null;
  for (const entry of fs.readdirSync(output.parentContainer, { withFileTypes: true })) {
    const candidate = path.join(output.parentContainer, entry.name);
    if (isCapturedDirectory(candidate, output.parentIdentity)) return candidate;
  }
  return null;
}

function removeCapturedFile(parent, name, identity) {
  if (identity === undefined) return;
  try {
    const target = path.join(parent, name);
    const state = fs.lstatSync(target);
    if (!state.isFile() || !sameFileIdentity(state, identity)) return;
    fs.unlinkSync(target);
  } catch (error) {
    if (error && typeof error === 'object' && error.code === 'ENOENT') return;
  }
}

function rollbackTemporaryReportResidue(output, temporaryName, temporaryIdentity) {
  try {
    const parent = locateCapturedDirectory(output);
    if (parent === null) return;
    removeCapturedFile(parent, temporaryName, temporaryIdentity);
  } catch {
    // The caller returns only the fixed sanitized failure.
  }
}

function writeReport(reportPath, changedPathCount) {
  const output = resolveReportOutput(reportPath);
  const content = `{"changedPathCount":${changedPathCount},"result":"PASS"}\n`;
  if (content.length === 0 || content.includes('\0')) failScope();
  const temporaryName = `.${output.name}.${process.pid}.${crypto.randomUUID()}.tmp`;
  const temporary = path.join(output.parent, temporaryName);
  let descriptor;
  let temporaryIdentity;
  let committed = false;
  try {
    revalidateReportOutput(output);
    const noFollow = typeof fs.constants.O_NOFOLLOW === 'number' ? fs.constants.O_NOFOLLOW : 0;
    descriptor = fs.openSync(temporary, fs.constants.O_WRONLY | fs.constants.O_CREAT | fs.constants.O_EXCL | noFollow, 0o600);
    temporaryIdentity = fileIdentityFromDescriptor(descriptor);
    revalidateReportOutput(output);
    fs.writeFileSync(descriptor, content, 'utf8');
    fs.fsyncSync(descriptor);
    fs.closeSync(descriptor);
    descriptor = undefined;
    revalidateReportOutput(output);
    fs.renameSync(temporary, output.target);
    committed = true;
  } finally {
    if (descriptor !== undefined) fs.closeSync(descriptor);
    if (!committed) rollbackTemporaryReportResidue(output, temporaryName, temporaryIdentity);
  }
}

function validateScope({ repoRoot, baseRef, expectedBase = R2_BASE, reportPath }) {
  if (baseRef !== expectedBase || !/^[0-9a-f]{40}$/.test(baseRef)) throw new Error('invalid base');
  const root = fs.realpathSync(repoRoot);
  const runGit = defaultRunGit(root);
  const paths = collectChangedPaths({ runGit, baseRef });
  if (paths.some((repositoryPath) => !R2_ALLOWED_PATHS.has(repositoryPath))) failScope();
  if (paths.some((repositoryPath) => repositoryPath === 'backend/prisma/seed.ts' || repositoryPath.startsWith('backend/prisma/migrations/'))) failScope();
  if (paths.some((repositoryPath) => repositoryPath.startsWith('backend/src/') || repositoryPath.startsWith('mobile/') || repositoryPath.startsWith('admin-web/') || repositoryPath.startsWith('deploy/') || repositoryPath.startsWith('.github/'))) failScope();
  if (!dockerDeltaIsApproved(runGit, baseRef, root)) failScope();
  if (!prismaConfigDeltaIsApproved(runGit, baseRef, root, paths)) failScope();
  assertTestPolicy(runGit, baseRef, root, paths);
  const baseSchema = String(runGit(['show', `${baseRef}:${R2_BASE_SCHEMA_PATH}`]));
  assertSameBlockSet(baseSchema, readCandidateSchema(root));
  if (typeof reportPath !== 'undefined') writeReport(reportPath, paths.length);
  return { changedPathCount: paths.length };
}

function parseArguments(argv) {
  if (!Array.isArray(argv) || (argv.length !== 3 && argv.length !== 5)) throw new Error('invalid arguments');
  if (argv[0] !== '--check' || argv[1] !== '--base-ref') throw new Error('invalid arguments');
  const parsed = { baseRef: argv[2] };
  if (argv.length === 5) {
    if (argv[3] !== '--report') throw new Error('invalid arguments');
    parsed.reportPath = argv[4];
  }
  return parsed;
}

function runCli({ argv, expectedBase = R2_BASE, getRepoRoot, stdout, stderr }) {
  try {
    const parsed = parseArguments(argv);
    const result = validateScope({
      repoRoot: getRepoRoot(),
      baseRef: parsed.baseRef,
      expectedBase,
      reportPath: parsed.reportPath,
    });
    stdout(`PASS - R2 schema scope: ${result.changedPathCount} changed paths`);
    return 0;
  } catch (error) {
    if (error instanceof ScopeViolation) {
      stderr(CLI_SCOPE_FAILURE);
      return 1;
    }
    stderr(CLI_FAILURE);
    return 2;
  }
}

module.exports = {
  R2_ALLOWED_PATHS,
  R2_BASE,
  collectChangedPaths,
  parseTopLevelBlocks,
  runCli,
  validateScope,
};

if (process.argv[1] && pathToFileURL(path.resolve(process.argv[1])).href === pathToFileURL(__filename).href) {
  const scriptRoot = path.resolve(__dirname, '../../..');
  process.exitCode = runCli({
    argv: process.argv.slice(2),
    getRepoRoot: () => scriptRoot,
    stdout: (message) => process.stdout.write(`${message}\n`),
    stderr: (message) => process.stderr.write(`${message}\n`),
  });
}
