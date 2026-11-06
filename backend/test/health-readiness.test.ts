import 'reflect-metadata';

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { afterEach, test } from 'node:test';
import { Module, ServiceUnavailableException } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { HealthController } from '../src/platform/health/health.controller';
import {
  dependencyRequired,
  READINESS_FETCH,
  ReadinessReport,
  ReadinessService,
} from '../src/platform/health/readiness.service';
import {
  MEDIA_READINESS_PORT,
  MediaReadinessPort,
} from '../src/platform/health/media-readiness.port';
import { PrismaService } from '../src/platform/database/prisma.service';

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
    { provide: MEDIA_READINESS_PORT, useValue: {} },
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
    { checkReadiness: async () => undefined } as MediaReadinessPort,
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
    { checkReadiness: async () => undefined } as MediaReadinessPort,
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
    { checkReadiness: async () => undefined } as MediaReadinessPort,
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
      otpCapacity: { status: 'up' },
      disk: { status: 'up' },
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

// J1-19, RA-BE-02: /ready says how close the daily WhatsApp-code limit is, so
// the uptime alarm warns before sign-ups stop. Status only, no counts.
for (const [capacity, status, ready] of [
  ['up', 'up', 'ready'],
  ['near_limit', 'near_limit', 'ready'],
  ['exhausted', 'down', 'not_ready'],
] as const) {
  test(`a ${capacity} code quota reads ${status} and leaves /ready ${ready}`, async () => {
    process.env.NODE_ENV = 'test';
    delete process.env.REDIS_URL;
    delete process.env.AARAST_MEDIA_ENDPOINT;
    delete process.env.AARAST_MEDIA_BUCKET;
    process.env.AUTH_OTP_MODE = 'dev';
    const service = new ReadinessService(
      { $queryRawUnsafe: async () => [{ '?column?': 1 }] } as unknown as PrismaService,
      { checkReadiness: async () => undefined } as MediaReadinessPort,
      fetch,
      { capacity: async () => capacity },
    );
    const report = await service.check();
    assert.deepEqual(report.checks.otpCapacity, { status });
    assert.equal(report.status, ready);
    const core = await service.checkCore();
    assert.equal(core.status, 'ready', 'the quota never fails the host check');
    assert.equal('otpCapacity' in core.checks, false);
  });
}

// RA-OP-06: the host's disk, read from inside the container (its root is the
// host's disk). Low under 2 GiB or a tenth free; it warns, it never fails
// /ready, and it is not part of the host check a deploy waits on.
const GiB = 1024 ** 3;
for (const [freeGiB, status] of [
  [20, 'up'],
  [3.5, 'up'],
  [2.5, 'low'],
  [1, 'low'],
] as const) {
  test(`a disk with ${freeGiB} GiB of 30 free reads ${status}`, async () => {
    process.env.NODE_ENV = 'test';
    delete process.env.REDIS_URL;
    delete process.env.AARAST_MEDIA_ENDPOINT;
    delete process.env.AARAST_MEDIA_BUCKET;
    process.env.AUTH_OTP_MODE = 'disabled';
    const asked: string[] = [];
    const service = new ReadinessService(
      { $queryRawUnsafe: async () => [{ '?column?': 1 }] } as unknown as PrismaService,
      { checkReadiness: async () => undefined } as MediaReadinessPort,
      fetch,
      undefined,
      async (path: string) => {
        asked.push(path);
        return { bsize: 4096, blocks: (30 * GiB) / 4096, bavail: (freeGiB * GiB) / 4096 };
      },
    );
    const report = await service.check();
    assert.deepEqual(report.checks.disk, { status });
    assert.equal(report.status, 'ready');
    assert.deepEqual(asked, ['/']);
    assert.equal('disk' in (await service.checkCore()).checks, false);
  });
}

test('an unreadable disk is not reported', async () => {
  process.env.NODE_ENV = 'test';
  process.env.AUTH_OTP_MODE = 'disabled';
  const service = new ReadinessService(
    { $queryRawUnsafe: async () => [{ '?column?': 1 }] } as unknown as PrismaService,
    { checkReadiness: async () => undefined } as MediaReadinessPort,
    fetch,
    undefined,
    async () => {
      throw new Error('statfs unsupported');
    },
  );
  assert.deepEqual((await service.check()).checks.disk, { status: 'disabled' });
});

test('an unreadable code quota reads down, and no quota without codes', async () => {
  process.env.NODE_ENV = 'test';
  delete process.env.REDIS_URL;
  delete process.env.AARAST_MEDIA_ENDPOINT;
  delete process.env.AARAST_MEDIA_BUCKET;
  const prisma = { $queryRawUnsafe: async () => [{ '?column?': 1 }] } as unknown as PrismaService;
  const media = { checkReadiness: async () => undefined } as MediaReadinessPort;
  process.env.AUTH_OTP_MODE = 'openwa';
  const failing = new ReadinessService(prisma, media, fetch, {
    capacity: async () => {
      throw new Error('database gone');
    },
  });
  assert.deepEqual((await failing.check()).checks.otpCapacity, { status: 'down' });
  process.env.AUTH_OTP_MODE = 'disabled';
  const off = new ReadinessService(prisma, media, fetch, { capacity: async () => 'exhausted' });
  assert.deepEqual((await off.check()).checks.otpCapacity, { status: 'disabled' });
  // A context without the port (tests, tools) reports it disabled too.
  process.env.AUTH_OTP_MODE = 'openwa';
  assert.deepEqual((await new ReadinessService(prisma, media).check()).checks.otpCapacity, { status: 'disabled' });
});

test('a stopped OpenWA leaves the core ready while /ready tells the truth', async () => {
  process.env.NODE_ENV = 'test';
  process.env.AUTH_OTP_MODE = 'openwa';
  process.env.OPENWA_BASE_URL = 'http://openwa:3000';
  process.env.OPENWA_SESSION_ID = 'aarast-otp';
  process.env.OPENWA_API_KEY = 'a-secure-openwa-api-key-for-tests-only';
  const service = new ReadinessService(
    { $queryRawUnsafe: async () => [{ '?column?': 1 }] } as unknown as PrismaService,
    { checkReadiness: async () => undefined } as MediaReadinessPort,
    async () =>
      new Response(JSON.stringify({ ready: false, transientText: false }), {
        status: 200,
        headers: { 'content-type': 'application/json' },
      }),
  );
  const controller = new HealthController(service);

  const core = await controller.getCoreReadiness();
  assert.equal(core.status, 'ready');
  assert.deepEqual(Object.keys(core.checks).sort(), ['database', 'media', 'redis']);
  await assert.rejects(() => controller.getReadiness(), ServiceUnavailableException);
});

test('the core is not ready without its database', async () => {
  process.env.NODE_ENV = 'test';
  const controller = new HealthController(
    new ReadinessService(
      {
        $queryRawUnsafe: async () => {
          throw new Error('database stopped');
        },
      } as unknown as PrismaService,
      { checkReadiness: async () => undefined } as MediaReadinessPort,
    ),
  );

  await assert.rejects(
    () => controller.getCoreReadiness(),
    ServiceUnavailableException,
  );
});

test('the host judges the backend by its core, never by OpenWA', () => {
  const compose = readFileSync(
    join(__dirname, '..', '..', 'deploy', 'aws', 'compose.yml'),
    'utf8',
  );

  assert.match(compose, /127\.0\.0\.1:3000\/ready\/core/);
  assert.doesNotMatch(compose, /127\.0\.0\.1:3000\/ready'/);
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
    { checkReadiness: async () => undefined } as MediaReadinessPort,
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
    { checkReadiness: async () => undefined } as MediaReadinessPort,
    async () => new Response('Not Found', { status: 404 }),
  );

  const report = await service.check();
  assert.equal(report.status, 'not_ready');
  assert.equal(report.checks.openwa.status, 'down');
});
