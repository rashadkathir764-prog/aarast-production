import { createHmac } from 'node:crypto';
import {
  HttpException,
  HttpStatus,
  Inject,
  Injectable,
  Optional,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../../../platform/database/prisma.service';
import { otpDeliveryUnavailableError } from '../../public/auth-error';
import type { OtpDispatchContext } from '../../public/identity-auth.port';

interface QuotaPolicy {
  scope: string;
  subject: string;
  limit: number;
  windowMs: number;
}

interface QuotaRow {
  count: number;
}

export const OTP_DISPATCH_NOW = Symbol('OTP_DISPATCH_NOW');

@Injectable()
export class OtpDispatchQuotaService {
  static readonly phoneCooldownMs = 60_000;
  static readonly retentionMs = 2 * 24 * 60 * 60_000;

  constructor(
    private readonly prisma: PrismaService,
    @Optional()
    @Inject(OTP_DISPATCH_NOW)
    private readonly now: () => Date = () => new Date(),
  ) {}

  async consume(phone: string, context: OtpDispatchContext = {}): Promise<void> {
    const policies = this.policies(phone, context.ip);

    for (let attempt = 0; attempt < 3; attempt += 1) {
      try {
        await this.prisma.$transaction(
          async (tx) => {
            const now = this.now();
            for (const policy of policies) {
              const resetBefore = new Date(now.getTime() - policy.windowMs);
              const subjectHash = OtpDispatchQuotaService.subjectHash(
                policy.scope,
                policy.subject,
              );
              const [row] = await tx.$queryRawUnsafe<QuotaRow[]>(
                `
                  INSERT INTO "OtpDispatchQuota"
                    ("scope", "subjectHash", "count", "windowStartedAt", "updatedAt")
                  VALUES ($1, $2, 1, $3, $3)
                  ON CONFLICT ("scope", "subjectHash") DO UPDATE SET
                    "count" = CASE
                      WHEN "OtpDispatchQuota"."windowStartedAt" <= $4 THEN 1
                      ELSE "OtpDispatchQuota"."count" + 1
                    END,
                    "windowStartedAt" = CASE
                      WHEN "OtpDispatchQuota"."windowStartedAt" <= $4 THEN $3
                      ELSE "OtpDispatchQuota"."windowStartedAt"
                    END,
                    "updatedAt" = $3
                  RETURNING "count"
                `,
                policy.scope,
                subjectHash,
                now,
                resetBefore,
              );
              if (!row || row.count > policy.limit) {
                throw new HttpException(
                  'طلبات رمز التحقق كثيرة. حاول لاحقًا.',
                  HttpStatus.TOO_MANY_REQUESTS,
                );
              }
            }
          },
          { isolationLevel: Prisma.TransactionIsolationLevel.Serializable },
        );
        return;
      } catch (error) {
        if (error instanceof HttpException) throw error;
        if (
          error instanceof Prisma.PrismaClientKnownRequestError &&
          (error.code === 'P2002' || error.code === 'P2034') &&
          attempt < 2
        ) {
          continue;
        }
        throw otpDeliveryUnavailableError();
      }
    }
  }

  private policies(phone: string, rawIp?: string | null): QuotaPolicy[] {
    const policies: QuotaPolicy[] = [
      {
        scope: 'PHONE_COOLDOWN',
        subject: phone,
        limit: 1,
        windowMs: OtpDispatchQuotaService.phoneCooldownMs,
      },
      { scope: 'PHONE_HOUR', subject: phone, limit: 5, windowMs: 60 * 60_000 },
      { scope: 'PHONE_DAY', subject: phone, limit: 10, windowMs: 24 * 60 * 60_000 },
      {
        scope: 'GLOBAL_DAY',
        subject: 'aarast-otp',
        limit: this.globalDailyLimit(),
        windowMs: 24 * 60 * 60_000,
      },
    ];
    const ip = rawIp?.trim().toLowerCase().slice(0, 128);
    if (ip) {
      policies.push(
        { scope: 'IP_TEN_MIN', subject: ip, limit: 10, windowMs: 10 * 60_000 },
        { scope: 'IP_DAY', subject: ip, limit: 50, windowMs: 24 * 60 * 60_000 },
      );
    }
    return policies;
  }

  private globalDailyLimit(): number {
    const configured = Number(process.env.OTP_GLOBAL_DAILY_LIMIT ?? 150);
    if (!Number.isInteger(configured) || configured < 1 || configured > 10_000) {
      throw otpDeliveryUnavailableError();
    }
    return configured;
  }

  static subjectHash(scope: string, subject: string): string {
    const configured = process.env.AUTH_LOGIN_THROTTLE_PEPPER?.trim();
    if (!configured && process.env.NODE_ENV === 'production') {
      throw otpDeliveryUnavailableError();
    }
    const pepper = configured || 'aarast-local-login-throttle-pepper-v1';
    return createHmac('sha256', pepper)
      .update(`otp-dispatch-v1:${scope}:${subject}`, 'utf8')
      .digest('hex');
  }
}
