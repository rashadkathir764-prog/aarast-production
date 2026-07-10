import { Injectable } from '@nestjs/common';
import Redis from 'ioredis';
import { MediaStorageService } from '../media/media-storage.service';
import { PrismaService } from '../prisma/prisma.service';

export type DependencyState = 'up' | 'down' | 'disabled';

export interface DependencyReadiness {
  status: DependencyState;
  latencyMs?: number;
}

export interface ReadinessReport {
  status: 'ready' | 'not_ready';
  service: 'aarast-backend';
  checks: {
    database: DependencyReadiness;
    redis: DependencyReadiness;
    media: DependencyReadiness;
  };
}

const dependencyTimeoutMs = 2_500;

@Injectable()
export class ReadinessService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly mediaStorage: MediaStorageService,
  ) {}

  async check(): Promise<ReadinessReport> {
    const [database, redis, media] = await Promise.all([
      this.checkDependency(() => this.prisma.$queryRawUnsafe('SELECT 1')),
      this.checkRedis(),
      this.checkMedia(),
    ]);
    const checks = { database, redis, media };
    const ready = Object.values(checks).every(
      (check) => check.status !== 'down',
    );
    return {
      status: ready ? 'ready' : 'not_ready',
      service: 'aarast-backend',
      checks,
    };
  }

  private async checkRedis(): Promise<DependencyReadiness> {
    const redisUrl = process.env.REDIS_URL?.trim();
    const required = dependencyRequired('READINESS_REQUIRE_REDIS');
    if (!redisUrl) return { status: required ? 'down' : 'disabled' };

    return this.checkDependency(async () => {
      const client = new Redis(redisUrl, {
        lazyConnect: true,
        connectTimeout: dependencyTimeoutMs,
        commandTimeout: dependencyTimeoutMs,
        enableOfflineQueue: false,
        maxRetriesPerRequest: 0,
        retryStrategy: () => null,
      });
      client.on('error', () => undefined);
      try {
        await client.connect();
        await client.ping();
      } finally {
        client.disconnect(false);
      }
    });
  }

  private async checkMedia(): Promise<DependencyReadiness> {
    const endpoint = process.env.AARAST_MEDIA_ENDPOINT?.trim();
    const bucket = process.env.AARAST_MEDIA_BUCKET?.trim();
    const required = dependencyRequired('READINESS_REQUIRE_MEDIA');
    if (!endpoint || !bucket) {
      return { status: required ? 'down' : 'disabled' };
    }
    return this.checkDependency(() => this.mediaStorage.checkReadiness());
  }

  private async checkDependency(
    operation: () => Promise<unknown>,
  ): Promise<DependencyReadiness> {
    const startedAt = Date.now();
    try {
      await withTimeout(operation(), dependencyTimeoutMs);
      return { status: 'up', latencyMs: Date.now() - startedAt };
    } catch {
      return { status: 'down', latencyMs: Date.now() - startedAt };
    }
  }
}

export function dependencyRequired(name: string): boolean {
  const value = process.env[name]?.trim().toLowerCase();
  if (value === 'true' || value === '1') return true;
  if (value === 'false' || value === '0') return false;
  return process.env.NODE_ENV === 'production';
}

async function withTimeout<T>(
  operation: Promise<T>,
  timeoutMs: number,
): Promise<T> {
  let timeout: NodeJS.Timeout | undefined;
  try {
    return await Promise.race([
      operation,
      new Promise<never>((_, reject) => {
        timeout = setTimeout(
          () => reject(new Error('Dependency readiness timed out')),
          timeoutMs,
        );
        timeout.unref?.();
      }),
    ]);
  } finally {
    if (timeout) clearTimeout(timeout);
  }
}
