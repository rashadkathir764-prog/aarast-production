import { createHmac } from 'node:crypto';
import { isIPv4, isIPv6 } from 'node:net';
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

/**
 * RA-BE-55: the sender the address limits count. An IPv6 subscriber holds a
 * whole /64 and may use any address in it, so counting the full address let
 * one sender rotate addresses past the limits and spend the app's day of
 * codes for everyone. IPv6 counts by its /64; an IPv4 address written as IPv6
 * (`::ffff:a.b.c.d`) is that IPv4 address; anything else is kept as given.
 */
export function otpIpSubject(rawIp?: string | null): string | null {
  const ip = rawIp?.trim().toLowerCase().replace(/%.*$/u, '');
  if (!ip) return null;
  const mapped = /^::ffff:(\d{1,3}(?:\.\d{1,3}){3})$/u.exec(ip);
  if (mapped && isIPv4(mapped[1])) return mapped[1];
  if (!isIPv6(ip)) return ip.slice(0, 128);
  const [head, tail = ''] = ip.split('::');
  const left = head ? head.split(':') : [];
  const right = ip.includes('::') && tail ? tail.split(':') : [];
  const groups = ip.includes('::')
    ? [...left, ...Array(8 - left.length - right.length).fill('0'), ...right]
    : left;
  if (groups.length !== 8) return ip.slice(0, 128);
  const network = groups
    .slice(0, 4)
    .map((group) => Number.parseInt(group || '0', 16).toString(16));
  return `${network.join(':')}::/64`;
}

/** «دقيقة», «دقيقتين», «5 دقائق», «50 دقيقة»: the count the way it is said. */
function counted(
  count: number,
  one: string,
  two: string,
  few: string,
  many: string,
): string {
  if (count === 1) return one;
  if (count === 2) return two;
  return count <= 10 ? `${count} ${few}` : `${count} ${many}`;
}

/**
 * D112 (Q-14): the wait as a person says it, never shorter than it is: a
 * minute for anything under one, minutes up to an hour, whole hours past it
 * (13 hours and 50 minutes is «14 ساعة», so nobody comes back to a second
 * refusal).
 */
export function otpWaitWords(retryAfterSeconds: number): string {
  const minutes = Math.max(1, Math.ceil(retryAfterSeconds / 60));
  if (minutes < 60) {
    return counted(minutes, 'دقيقة', 'دقيقتين', 'دقائق', 'دقيقة');
  }
  return counted(Math.ceil(minutes / 60), 'ساعة', 'ساعتين', 'ساعات', 'ساعة');
}

/**
 * D112 (Q-14), the owner's word: the refusal names the limit that was
 * reached and how long is left. A sentence about the number or the network,
 * with no «حاول» in either gender: who asks for a code has not said yet
 * whether they are the groom or the bride.
 */
function otpLimitRefusal(
  code: string,
  reached: string | null,
): (retryAfterSeconds: number) => { code: string; message: string } {
  return (retryAfterSeconds) => {
    const wait = `يتاح رمز جديد بعد ${otpWaitWords(retryAfterSeconds)}.`;
    return { code, message: reached ? `${reached} ${wait}` : wait };
  };
}

function codesWords(limit: number): string {
  return counted(limit, 'رمز', 'رمزين', 'رموز', 'رمز');
}

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
        refusal: otpLimitRefusal('OTP_LIMIT_COOLDOWN', null),
      },
      {
        scope: 'PHONE_HOUR',
        subject: phone,
        limit: 5,
        windowMs: 60 * 60_000,
        refusal: otpLimitRefusal(
          'OTP_LIMIT_PHONE_HOUR',
          `هذا الرقم طلب ${codesWords(5)} في ساعة.`,
        ),
      },
      {
        scope: 'PHONE_DAY',
        subject: phone,
        limit: 10,
        windowMs: 24 * 60 * 60_000,
        refusal: otpLimitRefusal(
          'OTP_LIMIT_PHONE_DAY',
          `هذا الرقم طلب ${codesWords(10)} اليوم.`,
        ),
      },
      {
        scope: GLOBAL_SCOPE,
        subject: GLOBAL_SUBJECT,
        limit: this.globalDailyLimit(),
        windowMs: GLOBAL_WINDOW_MS,
        // The whole app's day of codes: nothing this person did, and the
        // count itself is not theirs to know.
        refusal: otpLimitRefusal(
          'OTP_LIMIT_SERVICE_DAY',
          'رموز اليوم خلصت عندنا لكل الناس.',
        ),
      },
    ];
    const ip = otpIpSubject(rawIp);
    if (ip) {
      const network = otpLimitRefusal(
        'OTP_LIMIT_NETWORK',
        'طلبات رموز كثيرة من هذي الشبكة.',
      );
      policies.push(
        {
          scope: 'IP_TEN_MIN',
          subject: ip,
          limit: 10,
          windowMs: 10 * 60_000,
          refusal: network,
        },
        {
          scope: 'IP_DAY',
          subject: ip,
          limit: 50,
          windowMs: 24 * 60 * 60_000,
          refusal: network,
        },
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
