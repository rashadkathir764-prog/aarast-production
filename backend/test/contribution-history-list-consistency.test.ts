import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import {
  ContributionAction,
  ContributionEntityType,
  ContributionProvenance,
  ContributionSection,
  Prisma,
} from "@prisma/client";
import {
  ContributionHistoryService,
  contributorActorReference,
} from "../src/modules/collaboration/internal/contribution-history.service";
import { contributionHistoryService } from "./support/owner-ports";

// The page and total used to carry the live membership check as a
// `weddingPlan: { is: ... }` join on planning's table. The check is now a
// separate member-row read through the permission port inside the same
// repeatable-read transaction, and its result is spread into both history
// queries; the fixture therefore serves that read on `tx` and refuses it
// outside the snapshot like every other read.
test("history page and total are read from one repeatable-read authorization snapshot", async () => {
  const calls: string[] = [];
  const observedWhere: unknown[] = [];
  let liveWhere: unknown;
  let transactionOptions: unknown;
  const liveMember = {
    id: "member-1",
    weddingPlanId: "plan-1",
    userId: "contributor-1",
    canManageTasks: false,
    canManageGuests: false,
    canViewMoney: false,
    canManageProviders: false,
    canInviteMembers: false,
    canEditPlan: false,
  };
  const tx = {
    weddingPlan: {
      findUnique: async () => {
        calls.push("tx:plan");
        return { id: "plan-1", ownerUserId: "owner-1" };
      },
    },
    sharedMember: {
      findUnique: async () => {
        calls.push("tx:member");
        return liveMember;
      },
      findFirst: async ({ where }: { where: unknown }) => {
        calls.push("tx:member-live");
        liveWhere = where;
        return { id: liveMember.id };
      },
    },
    contributorHistoryScope: {
      findFirst: async () => {
        calls.push("tx:scope");
        return {
          id: "scope-1",
          historyCoverageStartsAt: new Date("2026-08-02T09:00:00.000Z"),
        };
      },
    },
    contributionEvent: {
      findMany: async ({ where }: { where: unknown }) => {
        calls.push("tx:page");
        observedWhere.push(where);
        return [{
          id: "event-1",
          contributorTenure: { actorReference: "a".repeat(64) },
          section: ContributionSection.TASKS,
          entityType: ContributionEntityType.TASK,
          action: ContributionAction.CREATED,
          snapshot: { title: "Task" },
          provenance: ContributionProvenance.RUNTIME,
          occurredAt: null,
          capturedAt: new Date("2026-08-02T10:00:00.000Z"),
        }];
      },
      count: async ({ where }: { where: unknown }) => {
        calls.push("tx:total");
        observedWhere.push(where);
        return 1;
      },
    },
  };
  const outsideSnapshot = async () => {
    throw new Error("history read escaped the transaction snapshot");
  };
  const prisma = {
    $transaction: async (
      operation: (client: typeof tx) => Promise<unknown>,
      options: unknown,
    ) => {
      calls.push("transaction:start");
      transactionOptions = options;
      const result = await operation(tx);
      calls.push("transaction:end");
      return result;
    },
    weddingPlan: { findUnique: outsideSnapshot },
    sharedMember: { findUnique: outsideSnapshot, findFirst: outsideSnapshot },
    contributorHistoryScope: { findFirst: outsideSnapshot },
    contributionEvent: {
      findMany: outsideSnapshot,
      count: outsideSnapshot,
    },
  };

  const result = await contributionHistoryService(prisma as any).list(
    { id: "contributor-1" } as any,
    "plan-1",
    { limit: 20, offset: 0 },
  );

  assert.deepEqual(transactionOptions, {
    isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead,
  });
  assert.deepEqual(calls, [
    "transaction:start",
    "tx:plan",
    "tx:member",
    "tx:member-live",
    "tx:scope",
    "tx:page",
    "tx:total",
    "transaction:end",
  ]);
  assert.deepEqual(liveWhere, {
    id: "member-1",
    weddingPlanId: "plan-1",
    userId: "contributor-1",
  });
  assert.equal(result.total, result.events.length);
  assert.equal(observedWhere.length, 2);
  assert.deepEqual(observedWhere[0], observedWhere[1]);
  assert.deepEqual(observedWhere[0], {
    historyScope: { id: "scope-1" },
    contributorTenure: {
      actorReference: contributorActorReference("contributor-1"),
    },
  });
});
