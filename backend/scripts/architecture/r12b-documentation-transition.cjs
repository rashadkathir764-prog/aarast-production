'use strict';

const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const scanner = require('./r12b-planning-public-contracts-scan.cjs');

const MANIFEST_RELATIVE = 'backend/architecture/r12b-planning-public-contracts.json';
const JOURNAL_RELATIVE = 'backend/architecture/.r12b-documentation-transition.json';
const GENESIS_SHA256 = 'e60fbd3d8820a9bfa00199937e0ce44025a32a73f41454786a3d53aef1adf4ad';
const HASH = /^[0-9a-f]{64}$/u;
const DOCUMENT_PATHS = Object.freeze([
  'ARCHITECTURE.md',
  'CHANGELOG.md',
  'docs/project/DECISIONS.md',
  'docs/project/EXECUTION_PLAN.md',
  'docs/project/STATUS.md',
  'docs/README.md',
  'docs/SCRIPTS.md',
]);
const TRANSITIONS = Object.freeze([
  ['entry', 'candidate-prepared'],
  ['candidate-prepared', 'candidate'],
  ['candidate', 'activation-prepared'],
  ['activation-prepared', 'activated'],
]);

function sha256(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}

function safeAbsoluteRoot(value, label) {
  if (typeof value !== 'string' || !path.isAbsolute(value) || !fs.existsSync(value)) throw new Error(`${label} must be an existing absolute directory`);
  const stat = fs.lstatSync(value);
  if (stat.isSymbolicLink() || !stat.isDirectory()) throw new Error(`${label} must be a plain directory without a symlink or reparse point`);
  return fs.realpathSync.native(value);
}

function boundedFile(root, relative, label) {
  const rootReal = fs.realpathSync.native(root);
  let current = root;
  for (const part of relative.split('/')) {
    if (!part || part === '.' || part === '..') throw new Error(`${label} path is unsafe`);
    current = path.join(current, part);
    if (!fs.existsSync(current)) throw new Error(`${label} document is missing: ${relative}`);
    const stat = fs.lstatSync(current);
    if (stat.isSymbolicLink()) throw new Error(`${label} contains a symlink or reparse point: ${relative}`);
  }
  const real = fs.realpathSync.native(current);
  const escaped = path.relative(rootReal, real);
  if (escaped.startsWith('..') || path.isAbsolute(escaped)) throw new Error(`${label} escapes its prepared root`);
  const stat = fs.lstatSync(current);
  if (!stat.isFile() || stat.size > 16 * 1024 * 1024) throw new Error(`${label} must be a bounded plain file`);
  return current;
}

function readDocuments(root, label) {
  return DOCUMENT_PATHS.map((relative) => {
    const file = boundedFile(root, relative, label);
    const bytes = fs.readFileSync(file);
    return { path: relative, sha256: sha256(bytes), bytes };
  });
}

function publicDocuments(documents) {
  return documents.map((item) => ({ path: item.path, sha256: item.sha256 }));
}

function expectedDocuments(manifest, state) {
  const transforms = manifest.inverseTransforms.filter((item) => item.kind === 'documentation-transition');
  const field = ['entry', 'candidate-prepared'].includes(state)
    ? 'entrySha256'
    : ['candidate', 'activation-prepared'].includes(state)
      ? 'candidateSha256'
      : 'activatedSha256';
  return transforms.map((item) => ({ path: item.path, sha256: item[field] }));
}

function assertDocumentHashes(actual, expected, label) {
  if (actual.length !== DOCUMENT_PATHS.length || expected.length !== DOCUMENT_PATHS.length) throw new Error(`${label} document count changed`);
  actual.forEach((item, index) => {
    if (item.path !== DOCUMENT_PATHS[index] || expected[index].path !== DOCUMENT_PATHS[index] || item.sha256 !== expected[index].sha256) throw new Error(`${label} document hash or order changed: ${DOCUMENT_PATHS[index]}`);
  });
}

function hashReceipt(receipt) {
  const unsigned = {
    sequence: receipt.sequence,
    from: receipt.from,
    to: receipt.to,
    previousReceiptSha256: receipt.previousReceiptSha256,
    beforeDocuments: receipt.beforeDocuments,
    afterDocuments: receipt.afterDocuments,
    candidateDocuments: receipt.candidateDocuments,
    activatedDocuments: receipt.activatedDocuments,
  };
  return sha256(Buffer.from(JSON.stringify(unsigned), 'utf8'));
}

function refreshNormalizedSelfContract(manifest) {
  const self = manifest.r12bPaths && manifest.r12bPaths[0];
  if (!self || self.hashMode !== 'normalized-self') throw new Error('R12B normalized-self contract is missing');
  self.normalizedSelfSha256 = '0'.repeat(64);
  const normalized = Buffer.from(`${JSON.stringify(manifest, null, 2)}\n`, 'utf8');
  self.normalizedSelfSha256 = sha256(normalized);
}

function readManifest(repositoryRoot, expectedManifestSha256) {
  const manifestFile = boundedFile(repositoryRoot, MANIFEST_RELATIVE, 'R12B manifest');
  const bytes = fs.readFileSync(manifestFile);
  if (typeof expectedManifestSha256 !== 'string' || !HASH.test(expectedManifestSha256) || sha256(bytes) !== expectedManifestSha256) throw new Error('R12B expected manifest hash is stale or invalid');
  let parsed;
  try {
    parsed = JSON.parse(bytes.toString('utf8'));
  } catch {
    throw new Error('R12B manifest JSON is invalid');
  }
  return { manifestFile, bytes, manifest: scanner.validateR12bManifest(parsed) };
}

function assertNoTransitionArtifacts(repositoryRoot) {
  const artifacts = [JOURNAL_RELATIVE, MANIFEST_RELATIVE, ...DOCUMENT_PATHS]
    .flatMap((relative) => relative === JOURNAL_RELATIVE ? [relative] : [`${relative}.r12b-documentation.bak`, `${relative}.r12b-documentation.tmp`, `${relative}.r12b-documentation.restore.tmp`]);
  for (const relative of artifacts) {
    const candidate = path.join(repositoryRoot, ...relative.split('/'));
    if (fs.existsSync(candidate)) throw new Error('R12B documentation transition recovery or stale artifact cleanup is required');
  }
}

function planDocumentationTransition(options = {}) {
  const optionKeys = new Set(['repositoryRoot', 'to', 'expectedManifestSha256', 'candidateRoot', 'activatedRoot', 'preparedRoot', 'replaceFile']);
  if (Object.keys(options).some((key) => !optionKeys.has(key))) throw new Error('R12B transition options contain an irrelevant key');
  const repositoryRoot = safeAbsoluteRoot(options.repositoryRoot, 'R12B repository root');
  assertNoTransitionArtifacts(repositoryRoot);
  const current = readManifest(repositoryRoot, options.expectedManifestSha256);
  if (current.manifest.stage !== 'strict') throw new Error('R12B documentation transitions require dependency stage strict');
  const transitionIndex = TRANSITIONS.findIndex(([from, to]) => from === current.manifest.documentationStage && to === options.to);
  if (transitionIndex < 0) throw new Error('R12B documentation transition is not the next legal state');
  const [from, to] = TRANSITIONS[transitionIndex];
  if (to === 'candidate-prepared') {
    if (!options.candidateRoot || !options.activatedRoot || options.preparedRoot) throw new Error('R12B candidate-prepared transition requires exactly candidate and activated roots');
  } else if (!options.preparedRoot || options.candidateRoot || options.activatedRoot) {
    throw new Error('R12B publication transition requires exactly one prepared root');
  }
  const live = readDocuments(repositoryRoot, 'R12B live documentation');
  assertDocumentHashes(live, expectedDocuments(current.manifest, from), 'R12B live documentation');

  const nextManifest = structuredClone(current.manifest);
  let candidate;
  let activated;
  let prepared = null;
  let publication = false;
  if (to === 'candidate-prepared') {
    const candidateRoot = safeAbsoluteRoot(options.candidateRoot, 'R12B candidate root');
    const activatedRoot = safeAbsoluteRoot(options.activatedRoot, 'R12B activated root');
    candidate = readDocuments(candidateRoot, 'R12B candidate documentation');
    activated = readDocuments(activatedRoot, 'R12B activated documentation');
    for (let index = 0; index < DOCUMENT_PATHS.length; index += 1) {
      const isGeneratedScripts = DOCUMENT_PATHS[index] === 'docs/SCRIPTS.md';
      if (candidate[index].sha256 === live[index].sha256) throw new Error('R12B candidate documentation must differ from entry');
      if (isGeneratedScripts) {
        if (activated[index].sha256 !== candidate[index].sha256) throw new Error('R12B generated scripts candidate and activated bytes must match');
      } else if (activated[index].sha256 === candidate[index].sha256) {
        throw new Error('R12B narrative candidate and activated states must be distinct');
      }
      const transform = nextManifest.inverseTransforms.find((item) => item.kind === 'documentation-transition' && item.path === DOCUMENT_PATHS[index]);
      transform.candidateSha256 = candidate[index].sha256;
      transform.activatedSha256 = activated[index].sha256;
    }
  } else {
    const transforms = nextManifest.inverseTransforms.filter((item) => item.kind === 'documentation-transition');
    candidate = transforms.map((item) => ({ path: item.path, sha256: item.candidateSha256 }));
    activated = transforms.map((item) => ({ path: item.path, sha256: item.activatedSha256 }));
    const preparedRoot = safeAbsoluteRoot(options.preparedRoot, 'R12B prepared root');
    prepared = readDocuments(preparedRoot, 'R12B prepared documentation');
    const expectedPrepared = to === 'candidate' ? candidate : activated;
    assertDocumentHashes(prepared, expectedPrepared, 'R12B prepared documentation');
    publication = to === 'candidate' || to === 'activated';
  }

  const beforeDocuments = publicDocuments(live);
  const afterDocuments = publication ? publicDocuments(prepared) : beforeDocuments.map((item) => ({ ...item }));
  const candidateDocuments = candidate.map((item) => ({ path: item.path, sha256: item.sha256 }));
  const activatedDocuments = activated.map((item) => ({ path: item.path, sha256: item.sha256 }));
  const previousReceiptSha256 = current.manifest.documentationTransitions.length
    ? current.manifest.documentationTransitions[current.manifest.documentationTransitions.length - 1].receiptSha256
    : GENESIS_SHA256;
  const receipt = {
    sequence: transitionIndex + 1,
    from,
    to,
    previousReceiptSha256,
    beforeDocuments,
    afterDocuments,
    candidateDocuments,
    activatedDocuments,
    receiptSha256: '',
  };
  receipt.receiptSha256 = hashReceipt(receipt);
  nextManifest.documentationTransitions.push(receipt);
  nextManifest.documentationStage = to;
  refreshNormalizedSelfContract(nextManifest);
  scanner.validateR12bManifest(nextManifest);
  return Object.freeze({
    repositoryRoot,
    manifestFile: current.manifestFile,
    currentManifestBytes: current.bytes,
    nextManifest,
    live,
    prepared,
    publication,
    transition: Object.freeze({ from, to }),
  });
}

function writeAndVerify(file, bytes, expectedHash) {
  if (fs.existsSync(file)) throw new Error(`R12B transition artifact already exists: ${file}`);
  fs.writeFileSync(file, bytes, { flag: 'wx' });
  if (sha256(fs.readFileSync(file)) !== expectedHash) throw new Error('R12B transition artifact hash verification failed');
}

function removeIfExists(file) {
  if (fs.existsSync(file)) fs.rmSync(file, { force: true });
}

function replaceManifestAtomically(manifestFile, nextBytes) {
  const temporary = `${manifestFile}.r12b-documentation.tmp`;
  writeAndVerify(temporary, nextBytes, sha256(nextBytes));
  try {
    atomicReplaceExisting(manifestFile, temporary);
  } catch (error) {
    removeIfExists(temporary);
    throw error;
  }
}

function atomicReplaceExisting(target, temporary) {
  fs.renameSync(temporary, target);
}

function cleanupArtifacts(artifacts, journalFile, manifestArtifact) {
  for (const item of artifacts) {
    removeIfExists(item.temporary);
    removeIfExists(item.backup);
    removeIfExists(item.restorationTemporary);
  }
  if (manifestArtifact) {
    removeIfExists(manifestArtifact.temporary);
    removeIfExists(manifestArtifact.backup);
    removeIfExists(manifestArtifact.restorationTemporary);
  }
  removeIfExists(journalFile);
}

function restoreFileAtomically(target, restorationTemporary, bytes, expectedHash) {
  if (fs.existsSync(restorationTemporary)) {
    if (sha256(fs.readFileSync(restorationTemporary)) !== expectedHash) throw new Error('R12B restoration artifact hash verification failed');
  } else {
    writeAndVerify(restorationTemporary, bytes, expectedHash);
  }
  atomicReplaceExisting(target, restorationTemporary);
  if (sha256(fs.readFileSync(target)) !== expectedHash) throw new Error('R12B restored target hash verification failed');
}

function restorePublication(plan, artifacts, journalFile, manifestArtifact) {
  for (let index = 0; index < plan.live.length; index += 1) {
    restoreFileAtomically(
      artifacts[index].target,
      artifacts[index].restorationTemporary,
      plan.live[index].bytes,
      plan.live[index].sha256,
    );
  }
  restoreFileAtomically(
    plan.manifestFile,
    manifestArtifact.restorationTemporary,
    plan.currentManifestBytes,
    manifestArtifact.beforeSha256,
  );
  for (let index = 0; index < plan.live.length; index += 1) {
    if (sha256(fs.readFileSync(artifacts[index].target)) !== plan.live[index].sha256) throw new Error('R12B documentation rollback verification failed');
  }
  if (sha256(fs.readFileSync(plan.manifestFile)) !== manifestArtifact.beforeSha256) throw new Error('R12B manifest rollback verification failed');
  cleanupArtifacts(artifacts, journalFile, manifestArtifact);
}

function runDocumentationTransition(options = {}) {
  const plan = planDocumentationTransition(options);
  const nextBytes = Buffer.from(`${JSON.stringify(plan.nextManifest, null, 2)}\n`, 'utf8');
  if (!plan.publication) {
    replaceManifestAtomically(plan.manifestFile, nextBytes);
    return Object.freeze({ ok: true, from: plan.transition.from, to: plan.transition.to, receipt: plan.nextManifest.documentationTransitions.length });
  }

  const journalFile = path.join(plan.repositoryRoot, ...JOURNAL_RELATIVE.split('/'));
  const manifestArtifact = {
    target: plan.manifestFile,
      backup: `${plan.manifestFile}.r12b-documentation.bak`,
      temporary: `${plan.manifestFile}.r12b-documentation.tmp`,
      restorationTemporary: `${plan.manifestFile}.r12b-documentation.restore.tmp`,
      beforeSha256: sha256(plan.currentManifestBytes),
      afterSha256: sha256(nextBytes),
  };
  const artifacts = DOCUMENT_PATHS.map((relative, index) => {
    const target = path.join(plan.repositoryRoot, ...relative.split('/'));
    return {
      path: relative,
      target,
        backup: `${target}.r12b-documentation.bak`,
        temporary: `${target}.r12b-documentation.tmp`,
        restorationTemporary: `${target}.r12b-documentation.restore.tmp`,
        beforeSha256: plan.live[index].sha256,
        afterSha256: plan.prepared[index].sha256,
    };
  });
  const journal = {
    schemaVersion: 1,
    from: plan.transition.from,
    to: plan.transition.to,
    manifestSha256: sha256(plan.currentManifestBytes),
    nextManifestSha256: sha256(nextBytes),
    artifacts: artifacts.map(({ path: relative, beforeSha256, afterSha256 }) => ({ path: relative, beforeSha256, afterSha256 })),
  };
  fs.writeFileSync(journalFile, `${JSON.stringify(journal, null, 2)}\n`, { flag: 'wx' });
  try {
    writeAndVerify(manifestArtifact.backup, plan.currentManifestBytes, manifestArtifact.beforeSha256);
    writeAndVerify(manifestArtifact.temporary, nextBytes, manifestArtifact.afterSha256);
    artifacts.forEach((artifact, index) => {
      writeAndVerify(artifact.backup, plan.live[index].bytes, artifact.beforeSha256);
      writeAndVerify(artifact.temporary, plan.prepared[index].bytes, artifact.afterSha256);
    });
    artifacts.forEach((artifact) => {
      const operation = () => {
        atomicReplaceExisting(artifact.target, artifact.temporary);
        if (sha256(fs.readFileSync(artifact.target)) !== artifact.afterSha256) throw new Error('R12B published documentation hash verification failed');
      };
      if (typeof options.replaceFile === 'function') options.replaceFile(operation, artifact.path);
      else operation();
    });
    atomicReplaceExisting(plan.manifestFile, manifestArtifact.temporary);
    if (sha256(fs.readFileSync(plan.manifestFile)) !== manifestArtifact.afterSha256) throw new Error('R12B published manifest hash verification failed');
    cleanupArtifacts(artifacts, journalFile, manifestArtifact);
    return Object.freeze({ ok: true, from: plan.transition.from, to: plan.transition.to, receipt: plan.nextManifest.documentationTransitions.length });
  } catch (error) {
    restorePublication(plan, artifacts, journalFile, manifestArtifact);
    throw error;
  }
}

function recoverDocumentationTransition(options = {}) {
  const repositoryRoot = safeAbsoluteRoot(options.repositoryRoot, 'R12B repository root');
  const journalFile = path.join(repositoryRoot, ...JOURNAL_RELATIVE.split('/'));
  if (!fs.existsSync(journalFile)) {
    const stale = [MANIFEST_RELATIVE, ...DOCUMENT_PATHS].flatMap((relative) => [
      `${relative}.r12b-documentation.bak`, `${relative}.r12b-documentation.tmp`, `${relative}.r12b-documentation.restore.tmp`,
    ]).some((relative) => fs.existsSync(path.join(repositoryRoot, ...relative.split('/'))));
    if (stale) throw new Error('R12B stale transition artifact exists without a recovery journal');
    return Object.freeze({ ok: true, recovered: false });
  }
  const journal = JSON.parse(fs.readFileSync(boundedFile(repositoryRoot, JOURNAL_RELATIVE, 'R12B transition journal'), 'utf8'));
  if (!journal || journal.schemaVersion !== 1 || !HASH.test(journal.manifestSha256) || !HASH.test(journal.nextManifestSha256) || !Array.isArray(journal.artifacts) || journal.artifacts.length !== DOCUMENT_PATHS.length) throw new Error('R12B transition journal is invalid');
  const manifestFile = path.join(repositoryRoot, ...MANIFEST_RELATIVE.split('/'));
  const manifestBackup = `${manifestFile}.r12b-documentation.bak`;
  const manifestTemporary = `${manifestFile}.r12b-documentation.tmp`;
  const manifestRestorationTemporary = `${manifestFile}.r12b-documentation.restore.tmp`;
  journal.artifacts.forEach((record, index) => {
    if (!record || record.path !== DOCUMENT_PATHS[index] || !HASH.test(record.beforeSha256) || !HASH.test(record.afterSha256)) throw new Error('R12B transition journal record is invalid');
  });
  const completed = fs.existsSync(manifestFile)
    && sha256(fs.readFileSync(manifestFile)) === journal.nextManifestSha256
    && journal.artifacts.every((record) => {
      const target = path.join(repositoryRoot, ...record.path.split('/'));
      return fs.existsSync(target) && sha256(fs.readFileSync(target)) === record.afterSha256;
    });
  if (completed) {
    journal.artifacts.forEach((record) => {
      const target = path.join(repositoryRoot, ...record.path.split('/'));
      removeIfExists(`${target}.r12b-documentation.bak`);
      removeIfExists(`${target}.r12b-documentation.tmp`);
      removeIfExists(`${target}.r12b-documentation.restore.tmp`);
    });
    removeIfExists(manifestBackup);
    removeIfExists(manifestTemporary);
    removeIfExists(manifestRestorationTemporary);
    removeIfExists(journalFile);
    return Object.freeze({ ok: true, recovered: true, completed: true });
  }
  if (!fs.existsSync(manifestBackup) || sha256(fs.readFileSync(manifestBackup)) !== journal.manifestSha256) throw new Error('R12B recovery manifest backup is missing or invalid');
  const recoveryArtifacts = journal.artifacts.map((record) => {
    const target = path.join(repositoryRoot, ...record.path.split('/'));
    return {
      target,
      backup: `${target}.r12b-documentation.bak`,
      temporary: `${target}.r12b-documentation.tmp`,
      restorationTemporary: `${target}.r12b-documentation.restore.tmp`,
      beforeSha256: record.beforeSha256,
    };
  });
  recoveryArtifacts.forEach((artifact) => {
    if (!fs.existsSync(artifact.backup) || sha256(fs.readFileSync(artifact.backup)) !== artifact.beforeSha256) throw new Error('R12B recovery backup is missing or invalid');
  });
  const manifestBeforeBytes = fs.readFileSync(manifestBackup);
  recoveryArtifacts.forEach((artifact) => {
    restoreFileAtomically(
      artifact.target,
      artifact.restorationTemporary,
      fs.readFileSync(artifact.backup),
      artifact.beforeSha256,
    );
  });
  restoreFileAtomically(manifestFile, manifestRestorationTemporary, manifestBeforeBytes, journal.manifestSha256);
  recoveryArtifacts.forEach((artifact) => {
    if (sha256(fs.readFileSync(artifact.target)) !== artifact.beforeSha256) throw new Error('R12B recovered document hash is invalid');
  });
  if (sha256(fs.readFileSync(manifestFile)) !== journal.manifestSha256) throw new Error('R12B recovered manifest hash is invalid');
  cleanupArtifacts(recoveryArtifacts, journalFile, {
    temporary: manifestTemporary,
    backup: manifestBackup,
    restorationTemporary: manifestRestorationTemporary,
  });
  return Object.freeze({ ok: true, recovered: true, completed: false });
}

function parseCli(argv) {
  if (argv.length === 1 && argv[0] === '--recover') return { recover: true };
  const allowed = new Set(['--to', '--expected-manifest-sha256', '--candidate-root', '--activated-root', '--prepared-root']);
  const result = {};
  for (let index = 0; index < argv.length; index += 2) {
    if (!allowed.has(argv[index]) || typeof argv[index + 1] !== 'string' || Object.prototype.hasOwnProperty.call(result, argv[index].slice(2))) throw new Error('invalid arguments');
    result[argv[index].slice(2).replace(/-([a-z])/gu, (_, letter) => letter.toUpperCase())] = argv[index + 1];
  }
  if (!result.to || !result.expectedManifestSha256) throw new Error('invalid arguments');
  return result;
}

function runCli() {
  try {
    const repositoryRoot = path.resolve(__dirname, '../../..');
    const options = parseCli(process.argv.slice(2));
    const result = options.recover
      ? recoverDocumentationTransition({ repositoryRoot })
      : runDocumentationTransition({ repositoryRoot, ...options });
    process.stdout.write(`PASS - R12B documentation transition: ${result.recovered === false ? 'recovery=clean' : result.recovered ? 'recovery=restored' : `${result.from}->${result.to}, receipt=${result.receipt}`}\n`);
    return 0;
  } catch (error) {
    if (process.env.R12B_DEBUG === '1') process.stderr.write(`${error.stack || error}\n`);
    else process.stderr.write('ERROR - R12B documentation transition failed\n');
    return 2;
  }
}

module.exports = {
  planDocumentationTransition,
  runDocumentationTransition,
  recoverDocumentationTransition,
  runCli,
};

if (require.main === module) process.exitCode = runCli();
