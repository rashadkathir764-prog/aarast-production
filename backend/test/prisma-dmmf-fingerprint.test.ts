import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  realpathSync,
  renameSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

const {
  FINGERPRINT_FAILURE,
  createFingerprint,
  projectDmmf,
  runCli,
} = require('../scripts/prisma/dmmf-fingerprint.cjs') as {
  FINGERPRINT_FAILURE: string;
  createFingerprint: (dmmf: unknown) => {
    canonicalJson: string;
    projection: unknown;
    sha256: string;
  };
  projectDmmf: (dmmf: unknown) => unknown;
  runCli: (dependencies: {
    argv: string[];
    getDmmf: () => unknown;
    stdout: (message: string) => void;
    stderr: (message: string) => void;
  }) => number;
};

const backendRoot = path.resolve(__dirname, '..');
const scriptPath = path.join(backendRoot, 'scripts', 'prisma', 'dmmf-fingerprint.cjs');
const temporaryRoots: string[] = [];
const mutableFs = require('node:fs') as typeof import('node:fs');
const mutableOperations = mutableFs as unknown as Record<'realpathSync' | 'openSync' | 'lstatSync', (...args: unknown[]) => unknown>;

function temporaryRoot(prefix: string) {
  const root = mkdtempSync(path.join(os.tmpdir(), prefix));
  temporaryRoots.push(root);
  return root;
}

function ignoredBackendFixture(prefix: string): string {
  const parent = path.join(backendRoot, 'dist', 'test-fixtures');
  mkdirSync(parent, { recursive: true });
  const root = mkdtempSync(path.join(parent, prefix));
  temporaryRoots.push(root);
  return root;
}

// A directory that is outside the OS temp directory wherever the repository
// lives (a checkout under the temp directory would otherwise make a
// repository path count as "inside temp"). The home directory is writable
// and outside temp on every platform; the temp root's parent is not writable
// on Linux, where it is `/`.
function outsideTempRoot(prefix: string): string {
  const root = mkdtempSync(path.join(realpathSync.native(os.homedir()), prefix));
  temporaryRoots.push(root);
  return root;
}

function captureCli(overrides: Partial<Parameters<typeof runCli>[0]> = {}) {
  const stdout: string[] = [];
  const stderr: string[] = [];
  const exitCode = runCli({
    argv: ['--output', path.join(temporaryRoot('aarast-r2-dmmf-capture-'), 'fingerprint.json')],
    getDmmf: () => ({ datamodel: { models: [], enums: [] } }),
    stdout: (message) => stdout.push(message),
    stderr: (message) => stderr.push(message),
    ...overrides,
  });
  return { exitCode, stdout, stderr };
}

test.afterEach(() => {
  for (const root of temporaryRoots.splice(0)) {
    rmSync(root, { recursive: true, force: true });
  }
});

test('normalizes model and enum order while preserving declaration and compound-key order', () => {
  const source = {
    datamodel: {
      enums: [
        { name: 'Zeta', dbName: null, values: [{ name: 'SECOND', dbName: null }, { name: 'FIRST', dbName: null }] },
        { name: 'Alpha', dbName: 'alpha_enum', values: [{ name: 'ONLY', dbName: 'only_value' }] },
      ],
      models: [
        {
          name: 'ZetaModel',
          dbName: null,
          documentation: 'zeta model',
          isGenerated: false,
          fields: [
            { name: 'second', kind: 'scalar', isList: false, isRequired: true, isUnique: false, isId: false, isReadOnly: false, isGenerated: false, isUpdatedAt: false, type: 'String', nativeType: null, dbName: null, hasDefaultValue: false, default: undefined },
            { name: 'first', kind: 'scalar', isList: false, isRequired: true, isUnique: false, isId: true, isReadOnly: false, isGenerated: false, isUpdatedAt: false, type: 'Int', nativeType: ['Int4', []], dbName: 'first_id', hasDefaultValue: true, default: 1 },
          ],
          primaryKey: { name: 'zeta_pk', fields: ['second', 'first'] },
          uniqueFields: [['second', 'first']],
          uniqueIndexes: [{ name: 'zeta_unique', fields: ['first', 'second'] }],
        },
        {
          name: 'AlphaModel',
          dbName: 'alpha_model',
          documentation: null,
          isGenerated: false,
          fields: [
            { name: 'id', kind: 'scalar', isList: false, isRequired: true, isUnique: true, isId: true, isReadOnly: false, isGenerated: false, isUpdatedAt: false, type: 'String', nativeType: null, dbName: null, hasDefaultValue: false, default: undefined },
          ],
          primaryKey: null,
          uniqueFields: [],
          uniqueIndexes: [],
        },
      ],
    },
  };

  const first = createFingerprint(source);
  const second = createFingerprint(JSON.parse(JSON.stringify(source)));
  const projection = first.projection as {
    models: Array<{ name: string; fields: Array<{ name: string }>; primaryKey: { fields: string[] } | null; uniqueFields: string[][]; uniqueIndexes: Array<{ fields: string[] }> }>;
    enums: Array<{ name: string; values: Array<{ name: string }> }>;
  };

  assert.equal(first.canonicalJson, second.canonicalJson);
  assert.equal(first.sha256, second.sha256);
  assert.deepEqual(projection.models.map((model) => model.name), ['AlphaModel', 'ZetaModel']);
  assert.deepEqual(projection.enums.map((entry) => entry.name), ['Alpha', 'Zeta']);
  assert.deepEqual(projection.models[1].fields.map((field) => field.name), ['second', 'first']);
  assert.deepEqual(projection.enums[1].values.map((value) => value.name), ['SECOND', 'FIRST']);
  assert.deepEqual(projection.models[1].primaryKey?.fields, ['second', 'first']);
  assert.deepEqual(projection.models[1].uniqueFields, [['second', 'first']]);
  assert.deepEqual(projection.models[1].uniqueIndexes[0].fields, ['first', 'second']);
  assert.deepEqual(Object.keys(projection), ['models', 'enums']);
});

test('rejects hostile or non-plain DMMF input with a fixed non-reflective failure', () => {
  let getterRead = false;
  const accessor = {} as Record<string, unknown>;
  Object.defineProperty(accessor, 'datamodel', {
    enumerable: true,
    get() {
      getterRead = true;
      throw new Error('TOKEN=dmmf-accessor');
    },
  });
  const hostile = new Proxy({}, {
    get() { throw new Error('TOKEN=dmmf-proxy'); },
  });

  for (const candidate of [accessor, hostile, { datamodel: { models: new Date(), enums: [] } }]) {
    assert.throws(
      () => projectDmmf(candidate),
      (error: unknown) => error instanceof Error && error.message === FINGERPRINT_FAILURE,
    );
  }
  assert.equal(getterRead, false);

  const result = captureCli({
    getDmmf: () => {
      throw new Error('TOKEN=dmmf-cli-secret C:/private/dmmf.json');
    },
  });
  assert.equal(result.exitCode, 2);
  assert.deepEqual(result.stdout, []);
  assert.deepEqual(result.stderr, ['ERROR - Prisma DMMF fingerprint failed']);
});

test('converts every Proxy trap from the exported projection API into the fixed failure', () => {
  const traps = [
    'getPrototypeOf',
    'ownKeys',
    'getOwnPropertyDescriptor',
  ] as const;

  for (const trap of traps) {
    const hostile = new Proxy({}, {
      [trap]() {
        throw new Error(`TOKEN=dmmf-${trap}`);
      },
    });
    assert.throws(
      () => projectDmmf(hostile),
      (error: unknown) => error instanceof Error && error.message === FINGERPRINT_FAILURE,
    );
  }
});

test('projects own __proto__ data without prototype mutation and bounds hostile plain values', () => {
  const baseModel = {
    name: 'SafeModel',
    dbName: null,
    documentation: null,
    isGenerated: false,
    fields: [],
    primaryKey: null,
    uniqueFields: [],
    uniqueIndexes: [],
  };
  const withProto = {
    datamodel: {
      models: [{
        ...baseModel,
        fields: [{
          name: 'id', kind: 'scalar', isList: false, isRequired: true, isUnique: true,
          isId: true, isReadOnly: false, isGenerated: false, isUpdatedAt: false,
          type: 'String', nativeType: Object.defineProperty({}, '__proto__', {
            value: { nested: 'safe' }, enumerable: true, writable: true, configurable: true,
          }),
          dbName: null, hasDefaultValue: false, default: undefined,
        }],
      }],
      enums: [],
    },
  };
  const projection = projectDmmf(withProto) as {
    models: Array<{ fields: Array<{ nativeType: Record<string, unknown> }> }>;
  };
  const nativeType = projection.models[0].fields[0].nativeType;
  assert.equal(Object.prototype.hasOwnProperty.call(nativeType, '__proto__'), true);
  assert.deepEqual(Object.getOwnPropertyDescriptor(nativeType, '__proto__')?.value, { nested: 'safe' });
  assert.equal(Object.getPrototypeOf(nativeType), Object.prototype);

  const oversizedString = {
    datamodel: { models: [{ ...baseModel, documentation: 'x'.repeat(128 * 1024) }], enums: [] },
  };
  const oversizedKeys = {
    datamodel: {
      models: [{
        ...baseModel,
        fields: [{
          name: 'id', kind: 'scalar', isList: false, isRequired: true, isUnique: true,
          isId: true, isReadOnly: false, isGenerated: false, isUpdatedAt: false,
          type: 'String', nativeType: Object.fromEntries(Array.from({ length: 2048 }, (_, index) => [`k${index}`, index])),
          dbName: null, hasDefaultValue: false, default: undefined,
        }],
      }],
      enums: [],
    },
  };
  const oversizedNodes = {
    datamodel: {
      models: Array.from({ length: 12_000 }, (_, index) => ({ ...baseModel, name: `Model${index}` })),
      enums: [],
    },
  };
  const oversizedOutput = {
    datamodel: {
      models: Array.from({ length: 2_000 }, (_, index) => ({ ...baseModel, name: `Output${index}`, documentation: 'y'.repeat(1024) })),
      enums: [],
    },
  };

  for (const candidate of [oversizedString, oversizedKeys, oversizedNodes]) {
    assert.throws(
      () => projectDmmf(candidate),
      (error: unknown) => error instanceof Error && error.message === FINGERPRINT_FAILURE,
    );
  }
  assert.throws(
    () => createFingerprint(oversizedOutput),
    (error: unknown) => error instanceof Error && error.message === FINGERPRINT_FAILURE,
  );
});

test('writes an atomic fingerprint only under the real OS temp directory and accepts a safe temp alias', () => {
  const root = temporaryRoot('aarast-r2-dmmf-output-');
  const alias = path.join(os.tmpdir(), `aarast-r2-dmmf-alias-${path.basename(root)}`);
  symlinkSync(root, alias, 'junction');
  temporaryRoots.push(alias);
  const outputPath = path.join(alias, 'fingerprint.json');
  const result = spawnSync(process.execPath, [scriptPath, '--output', outputPath], {
    cwd: backendRoot,
    encoding: 'utf8',
    windowsHide: true,
  });

  assert.equal(result.status, 0, `${result.stdout}\n${result.stderr}`);
  assert.equal(result.stderr, '');
  assert.equal(existsSync(path.join(root, 'fingerprint.json')), true);
  const saved = JSON.parse(readFileSync(path.join(root, 'fingerprint.json'), 'utf8')) as {
    sha256: string;
    modelCount: number;
    enumCount: number;
    dmmf: { models: unknown[]; enums: unknown[] };
  };
  assert.match(saved.sha256, /^[a-f0-9]{64}$/);
  assert.equal(saved.modelCount, 64);
  // B5: + BudgetCategoryKind (the groom's mahr item, C1).
  assert.equal(saved.enumCount, 51);
  assert.equal(saved.dmmf.models.length, 64);
  assert.equal(saved.dmmf.enums.length, 51);
});

test('rejects a non-temp output and a junction escape without writing outside temp', () => {
  const outside = outsideTempRoot('aarast-r2-dmmf-output-outside-');
  const root = temporaryRoot('aarast-r2-dmmf-junction-');
  const junction = path.join(root, 'junction');
  symlinkSync(outside, junction, 'junction');

  for (const outputPath of [
    path.join(outside, 'fingerprint.json'),
    path.join(junction, 'fingerprint.json'),
  ]) {
    const result = spawnSync(process.execPath, [scriptPath, '--output', outputPath], {
      cwd: backendRoot,
      encoding: 'utf8',
      windowsHide: true,
    });
    assert.equal(result.status, 2);
    assert.equal(result.stdout, '');
    assert.equal(result.stderr.trim(), 'ERROR - Prisma DMMF fingerprint failed');
  }
  assert.equal(existsSync(path.join(outside, 'fingerprint.json')), false);
});

test('preserves a pre-existing valid fingerprint when this invocation cannot open its temp artifact', () => {
  const parent = temporaryRoot('aarast-r2-dmmf-existing-target-');
  const outputPath = path.join(parent, 'fingerprint.json');
  const prior = `${JSON.stringify({
    sha256: '0'.repeat(64),
    modelCount: 0,
    enumCount: 0,
    dmmf: { models: [], enums: [] },
  })}\n`;
  writeFileSync(outputPath, prior, 'utf8');
  const original = mutableOperations.openSync;
  let injected = false;

  mutableOperations.openSync = (...args: unknown[]) => {
    const candidate = path.resolve(String(args[0]));
    if (path.dirname(candidate) === parent && path.basename(candidate).startsWith('.fingerprint.json.')) {
      injected = true;
      throw new Error('forced temp open failure');
    }
    return original(...args);
  };
  try {
    const result = captureCli({ argv: ['--output', outputPath] });
    assert.equal(result.exitCode, 2);
    assert.deepEqual(result.stdout, []);
    assert.deepEqual(result.stderr, ['ERROR - Prisma DMMF fingerprint failed']);
  } finally {
    mutableOperations.openSync = original;
  }
  assert.equal(injected, true);
  assert.equal(readFileSync(outputPath, 'utf8'), prior);
  assert.deepEqual(readdirSync(parent), ['fingerprint.json']);
});

test('treats the successful rename as final and never deletes a concurrent post-commit replacement', () => {
  const root = temporaryRoot('aarast-r2-dmmf-post-commit-');
  const safeParent = path.join(root, 'safe');
  const movedParent = path.join(root, 'moved');
  mkdirSync(safeParent);
  const outputName = 'fingerprint.json';
  const outputPath = path.join(safeParent, outputName);
  const movedTarget = path.join(movedParent, outputName);
  const ownedOrphan = path.join(movedParent, 'invocation-owned.json');
  const concurrent = '{"owner":"concurrent"}\n';
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
      symlinkSync(temporaryRoot('aarast-r2-dmmf-post-commit-outside-'), safeParent, 'junction');
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
    result = captureCli({ argv: ['--output', outputPath] });
  } finally {
    mutableOperations.realpathSync = originalRealpath;
    mutableOperations.lstatSync = originalLstat;
  }

  assert.equal(checkToUnlinkRaceTriggered, false, 'post-commit cleanup must never inspect the committed target by path');
  assert.equal(parentSwapped, false, 'no fallible parent validation may run after the atomic rename');
  assert.equal(result.exitCode, 0);
  assert.deepEqual(result.stderr, []);
  assert.equal(existsSync(ownedOrphan), false);
  assert.equal(existsSync(movedTarget), false);
  assert.doesNotThrow(() => JSON.parse(readFileSync(outputPath, 'utf8')));
});

test('rejects real Windows parent swaps before temp creation and before the commit rename without residue', () => {
  const outside = temporaryRoot('aarast-r2-dmmf-toctou-outside-');

  for (const swapOnSafeParentCall of [2, 4]) {
    const root = temporaryRoot(`aarast-r2-dmmf-toctou-${swapOnSafeParentCall}-`);
    const safeParent = path.join(root, 'safe');
    const movedParent = path.join(root, 'moved');
    mkdirSync(safeParent);
    const outputPath = path.join(safeParent, `fingerprint-${swapOnSafeParentCall}.json`);
    const original = mutableOperations.realpathSync;
    let swapped = false;
    let safeParentCalls = 0;

    mutableOperations.realpathSync = (...args: unknown[]) => {
      if (path.resolve(String(args[0])) === safeParent) {
        safeParentCalls += 1;
      }
      if (!swapped && safeParentCalls === swapOnSafeParentCall) {
        swapped = true;
        renameSync(safeParent, movedParent);
        symlinkSync(outside, safeParent, 'junction');
      }
      return (original as unknown as (...inner: unknown[]) => unknown)(...args);
    };
    try {
      const result = captureCli({ argv: ['--output', outputPath] });
      assert.equal(result.exitCode, 2);
      assert.deepEqual(result.stdout, []);
      assert.deepEqual(result.stderr, ['ERROR - Prisma DMMF fingerprint failed']);
    } finally {
      mutableOperations.realpathSync = original;
    }
    assert.equal(swapped, true);
    assert.equal(existsSync(path.join(outside, `fingerprint-${swapOnSafeParentCall}.json`)), false);
    assert.deepEqual(readdirSync(movedParent), [], 'the moved old parent must not retain a temporary or final fingerprint');
  }
});

test('rejects unknown CLI arguments without reflecting paths or errors', () => {
  const result = spawnSync(process.execPath, [scriptPath, '--unknown'], {
    cwd: backendRoot,
    encoding: 'utf8',
    windowsHide: true,
  });
  const output = `${result.stdout}\n${result.stderr}`;

  assert.equal(result.status, 2);
  assert.equal(result.stderr.trim(), 'ERROR - Prisma DMMF fingerprint failed');
  assert.doesNotMatch(output, /(?:[A-Za-z]:\\|file:\/\/|Error:|\n\s+at\s)/);
});
