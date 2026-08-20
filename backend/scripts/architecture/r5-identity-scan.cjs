'use strict';

const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const { types: utilTypes } = require('node:util');
const ts = require('typescript');

const R5_BASE = '9dab73acdc187a4a18d8a675713d8ded40a16d02';
const MANIFEST_PATH = 'backend/architecture/r5-identity-relocation.json';
const STAGES = Object.freeze(['inventory', 'task-2', 'task-3', 'task-4', 'strict']);
const STATIC_HASHES = Object.freeze({
  moves: 'b4cfefb11fa70c69d02e5d72324eec3411c69954b17b97d55839beb49c798f66',
  publicRuntimeContracts: '408ba2aeef53e6fdbccfcbaecad2a47ff055cf78d969ee07fd322d4aa10261d2',
  retiredRoots: '36ddd91996084e08e19a1645e8382d94dd3005d4f2d77b5c7653c5e707ef0984',
  expectedBaselines: '368149a364608a40b3e66411e9a74d4d01b2d1ee1ed761ff0f627a25e39524c7',
  allowedChangedPaths: 'ee4d93ce65f92defda51ac9bda9d4cc810d9440b00b8a2c0f4d1164045d0cda8',
});
const MAX_ARRAY_ITEMS = 1000;
const MAX_TEXT_LENGTH = 4096;

function plainObject(value, label) {
  if (!value || typeof value !== 'object' || Array.isArray(value)
      || utilTypes.isProxy(value) || Object.getPrototypeOf(value) !== Object.prototype) {
    throw new Error(`${label} must be a plain object`);
  }
  for (const key of Reflect.ownKeys(value)) {
    const descriptor = Object.getOwnPropertyDescriptor(value, key);
    if (typeof key !== 'string' || !descriptor || !descriptor.enumerable
        || !Object.prototype.hasOwnProperty.call(descriptor, 'value')) {
      throw new Error(`${label} must use plain data properties`);
    }
  }
  return value;
}

function denseArray(value, label) {
  if (!Array.isArray(value) || utilTypes.isProxy(value)
      || Object.getPrototypeOf(value) !== Array.prototype
      || value.length > MAX_ARRAY_ITEMS) {
    throw new Error(`${label} must be a bounded plain array`);
  }
  for (let index = 0; index < value.length; index += 1) {
    const descriptor = Object.getOwnPropertyDescriptor(value, String(index));
    if (!descriptor || !descriptor.enumerable
        || !Object.prototype.hasOwnProperty.call(descriptor, 'value')) {
      throw new Error(`${label} must be dense plain data`);
    }
  }
  const ownKeys = Reflect.ownKeys(value);
  if (ownKeys.some((key) => typeof key !== 'string')
      || ownKeys.length !== value.length + 1 || !ownKeys.includes('length')) {
    throw new Error(`${label} must contain array data only`);
  }
  return value;
}

function assertDeepPlainData(value, label, seen = new Set(), depth = 0) {
  if (value === null || typeof value === 'boolean'
      || (typeof value === 'number' && Number.isFinite(value))
      || (typeof value === 'string' && value.length <= MAX_TEXT_LENGTH)) return;
  if (!value || typeof value !== 'object' || depth > 32 || seen.has(value)) {
    throw new Error(`${label} must be bounded plain data`);
  }
  seen.add(value);
  if (Array.isArray(value)) {
    const array = denseArray(value, label);
    for (let index = 0; index < array.length; index += 1) {
      assertDeepPlainData(
        Object.getOwnPropertyDescriptor(array, String(index)).value,
        `${label}[${index}]`,
        seen,
        depth + 1,
      );
    }
  } else {
    const object = plainObject(value, label);
    for (const key of Object.keys(object)) {
      assertDeepPlainData(
        Object.getOwnPropertyDescriptor(object, key).value,
        `${label}.${key}`,
        seen,
        depth + 1,
      );
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

function hash(value) {
  return crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
}

function relativePath(value, label) {
  if (typeof value !== 'string' || value.length === 0 || value.length > MAX_TEXT_LENGTH
      || value.includes('\\') || path.posix.isAbsolute(value)
      || value.split('/').includes('.') || value.split('/').includes('..')
      || /[\u0000-\u001f]/u.test(value)) {
    throw new Error(`${label} contains an invalid path`);
  }
  return value;
}

function validateMove(value, label) {
  const move = exactObject(value, ['from', 'to'], label);
  return Object.freeze({
    from: relativePath(move.from, `${label}.from`),
    to: relativePath(move.to, `${label}.to`),
  });
}

function validatePublicRuntimeContract(value, label) {
  const contract = exactObject(value, ['source', 'target', 'declarations'], label);
  const declarations = denseArray(contract.declarations, `${label}.declarations`).map(
    (entry, index) => {
      if (typeof entry !== 'string' || !/^(class|const|function|interface|type):[A-Za-z_$][\w$]*$/u.test(entry)) {
        throw new Error(`${label}.declarations[${index}] is invalid`);
      }
      return entry;
    },
  );
  if (new Set(declarations).size !== declarations.length
      || JSON.stringify(declarations) !== JSON.stringify([...declarations].sort())) {
    throw new Error(`${label}.declarations must be sorted and unique`);
  }
  return Object.freeze({
    source: relativePath(contract.source, `${label}.source`),
    target: relativePath(contract.target, `${label}.target`),
    declarations: Object.freeze(declarations),
  });
}

function validatePathList(value, label) {
  const entries = denseArray(value, label).map(
    (entry, index) => relativePath(entry, `${label}[${index}]`),
  );
  if (new Set(entries).size !== entries.length
      || JSON.stringify(entries) !== JSON.stringify([...entries].sort())) {
    throw new Error(`${label} must be sorted and unique`);
  }
  return entries;
}

function validateR5Manifest(value) {
  assertDeepPlainData(value, 'R5 identity manifest');
  const manifest = exactObject(value, [
    'schemaVersion',
    'baseRevision',
    'stage',
    'moves',
    'publicRuntimeContracts',
    'retiredRoots',
    'expectedBaselines',
    'allowedChangedPaths',
  ], 'R5 identity manifest');
  if (manifest.schemaVersion !== 1 || manifest.baseRevision !== R5_BASE) {
    throw new Error('R5 identity manifest identity is invalid');
  }
  if (!STAGES.includes(manifest.stage)) throw new Error('R5 identity manifest stage is invalid');

  const moves = denseArray(manifest.moves, 'R5 identity manifest moves')
    .map((move, index) => validateMove(move, `R5 identity manifest moves[${index}]`));
  const publicRuntimeContracts = denseArray(
    manifest.publicRuntimeContracts,
    'R5 identity manifest public runtime',
  ).map((contract, index) => validatePublicRuntimeContract(
    contract,
    `R5 identity manifest public runtime[${index}]`,
  ));
  const retiredRoots = denseArray(manifest.retiredRoots, 'R5 identity manifest retired roots')
    .map((root, index) => relativePath(root, `R5 identity manifest retired roots[${index}]`));
  const expectedBaselines = exactObject(manifest.expectedBaselines, [
    'dependencyRecords',
    'ownershipRecords',
    'ownershipOccurrences',
  ], 'R5 identity manifest expected baselines');
  for (const [key, expected] of Object.entries({
    dependencyRecords: 89,
    ownershipRecords: 385,
    ownershipOccurrences: 781,
  })) {
    if (expectedBaselines[key] !== expected) {
      throw new Error('R5 identity manifest expected baselines are invalid');
    }
  }
  const allowedChangedPaths = validatePathList(
    manifest.allowedChangedPaths,
    'R5 identity manifest allowed paths',
  );

  const staticValues = {
    moves,
    publicRuntimeContracts,
    retiredRoots,
    expectedBaselines,
    allowedChangedPaths,
  };
  for (const [key, expectedHash] of Object.entries(STATIC_HASHES)) {
    if (hash(staticValues[key]) !== expectedHash) {
      throw new Error(`R5 identity manifest ${key} drift detected`);
    }
  }
  return Object.freeze({
    schemaVersion: 1,
    baseRevision: R5_BASE,
    stage: manifest.stage,
    moves: Object.freeze(moves),
    publicRuntimeContracts: Object.freeze(publicRuntimeContracts),
    retiredRoots: Object.freeze(retiredRoots),
    expectedBaselines: Object.freeze({ ...expectedBaselines }),
    allowedChangedPaths: Object.freeze(allowedChangedPaths),
  });
}

function isInside(parent, candidate) {
  const relative = path.relative(parent, candidate);
  return relative === '' || (!path.isAbsolute(relative) && relative !== '..'
    && !relative.startsWith(`..${path.sep}`));
}

function inspectExistingPath(repositoryRoot, relative, expected) {
  const root = (fs.realpathSync.native || fs.realpathSync)(repositoryRoot);
  const parts = relative.split('/');
  let cursor = repositoryRoot;
  for (let index = 0; index < parts.length; index += 1) {
    cursor = path.join(cursor, parts[index]);
    if (!fs.existsSync(cursor)) return { exists: false };
    const status = fs.lstatSync(cursor);
    if (status.isSymbolicLink()) throw new Error('R5 source contains a symbolic or junction reparse point');
    if (index < parts.length - 1 && !status.isDirectory()) {
      throw new Error('R5 source parent is not a directory');
    }
  }
  const status = fs.lstatSync(cursor);
  const real = (fs.realpathSync.native || fs.realpathSync)(cursor);
  if (!isInside(root, real)) throw new Error('R5 source escapes the repository');
  if (expected === 'file' && !status.isFile()) throw new Error('R5 source is not a plain file');
  if (expected === 'directory' && !status.isDirectory()) throw new Error('R5 root is not a plain directory');
  return { exists: true };
}

function moveStage(move) {
  if (move.to.includes('/public/')) return 'task-2';
  if (move.to.includes('/internal/auth/') || move.to.includes('/api/auth')) return 'task-3';
  return 'task-4';
}

function exportedDeclarations(filePath) {
  const sourceFile = ts.createSourceFile(
    filePath,
    fs.readFileSync(filePath, 'utf8'),
    ts.ScriptTarget.Latest,
    true,
  );
  const declarations = [];
  const isExported = (node) => (ts.getCombinedModifierFlags(node) & ts.ModifierFlags.Export) !== 0;
  for (const statement of sourceFile.statements) {
    if (!isExported(statement)) continue;
    if (ts.isClassDeclaration(statement) && statement.name) {
      declarations.push(`class:${statement.name.text}`);
    } else if (ts.isFunctionDeclaration(statement) && statement.name) {
      declarations.push(`function:${statement.name.text}`);
    } else if (ts.isInterfaceDeclaration(statement)) {
      declarations.push(`interface:${statement.name.text}`);
    } else if (ts.isTypeAliasDeclaration(statement)) {
      declarations.push(`type:${statement.name.text}`);
    } else if (ts.isVariableStatement(statement)) {
      for (const declaration of statement.declarationList.declarations) {
        if (ts.isIdentifier(declaration.name)) declarations.push(`const:${declaration.name.text}`);
      }
    }
  }
  return declarations.sort();
}

function walkTypeScriptFiles(root) {
  if (!fs.existsSync(root)) return [];
  const files = [];
  for (const entry of fs.readdirSync(root, { withFileTypes: true })) {
    const target = path.join(root, entry.name);
    if (entry.isDirectory()) files.push(...walkTypeScriptFiles(target));
    else if (/\.(?:cts|mts|ts|tsx)$/u.test(entry.name)) files.push(target);
  }
  return files;
}

function isIdentityOwnerSource(backendRoot, filePath) {
  const relative = path.relative(path.join(backendRoot, 'src'), filePath).split(path.sep);
  return ['auth', 'contexts', 'me', 'users'].includes(relative[0])
    || (relative[0] === 'modules' && relative[1] === 'identity');
}

function publicRuntimeConsumers(repositoryRoot, contractPaths) {
  const backendRoot = path.join(repositoryRoot, 'backend');
  const configPath = path.join(backendRoot, 'tsconfig.json');
  if (!fs.existsSync(configPath)) throw new Error('R5 public runtime consumer inventory is unavailable');
  const config = ts.readConfigFile(configPath, ts.sys.readFile);
  if (config.error) throw new Error('R5 public runtime consumer inventory is unavailable');
  const options = ts.parseJsonConfigFileContent(config.config, ts.sys, backendRoot).options;
  const normalizedContracts = new Map(
    contractPaths.map((entry) => [path.normalize(entry), 0]),
  );
  for (const filePath of walkTypeScriptFiles(path.join(backendRoot, 'src'))) {
    if (isIdentityOwnerSource(backendRoot, filePath)) continue;
    const sourceFile = ts.createSourceFile(
      filePath,
      fs.readFileSync(filePath, 'utf8'),
      ts.ScriptTarget.Latest,
      true,
    );
    for (const statement of sourceFile.statements) {
      if ((!ts.isImportDeclaration(statement) && !ts.isExportDeclaration(statement))
          || !statement.moduleSpecifier || !ts.isStringLiteral(statement.moduleSpecifier)) continue;
      const resolved = ts.resolveModuleName(
        statement.moduleSpecifier.text,
        filePath,
        options,
        ts.sys,
      ).resolvedModule;
      if (!resolved) continue;
      const key = path.normalize(resolved.resolvedFileName);
      if (normalizedContracts.has(key)) {
        normalizedContracts.set(key, normalizedContracts.get(key) + 1);
      }
    }
  }
  return normalizedContracts;
}

function validatePublicRuntimeSurface(repositoryRoot, manifest) {
  const stageIndex = STAGES.indexOf(manifest.stage);
  const currentPaths = manifest.publicRuntimeContracts.map((contract) => {
    const moved = stageIndex >= STAGES.indexOf('task-2');
    const relative = moved ? contract.target : contract.source;
    const absolute = path.join(repositoryRoot, ...relative.split('/'));
    if (JSON.stringify(exportedDeclarations(absolute)) !== JSON.stringify(contract.declarations)) {
      throw new Error('R5 public runtime declaration drift detected');
    }
    return absolute;
  });
  const consumers = publicRuntimeConsumers(repositoryRoot, currentPaths);
  if ([...consumers.values()].some((count) => count === 0)) {
    throw new Error('R5 public runtime consumer surface is hollow');
  }
}

function scanR5Identity(options) {
  const input = plainObject(options, 'R5 scan options');
  if (typeof input.repositoryRoot !== 'string' || !path.isAbsolute(input.repositoryRoot)) {
    throw new Error('R5 repository root must be absolute');
  }
  const manifest = validateR5Manifest(input.manifest);
  const currentStage = STAGES.indexOf(manifest.stage);
  for (const move of manifest.moves) {
    const moved = currentStage >= STAGES.indexOf(moveStage(move));
    const source = inspectExistingPath(input.repositoryRoot, move.from, 'file');
    const target = inspectExistingPath(input.repositoryRoot, move.to, 'file');
    if (moved && (source.exists || !target.exists)) {
      throw new Error('R5 move stage does not match the filesystem');
    }
    if (!moved && (!source.exists || target.exists)) {
      throw new Error('R5 inventory does not match the filesystem');
    }
  }
  validatePublicRuntimeSurface(input.repositoryRoot, manifest);
  if (manifest.stage === 'strict') {
    for (const rootName of manifest.retiredRoots) {
      const legacyRoot = inspectExistingPath(
        input.repositoryRoot,
        `backend/src/${rootName}`,
        'directory',
      );
      if (legacyRoot.exists) throw new Error('R5 retired identity root remains');
    }
  }
  return Object.freeze({ ok: true, stage: manifest.stage, moves: manifest.moves.length });
}

function runCli(dependencies = {}) {
  const argv = dependencies.argv || process.argv.slice(2);
  const stdout = dependencies.stdout || ((message) => process.stdout.write(`${message}\n`));
  const stderr = dependencies.stderr || ((message) => process.stderr.write(`${message}\n`));
  try {
    if (argv.length !== 1 || argv[0] !== '--check') throw new Error('invalid arguments');
    const repositoryRoot = path.resolve(__dirname, '../../..');
    const manifest = JSON.parse(fs.readFileSync(
      path.join(repositoryRoot, ...MANIFEST_PATH.split('/')),
      'utf8',
    ));
    const result = scanR5Identity({ repositoryRoot, manifest });
    stdout(`PASS - R5 Identity relocation: stage=${result.stage}, moves=${result.moves}`);
    return 0;
  } catch {
    stderr('ERROR - R5 Identity relocation validation failed');
    return 2;
  }
}

module.exports = {
  MANIFEST_PATH,
  R5_BASE,
  STATIC_HASHES,
  STAGES,
  validateR5Manifest,
  scanR5Identity,
  runCli,
};

if (require.main === module) process.exitCode = runCli();
