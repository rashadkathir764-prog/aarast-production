import {
  ConversationEventType,
  ConversationScope,
  Prisma,
} from '@prisma/client';
import { OutboxEventTypes } from '../platform/outbox/outbox.constants';
import { enqueueOutboxEventInTransaction } from '../platform/outbox/outbox.service';

import type {
  ConversationLifecycleClient,
  EnsureConversationContextInput,
  RecordConversationEventInput,
} from '../modules/messaging/public/conversation-lifecycle.port';
import type { ProviderReadPort } from '../modules/marketplace/public/provider-read.port';
import type { PlanReadPort } from '../modules/planning/public/plan-read.port';
import {
  addCoreConversationParticipants,
  findConversationBlockRow,
  findConversationEventByDedupeKey,
  findConversationProvider,
  insertConversationEvent,
  lockConversationRowForShare,
  lockConversationRowForUpdate,
  setConversationPushStopAt,
  updateConversationActivity,
  upsertAccountConversationContext,
  upsertPlanConversationContext,
} from '../modules/messaging/infrastructure/conversation-lifecycle.repository';

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
    ? await upsertPlanConversationContext(tx, input, activityAt)
    : await upsertAccountConversationContext(tx, input, activityAt);
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
  await addCoreConversationParticipants(tx, conversation.id, [...coreUserIds], activityAt);
  return { id: conversation.id, scope };
}

export async function lockConversationForUpdate(
  tx: ConversationLifecycleClient,
  conversationId: string,
): Promise<boolean> {
  return lockConversationRowForUpdate(tx, conversationId);
}

export async function lockConversationForShare(
  tx: ConversationLifecycleClient,
  conversationId: string,
): Promise<boolean> {
  return lockConversationRowForShare(tx, conversationId);
}

/** RA-BE-169: whether either side blocked the conversation. */
export async function isConversationBlocked(
  tx: ConversationLifecycleClient,
  conversationId: string,
): Promise<boolean> {
  const row = await findConversationBlockRow(tx, conversationId);
  return Boolean(row?.customerSideBlockedAt || row?.providerSideBlockedAt);
}

/** Q-42 (أ): the instant the conversation stops making notices, or null for never. */
export async function setConversationPushStop(
  tx: ConversationLifecycleClient,
  conversationId: string,
  endsAt: Date | null,
): Promise<void> {
  await setConversationPushStopAt(tx, conversationId, endsAt);
}

/**
 * Q-42 (أ): what an event says about the conversation's life. A new request,
 * a new or revised offer and an accepted one start it again; the ending ones
 * are marketplace's to settle once it knows nothing else is alive.
 */
const REOPENING_EVENT_TYPES: ReadonlySet<ConversationEventType> = new Set([
  ConversationEventType.QUOTE_REQUEST_CREATED,
  ConversationEventType.QUOTE_OFFER_RECEIVED,
  ConversationEventType.QUOTE_OFFER_REVISED,
  ConversationEventType.QUOTE_OFFER_ACCEPTED,
]);

export async function findConversationProviderId(
  client: ConversationLifecycleClient,
  conversationId: string,
): Promise<string | null> {
  const conversation = await findConversationProvider(client, conversationId);
  return conversation?.providerId ?? null;
}

export async function recordConversationEvent(
  tx: ConversationLifecycleClient,
  input: RecordConversationEventInput,
) {
  const occurredAt = input.occurredAt ?? new Date();
  const inserted = await insertConversationEvent(tx, input, occurredAt);
  const event = await findConversationEventByDedupeKey(tx, input.dedupeKey);
  if (inserted.count === 0) return { event, created: false };

  await updateConversationActivity(
    tx,
    input.conversationId,
    occurredAt,
    REOPENING_EVENT_TYPES.has(input.type),
  );
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
