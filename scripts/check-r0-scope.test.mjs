import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import {
  mkdtempSync,
  mkdirSync,
  renameSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  R0_ALLOWED_PATHS,
  R0_BASE,
  collectChangedPaths,
  findUnexpectedPaths,
  runCli,
} from './check-r0-scope.mjs';

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const scriptPath = path.join(scriptDir, 'check-r0-scope.mjs');

const expectedAllowedPaths = [
  '.github/workflows/ci.yml',
  '.gitleaksignore',
  'AGENTS.md',
  'ARCHITECTURE.md',
  'CHANGELOG.md',
  'backend/.dependency-cruiser-known-violations.json',
  'backend/.dependency-cruiser.cjs',
  'backend/architecture/ownership-baseline.json',
  'backend/architecture/ownership-registry.json',
  'backend/package-lock.json',
  'backend/package.json',
  'backend/scripts/architecture/ownership-scan.cjs',
  'backend/scripts/architecture/ports-scan.cjs',
  'backend/test/architecture-dependencies.test.ts',
  'backend/test/architecture-ownership.test.ts',
  'backend/test/architecture-ports.test.ts',
  'docs/README.md',
  'docs/SCRIPTS.md',
  'docs/backend/README.md',
  'docs/frontend/MOBILE_ARCHITECTURE.md',
  'docs/project/DECISIONS.md',
  'docs/project/EXECUTION_PLAN.md',
  'docs/project/STATUS.md',
  'docs/qa/README.md',
  'docs/superpowers/plans/2026-08-11-modular-monolith-r0-governance.md',
  'mobile/lib/features/welcome_gateway/widgets/aarast_path_card.dart',
  'scripts/architecture/mobile-boundaries-baseline.json',
  'scripts/check-mobile-boundaries.mjs',
  'scripts/check-mobile-boundaries.test.mjs',
  'scripts/check-r0-scope.mjs',
  'scripts/check-r0-scope.test.mjs',
];

function captureCli(overrides = {}) {
  const stdout = [];
  const stderr = [];
  const exitCode = runCli({
    argv: ['--check'],
    collect: () => [],
    stdout: (message) => stdout.push(message),
    stderr: (message) => stderr.push(message),
    ...overrides,
  });
  return { exitCode, stdout, stderr };
}

function runGitIn(cwd, args) {
  return execFileSync('git', args, {
    cwd,
    encoding: 'utf8',
    windowsHide: true,
  });
}

test('the R0 base is immutable', () => {
  assert.equal(R0_BASE, 'feafe3db0053d6c66d5f46b56ff9a512861dfbad');
});

test('the R0 allowlist contains exactly the approved paths', () => {
  assert.deepEqual([...R0_ALLOWED_PATHS].sort(), expectedAllowedPaths);
});

test('allowed paths pass regardless of input order or duplicates', () => {
  assert.deepEqual(findUnexpectedPaths([
    'ARCHITECTURE.md',
    'backend/package.json',
    'mobile/lib/features/welcome_gateway/widgets/aarast_path_card.dart',
    'ARCHITECTURE.md',
  ]), []);
});

test('application, schema, migration, deployment, and unknown paths fail', () => {
  assert.deepEqual(findUnexpectedPaths([
    'backend/src/auth/auth.service.ts',
    'backend/prisma/schema.prisma',
    'backend/prisma/migrations/not-a-real-migration/migration.sql',
    'mobile/lib/main.dart',
    'admin-web/src/App.tsx',
    'deploy/compose.yml',
    'unexpected.txt',
  ]), [
    'admin-web/src/App.tsx',
    'backend/prisma/migrations/not-a-real-migration/migration.sql',
    'backend/prisma/schema.prisma',
    'backend/src/auth/auth.service.ts',
    'deploy/compose.yml',
    'mobile/lib/main.dart',
    'unexpected.txt',
  ]);
});

test('changed-path collection verifies the base and combines every required Git source', () => {
  const calls = [];
  const runGit = (args) => {
    calls.push(args);
    if (args[0] === 'diff') {
      return 'backend\\package.json\nARCHITECTURE.md\n';
    }
    if (args[0] === 'ls-files') {
      return 'scripts\\check-r0-scope.mjs\nARCHITECTURE.md\n';
    }
    return '';
  };

  assert.deepEqual(collectChangedPaths({ runGit }), [
    'ARCHITECTURE.md',
    'backend/package.json',
    'scripts/check-r0-scope.mjs',
  ]);
  assert.deepEqual(calls, [
    ['cat-file', '-e', `${R0_BASE}^{commit}`],
    [
      'diff',
      '--name-only',
      '--no-renames',
      '--diff-filter=ACMRDTUXB',
      R0_BASE,
      '--',
    ],
    ['ls-files', '--others', '--exclude-standard'],
  ]);
});

test('changed-path collection rejects absolute and parent-traversal Git output', () => {
  for (const invalidPath of [
    '../outside.txt',
    '/absolute/path.txt',
    'C:\\absolute\\path.txt',
  ]) {
    assert.throws(
      () => collectChangedPaths({
        runGit: (args) => args[0] === 'diff' ? `${invalidPath}\n` : '',
      }),
      /invalid repository path/,
      invalidPath,
    );
  }
});

test('a protected source renamed to an allowed destination remains visible', () => {
  const root = mkdtempSync(path.join(os.tmpdir(), 'aarast-r0-scope-'));
  try {
    runGitIn(root, ['init']);
    runGitIn(root, ['config', 'user.name', 'R0 Scope Test']);
    runGitIn(root, ['config', 'user.email', 'r0-scope@example.invalid']);
    runGitIn(root, ['config', 'core.autocrlf', 'false']);
    mkdirSync(path.join(root, 'backend', 'src'), { recursive: true });
    writeFileSync(path.join(root, 'backend', 'src', 'protected.ts'), 'export {};\n');
    runGitIn(root, ['add', 'backend/src/protected.ts']);
    runGitIn(root, ['commit', '-m', 'fixture base']);
    const base = runGitIn(root, ['rev-parse', 'HEAD']).trim();
    renameSync(
      path.join(root, 'backend', 'src', 'protected.ts'),
      path.join(root, 'ARCHITECTURE.md'),
    );

    const changedPaths = collectChangedPaths({
      runGit: (args) => runGitIn(root, args),
      base,
    });

    assert.deepEqual(changedPaths, [
      'ARCHITECTURE.md',
      'backend/src/protected.ts',
    ]);
    assert.deepEqual(findUnexpectedPaths(changedPaths), [
      'backend/src/protected.ts',
    ]);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('CLI returns zero for a clean R0 scope', () => {
  const result = captureCli({ collect: () => ['ARCHITECTURE.md'] });

  assert.equal(result.exitCode, 0);
  assert.deepEqual(result.stdout, ['PASS - R0 scope: no unexpected paths']);
  assert.deepEqual(result.stderr, []);
});

test('CLI returns one and prints every unexpected path in sorted order', () => {
  const result = captureCli({
    collect: () => ['unexpected.txt', 'admin-web/src/App.tsx'],
  });

  assert.equal(result.exitCode, 1);
  assert.deepEqual(result.stdout, []);
  assert.deepEqual(result.stderr, [
    'FAIL - R0 scope: unexpected paths',
    'admin-web/src/App.tsx',
    'unexpected.txt',
  ]);
});

test('CLI turns a missing-base Git failure into sanitized configuration exit two', () => {
  const calls = [];
  const result = captureCli({
    collect: () => collectChangedPaths({
      runGit: (args) => {
        calls.push(args);
        throw new Error('fatal: bad object C:\\Users\\private\\repository');
      },
    }),
  });

  assert.equal(result.exitCode, 2);
  assert.deepEqual(calls, [['cat-file', '-e', `${R0_BASE}^{commit}`]]);
  assert.deepEqual(result.stdout, []);
  assert.deepEqual(result.stderr, ['R0 scope configuration error']);
});

test('CLI rejects unknown arguments without invoking collection', () => {
  let collected = false;
  const result = captureCli({
    argv: ['--unknown'],
    collect: () => {
      collected = true;
      return [];
    },
  });

  assert.equal(result.exitCode, 2);
  assert.equal(collected, false);
  assert.deepEqual(result.stdout, []);
  assert.deepEqual(result.stderr, ['usage: check-r0-scope.mjs --check']);
});

test('real wrapper sanitizes unknown-argument output', () => {
  const result = spawnSync(process.execPath, [scriptPath, '--unknown'], {
    cwd: scriptDir,
    encoding: 'utf8',
    windowsHide: true,
  });
  const output = `${result.stdout}${result.stderr}`;

  assert.equal(result.status, 2);
  assert.match(output, /usage: check-r0-scope\.mjs --check/);
  assert.doesNotMatch(output, /(?:[A-Za-z]:\\|file:\/\/|Error:|\n\s+at\s)/);
});
