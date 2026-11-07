import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import {
  ContributionAction,
  ContributionEntityType,
  ContributionProvenance,
  ContributionSection,
} from "@prisma/client";
import { contributionHistoryService } from "./support/owner-ports";

// RA-BE-39: money in a member's history is money too. D52 keeps money with
// the members who hold `canViewMoney`; a member whose money access was taken
// away still read the amounts of the payments and costs they had recorded,
// because the history list filtered by contributor alone.

type StoredEvent = {
  id: string;
  section: ContributionSection;
  entityId: string;
};

function sectionMatches(
  section: ContributionSection,
  filter: unknown,
): boolean {
  if (filter === undefined) return true;
  if (typeof filter === "string") return section === filter;
  const { in: allowed, notIn: refused } = filter as {
    in?: ContributionSection[];
    notIn?: ContributionSection[];
  };
  if (allowed && !allowed.includes(section)) return false;
  if (refused && refused.includes(section)) return false;
  return true;
}

function historyFor(member: { canViewMoney: boolean } | "owner") {
  const events: StoredEvent[] = [
    { id: "task-event", section: ContributionSection.TASKS, entityId: "task-1" },
    { id: "money-event", section: ContributionSection.MONEY, entityId: "payment-1" },
  ];
  const plan = { id: "plan-1", ownerUserId: "owner-1" };
  const membership =
    member === "owner"
      ? null
      : {
          id: "member-1",
          weddingPlanId: "plan-1",
          userId: "member-user",
          canManageTasks: true,
          canManageGuests: false,
          canViewMoney: member.canViewMoney,
          canManageMoney: false,
          canManageProviders: false,
          canInviteMembers: false,
          canEditPlan: false,
        };
  const pick = (where: Record<string, unknown>) =>
    events.filter((event) => sectionMatches(event.section, where.section));
  const tx = {
    weddingPlan: {
      findUnique: async () => plan,
      findFirst: async () => plan,
    },
    sharedMember: {
      findUnique: async () => membership,
      findFirst: async () => (membership ? { id: membership.id } : null),
    },
    contributorHistoryScope: {
      findFirst: async () => ({
        id: "scope-1",
        historyCoverageStartsAt: new Date("2026-08-02T09:00:00.000Z"),
      }),
    },
    contributionEvent: {
      findMany: async ({ where, select }: any) =>
        pick(where).map((event) =>
          select
            ? { section: event.section, entityId: event.entityId }
            : {
                id: event.id,
                contributorTenure: { actorReference: "a".repeat(64) },
                section: event.section,
                entityType:
                  event.section === ContributionSection.MONEY
                    ? ContributionEntityType.COST_PAYMENT
                    : ContributionEntityType.TASK,
                action: ContributionAction.CREATED,
                snapshot: { amount: "500000" },
                provenance: ContributionProvenance.RUNTIME,
                occurredAt: null,
                capturedAt: new Date("2026-08-02T10:00:00.000Z"),
              },
        ),
      count: async ({ where }: any) => pick(where).length,
    },
  };
  const prisma = {
    $transaction: async (operation: (client: typeof tx) => Promise<unknown>) =>
      operation(tx),
    ...tx,
  };
  const service = contributionHistoryService(prisma as any);
  const reader = {
    id: member === "owner" ? "owner-1" : "member-user",
  } as any;
  return {
    list: (section?: ContributionSection) =>
      service.list(reader, "plan-1", { limit: 20, offset: 0, section }),
    summary: () => service.summary(reader, "plan-1"),
  };
}

test("RA-BE-39: a member without money access reads no money in their own history", async () => {
  const history = historyFor({ canViewMoney: false });

  const page = await history.list();
  assert.deepEqual(
    page.events.map((event) => event.section),
    [ContributionSection.TASKS],
  );
  assert.equal(page.total, 1);
  assert.deepEqual((await history.list(ContributionSection.MONEY)).events, []);
  assert.equal((await history.list(ContributionSection.MONEY)).total, 0);
  const summary = await history.summary();
  assert.equal(summary.MONEY, 0);
  assert.equal(summary.TASKS, 1);
});

test("RA-BE-39: the owner and a member who reads money keep the money in the history", async () => {
  for (const reader of ["owner", { canViewMoney: true }] as const) {
    const history = historyFor(reader);
    const page = await history.list();
    assert.deepEqual(
      page.events.map((event) => event.section).sort(),
      [ContributionSection.MONEY, ContributionSection.TASKS],
    );
    assert.equal((await history.list(ContributionSection.MONEY)).total, 1);
    assert.equal((await history.summary()).MONEY, 1);
  }
});
