import assert from 'node:assert/strict';
import {
  copyFileSync,
  mkdtempSync,
  mkdirSync,
  readFileSync,
  rmSync,
  symlinkSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { afterEach, test } from 'node:test';

const backendRoot = path.resolve(__dirname, '..');
const manifestPath = path.join(
  backendRoot,
  'architecture',
  'r8-global-module-removal.json',
);
const scannerPath = path.join(
  backendRoot,
  'scripts',
  'architecture',
  'r8-global-module-removal-scan.cjs',
);
const temporaryRoots: string[] = [];

const expectedAllowedChangedPaths = [
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
] as const;

type R8Manifest = {
  schemaVersion: number;
  baseRevision: string;
  stage: 'design' | 'strict';
  documents: {
    design: { path: string; sha256: string };
    plan: { path: string; sha256: string };
  };
  allowedChangedPaths: string[];
};

type R8Scanner = {
  R8_BASE: string;
  EXPECTED_ALLOWED_PATHS: readonly string[];
  validateR8Manifest(value: unknown): Readonly<R8Manifest>;
};

function scanner(modulePath = scannerPath): R8Scanner {
  return require(modulePath) as R8Scanner;
}

function manifest(): R8Manifest {
  return JSON.parse(readFileSync(manifestPath, 'utf8')) as R8Manifest;
}

afterEach(() => {
  for (const root of temporaryRoots.splice(0)) rmSync(root, { recursive: true, force: true });
});

test('R8 design-stage manifest is exact, hash-bound, and deeply immutable', () => {
  const r8 = scanner();
  const value = manifest();
  const validated = r8.validateR8Manifest(value);

  assert.equal(r8.R8_BASE, 'c2b728bfe54304562923facfb6094e0de04c0b27');
  assert.deepEqual(r8.EXPECTED_ALLOWED_PATHS, expectedAllowedChangedPaths);
  assert.deepEqual(Object.keys(value), [
    'schemaVersion',
    'baseRevision',
    'stage',
    'documents',
    'allowedChangedPaths',
  ]);
  assert.deepEqual(validated, {
    schemaVersion: 1,
    baseRevision: 'c2b728bfe54304562923facfb6094e0de04c0b27',
    stage: 'design',
    documents: {
      design: {
        path: 'docs/superpowers/specs/2026-08-27-modular-monolith-r8-global-module-removal-design.md',
        sha256: 'eb6d585694c7f2b571ec6922db9765ef0426c94898d9f88fa22a14c7763768a5',
      },
      plan: {
        path: 'docs/superpowers/plans/2026-08-27-modular-monolith-r8-global-module-removal.md',
        sha256: '9afe10c044426df84ae818d5603762f97e39b5fd4d5a81802128ac262ea069ca',
      },
    },
    allowedChangedPaths: expectedAllowedChangedPaths,
  });
  assert.equal(Object.isFrozen(validated), true);
  assert.equal(Object.isFrozen(validated.documents), true);
  assert.equal(Object.isFrozen(validated.documents.design), true);
  assert.equal(Object.isFrozen(validated.documents.plan), true);
  assert.equal(Object.isFrozen(validated.allowedChangedPaths), true);

  value.allowedChangedPaths[0] = 'docs/attacker.md';
  value.documents.design.sha256 = '0'.repeat(64);
  assert.deepEqual(validated.allowedChangedPaths, expectedAllowedChangedPaths);
  assert.equal(
    validated.documents.design.sha256,
    'eb6d585694c7f2b571ec6922db9765ef0426c94898d9f88fa22a14c7763768a5',
  );

  const strict = manifest();
  strict.stage = 'strict';
  assert.equal(r8.validateR8Manifest(strict).stage, 'strict');
});

test('R8 validator rejects non-plain, sparse, accessor, and unknown-key data', () => {
  const r8 = scanner();
  const valid = manifest();
  const sparse = structuredClone(valid);
  sparse.allowedChangedPaths = new Array(expectedAllowedChangedPaths.length);
  const accessor = structuredClone(valid) as R8Manifest & { extra?: boolean };
  Object.defineProperty(accessor, 'stage', { get: () => 'design', enumerable: true });
  const arrayAccessor = structuredClone(valid);
  Object.defineProperty(arrayAccessor.allowedChangedPaths, '0', {
    get: () => expectedAllowedChangedPaths[0],
    enumerable: true,
  });
  const unknown = structuredClone(valid) as R8Manifest & { extra?: boolean };
  unknown.extra = true;

  for (const candidate of [
    null,
    [],
    new Date(),
    new Proxy(valid, {}),
    sparse,
    accessor,
    arrayAccessor,
    unknown,
  ]) {
    assert.throws(() => r8.validateR8Manifest(candidate), /R8 manifest|plain|dense|accessor|key/i);
  }
});

test('R8 validator rejects a junction in an allowed-path ancestry', () => {
  const fixtureRoot = mkdtempSync(path.join(tmpdir(), 'aarast-r8-manifest-junction-'));
  const outsideRoot = mkdtempSync(path.join(tmpdir(), 'aarast-r8-manifest-outside-'));
  temporaryRoots.push(fixtureRoot, outsideRoot);
  const fixtureScannerPath = path.join(
    fixtureRoot,
    'backend',
    'scripts',
    'architecture',
    'r8-global-module-removal-scan.cjs',
  );
  mkdirSync(path.dirname(fixtureScannerPath), { recursive: true });
  copyFileSync(scannerPath, fixtureScannerPath);
  symlinkSync(outsideRoot, path.join(fixtureRoot, 'docs'), process.platform === 'win32' ? 'junction' : 'dir');

  assert.throws(
    () => scanner(fixtureScannerPath).validateR8Manifest(manifest()),
    /reparse|junction|symbolic/i,
  );
});
