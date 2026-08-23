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

test("history page and total are read from one repeatable-read authorization snapshot", async () => {
  const calls: string[] = [];
  const observedWhere: unknown[] = [];
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
    sharedMember: { findUnique: outsideSnapshot },
    contributorHistoryScope: { findFirst: outsideSnapshot },
    contributionEvent: {
      findMany: outsideSnapshot,
      count: outsideSnapshot,
    },
  };

  const result = await new ContributionHistoryService(prisma as any).list(
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
    "tx:scope",
    "tx:page",
    "tx:total",
    "transaction:end",
  ]);
  assert.equal(result.total, result.events.length);
  assert.equal(observedWhere.length, 2);
  assert.deepEqual(observedWhere[0], observedWhere[1]);
  assert.deepEqual(observedWhere[0], {
    historyScope: {
      id: "scope-1",
      weddingPlan: {
        is: {
          sharedMembers: {
            some: {
              id: "member-1",
              userId: "contributor-1",
            },
          },
        },
      },
    },
    contributorTenure: {
      actorReference: contributorActorReference("contributor-1"),
    },
  });
});
