import {
  Controller,
  Get,
  Header,
  Headers,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { metricsRegistry } from './metrics';

/** Where the code runs on a developer's machine, not behind a public proxy. */
const OPEN_WITHOUT_TOKEN = new Set(['development', 'test']);

/**
 * Prometheus scrape endpoint. Without METRICS_TOKEN it exists only on a
 * developer's machine (development, test): the backend port is reachable
 * through the public proxy and metrics leak internal topology, and a
 * staging host or an unset NODE_ENV is as public as production (RA-BE-05).
 */
@Controller('metrics')
export class MetricsController {
  @Get()
  @Header('Content-Type', 'text/plain; version=0.0.4; charset=utf-8')
  async metrics(@Headers('authorization') authorization?: string) {
    const token = process.env.METRICS_TOKEN?.trim();

    if (!token) {
      if (!OPEN_WITHOUT_TOKEN.has(process.env.NODE_ENV ?? '')) {
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
