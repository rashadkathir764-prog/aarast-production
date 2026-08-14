import assert from 'node:assert/strict';
import {
  existsSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { afterEach, test } from 'node:test';

const backendRoot = path.resolve(__dirname, '..');
const repositoryRoot = path.resolve(backendRoot, '..');
const scopePath = path.join(backendRoot, 'scripts', 'architecture', 'r3-scope.cjs');
const baseRef = '6b06eb096aca8cc6684d365d16e05d4cd8529898';
const temporaryRoots: string[] = [];

type ScopeModule = {
  R3_BASE: string;
  ALLOWED_PATHS: readonly string[];
  assertAllowedPathsMatch(manifestPaths: unknown, scopePaths: unknown): void;
  writeAtomicJson(
    reportPath: string,
    value: unknown,
    dependencies?: Record<string, unknown>,
  ): void;
  validateR3Scope(options: Record<string, unknown>): any;
  validateScopeSnapshot(value: unknown): any;
  runCli(dependencies: Record<string, unknown>): number;
};

function scope(): ScopeModule {
  return require(scopePath) as ScopeModule;
}

afterEach(() => {
  for (const root of temporaryRoots.splice(0)) rmSync(root, { recursive: true, force: true });
});

test('R3 scope pins the immutable base and accepts only the explicit Task 0/1 paths', () => {
  assert.equal(scope().R3_BASE, baseRef);
  const result = scope().validateR3Scope({ repositoryRoot, baseRef });
  assert.equal(result.ok, true);
  assert.deepEqual(result.unexpectedPaths, []);
  assert.deepEqual(result.changedPaths, [
    'backend/.dependency-cruiser.cjs',
    'backend/architecture/r3-context-boundaries.json',
    'backend/package.json',
    'backend/scripts/architecture/ports-scan.cjs',
    'backend/scripts/architecture/r3-context-scan.cjs',
    'backend/scripts/architecture/r3-scope.cjs',
    'backend/test/architecture-dependencies.test.ts',
    'backend/test/architecture-ports.test.ts',
    'backend/test/architecture-r3-contexts.test.ts',
    'backend/test/architecture-r3-scope.test.ts',
    'docs/SCRIPTS.md',
    'docs/superpowers/plans/2026-08-14-modular-monolith-r3-nest-boundaries.md',
    'docs/superpowers/specs/2026-08-14-modular-monolith-r3-nest-boundaries-design.md',
  ]);
  rmSync(result.reportPath, { force: true });
});

test('the scope allowlist is byte/order-exact with the canonical manifest', () => {
  const manifest = JSON.parse(readFileSync(path.join(
    backendRoot,
    'architecture',
    'r3-context-boundaries.json',
  ), 'utf8'));
  assert.deepEqual(scope().ALLOWED_PATHS, manifest.allowedChangedPaths);
  assert.doesNotThrow(() => scope().assertAllowedPathsMatch(
    manifest.allowedChangedPaths,
    scope().ALLOWED_PATHS,
  ));
  const reordered = [...manifest.allowedChangedPaths];
  [reordered[0], reordered[1]] = [reordered[1], reordered[0]];
  assert.throws(() => scope().assertAllowedPathsMatch(
    reordered,
    scope().ALLOWED_PATHS,
  ), /allowlist.*drift/i);
  assert.throws(() => scope().assertAllowedPathsMatch(
    [...manifest.allowedChangedPaths.slice(0, -1), 'docs/attacker.md'],
    scope().ALLOWED_PATHS,
  ), /allowlist.*drift/i);
});

test('scope snapshots reject an incorrect base, unknown paths, traversal, and duplicates', () => {
  const valid = {
    baseRef,
    allowedPaths: ['backend/package.json'],
    changedPaths: ['backend/package.json'],
  };
  assert.equal(scope().validateScopeSnapshot(valid).ok, true);
  assert.throws(() => scope().validateScopeSnapshot({ ...valid, baseRef: 'HEAD' }), /base/);
  assert.throws(() => scope().validateScopeSnapshot({
    ...valid,
    changedPaths: ['backend/package.json', 'backend/src/app.module.ts'],
  }), /scope/);
  assert.throws(() => scope().validateScopeSnapshot({
    ...valid,
    changedPaths: ['../backend/package.json'],
  }), /path/);
  assert.throws(() => scope().validateScopeSnapshot({
    ...valid,
    changedPaths: ['backend/package.json', 'backend/package.json'],
  }), /duplicate/);
});

test('scope input accepts plain dense data only', () => {
  const valid = {
    baseRef,
    allowedPaths: ['backend/package.json'],
    changedPaths: ['backend/package.json'],
  };
  assert.throws(() => scope().validateScopeSnapshot(new Proxy(valid, {})), /plain object/);
  const accessor = { ...valid } as Record<string, unknown>;
  Object.defineProperty(accessor, 'baseRef', { get: () => baseRef, enumerable: true });
  assert.throws(() => scope().validateScopeSnapshot(accessor), /accessor|data property/);
  assert.throws(() => scope().validateScopeSnapshot({
    ...valid,
    changedPaths: new Array(1),
  }), /dense/);
});

test('machine reports use a unique absolute OS-temp JSON path and reparse safely', () => {
  const root = mkdtempSync(path.join(tmpdir(), 'aarast-r3-scope-report-'));
  temporaryRoots.push(root);
  const first = path.join(root, 'first.json');
  const second = path.join(root, 'second.json');
  const resultA = scope().validateR3Scope({ repositoryRoot, baseRef, reportPath: first });
  const resultB = scope().validateR3Scope({ repositoryRoot, baseRef, reportPath: second });
  assert.equal(path.isAbsolute(resultA.reportPath), true);
  assert.equal(path.extname(resultA.reportPath), '.json');
  assert.notEqual(resultA.reportPath, resultB.reportPath);
  assert.equal(existsSync(`${first}.tmp`), false);
  assert.deepEqual(JSON.parse(readFileSync(first, 'utf8')).changedPaths, resultA.changedPaths);
});

test('I7 the default validator and real CLI both commit truthful atomic reports', () => {
  const result = scope().validateR3Scope({ repositoryRoot, baseRef });
  try {
    assert.equal(existsSync(result.reportPath), true);
    assert.deepEqual(JSON.parse(readFileSync(result.reportPath, 'utf8')).changedPaths, result.changedPaths);
    assert.equal(existsSync(`${result.reportPath}.tmp`), false);
  } finally {
    rmSync(result.reportPath, { force: true });
  }

  const root = mkdtempSync(path.join(tmpdir(), 'aarast-r3-real-cli-'));
  temporaryRoots.push(root);
  const reportPath = path.join(root, 'cli-report.json');
  const cli = path.join(backendRoot, 'scripts', 'architecture', 'r3-scope.cjs');
  const command = spawnSync(process.execPath, [
    cli,
    '--check',
    '--base-ref',
    baseRef,
    '--report-path',
    reportPath,
  ], {
    cwd: backendRoot,
    encoding: 'utf8',
  });
  assert.equal(command.status, 0, command.stderr || command.stdout);
  assert.equal(existsSync(reportPath), true);
  assert.equal(existsSync(`${reportPath}.tmp`), false);
  assert.equal(JSON.parse(readFileSync(reportPath, 'utf8')).ok, true);
});

test('I8 report confinement rejects junction or symlink escapes outside the canonical temp root', () => {
  const lexicalRoot = mkdtempSync(path.join(tmpdir(), 'aarast-r3-link-root-'));
  const outsideRoot = mkdtempSync(path.join(path.dirname(tmpdir()), 'aarast-r3-outside-'));
  temporaryRoots.push(lexicalRoot, outsideRoot);
  const link = path.join(lexicalRoot, 'redirect');
  symlinkSync(outsideRoot, link, process.platform === 'win32' ? 'junction' : 'dir');
  const reportPath = path.join(link, 'escaped.json');
  assert.throws(() => scope().validateR3Scope({
    repositoryRoot,
    baseRef,
    reportPath,
  }), /canonical|reparse|junction|symbolic|temporary/i);
  assert.equal(existsSync(path.join(outsideRoot, 'escaped.json')), false);
  assert.equal(existsSync(path.join(outsideRoot, 'escaped.json.tmp')), false);
});

test('I8 report commit rejects destination races, preserves prior output, and removes partials', () => {
  const root = mkdtempSync(path.join(tmpdir(), 'aarast-r3-race-'));
  temporaryRoots.push(root);
  const existing = path.join(root, 'existing.json');
  writeFileSync(existing, '{"preserved":true}\n', 'utf8');
  assert.throws(() => scope().writeAtomicJson(existing, { ok: true }), /exists|destination|race/i);
  assert.equal(readFileSync(existing, 'utf8'), '{"preserved":true}\n');
  assert.equal(existsSync(`${existing}.tmp`), false);

  const raced = path.join(root, 'raced.json');
  assert.throws(() => scope().writeAtomicJson(raced, { ok: true }, {
    beforeCommit: () => writeFileSync(raced, '{"racer":true}\n', 'utf8'),
  }), /exists|destination|race/i);
  assert.equal(readFileSync(raced, 'utf8'), '{"racer":true}\n');
  assert.equal(existsSync(`${raced}.tmp`), false);
});

test('I8 report publish rejects and preserves a replaced validation temporary', () => {
  const root = mkdtempSync(path.join(tmpdir(), 'aarast-r3-identity-race-'));
  temporaryRoots.push(root);
  const reportPath = path.join(root, 'report.json');
  let replacementPath = '';
  assert.throws(() => scope().writeAtomicJson(reportPath, { ok: true }, {
    beforeCommit: () => {
      const stagingName = readdirSync(root).find((name) => name.includes('.stage-'));
      if (!stagingName) throw new Error('test could not locate private staging directory');
      const stagingPath = path.join(root, stagingName);
      const temporaryName = readdirSync(stagingPath).find((name) => name.endsWith('.tmp'));
      if (!temporaryName) throw new Error('test could not locate owned temporary file');
      replacementPath = path.join(stagingPath, temporaryName);
      rmSync(replacementPath);
      writeFileSync(replacementPath, '{"racer":true}\n', 'utf8');
    },
  }), /changed|identity|race/i);
  assert.equal(existsSync(reportPath), false);
  assert.equal(existsSync(replacementPath), true);
  assert.equal(readFileSync(replacementPath, 'utf8'), '{"racer":true}\n');
});

test('I8 write, flush, and hard-link failures never publish partial output', () => {
  const root = mkdtempSync(path.join(tmpdir(), 'aarast-r3-publish-failure-'));
  temporaryRoots.push(root);
  const mutableFs = require('node:fs') as any;
  const originalWriteFileSync = mutableFs.writeFileSync;
  const originalWriteSync = mutableFs.writeSync;
  const originalFsyncSync = mutableFs.fsyncSync;
  const originalLinkSync = mutableFs.linkSync;

  const partial = path.join(root, 'partial.json');
  mutableFs.writeFileSync = (target: unknown, data: unknown, ...args: unknown[]) => {
    if (typeof target === 'number') {
      originalWriteSync(target, Buffer.from('{"partial":', 'utf8'));
      throw Object.assign(new Error('injected temporary write failure'), { code: 'EIO' });
    }
    return originalWriteFileSync(target, data, ...args);
  };
  try {
    assert.throws(() => scope().writeAtomicJson(partial, { ok: true }), /write failure/i);
  } finally {
    mutableFs.writeFileSync = originalWriteFileSync;
  }
  assert.equal(existsSync(partial), false);

  const unflushed = path.join(root, 'unflushed.json');
  mutableFs.fsyncSync = () => {
    throw Object.assign(new Error('injected fsync failure'), { code: 'EIO' });
  };
  try {
    assert.throws(() => scope().writeAtomicJson(unflushed, { ok: true }), /fsync failure/i);
  } finally {
    mutableFs.fsyncSync = originalFsyncSync;
  }
  assert.equal(existsSync(unflushed), false);

  const unsupported = path.join(root, 'unsupported.json');
  mutableFs.linkSync = () => {
    throw Object.assign(new Error('injected hard-link failure'), { code: 'ENOTSUP' });
  };
  try {
    assert.throws(() => scope().writeAtomicJson(unsupported, { ok: true }), /hard-link failure/i);
  } finally {
    mutableFs.linkSync = originalLinkSync;
  }
  assert.equal(existsSync(unsupported), false);
  assert.deepEqual(readdirSync(root), []);
});

test('invalid mixed batches do not commit a partial report', () => {
  const root = mkdtempSync(path.join(tmpdir(), 'aarast-r3-scope-invalid-'));
  temporaryRoots.push(root);
  const reportPath = path.join(root, 'invalid.json');
  assert.throws(() => scope().validateScopeSnapshot({
    baseRef,
    allowedPaths: ['backend/package.json'],
    changedPaths: ['backend/package.json', 'backend/src/app.module.ts'],
    reportPath,
  }), /scope/);
  assert.equal(existsSync(reportPath), false);
});

test('the scope CLI returns one fixed failure line with exit 2', () => {
  const output: string[] = [];
  const code = scope().runCli({
    argv: ['--check', '--base-ref', baseRef],
    validate: () => { throw new Error('C:\\private\\TOKEN=secret\nstack'); },
    stdout: (message: string) => output.push(message),
    stderr: (message: string) => output.push(message),
  });
  assert.equal(code, 2);
  assert.deepEqual(output, ['ERROR - R3 scope validation failed']);
});
