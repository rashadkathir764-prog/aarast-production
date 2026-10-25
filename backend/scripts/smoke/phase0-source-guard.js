#!/usr/bin/env node
'use strict';

const { existsSync, readFileSync, readdirSync } = require('fs');
const { join, resolve } = require('path');
const ts = require('typescript');
const backendTestRunner = require('../run-tests-with-artifact-guard');

const backendRoot = resolve(__dirname, '..', '..');
const repositoryRoot = resolve(backendRoot, '..');
const managedRunner = 'scripts/smoke/run-isolated-smoke.js';
const externalOpenwaCommand = 'node scripts/smoke/openwa-otp-smoke.js';
const guardedBackendTestRunner =
  'node scripts/run-tests-with-artifact-guard.js';
const sourceExtensions = new Set(['.js', '.ts', '.mjs', '.cjs']);
const allowedDirectDatabaseClients = new Map([
  'admin-web/scripts/admin-runtime-smoke.mjs',
  'backend/scripts/smoke/account-deletion-smoke.ts',
  'backend/scripts/smoke/backend-completion-smoke.js',
  'backend/scripts/smoke/booking-smoke.ts',
  'backend/scripts/smoke/guest-rsvp-smoke.ts',
  'backend/scripts/smoke/provider-claim-smoke.ts',
  'backend/scripts/smoke/provider-lifecycle-smoke.ts',
  'backend/scripts/smoke/quote-offer-lifecycle-smoke.ts',
  'backend/scripts/smoke/featured-placement-smoke.ts',
  'backend/scripts/smoke/cost-receipts-smoke.js',
  'backend/scripts/smoke/contributor-history-migration-smoke.js',
  'backend/scripts/smoke/conversation-unification-smoke.js',
  'backend/scripts/smoke/guest-phone-migration-smoke.js',
  'backend/scripts/smoke/marketplace-smoke.js',
  'backend/scripts/smoke/notifications-apis-smoke.js',
  'backend/scripts/smoke/phase0-fixtures-smoke.js',
  'backend/scripts/smoke/phase1-identity-smoke.ts',
  'backend/scripts/smoke/phase2-admin-mutation-authorization-smoke.ts',
  'backend/scripts/smoke/phase2-auth-lifecycle-concurrency-smoke.ts',
  'backend/scripts/smoke/phase2-auth-retention-smoke.ts',
  'backend/scripts/smoke/phase2-conversation-revocation-smoke.ts',
  'backend/scripts/smoke/phase2-idempotency-reconciliation-smoke.ts',
  'backend/scripts/smoke/phase2-marketplace-write-concurrency-smoke.ts',
  'backend/scripts/smoke/phase2-media-verification-lifecycle-smoke.ts',
  'backend/scripts/smoke/phase2-money-authorization-concurrency-smoke.ts',
  'backend/scripts/smoke/phase2-notification-authorization-concurrency-smoke.ts',
  'backend/scripts/smoke/phase2-notification-preferences-smoke.ts',
  'backend/scripts/smoke/phase2-plan-permission-concurrency-smoke.ts',
  'backend/scripts/smoke/phase2-provider-dashboard-concurrency-smoke.ts',
  'backend/scripts/smoke/phase2-provider-rating-concurrency-smoke.ts',
  'backend/scripts/smoke/phase2-quote-concurrency-smoke.ts',
  'backend/scripts/smoke/phase2-sharing-permission-concurrency-smoke.ts',
  'backend/scripts/smoke/phase2-task-guest-permission-concurrency-smoke.ts',
  'backend/scripts/smoke/phase3-context-transition-smoke.ts',
  'backend/scripts/smoke/private-chat-media-smoke.js',
  'backend/scripts/smoke/provider-dashboard-smoke.js',
  'backend/scripts/smoke/providers-quotes-smoke.js',
  'backend/scripts/smoke/quote-stability-smoke.js',
  'backend/scripts/smoke/sharing-security-smoke.js',
  'backend/scripts/smoke/ux-c4-c7-smoke.js',
].map((label) => [label, new Set(['@prisma/client'])]));
const exactEnvironmentInfrastructure = new Set([
  'backend/scripts/smoke/smoke-utils.js',
]);
const exactEnvironmentSpreadInfrastructure = new Set([
  'backend/scripts/smoke/all-smoke.js',
  'backend/scripts/smoke/run-isolated-smoke.js',
]);
const allowedEnvironmentMutationKeys = new Map([
  ['backend/scripts/smoke/account-deletion-smoke.ts', new Set([
    'AARAST_MEDIA_ENDPOINT',
    'AARAST_MEDIA_SIGNED_ENDPOINT',
    'AARAST_MEDIA_BUCKET',
    'AARAST_MEDIA_PUBLIC_BASE_URL',
    'AARAST_MEDIA_REGION',
    'AARAST_MEDIA_FORCE_PATH_STYLE',
    'AARAST_MEDIA_ACCESS_KEY_ID',
    'AARAST_MEDIA_SECRET_ACCESS_KEY',
  ])],
]);
const environmentMutatorCapabilities = new Set([
  'Object.assign',
  'Object.defineProperty',
  'Reflect.set',
  'Reflect.defineProperty',
]);

const managedCommandArguments = new Map([
  ['smoke', 'health-smoke.js auth-smoke.js'],
  ['smoke:health', 'health-smoke.js'],
  ['smoke:auth', 'auth-smoke.js'],
  ['smoke:auth-verification', 'auth-verification-smoke.js'],
  ['smoke:wedding-plan', 'wedding-plan-smoke.js'],
  ['smoke:onboarding-active-plan', 'onboarding-active-plan-smoke.js'],
  ['smoke:dashboard-summary', 'dashboard-summary-smoke.js'],
  ['smoke:money-apis', 'money-apis-smoke.js'],
  ['smoke:financial-ledger-concurrency', 'financial-ledger-concurrency-smoke.js'],
  ['smoke:money-budget', 'money-budget-smoke.js'],
  ['smoke:money-routes', 'money-route-contract-smoke.js'],
  ['smoke:tasks-apis', 'tasks-apis-smoke.js'],
  ['smoke:task-timeline', 'task-timeline-smoke.js'],
  ['smoke:sharing', 'sharing-smoke.js'],
  ['smoke:sharing-roles', 'sharing-roles-smoke.js'],
  ['smoke:sharing-security', 'sharing-security-smoke.js'],
  ['smoke:notifications', 'notifications-smoke.js'],
  ['smoke:notifications-apis', 'notifications-apis-smoke.js'],
  ['smoke:guests', 'guests-smoke.js'],
  ['smoke:guests-apis', 'guests-apis-smoke.js'],
  ['smoke:otp-profile', 'otp-profile-smoke.js'],
  ['smoke:marketplace', 'marketplace-smoke.js'],
  ['smoke:reference-catalog', 'reference-catalog-smoke.js'],
  ['smoke:providers-quotes', 'providers-quotes-smoke.js'],
  ['smoke:quote-stability', 'quote-stability-smoke.js'],
  ['smoke:conversation-unification', 'conversation-unification-smoke.js'],
  ['smoke:private-chat-media', 'private-chat-media-smoke.js'],
  ['smoke:provider-dashboard', 'provider-dashboard-smoke.js'],
  ['smoke:ux-backend-support', 'ux-backend-support-smoke.js'],
  ['smoke:ux-c4-c7', 'ux-c4-c7-smoke.js'],
  ['smoke:backend-completion', 'backend-completion-smoke.js'],
  ['smoke:account-deletion', 'account-deletion-smoke.ts'],
  ['smoke:booking', 'booking-smoke.ts'],
  ['smoke:guest-rsvp', 'guest-rsvp-smoke.ts'],
  ['smoke:provider-claim', 'provider-claim-smoke.ts'],
  ['smoke:provider-lifecycle', 'provider-lifecycle-smoke.ts'],
  ['smoke:quote-offer-lifecycle', 'quote-offer-lifecycle-smoke.ts'],
  ['smoke:featured-placement', 'featured-placement-smoke.ts'],
  ['smoke:cost-receipts', 'cost-receipts-smoke.js'],
  ['smoke:phone-change', 'phone-change-smoke.js'],
  ['smoke:task-shift', 'task-shift-smoke.js'],
  ['smoke:plan-partner', 'plan-partner-smoke.js'],
  ['smoke:assistant', 'assistant-smoke.js'],
  ['smoke:contributor-history-migration', '--contributor-history-migration'],
  ['smoke:guest-phone-migration', '--guest-phone-migration'],
  ['smoke:schema-equivalence', '--schema-equivalence'],
  ['smoke:phase0-fixtures', 'phase0-fixtures-smoke.js'],
  ['smoke:phase1-identity', 'phase1-identity-smoke.ts'],
  ['smoke:phase2-admin-mutation-authorization', 'phase2-admin-mutation-authorization-smoke.ts'],
  ['smoke:phase2-auth-lifecycle-concurrency', 'phase2-auth-lifecycle-concurrency-smoke.ts'],
  ['smoke:phase2-auth-retention', 'phase2-auth-retention-smoke.ts'],
  ['smoke:phase2-idempotency-reconciliation', 'phase2-idempotency-reconciliation-smoke.ts'],
  ['smoke:phase2-marketplace-write-concurrency', 'phase2-marketplace-write-concurrency-smoke.ts'],
  ['smoke:phase2-media-verification-lifecycle', 'phase2-media-verification-lifecycle-smoke.ts'],
  ['smoke:phase2-money-authorization-concurrency', 'phase2-money-authorization-concurrency-smoke.ts'],
  ['smoke:phase2-notification-authorization-concurrency', 'phase2-notification-authorization-concurrency-smoke.ts'],
  ['smoke:phase2-notification-preferences', 'phase2-notification-preferences-smoke.ts'],
  ['smoke:phase2-plan-permission-concurrency', 'phase2-plan-permission-concurrency-smoke.ts'],
  ['smoke:phase2-provider-dashboard-concurrency', 'phase2-provider-dashboard-concurrency-smoke.ts'],
  ['smoke:phase2-provider-rating-concurrency', 'phase2-provider-rating-concurrency-smoke.ts'],
  ['smoke:phase2-conversation-revocation', 'phase2-conversation-revocation-smoke.ts'],
  ['smoke:phase2-quote-concurrency', 'phase2-quote-concurrency-smoke.ts'],
  ['smoke:phase2-sharing-permission-concurrency', 'phase2-sharing-permission-concurrency-smoke.ts'],
  ['smoke:phase2-task-guest-permission-concurrency', 'phase2-task-guest-permission-concurrency-smoke.ts'],
  ['smoke:phase3-context-transition', 'phase3-context-transition-smoke.ts'],
  ['smoke:all', 'all-smoke.js'],
  ['load:test', '--load-test'],
]);

function readJson(filePath) {
  return JSON.parse(readFileSync(filePath, 'utf8'));
}

function expectedManagedCommand(name) {
  const argumentsText = managedCommandArguments.get(name);
  return argumentsText ? `node ${managedRunner} ${argumentsText}` : null;
}

function assertOfficialMutatingScriptsUseManagedRunner(scripts) {
  for (const [name, command] of Object.entries(scripts)) {
    if (name === 'smoke:openwa-otp') continue;
    if (!(name === 'smoke' || name.startsWith('smoke:') || name === 'load:test')) continue;
    const expected = expectedManagedCommand(name);
    if (!expected || command !== expected) {
      throw new Error(`${name} must use the exact managed command without a prefix, suffix, pipeline, or extra argument.`);
    }
  }
}

function assertBackendTestRunnerContract(scripts) {
  if (scripts.pretest !== 'node scripts/smoke/phase0-source-guard.js') {
    throw new Error('Backend pretest must run the source guard exactly once.');
  }
  if (Object.hasOwn(scripts, 'posttest')) {
    throw new Error(
      'Backend artifact cleanliness must run inside the guarded test process, not as a Git-dirty posttest.',
    );
  }

  if (scripts.test !== guardedBackendTestRunner) {
    throw new Error(
      'Backend tests must use the exact protected-artifact runner command without test file arguments.',
    );
  }

  const repositoryTests = readdirSync(join(backendRoot, 'test'), {
    withFileTypes: true,
  })
    .filter((entry) => entry.isFile() && entry.name.endsWith('.test.ts'))
    .map((entry) => `test/${entry.name}`)
    .sort();
  assertBackendTestBatches(
    backendTestRunner.buildTestBatches(),
    repositoryTests,
  );
}

function assertBackendTestBatches(testBatches, repositoryTests) {
  if (
    !Array.isArray(testBatches) ||
    testBatches.length !== 2 ||
    testBatches.some((batch) => !Array.isArray(batch))
  ) {
    throw new Error(
      'Backend tests must preserve one preflight batch and one main batch.',
    );
  }

  const [preflight, main] = testBatches;
  const expectedPreflight = [
    'test/legacy-finance-removal.test.ts',
    'test/canonical-api-routes.test.ts',
    'test/admin-app-identity.test.ts',
    'test/invite-delivery.test.ts',
    'test/phase0-guards.test.ts',
  ];
  if (
    preflight.length !== expectedPreflight.length ||
    preflight.some((file, index) => file !== expectedPreflight[index])
  ) {
    throw new Error('Backend test preflight files or ordering changed.');
  }

  const testFiles = [...preflight, ...main];
  if (main.length === 0) {
    throw new Error('Backend main test batch must not be empty.');
  }
  if (new Set(testFiles).size !== testFiles.length) {
    throw new Error('Backend guarded test batches contain a duplicate test file.');
  }

  const configuredTests = [...testFiles].sort();
  const expectedTests = [...repositoryTests].sort();
  if (
    expectedTests.length !== configuredTests.length ||
    expectedTests.some((file, index) => file !== configuredTests[index])
  ) {
    throw new Error(
      'Backend guarded test command must include every top-level test file exactly once.',
    );
  }
}

function assertNoUnsafeDatabaseTargets(source, label) {
  if (/\b(?:prisma\s+)?migrate\s+reset\b|\bprisma\s+db\s+push\b/i.test(source)) {
    throw new Error(`${label} contains a destructive Prisma command.`);
  }

  const sourceFile = parseSource(source);
  assertNoUnresolvedPostgresExpression(sourceFile, label);
  for (const databaseUrl of extractPostgresUrls(source)) {
    let parsed;
    try {
      parsed = new URL(databaseUrl);
    } catch {
      continue;
    }
    const databaseName = decodeURIComponent(parsed.pathname).replace(/^\/+|\/+$/g, '');
    if (databaseName === 'aarast' || databaseName === 'aarast_dev') {
      throw new Error(`${label} contains a permanent Aarast database target.`);
    }
  }

}

function extractPostgresUrls(source) {
  const sourceFile = parseSource(source);
  const staticStrings = new Set();
  const visit = (node) => {
    const value = evaluateStaticString(node);
    if (value !== undefined) staticStrings.add(value);
    ts.forEachChild(node, visit);
  };
  visit(sourceFile);

  const urls = new Set();
  for (const value of staticStrings) {
    for (const match of value.matchAll(/(?:^|[^A-Za-z0-9_:\/])((?:postgres|postgresql):\/\/[^\s'"`\\]+)/gi)) {
      urls.add(match[1]);
    }
  }
  for (const match of source.matchAll(/(?:^|[^A-Za-z0-9_:\/])((?:postgres|postgresql):\/\/[^\s'"`\\]+)/gi)) {
    urls.add(match[1]);
  }
  return [...urls];
}

function parseSource(source) {
  return ts.createSourceFile('phase0-guard.ts', source, ts.ScriptTarget.Latest, true, ts.ScriptKind.TSX);
}

function unwrapExpression(node) {
  while (
    ts.isParenthesizedExpression(node) ||
    ts.isAsExpression(node) ||
    ts.isTypeAssertionExpression(node) ||
    ts.isNonNullExpression(node) ||
    (typeof ts.isSatisfiesExpression === 'function' && ts.isSatisfiesExpression(node))
  ) {
    node = node.expression;
  }
  return node;
}

function evaluateStaticString(node) {
  node = unwrapExpression(node);
  if (ts.isStringLiteralLike(node) || ts.isNoSubstitutionTemplateLiteral(node)) return node.text;
  if (ts.isTemplateExpression(node) && node.templateSpans.length === 0) return node.head.text;
  if (ts.isBinaryExpression(node) && node.operatorToken.kind === ts.SyntaxKind.PlusToken) {
    const left = evaluateStaticString(node.left);
    const right = evaluateStaticString(node.right);
    return left === undefined || right === undefined ? undefined : left + right;
  }
  return undefined;
}

function assertNoUnresolvedPostgresExpression(sourceFile, label) {
  const visit = (node) => {
    const expression = unwrapExpression(node);
    const dynamicTemplate = ts.isTemplateExpression(expression) && expression.templateSpans.length > 0;
    const dynamicBinary = ts.isBinaryExpression(expression) && expression.operatorToken.kind === ts.SyntaxKind.PlusToken;
    if (
      (dynamicTemplate || dynamicBinary) &&
      (containsPostgresScheme(expression) || containsPermanentDatabaseFragment(expression)) &&
      evaluateStaticString(expression) === undefined
    ) {
      throw new Error(`${label} contains an unresolved PostgreSQL expression.`);
    }
    ts.forEachChild(node, visit);
  };
  visit(sourceFile);
}

function containsPostgresScheme(node) {
  node = unwrapExpression(node);
  if (ts.isTemplateExpression(node) && /(?:postgres|postgresql):\/\//i.test(node.head.text)) return true;
  const value = evaluateStaticString(node);
  if (value !== undefined && /(?:postgres|postgresql):\/\//i.test(value)) return true;
  let found = false;
  const visit = (child) => {
    if (found) return;
    const childValue = evaluateStaticString(child);
    if (childValue !== undefined && /(?:postgres|postgresql):\/\//i.test(childValue)) {
      found = true;
      return;
    }
    ts.forEachChild(child, visit);
  };
  visit(node);
  return found;
}

function containsPermanentDatabaseFragment(node) {
  const value = evaluateStaticString(node);
  if (value !== undefined && /\/(?:aarast|%61arast)(?:_dev|%5fdev)?(?:$|[?/'"`])/i.test(value)) return true;
  let found = false;
  const visit = (child) => {
    if (found) return;
    const childValue = evaluateStaticString(child);
    if (childValue !== undefined && /\/(?:aarast|%61arast)(?:_dev|%5fdev)?(?:$|[?/'"`])/i.test(childValue)) {
      found = true;
      return;
    }
    ts.forEachChild(child, visit);
  };
  visit(node);
  return found;
}

function assertEntrypointDatabaseContract(source, label) {
  const sourceFile = parseSource(source);
  const normalizedLabel = label.replace(/\\/g, '/');
  const hasPrismaBinding = assertStaticDatabaseImportGrammar(sourceFile, normalizedLabel);
  const hasEnvironmentValidatorBinding = hasExactEnvironmentValidatorBinding(
    sourceFile,
    normalizedLabel,
  );
  const visit = (node) => {
    assertLoaderIdentifierUsage(node, normalizedLabel);
    assertPrismaClientIdentifierUsage(node, normalizedLabel);
    assertEnvironmentValidatorIdentifierUsage(
      node,
      normalizedLabel,
      hasEnvironmentValidatorBinding,
    );
    assertProcessCapabilityUsage(
      node,
      normalizedLabel,
      hasEnvironmentValidatorBinding,
    );
    assertEnvironmentMutatorCapabilityUsage(node, normalizedLabel);
    assertNoProcessAlias(node, normalizedLabel);
    assertNoPrismaAlias(node, normalizedLabel);
    assertNoEnvironmentMutation(node, normalizedLabel);
    if (ts.isNewExpression(node) && ts.isIdentifier(node.expression) && node.expression.text === 'PrismaClient') {
      if (!hasPrismaBinding) {
        throw new Error(`${normalizedLabel} creates an independent database client.`);
      }
      if (node.arguments?.length) {
        throw new Error(`${normalizedLabel} gives an allowed database client unapproved constructor arguments.`);
      }
    }
    if (isReflectConstructOfPrismaClient(node)) {
      throw new Error(`${normalizedLabel} must use new PrismaClient() without Reflect.construct.`);
    }
    if (ts.isPropertyAssignment(node) && /^(?:datasourceUrl|datasources)$/.test(staticPropertyName(node.name) ?? '')) {
      throw new Error(`${normalizedLabel} contains a datasource override.`);
    }
    ts.forEachChild(node, visit);
  };
  visit(sourceFile);
}

function assertStaticDatabaseImportGrammar(sourceFile, label) {
  const allowedClientModules = allowedDirectDatabaseClients.get(label) ?? new Set();
  let hasPrismaBinding = false;
  const visit = (node) => {
    if (ts.isImportEqualsDeclaration(node) && ts.isExternalModuleReference(node.moduleReference)) {
      const moduleName = staticModuleName(node.moduleReference.expression);
      if (moduleName && (isDatabaseModule(moduleName) || isProcessModule(moduleName))) {
        throw new Error(`${label} imports an independent database client outside managed smoke infrastructure.`);
      }
    }
    if (ts.isImportDeclaration(node)) {
      const moduleName = staticModuleName(node.moduleSpecifier);
      if (moduleName && isProcessModule(moduleName)) {
        throw new Error(`${label} imports the process module outside the narrow environment grammar.`);
      }
      if (moduleName && isModuleLoaderModule(moduleName)) {
        if (label !== 'admin-web/scripts/admin-runtime-smoke.mjs' || !isExactCreateRequireImport(node)) {
          throw new Error(`${label} imports a module loader outside the static database-client grammar.`);
        }
      }
      if (moduleName && isDatabaseModule(moduleName)) {
        if (!allowedClientModules.has(moduleName) || !isExactPrismaImport(node)) {
          throw new Error(`${label} imports an independent database client outside managed smoke infrastructure.`);
        }
        hasPrismaBinding = true;
      }
    }
    if (ts.isCallExpression(node)) {
      if (node.expression.kind === ts.SyntaxKind.ImportKeyword) {
        throw new Error(`${label} uses a dynamic import outside the static database-client grammar.`);
      }
      if (isModuleRequireCall(node)) {
        throw new Error(`${label} imports an independent database client outside managed smoke infrastructure.`);
      }
      if (isRequireAliasDeclaration(node)) {
        throw new Error(`${label} aliases require outside the static database-client grammar.`);
      }
      const importer = staticImporterName(node, label);
      if (importer) {
        if (node.arguments.length !== 1) {
          throw new Error(`${label} uses an invalid require outside the static database-client grammar.`);
        }
        const moduleName = staticModuleName(node.arguments[0]);
        if (moduleName === undefined) {
          if (importer === 'require' && isAllowedDynamicRequire(node, label)) {
            ts.forEachChild(node, visit);
            return;
          }
          throw new Error(`${label} uses a dynamic require outside the static database-client grammar.`);
        }
        if (isProcessModule(moduleName)) {
          throw new Error(`${label} imports the process module outside the narrow environment grammar.`);
        }
        if (isModuleLoaderModule(moduleName)) {
          throw new Error(`${label} imports a module loader outside the static database-client grammar.`);
        }
        if (moduleName && isDatabaseModule(moduleName)) {
          if (!allowedClientModules.has(moduleName) || !isExactPrismaRequire(node)) {
            throw new Error(`${label} imports an independent database client outside managed smoke infrastructure.`);
          }
          hasPrismaBinding = true;
        }
      }
    }
    ts.forEachChild(node, visit);
  };
  visit(sourceFile);
  return hasPrismaBinding;
}

function staticModuleName(node) {
  const value = evaluateStaticString(node);
  return typeof value === 'string' ? value : undefined;
}

function isDatabaseModule(moduleName) {
  return moduleName === '@prisma/client' || moduleName === 'pg' || moduleName === 'postgres' ||
    moduleName.startsWith('@prisma/adapter-') || moduleName.startsWith('@prisma/driver-adapter-');
}

function isProcessModule(moduleName) {
  return moduleName === 'process' || moduleName === 'node:process';
}

function isModuleLoaderModule(moduleName) {
  return moduleName === 'module' || moduleName === 'node:module';
}

function isExactCreateRequireImport(node) {
  const bindings = node.importClause?.namedBindings;
  return node.importClause && !node.importClause.name && !node.importClause.isTypeOnly &&
    bindings && ts.isNamedImports(bindings) && bindings.elements.length === 1 &&
    !bindings.elements[0].propertyName &&
    bindings.elements[0].name.text === 'createRequire';
}

function isExactPrismaImport(node) {
  const bindings = node.importClause?.namedBindings;
  return node.importClause && !node.importClause.name && !node.importClause.isTypeOnly &&
    bindings && ts.isNamedImports(bindings) && hasExactPrismaClientBinding(bindings.elements);
}

function isExactPrismaRequire(node) {
  const declaration = node.parent;
  return ts.isVariableDeclaration(declaration) && declaration.initializer === node &&
    ts.isObjectBindingPattern(declaration.name) && hasExactPrismaClientBinding(declaration.name.elements);
}

function hasExactPrismaClientBinding(elements) {
  return elements.some((element) =>
    !element.dotDotDotToken && !element.propertyName &&
    ts.isIdentifier(element.name) && element.name.text === 'PrismaClient',
  ) && elements.every((element) =>
    !element.dotDotDotToken && !element.propertyName && ts.isIdentifier(element.name),
  );
}

function staticImporterName(node, label) {
  if (!ts.isIdentifier(node.expression)) return undefined;
  if (node.expression.text === 'require') return 'require';
  return label === 'admin-web/scripts/admin-runtime-smoke.mjs' && node.expression.text === 'backendRequire'
    ? 'backendRequire'
    : undefined;
}

function isAllowedDynamicRequire(node, label) {
  if (label !== 'backend/scripts/smoke/conversation-unification-smoke.js') return false;
  const argument = unwrapExpression(node.arguments[0]);
  if (!ts.isCallExpression(argument) || !ts.isPropertyAccessExpression(argument.expression)) return false;
  const owner = argument.expression.expression;
  return ts.isIdentifier(owner) && owner.text === 'path' &&
    argument.expression.name.text === 'join' &&
    argument.arguments.length === 3 &&
    ts.isIdentifier(unwrapExpression(argument.arguments[0])) &&
    unwrapExpression(argument.arguments[0]).text === 'socketIoRoot' &&
    evaluateStaticString(argument.arguments[1]) === 'client-dist' &&
    evaluateStaticString(argument.arguments[2]) === 'socket.io.js';
}

function isModuleRequireCall(node) {
  const member = staticOwnerMember(node.expression);
  return member?.owner === 'module' && member.member === 'require';
}

function isRequireAliasDeclaration(node) {
  const declaration = node.parent;
  return ts.isVariableDeclaration(declaration) && declaration.initializer === node &&
    ts.isIdentifier(node.expression) && node.expression.text === 'require' &&
    ts.isIdentifier(declaration.name) && node.arguments.length === 0;
}

function assertNoPrismaAlias(node, label) {
  if (ts.isVariableDeclaration(node) && ts.isIdentifier(node.name) && node.initializer &&
    ts.isIdentifier(unwrapExpression(node.initializer)) && unwrapExpression(node.initializer).text === 'PrismaClient' &&
    node.name.text !== 'PrismaClient') {
    throw new Error(`${label} creates a PrismaClient alias outside the static database-client grammar.`);
  }
  if (ts.isBinaryExpression(node) && isAssignmentOperator(node.operatorToken.kind) && ts.isIdentifier(unwrapExpression(node.right)) &&
    unwrapExpression(node.right).text === 'PrismaClient') {
    throw new Error(`${label} assigns a PrismaClient alias outside the static database-client grammar.`);
  }
}

function isReflectConstructOfPrismaClient(node) {
  const member = ts.isCallExpression(node) ? staticOwnerMember(node.expression) : null;
  return ts.isCallExpression(node) && member?.owner === 'Reflect' &&
    member.member === 'construct' && node.arguments.length > 0 &&
    ts.isIdentifier(unwrapExpression(node.arguments[0])) &&
    unwrapExpression(node.arguments[0]).text === 'PrismaClient';
}

function assertNoProcessAlias(node, label) {
  if (exactEnvironmentInfrastructure.has(label)) return;
  if (ts.isParameter(node) && node.initializer && isProcessOrEnvironment(node.initializer)) {
    throw new Error(`${label} creates a process alias outside the narrow environment grammar.`);
  }
  if (ts.isVariableDeclaration(node) && node.initializer) {
    if (ts.isIdentifier(node.name) && isProcessOrEnvironment(node.initializer)) {
      throw new Error(`${label} creates a process alias outside the narrow environment grammar.`);
    }
    if (ts.isObjectBindingPattern(node.name) && isProcessIdentifier(node.initializer) &&
      node.name.elements.some((element) => staticPropertyName(element.propertyName ?? element.name) === 'env')) {
      throw new Error(`${label} creates a process alias outside the narrow environment grammar.`);
    }
  }
  if (ts.isBinaryExpression(node) && isAssignmentOperator(node.operatorToken.kind) &&
    isProcessOrEnvironment(node.right) && !isDirectProcessEnvironment(node.left)) {
    throw new Error(`${label} assigns a process alias outside the narrow environment grammar.`);
  }
}

function isProcessIdentifier(node) {
  node = unwrapExpression(node);
  if (ts.isIdentifier(node)) return node.text === 'process';
  if (
    ts.isPropertyAccessExpression(node) &&
    ts.isIdentifier(node.expression) &&
    (node.expression.text === 'global' || node.expression.text === 'globalThis') &&
    node.name.text === 'process'
  ) {
    return true;
  }
  return ts.isElementAccessExpression(node) &&
    ts.isIdentifier(node.expression) &&
    (node.expression.text === 'global' || node.expression.text === 'globalThis') &&
    evaluateStaticString(node.argumentExpression) === 'process';
}

function isDirectProcessEnvironment(node) {
  node = unwrapExpression(node);
  if (ts.isPropertyAccessExpression(node)) return isProcessIdentifier(node.expression) && node.name.text === 'env';
  return ts.isElementAccessExpression(node) && isProcessIdentifier(node.expression) &&
    evaluateStaticString(node.argumentExpression) === 'env';
}

function isProcessOrEnvironment(node) {
  return isProcessIdentifier(node) || isDirectProcessEnvironment(node);
}

function hasExactEnvironmentValidatorBinding(sourceFile, label) {
  let bindings = 0;
  for (const statement of sourceFile.statements) {
    if (ts.isImportDeclaration(statement)) {
      const moduleName = staticModuleName(statement.moduleSpecifier);
      const namedBindings = statement.importClause?.namedBindings;
      if (
        isAllowedEnvironmentValidatorModule(moduleName, label) &&
        namedBindings &&
        ts.isNamedImports(namedBindings) &&
        namedBindings.elements.some((element) =>
          !element.propertyName &&
          element.name.text === 'assertManagedSmokeEnvironment'
        )
      ) {
        bindings += 1;
      }
      continue;
    }
    if (!ts.isVariableStatement(statement)) continue;
    for (const declaration of statement.declarationList.declarations) {
      if (
        !ts.isObjectBindingPattern(declaration.name) ||
        !declaration.initializer ||
        !ts.isCallExpression(unwrapExpression(declaration.initializer))
      ) {
        continue;
      }
      const initializer = unwrapExpression(declaration.initializer);
      const importer = staticImporterName(initializer, label);
      const moduleName = staticModuleName(initializer.arguments[0]);
      if (
        importer &&
        initializer.arguments.length === 1 &&
        isAllowedEnvironmentValidatorModule(moduleName, label) &&
        declaration.name.elements.some((element) =>
          !element.dotDotDotToken &&
          !element.propertyName &&
          ts.isIdentifier(element.name) &&
          element.name.text === 'assertManagedSmokeEnvironment'
        )
      ) {
        bindings += 1;
      }
    }
  }
  return bindings === 1;
}

function assertEnvironmentValidatorIdentifierUsage(node, label, hasBinding) {
  if (exactEnvironmentInfrastructure.has(label)) return;
  if (!ts.isIdentifier(node) || node.text !== 'assertManagedSmokeEnvironment') return;
  if (isWithinTypeOnlySyntax(node)) return;
  if (isExactEnvironmentValidatorBindingIdentifier(node, label)) return;
  if (
    hasBinding &&
    ts.isCallExpression(node.parent) &&
    node.parent.expression === node
  ) {
    return;
  }
  throw new Error(`${label} aliases or shadows the managed environment validator.`);
}

function isWithinTypeOnlySyntax(node) {
  for (let current = node.parent; current && !ts.isSourceFile(current); current = current.parent) {
    if (ts.isTypeNode(current)) return true;
  }
  return false;
}

function isExactEnvironmentValidatorBindingIdentifier(node, label) {
  if (ts.isImportSpecifier(node.parent)) {
    const namedImports = node.parent.parent;
    const importClause = namedImports?.parent;
    const declaration = importClause?.parent;
    return node.parent.name === node &&
      !node.parent.propertyName &&
      ts.isNamedImports(namedImports) &&
      ts.isImportClause(importClause) &&
      ts.isImportDeclaration(declaration) &&
      ts.isSourceFile(declaration.parent) &&
      isAllowedEnvironmentValidatorModule(
        staticModuleName(declaration.moduleSpecifier),
        label,
      );
  }
  if (
    !ts.isBindingElement(node.parent) ||
    node.parent.name !== node ||
    node.parent.propertyName ||
    !ts.isObjectBindingPattern(node.parent.parent)
  ) {
    return false;
  }
  const declaration = node.parent.parent.parent;
  if (
    !ts.isVariableDeclaration(declaration) ||
    !declaration.initializer ||
    !ts.isCallExpression(unwrapExpression(declaration.initializer)) ||
    !ts.isVariableDeclarationList(declaration.parent) ||
    !ts.isVariableStatement(declaration.parent.parent) ||
    !ts.isSourceFile(declaration.parent.parent.parent)
  ) {
    return false;
  }
  const initializer = unwrapExpression(declaration.initializer);
  return Boolean(staticImporterName(initializer, label)) &&
    initializer.arguments.length === 1 &&
    isAllowedEnvironmentValidatorModule(
      staticModuleName(initializer.arguments[0]),
      label,
    );
}

function isAllowedEnvironmentValidatorModule(moduleName, label) {
  if (label === 'admin-web/scripts/admin-runtime-smoke.mjs') {
    return moduleName === './scripts/smoke/smoke-utils.js';
  }
  if (label === 'backend/scripts/load/load-test.js') {
    return moduleName === '../smoke/smoke-utils';
  }
  return label.startsWith('backend/scripts/smoke/') &&
    (moduleName === './smoke-utils' || moduleName === './smoke-utils.js');
}

function assertProcessCapabilityUsage(node, label, hasEnvironmentValidatorBinding) {
  if (exactEnvironmentInfrastructure.has(label)) return;
  if (isDirectProcessEnvironment(node)) {
    const parent = node.parent;
    if (
      (ts.isPropertyAccessExpression(parent) || ts.isElementAccessExpression(parent)) &&
      parent.expression === node
    ) {
      return;
    }
    if (
      ts.isCallExpression(parent) &&
      parent.arguments.length === 1 &&
      parent.arguments[0] === node &&
      ts.isIdentifier(parent.expression) &&
      parent.expression.text === 'assertManagedSmokeEnvironment' &&
      hasEnvironmentValidatorBinding &&
      ts.isExpressionStatement(parent.parent) &&
      parent.parent.expression === parent
    ) {
      return;
    }
    if (
      exactEnvironmentSpreadInfrastructure.has(label) &&
      (ts.isSpreadElement(parent) || ts.isSpreadAssignment(parent)) &&
      parent.expression === node
    ) {
      return;
    }
    if (
      isExactRunnerEnvironmentFallback(node, parent, label)
    ) {
      return;
    }
    throw new Error(`${label} lets process.env escape outside the narrow environment grammar.`);
  }
  if (!isProcessIdentifier(node)) return;
  const parent = node.parent;
  if (
    (ts.isPropertyAccessExpression(parent) || ts.isElementAccessExpression(parent)) &&
    parent.expression === node
  ) {
    return;
  }
  throw new Error(`${label} lets process escape outside the narrow environment grammar.`);
}

function isExactRunnerEnvironmentFallback(node, parent, label) {
  if (
    label !== 'backend/scripts/smoke/run-isolated-smoke.js' ||
    !ts.isBinaryExpression(parent) ||
    parent.operatorToken.kind !== ts.SyntaxKind.QuestionQuestionToken ||
    parent.right !== node
  ) {
    return false;
  }
  const left = unwrapExpression(parent.left);
  return ts.isPropertyAccessExpression(left) &&
    ts.isIdentifier(left.expression) &&
    left.expression.text === 'options' &&
    left.name.text === 'env';
}

function assertEnvironmentMutatorCapabilityUsage(node, label) {
  const member = staticOwnerMember(node);
  if (!member || !environmentMutatorCapabilities.has(`${member.owner}.${member.member}`)) {
    return;
  }
  if (ts.isCallExpression(node.parent) && node.parent.expression === node) return;
  throw new Error(`${label} lets an environment mutation capability escape the narrow grammar.`);
}

function assertNoEnvironmentMutation(node, label) {
  if (isEnvironmentMutatorAlias(node)) {
    throw new Error(`${label} creates an environment mutation alias outside the narrow environment grammar.`);
  }
  if (ts.isDeleteExpression(node) && directEnvironmentKey(node.expression) !== null) {
    throw new Error(`${label} deletes an environment key outside the narrow environment grammar.`);
  }
  if (
    (ts.isPrefixUnaryExpression(node) || ts.isPostfixUnaryExpression(node)) &&
    (node.operator === ts.SyntaxKind.PlusPlusToken || node.operator === ts.SyntaxKind.MinusMinusToken) &&
    directEnvironmentKey(node.operand) !== null
  ) {
    throw new Error(`${label} mutates an environment key outside the narrow environment grammar.`);
  }
  if (ts.isBinaryExpression(node) && isAssignmentOperator(node.operatorToken.kind)) {
    if (isDirectProcessEnvironment(node.left)) {
      throw new Error(`${label} replaces process.env outside the narrow environment grammar.`);
    }
    const key = directEnvironmentKey(node.left);
    if (key !== null) assertAllowedEnvironmentMutation(label, key);
  }
  if (!ts.isCallExpression(node)) return;
  const member = staticOwnerMember(node.expression);
  if (member?.owner === 'Object' && member.member === 'assign' && isDirectProcessEnvironment(node.arguments[0])) {
    if (node.arguments.length < 2 || !ts.isObjectLiteralExpression(node.arguments[1])) {
      throw new Error(`${label} uses an unapproved environment mutation.`);
    }
    for (const property of node.arguments[1].properties) {
      if (ts.isSpreadAssignment(property) || ts.isMethodDeclaration(property) || ts.isGetAccessorDeclaration(property) || ts.isSetAccessorDeclaration(property)) {
        throw new Error(`${label} uses an unapproved environment mutation.`);
      }
      if (ts.isPropertyAssignment(property) || ts.isShorthandPropertyAssignment(property)) {
        assertAllowedEnvironmentMutation(label, staticPropertyName(property.name));
      }
    }
  }
  if (member?.owner === 'Reflect' &&
    ['set', 'defineProperty'].includes(member.member) && isDirectProcessEnvironment(node.arguments[0])) {
    assertAllowedEnvironmentMutation(label, evaluateStaticString(node.arguments[1]));
  }
  if (member?.owner === 'Object' && member.member === 'defineProperty' &&
    isDirectProcessEnvironment(node.arguments[0])) {
    assertAllowedEnvironmentMutation(label, evaluateStaticString(node.arguments[1]));
  }
}

function staticOwnerMember(node) {
  node = unwrapExpression(node);
  if (ts.isPropertyAccessExpression(node) && ts.isIdentifier(node.expression)) {
    return { owner: node.expression.text, member: node.name.text };
  }
  if (ts.isElementAccessExpression(node) && ts.isIdentifier(node.expression)) {
    const member = evaluateStaticString(node.argumentExpression);
    return typeof member === 'string' ? { owner: node.expression.text, member } : null;
  }
  return null;
}

function isEnvironmentMutatorAlias(node) {
  const isMutator = (expression) => {
    const member = staticOwnerMember(expression);
    return member
      ? environmentMutatorCapabilities.has(`${member.owner}.${member.member}`)
      : false;
  };
  if (ts.isVariableDeclaration(node) && node.initializer) {
    if (ts.isIdentifier(node.name) && isMutator(node.initializer)) return true;
    if (ts.isObjectBindingPattern(node.name) && ts.isIdentifier(unwrapExpression(node.initializer))) {
      const owner = unwrapExpression(node.initializer).text;
      return node.name.elements.some((element) => {
        const member = staticPropertyName(element.propertyName ?? element.name);
        return environmentMutatorCapabilities.has(`${owner}.${member}`);
      });
    }
  }
  return ts.isBinaryExpression(node) && isAssignmentOperator(node.operatorToken.kind) &&
    isMutator(node.right);
}

function directEnvironmentKey(node) {
  node = unwrapExpression(node);
  if (ts.isPropertyAccessExpression(node) && isDirectProcessEnvironment(node.expression)) return node.name.text;
  if (ts.isElementAccessExpression(node) && isDirectProcessEnvironment(node.expression)) {
    return evaluateStaticString(node.argumentExpression);
  }
  return null;
}

function assertAllowedEnvironmentMutation(label, key) {
  if (exactEnvironmentInfrastructure.has(label)) return;
  if (typeof key !== 'string') {
    throw new Error(`${label} uses a dynamic environment mutation outside the narrow environment grammar.`);
  }
  if (allowedEnvironmentMutationKeys.get(label)?.has(key)) return;
  throw new Error(`${label} writes ${key} outside the narrow environment grammar.`);
}

function staticPropertyName(name) {
  if (!name) return undefined;
  if (ts.isIdentifier(name) || ts.isStringLiteralLike(name)) return name.text;
  return ts.isComputedPropertyName(name) ? evaluateStaticString(name.expression) : undefined;
}

function assertPrismaClientIdentifierUsage(node, label) {
  if (!ts.isIdentifier(node) || node.text !== 'PrismaClient') return;
  if (isExactPrismaBindingIdentifier(node, label)) return;
  if (ts.isNewExpression(node.parent) && node.parent.expression === node) return;
  throw new Error(`${label} uses PrismaClient outside the static database-client grammar.`);
}

function assertLoaderIdentifierUsage(node, label) {
  if (!ts.isIdentifier(node)) return;
  if (node.text === 'require') {
    if (ts.isCallExpression(node.parent) && node.parent.expression === node) return;
    if (
      ts.isPropertyAccessExpression(node.parent) &&
      node.parent.expression === node &&
      (node.parent.name.text === 'main' || node.parent.name.text === 'resolve')
    ) {
      return;
    }
    throw new Error(`${label} creates a require alias outside the static database-client grammar.`);
  }
  if (node.text === 'createRequire') {
    if (label !== 'admin-web/scripts/admin-runtime-smoke.mjs') {
      throw new Error(`${label} uses a module loader outside the static database-client grammar.`);
    }
    if (
      ts.isImportSpecifier(node.parent) &&
      node.parent.name === node &&
      !node.parent.propertyName
    ) {
      return;
    }
    if (
      ts.isCallExpression(node.parent) &&
      node.parent.expression === node &&
      ts.isVariableDeclaration(node.parent.parent) &&
      node.parent.parent.initializer === node.parent &&
      ts.isIdentifier(node.parent.parent.name) &&
      node.parent.parent.name.text === 'backendRequire'
    ) {
      return;
    }
    throw new Error(`${label} creates a module loader alias outside the static database-client grammar.`);
  }
  if (node.text !== 'backendRequire') return;
  if (label !== 'admin-web/scripts/admin-runtime-smoke.mjs') {
    throw new Error(`${label} uses backendRequire outside the static database-client grammar.`);
  }
  if (ts.isCallExpression(node.parent) && node.parent.expression === node) return;
  if (
    ts.isVariableDeclaration(node.parent) &&
    node.parent.name === node &&
    node.parent.initializer &&
    ts.isCallExpression(unwrapExpression(node.parent.initializer)) &&
    ts.isIdentifier(unwrapExpression(node.parent.initializer).expression) &&
    unwrapExpression(node.parent.initializer).expression.text === 'createRequire'
  ) {
    return;
  }
  throw new Error(`${label} creates a backendRequire alias outside the static database-client grammar.`);
}

function isExactPrismaBindingIdentifier(node, label) {
  if (ts.isImportSpecifier(node.parent)) {
    const namedImports = node.parent.parent;
    const importClause = namedImports?.parent;
    const declaration = importClause?.parent;
    return node.parent.name === node && !node.parent.propertyName &&
      ts.isNamedImports(namedImports) && ts.isImportClause(importClause) &&
      ts.isImportDeclaration(declaration) &&
      allowedDirectDatabaseClients.get(label)?.has(staticModuleName(declaration.moduleSpecifier));
  }
  if (!ts.isBindingElement(node.parent) || node.parent.name !== node || node.parent.propertyName ||
    !ts.isObjectBindingPattern(node.parent.parent)) return false;
  const declaration = node.parent.parent.parent;
  if (!ts.isVariableDeclaration(declaration) || !ts.isCallExpression(declaration.initializer)) return false;
  const importer = staticImporterName(declaration.initializer, label);
  return Boolean(importer) && allowedDirectDatabaseClients.get(label)?.has(
    staticModuleName(declaration.initializer.arguments[0]),
  );
}

function isAssignmentOperator(kind) {
  return new Set([
    ts.SyntaxKind.EqualsToken,
    ts.SyntaxKind.PlusEqualsToken,
    ts.SyntaxKind.MinusEqualsToken,
    ts.SyntaxKind.AsteriskEqualsToken,
    ts.SyntaxKind.AsteriskAsteriskEqualsToken,
    ts.SyntaxKind.SlashEqualsToken,
    ts.SyntaxKind.PercentEqualsToken,
    ts.SyntaxKind.LessThanLessThanEqualsToken,
    ts.SyntaxKind.GreaterThanGreaterThanEqualsToken,
    ts.SyntaxKind.GreaterThanGreaterThanGreaterThanEqualsToken,
    ts.SyntaxKind.AmpersandEqualsToken,
    ts.SyntaxKind.BarEqualsToken,
    ts.SyntaxKind.CaretEqualsToken,
    ts.SyntaxKind.BarBarEqualsToken,
    ts.SyntaxKind.AmpersandAmpersandEqualsToken,
    ts.SyntaxKind.QuestionQuestionEqualsToken,
  ]).has(kind);
}

function collectFiles(directory) {
  if (!existsSync(directory)) return [];
  return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const filePath = join(directory, entry.name);
    if (entry.isDirectory()) return collectFiles(filePath);
    const extension = entry.name.slice(entry.name.lastIndexOf('.'));
    return sourceExtensions.has(extension) ? [filePath] : [];
  });
}

function collectGuardedSourceFiles() {
  return [
    ...collectFiles(join(backendRoot, 'scripts', 'smoke')),
    ...collectFiles(join(backendRoot, 'scripts', 'load')),
    ...collectFiles(join(repositoryRoot, 'admin-web', 'scripts')),
  ];
}

function assertExternalOpenwaSmokeContract(command, source) {
  if (command !== externalOpenwaCommand) {
    throw new Error('OpenWA smoke must use the exact external command with no chained command.');
  }
  if (
    !/const requiredConfirmation = ['"]I_ACCEPT_REAL_WHATSAPP_SEND['"]/.test(source) ||
    !/OPENWA_SMOKE_CONFIRM\s*!==\s*requiredConfirmation/.test(source)
  ) {
    throw new Error('OpenWA external mutation requires the explicit confirmation guard.');
  }
  if (/\b(?:DATABASE_URL|SMOKE_DATABASE_URL|PrismaClient|@prisma\/client|postgres(?:ql)?)\b/i.test(source)) {
    throw new Error('OpenWA external mutation must not use a database.');
  }
}

function main() {
  const backendPackage = readJson(join(backendRoot, 'package.json'));
  const adminPackage = readJson(join(repositoryRoot, 'admin-web', 'package.json'));
  assertBackendTestRunnerContract(backendPackage.scripts);
  assertOfficialMutatingScriptsUseManagedRunner(backendPackage.scripts);
  assertExternalOpenwaSmokeContract(
    backendPackage.scripts['smoke:openwa-otp'],
    readFileSync(join(backendRoot, 'scripts', 'smoke', 'openwa-otp-smoke.js'), 'utf8'),
  );
  if (adminPackage.scripts['smoke:admin-runtime'] !== `node ../backend/${managedRunner} --admin-runtime`) {
    throw new Error('Admin runtime smoke must use the exact managed isolated smoke command.');
  }

  for (const sourcePath of collectGuardedSourceFiles()) {
    const label = sourcePath.slice(repositoryRoot.length + 1).replace(/\\/g, '/');
    const source = readFileSync(sourcePath, 'utf8');
    assertNoUnsafeDatabaseTargets(source, label);
    assertEntrypointDatabaseContract(source, label);
  }

  console.log('PASS - Phase 0 source guard: exact managed commands, external OpenWA contract, and database targets are safe.');
}

if (require.main === module) main();

module.exports = {
  assertBackendTestBatches,
  assertBackendTestRunnerContract,
  assertExternalOpenwaSmokeContract,
  assertNoUnsafeDatabaseTargets,
  assertEntrypointDatabaseContract,
  assertOfficialMutatingScriptsUseManagedRunner,
  collectGuardedSourceFiles,
  extractPostgresUrls,
};
