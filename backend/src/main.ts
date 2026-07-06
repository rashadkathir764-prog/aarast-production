import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { Logger, ValidationPipe } from '@nestjs/common';
import type { NestExpressApplication } from '@nestjs/platform-express';
import helmet from 'helmet';
import { AppModule } from './app.module';
import { getCorsOrigins } from './common/config/cors-origins';
import { GlobalExceptionFilter } from './common/filters/global-exception.filter';

/**
 * Fail fast on broken configuration: a typo'd env var must stop the
 * deployment at boot, not surface as silent degradation at runtime.
 */
function validateEnvironment(logger: Logger): void {
  const missing = ['DATABASE_URL', 'JWT_SECRET'].filter(
    (name) => !process.env[name]?.trim(),
  );
  if (missing.length > 0) {
    throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
  }

  const otpMode = process.env.AUTH_OTP_MODE?.trim();
  if (otpMode && !['dev', 'whatsapp', 'disabled'].includes(otpMode)) {
    throw new Error(
      `AUTH_OTP_MODE must be one of dev|whatsapp|disabled, got "${otpMode}"`,
    );
  }

  if (process.env.NODE_ENV !== 'production') {
    logger.warn(
      'NODE_ENV is not "production" — dev conveniences (echoed OTP codes, permissive CORS) are ACTIVE.',
    );
  }
}

async function bootstrap() {
  const logger = new Logger('Bootstrap');
  validateEnvironment(logger);

  const app = await NestFactory.create<NestExpressApplication>(AppModule);
  const port = Number(process.env.PORT ?? 3000);

  // Behind Dokploy/NPM every request arrives from the proxy IP. Without
  // trust proxy the throttler rate-limits ALL users collectively instead
  // of per client.
  app.set('trust proxy', 1);

  app.use(helmet());

  app.enableCors({
    origin: getCorsOrigins(),
    methods: ['GET', 'POST', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Client-Request-Id'],
  });

  app.useGlobalPipes(
    new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true }),
  );

  app.useGlobalFilters(new GlobalExceptionFilter());

  await app.listen(port);
  logger.log(
    `Aarast API listening on :${port} (env=${process.env.NODE_ENV ?? 'development'})`,
  );
}

void bootstrap();
