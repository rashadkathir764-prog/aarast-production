import {
  Controller,
  Get,
  Headers,
  ServiceUnavailableException,
} from '@nestjs/common';
import { SkipThrottle, Throttle } from '@nestjs/throttler';
import { operatorTokenMatches } from '../observability/operator-token';
import { publicReadiness, ReadinessService } from './readiness.service';

/**
 * RA-BE-149: /ready runs its checks (the database, Redis, the media bucket,
 * OpenWA) for whoever asks, so one address asks it this many times a
 * minute; the uptime probe asks once in five. The liveness routes and the
 * host's /ready/core stay unlimited.
 */
export const READINESS_REQUESTS_PER_MINUTE = 10;

@Controller()
export class HealthController {
  constructor(private readonly readiness: ReadinessService) {}

  @Get('health')
  @SkipThrottle()
  getCompatibilityHealth() {
    return this.getLiveness();
  }

  @Get('live')
  @SkipThrottle()
  getLiveness() {
    return {
      status: 'ok',
      service: 'aarast-backend',
    };
  }

  /**
   * RA-BE-149: the code quota and the disk answer the operator's token only
   * (the uptime probe sends it); anyone else reads the dependencies.
   */
  @Get('ready')
  @Throttle({ default: { limit: READINESS_REQUESTS_PER_MINUTE, ttl: 60_000 } })
  async getReadiness(@Headers('authorization') authorization?: string) {
    const whole = await this.readiness.check();
    const report = operatorTokenMatches(authorization)
      ? whole
      : publicReadiness(whole);
    if (report.status !== 'ready') {
      throw new ServiceUnavailableException(report);
    }
    return report;
  }

  /** The host's health check: OpenWA's outage is not the backend's. */
  @Get('ready/core')
  @SkipThrottle()
  async getCoreReadiness() {
    const report = await this.readiness.checkCore();
    if (report.status !== 'ready') {
      throw new ServiceUnavailableException(report);
    }
    return report;
  }
}
