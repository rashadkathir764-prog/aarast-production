'use strict';

// Portable repository identity for the governance scanners.
//
// Governance must bind to the repository and its content, never to the
// environment it happens to be checked out in. The identity facts a scanner may
// rely on are therefore:
//
//   1. the given root is the real top level of a Git working tree (no parent
//      repository fallback, no nested directory, no reparse point);
//   2. the phase's immutable base commit exists here and is an ancestor of (or
//      equal to) HEAD, so the current state is a true extension of that entry;
//   3. the working-tree overlay relative to that base commit, expressed with the
//      same two-character vocabulary the manifests already carry:
//        ' M' modified against the base, ' D' deleted against the base,
//        '??' added against the base (whether committed since or not).
//
// Absolute paths, directory names, branch names, the exact HEAD hash, and the
// staging state are deliberately not identity: a linked worktree, a differently
// named clone, a CI checkout, or a committed extension of the base must all be
// validated by the same content law.

const { execFileSync, spawnSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

const COMMIT = /^[0-9a-f]{40}$/u;
const MAX_INVENTORY_ROWS = 4096;
const MAX_OUTPUT_BYTES = 16 * 1024 * 1024;
const STATUS_BY_DIFF = Object.freeze({ M: ' M', D: ' D', A: '??' });

function identityError(message) {
  return new Error(`Repository identity: ${message}`);
}

function gitEnvironment() {
  // A polluted GIT_DIR / GIT_WORK_TREE would redirect every query below to a
  // different repository; discovery must come from the root path alone.
  const env = { ...process.env };
  delete env.GIT_DIR;
  delete env.GIT_WORK_TREE;
  delete env.GIT_INDEX_FILE;
  delete env.GIT_COMMON_DIR;
  return env;
}

function gitOptions(cwd) {
  return {
    cwd,
    encoding: 'utf8',
    env: gitEnvironment(),
    maxBuffer: MAX_OUTPUT_BYTES,
    stdio: ['ignore', 'pipe', 'pipe'],
    windowsHide: true,
  };
}

function runGit(cwd, args, executeGit = execFileSync) {
  let output;
  try {
    output = executeGit('git', args, gitOptions(cwd));
  } catch (error) {
    throw identityError(`git ${args.join(' ')} failed${error && error.message ? `: ${error.message.split(/\r?\n/u)[0]}` : ''}`);
  }
  if (typeof output !== 'string') output = Buffer.isBuffer(output) ? output.toString('utf8') : String(output ?? '');
  if (output.includes('\u0000') && !args.includes('-z')) throw identityError(`git ${args.join(' ')} produced binary output`);
  return output;
}

function comparablePath(value) {
  const resolved = path.resolve(value).replaceAll('\\', '/');
  return process.platform === 'win32' ? resolved.toLowerCase() : resolved;
}

function validateBaseCommit(baseCommit) {
  if (typeof baseCommit !== 'string' || !COMMIT.test(baseCommit)) throw identityError('base commit must be a full lowercase SHA-1');
  return baseCommit;
}

// Resolves and verifies that `repositoryRoot` is exactly the top level of the
// working tree Git discovers from it. Returns the native real path.
function resolveRepositoryRoot(repositoryRoot) {
  if (typeof repositoryRoot !== 'string' || repositoryRoot.length === 0 || !path.isAbsolute(repositoryRoot)) {
    throw identityError('repository root must be an absolute path');
  }
  let given;
  try {
    given = fs.lstatSync(repositoryRoot);
  } catch {
    throw identityError('repository root does not exist');
  }
  if (given.isSymbolicLink() || !given.isDirectory()) throw identityError('repository root must be a plain directory');
  const real = fs.realpathSync.native(repositoryRoot);
  const topLevel = runGit(real, ['rev-parse', '--show-toplevel']).trim();
  if (!topLevel || comparablePath(fs.realpathSync.native(topLevel)) !== comparablePath(real)) {
    throw identityError('repository root is not the Git top level');
  }
  const gitDir = runGit(real, ['rev-parse', '--absolute-git-dir']).trim();
  if (!gitDir || !path.isAbsolute(gitDir)) throw identityError('Git directory is not absolute');
  let control;
  try {
    control = fs.lstatSync(gitDir);
  } catch {
    throw identityError('Git directory does not exist');
  }
  if (control.isSymbolicLink() || !control.isDirectory()) throw identityError('Git directory must be a plain directory');
  return real;
}

// The immutable base commit must exist in this repository and be reachable
// from HEAD: the current state is then a genuine extension of the phase entry.
function assertBaseCommitReachable(repositoryRoot, baseCommit) {
  validateBaseCommit(baseCommit);
  const options = gitOptions(repositoryRoot);
  const exists = spawnSync('git', ['cat-file', '-e', `${baseCommit}^{commit}`], options);
  if (exists.error || exists.status !== 0) throw identityError(`base commit ${baseCommit} is not present in this repository`);
  const head = spawnSync('git', ['rev-parse', '--verify', 'HEAD^{commit}'], options);
  if (head.error || head.status !== 0 || !COMMIT.test(String(head.stdout).trim())) throw identityError('HEAD is not a commit');
  const ancestor = spawnSync('git', ['merge-base', '--is-ancestor', baseCommit, 'HEAD'], options);
  if (ancestor.error || ancestor.status !== 0) throw identityError(`HEAD does not extend base commit ${baseCommit}`);
  return String(head.stdout).trim();
}

function parseNulSeparated(output) {
  return output.split('\u0000').filter((item) => item.length > 0);
}

function safeInventoryPath(relative) {
  if (typeof relative !== 'string' || relative.length === 0 || relative.length > 4096 || relative.includes('\\')
      || path.posix.isAbsolute(relative) || relative.split('/').some((part) => part === '' || part === '.' || part === '..')) {
    throw identityError(`inventory path is unsafe: ${relative}`);
  }
  return relative;
}

// Working-tree overlay relative to the base commit. Renames are never folded
// (a moved file is ' D' plus '??'), ignored files never appear, and any status
// Git reports outside modified/deleted/added fails closed.
function workingTreeInventory(repositoryRoot, baseCommit, executeGit = execFileSync) {
  validateBaseCommit(baseCommit);
  const tracked = parseNulSeparated(runGit(repositoryRoot, ['diff', '--no-renames', '--name-status', '-z', baseCommit, '--'], executeGit));
  if (tracked.length % 2 !== 0) throw identityError('git diff produced an unpaired status record');
  const rows = new Map();
  const record = (status, relative) => {
    safeInventoryPath(relative);
    if (rows.has(relative)) throw identityError(`inventory path is duplicated: ${relative}`);
    rows.set(relative, status);
  };
  for (let index = 0; index < tracked.length; index += 2) {
    const status = STATUS_BY_DIFF[tracked[index]];
    if (!status) throw identityError(`unsupported working-tree status ${JSON.stringify(tracked[index])} for ${tracked[index + 1]}`);
    record(status, tracked[index + 1]);
  }
  for (const relative of parseNulSeparated(runGit(repositoryRoot, ['ls-files', '--others', '--exclude-standard', '-z'], executeGit))) {
    record('??', relative);
  }
  if (rows.size > MAX_INVENTORY_ROWS) throw identityError('working-tree inventory is unbounded');
  return [...rows.entries()]
    .sort(([left], [right]) => (left < right ? -1 : left > right ? 1 : 0))
    .map(([relative, status]) => ({ status, path: relative }));
}

// The single identity check a phase scanner performs before reading content.
function verifyRepositoryIdentity(repositoryRoot, baseCommit) {
  const root = resolveRepositoryRoot(repositoryRoot);
  assertBaseCommitReachable(root, baseCommit);
  return root;
}

module.exports = {
  MAX_INVENTORY_ROWS,
  assertBaseCommitReachable,
  resolveRepositoryRoot,
  verifyRepositoryIdentity,
  workingTreeInventory,
};
