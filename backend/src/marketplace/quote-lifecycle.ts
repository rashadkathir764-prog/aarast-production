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

export type QuoteLifecycleActor =
  | 'requester'
  | 'provider'
  | 'provider_offer'
  | 'provider_withdraw'
  | 'expiry';

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
  // B-03: a withdrawn offer gives the request back to the provider, who
  // sends a new offer or declines.
  provider_withdraw: {
    [QuoteRequestStatus.RESPONDED]: [QuoteRequestStatus.VIEWED],
  },
  // B-04: the hourly job ends a request nobody answered in time.
  expiry: {
    [QuoteRequestStatus.SENT]: [QuoteRequestStatus.EXPIRED],
    [QuoteRequestStatus.VIEWED]: [QuoteRequestStatus.EXPIRED],
  },
};

export function assertQuoteRequestTransition(
  current: QuoteRequestStatus,
  next: QuoteRequestStatus,
  actor: QuoteLifecycleActor,
): void {
  if (current === QuoteRequestStatus.EXPIRED) throw quoteRequestExpired();
  const allowed = ALLOWED_TRANSITIONS[actor][current] ?? [];
  if (!allowed.includes(next)) {
    throw new ConflictException(
      `Quote request cannot transition from ${current} to ${next}`,
    );
  }
}

/** B-04: the provider has this many days to answer a request. */
export const QUOTE_REQUEST_ANSWER_DAYS = 7;
const DAY_MS = 24 * 60 * 60 * 1000;

/** When a request waiting from `from` stops waiting for the provider. */
export function quoteRequestAnswerDeadline(from: Date): Date {
  return new Date(from.getTime() + QUOTE_REQUEST_ANSWER_DAYS * DAY_MS);
}

/** Waiting for the provider (SENT or VIEWED) and past its deadline. */
export function isQuoteRequestOverdue(
  request: { status: QuoteRequestStatus; expiresAt: Date },
  now: Date = new Date(),
): boolean {
  return (
    (request.status === QuoteRequestStatus.SENT ||
      request.status === QuoteRequestStatus.VIEWED) &&
    request.expiresAt.getTime() <= now.getTime()
  );
}

/**
 * Whether the customer is told «ما رد … خلال 7 أيام» when the hourly job
 * ends a request. A request the job reaches more than a day after its
 * deadline (the first run after B-04 shipped meets requests months old, or
 * the job was down) ends without that notice: it would announce as news a
 * wait that ended long ago. The timeline still records the end.
 */
export function isQuoteRequestExpiryNoticeTimely(
  expiresAt: Date,
  now: Date = new Date(),
): boolean {
  return now.getTime() - expiresAt.getTime() <= DAY_MS;
}

/**
 * The provider answers (an offer or an apology) only before the deadline.
 * Between the deadline and the hourly job the request is already over.
 */
export function assertQuoteRequestAnswerable(
  request: { status: QuoteRequestStatus; expiresAt: Date },
  now: Date = new Date(),
): void {
  if (
    request.status === QuoteRequestStatus.EXPIRED ||
    isQuoteRequestOverdue(request, now)
  ) {
    throw quoteRequestExpired();
  }
}

function quoteRequestExpired(): ConflictException {
  return new ConflictException({
    code: 'QUOTE_REQUEST_EXPIRED',
    message: `انتهى هذا الطلب: مرت ${QUOTE_REQUEST_ANSWER_DAYS} أيام بدون رد.`,
  });
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
    case QuoteRequestStatus.EXPIRED:
      return 'EXPIRED';
  }
}
