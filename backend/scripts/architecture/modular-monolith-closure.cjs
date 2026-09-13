'use strict';

// Phase closure for the byte-lineage governance (R12A/R12B/R12C).
//
// While a phase is open, its manifests bind the exact working-tree overlay to
// the immutable base commit and every historical law is replayed over a
// byte-for-byte reconstruction of its predecessor. That is the right law for
// an in-progress migration and the wrong law for a living product: after the
// phase closes, any changed file anywhere would be an "undeclared" row.
//
// The closure record marks the last commit at which the complete lineage
// validation holds (`lineageCommit`; check it out to re-run the lineage gates
// verbatim) and freezes the three manifests at their closure bytes. From that
// commit on, the R12 gates validate the live tree against the architecture
// invariants the phases established, not against reconstructed history.

const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const CLOSURE_PATH = 'backend/architecture/modular-monolith-closure.json';
const MANIFEST_PATHS = Object.freeze({
  r12a: 'backend/architecture/r12a-backoffice-catalog-public-contracts.json',
  r12b: 'backend/architecture/r12b-planning-public-contracts.json',
  r12c: 'backend/architecture/r12c-zero-cross-context-dependencies.json',
});
const COMMIT = /^[0-9a-f]{40}$/u;
const HASH = /^[0-9a-f]{64}$/u;
const sha = (bytes) => crypto.createHash('sha256').update(bytes).digest('hex');

function closureError(message) {
  return new Error(`Modular-monolith closure: ${message}`);
}

function gitOk(repositoryRoot, args) {
  const env = { ...process.env };
  delete env.GIT_DIR;
  delete env.GIT_WORK_TREE;
  delete env.GIT_INDEX_FILE;
  delete env.GIT_COMMON_DIR;
  const result = spawnSync('git', args, { cwd: repositoryRoot, encoding: 'utf8', env, windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'] });
  return !result.error && result.status === 0;
}

function plainFile(repositoryRoot, relative) {
  const file = path.join(repositoryRoot, ...relative.split('/'));
  if (!fs.existsSync(file)) return null;
  const stat = fs.lstatSync(file);
  if (stat.isSymbolicLink() || !stat.isFile()) throw closureError(`${relative} must be a plain file`);
  return file;
}

// Returns the validated closure record, or null when the repository has no
// closure record (the phase is open and the lineage law applies).
function readClosure(repositoryRoot, expectedBaseCommit) {
  if (typeof repositoryRoot !== 'string' || !path.isAbsolute(repositoryRoot)) throw closureError('repository root must be absolute');
  const file = plainFile(repositoryRoot, CLOSURE_PATH);
  if (!file) return null;
  let record;
  try {
    record = JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch {
    throw closureError('record is not valid JSON');
  }
  if (!record || typeof record !== 'object' || Array.isArray(record)
      || Object.keys(record).join('|') !== 'schemaVersion|phase|closedOn|baseCommit|lineageCommit|manifests|lineageGates') {
    throw closureError('record shape changed');
  }
  if (record.schemaVersion !== 1 || record.phase !== 'R12C' || !/^\d{4}-\d{2}-\d{2}$/u.test(record.closedOn)) throw closureError('record identity is invalid');
  if (!COMMIT.test(record.baseCommit) || !COMMIT.test(record.lineageCommit)) throw closureError('commits must be full lowercase SHA-1');
  if (expectedBaseCommit !== undefined && record.baseCommit !== expectedBaseCommit) throw closureError('base commit does not match the phase');
  if (!record.manifests || typeof record.manifests !== 'object' || Object.keys(record.manifests).join('|') !== 'r12a|r12b|r12c') throw closureError('manifest set changed');
  for (const [phase, relative] of Object.entries(MANIFEST_PATHS)) {
    const expected = record.manifests[phase];
    if (!HASH.test(expected)) throw closureError(`${phase} manifest fingerprint is invalid`);
    const manifestFile = plainFile(repositoryRoot, relative);
    if (!manifestFile || sha(fs.readFileSync(manifestFile)) !== expected) throw closureError(`${phase} manifest changed after closure`);
  }
  if (!Array.isArray(record.lineageGates) || record.lineageGates.length < 1
      || record.lineageGates.some((gate) => typeof gate !== 'string' || gate.length === 0 || gate.length > 1024)) {
    throw closureError('lineage gates must be a non-empty list of commands');
  }
  // The lineage commit must be real history of this repository: base -> lineage -> HEAD.
  if (!gitOk(repositoryRoot, ['cat-file', '-e', `${record.lineageCommit}^{commit}`])) throw closureError('lineage commit is not present in this repository');
  if (!gitOk(repositoryRoot, ['merge-base', '--is-ancestor', record.baseCommit, record.lineageCommit])) throw closureError('lineage commit does not extend the base commit');
  if (!gitOk(repositoryRoot, ['merge-base', '--is-ancestor', record.lineageCommit, 'HEAD'])) throw closureError('HEAD does not extend the lineage commit');
  return Object.freeze({
    schemaVersion: 1,
    phase: record.phase,
    closedOn: record.closedOn,
    baseCommit: record.baseCommit,
    lineageCommit: record.lineageCommit,
    manifests: Object.freeze({ ...record.manifests }),
    lineageGates: Object.freeze([...record.lineageGates]),
  });
}

module.exports = { CLOSURE_PATH, MANIFEST_PATHS, readClosure };
