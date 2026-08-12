import {
  Controller,
  Get,
  Header,
  Headers,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { metricsRegistry } from './metrics';

/**
 * Prometheus scrape endpoint. In production it only exists when
 * METRICS_TOKEN is configured, because the backend port is reachable
 * through the public proxy and metrics leak internal topology.
 */
@Controller('metrics')
export class MetricsController {
  @Get()
  @Header('Content-Type', 'text/plain; version=0.0.4; charset=utf-8')
  async metrics(@Headers('authorization') authorization?: string) {
    const token = process.env.METRICS_TOKEN?.trim();

    if (!token) {
      if (process.env.NODE_ENV === 'production') {
        throw new NotFoundException();
      }
      return metricsRegistry.metrics();
    }

    if (authorization !== `Bearer ${token}`) {
      throw new UnauthorizedException();
    }
    return metricsRegistry.metrics();
  }
}
