import "reflect-metadata";

import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";
import { BadRequestException } from "@nestjs/common";
import { Prisma } from "@prisma/client";
import { UsersController } from "../src/modules/identity/api/users.controller";
import {
  UsersService,
  accountDeletionReceiptHash,
} from "../src/modules/identity/internal/profile/users.service";
import { usersService } from "./support/owner-ports";

test("DELETE /users/me rejects a missing client request id before deletion", () => {
  let calls = 0;
  const controller = new UsersController({
    deleteMe: async () => {
      calls += 1;
      return { deleted: true };
    },
  } as never);

  assert.throws(
    () => controller.deleteMe({ id: "user-a" } as never, undefined),
    BadRequestException,
  );
  assert.equal(calls, 0);
});

test("DELETE /users/me forwards the validated client request id", async () => {
  let forwarded: unknown;
  const controller = new UsersController({
    deleteMe: async (_user: unknown, requestId: string) => {
      forwarded = requestId;
      return { deleted: true };
    },
  } as never);

  assert.deepEqual(
    await controller.deleteMe(
      { id: "user-a" } as never,
      "account-delete-request-1",
    ),
    { deleted: true },
  );
  assert.equal(forwarded, "account-delete-request-1");
});

test("HTTP smoke account cleanup always supplies a stable deletion request id", () => {
  for (const fileName of [
    "financial-ledger-concurrency-smoke.js",
    "money-apis-smoke.js",
    "money-budget-smoke.js",
    "quote-stability-smoke.js",
  ]) {
    const source = readFileSync(
      join(process.cwd(), "scripts", "smoke", fileName),
      "utf8",
    );
    assert.match(source, /const deletionRequestId = randomUUID\(\);/, fileName);
    assert.match(
      source,
      /request\(\s*["']DELETE["'],\s*["']\/api\/v1\/users\/me["'],\s*null,\s*token,\s*deletionRequestId,?\s*\)/,
      fileName,
    );
  }
});

test("public status exposes only DELETED PENDING or NOT_STARTED from one snapshot", async () => {
  const statuses = [
    {
      receipt: { receiptHash: "a".repeat(64) },
      reservation: null,
      expected: "DELETED",
    },
    {
      receipt: null,
      reservation: { method: "DELETE", path: "/api/v1/users/me" },
      expected: "PENDING",
    },
    { receipt: null, reservation: null, expected: "NOT_STARTED" },
  ] as const;

  for (const fixture of statuses) {
    let options: unknown;
    const service = usersService(
      {
        $transaction: async (operation: (tx: unknown) => unknown, value: unknown) => {
          options = value;
          return operation({
            accountDeletionReceipt: {
              findUnique: async () => fixture.receipt,
            },
            idempotencyKey: {
              findUnique: async () =>
                fixture.reservation == null
                  ? null
                  : {
                      id: "reservation-a",
                      completedAt: null,
                      createdAt: new Date(),
                      ...fixture.reservation,
                    },
              deleteMany: async () => ({ count: 0 }),
            },
          });
        },
      } as never,
      {} as never,
      {} as never,
    );

    assert.deepEqual(
      await service.accountDeletionStatus("user-a", "request-a"),
      { status: fixture.expected },
    );
    assert.deepEqual(options, {
      isolationLevel: Prisma.TransactionIsolationLevel.ReadCommitted,
    });
  }
});

test("stale crashed reservation is reclaimed only after locking a live user and rechecking receipt", async () => {
  const events: string[] = [];
  const service = usersService(
    {
      $transaction: async (operation: (tx: unknown) => unknown) =>
        operation({
          accountDeletionReceipt: {
            findUnique: async () => {
              events.push("receipt");
              return null;
            },
          },
          idempotencyKey: {
            findUnique: async () => ({
              id: "stale-reservation",
              method: "DELETE",
              path: "/api/v1/users/me",
              completedAt: null,
              createdAt: new Date(Date.now() - 60_000),
            }),
            deleteMany: async () => {
              events.push("reclaim");
              return { count: 1 };
            },
          },
          $queryRaw: async () => {
            events.push("lock-user");
            return [{ id: "user-a" }];
          },
        }),
    } as never,
    {} as never,
    {} as never,
  );

  assert.deepEqual(
    await service.accountDeletionStatus("user-a", "request-a"),
    { status: "NOT_STARTED" },
  );
  assert.deepEqual(events, ["receipt", "lock-user", "receipt", "reclaim"]);
});

test("a receipt committed while the stale-status request waits wins the race", async () => {
  let receiptReads = 0;
  let reclaimed = false;
  const service = usersService(
    {
      $transaction: async (operation: (tx: unknown) => unknown) =>
        operation({
          accountDeletionReceipt: {
            findUnique: async () =>
              ++receiptReads === 1 ? null : { receiptHash: "a".repeat(64) },
          },
          idempotencyKey: {
            findUnique: async () => ({
              id: "stale-reservation",
              method: "DELETE",
              path: "/api/v1/users/me",
              completedAt: null,
              createdAt: new Date(Date.now() - 60_000),
            }),
            deleteMany: async () => {
              reclaimed = true;
              return { count: 1 };
            },
          },
          $queryRaw: async () => [{ id: "user-a" }],
        }),
    } as never,
    {} as never,
    {} as never,
  );

  assert.deepEqual(
    await service.accountDeletionStatus("user-a", "request-a"),
    { status: "DELETED" },
  );
  assert.equal(reclaimed, false);
});

test("receipt digest is stable and stores neither source identifier", () => {
  const digest = accountDeletionReceiptHash("user-a", "request-a");
  assert.match(digest, /^[0-9a-f]{64}$/);
  assert.equal(digest.includes("user-a"), false);
  assert.equal(digest.includes("request-a"), false);
  assert.notEqual(digest, accountDeletionReceiptHash("user-a", "request-b"));
});

test("receipt migration enforces append-only anonymous rows", () => {
  const migration = readFileSync(
    join(
      process.cwd(),
      "prisma",
      "migrations",
      "20260803110000_add_account_deletion_receipts",
      "migration.sql",
    ),
    "utf8",
  );
  assert.match(migration, /^BEGIN;\s*$/m);
  assert.match(migration, /SET LOCAL lock_timeout = '15s';/);
  assert.match(migration, /COMMIT;\s*$/);
  assert.match(migration, /CREATE TABLE "AccountDeletionReceipt"/);
  assert.match(migration, /CHECK \("receiptHash" ~ '\^\[0-9a-f\]\{64\}\$'\)/);
  assert.match(migration, /BEFORE UPDATE ON "AccountDeletionReceipt"/);
  assert.match(migration, /BEFORE DELETE ON "AccountDeletionReceipt"/);
  assert.doesNotMatch(migration, /CREATE OR REPLACE FUNCTION/);
  assert.doesNotMatch(migration, /"userId"|"clientRequestId"/);
});
