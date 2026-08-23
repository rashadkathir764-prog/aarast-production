import assert from 'node:assert/strict';
import {
  copyFileSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { test } from 'node:test';
import { tmpdir } from 'node:os';

const backendRoot = path.resolve(__dirname, '..');
const repositoryRoot = path.resolve(backendRoot, '..');
const manifestPath = path.join(
  backendRoot,
  'architecture',
  'r7-collaboration-relocation.json',
);

type R7Manifest = {
  schemaVersion: number;
  baseRevision: string;
  stage: string;
  moves: Array<{ from: string; to: string }>;
  publicSnapshotContract: { path: string; exports: string[] };
  historicalHandoffs: {
    constructorConsumers: Array<Record<string, unknown>>;
    controllerSources: Array<{ from: string; to: string }>;
    retiredDependencyKeys: string[];
    ownershipProjection: Array<{
      from: string;
      to: string;
      records: number;
      occurrences: number;
    }>;
  };
  frozenOptionalDependencies: Array<Record<string, unknown>>;
  expectedBaselines: Record<string, number>;
  allowedChangedPaths: string[];
};

type R7Scanner = {
  EXPECTED_ALLOWED_PATHS: readonly string[];
  validateR7Manifest(value: unknown): R7Manifest;
  verifyPublicSnapshotSource(repositoryRoot: string, manifest: R7Manifest): {
    exports: number;
    imports: number;
  };
  verifyConstructorHandoffs(repositoryRoot: string, manifest: R7Manifest): {
    consumers: number;
    optional: number;
  };
  verifyControllerHandoffs(repositoryRoot: string, manifest: R7Manifest): {
    controllers: number;
    operations: number;
  };
  scanR7CollaborationRelocation(options: {
    repositoryRoot: string;
    manifest: unknown;
  }): { ok: boolean; stage: string; sourceFiles: number; targetFiles: number };
};

type R3Scope = {
  ALLOWED_PATHS: readonly string[];
  R7_ALLOWED_PATHS: readonly string[];
  validateR7CollaborationManifest(value: unknown): unknown;
  validateR3Scope(options: Record<string, unknown>): { reportPath: string };
};

function manifest(): R7Manifest {
  return JSON.parse(readFileSync(manifestPath, 'utf8')) as R7Manifest;
}

function scanner(): R7Scanner {
  return require(path.join(
    backendRoot,
    'scripts',
    'architecture',
    'r7-collaboration-relocation-scan.cjs',
  )) as R7Scanner;
}

function r3Scope(): R3Scope {
  return require(path.join(
    backendRoot,
    'scripts',
    'architecture',
    'r3-scope.cjs',
  )) as R3Scope;
}

function sourceContractFixture(): string {
  const fixtureRoot = mkdtempSync(path.join(tmpdir(), 'aarast-r7-source-contract-'));
  const paths = manifest().moves.map((move) => move.from);
  for (const relativePath of paths) {
    const target = path.join(fixtureRoot, ...relativePath.split('/'));
    mkdirSync(path.dirname(target), { recursive: true });
    copyFileSync(path.join(repositoryRoot, ...relativePath.split('/')), target);
  }
  return fixtureRoot;
}

const expectedMoves = [
  ['backend/src/contribution-history/contribution-history.contracts.ts', 'backend/src/modules/collaboration/internal/contribution-history.contracts.ts'],
  ['backend/src/contribution-history/contribution-history.controller.ts', 'backend/src/modules/collaboration/api/contribution-history.controller.ts'],
  ['backend/src/contribution-history/contribution-history.service.ts', 'backend/src/modules/collaboration/internal/contribution-history.service.ts'],
  ['backend/src/contribution-history/contribution-snapshot.builder.ts', 'backend/src/modules/collaboration/public/contribution-snapshot.builder.ts'],
  ['backend/src/contribution-history/contributor-scope.service.ts', 'backend/src/modules/collaboration/internal/contributor-scope.service.ts'],
  ['backend/src/contribution-history/dto/list-contributions.dto.ts', 'backend/src/modules/collaboration/api/dto/list-contributions.dto.ts'],
  ['backend/src/sharing/dto/create-plan-invite.dto.ts', 'backend/src/modules/collaboration/api/dto/create-plan-invite.dto.ts'],
  ['backend/src/sharing/dto/create-shared-member.dto.ts', 'backend/src/modules/collaboration/api/dto/create-shared-member.dto.ts'],
  ['backend/src/sharing/dto/leave-plan.dto.ts', 'backend/src/modules/collaboration/api/dto/leave-plan.dto.ts'],
  ['backend/src/sharing/dto/request-invite-otp.dto.ts', 'backend/src/modules/collaboration/api/dto/request-invite-otp.dto.ts'],
  ['backend/src/sharing/dto/update-shared-member.dto.ts', 'backend/src/modules/collaboration/api/dto/update-shared-member.dto.ts'],
  ['backend/src/sharing/dto/verify-invite-otp.dto.ts', 'backend/src/modules/collaboration/api/dto/verify-invite-otp.dto.ts'],
  ['backend/src/sharing/invitation-delivery.service.ts', 'backend/src/modules/collaboration/internal/invitation-delivery.service.ts'],
  ['backend/src/sharing/invite-access.service.ts', 'backend/src/modules/collaboration/internal/invite-access.service.ts'],
  ['backend/src/sharing/permission.service.ts', 'backend/src/modules/collaboration/internal/permission.service.ts'],
  ['backend/src/sharing/plan-permissions.ts', 'backend/src/modules/collaboration/internal/plan-permissions.ts'],
  ['backend/src/sharing/sharing.controller.ts', 'backend/src/modules/collaboration/api/sharing.controller.ts'],
  ['backend/src/sharing/sharing.service.ts', 'backend/src/modules/collaboration/internal/sharing.service.ts'],
].map(([from, to]) => ({ from, to }));

const expectedDependencyKeys = [
  'context-finance-cross-context|src/budget-categories/budget-categories.service.ts|src/contribution-history/contribution-snapshot.builder.ts',
  'context-finance-cross-context|src/wedding-costs/wedding-costs.service.ts|src/contribution-history/contribution-snapshot.builder.ts',
  'context-guests-cross-context|src/guests/guests.service.ts|src/contribution-history/contribution-snapshot.builder.ts',
  'context-marketplace-cross-context|src/marketplace/quote-offer-acceptance.ts|src/contribution-history/contribution-snapshot.builder.ts',
  'context-marketplace-cross-context|src/marketplace/quote-offer-rejection.ts|src/contribution-history/contribution-snapshot.builder.ts',
  'context-marketplace-cross-context|src/marketplace/quote-request-cancellation.ts|src/contribution-history/contribution-snapshot.builder.ts',
  'context-marketplace-cross-context|src/marketplace/quote-request-creation.ts|src/contribution-history/contribution-snapshot.builder.ts',
  'context-planning-cross-context|src/wedding-plans/wedding-plans.service.ts|src/contribution-history/contribution-snapshot.builder.ts',
  'context-tasks-cross-context|src/tasks/tasks.service.ts|src/contribution-history/contribution-snapshot.builder.ts',
];

test('R7 pins the immutable R6 closeout and exact Collaboration fate map', () => {
  const value = scanner().validateR7Manifest(manifest());
  assert.equal(value.schemaVersion, 1);
  assert.equal(value.baseRevision, '31ea5324007fc71fa4b3590fbb98a454ee1deaa7');
  assert.equal(value.stage, 'design');
  assert.deepEqual(value.moves, expectedMoves);
  assert.equal(new Set(value.moves.map((move) => move.from)).size, 18);
  assert.equal(new Set(value.moves.map((move) => move.to)).size, 18);
});

test('R7 freezes the public snapshot contract and every historical handoff', () => {
  const value = scanner().validateR7Manifest(manifest());
  assert.deepEqual(value.publicSnapshotContract, {
    path: 'backend/src/modules/collaboration/public/contribution-snapshot.builder.ts',
    exports: [
      'buildContributionSnapshot',
      'canonicalJson',
      'hashContributionSnapshot',
      'validateContributionSnapshot',
    ],
  });
  assert.deepEqual(value.historicalHandoffs.controllerSources, [
    {
      from: 'backend/src/contribution-history/contribution-history.controller.ts',
      to: 'backend/src/modules/collaboration/api/contribution-history.controller.ts',
    },
    {
      from: 'backend/src/sharing/sharing.controller.ts',
      to: 'backend/src/modules/collaboration/api/sharing.controller.ts',
    },
  ]);
  assert.equal(value.historicalHandoffs.constructorConsumers.length, 4);
  assert.deepEqual(value.historicalHandoffs.retiredDependencyKeys, expectedDependencyKeys);
  assert.deepEqual(value.historicalHandoffs.ownershipProjection, [
    {
      from: 'backend/src/contribution-history/contribution-history.service.ts',
      to: 'backend/src/modules/collaboration/internal/contribution-history.service.ts',
      records: 5,
      occurrences: 7,
    },
    {
      from: 'backend/src/sharing/invite-access.service.ts',
      to: 'backend/src/modules/collaboration/internal/invite-access.service.ts',
      records: 1,
      occurrences: 1,
    },
    {
      from: 'backend/src/sharing/permission.service.ts',
      to: 'backend/src/modules/collaboration/internal/permission.service.ts',
      records: 2,
      occurrences: 6,
    },
    {
      from: 'backend/src/sharing/sharing.service.ts',
      to: 'backend/src/modules/collaboration/internal/sharing.service.ts',
      records: 20,
      occurrences: 66,
    },
  ]);
});

test('R7 preserves the existing optional realtime injection instead of banning it', () => {
  const [dependency] = scanner().validateR7Manifest(manifest()).frozenOptionalDependencies;
  assert.deepEqual(dependency, {
    from: 'backend/src/sharing/sharing.service.ts',
    to: 'backend/src/modules/collaboration/internal/sharing.service.ts',
    consumerClass: 'SharingService',
    parameter: 'realtime',
    parameterIndex: 5,
    token: 'MESSAGING_REALTIME_PORT',
    optional: true,
    undefinedBehavior: 'unchanged',
  });
});

test('R7 verifies public exports and DI handoffs against the live TypeScript source', () => {
  const value = scanner().validateR7Manifest(manifest());
  assert.deepEqual(scanner().verifyPublicSnapshotSource(repositoryRoot, value), {
    exports: 4,
    imports: 3,
  });
  assert.deepEqual(scanner().verifyConstructorHandoffs(repositoryRoot, value), {
    consumers: 4,
    optional: 1,
  });
  assert.deepEqual(scanner().verifyControllerHandoffs(repositoryRoot, value), {
    controllers: 2,
    operations: 19,
  });
});

test('R7 source contract rejects export, token, index, and optionality drift', () => {
  const value = scanner().validateR7Manifest(manifest());
  const fixtureRoot = sourceContractFixture();
  try {
    const builderPath = path.join(
      fixtureRoot,
      'backend',
      'src',
      'contribution-history',
      'contribution-snapshot.builder.ts',
    );
    const originalBuilder = readFileSync(builderPath, 'utf8');
    writeFileSync(builderPath, `${originalBuilder}\nexport const unexpectedExport = true;\n`);
    assert.throws(
      () => scanner().verifyPublicSnapshotSource(fixtureRoot, value),
      /public snapshot exports drift/u,
    );
    writeFileSync(builderPath, originalBuilder);
    writeFileSync(builderPath, `${originalBuilder}\nvoid require('unexpected-package');\n`);
    assert.throws(
      () => scanner().verifyPublicSnapshotSource(fixtureRoot, value),
      /public snapshot dynamic dependency drift/u,
    );
    writeFileSync(builderPath, `${originalBuilder}\nvoid import('unexpected-package');\n`);
    assert.throws(
      () => scanner().verifyPublicSnapshotSource(fixtureRoot, value),
      /public snapshot dynamic dependency drift/u,
    );
    writeFileSync(builderPath, originalBuilder);

    const sharingPath = path.join(
      fixtureRoot,
      'backend',
      'src',
      'sharing',
      'sharing.service.ts',
    );
    const originalSharing = readFileSync(sharingPath, 'utf8');
    writeFileSync(
      sharingPath,
      originalSharing.replace('@Inject(NOTIFICATIONS_PORT)', '@Inject(MESSAGING_REALTIME_PORT)'),
    );
    assert.throws(
      () => scanner().verifyConstructorHandoffs(fixtureRoot, value),
      /constructor injection drift/u,
    );
    writeFileSync(
      sharingPath,
      originalSharing.replace('@Optional()\n', ''),
    );
    assert.throws(
      () => scanner().verifyConstructorHandoffs(fixtureRoot, value),
      /constructor optionality drift/u,
    );
    writeFileSync(
      sharingPath,
      originalSharing.replace(
        'private readonly notifications: NotificationsPort,',
        'private readonly __r7_swap__: NotificationsPort,',
      ).replace(
        'private readonly history: ContributionHistoryService,',
        'private readonly notifications: NotificationsPort,',
      ).replace(
        'private readonly __r7_swap__: NotificationsPort,',
        'private readonly history: ContributionHistoryService,',
      ),
    );
    assert.throws(
      () => scanner().verifyConstructorHandoffs(fixtureRoot, value),
      /constructor parameter drift/u,
    );
    writeFileSync(
      sharingPath,
      originalSharing.replace(
        'private readonly prisma: PrismaService,',
        'private readonly prisma: PrismaService = undefined as never,',
      ),
    );
    assert.throws(
      () => scanner().verifyConstructorHandoffs(fixtureRoot, value),
      /constructor default drift/u,
    );
    writeFileSync(
      sharingPath,
      originalSharing.replace(
        'private readonly prisma: PrismaService,',
        'private readonly prisma?: PrismaService,',
      ),
    );
    assert.throws(
      () => scanner().verifyConstructorHandoffs(fixtureRoot, value),
      /constructor optionality drift/u,
    );

    const controllerPath = path.join(
      fixtureRoot,
      'backend',
      'src',
      'sharing',
      'sharing.controller.ts',
    );
    const originalController = readFileSync(controllerPath, 'utf8');
    writeFileSync(
      controllerPath,
      originalController.replace('@Post(":token/request-otp")', '@Get(":token/request-otp")'),
    );
    assert.throws(
      () => scanner().verifyControllerHandoffs(fixtureRoot, value),
      /controller inventory drift/u,
    );
  } finally {
    rmSync(fixtureRoot, { recursive: true, force: true });
  }
});

test('R7 baseline arithmetic is exact and path-only ownership stays 385/781', () => {
  assert.deepEqual(scanner().validateR7Manifest(manifest()).expectedBaselines, {
    baseDependencyRecords: 31,
    retiredDependencyRecords: 9,
    strictDependencyRecords: 22,
    baseOwnershipRecords: 385,
    baseOwnershipOccurrences: 781,
    projectedOwnershipRecords: 28,
    projectedOwnershipOccurrences: 80,
    strictOwnershipRecords: 385,
    strictOwnershipOccurrences: 781,
  });
});

test('R7 scope is exact, sorted, delegated, and does not mutate R3', () => {
  const value = scanner().validateR7Manifest(manifest());
  const scan = scanner().scanR7CollaborationRelocation({ repositoryRoot, manifest: value });
  assert.deepEqual(scan, {
    ok: true,
    stage: 'design',
    sourceFiles: 18,
    targetFiles: 0,
  });
  assert.deepEqual(value.allowedChangedPaths, scanner().EXPECTED_ALLOWED_PATHS);
  assert.deepEqual(value.allowedChangedPaths, [...value.allowedChangedPaths].sort());
  assert.equal(new Set(value.allowedChangedPaths).size, value.allowedChangedPaths.length);
  for (const entry of value.allowedChangedPaths) {
    assert.equal(path.posix.isAbsolute(entry), false);
    assert.equal(entry.includes('\\'), false);
    assert.equal(entry.split('/').includes('..'), false);
  }

  const scope = r3Scope();
  assert.doesNotThrow(() => scope.validateR7CollaborationManifest(value));
  assert.deepEqual(scope.R7_ALLOWED_PATHS, value.allowedChangedPaths);
  assert.equal(
    scope.ALLOWED_PATHS.includes('backend/architecture/r7-collaboration-relocation.json'),
    false,
    'the immutable R3 receipt must not be widened with R7 paths',
  );
});

test('R7 architecture delegation preserves the immutable R5 package fingerprint', () => {
  const r5 = require(path.join(
    backendRoot,
    'scripts',
    'architecture',
    'r5-identity-scan.cjs',
  )) as {
    R5_BASE: string;
    validateR5SecurityCheckpointScope(value: unknown): unknown;
  };
  const gitLines = (args: string[]) => execFileSync('git', args, {
    cwd: repositoryRoot,
    encoding: 'utf8',
  }).split(/\r?\n/u).filter(Boolean);
  const changedPaths = [...new Set([
    ...gitLines(['diff', '--no-renames', '--name-only', r5.R5_BASE, '--']),
    ...gitLines(['ls-files', '--others', '--exclude-standard']),
  ])].sort();
  assert.doesNotThrow(() => r5.validateR5SecurityCheckpointScope({
    changedPaths,
    packageJson: JSON.parse(readFileSync(path.join(backendRoot, 'package.json'), 'utf8')),
    packageLock: JSON.parse(readFileSync(path.join(backendRoot, 'package-lock.json'), 'utf8')),
  }));
});
