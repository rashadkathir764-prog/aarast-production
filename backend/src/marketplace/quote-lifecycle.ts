import { ConflictException } from '@nestjs/common';
import { Prisma, QuoteRequestStatus } from '@prisma/client';
import type { ConversationLifecyclePort } from '../modules/messaging/public/conversation-lifecycle.port';

export type QuoteLifecycleActor = 'requester' | 'provider' | 'provider_offer';

export async function lockQuoteRequestTransitionRow(
  tx: Prisma.TransactionClient,
  lifecycle: ConversationLifecyclePort,
  quoteRequestId: string,
): Promise<boolean> {
  // The conversation row is messaging's: its id is read from the request
  // (set at creation, never changed) and the row locked by its owner first.
  const request = await tx.quoteRequest.findUnique({
    where: { id: quoteRequestId },
    select: { conversationId: true },
  });
  if (!request) return false;
  if (
    !(await lifecycle.lockConversationForUpdateInTransaction(
      tx,
      request.conversationId,
    ))
  ) {
    return false;
  }

  const requests = await tx.$queryRaw<Array<{ id: string }>>(
    Prisma.sql`SELECT "id" FROM "QuoteRequest" WHERE "id" = ${quoteRequestId} FOR UPDATE`,
  );
  return requests.length === 1;
}

export async function lockQuoteOfferTransitionRows(
  tx: Prisma.TransactionClient,
  lifecycle: ConversationLifecyclePort,
  quoteOfferId: string,
): Promise<{ quoteRequestId: string } | null> {
  // Conversation events update the shared conversation row. Lock it before
  // request/offer rows so quote transitions match account deletion and cannot
  // deadlock as QuoteRequest -> Conversation versus Conversation -> QuoteRequest.
  const offer = await tx.quoteOffer.findUnique({
    where: { id: quoteOfferId },
    select: { quoteRequest: { select: { conversationId: true } } },
  });
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
  const requests = await tx.$queryRaw<Array<{ quoteRequestId: string }>>(
    Prisma.sql`
      SELECT qr."id" AS "quoteRequestId"
      FROM "QuoteRequest" qr
      INNER JOIN "QuoteOffer" qo ON qo."quoteRequestId" = qr."id"
      WHERE qo."id" = ${quoteOfferId}
      FOR UPDATE OF qr
    `,
  );
  const request = requests[0];
  if (!request) return null;

  const offers = await tx.$queryRaw<Array<{ id: string }>>(
    Prisma.sql`SELECT "id" FROM "QuoteOffer" WHERE "id" = ${quoteOfferId} FOR UPDATE`,
  );
  return offers.length === 1 ? request : null;
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
