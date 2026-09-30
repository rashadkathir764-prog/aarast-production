import { Prisma } from '@prisma/client';
import { MARKETPLACE_QUOTE_INCLUDE } from '../../../marketplace/marketplace.contracts';
import type { LiveAuthorizationFilter } from '../../collaboration/public/collaboration-permission.port';

export function findLivePlanQuoteRequest(
  client: Prisma.TransactionClient,
  quoteRequestId: string,
  weddingPlanId: string,
  liveFilter: LiveAuthorizationFilter,
) {
  return client.quoteRequest.findFirst({
    where: {
      id: quoteRequestId,
      weddingPlanId,
      ...liveFilter,
    },
    include: MARKETPLACE_QUOTE_INCLUDE,
  });
}
