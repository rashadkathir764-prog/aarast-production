import { Prisma, ProviderStatus } from '@prisma/client';

export function lockProviderRow(tx: Prisma.TransactionClient, providerId: string, mode: 'SHARE' | 'UPDATE') {
  return mode === 'UPDATE'
    ? tx.$queryRaw<Array<{ id: string }>>(
        Prisma.sql`SELECT "id" FROM "Provider" WHERE "id" = ${providerId} FOR UPDATE`,
      )
    : tx.$queryRaw<Array<{ id: string }>>(
        Prisma.sql`SELECT "id" FROM "Provider" WHERE "id" = ${providerId} FOR SHARE`,
      );
}

export function findLockedProvider(tx: Prisma.TransactionClient, providerId: string) {
  return tx.provider.findUnique({
    where: { id: providerId },
    select: { id: true, userId: true, status: true, businessName: true },
  });
}

export function lockProviderServiceRow(tx: Prisma.TransactionClient, serviceId: string) {
  return tx.$queryRaw<Array<{ id: string }>>(
    Prisma.sql`SELECT "id" FROM "ProviderService" WHERE "id" = ${serviceId} FOR SHARE`,
  );
}

export function findActiveProviderService(tx: Prisma.TransactionClient, serviceId: string, providerId: string) {
  return tx.providerService.findFirst({
    where: { id: serviceId, providerId, isActive: true, provider: { status: ProviderStatus.ACTIVE } },
  });
}
