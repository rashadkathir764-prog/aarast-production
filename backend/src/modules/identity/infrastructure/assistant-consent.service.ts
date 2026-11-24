import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../../platform/database/prisma.service';
import type { AssistantConsentPort } from '../public/assistant-consent.port';

/** RA-BE-161 (Q-41, D124): the account's consent to the planning assistant. */
@Injectable()
export class AssistantConsentService implements AssistantConsentPort {
  constructor(private readonly prisma: PrismaService) {}

  async consentedAt(userId: string): Promise<Date | null> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { assistantConsentAt: true },
    });
    return user?.assistantConsentAt ?? null;
  }

  async recordConsent(userId: string): Promise<Date> {
    // One statement: a repeated or concurrent agreement keeps the first date.
    const [row] = await this.prisma.$queryRaw<Array<{ assistantConsentAt: Date }>>`
      UPDATE "User"
      SET "assistantConsentAt" = COALESCE("assistantConsentAt", NOW())
      WHERE "id" = ${userId}
      RETURNING "assistantConsentAt"`;
    if (!row) throw new Error('The consenting account does not exist');
    return row.assistantConsentAt;
  }

  async withdrawConsent(userId: string): Promise<void> {
    await this.prisma.user.update({
      where: { id: userId },
      data: { assistantConsentAt: null },
    });
  }
}
