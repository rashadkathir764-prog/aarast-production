const fs = require('node:fs');
const path = require('node:path');

const SCHEMA_FILES_FAILURE = 'invalid Prisma schema files';
const CLI_FAILURE = 'ERROR - Prisma schema loader failed';
const MAX_MANIFEST_BYTES = 1024 * 1024;
const MAX_SCHEMA_FILE_BYTES = 8 * 1024 * 1024;
const MAX_COMBINED_BYTES = 32 * 1024 * 1024;
const MAX_OWNERS = 64;
const MAX_NAMES = 10_000;
const MAX_STRING_LENGTH = 1024;

function fail() {
  throw new Error(SCHEMA_FILES_FAILURE);
}

function ownDescriptor(value, key) {
  const descriptor = Object.getOwnPropertyDescriptor(value, key);
  if (!descriptor || !Object.prototype.hasOwnProperty.call(descriptor, 'value')) fail();
  return descriptor;
}

function ownValue(value, key) {
  return ownDescriptor(value, key).value;
}

function assertPlainRecord(value, expectedKeys) {
  if (value === null || typeof value !== 'object' || Object.getPrototypeOf(value) !== Object.prototype) fail();
  if (Object.getOwnPropertySymbols(value).length !== 0) fail();
  const names = Object.getOwnPropertyNames(value);
  if (names.length !== expectedKeys.length) fail();
  for (const key of expectedKeys) {
    if (!names.includes(key)) fail();
    if (!ownDescriptor(value, key).enumerable) fail();
  }
}

function readDenseArray(value, maximum, readEntry) {
  if (!Array.isArray(value) || Object.getPrototypeOf(value) !== Array.prototype) fail();
  if (Object.getOwnPropertySymbols(value).length !== 0) fail();
  const length = ownValue(value, 'length');
  if (!Number.isSafeInteger(length) || length < 0 || length > maximum) fail();
  if (ownDescriptor(value, 'length').enumerable) fail();
  const names = Object.getOwnPropertyNames(value);
  if (names.length !== length + 1 || !names.includes('length')) fail();
  const result = [];
  for (let index = 0; index < length; index += 1) {
    const descriptor = ownDescriptor(value, String(index));
    if (!descriptor.enumerable) fail();
    result.push(readEntry(descriptor.value));
  }
  return result;
}

function readString(value, pattern) {
  if (typeof value !== 'string' || value.length === 0 || value.length > MAX_STRING_LENGTH || !pattern.test(value)) fail();
  return value;
}

function readName(value) {
  return readString(value, /^[A-Za-z][A-Za-z0-9_]*$/);
}

function readNameArray(value) {
  return readDenseArray(value, MAX_NAMES, readName);
}

function assertUnique(values) {
  if (new Set(values).size !== values.length) fail();
}

function validateManifestUnchecked(value) {
  assertPlainRecord(value, ['schemaVersion', 'splitBaseRevision', 'baseFile', 'owners', 'modelOrder']);
  if (ownValue(value, 'schemaVersion') !== 1) fail();
  const splitBaseRevision = readString(ownValue(value, 'splitBaseRevision'), /^[0-9a-f]{40}$/);
  const baseFile = readString(ownValue(value, 'baseFile'), /^_[a-z][a-z0-9-]*\.prisma$/);
  const owners = readDenseArray(ownValue(value, 'owners'), MAX_OWNERS, (entry) => {
    assertPlainRecord(entry, ['owner', 'file', 'models', 'enums']);
    return {
      owner: readString(ownValue(entry, 'owner'), /^[a-z][a-z0-9-]*$/),
      file: readString(ownValue(entry, 'file'), /^[a-z][a-z0-9-]*\.prisma$/),
      models: readNameArray(ownValue(entry, 'models')),
      enums: readNameArray(ownValue(entry, 'enums')),
    };
  });
  if (owners.length === 0) fail();
  const modelOrder = readNameArray(ownValue(value, 'modelOrder'));
  const ownerNames = owners.map((entry) => entry.owner);
  const files = owners.map((entry) => entry.file);
  const models = owners.flatMap((entry) => entry.models);
  const enums = owners.flatMap((entry) => entry.enums);
  assertUnique(ownerNames);
  assertUnique([baseFile, ...files]);
  assertUnique(models);
  assertUnique(enums);
  assertUnique(modelOrder);
  if (models.length !== modelOrder.length) fail();
  const orderedModels = [...models].sort();
  const sortedModelOrder = [...modelOrder].sort();
  for (let index = 0; index < orderedModels.length; index += 1) {
    if (orderedModels[index] !== sortedModelOrder[index]) fail();
  }
  return { schemaVersion: 1, splitBaseRevision, baseFile, owners, modelOrder };
}

function validateManifest(value) {
  try {
    return validateManifestUnchecked(value);
  } catch {
    fail();
  }
}

function isWithin(parent, candidate) {
  const relative = path.relative(parent, candidate);
  return relative === '' || (!relative.startsWith('..') && !path.isAbsolute(relative));
}

function sameIdentity(left, right) {
  return left.dev === right.dev
    && left.ino === right.ino
    && left.size === right.size
    && left.mtimeMs === right.mtimeMs
    && left.ctimeMs === right.ctimeMs;
}

function identityFromState(state) {
  return {
    dev: state.dev,
    ino: state.ino,
    size: state.size,
    mtimeMs: state.mtimeMs,
    ctimeMs: state.ctimeMs,
  };
}

function capturePlainPath(absolute, expectedType) {
  const resolved = path.resolve(absolute);
  const state = fs.lstatSync(resolved);
  if (state.isSymbolicLink()) fail();
  if (expectedType === 'file' ? !state.isFile() : !state.isDirectory()) fail();
  if (fs.realpathSync(resolved) !== resolved) fail();
  return identityFromState(state);
}

function assertCapturedPath(absolute, expectedType, identity) {
  const current = capturePlainPath(absolute, expectedType);
  if (!sameIdentity(current, identity)) fail();
}

function descriptorIdentity(descriptor) {
  const state = fs.fstatSync(descriptor);
  if (!state.isFile()) fail();
  return identityFromState(state);
}

function openCapturedFile(absolute, identity) {
  assertCapturedPath(absolute, 'file', identity);
  const noFollow = typeof fs.constants.O_NOFOLLOW === 'number' ? fs.constants.O_NOFOLLOW : 0;
  const descriptor = fs.openSync(absolute, fs.constants.O_RDONLY | noFollow);
  const openedIdentity = descriptorIdentity(descriptor);
  if (!sameIdentity(openedIdentity, identity)) {
    fs.closeSync(descriptor);
    fail();
  }
  return { absolute, descriptor, identity: openedIdentity };
}

function assertDescriptorSnapshot(opened) {
  if (!sameIdentity(descriptorIdentity(opened.descriptor), opened.identity)) fail();
}

function readOpenedFile(opened, maximumBytes) {
  assertDescriptorSnapshot(opened);
  const text = fs.readFileSync(opened.descriptor, 'utf8');
  assertDescriptorSnapshot(opened);
  if (Buffer.byteLength(text, 'utf8') > maximumBytes) fail();
  return text;
}

function closeOpenedFiles(openedFiles) {
  let failed = false;
  for (const opened of [...openedFiles].reverse()) {
    try {
      fs.closeSync(opened.descriptor);
    } catch {
      failed = true;
    }
  }
  if (failed) fail();
}

function readCapturedFile(absolute, identity, maximumBytes) {
  const opened = openCapturedFile(absolute, identity);
  let text;
  try {
    text = readOpenedFile(opened, maximumBytes);
    assertCapturedPath(absolute, 'file', identity);
  } finally {
    closeOpenedFiles([opened]);
  }
  return text;
}

function parseOptions(options) {
  if (typeof options === 'undefined') {
    return { backendRoot: path.resolve(__dirname, '..', '..') };
  }
  assertPlainRecord(options, ['backendRoot']);
  const backendRoot = ownValue(options, 'backendRoot');
  if (typeof backendRoot !== 'string' || backendRoot.length === 0 || backendRoot.includes('\0') || !path.isAbsolute(backendRoot)) fail();
  return { backendRoot };
}

function readPrismaSchemaFilesUnchecked(options) {
  const parsedOptions = parseOptions(options);
  const backendRoot = fs.realpathSync(parsedOptions.backendRoot);
  if (!path.isAbsolute(backendRoot)) fail();
  const manifestPath = path.join(backendRoot, 'architecture', 'prisma-schema-layout.json');
  const schemaRoot = path.join(backendRoot, 'prisma', 'schema');
  if (!isWithin(backendRoot, manifestPath) || !isWithin(backendRoot, schemaRoot)) fail();

  const manifestIdentity = capturePlainPath(manifestPath, 'file');
  if (manifestIdentity.size > MAX_MANIFEST_BYTES) fail();
  const manifestText = readCapturedFile(manifestPath, manifestIdentity, MAX_MANIFEST_BYTES);
  const manifest = validateManifestUnchecked(JSON.parse(manifestText));

  const schemaRootIdentity = capturePlainPath(schemaRoot, 'directory');
  const expectedNames = [manifest.baseFile, ...manifest.owners.map((entry) => entry.file)];
  const entries = fs.readdirSync(schemaRoot, { withFileTypes: true });
  const actualNames = entries.map((entry) => entry.name).sort();
  const sortedExpected = [...expectedNames].sort();
  if (actualNames.length !== sortedExpected.length) fail();
  for (let index = 0; index < actualNames.length; index += 1) {
    if (actualNames[index] !== sortedExpected[index]) fail();
  }
  for (const entry of entries) {
    if (!entry.isFile() || entry.isSymbolicLink()) fail();
  }

  const captures = expectedNames.map((file) => {
    const absolute = path.join(schemaRoot, file);
    if (path.dirname(absolute) !== schemaRoot || !isWithin(schemaRoot, absolute)) fail();
    const identity = capturePlainPath(absolute, 'file');
    if (identity.size > MAX_SCHEMA_FILE_BYTES) fail();
    return { file, absolute, identity };
  });
  assertCapturedPath(schemaRoot, 'directory', schemaRootIdentity);

  const openedFiles = [];
  let texts;
  try {
    for (const capture of captures) {
      openedFiles.push(openCapturedFile(capture.absolute, capture.identity));
    }
    assertCapturedPath(schemaRoot, 'directory', schemaRootIdentity);
    texts = openedFiles.map((opened) => readOpenedFile(opened, MAX_SCHEMA_FILE_BYTES));
    for (const opened of openedFiles) assertDescriptorSnapshot(opened);
    for (const capture of captures) {
      assertCapturedPath(capture.absolute, 'file', capture.identity);
    }
    assertCapturedPath(schemaRoot, 'directory', schemaRootIdentity);
    assertCapturedPath(manifestPath, 'file', manifestIdentity);
  } finally {
    closeOpenedFiles(openedFiles);
  }

  const files = [
    {
      file: manifest.baseFile,
      owner: null,
      models: [],
      enums: [],
      text: texts[0],
    },
    ...manifest.owners.map((entry, index) => ({
      file: entry.file,
      owner: entry.owner,
      models: [...entry.models],
      enums: [...entry.enums],
      text: texts[index + 1],
    })),
  ];
  const combinedText = texts.join('\n');
  if (Buffer.byteLength(combinedText, 'utf8') > MAX_COMBINED_BYTES) fail();
  return {
    baseFile: manifest.baseFile,
    files,
    combinedText,
    modelOrder: [...manifest.modelOrder],
  };
}

function readPrismaSchemaFiles(options) {
  try {
    return readPrismaSchemaFilesUnchecked(options);
  } catch {
    fail();
  }
}

function runCli(dependencies = {}) {
  const argv = dependencies.argv ?? process.argv.slice(2);
  const stdout = dependencies.stdout ?? ((message) => process.stdout.write(`${message}\n`));
  const stderr = dependencies.stderr ?? ((message) => process.stderr.write(`${message}\n`));
  try {
    if (!Array.isArray(argv) || argv.length !== 0) fail();
    const result = readPrismaSchemaFiles();
    stdout(`PASS - Prisma schema loader: ${result.files.length} files`);
    return 0;
  } catch {
    stderr(CLI_FAILURE);
    return 2;
  }
}

if (require.main === module) {
  process.exitCode = runCli();
}

module.exports = {
  CLI_FAILURE,
  SCHEMA_FILES_FAILURE,
  readPrismaSchemaFiles,
  runCli,
  validateManifest,
};
