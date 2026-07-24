#!/usr/bin/env node
'use strict';

const { existsSync, readFileSync, readdirSync } = require('fs');
const { join, resolve } = require('path');
const ts = require('typescript');

const backendRoot = resolve(__dirname, '..', '..');
const repositoryRoot = resolve(backendRoot, '..');
const managedRunner = 'scripts/smoke/run-isolated-smoke.js';
const externalOpenwaCommand = 'node scripts/smoke/openwa-otp-smoke.js';
const sourceExtensions = new Set(['.js', '.ts', '.mjs', '.cjs']);
const allowedDirectDatabaseClients = new Map([
  'admin-web/scripts/admin-runtime-smoke.mjs',
  'backend/scripts/smoke/account-deletion-smoke.ts',
  'backend/scripts/smoke/backend-completion-smoke.js',
  'backend/scripts/smoke/conversation-unification-smoke.js',
  'backend/scripts/smoke/marketplace-smoke.js',
  'backend/scripts/smoke/notifications-apis-smoke.js',
  'backend/scripts/smoke/phase0-fixtures-smoke.js',
  'backend/scripts/smoke/private-chat-media-smoke.js',
  'backend/scripts/smoke/provider-dashboard-smoke.js',
  'backend/scripts/smoke/providers-quotes-smoke.js',
  'backend/scripts/smoke/quote-stability-smoke.js',
  'backend/scripts/smoke/sharing-security-smoke.js',
  'backend/scripts/smoke/ux-c4-c7-smoke.js',
].map((label) => [label, new Set(['@prisma/client'])]));
const allowedDatabaseUrlWriters = new Set(['backend/scripts/smoke/smoke-utils.js']);

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
  ['smoke:providers-quotes', 'providers-quotes-smoke.js'],
  ['smoke:quote-stability', 'quote-stability-smoke.js'],
  ['smoke:conversation-unification', 'conversation-unification-smoke.js'],
  ['smoke:private-chat-media', 'private-chat-media-smoke.js'],
  ['smoke:provider-dashboard', 'provider-dashboard-smoke.js'],
  ['smoke:ux-backend-support', 'ux-backend-support-smoke.js'],
  ['smoke:ux-c4-c7', 'ux-c4-c7-smoke.js'],
  ['smoke:backend-completion', 'backend-completion-smoke.js'],
  ['smoke:account-deletion', 'account-deletion-smoke.ts'],
  ['smoke:phase0-fixtures', 'phase0-fixtures-smoke.js'],
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

function assertNoUnsafeDatabaseTargets(source, label) {
  if (/\b(?:prisma\s+)?migrate\s+reset\b|\bprisma\s+db\s+push\b/i.test(source)) {
    throw new Error(`${label} contains a destructive Prisma command.`);
  }

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
  const constants = collectStringConstants(sourceFile);
  const staticStrings = new Set();
  const visit = (node) => {
    const value = evaluateStaticString(node, constants);
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

function collectStringConstants(sourceFile) {
  const constants = new Map();
  const visit = (node) => {
    if (ts.isVariableDeclaration(node) && ts.isIdentifier(node.name) && node.initializer) {
      const declarationList = node.parent;
      if (ts.isVariableDeclarationList(declarationList) && (declarationList.flags & ts.NodeFlags.Const)) {
        constants.set(node.name.text, node.initializer);
      }
    }
    ts.forEachChild(node, visit);
  };
  visit(sourceFile);
  return constants;
}

function evaluateStaticString(node, constants, visited = new Set()) {
  if (ts.isStringLiteralLike(node) || ts.isNoSubstitutionTemplateLiteral(node)) return node.text;
  if (ts.isTemplateExpression(node)) {
    let value = node.head.text;
    for (const span of node.templateSpans) {
      const expression = evaluateStaticString(span.expression, constants, visited);
      if (expression === undefined) return undefined;
      value += expression + span.literal.text;
    }
    return value;
  }
  if (ts.isParenthesizedExpression(node)) return evaluateStaticString(node.expression, constants, visited);
  if (ts.isBinaryExpression(node) && node.operatorToken.kind === ts.SyntaxKind.PlusToken) {
    const left = evaluateStaticString(node.left, constants, visited);
    const right = evaluateStaticString(node.right, constants, visited);
    return left === undefined || right === undefined ? undefined : left + right;
  }
  if (ts.isIdentifier(node) && constants.has(node.text) && !visited.has(node.text)) {
    const nextVisited = new Set(visited);
    nextVisited.add(node.text);
    return evaluateStaticString(constants.get(node.text), constants, nextVisited);
  }
  return undefined;
}

function assertEntrypointDatabaseContract(source, label) {
  const sourceFile = parseSource(source);
  const normalizedLabel = label.replace(/\\/g, '/');
  const allowedClientModules = allowedDirectDatabaseClients.get(normalizedLabel) ?? new Set();
  const directClientAllowed = allowedClientModules.size > 0;
  const databaseUrlWriterAllowed = allowedDatabaseUrlWriters.has(normalizedLabel);
  const constants = collectStringConstants(sourceFile);
  const databaseAliases = collectDatabaseAliases(sourceFile);
  const environmentAliases = collectEnvironmentAliases(sourceFile, constants);
  if (hasDynamicDatabaseImport(sourceFile, constants)) {
    throw new Error(`${normalizedLabel} imports an independent database client outside managed smoke infrastructure.`);
  }
  for (const moduleName of importedDatabaseModules(sourceFile, constants)) {
    if (!allowedClientModules.has(moduleName)) {
      throw new Error(`${normalizedLabel} imports an independent database client outside managed smoke infrastructure.`);
    }
  }
  let violation;
  const visit = (node) => {
    if (violation) return;
    if (ts.isNewExpression(node) && isDirectDatabaseConstructor(node.expression, databaseAliases)) {
      if (!directClientAllowed) {
        violation = `${normalizedLabel} creates an independent database client.`;
      } else if (node.arguments?.length) {
        violation = `${normalizedLabel} gives an allowed database client unapproved constructor arguments.`;
      }
    }
    if (ts.isPropertyAssignment(node) && /^(?:datasourceUrl|datasources)$/.test(staticPropertyName(node.name, constants) ?? '')) {
      violation = `${normalizedLabel} contains a datasource override.`;
    }
    if (
      ts.isBinaryExpression(node) && isAssignmentOperator(node.operatorToken.kind) &&
      environmentAssignmentName(node.left, constants, environmentAliases) &&
      !databaseUrlWriterAllowed
    ) {
      violation = `${normalizedLabel} writes ${environmentAssignmentName(node.left, constants, environmentAliases)} outside managed smoke infrastructure.`;
    }
    if (!databaseUrlWriterAllowed && ts.isCallExpression(node)) {
      const name = environmentMutationName(node, constants, environmentAliases);
      if (name) violation = `${normalizedLabel} writes ${name} outside managed smoke infrastructure.`;
    }
    ts.forEachChild(node, visit);
  };
  visit(sourceFile);
  if (violation) throw new Error(violation);
}

function collectDatabaseAliases(sourceFile) {
  const aliases = new Set(['PrismaClient']);
  const visit = (node) => {
    if (ts.isImportDeclaration(node) && ts.isStringLiteral(node.moduleSpecifier) && isDatabaseModule(node.moduleSpecifier.text)) {
      const bindings = node.importClause?.namedBindings;
      if (bindings && ts.isNamedImports(bindings)) {
        for (const item of bindings.elements) aliases.add(item.name.text);
      }
      if (bindings && ts.isNamespaceImport(bindings)) aliases.add(bindings.name.text);
      if (node.importClause?.name) aliases.add(node.importClause.name.text);
    }
    if (
      ts.isVariableDeclaration(node) && node.initializer && ts.isCallExpression(node.initializer) &&
      ts.isIdentifier(node.initializer.expression) && node.initializer.expression.text === 'require' &&
      node.initializer.arguments.length === 1 && ts.isStringLiteral(node.initializer.arguments[0]) &&
      isDatabaseModule(node.initializer.arguments[0].text)
    ) {
      if (ts.isIdentifier(node.name)) aliases.add(node.name.text);
      if (ts.isObjectBindingPattern(node.name)) {
        for (const element of node.name.elements) aliases.add(element.name.getText(sourceFile));
      }
    }
    ts.forEachChild(node, visit);
  };
  visit(sourceFile);
  let changed = true;
  while (changed) {
    changed = false;
    const collectAliases = (node) => {
      if (ts.isVariableDeclaration(node) && ts.isIdentifier(node.name) && node.initializer && isDatabaseAliasExpression(node.initializer, aliases)) {
        if (!aliases.has(node.name.text)) {
          aliases.add(node.name.text);
          changed = true;
        }
      }
      ts.forEachChild(node, collectAliases);
    };
    collectAliases(sourceFile);
  }
  return aliases;
}

function isDatabaseAliasExpression(expression, aliases) {
  if (ts.isIdentifier(expression)) return aliases.has(expression.text);
  if (ts.isParenthesizedExpression(expression) || ts.isAwaitExpression(expression)) {
    return isDatabaseAliasExpression(expression.expression, aliases);
  }
  if (!ts.isPropertyAccessExpression(expression) || !/^(?:PrismaClient|Client|Pool)$/.test(expression.name.text)) return false;
  if (ts.isIdentifier(expression.expression)) return aliases.has(expression.expression.text);
  return ts.isCallExpression(expression.expression) && ts.isIdentifier(expression.expression.expression) &&
    expression.expression.expression.text === 'require' && expression.expression.arguments.length === 1 &&
    ts.isStringLiteral(expression.expression.arguments[0]) && isDatabaseModule(expression.expression.arguments[0].text);
}

function importedDatabaseModules(sourceFile, constants) {
  const modules = new Set();
  const visit = (node) => {
    const moduleName = staticImportedModuleName(node, constants);
    if (moduleName && isDatabaseModule(moduleName)) modules.add(moduleName);
    ts.forEachChild(node, visit);
  };
  visit(sourceFile);
  return modules;
}

function hasDynamicDatabaseImport(sourceFile, constants) {
  let found = false;
  const visit = (node) => {
    if (ts.isCallExpression(node) && node.expression.kind === ts.SyntaxKind.ImportKeyword && node.arguments.length === 1) {
      const moduleName = evaluateStaticString(node.arguments[0], constants);
      if (moduleName && isDatabaseModule(moduleName)) found = true;
    }
    ts.forEachChild(node, visit);
  };
  visit(sourceFile);
  return found;
}

function staticImportedModuleName(node, constants) {
  if (ts.isImportDeclaration(node)) return ts.isStringLiteral(node.moduleSpecifier) ? node.moduleSpecifier.text : undefined;
  if (!ts.isCallExpression(node) || node.arguments.length !== 1) return undefined;
  const isRequire = ts.isIdentifier(node.expression) && node.expression.text === 'require';
  const isDynamicImport = node.expression.kind === ts.SyntaxKind.ImportKeyword;
  return isRequire || isDynamicImport ? evaluateStaticString(node.arguments[0], constants) : undefined;
}

function isDatabaseModule(moduleName) {
  return moduleName === '@prisma/client' || moduleName === 'pg' || moduleName === 'postgres' ||
    moduleName.startsWith('@prisma/adapter-') || moduleName.startsWith('@prisma/driver-adapter-');
}

function isDirectDatabaseConstructor(expression, aliases) {
  if (ts.isIdentifier(expression)) return aliases.has(expression.text) || /^(?:PrismaClient|Client|Pool)$/.test(expression.text);
  return ts.isPropertyAccessExpression(expression) && ts.isIdentifier(expression.expression) && aliases.has(expression.expression.text);
}

function staticPropertyName(name, constants) {
  if (ts.isIdentifier(name) || ts.isStringLiteralLike(name)) return name.text;
  if (ts.isComputedPropertyName(name)) return evaluateStaticString(name.expression, constants);
  return undefined;
}

function collectEnvironmentAliases(sourceFile, constants) {
  const aliases = new Set();
  let changed = true;
  while (changed) {
    changed = false;
    const visit = (node) => {
      if (ts.isVariableDeclaration(node) && node.initializer) {
        if (ts.isIdentifier(node.name) && isProcessEnvironment(node.initializer, constants, aliases) && !aliases.has(node.name.text)) {
          aliases.add(node.name.text);
          changed = true;
        }
        if (ts.isObjectBindingPattern(node.name) && ts.isIdentifier(node.initializer) && node.initializer.text === 'process') {
          for (const element of node.name.elements) {
            const property = element.propertyName ? staticPropertyName(element.propertyName, constants) : element.name.getText(sourceFile);
            if (property === 'env' && ts.isIdentifier(element.name) && !aliases.has(element.name.text)) {
              aliases.add(element.name.text);
              changed = true;
            }
          }
        }
      }
      ts.forEachChild(node, visit);
    };
    visit(sourceFile);
  }
  return aliases;
}

function isProcessEnvironment(expression, constants, aliases) {
  if (ts.isIdentifier(expression)) return aliases.has(expression.text);
  if (ts.isPropertyAccessExpression(expression)) {
    return ts.isIdentifier(expression.expression) && expression.expression.text === 'process' && expression.name.text === 'env';
  }
  return ts.isElementAccessExpression(expression) && ts.isIdentifier(expression.expression) &&
    expression.expression.text === 'process' && evaluateStaticString(expression.argumentExpression, constants) === 'env';
}

function environmentAssignmentName(left, constants, aliases) {
  let environmentAccess;
  let name;
  if (ts.isPropertyAccessExpression(left)) {
    environmentAccess = left.expression;
    name = left.name.text;
  } else if (ts.isElementAccessExpression(left)) {
    environmentAccess = left.expression;
    name = evaluateStaticString(left.argumentExpression, constants);
  } else {
    return undefined;
  }
  return isProcessEnvironment(environmentAccess, constants, aliases) &&
    (name === 'DATABASE_URL' || name === 'SMOKE_DATABASE_URL') ? name : undefined;
}

function environmentMutationName(node, constants, aliases) {
  if (ts.isPropertyAccessExpression(node.expression) && ts.isIdentifier(node.expression.expression)) {
    if (node.expression.expression.text === 'Object' && node.expression.name.text === 'assign' && node.arguments.length >= 2 &&
      isProcessEnvironment(node.arguments[0], constants, aliases) && ts.isObjectLiteralExpression(node.arguments[1])) {
      for (const property of node.arguments[1].properties) {
        if (ts.isPropertyAssignment(property)) {
          const name = staticPropertyName(property.name, constants);
          if (name === 'DATABASE_URL' || name === 'SMOKE_DATABASE_URL') return name;
        }
      }
    }
    if (node.expression.expression.text === 'Reflect' && node.expression.name.text === 'set' && node.arguments.length >= 2 &&
      isProcessEnvironment(node.arguments[0], constants, aliases)) {
      const name = evaluateStaticString(node.arguments[1], constants);
      if (name === 'DATABASE_URL' || name === 'SMOKE_DATABASE_URL') return name;
    }
  }
  return undefined;
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
  assertExternalOpenwaSmokeContract,
  assertNoUnsafeDatabaseTargets,
  assertEntrypointDatabaseContract,
  assertOfficialMutatingScriptsUseManagedRunner,
  collectGuardedSourceFiles,
  extractPostgresUrls,
};
