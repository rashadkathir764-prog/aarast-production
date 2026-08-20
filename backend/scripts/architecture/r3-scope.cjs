'use strict';

const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const { execFileSync } = require('node:child_process');
const { types: utilTypes } = require('node:util');
const {
  R5_BASE,
  validateR5Manifest,
} = require('./r5-identity-scan.cjs');

const R3_BASE = '6b06eb096aca8cc6684d365d16e05d4cd8529898';
const R4_BASE = '502b181a2ce624458fd7eae064f194497ec0151e';
const R4_MANIFEST_PATH = 'backend/architecture/r4-planning-finance-boundary.json';
const R5_MANIFEST_PATH = 'backend/architecture/r5-identity-relocation.json';
const R4_ALLOWED_PATHS = Object.freeze([
  'ARCHITECTURE.md',
  'CHANGELOG.md',
  'backend/architecture/ownership-baseline.json',
  'backend/architecture/r3-context-boundaries.json',
  'backend/architecture/r4-planning-finance-boundary.json',
  'backend/package.json',
  'backend/scripts/architecture/r3-context-scan.cjs',
  'backend/scripts/architecture/r3-scope.cjs',
  'backend/scripts/smoke/phase2-money-authorization-concurrency-smoke.ts',
  'backend/src/modules/finance/internal/finance-services.internal.module.ts',
  'backend/src/modules/planning/internal/planning-budget-write.internal.module.ts',
  'backend/src/modules/planning/internal/wedding-plan-budget-writer.ts',
  'backend/src/modules/planning/planning.module.ts',
  'backend/src/modules/planning/public/planning-budget-write-public.module.ts',
  'backend/src/modules/planning/public/planning-budget-write.port.ts',
  'backend/src/money/money-budget.service.ts',
  'backend/test/architecture-r3-context-modules-a.test.ts',
  'backend/test/architecture-r3-contexts.test.ts',
  'backend/test/architecture-r3-scope.test.ts',
  'backend/test/architecture-r4-planning-finance-boundary.test.ts',
  'backend/test/financial-integrity.test.ts',
  'docs/README.md',
  'docs/SCRIPTS.md',
  'docs/backend/README.md',
  'docs/project/DECISIONS.md',
  'docs/project/EXECUTION_PLAN.md',
  'docs/project/STATUS.md',
  'docs/qa/README.md',
  'docs/superpowers/plans/2026-08-16-modular-monolith-r4-planning-finance-ownership.md',
  'docs/superpowers/specs/2026-08-16-modular-monolith-r4-planning-finance-ownership-design.md',
]);
const ALLOWED_PATHS = Object.freeze([
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
  'backend/src/modules/collaboration/internal/collaboration-history.internal.module.ts',
  'backend/src/modules/collaboration/internal/collaboration-permission.internal.module.ts',
  'backend/src/modules/collaboration/internal/collaboration-scope.internal.module.ts',
  'backend/src/modules/collaboration/internal/collaboration-services.internal.module.ts',
  'backend/src/modules/collaboration/collaboration.module.ts',
  'backend/src/modules/collaboration/public/collaboration-history-public.module.ts',
  'backend/src/modules/collaboration/public/collaboration-history.port.ts',
  'backend/src/modules/collaboration/public/collaboration-permission-public.module.ts',
  'backend/src/modules/collaboration/public/collaboration-permission.port.ts',
  'backend/src/modules/collaboration/public/collaboration-scope-public.module.ts',
  'backend/src/modules/collaboration/public/collaboration-scope.port.ts',
  'backend/src/modules/identity/internal/identity-auth.internal.module.ts',
  'backend/src/modules/identity/internal/identity-profile.internal.module.ts',
  'backend/src/modules/identity/identity.module.ts',
  'backend/src/modules/identity/public/identity-auth-public.module.ts',
  'backend/src/modules/identity/public/identity-auth.port.ts',
  'backend/src/modules/identity/public/identity-session.types.ts',
  'backend/src/modules/media/internal/media-lifecycle.internal.module.ts',
  'backend/src/modules/media/internal/media-storage.internal.module.ts',
  'backend/src/modules/media/public/media-storage-public.module.ts',
  'backend/src/modules/media/public/media-storage.port.ts',
  'backend/src/modules/messaging/internal/messaging-realtime.implementation-token.ts',
  'backend/src/modules/messaging/internal/messaging-realtime.internal.module.ts',
  'backend/src/modules/messaging/public/messaging-realtime-public.module.ts',
  'backend/src/modules/messaging/public/messaging-realtime.port.ts',
  'backend/src/modules/notifications/internal/notifications-service.internal.module.ts',
  'backend/src/modules/notifications/internal/push-transport.internal.module.ts',
  'backend/src/modules/notifications/public/notifications-public.module.ts',
  'backend/src/modules/notifications/public/notifications.port.ts',
  'backend/src/modules/notifications/public/push-capability-public.module.ts',
  'backend/src/modules/notifications/public/push-capability.port.ts',
  'backend/src/modules/notifications/public/push-delivery-public.module.ts',
  'backend/src/modules/notifications/public/push-delivery.port.ts',
  'backend/src/modules/finance/finance.module.ts',
  'backend/src/modules/finance/internal/finance-services.internal.module.ts',
  'backend/src/modules/guests/guests.module.ts',
  'backend/src/modules/guests/internal/guests-service.internal.module.ts',
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
  'backend/test/architecture-dependencies.test.ts',
  'backend/test/architecture-ports.test.ts',
  'backend/test/architecture-r1-layout.test.ts',
  'backend/test/architecture-r3-collaboration-ports.test.ts',
  'backend/test/architecture-r3-composition.test.ts',
  'backend/test/architecture-r3-context-modules-a.test.ts',
  'backend/test/architecture-r3-contexts.test.ts',
  'backend/test/architecture-r3-identity-port.test.ts',
  'backend/test/architecture-r3-notifications-port.test.ts',
  'backend/test/architecture-r3-scope.test.ts',
  'backend/test/auth-otp-mode.test.ts',
  'backend/test/auth-refresh-wiring.test.ts',
  'backend/test/contexts.test.ts',
  'backend/test/health-readiness.test.ts',
  'backend/test/legacy-finance-removal.test.ts',
  'backend/test/media-url-ownership.test.ts',
  'backend/test/notification-logic.test.ts',
  'backend/test/openwa-otp-channel.test.ts',
  'backend/test/push-notifications.test.ts',
  'backend/test/sharing-permission-ceiling.test.ts',
  'backend/test/whatsapp-otp-channel.test.ts',
  'docs/SCRIPTS.md',
  'backend/src/catalogs/catalogs.module.ts',
  'backend/src/modules/backoffice/backoffice.module.ts',
  'backend/src/modules/backoffice/internal/backoffice-services.internal.module.ts',
  'backend/src/modules/catalog/catalog.module.ts',
  'backend/src/modules/catalog/internal/catalog-services.internal.module.ts',
  'backend/src/modules/insights/insights.module.ts',
  'backend/src/modules/insights/internal/insights-services.internal.module.ts',
  'backend/src/modules/marketplace/internal/marketplace-services.internal.module.ts',
  'backend/src/modules/marketplace/marketplace.module.ts',
  'backend/src/modules/media/media.module.ts',
  'backend/test/architecture-r3-context-modules-b.test.ts',
  'backend/test/admin-presenter.test.ts',
  'backend/test/dashboard-summary-presenter.test.ts',
  'backend/src/modules/messaging/internal/messaging-conversations.internal.module.ts',
  'backend/src/modules/messaging/messaging.module.ts',
  'backend/src/modules/notifications/internal/notifications-lifecycle.internal.module.ts',
  'backend/src/modules/notifications/internal/push-installations.internal.module.ts',
  'backend/src/modules/notifications/notifications.module.ts',
  'backend/test/architecture-r3-closure.test.ts',
  'docs/superpowers/plans/2026-08-14-modular-monolith-r3-nest-boundaries.md',
  'docs/superpowers/specs/2026-08-14-modular-monolith-r3-nest-boundaries-design.md',
  'mobile/lib/core/network/api_client.dart',
  'mobile/test/core/network/api_client_refresh_test.dart',
  'ARCHITECTURE.md',
  'docs/README.md',
  'docs/project/STATUS.md',
  'docs/project/DECISIONS.md',
  'docs/project/EXECUTION_PLAN.md',
  'docs/qa/README.md',
  'CHANGELOG.md',
]);
const R5_ALLOWED_PATHS = Object.freeze([
  ...validateR5Manifest(JSON.parse(fs.readFileSync(path.join(
    __dirname,
    '..',
    '..',
    'architecture',
    'r5-identity-relocation.json',
  ), 'utf8'))).allowedChangedPaths,
]);

function assertPlainObject(value, label) {
  if (!value || typeof value !== 'object' || Array.isArray(value) || !utilTypes.isProxy(value)) {
    if (value && typeof value === 'object' && !Array.isArray(value) && !utilTypes.isProxy(value)
      && Object.getPrototypeOf(value) === Object.prototype) {
      for (const key of Object.keys(value)) {
        const descriptor = Object.getOwnPropertyDescriptor(value, key);
        if (!descriptor || !Object.prototype.hasOwnProperty.call(descriptor, 'value')) {
          throw new Error(`${label} must contain data properties only; accessor found`);
        }
      }
      return value;
    }
    throw new Error(`${label} must be a plain object`);
  }
  throw new Error(`${label} must be a plain object`);
}

function validatePathList(value, label) {
  if (!Array.isArray(value)) throw new Error(`${label} must be an array`);
  for (let index = 0; index < value.length; index += 1) {
    if (!Object.prototype.hasOwnProperty.call(value, index)) throw new Error(`${label} must be dense`);
    const item = value[index];
    if (typeof item !== 'string' || !item || item.includes('\\') || path.posix.isAbsolute(item)
      || item.split('/').includes('..') || item.split('/').includes('.')) {
      throw new Error(`${label} contains an invalid path`);
    }
  }
  if (new Set(value).size !== value.length) throw new Error(`${label} contains a duplicate path`);
  return [...value];
}

function assertAllowedPathsMatch(manifestPaths, scopePaths) {
  const manifestAllowlist = validatePathList(manifestPaths, 'manifest allowlist');
  const scopeAllowlist = validatePathList(scopePaths, 'scope allowlist');
  if (JSON.stringify(manifestAllowlist) !== JSON.stringify(scopeAllowlist)) {
    throw new Error('R3 allowlist drift detected');
  }
}

function validateR4DelegationManifest(value) {
  assertPlainData(value, 'R4 delegation manifest');
  const manifest = assertPlainObject(value, 'R4 delegation manifest');
  if (manifest.schemaVersion !== 1 || manifest.baseRevision !== R4_BASE) {
    throw new Error('R4 delegation manifest identity is invalid');
  }
  if (!['baseline', 'strict', 'complete'].includes(manifest.stage)) {
    throw new Error('R4 delegation manifest stage is invalid');
  }
  const allowedChangedPaths = validatePathList(
    manifest.allowedChangedPaths,
    'R4 delegated paths',
  );
  if (JSON.stringify(allowedChangedPaths) !== JSON.stringify([...allowedChangedPaths].sort())) {
    throw new Error('R4 delegated paths must be sorted');
  }
  assertAllowedPathsMatch(allowedChangedPaths, R4_ALLOWED_PATHS);
  for (const requiredPath of [
    R4_MANIFEST_PATH,
    'backend/scripts/architecture/r3-scope.cjs',
    'backend/test/architecture-r3-scope.test.ts',
    'backend/test/architecture-r4-planning-finance-boundary.test.ts',
  ]) {
    if (!allowedChangedPaths.includes(requiredPath)) {
      throw new Error('R4 delegation manifest is missing a required handoff path');
    }
  }
  return Object.freeze({
    baseRevision: manifest.baseRevision,
    stage: manifest.stage,
    allowedChangedPaths: Object.freeze(allowedChangedPaths),
  });
}

function validateR5IdentityManifest(value) {
  const manifest = validateR5Manifest(value);
  if (manifest.baseRevision !== R5_BASE) {
    throw new Error('R5 identity manifest identity is invalid');
  }
  assertAllowedPathsMatch(manifest.allowedChangedPaths, R5_ALLOWED_PATHS);
  for (const requiredPath of [
    R5_MANIFEST_PATH,
    'backend/scripts/architecture/r3-scope.cjs',
    'backend/scripts/architecture/r5-identity-scan.cjs',
    'backend/test/architecture-r3-scope.test.ts',
    'backend/test/architecture-r5-identity-relocation.test.ts',
  ]) {
    if (!manifest.allowedChangedPaths.includes(requiredPath)) {
      throw new Error('R5 identity manifest is missing a required handoff path');
    }
  }
  return Object.freeze({
    baseRevision: manifest.baseRevision,
    stage: manifest.stage,
    allowedChangedPaths: Object.freeze([...manifest.allowedChangedPaths]),
  });
}

function validateScopeSnapshot(value) {
  const snapshot = assertPlainObject(value, 'scope snapshot');
  if (snapshot.baseRef !== R3_BASE) throw new Error('scope base does not equal immutable R3 base');
  const allowedPaths = validatePathList(snapshot.allowedPaths, 'allowed paths');
  const changedPaths = validatePathList(snapshot.changedPaths, 'changed paths');
  const allowed = new Set(allowedPaths);
  const unexpectedPaths = changedPaths.filter((item) => !allowed.has(item));
  if (unexpectedPaths.length > 0) throw new Error('changed path is outside R3 scope');
  return Object.freeze({
    baseRef: snapshot.baseRef,
    allowedPaths: Object.freeze(allowedPaths),
    changedPaths: Object.freeze(changedPaths),
    unexpectedPaths: Object.freeze([]),
    ok: true,
  });
}

function gitLines(repositoryRoot, args) {
  const text = execFileSync('git', args, { cwd: repositoryRoot, encoding: 'utf8' });
  return text.split(/\r?\n/u).map((item) => item.trim()).filter(Boolean);
}

function isInside(parent, candidate) {
  const relative = path.relative(parent, candidate);
  return relative === '' || (!path.isAbsolute(relative) && relative !== '..' && !relative.startsWith(`..${path.sep}`));
}

function assertPlainData(value, label, seen = new Set(), depth = 0) {
  if (value === null || typeof value === 'string' || typeof value === 'boolean'
      || (typeof value === 'number' && Number.isFinite(value))) return;
  if (!value || typeof value !== 'object' || utilTypes.isProxy(value) || depth > 32 || seen.has(value)) {
    throw new Error(`${label} must be bounded plain data`);
  }
  seen.add(value);
  if (Array.isArray(value)) {
    if (value.length > 10000) throw new Error(`${label} is oversized`);
    for (let index = 0; index < value.length; index += 1) {
      if (!Object.prototype.hasOwnProperty.call(value, index)) throw new Error(`${label} must be dense`);
      assertPlainData(value[index], `${label}[${index}]`, seen, depth + 1);
    }
  } else {
    if (Object.getPrototypeOf(value) !== Object.prototype) throw new Error(`${label} must be plain data`);
    const keys = Object.keys(value);
    if (keys.length > 10000) throw new Error(`${label} is oversized`);
    for (const key of keys) {
      const descriptor = Object.getOwnPropertyDescriptor(value, key);
      if (!descriptor || !Object.prototype.hasOwnProperty.call(descriptor, 'value')) {
        throw new Error(`${label} must contain data properties only`);
      }
      assertPlainData(descriptor.value, `${label}.${key}`, seen, depth + 1);
    }
  }
  seen.delete(value);
}

function canonicalReportParent(reportPath, expectedParent = null) {
  const realpath = fs.realpathSync.native || fs.realpathSync;
  const canonicalTemp = realpath(os.tmpdir());
  const parent = path.dirname(reportPath);
  const relative = path.relative(canonicalTemp, parent);
  if (!isInside(canonicalTemp, parent)) {
    throw new Error('scope report path must be inside the canonical OS temporary directory');
  }
  let cursor = canonicalTemp;
  for (const segment of relative.split(path.sep).filter(Boolean)) {
    cursor = path.join(cursor, segment);
    const status = fs.lstatSync(cursor);
    if (status.isSymbolicLink()) throw new Error('scope report path contains a symbolic link or junction');
    if (!status.isDirectory()) throw new Error('scope report parent is not a directory');
    const canonicalCursor = realpath(cursor);
    if (!isInside(canonicalTemp, canonicalCursor) || path.relative(cursor, canonicalCursor) !== '') {
      throw new Error('scope report path contains a reparse redirect');
    }
  }
  const canonicalParent = realpath(parent);
  if (!isInside(canonicalTemp, canonicalParent) || path.relative(parent, canonicalParent) !== '') {
    throw new Error('scope report parent is not canonical');
  }
  if (expectedParent !== null && canonicalParent !== expectedParent) {
    throw new Error('scope report parent changed before commit');
  }
  return canonicalParent;
}

function writeAtomicJson(reportPath, result, dependencies = {}) {
  if (typeof reportPath !== 'string' || !path.isAbsolute(reportPath)
      || path.normalize(reportPath) !== reportPath || path.extname(reportPath).toLowerCase() !== '.json') {
    throw new Error('scope report path must be an absolute JSON path');
  }
  assertPlainData(result, 'scope report');
  const hooks = assertPlainObject(dependencies, 'scope report dependencies');
  if (hooks.beforeCommit !== undefined && typeof hooks.beforeCommit !== 'function') {
    throw new Error('scope report beforeCommit hook is invalid');
  }
  const canonicalParent = canonicalReportParent(reportPath);
  if (fs.existsSync(reportPath)) throw new Error('scope report destination already exists');
  let stagingDirectory;
  let stagingIdentity;
  let canonicalStagingDirectory;
  let temporaryPath;
  let descriptor;
  let ownedIdentity;
  let published = false;
  const identityOf = (status) => `${status.dev}:${status.ino}`;
  const removeOwnedTemporary = () => {
    if (!ownedIdentity || !temporaryPath) return;
    try {
      const status = fs.lstatSync(temporaryPath, { bigint: true });
      if (identityOf(status) === ownedIdentity) fs.unlinkSync(temporaryPath);
    } catch (error) {
      if (!error || error.code !== 'ENOENT') throw error;
    }
  };
  const removeOwnedStagingDirectory = () => {
    if (!stagingDirectory || !stagingIdentity) return;
    try {
      const status = fs.lstatSync(stagingDirectory, { bigint: true });
      if (identityOf(status) !== stagingIdentity || !status.isDirectory()
          || status.isSymbolicLink() || fs.readdirSync(stagingDirectory).length !== 0) return;
      fs.rmdirSync(stagingDirectory);
    } catch (error) {
      if (!error || !['ENOENT', 'ENOTEMPTY', 'EEXIST'].includes(error.code)) throw error;
    }
  };
  try {
    const payload = `${JSON.stringify(result, null, 2)}\n`;
    stagingDirectory = fs.mkdtempSync(path.join(
      path.dirname(reportPath), `.${path.basename(reportPath)}.${process.pid}.stage-`,
    ));
    fs.chmodSync(stagingDirectory, 0o700);
    const openedStagingStatus = fs.lstatSync(stagingDirectory, { bigint: true });
    if (!openedStagingStatus.isDirectory() || openedStagingStatus.isSymbolicLink()) {
      throw new Error('scope report staging directory is invalid');
    }
    stagingIdentity = identityOf(openedStagingStatus);
    temporaryPath = path.join(
      stagingDirectory, `${crypto.randomBytes(16).toString('hex')}.tmp`,
    );
    canonicalStagingDirectory = canonicalReportParent(temporaryPath);
    if (path.dirname(canonicalStagingDirectory) !== canonicalParent
        || path.relative(stagingDirectory, canonicalStagingDirectory) !== '') {
      throw new Error('scope report staging directory escaped its canonical parent');
    }
    descriptor = fs.openSync(temporaryPath, 'wx+', 0o600);
    const openedStatus = fs.fstatSync(descriptor, { bigint: true });
    if (!openedStatus.isFile()) throw new Error('scope report temporary identity is invalid');
    ownedIdentity = identityOf(openedStatus);
    fs.writeFileSync(descriptor, payload, 'utf8');
    fs.fsyncSync(descriptor);
    const writtenStatus = fs.fstatSync(descriptor, { bigint: true });
    const payloadBytes = Buffer.byteLength(payload, 'utf8');
    if (identityOf(writtenStatus) !== ownedIdentity || writtenStatus.size !== BigInt(payloadBytes)) {
      throw new Error('scope report temporary identity changed while writing');
    }
    const payloadBuffer = Buffer.alloc(payloadBytes);
    let offset = 0;
    while (offset < payloadBuffer.length) {
      const bytesRead = fs.readSync(
        descriptor,
        payloadBuffer,
        offset,
        payloadBuffer.length - offset,
        offset,
      );
      if (bytesRead === 0) throw new Error('scope report descriptor read was incomplete');
      offset += bytesRead;
    }
    const reparsed = JSON.parse(payloadBuffer.toString('utf8'));
    if (`${JSON.stringify(reparsed, null, 2)}\n` !== payload) throw new Error('scope report reparse mismatch');
    if (hooks.beforeCommit) hooks.beforeCommit();
    canonicalReportParent(reportPath, canonicalParent);
    canonicalReportParent(temporaryPath, canonicalStagingDirectory);
    if (fs.existsSync(reportPath)) throw new Error('scope report destination race detected');
    const currentStagingStatus = fs.lstatSync(stagingDirectory, { bigint: true });
    const temporaryStatus = fs.lstatSync(temporaryPath, { bigint: true });
    if (!currentStagingStatus.isDirectory() || currentStagingStatus.isSymbolicLink()
        || identityOf(currentStagingStatus) !== stagingIdentity
        || !temporaryStatus.isFile() || temporaryStatus.isSymbolicLink()
        || identityOf(temporaryStatus) !== ownedIdentity) {
      throw new Error('scope report staging identity changed before commit');
    }
    // Within the documented local-tool threat model, this is the one atomic no-clobber
    // namespace commit. The complete payload was flushed and reparsed before this point.
    fs.linkSync(temporaryPath, reportPath);
    published = true;
  } finally {
    if (descriptor !== undefined) fs.closeSync(descriptor);
    removeOwnedTemporary();
    removeOwnedStagingDirectory();
  }
  if (!published) throw new Error('scope report was not published');
}

function validateR3Scope(options) {
  const input = assertPlainObject(options, 'scope options');
  if (input.baseRef !== R3_BASE) throw new Error('scope base does not equal immutable R3 base');
  if (typeof input.repositoryRoot !== 'string' || !path.isAbsolute(input.repositoryRoot)) {
    throw new Error('repository root must be absolute');
  }
  const manifest = JSON.parse(fs.readFileSync(path.join(
    input.repositoryRoot,
    'backend',
    'architecture',
    'r3-context-boundaries.json',
  ), 'utf8'));
  assertAllowedPathsMatch(manifest.allowedChangedPaths, ALLOWED_PATHS);
  const r4ManifestAbsolutePath = path.join(input.repositoryRoot, ...R4_MANIFEST_PATH.split('/'));
  const delegatedR4 = fs.existsSync(r4ManifestAbsolutePath)
    ? validateR4DelegationManifest(JSON.parse(fs.readFileSync(r4ManifestAbsolutePath, 'utf8')))
    : null;
  const r5ManifestAbsolutePath = path.join(input.repositoryRoot, ...R5_MANIFEST_PATH.split('/'));
  const delegatedR5 = fs.existsSync(r5ManifestAbsolutePath)
    ? validateR5IdentityManifest(JSON.parse(fs.readFileSync(r5ManifestAbsolutePath, 'utf8')))
    : null;
  const effectiveAllowedPaths = [...new Set([
    ...ALLOWED_PATHS,
    ...(delegatedR4 ? delegatedR4.allowedChangedPaths : []),
    ...(delegatedR5 ? delegatedR5.allowedChangedPaths : []),
  ])].sort();
  const tracked = gitLines(input.repositoryRoot, ['diff', '--no-renames', '--name-only', R3_BASE, '--']);
  const untracked = gitLines(input.repositoryRoot, ['ls-files', '--others', '--exclude-standard']);
  const changedPaths = [...new Set([...tracked, ...untracked])].sort();
  const snapshot = validateScopeSnapshot({
    baseRef: input.baseRef,
    allowedPaths: effectiveAllowedPaths,
    changedPaths,
  });
  const reportPath = input.reportPath === undefined
    ? path.join((fs.realpathSync.native || fs.realpathSync)(os.tmpdir()), `aarast-r3-scope-${crypto.randomUUID()}.json`)
    : input.reportPath;
  const result = { ...snapshot, reportPath };
  writeAtomicJson(reportPath, result);
  return Object.freeze(result);
}

function runCli(dependencies = {}) {
  const argv = dependencies.argv || process.argv.slice(2);
  const stdout = dependencies.stdout || ((message) => process.stdout.write(`${message}\n`));
  const stderr = dependencies.stderr || ((message) => process.stderr.write(`${message}\n`));
  const validate = dependencies.validate || validateR3Scope;
  try {
    const hasReportPath = argv.length === 5 && argv[3] === '--report-path';
    if (![3, 5].includes(argv.length) || argv[0] !== '--check' || argv[1] !== '--base-ref'
        || argv[2] !== R3_BASE || (argv.length === 5 && !hasReportPath)) {
      throw new Error('invalid arguments');
    }
    const result = validate({
      repositoryRoot: path.resolve(__dirname, '../../..'),
      baseRef: argv[2],
      ...(hasReportPath ? { reportPath: argv[4] } : {}),
    });
    stdout(`PASS - R3 scope: changed=${result.changedPaths.length}, unexpected=0, base=${R3_BASE}`);
    return 0;
  } catch {
    stderr('ERROR - R3 scope validation failed');
    return 2;
  }
}

module.exports = {
  R3_BASE,
  ALLOWED_PATHS,
  R4_ALLOWED_PATHS,
  R5_ALLOWED_PATHS,
  assertAllowedPathsMatch,
  validateR4DelegationManifest,
  validateR5IdentityManifest,
  writeAtomicJson,
  validateR3Scope,
  validateScopeSnapshot,
  runCli,
};
if (require.main === module) process.exitCode = runCli();
