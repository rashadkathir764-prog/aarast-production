import "reflect-metadata";

import assert from "node:assert/strict";
import { ConflictException, NotFoundException } from "@nestjs/common";
import { PrismaClient } from "@prisma/client";
import { ConversationsService } from "../../src/conversations/conversations.service";
import { NotificationsService } from "../../src/notifications/notifications.service";
import { OutboxService } from "../../src/outbox/outbox.service";
import { SharingService } from "../../src/sharing/sharing.service";
import { PermissionService } from "../../src/sharing/permission.service";

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
const permissions = new PermissionService(prisma as any);
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
      const sharing = new SharingService(
        prisma as any,
        permissions,
        notifications,
        {} as any,
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
      const sharing = new SharingService(
        prisma as any,
        permissions,
        notifications,
        {} as any,
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

async function main(): Promise<void> {
  try {
    for (let iteration = 0; iteration < repetitions; iteration += 1) {
      await assertRevocationWinsBeforeMessage();
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
