import 'reflect-metadata';

import assert from 'node:assert/strict';
import { afterEach, test } from 'node:test';
import { Module, ServiceUnavailableException } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { HealthController } from '../src/health.controller';
import {
  dependencyRequired,
  READINESS_FETCH,
  ReadinessReport,
  ReadinessService,
} from '../src/health/readiness.service';
import { MediaStorageService } from '../src/media/media-storage.service';
import { PrismaService } from '../src/prisma/prisma.service';

const savedEnvironment = {
  NODE_ENV: process.env.NODE_ENV,
  REDIS_URL: process.env.REDIS_URL,
  AARAST_MEDIA_ENDPOINT: process.env.AARAST_MEDIA_ENDPOINT,
  AARAST_MEDIA_BUCKET: process.env.AARAST_MEDIA_BUCKET,
  READINESS_REQUIRE_REDIS: process.env.READINESS_REQUIRE_REDIS,
  READINESS_REQUIRE_MEDIA: process.env.READINESS_REQUIRE_MEDIA,
  AUTH_OTP_MODE: process.env.AUTH_OTP_MODE,
  OPENWA_BASE_URL: process.env.OPENWA_BASE_URL,
  OPENWA_SESSION_ID: process.env.OPENWA_SESSION_ID,
  OPENWA_API_KEY: process.env.OPENWA_API_KEY,
};

@Module({
  providers: [
    ReadinessService,
    { provide: PrismaService, useValue: {} },
    { provide: MediaStorageService, useValue: {} },
    { provide: READINESS_FETCH, useValue: fetch },
  ],
})
class ReadinessWiringTestModule {}

afterEach(() => {
  for (const [name, value] of Object.entries(savedEnvironment)) {
    if (value === undefined) delete process.env[name];
    else process.env[name] = value;
  }
});

test('Nest resolves the readiness fetch implementation through an explicit token', async () => {
  const context = await NestFactory.createApplicationContext(
    ReadinessWiringTestModule,
    { logger: false },
  );
  try {
    assert.ok(context.get(ReadinessService));
  } finally {
    await context.close();
  }
});

test('liveness remains dependency-free', () => {
  const controller = new HealthController({} as ReadinessService);
  assert.deepEqual(controller.getLiveness(), {
    status: 'ok',
    service: 'aarast-backend',
  });
});

test('readiness reports database up and optional dependencies disabled', async () => {
  process.env.NODE_ENV = 'test';
  delete process.env.REDIS_URL;
  delete process.env.AARAST_MEDIA_ENDPOINT;
  delete process.env.AARAST_MEDIA_BUCKET;
  delete process.env.READINESS_REQUIRE_REDIS;
  delete process.env.READINESS_REQUIRE_MEDIA;
  process.env.AUTH_OTP_MODE = 'disabled';

  const service = new ReadinessService(
    {
      $queryRawUnsafe: async () => [{ '?column?': 1 }],
    } as unknown as PrismaService,
    { checkReadiness: async () => undefined } as MediaStorageService,
  );
  const report = await service.check();

  assert.equal(report.status, 'ready');
  assert.equal(report.checks.database.status, 'up');
  assert.equal(report.checks.redis.status, 'disabled');
  assert.equal(report.checks.media.status, 'disabled');
  assert.equal(report.checks.openwa.status, 'disabled');
});

test('production readiness fails closed when Redis and media are absent', async () => {
  process.env.NODE_ENV = 'production';
  delete process.env.REDIS_URL;
  delete process.env.AARAST_MEDIA_ENDPOINT;
  delete process.env.AARAST_MEDIA_BUCKET;
  delete process.env.READINESS_REQUIRE_REDIS;
  delete process.env.READINESS_REQUIRE_MEDIA;
  process.env.AUTH_OTP_MODE = 'disabled';

  const service = new ReadinessService(
    {
      $queryRawUnsafe: async () => [{ '?column?': 1 }],
    } as unknown as PrismaService,
    { checkReadiness: async () => undefined } as MediaStorageService,
  );
  const report = await service.check();

  assert.equal(report.status, 'not_ready');
  assert.equal(report.checks.redis.status, 'down');
  assert.equal(report.checks.media.status, 'down');
  assert.equal(report.checks.openwa.status, 'disabled');
});

test('database failure returns a redacted down state', async () => {
  process.env.NODE_ENV = 'test';
  const service = new ReadinessService(
    {
      $queryRawUnsafe: async () => {
        throw new Error('postgres://secret-user:secret-password@db/private');
      },
    } as unknown as PrismaService,
    { checkReadiness: async () => undefined } as MediaStorageService,
  );
  const report = await service.check();

  assert.equal(report.status, 'not_ready');
  assert.deepEqual(Object.keys(report.checks.database).sort(), [
    'latencyMs',
    'status',
  ]);
  assert.equal(JSON.stringify(report).includes('secret-password'), false);
});

test('controller emits 503 for a non-ready report', async () => {
  const report: ReadinessReport = {
    status: 'not_ready',
    service: 'aarast-backend',
    checks: {
      database: { status: 'down', latencyMs: 1 },
      redis: { status: 'up', latencyMs: 1 },
      media: { status: 'up', latencyMs: 1 },
      openwa: { status: 'up', latencyMs: 1 },
    },
  };
  const controller = new HealthController({
    check: async () => report,
  } as ReadinessService);

  await assert.rejects(
    () => controller.getReadiness(),
    ServiceUnavailableException,
  );
});

test('dependency requirement defaults to production but allows explicit override', () => {
  process.env.NODE_ENV = 'production';
  delete process.env.READINESS_REQUIRE_REDIS;
  assert.equal(dependencyRequired('READINESS_REQUIRE_REDIS'), true);
  process.env.READINESS_REQUIRE_REDIS = 'false';
  assert.equal(dependencyRequired('READINESS_REQUIRE_REDIS'), false);
  process.env.READINESS_REQUIRE_REDIS = 'true';
  assert.equal(dependencyRequired('READINESS_REQUIRE_REDIS'), true);
});

test('OpenWA readiness requires a connected session and transient transport', async () => {
  process.env.NODE_ENV = 'test';
  process.env.AUTH_OTP_MODE = 'openwa';
  process.env.OPENWA_BASE_URL = 'http://openwa:3000';
  process.env.OPENWA_SESSION_ID = 'aarast-otp';
  process.env.OPENWA_API_KEY = 'a-secure-openwa-api-key-for-tests-only';
  const requested: string[] = [];
  const service = new ReadinessService(
    { $queryRawUnsafe: async () => [{ '?column?': 1 }] } as unknown as PrismaService,
    { checkReadiness: async () => undefined } as MediaStorageService,
    async (url) => {
      requested.push(url.toString());
      return new Response(
        JSON.stringify({ ready: true, transientText: true }),
        { status: 200, headers: { 'content-type': 'application/json' } },
      );
    },
  );

  const report = await service.check();
  assert.equal(report.checks.openwa.status, 'up');
  assert.deepEqual(requested, [
    'http://openwa:3000/api/sessions/aarast-otp/otp-readiness',
  ]);
});

test('OpenWA readiness fails closed for an upstream instance without the hardened contract', async () => {
  process.env.NODE_ENV = 'test';
  process.env.AUTH_OTP_MODE = 'openwa';
  process.env.OPENWA_BASE_URL = 'http://openwa:3000';
  process.env.OPENWA_SESSION_ID = 'aarast-otp';
  process.env.OPENWA_API_KEY = 'a-secure-openwa-api-key-for-tests-only';
  const service = new ReadinessService(
    { $queryRawUnsafe: async () => [{ '?column?': 1 }] } as unknown as PrismaService,
    { checkReadiness: async () => undefined } as MediaStorageService,
    async () => new Response('Not Found', { status: 404 }),
  );

  const report = await service.check();
  assert.equal(report.status, 'not_ready');
  assert.equal(report.checks.openwa.status, 'down');
});
