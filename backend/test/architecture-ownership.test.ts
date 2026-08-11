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
      favorite Child?  @relation("Favorite")
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
