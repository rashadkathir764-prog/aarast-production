import 'reflect-metadata';

import assert from 'node:assert/strict';
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { afterEach, test } from 'node:test';
import { MODULE_METADATA } from '@nestjs/common/constants';
import { NestFactory } from '@nestjs/core';

const backendRoot = path.resolve(__dirname, '..');
const repositoryRoot = path.resolve(backendRoot, '..');
const manifestPath = path.join(
  backendRoot,
  'architecture',
  'r4-planning-finance-boundary.json',
);
const r4Base = '502b181a2ce624458fd7eae064f194497ec0151e';
const ownershipDebtKey = 'backend/src/money/money-budget.service.ts|finance|planning|WeddingPlan|update|write|delegate|foreign-model';
const expectedAllowedPaths = [
  'ARCHITECTURE.md',
  'CHANGELOG.md',
  'backend/architecture/ownership-baseline.json',
  'backend/architecture/r3-context-boundaries.json',
  'backend/architecture/r4-planning-finance-boundary.json',
  'backend/package.json',
  'backend/scripts/architecture/r3-context-scan.cjs',
  'backend/scripts/architecture/r3-scope.cjs',
  'backend/scripts/smoke/phase2-money-authorization-concurrency-smoke.ts',
  'backend/src/modules/finance/internal/finance-services.internal.module.ts',
  'backend/src/modules/planning/internal/planning-budget-write.internal.module.ts',
  'backend/src/modules/planning/internal/wedding-plan-budget-writer.ts',
  'backend/src/modules/planning/planning.module.ts',
  'backend/src/modules/planning/public/planning-budget-write-public.module.ts',
  'backend/src/modules/planning/public/planning-budget-write.port.ts',
  'backend/src/money/money-budget.service.ts',
  'backend/test/architecture-r3-context-modules-a.test.ts',
  'backend/test/architecture-r3-contexts.test.ts',
  'backend/test/architecture-r3-scope.test.ts',
  'backend/test/architecture-r4-planning-finance-boundary.test.ts',
  'backend/test/financial-integrity.test.ts',
  'docs/README.md',
  'docs/SCRIPTS.md',
  'docs/backend/README.md',
  'docs/project/DECISIONS.md',
  'docs/project/EXECUTION_PLAN.md',
  'docs/project/STATUS.md',
  'docs/qa/README.md',
  'docs/superpowers/plans/2026-08-16-modular-monolith-r4-planning-finance-ownership.md',
  'docs/superpowers/specs/2026-08-16-modular-monolith-r4-planning-finance-ownership-design.md',
] as const;

type R4Manifest = {
  schemaVersion: number;
  baseRevision: string;
  stage: string;
  ownershipDebt: { key: string; count: number };
  providerContract: {
    token: string;
    methods: string[];
    implementations: string[];
    consumers: Array<{ source: string; kind: string }>;
  };
  expectedStrictOwnership: { records: number; occurrences: number };
  allowedChangedPaths: string[];
};

type R3ScopeModule = {
  ALLOWED_PATHS: readonly string[];
  R5_ALLOWED_PATHS: readonly string[];
  validateR3Scope(options: Record<string, unknown>): {
    changedPaths: readonly string[];
    reportPath: string;
  };
  validateR4DelegationManifest(value: unknown): unknown;
};

type R3ContextScanner = {
  scanR3SourceLaws(options: Record<string, unknown>): {
    diagnostics: Array<{ kind: string }>;
  };
  scanR4PlanningBudgetWriter?: (options: Record<string, unknown>) => {
    diagnostics: Array<{ kind: string }>;
  };
};

const temporaryRoots: string[] = [];

function writeFixture(root: string, relativePath: string, content: string) {
  const target = path.join(root, relativePath);
  mkdirSync(path.dirname(target), { recursive: true });
  writeFileSync(target, content, 'utf8');
}

function sourceLawFixture(files: Record<string, string>) {
  const root = mkdtempSync(path.join(tmpdir(), 'aarast-r4-boundary-'));
  temporaryRoots.push(root);
  writeFixture(root, 'backend/tsconfig.json', `${JSON.stringify({
    compilerOptions: {
      module: 'commonjs',
      moduleResolution: 'node',
      target: 'ES2022',
      experimentalDecorators: true,
      strict: false,
      skipLibCheck: true,
    },
    include: ['src/**/*.ts'],
  }, null, 2)}\n`);
  writeFixture(root, 'backend/node_modules/@nestjs/common/index.d.ts', [
    'export declare function Module(metadata: any): ClassDecorator;',
    'export declare function Injectable(): ClassDecorator;',
    'export declare function Inject(token: unknown): ParameterDecorator;',
  ].join('\n'));
  for (const [relativePath, content] of Object.entries(files)) {
    writeFixture(root, relativePath, content);
  }
  return { repoRoot: root, backendRoot: path.join(root, 'backend') };
}

function contextScanner(): R3ContextScanner {
  return require(path.join(
    backendRoot,
    'scripts',
    'architecture',
    'r3-context-scan.cjs',
  )) as R3ContextScanner;
}

afterEach(() => {
  for (const root of temporaryRoots.splice(0)) {
    rmSync(root, { recursive: true, force: true });
  }
});

function manifest(): R4Manifest {
  return JSON.parse(readFileSync(manifestPath, 'utf8')) as R4Manifest;
}

function gitLines(args: string[]): string[] {
  return execFileSync('git', args, { cwd: repositoryRoot, encoding: 'utf8' })
    .split(/\r?\n/u)
    .map((entry) => entry.trim())
    .filter(Boolean);
}

function r3Scope(): R3ScopeModule {
  return require(path.join(
    backendRoot,
    'scripts',
    'architecture',
    'r3-scope.cjs',
  )) as R3ScopeModule;
}

test('R4 pins its immutable base and exact Planning ownership debt', () => {
  const value = manifest();

  assert.equal(value.schemaVersion, 1);
  assert.equal(value.baseRevision, r4Base);
  assert.equal(value.stage, 'strict');
  assert.deepEqual(value.ownershipDebt, {
    key: ownershipDebtKey,
    count: 1,
  });
  assert.deepEqual(value.providerContract, {
    token: 'PLANNING_BUDGET_WRITE_PORT',
    methods: ['updateBudgetInTransaction'],
    implementations: ['WeddingPlanBudgetWriter'],
    consumers: [{
      source: 'backend/src/money/money-budget.service.ts',
      kind: 'constructor-injection',
    }],
  });
  assert.deepEqual(value.expectedStrictOwnership, {
    records: 385,
    occurrences: 781,
  });
});

test('R4 changed paths are sorted, unique, relative, and byte-exact', () => {
  const value = manifest();
  assert.deepEqual(value.allowedChangedPaths, expectedAllowedPaths);
  assert.deepEqual(value.allowedChangedPaths, [...value.allowedChangedPaths].sort());
  assert.equal(new Set(value.allowedChangedPaths).size, value.allowedChangedPaths.length);
  for (const entry of value.allowedChangedPaths) {
    assert.equal(path.posix.isAbsolute(entry), false);
    assert.equal(entry.includes('\\'), false);
    assert.equal(entry.split('/').includes('..'), false);
  }
});

test('R3 accepts only the validated R4 phase handoff without mutating its receipt', () => {
  const scope = r3Scope();
  const value = manifest();
  assert.doesNotThrow(() => scope.validateR4DelegationManifest(value));

  const wrongBase = structuredClone(value);
  wrongBase.baseRevision = '0'.repeat(40);
  assert.throws(
    () => scope.validateR4DelegationManifest(wrongBase),
    /identity.*invalid/i,
  );

  const reordered = structuredClone(value);
  [reordered.allowedChangedPaths[0], reordered.allowedChangedPaths[1]] = [
    reordered.allowedChangedPaths[1],
    reordered.allowedChangedPaths[0],
  ];
  assert.throws(
    () => scope.validateR4DelegationManifest(reordered),
    /must be sorted/i,
  );

  const replaced = structuredClone(value);
  replaced.allowedChangedPaths[replaced.allowedChangedPaths.length - 1] = 'docs/attacker.md';
  assert.throws(
    () => scope.validateR4DelegationManifest(replaced),
    /(must be sorted|allowlist.*drift)/i,
  );

  assert.equal(
    scope.ALLOWED_PATHS.includes('backend/architecture/r4-planning-finance-boundary.json'),
    false,
    'the immutable R3 receipt must not be widened with R4 paths',
  );

  const result = scope.validateR3Scope({
    repositoryRoot,
    baseRef: '6b06eb096aca8cc6684d365d16e05d4cd8529898',
  });
  try {
    assert.equal(result.changedPaths.includes(manifestPath
      .slice(repositoryRoot.length + 1)
      .replaceAll('\\', '/')), true);
  } finally {
    rmSync(result.reportPath, { force: true });
  }
});

test('live R4 paths stay inside the exact manifest fence with rename detection disabled', () => {
  const changedPaths = [...new Set([
    ...gitLines(['diff', '--no-renames', '--name-only', r4Base, '--']),
    ...gitLines(['ls-files', '--others', '--exclude-standard', '--']),
  ])].sort();
  const allowed = new Set([
    ...manifest().allowedChangedPaths,
    ...r3Scope().R5_ALLOWED_PATHS,
  ]);
  assert.deepEqual(changedPaths.filter((entry) => !allowed.has(entry)), []);
});

function assertStrictOwnershipDelta(
  base: { violations: Array<Record<string, unknown>> },
  current: { violations: Array<Record<string, unknown>> },
) {
  const expected = base.violations.filter((entry) => entry.key !== ownershipDebtKey);
  assert.equal(
    base.violations.filter((entry) => entry.key === ownershipDebtKey).length,
    1,
  );
  assert.deepEqual(current.violations, expected);
  assert.equal(current.violations.length, 385);
  assert.equal(
    current.violations.reduce((sum, entry) => sum + Number(entry.count), 0),
    781,
  );
}

test('the strict ownership baseline is exactly R4 base minus one frozen debt', () => {
  const base = JSON.parse(execFileSync('git', [
    'show',
    `${r4Base}:backend/architecture/ownership-baseline.json`,
  ], { cwd: repositoryRoot, encoding: 'utf8' })) as {
    violations: Array<Record<string, unknown>>;
  };
  const current = JSON.parse(readFileSync(path.join(
    backendRoot,
    'architecture',
    'ownership-baseline.json',
  ), 'utf8')) as {
    violations: Array<Record<string, unknown>>;
  };
  assertStrictOwnershipDelta(base, current);

  const substituted = structuredClone(current);
  substituted.violations[0] = {
    ...substituted.violations[0],
    key: 'backend/src/attacker.ts|finance|planning|WeddingPlan|update|write|delegate|foreign-model',
    file: 'backend/src/attacker.ts',
  };
  assert.throws(() => assertStrictOwnershipDelta(base, substituted));
});

test('strict R4 requires the complete Planning budget-write boundary', () => {
  const requiredFiles = [
    'src/modules/planning/public/planning-budget-write.port.ts',
    'src/modules/planning/public/planning-budget-write-public.module.ts',
    'src/modules/planning/internal/wedding-plan-budget-writer.ts',
    'src/modules/planning/internal/planning-budget-write.internal.module.ts',
  ];
  assert.deepEqual(
    requiredFiles.filter((entry) => !existsSync(path.join(backendRoot, entry))),
    [],
  );
});

test('strict R4 removes the Finance delegate and records the exact public contract', () => {
  const moneyBudgetSource = readFileSync(path.join(
    backendRoot,
    'src',
    'money',
    'money-budget.service.ts',
  ), 'utf8');
  assert.doesNotMatch(moneyBudgetSource, /\btx\.weddingPlan\b/u);
  assert.match(moneyBudgetSource, /@Inject\(PLANNING_BUDGET_WRITE_PORT\)/u);
  assert.match(moneyBudgetSource, /planningBudgetWriter\.updateBudgetInTransaction\(tx,/u);

  const r3Manifest = JSON.parse(readFileSync(path.join(
    backendRoot,
    'architecture',
    'r3-context-boundaries.json',
  ), 'utf8')) as { providerContracts: unknown[] };
  assert.deepEqual(
    r3Manifest.providerContracts.filter((entry) =>
      (entry as { token?: string }).token === 'PLANNING_BUDGET_WRITE_PORT'),
    [manifest().providerContract],
  );
});

test('R4 owns one writer and exposes one singleton public useExisting alias', async () => {
  const internal = require(path.join(
    backendRoot,
    'src/modules/planning/internal/planning-budget-write.internal.module',
  ));
  const writer = require(path.join(
    backendRoot,
    'src/modules/planning/internal/wedding-plan-budget-writer',
  ));
  const publicBoundary = require(path.join(
    backendRoot,
    'src/modules/planning/public/planning-budget-write-public.module',
  ));
  const contract = require(path.join(
    backendRoot,
    'src/modules/planning/public/planning-budget-write.port',
  ));
  const planning = require(path.join(
    backendRoot,
    'src/modules/planning/planning.module',
  ));
  const finance = require(path.join(
    backendRoot,
    'src/modules/finance/internal/finance-services.internal.module',
  ));

  const internalProviders = Reflect.getMetadata(
    MODULE_METADATA.PROVIDERS,
    internal.PlanningBudgetWriteInternalModule,
  ) as unknown[];
  assert.equal(internalProviders.length, 2);
  assert.equal(internalProviders[0], writer.WeddingPlanBudgetWriter);
  assert.deepEqual(internalProviders[1], {
    provide: internal.PLANNING_BUDGET_WRITE_IMPLEMENTATION,
    useExisting: writer.WeddingPlanBudgetWriter,
  });
  assert.deepEqual(
    Reflect.getMetadata(
      MODULE_METADATA.EXPORTS,
      internal.PlanningBudgetWriteInternalModule,
    ),
    [
      writer.WeddingPlanBudgetWriter,
      internal.PLANNING_BUDGET_WRITE_IMPLEMENTATION,
    ],
  );

  assert.deepEqual(
    Reflect.getMetadata(
      MODULE_METADATA.IMPORTS,
      publicBoundary.PlanningBudgetWritePublicModule,
    ),
    [internal.PlanningBudgetWriteInternalModule],
  );
  assert.deepEqual(
    Reflect.getMetadata(
      MODULE_METADATA.PROVIDERS,
      publicBoundary.PlanningBudgetWritePublicModule,
    ),
    [{
      provide: contract.PLANNING_BUDGET_WRITE_PORT,
      useExisting: internal.PLANNING_BUDGET_WRITE_IMPLEMENTATION,
    }],
  );
  assert.deepEqual(
    Reflect.getMetadata(
      MODULE_METADATA.EXPORTS,
      publicBoundary.PlanningBudgetWritePublicModule,
    ),
    [contract.PLANNING_BUDGET_WRITE_PORT],
  );

  const planningImports = Reflect.getMetadata(
    MODULE_METADATA.IMPORTS,
    planning.PlanningModule,
  ) as Function[];
  const financeImports = Reflect.getMetadata(
    MODULE_METADATA.IMPORTS,
    finance.FinanceServicesInternalModule,
  ) as Function[];
  assert.equal(planningImports.includes(publicBoundary.PlanningBudgetWritePublicModule), true);
  assert.equal(financeImports.includes(publicBoundary.PlanningBudgetWritePublicModule), true);

  const testingModule = await NestFactory.createApplicationContext(
    publicBoundary.PlanningBudgetWritePublicModule,
    { logger: false },
  );
  try {
    assert.equal(
      testingModule.get(contract.PLANNING_BUDGET_WRITE_PORT),
      testingModule.get(writer.WeddingPlanBudgetWriter),
    );
  } finally {
    await testingModule.close();
  }
});

test('R4 writer delegates one exact update and preserves the original error identity', async () => {
  const { WeddingPlanBudgetWriter } = require(path.join(
    backendRoot,
    'src/modules/planning/internal/wedding-plan-budget-writer',
  ));
  const writer = new WeddingPlanBudgetWriter();
  const originalError = new Error('database failure sentinel');
  const calls: unknown[] = [];
  const tx = {
    weddingPlan: {
      update: async (input: unknown) => {
        calls.push(input);
        throw originalError;
      },
    },
  };

  await assert.rejects(
    writer.updateBudgetInTransaction(tx, {
      weddingPlanId: 'plan-1',
      estimatedBudget: null,
      currency: 'YER',
    }),
    (error: unknown) => {
      assert.equal(error, originalError);
      return true;
    },
  );
  assert.deepEqual(calls, [{
    where: { id: 'plan-1' },
    data: { estimatedBudget: null, currency: 'YER' },
  }]);
});

test('R4 writer isolation rejects dependencies, nested transactions, remapped errors, and extra writes', () => {
  const writerSource = (body: string, constructor = '') => [
    "import { Injectable } from '@nestjs/common';",
    '@Injectable()',
    'export class WeddingPlanBudgetWriter {',
    constructor,
    '  async updateBudgetInTransaction(tx: any, input: any): Promise<void> {',
    body,
    '  }',
    '}',
  ].filter(Boolean).join('\n');
  const exactUpdate = [
    '    await tx.weddingPlan.update({',
    '      where: { id: input.weddingPlanId },',
    '      data: {',
    '        estimatedBudget: input.estimatedBudget,',
    '        currency: input.currency,',
    '      },',
    '    });',
  ].join('\n');
  const cases = [
    {
      name: 'PrismaService dependency',
      source: writerSource(exactUpdate, '  constructor(private readonly prisma: PrismaService) {}'),
    },
    {
      name: 'nested transaction',
      source: writerSource('    await tx.$transaction(() => tx.weddingPlan.update({ where: { id: input.weddingPlanId }, data: input }));'),
    },
    {
      name: 'remapped error',
      source: writerSource([
        '    try {',
        exactUpdate,
        '    } catch {',
        "      throw new Error('mapped');",
        '    }',
      ].join('\n')),
    },
    {
      name: 'extra owner write',
      source: writerSource(`${exactUpdate}\n    await tx.weddingPlan.update({ where: { id: 'other' }, data: {} });`),
    },
  ];

  for (const entry of cases) {
    const fixture = sourceLawFixture({
      'backend/src/modules/planning/internal/wedding-plan-budget-writer.ts': entry.source,
    });
    const result = contextScanner().scanR4PlanningBudgetWriter?.(fixture) ?? { diagnostics: [] };
    assert.equal(
      result.diagnostics.some((diagnostic) => diagnostic.kind === 'r4-writer-isolation'),
      true,
      entry.name,
    );
  }
});

test('R4 module laws reject wrong internal ownership, duplicate registration, and useClass', () => {
  const contract = [{
    token: 'PLANNING_BUDGET_WRITE_PORT',
    implementations: ['WeddingPlanBudgetWriter'],
  }];
  const baseFiles = {
    'backend/src/modules/planning/internal/wedding-plan-budget-writer.ts':
      'export class WeddingPlanBudgetWriter {}\n',
    'backend/src/modules/planning/internal/planning-budget-write.internal.module.ts': [
      "import { Module } from '@nestjs/common';",
      "import { WeddingPlanBudgetWriter } from './wedding-plan-budget-writer';",
      "export const PLANNING_BUDGET_WRITE_IMPLEMENTATION = Symbol('PLANNING_BUDGET_WRITE_IMPLEMENTATION');",
      '@Module({ providers: [WeddingPlanBudgetWriter, { provide: PLANNING_BUDGET_WRITE_IMPLEMENTATION, useExisting: WeddingPlanBudgetWriter }], exports: [WeddingPlanBudgetWriter, PLANNING_BUDGET_WRITE_IMPLEMENTATION] })',
      'export class PlanningBudgetWriteInternalModule {}',
    ].join('\n'),
    'backend/src/modules/planning/public/planning-budget-write.port.ts':
      "export const PLANNING_BUDGET_WRITE_PORT = Symbol('PLANNING_BUDGET_WRITE_PORT');\n",
  };
  const publicModule = (imports: string, provider: string) => [
    "import { Module } from '@nestjs/common';",
    "import { PLANNING_BUDGET_WRITE_PORT } from './planning-budget-write.port';",
    imports,
    `@Module({ imports: [${imports.includes('Decoy') ? 'DecoyInternalModule' : 'PlanningBudgetWriteInternalModule'}], providers: [${provider}], exports: [PLANNING_BUDGET_WRITE_PORT] })`,
    'export class PlanningBudgetWritePublicModule {}',
  ].join('\n');

  const wrongInternal = sourceLawFixture({
    ...baseFiles,
    'backend/src/modules/planning/internal/decoy.internal.module.ts': [
      "import { Module } from '@nestjs/common';",
      '@Module({})',
      'export class DecoyInternalModule {}',
    ].join('\n'),
    'backend/src/modules/planning/public/planning-budget-write-public.module.ts': publicModule(
      [
        "import { DecoyInternalModule } from '../internal/decoy.internal.module';",
        "import { PLANNING_BUDGET_WRITE_IMPLEMENTATION } from '../internal/planning-budget-write.internal.module';",
      ].join('\n'),
      '{ provide: PLANNING_BUDGET_WRITE_PORT, useExisting: PLANNING_BUDGET_WRITE_IMPLEMENTATION }',
    ),
  });
  assert.ok(contextScanner().scanR3SourceLaws({
    ...wrongInternal,
    providerContracts: contract,
  }).diagnostics.some((item) => item.kind === 'public-binding-not-use-existing'));

  const useClass = sourceLawFixture({
    ...baseFiles,
    'backend/src/modules/planning/public/planning-budget-write-public.module.ts': publicModule(
      [
        "import { PlanningBudgetWriteInternalModule } from '../internal/planning-budget-write.internal.module';",
        "import { WeddingPlanBudgetWriter } from '../internal/wedding-plan-budget-writer';",
      ].join('\n'),
      '{ provide: PLANNING_BUDGET_WRITE_PORT, useClass: WeddingPlanBudgetWriter }',
    ),
  });
  assert.ok(contextScanner().scanR3SourceLaws({
    ...useClass,
    providerContracts: contract,
  }).diagnostics.some((item) => item.kind === 'public-binding-not-use-existing'));

  const duplicate = sourceLawFixture({
    ...baseFiles,
    'backend/src/modules/planning/internal/duplicate.internal.module.ts': [
      "import { Module } from '@nestjs/common';",
      "import { WeddingPlanBudgetWriter } from './wedding-plan-budget-writer';",
      '@Module({ providers: [WeddingPlanBudgetWriter] })',
      'export class DuplicateInternalModule {}',
    ].join('\n'),
  });
  assert.ok(contextScanner().scanR3SourceLaws({
    ...duplicate,
    providerContracts: contract,
  }).diagnostics.some((item) => item.kind === 'duplicate-provider'));
});

test('R4 module laws reject Finance imports of Planning internal sources', () => {
  const fixture = sourceLawFixture({
    'backend/src/modules/planning/internal/wedding-plan-budget-writer.ts':
      'export class WeddingPlanBudgetWriter {}\n',
    'backend/src/modules/finance/internal/bad.internal.module.ts': [
      "import { WeddingPlanBudgetWriter } from '../../planning/internal/wedding-plan-budget-writer';",
      'export const illegal = WeddingPlanBudgetWriter;',
    ].join('\n'),
  });
  assert.ok(contextScanner().scanR3SourceLaws(fixture).diagnostics.some(
    (item) => item.kind === 'illegal-boundary-import',
  ));
});
