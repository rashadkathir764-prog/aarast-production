import {
  Controller,
  Get,
  ServiceUnavailableException,
} from '@nestjs/common';
import { SkipThrottle } from '@nestjs/throttler';
import { ReadinessService } from './health/readiness.service';

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

  @Get('ready')
  async getReadiness() {
    const report = await this.readiness.check();
    if (report.status !== 'ready') {
      throw new ServiceUnavailableException(report);
    }
    return report;
  }
}
