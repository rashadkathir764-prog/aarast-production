import { createHmac } from "node:crypto";
import {
  HttpException,
  HttpStatus,
  Injectable,
  ServiceUnavailableException,
} from "@nestjs/common";
import { runRetryableTransaction } from "../common/prisma/serializable-transaction";
import { PrismaService } from "../prisma/prisma.service";

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
    const record = await this.prisma.loginThrottle.findUnique({
      where: { subjectHash: LoginThrottleService.subjectHash(phone, realm) },
      select: { lockedUntil: true },
    });
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
      outcome = await runRetryableTransaction(
        this.prisma,
        async (tx) => {
          const now = new Date();
          // PostgreSQL's INSERT ... ON CONFLICT DO UPDATE acquires and keeps a
          // row lock until this transaction commits. Every concurrent attempt
          // therefore observes the count written by the previous transaction.
          const existing = await tx.loginThrottle.upsert({
            where: { subjectHash },
            create: {
              subjectHash,
              failedCount: 0,
              windowStartedAt: now,
            },
            update: { updatedAt: now },
          });
          if (existing.lockedUntil && existing.lockedUntil > now) {
            return "locked" as const;
          }

          const windowExpired =
            existing.lockedUntil !== null ||
            existing.windowStartedAt.getTime() <=
              now.getTime() - LoginThrottleService.windowMs;
          const nextCount = windowExpired ? 1 : existing.failedCount + 1;
          const shouldLock = nextCount >= LoginThrottleService.maxAttempts;
          await tx.loginThrottle.update({
            where: { subjectHash },
            data: {
              failedCount: shouldLock ? 0 : nextCount,
              windowStartedAt: windowExpired ? now : existing.windowStartedAt,
              lockedUntil: shouldLock
                ? new Date(now.getTime() + LoginThrottleService.windowMs)
                : null,
            },
          });
          return "admitted" as const;
        },
        { maxAttempts: 4 },
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
    await this.prisma.loginThrottle.deleteMany({
      where: { subjectHash: LoginThrottleService.subjectHash(phone, realm) },
    });
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
