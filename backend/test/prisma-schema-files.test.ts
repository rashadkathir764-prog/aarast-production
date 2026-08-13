import assert from 'node:assert/strict';
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  renameSync,
  rmSync,
  symlinkSync,
  statSync,
  unlinkSync,
  utimesSync,
  writeFileSync,
} from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

const {
  SCHEMA_FILES_FAILURE,
  readPrismaSchemaFiles,
  runCli,
  validateManifest,
} = require('../scripts/prisma/schema-files.cjs') as {
  SCHEMA_FILES_FAILURE: string;
  readPrismaSchemaFiles: (options?: { backendRoot?: string }) => {
    baseFile: string;
    files: Array<{
      file: string;
      owner: string | null;
      models: string[];
      enums: string[];
      text: string;
    }>;
    combinedText: string;
    modelOrder: string[];
  };
  runCli: (dependencies: {
    argv: string[];
    stdout: (message: string) => void;
    stderr: (message: string) => void;
  }) => number;
  validateManifest: (value: unknown) => unknown;
};

const fixtureRoots: string[] = [];
const mutableFs = require('node:fs') as typeof import('node:fs');
const mutableOperations = mutableFs as unknown as Record<
  'openSync' | 'readFileSync' | 'realpathSync',
  (...args: unknown[]) => unknown
>;

const baseText = [
  'generator client {',
  '  provider = "prisma-client-js"',
  '}',
  '',
  'datasource db {',
  '  provider = "postgresql"',
  '  url      = env("DATABASE_URL")',
  '}',
  '',
].join('\n');

const firstText = [
  'enum FirstState {',
  '  ACTIVE',
  '}',
  '',
  'model First {',
  '  id String @id',
  '}',
  '',
].join('\n');

const secondText = [
  'model Second {',
  '  id String @id',
  '}',
  '',
].join('\n');

function plainManifest() {
  return {
    schemaVersion: 1,
    splitBaseRevision: '8ba0db78ac669bd6d17de878b77a4d1e6c5e542d',
    baseFile: '_base.prisma',
    owners: [
      { owner: 'first', file: 'first.prisma', models: ['First'], enums: ['FirstState'] },
      { owner: 'second', file: 'second.prisma', models: ['Second'], enums: [] },
    ],
    modelOrder: ['First', 'Second'],
  };
}

function write(root: string, relativePath: string, content: string) {
  const target = path.join(root, relativePath);
  mkdirSync(path.dirname(target), { recursive: true });
  writeFileSync(target, content, 'utf8');
}

function fixtureBackend() {
  const root = mkdtempSync(path.join(os.tmpdir(), 'aarast-prisma-schema-files-'));
  fixtureRoots.push(root);
  const backendRoot = path.join(root, 'backend');
  write(
    backendRoot,
    'architecture/prisma-schema-layout.json',
    `${JSON.stringify(plainManifest(), null, 2)}\n`,
  );
  write(backendRoot, 'prisma/schema/_base.prisma', baseText);
  write(backendRoot, 'prisma/schema/first.prisma', firstText);
  write(backendRoot, 'prisma/schema/second.prisma', secondText);
  return { root, backendRoot };
}

function assertFixedFailure(action: () => unknown) {
  assert.throws(action, (error: unknown) => {
    assert.equal(error instanceof Error, true);
    assert.equal((error as Error).message, SCHEMA_FILES_FAILURE);
    assert.doesNotMatch((error as Error).message, /TOKEN=|aarast-prisma-schema-files|schema\.prisma/i);
    return true;
  });
}

test.afterEach(() => {
  for (const root of fixtureRoots.splice(0)) {
    rmSync(root, { recursive: true, force: true });
  }
});

test('reads the complete schema batch in manifest order with combined text and owner metadata', () => {
  const { backendRoot } = fixtureBackend();

  const first = readPrismaSchemaFiles({ backendRoot });
  const second = readPrismaSchemaFiles({ backendRoot });

  assert.deepEqual(first, second);
  assert.equal(first.baseFile, '_base.prisma');
  assert.deepEqual(first.modelOrder, ['First', 'Second']);
  assert.deepEqual(
    first.files.map(({ file, owner, models, enums }) => ({ file, owner, models, enums })),
    [
      { file: '_base.prisma', owner: null, models: [], enums: [] },
      { file: 'first.prisma', owner: 'first', models: ['First'], enums: ['FirstState'] },
      { file: 'second.prisma', owner: 'second', models: ['Second'], enums: [] },
    ],
  );
  assert.equal(first.files[0].text, baseText);
  assert.equal(first.files[1].text, firstText);
  assert.equal(first.files[2].text, secondText);
  assert.equal(first.combinedText, [baseText, firstText, secondText].join('\n'));
});

test('validates the entire exact file batch before reading any schema text', () => {
  for (const mutate of [
    (backendRoot: string) => unlinkSync(path.join(backendRoot, 'prisma/schema/second.prisma')),
    (backendRoot: string) => write(backendRoot, 'prisma/schema/unexpected.prisma', secondText),
    (backendRoot: string) => write(backendRoot, 'prisma/schema/README.txt', 'unexpected\n'),
  ]) {
    const { backendRoot } = fixtureBackend();
    mutate(backendRoot);
    const original = mutableOperations.readFileSync;
    let schemaReadCount = 0;
    mutableOperations.readFileSync = (...args: unknown[]) => {
      if (String(args[0]).toLowerCase().endsWith('.prisma')) schemaReadCount += 1;
      return original(...args);
    };
    try {
      assertFixedFailure(() => readPrismaSchemaFiles({ backendRoot }));
    } finally {
      mutableOperations.readFileSync = original;
    }
    assert.equal(schemaReadCount, 0);
  }
});

test('rejects malformed, non-canonical, duplicate, and bounded manifest data', () => {
  const mutations: Array<(manifest: ReturnType<typeof plainManifest>) => void> = [
    (manifest) => { (manifest as unknown as { extra: boolean }).extra = true; },
    (manifest) => { manifest.schemaVersion = 2; },
    (manifest) => { manifest.baseFile = '../_base.prisma'; },
    (manifest) => { manifest.owners[0].file = path.resolve(os.tmpdir(), 'first.prisma'); },
    (manifest) => { manifest.owners[1].file = manifest.owners[0].file; },
    (manifest) => { manifest.owners[1].owner = manifest.owners[0].owner; },
    (manifest) => { manifest.owners[1].models = ['First']; },
    (manifest) => { manifest.owners[0].models = Array.from({ length: 10_001 }, (_, index) => `M${index}`); },
    (manifest) => { manifest.owners[0].owner = 'x'.repeat(1_025); },
    (manifest) => { manifest.modelOrder = ['First', 'First']; },
  ];

  for (const mutate of mutations) {
    const { backendRoot } = fixtureBackend();
    const manifest = plainManifest();
    mutate(manifest);
    write(
      backendRoot,
      'architecture/prisma-schema-layout.json',
      `${JSON.stringify(manifest)}\n`,
    );
    assertFixedFailure(() => readPrismaSchemaFiles({ backendRoot }));
  }

  const malformed = fixtureBackend();
  write(malformed.backendRoot, 'architecture/prisma-schema-layout.json', '{TOKEN=broken');
  assertFixedFailure(() => readPrismaSchemaFiles({ backendRoot: malformed.backendRoot }));
});

test('validates hostile in-memory manifest values as plain data without invoking accessors or proxy traps', () => {
  const accessor = plainManifest() as unknown as Record<string, unknown>;
  Object.defineProperty(accessor, 'baseFile', {
    enumerable: true,
    get() { throw new Error('TOKEN=accessor'); },
  });
  assertFixedFailure(() => validateManifest(accessor));

  const proxy = new Proxy(plainManifest(), {
    getPrototypeOf() { throw new Error('TOKEN=proxy'); },
  });
  assertFixedFailure(() => validateManifest(proxy));

  assertFixedFailure(() => validateManifest(Object.create(null)));
  assertFixedFailure(() => validateManifest([]));
});

test('rejects file and directory symlink or junction escapes even when every target exists', () => {
  const fileEscape = fixtureBackend();
  const outsideFile = path.join(fileEscape.root, 'outside.prisma');
  writeFileSync(outsideFile, secondText, 'utf8');
  unlinkSync(path.join(fileEscape.backendRoot, 'prisma/schema/second.prisma'));
  symlinkSync(outsideFile, path.join(fileEscape.backendRoot, 'prisma/schema/second.prisma'), 'file');
  assertFixedFailure(() => readPrismaSchemaFiles({ backendRoot: fileEscape.backendRoot }));

  const directoryEscape = fixtureBackend();
  const outsideSchema = path.join(directoryEscape.root, 'outside-schema');
  renameSync(path.join(directoryEscape.backendRoot, 'prisma/schema'), outsideSchema);
  symlinkSync(outsideSchema, path.join(directoryEscape.backendRoot, 'prisma/schema'), 'junction');
  assertFixedFailure(() => readPrismaSchemaFiles({ backendRoot: directoryEscape.backendRoot }));
});

test('accepts a backend-root junction alias while retaining canonical contained schema paths', () => {
  const { root, backendRoot } = fixtureBackend();
  const aliasRoot = path.join(os.tmpdir(), `aarast-prisma-schema-alias-${path.basename(root)}`);
  symlinkSync(backendRoot, aliasRoot, 'junction');
  fixtureRoots.push(aliasRoot);

  const result = readPrismaSchemaFiles({ backendRoot: aliasRoot });

  assert.deepEqual(result.modelOrder, ['First', 'Second']);
  assert.equal(result.files.length, 3);
});

test('rejects schema mutation between validation and reading without returning a partial batch', () => {
  const { backendRoot } = fixtureBackend();
  const target = path.join(backendRoot, 'prisma/schema/second.prisma');
  const replacement = path.join(backendRoot, 'prisma/replacement.tmp');
  writeFileSync(replacement, 'model Replaced { id String @id }\n', 'utf8');
  const originalOpen = mutableOperations.openSync;
  const originalRead = mutableOperations.readFileSync;
  const openedPaths = new Map<number, string>();
  let swapped = false;
  mutableOperations.openSync = (...args: unknown[]) => {
    const descriptor = originalOpen(...args);
    if (typeof descriptor === 'number' && typeof args[0] === 'string') {
      openedPaths.set(descriptor, path.resolve(args[0]));
    }
    return descriptor;
  };
  mutableOperations.readFileSync = (...args: unknown[]) => {
    const source = args[0];
    const candidate = typeof source === 'number'
      ? openedPaths.get(source)
      : path.resolve(String(source));
    if (!swapped && candidate?.endsWith(`${path.sep}first.prisma`)) {
      swapped = true;
      unlinkSync(target);
      renameSync(replacement, target);
    }
    return originalRead(...args);
  };
  try {
    assertFixedFailure(() => readPrismaSchemaFiles({ backendRoot }));
  } finally {
    mutableOperations.openSync = originalOpen;
    mutableOperations.readFileSync = originalRead;
  }
  assert.equal(swapped, true);
});

test('rejects a same-inode same-size rewrite after batch validation and before schema reading', () => {
  const { backendRoot } = fixtureBackend();
  const target = path.join(backendRoot, 'prisma/schema/second.prisma');
  const replacementText = secondText.replace('id String', 'xx String');
  assert.equal(Buffer.byteLength(replacementText), Buffer.byteLength(secondText));
  const before = statSync(target);
  const originalOpen = mutableOperations.openSync;
  const originalRead = mutableOperations.readFileSync;
  const openedPaths = new Map<number, string>();
  let after: ReturnType<typeof statSync> | undefined;
  let rewritten = false;
  mutableOperations.openSync = (...args: unknown[]) => {
    const descriptor = originalOpen(...args);
    if (typeof descriptor === 'number' && typeof args[0] === 'string') {
      openedPaths.set(descriptor, path.resolve(args[0]));
    }
    return descriptor;
  };
  mutableOperations.readFileSync = (...args: unknown[]) => {
    const source = args[0];
    const candidate = typeof source === 'number'
      ? openedPaths.get(source)
      : path.resolve(String(source));
    if (!rewritten && candidate?.endsWith(`${path.sep}first.prisma`)) {
      rewritten = true;
      writeFileSync(target, replacementText, 'utf8');
      utimesSync(target, before.atime, new Date(before.mtimeMs + 5_000));
      after = statSync(target);
    }
    return originalRead(...args);
  };
  try {
    assertFixedFailure(() => readPrismaSchemaFiles({ backendRoot }));
  } finally {
    mutableOperations.openSync = originalOpen;
    mutableOperations.readFileSync = originalRead;
  }
  assert.equal(rewritten, true);
  assert.notEqual(after, undefined);
  assert.equal(after?.dev, before.dev);
  assert.equal(after?.ino, before.ino);
  assert.equal(after?.size, before.size);
  assert.equal(after?.mtimeMs !== before.mtimeMs || after?.ctimeMs !== before.ctimeMs, true);
});

test('converts filesystem failures and invalid options into one fixed non-reflective error', () => {
  const { backendRoot } = fixtureBackend();
  const original = mutableOperations.realpathSync;
  mutableOperations.realpathSync = (...args: unknown[]) => {
    if (path.resolve(String(args[0])) === path.resolve(backendRoot)) {
      throw new Error('TOKEN=filesystem-failure');
    }
    return original(...args);
  };
  try {
    assertFixedFailure(() => readPrismaSchemaFiles({ backendRoot }));
  } finally {
    mutableOperations.realpathSync = original;
  }

  assertFixedFailure(() => readPrismaSchemaFiles({ backendRoot: '' }));
  assertFixedFailure(() => readPrismaSchemaFiles({ backendRoot: 'relative/backend' }));
  assertFixedFailure(() => readPrismaSchemaFiles({ backendRoot, TOKEN: 'secret' } as never));
});

test('CLI rejects every argument with a fixed non-reflective boundary', () => {
  const stdout: string[] = [];
  const stderr: string[] = [];
  const exitCode = runCli({
    argv: ['TOKEN=argument'],
    stdout: (message) => stdout.push(message),
    stderr: (message) => stderr.push(message),
  });

  assert.equal(exitCode, 2);
  assert.deepEqual(stdout, []);
  assert.deepEqual(stderr, ['ERROR - Prisma schema loader failed']);
});

test('fixture cleanup removes every temporary schema root', () => {
  const { root } = fixtureBackend();
  assert.equal(existsSync(root), true);
  rmSync(root, { recursive: true, force: true });
  assert.equal(existsSync(root), false);
  fixtureRoots.splice(fixtureRoots.indexOf(root), 1);
  assert.deepEqual(readdirSync(os.tmpdir()).filter((name) => name === path.basename(root)), []);
});
