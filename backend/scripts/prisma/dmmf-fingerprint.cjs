const crypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { pathToFileURL } = require('node:url');

const FINGERPRINT_FAILURE = 'invalid Prisma DMMF fingerprint input';
const CLI_FAILURE = 'ERROR - Prisma DMMF fingerprint failed';
const MAX_DEPTH = 32;
const MAX_ARRAY_LENGTH = 10_000;
const MAX_NODE_COUNT = 50_000;
const MAX_OBJECT_KEYS = 1_024;
const MAX_STRING_LENGTH = 16 * 1024;
const MAX_OUTPUT_BYTES = 1024 * 1024;

function fail() {
  throw new Error(FINGERPRINT_FAILURE);
}

function ownDescriptor(value, key) {
  const descriptor = Object.getOwnPropertyDescriptor(value, key);
  if (!descriptor || !Object.prototype.hasOwnProperty.call(descriptor, 'value')) fail();
  return descriptor;
}

function ownValue(value, key) {
  return ownDescriptor(value, key).value;
}

function optionalOwnValue(value, key, fallback) {
  const descriptor = Object.getOwnPropertyDescriptor(value, key);
  if (!descriptor) return arguments.length >= 3 ? fallback : null;
  if (!Object.prototype.hasOwnProperty.call(descriptor, 'value')) fail();
  return descriptor.value;
}

function assertPlainRecord(value, allowedKeys) {
  if (value === null || typeof value !== 'object' || Object.getPrototypeOf(value) !== Object.prototype) {
    fail();
  }
  if (Object.getOwnPropertySymbols(value).length > 0) fail();
  const names = Object.getOwnPropertyNames(value);
  for (const name of names) {
    if (!allowedKeys.has(name)) fail();
    const descriptor = ownDescriptor(value, name);
    if (!descriptor.enumerable) fail();
  }
}

function assertBoundedPlainData(value, budget = { nodes: 0 }, depth = 0) {
  if (depth > MAX_DEPTH) fail();
  if (value === null || typeof value === 'boolean' || typeof value === 'undefined') return;
  if (typeof value === 'string') {
    if (value.length > MAX_STRING_LENGTH) fail();
    return;
  }
  if (typeof value === 'number') {
    if (!Number.isFinite(value)) fail();
    return;
  }
  if (typeof value !== 'object') fail();
  budget.nodes += 1;
  if (budget.nodes > MAX_NODE_COUNT) fail();
  if (Array.isArray(value)) {
    if (Object.getPrototypeOf(value) !== Array.prototype || Object.getOwnPropertySymbols(value).length > 0) fail();
    const length = ownValue(value, 'length');
    if (!Number.isSafeInteger(length) || length < 0 || length > MAX_ARRAY_LENGTH) fail();
    const names = Object.getOwnPropertyNames(value);
    if (names.length !== length + 1 || !names.includes('length')) fail();
    for (let index = 0; index < length; index += 1) {
      const descriptor = ownDescriptor(value, String(index));
      if (!descriptor.enumerable) fail();
      assertBoundedPlainData(descriptor.value, budget, depth + 1);
    }
    return;
  }
  if (Object.getPrototypeOf(value) !== Object.prototype || Object.getOwnPropertySymbols(value).length > 0) fail();
  const names = Object.getOwnPropertyNames(value);
  if (names.length > MAX_OBJECT_KEYS) fail();
  for (const name of names) {
    const descriptor = ownDescriptor(value, name);
    if (!descriptor.enumerable) fail();
    assertBoundedPlainData(descriptor.value, budget, depth + 1);
  }
}

function readArray(value, readEntry, depth) {
  if (depth > MAX_DEPTH || !Array.isArray(value) || Object.getPrototypeOf(value) !== Array.prototype) fail();
  if (Object.getOwnPropertySymbols(value).length > 0) fail();
  const lengthDescriptor = ownDescriptor(value, 'length');
  const length = lengthDescriptor.value;
  if (!Number.isSafeInteger(length) || length < 0 || length > MAX_ARRAY_LENGTH) fail();
  const names = Object.getOwnPropertyNames(value);
  if (names.length !== length + 1 || !names.includes('length')) fail();

  const entries = [];
  for (let index = 0; index < length; index += 1) {
    const name = String(index);
    if (!names.includes(name)) fail();
    const descriptor = ownDescriptor(value, name);
    if (!descriptor.enumerable) fail();
    entries.push(readEntry(descriptor.value, depth + 1));
  }
  return entries;
}

function readString(value) {
  if (typeof value !== 'string') fail();
  return value;
}

function readNullableString(value) {
  if (value !== null && typeof value !== 'string') fail();
  return value;
}

function readBoolean(value) {
  if (typeof value !== 'boolean') fail();
  return value;
}

function clonePlainData(value, depth = 0) {
  if (depth > MAX_DEPTH) fail();
  if (value === null || typeof value === 'string' || typeof value === 'boolean') return value;
  if (typeof value === 'number') {
    if (!Number.isFinite(value)) fail();
    return value;
  }
  if (typeof value === 'undefined') return null;
  if (Array.isArray(value)) return readArray(value, clonePlainData, depth);
  if (typeof value !== 'object' || Object.getPrototypeOf(value) !== Object.prototype) fail();
  if (Object.getOwnPropertySymbols(value).length > 0) fail();

  const result = {};
  for (const key of Object.getOwnPropertyNames(value).sort()) {
    const descriptor = ownDescriptor(value, key);
    if (!descriptor.enumerable) fail();
    Object.defineProperty(result, key, {
      value: clonePlainData(descriptor.value, depth + 1),
      enumerable: true,
      configurable: true,
      writable: true,
    });
  }
  return result;
}

function readField(value) {
  const allowed = new Set([
    'name', 'kind', 'isList', 'isRequired', 'isUnique', 'isId', 'isReadOnly',
    'isGenerated', 'isUpdatedAt', 'type', 'nativeType', 'dbName',
    'hasDefaultValue', 'default', 'relationFromFields', 'relationToFields',
    'relationName', 'relationOnDelete', 'relationOnUpdate',
  ]);
  assertPlainRecord(value, allowed);
  const field = {
    name: readString(ownValue(value, 'name')),
    kind: readString(ownValue(value, 'kind')),
    isList: readBoolean(ownValue(value, 'isList')),
    isRequired: readBoolean(ownValue(value, 'isRequired')),
    isUnique: readBoolean(ownValue(value, 'isUnique')),
    isId: readBoolean(ownValue(value, 'isId')),
    isReadOnly: readBoolean(ownValue(value, 'isReadOnly')),
    isGenerated: readBoolean(ownValue(value, 'isGenerated')),
    isUpdatedAt: readBoolean(ownValue(value, 'isUpdatedAt')),
    type: readString(ownValue(value, 'type')),
    nativeType: clonePlainData(ownValue(value, 'nativeType')),
    dbName: readNullableString(optionalOwnValue(value, 'dbName')),
    hasDefaultValue: readBoolean(ownValue(value, 'hasDefaultValue')),
    default: clonePlainData(optionalOwnValue(value, 'default', undefined)),
    relationFromFields: readOptionalStringArray(value, 'relationFromFields'),
    relationToFields: readOptionalStringArray(value, 'relationToFields'),
    relationName: readNullableString(optionalOwnValue(value, 'relationName')),
    relationOnDelete: readNullableString(optionalOwnValue(value, 'relationOnDelete')),
    relationOnUpdate: readNullableString(optionalOwnValue(value, 'relationOnUpdate')),
  };
  return field;
}

function readStringArray(value, depth) {
  return readArray(value, readString, depth);
}

function readOptionalStringArray(value, key) {
  const candidate = optionalOwnValue(value, key, undefined);
  return typeof candidate === 'undefined' ? [] : readStringArray(candidate, 0);
}

function readPrimaryKey(value) {
  if (value === null) return null;
  const allowed = new Set(['name', 'fields']);
  assertPlainRecord(value, allowed);
  return {
    name: readNullableString(ownValue(value, 'name')),
    fields: readStringArray(ownValue(value, 'fields'), 0),
  };
}

function readUniqueIndex(value) {
  const allowed = new Set(['name', 'fields']);
  assertPlainRecord(value, allowed);
  return {
    name: readNullableString(ownValue(value, 'name')),
    fields: readStringArray(ownValue(value, 'fields'), 0),
  };
}

function readModel(value) {
  const allowed = new Set([
    'name', 'dbName', 'documentation', 'isGenerated', 'schema', 'fields',
    'primaryKey', 'uniqueFields', 'uniqueIndexes',
  ]);
  assertPlainRecord(value, allowed);
  return {
    name: readString(ownValue(value, 'name')),
    dbName: readNullableString(ownValue(value, 'dbName')),
    documentation: readNullableString(optionalOwnValue(value, 'documentation')),
    isGenerated: readBoolean(ownValue(value, 'isGenerated')),
    schema: readNullableString(optionalOwnValue(value, 'schema')),
    fields: readArray(ownValue(value, 'fields'), readField, 0),
    primaryKey: readPrimaryKey(ownValue(value, 'primaryKey')),
    uniqueFields: readArray(ownValue(value, 'uniqueFields'), readStringArray, 0),
    uniqueIndexes: readArray(ownValue(value, 'uniqueIndexes'), readUniqueIndex, 0),
  };
}

function readEnumValue(value) {
  const allowed = new Set(['name', 'dbName']);
  assertPlainRecord(value, allowed);
  return {
    name: readString(ownValue(value, 'name')),
    dbName: readNullableString(ownValue(value, 'dbName')),
  };
}

function readEnum(value) {
  const allowed = new Set(['name', 'dbName', 'values']);
  assertPlainRecord(value, allowed);
  return {
    name: readString(ownValue(value, 'name')),
    dbName: readNullableString(ownValue(value, 'dbName')),
    values: readArray(ownValue(value, 'values'), readEnumValue, 0),
  };
}

function compareNames(left, right) {
  return left.name < right.name ? -1 : left.name > right.name ? 1 : 0;
}

function assertUniqueNames(entries) {
  for (let index = 1; index < entries.length; index += 1) {
    if (entries[index - 1].name === entries[index].name) fail();
  }
}

function projectDmmfUnchecked(value) {
  assertBoundedPlainData(value);
  const rootKeys = new Set(['datamodel']);
  assertPlainRecord(value, rootKeys);
  const datamodel = ownValue(value, 'datamodel');
  const datamodelKeys = new Set(['models', 'enums', 'types']);
  assertPlainRecord(datamodel, datamodelKeys);
  const models = readArray(ownValue(datamodel, 'models'), readModel, 0).sort(compareNames);
  const enums = readArray(ownValue(datamodel, 'enums'), readEnum, 0).sort(compareNames);
  readArray(optionalOwnValue(datamodel, 'types', []), clonePlainData, 0);
  assertUniqueNames(models);
  assertUniqueNames(enums);
  return { models, enums };
}

function projectDmmf(value) {
  try {
    return projectDmmfUnchecked(value);
  } catch {
    fail();
  }
}

function stableStringify(value) {
  if (value === null || typeof value === 'string' || typeof value === 'boolean' || typeof value === 'number') {
    return JSON.stringify(value);
  }
  if (Array.isArray(value)) return `[${value.map(stableStringify).join(',')}]`;
  const keys = Object.keys(value).sort();
  return `{${keys.map((key) => `${JSON.stringify(key)}:${stableStringify(value[key])}`).join(',')}}`;
}

function createFingerprint(dmmf) {
  const projection = projectDmmf(dmmf);
  const canonicalJson = stableStringify(projection);
  if (Buffer.byteLength(canonicalJson, 'utf8') > MAX_OUTPUT_BYTES) fail();
  const sha256 = crypto.createHash('sha256').update(canonicalJson, 'utf8').digest('hex');
  return { projection, canonicalJson, sha256 };
}

function isWithin(parent, candidate) {
  const relative = path.relative(parent, candidate);
  return relative === '' || (!relative.startsWith('..') && !path.isAbsolute(relative));
}

function directoryIdentity(directory) {
  const state = fs.statSync(directory);
  return { dev: state.dev, ino: state.ino };
}

function sameDirectoryIdentity(left, right) {
  return left.dev === right.dev && left.ino === right.ino;
}

function fileIdentityFromDescriptor(descriptor) {
  const state = fs.fstatSync(descriptor);
  if (!state.isFile()) fail();
  return { dev: state.dev, ino: state.ino };
}

function sameFileIdentity(left, right) {
  return left.dev === right.dev && left.ino === right.ino;
}

function isCapturedDirectory(candidate, identity) {
  try {
    if (!fs.lstatSync(candidate).isDirectory()) return false;
    return sameDirectoryIdentity(directoryIdentity(candidate), identity);
  } catch {
    return false;
  }
}

function locateCapturedDirectory(output) {
  if (isCapturedDirectory(output.parent, output.parentIdentity)) return output.parent;
  if (!isCapturedDirectory(output.parentContainer, output.parentContainerIdentity)) return null;
  for (const entry of fs.readdirSync(output.parentContainer, { withFileTypes: true })) {
    const candidate = path.join(output.parentContainer, entry.name);
    if (isCapturedDirectory(candidate, output.parentIdentity)) return candidate;
  }
  return null;
}

function removeCapturedFile(parent, name, identity) {
  if (identity === undefined) return;
  try {
    const target = path.join(parent, name);
    const state = fs.lstatSync(target);
    if (!state.isFile() || !sameFileIdentity(state, identity)) return;
    fs.unlinkSync(target);
  } catch (error) {
    if (error && typeof error === 'object' && error.code === 'ENOENT') return;
  }
}

function rollbackTemporaryResidue(output, temporaryName, temporaryIdentity) {
  try {
    const parent = locateCapturedDirectory(output);
    if (parent === null) return;
    removeCapturedFile(parent, temporaryName, temporaryIdentity);
  } catch {
    // The caller returns only the fixed sanitized failure.
  }
}

function resolveTempOutput(outputPath) {
  if (typeof outputPath !== 'string' || outputPath.length === 0 || outputPath.includes('\0') || !path.isAbsolute(outputPath)) {
    fail();
  }
  const resolved = path.resolve(outputPath);
  const name = path.basename(resolved);
  if (name.length === 0 || name === '.' || name === '..' || path.dirname(resolved) === resolved) fail();
  const temporaryRoot = fs.realpathSync(os.tmpdir());
  const parent = fs.realpathSync(path.dirname(resolved));
  if (!isWithin(temporaryRoot, parent)) fail();
  const parentContainer = fs.realpathSync(path.dirname(parent));
  return {
    temporaryRoot,
    parent,
    parentIdentity: directoryIdentity(parent),
    parentContainer,
    parentContainerIdentity: directoryIdentity(parentContainer),
    name,
    target: path.join(parent, name),
  };
}

function revalidateTempOutput(output) {
  const currentTemporaryRoot = fs.realpathSync(os.tmpdir());
  const currentParent = fs.realpathSync(output.parent);
  if (
    currentTemporaryRoot !== output.temporaryRoot
    || currentParent !== output.parent
    || !isWithin(output.temporaryRoot, currentParent)
    || !sameDirectoryIdentity(directoryIdentity(currentParent), output.parentIdentity)
  ) fail();
}

function writeAtomically(outputPath, value) {
  const output = resolveTempOutput(outputPath);
  const temporaryName = `.${output.name}.${process.pid}.${crypto.randomUUID()}.tmp`;
  const temporary = path.join(output.parent, temporaryName);
  let descriptor;
  let temporaryIdentity;
  let committed = false;
  try {
    revalidateTempOutput(output);
    const noFollow = typeof fs.constants.O_NOFOLLOW === 'number' ? fs.constants.O_NOFOLLOW : 0;
    descriptor = fs.openSync(temporary, fs.constants.O_WRONLY | fs.constants.O_CREAT | fs.constants.O_EXCL | noFollow, 0o600);
    temporaryIdentity = fileIdentityFromDescriptor(descriptor);
    revalidateTempOutput(output);
    fs.writeFileSync(descriptor, value, 'utf8');
    fs.fsyncSync(descriptor);
    fs.closeSync(descriptor);
    descriptor = undefined;
    revalidateTempOutput(output);
    fs.renameSync(temporary, output.target);
    committed = true;
  } finally {
    if (descriptor !== undefined) fs.closeSync(descriptor);
    if (!committed) rollbackTemporaryResidue(output, temporaryName, temporaryIdentity);
  }
}

function parseArguments(argv) {
  if (!Array.isArray(argv) || argv.length !== 2 || argv[0] !== '--output') fail();
  return argv[1];
}

function defaultDmmf() {
  return require('@prisma/client').Prisma.dmmf;
}

function runCli({ argv, getDmmf = defaultDmmf, stdout, stderr }) {
  try {
    const outputPath = parseArguments(argv);
    const fingerprint = createFingerprint(getDmmf());
    const payload = {
      sha256: fingerprint.sha256,
      modelCount: fingerprint.projection.models.length,
      enumCount: fingerprint.projection.enums.length,
      dmmf: fingerprint.projection,
    };
    writeAtomically(outputPath, `${stableStringify(payload)}\n`);
    stdout(`Prisma DMMF fingerprint written (${payload.modelCount} models, ${payload.enumCount} enums)`);
    return 0;
  } catch {
    stderr(CLI_FAILURE);
    return 2;
  }
}

module.exports = {
  FINGERPRINT_FAILURE,
  createFingerprint,
  projectDmmf,
  runCli,
};

if (process.argv[1] && pathToFileURL(path.resolve(process.argv[1])).href === pathToFileURL(__filename).href) {
  process.exitCode = runCli({
    argv: process.argv.slice(2),
    stdout: (message) => process.stdout.write(`${message}\n`),
    stderr: (message) => process.stderr.write(`${message}\n`),
  });
}
