'use strict';

const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const { execFileSync } = require('node:child_process');
const { types: utilTypes } = require('node:util');

const R3_BASE = '6b06eb096aca8cc6684d365d16e05d4cd8529898';
const ALLOWED_PATHS = Object.freeze([
  'backend/.dependency-cruiser.cjs',
  'backend/architecture/r3-context-boundaries.json',
  'backend/package.json',
  'backend/scripts/architecture/ports-scan.cjs',
  'backend/scripts/architecture/r3-context-scan.cjs',
  'backend/scripts/architecture/r3-scope.cjs',
  'backend/test/architecture-dependencies.test.ts',
  'backend/test/architecture-ports.test.ts',
  'backend/test/architecture-r3-contexts.test.ts',
  'backend/test/architecture-r3-scope.test.ts',
  'docs/SCRIPTS.md',
  'docs/superpowers/plans/2026-08-14-modular-monolith-r3-nest-boundaries.md',
  'docs/superpowers/specs/2026-08-14-modular-monolith-r3-nest-boundaries-design.md',
]);

function assertPlainObject(value, label) {
  if (!value || typeof value !== 'object' || Array.isArray(value) || !utilTypes.isProxy(value)) {
    if (value && typeof value === 'object' && !Array.isArray(value) && !utilTypes.isProxy(value)
      && Object.getPrototypeOf(value) === Object.prototype) {
      for (const key of Object.keys(value)) {
        const descriptor = Object.getOwnPropertyDescriptor(value, key);
        if (!descriptor || !Object.prototype.hasOwnProperty.call(descriptor, 'value')) {
          throw new Error(`${label} must contain data properties only; accessor found`);
        }
      }
      return value;
    }
    throw new Error(`${label} must be a plain object`);
  }
  throw new Error(`${label} must be a plain object`);
}

function validatePathList(value, label) {
  if (!Array.isArray(value)) throw new Error(`${label} must be an array`);
  for (let index = 0; index < value.length; index += 1) {
    if (!Object.prototype.hasOwnProperty.call(value, index)) throw new Error(`${label} must be dense`);
    const item = value[index];
    if (typeof item !== 'string' || !item || item.includes('\\') || path.posix.isAbsolute(item)
      || item.split('/').includes('..') || item.split('/').includes('.')) {
      throw new Error(`${label} contains an invalid path`);
    }
  }
  if (new Set(value).size !== value.length) throw new Error(`${label} contains a duplicate path`);
  return [...value];
}

function assertAllowedPathsMatch(manifestPaths, scopePaths) {
  const manifestAllowlist = validatePathList(manifestPaths, 'manifest allowlist');
  const scopeAllowlist = validatePathList(scopePaths, 'scope allowlist');
  if (JSON.stringify(manifestAllowlist) !== JSON.stringify(scopeAllowlist)) {
    throw new Error('R3 allowlist drift detected');
  }
}

function validateScopeSnapshot(value) {
  const snapshot = assertPlainObject(value, 'scope snapshot');
  if (snapshot.baseRef !== R3_BASE) throw new Error('scope base does not equal immutable R3 base');
  const allowedPaths = validatePathList(snapshot.allowedPaths, 'allowed paths');
  const changedPaths = validatePathList(snapshot.changedPaths, 'changed paths');
  const allowed = new Set(allowedPaths);
  const unexpectedPaths = changedPaths.filter((item) => !allowed.has(item));
  if (unexpectedPaths.length > 0) throw new Error('changed path is outside R3 scope');
  return Object.freeze({
    baseRef: snapshot.baseRef,
    allowedPaths: Object.freeze(allowedPaths),
    changedPaths: Object.freeze(changedPaths),
    unexpectedPaths: Object.freeze([]),
    ok: true,
  });
}

function gitLines(repositoryRoot, args) {
  const text = execFileSync('git', args, { cwd: repositoryRoot, encoding: 'utf8' });
  return text.split(/\r?\n/u).map((item) => item.trim()).filter(Boolean);
}

function isInside(parent, candidate) {
  const relative = path.relative(parent, candidate);
  return relative === '' || (!path.isAbsolute(relative) && relative !== '..' && !relative.startsWith(`..${path.sep}`));
}

function assertPlainData(value, label, seen = new Set(), depth = 0) {
  if (value === null || typeof value === 'string' || typeof value === 'boolean'
      || (typeof value === 'number' && Number.isFinite(value))) return;
  if (!value || typeof value !== 'object' || utilTypes.isProxy(value) || depth > 32 || seen.has(value)) {
    throw new Error(`${label} must be bounded plain data`);
  }
  seen.add(value);
  if (Array.isArray(value)) {
    if (value.length > 10000) throw new Error(`${label} is oversized`);
    for (let index = 0; index < value.length; index += 1) {
      if (!Object.prototype.hasOwnProperty.call(value, index)) throw new Error(`${label} must be dense`);
      assertPlainData(value[index], `${label}[${index}]`, seen, depth + 1);
    }
  } else {
    if (Object.getPrototypeOf(value) !== Object.prototype) throw new Error(`${label} must be plain data`);
    const keys = Object.keys(value);
    if (keys.length > 10000) throw new Error(`${label} is oversized`);
    for (const key of keys) {
      const descriptor = Object.getOwnPropertyDescriptor(value, key);
      if (!descriptor || !Object.prototype.hasOwnProperty.call(descriptor, 'value')) {
        throw new Error(`${label} must contain data properties only`);
      }
      assertPlainData(descriptor.value, `${label}.${key}`, seen, depth + 1);
    }
  }
  seen.delete(value);
}

function canonicalReportParent(reportPath, expectedParent = null) {
  const realpath = fs.realpathSync.native || fs.realpathSync;
  const canonicalTemp = realpath(os.tmpdir());
  const parent = path.dirname(reportPath);
  const relative = path.relative(canonicalTemp, parent);
  if (!isInside(canonicalTemp, parent)) {
    throw new Error('scope report path must be inside the canonical OS temporary directory');
  }
  let cursor = canonicalTemp;
  for (const segment of relative.split(path.sep).filter(Boolean)) {
    cursor = path.join(cursor, segment);
    const status = fs.lstatSync(cursor);
    if (status.isSymbolicLink()) throw new Error('scope report path contains a symbolic link or junction');
    if (!status.isDirectory()) throw new Error('scope report parent is not a directory');
    const canonicalCursor = realpath(cursor);
    if (!isInside(canonicalTemp, canonicalCursor) || path.relative(cursor, canonicalCursor) !== '') {
      throw new Error('scope report path contains a reparse redirect');
    }
  }
  const canonicalParent = realpath(parent);
  if (!isInside(canonicalTemp, canonicalParent) || path.relative(parent, canonicalParent) !== '') {
    throw new Error('scope report parent is not canonical');
  }
  if (expectedParent !== null && canonicalParent !== expectedParent) {
    throw new Error('scope report parent changed before commit');
  }
  return canonicalParent;
}

function writeAtomicJson(reportPath, result, dependencies = {}) {
  if (typeof reportPath !== 'string' || !path.isAbsolute(reportPath)
      || path.normalize(reportPath) !== reportPath || path.extname(reportPath).toLowerCase() !== '.json') {
    throw new Error('scope report path must be an absolute JSON path');
  }
  assertPlainData(result, 'scope report');
  const hooks = assertPlainObject(dependencies, 'scope report dependencies');
  if (hooks.beforeCommit !== undefined && typeof hooks.beforeCommit !== 'function') {
    throw new Error('scope report beforeCommit hook is invalid');
  }
  const canonicalParent = canonicalReportParent(reportPath);
  if (fs.existsSync(reportPath)) throw new Error('scope report destination already exists');
  let stagingDirectory;
  let stagingIdentity;
  let canonicalStagingDirectory;
  let temporaryPath;
  let descriptor;
  let ownedIdentity;
  let published = false;
  const identityOf = (status) => `${status.dev}:${status.ino}`;
  const removeOwnedTemporary = () => {
    if (!ownedIdentity || !temporaryPath) return;
    try {
      const status = fs.lstatSync(temporaryPath, { bigint: true });
      if (identityOf(status) === ownedIdentity) fs.unlinkSync(temporaryPath);
    } catch (error) {
      if (!error || error.code !== 'ENOENT') throw error;
    }
  };
  const removeOwnedStagingDirectory = () => {
    if (!stagingDirectory || !stagingIdentity) return;
    try {
      const status = fs.lstatSync(stagingDirectory, { bigint: true });
      if (identityOf(status) !== stagingIdentity || !status.isDirectory()
          || status.isSymbolicLink() || fs.readdirSync(stagingDirectory).length !== 0) return;
      fs.rmdirSync(stagingDirectory);
    } catch (error) {
      if (!error || !['ENOENT', 'ENOTEMPTY', 'EEXIST'].includes(error.code)) throw error;
    }
  };
  try {
    const payload = `${JSON.stringify(result, null, 2)}\n`;
    stagingDirectory = fs.mkdtempSync(path.join(
      path.dirname(reportPath), `.${path.basename(reportPath)}.${process.pid}.stage-`,
    ));
    fs.chmodSync(stagingDirectory, 0o700);
    const openedStagingStatus = fs.lstatSync(stagingDirectory, { bigint: true });
    if (!openedStagingStatus.isDirectory() || openedStagingStatus.isSymbolicLink()) {
      throw new Error('scope report staging directory is invalid');
    }
    stagingIdentity = identityOf(openedStagingStatus);
    temporaryPath = path.join(
      stagingDirectory, `${crypto.randomBytes(16).toString('hex')}.tmp`,
    );
    canonicalStagingDirectory = canonicalReportParent(temporaryPath);
    if (path.dirname(canonicalStagingDirectory) !== canonicalParent
        || path.relative(stagingDirectory, canonicalStagingDirectory) !== '') {
      throw new Error('scope report staging directory escaped its canonical parent');
    }
    descriptor = fs.openSync(temporaryPath, 'wx+', 0o600);
    const openedStatus = fs.fstatSync(descriptor, { bigint: true });
    if (!openedStatus.isFile()) throw new Error('scope report temporary identity is invalid');
    ownedIdentity = identityOf(openedStatus);
    fs.writeFileSync(descriptor, payload, 'utf8');
    fs.fsyncSync(descriptor);
    const writtenStatus = fs.fstatSync(descriptor, { bigint: true });
    const payloadBytes = Buffer.byteLength(payload, 'utf8');
    if (identityOf(writtenStatus) !== ownedIdentity || writtenStatus.size !== BigInt(payloadBytes)) {
      throw new Error('scope report temporary identity changed while writing');
    }
    const payloadBuffer = Buffer.alloc(payloadBytes);
    let offset = 0;
    while (offset < payloadBuffer.length) {
      const bytesRead = fs.readSync(
        descriptor,
        payloadBuffer,
        offset,
        payloadBuffer.length - offset,
        offset,
      );
      if (bytesRead === 0) throw new Error('scope report descriptor read was incomplete');
      offset += bytesRead;
    }
    const reparsed = JSON.parse(payloadBuffer.toString('utf8'));
    if (`${JSON.stringify(reparsed, null, 2)}\n` !== payload) throw new Error('scope report reparse mismatch');
    if (hooks.beforeCommit) hooks.beforeCommit();
    canonicalReportParent(reportPath, canonicalParent);
    canonicalReportParent(temporaryPath, canonicalStagingDirectory);
    if (fs.existsSync(reportPath)) throw new Error('scope report destination race detected');
    const currentStagingStatus = fs.lstatSync(stagingDirectory, { bigint: true });
    const temporaryStatus = fs.lstatSync(temporaryPath, { bigint: true });
    if (!currentStagingStatus.isDirectory() || currentStagingStatus.isSymbolicLink()
        || identityOf(currentStagingStatus) !== stagingIdentity
        || !temporaryStatus.isFile() || temporaryStatus.isSymbolicLink()
        || identityOf(temporaryStatus) !== ownedIdentity) {
      throw new Error('scope report staging identity changed before commit');
    }
    // Within the documented local-tool threat model, this is the one atomic no-clobber
    // namespace commit. The complete payload was flushed and reparsed before this point.
    fs.linkSync(temporaryPath, reportPath);
    published = true;
  } finally {
    if (descriptor !== undefined) fs.closeSync(descriptor);
    removeOwnedTemporary();
    removeOwnedStagingDirectory();
  }
  if (!published) throw new Error('scope report was not published');
}

function validateR3Scope(options) {
  const input = assertPlainObject(options, 'scope options');
  if (input.baseRef !== R3_BASE) throw new Error('scope base does not equal immutable R3 base');
  if (typeof input.repositoryRoot !== 'string' || !path.isAbsolute(input.repositoryRoot)) {
    throw new Error('repository root must be absolute');
  }
  const manifest = JSON.parse(fs.readFileSync(path.join(
    input.repositoryRoot,
    'backend',
    'architecture',
    'r3-context-boundaries.json',
  ), 'utf8'));
  assertAllowedPathsMatch(manifest.allowedChangedPaths, ALLOWED_PATHS);
  const tracked = gitLines(input.repositoryRoot, ['diff', '--name-only', R3_BASE, '--']);
  const untracked = gitLines(input.repositoryRoot, ['ls-files', '--others', '--exclude-standard']);
  const changedPaths = [...new Set([...tracked, ...untracked])].sort();
  const snapshot = validateScopeSnapshot({
    baseRef: input.baseRef,
    allowedPaths: [...ALLOWED_PATHS],
    changedPaths,
  });
  const reportPath = input.reportPath === undefined
    ? path.join((fs.realpathSync.native || fs.realpathSync)(os.tmpdir()), `aarast-r3-scope-${crypto.randomUUID()}.json`)
    : input.reportPath;
  const result = { ...snapshot, reportPath };
  writeAtomicJson(reportPath, result);
  return Object.freeze(result);
}

function runCli(dependencies = {}) {
  const argv = dependencies.argv || process.argv.slice(2);
  const stdout = dependencies.stdout || ((message) => process.stdout.write(`${message}\n`));
  const stderr = dependencies.stderr || ((message) => process.stderr.write(`${message}\n`));
  const validate = dependencies.validate || validateR3Scope;
  try {
    const hasReportPath = argv.length === 5 && argv[3] === '--report-path';
    if (![3, 5].includes(argv.length) || argv[0] !== '--check' || argv[1] !== '--base-ref'
        || argv[2] !== R3_BASE || (argv.length === 5 && !hasReportPath)) {
      throw new Error('invalid arguments');
    }
    const result = validate({
      repositoryRoot: path.resolve(__dirname, '../../..'),
      baseRef: argv[2],
      ...(hasReportPath ? { reportPath: argv[4] } : {}),
    });
    stdout(`PASS - R3 scope: changed=${result.changedPaths.length}, unexpected=0, base=${R3_BASE}`);
    return 0;
  } catch {
    stderr('ERROR - R3 scope validation failed');
    return 2;
  }
}

module.exports = {
  R3_BASE,
  ALLOWED_PATHS,
  assertAllowedPathsMatch,
  writeAtomicJson,
  validateR3Scope,
  validateScopeSnapshot,
  runCli,
};
if (require.main === module) process.exitCode = runCli();
