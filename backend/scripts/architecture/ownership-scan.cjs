'use strict';

const fs = require('node:fs');
const path = require('node:path');
const ts = require('typescript');

const SCHEMA_VERSION = 1;
const SOURCE_REVISION = 'feafe3db0053d6c66d5f46b56ff9a512861dfbad';
const CONTEXTS = [
  'platform',
  'identity',
  'planning',
  'finance',
  'collaboration',
  'tasks',
  'guests',
  'marketplace',
  'messaging',
  'notifications',
  'catalog',
  'media',
  'insights',
  'backoffice',
];
const READ_OPERATIONS = new Set([
  'findUnique',
  'findUniqueOrThrow',
  'findFirst',
  'findFirstOrThrow',
  'findMany',
  'count',
  'aggregate',
  'groupBy',
]);
const WRITE_OPERATIONS = new Set([
  'create',
  'createMany',
  'createManyAndReturn',
  'update',
  'updateMany',
  'updateManyAndReturn',
  'upsert',
  'delete',
  'deleteMany',
]);
const RAW_OPERATIONS = new Set([
  '$queryRaw',
  '$executeRaw',
  '$queryRawUnsafe',
  '$executeRawUnsafe',
]);
const READ_CONTAINERS = new Set([
  'include',
  'select',
  'where',
  'having',
  'orderBy',
  'cursor',
]);
const RELATION_FILTERS = new Set(['is', 'isNot', 'some', 'none', 'every']);
const LOGICAL_FILTERS = new Set(['AND', 'OR', 'NOT']);
const RELATION_WRITES = new Set([
  'create',
  'createMany',
  'connect',
  'connectOrCreate',
  'set',
  'disconnect',
  'update',
  'updateMany',
  'upsert',
  'delete',
  'deleteMany',
]);

function extractSchemaMetadata(schemaText) {
  const lines = schemaText.split(/\r?\n/);
  const models = [];
  const blocks = new Map();
  let current = null;
  let fields = [];

  for (const line of lines) {
    const model = line.match(/^\s*model\s+([A-Za-z_][A-Za-z0-9_]*)\s*\{/);
    if (model) {
      current = model[1];
      fields = [];
      models.push(current);
      continue;
    }
    if (current && /^\s*}\s*$/.test(line)) {
      blocks.set(current, fields);
      current = null;
      fields = [];
      continue;
    }
    if (current) fields.push(line);
  }

  const modelSet = new Set(models);
  const relations = Object.fromEntries(models.map((model) => [model, {}]));
  for (const [model, modelLines] of blocks) {
    for (const line of modelLines) {
      if (/^\s*(?:\/\/|@@|$)/.test(line)) continue;
      const field = line.match(
        /^\s*([A-Za-z_][A-Za-z0-9_]*)\s+([A-Za-z_][A-Za-z0-9_]*)(\[\])?(\?)?\s*(.*)$/,
      );
      if (!field || !modelSet.has(field[2])) continue;
      const relationName = field[5].match(/@relation\(\s*"([^"]+)"/);
      relations[model][field[1]] = {
        target: field[2],
        isList: Boolean(field[3]),
        isOptional: Boolean(field[4]),
        relationName: relationName ? relationName[1] : null,
      };
    }
  }

  return { models, relations };
}

function lowerCamel(value) {
  return value.length === 0 ? value : value[0].toLowerCase() + value.slice(1);
}

function buildRegistryMetadata(registry, schemaMetadata) {
  validateRegistry(registry, schemaMetadata);
  const modelOwners = new Map();
  for (const [owner, models] of Object.entries(registry.owners)) {
    for (const model of models) modelOwners.set(model, owner);
  }
  const delegateModels = new Map(
    schemaMetadata.models.map((model) => [lowerCamel(model), model]),
  );
  return { modelOwners, delegateModels };
}

function validateRegistry(registry, schemaMetadata) {
  if (!registry || registry.schemaVersion !== SCHEMA_VERSION) {
    throw new Error('ownership registry schemaVersion must be 1');
  }
  if (registry.sourceRevision !== SOURCE_REVISION) {
    throw new Error('ownership registry sourceRevision is invalid');
  }
  if (!registry.owners || !registry.currentRoots || Object.hasOwn(registry, 'exceptions')) {
    throw new Error('ownership registry shape is invalid');
  }
  const ownerKeys = Object.keys(registry.owners).sort();
  const rootKeys = Object.keys(registry.currentRoots).sort();
  const expectedKeys = [...CONTEXTS].sort();
  if (!sameArray(ownerKeys, expectedKeys) || !sameArray(rootKeys, expectedKeys)) {
    throw new Error('ownership registry contexts are incomplete or unknown');
  }
  const registeredModels = Object.values(registry.owners).flat();
  if (new Set(registeredModels).size !== registeredModels.length) {
    throw new Error('ownership registry contains a duplicate model');
  }
  if (!sameArray([...registeredModels].sort(), [...schemaMetadata.models].sort())) {
    throw new Error('ownership registry and Prisma schema models differ');
  }
  const roots = Object.values(registry.currentRoots).flat();
  if (new Set(roots).size !== roots.length) {
    throw new Error('ownership registry contains a duplicate current root');
  }
  for (const root of roots) {
    if (typeof root !== 'string' || !/^[a-z0-9-]+$/.test(root)) {
      throw new Error('ownership registry contains an invalid current root');
    }
  }
}

function sameArray(left, right) {
  return left.length === right.length && left.every((value, index) => value === right[index]);
}

function toRepositoryPath(file, repoRoot, pathApi = path) {
  const relative = pathApi.relative(repoRoot, file);
  if (
    !relative
    || pathApi.isAbsolute(relative)
    || relative === '..'
    || relative.startsWith(`..${pathApi.sep}`)
  ) {
    throw new Error('architecture path is outside the repository');
  }
  return relative.split(pathApi.sep).join('/');
}

function contextForRepositoryPath(repositoryPath, registry) {
  const prefix = 'backend/src/';
  if (!repositoryPath.startsWith(prefix)) return 'unclassified';
  const segments = repositoryPath.slice(prefix.length).split('/');
  if (segments[0] === 'modules') {
    return Object.hasOwn(registry.owners, segments[1]) ? segments[1] : 'unclassified';
  }
  if (segments[0] === 'platform') return 'platform';
  const matches = Object.entries(registry.currentRoots)
    .filter(([, roots]) => roots.includes(segments[0]))
    .map(([context]) => context);
  return matches.length === 1 ? matches[0] : 'unclassified';
}

function readJson(file, label) {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch {
    throw new Error(`${label} cannot be read`);
  }
}

function createProgram(backendRoot) {
  const configPath = path.join(backendRoot, 'tsconfig.json');
  const config = ts.readConfigFile(configPath, ts.sys.readFile);
  if (config.error) throw new Error('backend tsconfig cannot be read');
  const parsed = ts.parseJsonConfigFileContent(config.config, ts.sys, backendRoot, undefined, configPath);
  if (parsed.errors.length > 0) throw new Error('backend tsconfig cannot be parsed');
  const program = ts.createProgram({ rootNames: parsed.fileNames, options: parsed.options });
  return { program, checker: program.getTypeChecker() };
}

function normalizeFsPath(file) {
  return file.replace(/\\/g, '/').toLowerCase();
}

function declarationIsGeneratedPrisma(declaration) {
  if (!declaration) return false;
  const file = normalizeFsPath(declaration.getSourceFile().fileName);
  return file.includes('/node_modules/.prisma/client/')
    || file.includes('/node_modules/@prisma/client/');
}

function symbolIsGeneratedPrisma(symbol, checker) {
  if (!symbol) return false;
  let resolved = symbol;
  if (resolved.flags & ts.SymbolFlags.Alias) {
    try {
      resolved = checker.getAliasedSymbol(resolved);
    } catch {
      return false;
    }
  }
  return (resolved.declarations || []).some(declarationIsGeneratedPrisma);
}

function typeParts(type) {
  if (!type) return [];
  if (type.isUnionOrIntersection && type.isUnionOrIntersection()) {
    return type.types.flatMap(typeParts);
  }
  return [type];
}

function delegateModelForExpression(expression, checker, schemaMetadata, delegateModels) {
  const type = checker.getTypeAtLocation(expression);
  for (const part of typeParts(type)) {
    const symbols = [part.getSymbol && part.getSymbol(), part.aliasSymbol].filter(Boolean);
    for (const symbol of symbols) {
      const name = symbol.getName();
      const match = name.match(/^([A-Za-z_][A-Za-z0-9_]*)Delegate$/);
      if (
        match
        && schemaMetadata.models.includes(match[1])
        && (symbol.declarations || []).some(declarationIsGeneratedPrisma)
      ) {
        return match[1];
      }
    }
    const rendered = checker.typeToString(part);
    for (const match of rendered.matchAll(/\b([A-Za-z_][A-Za-z0-9_]*)Delegate\b/g)) {
      if (schemaMetadata.models.includes(match[1])) return match[1];
    }
  }
  if (ts.isPropertyAccessExpression(expression)) {
    const candidate = delegateModels.get(expression.name.text);
    const propertySymbol = checker.getSymbolAtLocation(expression.name);
    if (candidate && symbolIsGeneratedPrisma(propertySymbol, checker)) return candidate;
  }
  return null;
}

function operationFromCall(call, checker, schemaMetadata, delegateModels) {
  if (!ts.isPropertyAccessExpression(call.expression)) return null;
  const method = call.expression.name.text;
  if (RAW_OPERATIONS.has(method)) return null;
  const methodSymbol = checker.getSymbolAtLocation(call.expression.name);
  if (!symbolIsGeneratedPrisma(methodSymbol, checker)) return null;
  const model = delegateModelForExpression(
    call.expression.expression,
    checker,
    schemaMetadata,
    delegateModels,
  );
  if (!model) return null;
  const mode = READ_OPERATIONS.has(method)
    ? 'read'
    : WRITE_OPERATIONS.has(method)
      ? 'write'
      : 'unknown';
  return { model, operation: method, mode };
}

function rawOperationForProperty(property, checker) {
  if (!ts.isPropertyAccessExpression(property)) return null;
  const operation = property.name.text;
  if (!RAW_OPERATIONS.has(operation)) return null;
  const symbol = checker.getSymbolAtLocation(property.name);
  return symbolIsGeneratedPrisma(symbol, checker) ? operation : null;
}

function unwrapExpression(node) {
  let current = node;
  while (
    current
    && (
      ts.isParenthesizedExpression(current)
      || ts.isAsExpression(current)
      || ts.isSatisfiesExpression(current)
      || ts.isNonNullExpression(current)
      || ts.isTypeAssertionExpression(current)
    )
  ) {
    current = current.expression;
  }
  return current;
}

function staticPropertyName(name) {
  if (ts.isIdentifier(name) || ts.isStringLiteral(name) || ts.isNumericLiteral(name)) {
    return name.text;
  }
  return null;
}

function resolvedSymbol(identifier, checker) {
  let symbol = checker.getSymbolAtLocation(identifier);
  if (!symbol) return null;
  if (symbol.flags & ts.SymbolFlags.Alias) {
    try {
      symbol = checker.getAliasedSymbol(symbol);
    } catch {
      return null;
    }
  }
  return symbol;
}

function constInitializer(identifier, checker, visitedSymbols) {
  const symbol = resolvedSymbol(identifier, checker);
  if (!symbol || visitedSymbols.has(symbol)) return null;
  const declarations = symbol.declarations || [];
  const declaration = declarations.find((candidate) => ts.isVariableDeclaration(candidate));
  if (!declaration || !declaration.initializer) return null;
  const declarationList = declaration.parent;
  if (!ts.isVariableDeclarationList(declarationList)) return null;
  if ((declarationList.flags & ts.NodeFlags.Const) === 0) return null;
  return { symbol, initializer: declaration.initializer };
}

function resolveStaticObject(node, checker, visitedSymbols = new Set()) {
  const current = unwrapExpression(node);
  if (!current) return { kind: 'unknown', unknown: true };

  if (ts.isIdentifier(current)) {
    const resolved = constInitializer(current, checker, visitedSymbols);
    if (!resolved) return { kind: 'unknown', unknown: true };
    const nextVisited = new Set(visitedSymbols);
    nextVisited.add(resolved.symbol);
    return resolveStaticObject(resolved.initializer, checker, nextVisited);
  }

  if (ts.isObjectLiteralExpression(current)) {
    const properties = [];
    let unknown = false;
    for (const property of current.properties) {
      if (ts.isPropertyAssignment(property)) {
        const name = staticPropertyName(property.name);
        if (name === null) {
          unknown = true;
        } else {
          properties.push({ name, value: property.initializer });
        }
        continue;
      }
      if (ts.isShorthandPropertyAssignment(property)) {
        properties.push({ name: property.name.text, value: property.name });
        continue;
      }
      if (ts.isSpreadAssignment(property)) {
        const spread = resolveStaticObject(property.expression, checker, new Set(visitedSymbols));
        if (spread.kind === 'object') {
          properties.push(...spread.properties);
          unknown = unknown || spread.unknown;
        } else {
          unknown = true;
        }
        continue;
      }
      unknown = true;
    }
    return { kind: 'object', properties, unknown };
  }

  if (ts.isArrayLiteralExpression(current)) {
    const elements = [];
    let unknown = false;
    for (const element of current.elements) {
      if (!ts.isSpreadElement(element)) {
        elements.push(element);
        continue;
      }
      const spread = resolveStaticObject(element.expression, checker, new Set(visitedSymbols));
      if (spread.kind === 'array') {
        elements.push(...spread.elements);
        unknown = unknown || spread.unknown;
      } else {
        unknown = true;
      }
    }
    return { kind: 'array', elements, unknown };
  }

  if (
    ts.isStringLiteralLike(current)
    || ts.isNumericLiteral(current)
    || current.kind === ts.SyntaxKind.TrueKeyword
    || current.kind === ts.SyntaxKind.FalseKeyword
    || current.kind === ts.SyntaxKind.NullKeyword
  ) {
    return { kind: 'scalar', unknown: false };
  }

  return { kind: 'unknown', unknown: true };
}

function relationAccesses(argument, rootModel, checker, schemaMetadata, makeAccess, operation) {
  const accesses = [];
  let unknownEmitted = false;

  function emitUnknown() {
    if (unknownEmitted) return;
    unknownEmitted = true;
    accesses.push(makeAccess({
      model: '<dynamic>',
      operation,
      mode: 'unknown',
      source: 'relation',
      issue: 'unknown-relation-shape',
    }));
  }

  function walk(node, model, zone) {
    const resolved = resolveStaticObject(node, checker, new Set());
    if (resolved.kind === 'array') {
      if (resolved.unknown) emitUnknown();
      for (const element of resolved.elements) walk(element, model, zone);
      return;
    }
    if (resolved.kind !== 'object') {
      if (zone === 'root' || zone === 'read' || zone === 'data') emitUnknown();
      return;
    }
    if (resolved.unknown) emitUnknown();

    for (const property of resolved.properties) {
      const name = property.name;
      if (name === '_count' && zone !== 'data') {
        const countShape = resolveStaticObject(property.value, checker, new Set());
        if (countShape.kind === 'object') {
          if (countShape.unknown) emitUnknown();
          const select = countShape.properties.find((candidate) => candidate.name === 'select');
          if (select) walk(select.value, model, 'read');
        } else if (countShape.kind !== 'scalar') {
          emitUnknown();
        }
        continue;
      }
      if (READ_CONTAINERS.has(name)) {
        walk(property.value, model, 'read');
        continue;
      }
      if (name === 'data') {
        walk(property.value, model, 'data');
        continue;
      }
      if (RELATION_FILTERS.has(name)) {
        walk(property.value, model, 'read');
        continue;
      }
      if (LOGICAL_FILTERS.has(name) && zone !== 'data') {
        walk(property.value, model, 'read');
        continue;
      }
      if (RELATION_WRITES.has(name) && zone === 'data') {
        const nested = resolveStaticObject(property.value, checker, new Set());
        if (nested.kind === 'object' || nested.kind === 'array') {
          walk(property.value, model, 'data');
        } else if (nested.kind === 'unknown') {
          emitUnknown();
        }
        continue;
      }
      const relation = schemaMetadata.relations[model] && schemaMetadata.relations[model][name];
      if (!relation) continue;

      if (zone === 'data') {
        const mutationShape = resolveStaticObject(property.value, checker, new Set());
        if (mutationShape.kind !== 'object') {
          emitUnknown();
          continue;
        }
        if (mutationShape.unknown) emitUnknown();
        const mutations = mutationShape.properties.filter((candidate) => RELATION_WRITES.has(candidate.name));
        if (mutations.length === 0) {
          emitUnknown();
          continue;
        }
        accesses.push(makeAccess({
          model: relation.target,
          operation: mutations.map((candidate) => candidate.name).join('+'),
          mode: 'write',
          source: 'relation',
        }));
        for (const mutation of mutations) {
          const nested = resolveStaticObject(mutation.value, checker, new Set());
          if (nested.kind === 'object' || nested.kind === 'array') {
            walk(mutation.value, relation.target, 'data');
          } else if (nested.kind === 'unknown') {
            emitUnknown();
          }
        }
        continue;
      }

      accesses.push(makeAccess({
        model: relation.target,
        operation: name,
        mode: 'read',
        source: 'relation',
      }));
      const nested = resolveStaticObject(property.value, checker, new Set());
      if (nested.kind === 'object' || nested.kind === 'array') {
        walk(property.value, relation.target, 'read');
      } else if (nested.kind === 'unknown') {
        emitUnknown();
      }
    }
  }

  walk(argument, rootModel, 'root');
  return accesses;
}

function isPrismaMember(expression, member, checker) {
  if (!ts.isPropertyAccessExpression(expression) || expression.name.text !== member) return false;
  return symbolIsGeneratedPrisma(checker.getSymbolAtLocation(expression.name), checker);
}

function typeIncludesPrismaSql(type, checker, visited = new Set()) {
  if (!type || visited.has(type)) return false;
  visited.add(type);
  for (const part of typeParts(type)) {
    const symbols = [part.getSymbol && part.getSymbol(), part.aliasSymbol].filter(Boolean);
    for (const symbol of symbols) {
      if (symbol.getName() === 'Sql' && (symbol.declarations || []).some(declarationIsGeneratedPrisma)) {
        return true;
      }
    }
    if (/\bSql\b/.test(checker.typeToString(part))) return true;
    const typeArguments = checker.getTypeArguments && part.objectFlags & ts.ObjectFlags.Reference
      ? checker.getTypeArguments(part)
      : [];
    if (typeArguments.some((argument) => typeIncludesPrismaSql(argument, checker, visited))) return true;
  }
  return false;
}

function staticString(node, checker, visited = new Set()) {
  const current = unwrapExpression(node);
  if (!current) return null;
  if (ts.isStringLiteralLike(current)) return current.text;
  if (ts.isIdentifier(current)) {
    const resolved = constInitializer(current, checker, visited);
    if (!resolved) return null;
    const next = new Set(visited);
    next.add(resolved.symbol);
    return staticString(resolved.initializer, checker, next);
  }
  return null;
}

function sqlAlternatives(node, checker, visitedSymbols = new Set()) {
  const current = unwrapExpression(node);
  if (!current) return { sql: ['?'], unknown: true };

  if (ts.isIdentifier(current)) {
    const resolved = constInitializer(current, checker, visitedSymbols);
    if (!resolved) return { sql: ['?'], unknown: true };
    const next = new Set(visitedSymbols);
    next.add(resolved.symbol);
    return sqlAlternatives(resolved.initializer, checker, next);
  }

  if (ts.isConditionalExpression(current)) {
    const left = sqlAlternatives(current.whenTrue, checker, new Set(visitedSymbols));
    const right = sqlAlternatives(current.whenFalse, checker, new Set(visitedSymbols));
    return { sql: [...left.sql, ...right.sql], unknown: left.unknown || right.unknown };
  }

  if (ts.isTaggedTemplateExpression(current) && isPrismaMember(current.tag, 'sql', checker)) {
    return flattenTemplate(current.template, checker, visitedSymbols);
  }

  if (ts.isCallExpression(current) && isPrismaMember(current.expression, 'join', checker)) {
    return flattenPrismaJoin(current, checker, visitedSymbols);
  }

  return { sql: ['?'], unknown: true };
}

function interpolationIsTablePosition(prefix) {
  return /\b(?:FROM|JOIN|INTO|UPDATE|TABLE|USING|COPY)\s*$/i.test(prefix);
}

function flattenTemplate(template, checker, visitedSymbols = new Set()) {
  if (ts.isNoSubstitutionTemplateLiteral(template)) {
    return { sql: [template.text], unknown: false };
  }
  let alternatives = [template.head.text];
  let unknown = false;

  for (const span of template.templateSpans) {
    const expression = unwrapExpression(span.expression);
    let fragment;
    if (expression && ts.isCallExpression(expression) && isPrismaMember(expression.expression, 'join', checker)) {
      fragment = flattenPrismaJoin(expression, checker, new Set(visitedSymbols));
    } else if (expression && typeIncludesPrismaSql(checker.getTypeAtLocation(expression), checker)) {
      fragment = sqlAlternatives(expression, checker, new Set(visitedSymbols));
    } else {
      fragment = {
        sql: alternatives.some(interpolationIsTablePosition) ? ['__DYNAMIC_TABLE__'] : ['?'],
        unknown: false,
      };
    }
    unknown = unknown || fragment.unknown;
    const combined = [];
    for (const prefix of alternatives) {
      for (const inserted of fragment.sql) combined.push(prefix + inserted + span.literal.text);
    }
    alternatives = combined;
  }
  return { sql: alternatives, unknown };
}

function arrayInitializer(node, checker, visitedSymbols) {
  const current = unwrapExpression(node);
  if (!current) return null;
  if (ts.isArrayLiteralExpression(current)) return current;
  if (ts.isIdentifier(current)) {
    const resolved = constInitializer(current, checker, visitedSymbols);
    if (!resolved) return null;
    const next = new Set(visitedSymbols);
    next.add(resolved.symbol);
    return arrayInitializer(resolved.initializer, checker, next);
  }
  return null;
}

function flattenPrismaJoin(call, checker, visitedSymbols) {
  const collection = call.arguments[0];
  if (!collection) return { sql: ['?'], unknown: true };
  const collectionType = checker.getTypeAtLocation(collection);
  const containsSql = typeIncludesPrismaSql(collectionType, checker);
  const array = arrayInitializer(collection, checker, visitedSymbols);
  if (!containsSql) return { sql: ['?'], unknown: false };
  if (!array) return { sql: ['?'], unknown: true };

  const separator = call.arguments[1] ? staticString(call.arguments[1], checker) : ',';
  if (separator === null) return { sql: ['?'], unknown: true };
  let alternatives = [''];
  let unknown = false;
  for (const element of array.elements) {
    if (!typeIncludesPrismaSql(checker.getTypeAtLocation(element), checker)) {
      unknown = true;
      continue;
    }
    const fragment = sqlAlternatives(element, checker, new Set(visitedSymbols));
    unknown = unknown || fragment.unknown;
    const combined = [];
    for (const prefix of alternatives) {
      for (const inserted of fragment.sql) {
        combined.push(prefix ? `${prefix}${separator}${inserted}` : inserted);
      }
    }
    alternatives = combined;
  }
  return { sql: alternatives.length > 0 ? alternatives : ['?'], unknown };
}

function tokenizeSql(sql) {
  const tokens = [];
  let index = 0;
  while (index < sql.length) {
    const char = sql[index];
    if (/\s/.test(char)) {
      index += 1;
      continue;
    }
    if (char === '-' && sql[index + 1] === '-') {
      index += 2;
      while (index < sql.length && sql[index] !== '\n') index += 1;
      continue;
    }
    if (char === '/' && sql[index + 1] === '*') {
      const end = sql.indexOf('*/', index + 2);
      index = end === -1 ? sql.length : end + 2;
      continue;
    }
    if (char === '"') {
      let value = '';
      index += 1;
      while (index < sql.length) {
        if (sql[index] === '"' && sql[index + 1] === '"') {
          value += '"';
          index += 2;
        } else if (sql[index] === '"') {
          index += 1;
          break;
        } else {
          value += sql[index];
          index += 1;
        }
      }
      tokens.push({ kind: 'identifier', value });
      continue;
    }
    if (char === "'") {
      index += 1;
      while (index < sql.length) {
        if (sql[index] === "'" && sql[index + 1] === "'") {
          index += 2;
        } else if (sql[index] === "'") {
          index += 1;
          break;
        } else {
          index += 1;
        }
      }
      tokens.push({ kind: 'string', value: '<string>' });
      continue;
    }
    if (/[A-Za-z_$]/.test(char)) {
      let end = index + 1;
      while (end < sql.length && /[A-Za-z0-9_$]/.test(sql[end])) end += 1;
      tokens.push({ kind: 'word', value: sql.slice(index, end) });
      index = end;
      continue;
    }
    if (/[0-9]/.test(char)) {
      let end = index + 1;
      while (end < sql.length && /[0-9.]/.test(sql[end])) end += 1;
      tokens.push({ kind: 'number', value: sql.slice(index, end) });
      index = end;
      continue;
    }
    tokens.push({ kind: char === '?' ? 'placeholder' : 'punctuation', value: char });
    index += 1;
  }
  return tokens;
}

function tokenKeyword(token) {
  return token && token.kind === 'word' ? token.value.toUpperCase() : '';
}

function nextTableToken(tokens, start) {
  let index = start;
  if (tokenKeyword(tokens[index]) === 'ONLY') index += 1;
  if (!tokens[index]) return null;
  if (tokens[index].value === '(') return null;
  let token = tokens[index];
  if (!['identifier', 'word'].includes(token.kind)) return null;
  let value = token.value;
  let end = index;
  if (tokens[index + 1] && tokens[index + 1].value === '.' && tokens[index + 2]) {
    token = tokens[index + 2];
    value = token.value;
    end = index + 2;
  }
  return { value, token, end };
}

function collectCteNames(tokens) {
  const names = new Set();
  if (tokenKeyword(tokens[0]) !== 'WITH') return names;
  let index = tokenKeyword(tokens[1]) === 'RECURSIVE' ? 2 : 1;
  while (index < tokens.length) {
    const name = tokens[index];
    if (!name || !['identifier', 'word'].includes(name.kind)) break;
    names.add(name.value.toLowerCase());
    index += 1;
    if (tokens[index] && tokens[index].value === '(') {
      let depth = 1;
      index += 1;
      while (index < tokens.length && depth > 0) {
        if (tokens[index].value === '(') depth += 1;
        if (tokens[index].value === ')') depth -= 1;
        index += 1;
      }
    }
    if (tokenKeyword(tokens[index]) !== 'AS') break;
    index += 1;
    if (!tokens[index] || tokens[index].value !== '(') break;
    let depth = 1;
    index += 1;
    while (index < tokens.length && depth > 0) {
      if (tokens[index].value === '(') depth += 1;
      if (tokens[index].value === ')') depth -= 1;
      index += 1;
    }
    if (!tokens[index] || tokens[index].value !== ',') break;
    index += 1;
  }
  return names;
}

function sqlTableOccurrences(sql) {
  const tokens = tokenizeSql(sql);
  const first = tokenKeyword(tokens[0]);
  const recognized = new Set([
    'SELECT', 'WITH', 'INSERT', 'UPDATE', 'DELETE', 'LOCK', 'TRUNCATE',
    'ALTER', 'DROP', 'CREATE', 'MERGE', 'COPY',
  ]);
  if (!recognized.has(first)) return { occurrences: [], unknown: tokens.length > 0 };
  const ctes = collectCteNames(tokens);
  const occurrences = [];

  function add(index, mode, operation) {
    const table = nextTableToken(tokens, index);
    if (!table) return;
    if (ctes.has(table.value.toLowerCase())) return;
    occurrences.push({ model: table.value, mode, operation });
  }

  function addList(index, mode, operation) {
    let cursor = index;
    while (cursor < tokens.length) {
      const table = nextTableToken(tokens, cursor);
      if (!table) return;
      if (!ctes.has(table.value.toLowerCase())) {
        occurrences.push({ model: table.value, mode, operation });
      }
      cursor = table.end + 1;
      if (tokenKeyword(tokens[cursor]) === 'AS') cursor += 2;
      else if (
        tokens[cursor]
        && ['identifier', 'word'].includes(tokens[cursor].kind)
        && !['WHERE', 'JOIN', 'USING', 'ORDER', 'GROUP', 'HAVING', 'LIMIT', 'RETURNING', 'FOR', 'ON'].includes(tokenKeyword(tokens[cursor]))
      ) {
        cursor += 1;
      }
      if (!tokens[cursor] || tokens[cursor].value !== ',') return;
      cursor += 1;
    }
  }

  for (let index = 0; index < tokens.length; index += 1) {
    const keyword = tokenKeyword(tokens[index]);
    const previous = tokenKeyword(tokens[index - 1]);
    if (keyword === 'FROM' && first !== 'COPY') {
      addList(index + 1, previous === 'DELETE' ? 'write' : 'read', previous === 'DELETE' ? 'delete' : 'select');
    } else if (keyword === 'JOIN' || keyword === 'USING') {
      add(index + 1, 'read', keyword.toLowerCase());
    } else if (keyword === 'INTO' && (previous === 'INSERT' || previous === 'MERGE')) {
      add(index + 1, 'write', previous.toLowerCase());
    } else if (keyword === 'UPDATE' && (index === 0 || (first === 'WITH' && previous !== 'FOR'))) {
      add(index + 1, 'write', 'update');
    } else if (keyword === 'TABLE' && ['LOCK', 'TRUNCATE', 'ALTER', 'DROP', 'CREATE'].includes(previous)) {
      add(index + 1, 'write', previous.toLowerCase());
    } else if (['TRUNCATE', 'COPY'].includes(keyword) && tokenKeyword(tokens[index + 1]) !== 'TABLE') {
      addList(index + 1, 'write', keyword.toLowerCase());
    }
  }

  if (occurrences.length === 0 && (first === 'SELECT' || first === 'WITH')) {
    const normalized = tokens.map((token) => token.value).join(' ');
    const tableless = /^SELECT\s+1\b/i.test(normalized)
      || /^SELECT\s+pg_(?:try_)?advisory_[A-Za-z0-9_]*\s*\(/i.test(normalized)
      || /^SELECT\s+set_config\s*\(/i.test(normalized);
    return { occurrences, unknown: !tableless };
  }
  return { occurrences, unknown: false };
}

function sqlAccesses(node, checker, makeAccess, operation) {
  let flattened;
  if (ts.isTaggedTemplateExpression(node)) {
    flattened = flattenTemplate(node.template, checker, new Set());
  } else if (ts.isCallExpression(node)) {
    const first = node.arguments[0];
    if (!first) return [makeAccess({
      model: '<dynamic>', operation, mode: 'unknown', source: 'sql', issue: 'unknown-sql-composition',
    })];
    const current = unwrapExpression(first);
    if (current && ts.isTaggedTemplateExpression(current) && isPrismaMember(current.tag, 'sql', checker)) {
      flattened = flattenTemplate(current.template, checker, new Set());
    } else if (current && ts.isTemplateExpression(current)) {
      flattened = flattenTemplate(current, checker, new Set());
    } else if (current && ts.isStringLiteralLike(current)) {
      flattened = { sql: [current.text], unknown: false };
    } else if (current && ts.isNoSubstitutionTemplateLiteral(current)) {
      flattened = { sql: [current.text], unknown: false };
    } else {
      const resolvedString = current ? staticString(current, checker) : null;
      flattened = resolvedString === null
        ? { sql: ['?'], unknown: true }
        : { sql: [resolvedString], unknown: false };
    }
  } else {
    return [];
  }

  const accesses = [];
  let unknownComposition = flattened.unknown;
  for (const sql of flattened.sql) {
    const parsed = sqlTableOccurrences(sql);
    unknownComposition = unknownComposition || parsed.unknown;
    for (const occurrence of parsed.occurrences) {
      accesses.push(makeAccess({
        model: occurrence.model,
        operation: occurrence.operation,
        mode: occurrence.mode,
        source: 'sql',
        issue: occurrence.model === '__DYNAMIC_TABLE__' ? 'unknown-model' : null,
      }));
    }
  }
  if (unknownComposition) {
    accesses.push(makeAccess({
      model: '<dynamic>',
      operation,
      mode: 'unknown',
      source: 'sql',
      issue: 'unknown-sql-composition',
    }));
  }
  return accesses;
}

function classifyOwnershipAccesses(options) {
  if (!options || !options.repoRoot || !options.backendRoot) {
    throw new Error('ownership scan roots are required');
  }
  const repoRoot = path.resolve(options.repoRoot);
  const backendRoot = path.resolve(options.backendRoot);
  const schemaText = fs.readFileSync(path.join(backendRoot, 'prisma', 'schema.prisma'), 'utf8');
  const registry = readJson(
    path.join(backendRoot, 'architecture', 'ownership-registry.json'),
    'ownership registry',
  );
  const schemaMetadata = extractSchemaMetadata(schemaText);
  const { modelOwners, delegateModels } = buildRegistryMetadata(registry, schemaMetadata);
  const { program, checker } = createProgram(backendRoot);
  const sourceRoot = path.resolve(backendRoot, 'src');
  const accesses = [];

  for (const sourceFile of program.getSourceFiles()) {
    if (sourceFile.isDeclarationFile) continue;
    const absoluteFile = path.resolve(sourceFile.fileName);
    const relativeToSource = path.relative(sourceRoot, absoluteFile);
    if (
      !relativeToSource
      || path.isAbsolute(relativeToSource)
      || relativeToSource === '..'
      || relativeToSource.startsWith(`..${path.sep}`)
      || !absoluteFile.endsWith('.ts')
    ) {
      continue;
    }
    const file = toRepositoryPath(absoluteFile, repoRoot);
    const context = contextForRepositoryPath(file, registry);

    function makeAccess(candidate) {
      const physicalModel = candidate.model === '__DYNAMIC_TABLE__' ? '<dynamic>' : candidate.model;
      const knownModel = modelOwners.has(physicalModel);
      const owner = knownModel ? modelOwners.get(physicalModel) : null;
      let reason = null;
      if (candidate.issue === 'unknown-model' || (!knownModel && !candidate.issue)) {
        reason = 'unknown-model';
      } else if (candidate.issue === 'unknown-operation') {
        reason = 'unknown-operation';
      } else if (candidate.issue === 'unknown-relation-shape') {
        reason = 'unknown-relation-shape';
      } else if (candidate.issue === 'unknown-sql-composition') {
        reason = 'unknown-sql-composition';
      } else if (context === 'unclassified') {
        reason = 'unclassified-context';
      } else if (owner !== context) {
        reason = 'foreign-model';
      }
      return {
        file,
        context,
        owner,
        model: physicalModel,
        operation: candidate.operation,
        mode: candidate.mode,
        source: candidate.source,
        reason,
      };
    }

    function visit(node) {
      if (ts.isTaggedTemplateExpression(node)) {
        const rawOperation = rawOperationForProperty(node.tag, checker);
        if (rawOperation) {
          accesses.push(...sqlAccesses(node, checker, makeAccess, rawOperation));
          return;
        }
      }
      if (ts.isCallExpression(node)) {
        const rawOperation = rawOperationForProperty(node.expression, checker);
        if (rawOperation) {
          accesses.push(...sqlAccesses(node, checker, makeAccess, rawOperation));
          return;
        }
        const delegate = operationFromCall(node, checker, schemaMetadata, delegateModels);
        if (delegate) {
          accesses.push(makeAccess({
            model: delegate.model,
            operation: delegate.operation,
            mode: delegate.mode,
            source: 'delegate',
            issue: delegate.mode === 'unknown' ? 'unknown-operation' : null,
          }));
          if (node.arguments[0]) {
            accesses.push(...relationAccesses(
              node.arguments[0],
              delegate.model,
              checker,
              schemaMetadata,
              makeAccess,
              delegate.operation,
            ));
          }
          return;
        }
      }
      ts.forEachChild(node, visit);
    }

    visit(sourceFile);
  }
  return accesses;
}

function recordKey(record) {
  return [
    record.file,
    record.context,
    record.owner ?? '',
    record.model,
    record.operation,
    record.mode,
    record.source,
    record.reason,
  ].join('|');
}

function scanOwnershipViolations(options) {
  const aggregated = new Map();
  for (const access of classifyOwnershipAccesses(options)) {
    if (!access.reason) continue;
    const key = recordKey(access);
    const existing = aggregated.get(key);
    if (existing) {
      existing.count += 1;
    } else {
      aggregated.set(key, { key, ...access, count: 1 });
    }
  }
  return [...aggregated.values()].sort((left, right) => (
    left.key < right.key ? -1 : left.key > right.key ? 1 : 0
  ));
}

function compareWithBaseline(currentRecords, baselineRecords) {
  const allowed = new Map(baselineRecords.map((record) => [record.key || recordKey(record), record.count]));
  const additions = currentRecords.filter((record) => {
    const key = record.key || recordKey(record);
    return !allowed.has(key) || record.count > allowed.get(key);
  });
  return { ok: additions.length === 0, additions };
}

function canonicalBaselineFile(file) {
  return typeof file === 'string'
    && /^backend\/src\/.+\.ts$/.test(file)
    && !file.includes('\\')
    && !file.split('/').includes('..')
    && !path.posix.isAbsolute(file)
    && !path.win32.isAbsolute(file);
}

function validateBaseline(baseline) {
  if (!baseline || baseline.schemaVersion !== SCHEMA_VERSION) {
    throw new Error('ownership baseline schemaVersion must be 1');
  }
  if (baseline.sourceRevision !== SOURCE_REVISION) {
    throw new Error('ownership baseline sourceRevision is invalid');
  }
  if (!Array.isArray(baseline.violations)) {
    throw new Error('ownership baseline violations must be an array');
  }
  const keys = [];
  for (const record of baseline.violations) {
    if (!record || record.key !== recordKey(record)) {
      throw new Error('ownership baseline contains an invalid key');
    }
    if (!canonicalBaselineFile(record.file)) {
      throw new Error('ownership baseline contains a non-canonical file');
    }
    if (!Number.isInteger(record.count) || record.count <= 0) {
      throw new Error('ownership baseline counts must be positive integers');
    }
    const serialized = JSON.stringify(record);
    if (
      /DATABASE_URL\s*=|JWT_SECRET\s*=|PASSWORD\s*=|SECRET\s*=|TOKEN\s*=|BEGIN (?:RSA |OPENSSH )?PRIVATE KEY|postgres(?:ql)?:\/\/|https?:\/\/[^/\s]+:[^@\s]+@|[A-Za-z]:[\\/]|(?:^|\s)\/[A-Za-z]/i.test(serialized)
    ) {
      throw new Error('ownership baseline contains an absolute path or secret');
    }
    keys.push(record.key);
  }
  if (!sameArray(keys, [...keys].sort()) || new Set(keys).size !== keys.length) {
    throw new Error('ownership baseline keys must be sorted and unique');
  }
  return baseline;
}

function sanitizeMessage(value) {
  const firstLine = String(value || 'unknown error').split(/\r?\n/, 1)[0];
  return firstLine
    .replace(/[A-Za-z]:[\\/][^\s:]*/g, '<path>')
    .replace(/\/(?:[^\s/:]+\/)+[^\s:]*/g, '<path>');
}

function writeLine(target, message) {
  if (typeof target === 'function') target(message);
  else if (target && typeof target.write === 'function') target.write(`${message}\n`);
}

function runCli(dependencies) {
  const argv = dependencies.argv || [];
  if (
    argv.length !== 1
    || !['--check', '--write-baseline'].includes(argv[0])
  ) {
    writeLine(dependencies.stderr, 'usage: ownership-scan.cjs --check | --write-baseline');
    return 2;
  }
  try {
    const current = dependencies.scan();
    if (argv[0] === '--write-baseline') {
      if (typeof dependencies.writeBaseline !== 'function') {
        throw new Error('baseline writer is unavailable');
      }
      const baseline = {
        schemaVersion: SCHEMA_VERSION,
        sourceRevision: SOURCE_REVISION,
        violations: current,
      };
      validateBaseline(baseline);
      dependencies.writeBaseline(baseline);
      writeLine(dependencies.stdout, `ownership baseline written (${current.length} records)`);
      return 0;
    }
    const baseline = validateBaseline(dependencies.readBaseline());
    const comparison = compareWithBaseline(current, baseline.violations);
    if (!comparison.ok) {
      writeLine(dependencies.stderr, `ownership violations added (${comparison.additions.length} records)`);
      for (const addition of comparison.additions) {
        writeLine(dependencies.stderr, `${addition.key} count=${addition.count}`);
      }
      return 1;
    }
    writeLine(dependencies.stdout, `ownership check passed (${current.length} current records)`);
    return 0;
  } catch (error) {
    writeLine(dependencies.stderr, `architecture ownership error: ${sanitizeMessage(error && error.message)}`);
    return 2;
  }
}

function defaultDependencies(argv) {
  const backendRoot = path.resolve(__dirname, '../..');
  const repoRoot = path.resolve(backendRoot, '..');
  const baselinePath = path.join(backendRoot, 'architecture', 'ownership-baseline.json');
  return {
    argv,
    scan: () => scanOwnershipViolations({ repoRoot, backendRoot }),
    readBaseline: () => readJson(baselinePath, 'ownership baseline'),
    writeBaseline: (baseline) => fs.writeFileSync(
      baselinePath,
      `${JSON.stringify(baseline, null, 2)}\n`,
      'utf8',
    ),
    stdout: (message) => process.stdout.write(`${message}\n`),
    stderr: (message) => process.stderr.write(`${message}\n`),
  };
}

module.exports = {
  extractSchemaMetadata,
  toRepositoryPath,
  contextForRepositoryPath,
  classifyOwnershipAccesses,
  scanOwnershipViolations,
  compareWithBaseline,
  runCli,
};

if (require.main === module) {
  process.exitCode = runCli(defaultDependencies(process.argv.slice(2)));
}
