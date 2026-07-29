import { Injectable, NotFoundException } from "@nestjs/common";
import { Prisma, PushPlatform, UserStatus } from "@prisma/client";
import { AuthenticatedUser } from "../auth/authenticated-user.interface";
import { runSerializableTransaction } from "../common/prisma/serializable-transaction";
import { PrismaService } from "../prisma/prisma.service";
import { lockUserLifecycleRowsForUpdateInTransaction } from "../users/user-lifecycle-lock";

interface LockedInstallation {
  id: string;
  userId: string;
}

@Injectable()
export class PushInstallationsService {
  constructor(private readonly prisma: PrismaService) {}

  async register(
    currentUser: AuthenticatedUser,
    fidValue: string,
    platform: PushPlatform,
  ): Promise<{ registered: true }> {
    const fid = fidValue.trim();
    await runSerializableTransaction(this.prisma, async (tx) => {
      const existing = await this.lockInstallation(tx, fid);
      const userIds = [currentUser.id, ...(existing ? [existing.userId] : [])];
      const users = await lockUserLifecycleRowsForUpdateInTransaction(
        tx,
        userIds,
      );
      const current = users.find((user) => user.id === currentUser.id);
      if (!current || current.status !== UserStatus.ACTIVE) {
        throw new NotFoundException("User not found");
      }

      await tx.pushInstallation.upsert({
        where: { fid },
        create: {
          userId: currentUser.id,
          fid,
          platform,
          enabled: true,
          lastSeenAt: new Date(),
        },
        update: {
          userId: currentUser.id,
          platform,
          enabled: true,
          lastSeenAt: new Date(),
        },
      });
      await tx.notificationPreference.upsert({
        where: { userId: currentUser.id },
        create: { userId: currentUser.id, pushEnabled: true },
        update: { pushEnabled: true },
      });

      if (existing && existing.userId !== currentUser.id) {
        await this.disablePushWithoutInstallations(tx, existing.userId);
      }
    });
    return { registered: true };
  }

  async unregister(
    currentUser: AuthenticatedUser,
    fidValue: string,
  ): Promise<{ unregistered: true }> {
    const fid = fidValue.trim();
    await runSerializableTransaction(this.prisma, async (tx) => {
      const existing = await this.lockInstallation(tx, fid);
      const users = await lockUserLifecycleRowsForUpdateInTransaction(tx, [
        currentUser.id,
      ]);
      if (users.length !== 1 || users[0]?.status !== UserStatus.ACTIVE) {
        throw new NotFoundException("User not found");
      }
      if (existing?.userId === currentUser.id) {
        await tx.pushInstallation.delete({ where: { id: existing.id } });
      }
      await this.disablePushWithoutInstallations(tx, currentUser.id);
    });
    return { unregistered: true };
  }

  private lockInstallation(
    tx: Prisma.TransactionClient,
    fid: string,
  ): Promise<LockedInstallation | null> {
    return tx
      .$queryRaw<LockedInstallation[]>(
        Prisma.sql`
          SELECT "id", "userId"
          FROM "PushInstallation"
          WHERE "fid" = ${fid}
          FOR UPDATE
        `,
      )
      .then((rows) => rows[0] ?? null);
  }

  private async disablePushWithoutInstallations(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<void> {
    const remaining = await tx.pushInstallation.count({
      where: { userId, enabled: true },
    });
    if (remaining === 0) {
      await tx.notificationPreference.updateMany({
        where: { userId },
        data: { pushEnabled: false },
      });
    }
  }
}
