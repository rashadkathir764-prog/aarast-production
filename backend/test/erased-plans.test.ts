import "reflect-metadata";

import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";
import { ConflictException } from "@nestjs/common";
import { PlanErasureService } from "../src/modules/planning/infrastructure/plan-erasure.service";
import { ERASED_PLAN_LIST_DAYS } from "../src/modules/planning/infrastructure/wedding-plan.repository";
import { PlanDeletionService } from "../src/wedding-plans/plan-deletion.service";
import { PlanDeletionPurgeScheduler } from "../src/modules/identity/internal/profile/plan-deletion-purge.scheduler";

// RA-OP-32 for plans: the backups keep deleted data up to 90 days, and a
// restore brought a deleted plan back with nothing to erase it again. The
// erasure of a plan lists its id; the restore script puts the list back and
// marks those plans due; the server never takes such a plan back; and the
// list forgets an id after 120 days.

const NOW = new Date("2026-11-25T09:00:00.000Z");
const hostDir = join(__dirname, "..", "..", "deploy", "aws", "host");

test("RA-OP-32: erasing plans lists their ids, after the plans are gone", async () => {
  const calls: Array<[string, any]> = [];
  const delegate = (name: string) =>
    new Proxy({}, {
      get: (_target, method: string) => async (args: unknown) => {
        calls.push([`${name}.${method}`, args]);
        return { count: 0 };
      },
    });
  const tx: any = { planEvent: delegate("planEvent"), weddingPlan: delegate("weddingPlan"), erasedPlan: delegate("erasedPlan") };
  const before = Date.now();
  await new PlanErasureService().deletePlansInTransaction(tx, ["plan-1", "plan-2"]);
  await new PlanErasureService().deletePlansInTransaction(tx, []);
  assert.deepEqual(calls.map(([name]) => name), [
    "planEvent.deleteMany",
    "weddingPlan.deleteMany",
    "erasedPlan.createMany",
  ]);
  const written = calls[2]![1];
  assert.deepEqual(written.data.map((row: any) => row.weddingPlanId), ["plan-1", "plan-2"]);
  assert.equal(written.skipDuplicates, true);
  assert.ok(written.data[0].erasedAt.getTime() >= before);
});

test("RA-OP-32: a plan a restore brought back cannot be taken back", async () => {
  const plan = { id: "plan-1", deletionRequestedAt: new Date(NOW.getTime() - 60_000) };
  const tx: any = {
    erasedPlan: {
      findUnique: async ({ where }: any) =>
        where.weddingPlanId === "plan-1" ? { weddingPlanId: "plan-1" } : null,
    },
    weddingPlan: {
      update: async () => {
        throw new Error("the plan must stay due");
      },
    },
  };
  const service = new PlanDeletionService(
    { $transaction: async (work: any) => work(tx) } as any,
    {} as any,
    { assertPlanReadableForUserUpdateInTransaction: async () => ({ isOwner: true }), getPlanForUpdate: async () => plan } as any,
    {} as any,
    {} as any,
  );
  (service as any).lockOwnedPlan = async () => plan;
  await assert.rejects(
    () => service.cancel({ id: "owner-1" } as any, "plan-1"),
    (error: unknown) =>
      error instanceof ConflictException &&
      (error.getResponse() as any).code === "PLAN_ERASED",
  );
});

test("RA-OP-32: the list forgets a plan id after 120 days, past every backup", async () => {
  const deletes: any[] = [];
  const client: any = {
    erasedPlan: {
      deleteMany: async ({ where }: any) => {
        deletes.push(where);
        return { count: 4 };
      },
    },
  };
  assert.equal(ERASED_PLAN_LIST_DAYS, 120);
  assert.equal(await new PlanErasureService().removeOldErasedPlans(client, NOW), 4);
  assert.deepEqual(deletes, [
    { erasedAt: { lt: new Date(NOW.getTime() - 120 * 24 * 60 * 60 * 1000) } },
  ]);

  // The hourly plan purge does it, as the account purge does for accounts.
  const forgotten: Date[] = [];
  const scheduler = new PlanDeletionPurgeScheduler({
    purgeDuePlans: async () => ({ erased: 0, failures: [] }),
    forgetOldErasedPlans: async (now: Date) => {
      forgotten.push(now);
      return 1;
    },
  } as any);
  await scheduler.purgeDuePlans();
  assert.equal(forgotten.length, 1);
});

test("RA-OP-32: the restore puts the plans' list back and marks those plans due, in the same transaction as the accounts", () => {
  const script = readFileSync(join(hostDir, "restore.sh"), "utf8");
  const sql = readFileSync(join(hostDir, "reapply-erasures.sql"), "utf8");
  const at = (text: string) => {
    const index = script.indexOf(text);
    assert.ok(index >= 0, text);
    return index;
  };
  const migrated = at("dc run --rm --quiet-pull migrate");
  const copied = at(`in_db "$kept" 'COPY "ErasedPlan" TO STDOUT' | in_db "$db" 'COPY "ErasedPlanIncoming" FROM STDIN'`);
  const reapplied = at('<"$here/reapply-erasures.sql"');
  const started = script.lastIndexOf("dc up -d --quiet-pull backend");
  assert.ok(migrated < copied && copied < reapplied && reapplied < started);
  // A live database from before the list existed has no plans to copy.
  assert.match(script, /kept_has_plans=\$\(in_db "\$kept" "SELECT to_regclass\('public\.\\"ErasedPlan\\"'\) IS NOT NULL"\)/u);
  assert.match(script, /CREATE TABLE "ErasedPlanIncoming"/u);
  // One transaction: both lists join, every listed plan is due now.
  assert.match(sql, /^BEGIN;[\s\S]*COMMIT;\s*$/mu);
  assert.match(sql, /INSERT INTO "ErasedPlan"[\s\S]*ON CONFLICT \("weddingPlanId"\) DO NOTHING/u);
  assert.match(
    sql,
    /UPDATE "WeddingPlan"[\s\S]*"deletionScheduledFor" = CURRENT_TIMESTAMP AT TIME ZONE 'UTC'[\s\S]*WHERE "id" IN \(SELECT "weddingPlanId" FROM "ErasedPlan"\)/u,
  );
  assert.match(sql, /DROP TABLE "ErasedPlanIncoming"/u);
  assert.ok(sql.indexOf('INSERT INTO "ErasedAccount"') < sql.indexOf('INSERT INTO "ErasedPlan"'));
});
