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

@Injectable()
export class LoginThrottleService {
  static readonly maxAttempts = 5;
  static readonly windowMs = 15 * 60_000;

  constructor(private readonly prisma: PrismaService) {}

  async assertAllowed(
    phone: string,
    realm: LoginThrottleRealm = "application",
  ): Promise<void> {
    const record = await findLoginThrottleLock(
      this.prisma,
      LoginThrottleService.subjectHash(phone, realm),
    );
    if (record?.lockedUntil && record.lockedUntil > new Date()) {
      throw new HttpException(
        "Too many failed login attempts. Try again later.",
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
  }

  async reserveAttempt(
    phone: string,
    realm: LoginThrottleRealm = "application",
  ): Promise<void> {
    const subjectHash = LoginThrottleService.subjectHash(phone, realm);
    let outcome: "admitted" | "locked";
    try {
      outcome = await reserveLoginThrottleAttempt(
        this.prisma,
        subjectHash,
        LoginThrottleService.maxAttempts,
        LoginThrottleService.windowMs,
      );
    } catch {
      // Preserve the public fail-closed contract without exposing database
      // details or allowing authentication to continue.
      throw new ServiceUnavailableException(
        "Login protection is temporarily unavailable",
      );
    }
    if (outcome === "locked") {
      throw new HttpException(
        "Too many failed login attempts. Try again later.",
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
  }

  async clear(
    phone: string,
    realm: LoginThrottleRealm = "application",
  ): Promise<void> {
    await clearLoginThrottleAttempt(
      this.prisma,
      LoginThrottleService.subjectHash(phone, realm),
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
