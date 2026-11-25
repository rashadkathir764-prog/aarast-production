import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";
import { Prisma } from "@prisma/client";

// RA-BE-180: the payment ledger is append-only, and a session setting
// (`aarast.allow_ledger_purge`) used to switch that off for whoever set it.
// The setting is gone: only the database's eraser deletes a cost's payments,
// for a cost being erased, and the plain ids that name an account are
// references now (SET NULL).

const root = join(__dirname, "..");
const read = (path: string) => readFileSync(join(root, path), "utf8");
const eraser = read("prisma/migrations/20261125150000_ledger_erasure_function/migration.sql");
const references = read("prisma/migrations/20261125151000_people_references/migration.sql");

test("no code, test support or deploy file opens the ledger with a session setting", () => {
  const search = spawnSync(
    "git",
    ["grep", "-l", "allow_ledger_purge", "--", "backend/src", "backend/test/support", "backend/scripts", "deploy"],
    { cwd: join(root, ".."), encoding: "utf8" },
  );
  // git grep answers 1 when nothing matches.
  assert.equal(search.status, 1, search.stdout);
  assert.equal(search.stdout, "");
});

test("the eraser runs as its owner, on a fixed path, for a cost being erased only", () => {
  assert.match(eraser, /CREATE FUNCTION "aarast_erase_cost_ledger"\(erased_cost_id TEXT\)/);
  assert.match(eraser, /SECURITY DEFINER\s+SET search_path = public, pg_temp/);
  assert.match(eraser, /REVOKE ALL ON FUNCTION "aarast_erase_cost_ledger"\(TEXT\) FROM PUBLIC;/);
  for (const due of [
    /plan\."deletionRequestedAt" IS NOT NULL AND plan\."deletionScheduledFor" <= \(now\(\) AT TIME ZONE 'UTC'\)/,
    /owner\."deletionRequestedAt" IS NOT NULL AND owner\."deletionScheduledFor" <= \(now\(\) AT TIME ZONE 'UTC'\)/,
    /holder\."deletionRequestedAt" IS NOT NULL AND holder\."deletionScheduledFor" <= \(now\(\) AT TIME ZONE 'UTC'\)/,
  ]) {
    assert.match(eraser, due);
  }
  assert.match(eraser, /RAISE EXCEPTION 'CostPayment is append-only: cost % is not being erased'/);
});

test("the ledger's trigger takes a delete only from inside the eraser, as its owner", () => {
  const trigger = eraser.slice(eraser.indexOf('CREATE OR REPLACE FUNCTION "aarast_protect_cost_payment_ledger"'));
  assert.doesNotMatch(trigger, /current_setting|allow_ledger_purge/);
  assert.match(trigger, /current_user <> eraser_owner/);
  assert.match(trigger, /'public\.aarast_erase_cost_ledger\(text\)'::regprocedure/);
  assert.match(trigger, /GET DIAGNOSTICS call_stack = PG_CONTEXT/);
  assert.match(trigger, /PL\/pgSQL function aarast_erase_cost_ledger\\\\\(text\\\\\) line \[0-9\]\+ at SQL statement/);
  assert.match(trigger, /IF TG_OP = 'UPDATE' THEN\s+RAISE EXCEPTION 'CostPayment is append-only';/);
});

const PEOPLE_REFERENCES: Array<[string, string, string]> = [
  ["BookingChange", "requestedByUserId", "requestedByUser"],
  ["CostReceipt", "uploadedByUserId", "uploadedByUser"],
  ["ProviderReviewEvent", "actorId", "actor"],
  ["Provider", "verifiedById", "verifiedBy"],
  ["ProviderClaimRequest", "decidedById", "decidedBy"],
  ["ProviderFeaturedPeriod", "endedById", "endedBy"],
  ["PortfolioItem", "reviewedById", "reviewedBy"],
  ["ProviderProfileChange", "decidedById", "decidedBy"],
];

test("each id that names an account is a SET NULL reference, cleared of dead ids first", () => {
  assert.match(references, /ALTER TABLE "BookingChange" ALTER COLUMN "requestedByUserId" DROP NOT NULL;/);
  for (const [model, column, relation] of PEOPLE_REFERENCES) {
    const field = Prisma.dmmf.datamodel.models
      .find((candidate) => candidate.name === model)
      ?.fields.find((candidate) => candidate.name === relation);
    assert.equal(field?.type, "User", `${model}.${relation}`);
    assert.deepEqual(field?.relationFromFields, [column]);
    assert.equal(field?.relationOnDelete, "SetNull", `${model}.${relation}`);
    const cleared = references.indexOf(`UPDATE "${model}"\nSET "${column}" = NULL`);
    const keyed = references.indexOf(`ADD CONSTRAINT "${model}_${column}_fkey"`);
    assert.ok(cleared > 0 && keyed > cleared, `${model}.${column} is cleared before its key`);
    assert.match(
      references.slice(keyed, keyed + 200),
      new RegExp(`FOREIGN KEY \\("${column}"\\) REFERENCES "User"\\("id"\\) ON DELETE SET NULL`),
    );
  }
  assert.doesNotMatch(references, /DELETE FROM/);
});
