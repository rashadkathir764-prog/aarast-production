import { Prisma } from '@prisma/client';

export function findQuoteRequestConversation(
  tx: Prisma.TransactionClient,
  quoteRequestId: string,
): Promise<{ conversationId: string } | null> {
  return tx.quoteRequest.findUnique({
    where: { id: quoteRequestId },
    select: { conversationId: true },
  });
}

export function findQuoteOfferConversation(
  tx: Prisma.TransactionClient,
  quoteOfferId: string,
) {
  return tx.quoteOffer.findUnique({
    where: { id: quoteOfferId },
    select: { quoteRequest: { select: { conversationId: true } } },
  });
}

export async function lockQuoteRequestRow(
  tx: Prisma.TransactionClient,
  quoteRequestId: string,
): Promise<boolean> {
  const requests = await tx.$queryRaw<Array<{ id: string }>>(
    Prisma.sql`SELECT "id" FROM "QuoteRequest" WHERE "id" = ${quoteRequestId} FOR UPDATE`,
  );
  return requests.length === 1;
}

export async function lockQuoteRequestForOffer(
  tx: Prisma.TransactionClient,
  quoteOfferId: string,
): Promise<{ quoteRequestId: string } | null> {
  const requests = await tx.$queryRaw<Array<{ quoteRequestId: string }>>(
    Prisma.sql`
      SELECT qr."id" AS "quoteRequestId"
      FROM "QuoteRequest" qr
      INNER JOIN "QuoteOffer" qo ON qo."quoteRequestId" = qr."id"
      WHERE qo."id" = ${quoteOfferId}
      FOR UPDATE OF qr
    `,
  );
  return requests[0] ?? null;
}

export async function lockQuoteOfferRow(
  tx: Prisma.TransactionClient,
  quoteOfferId: string,
): Promise<boolean> {
  const offers = await tx.$queryRaw<Array<{ id: string }>>(
    Prisma.sql`SELECT "id" FROM "QuoteOffer" WHERE "id" = ${quoteOfferId} FOR UPDATE`,
  );
  return offers.length === 1;
}
