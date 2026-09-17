import {
  ConversationEventType,
  ConversationScope,
  Prisma,
} from '@prisma/client';
import { randomUUID } from 'crypto';
import { OutboxEventTypes } from '../platform/outbox/outbox.constants';
import { enqueueOutboxEventInTransaction } from '../platform/outbox/outbox.service';

import type {
  ConversationLifecycleClient,
  EnsureConversationContextInput,
  RecordConversationEventInput,
} from '../modules/messaging/public/conversation-lifecycle.port';
import type { ProviderReadPort } from '../modules/marketplace/public/provider-read.port';
import type { PlanReadPort } from '../modules/planning/public/plan-read.port';

/** The owners a new conversation's core participants are read from: planning for the plan owner, marketplace for the provider account. */
export interface ConversationContextOwners {
  plans: PlanReadPort;
  providers: ProviderReadPort;
}

export async function ensureConversationContext(
  tx: ConversationLifecycleClient,
  input: EnsureConversationContextInput,
  owners: ConversationContextOwners,
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
    const plan = await owners.plans.getPlan(tx, input.weddingPlanId);
    if (!plan) throw new Error('ConversationWeddingPlanMissing');
    coreUserIds.add(plan.ownerUserId);
  } else {
    coreUserIds.add(input.requesterUserId);
  }
  const provider = await owners.providers.getProvider(tx, input.providerId);
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

export async function lockConversationForUpdate(
  tx: ConversationLifecycleClient,
  conversationId: string,
): Promise<boolean> {
  const rows = await tx.$queryRaw<Array<{ id: string }>>(Prisma.sql`
    SELECT "id"
    FROM "Conversation"
    WHERE "id" = ${conversationId}
    FOR UPDATE
  `);
  return rows.length === 1;
}

export async function lockConversationForShare(
  tx: ConversationLifecycleClient,
  conversationId: string,
): Promise<boolean> {
  const rows = await tx.$queryRaw<Array<{ id: string }>>(Prisma.sql`
    SELECT "id"
    FROM "Conversation"
    WHERE "id" = ${conversationId}
    FOR SHARE
  `);
  return rows.length === 1;
}

export async function findConversationProviderId(
  client: ConversationLifecycleClient,
  conversationId: string,
): Promise<string | null> {
  const conversation = await client.conversation.findUnique({
    where: { id: conversationId },
    select: { providerId: true },
  });
  return conversation?.providerId ?? null;
}

export async function recordConversationEvent(
  tx: ConversationLifecycleClient,
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
  await enqueueOutboxEventInTransaction(tx, {
    type: OutboxEventTypes.conversationActivityAvailable,
    aggregateType: 'conversation',
    aggregateId: input.conversationId,
    payload: {
      conversationId: input.conversationId,
      eventId: event.id,
      activityKind: 'EVENT',
    },
  });
  return { event, created: true };
}

function conversationId(): string {
  return `conv_${randomUUID().replaceAll('-', '')}`;
}
