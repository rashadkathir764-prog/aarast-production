import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { ConflictException } from "@nestjs/common";
import { AccountDeletionService } from "../src/modules/identity/internal/profile/account-deletion.service";
import {
  clearAccountDeletionRequest,
  clearAdministratorApplicationIdentity,
  markAccountDeletionRequested,
} from "../src/modules/identity/infrastructure/account-erasure.repository";

// RA-BE-177: the hourly purge takes 25 due accounts a run. It used to take
// them by due date alone, and a failure changed nothing, so 25 accounts
// that always fail took every run and every account behind them waited
// forever, past the thirty days the app promises.

const HOUR_MS = 60 * 60 * 1000;
const START = new Date("2026-11-27T09:35:00.000Z");
const at = (hours: number) => new Date(START.getTime() + hours * HOUR_MS);

type Row = Record<string, unknown> & { id: string };

function matches(row: Row, where: Record<string, unknown>): boolean {
  return Object.entries(where).every(([key, condition]) => {
    if (key === "OR") {
      return (condition as Array<Record<string, unknown>>).some((branch) =>
        matches(row, branch),
      );
    }
    const value = row[key] ?? null;
    if (condition === null || typeof condition !== "object" || condition instanceof Date) {
      return value instanceof Date && condition instanceof Date
        ? value.getTime() === condition.getTime()
        : value === condition;
    }
    return Object.entries(condition as Record<string, unknown>).every(([operator, operand]) => {
      switch (operator) {
        case "lte":
          return value !== null && (value as Date).getTime() <= (operand as Date).getTime();
        case "not":
          return operand === null ? value !== null : value !== operand;
        default:
          throw new Error(`The fake user table does not know "${operator}"`);
      }
    });
  });
}

function compare(left: Row, right: Row, orderBy: Array<Record<string, "asc" | "desc">>): number {
  for (const order of orderBy) {
    const [[key, direction]] = Object.entries(order);
    const a = left[key] instanceof Date ? (left[key] as Date).getTime() : left[key];
    const b = right[key] instanceof Date ? (right[key] as Date).getTime() : right[key];
    if (a === b) continue;
    const sign = direction === "asc" ? 1 : -1;
    return (a as number | string) < (b as number | string) ? -sign : sign;
  }
  return 0;
}

/** The `User` table as the purge reads and writes it. */
function userTable(rows: Row[]) {
  return {
    rows,
    user: {
      findMany: async (args: {
        where: Record<string, unknown>;
        orderBy: Array<Record<string, "asc" | "desc">>;
        select: Record<string, true>;
        take: number;
      }) =>
        rows
          .filter((row) => matches(row, args.where))
          .sort((left, right) => compare(left, right, args.orderBy))
          .slice(0, args.take)
          .map((row) =>
            Object.fromEntries(Object.keys(args.select).map((key) => [key, row[key]])),
          ),
      updateMany: async (args: {
        where: Record<string, unknown>;
        data: Record<string, unknown>;
      }) => {
        let count = 0;
        for (const row of rows.filter((candidate) => matches(candidate, args.where))) {
          for (const [key, value] of Object.entries(args.data)) {
            row[key] =
              value !== null && typeof value === "object" && "increment" in value
                ? (row[key] as number) + (value as { increment: number }).increment
                : value;
          }
          count += 1;
        }
        return { count };
      },
    },
  };
}

function dueAccount(id: string, scheduledFor: Date): Row {
  return {
    id,
    deletionRequestedAt: new Date(scheduledFor.getTime() - 30 * 24 * HOUR_MS),
    deletionScheduledFor: scheduledFor,
    deletionPurgeFailedAt: null,
    deletionPurgeFailure: null,
    deletionPurgeAttempts: 0,
  };
}

/** The purge over `rows`; the accounts in `failing` can never be erased (B-33). */
function purge(rows: Row[], failing: ReadonlySet<string>) {
  const table = userTable(rows);
  const erased: string[] = [];
  const users = {
    eraseDueAccount: async (id: string) => {
      if (failing.has(id)) {
        throw new ConflictException({
          statusCode: 409,
          code: "PROVIDER_HAS_UPCOMING_BOOKINGS",
          message: "Hand over or cancel the upcoming bookings first",
        });
      }
      rows.splice(rows.findIndex((row) => row.id === id), 1);
      erased.push(id);
      return "ERASED" as const;
    },
  };
  const service = new AccountDeletionService(
    table as never,
    users as never,
    {} as never,
    {} as never,
    {} as never,
    {} as never,
    {} as never,
  );
  const errors: string[] = [];
  const warnings: string[] = [];
  (service as unknown as { logger: unknown }).logger = {
    error: (message: string) => errors.push(message),
    warn: (message: string) => warnings.push(message),
    log: () => undefined,
  };
  return { service, erased, errors, warnings };
}

test("RA-BE-177: 25 accounts that always fail do not block a 26th", async () => {
  const failing = new Set(Array.from({ length: 25 }, (_, index) => `failing-${String(index).padStart(2, "0")}`));
  // The 25 failing accounts fell due first, so a purge by due date alone
  // takes them, and only them, every run.
  const rows = [
    ...[...failing].map((id, index) => dueAccount(id, new Date(START.getTime() - (60 - index) * HOUR_MS))),
    dueAccount("waiting", new Date(START.getTime() - HOUR_MS)),
  ];
  const { service, erased } = purge(rows, failing);

  const first = await service.purgeDueAccounts(at(0));
  assert.equal(first.failures.length, 25);
  assert.deepEqual(erased, []);

  const second = await service.purgeDueAccounts(at(1));
  assert.equal(second.erased, 1);
  assert.deepEqual(erased, ["waiting"]);
});

test("RA-BE-177: a failed purge records its attempts and last error; an account that failed within the hour waits", async () => {
  const rows = [dueAccount("blocked", at(-2))];
  const { service } = purge(rows, new Set(["blocked"]));

  await service.purgeDueAccounts(at(0));
  assert.equal(rows[0].deletionPurgeAttempts, 1);
  assert.equal(rows[0].deletionPurgeFailure, "PROVIDER_HAS_UPCOMING_BOOKINGS");
  assert.deepEqual(rows[0].deletionPurgeFailedAt, at(0));

  // Within the hour of its failure it is not tried again.
  const soon = await service.purgeDueAccounts(at(0.5));
  assert.equal(soon.failures.length, 0);
  assert.equal(rows[0].deletionPurgeAttempts, 1);

  // An hour after it, it is.
  const later = await service.purgeDueAccounts(at(1));
  assert.equal(later.failures.length, 1);
  assert.equal(rows[0].deletionPurgeAttempts, 2);
  assert.deepEqual(rows[0].deletionPurgeFailedAt, at(1));
});

test("RA-BE-177: the purge raises an error log once an account has failed 5 times", async () => {
  const rows = [dueAccount("blocked", at(-2))];
  const { service, errors } = purge(rows, new Set(["blocked"]));

  for (let run = 0; run < 4; run += 1) await service.purgeDueAccounts(at(run));
  assert.equal(rows[0].deletionPurgeAttempts, 4);
  assert.equal(errors.some((message) => message.includes("blocked")), false);

  await service.purgeDueAccounts(at(4));
  assert.equal(rows[0].deletionPurgeAttempts, 5);
  const alert = errors.find((message) => message.includes("blocked"));
  assert.ok(alert, "the fifth failure is raised");
  assert.match(alert, /5 times/);
  assert.match(alert, /PROVIDER_HAS_UPCOMING_BOOKINGS/);
});

test("RA-BE-177: asking again, taking the request back, or keeping an administrator forgets the attempts", async () => {
  const writes: Array<{ data: Record<string, unknown> }> = [];
  const tx = { user: { update: async (args: { data: Record<string, unknown> }) => (writes.push(args), {}) } };
  await markAccountDeletionRequested(tx as never, "user-a", at(0), at(720));
  await clearAccountDeletionRequest(tx as never, "user-a");
  await clearAdministratorApplicationIdentity(tx as never, "user-a");
  assert.equal(writes.length, 3);
  for (const { data } of writes) {
    assert.equal(data.deletionPurgeAttempts, 0);
    assert.equal(data.deletionPurgeFailedAt, null);
    assert.equal(data.deletionPurgeFailure, null);
  }
});
