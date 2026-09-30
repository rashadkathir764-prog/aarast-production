import { ConflictException } from '@nestjs/common';
import { Prisma, QuoteRequestStatus } from '@prisma/client';
import type { ConversationLifecyclePort } from '../modules/messaging/public/conversation-lifecycle.port';
import {
  findQuoteOfferConversation,
  findQuoteRequestConversation,
  lockQuoteOfferRow,
  lockQuoteRequestForOffer,
  lockQuoteRequestRow,
} from '../modules/marketplace/infrastructure/quote-lifecycle.repository';

export type QuoteLifecycleActor = 'requester' | 'provider' | 'provider_offer';

export async function lockQuoteRequestTransitionRow(
  tx: Prisma.TransactionClient,
  lifecycle: ConversationLifecyclePort,
  quoteRequestId: string,
): Promise<boolean> {
  // The conversation row is messaging's: its id is read from the request
  // (set at creation, never changed) and the row locked by its owner first.
  const request = await findQuoteRequestConversation(tx, quoteRequestId);
  if (!request) return false;
  if (
    !(await lifecycle.lockConversationForUpdateInTransaction(
      tx,
      request.conversationId,
    ))
  ) {
    return false;
  }

  return lockQuoteRequestRow(tx, quoteRequestId);
}

export async function lockQuoteOfferTransitionRows(
  tx: Prisma.TransactionClient,
  lifecycle: ConversationLifecyclePort,
  quoteOfferId: string,
): Promise<{ quoteRequestId: string } | null> {
  // Conversation events update the shared conversation row. Lock it before
  // request/offer rows so quote transitions match account deletion and cannot
  // deadlock as QuoteRequest -> Conversation versus Conversation -> QuoteRequest.
  const offer = await findQuoteOfferConversation(tx, quoteOfferId);
  if (!offer) return null;
  if (
    !(await lifecycle.lockConversationForUpdateInTransaction(
      tx,
      offer.quoteRequest.conversationId,
    ))
  ) {
    return null;
  }

  // Every quote transition then takes the request row and the offer row in
  // that order. The final state is always re-read under all three locks.
  const request = await lockQuoteRequestForOffer(tx, quoteOfferId);
  if (!request) return null;
  return (await lockQuoteOfferRow(tx, quoteOfferId)) ? request : null;
}

const ALLOWED_TRANSITIONS: Record<
  QuoteLifecycleActor,
  Partial<Record<QuoteRequestStatus, readonly QuoteRequestStatus[]>>
> = {
  requester: {
    [QuoteRequestStatus.SENT]: [QuoteRequestStatus.CANCELLED],
    [QuoteRequestStatus.VIEWED]: [QuoteRequestStatus.CANCELLED],
    [QuoteRequestStatus.RESPONDED]: [
      QuoteRequestStatus.ACCEPTED,
      QuoteRequestStatus.REJECTED,
    ],
  },
  provider: {
    [QuoteRequestStatus.SENT]: [
      QuoteRequestStatus.VIEWED,
      QuoteRequestStatus.REJECTED,
    ],
    [QuoteRequestStatus.VIEWED]: [QuoteRequestStatus.REJECTED],
  },
  provider_offer: {
    [QuoteRequestStatus.SENT]: [QuoteRequestStatus.RESPONDED],
    [QuoteRequestStatus.VIEWED]: [QuoteRequestStatus.RESPONDED],
  },
};

export function assertQuoteRequestTransition(
  current: QuoteRequestStatus,
  next: QuoteRequestStatus,
  actor: QuoteLifecycleActor,
): void {
  const allowed = ALLOWED_TRANSITIONS[actor][current] ?? [];
  if (!allowed.includes(next)) {
    throw new ConflictException(
      `Quote request cannot transition from ${current} to ${next}`,
    );
  }
}

export function quoteLifecycleStatus(status: QuoteRequestStatus): string {
  switch (status) {
    case QuoteRequestStatus.SENT:
    case QuoteRequestStatus.VIEWED:
      return 'PENDING_PROVIDER';
    case QuoteRequestStatus.RESPONDED:
      return 'RECEIVED';
    case QuoteRequestStatus.ACCEPTED:
      return 'ACCEPTED';
    case QuoteRequestStatus.REJECTED:
      return 'REJECTED';
    case QuoteRequestStatus.CANCELLED:
      return 'CANCELLED';
  }
}
