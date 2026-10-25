import assert from 'node:assert/strict';
import {
  existsSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { test } from 'node:test';
import ts from 'typescript';

const backendRoot = path.resolve(__dirname, '..');

function source(relativePath: string): string {
  return readFileSync(path.join(backendRoot, relativePath), 'utf8');
}

function sourceCodeFiles(root: string): string[] {
  if (!existsSync(root)) return [];
  return readdirSync(root, { withFileTypes: true }).flatMap((entry) => {
    const target = path.join(root, entry.name);
    if (entry.isDirectory()) return sourceCodeFiles(target);
    return entry.isFile() && /\.(?:ts|js|cjs|mjs)$/.test(entry.name) ? [target] : [];
  });
}

const task5StalePattern = /(?:src|dist)\/(?:common|prisma|outbox|health)(?:\/|\.)|(?:from\s*['"]|require\(\s*['"])[^'"\n]*(?:\.\.\/common\/|\/users\/application-user-identity|\/admin\/admin-privacy)/;

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

test('R1 Task 2 preserves Prisma lifecycle in the ordinary owner module', () => {
  const moduleSource = source('src/platform/database/prisma.module.ts');
  const serviceSource = source('src/platform/database/prisma.service.ts');
  assert.equal(moduleSource, [
    "import { Module } from '@nestjs/common';",
    "import { PrismaService } from './prisma.service';",
    '',
    '@Module({',
    '  providers: [PrismaService],',
    '  exports: [PrismaService],',
    '})',
    'export class PrismaModule {}',
    '',
  ].join('\n'));
  assert.match(serviceSource, /onModuleInit\s*\(\)[\s\S]*this\.\$connect\(\)/);
  assert.match(serviceSource, /onModuleDestroy\s*\(\)[\s\S]*this\.\$disconnect\(\)/);
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
  const stale = roots.flatMap(sourceCodeFiles)
    .filter((file) => file !== __filename)
    .filter((file) => {
      const contents = readFileSync(file, 'utf8');
      return [...contents.matchAll(importSpecifiers)].some((match) => isLegacy(match[1]));
    })
    .map((file) => path.relative(backendRoot, file).replace(/\\/g, '/'))
    .sort();
  assert.deepEqual(stale, []);
});

test('R1 Task 3 ownership includes the canonical platform root', () => {
  const registry = JSON.parse(source('architecture/ownership-registry.json')) as {
    currentRoots: { platform: string[] };
  };
  assert.equal(registry.currentRoots.platform.includes('platform'), true);
});

test('R1 Task 3 idempotency and outbox runtime exist only at canonical paths', () => {
  const moved = [
    ['src/common/idempotency/idempotency.interceptor.ts', 'src/platform/idempotency/idempotency.interceptor.ts'],
    ['src/common/idempotency/idempotency-cleanup.scheduler.ts', 'src/platform/idempotency/idempotency-cleanup.scheduler.ts'],
    ['src/common/idempotency/idempotency-reconcile.cli.ts', 'src/platform/idempotency/idempotency-reconcile.cli.ts'],
    ['src/common/idempotency/idempotency-reconciliation.ts', 'src/platform/idempotency/idempotency-reconciliation.ts'],
    ['src/outbox/outbox.constants.ts', 'src/platform/outbox/outbox.constants.ts'],
    ['src/outbox/outbox.dispatcher.ts', 'src/platform/outbox/outbox.dispatcher.ts'],
    ['src/outbox/outbox.service.ts', 'src/platform/outbox/outbox.service.ts'],
    ['src/outbox/outbox.worker.ts', 'src/platform/outbox/outbox.worker.ts'],
    ['src/outbox/outbox-cleanup.scheduler.ts', 'src/platform/outbox/outbox-cleanup.scheduler.ts'],
    ['src/outbox/realtime-revocation.ts', 'src/platform/outbox/realtime-revocation.ts'],
  ];
  for (const [legacy, canonical] of moved) {
    assert.equal(existsSync(path.join(backendRoot, legacy)), false, legacy);
    assert.equal(existsSync(path.join(backendRoot, canonical)), true, canonical);
  }
  assert.equal(existsSync(path.join(backendRoot, 'src/outbox/outbox.module.ts')), false);
  assert.equal(existsSync(path.join(backendRoot, 'src/platform/outbox/outbox.module.ts')), false);
  assert.equal(existsSync(path.join(backendRoot, 'src/platform/outbox/outbox-core.module.ts')), true);
  assert.equal(existsSync(path.join(backendRoot, 'src/application-composition/application-outbox-runtime.module.ts')), true);
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
  const coreModuleSource = source('src/platform/outbox/outbox-core.module.ts');
  const runtimeModuleSource = source('src/application-composition/application-outbox-runtime.module.ts');
  assert.match(worker, /const\s+maxAttempts\s*=\s*8\s*;/);
  assert.match(worker, /@Interval\(1_000\)/);
  assert.match(cleanup, /const\s+CLEANUP_INTERVAL_MS\s*=\s*6\s*\*\s*60\s*\*\s*60\s*\*\s*1_000\s*;/);
  assert.match(cleanup, /const\s+PROCESSED_RETENTION_MS\s*=\s*7\s*\*\s*24\s*\*\s*60\s*\*\s*60\s*\*\s*1_000\s*;/);
  assert.match(coreModuleSource, /providers:\s*\[OutboxService, OutboxCleanupScheduler\]/);
  assert.match(coreModuleSource, /exports:\s*\[OutboxService\]/);
  assert.match(runtimeModuleSource, /OutboxDispatcher,\s*\n\s*OutboxWorker,/);
});

test('R1 Task 3 source tests and smokes have no stale idempotency or outbox paths', () => {
  const roots = [
    path.join(backendRoot, 'src'),
    path.join(backendRoot, 'test'),
    path.join(backendRoot, 'scripts', 'smoke'),
  ];
  const negativeArchitectureFixtures = new Set([
    'architecture-r1-baseline-relocation.test.ts',
    'architecture-ports.test.ts',
  ]);
  const stale = roots.flatMap(sourceCodeFiles)
    .filter((file) => file !== __filename)
    .filter((file) => !negativeArchitectureFixtures.has(path.basename(file)))
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
  const identitySource = source('src/modules/identity/internal/auth/otp-channel.ts');
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
  for (const file of sourceCodeFiles(transportRoot)) {
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
  const { generateProductionOtpCode } = require('../src/modules/identity/internal/auth/otp-channel') as {
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

test('R1 OTP ownership remains intact while sharing consumes the R6 Identity transport port', () => {
  const authServiceSource = source('src/modules/identity/internal/auth/auth.service.ts');
  assert.match(authServiceSource, /from\s+['"]\.\/otp-channel['"]/);
  assert.match(
    authServiceSource,
    /from\s+['"]\.\.\/\.\.\/\.\.\/\.\.\/platform\/otp-transport\/(?:otp-delivery|openwa-otp\.channel|whatsapp-otp\.channel)['"]/,
  );
  assert.match(authServiceSource, /generateProductionOtpCode/);
  assert.match(authServiceSource, /resolveOtpChannel\s*\(/);

  const sharingSource = source('src/modules/collaboration/internal/invitation-delivery.service.ts');
  assert.match(
    sharingSource,
    /from\s+['"]\.\.\/\.\.\/identity\/public\/identity-transient-delivery\.port['"]/,
  );
  assert.match(sharingSource, /@Inject\(IDENTITY_TRANSIENT_DELIVERY_PORT\)/);
  assert.match(
    sharingSource,
    /private readonly transientDelivery:\s*IdentityTransientDeliveryPort/,
  );
  assert.match(sharingSource, /this\.transientDelivery\.send\s*\(/);
  assert.doesNotMatch(sharingSource, /platform\/otp-transport\/openwa-transient-text/);
  assert.doesNotMatch(sharingSource, /auth\/openwa-transient-text/);
});

test('R1 Task 5 shared kernel and backoffice domain exist only at canonical paths', () => {
  const moved = [
    ['src/common/validation/money.ts', 'src/shared-kernel/money/money.ts'],
    ['src/common/phone/phone-normalizer.ts', 'src/shared-kernel/phone/phone-normalizer.ts'],
    ['src/common/privacy/review-identity.ts', 'src/shared-kernel/privacy/review-identity.ts'],
    ['src/users/application-user-identity.ts', 'src/shared-kernel/privacy/application-user-identity.ts'],
    ['src/common/time/business-day.ts', 'src/shared-kernel/time/business-day.ts'],
    ['src/common/admin/admin-permissions.ts', 'src/modules/backoffice/domain/admin-permissions.ts'],
  ];
  for (const [legacy, canonical] of moved) {
    assert.equal(existsSync(path.join(backendRoot, legacy)), false, legacy);
    assert.equal(existsSync(path.join(backendRoot, canonical)), true, canonical);
  }
  // The admin notification privacy mapper moved to the shared kernel in R1
  // and was deleted with the desk's notification routes it served (D56, B4):
  // neither path may come back.
  for (const gone of ['src/admin/admin-privacy.ts', 'src/shared-kernel/privacy/admin-notification-privacy.ts']) {
    assert.equal(existsSync(path.join(backendRoot, gone)), false, gone);
  }
  assert.equal(existsSync(path.join(backendRoot, 'src/common')), false, 'src/common directory');
});

test('R1 Task 5 shared kernel imports neither platform nor business or module code', () => {
  const registry = JSON.parse(source('architecture/ownership-registry.json')) as {
    currentRoots: Record<string, string[]>;
  };
  const forbiddenRoots = [
    'platform',
    'modules',
    ...Object.entries(registry.currentRoots)
      .filter(([owner]) => owner !== 'platform')
      .flatMap(([, roots]) => roots),
  ];
  const importSpecifiers = /(?:from\s*['"]|require\(\s*['"])([^'"\n]+)/g;
  const sharedKernelRoot = path.join(backendRoot, 'src/shared-kernel');
  for (const file of sourceCodeFiles(sharedKernelRoot)) {
    const contents = readFileSync(file, 'utf8');
    const fileDirectory = path.dirname(file);
    for (const match of contents.matchAll(importSpecifiers)) {
      const specifier = match[1];
      if (!specifier.startsWith('.')) continue;
      const resolved = path.resolve(fileDirectory, specifier);
      assert.equal(
        forbiddenRoots.some((root) =>
          resolved === path.join(backendRoot, 'src', root)
          || resolved.startsWith(`${path.join(backendRoot, 'src', root)}${path.sep}`)),
        false,
        `${path.relative(backendRoot, file)} -> ${specifier}`,
      );
    }
  }
});

test('R1 Task 5 platform ownership root and Admin permission contract are exact', () => {
  const registry = JSON.parse(source('architecture/ownership-registry.json')) as {
    currentRoots: { platform: string[] };
  };
  assert.deepEqual(registry.currentRoots.platform, ['platform']);

  const permissions = require(
    '../src/modules/backoffice/domain/admin-permissions',
  ) as typeof import('../src/modules/backoffice/domain/admin-permissions');
  const expected = [
    'DASHBOARD_READ', 'REPORTS_READ', 'USERS_READ', 'USERS_WRITE',
    'PROVIDERS_READ', 'PROVIDERS_WRITE', 'SERVICES_READ', 'SERVICES_WRITE',
    'CATALOG_READ', 'CATALOG_WRITE', 'REVIEWS_READ', 'REVIEWS_WRITE',
    'CONVERSATION_REPORTS_READ', 'CONVERSATION_REPORTS_WRITE',
    // NOTIFICATIONS_READ and NOTIFICATIONS_WRITE left with the desk's
    // notification routes (D56, B4).
    'AUDIT_READ',
  ];
  assert.deepEqual(Object.values(permissions.AdminPermission), expected);

  const permissionPath = 'src/modules/backoffice/domain/admin-permissions.ts';
  const permissionSource = source(permissionPath);
  const permissionAst = ts.createSourceFile(
    permissionPath,
    permissionSource,
    ts.ScriptTarget.Latest,
    true,
    ts.ScriptKind.TS,
  );
  const imports = permissionAst.statements.filter(ts.isImportDeclaration);
  assert.equal(imports.length, 1);
  const onlyImport = imports[0];
  assert.equal((onlyImport.moduleSpecifier as ts.StringLiteral).text, '@prisma/client');
  assert.equal(onlyImport.importClause?.name, undefined);
  const bindings = onlyImport.importClause?.namedBindings;
  assert.ok(bindings && ts.isNamedImports(bindings));
  assert.deepEqual(
    bindings.elements.map((element) => ({
      imported: element.propertyName?.text ?? element.name.text,
      local: element.name.text,
    })),
    [{ imported: 'AdminRole', local: 'AdminRole' }],
  );

  const dependencyConfig = source('.dependency-cruiser.cjs');
  assert.doesNotMatch(dependencyConfig, /current-platform-no-business-contexts/);
});

test('R1 Task 5 source tests and scripts have no stale moved paths', () => {
  const roots = [
    path.join(backendRoot, 'src'),
    path.join(backendRoot, 'test'),
    path.join(backendRoot, 'scripts'),
  ];
  const excluded = new Set([
    path.normalize(path.join(backendRoot, 'test/architecture-r1-baseline-relocation.test.ts')),
    path.normalize(path.join(backendRoot, 'test/architecture-dependencies.test.ts')),
    path.normalize(path.join(backendRoot, 'test/architecture-ports.test.ts')),
    path.normalize(path.join(backendRoot, 'test/legacy-finance-removal.test.ts')),
    path.normalize(path.join(backendRoot, 'scripts/architecture/r1-baseline-relocation.cjs')),
    path.normalize(path.join(backendRoot, 'scripts/architecture/ports-scan.cjs')),
  ]);
  const stale = roots.flatMap(sourceCodeFiles)
    .filter((file) => file !== __filename && !excluded.has(path.normalize(file)))
    .filter((file) => task5StalePattern.test(readFileSync(file, 'utf8')))
    .map((file) => path.relative(backendRoot, file).replace(/\\/g, '/'))
    .sort();
  assert.deepEqual(stale, []);
});

test('R1 Task 5 stale-path gate scans every supported source-script extension', () => {
  const root = mkdtempSync(path.join(tmpdir(), 'aarast-r1-task5-stale-'));
  try {
    for (const extension of ['ts', 'js', 'cjs', 'mjs']) {
      writeFileSync(
        path.join(root, `consumer.${extension}`),
        "require('../src/common/validation/money');\n",
        'utf8',
      );
    }
    const stale = sourceCodeFiles(root)
      .filter((file) => task5StalePattern.test(readFileSync(file, 'utf8')))
      .map((file) => path.basename(file))
      .sort();
    assert.deepEqual(stale, [
      'consumer.cjs',
      'consumer.js',
      'consumer.mjs',
      'consumer.ts',
    ]);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
