import "reflect-metadata";

import assert from "node:assert/strict";
import {
  AdminRole,
  Prisma,
  PrismaClient,
  ProviderStatus,
  UserRole,
  UserStatus,
} from "@prisma/client";
import { ForbiddenException } from "@nestjs/common";
import { notificationsService, ownerPorts, adminService } from "./support/owner-ports";
import { PermissionService } from "../../src/modules/collaboration/internal/permission.service";
import { OutboxService } from "../../src/platform/outbox/outbox.service";

const { assertManagedSmokeEnvironment } = require("./smoke-utils.js") as {
  assertManagedSmokeEnvironment: (environment: NodeJS.ProcessEnv) => {
    runId: string;
  };
};

assertManagedSmokeEnvironment(process.env);
const runId = process.env.AARAST_SMOKE_RUN_ID!;
const prisma = new PrismaClient();
const label = `Admin mutation ${runId}`;
const slugPrefix = runId.replace(/_/g, "-");

function deferred() {
  let resolve!: () => void;
  const promise = new Promise<void>((done) => {
    resolve = done;
  });
  return { promise, resolve };
}

async function holdActorMutation(
  actorId: string,
  data: { status?: UserStatus; adminRole?: AdminRole },
): Promise<{ commit: () => Promise<void> }> {
  const acquired = deferred();
  const release = deferred();
  let committed = false;
  const transaction = prisma.$transaction(
    async (tx) => {
      await tx.$queryRaw(
        Prisma.sql`
          SELECT "id"
          FROM "User"
          WHERE "id" = ${actorId}
          FOR UPDATE
        `,
      );
      await tx.user.update({ where: { id: actorId }, data });
      acquired.resolve();
      await release.promise;
    },
    { timeout: 20_000 },
  );
  await acquired.promise;
  return {
    commit: async () => {
      if (!committed) {
        committed = true;
        release.resolve();
      }
      await transaction;
    },
  };
}

async function assertBlocked(
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
  assert.equal(state, "blocked", `${label} must wait for the actor row lock`);
}

async function assertRejectedAfterActorChange(
  operation: Promise<unknown>,
  blocker: { commit: () => Promise<void> },
): Promise<void> {
  try {
    await assertBlocked(operation, "admin mutation");
    await blocker.commit();
    await assert.rejects(operation, ForbiddenException);
  } finally {
    await blocker.commit();
    await Promise.allSettled([operation]);
  }
}

async function main(): Promise<void> {
  const actor = await prisma.user.create({
    data: {
      name: `${label} actor`,
      passwordHash: "managed-smoke-not-a-credential",
      role: UserRole.ADMIN,
      adminRole: AdminRole.OPERATIONS,
      status: UserStatus.ACTIVE,
    },
  });
  const revokedConversationIds: string[][] = [];
  const disconnectedUsers: string[] = [];
  const notifications = notificationsService(
    prisma,
    new PermissionService(prisma as any, ownerPorts.plans),
    new OutboxService(),
  );
  const service = adminService(
    prisma as any,
    {
      disconnectUser: (userId: string) => disconnectedUsers.push(userId),
      revokeConversationAccess: (_userId: string, conversationIds: string[]) =>
        revokedConversationIds.push(conversationIds),
    } as any,
    notifications,
  );
  const authenticatedActor = {
    ...actor,
    adminMfa: true,
    sessionScope: "admin",
  } as any;

  const disabledBlocker = await holdActorMutation(actor.id, {
    status: UserStatus.DISABLED,
  });
  const disabledAttempt = service.createCategory(authenticatedActor, {
    nameAr: `${label} disabled`,
    slug: `${slugPrefix}-disabled`,
  });
  await assertRejectedAfterActorChange(disabledAttempt, disabledBlocker);
  assert.equal(
    await prisma.providerCategory.count({
      where: { slug: `${slugPrefix}-disabled` },
    }),
    0,
  );

  await prisma.user.update({
    where: { id: actor.id },
    data: {
      status: UserStatus.ACTIVE,
      adminRole: AdminRole.OPERATIONS,
    },
  });
  const permissionBlocker = await holdActorMutation(actor.id, {
    adminRole: AdminRole.SUPPORT,
  });
  const permissionAttempt = service.createCategory(authenticatedActor, {
    nameAr: `${label} permission`,
    slug: `${slugPrefix}-permission`,
  });
  await assertRejectedAfterActorChange(permissionAttempt, permissionBlocker);
  assert.equal(
    await prisma.providerCategory.count({
      where: { slug: `${slugPrefix}-permission` },
    }),
    0,
  );

  await prisma.user.update({
    where: { id: actor.id },
    data: { adminRole: AdminRole.OPERATIONS },
  });
  const createdCategory = await service.createCategory(authenticatedActor, {
    nameAr: `${label} authorized`,
    slug: `${slugPrefix}-authorized`,
  });
  assert.equal(createdCategory.slug, `${slugPrefix}-authorized`);

  const target = await prisma.user.create({
    data: {
      name: `${label} disabled target`,
      passwordHash: "managed-smoke-not-a-credential",
    },
  });
  await service.disableUser(authenticatedActor, target.id);
  const [disabledTarget, sessionRevocation] = await Promise.all([
    prisma.user.findUniqueOrThrow({ where: { id: target.id } }),
    prisma.outboxEvent.findFirst({
      where: {
        type: "USER_SESSIONS_REVOKED",
        aggregateType: "user",
        aggregateId: target.id,
      },
    }),
  ]);
  assert.equal(disabledTarget.status, UserStatus.DISABLED);
  assert.deepEqual(sessionRevocation?.payload, { userId: target.id });
  assert.deepEqual(disconnectedUsers, [target.id]);

  const [providerOwner, customer, city] = await Promise.all([
    prisma.user.create({
      data: {
        name: `${label} provider owner`,
        passwordHash: "managed-smoke-not-a-credential",
        role: UserRole.PROVIDER,
      },
    }),
    prisma.user.create({
      data: {
        name: `${label} customer`,
        passwordHash: "managed-smoke-not-a-credential",
      },
    }),
    prisma.city.create({
      data: {
        nameAr: `${label} city`,
        countryCode: "ZZ",
      },
    }),
  ]);
  const provider = await prisma.provider.create({
    data: {
      userId: providerOwner.id,
      cityId: city.id,
      businessName: `${label} provider`,
      phone: `provider-${runId}`,
      status: ProviderStatus.ACTIVE,
    },
  });
  const plan = await prisma.weddingPlan.create({
    data: {
      ownerUserId: customer.id,
      title: `${label} plan`,
    },
  });
  const conversation = await prisma.conversation.create({
    data: {
      scope: "PLAN",
      weddingPlanId: plan.id,
      providerId: provider.id,
      createdByUserId: customer.id,
    },
  });

  await service.suspendProvider(authenticatedActor, provider.id, {
    reason: "managed smoke",
  });
  const [suspendedProvider, accessRevocation, lifecycleNotification] =
    await Promise.all([
      prisma.provider.findUniqueOrThrow({ where: { id: provider.id } }),
      prisma.outboxEvent.findFirst({
        where: {
          type: "CONVERSATION_ACCESS_REVOKED",
          aggregateType: "user",
          aggregateId: providerOwner.id,
        },
      }),
      prisma.notification.findFirst({
        where: {
          userId: providerOwner.id,
          entityType: "Provider",
          entityId: provider.id,
        },
      }),
    ]);
  assert.equal(suspendedProvider.status, ProviderStatus.SUSPENDED);
  assert.deepEqual(accessRevocation?.payload, {
    userId: providerOwner.id,
    conversationIds: [conversation.id],
  });
  assert.deepEqual(revokedConversationIds, [[conversation.id]]);
  // B-19: a suspension is its own notice type, opening the portal.
  assert.equal(lifecycleNotification?.type, "PROVIDER_SUSPENDED");
  assert.equal(lifecycleNotification?.routeTarget, "/provider/dashboard");
  assert.equal(
    (lifecycleNotification?.data as { providerStatus?: string })
      ?.providerStatus,
    ProviderStatus.SUSPENDED,
  );

  console.log(
    "PASS - admin mutations reauthorize the locked live actor, reject revoked authority, and persist realtime revocations in the same transaction.",
  );
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
