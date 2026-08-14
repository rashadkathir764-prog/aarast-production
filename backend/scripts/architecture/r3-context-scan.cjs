'use strict';

const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { types: utilTypes } = require('node:util');
const ts = require('typescript');
const { scanPorts } = require('./ports-scan.cjs');

const R3_BASE = '6b06eb096aca8cc6684d365d16e05d4cd8529898';
const CONTEXTS = Object.freeze([
  'identity', 'planning', 'finance', 'collaboration', 'tasks', 'guests',
  'marketplace', 'messaging', 'notifications', 'catalog', 'media', 'insights',
  'backoffice',
]);
const ROOTS = Object.freeze({
  identity: ['auth', 'users', 'me', 'contexts'],
  planning: ['wedding-plans', 'onboarding'],
  finance: ['money', 'budget-categories', 'wedding-costs'],
  collaboration: ['sharing', 'contribution-history'],
  tasks: ['tasks'], guests: ['guests'],
  marketplace: ['marketplace', 'provider-dashboard'],
  messaging: ['conversations'], notifications: ['notifications', 'push'],
  catalog: ['catalogs'], media: ['media'], insights: ['dashboard', 'timeline'],
  backoffice: ['admin'],
});
const ROOT_TO_CONTEXT = new Map(
  Object.entries(ROOTS).flatMap(([context, roots]) => roots.map((root) => [root, context])),
);
const DIAGNOSTIC_KINDS = new Set([
  'unresolved-nest-metadata', 'duplicate-provider', 'hollow-public-token',
  'concrete-public-export', 'illegal-boundary-import', 'illegal-composition-import',
  'public-binding-not-use-existing', 'public-imports-concrete',
  'implementation-token-misuse', 'forward-ref', 'unknown-context',
  'nest-module-cycle', 'inventory-drift',
]);
const COUNT_KEYS = Object.freeze([
  'contexts', 'legacyModules', 'crossContextInjections', 'compositionDependencies',
  'initialDuplicateProviders', 'remainingDuplicateProviders',
  'initialPlatformDebts', 'remainingPlatformDebts',
  'initialRetiredLegacyProviderEdges', 'remainingRetiredLegacyProviderEdges',
  'forwardRef', 'globals', 'nestModuleCycles', 'illegalEdges',
]);
const EXACT_DUPLICATE_PROVIDERS = Object.freeze([
  'AdminGuard', 'AdminPermissionGuard', 'PermissionService',
]);
const EXACT_PLATFORM_DEBTS = Object.freeze([
  'runtime-jwt-secret', 'readiness-media-storage', 'outbox-dispatcher-realtime',
  'outbox-dispatcher-push', 'outbox-module-realtime', 'outbox-module-push',
]);
const DUPLICATE_RETIREMENT_TASK = Object.freeze({
  AdminGuard: 7,
  AdminPermissionGuard: 7,
  PermissionService: 3,
});
const PLATFORM_RETIREMENT_TASK = Object.freeze({
  'runtime-jwt-secret': 5,
  'readiness-media-storage': 2,
  'outbox-dispatcher-realtime': 2,
  'outbox-dispatcher-push': 2,
  'outbox-module-realtime': 2,
  'outbox-module-push': 2,
});
const APPROVED_DUPLICATE_IDENTITIES = new Map([
  ['AdminGuard', 'backend/src/admin/admin.guard.ts'],
  ['AdminPermissionGuard', 'backend/src/admin/admin-permission.guard.ts'],
  ['PermissionService', 'backend/src/sharing/permission.service.ts'],
]);
const APPROVED_DUPLICATE_REGISTRATIONS = new Map([
  ['AdminGuard', new Set(['backend/src/admin/admin.module.ts', 'backend/src/catalogs/catalogs.module.ts'])],
  ['AdminPermissionGuard', new Set(['backend/src/admin/admin.module.ts', 'backend/src/catalogs/catalogs.module.ts'])],
  ['PermissionService', new Set(['backend/src/sharing/sharing.module.ts', 'backend/src/notifications/notifications.module.ts'])],
]);
const EXTERNAL_PROVIDER_CONTRACTS = new Map([
  ['IDENTITY_ACCESS_TOKEN_VERIFIER', Object.freeze({
    implementation: 'JwtService',
    module: 'JwtModule',
    packageName: '@nestjs/jwt',
  })],
]);
const COMPOSITION_DEPENDENCIES = Object.freeze([
  { key: 'app-jwt-module-availability', kind: 'module-availability', retirementTask: 5 },
  { key: 'readiness-media-storage', kind: 'provider', retirementTask: 2 },
  { key: 'outbox-dispatcher-realtime', kind: 'provider', retirementTask: 2 },
  { key: 'outbox-dispatcher-push', kind: 'provider', retirementTask: 2 },
  { key: 'outbox-module-realtime', kind: 'module', retirementTask: 2 },
  { key: 'outbox-module-push', kind: 'module', retirementTask: 2 },
]);
const CONTRACT_SHAPE_HASH = 'c8cd93a74fe8ebcd79dd2cddd3b392b83171ef0752cb2f7545a0b03f48b4d8a5';
const INITIAL_RETIRED_LEDGER_HASH = '18fb99438d6b7002ca3f55aac407985fa13252aff3a59073d126fa3dc4c9b3a3';
const MAX_ARRAY_ITEMS = 1000;
const MAX_TEXT_LENGTH = 2048;

function plainObject(value, label) {
  if (!value || typeof value !== 'object' || Array.isArray(value) || utilTypes.isProxy(value)
      || Object.getPrototypeOf(value) !== Object.prototype) {
    throw new Error(`${label} must be a plain object`);
  }
  for (const key of Reflect.ownKeys(value)) {
    if (typeof key !== 'string') throw new Error(`${label} must use string data properties only`);
    const descriptor = Object.getOwnPropertyDescriptor(value, key);
    if (!descriptor || !descriptor.enumerable
        || !Object.prototype.hasOwnProperty.call(descriptor, 'value')) {
      throw new Error(`${label} must use data properties; accessor found`);
    }
  }
  return value;
}

function denseArray(value, label) {
  if (!Array.isArray(value) || utilTypes.isProxy(value)
      || Object.getPrototypeOf(value) !== Array.prototype) {
    throw new Error(`${label} must be a plain array`);
  }
  if (value.length > MAX_ARRAY_ITEMS) throw new Error(`${label} is oversized`);
  for (let index = 0; index < value.length; index += 1) {
    const descriptor = Object.getOwnPropertyDescriptor(value, String(index));
    if (!descriptor) throw new Error(`${label} must be dense`);
    if (!descriptor.enumerable || !Object.prototype.hasOwnProperty.call(descriptor, 'value')) {
      throw new Error(`${label} must use data properties; accessor found`);
    }
  }
  const ownKeys = Reflect.ownKeys(value);
  if (ownKeys.some((key) => typeof key !== 'string') || ownKeys.length !== value.length + 1
      || !ownKeys.includes('length')) {
    throw new Error(`${label} must contain plain array data properties only`);
  }
  const lengthDescriptor = Object.getOwnPropertyDescriptor(value, 'length');
  if (!lengthDescriptor || !Object.prototype.hasOwnProperty.call(lengthDescriptor, 'value')) {
    throw new Error(`${label} must use a data length property`);
  }
  return value;
}

function assertDeepPlainData(value, label, seen = new Set(), depth = 0) {
  if (value === null || typeof value === 'string' || typeof value === 'boolean'
      || (typeof value === 'number' && Number.isFinite(value))) return;
  if (!value || typeof value !== 'object' || depth > 32 || seen.has(value)) {
    throw new Error(`${label} must be bounded plain data`);
  }
  seen.add(value);
  if (Array.isArray(value)) {
    const items = denseArray(value, label);
    for (let index = 0; index < items.length; index += 1) {
      const descriptor = Object.getOwnPropertyDescriptor(items, String(index));
      assertDeepPlainData(descriptor.value, `${label}[${index}]`, seen, depth + 1);
    }
  } else {
    const object = plainObject(value, label);
    for (const key of Object.keys(object)) {
      const descriptor = Object.getOwnPropertyDescriptor(object, key);
      assertDeepPlainData(descriptor.value, `${label}.${key}`, seen, depth + 1);
    }
  }
  seen.delete(value);
}

function exactObject(value, keys, label) {
  const object = plainObject(value, label);
  if (Object.keys(object).sort().join('|') !== [...keys].sort().join('|')) {
    throw new Error(`${label} keys are invalid`);
  }
  return object;
}

function text(value, label, pattern = null) {
  if (typeof value !== 'string' || value.length === 0 || value.length > MAX_TEXT_LENGTH
      || /[\u0000-\u0008\u000b\u000c\u000e-\u001f]/u.test(value)
      || (pattern && !pattern.test(value))) {
    throw new Error(`${label} has invalid length or text`);
  }
  return value;
}

function recordArray(value, label, validateRecord, keyOf) {
  const records = denseArray(value, label).map((item, index) => validateRecord(item, `${label}[${index}]`));
  const keys = records.map(keyOf);
  if (new Set(keys).size !== keys.length) throw new Error(`${label} contains a duplicate`);
  const sorted = [...keys].sort();
  if (keys.join('|') !== sorted.join('|')) throw new Error(`${label} is not in canonical order`);
  return records;
}

function sha256(value) {
  return crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
}

function uniqueStrings(value, label) {
  const items = denseArray(value, label);
  if (items.some((item) => typeof item !== 'string' || !item || item.length > MAX_TEXT_LENGTH)) {
    throw new Error(`${label} must contain bounded strings`);
  }
  if (new Set(items).size !== items.length) throw new Error(`${label} contains a duplicate`);
  return items;
}

function validateR3ContextManifest(value) {
  assertDeepPlainData(value, 'R3 context manifest');
  const manifest = plainObject(value, 'R3 context manifest');
  const required = [
    'schemaVersion', 'baseRevision', 'stage', 'contexts', 'contextRoots',
    'legacyModules', 'crossContextInjections', 'compositionDependencies',
    'providerContracts', 'decoratorRuntimeReferences', 'adminGuardMetadata',
    'runtimeDecoratorValueReferences', 'lifecycleProviders',
    'initialDuplicateProviders', 'remainingDuplicateProviders',
    'initialPlatformDebts', 'remainingPlatformDebts',
    'initialRetiredLegacyProviderEdges', 'remainingRetiredLegacyProviderEdges',
    'allowedChangedPaths',
  ];
  if (Object.keys(manifest).sort().join('|') !== [...required].sort().join('|')) {
    throw new Error('R3 context manifest keys are invalid');
  }
  const stageMatch = typeof manifest.stage === 'string' && /^(?:inventory|task-[2-8])$/u.exec(manifest.stage);
  if (manifest.schemaVersion !== 1 || manifest.baseRevision !== R3_BASE || !stageMatch) {
    throw new Error('R3 context manifest identity is invalid');
  }
  const completedTask = manifest.stage === 'inventory' ? 1 : Number(manifest.stage.slice('task-'.length));
  const contexts = uniqueStrings(manifest.contexts, 'contexts');
  if (contexts.join('|') !== CONTEXTS.join('|')) throw new Error('contexts do not match the canonical set');
  const contextRoots = denseArray(manifest.contextRoots, 'context roots').map((item, index) => {
    const record = exactObject(item, ['context', 'legacyRoots'], `context roots[${index}]`);
    text(record.context, 'context root context', /^[a-z-]+$/u);
    uniqueStrings(record.legacyRoots, 'context legacy roots').forEach((root) => text(root, 'legacy root', /^[a-z-]+$/u));
    return record;
  });
  if (JSON.stringify(contextRoots) !== JSON.stringify(Object.entries(ROOTS).map(([context, legacyRoots]) => ({ context, legacyRoots })))) {
    throw new Error('context root inventory is not canonical');
  }
  const validateStringList = (items, label) => uniqueStrings(items, label).map((item) => text(item, label));
  const legacyModules = recordArray(manifest.legacyModules, 'legacy modules', (item, label) => {
    const record = exactObject(item, ['path', 'className', 'imports', 'providers', 'exports', 'global'], label);
    text(record.path, `${label} path`, /^backend\/src\/.+\.ts$/u);
    text(record.className, `${label} class`, /^[A-Za-z_$][\w$]*$/u);
    for (const key of ['imports', 'providers', 'exports']) validateStringList(record[key], `${label} ${key}`);
    if (typeof record.global !== 'boolean') throw new Error(`${label} global is invalid`);
    return record;
  }, (record) => `${record.path}|${record.className}`);
  const injections = recordArray(manifest.crossContextInjections, 'cross-context injections', (item, label) => {
    const record = exactObject(item, ['source', 'parameter', 'target', 'targetPath', 'sourceContext', 'targetContext', 'kind'], label);
    text(record.source, `${label} source`, /^backend\/src\/.+\.ts$/u);
    text(record.targetPath, `${label} target path`, /^backend\/src\/.+\.ts$/u);
    for (const key of ['parameter', 'target']) text(record[key], `${label} ${key}`, /^[A-Za-z_$][\w$]*$/u);
    if (!CONTEXTS.includes(record.sourceContext) || !CONTEXTS.includes(record.targetContext)
        || record.sourceContext === record.targetContext || record.kind !== 'constructor-injection') {
      throw new Error(`${label} context or kind is invalid`);
    }
    return record;
  }, (record) => `${record.source}|${record.parameter}|${record.target}`);
  void legacyModules;
  void injections;
  const composition = denseArray(manifest.compositionDependencies, 'composition dependencies').map((item, index) => {
    const label = `composition dependencies[${index}]`;
    const record = exactObject(item, ['key', 'kind', 'retirementTask'], label);
    text(record.key, `${label} key`, /^[a-z0-9-]+$/u);
    if (!['module-availability', 'provider', 'module'].includes(record.kind)
        || ![2, 5].includes(record.retirementTask)) throw new Error(`${label} is invalid`);
    return record;
  });
  if (JSON.stringify(composition) !== JSON.stringify(COMPOSITION_DEPENDENCIES)) {
    throw new Error('composition dependency inventory is not canonical');
  }
  const providerContracts = denseArray(manifest.providerContracts, 'provider contracts').map((item, index) => {
    const label = `provider contracts[${index}]`;
    const record = exactObject(item, ['token', 'methods', 'implementations', 'consumers'], label);
    text(record.token, `${label} token`, /^[A-Z][A-Z0-9_]+$/u);
    validateStringList(record.methods, `${label} methods`).forEach((method) => text(method, `${label} method`, /^[A-Za-z_$][\w$]*$/u));
    validateStringList(record.implementations, `${label} implementations`).forEach((name) => text(name, `${label} implementation`, /^[A-Za-z_$][\w$]*$/u));
    recordArray(record.consumers, `${label} consumers`, (consumer, consumerLabel) => {
      const value = exactObject(consumer, ['source', 'kind'], consumerLabel);
      text(value.source, `${consumerLabel} source`, /^backend\/src\/.+\.ts$/u);
      if (!['constructor-injection', 'function-parameter', 'type-only', 'pure-function'].includes(value.kind)) {
        throw new Error(`${consumerLabel} kind is invalid`);
      }
      return value;
    }, (consumer) => `${consumer.source}|${consumer.kind}`);
    if (record.consumers.length === 0) throw new Error(`${label} has no present consumer`);
    return record;
  });
  const contractShape = providerContracts.map(({ token, methods, implementations }) => ({ token, methods, implementations }));
  if (sha256(contractShape) !== CONTRACT_SHAPE_HASH) throw new Error('provider contract inventory is not canonical');
  const validateUse = (item, label) => {
    const record = exactObject(item, ['controllerClass', 'method', 'routePrefix', 'routeMethod', 'routePath', 'parameterIndex'], label);
    text(record.controllerClass, `${label} controller`, /^[A-Za-z_$][\w$]*$/u);
    if (record.method !== null) text(record.method, `${label} method`, /^[A-Za-z_$][\w$]*$/u);
    for (const key of ['routePrefix', 'routePath']) {
      if (record[key] !== null && (typeof record[key] !== 'string' || record[key].length > MAX_TEXT_LENGTH
          || /[\u0000-\u0008\u000b\u000c\u000e-\u001f]/u.test(record[key]))) {
        throw new Error(`${label} ${key} is invalid`);
      }
    }
    if (record.routeMethod !== null) text(record.routeMethod, `${label} routeMethod`, /^[A-Z]+$/u);
    if (record.parameterIndex !== null && (!Number.isSafeInteger(record.parameterIndex) || record.parameterIndex < 0)) {
      throw new Error(`${label} parameter index is invalid`);
    }
    return record;
  };
  const validateDecoratorRecords = (items, label, kinds) => recordArray(items, label, (item, itemLabel) => {
    const record = exactObject(item, ['source', 'symbol', 'kind', 'uses'], itemLabel);
    text(record.source, `${itemLabel} source`, /^backend\/src\/.+\.ts$/u);
    text(record.symbol, `${itemLabel} symbol`, /^[A-Z][A-Za-z0-9_]+$/u);
    if (!kinds.includes(record.kind)) throw new Error(`${itemLabel} kind is invalid`);
    recordArray(record.uses, `${itemLabel} uses`, validateUse, (use) => (
      `${use.controllerClass}|${use.method}|${use.routeMethod}|${use.routePath}|${use.parameterIndex}`
    ));
    if (record.uses.length === 0) throw new Error(`${itemLabel} has no actual use`);
    return record;
  }, (record) => `${record.source}|${record.symbol}`);
  validateDecoratorRecords(manifest.decoratorRuntimeReferences, 'decorator runtime references', ['decorator-runtime']);
  validateDecoratorRecords(manifest.runtimeDecoratorValueReferences, 'runtime decorator value references', ['runtime-decorator', 'runtime-value']);
  recordArray(manifest.adminGuardMetadata, 'Admin guard metadata', (item, label) => {
    const record = exactObject(item, ['source', 'controllerClass', 'routePrefix', 'guards'], label);
    text(record.source, `${label} source`, /^backend\/src\/.+\.controller\.ts$/u);
    text(record.controllerClass, `${label} controller`, /^[A-Za-z_$][\w$]*$/u);
    text(record.routePrefix, `${label} route prefix`);
    validateStringList(record.guards, `${label} guards`).forEach((guard) => text(guard, `${label} guard`, /^[A-Za-z_$][\w$]*$/u));
    return record;
  }, (record) => `${record.source}|${record.controllerClass}`);
  recordArray(manifest.lifecycleProviders, 'lifecycle providers', (item, label) => {
    const record = exactObject(item, ['className', 'path'], label);
    text(record.className, `${label} class`, /^[A-Za-z_$][\w$]*$/u);
    text(record.path, `${label} path`, /^backend\/src\/.+\.ts$/u);
    return record;
  }, (record) => record.className);
  uniqueStrings(manifest.initialDuplicateProviders, 'initial duplicate providers');
  uniqueStrings(manifest.remainingDuplicateProviders, 'remaining duplicate providers');
  uniqueStrings(manifest.initialPlatformDebts, 'initial platform debts');
  uniqueStrings(manifest.remainingPlatformDebts, 'remaining platform debts');
  uniqueStrings(manifest.remainingRetiredLegacyProviderEdges, 'remaining retired legacy provider edges');
  uniqueStrings(manifest.allowedChangedPaths, 'allowed changed paths');
  if (manifest.initialDuplicateProviders.join('|') !== EXACT_DUPLICATE_PROVIDERS.join('|')) throw new Error('initial duplicate provider ledger is invalid');
  if (manifest.initialPlatformDebts.join('|') !== EXACT_PLATFORM_DEBTS.join('|')) throw new Error('initial platform debt ledger is invalid');
  const retiredKeys = manifest.initialRetiredLegacyProviderEdges.map((edge) => {
    const record = exactObject(edge, ['key', 'retirementTask'], 'retired legacy provider edge');
    if (typeof record.key !== 'string' || record.key.length > MAX_TEXT_LENGTH
        || !/^[^|]+\|[^|]+$/u.test(record.key) || ![2, 3, 4, 5, 7].includes(record.retirementTask)) {
      throw new Error('retired legacy provider edge is invalid');
    }
    return record.key;
  });
  if (new Set(retiredKeys).size !== retiredKeys.length) throw new Error('retired ledger contains a duplicate');
  if (retiredKeys.join('|') !== [...retiredKeys].sort().join('|')
      || sha256(manifest.initialRetiredLegacyProviderEdges) !== INITIAL_RETIRED_LEDGER_HASH) {
    throw new Error('initial retired legacy provider ledger is not canonical or immutable');
  }
  const expectedDuplicates = EXACT_DUPLICATE_PROVIDERS.filter((item) => DUPLICATE_RETIREMENT_TASK[item] > completedTask);
  const expectedPlatform = EXACT_PLATFORM_DEBTS.filter((item) => PLATFORM_RETIREMENT_TASK[item] > completedTask);
  const expectedRetired = manifest.initialRetiredLegacyProviderEdges
    .filter((item) => item.retirementTask > completedTask).map((item) => item.key);
  if (manifest.remainingDuplicateProviders.join('|') !== expectedDuplicates.join('|')) {
    throw new Error('duplicate provider retirement is early, late, or unscheduled for task');
  }
  if (manifest.remainingPlatformDebts.join('|') !== expectedPlatform.join('|')) {
    throw new Error('platform debt retirement is early, late, or unscheduled for task');
  }
  if (manifest.remainingRetiredLegacyProviderEdges.join('|') !== expectedRetired.join('|')) {
    throw new Error('retired legacy provider removal is early, late, renamed, or unscheduled for task');
  }
  return manifest;
}

function createProgram(backendRoot) {
  const configPath = path.join(backendRoot, 'tsconfig.json');
  const config = ts.readConfigFile(configPath, ts.sys.readFile);
  if (config.error) throw new Error('backend tsconfig cannot be read');
  const parsed = ts.parseJsonConfigFileContent(config.config, ts.sys, backendRoot, undefined, configPath);
  if (parsed.errors.length || !parsed.fileNames.length) throw new Error('backend tsconfig cannot be parsed');
  const program = ts.createProgram(parsed.fileNames, parsed.options);
  if (program.getSyntacticDiagnostics().length) throw new Error('backend source has syntax errors');
  return { program, checker: program.getTypeChecker() };
}

function repoPath(file, repoRoot) {
  const relative = path.relative(repoRoot, file);
  if (!relative || path.isAbsolute(relative) || relative === '..' || relative.startsWith(`..${path.sep}`)) {
    throw new Error('source path is outside repository');
  }
  return relative.replace(/\\/g, '/');
}

function alias(symbol, checker) {
  let current = symbol;
  const seen = new Set();
  while (current && (current.flags & ts.SymbolFlags.Alias) && !seen.has(current)) {
    seen.add(current);
    current = checker.getAliasedSymbol(current);
  }
  return current;
}

function nestSymbol(expression, expected, checker) {
  const target = ts.isPropertyAccessExpression(expression) ? expression.name : expression;
  const symbol = alias(checker.getSymbolAtLocation(target), checker);
  return Boolean(symbol && symbol.getName() === expected && (symbol.declarations || []).some((item) => (
    item.getSourceFile().fileName.replace(/\\/g, '/').includes('/node_modules/@nestjs/common/')
  )));
}

function decorators(node) {
  return ts.canHaveDecorators(node) ? (ts.getDecorators(node) || []) : [];
}

function decoratorCall(node, expected, checker) {
  return decorators(node).map((item) => item.expression).find((expression) => (
    ts.isCallExpression(expression) && nestSymbol(expression.expression, expected, checker)
  )) || null;
}

function lineOf(sourceFile, node) {
  return sourceFile.getLineAndCharacterOfPosition(node.getStart(sourceFile)).line + 1;
}

function addDiagnostic(diagnostics, kind, repositoryPath, sourceFile, node, extra = {}) {
  diagnostics.push({ kind, path: repositoryPath, line: lineOf(sourceFile, node || sourceFile), ...extra });
}

function expressionSymbol(expression, checker) {
  if (!expression) return null;
  const target = ts.isPropertyAccessExpression(expression) ? expression.name : expression;
  return alias(checker.getSymbolAtLocation(target), checker);
}

function symbolRepositoryDeclaration(symbol, repoRoot) {
  if (!symbol) return null;
  for (const declaration of symbol.declarations || []) {
    try {
      const declarationPath = repoPath(declaration.getSourceFile().fileName, repoRoot);
      if (declarationPath.startsWith('backend/src/')) return { declaration, declarationPath };
    } catch {
      // External declarations do not have repository identities.
    }
  }
  return null;
}

function symbolIdentity(expression, checker, repoRoot) {
  const symbol = expressionSymbol(expression, checker);
  const resolved = symbolRepositoryDeclaration(symbol, repoRoot);
  if (!symbol || !resolved) return null;
  return { symbol, name: symbol.getName(), ...resolved, key: `${resolved.declarationPath}#${symbol.getName()}` };
}

function resolvedIdentityFromSymbol(input, checker) {
  const symbol = alias(input, checker);
  if (!symbol) return null;
  const declaration = (symbol.declarations || [])[0];
  if (!declaration) return null;
  const declarationPath = path.resolve(declaration.getSourceFile().fileName).replace(/\\/g, '/');
  return {
    symbol,
    name: symbol.getName(),
    declaration,
    declarationPath,
    key: `${declarationPath}#${symbol.getName()}`,
  };
}

function resolvedSymbolIdentity(expression, checker) {
  return resolvedIdentityFromSymbol(expressionSymbol(expression, checker), checker);
}

function moduleExpressionIdentity(expression, checker) {
  let target = expression;
  if (ts.isCallExpression(target)) target = target.expression;
  if (ts.isPropertyAccessExpression(target)) target = target.expression;
  return resolvedSymbolIdentity(target, checker);
}

function canonicalExternalContractIdentity(contract, program, checker, backendRoot) {
  const containingFile = path.join(backendRoot, 'src', '__r3-contract-resolution__.ts');
  const resolution = ts.resolveModuleName(
    contract.packageName, containingFile, program.getCompilerOptions(), ts.sys,
  ).resolvedModule;
  if (!resolution) return null;
  const resolvedPath = path.resolve(resolution.resolvedFileName);
  const sourceFile = program.getSourceFiles().find(
    (candidate) => path.resolve(candidate.fileName) === resolvedPath,
  );
  if (!sourceFile) return null;
  const moduleSymbol = checker.getSymbolAtLocation(sourceFile) || sourceFile.symbol;
  if (!moduleSymbol) return null;
  const exports = new Map(checker.getExportsOfModule(moduleSymbol).map((item) => [item.getName(), item]));
  const implementation = resolvedIdentityFromSymbol(exports.get(contract.implementation), checker);
  const module = resolvedIdentityFromSymbol(exports.get(contract.module), checker);
  return implementation && module ? { implementation, module } : null;
}

function isDeclaredSymbolToken(identity) {
  if (!identity || !ts.isVariableDeclaration(identity.declaration) || !identity.declaration.initializer) return false;
  const initializer = identity.declaration.initializer;
  return ts.isCallExpression(initializer)
    && ts.isIdentifier(initializer.expression)
    && initializer.expression.text === 'Symbol'
    && initializer.arguments.length === 1
    && ts.isStringLiteral(initializer.arguments[0])
    && initializer.arguments[0].text === identity.name;
}

function classify(repositoryPath) {
  const prefix = 'backend/src/';
  if (!repositoryPath.startsWith(prefix)) return { kind: 'external' };
  const segments = repositoryPath.slice(prefix.length).split('/');
  if (segments[0] === 'application-composition') return { kind: 'composition' };
  if (segments[0] === 'platform') return { kind: 'platform' };
  if (segments[0] === 'modules') {
    return CONTEXTS.includes(segments[1])
      ? { kind: 'future', context: segments[1], slice: segments[2] || 'full' }
      : { kind: 'unknown-context' };
  }
  const context = ROOT_TO_CONTEXT.get(segments[0]);
  return context ? { kind: 'legacy', context } : { kind: 'other' };
}

function resolvedImportPath(sourceFile, specifier, program, repoRoot) {
  const result = ts.resolveModuleName(
    specifier, sourceFile.fileName, program.getCompilerOptions(), ts.sys,
  ).resolvedModule;
  if (!result) return null;
  try { return repoPath(result.resolvedFileName.replace(/\.d\.ts$/u, '.ts'), repoRoot); } catch { return null; }
}

function isTypeOnlyImport(node) {
  if (!node.importClause) return false;
  if (node.importClause.isTypeOnly) return true;
  const bindings = node.importClause.namedBindings;
  return Boolean(bindings && ts.isNamedImports(bindings) && bindings.elements.length
    && bindings.elements.every((element) => element.isTypeOnly));
}

function propertyName(property) {
  if (!property.name) return null;
  if (ts.isIdentifier(property.name) || ts.isStringLiteral(property.name)) return property.name.text;
  return null;
}

function moduleMetadata(classNode, call, sourceFile, repositoryPath, diagnostics) {
  const argument = call.arguments[0];
  const metadata = { imports: [], providers: [], exports: [] };
  if (!argument || !ts.isObjectLiteralExpression(argument)) {
    addDiagnostic(diagnostics, 'unresolved-nest-metadata', repositoryPath, sourceFile, call);
    return metadata;
  }
  for (const property of argument.properties) {
    if (!ts.isPropertyAssignment(property) || !propertyName(property)) {
      addDiagnostic(diagnostics, 'unresolved-nest-metadata', repositoryPath, sourceFile, property);
      continue;
    }
    const name = propertyName(property);
    if (!['imports', 'providers', 'exports'].includes(name)) continue;
    if (!ts.isArrayLiteralExpression(property.initializer)) {
      addDiagnostic(diagnostics, 'unresolved-nest-metadata', repositoryPath, sourceFile, property.initializer);
      continue;
    }
    metadata[name] = [...property.initializer.elements];
  }
  return { classNode, ...metadata };
}

function scanR3SourceLaws(options) {
  const repoRoot = path.resolve(options.repoRoot);
  const backendRoot = path.resolve(options.backendRoot);
  const { program, checker } = createProgram(backendRoot);
  const diagnostics = [];
  const modules = [];
  const imports = [];
  const contractsByToken = new Map((options.providerContracts || []).map((contract) => [
    contract.token,
    new Set(contract.implementations),
  ]));
  const enforceManifestImplementations = options.providerContracts !== undefined;
  const classIdentitiesByName = new Map();
  const sourceFiles = program.getSourceFiles().filter((sourceFile) => {
    if (sourceFile.isDeclarationFile) return false;
    try { return repoPath(sourceFile.fileName, repoRoot).startsWith('backend/src/'); } catch { return false; }
  });
  for (const sourceFile of sourceFiles) {
    const repositoryPath = repoPath(sourceFile.fileName, repoRoot);
    const sourceClass = classify(repositoryPath);
    if (sourceClass.kind === 'unknown-context') {
      addDiagnostic(diagnostics, 'unknown-context', repositoryPath, sourceFile, sourceFile);
    }
    const visit = (node) => {
      if (ts.isCallExpression(node) && nestSymbol(node.expression, 'forwardRef', checker)) {
        addDiagnostic(diagnostics, 'forward-ref', repositoryPath, sourceFile, node);
      }
      ts.forEachChild(node, visit);
    };
    visit(sourceFile);
    for (const statement of sourceFile.statements) {
      if (ts.isImportDeclaration(statement) && ts.isStringLiteral(statement.moduleSpecifier)) {
        const targetPath = resolvedImportPath(sourceFile, statement.moduleSpecifier.text, program, repoRoot);
        if (!targetPath) continue;
        const targetClass = classify(targetPath);
        imports.push({ sourcePath: repositoryPath, targetPath, sourceClass, targetClass, node: statement, sourceFile });
        if ((sourceClass.kind === 'platform' || sourceClass.kind === 'legacy' || sourceClass.kind === 'future')
            && targetClass.kind === 'composition') {
          addDiagnostic(diagnostics, 'illegal-composition-import', repositoryPath, sourceFile, statement);
        }
        if (sourceClass.kind === 'composition'
            && !(targetClass.kind === 'platform'
              || (targetClass.kind === 'future' && targetClass.slice === 'public')
              || targetClass.kind === 'external')) {
          addDiagnostic(diagnostics, 'illegal-composition-import', repositoryPath, sourceFile, statement);
        }
        if (sourceClass.kind === 'future' && targetClass.context && sourceClass.context !== targetClass.context) {
          const legalType = sourceClass.slice === 'public' && targetClass.kind === 'future'
            && targetClass.slice === 'public' && isTypeOnlyImport(statement);
          if (!legalType) addDiagnostic(diagnostics, 'illegal-boundary-import', repositoryPath, sourceFile, statement);
        }
        if (sourceClass.kind === 'future' && sourceClass.slice === 'public' && targetClass.kind === 'legacy') {
          addDiagnostic(diagnostics, 'public-imports-concrete', repositoryPath, sourceFile, statement);
        }
      }
      if (ts.isClassDeclaration(statement) && statement.name) {
        const classIdentity = symbolIdentity(statement.name, checker, repoRoot);
        if (classIdentity) {
          const identities = classIdentitiesByName.get(classIdentity.name) || [];
          identities.push(classIdentity);
          classIdentitiesByName.set(classIdentity.name, identities);
        }
        const call = decoratorCall(statement, 'Module', checker);
        if (!call) continue;
        modules.push({
          className: statement.name.text,
          path: repositoryPath,
          sourceFile,
          ...moduleMetadata(statement, call, sourceFile, repositoryPath, diagnostics),
        });
      }
    }
  }
  const providers = new Map();
  const modulesByIdentity = new Map(modules.map((module) => {
    const identity = symbolIdentity(module.classNode.name, checker, repoRoot);
    return identity ? [identity.key, module] : [null, null];
  }).filter(([key]) => key !== null));
  for (const module of modules) {
    for (const provider of module.providers) {
      if (!(ts.isIdentifier(provider) || ts.isPropertyAccessExpression(provider))) continue;
      const identity = symbolIdentity(provider, checker, repoRoot);
      if (!identity) continue;
      const list = providers.get(identity.key) || [];
      list.push({ module, node: provider, identity });
      providers.set(identity.key, list);
    }
  }
  const publicContractBindings = new Map();
  for (const module of modules) {
    const moduleClass = classify(module.path);
    if (moduleClass.kind !== 'future' || moduleClass.slice !== 'public') continue;
    for (const provider of module.providers) {
      if (!ts.isObjectLiteralExpression(provider)) continue;
      const properties = new Map(provider.properties.filter(ts.isPropertyAssignment)
        .map((item) => [propertyName(item), item]));
      const provide = properties.get('provide');
      const identity = provide && symbolIdentity(provide.initializer, checker, repoRoot);
      if (!identity || !(contractsByToken.has(identity.name)
          || (!enforceManifestImplementations && identity.name.endsWith('_PORT')))) continue;
      const registrations = publicContractBindings.get(identity.name) || [];
      registrations.push({ module, provider, identity });
      publicContractBindings.set(identity.name, registrations);
    }
  }
  const internalModules = modules.filter((module) => {
    const moduleClass = classify(module.path);
    return moduleClass.kind === 'future' && moduleClass.slice === 'internal';
  });
  const externalContractIdentities = new Map([...EXTERNAL_PROVIDER_CONTRACTS].map(([token, contract]) => [
    token,
    canonicalExternalContractIdentity(contract, program, checker, backendRoot),
  ]));
  for (const module of modules) {
    if (!module.path.includes('/modules/') || !module.path.includes('/public/')) continue;
    const moduleClass = classify(module.path);
    const importedInternalModules = module.imports.map((expression) => symbolIdentity(expression, checker, repoRoot))
      .filter((identity) => identity && classify(identity.declarationPath).kind === 'future'
        && classify(identity.declarationPath).context === moduleClass.context
        && classify(identity.declarationPath).slice === 'internal');
    const importedInternalModuleSet = new Set(importedInternalModules
      .map((identity) => modulesByIdentity.get(identity.key)).filter(Boolean));
    const bindings = new Map();
    for (const provider of module.providers) {
      if (!ts.isObjectLiteralExpression(provider)) continue;
      const properties = new Map(provider.properties.filter(ts.isPropertyAssignment).map((item) => [propertyName(item), item]));
      const provide = properties.get('provide');
      if (!provide) continue;
      const publicToken = symbolIdentity(provide.initializer, checker, repoRoot);
      if (publicToken) bindings.set(publicToken.key, properties);
      if (!publicToken || publicToken.name.endsWith('_IMPLEMENTATION') || properties.has('useClass') || properties.has('useFactory')) {
        addDiagnostic(diagnostics, 'implementation-token-misuse', module.path, module.sourceFile, provider);
      }
      const manifestImplementations = publicToken && contractsByToken.get(publicToken.name);
      const isPublicContractToken = Boolean(publicToken && (
        manifestImplementations || (!enforceManifestImplementations && publicToken.name.endsWith('_PORT'))
      ));
      if (isPublicContractToken) {
        const useExisting = properties.get('useExisting');
        const implementationToken = useExisting && symbolIdentity(useExisting.initializer, checker, repoRoot);
        const implementationClass = implementationToken ? classify(implementationToken.declarationPath) : null;
        const publicClass = classify(publicToken.declarationPath);
        const expectedImplementation = publicToken.name.replace(/_PORT$/u, '_IMPLEMENTATION');
        const expectedImplementationIdentities = manifestImplementations
          ? [...manifestImplementations].flatMap((name) => classIdentitiesByName.get(name) || [])
            .filter((identity) => {
              const identityClass = classify(identity.declarationPath);
              return identityClass.kind === 'legacy' && identityClass.context === moduleClass.context;
            })
          : [];
        const ownerInternalModules = internalModules.filter(
          (internalModule) => classify(internalModule.path).context === moduleClass.context,
        );
        const pairedInternalModules = implementationToken ? ownerInternalModules.filter((internalModule) => {
          const exportsImplementation = internalModule.exports.filter((expression) => (
            symbolIdentity(expression, checker, repoRoot)?.key === implementationToken.key
          )).length === 1;
          const bindings = internalModule.providers.filter((candidate) => {
            if (!ts.isObjectLiteralExpression(candidate)) return false;
            const internalProperties = new Map(candidate.properties.filter(ts.isPropertyAssignment)
              .map((item) => [propertyName(item), item]));
            const provide = internalProperties.get('provide');
            return Boolean(provide
              && symbolIdentity(provide.initializer, checker, repoRoot)?.key === implementationToken.key);
          });
          if (bindings.length !== 1) return false;
          const internalProperties = new Map(bindings[0].properties.filter(ts.isPropertyAssignment)
            .map((item) => [propertyName(item), item]));
          if (internalProperties.has('useClass') || internalProperties.has('useFactory')) return false;
          const targetProperty = internalProperties.get('useExisting');
          const target = targetProperty && symbolIdentity(targetProperty.initializer, checker, repoRoot);
          if (!target) return false;
          const exactManifestTarget = !enforceManifestImplementations || Boolean(manifestImplementations
            && expectedImplementationIdentities.some((identity) => identity.key === target.key));
          const registrations = providers.get(target.key) || [];
          const registeredExactlyOnce = registrations.length === 1
            && registrations[0].module === internalModule;
          return exportsImplementation && exactManifestTarget && registeredExactlyOnce;
        }) : [];
        const publicTokenBindings = publicContractBindings.get(publicToken.name) || [];
        const publicBindingCount = publicTokenBindings.length;
        const publicBindingIdentityCount = new Set(
          publicTokenBindings.map((binding) => binding.identity.key),
        ).size;
        const publicBindingIdentityIsExact = publicBindingCount === 1
          && publicBindingIdentityCount === 1
          && publicTokenBindings[0].identity.key === publicToken.key;
        const manifestIdentityIsExact = !enforceManifestImplementations || Boolean(
          manifestImplementations && expectedImplementationIdentities.length === manifestImplementations.size,
        );
        const externalContract = EXTERNAL_PROVIDER_CONTRACTS.get(publicToken.name);
        let exactBinding = Boolean(implementationToken
          && implementationToken.name === expectedImplementation
          && implementationClass.kind === 'future' && implementationClass.slice === 'internal'
          && implementationClass.context === moduleClass.context && isDeclaredSymbolToken(implementationToken)
          && manifestIdentityIsExact && pairedInternalModules.length === 1
          && importedInternalModuleSet.has(pairedInternalModules[0]));
        if (externalContract) {
          const externalTarget = useExisting
            ? resolvedSymbolIdentity(useExisting.initializer, checker) : null;
          const canonicalExternal = externalContractIdentities.get(publicToken.name);
          const manifestExternalIsExact = Boolean(manifestImplementations
            && manifestImplementations.size === 1
            && manifestImplementations.has(externalContract.implementation));
          const pairedExternalModules = ownerInternalModules.filter((internalModule) => {
            const imports = internalModule.imports.map((expression) => moduleExpressionIdentity(expression, checker))
              .filter((identity) => canonicalExternal && identity.symbol === canonicalExternal.module.symbol);
            const exports = internalModule.exports.map((expression) => resolvedSymbolIdentity(expression, checker))
              .filter((identity) => canonicalExternal && identity.symbol === canonicalExternal.module.symbol);
            return imports.length === 1 && exports.length === 1;
          });
          exactBinding = Boolean(manifestExternalIsExact
            && canonicalExternal && externalTarget
            && externalTarget.symbol === canonicalExternal.implementation.symbol
            && pairedExternalModules.length === 1
            && importedInternalModuleSet.has(pairedExternalModules[0]));
        }
        if (!useExisting || !publicBindingIdentityIsExact
            || publicClass.kind !== 'future' || publicClass.slice !== 'public'
            || publicClass.context !== moduleClass.context || !isDeclaredSymbolToken(publicToken)
            || !exactBinding) {
          addDiagnostic(diagnostics, 'public-binding-not-use-existing', module.path, module.sourceFile, provider);
        }
      }
    }
    for (const exported of module.exports) {
      const identity = symbolIdentity(exported, checker, repoRoot);
      const isPublicContractToken = Boolean(identity && (
        contractsByToken.has(identity.name)
        || (!enforceManifestImplementations && identity.name.endsWith('_PORT'))
      ));
      if (identity && isPublicContractToken && isDeclaredSymbolToken(identity)
          && classify(identity.declarationPath).context === moduleClass.context
          && classify(identity.declarationPath).slice === 'public') {
        if (!bindings.has(identity.key)) addDiagnostic(diagnostics, 'hollow-public-token', module.path, module.sourceFile, exported);
      } else {
        addDiagnostic(diagnostics, 'concrete-public-export', module.path, module.sourceFile, exported);
      }
    }
  }
  for (const registrations of providers.values()) {
    if (registrations.length < 2) continue;
    for (const registration of registrations) {
      addDiagnostic(diagnostics, 'duplicate-provider', registration.module.path, registration.module.sourceFile, registration.node, {
        provider: registration.identity.name,
        declarationPath: registration.identity.declarationPath,
      });
    }
  }
  const moduleBySymbol = new Map(modules.map((item) => [item.className, item]));
  const graph = new Map(modules.map((item) => [item.className, item.imports.filter(ts.isIdentifier).map((node) => node.text).filter((name) => moduleBySymbol.has(name))]));
  const visiting = new Set();
  const visited = new Set();
  let cycleFound = false;
  function walk(name) {
    if (visiting.has(name)) { cycleFound = true; return; }
    if (visited.has(name)) return;
    visiting.add(name);
    for (const next of graph.get(name) || []) walk(next);
    visiting.delete(name); visited.add(name);
  }
  for (const name of graph.keys()) walk(name);
  if (cycleFound && modules.length) {
    addDiagnostic(diagnostics, 'nest-module-cycle', modules[0].path, modules[0].sourceFile, modules[0].classNode);
  }
  diagnostics.sort((left, right) => `${left.path}|${left.line}|${left.kind}`.localeCompare(`${right.path}|${right.line}|${right.kind}`));
  return { modules: modules.map(({ className, path: modulePath }) => ({ className, path: modulePath })), diagnostics };
}

const ROUTE_DECORATORS = new Map([
  ['Get', 'GET'], ['Post', 'POST'], ['Put', 'PUT'], ['Patch', 'PATCH'],
  ['Delete', 'DELETE'], ['Options', 'OPTIONS'], ['Head', 'HEAD'], ['All', 'ALL'],
]);
const GUARD_DECLARATIONS = new Map([
  ['JwtAuthGuard', 'backend/src/auth/jwt-auth.guard.ts'],
  ['JwtSessionGuard', 'backend/src/auth/jwt-session.guard.ts'],
  ['AdminGuard', 'backend/src/admin/admin.guard.ts'],
  ['AdminPermissionGuard', 'backend/src/admin/admin-permission.guard.ts'],
]);
const CUSTOM_DECORATOR_DECLARATIONS = new Map([
  ['CurrentUser', 'backend/src/auth/current-user.decorator.ts'],
  ['RequireAdminPermission', 'backend/src/admin/admin-permission.decorator.ts'],
]);

function staticDecoratorText(call) {
  if (!call || call.arguments.length === 0) return '';
  const value = call.arguments[0];
  return ts.isStringLiteralLike(value) || ts.isNoSubstitutionTemplateLiteral(value) ? value.text : null;
}

function routeForMethod(method, checker) {
  for (const [decoratorName, routeMethod] of ROUTE_DECORATORS) {
    const call = decoratorCall(method, decoratorName, checker);
    if (call) return { routeMethod, routePath: staticDecoratorText(call) };
  }
  return { routeMethod: null, routePath: null };
}

function namedDecoratorCall(node, expected, checker, repoRoot) {
  return decorators(node).map((item) => item.expression).find((expression) => {
    if (!ts.isCallExpression(expression)) return false;
    const identity = symbolIdentity(expression.expression, checker, repoRoot);
    return Boolean(identity && identity.name === expected
      && identity.declarationPath === CUSTOM_DECORATOR_DECLARATIONS.get(expected));
  }) || null;
}

function collectR3DecoratorInventory(options) {
  const repoRoot = path.resolve(options.repoRoot);
  const backendRoot = path.resolve(options.backendRoot);
  const supplied = options.program && options.checker
    ? { program: options.program, checker: options.checker }
    : createProgram(backendRoot);
  const { program, checker } = supplied;
  const groupedGuards = new Map();
  const groupedRuntime = new Map();
  const adminGuardMetadata = [];
  const sources = program.getSourceFiles().filter((sourceFile) => {
    if (sourceFile.isDeclarationFile) return false;
    try { return repoPath(sourceFile.fileName, repoRoot).startsWith('backend/src/'); } catch { return false; }
  }).sort((left, right) => repoPath(left.fileName, repoRoot).localeCompare(repoPath(right.fileName, repoRoot)));
  const addUse = (target, source, symbol, kind, use) => {
    const key = `${source}|${symbol}`;
    const record = target.get(key) || { source, symbol, kind, uses: [] };
    record.uses.push(use);
    target.set(key, record);
  };
  const useRecord = (controllerClass, method, routePrefix, routeMethod, routePath, parameterIndex = null) => ({
    controllerClass, method, routePrefix, routeMethod, routePath, parameterIndex,
  });
  for (const sourceFile of sources) {
    const source = repoPath(sourceFile.fileName, repoRoot);
    for (const statement of sourceFile.statements) {
      if (!ts.isClassDeclaration(statement) || !statement.name) continue;
      const controller = decoratorCall(statement, 'Controller', checker);
      if (!controller) continue;
      const controllerClass = statement.name.text;
      const routePrefix = staticDecoratorText(controller);
      if (routePrefix === null) throw new Error('controller route metadata is not statically resolvable');
      const collectGuards = (node, method, route) => {
        const call = decoratorCall(node, 'UseGuards', checker);
        if (!call) return [];
        const guardNames = [];
        for (const argument of call.arguments) {
          const identity = symbolIdentity(argument, checker, repoRoot);
          if (!identity) throw new Error('guard identity cannot be resolved');
          const exactGuard = GUARD_DECLARATIONS.get(identity.name) === identity.declarationPath;
          guardNames.push(exactGuard ? identity.name : `${identity.name}@${identity.declarationPath}`);
          if (exactGuard && ['JwtAuthGuard', 'JwtSessionGuard'].includes(identity.name)
              && source !== 'backend/src/auth/auth.controller.ts') {
            addUse(groupedGuards, source, identity.name, 'decorator-runtime', useRecord(
              controllerClass, method, routePrefix, route.routeMethod, route.routePath,
            ));
          }
        }
        return guardNames;
      };
      const classGuards = collectGuards(statement, null, { routeMethod: null, routePath: null });
      if (classGuards.includes('AdminPermissionGuard')) {
        adminGuardMetadata.push({ source, controllerClass, routePrefix, guards: classGuards });
      }
      const classPermission = namedDecoratorCall(statement, 'RequireAdminPermission', checker, repoRoot);
      if (classPermission) {
        addUse(groupedRuntime, source, 'RequireAdminPermission', 'runtime-decorator', useRecord(
          controllerClass, null, routePrefix, null, null,
        ));
      }
      for (const member of statement.members) {
        if (!ts.isMethodDeclaration(member) || !member.name) continue;
        const method = member.name.getText(sourceFile);
        const route = routeForMethod(member, checker);
        const methodGuards = collectGuards(member, method, route);
        if (methodGuards.includes('AdminPermissionGuard')) {
          throw new Error('Admin guard metadata must be controller-scoped');
        }
        if (namedDecoratorCall(member, 'RequireAdminPermission', checker, repoRoot)) {
          addUse(groupedRuntime, source, 'RequireAdminPermission', 'runtime-decorator', useRecord(
            controllerClass, method, routePrefix, route.routeMethod, route.routePath,
          ));
        }
        for (let parameterIndex = 0; parameterIndex < member.parameters.length; parameterIndex += 1) {
          const parameter = member.parameters[parameterIndex];
          if (namedDecoratorCall(parameter, 'CurrentUser', checker, repoRoot)
              && source !== 'backend/src/auth/auth.controller.ts') {
            addUse(groupedRuntime, source, 'CurrentUser', 'runtime-decorator', useRecord(
              controllerClass, method, routePrefix, route.routeMethod, route.routePath, parameterIndex,
            ));
          }
        }
      }
    }
  }
  const metadataSource = sources.find((sourceFile) => (
    repoPath(sourceFile.fileName, repoRoot) === 'backend/src/admin/admin-permission.guard.ts'
  ));
  if (metadataSource) {
    let metadataUsed = false;
    let className = 'AdminPermissionGuard';
    for (const statement of metadataSource.statements) {
      if (ts.isClassDeclaration(statement) && statement.name) className = statement.name.text;
    }
    const visit = (node) => {
      if (ts.isIdentifier(node) && node.text === 'ADMIN_PERMISSIONS_KEY') {
        const symbol = alias(checker.getSymbolAtLocation(node), checker);
        const resolved = symbolRepositoryDeclaration(symbol, repoRoot);
        if (symbol && symbol.getName() === 'ADMIN_PERMISSIONS_KEY' && resolved
            && resolved.declarationPath === 'backend/src/admin/admin-permission.decorator.ts'
            && !ts.isImportSpecifier(node.parent)) metadataUsed = true;
      }
      ts.forEachChild(node, visit);
    };
    visit(metadataSource);
    if (metadataUsed) {
      addUse(groupedRuntime, 'backend/src/admin/admin-permission.guard.ts', 'ADMIN_PERMISSIONS_KEY', 'runtime-value',
        useRecord(className, 'canActivate', null, null, null));
    }
  }
  const useKey = (use) => `${use.controllerClass}|${use.method}|${use.routeMethod}|${use.routePath}|${use.parameterIndex}`;
  const finalize = (map) => [...map.values()].map((record) => ({
    ...record,
    uses: record.uses.sort((left, right) => (useKey(left) < useKey(right) ? -1 : useKey(left) > useKey(right) ? 1 : 0)),
  })).sort((left, right) => {
    const leftKey = `${left.source}|${left.symbol}`;
    const rightKey = `${right.source}|${right.symbol}`;
    return leftKey < rightKey ? -1 : leftKey > rightKey ? 1 : 0;
  });
  adminGuardMetadata.sort((left, right) => {
    const leftKey = `${left.source}|${left.controllerClass}`;
    const rightKey = `${right.source}|${right.controllerClass}`;
    return leftKey < rightKey ? -1 : leftKey > rightKey ? 1 : 0;
  });
  return {
    decoratorRuntimeReferences: finalize(groupedGuards),
    runtimeDecoratorValueReferences: finalize(groupedRuntime),
    adminGuardMetadata,
  };
}

function metadataTexts(call, key, sourceFile) {
  const argument = call.arguments[0];
  if (!argument || !ts.isObjectLiteralExpression(argument)) return [];
  const property = argument.properties.find((item) => (
    ts.isPropertyAssignment(item) && propertyName(item) === key
  ));
  if (!property || !ts.isArrayLiteralExpression(property.initializer)) return [];
  return [...property.initializer.elements].map((item) => item.getText(sourceFile)).sort();
}

function collectLiveInventory(repoRoot, backendRoot, contractDefinitions, initialRetiredEdges) {
  const { program, checker } = createProgram(backendRoot);
  let globals = 0;
  const modules = [];
  const injections = [];
  const allConstructorUses = [];
  const importEdges = new Set();
  const sources = program.getSourceFiles().filter((sourceFile) => {
    if (sourceFile.isDeclarationFile) return false;
    try { return repoPath(sourceFile.fileName, repoRoot).startsWith('backend/src/'); } catch { return false; }
  }).sort((left, right) => repoPath(left.fileName, repoRoot).localeCompare(repoPath(right.fileName, repoRoot)));
  for (const sourceFile of sources) {
    const repositoryPath = repoPath(sourceFile.fileName, repoRoot);
    const first = repositoryPath.slice('backend/src/'.length).split('/')[0];
    const sourceContext = ROOT_TO_CONTEXT.get(first);
    for (const statement of sourceFile.statements) {
      if (ts.isImportDeclaration(statement) && ts.isStringLiteral(statement.moduleSpecifier)) {
        const targetPath = resolvedImportPath(sourceFile, statement.moduleSpecifier.text, program, repoRoot);
        if (targetPath) importEdges.add(`${repositoryPath}|${targetPath}`);
      }
    }
    const visit = (node) => {
      if (ts.isClassDeclaration(node) && node.name) {
        const call = decoratorCall(node, 'Module', checker);
        if (call) {
          const global = Boolean(decoratorCall(node, 'Global', checker));
          if (global) globals += 1;
          modules.push({
            path: repositoryPath,
            className: node.name.text,
            imports: metadataTexts(call, 'imports', sourceFile),
            providers: metadataTexts(call, 'providers', sourceFile),
            exports: metadataTexts(call, 'exports', sourceFile),
            global,
          });
        }
      }
      if (ts.isConstructorDeclaration(node)) {
        for (const parameter of node.parameters) {
          if (!parameter.type) continue;
          const expression = ts.isTypeReferenceNode(parameter.type) ? parameter.type.typeName : parameter.type;
          const symbol = alias(checker.getSymbolAtLocation(expression), checker);
          if (!symbol) continue;
          allConstructorUses.push({
            source: repositoryPath,
            parameter: parameter.name.getText(sourceFile),
            target: symbol.getName(),
          });
          if (!sourceContext) continue;
          const declaration = (symbol.declarations || []).find((item) => {
            try { return repoPath(item.getSourceFile().fileName, repoRoot).startsWith('backend/src/'); } catch { return false; }
          });
          if (!declaration) continue;
          const targetPath = repoPath(declaration.getSourceFile().fileName, repoRoot);
          const targetRoot = targetPath.slice('backend/src/'.length).split('/')[0];
          const targetContext = ROOT_TO_CONTEXT.get(targetRoot);
          if (targetContext && targetContext !== sourceContext) {
            injections.push({
              source: repositoryPath,
              parameter: parameter.name.getText(sourceFile),
              target: symbol.getName(),
              targetPath,
              sourceContext,
              targetContext,
              kind: 'constructor-injection',
            });
          }
        }
      }
      ts.forEachChild(node, visit);
    };
    visit(sourceFile);
  }
  modules.sort((left, right) => `${left.path}|${left.className}`.localeCompare(`${right.path}|${right.className}`));
  injections.sort((left, right) => `${left.source}|${left.parameter}|${left.target}`.localeCompare(`${right.source}|${right.parameter}|${right.target}`));
  const decoratorInventory = collectR3DecoratorInventory({ repoRoot, backendRoot, program, checker });
  const lifecycleNames = new Set([
    'AuthChallengeCleanupScheduler', 'ConversationsGateway', 'IdempotencyCleanupScheduler',
    'LoginThrottleCleanupScheduler', 'MediaUploadCleanupScheduler',
    'NotificationRemindersScheduler', 'OtpDispatchQuotaCleanupScheduler',
    'OutboxCleanupScheduler', 'OutboxDispatcher', 'OutboxWorker',
  ]);
  const lifecycleProviders = [];
  for (const sourceFile of sources) {
    for (const statement of sourceFile.statements) {
      if (ts.isClassDeclaration(statement) && statement.name && lifecycleNames.has(statement.name.text)) {
        lifecycleProviders.push({ className: statement.name.text, path: repoPath(sourceFile.fileName, repoRoot) });
      }
    }
  }
  lifecycleProviders.sort((left, right) => left.className.localeCompare(right.className));
  const moduleByName = new Map(modules.map((item) => [item.className, item]));
  const compositionDependencies = [];
  const authModule = moduleByName.get('AuthModule');
  const appModule = moduleByName.get('AppModule');
  if (authModule && appModule && authModule.exports.includes('JwtModule') && appModule.imports.includes('AuthModule')) {
    compositionDependencies.push(COMPOSITION_DEPENDENCIES[0]);
  }
  const compositionEdges = [
    ['backend/src/platform/health/readiness.service.ts|backend/src/media/media-storage.service.ts', COMPOSITION_DEPENDENCIES[1]],
    ['backend/src/platform/outbox/outbox.dispatcher.ts|backend/src/conversations/conversation-realtime.publisher.ts', COMPOSITION_DEPENDENCIES[2]],
    ['backend/src/platform/outbox/outbox.dispatcher.ts|backend/src/push/push-delivery.service.ts', COMPOSITION_DEPENDENCIES[3]],
    ['backend/src/platform/outbox/outbox.module.ts|backend/src/conversations/conversation-realtime.module.ts', COMPOSITION_DEPENDENCIES[4]],
    ['backend/src/platform/outbox/outbox.module.ts|backend/src/push/push.module.ts', COMPOSITION_DEPENDENCIES[5]],
  ];
  for (const [edge, record] of compositionEdges) if (importEdges.has(edge)) compositionDependencies.push(record);
  const declarationsByName = new Map();
  for (const sourceFile of program.getSourceFiles()) {
    for (const statement of sourceFile.statements) {
      if (ts.isClassDeclaration(statement) && statement.name) declarationsByName.set(statement.name.text, statement);
    }
  }
  const providerContracts = contractDefinitions.map((contract) => {
    const consumers = injections.filter((item) => contract.implementations.includes(item.target))
      .map((item) => ({ source: item.source, kind: 'constructor-injection' }));
    if (contract.token === 'IDENTITY_ACCESS_TOKEN_VERIFIER'
        && allConstructorUses.some((item) => item.source === 'backend/src/conversations/conversations.gateway.ts'
          && item.target === 'JwtService')) {
      consumers.push({ source: 'backend/src/conversations/conversations.gateway.ts', kind: 'constructor-injection' });
    }
    if (contract.token === 'PUSH_DELIVERY_PORT'
        && allConstructorUses.some((item) => item.source === 'backend/src/platform/outbox/outbox.dispatcher.ts'
          && item.target === 'PushDeliveryService')) {
      consumers.push({ source: 'backend/src/platform/outbox/outbox.dispatcher.ts', kind: 'constructor-injection' });
    }
    consumers.sort((left, right) => `${left.source}|${left.kind}`.localeCompare(`${right.source}|${right.kind}`));
    let surfacePresent = true;
    for (const implementation of contract.implementations) {
      let declaration = declarationsByName.get(implementation);
      if (!declaration) {
        for (const sourceFile of program.getSourceFiles()) {
          const symbol = checker.getSymbolAtLocation(sourceFile);
          if (!symbol) continue;
          const exported = checker.getExportsOfModule(symbol).find((item) => item.getName() === implementation);
          if (exported) declaration = (alias(exported, checker).declarations || []).find(ts.isClassDeclaration);
          if (declaration) break;
        }
      }
      if (!declaration) { surfacePresent = false; continue; }
      const type = checker.getTypeAtLocation(declaration);
      const properties = new Set(checker.getPropertiesOfType(type).map((item) => item.getName()));
      if (contract.methods.some((method) => !properties.has(method))) surfacePresent = false;
    }
    return { ...contract, consumers, surfacePresent };
  });
  const retiredEdges = initialRetiredEdges.filter((edge) => {
    const [from, to] = edge.key.split('|');
    return importEdges.has(`backend/${from}|backend/${to}`);
  });
  return {
    modules, globals, injections, compositionDependencies,
    providerContracts: providerContracts.map(({ surfacePresent, ...contract }) => contract),
    providerContractSurfacesPresent: providerContracts.every((item) => item.surfacePresent),
    ...decoratorInventory,
    lifecycleProviders, retiredEdges,
  };
}

function scanR3Contexts(options) {
  const manifest = validateR3ContextManifest(JSON.parse(fs.readFileSync(options.manifestPath, 'utf8')));
  if (options.stage !== manifest.stage) throw new Error('R3 stage does not match manifest');
  const contractDefinitions = manifest.providerContracts.map(({ token, methods, implementations }) => ({
    token, methods, implementations,
  }));
  const sourceLawScan = options.sourceLawScan || scanR3SourceLaws;
  const sourceLaws = sourceLawScan({
    repoRoot: options.repoRoot,
    backendRoot: options.backendRoot,
    providerContracts: contractDefinitions,
  });
  const duplicateDiagnostics = sourceLaws.diagnostics
    .filter((item) => item.kind === 'duplicate-provider' && typeof item.provider === 'string');
  const duplicateIdentities = new Set(duplicateDiagnostics
    .filter((item) => item.kind === 'duplicate-provider' && typeof item.provider === 'string')
    .map((item) => `${item.provider}|${item.declarationPath}`));
  const permittedDuplicates = new Set(manifest.remainingDuplicateProviders);
  const sourceDiagnostics = sourceLaws.diagnostics.filter((item) => {
    if (item.kind !== 'duplicate-provider') return true;
    return !(permittedDuplicates.has(item.provider)
      && APPROVED_DUPLICATE_IDENTITIES.get(item.provider) === item.declarationPath
      && APPROVED_DUPLICATE_REGISTRATIONS.get(item.provider)?.has(item.path));
  });
  const live = collectLiveInventory(
    options.repoRoot,
    options.backendRoot,
    contractDefinitions,
    manifest.initialRetiredLegacyProviderEdges,
  );
  const ports = scanPorts({ repoRoot: options.repoRoot, backendRoot: options.backendRoot });
  const exactRemainingDuplicates = manifest.remainingDuplicateProviders.every((provider) => {
    const registrations = duplicateDiagnostics.filter((item) => (
      item.provider === provider && item.declarationPath === APPROVED_DUPLICATE_IDENTITIES.get(provider)
    )).map((item) => item.path).sort();
    return JSON.stringify(registrations) === JSON.stringify([...APPROVED_DUPLICATE_REGISTRATIONS.get(provider)].sort());
  });
  const livePlatformDebts = live.compositionDependencies.map((item) => (
    item.key === 'app-jwt-module-availability' ? 'runtime-jwt-secret' : item.key
  ));
  const drift = JSON.stringify(live.modules) !== JSON.stringify(manifest.legacyModules)
    || JSON.stringify(live.injections) !== JSON.stringify(manifest.crossContextInjections)
    || JSON.stringify(livePlatformDebts) !== JSON.stringify(manifest.remainingPlatformDebts)
    || JSON.stringify(live.providerContracts) !== JSON.stringify(manifest.providerContracts)
    || !live.providerContractSurfacesPresent
    || JSON.stringify(live.decoratorRuntimeReferences) !== JSON.stringify(manifest.decoratorRuntimeReferences)
    || JSON.stringify(live.runtimeDecoratorValueReferences) !== JSON.stringify(manifest.runtimeDecoratorValueReferences)
    || JSON.stringify(live.lifecycleProviders) !== JSON.stringify(manifest.lifecycleProviders)
    || JSON.stringify(live.retiredEdges.map((item) => item.key)) !== JSON.stringify(manifest.remainingRetiredLegacyProviderEdges)
    || JSON.stringify(live.adminGuardMetadata) !== JSON.stringify(manifest.adminGuardMetadata)
    || live.globals !== 2
    || !exactRemainingDuplicates;
  const diagnostics = [...sourceDiagnostics];
  if (drift) diagnostics.push({ kind: 'inventory-drift', path: 'backend/src/app.module.ts', line: 1 });
  if (ports.diagnostics.length) diagnostics.push({ kind: 'inventory-drift', path: 'backend/src/app.module.ts', line: 1 });
  return validateR3ScanResult({
    diagnostics,
    counts: {
      contexts: Object.keys(ROOTS).length,
      legacyModules: live.modules.length,
      crossContextInjections: live.injections.length,
      compositionDependencies: live.compositionDependencies.length,
      initialDuplicateProviders: manifest.initialDuplicateProviders.length,
      remainingDuplicateProviders: duplicateIdentities.size,
      initialPlatformDebts: manifest.initialPlatformDebts.length,
      remainingPlatformDebts: live.compositionDependencies.length,
      initialRetiredLegacyProviderEdges: manifest.initialRetiredLegacyProviderEdges.length,
      remainingRetiredLegacyProviderEdges: live.retiredEdges.length,
      forwardRef: ports.counts.forwardRef,
      globals: ports.counts.globals,
      nestModuleCycles: ports.counts.nestModuleCycles,
      illegalEdges: ports.counts.illegalFutureImports,
    },
  });
}

function validateR3ScanResult(value) {
  assertDeepPlainData(value, 'R3 scan result');
  const result = plainObject(value, 'R3 scan result');
  if (Object.keys(result).sort().join('|') !== 'counts|diagnostics') throw new Error('R3 scan result keys are invalid');
  const diagnostics = denseArray(result.diagnostics, 'R3 diagnostics').map((item) => {
    const record = plainObject(item, 'R3 diagnostic');
    if (!DIAGNOSTIC_KINDS.has(record.kind) || typeof record.path !== 'string'
        || !record.path.startsWith('backend/') || !Number.isSafeInteger(record.line) || record.line < 1) {
      throw new Error('R3 diagnostic is invalid');
    }
    return { kind: record.kind, path: record.path, line: record.line };
  });
  const counts = plainObject(result.counts, 'R3 counts');
  if (Object.keys(counts).sort().join('|') !== [...COUNT_KEYS].sort().join('|')) throw new Error('R3 count keys are invalid');
  for (const key of COUNT_KEYS) if (!Number.isSafeInteger(counts[key]) || counts[key] < 0) throw new Error('R3 count is invalid');
  return { diagnostics, counts };
}

function runCli(dependencies = {}) {
  const argv = dependencies.argv || process.argv.slice(2);
  const stdout = dependencies.stdout || ((message) => process.stdout.write(`${message}\n`));
  const stderr = dependencies.stderr || ((message) => process.stderr.write(`${message}\n`));
  try {
    if (argv.length !== 3 || argv[0] !== '--check' || argv[1] !== '--stage' || argv[2] !== 'inventory') {
      throw new Error('invalid arguments');
    }
    const backendRoot = path.resolve(__dirname, '../..');
    const repoRoot = path.resolve(backendRoot, '..');
    const scan = dependencies.scan || (() => scanR3Contexts({
      repoRoot, backendRoot,
      manifestPath: path.join(backendRoot, 'architecture', 'r3-context-boundaries.json'),
      stage: argv[2],
    }));
    const result = validateR3ScanResult(scan());
    if (result.diagnostics.length) return 1;
    stdout(`PASS - R3 contexts: contexts=${result.counts.contexts}, duplicates=${result.counts.remainingDuplicateProviders}/${result.counts.initialDuplicateProviders}, platform debts=${result.counts.remainingPlatformDebts}/${result.counts.initialPlatformDebts}, retired edges=${result.counts.remainingRetiredLegacyProviderEdges}/${result.counts.initialRetiredLegacyProviderEdges}, forwardRef=${result.counts.forwardRef}, globals=${result.counts.globals}, cycles=${result.counts.nestModuleCycles}, illegal=${result.counts.illegalEdges}`);
    return 0;
  } catch {
    stderr('ERROR - R3 context scan failed');
    return 2;
  }
}

module.exports = {
  collectR3DecoratorInventory,
  scanR3Contexts,
  scanR3SourceLaws,
  validateR3ContextManifest,
  validateR3ScanResult,
  runCli,
};
if (require.main === module) process.exitCode = runCli();
