import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { createRequire } from 'node:module';
import {
  mkdtempSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(scriptDir, '..');
const manifestPath = path.join(repoRoot, 'admin-web', 'architecture', 'r10-admin-boundaries.json');
const adminRuntimeSmoke = Object.freeze({
  path: 'admin-web/scripts/admin-runtime-smoke.mjs',
  sha256: 'e896de8b6894faa14c402fab8bdd304c078278cdde0808db9cc6940af994ff48',
});
const adminRequire = createRequire(path.join(repoRoot, 'admin-web', 'package.json'));
const ts = adminRequire('typescript');

let scope = {};
let boundaries = {};
try {
  scope = await import('./check-r10-scope.mjs');
} catch {
  scope = {};
}
try {
  boundaries = await import('../admin-web/scripts/admin-boundaries.mjs');
} catch {
  boundaries = {};
}

function requireImplementation() {
  for (const name of [
    'checkR10Scope',
    'collectChangedPaths',
    'extractAdminRequestInventory',
    'extractAdminArabicLiteralInventory',
    'normalizeExistingAdminTest',
    'compareExistingAdminTest',
    'checkLegacyRootMilestone',
    'checkChangedPathFence',
  ]) assert.equal(typeof scope[name], 'function', `${name} must exist`);
  assert.equal(typeof boundaries.validateR10Manifest, 'function', 'validateR10Manifest must exist');
}

function manifestValue() {
  requireImplementation();
  return JSON.parse(readFileSync(manifestPath, 'utf8'));
}

function sha256(value) {
  return createHash('sha256').update(value).digest('hex');
}

const exactGenericTransportCall = [
  'fetch(`${apiBaseUrl}${path}`, {',
  "  method: options.method ?? 'GET',",
  '  headers: {',
  "    Accept: 'application/json',",
  "    'Content-Type': 'application/json',",
  '    ...(options.auth !== false && token',
  '      ? { Authorization: `Bearer ${token}` }',
  '      : {}),',
  "    ...(requestId ? { 'X-Client-Request-Id': requestId } : {}),",
  '  },',
  '  body: options.body === undefined ? undefined : JSON.stringify(options.body),',
  "  credentials: 'include',",
  '});',
].join('\n');

function productionAdminFiles() {
  const srcRoot = path.join(repoRoot, 'admin-web', 'src');
  const records = [];
  const visit = (directory) => {
    for (const entry of readdirSync(directory, { withFileTypes: true })) {
      const target = path.join(directory, entry.name);
      if (entry.isDirectory()) visit(target);
      else if (
        /\.(?:ts|tsx)$/.test(entry.name)
        && !/\.test\.(?:ts|tsx)$/.test(entry.name)
        && !target.includes(`${path.sep}test${path.sep}`)
      ) {
        records.push({
          path: path.relative(srcRoot, target).replaceAll('\\', '/'),
          sourceText: readFileSync(target, 'utf8'),
        });
      }
    }
  };
  visit(srcRoot);
  return records;
}

function runtimeSmokeSourceContract(sourceTextOverride) {
  const smokePath = path.join(repoRoot, 'admin-web', 'scripts', 'admin-runtime-smoke.mjs');
  const sourceText = sourceTextOverride ?? readFileSync(smokePath, 'utf8');
  const sourceFile = ts.createSourceFile(
    smokePath,
    sourceText,
    ts.ScriptTarget.Latest,
    true,
    ts.ScriptKind.JS,
  );
  let runFunction = null;
  let runBody = null;
  for (const statement of sourceFile.statements) {
    if (
      ts.isFunctionDeclaration(statement)
      && statement.name?.text === 'run'
      && statement.body
    ) {
      runFunction = statement;
      runBody = statement.body;
    }
  }
  assert.ok(runBody, 'admin runtime smoke must expose run()');

  const statements = [...runBody.statements];
  const scenarios = [];
  let active = null;
  for (const [index, statement] of statements.entries()) {
    if (!ts.isExpressionStatement(statement)) continue;
    const expression = statement.expression;
    if (
      ts.isBinaryExpression(expression)
      && expression.operatorToken.kind === ts.SyntaxKind.EqualsToken
      && expression.left.getText(sourceFile) === 'res'
      && ts.isAwaitExpression(expression.right)
      && ts.isCallExpression(expression.right.expression)
      && expression.right.expression.expression.getText(sourceFile) === 'request'
    ) {
      const call = expression.right.expression;
      active = {
        index,
        pathNode: call.arguments[0] ?? null,
        optionsNode: call.arguments[1] ?? null,
        checks: [],
      };
      scenarios.push(active);
      continue;
    }
    if (
      active
      && ts.isCallExpression(expression)
      && expression.expression.getText(sourceFile) === 'check'
    ) {
      if (expression.arguments[1]) active.checks.push(expression.arguments[1]);
    }
  }
  return { sourceFile, sourceText, runFunction, statements, scenarios };
}

function replaceRuntimeSourceOnce(sourceText, before, after) {
  const parts = sourceText.split(before);
  assert.equal(parts.length, 2, 'adversarial mutation must match exactly once');
  return `${parts[0]}${after}${parts[1]}`;
}

function unwrapRuntimeExpression(node) {
  let current = node;
  while (current && ts.isParenthesizedExpression(current)) current = current.expression;
  return current;
}

function runtimePropertyName(name) {
  if (ts.isIdentifier(name) || ts.isStringLiteral(name)) return name.text;
  return null;
}

function runtimeObjectProperty(objectNode, propertyName) {
  const node = unwrapRuntimeExpression(objectNode);
  if (!node || !ts.isObjectLiteralExpression(node)) return null;
  if (node.properties.some(
    (property) => !ts.isPropertyAssignment(property)
      || runtimePropertyName(property.name) === null,
  )) return null;
  const matches = node.properties.filter(
    (property) => ts.isPropertyAssignment(property)
      && runtimePropertyName(property.name) === propertyName,
  );
  return matches.length === 1 ? matches[0].initializer : null;
}

function runtimeObjectHasExactKeys(objectNode, keys) {
  const node = unwrapRuntimeExpression(objectNode);
  if (!node || !ts.isObjectLiteralExpression(node)) return false;
  const actual = [];
  for (const property of node.properties) {
    if (!ts.isPropertyAssignment(property)) return false;
    const name = runtimePropertyName(property.name);
    if (name === null) return false;
    actual.push(name);
  }
  return actual.length === keys.length
    && [...actual].sort().every((name, index) => name === [...keys].sort()[index]);
}

function runtimeExpressionPath(expression) {
  const node = unwrapRuntimeExpression(expression);
  if (!node) return null;
  if (ts.isIdentifier(node)) return [node.text];
  if (!ts.isPropertyAccessExpression(node)) return null;
  const parent = runtimeExpressionPath(node.expression);
  return parent ? [...parent, node.name.text] : null;
}

function runtimePathEquals(expression, expected) {
  const actual = runtimeExpressionPath(expression);
  return actual !== null
    && actual.length === expected.length
    && actual.every((part, index) => part === expected[index]);
}

function runtimeLiteralValue(expression) {
  const node = unwrapRuntimeExpression(expression);
  if (!node) return { found: false };
  if (ts.isStringLiteral(node) || ts.isNoSubstitutionTemplateLiteral(node)) {
    return { found: true, value: node.text };
  }
  if (ts.isNumericLiteral(node)) return { found: true, value: Number(node.text) };
  if (node.kind === ts.SyntaxKind.TrueKeyword) return { found: true, value: true };
  if (node.kind === ts.SyntaxKind.FalseKeyword) return { found: true, value: false };
  return { found: false };
}

function runtimeScenarioLiteralPath(scenario) {
  const value = runtimeLiteralValue(scenario.pathNode);
  return value.found && typeof value.value === 'string' ? value.value : null;
}

function runtimeScenarioMethod(scenario) {
  if (!scenario.optionsNode) return 'GET';
  const options = unwrapRuntimeExpression(scenario.optionsNode);
  if (!options || !ts.isObjectLiteralExpression(options)) return null;
  if (options.properties.some(
    (property) => !ts.isPropertyAssignment(property)
      || runtimePropertyName(property.name) === null,
  )) return null;
  const methodProperties = options.properties.filter(
    (property) => ts.isPropertyAssignment(property)
      && runtimePropertyName(property.name) === 'method',
  );
  if (methodProperties.length === 0) return 'GET';
  if (methodProperties.length !== 1) return null;
  const value = runtimeLiteralValue(methodProperties[0].initializer);
  return value.found && typeof value.value === 'string' ? value.value : null;
}

function runtimeRequestBodyProperty(scenario, propertyName) {
  const body = runtimeObjectProperty(scenario.optionsNode, 'body');
  return runtimeObjectProperty(body, propertyName);
}

function runtimeMatchesStrictEquality(expression, expectedPath, expectedValue) {
  const node = unwrapRuntimeExpression(expression);
  if (
    !node
    || !ts.isBinaryExpression(node)
    || node.operatorToken.kind !== ts.SyntaxKind.EqualsEqualsEqualsToken
    || !runtimePathEquals(node.left, expectedPath)
  ) return false;
  const literal = runtimeLiteralValue(node.right);
  return literal.found && Object.is(literal.value, expectedValue);
}

function runtimeMatchesCall(expression, calleePath, argumentMatchers) {
  const node = unwrapRuntimeExpression(expression);
  if (
    !node
    || !ts.isCallExpression(node)
    || !runtimePathEquals(node.expression, calleePath)
    || node.arguments.length !== argumentMatchers.length
  ) return false;
  return argumentMatchers.every((matcher, index) => matcher(node.arguments[index]));
}

function runtimeMatchesNegatedCall(expression, calleePath, argumentMatchers) {
  const node = unwrapRuntimeExpression(expression);
  return Boolean(
    node
    && ts.isPrefixUnaryExpression(node)
    && node.operator === ts.SyntaxKind.ExclamationToken
    && runtimeMatchesCall(node.operand, calleePath, argumentMatchers),
  );
}

function runtimeConjunctionAtoms(expression) {
  const node = unwrapRuntimeExpression(expression);
  if (!node) return null;
  if (ts.isConditionalExpression(node)) return null;
  if (ts.isBinaryExpression(node)) {
    if (node.operatorToken.kind === ts.SyntaxKind.BarBarToken) return null;
    if (node.operatorToken.kind === ts.SyntaxKind.AmpersandAmpersandToken) {
      const left = runtimeConjunctionAtoms(node.left);
      const right = runtimeConjunctionAtoms(node.right);
      return left && right ? [...left, ...right] : null;
    }
  }
  return [node];
}

function runtimeMatchesExactConjunction(expression, matchers) {
  const atoms = runtimeConjunctionAtoms(expression);
  if (!atoms || atoms.length !== matchers.length) return false;
  const unmatched = [...atoms];
  for (const matcher of matchers) {
    const index = unmatched.findIndex((atom) => matcher(atom));
    if (index === -1) return false;
    unmatched.splice(index, 1);
  }
  return unmatched.length === 0;
}

function runtimeScenarioHasCheck(scenario, matchers) {
  return scenario.checks.some(
    (expression) => runtimeMatchesExactConjunction(expression, matchers),
  );
}

function runtimeHasDirectAwaitedCall(statement, calleePath) {
  if (!ts.isExpressionStatement(statement)) return false;
  const expression = unwrapRuntimeExpression(statement.expression);
  return Boolean(
    expression
    && ts.isAwaitExpression(expression)
    && ts.isCallExpression(expression.expression)
    && expression.expression.arguments.length === 0
    && runtimePathEquals(expression.expression.expression, calleePath),
  );
}

function runtimeBindingNameContains(bindingName, identifierName) {
  if (ts.isIdentifier(bindingName)) return bindingName.text === identifierName;
  if (!ts.isObjectBindingPattern(bindingName) && !ts.isArrayBindingPattern(bindingName)) {
    return false;
  }
  return bindingName.elements.some(
    (element) => ts.isBindingElement(element)
      && runtimeBindingNameContains(element.name, identifierName),
  );
}

function runtimeBindingDeclarations(root, identifierName) {
  const bindings = [];
  const visit = (node) => {
    if (
      (ts.isVariableDeclaration(node) || ts.isParameter(node))
      && runtimeBindingNameContains(node.name, identifierName)
    ) {
      bindings.push(node);
    } else if (
      (
        ts.isFunctionDeclaration(node)
        || ts.isFunctionExpression(node)
        || ts.isClassDeclaration(node)
        || ts.isClassExpression(node)
      )
      && node.name?.text === identifierName
    ) {
      bindings.push(node);
    }
    ts.forEachChild(node, visit);
  };
  visit(root);
  return bindings;
}

function runtimeAssignmentTargetContains(target, identifierName) {
  const node = unwrapRuntimeExpression(target);
  if (!node) return false;
  if (ts.isIdentifier(node)) return node.text === identifierName;
  if (ts.isSpreadElement(node) || ts.isSpreadAssignment(node)) {
    return runtimeAssignmentTargetContains(node.expression, identifierName);
  }
  if (ts.isArrayLiteralExpression(node)) {
    return node.elements.some(
      (element) => !ts.isOmittedExpression(element)
        && runtimeAssignmentTargetContains(element, identifierName),
    );
  }
  if (ts.isObjectLiteralExpression(node)) {
    return node.properties.some((property) => {
      if (ts.isShorthandPropertyAssignment(property)) {
        return property.name.text === identifierName;
      }
      if (ts.isPropertyAssignment(property)) {
        return runtimeAssignmentTargetContains(property.initializer, identifierName);
      }
      if (ts.isSpreadAssignment(property)) {
        return runtimeAssignmentTargetContains(property.expression, identifierName);
      }
      return false;
    });
  }
  if (
    ts.isBinaryExpression(node)
    && node.operatorToken.kind === ts.SyntaxKind.EqualsToken
  ) return runtimeAssignmentTargetContains(node.left, identifierName);
  return false;
}

function runtimeIsAssignmentOperator(kind) {
  return kind >= ts.SyntaxKind.FirstAssignment && kind <= ts.SyntaxKind.LastAssignment;
}

function runtimeBindingMutations(root, identifierName) {
  const mutations = [];
  const visit = (node) => {
    if (
      ts.isBinaryExpression(node)
      && runtimeIsAssignmentOperator(node.operatorToken.kind)
      && runtimeAssignmentTargetContains(node.left, identifierName)
    ) {
      mutations.push(node);
    } else if (
      (ts.isPrefixUnaryExpression(node) || ts.isPostfixUnaryExpression(node))
      && (
        node.operator === ts.SyntaxKind.PlusPlusToken
        || node.operator === ts.SyntaxKind.MinusMinusToken
      )
      && runtimeAssignmentTargetContains(node.operand, identifierName)
    ) {
      mutations.push(node);
    } else if (
      (ts.isForInStatement(node) || ts.isForOfStatement(node))
      && !ts.isVariableDeclarationList(node.initializer)
      && runtimeAssignmentTargetContains(node.initializer, identifierName)
    ) {
      mutations.push(node);
    }
    ts.forEachChild(node, visit);
  };
  visit(root);
  return mutations;
}

function assertRuntimeHasNoDirectEval(contract) {
  const directEvalCalls = [];
  const visit = (node) => {
    if (
      ts.isCallExpression(node)
      && ts.isIdentifier(unwrapRuntimeExpression(node.expression))
      && unwrapRuntimeExpression(node.expression).text === 'eval'
    ) directEvalCalls.push(node);
    ts.forEachChild(node, visit);
  };
  visit(contract.sourceFile);
  assert.equal(
    directEvalCalls.length,
    0,
    'direct eval is forbidden in the protected source because it can dynamically mutate bindings',
  );
}

function runtimeSoleTopLevelAsyncFunction(contract, functionName) {
  const bindings = runtimeBindingDeclarations(contract.sourceFile, functionName);
  assert.equal(
    bindings.length,
    1,
    `${functionName} must be the sole source binding in the credential chain`,
  );
  const declaration = bindings[0];
  assert.ok(
    ts.isFunctionDeclaration(declaration)
      && declaration.name?.text === functionName
      && declaration.parent === contract.sourceFile
      && declaration.body
      && declaration.modifiers?.some(
        (modifier) => modifier.kind === ts.SyntaxKind.AsyncKeyword,
      ),
    `${functionName} must be one top-level async function declaration`,
  );
  assert.equal(
    runtimeBindingMutations(contract.sourceFile, functionName).length,
    0,
    `${functionName} must not be reassigned anywhere in the credential chain`,
  );
  return declaration;
}

function assertRuntimeCredentialChain(contract) {
  const createFunction = runtimeSoleTopLevelAsyncFunction(
    contract,
    'createLocalSmokeAdmin',
  );
  const resolveFunction = runtimeSoleTopLevelAsyncFunction(
    contract,
    'resolveCredentials',
  );
  assert.equal(
    resolveFunction.parameters.length,
    0,
    'resolveCredentials must take no parameters in the credential chain',
  );
  assert.equal(
    resolveFunction.body.statements.length,
    1,
    'resolveCredentials must contain only the createLocalSmokeAdmin return',
  );
  const resolveReturn = resolveFunction.body.statements[0];
  assert.ok(
    ts.isReturnStatement(resolveReturn)
      && resolveReturn.expression
      && runtimeMatchesCall(resolveReturn.expression, ['createLocalSmokeAdmin'], []),
    'resolveCredentials must return createLocalSmokeAdmin() directly',
  );

  const runFunction = runtimeSoleTopLevelAsyncFunction(contract, 'run');
  assert.equal(runFunction.parameters.length, 0, 'run() must take no parameters');
  assert.equal(
    runtimeFunctionOwnReturns(runFunction).length,
    0,
    'run() must not return early before the complete journey finishes',
  );
  const firstStatement = runFunction.body.statements[0];
  assert.ok(
    firstStatement
      && ts.isExpressionStatement(firstStatement)
      && ts.isBinaryExpression(firstStatement.expression)
      && firstStatement.expression.operatorToken.kind === ts.SyntaxKind.EqualsToken
      && runtimePathEquals(firstStatement.expression.left, ['smokeCredentials'])
      && ts.isAwaitExpression(firstStatement.expression.right)
      && runtimeMatchesCall(
        firstStatement.expression.right.expression,
        ['resolveCredentials'],
        [],
      ),
    'run() must begin by awaiting resolveCredentials() into smokeCredentials',
  );
  return { createFunction, runFunction };
}

function assertRuntimeSupportHelperBindingSafety(contract) {
  const helperName = 'setSmokeAdminRoleToSupport';
  const bindings = runtimeBindingDeclarations(contract.sourceFile, helperName);
  assert.equal(
    bindings.length,
    1,
    'the outer SUPPORT helper must be the sole binding; local shadow bindings are forbidden',
  );
  const declaration = bindings[0];
  assert.ok(
    ts.isVariableDeclaration(declaration)
      && ts.isIdentifier(declaration.name)
      && declaration.name.text === helperName
      && ts.isVariableDeclarationList(declaration.parent)
      && declaration.parent.declarations.length === 1
      && Boolean(declaration.parent.flags & ts.NodeFlags.Let)
      && ts.isVariableStatement(declaration.parent.parent)
      && ts.isSourceFile(declaration.parent.parent.parent),
    'the sole SUPPORT helper binding must be one top-level let declaration',
  );
  const initializer = unwrapRuntimeExpression(declaration.initializer);
  assert.ok(
    initializer
      && ts.isArrowFunction(initializer)
      && initializer.modifiers?.some(
        (modifier) => modifier.kind === ts.SyntaxKind.AsyncKeyword,
      )
      && ts.isBlock(initializer.body)
      && initializer.body.statements.length === 0,
    'the outer SUPPORT helper must begin as the explicit async no-op lifecycle binding',
  );

  assert.ok(contract.runFunction, 'admin runtime smoke must expose run()');
  assert.equal(
    runtimeBindingMutations(contract.runFunction, helperName).length,
    0,
    'run() must not reassign or mutate the outer SUPPORT helper binding',
  );
}

function runtimeIsFunctionBoundary(node) {
  return ts.isFunctionDeclaration(node)
    || ts.isFunctionExpression(node)
    || ts.isArrowFunction(node)
    || ts.isMethodDeclaration(node)
    || ts.isGetAccessorDeclaration(node)
    || ts.isSetAccessorDeclaration(node)
    || ts.isConstructorDeclaration(node);
}

function runtimeFunctionOwnReturns(functionDeclaration) {
  const returns = [];
  const visit = (node) => {
    if (node !== functionDeclaration.body && runtimeIsFunctionBoundary(node)) return;
    if (ts.isReturnStatement(node)) returns.push(node);
    ts.forEachChild(node, visit);
  };
  visit(functionDeclaration.body);
  return returns;
}

function runtimeIsSuccessfulCredentialReturn(returnStatement) {
  if (!returnStatement.expression) return false;
  const payload = unwrapRuntimeExpression(returnStatement.expression);
  if (!payload || !ts.isObjectLiteralExpression(payload) || payload.properties.length !== 3) {
    return false;
  }
  const [phone, password, source] = payload.properties;
  const sourceValue = ts.isPropertyAssignment(source)
    && runtimePropertyName(source.name) === 'source'
    ? runtimeLiteralValue(source.initializer)
    : { found: false };
  return ts.isShorthandPropertyAssignment(phone)
    && phone.name.text === 'phone'
    && !phone.objectAssignmentInitializer
    && ts.isShorthandPropertyAssignment(password)
    && password.name.text === 'password'
    && !password.objectAssignmentInitializer
    && sourceValue.found
    && sourceValue.value === 'temporary local smoke admin';
}

function assertRuntimeSupportRoleTransition(contract, createFunction) {
  const assignments = [];
  const visit = (node) => {
    if (
      ts.isBinaryExpression(node)
      && node.operatorToken.kind === ts.SyntaxKind.EqualsToken
      && ts.isIdentifier(node.left)
      && node.left.text === 'setSmokeAdminRoleToSupport'
    ) assignments.push(node);
    ts.forEachChild(node, visit);
  };
  visit(contract.sourceFile);
  assert.equal(
    assignments.length,
    1,
    'SUPPORT role transition must have one concrete helper assignment',
  );
  const assignment = assignments[0];
  const assignmentStatement = assignment.parent;
  assert.ok(
    ts.isExpressionStatement(assignmentStatement)
      && ts.isBlock(assignmentStatement.parent)
      && ts.isTryStatement(assignmentStatement.parent.parent)
      && assignmentStatement.parent.parent.tryBlock === assignmentStatement.parent
      && assignmentStatement.parent.parent.parent === createFunction.body,
    'SUPPORT role transition assignment must be a direct try statement in createLocalSmokeAdmin control flow',
  );
  const tryBlock = assignmentStatement.parent;
  const ownReturns = runtimeFunctionOwnReturns(createFunction);
  assert.equal(
    ownReturns.length,
    1,
    'createLocalSmokeAdmin must have exactly one successful return outside nested functions',
  );
  const successfulReturn = ownReturns[0];
  assert.ok(
    successfulReturn.parent === tryBlock
      && runtimeIsSuccessfulCredentialReturn(successfulReturn),
    'the only successful return must directly exit the assignment try block with local credentials',
  );
  assert.ok(
    tryBlock.statements.indexOf(assignmentStatement) >= 0
      && tryBlock.statements.indexOf(assignmentStatement)
        < tryBlock.statements.indexOf(successfulReturn),
    'SUPPORT role transition assignment must execute before the successful return',
  );

  const helper = unwrapRuntimeExpression(assignment.right);
  assert.ok(
    helper
      && ts.isArrowFunction(helper)
      && helper.modifiers?.some((modifier) => modifier.kind === ts.SyntaxKind.AsyncKeyword)
      && ts.isBlock(helper.body),
    'SUPPORT role transition must be an async block helper',
  );
  assert.equal(
    helper.body.statements.length,
    1,
    'SUPPORT role transition helper must contain only the awaited owner update',
  );
  const statement = helper.body.statements[0];
  assert.ok(
    ts.isExpressionStatement(statement)
      && ts.isAwaitExpression(statement.expression)
      && ts.isCallExpression(statement.expression.expression),
    'SUPPORT role transition must await prisma.user.update',
  );
  const call = statement.expression.expression;
  assert.ok(
    runtimePathEquals(call.expression, ['prisma', 'user', 'update'])
      && call.arguments.length === 1,
    'SUPPORT role transition must call prisma.user.update exactly once',
  );
  const payload = call.arguments[0];
  assert.ok(
    runtimeObjectHasExactKeys(payload, ['where', 'data']),
    'SUPPORT role transition update must contain only where and data',
  );
  const where = runtimeObjectProperty(payload, 'where');
  const data = runtimeObjectProperty(payload, 'data');
  assert.ok(
    runtimeObjectHasExactKeys(where, ['id'])
      && runtimePathEquals(runtimeObjectProperty(where, 'id'), ['user', 'id']),
    'SUPPORT role transition must target the disposable identity user.id',
  );
  assert.ok(
    runtimeObjectHasExactKeys(data, ['adminRole'])
      && runtimePathEquals(runtimeObjectProperty(data, 'adminRole'), ['AdminRole', 'SUPPORT']),
    'SUPPORT role transition must assign AdminRole.SUPPORT',
  );
  return { tryBlock, assignmentStatement };
}

function runtimeTopLevelNoopLet(contract, bindingName) {
  const bindings = runtimeBindingDeclarations(contract.sourceFile, bindingName);
  assert.equal(
    bindings.length,
    1,
    `${bindingName} must be the sole cleanup binding`,
  );
  const declaration = bindings[0];
  assert.ok(
    ts.isVariableDeclaration(declaration)
      && ts.isIdentifier(declaration.name)
      && declaration.name.text === bindingName
      && ts.isVariableDeclarationList(declaration.parent)
      && declaration.parent.declarations.length === 1
      && Boolean(declaration.parent.flags & ts.NodeFlags.Let)
      && ts.isVariableStatement(declaration.parent.parent)
      && declaration.parent.parent.parent === contract.sourceFile,
    `${bindingName} must be one top-level lifecycle let`,
  );
  const initializer = unwrapRuntimeExpression(declaration.initializer);
  assert.ok(
    initializer
      && ts.isArrowFunction(initializer)
      && initializer.modifiers?.some(
        (modifier) => modifier.kind === ts.SyntaxKind.AsyncKeyword,
      )
      && ts.isBlock(initializer.body)
      && initializer.body.statements.length === 0,
    `${bindingName} must begin as the explicit async no-op lifecycle binding`,
  );
}

function runtimeDirectAwaitedCall(statement, calleePath, argumentCount) {
  if (!ts.isExpressionStatement(statement)) return null;
  const expression = unwrapRuntimeExpression(statement.expression);
  if (!expression || !ts.isAwaitExpression(expression)) return null;
  const call = unwrapRuntimeExpression(expression.expression);
  return call
    && ts.isCallExpression(call)
    && runtimePathEquals(call.expression, calleePath)
    && call.arguments.length === argumentCount
    ? call
    : null;
}

function assertRuntimeCleanupLifecycle(contract, supportPlacement) {
  const cleanupName = 'cleanupSmokeAdmin';
  runtimeTopLevelNoopLet(contract, cleanupName);
  const assignments = runtimeBindingMutations(contract.sourceFile, cleanupName)
    .filter((node) => (
      ts.isBinaryExpression(node)
      && node.operatorToken.kind === ts.SyntaxKind.EqualsToken
      && ts.isIdentifier(node.left)
      && node.left.text === cleanupName
    ));
  assert.equal(
    assignments.length,
    1,
    'cleanupSmokeAdmin must have one concrete cleanup assignment',
  );
  const assignment = assignments[0];
  const statement = assignment.parent;
  assert.ok(
    ts.isExpressionStatement(statement)
      && statement.parent === supportPlacement.tryBlock
      && supportPlacement.tryBlock.statements.indexOf(statement) >= 0
      && supportPlacement.tryBlock.statements.indexOf(statement)
        < supportPlacement.tryBlock.statements.indexOf(supportPlacement.assignmentStatement),
    'cleanup assignment must be a direct factory try statement before the SUPPORT assignment',
  );
  const helper = unwrapRuntimeExpression(assignment.right);
  assert.ok(
    helper
      && ts.isArrowFunction(helper)
      && helper.modifiers?.some(
        (modifier) => modifier.kind === ts.SyntaxKind.AsyncKeyword,
      )
      && ts.isBlock(helper.body),
    'cleanupSmokeAdmin assignment must be an async cleanup block',
  );
  const expectedCalls = [
    [['prisma', 'adminLoginChallenge', 'deleteMany'], 1],
    [['prisma', 'refreshToken', 'deleteMany'], 1],
    [['prisma', 'otpCode', 'deleteMany'], 1],
    [['prisma', 'user', 'deleteMany'], 1],
    [['prisma', '$disconnect'], 0],
  ];
  assert.equal(
    helper.body.statements.length,
    expectedCalls.length,
    'cleanupSmokeAdmin must retain the complete disposable cleanup sequence',
  );
  expectedCalls.forEach(([calleePath, argumentCount], index) => {
    assert.ok(
      runtimeDirectAwaitedCall(
        helper.body.statements[index],
        calleePath,
        argumentCount,
      ),
      `cleanupSmokeAdmin cleanup step ${index + 1} must remain direct and awaited`,
    );
  });
}

function runtimeConsoleCall(statement, methodName) {
  if (!ts.isExpressionStatement(statement)) return null;
  const expression = unwrapRuntimeExpression(statement.expression);
  return expression
    && ts.isCallExpression(expression)
    && runtimePathEquals(expression.expression, ['console', methodName])
    ? expression
    : null;
}

function assertRuntimeRunEpilogue(runFunction) {
  const statements = [...runFunction.body.statements];
  assert.ok(statements.length >= 3, 'run() must retain its failure epilogue');
  const failedStatement = statements.at(-3);
  assert.ok(
    ts.isVariableStatement(failedStatement)
      && Boolean(failedStatement.declarationList.flags & ts.NodeFlags.Const)
      && failedStatement.declarationList.declarations.length === 1,
    'run() epilogue must calculate failed as one const declaration',
  );
  const failedDeclaration = failedStatement.declarationList.declarations[0];
  const filterCall = unwrapRuntimeExpression(failedDeclaration.initializer);
  assert.ok(
    ts.isIdentifier(failedDeclaration.name)
      && failedDeclaration.name.text === 'failed'
      && filterCall
      && ts.isCallExpression(filterCall)
      && runtimePathEquals(filterCall.expression, ['checks', 'filter'])
      && filterCall.arguments.length === 1,
    'run() epilogue must calculate failed from checks.filter',
  );
  const predicate = unwrapRuntimeExpression(filterCall.arguments[0]);
  assert.ok(
    predicate
      && ts.isArrowFunction(predicate)
      && predicate.parameters.length === 1
      && ts.isIdentifier(predicate.parameters[0].name)
      && predicate.parameters[0].name.text === 'item'
      && ts.isPrefixUnaryExpression(unwrapRuntimeExpression(predicate.body))
      && unwrapRuntimeExpression(predicate.body).operator === ts.SyntaxKind.ExclamationToken
      && runtimePathEquals(
        unwrapRuntimeExpression(predicate.body).operand,
        ['item', 'passed'],
      ),
    'run() failed filter must retain the exact item.passed predicate',
  );

  const resultLog = runtimeConsoleCall(statements.at(-2), 'log');
  const resultTemplate = resultLog?.arguments[0];
  assert.ok(
    resultLog
      && resultLog.arguments.length === 1
      && resultTemplate
      && ts.isTemplateExpression(resultTemplate)
      && resultTemplate.head.text === '\nOverall Result: '
      && resultTemplate.templateSpans.length === 1,
    'run() epilogue must print the exact overall result template',
  );
  const resultSpan = resultTemplate.templateSpans[0];
  const resultCondition = unwrapRuntimeExpression(resultSpan.expression);
  assert.ok(
    resultSpan.literal.text === ''
      && resultCondition
      && ts.isConditionalExpression(resultCondition)
      && runtimePathEquals(resultCondition.condition, ['failed', 'length'])
      && runtimeLiteralValue(resultCondition.whenTrue).value === 'FAIL'
      && runtimeLiteralValue(resultCondition.whenFalse).value === 'PASS',
    'run() result log must derive FAIL or PASS from failed.length',
  );

  const exitIf = statements.at(-1);
  assert.ok(
    ts.isIfStatement(exitIf)
      && runtimePathEquals(exitIf.expression, ['failed', 'length'])
      && !exitIf.elseStatement
      && ts.isExpressionStatement(exitIf.thenStatement),
    'run() may exit only from the final failed.length guard',
  );
  const exitCall = unwrapRuntimeExpression(exitIf.thenStatement.expression);
  assert.ok(
    exitCall
      && ts.isCallExpression(exitCall)
      && runtimePathEquals(exitCall.expression, ['process', 'exit'])
      && exitCall.arguments.length === 1
      && runtimeLiteralValue(exitCall.arguments[0]).value === 1,
    'the final run failure guard must call exact process.exit(1)',
  );
  return exitCall;
}

function assertRuntimeBootstrap(contract) {
  const bootstrapStatement = contract.sourceFile.statements.at(-1);
  assert.ok(
    ts.isExpressionStatement(bootstrapStatement)
      && ts.isCallExpression(unwrapRuntimeExpression(bootstrapStatement.expression)),
    'the bootstrap must be the final top-level expression',
  );
  const finallyCall = unwrapRuntimeExpression(bootstrapStatement.expression);
  assert.ok(
    ts.isPropertyAccessExpression(finallyCall.expression)
      && finallyCall.expression.name.text === 'finally'
      && finallyCall.arguments.length === 1,
    'the bootstrap must end with one direct finally handler',
  );
  const catchCall = unwrapRuntimeExpression(finallyCall.expression.expression);
  assert.ok(
    catchCall
      && ts.isCallExpression(catchCall)
      && ts.isPropertyAccessExpression(catchCall.expression)
      && catchCall.expression.name.text === 'catch'
      && catchCall.arguments.length === 1,
    'the bootstrap must contain one direct catch handler before finally',
  );
  const runCall = unwrapRuntimeExpression(catchCall.expression.expression);
  assert.ok(
    runCall
      && ts.isCallExpression(runCall)
      && runtimePathEquals(runCall.expression, ['run'])
      && runCall.arguments.length === 0,
    'the bootstrap must start from direct run()',
  );
  const runCalls = [];
  const cleanupCalls = [];
  const visitCalls = (node) => {
    if (ts.isCallExpression(node) && runtimePathEquals(node.expression, ['run'])) {
      runCalls.push(node);
    }
    if (ts.isCallExpression(node) && runtimePathEquals(node.expression, ['cleanupSmokeAdmin'])) {
      cleanupCalls.push(node);
    }
    ts.forEachChild(node, visitCalls);
  };
  visitCalls(contract.sourceFile);
  assert.equal(runCalls.length, 1, 'the bootstrap must contain the only run() call');
  assert.equal(runCalls[0], runCall, 'the only run() call must be the final bootstrap root');

  const catchHandler = unwrapRuntimeExpression(catchCall.arguments[0]);
  assert.ok(
    catchHandler
      && ts.isArrowFunction(catchHandler)
      && catchHandler.parameters.length === 1
      && ts.isIdentifier(catchHandler.parameters[0].name)
      && catchHandler.parameters[0].name.text === 'error'
      && ts.isBlock(catchHandler.body)
      && catchHandler.body.statements.length === 3,
    'the bootstrap catch handler must keep its exact error lifecycle',
  );
  const failLog = runtimeConsoleCall(catchHandler.body.statements[0], 'error');
  assert.ok(
    failLog
      && failLog.arguments.length === 1
      && runtimeLiteralValue(failLog.arguments[0]).value === '\nOverall Result: FAIL',
    'the bootstrap catch handler must log the overall FAIL result',
  );
  const detailLog = runtimeConsoleCall(catchHandler.body.statements[1], 'error');
  const detail = detailLog?.arguments[0];
  assert.ok(
    detailLog
      && detailLog.arguments.length === 1
      && detail
      && ts.isConditionalExpression(unwrapRuntimeExpression(detail)),
    'the bootstrap catch handler must log the normalized error detail',
  );
  const detailCondition = unwrapRuntimeExpression(detail);
  assert.ok(
    ts.isBinaryExpression(detailCondition.condition)
      && detailCondition.condition.operatorToken.kind === ts.SyntaxKind.InstanceOfKeyword
      && runtimePathEquals(detailCondition.condition.left, ['error'])
      && runtimePathEquals(detailCondition.condition.right, ['Error'])
      && runtimePathEquals(detailCondition.whenTrue, ['error', 'message'])
      && runtimeMatchesCall(
        detailCondition.whenFalse,
        ['String'],
        [(argument) => runtimePathEquals(argument, ['error'])],
      ),
    'the bootstrap catch handler must preserve Error message normalization',
  );
  const exitCodeStatement = catchHandler.body.statements[2];
  assert.ok(
    ts.isExpressionStatement(exitCodeStatement)
      && ts.isBinaryExpression(exitCodeStatement.expression)
      && exitCodeStatement.expression.operatorToken.kind === ts.SyntaxKind.EqualsToken
      && runtimePathEquals(exitCodeStatement.expression.left, ['process', 'exitCode'])
      && runtimeLiteralValue(exitCodeStatement.expression.right).value === 1,
    'the bootstrap catch handler must set process.exitCode to 1',
  );

  const finallyHandler = unwrapRuntimeExpression(finallyCall.arguments[0]);
  assert.ok(
    finallyHandler
      && ts.isArrowFunction(finallyHandler)
      && finallyHandler.modifiers?.some(
        (modifier) => modifier.kind === ts.SyntaxKind.AsyncKeyword,
      )
      && finallyHandler.parameters.length === 0
      && ts.isBlock(finallyHandler.body)
      && finallyHandler.body.statements.length === 1
      && runtimeDirectAwaitedCall(
        finallyHandler.body.statements[0],
        ['cleanupSmokeAdmin'],
        0,
      ),
    'the bootstrap finally handler must directly await cleanupSmokeAdmin()',
  );
  assert.equal(cleanupCalls.length, 1, 'the bootstrap must contain the only cleanup call');
  return { exitCodeReference: exitCodeStatement.expression.left };
}

function runtimeIsProcessRoot(expression) {
  return runtimePathEquals(expression, ['process'])
    || runtimePathEquals(expression, ['globalThis', 'process'])
    || runtimePathEquals(expression, ['global', 'process']);
}

function assertRuntimeProcessPolicy(
  contract,
  allowedExitCall,
  allowedExitCodeReference,
) {
  const directMembers = [];
  const computedMembers = [];
  const aliases = [];
  const visit = (node) => {
    if (
      ts.isPropertyAccessExpression(node)
      && ts.isIdentifier(unwrapRuntimeExpression(node.expression))
      && unwrapRuntimeExpression(node.expression).text === 'process'
    ) directMembers.push(node);
    if (
      ts.isElementAccessExpression(node)
      && ts.isIdentifier(unwrapRuntimeExpression(node.expression))
      && unwrapRuntimeExpression(node.expression).text === 'process'
    ) computedMembers.push(node);
    if (
      (ts.isVariableDeclaration(node) || ts.isParameter(node))
      && node.initializer
      && runtimeIsProcessRoot(node.initializer)
    ) aliases.push(node);
    if (
      ts.isBinaryExpression(node)
      && runtimeIsAssignmentOperator(node.operatorToken.kind)
      && runtimeIsProcessRoot(node.right)
    ) aliases.push(node);
    ts.forEachChild(node, visit);
  };
  visit(contract.sourceFile);
  assert.equal(computedMembers.length, 0, 'computed process members are forbidden by exit policy');
  assert.equal(aliases.length, 0, 'process aliases are forbidden by exit policy');
  const allowedMembers = new Set(['env', 'exit', 'exitCode']);
  const forbiddenMembers = directMembers.filter(
    (member) => !allowedMembers.has(member.name.text),
  );
  assert.equal(
    forbiddenMembers.length,
    0,
    'every direct process member must satisfy the exact exit policy',
  );
  const exitReferences = directMembers.filter((member) => member.name.text === 'exit');
  assert.equal(exitReferences.length, 1, 'process.exit policy allows one exact reference');
  assert.equal(
    exitReferences[0],
    allowedExitCall.expression,
    'the only process.exit reference must be the final process.exit(1)',
  );
  const exitCodeReferences = directMembers.filter(
    (member) => member.name.text === 'exitCode',
  );
  assert.equal(exitCodeReferences.length, 1, 'process.exitCode policy allows one exact reference');
  assert.equal(
    exitCodeReferences[0],
    allowedExitCodeReference,
    'the only process.exitCode reference must be the bootstrap catch assignment',
  );
}

function runtimeIsMissingCatalogPath(expression) {
  const node = unwrapRuntimeExpression(expression);
  if (!node || !ts.isTemplateExpression(node) || node.templateSpans.length !== 1) return false;
  const span = node.templateSpans[0];
  return node.head.text === '/admin/reference-catalogs/'
    && span.literal.text === ''
    && runtimeMatchesCall(
      span.expression,
      ['encodeURIComponent'],
      [(argument) => runtimePathEquals(argument, ['missingCatalogKey'])],
    );
}

function assertRuntimeSmokeTask8Coverage(sourceText) {
  const contract = runtimeSmokeSourceContract(sourceText);
  assertRuntimeHasNoDirectEval(contract);
  assertRuntimeSupportHelperBindingSafety(contract);
  const { createFunction, runFunction } = assertRuntimeCredentialChain(contract);
  const supportPlacement = assertRuntimeSupportRoleTransition(contract, createFunction);
  assertRuntimeCleanupLifecycle(contract, supportPlacement);
  const allowedExitCall = assertRuntimeRunEpilogue(runFunction);
  const { exitCodeReference } = assertRuntimeBootstrap(contract);
  assertRuntimeProcessPolicy(contract, allowedExitCall, exitCodeReference);
  const loginScenarios = contract.scenarios.filter(
    (scenario) => runtimeScenarioLiteralPath(scenario) === '/api/v1/auth/admin/login'
      && runtimeScenarioMethod(scenario) === 'POST'
      && runtimePathEquals(
        runtimeRequestBodyProperty(scenario, 'phone'),
        ['smokeCredentials', 'phone'],
      )
      && runtimePathEquals(
        runtimeRequestBodyProperty(scenario, 'password'),
        ['smokeCredentials', 'password'],
      ),
  );
  assert.equal(loginScenarios.length, 2, 'the disposable identity must perform two password logins');

  const revokedScenario = contract.scenarios.findLast(
    (scenario) => runtimeScenarioLiteralPath(scenario) === '/admin/dashboard/stats'
      && runtimeScenarioMethod(scenario) === 'GET'
      && runtimeScenarioHasCheck(scenario, [
        (atom) => runtimeMatchesStrictEquality(atom, ['res', 'status'], 401),
      ]),
  );
  assert.ok(revokedScenario, 'the first access session must be proven revoked');
  const freshLogin = loginScenarios.find(({ index }) => index > revokedScenario.index);
  assert.ok(freshLogin, 'fresh password login must occur after revocation');
  assert.ok(
    contract.statements
      .slice(revokedScenario.index + 1, freshLogin.index)
      .some((statement) => runtimeHasDirectAwaitedCall(
        statement,
        ['setSmokeAdminRoleToSupport'],
      )),
    'the concrete SUPPORT role transition must be awaited directly after revocation',
  );

  const freshMfa = contract.scenarios.find(
    (scenario) => scenario.index > freshLogin.index
      && runtimeScenarioLiteralPath(scenario) === '/api/v1/auth/admin/login/complete'
      && runtimeScenarioMethod(scenario) === 'POST'
      && runtimePathEquals(
        runtimeRequestBodyProperty(scenario, 'challengeToken'),
        ['restrictedChallengeToken'],
      )
      && runtimePathEquals(
        runtimeRequestBodyProperty(scenario, 'code'),
        ['restrictedOtpCode'],
      )
      && runtimeScenarioHasCheck(scenario, [
        (atom) => runtimeMatchesStrictEquality(atom, ['res', 'status'], 200),
        (atom) => runtimeMatchesStrictEquality(
          atom,
          ['res', 'body', 'user', 'adminRole'],
          'SUPPORT',
        ),
        (atom) => runtimeMatchesCall(
          atom,
          ['Array', 'isArray'],
          [(argument) => runtimePathEquals(
            argument,
            ['res', 'body', 'user', 'adminPermissions'],
          )],
        ),
        (atom) => runtimeMatchesCall(
          atom,
          ['res', 'body', 'user', 'adminPermissions', 'includes'],
          [(argument) => runtimeLiteralValue(argument).value === 'CATALOG_READ'],
        ),
        (atom) => runtimeMatchesNegatedCall(
          atom,
          ['res', 'body', 'user', 'adminPermissions', 'includes'],
          [(argument) => runtimeLiteralValue(argument).value === 'CATALOG_WRITE'],
        ),
      ]),
  );
  assert.ok(freshMfa, 'fresh MFA must prove the restricted SUPPORT permission set');

  const allowedRead = contract.scenarios.find(
    (scenario) => scenario.index > freshMfa.index
      && runtimeScenarioLiteralPath(scenario)
        === '/admin/reference-catalogs/money.starter.categories'
      && runtimeScenarioMethod(scenario) === 'GET'
      && runtimeScenarioHasCheck(scenario, [
        (atom) => runtimeMatchesStrictEquality(atom, ['res', 'status'], 200),
        (atom) => runtimeMatchesStrictEquality(
          atom,
          ['res', 'body', 'key'],
          'money.starter.categories',
        ),
      ]),
  );
  assert.ok(allowedRead, 'SUPPORT must prove an allowed catalog read');

  const deniedWrite = contract.scenarios.find(
    (scenario) => scenario.index > allowedRead.index
      && runtimeScenarioLiteralPath(scenario)
        === '/admin/reference-catalogs/money.starter.categories/items'
      && runtimeScenarioMethod(scenario) === 'POST'
      && runtimePathEquals(
        runtimeRequestBodyProperty(scenario, 'key'),
        ['restrictedWriteKey'],
      )
      && typeof runtimeLiteralValue(
        runtimeRequestBodyProperty(scenario, 'nameAr'),
      ).value === 'string'
      && runtimeScenarioHasCheck(scenario, [
        (atom) => runtimeMatchesStrictEquality(atom, ['res', 'status'], 403),
        (atom) => runtimeMatchesStrictEquality(atom, ['res', 'body', 'statusCode'], 403),
        (atom) => runtimeMatchesStrictEquality(
          atom,
          ['res', 'body', 'message'],
          'Admin permission is required',
        ),
      ]),
  );
  assert.ok(
    deniedWrite,
    'a valid catalog write must use the actual request method POST and propagate structured 403',
  );

  const missingRead = contract.scenarios.find(
    (scenario) => scenario.index > deniedWrite.index
      && runtimeIsMissingCatalogPath(scenario.pathNode)
      && runtimeScenarioMethod(scenario) === 'GET'
      && runtimeScenarioHasCheck(scenario, [
        (atom) => runtimeMatchesStrictEquality(atom, ['res', 'status'], 404),
        (atom) => runtimeMatchesStrictEquality(atom, ['res', 'body', 'statusCode'], 404),
        (atom) => runtimeMatchesStrictEquality(
          atom,
          ['res', 'body', 'message'],
          'Reference catalog not found',
        ),
      ]),
  );
  assert.ok(missingRead, 'a distinct authorized missing-key read must propagate the structured 404 body');
  assert.notEqual(missingRead.pathNode, deniedWrite.pathNode);
}

test('tracked R10 manifest freezes exact base hashes fates stages and sorted fence', () => {
  const raw = manifestValue();
  const manifest = boundaries.validateR10Manifest(raw);
  assert.equal(manifest.version, 1);
  assert.equal(manifest.phase, 'R10');
  assert.equal(manifest.base, 'e560e5784278907dd6bf565327c3abfa0c9b8cab');
  assert.equal(manifest.designSha256, '7abc4aecf3cfcceb4a6b601fcbe83377371a4aed58cb0cf06bce7a67d200f76e');
  assert.equal(manifest.adminRoutes.count, 22);
  assert.equal(manifest.requestInventory.count, 62);
  assert.equal(manifest.arabicLiteralInventory.count, 1020);
  assert.equal(manifest.sourceFates.length, 78);
  assert.deepEqual(manifest.publicSurfaces.catalog, [
    'AdministrativeLocality',
    'AdministrativeLocalityType',
    'AdministrativeLocationPayload',
    'CatalogPayload',
    'City',
    'District',
    'Governorate',
    'ProviderCategory',
    'ProviderService',
    'ReferenceCatalog',
    'ReferenceCatalogItem',
    'ReferenceCatalogItemPayload',
    'ReferenceCatalogRevision',
    'ReferenceCatalogSummary',
    'ServicePayload',
    'createCategory',
    'createCity',
    'createDistrict',
    'createGovernorate',
    'createLocality',
    'createReferenceCatalogItem',
    'createService',
    'deleteCategory',
    'deleteCity',
    'deleteService',
    'disableDistrict',
    'disableGovernorate',
    'disableLocality',
    'disableReferenceCatalogItem',
    'getCategories',
    'getCities',
    'getDistricts',
    'getGovernorates',
    'getLocalities',
    'getReferenceCatalog',
    'getReferenceCatalogs',
    'getServices',
    'publishReferenceCatalogItem',
    'updateCategory',
    'updateCity',
    'updateDistrict',
    'updateGovernorate',
    'updateLocality',
    'updateReferenceCatalogItem',
    'updateService',
  ]);
  assert.deepEqual(manifest.allowedChangedPaths, [...manifest.allowedChangedPaths].sort());
  assert.equal(new Set(manifest.allowedChangedPaths).size, manifest.allowedChangedPaths.length);
  assert.deepEqual(Object.keys(manifest.stages), [
    'task-1', 'task-2', 'task-3', 'task-4', 'task-5', 'task-6',
    'task-7', 'task-8', 'task-9', 'task-10', 'task-11', 'strict',
  ]);
  assert.doesNotMatch(JSON.stringify(raw), /[A-Za-z]:[\\/]|(?:PASSWORD|SECRET|TOKEN)\s*=/i);
});

test('manifest validation rejects wrong base design hash count order duplicates and unsafe paths', () => {
  const raw = manifestValue();
  const normalized = boundaries.validateR10Manifest(raw);
  const original = { ...raw, allowedChangedPaths: normalized.allowedChangedPaths };
  const clones = [
    { ...original, base: '0'.repeat(40) },
    { ...original, designSha256: '0'.repeat(64) },
    { ...original, requestInventory: { ...original.requestInventory, count: 61 } },
    { ...original, allowedFeatureEdges: { ...original.allowedFeatureEdges, audit: ['auth'] } },
    { ...original, appScreenAllowlist: [...original.appScreenAllowlist.slice(0, -1), 'features/users/OtherPage.tsx'].sort() },
    { ...original, publicSurfaces: { ...original.publicSurfaces, audit: [...original.publicSurfaces.audit, 'deleteAuditLog'] } },
    { ...original, sourceFates: [...original.sourceFates].reverse() },
    { ...original, sourceFates: [...original.sourceFates.slice(0, -1), original.sourceFates[0]] },
    { ...original, allowedChangedPaths: [...original.allowedChangedPaths].reverse() },
    { ...original, allowedChangedPaths: [...original.allowedChangedPaths.slice(0, -1), 'C:/secret.txt'].sort() },
    { ...original, allowedChangedPaths: [...original.allowedChangedPaths.slice(0, -1), '../secret.txt'].sort() },
    { ...original, allowedChangedPaths: [...original.allowedChangedPaths.slice(0, -1), 'scripts\\check-r10-scope.mjs'].sort() },
  ];
  for (const value of clones) assert.throws(() => boundaries.validateR10Manifest(value));
});

test('manifest validation rejects a missing Admin runtime smoke fingerprint', () => {
  const raw = { ...manifestValue(), adminRuntimeSmoke };
  delete raw.adminRuntimeSmoke;
  assert.throws(() => boundaries.validateR10Manifest(raw));
});

test('manifest validation rejects a wrong Admin runtime smoke path', () => {
  const raw = {
    ...manifestValue(),
    adminRuntimeSmoke: { ...adminRuntimeSmoke, path: 'admin-web/scripts/other-runtime-smoke.mjs' },
  };
  assert.throws(() => boundaries.validateR10Manifest(raw));
});

test('manifest validation rejects a wrong Admin runtime smoke hash', () => {
  const raw = {
    ...manifestValue(),
    adminRuntimeSmoke: { ...adminRuntimeSmoke, sha256: '0'.repeat(64) },
  };
  assert.throws(() => boundaries.validateR10Manifest(raw));
});

test('manifest validation rejects an extra Admin runtime smoke key', () => {
  const raw = {
    ...manifestValue(),
    adminRuntimeSmoke: { ...adminRuntimeSmoke, fallback: false },
  };
  assert.throws(() => boundaries.validateR10Manifest(raw));
});

test('live Admin runtime smoke source matches its validated manifest fingerprint', () => {
  const manifest = boundaries.validateR10Manifest(manifestValue());
  assert.deepEqual(manifest.adminRuntimeSmoke, adminRuntimeSmoke);
  const source = readFileSync(path.join(repoRoot, ...adminRuntimeSmoke.path.split('/')));
  assert.equal(sha256(source), adminRuntimeSmoke.sha256);
});

test('request extractor reproduces the exact 62-record immutable contract', () => {
  requireImplementation();
  const sourceFiles = ['admin.ts', 'auth.ts', 'client.ts'].map((name) => ({
    path: `api/${name}`,
    sourceText: execFileSync('git', [
      '-C', repoRoot, 'show',
      `e560e5784278907dd6bf565327c3abfa0c9b8cab:admin-web/src/api/${name}`,
    ], { encoding: 'utf8', windowsHide: true }),
  }));
  const records = scope.extractAdminRequestInventory({
    sourceFiles,
    genericTransportPaths: ['api/client.ts'],
  });
  assert.equal(records.length, 62);
  assert.equal(sha256(JSON.stringify(records)), 'a740ff61ff987899c5f64520de2f74839c1257314383912929fd93970d77fbf9');
  assert.ok(records.includes('POST /api/v1/auth/admin/refresh'));
  assert.ok(!records.some((record) => record.includes('<expr>') && record.endsWith(' <expr>')));
});

test('request extractor keeps duplicates sorts canonically and fails unsupported selected calls', () => {
  requireImplementation();
  const records = scope.extractAdminRequestInventory({
    sourceFiles: [{
      path: 'fixture.ts',
      sourceText: [
        "apiRequest('/z');",
        "apiRequest('/a', { method: 'post' });",
        "apiRequest('/z');",
        "fetch(`${apiBaseUrl}/refresh`, { method: 'POST' });",
        exactGenericTransportCall,
      ].join('\n'),
    }],
    genericTransportPaths: ['fixture.ts'],
  });
  assert.deepEqual(records, ['GET /z', 'GET /z', 'POST /a', 'POST /refresh']);
  assert.throws(() => scope.extractAdminRequestInventory({ sourceFiles: [{
    path: 'bad.ts',
    sourceText: 'apiRequest(path);\n',
  }] }));
  for (const sourceText of [
    'fetch(url, options);\n',
    "window.fetch('/api/v1/example');\n",
    "globalThis.fetch('/api/v1/example');\n",
    "const request = fetch; request('/api/v1/example');\n",
    "const hiddenRequest = apiRequest; hiddenRequest('/api/v1/hidden');\n",
    "const hiddenFetch = (globalThis as any)['f' + 'etch']; hiddenFetch('/api/v1/hidden');\n",
    "fetch('/api/v1/example', options);\n",
    "apiRequest('/api/v1/example', { ...options });\n",
    "apiRequest('/api/v1/example', { method });\n",
    "apiRequest('/api/v1/example', { ['method']: 'POST' });\n",
    "fetch(`${apiBaseUrl}${path}`, { method: options.method ?? 'GET' });\n",
  ]) {
    assert.throws(() => scope.extractAdminRequestInventory({
      sourceFiles: [{ path: 'fixture.ts', sourceText }],
    }));
  }
  assert.deepEqual(scope.extractAdminRequestInventory({
    sourceFiles: [{
      path: 'platform/api/client.ts',
      sourceText: [
        exactGenericTransportCall,
        "fetch(`${apiBaseUrl}/refresh`, { method: 'POST' });",
      ].join('\n'),
    }],
    genericTransportPaths: ['platform/api/client.ts'],
  }), ['POST /refresh']);
  assert.throws(() => scope.extractAdminRequestInventory({
    sourceFiles: [{ path: 'platform/api/client.ts', sourceText: "fetch(`${apiBaseUrl}/refresh`);\n" }],
    genericTransportPaths: ['platform/api/client.ts'],
  }));
});

test('Arabic extractor reproduces the exact production multiset', () => {
  requireImplementation();
  const records = scope.extractAdminArabicLiteralInventory({ sourceFiles: productionAdminFiles() });
  assert.equal(records.length, 1020);
  assert.equal(sha256(JSON.stringify(records)), 'db93ddc6d31d7e79410fb6e1d711e9cdb56ee69cfd2563dab549124bf398f0d0');
});

test('normalization permits module specifier changes but rejects behavioral changes', () => {
  requireImplementation();
  const base = "import { value } from '../old';\nexpect(value).toBe(1);\n";
  const moved = "import { value } from '../../new';\nexpect(value).toBe(1);\n";
  assert.equal(
    scope.normalizeExistingAdminTest({ sourceText: base, relativePath: 'x.test.ts', stage: 'task-1' }),
    scope.normalizeExistingAdminTest({ sourceText: moved, relativePath: 'x.test.ts', stage: 'task-2' }),
  );
  assert.notEqual(
    scope.normalizeExistingAdminTest({ sourceText: base, relativePath: 'x.test.ts', stage: 'task-1' }),
    scope.normalizeExistingAdminTest({ sourceText: moved.replace('toBe(1)', 'toBe(2)'), relativePath: 'x.test.ts', stage: 'task-2' }),
  );
  for (const changed of [
    moved.replace('toBe(1)', 'toBe(2)'),
    moved.replace('expect(value)', "const fixture = 'changed';\nexpect(value)"),
    moved.replace('toBe(1)', 'toBe(1), 30_000'),
  ]) {
    assert.equal(scope.compareExistingAdminTest({
      baseSourceText: base,
      candidateSourceText: changed,
      relativePath: 'x.test.ts',
      stage: 'task-2',
    }).ok, false);
  }
});

test('Dashboard exception accepts only the exact two imports and vi.fn mock factories', () => {
  requireImplementation();
  const base = [
    "import { getProviderApplications, getStats, type AdminStats, type ProviderApplication } from '../api/admin';",
    "vi.mock('../api/admin', () => ({ getProviderApplications: vi.fn(), getStats: vi.fn() }));",
    "expect(getStats).toBeDefined();",
  ].join('\n');
  const candidate = [
    "import { getStats, type AdminStats } from './api';",
    "import { getProviderApplications, type ProviderApplication } from '../providers/api';",
    "vi.mock('./api', () => ({ getStats: vi.fn() }));",
    "vi.mock('../providers/api', () => ({ getProviderApplications: vi.fn() }));",
    "expect(getStats).toBeDefined();",
  ].join('\n');
  assert.equal(scope.compareExistingAdminTest({
    baseSourceText: base,
    candidateSourceText: candidate,
    relativePath: 'pages/DashboardPage.test.tsx',
    stage: 'task-4',
  }).ok, true);
  assert.equal(scope.compareExistingAdminTest({
    baseSourceText: base,
    candidateSourceText: candidate.replace('getStats: vi.fn()', 'getStats: otherMock()'),
    relativePath: 'pages/DashboardPage.test.tsx',
    stage: 'task-4',
  }).ok, false);
  for (const drifted of [
    candidate.replace('type AdminStats', 'AdminStats').replace('type ProviderApplication', 'ProviderApplication'),
    candidate.replaceAll('() => ({', 'async () => ({'),
  ]) {
    assert.equal(scope.compareExistingAdminTest({
      baseSourceText: base,
      candidateSourceText: drifted,
      relativePath: 'pages/DashboardPage.test.tsx',
      stage: 'task-4',
    }).ok, false);
  }
});

const paginationPages = [
  'UsersPage.tsx',
  'ProviderApplicationsPage.tsx',
  'ProvidersPage.tsx',
  'ServicesPage.tsx',
  'ReviewsPage.tsx',
  'ConversationReportsPage.tsx',
  'NotificationsPage.tsx',
];

function paginationSource(values = null) {
  const records = paginationPages.map((page, index) => (
    values
      ? `  ['${page}', source${index}, '${values[index]}'],`
      : `  ['${page}', source${index}],`
  )).join('\n');
  const binding = values ? '[file, source, expectedPaginationImport]' : '[file, source]';
  const operand = values
    ? "`from '${expectedPaginationImport}'`"
    : '"from \'../components/Pagination\'"';
  return [
    `const paginatedPages = [\n${records}\n] as const;`,
    `for (const ${binding} of paginatedPages) {`,
    `  expect(source).toContain(${operand});`,
    '}',
  ].join('\n');
}

test('Pagination contract accepts every exact Task 2-6 stage and rejects a wrong mapping', () => {
  requireImplementation();
  const shallow = '../design_system/Pagination';
  const deep = '../../design_system/Pagination';
  const stages = {
    'task-2': [shallow, shallow, shallow, shallow, shallow, shallow, shallow],
    'task-3': [shallow, shallow, shallow, shallow, shallow, shallow, shallow],
    'task-4': [deep, deep, deep, shallow, shallow, shallow, shallow],
    'task-5': [deep, deep, deep, deep, shallow, shallow, shallow],
    'task-6': [deep, deep, deep, deep, deep, deep, deep],
  };
  for (const [stage, values] of Object.entries(stages)) {
    const result = scope.compareExistingAdminTest({
      baseSourceText: paginationSource(),
      candidateSourceText: paginationSource(values),
      relativePath: 'pages/AdminPaginationContract.test.ts',
      stage,
      paginationResolution: Object.fromEntries(paginationPages.map((page, index) => [page, {
        expectedImport: values[index],
        actualImport: values[index],
        resolvesToDesignSystem: true,
        pageIdentityMatches: true,
      }])),
    });
    assert.equal(result.ok, true, stage);
  }
  const wrong = stages['task-4'].with(0, shallow);
  assert.equal(scope.compareExistingAdminTest({
    baseSourceText: paginationSource(),
    candidateSourceText: paginationSource(wrong),
    relativePath: 'pages/AdminPaginationContract.test.ts',
    stage: 'task-4',
    paginationResolution: Object.fromEntries(paginationPages.map((page, index) => [page, {
      expectedImport: wrong[index], actualImport: wrong[index], resolvesToDesignSystem: true,
      pageIdentityMatches: true,
    }])),
  }).ok, false);
  assert.equal(scope.compareExistingAdminTest({
    baseSourceText: paginationSource(),
    candidateSourceText: paginationSource(stages['task-4']),
    relativePath: 'pages/AdminPaginationContract.test.ts',
    stage: 'task-4',
    paginationResolution: Object.fromEntries(paginationPages.map((page, index) => [page, {
      expectedImport: stages['task-4'][index],
      actualImport: stages['task-4'][index],
      resolvesToDesignSystem: true,
      pageIdentityMatches: index !== 0,
    }])),
  }).ok, false);
});

test('scope accepts the final Task 11 checkpoint and rejects unsafe or drifting inputs', () => {
  requireImplementation();
  assert.equal(scope.checkR10Scope({ repoRoot, task: 'task-11' }).ok, true);
  assert.equal(scope.checkR10Scope({ repoRoot, task: 'task-12' }).ok, false);
  for (const changedPath of [
    'README.md',
    'backend/src/app.module.ts',
    'mobile/lib/main.dart',
    'deploy/dokploy/compose.yml',
    'scripts\\check-r10-scope.mjs',
    'Scripts/check-r10-scope.mjs',
    '../scripts/check-r10-scope.mjs',
    'C:/scripts/check-r10-scope.mjs',
  ]) {
    const result = scope.checkR10Scope({ repoRoot, task: 'task-6' }, { changedPaths: [changedPath] });
    assert.equal(result.ok, false, changedPath);
    assert.ok(result.errors.some(({ kind }) => kind === 'unapproved-changed-path'));
  }
  const protectedResult = scope.checkR10Scope({ repoRoot, task: 'task-6' }, {
    protectedTextOverrides: new Map([['admin-web/package-lock.json', 'changed']]),
  });
  assert.equal(protectedResult.ok, false);
  assert.ok(protectedResult.errors.some(({ kind }) => kind === 'protected-hash-mismatch'));
  const milestoneResult = scope.checkR10Scope({ repoRoot, task: 'task-6' }, {
    boundaryResult: { errors: [], legacyRoots: { api: 6, auth: 9, components: 27, pages: 24 } },
  });
  assert.equal(milestoneResult.ok, false);
  assert.ok(milestoneResult.errors.some(({ kind }) => kind === 'milestone-mismatch'));
});

test('Task 7 introduces generated docs/SCRIPTS without exposing it to Task 6', () => {
  requireImplementation();
  const changedPaths = ['docs/SCRIPTS.md'];
  const task6Result = scope.checkR10Scope(
    { repoRoot, task: 'task-6' },
    { changedPaths },
  );
  assert.equal(task6Result.ok, false);
  assert.ok(task6Result.errors.some(({ kind }) => kind === 'unapproved-changed-path'));

  const task7Result = scope.checkR10Scope(
    { repoRoot, task: 'task-7' },
    { changedPaths },
  );
  assert.equal(task7Result.ok, true, JSON.stringify(task7Result.errors));
});

test('Task 8 alone admits the protected managed runtime smoke remediation path', () => {
  requireImplementation();
  const changedPaths = ['admin-web/scripts/admin-runtime-smoke.mjs'];
  const task7Result = scope.checkR10Scope(
    { repoRoot, task: 'task-7' },
    { changedPaths },
  );
  assert.equal(task7Result.ok, false);
  assert.ok(task7Result.errors.some(({ kind }) => kind === 'unapproved-changed-path'));

  const task8Result = scope.checkR10Scope(
    { repoRoot, task: 'task-8' },
    { changedPaths },
  );
  assert.equal(task8Result.ok, true, JSON.stringify(task8Result.errors));
});

test('Task 9 alone admits the historical Backend gate remediation paths', () => {
  requireImplementation();
  const changedPaths = [
    'backend/scripts/architecture/r3-scope.cjs',
    'backend/scripts/architecture/r5-identity-scan.cjs',
    'backend/test/architecture-r3-scope.test.ts',
    'backend/test/architecture-r4-planning-finance-boundary.test.ts',
    'backend/test/architecture-r5-identity-relocation.test.ts',
  ];
  const task8Result = scope.checkR10Scope(
    { repoRoot, task: 'task-8' },
    { changedPaths },
  );
  assert.equal(task8Result.ok, false);
  for (const changedPath of changedPaths) {
    const isolated = scope.checkR10Scope(
      { repoRoot, task: 'task-8' },
      { changedPaths: [changedPath] },
    );
    assert.ok(
      isolated.errors.some(({ kind }) => kind === 'unapproved-changed-path'),
      changedPath,
    );
  }

  const task9Result = scope.checkR10Scope(
    { repoRoot, task: 'task-9' },
    { changedPaths },
  );
  assert.equal(task9Result.ok, true, JSON.stringify(task9Result.errors));
});

test('Task 8 rejects a one-byte protected Admin runtime smoke mutation', () => {
  requireImplementation();
  const source = readFileSync(path.join(repoRoot, ...adminRuntimeSmoke.path.split('/')));
  const mutated = Buffer.from(source);
  mutated[0] ^= 1;
  const result = scope.checkR10Scope({ repoRoot, task: 'task-8' }, {
    protectedTextOverrides: new Map([[adminRuntimeSmoke.path, mutated]]),
  });
  assert.equal(result.ok, false);
  assert.ok(result.errors.some(
    (error) => error.kind === 'protected-hash-mismatch'
      && error.path === adminRuntimeSmoke.path,
  ));
});

test('managed runtime smoke proves fresh SUPPORT login, valid-write 403, and distinct missing-key 404 bodies', () => {
  assertRuntimeSmokeTask8Coverage();
});

test('managed runtime source contract rejects an always-true OR wrapper around the 403 proof', () => {
  const sourceText = runtimeSmokeSourceContract().sourceText;
  const mutated = replaceRuntimeSourceOnce(
    sourceText,
    `    res.status === 403 &&
      res.body?.statusCode === 403 &&
      res.body?.message === "Admin permission is required",`,
    `    true || (
      res.status === 403 &&
      res.body?.statusCode === 403 &&
      res.body?.message === "Admin permission is required"
    ),`,
  );
  assert.throws(
    () => assertRuntimeSmokeTask8Coverage(mutated),
    /structured 403|conjunction|always-true|logical OR/,
  );
});

test('managed runtime source contract reads the real request method and rejects a POST decoy string', () => {
  const sourceText = runtimeSmokeSourceContract().sourceText;
  const mutated = replaceRuntimeSourceOnce(
    sourceText,
    `  res = await request("/admin/reference-catalogs/money.starter.categories/items", {
    method: "POST",
    body: {
      key: restrictedWriteKey,`,
    `  res = await request("/admin/reference-catalogs/money.starter.categories/items", {
    method: "GET",
    body: {
      contractDecoy: 'method: "POST"',
      key: restrictedWriteKey,`,
  );
  assert.throws(
    () => assertRuntimeSmokeTask8Coverage(mutated),
    /actual request method|valid catalog write|POST/,
  );
});

test('managed runtime source contract rejects a no-op SUPPORT role transition helper', () => {
  const sourceText = runtimeSmokeSourceContract().sourceText;
  const mutated = replaceRuntimeSourceOnce(
    sourceText,
    `    setSmokeAdminRoleToSupport = async () => {
      await prisma.user.update({
        where: { id: user.id },
        data: { adminRole: AdminRole.SUPPORT },
      });
    };`,
    '    setSmokeAdminRoleToSupport = async () => {};',
  );
  assert.throws(
    () => assertRuntimeSmokeTask8Coverage(mutated),
    /SUPPORT role transition|prisma\.user\.update|disposable identity/,
  );
});

test('managed runtime source contract rejects a run-local const that shadows the SUPPORT helper', () => {
  const sourceText = runtimeSmokeSourceContract().sourceText;
  const mutated = replaceRuntimeSourceOnce(
    sourceText,
    'async function run() {',
    `async function run() {
  const setSmokeAdminRoleToSupport = async () => {};`,
  );
  assert.throws(
    () => assertRuntimeSmokeTask8Coverage(mutated),
    /shadow|binding|outer SUPPORT helper/,
  );
});

test('managed runtime source contract rejects a run parameter that shadows the SUPPORT helper', () => {
  const sourceText = runtimeSmokeSourceContract().sourceText;
  const mutated = replaceRuntimeSourceOnce(
    sourceText,
    'async function run() {',
    'async function run(setSmokeAdminRoleToSupport = async () => {}) {',
  );
  assert.throws(
    () => assertRuntimeSmokeTask8Coverage(mutated),
    /shadow|binding|outer SUPPORT helper/,
  );
});

test('managed runtime source contract rejects a nested destructuring binding of the SUPPORT helper', () => {
  const sourceText = runtimeSmokeSourceContract().sourceText;
  const mutated = replaceRuntimeSourceOnce(
    sourceText,
    'async function run() {',
    `async function run() {
  if (Date.now() > 0) {
    const { setSmokeAdminRoleToSupport } = {
      setSmokeAdminRoleToSupport: async () => {},
    };
    await setSmokeAdminRoleToSupport();
  }`,
  );
  assert.throws(
    () => assertRuntimeSmokeTask8Coverage(mutated),
    /shadow|binding|outer SUPPORT helper/,
  );
});

test('managed runtime source contract rejects a destructuring reassignment of the SUPPORT helper in run', () => {
  const sourceText = runtimeSmokeSourceContract().sourceText;
  const mutated = replaceRuntimeSourceOnce(
    sourceText,
    'async function run() {',
    `async function run() {
  ({ setSmokeAdminRoleToSupport } = {
    setSmokeAdminRoleToSupport: async () => {},
  });`,
  );
  assert.throws(
    () => assertRuntimeSmokeTask8Coverage(mutated),
    /reassign|mutation|outer SUPPORT helper/,
  );
});

test('managed runtime source contract rejects every remaining run-local binding declaration form', () => {
  const sourceText = runtimeSmokeSourceContract().sourceText;
  const declarations = [
    'var setSmokeAdminRoleToSupport = async () => {};',
    'let setSmokeAdminRoleToSupport = async () => {};',
    'function setSmokeAdminRoleToSupport() {}',
    'class setSmokeAdminRoleToSupport {}',
    'try { throw new Error("binding probe"); } catch (setSmokeAdminRoleToSupport) {}',
  ];
  for (const declaration of declarations) {
    const mutated = replaceRuntimeSourceOnce(
      sourceText,
      'async function run() {',
      `async function run() {\n  ${declaration}`,
    );
    assert.throws(
      () => assertRuntimeSmokeTask8Coverage(mutated),
      /shadow|binding|outer SUPPORT helper/,
      declaration,
    );
  }
});

test('managed runtime source contract rejects the SUPPORT helper assignment inside if false', () => {
  const sourceText = runtimeSmokeSourceContract().sourceText;
  const mutated = replaceRuntimeSourceOnce(
    sourceText,
    `    setSmokeAdminRoleToSupport = async () => {
      await prisma.user.update({
        where: { id: user.id },
        data: { adminRole: AdminRole.SUPPORT },
      });
    };`,
    `    if (false) {
      setSmokeAdminRoleToSupport = async () => {
        await prisma.user.update({
          where: { id: user.id },
          data: { adminRole: AdminRole.SUPPORT },
        });
      };
    }`,
  );
  assert.throws(
    () => assertRuntimeSmokeTask8Coverage(mutated),
    /control flow|direct try statement|successful return/,
  );
});

test('managed runtime source contract rejects the SUPPORT helper assignment after return', () => {
  const sourceText = runtimeSmokeSourceContract().sourceText;
  const assignment = `    setSmokeAdminRoleToSupport = async () => {
      await prisma.user.update({
        where: { id: user.id },
        data: { adminRole: AdminRole.SUPPORT },
      });
    };`;
  const withoutAssignment = replaceRuntimeSourceOnce(
    sourceText,
    assignment,
    '',
  );
  const mutated = replaceRuntimeSourceOnce(
    withoutAssignment,
    '    return { phone, password, source: "temporary local smoke admin" };',
    `    return { phone, password, source: "temporary local smoke admin" };

${assignment}`,
  );
  assert.throws(
    () => assertRuntimeSmokeTask8Coverage(mutated),
    /control flow|before.*return|successful return/,
  );
});

test('managed runtime source contract rejects a short-circuited SUPPORT helper assignment', () => {
  const sourceText = runtimeSmokeSourceContract().sourceText;
  const mutated = replaceRuntimeSourceOnce(
    sourceText,
    `    setSmokeAdminRoleToSupport = async () => {
      await prisma.user.update({
        where: { id: user.id },
        data: { adminRole: AdminRole.SUPPORT },
      });
    };`,
    `    false && (setSmokeAdminRoleToSupport = async () => {
      await prisma.user.update({
        where: { id: user.id },
        data: { adminRole: AdminRole.SUPPORT },
      });
    });`,
  );
  assert.throws(
    () => assertRuntimeSmokeTask8Coverage(mutated),
    /control flow|direct try statement|successful return/,
  );
});

test('managed runtime source contract rejects a conditional return before the SUPPORT helper assignment', () => {
  const sourceText = runtimeSmokeSourceContract().sourceText;
  const mutated = replaceRuntimeSourceOnce(
    sourceText,
    '    setSmokeAdminRoleToSupport = async () => {',
    `    if (Date.now() > 0) {
      return { phone, password, source: "early bypass" };
    }
    setSmokeAdminRoleToSupport = async () => {`,
  );
  assert.throws(
    () => assertRuntimeSmokeTask8Coverage(mutated),
    /return|control flow|successful return/,
  );
});

test('managed runtime source contract rejects direct eval anywhere in the protected source', () => {
  const sourceText = runtimeSmokeSourceContract().sourceText;
  const mutated = replaceRuntimeSourceOnce(
    sourceText,
    'async function run() {',
    `async function run() {
  eval("setSmokeAdminRoleToSupport = async () => {};");`,
  );
  assert.throws(
    () => assertRuntimeSmokeTask8Coverage(mutated),
    /direct eval|protected source|dynamic mutation/,
  );
});

test('managed runtime source contract requires resolveCredentials to call createLocalSmokeAdmin', () => {
  const sourceText = runtimeSmokeSourceContract().sourceText;
  const mutated = replaceRuntimeSourceOnce(
    sourceText,
    '  return createLocalSmokeAdmin();',
    '  return { phone: "bypass", password: "bypass", source: "bypass" };',
  );
  assert.throws(
    () => assertRuntimeSmokeTask8Coverage(mutated),
    /resolveCredentials|createLocalSmokeAdmin|credential chain/,
  );
});

test('managed runtime source contract requires run to begin by awaiting resolveCredentials', () => {
  const sourceText = runtimeSmokeSourceContract().sourceText;
  const mutated = replaceRuntimeSourceOnce(
    sourceText,
    '  smokeCredentials = await resolveCredentials();',
    '  smokeCredentials = { phone: "bypass", password: "bypass", source: "bypass" };',
  );
  assert.throws(
    () => assertRuntimeSmokeTask8Coverage(mutated),
    /run.*await|resolveCredentials|credential chain/,
  );
});

test('managed runtime source contract rejects an early run return after credential resolution', () => {
  const sourceText = runtimeSmokeSourceContract().sourceText;
  const mutated = replaceRuntimeSourceOnce(
    sourceText,
    '  smokeCredentials = await resolveCredentials();',
    `  smokeCredentials = await resolveCredentials();
  return;`,
  );
  assert.throws(
    () => assertRuntimeSmokeTask8Coverage(mutated),
    /run.*return|early success|complete journey/,
  );
});

test('managed runtime source contract rejects a run return immediately before the SUPPORT transition', () => {
  const sourceText = runtimeSmokeSourceContract().sourceText;
  const mutated = replaceRuntimeSourceOnce(
    sourceText,
    '  await setSmokeAdminRoleToSupport();',
    `  return;
  await setSmokeAdminRoleToSupport();`,
  );
  assert.throws(
    () => assertRuntimeSmokeTask8Coverage(mutated),
    /run.*return|early success|complete journey/,
  );
});

test('managed runtime source contract rejects process exit zero inside run', () => {
  const sourceText = runtimeSmokeSourceContract().sourceText;
  const mutated = replaceRuntimeSourceOnce(
    sourceText,
    '  smokeCredentials = await resolveCredentials();',
    `  smokeCredentials = await resolveCredentials();
  process.exit(0);`,
  );
  assert.throws(
    () => assertRuntimeSmokeTask8Coverage(mutated),
    /process\.exit|exit policy|early success/,
  );
});

test('managed runtime source contract rejects alternate process exit methods', () => {
  const sourceText = runtimeSmokeSourceContract().sourceText;
  const mutated = replaceRuntimeSourceOnce(
    sourceText,
    '  smokeCredentials = await resolveCredentials();',
    `  smokeCredentials = await resolveCredentials();
  process.reallyExit(0);`,
  );
  assert.throws(
    () => assertRuntimeSmokeTask8Coverage(mutated),
    /process member|exit policy|reallyExit/,
  );
});

test('managed runtime source contract rejects an aliased process exit call', () => {
  const sourceText = runtimeSmokeSourceContract().sourceText;
  const mutated = replaceRuntimeSourceOnce(
    sourceText,
    '  smokeCredentials = await resolveCredentials();',
    `  smokeCredentials = await resolveCredentials();
  const reallyExit = process.exit;
  reallyExit(0);`,
  );
  assert.throws(
    () => assertRuntimeSmokeTask8Coverage(mutated),
    /process\.exit|alias|exit policy/,
  );
});

test('managed runtime source contract rejects top-level process exit zero before bootstrap', () => {
  const sourceText = runtimeSmokeSourceContract().sourceText;
  const mutated = replaceRuntimeSourceOnce(
    sourceText,
    '\r\nrun()\r\n  .catch',
    '\r\nprocess.exit(0);\r\nrun()\r\n  .catch',
  );
  assert.throws(
    () => assertRuntimeSmokeTask8Coverage(mutated),
    /process\.exit|exit policy|bootstrap/,
  );
});

test('managed runtime source contract rejects replacing the final run bootstrap with Promise resolve', () => {
  const sourceText = runtimeSmokeSourceContract().sourceText;
  const mutated = replaceRuntimeSourceOnce(
    sourceText,
    'run()\r\n  .catch',
    'Promise.resolve()\r\n  .catch',
  );
  assert.throws(
    () => assertRuntimeSmokeTask8Coverage(mutated),
    /bootstrap|run\(\)|catch.*finally/,
  );
});

test('managed runtime source contract rejects a no-op cleanup assignment before bootstrap', () => {
  const sourceText = runtimeSmokeSourceContract().sourceText;
  const mutated = replaceRuntimeSourceOnce(
    sourceText,
    '    cleanupSmokeAdmin = async () => {',
    `    cleanupSmokeAdmin = async () => {};
    const ignoredCleanup = async () => {`,
  );
  assert.throws(
    () => assertRuntimeSmokeTask8Coverage(mutated),
    /cleanupSmokeAdmin|cleanup binding|cleanup assignment/,
  );
});

test('every exact legacy-root milestone passes and every one-count mutation fails', () => {
  requireImplementation();
  const manifest = boundaries.validateR10Manifest(manifestValue());
  for (const task of Object.keys(manifest.stages).filter((stage) => stage !== 'strict')) {
    const legacyRoots = Object.fromEntries(Object.entries(manifest.stages[task].legacyRoots)
      .map(([root, paths]) => [root, paths.length]));
    assert.deepEqual(scope.checkLegacyRootMilestone({ legacyRoots, stage: task, manifest }), []);
    const wrong = { ...legacyRoots, pages: legacyRoots.pages + 1 };
    assert.ok(scope.checkLegacyRootMilestone({ legacyRoots: wrong, stage: task, manifest })
      .some(({ kind }) => kind === 'milestone-mismatch'));
  }
});

test('scope rejects request Arabic and existing-test drift', () => {
  requireImplementation();
  for (const override of [
    { candidateRequestRecords: [] },
    { candidateArabicRecords: [] },
    { testComparison: { ok: false, errors: [{ kind: 'behavioral-test-drift' }] } },
  ]) assert.equal(scope.checkR10Scope({ repoRoot, task: 'task-1' }, override).ok, false);
});

test('changed-path collection expands rename records and retains deleted paths', () => {
  requireImplementation();
  const outputs = new Map([
    ['diff', 'R100\0old.ts\0new.ts\0D\0deleted.ts\0'],
    ['ls-files', 'untracked.ts\0'],
  ]);
  const paths = scope.collectChangedPaths({
    base: 'e560e5784278907dd6bf565327c3abfa0c9b8cab',
    runGit: (args) => {
      if (args[0] === 'cat-file') return '';
      return args[0] === 'diff' ? outputs.get('diff') : outputs.get('ls-files');
    },
  });
  assert.deepEqual(paths, ['deleted.ts', 'new.ts', 'old.ts', 'untracked.ts']);
});

test('scope rejects a symlink or junction escape without disclosing its target', () => {
  requireImplementation();
  const fixture = mkdtempSync(path.join(os.tmpdir(), 'aarast-r10-scope-'));
  const outside = mkdtempSync(path.join(os.tmpdir(), 'aarast-r10-outside-'));
  try {
    mkdirSync(path.join(fixture, 'scripts'), { recursive: true });
    writeFileSync(path.join(outside, 'check-r10-scope.mjs'), '', 'utf8');
    symlinkSync(outside, path.join(fixture, 'scripts', 'linked'), process.platform === 'win32' ? 'junction' : 'dir');
    const result = scope.checkChangedPathFence({
      repoRoot: fixture,
      changedPaths: ['scripts/linked/check-r10-scope.mjs'],
      allowedPaths: new Set(['scripts/linked/check-r10-scope.mjs']),
    });
    assert.equal(result.ok, false);
    assert.ok(result.errors.some(({ kind }) => kind === 'changed-path-link'));
    assert.doesNotMatch(JSON.stringify(result), new RegExp(outside.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i'));
  } finally {
    rmSync(fixture, { recursive: true, force: true });
    rmSync(outside, { recursive: true, force: true });
  }
});

test('scope rejects an internal symlink or junction even when its target stays in the repository', () => {
  requireImplementation();
  const fixture = mkdtempSync(path.join(os.tmpdir(), 'aarast-r10-scope-internal-'));
  try {
    const target = path.join(fixture, 'internal');
    mkdirSync(target, { recursive: true });
    writeFileSync(path.join(target, 'check-r10-scope.mjs'), '', 'utf8');
    mkdirSync(path.join(fixture, 'scripts'), { recursive: true });
    symlinkSync(target, path.join(fixture, 'scripts', 'linked'), process.platform === 'win32' ? 'junction' : 'dir');
    const result = scope.checkChangedPathFence({
      repoRoot: fixture,
      changedPaths: ['scripts/linked/check-r10-scope.mjs'],
      allowedPaths: new Set(['scripts/linked/check-r10-scope.mjs']),
    });
    assert.equal(result.ok, false);
    assert.ok(result.errors.some(({ kind }) => kind === 'changed-path-link'));
  } finally {
    rmSync(fixture, { recursive: true, force: true });
  }
});
