import "reflect-metadata";

import assert from "node:assert/strict";
import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  NotFoundException,
} from "@nestjs/common";
import {
  Prisma,
  PrismaClient,
  SharedMemberRole,
  WeddingPlanStatus,
} from "@prisma/client";
import { ContributorScopeService } from "../../src/modules/collaboration/internal/contributor-scope.service";
import { GuestsService } from "../../src/guests/guests.service";
import {
  TASK_PERMISSION_REVOKED,
  TASK_PERMISSION_REVOKED_MESSAGE,
} from "../../src/modules/collaboration/public/collaboration-permission.port";
import { PermissionService } from "../../src/modules/collaboration/internal/permission.service";
import { ownerPorts, contributionHistoryService } from "./support/owner-ports";
import { TasksService } from "../../src/tasks/tasks.service";

const { assertManagedSmokeEnvironment } = require("./smoke-utils.js") as {
  assertManagedSmokeEnvironment: (environment: NodeJS.ProcessEnv) => {
    runId: string;
  };
};
const { createPermissionRevocationFixture, withFixture } =
  require("../../test/support/phase0-postgres-support.js") as {
    createPermissionRevocationFixture: (
      prisma: unknown,
      environment?: NodeJS.ProcessEnv,
    ) => Promise<any>;
    withFixture: (
      createFixture: (environment: NodeJS.ProcessEnv) => Promise<any>,
      callback: (fixture: any) => Promise<void>,
      environment?: NodeJS.ProcessEnv,
    ) => Promise<void>;
  };

assertManagedSmokeEnvironment(process.env);

const prisma = new PrismaClient();
const permissions = new PermissionService(prisma as any, ownerPorts.plans);
const contributionHistory = contributionHistoryService(prisma, permissions);
const contributorScope = new ContributorScopeService(contributionHistory);
const tasks = new TasksService(
  prisma as any,
  permissions,
  {
    notifyTaskDue: async () => undefined,
  } as any,
  contributionHistory,
  contributorScope,
);
const guests = new GuestsService(
  prisma as any,
  permissions,
  contributionHistory,
  contributorScope,
);

function authenticatedUser(user: {
  id: string;
  name: string;
  phone: string | null;
}) {
  return {
    id: user.id,
    name: user.name,
    phone: user.phone,
  } as any;
}

function deferred(): {
  promise: Promise<void>;
  resolve: () => void;
} {
  let resolve!: () => void;
  const promise = new Promise<void>((done) => {
    resolve = done;
  });
  return { promise, resolve };
}

function assertTaskPermissionRevoked(error: unknown): void {
  assert.ok(error instanceof ForbiddenException);
  assert.deepEqual(error.getResponse(), {
    statusCode: 403,
    code: TASK_PERMISSION_REVOKED,
    message: TASK_PERMISSION_REVOKED_MESSAGE,
  });
}

async function holdUncommittedDomainPermissionRevocation(
  sharedMemberId: string,
): Promise<{ commit: () => Promise<void> }> {
  const revoked = deferred();
  const commitRequested = deferred();
  let committedOnce = false;
  const transaction = prisma.$transaction(
    async (tx) => {
      await tx.sharedMember.update({
        where: { id: sharedMemberId },
        data: {
          role: SharedMemberRole.VIEWER,
          canManageTasks: false,
          canManageGuests: false,
        },
      });
      revoked.resolve();
      await commitRequested.promise;
    },
    { timeout: 20_000 },
  );
  await revoked.promise;
  return {
    commit: async () => {
      if (!committedOnce) {
        committedOnce = true;
        commitRequested.resolve();
      }
      await transaction;
    },
  };
}

async function holdUncommittedPlanArchive(
  weddingPlanId: string,
): Promise<{ commit: () => Promise<void> }> {
  const archived = deferred();
  const commitRequested = deferred();
  let committedOnce = false;
  const transaction = prisma.$transaction(
    async (tx) => {
      await tx.weddingPlan.update({
        where: { id: weddingPlanId },
        data: { status: WeddingPlanStatus.ARCHIVED },
      });
      archived.resolve();
      await commitRequested.promise;
    },
    { timeout: 20_000 },
  );
  await archived.promise;
  return {
    commit: async () => {
      if (!committedOnce) {
        committedOnce = true;
        commitRequested.resolve();
      }
      await transaction;
    },
  };
}

async function holdUncommittedSharedMemberRemoval(
  sharedMemberId: string,
): Promise<{ commit: () => Promise<void> }> {
  const removed = deferred();
  const commitRequested = deferred();
  let committedOnce = false;
  const transaction = prisma.$transaction(
    async (tx) => {
      await tx.sharedMember.delete({ where: { id: sharedMemberId } });
      removed.resolve();
      await commitRequested.promise;
    },
    { timeout: 20_000 },
  );
  await removed.promise;
  return {
    commit: async () => {
      if (!committedOnce) {
        committedOnce = true;
        commitRequested.resolve();
      }
      await transaction;
    },
  };
}

async function holdUncommittedGuestInsert(
  weddingPlanId: string,
  normalizedPhone: string,
): Promise<{ commit: () => Promise<void> }> {
  const inserted = deferred();
  const commitRequested = deferred();
  let committedOnce = false;
  const transaction = prisma.$transaction(
    async (tx) => {
      await tx.guest.create({
        data: {
          weddingPlanId,
          name: "Concurrent duplicate first",
          normalizedName: "Concurrent duplicate first",
          phone: normalizedPhone,
          normalizedPhone,
        },
      });
      inserted.resolve();
      await commitRequested.promise;
    },
    { timeout: 20_000 },
  );
  await inserted.promise;
  return {
    commit: async () => {
      if (!committedOnce) {
        committedOnce = true;
        commitRequested.resolve();
      }
      await transaction;
    },
  };
}

async function holdUncommittedGuestRename(
  guestId: string,
  name: string,
): Promise<{ commit: () => Promise<void> }> {
  const renamed = deferred();
  const commitRequested = deferred();
  let committedOnce = false;
  const transaction = prisma.$transaction(
    async (tx) => {
      await tx.guest.update({
        where: { id: guestId },
        data: {
          name,
          normalizedName: name,
        },
      });
      renamed.resolve();
      await commitRequested.promise;
    },
    { timeout: 20_000 },
  );
  await renamed.promise;
  return {
    commit: async () => {
      if (!committedOnce) {
        committedOnce = true;
        commitRequested.resolve();
      }
      await transaction;
    },
  };
}

async function waitForBlockedMutation(
  operation: Promise<unknown>,
  label: string,
): Promise<void> {
  const state = await Promise.race([
    operation.then(
      () => "settled",
      () => "settled",
    ),
    new Promise<"blocked">((resolve) =>
      setTimeout(() => resolve("blocked"), 75),
    ),
  ]);
  assert.equal(
    state,
    "blocked",
    `${label} must wait for the concurrent lifecycle change`,
  );
}

async function cleanupTaskGuestRows(weddingPlanId: string): Promise<void> {
  await prisma.guest.deleteMany({ where: { weddingPlanId } });
  await prisma.guestGroup.deleteMany({ where: { weddingPlanId } });
  await prisma.weddingTask.deleteMany({ where: { weddingPlanId } });
}

async function assertTaskCreationFailsClosed(): Promise<void> {
  await withFixture(
    (environment) => createPermissionRevocationFixture(prisma, environment),
    async (fixture) => {
      const revocation = await holdUncommittedDomainPermissionRevocation(
        fixture.sharedMember.id,
      );
      const creation = tasks.create(
        authenticatedUser(fixture.member),
        fixture.plan.id,
        { title: "Must not survive task permission revocation" },
      );

      try {
        await waitForBlockedMutation(
          creation,
          "task creation while permission revocation is uncommitted",
        );
        await revocation.commit();
        const [result] = await Promise.allSettled([creation]);
        assert.equal(result?.status, "rejected");
        if (result?.status === "rejected") {
          assertTaskPermissionRevoked(result.reason);
        }
        assert.equal(
          await prisma.weddingTask.count({
            where: {
              weddingPlanId: fixture.plan.id,
              title: "Must not survive task permission revocation",
            },
          }),
          0,
        );
      } finally {
        await revocation.commit();
        await Promise.allSettled([creation]);
        await prisma.weddingTask.deleteMany({
          where: { weddingPlanId: fixture.plan.id },
        });
      }
    },
  );
}

async function assertGuestCreationFailsClosed(): Promise<void> {
  await withFixture(
    (environment) => createPermissionRevocationFixture(prisma, environment),
    async (fixture) => {
      const revocation = await holdUncommittedDomainPermissionRevocation(
        fixture.sharedMember.id,
      );
      const creation = guests.create(
        authenticatedUser(fixture.member),
        fixture.plan.id,
        { name: "Must not survive guest permission revocation" },
      );

      try {
        await waitForBlockedMutation(
          creation,
          "guest creation while permission revocation is uncommitted",
        );
        await revocation.commit();
        const [result] = await Promise.allSettled([creation]);
        assert.equal(result?.status, "rejected");
        if (result?.status === "rejected") {
          assert.ok(result.reason instanceof NotFoundException);
        }
        assert.equal(
          await prisma.guest.count({
            where: {
              weddingPlanId: fixture.plan.id,
              name: "Must not survive guest permission revocation",
            },
          }),
          0,
        );
      } finally {
        await revocation.commit();
        await Promise.allSettled([creation]);
        await prisma.guest.deleteMany({
          where: { weddingPlanId: fixture.plan.id },
        });
      }
    },
  );
}

interface MutationScenario {
  label: string;
  setup: (fixture: any) => Promise<any>;
  mutate: (
    fixture: any,
    state: any,
    currentUser: ReturnType<typeof authenticatedUser>,
  ) => Promise<unknown>;
  verifyUnchanged: (fixture: any, state: any) => Promise<void>;
}

async function createTaskState(
  fixture: any,
  checklistTitle?: string,
): Promise<{ task: any; item?: any }> {
  const task = await prisma.weddingTask.create({
    data: {
      weddingPlanId: fixture.plan.id,
      title: "Task before concurrent mutation",
    },
  });
  const item = checklistTitle
    ? await prisma.weddingTaskChecklistItem.create({
        data: { taskId: task.id, title: checklistTitle },
      })
    : undefined;
  return { task, item };
}

async function createGuestState(fixture: any): Promise<{ guest: any }> {
  const guest = await prisma.guest.create({
    data: {
      weddingPlanId: fixture.plan.id,
      name: "Guest before concurrent mutation",
      normalizedName: "Guest before concurrent mutation",
    },
  });
  return { guest };
}

async function createGuestGroupState(fixture: any): Promise<{ group: any }> {
  const group = await prisma.guestGroup.create({
    data: {
      weddingPlanId: fixture.plan.id,
      name: "Group before concurrent mutation",
    },
  });
  return { group };
}

const taskRevocationScenarios: MutationScenario[] = [
  {
    label: "task update",
    setup: (fixture) => createTaskState(fixture),
    mutate: (_fixture, state, user) =>
      tasks.update(user, state.task.id, {
        title: "Task after revoked update",
      }),
    verifyUnchanged: async (_fixture, state) => {
      const stored = await prisma.weddingTask.findUniqueOrThrow({
        where: { id: state.task.id },
      });
      assert.equal(stored.title, state.task.title);
    },
  },
  {
    label: "task assignment",
    setup: (fixture) => createTaskState(fixture),
    mutate: (fixture, state, user) =>
      tasks.assign(user, state.task.id, {
        assigneeUserId: fixture.owner.id,
      }),
    verifyUnchanged: async (_fixture, state) => {
      const stored = await prisma.weddingTask.findUniqueOrThrow({
        where: { id: state.task.id },
      });
      assert.equal(stored.assigneeUserId, null);
    },
  },
  {
    label: "task checklist creation",
    setup: (fixture) => createTaskState(fixture),
    mutate: (_fixture, state, user) =>
      tasks.createChecklistItem(user, state.task.id, {
        title: "Checklist item after revocation",
      }),
    verifyUnchanged: async (_fixture, state) => {
      assert.equal(
        await prisma.weddingTaskChecklistItem.count({
          where: { taskId: state.task.id },
        }),
        0,
      );
    },
  },
  {
    label: "task checklist update",
    setup: (fixture) =>
      createTaskState(fixture, "Checklist before concurrent mutation"),
    mutate: (_fixture, state, user) =>
      tasks.updateChecklistItem(user, state.task.id, state.item.id, {
        title: "Checklist after revoked update",
      }),
    verifyUnchanged: async (_fixture, state) => {
      const stored = await prisma.weddingTaskChecklistItem.findUniqueOrThrow({
        where: { id: state.item.id },
      });
      assert.equal(stored.title, state.item.title);
    },
  },
  {
    label: "task checklist removal",
    setup: (fixture) =>
      createTaskState(fixture, "Checklist must survive revocation"),
    mutate: (_fixture, state, user) =>
      tasks.removeChecklistItem(user, state.task.id, state.item.id),
    verifyUnchanged: async (_fixture, state) => {
      assert.equal(
        await prisma.weddingTaskChecklistItem.count({
          where: { id: state.item.id },
        }),
        1,
      );
    },
  },
  {
    label: "task removal",
    setup: (fixture) => createTaskState(fixture),
    mutate: (_fixture, state, user) => tasks.remove(user, state.task.id),
    verifyUnchanged: async (_fixture, state) => {
      assert.equal(
        await prisma.weddingTask.count({ where: { id: state.task.id } }),
        1,
      );
    },
  },
];

const guestRevocationScenarios: MutationScenario[] = [
  {
    label: "guest bulk creation",
    setup: async () => ({}),
    mutate: (fixture, _state, user) =>
      guests.bulkCreate(user, fixture.plan.id, {
        items: [
          { name: "Revoked bulk guest one" },
          { name: "Revoked bulk guest two" },
        ],
      }),
    verifyUnchanged: async (fixture) => {
      assert.equal(
        await prisma.guest.count({
          where: {
            weddingPlanId: fixture.plan.id,
            name: { startsWith: "Revoked bulk guest" },
          },
        }),
        0,
      );
    },
  },
  {
    label: "guest update",
    setup: (fixture) => createGuestState(fixture),
    mutate: (_fixture, state, user) =>
      guests.update(user, state.guest.id, {
        notes: "Notes after revoked update",
      }),
    verifyUnchanged: async (_fixture, state) => {
      const stored = await prisma.guest.findUniqueOrThrow({
        where: { id: state.guest.id },
      });
      assert.equal(stored.notes, null);
    },
  },
  {
    label: "guest removal",
    setup: (fixture) => createGuestState(fixture),
    mutate: (_fixture, state, user) => guests.remove(user, state.guest.id),
    verifyUnchanged: async (_fixture, state) => {
      assert.equal(
        await prisma.guest.count({ where: { id: state.guest.id } }),
        1,
      );
    },
  },
  {
    label: "guest group creation",
    setup: async () => ({}),
    mutate: (fixture, _state, user) =>
      guests.createGroup(user, fixture.plan.id, {
        name: "Group after revocation",
      }),
    verifyUnchanged: async (fixture) => {
      assert.equal(
        await prisma.guestGroup.count({
          where: {
            weddingPlanId: fixture.plan.id,
            name: "Group after revocation",
          },
        }),
        0,
      );
    },
  },
  {
    label: "guest group update",
    setup: (fixture) => createGuestGroupState(fixture),
    mutate: (_fixture, state, user) =>
      guests.updateGroup(user, state.group.id, {
        notes: "Notes after revoked group update",
      }),
    verifyUnchanged: async (_fixture, state) => {
      const stored = await prisma.guestGroup.findUniqueOrThrow({
        where: { id: state.group.id },
      });
      assert.equal(stored.notes, null);
    },
  },
  {
    label: "guest group removal",
    setup: (fixture) => createGuestGroupState(fixture),
    mutate: (_fixture, state, user) => guests.removeGroup(user, state.group.id),
    verifyUnchanged: async (_fixture, state) => {
      assert.equal(
        await prisma.guestGroup.count({ where: { id: state.group.id } }),
        1,
      );
    },
  },
];

async function assertPermissionRevocationMatrix(
  scenarios: MutationScenario[],
  expectedError: "TASK_PERMISSION_REVOKED" | "NOT_FOUND",
): Promise<void> {
  for (const scenario of scenarios) {
    await withFixture(
      (environment) => createPermissionRevocationFixture(prisma, environment),
      async (fixture) => {
        const state = await scenario.setup(fixture);
        const revocation = await holdUncommittedDomainPermissionRevocation(
          fixture.sharedMember.id,
        );
        const operation = scenario.mutate(
          fixture,
          state,
          authenticatedUser(fixture.member),
        );

        try {
          await waitForBlockedMutation(
            operation,
            `${scenario.label} while permission revocation is uncommitted`,
          );
          await revocation.commit();
          const [result] = await Promise.allSettled([operation]);
          assert.equal(result?.status, "rejected");
          if (result?.status === "rejected") {
            if (expectedError === "TASK_PERMISSION_REVOKED") {
              assertTaskPermissionRevoked(result.reason);
            } else {
              assert.ok(result.reason instanceof NotFoundException);
            }
          }
          await scenario.verifyUnchanged(fixture, state);
        } finally {
          await revocation.commit();
          await Promise.allSettled([operation]);
          await cleanupTaskGuestRows(fixture.plan.id);
        }
      },
    );
  }
}

const archiveScenarios: MutationScenario[] = [
  {
    label: "task creation",
    setup: async () => ({}),
    mutate: (fixture, _state, user) =>
      tasks.create(user, fixture.plan.id, {
        title: "Task after plan archive",
      }),
    verifyUnchanged: async (fixture) => {
      assert.equal(
        await prisma.weddingTask.count({
          where: {
            weddingPlanId: fixture.plan.id,
            title: "Task after plan archive",
          },
        }),
        0,
      );
    },
  },
  taskRevocationScenarios[0]!,
  taskRevocationScenarios[2]!,
  {
    label: "guest creation",
    setup: async () => ({}),
    mutate: (fixture, _state, user) =>
      guests.create(user, fixture.plan.id, {
        name: "Guest after plan archive",
      }),
    verifyUnchanged: async (fixture) => {
      assert.equal(
        await prisma.guest.count({
          where: {
            weddingPlanId: fixture.plan.id,
            name: "Guest after plan archive",
          },
        }),
        0,
      );
    },
  },
  guestRevocationScenarios[1]!,
  guestRevocationScenarios[5]!,
];

async function assertPlanArchiveMatrix(): Promise<void> {
  for (const scenario of archiveScenarios) {
    await withFixture(
      (environment) => createPermissionRevocationFixture(prisma, environment),
      async (fixture) => {
        const state = await scenario.setup(fixture);
        const archive = await holdUncommittedPlanArchive(fixture.plan.id);
        const operation = scenario.mutate(
          fixture,
          state,
          authenticatedUser(fixture.owner),
        );

        try {
          await waitForBlockedMutation(
            operation,
            `${scenario.label} while plan archive is uncommitted`,
          );
          await archive.commit();
          const [result] = await Promise.allSettled([operation]);
          assert.equal(result?.status, "rejected");
          if (result?.status === "rejected") {
            assert.ok(result.reason instanceof ConflictException);
          }
          await scenario.verifyUnchanged(fixture, state);
        } finally {
          await archive.commit();
          await Promise.allSettled([operation]);
          await cleanupTaskGuestRows(fixture.plan.id);
        }
      },
    );
  }
}

async function assertAssigneeRemovalWinsTaskAssignment(): Promise<void> {
  await withFixture(
    (environment) => createPermissionRevocationFixture(prisma, environment),
    async (fixture) => {
      const { task } = await createTaskState(fixture);
      const removal = await holdUncommittedSharedMemberRemoval(
        fixture.sharedMember.id,
      );
      const assignment = tasks.assign(
        authenticatedUser(fixture.owner),
        task.id,
        { assigneeUserId: fixture.member.id },
      );

      try {
        await waitForBlockedMutation(
          assignment,
          "task assignment while assignee removal is uncommitted",
        );
        await removal.commit();
        const [result] = await Promise.allSettled([assignment]);
        assert.equal(result?.status, "rejected");
        if (result?.status === "rejected") {
          assert.ok(result.reason instanceof BadRequestException);
        }
        const stored = await prisma.weddingTask.findUniqueOrThrow({
          where: { id: task.id },
        });
        assert.equal(stored.assigneeUserId, null);
      } finally {
        await removal.commit();
        await Promise.allSettled([assignment]);
        await cleanupTaskGuestRows(fixture.plan.id);
      }
    },
  );
}

async function assertDuplicateGuestPhoneIsDatabaseAtomic(): Promise<void> {
  await withFixture(
    (environment) => createPermissionRevocationFixture(prisma, environment),
    async (fixture) => {
      const normalizedPhone = "+967711234561";
      const firstInsert = await holdUncommittedGuestInsert(
        fixture.plan.id,
        normalizedPhone,
      );
      const secondInsert = prisma.guest.create({
        data: {
          weddingPlanId: fixture.plan.id,
          name: "Concurrent duplicate second",
          normalizedName: "Concurrent duplicate second",
          phone: normalizedPhone,
          normalizedPhone,
        },
      });

      try {
        await waitForBlockedMutation(
          secondInsert,
          "same-phone guest insert while the first insert is uncommitted",
        );
        await firstInsert.commit();
        const [result] = await Promise.allSettled([secondInsert]);
        assert.equal(result?.status, "rejected");
        if (result?.status === "rejected") {
          assert.ok(
            result.reason instanceof Prisma.PrismaClientKnownRequestError,
          );
          assert.equal(result.reason.code, "P2002");
        }
        assert.equal(
          await prisma.guest.count({
            where: {
              weddingPlanId: fixture.plan.id,
              normalizedPhone,
            },
          }),
          1,
        );
      } finally {
        await firstInsert.commit();
        await Promise.allSettled([secondInsert]);
        await prisma.guest.deleteMany({
          where: { weddingPlanId: fixture.plan.id },
        });
      }
    },
  );
}

async function assertBulkGuestCreationIsAtomic(): Promise<void> {
  await withFixture(
    (environment) => createPermissionRevocationFixture(prisma, environment),
    async (fixture) => {
      const owner = authenticatedUser(fixture.owner);
      const duplicatePhone = "+967711234562";
      const partialGuestName = "Bulk guest must roll back";
      await guests.create(owner, fixture.plan.id, {
        name: "Existing duplicate target",
        phone: duplicatePhone,
      });

      try {
        const [result] = await Promise.allSettled([
          guests.bulkCreate(owner, fixture.plan.id, {
            items: [
              { name: partialGuestName },
              {
                name: "Different name with duplicate phone",
                phone: duplicatePhone,
              },
            ],
          }),
        ]);
        assert.equal(result?.status, "rejected");
        if (result?.status === "rejected") {
          assert.ok(result.reason instanceof ConflictException);
        }
        assert.equal(
          await prisma.guest.count({
            where: {
              weddingPlanId: fixture.plan.id,
              name: partialGuestName,
            },
          }),
          0,
          "a failed bulk request must not retain earlier guests",
        );
      } finally {
        await prisma.guest.deleteMany({
          where: { weddingPlanId: fixture.plan.id },
        });
      }
    },
  );
}

async function assertGuestNormalizationSurvivesConcurrentRename(): Promise<void> {
  await withFixture(
    (environment) => createPermissionRevocationFixture(prisma, environment),
    async (fixture) => {
      const owner = authenticatedUser(fixture.owner);
      const guest = await guests.create(owner, fixture.plan.id, {
        name: "Original guest name",
      });
      const renamedName = "Concurrent renamed guest";
      const rename = await holdUncommittedGuestRename(guest.id, renamedName);
      const notesUpdate = guests.update(owner, guest.id, {
        notes: "Notes written after the rename",
      });

      try {
        await waitForBlockedMutation(
          notesUpdate,
          "notes-only update while a guest rename is uncommitted",
        );
        await rename.commit();
        await notesUpdate;
        const stored = await prisma.guest.findUniqueOrThrow({
          where: { id: guest.id },
        });
        assert.equal(stored.name, renamedName);
        assert.equal(
          stored.normalizedName,
          renamedName,
          "name and normalizedName must remain one atomic value pair",
        );
      } finally {
        await rename.commit();
        await Promise.allSettled([notesUpdate]);
        await prisma.guest.deleteMany({
          where: { weddingPlanId: fixture.plan.id },
        });
      }
    },
  );
}

async function main(): Promise<void> {
  try {
    const requestedCase = process.env.PHASE2_DOMAIN_CASE;
    if (!requestedCase || requestedCase === "task") {
      await assertTaskCreationFailsClosed();
    }
    if (!requestedCase || requestedCase === "guest") {
      await assertGuestCreationFailsClosed();
    }
    if (!requestedCase || requestedCase === "task-matrix") {
      await assertPermissionRevocationMatrix(
        taskRevocationScenarios,
        "TASK_PERMISSION_REVOKED",
      );
    }
    if (!requestedCase || requestedCase === "guest-matrix") {
      await assertPermissionRevocationMatrix(
        guestRevocationScenarios,
        "NOT_FOUND",
      );
    }
    if (!requestedCase || requestedCase === "archive-matrix") {
      await assertPlanArchiveMatrix();
    }
    if (!requestedCase || requestedCase === "assignee-removal") {
      await assertAssigneeRemovalWinsTaskAssignment();
    }
    if (!requestedCase || requestedCase === "guest-duplicate") {
      await assertDuplicateGuestPhoneIsDatabaseAtomic();
    }
    if (!requestedCase || requestedCase === "guest-bulk") {
      await assertBulkGuestCreationIsAtomic();
    }
    if (!requestedCase || requestedCase === "guest-normalization") {
      await assertGuestNormalizationSurvivesConcurrentRename();
    }
    console.log(
      "PASS - Phase 2 task and guest mutations serialize permissions, lifecycle, and domain invariants.",
    );
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
