import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import test from 'node:test';

const backendRoot = path.resolve(__dirname, '..');
const checkerPath = path.join(
  backendRoot,
  'scripts',
  'security',
  'prisma-config-merge-security.cjs',
);

type JsonRecord = Record<string, unknown>;
type InstalledResolution = {
  backendRoot: string;
  prismaConfigPackageRoot: string;
  prismaConfigPackageJson: JsonRecord;
  mergeEntryFromPrismaConfig: string;
  mergeEntryFromRuntime: string;
  mergePackageRoot: string;
  mergePackageJson: JsonRecord;
  installedMergePackageRoots: string[];
};
type Checker = {
  PINNED_DEEPMERGE_VERSION: string;
  PINNED_DEEPMERGE_INTEGRITY: string;
  SECURITY_FAILURE: string;
  assertInstalledMergeBehavior: (mergeEntry: string) => void;
  assertMergeBehavior: (deepmerge: (left: JsonRecord, right: JsonRecord) => JsonRecord) => void;
  checkPrismaConfigMergeSecurity: (options?: { backendRoot?: string }) => Promise<unknown>;
  fingerprintPlainJson: (value: unknown) => string;
  runCli: (options: {
    argv: string[];
    backendRoot?: string;
    stdout: (message: string) => void;
    stderr: (message: string) => void;
  }) => Promise<number>;
  validateInstalledResolution: (input: InstalledResolution) => unknown;
  validatePackageGraph: (
    packageJson: unknown,
    packageLock: unknown,
    options?: {
      expectedIntegrity?: string;
      expectedPackageFingerprint?: string;
      expectedLockFingerprint?: string;
    },
  ) => unknown;
};

function loadChecker(): Checker {
  return require(checkerPath) as Checker;
}

const pinnedIntegrity =
  'sha512-szCXE7YLCvLKR9bFPJcvsezOShdalctSvrgN/LM/QGUEPZQajwjmsMObZ6/DuANT5lxzM/wtO8Feubwdkz8myA==';

function patchedPackage(): JsonRecord {
  return {
    name: 'fixture-backend',
    dependencies: {
      prisma: '^6.19.3',
      '@prisma/client': '^6.19.3',
    },
    overrides: {
      'deepmerge-ts': '8.0.1',
    },
  };
}

function patchedLock(): JsonRecord {
  return {
    name: 'fixture-backend',
    lockfileVersion: 3,
    requires: true,
    packages: {
      '': {
        name: 'fixture-backend',
        dependencies: {
          prisma: '^6.19.3',
          '@prisma/client': '^6.19.3',
        },
      },
      'node_modules/@prisma/config': {
        version: '6.19.3',
        resolved: 'https://registry.npmjs.org/@prisma/config/-/config-6.19.3.tgz',
        integrity: 'sha512-fixture-prisma-config',
        dependencies: {
          'deepmerge-ts': '7.1.5',
        },
      },
      'node_modules/deepmerge-ts': {
        version: '8.0.1',
        resolved: 'https://registry.npmjs.org/deepmerge-ts/-/deepmerge-ts-8.0.1.tgz',
        integrity: pinnedIntegrity,
      },
    },
  };
}

function fixtureGraphOptions(checker: Checker): {
  expectedPackageFingerprint: string;
  expectedLockFingerprint: string;
} {
  return {
    expectedPackageFingerprint: checker.fingerprintPlainJson(patchedPackage()),
    expectedLockFingerprint: checker.fingerprintPlainJson(patchedLock()),
  };
}

test('accepts only the exact patched Prisma config merge graph', () => {
  const checker = loadChecker();
  assert.equal(checker.PINNED_DEEPMERGE_VERSION, '8.0.1');
  assert.equal(checker.PINNED_DEEPMERGE_INTEGRITY, pinnedIntegrity);
  assert.doesNotThrow(() => checker.validatePackageGraph(
    patchedPackage(),
    patchedLock(),
    fixtureGraphOptions(checker),
  ));
});

test('rejects missing, ranged, downgraded, duplicated, and non-registry resolutions', () => {
  const checker = loadChecker();
  const mutations: Array<[unknown, unknown]> = [];

  const missingOverride = patchedPackage();
  delete (missingOverride.overrides as JsonRecord)['deepmerge-ts'];
  mutations.push([missingOverride, patchedLock()]);

  const rangedOverride = patchedPackage();
  (rangedOverride.overrides as JsonRecord)['deepmerge-ts'] = '^8.0.1';
  mutations.push([rangedOverride, patchedLock()]);

  const prismaUpgrade = patchedPackage();
  (prismaUpgrade.dependencies as JsonRecord).prisma = '^7.9.1';
  mutations.push([prismaUpgrade, patchedLock()]);

  const vulnerableRoot = patchedLock();
  ((vulnerableRoot.packages as JsonRecord)['node_modules/deepmerge-ts'] as JsonRecord).version = '7.1.5';
  mutations.push([patchedPackage(), vulnerableRoot]);

  const vulnerableNested = patchedLock();
  (vulnerableNested.packages as JsonRecord)[
    'node_modules/@prisma/config/node_modules/deepmerge-ts'
  ] = {
    version: '7.1.5',
    resolved: 'https://registry.npmjs.org/deepmerge-ts/-/deepmerge-ts-7.1.5.tgz',
    integrity: 'sha512-vulnerable',
  };
  mutations.push([patchedPackage(), vulnerableNested]);

  const localResolution = patchedLock();
  ((localResolution.packages as JsonRecord)['node_modules/deepmerge-ts'] as JsonRecord).resolved =
    'file:../deepmerge-ts';
  mutations.push([patchedPackage(), localResolution]);

  const wrongIntegrity = patchedLock();
  ((wrongIntegrity.packages as JsonRecord)['node_modules/deepmerge-ts'] as JsonRecord).integrity =
    'sha512-wrong';
  mutations.push([patchedPackage(), wrongIntegrity]);

  for (const [packageJson, packageLock] of mutations) {
    assert.throws(
      () => checker.validatePackageGraph(packageJson, packageLock, fixtureGraphOptions(checker)),
      new RegExp(checker.SECURITY_FAILURE, 'u'),
    );
  }
});

test('rejects unrelated dependency and lock graph drift', () => {
  const checker = loadChecker();
  const packageJson = patchedPackage();
  const packageLock = patchedLock();
  (packageJson.dependencies as JsonRecord)['unrelated-package'] = '1.0.0';
  const lockPackages = packageLock.packages as JsonRecord;
  ((lockPackages[''] as JsonRecord).dependencies as JsonRecord)['unrelated-package'] = '1.0.0';
  lockPackages['node_modules/unrelated-package'] = {
    version: '1.0.0',
    resolved: 'file:../attacker',
  };

  assert.throws(
    () => checker.validatePackageGraph(packageJson, packageLock, fixtureGraphOptions(checker)),
    new RegExp(checker.SECURITY_FAILURE, 'u'),
  );
});

test('rejects accessor, proxy, sparse, and cyclic injected package data', () => {
  const checker = loadChecker();
  const accessorPackage = patchedPackage();
  Object.defineProperty(accessorPackage, 'overrides', {
    enumerable: true,
    get: () => ({ 'deepmerge-ts': '8.0.1' }),
  });

  const proxyLock = new Proxy(patchedLock(), {});
  const sparsePackages: unknown[] = [];
  sparsePackages.length = 2;
  const sparseLock = { lockfileVersion: 3, packages: sparsePackages };
  const cyclicPackage = patchedPackage();
  cyclicPackage.self = cyclicPackage;

  for (const [packageJson, packageLock] of [
    [accessorPackage, patchedLock()],
    [patchedPackage(), proxyLock],
    [patchedPackage(), sparseLock],
    [cyclicPackage, patchedLock()],
  ]) {
    assert.throws(
      () => checker.validatePackageGraph(packageJson, packageLock, fixtureGraphOptions(checker)),
      new RegExp(checker.SECURITY_FAILURE, 'u'),
    );
  }
});

test('requires Prisma Config and runtime to resolve one canonical installed package', () => {
  const checker = loadChecker();
  const root = path.resolve('C:\\fixture-backend');
  const mergeRoot = path.join(root, 'node_modules', 'deepmerge-ts');
  const entry = path.join(mergeRoot, 'dist', 'index.cjs');
  const valid: InstalledResolution = {
    backendRoot: root,
    prismaConfigPackageRoot: path.join(root, 'node_modules', '@prisma', 'config'),
    prismaConfigPackageJson: { name: '@prisma/config', version: '6.19.3' },
    mergeEntryFromPrismaConfig: entry,
    mergeEntryFromRuntime: entry,
    mergePackageRoot: mergeRoot,
    mergePackageJson: { name: 'deepmerge-ts', version: '8.0.1' },
    installedMergePackageRoots: [mergeRoot],
  };

  assert.doesNotThrow(() => checker.validateInstalledResolution(valid));

  for (const mutation of [
    { ...valid, mergeEntryFromPrismaConfig: path.join(root, 'nested', 'index.cjs') },
    { ...valid, mergeEntryFromRuntime: path.join(root, 'fake', 'index.cjs') },
    { ...valid, mergePackageJson: { name: 'deepmerge-ts', version: '7.1.5' } },
    { ...valid, mergePackageJson: { name: '@attacker/deepmerge-ts', version: '8.0.1' } },
    { ...valid, prismaConfigPackageJson: { name: '@prisma/config', version: '0.0.0' } },
    {
      ...valid,
      installedMergePackageRoots: [mergeRoot, path.join(root, 'node_modules', 'nested', 'deepmerge-ts')],
    },
  ]) {
    assert.throws(
      () => checker.validateInstalledResolution(mutation),
      new RegExp(checker.SECURITY_FAILURE, 'u'),
    );
  }
});

test('requires recursive merge safety and preserves ordinary Prisma config semantics', () => {
  const checker = loadChecker();
  const safeMerge = (left: JsonRecord, right: JsonRecord): JsonRecord => {
    const merged: JsonRecord = {
      ...left,
      ...right,
      migrations: {
        ...((left.migrations as JsonRecord | undefined) ?? {}),
        ...((right.migrations as JsonRecord | undefined) ?? {}),
      },
      datasource: {
        ...((left.datasource as JsonRecord | undefined) ?? {}),
        ...((right.datasource as JsonRecord | undefined) ?? {}),
      },
    };
    merged.self = merged;
    return merged;
  };
  const shallowMerge = (left: JsonRecord, right: JsonRecord): JsonRecord => {
    const merged = { ...left, ...right };
    merged.self = merged;
    return merged;
  };
  const unsafeMerge = (): JsonRecord => {
    throw new RangeError('Maximum call stack size exceeded');
  };
  const mutatingMerge = (left: JsonRecord, right: JsonRecord): JsonRecord => {
    left.migrations = right.migrations;
    left.self = left;
    return left;
  };
  const stealthMutatingMerge = (left: JsonRecord, right: JsonRecord): JsonRecord => {
    const merged = safeMerge(left, right);
    if (!Object.prototype.hasOwnProperty.call(left, 'self')) {
      left.schema = 'mutated-after-merge';
    }
    return merged;
  };

  assert.doesNotThrow(() => checker.assertMergeBehavior(safeMerge));
  for (const candidate of [
    shallowMerge,
    unsafeMerge,
    mutatingMerge,
    stealthMutatingMerge,
  ]) {
    assert.throws(
      () => checker.assertMergeBehavior(candidate),
      new RegExp(checker.SECURITY_FAILURE, 'u'),
    );
  }
});

test('rejects every observable whole-input object-state mutation', () => {
  const checker = loadChecker();
  const mergeCorrectly = (left: JsonRecord, right: JsonRecord): JsonRecord => {
    const merged: JsonRecord = {
      ...left,
      ...right,
      migrations: {
        ...((left.migrations as JsonRecord | undefined) ?? {}),
        ...((right.migrations as JsonRecord | undefined) ?? {}),
      },
      datasource: {
        ...((left.datasource as JsonRecord | undefined) ?? {}),
        ...((right.datasource as JsonRecord | undefined) ?? {}),
      },
    };
    merged.self = merged;
    return merged;
  };
  const onlyOrdinary = (
    mutate: (left: JsonRecord, right: JsonRecord) => void,
  ): ((left: JsonRecord, right: JsonRecord) => JsonRecord) => (
    left,
    right,
  ) => {
    const merged = mergeCorrectly(left, right);
    if (!Object.prototype.hasOwnProperty.call(left, 'self')) mutate(left, right);
    return merged;
  };

  const candidates = [
    onlyOrdinary((left) => Object.defineProperty(left, 'hiddenMutation', {
      value: true,
      enumerable: false,
      configurable: true,
    })),
    onlyOrdinary((left) => Object.defineProperty(left, Symbol('hiddenMutation'), {
      value: true,
      enumerable: true,
      configurable: true,
    })),
    onlyOrdinary((left) => Object.setPrototypeOf(left, null)),
    onlyOrdinary((left) => Object.defineProperty(left, 'schema', { writable: false })),
    onlyOrdinary((left) => Object.preventExtensions(left)),
    onlyOrdinary((left) => { delete left.schema; }),
    onlyOrdinary((_left, right) => Object.defineProperty(right, 'hiddenMutation', {
      value: true,
      enumerable: false,
      configurable: true,
    })),
    (left: JsonRecord, right: JsonRecord): JsonRecord => {
      const merged = mergeCorrectly(left, right);
      if (Object.prototype.hasOwnProperty.call(left, 'self')) {
        Object.defineProperty(left, 'hiddenCycleMutation', {
          value: true,
          enumerable: false,
          configurable: true,
        });
      }
      return merged;
    },
  ];

  for (const candidate of candidates) {
    assert.throws(
      () => checker.assertMergeBehavior(candidate),
      new RegExp(checker.SECURITY_FAILURE, 'u'),
    );
  }
});

test('rejects primordial tampering without trusting post-merge globals or iterators', () => {
  const worker = [
    'const checker = require(process.argv[1]);',
    "const { deepmerge } = require('deepmerge-ts');",
    'const mode = process.argv[2];',
    'const originalIterator = Array.prototype[Symbol.iterator];',
    'const candidate = (left, right) => {',
    '  Array.prototype[Symbol.iterator] = originalIterator;',
    '  const merged = deepmerge(left, right);',
    "  if (!Object.prototype.hasOwnProperty.call(left, 'self')) {",
    "    if (mode === 'iterator') {",
    "      left.schema = 'mutated-after-merge';",
    '      Array.prototype[Symbol.iterator] = function* emptyIterator() {};',
    "    } else if (mode === 'getPrototypeOf') {",
    '      Object.setPrototypeOf(left, null);',
    '      Object.getPrototypeOf = () => Object.prototype;',
    "    } else if (mode === 'objectPrototype') {",
    "      Object.defineProperty(Object.prototype, 'hiddenMutation', {",
    '        value: true, enumerable: false, configurable: true,',
    '      });',
    '    }',
    '  }',
    '  return merged;',
    '};',
    'try {',
    '  checker.assertMergeBehavior(candidate);',
    '  process.exit(10);',
    '} catch (error) {',
    '  process.exit(error?.message === checker.SECURITY_FAILURE ? 0 : 11);',
    '}',
  ].join('\n');

  for (const mode of ['iterator', 'getPrototypeOf', 'objectPrototype']) {
    const result = spawnSync(process.execPath, ['-e', worker, checkerPath, mode], {
      cwd: backendRoot,
      encoding: 'utf8',
      timeout: 2_000,
      windowsHide: true,
    });
    assert.equal(result.status, 0, `${mode} bypass must be rejected`);
    assert.equal(result.stdout, '');
    assert.equal(result.stderr, '');
  }
});

test('rejects Set method and global primordial binding tampering between merge calls', () => {
  const worker = [
    'const checker = require(process.argv[1]);',
    "const { deepmerge } = require('deepmerge-ts');",
    'const mode = process.argv[2];',
    'const originalSetHas = Set.prototype.has;',
    'const originalObject = globalThis.Object;',
    'const originalReflect = globalThis.Reflect;',
    'const fakeObject = function FakeObject() {};',
    'const fakeReflect = Object.freeze({});',
    'let calls = 0;',
    'const candidate = (left, right) => {',
    '  Set.prototype.has = originalSetHas;',
    '  globalThis.Object = originalObject;',
    '  globalThis.Reflect = originalReflect;',
    '  const merged = deepmerge(left, right);',
    '  calls += 1;',
    "  if (mode === 'set' && calls === 2) left.schema = 'mutated-after-merge';",
    "  if (mode === 'set') Set.prototype.has = function alwaysSeen() { return true; };",
    "  if (mode === 'objectBinding') globalThis.Object = fakeObject;",
    "  if (mode === 'reflectBinding') globalThis.Reflect = fakeReflect;",
    '  return merged;',
    '};',
    'try {',
    '  checker.assertMergeBehavior(candidate);',
    '  process.exit(10);',
    '} catch (error) {',
    '  process.exit(error?.message === checker.SECURITY_FAILURE ? 0 : 11);',
    '}',
  ].join('\n');

  for (const mode of ['set', 'objectBinding', 'reflectBinding']) {
    const result = spawnSync(process.execPath, ['-e', worker, checkerPath, mode], {
      cwd: backendRoot,
      encoding: 'utf8',
      timeout: 2_000,
      windowsHide: true,
    });
    assert.equal(result.status, 0, `${mode} bypass must be rejected`);
    assert.equal(result.stdout, '');
    assert.equal(result.stderr, '');
  }
});

test('rejects primordial mutation that occurs before the first merge call', () => {
  const worker = [
    'const checker = require(process.argv[1]);',
    "const { deepmerge } = require('deepmerge-ts');",
    'const mode = process.argv[2];',
    "if (mode === 'set') Set.prototype.has = function alwaysSeen() { return true; };",
    "if (mode === 'array') Array.prototype[Symbol.iterator] = function* emptyIterator() {};",
    'try {',
    '  checker.assertMergeBehavior(deepmerge);',
    '  process.exit(10);',
    '} catch (error) {',
    '  process.exit(error?.message === checker.SECURITY_FAILURE ? 0 : 11);',
    '}',
  ].join('\n');

  for (const mode of ['set', 'array']) {
    const result = spawnSync(process.execPath, ['-e', worker, checkerPath, mode], {
      cwd: backendRoot,
      encoding: 'utf8',
      timeout: 2_000,
      windowsHide: true,
    });
    assert.equal(result.status, 0, `${mode} load-time mutation must be rejected`);
    assert.equal(result.stdout, '');
    assert.equal(result.stderr, '');
  }
});

test('rejects accessor and Proxy merge outputs before observing their values', () => {
  const worker = [
    'const checker = require(process.argv[1]);',
    "const { deepmerge } = require('deepmerge-ts');",
    'const mode = process.argv[2];',
    'const candidate = (left, right) => {',
    '  const merged = deepmerge(left, right);',
    "  if (Object.prototype.hasOwnProperty.call(left, 'self')) return merged;",
    "  if (mode === 'accessor') {",
    '    const schema = merged.schema;',
    "    Object.defineProperty(merged, 'schema', {",
    '      enumerable: true, configurable: true,',
    "      get() { left.schema = 'mutated-by-accessor'; return schema; },",
    '    });',
    '    return merged;',
    '  }',
    '  return new Proxy(merged, {',
    '    get(target, key, receiver) {',
    "      if (key === 'schema') Object.defineProperty(Object.prototype, 'r5OutputPollution', {",
    '        value: true, enumerable: false, configurable: true,',
    '      });',
    '      return Reflect.get(target, key, receiver);',
    '    },',
    '  });',
    '};',
    'try {',
    '  checker.assertMergeBehavior(candidate);',
    '  process.exit(10);',
    '} catch (error) {',
    '  process.exit(error?.message === checker.SECURITY_FAILURE ? 0 : 11);',
    '}',
  ].join('\n');

  for (const mode of ['accessor', 'proxy']) {
    const result = spawnSync(process.execPath, ['-e', worker, checkerPath, mode], {
      cwd: backendRoot,
      encoding: 'utf8',
      timeout: 2_000,
      windowsHide: true,
    });
    assert.equal(result.status, 0, `${mode} output must be rejected before observation`);
    assert.equal(result.stdout, '');
    assert.equal(result.stderr, '');
  }
});

test('isolated installed-merge worker requires an exact completion sentinel', () => {
  const fixtureRoot = mkdtempSync(path.join(tmpdir(), 'aarast-r5-merge-worker-'));
  const safeEntry = path.join(fixtureRoot, 'safe.cjs');
  const callbackExitEntry = path.join(fixtureRoot, 'callback-exit.cjs');
  const moduleExitEntry = path.join(fixtureRoot, 'module-exit.cjs');
  try {
    writeFileSync(
      safeEntry,
      `module.exports = require(${JSON.stringify(require.resolve('deepmerge-ts'))});\n`,
      'utf8',
    );
    writeFileSync(
      callbackExitEntry,
      'module.exports = { deepmerge() { process.exit(0); } };\n',
      'utf8',
    );
    writeFileSync(moduleExitEntry, 'process.exit(0);\n', 'utf8');

    const checker = loadChecker();
    assert.doesNotThrow(() => checker.assertInstalledMergeBehavior(safeEntry));
    for (const entry of [callbackExitEntry, moduleExitEntry]) {
      assert.throws(
        () => checker.assertInstalledMergeBehavior(entry),
        new RegExp(checker.SECURITY_FAILURE, 'u'),
      );
    }
  } finally {
    const canonicalFixtureRoot = path.resolve(fixtureRoot);
    assert.equal(path.dirname(canonicalFixtureRoot), path.resolve(tmpdir()));
    rmSync(canonicalFixtureRoot, { recursive: true, force: true });
  }
});

test('live public Prisma config merger handles a recursive object graph safely', () => {
  const { deepmerge } = require('deepmerge-ts') as {
    deepmerge: (left: JsonRecord, right: JsonRecord) => JsonRecord;
  };
  assert.doesNotThrow(() => loadChecker().assertMergeBehavior(deepmerge));
});

test('live installed Prisma config merger is pinned, canonical, cycle-safe, and loadable', async () => {
  await assert.doesNotReject(loadChecker().checkPrismaConfigMergeSecurity({ backendRoot }));
});

test('CLI is fixed, sanitized, and truthful for the live installed graph', async () => {
  const stdout: string[] = [];
  const stderr: string[] = [];
  const checker = loadChecker();
  const exitCode = await checker.runCli({
    argv: ['--check'],
    backendRoot,
    stdout: (message) => stdout.push(message),
    stderr: (message) => stderr.push(message),
  });

  assert.equal(exitCode, 0);
  assert.deepEqual(stdout, ['PASS - Prisma config merge security']);
  assert.deepEqual(stderr, []);

  const invalidStdout: string[] = [];
  const invalidStderr: string[] = [];
  const invalidExit = await checker.runCli({
    argv: ['--unknown'],
    backendRoot,
    stdout: (message) => invalidStdout.push(message),
    stderr: (message) => invalidStderr.push(message),
  });
  assert.equal(invalidExit, 2);
  assert.deepEqual(invalidStdout, []);
  assert.deepEqual(invalidStderr, ['ERROR - Prisma config merge security check failed']);
  assert.doesNotMatch(invalidStderr.join('\n'), /(?:[A-Za-z]:\\|file:\/\/|Error:|\n\s+at\s)/u);
});
