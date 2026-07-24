import { ConflictException } from '@nestjs/common';
import { Prisma, QuoteRequestStatus } from '@prisma/client';

export type QuoteLifecycleActor = 'requester' | 'provider' | 'provider_offer';

export async function lockQuoteRequestTransitionRow(
  tx: Prisma.TransactionClient,
  quoteRequestId: string,
): Promise<boolean> {
  const rows = await tx.$queryRaw<Array<{ id: string }>>(
    Prisma.sql`SELECT "id" FROM "QuoteRequest" WHERE "id" = ${quoteRequestId} FOR UPDATE`,
  );
  return rows.length === 1;
}

export async function lockQuoteOfferTransitionRows(
  tx: Prisma.TransactionClient,
  quoteOfferId: string,
): Promise<{ quoteRequestId: string } | null> {
  // Every quote transition takes the request row first and the offer row
  // second. One global order prevents accept/reject/update/cancel from
  // deadlocking each other while the final state is re-read under both locks.
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
