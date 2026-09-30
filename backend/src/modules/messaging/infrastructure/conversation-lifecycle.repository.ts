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

export function upsertPlanConversationContext(
  tx: ConversationLifecycleClient,
  input: EnsureConversationContextInput,
  activityAt: Date,
) {
  return tx.$queryRaw<Array<{ id: string }>>(Prisma.sql`
    INSERT INTO "Conversation" (
      "id", "scope", "weddingPlanId", "providerId", "createdByUserId",
      "lastActivityAt", "createdAt", "updatedAt"
    ) VALUES (
      ${conversationId()}, 'PLAN'::"ConversationScope",
      ${input.weddingPlanId}, ${input.providerId}, ${input.requesterUserId},
      ${activityAt}, ${activityAt}, ${activityAt}
    )
    ON CONFLICT ("weddingPlanId", "providerId") WHERE "scope" = 'PLAN'
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
) {
  return tx.conversation.update({
    where: { id: conversationId },
    data: { lastActivityAt: occurredAt },
  });
}
