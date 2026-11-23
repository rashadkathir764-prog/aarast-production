import {
  Logger,
  type OnApplicationShutdown,
  type OnModuleDestroy,
} from "@nestjs/common";
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
export class ResilientThrottlerStorage
  implements ThrottlerStorage, OnModuleDestroy, OnApplicationShutdown
{
  private readonly logger = new Logger(ResilientThrottlerStorage.name);
  private lastFailureLogAt = 0;

  constructor(
    private readonly inner: ThrottlerStorage,
    private readonly fallback: ThrottlerStorage = new ThrottlerStorageService(),
  ) {}

  /**
   * Nest calls lifecycle hooks on the registered storage only, so they are
   * passed on: the Redis store disconnects its client here, and the local
   * store clears its timers. Without it a closed app kept a socket open.
   */
  async onModuleDestroy(): Promise<void> {
    await callHook(this.inner, "onModuleDestroy");
    await callHook(this.fallback, "onModuleDestroy");
  }

  async onApplicationShutdown(): Promise<void> {
    await callHook(this.inner, "onApplicationShutdown");
    await callHook(this.fallback, "onApplicationShutdown");
  }

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

async function callHook(
  store: ThrottlerStorage,
  hook: "onModuleDestroy" | "onApplicationShutdown",
): Promise<void> {
  const method = (store as Partial<Record<typeof hook, () => unknown>>)[hook];
  if (typeof method === "function") await method.call(store);
}
