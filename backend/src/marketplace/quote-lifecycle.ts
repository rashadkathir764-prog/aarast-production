import { ConflictException } from '@nestjs/common';
import { Prisma, QuoteRequestStatus } from '@prisma/client';

export type QuoteLifecycleActor = 'requester' | 'provider' | 'provider_offer';

export async function lockQuoteRequestTransitionRow(
  tx: Prisma.TransactionClient,
  quoteRequestId: string,
): Promise<boolean> {
  const conversations = await tx.$queryRaw<Array<{ id: string }>>(
    Prisma.sql`
      SELECT conversation."id"
      FROM "Conversation" conversation
      INNER JOIN "QuoteRequest" request
        ON request."conversationId" = conversation."id"
      WHERE request."id" = ${quoteRequestId}
      FOR UPDATE OF conversation
    `,
  );
  if (conversations.length !== 1) return false;

  const requests = await tx.$queryRaw<Array<{ id: string }>>(
    Prisma.sql`SELECT "id" FROM "QuoteRequest" WHERE "id" = ${quoteRequestId} FOR UPDATE`,
  );
  return requests.length === 1;
}

export async function lockQuoteOfferTransitionRows(
  tx: Prisma.TransactionClient,
  quoteOfferId: string,
): Promise<{ quoteRequestId: string } | null> {
  // Conversation events update the shared conversation row. Lock it before
  // request/offer rows so quote transitions match account deletion and cannot
  // deadlock as QuoteRequest -> Conversation versus Conversation -> QuoteRequest.
  const conversations = await tx.$queryRaw<Array<{ id: string }>>(
    Prisma.sql`
      SELECT conversation."id"
      FROM "Conversation" conversation
      INNER JOIN "QuoteRequest" request
        ON request."conversationId" = conversation."id"
      INNER JOIN "QuoteOffer" offer
        ON offer."quoteRequestId" = request."id"
      WHERE offer."id" = ${quoteOfferId}
      FOR UPDATE OF conversation
    `,
  );
  if (conversations.length !== 1) return null;

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
