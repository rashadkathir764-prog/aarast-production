import assert from 'node:assert/strict';
import {
  existsSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { afterEach, test } from 'node:test';

const backendRoot = path.resolve(__dirname, '..');
const repositoryRoot = path.resolve(backendRoot, '..');
const scopePath = path.join(backendRoot, 'scripts', 'architecture', 'r3-scope.cjs');
const baseRef = '6b06eb096aca8cc6684d365d16e05d4cd8529898';
const temporaryRoots: string[] = [];

type ScopeModule = {
  R3_BASE: string;
  ALLOWED_PATHS: readonly string[];
  assertAllowedPathsMatch(manifestPaths: unknown, scopePaths: unknown): void;
  writeAtomicJson(
    reportPath: string,
    value: unknown,
    dependencies?: Record<string, unknown>,
  ): void;
  validateR3Scope(options: Record<string, unknown>): any;
  validateScopeSnapshot(value: unknown): any;
  runCli(dependencies: Record<string, unknown>): number;
};

function scope(): ScopeModule {
  return require(scopePath) as ScopeModule;
}

afterEach(() => {
  for (const root of temporaryRoots.splice(0)) rmSync(root, { recursive: true, force: true });
});

test('R3 scope pins the immutable base and accepts only the explicit strict paths', () => {
  assert.equal(scope().R3_BASE, baseRef);
  const result = scope().validateR3Scope({ repositoryRoot, baseRef });
  assert.equal(result.ok, true);
  assert.deepEqual(result.unexpectedPaths, []);
  const preliminaryChangedPaths = [
    'backend/.dependency-cruiser-known-violations.json',
    'backend/.dependency-cruiser.cjs',
    'backend/architecture/r3-context-boundaries.json',
    'backend/package.json',
    'backend/scripts/architecture/ports-scan.cjs',
    'backend/scripts/architecture/r3-context-scan.cjs',
    'backend/scripts/architecture/r3-scope.cjs',
    'backend/scripts/smoke/phase2-sharing-permission-concurrency-smoke.ts',
    'backend/scripts/smoke/phase2-task-guest-permission-concurrency-smoke.ts',
    'backend/src/admin/admin-audit.interceptor.ts',
    'backend/src/admin/admin-mutation-executor.ts',
    'backend/src/admin/admin-mutation-gate.ts',
    'backend/src/admin/admin-permission.guard.ts',
    'backend/src/admin/admin-user-status.ts',
    'backend/src/admin/admin.controller.ts',
    'backend/src/admin/admin.guard.ts',
    'backend/src/admin/admin.module.ts',
    'backend/src/admin/admin.service.ts',
    'backend/src/app.module.ts',
    'backend/src/application-composition/application-outbox-runtime.module.ts',
    'backend/src/auth/access-token-scope.ts',
    'backend/src/auth/auth.controller.ts',
    'backend/src/auth/auth.module.ts',
    'backend/src/auth/auth.service.ts',
    'backend/src/auth/authenticated-user.interface.ts',
    'backend/src/auth/current-user.decorator.ts',
    'backend/src/auth/jwt-auth.guard.ts',
    'backend/src/auth/jwt-payload.interface.ts',
    'backend/src/auth/jwt.strategy.ts',
    'backend/src/auth/safe-user.ts',
    'backend/src/budget-categories/budget-categories.controller.ts',
    'backend/src/budget-categories/budget-categories.module.ts',
    'backend/src/budget-categories/budget-categories.service.ts',
    'backend/src/catalogs/administrative-catalog.service.ts',
    'backend/src/catalogs/catalogs.controller.ts',
    'backend/src/catalogs/catalogs.module.ts',
    'backend/src/catalogs/reference-catalog.service.ts',
    'backend/src/contexts/contexts.controller.ts',
    'backend/src/contexts/contexts.module.ts',
    'backend/src/contexts/contexts.service.ts',
    'backend/src/contribution-history/contribution-history.contracts.ts',
    'backend/src/contribution-history/contribution-history.controller.ts',
    'backend/src/contribution-history/contribution-history.module.ts',
    'backend/src/contribution-history/contribution-history.service.ts',
    'backend/src/contribution-history/contributor-scope.service.ts',
    'backend/src/conversations/conversation-realtime.publisher.ts',
    'backend/src/conversations/conversations.controller.ts',
    'backend/src/conversations/conversations.gateway.ts',
    'backend/src/conversations/conversations.module.ts',
    'backend/src/conversations/conversations.service.ts',
    'backend/src/dashboard/dashboard-contributor-scope.ts',
    'backend/src/dashboard/dashboard.contracts.ts',
    'backend/src/dashboard/dashboard.controller.ts',
    'backend/src/dashboard/dashboard.module.ts',
    'backend/src/dashboard/dashboard.service.ts',
    'backend/src/guests/guests.controller.ts',
    'backend/src/guests/guests.module.ts',
    'backend/src/guests/guests.service.ts',
    'backend/src/main.ts',
    'backend/src/marketplace/marketplace-contributor-quote-scope.ts',
    'backend/src/marketplace/marketplace-write-locks.ts',
    'backend/src/marketplace/marketplace.controller.ts',
    'backend/src/marketplace/marketplace.module.ts',
    'backend/src/marketplace/marketplace.service.ts',
    'backend/src/marketplace/quote-notifications.ts',
    'backend/src/marketplace/quote-offer-acceptance.ts',
    'backend/src/marketplace/quote-offer-rejection.ts',
    'backend/src/marketplace/quote-request-cancellation.ts',
    'backend/src/marketplace/quote-request-creation.ts',
    'backend/src/me/me.controller.ts',
    'backend/src/me/me.module.ts',
    'backend/src/media/dto/verify-media-upload.dto.ts',
    'backend/src/media/media-storage.service.ts',
    'backend/src/media/media-upload-policy.ts',
    'backend/src/media/media-upload-ticket.service.ts',
    'backend/src/media/media.controller.ts',
    'backend/src/media/media.module.ts',
    'backend/src/modules/backoffice/backoffice.module.ts',
    'backend/src/modules/backoffice/internal/backoffice-services.internal.module.ts',
    'backend/src/modules/catalog/catalog.module.ts',
    'backend/src/modules/catalog/internal/catalog-services.internal.module.ts',
    'backend/src/modules/collaboration/collaboration.module.ts',
    'backend/src/modules/collaboration/internal/collaboration-history.internal.module.ts',
    'backend/src/modules/collaboration/internal/collaboration-permission.internal.module.ts',
    'backend/src/modules/collaboration/internal/collaboration-scope.internal.module.ts',
    'backend/src/modules/collaboration/internal/collaboration-services.internal.module.ts',
    'backend/src/modules/collaboration/public/collaboration-history-public.module.ts',
    'backend/src/modules/collaboration/public/collaboration-history.port.ts',
    'backend/src/modules/collaboration/public/collaboration-permission-public.module.ts',
    'backend/src/modules/collaboration/public/collaboration-permission.port.ts',
    'backend/src/modules/collaboration/public/collaboration-scope-public.module.ts',
    'backend/src/modules/collaboration/public/collaboration-scope.port.ts',
    'backend/src/modules/finance/finance.module.ts',
    'backend/src/modules/finance/internal/finance-services.internal.module.ts',
    'backend/src/modules/guests/guests.module.ts',
    'backend/src/modules/guests/internal/guests-service.internal.module.ts',
    'backend/src/modules/identity/identity.module.ts',
    'backend/src/modules/identity/internal/identity-auth.internal.module.ts',
    'backend/src/modules/identity/internal/identity-profile.internal.module.ts',
    'backend/src/modules/identity/public/identity-auth-public.module.ts',
    'backend/src/modules/identity/public/identity-auth.port.ts',
    'backend/src/modules/identity/public/identity-session.types.ts',
    'backend/src/modules/insights/insights.module.ts',
    'backend/src/modules/insights/internal/insights-services.internal.module.ts',
    'backend/src/modules/marketplace/internal/marketplace-services.internal.module.ts',
    'backend/src/modules/marketplace/marketplace.module.ts',
    'backend/src/modules/media/internal/media-lifecycle.internal.module.ts',
    'backend/src/modules/media/internal/media-storage.internal.module.ts',
    'backend/src/modules/media/media.module.ts',
    'backend/src/modules/media/public/media-storage-public.module.ts',
    'backend/src/modules/media/public/media-storage.port.ts',
    'backend/src/modules/messaging/internal/messaging-conversations.internal.module.ts',
    'backend/src/modules/messaging/internal/messaging-realtime.implementation-token.ts',
    'backend/src/modules/messaging/internal/messaging-realtime.internal.module.ts',
    'backend/src/modules/messaging/messaging.module.ts',
    'backend/src/modules/messaging/public/messaging-realtime-public.module.ts',
    'backend/src/modules/messaging/public/messaging-realtime.port.ts',
    'backend/src/modules/notifications/internal/notifications-lifecycle.internal.module.ts',
    'backend/src/modules/notifications/internal/notifications-service.internal.module.ts',
    'backend/src/modules/notifications/internal/push-installations.internal.module.ts',
    'backend/src/modules/notifications/internal/push-transport.internal.module.ts',
    'backend/src/modules/notifications/notifications.module.ts',
    'backend/src/modules/notifications/public/notifications-public.module.ts',
    'backend/src/modules/notifications/public/notifications.port.ts',
    'backend/src/modules/notifications/public/push-capability-public.module.ts',
    'backend/src/modules/notifications/public/push-capability.port.ts',
    'backend/src/modules/notifications/public/push-delivery-public.module.ts',
    'backend/src/modules/notifications/public/push-delivery.port.ts',
    'backend/src/modules/planning/internal/planning-services.internal.module.ts',
    'backend/src/modules/planning/planning.module.ts',
    'backend/src/modules/tasks/internal/tasks-service.internal.module.ts',
    'backend/src/modules/tasks/tasks.module.ts',
    'backend/src/money/money-budget.service.ts',
    'backend/src/money/money-summary.controller.ts',
    'backend/src/money/money-summary.service.ts',
    'backend/src/money/money.module.ts',
    'backend/src/notifications/notifications.controller.ts',
    'backend/src/notifications/notifications.module.ts',
    'backend/src/notifications/notifications.service.ts',
    'backend/src/onboarding/onboarding.controller.ts',
    'backend/src/onboarding/onboarding.module.ts',
    'backend/src/onboarding/onboarding.service.ts',
    'backend/src/platform/config/runtime-environment.ts',
    'backend/src/platform/health/media-readiness.port.ts',
    'backend/src/platform/health/readiness.service.ts',
    'backend/src/platform/outbox/outbox-core.module.ts',
    'backend/src/platform/outbox/outbox.dispatcher.ts',
    'backend/src/platform/outbox/outbox.module.ts',
    'backend/src/platform/outbox/outbox.ports.ts',
    'backend/src/provider-dashboard/provider-dashboard.controller.ts',
    'backend/src/provider-dashboard/provider-dashboard.module.ts',
    'backend/src/provider-dashboard/provider-dashboard.service.ts',
    'backend/src/push/firebase-push.client.ts',
    'backend/src/push/push-delivery.service.ts',
    'backend/src/push/push-installations.service.ts',
    'backend/src/push/push.controller.ts',
    'backend/src/push/push.module.ts',
    'backend/src/sharing/invite-access.service.ts',
    'backend/src/sharing/permission.service.ts',
    'backend/src/sharing/sharing.controller.ts',
    'backend/src/sharing/sharing.module.ts',
    'backend/src/sharing/sharing.service.ts',
    'backend/src/tasks/tasks.controller.ts',
    'backend/src/tasks/tasks.module.ts',
    'backend/src/tasks/tasks.service.ts',
    'backend/src/timeline/timeline.controller.ts',
    'backend/src/timeline/timeline.module.ts',
    'backend/src/timeline/timeline.service.ts',
    'backend/src/users/users.controller.ts',
    'backend/src/users/users.module.ts',
    'backend/src/users/users.service.ts',
    'backend/src/wedding-costs/wedding-costs.controller.ts',
    'backend/src/wedding-costs/wedding-costs.module.ts',
    'backend/src/wedding-costs/wedding-costs.service.ts',
    'backend/src/wedding-plans/wedding-plans.controller.ts',
    'backend/src/wedding-plans/wedding-plans.module.ts',
    'backend/src/wedding-plans/wedding-plans.service.ts',
    'backend/test/admin-presenter.test.ts',
    'backend/test/architecture-dependencies.test.ts',
    'backend/test/architecture-ports.test.ts',
    'backend/test/architecture-r1-layout.test.ts',
    'backend/test/architecture-r3-closure.test.ts',
    'backend/test/architecture-r3-collaboration-ports.test.ts',
    'backend/test/architecture-r3-composition.test.ts',
    'backend/test/architecture-r3-context-modules-a.test.ts',
    'backend/test/architecture-r3-context-modules-b.test.ts',
    'backend/test/architecture-r3-contexts.test.ts',
    'backend/test/architecture-r3-identity-port.test.ts',
    'backend/test/architecture-r3-notifications-port.test.ts',
    'backend/test/architecture-r3-scope.test.ts',
    'backend/test/auth-otp-mode.test.ts',
    'backend/test/auth-refresh-wiring.test.ts',
    'backend/test/contexts.test.ts',
    'backend/test/dashboard-summary-presenter.test.ts',
    'backend/test/health-readiness.test.ts',
    'backend/test/legacy-finance-removal.test.ts',
    'backend/test/media-url-ownership.test.ts',
    'backend/test/notification-logic.test.ts',
    'backend/test/openwa-otp-channel.test.ts',
    'backend/test/push-notifications.test.ts',
    'backend/test/sharing-permission-ceiling.test.ts',
    'backend/test/whatsapp-otp-channel.test.ts',
    'docs/SCRIPTS.md',
    'docs/project/STATUS.md',
    'docs/superpowers/plans/2026-08-14-modular-monolith-r3-nest-boundaries.md',
    'docs/superpowers/specs/2026-08-14-modular-monolith-r3-nest-boundaries-design.md',
  ];
  const finalReceiptChangedPaths = [...new Set([
    ...preliminaryChangedPaths,
    'ARCHITECTURE.md',
    'CHANGELOG.md',
    'docs/README.md',
    'docs/project/DECISIONS.md',
    'docs/project/EXECUTION_PLAN.md',
    'docs/qa/README.md',
  ])].sort();
  assert.equal(
    [preliminaryChangedPaths, finalReceiptChangedPaths].some(
      (expected) => JSON.stringify(result.changedPaths) === JSON.stringify(expected),
    ),
    true,
    'live R3 scope must match either the exact preliminary or exact final receipt stage',
  );
  rmSync(result.reportPath, { force: true });
});

test('the scope allowlist is byte/order-exact with the canonical manifest', () => {
  const manifest = JSON.parse(readFileSync(path.join(
    backendRoot,
    'architecture',
    'r3-context-boundaries.json',
  ), 'utf8'));
  assert.deepEqual(scope().ALLOWED_PATHS, manifest.allowedChangedPaths);
  assert.doesNotThrow(() => scope().assertAllowedPathsMatch(
    manifest.allowedChangedPaths,
    scope().ALLOWED_PATHS,
  ));
  const reordered = [...manifest.allowedChangedPaths];
  [reordered[0], reordered[1]] = [reordered[1], reordered[0]];
  assert.throws(() => scope().assertAllowedPathsMatch(
    reordered,
    scope().ALLOWED_PATHS,
  ), /allowlist.*drift/i);
  assert.throws(() => scope().assertAllowedPathsMatch(
    [...manifest.allowedChangedPaths.slice(0, -1), 'docs/attacker.md'],
    scope().ALLOWED_PATHS,
  ), /allowlist.*drift/i);
});

test('Task 9 permits only the seven approved active receipt files', () => {
  const approvedReceipts = [
    'ARCHITECTURE.md',
    'docs/README.md',
    'docs/project/STATUS.md',
    'docs/project/DECISIONS.md',
    'docs/project/EXECUTION_PLAN.md',
    'docs/qa/README.md',
    'CHANGELOG.md',
  ];
  assert.deepEqual(
    scope().ALLOWED_PATHS.filter((entry: string) => approvedReceipts.includes(entry)),
    approvedReceipts,
  );
});

test('scope snapshots reject an incorrect base, unknown paths, traversal, and duplicates', () => {
  const valid = {
    baseRef,
    allowedPaths: ['backend/package.json'],
    changedPaths: ['backend/package.json'],
  };
  assert.equal(scope().validateScopeSnapshot(valid).ok, true);
  assert.throws(() => scope().validateScopeSnapshot({ ...valid, baseRef: 'HEAD' }), /base/);
  assert.throws(() => scope().validateScopeSnapshot({
    ...valid,
    changedPaths: ['backend/package.json', 'backend/src/app.module.ts'],
  }), /scope/);
  assert.throws(() => scope().validateScopeSnapshot({
    ...valid,
    changedPaths: ['../backend/package.json'],
  }), /path/);
  assert.throws(() => scope().validateScopeSnapshot({
    ...valid,
    changedPaths: ['backend/package.json', 'backend/package.json'],
  }), /duplicate/);
});

test('scope exposes a high-similarity forbidden deletion instead of collapsing it into an allowed creation', () => {
  const root = mkdtempSync(path.join(tmpdir(), 'aarast-r3-rename-regression-'));
  temporaryRoots.push(root);
  const reportPath = path.join(root, 'scope.json');
  const forbiddenSource = 'backend/src/forbidden-auth-session.ts';
  const allowedDestination = 'backend/src/app.module.ts';
  const mutableChildProcess = require('node:child_process') as any;
  const originalExecFileSync = mutableChildProcess.execFileSync;
  const calls: string[][] = [];
  delete require.cache[scopePath];
  mutableChildProcess.execFileSync = (
    executable: string,
    args: string[],
    options: Record<string, unknown>,
  ) => {
    if (executable !== 'git') return originalExecFileSync(executable, args, options);
    calls.push([...args]);
    if (args[0] === 'diff') {
      return args.includes('--no-renames')
        ? `${forbiddenSource}\n${allowedDestination}\n`
        : `${allowedDestination}\n`;
    }
    if (args[0] === 'ls-files') return '';
    throw new Error('unexpected Git command in rename regression');
  };
  try {
    const isolatedScope = require(scopePath) as ScopeModule;
    assert.throws(() => isolatedScope.validateR3Scope({
      repositoryRoot,
      baseRef,
      reportPath,
    }), /scope/);
    assert.equal(existsSync(reportPath), false);
    assert.deepEqual(calls[0], [
      'diff', '--no-renames', '--name-only', baseRef, '--',
    ]);
  } finally {
    mutableChildProcess.execFileSync = originalExecFileSync;
    delete require.cache[scopePath];
  }
});

test('scope input accepts plain dense data only', () => {
  const valid = {
    baseRef,
    allowedPaths: ['backend/package.json'],
    changedPaths: ['backend/package.json'],
  };
  assert.throws(() => scope().validateScopeSnapshot(new Proxy(valid, {})), /plain object/);
  const accessor = { ...valid } as Record<string, unknown>;
  Object.defineProperty(accessor, 'baseRef', { get: () => baseRef, enumerable: true });
  assert.throws(() => scope().validateScopeSnapshot(accessor), /accessor|data property/);
  assert.throws(() => scope().validateScopeSnapshot({
    ...valid,
    changedPaths: new Array(1),
  }), /dense/);
});

test('machine reports use a unique absolute OS-temp JSON path and reparse safely', () => {
  const root = mkdtempSync(path.join(tmpdir(), 'aarast-r3-scope-report-'));
  temporaryRoots.push(root);
  const first = path.join(root, 'first.json');
  const second = path.join(root, 'second.json');
  const resultA = scope().validateR3Scope({ repositoryRoot, baseRef, reportPath: first });
  const resultB = scope().validateR3Scope({ repositoryRoot, baseRef, reportPath: second });
  assert.equal(path.isAbsolute(resultA.reportPath), true);
  assert.equal(path.extname(resultA.reportPath), '.json');
  assert.notEqual(resultA.reportPath, resultB.reportPath);
  assert.equal(existsSync(`${first}.tmp`), false);
  assert.deepEqual(JSON.parse(readFileSync(first, 'utf8')).changedPaths, resultA.changedPaths);
});

test('I7 the default validator and real CLI both commit truthful atomic reports', () => {
  const result = scope().validateR3Scope({ repositoryRoot, baseRef });
  try {
    assert.equal(existsSync(result.reportPath), true);
    assert.deepEqual(JSON.parse(readFileSync(result.reportPath, 'utf8')).changedPaths, result.changedPaths);
    assert.equal(existsSync(`${result.reportPath}.tmp`), false);
  } finally {
    rmSync(result.reportPath, { force: true });
  }

  const root = mkdtempSync(path.join(tmpdir(), 'aarast-r3-real-cli-'));
  temporaryRoots.push(root);
  const reportPath = path.join(root, 'cli-report.json');
  const cli = path.join(backendRoot, 'scripts', 'architecture', 'r3-scope.cjs');
  const command = spawnSync(process.execPath, [
    cli,
    '--check',
    '--base-ref',
    baseRef,
    '--report-path',
    reportPath,
  ], {
    cwd: backendRoot,
    encoding: 'utf8',
  });
  assert.equal(command.status, 0, command.stderr || command.stdout);
  assert.equal(existsSync(reportPath), true);
  assert.equal(existsSync(`${reportPath}.tmp`), false);
  assert.equal(JSON.parse(readFileSync(reportPath, 'utf8')).ok, true);
});

test('I8 report confinement rejects junction or symlink escapes outside the canonical temp root', () => {
  const lexicalRoot = mkdtempSync(path.join(tmpdir(), 'aarast-r3-link-root-'));
  const outsideRoot = mkdtempSync(path.join(path.dirname(tmpdir()), 'aarast-r3-outside-'));
  temporaryRoots.push(lexicalRoot, outsideRoot);
  const link = path.join(lexicalRoot, 'redirect');
  symlinkSync(outsideRoot, link, process.platform === 'win32' ? 'junction' : 'dir');
  const reportPath = path.join(link, 'escaped.json');
  assert.throws(() => scope().validateR3Scope({
    repositoryRoot,
    baseRef,
    reportPath,
  }), /canonical|reparse|junction|symbolic|temporary/i);
  assert.equal(existsSync(path.join(outsideRoot, 'escaped.json')), false);
  assert.equal(existsSync(path.join(outsideRoot, 'escaped.json.tmp')), false);
});

test('I8 report commit rejects destination races, preserves prior output, and removes partials', () => {
  const root = mkdtempSync(path.join(tmpdir(), 'aarast-r3-race-'));
  temporaryRoots.push(root);
  const existing = path.join(root, 'existing.json');
  writeFileSync(existing, '{"preserved":true}\n', 'utf8');
  assert.throws(() => scope().writeAtomicJson(existing, { ok: true }), /exists|destination|race/i);
  assert.equal(readFileSync(existing, 'utf8'), '{"preserved":true}\n');
  assert.equal(existsSync(`${existing}.tmp`), false);

  const raced = path.join(root, 'raced.json');
  assert.throws(() => scope().writeAtomicJson(raced, { ok: true }, {
    beforeCommit: () => writeFileSync(raced, '{"racer":true}\n', 'utf8'),
  }), /exists|destination|race/i);
  assert.equal(readFileSync(raced, 'utf8'), '{"racer":true}\n');
  assert.equal(existsSync(`${raced}.tmp`), false);
});

test('I8 report publish rejects and preserves a replaced validation temporary', () => {
  const root = mkdtempSync(path.join(tmpdir(), 'aarast-r3-identity-race-'));
  temporaryRoots.push(root);
  const reportPath = path.join(root, 'report.json');
  let replacementPath = '';
  assert.throws(() => scope().writeAtomicJson(reportPath, { ok: true }, {
    beforeCommit: () => {
      const stagingName = readdirSync(root).find((name) => name.includes('.stage-'));
      if (!stagingName) throw new Error('test could not locate private staging directory');
      const stagingPath = path.join(root, stagingName);
      const temporaryName = readdirSync(stagingPath).find((name) => name.endsWith('.tmp'));
      if (!temporaryName) throw new Error('test could not locate owned temporary file');
      replacementPath = path.join(stagingPath, temporaryName);
      rmSync(replacementPath);
      writeFileSync(replacementPath, '{"racer":true}\n', 'utf8');
    },
  }), /changed|identity|race/i);
  assert.equal(existsSync(reportPath), false);
  assert.equal(existsSync(replacementPath), true);
  assert.equal(readFileSync(replacementPath, 'utf8'), '{"racer":true}\n');
});

test('I8 write, flush, and hard-link failures never publish partial output', () => {
  const root = mkdtempSync(path.join(tmpdir(), 'aarast-r3-publish-failure-'));
  temporaryRoots.push(root);
  const mutableFs = require('node:fs') as any;
  const originalWriteFileSync = mutableFs.writeFileSync;
  const originalWriteSync = mutableFs.writeSync;
  const originalFsyncSync = mutableFs.fsyncSync;
  const originalLinkSync = mutableFs.linkSync;

  const partial = path.join(root, 'partial.json');
  mutableFs.writeFileSync = (target: unknown, data: unknown, ...args: unknown[]) => {
    if (typeof target === 'number') {
      originalWriteSync(target, Buffer.from('{"partial":', 'utf8'));
      throw Object.assign(new Error('injected temporary write failure'), { code: 'EIO' });
    }
    return originalWriteFileSync(target, data, ...args);
  };
  try {
    assert.throws(() => scope().writeAtomicJson(partial, { ok: true }), /write failure/i);
  } finally {
    mutableFs.writeFileSync = originalWriteFileSync;
  }
  assert.equal(existsSync(partial), false);

  const unflushed = path.join(root, 'unflushed.json');
  mutableFs.fsyncSync = () => {
    throw Object.assign(new Error('injected fsync failure'), { code: 'EIO' });
  };
  try {
    assert.throws(() => scope().writeAtomicJson(unflushed, { ok: true }), /fsync failure/i);
  } finally {
    mutableFs.fsyncSync = originalFsyncSync;
  }
  assert.equal(existsSync(unflushed), false);

  const unsupported = path.join(root, 'unsupported.json');
  mutableFs.linkSync = () => {
    throw Object.assign(new Error('injected hard-link failure'), { code: 'ENOTSUP' });
  };
  try {
    assert.throws(() => scope().writeAtomicJson(unsupported, { ok: true }), /hard-link failure/i);
  } finally {
    mutableFs.linkSync = originalLinkSync;
  }
  assert.equal(existsSync(unsupported), false);
  assert.deepEqual(readdirSync(root), []);
});

test('invalid mixed batches do not commit a partial report', () => {
  const root = mkdtempSync(path.join(tmpdir(), 'aarast-r3-scope-invalid-'));
  temporaryRoots.push(root);
  const reportPath = path.join(root, 'invalid.json');
  assert.throws(() => scope().validateScopeSnapshot({
    baseRef,
    allowedPaths: ['backend/package.json'],
    changedPaths: ['backend/package.json', 'backend/src/app.module.ts'],
    reportPath,
  }), /scope/);
  assert.equal(existsSync(reportPath), false);
});

test('the scope CLI returns one fixed failure line with exit 2', () => {
  const output: string[] = [];
  const code = scope().runCli({
    argv: ['--check', '--base-ref', baseRef],
    validate: () => { throw new Error('C:\\private\\TOKEN=secret\nstack'); },
    stdout: (message: string) => output.push(message),
    stderr: (message: string) => output.push(message),
  });
  assert.equal(code, 2);
  assert.deepEqual(output, ['ERROR - R3 scope validation failed']);
});
