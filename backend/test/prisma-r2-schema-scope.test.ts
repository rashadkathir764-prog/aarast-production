import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  renameSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

const {
  R2_BASE,
  R2_ALLOWED_PATHS,
  parseTopLevelBlocks,
  runCli,
  validateScope,
} = require('../scripts/prisma/r2-schema-scope.cjs') as {
  R2_BASE: string;
  R2_ALLOWED_PATHS: Set<string>;
  parseTopLevelBlocks: (schema: string) => Map<string, string>;
  runCli: (dependencies: {
    argv: string[];
    expectedBase: string;
    getRepoRoot: () => string;
    stdout: (message: string) => void;
    stderr: (message: string) => void;
  }) => number;
  validateScope: (options: { repoRoot: string; baseRef: string; expectedBase: string }) => { changedPathCount: number };
};

const fixtureRoots: string[] = [];
const mutableFs = require('node:fs') as typeof import('node:fs');
const mutableOperations = mutableFs as unknown as Record<'realpathSync' | 'openSync' | 'lstatSync', (...args: unknown[]) => unknown>;

const schema = [
  'generator client {',
  '  provider = "prisma-client-js"',
  '}',
  '',
  'datasource db {',
  '  provider = "postgresql"',
  '}',
  '',
  '/// Item state comment',
  'enum ItemState {',
  '  ACTIVE',
  '}',
  '',
  '/// Item model comment',
  'model Item {',
  '  id String @id',
  '  state ItemState',
  '}',
  '',
].join('\n');

function runGit(cwd: string, args: string[]) {
  return execFileSync('git', args, { cwd, encoding: 'utf8', windowsHide: true });
}

function write(root: string, relativePath: string, content: string) {
  const target = path.join(root, relativePath);
  mkdirSync(path.dirname(target), { recursive: true });
  writeFileSync(target, content, 'utf8');
}

function fixtureRepository(overrides: Record<string, string> = {}) {
  const root = mkdtempSync(path.join(os.tmpdir(), 'aarast-r2-scope-'));
  fixtureRoots.push(root);
  runGit(root, ['init']);
  runGit(root, ['config', 'user.name', 'R2 Scope Test']);
  runGit(root, ['config', 'user.email', 'r2-scope@example.invalid']);
  runGit(root, ['config', 'core.autocrlf', 'false']);
  write(root, 'backend/prisma/schema.prisma', schema);
  write(root, 'backend/Dockerfile', [
    'FROM node AS build',
    'COPY prisma ./prisma',
    'RUN npm run build',
    'FROM node AS runtime',
    'COPY --from=build /app/prisma ./prisma',
    '',
  ].join('\n'));
  write(root, 'backend/test/financial-ledger.test.ts', "const schemaText = readFileSync('schema.prisma');\n");
  write(root, 'backend/test/architecture-ownership.test.ts', [
    "import {",
    "  readFileSync,",
    "  writeFileSync,",
    "} from 'node:fs';",
    "const schemaText = readFileSync(path.join(backendRoot, 'prisma', 'schema.prisma'), 'utf8');",
    "function fixtureProject(root: string, fixtureBackend: string) {",
    "  write(root, 'backend/prisma/schema.prisma', schemaText);",
    "  writeFileSync(path.join(fixtureBackend, 'placeholder'), 'fixture');",
    "}",
    '',
  ].join('\n'));
  for (const [relativePath, content] of Object.entries(overrides)) write(root, relativePath, content);
  write(root, '.gitignore', '.superpowers/sdd/**/task-1-report.md\n');
  runGit(root, ['add', '.']);
  runGit(root, ['commit', '-m', 'fixture base']);
  return { root, base: runGit(root, ['rev-parse', 'HEAD']).trim() };
}

function captureCli(root: string, base: string, argv = ['--check', '--base-ref', base]) {
  const stdout: string[] = [];
  const stderr: string[] = [];
  const exitCode = runCli({
    argv,
    expectedBase: base,
    getRepoRoot: () => root,
    stdout: (message) => stdout.push(message),
    stderr: (message) => stderr.push(message),
  });
  return { exitCode, stdout, stderr };
}

test.afterEach(() => {
  for (const root of fixtureRoots.splice(0)) {
    rmSync(root, { recursive: true, force: true });
  }
});

test('pins the production R2 base and the complete R2 file allowlist', () => {
  assert.equal(R2_BASE, '8ba0db78ac669bd6d17de878b77a4d1e6c5e542d');
  assert.equal(R2_ALLOWED_PATHS.has('backend/scripts/prisma/r2-schema-scope.cjs'), true);
  assert.equal(R2_ALLOWED_PATHS.has('backend/prisma/schema.prisma'), true);
  assert.equal(R2_ALLOWED_PATHS.has('backend/src/auth/auth.service.ts'), false);
});

test('accepts an allowed R2 change with byte-identical protected schema blocks through a temp alias', () => {
  const { root, base } = fixtureRepository();
  const alias = path.join(os.tmpdir(), `aarast-r2-scope-alias-${path.basename(root)}`);
  symlinkSync(root, alias, 'junction');
  fixtureRoots.push(alias);
  write(root, 'backend/scripts/prisma/dmmf-fingerprint.cjs', 'module.exports = {};\n');

  const result = captureCli(alias, base);
  assert.equal(result.exitCode, 0);
  assert.deepEqual(result.stderr, []);
  assert.deepEqual(result.stdout, ['PASS - R2 schema scope: 1 changed paths']);
  assert.deepEqual(validateScope({ repoRoot: alias, baseRef: base, expectedBase: base }), { changedPathCount: 1 });
});

test('rejects protected paths, unauthorized paths, and non-mechanical existing test hunks', () => {
  for (const mutation of [
    ['backend/src/auth/auth.service.ts', 'export {};\n'],
    ['unexpected.txt', 'unexpected\n'],
    ['backend/test/financial-ledger.test.ts', 'test("changed assertion", () => {});\n'],
  ]) {
    const { root, base } = fixtureRepository();
    write(root, mutation[0], mutation[1]);
    const result = captureCli(root, base);
    assert.equal(result.exitCode, 1);
    assert.deepEqual(result.stdout, []);
    assert.deepEqual(result.stderr, ['FAIL - R2 schema scope check']);
  }
});

test('rejects changed leading comments, renamed blocks, and duplicate schema blocks', () => {
  for (const candidate of [
    schema.replace('/// Item model comment', '/// Changed item model comment'),
    schema.replace('model Item {', 'model RenamedItem {'),
    `${schema}model Item {\n  duplicate String @id\n}\n`,
  ]) {
    const { root, base } = fixtureRepository();
    write(root, 'backend/prisma/schema.prisma', candidate.replaceAll('\n', '\r\n'));
    const result = captureCli(root, base);
    assert.equal(result.exitCode, 1);
    assert.deepEqual(result.stdout, []);
    assert.deepEqual(result.stderr, ['FAIL - R2 schema scope check']);
  }
});

test('rejects indented extra declarations and detached top-level comments', () => {
  for (const candidate of [
    `${schema}  model IndentedExtra {\n    id String @id\n  }\n`,
    `${schema}\n// detached top-level comment\n`,
  ]) {
    const { root, base } = fixtureRepository();
    write(root, 'backend/prisma/schema.prisma', candidate);
    const result = captureCli(root, base);
    assert.equal(result.exitCode, 1);
    assert.deepEqual(result.stderr, ['FAIL - R2 schema scope check']);
  }
});

test('permits no Dockerfile delta or exactly the two approved config-copy additions', () => {
  const unchanged = fixtureRepository();
  assert.equal(captureCli(unchanged.root, unchanged.base).exitCode, 0);

  const approved = fixtureRepository();
  write(approved.root, 'backend/Dockerfile', [
    'FROM node AS build',
    'COPY prisma ./prisma',
    'COPY prisma.config.ts ./',
    'RUN npm run build',
    'FROM node AS runtime',
    'COPY --from=build /app/prisma ./prisma',
    'COPY --from=build /app/prisma.config.ts ./',
    '',
  ].join('\n'));
  assert.equal(captureCli(approved.root, approved.base).exitCode, 0);

  const rejected = fixtureRepository();
  write(rejected.root, 'backend/Dockerfile', 'FROM node:22\nCOPY prisma ./prisma\n');
  const result = captureCli(rejected.root, rejected.base);
  assert.equal(result.exitCode, 1);
  assert.deepEqual(result.stderr, ['FAIL - R2 schema scope check']);

  const wrongPlacement = fixtureRepository();
  write(wrongPlacement.root, 'backend/Dockerfile', [
    'FROM node AS build',
    'COPY prisma.config.ts ./',
    'COPY prisma ./prisma',
    'RUN npm run build',
    'FROM node AS runtime',
    'COPY --from=build /app/prisma.config.ts ./',
    'COPY --from=build /app/prisma ./prisma',
    '',
  ].join('\n'));
  const misplaced = captureCli(wrongPlacement.root, wrongPlacement.base);
  assert.equal(misplaced.exitCode, 1);
  assert.deepEqual(misplaced.stderr, ['FAIL - R2 schema scope check']);
});

test('creates a structured machine report only in a unique OS-temp output while preserving seeded human evidence bytes', () => {
  const { root, base } = fixtureRepository();
  const humanReport = '.superpowers/sdd/2026-08-13-modular-monolith-r2/task-1-report.md';
  write(root, humanReport, '# human evidence\n- preserve bytes\n');
  const humanBefore = readFileSync(path.join(root, humanReport));
  const machineRoot = mkdtempSync(path.join(os.tmpdir(), 'aarast-r2-machine-report-'));
  fixtureRoots.push(machineRoot);
  const machineReport = path.join(machineRoot, 'scope-report.json');
  const passed = captureCli(root, base, ['--check', '--base-ref', base, '--report', machineReport]);
  assert.equal(passed.exitCode, 0);
  assert.deepEqual(passed.stderr, []);
  assert.deepEqual(readFileSync(path.join(root, humanReport)), humanBefore);
  const generated = readFileSync(machineReport, 'utf8');
  assert.deepEqual(JSON.parse(generated), { changedPathCount: 0, result: 'PASS' });
  assert.doesNotMatch(generated, /(?:[A-Za-z]:\\|file:\/\/|schema\.prisma|TOKEN=)/);

  const failed = captureCli(root, base, ['--check', '--base-ref', base, '--report', '../TOKEN=report']);
  assert.equal(failed.exitCode, 2);
  assert.deepEqual(failed.stdout, []);
  assert.deepEqual(failed.stderr, ['ERROR - R2 schema scope check failed']);
  assert.equal(existsSync(path.join(root, '..', 'TOKEN=report')), false);
});

test('preserves a concurrent machine report when this invocation cannot open its temp artifact', () => {
  const { root, base } = fixtureRepository();
  const machineRoot = mkdtempSync(path.join(os.tmpdir(), 'aarast-r2-scope-concurrent-target-'));
  fixtureRoots.push(machineRoot);
  const machineReport = path.join(machineRoot, 'scope.json');
  const concurrent = '{"changedPathCount":99,"result":"CONCURRENT"}\n';
  assert.equal(existsSync(machineReport), false);
  const original = mutableOperations.openSync;
  let injected = false;

  mutableOperations.openSync = (...args: unknown[]) => {
    const candidate = path.resolve(String(args[0]));
    if (path.dirname(candidate) === machineRoot && path.basename(candidate).startsWith('.scope.json.')) {
      injected = true;
      writeFileSync(machineReport, concurrent, 'utf8');
      throw new Error('forced temp open failure');
    }
    return original(...args);
  };
  try {
    const result = captureCli(root, base, ['--check', '--base-ref', base, '--report', machineReport]);
    assert.equal(result.exitCode, 2);
    assert.deepEqual(result.stdout, []);
    assert.deepEqual(result.stderr, ['ERROR - R2 schema scope check failed']);
  } finally {
    mutableOperations.openSync = original;
  }
  assert.equal(injected, true);
  assert.equal(readFileSync(machineReport, 'utf8'), concurrent);
  assert.deepEqual(readdirSync(machineRoot), ['scope.json']);
});

test('treats the successful report rename as final and never deletes a concurrent post-commit replacement', () => {
  const { root, base } = fixtureRepository();
  const reportRoot = mkdtempSync(path.join(os.tmpdir(), 'aarast-r2-scope-post-commit-'));
  fixtureRoots.push(reportRoot);
  const safeParent = path.join(reportRoot, 'safe');
  const movedParent = path.join(reportRoot, 'moved');
  mkdirSync(safeParent);
  const outputName = 'scope.json';
  const machineReport = path.join(safeParent, outputName);
  const movedTarget = path.join(movedParent, outputName);
  const ownedOrphan = path.join(movedParent, 'invocation-owned.json');
  const concurrent = '{"changedPathCount":99,"result":"CONCURRENT"}\n';
  const originalRealpath = mutableOperations.realpathSync;
  const originalLstat = mutableOperations.lstatSync;
  let safeParentCalls = 0;
  let parentSwapped = false;
  let checkToUnlinkRaceTriggered = false;

  mutableOperations.realpathSync = (...args: unknown[]) => {
    if (path.resolve(String(args[0])) === safeParent) safeParentCalls += 1;
    if (!parentSwapped && safeParentCalls === 5) {
      parentSwapped = true;
      renameSync(safeParent, movedParent);
      const outside = mkdtempSync(path.join(os.tmpdir(), 'aarast-r2-scope-post-commit-outside-'));
      fixtureRoots.push(outside);
      symlinkSync(outside, safeParent, 'junction');
    }
    return (originalRealpath as unknown as (...inner: unknown[]) => unknown)(...args);
  };
  mutableOperations.lstatSync = (...args: unknown[]) => {
    const candidate = path.resolve(String(args[0]));
    const state = (originalLstat as unknown as (...inner: unknown[]) => unknown)(...args);
    if (!checkToUnlinkRaceTriggered && candidate === movedTarget) {
      checkToUnlinkRaceTriggered = true;
      renameSync(movedTarget, ownedOrphan);
      writeFileSync(movedTarget, concurrent, 'utf8');
    }
    return state;
  };
  let result: ReturnType<typeof captureCli>;
  try {
    result = captureCli(root, base, ['--check', '--base-ref', base, '--report', machineReport]);
  } finally {
    mutableOperations.realpathSync = originalRealpath;
    mutableOperations.lstatSync = originalLstat;
  }

  assert.equal(checkToUnlinkRaceTriggered, false, 'post-commit cleanup must never inspect the committed report by path');
  assert.equal(parentSwapped, false, 'no fallible parent validation may run after the atomic rename');
  assert.equal(result.exitCode, 0);
  assert.deepEqual(result.stderr, []);
  assert.equal(existsSync(ownedOrphan), false);
  assert.equal(existsSync(movedTarget), false);
  assert.deepEqual(JSON.parse(readFileSync(machineReport, 'utf8')), { changedPathCount: 0, result: 'PASS' });
});

test('rejects machine-report parent swaps before temp creation and before the commit rename without residue', () => {
  const outside = mkdtempSync(path.join(os.tmpdir(), 'aarast-r2-scope-report-outside-'));
  fixtureRoots.push(outside);

  for (const swapOnSafeParentCall of [2, 4]) {
    const { root, base } = fixtureRepository();
    const safeParent = path.join(mkdtempSync(path.join(os.tmpdir(), `aarast-r2-scope-report-${swapOnSafeParentCall}-`)), 'safe');
    const reportRoot = path.dirname(safeParent);
    const movedParent = path.join(reportRoot, 'moved');
    fixtureRoots.push(reportRoot);
    mkdirSync(safeParent);
    const machineReport = path.join(safeParent, `scope-${swapOnSafeParentCall}.json`);
    const original = mutableOperations.realpathSync;
    let swapped = false;
    let safeParentCalls = 0;

    mutableOperations.realpathSync = (...args: unknown[]) => {
      if (path.resolve(String(args[0])) === safeParent) safeParentCalls += 1;
      if (!swapped && safeParentCalls === swapOnSafeParentCall) {
        swapped = true;
        renameSync(safeParent, movedParent);
        symlinkSync(outside, safeParent, 'junction');
      }
      return (original as unknown as (...inner: unknown[]) => unknown)(...args);
    };
    try {
      const result = captureCli(root, base, ['--check', '--base-ref', base, '--report', machineReport]);
      assert.equal(result.exitCode, 1);
      assert.deepEqual(result.stdout, []);
      assert.deepEqual(result.stderr, ['FAIL - R2 schema scope check']);
    } finally {
      mutableOperations.realpathSync = original;
    }
    assert.equal(swapped, true);
    assert.equal(existsSync(path.join(outside, `scope-${swapOnSafeParentCall}.json`)), false);
    assert.deepEqual(readdirSync(movedParent), [], 'the moved old parent must not retain a temporary or final machine report');
  }
});

test('allows only the exact schema-reader mechanical changes, including the real architecture fixture folder and manifest flow', () => {
  const reader = fixtureRepository();
  write(reader.root, 'backend/test/financial-ledger.test.ts', [
    "import { readLivePrismaSchema } from './support/live-prisma-schema';",
    'const schemaText = readLivePrismaSchema();',
    '',
  ].join('\n'));
  assert.equal(captureCli(reader.root, reader.base).exitCode, 0);

  const helperReader = fixtureRepository({
    'backend/test/financial-ledger.test.ts': [
      "const read = (target: string) => readFileSync(target, 'utf8');",
      "const schemaText = read('prisma/schema.prisma');",
      '',
    ].join('\n'),
  });
  write(helperReader.root, 'backend/test/financial-ledger.test.ts', [
    "import { readLivePrismaSchema } from './support/live-prisma-schema';",
    "const read = (target: string) => readFileSync(target, 'utf8');",
    'const schemaText = readLivePrismaSchema();',
    '',
  ].join('\n'));
  assert.equal(captureCli(helperReader.root, helperReader.base).exitCode, 0);

  const multilineReader = fixtureRepository({
    'backend/test/financial-ledger.test.ts': [
      'const schemaText = readFileSync(',
      "  join(process.cwd(), 'prisma/schema.prisma'),",
      "  'utf8',",
      ');',
      '',
    ].join('\n'),
  });
  write(multilineReader.root, 'backend/test/financial-ledger.test.ts', [
    "import { readLivePrismaSchema } from './support/live-prisma-schema';",
    'const schemaText = readLivePrismaSchema();',
    '',
  ].join('\n'));
  assert.equal(captureCli(multilineReader.root, multilineReader.base).exitCode, 0);

  const pathNamedButWrong = fixtureRepository();
  write(pathNamedButWrong.root, 'backend/test/financial-ledger.test.ts', [
    "import { readLivePrismaSchema } from '../../support/live-prisma-schema';",
    'const schemaText = readLivePrismaSchema();',
    '',
  ].join('\n'));
  assert.equal(captureCli(pathNamedButWrong.root, pathNamedButWrong.base).exitCode, 1);

  const architecture = fixtureRepository();
  write(architecture.root, 'backend/test/architecture-ownership.test.ts', [
    "import {",
    "  cpSync,",
    "  copyFileSync,",
    "  readFileSync,",
    "  writeFileSync,",
    "} from 'node:fs';",
    "function fixtureProject(root: string, fixtureBackend: string) {",
    "  cpSync(",
    "    path.join(backendRoot, 'prisma', 'schema'),",
    "    path.join(fixtureBackend, 'prisma', 'schema'),",
    "    { recursive: true },",
    "  );",
    "  copyFileSync(",
    "    path.join(backendRoot, 'architecture', 'prisma-schema-layout.json'),",
    "    path.join(fixtureBackend, 'architecture', 'prisma-schema-layout.json'),",
    "  );",
    "  writeFileSync(path.join(fixtureBackend, 'placeholder'), 'fixture');",
    "}",
    '',
  ].join('\n'));
  assert.equal(captureCli(architecture.root, architecture.base).exitCode, 0);

  const unrelatedArchitecture = fixtureRepository();
  write(unrelatedArchitecture.root, 'backend/test/architecture-ownership.test.ts', [
    "import {",
    "  cpSync,",
    "  copyFileSync,",
    "  readFileSync,",
    "  writeFileSync,",
    "} from 'node:path';",
    "function fixtureProject(root: string, fixtureBackend: string) {",
    "  cpSync(",
    "    path.join(backendRoot, 'prisma', 'schema'),",
    "    path.join(fixtureBackend, 'prisma', 'schema'),",
    "    { recursive: true },",
    "  );",
    "  copyFileSync(",
    "    path.join(backendRoot, 'architecture', 'prisma-schema-layout.json'),",
    "    path.join(fixtureBackend, 'architecture', 'prisma-schema-layout.json'),",
    "  );",
    "  writeFileSync(path.join(fixtureBackend, 'placeholder'), 'fixture');",
    "}",
    '',
  ].join('\n'));
  assert.equal(captureCli(unrelatedArchitecture.root, unrelatedArchitecture.base).exitCode, 1);
});

test('parses top-level blocks deterministically and retains immediate leading comments', () => {
  const first = parseTopLevelBlocks(schema);
  const second = parseTopLevelBlocks(schema.replaceAll('\n', '\r\n'));
  assert.deepEqual([...first], [...second]);
  assert.equal(first.get('model:Item')?.startsWith('/// Item model comment\nmodel Item'), true);
  assert.equal(first.get('enum:ItemState')?.startsWith('/// Item state comment\nenum ItemState'), true);
});
