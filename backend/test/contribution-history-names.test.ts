import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import {
  ContributionAction,
  ContributionEntityType,
  ContributionProvenance,
  ContributionSection,
  UserRole,
} from "@prisma/client";
import { buildContributionSnapshot } from "../src/modules/collaboration/public/contribution-snapshot.builder";
import { DELETED_SUBJECT } from "../src/modules/collaboration/internal/contribution-history.service";
import { contributionHistoryService } from "./support/owner-ports";

// RA-BE-176 (D124): the contribution history kept guests' and members' names
// for ever, after the guest, the member, the plan or the account was gone.
// A snapshot now keeps no person's name: the event's entity type and id are
// its label, and the history reads the name live from the guest or member,
// «محذوف» once it is gone.

test("RA-BE-176: a snapshot built now names no guest and no member", () => {
  const guest = buildContributionSnapshot(ContributionEntityType.GUEST, {
    displayName: "سالم الحداد",
    groupDisplayName: "أهل العريس",
    side: "GROOM",
    invitationStatus: "NOT_INVITED",
    attendanceStatus: "PENDING",
  });
  assert.deepEqual(guest, {
    groupDisplayName: "أهل العريس",
    side: "GROOM",
    invitationStatus: "NOT_INVITED",
    attendanceStatus: "PENDING",
  });
  for (const entityType of [
    ContributionEntityType.MEMBER_ITEM,
    ContributionEntityType.PLAN_INVITE,
  ]) {
    const member = buildContributionSnapshot(entityType, {
      displayName: "صالح المنصور",
      role: "VIEWER",
      permissionLabels: ["المال"],
      inviteState: "PENDING",
    });
    assert.equal("displayName" in member, false, entityType);
    assert.equal(JSON.stringify(member).includes("صالح"), false, entityType);
  }
  // A group is not a person: it keeps its name.
  assert.deepEqual(
    buildContributionSnapshot(ContributionEntityType.GUEST_GROUP, {
      displayName: "أهل العروسة",
    }),
    { displayName: "أهل العروسة" },
  );
});

test("RA-BE-176: the history names live guests and members, and «محذوف» once gone", async () => {
  const event = (id: string, entityType: ContributionEntityType, entityId: string | null) => ({
    id,
    contributorTenure: { actorReference: "a".repeat(64) },
    section:
      entityType === ContributionEntityType.TASK
        ? ContributionSection.TASKS
        : entityType === ContributionEntityType.GUEST
          ? ContributionSection.GUESTS
          : ContributionSection.MEMBERS,
    entityType,
    entityId,
    action: ContributionAction.CREATED,
    snapshot: {},
    provenance: ContributionProvenance.RUNTIME,
    occurredAt: null,
    capturedAt: new Date("2026-08-02T10:00:00.000Z"),
  });
  const reads: Array<[string, unknown]> = [];
  const tx = {
    weddingPlan: {
      findUnique: async () => ({ id: "plan-1", ownerUserId: "owner-1" }),
    },
    contributorHistoryScope: {
      findFirst: async () => ({
        id: "scope-1",
        historyCoverageStartsAt: new Date("2026-08-02T09:00:00.000Z"),
      }),
    },
    contributionEvent: {
      findMany: async () => [
        event("e-guest", ContributionEntityType.GUEST, "guest-live"),
        event("e-guest-gone", ContributionEntityType.GUEST, "guest-gone"),
        event("e-member", ContributionEntityType.MEMBER_ITEM, "member-live"),
        event("e-member-gone", ContributionEntityType.MEMBER_ITEM, "member-gone"),
        event("e-invite", ContributionEntityType.PLAN_INVITE, "invite-live"),
        event("e-task", ContributionEntityType.TASK, "task-1"),
      ],
      count: async () => 6,
    },
    guest: {
      findMany: async ({ where }: any) => {
        reads.push(["guest", where]);
        return [{ id: "guest-live", name: "سالم" }];
      },
    },
    sharedMember: {
      findMany: async ({ where }: any) => {
        reads.push(["sharedMember", where]);
        return [{ id: "member-live", userId: "user-saleh" }];
      },
    },
    planInvite: {
      findMany: async ({ where }: any) => {
        reads.push(["planInvite", where]);
        return [{ id: "invite-live", name: "الوالد" }];
      },
    },
    user: {
      findMany: async () => [
        { id: "user-saleh", name: "صالح", appName: null, role: UserRole.USER },
      ],
    },
  };
  const prisma = {
    $transaction: async (operation: (client: typeof tx) => Promise<unknown>) =>
      operation(tx),
  };

  const page = await contributionHistoryService(prisma as any).list(
    { id: "owner-1" } as any,
    "plan-1",
    { limit: 20, offset: 0 },
  );

  assert.deepEqual(
    page.events.map((item) => [item.id, item.subjectName]),
    [
      ["e-guest", "سالم"],
      ["e-guest-gone", DELETED_SUBJECT],
      ["e-member", "صالح"],
      ["e-member-gone", DELETED_SUBJECT],
      ["e-invite", "الوالد"],
      ["e-task", null],
    ],
  );
  assert.equal(DELETED_SUBJECT, "محذوف");
  // Each name is read in this plan only.
  assert.deepEqual(reads, [
    ["guest", { weddingPlanId: "plan-1", id: { in: ["guest-live", "guest-gone"] } }],
    ["sharedMember", { weddingPlanId: "plan-1", id: { in: ["member-live", "member-gone"] } }],
    ["planInvite", { weddingPlanId: "plan-1", id: { in: ["invite-live"] } }],
  ]);
});
