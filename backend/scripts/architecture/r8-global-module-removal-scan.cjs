'use strict';

const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const { types: utilTypes } = require('node:util');

const R8_BASE = 'c2b728bfe54304562923facfb6094e0de04c0b27';
const REPOSITORY_ROOT = path.resolve(__dirname, '../../..');
const EXPECTED_DOCUMENTS = Object.freeze({
  design: Object.freeze({
    path: 'docs/superpowers/specs/2026-08-27-modular-monolith-r8-global-module-removal-design.md',
    sha256: 'eb6d585694c7f2b571ec6922db9765ef0426c94898d9f88fa22a14c7763768a5',
  }),
  plan: Object.freeze({
    path: 'docs/superpowers/plans/2026-08-27-modular-monolith-r8-global-module-removal.md',
    sha256: '9afe10c044426df84ae818d5603762f97e39b5fd4d5a81802128ac262ea069ca',
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
  'backend/scripts/architecture/r7-collaboration-relocation-scan.cjs',
  'backend/scripts/architecture/r8-global-module-removal-scan.cjs',
  'backend/scripts/security/prisma-config-merge-security.cjs',
  'backend/src/application-composition/application-outbox-runtime.module.ts',
  'backend/src/conversations/conversation-realtime.module.ts',
  'backend/src/platform/database/prisma.module.ts',
  'backend/test/architecture-ports.test.ts',
  'backend/test/architecture-r1-layout.test.ts',
  'backend/test/architecture-r3-composition.test.ts',
  'backend/test/architecture-r3-contexts.test.ts',
  'backend/test/architecture-r3-scope.test.ts',
  'backend/test/architecture-r7-collaboration-relocation.test.ts',
  'backend/test/architecture-r8-global-module-removal.test.ts',
  'backend/test/prisma-config-merge-security.test.ts',
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
    ['schemaVersion', 'baseRevision', 'stage', 'documents', 'allowedChangedPaths'],
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
  return Object.freeze({
    schemaVersion: 1,
    baseRevision: R8_BASE,
    stage: value.stage,
    documents: Object.freeze({
      design: Object.freeze({ ...EXPECTED_DOCUMENTS.design }),
      plan: Object.freeze({ ...EXPECTED_DOCUMENTS.plan }),
    }),
    allowedChangedPaths: Object.freeze([...allowedChangedPaths]),
  });
}

module.exports = {
  R8_BASE,
  EXPECTED_ALLOWED_PATHS,
  validateR8Manifest,
};
