'use strict';

const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const ts = require('typescript');
const identity = require('./repository-identity.cjs');

const MANIFEST_PATH = 'backend/architecture/r12a-backoffice-catalog-public-contracts.json';
const BASE_COMMIT = '4d0d3ee91fb32d0432aa3bd69fe018d9a5a323b1';
const STAGES = Object.freeze(['design', 'backoffice', 'strict']);
const ENTRY = Object.freeze({ dependencyRecords: 22, ownershipRecords: 385, ownershipOccurrences: 781 });
const DEPENDENCY_SHA256 = 'cdb119fd3670913a6ad61940ecc811ddb257e5c23790ce43f345062a23128990';
const OWNERSHIP_SHA256 = '56e48f6a5fbe7c50cccef7568de52e999585e35f937e45a229d86305e6d2edb5';
const ENTRY_DEPENDENCY_PATH = 'backend/.dependency-cruiser-known-violations.json';
const ENTRY_OWNERSHIP_PATH = 'backend/architecture/ownership-baseline.json';
const TOP_LEVEL_KEYS = Object.freeze([
  'behavioralTests', 'consumers', 'dependencyRecords', 'entry', 'exceptionRetirement',
  'futureHandoffs', 'guardOrder', 'moves', 'ownershipProjection', 'phase', 'repository',
  'runtimePublicEdges', 'schemaVersion', 'stage', 'stages',
]);
const MOVE_FILES = Object.freeze({
  B1: ['backoffice', 'backend/src/admin/admin.guard.ts', 'backend/src/modules/backoffice/public/admin.guard.ts', ['AdminGuard'], []],
  B2: ['backoffice', 'backend/src/admin/admin-permission.decorator.ts', 'backend/src/modules/backoffice/public/admin-permission.decorator.ts', ['ADMIN_PERMISSIONS_KEY', 'RequireAdminPermission'], []],
  B3: ['backoffice', 'backend/src/admin/admin-permission.guard.ts', 'backend/src/modules/backoffice/public/admin-permission.guard.ts', ['AdminPermissionGuard'], []],
  B4: ['backoffice', 'backend/src/admin/admin-mutation-gate.ts', 'backend/src/modules/backoffice/public/admin-mutation-gate.ts', ['authorizeAdminMutationActor', 'runAuthorizedAdminMutation'], ['AuthorizedAdminMutationActor']],
  M1: ['marketplace', 'backend/src/marketplace/provider-review-rating.ts', 'backend/src/modules/marketplace/public/provider-review-rating.ts', ['lockProviderRatingRows', 'refreshProviderRating', 'runProviderReviewMutation'], []],
});
const SIBLING_EXCEPTIONS = Object.freeze([
  ['backend/.dependency-cruiser.cjs', ['context-identity-relocated-contexts-helper-cross-context', 'relocatedIdentityContextsService', 'providerAccessPolicy']],
  ['backend/scripts/architecture/ports-scan.cjs', ['backend/src/modules/identity/internal/profile/contexts.service.ts|backend/src/provider-dashboard/provider-access-policy.ts']],
  ['backend/scripts/architecture/r3-context-scan.cjs', ['backend/src/modules/identity/internal/profile/contexts.service.ts->backend/src/provider-dashboard/provider-access-policy.ts']],
]);
const IMMUTABLE_CONTRACT_HASHES = Object.freeze({
  moves: 'f32f791510d95122f421798e85f8961c3c43d17ee587fd3150bc70c761f2eb44',
  consumers: '7aa1614ada3ddb1d76eae17166d79161d56aee06b5faf91b916f332b28279702',
  behavioralTests: '6a74bd1f4f7464f41de493a5158a200023650b862500c9283b9e800f46bb0673',
  exceptionRetirement: '9a1a3c3453afc49b2524d093b0e237026a7a4bdd91ef380087f30484a485eec7',
  futureHandoffs: '8260daec25b9ad3f70435594b7d9e7c7112992db5877fb1e331a735b7b76fc05',
});

function sha256(value) { return crypto.createHash('sha256').update(value).digest('hex'); }
function exactKeys(value, keys, label) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error(`${label} must be an object`);
  const own = Reflect.ownKeys(value);
  if (own.some((key) => typeof key !== 'string') || own.sort().join('|') !== [...keys].sort().join('|')) throw new Error(`${label} has unknown or missing keys`);
}
function plainObject(value, label) {
  if (!value || typeof value !== 'object' || Array.isArray(value) || Object.getPrototypeOf(value) !== Object.prototype) throw new Error(`${label} must be plain data`);
  return value;
}
function denseArray(value, label) {
  if (!Array.isArray(value) || Object.getPrototypeOf(value) !== Array.prototype) throw new Error(`${label} must be an array`);
  const own = Reflect.ownKeys(value);
  if (own.some((key) => typeof key !== 'string') || own.length !== value.length + 1 || !own.includes('length')) throw new Error(`${label} must be dense`);
  for (let i = 0; i < value.length; i += 1) if (!Object.prototype.hasOwnProperty.call(value, String(i))) throw new Error(`${label} must be dense`);
  return value;
}
function deepData(value, label, seen = new Set(), depth = 0) {
  if (value === null || typeof value === 'boolean' || typeof value === 'string') return;
  if (typeof value === 'number') { if (!Number.isFinite(value) || !Number.isSafeInteger(value)) throw new Error(`${label} contains an unsafe number`); return; }
  if (!value || typeof value !== 'object' || depth > 32 || seen.has(value)) throw new Error(`${label} must be bounded plain data`);
  seen.add(value);
  if (Array.isArray(value)) denseArray(value, label).forEach((item, i) => deepData(item, `${label}[${i}]`, seen, depth + 1));
  else { plainObject(value, label); Object.keys(value).forEach((key) => deepData(value[key], `${label}.${key}`, seen, depth + 1)); }
  seen.delete(value);
}
function safeRelative(relative, label) {
  if (typeof relative !== 'string' || !relative.startsWith('backend/') || relative.includes('\\') || relative.includes('\u0000') || relative.split('/').some((part) => !part || part === '.' || part === '..')) throw new Error(`${label} escapes the repository`);
}
function canonicalStrings(value, label) {
  denseArray(value, label);
  if (value.some((item) => typeof item !== 'string') || new Set(value).size !== value.length) throw new Error(`${label} must be unique strings`);
}
function dependencyKey(record) { return [record.rule && record.rule.name, record.from, record.to].join('|'); }

function validateR12aManifest(value) {
  deepData(value, 'R12A manifest'); exactKeys(value, TOP_LEVEL_KEYS, 'R12A manifest');
  if (value.schemaVersion !== 1 || value.phase !== 'R12A' || !STAGES.includes(value.stage)) throw new Error('R12A manifest identity is invalid');
  exactKeys(value.repository, ['baseCommit', 'branch', 'rootName'], 'R12A repository');
  if (JSON.stringify(value.repository) !== JSON.stringify({ rootName: 'aarast-modular-monolith', branch: 'modular-monolith', baseCommit: BASE_COMMIT })) throw new Error('R12A repository is invalid');
  exactKeys(value.entry, ['dependencyRecords', 'dependencySha256', 'ownershipOccurrences', 'ownershipRecords', 'ownershipSha256'], 'R12A entry');
  if (JSON.stringify(value.entry) !== JSON.stringify({ dependencyRecords: 22, dependencySha256: DEPENDENCY_SHA256, ownershipRecords: 385, ownershipOccurrences: 781, ownershipSha256: OWNERSHIP_SHA256 })) throw new Error('R12A entry is invalid');
  exactKeys(value.stages, STAGES, 'R12A stages');
  const stages = { design: [[], [], 22, false, false], backoffice: [['B1', 'B2', 'B3', 'B4'], [2, 3, 4, 5, 6], 17, true, false], strict: [['B1', 'B2', 'B3', 'B4', 'M1'], [1, 2, 3, 4, 5, 6], 16, true, true] };
  STAGES.forEach((stage) => { const expected = stages[stage]; const current = plainObject(value.stages[stage], `R12A ${stage}`); exactKeys(current, ['activeMoveIds', 'dependencyRecords', 'ownershipProjectionActive', 'retiredDependencyIds', 'runtimePublicEdgeActive'], `R12A ${stage}`); if (JSON.stringify([current.activeMoveIds, current.retiredDependencyIds, current.dependencyRecords, current.ownershipProjectionActive, current.runtimePublicEdgeActive]) !== JSON.stringify(expected)) throw new Error(`R12A ${stage} projection is invalid`); });
  denseArray(value.dependencyRecords, 'R12A dependency records'); if (value.dependencyRecords.length !== 6) throw new Error('R12A dependency inventory is invalid');
  const dependencyShapes = [
    ['context-backoffice-cross-context', 'src/admin/admin-mutation-executor.ts', 'src/marketplace/provider-review-rating.ts', '../marketplace/provider-review-rating'],
    ['context-catalog-cross-context', 'src/catalogs/administrative-catalog.service.ts', 'src/admin/admin-mutation-gate.ts', '../admin/admin-mutation-gate'],
    ['context-catalog-cross-context', 'src/catalogs/catalogs.controller.ts', 'src/admin/admin-permission.decorator.ts', '../admin/admin-permission.decorator'],
    ['context-catalog-cross-context', 'src/catalogs/catalogs.controller.ts', 'src/admin/admin-permission.guard.ts', '../admin/admin-permission.guard'],
    ['context-catalog-cross-context', 'src/catalogs/catalogs.controller.ts', 'src/admin/admin.guard.ts', '../admin/admin.guard'],
    ['context-catalog-cross-context', 'src/catalogs/reference-catalog.service.ts', 'src/admin/admin-mutation-gate.ts', '../admin/admin-mutation-gate'],
  ];
  value.dependencyRecords.forEach((record, index) => { exactKeys(record, ['dependencyTypes', 'from', 'id', 'rule', 'to', 'type', 'unresolvedTo'], `R12A dependency ${index}`); exactKeys(record.rule, ['name', 'severity'], `R12A dependency rule ${index}`); denseArray(record.dependencyTypes, `R12A dependency types ${index}`); const shape = dependencyShapes[index]; if (JSON.stringify([record.id, record.rule.name, record.from, record.to, record.unresolvedTo, record.type, record.dependencyTypes, record.rule.severity]) !== JSON.stringify([index + 1, ...shape, 'dependency', ['local', 'import'], 'error'])) throw new Error('R12A dependency record semantics changed'); });
  denseArray(value.moves, 'R12A moves'); if (value.moves.length !== 5) throw new Error('R12A move inventory is invalid'); const moveIds = Object.keys(MOVE_FILES);
  value.moves.forEach((move, index) => { const id = moveIds[index]; const shape = MOVE_FILES[id]; exactKeys(move, ['entrySha256', 'from', 'id', 'importRewrites', 'owner', 'runtimeExports', 'to', 'typeExports'], `R12A move ${index}`); safeRelative(move.from, 'R12A move source'); safeRelative(move.to, 'R12A move target'); canonicalStrings(move.runtimeExports, 'R12A runtime exports'); canonicalStrings(move.typeExports, 'R12A type exports'); if (move.id !== id || move.owner !== shape[0] || move.from !== shape[1] || move.to !== shape[2] || JSON.stringify(move.runtimeExports) !== JSON.stringify(shape[3]) || JSON.stringify(move.typeExports) !== JSON.stringify(shape[4]) || !/^[a-f0-9]{64}$/u.test(move.entrySha256)) throw new Error('R12A move semantics changed'); denseArray(move.importRewrites, 'R12A move imports').forEach((rewrite) => { exactKeys(rewrite, ['importedNames', 'newModule', 'newTypeOnly', 'oldModule', 'oldTypeOnly'], 'R12A move import'); canonicalStrings(rewrite.importedNames, 'R12A imported names'); if (typeof rewrite.oldModule !== 'string' || typeof rewrite.newModule !== 'string' || typeof rewrite.oldTypeOnly !== 'boolean' || typeof rewrite.newTypeOnly !== 'boolean') throw new Error('R12A move import is invalid'); }); });
  const moveSet = new Set(moveIds); const expectedConsumerPaths = ['backend/src/admin/admin-audit.controller.ts', 'backend/src/admin/admin.controller.ts', 'backend/src/admin/admin-user-status.ts', 'backend/src/admin/admin-mutation-executor.ts', 'backend/src/catalogs/catalogs.controller.ts', 'backend/src/catalogs/administrative-catalog.service.ts', 'backend/src/catalogs/reference-catalog.service.ts', 'backend/src/marketplace/marketplace.service.ts', 'backend/src/modules/identity/internal/profile/users.service.ts']; const expectedTestPaths = ['backend/test/admin-auth-session-security.test.ts', 'backend/test/admin-rbac-audit.test.ts', 'backend/test/admin-mutation-authorization.test.ts', 'backend/test/provider-rating-atomicity.test.ts', 'backend/test/admin-mutation-gate-runtime.test.ts', 'backend/test/reference-catalogs.test.ts'];
  [value.consumers, value.behavioralTests].forEach((collection, ci) => { denseArray(collection, ci ? 'R12A behavioral tests' : 'R12A consumers'); const paths = collection.map((item) => item.path); const expected = ci ? expectedTestPaths : expectedConsumerPaths; if (JSON.stringify(paths) !== JSON.stringify(expected)) throw new Error('R12A contract inventory changed'); const seen = new Set(); collection.forEach((item) => { exactKeys(item, ci ? ['entrySha256', 'literalRewrites', 'mode', 'path'] : ['entrySha256', 'importRewrites', 'path'], 'R12A contract'); safeRelative(item.path, 'R12A contract path'); if (seen.has(item.path) || !/^[a-f0-9]{64}$/u.test(item.entrySha256)) throw new Error('R12A contract is invalid'); seen.add(item.path); if (ci && !['rewrite', 'run-only'].includes(item.mode)) throw new Error('R12A behavioral mode is invalid'); const rewrites = ci ? item.literalRewrites : item.importRewrites; denseArray(rewrites, 'R12A rewrites').forEach((rewrite) => { exactKeys(rewrite, ci ? ['moveId', 'old', 'new'] : ['moveId', 'oldModule', 'newModule'], 'R12A rewrite'); if (!moveSet.has(rewrite.moveId)) throw new Error('R12A contract references unknown move'); }); if (ci && item.mode === 'run-only' && item.literalRewrites.length !== 0) throw new Error('R12A run-only rewrite is invalid'); }); });
  exactKeys(value.ownershipProjection, ['newFile', 'newKey', 'oldFile', 'oldKey', 'unchanged'], 'R12A ownership projection'); if (value.ownershipProjection.oldKey !== 'backend/src/admin/admin-mutation-gate.ts|backoffice|identity|User|select|read|sql|foreign-model' || value.ownershipProjection.newKey !== 'backend/src/modules/backoffice/public/admin-mutation-gate.ts|backoffice|identity|User|select|read|sql|foreign-model' || value.ownershipProjection.oldFile !== 'backend/src/admin/admin-mutation-gate.ts' || value.ownershipProjection.newFile !== 'backend/src/modules/backoffice/public/admin-mutation-gate.ts' || JSON.stringify(value.ownershipProjection.unchanged) !== JSON.stringify({ context: 'backoffice', owner: 'identity', model: 'User', operation: 'select', mode: 'read', source: 'sql', reason: 'foreign-model', count: 1 })) throw new Error('R12A ownership projection changed');
  if (JSON.stringify(value.guardOrder) !== JSON.stringify(['JwtSessionGuard', 'AdminGuard', 'AdminPermissionGuard'])) throw new Error('R12A guard order is invalid'); denseArray(value.runtimePublicEdges, 'R12A runtime edges'); if (value.runtimePublicEdges.length !== 1 || JSON.stringify(value.runtimePublicEdges[0]) !== JSON.stringify({ stage: 'strict', source: 'backend/src/modules/identity/internal/profile/users.service.ts', target: 'backend/src/modules/marketplace/public/provider-review-rating.ts', importedNames: ['lockProviderRatingRows', 'refreshProviderRating'], ownerPhase: 'R16' })) throw new Error('R12A runtime edge changed'); denseArray(value.exceptionRetirement, 'R12A exception retirement'); if (value.exceptionRetirement.length !== 3) throw new Error('R12A exception retirement changed'); value.exceptionRetirement.forEach((item) => { exactKeys(item, ['collection', 'identity', 'path'], 'R12A exception'); safeRelative(item.path, 'R12A exception path'); }); denseArray(value.futureHandoffs, 'R12A future handoffs'); if (value.futureHandoffs.length !== 2) throw new Error('R12A future handoffs changed');
  for (const [key, expectedHash] of Object.entries(IMMUTABLE_CONTRACT_HASHES)) {
    if (sha256(JSON.stringify(value[key])) !== expectedHash) throw new Error(`R12A ${key} contract changed`);
  }
  return Object.freeze(value);
}

function expectedR12aDependencyRecords(entryRecords, manifest) { const checked = validateR12aManifest(manifest); const active = checked.stages[checked.stage]; const byId = new Map(checked.dependencyRecords.map((record) => [record.id, record])); const retired = new Set(active.retiredDependencyIds); const expected = new Map(); retired.forEach((id) => { const record = byId.get(id); if (!record) throw new Error(`Unknown R12A dependency id: ${id}`); const { id: ignored, ...withoutId } = record; expected.set(dependencyKey(withoutId), withoutId); }); const counts = new Map(); for (const record of denseArray(entryRecords, 'R12A entry dependencies')) { const key = dependencyKey(record); counts.set(key, (counts.get(key) || 0) + 1); } for (const key of expected.keys()) if (counts.get(key) !== 1) throw new Error('R12A dependency projection is invalid'); const seen = new Set(); const projected = denseArray(entryRecords, 'R12A entry dependencies').filter((record) => { const key = dependencyKey(record); if (!expected.has(key)) return true; assert.deepStrictEqual(record, expected.get(key)); seen.add(key); return false; }); if (seen.size !== expected.size || projected.length !== active.dependencyRecords) throw new Error('R12A dependency projection is invalid'); return Object.freeze(projected.map((record) => Object.freeze({ ...record }))); }
// Sanity bound for a JSON authority. The R12C manifest carries base64 candidate
// payloads for every registered edit, so the bound is sized for that, not for
// the small R12A/R12B manifests.
const JSON_AUTHORITY_BYTES = 8 * 1024 * 1024;
function readBoundedPlainJson(repositoryRoot, relative, label) {
  const file = inspectFile(repositoryRoot, relative);
  if (!file) return null;
  const stat = fs.statSync(file);
  if (stat.size < 2 || stat.size > JSON_AUTHORITY_BYTES) throw new Error(`${label} exceeds its file bound`);
  const bytes = fs.readFileSync(file);
  if (bytes.length !== stat.size) throw new Error(`${label} changed while being read`);
  const source = bytes.toString('utf8');
  if (!Buffer.from(source, 'utf8').equals(bytes)) throw new Error(`${label} is not exact UTF-8`);
  let value;
  try { value = JSON.parse(source); } catch { throw new Error(`${label} contains invalid JSON`); }
  deepData(value, label);
  return Object.freeze({ bytes, value });
}
function r12aGitAuthorityError() {
  return new Error('R12A successor Git authority is invalid');
}
function r12aPathIdentity(value) {
  const resolved = path.resolve(value);
  return process.platform === 'win32' ? resolved.toLowerCase() : resolved;
}
function canonicalR12aGitPath(value) {
  try {
    return fs.realpathSync.native(value);
  } catch {
    throw r12aGitAuthorityError();
  }
}
function r12aGitControlStat(value, expectedType) {
  let stat;
  try {
    stat = fs.lstatSync(value);
  } catch {
    throw r12aGitAuthorityError();
  }
  if (stat.isSymbolicLink()
      || (expectedType === 'file' && !stat.isFile())
      || (expectedType === 'directory' && !stat.isDirectory())
      || (expectedType === 'control' && !stat.isFile() && !stat.isDirectory())) {
    throw r12aGitAuthorityError();
  }
  return stat;
}
function readR12aGitControlLine(filePath, prefixed) {
  const stat = r12aGitControlStat(filePath, 'file');
  if (stat.size < 1 || stat.size > 4096) throw r12aGitAuthorityError();
  const bytes = fs.readFileSync(filePath);
  if (bytes.length !== stat.size) throw r12aGitAuthorityError();
  const source = bytes.toString('utf8');
  if (!Buffer.from(source, 'utf8').equals(bytes)) throw r12aGitAuthorityError();
  const match = (prefixed
    ? /^gitdir: ([^\r\n\u0000]+)(?:\r?\n)?$/u
    : /^([^\r\n\u0000]+)(?:\r?\n)?$/u).exec(source);
  if (!match || !match[1] || match[1] !== match[1].trim()) throw r12aGitAuthorityError();
  return match[1];
}
function runR12aGitAuthority(repositoryRoot, args) {
  try {
    const output = execFileSync('git', args, {
      cwd: repositoryRoot,
      encoding: 'utf8',
      maxBuffer: 1024 * 1024,
      windowsHide: true,
      stdio: ['ignore', 'pipe', 'pipe'],
    }).trim();
    if (!output || output.includes('\u0000')) throw r12aGitAuthorityError();
    return output;
  } catch {
    throw r12aGitAuthorityError();
  }
}
function verifyR12aSuccessorGitAuthority(repositoryRoot) {
  const canonicalRoot = canonicalR12aGitPath(repositoryRoot);
  const gitControl = path.join(canonicalRoot, '.git');
  const controlStat = r12aGitControlStat(gitControl, 'control');
  const topLevel = canonicalR12aGitPath(runR12aGitAuthority(canonicalRoot, ['rev-parse', '--show-toplevel']));
  if (r12aPathIdentity(topLevel) !== r12aPathIdentity(canonicalRoot)) throw r12aGitAuthorityError();
  const absoluteGitDir = runR12aGitAuthority(canonicalRoot, ['rev-parse', '--absolute-git-dir']);
  if (!path.isAbsolute(absoluteGitDir)) throw r12aGitAuthorityError();
  const resolvedGitDir = path.resolve(absoluteGitDir);
  r12aGitControlStat(resolvedGitDir, 'directory');
  const canonicalGitDir = canonicalR12aGitPath(resolvedGitDir);
  if (r12aPathIdentity(canonicalGitDir) !== r12aPathIdentity(resolvedGitDir)) throw r12aGitAuthorityError();
  if (controlStat.isDirectory()) {
    const canonicalControl = canonicalR12aGitPath(gitControl);
    if (r12aPathIdentity(canonicalGitDir) !== r12aPathIdentity(canonicalControl)) throw r12aGitAuthorityError();
    return canonicalRoot;
  }
  const linkedTarget = readR12aGitControlLine(gitControl, true);
  const resolvedTarget = path.resolve(path.dirname(gitControl), linkedTarget);
  r12aGitControlStat(resolvedTarget, 'directory');
  const canonicalTarget = canonicalR12aGitPath(resolvedTarget);
  if (r12aPathIdentity(canonicalTarget) !== r12aPathIdentity(resolvedTarget)
      || r12aPathIdentity(canonicalTarget) !== r12aPathIdentity(canonicalGitDir)) {
    throw r12aGitAuthorityError();
  }
  const backReferenceFile = path.join(canonicalTarget, 'gitdir');
  const backReference = readR12aGitControlLine(backReferenceFile, false);
  const resolvedBackReference = path.resolve(canonicalTarget, backReference);
  r12aGitControlStat(resolvedBackReference, 'file');
  const canonicalBackReference = canonicalR12aGitPath(resolvedBackReference);
  if (r12aPathIdentity(resolvedBackReference) !== r12aPathIdentity(gitControl)
      || r12aPathIdentity(canonicalBackReference) !== r12aPathIdentity(gitControl)) {
    throw r12aGitAuthorityError();
  }
  return canonicalRoot;
}
function expectedR12aSuccessorDependencyRecords({ repositoryRoot, r12aEntryRecords, r12aManifest, readImmutableFile } = {}) {
  if (typeof repositoryRoot !== 'string' || !path.isAbsolute(repositoryRoot)) throw new Error('R12A successor repository root must be absolute');
  const checkedR12a = validateR12aManifest(r12aManifest);
  const r12aRecords = expectedR12aDependencyRecords(r12aEntryRecords, checkedR12a);
  const r12bFile = readBoundedPlainJson(repositoryRoot, 'backend/architecture/r12b-planning-public-contracts.json', 'R12B successor manifest');
  if (!r12bFile) return r12aRecords;
  const r12b = require('./r12b-planning-public-contracts-scan.cjs');
  const manifest = r12b.validateR12bManifest(r12bFile.value);
  const self = manifest.r12bPaths[0].normalizedSelfSha256;
  const needle = Buffer.from(`"normalizedSelfSha256": "${self}"`, 'utf8');
  const first = r12bFile.bytes.indexOf(needle);
  if (first < 0 || r12bFile.bytes.indexOf(needle, first + needle.length) >= 0) throw new Error('R12B successor manifest self binding is invalid');
  const normalized = Buffer.from(r12bFile.bytes);
  normalized.set(Buffer.from('0'.repeat(64), 'utf8'), first + needle.indexOf(Buffer.from(self, 'utf8')));
  if (sha256(normalized) !== self) throw new Error('R12B successor manifest self binding changed');
  const liveR12aFile = readBoundedPlainJson(repositoryRoot, MANIFEST_PATH, 'R12A predecessor manifest');
  if (!liveR12aFile || sha256(liveR12aFile.bytes) !== manifest.predecessor.manifestSha256) throw new Error('R12B predecessor manifest fingerprint changed');
  const liveR12a = validateR12aManifest(liveR12aFile.value);
  if (JSON.stringify(liveR12a) !== JSON.stringify(checkedR12a)) throw new Error('R12A successor manifest input is not the exact predecessor');
  verifyR12aSuccessorGitAuthority(repositoryRoot);
  const immutable = readR12aImmutableEntry({ repositoryRoot, manifest: liveR12a, readImmutableFile });
  if (JSON.stringify(immutable.dependency) !== JSON.stringify(r12aEntryRecords)) throw new Error('R12A successor immutable entry changed');
  const r12bRecords = r12b.expectedR12bDependencyRecords(r12aRecords, manifest);
  const r12cFile = readBoundedPlainJson(repositoryRoot, 'backend/architecture/r12c-zero-cross-context-dependencies.json', 'R12C successor manifest');
  if (!r12cFile) return r12bRecords;
  const r12c = require('./r12c-zero-cross-context-dependencies-scan.cjs');
  const successor = r12c.validateR12cManifest(r12cFile.value);
  if (successor.predecessor.manifestSha256 !== sha256(r12bFile.bytes)) throw new Error('R12C predecessor manifest fingerprint changed');
  const retired = new Set(successor.stages[successor.stage].retiredDependencyIds);
  const records = successor.dependencyRecords.filter((row) => !retired.has(row.id)).map(({ id: ignored, ...row }) => row);
  assert.deepStrictEqual(successor.dependencyRecords.map(({ id: ignored, ...row }) => row), r12bRecords);
  return r12c.expectedR12cDependencyRecords(records, successor);
}
function r12aSuccessorPredecessorBytes({ repositoryRoot, r12aEntryRecords, r12aManifest, readImmutableFile } = {}) {
  const r12bFile = readBoundedPlainJson(repositoryRoot, 'backend/architecture/r12b-planning-public-contracts.json', 'R12B successor manifest');
  if (!r12bFile) return new Map();
  expectedR12aSuccessorDependencyRecords({ repositoryRoot, r12aEntryRecords, r12aManifest, readImmutableFile });
  const r12b = require('./r12b-planning-public-contracts-scan.cjs');
  const manifest = r12b.validateR12bManifest(r12bFile.value);
  const projected = r12b.projectR12bWorkingTreeToPredecessor({ repositoryRoot, manifest });
  const result = new Map(projected.projectionDetails.nonDocumentation.map(
    (item) => [item.path, item.entryBytes],
  ));
  const r12cFile = readBoundedPlainJson(repositoryRoot, 'backend/architecture/r12c-zero-cross-context-dependencies.json', 'R12C successor manifest');
  if (r12cFile) {
    const r12c = require('./r12c-zero-cross-context-dependencies-scan.cjs');
    const successor = r12c.validateR12cManifest(r12cFile.value);
    const predecessor = r12c.projectR12cWorkingTreeToPredecessor({ repositoryRoot, manifest: successor });
    for (const contract of [...r12aManifest.consumers, ...r12aManifest.behavioralTests]) {
      if (!result.has(contract.path)) result.set(contract.path, predecessor.readWorkingFile(contract.path));
    }
    for (const [relative] of SIBLING_EXCEPTIONS) result.set(relative, predecessor.readWorkingFile(relative));
  }
  return result;
}

function readR12aSuccessorDependencyBytes(repositoryRoot) {
  if (typeof repositoryRoot !== 'string' || !path.isAbsolute(repositoryRoot)) {
    throw new Error('R12A successor repository root must be absolute');
  }
  const r12cFile = readBoundedPlainJson(
    repositoryRoot,
    'backend/architecture/r12c-zero-cross-context-dependencies.json',
    'R12C successor manifest',
  );
  if (r12cFile) {
    const r12c = require('./r12c-zero-cross-context-dependencies-scan.cjs');
    r12c.validateR12cManifest(r12cFile.value);
    return r12c.readR12cStrictDependencyBytes(repositoryRoot);
  }
  return fs.readFileSync(inspectFile(repositoryRoot, ENTRY_DEPENDENCY_PATH));
}

function expectedR12aOwnershipBaseline(entryBaseline, manifest) { const checked = validateR12aManifest(manifest); const expected = structuredClone(entryBaseline); if (!expected || !Array.isArray(expected.violations)) throw new Error('R12A ownership baseline is invalid'); const active = checked.stages[checked.stage]; if (active.ownershipProjectionActive) { const projection = checked.ownershipProjection; const matches = expected.violations.filter((item) => item.key === projection.oldKey && item.file === projection.oldFile); if (matches.length !== 1) throw new Error('R12A ownership projection is invalid'); const item = matches[0]; for (const [key, value] of Object.entries(projection.unchanged)) if (item[key] !== value) throw new Error('R12A ownership projection semantics changed'); item.key = projection.newKey; item.file = projection.newFile; } expected.violations.sort((left, right) => (left.key < right.key ? -1 : left.key > right.key ? 1 : 0)); if (expected.violations.length !== ENTRY.ownershipRecords || expected.violations.reduce((sum, item) => sum + item.count, 0) !== ENTRY.ownershipOccurrences) throw new Error('R12A ownership totals are invalid'); return expected; }

function parseSource(filePath, source) { const file = ts.createSourceFile(filePath, source, ts.ScriptTarget.Latest, true, ts.ScriptKind.TS); if (file.parseDiagnostics.length) throw new Error('R12A TypeScript source could not be parsed'); return file; }
function importInfo(statement) { const clause = statement.importClause; const names = []; if (clause) { if (clause.name) names.push('default'); if (clause.namedBindings) { if (ts.isNamespaceImport(clause.namedBindings)) names.push(clause.namedBindings.name.text); else clause.namedBindings.elements.forEach((element) => names.push((element.propertyName || element.name).text)); } } return { module: statement.moduleSpecifier.text, typeOnly: Boolean(clause && clause.isTypeOnly), names }; }
function importStatements(file) { return file.statements.filter(ts.isImportDeclaration); }
function transformedImportText(historicalText, rewrite) { const escaped = rewrite.oldModule.replace(/[.*+?^${}()|[\]\\]/gu, '\\$&'); const replaced = historicalText.replace(new RegExp(`(['"])${escaped}\\1`, 'u'), `$1${rewrite.newModule}$1`); return rewrite.newTypeOnly ? replaced.replace(/^import\s+/u, 'import type ') : replaced.replace(/^import\s+type\s+/u, 'import '); }
function verifyR12aSourceParity({ historicalSource, liveSource, move }) { if (sha256(historicalSource) !== move.entrySha256) throw new Error('R12A historical source hash is invalid'); const historical = String(historicalSource).replace(/\r\n/gu, '\n'); let live = String(liveSource).replace(/\r\n/gu, '\n'); const oldFile = parseSource(move.from, historical); const liveFile = parseSource(move.to, live); const oldImports = importStatements(oldFile); const liveImports = importStatements(liveFile); if (oldImports.length !== liveImports.length) throw new Error('R12A source import inventory changed'); const replacements = []; oldImports.forEach((oldStatement, index) => { const current = liveImports[index]; const oldInfo = importInfo(oldStatement); const currentInfo = importInfo(current); const rewrite = move.importRewrites.find((item) => item.oldModule === oldInfo.module && item.oldTypeOnly === oldInfo.typeOnly && JSON.stringify(item.importedNames) === JSON.stringify(oldInfo.names)); if (rewrite) { if (currentInfo.module !== rewrite.newModule || currentInfo.typeOnly !== rewrite.newTypeOnly || JSON.stringify(currentInfo.names) !== JSON.stringify(oldInfo.names) || current.getText(liveFile) !== transformedImportText(oldStatement.getText(oldFile), rewrite)) throw new Error('R12A source import rewrite is invalid'); replacements.push([current.getStart(liveFile), current.getEnd(), oldStatement.getText(oldFile)]); } else if (current.getText(liveFile) !== oldStatement.getText(oldFile)) throw new Error('R12A undeclared import changed'); }); if (replacements.length !== move.importRewrites.length) throw new Error('R12A source import rewrite inventory is invalid'); replacements.sort((a, b) => b[0] - a[0]).forEach(([start, end, text]) => { live = live.slice(0, start) + text + live.slice(end); }); if (live !== historical) throw new Error('R12A source parity drift detected'); return true; }

function literalNodes(file) { const nodes = []; const visit = (node) => { if (ts.isStringLiteralLike(node)) nodes.push(node); ts.forEachChild(node, visit); }; visit(file); return nodes; }
function verifyR12aConsumerParity({ historicalSource, liveSource, contract, manifest }) {
  if (sha256(historicalSource) !== contract.entrySha256) throw new Error('R12A historical consumer hash is invalid');
  const historical = String(historicalSource).replace(/\r\n/gu, '\n'); let live = String(liveSource).replace(/\r\n/gu, '\n');
  const oldFile = parseSource(contract.path, historical); const liveFile = parseSource(contract.path, live); const oldImports = importStatements(oldFile); const liveImports = importStatements(liveFile);
  if (oldImports.length !== liveImports.length) throw new Error('R12A consumer import inventory changed');
  const active = new Set(manifest.stages[manifest.stage].activeMoveIds); const replacements = [];
  for (const rewrite of contract.importRewrites) {
    const move = manifest.moves.find((item) => item.id === rewrite.moveId); if (!move) throw new Error('R12A consumer references unknown move');
    const oldCount = oldImports.filter((item) => item.moduleSpecifier.text === rewrite.oldModule).length; const expected = active.has(rewrite.moveId) ? rewrite.newModule : rewrite.oldModule;
    const newCount = liveImports.filter((item) => item.moduleSpecifier.text === expected).length; const forbidden = active.has(rewrite.moveId) ? rewrite.oldModule : rewrite.newModule;
    if (oldCount < 1 || newCount !== oldCount || liveImports.some((item) => item.moduleSpecifier.text === forbidden)) throw new Error('R12A consumer rewrite stage is invalid');
    if (active.has(rewrite.moveId)) liveImports.filter((item) => item.moduleSpecifier.text === expected).forEach((item) => replacements.push([item.moduleSpecifier.getStart(liveFile) + 1, item.moduleSpecifier.getEnd() - 1, rewrite.oldModule]));
  }
  replacements.sort((a, b) => b[0] - a[0]).forEach(([start, end, text]) => { live = live.slice(0, start) + text + live.slice(end); });
  if (live !== historical) throw new Error('R12A consumer parity drift detected'); return true;
}
function verifyR12aLiteralParity({ historicalSource, liveSource, contract, manifest }) { if (contract.importRewrites) return verifyR12aConsumerParity({ historicalSource, liveSource, contract, manifest }); if (sha256(historicalSource) !== contract.entrySha256) throw new Error('R12A historical contract hash is invalid'); if (contract.mode === 'run-only') { if (sha256(liveSource) !== contract.entrySha256) throw new Error('R12A run-only contract drift detected'); return true; } const active = new Set(manifest.stages[manifest.stage].activeMoveIds); const historical = String(historicalSource).replace(/\r\n/gu, '\n'); let live = String(liveSource).replace(/\r\n/gu, '\n'); const oldFile = parseSource(contract.path, historical); const liveFile = parseSource(contract.path, live); const oldLiterals = literalNodes(oldFile); const liveLiterals = literalNodes(liveFile); const replacements = []; for (const rewrite of contract.literalRewrites || []) { const oldValue = rewrite.old; const newValue = rewrite.new; const on = oldLiterals.filter((node) => node.text === oldValue).length; const nn = liveLiterals.filter((node) => node.text === newValue).length; const no = liveLiterals.filter((node) => node.text === oldValue).length; if (!on) throw new Error('R12A historical literal is missing'); if (active.has(rewrite.moveId) ? (nn !== on || no !== 0) : (no !== on || nn !== 0)) throw new Error('R12A contract rewrite stage is invalid'); if (active.has(rewrite.moveId)) liveLiterals.filter((node) => node.text === newValue).forEach((node) => replacements.push([node.getStart(liveFile) + 1, node.getEnd() - 1, oldValue])); } replacements.sort((a, b) => b[0] - a[0]).forEach(([start, end, text]) => { live = live.slice(0, start) + text + live.slice(end); }); if (live !== historical) throw new Error('R12A contract parity drift detected'); return true; }
function normalizeR12aIdentityProviderRatingImport(source, manifest) { const checked = validateR12aManifest(manifest); const move = checked.moves.find((item) => item.id === 'M1'); if (!move) throw new Error('R12A M1 move is missing'); let output = String(source).replace(/\r\n/gu, '\n'); const file = parseSource('r12a-identity.ts', output); const imports = importStatements(file); for (let i = imports.length - 1; i >= 0; i -= 1) { const statement = imports[i]; const rewrite = move.importRewrites.find((item) => item.newModule === statement.moduleSpecifier.text); if (!rewrite) continue; const current = statement.getText(file); const replaced = current.replace(statement.moduleSpecifier.text, rewrite.oldModule); output = output.slice(0, statement.getFullStart(file)) + (rewrite.oldTypeOnly ? replaced.replace(/^import\s+/u, 'import type ') : replaced.replace(/^import\s+type\s+/u, 'import ')) + output.slice(statement.getEnd()); } return output; }
function isAllowedR12aRuntimePublicEdge({ sourcePath, targetPath, importedNames, stage }, manifest) { if (typeof sourcePath === 'string' && typeof targetPath === 'string' && sourcePath.startsWith('backend/src/modules/backoffice/public/') && targetPath.startsWith('backend/src/modules/backoffice/public/')) return true; if (stage !== 'strict' || !manifest?.stages?.strict?.runtimePublicEdgeActive) return false; return manifest.runtimePublicEdges.some((edge) => edge.stage === stage && edge.source === sourcePath && edge.target === targetPath && JSON.stringify(edge.importedNames) === JSON.stringify(importedNames)); }

function inspectFile(repositoryRoot, relative) { safeRelative(relative, 'R12A path'); const root = fs.realpathSync.native(repositoryRoot); let current = repositoryRoot; for (const part of relative.split('/')) { current = path.join(current, part); if (!fs.existsSync(current)) return null; const stat = fs.lstatSync(current); if (stat.isSymbolicLink()) throw new Error('R12A source contains a symlink or reparse point'); } const real = fs.realpathSync.native(current); if (path.relative(root, real).startsWith('..')) throw new Error('R12A path escapes repository'); if (!fs.lstatSync(current).isFile()) throw new Error('R12A path is not a file'); return current; }
function validateR12aMoveLayout(sourcePath, targetPath, active) { if (active ? (sourcePath || !targetPath) : (!sourcePath || targetPath)) throw new Error('R12A move layout is invalid'); return true; }
function readImmutable(repositoryRoot, relative, manifest) { return execFileSync('git', ['show', `${manifest.repository.baseCommit}:${relative}`], { cwd: repositoryRoot, encoding: 'utf8', maxBuffer: 16 * 1024 * 1024, windowsHide: true }); }
function deepFreeze(value) {
  if (!value || typeof value !== 'object' || Object.isFrozen(value)) return value;
  for (const child of Object.values(value)) deepFreeze(child);
  return Object.freeze(value);
}
function readR12aImmutableEntry({ repositoryRoot, manifest, readImmutableFile } = {}) {
  if (typeof repositoryRoot !== 'string' || !path.isAbsolute(repositoryRoot)) {
    throw new Error('R12A immutable entry repository root must be absolute');
  }
  const checked = validateR12aManifest(manifest);
  if (readImmutableFile !== undefined && typeof readImmutableFile !== 'function') {
    throw new Error('R12A immutable entry reader must be a function');
  }
  const reader = readImmutableFile || ((revision, relative) => execFileSync(
    'git',
    ['show', `${revision}:${relative}`],
    {
      cwd: repositoryRoot,
      encoding: 'utf8',
      maxBuffer: 16 * 1024 * 1024,
      windowsHide: true,
    },
  ));
  const parseEntry = (relative, label) => {
    const bytes = reader(checked.repository.baseCommit, relative);
    if (typeof bytes !== 'string' && !Buffer.isBuffer(bytes)) {
      throw new Error(`R12A immutable ${label} reader must return a string or Buffer`);
    }
    let value;
    try {
      value = JSON.parse(Buffer.isBuffer(bytes) ? bytes.toString('utf8') : bytes);
    } catch {
      throw new Error(`R12A immutable ${label} entry contains invalid JSON`);
    }
    deepData(value, `R12A immutable ${label} entry`);
    return value;
  };
  const dependency = parseEntry(ENTRY_DEPENDENCY_PATH, 'dependency');
  const ownership = parseEntry(ENTRY_OWNERSHIP_PATH, 'ownership');
  if (!Array.isArray(dependency) || dependency.length !== checked.entry.dependencyRecords
      || sha256(`${JSON.stringify(dependency, null, 2)}\n`) !== checked.entry.dependencySha256) {
    throw new Error('R12A immutable dependency entry hash or count is invalid');
  }
  if (!ownership || !Array.isArray(ownership.violations)
      || ownership.violations.length !== checked.entry.ownershipRecords) {
    throw new Error('R12A immutable ownership entry record count is invalid');
  }
  const ownershipOccurrences = ownership.violations.reduce((sum, item) => {
    if (!item || !Number.isSafeInteger(item.count) || item.count < 1) {
      throw new Error('R12A immutable ownership entry occurrence is invalid');
    }
    return sum + item.count;
  }, 0);
  if (ownershipOccurrences !== checked.entry.ownershipOccurrences
      || sha256(`${JSON.stringify(ownership, null, 2)}\n`) !== checked.entry.ownershipSha256) {
    throw new Error('R12A immutable ownership entry hash or occurrence count is invalid');
  }
  return deepFreeze({ dependency, ownership });
}
function filesUnder(root) { const output = []; const visit = (directory) => { for (const entry of fs.readdirSync(directory, { withFileTypes: true })) { const current = path.join(directory, entry.name); if (entry.isSymbolicLink()) throw new Error('R12A source contains a symlink'); if (entry.isDirectory()) visit(current); else if (/\.ts$/u.test(entry.name)) output.push(current); } }; visit(root); return output; }
function exportedNames(sourceFile) { const runtime = []; const types = []; const add = (name, type) => (type ? types : runtime).push(name); sourceFile.statements.forEach((statement) => { if (!(statement.modifiers || []).some((item) => item.kind === ts.SyntaxKind.ExportKeyword)) return; if (ts.isClassDeclaration(statement) || ts.isFunctionDeclaration(statement) || ts.isEnumDeclaration(statement)) { if (statement.name) add(statement.name.text, false); } else if (ts.isInterfaceDeclaration(statement) || ts.isTypeAliasDeclaration(statement)) add(statement.name.text, true); else if (ts.isVariableStatement(statement)) statement.declarationList.declarations.forEach((decl) => { if (ts.isIdentifier(decl.name)) add(decl.name.text, false); }); else if (ts.isExportDeclaration(statement) && statement.exportClause && ts.isNamedExports(statement.exportClause)) statement.exportClause.elements.forEach((element) => add(element.name.text, false)); }); return { runtime, types }; }
function verifyR12aPublicExportInventory(source, move) { const inventory = exportedNames(parseSource(move.to, source)); if (JSON.stringify(inventory.runtime) !== JSON.stringify(move.runtimeExports) || JSON.stringify(inventory.types) !== JSON.stringify(move.typeExports)) throw new Error('R12A public export inventory is invalid'); return true; }
const R12A_RUNTIME_MODULE_EXTENSIONS = new Set(['.cjs', '.js', '.jsx', '.mjs']);
function isWithin(root, candidate) { const relative = path.relative(root, candidate); return relative === '' || (relative && !relative.startsWith('..') && !path.isAbsolute(relative)); }
function assertNoLocalSymlink(root, candidate) {
  let current = root;
  for (const part of path.relative(root, candidate).split(path.sep).filter(Boolean)) {
    current = path.join(current, part);
    if (fs.existsSync(current) && fs.lstatSync(current).isSymbolicLink()) throw new Error('R12A source contains a symlink or reparse point');
  }
}
function localModuleCandidates(base) {
  const extension = path.extname(base).toLowerCase();
  const stem = R12A_RUNTIME_MODULE_EXTENSIONS.has(extension) ? base.slice(0, -extension.length) : base;
  const candidates = [];
  if (extension === '.ts' || extension === '.tsx') candidates.push(base);
  else candidates.push(`${stem}.ts`, `${stem}.tsx`, path.join(stem, 'index.ts'), path.join(stem, 'index.tsx'));
  return [...new Set(candidates)];
}
function resolveLocalModule(sourceRoot, sourceFile, specifier) {
  const base = path.resolve(path.dirname(sourceFile), specifier);
  if (!isWithin(sourceRoot, base) || /[?#]/u.test(specifier)) throw new Error(`R12A suspicious local module form: ${specifier}`);
  const candidates = localModuleCandidates(base);
  for (const candidate of candidates) {
    if (!isWithin(sourceRoot, candidate)) throw new Error(`R12A suspicious local module form: ${specifier}`);
    if (!fs.existsSync(candidate)) continue;
    assertNoLocalSymlink(sourceRoot, candidate);
    if (!fs.lstatSync(candidate).isFile()) continue;
    return path.resolve(candidate);
  }
  throw new Error(`R12A unresolved local module import: ${specifier}`);
}
function localModuleEdges(ast) {
  const edges = [];
  const add = (node, specifier, typeOnly, kind) => { if (typeof specifier !== 'string' || !specifier.startsWith('.')) return; edges.push({ kind, node, specifier, typeOnly: Boolean(typeOnly) }); };
  for (const statement of ast.statements) {
    if (ts.isImportDeclaration(statement)) add(statement, statement.moduleSpecifier.text, statement.importClause && statement.importClause.isTypeOnly, 'import');
    else if (ts.isExportDeclaration(statement) && statement.moduleSpecifier) add(statement, statement.moduleSpecifier.text, statement.isTypeOnly, 'export');
  }
  const visit = (node) => {
    if (ts.isCallExpression(node)) {
      const isRequire = ts.isIdentifier(node.expression) && node.expression.text === 'require';
      const isDynamicImport = node.expression.kind === ts.SyntaxKind.ImportKeyword;
      if (isRequire || isDynamicImport) {
        const argument = node.arguments[0];
        if (!argument || !ts.isStringLiteralLike(argument)) throw new Error('R12A suspicious local module form');
        add(node, argument.text, false, isRequire ? 'require' : 'dynamic-import');
      }
    } else if (ts.isImportTypeNode(node) && ts.isLiteralTypeNode(node.argument) && ts.isStringLiteralLike(node.argument.literal)) {
      add(node, node.argument.literal.text, true, 'import');
    }
    ts.forEachChild(node, visit);
  };
  visit(ast);
  return edges;
}
function isCjsExportAssignment(statement) {
  if (!ts.isExpressionStatement(statement) || !ts.isBinaryExpression(statement.expression) || statement.expression.operatorToken.kind !== ts.SyntaxKind.EqualsToken) return false;
  const left = statement.expression.left;
  if (!ts.isPropertyAccessExpression(left)) return false;
  if (ts.isIdentifier(left.expression) && left.expression.text === 'exports') return true;
  if (ts.isIdentifier(left.expression) && left.expression.text === 'module' && left.name.text === 'exports') return true;
  return ts.isPropertyAccessExpression(left.expression) && ts.isIdentifier(left.expression.expression) && left.expression.expression.text === 'module' && left.expression.name.text === 'exports';
}
function localModuleIsFacade(ast) {
  if (ast.statements.some((statement) => (ts.isExportDeclaration(statement) && !statement.moduleSpecifier) || ts.isExportAssignment(statement))) return { kind: 'esm' };
  if (ast.statements.some((statement) => isCjsExportAssignment(statement))) return { kind: 'cjs' };
  return null;
}
function nestUseGuardsBindings(ast) {
  const direct = new Set(); const namespaces = new Set();
  for (const statement of ast.statements) {
    if (!ts.isImportDeclaration(statement) || statement.moduleSpecifier.text !== '@nestjs/common' || !statement.importClause) continue;
    const bindings = statement.importClause.namedBindings;
    if (!bindings) continue;
    if (ts.isNamespaceImport(bindings)) namespaces.add(bindings.name.text);
    else bindings.elements.forEach((element) => { const imported = (element.propertyName || element.name).text; if (imported === 'UseGuards') direct.add(element.name.text); });
  }
  return { direct, namespaces };
}
function isNestUseGuards(expression, bindings) {
  if (ts.isIdentifier(expression)) return bindings.direct.has(expression.text) && !isShadowedBinding(expression, expression.text);
  if (ts.isPropertyAccessExpression(expression)) return ts.isIdentifier(expression.expression) && bindings.namespaces.has(expression.expression.text) && !isShadowedBinding(expression, expression.expression.text) && expression.name.text === 'UseGuards';
  if (ts.isElementAccessExpression(expression) && ts.isIdentifier(expression.expression) && bindings.namespaces.has(expression.expression.text) && !isShadowedBinding(expression, expression.expression.text) && expression.argumentExpression && ts.isStringLiteralLike(expression.argumentExpression)) return expression.argumentExpression.text === 'UseGuards';
  return false;
}
function bindingPatternHasName(pattern, name) {
  if (ts.isIdentifier(pattern)) return pattern.text === name;
  if (ts.isObjectBindingPattern(pattern) || ts.isArrayBindingPattern(pattern)) return pattern.elements.some((element) => ts.isOmittedExpression(element) ? false : bindingPatternHasName(ts.isBindingElement(element) ? element.name : element, name));
  return false;
}
function scopeDeclaresName(scope, name) {
  let found = false;
  const visit = (node) => {
    if (found) return;
    if (ts.isVariableDeclaration(node) && bindingPatternHasName(node.name, name)) { found = true; return; }
    if ((ts.isFunctionDeclaration(node) || ts.isClassDeclaration(node)) && node.name && node.name.text === name) { found = true; return; }
    if (node !== scope && (ts.isFunctionLike(node) || ts.isClassLike(node))) return;
    ts.forEachChild(node, visit);
  };
  ts.forEachChild(scope, visit); return found;
}
function isShadowedBinding(node, name) {
  let current = node.parent;
  while (current && !ts.isSourceFile(current)) {
    if (ts.isFunctionLike(current)) {
      if (current.name && ts.isIdentifier(current.name) && current.name.text === name) return true;
      if (current.parameters.some((parameter) => bindingPatternHasName(parameter.name, name))) return true;
    }
    if (ts.isCatchClause(current) && current.variableDeclaration && bindingPatternHasName(current.variableDeclaration.name, name)) return true;
    if (ts.isBlock(current) || ts.isCaseBlock(current) || ts.isModuleBlock(current)) {
      if (scopeDeclaresName(current, name)) return true;
    }
    if ((ts.isForStatement(current) || ts.isForInStatement(current) || ts.isForOfStatement(current)) && current.initializer && scopeDeclaresName(current.initializer, name)) return true;
    current = current.parent;
  }
  return false;
}
function checkGuardOrder(repositoryRoot) {
  const root = path.join(repositoryRoot, 'backend', 'src');
  for (const file of filesUnder(root).filter((item) => /(?:admin|catalogs|modules[\\/]backoffice)[\\/].*\.ts$/u.test(item))) {
    const ast = parseSource(file, fs.readFileSync(file, 'utf8')); const bindings = nestUseGuardsBindings(ast);
    const walk = (node) => { if (ts.isCallExpression(node) && isNestUseGuards(node.expression, bindings)) { const names = node.arguments.map((arg) => arg.getText(ast)); if (JSON.stringify(names) !== JSON.stringify(['JwtSessionGuard', 'AdminGuard', 'AdminPermissionGuard'])) throw new Error('R12A guard order changed'); } ts.forEachChild(node, walk); };
    walk(ast);
  }
}
function checkRuntimeEdges(repositoryRoot, manifest) {
  const sourceRoot = path.resolve(repositoryRoot, 'backend', 'src'); const backendRoot = path.join(repositoryRoot, 'backend');
  const targets = new Map(manifest.moves.map((move) => [path.resolve(repositoryRoot, move.to), move])); const activeMoves = new Set(manifest.stages[manifest.stage].activeMoveIds); const consumers = new Set(manifest.consumers.map((item) => path.resolve(repositoryRoot, item.path))); const sourceCache = new Map(); const reachableCache = new Map();
  const edgeImportNames = (edge) => ts.isImportDeclaration(edge.node) ? importInfo(edge.node).names : [];
  const readSource = (file) => { if (!sourceCache.has(file)) sourceCache.set(file, parseSource(file, fs.readFileSync(file, 'utf8'))); return sourceCache.get(file); };
  const reachable = (file, stack = new Set()) => {
    if (reachableCache.has(file)) return reachableCache.get(file);
    if (stack.has(file)) throw new Error('R12A cyclic local forwarding facade');
    const nextStack = new Set(stack); nextStack.add(file); const result = new Map(); const move = targets.get(file); if (move && activeMoves.has(move.id)) result.set(file, move);
    const sourceAst = readSource(file); const facade = localModuleIsFacade(sourceAst); const forwardingEdges = localModuleEdges(sourceAst).filter((edge) => !edge.typeOnly && edge.kind === 'require');
    if (facade?.kind === 'cjs' && forwardingEdges.length > 1) throw new Error('R12A ambiguous local forwarding facade');
    for (const edge of localModuleEdges(sourceAst)) { const follows = edge.kind === 'export' || (facade?.kind === 'esm' && edge.kind === 'import') || (facade?.kind === 'cjs' && edge.kind === 'require'); if (edge.typeOnly || !follows) continue; const child = resolveLocalModule(sourceRoot, file, edge.specifier); for (const [target, targetMove] of reachable(child, nextStack)) result.set(target, targetMove); }
    reachableCache.set(file, result); return result;
  };
  for (const file of filesUnder(sourceRoot)) {
    const sourcePath = `backend/${path.relative(backendRoot, file).replace(/\\/gu, '/')}`; const ast = readSource(file);
    for (const edge of localModuleEdges(ast)) {
      const resolved = resolveLocalModule(sourceRoot, file, edge.specifier); if (edge.typeOnly) continue;
      const resolvedPath = `backend/${path.relative(backendRoot, resolved).replace(/\\/gu, '/')}`;
      const reachableFiles = reachable(resolved);
      if (sourcePath.startsWith('backend/src/modules/backoffice/public/') && resolvedPath.startsWith('backend/src/modules/identity/public/')) throw new Error('R12A runtime Backoffice-public to Identity-public import is forbidden');
      for (const [targetPathAbsolute, move] of reachableFiles) {
        const targetPath = move.to;
        if (sourcePath.startsWith('backend/src/modules/backoffice/public/') && targetPath.startsWith('backend/src/modules/backoffice/public/')) continue;
        if (!consumers.has(file) && !isAllowedR12aRuntimePublicEdge({ sourcePath, targetPath, importedNames: edgeImportNames(edge), stage: manifest.stage }, manifest)) throw new Error(`R12A unapproved source consumer: ${sourcePath} -> ${targetPath}`);
        if (sourcePath.startsWith('backend/src/modules/backoffice/public/') && targetPath.startsWith('backend/src/modules/identity/public/')) throw new Error('R12A runtime Backoffice-public to Identity-public import is forbidden');
        void targetPathAbsolute;
      }
    }
  }
}
function isExactRetiredException(text, exception) {
  if (exception.path.endsWith('.dependency-cruiser.cjs')) {
    return /const relocatedIdentityUsersService\s*=\s*'\^src\/modules\/identity\/internal\/profile\/users\\\\\.service\\\\\.ts\$';/u.test(text)
      && /const providerReviewRating\s*=\s*'\^src\/marketplace\/provider-review-rating\\\\\.ts\$';/u.test(text)
      && /\.\.\.makeContextRule\(name, ownRoots, \[\], providerReviewRating\),\s*name:\s*'context-identity-relocated-users-helper-cross-context',\s*from:\s*\{\s*path:\s*relocatedIdentityUsersService\s*\}/u.test(text);
  }
  return text.includes(exception.identity);
}
function verifyR12aSiblingExceptionText(text, relative) { const entry = SIBLING_EXCEPTIONS.find(([pathName]) => pathName === relative); if (!entry || !entry[1].every((needle) => text.includes(needle))) throw new Error('R12A sibling provider-access-policy exception was removed'); return true; }
 function scanR12aBackofficeCatalogPublicContracts({ repositoryRoot, manifest, readImmutableFile }) { if (typeof repositoryRoot !== 'string' || !path.isAbsolute(repositoryRoot)) throw new Error('R12A repository root must be absolute'); const checked = validateR12aManifest(manifest); const stage = checked.stages[checked.stage]; identity.verifyRepositoryIdentity(repositoryRoot, BASE_COMMIT); const ownRelative = ENTRY_OWNERSHIP_PATH; const entry = readR12aImmutableEntry({ repositoryRoot, manifest: checked, readImmutableFile }); const entryDep = entry.dependency; const entryOwn = entry.ownership; const ownFile = inspectFile(repositoryRoot, ownRelative); const liveDep = JSON.parse(readR12aSuccessorDependencyBytes(repositoryRoot).toString('utf8')); const liveOwn = JSON.parse(fs.readFileSync(ownFile, 'utf8')); if (JSON.stringify(liveDep) !== JSON.stringify(expectedR12aSuccessorDependencyRecords({ repositoryRoot, r12aEntryRecords: entryDep, r12aManifest: checked, readImmutableFile })) || JSON.stringify(liveOwn) !== JSON.stringify(expectedR12aOwnershipBaseline(entryOwn, checked))) throw new Error('R12A baseline parity drift detected'); const predecessorContractBytes = r12aSuccessorPredecessorBytes({ repositoryRoot, r12aEntryRecords: entryDep, r12aManifest: checked, readImmutableFile }); for (const move of checked.moves) { const sourcePath = inspectFile(repositoryRoot, move.from); const targetPath = inspectFile(repositoryRoot, move.to); const active = stage.activeMoveIds.includes(move.id); validateR12aMoveLayout(sourcePath, targetPath, active); const historical = readImmutable(repositoryRoot, move.from, checked); const live = fs.readFileSync(active ? targetPath : sourcePath, 'utf8'); if (!active) { if (sha256(live) !== move.entrySha256) throw new Error('R12A legacy source drift detected'); } else { verifyR12aSourceParity({ historicalSource: historical, liveSource: live, move }); verifyR12aPublicExportInventory(live, move); } } for (const contract of [...checked.consumers, ...checked.behavioralTests]) { const file = inspectFile(repositoryRoot, contract.path); if (!file) throw new Error('R12A contract path is missing'); verifyR12aLiteralParity({ historicalSource: readImmutable(repositoryRoot, contract.path, checked), liveSource: predecessorContractBytes.get(contract.path) || fs.readFileSync(file), contract, manifest: checked }); } for (const exception of checked.exceptionRetirement) { const text = fs.readFileSync(inspectFile(repositoryRoot, exception.path), 'utf8'); if (isExactRetiredException(text, exception) !== (checked.stage !== 'strict')) throw new Error('R12A provider rating exception state is invalid'); } for (const [relative] of SIBLING_EXCEPTIONS) verifyR12aSiblingExceptionText((predecessorContractBytes.get(relative) || fs.readFileSync(inspectFile(repositoryRoot, relative))).toString('utf8'), relative); checkGuardOrder(repositoryRoot); checkRuntimeEdges(repositoryRoot, checked); return Object.freeze({ ok: true, stage: checked.stage, dependencyRecords: liveDep.length, ownershipRecords: liveOwn.violations.length, ownershipOccurrences: liveOwn.violations.reduce((sum, item) => sum + item.count, 0), legacyPaths: checked.moves.filter((move) => stage.activeMoveIds.includes(move.id) && inspectFile(repositoryRoot, move.from)).map((move) => move.from) }); }

 function runCli() { try { if (process.argv.slice(2).join(' ') !== '--check') throw new Error('invalid arguments'); const root = path.resolve(__dirname, '../../..'); const manifest = JSON.parse(fs.readFileSync(path.join(root, ...MANIFEST_PATH.split('/')), 'utf8')); const result = scanR12aBackofficeCatalogPublicContracts({ repositoryRoot: root, manifest }); process.stdout.write(`PASS - R12A Backoffice/Catalog public contracts: stage=${result.stage}, dependency=${result.dependencyRecords}, ownership=${result.ownershipRecords}/${result.ownershipOccurrences}\n`); return 0; } catch (error) { if (process.env.R12A_DEBUG === '1') process.stderr.write(`${error.stack || error}\n`); else process.stderr.write('ERROR - R12A Backoffice/Catalog public contracts validation failed\n'); return 2; } }
 module.exports = { MANIFEST_PATH, dependencyKey, expectedR12aDependencyRecords, expectedR12aSuccessorDependencyRecords, expectedR12aOwnershipBaseline, isAllowedR12aRuntimePublicEdge, normalizeR12aIdentityProviderRatingImport, readR12aImmutableEntry, readR12aSuccessorDependencyBytes, runCli, checkGuardOrder, checkRuntimeEdges, exportedNames, inspectFile, verifyR12aPublicExportInventory, verifyR12aSiblingExceptionText, isExactRetiredException, scanR12aBackofficeCatalogPublicContracts, validateR12aMoveLayout, verifyR12aConsumerParity, validateR12aManifest, verifyR12aLiteralParity, verifyR12aSourceParity };
if (require.main === module) process.exitCode = runCli();
