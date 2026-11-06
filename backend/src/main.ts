import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { ConsoleLogger, Logger, ValidationPipe } from '@nestjs/common';
import type { NestExpressApplication } from '@nestjs/platform-express';
import * as Sentry from '@sentry/node';
import helmet from 'helmet';
import { AppModule } from './app.module';
import { getCorsOptions } from './platform/config/cors-options';
import { validateRuntimeEnvironment } from './platform/config/runtime-environment';
import { clientContractGate, minClientContract } from './platform/http/client-contract';
import { GlobalExceptionFilter } from './platform/http/global-exception.filter';
import { requestObservability } from './platform/observability/request-observability.middleware';
import { RedisIoAdapter } from './platform/redis/redis-io.adapter';
import { getJwtSecret } from './modules/identity/internal/auth/jwt-secret';

/**
 * Fail fast on broken configuration: a typo'd env var must stop the
 * deployment at boot, not surface as silent degradation at runtime.
 */
function validateEnvironment(logger: Logger): void {
  validateRuntimeEnvironment(process.env, getJwtSecret);
  if (process.env.NODE_ENV !== 'production') {
    logger.warn(
      'NODE_ENV is not "production" — dev conveniences (echoed OTP codes, permissive CORS) are ACTIVE.',
    );
  }
}

async function bootstrap() {
  const logger = new Logger('Bootstrap');
  validateEnvironment(logger);

  const sentryDsn = process.env.SENTRY_DSN?.trim();
  if (sentryDsn) {
    Sentry.init({
      dsn: sentryDsn,
      environment: process.env.NODE_ENV ?? 'development',
      tracesSampleRate: 0.1,
    });
  }

  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    // JSON logs in production so Dokploy/aggregators can parse fields
    // instead of scraping pretty-printed text.
    logger:
      process.env.NODE_ENV === 'production'
        ? new ConsoleLogger({ json: true })
        : undefined,
  });
  const port = Number(process.env.PORT ?? 3000);

  const redisUrl = process.env.REDIS_URL?.trim();
  if (redisUrl) {
    const redisIoAdapter = new RedisIoAdapter(app);
    await redisIoAdapter.connectToRedis(redisUrl);
    app.useWebSocketAdapter(redisIoAdapter);
  } else if (process.env.NODE_ENV === 'production') {
    logger.warn(
      'REDIS_URL is not set — Socket.IO delivery and rate limiting are single-instance only.',
    );
  }

  // Behind Dokploy/NPM every request arrives from the proxy IP. Without
  // trust proxy the throttler rate-limits ALL users collectively instead
  // of per client.
  app.set('trust proxy', 1);

  app.use(helmet());
  app.use(requestObservability);
  // RA-BE-01: an app older than MIN_CLIENT_CONTRACT is told to update.
  app.use(clientContractGate(minClientContract()));

  app.enableCors(getCorsOptions());

  app.useGlobalPipes(
    // transform is required so @Type() conversions run on query-string
    // DTOs (pagination take/skip arrive as strings otherwise).
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  app.useGlobalFilters(new GlobalExceptionFilter());

  // SIGTERM from rolling deploys must drain in-flight requests instead
  // of dropping them mid-transaction.
  app.enableShutdownHooks();

  await app.listen(port);
  logger.log(
    `Aarast API listening on :${port} (env=${process.env.NODE_ENV ?? 'development'})`,
  );
}

void bootstrap();
