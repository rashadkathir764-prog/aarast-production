import assert from 'node:assert/strict';
import {
  cpSync,
  copyFileSync,
  existsSync,
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
  inspectSemanticSource(sourceFile: ts.SourceFile, checker: ts.TypeChecker): {
    moduleReferences: string[];
    commonJsExports: string[];
    globalApplications: number;
  };
  validateR7Manifest(value: unknown): R7Manifest;
  verifyPublicSnapshotSource(repositoryRoot: string, manifest: R7Manifest): {
    exports: number;
    imports: number;
  };
  verifyPublicSnapshotConsumers(repositoryRoot: string): {
    callers: number;
    testImports: number;
  };
  verifyConstructorHandoffs(repositoryRoot: string, manifest: R7Manifest): {
    consumers: number;
    optional: number;
  };
  verifyControllerHandoffs(repositoryRoot: string, manifest: R7Manifest): {
    controllers: number;
    operations: number;
  };
  verifyHistoryRelocation(repositoryRoot: string, manifest: R7Manifest): {
    controllers: number;
    providers: number;
    aliases: number;
    exports: number;
    legacyRuntimeImports: number;
  };
  verifySharingRelocation(repositoryRoot: string, manifest: R7Manifest): {
    controllers: number;
    operations: number;
    providers: number;
    aliases: number;
    exports: number;
    legacyRuntimeImports: number;
  };
  verifyStrictRelocationState(repositoryRoot: string, manifest: R7Manifest): {
    legacyRoots: number;
    legacyImportLiterals: number;
    retiredDependencyKeys: number;
    protectedRuntimeImports: number;
    duplicatePublicExports: number;
    unregisteredTargetFiles: number;
    reparsePoints: number;
    forwardRef: number;
    globals: number;
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
    const move = manifest().moves.find((entry) => entry.from === relativePath)!;
    const activePath = existsSync(path.join(repositoryRoot, ...move.from.split('/')))
      ? move.from
      : move.to;
    copyFileSync(path.join(repositoryRoot, ...activePath.split('/')), target);
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
  activeTargets: Set<string>,
): string {
  const aliases = new Map<string, string>();
  for (const move of value.moves) {
    aliases.set(
      move.from.replace(/\.ts$/u, ''),
      (activeTargets.has(move.to) ? move.to : move.from).replace(/\.ts$/u, ''),
    );
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
  for (const move of value.moves) {
    rmSync(path.join(root, ...move.to.split('/')), { force: true });
  }
  mkdirSync(path.join(root, 'backend'), { recursive: true });
  copyFileSync(
    path.join(repositoryRoot, 'backend', 'tsconfig.json'),
    path.join(root, 'backend', 'tsconfig.json'),
  );
  writeFixtureFile(
    root,
    'backend/node_modules/@nestjs/common/index.d.ts',
    [
      'export declare function forwardRef(callback: () => unknown): unknown;',
      'export declare function Global(): ClassDecorator;',
      '',
    ].join('\n'),
  );
  writeFileSync(
    path.join(root, 'backend', '.dependency-cruiser-known-violations.json'),
    execFileSync(
      'git',
      ['show', `${value.baseRevision}:backend/.dependency-cruiser-known-violations.json`],
      { cwd: repositoryRoot, encoding: 'utf8' },
    ),
    'utf8',
  );
  mkdirSync(path.join(root, 'backend', 'architecture'), { recursive: true });
  writeFileSync(
    path.join(root, 'backend', 'architecture', 'ownership-baseline.json'),
    execFileSync(
      'git',
      [`show`, `${value.baseRevision}:backend/architecture/ownership-baseline.json`],
      { cwd: repositoryRoot, encoding: 'utf8' },
    ),
    'utf8',
  );

  for (const relativePath of [
    'backend/src/conversations/conversation-realtime.module.ts',
    'backend/src/platform/database/prisma.module.ts',
    'backend/src/budget-categories/budget-categories.service.ts',
    'backend/src/contribution-history/contribution-history.service.ts',
    'backend/src/guests/guests.service.ts',
    'backend/src/marketplace/quote-offer-acceptance.ts',
    'backend/src/marketplace/quote-offer-rejection.ts',
    'backend/src/marketplace/quote-request-cancellation.ts',
    'backend/src/marketplace/quote-request-creation.ts',
    'backend/src/tasks/tasks.service.ts',
    'backend/src/wedding-costs/wedding-costs.service.ts',
    'backend/src/wedding-plans/wedding-plans.service.ts',
    'backend/test/contribution-history-dedupe.test.ts',
    'backend/test/contribution-history-privacy.test.ts',
  ]) {
    const target = path.join(root, ...relativePath.split('/'));
    mkdirSync(path.dirname(target), { recursive: true });
    if (stage === 'design') {
      writeFileSync(
        target,
        execFileSync('git', ['show', `${value.baseRevision}:${relativePath}`], {
          cwd: repositoryRoot,
          encoding: 'utf8',
        }),
        'utf8',
      );
    } else {
      const activePath = relativePath === 'backend/src/contribution-history/contribution-history.service.ts'
        && !existsSync(path.join(repositoryRoot, ...relativePath.split('/')))
        ? 'backend/src/modules/collaboration/internal/contribution-history.service.ts'
        : relativePath;
      copyFileSync(path.join(repositoryRoot, ...activePath.split('/')), target);
    }
  }

  const activeTargets = targetPathsForStage(value, stage);
  for (const move of value.moves) {
    const source = path.join(root, ...move.from.split('/'));
    mkdirSync(path.dirname(source), { recursive: true });
    const baseSource = execFileSync('git', ['show', `${value.baseRevision}:${move.from}`], {
      cwd: repositoryRoot,
      encoding: 'utf8',
    });
    writeFileSync(
      source,
      stage === 'design'
        ? baseSource
        : rewriteRelativeImports(move.from, move.from, baseSource, value, activeTargets),
      'utf8',
    );
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
        activeTargets,
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
  ownership.violations.sort((left, right) => (
    left.key < right.key ? -1 : left.key > right.key ? 1 : 0
  ));
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

function writeFixtureFile(root: string, relativePath: string, source: string): void {
  const absolute = path.join(root, ...relativePath.split('/'));
  mkdirSync(path.dirname(absolute), { recursive: true });
  writeFileSync(absolute, source, 'utf8');
}

function inspectSemanticFixtureSources(
  sources: Record<string, string>,
): Record<string, {
  moduleReferences: string[];
  commonJsExports: string[];
  globalApplications: number;
}> {
  const root = mkdtempSync(path.join(tmpdir(), 'aarast-r7-semantic-'));
  try {
    writeFixtureFile(
      root,
      'node_modules/@nestjs/common/index.d.ts',
      [
        'export declare function Global(): ClassDecorator;',
        'export declare function forwardRef(callback: () => unknown): unknown;',
        '',
      ].join('\n'),
    );
    const entries = Object.entries(sources).map(([name, source]) => {
      const absolute = path.join(root, `${name}.ts`);
      writeFixtureFile(root, `${name}.ts`, `${source}\nexport {};\n`);
      return { absolute, name };
    });
    const program = ts.createProgram({
      rootNames: entries.map((entry) => entry.absolute),
      options: {
        experimentalDecorators: true,
        module: ts.ModuleKind.CommonJS,
        moduleResolution: ts.ModuleResolutionKind.NodeJs,
        noEmit: true,
        target: ts.ScriptTarget.ES2022,
      },
    });
    const checker = program.getTypeChecker();
    return Object.fromEntries(entries.map((entry) => {
      const sourceFile = program.getSourceFile(entry.absolute);
      assert.ok(sourceFile, `semantic fixture must load ${entry.name}`);
      assert.equal(
        program.getSyntacticDiagnostics(sourceFile).length,
        0,
        `semantic fixture must parse ${entry.name}`,
      );
      return [entry.name, scanner().inspectSemanticSource(sourceFile, checker)];
    }));
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

test('R7 semantic inspector exposes the shared value-origin behavior', () => {
  assert.deepEqual(inspectSemanticFixtureSources({
    loader: [
      'const [load] = [require];',
      'void load("../sharing/sharing.service");',
      '',
    ].join('\n'),
  }).loader, {
    moduleReferences: ['../sharing/sharing.service'],
    commonJsExports: [],
    globalApplications: 0,
  });
});

function mutateOwnershipFixture(
  stage: keyof typeof expectedStageCounts,
  mutate: (violations: Array<Record<string, any>>, untouchedIndexes: number[]) => void,
): { root: string; value: R7Manifest } {
  const fixture = stagedFixture(stage);
  const ownershipPath = path.join(
    fixture.root,
    'backend',
    'architecture',
    'ownership-baseline.json',
  );
  const baseline = JSON.parse(readFileSync(ownershipPath, 'utf8')) as {
    violations: Array<Record<string, any>>;
  };
  const projectedPaths = new Set(fixture.value.historicalHandoffs.ownershipProjection.flatMap(
    (projection) => [projection.from, projection.to],
  ));
  const untouchedIndexes = baseline.violations.flatMap((record, index) => (
    projectedPaths.has(String(record.file)) ? [] : [index]
  ));
  assert.ok(untouchedIndexes.length >= 2);
  mutate(baseline.violations, untouchedIndexes);
  writeJson(ownershipPath, baseline);
  return fixture;
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
  assert.equal(value.stage, 'strict');
  assert.deepEqual(value.moves, expectedMoves);
  assert.equal(new Set(value.moves.map((move) => move.from)).size, 18);
  assert.equal(new Set(value.moves.map((move) => move.to)).size, 18);
  assert.deepEqual(value.sourceParity, expectedSourceParity);
});

test('R7 strict stage preserves the history API, providers, aliases, exports, and imports', () => {
  const value = scanner().validateR7Manifest(manifest());
  assert.deepEqual(scanner().verifyHistoryRelocation(repositoryRoot, value), {
    controllers: 1,
    providers: 2,
    aliases: 2,
    exports: 4,
    legacyRuntimeImports: 0,
  });
});

test('R7 strict stage pins final layout, API, providers, DI, builder, and baselines', () => {
  const value = scanner().validateR7Manifest(manifest());
  assert.equal(value.stage, 'strict');
  assert.deepEqual(scanner().verifyStrictRelocationState(repositoryRoot, value), {
    legacyRoots: 0,
    legacyImportLiterals: 0,
    retiredDependencyKeys: 0,
    protectedRuntimeImports: 0,
    duplicatePublicExports: 0,
    unregisteredTargetFiles: 0,
    reparsePoints: 0,
    forwardRef: 0,
    globals: 2,
  });
  assert.deepEqual(scanner().verifyPublicSnapshotSource(repositoryRoot, value), {
    exports: 4,
    imports: 3,
  });
  assert.deepEqual(scanner().verifyPublicSnapshotConsumers(repositoryRoot), {
    callers: 11,
    testImports: 2,
  });
  assert.deepEqual(scanner().verifyConstructorHandoffs(repositoryRoot, value), {
    consumers: 4,
    optional: 1,
  });
  assert.deepEqual(scanner().verifyControllerHandoffs(repositoryRoot, value), {
    controllers: 2,
    operations: 19,
  });
  assert.deepEqual(scanner().verifySharingRelocation(repositoryRoot, value), {
    controllers: 7,
    operations: 17,
    providers: 4,
    aliases: 1,
    exports: 4,
    legacyRuntimeImports: 0,
  });
  assert.deepEqual(scanner().scanR7CollaborationRelocation({ repositoryRoot, manifest: value }), {
    ok: true,
    stage: 'strict',
    sourceFiles: 0,
    targetFiles: 18,
    dependencyRecords: 22,
    ownershipRecords: 385,
    ownershipOccurrences: 781,
  });
});

test('R7 strict stage rejects every compatibility, boundary, topology, and Nest regression', () => {
  const cases: Array<{
    name: string;
    error: RegExp;
    mutate(root: string, value: R7Manifest): void;
  }> = [
    {
      name: 'retained legacy root',
      error: /R7 strict stage retains a legacy root/u,
      mutate(root) {
        mkdirSync(path.join(root, 'backend', 'src', 'sharing'), { recursive: true });
      },
    },
    {
      name: 'legacy import literal',
      error: /R7 Sharing legacy runtime import drift detected/u,
      mutate(root) {
        writeFixtureFile(
          root,
          'backend/src/tasks/legacy-sharing-import.ts',
          'import "../sharing/sharing.service";\n',
        );
      },
    },
    {
      name: 'retired dependency key',
      error: /R7 dependency identity drift detected/u,
      mutate(root, value) {
        const dependencyPath = path.join(
          root,
          'backend',
          '.dependency-cruiser-known-violations.json',
        );
        const dependency = JSON.parse(readFileSync(dependencyPath, 'utf8')) as Array<{
          rule: { name: string };
          from: string;
          to: string;
        }>;
        const historical = JSON.parse(execFileSync(
          'git',
          ['show', `${value.baseRevision}:backend/.dependency-cruiser-known-violations.json`],
          { cwd: repositoryRoot, encoding: 'utf8' },
        )) as typeof dependency;
        const retired = historical.find((record) => (
          [record.rule.name, record.from, record.to].join('|') === expectedDependencyKeys[0]
        ));
        assert.ok(retired);
        const originalLength = dependency.length;
        const originalUniqueCount = new Set(dependency.map((record) => (
          [record.rule.name, record.from, record.to].join('|')
        ))).size;
        dependency[0] = retired;
        assert.equal(dependency.length, originalLength);
        assert.equal(new Set(dependency.map((record) => (
          [record.rule.name, record.from, record.to].join('|')
        ))).size, originalUniqueCount);
        writeJson(dependencyPath, dependency);
      },
    },
    {
      name: 'cross-context internal import',
      error: /R7 cross-context runtime import enters Collaboration internal or api/u,
      mutate(root) {
        writeFixtureFile(
          root,
          'backend/src/tasks/collaboration-internal-import.ts',
          'import "../modules/collaboration/internal/sharing.service";\n',
        );
      },
    },
    {
      name: 'duplicate public export',
      error: /R7 strict stage contains a duplicate public snapshot export/u,
      mutate(root) {
        writeFixtureFile(
          root,
          'backend/src/tasks/duplicate-contribution-snapshot.ts',
          'export const buildContributionSnapshot = () => undefined;\n',
        );
      },
    },
    {
      name: 'unregistered target file',
      error: /R7 final Collaboration inventory drift detected/u,
      mutate(root) {
        writeFixtureFile(
          root,
          'backend/src/modules/collaboration/internal/unregistered.ts',
          'export const unregistered = true;\n',
        );
      },
    },
    {
      name: 'directory junction',
      error: /R7 source contains a symbolic or junction reparse point/u,
      mutate(root) {
        const dto = path.join(root, 'backend', 'src', 'modules', 'collaboration', 'api', 'dto');
        const outside = path.join(root, 'strict-junction-target');
        cpSync(dto, outside, { recursive: true });
        rmSync(dto, { recursive: true, force: true });
        symlinkSync(outside, dto, process.platform === 'win32' ? 'junction' : 'dir');
      },
    },
    {
      name: 'forwardRef call',
      error: /R7 strict stage contains forwardRef\(\)/u,
      mutate(root) {
        writeFixtureFile(
          root,
          'backend/src/tasks/forward-ref.module.ts',
          [
            "import { forwardRef } from '@nestjs/common';",
            'class Dependency {}',
            'void forwardRef(() => Dependency);',
            '',
          ].join('\n'),
        );
      },
    },
    {
      name: 'new global module',
      error: /R7 strict globals drift detected/u,
      mutate(root) {
        writeFixtureFile(
          root,
          'backend/src/tasks/global.module.ts',
          [
            "import { Global, Module } from '@nestjs/common';",
            '@Global()',
            '@Module({})',
            'export class TaskGlobalModule {}',
            '',
          ].join('\n'),
        );
      },
    },
  ];

  for (const fixtureCase of cases) {
    const fixture = stagedFixture('strict');
    try {
      fixtureCase.mutate(fixture.root, fixture.value);
      assert.throws(
        () => scanner().scanR7CollaborationRelocation({
          repositoryRoot: fixture.root,
          manifest: fixture.value,
        }),
        fixtureCase.error,
        fixtureCase.name,
      );
    } finally {
      rmSync(fixture.root, { recursive: true, force: true });
    }
  }
});

for (const form of [
  {
    name: 'const alias',
    source: [
      "import { forwardRef as NestForwardRef } from '@nestjs/common';",
      'class Dependency {}',
      'const hiddenForwardRef = NestForwardRef;',
      'void hiddenForwardRef(() => Dependency);',
      '',
    ].join('\n'),
  },
  {
    name: 'import equals namespace',
    source: [
      "import NestCommon = require('@nestjs/common');",
      'class Dependency {}',
      'void NestCommon.forwardRef(() => Dependency);',
      '',
    ].join('\n'),
  },
  {
    name: 'require namespace',
    source: [
      "const NestCommon = require('@nestjs/common');",
      'class Dependency {}',
      'void NestCommon.forwardRef(() => Dependency);',
      '',
    ].join('\n'),
  },
  {
    name: 'ES namespace',
    source: [
      "import * as NestCommon from '@nestjs/common';",
      'class Dependency {}',
      'void NestCommon.forwardRef(() => Dependency);',
      '',
    ].join('\n'),
  },
]) {
  test(`R7 strict Nest rejects real forwardRef through ${form.name}`, () => {
    const fixture = stagedFixture('strict');
    try {
      writeFixtureFile(
        fixture.root,
        'backend/src/tasks/nest-forward-ref-bypass.ts',
        form.source,
      );
      assert.throws(
        () => scanner().scanR7CollaborationRelocation({
          repositoryRoot: fixture.root,
          manifest: fixture.value,
        }),
        /R7 strict stage contains forwardRef\(\)/u,
      );
    } finally {
      rmSync(fixture.root, { recursive: true, force: true });
    }
  });
}

for (const form of [
  {
    name: 'const alias',
    source: [
      "import { Global as NestGlobal } from '@nestjs/common';",
      'const hiddenGlobal = NestGlobal;',
      '@hiddenGlobal()',
      'export class HiddenGlobalModule {}',
      '',
    ].join('\n'),
  },
  {
    name: 'import equals namespace',
    source: [
      "import NestCommon = require('@nestjs/common');",
      '@NestCommon.Global()',
      'export class ImportEqualsGlobalModule {}',
      '',
    ].join('\n'),
  },
  {
    name: 'require namespace',
    source: [
      "const NestCommon = require('@nestjs/common');",
      '@NestCommon.Global()',
      'export class RequireGlobalModule {}',
      '',
    ].join('\n'),
  },
  {
    name: 'ES namespace',
    source: [
      "import * as NestCommon from '@nestjs/common';",
      '@NestCommon.Global()',
      'export class NamespaceGlobalModule {}',
      '',
    ].join('\n'),
  },
]) {
  test(`R7 strict Nest rejects real Global decorator through ${form.name}`, () => {
    const fixture = stagedFixture('strict');
    try {
      writeFixtureFile(
        fixture.root,
        'backend/src/tasks/nest-global-bypass.module.ts',
        form.source,
      );
      assert.throws(
        () => scanner().scanR7CollaborationRelocation({
          repositoryRoot: fixture.root,
          manifest: fixture.value,
        }),
        /R7 strict globals drift detected/u,
      );
    } finally {
      rmSync(fixture.root, { recursive: true, force: true });
    }
  });
}

for (const fixtureCase of [
  {
    name: 'a shadowed imported Global binding',
    source: [
      "import { Global } from '@nestjs/common';",
      'function invoke(Global: () => unknown) { return Global(); }',
      'void Global;',
      'void invoke(() => undefined);',
      '',
    ].join('\n'),
  },
  {
    name: 'a real Nest Global call outside decorator context',
    source: [
      "import { Global } from '@nestjs/common';",
      'void Global();',
      '',
    ].join('\n'),
  },
  {
    name: 'an ordinary local Global call',
    source: [
      'function Global() { return undefined; }',
      'void Global();',
      '',
    ].join('\n'),
  },
]) {
  test(`R7 strict Nest permits ${fixtureCase.name}`, () => {
    const fixture = stagedFixture('strict');
    try {
      writeFixtureFile(
        fixture.root,
        'backend/src/tasks/ordinary-global-call.ts',
        fixtureCase.source,
      );
      assert.deepEqual(scanner().scanR7CollaborationRelocation({
        repositoryRoot: fixture.root,
        manifest: fixture.value,
      }), {
        ok: true,
        stage: 'strict',
        sourceFiles: 0,
        targetFiles: 18,
        dependencyRecords: 22,
        ownershipRecords: 385,
        ownershipOccurrences: 781,
      });
    } finally {
      rmSync(fixture.root, { recursive: true, force: true });
    }
  });
}

for (const fixtureCase of [
  {
    name: 'qualified import-equals forwardRef alias',
    files: {
      'backend/src/tasks/qualified-forward-ref.ts': [
        "import NestCommon = require('@nestjs/common');",
        'import HiddenForwardRef = NestCommon.forwardRef;',
        'class Dependency {}',
        'void HiddenForwardRef(() => Dependency);',
        '',
      ].join('\n'),
    },
    error: /R7 strict stage contains forwardRef\(\)/u,
  },
  {
    name: 'qualified import-equals Global alias',
    files: {
      'backend/src/tasks/qualified-global.module.ts': [
        "import NestCommon = require('@nestjs/common');",
        'import HiddenGlobal = NestCommon.Global;',
        '@HiddenGlobal()',
        'export class QualifiedGlobalModule {}',
        '',
      ].join('\n'),
    },
    error: /R7 strict globals drift detected/u,
  },
  {
    name: 'cross-file const forwardRef alias',
    files: {
      'backend/src/tasks/nest-forward-ref-alias.ts': [
        "import { forwardRef } from '@nestjs/common';",
        'export const hiddenForwardRef = forwardRef;',
        '',
      ].join('\n'),
      'backend/src/tasks/cross-file-forward-ref.ts': [
        "import { hiddenForwardRef } from './nest-forward-ref-alias';",
        'class Dependency {}',
        'void hiddenForwardRef(() => Dependency);',
        '',
      ].join('\n'),
    },
    error: /R7 strict stage contains forwardRef\(\)/u,
  },
  {
    name: 'cross-file const Global alias',
    files: {
      'backend/src/tasks/nest-global-alias.ts': [
        "import { Global } from '@nestjs/common';",
        'export const hiddenGlobal = Global;',
        '',
      ].join('\n'),
      'backend/src/tasks/cross-file-global.module.ts': [
        "import { hiddenGlobal } from './nest-global-alias';",
        '@hiddenGlobal()',
        'export class CrossFileGlobalModule {}',
        '',
      ].join('\n'),
    },
    error: /R7 strict globals drift detected/u,
  },
  {
    name: 'cross-file forwardRef re-export alias',
    files: {
      'backend/src/tasks/nest-forward-ref-reexport.ts': [
        "export { forwardRef as hiddenForwardRef } from '@nestjs/common';",
        '',
      ].join('\n'),
      'backend/src/tasks/reexported-forward-ref.ts': [
        "import { hiddenForwardRef } from './nest-forward-ref-reexport';",
        'class Dependency {}',
        'void hiddenForwardRef(() => Dependency);',
        '',
      ].join('\n'),
    },
    error: /R7 strict stage contains forwardRef\(\)/u,
  },
  {
    name: 'cross-file Global re-export alias',
    files: {
      'backend/src/tasks/nest-global-reexport.ts': [
        "export { Global as hiddenGlobal } from '@nestjs/common';",
        '',
      ].join('\n'),
      'backend/src/tasks/reexported-global.module.ts': [
        "import { hiddenGlobal } from './nest-global-reexport';",
        '@hiddenGlobal()',
        'export class ReexportedGlobalModule {}',
        '',
      ].join('\n'),
    },
    error: /R7 strict globals drift detected/u,
  },
]) {
  test(`R7 strict Nest rejects ${fixtureCase.name}`, () => {
    const fixture = stagedFixture('strict');
    try {
      for (const [relativePath, source] of Object.entries(fixtureCase.files)) {
        writeFixtureFile(fixture.root, relativePath, source);
      }
      assert.throws(
        () => scanner().scanR7CollaborationRelocation({
          repositoryRoot: fixture.root,
          manifest: fixture.value,
        }),
        fixtureCase.error,
      );
    } finally {
      rmSync(fixture.root, { recursive: true, force: true });
    }
  });
}

for (const fixtureCase of [
  {
    name: 'a qualified import-equals local Global homonym',
    files: {
      'backend/src/tasks/qualified-local-global.module.ts': [
        'namespace LocalNest {',
        '  export function Global() { return (_target: unknown) => undefined; }',
        '}',
        'import LocalGlobal = LocalNest.Global;',
        '@LocalGlobal()',
        'export class QualifiedLocalGlobalModule {}',
        '',
      ].join('\n'),
    },
  },
  {
    name: 'a cross-file local Global alias and re-export',
    files: {
      'backend/src/tasks/local-global.ts': [
        'export function Global() { return (_target: unknown) => undefined; }',
        '',
      ].join('\n'),
      'backend/src/tasks/local-global-alias.ts': [
        "import { Global } from './local-global';",
        'export const hiddenGlobal = Global;',
        '',
      ].join('\n'),
      'backend/src/tasks/local-global-reexport.ts': [
        "export { hiddenGlobal as ordinaryGlobal } from './local-global-alias';",
        '',
      ].join('\n'),
      'backend/src/tasks/local-global-consumer.module.ts': [
        "import { ordinaryGlobal } from './local-global-reexport';",
        '@ordinaryGlobal()',
        'export class LocalGlobalConsumerModule {}',
        '',
      ].join('\n'),
    },
  },
  {
    name: 'a cross-file local forwardRef alias and re-export',
    files: {
      'backend/src/tasks/local-forward-ref.ts': [
        'export function forwardRef(callback: () => unknown) { return callback; }',
        '',
      ].join('\n'),
      'backend/src/tasks/local-forward-ref-reexport.ts': [
        "export { forwardRef as ordinaryForwardRef } from './local-forward-ref';",
        '',
      ].join('\n'),
      'backend/src/tasks/local-forward-ref-consumer.ts': [
        "import { ordinaryForwardRef } from './local-forward-ref-reexport';",
        'class Dependency {}',
        'void ordinaryForwardRef(() => Dependency);',
        '',
      ].join('\n'),
    },
  },
]) {
  test(`R7 strict Nest permits ${fixtureCase.name}`, () => {
    const fixture = stagedFixture('strict');
    try {
      for (const [relativePath, source] of Object.entries(fixtureCase.files)) {
        writeFixtureFile(fixture.root, relativePath, source);
      }
      assert.deepEqual(scanner().scanR7CollaborationRelocation({
        repositoryRoot: fixture.root,
        manifest: fixture.value,
      }), {
        ok: true,
        stage: 'strict',
        sourceFiles: 0,
        targetFiles: 18,
        dependencyRecords: 22,
        ownershipRecords: 385,
        ownershipOccurrences: 781,
      });
    } finally {
      rmSync(fixture.root, { recursive: true, force: true });
    }
  });
}

for (const fixtureCase of [
  {
    name: 'a stored Nest Global decorator used with decorator syntax',
    mutate(source: string): string {
      return source
        .replace(
          'import { Module } from "@nestjs/common";',
          'import { Global, Module } from "@nestjs/common";',
        )
        .replace(
          '@Module({',
          ['const hiddenGlobalDecorator = Global();', '@hiddenGlobalDecorator', '@Module({'].join('\n'),
        );
    },
  },
  {
    name: 'a directly applied Nest Global decorator factory result',
    mutate(source: string): string {
      return source
        .replace(
          'import { Module } from "@nestjs/common";',
          'import { Global, Module } from "@nestjs/common";',
        )
        .replace(
          'export class CollaborationModule {}',
          ['export class CollaborationModule {}', 'Global()(CollaborationModule);'].join('\n'),
        );
    },
  },
]) {
  test(`R7 strict Global application rejects ${fixtureCase.name}`, () => {
    const fixture = stagedFixture('strict');
    try {
      mutateFixtureFile(
        fixture.root,
        'backend/src/modules/collaboration/collaboration.module.ts',
        fixtureCase.mutate,
      );
      assert.throws(
        () => scanner().scanR7CollaborationRelocation({
          repositoryRoot: fixture.root,
          manifest: fixture.value,
        }),
        /R7 strict globals drift detected/u,
      );
    } finally {
      rmSync(fixture.root, { recursive: true, force: true });
    }
  });
}

test('R7 strict Global application permits a detached unused Nest Global decorator result', () => {
  const fixture = stagedFixture('strict');
  try {
    mutateFixtureFile(
      fixture.root,
      'backend/src/modules/collaboration/collaboration.module.ts',
      (source) => source
        .replace(
          'import { Module } from "@nestjs/common";',
          'import { Global, Module } from "@nestjs/common";',
        )
        .replace(
          '@Module({',
          ['const detachedGlobalDecorator = Global();', 'void detachedGlobalDecorator;', '@Module({'].join('\n'),
        ),
    );
    assert.deepEqual(scanner().scanR7CollaborationRelocation({
      repositoryRoot: fixture.root,
      manifest: fixture.value,
    }), {
      ok: true,
      stage: 'strict',
      sourceFiles: 0,
      targetFiles: 18,
      dependencyRecords: 22,
      ownershipRecords: 385,
      ownershipOccurrences: 781,
    });
  } finally {
    rmSync(fixture.root, { recursive: true, force: true });
  }
});

for (const fixtureCase of [
  {
    name: 'object property decorator',
    setup: [
      'const decorators = { global: Global() };',
      '@decorators.global',
    ].join('\n'),
  },
  {
    name: 'destructured object property decorator',
    setup: [
      'const decorators = { global: Global() };',
      'const { global: hiddenGlobal } = decorators;',
      '@hiddenGlobal',
    ].join('\n'),
  },
  {
    name: 'later-assigned decorator',
    setup: [
      'const ordinaryDecorator: ClassDecorator = () => undefined;',
      'let hiddenGlobal = ordinaryDecorator;',
      'hiddenGlobal = Global();',
      '@hiddenGlobal',
    ].join('\n'),
  },
]) {
  test(`R7 semantic Global result rejects ${fixtureCase.name}`, () => {
    const fixture = stagedFixture('strict');
    try {
      mutateFixtureFile(
        fixture.root,
        'backend/src/modules/collaboration/collaboration.module.ts',
        (source) => source
          .replace(
            'import { Module } from "@nestjs/common";',
            'import { Global, Module } from "@nestjs/common";',
          )
          .replace('@Module({', `${fixtureCase.setup}\n@Module({`),
      );
      assert.throws(
        () => scanner().scanR7CollaborationRelocation({
          repositoryRoot: fixture.root,
          manifest: fixture.value,
        }),
        /R7 strict globals drift detected/u,
      );
    } finally {
      rmSync(fixture.root, { recursive: true, force: true });
    }
  });
}

for (const fixtureCase of [
  {
    name: 'detached object property',
    importGlobal: true,
    setup: [
      'const decorators = { global: Global() };',
      'void decorators.global;',
    ].join('\n'),
  },
  {
    name: 'reassigned-away decorator variable',
    importGlobal: true,
    setup: [
      'const ordinaryDecorator: ClassDecorator = () => undefined;',
      'let hiddenGlobal = Global();',
      'hiddenGlobal = ordinaryDecorator;',
      '@hiddenGlobal',
    ].join('\n'),
  },
  {
    name: 'reassigned-away object property',
    importGlobal: true,
    setup: [
      'const ordinaryDecorator: ClassDecorator = () => undefined;',
      'const decorators = { global: Global() };',
      'decorators.global = ordinaryDecorator;',
      '@decorators.global',
    ].join('\n'),
  },
  {
    name: 'local Global homonym object property',
    importGlobal: false,
    setup: [
      'function Global(): ClassDecorator { return () => undefined; }',
      'const decorators = { global: Global() };',
      '@decorators.global',
    ].join('\n'),
  },
]) {
  test(`R7 semantic Global result permits ${fixtureCase.name}`, () => {
    const fixture = stagedFixture('strict');
    try {
      mutateFixtureFile(
        fixture.root,
        'backend/src/modules/collaboration/collaboration.module.ts',
        (source) => {
          const imported = fixtureCase.importGlobal
            ? source.replace(
              'import { Module } from "@nestjs/common";',
              'import { Global, Module } from "@nestjs/common";',
            )
            : source;
          return imported.replace('@Module({', `${fixtureCase.setup}\n@Module({`);
        },
      );
      assert.deepEqual(scanner().scanR7CollaborationRelocation({
        repositoryRoot: fixture.root,
        manifest: fixture.value,
      }), {
        ok: true,
        stage: 'strict',
        sourceFiles: 0,
        targetFiles: 18,
        dependencyRecords: 22,
        ownershipRecords: 385,
        ownershipOccurrences: 781,
      });
    } finally {
      rmSync(fixture.root, { recursive: true, force: true });
    }
  });
}

const finiteCandidateGlobalResultCases = [
  {
    name: 'array binding',
    setup: [
      'const [hiddenGlobal] = [Global()];',
      '@hiddenGlobal',
    ].join('\n'),
  },
  {
    name: 'conditional branch',
    setup: [
      'const ordinaryDecorator: ClassDecorator = () => undefined;',
      'const useNest = Boolean(Date.now());',
      'const hiddenGlobal = useNest ? Global() : ordinaryDecorator;',
      '@hiddenGlobal',
    ].join('\n'),
  },
  {
    name: 'logical or branch',
    setup: [
      'const ordinaryDecorator: ClassDecorator = () => undefined;',
      'const hiddenGlobal = ordinaryDecorator || Global();',
      '@hiddenGlobal',
    ].join('\n'),
  },
  {
    name: 'nullish branch',
    setup: [
      'const ordinaryDecorator: ClassDecorator = () => undefined;',
      'const maybeDecorator: ClassDecorator | null = ordinaryDecorator;',
      'const hiddenGlobal = maybeDecorator ?? Global();',
      '@hiddenGlobal',
    ].join('\n'),
  },
  {
    name: 'logical and branch',
    setup: [
      'const useNest = Boolean(Date.now());',
      'const hiddenGlobal = useNest && Global();',
      '@hiddenGlobal',
    ].join('\n'),
  },
];

test('R7 semantic Global inspector rejects every dangerous finite candidate and permits local branches', () => {
  const sources = Object.fromEntries(finiteCandidateGlobalResultCases.map((fixtureCase, index) => [
    `dangerous-global-${index}`,
    `import { Global } from "@nestjs/common";\n${fixtureCase.setup}\nclass Example {}\n`,
  ]));
  sources.local = [
    'const ordinaryDecorator: ClassDecorator = () => undefined;',
    'const otherDecorator: ClassDecorator = () => undefined;',
    'const useOther = Boolean(Date.now());',
    'const [arrayDecorator] = [ordinaryDecorator];',
    'const conditionalDecorator = useOther ? arrayDecorator : otherDecorator;',
    'const orDecorator = conditionalDecorator || otherDecorator;',
    'const nullishDecorator = orDecorator ?? ordinaryDecorator;',
    'const finalDecorator = useOther && nullishDecorator;',
    '@finalDecorator',
    'class Example {}',
    '',
  ].join('\n');
  const inspections = inspectSemanticFixtureSources(sources);
  finiteCandidateGlobalResultCases.forEach((fixtureCase, index) => {
    assert.equal(
      inspections[`dangerous-global-${index}`].globalApplications,
      1,
      fixtureCase.name,
    );
  });
  assert.equal(inspections.local.globalApplications, 0);
});

test('R7 finite candidate Global array binding reaches the strict globals gate', () => {
  const fixture = stagedFixture('strict');
  try {
    mutateFixtureFile(
      fixture.root,
      'backend/src/modules/collaboration/collaboration.module.ts',
      (source) => source
        .replace(
          'import { Module } from "@nestjs/common";',
          'import { Global, Module } from "@nestjs/common";',
        )
        .replace('@Module({', `${finiteCandidateGlobalResultCases[0].setup}\n@Module({`),
    );
    assert.throws(
      () => scanner().scanR7CollaborationRelocation({
        repositoryRoot: fixture.root,
        manifest: fixture.value,
      }),
      /R7 strict globals drift detected/u,
    );
  } finally {
    rmSync(fixture.root, { recursive: true, force: true });
  }
});

for (const providerCase of [
  {
    name: 'external useClass registration through an imported alias',
    source: `
import { Module } from '@nestjs/common';
import { SharingService as RenamedSharingService } from './modules/collaboration/internal/sharing.service';

const SECOND_SHARING = Symbol('SECOND_SHARING');

@Module({
  providers: [{ provide: SECOND_SHARING, useClass: RenamedSharingService }],
})
export class ExternalSharingUseClassModule {}
`,
  },
  {
    name: 'external useExisting registration through a local alias',
    source: `
import { Module } from '@nestjs/common';
import { SharingService } from './modules/collaboration/internal/sharing.service';

const SECOND_SHARING = Symbol('SECOND_SHARING');
const SharingAlias = SharingService;

@Module({
  providers: [{ provide: SECOND_SHARING, useExisting: SharingAlias }],
})
export class ExternalSharingUseExistingModule {}
`,
  },
  {
    name: 'external spread registration through a provider alias',
    source: `
import { Module } from '@nestjs/common';
import { SharingService } from './modules/collaboration/internal/sharing.service';

const SharingAlias = SharingService;
const extraProviders = [SharingAlias];

@Module({
  providers: [...extraProviders],
})
export class ExternalSharingSpreadModule {}
`,
  },
  {
    name: 'external property-access registration through an object shorthand',
    source: `
import { Module } from '@nestjs/common';
import { SharingService } from './modules/collaboration/internal/sharing.service';

const SECOND_SHARING = Symbol('SECOND_SHARING');
const Registry = { SharingService };

@Module({
  providers: [{ provide: SECOND_SHARING, useClass: Registry.SharingService }],
})
export class ExternalSharingPropertyAccessModule {}
`,
  },
  {
    name: 'external destructuring registration through a property alias',
    source: `
import { Module } from '@nestjs/common';
import { InviteAccessService } from './modules/collaboration/internal/invite-access.service';

const SECOND_INVITE_ACCESS = Symbol('SECOND_INVITE_ACCESS');
const Registry = { inviteAccess: InviteAccessService };
const { inviteAccess: InviteAccessAlias } = Registry;

@Module({
  providers: [{ provide: SECOND_INVITE_ACCESS, useClass: InviteAccessAlias }],
})
export class ExternalInviteAccessDestructuringModule {}
`,
  },
  {
    name: 'external frozen provider object and array registration',
    source: `
import { Module } from '@nestjs/common';
import { SharingService } from './modules/collaboration/internal/sharing.service';

const SECOND_SHARING = Symbol('SECOND_SHARING');
const frozenProvider = Object.freeze({ provide: SECOND_SHARING, useClass: SharingService });
const frozenProviders = Object.freeze([frozenProvider]);

@Module({
  providers: [...frozenProviders],
})
export class ExternalFrozenSharingModule {}
`,
  },
]) {
  test(`R7 Sharing topology rejects ${providerCase.name}`, () => {
    const fixture = stagedFixture('relocated');
    try {
      writeFixtureFile(
        fixture.root,
        'backend/src/external-sharing-topology.module.ts',
        providerCase.source,
      );
      assert.throws(
        () => scanner().verifySharingRelocation(fixture.root, fixture.value),
        /provider singleton drift/u,
      );
    } finally {
      rmSync(fixture.root, { recursive: true, force: true });
    }
  });
}

test('R7 Sharing topology permits same-name unrelated provider objects and spreads', () => {
  const fixture = stagedFixture('relocated');
  try {
    writeFixtureFile(
      fixture.root,
      'backend/src/unrelated-provider-topology.module.ts',
      `
import { Module } from '@nestjs/common';

class SharingService {}
const UnrelatedAlias = SharingService;
const UNRELATED_ALIAS = Symbol('UNRELATED_ALIAS');
const unrelatedProviders = [
  { provide: UNRELATED_ALIAS, useClass: UnrelatedAlias },
  { provide: 'UNRELATED_EXISTING', useExisting: SharingService },
];

@Module({
  providers: [...unrelatedProviders],
})
export class UnrelatedProviderTopologyModule {}
`,
    );
    assert.deepEqual(scanner().verifySharingRelocation(fixture.root, fixture.value), {
      controllers: 7,
      operations: 17,
      providers: 4,
      aliases: 1,
      exports: 4,
      legacyRuntimeImports: 0,
    });
  } finally {
    rmSync(fixture.root, { recursive: true, force: true });
  }
});

test('R7 Sharing topology permits unrelated frozen module metadata', () => {
  const fixture = stagedFixture('relocated');
  try {
    writeFixtureFile(
      fixture.root,
      'backend/src/unrelated-frozen-metadata.module.ts',
      `
import { Module } from '@nestjs/common';

const unrelatedMetadata = Object.freeze({ imports: [] });

@Module({
  ...unrelatedMetadata,
  providers: [],
})
export class UnrelatedFrozenMetadataModule {}
`,
    );
    assert.deepEqual(scanner().verifySharingRelocation(fixture.root, fixture.value), {
      controllers: 7,
      operations: 17,
      providers: 4,
      aliases: 1,
      exports: 4,
      legacyRuntimeImports: 0,
    });
  } finally {
    rmSync(fixture.root, { recursive: true, force: true });
  }
});

test('R7 Sharing topology permits frozen objects and arrays for a same-name local class', () => {
  const fixture = stagedFixture('relocated');
  try {
    writeFixtureFile(
      fixture.root,
      'backend/src/unrelated-frozen-provider.module.ts',
      `
import { Module } from '@nestjs/common';

class SharingService {}
const unrelatedDetails = Object.freeze({ useClass: SharingService });
const unrelatedProvider = Object.freeze({ provide: 'UNRELATED', ...unrelatedDetails });
const unrelatedProviders = Object.freeze([unrelatedProvider]);

@Module({
  providers: [...unrelatedProviders],
})
export class UnrelatedFrozenProviderModule {}
`,
    );
    assert.deepEqual(scanner().verifySharingRelocation(fixture.root, fixture.value), {
      controllers: 7,
      operations: 17,
      providers: 4,
      aliases: 1,
      exports: 4,
      legacyRuntimeImports: 0,
    });
  } finally {
    rmSync(fixture.root, { recursive: true, force: true });
  }
});

test('R7 Sharing topology fails closed on cyclic provider spread aliases', () => {
  const fixture = stagedFixture('relocated');
  try {
    writeFixtureFile(
      fixture.root,
      'backend/src/cyclic-provider-topology.module.ts',
      `
import { Module } from '@nestjs/common';

const cyclicProviders: unknown[] = [...cyclicProviders];

@Module({
  providers: [...cyclicProviders],
})
export class CyclicProviderTopologyModule {}
`,
    );
    assert.throws(
      () => scanner().verifySharingRelocation(fixture.root, fixture.value),
      /could not resolve providers spread/u,
    );
  } finally {
    rmSync(fixture.root, { recursive: true, force: true });
  }
});

test('R7 Sharing topology fails closed on cyclic object spread during provider destructuring', () => {
  const fixture = stagedFixture('relocated');
  try {
    writeFixtureFile(
      fixture.root,
      'backend/src/cyclic-provider-object.module.ts',
      `
import { Module } from '@nestjs/common';
import { SharingService } from './modules/collaboration/internal/sharing.service';

const SECOND_SHARING = Symbol('SECOND_SHARING');
const Registry = { SharingService, ...Registry };
const { SharingService: SharingAlias } = Registry;

@Module({
  providers: [{ provide: SECOND_SHARING, useClass: SharingAlias }],
})
export class CyclicProviderObjectModule {}
`,
    );
    assert.throws(
      () => scanner().verifySharingRelocation(fixture.root, fixture.value),
      (error: unknown) => {
        assert.ok(error instanceof Error);
        assert.ok(!(error instanceof RangeError));
        assert.equal(
          error.message,
          'R7 Sharing provider topology could not resolve provider identity',
        );
        return true;
      },
    );
  } finally {
    rmSync(fixture.root, { recursive: true, force: true });
  }
});

for (const fixtureCase of [
  {
    name: 'SharingService constructor index drift',
    file: 'backend/src/modules/collaboration/internal/sharing.service.ts',
    mutate: (source: string) => source.replace(
      'private readonly notifications: NotificationsPort,',
      'private readonly __r7_swap__: NotificationsPort,',
    ).replace(
      'private readonly history: ContributionHistoryService,',
      'private readonly notifications: NotificationsPort,',
    ).replace(
      'private readonly __r7_swap__: NotificationsPort,',
      'private readonly history: ContributionHistoryService,',
    ),
    verify: (root: string, value: R7Manifest) => scanner().verifyConstructorHandoffs(root, value),
    error: /constructor parameter drift/u,
  },
  {
    name: 'SharingService notification token drift',
    file: 'backend/src/modules/collaboration/internal/sharing.service.ts',
    mutate: (source: string) => source.replace(
      '@Inject(NOTIFICATIONS_PORT)',
      '@Inject(MESSAGING_REALTIME_PORT)',
    ),
    verify: (root: string, value: R7Manifest) => scanner().verifyConstructorHandoffs(root, value),
    error: /constructor injection drift/u,
  },
  {
    name: 'SharingService class drift',
    file: 'backend/src/modules/collaboration/internal/sharing.service.ts',
    mutate: (source: string) => source.replace(
      'export class SharingService',
      'export class ChangedSharingService',
    ),
    verify: (root: string, value: R7Manifest) => scanner().verifyConstructorHandoffs(root, value),
    error: /constructor class drift/u,
  },
  {
    name: 'SharingService @Optional drift',
    file: 'backend/src/modules/collaboration/internal/sharing.service.ts',
    mutate: (source: string) => source.replace('@Optional()\n', ''),
    verify: (root: string, value: R7Manifest) => scanner().verifyConstructorHandoffs(root, value),
    error: /constructor optionality drift/u,
  },
  {
    name: 'SharingService question-token drift',
    file: 'backend/src/modules/collaboration/internal/sharing.service.ts',
    mutate: (source: string) => source.replace(
      'private readonly realtime?: MessagingRealtimePort,',
      'private readonly realtime: MessagingRealtimePort,',
    ),
    verify: (root: string, value: R7Manifest) => scanner().verifyConstructorHandoffs(root, value),
    error: /constructor optionality drift/u,
  },
  {
    name: 'SharingService default initializer drift',
    file: 'backend/src/modules/collaboration/internal/sharing.service.ts',
    mutate: (source: string) => source.replace(
      'private readonly prisma: PrismaService,',
      'private readonly prisma: PrismaService = undefined as never,',
    ),
    verify: (root: string, value: R7Manifest) => scanner().verifyConstructorHandoffs(root, value),
    error: /constructor default drift/u,
  },
  {
    name: 'duplicate SharingService provider',
    file: 'backend/src/modules/collaboration/internal/collaboration-services.internal.module.ts',
    mutate: (source: string) => source.replace(
      'providers: [SharingService, InvitationDeliveryService, InviteAccessService]',
      'providers: [SharingService, SharingService, InvitationDeliveryService, InviteAccessService]',
    ),
    verify: (root: string, value: R7Manifest) => scanner().verifySharingRelocation(root, value),
    error: /sharing module providers/u,
  },
  {
    name: 'Sharing controller route drift',
    file: 'backend/src/modules/collaboration/api/sharing.controller.ts',
    mutate: (source: string) => source.replace('@Post(":token/accept")', '@Post(":token/changed")'),
    verify: (root: string, value: R7Manifest) => scanner().verifyControllerHandoffs(root, value),
    error: /controller inventory drift/u,
  },
  {
    name: 'Sharing controller guard drift',
    file: 'backend/src/modules/collaboration/api/sharing.controller.ts',
    mutate: (source: string) => source.replace('@UseGuards(JwtAuthGuard)', '@UseGuards()'),
    verify: (root: string, value: R7Manifest) => scanner().verifyControllerHandoffs(root, value),
    error: /controller inventory drift/u,
  },
  {
    name: 'Sharing DTO decorator drift',
    file: 'backend/src/modules/collaboration/api/dto/leave-plan.dto.ts',
    mutate: (source: string) => source.replace('  @IsNotEmpty()\n', ''),
    verify: (root: string, value: R7Manifest) => scanner().scanR7CollaborationRelocation({
      repositoryRoot: root,
      manifest: value,
    }),
    error: /normalized source parity drift/u,
  },
  {
    name: 'InviteAccessService unknown error identity drift',
    file: 'backend/src/modules/collaboration/internal/invite-access.service.ts',
    mutate: (source: string) => source.replace('      throw error;', '      throw new Error("changed");'),
    verify: (root: string, value: R7Manifest) => scanner().scanR7CollaborationRelocation({
      repositoryRoot: root,
      manifest: value,
    }),
    error: /normalized source parity drift/u,
  },
]) {
  test(`R7 Sharing gate rejects ${fixtureCase.name}`, () => {
    const fixture = stagedFixture('relocated');
    try {
      mutateFixtureFile(fixture.root, fixtureCase.file, fixtureCase.mutate);
      assert.throws(
        () => fixtureCase.verify(fixture.root, fixture.value),
        fixtureCase.error,
      );
    } finally {
      rmSync(fixture.root, { recursive: true, force: true });
    }
  });
}

test('R7 history gate rejects controller, provider, and ownership semantic drift', () => {
  const controllerCases = [
    {
      name: 'controller route',
      mutate: (source: string) => source.replace('@Get("summary")', '@Get("changed")'),
    },
    {
      name: 'CurrentUser decorator',
      mutate: (source: string) => source.replace('@CurrentUser()', '@Param("currentUser")'),
    },
    {
      name: 'query parameter',
      mutate: (source: string) => source.replace(
        '@Query("contributorUserId")',
        '@Query("changedContributorUserId")',
      ),
    },
  ];
  for (const fixtureCase of controllerCases) {
    const fixture = stagedFixture('history');
    try {
      mutateFixtureFile(
        fixture.root,
        'backend/src/modules/collaboration/api/contribution-history.controller.ts',
        fixtureCase.mutate,
      );
      assert.throws(
        () => scanner().verifyControllerHandoffs(fixture.root, fixture.value),
        /controller inventory drift/u,
        fixtureCase.name,
      );
    } finally {
      rmSync(fixture.root, { recursive: true, force: true });
    }
  }

  const provider = stagedFixture('history');
  try {
    mutateFixtureFile(
      provider.root,
      'backend/src/modules/collaboration/internal/contribution-history.service.ts',
      (source) => source.replace(
        'export class ContributionHistoryService',
        'export class ChangedContributionHistoryService',
      ),
    );
    assert.throws(
      () => scanner().verifyHistoryRelocation(provider.root, provider.value),
      /history provider identity drift/u,
    );
  } finally {
    rmSync(provider.root, { recursive: true, force: true });
  }

  const ownership = stagedFixture('history');
  try {
    const ownershipPath = path.join(
      ownership.root,
      'backend',
      'architecture',
      'ownership-baseline.json',
    );
    const baseline = JSON.parse(readFileSync(ownershipPath, 'utf8')) as {
      violations: Array<Record<string, unknown>>;
    };
    const record = baseline.violations.find((entry) => (
      entry.file === 'backend/src/modules/collaboration/internal/contribution-history.service.ts'
    ));
    assert.ok(record);
    record.reason = 'changed-semantic-reason';
    writeJson(ownershipPath, baseline);
    assert.throws(
      () => scanner().scanR7CollaborationRelocation({
        repositoryRoot: ownership.root,
        manifest: ownership.value,
      }),
      /ownership semantic drift/u,
    );
  } finally {
    rmSync(ownership.root, { recursive: true, force: true });
  }
});

for (const fixtureCase of [
  {
    name: 'untouched-record substitution',
    mutate: (violations: Array<Record<string, any>>, untouched: number[]) => {
      violations[untouched[0]].reason = 'same-count-unrelated-substitution';
    },
  },
  {
    name: 'canonical order drift',
    mutate: (violations: Array<Record<string, any>>, untouched: number[]) => {
      [violations[untouched[0]], violations[untouched[1]]] = [
        violations[untouched[1]],
        violations[untouched[0]],
      ];
    },
  },
  {
    name: 'untouched key drift',
    mutate: (violations: Array<Record<string, any>>, untouched: number[]) => {
      violations[untouched[0]].key = `${violations[untouched[0]].key}-drift`;
    },
  },
]) {
  test(`R7 ownership gate rejects ${fixtureCase.name}`, () => {
    const fixture = mutateOwnershipFixture('history', fixtureCase.mutate);
    try {
      assert.throws(
        () => scanner().scanR7CollaborationRelocation({
          repositoryRoot: fixture.root,
          manifest: fixture.value,
        }),
        /ownership baseline identity drift/u,
      );
    } finally {
      rmSync(fixture.root, { recursive: true, force: true });
    }
  });
}

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

test('R7 staged fixtures reconstruct legacy snapshot imports only at design', () => {
  for (const stage of Object.keys(expectedStageCounts) as Array<keyof typeof expectedStageCounts>) {
    const fixture = stagedFixture(stage);
    try {
      const budgetSource = readFileSync(path.join(
        fixture.root,
        'backend',
        'src',
        'budget-categories',
        'budget-categories.service.ts',
      ), 'utf8');
      const expectedSpecifier = stage === 'design'
        ? '../contribution-history/contribution-snapshot.builder'
        : '../modules/collaboration/public/contribution-snapshot.builder';
      assert.match(budgetSource, new RegExp(expectedSpecifier.replace(/[./]/gu, '\\$&'), 'u'));
      assert.doesNotMatch(
        budgetSource,
        new RegExp((stage === 'design'
          ? '../modules/collaboration/public/contribution-snapshot.builder'
          : '../contribution-history/contribution-snapshot.builder').replace(/[./]/gu, '\\$&'), 'u'),
      );
      assert.doesNotThrow(() => scanner().verifyPublicSnapshotConsumers(fixture.root));
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

test('R7 rejects a same-count substitution in every staged dependency baseline', () => {
  for (const stage of ['design', 'snapshot', 'history', 'relocated', 'strict'] as const) {
    const fixture = stagedFixture(stage);
    try {
      const dependencyPath = path.join(
        fixture.root,
        'backend',
        '.dependency-cruiser-known-violations.json',
      );
      const dependency = JSON.parse(readFileSync(dependencyPath, 'utf8')) as Array<{
        from: string;
      }>;
      dependency[0].from = 'src/attacker/replacement.ts';
      writeJson(dependencyPath, dependency);
      assert.throws(() => scanner().scanR7CollaborationRelocation({
        repositoryRoot: fixture.root,
        manifest: fixture.value,
      }), /dependency.*identity|dependency.*drift/i, stage);
    } finally {
      rmSync(fixture.root, { recursive: true, force: true });
    }
  }
});

test('R7 rejects TypeScript import-equals access to Collaboration internals', () => {
  const fixture = stagedFixture('design');
  try {
    const attacker = path.join(fixture.root, 'backend', 'src', 'tasks', 'attacker.ts');
    mkdirSync(path.dirname(attacker), { recursive: true });
    writeFileSync(
      attacker,
      'import attacker = require("../modules/collaboration/internal/attacker");\nvoid attacker;\n',
      'utf8',
    );
    assert.throws(() => scanner().scanR7CollaborationRelocation({
      repositoryRoot: fixture.root,
      manifest: fixture.value,
    }), /internal|cross-context|boundary/i);
  } finally {
    rmSync(fixture.root, { recursive: true, force: true });
  }
});

test('R7 permits type-only TypeScript import-equals access without opening runtime access', () => {
  const fixture = stagedFixture('design');
  try {
    const consumer = path.join(fixture.root, 'backend', 'src', 'tasks', 'type-consumer.ts');
    mkdirSync(path.dirname(consumer), { recursive: true });
    writeFileSync(
      consumer,
      'import type contract = require("../modules/collaboration/internal/contract");\ntype Contract = contract.Value;\n',
      'utf8',
    );
    assert.deepEqual(scanner().scanR7CollaborationRelocation({
      repositoryRoot: fixture.root,
      manifest: fixture.value,
    }), {
      ok: true,
      stage: 'design',
      sourceFiles: 18,
      targetFiles: 0,
      dependencyRecords: 31,
      ownershipRecords: 385,
      ownershipOccurrences: 781,
    });
  } finally {
    rmSync(fixture.root, { recursive: true, force: true });
  }
});

test('R7 permits element-level type-only named re-exports from Collaboration internals', () => {
  const fixture = stagedFixture('strict');
  try {
    writeFixtureFile(
      fixture.root,
      'backend/src/tasks/collaboration-contract-facade.ts',
      'export { type ContributionHistoryItemResponse } from "../modules/collaboration/internal/contribution-history.contracts";\n',
    );
    assert.deepEqual(scanner().scanR7CollaborationRelocation({
      repositoryRoot: fixture.root,
      manifest: fixture.value,
    }), {
      ok: true,
      stage: 'strict',
      sourceFiles: 0,
      targetFiles: 18,
      dependencyRecords: 22,
      ownershipRecords: 385,
      ownershipOccurrences: 781,
    });
  } finally {
    rmSync(fixture.root, { recursive: true, force: true });
  }
});

test('R7 rejects mixed type-only and runtime named re-exports from Collaboration internals', () => {
  const fixture = stagedFixture('strict');
  try {
    writeFixtureFile(
      fixture.root,
      'backend/src/tasks/collaboration-mixed-facade.ts',
      'export { type SharedMemberResponse, SharingService } from "../modules/collaboration/internal/sharing.service";\n',
    );
    assert.throws(
      () => scanner().scanR7CollaborationRelocation({
        repositoryRoot: fixture.root,
        manifest: fixture.value,
      }),
      /R7 cross-context runtime import enters Collaboration internal or api/u,
    );
  } finally {
    rmSync(fixture.root, { recursive: true, force: true });
  }
});

for (const fixtureCase of [
  {
    name: 'export import alias',
    files: {
      'backend/src/tasks/export-import-duplicate.ts': [
        'namespace LocalSnapshot { export const implementation = () => undefined; }',
        'export import buildContributionSnapshot = LocalSnapshot.implementation;',
        '',
      ].join('\n'),
    },
  },
  {
    name: 'exported namespace',
    files: {
      'backend/src/tasks/namespace-duplicate.ts': [
        'export namespace buildContributionSnapshot {',
        '  export const implementation = () => undefined;',
        '}',
        '',
      ].join('\n'),
    },
  },
  {
    name: 'namespace re-export',
    files: {
      'backend/src/tasks/snapshot-helper.ts': 'export const helper = true;\n',
      'backend/src/tasks/namespace-reexport-duplicate.ts': [
        "export * as buildContributionSnapshot from './snapshot-helper';",
        '',
      ].join('\n'),
    },
  },
  {
    name: 'destructured runtime export',
    files: {
      'backend/src/tasks/destructured-duplicate.ts': [
        'export const { buildContributionSnapshot } = {',
        '  buildContributionSnapshot: () => undefined,',
        '};',
        '',
      ].join('\n'),
    },
  },
  {
    name: 'exports property assignment',
    files: {
      'backend/src/tasks/exports-property-duplicate.ts': [
        'exports.buildContributionSnapshot = () => undefined;',
        '',
      ].join('\n'),
    },
  },
  {
    name: 'computed exports property assignment',
    files: {
      'backend/src/tasks/computed-exports-duplicate.ts': [
        'exports["buildContributionSnapshot"] = () => undefined;',
        '',
      ].join('\n'),
    },
  },
  {
    name: 'module.exports property assignment',
    files: {
      'backend/src/tasks/module-exports-property-duplicate.ts': [
        'module.exports.buildContributionSnapshot = () => undefined;',
        '',
      ].join('\n'),
    },
  },
  {
    name: 'module.exports object assignment',
    files: {
      'backend/src/tasks/module-exports-object-duplicate.ts': [
        'const implementation = () => undefined;',
        'module.exports = { buildContributionSnapshot: implementation };',
        '',
      ].join('\n'),
    },
  },
]) {
  test(`R7 runtime export inventory rejects duplicate ${fixtureCase.name}`, () => {
    const fixture = stagedFixture('strict');
    try {
      for (const [relativePath, source] of Object.entries(fixtureCase.files)) {
        writeFixtureFile(fixture.root, relativePath, source);
      }
      assert.throws(
        () => scanner().scanR7CollaborationRelocation({
          repositoryRoot: fixture.root,
          manifest: fixture.value,
        }),
        /R7 strict stage contains a duplicate public snapshot export/u,
      );
    } finally {
      rmSync(fixture.root, { recursive: true, force: true });
    }
  });
}

test('R7 runtime export inventory ignores a type-only public-name homonym', () => {
  const fixture = stagedFixture('strict');
  try {
    writeFixtureFile(
      fixture.root,
      'backend/src/tasks/type-only-export-control.ts',
      'export type buildContributionSnapshot = { readonly typeOnly: true };\n',
    );
    assert.deepEqual(scanner().scanR7CollaborationRelocation({
      repositoryRoot: fixture.root,
      manifest: fixture.value,
    }), {
      ok: true,
      stage: 'strict',
      sourceFiles: 0,
      targetFiles: 18,
      dependencyRecords: 22,
      ownershipRecords: 385,
      ownershipOccurrences: 781,
    });
  } finally {
    rmSync(fixture.root, { recursive: true, force: true });
  }
});

for (const fixtureCase of [
  {
    name: 'ambient const',
    source: 'export declare const buildContributionSnapshot: unknown;\n',
  },
  {
    name: 'ambient function',
    source: 'export declare function buildContributionSnapshot(): unknown;\n',
  },
  {
    name: 'ambient class',
    source: 'export declare class buildContributionSnapshot {}\n',
  },
  {
    name: 'ambient namespace',
    source: [
      'export declare namespace buildContributionSnapshot {',
      '  const contract: true;',
      '}',
      '',
    ].join('\n'),
  },
]) {
  test(`R7 runtime export inventory permits non-emitting ${fixtureCase.name}`, () => {
    const fixture = stagedFixture('strict');
    try {
      writeFixtureFile(
        fixture.root,
        'backend/src/tasks/ambient-export-control.ts',
        fixtureCase.source,
      );
      assert.deepEqual(scanner().scanR7CollaborationRelocation({
        repositoryRoot: fixture.root,
        manifest: fixture.value,
      }), {
        ok: true,
        stage: 'strict',
        sourceFiles: 0,
        targetFiles: 18,
        dependencyRecords: 22,
        ownershipRecords: 385,
        ownershipOccurrences: 781,
      });
    } finally {
      rmSync(fixture.root, { recursive: true, force: true });
    }
  });
}

test('R7 runtime export inventory ignores local CommonJS export homonyms', () => {
  const fixture = stagedFixture('strict');
  try {
    writeFixtureFile(
      fixture.root,
      'backend/src/tasks/local-commonjs-export-controls.ts',
      [
        'const exports = { buildContributionSnapshot: () => undefined };',
        'const module = { exports: { buildContributionSnapshot: () => undefined } };',
        'exports.buildContributionSnapshot = () => undefined;',
        'module.exports.buildContributionSnapshot = () => undefined;',
        'void exports;',
        'void module;',
        '',
      ].join('\n'),
    );
    assert.deepEqual(scanner().scanR7CollaborationRelocation({
      repositoryRoot: fixture.root,
      manifest: fixture.value,
    }), {
      ok: true,
      stage: 'strict',
      sourceFiles: 0,
      targetFiles: 18,
      dependencyRecords: 22,
      ownershipRecords: 385,
      ownershipOccurrences: 781,
    });
  } finally {
    rmSync(fixture.root, { recursive: true, force: true });
  }
});

test('R7 runtime export inventory is not masked by CommonJS homonyms in another file', () => {
  const fixture = stagedFixture('strict');
  try {
    writeFixtureFile(
      fixture.root,
      'backend/src/tasks/foreign-commonjs-export-homonyms.ts',
      [
        'const exports = { local: true };',
        'const module = { exports: { local: true } };',
        'void exports;',
        'void module;',
        '',
      ].join('\n'),
    );
    writeFixtureFile(
      fixture.root,
      'backend/src/tasks/commonjs-export-duplicate.ts',
      'exports.buildContributionSnapshot = () => undefined;\n',
    );
    assert.throws(
      () => scanner().scanR7CollaborationRelocation({
        repositoryRoot: fixture.root,
        manifest: fixture.value,
      }),
      /R7 strict stage contains a duplicate public snapshot export/u,
    );
  } finally {
    rmSync(fixture.root, { recursive: true, force: true });
  }
});

for (const fixtureCase of [
  {
    name: 'const module.exports alias',
    source: [
      'const api = module.exports;',
      'api.buildContributionSnapshot = () => undefined;',
      '',
    ].join('\n'),
  },
  {
    name: 'let exports alias',
    source: [
      'let api = exports;',
      'api.buildContributionSnapshot = () => undefined;',
      '',
    ].join('\n'),
  },
  {
    name: 'var module.exports alias',
    source: [
      'var api = module.exports;',
      'api.buildContributionSnapshot = () => undefined;',
      '',
    ].join('\n'),
  },
  {
    name: 'object-property module.exports alias',
    source: [
      'const holder = { api: module.exports };',
      'holder.api.buildContributionSnapshot = () => undefined;',
      '',
    ].join('\n'),
  },
  {
    name: 'destructured module.exports alias',
    source: [
      'const holder = { api: module.exports };',
      'const { api } = holder;',
      'api.buildContributionSnapshot = () => undefined;',
      '',
    ].join('\n'),
  },
  {
    name: 'later module.exports assignment',
    source: [
      'let api = { local: true };',
      'api = module.exports;',
      'api.buildContributionSnapshot = () => undefined;',
      '',
    ].join('\n'),
  },
]) {
  test(`R7 semantic CommonJS exports reject ${fixtureCase.name}`, () => {
    const fixture = stagedFixture('strict');
    try {
      writeFixtureFile(
        fixture.root,
        'backend/src/tasks/semantic-commonjs-export.ts',
        fixtureCase.source,
      );
      assert.throws(
        () => scanner().scanR7CollaborationRelocation({
          repositoryRoot: fixture.root,
          manifest: fixture.value,
        }),
        /R7 strict stage contains a duplicate public snapshot export/u,
      );
    } finally {
      rmSync(fixture.root, { recursive: true, force: true });
    }
  });
}

test('R7 semantic CommonJS exports permit local and reassigned-away aliases', () => {
  const fixture = stagedFixture('strict');
  try {
    writeFixtureFile(
      fixture.root,
      'backend/src/tasks/semantic-commonjs-controls.ts',
      [
        '{',
        '  let api = module.exports;',
        '  api = { local: true };',
        '  api.buildContributionSnapshot = () => undefined;',
        '  const holder = { api: module.exports };',
        '  holder.api = { local: true };',
        '  holder.api.buildContributionSnapshot = () => undefined;',
        '}',
        '{',
        '  const module = { exports: { local: true } };',
        '  const api = module.exports;',
        '  api.buildContributionSnapshot = () => undefined;',
        '}',
        '{',
        '  const exports = { local: true };',
        '  const api = exports;',
        '  api.buildContributionSnapshot = () => undefined;',
        '}',
        '',
      ].join('\n'),
    );
    assert.deepEqual(scanner().scanR7CollaborationRelocation({
      repositoryRoot: fixture.root,
      manifest: fixture.value,
    }), {
      ok: true,
      stage: 'strict',
      sourceFiles: 0,
      targetFiles: 18,
      dependencyRecords: 22,
      ownershipRecords: 385,
      ownershipOccurrences: 781,
    });
  } finally {
    rmSync(fixture.root, { recursive: true, force: true });
  }
});

test('R7 semantic CommonJS exports are not masked by another-file module homonyms', () => {
  const fixture = stagedFixture('strict');
  try {
    writeFixtureFile(
      fixture.root,
      'backend/src/tasks/foreign-commonjs-module.ts',
      'const module = { exports: { local: true } };\nvoid module;\n',
    );
    writeFixtureFile(
      fixture.root,
      'backend/src/tasks/semantic-cross-file-commonjs-export.ts',
      [
        'const api = module.exports;',
        'api.buildContributionSnapshot = () => undefined;',
        '',
      ].join('\n'),
    );
    assert.throws(
      () => scanner().scanR7CollaborationRelocation({
        repositoryRoot: fixture.root,
        manifest: fixture.value,
      }),
      /R7 strict stage contains a duplicate public snapshot export/u,
    );
  } finally {
    rmSync(fixture.root, { recursive: true, force: true });
  }
});

const finiteCandidateCommonJsExportCases = [
  {
    name: 'array binding',
    expression: 'const [api] = [module.exports];',
  },
  {
    name: 'conditional branch',
    expression: [
      'const localApi = { local: true };',
      'const api = Boolean(Date.now()) ? module.exports : localApi;',
    ].join('\n'),
  },
  {
    name: 'logical or branch',
    expression: [
      'const localApi = { local: true };',
      'const api = localApi || module.exports;',
    ].join('\n'),
  },
  {
    name: 'nullish branch',
    expression: [
      'const localApi: Record<string, unknown> | null = { local: true };',
      'const api = localApi ?? module.exports;',
    ].join('\n'),
  },
  {
    name: 'logical and branch',
    expression: 'const api = Boolean(Date.now()) && module.exports;',
  },
];

test('R7 semantic CommonJS inspector rejects every dangerous finite candidate and permits local branches', () => {
  const sources = Object.fromEntries(finiteCandidateCommonJsExportCases.map((fixtureCase, index) => [
    `dangerous-commonjs-${index}`,
    `${fixtureCase.expression}\napi.buildContributionSnapshot = () => undefined;\n`,
  ]));
  sources.local = [
    'const localApi = { local: true };',
    'const otherApi = { local: false };',
    'const [arrayApi] = [localApi];',
    'const conditionalApi = Boolean(Date.now()) ? arrayApi : otherApi;',
    'const orApi = conditionalApi || otherApi;',
    'const nullishApi = orApi ?? localApi;',
    'const api = Boolean(Date.now()) && nullishApi;',
    'api.buildContributionSnapshot = () => undefined;',
    '',
  ].join('\n');
  const inspections = inspectSemanticFixtureSources(sources);
  finiteCandidateCommonJsExportCases.forEach((fixtureCase, index) => {
    assert.deepEqual(
      inspections[`dangerous-commonjs-${index}`].commonJsExports,
      ['buildContributionSnapshot'],
      fixtureCase.name,
    );
  });
  assert.deepEqual(inspections.local.commonJsExports, []);
});

test('R7 finite candidate CommonJS array binding reaches the duplicate-export gate', () => {
  const fixture = stagedFixture('strict');
  try {
    writeFixtureFile(
      fixture.root,
      'backend/src/tasks/finite-commonjs-export.ts',
      `${finiteCandidateCommonJsExportCases[0].expression}\napi.buildContributionSnapshot = () => undefined;\n`,
    );
    assert.throws(
      () => scanner().scanR7CollaborationRelocation({
        repositoryRoot: fixture.root,
        manifest: fixture.value,
      }),
      /R7 strict stage contains a duplicate public snapshot export/u,
    );
  } finally {
    rmSync(fixture.root, { recursive: true, force: true });
  }
});

test('R7 runtime export inventory rejects a CommonJS extra on the canonical builder', () => {
  const fixture = stagedFixture('strict');
  try {
    mutateFixtureFile(
      fixture.root,
      'backend/src/modules/collaboration/public/contribution-snapshot.builder.ts',
      (source) => `${source}\nexports.extraRuntime = true;\n`,
    );
    assert.throws(
      () => scanner().verifyPublicSnapshotSource(fixture.root, fixture.value),
      /R7 public snapshot exports drift detected/u,
    );
  } finally {
    rmSync(fixture.root, { recursive: true, force: true });
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
  assert.deepEqual(scanner().verifyPublicSnapshotConsumers(repositoryRoot), {
    callers: 11,
    testImports: 2,
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

for (const form of [
  {
    name: 'static import',
    source: 'import { buildContributionSnapshot } from "../modules/collaboration/public/contribution-snapshot.builder.js";\nvoid buildContributionSnapshot;\n',
  },
  {
    name: 'named re-export',
    source: 'export { buildContributionSnapshot } from "../modules/collaboration/public/contribution-snapshot.builder.js";\n',
  },
  {
    name: 'star re-export',
    source: 'export * from "../modules/collaboration/public/contribution-snapshot.builder.js";\n',
  },
  {
    name: 'dynamic import',
    source: 'void import("../modules/collaboration/public/contribution-snapshot.builder.js");\n',
  },
  {
    name: 'require call',
    source: 'void require("../modules/collaboration/public/contribution-snapshot.builder.js");\n',
  },
  {
    name: 'import equals',
    source: 'import builder = require("../modules/collaboration/public/contribution-snapshot.builder.js");\nvoid builder;\n',
  },
]) {
  test(`R7 rejects .js public builder ${form.name} by canonical source identity`, () => {
    const fixture = stagedFixture('strict');
    try {
      writeFixtureFile(
        fixture.root,
        'backend/src/tasks/js-builder-facade.ts',
        form.source,
      );
      assert.throws(
        () => scanner().verifyPublicSnapshotConsumers(fixture.root),
        /R7 public snapshot.*(?:consumer|reference|facade|form)/iu,
      );
    } finally {
      rmSync(fixture.root, { recursive: true, force: true });
    }
  });
}

for (const form of [
  {
    name: 'static import',
    source: 'import { SharingService } from "../modules/collaboration/internal/sharing.service.js";\nvoid SharingService;\n',
  },
  {
    name: 'named re-export',
    source: 'export { SharingService } from "../modules/collaboration/internal/sharing.service.js";\n',
  },
  {
    name: 'star re-export',
    source: 'export * from "../modules/collaboration/internal/sharing.service.js";\n',
  },
  {
    name: 'dynamic import',
    source: 'void import("../modules/collaboration/internal/sharing.service.js");\n',
  },
  {
    name: 'require call',
    source: 'void require("../modules/collaboration/internal/sharing.service.js");\n',
  },
  {
    name: 'import equals',
    source: 'import sharing = require("../modules/collaboration/internal/sharing.service.js");\nvoid sharing;\n',
  },
]) {
  test(`R7 rejects .js protected Collaboration ${form.name} by canonical source identity`, () => {
    const fixture = stagedFixture('strict');
    try {
      writeFixtureFile(
        fixture.root,
        'backend/src/tasks/js-protected-bypass.ts',
        form.source,
      );
      assert.throws(
        () => scanner().scanR7CollaborationRelocation({
          repositoryRoot: fixture.root,
          manifest: fixture.value,
        }),
        /R7 cross-context runtime import enters Collaboration internal or api/u,
      );
    } finally {
      rmSync(fixture.root, { recursive: true, force: true });
    }
  });
}

test('R7 preserves a real .js source identity instead of stripping its extension', () => {
  const fixture = stagedFixture('strict');
  try {
    writeFixtureFile(
      fixture.root,
      'backend/src/tasks/contribution-snapshot.builder.js',
      'exports.helper = () => true;\n',
    );
    writeFixtureFile(
      fixture.root,
      'backend/src/tasks/real-js-consumer.ts',
      'import { helper } from "./contribution-snapshot.builder.js";\nvoid helper;\n',
    );
    assert.deepEqual(scanner().verifyPublicSnapshotConsumers(fixture.root), {
      callers: 11,
      testImports: 2,
    });
  } finally {
    rmSync(fixture.root, { recursive: true, force: true });
  }
});

const srcModuleReferenceForms = [
  {
    name: 'static import',
    source(specifier: string, symbol: string): string {
      return `import { ${symbol} } from "${specifier}";\nvoid ${symbol};\n`;
    },
  },
  {
    name: 'named re-export',
    source(specifier: string, symbol: string): string {
      return `export { ${symbol} } from "${specifier}";\n`;
    },
  },
  {
    name: 'star re-export',
    source(specifier: string): string {
      return `export * from "${specifier}";\n`;
    },
  },
  {
    name: 'dynamic import',
    source(specifier: string): string {
      return `void import("${specifier}");\n`;
    },
  },
  {
    name: 'require call',
    source(specifier: string): string {
      return `void require("${specifier}");\n`;
    },
  },
  {
    name: 'import equals',
    source(specifier: string): string {
      return `import target = require("${specifier}");\nvoid target;\n`;
    },
  },
];

for (const suffix of ['', '.js']) {
  for (const form of srcModuleReferenceForms) {
    test(`R7 rejects src/ public builder ${form.name}${suffix || ' extensionless'} by compiler source identity`, () => {
      const fixture = stagedFixture('strict');
      try {
        const specifier = `src/modules/collaboration/public/contribution-snapshot.builder${suffix}`;
        writeFixtureFile(
          fixture.root,
          'backend/src/tasks/src-builder-facade.ts',
          form.source(specifier, 'buildContributionSnapshot'),
        );
        assert.throws(
          () => scanner().verifyPublicSnapshotConsumers(fixture.root),
          /R7 public snapshot.*(?:consumer|reference|facade|form)/iu,
        );
      } finally {
        rmSync(fixture.root, { recursive: true, force: true });
      }
    });
  }
}

for (const target of [
  {
    name: 'internal',
    path: 'src/modules/collaboration/internal/sharing.service',
    symbol: 'SharingService',
  },
  {
    name: 'api',
    path: 'src/modules/collaboration/api/sharing.controller',
    symbol: 'ApiV1InviteAccessController',
  },
]) {
  for (const suffix of ['', '.js']) {
    for (const form of srcModuleReferenceForms) {
      test(`R7 rejects src/ protected ${target.name} ${form.name}${suffix || ' extensionless'} by compiler source identity`, () => {
        const fixture = stagedFixture('strict');
        try {
          writeFixtureFile(
            fixture.root,
            'backend/src/tasks/src-protected-bypass.ts',
            form.source(`${target.path}${suffix}`, target.symbol),
          );
          assert.throws(
            () => scanner().scanR7CollaborationRelocation({
              repositoryRoot: fixture.root,
              manifest: fixture.value,
            }),
            /R7 cross-context runtime import enters Collaboration internal or api/u,
          );
        } finally {
          rmSync(fixture.root, { recursive: true, force: true });
        }
      });
    }
  }
}

test('R7 preserves real nonmatching src/ .js and near-name source identities', () => {
  const fixture = stagedFixture('strict');
  try {
    writeFixtureFile(
      fixture.root,
      'backend/src/tasks/src-contribution-snapshot.builder.js',
      'exports.helper = () => true;\n',
    );
    writeFixtureFile(
      fixture.root,
      'backend/src/tasks/contribution-snapshot.builder-near.ts',
      'export const near = true;\n',
    );
    writeFixtureFile(
      fixture.root,
      'backend/src/tasks/src-builder-controls.ts',
      [
        'import { helper } from "src/tasks/src-contribution-snapshot.builder.js";',
        'import { near } from "src/tasks/contribution-snapshot.builder-near";',
        'void helper;',
        'void near;',
        '',
      ].join('\n'),
    );
    assert.deepEqual(scanner().verifyPublicSnapshotConsumers(fixture.root), {
      callers: 11,
      testImports: 2,
    });
  } finally {
    rmSync(fixture.root, { recursive: true, force: true });
  }
});

const moduleLoaderForms = [
  {
    name: 'const require alias',
    source(specifier: string): string {
      return `const load = require;\nvoid load("${specifier}");\n`;
    },
  },
  {
    name: 'chained const require alias',
    source(specifier: string): string {
      return `const load = require;\nconst indirectLoad = load;\nvoid indirectLoad("${specifier}");\n`;
    },
  },
  {
    name: 'direct module.require',
    source(specifier: string): string {
      return `void module.require("${specifier}");\n`;
    },
  },
  {
    name: 'const module.require alias',
    source(specifier: string): string {
      return `const load = module.require;\nvoid load("${specifier}");\n`;
    },
  },
];

for (const form of moduleLoaderForms) {
  test(`R7 module loader rejects ${form.name} to a legacy Collaboration root`, () => {
    const fixture = stagedFixture('strict');
    try {
      writeFixtureFile(
        fixture.root,
        'backend/src/tasks/legacy-loader-bypass.ts',
        form.source('../sharing/sharing.service'),
      );
      assert.throws(
        () => scanner().scanR7CollaborationRelocation({
          repositoryRoot: fixture.root,
          manifest: fixture.value,
        }),
        /R7 strict stage retains a legacy import literal/u,
      );
    } finally {
      rmSync(fixture.root, { recursive: true, force: true });
    }
  });

  test(`R7 module loader rejects ${form.name} to protected Collaboration internals`, () => {
    const fixture = stagedFixture('strict');
    try {
      writeFixtureFile(
        fixture.root,
        'backend/src/tasks/internal-loader-bypass.ts',
        form.source('../modules/collaboration/internal/sharing.service'),
      );
      assert.throws(
        () => scanner().scanR7CollaborationRelocation({
          repositoryRoot: fixture.root,
          manifest: fixture.value,
        }),
        /R7 cross-context runtime import enters Collaboration internal or api/u,
      );
    } finally {
      rmSync(fixture.root, { recursive: true, force: true });
    }
  });

  test(`R7 module loader rejects ${form.name} to the public snapshot builder`, () => {
    const fixture = stagedFixture('strict');
    try {
      writeFixtureFile(
        fixture.root,
        'backend/src/tasks/builder-loader-bypass.ts',
        form.source('../modules/collaboration/public/contribution-snapshot.builder'),
      );
      assert.throws(
        () => scanner().verifyPublicSnapshotConsumers(fixture.root),
        /R7 public snapshot non-canonical consumer form detected/u,
      );
    } finally {
      rmSync(fixture.root, { recursive: true, force: true });
    }
  });
}

test('R7 module loader permits shadowed require and local module.require homonyms', () => {
  const fixture = stagedFixture('strict');
  try {
    writeFixtureFile(
      fixture.root,
      'backend/src/tasks/local-loader-controls.ts',
      [
        'const require = (_specifier: string) => undefined;',
        'const module = { require: (_specifier: string) => undefined };',
        'void require("../modules/collaboration/public/contribution-snapshot.builder");',
        'void module.require("../modules/collaboration/internal/sharing.service");',
        '',
      ].join('\n'),
    );
    assert.deepEqual(scanner().scanR7CollaborationRelocation({
      repositoryRoot: fixture.root,
      manifest: fixture.value,
    }), {
      ok: true,
      stage: 'strict',
      sourceFiles: 0,
      targetFiles: 18,
      dependencyRecords: 22,
      ownershipRecords: 385,
      ownershipOccurrences: 781,
    });
  } finally {
    rmSync(fixture.root, { recursive: true, force: true });
  }
});

test('R7 module loader is not masked by require homonyms in another CommonJS file', () => {
  const fixture = stagedFixture('strict');
  try {
    writeFixtureFile(
      fixture.root,
      'backend/src/tasks/foreign-loader-homonyms.ts',
      [
        'const require = (_specifier: string) => undefined;',
        'const module = { require: (_specifier: string) => undefined };',
        'void require;',
        'void module;',
        '',
      ].join('\n'),
    );
    writeFixtureFile(
      fixture.root,
      'backend/src/tasks/cross-file-loader-bypass.ts',
      [
        'const load = require;',
        'void load("../sharing/sharing.service");',
        '',
      ].join('\n'),
    );
    assert.throws(
      () => scanner().scanR7CollaborationRelocation({
        repositoryRoot: fixture.root,
        manifest: fixture.value,
      }),
      /R7 strict stage retains a legacy import literal/u,
    );
  } finally {
    rmSync(fixture.root, { recursive: true, force: true });
  }
});

const semanticModuleLoaderForms = [
  {
    name: 'let initializer',
    source(specifier: string): string {
      return `let load = require;\nvoid load("${specifier}");\n`;
    },
  },
  {
    name: 'var module.require initializer',
    source(specifier: string): string {
      return `var load = module.require;\nvoid load("${specifier}");\n`;
    },
  },
  {
    name: 'object property',
    source(specifier: string): string {
      return `const holder = { load: require };\nvoid holder.load("${specifier}");\n`;
    },
  },
  {
    name: 'destructured object property',
    source(specifier: string): string {
      return [
        'const holder = { load: module.require };',
        'const { load } = holder;',
        `void load("${specifier}");`,
        '',
      ].join('\n');
    },
  },
  {
    name: 'later assignment',
    source(specifier: string): string {
      return [
        'const ordinaryLoad = (_specifier: string) => undefined;',
        'let load = ordinaryLoad;',
        'load = require;',
        `void load("${specifier}");`,
        '',
      ].join('\n');
    },
  },
];

for (const form of semanticModuleLoaderForms) {
  test(`R7 semantic module loader rejects ${form.name} to a legacy root`, () => {
    const fixture = stagedFixture('strict');
    try {
      writeFixtureFile(
        fixture.root,
        'backend/src/tasks/semantic-legacy-loader.ts',
        form.source('../sharing/sharing.service'),
      );
      assert.throws(
        () => scanner().scanR7CollaborationRelocation({
          repositoryRoot: fixture.root,
          manifest: fixture.value,
        }),
        /R7 strict stage retains a legacy import literal/u,
      );
    } finally {
      rmSync(fixture.root, { recursive: true, force: true });
    }
  });

  test(`R7 semantic module loader rejects ${form.name} to protected internals`, () => {
    const fixture = stagedFixture('strict');
    try {
      writeFixtureFile(
        fixture.root,
        'backend/src/tasks/semantic-protected-loader.ts',
        form.source('../modules/collaboration/internal/sharing.service'),
      );
      assert.throws(
        () => scanner().scanR7CollaborationRelocation({
          repositoryRoot: fixture.root,
          manifest: fixture.value,
        }),
        /R7 cross-context runtime import enters Collaboration internal or api/u,
      );
    } finally {
      rmSync(fixture.root, { recursive: true, force: true });
    }
  });

  test(`R7 semantic module loader rejects ${form.name} to the public builder`, () => {
    const fixture = stagedFixture('strict');
    try {
      writeFixtureFile(
        fixture.root,
        'backend/src/tasks/semantic-builder-loader.ts',
        form.source('../modules/collaboration/public/contribution-snapshot.builder'),
      );
      assert.throws(
        () => scanner().verifyPublicSnapshotConsumers(fixture.root),
        /R7 public snapshot non-canonical consumer form detected/u,
      );
    } finally {
      rmSync(fixture.root, { recursive: true, force: true });
    }
  });
}

test('R7 semantic module loader permits shadowed and reassigned-away values', () => {
  const fixture = stagedFixture('strict');
  try {
    writeFixtureFile(
      fixture.root,
      'backend/src/tasks/semantic-loader-controls.ts',
      [
        'const ordinaryLoad = (_specifier: string) => undefined;',
        '{',
        '  let load = require;',
        '  load = ordinaryLoad;',
        '  void load("../sharing/sharing.service");',
        '  const holder = { load: module.require };',
        '  holder.load = ordinaryLoad;',
        '  void holder.load("../modules/collaboration/internal/sharing.service");',
        '}',
        '{',
        '  const require = ordinaryLoad;',
        '  const localHolder = { load: require };',
        '  void localHolder.load("../modules/collaboration/public/contribution-snapshot.builder");',
        '}',
        '',
      ].join('\n'),
    );
    assert.deepEqual(scanner().scanR7CollaborationRelocation({
      repositoryRoot: fixture.root,
      manifest: fixture.value,
    }), {
      ok: true,
      stage: 'strict',
      sourceFiles: 0,
      targetFiles: 18,
      dependencyRecords: 22,
      ownershipRecords: 385,
      ownershipOccurrences: 781,
    });
  } finally {
    rmSync(fixture.root, { recursive: true, force: true });
  }
});

const finiteCandidateModuleLoaderForms = [
  {
    name: 'array binding',
    source(specifier: string): string {
      return `const [load] = [require];\nvoid load("${specifier}");\n`;
    },
  },
  {
    name: 'conditional branch',
    source(specifier: string): string {
      return [
        'const ordinaryLoad = (_specifier: string) => undefined;',
        'const load = Boolean(Date.now()) ? require : ordinaryLoad;',
        `void load("${specifier}");`,
        '',
      ].join('\n');
    },
  },
  {
    name: 'logical or branch',
    source(specifier: string): string {
      return [
        'const ordinaryLoad = (_specifier: string) => undefined;',
        'const load = ordinaryLoad || require;',
        `void load("${specifier}");`,
        '',
      ].join('\n');
    },
  },
  {
    name: 'nullish branch',
    source(specifier: string): string {
      return [
        'const ordinaryLoad: ((specifier: string) => unknown) | null = () => undefined;',
        'const load = ordinaryLoad ?? module.require;',
        `void load("${specifier}");`,
        '',
      ].join('\n');
    },
  },
  {
    name: 'logical and branch',
    source(specifier: string): string {
      return [
        'const load = Boolean(Date.now()) && require;',
        `void load("${specifier}");`,
        '',
      ].join('\n');
    },
  },
];

const finiteCandidateModulePaths = [
  '../sharing/sharing.service',
  '../modules/collaboration/internal/sharing.service',
  '../modules/collaboration/public/contribution-snapshot.builder',
];

test('R7 semantic module inspector rejects every dangerous finite candidate and permits local branches', () => {
  const sources: Record<string, string> = {};
  finiteCandidateModuleLoaderForms.forEach((form, formIndex) => {
    finiteCandidateModulePaths.forEach((specifier, pathIndex) => {
      sources[`dangerous-loader-${formIndex}-${pathIndex}`] = form.source(specifier);
    });
  });
  sources.local = [
    'const ordinaryLoad = (_specifier: string) => undefined;',
    'const otherLoad = (_specifier: string) => undefined;',
    'const [arrayLoad] = [ordinaryLoad];',
    'const conditionalLoad = Boolean(Date.now()) ? arrayLoad : otherLoad;',
    'const orLoad = conditionalLoad || otherLoad;',
    'const nullishLoad = orLoad ?? ordinaryLoad;',
    'const load = Boolean(Date.now()) && nullishLoad;',
    ...finiteCandidateModulePaths.map((specifier) => `void load("${specifier}");`),
    '',
  ].join('\n');
  const inspections = inspectSemanticFixtureSources(sources);
  finiteCandidateModuleLoaderForms.forEach((form, formIndex) => {
    finiteCandidateModulePaths.forEach((specifier, pathIndex) => {
      assert.deepEqual(
        inspections[`dangerous-loader-${formIndex}-${pathIndex}`].moduleReferences,
        [specifier],
        `${form.name}: ${specifier}`,
      );
    });
  });
  assert.deepEqual(inspections.local.moduleReferences, []);
});

for (const fixtureCase of [
  {
    name: 'array binding to a legacy root',
    source: finiteCandidateModuleLoaderForms[0].source(finiteCandidateModulePaths[0]),
    error: /R7 strict stage retains a legacy import literal/u,
    verify(root: string, manifest: R7Manifest): unknown {
      return scanner().scanR7CollaborationRelocation({ repositoryRoot: root, manifest });
    },
  },
  {
    name: 'conditional branch to protected internals',
    source: finiteCandidateModuleLoaderForms[1].source(finiteCandidateModulePaths[1]),
    error: /R7 cross-context runtime import enters Collaboration internal or api/u,
    verify(root: string, manifest: R7Manifest): unknown {
      return scanner().scanR7CollaborationRelocation({ repositoryRoot: root, manifest });
    },
  },
  {
    name: 'logical branch to the public builder',
    source: finiteCandidateModuleLoaderForms[2].source(finiteCandidateModulePaths[2]),
    error: /R7 public snapshot non-canonical consumer form detected/u,
    verify(root: string): unknown {
      return scanner().verifyPublicSnapshotConsumers(root);
    },
  },
]) {
  test(`R7 finite candidate module loader reaches its gate for ${fixtureCase.name}`, () => {
    const fixture = stagedFixture('strict');
    try {
      writeFixtureFile(fixture.root, 'backend/src/tasks/finite-loader.ts', fixtureCase.source);
      assert.throws(
        () => fixtureCase.verify(fixture.root, fixture.value),
        fixtureCase.error,
      );
    } finally {
      rmSync(fixture.root, { recursive: true, force: true });
    }
  });
}

const multiArgumentModuleReferenceForms = [
  {
    name: 'dynamic import options',
    source(specifier: string): string {
      return `void import("${specifier}", { with: { type: "json" } });\n`;
    },
  },
  {
    name: 'runtime loader extras',
    source(specifier: string): string {
      return `void require("${specifier}", { ignored: true }, 7);\n`;
    },
  },
];

test('R7 semantic module inspector accepts extra arguments and ignores nonliteral specifiers', () => {
  const sources: Record<string, string> = {};
  multiArgumentModuleReferenceForms.forEach((form, formIndex) => {
    finiteCandidateModulePaths.forEach((specifier, pathIndex) => {
      sources[`literal-${formIndex}-${pathIndex}`] = form.source(specifier);
    });
  });
  sources.nonliteral = [
    'const legacy = "../sharing/sharing.service";',
    'const protectedPath = "../modules/collaboration/internal/sharing.service";',
    'const builder = "../modules/collaboration/public/contribution-snapshot.builder";',
    'void import(legacy, { with: { type: "json" } });',
    'void require(protectedPath, { ignored: true });',
    'void require(builder, { ignored: true });',
    '',
  ].join('\n');
  const inspections = inspectSemanticFixtureSources(sources);
  multiArgumentModuleReferenceForms.forEach((form, formIndex) => {
    finiteCandidateModulePaths.forEach((specifier, pathIndex) => {
      assert.deepEqual(
        inspections[`literal-${formIndex}-${pathIndex}`].moduleReferences,
        [specifier],
        `${form.name}: ${specifier}`,
      );
    });
  });
  assert.deepEqual(inspections.nonliteral.moduleReferences, []);
});

for (const fixtureCase of [
  {
    name: 'dynamic import options to a legacy root',
    source: multiArgumentModuleReferenceForms[0].source(finiteCandidateModulePaths[0]),
    error: /R7 strict stage retains a legacy import literal/u,
  },
  {
    name: 'runtime loader extras to protected internals',
    source: multiArgumentModuleReferenceForms[1].source(finiteCandidateModulePaths[1]),
    error: /R7 cross-context runtime import enters Collaboration internal or api/u,
  },
]) {
  test(`R7 multi-argument module reference reaches its gate for ${fixtureCase.name}`, () => {
    const fixture = stagedFixture('strict');
    try {
      writeFixtureFile(fixture.root, 'backend/src/tasks/multi-argument-reference.ts', fixtureCase.source);
      assert.throws(
        () => scanner().scanR7CollaborationRelocation({
          repositoryRoot: fixture.root,
          manifest: fixture.value,
        }),
        fixtureCase.error,
      );
    } finally {
      rmSync(fixture.root, { recursive: true, force: true });
    }
  });
}

const dangerousReceiverCases = [
  {
    name: 'interface receiver fail-open ordering',
    source: [
      'type Loader = (specifier: string) => unknown;',
      'interface Holder { load: Loader }',
      'const ordinaryLoad: Loader = () => undefined;',
      'const dangerous: Holder = { load: ordinaryLoad };',
      'const safe: Holder = { load: ordinaryLoad };',
      'dangerous.load = require;',
      'safe.load = ordinaryLoad;',
      'void dangerous.load("../sharing/sharing.service");',
      '',
    ].join('\n'),
  },
  {
    name: 'class receiver fail-open ordering',
    source: [
      'type Loader = (specifier: string) => unknown;',
      'const ordinaryLoad: Loader = () => undefined;',
      'class Holder { load: Loader = ordinaryLoad; }',
      'const dangerous = new Holder();',
      'const safe = new Holder();',
      'dangerous.load = require;',
      'safe.load = ordinaryLoad;',
      'void dangerous.load("../sharing/sharing.service");',
      '',
    ].join('\n'),
  },
];

const safeReceiverCases = [
  {
    name: 'interface receiver false-positive ordering',
    source: [
      'type Loader = (specifier: string) => unknown;',
      'interface Holder { load: Loader }',
      'const ordinaryLoad: Loader = () => undefined;',
      'const dangerous: Holder = { load: ordinaryLoad };',
      'const safe: Holder = { load: ordinaryLoad };',
      'safe.load = ordinaryLoad;',
      'dangerous.load = require;',
      'void safe.load("../modules/collaboration/internal/sharing.service");',
      '',
    ].join('\n'),
  },
  {
    name: 'class receiver false-positive ordering',
    source: [
      'type Loader = (specifier: string) => unknown;',
      'const ordinaryLoad: Loader = () => undefined;',
      'class Holder { load: Loader = ordinaryLoad; }',
      'const dangerous = new Holder();',
      'const safe = new Holder();',
      'safe.load = ordinaryLoad;',
      'dangerous.load = require;',
      'void safe.load("../modules/collaboration/public/contribution-snapshot.builder");',
      '',
    ].join('\n'),
  },
];

test('R7 semantic module inspector keeps property writes receiver-sensitive in both orderings', () => {
  const sources = Object.fromEntries([
    ...dangerousReceiverCases.map((fixtureCase, index) => [
      `dangerous-receiver-${index}`,
      fixtureCase.source,
    ]),
    ...safeReceiverCases.map((fixtureCase, index) => [
      `safe-receiver-${index}`,
      fixtureCase.source,
    ]),
  ]);
  const inspections = inspectSemanticFixtureSources(sources);
  dangerousReceiverCases.forEach((fixtureCase, index) => {
    assert.deepEqual(
      inspections[`dangerous-receiver-${index}`].moduleReferences,
      ['../sharing/sharing.service'],
      fixtureCase.name,
    );
  });
  safeReceiverCases.forEach((fixtureCase, index) => {
    assert.deepEqual(
      inspections[`safe-receiver-${index}`].moduleReferences,
      [],
      fixtureCase.name,
    );
  });
});

test('R7 receiver-sensitive dangerous property write reaches the strict legacy gate', () => {
  const fixture = stagedFixture('strict');
  try {
    writeFixtureFile(
      fixture.root,
      'backend/src/tasks/receiver-sensitive-loader.ts',
      dangerousReceiverCases[0].source,
    );
    assert.throws(
      () => scanner().scanR7CollaborationRelocation({
        repositoryRoot: fixture.root,
        manifest: fixture.value,
      }),
      /R7 strict stage retains a legacy import literal/u,
    );
  } finally {
    rmSync(fixture.root, { recursive: true, force: true });
  }
});

test('R7 receiver-sensitive safe property write remains accepted end to end', () => {
  const fixture = stagedFixture('strict');
  try {
    writeFixtureFile(
      fixture.root,
      'backend/src/tasks/receiver-sensitive-control.ts',
      safeReceiverCases[1].source,
    );
    assert.deepEqual(scanner().scanR7CollaborationRelocation({
      repositoryRoot: fixture.root,
      manifest: fixture.value,
    }), {
      ok: true,
      stage: 'strict',
      sourceFiles: 0,
      targetFiles: 18,
      dependencyRecords: 22,
      ownershipRecords: 385,
      ownershipOccurrences: 781,
    });
  } finally {
    rmSync(fixture.root, { recursive: true, force: true });
  }
});

const ambientRuntimeGlobalCases = [
  {
    name: 'ambient require',
    source: [
      'declare const require: (...args: unknown[]) => unknown;',
      'void require("../sharing/sharing.service", { ignored: true });',
      '',
    ].join('\n'),
    error: /R7 strict stage retains a legacy import literal/u,
  },
  {
    name: 'ambient module.require',
    source: [
      'declare const module: { require: (...args: unknown[]) => unknown };',
      'void module.require("../modules/collaboration/internal/sharing.service");',
      '',
    ].join('\n'),
    error: /R7 cross-context runtime import enters Collaboration internal or api/u,
  },
  {
    name: 'ambient module.exports',
    source: [
      'declare const module: { exports: Record<string, unknown> };',
      'module.exports.buildContributionSnapshot = () => undefined;',
      '',
    ].join('\n'),
    error: /R7 strict stage contains a duplicate public snapshot export/u,
  },
  {
    name: 'ambient exports',
    source: [
      'declare const exports: Record<string, unknown>;',
      'exports.buildContributionSnapshot = () => undefined;',
      '',
    ].join('\n'),
    error: /R7 strict stage contains a duplicate public snapshot export/u,
  },
];

const emittedRuntimeGlobalControl = [
  'const ordinaryLoad = (..._args: unknown[]) => undefined;',
  'const require = ordinaryLoad;',
  'const module = { require: ordinaryLoad, exports: {} as Record<string, unknown> };',
  'const exports = {} as Record<string, unknown>;',
  'void require("../sharing/sharing.service", { ignored: true });',
  'void module.require("../modules/collaboration/internal/sharing.service");',
  'module.exports.buildContributionSnapshot = () => undefined;',
  'exports.buildContributionSnapshot = () => undefined;',
  '',
].join('\n');

test('R7 semantic inspector treats ambient runtime declarations as globals and emitted declarations as shadows', () => {
  const sources = Object.fromEntries(ambientRuntimeGlobalCases.map((fixtureCase, index) => [
    `ambient-${index}`,
    fixtureCase.source,
  ]));
  sources.emitted = emittedRuntimeGlobalControl;
  const inspections = inspectSemanticFixtureSources(sources);
  assert.deepEqual(inspections['ambient-0'].moduleReferences, ['../sharing/sharing.service']);
  assert.deepEqual(
    inspections['ambient-1'].moduleReferences,
    ['../modules/collaboration/internal/sharing.service'],
  );
  assert.deepEqual(inspections['ambient-2'].commonJsExports, ['buildContributionSnapshot']);
  assert.deepEqual(inspections['ambient-3'].commonJsExports, ['buildContributionSnapshot']);
  assert.deepEqual(inspections.emitted.moduleReferences, []);
  assert.deepEqual(inspections.emitted.commonJsExports, []);
});

for (const fixtureCase of [ambientRuntimeGlobalCases[0], ambientRuntimeGlobalCases[3]]) {
  test(`R7 ambient runtime global reaches its strict gate for ${fixtureCase.name}`, () => {
    const fixture = stagedFixture('strict');
    try {
      writeFixtureFile(
        fixture.root,
        'backend/src/tasks/ambient-runtime-global.ts',
        fixtureCase.source,
      );
      assert.throws(
        () => scanner().scanR7CollaborationRelocation({
          repositoryRoot: fixture.root,
          manifest: fixture.value,
        }),
        fixtureCase.error,
      );
    } finally {
      rmSync(fixture.root, { recursive: true, force: true });
    }
  });
}

test('R7 emitted local require module and exports declarations remain shadowing controls', () => {
  const fixture = stagedFixture('strict');
  try {
    writeFixtureFile(
      fixture.root,
      'backend/src/tasks/emitted-runtime-global-controls.ts',
      emittedRuntimeGlobalControl,
    );
    assert.deepEqual(scanner().scanR7CollaborationRelocation({
      repositoryRoot: fixture.root,
      manifest: fixture.value,
    }), {
      ok: true,
      stage: 'strict',
      sourceFiles: 0,
      targetFiles: 18,
      dependencyRecords: 22,
      ownershipRecords: 385,
      ownershipOccurrences: 781,
    });
  } finally {
    rmSync(fixture.root, { recursive: true, force: true });
  }
});

test('R7 rejects every non-canonical static, dynamic, runtime, export, and fallback builder reference', () => {
  const forms = [
    {
      name: 'side-effect import',
      source: 'import "../modules/collaboration/public/contribution-snapshot.builder";\n',
    },
    {
      name: 'default import',
      source: 'import builder from "../modules/collaboration/public/contribution-snapshot.builder";\nvoid builder;\n',
    },
    {
      name: 'namespace import',
      source: 'import * as builder from "../modules/collaboration/public/contribution-snapshot.builder";\nvoid builder;\n',
    },
    {
      name: 'type-only import',
      source: 'import type { SnapshotSource } from "../modules/collaboration/public/contribution-snapshot.builder";\nvoid 0;\n',
    },
    {
      name: 'named re-export',
      source: 'export { buildContributionSnapshot } from "../modules/collaboration/public/contribution-snapshot.builder";\n',
    },
    {
      name: 'star re-export',
      source: 'export * from "../modules/collaboration/public/contribution-snapshot.builder";\n',
    },
    {
      name: 'type-only re-export',
      source: 'export type { SnapshotSource } from "../modules/collaboration/public/contribution-snapshot.builder";\n',
    },
    {
      name: 'import equals',
      source: 'import builder = require("../modules/collaboration/public/contribution-snapshot.builder");\nvoid builder;\n',
    },
    {
      name: 'require call',
      source: 'const builder = require("../modules/collaboration/public/contribution-snapshot.builder");\nvoid builder;\n',
    },
    {
      name: 'dynamic import',
      source: 'void import("../modules/collaboration/public/contribution-snapshot.builder");\n',
    },
    {
      name: 'import type expression',
      source: 'type Builder = typeof import("../modules/collaboration/public/contribution-snapshot.builder");\nvoid 0;\n',
    },
    {
      name: 'legacy fallback',
      source: [
        'export function loadBuilder() {',
        '  try { return require("../modules/collaboration/public/contribution-snapshot.builder"); }',
        '  catch { return require("../contribution-history/contribution-snapshot.builder"); }',
        '}',
        '',
      ].join('\n'),
    },
  ];

  for (const form of forms) {
    const fixture = stagedFixture('snapshot');
    try {
      const attacker = path.join(fixture.root, 'backend', 'src', 'tasks', 'snapshot-facade.ts');
      writeFileSync(attacker, form.source, 'utf8');
      assert.throws(
        () => scanner().verifyPublicSnapshotConsumers(fixture.root),
        /public snapshot.*(?:consumer|reference|facade|form)/iu,
        form.name,
      );
    } finally {
      rmSync(fixture.root, { recursive: true, force: true });
    }
  }
});

test('R7 public snapshot gate ignores near-name modules and inert string literals', () => {
  const fixture = stagedFixture('snapshot');
  try {
    writeFileSync(
      path.join(fixture.root, 'backend', 'src', 'tasks', 'unrelated-builder.ts'),
      [
        'import { helper } from "../modules/collaboration/public/contribution-snapshot.builder-helper";',
        'export const inert = "../modules/collaboration/public/contribution-snapshot.builder";',
        'void helper;',
        '',
      ].join('\n'),
      'utf8',
    );
    assert.deepEqual(scanner().verifyPublicSnapshotConsumers(fixture.root), {
      callers: 11,
      testImports: 2,
    });
  } finally {
    rmSync(fixture.root, { recursive: true, force: true });
  }
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
    stage: 'strict',
    sourceFiles: 0,
    targetFiles: 18,
    dependencyRecords: 22,
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
