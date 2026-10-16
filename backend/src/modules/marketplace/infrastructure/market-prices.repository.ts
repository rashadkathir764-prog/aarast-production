import { Prisma, ProviderStatus } from '@prisma/client';
import type { PricedService } from '../public/market-prices';

/**
 * Every priced, active service of an active provider: the rows the market
 * price ranges are grouped from (the back office's report and the planning
 * assistant read the same rows).
 */
export async function listPricedServices(
  client: Prisma.TransactionClient,
): Promise<PricedService[]> {
  const services = await client.providerService.findMany({
    where: { isActive: true, basePrice: { not: null } },
    select: {
      providerId: true,
      cityId: true,
      categoryId: true,
      currency: true,
      basePrice: true,
      provider: { select: { status: true, cityId: true } },
    },
  });
  return services.flatMap((service) =>
    service.provider.status === ProviderStatus.ACTIVE && service.basePrice
      ? [{
          providerId: service.providerId,
          cityId: service.cityId ?? service.provider.cityId,
          categoryId: service.categoryId,
          currency: service.currency,
          basePrice: service.basePrice,
        }]
      : [],
  );
}
