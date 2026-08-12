import {
  ConversationEventType,
  ConversationScope,
  Prisma,
} from '@prisma/client';
import { randomUUID } from 'crypto';
import { OutboxEventTypes } from '../platform/outbox/outbox.constants';

type ConversationTransaction = Pick<
  Prisma.TransactionClient,
  | '$queryRaw'
  | 'conversation'
  | 'conversationEvent'
  | 'conversationParticipant'
  | 'outboxEvent'
  | 'provider'
  | 'weddingPlan'
>;

export interface EnsureConversationContextInput {
  requesterUserId: string;
  providerId: string;
  weddingPlanId: string | null;
  activityAt?: Date;
}

export async function ensureConversationContext(
  tx: ConversationTransaction,
  input: EnsureConversationContextInput,
): Promise<{ id: string; scope: ConversationScope }> {
  const activityAt = input.activityAt ?? new Date();
  const scope = input.weddingPlanId
    ? ConversationScope.PLAN
    : ConversationScope.ACCOUNT;
  const rows = input.weddingPlanId
    ? await tx.$queryRaw<Array<{ id: string }>>(Prisma.sql`
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
      `)
    : await tx.$queryRaw<Array<{ id: string }>>(Prisma.sql`
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
  const conversation = rows[0];
  if (!conversation) {
    throw new Error('ConversationContextUpsertFailed');
  }

  const coreUserIds = new Set<string>();
  if (input.weddingPlanId) {
    const plan = await tx.weddingPlan.findUnique({
      where: { id: input.weddingPlanId },
      select: { ownerUserId: true },
    });
    if (!plan) throw new Error('ConversationWeddingPlanMissing');
    coreUserIds.add(plan.ownerUserId);
  } else {
    coreUserIds.add(input.requesterUserId);
  }
  const provider = await tx.provider.findUnique({
    where: { id: input.providerId },
    select: { userId: true },
  });
  if (provider?.userId) coreUserIds.add(provider.userId);
  await tx.conversationParticipant.createMany({
    data: [...coreUserIds].map((userId) => ({
      conversationId: conversation.id,
      userId,
      joinedAt: activityAt,
    })),
    skipDuplicates: true,
  });
  return { id: conversation.id, scope };
}

export interface RecordConversationEventInput {
  conversationId: string;
  quoteRequestId?: string | null;
  quoteOfferId?: string | null;
  actorUserId?: string | null;
  type: ConversationEventType;
  occurredAt?: Date;
  dedupeKey: string;
  data?: Prisma.InputJsonObject;
}

export async function recordConversationEvent(
  tx: ConversationTransaction,
  input: RecordConversationEventInput,
) {
  const occurredAt = input.occurredAt ?? new Date();
  const inserted = await tx.conversationEvent.createMany({
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
  const event = await tx.conversationEvent.findUniqueOrThrow({
    where: { dedupeKey: input.dedupeKey },
  });
  if (inserted.count === 0) return { event, created: false };

  await tx.conversation.update({
    where: { id: input.conversationId },
    data: { lastActivityAt: occurredAt },
  });
  await tx.outboxEvent.create({
    data: {
      type: OutboxEventTypes.conversationActivityAvailable,
      aggregateType: 'conversation',
      aggregateId: input.conversationId,
      payload: {
        conversationId: input.conversationId,
        eventId: event.id,
        activityKind: 'EVENT',
      },
    },
  });
  return { event, created: true };
}

function conversationId(): string {
  return `conv_${randomUUID().replaceAll('-', '')}`;
}
