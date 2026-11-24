import "reflect-metadata";

import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";
import { ConflictException } from "@nestjs/common";
import {
  ERASED_ACCOUNT_LIST_DAYS,
  removeOldErasedAccounts,
} from "../src/modules/identity/infrastructure/account-erasure.repository";
import { accountDeletionService } from "./support/owner-ports";

// RA-OP-32: the backups keep deleted data up to 90 days, and a restore
// brought erased accounts back with nothing to erase them again. The erasure
// now lists the account's id (account-deletion.test.ts); the restore script
// puts the list back and marks those accounts due; the server never takes
// such an account back; and the list forgets an id after 120 days.

const NOW = new Date("2026-11-25T09:00:00.000Z");
const hostDir = join(__dirname, "..", "..", "deploy", "aws", "host");

test("RA-OP-32: an account a restore brought back cannot be taken back", async () => {
  const requestedAt = new Date("2026-11-25T08:59:00.000Z");
  const tx: any = {
    $queryRaw: async () => [
      {
        id: "u-back",
        role: "USER",
        name: "عائد",
        phone: null,
        persona: null,
        deletionRequestedAt: requestedAt,
        deletionScheduledFor: NOW,
      },
    ],
    erasedAccount: {
      findUnique: async ({ where }: any) =>
        where.userId === "u-back" ? { userId: "u-back" } : null,
    },
    user: {
      update: async () => {
        throw new Error("the account must stay due");
      },
    },
  };
  const service = accountDeletionService({} as any, {} as any);
  await assert.rejects(
    () => service.restoreAccountDeletionInTransaction(tx, "u-back"),
    (error: unknown) =>
      error instanceof ConflictException &&
      (error.getResponse() as any).code === "ACCOUNT_ERASED",
  );
});

test("RA-OP-32: the re-deletion list forgets an id after 120 days, past every backup", async () => {
  const deletes: any[] = [];
  const client: any = {
    erasedAccount: {
      deleteMany: async ({ where }: any) => {
        deletes.push(where);
        return { count: 4 };
      },
    },
  };
  assert.equal(ERASED_ACCOUNT_LIST_DAYS, 120);
  assert.equal(await removeOldErasedAccounts(client, NOW), 4);
  assert.deepEqual(deletes, [
    { erasedAt: { lt: new Date(NOW.getTime() - 120 * 24 * 60 * 60 * 1000) } },
  ]);
});

test("RA-OP-32: the restore puts the list back and marks those accounts due before the backend starts", () => {
  const script = readFileSync(join(hostDir, "restore.sh"), "utf8");
  const sql = readFileSync(join(hostDir, "reapply-erasures.sql"), "utf8");
  const at = (text: string) => {
    const index = script.indexOf(text);
    assert.ok(index >= 0, text);
    return index;
  };
  const swapped = at('ALTER DATABASE \\"$incoming\\" RENAME TO \\"$db\\"');
  const migrated = at("dc run --rm --quiet-pull migrate");
  const copied = at(`in_db "$kept" 'COPY "ErasedAccount" TO STDOUT' | in_db "$db" 'COPY "ErasedAccountIncoming" FROM STDIN'`);
  const reapplied = at('<"$here/reapply-erasures.sql"');
  const started = script.lastIndexOf("dc up -d --quiet-pull backend");
  assert.ok(swapped < migrated && migrated < copied && copied < reapplied && reapplied < started);
  // A failure leaves the backend stopped and says how to undo.
  assert.match(script, /could not be marked again; the backend is not started/u);
  // One transaction: the list joins, every listed account is due now.
  assert.match(sql, /^BEGIN;[\s\S]*COMMIT;\s*$/mu);
  assert.match(sql, /INSERT INTO "ErasedAccount"[\s\S]*ON CONFLICT \("userId"\) DO NOTHING/u);
  assert.match(
    sql,
    /UPDATE "User"[\s\S]*"deletionScheduledFor" = CURRENT_TIMESTAMP AT TIME ZONE 'UTC'[\s\S]*WHERE "id" IN \(SELECT "userId" FROM "ErasedAccount"\)/u,
  );
  assert.match(sql, /DROP TABLE "ErasedAccountIncoming"/u);
});
