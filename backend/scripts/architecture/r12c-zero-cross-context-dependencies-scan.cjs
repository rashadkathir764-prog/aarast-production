'use strict';

const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const { createRequire, wrap: wrapModule } = require('node:module');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const { types } = require('node:util');
const vm = require('node:vm');
const security = require('../security/prisma-config-merge-security.cjs');
const r12b = require('./r12b-planning-public-contracts-scan.cjs');

const MANIFEST_PATH = 'backend/architecture/r12c-zero-cross-context-dependencies.json';
const R12B_PATH = 'backend/architecture/r12b-planning-public-contracts.json';
const DEPENDENCY_PATH = 'backend/.dependency-cruiser-known-violations.json';
const OWNERSHIP_PATH = 'backend/architecture/ownership-baseline.json';
const ROOT = 'D:/projects/aarast-modular-monolith';
const HEAD = '4d0d3ee91fb32d0432aa3bd69fe018d9a5a323b1';
const R12B_SHA = '1bf0c2d00886f1ec442187f2719c4d604b0ebcc57a3ada56d97006015c029845';
const DEPENDENCY_SHA = 'fe4d3bfe23cf0400266bbfea8bd0357d578b93cad005c77af0814ec52ccfcb53';
const OWNERSHIP_SHA = '5f42f33300a9727f587e62327c5261a88a6ce5928437241c9e7c20f726906496';
// Immutable design-entry identity, records, complete predecessor overlay and
// contract registry. Generated live file fingerprints are deliberately separate.
const AUTHORITY_SHA = '32055ad03f3bea727e6d844ce0ec1607ee1c90098af9b458d1a119e4d1fe1510';
const HASH = /^[0-9a-f]{64}$/u;
const INVERSE_PATHS = Object.freeze([
  'backend/package.json',
  'backend/scripts/architecture/r12b-planning-public-contracts-scan.cjs',
  'backend/test/architecture-r12b-planning-public-contracts.test.ts',
  'backend/scripts/security/prisma-config-merge-security.cjs',
  'backend/test/prisma-config-merge-security.test.ts',
]);
const NEW_PATHS = Object.freeze([
  MANIFEST_PATH,
  'backend/scripts/architecture/r12c-zero-cross-context-dependencies-scan.cjs',
  'backend/test/architecture-r12c-zero-cross-context-dependencies.test.ts',
  'docs/superpowers/specs/2026-09-08-modular-monolith-r12c-zero-cross-context-dependencies-design.md',
  'docs/superpowers/plans/2026-09-08-modular-monolith-r12c-zero-cross-context-dependencies.md',
]);
const sha = (value) => crypto.createHash('sha256').update(value).digest('hex');
const serialize = (value) => Buffer.from(`${JSON.stringify(value, null, 2)}\n`, 'utf8');
const plainData = (value) => security.fingerprintPlainJson(value);

function plainOptions(value, keys) {
  if (!value || typeof value !== 'object' || types.isProxy(value)
      || Object.getPrototypeOf(value) !== Object.prototype) throw new Error('R12C input must be a plain object');
  for (const key of Reflect.ownKeys(value)) {
    const descriptor = Object.getOwnPropertyDescriptor(value, key);
    if (typeof key !== 'string' || !keys.includes(key) || !descriptor.enumerable
        || !Object.prototype.hasOwnProperty.call(descriptor, 'value')) throw new Error('R12C input has invalid properties');
  }
  return value;
}

function authorityFingerprint(value) {
  plainData(value);
  const normalized = { ...value, stage: 'design' };
  const { governedFiles, inverseTransforms, normalizedSelfSha256, messagingLifecycleCandidate, marketplacePublicCandidate, strictCandidate, ...authority } = normalized;
  return sha(JSON.stringify(authority));
}

function validateR12cManifest(value) {
  plainData(value);
  assert.deepStrictEqual(Object.keys(value), [
    'schemaVersion', 'phase', 'stage', 'repository', 'predecessor', 'stages',
    'dependencyRecords', 'ownership', 'contractFamilies', 'financePublicCandidate', 'messagingLifecycleCandidate', 'marketplacePublicCandidate', 'strictCandidate', 'sourceFiles',
    'futurePaths', 'planningPaths', 'planningFiles', 'protectedSurfaces',
    'inverseEntries', 'governedFiles', 'inverseTransforms', 'normalizedSelfSha256',
  ]);
  if (authorityFingerprint(value) !== AUTHORITY_SHA) throw new Error('R12C immutable design authority changed');
  if (!['design', 'finance-public', 'messaging-lifecycle-public', 'zero-proven', 'strict'].includes(value.stage)) throw new Error('R12C active stage is invalid');
  validateStrictCandidate(value.strictCandidate);
  validateMessagingLifecycleCandidate(value.messagingLifecycleCandidate);
  validateMarketplacePublicCandidate(value.marketplacePublicCandidate);
  validateFinancePublicCandidate(value.financePublicCandidate);
  const expectedPaths = [...NEW_PATHS, ...INVERSE_PATHS];
  assert.deepStrictEqual(value.governedFiles.map((item) => item.path), expectedPaths);
  for (const [index, item] of value.governedFiles.entries()) {
    assert.deepStrictEqual(Object.keys(item), ['path', 'status', 'hashMode', 'sha256']);
    const expectedStatus = NEW_PATHS.includes(item.path) ? '??'
      : value.predecessor.overlayLedger.find((row) => row.path === item.path).status;
    if (item.status !== expectedStatus) throw new Error('R12C governed status changed');
    if (index === 0) {
      if (item.hashMode !== 'normalized-self' || item.sha256 !== null) throw new Error('R12C normalized-self contract changed');
    } else if (item.hashMode !== 'raw' || !HASH.test(item.sha256) || /^0+$/u.test(item.sha256)) {
      throw new Error('R12C raw file fingerprint is invalid');
    }
  }
  assert.deepStrictEqual(value.inverseTransforms.map((item) => item.path), INVERSE_PATHS);
  for (const [index, inverse] of value.inverseTransforms.entries()) {
    validateInverse(inverse);
    if (inverse.entrySha256 !== value.inverseEntries[index].sha256
        || inverse.liveSha256 !== value.governedFiles.find((item) => item.path === inverse.path).sha256) {
      throw new Error('R12C inverse fingerprint changed');
    }
  }
  if (!HASH.test(value.normalizedSelfSha256)) throw new Error('R12C normalized-self hash is invalid');
  const normalized = { ...value, normalizedSelfSha256: '0'.repeat(64) };
  if (sha(serialize(normalized)) !== value.normalizedSelfSha256) throw new Error('R12C normalized-self fingerprint changed');
  return value;
}

function validateFinancePublicCandidate(value) {
  plainData(value);
  assert.deepStrictEqual(Object.keys(value), ['stage', 'move', 'consumerRewrites', 'dependencyLedger', 'ownership']);
  if (value.stage !== 'finance-public') throw new Error('R12C Finance candidate stage changed');
  const move = value.move;
  plainData(move);
  assert.deepStrictEqual(Object.keys(move), ['kind', 'source', 'target', 'entrySha256', 'candidateSha256', 'byteLength', 'sourceEntryStatus', 'sourceCandidateStatus', 'targetCandidateStatus', 'inverse']);
  if (move.kind !== 'byte-identical-move'
      || move.source !== 'backend/src/wedding-costs/wedding-cost.presenter.ts'
      || move.target !== 'backend/src/modules/finance/public/wedding-cost.presenter.ts'
      || move.entrySha256 !== move.candidateSha256
      || !HASH.test(move.entrySha256) || move.byteLength !== 2040
      || move.sourceEntryStatus !== null || move.sourceCandidateStatus !== ' D' || move.targetCandidateStatus !== '??') {
    throw new Error('R12C Finance move candidate changed');
  }
  assert.deepStrictEqual(move.inverse, { from: move.target, to: move.source });
  if (!Array.isArray(value.consumerRewrites) || value.consumerRewrites.length !== 3) throw new Error('R12C Finance consumer candidate changed');
  for (const rewrite of value.consumerRewrites) {
    plainData(rewrite);
    assert.deepStrictEqual(Object.keys(rewrite), ['path', 'entrySha256', 'candidateSha256', 'entryStatus', 'candidateStatus', 'from', 'to', 'inverse']);
    if (!HASH.test(rewrite.entrySha256) || !HASH.test(rewrite.candidateSha256)
        || rewrite.candidateStatus !== ' M' || rewrite.to !== '../modules/finance/public/wedding-cost.presenter') {
      throw new Error('R12C Finance consumer rewrite changed');
    }
    assert.deepStrictEqual(rewrite.inverse, { from: rewrite.to, to: rewrite.from });
  }
  assert.deepStrictEqual(value.consumerRewrites.map((item) => item.path), [
    'backend/src/wedding-costs/wedding-costs.service.ts',
    'backend/src/marketplace/marketplace.service.ts',
    'backend/src/marketplace/quote-offer-acceptance.ts',
  ]);
  assert.deepStrictEqual(value.consumerRewrites.map((item) => item.entryStatus), [null, ' M', null]);
  const ledger = value.dependencyLedger;
  plainData(ledger);
  assert.deepStrictEqual(Object.keys(ledger), ['path', 'entrySha256', 'candidateSha256', 'entryStatus', 'candidateStatus', 'entryRecordIds', 'retiredIds', 'candidateRecordIds', 'candidateRecords']);
  if (ledger.path !== DEPENDENCY_PATH || ledger.entrySha256 !== DEPENDENCY_SHA
      || !HASH.test(ledger.candidateSha256) || ledger.entryStatus !== ' M' || ledger.candidateStatus !== ' M') {
    throw new Error('R12C Finance dependency candidate changed');
  }
  assert.deepStrictEqual(ledger.entryRecordIds, [10, 12, 13, 14, 15, 16, 17, 19, 20]);
  assert.deepStrictEqual(ledger.retiredIds, [10, 13]);
  assert.deepStrictEqual(ledger.candidateRecordIds, [12, 14, 15, 16, 17, 19, 20]);
  if (ledger.candidateRecords !== 7) throw new Error('R12C Finance dependency count changed');
  assert.deepStrictEqual(value.ownership, {
    path: OWNERSHIP_PATH, sha256: OWNERSHIP_SHA, records: 385, occurrences: 781,
  });
}

function chunksToBytes(chunks) {
  plainData(chunks);
  if (!Array.isArray(chunks) || chunks.length > 512) throw new Error('R12C inverse chunks are unbounded');
  const buffers = chunks.map((chunk) => {
    if (typeof chunk !== 'string' || chunk.length > 8192 || chunk.length === 0) throw new Error('R12C inverse chunk is invalid');
    const bytes = Buffer.from(chunk, 'base64');
    if (bytes.toString('base64') !== chunk) throw new Error('R12C inverse base64 is not canonical');
    return bytes;
  });
  const bytes = Buffer.concat(buffers);
  if (bytes.length > 2097152) throw new Error('R12C inverse payload is unbounded');
  return bytes;
}

function validateInverse(inverse) {
  plainData(inverse);
  assert.deepStrictEqual(Object.keys(inverse), ['path', 'kind', 'entrySha256', 'liveSha256', 'entryByteLength', 'offset', 'beforeBase64', 'afterBase64']);
  if (!INVERSE_PATHS.includes(inverse.path) || inverse.kind !== 'bounded-byte-splice'
      || !HASH.test(inverse.entrySha256) || !HASH.test(inverse.liveSha256)
      || !Number.isSafeInteger(inverse.entryByteLength) || inverse.entryByteLength < 1 || inverse.entryByteLength > 2097152
      || !Number.isSafeInteger(inverse.offset) || inverse.offset < 0 || inverse.offset > inverse.entryByteLength) throw new Error('R12C inverse contract is invalid');
  const before = chunksToBytes(inverse.beforeBase64);
  const after = chunksToBytes(inverse.afterBase64);
  if (before.equals(after) || before.length > inverse.entryByteLength - inverse.offset) throw new Error('R12C inverse range changed');
  return { before, after };
}

function projectR12cFileToPredecessor(bytes, inverse) {
  const { before, after } = validateInverse(inverse);
  if (!Buffer.isBuffer(bytes) || bytes.length !== inverse.entryByteLength - before.length + after.length
      || sha(bytes) !== inverse.liveSha256
      || !bytes.subarray(inverse.offset, inverse.offset + after.length).equals(after)) throw new Error('R12C inverse live bytes changed');
  const projected = Buffer.concat([bytes.subarray(0, inverse.offset), before, bytes.subarray(inverse.offset + after.length)]);
  if (sha(projected) !== inverse.entrySha256) throw new Error('R12C inverse predecessor bytes changed');
  return projected;
}

function expectedR12cDependencyRecords(records, manifest) {
  const checked = validateR12cManifest(manifest);
  plainData(records);
  const retired = new Set(checked.stages[checked.stage].retiredDependencyIds);
  const expected = checked.dependencyRecords.filter((item) => !retired.has(item.id)).map(({ id, ...record }) => record);
  // Full ordered records, not a count or a partial semantic-key comparison.
  assert.deepStrictEqual(records, expected);
  return structuredClone(expected);
}

function replaceSingleSpecifier(bytes, from, to, label) {
  if (!Buffer.isBuffer(bytes)) throw new Error(`R12C Finance bytes are missing: ${label}`);
  const source = Buffer.from(`"${from}"`, 'utf8');
  const target = Buffer.from(`"${to}"`, 'utf8');
  const offset = bytes.indexOf(source);
  if (offset < 0 || bytes.indexOf(source, offset + source.length) >= 0) throw new Error(`R12C Finance import specifier changed: ${label}`);
  return Buffer.concat([bytes.subarray(0, offset), target, bytes.subarray(offset + source.length)]);
}

function verifyFinancePublicFiles(read, exists, manifest) {
  const candidate = manifest.financePublicCandidate;
  const { move } = candidate;
  if (exists(move.source)) throw new Error('R12C Finance legacy presenter still exists');
  if (!exists(move.target)) throw new Error('R12C Finance public target is missing');
  const presenter = read(move.target);
  if (presenter.length !== move.byteLength || sha(presenter) !== move.candidateSha256) throw new Error('R12C Finance presenter parity changed');
  const exports = [...presenter.toString('utf8').matchAll(/^export\s+(?:const|type|interface|function)\s+([A-Za-z0-9_]+)/gmu)].map((match) => match[1]);
  assert.deepStrictEqual(exports, manifest.contractFamilies[0].exports);
  const reconstructed = new Map([[move.source, Buffer.from(presenter)]]);
  for (const rewrite of candidate.consumerRewrites) {
    const bytes = read(rewrite.path);
    if (sha(bytes) !== rewrite.candidateSha256) throw new Error(`R12C Finance consumer bytes changed: ${rewrite.path}`);
    const entry = replaceSingleSpecifier(bytes, rewrite.to, rewrite.from, rewrite.path);
    if (sha(entry) !== rewrite.entrySha256) throw new Error(`R12C Finance consumer changed beyond its import: ${rewrite.path}`);
    reconstructed.set(rewrite.path, entry);
  }
  const dependencyBytes = read(candidate.dependencyLedger.path);
  if (sha(dependencyBytes) !== candidate.dependencyLedger.candidateSha256) throw new Error('R12C Finance dependency bytes changed');
  const dependencyRecords = manifest.dependencyRecords.filter((row) => ![10, 13].includes(row.id)).map(({ id, ...row }) => row);
  assert.deepStrictEqual(JSON.parse(dependencyBytes.toString('utf8')), dependencyRecords);
  const entryDependencyBytes = serialize(manifest.dependencyRecords.map(({ id, ...record }) => record));
  if (sha(entryDependencyBytes) !== candidate.dependencyLedger.entrySha256) throw new Error('R12C Finance dependency inverse changed');
  reconstructed.set(candidate.dependencyLedger.path, entryDependencyBytes);
  const ownership = verifyR12cOwnership(read(OWNERSHIP_PATH), manifest);
  return { reconstructed, exports, dependencyRecords: dependencyRecords.length, ownershipRecords: ownership.ownershipRecords, ownershipOccurrences: ownership.ownershipOccurrences };
}

function listTypeScriptFiles(directory) {
  const files = [];
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const target = path.join(directory, entry.name);
    if (entry.isSymbolicLink()) throw new Error('R12C Finance source symlink is forbidden');
    if (entry.isDirectory()) files.push(...listTypeScriptFiles(target));
    else if (entry.isFile() && entry.name.endsWith('.ts')) files.push(target);
  }
  return files;
}

function verifyR12cFinanceProjection(input) {
  plainOptions(input, ['repositoryRoot', 'manifest']);
  const { repositoryRoot, manifest } = input;
  validateR12cManifest(manifest);
  verifyIdentity(repositoryRoot);
  const strict = strictPredecessorFiles(
    relative => fs.readFileSync(r12b.inspectPlainFile(repositoryRoot, relative)),
    relative => Boolean(r12b.inspectPlainFile(repositoryRoot, relative, false)), manifest);
  const { read: rawRead, exists } = strict;
  const marketplace = ['zero-proven', 'strict'].includes(manifest.stage)
    ? verifyMarketplacePublicFiles(rawRead, exists, manifest, repositoryRoot).reconstructed : new Map();
  const marketplaceRead = (relative) => marketplace.has(relative) ? marketplace.get(relative) : rawRead(relative);
  const lifecycle = ['messaging-lifecycle-public', 'zero-proven', 'strict'].includes(manifest.stage)
    ? verifyMessagingLifecycleFiles(marketplaceRead, exists, manifest).reconstructed : new Map();
  const read = (relative) => lifecycle.has(relative) ? lifecycle.get(relative) : marketplaceRead(relative);
  const result = verifyFinancePublicFiles(read, exists, manifest);
  const expectedSpecifier = '../modules/finance/public/wedding-cost.presenter';
  const consumers = listTypeScriptFiles(path.join(repositoryRoot, 'backend/src')).filter((file) => {
    const text = fs.readFileSync(file, 'utf8');
    return text.includes(`from "${expectedSpecifier}"`) || text.includes(`from '${expectedSpecifier}'`);
  }).map((file) => path.relative(repositoryRoot, file).replaceAll('\\', '/')).sort();
  assert.deepStrictEqual(consumers, manifest.financePublicCandidate.consumerRewrites.map((item) => item.path).sort());
  return { ok: true, stage: 'finance-public', legacyPaths: 0, publicPaths: 1, consumers: consumers.length, exports: result.exports, dependencyRecords: result.dependencyRecords, ownershipRecords: result.ownershipRecords, ownershipOccurrences: result.ownershipOccurrences };
}


function validateMessagingLifecycleCandidate(candidate) {
  plainData(candidate);
  if (sha(JSON.stringify(candidate)) !== 'a46dbbbf7496cef00ab4e38155ef745ac685cf489940b509a47e7f55c71fd52a') {
    throw new Error('R12C preregistered Messaging lifecycle candidate changed');
  }
}

function validateMarketplacePublicCandidate(candidate) {
  plainData(candidate);
  if (sha(JSON.stringify(candidate)) !== 'cc238a9001cf360765b3168b68611fe9d56760ac2527bf4ce3a02c7eeeee3adc') {
    throw new Error('R12C preregistered Marketplace public candidate changed');
  }
}

function validateStrictCandidate(candidate) {
  plainData(candidate);
  if (sha(JSON.stringify(candidate)) !== 'f592fe3c397609deac89c8294caf9a07723f5634cca6881b6c62a84363806ae2') {
    throw new Error('R12C preregistered strict candidate changed');
  }
}

// Reconstruct only the exact approved Task 5 bytes. This is an in-memory
// historical proof, never a new dependency allowance or a file on disk.
function strictPredecessorFiles(read, exists, manifest) {
  const reconstructed = new Map();
  if (manifest.stage !== 'strict') return { read, exists, reconstructed };
  validateStrictCandidate(manifest.strictCandidate);
  if (exists(DEPENDENCY_PATH)) throw new Error('R12C strict dependency baseline must be absent');
  const empty = Buffer.from('[]\n', 'utf8');
  if (sha(empty) !== manifest.marketplacePublicCandidate.dependencyLedger.candidateSha256) {
    throw new Error('R12C reviewed zero-proven ledger changed');
  }
  const packageJson = JSON.parse(read('backend/package.json').toString('utf8'));
  if (packageJson.scripts['architecture:imports'] !== 'depcruise --config .dependency-cruiser.cjs src') {
    throw new Error('R12C strict import command changed');
  }
  security.projectR12CArchitectureScripts(packageJson);
  reconstructed.set(DEPENDENCY_PATH, empty);
  for (const row of manifest.strictCandidate.records) {
    if (!exists(row.path)) throw new Error('R12C strict candidate is missing: ' + row.path);
    reconstructed.set(row.path, reconstructMarketplaceCandidateRecord(read(row.path), row));
  }
  return {
    reconstructed,
    read: relative => reconstructed.has(relative) ? Buffer.from(reconstructed.get(relative)) : read(relative),
    exists: relative => reconstructed.has(relative) || exists(relative),
  };
}

function readR12cStrictDependencyBytes(repositoryRoot) {
  const manifestFile = r12b.inspectPlainFile(repositoryRoot, MANIFEST_PATH);
  const manifest = validateR12cManifest(JSON.parse(fs.readFileSync(manifestFile, 'utf8')));
  if (manifest.stage !== 'strict') throw new Error('R12C missing baseline is permitted only at strict');
  // Full byte/status/source/ownership reconstruction must succeed before any
  // historical authority receives the exact zero projection.
  projectR12cWorkingTreeToPredecessor({ repositoryRoot, manifest });
  return serialize(expectedR12cDependencyRecords([], manifest));
}

function inspectMarketplacePolicyPath(repositoryRoot, relative, required = true) {
  const exact = 'backend/src/modules/marketplace/public/provider-access-policy.ts';
  if (relative !== exact) throw new Error('R12C Marketplace policy path is not exact');
  return r12b.inspectPlainFile(repositoryRoot, relative, required);
}

function reconstructMarketplaceCandidateRecord(bytes, row) {
  if (!Buffer.isBuffer(bytes) || sha(bytes) !== row.candidateSha256) {
    throw new Error('R12C Marketplace candidate bytes changed: ' + row.path);
  }
  if (row.kind === 'bounded-byte-splices') {
    if (!Array.isArray(row.splices) || row.splices.length < 1 || row.splices.length > 256
        || !HASH.test(row.entrySha256) || !Number.isSafeInteger(row.entryByteLength)
        || row.entryByteLength < 1 || row.entryByteLength > 2097152) {
      throw new Error('R12C strict multi-splice inverse is invalid: ' + row.path);
    }
    let previousEnd = 0;
    const splices = row.splices.map((splice) => {
      plainData(splice);
      if (Object.keys(splice).join('|') !== 'offset|beforeBase64|afterBase64'
          || !Number.isSafeInteger(splice.offset) || splice.offset < previousEnd) {
        throw new Error('R12C strict multi-splice range is invalid: ' + row.path);
      }
      const before = chunksToBytes(splice.beforeBase64);
      const after = chunksToBytes(splice.afterBase64);
      if (before.equals(after) || splice.offset + after.length > bytes.length) {
        throw new Error('R12C strict multi-splice payload is invalid: ' + row.path);
      }
      previousEnd = splice.offset + after.length;
      return { offset: splice.offset, before, after };
    });
    let entry = Buffer.from(bytes);
    for (const splice of [...splices].reverse()) {
      if (!entry.subarray(splice.offset, splice.offset + splice.after.length).equals(splice.after)) {
        throw new Error('R12C strict multi-splice candidate range changed: ' + row.path);
      }
      entry = Buffer.concat([
        entry.subarray(0, splice.offset),
        splice.before,
        entry.subarray(splice.offset + splice.after.length),
      ]);
    }
    if (entry.length !== row.entryByteLength || sha(entry) !== row.entrySha256) {
      throw new Error('R12C strict multi-splice entry bytes changed: ' + row.path);
    }
    return entry;
  }
  const before = chunksToBytes(row.beforeBase64);
  const after = chunksToBytes(row.afterBase64);
  if (row.kind === 'new-file') {
    if (row.entrySha256 !== null || row.entryByteLength !== 0 || row.offset !== 0
        || before.length !== 0 || !bytes.equals(after)) throw new Error('R12C Marketplace new-file inverse changed');
    return null;
  }
  if (row.kind !== 'bounded-byte-splice' || !HASH.test(row.entrySha256)
      || bytes.length !== row.entryByteLength - before.length + after.length
      || !bytes.subarray(row.offset, row.offset + after.length).equals(after)) {
    throw new Error('R12C Marketplace bounded inverse range changed: ' + row.path);
  }
  const entry = Buffer.concat([bytes.subarray(0, row.offset), before, bytes.subarray(row.offset + after.length)]);
  if (sha(entry) !== row.entrySha256) throw new Error('R12C Marketplace entry bytes changed: ' + row.path);
  return entry;
}

function marketplacePolicyReferences(repositoryRoot, targetRelative) {
  const ts = require('typescript');
  const targetAbsolute = path.resolve(repositoryRoot, ...targetRelative.split('/'));
  const consumers = [];
  const declarations = [];
  for (const file of listTypeScriptFiles(path.join(repositoryRoot, 'backend/src'))) {
    const relative = path.relative(repositoryRoot, file).replaceAll('\\', '/');
    const source = fs.readFileSync(file, 'utf8');
    const ast = ts.createSourceFile(relative, source, ts.ScriptTarget.Latest, true);
    const importedPolicyNames = new Set();
    for (const statement of ast.statements) {
      if (ts.isImportDeclaration(statement) && ts.isStringLiteralLike(statement.moduleSpecifier)) {
        const specifier = statement.moduleSpecifier.text;
        if (!specifier.includes('provider-access-policy')) continue;
        const resolved = path.resolve(path.dirname(file), `${specifier}.ts`);
        if (path.resolve(resolved) !== targetAbsolute) throw new Error(`R12C alternate Marketplace policy import is forbidden: ${relative}`);
        consumers.push(relative);
        const named = statement.importClause?.namedBindings;
        if (named && ts.isNamedImports(named)) for (const item of named.elements) importedPolicyNames.add(item.name.text);
      }
      if (ts.isExportDeclaration(statement)) {
        if (statement.moduleSpecifier && ts.isStringLiteralLike(statement.moduleSpecifier)
            && statement.moduleSpecifier.text.includes('provider-access-policy')) {
          throw new Error(`R12C Marketplace policy re-export is forbidden: ${relative}`);
        }
        if (!statement.moduleSpecifier && statement.exportClause && ts.isNamedExports(statement.exportClause)
            && statement.exportClause.elements.some((item) => importedPolicyNames.has(item.propertyName?.text || item.name.text))) {
          throw new Error(`R12C Marketplace policy local re-export is forbidden: ${relative}`);
        }
      }
    }
    const visit = (node) => {
      if (ts.isCallExpression(node) && (node.expression.kind === ts.SyntaxKind.ImportKeyword
          || (ts.isIdentifier(node.expression) && node.expression.text === 'require'))
          && node.arguments.some((argument) => ts.isStringLiteralLike(argument)
            && argument.text.includes('provider-access-policy'))) {
        throw new Error(`R12C dynamic Marketplace policy import is forbidden: ${relative}`);
      }
      ts.forEachChild(node, visit);
    };
    visit(ast);
    if (relative !== targetRelative
        && /^export\s+(?:const|type|interface|function)\s+(?:PROVIDER_NOT_ACTIVE|PROVIDER_PROFILE_READ_ONLY|PROVIDER_PORTAL_ROUTE|ProviderAccessCapabilities|ProviderAccessMode|ProviderAccessPolicy|isProviderOperational|providerAccessPolicy|assertProviderOperational|assertProviderProfileWritable)\b/mu.test(source)) {
      declarations.push(relative);
    }
  }
  if (declarations.length !== 0) throw new Error('R12C Marketplace policy copy is forbidden: ' + declarations.join(','));
  return consumers.sort();
}

function verifyMarketplacePublicFiles(read, exists, manifest, repositoryRoot) {
  const candidate = manifest.marketplacePublicCandidate;
  validateMarketplacePublicCandidate(candidate);
  const { move } = candidate;
  if (exists(move.source)) throw new Error('R12C Marketplace legacy policy still exists');
  if (!inspectMarketplacePolicyPath(repositoryRoot, move.target, false) || !exists(move.target)) {
    throw new Error('R12C Marketplace public policy is missing');
  }
  const target = read(move.target);
  if (target.length !== move.byteLength || sha(target) !== move.candidateSha256) throw new Error('R12C Marketplace policy parity changed');
  const exports = [...target.toString('utf8').matchAll(/^export\s+(?:const|type|interface|function)\s+([A-Za-z0-9_]+)/gmu)].map((match) => match[1]);
  assert.deepStrictEqual(exports, manifest.contractFamilies[2].exports);
  const reconstructed = new Map([[move.source, Buffer.from(target)]]);
  for (const row of candidate.records) {
    if (!exists(row.path)) throw new Error('R12C Marketplace candidate is missing: ' + row.path);
    const entry = reconstructMarketplaceCandidateRecord(read(row.path), row);
    if (entry) reconstructed.set(row.path, entry);
  }
  const consumers = marketplacePolicyReferences(repositoryRoot, move.target);
  assert.deepStrictEqual(consumers, [...candidate.consumerPaths].sort());
  const forbiddenByPath = new Map([
    ['backend/.dependency-cruiser.cjs', ['providerAccessPolicy', 'relocatedIdentityContextsService', 'context-identity-relocated-contexts-helper-cross-context', 'src/provider-dashboard/provider-access-policy']],
    ['backend/scripts/architecture/ports-scan.cjs', ['R5_RELOCATED_IDENTITY_PURE_HELPER_EDGES', 'backend/src/modules/identity/internal/profile/contexts.service.ts|backend/src/provider-dashboard/provider-access-policy.ts']],
    ['backend/scripts/architecture/r3-context-scan.cjs', ['relocatedIdentityPureHelpers', 'legalRelocatedIdentityPureHelper', 'backend/src/modules/identity/internal/profile/contexts.service.ts->backend/src/provider-dashboard/provider-access-policy.ts']],
  ]);
  for (const [relative, needles] of forbiddenByPath) {
    const text = read(relative).toString('utf8');
    for (const needle of needles) if (text.includes(needle)) throw new Error(`R12C Marketplace historical exception remains: ${relative}`);
  }
  const dependencyBytes = read(candidate.dependencyLedger.path);
  if (sha(dependencyBytes) !== candidate.dependencyLedger.candidateSha256
      || !dependencyBytes.equals(Buffer.from('[]\n', 'utf8'))) throw new Error('R12C Marketplace empty dependency ledger changed');
  const records = expectedR12cDependencyRecords(JSON.parse(dependencyBytes.toString('utf8')), manifest);
  const ownership = verifyR12cOwnership(read(OWNERSHIP_PATH), manifest);
  return {
    reconstructed,
    exports,
    consumers: consumers.length,
    dependencyRecords: records.length,
    exceptionAuthorities: 0,
    ownershipRecords: ownership.ownershipRecords,
    ownershipOccurrences: ownership.ownershipOccurrences,
  };
}

function verifyMessagingLifecycleFiles(read, exists, manifest) {
  const candidate = manifest.messagingLifecycleCandidate;
  validateMessagingLifecycleCandidate(candidate);
  const reconstructed = new Map();
  for (const row of candidate.records) {
    if (!exists(row.path)) throw new Error('R12C Messaging lifecycle candidate is missing: ' + row.path);
    const bytes = read(row.path);
    if (!Buffer.isBuffer(bytes) || sha(bytes) !== row.candidateSha256) {
      throw new Error('R12C Messaging lifecycle candidate bytes changed: ' + row.path);
    }
    const before = chunksToBytes(row.beforeBase64);
    const after = chunksToBytes(row.afterBase64);
    if (row.kind === 'new-file') {
      if (!bytes.equals(after) || before.length !== 0 || row.entrySha256 !== null) throw new Error('R12C Messaging new-file inverse changed');
      continue;
    }
    if (bytes.length !== row.entryByteLength - before.length + after.length
        || !bytes.subarray(row.offset, row.offset + after.length).equals(after)) {
      throw new Error('R12C Messaging lifecycle bounded inverse range changed');
    }
    const entry = Buffer.concat([bytes.subarray(0, row.offset), before, bytes.subarray(row.offset + after.length)]);
    if (sha(entry) !== row.entrySha256) throw new Error('R12C Messaging lifecycle entry bytes changed: ' + row.path);
    reconstructed.set(row.path, entry);
  }
  const records = JSON.parse(read(DEPENDENCY_PATH).toString('utf8'));
  const expectedRecords = manifest.dependencyRecords
    .filter((row) => candidate.candidateRecordIds.includes(row.id))
    .map(({ id: ignored, ...row }) => row);
  assert.deepStrictEqual(records, expectedRecords);
  return { reconstructed, dependencyRecords: records.length, ...verifyR12cOwnership(read(OWNERSHIP_PATH), manifest) };
}

function verifyR12cMessagingLifecycleProjection(input) {
  plainOptions(input, ['repositoryRoot', 'manifest']);
  const { repositoryRoot, manifest } = input;
  validateR12cManifest(manifest);
  verifyIdentity(repositoryRoot);
  if (!['messaging-lifecycle-public', 'zero-proven', 'strict'].includes(manifest.stage)) throw new Error('R12C Messaging lifecycle stage is not active');
  const strict = strictPredecessorFiles(
    relative => fs.readFileSync(r12b.inspectPlainFile(repositoryRoot, relative)),
    relative => Boolean(r12b.inspectPlainFile(repositoryRoot, relative, false)), manifest);
  const { read: rawRead, exists } = strict;
  const marketplace = ['zero-proven', 'strict'].includes(manifest.stage)
    ? verifyMarketplacePublicFiles(rawRead, exists, manifest, repositoryRoot).reconstructed : new Map();
  const read = (relative) => marketplace.has(relative) ? marketplace.get(relative) : rawRead(relative);
  const result = verifyMessagingLifecycleFiles(read, exists, manifest);
  return { ok: true, stage: manifest.stage, dependencyRecords: result.dependencyRecords, ownershipRecords: result.ownershipRecords, ownershipOccurrences: result.ownershipOccurrences };
}

function verifyR12cMarketplacePublicProjection(input) {
  plainOptions(input, ['repositoryRoot', 'manifest']);
  const { repositoryRoot, manifest } = input;
  validateR12cManifest(manifest);
  verifyIdentity(repositoryRoot);
  if (!['zero-proven', 'strict'].includes(manifest.stage)) throw new Error('R12C Marketplace public stage is not active');
  const { read, exists } = strictPredecessorFiles(
    relative => fs.readFileSync(r12b.inspectPlainFile(repositoryRoot, relative)),
    relative => Boolean(r12b.inspectPlainFile(repositoryRoot, relative, false)), manifest);
  const result = verifyMarketplacePublicFiles(read, exists, manifest, repositoryRoot);
  return {
    ok: true,
    stage: manifest.stage,
    legacyPaths: 0,
    publicPaths: 1,
    consumers: result.consumers,
    exports: result.exports,
    exceptionAuthorities: result.exceptionAuthorities,
    dependencyRecords: result.dependencyRecords,
    ownershipRecords: result.ownershipRecords,
    ownershipOccurrences: result.ownershipOccurrences,
  };
}

function verifyR12cOwnership(bytes, manifest) {
  validateR12cManifest(manifest);
  if (!Buffer.isBuffer(bytes) || sha(bytes) !== OWNERSHIP_SHA) throw new Error('R12C ownership raw bytes changed');
  const ownership = JSON.parse(bytes.toString('utf8'));
  const ownershipRecords = ownership.violations.length;
  const ownershipOccurrences = ownership.violations.reduce((sum, row) => sum + row.count, 0);
  if (ownershipRecords !== 385 || ownershipOccurrences !== 781) throw new Error('R12C ownership counts changed');
  return { ownershipRecords, ownershipOccurrences };
}

function verifyIdentity(repositoryRoot) {
  if (typeof repositoryRoot !== 'string' || !path.isAbsolute(repositoryRoot)
      || fs.realpathSync.native(repositoryRoot).replaceAll('\\', '/') !== ROOT) throw new Error('R12C repository root changed');
  const git = (args) => execFileSync('git', args, { cwd: repositoryRoot, encoding: 'utf8', windowsHide: true }).trim();
  if (git(['rev-parse', '--show-toplevel']).replaceAll('\\', '/') !== ROOT
      || git(['branch', '--show-current']) !== 'modular-monolith'
      || git(['rev-parse', 'HEAD']) !== HEAD || git(['diff', '--cached', '--name-only']) !== '') throw new Error('R12C repository identity or staging changed');
}

function repositoryRelative(repositoryRoot, candidate) {
  if (typeof candidate !== 'string') return null;
  const absolute = path.resolve(candidate);
  const relative = path.relative(repositoryRoot, absolute);
  if (relative === '' || relative.startsWith('..') || path.isAbsolute(relative)) return null;
  return relative.replaceAll('\\', '/');
}

function scanR12bPredecessorProjection(input) {
  plainOptions(input, ['repositoryRoot', 'manifest', 'projection', 'successorManifest']);
  const { repositoryRoot, manifest, projection, successorManifest } = input;
  verifyIdentity(repositoryRoot);
  r12b.validateR12bManifest(manifest);
  validateR12cManifest(successorManifest);
  if (!projection || typeof projection !== 'object' || types.isProxy(projection)
      || !Array.isArray(projection.statusRows)
      || typeof projection.readWorkingFile !== 'function'
      || typeof projection.pathExists !== 'function') {
    throw new Error('R12C R12B full-scan projection is invalid');
  }
  const scannerRelative = 'backend/scripts/architecture/r12b-planning-public-contracts-scan.cjs';
  const scannerBytes = projection.readWorkingFile(scannerRelative);
  if (!Buffer.isBuffer(scannerBytes)) throw new Error('R12C projected R12B scanner bytes are missing');
  const scannerFile = path.join(repositoryRoot, ...scannerRelative.split('/'));
  const nativeRequire = createRequire(scannerFile);
  const projectedFileStat = Object.freeze({
    isBlockDevice: () => false,
    isCharacterDevice: () => false,
    isDirectory: () => false,
    isFIFO: () => false,
    isFile: () => true,
    isSocket: () => false,
    isSymbolicLink: () => false,
  });
  const resolveProjectedRealpath = (file, options, native) => {
    const relative = repositoryRelative(repositoryRoot, file);
    if (relative === null || fs.existsSync(file) || !projection.pathExists(relative)) {
      return native ? fs.realpathSync.native(file, options) : fs.realpathSync(file, options);
    }
    const resolved = path.resolve(file);
    const encoding = typeof options === 'string' ? options : options?.encoding;
    return encoding === 'buffer' ? Buffer.from(resolved) : resolved;
  };
  const projectedRealpathSync = (file, options) => resolveProjectedRealpath(file, options, false);
  projectedRealpathSync.native = (file, options) => resolveProjectedRealpath(file, options, true);
  const projectedFs = new Proxy(fs, {
    get(target, property, receiver) {
      if (property === 'readFileSync') {
        return (file, options) => {
          const relative = repositoryRelative(repositoryRoot, file);
          if (relative === null) return fs.readFileSync(file, options);
          const bytes = projection.readWorkingFile(relative);
          if (!Buffer.isBuffer(bytes)) {
            const error = new Error(`ENOENT: no such projected file, open '${file}'`);
            error.code = 'ENOENT';
            throw error;
          }
          const encoding = typeof options === 'string' ? options : options?.encoding;
          return encoding ? bytes.toString(encoding) : Buffer.from(bytes);
        };
      }
      if (property === 'existsSync') {
        return (file) => {
          const relative = repositoryRelative(repositoryRoot, file);
          if (relative === null) return fs.existsSync(file);
          if (fs.existsSync(file) && fs.lstatSync(file).isDirectory()) return true;
          return Boolean(projection.pathExists(relative));
        };
      }
      if (property === 'lstatSync') {
        return (file, options) => {
          const relative = repositoryRelative(repositoryRoot, file);
          if (relative !== null && !fs.existsSync(file) && projection.pathExists(relative)) return projectedFileStat;
          return fs.lstatSync(file, options);
        };
      }
      if (property === 'realpathSync') return projectedRealpathSync;
      if (property === 'readdirSync') {
        return (directory, options) => {
          const relativeDirectory = repositoryRelative(repositoryRoot, directory);
          if (relativeDirectory === null || !options?.withFileTypes) return fs.readdirSync(directory, options);
          const entries = fs.readdirSync(directory, options).filter((entry) => {
            if (entry.isDirectory()) return true;
            const relative = `${relativeDirectory}/${entry.name}`;
            return Boolean(projection.pathExists(relative));
          });
          const restored = successorManifest.financePublicCandidate.move.source;
          if (path.posix.dirname(restored) === relativeDirectory
              && projection.pathExists(restored)
              && !entries.some((entry) => entry.name === path.posix.basename(restored))) {
            entries.push({
              name: path.posix.basename(restored),
              isBlockDevice: () => false,
              isCharacterDevice: () => false,
              isDirectory: () => false,
              isFIFO: () => false,
              isFile: () => true,
              isSocket: () => false,
              isSymbolicLink: () => false,
            });
          }
          return entries;
        };
      }
      return Reflect.get(target, property, receiver);
    },
  });
  const childProcess = nativeRequire('node:child_process');
  const projectedChildProcess = { ...childProcess, execFileSync(file, args, options) {
    if (file === 'git' && Array.isArray(args)
        && args.join(' ') === 'status --porcelain=v1 --untracked-files=all') {
      const output = projection.statusRows.map((row) => `${row.status} ${row.path}`).join('\n');
      const bytes = Buffer.from(output.length === 0 ? '' : `${output}\n`, 'utf8');
      const encoding = typeof options === 'string' ? options : options?.encoding;
      return encoding ? bytes.toString(encoding) : bytes;
    }
    return childProcess.execFileSync(file, args, options);
  } };
  const projectedRequire = (request) => {
    if (request === 'node:fs' || request === 'fs') return projectedFs;
    if (request === 'node:child_process' || request === 'child_process') return projectedChildProcess;
    return nativeRequire(request);
  };
  const projectedModule = { exports: {} };
  const compile = new vm.Script(wrapModule(scannerBytes.toString('utf8')), {
    filename: `${scannerFile}#r12c-predecessor-projection`,
  }).runInThisContext();
  compile(projectedModule.exports, projectedRequire, projectedModule, scannerFile, path.dirname(scannerFile));
  const api = projectedModule.exports;
  if (!api || typeof api.scanR12bPlanningPublicContracts !== 'function') {
    throw new Error('R12C projected R12B full scanner interface changed');
  }
  return api.scanR12bPlanningPublicContracts({ repositoryRoot, manifest });
}

function projectR12cWorkingTreeToPredecessor(input) {
  plainOptions(input, ['repositoryRoot', 'manifest', 'statusRows', 'readWorkingFile', 'pathExists']);
  const { repositoryRoot, manifest, statusRows: suppliedRows, readWorkingFile, pathExists } = input;
  const checked = validateR12cManifest(manifest);
  verifyIdentity(repositoryRoot);
  if ((readWorkingFile !== undefined && typeof readWorkingFile !== 'function')
      || (pathExists !== undefined && typeof pathExists !== 'function')
      || (typeof readWorkingFile === 'function') !== (typeof pathExists === 'function')) throw new Error('R12C fixture I/O must be an explicit pair');
  const injected = typeof readWorkingFile === 'function';
  const rawRead = (relative) => {
    r12b.safeRelative(relative, 'R12C file path');
    const bytes = injected ? readWorkingFile(relative) : fs.readFileSync(r12b.inspectPlainFile(repositoryRoot, relative));
    if (!Buffer.isBuffer(bytes)) throw new Error(`R12C file bytes are missing: ${relative}`);
    return Buffer.from(bytes);
  };
  const rawExists = (relative) => {
    r12b.safeRelative(relative, 'R12C file path');
    return injected ? Boolean(pathExists(relative)) : Boolean(r12b.inspectPlainFile(repositoryRoot, relative, false));
  };
  const statusRows = suppliedRows === undefined
    ? execFileSync('git', ['status', '--porcelain=v1', '--untracked-files=all'], { cwd: repositoryRoot, encoding: 'utf8', windowsHide: true }).trimEnd().split(/\r?\n/u).filter(Boolean)
      .map((line) => ({ status: line.slice(0, 2), path: line.slice(3).replaceAll('\\', '/') }))
    : suppliedRows;
  plainData(statusRows);
  if (!Array.isArray(statusRows) || statusRows.length > 256) throw new Error('R12C status rows are unbounded');
  const statuses = new Map();
  const allowed = new Map([
    ...checked.predecessor.overlayLedger.map((row) => [row.path, row.status]),
    ...checked.governedFiles.map((row) => [row.path, row.status]),
  ]);
  if (checked.stage !== 'design') {
    const candidate = checked.financePublicCandidate;
    allowed.set(candidate.move.source, candidate.move.sourceCandidateStatus);
    allowed.set(candidate.move.target, candidate.move.targetCandidateStatus);
    for (const rewrite of candidate.consumerRewrites) allowed.set(rewrite.path, rewrite.candidateStatus);
    allowed.set(candidate.dependencyLedger.path, candidate.dependencyLedger.candidateStatus);
  }
  if (['messaging-lifecycle-public', 'zero-proven', 'strict'].includes(checked.stage)) {
    for (const record of checked.messagingLifecycleCandidate.records) allowed.set(record.path, record.candidateStatus);
  }
  if (['zero-proven', 'strict'].includes(checked.stage)) {
    allowed.set(checked.marketplacePublicCandidate.move.source, checked.marketplacePublicCandidate.move.sourceCandidateStatus);
    for (const record of checked.marketplacePublicCandidate.records) allowed.set(record.path, record.candidateStatus);
  }
  if (checked.stage === 'strict') {
    allowed.set(DEPENDENCY_PATH, ' D');
    for (const row of checked.strictCandidate.records) allowed.set(row.path, row.candidateStatus);
  }
  for (const row of statusRows) {
    assert.deepStrictEqual(Object.keys(row), ['status', 'path']);
    if (statuses.has(row.path) || allowed.get(row.path) !== row.status) throw new Error(`R12C undeclared, duplicated or changed status: ${row.path}`);
    statuses.set(row.path, row.status);
  }
  if (statuses.size !== allowed.size) throw new Error('R12C status inventory is incomplete');
  const strict = strictPredecessorFiles(rawRead, rawExists, checked);
  const { read, exists } = strict;
  const reconstructed = new Map(strict.reconstructed);
  if (['zero-proven', 'strict'].includes(checked.stage)) {
    const result = verifyMarketplacePublicFiles(read, exists, checked, repositoryRoot);
    for (const [relative, bytes] of result.reconstructed) reconstructed.set(relative, bytes);
  }
  if (['messaging-lifecycle-public', 'zero-proven', 'strict'].includes(checked.stage)) {
    const messagingRead = (relative) => reconstructed.has(relative) ? reconstructed.get(relative) : read(relative);
    const result = verifyMessagingLifecycleFiles(messagingRead, exists, checked);
    for (const [relative, bytes] of result.reconstructed) reconstructed.set(relative, bytes);
  }
  if (checked.stage !== 'design') {
    const financeRead = (relative) => reconstructed.has(relative) ? reconstructed.get(relative) : read(relative);
    const result = verifyFinancePublicFiles(financeRead, exists, checked);
    for (const [relative, bytes] of result.reconstructed) reconstructed.set(relative, bytes);
  }
  for (const contract of checked.governedFiles) {
    const bytes = reconstructed.has(contract.path) ? reconstructed.get(contract.path) : read(contract.path);
    if (!exists(contract.path)) throw new Error('R12C governed file is missing');
    if (contract.hashMode === 'normalized-self') {
      if (!bytes.equals(serialize(checked))) throw new Error('R12C raw manifest or normalized-self representation changed');
    } else if (sha(bytes) !== contract.sha256) throw new Error(`R12C governed fingerprint changed: ${contract.path}`);
  }
  for (const item of checked.planningFiles) if (sha(read(item.path)) !== item.sha256) throw new Error('R12C approved planning bytes changed');
  for (const relative of checked.futurePaths) {
    if (checked.stage !== 'design' && relative === checked.financePublicCandidate.move.target) continue;
    if (['messaging-lifecycle-public', 'zero-proven', 'strict'].includes(checked.stage) && checked.messagingLifecycleCandidate.records.some((row) => row.kind === 'new-file' && row.path === relative)) continue;
    if (['zero-proven', 'strict'].includes(checked.stage) && relative === checked.marketplacePublicCandidate.move.target) continue;
    if (exists(relative)) throw new Error(`R12C future contract exists before its stage: ${relative}`);
  }
  for (const item of checked.sourceFiles) {
    const bytes = reconstructed.has(item.path) ? reconstructed.get(item.path) : read(item.path);
    if (sha(bytes) !== item.sha256) throw new Error(`R12C design source changed: ${item.path}`);
  }
  if (sha(read(R12B_PATH)) !== R12B_SHA) throw new Error('R12C R12B manifest fingerprint changed');
  const predecessor = JSON.parse(read(R12B_PATH).toString('utf8'));
  r12b.validateR12bManifest(predecessor);
  r12b.validateR12bDocumentationTransitions(predecessor);
  if (predecessor.stage !== 'strict' || predecessor.documentationStage !== 'activated'
      || predecessor.documentationTransitions.length !== 4) throw new Error('R12C predecessor is not activated/4');
  const dependencyBytes = read(DEPENDENCY_PATH);
  const expectedDependencySha = checked.stage === 'design' ? DEPENDENCY_SHA
    : checked.stage === 'finance-public' ? checked.financePublicCandidate.dependencyLedger.candidateSha256
      : checked.stage === 'messaging-lifecycle-public' ? checked.messagingLifecycleCandidate.records.find((row) => row.path === DEPENDENCY_PATH).candidateSha256
        : checked.marketplacePublicCandidate.dependencyLedger.candidateSha256;
  if (sha(dependencyBytes) !== expectedDependencySha) throw new Error('R12C active dependency bytes changed');
  expectedR12cDependencyRecords(JSON.parse(dependencyBytes.toString('utf8')), checked);
  verifyR12cOwnership(read(OWNERSHIP_PATH), checked);
  for (const row of checked.predecessor.overlayLedger) {
    if (row.status === ' D') {
      if (exists(row.path)) throw new Error(`R12C deleted predecessor reappeared: ${row.path}`);
      continue;
    }
    const inverse = checked.inverseTransforms.find((item) => item.path === row.path);
    const activeBytes = reconstructed.has(row.path) ? reconstructed.get(row.path) : read(row.path);
    const bytes = inverse ? projectR12cFileToPredecessor(activeBytes, inverse) : activeBytes;
    if (sha(bytes) !== row.sha256) throw new Error(`R12C predecessor reconstruction changed: ${row.path}`);
    reconstructed.set(row.path, bytes);
  }
  // Only these five exact successor files disappear. Every earlier R12B path
  // remains status- and byte-bound and is rechecked by the historical scanner.
  const successorNewPaths = new Set([
    ...NEW_PATHS,
    checked.financePublicCandidate.move.target,
    ...checked.messagingLifecycleCandidate.records.filter((row) => row.kind === 'new-file').map((row) => row.path),
    checked.marketplacePublicCandidate.move.target,
  ]);
  return {
    statusRows: checked.predecessor.overlayLedger.map(({ sha256, ...row }) => row),
    readWorkingFile: (relative) => reconstructed.has(relative) ? Buffer.from(reconstructed.get(relative)) : successorNewPaths.has(relative) ? undefined : read(relative),
    pathExists: (relative) => reconstructed.has(relative) ? true : successorNewPaths.has(relative) ? false : exists(relative),
  };
}

function scanR12cZeroCrossContextDependencies(input) {
  plainOptions(input, ['repositoryRoot', 'manifest']);
  const { repositoryRoot, manifest } = input;
  const projection = projectR12cWorkingTreeToPredecessor(input);
  const predecessor = JSON.parse(projection.readWorkingFile(R12B_PATH).toString('utf8'));
  r12b.projectR12bWorkingTreeToPredecessor({ repositoryRoot, manifest: predecessor, ...projection });
  const predecessorResult = scanR12bPredecessorProjection({ repositoryRoot, manifest: predecessor, projection, successorManifest: manifest });
  if (predecessorResult.receipts !== 4 || predecessorResult.dependencyRecords !== 9
      || predecessorResult.ownershipRecords !== 385 || predecessorResult.ownershipOccurrences !== 781
      || predecessorResult.approvedSecurityPrerequisite !== 1 || predecessorResult.unapprovedProtected !== 0) {
    throw new Error('R12C full R12B predecessor result changed');
  }
  const active = ['zero-proven', 'strict'].includes(manifest.stage) ? verifyR12cMarketplacePublicProjection({ repositoryRoot, manifest })
    : manifest.stage === 'messaging-lifecycle-public' ? verifyR12cMessagingLifecycleProjection({ repositoryRoot, manifest })
      : manifest.stage === 'finance-public' ? verifyR12cFinanceProjection({ repositoryRoot, manifest }) : null;
  return { ok: true, stage: manifest.stage, dependencyRecords: active?.dependencyRecords ?? 9, ...verifyR12cOwnership(projection.readWorkingFile(OWNERSHIP_PATH), manifest) };
}

function runCli() {
  try {
    if (process.argv.slice(2).join(' ') !== '--check') throw new Error('R12C invalid arguments');
    const repositoryRoot = path.resolve(__dirname, '../../..');
    const manifest = JSON.parse(fs.readFileSync(r12b.inspectPlainFile(repositoryRoot, MANIFEST_PATH), 'utf8'));
    const result = scanR12cZeroCrossContextDependencies({ repositoryRoot, manifest });
    process.stdout.write(`PASS - R12C zero cross-context dependencies: stage=${result.stage}, dependency=${result.dependencyRecords}, ownership=${result.ownershipRecords}/${result.ownershipOccurrences}\n`);
    return 0;
  } catch (error) {
    process.stderr.write(process.env.R12C_DEBUG === '1' ? `${error.stack || error}\n` : 'ERROR - R12C zero cross-context dependencies validation failed\n');
    return 2;
  }
}

module.exports = {
  authorityFingerprint, validateR12cManifest, expectedR12cDependencyRecords,
  verifyR12cOwnership, verifyR12cFinanceProjection, verifyR12cMessagingLifecycleProjection,
  verifyMarketplacePublicFiles, verifyR12cMarketplacePublicProjection,
  strictPredecessorFiles, readR12cStrictDependencyBytes,
  scanR12bPredecessorProjection, projectR12cFileToPredecessor,
  projectR12cWorkingTreeToPredecessor, scanR12cZeroCrossContextDependencies, runCli,
};
if (require.main === module) process.exitCode = runCli();
