'use strict';

const crypto = require('node:crypto');
const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const { types: utilTypes } = require('node:util');
const ts = require('typescript');

const R6_BASE = 'ce0c0d19824bff79d91417e2fe4617914c6bcd70';
const MANIFEST_PATH = 'backend/architecture/r6-sharing-otp-transport.json';
const STAGES = Object.freeze(['inventory', 'task-2', 'task-3', 'strict']);
const MAX_ARRAY_ITEMS = 256;
const MAX_TEXT_LENGTH = 4096;
const R7_HISTORICAL_DEPENDENCY_HASH =
  '82f08c01aa76b18e1d64b725358ebac335750ffee7fe7b0898ea9c34b7c25a42';
const R7_LIVE_DEPENDENCY_HASH =
  'c0290a046009d7fe81f420323da0792af38cd7bc3adb37a8eb4df7c4986a46cc';
const R7_RETIRED_DEPENDENCY_KEYS = Object.freeze([
  'context-finance-cross-context|src/budget-categories/budget-categories.service.ts|src/contribution-history/contribution-snapshot.builder.ts',
  'context-finance-cross-context|src/wedding-costs/wedding-costs.service.ts|src/contribution-history/contribution-snapshot.builder.ts',
  'context-guests-cross-context|src/guests/guests.service.ts|src/contribution-history/contribution-snapshot.builder.ts',
  'context-marketplace-cross-context|src/marketplace/quote-offer-acceptance.ts|src/contribution-history/contribution-snapshot.builder.ts',
  'context-marketplace-cross-context|src/marketplace/quote-offer-rejection.ts|src/contribution-history/contribution-snapshot.builder.ts',
  'context-marketplace-cross-context|src/marketplace/quote-request-cancellation.ts|src/contribution-history/contribution-snapshot.builder.ts',
  'context-marketplace-cross-context|src/marketplace/quote-request-creation.ts|src/contribution-history/contribution-snapshot.builder.ts',
  'context-planning-cross-context|src/wedding-plans/wedding-plans.service.ts|src/contribution-history/contribution-snapshot.builder.ts',
  'context-tasks-cross-context|src/tasks/tasks.service.ts|src/contribution-history/contribution-snapshot.builder.ts',
]);

const EXPECTED_CURRENT_DEPENDENCY = Object.freeze({
  consumer: 'backend/src/sharing/invitation-delivery.service.ts',
  transport: 'backend/src/platform/otp-transport/openwa-transient-text.ts',
  declarations: Object.freeze([
    'OpenWaTransientDeliveryRejectedError',
    'OpenWaTransientDeliveryUncertainError',
    'sendOpenWaTransientText',
  ]),
});

const EXPECTED_TARGET_BOUNDARY = Object.freeze({
  adapterPath: 'backend/src/modules/identity/internal/identity-transient-delivery.adapter.ts',
  collaborationModulePath:
    'backend/src/modules/collaboration/internal/collaboration-services.internal.module.ts',
  consumerPath: 'backend/src/sharing/invitation-delivery.service.ts',
  identityModulePath: 'backend/src/modules/identity/identity.module.ts',
  implementationToken: 'IDENTITY_TRANSIENT_DELIVERY_IMPLEMENTATION',
  inputType: 'IdentityTransientDeliveryInput',
  internalModulePath:
    'backend/src/modules/identity/internal/identity-transient-delivery.internal.module.ts',
  portInterface: 'IdentityTransientDeliveryPort',
  publicErrors: Object.freeze([
    'IdentityTransientDeliveryRejectedError',
    'IdentityTransientDeliveryUncertainError',
  ]),
  publicModulePath:
    'backend/src/modules/identity/public/identity-transient-delivery-public.module.ts',
  publicPortPath:
    'backend/src/modules/identity/public/identity-transient-delivery.port.ts',
  token: 'IDENTITY_TRANSIENT_DELIVERY_PORT',
});

const EXPECTED_PROTECTED_FILES = Object.freeze([
  Object.freeze({
    path: 'backend/src/platform/otp-transport/openwa-otp.channel.ts',
    sha256: '1f939561064a0d8c8bfe6142d9793c2b670557ff620bec1c0fec95669837fd50',
  }),
  Object.freeze({
    path: 'backend/src/platform/otp-transport/openwa-transient-text.ts',
    sha256: '9b53d04193876cd0258dc367685fbf6bb8e6d23845bfc8a1e501512a2a68b5ac',
  }),
]);

const EXPECTED_BASELINES = Object.freeze({
  dependencyRecords: 31,
  ownershipRecords: 385,
  ownershipOccurrences: 781,
  concreteTransportImports: Object.freeze({
    inventory: 1,
    'task-2': 1,
    'task-3': 0,
    strict: 0,
  }),
});

const EXPECTED_ALLOWED_PATHS = Object.freeze([
  'ARCHITECTURE.md',
  'backend/architecture/r3-context-boundaries.json',
  'backend/architecture/r6-sharing-otp-transport.json',
  'backend/package.json',
  'backend/scripts/architecture/r3-context-scan.cjs',
  'backend/scripts/architecture/r3-scope.cjs',
  'backend/scripts/architecture/r5-identity-scan.cjs',
  'backend/scripts/architecture/r6-sharing-otp-transport-scan.cjs',
  'backend/scripts/security/prisma-config-merge-security.cjs',
  'backend/src/modules/collaboration/internal/collaboration-services.internal.module.ts',
  'backend/src/modules/identity/identity.module.ts',
  'backend/src/modules/identity/internal/identity-transient-delivery.adapter.ts',
  'backend/src/modules/identity/internal/identity-transient-delivery.internal.module.ts',
  'backend/src/modules/identity/public/identity-transient-delivery-public.module.ts',
  'backend/src/modules/identity/public/identity-transient-delivery.port.ts',
  'backend/src/sharing/invitation-delivery.service.ts',
  'backend/test/architecture-ownership.test.ts',
  'backend/test/architecture-r1-baseline-relocation.test.ts',
  'backend/test/architecture-r1-layout.test.ts',
  'backend/test/architecture-r3-contexts.test.ts',
  'backend/test/architecture-r3-scope.test.ts',
  'backend/test/architecture-r4-planning-finance-boundary.test.ts',
  'backend/test/architecture-r5-identity-relocation.test.ts',
  'backend/test/architecture-r6-sharing-otp-transport.test.ts',
  'backend/test/invite-delivery.test.ts',
  'backend/test/prisma-dmmf-fingerprint.test.ts',
  'docs/README.md',
  'docs/SCRIPTS.md',
  'docs/project/DECISIONS.md',
  'docs/project/EXECUTION_PLAN.md',
  'docs/project/STATUS.md',
  'docs/qa/README.md',
  'docs/superpowers/plans/2026-08-22-modular-monolith-r6-sharing-otp-transport-port-completion.md',
  'docs/superpowers/plans/2026-08-22-modular-monolith-r6-sharing-otp-transport-port.md',
  'docs/superpowers/specs/2026-08-22-modular-monolith-r6-sharing-otp-transport-port-completion.md',
  'docs/superpowers/specs/2026-08-22-modular-monolith-r6-sharing-otp-transport-port-design.md',
]);

function plainObject(value, label) {
  if (!value || typeof value !== 'object' || Array.isArray(value)
      || utilTypes.isProxy(value) || Object.getPrototypeOf(value) !== Object.prototype) {
    throw new Error(label + ' must be a plain object');
  }
  for (const key of Reflect.ownKeys(value)) {
    const descriptor = Object.getOwnPropertyDescriptor(value, key);
    if (typeof key !== 'string' || !descriptor || !descriptor.enumerable
        || !Object.prototype.hasOwnProperty.call(descriptor, 'value')) {
      throw new Error(label + ' must use plain data properties');
    }
  }
  return value;
}

function denseArray(value, label) {
  if (!Array.isArray(value) || utilTypes.isProxy(value)
      || Object.getPrototypeOf(value) !== Array.prototype
      || value.length > MAX_ARRAY_ITEMS) {
    throw new Error(label + ' must be a bounded plain array');
  }
  for (let index = 0; index < value.length; index += 1) {
    const descriptor = Object.getOwnPropertyDescriptor(value, String(index));
    if (!descriptor || !descriptor.enumerable
        || !Object.prototype.hasOwnProperty.call(descriptor, 'value')) {
      throw new Error(label + ' must be dense plain data');
    }
  }
  if (Reflect.ownKeys(value).length !== value.length + 1) {
    throw new Error(label + ' must contain array data only');
  }
  return value;
}

function assertDeepPlainData(value, label, seen = new Set(), depth = 0) {
  if (value === null || typeof value === 'boolean'
      || (typeof value === 'number' && Number.isFinite(value))
      || (typeof value === 'string' && value.length <= MAX_TEXT_LENGTH)) return;
  if (!value || typeof value !== 'object' || depth > 32 || seen.has(value)) {
    throw new Error(label + ' must be bounded plain data');
  }
  seen.add(value);
  if (Array.isArray(value)) {
    const array = denseArray(value, label);
    for (let index = 0; index < array.length; index += 1) {
      assertDeepPlainData(array[index], label + '[' + index + ']', seen, depth + 1);
    }
  } else {
    const object = plainObject(value, label);
    for (const key of Object.keys(object)) {
      assertDeepPlainData(object[key], label + '.' + key, seen, depth + 1);
    }
  }
  seen.delete(value);
}

function exactObject(value, keys, label) {
  const object = plainObject(value, label);
  if (JSON.stringify(Object.keys(object).sort()) !== JSON.stringify([...keys].sort())) {
    throw new Error(label + ' keys are invalid');
  }
  return object;
}

function relativePath(value, label) {
  if (typeof value !== 'string' || value.length === 0 || value.length > MAX_TEXT_LENGTH
      || value.includes('\\') || path.posix.isAbsolute(value) || path.win32.isAbsolute(value)
      || value.split('/').includes('.') || value.split('/').includes('..')
      || /[*?\[\]\u0000-\u001f]/u.test(value)) {
    throw new Error(label + ' contains an invalid path');
  }
  return value;
}

function stringValue(value, label) {
  if (typeof value !== 'string' || value.length === 0 || value.length > MAX_TEXT_LENGTH
      || /[\u0000-\u001f]/u.test(value)) {
    throw new Error(label + ' is invalid');
  }
  return value;
}

function sortedUniqueStrings(value, label, pathValues = false) {
  const result = denseArray(value, label).map((entry, index) => (
    pathValues
      ? relativePath(entry, label + '[' + index + ']')
      : stringValue(entry, label + '[' + index + ']')
  ));
  if (new Set(result).size !== result.length
      || JSON.stringify(result) !== JSON.stringify([...result].sort())) {
    throw new Error(label + ' must be sorted and unique');
  }
  return result;
}

function assertExactValue(actual, expected, label) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(label + ' drift detected');
  }
}

function validateCurrentDependency(value) {
  const input = exactObject(
    value,
    ['consumer', 'transport', 'declarations'],
    'R6 current concrete dependency',
  );
  const result = {
    consumer: relativePath(input.consumer, 'R6 current consumer'),
    transport: relativePath(input.transport, 'R6 current transport'),
    declarations: sortedUniqueStrings(
      input.declarations,
      'R6 current declarations',
    ),
  };
  assertExactValue(result, EXPECTED_CURRENT_DEPENDENCY, 'R6 current dependency');
  return Object.freeze({
    ...result,
    declarations: Object.freeze(result.declarations),
  });
}

function dependencyRecordKey(record) {
  return `${record.rule && record.rule.name}|${record.from}|${record.to}`;
}

function verifyR7DependencyHandoff(options) {
  const input = exactObject(options, [
    'historicalDependency', 'liveDependency',
  ], 'R7 dependency handoff input');
  assertDeepPlainData(input.historicalDependency, 'R7 historical dependency');
  if (!Array.isArray(input.historicalDependency)
      || input.historicalDependency.length !== 31
      || crypto.createHash('sha256').update(JSON.stringify(input.historicalDependency)).digest('hex')
        !== R7_HISTORICAL_DEPENDENCY_HASH) {
    throw new Error('R7 historical dependency identity is invalid');
  }
  assertDeepPlainData(input.liveDependency, 'R7 live dependency');
  if (!Array.isArray(input.liveDependency)) {
    throw new Error('R7 live dependency is invalid');
  }
  const retired = new Set(R7_RETIRED_DEPENDENCY_KEYS);
  const expectedLive = input.historicalDependency.filter(
    (record) => !retired.has(dependencyRecordKey(record)),
  );
  if (expectedLive.length !== 22 || input.liveDependency.length !== 22
      || JSON.stringify(input.liveDependency) !== JSON.stringify(expectedLive)) {
    throw new Error('R7 live dependency projection is invalid');
  }
  return Object.freeze({
    historicalDependencyRecords: input.historicalDependency.length,
    liveDependencyRecords: input.liveDependency.length,
    retiredDependencyRecords: input.historicalDependency.length - input.liveDependency.length,
  });
}

function validateTargetBoundary(value) {
  const keys = [
    'adapterPath',
    'collaborationModulePath',
    'consumerPath',
    'identityModulePath',
    'implementationToken',
    'inputType',
    'internalModulePath',
    'portInterface',
    'publicErrors',
    'publicModulePath',
    'publicPortPath',
    'token',
  ];
  const input = exactObject(value, keys, 'R6 target boundary');
  const result = {
    adapterPath: relativePath(
      input.adapterPath,
      'R6 target boundary.adapterPath',
    ),
    collaborationModulePath: relativePath(
      input.collaborationModulePath,
      'R6 target boundary.collaborationModulePath',
    ),
    consumerPath: relativePath(
      input.consumerPath,
      'R6 target boundary.consumerPath',
    ),
    identityModulePath: relativePath(
      input.identityModulePath,
      'R6 target boundary.identityModulePath',
    ),
    implementationToken: stringValue(
      input.implementationToken,
      'R6 target boundary.implementationToken',
    ),
    inputType: stringValue(
      input.inputType,
      'R6 target boundary.inputType',
    ),
    internalModulePath: relativePath(
      input.internalModulePath,
      'R6 target boundary.internalModulePath',
    ),
    portInterface: stringValue(
      input.portInterface,
      'R6 target boundary.portInterface',
    ),
    publicErrors: sortedUniqueStrings(
      input.publicErrors,
      'R6 target boundary public errors',
    ),
    publicModulePath: relativePath(
      input.publicModulePath,
      'R6 target boundary.publicModulePath',
    ),
    publicPortPath: relativePath(
      input.publicPortPath,
      'R6 target boundary.publicPortPath',
    ),
    token: stringValue(
      input.token,
      'R6 target boundary.token',
    ),
  };
  assertExactValue(result, EXPECTED_TARGET_BOUNDARY, 'R6 target boundary');
  return Object.freeze({
    ...result,
    publicErrors: Object.freeze(result.publicErrors),
  });
}

function validateProtectedFiles(value) {
  const result = denseArray(value, 'R6 protected files').map((entry, index) => {
    const file = exactObject(
      entry,
      ['path', 'sha256'],
      'R6 protected files[' + index + ']',
    );
    const sha256 = stringValue(file.sha256, 'R6 protected sha256');
    if (!/^[a-f0-9]{64}$/u.test(sha256)) {
      throw new Error('R6 protected sha256 is invalid');
    }
    return Object.freeze({
      path: relativePath(file.path, 'R6 protected path'),
      sha256,
    });
  });
  const paths = result.map((entry) => entry.path);
  if (new Set(paths).size !== paths.length
      || JSON.stringify(paths) !== JSON.stringify([...paths].sort())) {
    throw new Error('R6 protected files must be sorted and unique');
  }
  assertExactValue(result, EXPECTED_PROTECTED_FILES, 'R6 protected files');
  return result;
}

function validateExpectedBaselines(value) {
  const input = exactObject(value, [
    'dependencyRecords',
    'ownershipRecords',
    'ownershipOccurrences',
    'concreteTransportImports',
  ], 'R6 expected baselines');
  const imports = exactObject(
    input.concreteTransportImports,
    STAGES,
    'R6 concrete transport imports',
  );
  const result = {
    dependencyRecords: input.dependencyRecords,
    ownershipRecords: input.ownershipRecords,
    ownershipOccurrences: input.ownershipOccurrences,
    concreteTransportImports: {
      inventory: imports.inventory,
      'task-2': imports['task-2'],
      'task-3': imports['task-3'],
      strict: imports.strict,
    },
  };
  for (const valueToCheck of [
    result.dependencyRecords,
    result.ownershipRecords,
    result.ownershipOccurrences,
    ...Object.values(result.concreteTransportImports),
  ]) {
    if (!Number.isSafeInteger(valueToCheck) || valueToCheck < 0) {
      throw new Error('R6 expected baseline value is invalid');
    }
  }
  assertExactValue(result, EXPECTED_BASELINES, 'R6 expected baselines');
  return Object.freeze({
    ...result,
    concreteTransportImports: Object.freeze(result.concreteTransportImports),
  });
}

function validateR6Manifest(value) {
  assertDeepPlainData(value, 'R6 Sharing OTP transport manifest');
  const manifest = exactObject(value, [
    'schemaVersion',
    'baseRevision',
    'stage',
    'currentConcreteDependency',
    'targetBoundary',
    'protectedFiles',
    'expectedBaselines',
    'allowedChangedPaths',
  ], 'R6 Sharing OTP transport manifest');
  if (manifest.schemaVersion !== 1 || manifest.baseRevision !== R6_BASE) {
    throw new Error('R6 Sharing OTP transport manifest identity is invalid');
  }
  if (!STAGES.includes(manifest.stage)) {
    throw new Error('R6 Sharing OTP transport manifest stage is invalid');
  }
  const currentConcreteDependency = validateCurrentDependency(
    manifest.currentConcreteDependency,
  );
  const targetBoundary = validateTargetBoundary(manifest.targetBoundary);
  const protectedFiles = validateProtectedFiles(manifest.protectedFiles);
  const expectedBaselines = validateExpectedBaselines(manifest.expectedBaselines);
  const allowedChangedPaths = sortedUniqueStrings(
    manifest.allowedChangedPaths,
    'R6 allowed changed paths',
    true,
  );
  assertExactValue(allowedChangedPaths, EXPECTED_ALLOWED_PATHS, 'R6 allowed changed paths');
  return Object.freeze({
    schemaVersion: 1,
    baseRevision: R6_BASE,
    stage: manifest.stage,
    currentConcreteDependency,
    targetBoundary,
    protectedFiles: Object.freeze(protectedFiles),
    expectedBaselines,
    allowedChangedPaths: Object.freeze(allowedChangedPaths),
  });
}

function isInside(parent, candidate) {
  const relative = path.relative(parent, candidate);
  return relative === ''
    || (!path.isAbsolute(relative) && relative !== '..'
      && !relative.startsWith('..' + path.sep));
}

function safeFile(repositoryRoot, relative, label) {
  const canonicalRoot = (fs.realpathSync.native || fs.realpathSync)(repositoryRoot);
  const parts = relative.split('/');
  const absolute = path.resolve(repositoryRoot, ...parts);
  if (!isInside(path.resolve(repositoryRoot), absolute)) {
    throw new Error(label + ' escapes repository');
  }
  let cursor = path.resolve(repositoryRoot);
  for (const part of parts) {
    cursor = path.join(cursor, part);
    const status = fs.lstatSync(cursor);
    if (status.isSymbolicLink()) throw new Error(label + ' contains a symbolic link');
  }
  const status = fs.lstatSync(absolute);
  if (!status.isFile()) throw new Error(label + ' is not a file');
  const canonical = (fs.realpathSync.native || fs.realpathSync)(absolute);
  if (!isInside(canonicalRoot, canonical)) throw new Error(label + ' escapes repository');
  return canonical;
}

function sha256(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}

function verifyProtectedFiles(options) {
  const repositoryRoot = options.repositoryRoot;
  const manifest = options.manifest;
  const readBaseFile = options.readBaseFile || ((relative) => execFileSync(
    'git',
    ['show', R6_BASE + ':' + relative],
    { cwd: repositoryRoot, maxBuffer: 16 * 1024 * 1024 },
  ));
  for (const protectedFile of manifest.protectedFiles) {
    const baseValue = readBaseFile(protectedFile.path);
    if (!Buffer.isBuffer(baseValue)) {
      throw new Error('R6 protected base reader must return a Buffer');
    }
    if (sha256(baseValue) !== protectedFile.sha256) {
      throw new Error('R6 protected base hash drift detected');
    }
    const current = fs.readFileSync(safeFile(
      repositoryRoot,
      protectedFile.path,
      'R6 protected file',
    ));
    if (sha256(current) !== protectedFile.sha256) {
      throw new Error('R6 protected file hash drift detected');
    }
  }
  return manifest.protectedFiles.length;
}

function verifyBaselines(repositoryRoot, manifest) {
  const dependency = JSON.parse(fs.readFileSync(safeFile(
    repositoryRoot,
    'backend/.dependency-cruiser-known-violations.json',
    'R6 dependency baseline',
  ), 'utf8'));
  if (!Array.isArray(dependency)
      || manifest.expectedBaselines.dependencyRecords !== 31
      || dependency.length !== 22
      || crypto.createHash('sha256').update(JSON.stringify(dependency)).digest('hex')
        !== R7_LIVE_DEPENDENCY_HASH) {
    throw new Error('R6 dependency baseline count drift detected');
  }
  const ownership = JSON.parse(fs.readFileSync(safeFile(
    repositoryRoot,
    'backend/architecture/ownership-baseline.json',
    'R6 ownership baseline',
  ), 'utf8'));
  if (!ownership || !Array.isArray(ownership.violations)
      || ownership.violations.length !== manifest.expectedBaselines.ownershipRecords) {
    throw new Error('R6 ownership baseline record drift detected');
  }
  const occurrences = ownership.violations.reduce((sum, entry) => {
    if (!entry || !Number.isSafeInteger(entry.count) || entry.count < 1) {
      throw new Error('R6 ownership baseline occurrence is invalid');
    }
    return sum + entry.count;
  }, 0);
  if (occurrences !== manifest.expectedBaselines.ownershipOccurrences) {
    throw new Error('R6 ownership baseline occurrence drift detected');
  }
}

function collectTypeScriptFiles(root) {
  if (!fs.existsSync(root)) return [];
  const status = fs.lstatSync(root);
  if (status.isSymbolicLink() || !status.isDirectory()) {
    throw new Error('R6 Collaboration source root is invalid');
  }
  const result = [];
  const visit = (directory) => {
    for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
      const absolute = path.join(directory, entry.name);
      if (entry.isSymbolicLink()) {
        throw new Error('R6 Collaboration source contains a symbolic link');
      }
      if (entry.isDirectory()) visit(absolute);
      else if (entry.isFile() && entry.name.endsWith('.ts')) result.push(absolute);
    }
  };
  visit(root);
  return result;
}

function compilerOptions(repositoryRoot) {
  const configPath = path.join(repositoryRoot, 'backend', 'tsconfig.json');
  if (!fs.existsSync(configPath)) {
    return {
      module: ts.ModuleKind.CommonJS,
      moduleResolution: ts.ModuleResolutionKind.NodeJs,
      target: ts.ScriptTarget.ES2020,
    };
  }
  const config = ts.readConfigFile(configPath, ts.sys.readFile);
  if (config.error) throw new Error('R6 TypeScript config is unreadable');
  const parsed = ts.parseJsonConfigFileContent(
    config.config,
    ts.sys,
    path.dirname(configPath),
  );
  if (parsed.errors.length > 0) throw new Error('R6 TypeScript config is invalid');
  return parsed.options;
}

function importedNames(node) {
  if (!node.importClause || !node.importClause.namedBindings
      || !ts.isNamedImports(node.importClause.namedBindings)) return [];
  return node.importClause.namedBindings.elements
    .map((element) => (
      element.propertyName ? element.propertyName.text : element.name.text
    ))
    .sort();
}

function moduleReferences(sourceFile) {
  const result = [];
  const visit = (node) => {
    if (ts.isImportDeclaration(node) && ts.isStringLiteral(node.moduleSpecifier)) {
      result.push({
        specifier: node.moduleSpecifier.text,
        declarations: importedNames(node),
      });
    } else if (ts.isImportEqualsDeclaration(node)
        && ts.isExternalModuleReference(node.moduleReference)
        && node.moduleReference.expression
        && ts.isStringLiteral(node.moduleReference.expression)) {
      result.push({
        specifier: node.moduleReference.expression.text,
        declarations: ['<import-equals>'],
      });
    } else if (ts.isCallExpression(node) && node.arguments.length === 1
        && ts.isStringLiteral(node.arguments[0])
        && ((ts.isIdentifier(node.expression) && node.expression.text === 'require')
          || node.expression.kind === ts.SyntaxKind.ImportKeyword)) {
      result.push({
        specifier: node.arguments[0].text,
        declarations: ['<dynamic>'],
      });
    }
    ts.forEachChild(node, visit);
  };
  visit(sourceFile);
  return result;
}

function inspectConcreteTransportImports(repositoryRoot, manifest) {
  const options = compilerOptions(repositoryRoot);
  const transport = safeFile(
    repositoryRoot,
    manifest.currentConcreteDependency.transport,
    'R6 concrete transport',
  );
  const transportDirectory = path.dirname(path.resolve(transport));
  const roots = [
    path.join(repositoryRoot, 'backend', 'src', 'sharing'),
    path.join(repositoryRoot, 'backend', 'src', 'contribution-history'),
    path.join(repositoryRoot, 'backend', 'src', 'modules', 'collaboration'),
  ];
  const files = roots.flatMap(collectTypeScriptFiles).sort();
  const imports = [];
  for (const file of files) {
    const source = ts.createSourceFile(
      file,
      fs.readFileSync(file, 'utf8'),
      ts.ScriptTarget.Latest,
      true,
      ts.ScriptKind.TS,
    );
    for (const reference of moduleReferences(source)) {
      const resolved = ts.resolveModuleName(
        reference.specifier,
        file,
        options,
        ts.sys,
      ).resolvedModule;
      if (!resolved) continue;
      const resolvedPath = path.resolve(resolved.resolvedFileName);
      if (!isInside(transportDirectory, resolvedPath)) continue;
      imports.push(Object.freeze({
        file: path.relative(repositoryRoot, file).split(path.sep).join('/'),
        target: path.relative(repositoryRoot, resolvedPath).split(path.sep).join('/'),
        declarations: Object.freeze(reference.declarations),
      }));
    }
  }
  return Object.freeze(imports);
}

function verifyTargetStage(repositoryRoot, manifest) {
  const newPaths = [
    manifest.targetBoundary.adapterPath,
    manifest.targetBoundary.internalModulePath,
    manifest.targetBoundary.publicModulePath,
    manifest.targetBoundary.publicPortPath,
  ];
  const targetMustExist = STAGES.indexOf(manifest.stage) >= STAGES.indexOf('task-2');
  for (const relative of newPaths) {
    const absolute = path.join(repositoryRoot, ...relative.split('/'));
    if (fs.existsSync(absolute) !== targetMustExist) {
      throw new Error('R6 target boundary stage does not match the filesystem');
    }
  }
}

function scanR6SharingOtpTransport(options) {
  const input = plainObject(options, 'R6 scan options');
  const keys = Object.keys(input).sort();
  if (keys.some((key) => !['manifest', 'readBaseFile', 'repositoryRoot'].includes(key))
      || !keys.includes('manifest') || !keys.includes('repositoryRoot')) {
    throw new Error('R6 scan options keys are invalid');
  }
  const manifest = validateR6Manifest(input.manifest);
  if (typeof input.repositoryRoot !== 'string' || !path.isAbsolute(input.repositoryRoot)) {
    throw new Error('R6 repository root must be absolute');
  }
  if (input.readBaseFile !== undefined && typeof input.readBaseFile !== 'function') {
    throw new Error('R6 base reader is invalid');
  }
  verifyTargetStage(input.repositoryRoot, manifest);
  const protectedFiles = verifyProtectedFiles({
    repositoryRoot: input.repositoryRoot,
    manifest,
    readBaseFile: input.readBaseFile,
  });
  verifyBaselines(input.repositoryRoot, manifest);
  const imports = inspectConcreteTransportImports(input.repositoryRoot, manifest);
  const expectedImports = manifest.expectedBaselines
    .concreteTransportImports[manifest.stage];
  if (imports.length !== expectedImports) {
    throw new Error('R6 concrete transport import count drift detected');
  }
  if (expectedImports === 1) {
    const [current] = imports;
    if (current.file !== manifest.currentConcreteDependency.consumer
        || current.target !== manifest.currentConcreteDependency.transport
        || JSON.stringify(current.declarations)
          !== JSON.stringify(manifest.currentConcreteDependency.declarations)) {
      throw new Error('R6 concrete transport import contract drift detected');
    }
  }
  return Object.freeze({
    ok: true,
    stage: manifest.stage,
    concreteImports: imports.length,
    protectedFiles,
  });
}

function runCli(dependencies = {}) {
  const argv = dependencies.argv || process.argv.slice(2);
  const repositoryRoot = dependencies.repositoryRoot
    || path.resolve(__dirname, '../../..');
  const stdout = dependencies.stdout
    || ((message) => process.stdout.write(message + '\n'));
  const stderr = dependencies.stderr
    || ((message) => process.stderr.write(message + '\n'));
  try {
    if (argv.length !== 1 || argv[0] !== '--check') {
      throw new Error('invalid arguments');
    }
    const manifest = JSON.parse(fs.readFileSync(
      path.join(repositoryRoot, ...MANIFEST_PATH.split('/')),
      'utf8',
    ));
    const result = scanR6SharingOtpTransport({ repositoryRoot, manifest });
    stdout(
      'PASS - R6 Sharing OTP transport: stage=' + result.stage
        + ', concrete-imports=' + result.concreteImports
        + ', protected=' + result.protectedFiles,
    );
    return 0;
  } catch {
    stderr('ERROR - R6 Sharing OTP transport validation failed');
    return 2;
  }
}

module.exports = {
  EXPECTED_ALLOWED_PATHS,
  MANIFEST_PATH,
  R6_BASE,
  STAGES,
  inspectConcreteTransportImports,
  runCli,
  scanR6SharingOtpTransport,
  validateR6Manifest,
  verifyR7DependencyHandoff,
};

if (require.main === module) process.exitCode = runCli();
