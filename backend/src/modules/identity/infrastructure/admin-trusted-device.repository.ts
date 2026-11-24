import type { Prisma } from '@prisma/client';
import type { PrismaService } from '../../../platform/database/prisma.service';
import type { AdminTrustedDeviceRecord } from '../internal/auth/admin-trusted-device';

type Client = PrismaService | Prisma.TransactionClient;

/** RA-AD-26: the admin browsers remembered after a code-verified sign-in. */
export class AdminTrustedDeviceRepository {
  findByTokenHash(client: Client, tokenHash: string) {
    return client.adminTrustedDevice.findUnique({ where: { tokenHash } });
  }

  create(
    tx: Prisma.TransactionClient,
    record: Omit<AdminTrustedDeviceRecord, 'revokedAt'>,
  ) {
    return tx.adminTrustedDevice.create({ data: record });
  }

  /** Records the device's use; 0 when it was revoked or expired meanwhile. */
  async markUsed(tx: Prisma.TransactionClient, id: string, now: Date): Promise<number> {
    const used = await tx.adminTrustedDevice.updateMany({
      where: { id, revokedAt: null, expiresAt: { gt: now } },
      data: { lastUsedAt: now },
    });
    return used.count;
  }
}
