import 'reflect-metadata';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  rmSync,
  statSync,
  symlinkSync,
  writeFileSync,
  readFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { test } from 'node:test';

const root = path.resolve(__dirname, '../..');
const manifestPath = 'backend/architecture/r12c-zero-cross-context-dependencies.json';
const scannerPath = 'backend/scripts/architecture/r12c-zero-cross-context-dependencies-scan.cjs';
const r12bPath = 'backend/architecture/r12b-planning-public-contracts.json';
const dependencyPath = 'backend/.dependency-cruiser-known-violations.json';
const ownershipPath = 'backend/architecture/ownership-baseline.json';
const ids = [10, 12, 13, 14, 15, 16, 17, 19, 20];
const stageNames = ['design', 'finance-public', 'messaging-lifecycle-public', 'zero-proven', 'strict'];
const prefixes = [[], [10, 13], [10, 12, 13, 14, 15, 16, 17], ids, ids];
const counts = [9, 7, 2, 0, 0];
test('R12C Task 5 strict gate has no dependency ledger or ignored canonical command', () => {
  assert.equal(existsSync(path.join(root, dependencyPath)), false, 'strict must delete the independently reviewed empty ledger');
  const packageJson = JSON.parse(readFileSync(path.join(root, 'backend/package.json'), 'utf8'));
  assert.equal(packageJson.scripts['architecture:imports'], 'depcruise --config .dependency-cruiser.cjs src');
  assert.equal('architecture:imports:baseline' in packageJson.scripts, false, 'strict zero retires the baseline generator: nothing may recreate a ledger');
  assert.equal(packageJson.scripts.architecture.split(' && ').filter((entry: string) => entry === 'npm run architecture:r12c').length, 1);
  assert.equal(packageJson.scripts.architecture.split(' && ').at(-1), 'npm run architecture:r12c');
});
const read = (relative: string) => readFileSync(path.join(root, relative));
const hash = (bytes: Buffer | string) => createHash('sha256').update(bytes).digest('hex');
const load = () => {
  assert.equal(existsSync(path.join(root, manifestPath)), true, 'missing R12C manifest successor authority');
  assert.equal(existsSync(path.join(root, scannerPath)), true, 'missing R12C scanner successor authority');
  return { api: require(path.join(root, scannerPath)), manifest: JSON.parse(read(manifestPath).toString('utf8')) };
};
const changed = (value: any, mutation: (copy: any) => void) => {
  const copy = structuredClone(value);
  mutation(copy);
  return copy;
};
const fixture = () => {
  const { api, manifest } = load();
  // The overlay is measured against the immutable base commit, never against
  // HEAD or the staging state, so committed and uncommitted work project alike.
  const identity = require(path.join(root, 'backend/scripts/architecture/repository-identity.cjs'));
  const statusRows = identity.workingTreeInventory(root, api.BASE_COMMIT) as Array<{ status: string; path: string }>;
  const files = new Map<string, Buffer>();
  for (const row of statusRows) if (row.status !== ' D') files.set(row.path, read(row.path));
  for (const relative of [manifestPath, r12bPath, dependencyPath, ownershipPath, manifest.financePublicCandidate.move.target, ...manifest.sourceFiles.map((item: any) => item.path)]) {
    if (existsSync(path.join(root, relative))) files.set(relative, read(relative));
  }
  return { api, manifest, files, statusRows, input: {
    repositoryRoot: root, manifest, statusRows,
    readWorkingFile: (relative: string) => files.get(relative),
    pathExists: (relative: string) => files.has(relative),
  } };
};

test('R12C authority preserves all nine entry records and the exact strict subtraction', () => {
  const { api, manifest } = load();
  assert.doesNotThrow(() => api.validateR12cManifest(manifest));
  assert.equal(manifest.stage, 'strict');
  assert.deepEqual(manifest.dependencyRecords.map((row: any) => row.id), ids);
  const activeRows = manifest.dependencyRecords.filter((row: any) => !manifest.stages[manifest.stage].retiredDependencyIds.includes(row.id));
  assert.deepEqual(activeRows.map(({ id, ...row }: any) => row), JSON.parse(api.readR12cStrictDependencyBytes(root).toString('utf8')));
  assert.equal(new Set(manifest.dependencyRecords.map((row: any) => `${row.rule.name}|${row.from}|${row.to}`)).size, 9);
  assert.deepEqual(Object.keys(manifest.stages), stageNames);
  stageNames.forEach((stage, index) => assert.deepEqual(manifest.stages[stage], { retiredDependencyIds: prefixes[index], dependencyRecords: counts[index] }));
  const strictDependency = JSON.parse(api.readR12cStrictDependencyBytes(root).toString('utf8'));
  assert.deepEqual(api.expectedR12cDependencyRecords(strictDependency, manifest), strictDependency);
});

test('R12C rejects missing, added, reordered, duplicated and mutated dependency rows and IDs', () => {
  const { api, manifest } = load();
  const records = manifest.dependencyRecords.map(({ id: ignored, ...row }: any) => structuredClone(row));
  const designManifest = changed(manifest, (copy) => { copy.stage = 'design'; });
  const mutations = [
    (rows: any[]) => rows.pop(), (rows: any[]) => rows.push(structuredClone(rows[0])),
    (rows: any[]) => rows.reverse(), (rows: any[]) => { rows[1] = structuredClone(rows[0]); },
    (rows: any[]) => { rows[0].unresolvedTo += '-near-miss'; },
    (rows: any[]) => { rows[0].dependencyTypes.reverse(); },
    (rows: any[]) => { rows[0].rule.severity = 'warn'; },
    (rows: any[]) => { rows[0].extra = true; },
  ];
  for (const mutation of mutations) {
    assert.throws(() => api.validateR12cManifest(changed(manifest, (copy) => mutation(copy.dependencyRecords))));
    assert.throws(() => api.expectedR12cDependencyRecords(changed(records, mutation), designManifest));
  }
  for (const id of ids) assert.throws(() => api.validateR12cManifest(changed(manifest, (copy) => { copy.dependencyRecords.find((row: any) => row.id === id).id = 1; })));
});

test('R12C stage prefixes are immutable and strict rejects every predecessor stage', () => {
  const { api, manifest } = load();
  assert.equal(manifest.stage, 'strict');
  for (const stage of stageNames.slice(0, -1)) assert.throws(() => api.validateR12cManifest(changed(manifest, (copy) => { copy.stage = stage; })));
  for (const stage of stageNames) {
    assert.throws(() => api.validateR12cManifest(changed(manifest, (copy) => { copy.stages[stage].dependencyRecords += 1; })));
    assert.throws(() => api.validateR12cManifest(changed(manifest, (copy) => { copy.stages[stage].retiredDependencyIds.push(22); })));
  }
});

test('R12C binds exactly three approved contract families, consumer inventories and real behavior gates', () => {
  const { api, manifest } = load();
  assert.deepEqual(manifest.contractFamilies.map((item: any) => item.owner), ['finance', 'messaging', 'marketplace']);
  assert.deepEqual(manifest.contractFamilies.map((item: any) => item.dependencyIds), [[10, 13], [12, 14, 15, 16, 17], [19, 20]]);
  assert.deepEqual(manifest.contractFamilies.map((item: any) => item.consumers.length), [3, 5, 7]);
  for (const family of manifest.contractFamilies) {
    const livePath = family.owner === 'finance' || family.owner === 'marketplace'
      ? family.target
      : family.source;
    const sourceBytes = family.owner === 'messaging'
      ? api.projectR12cWorkingTreeToPredecessor({ repositoryRoot: root, manifest }).readWorkingFile(livePath)
      : read(livePath);
    assert.equal(hash(sourceBytes), family.sourceSha256);
    for (const consumer of family.consumers) assert.equal(existsSync(path.join(root, consumer)), true, consumer);
    for (const behavior of family.behaviorTests) assert.equal(existsSync(path.join(root, behavior)), true, behavior);
    if (family.owner !== 'messaging') assert.equal(family.targetSha256, family.sourceSha256);
  }
  assert.equal(manifest.contractFamilies[1].targetSha256, null, 'future implementation hashes cannot be invented before Task 3');
  assert.deepEqual(manifest.contractFamilies[2].exceptionRetirement.authorities, [
    'backend/.dependency-cruiser.cjs', 'backend/scripts/architecture/ports-scan.cjs', 'backend/scripts/architecture/r3-context-scan.cjs',
  ]);
  assert.throws(() => api.validateR12cManifest(changed(manifest, (copy) => copy.contractFamilies[0].consumers.pop())));
});

test('R12C rejects forged predecessor hash, receipts, documentation and entry provenance', () => {
  const { api, manifest } = load();
  // `repository.root` and `repository.branch` record where the composite entry
  // was captured; they are immutable provenance inside the design authority,
  // not an execution constraint (see architecture-governance-portability).
  const mutations = [
    (copy: any) => { copy.predecessor.manifestSha256 = '0'.repeat(64); },
    (copy: any) => { copy.predecessor.receipts = 3; },
    (copy: any) => { copy.predecessor.documentationStage = 'candidate'; },
    (copy: any) => { copy.repository.root = 'D:/projects/aarast'; },
    (copy: any) => { copy.repository.branch = 'main'; },
    (copy: any) => { copy.repository.baseCommit = '0'.repeat(40); },
    (copy: any) => { copy.predecessor.overlayLedger.reverse(); },
  ];
  for (const mutation of mutations) assert.throws(() => api.validateR12cManifest(changed(manifest, mutation)));
  assert.throws(
    () => api.scanR12cZeroCrossContextDependencies({ repositoryRoot: path.dirname(root), manifest }),
    /repository identity/u,
    'a parent directory is never accepted as the repository',
  );
  assert.throws(
    () => api.scanR12cZeroCrossContextDependencies({ repositoryRoot: path.join(root, 'backend'), manifest }),
    /repository identity/u,
    'a nested directory is never resolved up to its repository',
  );
});

test('R12C stage and strict records use the compact reversible encodings and reconstruct their exact entries', () => {
  const { api, manifest } = load();
  // A single whole-span splice carried every unchanged byte between the first
  // and last edit twice; the approved Task 3/4 records were re-encoded
  // losslessly and no record may return to that form.
  const stages = [manifest.marketplacePublicCandidate, manifest.messagingLifecycleCandidate, manifest.strictCandidate];
  for (const stage of stages) {
    for (const record of stage.records) {
      assert.ok(['new-file', 'bounded-byte-splices', 'line-ending-normalization'].includes(record.kind), `${record.path}: ${record.kind}`);
      if (record.kind !== 'new-file') assert.ok(record.entrySha256 && record.entryByteLength > 0, record.path);
    }
  }
  const read = (relative: string) => readFileSync(path.join(root, relative));
  const exists = (relative: string) => existsSync(path.join(root, relative));
  const strict = api.strictPredecessorFiles(read, exists, manifest);
  const marketplace = api.verifyMarketplacePublicFiles(strict.read, strict.exists, manifest, root);
  for (const record of manifest.marketplacePublicCandidate.records) {
    const entry = api.reconstructCandidateRecord(strict.read(record.path), record);
    if (record.kind === 'new-file') assert.equal(entry, null);
    else assert.equal(hash(entry), record.entrySha256, record.path);
  }
  for (const record of manifest.messagingLifecycleCandidate.records) {
    const candidate = marketplace.reconstructed.get(record.path) || strict.read(record.path);
    const entry = api.reconstructCandidateRecord(candidate, record);
    if (record.kind === 'new-file') assert.equal(entry, null);
    else assert.equal(hash(entry), record.entrySha256, record.path);
  }
  assert.ok(statSync(path.join(root, manifestPath)).size < 1024 * 1024, 'the manifest must stay well inside its JSON authority bound');
});

test('R12C strict candidate registers only its declared scope and reconstructs line-ending normalization exactly', () => {
  const { api, manifest } = load();
  assert.deepEqual([...manifest.strictCandidate.records.map((row: any) => row.path)].sort(), [...new Set(manifest.strictCandidate.records.map((row: any) => row.path))].sort());
  for (const row of manifest.strictCandidate.records) assert.ok(api.STRICT_CANDIDATE_PATHS.includes(row.path), row.path);
  assert.throws(() => api.validateR12cManifest(changed(manifest, (copy) => { copy.strictCandidate.records.push({ ...copy.strictCandidate.records[0], path: 'backend/src/attacker.ts' }); })));
  const entry = Buffer.from('a\r\nb\nc\r\n', 'utf8');
  const candidate = Buffer.from('a\nb\nc\n', 'utf8');
  const record = {
    path: 'backend/scripts/architecture/ports-scan.cjs', kind: 'line-ending-normalization',
    entrySha256: hash(entry), candidateSha256: hash(candidate), entryByteLength: entry.length,
    entryStatus: ' M', candidateStatus: ' M', lfLines: [1], splices: [],
  };
  assert.deepEqual(api.reconstructCandidateRecord(candidate, record), entry);
  assert.throws(() => api.reconstructCandidateRecord(candidate, { ...record, lfLines: [0] }), /entry bytes changed/u);
  assert.throws(() => api.reconstructCandidateRecord(candidate, { ...record, lfLines: [5] }), /exceeds/u);
  assert.throws(() => api.reconstructCandidateRecord(Buffer.from('a\r\nb\nc\n'), { ...record, candidateSha256: hash('a\r\nb\nc\n') }), /invalid/u);
  const spliced = Buffer.from('a\nB\nc\n', 'utf8');
  const withSplice = { ...record, candidateSha256: hash(spliced), splices: [{ offset: 2, beforeBase64: [Buffer.from('b').toString('base64')], afterBase64: [Buffer.from('B').toString('base64')] }] };
  assert.deepEqual(api.reconstructCandidateRecord(spliced, withSplice), entry);
});

test('R12C rejects non-plain manifest and scanner input without invoking getters or proxies', () => {
  const { api, manifest } = load();
  let invoked = 0;
  const getter = Object.defineProperty({}, 'manifest', { enumerable: true, get() { invoked++; return manifest; } });
  const proxy = new Proxy({}, { get() { invoked++; return manifest; }, ownKeys() { invoked++; return []; } });
  for (const value of [null, [], new Date(), Object.create(null), proxy, getter]) {
    assert.throws(() => api.validateR12cManifest(value));
    assert.throws(() => api.scanR12cZeroCrossContextDependencies(value));
    assert.throws(() => api.projectR12cWorkingTreeToPredecessor(value));
  }
  const sparse = structuredClone(manifest); delete sparse.dependencyRecords[0];
  assert.throws(() => api.validateR12cManifest(sparse));
  assert.equal(invoked, 0);
});

test('R12C ownership raw bytes and 385/781 counts are exact and immutable', () => {
  const { api, manifest } = load();
  const bytes = read(ownershipPath);
  assert.equal(hash(bytes), '5f42f33300a9727f587e62327c5261a88a6ce5928437241c9e7c20f726906496');
  assert.deepEqual(api.verifyR12cOwnership(bytes, manifest), { ownershipRecords: 385, ownershipOccurrences: 781 });
  assert.throws(() => api.verifyR12cOwnership(Buffer.concat([bytes, Buffer.from(' ')]), manifest));
  assert.throws(() => api.validateR12cManifest(changed(manifest, (copy) => { copy.ownership.records--; })));
});

test('R12C successor reconstructs activated R12B bytes and preserves its full historical projection', () => {
  const item = fixture();
  const projected = item.api.projectR12cWorkingTreeToPredecessor(item.input);
  assert.deepEqual(projected.statusRows, item.manifest.predecessor.overlayLedger.map(({ sha256, ...row }: any) => row));
  for (const inverse of item.manifest.inverseTransforms) assert.equal(hash(projected.readWorkingFile(inverse.path)), inverse.entrySha256);
  assert.equal(hash(projected.readWorkingFile(r12bPath)), '1bf0c2d00886f1ec442187f2719c4d604b0ebcc57a3ada56d97006015c029845');
  // The R12C security prerequisite (multer 2.3.0, sharp 0.35.4) is a strict
  // record; R12B keeps validating its own approved lock through the projection.
  assert.equal(hash(projected.readWorkingFile('backend/package-lock.json')), '650bc45c00cd3cdf8298e33570481bb969fdbae78a63167cca9f8ff243b25f60');
  assert.notEqual(hash(read('backend/package-lock.json')), '650bc45c00cd3cdf8298e33570481bb969fdbae78a63167cca9f8ff243b25f60');
  assert.equal(JSON.parse(read('backend/package-lock.json').toString('utf8')).packages['node_modules/multer'].version, '2.3.0');
  const r12b = require(path.join(root, 'backend/scripts/architecture/r12b-planning-public-contracts-scan.cjs'));
  const predecessor = JSON.parse(read(r12bPath).toString('utf8'));
  assert.deepEqual(r12b.projectR12bWorkingTreeToPredecessor({ repositoryRoot: root, manifest: predecessor, ...projected }), predecessor.predecessor.overlayLedger);
  assert.equal(projected.pathExists(manifestPath), false);
  assert.throws(() => r12b.projectR12bWorkingTreeToPredecessor({
    repositoryRoot: root, manifest: predecessor, ...projected,
    statusRows: [...projected.statusRows, { status: '??', path: item.manifest.planningPaths[0] }],
  }), /undeclared/u, 'no-successor fixtures must still reject R12C planning files');
  assert.doesNotThrow(() => r12b.validateR12bManifest(predecessor));
  assert.doesNotThrow(() => r12b.validateR12bDocumentationTransitions(predecessor));
  assert.equal(predecessor.documentationStage, 'activated');
  assert.equal(predecessor.documentationTransitions.length, 4);
  assert.equal(JSON.parse(projected.readWorkingFile(dependencyPath).toString('utf8')).length, 9);
});

test('R12C projected full R12B scan retains source-layout ownership security and receipts', () => {
  const item = fixture();
  const projected = item.api.projectR12cWorkingTreeToPredecessor({
    repositoryRoot: root,
    manifest: item.manifest,
  });
  const predecessor = JSON.parse(projected.readWorkingFile(r12bPath).toString('utf8'));
  const scan = (projection = projected) => item.api.scanR12bPredecessorProjection({
    repositoryRoot: root,
    manifest: predecessor,
    projection,
    successorManifest: item.manifest,
  });
  assert.deepEqual(scan(), {
    ok: true,
    stage: 'strict',
    documentationStage: 'activated',
    receipts: 4,
    dependencyRecords: 9,
    ownershipRecords: 385,
    ownershipOccurrences: 781,
    approvedSecurityPrerequisite: 1,
    unapprovedProtected: 0,
  });

  const withBytes = (relative: string, bytes: Buffer) => ({
    ...projected,
    readWorkingFile: (candidate: string) => candidate === relative
      ? bytes
      : projected.readWorkingFile(candidate),
  });
  const locationTarget = predecessor.locationMove.to;
  assert.throws(
    () => scan(withBytes(locationTarget, Buffer.concat([projected.readWorkingFile(locationTarget), Buffer.from(' ')]))),
    /R12B location source parity drift detected/u,
  );
  assert.throws(
    () => scan(withBytes(ownershipPath, Buffer.concat([projected.readWorkingFile(ownershipPath), Buffer.from(' ')]))),
    /R12B ownership bytes changed/u,
  );
  const securityPath = predecessor.approvedSecurityPrerequisite.path;
  assert.throws(
    () => scan(withBytes(securityPath, Buffer.concat([projected.readWorkingFile(securityPath), Buffer.from(' ')]))),
    /R12B approved security prerequisite raw lock hash changed/u,
  );
});

test('R12C rejects governed-byte drift, status drift, forged inverse and any undeclared planning path', () => {
  const item = fixture();
  for (const contract of item.manifest.governedFiles) {
    const original = item.files.get(contract.path)!;
    item.files.set(contract.path, Buffer.concat([original, Buffer.from(' ')]));
    assert.throws(() => item.api.projectR12cWorkingTreeToPredecessor(item.input), contract.path);
    item.files.set(contract.path, original);
  }
  for (const relative of ['docs/superpowers/plans/other.md', 'backend/src/attacker.ts', 'mobile/attacker.txt']) {
    item.statusRows.push({ status: '??', path: relative }); item.files.set(relative, Buffer.from('drift'));
    assert.throws(() => item.api.projectR12cWorkingTreeToPredecessor(item.input));
    item.statusRows.pop(); item.files.delete(relative);
  }
  const originalStatus = item.statusRows[0].status;
  item.statusRows[0].status = 'M '; assert.throws(() => item.api.projectR12cWorkingTreeToPredecessor(item.input)); item.statusRows[0].status = originalStatus;
  item.statusRows.push({ ...item.statusRows[0] }); assert.throws(() => item.api.projectR12cWorkingTreeToPredecessor(item.input)); item.statusRows.pop();
  const inverse = item.manifest.inverseTransforms[0];
  assert.throws(() => item.api.projectR12cFileToPredecessor(item.files.get(inverse.path), changed(inverse, (copy) => { copy.entrySha256 = '0'.repeat(64); })));
  const rawPredecessor = item.files.get(r12bPath)!;
  const forged = JSON.parse(rawPredecessor.toString('utf8'));
  forged.documentationTransitions[3].receiptSha256 = '0'.repeat(64);
  item.files.set(r12bPath, Buffer.from(JSON.stringify(forged)));
  assert.throws(() => item.api.projectR12cWorkingTreeToPredecessor(item.input));
  item.files.set(r12bPath, rawPredecessor);
});

test('R12C active stage rejects premature later contract files and changed target-source hashes', () => {
  const item = fixture();
  for (const relative of item.manifest.futurePaths.filter((relative: string) => relative !== item.manifest.financePublicCandidate.move.target && !item.manifest.messagingLifecycleCandidate.records.some((record: any) => record.kind === 'new-file' && record.path === relative))) {
    item.files.set(relative, Buffer.from('premature'));
    assert.throws(() => item.api.projectR12cWorkingTreeToPredecessor(item.input), relative);
    item.files.delete(relative);
  }
  for (const contract of item.manifest.sourceFiles.filter((contract: any) => item.files.has(contract.path))) {
    const original = item.files.get(contract.path)!;
    item.files.set(contract.path, Buffer.concat([original, Buffer.from('drift')]));
    assert.throws(() => item.api.projectR12cWorkingTreeToPredecessor(item.input), contract.path);
    item.files.set(contract.path, original);
  }
  assert.deepEqual(item.manifest.planningPaths, [
    'docs/superpowers/specs/2026-09-08-modular-monolith-r12c-zero-cross-context-dependencies-design.md',
    'docs/superpowers/plans/2026-09-08-modular-monolith-r12c-zero-cross-context-dependencies.md',
  ]);
});

test('R12C Finance projection publishes one byte-identical public presenter and retires only IDs 10 and 13', () => {
  const { api, manifest } = load();
  const result = api.verifyR12cFinanceProjection({ repositoryRoot: root, manifest });
  assert.deepEqual(result, {
    ok: true,
    stage: 'finance-public',
    legacyPaths: 0,
    publicPaths: 1,
    consumers: 3,
    exports: [
      'weddingCostResponseInclude',
      'WeddingCostWithDetails',
      'WeddingCostResponse',
      'toWeddingCostResponse',
    ],
    dependencyRecords: 7,
    ownershipRecords: 385,
    ownershipOccurrences: 781,
  });
});

test('R12C CLI accepts only --check and reports strict/dependency0/ownership385/781', () => {
  load();
  const output = execFileSync(process.execPath, [path.join(root, scannerPath), '--check'], { cwd: root, encoding: 'utf8' });
  assert.match(output, /stage=strict, dependency=0, ownership=385\/781/u);
  assert.throws(() => execFileSync(process.execPath, [path.join(root, scannerPath), '--unknown'], { cwd: root, stdio: 'pipe' }));
});

const lifecyclePortPath = 'backend/src/modules/messaging/public/conversation-lifecycle.port.ts';
const lifecyclePublicPath = 'backend/src/modules/messaging/public/conversation-lifecycle-public.module.ts';
const lifecycleInternalPath = 'backend/src/modules/messaging/internal/conversation-lifecycle.internal.module.ts';
function requireLifecycle() {
  for (const relative of [lifecyclePortPath, lifecyclePublicPath, lifecycleInternalPath]) {
    assert.equal(existsSync(path.join(root, relative)), true, 'missing Messaging lifecycle port/wiring: ' + relative);
  }
  return {
    port: require(path.join(root, lifecyclePortPath)),
    publicModule: require(path.join(root, lifecyclePublicPath)),
    internalModule: require(path.join(root, lifecycleInternalPath)),
  };
}

test('R12C Task 3 lifecycle port exposes one runtime token and one singleton public alias', async () => {
  const { port, publicModule, internalModule } = requireLifecycle();
  assert.deepEqual(Object.keys(port), ['CONVERSATION_LIFECYCLE_PORT']);
  const { NestFactory } = require('@nestjs/core');
  const application = await NestFactory.createApplicationContext(publicModule.ConversationLifecyclePublicModule, { logger: false });
  try {
    const publicIdentity = application.get(port.CONVERSATION_LIFECYCLE_PORT);
    const internalIdentity = application.get(internalModule.CONVERSATION_LIFECYCLE_IMPLEMENTATION);
    assert.equal(publicIdentity, internalIdentity);
    assert.deepEqual(Object.keys(publicIdentity), ['ensureConversationContext', 'recordConversationEvent']);
    assert.deepEqual(Reflect.getMetadata('exports', publicModule.ConversationLifecyclePublicModule), [port.CONVERSATION_LIFECYCLE_PORT]);
    const providers = Reflect.getMetadata('providers', publicModule.ConversationLifecyclePublicModule);
    assert.deepEqual(providers, [{ provide: port.CONVERSATION_LIFECYCLE_PORT, useExisting: internalModule.CONVERSATION_LIFECYCLE_IMPLEMENTATION }]);
    assert.equal(Reflect.getMetadata('providers', internalModule.ConversationLifecycleInternalModule).length, 1);
  } finally {
    await application.close();
  }
});

test('R12C Task 3 lifecycle delegate preserves exact tx, input, promise, return and error identity', async () => {
  const { internalModule } = requireLifecycle();
  const implementation = Reflect.getMetadata('providers', internalModule.ConversationLifecycleInternalModule)[0].useValue;
  const legacy = require(path.join(root, 'backend/src/conversations/conversation-lifecycle.ts'));
  for (const method of ['ensureConversationContext', 'recordConversationEvent']) {
    const original = legacy[method];
    const tx = Object.freeze({ transactionIdentity: Symbol(method) });
    const input = Object.freeze({ inputIdentity: Symbol(method) });
    const value = Object.freeze({ resultIdentity: Symbol(method) });
    const expected = Promise.resolve(value);
    const error = new Error('same error ' + method);
    const calls: unknown[][] = [];
    try {
      legacy[method] = (...args: unknown[]) => { calls.push(args); return expected; };
      const result = implementation[method](tx, input);
      assert.equal(result, expected);
      assert.equal(await result, value);
      assert.equal(calls.length, 1);
      assert.equal(calls[0][0], tx);
      assert.equal(calls[0][1], input);
      assert.equal(calls[0].length, 2);
      legacy[method] = () => { throw error; };
      assert.throws(() => implementation[method](tx, input), caught => caught === error);
      const rejection = Promise.reject(error);
      legacy[method] = () => rejection;
      const rejected = implementation[method](tx, input);
      assert.equal(rejected, rejection);
      await assert.rejects(rejected, caught => caught === error);
    } finally {
      legacy[method] = original;
    }
  }
});

test('R12C Task 3 lifecycle consumers require one port and keep exact tx with no dual path', () => {
  requireLifecycle();
  const ts = require('typescript');
  const helperNames = ['acceptQuoteOfferInTransaction', 'rejectQuoteOfferInTransaction', 'cancelQuoteRequestInTransaction', 'createQuoteRequestInTransaction'];
  const files = [
    'backend/src/marketplace/quote-offer-acceptance.ts',
    'backend/src/marketplace/quote-offer-rejection.ts',
    'backend/src/marketplace/quote-request-cancellation.ts',
    'backend/src/marketplace/quote-request-creation.ts',
    'backend/src/provider-dashboard/provider-dashboard.service.ts',
  ];
  let lifecycleCalls = 0;
  for (const relative of files) {
    const source = read(relative).toString('utf8');
    const ast = ts.createSourceFile(relative, source, ts.ScriptTarget.Latest, true);
    assert.doesNotMatch(source, /from\s+['"][^'"]*conversations\/conversation-lifecycle['"]|require\s*\(|import\s*\(|\?\.\s*(?:ensureConversationContext|recordConversationEvent)/u);
    const visit = (node: any) => {
      if (ts.isCallExpression(node) && /(?:ensureConversationContext|recordConversationEvent)$/.test(node.expression.getText(ast))) {
        assert.ok(['lifecycle.ensureConversationContext', 'lifecycle.recordConversationEvent', 'this.lifecycle.recordConversationEvent'].includes(node.expression.getText(ast)));
        assert.equal(node.arguments[0].getText(ast), 'tx');
        assert.equal(node.arguments.length, 2);
        lifecycleCalls++;
      }
      if (ts.isFunctionDeclaration(node) && helperNames.includes(node.name?.text)) {
        assert.equal(node.parameters[1].name.text, 'lifecycle');
        assert.equal(node.parameters[1].type.getText(ast), 'ConversationLifecyclePort');
        assert.equal(node.parameters[1].questionToken, undefined);
        assert.equal(node.parameters[1].initializer, undefined);
      }
      ts.forEachChild(node, visit);
    };
    visit(ast);
  }
  assert.equal(lifecycleCalls, 9);
  const market = require(path.join(root, 'backend/src/marketplace/marketplace.service.ts')).MarketplaceService;
  const dashboard = require(path.join(root, 'backend/src/provider-dashboard/provider-dashboard.service.ts')).ProviderDashboardService;
  const token = requireLifecycle().port.CONVERSATION_LIFECYCLE_PORT;
  for (const service of [market, dashboard]) {
    assert.equal(Reflect.getMetadata('self:paramtypes', service).filter((item: any) => item.param === token).length, 1);
    assert.equal(Reflect.getMetadata('self:paramtypes', service).find((item: any) => item.param === token).index, 3);
  }
});

test('R12C Task 3 lifecycle projection retires exactly five rows and rejects any unregistered source drift', () => {
  requireLifecycle();
  const item = fixture();
  assert.equal(item.manifest.stage, 'strict');
  assert.deepEqual(item.manifest.messagingLifecycleCandidate.retiredIds, [12, 14, 15, 16, 17]);
  const result = item.api.verifyR12cMessagingLifecycleProjection({ repositoryRoot: root, manifest: item.manifest });
  assert.equal(result.dependencyRecords, 2);
  assert.equal(result.ownershipRecords, 385);
  assert.equal(result.ownershipOccurrences, 781);
  for (const record of item.manifest.messagingLifecycleCandidate.records) {
    const original = item.files.get(record.path)
      || (record.path === dependencyPath ? item.api.readR12cStrictDependencyBytes(root) : undefined);
    assert.ok(original, `missing exact Task 3 candidate bytes: ${record.path}`);
    item.files.set(record.path, Buffer.concat([original, Buffer.from(' ')]));
    assert.throws(() => item.api.projectR12cWorkingTreeToPredecessor(item.input), record.path);
    item.files.set(record.path, original);
  }
});

const marketplacePolicyLegacyPath = 'backend/src/provider-dashboard/provider-access-policy.ts';
const marketplacePolicyPublicPath = 'backend/src/modules/marketplace/public/provider-access-policy.ts';
const task4CandidatePath = '.superpowers/sdd/2026-09-08-modular-monolith-r12c-zero-cross-context-dependencies/task-4-marketplace-public-candidate.json';
const task4Consumers = [
  'backend/src/provider-dashboard/provider-dashboard.service.ts',
  'backend/src/provider-dashboard/provider-mutation-locks.ts',
  'backend/src/marketplace/quote-offer-acceptance.ts',
  'backend/src/marketplace/quote-notifications.ts',
  'backend/src/conversations/conversations.service.ts',
  'backend/src/notifications/notifications.service.ts',
  'backend/src/modules/identity/internal/profile/contexts.service.ts',
];

function writeFixtureFile(fixtureRoot: string, relative: string, bytes: Buffer | string): void {
  const absolute = path.join(fixtureRoot, ...relative.split('/'));
  mkdirSync(path.dirname(absolute), { recursive: true });
  writeFileSync(absolute, bytes);
}

function task4FilesystemFixture(api: any, manifest: any) {
  const fixtureRoot = mkdtempSync(path.join(tmpdir(), 'aarast-r12c-task4-'));
  const predecessor = api.strictPredecessorFiles(
    read,
    (relative: string) => existsSync(path.join(root, relative)),
    manifest,
  );
  for (const relative of [marketplacePolicyPublicPath, ...task4Consumers]) {
    writeFixtureFile(fixtureRoot, relative, read(relative));
  }
  const bytes = new Map<string, Buffer>();
  for (const record of manifest.marketplacePublicCandidate.records) {
    bytes.set(record.path, predecessor.read(record.path));
  }
  return {
    fixtureRoot,
    readCandidate: (relative: string) => {
      const value = bytes.get(relative);
      if (!value) throw new Error(`missing Task 4 candidate fixture bytes: ${relative}`);
      return value;
    },
    existsCandidate: (relative: string) => relative !== marketplacePolicyLegacyPath && bytes.has(relative),
  };
}

test('R12C Task 4 publishes one byte-identical Marketplace provider policy and retires IDs 19/20', () => {
  const { api, manifest } = load();
  assert.equal(manifest.stage, 'strict');
  assert.equal(existsSync(path.join(root, marketplacePolicyLegacyPath)), false);
  assert.equal(existsSync(path.join(root, marketplacePolicyPublicPath)), true);
  const task4Candidate = JSON.parse(read(task4CandidatePath).toString('utf8'));
  assert.equal(hash(read(marketplacePolicyPublicPath)), task4Candidate.move.entrySha256);
  assert.equal(typeof api.verifyR12cMarketplacePublicProjection, 'function');
  assert.deepEqual(api.verifyR12cMarketplacePublicProjection({ repositoryRoot: root, manifest }), {
    ok: true,
    stage: 'strict',
    legacyPaths: 0,
    publicPaths: 1,
    consumers: 7,
    exports: [
      'PROVIDER_NOT_ACTIVE',
      'PROVIDER_PROFILE_READ_ONLY',
      'PROVIDER_PORTAL_ROUTE',
      'ProviderAccessCapabilities',
      'ProviderAccessMode',
      'ProviderAccessPolicy',
      'isProviderOperational',
      'providerAccessPolicy',
      'assertProviderOperational',
      'assertProviderProfileWritable',
    ],
    exceptionAuthorities: 0,
    dependencyRecords: 0,
    ownershipRecords: 385,
    ownershipOccurrences: 781,
  });
});

test('R12C Task 4 rewrites exactly seven consumers and removes only the exact live exception authorities', () => {
  const { api } = load();
  for (const relative of task4Consumers) {
    const source = read(relative).toString('utf8');
    assert.match(source, /marketplace\/public\/provider-access-policy/u, relative);
    assert.doesNotMatch(source, /provider-dashboard\/provider-access-policy/u, relative);
  }
  assert.doesNotMatch(read('backend/src/marketplace/quote-notifications.ts').toString('utf8'), /export\s*\{\s*PROVIDER_PORTAL_ROUTE\s*\}/u);
  const retiredNeedles = new Map<string, string[]>([
    ['backend/.dependency-cruiser.cjs', [
      'context-identity-relocated-contexts-helper-cross-context',
      'relocatedIdentityContextsService',
      'providerAccessPolicy',
    ]],
    ['backend/scripts/architecture/ports-scan.cjs', [
      'R5_RELOCATED_IDENTITY_PURE_HELPER_EDGES',
      'backend/src/modules/identity/internal/profile/contexts.service.ts|backend/src/provider-dashboard/provider-access-policy.ts',
    ]],
    ['backend/scripts/architecture/r3-context-scan.cjs', [
      'relocatedIdentityPureHelpers',
      'legalRelocatedIdentityPureHelper',
      'backend/src/modules/identity/internal/profile/contexts.service.ts->backend/src/provider-dashboard/provider-access-policy.ts',
    ]],
  ]);
  for (const [relative, needles] of retiredNeedles) {
    const source = read(relative).toString('utf8');
    for (const needle of needles) assert.equal(source.includes(needle), false, `${relative}: ${needle}`);
  }
  assert.deepEqual(JSON.parse(api.readR12cStrictDependencyBytes(root).toString('utf8')), []);
  assert.deepEqual(api.readR12cStrictDependencyBytes(root), Buffer.from('[]\n', 'utf8'));
});

test('R12C Task 4 scanner rejects policy copies, re-exports, alternate paths, unlisted consumers, and byte drift', () => {
  const { api, manifest } = load();
  assert.equal(typeof api.verifyMarketplacePublicFiles, 'function');
  const strictHistoricalPath = 'backend/scripts/architecture/r12a-backoffice-catalog-public-contracts-scan.cjs';
  const strictHistoricalRow = manifest.marketplacePublicCandidate.records.find(
    (record: any) => record.path === strictHistoricalPath,
  );
  const stageBoundary = task4FilesystemFixture(api, manifest);
  try {
    assert.equal(hash(stageBoundary.readCandidate(strictHistoricalPath)), strictHistoricalRow.candidateSha256);
    assert.throws(
      () => api.verifyMarketplacePublicFiles(
        (relative: string) => relative === strictHistoricalPath ? read(relative) : stageBoundary.readCandidate(relative),
        stageBoundary.existsCandidate,
        manifest,
        stageBoundary.fixtureRoot,
      ),
      /candidate bytes changed/u,
    );
  } finally {
    rmSync(stageBoundary.fixtureRoot, { recursive: true, force: true });
  }
  const runCase = (relative: string, source: string, expected: RegExp) => {
    const item = task4FilesystemFixture(api, manifest);
    try {
      writeFixtureFile(item.fixtureRoot, relative, source);
      assert.throws(
        () => api.verifyMarketplacePublicFiles(item.readCandidate, item.existsCandidate, manifest, item.fixtureRoot),
        expected,
      );
    } finally {
      rmSync(item.fixtureRoot, { recursive: true, force: true });
    }
  };
  for (const relative of [
    'backend/src/modules/marketplace/public/provider-access-policy-copy.ts',
    'backend/src/modules/marketplace/public/nested/provider-access-policy.ts',
    'backend/src/provider-dashboard/provider-access-policy.ts',
  ]) {
    runCase(relative, 'export const PROVIDER_NOT_ACTIVE = true;\n', /copy/u);
  }
  runCase(
    'backend/src/modules/marketplace/public/index.ts',
    "export { providerAccessPolicy } from './provider-access-policy';\n",
    /re-export/u,
  );
  runCase(
    'backend/src/notifications/alternate-policy.ts',
    "import '../modules/marketplace/public/provider-access-policy-copy';\n",
    /alternate/u,
  );
  runCase(
    'backend/src/tasks/unlisted-provider-policy-consumer.ts',
    "import '../modules/marketplace/public/provider-access-policy';\n",
    /deepStrictEqual|Expected values/u,
  );

  const item = task4FilesystemFixture(api, manifest);
  try {
    const driftedRead = (relative: string) => relative === marketplacePolicyPublicPath
      ? Buffer.concat([item.readCandidate(relative), Buffer.from(' ')] as Buffer[])
      : item.readCandidate(relative);
    assert.throws(
      () => api.verifyMarketplacePublicFiles(driftedRead, item.existsCandidate, manifest, item.fixtureRoot),
      /parity|candidate bytes changed/u,
    );
    for (const broadOrNearMiss of [
      "\nconst providerAccessPolicy = '^src/.*provider-access-policy.*$';\n",
      "\nconst providerAccessPolicyNearMiss = '^src/provider-dashboard/provider-access-policy-copy\\.ts$';\n",
    ]) {
      const authorityRead = (relative: string) => relative === 'backend/.dependency-cruiser.cjs'
        ? Buffer.concat([item.readCandidate(relative), Buffer.from(broadOrNearMiss)])
        : item.readCandidate(relative);
      assert.throws(
        () => api.verifyMarketplacePublicFiles(authorityRead, item.existsCandidate, manifest, item.fixtureRoot),
        /candidate bytes changed/u,
      );
    }
  } finally {
    rmSync(item.fixtureRoot, { recursive: true, force: true });
  }
});

test('R12C Task 4 exact public target must be a plain file, never a directory or Windows reparse point', () => {
  const { api, manifest } = load();
  assert.equal(typeof api.verifyMarketplacePublicFiles, 'function');
  const directory = task4FilesystemFixture(api, manifest);
  try {
    const target = path.join(directory.fixtureRoot, ...marketplacePolicyPublicPath.split('/'));
    rmSync(target, { force: true });
    mkdirSync(target);
    assert.throws(
      () => api.verifyMarketplacePublicFiles(directory.readCandidate, directory.existsCandidate, manifest, directory.fixtureRoot),
      /plain|regular|file|symlink|reparse/u,
    );
  } finally {
    rmSync(directory.fixtureRoot, { recursive: true, force: true });
  }

  const reparse = task4FilesystemFixture(api, manifest);
  try {
    const target = path.join(reparse.fixtureRoot, ...marketplacePolicyPublicPath.split('/'));
    const actualDirectory = path.join(reparse.fixtureRoot, 'junction-target');
    rmSync(target, { force: true });
    mkdirSync(actualDirectory);
    symlinkSync(actualDirectory, target, 'junction');
    assert.throws(
      () => api.verifyMarketplacePublicFiles(reparse.readCandidate, reparse.existsCandidate, manifest, reparse.fixtureRoot),
      /plain|regular|file|symlink|reparse/u,
    );
  } finally {
    rmSync(reparse.fixtureRoot, { recursive: true, force: true });
  }
});
