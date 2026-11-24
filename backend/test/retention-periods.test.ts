import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { removeExpiredAdminAudit } from "../src/modules/backoffice/infrastructure/admin-audit-retention.scheduler";
import { removeExpiredPlanInvites } from "../src/modules/collaboration/infrastructure/plan-invite-retention.scheduler";
import { removeOldReadNotifications } from "../src/modules/notifications/infrastructure/notifications-retention.scheduler";
import { OutboxCleanupScheduler } from "../src/platform/outbox/outbox-cleanup.scheduler";

// RA-BE-179 (Q-45, D124): personal data had no end: invitations that
// expired with a name and a number, read notifications, the back office's
// audit log and the outbox's failed events were never cleaned. Each now has
// the period the privacy page states.

const NOW = new Date("2026-11-25T09:00:00.000Z");
const DAY_MS = 24 * 60 * 60 * 1000;

function recorder(model: string) {
  const deletes: unknown[] = [];
  const client: any = {
    [model]: {
      deleteMany: async ({ where }: any) => {
        deletes.push(where);
        return { count: 3 };
      },
    },
  };
  return { client, deletes };
}

test("RA-BE-179: an invitation never accepted goes 90 days after it expired", async () => {
  const { client, deletes } = recorder("planInvite");
  assert.equal(await removeExpiredPlanInvites(client, NOW), 3);
  assert.deepEqual(deletes, [
    { acceptedAt: null, expiresAt: { lt: new Date(NOW.getTime() - 90 * DAY_MS) } },
  ]);
});

test("RA-BE-179: a notification goes 180 days after it was read; an unread one stays", async () => {
  const { client, deletes } = recorder("notification");
  assert.equal(await removeOldReadNotifications(client, NOW), 3);
  assert.deepEqual(deletes, [{ readAt: { lt: new Date(NOW.getTime() - 180 * DAY_MS) } }]);
});

test("RA-BE-179: the audit log keeps two years, with a day's margin", async () => {
  const { client, deletes } = recorder("adminAuditLog");
  assert.equal(await removeExpiredAdminAudit(client, NOW), 3);
  assert.deepEqual(deletes, [
    { createdAt: { lt: new Date("2024-11-24T09:00:00.000Z") } },
  ]);
});

test("RA-BE-179: a failed outbox event goes 30 days after its last attempt", async () => {
  const deletes: any[] = [];
  const tx: any = {
    $queryRaw: async () => [{ locked: true }],
    outboxEvent: {
      deleteMany: async ({ where }: any) => {
        deletes.push(where);
        return { count: 2 };
      },
    },
  };
  const scheduler = new OutboxCleanupScheduler({
    $transaction: async (work: any) => work(tx),
  } as any);
  const before = Date.now();
  assert.equal(await scheduler.removeProcessedReceipts(), 2);
  const [where] = deletes;
  const failed = where.OR.find((branch: any) => branch.status === "FAILED");
  assert.ok(failed, "failed events are removed");
  const cutoff = failed.updatedAt.lt.getTime();
  assert.ok(cutoff <= Date.now() - 30 * DAY_MS && cutoff >= before - 30 * DAY_MS - 1_000);
  // The processed receipts keep their seven days.
  const processed = where.OR.find((branch: any) => branch.status === "PROCESSED");
  assert.ok(processed.processedAt.lt.getTime() <= Date.now() - 7 * DAY_MS);
});
