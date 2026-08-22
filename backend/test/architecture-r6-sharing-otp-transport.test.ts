import assert from 'node:assert/strict';
import {
  copyFileSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { afterEach, test } from 'node:test';

const backendRoot = path.resolve(__dirname, '..');
const repositoryRoot = path.resolve(backendRoot, '..');
const manifestPath = path.join(
  backendRoot,
  'architecture',
  'r6-sharing-otp-transport.json',
);
const scannerPath = path.join(
  backendRoot,
  'scripts',
  'architecture',
  'r6-sharing-otp-transport-scan.cjs',
);
const r6Base = 'ce0c0d19824bff79d91417e2fe4617914c6bcd70';

const expectedAllowedChangedPaths = [
  'ARCHITECTURE.md',
  'backend/architecture/r3-context-boundaries.json',
  'backend/architecture/r6-sharing-otp-transport.json',
  'backend/package.json',
  'backend/scripts/architecture/r3-context-scan.cjs',
  'backend/scripts/architecture/r3-scope.cjs',
  'backend/scripts/architecture/r5-identity-scan.cjs',
  'backend/scripts/architecture/r6-sharing-otp-transport-scan.cjs',
  'backend/src/modules/collaboration/internal/collaboration-services.internal.module.ts',
  'backend/src/modules/identity/identity.module.ts',
  'backend/src/modules/identity/internal/identity-transient-delivery.adapter.ts',
  'backend/src/modules/identity/internal/identity-transient-delivery.internal.module.ts',
  'backend/src/modules/identity/public/identity-transient-delivery-public.module.ts',
  'backend/src/modules/identity/public/identity-transient-delivery.port.ts',
  'backend/src/sharing/invitation-delivery.service.ts',
  'backend/test/architecture-r3-contexts.test.ts',
  'backend/test/architecture-r3-scope.test.ts',
  'backend/test/architecture-r4-planning-finance-boundary.test.ts',
  'backend/test/architecture-r5-identity-relocation.test.ts',
  'backend/test/architecture-r6-sharing-otp-transport.test.ts',
  'backend/test/invite-delivery.test.ts',
  'docs/README.md',
  'docs/SCRIPTS.md',
  'docs/project/DECISIONS.md',
  'docs/project/EXECUTION_PLAN.md',
  'docs/project/STATUS.md',
  'docs/qa/README.md',
  'docs/superpowers/plans/2026-08-22-modular-monolith-r6-sharing-otp-transport-port-completion.md',
  'docs/superpowers/plans/2026-08-22-modular-monolith-r6-sharing-otp-transport-port.md',
  'docs/superpowers/specs/2026-08-22-modular-monolith-r6-sharing-otp-transport-port-completion.md',
  'docs/superpowers/specs/2026-08-22-modular-monolith-r6-sharing-otp-transport-port-design.md',
];

type R6Manifest = {
  schemaVersion: number;
  baseRevision: string;
  stage: string;
  currentConcreteDependency: {
    consumer: string;
    transport: string;
    declarations: string[];
  };
  targetBoundary: {
    adapterPath: string;
    collaborationModulePath: string;
    consumerPath: string;
    identityModulePath: string;
    implementationToken: string;
    inputType: string;
    internalModulePath: string;
    portInterface: string;
    publicErrors: string[];
    publicModulePath: string;
    publicPortPath: string;
    token: string;
  };
  protectedFiles: Array<{ path: string; sha256: string }>;
  expectedBaselines: {
    dependencyRecords: number;
    ownershipRecords: number;
    ownershipOccurrences: number;
    concreteTransportImports: Record<string, number>;
  };
  allowedChangedPaths: string[];
};

type R6Scanner = {
  R6_BASE: string;
  STAGES: readonly string[];
  validateR6Manifest(value: unknown): R6Manifest;
  scanR6SharingOtpTransport(options: {
    repositoryRoot: string;
    manifest: unknown;
    readBaseFile?: (relativePath: string) => Buffer;
  }): {
    ok: boolean;
    stage: string;
    concreteImports: number;
    protectedFiles: number;
  };
  runCli(dependencies?: Record<string, unknown>): number;
};

const temporaryRoots: string[] = [];

function scanner(): R6Scanner {
  return require(scannerPath) as R6Scanner;
}

function readManifest(): R6Manifest {
  return JSON.parse(readFileSync(manifestPath, 'utf8')) as R6Manifest;
}

function copyProtectedFixture(root: string): void {
  for (const relativePath of [
    'backend/.dependency-cruiser-known-violations.json',
    'backend/architecture/ownership-baseline.json',
    'backend/src/platform/otp-transport/openwa-otp.channel.ts',
    'backend/src/platform/otp-transport/openwa-otp-config.ts',
    'backend/src/platform/otp-transport/openwa-transient-text.ts',
    'backend/src/sharing/invitation-delivery.service.ts',
  ]) {
    const target = path.join(root, ...relativePath.split('/'));
    mkdirSync(path.dirname(target), { recursive: true });
    copyFileSync(path.join(repositoryRoot, ...relativePath.split('/')), target);
  }
}

afterEach(() => {
  for (const root of temporaryRoots.splice(0)) {
    rmSync(root, { recursive: true, force: true });
  }
});

test('R6 manifest pins the exact base, boundary, protected files, baselines, and scope', () => {
  const r6 = scanner();
  const manifest = r6.validateR6Manifest(readManifest());

  assert.equal(r6.R6_BASE, r6Base);
  assert.deepEqual(r6.STAGES, ['inventory', 'task-2', 'task-3', 'strict']);
  assert.equal(manifest.baseRevision, r6Base);
  assert.equal(manifest.stage, 'inventory');
  assert.deepEqual(manifest.currentConcreteDependency, {
    consumer: 'backend/src/sharing/invitation-delivery.service.ts',
    transport: 'backend/src/platform/otp-transport/openwa-transient-text.ts',
    declarations: [
      'OpenWaTransientDeliveryRejectedError',
      'OpenWaTransientDeliveryUncertainError',
      'sendOpenWaTransientText',
    ],
  });
  assert.deepEqual(manifest.targetBoundary, {
    adapterPath: 'backend/src/modules/identity/internal/identity-transient-delivery.adapter.ts',
    collaborationModulePath:
      'backend/src/modules/collaboration/internal/collaboration-services.internal.module.ts',
    consumerPath: 'backend/src/sharing/invitation-delivery.service.ts',
    identityModulePath: 'backend/src/modules/identity/identity.module.ts',
    implementationToken: 'IDENTITY_TRANSIENT_DELIVERY_IMPLEMENTATION',
    inputType: 'IdentityTransientDeliveryInput',
    internalModulePath:
      'backend/src/modules/identity/internal/identity-transient-delivery.internal.module.ts',
    portInterface: 'IdentityTransientDeliveryPort',
    publicErrors: [
      'IdentityTransientDeliveryRejectedError',
      'IdentityTransientDeliveryUncertainError',
    ],
    publicModulePath:
      'backend/src/modules/identity/public/identity-transient-delivery-public.module.ts',
    publicPortPath:
      'backend/src/modules/identity/public/identity-transient-delivery.port.ts',
    token: 'IDENTITY_TRANSIENT_DELIVERY_PORT',
  });
  assert.deepEqual(manifest.protectedFiles, [
    {
      path: 'backend/src/platform/otp-transport/openwa-otp.channel.ts',
      sha256: '1f939561064a0d8c8bfe6142d9793c2b670557ff620bec1c0fec95669837fd50',
    },
    {
      path: 'backend/src/platform/otp-transport/openwa-transient-text.ts',
      sha256: '9b53d04193876cd0258dc367685fbf6bb8e6d23845bfc8a1e501512a2a68b5ac',
    },
  ]);
  assert.deepEqual(manifest.expectedBaselines, {
    dependencyRecords: 31,
    ownershipRecords: 385,
    ownershipOccurrences: 781,
    concreteTransportImports: {
      inventory: 1,
      'task-2': 1,
      'task-3': 0,
      strict: 0,
    },
  });
  assert.deepEqual(manifest.allowedChangedPaths, expectedAllowedChangedPaths);
});

test('R6 manifest rejects identity, shape, path, boundary, hash, and scope near-misses', () => {
  const r6 = scanner();
  const source = readManifest();
  const rejected: unknown[] = [];

  const unknownKey = structuredClone(source) as R6Manifest & { extra?: boolean };
  unknownKey.extra = true;
  rejected.push(unknownKey);

  const wrongBase = structuredClone(source);
  wrongBase.baseRevision = '0'.repeat(40);
  rejected.push(wrongBase);

  const wrongStage = structuredClone(source);
  wrongStage.stage = 'complete';
  rejected.push(wrongStage);

  const traversal = structuredClone(source);
  traversal.allowedChangedPaths[0] = '../outside.ts';
  rejected.push(traversal);

  const absolute = structuredClone(source);
  absolute.allowedChangedPaths[0] = 'C:/outside.ts';
  rejected.push(absolute);

  const wildcard = structuredClone(source);
  wildcard.allowedChangedPaths[0] = 'backend/src/**';
  rejected.push(wildcard);

  const duplicate = structuredClone(source);
  duplicate.allowedChangedPaths[1] = duplicate.allowedChangedPaths[0];
  rejected.push(duplicate);

  const reordered = structuredClone(source);
  [reordered.allowedChangedPaths[0], reordered.allowedChangedPaths[1]] = [
    reordered.allowedChangedPaths[1],
    reordered.allowedChangedPaths[0],
  ];
  rejected.push(reordered);

  const extraProductionPath = structuredClone(source);
  extraProductionPath.allowedChangedPaths.push('backend/src/app.module.ts');
  rejected.push(extraProductionPath);

  const changedToken = structuredClone(source);
  changedToken.targetBoundary.token = 'OPENWA_TRANSIENT_DELIVERY_PORT';
  rejected.push(changedToken);

  const changedHash = structuredClone(source);
  changedHash.protectedFiles[0].sha256 = '0'.repeat(64);
  rejected.push(changedHash);

  for (const value of rejected) {
    assert.throws(() => r6.validateR6Manifest(value));
  }

  const proxy = new Proxy(structuredClone(source), {});
  assert.throws(() => r6.validateR6Manifest(proxy), /plain|data/i);
});

test('R6 inventory scan resolves the one current concrete import and protected files', () => {
  const result = scanner().scanR6SharingOtpTransport({
    repositoryRoot,
    manifest: readManifest(),
  });
  assert.deepEqual(result, {
    ok: true,
    stage: 'inventory',
    concreteImports: 1,
    protectedFiles: 2,
  });
});

test('R6 scan rejects a second Collaboration concrete transport import', () => {
  const root = mkdtempSync(path.join(tmpdir(), 'aarast-r6-transport-'));
  temporaryRoots.push(root);
  copyProtectedFixture(root);

  const extraPath = path.join(
    root,
    'backend',
    'src',
    'modules',
    'collaboration',
    'internal',
    'second-sender.ts',
  );
  mkdirSync(path.dirname(extraPath), { recursive: true });
  writeFileSync(
    extraPath,
    [
      "import { sendOpenWaTransientText } from '../../../platform/otp-transport/openwa-transient-text';",
      'export const secondSender = sendOpenWaTransientText;',
      '',
    ].join('\n'),
    'utf8',
  );

  assert.throws(
    () => scanner().scanR6SharingOtpTransport({
      repositoryRoot: root,
      manifest: readManifest(),
      readBaseFile: (relativePath: string) =>
        readFileSync(path.join(root, ...relativePath.split('/'))),
    }),
    /concrete.*import|transport.*import/i,
  );
});

test('R6 scan rejects any other Collaboration platform OTP transport import', () => {
  const root = mkdtempSync(path.join(tmpdir(), 'aarast-r6-other-transport-'));
  temporaryRoots.push(root);
  copyProtectedFixture(root);

  const extraPath = path.join(
    root,
    'backend',
    'src',
    'modules',
    'collaboration',
    'internal',
    'transport-config.ts',
  );
  mkdirSync(path.dirname(extraPath), { recursive: true });
  writeFileSync(
    extraPath,
    [
      "import '../../../platform/otp-transport/openwa-otp-config';",
      'export const importedTransportConfig = true;',
      '',
    ].join('\n'),
    'utf8',
  );

  assert.throws(
    () => scanner().scanR6SharingOtpTransport({
      repositoryRoot: root,
      manifest: readManifest(),
      readBaseFile: (relativePath: string) =>
        readFileSync(path.join(root, ...relativePath.split('/'))),
    }),
    /concrete.*import|transport.*import/i,
  );
});

test('R6 scan rejects protected OpenWA transport drift', () => {
  const root = mkdtempSync(path.join(tmpdir(), 'aarast-r6-protected-'));
  temporaryRoots.push(root);
  copyProtectedFixture(root);
  const protectedPath = path.join(
    root,
    'backend',
    'src',
    'platform',
    'otp-transport',
    'openwa-otp.channel.ts',
  );
  writeFileSync(protectedPath, readFileSync(protectedPath, 'utf8') + '\n', 'utf8');

  assert.throws(
    () => scanner().scanR6SharingOtpTransport({
      repositoryRoot: root,
      manifest: readManifest(),
      readBaseFile: (relativePath: string) =>
        readFileSync(path.join(repositoryRoot, ...relativePath.split('/'))),
    }),
    /protected|hash|drift/i,
  );
});

test('R6 package scripts expose the standalone gate and keep every prior gate', () => {
  const packageJson = JSON.parse(
    readFileSync(path.join(backendRoot, 'package.json'), 'utf8'),
  ) as { scripts: Record<string, string> };
  assert.equal(
    packageJson.scripts['architecture:r6'],
    'node scripts/architecture/r6-sharing-otp-transport-scan.cjs --check',
  );
  assert.equal(
    packageJson.scripts.architecture,
    'npm run architecture:imports && npm run architecture:ownership && npm run architecture:ports && npm run architecture:r3 && npm run architecture:r4 && npm run architecture:r5 && npm run architecture:r6',
  );
});

test('R6 CLI accepts only check mode and reports one bounded result', () => {
  const output: string[] = [];
  const errors: string[] = [];
  const r6 = scanner();
  assert.equal(r6.runCli({
    argv: ['--check'],
    repositoryRoot,
    stdout: (message: string) => output.push(message),
    stderr: (message: string) => errors.push(message),
  }), 0);
  assert.equal(errors.length, 0);
  assert.deepEqual(output, [
    'PASS - R6 Sharing OTP transport: stage=inventory, concrete-imports=1, protected=2',
  ]);

  assert.equal(r6.runCli({
    argv: ['--check', '--extra'],
    repositoryRoot,
    stdout: (message: string) => output.push(message),
    stderr: (message: string) => errors.push(message),
  }), 2);
  assert.equal(
    errors[errors.length - 1],
    'ERROR - R6 Sharing OTP transport validation failed',
  );
});
