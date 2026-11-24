import {
  Controller,
  Get,
  Headers,
  ServiceUnavailableException,
} from '@nestjs/common';
import { SkipThrottle } from '@nestjs/throttler';
import { operatorTokenMatches } from '../observability/operator-token';
import { publicReadiness, ReadinessService } from './readiness.service';

@SkipThrottle()
@Controller()
export class HealthController {
  constructor(private readonly readiness: ReadinessService) {}

  @Get('health')
  getCompatibilityHealth() {
    return this.getLiveness();
  }

  @Get('live')
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
  async getCoreReadiness() {
    const report = await this.readiness.checkCore();
    if (report.status !== 'ready') {
      throw new ServiceUnavailableException(report);
    }
    return report;
  }
}
