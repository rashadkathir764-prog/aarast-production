import { Prisma } from '@prisma/client';
import type { PrismaService } from '../../../platform/database/prisma.service';

export class AuthChallengeRepository {
  findAdminLoginSeed(client: PrismaService, tokenHash: string) {
    return client.adminLoginChallenge.findUnique({
      where: { tokenHash }, select: { id: true, userId: true },
    });
  }

  findAdminLogin(tx: Prisma.TransactionClient, id: string) {
    return tx.adminLoginChallenge.findUnique({
      where: { id }, include: { user: true, otp: true },
    });
  }

  async createAdminLogin(tx: Prisma.TransactionClient, input: {
    userId: string; otpId: string; tokenHash: string; expiresAt: Date;
    superseded: boolean; now: Date;
  }) {
    if (!input.superseded) {
      await this.consumeActiveAdminLogins(tx, input.userId, input.now);
    }
    return tx.adminLoginChallenge.create({
      data: {
        userId: input.userId, otpId: input.otpId,
        tokenHash: input.tokenHash, expiresAt: input.expiresAt,
        ...(input.superseded ? { consumedAt: input.now } : {}),
      },
    });
  }

  consumeAdminLogin(tx: Prisma.TransactionClient, id: string, now: Date) {
    return tx.adminLoginChallenge.updateMany({
      where: { id, consumedAt: null, expiresAt: { gt: now } },
      data: { consumedAt: now },
    });
  }

  consumeActiveAdminLogins(tx: Prisma.TransactionClient, userId: string, now: Date) {
    return tx.adminLoginChallenge.updateMany({
      where: { userId, consumedAt: null }, data: { consumedAt: now },
    });
  }

  lockAdminLogins(tx: Prisma.TransactionClient, userId: string) {
    return tx.$queryRaw(
      Prisma.sql`
        SELECT "id"
        FROM "AdminLoginChallenge"
        WHERE "userId" = ${userId}
          AND "consumedAt" IS NULL
        ORDER BY "id" ASC
        FOR UPDATE
      `,
    );
  }

  findAdminResetSeed(client: PrismaService, tokenHash: string) {
    return client.adminPasswordResetChallenge.findUnique({
      where: { tokenHash }, select: { id: true, userId: true },
    });
  }

  findAdminReset(tx: Prisma.TransactionClient, id: string) {
    return tx.adminPasswordResetChallenge.findUnique({
      where: { id }, include: { user: true, otp: true },
    });
  }

  async createAdminReset(tx: Prisma.TransactionClient, input: {
    userId: string | null; otpId: string; tokenHash: string;
    subjectHash: string; expiresAt: Date; superseded: boolean; now: Date;
  }) {
    if (!input.superseded) {
      await this.consumeActiveAdminResetsBySubject(tx, input.subjectHash, input.now);
    }
    return tx.adminPasswordResetChallenge.create({
      data: {
        userId: input.userId, otpId: input.otpId,
        tokenHash: input.tokenHash, subjectHash: input.subjectHash,
        expiresAt: input.expiresAt,
        ...(input.superseded ? { consumedAt: input.now } : {}),
      },
    });
  }

  consumeActiveAdminResetsBySubject(tx: Prisma.TransactionClient, subjectHash: string, now: Date) {
    return tx.adminPasswordResetChallenge.updateMany({
      where: { subjectHash, consumedAt: null }, data: { consumedAt: now },
    });
  }

  consumeAdminResetIfActive(tx: Prisma.TransactionClient, id: string, now: Date) {
    return tx.adminPasswordResetChallenge.updateMany({
      where: { id, consumedAt: null }, data: { consumedAt: now },
    });
  }

  claimAdminReset(tx: Prisma.TransactionClient, id: string, maxAttempts: number, now: Date) {
    return tx.adminPasswordResetChallenge.updateMany({
      where: {
        id, consumedAt: null, expiresAt: { gt: now },
        attempts: { lt: maxAttempts },
      },
      data: { consumedAt: now },
    });
  }

  consumeActiveAdminResetsByUser(tx: Prisma.TransactionClient, userId: string, now: Date) {
    return tx.adminPasswordResetChallenge.updateMany({
      where: { userId, consumedAt: null }, data: { consumedAt: now },
    });
  }

  async recordFailedAdminResetAttempt(tx: Prisma.TransactionClient, id: string, maxAttempts: number, now: Date) {
    await tx.adminPasswordResetChallenge.updateMany({
      where: { id, consumedAt: null, attempts: { lt: maxAttempts } },
      data: { attempts: { increment: 1 } },
    });
    await tx.adminPasswordResetChallenge.updateMany({
      where: { id, consumedAt: null, attempts: { gte: maxAttempts } },
      data: { consumedAt: now },
    });
  }

  async lockAdminResets(tx: Prisma.TransactionClient,
    input: { userId: string } | { challengeId: string } | { subjectHash: string },
  ) {
    if ('userId' in input) {
      await tx.$queryRaw(Prisma.sql`
        SELECT "id" FROM "AdminPasswordResetChallenge"
        WHERE "userId" = ${input.userId} AND "consumedAt" IS NULL
        ORDER BY "id" ASC FOR UPDATE
      `);
    } else if ('subjectHash' in input) {
      await tx.$queryRaw(Prisma.sql`
        SELECT "id" FROM "AdminPasswordResetChallenge"
        WHERE "subjectHash" = ${input.subjectHash} AND "consumedAt" IS NULL
        ORDER BY "id" ASC FOR UPDATE
      `);
    } else {
      await tx.$queryRaw(Prisma.sql`
        SELECT "id" FROM "AdminPasswordResetChallenge"
        WHERE "id" = ${input.challengeId} FOR UPDATE
      `);
    }
  }
}
