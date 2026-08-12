import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import {
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { afterEach, test } from 'node:test';

type AccessMode = 'read' | 'write' | 'unknown';
type AccessSource = 'delegate' | 'relation' | 'sql';
type ViolationReason =
  | 'foreign-model'
  | 'unclassified-context'
  | 'unknown-model'
  | 'unknown-operation'
  | 'unknown-relation-shape'
  | 'unknown-sql-composition';
type OwnershipRecord = {
  key?: string;
  file: string;
  context: string;
  owner: string | null;
  model: string;
  operation: string;
  mode: AccessMode;
  source: AccessSource;
  reason?: ViolationReason | null;
  count?: number;
};

const {
  extractSchemaMetadata,
  toRepositoryPath,
  contextForRepositoryPath,
  classifyOwnershipAccesses,
  scanOwnershipViolations,
  compareWithBaseline,
  runCli,
} = require('../scripts/architecture/ownership-scan.cjs') as {
  extractSchemaMetadata: (schema: string) => {
    models: string[];
    relations: Record<string, Record<string, {
      target: string;
      isList: boolean;
      isOptional: boolean;
      relationName: string | null;
    }>>;
  };
  toRepositoryPath: (file: string, root: string, pathApi?: typeof path) => string;
  contextForRepositoryPath: (file: string, registry: Registry) => string;
  classifyOwnershipAccesses: (options: ScanOptions) => OwnershipRecord[];
  scanOwnershipViolations: (options: ScanOptions) => OwnershipRecord[];
  compareWithBaseline: (
    scan: OwnershipRecord[],
    baseline: OwnershipRecord[],
  ) => { ok: boolean; additions: OwnershipRecord[] };
  runCli: (dependencies: {
    argv: string[];
    scan: () => OwnershipRecord[];
    readBaseline: () => { schemaVersion: number; sourceRevision: string; violations: OwnershipRecord[] };
    stdout: (message: string) => void;
    stderr: (message: string) => void;
  }) => number;
};

type Registry = {
  schemaVersion: number;
  sourceRevision: string;
  owners: Record<string, string[]>;
  currentRoots: Record<string, string[]>;
  exceptions?: unknown;
};
type ScanOptions = { repoRoot: string; backendRoot: string };

const sourceRevision = 'feafe3db0053d6c66d5f46b56ff9a512861dfbad';

const backendRoot = path.resolve(__dirname, '..');
const repoRoot = path.resolve(__dirname, '../..');
const liveOptions = { repoRoot, backendRoot };
const schemaText = readFileSync(path.join(backendRoot, 'prisma', 'schema.prisma'), 'utf8');
const registry = JSON.parse(
  readFileSync(path.join(backendRoot, 'architecture', 'ownership-registry.json'), 'utf8'),
) as Registry;
const fixtureRoots: string[] = [];

function write(root: string, relativePath: string, content: string) {
  const target = path.join(root, relativePath);
  mkdirSync(path.dirname(target), { recursive: true });
  writeFileSync(target, content, 'utf8');
}

function fixtureProject(files: Record<string, string>): ScanOptions {
  const root = mkdtempSync(path.join(backendRoot, '.ownership-fixture-'));
  fixtureRoots.push(root);
  const fixtureBackend = path.join(root, 'backend');
  write(root, 'backend/prisma/schema.prisma', schemaText);
  write(root, 'backend/architecture/ownership-registry.json', `${JSON.stringify(registry, null, 2)}\n`);
  write(root, 'backend/tsconfig.json', `${JSON.stringify({
    compilerOptions: {
      module: 'commonjs',
      target: 'ES2021',
      moduleResolution: 'node',
      strict: true,
      skipLibCheck: true,
      esModuleInterop: true,
    },
    include: ['src/**/*.ts'],
  }, null, 2)}\n`);
  for (const [relativePath, content] of Object.entries(files)) {
    write(root, `backend/src/${relativePath}`, content);
  }
  return { repoRoot: root, backendRoot: fixtureBackend };
}

function prismaFixture(body: string, declarations = '') {
  return [
    "import { Prisma, PrismaClient } from '@prisma/client';",
    'declare const prisma: PrismaClient;',
    'declare const tx: Prisma.TransactionClient;',
    declarations,
    'async function exercise() {',
    body,
    '}',
  ].join('\n');
}

function pick(record: OwnershipRecord) {
  return {
    file: record.file,
    model: record.model,
    owner: record.owner,
    mode: record.mode,
    source: record.source,
    reason: record.reason ?? null,
  };
}

function exactRecord(record: OwnershipRecord) {
  return {
    file: record.file,
    model: record.model,
    owner: record.owner,
    operation: record.operation,
    mode: record.mode,
    source: record.source,
    reason: record.reason ?? null,
    count: record.count ?? 1,
  };
}

function assertExactRecords(
  records: OwnershipRecord[],
  expected: ReturnType<typeof exactRecord>[],
) {
  const order = (left: ReturnType<typeof exactRecord>, right: ReturnType<typeof exactRecord>) => (
    JSON.stringify(left).localeCompare(JSON.stringify(right))
  );
  assert.deepEqual(records.map(exactRecord).sort(order), [...expected].sort(order));
}

function ownershipKey(record: OwnershipRecord) {
  return [
    record.file,
    record.context,
    record.owner ?? '',
    record.model,
    record.operation,
    record.mode,
    record.source,
    record.reason,
  ].join('|');
}

function violation(overrides: Partial<OwnershipRecord> = {}): Required<OwnershipRecord> {
  const record: Required<OwnershipRecord> = {
    key: '',
    file: 'backend/src/money/x.ts',
    context: 'finance',
    owner: 'planning',
    model: 'WeddingPlan',
    operation: 'update',
    mode: 'write',
    source: 'delegate',
    reason: 'foreign-model',
    count: 1,
    ...overrides,
  };
  if (!overrides.key) record.key = ownershipKey(record);
  return record;
}

function ownershipBaseline(records: OwnershipRecord[] = []) {
  return {
    schemaVersion: 1,
    sourceRevision,
    violations: records,
  };
}

function captureOwnershipCli(options: {
  argv?: string[];
  scan?: unknown;
  saved?: unknown;
  writeBaseline?: (value: unknown) => void;
}) {
  const stdout: string[] = [];
  const stderr: string[] = [];
  const dependencies = {
    argv: options.argv ?? ['--check'],
    scan: () => options.scan ?? [],
    readBaseline: () => options.saved ?? ownershipBaseline(),
    writeBaseline: options.writeBaseline,
    stdout: (message: string) => stdout.push(message),
    stderr: (message: string) => stderr.push(message),
  };
  return {
    exitCode: runCli(dependencies as never),
    stdout,
    stderr,
  };
}

function assertRecord(
  records: OwnershipRecord[],
  expected: ReturnType<typeof pick>,
) {
  const matching = records.find((record) => {
    const actual = pick(record);
    return actual.file === expected.file
      && actual.model === expected.model
      && actual.owner === expected.owner
      && actual.mode === expected.mode
      && actual.source === expected.source
      && actual.reason === expected.reason;
  });
  assert.ok(matching, `missing record ${JSON.stringify(expected)}\n${JSON.stringify(records, null, 2)}`);
}

afterEach(() => {
  for (const root of fixtureRoots.splice(0)) {
    rmSync(root, { recursive: true, force: true });
  }
});

test('registry and schema contain the same models exactly once', () => {
  const metadata = extractSchemaMetadata(schemaText);
  const registered = Object.values(registry.owners).flat();
  assert.deepEqual([...registered].sort(), [...metadata.models].sort());
  assert.equal(new Set(registered).size, registered.length);
  assert.equal(registry.exceptions, undefined);
  assert.deepEqual(
    Object.entries(registry.owners)
      .filter(([, models]) => models.includes('WeddingPlan'))
      .map(([owner]) => owner),
    ['planning'],
  );
});

test('schema metadata records relation targets, list/optional flags, and names', () => {
  const metadata = extractSchemaMetadata(`
    model Parent {
      id       String  @id
      children Child[] @relation("Family")
      favorite Child?  @relation(name: "Favorite", fields: [favoriteId], references: [id])
      favoriteId String?
    }
    model Child {
      id String @id
    }
  `);
  assert.deepEqual(metadata.models, ['Parent', 'Child']);
  assert.deepEqual(metadata.relations.Parent.children, {
    target: 'Child', isList: true, isOptional: false, relationName: 'Family',
  });
  assert.deepEqual(metadata.relations.Parent.favorite, {
    target: 'Child', isList: false, isOptional: true, relationName: 'Favorite',
  });
});

test('current roots are complete, unique, and use the owner contexts', () => {
  assert.deepEqual(
    Object.keys(registry.currentRoots).sort(),
    Object.keys(registry.owners).sort(),
  );
  const roots = Object.values(registry.currentRoots).flat();
  assert.equal(new Set(roots).size, roots.length);
  const unclassified = classifyOwnershipAccesses(liveOptions)
    .filter((access) => access.context === 'unclassified')
    .map((access) => access.file);
  assert.deepEqual([...new Set(unclassified)].sort(), []);
});

test('repository paths classify identically on Windows and Linux', () => {
  assert.equal(
    toRepositoryPath('D:\\repo\\backend\\src\\auth\\auth.service.ts', 'D:\\repo', path.win32),
    'backend/src/auth/auth.service.ts',
  );
  assert.equal(
    toRepositoryPath('/repo/backend/src/auth/auth.service.ts', '/repo', path.posix),
    'backend/src/auth/auth.service.ts',
  );
  assert.throws(
    () => toRepositoryPath('/other/file.ts', '/repo', path.posix),
    /outside the repository/,
  );
  assert.equal(contextForRepositoryPath('backend/src/modules/finance/a.ts', registry), 'finance');
  assert.equal(contextForRepositoryPath('backend/src/platform/a.ts', registry), 'platform');
  assert.equal(contextForRepositoryPath('backend/src/unknown/a.ts', registry), 'unclassified');
});

test('delegate roots use generated symbols and classify local and foreign access', () => {
  const options = fixtureProject({
    'auth/root.ts': prismaFixture('await prisma.user.findUnique({ where: { id: "u" } });'),
    'money/root.ts': prismaFixture([
      'const costs = prisma.weddingCost;',
      'await costs.create({ data: {',
      '  weddingPlanId: "p", categoryId: "c", title: "x", amount: 1, currency: "YER"',
      '} });',
      'const transaction: Prisma.TransactionClient = tx;',
      'await transaction.weddingPlan.update({ where: { id: "p" }, data: { estimatedBudget: 2 } });',
    ].join('\n')),
  });
  const accesses = classifyOwnershipAccesses(options);
  assertRecord(accesses, {
    file: 'backend/src/auth/root.ts', model: 'User', owner: 'identity', mode: 'read',
    source: 'delegate', reason: null,
  });
  assertRecord(accesses, {
    file: 'backend/src/money/root.ts', model: 'WeddingCost', owner: 'finance', mode: 'write',
    source: 'delegate', reason: null,
  });
  assertRecord(scanOwnershipViolations(options), {
    file: 'backend/src/money/root.ts', model: 'WeddingPlan', owner: 'planning', mode: 'write',
    source: 'delegate', reason: 'foreign-model',
  });
});

test('Prisma static element access and proven delegate aliases cannot bypass ownership', () => {
  const options = fixtureProject({
    'money/element-method.ts': prismaFixture(
      'await prisma.user[\'findMany\']({ where: { id: "u" } });',
    ),
    'money/element-root.ts': prismaFixture(
      'await prisma[\'weddingPlan\'].findMany({ where: { id: "p" } });',
    ),
    'money/const-delegate.ts': prismaFixture([
      'const delegate = prisma.user;',
      'await delegate.findMany({ where: { id: "u" } });',
    ].join('\n')),
    'money/destructured-delegate.ts': prismaFixture([
      'const { chatMessage } = prisma;',
      'await chatMessage.findMany({ where: { id: "m" } });',
    ].join('\n')),
    'admin/raw-alias.ts': prismaFixture([
      'const raw = prisma[\'$queryRawUnsafe\'];',
      'await raw(\'SELECT * FROM "WeddingPlan"\');',
    ].join('\n')),
    'admin/raw-element.ts': prismaFixture(
      'await prisma[\'$queryRawUnsafe\'](\'SELECT * FROM "Conversation"\');',
    ),
    'admin/destructured-raw-alias.ts': prismaFixture([
      'const { $queryRawUnsafe: raw } = prisma;',
      'await raw(\'SELECT * FROM "ChatMessage"\');',
    ].join('\n')),
  });

  assertExactRecords(scanOwnershipViolations(options), [
    {
      file: 'backend/src/admin/destructured-raw-alias.ts', model: 'ChatMessage', owner: 'messaging',
      operation: 'select', mode: 'read', source: 'sql', reason: 'foreign-model', count: 1,
    },
    {
      file: 'backend/src/admin/raw-alias.ts', model: 'WeddingPlan', owner: 'planning',
      operation: 'select', mode: 'read', source: 'sql', reason: 'foreign-model', count: 1,
    },
    {
      file: 'backend/src/admin/raw-element.ts', model: 'Conversation', owner: 'messaging',
      operation: 'select', mode: 'read', source: 'sql', reason: 'foreign-model', count: 1,
    },
    {
      file: 'backend/src/money/const-delegate.ts', model: 'User', owner: 'identity',
      operation: 'findMany', mode: 'read', source: 'delegate', reason: 'foreign-model', count: 1,
    },
    {
      file: 'backend/src/money/destructured-delegate.ts', model: 'ChatMessage', owner: 'messaging',
      operation: 'findMany', mode: 'read', source: 'delegate', reason: 'foreign-model', count: 1,
    },
    {
      file: 'backend/src/money/element-method.ts', model: 'User', owner: 'identity',
      operation: 'findMany', mode: 'read', source: 'delegate', reason: 'foreign-model', count: 1,
    },
    {
      file: 'backend/src/money/element-root.ts', model: 'WeddingPlan', owner: 'planning',
      operation: 'findMany', mode: 'read', source: 'delegate', reason: 'foreign-model', count: 1,
    },
  ]);
});

test('raw-operation provenance rejects delegate-bearing local wrappers and preserves true Prisma roots', () => {
  const options = fixtureProject({
    'money/local-wrapper.ts': prismaFixture([
      'const local = {',
      '  user: prisma.user,',
      '  $queryRawUnsafe: async (_sql: string) => [],',
      '};',
      'const localRaw = local.$queryRawUnsafe;',
      'const { $queryRawUnsafe: destructuredLocalRaw } = local;',
      'declare const dynamicOperation: string;',
      'const dynamicLocalRaw = local[dynamicOperation];',
      'await local.$queryRawUnsafe(\'SELECT * FROM "WeddingPlan"\');',
      'await localRaw(\'SELECT * FROM "WeddingPlan"\');',
      'await destructuredLocalRaw(\'SELECT * FROM "WeddingPlan"\');',
      'await dynamicLocalRaw(\'SELECT * FROM "WeddingPlan"\');',
      'await local.user.findMany({ where: { id: "u" } });',
    ].join('\n')),
    'admin/prisma-root-controls.ts': prismaFixture([
      'const serviceRaw = service[\'$queryRawUnsafe\'];',
      'const { $queryRawUnsafe: transactionRaw } = tx;',
      'await serviceRaw(\'SELECT * FROM "User"\');',
      'await transactionRaw(\'SELECT * FROM "Conversation"\');',
    ].join('\n'), [
      'declare class PrismaService extends PrismaClient {}',
      'declare const service: PrismaService;',
    ].join('\n')),
  });

  assertExactRecords(scanOwnershipViolations(options), [
    {
      file: 'backend/src/admin/prisma-root-controls.ts', model: 'Conversation', owner: 'messaging',
      operation: 'select', mode: 'read', source: 'sql', reason: 'foreign-model', count: 1,
    },
    {
      file: 'backend/src/admin/prisma-root-controls.ts', model: 'User', owner: 'identity',
      operation: 'select', mode: 'read', source: 'sql', reason: 'foreign-model', count: 1,
    },
    {
      file: 'backend/src/money/local-wrapper.ts', model: 'User', owner: 'identity',
      operation: 'findMany', mode: 'read', source: 'delegate', reason: 'foreign-model', count: 1,
    },
  ]);
});

test('proven Prisma dynamic accesses fail closed while local homonyms and alias cycles do not', () => {
  const options = fixtureProject({
    'auth/dynamic-method.ts': prismaFixture(
      'declare const operation: string; await prisma.user[operation]({});',
    ),
    'auth/dynamic-root.ts': prismaFixture(
      'declare const delegateName: string; await prisma[delegateName].findMany({});',
    ),
    'auth/dynamic-delegate-alias.ts': prismaFixture([
      'declare const delegateName: string;',
      'const dynamicDelegate = prisma[delegateName];',
      'await dynamicDelegate.findMany({});',
    ].join('\n')),
    'auth/dynamic-method-alias.ts': prismaFixture([
      'declare const operation: string;',
      'const dynamicMethod = prisma.user[operation];',
      'await dynamicMethod({});',
    ].join('\n')),
    'auth/dynamic-raw-alias.ts': prismaFixture([
      'declare const operation: string;',
      'const dynamicRaw = prisma[operation];',
      'await dynamicRaw(\'SELECT * FROM "User"\');',
    ].join('\n')),
    'auth/local-homonyms.ts': [
      'const local = {',
      '  user: { findMany: async () => [] },',
      '  $queryRawUnsafe: async (_sql: string) => [],',
      '};',
      'const delegate = local.user;',
      'const raw = local[\'$queryRawUnsafe\'];',
      'void delegate[\'findMany\']();',
      'void raw(\'SELECT * FROM "WeddingPlan"\');',
      'const first = second;',
      'const second = first;',
      'void first.findMany();',
    ].join('\n'),
  });

  assertExactRecords(scanOwnershipViolations(options), [
    {
      file: 'backend/src/auth/dynamic-delegate-alias.ts', model: '<dynamic>', owner: null,
      operation: 'findMany', mode: 'read', source: 'delegate', reason: 'unknown-model', count: 1,
    },
    {
      file: 'backend/src/auth/dynamic-method.ts', model: 'User', owner: 'identity',
      operation: 'dynamic', mode: 'unknown', source: 'delegate', reason: 'unknown-operation', count: 1,
    },
    {
      file: 'backend/src/auth/dynamic-method-alias.ts', model: 'User', owner: 'identity',
      operation: 'dynamic', mode: 'unknown', source: 'delegate', reason: 'unknown-operation', count: 1,
    },
    {
      file: 'backend/src/auth/dynamic-raw-alias.ts', model: '<dynamic>', owner: null,
      operation: 'dynamic', mode: 'unknown', source: 'sql', reason: 'unknown-operation', count: 1,
    },
    {
      file: 'backend/src/auth/dynamic-root.ts', model: '<dynamic>', owner: null,
      operation: 'findMany', mode: 'read', source: 'delegate', reason: 'unknown-model', count: 1,
    },
  ]);
});

test('nested delegate calls inside Prisma arguments and SQL interpolations are counted once', () => {
  const options = fixtureProject({
    'money/nested-delegates.ts': prismaFixture([
      'await prisma.weddingCost.findMany({',
      '  where: { id: { in: (await prisma.weddingPlan.findMany({ select: { id: true } })).map((plan) => plan.id) } },',
      '});',
      'await prisma.$queryRaw(Prisma.sql`SELECT * FROM "WeddingCost" WHERE "id" = ${',
      '  await prisma.weddingPlan.findUnique({ where: { id: "p" } })',
      '}`);',
    ].join('\n')),
  });
  assertExactRecords(scanOwnershipViolations(options), [
    {
      file: 'backend/src/money/nested-delegates.ts', model: 'WeddingPlan', owner: 'planning',
      operation: 'findMany', mode: 'read', source: 'delegate', reason: 'foreign-model', count: 1,
    },
    {
      file: 'backend/src/money/nested-delegates.ts', model: 'WeddingPlan', owner: 'planning',
      operation: 'findUnique', mode: 'read', source: 'delegate', reason: 'foreign-model', count: 1,
    },
  ]);
});

test('delegate provenance follows generated symbols rather than misleading local type names', () => {
  const options = fixtureProject({
    'auth/delegate-provenance.ts': prismaFixture([
      'await misleading.findUnique({ where: { id: "spoof" } });',
      'await aliased.findUnique({ where: { id: "alias" } });',
      'await tx.weddingPlan.findUnique({ where: { id: "transaction" } });',
    ].join('\n'), [
      'interface UserDelegate extends Prisma.WeddingPlanDelegate {}',
      'declare const misleading: UserDelegate;',
      'type RealPlanAlias = Prisma.WeddingPlanDelegate;',
      'declare const aliased: RealPlanAlias;',
    ].join('\n')),
  });
  assertExactRecords(scanOwnershipViolations(options), [
    {
      file: 'backend/src/auth/delegate-provenance.ts', model: 'WeddingPlan', owner: 'planning',
      operation: 'findUnique', mode: 'read', source: 'delegate', reason: 'foreign-model', count: 3,
    },
  ]);
  assert.equal(
    classifyOwnershipAccesses(options).some((record) => record.model === 'User'),
    false,
  );
});

test('relation include, nested select, nested write, filter, and orderBy switch owners', () => {
  const options = fixtureProject({
    'marketplace/relations.ts': prismaFixture([
      'await prisma.provider.findMany({ include: { city: true, primaryCategory: true } });',
      'await prisma.provider.findMany({ select: { services: { select: { category: true } } } });',
      'await prisma.provider.findMany({ where: { city: { name: { contains: "S" } } }, orderBy: { city: { name: "asc" } } });',
    ].join('\n')),
    'wedding-plans/nested-write.ts': prismaFixture(
      'await prisma.weddingPlan.update({ where: { id: "p" }, data: { weddingCosts: { create: { categoryId: "c", title: "x", amount: 1, currency: "YER" } } } });',
    ),
  });
  const records = scanOwnershipViolations(options);
  for (const model of ['City', 'ProviderCategory']) {
    assertRecord(records, {
      file: 'backend/src/marketplace/relations.ts', model, owner: 'catalog', mode: 'read',
      source: 'relation', reason: 'foreign-model',
    });
  }
  assertRecord(records, {
    file: 'backend/src/marketplace/relations.ts', model: 'ProviderCategory', owner: 'catalog',
    mode: 'read', source: 'relation', reason: 'foreign-model',
  });
  const city = records.find((record) => record.file.endsWith('relations.ts') && record.model === 'City');
  assert.ok(city && (city.count ?? 0) >= 3, JSON.stringify(records, null, 2));
  assertRecord(records, {
    file: 'backend/src/wedding-plans/nested-write.ts', model: 'WeddingCost', owner: 'finance',
    mode: 'write', source: 'relation', reason: 'foreign-model',
  });
});

test('logical relation filters, static array spreads, and scalar nested writes keep their shapes', () => {
  const options = fixtureProject({
    'marketplace/logical.ts': prismaFixture([
      'const filters = [{ city: { is: { name: { contains: "S" } } } }] as const;',
      'await prisma.provider.findMany({ where: { OR: [...filters] } });',
    ].join('\n')),
    'auth/disconnect.ts': prismaFixture(
      'await prisma.user.update({ where: { id: "u" }, data: { providerProfile: { disconnect: true } } });',
    ),
  });
  const records = scanOwnershipViolations(options);
  assertRecord(records, {
    file: 'backend/src/marketplace/logical.ts', model: 'City', owner: 'catalog', mode: 'read',
    source: 'relation', reason: 'foreign-model',
  });
  assertRecord(records, {
    file: 'backend/src/auth/disconnect.ts', model: 'Provider', owner: 'marketplace', mode: 'write',
    source: 'relation', reason: 'foreign-model',
  });
  assert.equal(records.some((record) => record.reason === 'unknown-relation-shape'), false);
});

test('_count preserves the current model and classifies selected relations', () => {
  const options = fixtureProject({
    'money/count.ts': prismaFixture(
      'await prisma.budgetCategory.findMany({ include: { _count: { select: { weddingCosts: true } } } });',
    ),
    'admin/count.ts': prismaFixture(
      'await prisma.providerCategory.findMany({ include: { _count: { select: { providers: true, services: true } } } });',
    ),
  });
  const records = scanOwnershipViolations(options);
  assert.equal(records.some((record) => record.file.endsWith('money/count.ts')), false);
  for (const model of ['Provider', 'ProviderService']) {
    assertRecord(records, {
      file: 'backend/src/admin/count.ts', model, owner: 'marketplace', mode: 'read',
      source: 'relation', reason: 'foreign-model',
    });
  }
});

test('static const arguments resolve while call, mutable import, and computed spread fail closed', () => {
  const options = fixtureProject({
    'marketplace/static.ts': prismaFixture([
      'const args = { include: { city: true } } as const;',
      'await prisma.provider.findMany(args);',
    ].join('\n')),
    'marketplace/call.ts': prismaFixture(
      'await prisma.provider.findMany(makeArgs());',
      'declare function makeArgs(): Prisma.ProviderFindManyArgs;',
    ),
    'marketplace/imported.ts': [
      "import { PrismaClient } from '@prisma/client';",
      "import { importedArgs } from './mutable';",
      'declare const prisma: PrismaClient;',
      'async function exercise() { await prisma.provider.findMany(importedArgs); }',
    ].join('\n'),
    'marketplace/mutable.ts': [
      "import { Prisma } from '@prisma/client';",
      'export let importedArgs: Prisma.ProviderFindManyArgs = { include: { city: true } };',
    ].join('\n'),
    'marketplace/spread.ts': prismaFixture([
      'const relation = "city";',
      'await prisma.provider.findMany({ include: { primaryCategory: true, ...{ [relation]: true } } });',
    ].join('\n')),
  });
  const records = scanOwnershipViolations(options);
  assertRecord(records, {
    file: 'backend/src/marketplace/static.ts', model: 'City', owner: 'catalog', mode: 'read',
    source: 'relation', reason: 'foreign-model',
  });
  for (const file of [
    'backend/src/marketplace/call.ts',
    'backend/src/marketplace/imported.ts',
    'backend/src/marketplace/spread.ts',
  ]) {
    assertRecord(records, {
      file, model: '<dynamic>', owner: null, mode: 'unknown', source: 'relation',
      reason: 'unknown-relation-shape',
    });
  }
  assertRecord(records, {
    file: 'backend/src/marketplace/spread.ts', model: 'ProviderCategory', owner: 'catalog',
    mode: 'read', source: 'relation', reason: 'foreign-model',
  });
});

test('raw SQL finds direct, nested, joined, CTE, and dynamic physical tables', () => {
  const options = fixtureProject({
    'admin/sql.ts': prismaFixture([
      'const planId = "p";',
      'await tx.$queryRaw`SELECT * FROM "WeddingPlan" WHERE "id" = ${planId}`;',
      'await prisma.$queryRaw(Prisma.sql`SELECT * FROM "Conversation" JOIN "ChatMessage" ON true`);',
      'const fragments = [Prisma.sql`SELECT * FROM "WeddingPlan"`, Prisma.sql`SELECT * FROM "User"`] as const;',
      'await prisma.$queryRaw(Prisma.sql`${Prisma.join(fragments, " UNION ALL ")}`);',
      'const planIds: string[] = ["p"];',
      'await prisma.$queryRaw(Prisma.sql`SELECT * FROM "WeddingPlan" WHERE "id" IN (${Prisma.join(planIds)})`);',
      'const condition = true;',
      'const predicate = condition ? Prisma.sql`EXISTS (SELECT 1 FROM "ChatMessage")` : Prisma.sql`EXISTS (SELECT 1 FROM "Conversation")`;',
      'await prisma.$queryRaw(Prisma.sql`SELECT * FROM "User" WHERE ${predicate}`);',
      'await prisma.$queryRaw`WITH recent AS (SELECT * FROM "ChatMessage") SELECT * FROM recent`;',
      'const tableName = "WeddingPlan";',
      'await prisma.$queryRaw(Prisma.sql`SELECT * FROM ${tableName}`);',
    ].join('\n')),
  });
  const records = scanOwnershipViolations(options);
  for (const [model, owner] of [
    ['WeddingPlan', 'planning'],
    ['Conversation', 'messaging'],
    ['ChatMessage', 'messaging'],
    ['User', 'identity'],
  ] as const) {
    assertRecord(records, {
      file: 'backend/src/admin/sql.ts', model, owner, mode: 'read', source: 'sql',
      reason: 'foreign-model',
    });
  }
  assertRecord(records, {
    file: 'backend/src/admin/sql.ts', model: '<dynamic>', owner: null, mode: 'read',
    source: 'sql', reason: 'unknown-model',
  });
  assert.equal(
    records.some((record) => record.reason === 'unknown-sql-composition'),
    false,
    JSON.stringify(records, null, 2),
  );
});

test('raw SQL unresolved Sql composition fails closed without hiding resolvable siblings', () => {
  const options = fixtureProject({
    'admin/sql-unknown.ts': prismaFixture([
      'let fragments: Prisma.Sql[] = [Prisma.sql`SELECT * FROM "WeddingPlan"`];',
      'await prisma.$queryRaw(Prisma.sql`${Prisma.join(fragments)}`);',
      'declare function loadSql(): Prisma.Sql;',
      'const unresolved: Prisma.Sql = loadSql();',
      'await prisma.$queryRaw(Prisma.sql`SELECT * FROM "User" WHERE ${unresolved}`);',
    ].join('\n')),
  });
  const records = scanOwnershipViolations(options);
  assertRecord(records, {
    file: 'backend/src/admin/sql-unknown.ts', model: '<dynamic>', owner: null,
    mode: 'unknown', source: 'sql', reason: 'unknown-sql-composition',
  });
  assertRecord(records, {
    file: 'backend/src/admin/sql-unknown.ts', model: 'User', owner: 'identity', mode: 'read',
    source: 'sql', reason: 'foreign-model',
  });
});

test('Prisma.join distinguishes unknown inputs, mutable SQL arrays, readonly SQL tuples, and scalar arrays', () => {
  const options = fixtureProject({
    'admin/join-any.ts': prismaFixture(
      'await prisma.$queryRaw(Prisma.sql`SELECT * FROM "User" WHERE ${Prisma.join(anyFragments)}`);',
      'declare const anyFragments: any;',
    ),
    'admin/join-unknown.ts': prismaFixture(
      'await prisma.$queryRaw(Prisma.sql`SELECT * FROM "User" WHERE ${Prisma.join(unknownFragments)}`);',
      'declare const unknownFragments: unknown;',
    ),
    'admin/join-mutable-sql.ts': prismaFixture([
      'const mutableFragments: Prisma.Sql[] = [Prisma.sql`SELECT 1 FROM "WeddingPlan"`];',
      'mutableFragments.push(Prisma.sql`SELECT 1 FROM "User"`);',
      'await prisma.$queryRaw(Prisma.sql`SELECT * FROM "ChatMessage" WHERE ${Prisma.join(mutableFragments)}`);',
    ].join('\n')),
    'admin/join-static-sql.ts': prismaFixture([
      'const fragments = [',
      '  Prisma.sql`SELECT * FROM "WeddingPlan"`,',
      '  Prisma.sql`SELECT * FROM "User"`,',
      '] as const;',
      'await prisma.$queryRaw(Prisma.sql`${Prisma.join(fragments, " UNION ALL ")}`);',
    ].join('\n')),
    'admin/join-scalars.ts': prismaFixture([
      'const planIds: string[] = ["p-1", "p-2"];',
      'await prisma.$queryRaw(Prisma.sql`SELECT * FROM "WeddingPlan" WHERE "id" IN (${Prisma.join(planIds)})`);',
    ].join('\n')),
  });
  assertExactRecords(scanOwnershipViolations(options), [
    {
      file: 'backend/src/admin/join-any.ts', model: '<dynamic>', owner: null,
      operation: '$queryRaw', mode: 'unknown', source: 'sql',
      reason: 'unknown-sql-composition', count: 1,
    },
    {
      file: 'backend/src/admin/join-any.ts', model: 'User', owner: 'identity',
      operation: 'select', mode: 'read', source: 'sql', reason: 'foreign-model', count: 1,
    },
    {
      file: 'backend/src/admin/join-unknown.ts', model: '<dynamic>', owner: null,
      operation: '$queryRaw', mode: 'unknown', source: 'sql',
      reason: 'unknown-sql-composition', count: 1,
    },
    {
      file: 'backend/src/admin/join-unknown.ts', model: 'User', owner: 'identity',
      operation: 'select', mode: 'read', source: 'sql', reason: 'foreign-model', count: 1,
    },
    {
      file: 'backend/src/admin/join-mutable-sql.ts', model: '<dynamic>', owner: null,
      operation: '$queryRaw', mode: 'unknown', source: 'sql',
      reason: 'unknown-sql-composition', count: 1,
    },
    {
      file: 'backend/src/admin/join-mutable-sql.ts', model: 'ChatMessage', owner: 'messaging',
      operation: 'select', mode: 'read', source: 'sql', reason: 'foreign-model', count: 1,
    },
    {
      file: 'backend/src/admin/join-scalars.ts', model: 'WeddingPlan', owner: 'planning',
      operation: 'select', mode: 'read', source: 'sql', reason: 'foreign-model', count: 1,
    },
    {
      file: 'backend/src/admin/join-static-sql.ts', model: 'User', owner: 'identity',
      operation: 'select', mode: 'read', source: 'sql', reason: 'foreign-model', count: 1,
    },
    {
      file: 'backend/src/admin/join-static-sql.ts', model: 'WeddingPlan', owner: 'planning',
      operation: 'select', mode: 'read', source: 'sql', reason: 'foreign-model', count: 1,
    },
  ]);
});

test('each mandatory SQL fixture produces its own exact records', () => {
  const options = fixtureProject({
    'admin/sql-direct.ts': prismaFixture([
      'const planId = "p";',
      'await tx.$queryRaw`SELECT * FROM "WeddingPlan" WHERE "id" = ${planId}`;',
    ].join('\n')),
    'admin/sql-tagged-join.ts': prismaFixture(
      'await prisma.$queryRaw(Prisma.sql`SELECT * FROM "Conversation" JOIN "ChatMessage" ON true`);',
    ),
    'admin/sql-fragment-join.ts': prismaFixture([
      'const fragments = [Prisma.sql`SELECT * FROM "WeddingPlan"`, Prisma.sql`SELECT * FROM "User"`] as const;',
      'await prisma.$queryRaw(Prisma.sql`${Prisma.join(fragments, " UNION ALL ")}`);',
    ].join('\n')),
    'admin/sql-scalar-join.ts': prismaFixture([
      'const ids: string[] = ["p"];',
      'await prisma.$queryRaw(Prisma.sql`SELECT * FROM "WeddingPlan" WHERE "id" IN (${Prisma.join(ids)})`);',
    ].join('\n')),
    'admin/sql-mutable-join.ts': prismaFixture([
      'let fragments: Prisma.Sql[] = [Prisma.sql`SELECT * FROM "WeddingPlan"`];',
      'await prisma.$queryRaw(Prisma.sql`SELECT * FROM "User" WHERE ${Prisma.join(fragments)}`);',
    ].join('\n')),
    'admin/sql-conditional.ts': prismaFixture([
      'const condition = true;',
      'const predicate = condition ? Prisma.sql`EXISTS (SELECT 1 FROM "ChatMessage")` : Prisma.sql`EXISTS (SELECT 1 FROM "Conversation")`;',
      'await prisma.$queryRaw(Prisma.sql`SELECT * FROM "User" WHERE ${predicate}`);',
    ].join('\n')),
    'admin/sql-unresolved.ts': prismaFixture([
      'declare function loadSql(): Prisma.Sql;',
      'const unresolved: Prisma.Sql = loadSql();',
      'await prisma.$queryRaw(Prisma.sql`SELECT * FROM "User" WHERE ${unresolved}`);',
    ].join('\n')),
    'admin/sql-cte.ts': prismaFixture(
      'await prisma.$queryRaw`WITH recent AS (SELECT * FROM "ChatMessage") SELECT * FROM recent`;',
    ),
    'admin/sql-dynamic.ts': prismaFixture([
      'const tableName = "WeddingPlan";',
      'await prisma.$queryRaw(Prisma.sql`SELECT * FROM ${tableName}`);',
    ].join('\n')),
    'admin/sql-update.ts': prismaFixture(
      'await prisma.$queryRaw`UPDATE "WeddingPlan" SET "title" = ${"x"}`;',
    ),
    'admin/sql-delete.ts': prismaFixture(
      'await prisma.$executeRaw`DELETE FROM "User" WHERE "id" = ${"u"}`;',
    ),
    'admin/sql-truncate.ts': prismaFixture(
      'await prisma.$executeRaw`TRUNCATE "ChatMessage"`;',
    ),
    'admin/sql-unsupported.ts': prismaFixture(
      'await prisma.$executeRawUnsafe(`VACUUM "User"`);',
    ),
    'admin/sql-tableless.ts': prismaFixture([
      'await prisma.$queryRaw`SELECT 1`;',
      'await prisma.$queryRaw`SELECT pg_advisory_lock(1)`;',
      'await prisma.$queryRaw(Prisma.sql`SELECT set_config(\'x\', \'y\', true)`);',
    ].join('\n')),
  });
  assertExactRecords(scanOwnershipViolations(options), [
    { file: 'backend/src/admin/sql-direct.ts', model: 'WeddingPlan', owner: 'planning', operation: 'select', mode: 'read', source: 'sql', reason: 'foreign-model', count: 1 },
    { file: 'backend/src/admin/sql-tagged-join.ts', model: 'Conversation', owner: 'messaging', operation: 'select', mode: 'read', source: 'sql', reason: 'foreign-model', count: 1 },
    { file: 'backend/src/admin/sql-tagged-join.ts', model: 'ChatMessage', owner: 'messaging', operation: 'join', mode: 'read', source: 'sql', reason: 'foreign-model', count: 1 },
    { file: 'backend/src/admin/sql-fragment-join.ts', model: 'WeddingPlan', owner: 'planning', operation: 'select', mode: 'read', source: 'sql', reason: 'foreign-model', count: 1 },
    { file: 'backend/src/admin/sql-fragment-join.ts', model: 'User', owner: 'identity', operation: 'select', mode: 'read', source: 'sql', reason: 'foreign-model', count: 1 },
    { file: 'backend/src/admin/sql-scalar-join.ts', model: 'WeddingPlan', owner: 'planning', operation: 'select', mode: 'read', source: 'sql', reason: 'foreign-model', count: 1 },
    { file: 'backend/src/admin/sql-mutable-join.ts', model: 'User', owner: 'identity', operation: 'select', mode: 'read', source: 'sql', reason: 'foreign-model', count: 1 },
    { file: 'backend/src/admin/sql-mutable-join.ts', model: '<dynamic>', owner: null, operation: '$queryRaw', mode: 'unknown', source: 'sql', reason: 'unknown-sql-composition', count: 1 },
    { file: 'backend/src/admin/sql-conditional.ts', model: 'ChatMessage', owner: 'messaging', operation: 'select', mode: 'read', source: 'sql', reason: 'foreign-model', count: 1 },
    { file: 'backend/src/admin/sql-conditional.ts', model: 'Conversation', owner: 'messaging', operation: 'select', mode: 'read', source: 'sql', reason: 'foreign-model', count: 1 },
    { file: 'backend/src/admin/sql-conditional.ts', model: 'User', owner: 'identity', operation: 'select', mode: 'read', source: 'sql', reason: 'foreign-model', count: 2 },
    { file: 'backend/src/admin/sql-unresolved.ts', model: 'User', owner: 'identity', operation: 'select', mode: 'read', source: 'sql', reason: 'foreign-model', count: 1 },
    { file: 'backend/src/admin/sql-unresolved.ts', model: '<dynamic>', owner: null, operation: '$queryRaw', mode: 'unknown', source: 'sql', reason: 'unknown-sql-composition', count: 1 },
    { file: 'backend/src/admin/sql-cte.ts', model: 'ChatMessage', owner: 'messaging', operation: 'select', mode: 'read', source: 'sql', reason: 'foreign-model', count: 1 },
    { file: 'backend/src/admin/sql-dynamic.ts', model: '<dynamic>', owner: null, operation: 'select', mode: 'read', source: 'sql', reason: 'unknown-model', count: 1 },
    { file: 'backend/src/admin/sql-update.ts', model: 'WeddingPlan', owner: 'planning', operation: 'update', mode: 'write', source: 'sql', reason: 'foreign-model', count: 1 },
    { file: 'backend/src/admin/sql-delete.ts', model: 'User', owner: 'identity', operation: 'delete', mode: 'write', source: 'sql', reason: 'foreign-model', count: 1 },
    { file: 'backend/src/admin/sql-truncate.ts', model: 'ChatMessage', owner: 'messaging', operation: 'truncate', mode: 'write', source: 'sql', reason: 'foreign-model', count: 1 },
    { file: 'backend/src/admin/sql-unsupported.ts', model: '<dynamic>', owner: null, operation: '$executeRawUnsafe', mode: 'unknown', source: 'sql', reason: 'unknown-sql-composition', count: 1 },
  ]);
});

test('CTE row locks and advisory calls do not invent physical table names', () => {
  const options = fixtureProject({
    'common/locks.ts': prismaFixture([
      'const batchSize = 5;',
      'await tx.$queryRaw(Prisma.sql`',
      '  WITH candidates AS (',
      '    SELECT "id" FROM "OutboxEvent" FOR UPDATE SKIP LOCKED LIMIT ${batchSize}',
      '  )',
      '  UPDATE "OutboxEvent" AS event SET "status" = \'PROCESSING\'',
      '  FROM candidates WHERE event."id" = candidates."id"',
      '`);',
      'await tx.$queryRaw`SELECT pg_try_advisory_xact_lock(1, 2)`;',
    ].join('\n')),
  });
  const accesses = classifyOwnershipAccesses(options).filter((record) => record.source === 'sql');
  assert.equal(accesses.some((record) => ['OF', 'SKIP'].includes(record.model)), false);
  assert.equal(accesses.some((record) => record.reason === 'unknown-sql-composition'), false);
  assert.equal(accesses.filter((record) => record.model === 'OutboxEvent').length, 2);
  assert.deepEqual(scanOwnershipViolations(options), []);
});

test('a generated delegate method outside the fixed operation sets fails closed', () => {
  const options = fixtureProject({
    'auth/unknown-operation.ts': prismaFixture('await prisma.user.fields();'),
  });
  assertRecord(scanOwnershipViolations(options), {
    file: 'backend/src/auth/unknown-operation.ts', model: 'User', owner: 'identity',
    mode: 'unknown', source: 'delegate', reason: 'unknown-operation',
  });
});

test('SQL mutation modes, unsupported statements, and tableless allowlist are exact', () => {
  const options = fixtureProject({
    'admin/sql-modes.ts': prismaFixture([
      'await prisma.$queryRaw`UPDATE "WeddingPlan" SET "title" = ${"x"}`;',
      'await prisma.$executeRaw`DELETE FROM "User" WHERE "id" = ${"u"}`;',
      'await prisma.$executeRaw`TRUNCATE "ChatMessage"`;',
      'await prisma.$executeRawUnsafe(`VACUUM "User"`);',
      'await prisma.$queryRaw`SELECT 1`;',
      'await prisma.$queryRaw`SELECT pg_advisory_lock(1)`;',
      'await prisma.$queryRaw(Prisma.sql`SELECT set_config(\'x\', \'y\', true)`);',
    ].join('\n')),
  });
  const records = scanOwnershipViolations(options);
  for (const [model, owner] of [
    ['WeddingPlan', 'planning'],
    ['User', 'identity'],
    ['ChatMessage', 'messaging'],
  ] as const) {
    assertRecord(records, {
      file: 'backend/src/admin/sql-modes.ts', model, owner, mode: 'write', source: 'sql',
      reason: 'foreign-model',
    });
  }
  assertRecord(records, {
    file: 'backend/src/admin/sql-modes.ts', model: '<dynamic>', owner: null,
    mode: 'unknown', source: 'sql', reason: 'unknown-sql-composition',
  });
  assert.equal(records.filter((record) => record.file.endsWith('sql-modes.ts')).length, 4);
});

test('unsafe strings and PostgreSQL table-bearing forms report every physical table', () => {
  const options = fixtureProject({
    'admin/sql-forms.ts': prismaFixture([
      'await prisma.$queryRawUnsafe(\'SELECT * FROM "WeddingPlan", "User"\');',
      'const insertSql = \'INSERT INTO "ChatMessage" ("id") VALUES (\\\'m\\\')\' as const;',
      'await prisma.$executeRawUnsafe(insertSql);',
      'await prisma.$executeRawUnsafe(\'LOCK TABLE "User"\');',
      'await prisma.$executeRawUnsafe(\'ALTER TABLE "User" ADD COLUMN "x" text\');',
      'await prisma.$executeRawUnsafe(\'DROP TABLE "User"\');',
      'await prisma.$executeRawUnsafe(\'CREATE TABLE "User" ("id" text)\');',
      'await prisma.$executeRawUnsafe(\'MERGE INTO "Provider" USING "City" ON true WHEN MATCHED THEN DO NOTHING\');',
      'await prisma.$executeRawUnsafe(\'COPY "ChatMessage" FROM STDIN\');',
      'await prisma.$executeRawUnsafe(\'DELETE FROM "Conversation" USING "User" WHERE true\');',
    ].join('\n')),
  });
  const records = scanOwnershipViolations(options);
  for (const [model, owner, mode] of [
    ['WeddingPlan', 'planning', 'read'],
    ['User', 'identity', 'read'],
    ['ChatMessage', 'messaging', 'write'],
    ['User', 'identity', 'write'],
    ['Provider', 'marketplace', 'write'],
    ['City', 'catalog', 'read'],
    ['Conversation', 'messaging', 'write'],
  ] as const) {
    assertRecord(records, {
      file: 'backend/src/admin/sql-forms.ts', model, owner, mode, source: 'sql',
      reason: 'foreign-model',
    });
  }
  assert.ok(records.some((record) => (
    record.model === 'User' && record.operation === 'select' && record.mode === 'read'
  )), JSON.stringify(records, null, 2));
  assert.equal(records.some((record) => record.reason?.startsWith('unknown-')), false);
});

test('PostgreSQL table lists record every physical table and dynamic list positions fail closed', () => {
  const options = fixtureProject({
    'admin/sql-truncate-list.ts': prismaFixture(
      'await prisma.$executeRawUnsafe(\'TRUNCATE TABLE "ChatMessage", "Conversation"\');',
    ),
    'admin/sql-lock-list.ts': prismaFixture(
      'await prisma.$executeRawUnsafe(\'LOCK TABLE "User", "WeddingPlan"\');',
    ),
    'admin/sql-drop-list.ts': prismaFixture(
      'await prisma.$executeRawUnsafe(\'DROP TABLE IF EXISTS "Provider", "City"\');',
    ),
    'admin/sql-delete-using-list.ts': prismaFixture(
      'await prisma.$executeRawUnsafe(\'DELETE FROM "ChatMessage" USING "Conversation", "User" WHERE true\');',
    ),
    'admin/sql-dynamic-list.ts': prismaFixture([
      'const tableName = "Conversation";',
      'await prisma.$executeRaw(Prisma.sql`TRUNCATE TABLE "ChatMessage", ${tableName}`);',
    ].join('\n')),
  });
  assertExactRecords(scanOwnershipViolations(options), [
    { file: 'backend/src/admin/sql-truncate-list.ts', model: 'ChatMessage', owner: 'messaging', operation: 'truncate', mode: 'write', source: 'sql', reason: 'foreign-model', count: 1 },
    { file: 'backend/src/admin/sql-truncate-list.ts', model: 'Conversation', owner: 'messaging', operation: 'truncate', mode: 'write', source: 'sql', reason: 'foreign-model', count: 1 },
    { file: 'backend/src/admin/sql-lock-list.ts', model: 'User', owner: 'identity', operation: 'lock', mode: 'read', source: 'sql', reason: 'foreign-model', count: 1 },
    { file: 'backend/src/admin/sql-lock-list.ts', model: 'WeddingPlan', owner: 'planning', operation: 'lock', mode: 'read', source: 'sql', reason: 'foreign-model', count: 1 },
    { file: 'backend/src/admin/sql-drop-list.ts', model: 'Provider', owner: 'marketplace', operation: 'drop', mode: 'write', source: 'sql', reason: 'foreign-model', count: 1 },
    { file: 'backend/src/admin/sql-drop-list.ts', model: 'City', owner: 'catalog', operation: 'drop', mode: 'write', source: 'sql', reason: 'foreign-model', count: 1 },
    { file: 'backend/src/admin/sql-delete-using-list.ts', model: 'ChatMessage', owner: 'messaging', operation: 'delete', mode: 'write', source: 'sql', reason: 'foreign-model', count: 1 },
    { file: 'backend/src/admin/sql-delete-using-list.ts', model: 'Conversation', owner: 'messaging', operation: 'using', mode: 'read', source: 'sql', reason: 'foreign-model', count: 1 },
    { file: 'backend/src/admin/sql-delete-using-list.ts', model: 'User', owner: 'identity', operation: 'using', mode: 'read', source: 'sql', reason: 'foreign-model', count: 1 },
    { file: 'backend/src/admin/sql-dynamic-list.ts', model: 'ChatMessage', owner: 'messaging', operation: 'truncate', mode: 'write', source: 'sql', reason: 'foreign-model', count: 1 },
    { file: 'backend/src/admin/sql-dynamic-list.ts', model: '<dynamic>', owner: null, operation: 'truncate', mode: 'write', source: 'sql', reason: 'unknown-model', count: 1 },
  ]);
});

test('quoted SQL identifiers with controls or annotation text fail atomically before CLI output', () => {
  const hostileModels = [
    'Unknown\nFORGED',
    'Unknown\rFORGED',
    'Unknown\tFORGED',
    'Unknown\u0000FORGED',
    'TOKEN=ownership-output-secret',
    '::error file=C:/private/ownership.ts,line=1::FORGED',
  ];
  const options = fixtureProject({
    'admin/sql-output-injection.ts': prismaFixture(hostileModels.map((model) => (
      `await prisma.$queryRawUnsafe(${JSON.stringify(`SELECT * FROM "${model}"`)});`
    )).join('\n')),
  });
  const scan = scanOwnershipViolations(options);
  for (const model of hostileModels) {
    assert.equal(scan.some((record) => record.model === model), true, JSON.stringify(model));
  }

  const result = captureOwnershipCli({ scan, saved: ownershipBaseline() });
  assert.equal(result.exitCode, 2);
  assert.deepEqual(result.stdout, []);
  assert.deepEqual(result.stderr, ['ERROR - architecture ownership scan failed']);
});

test('ownership CLI renders legitimate additions and increases from fixed fields only', () => {
  const added = violation();
  const addition = captureOwnershipCli({ scan: [added], saved: ownershipBaseline() });
  assert.equal(addition.exitCode, 1);
  assert.deepEqual(addition.stdout, []);
  assert.deepEqual(addition.stderr, [
    'ownership violations added (1 records)',
    'new ownership violation [foreign-model]: backend/src/money/x.ts count=1',
  ]);

  const increased = violation({ count: 2 });
  const increase = captureOwnershipCli({ scan: [increased], saved: ownershipBaseline([added]) });
  assert.equal(increase.exitCode, 1);
  assert.deepEqual(increase.stderr, [
    'ownership violations added (1 records)',
    'increased ownership violation [foreign-model]: backend/src/money/x.ts count=2',
  ]);

  assert.equal(captureOwnershipCli({ scan: [], saved: ownershipBaseline([added]) }).exitCode, 0);
  assert.equal(captureOwnershipCli({ scan: [added], saved: ownershipBaseline([increased]) }).exitCode, 0);

  const unknownDebt = violation({
    owner: null,
    model: 'UnknownTable',
    operation: 'select',
    mode: 'read',
    source: 'sql',
    reason: 'unknown-model',
  });
  const unknown = captureOwnershipCli({ scan: [unknownDebt], saved: ownershipBaseline() });
  assert.equal(unknown.exitCode, 1);
  assert.deepEqual(unknown.stderr, [
    'ownership violations added (1 records)',
    'new ownership violation [unknown-model]: backend/src/money/x.ts count=1',
  ]);
  assert.equal(unknown.stderr.join('\n').includes('UnknownTable'), false);

  const dynamicDebt = violation({
    owner: null,
    model: '<dynamic>',
    operation: 'select',
    mode: 'read',
    source: 'sql',
    reason: 'unknown-model',
  });
  assert.equal(captureOwnershipCli({
    scan: [dynamicDebt],
    saved: ownershipBaseline(),
  }).exitCode, 1);

  const otherUnknownDebt = [
    violation({
      owner: null,
      model: '<dynamic>',
      operation: 'dynamic',
      mode: 'unknown',
      source: 'delegate',
      reason: 'unknown-model',
    }),
    violation({
      owner: null,
      model: '<dynamic>',
      operation: 'dynamic',
      mode: 'unknown',
      source: 'sql',
      reason: 'unknown-operation',
    }),
  ].sort((left, right) => (left.key < right.key ? -1 : left.key > right.key ? 1 : 0));
  assert.equal(captureOwnershipCli({
    scan: otherUnknownDebt,
    saved: ownershipBaseline(),
  }).exitCode, 1);
});

test('ownership CLI rejects malformed scan records atomically without reflecting their fields', () => {
  const safe = violation();
  const wrongKey = violation({ model: 'UnknownModel', owner: null, reason: 'unknown-model' });
  wrongKey.key = safe.key;
  const invalidRecords: unknown[] = [
    { ...safe, extra: 'TOKEN=extra-field' },
    Object.fromEntries(Object.entries(safe).filter(([key]) => key !== 'reason')),
    { ...safe, file: 'backend/src/money/forged\nTOKEN=file.ts' },
    { ...safe, file: 'C:/private/ownership.ts' },
    { ...safe, context: 'TOKEN=context' },
    { ...safe, owner: 'file://private/owner' },
    { ...safe, model: 'Unknown\nFORGED', owner: null, reason: 'unknown-model' },
    { ...safe, model: 'TOKEN=model', owner: null, reason: 'unknown-model' },
    { ...safe, model: 'https://example.test/model', owner: null, reason: 'unknown-model' },
    { ...safe, operation: 'update\rFORGED' },
    { ...safe, operation: 'TOKEN=operation' },
    { ...safe, operation: 'findUnique', source: 'sql' },
    { ...safe, mode: 'TOKEN=mode' },
    { ...safe, source: 'TOKEN=source' },
    { ...safe, reason: 'TOKEN=reason' },
    { ...safe, reason: 'unknown-relation-shape' },
    { ...safe, count: 0 },
    { ...safe, count: Number.MAX_SAFE_INTEGER + 1 },
    { ...safe, count: 1n },
    { ...safe, model: Symbol('TOKEN=model') },
    wrongKey,
  ];

  for (const invalid of invalidRecords) {
    const result = captureOwnershipCli({ scan: [safe, invalid], saved: ownershipBaseline() });
    assert.equal(result.exitCode, 2);
    assert.deepEqual(result.stdout, []);
    assert.deepEqual(result.stderr, ['ERROR - architecture ownership scan failed']);
  }
});

test('ownership CLI rejects duplicate, sparse, oversized, inherited, accessor, and proxy scan data', () => {
  const safe = violation();
  let accessorInvoked = false;
  const accessorRecord = { ...safe } as Record<string, unknown>;
  Object.defineProperty(accessorRecord, 'model', {
    enumerable: true,
    get() {
      accessorInvoked = true;
      throw new Error('TOKEN=record-accessor');
    },
  });
  const sparse: unknown[] = [];
  sparse.length = 3;
  sparse[2] = safe;
  const oversized = new Array(10_001).fill(safe);
  const inherited = Object.assign(Object.create({ TOKEN: 'inherited' }), safe);
  const proxy = new Proxy({ ...safe }, {
    get() { throw new Error('TOKEN=proxy-get'); },
  });
  const arrayProxy = new Proxy([safe], {
    get() { throw new Error('TOKEN=array-proxy-get'); },
  });
  const arraySubclass = new (class extends Array<OwnershipRecord> {})();
  arraySubclass.push(safe);
  const arrayWithExtra = [safe] as OwnershipRecord[] & { TOKEN?: string };
  arrayWithExtra.TOKEN = 'extra';

  for (const scan of [
    {},
    [safe, safe],
    sparse,
    oversized,
    [inherited],
    [accessorRecord],
    [proxy],
    arrayProxy,
    arraySubclass,
    arrayWithExtra,
  ]) {
    const result = captureOwnershipCli({ scan, saved: ownershipBaseline() });
    assert.equal(result.exitCode, 2);
    assert.deepEqual(result.stdout, []);
    assert.deepEqual(result.stderr, ['ERROR - architecture ownership scan failed']);
  }
  assert.equal(accessorInvoked, false);
});

test('ownership CLI validates hostile baselines atomically before comparison', () => {
  const safe = violation();
  let accessorInvoked = false;
  let recordAccessorInvoked = false;
  const accessorBaseline = ownershipBaseline([safe]) as Record<string, unknown>;
  Object.defineProperty(accessorBaseline, 'violations', {
    enumerable: true,
    get() {
      accessorInvoked = true;
      throw new Error('TOKEN=baseline-accessor');
    },
  });
  const sparse: unknown[] = [];
  sparse.length = 2;
  sparse[1] = safe;
  const oversized = new Array(10_001).fill(safe);
  const recordAccessor = { ...safe } as Record<string, unknown>;
  Object.defineProperty(recordAccessor, 'model', {
    enumerable: true,
    get() {
      recordAccessorInvoked = true;
      throw new Error('TOKEN=baseline-record-accessor');
    },
  });
  const inheritedRecord = Object.assign(Object.create({ TOKEN: 'record-inherited' }), safe);
  const proxyRecord = new Proxy({ ...safe }, {
    get() { throw new Error('TOKEN=baseline-record-proxy-get'); },
  });
  const violationsProxy = new Proxy([safe], {
    get() { throw new Error('TOKEN=baseline-array-proxy-get'); },
  });
  const proxy = new Proxy(ownershipBaseline([safe]), {
    get() { throw new Error('TOKEN=baseline-proxy-get'); },
  });
  const invalidBaselines: unknown[] = [
    { ...ownershipBaseline([safe]), extra: 'TOKEN=extra' },
    { ...ownershipBaseline([safe]), schemaVersion: 1n },
    { ...ownershipBaseline([safe]), sourceRevision: Symbol('TOKEN=revision') },
    { ...ownershipBaseline([safe]), sourceRevision: 'TOKEN=revision' },
    { ...ownershipBaseline(), violations: [safe, safe] },
    { ...ownershipBaseline(), violations: sparse },
    { ...ownershipBaseline(), violations: oversized },
    { ...ownershipBaseline(), violations: [safe, { ...safe, count: 1n }] },
    { ...ownershipBaseline(), violations: [safe, { ...safe, model: Symbol('TOKEN=model') }] },
    { ...ownershipBaseline(), violations: [recordAccessor] },
    { ...ownershipBaseline(), violations: [inheritedRecord] },
    { ...ownershipBaseline(), violations: [proxyRecord] },
    { ...ownershipBaseline(), violations: violationsProxy },
    Object.assign(Object.create({ TOKEN: 'inherited' }), ownershipBaseline([safe])),
    accessorBaseline,
    proxy,
  ];
  for (const saved of invalidBaselines) {
    const result = captureOwnershipCli({ scan: [safe], saved });
    assert.equal(result.exitCode, 2);
    assert.deepEqual(result.stdout, []);
    assert.deepEqual(result.stderr, ['ERROR - architecture ownership scan failed']);
  }
  assert.equal(accessorInvoked, false);
  assert.equal(recordAccessorInvoked, false);
});

test('ownership baseline writer validates atomically and preserves the canonical shape', () => {
  const safe = violation();
  let written: unknown;
  const valid = captureOwnershipCli({
    argv: ['--write-baseline'],
    scan: [safe],
    writeBaseline: (value) => { written = value; },
  });
  assert.equal(valid.exitCode, 0);
  assert.deepEqual(written, ownershipBaseline([safe]));

  let invalidWriteCalled = false;
  const invalid = captureOwnershipCli({
    argv: ['--write-baseline'],
    scan: [safe, { ...safe, model: 'FORGED\nTOKEN=x' }],
    writeBaseline: () => { invalidWriteCalled = true; },
  });
  assert.equal(invalid.exitCode, 2);
  assert.equal(invalidWriteCalled, false);
  assert.deepEqual(invalid.stdout, []);
  assert.deepEqual(invalid.stderr, ['ERROR - architecture ownership scan failed']);
});

test('baseline comparison is counted and CLI returns 0, 1, and 2', () => {
  const record: OwnershipRecord = {
    key: 'backend/src/money/x.ts|finance|planning|WeddingPlan|update|write|delegate|foreign-model',
    file: 'backend/src/money/x.ts', context: 'finance', owner: 'planning', model: 'WeddingPlan',
    operation: 'update', mode: 'write', source: 'delegate', reason: 'foreign-model', count: 1,
  };
  assert.deepEqual(compareWithBaseline([record], [record]), { ok: true, additions: [] });
  assert.deepEqual(compareWithBaseline([{ ...record, count: 2 }], [record]), {
    ok: false, additions: [{ ...record, count: 2 }],
  });

  const output: string[] = [];
  const dependencies = {
    argv: ['--check'],
    scan: () => [record],
    readBaseline: () => ({
      schemaVersion: 1,
      sourceRevision: 'feafe3db0053d6c66d5f46b56ff9a512861dfbad',
      violations: [record],
    }),
    stdout: (message: string) => output.push(message),
    stderr: (message: string) => output.push(message),
  };
  assert.equal(runCli(dependencies), 0);
  assert.equal(runCli({ ...dependencies, readBaseline: () => ({
    schemaVersion: 1,
    sourceRevision: 'feafe3db0053d6c66d5f46b56ff9a512861dfbad',
    violations: [],
  }) }), 1);
  assert.equal(runCli({ ...dependencies, argv: ['--wat'] }), 2);
});

test('ownership CLI never reflects scanner exceptions containing absolute paths', () => {
  const failures = [
    'scan failed [/srv/private/ownership-posix.ts',
    'scan failed "/opt/private/ownership-opt.ts"',
    "scan failed='/tmp/private/ownership-tmp.ts'",
    'scan failed (/workspace/aarast/backend/ownership-repo.ts)',
    'scan failed at C:\\private\\ownership-drive.ts',
    'scan failed =D:/private/ownership-forward-drive.ts',
    'scan failed {\\\\ownership-server\\private\\ownership-unc.ts}',
    'scan failed [\\\\?\\C:\\private\\ownership-extended-drive.ts]',
    'scan failed "\\\\?\\UNC\\ownership-server\\private\\ownership-extended-unc.ts"',
  ];
  for (const [index, failure] of failures.entries()) {
    const output: string[] = [];
    const exitCode = runCli({
      argv: ['--check'],
      scan: () => { throw new Error(`${failure}${index % 2 ? '\n' : '\r\n'}stack detail`); },
      readBaseline: () => ({ schemaVersion: 1, sourceRevision: '', violations: [] }),
      stdout: (message: string) => output.push(message),
      stderr: (message: string) => output.push(message),
    });
    assert.equal(exitCode, 2);
    assert.deepEqual(output, ['ERROR - architecture ownership scan failed']);
  }

  const urlOutput: string[] = [];
  assert.equal(runCli({
    argv: ['--check'],
    scan: () => { throw new Error('scan failed at https://example.test/docs/path\nstack detail'); },
    readBaseline: () => ({ schemaVersion: 1, sourceRevision: '', violations: [] }),
    stdout: (message: string) => urlOutput.push(message),
    stderr: (message: string) => urlOutput.push(message),
  }), 2);
  assert.deepEqual(urlOutput, ['ERROR - architecture ownership scan failed']);
});

test('ownership CLI never reflects file, web, malformed URL, secret, or sentinel text', () => {
  const reflectedInputs = [
    'file:///srv/private/ownership-file-posix.ts',
    'file://ownership-server/private/ownership-file-unc.ts',
    'file://ownership-server/share/private/ownership-file-share.ts',
    'file:///C:/private/ownership-file-drive.ts',
    'file://localhost/C:/private/ownership-file-localhost.ts',
    'file:///%5C%5C%3F%5CC%3A%5Cprivate%5Cownership-file-extended-drive.ts',
    'file:///%5C%5C%3F%5CUNC%5Cownership-server%5Cshare%5Cownership-file-extended-unc.ts',
    'https://example.test/docs/C:/safe-guide',
    'http://example.test/docs/ordinary-guide',
    'http:/malformed.example/private/ownership-malformed.ts',
    'https:////ownership-server/private/ownership-malformed-unc.ts',
    '\u0000architecture-web-url-0-attacker-sentinel\u0000',
    'TOKEN=ownership-attacker-secret',
  ];
  for (const reflectedInput of reflectedInputs) {
    const output: string[] = [];
    assert.equal(runCli({
      argv: ['--check'],
      scan: () => { throw new Error(`scan failed [${reflectedInput}\r\nstack detail`); },
      readBaseline: () => ({ schemaVersion: 1, sourceRevision: '', violations: [] }),
      stdout: (message: string) => output.push(message),
      stderr: (message: string) => output.push(message),
    }), 2);
    assert.deepEqual(output, ['ERROR - architecture ownership scan failed']);
  }
});

test('baseline validation rejects invalid fields and sensitive strings with sanitized errors', () => {
  const base: OwnershipRecord = {
    file: 'backend/src/money/x.ts', context: 'finance', owner: 'planning', model: 'WeddingPlan',
    operation: 'update', mode: 'write', source: 'delegate', reason: 'foreign-model', count: 1,
  };
  base.key = ownershipKey(base);
  const withField = (field: keyof OwnershipRecord, value: unknown) => {
    const record = { ...base, [field]: value } as OwnershipRecord;
    record.key = ownershipKey(record);
    return record;
  };
  const invalid = [
    withField('operation', '/tmp/ownership-leak'),
    withField('operation', 'C:\\ownership-leak'),
    withField('operation', 'https://example.test/private'),
    withField('operation', 'https://user:password@example.test/private'),
    withField('operation', 'PASSWORD=ownership-credential'),
    withField('operation', 'TOKEN=ownership-secret'),
    withField('context', 'not-a-context'),
    withField('owner', 'not-an-owner'),
    withField('model', '../WeddingPlan'),
    withField('mode', 'sometimes'),
    withField('source', 'reflection'),
    withField('reason', 'allowlisted'),
    { ...base, note: { '/tmp/ownership-key': 'safe' } } as OwnershipRecord,
  ];

  for (const record of invalid) {
    const output: string[] = [];
    const exitCode = runCli({
      argv: ['--check'],
      scan: () => [record],
      readBaseline: () => ({
        schemaVersion: 1,
        sourceRevision: 'feafe3db0053d6c66d5f46b56ff9a512861dfbad',
        violations: [record],
      }),
      stdout: (message: string) => output.push(message),
      stderr: (message: string) => output.push(message),
    });
    assert.equal(exitCode, 2, `baseline value was accepted: ${JSON.stringify(record)}`);
    assert.deepEqual(output, ['ERROR - architecture ownership scan failed']);
  }
});

test('persisted baseline is canonical, sorted, unique, counted, and contains no secrets', () => {
  const baselineText = readFileSync(
    path.join(backendRoot, 'architecture', 'ownership-baseline.json'),
    'utf8',
  );
  const baseline = JSON.parse(baselineText) as {
    schemaVersion: number;
    sourceRevision: string;
    violations: Required<OwnershipRecord>[];
  };
  assert.equal(baseline.schemaVersion, 1);
  assert.equal(baseline.sourceRevision, 'feafe3db0053d6c66d5f46b56ff9a512861dfbad');
  const keys = baseline.violations.map((record) => record.key);
  assert.deepEqual(keys, [...keys].sort());
  assert.equal(new Set(keys).size, keys.length);
  for (const record of baseline.violations) {
    assert.equal(record.key, [
      record.file, record.context, record.owner ?? '', record.model, record.operation,
      record.mode, record.source, record.reason,
    ].join('|'));
    assert.match(record.file, /^backend\/src\/.+\.ts$/);
    assert.equal(path.posix.isAbsolute(record.file), false);
    assert.equal(path.win32.isAbsolute(record.file), false);
    assert.equal(Number.isInteger(record.count) && record.count > 0, true);
  }
  assert.doesNotMatch(
    baselineText,
    /DATABASE_URL\s*=|JWT_SECRET\s*=|PASSWORD\s*=|SECRET\s*=|TOKEN\s*=|BEGIN (?:RSA |OPENSSH )?PRIVATE KEY|postgres(?:ql)?:\/\/|D:\\\\|[A-Za-z]:\\\\/i,
  );
});

test('the real wrapper rejects unknown arguments without absolute paths or stack traces', () => {
  const cli = path.join(backendRoot, 'scripts', 'architecture', 'ownership-scan.cjs');
  const result = spawnSync(process.execPath, [cli, '--wat'], {
    cwd: backendRoot,
    encoding: 'utf8',
  });
  assert.equal(result.status, 2, result.stderr || result.stdout);
  assert.doesNotMatch(result.stderr, new RegExp(repoRoot.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i'));
  assert.doesNotMatch(result.stderr, /\n\s+at\s/);
});

test('the real ownership CLI never reflects scanner failures without repository fixtures', () => {
  const root = mkdtempSync(path.join(tmpdir(), 'aarast-ownership-cli-error-'));
  fixtureRoots.push(root);
  const preload = path.join(root, 'throwing-program.cjs');
  const failureMessage = [
    'ownership-attacker-message',
    'https://example.test/docs/C:/safe-guide',
    'file:///srv/private/ownership-real.ts',
    'http:/malformed.example/private/ownership-malformed.ts',
    '\u0000architecture-web-url-0-attacker-sentinel\u0000',
    'TOKEN=ownership-real-secret',
    '\nstack detail',
  ].join(' ');
  writeFileSync(preload, [
    "const Module = require('node:module');",
    'const originalLoad = Module._load;',
    'Module._load = function patchedLoad(request, parent, isMain) {',
    '  const loaded = originalLoad.call(this, request, parent, isMain);',
    "  if (request !== 'typescript') return loaded;",
    `  return { ...loaded, createProgram() { throw new Error(${JSON.stringify(failureMessage)}); } };`,
    '};',
  ].join('\n'), 'utf8');

  const cli = path.join(backendRoot, 'scripts', 'architecture', 'ownership-scan.cjs');
  const result = spawnSync(process.execPath, ['-r', preload, cli, '--check'], {
    cwd: backendRoot,
    encoding: 'utf8',
  });
  const output = `${result.stdout}\n${result.stderr}`;
  assert.equal(result.status, 2, output);
  assert.equal(result.stderr.trim(), 'ERROR - architecture ownership scan failed');
  assert.doesNotMatch(output, /ownership-attacker-message|example\.test|ownership-real|file:|malformed|attacker-sentinel|ownership-real-secret|stack detail/i);
  assert.doesNotMatch(output, /\n\s*at\s+/);
});
