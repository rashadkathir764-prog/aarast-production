import { OtpCode, OtpPurpose, Prisma } from '@prisma/client';
import * as bcryptjs from 'bcryptjs';
import type { PrismaService } from '../../../platform/database/prisma.service';

type Client = PrismaService | Prisma.TransactionClient;

export type OtpClaimResult =
  | { outcome: 'verified'; otp: OtpCode }
  | { outcome: 'invalid' };

export class AuthOtpRepository {
  issuedConsumedAt(tx: Prisma.TransactionClient, otpId: string) {
    return tx.otpCode.findUniqueOrThrow({
      where: { id: otpId }, select: { consumedAt: true },
    });
  }

  consumeIfActive(client: Client, otpId: string, now: Date) {
    return client.otpCode.updateMany({
      where: { id: otpId, consumedAt: null }, data: { consumedAt: now },
    });
  }

  consumeAdministratorCodes(tx: Prisma.TransactionClient, phone: string, now: Date) {
    return tx.otpCode.updateMany({
      where: {
        phone,
        purpose: { in: [OtpPurpose.ADMIN_LOGIN, OtpPurpose.ADMIN_RESET_PASSWORD] },
        consumedAt: null,
      },
      data: { consumedAt: now },
    });
  }

  async replaceActive(tx: Prisma.TransactionClient, data: Pick<Prisma.OtpCodeUncheckedCreateInput,
    'phone' | 'purpose' | 'codeHash' | 'expiresAt' | 'maxAttempts' | 'planInviteId'
  >, now: Date): Promise<OtpCode> {
    await tx.otpCode.updateMany({
      where: {
        phone: data.phone, purpose: data.purpose,
        planInviteId: data.planInviteId ?? null, consumedAt: null,
      },
      data: { consumedAt: now },
    });
    return tx.otpCode.create({
      data: { ...data, planInviteId: data.planInviteId ?? null },
    });
  }

  async claim(tx: Prisma.TransactionClient, input: {
    otpId?: string;
    phone: string;
    purpose: OtpPurpose;
    planInviteId?: string | null;
    code: string;
    now: Date;
  }): Promise<OtpClaimResult> {
    const { otpId, phone, purpose, code, now } = input;
    const planInviteId = input.planInviteId ?? null;
    const otp = otpId
      ? await tx.otpCode.findUnique({ where: { id: otpId } })
      : await tx.otpCode.findFirst({
          where: { phone, purpose, planInviteId, consumedAt: null },
          orderBy: { createdAt: 'desc' },
        });
    if (!otp) return { outcome: 'invalid' };

    const locked = await tx.otpCode.updateMany({
      where: { id: otp.id }, data: { updatedAt: now },
    });
    if (locked.count !== 1) return { outcome: 'invalid' };

    const current = await tx.otpCode.findUnique({ where: { id: otp.id } });
    if (
      !current || current.phone !== phone || current.purpose !== purpose ||
      (current.planInviteId ?? null) !== planInviteId
    ) return { outcome: 'invalid' };
    if (
      current.consumedAt || current.expiresAt <= now ||
      current.attempts >= current.maxAttempts
    ) {
      if (!current.consumedAt) await this.consumeIfActive(tx, current.id, now);
      return { outcome: 'invalid' };
    }

    const matches = await bcryptjs.compare(code, current.codeHash);
    if (!matches) {
      const nextAttempts = current.attempts + 1;
      await tx.otpCode.updateMany({
        where: {
          id: current.id, consumedAt: null, expiresAt: { gt: now },
          attempts: { lt: current.maxAttempts },
        },
        data: {
          attempts: { increment: 1 },
          ...(nextAttempts >= current.maxAttempts ? { consumedAt: now } : {}),
        },
      });
      return { outcome: 'invalid' };
    }

    const consumed = await tx.otpCode.updateMany({
      where: {
        id: current.id, consumedAt: null, expiresAt: { gt: now },
        attempts: { lt: current.maxAttempts },
      },
      data: { consumedAt: now },
    });
    if (consumed.count !== 1) return { outcome: 'invalid' };
    return {
      outcome: 'verified',
      otp: { ...current, consumedAt: now, updatedAt: now },
    };
  }
}
