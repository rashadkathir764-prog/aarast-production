#!/usr/bin/env node
'use strict';

const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { PrismaClient } = require('@prisma/client');
const { assertManagedSmokeEnvironment } = require('./smoke-utils');

const migrationPath = join(
  __dirname,
  '..',
  '..',
  'prisma',
  'migrations',
  '20260726030000_enforce_unique_guest_phone',
  'migration.sql',
);

const OLD_INDEX =
  'Guest_weddingPlanId_normalizedName_normalizedPhone_key';
const NEW_INDEX = 'Guest_weddingPlanId_normalizedPhone_key';
const PHONE_MATCH_CONSTRAINT = 'Guest_phone_normalizedPhone_match_check';

function statementCommand(statement) {
  let value = statement.trim();
  while (value.startsWith('--') || value.startsWith('/*')) {
    if (value.startsWith('--')) {
      const newline = value.indexOf('\n');
      value = newline === -1 ? '' : value.slice(newline + 1).trimStart();
      continue;
    }
    const end = value.indexOf('*/');
    value = end === -1 ? '' : value.slice(end + 2).trimStart();
  }
  return value;
}

function splitSqlStatements(source) {
  const statements = [];
  let current = '';
  let dollarTag = null;
  let inSingleQuote = false;
  let inDoubleQuote = false;
  let inLineComment = false;
  let inBlockComment = false;

  for (let index = 0; index < source.length; index += 1) {
    const char = source[index];
    const next = source[index + 1];

    if (inLineComment) {
      current += char;
      if (char === '\n') inLineComment = false;
      continue;
    }
    if (inBlockComment) {
      current += char;
      if (char === '*' && next === '/') {
        current += next;
        index += 1;
        inBlockComment = false;
      }
      continue;
    }
    if (dollarTag) {
      if (source.startsWith(dollarTag, index)) {
        current += dollarTag;
        index += dollarTag.length - 1;
        dollarTag = null;
      } else {
        current += char;
      }
      continue;
    }
    if (inSingleQuote) {
      current += char;
      if (char === "'" && next === "'") {
        current += next;
        index += 1;
      } else if (char === "'") {
        inSingleQuote = false;
      }
      continue;
    }
    if (inDoubleQuote) {
      current += char;
      if (char === '"' && next === '"') {
        current += next;
        index += 1;
      } else if (char === '"') {
        inDoubleQuote = false;
      }
      continue;
    }

    if (char === '-' && next === '-') {
      current += char + next;
      index += 1;
      inLineComment = true;
      continue;
    }
    if (char === '/' && next === '*') {
      current += char + next;
      index += 1;
      inBlockComment = true;
      continue;
    }
    if (char === "'") {
      current += char;
      inSingleQuote = true;
      continue;
    }
    if (char === '"') {
      current += char;
      inDoubleQuote = true;
      continue;
    }
    if (char === '$') {
      const tag = source.slice(index).match(/^\$[A-Za-z_][A-Za-z0-9_]*\$|^\$\$/)?.[0];
      if (tag) {
        current += tag;
        index += tag.length - 1;
        dollarTag = tag;
        continue;
      }
    }
    if (char === ';') {
      if (statementCommand(current)) statements.push(`${current.trim()};`);
      current = '';
      continue;
    }
    current += char;
  }

  if (statementCommand(current)) statements.push(current.trim());
  return statements;
}

async function executeStatements(client, statements, onStatement) {
  for (const statement of statements) {
    await client.$executeRawUnsafe(statement);
    await onStatement?.(statementCommand(statement));
  }
}

async function applyMigration(client, source, onStatement) {
  const statements = splitSqlStatements(source);
  const first = statementCommand(statements[0] ?? '');
  const last = statementCommand(statements.at(-1) ?? '');
  const transactional = /^BEGIN\b/i.test(first);

  if (transactional) {
    assert.match(last, /^COMMIT\b/i, 'transactional migration must end in COMMIT');
    return client.$transaction(
      (tx) => executeStatements(tx, statements.slice(1, -1), onStatement),
      { timeout: 30_000 },
    );
  }

  assert.doesNotMatch(last, /^COMMIT\b/i, 'COMMIT without BEGIN is invalid');
  return executeStatements(client, statements, onStatement);
}

async function resetPreMigrationGuestTable(client) {
  await client.$executeRawUnsafe('DROP TABLE IF EXISTS "Guest" CASCADE;');
  await client.$executeRawUnsafe(`
    CREATE TABLE "Guest" (
      "id" TEXT PRIMARY KEY,
      "weddingPlanId" TEXT NOT NULL,
      "name" TEXT NOT NULL,
      "normalizedName" TEXT NOT NULL,
      "phone" TEXT,
      "normalizedPhone" TEXT
    );
  `);
  await client.$executeRawUnsafe(`
    CREATE UNIQUE INDEX "${OLD_INDEX}"
      ON "Guest"("weddingPlanId", "normalizedName", "normalizedPhone");
  `);
}

async function insertGuest(
  client,
  {
    id,
    planId = 'plan-1',
    name = id,
    phone = null,
    normalizedPhone = null,
  },
) {
  await client.$executeRawUnsafe(
    `
      INSERT INTO "Guest" (
        "id", "weddingPlanId", "name", "normalizedName", "phone", "normalizedPhone"
      )
      VALUES ($1, $2, $3, $4, $5, $6);
    `,
    id,
    planId,
    name,
    name,
    phone,
    normalizedPhone,
  );
}

async function guestPhones(client) {
  const rows = await client.$queryRawUnsafe(`
    SELECT "id", "phone", "normalizedPhone"
    FROM "Guest"
    ORDER BY "id";
  `);
  return new Map(rows.map((row) => [row.id, row]));
}

async function databaseObjects(client) {
  const indexes = await client.$queryRawUnsafe(`
    SELECT indexname
    FROM pg_indexes
    WHERE schemaname = current_schema()
      AND tablename = 'Guest';
  `);
  const constraints = await client.$queryRawUnsafe(`
    SELECT conname
    FROM pg_constraint
    WHERE conrelid = '"Guest"'::regclass;
  `);
  return {
    indexes: new Set(indexes.map((row) => row.indexname)),
    constraints: new Set(constraints.map((row) => row.conname)),
  };
}

async function rejectionFrom(operation) {
  let captured;
  try {
    await operation();
  } catch (error) {
    captured = error;
  }
  assert.ok(captured, 'operation must fail');
  return captured;
}

function assertGenericMigrationFailure(error, forbiddenValues) {
  const message = error instanceof Error ? error.message : String(error);
  assert.match(message, /manual reconciliation required/i);
  for (const forbidden of forbiddenValues) {
    assert.doesNotMatch(message, new RegExp(forbidden.replace(/[+]/g, '\\+')));
  }
}

async function assertCanonicalBackfillAndWriteLock(
  migrationClient,
  raceClient,
  migrationSql,
) {
  await resetPreMigrationGuestTable(migrationClient);
  const fixtures = [
    {
      id: 'arabic-digits',
      phone: '+٩٦٧٧١١٢٣٤٥٠٥',
      normalizedPhone: null,
      expected: '+967711234505',
    },
    {
      id: 'bare-international',
      phone: '2025550126',
      normalizedPhone: 'legacy-bare',
      expected: '2025550126',
    },
    {
      id: 'international-00',
      phone: '00442079460018',
      normalizedPhone: null,
      expected: '+442079460018',
    },
    {
      id: 'international-plus',
      phone: '+12025550125',
      normalizedPhone: null,
      expected: '+12025550125',
    },
    {
      id: 'no-phone-a',
      phone: null,
      normalizedPhone: null,
      expected: null,
    },
    {
      id: 'no-phone-b',
      phone: null,
      normalizedPhone: null,
      expected: null,
    },
    {
      id: 'yemen-00967',
      phone: '00967711234502',
      normalizedPhone: null,
      expected: '+967711234502',
    },
    {
      id: 'yemen-local-10',
      phone: '0711234503',
      normalizedPhone: '711234503',
      expected: '+967711234503',
    },
    {
      id: 'yemen-local-9',
      phone: '711234504',
      normalizedPhone: null,
      expected: '+967711234504',
    },
    {
      id: 'yemen-plus',
      phone: '+967711234501',
      normalizedPhone: 'legacy-yemen',
      expected: '+967711234501',
    },
  ];
  for (const fixture of fixtures) await insertGuest(migrationClient, fixture);

  let raceStarted = false;
  let raceSettled = false;
  let raceWrite;
  await applyMigration(migrationClient, migrationSql, async (statement) => {
    if (!/^LOCK TABLE "Guest" IN ACCESS EXCLUSIVE MODE\b/i.test(statement)) {
      return;
    }
    raceStarted = true;
    raceWrite = insertGuest(raceClient, {
      id: 'race-writer',
      phone: '+49301234567',
      normalizedPhone: '+49301234567',
    }).finally(() => {
      raceSettled = true;
    });
    await new Promise((resolve) => setTimeout(resolve, 250));
    assert.equal(
      raceSettled,
      false,
      'concurrent Guest writes must wait until canonicalization and index swap commit',
    );
  });
  assert.equal(raceStarted, true, 'migration must lock Guest before backfill');
  await raceWrite;

  const stored = await guestPhones(migrationClient);
  for (const fixture of fixtures) {
    assert.equal(
      stored.get(fixture.id)?.normalizedPhone,
      fixture.expected,
      fixture.id,
    );
    assert.equal(stored.get(fixture.id)?.phone, fixture.expected, fixture.id);
  }
  assert.equal(
    [...stored.values()].filter((row) => row.phone === null).length,
    2,
    'multiple guests without a phone remain valid',
  );

  const objects = await databaseObjects(migrationClient);
  assert.equal(objects.indexes.has(OLD_INDEX), false);
  assert.equal(objects.indexes.has(NEW_INDEX), true);
  assert.equal(objects.constraints.has(PHONE_MATCH_CONSTRAINT), true);

  await rejectionFrom(() =>
    insertGuest(migrationClient, {
      id: 'post-migration-missing-normalized',
      phone: '+33142278186',
      normalizedPhone: null,
    }),
  );
}

async function assertDuplicateFailsAtomicallyAndCanRetry(client, migrationSql) {
  await resetPreMigrationGuestTable(client);
  const firstPhone = '+967711234580';
  const secondPhone = '00967711234580';
  await insertGuest(client, {
    id: 'duplicate-a',
    name: 'Duplicate A',
    phone: firstPhone,
    normalizedPhone: 'legacy-a',
  });
  await insertGuest(client, {
    id: 'duplicate-b',
    name: 'Duplicate B',
    phone: secondPhone,
    normalizedPhone: 'legacy-b',
  });

  const error = await rejectionFrom(() => applyMigration(client, migrationSql));
  assertGenericMigrationFailure(error, [firstPhone, secondPhone]);

  let objects = await databaseObjects(client);
  assert.equal(objects.indexes.has(OLD_INDEX), true);
  assert.equal(objects.indexes.has(NEW_INDEX), false);
  const beforeRetry = await guestPhones(client);
  assert.equal(beforeRetry.get('duplicate-a')?.normalizedPhone, 'legacy-a');
  assert.equal(beforeRetry.get('duplicate-b')?.normalizedPhone, 'legacy-b');

  await client.$executeRawUnsafe(
    'DELETE FROM "Guest" WHERE "id" = $1;',
    'duplicate-b',
  );
  await applyMigration(client, migrationSql);
  objects = await databaseObjects(client);
  assert.equal(objects.indexes.has(OLD_INDEX), false);
  assert.equal(objects.indexes.has(NEW_INDEX), true);
}

async function assertInvalidPhoneFailsWithoutDiscardingPii(client, migrationSql) {
  const invalidPhones = ['not-a-phone-711234599', '   '];
  for (const [index, invalidPhone] of invalidPhones.entries()) {
    await resetPreMigrationGuestTable(client);
    const id = `invalid-phone-${index}`;
    await insertGuest(client, {
      id,
      phone: invalidPhone,
      normalizedPhone: null,
    });

    const error = await rejectionFrom(() =>
      applyMigration(client, migrationSql),
    );
    assertGenericMigrationFailure(error, [invalidPhone]);
    const stored = await guestPhones(client);
    assert.equal(stored.get(id)?.phone, invalidPhone);
    assert.equal(stored.get(id)?.normalizedPhone, null);
    const objects = await databaseObjects(client);
    assert.equal(objects.indexes.has(OLD_INDEX), true);
    assert.equal(objects.indexes.has(NEW_INDEX), false);
  }
}

async function assertPartialIndexTopologyCanRetry(client, migrationSql) {
  await resetPreMigrationGuestTable(client);
  await insertGuest(client, {
    id: 'partial-retry',
    phone: '+14155550100',
    normalizedPhone: '+14155550100',
  });
  await client.$executeRawUnsafe(`DROP INDEX "${OLD_INDEX}";`);
  await client.$executeRawUnsafe(`
    CREATE UNIQUE INDEX "${NEW_INDEX}"
      ON "Guest"("weddingPlanId", "normalizedPhone");
  `);

  await applyMigration(client, migrationSql);
  const objects = await databaseObjects(client);
  assert.equal(objects.indexes.has(OLD_INDEX), false);
  assert.equal(objects.indexes.has(NEW_INDEX), true);
  assert.equal(objects.constraints.has(PHONE_MATCH_CONSTRAINT), true);
}

async function main() {
  assertManagedSmokeEnvironment(process.env);
  const migrationSql = readFileSync(migrationPath, 'utf8');
  const migrationClient = new PrismaClient();
  const raceClient = new PrismaClient();
  try {
    await assertCanonicalBackfillAndWriteLock(
      migrationClient,
      raceClient,
      migrationSql,
    );
    await assertDuplicateFailsAtomicallyAndCanRetry(
      migrationClient,
      migrationSql,
    );
    await assertInvalidPhoneFailsWithoutDiscardingPii(
      migrationClient,
      migrationSql,
    );
    await assertPartialIndexTopologyCanRetry(migrationClient, migrationSql);

    const statements = splitSqlStatements(migrationSql);
    assert.match(statementCommand(statements[0] ?? ''), /^BEGIN\b/i);
    assert.match(statementCommand(statements.at(-1) ?? ''), /^COMMIT\b/i);
    console.log(
      'PASS - guest phone migration canonicalizes historical phones, fails closed without PII, blocks race writes, and retries atomically.',
    );
  } finally {
    await Promise.all([
      migrationClient.$disconnect(),
      raceClient.$disconnect(),
    ]);
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
});
