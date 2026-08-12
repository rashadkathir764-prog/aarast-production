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

test('R1 Task 2 mixed ownership roots are exact', () => {
  const registry = JSON.parse(source('architecture/ownership-registry.json')) as {
    currentRoots: { platform: string[] };
  };
  assert.deepEqual(registry.currentRoots.platform, ['common', 'outbox', 'platform']);
});
