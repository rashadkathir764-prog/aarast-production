import type { Prisma } from '@prisma/client';
import type { ConversationLifecyclePort } from '../modules/messaging/public/conversation-lifecycle.port';
import { conversationHasLiveWork } from '../modules/marketplace/infrastructure/marketplace-booking.repository';

/**
 * Q-42 (أ), RA-BE-170: a conversation stays open to writing after a request
 * is declined, cancelled or expired or a booking ends, and its messages make
 * no notice or phone alert after this many days.
 */
export const CONVERSATION_PUSH_WINDOW_DAYS = 30;
const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * Called in the transaction that ended a request or a booking (its new state
 * already written): when nothing else in the conversation is alive, its
 * messages stop making notices 30 days after [endedAt]; when something is,
 * they carry on.
 */
export async function settleConversationPush(
  tx: Prisma.TransactionClient,
  lifecycle: Pick<ConversationLifecyclePort, 'setConversationPushStopInTransaction'>,
  conversationId: string,
  endedAt: Date,
): Promise<void> {
  const alive = await conversationHasLiveWork(tx, conversationId);
  await lifecycle.setConversationPushStopInTransaction(
    tx,
    conversationId,
    alive ? null : new Date(endedAt.getTime() + CONVERSATION_PUSH_WINDOW_DAYS * DAY_MS),
  );
}
