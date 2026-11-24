import { createHmac } from "node:crypto";
import {
  HttpException,
  HttpStatus,
  Injectable,
  ServiceUnavailableException,
} from "@nestjs/common";
import { PrismaService } from "../../../../platform/database/prisma.service";
import {
  clearLoginThrottleAttempt,
  findLoginThrottleLock,
  reserveLoginThrottleAttempt,
} from '../../infrastructure/login-throttle.repository';

export type LoginThrottleRealm = "application" | "admin";

/** One counted window: whose it is, how many it takes, and for how long. */
interface ThrottleWindow {
  subjectHash: string;
  maxAttempts: number;
  windowMs: number;
}

@Injectable()
export class LoginThrottleService {
  static readonly maxAttempts = 5;
  static readonly windowMs = 15 * 60_000;
  /**
   * RA-BE-148: an application number's password lock was the number's alone
   * (5 in 15 minutes, from anyone), and providers' numbers are public: a
   * stranger closed a provider out. The 5 are now counted per phone on the
   * number, by the phone's own id (a phone without one shares one window);
   * the number keeps this ceiling across every id. The id is only the
   * phone's word, so the ceiling is the old lock's own rate: rotating ids
   * guesses no faster than before. Administrators keep the number's lock.
   */
  static readonly numberCeiling = 20;
  static readonly numberCeilingWindowMs = 60 * 60_000;

  constructor(private readonly prisma: PrismaService) {}

  async assertAllowed(
    phone: string,
    realm: LoginThrottleRealm = "application",
    device: string | null = null,
  ): Promise<void> {
    const now = new Date();
    for (const window of LoginThrottleService.windows(phone, realm, device)) {
      const record = await findLoginThrottleLock(this.prisma, window.subjectHash);
      if (record?.lockedUntil && record.lockedUntil > now) {
        throw LoginThrottleService.tooMany();
      }
    }
  }

  async reserveAttempt(
    phone: string,
    realm: LoginThrottleRealm = "application",
    device: string | null = null,
  ): Promise<void> {
    for (const window of LoginThrottleService.windows(phone, realm, device)) {
      let outcome: "admitted" | "locked";
      try {
        outcome = await reserveLoginThrottleAttempt(
          this.prisma,
          window.subjectHash,
          window.maxAttempts,
          window.windowMs,
        );
      } catch {
        // Preserve the public fail-closed contract without exposing database
        // details or allowing authentication to continue.
        throw new ServiceUnavailableException(
          "Login protection is temporarily unavailable",
        );
      }
      if (outcome === "locked") throw LoginThrottleService.tooMany();
    }
  }

  async clear(
    phone: string,
    realm: LoginThrottleRealm = "application",
    device: string | null = null,
  ): Promise<void> {
    for (const window of LoginThrottleService.windows(phone, realm, device)) {
      await clearLoginThrottleAttempt(this.prisma, window.subjectHash);
    }
  }

  /** The windows an attempt counts in, the phone's own first. */
  private static windows(
    phone: string,
    realm: LoginThrottleRealm,
    device: string | null,
  ): ThrottleWindow[] {
    if (realm === "admin") {
      return [
        {
          subjectHash: LoginThrottleService.subjectHash(phone, realm),
          maxAttempts: LoginThrottleService.maxAttempts,
          windowMs: LoginThrottleService.windowMs,
        },
      ];
    }
    return [
      {
        subjectHash: LoginThrottleService.subjectHash(
          `${phone}|device:${device ?? "none"}`,
          realm,
        ),
        maxAttempts: LoginThrottleService.maxAttempts,
        windowMs: LoginThrottleService.windowMs,
      },
      {
        subjectHash: LoginThrottleService.subjectHash(phone, realm),
        maxAttempts: LoginThrottleService.numberCeiling,
        windowMs: LoginThrottleService.numberCeilingWindowMs,
      },
    ];
  }

  private static tooMany(): HttpException {
    return new HttpException(
      "Too many failed login attempts. Try again later.",
      HttpStatus.TOO_MANY_REQUESTS,
    );
  }

  static subjectHash(
    phone: string,
    realm: LoginThrottleRealm = "application",
  ): string {
    const configured = process.env.AUTH_LOGIN_THROTTLE_PEPPER?.trim();
    if (!configured && process.env.NODE_ENV === "production") {
      throw new ServiceUnavailableException(
        "Login protection is temporarily unavailable",
      );
    }
    const pepper = configured || "aarast-local-login-throttle-pepper-v1";
    return createHmac("sha256", pepper)
      .update(`v2:${realm}:${phone}`, "utf8")
      .digest("hex");
  }
}
