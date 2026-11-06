import { statfs as readStatfs } from 'node:fs/promises';
import { Inject, Injectable, Optional } from '@nestjs/common';
import Redis from 'ioredis';
import { PrismaService } from '../database/prisma.service';
import { loadOpenWaOtpConfig } from '../otp-transport/openwa-otp-config';
import { readBoundedJson } from '../http/bounded-json-response';
import {
  MEDIA_READINESS_PORT,
  MediaReadinessPort,
} from './media-readiness.port';
import {
  OTP_CAPACITY_READINESS_PORT,
  type OtpCapacityReadinessPort,
} from './otp-capacity-readiness.port';

export type DependencyState = 'up' | 'down' | 'disabled';

export interface DependencyReadiness {
  status: DependencyState;
  latencyMs?: number;
}

/**
 * The app-wide daily WhatsApp-code quota (J1-19, RA-BE-02). `near_limit`
 * warns while codes still go out; `down` is the limit reached, when no new
 * account can be made by code. Status only: the public /ready carries no
 * sign-up counts.
 */
export interface OtpCapacityReadiness {
  status: 'up' | 'near_limit' | 'down' | 'disabled';
}

/**
 * The host's disk (RA-OP-06), read from inside the container, whose root is
 * the host's disk. `low` under 2 GiB or a tenth free: the database stops
 * writing when it fills, and the dumps and release images grow on it. It
 * warns; it never fails /ready. Status only, no sizes.
 */
export interface DiskReadiness {
  status: 'up' | 'low' | 'disabled';
}

/** What `fs.promises.statfs` answers, as far as the disk check reads it. */
export type ReadinessStatfs = (
  path: string,
) => Promise<{ bsize: number; blocks: number; bavail: number }>;

export const READINESS_STATFS = Symbol('READINESS_STATFS');
const lowDiskBytes = 2 * 1024 ** 3;
const lowDiskShare = 0.1;

export interface ReadinessReport {
  status: 'ready' | 'not_ready';
  service: 'aarast-backend';
  checks: {
    database: DependencyReadiness;
    redis: DependencyReadiness;
    media: DependencyReadiness;
    openwa: DependencyReadiness;
    otpCapacity: OtpCapacityReadiness;
    disk: DiskReadiness;
  };
}

export interface CoreReadinessReport {
  status: ReadinessReport['status'];
  service: ReadinessReport['service'];
  checks: Omit<ReadinessReport['checks'], 'openwa' | 'otpCapacity' | 'disk'>;
}

const dependencyTimeoutMs = 2_500;
export const READINESS_FETCH = Symbol('READINESS_FETCH');

function readinessOf(
  checks: Record<string, { status: string }>,
): ReadinessReport['status'] {
  return Object.values(checks).every((check) => check.status !== 'down')
    ? 'ready'
    : 'not_ready';
}

@Injectable()
export class ReadinessService {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(MEDIA_READINESS_PORT)
    private readonly mediaStorage: MediaReadinessPort,
    @Optional()
    @Inject(READINESS_FETCH)
    private readonly fetchImplementation: typeof fetch = fetch,
    @Optional()
    @Inject(OTP_CAPACITY_READINESS_PORT)
    private readonly otpCapacity?: OtpCapacityReadinessPort,
    @Optional()
    @Inject(READINESS_STATFS)
    private readonly statfs: ReadinessStatfs = (path) => readStatfs(path),
  ) {}

  async check(): Promise<ReadinessReport> {
    const [core, openwa, otpCapacity, disk] = await Promise.all([
      this.checkCore(),
      this.checkOpenWa(),
      this.checkOtpCapacity(),
      this.checkDisk(),
    ]);
    const checks = { ...core.checks, openwa, otpCapacity, disk };
    return {
      status: readinessOf(checks),
      service: 'aarast-backend',
      checks,
    };
  }

  /**
   * What the backend cannot serve anyone without. OpenWA is left out: only
   * WhatsApp codes need it, so its outage must not mark this host unhealthy
   * or fail a release. `/ready` still reports it.
   */
  async checkCore(): Promise<CoreReadinessReport> {
    const [database, redis, media] = await Promise.all([
      this.checkDependency(() => this.prisma.$queryRawUnsafe('SELECT 1')),
      this.checkRedis(),
      this.checkMedia(),
    ]);
    const checks = { database, redis, media };
    return {
      status: readinessOf(checks),
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

  private async checkOtpCapacity(): Promise<OtpCapacityReadiness> {
    const mode = process.env.AUTH_OTP_MODE?.trim().toLowerCase();
    if (!this.otpCapacity || mode === 'disabled' || mode === undefined) {
      return { status: 'disabled' };
    }
    try {
      const capacity = await withTimeout(this.otpCapacity.capacity(), dependencyTimeoutMs);
      return { status: capacity === 'exhausted' ? 'down' : capacity };
    } catch {
      // The quota could not be read; the database check says why.
      return { status: 'down' };
    }
  }

  private async checkDisk(): Promise<DiskReadiness> {
    try {
      const stats = await withTimeout(this.statfs('/'), dependencyTimeoutMs);
      const total = stats.blocks * stats.bsize;
      const free = stats.bavail * stats.bsize;
      if (!(total > 0)) return { status: 'disabled' };
      const low = free < Math.max(lowDiskBytes, total * lowDiskShare);
      return { status: low ? 'low' : 'up' };
    } catch {
      return { status: 'disabled' };
    }
  }

  private async checkOpenWa(): Promise<DependencyReadiness> {
    const mode = process.env.AUTH_OTP_MODE?.trim().toLowerCase();
    if (mode !== 'openwa') return { status: 'disabled' };

    return this.checkDependency(async () => {
      const config = loadOpenWaOtpConfig();
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), dependencyTimeoutMs);
      try {
        const response = await this.fetchImplementation(
          `${config.baseUrl}/api/sessions/${encodeURIComponent(config.sessionId)}/otp-readiness`,
          {
            method: 'GET',
            headers: { 'X-API-Key': config.apiKey },
            redirect: 'error',
            signal: controller.signal,
          },
        );
        if (!response.ok) throw new Error('OpenWA OTP transport is unavailable');
        const payload = await readBoundedJson<{
          ready?: unknown;
          transientText?: unknown;
        }>(response);
        if (payload.ready !== true || payload.transientText !== true) {
          throw new Error('OpenWA OTP transport is not ready');
        }
      } finally {
        clearTimeout(timeout);
      }
    });
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
