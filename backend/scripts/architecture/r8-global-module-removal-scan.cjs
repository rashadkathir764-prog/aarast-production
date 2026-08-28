'use strict';

const crypto = require('node:crypto');
const fs = require('node:fs');
const { createRequire } = require('node:module');
const path = require('node:path');
const { types: utilTypes } = require('node:util');
const ts = require('typescript');

const R8_BASE = 'c2b728bfe54304562923facfb6094e0de04c0b27';
const REPOSITORY_ROOT = path.resolve(__dirname, '../../..');
const INFERRED_NEST_DYNAMIC_MODULE_FACTORY_NAMES = Object.freeze([
  'forFeature',
  'forFeatureAsync',
  'forRoot',
  'forRootAsync',
  'register',
  'registerAsync',
]);
const SCHEDULE_6_1_3_ROOT_SHIM_SHA256 = 'f654b5aa2ae694e9cb10a3eef9b249331bc95e63bf9590cbb62a9f8e40c585c9';
const EXPECTED_DOCUMENTS = Object.freeze({
  design: Object.freeze({
    path: 'docs/superpowers/specs/2026-08-27-modular-monolith-r8-global-module-removal-design.md',
    sha256: 'ad6f3bb46aca7b24d240fcfa011489756aa08e6ef9f000a002ea350c5625cb64',
  }),
  plan: Object.freeze({
    path: 'docs/superpowers/plans/2026-08-27-modular-monolith-r8-global-module-removal.md',
    sha256: 'a0076773aea25769a9bb2a1ce9d558d46cce60cbb83b07ca70a94ec92ab17ebe',
  }),
});
const EXPECTED_ALLOWED_PATHS = Object.freeze([
  'ARCHITECTURE.md',
  'CHANGELOG.md',
  'backend/architecture/r8-global-module-removal.json',
  'backend/package.json',
  'backend/scripts/architecture/ports-scan.cjs',
  'backend/scripts/architecture/r3-context-scan.cjs',
  'backend/scripts/architecture/r3-scope.cjs',
  'backend/scripts/architecture/r5-identity-scan.cjs',
  'backend/scripts/architecture/r7-collaboration-relocation-scan.cjs',
  'backend/scripts/architecture/r8-global-module-removal-scan.cjs',
  'backend/scripts/security/prisma-config-merge-security.cjs',
  'backend/src/application-composition/application-outbox-runtime.module.ts',
  'backend/src/conversations/conversation-realtime.module.ts',
  'backend/src/platform/database/prisma.module.ts',
  'backend/test/architecture-ports.test.ts',
  'backend/test/architecture-r1-layout.test.ts',
  'backend/test/architecture-r3-closure.test.ts',
  'backend/test/architecture-r3-composition.test.ts',
  'backend/test/architecture-r3-contexts.test.ts',
  'backend/test/architecture-r3-scope.test.ts',
  'backend/test/architecture-r4-planning-finance-boundary.test.ts',
  'backend/test/architecture-r5-identity-relocation.test.ts',
  'backend/test/architecture-r6-sharing-otp-transport.test.ts',
  'backend/test/architecture-r7-collaboration-relocation.test.ts',
  'backend/test/architecture-r8-global-module-removal.test.ts',
  'backend/test/prisma-config-merge-security.test.ts',
  'backend/test/provider-status-access.test.ts',
  'docs/README.md',
  'docs/SCRIPTS.md',
  'docs/backend/README.md',
  'docs/project/DECISIONS.md',
  'docs/project/EXECUTION_PLAN.md',
  'docs/project/STATUS.md',
  'docs/qa/README.md',
  'docs/superpowers/plans/2026-08-27-modular-monolith-r8-global-module-removal-completion.md',
  'docs/superpowers/plans/2026-08-27-modular-monolith-r8-global-module-removal.md',
  'docs/superpowers/specs/2026-08-27-modular-monolith-r8-global-module-removal-completion.md',
  'docs/superpowers/specs/2026-08-27-modular-monolith-r8-global-module-removal-design.md',
]);
const EXPECTED_PROJECT_PROVIDERS = Object.freeze({
  prisma: Object.freeze({
    modulePath: 'backend/src/platform/database/prisma.module.ts',
    moduleClass: 'PrismaModule',
    providerPath: 'backend/src/platform/database/prisma.service.ts',
    providerClass: 'PrismaService',
    strictImporters: Object.freeze([
      'backend/src/app.module.ts',
      'backend/src/application-composition/application-outbox-runtime.module.ts',
      'backend/src/modules/backoffice/internal/backoffice-services.internal.module.ts',
      'backend/src/modules/catalog/internal/catalog-services.internal.module.ts',
      'backend/src/modules/collaboration/internal/collaboration-history.internal.module.ts',
      'backend/src/modules/collaboration/internal/collaboration-permission.internal.module.ts',
      'backend/src/modules/collaboration/internal/collaboration-services.internal.module.ts',
      'backend/src/modules/finance/internal/finance-services.internal.module.ts',
      'backend/src/modules/guests/internal/guests-service.internal.module.ts',
      'backend/src/modules/identity/internal/identity-auth.internal.module.ts',
      'backend/src/modules/identity/internal/identity-profile.internal.module.ts',
      'backend/src/modules/insights/internal/insights-services.internal.module.ts',
      'backend/src/modules/marketplace/internal/marketplace-services.internal.module.ts',
      'backend/src/modules/media/internal/media-storage.internal.module.ts',
      'backend/src/modules/messaging/internal/messaging-conversations.internal.module.ts',
      'backend/src/modules/notifications/internal/notifications-service.internal.module.ts',
      'backend/src/modules/notifications/internal/push-installations.internal.module.ts',
      'backend/src/modules/notifications/internal/push-transport.internal.module.ts',
      'backend/src/modules/planning/internal/planning-services.internal.module.ts',
      'backend/src/modules/tasks/internal/tasks-service.internal.module.ts',
      'backend/src/platform/outbox/outbox-core.module.ts',
    ]),
  }),
  realtime: Object.freeze({
    modulePath: 'backend/src/conversations/conversation-realtime.module.ts',
    moduleClass: 'ConversationRealtimeModule',
    providerPath: 'backend/src/conversations/conversation-realtime.publisher.ts',
    providerClass: 'ConversationRealtimePublisher',
    strictImporters: Object.freeze([
      'backend/src/modules/messaging/internal/messaging-conversations.internal.module.ts',
      'backend/src/modules/messaging/internal/messaging-realtime.internal.module.ts',
    ]),
  }),
});
const EXPECTED_MESSAGING_BINDINGS = Object.freeze([
  Object.freeze({
    modulePath: 'backend/src/modules/messaging/internal/messaging-realtime.internal.module.ts',
    providePath: 'backend/src/modules/messaging/internal/messaging-realtime.implementation-token.ts',
    provideName: 'MESSAGING_REALTIME_IMPLEMENTATION',
    useExistingPath: 'backend/src/conversations/conversation-realtime.publisher.ts',
    useExistingName: 'ConversationRealtimePublisher',
  }),
  Object.freeze({
    modulePath: 'backend/src/modules/messaging/public/messaging-realtime-public.module.ts',
    providePath: 'backend/src/modules/messaging/public/messaging-realtime.port.ts',
    provideName: 'MESSAGING_REALTIME_PORT',
    useExistingPath: 'backend/src/modules/messaging/internal/messaging-realtime.implementation-token.ts',
    useExistingName: 'MESSAGING_REALTIME_IMPLEMENTATION',
  }),
]);
const EXPECTED_R3_PROJECTION = Object.freeze({
  inventoryPath: 'backend/architecture/r3-context-boundaries.json',
  globalTransitions: Object.freeze([
    Object.freeze({
      path: 'backend/src/conversations/conversation-realtime.module.ts',
      className: 'ConversationRealtimeModule',
      before: true,
      after: false,
    }),
    Object.freeze({
      path: 'backend/src/platform/database/prisma.module.ts',
      className: 'PrismaModule',
      before: true,
      after: false,
    }),
  ]),
  importTransition: Object.freeze({
    path: 'backend/src/application-composition/application-outbox-runtime.module.ts',
    className: 'ApplicationOutboxRuntimeModule',
    before: Object.freeze([
      'MessagingRealtimePublicModule',
      'OutboxCoreModule',
      'PushDeliveryPublicModule',
    ]),
    after: Object.freeze([
      'MessagingRealtimePublicModule',
      'OutboxCoreModule',
      'PrismaModule',
      'PushDeliveryPublicModule',
    ]),
  }),
});
const EXPECTED_EXTERNAL_GLOBAL_IDENTITIES = Object.freeze([
  Object.freeze({
    packageName: '@nestjs/schedule',
    declaredRange: '^6.1.3',
    lockedVersion: '6.1.3',
    resolved: 'https://registry.npmjs.org/@nestjs/schedule/-/schedule-6.1.3.tgz',
    integrity: 'sha512-RflMFOpR16Dwd1jAUbeB4mfGTCh65fvEdL4mSjQPJChpkRGRjIXjb+6YQcK2faQrVT60c9DmLmoVR7/ONCtuYQ==',
    importedClass: 'ScheduleModule',
    factoryMethod: 'forRoot',
    sourcePath: 'backend/src/app.module.ts',
    callCount: 1,
    installedEntrypoint: 'dist/index.js',
    globalMechanism: 'dynamic-module-global',
  }),
  Object.freeze({
    packageName: '@nestjs/throttler',
    declaredRange: '^6.5.0',
    lockedVersion: '6.5.0',
    resolved: 'https://registry.npmjs.org/@nestjs/throttler/-/throttler-6.5.0.tgz',
    integrity: 'sha512-9j0ZRfH0QE1qyrj9JjIRDz5gQLPqq9yVC2nHsrosDVAfI5HHw08/aUAWx9DZLSdQf4HDkmhTTEGLrRFHENvchQ==',
    importedClass: 'ThrottlerModule',
    factoryMethod: 'forRootAsync',
    sourcePath: 'backend/src/app.module.ts',
    callCount: 1,
    installedEntrypoint: 'dist/index.js',
    globalMechanism: 'global-decorator',
  }),
]);
const EXPECTED_COUNTS = Object.freeze({
  designProjectOwnedGlobals: 2,
  strictProjectOwnedGlobals: 0,
  designPrismaImporters: 20,
  strictPrismaImporters: 21,
  realtimeImporters: 2,
  duplicateProviders: 0,
  forwardRef: 0,
  nestModuleCycles: 0,
  dependencyRecords: 22,
  ownershipRecords: 385,
  ownershipOccurrences: 781,
});

function assertPlainDenseJson(value, label, seen = new WeakSet()) {
  if (value === null || ['string', 'boolean'].includes(typeof value)) return;
  if (typeof value === 'number') {
    if (!Number.isFinite(value)) throw new Error(`${label} must contain JSON numbers only`);
    return;
  }
  if (typeof value !== 'object' || utilTypes.isProxy(value)) {
    throw new Error(`${label} must contain plain JSON data only`);
  }
  if (seen.has(value)) throw new Error(`${label} must not contain cycles`);
  seen.add(value);
  if (Array.isArray(value)) {
    const ownKeys = Reflect.ownKeys(value);
    if (ownKeys.some((key) => typeof key !== 'string')
        || ownKeys.length !== value.length + 1
        || ownKeys[ownKeys.length - 1] !== 'length') {
      throw new Error(`${label} must be a dense JSON array`);
    }
    for (let index = 0; index < value.length; index += 1) {
      if (!Object.prototype.hasOwnProperty.call(value, index)) {
        throw new Error(`${label} must be a dense JSON array`);
      }
      const descriptor = Object.getOwnPropertyDescriptor(value, `${index}`);
      if (!descriptor || !Object.prototype.hasOwnProperty.call(descriptor, 'value')
          || !descriptor.enumerable) {
        throw new Error(`${label} must contain data properties only; accessor found`);
      }
      assertPlainDenseJson(descriptor.value, `${label}[${index}]`, seen);
    }
    seen.delete(value);
    return;
  }
  if (Object.getPrototypeOf(value) !== Object.prototype) {
    throw new Error(`${label} must contain plain objects only`);
  }
  for (const key of Reflect.ownKeys(value)) {
    if (typeof key !== 'string') throw new Error(`${label} must contain string keys only`);
    const descriptor = Object.getOwnPropertyDescriptor(value, key);
    if (!descriptor || !Object.prototype.hasOwnProperty.call(descriptor, 'value')
        || !descriptor.enumerable) {
      throw new Error(`${label} must contain data properties only; accessor found`);
    }
    assertPlainDenseJson(descriptor.value, `${label}.${key}`, seen);
  }
  seen.delete(value);
}

function assertExactKeys(value, expectedKeys, label) {
  const actualKeys = Object.keys(value).sort();
  const sortedExpectedKeys = [...expectedKeys].sort();
  if (JSON.stringify(actualKeys) !== JSON.stringify(sortedExpectedKeys)) {
    throw new Error(`${label} key set is invalid`);
  }
}

function canonicalJson(value) {
  if (value === null || typeof value !== 'object') return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(',')}]`;
  return `{${Object.keys(value).sort().map(
    (key) => `${JSON.stringify(key)}:${canonicalJson(value[key])}`,
  ).join(',')}}`;
}

function assertExactContract(value, expected, label) {
  if (canonicalJson(value) !== canonicalJson(expected)) {
    throw new Error(`${label} identity is invalid`);
  }
}

function deepFrozenCopy(value) {
  if (value === null || typeof value !== 'object') return value;
  if (Array.isArray(value)) return Object.freeze(value.map(deepFrozenCopy));
  return Object.freeze(Object.fromEntries(
    Object.entries(value).map(([key, entry]) => [key, deepFrozenCopy(entry)]),
  ));
}

function validateRelativePathList(value, label) {
  if (!Array.isArray(value)) throw new Error(`${label} must be an array`);
  const paths = [];
  for (let index = 0; index < value.length; index += 1) {
    if (!Object.prototype.hasOwnProperty.call(value, index)) {
      throw new Error(`${label} must be dense`);
    }
    const candidate = value[index];
    const segments = typeof candidate === 'string' ? candidate.split('/') : [];
    if (typeof candidate !== 'string' || candidate.length === 0
        || candidate.includes('\\') || candidate.includes('\0')
        || path.posix.isAbsolute(candidate) || path.win32.isAbsolute(candidate)
        || segments.some((segment) => !segment || segment === '.' || segment === '..')) {
      throw new Error(`${label} contains an invalid repository-relative path`);
    }
    paths.push(candidate);
  }
  if (new Set(paths).size !== paths.length) throw new Error(`${label} contains a duplicate path`);
  if (JSON.stringify(paths) !== JSON.stringify([...paths].sort())) {
    throw new Error(`${label} must be sorted`);
  }
  return paths;
}

function isInside(root, candidate) {
  const relative = path.relative(root, candidate);
  return relative === '' || (!path.isAbsolute(relative) && relative !== '..'
    && !relative.startsWith(`..${path.sep}`));
}

function validateAllowedPathAncestry(repositoryRoot, relativePath) {
  const root = (fs.realpathSync.native || fs.realpathSync)(repositoryRoot);
  let cursor = repositoryRoot;
  const segments = relativePath.split('/');
  for (let index = 0; index < segments.length; index += 1) {
    cursor = path.join(cursor, segments[index]);
    if (!fs.existsSync(cursor)) return;
    const status = fs.lstatSync(cursor);
    if (status.isSymbolicLink()) {
      throw new Error('R8 allowed path contains a symbolic or junction reparse point');
    }
    if (index < segments.length - 1 && !status.isDirectory()) {
      throw new Error('R8 allowed path parent is not a directory');
    }
    if (index === segments.length - 1 && !status.isFile()) {
      throw new Error('R8 allowed path is not a plain file');
    }
    const real = (fs.realpathSync.native || fs.realpathSync)(cursor);
    if (!isInside(root, real)) throw new Error('R8 allowed path escapes the repository');
  }
}

function hashFile(repositoryRoot, relativePath) {
  const absolutePath = path.join(repositoryRoot, ...relativePath.split('/'));
  const status = fs.lstatSync(absolutePath);
  if (!status.isFile() || status.isSymbolicLink()) {
    throw new Error('R8 document must be a plain file');
  }
  return crypto.createHash('sha256').update(fs.readFileSync(absolutePath)).digest('hex');
}

function validateR8Manifest(value) {
  assertPlainDenseJson(value, 'R8 manifest');
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error('R8 manifest must be a plain object');
  }
  assertExactKeys(
    value,
    [
      'schemaVersion',
      'baseRevision',
      'stage',
      'documents',
      'allowedChangedPaths',
      'projectProviders',
      'messagingBindings',
      'r3Projection',
      'externalGlobalIdentities',
      'expectedCounts',
    ],
    'R8 manifest',
  );
  if (value.schemaVersion !== 1 || value.baseRevision !== R8_BASE) {
    throw new Error('R8 manifest identity is invalid');
  }
  if (!['design', 'strict'].includes(value.stage)) throw new Error('R8 manifest stage is invalid');
  assertExactKeys(value.documents, ['design', 'plan'], 'R8 manifest documents');
  for (const name of ['design', 'plan']) {
    const document = value.documents[name];
    assertExactKeys(document, ['path', 'sha256'], `R8 ${name} document`);
    if (typeof document.sha256 !== 'string' || !/^[0-9a-f]{64}$/.test(document.sha256)
        || document.path !== EXPECTED_DOCUMENTS[name].path
        || document.sha256 !== EXPECTED_DOCUMENTS[name].sha256) {
      throw new Error(`R8 ${name} document path or hash is invalid`);
    }
  }
  const allowedChangedPaths = validateRelativePathList(
    value.allowedChangedPaths,
    'R8 allowed changed paths',
  );
  if (JSON.stringify(allowedChangedPaths) !== JSON.stringify(EXPECTED_ALLOWED_PATHS)) {
    throw new Error('R8 allowed changed path fence is invalid');
  }
  for (const requiredPath of EXPECTED_ALLOWED_PATHS) {
    if (!allowedChangedPaths.includes(requiredPath)) {
      throw new Error('R8 allowed changed path fence is missing a required path');
    }
    validateAllowedPathAncestry(REPOSITORY_ROOT, requiredPath);
  }
  for (const document of Object.values(EXPECTED_DOCUMENTS)) {
    if (hashFile(REPOSITORY_ROOT, document.path) !== document.sha256) {
      throw new Error('R8 document content hash is invalid');
    }
  }
  assertExactContract(value.projectProviders, EXPECTED_PROJECT_PROVIDERS, 'R8 project provider');
  assertExactContract(value.messagingBindings, EXPECTED_MESSAGING_BINDINGS, 'R8 Messaging binding');
  assertExactContract(value.r3Projection, EXPECTED_R3_PROJECTION, 'R8 R3 projection');
  assertExactContract(
    value.externalGlobalIdentities,
    EXPECTED_EXTERNAL_GLOBAL_IDENTITIES,
    'R8 external global identity',
  );
  assertExactContract(value.expectedCounts, EXPECTED_COUNTS, 'R8 expected count');
  return deepFrozenCopy(value);
}

function normalizeFsPath(value) {
  return path.resolve(value).replace(/\\/g, '/');
}

function repositoryPath(fileName, repositoryRoot) {
  const relative = path.relative(repositoryRoot, fileName);
  if (!relative || path.isAbsolute(relative) || relative === '..'
      || relative.startsWith(`..${path.sep}`)) {
    throw new Error('R8 source path is outside the repository');
  }
  return relative.replace(/\\/g, '/');
}

function repositoryPathOrNull(fileName, repositoryRoot) {
  try {
    return repositoryPath(fileName, repositoryRoot);
  } catch {
    return null;
  }
}

function compareText(left, right) {
  return left < right ? -1 : left > right ? 1 : 0;
}

function createProgram(repositoryRoot) {
  if (typeof repositoryRoot !== 'string' || !path.isAbsolute(repositoryRoot)) {
    throw new Error('R8 repository root must be absolute');
  }
  const backendRoot = path.join(repositoryRoot, 'backend');
  const configPath = path.join(backendRoot, 'tsconfig.json');
  const config = ts.readConfigFile(configPath, ts.sys.readFile);
  if (config.error) throw new Error('R8 backend tsconfig cannot be read');
  const parsed = ts.parseJsonConfigFileContent(
    config.config,
    ts.sys,
    backendRoot,
    undefined,
    configPath,
  );
  if (parsed.errors.length || !parsed.fileNames.length) {
    throw new Error('R8 backend tsconfig cannot be parsed');
  }
  const program = ts.createProgram({ rootNames: parsed.fileNames, options: parsed.options });
  if (program.getOptionsDiagnostics().length) {
    throw new Error('R8 backend TypeScript options are invalid');
  }
  if (program.getSyntacticDiagnostics().length) {
    throw new Error('R8 backend source has syntax errors');
  }
  return { program, checker: program.getTypeChecker() };
}

function projectSourceFiles(program, repositoryRoot) {
  return program.getSourceFiles().map((sourceFile) => ({
    sourceFile,
    path: repositoryPathOrNull(sourceFile.fileName, repositoryRoot),
  })).filter((entry) => entry.path && /^backend\/src\/.+\.ts$/u.test(entry.path)
    && !entry.path.endsWith('.d.ts'))
    .sort((left, right) => compareText(left.path, right.path));
}

function unwrapExpression(input) {
  let current = input;
  while (current && (ts.isParenthesizedExpression(current)
    || ts.isAsExpression(current)
    || ts.isTypeAssertionExpression(current)
    || ts.isNonNullExpression(current)
    || (ts.isSatisfiesExpression && ts.isSatisfiesExpression(current)))) {
    current = current.expression;
  }
  return current;
}

function resolveAlias(input, checker) {
  let current = input || null;
  const seen = new Set();
  while (current && (current.flags & ts.SymbolFlags.Alias) && !seen.has(current)) {
    seen.add(current);
    let next = null;
    try {
      next = checker.getAliasedSymbol(current);
    } catch {
      next = null;
    }
    if (!next || next === current) break;
    current = next;
  }
  return current;
}

function staticString(input, checker, seen = new Set()) {
  const expression = unwrapExpression(input);
  if (!expression) return null;
  if (ts.isStringLiteralLike(expression) || ts.isNoSubstitutionTemplateLiteral(expression)) {
    return expression.text;
  }
  if (ts.isBinaryExpression(expression) && expression.operatorToken.kind === ts.SyntaxKind.PlusToken) {
    const left = staticString(expression.left, checker, seen);
    const right = staticString(expression.right, checker, seen);
    return left === null || right === null ? null : left + right;
  }
  if (ts.isIdentifier(expression) || ts.isPropertyAccessExpression(expression)
      || ts.isElementAccessExpression(expression)) {
    const resolved = constInitializer(expression, checker, seen);
    if (!resolved) return null;
    const next = new Set(seen);
    next.add(resolved.symbol);
    return staticString(resolved.initializer, checker, next);
  }
  return null;
}

function symbolAtExpression(input, checker) {
  const expression = unwrapExpression(input);
  if (!expression) return null;
  if (ts.isPropertyAccessExpression(expression)) {
    return resolveAlias(checker.getSymbolAtLocation(expression.name), checker);
  }
  if (ts.isElementAccessExpression(expression) && expression.argumentExpression) {
    const key = staticString(expression.argumentExpression, checker);
    if (key !== null) {
      const member = checker.getPropertyOfType(checker.getTypeAtLocation(expression.expression), key);
      if (member) return resolveAlias(member, checker);
    }
  }
  return resolveAlias(checker.getSymbolAtLocation(expression), checker);
}

function constInitializer(input, checker, seen = new Set()) {
  const symbol = symbolAtExpression(input, checker);
  if (!symbol || seen.has(symbol)) return null;
  const declarations = symbol.declarations || [];
  if (declarations.length !== 1 || !ts.isVariableDeclaration(declarations[0])
      || !declarations[0].initializer || !ts.isVariableDeclarationList(declarations[0].parent)
      || !(declarations[0].parent.flags & ts.NodeFlags.Const)) {
    return null;
  }
  return { symbol, initializer: declarations[0].initializer };
}

function staticPropertyName(name, checker) {
  if (!name) return null;
  if (ts.isIdentifier(name) || ts.isStringLiteralLike(name) || ts.isNumericLiteral(name)) {
    return name.text;
  }
  if (ts.isComputedPropertyName(name)) return staticString(name.expression, checker);
  return null;
}

function resolveStaticObject(input, checker, label, seen = new Set()) {
  const expression = unwrapExpression(input);
  if (!expression) throw new Error(`${label} metadata cannot be resolved`);
  const resolved = constInitializer(expression, checker, seen);
  if (resolved) {
    const next = new Set(seen);
    next.add(resolved.symbol);
    return resolveStaticObject(resolved.initializer, checker, label, next);
  }
  if (ts.isCallExpression(expression)
      && ts.isPropertyAccessExpression(expression.expression)
      && ts.isIdentifier(expression.expression.expression)
      && expression.expression.expression.text === 'Object'
      && expression.expression.name.text === 'freeze'
      && expression.arguments.length === 1) {
    return resolveStaticObject(expression.arguments[0], checker, label, seen);
  }
  if (!ts.isObjectLiteralExpression(expression)) {
    throw new Error(`${label} metadata cannot be resolved`);
  }
  const result = new Map();
  for (const property of expression.properties) {
    if (ts.isSpreadAssignment(property)) {
      const spread = resolveStaticObject(property.expression, checker, label, seen);
      for (const [key, value] of spread) result.set(key, value);
      continue;
    }
    const key = staticPropertyName(property.name, checker);
    if (key === null) throw new Error(`${label} metadata key cannot be resolved`);
    if (ts.isPropertyAssignment(property)) result.set(key, property.initializer);
    else if (ts.isShorthandPropertyAssignment(property)) result.set(key, property.name);
    else throw new Error(`${label} metadata property is not static data`);
  }
  return result;
}

function resolveStaticArray(input, checker, label, seen = new Set()) {
  const expression = unwrapExpression(input);
  if (!expression) throw new Error(`${label} array cannot be resolved`);
  const resolved = constInitializer(expression, checker, seen);
  if (resolved) {
    const next = new Set(seen);
    next.add(resolved.symbol);
    return resolveStaticArray(resolved.initializer, checker, label, next);
  }
  if (!ts.isArrayLiteralExpression(expression)) {
    throw new Error(`${label} array cannot be resolved`);
  }
  const result = [];
  for (const element of expression.elements) {
    if (ts.isSpreadElement(element)) {
      result.push(...resolveStaticArray(element.expression, checker, label, seen));
    } else if (!ts.isOmittedExpression(element)) {
      result.push(element);
    }
  }
  return result;
}

function resolveStaticBoolean(input, checker, label, seen = new Set()) {
  const expression = unwrapExpression(input);
  if (expression && expression.kind === ts.SyntaxKind.TrueKeyword) return true;
  if (expression && expression.kind === ts.SyntaxKind.FalseKeyword) return false;
  const resolved = expression && constInitializer(expression, checker, seen);
  if (resolved) {
    const next = new Set(seen);
    next.add(resolved.symbol);
    return resolveStaticBoolean(resolved.initializer, checker, label, next);
  }
  throw new Error(`${label} boolean cannot be resolved`);
}

function declarationFromPackage(declaration, packageName) {
  const fileName = normalizeFsPath(declaration.getSourceFile().fileName).toLowerCase();
  return fileName.includes(`/node_modules/${packageName.toLowerCase()}/`);
}

function isNestCommonSymbol(input, expectedName, checker, seen = new Set()) {
  const expression = unwrapExpression(input);
  const symbol = symbolAtExpression(expression, checker);
  if (!symbol || seen.has(symbol)) return false;
  if (symbol.getName() === expectedName && (symbol.declarations || []).some(
    (declaration) => declarationFromPackage(declaration, '@nestjs/common'),
  )) return true;
  const resolved = constInitializer(expression, checker, seen);
  if (!resolved) return false;
  const next = new Set(seen);
  next.add(resolved.symbol);
  return isNestCommonSymbol(resolved.initializer, expectedName, checker, next);
}

function decoratorsOf(node) {
  return ts.canHaveDecorators(node) ? (ts.getDecorators(node) || []) : [];
}

function decoratorCall(node, expectedName, checker) {
  return decoratorsOf(node).map((decorator) => decorator.expression).find((expression) => (
    ts.isCallExpression(expression)
      && isNestCommonSymbol(expression.expression, expectedName, checker)
  )) || null;
}

function findProjectSymbol(program, checker, repositoryRoot, expectedPath, expectedName) {
  const sourceFile = projectSourceFiles(program, repositoryRoot).find(
    (entry) => entry.path === expectedPath,
  )?.sourceFile;
  if (!sourceFile) throw new Error(`R8 protected identity source is missing: ${expectedName}`);
  let found = null;
  function visit(node) {
    if (found) return;
    if ((ts.isClassDeclaration(node) || ts.isVariableDeclaration(node)
        || ts.isInterfaceDeclaration(node) || ts.isTypeAliasDeclaration(node))
        && node.name && node.name.text === expectedName) {
      found = resolveAlias(checker.getSymbolAtLocation(node.name), checker);
      return;
    }
    ts.forEachChild(node, visit);
  }
  visit(sourceFile);
  if (!found) throw new Error(`R8 protected identity is missing: ${expectedName}`);
  return found;
}

function sameSymbol(input, expected, checker) {
  return Boolean(input && expected && resolveAlias(input, checker) === resolveAlias(expected, checker));
}

function expressionHasSymbol(input, expected, checker) {
  return sameSymbol(symbolAtExpression(input, checker), expected, checker);
}

function classDeclarationForSymbol(symbol) {
  return (symbol && symbol.declarations || []).find(ts.isClassDeclaration) || null;
}

function typeUsesSymbol(typeNode, expected, checker) {
  if (!typeNode) return false;
  const type = checker.getTypeAtLocation(typeNode);
  const symbols = [type.symbol, type.aliasSymbol].filter(Boolean);
  if (symbols.some((symbol) => sameSymbol(symbol, expected, checker))) return true;
  if (type.isUnionOrIntersection && type.isUnionOrIntersection()) {
    return type.types.some((part) => [part.symbol, part.aliasSymbol].filter(Boolean)
      .some((symbol) => sameSymbol(symbol, expected, checker)));
  }
  return false;
}

function collectModules(program, checker, repositoryRoot) {
  const modules = [];
  for (const entry of projectSourceFiles(program, repositoryRoot)) {
    for (const statement of entry.sourceFile.statements) {
      if (!ts.isClassDeclaration(statement) || !statement.name) continue;
      const call = decoratorCall(statement, 'Module', checker);
      if (!call || call.arguments.length !== 1) continue;
      const object = resolveStaticObject(call.arguments[0], checker, 'Nest Module');
      const readArray = (name) => object.has(name)
        ? resolveStaticArray(object.get(name), checker, `Nest Module ${name}`)
        : [];
      modules.push({
        path: entry.path,
        sourceFile: entry.sourceFile,
        classNode: statement,
        className: statement.name.text,
        symbol: resolveAlias(checker.getSymbolAtLocation(statement.name), checker),
        imports: readArray('imports'),
        providers: readArray('providers'),
        controllers: readArray('controllers'),
        exports: readArray('exports'),
      });
    }
  }
  return modules.sort((left, right) => compareText(left.path, right.path));
}

function typeIsNestDynamicModule(type, checker, seen = new Set()) {
  if (!type || seen.has(type)) return false;
  seen.add(type);
  const symbols = [type.symbol, type.aliasSymbol].filter(Boolean).map(
    (symbol) => resolveAlias(symbol, checker),
  );
  if (symbols.some((symbol) => symbol && symbol.getName() === 'DynamicModule'
      && (symbol.declarations || []).some(
        (declaration) => declarationFromPackage(declaration, '@nestjs/common'),
      ))) return true;
  if (type.isUnionOrIntersection && type.isUnionOrIntersection()) {
    return type.types.some((part) => typeIsNestDynamicModule(part, checker, seen));
  }
  return false;
}

function returnTypeIsNestDynamicModule(node, checker) {
  if (node.type) {
    const type = checker.getTypeFromTypeNode(node.type);
    if (typeIsNestDynamicModule(type, checker)) return true;
  }
  const signature = checker.getSignatureFromDeclaration(node);
  return Boolean(signature && typeIsNestDynamicModule(
    checker.getReturnTypeOfSignature(signature),
    checker,
  ));
}

function staticMemberName(node, checker) {
  if (ts.isIdentifier(node.name) || ts.isStringLiteralLike(node.name)) return node.name.text;
  return ts.isComputedPropertyName(node.name) ? staticString(node.name.expression, checker) : null;
}

function hasStaticModifier(node) {
  return Boolean(node.modifiers && node.modifiers.some(
    (modifier) => modifier.kind === ts.SyntaxKind.StaticKeyword,
  ));
}

function inferredNestDynamicModuleFactory(node, checker) {
  const member = ts.isMethodDeclaration(node)
    ? node
    : (ts.isArrowFunction(node) || ts.isFunctionExpression(node))
      && ts.isPropertyDeclaration(node.parent)
      && node.parent.initializer === node
      ? node.parent
      : null;
  if (!member || !hasStaticModifier(member) || !ts.isClassDeclaration(member.parent)
      || !decoratorCall(member.parent, 'Module', checker)) {
    return false;
  }
  const name = staticMemberName(member, checker);
  return name !== null && INFERRED_NEST_DYNAMIC_MODULE_FACTORY_NAMES.includes(name);
}

function expressionIsNestModuleClass(input, checker) {
  const declaration = classDeclarationForSymbol(symbolAtExpression(input, checker));
  return Boolean(declaration && decoratorCall(declaration, 'Module', checker));
}

function returnExpressionHasNestDynamicModuleShape(input, checker) {
  let metadata;
  try {
    metadata = resolveStaticObject(input, checker, 'inferred project DynamicModule');
  } catch {
    return null;
  }
  return metadata.has('module') && expressionIsNestModuleClass(metadata.get('module'), checker);
}

function collectReturnExpressions(node) {
  if (ts.isArrowFunction(node) && !ts.isBlock(node.body)) return [node.body];
  const result = [];
  function visit(current) {
    if (current !== node && (ts.isFunctionLike(current) || ts.isClassLike(current))) return;
    if (ts.isReturnStatement(current)) {
      if (current.expression) result.push(current.expression);
      return;
    }
    ts.forEachChild(current, visit);
  }
  if (node.body) visit(node.body);
  return result;
}

function callMember(input, checker) {
  const expression = unwrapExpression(input);
  if (!ts.isPropertyAccessExpression(expression) && !ts.isElementAccessExpression(expression)) {
    return null;
  }
  const name = ts.isPropertyAccessExpression(expression)
    ? expression.name.text
    : staticString(expression.argumentExpression, checker);
  return name === null ? null : { name, receiver: expression.expression };
}

function callReturnsNestDynamicModule(call, checker) {
  const signature = checker.getResolvedSignature(call);
  return Boolean(signature && typeIsNestDynamicModule(
    checker.getReturnTypeOfSignature(signature),
    checker,
  ));
}

function symbolIsExternal(symbol, repositoryRoot) {
  return Boolean(symbol && (symbol.declarations || []).length
    && (symbol.declarations || []).every((declaration) => {
      const sourcePath = repositoryPathOrNull(declaration.getSourceFile().fileName, repositoryRoot);
      return !sourcePath || !sourcePath.startsWith('backend/src/');
    }));
}

function inspectExternalFactoryOptions(call, checker, repositoryRoot) {
  const member = callMember(call.expression, checker);
  if (!member || !['forRoot', 'forRootAsync', 'register', 'registerAsync'].includes(member.name)
      || !callReturnsNestDynamicModule(call, checker)) return;
  const receiverSymbol = symbolAtExpression(member.receiver, checker);
  if (!symbolIsExternal(receiverSymbol, repositoryRoot)) return;
  for (const argument of call.arguments) {
    const object = resolveStaticObject(argument, checker, 'external DynamicModule option');
    for (const key of ['global', 'isGlobal']) {
      if (!object.has(key)) continue;
      if (resolveStaticBoolean(object.get(key), checker, 'external global factory option')) {
        throw new Error('external global factory option is forbidden');
      }
    }
  }
}

function moduleImportSymbol(input, checker) {
  let expression = unwrapExpression(input);
  if (ts.isCallExpression(expression)) {
    const member = callMember(expression.expression, checker);
    expression = member ? member.receiver : expression.expression;
  }
  return symbolAtExpression(expression, checker);
}

function countModuleCycles(modules, checker) {
  const bySymbol = new Map(modules.map((module) => [resolveAlias(module.symbol, checker), module]));
  const edges = new Map(modules.map((module) => [module, new Set()]));
  for (const module of modules) {
    for (const expression of module.imports) {
      const target = bySymbol.get(resolveAlias(moduleImportSymbol(expression, checker), checker));
      if (target) edges.get(module).add(target);
    }
  }
  let index = 0;
  let cycles = 0;
  const stack = [];
  const indexes = new Map();
  const lows = new Map();
  const active = new Set();
  function visit(module) {
    indexes.set(module, index);
    lows.set(module, index);
    index += 1;
    stack.push(module);
    active.add(module);
    for (const target of edges.get(module)) {
      if (!indexes.has(target)) {
        visit(target);
        lows.set(module, Math.min(lows.get(module), lows.get(target)));
      } else if (active.has(target)) {
        lows.set(module, Math.min(lows.get(module), indexes.get(target)));
      }
    }
    if (lows.get(module) !== indexes.get(module)) return;
    const component = [];
    let current;
    do {
      current = stack.pop();
      active.delete(current);
      component.push(current);
    } while (current !== module);
    if (component.length > 1 || edges.get(module).has(module)) cycles += 1;
  }
  for (const module of modules) if (!indexes.has(module)) visit(module);
  return cycles;
}

function collectProjectGlobalActivations(program, checker, repositoryRoot) {
  const globals = [];
  let forwardRef = 0;
  for (const entry of projectSourceFiles(program, repositoryRoot)) {
    function visit(node) {
      if (ts.isClassDeclaration(node) && decoratorCall(node, 'Global', checker)) {
        globals.push(entry.path);
      }
      if ((ts.isMethodDeclaration(node) || ts.isFunctionDeclaration(node)
          || ts.isFunctionExpression(node) || ts.isArrowFunction(node)) && node.body) {
        const declaredDynamicModule = returnTypeIsNestDynamicModule(node, checker);
        const inferredDynamicModuleFactory = !declaredDynamicModule
          && inferredNestDynamicModuleFactory(node, checker);
        const returns = collectReturnExpressions(node);
        if (declaredDynamicModule && !returns.length) {
          throw new Error('project DynamicModule metadata cannot be resolved');
        }
        for (const expression of returns) {
          if (!declaredDynamicModule) {
            const inferredShape = returnExpressionHasNestDynamicModuleShape(expression, checker);
            if (!inferredShape) {
              if (inferredDynamicModuleFactory && inferredShape === null) {
                throw new Error('project DynamicModule metadata cannot be resolved');
              }
              continue;
            }
          }
          const object = resolveStaticObject(expression, checker, 'project DynamicModule');
          if (object.has('global')
              && resolveStaticBoolean(object.get('global'), checker, 'project DynamicModule global')) {
            globals.push(entry.path);
          }
        }
      }
      if (ts.isCallExpression(node)) {
        if (isNestCommonSymbol(node.expression, 'forwardRef', checker)) forwardRef += 1;
        inspectExternalFactoryOptions(node, checker, repositoryRoot);
      }
      ts.forEachChild(node, visit);
    }
    visit(entry.sourceFile);
  }
  const globalPaths = [...globals].sort(compareText);
  return Object.freeze({
    projectOwnedGlobals: globalPaths.length,
    globalPaths: Object.freeze(globalPaths),
    forwardRef,
    nestModuleCycles: countModuleCycles(collectModules(program, checker, repositoryRoot), checker),
  });
}

function stringLiteralValue(input) {
  const expression = unwrapExpression(input);
  return expression && ts.isStringLiteralLike(expression) ? expression.text : null;
}

function isGlobalSymbolFactory(input, checker) {
  const symbol = symbolAtExpression(input, checker);
  return Boolean(symbol && symbol.getName() === 'Symbol' && (symbol.declarations || []).some(
    (declaration) => /\/typescript\/lib\/lib\.es\d+(?:\.\w+)*\.d\.ts$/u.test(
      normalizeFsPath(declaration.getSourceFile().fileName),
    ),
  ));
}

function stableSymbolDescription(input, checker, seen = new Set()) {
  const expression = unwrapExpression(input);
  if (!expression) return null;
  const resolved = constInitializer(expression, checker, seen);
  if (resolved) {
    const next = new Set(seen);
    next.add(resolved.symbol);
    return stableSymbolDescription(resolved.initializer, checker, next);
  }
  if (!ts.isCallExpression(expression) || expression.arguments.length !== 1
      || !isGlobalSymbolFactory(expression.expression, checker)) {
    return null;
  }
  return staticString(expression.arguments[0], checker);
}

function protectedTokenLookalike(input, protectedName, checker) {
  return stringLiteralValue(input) === protectedName
    || stableSymbolDescription(input, checker) === protectedName;
}

function classConsumesProtectedProvider(symbol, protectedSymbol, checker) {
  const declaration = classDeclarationForSymbol(resolveAlias(symbol, checker));
  if (!declaration) return false;
  return declaration.members.some((member) => ts.isConstructorDeclaration(member)
    && member.parameters.some((parameter) => typeUsesSymbol(parameter.type, protectedSymbol, checker)
      || decoratorsOf(parameter).some((decorator) => {
        const expression = decorator.expression;
        return ts.isCallExpression(expression)
          && isNestCommonSymbol(expression.expression, 'Inject', checker)
          && expression.arguments.length === 1
          && expressionHasSymbol(expression.arguments[0], protectedSymbol, checker);
      })));
}

function providerEntryConsumes(entry, protectedSymbol, checker, label) {
  const expression = unwrapExpression(entry);
  const direct = symbolAtExpression(expression, checker);
  if (classConsumesProtectedProvider(direct, protectedSymbol, checker)) return true;
  if (!ts.isObjectLiteralExpression(expression) && !constInitializer(expression, checker)) return false;
  const object = resolveStaticObject(expression, checker, `${label} provider`);
  if (object.has('inject')) {
    const inject = resolveStaticArray(object.get('inject'), checker, `${label} provider inject`);
    if (inject.some((token) => expressionHasSymbol(token, protectedSymbol, checker))) return true;
  }
  if (object.has('useClass')) {
    return classConsumesProtectedProvider(
      symbolAtExpression(object.get('useClass'), checker),
      protectedSymbol,
      checker,
    );
  }
  return false;
}

function verifyNoProtectedBypasses({
  program,
  checker,
  repositoryRoot,
  protectedSymbol,
  protectedName,
  ownerModulePath,
  modules,
  label,
}) {
  for (const entry of projectSourceFiles(program, repositoryRoot)) {
    function visit(node) {
      if (ts.isNewExpression(node) && expressionHasSymbol(node.expression, protectedSymbol, checker)) {
        throw new Error(`${label} protected provider construction is forbidden`);
      }
      if (ts.isClassDeclaration(node)) {
        for (const heritage of node.heritageClauses || []) {
          for (const type of heritage.types) {
            if (expressionHasSymbol(type.expression, protectedSymbol, checker)) {
              throw new Error(`${label} protected provider subclass is forbidden`);
            }
          }
        }
      }
      ts.forEachChild(node, visit);
    }
    visit(entry.sourceFile);
  }

  const providerOwners = [];
  const exportOwners = [];
  for (const module of modules) {
    for (const provider of module.providers) {
      if (expressionHasSymbol(provider, protectedSymbol, checker)) {
        if (module.path !== ownerModulePath) {
          throw new Error(`${label} protected provider duplicate registration is forbidden`);
        }
        providerOwners.push(`${module.path}#${module.className}`);
        continue;
      }
      const expression = unwrapExpression(provider);
      if (!ts.isObjectLiteralExpression(expression) && !constInitializer(expression, checker)) continue;
      const object = resolveStaticObject(expression, checker, `${label} provider`);
      const provide = object.get('provide');
      const useClass = object.get('useClass');
      if ((provide && expressionHasSymbol(provide, protectedSymbol, checker))
          || (provide && protectedTokenLookalike(provide, protectedName, checker))
          || (useClass && expressionHasSymbol(useClass, protectedSymbol, checker))) {
        throw new Error(`${label} protected provider identity replacement is forbidden`);
      }
    }
    for (const exported of module.exports) {
      if (!expressionHasSymbol(exported, protectedSymbol, checker)) continue;
      if (module.path !== ownerModulePath) {
        throw new Error(`${label} protected provider duplicate export is forbidden`);
      }
      exportOwners.push(`${module.path}#${module.className}`);
    }
  }
  const expectedOwner = modules.find((module) => module.path === ownerModulePath);
  const expectedIdentity = expectedOwner && `${expectedOwner.path}#${expectedOwner.className}`;
  if (!expectedOwner || providerOwners.length !== 1 || exportOwners.length !== 1
      || providerOwners[0] !== expectedIdentity || exportOwners[0] !== expectedIdentity) {
    throw new Error(`${label} protected provider ownership is invalid`);
  }
  return { providerOwners, exportOwners };
}

function collectDirectPrismaConsumers(program, checker, repositoryRoot) {
  const specification = EXPECTED_PROJECT_PROVIDERS.prisma;
  const prismaModule = findProjectSymbol(
    program,
    checker,
    repositoryRoot,
    specification.modulePath,
    specification.moduleClass,
  );
  const prismaService = findProjectSymbol(
    program,
    checker,
    repositoryRoot,
    specification.providerPath,
    specification.providerClass,
  );
  const modules = collectModules(program, checker, repositoryRoot);
  const ownership = verifyNoProtectedBypasses({
    program,
    checker,
    repositoryRoot,
    protectedSymbol: prismaService,
    protectedName: specification.providerClass,
    ownerModulePath: specification.modulePath,
    modules,
    label: 'Prisma',
  });
  const importers = [];
  const strictImporters = [];
  for (const module of modules) {
    if (module.imports.some((entry) => expressionHasSymbol(entry, prismaModule, checker))) {
      importers.push(module.path);
    }
    if ([...module.providers, ...module.controllers].some(
      (entry) => providerEntryConsumes(entry, prismaService, checker, 'Prisma'),
    )) strictImporters.push(module.path);
  }
  const sortedImporters = [...new Set(importers)].sort(compareText);
  const sortedStrict = [...new Set(strictImporters)].sort(compareText);
  const importerSet = new Set(sortedImporters);
  return Object.freeze({
    importers: Object.freeze(sortedImporters),
    strictImporters: Object.freeze(sortedStrict),
    missingImporters: Object.freeze(sortedStrict.filter((entry) => !importerSet.has(entry))),
    providerOwners: Object.freeze(ownership.providerOwners),
    exportOwners: Object.freeze(ownership.exportOwners),
    duplicateProviders: 0,
  });
}

function collectRealtimeComposition(program, checker, repositoryRoot) {
  const specification = EXPECTED_PROJECT_PROVIDERS.realtime;
  const realtimeModule = findProjectSymbol(
    program,
    checker,
    repositoryRoot,
    specification.modulePath,
    specification.moduleClass,
  );
  const publisher = findProjectSymbol(
    program,
    checker,
    repositoryRoot,
    specification.providerPath,
    specification.providerClass,
  );
  const implementationToken = findProjectSymbol(
    program,
    checker,
    repositoryRoot,
    EXPECTED_MESSAGING_BINDINGS[0].providePath,
    EXPECTED_MESSAGING_BINDINGS[0].provideName,
  );
  const publicToken = findProjectSymbol(
    program,
    checker,
    repositoryRoot,
    EXPECTED_MESSAGING_BINDINGS[1].providePath,
    EXPECTED_MESSAGING_BINDINGS[1].provideName,
  );
  const modules = collectModules(program, checker, repositoryRoot);
  const ownership = verifyNoProtectedBypasses({
    program,
    checker,
    repositoryRoot,
    protectedSymbol: publisher,
    protectedName: specification.providerClass,
    ownerModulePath: specification.modulePath,
    modules,
    label: 'Realtime publisher',
  });

  const allowedConcreteReferences = new Set([
    'backend/src/conversations/conversation-realtime.publisher.ts',
    'backend/src/conversations/conversation-realtime.module.ts',
    'backend/src/conversations/conversations.gateway.ts',
    'backend/src/conversations/conversations.service.ts',
    'backend/src/modules/messaging/internal/messaging-realtime.internal.module.ts',
  ]);
  for (const entry of projectSourceFiles(program, repositoryRoot)) {
    if (allowedConcreteReferences.has(entry.path)) continue;
    function visit(node) {
      if ((ts.isIdentifier(node) || ts.isPropertyAccessExpression(node)
          || ts.isElementAccessExpression(node))
          && expressionHasSymbol(node, publisher, checker)) {
        throw new Error('Realtime publisher cross-context concrete reference is forbidden');
      }
      ts.forEachChild(node, visit);
    }
    visit(entry.sourceFile);
  }

  const expectedBindings = [
    {
      contract: EXPECTED_MESSAGING_BINDINGS[0],
      provide: implementationToken,
      useExisting: publisher,
    },
    {
      contract: EXPECTED_MESSAGING_BINDINGS[1],
      provide: publicToken,
      useExisting: implementationToken,
    },
  ];
  const bindings = [];
  for (const expected of expectedBindings) {
    const matches = [];
    for (const module of modules) {
      for (const provider of module.providers) {
        const expression = unwrapExpression(provider);
        if (!ts.isObjectLiteralExpression(expression) && !constInitializer(expression, checker)) continue;
        const object = resolveStaticObject(expression, checker, 'Realtime binding');
        if (!object.has('provide')
            || !expressionHasSymbol(object.get('provide'), expected.provide, checker)) continue;
        if (module.path !== expected.contract.modulePath || !object.has('useExisting')
            || !expressionHasSymbol(object.get('useExisting'), expected.useExisting, checker)
            || object.has('useClass') || object.has('useFactory') || object.has('useValue')) {
          throw new Error('Realtime binding must use the exact useExisting identity');
        }
        matches.push(`${module.path}#${expected.contract.provideName}->${expected.contract.useExistingName}`);
      }
    }
    if (matches.length !== 1) throw new Error('Realtime binding count is invalid');
    bindings.push(matches[0]);
  }

  for (const module of modules) {
    for (const provider of module.providers) {
      const expression = unwrapExpression(provider);
      if (!ts.isObjectLiteralExpression(expression) && !constInitializer(expression, checker)) continue;
      const object = resolveStaticObject(expression, checker, 'Realtime binding');
      if (!object.has('useExisting')) continue;
      const useExisting = object.get('useExisting');
      if (!expressionHasSymbol(useExisting, publisher, checker)
          && !expressionHasSymbol(useExisting, implementationToken, checker)) continue;
      const provide = object.get('provide');
      const isExpected = expectedBindings.some((expected) => module.path === expected.contract.modulePath
        && provide && expressionHasSymbol(provide, expected.provide, checker)
        && expressionHasSymbol(useExisting, expected.useExisting, checker));
      if (!isExpected) throw new Error('Realtime publisher binding identity is invalid');
    }
  }

  const importers = modules.filter((module) => module.imports.some(
    (entry) => expressionHasSymbol(entry, realtimeModule, checker),
  )).map((module) => module.path).sort(compareText);
  return Object.freeze({
    importers: Object.freeze([...new Set(importers)]),
    providerOwners: Object.freeze(ownership.providerOwners),
    exportOwners: Object.freeze(ownership.exportOwners),
    duplicateProviders: 0,
    bindings: Object.freeze(bindings),
  });
}

function readJsonFile(fileName, label) {
  let value;
  try {
    value = JSON.parse(fs.readFileSync(fileName, 'utf8'));
  } catch {
    throw new Error(`${label} cannot be read`);
  }
  assertPlainDenseJson(value, label);
  return value;
}

function findInstalledPackageRoot(entrypoint, packageName) {
  let cursor = path.dirname(entrypoint);
  const root = path.parse(cursor).root;
  while (cursor !== root) {
    const packagePath = path.join(cursor, 'package.json');
    if (fs.existsSync(packagePath)) {
      const candidate = readJsonFile(packagePath, 'R8 installed package');
      if (candidate.name === packageName) return { root: cursor, packageJson: candidate };
    }
    cursor = path.dirname(cursor);
  }
  throw new Error('R8 external installed package identity cannot be resolved');
}

function verifyScheduleRootShim(installed, resolved, canonicalEntrypoint) {
  const shimPath = path.join(installed.root, 'index.js');
  let shimStatus;
  let shimTarget;
  try {
    shimStatus = fs.lstatSync(shimPath);
    shimTarget = createRequire(shimPath).resolve('./dist');
  } catch {
    throw new Error('R8 Schedule root forwarding shim is invalid');
  }
  const hasOwn = (name) => Object.prototype.hasOwnProperty.call(installed.packageJson, name);
  if (hasOwn('main') || hasOwn('exports') || shimStatus.isSymbolicLink() || !shimStatus.isFile()
      || fs.realpathSync(resolved) !== fs.realpathSync(shimPath)
      || crypto.createHash('sha256').update(fs.readFileSync(shimPath)).digest('hex')
        !== SCHEDULE_6_1_3_ROOT_SHIM_SHA256
      || fs.realpathSync(shimTarget) !== canonicalEntrypoint) {
    throw new Error('R8 Schedule root forwarding shim is invalid');
  }
}

function verifyInstalledExternalIdentity(backendRoot, identity) {
  const localRequire = createRequire(path.join(backendRoot, 'package.json'));
  let resolved;
  try {
    resolved = localRequire.resolve(identity.packageName);
  } catch {
    throw new Error('R8 external installed package cannot be resolved');
  }
  const installed = findInstalledPackageRoot(resolved, identity.packageName);
  const rootStatus = fs.lstatSync(installed.root);
  const entrypoint = path.join(installed.root, ...identity.installedEntrypoint.split('/'));
  const entryStatus = fs.lstatSync(entrypoint);
  const resolvedStatus = fs.lstatSync(resolved);
  const canonicalResolved = fs.realpathSync(resolved);
  const canonicalEntrypoint = fs.realpathSync(entrypoint);
  let lockedResolution;
  try {
    lockedResolution = localRequire.resolve(
      `${identity.packageName}/${identity.installedEntrypoint}`,
    );
  } catch {
    throw new Error('R8 external locked entrypoint cannot be resolved');
  }
  const canonicalLockedEntrypoint = fs.realpathSync(lockedResolution);
  const isLockedSchedule = identity.packageName === '@nestjs/schedule'
    && identity.lockedVersion === '6.1.3';
  if (isLockedSchedule) {
    verifyScheduleRootShim(installed, resolved, canonicalEntrypoint);
  }
  if (rootStatus.isSymbolicLink() || !rootStatus.isDirectory()
      || entryStatus.isSymbolicLink() || !entryStatus.isFile()
      || resolvedStatus.isSymbolicLink() || !resolvedStatus.isFile()
      || installed.packageJson.version !== identity.lockedVersion
      || !isInside(installed.root, resolved) || !isInside(installed.root, entrypoint)
      || !isInside(installed.root, lockedResolution)
      || canonicalLockedEntrypoint !== canonicalEntrypoint
      || (!isLockedSchedule && canonicalResolved !== canonicalEntrypoint)) {
    throw new Error('R8 external installed package identity is invalid');
  }
  const exported = localRequire(identity.packageName);
  const lockedExported = localRequire(
    `${identity.packageName}/${identity.installedEntrypoint}`,
  );
  if (!exported || !lockedExported || typeof exported[identity.importedClass] !== 'function'
      || exported[identity.importedClass] !== lockedExported[identity.importedClass]) {
    throw new Error('R8 external installed class identity is invalid');
  }
  if (identity.globalMechanism === 'dynamic-module-global') {
    const factory = exported[identity.importedClass][identity.factoryMethod];
    const dynamicModule = typeof factory === 'function'
      ? factory.call(exported[identity.importedClass])
      : null;
    if (!dynamicModule || dynamicModule.global !== true) {
      throw new Error('R8 external DynamicModule global behavior is invalid');
    }
  } else if (identity.globalMechanism === 'global-decorator') {
    localRequire('reflect-metadata');
    const constants = localRequire('@nestjs/common/constants');
    if (!constants || typeof constants.GLOBAL_MODULE_METADATA !== 'string'
        || Reflect.getMetadata(
          constants.GLOBAL_MODULE_METADATA,
          exported[identity.importedClass],
        ) !== true) {
      throw new Error('R8 external global decorator behavior is invalid');
    }
  } else {
    throw new Error('R8 external global mechanism is invalid');
  }
}

function verifyExternalSourceCall(repositoryRoot, identity, program, checker) {
  const sourceFile = projectSourceFiles(program, repositoryRoot).find(
    (entry) => entry.path === identity.sourcePath,
  )?.sourceFile;
  if (!sourceFile) throw new Error('R8 external canonical source is missing');
  const importedSymbols = [];
  for (const statement of sourceFile.statements) {
    if (!ts.isImportDeclaration(statement) || !ts.isStringLiteral(statement.moduleSpecifier)
        || statement.moduleSpecifier.text !== identity.packageName || !statement.importClause) continue;
    const bindings = statement.importClause.namedBindings;
    if (!bindings || !ts.isNamedImports(bindings)) continue;
    for (const element of bindings.elements) {
      const importedName = element.propertyName ? element.propertyName.text : element.name.text;
      if (importedName === identity.importedClass) {
        importedSymbols.push(resolveAlias(checker.getSymbolAtLocation(element.name), checker));
      }
    }
  }
  if (importedSymbols.length !== 1 || !importedSymbols[0]
      || !(importedSymbols[0].declarations || []).some(
        (declaration) => declarationFromPackage(declaration, identity.packageName),
      )) {
    throw new Error('R8 external imported class identity is invalid');
  }
  let calls = 0;
  function visit(node) {
    if (ts.isCallExpression(node)) {
      const member = callMember(node.expression, checker);
      if (member && member.name === identity.factoryMethod
          && sameSymbol(symbolAtExpression(member.receiver, checker), importedSymbols[0], checker)) {
        calls += 1;
      }
    }
    ts.forEachChild(node, visit);
  }
  visit(sourceFile);
  if (calls !== identity.callCount) throw new Error('R8 external call identity count is invalid');
}

function verifyExternalGlobalIdentities(repositoryRoot, manifestValue, analysis = null) {
  const manifest = validateR8Manifest(manifestValue);
  const backendRoot = path.join(repositoryRoot, 'backend');
  const packageJson = readJsonFile(path.join(backendRoot, 'package.json'), 'R8 package');
  const packageLock = readJsonFile(path.join(backendRoot, 'package-lock.json'), 'R8 package lock');
  const dependencies = packageJson.dependencies;
  const lockPackages = packageLock.packages;
  if (!dependencies || typeof dependencies !== 'object' || !lockPackages
      || typeof lockPackages !== 'object' || !lockPackages['']
      || typeof lockPackages[''] !== 'object' || !lockPackages[''].dependencies) {
    throw new Error('R8 external package graph is invalid');
  }
  const { program, checker } = analysis || createProgram(repositoryRoot);
  const packages = [];
  for (const identity of manifest.externalGlobalIdentities) {
    const lockKey = `node_modules/${identity.packageName}`;
    const locked = lockPackages[lockKey];
    if (dependencies[identity.packageName] !== identity.declaredRange
        || lockPackages[''].dependencies[identity.packageName] !== identity.declaredRange
        || !locked || locked.version !== identity.lockedVersion
        || locked.resolved !== identity.resolved || locked.integrity !== identity.integrity
        || locked.link === true) {
      throw new Error('R8 external package lock identity is invalid');
    }
    verifyExternalSourceCall(repositoryRoot, identity, program, checker);
    verifyInstalledExternalIdentity(backendRoot, identity);
    packages.push(`${identity.packageName}@${identity.lockedVersion}`);
  }
  return Object.freeze({ identities: packages.length, packages: Object.freeze(packages) });
}

function projectR3InventoryForR8(inventory, manifestValue) {
  const manifest = validateR8Manifest(manifestValue);
  if (manifest.stage !== 'strict') throw new Error('R8 strict projection is required');
  assertPlainDenseJson(inventory, 'R8 R3 inventory');
  if (!inventory || typeof inventory !== 'object' || Array.isArray(inventory)
      || !Array.isArray(inventory.legacyModules)) {
    throw new Error('R8 R3 projection inventory is invalid');
  }
  const canonicalInventory = readJsonFile(
    path.join(REPOSITORY_ROOT, ...manifest.r3Projection.inventoryPath.split('/')),
    'R8 canonical R3 inventory',
  );
  if (canonicalJson(inventory) !== canonicalJson(canonicalInventory)) {
    throw new Error('R8 R3 projection inventory identity is invalid');
  }
  const projected = JSON.parse(JSON.stringify(inventory));
  for (const transition of manifest.r3Projection.globalTransitions) {
    const matches = projected.legacyModules.filter((entry) => entry.path === transition.path);
    if (matches.length !== 1 || matches[0].className !== transition.className
        || matches[0].global !== transition.before) {
      throw new Error('R8 R3 global projection identity is invalid');
    }
    matches[0].global = transition.after;
  }
  const transition = manifest.r3Projection.importTransition;
  const matches = projected.legacyModules.filter((entry) => entry.path === transition.path);
  if (matches.length !== 1 || matches[0].className !== transition.className
      || canonicalJson(matches[0].imports) !== canonicalJson(transition.before)) {
    throw new Error('R8 R3 import projection identity is invalid');
  }
  matches[0].imports = [...transition.after];
  return deepFrozenCopy(projected);
}

function verifyBaselines(repositoryRoot) {
  const dependency = readJsonFile(
    path.join(repositoryRoot, 'backend', '.dependency-cruiser-known-violations.json'),
    'R8 dependency baseline',
  );
  const ownership = readJsonFile(
    path.join(repositoryRoot, 'backend', 'architecture', 'ownership-baseline.json'),
    'R8 ownership baseline',
  );
  if (!Array.isArray(dependency) || !ownership || !Array.isArray(ownership.violations)) {
    throw new Error('R8 baseline schema is invalid');
  }
  let occurrences = 0;
  for (const violation of ownership.violations) {
    if (!violation || !Number.isSafeInteger(violation.count) || violation.count < 1) {
      throw new Error('R8 ownership baseline occurrence is invalid');
    }
    occurrences += violation.count;
  }
  return Object.freeze({
    dependencyRecords: dependency.length,
    ownershipRecords: ownership.violations.length,
    ownershipOccurrences: occurrences,
  });
}

function validateStringArray(value, label) {
  if (!Array.isArray(value) || value.some((entry) => typeof entry !== 'string' || !entry)) {
    throw new Error(`${label} scan result schema is invalid`);
  }
  if (new Set(value).size !== value.length
      || canonicalJson(value) !== canonicalJson([...value].sort(compareText))) {
    throw new Error(`${label} scan result ordering is invalid`);
  }
  return value;
}

function validateR8ScanResult(value) {
  assertPlainDenseJson(value, 'R8 scan result');
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error('R8 scan result schema is invalid');
  }
  assertExactKeys(value, [
    'stage',
    'globals',
    'prisma',
    'realtime',
    'external',
    'dependencyRecords',
    'ownershipRecords',
    'ownershipOccurrences',
  ], 'R8 scan result');
  assertExactKeys(value.globals, [
    'projectOwnedGlobals', 'forwardRef', 'nestModuleCycles',
  ], 'R8 global scan result');
  assertExactKeys(value.prisma, [
    'importers', 'missingImporters', 'duplicateProviders',
  ], 'R8 Prisma scan result');
  assertExactKeys(value.realtime, [
    'importers', 'duplicateProviders',
  ], 'R8 Realtime scan result');
  assertExactKeys(value.external, ['identities'], 'R8 external scan result');
  if (!['design', 'strict'].includes(value.stage)) {
    throw new Error('R8 scan result stage is invalid');
  }
  const importers = validateStringArray(value.prisma.importers, 'R8 Prisma');
  const missing = validateStringArray(value.prisma.missingImporters, 'R8 Prisma missing');
  const realtimeImporters = validateStringArray(value.realtime.importers, 'R8 Realtime');
  const integers = [
    value.globals.projectOwnedGlobals,
    value.globals.forwardRef,
    value.globals.nestModuleCycles,
    value.prisma.duplicateProviders,
    value.realtime.duplicateProviders,
    value.external.identities,
    value.dependencyRecords,
    value.ownershipRecords,
    value.ownershipOccurrences,
  ];
  if (integers.some((entry) => !Number.isSafeInteger(entry) || entry < 0)) {
    throw new Error('R8 scan result count is invalid');
  }
  const design = value.stage === 'design';
  if (value.globals.projectOwnedGlobals !== (design
    ? EXPECTED_COUNTS.designProjectOwnedGlobals
    : EXPECTED_COUNTS.strictProjectOwnedGlobals)
      || importers.length !== (design
        ? EXPECTED_COUNTS.designPrismaImporters
        : EXPECTED_COUNTS.strictPrismaImporters)
      || missing.length !== (design ? 1 : 0)
      || realtimeImporters.length !== EXPECTED_COUNTS.realtimeImporters
      || value.prisma.duplicateProviders !== EXPECTED_COUNTS.duplicateProviders
      || value.realtime.duplicateProviders !== EXPECTED_COUNTS.duplicateProviders
      || value.globals.forwardRef !== EXPECTED_COUNTS.forwardRef
      || value.globals.nestModuleCycles !== EXPECTED_COUNTS.nestModuleCycles
      || value.external.identities !== EXPECTED_EXTERNAL_GLOBAL_IDENTITIES.length
      || value.dependencyRecords !== EXPECTED_COUNTS.dependencyRecords
      || value.ownershipRecords !== EXPECTED_COUNTS.ownershipRecords
      || value.ownershipOccurrences !== EXPECTED_COUNTS.ownershipOccurrences) {
    throw new Error('R8 scan result does not match the stage contract');
  }
  return Object.freeze({
    ok: true,
    stage: value.stage,
    projectOwnedGlobals: value.globals.projectOwnedGlobals,
    prismaImporters: importers.length,
    missingPrismaImporters: Object.freeze([...missing]),
    realtimeImporters: realtimeImporters.length,
    duplicateProviders: value.prisma.duplicateProviders + value.realtime.duplicateProviders,
    forwardRef: value.globals.forwardRef,
    nestModuleCycles: value.globals.nestModuleCycles,
    dependencyRecords: value.dependencyRecords,
    ownershipRecords: value.ownershipRecords,
    ownershipOccurrences: value.ownershipOccurrences,
  });
}

function scanR8GlobalRemoval(options) {
  if (!options || typeof options !== 'object' || Array.isArray(options)
      || typeof options.repositoryRoot !== 'string' || !path.isAbsolute(options.repositoryRoot)) {
    throw new Error('R8 scan options are invalid');
  }
  const manifest = validateR8Manifest(options.manifest);
  const analysis = createProgram(options.repositoryRoot);
  const globals = collectProjectGlobalActivations(
    analysis.program,
    analysis.checker,
    options.repositoryRoot,
  );
  const prisma = collectDirectPrismaConsumers(
    analysis.program,
    analysis.checker,
    options.repositoryRoot,
  );
  const realtime = collectRealtimeComposition(
    analysis.program,
    analysis.checker,
    options.repositoryRoot,
  );
  const external = verifyExternalGlobalIdentities(
    options.repositoryRoot,
    manifest,
    analysis,
  );
  const baselines = verifyBaselines(options.repositoryRoot);
  const expectedGlobalPaths = manifest.stage === 'design'
    ? manifest.r3Projection.globalTransitions.map((entry) => entry.path).sort(compareText)
    : [];
  const expectedBindings = manifest.messagingBindings.map(
    (entry) => `${entry.modulePath}#${entry.provideName}->${entry.useExistingName}`,
  );
  const expectedOwner = (provider) => [`${provider.modulePath}#${provider.moduleClass}`];
  if (canonicalJson(globals.globalPaths) !== canonicalJson(expectedGlobalPaths)
      || canonicalJson(prisma.strictImporters) !== canonicalJson(
        manifest.projectProviders.prisma.strictImporters,
      )
      || canonicalJson(realtime.importers) !== canonicalJson(
        manifest.projectProviders.realtime.strictImporters,
      )
      || canonicalJson(prisma.providerOwners) !== canonicalJson(
        expectedOwner(manifest.projectProviders.prisma),
      )
      || canonicalJson(prisma.exportOwners) !== canonicalJson(
        expectedOwner(manifest.projectProviders.prisma),
      )
      || canonicalJson(realtime.providerOwners) !== canonicalJson(
        expectedOwner(manifest.projectProviders.realtime),
      )
      || canonicalJson(realtime.exportOwners) !== canonicalJson(
        expectedOwner(manifest.projectProviders.realtime),
      )
      || canonicalJson(realtime.bindings) !== canonicalJson(expectedBindings)) {
    throw new Error('R8 live provider or global identity drift detected');
  }
  return validateR8ScanResult({
    stage: manifest.stage,
    globals: {
      projectOwnedGlobals: globals.projectOwnedGlobals,
      forwardRef: globals.forwardRef,
      nestModuleCycles: globals.nestModuleCycles,
    },
    prisma: {
      importers: [...prisma.importers],
      missingImporters: [...prisma.missingImporters],
      duplicateProviders: prisma.duplicateProviders,
    },
    realtime: {
      importers: [...realtime.importers],
      duplicateProviders: realtime.duplicateProviders,
    },
    external: { identities: external.identities },
    ...baselines,
  });
}

function runCli({
  argv = process.argv.slice(2),
  repositoryRoot = REPOSITORY_ROOT,
  stdout = (message) => process.stdout.write(`${message}\n`),
  stderr = (message) => process.stderr.write(`${message}\n`),
} = {}) {
  try {
    if (!Array.isArray(argv) || argv.length !== 1 || argv[0] !== '--check') {
      throw new Error('R8 CLI arguments are invalid');
    }
    const manifest = readJsonFile(
      path.join(repositoryRoot, 'backend', 'architecture', 'r8-global-module-removal.json'),
      'R8 manifest',
    );
    const result = scanR8GlobalRemoval({ repositoryRoot, manifest });
    stdout(`PASS - R8 global removal: stage=${result.stage}`
      + `, globals=${result.projectOwnedGlobals}`
      + `, Prisma=${result.prismaImporters}/${EXPECTED_COUNTS.strictPrismaImporters}`
      + `, missing=${result.missingPrismaImporters.length}`
      + `, Realtime=${result.realtimeImporters}`
      + `, duplicates=${result.duplicateProviders}`
      + `, forwardRef=${result.forwardRef}`
      + `, cycles=${result.nestModuleCycles}`
      + `, dependency=${result.dependencyRecords}`
      + `, ownership=${result.ownershipRecords}/${result.ownershipOccurrences}`);
    return 0;
  } catch {
    stderr('ERROR - R8 global removal validation failed');
    return 2;
  }
}

module.exports = {
  R8_BASE,
  EXPECTED_ALLOWED_PATHS,
  collectDirectPrismaConsumers,
  collectProjectGlobalActivations,
  collectRealtimeComposition,
  createProgram,
  projectR3InventoryForR8,
  runCli,
  scanR8GlobalRemoval,
  validateR8Manifest,
  validateR8ScanResult,
  verifyExternalGlobalIdentities,
};

if (require.main === module) process.exitCode = runCli();
