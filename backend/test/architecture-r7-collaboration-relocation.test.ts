import assert from 'node:assert/strict';
import {
  cpSync,
  copyFileSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { test } from 'node:test';
import { tmpdir } from 'node:os';
import ts from 'typescript';

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
  sourceParity: Array<{ from: string; to: string; normalizedSha256: string }>;
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
  }): {
    ok: boolean;
    stage: string;
    sourceFiles: number;
    targetFiles: number;
    dependencyRecords: number;
    ownershipRecords: number;
    ownershipOccurrences: number;
  };
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

const expectedStageCounts = {
  design: { sourceFiles: 18, targetFiles: 0 },
  snapshot: { sourceFiles: 17, targetFiles: 1 },
  history: { sourceFiles: 12, targetFiles: 6 },
  relocated: { sourceFiles: 0, targetFiles: 18 },
  strict: { sourceFiles: 0, targetFiles: 18 },
} as const;

function targetPathsForStage(
  value: R7Manifest,
  stage: keyof typeof expectedStageCounts,
): Set<string> {
  if (stage === 'design') return new Set();
  if (stage === 'snapshot') return new Set([value.publicSnapshotContract.path]);
  if (stage === 'history') {
    return new Set(value.moves
      .filter((move) => move.from.startsWith('backend/src/contribution-history/'))
      .map((move) => move.to));
  }
  return new Set(value.moves.map((move) => move.to));
}

function rewriteRelativeImports(
  sourcePath: string,
  targetPath: string,
  sourceText: string,
  value: R7Manifest,
): string {
  const aliases = new Map<string, string>();
  for (const move of value.moves) {
    aliases.set(move.from.replace(/\.ts$/u, ''), move.to.replace(/\.ts$/u, ''));
    aliases.set(move.to.replace(/\.ts$/u, ''), move.to.replace(/\.ts$/u, ''));
  }
  const sourceFile = ts.createSourceFile(
    sourcePath,
    sourceText,
    ts.ScriptTarget.Latest,
    true,
    ts.ScriptKind.TS,
  );
  const replacements: Array<{ start: number; end: number; value: string }> = [];
  for (const statement of sourceFile.statements) {
    if ((!ts.isImportDeclaration(statement) && !ts.isExportDeclaration(statement))
        || !statement.moduleSpecifier
        || !ts.isStringLiteralLike(statement.moduleSpecifier)
        || !statement.moduleSpecifier.text.startsWith('.')) continue;
    const resolved = path.posix.normalize(path.posix.join(
      path.posix.dirname(sourcePath),
      statement.moduleSpecifier.text,
    ));
    const finalDependency = aliases.get(resolved) ?? resolved;
    let relative = path.posix.relative(path.posix.dirname(targetPath), finalDependency);
    if (!relative.startsWith('.')) relative = `./${relative}`;
    replacements.push({
      start: statement.moduleSpecifier.getStart(sourceFile) + 1,
      end: statement.moduleSpecifier.getEnd() - 1,
      value: relative,
    });
  }
  return replacements.sort((left, right) => right.start - left.start).reduce(
    (text, replacement) => (
      text.slice(0, replacement.start) + replacement.value + text.slice(replacement.end)
    ),
    sourceText,
  );
}

function writeJson(filePath: string, value: unknown): void {
  mkdirSync(path.dirname(filePath), { recursive: true });
  writeFileSync(filePath, `${JSON.stringify(value, null, 2)}\n`, 'utf8');
}

function stagedFixture(stage: keyof typeof expectedStageCounts): {
  root: string;
  value: R7Manifest;
} {
  const root = mkdtempSync(path.join(tmpdir(), `aarast-r7-${stage}-`));
  const value = structuredClone(manifest());
  value.stage = stage;
  const collaborationSource = path.join(repositoryRoot, 'backend', 'src', 'modules', 'collaboration');
  const collaborationTarget = path.join(root, 'backend', 'src', 'modules', 'collaboration');
  cpSync(collaborationSource, collaborationTarget, { recursive: true });
  copyFileSync(
    path.join(repositoryRoot, 'backend', '.dependency-cruiser-known-violations.json'),
    path.join(root, 'backend', '.dependency-cruiser-known-violations.json'),
  );
  mkdirSync(path.join(root, 'backend', 'architecture'), { recursive: true });
  copyFileSync(
    path.join(repositoryRoot, 'backend', 'architecture', 'ownership-baseline.json'),
    path.join(root, 'backend', 'architecture', 'ownership-baseline.json'),
  );

  const activeTargets = targetPathsForStage(value, stage);
  for (const move of value.moves) {
    const source = path.join(root, ...move.from.split('/'));
    mkdirSync(path.dirname(source), { recursive: true });
    copyFileSync(path.join(repositoryRoot, ...move.from.split('/')), source);
    if (!activeTargets.has(move.to)) continue;
    const target = path.join(root, ...move.to.split('/'));
    mkdirSync(path.dirname(target), { recursive: true });
    writeFileSync(
      target,
      rewriteRelativeImports(
        move.from,
        move.to,
        readFileSync(source, 'utf8'),
        value,
      ),
      'utf8',
    );
    rmSync(source);
  }

  if (stage !== 'design') {
    const dependencyPath = path.join(root, 'backend', '.dependency-cruiser-known-violations.json');
    const dependency = JSON.parse(readFileSync(dependencyPath, 'utf8')) as Array<Record<string, any>>;
    const retired = new Set(value.historicalHandoffs.retiredDependencyKeys);
    writeJson(dependencyPath, dependency.filter((record) => !retired.has([
      record.rule?.name,
      record.from,
      record.to,
    ].join('|'))));
  }

  const ownershipPath = path.join(root, 'backend', 'architecture', 'ownership-baseline.json');
  const ownership = JSON.parse(readFileSync(ownershipPath, 'utf8')) as {
    violations: Array<Record<string, any>>;
  };
  for (const projection of value.historicalHandoffs.ownershipProjection) {
    if (!activeTargets.has(projection.to)) continue;
    for (const record of ownership.violations) {
      if (record.file !== projection.from) continue;
      record.file = projection.to;
      record.key = String(record.key).replace(projection.from, projection.to);
    }
  }
  writeJson(ownershipPath, ownership);

  if (stage === 'strict') {
    rmSync(path.join(root, 'backend', 'src', 'sharing'), { recursive: true, force: true });
    rmSync(path.join(root, 'backend', 'src', 'contribution-history'), {
      recursive: true,
      force: true,
    });
  }
  return { root, value };
}

function mutateFixtureFile(
  root: string,
  relativePath: string,
  mutate: (source: string) => string,
): void {
  const absolute = path.join(root, ...relativePath.split('/'));
  const before = readFileSync(absolute, 'utf8');
  const after = mutate(before);
  assert.notEqual(after, before, `mutation must change ${relativePath}`);
  writeFileSync(absolute, after, 'utf8');
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

const expectedSourceParity = [
  ['backend/src/contribution-history/contribution-history.contracts.ts', 'backend/src/modules/collaboration/internal/contribution-history.contracts.ts', 'aeab7af798e09cb6beae0d7409cf40d25ebd645096bed391f880e5a7a108239c'],
  ['backend/src/contribution-history/contribution-history.controller.ts', 'backend/src/modules/collaboration/api/contribution-history.controller.ts', '1ee407b59727469829bc93f301df0ad61f91535c9b4f181f33e944893249a547'],
  ['backend/src/contribution-history/contribution-history.service.ts', 'backend/src/modules/collaboration/internal/contribution-history.service.ts', '1f34aaf0b9a2b7d8101e3065fba9d40c5128ca6ce7471cd383a6751feb0f68ce'],
  ['backend/src/contribution-history/contribution-snapshot.builder.ts', 'backend/src/modules/collaboration/public/contribution-snapshot.builder.ts', '619abcebff09ea077d15040fd12b380a828fad54ac5a4ed9b43ca6742baddd87'],
  ['backend/src/contribution-history/contributor-scope.service.ts', 'backend/src/modules/collaboration/internal/contributor-scope.service.ts', 'ba4573a342450fe44ccc4f72def9931a1121fe4238e0f7892ed2a882dd6b33d2'],
  ['backend/src/contribution-history/dto/list-contributions.dto.ts', 'backend/src/modules/collaboration/api/dto/list-contributions.dto.ts', '2aa1486c288afe3eebb251ee4007dc32c73912571399d67285dc4c9a7597f02d'],
  ['backend/src/sharing/dto/create-plan-invite.dto.ts', 'backend/src/modules/collaboration/api/dto/create-plan-invite.dto.ts', 'ba4ee89e9a2608cd6f6c759068b532c2be234a30eec6a7079547c5d1b0a4a220'],
  ['backend/src/sharing/dto/create-shared-member.dto.ts', 'backend/src/modules/collaboration/api/dto/create-shared-member.dto.ts', '53f43fba776d4f117ae56baf5b541fcf470cbdc04c755892bb4834471f83b536'],
  ['backend/src/sharing/dto/leave-plan.dto.ts', 'backend/src/modules/collaboration/api/dto/leave-plan.dto.ts', 'ec5719af9c3b94eb0792c5aee6815d1a835cbd0d1a446b165021f95221ea48f3'],
  ['backend/src/sharing/dto/request-invite-otp.dto.ts', 'backend/src/modules/collaboration/api/dto/request-invite-otp.dto.ts', '0da6d2dcfdd4adbf81daccaf763441a3f1ac01fd7961425de3318169cb4b63fa'],
  ['backend/src/sharing/dto/update-shared-member.dto.ts', 'backend/src/modules/collaboration/api/dto/update-shared-member.dto.ts', '03744001cf43aa3f241bf3b319a484b0d418e1a39d0fbb01245f4e825399410c'],
  ['backend/src/sharing/dto/verify-invite-otp.dto.ts', 'backend/src/modules/collaboration/api/dto/verify-invite-otp.dto.ts', 'a3b383c7ff3331870c900a9b01cded90ddd33c597187e406004f838e8b054f0d'],
  ['backend/src/sharing/invitation-delivery.service.ts', 'backend/src/modules/collaboration/internal/invitation-delivery.service.ts', '36c16edbbb8bd647bddae34f1e4d2377fa5b13c708695bce831781f4ad05612c'],
  ['backend/src/sharing/invite-access.service.ts', 'backend/src/modules/collaboration/internal/invite-access.service.ts', 'c17110576aba439e6bda13b3b71fa331916b978e433d48b7f6035db0fe23474e'],
  ['backend/src/sharing/permission.service.ts', 'backend/src/modules/collaboration/internal/permission.service.ts', '3fd1670524fc55e4dcdd4b9322ef12724e2dd77e9d95adbcaf3ca09ef4980146'],
  ['backend/src/sharing/plan-permissions.ts', 'backend/src/modules/collaboration/internal/plan-permissions.ts', 'c856e84a7716a7efed4b7f4e7303b60f767ea6ddaa7481429645de20969d6161'],
  ['backend/src/sharing/sharing.controller.ts', 'backend/src/modules/collaboration/api/sharing.controller.ts', 'c0d93d3c25b41c523462fa3b2f415a5786ab83621ea7b4ece467bb053918dee7'],
  ['backend/src/sharing/sharing.service.ts', 'backend/src/modules/collaboration/internal/sharing.service.ts', '37894e0c52a61de94f2fa8596bc9a1c7dfd35b7bd1702e541f830f2710fc9955'],
].map(([from, to, normalizedSha256]) => ({ from, to, normalizedSha256 }));

test('R7 pins the immutable R6 closeout and exact Collaboration fate map', () => {
  const value = scanner().validateR7Manifest(manifest());
  assert.equal(value.schemaVersion, 1);
  assert.equal(value.baseRevision, '31ea5324007fc71fa4b3590fbb98a454ee1deaa7');
  assert.equal(value.stage, 'design');
  assert.deepEqual(value.moves, expectedMoves);
  assert.equal(new Set(value.moves.map((move) => move.from)).size, 18);
  assert.equal(new Set(value.moves.map((move) => move.to)).size, 18);
  assert.deepEqual(value.sourceParity, expectedSourceParity);
});

test('R7 accepts only the exact staged source and target layouts', () => {
  for (const [stage, counts] of Object.entries(expectedStageCounts) as Array<[
    keyof typeof expectedStageCounts,
    { sourceFiles: number; targetFiles: number },
  ]>) {
    const fixture = stagedFixture(stage);
    try {
      assert.deepEqual(scanner().scanR7CollaborationRelocation({
        repositoryRoot: fixture.root,
        manifest: fixture.value,
      }), {
        ok: true,
        stage,
        ...counts,
        dependencyRecords: stage === 'design' ? 31 : 22,
        ownershipRecords: 385,
        ownershipOccurrences: 781,
      });
    } finally {
      rmSync(fixture.root, { recursive: true, force: true });
    }
  }
});

test('R7 rejects mixed, duplicate, missing, converging, reparse, and extra layouts', () => {
  const cases: Array<{
    name: string;
    stage: keyof typeof expectedStageCounts;
    mutate(root: string, value: R7Manifest): void;
  }> = [
    {
      name: 'mixed stage target',
      stage: 'snapshot',
      mutate(root, value) {
        const expected = value.moves[3];
        const wrong = value.moves[0];
        const expectedSource = path.join(root, ...expected.from.split('/'));
        const expectedTarget = path.join(root, ...expected.to.split('/'));
        mkdirSync(path.dirname(expectedSource), { recursive: true });
        writeFileSync(expectedSource, readFileSync(expectedTarget, 'utf8'), 'utf8');
        rmSync(expectedTarget);
        const wrongSource = path.join(root, ...wrong.from.split('/'));
        const wrongTarget = path.join(root, ...wrong.to.split('/'));
        mkdirSync(path.dirname(wrongTarget), { recursive: true });
        writeFileSync(wrongTarget, readFileSync(wrongSource, 'utf8'), 'utf8');
        rmSync(wrongSource);
      },
    },
    {
      name: 'both source and target',
      stage: 'design',
      mutate(root, value) {
        const move = value.moves[0];
        const target = path.join(root, ...move.to.split('/'));
        mkdirSync(path.dirname(target), { recursive: true });
        copyFileSync(path.join(root, ...move.from.split('/')), target);
      },
    },
    {
      name: 'neither source nor target',
      stage: 'design',
      mutate(root, value) {
        rmSync(path.join(root, ...value.moves[0].from.split('/')));
      },
    },
    {
      name: 'converging targets',
      stage: 'design',
      mutate(_root, value) {
        value.moves[1].to = value.moves[0].to;
      },
    },
    {
      name: 'directory junction',
      stage: 'design',
      mutate(root) {
        const dto = path.join(root, 'backend', 'src', 'sharing', 'dto');
        const outside = path.join(root, 'junction-target');
        cpSync(dto, outside, { recursive: true });
        rmSync(dto, { recursive: true, force: true });
        symlinkSync(outside, dto, process.platform === 'win32' ? 'junction' : 'dir');
      },
    },
    {
      name: 'extra final-slice file',
      stage: 'design',
      mutate(root) {
        mkdirSync(
          path.join(root, 'backend', 'src', 'modules', 'collaboration', 'api'),
          { recursive: true },
        );
        writeFileSync(
          path.join(root, 'backend', 'src', 'modules', 'collaboration', 'api', 'extra.ts'),
          'export const extra = true;\n',
          'utf8',
        );
      },
    },
    {
      name: 'undeclared legacy file',
      stage: 'design',
      mutate(root) {
        writeFileSync(
          path.join(root, 'backend', 'src', 'sharing', 'undeclared.ts'),
          'export const undeclared = true;\n',
          'utf8',
        );
      },
    },
  ];
  for (const fixtureCase of cases) {
    const fixture = stagedFixture(fixtureCase.stage);
    try {
      fixtureCase.mutate(fixture.root, fixture.value);
      assert.throws(
        () => scanner().scanR7CollaborationRelocation({
          repositoryRoot: fixture.root,
          manifest: fixture.value,
        }),
        /R7/u,
        fixtureCase.name,
      );
    } finally {
      rmSync(fixture.root, { recursive: true, force: true });
    }
  }
});

test('R7 immutable source parity rejects behavioral and boundary bypasses', () => {
  const cases: Array<{
    name: string;
    file: string;
    mutate(source: string): string;
  }> = [
    {
      name: 'changed statement',
      file: 'backend/src/sharing/plan-permissions.ts',
      mutate: (source) => `${source}\nvoid 0;\n`,
    },
    {
      name: 'changed class',
      file: 'backend/src/contribution-history/contributor-scope.service.ts',
      mutate: (source) => source.replace('class ContributorScopeService', 'class ChangedContributorScopeService'),
    },
    {
      name: 'changed method',
      file: 'backend/src/contribution-history/contributor-scope.service.ts',
      mutate: (source) => source.replace('qualifyingEntityIds(', 'changedQualifyingEntityIds('),
    },
    {
      name: 'changed decorator',
      file: 'backend/src/sharing/sharing.controller.ts',
      mutate: (source) => source.replace('@Get("mine")', '@Post("mine")'),
    },
    {
      name: 'changed route',
      file: 'backend/src/sharing/sharing.controller.ts',
      mutate: (source) => source.replace('@Controller("api/v1/shared")', '@Controller("api/v1/changed")'),
    },
    {
      name: 'changed parameter',
      file: 'backend/src/contribution-history/contribution-snapshot.builder.ts',
      mutate: (source) => source.replace('value: unknown): string', 'value: string): string'),
    },
    {
      name: 'changed error text',
      file: 'backend/src/contribution-history/contribution-snapshot.builder.ts',
      mutate: (source) => source.replace('Contribution snapshot must be an object', 'Changed snapshot error'),
    },
    {
      name: 'constructor default',
      file: 'backend/src/sharing/sharing.service.ts',
      mutate: (source) => source.replace(
        'private readonly prisma: PrismaService,',
        'private readonly prisma: PrismaService = undefined as never,',
      ),
    },
    {
      name: 'optional marker',
      file: 'backend/src/sharing/sharing.service.ts',
      mutate: (source) => source.replace('@Optional()\n', ''),
    },
    {
      name: 'injection token',
      file: 'backend/src/sharing/sharing.service.ts',
      mutate: (source) => source.replace('@Inject(NOTIFICATIONS_PORT)', '@Inject(MESSAGING_REALTIME_PORT)'),
    },
    {
      name: 'dynamic dependency',
      file: 'backend/src/contribution-history/contribution-snapshot.builder.ts',
      mutate: (source) => `${source}\nvoid import("node:fs");\n`,
    },
    {
      name: 'extra export',
      file: 'backend/src/contribution-history/contribution-snapshot.builder.ts',
      mutate: (source) => `${source}\nexport const extra = true;\n`,
    },
    {
      name: 'compatibility re-export',
      file: 'backend/src/sharing/plan-permissions.ts',
      mutate: () => 'export * from "../modules/collaboration/internal/plan-permissions";\n',
    },
  ];
  for (const fixtureCase of cases) {
    const fixture = stagedFixture('design');
    try {
      mutateFixtureFile(fixture.root, fixtureCase.file, fixtureCase.mutate);
      assert.throws(
        () => scanner().scanR7CollaborationRelocation({
          repositoryRoot: fixture.root,
          manifest: fixture.value,
        }),
        /R7/u,
        fixtureCase.name,
      );
    } finally {
      rmSync(fixture.root, { recursive: true, force: true });
    }
  }

  const extra = stagedFixture('design');
  try {
    writeFileSync(
      path.join(extra.root, 'backend', 'src', 'modules', 'collaboration', 'internal', 'extra.ts'),
      'export const extra = true;\n',
      'utf8',
    );
    assert.throws(() => scanner().scanR7CollaborationRelocation({
      repositoryRoot: extra.root,
      manifest: extra.value,
    }));
  } finally {
    rmSync(extra.root, { recursive: true, force: true });
  }
});

test('R7 rejects runtime imports from another context into Collaboration API or internal', () => {
  for (const protectedSlice of ['api', 'internal']) {
    const fixture = stagedFixture('design');
    try {
      const attacker = path.join(fixture.root, 'backend', 'src', 'tasks', 'attacker.ts');
      mkdirSync(path.dirname(attacker), { recursive: true });
      writeFileSync(
        attacker,
        `import "../modules/collaboration/${protectedSlice}/attacker";\n`,
        'utf8',
      );
      assert.throws(() => scanner().scanR7CollaborationRelocation({
        repositoryRoot: fixture.root,
        manifest: fixture.value,
      }), /internal|api|cross-context|boundary/i);
    } finally {
      rmSync(fixture.root, { recursive: true, force: true });
    }
  }
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
    dependencyRecords: 31,
    ownershipRecords: 385,
    ownershipOccurrences: 781,
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
