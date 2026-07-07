import { Logger } from '@nestjs/common';
import type { ThrottlerStorage } from '@nestjs/throttler';
import type { ThrottlerStorageRecord } from '@nestjs/throttler/dist/throttler-storage-record.interface';

/**
 * Fail-open wrapper around a Redis-backed throttler storage. Rate limiting
 * is a protection layer, not a dependency: when Redis is unreachable the
 * request must pass (with a log) instead of turning every endpoint —
 * including /health — into a 500 and taking the whole API down.
 */
export class ResilientThrottlerStorage implements ThrottlerStorage {
  private readonly logger = new Logger(ResilientThrottlerStorage.name);
  private lastFailureLogAt = 0;

  constructor(private readonly inner: ThrottlerStorage) {}

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
          `Throttler storage unavailable — failing open: ${
            error instanceof Error ? error.message : String(error)
          }`,
        );
      }
      return {
        totalHits: 1,
        timeToExpire: ttl,
        isBlocked: false,
        timeToBlockExpire: 0,
      };
    }
  }
}
