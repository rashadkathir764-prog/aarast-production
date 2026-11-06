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
const jsonParse = JSON.parse;
const stringSlice = Function.prototype.call.bind(String.prototype.slice);
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
// Fingerprint of the package security surface (every package.json member
// except `scripts`) of the projected package. The checkpoint guards the
// dependency graph; npm scripts outside the architecture chain (which has
// its own exact projections below) are not a security event, and pinning
// the whole file made every ordinary script addition a false checkpoint
// failure (the 2026-09-13 audit's `smoke:schema-equivalence`).
const PINNED_PACKAGE_JSON_SHA256 =
  'a56a36b0202529f6d74ceb46455d8e696d3717a54b7d9ffc7ab87531b2a6604b';
// Approved lock lineage. Each entry is the canonical fingerprint of one
// approved package-lock: the R12B qs security prerequisite (qs 6.16.0), then
// the R12C security prerequisite (multer 2.3.0, sharp 0.35.4; registry
// advisories GHSA-wc9g-mqfw-jrwm, GHSA-qfvm-cv95-jqjf, GHSA-535w-7cp7-47q4,
// GHSA-qvfw-j98x-7q72, GHSA-rgj7-g3m4-5g8c), then the V1 planning assistant
// (V1 checklist 4.12: the official Anthropic SDK, @anthropic-ai/sdk 0.131.0,
// chosen two weeks after its release), then the V1 release security
// prerequisite (2026-11-06, release audit RA-BE-08: proxy-addr 2.0.8,
// body-parser 2.4.0, engine.io 6.6.11, sharp 0.35.5, @fastify/busboy 3.2.4,
// @grpc/grpc-js 1.14.6, qs 6.16.1, and the overrides multer 2.5.0 and
// brace-expansion 5.0.12; every version resolved with `--before=2026-10-23`,
// so each was public for two weeks). Live callers validate the current lock;
// historical projections re-validate the lock of their own era, so the
// default accepts exactly this lineage and nothing else.
const R12B_PACKAGE_LOCK_SHA256 =
  '6d3f757db4c2ec3f6d5d97168d325a6eae418e0038b3da7dc057340352c2dea3';
const R12C_PACKAGE_LOCK_SHA256 =
  'c1980760454f8ff757b2545fa39b40cee3a233cd28ba88343d16901d339123cb';
const V1_ASSISTANT_PACKAGE_LOCK_SHA256 =
  'f83eaf7fd4063180c276d2dbfe866b30418e1177789e0540c3e0d3257e1e188a';
const PINNED_PACKAGE_LOCK_SHA256 =
  '36142d501155fca2e52ec983a9d860f3406fbfdb68fd65c28666fab4d8e0d6df';
const PACKAGE_LOCK_LINEAGE = Object.freeze([
  R12B_PACKAGE_LOCK_SHA256,
  R12C_PACKAGE_LOCK_SHA256,
  V1_ASSISTANT_PACKAGE_LOCK_SHA256,
  PINNED_PACKAGE_LOCK_SHA256,
]);
const R12B_MULTER_OVERRIDE = '2.2.0';
const R12C_MULTER_OVERRIDE = '2.3.0';
// The V1 release security prerequisite (GHSA-3pph-fpjx-jg34 and
// GHSA-q7qp-rjg7-q26m for multer < 2.5.0; GHSA-q2hr-2g5m-vwhr,
// GHSA-qhr7-859c-m2p7 and GHSA-6j4f-fj2g-mc7p for brace-expansion < 5.0.12).
const V1_SECURITY_MULTER_OVERRIDE = '2.5.0';
const V1_SECURITY_BRACE_EXPANSION_OVERRIDE = '5.0.12';
const PREDECESSOR_BRACE_EXPANSION_OVERRIDE = '5.0.9';
// The planning assistant's SDK (V1 checklist 4.12): pinned to its approved
// minor; the historical chain fingerprints the package without it.
const V1_ASSISTANT_SDK = '@anthropic-ai/sdk';
const V1_ASSISTANT_SDK_RANGE = '^0.131.0';
const R6_ARCHITECTURE_SCRIPT =
  'npm run architecture:imports && npm run architecture:ownership && npm run architecture:ports && npm run architecture:r3 && npm run architecture:r4 && npm run architecture:r5 && npm run architecture:r6';
const R7_ARCHITECTURE_SCRIPT = R6_ARCHITECTURE_SCRIPT + ' && npm run architecture:r7';
const R7_STANDALONE_SCRIPT =
  'node scripts/architecture/r7-collaboration-relocation-scan.cjs --check';
const R8_ARCHITECTURE_SCRIPT = R7_ARCHITECTURE_SCRIPT + ' && npm run architecture:r8';
const R8_STANDALONE_SCRIPT =
  'node scripts/architecture/r8-global-module-removal-scan.cjs --check';
const R12A_ARCHITECTURE_SCRIPT = R8_ARCHITECTURE_SCRIPT + ' && npm run architecture:r12a';
const R12A_STANDALONE_SCRIPT =
  'node scripts/architecture/r12a-backoffice-catalog-public-contracts-scan.cjs --check';
const R12B_ARCHITECTURE_SCRIPT =
  R12A_ARCHITECTURE_SCRIPT + ' && npm run architecture:r12b';
const R12B_STANDALONE_SCRIPT =
  'node scripts/architecture/r12b-planning-public-contracts-scan.cjs --check';
const R12C_ARCHITECTURE_SCRIPT = R12B_ARCHITECTURE_SCRIPT + ' && npm run architecture:r12c';
const R12C_STANDALONE_SCRIPT =
  'node scripts/architecture/r12c-zero-cross-context-dependencies-scan.cjs --check';
const R12C_RETIRED_BASELINE_GENERATOR =
  'depcruise --config .dependency-cruiser.cjs --output-type baseline --output-to .dependency-cruiser-known-violations.json src';
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

// The package.json members the checkpoint pins: everything except `scripts`.
function packageSecuritySurface(value) {
  assertDeepPlainData(value);
  const packageJson = plainRecord(value);
  const surface = {};
  for (const key of reflectOwnKeys(packageJson)) {
    if (key === 'scripts') continue;
    surface[key] = ownValue(packageJson, key);
  }
  return surface;
}

function projectR7ArchitectureScripts(value) {
  assertDeepPlainData(value);
  const packageJson = plainRecord(value);
  const scripts = plainRecord(ownValue(packageJson, 'scripts'));
  const r12bKeys = Object.keys(scripts).filter((key) => key.startsWith('architecture:r12b'));
  const aggregate = optionalOwnValue(scripts, 'architecture');
  if (r12bKeys.length > 0
      || (typeof aggregate === 'string' && aggregate.includes('architecture:r12b'))) {
    return projectR12BArchitectureScripts(packageJson);
  }
  const r12aKeys = Object.keys(scripts).filter((key) => key.startsWith('architecture:r12a'));
  if (r12aKeys.length > 0
      || (typeof aggregate === 'string' && aggregate.includes('architecture:r12a'))) {
    return projectR12AArchitectureScripts(packageJson);
  }
  if (hasOwn(scripts, 'architecture:r8')
      || (typeof aggregate === 'string' && aggregate.includes('architecture:r8'))) {
    return projectR8ArchitectureScripts(packageJson);
  }
  // An aggregate that names the R7 gate without its standalone script is a
  // broken chain, not an R6-era package.
  const r7Keys = Object.keys(scripts).filter((key) => key.startsWith('architecture:r7'));
  if (r7Keys.length === 0 && !(typeof aggregate === 'string' && aggregate.includes('architecture:r7'))) return packageJson;
  if (r7Keys.length !== 1 || r7Keys[0] !== 'architecture:r7'
      || ownValue(scripts, 'architecture:r7') !== R7_STANDALONE_SCRIPT
      || ownValue(scripts, 'architecture') !== R7_ARCHITECTURE_SCRIPT) fail();
  const projectedScripts = { ...scripts };
  delete projectedScripts['architecture:r7'];
  projectedScripts.architecture = R6_ARCHITECTURE_SCRIPT;
  return { ...packageJson, scripts: projectedScripts };
}

function projectR8ArchitectureScripts(value) {
  assertDeepPlainData(value);
  const packageJson = plainRecord(value);
  const scripts = plainRecord(ownValue(packageJson, 'scripts'));
  const r12bKeys = Object.keys(scripts).filter((key) => key.startsWith('architecture:r12b'));
  const aggregate = optionalOwnValue(scripts, 'architecture');
  if (r12bKeys.length > 0
      || (typeof aggregate === 'string' && aggregate.includes('architecture:r12b'))) {
    return projectR12BArchitectureScripts(packageJson);
  }
  const r12aKeys = Object.keys(scripts).filter((key) => key.startsWith('architecture:r12a'));
  if (r12aKeys.length > 0
      || (typeof aggregate === 'string' && aggregate.includes('architecture:r12a'))) {
    return projectR12AArchitectureScripts(packageJson);
  }
  const r8Keys = Object.keys(scripts).filter((key) => key.startsWith('architecture:r8'));
  if (r8Keys.length !== 1 || r8Keys[0] !== 'architecture:r8'
      || ownValue(scripts, 'architecture:r8') !== R8_STANDALONE_SCRIPT
      || ownValue(scripts, 'architecture') !== R8_ARCHITECTURE_SCRIPT) fail();
  const projectedScripts = { ...scripts };
  delete projectedScripts['architecture:r8'];
  projectedScripts.architecture = R7_ARCHITECTURE_SCRIPT;
  return projectR7ArchitectureScripts({ ...packageJson, scripts: projectedScripts });
}

function projectR12AArchitectureScripts(value) {
  assertDeepPlainData(value);
  const packageJson = plainRecord(value);
  const scripts = plainRecord(ownValue(packageJson, 'scripts'));
  const r12bKeys = Object.keys(scripts).filter((key) => key.startsWith('architecture:r12b'));
  const aggregate = optionalOwnValue(scripts, 'architecture');
  if (r12bKeys.length > 0
      || (typeof aggregate === 'string' && aggregate.includes('architecture:r12b'))) {
    return projectR12BArchitectureScripts(packageJson);
  }
  const r12aKeys = Object.keys(scripts).filter((key) => key.startsWith('architecture:r12a'));
  if (r12aKeys.length !== 1 || r12aKeys[0] !== 'architecture:r12a'
      || ownValue(scripts, 'architecture:r12a') !== R12A_STANDALONE_SCRIPT
      || ownValue(scripts, 'architecture') !== R12A_ARCHITECTURE_SCRIPT) fail();
  const projectedScripts = { ...scripts };
  delete projectedScripts['architecture:r12a'];
  projectedScripts.architecture = R8_ARCHITECTURE_SCRIPT;
  return projectR8ArchitectureScripts({ ...packageJson, scripts: projectedScripts });
}

function projectR12BArchitectureScripts(value) {
  assertDeepPlainData(value);
  const packageJson = plainRecord(value);
  const scripts = plainRecord(ownValue(packageJson, 'scripts'));
  const successorKeys = Object.keys(scripts).filter((key) => key.startsWith('architecture:r12c'));
  const aggregate = optionalOwnValue(scripts, 'architecture');
  if (successorKeys.length > 0
      || (typeof aggregate === 'string' && aggregate.includes('architecture:r12c'))) {
    return projectR12CArchitectureScripts(packageJson);
  }
  const keys = Object.keys(scripts).filter((key) => key.startsWith('architecture:r12b'));
  if (keys.length !== 1
      || keys[0] !== 'architecture:r12b'
      || ownValue(scripts, 'architecture:r12b') !== R12B_STANDALONE_SCRIPT
      || ownValue(scripts, 'architecture') !== R12B_ARCHITECTURE_SCRIPT) fail();
  const projectedScripts = { ...scripts };
  delete projectedScripts['architecture:r12b'];
  projectedScripts.architecture = R12A_ARCHITECTURE_SCRIPT;
  return projectR12AArchitectureScripts({
    ...packageJson,
    scripts: projectedScripts,
  });
}

function projectR12CArchitectureScripts(value) {
  assertDeepPlainData(value);
  const packageJson = plainRecord(value);
  const scripts = plainRecord(ownValue(packageJson, 'scripts'));
  const keys = Object.keys(scripts).filter((key) => key.startsWith('architecture:r12c'));
  if (keys.length !== 1 || keys[0] !== 'architecture:r12c'
      || ownValue(scripts, 'architecture:r12c') !== R12C_STANDALONE_SCRIPT
      || ownValue(scripts, 'architecture') !== R12C_ARCHITECTURE_SCRIPT) fail();
  const projectedScripts = { ...scripts };
  delete projectedScripts['architecture:r12c'];
  projectedScripts.architecture = R12B_ARCHITECTURE_SCRIPT;
  const imports = ownValue(scripts, 'architecture:imports');
  const predecessorImports = 'depcruise --config .dependency-cruiser.cjs --ignore-known .dependency-cruiser-known-violations.json src';
  if (imports !== predecessorImports && imports !== 'depcruise --config .dependency-cruiser.cjs src') fail();
  projectedScripts['architecture:imports'] = predecessorImports;
  // R12C Task 5 retired the dependency baseline generator once the strict
  // command was unbaselined: a live package that still (or again) carries it
  // fails, and the projection restores the historical command for the chain.
  const overrides = plainRecord(ownValue(packageJson, 'overrides'));
  const multer = ownValue(overrides, 'multer');
  const projectedOverrides = { ...overrides };
  if (imports === 'depcruise --config .dependency-cruiser.cjs src') {
    if (Object.prototype.hasOwnProperty.call(scripts, 'architecture:imports:baseline')) fail();
    projectedScripts['architecture:imports:baseline'] = R12C_RETIRED_BASELINE_GENERATOR;
    // R12C security prerequisite pinned multer 2.3.0 (with brace-expansion
    // 5.0.9); the V1 release security prerequisite pins multer 2.5.0 and
    // brace-expansion 5.0.12. A strict package carries exactly one era's pair
    // (the R12C scanner rebuilds its own era's package, the live tree carries
    // the newest), never a mix; the lock lineage decides which era's lock
    // goes with it. The historical chain fingerprints the R12B-era multer and
    // the predecessor brace-expansion.
    const braceExpansion = ownValue(overrides, 'brace-expansion');
    const r12cEraPins = multer === R12C_MULTER_OVERRIDE
      && braceExpansion === PREDECESSOR_BRACE_EXPANSION_OVERRIDE;
    const v1SecurityPins = multer === V1_SECURITY_MULTER_OVERRIDE
      && braceExpansion === V1_SECURITY_BRACE_EXPANSION_OVERRIDE;
    if (!r12cEraPins && !v1SecurityPins) fail();
    projectedOverrides.multer = R12B_MULTER_OVERRIDE;
    projectedOverrides['brace-expansion'] = PREDECESSOR_BRACE_EXPANSION_OVERRIDE;
  } else if (multer !== R12B_MULTER_OVERRIDE) fail();
  const dependencies = plainRecord(ownValue(packageJson, 'dependencies'));
  const projectedDependencies = { ...dependencies };
  if (hasOwn(dependencies, V1_ASSISTANT_SDK)) {
    if (ownValue(dependencies, V1_ASSISTANT_SDK) !== V1_ASSISTANT_SDK_RANGE) fail();
    delete projectedDependencies[V1_ASSISTANT_SDK];
  }
  return projectR12BArchitectureScripts({
    ...packageJson,
    dependencies: projectedDependencies,
    scripts: projectedScripts,
    overrides: projectedOverrides,
  });
}

function validatePackageGraph(
  packageJsonValue,
  packageLockValue,
  {
    expectedIntegrity = PINNED_DEEPMERGE_INTEGRITY,
    expectedPackageFingerprint = PINNED_PACKAGE_JSON_SHA256,
    expectedLockFingerprint = PACKAGE_LOCK_LINEAGE,
  } = {},
) {
  try {
    assertDeepPlainData(packageJsonValue);
    assertDeepPlainData(packageLockValue);
    const packageJson = plainRecord(packageJsonValue);
    const packageLock = plainRecord(packageLockValue);
    const acceptedLocks = Array.isArray(expectedLockFingerprint) ? expectedLockFingerprint : [expectedLockFingerprint];
    if (fingerprintPlainJson(packageSecuritySurface(packageJson)) !== expectedPackageFingerprint
        || !acceptedLocks.includes(fingerprintPlainJson(packageLock))) fail();
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

function assertNoDuplicateJsonMembers(source) {
  if (typeof source !== 'string') fail();
  let index = 0;
  let properties = 0;

  function skipWhitespace() {
    while (index < source.length) {
      const code = source.charCodeAt(index);
      if (code !== 0x20 && code !== 0x09 && code !== 0x0a && code !== 0x0d) break;
      index += 1;
    }
  }

  function parseString() {
    if (source.charCodeAt(index) !== 0x22) fail();
    const start = index;
    index += 1;
    while (index < source.length) {
      const code = source.charCodeAt(index);
      if (code === 0x22) {
        index += 1;
        try {
          const value = jsonParse(stringSlice(source, start, index));
          if (typeof value !== 'string') fail();
          return value;
        } catch {
          fail();
        }
      }
      if (code < 0x20) fail();
      if (code === 0x5c) {
        index += 1;
        if (index >= source.length) fail();
        if (source.charCodeAt(index) === 0x75) {
          index += 4;
          if (index >= source.length) fail();
        }
      }
      index += 1;
    }
    fail();
  }

  function parsePrimitive() {
    const start = index;
    while (index < source.length) {
      const code = source.charCodeAt(index);
      if (code === 0x2c || code === 0x5d || code === 0x7d
          || code === 0x20 || code === 0x09 || code === 0x0a || code === 0x0d) break;
      index += 1;
    }
    if (start === index) fail();
    try {
      jsonParse(stringSlice(source, start, index));
    } catch {
      fail();
    }
  }

  function countProperty() {
    properties += 1;
    if (properties > MAX_PROPERTIES) fail();
  }

  function parseValue(depth) {
    if (depth > MAX_DEPTH) fail();
    skipWhitespace();
    const code = source.charCodeAt(index);
    if (code === 0x7b) {
      index += 1;
      skipWhitespace();
      const keys = new PrimordialSet();
      if (source.charCodeAt(index) === 0x7d) {
        index += 1;
        return;
      }
      while (index < source.length) {
        const key = parseString();
        if (setHas(keys, key)) fail();
        setAdd(keys, key);
        countProperty();
        skipWhitespace();
        if (source.charCodeAt(index) !== 0x3a) fail();
        index += 1;
        parseValue(depth + 1);
        skipWhitespace();
        const separator = source.charCodeAt(index);
        if (separator === 0x7d) {
          index += 1;
          return;
        }
        if (separator !== 0x2c) fail();
        index += 1;
        skipWhitespace();
      }
      fail();
    }
    if (code === 0x5b) {
      index += 1;
      skipWhitespace();
      if (source.charCodeAt(index) === 0x5d) {
        index += 1;
        return;
      }
      while (index < source.length) {
        countProperty();
        parseValue(depth + 1);
        skipWhitespace();
        const separator = source.charCodeAt(index);
        if (separator === 0x5d) {
          index += 1;
          return;
        }
        if (separator !== 0x2c) fail();
        index += 1;
      }
      fail();
    }
    if (code === 0x22) {
      parseString();
      return;
    }
    parsePrimitive();
  }

  parseValue(0);
  skipWhitespace();
  if (index !== source.length) fail();
}

function readJson(filePath) {
  const source = fs.readFileSync(filePath, 'utf8');
  assertNoDuplicateJsonMembers(source);
  return jsonParse(source);
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
      projectR12BArchitectureScripts(readJson(path.join(canonicalBackendRoot, 'package.json'))),
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
  PACKAGE_LOCK_LINEAGE,
  PINNED_DEEPMERGE_INTEGRITY,
  PINNED_DEEPMERGE_VERSION,
  PINNED_PACKAGE_JSON_SHA256,
  PINNED_PACKAGE_LOCK_SHA256,
  R12B_PACKAGE_LOCK_SHA256,
  R12C_PACKAGE_LOCK_SHA256,
  V1_ASSISTANT_PACKAGE_LOCK_SHA256,
  V1_ASSISTANT_SDK_RANGE,
  V1_SECURITY_BRACE_EXPANSION_OVERRIDE,
  V1_SECURITY_MULTER_OVERRIDE,
  R12A_ARCHITECTURE_SCRIPT,
  R12A_STANDALONE_SCRIPT,
  R12B_ARCHITECTURE_SCRIPT,
  R12B_STANDALONE_SCRIPT,
  R12C_ARCHITECTURE_SCRIPT,
  R12C_STANDALONE_SCRIPT,
  R8_ARCHITECTURE_SCRIPT,
  R8_STANDALONE_SCRIPT,
  SECURITY_FAILURE,
  assertInstalledMergeBehavior,
  assertMergeBehavior,
  checkPrismaConfigMergeSecurity,
  projectR12AArchitectureScripts,
  projectR12BArchitectureScripts,
  projectR12CArchitectureScripts,
  projectR7ArchitectureScripts,
  projectR8ArchitectureScripts,
  fingerprintPlainJson,
  packageSecuritySurface,
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
