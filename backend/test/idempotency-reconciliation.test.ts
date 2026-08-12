import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import {
  reconcileAmbiguousIdempotencyKey,
  type IdempotencyReconciliationInput,
} from "../src/platform/idempotency/idempotency-reconciliation";
import {
  parseReconciliationCommand,
  reconciliationConfirmation,
} from "../src/platform/idempotency/idempotency-reconcile.cli";

interface StoredKey {
  id: string;
  method: string;
  path: string;
  response: unknown;
  completedAt: Date | null;
  expiresAt: Date;
}

function reconciliationStore(row: StoredKey | null) {
  let stored = row ? { ...row } : null;
  const tx = {
    $queryRaw: async () => (stored ? [{ id: stored.id }] : []),
    idempotencyKey: {
      findUnique: async ({ where }: any) =>
        stored?.id === where.id ? { ...stored } : null,
      deleteMany: async ({ where }: any) => {
        const current = stored;
        if (
          current &&
          current.id === where.id &&
          current.completedAt === null &&
          current.expiresAt <= where.expiresAt.lte
        ) {
          stored = null;
          return { count: 1 };
        }
        return { count: 0 };
      },
      updateMany: async ({ where, data }: any) => {
        const current = stored;
        if (
          current &&
          current.id === where.id &&
          current.completedAt === null &&
          current.expiresAt <= where.expiresAt.lte
        ) {
          stored = { ...current, ...data };
          return { count: 1 };
        }
        return { count: 0 };
      },
    },
  };
  return {
    prisma: {
      $transaction: async (operation: (client: typeof tx) => unknown) =>
        operation(tx),
    } as any,
    row: () => stored,
  };
}

const expiredRow = (): StoredKey => ({
  id: "cm1234567890reconcile",
  method: "POST",
  path: "/api/v1/wedding-plans/:weddingPlanId/costs",
  response: null,
  completedAt: null,
  expiresAt: new Date("2026-07-23T00:00:00.000Z"),
});

const target = {
  id: "cm1234567890reconcile",
  expectedMethod: "POST",
  expectedPath: "/api/v1/wedding-plans/:weddingPlanId/costs",
};

test("release removes only an expired ambiguous row after exact target matching", async () => {
  const store = reconciliationStore(expiredRow());
  const result = await reconcileAmbiguousIdempotencyKey(
    store.prisma,
    { ...target, resolution: { outcome: "NO_COMMIT" } },
    new Date("2026-07-24T00:00:00.000Z"),
  );

  assert.deepEqual(result, {
    id: target.id,
    state: "RELEASED_FOR_RETRY",
  });
  assert.equal(store.row(), null);
});

test("completion stores the exact replay envelope without exposing it in the result", async () => {
  const store = reconciliationStore(expiredRow());
  const input: IdempotencyReconciliationInput = {
    ...target,
    resolution: {
      outcome: "COMMITTED",
      response: {
        body: { id: "cost-1", created: true },
        statusCode: 201,
        headers: { location: "/api/v1/costs/cost-1" },
      },
    },
  };
  const now = new Date("2026-07-24T00:00:00.000Z");
  const result = await reconcileAmbiguousIdempotencyKey(
    store.prisma,
    input,
    now,
  );

  assert.deepEqual(result, {
    id: target.id,
    state: "COMPLETED_FOR_REPLAY",
  });
  assert.equal(store.row()?.completedAt?.toISOString(), now.toISOString());
  assert.ok((store.row()?.expiresAt.getTime() ?? 0) > now.getTime());
  assert.deepEqual(store.row()?.response, {
    __aarastIdempotencyResponseV1: true,
    body: { id: "cost-1", created: true },
    statusCode: 201,
    headers: { location: "/api/v1/costs/cost-1" },
  });
});

test("reconciliation refuses active, completed, or mismatched rows", async () => {
  const active = reconciliationStore({
    ...expiredRow(),
    expiresAt: new Date("2026-07-25T00:00:00.000Z"),
  });
  await assert.rejects(
    reconcileAmbiguousIdempotencyKey(
      active.prisma,
      { ...target, resolution: { outcome: "NO_COMMIT" } },
      new Date("2026-07-24T00:00:00.000Z"),
    ),
    /still active/,
  );

  const mismatch = reconciliationStore(expiredRow());
  await assert.rejects(
    reconcileAmbiguousIdempotencyKey(
      mismatch.prisma,
      {
        ...target,
        expectedMethod: "PATCH",
        resolution: { outcome: "NO_COMMIT" },
      },
      new Date("2026-07-24T00:00:00.000Z"),
    ),
    /does not match/,
  );

  const completed = reconciliationStore({
    ...expiredRow(),
    completedAt: new Date("2026-07-23T01:00:00.000Z"),
  });
  await assert.rejects(
    reconcileAmbiguousIdempotencyKey(
      completed.prisma,
      { ...target, resolution: { outcome: "NO_COMMIT" } },
      new Date("2026-07-24T00:00:00.000Z"),
    ),
    /already completed/,
  );
});

test("the production command requires exact confirmation and explicit evidence", () => {
  assert.throws(
    () =>
      parseReconciliationCommand(
        [
          "--action=release",
          `--id=${target.id}`,
          `--expected-method=${target.expectedMethod}`,
          `--expected-path=${target.expectedPath}`,
          "--proof=no-domain-commit",
        ],
        {},
      ),
    /IDEMPOTENCY_RECONCILE_CONFIRM/,
  );

  const command = parseReconciliationCommand(
    [
      "--action=release",
      `--id=${target.id}`,
      `--expected-method=${target.expectedMethod}`,
      `--expected-path=${target.expectedPath}`,
      "--proof=no-domain-commit",
    ],
    {
      IDEMPOTENCY_RECONCILE_CONFIRM: reconciliationConfirmation(target.id),
    },
  );
  assert.deepEqual(command, {
    action: "release",
    id: target.id,
    expectedMethod: target.expectedMethod,
    expectedPath: target.expectedPath,
  });
});

test("inspect is read-only and needs no mutation confirmation", () => {
  assert.deepEqual(parseReconciliationCommand(["--action=list"], {}), {
    action: "list",
  });
  assert.deepEqual(
    parseReconciliationCommand(["--action=inspect", `--id=${target.id}`], {}),
    { action: "inspect", id: target.id },
  );
});
