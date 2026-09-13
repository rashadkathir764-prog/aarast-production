import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { after, before, describe, test } from 'node:test';

// Governance portability.
//
// The R12 governance chain binds to repository content: the immutable base
// commit, the overlay measured against it, and the fingerprints of governed
// files. It must therefore validate the same content from any checkout: a
// differently named directory, any branch, a committed or an uncommitted
// extension of the base. It must equally keep rejecting drifted governed
// bytes, undeclared files, forged ancestry and unregistered protected changes.
//
// The proofs below run the real gate commands as child processes inside a
// fresh clone whose working tree is exactly what committing the current
// working tree would materialize; nothing in memory is neutralized.

const repositoryRoot = path.resolve(__dirname, '../..');
const backendRoot = path.join(repositoryRoot, 'backend');
const identity = require(path.join(backendRoot, 'scripts/architecture/repository-identity.cjs'));
const r12c = require(path.join(backendRoot, 'scripts/architecture/r12c-zero-cross-context-dependencies-scan.cjs'));
const baseCommit: string = r12c.BASE_COMMIT;
const gateScripts = {
  r3: ['scripts/architecture/r3-context-scan.cjs', '--check', '--stage', 'strict'],
  r5: ['scripts/architecture/r5-identity-scan.cjs', '--check'],
  r6: ['scripts/architecture/r6-sharing-otp-transport-scan.cjs', '--check'],
  r7: ['scripts/architecture/r7-collaboration-relocation-scan.cjs', '--check'],
  r12a: ['scripts/architecture/r12a-backoffice-catalog-public-contracts-scan.cjs', '--check'],
  r12b: ['scripts/architecture/r12b-planning-public-contracts-scan.cjs', '--check'],
  r12c: ['scripts/architecture/r12c-zero-cross-context-dependencies-scan.cjs', '--check'],
} as const;
type Gate = keyof typeof gateScripts;

function git(cwd: string, args: string[], env: NodeJS.ProcessEnv = {}): string {
  return execFileSync('git', args, { cwd, encoding: 'utf8', windowsHide: true, env: { ...process.env, ...env } }).trim();
}

// A dangling commit of the current working tree, built through a private index
// so neither the real index nor any ref changes. Its checkout is what a commit
// of this working tree would materialize on any machine.
function commitWorkingTreeSnapshot(): string {
  const indexFile = path.join(mkdtempSync(path.join(tmpdir(), 'aarast-portability-index-')), 'index');
  const env = { GIT_INDEX_FILE: indexFile };
  git(repositoryRoot, ['read-tree', 'HEAD'], env);
  git(repositoryRoot, ['add', '-A', '--', '.'], env);
  const tree = git(repositoryRoot, ['write-tree'], env);
  const commit = git(repositoryRoot, ['commit-tree', tree, '-p', 'HEAD', '-m', 'governance portability snapshot'], {
    ...env,
    GIT_AUTHOR_NAME: 'portability', GIT_AUTHOR_EMAIL: 'portability@test', GIT_COMMITTER_NAME: 'portability', GIT_COMMITTER_EMAIL: 'portability@test',
  });
  rmSync(path.dirname(indexFile), { recursive: true, force: true });
  return commit;
}

function runGate(cwd: string, gate: Gate): { status: number | null; output: string } {
  const [script, ...args] = gateScripts[gate];
  const result = spawnSync(process.execPath, [path.join(cwd, 'backend', script), ...args], {
    cwd: path.join(cwd, 'backend'),
    encoding: 'utf8',
    windowsHide: true,
    env: { ...process.env, R12B_DEBUG: '1', R12C_DEBUG: '1' },
  });
  return { status: result.status, output: `${result.stdout}${result.stderr}` };
}

function expectPass(cwd: string, gate: Gate): void {
  const { status, output } = runGate(cwd, gate);
  assert.equal(status, 0, `${gate} must pass from ${cwd}:\n${output}`);
  assert.match(output, /^PASS - /mu, gate);
}

function expectFailure(cwd: string, gate: Gate, reason: RegExp): void {
  const { status, output } = runGate(cwd, gate);
  assert.notEqual(status, 0, `${gate} must fail from ${cwd}`);
  assert.match(output, reason, `${gate} must fail for the expected reason:\n${output}`);
}

describe('governance portability', () => {
  let scratch = '';
  let clone = '';
  let snapshot = '';

  before(() => {
    scratch = mkdtempSync(path.join(tmpdir(), 'aarast-portability-'));
    // A directory name that shares nothing with the source checkout.
    clone = path.join(scratch, 'renamed-checkout');
    snapshot = commitWorkingTreeSnapshot();
    git(scratch, ['clone', '--quiet', '--shared', '--no-checkout', repositoryRoot, clone]);
    git(clone, ['checkout', '--quiet', '-b', 'portability-proof', snapshot]);
    // A fresh checkout is verified after the documented dependency install:
    // the scanners resolve Nest decorators through a real TypeScript program.
    // The clone owns a plain node_modules directory of its own; nothing is
    // linked to this worktree's installation.
    const install = spawnSync(process.platform === 'win32' ? 'npm.cmd' : 'npm', ['ci', '--ignore-scripts', '--no-audit', '--no-fund', '--prefer-offline', '--loglevel=error'], {
      cwd: path.join(clone, 'backend'), encoding: 'utf8', windowsHide: true, shell: process.platform === 'win32',
    });
    assert.equal(install.status, 0, `dependency install in the clone failed:\n${install.stdout}${install.stderr}`);
    assert.equal(existsSync(path.join(clone, 'backend/node_modules/typescript/package.json')), true);
  });

  after(() => {
    if (scratch) rmSync(scratch, { recursive: true, force: true });
  });

  test('the identity helper accepts only a Git top level extending the base commit', () => {
    const root = identity.verifyRepositoryIdentity(repositoryRoot, baseCommit);
    assert.equal(path.resolve(root), path.resolve(repositoryRoot));
    assert.throws(() => identity.verifyRepositoryIdentity(backendRoot, baseCommit), /not the Git top level/u);
    assert.throws(() => identity.verifyRepositoryIdentity(path.dirname(repositoryRoot), baseCommit), /Repository identity/u);
    assert.throws(() => identity.verifyRepositoryIdentity(repositoryRoot, '0'.repeat(40)), /not present/u);
    assert.throws(() => identity.verifyRepositoryIdentity(repositoryRoot, 'HEAD'), /full lowercase SHA-1/u);
    assert.throws(() => identity.verifyRepositoryIdentity('relative/path', baseCommit), /absolute/u);
    const rows = identity.workingTreeInventory(repositoryRoot, baseCommit);
    for (const row of rows) assert.ok([' M', ' D', '??'].includes(row.status), JSON.stringify(row));
    assert.deepEqual(rows.map((row: { path: string }) => row.path), [...rows.map((row: { path: string }) => row.path)].sort());
    assert.equal(new Set(rows.map((row: { path: string }) => row.path)).size, rows.length);
  });

  test('the working tree is in canonical Git form, so a checkout reproduces every fingerprinted byte', () => {
    const tracked = git(repositoryRoot, ['ls-files', '-z']).split('\u0000').filter(Boolean);
    const drifted: string[] = [];
    for (const relative of tracked) {
      if (!/\.(cjs|mjs|ts|js|json|md)$/u.test(relative)) continue;
      const file = path.join(repositoryRoot, relative);
      if (!existsSync(file)) continue;
      const raw = git(repositoryRoot, ['hash-object', '--no-filters', '--', file]);
      const filtered = git(repositoryRoot, ['hash-object', '--path', relative, '--', file]);
      if (raw !== filtered) drifted.push(relative);
    }
    assert.deepEqual(drifted, [], 'files whose committed bytes would differ from their working bytes');
  });

  test('every governed gate passes from a renamed clone on another branch with the work committed', () => {
    assert.notEqual(path.basename(clone), path.basename(repositoryRoot));
    assert.equal(git(clone, ['branch', '--show-current']), 'portability-proof');
    assert.notEqual(git(clone, ['rev-parse', 'HEAD']), baseCommit);
    assert.equal(git(clone, ['status', '--porcelain']), '', 'the clone starts with a clean, fully committed tree');
    for (const gate of Object.keys(gateScripts) as Gate[]) expectPass(clone, gate);
  });

  test('the same content passes when the extension of the base commit is uncommitted', () => {
    git(clone, ['reset', '--quiet', '--mixed', baseCommit]);
    try {
      assert.equal(git(clone, ['rev-parse', 'HEAD']), baseCommit);
      assert.notEqual(git(clone, ['status', '--porcelain']), '', 'the overlay is now uncommitted');
      expectPass(clone, 'r12c');
      expectPass(clone, 'r12b');
      expectPass(clone, 'r3');
    } finally {
      git(clone, ['reset', '--quiet', '--hard', snapshot]);
      git(clone, ['clean', '--quiet', '-fd']);
    }
  });

  test('identical content on a history that does not extend the base commit is rejected', () => {
    git(clone, ['checkout', '--quiet', '--orphan', 'forged-history']);
    try {
      git(clone, ['commit', '--quiet', '-m', 'forged ancestry'], {
        GIT_AUTHOR_NAME: 'portability', GIT_AUTHOR_EMAIL: 'portability@test', GIT_COMMITTER_NAME: 'portability', GIT_COMMITTER_EMAIL: 'portability@test',
      });
      assert.equal(git(clone, ['status', '--porcelain']), '');
      expectFailure(clone, 'r12c', /does not extend base commit/u);
      expectFailure(clone, 'r12b', /does not extend base commit/u);
      expectFailure(clone, 'r12a', /does not extend base commit|validation failed/u);
    } finally {
      git(clone, ['checkout', '--quiet', 'portability-proof']);
      git(clone, ['branch', '--quiet', '-D', 'forged-history']);
      git(clone, ['reset', '--quiet', '--hard', snapshot]);
    }
  });

  test('drift of a governed file, an undeclared file, and an unregistered protected change are still rejected', () => {
    const scanner = path.join(clone, 'backend/scripts/architecture/r12c-zero-cross-context-dependencies-scan.cjs');
    const original = readFileSync(scanner);
    writeFileSync(scanner, Buffer.concat([original, Buffer.from('\n')]));
    try {
      expectFailure(clone, 'r12c', /governed fingerprint changed/u);
    } finally {
      writeFileSync(scanner, original);
    }

    const attacker = path.join(clone, 'backend/src/attacker.ts');
    mkdirSync(path.dirname(attacker), { recursive: true });
    writeFileSync(attacker, 'export const attacker = true;\n');
    try {
      expectFailure(clone, 'r12c', /undeclared, duplicated or changed status: backend\/src\/attacker\.ts/u);
    } finally {
      rmSync(attacker, { force: true });
    }

    const lock = path.join(clone, 'backend/package-lock.json');
    const lockBytes = readFileSync(lock);
    writeFileSync(lock, Buffer.concat([lockBytes, Buffer.from('\n')]));
    try {
      expectFailure(clone, 'r12c', /package-lock|security prerequisite|governed|changed/u);
    } finally {
      writeFileSync(lock, lockBytes);
    }

    const overlay = path.join(clone, 'docs/project/STATUS.md');
    const overlayBytes = readFileSync(overlay);
    writeFileSync(overlay, Buffer.concat([overlayBytes, Buffer.from('\n')]));
    try {
      expectFailure(clone, 'r12c', /predecessor reconstruction changed|documentation projection drifted|changed/u);
    } finally {
      writeFileSync(overlay, overlayBytes);
    }
    assert.equal(git(clone, ['status', '--porcelain']), '', 'every probe restored the clone');
    expectPass(clone, 'r12c');
  });

  test('the historical R12B replay substitutes exactly its pinned environment preamble and nothing else', () => {
    const preamble = r12c.R12B_CLOSURE_ENVIRONMENT_PREAMBLE;
    assert.equal(require('node:crypto').createHash('sha256').update(preamble.text, 'utf8').digest('hex'), preamble.sha256);
    assert.match(preamble.text, /rootName|show-current|'HEAD'/u, 'the substituted text is the environment binding');
    assert.doesNotMatch(preamble.replacement, /rootName|branch|show-current/u);
    const replayed = r12c.replayClosureScannerSource(Buffer.from(`head\n${preamble.text}tail\n`, 'utf8'));
    assert.equal(replayed, `head\n${preamble.replacement}tail\n`);
    assert.throws(() => r12c.replayClosureScannerSource(Buffer.from('no preamble here\n')), /not exactly once/u);
    assert.throws(() => r12c.replayClosureScannerSource(Buffer.from(`${preamble.text}${preamble.text}`)), /not exactly once/u);
  });
});
