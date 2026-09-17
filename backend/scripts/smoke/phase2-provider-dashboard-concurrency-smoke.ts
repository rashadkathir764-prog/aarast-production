import type { ConversationLifecyclePort } from "../../src/modules/messaging/public/conversation-lifecycle.port";
import { findConversationProviderId, lockConversationForShare, lockConversationForUpdate } from "../../src/conversations/conversation-lifecycle";

const lifecycle: ConversationLifecyclePort = {
  ensureConversationContext: async () => { throw new Error("Unexpected ensureConversationContext"); },
  recordConversationEvent: async () => { throw new Error("Unexpected recordConversationEvent"); },
  lockConversationForUpdateInTransaction: lockConversationForUpdate,
  lockConversationForShareInTransaction: lockConversationForShare,
  findConversationProviderId,
};
import "reflect-metadata";

import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import {
  AdminRole,
  AppRole,
  Prisma,
  PrismaClient,
  ProviderStatus,
  UserRole,
  UserStatus,
  WeddingPlanStatus,
} from "@prisma/client";
import { AdminService } from "../../src/admin/admin.service";
import { ProviderDashboardService } from "../../src/provider-dashboard/provider-dashboard.service";
import { providerDashboardService } from "./support/owner-ports";

const { assertManagedSmokeEnvironment } = require("./smoke-utils.js") as {
  assertManagedSmokeEnvironment: (
    environment: NodeJS.ProcessEnv,
  ) => { runId: string };
};
const {
  createQuoteDecisionFixture,
  withFixture,
} = require("../../test/support/phase0-postgres-support.js") as {
  createQuoteDecisionFixture: (
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
const notifications = {
  createNotificationInTransaction: async () => null,
};
const media = {
  verifyPublicMediaUrl: async (
    _user: unknown,
    value: string | null | undefined,
  ) => value?.trim() || null,
  scheduleTargetDeletion: async (
    target: { type: string; id: string },
    tx: Prisma.TransactionClient,
  ) => {
    await tx.$queryRaw`
      SELECT 1 AS locked
      FROM (
        SELECT pg_advisory_xact_lock(
          hashtextextended(${`${target.type}:${target.id}`}, 20260712)
        )
      ) acquired
    `;
  },
  consumePublicMediaUrl: async (
    _user: unknown,
    _value: string,
    _purpose: string,
    target: { type: string; id: string },
    tx: Prisma.TransactionClient,
  ) => {
    await tx.$queryRaw`
      SELECT 1 AS locked
      FROM (
        SELECT pg_advisory_xact_lock(
          hashtextextended(${`${target.type}:${target.id}`}, 20260712)
        )
      ) acquired
    `;
  },
};

function providerUser(user: any) {
  return {
    ...user,
    role: UserRole.PROVIDER,
    appRole: AppRole.PROVIDER,
    status: UserStatus.ACTIVE,
  } as any;
}

function scopedPhone(scope: string): string {
  const digits = createHash("sha256")
    .update(`${scope}:provider-reviewer`)
    .digest("hex")
    .split("")
    .map((character) => String(Number.parseInt(character, 16) % 10))
    .join("");
  return `+9677${digits.slice(0, 7)}`;
}

function deferred() {
  let resolve!: () => void;
  const promise = new Promise<void>((done) => {
    resolve = done;
  });
  return { promise, resolve };
}

async function holdMutation(
  operation: (tx: Prisma.TransactionClient) => Promise<void>,
): Promise<{ commit: () => Promise<void> }> {
  const acquired = deferred();
  const release = deferred();
  let committed = false;
  const transaction = prisma.$transaction(
    async (tx) => {
      await operation(tx);
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

async function waitForBlocked(operation: Promise<unknown>, label: string) {
  const state = await Promise.race([
    operation.then(
      () => "settled",
      () => "settled",
    ),
    new Promise<"blocked">((resolve) =>
      setTimeout(() => resolve("blocked"), 75),
    ),
  ]);
  assert.equal(state, "blocked", `${label} must wait on the lifecycle lock`);
}

function errorCode(error: unknown): unknown {
  const response = (error as { getResponse?: () => unknown })?.getResponse?.();
  return typeof response === "object" && response !== null
    ? (response as { code?: unknown }).code
    : undefined;
}

async function providerSuspensionWinsQuoteUpdate() {
  await withFixture(
    (environment) => createQuoteDecisionFixture(prisma, environment),
    async (fixture) => {
      const service = providerDashboardService(
        prisma,
        notifications,
        media,
        lifecycle,
      );
      const before = await prisma.quoteOffer.findUniqueOrThrow({
        where: { id: fixture.offer.id },
      });
      const suspension = await holdMutation(async (tx) => {
        await tx.provider.update({
          where: { id: fixture.provider.id },
          data: { status: ProviderStatus.SUSPENDED },
        });
      });
      const update = service.updateQuoteOffer(
        providerUser(fixture.providerUser),
        fixture.offer.id,
        { message: "must-not-commit" },
      );
      try {
        await waitForBlocked(update, "quote update during provider suspension");
        await suspension.commit();
        const [result] = await Promise.allSettled([update]);
        assert.equal(result?.status, "rejected");
        if (result?.status === "rejected") {
          assert.equal(errorCode(result.reason), "PROVIDER_NOT_ACTIVE");
        }
        const after = await prisma.quoteOffer.findUniqueOrThrow({
          where: { id: fixture.offer.id },
        });
        assert.equal(after.message, before.message);
      } finally {
        await suspension.commit();
        await Promise.allSettled([update]);
      }
    },
  );
}

async function planArchiveWinsQuoteUpdate() {
  await withFixture(
    (environment) => createQuoteDecisionFixture(prisma, environment),
    async (fixture) => {
      const service = providerDashboardService(
        prisma,
        notifications,
        media,
        lifecycle,
      );
      const archive = await holdMutation(async (tx) => {
        await tx.weddingPlan.update({
          where: { id: fixture.plan.id },
          data: { status: WeddingPlanStatus.ARCHIVED },
        });
      });
      const update = service.updateQuoteOffer(
        providerUser(fixture.providerUser),
        fixture.offer.id,
        { amount: "999" },
      );
      try {
        await waitForBlocked(update, "quote update during plan archive");
        await archive.commit();
        const [result] = await Promise.allSettled([update]);
        assert.equal(result?.status, "rejected");
        if (result?.status === "rejected") {
          assert.equal(errorCode(result.reason), "PLAN_ARCHIVED_READ_ONLY");
        }
        const after = await prisma.quoteOffer.findUniqueOrThrow({
          where: { id: fixture.offer.id },
        });
        assert.equal(after.amount?.toString(), "100");
      } finally {
        await archive.commit();
        await Promise.allSettled([update]);
      }
    },
  );
}

async function conversationPrecedesQuoteRow() {
  await withFixture(
    (environment) => createQuoteDecisionFixture(prisma, environment),
    async (fixture) => {
      const service = providerDashboardService(
        prisma,
        notifications,
        media,
        lifecycle,
      );
      const blocker = await holdMutation(async (tx) => {
        await tx.$queryRaw(
          Prisma.sql`
            SELECT "id"
            FROM "Conversation"
            WHERE "id" = ${fixture.conversation.id}
            FOR UPDATE
          `,
        );
      });
      const update = service.updateQuoteOffer(
        providerUser(fixture.providerUser),
        fixture.offer.id,
        { title: "ordered-locks" },
      );
      try {
        await waitForBlocked(update, "quote update behind conversation lock");
        await prisma.$transaction(async (tx) => {
          await tx.$queryRaw(
            Prisma.sql`
              SELECT "id"
              FROM "QuoteRequest"
              WHERE "id" = ${fixture.quoteRequest.id}
              FOR UPDATE NOWAIT
            `,
          );
        });
        await blocker.commit();
        await update;
      } finally {
        await blocker.commit();
        await Promise.allSettled([update]);
      }
    },
  );
}

async function imagePrecedesMediaTarget() {
  await withFixture(
    (environment) => createQuoteDecisionFixture(prisma, environment),
    async (fixture) => {
      const image = await prisma.providerServiceImage.create({
        data: {
          serviceId: fixture.service.id,
          imageUrl: "https://media.invalid/old.webp",
        },
      });
      const service = providerDashboardService(
        prisma,
        notifications,
        media,
        lifecycle,
      );
      const blocker = await holdMutation(async (tx) => {
        await tx.$queryRaw(
          Prisma.sql`
            SELECT "id"
            FROM "ProviderServiceImage"
            WHERE "id" = ${image.id}
            FOR UPDATE
          `,
        );
      });
      const update = service.updateServiceImage(
        providerUser(fixture.providerUser),
        fixture.service.id,
        image.id,
        { imageUrl: "https://media.invalid/new.webp" },
      );
      try {
        await waitForBlocked(update, "image update behind image row");
        const [probe] = await prisma.$queryRaw<Array<{ locked: boolean }>>`
          SELECT pg_try_advisory_xact_lock(
            hashtextextended(${`SERVICE_IMAGE:${image.id}`}, 20260712)
          ) AS locked
        `;
        assert.equal(
          probe?.locked,
          true,
          "image update must not hold the media target while waiting for Image",
        );
        await blocker.commit();
        await update;
      } finally {
        await blocker.commit();
        await Promise.allSettled([update]);
      }
    },
  );
}

async function userDisableWinsServiceCreate() {
  await withFixture(
    (environment) => createQuoteDecisionFixture(prisma, environment),
    async (fixture) => {
      const service = providerDashboardService(
        prisma,
        notifications,
        media,
        lifecycle,
      );
      const before = await prisma.providerService.count({
        where: { providerId: fixture.provider.id },
      });
      const disable = await holdMutation(async (tx) => {
        await tx.user.update({
          where: { id: fixture.providerUser.id },
          data: { status: UserStatus.DISABLED },
        });
      });
      const create = service.createService(
        providerUser(fixture.providerUser),
        {
          categoryId: fixture.category.id,
          cityId: fixture.city.id,
          title: "must-not-commit",
        },
      );
      try {
        await waitForBlocked(create, "service create during account disable");
        await disable.commit();
        const [result] = await Promise.allSettled([create]);
        assert.equal(result?.status, "rejected");
        assert.equal(
          await prisma.providerService.count({
            where: { providerId: fixture.provider.id },
          }),
          before,
        );
      } finally {
        await disable.commit();
        await Promise.allSettled([create]);
      }
    },
  );
}

async function adminLocksOwnerBeforeProvider() {
  await withFixture(
    (environment) => createQuoteDecisionFixture(prisma, environment),
    async (fixture) => {
      const admin = await prisma.user.create({
        data: {
          name: "Phase 2 provider reviewer",
          phone: scopedPhone(fixture.scope),
          passwordHash: "phase2-test-fixture-not-a-credential",
          phoneVerifiedAt: new Date(),
          role: UserRole.ADMIN,
          adminRole: AdminRole.OPERATIONS,
        },
      });
      try {
        await prisma.provider.update({
          where: { id: fixture.provider.id },
          data: { status: ProviderStatus.SUSPENDED },
        });
        const ownerBlocker = await holdMutation(async (tx) => {
          await tx.$queryRaw(
            Prisma.sql`
              SELECT "id"
              FROM "User"
              WHERE "id" = ${fixture.providerUser.id}
              FOR UPDATE
            `,
          );
        });
        const service = new AdminService(
          prisma as any,
          {
            revokeConversationAccess: () => undefined,
          } as any,
          {
            createNotificationInTransaction: async () => null,
          } as any,
        );
        const activate = service.activateProvider(
          {
            ...admin,
            adminMfa: true,
            sessionScope: "admin",
          } as any,
          fixture.provider.id,
        );
        try {
          await waitForBlocked(activate, "provider activation behind owner User");
          await prisma.$transaction(async (tx) => {
            await tx.$queryRaw(
              Prisma.sql`
                SELECT "id"
                FROM "Provider"
                WHERE "id" = ${fixture.provider.id}
                FOR UPDATE NOWAIT
              `,
            );
          });
          await ownerBlocker.commit();
          await activate;
        } finally {
          await ownerBlocker.commit();
          await Promise.allSettled([activate]);
        }
      } finally {
        await prisma.user.deleteMany({ where: { id: admin.id } });
      }
    },
  );
}

async function main() {
  try {
    await providerSuspensionWinsQuoteUpdate();
    await planArchiveWinsQuoteUpdate();
    await conversationPrecedesQuoteRow();
    await imagePrecedesMediaTarget();
    await userDisableWinsServiceCreate();
    await adminLocksOwnerBeforeProvider();
    console.log(
      "PASS - provider dashboard writes and admin lifecycle serialize against status, plan, account, conversation, quote, and media locks.",
    );
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
