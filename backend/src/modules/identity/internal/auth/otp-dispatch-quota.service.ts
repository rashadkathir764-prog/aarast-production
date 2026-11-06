import { createHmac } from 'node:crypto';
import {
  HttpException,
  HttpStatus,
  Inject,
  Injectable,
  Optional,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import {
  OTP_CAPACITY_WARNING_SHARE,
  otpGlobalDailyLimit,
} from '../../../../platform/config/runtime-environment';
import { PrismaService } from '../../../../platform/database/prisma.service';
import { otpDeliveryUnavailableError } from '../../public/auth-error';
import type { OtpDispatchContext } from '../../public/identity-auth.port';
import type { OtpCapacity } from '../../public/otp-capacity.port';
import {
  consumeOtpDispatchQuotaAttempt,
  readOtpDispatchQuotaCount,
  type OtpQuotaPolicy,
} from '../../infrastructure/otp-dispatch-quota.repository';

export const OTP_DISPATCH_NOW = Symbol('OTP_DISPATCH_NOW');

/** The app-wide rolling-day quota every code counts against. */
const GLOBAL_SCOPE = 'GLOBAL_DAY';
const GLOBAL_SUBJECT = 'aarast-otp';
const GLOBAL_WINDOW_MS = 24 * 60 * 60_000;

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
        await consumeOtpDispatchQuotaAttempt(
          this.prisma,
          policies,
          this.now,
          OtpDispatchQuotaService.subjectHash,
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

  private policies(phone: string, rawIp?: string | null): OtpQuotaPolicy[] {
    const policies: OtpQuotaPolicy[] = [
      {
        scope: 'PHONE_COOLDOWN',
        subject: phone,
        limit: 1,
        windowMs: OtpDispatchQuotaService.phoneCooldownMs,
      },
      { scope: 'PHONE_HOUR', subject: phone, limit: 5, windowMs: 60 * 60_000 },
      { scope: 'PHONE_DAY', subject: phone, limit: 10, windowMs: 24 * 60 * 60_000 },
      {
        scope: GLOBAL_SCOPE,
        subject: GLOBAL_SUBJECT,
        limit: this.globalDailyLimit(),
        windowMs: GLOBAL_WINDOW_MS,
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

  /**
   * RA-BE-02 (J1-19): how close the whole app is to its daily code limit, for
   * the readiness check and its alarm. Exhausted means no new account can be
   * made by WhatsApp code until the rolling day turns.
   */
  async capacity(): Promise<OtpCapacity> {
    const limit = this.globalDailyLimit();
    const used = await readOtpDispatchQuotaCount(
      this.prisma,
      GLOBAL_SCOPE,
      OtpDispatchQuotaService.subjectHash(GLOBAL_SCOPE, GLOBAL_SUBJECT),
      GLOBAL_WINDOW_MS,
      this.now(),
    );
    if (used >= limit) return 'exhausted';
    return used >= Math.ceil(limit * OTP_CAPACITY_WARNING_SHARE) ? 'near_limit' : 'up';
  }

  private globalDailyLimit(): number {
    try {
      return otpGlobalDailyLimit();
    } catch {
      throw otpDeliveryUnavailableError();
    }
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
