import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import {
  ContributionAction,
  ContributionEntityType,
  ContributionProvenance,
  ContributionSection,
  WeddingTaskPriority,
  WeddingTaskStatus,
} from "@prisma/client";
import {
  buildContributionSnapshot,
  validateContributionSnapshot,
} from "../src/modules/collaboration/public/contribution-snapshot.builder";
import { contributionHistoryService, tasksService } from "./support/owner-ports";

test("each contribution snapshot type emits only its explicit privacy allowlist", () => {
  const sensitiveSource = {
    id: "live-id",
    weddingPlanId: "plan-1",
    userId: "user-1",
    title: "Title",
    status: "ACTIVE",
    priority: "HIGH",
    dueDate: new Date("2026-08-02T10:00:00.000Z"),
    taskCategory: "Venue",
    displayName: "Display",
    groupDisplayName: "Family",
    side: "BRIDE",
    invitationStatus: "SENT",
    attendanceStatus: "PENDING",
    categoryLabel: "Hall",
    currency: "YER",
    totalAmount: "1000.00",
    paidAmount: "0.00",
    amount: "1000.00",
    relevantDate: new Date("2026-08-03T10:00:00.000Z"),
    providerDisplayLabel: "Provider",
    requestStatus: "SENT",
    role: "CONTRIBUTOR",
    permissionLabels: ["TASKS"],
    inviteState: "ACCEPTED",
    planTitle: "Plan",
    weddingDate: new Date("2026-12-01T00:00:00.000Z"),
    phone: "+967777777777",
    email: "secret@example.com",
    notes: "private",
    message: "private quote text",
    paymentMethod: "cash",
    attachmentUrl: "https://example.com/private.pdf?token=secret",
  };

  const cases: Array<[ContributionEntityType, readonly string[]]> = [
    [
      ContributionEntityType.TASK,
      ["title", "status", "priority", "dueDate", "category"],
    ],
    [
      ContributionEntityType.GUEST,
      [
        "displayName",
        "groupDisplayName",
        "side",
        "invitationStatus",
        "attendanceStatus",
      ],
    ],
    [
      ContributionEntityType.MONEY_ITEM,
      [
        "title",
        "categoryLabel",
        "currency",
        "totalAmount",
        "paidAmount",
        "amount",
        "status",
        "relevantDate",
      ],
    ],
    [
      ContributionEntityType.PROVIDER_ITEM,
      ["providerDisplayLabel", "categoryLabel", "requestStatus", "status"],
    ],
    [
      ContributionEntityType.MEMBER_ITEM,
      ["displayName", "role", "permissionLabels", "inviteState"],
    ],
    [ContributionEntityType.PLAN, ["planTitle", "weddingDate", "status"]],
    [ContributionEntityType.SECTION, ["status"]],
  ];

  for (const [entityType, allowed] of cases) {
    const snapshot = buildContributionSnapshot(entityType, sensitiveSource);
    assert.deepEqual(
      Object.keys(snapshot).sort(),
      [...allowed].sort(),
      entityType,
    );
    validateContributionSnapshot(snapshot);
    const serialized = JSON.stringify(snapshot).toLowerCase();
    for (const forbidden of [
      "live-id",
      "plan-1",
      "user-1",
      "+967",
      "secret@example.com",
      "private quote",
      "paymentmethod",
      "attachment",
    ]) {
      assert.equal(
        serialized.includes(forbidden),
        false,
        `${entityType}: ${forbidden}`,
      );
    }
  }
});

test("snapshot validation rejects forbidden nested keys and sensitive values", () => {
  for (const snapshot of [
    { title: "safe", nested: { contactPhone: "777777777" } },
    { title: "email secret@example.com" },
    { title: "Bearer eyJhbGciOiJIUzI1NiJ9.secret.signature" },
    { title: "https://example.com/path?token=secret" },
    { title: "محمد 777777777" },
    { title: "محمد ٧٧٧٧٧٧٧٧٧" },
    { title: "محمد ۷۷۷۷۷۷۷۷۷" },
  ]) {
    assert.throws(() => validateContributionSnapshot(snapshot));
  }
});

test("sensitive user text is omitted from history without rejecting the task mutation", async () => {
  const sensitiveTitle = "Call 777777777 before confirming";
  const now = new Date("2026-08-03T12:00:00.000Z");
  let recordedSnapshot: Record<string, unknown> | undefined;
  const context = {
    plan: { id: "plan-1", ownerUserId: "owner-1" },
    isOwner: false,
    sharedMember: {
      id: "member-1",
      weddingPlanId: "plan-1",
      userId: "contributor-1",
      authorityVersion: 1,
      canManageTasks: true,
    },
  };
  const createdTask = {
    id: "task-sensitive-title",
    weddingPlanId: "plan-1",
    assigneeUserId: null,
    responsibleName: null,
    responsiblePhone: null,
    responsibleSource: null,
    title: sensitiveTitle,
    description: null,
    dueDate: null,
    taskCategory: null,
    reminderAt: null,
    status: WeddingTaskStatus.TODO,
    priority: WeddingTaskPriority.MEDIUM,
    createdAt: now,
    updatedAt: now,
  };
  const prisma: any = {
    weddingTask: { create: async () => createdTask },
  };
  prisma.$transaction = async (operation: (tx: any) => Promise<unknown>) =>
    operation(prisma);
  const service = tasksService(
    prisma,
    { assertTaskManageableInTransaction: async () => context } as any,
    { notifyTaskDue: async () => undefined } as any,
    {
      recordForContextInTransaction: async (
        _tx: unknown,
        _context: unknown,
        input: { snapshot: Record<string, unknown> },
      ) => {
        recordedSnapshot = input.snapshot;
      },
    } as any,
    {} as any,
  );

  const result = await service.create(
    { id: "contributor-1" } as any,
    "plan-1",
    { title: sensitiveTitle } as any,
  );

  assert.equal(result.title, sensitiveTitle);
  assert.equal(recordedSnapshot?.title, undefined);
  assert.equal(recordedSnapshot?.status, WeddingTaskStatus.TODO);
  assert.doesNotMatch(JSON.stringify(recordedSnapshot), /777777777/);
});

test("snapshot validation rejects keys outside the durable allowlist", () => {
  assert.throws(
    () => validateContributionSnapshot({ title: "safe", internalId: "id-1" }),
    /Unknown contribution snapshot key/,
  );
});

test("snapshot validation enforces append-only storage depth, item, string, and byte limits", () => {
  assert.throws(() =>
    validateContributionSnapshot({ title: "x".repeat(2_049) }),
  );
  assert.throws(() =>
    validateContributionSnapshot({
      permissionLabels: Array.from({ length: 101 }, () => "SAFE"),
    }),
  );
  assert.throws(() =>
    validateContributionSnapshot({
      a: { b: { c: { d: { e: { f: { g: "too deep" } } } } } },
    }),
  );
  assert.throws(() =>
    validateContributionSnapshot({
      permissionLabels: Array.from(
        { length: 100 },
        (_, index) => `label-${index}-${"x".repeat(170)}`,
      ),
    }),
  );
});

test("history listing requires current access and removes live ids from revoked sections", async () => {
  const events = [
    {
      id: "event-task",
      historyScopeId: "scope-1",
      contributorTenureId: "tenure-1",
      contributorTenure: { actorReference: "a".repeat(64) },
      section: ContributionSection.TASKS,
      entityType: ContributionEntityType.TASK,
      entityId: "task-live-id",
      action: ContributionAction.CREATED,
      snapshot: { title: "Task" },
      snapshotHash: "a".repeat(64),
      dedupeKey: "task-created",
      provenance: ContributionProvenance.RUNTIME,
      permissionPolicyVersion: 1,
      authorityVersion: 1,
      occurredAt: null,
      capturedAt: new Date("2026-08-02T10:00:00.000Z"),
    },
    {
      id: "event-guest",
      historyScopeId: "scope-1",
      contributorTenureId: "tenure-1",
      contributorTenure: { actorReference: "a".repeat(64) },
      section: ContributionSection.GUESTS,
      entityType: ContributionEntityType.GUEST,
      entityId: "guest-live-id",
      action: ContributionAction.CREATED,
      snapshot: { displayName: "Guest" },
      snapshotHash: "b".repeat(64),
      dedupeKey: "guest-created",
      provenance: ContributionProvenance.RUNTIME,
      permissionPolicyVersion: 1,
      authorityVersion: 1,
      occurredAt: null,
      capturedAt: new Date("2026-08-02T11:00:00.000Z"),
    },
  ];
  const prisma: any = {
    weddingPlan: {
      findUnique: async () => ({ id: "plan-1", ownerUserId: "owner-1" }),
    },
    sharedMember: {
      findUnique: async () => ({
        userId: "contributor-1",
        canManageTasks: false,
        canManageGuests: true,
        canViewMoney: false,
        canManageProviders: false,
        canInviteMembers: false,
        canEditPlan: false,
      }),
    },
    contributorHistoryScope: {
      findFirst: async () => ({
        id: "scope-1",
        historyCoverageStartsAt: new Date("2026-08-02T09:00:00.000Z"),
      }),
    },
    contributionEvent: {
      findMany: async () => events,
      count: async () => events.length,
    },
  };
  prisma.$transaction = async (operation: (tx: any) => Promise<unknown>) =>
    operation(prisma);
  const service = contributionHistoryService(prisma as any);

  const result = await service.list(
    { id: "contributor-1" } as any,
    "plan-1",
    {},
  );

  assert.equal("entityId" in result.events[0], false);
  assert.equal("entityId" in result.events[1], false);
  assert.equal(result.events[0].contributorReference, "a".repeat(64));
  assert.equal(result.historyCoverageStartsAt, "2026-08-02T09:00:00.000Z");

  prisma.sharedMember.findUnique = async () => null as never;
  await assert.rejects(
    () => service.list({ id: "outsider" } as any, "plan-1", {}),
    /Wedding plan not found/,
  );
});

test("owner history filters deleted contributors by durable reference and allows an unfiltered audit", async () => {
  const observed: any[] = [];
  const event = {
    id: "event-1",
    historyScopeId: "scope-1",
    contributorTenureId: "tenure-deleted-user",
    contributorTenure: { actorReference: "placeholder" },
    section: ContributionSection.TASKS,
    entityType: ContributionEntityType.TASK,
    entityId: "task-1",
    action: ContributionAction.CREATED,
    snapshot: { title: "Task" },
    snapshotHash: "a".repeat(64),
    dedupeKey: "task-1",
    provenance: ContributionProvenance.RUNTIME,
    permissionPolicyVersion: 1,
    authorityVersion: 1,
    occurredAt: null,
    capturedAt: new Date("2026-08-02T10:00:00.000Z"),
  };
  const prisma: any = {
    weddingPlan: { findUnique: async () => ({ ownerUserId: "owner-1" }) },
    sharedMember: { findUnique: async () => null },
    contributorHistoryScope: {
      findFirst: async () => ({
        id: "scope-1",
        historyCoverageStartsAt: new Date("2026-08-02T09:00:00.000Z"),
      }),
    },
    contributionEvent: {
      findMany: async ({ where }: any) => {
        observed.push(where);
        const actorReference =
          where.contributorTenure?.actorReference ?? "b".repeat(64);
        return [{ ...event, contributorTenure: { actorReference } }];
      },
      count: async ({ where }: any) => {
        observed.push(where);
        return 1;
      },
    },
  };
  prisma.$transaction = async (operation: (tx: any) => Promise<unknown>) =>
    operation(prisma);
  const service = contributionHistoryService(prisma as any);

  const filtered = await service.list({ id: "owner-1" } as any, "plan-1", {
    contributorUserId: "deleted-user-1",
  });
  assert.match(filtered.events[0].contributorReference, /^[a-f0-9]{64}$/);
  assert.equal(
    observed[0].contributorTenure.actorReference,
    filtered.events[0].contributorReference,
  );

  await service.list({ id: "owner-1" } as any, "plan-1", {});
  assert.equal("contributorTenure" in observed[2], false);

  await service.summary({ id: "owner-1" } as any, "plan-1", "deleted-user-1");
  assert.equal(
    observed[4].contributorTenure.actorReference,
    filtered.events[0].contributorReference,
  );

  await service.summary({ id: "owner-1" } as any, "plan-1");
  assert.equal("contributorTenure" in observed[5], false);
});
