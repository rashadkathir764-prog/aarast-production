import { Prisma, Provider } from '@prisma/client';

export async function lockOwnedProviderRow(
  tx: Prisma.TransactionClient,
  userId: string,
  mode: 'SHARE' | 'UPDATE',
): Promise<{ id: string } | undefined> {
  const rows =
    mode === 'UPDATE'
      ? await tx.$queryRaw<Array<{ id: string }>>(
          Prisma.sql`
            SELECT "id"
            FROM "Provider"
            WHERE "userId" = ${userId}
            FOR UPDATE
          `,
        )
      : await tx.$queryRaw<Array<{ id: string }>>(
          Prisma.sql`
            SELECT "id"
            FROM "Provider"
            WHERE "userId" = ${userId}
            FOR SHARE
          `,
        );
  return rows[0];
}

export function findProviderForMutation(
  tx: Prisma.TransactionClient,
  providerId: string,
): Promise<Provider | null> {
  return tx.provider.findUnique({ where: { id: providerId } });
}
