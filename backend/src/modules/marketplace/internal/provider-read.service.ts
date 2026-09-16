import { Injectable } from '@nestjs/common';
import { Prisma, type Provider } from '@prisma/client';
import type {
  LockedProviderRow,
  ProviderReadPort,
} from '../public/provider-read.port';

@Injectable()
export class ProviderReadService implements ProviderReadPort {
  async getProvider(
    client: Prisma.TransactionClient,
    providerId: string,
  ): Promise<Provider | null> {
    return client.provider.findUnique({ where: { id: providerId } });
  }

  async getProviders(
    client: Prisma.TransactionClient,
    providerIds: readonly string[],
  ): Promise<Provider[]> {
    if (providerIds.length === 0) return [];
    return client.provider.findMany({
      where: { id: { in: [...providerIds] } },
    });
  }

  async getProviderByUserId(
    client: Prisma.TransactionClient,
    userId: string,
  ): Promise<Provider | null> {
    return client.provider.findUnique({ where: { userId } });
  }

  async filterProviderIdsByBusinessName(
    client: Prisma.TransactionClient,
    providerIds: readonly string[],
    search: string,
  ): Promise<string[]> {
    if (providerIds.length === 0) return [];
    const providers = await client.provider.findMany({
      where: {
        id: { in: [...providerIds] },
        businessName: { contains: search, mode: 'insensitive' },
      },
      select: { id: true },
    });
    return providers.map((provider) => provider.id);
  }

  async lockProviderRowsForShareInTransaction(
    tx: Prisma.TransactionClient,
    providerIds: readonly string[],
  ): Promise<LockedProviderRow[]> {
    const sortedProviderIds = [...new Set(providerIds)].sort();
    if (sortedProviderIds.length === 0) return [];
    return tx.$queryRaw<LockedProviderRow[]>(
      Prisma.sql`
        SELECT "id"
        FROM "Provider"
        WHERE "id" IN (${Prisma.join(sortedProviderIds)})
        ORDER BY "id" ASC
        FOR SHARE
      `,
    );
  }
}
