import "reflect-metadata";

import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { test } from "node:test";
import {
  ContributionAction,
  ContributionEntityType,
  ContributionPermission,
  ContributionSection,
  GuestAttendanceStatus,
  GuestInvitationStatus,
  GuestSide,
  GuestStatus,
  SharedMemberRole,
  WeddingTaskPriority,
  WeddingTaskStatus,
} from "@prisma/client";
import { GuestsService } from "../src/guests/guests.service";
import { ContributorScopeService } from "../src/modules/collaboration/internal/contributor-scope.service";
import { TasksService } from "../src/tasks/tasks.service";
import { contributionHistoryService, tasksService, timelineService } from "./support/owner-ports";
import { TimelineService } from "../src/timeline/timeline.service";

const now = new Date("2026-08-02T09:00:00.000Z");

function contributorContext(
  overrides: Record<string, unknown> = {},
) {
  return {
    plan: {
      id: "plan-1",
      ownerUserId: "owner-1",
      weddingDate: null,
      status: "ACTIVE",
    },
    isOwner: false,
    sharedMember: {
      id: "member-a",
      weddingPlanId: "plan-1",
      userId: "contributor-a",
      role: SharedMemberRole.CONTRIBUTOR,
      canManageTasks: true,
      canManageGuests: true,
      authorityVersion: 3,
      receiveNotifications: true,
      createdAt: now,
      updatedAt: now,
      ...overrides,
    },
  } as any;
}

function task(id: string, assigneeUserId: string | null) {
  return {
    id,
    weddingPlanId: "plan-1",
    assigneeUserId,
    responsibleName: null,
    responsiblePhone: null,
    responsibleSource: null,
    title: `Task ${id}`,
    description: "private task description",
    dueDate: new Date("2026-08-03T09:00:00.000Z"),
    taskCategory: "VENUE",
    reminderAt: null,
    status: WeddingTaskStatus.TODO,
    priority: WeddingTaskPriority.MEDIUM,
    createdAt: now,
    updatedAt: now,
    checklistItems: [],
  };
}

function guest(id: string) {
  return {
    id,
    weddingPlanId: "plan-1",
    groupId: null,
    name: `Guest ${id}`,
    normalizedName: `Guest ${id}`,
    phone: "+967777777777",
    normalizedPhone: "967777777777",
    side: GuestSide.OTHER,
    status: GuestStatus.INVITED,
    invitationStatus: GuestInvitationStatus.NOT_SENT,
    attendanceStatus: GuestAttendanceStatus.PENDING,
    seatsCount: 1,
    companionsCount: 0,
    notes: "private guest note",
    createdAt: now,
    updatedAt: now,
    group: null,
  };
}

function permissions(context = contributorContext()) {
  return {
    assertPlanReadable: async () => context,
    assertPlanReadableInTransaction: async () => context,
    assertTaskManageableInTransaction: async () => context,
    assertGuestManageableInTransaction: async () => context,
    canManageTasks: () => Boolean(context.sharedMember?.canManageTasks),
    canManageGuests: () => Boolean(context.sharedMember?.canManageGuests),
    canViewMoney: () => false,
  } as any;
}

test("task list, detail, summary and timeline never expose another contributor task", async () => {
  const own = task("task-a", "contributor-a");
  const other = task("task-b", "contributor-b");
  const prisma = {
    weddingTask: {
      findMany: async () => [own, other],
      findUnique: async ({ where }: any) =>
        where.id === own.id ? own : other,
      findFirst: async ({ where }: any) =>
        where.id === own.id ? own : null,
    },
    paymentSchedule: { findMany: async () => [] },
  } as any;
  const scope = {
    qualifyingEntityIds: async () => [own.id],
  } as any;
  const tasks = tasksService(
    prisma,
    permissions(),
    { notifyTaskDue: async () => undefined },
    {},
    scope,
  ) as TasksService;
  const timeline = timelineService(
    prisma,
    permissions(),
    scope,
  ) as TimelineService;
  const actor = { id: "contributor-a" } as any;

  assert.deepEqual(
    (await tasks.findForPlan(actor, "plan-1")).map((item) => item.id),
    [own.id],
  );
  assert.equal((await tasks.summary(actor, "plan-1")).total, 1);
  assert.deepEqual(
    (await timeline.getForPlan(actor, "plan-1")).upcomingTasks.map(
      (item) => item.id,
    ),
    [own.id],
  );
  await assert.rejects(
    () => tasks.findOne(actor, other.id),
    (error: any) =>
      error?.getStatus?.() === 404 &&
      error?.message === "Task not found",
  );
});

test("revoked task detail returns the stable Arabic 403 instead of hiding the permission failure", async () => {
  const own = task("task-a", "contributor-a");
  const context = contributorContext({ canManageTasks: false });
  const tasks = tasksService(
    { weddingTask: { findUnique: async () => own } },
    permissions(context),
    { notifyTaskDue: async () => undefined },
    {},
    { qualifyingEntityIds: async () => [own.id] },
  ) as TasksService;

  await assert.rejects(
    () => tasks.findOne({ id: "contributor-a" } as any, own.id),
    (error: any) =>
      error?.getStatus?.() === 403 &&
      error?.getResponse?.()?.code === "TASK_PERMISSION_REVOKED" &&
      error?.getResponse?.()?.message ===
        "لم تعد لديك صلاحية لتنفيذ هذه المهمة",
  );
});

test("timeline never exposes another contributor financial schedule", async () => {
  const schedules = [
    {
      id: "schedule-a",
      weddingCostId: "cost-a",
      amount: { toString: () => "100" },
      dueDate: now,
      status: "PENDING",
      weddingCost: { title: "Own cost" },
    },
    {
      id: "schedule-b",
      weddingCostId: "cost-b",
      amount: { toString: () => "200" },
      dueDate: now,
      status: "PENDING",
      weddingCost: { title: "Other cost" },
    },
  ];
  const context = contributorContext({ canViewMoney: true });
  let liveMemberWhere: unknown;
  const timeline = timelineService(
    {
      weddingTask: { findMany: async () => [] },
      paymentSchedule: { findMany: async () => schedules },
      // The live money re-check used to be a join on the schedule query;
      // it is the stored membership row read through the permission port.
      sharedMember: {
        findFirst: async ({ where }: { where: unknown }) => {
          liveMemberWhere = where;
          return { id: context.sharedMember.id };
        },
      },
    },
    {
      ...permissions(context),
      canViewMoney: () => true,
    },
    {
      qualifyingEntityIds: async (
        _planId: string,
        _actorId: string,
        entityTypes: ContributionEntityType[],
      ) =>
        entityTypes.includes(ContributionEntityType.WEDDING_COST)
          ? ["cost-a"]
          : [],
    },
  ) as TimelineService;

  const result = await timeline.getForPlan(
    { id: "contributor-a" } as any,
    "plan-1",
  );
  assert.deepEqual(
    result.paymentSchedules.map((schedule) => schedule.id),
    ["schedule-a"],
  );
  assert.deepEqual(liveMemberWhere, {
    id: "member-a",
    weddingPlanId: "plan-1",
    userId: "contributor-a",
    canViewMoney: true,
  });
});

test("revoked task permission returns no live rows even for a previously contributed task", async () => {
  let queried = false;
  const context = contributorContext({ canManageTasks: false });
  const tasks = tasksService(
    {
      weddingTask: {
        findMany: async () => {
          queried = true;
          return [task("task-a", "contributor-a")];
        },
      },
    },
    permissions(context),
    { notifyTaskDue: async () => undefined },
    {},
    { qualifyingEntityIds: async () => ["task-a"] },
  ) as TasksService;

  assert.deepEqual(
    await tasks.findForPlan({ id: "contributor-a" } as any, "plan-1"),
    [],
  );
  assert.equal(queried, false, "revoked live rows must not be queried");
});

test("a historical ASSIGNED event does not keep live access after reassignment", async () => {
  const reassigned = task("task-reassigned", "contributor-b");
  const tasks = tasksService(
    { weddingTask: { findMany: async () => [reassigned] } },
    permissions(),
    { notifyTaskDue: async () => undefined },
    {},
    {
      qualifyingEntityIds: async (
        _planId: string,
        _actorId: string,
        _entityTypes: unknown,
        actions: ContributionAction[],
      ) => {
        assert.deepEqual(actions, [
          ContributionAction.CREATED,
          ContributionAction.COMPLETED,
        ]);
        return [];
      },
    },
  ) as TasksService;

  assert.deepEqual(
    await tasks.findForPlan({ id: "contributor-a" } as any, "plan-1"),
    [],
  );
});

test("live scope accepts qualifying events from current and previous tenures after current membership is authorized", async () => {
  const observed: any[] = [];
  const prisma = {
    contributionEvent: {
      findMany: async ({ where }: any) => {
        observed.push(where);
        return [];
      },
    },
  } as any;
  const history = contributionHistoryService(prisma);
  const scope = new ContributorScopeService(history);

  await scope.qualifyingEntityIds(
    "plan-1",
    "contributor-a",
    [ContributionEntityType.TASK],
    [ContributionAction.CREATED],
  );
  await scope.qualifyingEntityIdsInTransaction(
    prisma,
    "plan-1",
    "contributor-a",
    [ContributionEntityType.TASK],
    [ContributionAction.CREATED],
  );

  await scope.qualifyingEntityIdsForActorInTransaction(
    prisma,
    "contributor-a",
    [ContributionEntityType.QUOTE_REQUEST],
    [ContributionAction.CREATED, ContributionAction.LEGACY_CAPTURED],
  );
  await scope.qualifyingEntityIdsForActorInTransaction(
    prisma,
    "contributor-a",
    [ContributionEntityType.QUOTE_REQUEST],
    [ContributionAction.CREATED],
    "quote-1",
  );

  assert.equal(observed.length, 4);
  for (const where of observed) {
    assert.deepEqual(where.contributorTenure, {
      actorReference: createHash("sha256").update("contributor-a").digest("hex"),
    });
  }
  // The actor-wide scope spans plans: no history-scope predicate, the
  // requested entity types and actions, and an exact entity id when asked.
  assert.deepEqual(observed[2], {
    contributorTenure: observed[2].contributorTenure,
    entityType: { in: [ContributionEntityType.QUOTE_REQUEST] },
    action: { in: [ContributionAction.CREATED, ContributionAction.LEGACY_CAPTURED] },
    entityId: { not: null },
  });
  assert.equal(observed[3].entityId, "quote-1");
});

test("guest list and summary only use the contributor guest scope", async () => {
  const own = guest("guest-a");
  const other = guest("guest-b");
  const prisma: any = {
    guest: { findMany: async () => [own, other] },
    guestGroup: { count: async () => 0 },
  };
  prisma.$transaction = async (
    operation: (tx: any) => Promise<unknown>,
  ) => operation(prisma);
  const scope = {
    qualifyingEntityIds: async () => [own.id],
    qualifyingEntityIdsInTransaction: async (
      _tx: unknown,
      _planId: string,
      _actorId: string,
      entityTypes: ContributionEntityType[],
    ) =>
      entityTypes.includes(ContributionEntityType.GUEST_GROUP)
        ? []
        : [own.id],
  };
  const guests = new (GuestsService as any)(
    prisma,
    permissions(),
    {},
    scope,
  ) as GuestsService;
  const actor = { id: "contributor-a" } as any;

  assert.deepEqual(
    (await guests.findForPlan(actor, "plan-1")).map((item) => item.id),
    [own.id],
  );
  assert.equal((await guests.summary(actor, "plan-1")).totalGuests, 1);
});

test("task create and completion append privacy-allowlisted events in the domain transaction", async () => {
  const createdTask = task("task-created", null);
  let currentTask = createdTask;
  const events: any[] = [];
  const prisma: any = {
    weddingTask: {
      create: async () => createdTask,
      findUnique: async () => currentTask,
      update: async ({ data }: any) => {
        currentTask = { ...currentTask, ...data, updatedAt: new Date(now.getTime() + 1) };
        return currentTask;
      },
    },
    $queryRaw: async () => [{ id: createdTask.id }],
  };
  prisma.$transaction = async (operation: (tx: any) => Promise<unknown>) =>
    operation(prisma);
  const history = {
    recordForContextInTransaction: async (tx: unknown, context: unknown, input: any) => {
      assert.equal(tx, prisma);
      events.push({ context, input });
    },
  };
  const scope = {
    qualifyingEntityIdsInTransaction: async () => [createdTask.id],
  };
  const service = tasksService(
    prisma,
    permissions(),
    { notifyTaskDue: async () => undefined },
    history,
    scope,
  ) as TasksService;
  const actor = { id: "contributor-a" } as any;

  await service.create(actor, "plan-1", {
    title: createdTask.title,
    description: createdTask.description,
    responsiblePhone: "+967700000000",
  } as any);
  await service.update(actor, createdTask.id, {
    status: WeddingTaskStatus.DONE,
  });

  assert.equal(events.length, 2);
  assert.equal(events[0].input.section, ContributionSection.TASKS);
  assert.equal(events[0].input.entityType, ContributionEntityType.TASK);
  assert.equal(events[0].input.action, ContributionAction.CREATED);
  assert.equal(
    events[0].input.requiredPermission,
    ContributionPermission.MANAGE_TASKS,
  );
  assert.equal(events[1].input.action, ContributionAction.COMPLETED);
  const serialized = JSON.stringify(events.map((event) => event.input.snapshot));
  assert.equal(serialized.includes("+967"), false);
  assert.equal(serialized.includes("private task description"), false);
});

test("owner assignment records ASSIGNED for the target contributor in the same transaction", async () => {
  const original = task("task-assigned", null);
  const assigned = {
    ...original,
    assigneeUserId: "contributor-a",
    updatedAt: new Date(now.getTime() + 2),
  };
  const member = contributorContext().sharedMember;
  const recorded: any[] = [];
  const prisma: any = {
    weddingTask: {
      findUnique: async () => original,
      update: async () => assigned,
    },
    sharedMember: { findUnique: async () => member },
    $queryRaw: async () => [{ id: "locked" }],
  };
  prisma.$transaction = async (operation: (tx: any) => Promise<unknown>) =>
    operation(prisma);
  const ownerContext = {
    plan: { id: "plan-1", ownerUserId: "owner-1" },
    isOwner: true,
    sharedMember: null,
  } as any;
  const service = tasksService(
    prisma,
    {
      assertTaskManageableInTransaction: async () => ownerContext,
    },
    {
      notifyTaskDue: async () => undefined,
      createNotificationInTransaction: async () => undefined,
    },
    {
      recordForContextInTransaction: async () => undefined,
      ensureTenureInTransaction: async (tx: unknown) => assert.equal(tx, prisma),
      recordInTransaction: async (tx: unknown, input: any) => {
        assert.equal(tx, prisma);
        recorded.push(input);
      },
    },
    {},
  ) as TasksService;

  await service.assign({ id: "owner-1" } as any, original.id, {
    assigneeUserId: "contributor-a",
  });

  assert.equal(recorded.length, 1);
  assert.equal(recorded[0].actorUserId, "contributor-a");
  assert.equal(recorded[0].action, ContributionAction.ASSIGNED);
  assert.equal(recorded[0].requiredPermission, ContributionPermission.MANAGE_TASKS);
  assert.equal(JSON.stringify(recorded[0].snapshot).includes("private task description"), false);
});

test("guest create/update append frozen allowlisted snapshots and reject another contributor guest", async () => {
  const own = guest("guest-a");
  const other = guest("guest-b");
  let currentGuest = own;
  const events: any[] = [];
  const prisma: any = {
    guest: {
      create: async () => own,
      findUnique: async ({ where }: any) =>
        where.id === own.id ? currentGuest : other,
      findFirst: async () => null,
      update: async ({ data }: any) => {
        currentGuest = { ...currentGuest, ...data, updatedAt: new Date(now.getTime() + 1) };
        return currentGuest;
      },
    },
    $queryRaw: async () => [{ id: own.id }],
  };
  prisma.$transaction = async (operation: (tx: any) => Promise<unknown>) =>
    operation(prisma);
  const history = {
    recordForContextInTransaction: async (tx: unknown, context: unknown, input: any) => {
      assert.equal(tx, prisma);
      events.push({ context, input });
    },
  };
  const scope = {
    qualifyingEntityIdsInTransaction: async () => [own.id],
  };
  const service = new (GuestsService as any)(
    prisma,
    permissions(),
    history,
    scope,
  ) as GuestsService;
  const actor = { id: "contributor-a" } as any;

  await service.create(actor, "plan-1", {
    name: own.name,
    phone: own.phone,
    notes: own.notes,
  } as any);
  await service.update(actor, own.id, {
    attendanceStatus: GuestAttendanceStatus.CONFIRMED,
  });
  await assert.rejects(
    () => service.update(actor, other.id, { name: "Changed" }),
    /Guest not found/,
  );

  assert.equal(events.length, 2);
  assert.equal(events[0].input.section, ContributionSection.GUESTS);
  assert.equal(events[0].input.entityType, ContributionEntityType.GUEST);
  assert.equal(events[0].input.action, ContributionAction.CREATED);
  assert.equal(events[1].input.action, ContributionAction.STATUS_CHANGED);
  const serialized = JSON.stringify(events.map((event) => event.input.snapshot));
  assert.equal(serialized.includes("+967"), false);
  assert.equal(serialized.includes("private guest note"), false);
});

test("contributor cannot link a new guest to an owner or another contributor group", async () => {
  const foreignGroupId = "group-owner";
  let created = false;
  const tx: any = {
    $queryRaw: async () => [{ id: foreignGroupId }],
    guest: {
      findFirst: async () => null,
      create: async ({ data }: any) => {
        created = true;
        return { ...guest("guest-a"), ...data, id: "guest-a" };
      },
    },
  };
  const prisma: any = {
    $transaction: async (operation: (client: any) => Promise<unknown>) =>
      operation(tx),
  };
  const context = contributorContext();
  const service = new (GuestsService as any)(
    prisma,
    {
      assertGuestManageableInTransaction: async (client: unknown) => {
        assert.equal(client, tx);
        return context;
      },
      canManageGuests: () => true,
    },
    { recordForContextInTransaction: async () => undefined },
    {
      qualifyingEntityIdsInTransaction: async (
        client: unknown,
        _planId: string,
        _actorId: string,
        entityTypes: ContributionEntityType[],
      ) => {
        assert.equal(client, tx);
        return entityTypes.includes(ContributionEntityType.GUEST_GROUP)
          ? []
          : [];
      },
    },
  ) as GuestsService;

  await assert.rejects(
    () =>
      service.create({ id: "contributor-a" } as any, "plan-1", {
        name: "Guest A",
        groupId: foreignGroupId,
      } as any),
    /Guest group not found/,
  );
  assert.equal(created, false);
});

test("contributor cannot move an own guest into an owner or another contributor group", async () => {
  const own = guest("guest-a");
  let updated = false;
  const tx: any = {
    $queryRaw: async () => [{ id: "locked" }],
    guest: {
      findUnique: async () => own,
      update: async () => {
        updated = true;
        return own;
      },
    },
  };
  const prisma: any = {
    guest: { findUnique: async () => own },
    $transaction: async (operation: (client: any) => Promise<unknown>) =>
      operation(tx),
  };
  const service = new (GuestsService as any)(
    prisma,
    {
      assertGuestManageableInTransaction: async () => contributorContext(),
      canManageGuests: () => true,
    },
    {},
    {
      qualifyingEntityIdsInTransaction: async (
        _client: unknown,
        _planId: string,
        _actorId: string,
        entityTypes: ContributionEntityType[],
      ) =>
        entityTypes.includes(ContributionEntityType.GUEST_GROUP)
          ? []
          : [own.id],
    },
  ) as GuestsService;

  await assert.rejects(
    () =>
      service.update({ id: "contributor-a" } as any, own.id, {
        groupId: "group-owner",
      }),
    /Guest group not found/,
  );
  assert.equal(updated, false);
});

test("guest live reads authorize and query on one transaction and never inherit a foreign group through an own guest", async () => {
  const own = { ...guest("guest-a"), groupId: "group-owner" };
  const ownGroup = {
    id: "group-a",
    weddingPlanId: "plan-1",
    name: "Own group",
    notes: "own notes",
    sortOrder: 0,
    createdAt: now,
    updatedAt: now,
  };
  const ownerGroup = {
    ...ownGroup,
    id: "group-owner",
    name: "OWNER PRIVATE GROUP",
    notes: "OWNER PRIVATE NOTES",
  };
  const tx: any = {
    guest: {
      findMany: async ({ where, include }: any) => {
        const rows = where.id?.in?.includes(own.id) ? [own] : [];
        return include
          ? rows.map((row) => ({
              ...row,
              group: { name: ownerGroup.name },
            }))
          : rows;
      },
    },
    guestGroup: {
      findMany: async ({ where }: any) =>
        [ownGroup, ownerGroup].filter((group) =>
          where.id?.in?.includes(group.id),
        ),
      count: async ({ where }: any) =>
        [ownGroup, ownerGroup].filter((group) =>
          where.id?.in?.includes(group.id),
        ).length,
    },
  };
  const prisma: any = {
    guest: tx.guest,
    guestGroup: tx.guestGroup,
    $transaction: async (operation: (client: any) => Promise<unknown>) =>
      operation(tx),
  };
  const context = contributorContext();
  const permissions = {
    assertPlanReadable: async () => context,
    assertPlanReadableInTransaction: async (client: unknown) => {
      assert.equal(client, tx);
      return context;
    },
    canManageGuests: () => true,
  };
  const scope = {
    qualifyingEntityIds: async (
      _planId: string,
      _actorId: string,
      entityTypes: ContributionEntityType[],
    ) =>
      entityTypes.includes(ContributionEntityType.GUEST_GROUP)
        ? [ownGroup.id]
        : [own.id],
    qualifyingEntityIdsInTransaction: async (
      client: unknown,
      _planId: string,
      _actorId: string,
      entityTypes: ContributionEntityType[],
    ) => {
      assert.equal(client, tx);
      return entityTypes.includes(ContributionEntityType.GUEST_GROUP)
        ? [ownGroup.id]
        : [own.id];
    },
  };
  const service = new (GuestsService as any)(
    prisma,
    permissions,
    {},
    scope,
  ) as GuestsService;
  const actor = { id: "contributor-a" } as any;

  const rows = await service.findForPlan(actor, "plan-1");
  assert.equal(rows.length, 1);
  assert.equal(rows[0]?.groupId, null);
  assert.deepEqual(
    (await service.findGroups(actor, "plan-1")).map((group) => group.id),
    [ownGroup.id],
  );
  const summary = await service.summary(actor, "plan-1");
  assert.equal(summary.byGroup[ownerGroup.name], undefined);
  assert.equal(summary.byGroup.ungrouped, 1);
});
