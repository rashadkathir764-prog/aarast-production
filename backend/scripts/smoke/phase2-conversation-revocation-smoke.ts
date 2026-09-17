import "reflect-metadata";

import assert from "node:assert/strict";
import {
  ConflictException,
  ForbiddenException,
  NotFoundException,
} from "@nestjs/common";
import {
  PrismaClient,
  ProviderStatus,
  UserStatus,
  WeddingPlanStatus,
} from "@prisma/client";
import { ConversationsService } from "../../src/conversations/conversations.service";
import { NotificationsService } from "../../src/notifications/notifications.service";
import { OutboxService } from "../../src/platform/outbox/outbox.service";
import { PermissionService } from "../../src/modules/collaboration/internal/permission.service";
import { ownerPorts, contributionHistoryService, sharingService } from "./support/owner-ports";

const { assertManagedSmokeEnvironment } = require("./smoke-utils.js") as {
  assertManagedSmokeEnvironment: (
    environment: NodeJS.ProcessEnv,
  ) => { runId: string };
};
const {
  createPermissionRevocationFixture,
  createQuoteDecisionFixture,
  withFixture,
} = require("../../test/support/phase0-postgres-support.js") as {
  createPermissionRevocationFixture: (
    prisma: unknown,
    environment?: NodeJS.ProcessEnv,
  ) => Promise<any>;
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
const outbox = new OutboxService();
const permissions = new PermissionService(prisma as any, ownerPorts.plans);
const history = contributionHistoryService(prisma, permissions);
const notifications = new NotificationsService(
  prisma as any,
  permissions,
  outbox,
);
const repetitions = Number(
  process.env.PHASE2_CHAT_RACE_REPETITIONS ?? "1",
);
if (
  !Number.isInteger(repetitions) ||
  repetitions < 1 ||
  repetitions > 100
) {
  throw new Error(
    "PHASE2_CHAT_RACE_REPETITIONS must be an integer from 1 to 100.",
  );
}

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

async function holdUncommittedProviderSuspension(
  providerId: string,
): Promise<{ commit: () => Promise<void> }> {
  const suspended = deferred();
  const commitRequested = deferred();
  let committedOnce = false;
  const transaction = prisma.$transaction(
    async (tx) => {
      await tx.provider.update({
        where: { id: providerId },
        data: { status: ProviderStatus.SUSPENDED },
      });
      suspended.resolve();
      await commitRequested.promise;
    },
    { timeout: 20_000 },
  );
  await suspended.promise;
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

async function holdUncommittedUserDisable(
  userId: string,
): Promise<{ commit: () => Promise<void> }> {
  const disabled = deferred();
  const commitRequested = deferred();
  let committedOnce = false;
  const transaction = prisma.$transaction(
    async (tx) => {
      await tx.user.update({
        where: { id: userId },
        data: { status: UserStatus.DISABLED },
      });
      disabled.resolve();
      await commitRequested.promise;
    },
    { timeout: 20_000 },
  );
  await disabled.promise;
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

async function holdUncommittedMemberRevocation(
  fixture: any,
): Promise<{ commit: () => Promise<void> }> {
  const revoked = deferred();
  const commitRequested = deferred();
  let committedOnce = false;
  const transaction = prisma.$transaction(
    async (tx) => {
      await tx.sharedMember.update({
        where: { id: fixture.sharedMember.id },
        data: { canManageProviders: false },
      });
      revoked.resolve();
      await commitRequested.promise;
      await tx.conversationParticipant.updateMany({
        where: {
          conversationId: fixture.conversation.id,
          userId: fixture.member.id,
          revokedAt: null,
        },
        data: { revokedAt: new Date() },
      });
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
  assert.equal(state, "blocked", `${label} must be waiting on the row lock`);
}

function serviceDependencies() {
  const realtime = {
    revoked: [] as Array<{ userId: string; conversationIds: string[] }>,
    message: () => undefined,
    read: () => undefined,
    activityAvailable: () => undefined,
    revokeConversationAccess(
      userId: string,
      conversationIds: string[],
    ) {
      this.revoked.push({ userId, conversationIds });
    },
  };
  const mediaStorage = {
    verifyUpload: async () => {
      throw new Error("No attachment expected");
    },
    createDownloadUrl: async () => {
      throw new Error("No attachment expected");
    },
    consumeUpload: async () => {
      throw new Error("No attachment expected");
    },
  };
  return { realtime, mediaStorage };
}

function gatedTransactionPrisma() {
  const transactionReached = deferred();
  const releaseTransaction = deferred();
  let intercepted = false;
  const proxy = new Proxy(prisma as any, {
    get(target, property, receiver) {
      if (property === "$transaction") {
        return (input: unknown, ...args: unknown[]) => {
          if (typeof input === "function" && !intercepted) {
            intercepted = true;
            transactionReached.resolve();
            return releaseTransaction.promise.then(() =>
              target.$transaction(input, ...args),
            );
          }
          return target.$transaction(input, ...args);
        };
      }
      const value = Reflect.get(target, property, receiver);
      return typeof value === "function" ? value.bind(target) : value;
    },
  });
  return {
    prisma: proxy,
    transactionReached: transactionReached.promise,
    release: releaseTransaction.resolve,
  };
}

function conversationsService(
  prismaClient: any,
  realtime: any,
  mediaStorage: any,
) {
  return new ConversationsService(
    prismaClient,
    notifications,
    realtime,
    mediaStorage,
    outbox,
  );
}

async function assertRevocationWinsBeforeMessage(): Promise<void> {
  await withFixture(
    (environment) =>
      createPermissionRevocationFixture(prisma, environment),
    async (fixture) => {
      await prisma.conversationParticipant.createMany({
        data: [
          {
            conversationId: fixture.conversation.id,
            userId: fixture.owner.id,
          },
          {
            conversationId: fixture.conversation.id,
            userId: fixture.providerUser.id,
          },
        ],
        skipDuplicates: true,
      });
      const dependencies = serviceDependencies();
      const gated = gatedTransactionPrisma();
      const conversations = conversationsService(
        gated.prisma,
        dependencies.realtime,
        dependencies.mediaStorage,
      );
      const sharing = sharingService(
        prisma,
        permissions,
        notifications,
        {} as any,
        history,
        dependencies.realtime as any,
      );
      const send = conversations.send(
        authenticatedUser(fixture.member),
        fixture.conversation.id,
        { body: "Must be rejected after permission revocation" },
      );

      try {
        await gated.transactionReached;
        await sharing.updateMemberForPlan(
          authenticatedUser(fixture.owner),
          fixture.plan.id,
          fixture.sharedMember.id,
          { canManageProviders: false },
        );
      } finally {
        gated.release();
      }

      const result = await Promise.allSettled([send]);
      assert.equal(
        result[0]?.status,
        "rejected",
        "a committed permission revocation must win before message commit",
      );
      if (result[0]?.status === "rejected") {
        assert.ok(result[0].reason instanceof NotFoundException);
      }
      assert.equal(
        await prisma.chatMessage.count({
          where: {
            conversationId: fixture.conversation.id,
            senderUserId: fixture.member.id,
          },
        }),
        0,
      );
      assert.equal(
        await prisma.notification.count({
          where: {
            type: "CHAT_MESSAGE_RECEIVED",
            entityId: fixture.conversation.id,
          },
        }),
        0,
      );
      assert.equal(
        await prisma.outboxEvent.count({
          where: {
            aggregateType: "conversation",
            aggregateId: fixture.conversation.id,
          },
        }),
        0,
      );
      const participant =
        await prisma.conversationParticipant.findUniqueOrThrow({
          where: {
            conversationId_userId: {
              conversationId: fixture.conversation.id,
              userId: fixture.member.id,
            },
          },
        });
      assert.ok(participant.revokedAt);
      await assert.rejects(
        conversations.markRead(
          authenticatedUser(fixture.member),
          fixture.conversation.id,
        ),
        NotFoundException,
      );
      const afterRead =
        await prisma.conversationParticipant.findUniqueOrThrow({
          where: {
            conversationId_userId: {
              conversationId: fixture.conversation.id,
              userId: fixture.member.id,
            },
          },
        });
      assert.equal(
        afterRead.revokedAt?.getTime(),
        participant.revokedAt?.getTime(),
      );
      assert.equal(afterRead.lastReadAt, null);
      assert.ok(
        dependencies.realtime.revoked.some(
          (entry) =>
            entry.userId === fixture.member.id &&
            entry.conversationIds.includes(fixture.conversation.id),
        ),
      );
      await sharing.updateMemberForPlan(
        authenticatedUser(fixture.owner),
        fixture.plan.id,
        fixture.sharedMember.id,
        { canManageProviders: true },
      );
      const restoredParticipant =
        await prisma.conversationParticipant.findUniqueOrThrow({
          where: {
            conversationId_userId: {
              conversationId: fixture.conversation.id,
              userId: fixture.member.id,
            },
          },
        });
      assert.equal(restoredParticipant.revokedAt, null);
      const restoredMessage = await conversations.send(
        authenticatedUser(fixture.member),
        fixture.conversation.id,
        { body: "Permission restored explicitly" },
      );
      assert.equal(restoredMessage.body, "Permission restored explicitly");
    },
  );
}

async function assertProviderCanJoinBySendingWhileCustomerWaits(): Promise<void> {
  await withFixture(
    (environment) => createQuoteDecisionFixture(prisma, environment),
    async (fixture) => {
      const dependencies = serviceDependencies();
      const conversations = conversationsService(
        prisma,
        dependencies.realtime,
        dependencies.mediaStorage,
      );
      const owner = authenticatedUser(fixture.owner);
      const provider = authenticatedUser(fixture.providerUser);

      const beforeJoin = await conversations.get(
        owner,
        fixture.conversation.id,
      );
      assert.equal(beforeJoin.providerJoined, false);
      assert.equal(beforeJoin.canSend, false);
      await assert.rejects(
        conversations.send(owner, fixture.conversation.id, {
          body: "Must wait for provider",
        }),
        (error: unknown) =>
          error instanceof ConflictException &&
          (error.getResponse() as { code?: string }).code ===
            "PROVIDER_NOT_JOINED",
      );
      assert.equal(
        await prisma.chatMessage.count({
          where: { conversationId: fixture.conversation.id },
        }),
        0,
      );

      const providerMessage = await conversations.send(
        provider,
        fixture.conversation.id,
        { body: "Provider joins with the first send" },
      );
      assert.equal(
        providerMessage.body,
        "Provider joins with the first send",
      );
      const afterProviderSend = await conversations.get(
        owner,
        fixture.conversation.id,
      );
      assert.equal(afterProviderSend.providerJoined, true);
      const sent = await conversations.send(
        owner,
        fixture.conversation.id,
        { body: "Provider has joined" },
      );
      assert.equal(sent.body, "Provider has joined");
    },
  );
}

async function assertIndependentProviderAuthoritySurvivesMemberRevocation(): Promise<void> {
  await withFixture(
    (environment) =>
      createPermissionRevocationFixture(prisma, environment),
    async (fixture) => {
      await prisma.provider.update({
        where: { id: fixture.provider.id },
        data: { userId: fixture.member.id },
      });
      const dependencies = serviceDependencies();
      const sharing = sharingService(
        prisma,
        permissions,
        notifications,
        {} as any,
        history,
        dependencies.realtime as any,
      );
      const conversations = conversationsService(
        prisma,
        dependencies.realtime,
        dependencies.mediaStorage,
      );

      await sharing.updateMemberForPlan(
        authenticatedUser(fixture.owner),
        fixture.plan.id,
        fixture.sharedMember.id,
        { canManageProviders: false },
      );

      const participant =
        await prisma.conversationParticipant.findUniqueOrThrow({
          where: {
            conversationId_userId: {
              conversationId: fixture.conversation.id,
              userId: fixture.member.id,
            },
          },
        });
      assert.equal(participant.revokedAt, null);
      assert.equal(dependencies.realtime.revoked.length, 0);
      const sent = await conversations.send(
        authenticatedUser(fixture.member),
        fixture.conversation.id,
        { body: "Independent provider authority remains active" },
      );
      assert.equal(
        sent.body,
        "Independent provider authority remains active",
      );
    },
  );
}

async function assertProviderSuspensionWinsBeforeMessage(): Promise<void> {
  await withFixture(
    (environment) => createQuoteDecisionFixture(prisma, environment),
    async (fixture) => {
      const dependencies = serviceDependencies();
      const conversations = conversationsService(
        prisma,
        dependencies.realtime,
        dependencies.mediaStorage,
      );
      const suspension = await holdUncommittedProviderSuspension(
        fixture.provider.id,
      );
      const send = conversations.send(
        authenticatedUser(fixture.providerUser),
        fixture.conversation.id,
        { body: "Must be rejected after provider suspension" },
      );

      try {
        await waitForBlockedMutation(
          send,
          "provider send while suspension is uncommitted",
        );
        await suspension.commit();

        const [result] = await Promise.allSettled([send]);
        assert.equal(
          result?.status,
          "rejected",
          "provider suspension must reject the waiting message",
        );
        if (result?.status === "rejected") {
          assert.ok(result.reason instanceof ForbiddenException);
          const response = result.reason.getResponse();
          assert.equal(
            typeof response === "object" && response !== null
              ? (response as { code?: unknown }).code
              : undefined,
            "PROVIDER_NOT_ACTIVE",
          );
        }
        assert.equal(
          await prisma.chatMessage.count({
            where: {
              conversationId: fixture.conversation.id,
              senderUserId: fixture.providerUser.id,
            },
          }),
          0,
        );
        assert.equal(
          await prisma.notification.count({
            where: {
              type: "CHAT_MESSAGE_RECEIVED",
              entityId: fixture.conversation.id,
            },
          }),
          0,
        );
        assert.equal(
          await prisma.outboxEvent.count({
            where: {
              aggregateType: "conversation",
              aggregateId: fixture.conversation.id,
            },
          }),
          0,
        );
      } finally {
        await suspension.commit();
      }
    },
  );
}

async function assertPlanArchiveWinsBeforeMessage(): Promise<void> {
  await withFixture(
    (environment) => createQuoteDecisionFixture(prisma, environment),
    async (fixture) => {
      const dependencies = serviceDependencies();
      const conversations = conversationsService(
        prisma,
        dependencies.realtime,
        dependencies.mediaStorage,
      );
      const archive = await holdUncommittedPlanArchive(fixture.plan.id);
      const send = conversations.send(
        authenticatedUser(fixture.providerUser),
        fixture.conversation.id,
        { body: "Must be rejected after plan archive" },
      );

      try {
        await waitForBlockedMutation(
          send,
          "provider send while plan archive is uncommitted",
        );
        await archive.commit();
        const [result] = await Promise.allSettled([send]);
        assert.equal(result?.status, "rejected");
        if (result?.status === "rejected") {
          assert.ok(result.reason instanceof ConflictException);
          const response = result.reason.getResponse();
          assert.equal(
            typeof response === "object" && response !== null
              ? (response as { code?: unknown }).code
              : undefined,
            "PLAN_ARCHIVED_READ_ONLY",
          );
        }
        assert.equal(
          await prisma.chatMessage.count({
            where: {
              conversationId: fixture.conversation.id,
              senderUserId: fixture.providerUser.id,
            },
          }),
          0,
        );
      } finally {
        await archive.commit();
      }
    },
  );
}

async function assertDisabledActorCannotFinishMessage(): Promise<void> {
  await withFixture(
    (environment) => createQuoteDecisionFixture(prisma, environment),
    async (fixture) => {
      const dependencies = serviceDependencies();
      const conversations = conversationsService(
        prisma,
        dependencies.realtime,
        dependencies.mediaStorage,
      );
      const disable = await holdUncommittedUserDisable(
        fixture.providerUser.id,
      );
      const send = conversations.send(
        authenticatedUser(fixture.providerUser),
        fixture.conversation.id,
        { body: "Must be rejected after actor disable" },
      );

      try {
        await waitForBlockedMutation(
          send,
          "provider send while actor disable is uncommitted",
        );
        await disable.commit();
        const [result] = await Promise.allSettled([send]);
        assert.equal(
          result?.status,
          "rejected",
          "a disabled actor must not finish a conversation write",
        );
        assert.equal(
          await prisma.chatMessage.count({
            where: {
              conversationId: fixture.conversation.id,
              senderUserId: fixture.providerUser.id,
            },
          }),
          0,
        );
      } finally {
        await disable.commit();
      }
    },
  );
}

async function assertMemberRevocationWinsEveryPersonalMutation(): Promise<void> {
  const scenarios = [
    {
      label: "mark read",
      mutate: (
        conversations: ConversationsService,
        user: ReturnType<typeof authenticatedUser>,
        conversationId: string,
      ) => conversations.markRead(user, conversationId),
    },
    {
      label: "mute",
      mutate: (
        conversations: ConversationsService,
        user: ReturnType<typeof authenticatedUser>,
        conversationId: string,
      ) => conversations.setMuted(user, conversationId, true),
    },
    {
      label: "block",
      mutate: (
        conversations: ConversationsService,
        user: ReturnType<typeof authenticatedUser>,
        conversationId: string,
      ) => conversations.setBlocked(user, conversationId, true),
    },
    {
      label: "report",
      mutate: (
        conversations: ConversationsService,
        user: ReturnType<typeof authenticatedUser>,
        conversationId: string,
      ) =>
        conversations.report(
          user,
          conversationId,
          "Deterministic revocation report",
        ),
    },
  ] as const;

  for (const scenario of scenarios) {
    await withFixture(
      (environment) =>
        createPermissionRevocationFixture(prisma, environment),
      async (fixture) => {
        await prisma.conversationParticipant.createMany({
          data: [
            {
              conversationId: fixture.conversation.id,
              userId: fixture.member.id,
            },
          ],
          skipDuplicates: true,
        });
        const dependencies = serviceDependencies();
        const conversations = conversationsService(
          prisma,
          dependencies.realtime,
          dependencies.mediaStorage,
        );
        const revocation = await holdUncommittedMemberRevocation(fixture);
        const mutation = scenario.mutate(
          conversations,
          authenticatedUser(fixture.member),
          fixture.conversation.id,
        );

        try {
          await waitForBlockedMutation(
            mutation,
            `${scenario.label} while member revocation is uncommitted`,
          );
          await revocation.commit();
          const [result] = await Promise.allSettled([mutation]);
          assert.equal(
            result?.status,
            "rejected",
            `${scenario.label} must reject after member revocation`,
          );
          if (result?.status === "rejected") {
            assert.ok(result.reason instanceof NotFoundException);
          }
        } finally {
          await revocation.commit();
        }

        const participant =
          await prisma.conversationParticipant.findUniqueOrThrow({
            where: {
              conversationId_userId: {
                conversationId: fixture.conversation.id,
                userId: fixture.member.id,
              },
            },
          });
        assert.equal(participant.lastReadAt, null);
        assert.equal(participant.mutedAt, null);
        const conversation = await prisma.conversation.findUniqueOrThrow({
          where: { id: fixture.conversation.id },
        });
        assert.equal(conversation.customerSideBlockedAt, null);
        assert.equal(conversation.providerSideBlockedAt, null);
        assert.equal(
          await prisma.conversationReport.count({
            where: {
              conversationId: fixture.conversation.id,
              reporterUserId: fixture.member.id,
            },
          }),
          0,
        );
      },
    );
  }
}

async function assertRecipientRevocationSuppressesNotification(): Promise<void> {
  await withFixture(
    (environment) =>
      createPermissionRevocationFixture(prisma, environment),
    async (fixture) => {
      await prisma.conversationParticipant.createMany({
        data: [
          {
            conversationId: fixture.conversation.id,
            userId: fixture.member.id,
          },
          {
            conversationId: fixture.conversation.id,
            userId: fixture.providerUser.id,
          },
        ],
        skipDuplicates: true,
      });
      const dependencies = serviceDependencies();
      const conversations = conversationsService(
        prisma,
        dependencies.realtime,
        dependencies.mediaStorage,
      );
      const revocation = await holdUncommittedMemberRevocation(fixture);
      const send = conversations.send(
        authenticatedUser(fixture.providerUser),
        fixture.conversation.id,
        { body: "Recipient revocation must suppress notification" },
      );

      try {
        await waitForBlockedMutation(
          send,
          "provider send while recipient revocation is uncommitted",
        );
        await revocation.commit();
        const [result] = await Promise.allSettled([send]);
        assert.equal(result?.status, "fulfilled");
        assert.equal(
          await prisma.notification.count({
            where: {
              userId: fixture.member.id,
              type: "CHAT_MESSAGE_RECEIVED",
              entityId: fixture.conversation.id,
            },
          }),
          0,
        );
      } finally {
        await revocation.commit();
      }
    },
  );
}

async function main(): Promise<void> {
  try {
    for (let iteration = 0; iteration < repetitions; iteration += 1) {
      await assertRevocationWinsBeforeMessage();
      await assertProviderSuspensionWinsBeforeMessage();
      await assertPlanArchiveWinsBeforeMessage();
      await assertDisabledActorCannotFinishMessage();
      await assertMemberRevocationWinsEveryPersonalMutation();
      await assertRecipientRevocationSuppressesNotification();
    }
    await assertProviderCanJoinBySendingWhileCustomerWaits();
    await assertIndependentProviderAuthoritySurvivesMemberRevocation();
    console.log(
      `PASS - Phase 2 conversation revocation is transactional and provider join stays explicit (${repetitions} repetition(s)).`,
    );
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
