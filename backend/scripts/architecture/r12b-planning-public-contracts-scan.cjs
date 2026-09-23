'use strict';

const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const prismaSecurity = require('../security/prisma-config-merge-security.cjs');
const identity = require('./repository-identity.cjs');
const closure = require('./modular-monolith-closure.cjs');

const MANIFEST_PATH = 'backend/architecture/r12b-planning-public-contracts.json';
const R12A_MANIFEST_PATH = 'backend/architecture/r12a-backoffice-catalog-public-contracts.json';
const R12A_SCANNER_PATH = './r12a-backoffice-catalog-public-contracts-scan.cjs';
const DEPENDENCY_PATH = 'backend/.dependency-cruiser-known-violations.json';
const OWNERSHIP_PATH = 'backend/architecture/ownership-baseline.json';
const BASE_COMMIT = '4d0d3ee91fb32d0432aa3bd69fe018d9a5a323b1';
const GENESIS_SHA256 = 'e60fbd3d8820a9bfa00199937e0ce44025a32a73f41454786a3d53aef1adf4ad';
const OVERLAY_SHA256 = '30e2de6928edd7ac1b44598fae4ad18dbcd452b34f7e9a6fb792e1936ce8561c';
const R12A_MANIFEST_SHA256 = 'b2904ef15dd104da8cc27315d89880b75042a6175df3a756897b0b45e4a269fd';
const DEPENDENCY_SHA256 = '4dd61610c6583e369b836b3b0fe80ffc63153e70a0fbe86a089509962b35c71e';
const OWNERSHIP_SHA256 = '5f42f33300a9727f587e62327c5261a88a6ce5928437241c9e7c20f726906496';
const R12A_SEMANTIC_DEPENDENCY_SHA256 = 'a469731ea0ae7d27c3054bf65161091fd2df07b8bdcabf43de4e70b1235a6f74';
const APPROVED_SECURITY_PREREQUISITE_PATH = 'backend/package-lock.json';
const APPROVED_SECURITY_PREREQUISITE_OLD_SHA256 = '30bd3b228b763b3bbe895554a71623465e9717409c71266dbdff41e4c079cf0b';
const APPROVED_SECURITY_PREREQUISITE_NEW_SHA256 = '650bc45c00cd3cdf8298e33570481bb969fdbae78a63167cca9f8ff243b25f60';
const APPROVED_QS_VERSION = '6.16.0';
const APPROVED_QS_RESOLVED = 'https://registry.npmjs.org/qs/-/qs-6.16.0.tgz';
const APPROVED_QS_INTEGRITY = 'sha512-h6fhOIaRrID2CbEY2fqs+7t+UXZo+MLAnU5gRIq85uFtdiUPCdsApMlHhXogKVM4HM2DVbIjGNTTYH2OcmP1vA==';
const HASH = /^[0-9a-f]{64}$/u;
const STAGE_NAMES = Object.freeze(['design', 'planning-public', 'strict']);
const DOCUMENT_STAGES = Object.freeze(['entry', 'candidate-prepared', 'candidate', 'activation-prepared', 'activated']);
const DOCUMENT_PATHS = Object.freeze([
  'ARCHITECTURE.md',
  'CHANGELOG.md',
  'docs/project/DECISIONS.md',
  'docs/project/EXECUTION_PLAN.md',
  'docs/project/STATUS.md',
  'docs/README.md',
  'docs/SCRIPTS.md',
]);
const FINAL_REPORT_PATH = 'docs/superpowers/reports/2026-09-02-modular-monolith-r12b-planning-public-contracts-report.md';
const PRODUCT_FRESHNESS_PATH = 'docs/project/PRODUCT.md';
const PRODUCT_FRESHNESS_STATUS = ' M';
const PRODUCT_FRESHNESS_OLD_DATE = 'Snapshot date: 2026-07-23';
const PRODUCT_FRESHNESS_NEW_DATE = 'Snapshot date: 2026-09-07';
const PRODUCT_FRESHNESS_OLD_SHA256 = '39167ec645e0ae67061432f2938dd2b09e17e591f8e127f988974776b944b536';
const PRODUCT_FRESHNESS_NEW_SHA256 = 'b1562c7203db76d3571700e9272989fe60f1efb45af27b6e3cf23a4028f2da08';
const PRODUCT_FRESHNESS_STAGES = Object.freeze(['candidate', 'activation-prepared', 'activated']);
const TRANSITIONS = Object.freeze([
  ['entry', 'candidate-prepared'],
  ['candidate-prepared', 'candidate'],
  ['candidate', 'activation-prepared'],
  ['activation-prepared', 'activated'],
]);
const INVERSE_PATHS = Object.freeze([
  'backend/.dependency-cruiser-known-violations.json',
  'backend/package.json',
  'backend/src/marketplace/marketplace.service.ts',
  'backend/scripts/architecture/r3-context-scan.cjs',
  'backend/scripts/architecture/r5-identity-scan.cjs',
  'backend/scripts/architecture/r6-sharing-otp-transport-scan.cjs',
  'backend/scripts/architecture/r7-collaboration-relocation-scan.cjs',
  'backend/scripts/architecture/r8-global-module-removal-scan.cjs',
  'backend/scripts/architecture/r12a-backoffice-catalog-public-contracts-scan.cjs',
  'backend/scripts/security/prisma-config-merge-security.cjs',
  'backend/test/architecture-r3-contexts.test.ts',
  'backend/test/architecture-r3-scope.test.ts',
  'backend/test/architecture-r5-identity-relocation.test.ts',
  'backend/test/architecture-r6-sharing-otp-transport.test.ts',
  'backend/test/architecture-r7-collaboration-relocation.test.ts',
  'backend/test/architecture-r8-global-module-removal.test.ts',
  'backend/test/architecture-r12a-backoffice-catalog-public-contracts.test.ts',
  'backend/test/prisma-config-merge-security.test.ts',
  ...DOCUMENT_PATHS,
]);
const INVERSE_KINDS = Object.freeze([
  'dependency-subtraction-reinsertion',
  'package-script-projection',
  'exact-text-rewrite',
  ...Array(15).fill('bounded-hunk-replay'),
  ...Array(7).fill('documentation-transition'),
]);
const NEW_R12B_PATHS = new Set([
  MANIFEST_PATH,
  'backend/scripts/architecture/r12b-planning-public-contracts-scan.cjs',
  'backend/scripts/architecture/r12b-documentation-transition.cjs',
  'backend/test/architecture-r12b-planning-public-contracts.test.ts',
  'backend/test/architecture-r12b-documentation-transition.test.ts',
  'docs/superpowers/plans/2026-09-02-modular-monolith-r12b-planning-public-contracts.md',
  'docs/superpowers/specs/2026-09-02-modular-monolith-r12b-planning-public-contracts-design.md',
  'backend/src/onboarding/dto/import-local-plan.dto.ts',
  'backend/src/onboarding/dto/import-local-task.dto.ts',
  'backend/src/onboarding/dto/import-local-guest.dto.ts',
  'backend/test/import-local-plan-dto-contract.test.ts',
]);
const R12B_PATHS = Object.freeze([
  MANIFEST_PATH,
  'backend/scripts/architecture/r12b-planning-public-contracts-scan.cjs',
  'backend/scripts/architecture/r12b-documentation-transition.cjs',
  'backend/test/architecture-r12b-planning-public-contracts.test.ts',
  'backend/test/architecture-r12b-documentation-transition.test.ts',
  'docs/superpowers/plans/2026-09-02-modular-monolith-r12b-planning-public-contracts.md',
  'docs/superpowers/specs/2026-09-02-modular-monolith-r12b-planning-public-contracts-design.md',
  'backend/src/onboarding/dto/import-local-plan.dto.ts',
  'backend/src/onboarding/dto/import-local-task.dto.ts',
  'backend/src/onboarding/dto/import-local-guest.dto.ts',
  'backend/test/import-local-plan-dto-contract.test.ts',
]);
const R12B_PATH_STATUSES = Object.freeze([
  '??', '??', '??', '??', '??', '??', '??', ' M', '??', '??', '??',
]);
const TOP_LEVEL_KEYS = Object.freeze([
  'schemaVersion',
  'phase',
  'stage',
  'documentationStage',
  'documentationTransitionGenesisSha256',
  'documentationTransitions',
  'repository',
  'predecessor',
  'stages',
  'dependencyRecords',
  'locationMove',
  'locationConsumers',
  'dtoReexpressions',
  'behavioralTests',
  'protectedPaths',
  'approvedSecurityPrerequisite',
  'r12bPaths',
  'inverseTransforms',
]);

function sha256(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}

function plainObject(value, label) {
  if (!value || typeof value !== 'object' || Array.isArray(value) || Object.getPrototypeOf(value) !== Object.prototype) {
    throw new Error(`${label} must be a plain object`);
  }
  return value;
}

function exactKeys(value, keys, label) {
  plainObject(value, label);
  if (JSON.stringify(Object.keys(value)) !== JSON.stringify(keys)) throw new Error(`${label} has unknown, missing, or reordered keys`);
}

function denseArray(value, label, maximum = 1024) {
  if (!Array.isArray(value) || value.length > maximum) throw new Error(`${label} must be a bounded array`);
  for (let index = 0; index < value.length; index += 1) if (!(index in value)) throw new Error(`${label} must not be sparse`);
  return value;
}

function safeInteger(value, label) {
  if (!Number.isSafeInteger(value) || value < 0) throw new Error(`${label} must be a safe non-negative integer`);
}

function safeRelative(value, label) {
  if (typeof value !== 'string' || value.length < 1 || value.length > 512 || value.includes('\\') || path.posix.isAbsolute(value) || value.split('/').some((part) => part === '' || part === '.' || part === '..')) {
    throw new Error(`${label} must be a safe repository-relative path`);
  }
  return value;
}

function exact(value, expected, label) {
  if (value !== expected) throw new Error(`${label} changed`);
}

function exactHash(value, expected, label) {
  if (typeof value !== 'string' || !HASH.test(value) || value !== expected) throw new Error(`${label} hash changed`);
}

function deepData(value, label, seen = new Set(), depth = 0) {
  if (depth > 32) throw new Error(`${label} is too deeply nested`);
  if (value === null || ['string', 'boolean'].includes(typeof value)) return;
  if (typeof value === 'number') {
    if (!Number.isSafeInteger(value)) throw new Error(`${label} contains an unsafe number`);
    return;
  }
  if (typeof value !== 'object' || seen.has(value)) throw new Error(`${label} is not bounded plain data`);
  seen.add(value);
  if (Array.isArray(value)) denseArray(value, label).forEach((item) => deepData(item, label, seen, depth + 1));
  else {
    plainObject(value, label);
    for (const item of Object.values(value)) deepData(item, label, seen, depth + 1);
  }
  seen.delete(value);
}

function deepFreeze(value) {
  if (Buffer.isBuffer(value) || ArrayBuffer.isView(value)) return value;
  if (value && typeof value === 'object' && !Object.isFrozen(value)) {
    Object.freeze(value);
    for (const item of Object.values(value)) deepFreeze(item);
  }
  return value;
}

function validateDocumentArray(value, expectedHashes, label) {
  const documents = denseArray(value, label, DOCUMENT_PATHS.length);
  if (documents.length !== DOCUMENT_PATHS.length) throw new Error(`${label} must contain seven documents`);
  documents.forEach((document, index) => {
    exactKeys(document, ['path', 'sha256'], `${label}[${index}]`);
    exact(document.path, DOCUMENT_PATHS[index], `${label}[${index}].path`);
    if (!HASH.test(document.sha256) || document.sha256 !== expectedHashes[index]) throw new Error(`${label}[${index}] hash changed`);
  });
}

function validateR12bPathContracts(value) {
  const contracts = denseArray(value, 'R12B-only path contracts', R12B_PATHS.length);
  if (contracts.length !== R12B_PATHS.length) throw new Error('R12B-only path contract count changed');
  const seen = new Set();
  contracts.forEach((contract, index) => {
    exactKeys(contract, ['path', 'status', 'hashMode', 'sha256', 'normalizedSelfSha256'], `R12B-only path contract ${index}`);
    exact(contract.path, R12B_PATHS[index], `R12B-only path contract ${index} path`);
    safeRelative(contract.path, `R12B-only path contract ${index} path`);
    if (seen.has(contract.path) || contract.status !== R12B_PATH_STATUSES[index]) throw new Error('R12B-only path contract order/status changed');
    seen.add(contract.path);
    const expectedMode = index === 0 ? 'normalized-self' : 'raw';
    exact(contract.hashMode, expectedMode, `R12B-only path contract ${index} hash mode`);
    if (expectedMode === 'raw') {
      if (!HASH.test(contract.sha256) || contract.sha256 === '0'.repeat(64) || contract.normalizedSelfSha256 !== null) throw new Error('R12B-only raw path hash contract is invalid');
    } else if (contract.sha256 !== null || !HASH.test(contract.normalizedSelfSha256) || contract.normalizedSelfSha256 === '0'.repeat(64)) {
      throw new Error('R12B-only normalized-self contract is invalid');
    }
  });
  return contracts;
}

function validateApprovedSecurityPrerequisiteContract(value) {
  exactKeys(value, [
    'path', 'status', 'oldRawSha256', 'newRawSha256', 'lockfileVersion',
    'package', 'parentRanges',
  ], 'R12B approved security prerequisite');
  exact(value.path, APPROVED_SECURITY_PREREQUISITE_PATH, 'R12B approved security prerequisite path');
  exact(value.status, ' M', 'R12B approved security prerequisite status');
  exactHash(value.oldRawSha256, APPROVED_SECURITY_PREREQUISITE_OLD_SHA256, 'R12B approved security prerequisite old lock');
  exactHash(value.newRawSha256, APPROVED_SECURITY_PREREQUISITE_NEW_SHA256, 'R12B approved security prerequisite new lock');
  exact(value.lockfileVersion, 3, 'R12B approved security prerequisite lockfile version');
  exactKeys(value.package, ['path', 'version', 'resolved', 'integrity'], 'R12B approved qs package');
  exact(value.package.path, 'node_modules/qs', 'R12B approved qs path');
  exact(value.package.version, APPROVED_QS_VERSION, 'R12B approved qs version');
  exact(value.package.resolved, APPROVED_QS_RESOLVED, 'R12B approved qs resolution');
  exact(value.package.integrity, APPROVED_QS_INTEGRITY, 'R12B approved qs integrity');
  const parentRanges = denseArray(value.parentRanges, 'R12B approved qs parent ranges', 2);
  if (parentRanges.length !== 2) throw new Error('R12B approved qs parent range count changed');
  const expected = [
    ['node_modules/express', 'qs', '^6.14.0'],
    ['node_modules/body-parser', 'qs', '^6.15.2'],
  ];
  parentRanges.forEach((parent, index) => {
    exactKeys(parent, ['path', 'dependency', 'range'], `R12B approved qs parent ${index}`);
    if (JSON.stringify(Object.values(parent)) !== JSON.stringify(expected[index])) {
      throw new Error(`R12B approved qs parent ${index} changed`);
    }
  });
  return value;
}

function receiptHash(receipt) {
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

function validateR12bDocumentationTransitions(value) {
  const manifest = plainObject(value, 'R12B manifest');
  if (!DOCUMENT_STAGES.includes(manifest.documentationStage)) throw new Error('R12B documentation stage is invalid');
  exactHash(manifest.documentationTransitionGenesisSha256, GENESIS_SHA256, 'R12B documentation genesis');
  const transforms = denseArray(manifest.inverseTransforms, 'R12B inverse transforms', 25)
    .filter((item) => item.kind === 'documentation-transition');
  if (transforms.length !== DOCUMENT_PATHS.length || JSON.stringify(transforms.map((item) => item.path)) !== JSON.stringify(DOCUMENT_PATHS)) {
    throw new Error('R12B documentation transform order is invalid');
  }
  const entryHashes = transforms.map((item) => item.entrySha256);
  const candidateHashes = transforms.map((item) => item.candidateSha256);
  const activatedHashes = transforms.map((item) => item.activatedSha256);
  entryHashes.forEach((hash) => { if (!HASH.test(hash)) throw new Error('R12B documentation entry hash is invalid'); });
  const stageIndex = DOCUMENT_STAGES.indexOf(manifest.documentationStage);
  if (stageIndex === 0) {
    if (candidateHashes.some((hash) => hash !== null) || activatedHashes.some((hash) => hash !== null)) throw new Error('R12B documentation hashes were registered post-publication');
  } else if (candidateHashes.some((hash) => typeof hash !== 'string' || !HASH.test(hash)) || activatedHashes.some((hash) => typeof hash !== 'string' || !HASH.test(hash))) {
    throw new Error('R12B prepared documentation hashes are missing');
  }
  const receipts = denseArray(manifest.documentationTransitions, 'R12B documentation transitions', 4);
  if (receipts.length !== stageIndex) throw new Error('R12B documentation receipt prefix is invalid');
  let previous = GENESIS_SHA256;
  receipts.forEach((receipt, index) => {
    exactKeys(receipt, [
      'sequence', 'from', 'to', 'previousReceiptSha256', 'beforeDocuments', 'afterDocuments',
      'candidateDocuments', 'activatedDocuments', 'receiptSha256',
    ], `R12B receipt ${index + 1}`);
    safeInteger(receipt.sequence, `R12B receipt ${index + 1} sequence`);
    exact(receipt.sequence, index + 1, `R12B receipt ${index + 1} sequence`);
    exact(receipt.from, TRANSITIONS[index][0], `R12B receipt ${index + 1} from`);
    exact(receipt.to, TRANSITIONS[index][1], `R12B receipt ${index + 1} to`);
    exact(receipt.previousReceiptSha256, previous, `R12B receipt ${index + 1} previous hash`);
    const beforeHashes = index < 2 ? entryHashes : candidateHashes;
    const afterHashes = index === 0 ? entryHashes : index === 1 ? candidateHashes : index === 2 ? candidateHashes : activatedHashes;
    validateDocumentArray(receipt.beforeDocuments, beforeHashes, `R12B receipt ${index + 1} before documents`);
    validateDocumentArray(receipt.afterDocuments, afterHashes, `R12B receipt ${index + 1} after documents`);
    validateDocumentArray(receipt.candidateDocuments, candidateHashes, `R12B receipt ${index + 1} candidate documents`);
    validateDocumentArray(receipt.activatedDocuments, activatedHashes, `R12B receipt ${index + 1} activated documents`);
    if (!HASH.test(receipt.receiptSha256) || receipt.receiptSha256 !== receiptHash(receipt)) throw new Error(`R12B receipt ${index + 1} hash is invalid`);
    previous = receipt.receiptSha256;
  });
  const derived = receipts.length ? receipts[receipts.length - 1].to : 'entry';
  if (derived !== manifest.documentationStage) throw new Error('R12B documentation stage is forged');
  return derived;
}

function validateR12bHunkPayload(inverse) {
  if (!INVERSE_PATHS.slice(3, 18).includes(inverse.path)
      || inverse.kind !== 'bounded-hunk-replay') {
    throw new Error('R12B hunk path/kind changed');
  }
  exactKeys(inverse.payload, ['entryByteLength', 'hunks'], 'R12B hunk payload');
  const { entryByteLength, hunks } = inverse.payload;
  if (entryByteLength === null || hunks === null) {
    if (entryByteLength !== null || hunks !== null
        || inverse.intendedFinalSha256 !== null) {
      throw new Error('R12B hunk registration is partial');
    }
    return null;
  }
  safeInteger(entryByteLength, 'R12B entry byte length');
  if (entryByteLength > 2097152 || !HASH.test(inverse.entrySha256)
      || !HASH.test(inverse.intendedFinalSha256)) {
    throw new Error('R12B hunk file bounds/hash changed');
  }
  denseArray(hunks, 'R12B hunks', 128);
  if (!hunks.length) throw new Error('R12B hunks are empty');
  let previousOffset = -1;
  let previousEnd = 0;
  let textBytes = 0;
  let finalLength = entryByteLength;
  for (const hunk of hunks) {
    exactKeys(hunk, ['offset', 'before', 'after'], 'R12B hunk');
    safeInteger(hunk.offset, 'R12B hunk offset');
    for (const text of [hunk.before, hunk.after]) {
      if (typeof text !== 'string' || Buffer.from(text, 'utf8').toString('utf8') !== text) {
        throw new Error('R12B hunk text is not exact UTF-8');
      }
    }
    const beforeLength = Buffer.byteLength(hunk.before, 'utf8');
    const afterLength = Buffer.byteLength(hunk.after, 'utf8');
    textBytes += beforeLength + afterLength;
    finalLength += afterLength - beforeLength;
    if (hunk.offset <= previousOffset || hunk.offset < previousEnd
        || hunk.offset > entryByteLength
        || beforeLength > entryByteLength - hunk.offset
        || hunk.before === hunk.after || textBytes > 1048576) {
      throw new Error('R12B hunk ordering/range/text changed');
    }
    previousOffset = hunk.offset;
    previousEnd = hunk.offset + beforeLength;
  }
  if (finalLength < 0 || finalLength > 2097152) {
    throw new Error('R12B hunk final byte length changed');
  }
  return inverse.payload;
}

function validateDependencyRecord(record, index, idRequired = true) {
  exactKeys(record, idRequired ? ['id', 'type', 'from', 'to', 'unresolvedTo', 'dependencyTypes', 'rule'] : ['type', 'from', 'to', 'unresolvedTo', 'dependencyTypes', 'rule'], `R12B dependency ${index}`);
  if (idRequired) safeInteger(record.id, `R12B dependency ${index} id`);
  exact(record.type, 'dependency', `R12B dependency ${index} type`);
  safeRelative(record.from, `R12B dependency ${index} from`);
  safeRelative(record.to, `R12B dependency ${index} to`);
  if (typeof record.unresolvedTo !== 'string' || !record.unresolvedTo.startsWith('../')) throw new Error('R12B dependency unresolved path is invalid');
  if (JSON.stringify(record.dependencyTypes) !== '["local","import"]') throw new Error('R12B dependency types changed');
  exactKeys(record.rule, ['severity', 'name'], `R12B dependency ${index} rule`);
  exact(record.rule.severity, 'error', `R12B dependency ${index} severity`);
  if (!/^context-(insights|marketplace|planning)-cross-context$/u.test(record.rule.name)) throw new Error('R12B dependency rule changed');
}

function validateR12bManifest(value) {
  deepData(value, 'R12B manifest');
  exactKeys(value, TOP_LEVEL_KEYS, 'R12B manifest');
  validateR12bPathContracts(value.r12bPaths);
  exact(value.schemaVersion, 2, 'R12B schema version');
  exact(value.phase, 'R12B', 'R12B phase');
  if (!STAGE_NAMES.includes(value.stage)) throw new Error('R12B stage is invalid');
  exactKeys(value.repository, ['rootName', 'branch', 'baseCommit'], 'R12B repository');
  exact(value.repository.rootName, 'aarast-modular-monolith', 'R12B repository root');
  exact(value.repository.branch, 'modular-monolith', 'R12B repository branch');
  if (!/^[0-9a-f]{40}$/u.test(value.repository.baseCommit)) throw new Error('R12B base commit is invalid');
  exact(value.repository.baseCommit, BASE_COMMIT, 'R12B base commit');

  exactKeys(value.predecessor, [
    'phase', 'manifestSha256', 'dependencyRecords', 'dependencySha256', 'ownershipRecords',
    'ownershipOccurrences', 'ownershipSha256', 'overlayPaths', 'overlaySha256', 'overlayLedger',
  ], 'R12B predecessor');
  exact(value.predecessor.phase, 'R12A', 'R12B predecessor phase');
  exactHash(value.predecessor.manifestSha256, R12A_MANIFEST_SHA256, 'R12B predecessor manifest');
  exact(value.predecessor.dependencyRecords, 16, 'R12B predecessor dependency count');
  exactHash(value.predecessor.dependencySha256, DEPENDENCY_SHA256, 'R12B predecessor dependency');
  exact(value.predecessor.ownershipRecords, 385, 'R12B predecessor ownership count');
  exact(value.predecessor.ownershipOccurrences, 781, 'R12B predecessor ownership occurrences');
  exactHash(value.predecessor.ownershipSha256, OWNERSHIP_SHA256, 'R12B predecessor ownership');
  exact(value.predecessor.overlayPaths, 65, 'R12B predecessor overlay count');
  exactHash(value.predecessor.overlaySha256, OVERLAY_SHA256, 'R12B predecessor overlay');
  const ledger = denseArray(value.predecessor.overlayLedger, 'R12B predecessor ledger', 65);
  if (ledger.length !== 65) throw new Error('R12B predecessor ledger count changed');
  const paths = new Set();
  ledger.forEach((row, index) => {
    exactKeys(row, ['status', 'path', 'sha256'], `R12B predecessor row ${index}`);
    if (![' M', ' D', '??'].includes(row.status)) throw new Error('R12B predecessor row status changed');
    safeRelative(row.path, `R12B predecessor row ${index} path`);
    if (paths.has(row.path)) throw new Error('R12B predecessor row is duplicated');
    paths.add(row.path);
    if (row.status === ' D' ? row.sha256 !== 'DELETED' : !HASH.test(row.sha256)) throw new Error('R12B predecessor row hash is invalid');
  });
  const serialized = ledger.map((row) => `${row.status}|${row.path}|${row.sha256}`).join('\n');
  if (sha256(Buffer.from(serialized, 'utf8')) !== OVERLAY_SHA256) throw new Error('R12B predecessor ledger fingerprint changed');

  exactKeys(value.stages, STAGE_NAMES, 'R12B stages');
  const expectedStages = {
    design: [[], 16],
    'planning-public': [[7, 8, 9, 11, 18], 11],
    strict: [[7, 8, 9, 11, 18, 21, 22], 9],
  };
  for (const stage of STAGE_NAMES) {
    exactKeys(value.stages[stage], ['retiredDependencyIds', 'dependencyRecords'], `R12B ${stage} stage`);
    if (JSON.stringify(value.stages[stage].retiredDependencyIds) !== JSON.stringify(expectedStages[stage][0])) throw new Error(`R12B ${stage} retirements changed`);
    exact(value.stages[stage].dependencyRecords, expectedStages[stage][1], `R12B ${stage} dependency count`);
  }

  const records = denseArray(value.dependencyRecords, 'R12B dependency records', 7);
  if (records.length !== 7) throw new Error('R12B dependency record count changed');
  records.forEach(validateDependencyRecord);
  if (JSON.stringify(records.map((record) => record.id)) !== '[7,8,9,11,18,21,22]') throw new Error('R12B dependency record IDs changed');
  const expectedPairs = [
    ['src/dashboard/dashboard.contracts.ts', 'src/wedding-plans/wedding-location.ts'],
    ['src/dashboard/dashboard.service.ts', 'src/wedding-plans/wedding-location.ts'],
    ['src/marketplace/marketplace.presenter.ts', 'src/wedding-plans/wedding-location.ts'],
    ['src/marketplace/marketplace.service.ts', 'src/wedding-plans/wedding-location.ts'],
    ['src/provider-dashboard/provider-dashboard.service.ts', 'src/wedding-plans/wedding-location.ts'],
    ['src/onboarding/dto/import-local-plan.dto.ts', 'src/guests/dto/create-guest.dto.ts'],
    ['src/onboarding/dto/import-local-plan.dto.ts', 'src/tasks/dto/create-task.dto.ts'],
  ];
  if (JSON.stringify(records.map((record) => [record.from, record.to])) !== JSON.stringify(expectedPairs)) throw new Error('R12B dependency inventory changed');
  const expectedUnresolved = [
    '../wedding-plans/wedding-location', '../wedding-plans/wedding-location',
    '../wedding-plans/wedding-location', '../wedding-plans/wedding-location',
    '../wedding-plans/wedding-location', '../../guests/dto/create-guest.dto',
    '../../tasks/dto/create-task.dto',
  ];
  const expectedRules = [
    'context-insights-cross-context', 'context-insights-cross-context',
    'context-marketplace-cross-context', 'context-marketplace-cross-context',
    'context-marketplace-cross-context', 'context-planning-cross-context',
    'context-planning-cross-context',
  ];
  if (JSON.stringify(records.map((record) => record.unresolvedTo)) !== JSON.stringify(expectedUnresolved)
    || JSON.stringify(records.map((record) => record.rule.name)) !== JSON.stringify(expectedRules)) throw new Error('R12B dependency details changed');

  exactKeys(value.locationMove, ['from', 'to', 'sourceSha256', 'targetSha256'], 'R12B location move');
  exact(value.locationMove.from, 'backend/src/wedding-plans/wedding-location.ts', 'R12B location source');
  exact(value.locationMove.to, 'backend/src/modules/planning/public/wedding-location.ts', 'R12B location target');
  exactHash(value.locationMove.sourceSha256, '7836f0cf91b07f970e947684e1c382fca97b42d8edeed57ee1563fbe556ac764', 'R12B location source');
  exactHash(value.locationMove.targetSha256, value.locationMove.sourceSha256, 'R12B location target');

  const consumers = denseArray(value.locationConsumers, 'R12B location consumers', 7);
  if (consumers.length !== 7) throw new Error('R12B location consumer count changed');
  const expectedConsumerPaths = [
    'backend/src/dashboard/dashboard.contracts.ts', 'backend/src/dashboard/dashboard.service.ts',
    'backend/src/marketplace/marketplace.presenter.ts', 'backend/src/marketplace/marketplace.service.ts',
    'backend/src/provider-dashboard/provider-dashboard.service.ts', 'backend/src/wedding-plans/wedding-plans.service.ts',
    'backend/test/backend-support.test.ts',
  ];
  const expectedConsumerOldModules = [
    '../wedding-plans/wedding-location', '../wedding-plans/wedding-location',
    '../wedding-plans/wedding-location', '../wedding-plans/wedding-location',
    '../wedding-plans/wedding-location', './wedding-location',
    '../src/wedding-plans/wedding-location',
  ];
  const expectedConsumerNewModules = [
    '../modules/planning/public/wedding-location', '../modules/planning/public/wedding-location',
    '../modules/planning/public/wedding-location', '../modules/planning/public/wedding-location',
    '../modules/planning/public/wedding-location', '../modules/planning/public/wedding-location',
    '../src/modules/planning/public/wedding-location',
  ];
  const expectedConsumerHashes = [
    'f637cbeac2027fc735233a15f2df36f91a7c61d861893ba2960235ac2cf9dbb6',
    'c865b51880d1060bb1b84095f12aeaa50e41cd1636da267253c34a9b24414e97',
    'c67f930f50bbac4524616aa9a1981a8d13a8854f1e1ce531f80bf8975c48dc85',
    '51d5f6412c10763bd11b60540203d59fac77e594edaf9de24b376f48e22721a1',
    '44ce4ac70168b49bfe8f49b8c047d1ea888d74b8078a49f46d13b85cf56a46e8',
    '43cee77072074d9227ae3359488b8d6c21b74d6f5c4db1039fe0c7966ce0a777',
    '8dc46754c9d8982372d9f4bcd6a62a9427cf49e519a994c9bd6dd63eb5b6e834',
  ];
  consumers.forEach((consumer, index) => {
    exactKeys(consumer, ['path', 'oldModule', 'newModule', 'entrySha256'], `R12B consumer ${index}`);
    exact(consumer.path, expectedConsumerPaths[index], `R12B consumer ${index} path`);
    safeRelative(consumer.path, `R12B consumer ${index} path`);
    exact(consumer.oldModule, expectedConsumerOldModules[index], `R12B consumer ${index} old module`);
    exact(consumer.newModule, expectedConsumerNewModules[index], `R12B consumer ${index} new module`);
    exactHash(consumer.entrySha256, expectedConsumerHashes[index], `R12B consumer ${index} entry`);
  });

  const dtos = denseArray(value.dtoReexpressions, 'R12B DTO reexpressions', 2);
  if (dtos.length !== 2) throw new Error('R12B DTO reexpression count changed');
  const dtoExpected = [
    ['backend/src/tasks/dto/create-task.dto.ts', 'backend/src/onboarding/dto/import-local-task.dto.ts', 'CreateTaskDto', 'ImportLocalTaskDto', '9960bc6d618a5f3cb03a7491375842ab73e4fe2e9c4db884b3f24743b0745e6a', 'e7a74a721f87e17a08ecf2a0210fb5f14874e9f371f3a16ea1c862402098b189'],
    ['backend/src/guests/dto/create-guest.dto.ts', 'backend/src/onboarding/dto/import-local-guest.dto.ts', 'CreateGuestDto', 'ImportLocalGuestDto', '3efce4297de98e74a80e0158d5b005172728a32def420bc7de3a3ed4ee1068a6', 'cfeab752387affdb8c55f61431ad3e08a8016258877f83c619c71bac22e43582'],
  ];
  dtos.forEach((dto, index) => {
    exactKeys(dto, ['from', 'to', 'oldClass', 'newClass', 'sourceSha256', 'targetSha256'], `R12B DTO ${index}`);
    if (JSON.stringify(Object.values(dto)) !== JSON.stringify(dtoExpected[index])) throw new Error(`R12B DTO ${index} changed`);
  });

  const tests = denseArray(value.behavioralTests, 'R12B behavioral tests', 8);
  if (tests.length !== 2) throw new Error('R12B behavioral test inventory changed');
  exactKeys(tests[0], ['path', 'entrySha256', 'oldModule', 'newModule'], 'R12B location behavior test');
  exactKeys(tests[1], ['path', 'entrySha256', 'purpose'], 'R12B DTO behavior test');
  exact(tests[0].path, 'backend/test/backend-support.test.ts', 'R12B location behavior test path');
  exactHash(tests[0].entrySha256, '8dc46754c9d8982372d9f4bcd6a62a9427cf49e519a994c9bd6dd63eb5b6e834', 'R12B location behavior test entry');
  exact(tests[0].oldModule, '../src/wedding-plans/wedding-location', 'R12B location behavior test old module');
  exact(tests[0].newModule, '../src/modules/planning/public/wedding-location', 'R12B location behavior test new module');
  exact(tests[1].path, 'backend/test/import-local-plan-dto-contract.test.ts', 'R12B DTO behavior test path');
  if (value.stage === 'strict') {
    if (!HASH.test(tests[1].entrySha256)) throw new Error('R12B DTO behavior test strict hash is invalid');
  } else if (tests[1].entrySha256 !== null) throw new Error('R12B future behavior test hash must be null before strict');
  exact(tests[1].purpose, 'onboarding-local-dto-parity', 'R12B DTO behavior test purpose');

  const protectedPaths = denseArray(value.protectedPaths, 'R12B protected paths', 16);
  const expectedProtected = ['backend/package-lock.json', 'backend/architecture/ownership-baseline.json', 'backend/prisma', 'mobile', 'admin-web', 'deploy'];
  if (JSON.stringify(protectedPaths) !== JSON.stringify(expectedProtected)) throw new Error('R12B protected paths changed');
  protectedPaths.forEach((item) => safeRelative(item, 'R12B protected path'));
  validateApprovedSecurityPrerequisiteContract(value.approvedSecurityPrerequisite);

  const inverses = denseArray(value.inverseTransforms, 'R12B inverse transforms', 25);
  if (inverses.length !== 25 || JSON.stringify(inverses.map((item) => item.path)) !== JSON.stringify(INVERSE_PATHS)) throw new Error('R12B inverse transform registry changed');
  const inverseSeen = new Set();
  inverses.forEach((inverse, index) => {
    safeRelative(inverse.path, `R12B inverse ${index} path`);
    if (inverseSeen.has(inverse.path)) throw new Error('R12B inverse transform is duplicated');
    inverseSeen.add(inverse.path);
    const ledgerRow = ledger.find((row) => row.path === inverse.path);
    if (!ledgerRow || ledgerRow.sha256 !== inverse.entrySha256) throw new Error('R12B inverse entry hash changed');
    exact(inverse.kind, INVERSE_KINDS[index], `R12B inverse ${index} kind`);
    if (inverse.kind === 'documentation-transition') {
      exactKeys(inverse, ['path', 'entrySha256', 'kind', 'candidateSha256', 'activatedSha256'], `R12B inverse ${index}`);
      if (inverse.candidateSha256 !== null && !HASH.test(inverse.candidateSha256)) throw new Error('R12B candidate hash is invalid');
      if (inverse.activatedSha256 !== null && !HASH.test(inverse.activatedSha256)) throw new Error('R12B activated hash is invalid');
    } else {
      if (!['exact-text-rewrite', 'dependency-subtraction-reinsertion', 'package-script-projection', 'bounded-hunk-replay', 'one-to-one-move'].includes(inverse.kind)) throw new Error('R12B inverse transform kind is invalid');
      exactKeys(inverse, ['path', 'entrySha256', 'kind', 'payload', 'intendedFinalSha256'], `R12B inverse ${index}`);
      plainObject(inverse.payload, `R12B inverse ${index} payload`);
      if (inverse.kind === 'dependency-subtraction-reinsertion') {
        exactKeys(inverse.payload, ['retiredDependencyIds', 'records'], `R12B inverse ${index} payload`);
        const expectedRetirementIds = value.stage === 'strict'
          ? [7, 8, 9, 11, 18, 21, 22]
          : [7, 8, 9, 11, 18];
        if (JSON.stringify(inverse.payload.retiredDependencyIds) !== JSON.stringify(expectedRetirementIds)) throw new Error('R12B dependency inverse payload changed');
        const records = denseArray(inverse.payload.records, `R12B inverse ${index} records`, 7);
        if (records.length !== expectedRetirementIds.length) throw new Error('R12B dependency inverse records changed');
        const ordinals = new Set();
        records.forEach((item, recordIndex) => {
          exactKeys(item, ['ordinal', 'record'], `R12B inverse ${index} record ${recordIndex}`);
          safeInteger(item.ordinal, `R12B inverse ${index} ordinal`);
          if (ordinals.has(item.ordinal)) throw new Error('R12B dependency inverse ordinal duplicated');
          ordinals.add(item.ordinal);
          validateDependencyRecord(item.record, recordIndex, false);
          const expected = value.dependencyRecords.find((record) => record.id === expectedRetirementIds[recordIndex]);
          const { id: ignored, ...withoutId } = expected;
          assert.deepStrictEqual(item.record, withoutId);
          exact(item.ordinal, [0, 1, 2, 4, 11, 14, 15][recordIndex], `R12B inverse ${index} record ${recordIndex} ordinal`);
        });
      } else if (inverse.kind === 'package-script-projection') {
        exactKeys(inverse.payload, ['script', 'aggregate', 'rewrites'], `R12B inverse ${index} payload`);
        exact(inverse.payload.script, 'architecture:r12b', 'R12B package inverse script');
        exact(inverse.payload.aggregate, 'architecture', 'R12B package inverse aggregate');
        const rewrites = denseArray(inverse.payload.rewrites, `R12B package inverse rewrites`, 16);
        if (!rewrites.length) throw new Error('R12B package inverse rewrites are empty');
        rewrites.forEach((rewrite, rewriteIndex) => {
          exactKeys(rewrite, ['old', 'new', 'occurrences'], `R12B package rewrite ${rewriteIndex}`);
          if (typeof rewrite.old !== 'string' || typeof rewrite.new !== 'string' || rewrite.old === rewrite.new) throw new Error('R12B package rewrite is invalid');
          exact(rewrite.occurrences, 1, `R12B package rewrite ${rewriteIndex} occurrences`);
        });
      } else if (inverse.kind === 'exact-text-rewrite') {
        exactKeys(inverse.payload, ['old', 'new', 'occurrences'], `R12B inverse ${index} payload`);
        exact(inverse.payload.old, '../wedding-plans/wedding-location', 'R12B text inverse old value');
        exact(inverse.payload.new, '../modules/planning/public/wedding-location', 'R12B text inverse new value');
        exact(inverse.payload.occurrences, 1, 'R12B text inverse occurrence count');
      } else if (inverse.kind === 'bounded-hunk-replay') {
        validateR12bHunkPayload(inverse);
      }
      if (value.stage === 'design') {
        if (inverse.intendedFinalSha256 !== null) throw new Error('R12B design inverse final hash must be unregistered');
      } else if (inverse.intendedFinalSha256 !== null && !HASH.test(inverse.intendedFinalSha256)) throw new Error('R12B inverse final hash is invalid');
    }
  });

  validateR12bDocumentationTransitions(value);
  return deepFreeze(structuredClone(value));
}

function dependencyKey(record) {
  return [record.rule && record.rule.name, record.from, record.to].join('|');
}

function expectedR12bDependencyRecords(r12aRecords, manifest) {
  const checked = validateR12bManifest(manifest);
  const input = denseArray(r12aRecords, 'R12A dependency records', 128);
  if (input.length !== 16 || sha256(Buffer.from(JSON.stringify(input), 'utf8')) !== R12A_SEMANTIC_DEPENDENCY_SHA256) throw new Error('R12A dependency authority drifted');
  const retiredIds = new Set(checked.stages[checked.stage].retiredDependencyIds);
  const retired = new Map(checked.dependencyRecords.filter((record) => retiredIds.has(record.id)).map((record) => [dependencyKey(record), record]));
  const seen = new Set();
  const result = input.filter((record) => {
    const expected = retired.get(dependencyKey(record));
    if (!expected) return true;
    const { id: ignored, ...withoutId } = expected;
    assert.deepStrictEqual(record, withoutId);
    if (seen.has(dependencyKey(record))) throw new Error('R12B dependency retirement is duplicated');
    seen.add(dependencyKey(record));
    return false;
  });
  if (seen.size !== retired.size || result.length !== checked.stages[checked.stage].dependencyRecords) throw new Error('R12B dependency projection is invalid');
  return deepFreeze(result.map((record) => ({ ...record })));
}

function expectedR12bSuccessorDependencyRecords(r12aRecords, manifest, { repositoryRoot, actualRecords } = {}) {
  const r12bRecords = expectedR12bDependencyRecords(r12aRecords, manifest);
  if (typeof repositoryRoot !== 'string' || !Array.isArray(actualRecords)) return r12bRecords;
  const successorPath = inspectPlainFile(repositoryRoot, 'backend/architecture/r12c-zero-cross-context-dependencies.json', false);
  if (!successorPath) return r12bRecords;
  const r12c = require('./r12c-zero-cross-context-dependencies-scan.cjs');
  const successor = r12c.validateR12cManifest(JSON.parse(fs.readFileSync(successorPath, 'utf8')));
  const predecessorBytes = fs.readFileSync(inspectPlainFile(repositoryRoot, MANIFEST_PATH));
  if (successor.predecessor.manifestSha256 !== sha256(predecessorBytes)) throw new Error('R12C predecessor manifest fingerprint changed');
  assert.deepStrictEqual(successor.dependencyRecords.map(({ id: ignored, ...row }) => row), r12bRecords);
  return r12c.expectedR12cDependencyRecords(actualRecords, successor);
}

function validateR12bPredecessorOverlay({ manifest, actualLedger } = {}) {
  const checked = validateR12bManifest(manifest);
  const actual = denseArray(actualLedger, 'R12B actual predecessor ledger', 65);
  if (actual.length !== 65) throw new Error('R12B actual predecessor ledger count changed');
  actual.forEach((row, index) => {
    exactKeys(row, ['status', 'path', 'sha256'], `R12B actual predecessor row ${index}`);
    assert.deepStrictEqual(row, checked.predecessor.overlayLedger[index]);
  });
  const serialized = actual.map((row) => `${row.status}|${row.path}|${row.sha256}`).join('\n');
  if (sha256(Buffer.from(serialized, 'utf8')) !== OVERLAY_SHA256) throw new Error('R12B actual predecessor fingerprint changed');
  return true;
}

function validateR12bPathBytes({ manifest, repositoryRoot, statusRows, readWorkingFile, pathExists } = {}) {
  const contracts = validateR12bPathContracts(manifest.r12bPaths);
  const rows = statusRows || gitStatus(repositoryRoot);
  const statusMap = new Map(rows.map((row) => [row.path, row.status]));
  const read = (relative) => {
    const injected = typeof readWorkingFile === 'function' ? readWorkingFile(relative) : null;
    if (injected !== null && injected !== undefined) return Buffer.isBuffer(injected) ? injected : Buffer.from(injected);
    const file = inspectPlainFile(repositoryRoot, relative);
    return fs.readFileSync(file);
  };
  const exists = (relative) => typeof pathExists === 'function'
    ? Boolean(pathExists(relative))
    : fs.existsSync(path.join(repositoryRoot, ...relative.split('/')));
  contracts.forEach((contract) => {
    if (statusMap.get(contract.path) !== contract.status) throw new Error(`R12B-only path status changed: ${contract.path}`);
    if (!exists(contract.path)) throw new Error(`R12B-only path is missing: ${contract.path}`);
    const bytes = read(contract.path);
    if (contract.hashMode === 'raw') {
      if (sha256(bytes) !== contract.sha256) throw new Error(`R12B-only path hash changed: ${contract.path}`);
      return;
    }
    const needle = Buffer.from(`"normalizedSelfSha256": "${contract.normalizedSelfSha256}"`, 'utf8');
    let occurrences = 0;
    let offset = 0;
    while ((offset = bytes.indexOf(needle, offset)) >= 0) {
      occurrences += 1;
      offset += needle.length;
    }
    if (occurrences !== 1) throw new Error('R12B normalized-self contract requires exactly one raw occurrence');
    const normalized = Buffer.from(bytes);
    normalized.set(Buffer.from('0'.repeat(64), 'utf8'), normalized.indexOf(needle) + needle.indexOf(Buffer.from(contract.normalizedSelfSha256, 'utf8')));
    if (sha256(normalized) !== contract.normalizedSelfSha256) throw new Error('R12B normalized-self contract hash changed');
  });
  return true;
}

function inspectPlainFile(root, relative, required = true) {
  safeRelative(relative, 'R12B file path');
  const rootReal = fs.realpathSync.native(root);
  let current = root;
  for (const part of relative.split('/')) {
    current = path.join(current, part);
    if (!fs.existsSync(current)) {
      if (required) throw new Error(`R12B file is missing: ${relative}`);
      return null;
    }
    const stat = fs.lstatSync(current);
    if (stat.isSymbolicLink()) throw new Error(`R12B file contains a symlink or reparse point: ${relative}`);
  }
  const real = fs.realpathSync.native(current);
  const escaped = path.relative(rootReal, real);
  if (escaped.startsWith('..') || path.isAbsolute(escaped)) throw new Error('R12B file escapes repository');
  if (!fs.lstatSync(current).isFile()) throw new Error('R12B path is not a plain file');
  return current;
}

// Working-tree overlay against the immutable base commit. The ' M' / ' D' / '??'
// vocabulary is unchanged; it now describes the content delta from the base,
// which is identical whether that delta is committed or not.
function gitStatus(repositoryRoot) {
  return identity.workingTreeInventory(repositoryRoot, BASE_COMMIT);
}

function verifyApprovedSecurityPrerequisite({ repositoryRoot, manifest, statusRows: suppliedStatusRows, readWorkingFile, pathExists } = {}) {
  if (typeof repositoryRoot !== 'string' || !path.isAbsolute(repositoryRoot)) {
    throw new Error('R12B approved security prerequisite repository root must be absolute');
  }
  const checked = validateR12bManifest(manifest);
  const receipt = validateApprovedSecurityPrerequisiteContract(checked.approvedSecurityPrerequisite);
  if (!checked.protectedPaths.includes(receipt.path)) {
    throw new Error('R12B approved security prerequisite must remain protected');
  }
  const statusRows = suppliedStatusRows || gitStatus(repositoryRoot);
  denseArray(statusRows, 'R12B approved security prerequisite status rows', 256);
  const statusMap = new Map(statusRows.map((row) => [row.path, row.status]));
  if (statusMap.size !== statusRows.length) {
    throw new Error('R12B approved security prerequisite status rows are duplicated');
  }
  if (statusMap.get(receipt.path) !== receipt.status) {
    throw new Error('R12B approved security prerequisite status changed');
  }
  const exists = typeof pathExists === 'function'
    ? Boolean(pathExists(receipt.path))
    : fs.existsSync(path.join(repositoryRoot, ...receipt.path.split('/')));
  if (!exists) throw new Error('R12B approved security prerequisite lock is missing');
  const injected = typeof readWorkingFile === 'function' ? readWorkingFile(receipt.path) : null;
  const lockBytes = injected !== null && injected !== undefined
    ? (Buffer.isBuffer(injected) ? injected : Buffer.from(injected))
    : fs.readFileSync(inspectPlainFile(repositoryRoot, receipt.path));
  if (sha256(lockBytes) !== receipt.newRawSha256) {
    throw new Error('R12B approved security prerequisite raw lock hash changed');
  }
  let packageLock;
  try {
    packageLock = JSON.parse(lockBytes.toString('utf8'));
    deepData(packageLock, 'R12B approved security prerequisite lock');
  } catch {
    throw new Error('R12B approved security prerequisite lock JSON changed');
  }
  exact(packageLock.lockfileVersion, receipt.lockfileVersion, 'R12B approved security prerequisite live lockfile version');
  const packages = plainObject(packageLock.packages, 'R12B approved security prerequisite packages');
  const qsPaths = Object.keys(packages).filter(
    (packagePath) => packagePath === 'node_modules/qs' || packagePath.endsWith('/node_modules/qs'),
  );
  if (JSON.stringify(qsPaths) !== JSON.stringify([receipt.package.path])) {
    throw new Error('R12B approved security prerequisite qs copy count changed');
  }
  const qsPackage = plainObject(packages[receipt.package.path], 'R12B approved qs package');
  exact(qsPackage.version, receipt.package.version, 'R12B approved qs live version');
  exact(qsPackage.resolved, receipt.package.resolved, 'R12B approved qs live resolution');
  exact(qsPackage.integrity, receipt.package.integrity, 'R12B approved qs live integrity');
  for (const parent of receipt.parentRanges) {
    const parentPackage = plainObject(packages[parent.path], `R12B approved qs parent ${parent.path}`);
    const dependencies = plainObject(parentPackage.dependencies, `R12B approved qs parent dependencies ${parent.path}`);
    exact(dependencies[parent.dependency], parent.range, `R12B approved qs parent range ${parent.path}`);
  }
  const packageRelative = 'backend/package.json';
  const packageInjected = typeof readWorkingFile === 'function' ? readWorkingFile(packageRelative) : null;
  const packageBytes = packageInjected !== null && packageInjected !== undefined
    ? (Buffer.isBuffer(packageInjected) ? packageInjected : Buffer.from(packageInjected))
    : fs.readFileSync(inspectPlainFile(repositoryRoot, packageRelative));
  const packageInverse = checked.inverseTransforms.find((item) => item.path === packageRelative);
  if (!packageInverse || packageInverse.kind !== 'package-script-projection') {
    throw new Error('R12B approved security prerequisite package projection is missing');
  }
  let securityPackageBytes = packageBytes;
  const packageHash = sha256(packageBytes);
  if (packageHash === packageInverse.entrySha256) {
    let projected = packageBytes.toString('utf8');
    for (const rewrite of packageInverse.payload.rewrites) {
      projected = replaceCounted(
        projected,
        rewrite.old,
        rewrite.new,
        rewrite.occurrences,
        'R12B approved security prerequisite package projection',
      );
    }
    securityPackageBytes = Buffer.from(projected, 'utf8');
    if (sha256(securityPackageBytes) !== packageInverse.intendedFinalSha256) {
      throw new Error('R12B approved security prerequisite package final hash changed');
    }
  } else if (packageHash !== packageInverse.intendedFinalSha256) {
    throw new Error('R12B approved security prerequisite package hash changed');
  }
  let packageJson;
  try {
    packageJson = JSON.parse(securityPackageBytes.toString('utf8'));
  } catch {
    throw new Error('R12B approved security prerequisite package JSON changed');
  }
  try {
    prismaSecurity.validatePackageGraph(
      prismaSecurity.projectR12BArchitectureScripts(packageJson),
      packageLock,
    );
  } catch {
    throw new Error('R12B approved security prerequisite Prisma graph changed');
  }
  return deepFreeze({
    approvedSecurityPrerequisite: 1,
    unapprovedProtected: 0,
    path: receipt.path,
    oldRawSha256: receipt.oldRawSha256,
    newRawSha256: receipt.newRawSha256,
    qsVersion: receipt.package.version,
  });
}

function replaceCounted(source, oldValue, newValue, occurrences, label) {
  let count = 0;
  let offset = 0;
  while ((offset = source.indexOf(oldValue, offset)) >= 0) {
    count += 1;
    offset += oldValue.length;
  }
  if (count !== occurrences) throw new Error(`${label} occurrence count changed`);
  return source.split(oldValue).join(newValue);
}

function verifyProductFreshnessPrerequisite({ repositoryRoot, documentationStage, statusMap, readWorkingFile } = {}) {
  const allowed = PRODUCT_FRESHNESS_STAGES.includes(documentationStage);
  const currentStatus = statusMap.get(PRODUCT_FRESHNESS_PATH);
  if (allowed) {
    if (currentStatus !== PRODUCT_FRESHNESS_STATUS) {
      throw new Error('R12B PRODUCT freshness prerequisite status changed');
    }
  } else if (currentStatus !== undefined) {
    throw new Error('R12B PRODUCT freshness prerequisite is forbidden at this documentation stage');
  }

  const injected = typeof readWorkingFile === 'function'
    ? readWorkingFile(PRODUCT_FRESHNESS_PATH)
    : null;
  const bytes = injected !== null && injected !== undefined
    ? (Buffer.isBuffer(injected) ? injected : Buffer.from(injected))
    : fs.readFileSync(inspectPlainFile(repositoryRoot, PRODUCT_FRESHNESS_PATH));
  const expectedHash = allowed ? PRODUCT_FRESHNESS_NEW_SHA256 : PRODUCT_FRESHNESS_OLD_SHA256;
  if (sha256(bytes) !== expectedHash) {
    throw new Error('R12B PRODUCT freshness prerequisite raw hash changed');
  }
  if (!allowed) return deepFreeze({ path: PRODUCT_FRESHNESS_PATH });

  const text = bytes.toString('utf8');
  if (!Buffer.from(text, 'utf8').equals(bytes)) {
    throw new Error('R12B PRODUCT freshness prerequisite must remain exact UTF-8');
  }
  const reconstructed = Buffer.from(replaceCounted(
    text,
    PRODUCT_FRESHNESS_NEW_DATE,
    PRODUCT_FRESHNESS_OLD_DATE,
    1,
    'R12B PRODUCT freshness prerequisite date',
  ), 'utf8');
  if (sha256(reconstructed) !== PRODUCT_FRESHNESS_OLD_SHA256) {
    throw new Error('R12B PRODUCT freshness prerequisite contains a semantic change');
  }
  return deepFreeze({ path: PRODUCT_FRESHNESS_PATH });
}

function applyInverseTransform(bytes, inverse) {
  const text = bytes.toString('utf8');
  if (inverse.kind === 'exact-text-rewrite') {
    return Buffer.from(replaceCounted(text, inverse.payload.new, inverse.payload.old, inverse.payload.occurrences, `R12B inverse ${inverse.path}`), 'utf8');
  }
  if (inverse.kind === 'package-script-projection') {
    let result = text;
    for (const rewrite of [...inverse.payload.rewrites].reverse()) {
      result = replaceCounted(result, rewrite.new, rewrite.old, rewrite.occurrences, `R12B package inverse ${inverse.path}`);
    }
    return Buffer.from(result, 'utf8');
  }
  if (inverse.kind === 'dependency-subtraction-reinsertion') {
    const records = JSON.parse(text);
    for (const item of [...inverse.payload.records].sort((left, right) => left.ordinal - right.ordinal)) records.splice(item.ordinal, 0, item.record);
    return Buffer.from(`${JSON.stringify(records, null, 2)}\n`, 'utf8');
  }
  if (inverse.kind === 'bounded-hunk-replay') return applyR12bHunkTransform({ bytes, inverse, direction: 'inverse' });
  throw new Error(`R12B inverse transform cannot reconstruct ${inverse.path}`);
}

function applyR12bHunkTransform({ bytes, inverse, direction }) {
  const payload = validateR12bHunkPayload(inverse);
  if (!payload || !Buffer.isBuffer(bytes)
      || !['forward', 'inverse'].includes(direction)) {
    throw new Error('R12B hunk replay input is invalid');
  }
  const utf8 = (value) => {
    if (!Buffer.from(value.toString('utf8'), 'utf8').equals(value)) {
      throw new Error('R12B hunk replay requires exact UTF-8');
    }
    return value;
  };
  utf8(bytes);
  let delta = 0;
  const operations = payload.hunks.map((hunk) => {
    const before = Buffer.from(hunk.before, 'utf8');
    const after = Buffer.from(hunk.after, 'utf8');
    const liveOffset = hunk.offset + delta;
    delta += after.length - before.length;
    return direction === 'forward'
      ? { offset: hunk.offset, expected: before, replacement: after }
      : { offset: liveOffset, expected: after, replacement: before };
  });
  const expectedLength = direction === 'forward'
    ? payload.entryByteLength : payload.entryByteLength + delta;
  const expectedHash = direction === 'forward'
    ? inverse.entrySha256 : inverse.intendedFinalSha256;
  if (bytes.length !== expectedLength || sha256(bytes) !== expectedHash) {
    throw new Error('R12B hunk replay input hash or length changed');
  }
  for (const op of operations) {
    if (!bytes.subarray(op.offset, op.offset + op.expected.length)
        .equals(op.expected)) throw new Error('R12B hunk slice changed');
  }
  let result = bytes;
  for (const op of [...operations].reverse()) {
    result = Buffer.concat([
      result.subarray(0, op.offset), op.replacement,
      result.subarray(op.offset + op.expected.length),
    ]);
  }
  utf8(result);
  const resultHash = direction === 'forward'
    ? inverse.intendedFinalSha256 : inverse.entrySha256;
  if (sha256(result) !== resultHash) throw new Error('R12B hunk replay result hash changed');
  return result;
}

function projectR12bWorkingTreeToPredecessor({ repositoryRoot, manifest, statusRows: suppliedStatusRows, readWorkingFile, pathExists } = {}) {
  if (typeof repositoryRoot !== 'string' || !path.isAbsolute(repositoryRoot)) throw new Error('R12B repository root must be absolute');
  const checked = validateR12bManifest(manifest);
  if (typeof readWorkingFile !== 'function' && closure.readClosure(repositoryRoot, checked.repository.baseCommit)) {
    throw new Error('R12B is closed: the predecessor projection is historical and is verified at the recorded lineage commit');
  }
  validateR12bDocumentationTransitions(checked);
  const successorPath = 'backend/architecture/r12c-zero-cross-context-dependencies.json';
  // Injected no-successor fixtures never consult the live successor. A present
  // successor must validate and reconstruct the exact activated R12B bytes;
  // failure is never converted into historical fallback or a scope allowance.
  const successorExists = typeof pathExists === 'function'
    ? pathExists(successorPath) : Boolean(inspectPlainFile(repositoryRoot, successorPath, false));
  if (successorExists) {
    if (checked.stage !== 'strict' || checked.documentationStage !== 'activated'
        || checked.documentationTransitions.length !== 4) throw new Error('R12C requires the activated R12B predecessor');
    const successorBytes = typeof readWorkingFile === 'function'
      ? readWorkingFile(successorPath) : fs.readFileSync(inspectPlainFile(repositoryRoot, successorPath));
    if (!Buffer.isBuffer(successorBytes)) throw new Error('R12C successor manifest bytes are missing');
    const r12c = require('./r12c-zero-cross-context-dependencies-scan.cjs');
    const projection = r12c.projectR12cWorkingTreeToPredecessor({
      repositoryRoot, manifest: JSON.parse(successorBytes.toString('utf8')),
      statusRows: suppliedStatusRows, readWorkingFile, pathExists,
    });
    return projectR12bWorkingTreeToPredecessor({ repositoryRoot, manifest: checked, ...projection });
  }
  const statusRows = suppliedStatusRows || gitStatus(repositoryRoot);
  denseArray(statusRows, 'R12B working tree status rows', 256);
  const finalReportRows = statusRows.filter((row) => row.path === FINAL_REPORT_PATH);
  if (checked.documentationStage === 'activated') {
    if (finalReportRows.length !== 1) throw new Error('R12B activated final report must have exactly one status row');
    if (finalReportRows[0].status !== '??') throw new Error('R12B activated final report status must be exactly ??');
    inspectPlainFile(repositoryRoot, FINAL_REPORT_PATH);
  } else if (finalReportRows.length !== 0) {
    throw new Error('R12B final report is forbidden before documentation stage activated');
  }
  const statusMap = new Map(statusRows.map((row) => [row.path, row.status]));
  if (statusMap.size !== statusRows.length) throw new Error('R12B working tree status rows are duplicated');
  const read = (relative) => {
    const injected = typeof readWorkingFile === 'function' ? readWorkingFile(relative) : null;
    if (injected !== null && injected !== undefined) return Buffer.isBuffer(injected) ? injected : Buffer.from(injected);
    const file = inspectPlainFile(repositoryRoot, relative);
    return fs.readFileSync(file);
  };
  const exists = (relative) => typeof pathExists === 'function'
    ? Boolean(pathExists(relative))
    : fs.existsSync(path.join(repositoryRoot, ...relative.split('/')));
  const securityPrerequisite = verifyApprovedSecurityPrerequisite({
    repositoryRoot,
    manifest: checked,
    statusRows,
    readWorkingFile: read,
    pathExists: exists,
  });
  validateR12bPathBytes({ manifest: checked, repositoryRoot, statusRows, readWorkingFile: read, pathExists: exists });
  const productFreshness = verifyProductFreshnessPrerequisite({
    repositoryRoot,
    documentationStage: checked.documentationStage,
    statusMap,
    readWorkingFile,
  });
  const ledgerPaths = new Set(checked.predecessor.overlayLedger.map((row) => row.path));
  const stagePaths = new Set(planningPublicPaths(checked));
  for (const row of statusRows) {
    if (row.path === securityPrerequisite.path) continue;
    if (row.path === FINAL_REPORT_PATH) continue;
    if (row.path === productFreshness.path) continue;
    if (!ledgerPaths.has(row.path) && !NEW_R12B_PATHS.has(row.path) && !stagePaths.has(row.path)) throw new Error(`R12B working tree contains an undeclared path: ${row.path}`);
  }
  const documentationByPath = new Map(checked.inverseTransforms.filter((item) => item.kind === 'documentation-transition').map((item) => [item.path, item]));
  const nonDocumentation = [];
  const documentation = [];
  const projected = checked.predecessor.overlayLedger.map((row) => {
    const currentStatus = statusMap.get(row.path);
    if (row.status === ' D') {
      if (currentStatus !== ' D' || exists(row.path)) throw new Error(`R12B deleted predecessor drifted: ${row.path}`);
      return { ...row };
    }
    if (![' M', '??'].includes(currentStatus)) throw new Error(`R12B predecessor status drifted: ${row.path}`);
    if (!exists(row.path)) throw new Error(`R12B predecessor file is missing: ${row.path}`);
    const currentBytes = read(row.path);
    const currentHash = sha256(currentBytes);
    const inverse = checked.inverseTransforms.find((item) => item.path === row.path);
    if (currentHash === row.sha256 && currentStatus === row.status) {
      if (inverse && inverse.kind === 'bounded-hunk-replay' && inverse.intendedFinalSha256 !== null) {
        applyR12bHunkTransform({ bytes: currentBytes, inverse, direction: 'forward' });
      }
      if (inverse && inverse.kind !== 'documentation-transition') nonDocumentation.push({ path: row.path, entrySha256: row.sha256, liveSha256: currentHash, reconstructedSha256: currentHash, entryBytes: currentBytes });
      return { ...row };
    }
    const transform = documentationByPath.get(row.path);
    if (transform) {
      const expected = ['entry', 'candidate-prepared'].includes(checked.documentationStage)
        ? transform.entrySha256
        : ['candidate', 'activation-prepared'].includes(checked.documentationStage)
          ? transform.candidateSha256
          : transform.activatedSha256;
      if (currentHash !== expected || currentStatus !== row.status) throw new Error(`R12B documentation projection drifted: ${row.path}`);
      return { ...row };
    }
    if (!inverse || !inverse.intendedFinalSha256 || currentStatus !== row.status) throw new Error(`R12B predecessor path drifted: ${row.path}`);
    if (currentHash !== inverse.intendedFinalSha256) throw new Error(`R12B predecessor final hash drifted: ${row.path}`);
    const reconstructed = applyInverseTransform(currentBytes, inverse);
    if (sha256(reconstructed) !== row.sha256) throw new Error(`R12B predecessor inverse projection drifted: ${row.path}`);
    nonDocumentation.push({ path: row.path, entrySha256: row.sha256, liveSha256: currentHash, reconstructedSha256: sha256(reconstructed), entryBytes: reconstructed });
    return { ...row };
  });
  validateR12bPredecessorOverlay({ manifest: checked, actualLedger: projected });
  for (const transform of checked.inverseTransforms.filter((item) => item.kind === 'documentation-transition')) {
    const expected = ['entry', 'candidate-prepared'].includes(checked.documentationStage)
      ? transform.entrySha256
      : ['candidate', 'activation-prepared'].includes(checked.documentationStage)
        ? transform.candidateSha256
        : transform.activatedSha256;
    documentation.push({ state: checked.documentationStage, path: transform.path, entrySha256: transform.entrySha256, liveSha256: expected });
  }
  const documentationStates = Object.fromEntries(DOCUMENT_STAGES.map((state) => [state,
    checked.inverseTransforms.filter((item) => item.kind === 'documentation-transition').map((transform) => ({
      path: transform.path,
      entrySha256: transform.entrySha256,
      stateSha256: ['entry', 'candidate-prepared'].includes(state)
        ? transform.entrySha256
        : ['candidate', 'activation-prepared'].includes(state)
          ? transform.candidateSha256
          : transform.activatedSha256,
    })),
  ]));
  Object.defineProperty(projected, 'projectionDetails', {
    enumerable: false,
    value: deepFreeze({ nonDocumentation: nonDocumentation.map((item) => ({ ...item })), documentation: documentation.map((item) => ({ ...item })), documentationStates }),
  });
  Object.defineProperty(projected, 'securityPrerequisite', {
    enumerable: false,
    value: securityPrerequisite,
  });
  return deepFreeze(projected);
}

function verifyR12bLocationSourceParity({ source, target, contract } = {}) {
  plainObject(contract, 'R12B location contract');
  if (typeof source !== 'string' && !Buffer.isBuffer(source)) throw new Error('R12B location source is invalid');
  if (typeof target !== 'string' && !Buffer.isBuffer(target)) throw new Error('R12B location target is invalid');
  if (sha256(source) !== contract.sourceSha256 || sha256(target) !== contract.targetSha256 || !Buffer.from(source).equals(Buffer.from(target))) throw new Error('R12B location source parity drift detected');
  return true;
}

function replaceExactlyOnce(source, oldValue, newValue, label) {
  const first = source.indexOf(oldValue);
  if (first < 0 || source.indexOf(oldValue, first + oldValue.length) >= 0) throw new Error(`${label} occurrence count changed`);
  return source.slice(0, first) + newValue + source.slice(first + oldValue.length);
}

function verifyR12bConsumerParity({ historicalSource, liveSource, contract } = {}) {
  if (typeof historicalSource !== 'string' || typeof liveSource !== 'string') throw new Error('R12B consumer sources must be text');
  if (sha256(Buffer.from(historicalSource)) !== contract.entrySha256) throw new Error('R12B consumer entry hash changed');
  const expected = replaceExactlyOnce(historicalSource, contract.oldModule, contract.newModule, 'R12B consumer rewrite');
  if (liveSource !== expected) throw new Error('R12B consumer parity drift detected');
  return true;
}

function planningPublicPaths(manifest) {
  if (manifest.stage === 'design') return [];
  return [
    manifest.locationMove.from,
    manifest.locationMove.to,
    ...manifest.locationConsumers.map((consumer) => consumer.path),
  ];
}

function readImmutableText(repositoryRoot, revision, relative) {
  return execFileSync('git', ['show', `${revision}:${relative}`], {
    cwd: repositoryRoot,
    encoding: 'utf8',
    windowsHide: true,
  });
}

function walkTypeScriptFiles(root, relative = '') {
  const directory = path.join(root, ...relative.split('/').filter(Boolean));
  const entries = fs.readdirSync(directory, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const next = relative ? `${relative}/${entry.name}` : entry.name;
    if (entry.isDirectory()) files.push(...walkTypeScriptFiles(root, next));
    else if (entry.isFile() && entry.name.endsWith('.ts')) files.push(next);
  }
  return files;
}

function verifyR12bPlanningPublicLayout({ repositoryRoot, manifest, r12aManifest, r12a } = {}) {
  if (manifest.stage === 'design') return true;
  const successorPath = inspectPlainFile(repositoryRoot, 'backend/architecture/r12c-zero-cross-context-dependencies.json', false);
  const successorProjection = successorPath
    ? require('./r12c-zero-cross-context-dependencies-scan.cjs').projectR12cWorkingTreeToPredecessor({
      repositoryRoot,
      manifest: JSON.parse(fs.readFileSync(successorPath, 'utf8')),
    })
    : null;
  const readLayoutFile = (relative) => successorProjection
    ? successorProjection.readWorkingFile(relative)
    : fs.readFileSync(inspectPlainFile(repositoryRoot, relative));
  const layoutPathExists = (relative) => successorProjection
    ? successorProjection.pathExists(relative)
    : Boolean(inspectPlainFile(repositoryRoot, relative, false));
  const legacy = layoutPathExists(manifest.locationMove.from);
  if (legacy) throw new Error('R12B location legacy and target coexist');
  if (!layoutPathExists(manifest.locationMove.to)) throw new Error('R12B location target is missing');
  const historicalLocation = readImmutableText(repositoryRoot, manifest.repository.baseCommit, manifest.locationMove.from);
  verifyR12bLocationSourceParity({
    source: historicalLocation,
    target: readLayoutFile(manifest.locationMove.to),
    contract: manifest.locationMove,
  });

  for (const consumer of manifest.locationConsumers) {
    const live = readLayoutFile(consumer.path).toString('utf8');
    let historical = readImmutableText(repositoryRoot, manifest.repository.baseCommit, consumer.path);
    if (consumer.path === 'backend/src/marketplace/marketplace.service.ts') {
      historical = replaceExactlyOnce(live, consumer.newModule, consumer.oldModule, 'R12B marketplace consumer inverse');
      const r12aConsumer = r12aManifest.consumers.find((item) => item.path === consumer.path);
      if (!r12aConsumer) throw new Error('R12B marketplace R12A consumer contract is missing');
      let r12aHistorical = historical;
      for (const rewrite of r12aConsumer.importRewrites) {
        r12aHistorical = replaceExactlyOnce(r12aHistorical, rewrite.newModule, rewrite.oldModule, 'R12B marketplace R12A provider-rating inverse');
      }
      if (r12aHistorical !== readImmutableText(repositoryRoot, manifest.repository.baseCommit, consumer.path)) {
        throw new Error('R12B marketplace R12A normalization drift detected');
      }
    }
    verifyR12bConsumerParity({ historicalSource: historical, liveSource: live, contract: consumer });
  }

  const allowedConsumers = new Set(manifest.locationConsumers.map((consumer) => consumer.path));
  for (const root of ['backend/src', 'backend/test']) {
    for (const relative of walkTypeScriptFiles(repositoryRoot, root)) {
      const source = fs.readFileSync(inspectPlainFile(repositoryRoot, relative), 'utf8');
      const modules = [...source.matchAll(/(?:from\s*|import\s*\()(['"])([^'"]*wedding-location)\1/gu)].map((match) => match[2]);
      for (const module of modules) {
        if (module.includes('wedding-plans/wedding-location')) throw new Error(`R12B legacy location consumer remains: ${relative}`);
        if (module.includes('modules/planning/public/wedding-location') && !allowedConsumers.has(relative)) {
          throw new Error(`R12B undeclared location consumer: ${relative}`);
        }
      }
    }
  }
  return true;
}

function verifyR12bDtoParity({ source, target, contract } = {}) {
  if (typeof source !== 'string' || typeof target !== 'string') throw new Error('R12B DTO sources must be text');
  if (sha256(Buffer.from(source)) !== contract.sourceSha256) throw new Error('R12B DTO source hash changed');
  const expected = replaceExactlyOnce(source, contract.oldClass, contract.newClass, 'R12B DTO class rewrite');
  if (target !== expected || sha256(Buffer.from(target)) !== contract.targetSha256) throw new Error('R12B DTO parity drift detected');
  return true;
}

function verifyR12bStrictDtoLayout({ repositoryRoot, manifest } = {}) {
  for (const dto of manifest.dtoReexpressions) {
    const source = fs.readFileSync(inspectPlainFile(repositoryRoot, dto.from), 'utf8');
    const target = fs.readFileSync(inspectPlainFile(repositoryRoot, dto.to), 'utf8');
    verifyR12bDtoParity({ source, target, contract: dto });
  }

  const plan = fs.readFileSync(inspectPlainFile(repositoryRoot, 'backend/src/onboarding/dto/import-local-plan.dto.ts'), 'utf8');
  const required = [
    'import { ImportLocalGuestDto } from "./import-local-guest.dto";',
    'import { ImportLocalTaskDto } from "./import-local-task.dto";',
    '@Type(() => ImportLocalTaskDto)',
    'tasks?: ImportLocalTaskDto[];',
    '@Type(() => ImportLocalGuestDto)',
    'guests?: ImportLocalGuestDto[];',
  ];
  for (const value of required) {
    if (plan.split(value).length - 1 !== 1) throw new Error(`R12B onboarding local DTO constructor drifted: ${value}`);
  }
  for (const relative of walkTypeScriptFiles(repositoryRoot, 'backend/src/onboarding')) {
    const source = fs.readFileSync(inspectPlainFile(repositoryRoot, relative), 'utf8');
    if (/(?:from\s*|import\s*\()(['"][^'"]*(?:guests|tasks)\/dto\/[^'"]*['"])/gu.test(source)) {
      throw new Error(`R12B onboarding shared DTO import remains: ${relative}`);
    }
  }
  return true;
}

function assertNoTransitionArtifacts(repositoryRoot) {
  const journal = path.join(repositoryRoot, 'backend', 'architecture', '.r12b-documentation-transition.json');
  if (fs.existsSync(journal)) throw new Error('R12B documentation transition journal remains');
  const targets = [MANIFEST_PATH, ...DOCUMENT_PATHS];
  for (const relative of targets) {
    const target = path.join(repositoryRoot, ...relative.split('/'));
    if (fs.existsSync(`${target}.r12b-documentation.bak`) || fs.existsSync(`${target}.r12b-documentation.tmp`) || fs.existsSync(`${target}.r12b-documentation.restore.tmp`)) {
      throw new Error('R12B documentation transition backup or temporary remains');
    }
  }
}

function versionAtLeast(live, approved) {
  const parse = (value) => {
    const match = /^(\d+)\.(\d+)\.(\d+)$/u.exec(String(value));
    if (!match) throw new Error('R12B closed qs version is not a release version: ' + value);
    return match.slice(1).map(Number);
  };
  const a = parse(live);
  const b = parse(approved);
  for (let index = 0; index < 3; index += 1) if (a[index] !== b[index]) return a[index] > b[index];
  return true;
}

// Closed security prerequisite: the approved qs remediation cannot regress.
// Exactly one qs copy at or above the approved version, and the live package
// graph passes the Prisma security checker through the same projection chain
// its CLI applies (which also pins the lock to the approved lineage).
function verifyR12bClosedSecurityPrerequisite(root, checked) {
  const receipt = validateApprovedSecurityPrerequisiteContract(checked.approvedSecurityPrerequisite);
  const packageLock = JSON.parse(fs.readFileSync(inspectPlainFile(root, receipt.path), 'utf8'));
  const packages = plainObject(packageLock.packages, 'R12B closed lock packages');
  const qsPaths = Object.keys(packages).filter(
    (packagePath) => packagePath === 'node_modules/qs' || packagePath.endsWith('/node_modules/qs'),
  );
  if (JSON.stringify(qsPaths) !== JSON.stringify([receipt.package.path])) throw new Error('R12B closed qs copy count changed');
  const live = plainObject(packages[receipt.package.path], 'R12B closed qs package').version;
  if (!versionAtLeast(live, receipt.package.version)) throw new Error('R12B closed qs version regressed below the approved remediation');
  const packageJson = JSON.parse(fs.readFileSync(inspectPlainFile(root, 'backend/package.json'), 'utf8'));
  prismaSecurity.validatePackageGraph(prismaSecurity.projectR12BArchitectureScripts(packageJson), packageLock);
  return 1;
}

// Closed successor: after the R12C closure the R12B gate proves the live
// invariants R12B established (one Planning public location, no legacy
// consumer, Onboarding-owned DTO re-expressions in parity, the qs security
// prerequisite not regressed, strict successor zero) instead of replaying the
// byte lineage; the lineage is verified at the recorded lineage commit. The
// protected-surface count of the lineage stage has no closed counterpart: the
// package and lock are pinned by the security checker and R5, and every other
// governed file is ordinary reviewed code.
function scanR12bClosed(root, checked) {
  assertNoTransitionArtifacts(root);
  validateR12bDocumentationTransitions(checked);
  if (checked.stage !== 'strict' || checked.documentationStage !== 'activated') throw new Error('R12B closure requires the activated strict stage');
  if (inspectPlainFile(root, checked.locationMove.from, false)) throw new Error('R12B location legacy and target coexist');
  if (!inspectPlainFile(root, checked.locationMove.to, false)) throw new Error('R12B location target is missing');
  const legacyModule = 'wedding-plans/wedding-location';
  for (const scope of ['backend/src', 'backend/test']) {
    for (const relative of walkTypeScriptFiles(root, scope)) {
      const source = fs.readFileSync(inspectPlainFile(root, relative), 'utf8');
      const modules = [...source.matchAll(/(?:from\s*|import\s*\()(['"])([^'"]*wedding-location)\1/gu)].map((match) => match[2]);
      if (modules.some((module) => module.includes(legacyModule))) throw new Error(`R12B legacy location consumer remains: ${relative}`);
    }
  }
  verifyR12bStrictDtoLayout({ repositoryRoot: root, manifest: checked });
  const r12a = require(R12A_SCANNER_PATH);
  const dependency = JSON.parse(r12a.readR12aSuccessorDependencyBytes(root).toString('utf8'));
  if (!Array.isArray(dependency) || dependency.length !== 0) throw new Error('R12B closed successor dependency must be zero');
  const approvedSecurityPrerequisite = verifyR12bClosedSecurityPrerequisite(root, checked);
  const ownership = closure.strictOwnershipCounts(root);
  return deepFreeze({
    ok: true,
    stage: checked.stage,
    closed: true,
    documentationStage: checked.documentationStage,
    receipts: checked.documentationTransitions.length,
    dependencyRecords: 0,
    ownershipRecords: ownership.ownershipRecords,
    ownershipOccurrences: ownership.ownershipOccurrences,
    approvedSecurityPrerequisite,
  });
}

function scanR12bPlanningPublicContracts({ repositoryRoot, manifest, readImmutableFile } = {}) {
  if (typeof repositoryRoot !== 'string' || !path.isAbsolute(repositoryRoot)) throw new Error('R12B repository root must be absolute');
  const checked = validateR12bManifest(manifest);
  // Repository identity: this Git top level, extending the immutable base
  // commit. `repository.rootName` and `repository.branch` record where the
  // composite entry was captured; they are provenance, not a constraint.
  const root = identity.verifyRepositoryIdentity(repositoryRoot, checked.repository.baseCommit);
  if (closure.readClosure(root, checked.repository.baseCommit)) return scanR12bClosed(root, checked);
  assertNoTransitionArtifacts(root);

  const r12aManifestFile = inspectPlainFile(root, R12A_MANIFEST_PATH);
  const r12aManifestBytes = fs.readFileSync(r12aManifestFile);
  if (sha256(r12aManifestBytes) !== checked.predecessor.manifestSha256) throw new Error('R12B R12A manifest fingerprint changed');
  const r12aManifest = JSON.parse(r12aManifestBytes.toString('utf8'));
  const r12a = require(R12A_SCANNER_PATH);
  const entry = r12a.readR12aImmutableEntry({ repositoryRoot: root, manifest: r12aManifest, readImmutableFile });
  const r12aDependency = r12a.expectedR12aDependencyRecords(entry.dependency, r12aManifest);
  const expectedOwnership = r12a.expectedR12aOwnershipBaseline(entry.ownership, r12aManifest);
  const ownershipFile = inspectPlainFile(root, OWNERSHIP_PATH);
  const dependencyBytes = r12a.readR12aSuccessorDependencyBytes(root);
  const ownershipBytes = fs.readFileSync(ownershipFile);
  const liveDependency = JSON.parse(dependencyBytes.toString('utf8'));
  const liveOwnership = JSON.parse(ownershipBytes.toString('utf8'));
  const expectedDependency = expectedR12bSuccessorDependencyRecords(r12aDependency, checked, {
    repositoryRoot: root,
    actualRecords: liveDependency,
  });
  assert.deepStrictEqual(liveDependency, expectedDependency);
  assert.deepStrictEqual(liveOwnership, expectedOwnership);
  if (checked.stage === 'design' && sha256(dependencyBytes) !== DEPENDENCY_SHA256) throw new Error('R12B design dependency bytes changed');
  if (sha256(ownershipBytes) !== OWNERSHIP_SHA256) throw new Error('R12B ownership bytes changed');
  const projection = projectR12bWorkingTreeToPredecessor({ repositoryRoot: root, manifest: checked });

  if (checked.stage === 'design') {
    const locationSource = inspectPlainFile(root, checked.locationMove.from);
    if (sha256(fs.readFileSync(locationSource)) !== checked.locationMove.sourceSha256) throw new Error('R12B location entry source changed');
    if (inspectPlainFile(root, checked.locationMove.to, false)) throw new Error('R12B location target exists before its stage');
    for (const consumer of checked.locationConsumers) {
      const file = inspectPlainFile(root, consumer.path);
      if (sha256(fs.readFileSync(file)) !== consumer.entrySha256) throw new Error(`R12B consumer entry changed: ${consumer.path}`);
    }
    for (const dto of checked.dtoReexpressions) {
      const file = inspectPlainFile(root, dto.from);
      if (sha256(fs.readFileSync(file)) !== dto.sourceSha256) throw new Error(`R12B DTO source changed: ${dto.from}`);
      if (inspectPlainFile(root, dto.to, false)) throw new Error(`R12B DTO target exists before its stage: ${dto.to}`);
    }
  } else {
    verifyR12bPlanningPublicLayout({ repositoryRoot: root, manifest: checked, r12aManifest, r12a });
    if (checked.stage === 'strict') {
      verifyR12bStrictDtoLayout({ repositoryRoot: root, manifest: checked });
      const behavior = checked.behavioralTests[1];
      if (sha256(fs.readFileSync(inspectPlainFile(root, behavior.path))) !== behavior.entrySha256) {
        throw new Error('R12B DTO behavior test hash changed');
      }
    }
    const statusMap = new Map(gitStatus(root).map((row) => [row.path, row.status]));
    const expectedStatuses = new Map([
      [checked.locationMove.from, ' D'],
      [checked.locationMove.to, '??'],
      ...checked.locationConsumers.map((consumer) => [consumer.path, ' M']),
      ['backend/src/onboarding/dto/import-local-plan.dto.ts', ' M'],
      ...checked.dtoReexpressions.map((dto) => [dto.to, '??']),
      [checked.behavioralTests[1].path, '??'],
    ]);
    for (const [relative, expectedStatus] of expectedStatuses) {
      if (statusMap.get(relative) !== expectedStatus) throw new Error(`R12B planning-public working-tree status changed: ${relative}`);
    }
  }
  const ownershipRecords = liveOwnership.violations.length;
  const ownershipOccurrences = liveOwnership.violations.reduce((sum, item) => sum + item.count, 0);
  if (ownershipRecords !== 385 || ownershipOccurrences !== 781) throw new Error('R12B ownership totals changed');
  return deepFreeze({
    ok: true,
    stage: checked.stage,
    documentationStage: checked.documentationStage,
    receipts: checked.documentationTransitions.length,
    dependencyRecords: liveDependency.length,
    ownershipRecords,
    ownershipOccurrences,
    approvedSecurityPrerequisite: projection.securityPrerequisite.approvedSecurityPrerequisite,
    unapprovedProtected: projection.securityPrerequisite.unapprovedProtected,
  });
}

function runCli() {
  try {
    if (process.argv.slice(2).join(' ') !== '--check') throw new Error('invalid arguments');
    const repositoryRoot = path.resolve(__dirname, '../../..');
    const manifestFile = inspectPlainFile(repositoryRoot, MANIFEST_PATH);
    const manifest = JSON.parse(fs.readFileSync(manifestFile, 'utf8'));
    const result = scanR12bPlanningPublicContracts({ repositoryRoot, manifest });
    process.stdout.write(`PASS - R12B Planning public contracts: stage=${result.stage}${result.closed ? ' (closed)' : ''}, dependency=${result.dependencyRecords}, documentation=${result.documentationStage}, receipts=${result.receipts}, ownership=${result.ownershipRecords}/${result.ownershipOccurrences}, approvedSecurityPrerequisite=${result.approvedSecurityPrerequisite}${result.closed ? '' : `, unapprovedProtected=${result.unapprovedProtected}`}\n`);
    return 0;
  } catch (error) {
    if (process.env.R12B_DEBUG === '1') process.stderr.write(`${error.stack || error}\n`);
    else process.stderr.write('ERROR - R12B Planning public contracts validation failed\n');
    return 2;
  }
}

module.exports = {
  inspectPlainFile,
  safeRelative,
  validateR12bManifest,
  expectedR12bDependencyRecords,
  expectedR12bSuccessorDependencyRecords,
  validateR12bPredecessorOverlay,
  projectR12bWorkingTreeToPredecessor,
  validateR12bDocumentationTransitions,
  verifyR12bLocationSourceParity,
  verifyR12bConsumerParity,
  verifyR12bDtoParity,
  scanR12bPlanningPublicContracts,
  runCli,
  applyR12bHunkTransform,
  verifyApprovedSecurityPrerequisite,
  verifyR12bClosedSecurityPrerequisite,
  versionAtLeast,
  scanR12bClosed,
};

if (require.main === module) process.exitCode = runCli();
