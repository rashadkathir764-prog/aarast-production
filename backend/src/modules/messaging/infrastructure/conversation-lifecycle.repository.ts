import { Prisma } from '@prisma/client';
import { randomUUID } from 'node:crypto';
import type {
  ConversationLifecycleClient,
  EnsureConversationContextInput,
  RecordConversationEventInput,
} from '../public/conversation-lifecycle.port';

function conversationId(): string {
  return `conv_${randomUUID().replaceAll('-', '')}`;
}

// RA-BE-139 (Q-33 (أ)): the plan's one thread with the provider for its
// owner and partners.
export function upsertPlanConversationContext(
  tx: ConversationLifecycleClient,
  input: EnsureConversationContextInput,
  activityAt: Date,
) {
  return tx.$queryRaw<Array<{ id: string }>>(Prisma.sql`
    INSERT INTO "Conversation" (
      "id", "scope", "weddingPlanId", "providerId", "createdByUserId",
      "helperThread", "lastActivityAt", "createdAt", "updatedAt"
    ) VALUES (
      ${conversationId()}, 'PLAN'::"ConversationScope",
      ${input.weddingPlanId}, ${input.providerId}, ${input.requesterUserId},
      false, ${activityAt}, ${activityAt}, ${activityAt}
    )
    ON CONFLICT ("weddingPlanId", "providerId") WHERE "scope" = 'PLAN' AND NOT "helperThread"
    DO UPDATE SET
      "lastActivityAt" = GREATEST("Conversation"."lastActivityAt", EXCLUDED."lastActivityAt"),
      "updatedAt" = GREATEST("Conversation"."updatedAt", EXCLUDED."updatedAt")
    RETURNING "id"
  `);
}

// RA-BE-139 (Q-33 (أ)): a helper's own thread with the provider in the plan.
// A new one starts with the plan's block with the provider: the provider's
// side from any thread of the plan with him (his block reaches them all),
// the owner's side as it stands on the shared thread.
export function upsertPlanHelperConversationContext(
  tx: ConversationLifecycleClient,
  input: EnsureConversationContextInput,
  helperUserId: string,
  activityAt: Date,
) {
  return tx.$queryRaw<Array<{ id: string }>>(Prisma.sql`
    INSERT INTO "Conversation" (
      "id", "scope", "weddingPlanId", "providerId", "createdByUserId",
      "helperThread", "helperUserId", "lastActivityAt", "createdAt", "updatedAt",
      "customerSideBlockedAt", "customerSideBlockedById", "providerSideBlockedAt"
    )
    SELECT
      ${conversationId()}, 'PLAN'::"ConversationScope",
      ${input.weddingPlanId}, ${input.providerId}, ${input.requesterUserId},
      true, ${helperUserId}, ${activityAt}, ${activityAt}, ${activityAt},
      shared."customerSideBlockedAt", shared."customerSideBlockedById",
      (
        SELECT max("providerSideBlockedAt") FROM "Conversation"
        WHERE "scope" = 'PLAN' AND "weddingPlanId" = ${input.weddingPlanId}
          AND "providerId" = ${input.providerId}
      )
    FROM (SELECT 1) AS one
    LEFT JOIN "Conversation" shared
      ON shared."scope" = 'PLAN' AND shared."weddingPlanId" = ${input.weddingPlanId}
     AND shared."providerId" = ${input.providerId} AND NOT shared."helperThread"
    ON CONFLICT ("weddingPlanId", "providerId", "helperUserId") WHERE "scope" = 'PLAN' AND "helperThread"
    DO UPDATE SET
      "lastActivityAt" = GREATEST("Conversation"."lastActivityAt", EXCLUDED."lastActivityAt"),
      "updatedAt" = GREATEST("Conversation"."updatedAt", EXCLUDED."updatedAt")
    RETURNING "id"
  `);
}

export function upsertAccountConversationContext(
  tx: ConversationLifecycleClient,
  input: EnsureConversationContextInput,
  activityAt: Date,
) {
  return tx.$queryRaw<Array<{ id: string }>>(Prisma.sql`
    INSERT INTO "Conversation" (
      "id", "scope", "accountRequesterUserId", "providerId", "createdByUserId",
      "lastActivityAt", "createdAt", "updatedAt"
    ) VALUES (
      ${conversationId()}, 'ACCOUNT'::"ConversationScope",
      ${input.requesterUserId}, ${input.providerId}, ${input.requesterUserId},
      ${activityAt}, ${activityAt}, ${activityAt}
    )
    ON CONFLICT ("accountRequesterUserId", "providerId") WHERE "scope" = 'ACCOUNT'
    DO UPDATE SET
      "lastActivityAt" = GREATEST("Conversation"."lastActivityAt", EXCLUDED."lastActivityAt"),
      "updatedAt" = GREATEST("Conversation"."updatedAt", EXCLUDED."updatedAt")
    RETURNING "id"
  `);
}

export function addCoreConversationParticipants(
  tx: ConversationLifecycleClient,
  conversationId: string,
  userIds: readonly string[],
  activityAt: Date,
) {
  return tx.conversationParticipant.createMany({
    data: userIds.map((userId) => ({ conversationId, userId, joinedAt: activityAt })),
    skipDuplicates: true,
  });
}

export async function lockConversationRowForUpdate(
  tx: ConversationLifecycleClient,
  conversationId: string,
): Promise<boolean> {
  const rows = await tx.$queryRaw<Array<{ id: string }>>(Prisma.sql`
    SELECT "id" FROM "Conversation" WHERE "id" = ${conversationId} FOR UPDATE
  `);
  return rows.length === 1;
}

export async function lockConversationRowForShare(
  tx: ConversationLifecycleClient,
  conversationId: string,
): Promise<boolean> {
  const rows = await tx.$queryRaw<Array<{ id: string }>>(Prisma.sql`
    SELECT "id" FROM "Conversation" WHERE "id" = ${conversationId} FOR SHARE
  `);
  return rows.length === 1;
}

/**
 * RA-BE-169: the conversation's two block marks, read on the caller's
 * transaction (which holds the row's share lock); null when it is gone.
 */
export async function findConversationBlockRow(
  tx: ConversationLifecycleClient,
  conversationId: string,
): Promise<{ customerSideBlockedAt: Date | null; providerSideBlockedAt: Date | null } | null> {
  const rows = await tx.$queryRaw<
    Array<{ customerSideBlockedAt: Date | null; providerSideBlockedAt: Date | null }>
  >(Prisma.sql`
    SELECT "customerSideBlockedAt", "providerSideBlockedAt" FROM "Conversation" WHERE "id" = ${conversationId}
  `);
  return rows[0] ?? null;
}

export function findConversationProvider(
  client: ConversationLifecycleClient,
  conversationId: string,
) {
  return client.conversation.findUnique({
    where: { id: conversationId },
    select: { providerId: true },
  });
}

export function insertConversationEvent(
  tx: ConversationLifecycleClient,
  input: RecordConversationEventInput,
  occurredAt: Date,
) {
  return tx.conversationEvent.createMany({
    data: [
      {
        conversationId: input.conversationId,
        quoteRequestId: input.quoteRequestId ?? null,
        quoteOfferId: input.quoteOfferId ?? null,
        actorUserId: input.actorUserId ?? null,
        type: input.type,
        occurredAt,
        dedupeKey: input.dedupeKey,
        ...(input.data ? { data: input.data } : {}),
      },
    ],
    skipDuplicates: true,
  });
}

export function findConversationEventByDedupeKey(
  tx: ConversationLifecycleClient,
  dedupeKey: string,
) {
  return tx.conversationEvent.findUniqueOrThrow({ where: { dedupeKey } });
}

export function updateConversationActivity(
  tx: ConversationLifecycleClient,
  conversationId: string,
  occurredAt: Date,
  reopens = false,
) {
  return tx.conversation.update({
    where: { id: conversationId },
    data: { lastActivityAt: occurredAt, ...(reopens ? { pushStopsAt: null } : {}) },
  });
}

export function setConversationPushStopAt(
  tx: ConversationLifecycleClient,
  conversationId: string,
  pushStopsAt: Date | null,
) {
  return tx.conversation.update({
    where: { id: conversationId },
    data: { pushStopsAt },
  });
}
