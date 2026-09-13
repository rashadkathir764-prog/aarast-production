'use strict';

// R12C strict-candidate registration.
//
// The strict candidate is the only mutable layer of the R12C manifest: it
// registers, as exact reversible byte splices, every edit Task 5 makes to the
// historical scanners/tests it is allowed to touch, plus the files it adds.
// This tool recomputes that registration from two facts only:
//
//   * the last registered state, read from Git (`--reference`, default HEAD):
//     its manifest and its bytes reconstruct the immutable Task 5 entry bytes;
//   * the working tree, which is the new candidate.
//
// It then refreshes the governed fingerprints that depend on the registration
// (the strict-candidate preregistration hash in the scanner, the governed raw
// hashes of the scanner and its planning files, and the manifest's
// normalized-self hash), writes both files, and re-runs the strict scanner.
// It never widens what may be registered: the path allowlist is the scanner's.
//
// Usage:
//   node scripts/architecture/r12c-strict-candidate.cjs --check
//   node scripts/architecture/r12c-strict-candidate.cjs --write [--reference <rev>] [--reference-tree <dir>] [--rebind-authority]
//
// --reference-tree supplies registered bytes that Git cannot materialize (for
// example the mixed line endings registered before canonical LF); bytes from
// it are accepted only when they hash to the reference manifest's fingerprint.

const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync, spawnSync } = require('node:child_process');
const diff = require('diff');

const backendRoot = path.resolve(__dirname, '../..');
const repositoryRoot = path.resolve(backendRoot, '..');
const MANIFEST_PATH = 'backend/architecture/r12c-zero-cross-context-dependencies.json';
const SCANNER_PATH = 'backend/scripts/architecture/r12c-zero-cross-context-dependencies-scan.cjs';
const DEPENDENCY_PATH = 'backend/.dependency-cruiser-known-violations.json';
const CHUNK_BYTES = 6000;
const MERGE_GAP = 48;

const sha = (bytes) => crypto.createHash('sha256').update(bytes).digest('hex');
const serialize = (value) => Buffer.from(`${JSON.stringify(value, null, 2)}\n`, 'utf8');
const absolute = (relative) => path.join(repositoryRoot, ...relative.split('/'));

function readWorking(relative) {
  const file = absolute(relative);
  if (!fs.existsSync(file)) return null;
  if (fs.lstatSync(file).isSymbolicLink() || !fs.lstatSync(file).isFile()) throw new Error(`not a plain file: ${relative}`);
  return fs.readFileSync(file);
}

function gitShow(revision, relative) {
  const options = { cwd: repositoryRoot, maxBuffer: 64 * 1024 * 1024, windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'] };
  const exists = spawnSync('git', ['cat-file', '-e', `${revision}:${relative}`], options);
  if (exists.error) throw exists.error;
  if (exists.status !== 0) return null;
  return execFileSync('git', ['show', `${revision}:${relative}`], options);
}

function chunks(bytes) {
  const output = [];
  for (let index = 0; index < bytes.length; index += CHUNK_BYTES) output.push(bytes.subarray(index, index + CHUNK_BYTES).toString('base64'));
  return output;
}

// Exact character-level splices from entry to candidate, expressed at
// candidate byte offsets, with nearby splices merged so the record stays small
// while every changed byte and its immediate context remain explicit.
function exactSplices(entry, candidate) {
  const components = diff.diffChars(entry.toString('utf8'), candidate.toString('utf8'));
  const splices = [];
  let offset = 0;
  let pending = null;
  const flush = () => {
    if (pending) splices.push({ offset: pending.offset, before: Buffer.from(pending.before, 'utf8'), after: Buffer.from(pending.after, 'utf8') });
    pending = null;
  };
  for (const component of components) {
    if (!component.added && !component.removed) {
      flush();
      offset += Buffer.byteLength(component.value, 'utf8');
      continue;
    }
    if (!pending) pending = { offset, before: '', after: '' };
    if (component.removed) pending.before += component.value;
    if (component.added) {
      pending.after += component.value;
      offset += Buffer.byteLength(component.value, 'utf8');
    }
  }
  flush();
  const merged = [];
  for (const splice of splices) {
    const last = merged.at(-1);
    if (last && splice.offset - last.offset - last.after.length <= MERGE_GAP) {
      const gap = candidate.subarray(last.offset + last.after.length, splice.offset);
      last.before = Buffer.concat([last.before, gap, splice.before]);
      last.after = Buffer.concat([last.after, gap, splice.after]);
    } else merged.push({ ...splice });
  }
  return merged.map((row) => ({ offset: row.offset, beforeBase64: chunks(row.before), afterBase64: chunks(row.after) }));
}

function statusPair(baseBytes, entry) {
  if (baseBytes === null) return { entryStatus: entry === null ? null : '??', candidateStatus: '??' };
  return { entryStatus: entry.equals(baseBytes) ? null : ' M', candidateStatus: ' M' };
}

// The LF form of an entry that carried CRLF terminators, with the indexes of
// its LF-only terminators; null when the entry had no CRLF, when it had a bare
// CR, or when the candidate itself is not LF only.
function lineEndingNormalization(entry, candidate) {
  if (candidate.includes(0x0d) || !entry.includes(0x0d)) return null;
  const lfLines = [];
  const parts = [];
  let line = 0;
  let start = 0;
  for (let index = 0; index < entry.length; index += 1) {
    if (entry[index] !== 0x0a) continue;
    if (index > 0 && entry[index - 1] === 0x0d) parts.push(entry.subarray(start, index - 1));
    else { parts.push(entry.subarray(start, index)); lfLines.push(line); }
    parts.push(Buffer.from('\n'));
    line += 1;
    start = index + 1;
  }
  if (start < entry.length) parts.push(entry.subarray(start));
  const normalized = Buffer.concat(parts);
  return normalized.includes(0x0d) ? null : { normalized, lfLines };
}

function buildRecord(relative, entry, candidate, baseBytes, reconstruct) {
  const statuses = statusPair(baseBytes, entry);
  const lineEndings = entry === null ? null : lineEndingNormalization(entry, candidate);
  const record = entry === null
    ? {
      path: relative, kind: 'new-file', entrySha256: null, candidateSha256: sha(candidate),
      entryByteLength: 0, offset: 0, beforeBase64: [], afterBase64: chunks(candidate),
      entryStatus: statuses.entryStatus, candidateStatus: statuses.candidateStatus,
    }
    : lineEndings
      ? {
        path: relative, kind: 'line-ending-normalization', entrySha256: sha(entry), candidateSha256: sha(candidate),
        entryByteLength: entry.length, entryStatus: statuses.entryStatus, candidateStatus: statuses.candidateStatus,
        lfLines: lineEndings.lfLines, splices: exactSplices(lineEndings.normalized, candidate),
      }
      : {
        path: relative, kind: 'bounded-byte-splices', entrySha256: sha(entry), candidateSha256: sha(candidate),
        entryByteLength: entry.length, entryStatus: statuses.entryStatus, candidateStatus: statuses.candidateStatus,
        splices: exactSplices(entry, candidate),
      };
  const roundTrip = reconstruct(candidate, record);
  if (entry === null ? roundTrip !== null : (roundTrip === null || !roundTrip.equals(entry))) {
    throw new Error(`registration does not reconstruct the entry bytes: ${relative}`);
  }
  return record;
}

function patchConstant(source, name, hash) {
  const pattern = new RegExp(`(${name.replace(/[.*+?^${}()|[\]\\]/gu, '\\$&')})'[0-9a-f]{64}'`, 'u');
  if ((source.match(new RegExp(pattern.source, 'gu')) || []).length !== 1) throw new Error(`scanner constant is not unique: ${name}`);
  return source.replace(pattern, `$1'${hash}'`);
}

function main(argv) {
  const write = argv.includes('--write');
  const check = argv.includes('--check');
  const rebindAuthority = argv.includes('--rebind-authority');
  const referenceIndex = argv.indexOf('--reference');
  const reference = referenceIndex >= 0 ? argv[referenceIndex + 1] : 'HEAD';
  if ((write === check) || !reference) throw new Error('usage: --check | --write [--reference <rev>] [--reference-tree <dir>] [--rebind-authority]');

  const treeIndex = argv.indexOf('--reference-tree');
  const referenceTree = treeIndex >= 0 ? path.resolve(argv[treeIndex + 1]) : null;
  const scanner = require(absolute(SCANNER_PATH));
  const allowedPaths = scanner.STRICT_CANDIDATE_PATHS;
  const baseCommit = scanner.BASE_COMMIT;
  const referenceManifestBytes = gitShow(reference, MANIFEST_PATH);
  if (!referenceManifestBytes) throw new Error(`reference ${reference} has no R12C manifest`);
  const referenceManifest = JSON.parse(referenceManifestBytes.toString('utf8'));
  const referenceRecords = new Map(referenceManifest.strictCandidate.records.map((row) => [row.path, row]));
  const liveManifest = JSON.parse(readWorking(MANIFEST_PATH).toString('utf8'));

  // Every registration is content-addressed: the reference manifest says which
  // bytes the strict layer consumes for a path (its own record's candidate, an
  // earlier stage candidate, a governed or overlay fingerprint), and those bytes
  // are accepted from any source only when they hash to that fingerprint.
  const pinnedReferenceHash = (relative) => {
    const record = referenceRecords.get(relative);
    if (record) return record.candidateSha256;
    for (const stage of [referenceManifest.marketplacePublicCandidate, referenceManifest.messagingLifecycleCandidate]) {
      const row = stage.records.find((item) => item.path === relative);
      if (row) return row.candidateSha256;
    }
    const governed = referenceManifest.governedFiles.find((item) => item.path === relative && item.sha256);
    if (governed) return governed.sha256;
    const overlay = referenceManifest.predecessor.overlayLedger.find((item) => item.path === relative && item.status !== ' D');
    return overlay ? overlay.sha256 : null;
  };
  const locateReferenceBytes = (relative) => {
    const expected = pinnedReferenceHash(relative);
    const sources = [gitShow(reference, relative)];
    if (referenceTree) {
      const file = path.join(referenceTree, ...relative.split('/'));
      if (fs.existsSync(file) && fs.lstatSync(file).isFile()) sources.push(fs.readFileSync(file));
    }
    sources.push(readWorking(relative));
    if (expected === null) return sources[0];
    const match = sources.find((bytes) => bytes !== null && sha(bytes) === expected);
    if (!match) throw new Error(`reference bytes ${expected} for ${relative} were not found in ${reference}${referenceTree ? `, ${referenceTree}` : ''} or the working tree; pass --reference-tree`);
    return match;
  };

  const records = [];
  for (const relative of allowedPaths) {
    const referenceBytes = locateReferenceBytes(relative);
    const referenceRecord = referenceRecords.get(relative);
    const entry = referenceRecord ? scanner.reconstructCandidateRecord(referenceBytes, referenceRecord) : referenceBytes;
    const candidate = readWorking(relative);
    if (candidate === null) {
      if (entry !== null) throw new Error(`strict candidate may not delete ${relative}`);
      continue;
    }
    if (entry !== null && candidate.equals(entry)) continue;
    records.push(buildRecord(relative, entry, candidate, gitShow(baseCommit, relative), scanner.reconstructCandidateRecord));
  }
  const strictCandidate = { ...liveManifest.strictCandidate, records };
  const strictHash = sha(JSON.stringify(strictCandidate));

  const manifest = { ...liveManifest, strictCandidate };

  // Lossless re-encoding of the approved Task 3/4 stage records. Their original
  // single whole-span splice carried the unchanged bytes between the first and
  // last edit twice; the multi-splice form keeps the same entry and candidate
  // fingerprints, statuses and paths, and reconstructs the identical entry
  // bytes, so the approved evidence is unchanged while the manifest shrinks.
  // Runs against a consistent registration: register first, then re-encode.
  const stageHashes = {};
  if (argv.includes('--reencode-stage-candidates')) {
    const readLive = (relative) => {
      const bytes = readWorking(relative);
      if (bytes === null) throw new Error(`stage re-encoding needs ${relative}`);
      return bytes;
    };
    const strict = scanner.strictPredecessorFiles(readLive, (relative) => readWorking(relative) !== null, liveManifest);
    const marketplace = scanner.verifyMarketplacePublicFiles(strict.read, strict.exists, liveManifest, repositoryRoot);
    const reencode = (row, candidate) => {
      if (row.kind !== 'bounded-byte-splice') return row;
      const entry = scanner.reconstructCandidateRecord(candidate, row);
      const record = {
        path: row.path, kind: 'bounded-byte-splices', entrySha256: row.entrySha256, candidateSha256: row.candidateSha256,
        entryByteLength: row.entryByteLength, entryStatus: row.entryStatus, candidateStatus: row.candidateStatus,
        splices: exactSplices(entry, candidate),
      };
      if (!scanner.reconstructCandidateRecord(candidate, record).equals(entry)) throw new Error(`stage re-encoding does not reconstruct ${row.path}`);
      return record;
    };
    manifest.marketplacePublicCandidate = {
      ...liveManifest.marketplacePublicCandidate,
      records: liveManifest.marketplacePublicCandidate.records.map((row) => reencode(row, strict.read(row.path))),
    };
    manifest.messagingLifecycleCandidate = {
      ...liveManifest.messagingLifecycleCandidate,
      records: liveManifest.messagingLifecycleCandidate.records.map((row) => reencode(row, marketplace.reconstructed.get(row.path) || strict.read(row.path))),
    };
    stageHashes.marketplace = sha(JSON.stringify(manifest.marketplacePublicCandidate));
    stageHashes.messaging = sha(JSON.stringify(manifest.messagingLifecycleCandidate));
  }
  const entrySha = (relative) => {
    const record = records.find((row) => row.path === relative);
    if (record) return record.entrySha256;
    const live = readWorking(relative);
    return live === null ? null : sha(live);
  };
  manifest.planningFiles = manifest.planningFiles.map((item) => ({ ...item, sha256: sha(readWorking(item.path)) }));
  const authorityBefore = scanner.authorityFingerprint(liveManifest);
  const authorityAfter = scanner.authorityFingerprint(manifest);
  if (authorityAfter !== authorityBefore && !rebindAuthority) {
    throw new Error('planning files changed; the immutable design authority must be rebound explicitly with --rebind-authority');
  }

  let scannerSource = readWorking(SCANNER_PATH).toString('utf8');
  scannerSource = patchConstant(scannerSource, 'function validateStrictCandidate(candidate) {\n  plainData(candidate);\n  if (sha(JSON.stringify(candidate)) !== ', strictHash);
  if (stageHashes.marketplace) {
    scannerSource = patchConstant(scannerSource, 'function validateMarketplacePublicCandidate(candidate) {\n  plainData(candidate);\n  if (sha(JSON.stringify(candidate)) !== ', stageHashes.marketplace);
    scannerSource = patchConstant(scannerSource, 'function validateMessagingLifecycleCandidate(candidate) {\n  plainData(candidate);\n  if (sha(JSON.stringify(candidate)) !== ', stageHashes.messaging);
  }
  if (authorityAfter !== authorityBefore) scannerSource = patchConstant(scannerSource, 'const AUTHORITY_SHA = ', authorityAfter);
  const scannerBytes = Buffer.from(scannerSource, 'utf8');

  // Governed fingerprints: the manifest binds itself (index 0), the scanner
  // binds its live bytes, R12C's other new paths bind the bytes the strict
  // layer projects (their Task 5 entry when registered, else live), and the
  // design-entry inverse paths keep the fingerprint the projection chain
  // reconstructs through every stage candidate.
  manifest.governedFiles = manifest.governedFiles.map((item, index) => {
    if (index === 0) return { ...item };
    if (item.path === SCANNER_PATH) return { ...item, sha256: sha(scannerBytes) };
    if (manifest.inverseTransforms.some((row) => row.path === item.path)) return { ...item };
    return { ...item, sha256: entrySha(item.path) };
  });
  manifest.normalizedSelfSha256 = '0'.repeat(64);
  manifest.normalizedSelfSha256 = sha(serialize(manifest));
  const manifestBytes = serialize(manifest);

  const manifestChanged = !manifestBytes.equals(readWorking(MANIFEST_PATH));
  const scannerChanged = !scannerBytes.equals(readWorking(SCANNER_PATH));
  const summary = {
    reference, records: records.map((row) => ({ path: row.path, kind: row.kind, splices: row.splices ? row.splices.length : 0, candidateStatus: row.candidateStatus })),
    strictHash, authority: { before: authorityBefore, after: authorityAfter }, manifestBytes: manifestBytes.length,
    manifestChanged, scannerChanged,
  };
  process.stdout.write(`${JSON.stringify(summary, null, 2)}\n`);
  if (check) {
    if (manifestChanged || scannerChanged) {
      process.stderr.write('R12C strict candidate registration is stale; run --write\n');
      return 1;
    }
    process.stdout.write('R12C strict candidate registration is current\n');
    return 0;
  }
  fs.writeFileSync(absolute(MANIFEST_PATH), manifestBytes);
  fs.writeFileSync(absolute(SCANNER_PATH), scannerBytes);
  const verify = spawnSync(process.execPath, [absolute(SCANNER_PATH), '--check'], {
    cwd: backendRoot, encoding: 'utf8', windowsHide: true, env: { ...process.env, R12C_DEBUG: '1' },
  });
  process.stdout.write(`${verify.stdout || ''}${verify.stderr || ''}`);
  if (verify.status !== 0) {
    process.stderr.write('registration written but the strict scanner rejects it\n');
    return 2;
  }
  return 0;
}

if (require.main === module) process.exitCode = main(process.argv.slice(2));
module.exports = { exactSplices, buildRecord, statusPair };
