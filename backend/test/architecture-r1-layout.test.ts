import assert from 'node:assert/strict';
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';
import { test } from 'node:test';

const backendRoot = path.resolve(__dirname, '..');

function source(relativePath: string): string {
  return readFileSync(path.join(backendRoot, relativePath), 'utf8');
}

function typescriptFiles(root: string): string[] {
  if (!existsSync(root)) return [];
  return readdirSync(root, { withFileTypes: true }).flatMap((entry) => {
    const target = path.join(root, entry.name);
    if (entry.isDirectory()) return typescriptFiles(target);
    return entry.isFile() && entry.name.endsWith('.ts') ? [target] : [];
  });
}

test('R1 Task 2 platform foundation exists only at canonical paths', () => {
  assert.equal(existsSync(path.join(backendRoot, 'src/prisma')), false, 'src/prisma directory');
  assert.equal(existsSync(path.join(backendRoot, 'src/health')), false, 'src/health directory');
  const moved = [
    ['src/common/config/cors-options.ts', 'src/platform/config/cors-options.ts'],
    ['src/common/config/cors-origins.ts', 'src/platform/config/cors-origins.ts'],
    ['src/common/config/runtime-environment.ts', 'src/platform/config/runtime-environment.ts'],
    ['src/common/filters/global-exception.filter.ts', 'src/platform/http/global-exception.filter.ts'],
    ['src/common/http/bounded-json-response.ts', 'src/platform/http/bounded-json-response.ts'],
    ['src/common/pagination/list-query.dto.ts', 'src/platform/http/list-query.dto.ts'],
    ['src/common/redis/redis-io.adapter.ts', 'src/platform/redis/redis-io.adapter.ts'],
    ['src/common/redis/resilient-throttler-storage.ts', 'src/platform/redis/resilient-throttler-storage.ts'],
    ['src/common/observability/metrics.controller.ts', 'src/platform/observability/metrics.controller.ts'],
    ['src/common/observability/metrics.ts', 'src/platform/observability/metrics.ts'],
    ['src/common/observability/request-observability.middleware.ts', 'src/platform/observability/request-observability.middleware.ts'],
    ['src/common/observability/sanitize-request-target.ts', 'src/platform/observability/sanitize-request-target.ts'],
    ['src/common/prisma/serializable-transaction.ts', 'src/platform/database/serializable-transaction.ts'],
    ['src/prisma/prisma.module.ts', 'src/platform/database/prisma.module.ts'],
    ['src/prisma/prisma.service.ts', 'src/platform/database/prisma.service.ts'],
    ['src/health.controller.ts', 'src/platform/health/health.controller.ts'],
    ['src/health/readiness.service.ts', 'src/platform/health/readiness.service.ts'],
  ];
  for (const [legacy, canonical] of moved) {
    assert.equal(existsSync(path.join(backendRoot, legacy)), false, legacy);
    assert.equal(existsSync(path.join(backendRoot, canonical)), true, canonical);
  }
});

test('R1 Task 2 preserves Prisma lifecycle and approved global provenance', () => {
  const moduleSource = source('src/platform/database/prisma.module.ts');
  const serviceSource = source('src/platform/database/prisma.service.ts');
  assert.match(moduleSource, /import\s*\{[^}]*\bGlobal\b[^}]*\}\s*from\s*['"]@nestjs\/common['"]/);
  assert.match(moduleSource, /@Global\(\)/);
  assert.match(serviceSource, /onModuleInit\s*\(\)[\s\S]*this\.\$connect\(\)/);
  assert.match(serviceSource, /onModuleDestroy\s*\(\)[\s\S]*this\.\$disconnect\(\)/);
  const scanner = source('scripts/architecture/ports-scan.cjs');
  assert.match(scanner, /backend\/src\/platform\/database\/prisma\.module\.ts/);
  assert.doesNotMatch(scanner, /backend\/src\/prisma\/prisma\.module\.ts/);
});

test('R1 Task 2 source and tests have no imports of moved legacy paths', () => {
  const importSpecifiers = /(?:from\s*['"]|require\(\s*['"])([^'"\n]+)/g;
  const isLegacy = (specifier: string) => (
    /common\/(?:config|filters|http|pagination|redis|observability|prisma)/.test(specifier)
    || /prisma\/prisma\.(?:module|service)/.test(specifier)
    || (specifier.endsWith('/health.controller') && !specifier.includes('platform/health/health.controller'))
    || (/health\/readiness/.test(specifier) && !specifier.includes('platform/health/readiness'))
  );
  const roots = ['src', 'test', 'scripts'].map((entry) => path.join(backendRoot, entry));
  const stale = roots.flatMap(typescriptFiles)
    .filter((file) => file !== __filename)
    .filter((file) => {
      const contents = readFileSync(file, 'utf8');
      return [...contents.matchAll(importSpecifiers)].some((match) => isLegacy(match[1]));
    })
    .map((file) => path.relative(backendRoot, file).replace(/\\/g, '/'))
    .sort();
  assert.deepEqual(stale, []);
});

test('R1 Task 3 mixed ownership roots are exact', () => {
  const registry = JSON.parse(source('architecture/ownership-registry.json')) as {
    currentRoots: { platform: string[] };
  };
  assert.deepEqual(registry.currentRoots.platform, ['common', 'platform']);
});

test('R1 Task 3 idempotency and outbox runtime exist only at canonical paths', () => {
  const moved = [
    ['src/common/idempotency/idempotency.interceptor.ts', 'src/platform/idempotency/idempotency.interceptor.ts'],
    ['src/common/idempotency/idempotency-cleanup.scheduler.ts', 'src/platform/idempotency/idempotency-cleanup.scheduler.ts'],
    ['src/common/idempotency/idempotency-reconcile.cli.ts', 'src/platform/idempotency/idempotency-reconcile.cli.ts'],
    ['src/common/idempotency/idempotency-reconciliation.ts', 'src/platform/idempotency/idempotency-reconciliation.ts'],
    ['src/outbox/outbox.constants.ts', 'src/platform/outbox/outbox.constants.ts'],
    ['src/outbox/outbox.dispatcher.ts', 'src/platform/outbox/outbox.dispatcher.ts'],
    ['src/outbox/outbox.module.ts', 'src/platform/outbox/outbox.module.ts'],
    ['src/outbox/outbox.service.ts', 'src/platform/outbox/outbox.service.ts'],
    ['src/outbox/outbox.worker.ts', 'src/platform/outbox/outbox.worker.ts'],
    ['src/outbox/outbox-cleanup.scheduler.ts', 'src/platform/outbox/outbox-cleanup.scheduler.ts'],
    ['src/outbox/realtime-revocation.ts', 'src/platform/outbox/realtime-revocation.ts'],
  ];
  for (const [legacy, canonical] of moved) {
    assert.equal(existsSync(path.join(backendRoot, legacy)), false, legacy);
    assert.equal(existsSync(path.join(backendRoot, canonical)), true, canonical);
  }
  assert.equal(existsSync(path.join(backendRoot, 'src/outbox')), false, 'src/outbox directory');
});

test('R1 Task 3 production idempotency command targets the canonical build output', () => {
  const packageJson = JSON.parse(source('package.json')) as {
    scripts: Record<string, string>;
  };
  assert.equal(
    packageJson.scripts['prod:reconcile-idempotency'],
    'node dist/platform/idempotency/idempotency-reconcile.cli.js',
  );
});

test('R1 Task 3 preserves outbox scheduling retry and module export contracts', () => {
  const worker = source('src/platform/outbox/outbox.worker.ts');
  const cleanup = source('src/platform/outbox/outbox-cleanup.scheduler.ts');
  const moduleSource = source('src/platform/outbox/outbox.module.ts');
  assert.match(worker, /const\s+maxAttempts\s*=\s*8\s*;/);
  assert.match(worker, /@Interval\(1_000\)/);
  assert.match(cleanup, /const\s+CLEANUP_INTERVAL_MS\s*=\s*6\s*\*\s*60\s*\*\s*60\s*\*\s*1_000\s*;/);
  assert.match(cleanup, /const\s+PROCESSED_RETENTION_MS\s*=\s*7\s*\*\s*24\s*\*\s*60\s*\*\s*60\s*\*\s*1_000\s*;/);
  assert.match(moduleSource, /exports:\s*\[OutboxService\]/);
});

test('R1 Task 3 source tests and smokes have no stale idempotency or outbox paths', () => {
  const roots = [
    path.join(backendRoot, 'src'),
    path.join(backendRoot, 'test'),
    path.join(backendRoot, 'scripts', 'smoke'),
  ];
  const stale = roots.flatMap(typescriptFiles)
    .filter((file) => file !== __filename)
    .filter((file) => path.basename(file) !== 'architecture-r1-baseline-relocation.test.ts')
    .filter((file) => {
      const contents = readFileSync(file, 'utf8');
      return /(?:src|dist)\/common\/idempotency\//.test(contents)
        || /(?:src|dist)\/outbox\//.test(contents)
        || /(?:from\s*['"]|require\(\s*['"])[^'"\n]*common\/idempotency\//.test(contents)
        || /(?:from\s*['"]|require\(\s*['"])(?![^'"\n]*platform\/outbox\/)[^'"\n]*outbox\//.test(contents);
    })
    .map((file) => path.relative(backendRoot, file).replace(/\\/g, '/'))
    .sort();
  assert.deepEqual(stale, []);
});

test('R1 Task 4 OTP transport exists only at canonical paths', () => {
  const moved = [
    ['src/auth/openwa-otp-config.ts', 'src/platform/otp-transport/openwa-otp-config.ts'],
    ['src/auth/openwa-transient-text.ts', 'src/platform/otp-transport/openwa-transient-text.ts'],
    ['src/auth/whatsapp-otp-config.ts', 'src/platform/otp-transport/whatsapp-otp-config.ts'],
  ];
  const created = [
    'src/platform/otp-transport/otp-delivery.ts',
    'src/platform/otp-transport/openwa-otp.channel.ts',
    'src/platform/otp-transport/whatsapp-otp.channel.ts',
  ];

  for (const [legacy, canonical] of moved) {
    assert.equal(existsSync(path.join(backendRoot, legacy)), false, legacy);
    assert.equal(existsSync(path.join(backendRoot, canonical)), true, canonical);
  }
  for (const canonical of created) {
    assert.equal(existsSync(path.join(backendRoot, canonical)), true, canonical);
  }
});

test('R1 Task 4 keeps OTP identity policy out of production transports', () => {
  const identitySource = source('src/auth/otp-channel.ts');
  assert.match(identitySource, /export\s+interface\s+OtpChannel\b/);
  assert.match(identitySource, /export\s+class\s+DevEchoOtpChannel\b/);
  assert.match(identitySource, /export\s+function\s+generateProductionOtpCode\b/);
  assert.match(
    identitySource,
    /randomInt\(0,\s*1_000_000\)\.toString\(\)\.padStart\(6,\s*'0'\)/,
  );
  assert.doesNotMatch(identitySource, /\b(?:WhatsAppOtpChannel|OpenWaOtpChannel)\b/);
  assert.doesNotMatch(
    identitySource,
    /graph\.facebook\.com|sendOpenWaTransientText|load(?:WhatsApp|OpenWa)OtpConfig|\bfetch\b|JSON\.stringify/,
  );

  const registry = JSON.parse(source('architecture/ownership-registry.json')) as {
    currentRoots: Record<string, string[]>;
  };
  const businessRoots = Object.entries(registry.currentRoots)
    .filter(([owner]) => owner !== 'platform')
    .flatMap(([, roots]) => roots);
  const importSpecifiers = /(?:from\s*['"]|require\(\s*['"])([^'"\n]+)/g;
  const transportRoot = path.join(backendRoot, 'src/platform/otp-transport');
  for (const file of typescriptFiles(transportRoot)) {
    const contents = readFileSync(file, 'utf8');
    const specifiers = [...contents.matchAll(importSpecifiers)].map((match) => match[1]);
    assert.equal(
      specifiers.some((specifier) =>
        specifier.includes('/auth/')
        || specifier.startsWith('../../auth')
        || specifier.includes('/modules/')
        || specifier.startsWith('../../modules')
        || businessRoots.some((root) => specifier.startsWith(`../../${root}`))),
      false,
      path.relative(backendRoot, file),
    );
    assert.doesNotMatch(contents, /\brandomInt\b|\bgenerateCode\s*\(|\bgenerateProductionOtpCode\b/);
  }
});

test('R1 Task 4 production OTP generator remains six-digit and zero-padded', () => {
  const { generateProductionOtpCode } = require('../src/auth/otp-channel') as {
    generateProductionOtpCode: () => string;
  };
  const samples = Array.from({ length: 2_000 }, generateProductionOtpCode);
  assert.equal(samples.every((code) => /^\d{6}$/.test(code)), true);
});

test('R1 Task 4 delivery uncertainty contract is fixed and secret-safe', () => {
  const { OtpDeliveryUncertainError } = require(
    '../src/platform/otp-transport/otp-delivery',
  ) as {
    OtpDeliveryUncertainError: new () => Error;
  };
  const error = new OtpDeliveryUncertainError();
  assert.equal(error.name, 'OtpDeliveryUncertainError');
  assert.equal(error.message, 'OTP delivery outcome is uncertain');
  assert.deepEqual(Object.keys(error), ['name']);
});

test('R1 Task 4 AuthService owns selection while sharing keeps named pre-R6 transport debt', () => {
  const authServiceSource = source('src/auth/auth.service.ts');
  assert.match(authServiceSource, /from\s+['"]\.\/otp-channel['"]/);
  assert.match(
    authServiceSource,
    /from\s+['"]\.\.\/platform\/otp-transport\/(?:otp-delivery|openwa-otp\.channel|whatsapp-otp\.channel)['"]/,
  );
  assert.match(authServiceSource, /generateProductionOtpCode/);
  assert.match(authServiceSource, /resolveOtpChannel\s*\(/);

  const sharingSource = source('src/sharing/invitation-delivery.service.ts');
  assert.match(
    sharingSource,
    /from\s+['"]\.\.\/platform\/otp-transport\/openwa-transient-text['"]/,
  );
  assert.doesNotMatch(sharingSource, /auth\/openwa-transient-text/);
});
