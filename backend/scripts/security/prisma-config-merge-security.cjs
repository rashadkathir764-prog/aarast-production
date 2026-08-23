const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { createRequire } = require('node:module');
const { spawnSync } = require('node:child_process');
const { types: utilTypes } = require('node:util');

const primordialGlobalThis = globalThis;
const PrimordialObject = Object;
const PrimordialArray = Array;
const PrimordialFunction = Function;
const PrimordialReflect = Reflect;
const PrimordialSymbol = Symbol;
const PrimordialError = Error;
const PrimordialSet = Set;
const PrimordialNumber = Number;
const SecurityError = PrimordialError;
const reflectOwnKeys = Reflect.ownKeys;
const objectGetOwnPropertyDescriptor = Object.getOwnPropertyDescriptor;
const objectGetPrototypeOf = Object.getPrototypeOf;
const objectIsExtensible = Object.isExtensible;
const objectIsSealed = Object.isSealed;
const objectIsFrozen = Object.isFrozen;
const objectIs = Object.is;
const hasOwn = Function.prototype.call.bind(Object.prototype.hasOwnProperty);
const setHas = Function.prototype.call.bind(Set.prototype.has);
const setAdd = Function.prototype.call.bind(Set.prototype.add);
const arrayIsArray = Array.isArray;
const isProxy = utilTypes.isProxy;
const numberIsFinite = Number.isFinite;
const numberIsSafeInteger = Number.isSafeInteger;
const numberToString = Function.prototype.call.bind(Number.prototype.toString);
const primordialGlobalBindings = [
  ['globalThis', primordialGlobalThis],
  ['Object', PrimordialObject],
  ['Array', PrimordialArray],
  ['Function', PrimordialFunction],
  ['Reflect', PrimordialReflect],
  ['Symbol', PrimordialSymbol],
  ['Error', PrimordialError],
  ['Set', PrimordialSet],
  ['Number', PrimordialNumber],
];

const PINNED_DEEPMERGE_VERSION = '8.0.1';
const PINNED_DEEPMERGE_INTEGRITY =
  'sha512-szCXE7YLCvLKR9bFPJcvsezOShdalctSvrgN/LM/QGUEPZQajwjmsMObZ6/DuANT5lxzM/wtO8Feubwdkz8myA==';
const PINNED_PRISMA_VERSION = '6.19.3';
const PINNED_PRISMA_RANGE = '^6.19.3';
const PINNED_PACKAGE_JSON_SHA256 =
  'd9503a604c4ffb3e63a6faa3b25478a2a4fd766883bcfa2927fccb31fbd2dad7';
const PINNED_PACKAGE_LOCK_SHA256 =
  '46ba2e49c063229aa498112f735f09f7538d6b1e01a0986fec57643d02b586bf';
const R6_ARCHITECTURE_SCRIPT =
  'npm run architecture:imports && npm run architecture:ownership && npm run architecture:ports && npm run architecture:r3 && npm run architecture:r4 && npm run architecture:r5 && npm run architecture:r6';
const R7_ARCHITECTURE_SCRIPT = R6_ARCHITECTURE_SCRIPT + ' && npm run architecture:r7';
const R7_STANDALONE_SCRIPT =
  'node scripts/architecture/r7-collaboration-relocation-scan.cjs --check';
const SECURITY_FAILURE = 'invalid Prisma config merge security state';
const MAX_DEPTH = 32;
const MAX_PROPERTIES = 100_000;
const MAX_STRING_LENGTH = 16 * 1024;

function fail() {
  throw new SecurityError(SECURITY_FAILURE);
}

function plainRecord(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)
      || utilTypes.isProxy(value) || Object.getPrototypeOf(value) !== Object.prototype) fail();
  for (const key of Reflect.ownKeys(value)) {
    const descriptor = Object.getOwnPropertyDescriptor(value, key);
    if (typeof key !== 'string' || !descriptor || !descriptor.enumerable
        || !Object.prototype.hasOwnProperty.call(descriptor, 'value')) fail();
  }
  return value;
}

function denseArray(value) {
  if (!Array.isArray(value) || utilTypes.isProxy(value)
      || Object.getPrototypeOf(value) !== Array.prototype) fail();
  const names = Object.getOwnPropertyNames(value);
  if (names.length !== value.length + 1 || !names.includes('length')) fail();
  for (let index = 0; index < value.length; index += 1) {
    const descriptor = Object.getOwnPropertyDescriptor(value, String(index));
    if (!descriptor || !descriptor.enumerable
        || !Object.prototype.hasOwnProperty.call(descriptor, 'value')) fail();
  }
  if (Object.getOwnPropertySymbols(value).length !== 0) fail();
  return value;
}

function assertDeepPlainData(value, seen = new Set(), depth = 0, state = { properties: 0 }) {
  if (value === null || typeof value === 'boolean'
      || (typeof value === 'number' && Number.isFinite(value))
      || (typeof value === 'string' && value.length <= MAX_STRING_LENGTH)) return;
  if (!value || typeof value !== 'object' || depth > MAX_DEPTH || seen.has(value)) fail();
  seen.add(value);
  if (Array.isArray(value)) {
    const array = denseArray(value);
    state.properties += array.length;
    if (state.properties > MAX_PROPERTIES) fail();
    for (let index = 0; index < array.length; index += 1) {
      assertDeepPlainData(
        Object.getOwnPropertyDescriptor(array, String(index)).value,
        seen,
        depth + 1,
        state,
      );
    }
  } else {
    const record = plainRecord(value);
    const keys = Object.keys(record);
    state.properties += keys.length;
    if (state.properties > MAX_PROPERTIES) fail();
    for (const key of keys) {
      assertDeepPlainData(
        Object.getOwnPropertyDescriptor(record, key).value,
        seen,
        depth + 1,
        state,
      );
    }
  }
  seen.delete(value);
}

function ownValue(record, key) {
  const descriptor = Object.getOwnPropertyDescriptor(plainRecord(record), key);
  if (!descriptor || !descriptor.enumerable
      || !Object.prototype.hasOwnProperty.call(descriptor, 'value')) fail();
  return descriptor.value;
}

function optionalOwnValue(record, key) {
  const descriptor = Object.getOwnPropertyDescriptor(plainRecord(record), key);
  if (!descriptor) return undefined;
  if (!descriptor.enumerable || !Object.prototype.hasOwnProperty.call(descriptor, 'value')) fail();
  return descriptor.value;
}

function canonicalJson(value) {
  if (value === null || typeof value !== 'object') return JSON.stringify(value);
  if (Array.isArray(value)) {
    return '[' + value.map((entry) => canonicalJson(entry)).join(',') + ']';
  }
  return '{' + Object.keys(value).sort().map(
    (key) => JSON.stringify(key) + ':' + canonicalJson(value[key]),
  ).join(',') + '}';
}

function fingerprintPlainJson(value) {
  assertDeepPlainData(value);
  return crypto.createHash('sha256').update(canonicalJson(value)).digest('hex');
}

function projectR7ArchitectureScripts(value) {
  assertDeepPlainData(value);
  const packageJson = plainRecord(value);
  const scripts = plainRecord(ownValue(packageJson, 'scripts'));
  if (!hasOwn(scripts, 'architecture:r7')) return packageJson;
  if (ownValue(scripts, 'architecture:r7') !== R7_STANDALONE_SCRIPT
      || ownValue(scripts, 'architecture') !== R7_ARCHITECTURE_SCRIPT) fail();
  const projectedScripts = { ...scripts };
  delete projectedScripts['architecture:r7'];
  projectedScripts.architecture = R6_ARCHITECTURE_SCRIPT;
  return { ...packageJson, scripts: projectedScripts };
}

function validatePackageGraph(
  packageJsonValue,
  packageLockValue,
  {
    expectedIntegrity = PINNED_DEEPMERGE_INTEGRITY,
    expectedPackageFingerprint = PINNED_PACKAGE_JSON_SHA256,
    expectedLockFingerprint = PINNED_PACKAGE_LOCK_SHA256,
  } = {},
) {
  try {
    assertDeepPlainData(packageJsonValue);
    assertDeepPlainData(packageLockValue);
    const packageJson = plainRecord(packageJsonValue);
    const packageLock = plainRecord(packageLockValue);
    if (fingerprintPlainJson(packageJson) !== expectedPackageFingerprint
        || fingerprintPlainJson(packageLock) !== expectedLockFingerprint) fail();
    const dependencies = plainRecord(ownValue(packageJson, 'dependencies'));
    const overrides = plainRecord(ownValue(packageJson, 'overrides'));
    if (ownValue(dependencies, 'prisma') !== PINNED_PRISMA_RANGE
        || ownValue(dependencies, '@prisma/client') !== PINNED_PRISMA_RANGE
        || ownValue(overrides, 'deepmerge-ts') !== PINNED_DEEPMERGE_VERSION) fail();
    if (ownValue(packageLock, 'lockfileVersion') !== 3) fail();

    const packages = plainRecord(ownValue(packageLock, 'packages'));
    const root = plainRecord(ownValue(packages, ''));
    const rootDependencies = plainRecord(ownValue(root, 'dependencies'));
    if (ownValue(rootDependencies, 'prisma') !== PINNED_PRISMA_RANGE
        || ownValue(rootDependencies, '@prisma/client') !== PINNED_PRISMA_RANGE) fail();

    const prismaConfig = plainRecord(ownValue(packages, 'node_modules/@prisma/config'));
    const prismaConfigDependencies = plainRecord(ownValue(prismaConfig, 'dependencies'));
    if (ownValue(prismaConfig, 'version') !== PINNED_PRISMA_VERSION
        || ownValue(prismaConfigDependencies, 'deepmerge-ts') !== '7.1.5') fail();

    const mergeEntries = Object.keys(packages).filter(
      (key) => key === 'node_modules/deepmerge-ts' || key.endsWith('/node_modules/deepmerge-ts'),
    );
    if (mergeEntries.length !== 1 || mergeEntries[0] !== 'node_modules/deepmerge-ts') fail();
    const merge = plainRecord(ownValue(packages, mergeEntries[0]));
    const resolved = ownValue(merge, 'resolved');
    if (ownValue(merge, 'version') !== PINNED_DEEPMERGE_VERSION
        || resolved !== 'https://registry.npmjs.org/deepmerge-ts/-/deepmerge-ts-8.0.1.tgz'
        || ownValue(merge, 'integrity') !== expectedIntegrity
        || optionalOwnValue(merge, 'link') === true) fail();

    return Object.freeze({
      prismaVersion: PINNED_PRISMA_VERSION,
      deepmergeVersion: PINNED_DEEPMERGE_VERSION,
      deepmergeIntegrity: expectedIntegrity,
      installedCopies: 1,
    });
  } catch {
    fail();
  }
}

function isInside(parent, candidate) {
  const relative = path.relative(parent, candidate);
  return relative === '' || (!path.isAbsolute(relative) && relative !== '..'
    && !relative.startsWith('..' + path.sep));
}

function validateInstalledResolution(inputValue) {
  try {
    assertDeepPlainData(inputValue);
    const input = plainRecord(inputValue);
    const backendRoot = path.resolve(ownValue(input, 'backendRoot'));
    const expectedPrismaConfigRoot = path.join(
      backendRoot,
      'node_modules',
      '@prisma',
      'config',
    );
    const expectedMergeRoot = path.join(backendRoot, 'node_modules', 'deepmerge-ts');
    const prismaConfigPackageRoot = path.resolve(ownValue(input, 'prismaConfigPackageRoot'));
    const mergeEntryFromPrismaConfig = path.resolve(ownValue(input, 'mergeEntryFromPrismaConfig'));
    const mergeEntryFromRuntime = path.resolve(ownValue(input, 'mergeEntryFromRuntime'));
    const mergePackageRoot = path.resolve(ownValue(input, 'mergePackageRoot'));
    const prismaConfigPackageJson = plainRecord(ownValue(input, 'prismaConfigPackageJson'));
    const mergePackageJson = plainRecord(ownValue(input, 'mergePackageJson'));
    const installedMergePackageRoots = denseArray(ownValue(input, 'installedMergePackageRoots'))
      .map((entry) => path.resolve(entry));

    if (prismaConfigPackageRoot !== expectedPrismaConfigRoot
        || mergePackageRoot !== expectedMergeRoot
        || ownValue(prismaConfigPackageJson, 'name') !== '@prisma/config'
        || ownValue(prismaConfigPackageJson, 'version') !== PINNED_PRISMA_VERSION
        || mergeEntryFromPrismaConfig !== mergeEntryFromRuntime
        || !isInside(mergePackageRoot, mergeEntryFromPrismaConfig)
        || ownValue(mergePackageJson, 'name') !== 'deepmerge-ts'
        || ownValue(mergePackageJson, 'version') !== PINNED_DEEPMERGE_VERSION
        || installedMergePackageRoots.length !== 1
        || installedMergePackageRoots[0] !== expectedMergeRoot) fail();

    return Object.freeze({
      prismaConfigPackageRoot,
      mergePackageRoot,
      mergeEntry: mergeEntryFromPrismaConfig,
    });
  } catch {
    fail();
  }
}

function captureObjectState(value) {
  const keys = reflectOwnKeys(value);
  const descriptors = [];
  for (let index = 0; index < keys.length; index += 1) {
    const descriptor = objectGetOwnPropertyDescriptor(value, keys[index]);
    if (!descriptor) fail();
    descriptors[index] = {
      configurable: descriptor.configurable,
      enumerable: descriptor.enumerable,
      data: hasOwn(descriptor, 'value'),
      value: descriptor.value,
      writable: descriptor.writable,
      get: descriptor.get,
      set: descriptor.set,
    };
  }
  return {
    object: value,
    prototype: objectGetPrototypeOf(value),
    extensible: objectIsExtensible(value),
    sealed: objectIsSealed(value),
    frozen: objectIsFrozen(value),
    keys,
    descriptors,
  };
}

function captureObjectGraphState(...roots) {
  const states = [];
  const pending = [...roots];
  const seen = new PrimordialSet();
  while (pending.length > 0) {
    const value = pending.pop();
    if ((value === null || (typeof value !== 'object' && typeof value !== 'function'))
        || setHas(seen, value)) continue;
    setAdd(seen, value);
    const state = captureObjectState(value);
    states.push(state);
    for (let index = 0; index < state.descriptors.length; index += 1) {
      const descriptor = state.descriptors[index];
      if (descriptor.data && descriptor.value !== null
          && (typeof descriptor.value === 'object' || typeof descriptor.value === 'function')) {
        pending.push(descriptor.value);
      }
    }
  }
  return states;
}

function capturePrimordialState() {
  const primordials = [
    PrimordialObject,
    PrimordialObject.prototype,
    PrimordialArray,
    PrimordialArray.prototype,
    PrimordialFunction,
    PrimordialFunction.prototype,
    PrimordialReflect,
    PrimordialSymbol,
    PrimordialSymbol.prototype,
    PrimordialError,
    PrimordialError.prototype,
    PrimordialSet,
    PrimordialSet.prototype,
    PrimordialNumber,
    PrimordialNumber.prototype,
    utilTypes,
  ];
  const states = [];
  for (let index = 0; index < primordials.length; index += 1) {
    states[index] = captureObjectState(primordials[index]);
  }
  return states;
}

function captureGlobalBindingState() {
  const states = [];
  for (let index = 0; index < primordialGlobalBindings.length; index += 1) {
    const name = primordialGlobalBindings[index][0];
    const expectedValue = primordialGlobalBindings[index][1];
    const descriptor = objectGetOwnPropertyDescriptor(primordialGlobalThis, name);
    if (!descriptor || !hasOwn(descriptor, 'value') || descriptor.value !== expectedValue) fail();
    states[index] = {
      name,
      configurable: descriptor.configurable,
      enumerable: descriptor.enumerable,
      writable: descriptor.writable,
      value: descriptor.value,
    };
  }
  return states;
}

function assertGlobalBindingStateUnchanged(states) {
  for (let index = 0; index < states.length; index += 1) {
    const before = states[index];
    const after = objectGetOwnPropertyDescriptor(primordialGlobalThis, before.name);
    if (!after || !hasOwn(after, 'value')
        || after.configurable !== before.configurable
        || after.enumerable !== before.enumerable
        || after.writable !== before.writable
        || after.value !== before.value) fail();
  }
}

function assertObjectGraphStateUnchanged(states) {
  for (let stateIndex = 0; stateIndex < states.length; stateIndex += 1) {
    const state = states[stateIndex];
    const value = state.object;
    if (objectGetPrototypeOf(value) !== state.prototype
        || objectIsExtensible(value) !== state.extensible
        || objectIsSealed(value) !== state.sealed
        || objectIsFrozen(value) !== state.frozen) fail();
    const keys = reflectOwnKeys(value);
    if (keys.length !== state.keys.length) fail();
    for (let index = 0; index < keys.length; index += 1) {
      if (keys[index] !== state.keys[index]) fail();
      const before = state.descriptors[index];
      const after = objectGetOwnPropertyDescriptor(value, keys[index]);
      if (!after
          || after.configurable !== before.configurable
          || after.enumerable !== before.enumerable
          || hasOwn(after, 'value') !== before.data) fail();
      if (before.data) {
        if (after.writable !== before.writable || !objectIs(after.value, before.value)) fail();
      } else if (after.get !== before.get || after.set !== before.set) fail();
    }
  }
}

function assertMergeOutputGraph(root) {
  if (!root || typeof root !== 'object') fail();
  const pendingValues = [root];
  const pendingDepths = [0];
  const seen = new PrimordialSet();
  let cursor = 0;
  let propertyCount = 0;
  while (cursor < pendingValues.length) {
    const value = pendingValues[cursor];
    const depth = pendingDepths[cursor];
    cursor += 1;
    if (value === null || typeof value === 'boolean'
        || (typeof value === 'number' && numberIsFinite(value))
        || (typeof value === 'string' && value.length <= MAX_STRING_LENGTH)) continue;
    if (!value || typeof value !== 'object' || depth > MAX_DEPTH || isProxy(value)) fail();
    if (setHas(seen, value)) continue;
    setAdd(seen, value);

    const array = arrayIsArray(value);
    const expectedPrototype = array ? PrimordialArray.prototype : PrimordialObject.prototype;
    if (objectGetPrototypeOf(value) !== expectedPrototype) fail();
    const keys = reflectOwnKeys(value);
    if (array) {
      const lengthDescriptor = objectGetOwnPropertyDescriptor(value, 'length');
      if (!lengthDescriptor || !hasOwn(lengthDescriptor, 'value')
          || !numberIsSafeInteger(lengthDescriptor.value) || lengthDescriptor.value < 0
          || keys.length !== lengthDescriptor.value + 1
          || keys[keys.length - 1] !== 'length') fail();
      propertyCount += lengthDescriptor.value;
      if (propertyCount > MAX_PROPERTIES) fail();
      for (let index = 0; index < lengthDescriptor.value; index += 1) {
        if (keys[index] !== numberToString(index)) fail();
        const descriptor = objectGetOwnPropertyDescriptor(value, keys[index]);
        if (!descriptor || !descriptor.enumerable || !hasOwn(descriptor, 'value')) fail();
        pendingValues[pendingValues.length] = descriptor.value;
        pendingDepths[pendingDepths.length] = depth + 1;
      }
    } else {
      propertyCount += keys.length;
      if (propertyCount > MAX_PROPERTIES) fail();
      for (let index = 0; index < keys.length; index += 1) {
        if (typeof keys[index] !== 'string') fail();
        const descriptor = objectGetOwnPropertyDescriptor(value, keys[index]);
        if (!descriptor || !descriptor.enumerable || !hasOwn(descriptor, 'value')) fail();
        pendingValues[pendingValues.length] = descriptor.value;
        pendingDepths[pendingDepths.length] = depth + 1;
      }
    }
  }
}

function mergeOutputValue(record, key) {
  if (!record || typeof record !== 'object' || isProxy(record)) fail();
  const descriptor = objectGetOwnPropertyDescriptor(record, key);
  if (!descriptor || !descriptor.enumerable || !hasOwn(descriptor, 'value')) fail();
  return descriptor.value;
}

const trustedPrimordialState = capturePrimordialState();
const trustedGlobalBindingState = captureGlobalBindingState();

function assertMergeBehavior(deepmerge) {
  try {
    assertObjectGraphStateUnchanged(trustedPrimordialState);
    assertGlobalBindingStateUnchanged(trustedGlobalBindingState);
    if (typeof deepmerge !== 'function') fail();
    const cycleLeft = { schema: 'prisma/schema' };
    const cycleRight = { migrations: { path: 'prisma/migrations' } };
    cycleLeft.self = cycleLeft;
    cycleRight.self = cycleRight;
    const cycleInputsBefore = captureObjectGraphState(cycleLeft, cycleRight);
    const cyclePrimordialsBefore = capturePrimordialState();
    const cycleGlobalsBefore = captureGlobalBindingState();
    const cycleMerged = deepmerge(cycleLeft, cycleRight);
    assertObjectGraphStateUnchanged(cycleInputsBefore);
    assertObjectGraphStateUnchanged(cyclePrimordialsBefore);
    assertGlobalBindingStateUnchanged(cycleGlobalsBefore);
    assertMergeOutputGraph(cycleMerged);
    const cycleMigrations = mergeOutputValue(cycleMerged, 'migrations');
    if (mergeOutputValue(cycleMerged, 'schema') !== 'prisma/schema'
        || mergeOutputValue(cycleMigrations, 'path') !== 'prisma/migrations'
        || mergeOutputValue(cycleMerged, 'self') !== cycleMerged
        || cycleLeft.self !== cycleLeft || cycleRight.self !== cycleRight
        || hasOwn(cycleLeft, 'migrations')
        || hasOwn(cycleRight, 'schema')) fail();
    assertObjectGraphStateUnchanged(cycleInputsBefore);
    assertObjectGraphStateUnchanged(cyclePrimordialsBefore);
    assertGlobalBindingStateUnchanged(cycleGlobalsBefore);

    const ordinaryLeft = {
      schema: 'prisma/schema',
      migrations: { seed: 'tsx prisma/seed.ts' },
      datasource: {
        url: 'postgresql://primary',
        shadowDatabaseUrl: 'postgresql://shadow',
      },
    };
    const ordinaryRight = {
      migrations: { path: 'prisma/migrations' },
      datasource: { url: 'postgresql://override' },
    };
    const ordinaryInputsBefore = captureObjectGraphState(ordinaryLeft, ordinaryRight);
    const ordinaryPrimordialsBefore = capturePrimordialState();
    const ordinaryGlobalsBefore = captureGlobalBindingState();
    const ordinaryMerged = deepmerge(ordinaryLeft, ordinaryRight);
    assertObjectGraphStateUnchanged(ordinaryInputsBefore);
    assertObjectGraphStateUnchanged(ordinaryPrimordialsBefore);
    assertGlobalBindingStateUnchanged(ordinaryGlobalsBefore);
    assertMergeOutputGraph(ordinaryMerged);
    const ordinaryMigrations = mergeOutputValue(ordinaryMerged, 'migrations');
    const ordinaryDatasource = mergeOutputValue(ordinaryMerged, 'datasource');
    if (mergeOutputValue(ordinaryMerged, 'schema') !== 'prisma/schema'
        || mergeOutputValue(ordinaryMigrations, 'seed') !== 'tsx prisma/seed.ts'
        || mergeOutputValue(ordinaryMigrations, 'path') !== 'prisma/migrations'
        || mergeOutputValue(ordinaryDatasource, 'url') !== 'postgresql://override'
        || mergeOutputValue(ordinaryDatasource, 'shadowDatabaseUrl') !== 'postgresql://shadow'
        || ordinaryLeft.migrations.path !== undefined
        || ordinaryLeft.datasource.url !== 'postgresql://primary'
        || ordinaryRight.migrations.seed !== undefined
        || ordinaryRight.datasource.shadowDatabaseUrl !== undefined) fail();
    assertObjectGraphStateUnchanged(ordinaryInputsBefore);
    assertObjectGraphStateUnchanged(ordinaryPrimordialsBefore);
    assertGlobalBindingStateUnchanged(ordinaryGlobalsBefore);
  } catch {
    fail();
  }
}

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, 'utf8'));
}

function packageRootForEntry(entryPath, expectedName, boundary) {
  let cursor = path.dirname(entryPath);
  while (isInside(boundary, cursor)) {
    const candidate = path.join(cursor, 'package.json');
    if (fs.existsSync(candidate)) {
      const packageJson = readJson(candidate);
      if (packageJson && packageJson.name === expectedName) return fs.realpathSync(cursor);
    }
    const parent = path.dirname(cursor);
    if (parent === cursor) break;
    cursor = parent;
  }
  fail();
}

function findInstalledPackageRoots(nodeModulesRoot, expectedName) {
  const roots = [];
  const visited = new Set();
  let visitedPackages = 0;

  function visitPackage(packageRoot, packageName) {
    const metadata = fs.lstatSync(packageRoot);
    if (!metadata.isDirectory() || metadata.isSymbolicLink()) fail();
    const realRoot = fs.realpathSync(packageRoot);
    if (packageName === expectedName) roots.push(realRoot);
    visitedPackages += 1;
    if (visitedPackages > MAX_PROPERTIES) fail();
    const nested = path.join(realRoot, 'node_modules');
    if (fs.existsSync(nested)) visitNodeModules(nested);
  }

  function visitNodeModules(directory) {
    const metadata = fs.lstatSync(directory);
    if (!metadata.isDirectory() || metadata.isSymbolicLink()) fail();
    const realDirectory = fs.realpathSync(directory);
    if (visited.has(realDirectory)) fail();
    visited.add(realDirectory);
    for (const entry of fs.readdirSync(realDirectory, { withFileTypes: true })) {
      if (entry.name === '.bin' || entry.name.startsWith('.')) continue;
      const entryPath = path.join(realDirectory, entry.name);
      if (entry.isSymbolicLink() || !entry.isDirectory()) fail();
      if (entry.name.startsWith('@')) {
        for (const scoped of fs.readdirSync(entryPath, { withFileTypes: true })) {
          if (scoped.isSymbolicLink() || !scoped.isDirectory()) fail();
          visitPackage(path.join(entryPath, scoped.name), entry.name + '/' + scoped.name);
        }
      } else {
        visitPackage(entryPath, entry.name);
      }
    }
  }

  visitNodeModules(nodeModulesRoot);
  return roots.sort();
}

function resolveLiveInstalledGraph(backendRootValue) {
  const backendRoot = fs.realpathSync(path.resolve(backendRootValue));
  const rootRequire = createRequire(path.join(backendRoot, 'package.json'));
  const prismaConfigEntry = fs.realpathSync(rootRequire.resolve('@prisma/config'));
  const prismaConfigPackageRoot = packageRootForEntry(
    prismaConfigEntry,
    '@prisma/config',
    backendRoot,
  );
  const prismaConfigRequire = createRequire(path.join(prismaConfigPackageRoot, 'package.json'));
  const mergeEntryFromPrismaConfig = fs.realpathSync(
    prismaConfigRequire.resolve('deepmerge-ts'),
  );
  const mergeEntryFromRuntime = fs.realpathSync(rootRequire.resolve('deepmerge-ts'));
  const mergePackageRoot = packageRootForEntry(
    mergeEntryFromPrismaConfig,
    'deepmerge-ts',
    backendRoot,
  );
  const prismaConfigPackageJson = readJson(
    path.join(prismaConfigPackageRoot, 'package.json'),
  );
  const mergePackageJson = readJson(path.join(mergePackageRoot, 'package.json'));
  const installedMergePackageRoots = findInstalledPackageRoots(
    path.join(backendRoot, 'node_modules'),
    'deepmerge-ts',
  );

  return {
    backendRoot,
    rootRequire,
    prismaConfigEntry,
    resolution: validateInstalledResolution({
      backendRoot,
      prismaConfigPackageRoot,
      prismaConfigPackageJson,
      mergeEntryFromPrismaConfig,
      mergeEntryFromRuntime,
      mergePackageRoot,
      mergePackageJson,
      installedMergePackageRoots,
    }),
  };
}

function assertInstalledMergeBehavior(mergeEntry) {
  const completionToken = crypto.randomBytes(32).toString('hex');
  const worker = [
    'const checkerPath = process.argv[1];',
    'const mergeEntry = process.argv[2];',
    'const completionToken = process.argv[3];',
    'process.argv.length = 1;',
    'const writeCompletion = process.stdout.write.bind(process.stdout);',
    'const checker = require(checkerPath);',
    'const { deepmerge } = require(mergeEntry);',
    'checker.assertMergeBehavior(deepmerge);',
    'writeCompletion(completionToken);',
  ].join('\n');
  const result = spawnSync(
    process.execPath,
    ['-e', worker, __filename, mergeEntry, completionToken],
    {
    encoding: 'utf8',
    timeout: 2_000,
    windowsHide: true,
    },
  );
  if (result.status !== 0 || result.signal !== null || result.error
      || result.stdout !== completionToken || result.stderr !== '') fail();
}

async function loadRealPrismaConfig({ backendRoot, prismaConfigEntry }) {
  try {
    const prismaConfig = require(prismaConfigEntry);
    if (typeof prismaConfig.loadConfigFromFile !== 'function') fail();
    const result = await prismaConfig.loadConfigFromFile({
      configRoot: backendRoot,
      configFile: 'prisma.config.ts',
    });
    if (!result || !result.config || !Array.isArray(result.diagnostics)
        || result.diagnostics.some((diagnostic) => !diagnostic || diagnostic._tag !== 'log')
        || path.resolve(result.config.schema) !== path.join(backendRoot, 'prisma', 'schema')
        || !result.config.migrations
        || path.resolve(result.config.migrations.path)
          !== path.join(backendRoot, 'prisma', 'migrations')) fail();
    return Object.freeze({ schemaFolder: 'prisma/schema', migrationsFolder: 'prisma/migrations' });
  } catch {
    fail();
  }
}

async function checkPrismaConfigMergeSecurity({ backendRoot = path.resolve(__dirname, '..', '..') } = {}) {
  try {
    const canonicalBackendRoot = fs.realpathSync(path.resolve(backendRoot));
    const packageProof = validatePackageGraph(
      projectR7ArchitectureScripts(readJson(path.join(canonicalBackendRoot, 'package.json'))),
      readJson(path.join(canonicalBackendRoot, 'package-lock.json')),
    );
    const installed = resolveLiveInstalledGraph(canonicalBackendRoot);
    assertInstalledMergeBehavior(installed.resolution.mergeEntry);
    const configProof = await loadRealPrismaConfig({
      backendRoot: canonicalBackendRoot,
      prismaConfigEntry: installed.prismaConfigEntry,
    });
    return Object.freeze({ packageProof, installed: installed.resolution, configProof });
  } catch {
    fail();
  }
}

async function runCli({
  argv = process.argv.slice(2),
  backendRoot = path.resolve(__dirname, '..', '..'),
  stdout = (message) => process.stdout.write(message + '\n'),
  stderr = (message) => process.stderr.write(message + '\n'),
} = {}) {
  if (!Array.isArray(argv) || argv.length !== 1 || argv[0] !== '--check') {
    stderr('ERROR - Prisma config merge security check failed');
    return 2;
  }
  try {
    await checkPrismaConfigMergeSecurity({ backendRoot });
    stdout('PASS - Prisma config merge security');
    return 0;
  } catch {
    stderr('FAIL - Prisma config merge security');
    return 1;
  }
}

module.exports = {
  PINNED_DEEPMERGE_INTEGRITY,
  PINNED_DEEPMERGE_VERSION,
  PINNED_PACKAGE_JSON_SHA256,
  PINNED_PACKAGE_LOCK_SHA256,
  SECURITY_FAILURE,
  assertInstalledMergeBehavior,
  assertMergeBehavior,
  checkPrismaConfigMergeSecurity,
  projectR7ArchitectureScripts,
  fingerprintPlainJson,
  loadRealPrismaConfig,
  runCli,
  validateInstalledResolution,
  validatePackageGraph,
};

if (require.main === module) {
  runCli().then((exitCode) => {
    process.exitCode = exitCode;
  });
}
