import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";
import {
  ARABIC_FOLD_FROM,
  ARABIC_FOLD_TO,
} from "../src/shared-kernel/text/arabic-search";
import { readLivePrismaSchema } from "./support/live-prisma-schema";

// RA-BE-180 and RA-BE-181: money, ratings and ids are held by the database
// itself, and the slow searches have the indexes they need. Every migration
// below first checks (or fixes) the rows already there, in the same file, so
// a database that holds a bad row stops the deploy with a message instead of
// a bare constraint error, and no money row is ever deleted by it.

const root = process.cwd();
const constraints = "20261125120000_data_integrity_constraints";
const indexes = "20261125130000_search_and_invite_indexes";
const read = (path: string) => readFileSync(join(root, path), "utf8");
const migration = (name: string) =>
  read(`prisma/migrations/${name}/migration.sql`);
const model = (schema: string, name: string) =>
  schema.match(new RegExp(`model ${name} \\{[\\s\\S]*?\\n\\}`))?.[0] ?? "";

const MONEY_TABLES = [
  "FundingSource",
  "LoanRepayment",
  "QuoteOffer",
  "ProviderService",
  "QuoteRequest",
  "ProviderReview",
];

test("each money, budget and rating column has its CHECK, added after its own verification", () => {
  const sql = migration(constraints);
  const expected: Array<[string, RegExp]> = [
    ["FundingSource_amount_positive", /"amount" > 0/],
    ["LoanRepayment_amount_positive", /"amount" > 0/],
    ["QuoteOffer_amount_positive", /"amount" > 0/],
    ["ProviderService_basePrice_nonnegative", /"basePrice" >= 0/],
    ["QuoteRequest_budget_range_check", /"budgetMin" <= "budgetMax"/],
    ["ProviderReview_rating_range", /"rating" BETWEEN 1 AND 5/],
  ];
  for (const [name, predicate] of expected) {
    const added = sql.indexOf(`ADD CONSTRAINT "${name}"`);
    assert.ok(added > 0, `${name} is added`);
    assert.match(sql.slice(added, added + 400), predicate, name);
  }
  assert.match(sql, /"budgetMin" >= 0 AND "budgetMax" >= 0/);

  // The check of the existing rows comes before the first constraint, and
  // it stops the migration with its own words.
  const verified = sql.indexOf("RA-BE-180");
  const firstConstraint = sql.indexOf("ADD CONSTRAINT");
  assert.ok(verified >= 0 && verified < firstConstraint);
  assert.match(sql, /RAISE EXCEPTION/);
  assert.match(sql, /no row is deleted or changed/i);
});

test("the migration never deletes or rewrites a money row to make a CHECK pass", () => {
  const sql = migration(constraints).replace(/--[^\n]*/g, "");
  for (const table of MONEY_TABLES) {
    assert.doesNotMatch(
      sql,
      new RegExp(`DELETE\\s+FROM\\s+"${table}"`, "i"),
      `${table} rows are not deleted`,
    );
  }
  // The one data fix on a money table puts a reversed budget range the right
  // way round; both figures stay, nothing is lost.
  const updates = [...sql.matchAll(/UPDATE\s+"(\w+)"\s+SET\s+([^;]*)/gi)].filter(
    ([, table]) => MONEY_TABLES.includes(table),
  );
  assert.equal(updates.length, 1);
  assert.equal(updates[0][1], "QuoteRequest");
  assert.match(updates[0][2], /"budgetMin" = "budgetMax"/);
  assert.match(updates[0][2], /"budgetMax" = "budgetMin"/);
});

test("the ids that are real references become foreign keys, with the history kept", () => {
  const sql = migration(constraints);
  const keys: Array<[string, string]> = [
    ["GuestInvitationSend_weddingPlanId_fkey", "ON DELETE RESTRICT"],
    ["GuestInvitationSend_planEventId_fkey", "ON DELETE CASCADE"],
    ["GuestInvitationSend_createdByUserId_fkey", "ON DELETE SET NULL"],
    ["WeddingTask_linkedBudgetCategoryId_fkey", "ON DELETE SET NULL"],
    ["WeddingTask_linkedCostId_fkey", "ON DELETE SET NULL"],
    ["WeddingTask_linkedScheduleId_fkey", "ON DELETE SET NULL"],
    ["Booking_requestedByUserId_fkey", "ON DELETE SET NULL"],
  ];
  for (const [name, action] of keys) {
    const at = sql.indexOf(`ADD CONSTRAINT "${name}"`);
    assert.ok(at > 0, `${name} is added`);
    assert.ok(
      sql.slice(at, sql.indexOf(";", at)).includes(action),
      `${name} ${action}`,
    );
  }
  // A reference to something that is gone is cleared (or, for a send of an
  // event that no longer exists, removed as the cascade would) before the key.
  for (const column of [
    "linkedBudgetCategoryId",
    "linkedCostId",
    "linkedScheduleId",
  ]) {
    assert.match(
      sql,
      new RegExp(`UPDATE "WeddingTask"[\\s\\S]*?SET "${column}" = NULL`),
      column,
    );
  }
  assert.match(sql, /UPDATE "Booking"\s+SET "requestedByUserId" = NULL/);
  assert.match(sql, /UPDATE "GuestInvitationSend"[\s\S]*?"createdByUserId" = NULL/);
  assert.match(sql, /ALTER COLUMN "requestedByUserId" DROP NOT NULL/);
});

test("the schema declares the same references", () => {
  const schema = readLivePrismaSchema();
  const send = model(schema, "GuestInvitationSend");
  assert.match(send, /weddingPlan\s+WeddingPlan\s+@relation\([^)]*onDelete: Restrict/);
  assert.match(send, /planEvent\s+PlanEvent\?\s+@relation\([^)]*onDelete: Cascade/);
  assert.match(send, /createdByUser\s+User\?\s+@relation\([^)]*onDelete: SetNull/);
  const task = model(schema, "WeddingTask");
  assert.match(task, /linkedBudgetCategory\s+BudgetCategory\?\s+@relation\([^)]*onDelete: SetNull/);
  assert.match(task, /linkedCost\s+WeddingCost\?\s+@relation\([^)]*onDelete: SetNull/);
  assert.match(task, /linkedSchedule\s+PaymentSchedule\?\s+@relation\([^)]*onDelete: SetNull/);
  const booking = model(schema, "Booking");
  assert.match(booking, /requestedByUserId\s+String\?/);
  assert.match(booking, /requestedByUser\s+User\?\s+@relation\([^)]*onDelete: SetNull/);
});

test("the search and invitation indexes: trigram on the folded text, a partial index on the open phone", () => {
  const sql = migration(indexes);
  assert.match(sql, /CREATE EXTENSION IF NOT EXISTS "pg_trgm"/);
  assert.match(sql, /IMMUTABLE/);
  assert.equal((sql.match(/USING gin/gi) ?? []).length, 3);
  assert.equal((sql.match(/gin_trgm_ops/g) ?? []).length, 3);
  assert.match(
    sql,
    /CREATE INDEX "PlanInvite_open_normalizedPhone_idx"\s+ON "PlanInvite"\s*\("normalizedPhone"\)\s+WHERE "inviteeUserId" IS NULL/,
  );
});

test("the folding function in the database folds exactly what the server folds", () => {
  const sql = migration(indexes);
  const literal = (text: string) =>
    text.replace(/\\u([0-9a-f]{4})/gi, (_, hex) =>
      String.fromCharCode(parseInt(hex, 16)),
    );
  const fold = sql.match(
    /translate\(lower\(\$1\),\s*E'([^']*)',\s*E'([^']*)'\)/,
  );
  assert.ok(fold, "the function translates with two literals");
  assert.equal(literal(fold[1]), ARABIC_FOLD_FROM);
  assert.equal(literal(fold[2]), ARABIC_FOLD_TO);
});

test("both migrations are pinned and carry no edit after their pin", () => {
  const pins = JSON.parse(read("architecture/published-migrations.json"))
    .migrations as Record<string, string>;
  for (const name of [constraints, indexes]) {
    assert.equal(
      pins[name],
      createHash("sha256").update(migration(name)).digest("hex"),
      name,
    );
  }
});
