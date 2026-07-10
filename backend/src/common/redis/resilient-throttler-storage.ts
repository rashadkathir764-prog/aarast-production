import { Logger } from "@nestjs/common";
import {
  ThrottlerStorageService,
  type ThrottlerStorage,
} from "@nestjs/throttler";
import type { ThrottlerStorageRecord } from "@nestjs/throttler/dist/throttler-storage-record.interface";

/**
 * Keeps rate limiting available when Redis is temporarily unreachable.
 * The fallback is deliberately per-process: it cannot provide a global
 * replica-wide count, but it still enforces a bounded limit instead of
 * silently opening authentication and OTP routes during an outage.
 */
export class ResilientThrottlerStorage implements ThrottlerStorage {
  private readonly logger = new Logger(ResilientThrottlerStorage.name);
  private lastFailureLogAt = 0;

  constructor(
    private readonly inner: ThrottlerStorage,
    private readonly fallback: ThrottlerStorage = new ThrottlerStorageService(),
  ) {}

  async increment(
    key: string,
    ttl: number,
    limit: number,
    blockDuration: number,
    throttlerName: string,
  ): Promise<ThrottlerStorageRecord> {
    try {
      return await this.inner.increment(
        key,
        ttl,
        limit,
        blockDuration,
        throttlerName,
      );
    } catch (error) {
      // Log at most once per 30s so a Redis outage does not flood stdout
      // at request rate.
      const now = Date.now();
      if (now - this.lastFailureLogAt > 30_000) {
        this.lastFailureLogAt = now;
        this.logger.error(
          `Throttler storage unavailable; using in-process limits type=${throttlerStorageFailureType(error)}`,
        );
      }
      return this.fallback.increment(
        key,
        ttl,
        limit,
        blockDuration,
        throttlerName,
      );
    }
  }
}

export function throttlerStorageFailureType(error: unknown): string {
  const name = error instanceof Error ? error.name : "UnknownError";
  const sanitized = name.replace(/[^a-zA-Z0-9_-]/g, "").slice(0, 64);
  return sanitized || "UnknownError";
}
