import assert from 'node:assert/strict';
import { test } from 'node:test';
import { AdminAuditPhase, Prisma } from '@prisma/client';
import { PrismaAdminAuditLogRepository } from '../src/modules/backoffice/infrastructure/prisma-admin-audit-log.repository';

// RA-AD-09: the list pages actions, not rows, so it is SQL with a
// correlated NOT EXISTS (Prisma's findMany cannot say "an attempt with no
// result"). This test used to pin the findMany call it replaced; it now
// checks what still matters: count and page in one transaction under the
// same condition, every filter a bound parameter. The behaviour itself is
// proved on a real database by admin-web's runtime smoke (one line per
// action across pages).

type Captured = { sql: string; values: unknown[] };

function fakePrisma(total: number, rows: unknown[]) {
  const queries: Captured[] = [];
  let transactions = 0;
  const prisma = {
    $queryRaw: (strings: TemplateStringsArray, ...values: unknown[]) => {
      const composed = Prisma.sql(strings, ...values);
      queries.push({ sql: composed.sql, values: composed.values });
      return Promise.resolve(queries.length === 1 ? [{ total }] : rows);
    },
    $transaction: async (operations: Array<Promise<unknown>>) => {
      transactions++;
      return Promise.all(operations);
    },
  };
  return { prisma, queries, transactions: () => transactions };
}

test('audit list counts and pages actions in one transaction', async () => {
  const selected = [{ id: 'audit-1' }];
  const fake = fakePrisma(3, selected);
  const repository = new PrismaAdminAuditLogRepository(fake.prisma as any);

  const result = await repository.list({
    action: ' APP_ROVE% ', actorUserId: ' admin-1 ', phase: AdminAuditPhase.SUCCEEDED,
    from: '2026-09-01T00:00:00.000Z', to: '2026-09-29T00:00:00.000Z',
  }, 2, 20);

  assert.deepEqual(result, { total: 3, items: selected });
  assert.equal(fake.transactions(), 1);
  const [count, page] = fake.queries;
  const whereOf = (sql: string) => sql.slice(sql.indexOf('WHERE'), sql.indexOf('ORDER BY') === -1 ? undefined : sql.indexOf('ORDER BY')).trim();
  assert.equal(whereOf(count.sql), whereOf(page.sql));
  assert.match(count.sql, /NOT EXISTS/);
  assert.match(page.sql, /ORDER BY log\."createdAt" DESC, log\."id" DESC/);
  assert.match(page.sql, /log\."requestId"/);
  // Every filter is a parameter (once for «not asked», once to compare), the
  // typed pattern letters escaped.
  const twice = (value: unknown) => [value, value];
  assert.deepEqual(count.values, [
    ...twice('%APP\\_ROVE\\%%'),
    ...twice('admin-1'),
    ...twice(AdminAuditPhase.SUCCEEDED),
    ...twice('2026-09-01T00:00:00.000Z'),
    ...twice('2026-09-29T00:00:00.000Z'),
  ]);
  assert.deepEqual(page.values, [...count.values, 20, 20]);
  for (const typed of ['APP_ROVE', 'admin-1', '2026-09-01']) {
    assert.equal(page.sql.includes(typed), false, `${typed} must not be in the SQL text`);
  }
});

test('audit list without filters keeps only the one-line-per-action rule', async () => {
  const fake = fakePrisma(0, []);
  const repository = new PrismaAdminAuditLogRepository(fake.prisma as any);

  assert.deepEqual(await repository.list({}, 1, 40), { total: 0, items: [] });
  assert.deepEqual(fake.queries[0].values, Array(10).fill(null));
  assert.deepEqual(fake.queries[1].values, [...Array(10).fill(null), 40, 0]);
  assert.match(fake.queries[0].sql, /NOT EXISTS/);
});
