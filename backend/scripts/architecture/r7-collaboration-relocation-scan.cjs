'use strict';

const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { execFileSync } = require('node:child_process');
const { types: utilTypes } = require('node:util');
const ts = require('typescript');

const R7_BASE = '31ea5324007fc71fa4b3590fbb98a454ee1deaa7';
const MANIFEST_PATH = 'backend/architecture/r7-collaboration-relocation.json';
const STAGES = Object.freeze(['design', 'snapshot', 'history', 'relocated', 'strict']);

const EXPECTED_MOVES = Object.freeze([
  ['backend/src/contribution-history/contribution-history.contracts.ts', 'backend/src/modules/collaboration/internal/contribution-history.contracts.ts'],
  ['backend/src/contribution-history/contribution-history.controller.ts', 'backend/src/modules/collaboration/api/contribution-history.controller.ts'],
  ['backend/src/contribution-history/contribution-history.service.ts', 'backend/src/modules/collaboration/internal/contribution-history.service.ts'],
  ['backend/src/contribution-history/contribution-snapshot.builder.ts', 'backend/src/modules/collaboration/public/contribution-snapshot.builder.ts'],
  ['backend/src/contribution-history/contributor-scope.service.ts', 'backend/src/modules/collaboration/internal/contributor-scope.service.ts'],
  ['backend/src/contribution-history/dto/list-contributions.dto.ts', 'backend/src/modules/collaboration/api/dto/list-contributions.dto.ts'],
  ['backend/src/sharing/dto/create-plan-invite.dto.ts', 'backend/src/modules/collaboration/api/dto/create-plan-invite.dto.ts'],
  ['backend/src/sharing/dto/create-shared-member.dto.ts', 'backend/src/modules/collaboration/api/dto/create-shared-member.dto.ts'],
  ['backend/src/sharing/dto/leave-plan.dto.ts', 'backend/src/modules/collaboration/api/dto/leave-plan.dto.ts'],
  ['backend/src/sharing/dto/request-invite-otp.dto.ts', 'backend/src/modules/collaboration/api/dto/request-invite-otp.dto.ts'],
  ['backend/src/sharing/dto/update-shared-member.dto.ts', 'backend/src/modules/collaboration/api/dto/update-shared-member.dto.ts'],
  ['backend/src/sharing/dto/verify-invite-otp.dto.ts', 'backend/src/modules/collaboration/api/dto/verify-invite-otp.dto.ts'],
  ['backend/src/sharing/invitation-delivery.service.ts', 'backend/src/modules/collaboration/internal/invitation-delivery.service.ts'],
  ['backend/src/sharing/invite-access.service.ts', 'backend/src/modules/collaboration/internal/invite-access.service.ts'],
  ['backend/src/sharing/permission.service.ts', 'backend/src/modules/collaboration/internal/permission.service.ts'],
  ['backend/src/sharing/plan-permissions.ts', 'backend/src/modules/collaboration/internal/plan-permissions.ts'],
  ['backend/src/sharing/sharing.controller.ts', 'backend/src/modules/collaboration/api/sharing.controller.ts'],
  ['backend/src/sharing/sharing.service.ts', 'backend/src/modules/collaboration/internal/sharing.service.ts'],
].map(([from, to]) => Object.freeze({ from, to })));

const EXPECTED_SOURCE_PARITY_HASHES = Object.freeze([
  'aeab7af798e09cb6beae0d7409cf40d25ebd645096bed391f880e5a7a108239c',
  '1ee407b59727469829bc93f301df0ad61f91535c9b4f181f33e944893249a547',
  '1f34aaf0b9a2b7d8101e3065fba9d40c5128ca6ce7471cd383a6751feb0f68ce',
  '619abcebff09ea077d15040fd12b380a828fad54ac5a4ed9b43ca6742baddd87',
  'ba4573a342450fe44ccc4f72def9931a1121fe4238e0f7892ed2a882dd6b33d2',
  '2aa1486c288afe3eebb251ee4007dc32c73912571399d67285dc4c9a7597f02d',
  'ba4ee89e9a2608cd6f6c759068b532c2be234a30eec6a7079547c5d1b0a4a220',
  '53f43fba776d4f117ae56baf5b541fcf470cbdc04c755892bb4834471f83b536',
  'ec5719af9c3b94eb0792c5aee6815d1a835cbd0d1a446b165021f95221ea48f3',
  '0da6d2dcfdd4adbf81daccaf763441a3f1ac01fd7961425de3318169cb4b63fa',
  '03744001cf43aa3f241bf3b319a484b0d418e1a39d0fbb01245f4e825399410c',
  'a3b383c7ff3331870c900a9b01cded90ddd33c597187e406004f838e8b054f0d',
  '36c16edbbb8bd647bddae34f1e4d2377fa5b13c708695bce831781f4ad05612c',
  'c17110576aba439e6bda13b3b71fa331916b978e433d48b7f6035db0fe23474e',
  '3fd1670524fc55e4dcdd4b9322ef12724e2dd77e9d95adbcaf3ca09ef4980146',
  'c856e84a7716a7efed4b7f4e7303b60f767ea6ddaa7481429645de20969d6161',
  'c0d93d3c25b41c523462fa3b2f415a5786ab83621ea7b4ece467bb053918dee7',
  '37894e0c52a61de94f2fa8596bc9a1c7dfd35b7bd1702e541f830f2710fc9955',
]);

const EXPECTED_SOURCE_PARITY = Object.freeze(EXPECTED_MOVES.map((move, index) => Object.freeze({
  from: move.from,
  to: move.to,
  normalizedSha256: EXPECTED_SOURCE_PARITY_HASHES[index],
})));

const EXPECTED_EXISTING_COLLABORATION_FILES = Object.freeze([
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
]);

const EXPECTED_PUBLIC_SNAPSHOT_CONTRACT = Object.freeze({
  path: 'backend/src/modules/collaboration/public/contribution-snapshot.builder.ts',
  exports: Object.freeze([
    'buildContributionSnapshot',
    'canonicalJson',
    'hashContributionSnapshot',
    'validateContributionSnapshot',
  ]),
});

const EXPECTED_PUBLIC_SNAPSHOT_IMPORTS = Object.freeze([
  '@nestjs/common',
  '@prisma/client',
  'node:crypto',
]);
const EXPECTED_PUBLIC_SNAPSHOT_CONSUMERS = Object.freeze([
  Object.freeze({ path: 'backend/src/budget-categories/budget-categories.service.ts', specifier: '../modules/collaboration/public/contribution-snapshot.builder', names: Object.freeze(['buildContributionSnapshot']) }),
  Object.freeze({ path: 'backend/src/contribution-history/contribution-history.service.ts', specifier: '../modules/collaboration/public/contribution-snapshot.builder', names: Object.freeze(['canonicalJson', 'hashContributionSnapshot', 'validateContributionSnapshot']) }),
  Object.freeze({ path: 'backend/src/guests/guests.service.ts', specifier: '../modules/collaboration/public/contribution-snapshot.builder', names: Object.freeze(['buildContributionSnapshot']) }),
  Object.freeze({ path: 'backend/src/marketplace/quote-offer-acceptance.ts', specifier: '../modules/collaboration/public/contribution-snapshot.builder', names: Object.freeze(['buildContributionSnapshot']) }),
  Object.freeze({ path: 'backend/src/marketplace/quote-offer-rejection.ts', specifier: '../modules/collaboration/public/contribution-snapshot.builder', names: Object.freeze(['buildContributionSnapshot']) }),
  Object.freeze({ path: 'backend/src/marketplace/quote-request-cancellation.ts', specifier: '../modules/collaboration/public/contribution-snapshot.builder', names: Object.freeze(['buildContributionSnapshot']) }),
  Object.freeze({ path: 'backend/src/marketplace/quote-request-creation.ts', specifier: '../modules/collaboration/public/contribution-snapshot.builder', names: Object.freeze(['buildContributionSnapshot']) }),
  Object.freeze({ path: 'backend/src/sharing/sharing.service.ts', specifier: '../modules/collaboration/public/contribution-snapshot.builder', names: Object.freeze(['buildContributionSnapshot']) }),
  Object.freeze({ path: 'backend/src/tasks/tasks.service.ts', specifier: '../modules/collaboration/public/contribution-snapshot.builder', names: Object.freeze(['buildContributionSnapshot']) }),
  Object.freeze({ path: 'backend/src/wedding-costs/wedding-costs.service.ts', specifier: '../modules/collaboration/public/contribution-snapshot.builder', names: Object.freeze(['buildContributionSnapshot']) }),
  Object.freeze({ path: 'backend/src/wedding-plans/wedding-plans.service.ts', specifier: '../modules/collaboration/public/contribution-snapshot.builder', names: Object.freeze(['buildContributionSnapshot']) }),
  Object.freeze({ path: 'backend/test/contribution-history-dedupe.test.ts', specifier: '../src/modules/collaboration/public/contribution-snapshot.builder', names: Object.freeze(['canonicalJson', 'hashContributionSnapshot']) }),
  Object.freeze({ path: 'backend/test/contribution-history-privacy.test.ts', specifier: '../src/modules/collaboration/public/contribution-snapshot.builder', names: Object.freeze(['buildContributionSnapshot', 'validateContributionSnapshot']) }),
]);

const EXPECTED_CONTROLLER_INVENTORIES = Object.freeze([
  Object.freeze({
    target: 'backend/src/modules/collaboration/api/contribution-history.controller.ts',
    operations: 2,
    fingerprint: '52bfb1432ab942b8c68259f4457788a59a36ea4758a31bc20df42d731e688da4',
  }),
  Object.freeze({
    target: 'backend/src/modules/collaboration/api/sharing.controller.ts',
    operations: 17,
    fingerprint: '14e679f88f40b86586234024ac1f239a21a01cf915219f721f13f448b9767f01',
  }),
]);

const EXPECTED_CONSTRUCTOR_CONSUMERS = Object.freeze([
  Object.freeze({
    from: 'backend/src/sharing/invitation-delivery.service.ts',
    to: 'backend/src/modules/collaboration/internal/invitation-delivery.service.ts',
    consumerClass: 'InvitationDeliveryService',
    parameter: 'transientDelivery',
    parameterIndex: 0,
    token: 'IDENTITY_TRANSIENT_DELIVERY_PORT',
  }),
  Object.freeze({
    from: 'backend/src/sharing/invite-access.service.ts',
    to: 'backend/src/modules/collaboration/internal/invite-access.service.ts',
    consumerClass: 'InviteAccessService',
    parameter: 'auth',
    parameterIndex: 1,
    token: 'IDENTITY_AUTH_PORT',
  }),
  Object.freeze({
    from: 'backend/src/sharing/sharing.service.ts',
    to: 'backend/src/modules/collaboration/internal/sharing.service.ts',
    consumerClass: 'SharingService',
    parameter: 'notifications',
    parameterIndex: 2,
    token: 'NOTIFICATIONS_PORT',
  }),
  Object.freeze({
    from: 'backend/src/sharing/sharing.service.ts',
    to: 'backend/src/modules/collaboration/internal/sharing.service.ts',
    consumerClass: 'SharingService',
    parameter: 'realtime',
    parameterIndex: 5,
    token: 'MESSAGING_REALTIME_PORT',
  }),
]);

const EXPECTED_CONTROLLER_SOURCES = Object.freeze([
  Object.freeze({
    from: 'backend/src/contribution-history/contribution-history.controller.ts',
    to: 'backend/src/modules/collaboration/api/contribution-history.controller.ts',
  }),
  Object.freeze({
    from: 'backend/src/sharing/sharing.controller.ts',
    to: 'backend/src/modules/collaboration/api/sharing.controller.ts',
  }),
]);

const EXPECTED_RETIRED_DEPENDENCY_KEYS = Object.freeze([
  'context-finance-cross-context|src/budget-categories/budget-categories.service.ts|src/contribution-history/contribution-snapshot.builder.ts',
  'context-finance-cross-context|src/wedding-costs/wedding-costs.service.ts|src/contribution-history/contribution-snapshot.builder.ts',
  'context-guests-cross-context|src/guests/guests.service.ts|src/contribution-history/contribution-snapshot.builder.ts',
  'context-marketplace-cross-context|src/marketplace/quote-offer-acceptance.ts|src/contribution-history/contribution-snapshot.builder.ts',
  'context-marketplace-cross-context|src/marketplace/quote-offer-rejection.ts|src/contribution-history/contribution-snapshot.builder.ts',
  'context-marketplace-cross-context|src/marketplace/quote-request-cancellation.ts|src/contribution-history/contribution-snapshot.builder.ts',
  'context-marketplace-cross-context|src/marketplace/quote-request-creation.ts|src/contribution-history/contribution-snapshot.builder.ts',
  'context-planning-cross-context|src/wedding-plans/wedding-plans.service.ts|src/contribution-history/contribution-snapshot.builder.ts',
  'context-tasks-cross-context|src/tasks/tasks.service.ts|src/contribution-history/contribution-snapshot.builder.ts',
]);

const EXPECTED_BASE_DEPENDENCY_KEYS = Object.freeze([
  'context-backoffice-cross-context|src/admin/admin-mutation-executor.ts|src/marketplace/provider-review-rating.ts',
  'context-catalog-cross-context|src/catalogs/administrative-catalog.service.ts|src/admin/admin-mutation-gate.ts',
  'context-catalog-cross-context|src/catalogs/catalogs.controller.ts|src/admin/admin-permission.decorator.ts',
  'context-catalog-cross-context|src/catalogs/catalogs.controller.ts|src/admin/admin-permission.guard.ts',
  'context-catalog-cross-context|src/catalogs/catalogs.controller.ts|src/admin/admin.guard.ts',
  'context-catalog-cross-context|src/catalogs/reference-catalog.service.ts|src/admin/admin-mutation-gate.ts',
  'context-finance-cross-context|src/budget-categories/budget-categories.service.ts|src/contribution-history/contribution-snapshot.builder.ts',
  'context-finance-cross-context|src/wedding-costs/wedding-costs.service.ts|src/contribution-history/contribution-snapshot.builder.ts',
  'context-guests-cross-context|src/guests/guests.service.ts|src/contribution-history/contribution-snapshot.builder.ts',
  'context-insights-cross-context|src/dashboard/dashboard.contracts.ts|src/wedding-plans/wedding-location.ts',
  'context-insights-cross-context|src/dashboard/dashboard.service.ts|src/wedding-plans/wedding-location.ts',
  'context-marketplace-cross-context|src/marketplace/marketplace.presenter.ts|src/wedding-plans/wedding-location.ts',
  'context-marketplace-cross-context|src/marketplace/marketplace.service.ts|src/wedding-costs/wedding-cost.presenter.ts',
  'context-marketplace-cross-context|src/marketplace/marketplace.service.ts|src/wedding-plans/wedding-location.ts',
  'context-marketplace-cross-context|src/marketplace/quote-offer-acceptance.ts|src/contribution-history/contribution-snapshot.builder.ts',
  'context-marketplace-cross-context|src/marketplace/quote-offer-acceptance.ts|src/conversations/conversation-lifecycle.ts',
  'context-marketplace-cross-context|src/marketplace/quote-offer-acceptance.ts|src/wedding-costs/wedding-cost.presenter.ts',
  'context-marketplace-cross-context|src/marketplace/quote-offer-rejection.ts|src/contribution-history/contribution-snapshot.builder.ts',
  'context-marketplace-cross-context|src/marketplace/quote-offer-rejection.ts|src/conversations/conversation-lifecycle.ts',
  'context-marketplace-cross-context|src/marketplace/quote-request-cancellation.ts|src/contribution-history/contribution-snapshot.builder.ts',
  'context-marketplace-cross-context|src/marketplace/quote-request-cancellation.ts|src/conversations/conversation-lifecycle.ts',
  'context-marketplace-cross-context|src/marketplace/quote-request-creation.ts|src/contribution-history/contribution-snapshot.builder.ts',
  'context-marketplace-cross-context|src/marketplace/quote-request-creation.ts|src/conversations/conversation-lifecycle.ts',
  'context-marketplace-cross-context|src/provider-dashboard/provider-dashboard.service.ts|src/conversations/conversation-lifecycle.ts',
  'context-marketplace-cross-context|src/provider-dashboard/provider-dashboard.service.ts|src/wedding-plans/wedding-location.ts',
  'context-messaging-cross-context|src/conversations/conversations.service.ts|src/provider-dashboard/provider-access-policy.ts',
  'context-notifications-cross-context|src/notifications/notifications.service.ts|src/provider-dashboard/provider-access-policy.ts',
  'context-planning-cross-context|src/onboarding/dto/import-local-plan.dto.ts|src/guests/dto/create-guest.dto.ts',
  'context-planning-cross-context|src/onboarding/dto/import-local-plan.dto.ts|src/tasks/dto/create-task.dto.ts',
  'context-planning-cross-context|src/wedding-plans/wedding-plans.service.ts|src/contribution-history/contribution-snapshot.builder.ts',
  'context-tasks-cross-context|src/tasks/tasks.service.ts|src/contribution-history/contribution-snapshot.builder.ts',
]);

const EXPECTED_OWNERSHIP_PROJECTION = Object.freeze([
  Object.freeze({ from: 'backend/src/contribution-history/contribution-history.service.ts', to: 'backend/src/modules/collaboration/internal/contribution-history.service.ts', records: 5, occurrences: 7 }),
  Object.freeze({ from: 'backend/src/sharing/invite-access.service.ts', to: 'backend/src/modules/collaboration/internal/invite-access.service.ts', records: 1, occurrences: 1 }),
  Object.freeze({ from: 'backend/src/sharing/permission.service.ts', to: 'backend/src/modules/collaboration/internal/permission.service.ts', records: 2, occurrences: 6 }),
  Object.freeze({ from: 'backend/src/sharing/sharing.service.ts', to: 'backend/src/modules/collaboration/internal/sharing.service.ts', records: 20, occurrences: 66 }),
]);
const EXPECTED_OWNERSHIP_SEMANTIC_HASHES = Object.freeze([
  'de87d345463515447da89666d43b82f04f8d7843b1c6f244e74bf65592b63108',
  '1e583f56c329d98a56a75d6ddbcb9184338fb6d146807ae4a2f761a05d988517',
  'b9b2c79112659cace11469e13180769de683576c47448c5f3a034434031e1b4f',
  'e3f1bd58cb00c86d0942be0b1e6af83c8c950d01a7f30bbad1f4ad0b195392fb',
]);

const EXPECTED_OPTIONAL_DEPENDENCIES = Object.freeze([
  Object.freeze({
    from: 'backend/src/sharing/sharing.service.ts',
    to: 'backend/src/modules/collaboration/internal/sharing.service.ts',
    consumerClass: 'SharingService',
    parameter: 'realtime',
    parameterIndex: 5,
    token: 'MESSAGING_REALTIME_PORT',
    optional: true,
    undefinedBehavior: 'unchanged',
  }),
]);

const EXPECTED_APPROVED_GLOBAL_MODULES = Object.freeze([
  'backend/src/conversations/conversation-realtime.module.ts',
  'backend/src/platform/database/prisma.module.ts',
]);

const EXPECTED_BASELINES = Object.freeze({
  baseDependencyRecords: 31,
  retiredDependencyRecords: 9,
  strictDependencyRecords: 22,
  baseOwnershipRecords: 385,
  baseOwnershipOccurrences: 781,
  projectedOwnershipRecords: 28,
  projectedOwnershipOccurrences: 80,
  strictOwnershipRecords: 385,
  strictOwnershipOccurrences: 781,
});

const EXPECTED_ALLOWED_PATHS = Object.freeze([
  'ARCHITECTURE.md',
  'CHANGELOG.md',
  'backend/.dependency-cruiser-known-violations.json',
  'backend/architecture/ownership-baseline.json',
  'backend/architecture/r3-context-boundaries.json',
  'backend/architecture/r7-collaboration-relocation.json',
  'backend/package.json',
  'backend/scripts/architecture/r3-context-scan.cjs',
  'backend/scripts/architecture/r3-scope.cjs',
  'backend/scripts/architecture/r5-identity-scan.cjs',
  'backend/scripts/architecture/r6-sharing-otp-transport-scan.cjs',
  'backend/scripts/architecture/r7-collaboration-relocation-scan.cjs',
  'backend/scripts/security/prisma-config-merge-security.cjs',
  'backend/scripts/smoke/phase2-auth-lifecycle-concurrency-smoke.ts',
  'backend/scripts/smoke/phase2-conversation-revocation-smoke.ts',
  'backend/scripts/smoke/phase2-marketplace-write-concurrency-smoke.ts',
  'backend/scripts/smoke/phase2-money-authorization-concurrency-smoke.ts',
  'backend/scripts/smoke/phase2-notification-authorization-concurrency-smoke.ts',
  'backend/scripts/smoke/phase2-notification-preferences-smoke.ts',
  'backend/scripts/smoke/phase2-plan-permission-concurrency-smoke.ts',
  'backend/scripts/smoke/phase2-quote-concurrency-smoke.ts',
  'backend/scripts/smoke/phase2-sharing-permission-concurrency-smoke.ts',
  'backend/scripts/smoke/phase2-task-guest-permission-concurrency-smoke.ts',
  'backend/scripts/smoke/phase3-context-transition-smoke.ts',
  'backend/src/budget-categories/budget-categories.service.ts',
  'backend/src/contribution-history/contribution-history.contracts.ts',
  'backend/src/contribution-history/contribution-history.controller.ts',
  'backend/src/contribution-history/contribution-history.service.ts',
  'backend/src/contribution-history/contribution-snapshot.builder.ts',
  'backend/src/contribution-history/contributor-scope.service.ts',
  'backend/src/contribution-history/dto/list-contributions.dto.ts',
  'backend/src/guests/guests.service.ts',
  'backend/src/marketplace/quote-offer-acceptance.ts',
  'backend/src/marketplace/quote-offer-rejection.ts',
  'backend/src/marketplace/quote-request-cancellation.ts',
  'backend/src/marketplace/quote-request-creation.ts',
  'backend/src/modules/collaboration/api/contribution-history.controller.ts',
  'backend/src/modules/collaboration/api/dto/create-plan-invite.dto.ts',
  'backend/src/modules/collaboration/api/dto/create-shared-member.dto.ts',
  'backend/src/modules/collaboration/api/dto/leave-plan.dto.ts',
  'backend/src/modules/collaboration/api/dto/list-contributions.dto.ts',
  'backend/src/modules/collaboration/api/dto/request-invite-otp.dto.ts',
  'backend/src/modules/collaboration/api/dto/update-shared-member.dto.ts',
  'backend/src/modules/collaboration/api/dto/verify-invite-otp.dto.ts',
  'backend/src/modules/collaboration/api/sharing.controller.ts',
  'backend/src/modules/collaboration/collaboration.module.ts',
  'backend/src/modules/collaboration/internal/collaboration-history.internal.module.ts',
  'backend/src/modules/collaboration/internal/collaboration-permission.internal.module.ts',
  'backend/src/modules/collaboration/internal/collaboration-scope.internal.module.ts',
  'backend/src/modules/collaboration/internal/collaboration-services.internal.module.ts',
  'backend/src/modules/collaboration/internal/contribution-history.contracts.ts',
  'backend/src/modules/collaboration/internal/contribution-history.service.ts',
  'backend/src/modules/collaboration/internal/contributor-scope.service.ts',
  'backend/src/modules/collaboration/internal/invitation-delivery.service.ts',
  'backend/src/modules/collaboration/internal/invite-access.service.ts',
  'backend/src/modules/collaboration/internal/permission.service.ts',
  'backend/src/modules/collaboration/internal/plan-permissions.ts',
  'backend/src/modules/collaboration/internal/sharing.service.ts',
  'backend/src/modules/collaboration/public/contribution-snapshot.builder.ts',
  'backend/src/sharing/dto/create-plan-invite.dto.ts',
  'backend/src/sharing/dto/create-shared-member.dto.ts',
  'backend/src/sharing/dto/leave-plan.dto.ts',
  'backend/src/sharing/dto/request-invite-otp.dto.ts',
  'backend/src/sharing/dto/update-shared-member.dto.ts',
  'backend/src/sharing/dto/verify-invite-otp.dto.ts',
  'backend/src/sharing/invitation-delivery.service.ts',
  'backend/src/sharing/invite-access.service.ts',
  'backend/src/sharing/permission.service.ts',
  'backend/src/sharing/plan-permissions.ts',
  'backend/src/sharing/sharing.controller.ts',
  'backend/src/sharing/sharing.service.ts',
  'backend/src/tasks/tasks.service.ts',
  'backend/src/wedding-costs/wedding-costs.service.ts',
  'backend/src/wedding-plans/wedding-plans.service.ts',
  'backend/test/architecture-r1-layout.test.ts',
  'backend/test/architecture-r3-closure.test.ts',
  'backend/test/architecture-r3-collaboration-ports.test.ts',
  'backend/test/architecture-r3-composition.test.ts',
  'backend/test/architecture-r3-contexts.test.ts',
  'backend/test/architecture-r3-identity-port.test.ts',
  'backend/test/architecture-r3-notifications-port.test.ts',
  'backend/test/architecture-r3-scope.test.ts',
  'backend/test/architecture-r4-planning-finance-boundary.test.ts',
  'backend/test/architecture-r5-identity-relocation.test.ts',
  'backend/test/architecture-r6-sharing-otp-transport.test.ts',
  'backend/test/architecture-r7-collaboration-relocation.test.ts',
  'backend/test/archived-plan-lifecycle.test.ts',
  'backend/test/contexts.test.ts',
  'backend/test/contribution-history-dedupe.test.ts',
  'backend/test/contribution-history-freeze.test.ts',
  'backend/test/contribution-history-list-consistency.test.ts',
  'backend/test/contribution-history-privacy.test.ts',
  'backend/test/contributor-live-read-boundary.test.ts',
  'backend/test/contributor-permission-authority.test.ts',
  'backend/test/contributor-task-guest-scope.test.ts',
  'backend/test/invite-delivery.test.ts',
  'backend/test/notification-logic.test.ts',
  'backend/test/plan-permissions.test.ts',
  'backend/test/prisma-config-merge-security.test.ts',
  'backend/test/sharing-member-scope.test.ts',
  'backend/test/sharing-permission-ceiling.test.ts',
  'backend/test/sharing-reinvite-authority.test.ts',
  'backend/test/sharing-self-leave.test.ts',
  'docs/README.md',
  'docs/SCRIPTS.md',
  'docs/backend/README.md',
  'docs/project/DECISIONS.md',
  'docs/project/EXECUTION_PLAN.md',
  'docs/project/STATUS.md',
  'docs/qa/README.md',
  'docs/superpowers/plans/2026-08-23-modular-monolith-r7-collaboration-relocation-completion.md',
  'docs/superpowers/plans/2026-08-23-modular-monolith-r7-collaboration-relocation.md',
  'docs/superpowers/specs/2026-08-23-modular-monolith-r7-collaboration-relocation-completion.md',
  'docs/superpowers/specs/2026-08-23-modular-monolith-r7-collaboration-relocation-design.md',
]);

function assertPlainData(value, label, seen = new Set(), depth = 0) {
  if (value === null || typeof value === 'boolean'
      || (typeof value === 'number' && Number.isFinite(value))
      || (typeof value === 'string' && value.length <= 4096)) return;
  if (!value || typeof value !== 'object' || depth > 32 || seen.has(value)
      || utilTypes.isProxy(value)) {
    throw new Error(label + ' must be bounded plain data');
  }
  seen.add(value);
  if (Array.isArray(value)) {
    if (Object.getPrototypeOf(value) !== Array.prototype || value.length > 512) {
      throw new Error(label + ' must be a bounded plain array');
    }
    for (let index = 0; index < value.length; index += 1) {
      const descriptor = Object.getOwnPropertyDescriptor(value, String(index));
      if (!descriptor || !descriptor.enumerable
          || !Object.prototype.hasOwnProperty.call(descriptor, 'value')) {
        throw new Error(label + ' must be dense plain data');
      }
      assertPlainData(value[index], label, seen, depth + 1);
    }
    if (Reflect.ownKeys(value).length !== value.length + 1) {
      throw new Error(label + ' must contain array data only');
    }
  } else {
    if (Object.getPrototypeOf(value) !== Object.prototype) {
      throw new Error(label + ' must be a plain object');
    }
    for (const key of Reflect.ownKeys(value)) {
      const descriptor = Object.getOwnPropertyDescriptor(value, key);
      if (typeof key !== 'string' || !descriptor || !descriptor.enumerable
          || !Object.prototype.hasOwnProperty.call(descriptor, 'value')) {
        throw new Error(label + ' must use plain data properties');
      }
      assertPlainData(value[key], label, seen, depth + 1);
    }
  }
  seen.delete(value);
}

function assertExact(actual, expected, label) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(label + ' drift detected');
  }
}

function validateRelativePaths(paths, label) {
  if (!Array.isArray(paths)) throw new Error(label + ' must be an array');
  for (const entry of paths) {
    if (typeof entry !== 'string' || !entry || entry.includes('\\')
        || path.posix.isAbsolute(entry) || path.win32.isAbsolute(entry)
        || entry.split('/').includes('.') || entry.split('/').includes('..')) {
      throw new Error(label + ' contains an invalid path');
    }
  }
  if (new Set(paths).size !== paths.length
      || JSON.stringify(paths) !== JSON.stringify([...paths].sort())) {
    throw new Error(label + ' must be sorted and unique');
  }
}

function validateR7Manifest(value) {
  assertPlainData(value, 'R7 manifest');
  const keys = Object.keys(value).sort();
  const expectedKeys = [
    'allowedChangedPaths',
    'baseRevision',
    'expectedBaselines',
    'frozenOptionalDependencies',
    'historicalHandoffs',
    'moves',
    'publicSnapshotContract',
    'schemaVersion',
    'sourceParity',
    'stage',
  ];
  assertExact(keys, expectedKeys, 'R7 manifest keys');
  if (value.schemaVersion !== 1 || value.baseRevision !== R7_BASE) {
    throw new Error('R7 manifest identity is invalid');
  }
  if (!STAGES.includes(value.stage)) throw new Error('R7 manifest stage is invalid');
  assertExact(value.moves, EXPECTED_MOVES, 'R7 move map');
  assertExact(value.sourceParity, EXPECTED_SOURCE_PARITY, 'R7 source parity');
  assertExact(value.publicSnapshotContract, EXPECTED_PUBLIC_SNAPSHOT_CONTRACT, 'R7 public snapshot contract');
  assertExact(value.historicalHandoffs, {
    constructorConsumers: EXPECTED_CONSTRUCTOR_CONSUMERS,
    controllerSources: EXPECTED_CONTROLLER_SOURCES,
    retiredDependencyKeys: EXPECTED_RETIRED_DEPENDENCY_KEYS,
    ownershipProjection: EXPECTED_OWNERSHIP_PROJECTION,
  }, 'R7 historical handoffs');
  assertExact(value.frozenOptionalDependencies, EXPECTED_OPTIONAL_DEPENDENCIES, 'R7 optional dependencies');
  assertExact(value.expectedBaselines, EXPECTED_BASELINES, 'R7 expected baselines');
  validateRelativePaths(value.allowedChangedPaths, 'R7 allowed paths');
  assertExact(value.allowedChangedPaths, EXPECTED_ALLOWED_PATHS, 'R7 allowed paths');
  return Object.freeze(value);
}

function dependencyKey(record) {
  return [record.rule && record.rule.name, record.from, record.to].join('|');
}

function stageTargetPaths(manifest) {
  if (manifest.stage === 'design') return new Set();
  if (manifest.stage === 'snapshot') return new Set([manifest.publicSnapshotContract.path]);
  if (manifest.stage === 'history') {
    return new Set(manifest.moves
      .filter((move) => move.from.startsWith('backend/src/contribution-history/'))
      .map((move) => move.to));
  }
  return new Set(manifest.moves.map((move) => move.to));
}

function isInside(parent, candidate) {
  const relative = path.relative(parent, candidate);
  return relative === '' || (!path.isAbsolute(relative) && relative !== '..'
    && !relative.startsWith(`..${path.sep}`));
}

function inspectExistingPath(repositoryRoot, relativePath, expected) {
  const repositoryRealPath = (fs.realpathSync.native || fs.realpathSync)(repositoryRoot);
  let cursor = repositoryRoot;
  for (const part of relativePath.split('/')) {
    cursor = path.join(cursor, part);
    if (!fs.existsSync(cursor)) return Object.freeze({ exists: false });
    const status = fs.lstatSync(cursor);
    if (status.isSymbolicLink()) {
      throw new Error('R7 source contains a symbolic or junction reparse point');
    }
  }
  const status = fs.lstatSync(cursor);
  const realPath = (fs.realpathSync.native || fs.realpathSync)(cursor);
  if (!isInside(repositoryRealPath, realPath)) throw new Error('R7 source escapes the repository');
  if (expected === 'file' && !status.isFile()) throw new Error('R7 source is not a plain file');
  if (expected === 'directory' && !status.isDirectory()) {
    throw new Error('R7 source root is not a plain directory');
  }
  return Object.freeze({ exists: true });
}

function listPlainFiles(repositoryRoot, relativeRoot) {
  const inspected = inspectExistingPath(repositoryRoot, relativeRoot, 'directory');
  if (!inspected.exists) return [];
  const files = [];
  const visit = (relativeDirectory) => {
    const absoluteDirectory = path.join(repositoryRoot, ...relativeDirectory.split('/'));
    for (const name of fs.readdirSync(absoluteDirectory).sort()) {
      const relative = `${relativeDirectory}/${name}`;
      const absolute = path.join(repositoryRoot, ...relative.split('/'));
      const status = fs.lstatSync(absolute);
      if (status.isSymbolicLink()) {
        throw new Error('R7 source contains a symbolic or junction reparse point');
      }
      if (status.isDirectory()) visit(relative);
      else if (status.isFile()) files.push(relative);
      else throw new Error('R7 source contains a non-plain filesystem entry');
    }
  };
  visit(relativeRoot);
  return files.sort();
}

function validateStagedLayout(repositoryRoot, manifest) {
  const targetPaths = stageTargetPaths(manifest);
  let sourceFiles = 0;
  let targetFiles = 0;
  for (const move of manifest.moves) {
    const sourceExists = inspectExistingPath(repositoryRoot, move.from, 'file').exists;
    const targetExists = inspectExistingPath(repositoryRoot, move.to, 'file').exists;
    if (sourceExists === targetExists) {
      throw new Error('R7 move must have exactly one active source path');
    }
    if (targetExists !== targetPaths.has(move.to)) {
      throw new Error('R7 stage does not match the exact move layout');
    }
    sourceFiles += sourceExists ? 1 : 0;
    targetFiles += targetExists ? 1 : 0;
  }

  const expectedLegacy = manifest.moves
    .filter((move) => !targetPaths.has(move.to))
    .map((move) => move.from)
    .sort();
  const actualLegacy = [
    ...listPlainFiles(repositoryRoot, 'backend/src/contribution-history'),
    ...listPlainFiles(repositoryRoot, 'backend/src/sharing'),
  ].sort();
  assertExact(actualLegacy, expectedLegacy, 'R7 legacy source inventory');

  const expectedCollaboration = [
    ...EXPECTED_EXISTING_COLLABORATION_FILES,
    ...targetPaths,
  ].sort();
  assertExact(
    listPlainFiles(repositoryRoot, 'backend/src/modules/collaboration'),
    expectedCollaboration,
    'R7 final Collaboration inventory',
  );
  if (manifest.stage === 'strict') {
    for (const legacyRoot of ['backend/src/contribution-history', 'backend/src/sharing']) {
      if (inspectExistingPath(repositoryRoot, legacyRoot, 'directory').exists) {
        throw new Error('R7 strict stage retains a legacy root');
      }
    }
  }
  return Object.freeze({ sourceFiles, targetFiles });
}

function verifyBaselines(repositoryRoot, manifest) {
  const dependency = JSON.parse(fs.readFileSync(path.join(
    repositoryRoot,
    'backend',
    '.dependency-cruiser-known-violations.json',
  ), 'utf8'));
  const expectedDependencyRecords = manifest.stage === 'design'
    ? manifest.expectedBaselines.baseDependencyRecords
    : manifest.expectedBaselines.strictDependencyRecords;
  if (!Array.isArray(dependency) || dependency.length !== expectedDependencyRecords) {
    throw new Error('R7 dependency baseline drift detected');
  }
  const actualDependencyKeys = dependency.map(dependencyKey).sort();
  const expectedDependencyKeys = manifest.stage === 'design'
    ? EXPECTED_BASE_DEPENDENCY_KEYS
    : EXPECTED_BASE_DEPENDENCY_KEYS.filter(
      (key) => !manifest.historicalHandoffs.retiredDependencyKeys.includes(key),
    );
  assertExact(actualDependencyKeys, expectedDependencyKeys, 'R7 dependency identity');
  const debt = actualDependencyKeys
    .filter((key) => manifest.historicalHandoffs.retiredDependencyKeys.includes(key));
  assertExact(
    debt,
    manifest.stage === 'design' ? manifest.historicalHandoffs.retiredDependencyKeys : [],
    'R7 dependency handoff',
  );

  const ownership = JSON.parse(fs.readFileSync(path.join(
    repositoryRoot,
    'backend',
    'architecture',
    'ownership-baseline.json',
  ), 'utf8'));
  if (!ownership || !Array.isArray(ownership.violations)
      || ownership.violations.length !== manifest.expectedBaselines.baseOwnershipRecords) {
    throw new Error('R7 ownership baseline drift detected');
  }
  const total = ownership.violations.reduce((sum, record) => sum + record.count, 0);
  if (total !== manifest.expectedBaselines.baseOwnershipOccurrences) {
    throw new Error('R7 ownership occurrence drift detected');
  }
  const targetPaths = stageTargetPaths(manifest);
  for (const [projectionIndex, projection]
    of manifest.historicalHandoffs.ownershipProjection.entries()) {
    const activePath = targetPaths.has(projection.to) ? projection.to : projection.from;
    const records = ownership.violations.filter((record) => record.file === activePath);
    const occurrences = records.reduce((sum, record) => sum + record.count, 0);
    if (records.length !== projection.records || occurrences !== projection.occurrences) {
      throw new Error('R7 ownership handoff drift detected');
    }
    const inactivePath = activePath === projection.from ? projection.to : projection.from;
    if (ownership.violations.some((record) => record.file === inactivePath)) {
      throw new Error('R7 ownership handoff retains an inactive path');
    }
    const semanticRecords = records.map((record) => ({
      ...record,
      key: String(record.key).replace(activePath, '#source'),
      file: '#source',
    }));
    const semanticHash = crypto.createHash('sha256')
      .update(JSON.stringify(semanticRecords))
      .digest('hex');
    if (semanticHash !== EXPECTED_OWNERSHIP_SEMANTIC_HASHES[projectionIndex]) {
      throw new Error('R7 ownership semantic drift detected');
    }
  }
  const expectedOwnership = expectedOwnershipBaseline(repositoryRoot, manifest, targetPaths);
  if (JSON.stringify(ownership) !== JSON.stringify(expectedOwnership)) {
    throw new Error('R7 ownership baseline identity drift detected');
  }
  return Object.freeze({
    dependencyRecords: dependency.length,
    ownershipRecords: ownership.violations.length,
    ownershipOccurrences: total,
  });
}

function expectedOwnershipBaseline(repositoryRoot, manifest, targetPaths) {
  const scannerRepositoryRoot = path.resolve(__dirname, '..', '..', '..');
  const gitRoot = [repositoryRoot, scannerRepositoryRoot].find((candidate) => (
    fs.existsSync(path.join(candidate, '.git'))
  ));
  if (!gitRoot) throw new Error('R7 immutable ownership baseline is unavailable');
  let historical;
  try {
    historical = JSON.parse(execFileSync(
      'git',
      ['show', `${manifest.baseRevision}:backend/architecture/ownership-baseline.json`],
      {
        cwd: gitRoot,
        encoding: 'utf8',
        windowsHide: true,
        stdio: ['ignore', 'pipe', 'ignore'],
      },
    ));
  } catch {
    throw new Error('R7 immutable ownership baseline is unavailable');
  }
  if (!historical || !Array.isArray(historical.violations)) {
    throw new Error('R7 immutable ownership baseline is invalid');
  }
  const expected = structuredClone(historical);
  for (const projection of manifest.historicalHandoffs.ownershipProjection) {
    if (!targetPaths.has(projection.to)) continue;
    for (const record of expected.violations) {
      if (record.file !== projection.from) continue;
      record.file = projection.to;
      record.key = String(record.key).replace(projection.from, projection.to);
    }
  }
  expected.violations.sort((left, right) => (
    left.key < right.key ? -1 : left.key > right.key ? 1 : 0
  ));
  return expected;
}

function activeMovePath(repositoryRoot, manifest, targetPath) {
  const move = manifest.moves.find((entry) => entry.to === targetPath);
  if (!move) throw new Error('R7 source contract target is outside the move map');
  const sourceExists = inspectExistingPath(repositoryRoot, move.from, 'file').exists;
  const targetExists = inspectExistingPath(repositoryRoot, move.to, 'file').exists;
  if (sourceExists === targetExists) {
    throw new Error('R7 source contract path identity drift detected');
  }
  return sourceExists ? move.from : move.to;
}

function parseTypeScriptSource(repositoryRoot, relativePath) {
  const sourceText = fs.readFileSync(
    path.join(repositoryRoot, ...relativePath.split('/')),
    'utf8',
  );
  const sourceFile = ts.createSourceFile(
    relativePath,
    sourceText,
    ts.ScriptTarget.Latest,
    true,
    ts.ScriptKind.TS,
  );
  if (sourceFile.parseDiagnostics.length > 0) {
    throw new Error('R7 TypeScript source could not be parsed');
  }
  return sourceFile;
}

function normalizeR7Source(relativePath, sourceText, manifest) {
  if (typeof sourceText !== 'string') throw new Error('R7 source parity input is invalid');
  let normalized = sourceText.replace(/\r\n/gu, '\n');
  const sourceFile = ts.createSourceFile(
    relativePath,
    normalized,
    ts.ScriptTarget.Latest,
    true,
    ts.ScriptKind.TS,
  );
  if (sourceFile.parseDiagnostics.length > 0) {
    throw new Error('R7 TypeScript source could not be parsed');
  }
  const aliases = new Map();
  for (const move of manifest.moves) {
    aliases.set(move.from.replace(/\.ts$/u, ''), move.to.replace(/\.ts$/u, ''));
    aliases.set(move.to.replace(/\.ts$/u, ''), move.to.replace(/\.ts$/u, ''));
  }
  const replacements = [];
  for (const statement of sourceFile.statements) {
    if ((!ts.isImportDeclaration(statement) && !ts.isExportDeclaration(statement))
        || !statement.moduleSpecifier
        || !ts.isStringLiteralLike(statement.moduleSpecifier)
        || !statement.moduleSpecifier.text.startsWith('.')) continue;
    const resolved = path.posix.normalize(path.posix.join(
      path.posix.dirname(relativePath),
      statement.moduleSpecifier.text,
    ));
    const canonical = aliases.get(resolved) || resolved;
    replacements.push(Object.freeze({
      start: statement.moduleSpecifier.getStart(sourceFile) + 1,
      end: statement.moduleSpecifier.getEnd() - 1,
      value: `#r7/${canonical}`,
    }));
  }
  for (const replacement of replacements.sort((left, right) => right.start - left.start)) {
    normalized = normalized.slice(0, replacement.start)
      + replacement.value
      + normalized.slice(replacement.end);
  }
  return normalized;
}

function verifySourceParity(repositoryRoot, manifest) {
  for (const parity of manifest.sourceParity) {
    const activePath = activeMovePath(repositoryRoot, manifest, parity.to);
    const sourceText = fs.readFileSync(
      path.join(repositoryRoot, ...activePath.split('/')),
      'utf8',
    );
    const fingerprint = crypto.createHash('sha256')
      .update(normalizeR7Source(activePath, sourceText, manifest))
      .digest('hex');
    if (fingerprint !== parity.normalizedSha256) {
      throw new Error('R7 normalized source parity drift detected');
    }
  }
  return Object.freeze({ files: manifest.sourceParity.length });
}

function decoratorsOf(node) {
  return ts.canHaveDecorators(node) ? (ts.getDecorators(node) || []) : [];
}

function decoratorName(decorator, sourceFile) {
  const expression = decorator.expression;
  if (!ts.isCallExpression(expression)) return expression.getText(sourceFile);
  return expression.expression.getText(sourceFile);
}

function isExported(node) {
  return ts.canHaveModifiers(node)
    && (ts.getModifiers(node) || []).some((modifier) => modifier.kind === ts.SyntaxKind.ExportKeyword);
}

function exportedNames(statement, sourceFile) {
  if (!isExported(statement)) return [];
  if ((ts.isFunctionDeclaration(statement) || ts.isClassDeclaration(statement)
      || ts.isInterfaceDeclaration(statement) || ts.isTypeAliasDeclaration(statement)
      || ts.isEnumDeclaration(statement)) && statement.name) {
    return [statement.name.text];
  }
  if (ts.isVariableStatement(statement)) {
    return statement.declarationList.declarations.map((declaration) => declaration.name.getText(sourceFile));
  }
  return ['<unsupported-export>'];
}

function verifyPublicSnapshotSource(repositoryRoot, manifest) {
  const activePath = activeMovePath(
    repositoryRoot,
    manifest,
    manifest.publicSnapshotContract.path,
  );
  const sourceFile = parseTypeScriptSource(repositoryRoot, activePath);
  let dynamicDependencies = 0;
  const visit = (node) => {
    if (ts.isImportEqualsDeclaration(node)
        || (ts.isCallExpression(node)
          && ((ts.isIdentifier(node.expression) && node.expression.text === 'require')
            || node.expression.kind === ts.SyntaxKind.ImportKeyword))) {
      dynamicDependencies += 1;
    }
    ts.forEachChild(node, visit);
  };
  visit(sourceFile);
  if (dynamicDependencies !== 0) {
    throw new Error('R7 public snapshot dynamic dependency drift detected');
  }
  const imports = sourceFile.statements
    .filter(ts.isImportDeclaration)
    .map((statement) => statement.moduleSpecifier.text)
    .sort();
  assertExact(imports, EXPECTED_PUBLIC_SNAPSHOT_IMPORTS, 'R7 public snapshot imports');
  const exports = sourceFile.statements
    .flatMap((statement) => exportedNames(statement, sourceFile))
    .sort();
  assertExact(exports, [...manifest.publicSnapshotContract.exports].sort(), 'R7 public snapshot exports');
  return Object.freeze({ exports: exports.length, imports: imports.length });
}

function verifyPublicSnapshotConsumers(repositoryRoot) {
  const publicSnapshotActive = fs.existsSync(path.join(
    repositoryRoot,
    ...EXPECTED_PUBLIC_SNAPSHOT_CONTRACT.path.split('/'),
  ));
  const expected = EXPECTED_PUBLIC_SNAPSHOT_CONSUMERS.map((entry) => {
    if (!publicSnapshotActive) {
      if (entry.path === 'backend/src/contribution-history/contribution-history.service.ts') {
        return { ...entry, specifier: './contribution-snapshot.builder' };
      }
      if (entry.path.startsWith('backend/test/')) {
        return {
          ...entry,
          specifier: '../src/contribution-history/contribution-snapshot.builder',
        };
      }
      return {
        ...entry,
        specifier: '../contribution-history/contribution-snapshot.builder',
      };
    }
    if (entry.path === 'backend/src/contribution-history/contribution-history.service.ts'
        && !fs.existsSync(path.join(repositoryRoot, ...entry.path.split('/')))) {
      return {
        ...entry,
        path: 'backend/src/modules/collaboration/internal/contribution-history.service.ts',
        specifier: '../public/contribution-snapshot.builder',
      };
    }
    if (entry.path === 'backend/src/sharing/sharing.service.ts'
        && !fs.existsSync(path.join(repositoryRoot, ...entry.path.split('/')))) {
      return {
        ...entry,
        path: 'backend/src/modules/collaboration/internal/sharing.service.ts',
        specifier: '../public/contribution-snapshot.builder',
      };
    }
    return entry;
  }).sort((left, right) => left.path.localeCompare(right.path));
  const actual = [];
  const builderTargets = new Set([
    'backend/src/contribution-history/contribution-snapshot.builder',
    'backend/src/modules/collaboration/public/contribution-snapshot.builder',
  ]);
  for (const root of ['backend/src', 'backend/test']) {
    for (const relativePath of listPlainFiles(repositoryRoot, root).filter(
      (entry) => entry.endsWith('.ts'),
    )) {
      const sourceText = fs.readFileSync(
        path.join(repositoryRoot, ...relativePath.split('/')),
        'utf8',
      );
      if (!sourceText.includes('contribution-snapshot.builder')) continue;
      const sourceFile = parseTypeScriptSource(repositoryRoot, relativePath);
      const isBuilderSpecifier = (specifier) => {
        if (typeof specifier !== 'string') return false;
        const resolved = resolvedImportPath(relativePath, specifier);
        return resolved !== null && builderTargets.has(resolved);
      };
      const rejectNonCanonicalForm = (specifier) => {
        if (isBuilderSpecifier(specifier)) {
          throw new Error('R7 public snapshot non-canonical consumer form detected');
        }
      };
      for (const statement of sourceFile.statements) {
        if (ts.isImportDeclaration(statement)
            && ts.isStringLiteralLike(statement.moduleSpecifier)
            && isBuilderSpecifier(statement.moduleSpecifier.text)) {
          const clause = statement.importClause;
          const bindings = clause && clause.namedBindings;
          if (!clause || clause.isTypeOnly || clause.name
              || !bindings || !ts.isNamedImports(bindings)
              || bindings.elements.some((element) => element.isTypeOnly)) {
            throw new Error('R7 public snapshot non-canonical consumer form detected');
          }
          actual.push({
            path: relativePath,
            specifier: statement.moduleSpecifier.text,
            names: bindings.elements.map((element) => element.name.text).sort(),
          });
        } else if (ts.isExportDeclaration(statement)
            && statement.moduleSpecifier
            && ts.isStringLiteralLike(statement.moduleSpecifier)) {
          rejectNonCanonicalForm(statement.moduleSpecifier.text);
        } else if (ts.isImportEqualsDeclaration(statement)
            && ts.isExternalModuleReference(statement.moduleReference)
            && statement.moduleReference.expression
            && ts.isStringLiteralLike(statement.moduleReference.expression)) {
          rejectNonCanonicalForm(statement.moduleReference.expression.text);
        }
      }
      const visit = (node) => {
        if (ts.isCallExpression(node)
            && ((ts.isIdentifier(node.expression) && node.expression.text === 'require')
              || node.expression.kind === ts.SyntaxKind.ImportKeyword)
            && node.arguments.length === 1
            && ts.isStringLiteralLike(node.arguments[0])) {
          rejectNonCanonicalForm(node.arguments[0].text);
        } else if (ts.isImportTypeNode(node)
            && ts.isLiteralTypeNode(node.argument)
            && ts.isStringLiteralLike(node.argument.literal)) {
          rejectNonCanonicalForm(node.argument.literal.text);
        }
        ts.forEachChild(node, visit);
      };
      visit(sourceFile);
    }
  }
  actual.sort((left, right) => left.path.localeCompare(right.path));
  assertExact(actual, expected, 'R7 public snapshot consumers');
  return Object.freeze({
    callers: actual.filter((entry) => entry.path.startsWith('backend/src/')).length,
    testImports: actual.filter((entry) => entry.path.startsWith('backend/test/')).length,
  });
}

function verifyConstructorHandoffs(repositoryRoot, manifest) {
  const sourceFiles = new Map();
  let optional = 0;
  let optionalSyntax = 0;
  for (const move of manifest.moves) {
    const activePath = activeMovePath(repositoryRoot, manifest, move.to);
    const sourceFile = parseTypeScriptSource(repositoryRoot, activePath);
    sourceFiles.set(move.to, sourceFile);
    const visit = (node) => {
      optional += decoratorsOf(node)
        .filter((decorator) => decoratorName(decorator, sourceFile) === 'Optional')
        .length;
      ts.forEachChild(node, visit);
    };
    visit(sourceFile);
    for (const classNode of sourceFile.statements.filter(ts.isClassDeclaration)) {
      for (const constructorNode of classNode.members.filter(ts.isConstructorDeclaration)) {
        for (const parameter of constructorNode.parameters) {
          if (parameter.initializer) {
            throw new Error('R7 constructor default drift detected');
          }
          let typeContainsUndefined = false;
          if (parameter.type) {
            const visitType = (node) => {
              if (node.kind === ts.SyntaxKind.UndefinedKeyword) typeContainsUndefined = true;
              ts.forEachChild(node, visitType);
            };
            visitType(parameter.type);
          }
          if (parameter.questionToken || typeContainsUndefined) optionalSyntax += 1;
        }
      }
    }
  }

  for (const consumer of manifest.historicalHandoffs.constructorConsumers) {
    const sourceFile = sourceFiles.get(consumer.to);
    const classNode = sourceFile.statements.find((statement) => (
      ts.isClassDeclaration(statement)
      && statement.name
      && statement.name.text === consumer.consumerClass
    ));
    const constructors = classNode
      ? classNode.members.filter(ts.isConstructorDeclaration)
      : [];
    if (constructors.length !== 1) {
      throw new Error('R7 constructor class drift detected');
    }
    const parameter = constructors[0].parameters[consumer.parameterIndex];
    if (!parameter || parameter.name.getText(sourceFile) !== consumer.parameter) {
      throw new Error('R7 constructor parameter drift detected');
    }
    const decorators = decoratorsOf(parameter);
    const names = decorators.map((decorator) => decoratorName(decorator, sourceFile));
    const frozen = manifest.frozenOptionalDependencies.find((entry) => (
      entry.to === consumer.to
      && entry.consumerClass === consumer.consumerClass
      && entry.parameterIndex === consumer.parameterIndex
    ));
    const expectedNames = frozen ? ['Optional', 'Inject'] : ['Inject'];
    if (JSON.stringify(names) !== JSON.stringify(expectedNames)) {
      throw new Error('R7 constructor optionality drift detected');
    }
    const inject = decorators.find((decorator) => decoratorName(decorator, sourceFile) === 'Inject');
    const expression = inject && inject.expression;
    if (!expression || !ts.isCallExpression(expression)
        || expression.arguments.length !== 1
        || expression.arguments[0].getText(sourceFile) !== consumer.token) {
      throw new Error('R7 constructor injection drift detected');
    }
    if (Boolean(parameter.questionToken) !== Boolean(frozen)) {
      throw new Error('R7 constructor optionality drift detected');
    }
  }
  if (optional !== manifest.frozenOptionalDependencies.length
      || optionalSyntax !== manifest.frozenOptionalDependencies.length) {
    throw new Error('R7 constructor optionality drift detected');
  }
  return Object.freeze({
    consumers: manifest.historicalHandoffs.constructorConsumers.length,
    optional,
  });
}

function controllerInventory(sourceFile) {
  const classes = sourceFile.statements
    .filter(ts.isClassDeclaration)
    .map((classNode) => ({
      class: classNode.name ? classNode.name.text : '<anonymous>',
      decorators: decoratorsOf(classNode).map((decorator) => decorator.expression.getText(sourceFile)),
      methods: classNode.members.filter(ts.isMethodDeclaration).map((method) => ({
        name: method.name.getText(sourceFile),
        decorators: decoratorsOf(method).map((decorator) => decorator.expression.getText(sourceFile)),
        params: method.parameters.map((parameter) => (
          decoratorsOf(parameter).map((decorator) => decorator.expression.getText(sourceFile))
        )),
      })),
    }));
  const operations = classes.reduce((sum, entry) => sum + entry.methods.length, 0);
  const fingerprint = crypto.createHash('sha256')
    .update(JSON.stringify(classes))
    .digest('hex');
  return { operations, fingerprint };
}

function verifyControllerHandoffs(repositoryRoot, manifest) {
  let operations = 0;
  for (const expected of EXPECTED_CONTROLLER_INVENTORIES) {
    if (!manifest.historicalHandoffs.controllerSources.some((entry) => entry.to === expected.target)) {
      throw new Error('R7 controller handoff drift detected');
    }
    const activePath = activeMovePath(repositoryRoot, manifest, expected.target);
    const actual = controllerInventory(parseTypeScriptSource(repositoryRoot, activePath));
    assertExact(actual, {
      operations: expected.operations,
      fingerprint: expected.fingerprint,
    }, 'R7 controller inventory');
    operations += actual.operations;
  }
  return Object.freeze({ controllers: EXPECTED_CONTROLLER_INVENTORIES.length, operations });
}

function importedSpecifier(sourceFile, importedName) {
  for (const statement of sourceFile.statements.filter(ts.isImportDeclaration)) {
    if (!ts.isStringLiteralLike(statement.moduleSpecifier) || !statement.importClause) continue;
    if (statement.importClause.name?.text === importedName) return statement.moduleSpecifier.text;
    const bindings = statement.importClause.namedBindings;
    if (bindings && ts.isNamedImports(bindings)
        && bindings.elements.some((element) => element.name.text === importedName)) {
      return statement.moduleSpecifier.text;
    }
  }
  return null;
}

function classModuleMetadata(sourceFile, className) {
  const classNode = sourceFile.statements.find((statement) => (
    ts.isClassDeclaration(statement) && statement.name?.text === className
  ));
  if (!classNode) throw new Error('R7 history provider identity drift detected');
  const moduleDecorator = decoratorsOf(classNode).find(
    (decorator) => decoratorName(decorator, sourceFile) === 'Module',
  );
  const expression = moduleDecorator?.expression;
  if (!expression || !ts.isCallExpression(expression)
      || expression.arguments.length !== 1
      || !ts.isObjectLiteralExpression(expression.arguments[0])) {
    throw new Error('R7 history module wiring drift detected');
  }
  const metadata = new Map();
  for (const property of expression.arguments[0].properties) {
    if (!ts.isPropertyAssignment(property) || !ts.isIdentifier(property.name)
        || !ts.isArrayLiteralExpression(property.initializer)) continue;
    metadata.set(
      property.name.text,
      property.initializer.elements.map((element) => element.getText(sourceFile)
        .replace(/\s+/gu, '')),
    );
  }
  return metadata;
}

function unwrapProviderExpression(expression) {
  let current = expression;
  while (ts.isParenthesizedExpression(current)
      || ts.isAsExpression(current)
      || ts.isTypeAssertionExpression(current)
      || ts.isNonNullExpression(current)
      || (ts.isSatisfiesExpression && ts.isSatisfiesExpression(current))) {
    current = current.expression;
  }
  return current;
}

function sharingProviderTopology(repositoryRoot) {
  const sourcePaths = listPlainFiles(repositoryRoot, 'backend/src')
    .filter((entry) => entry.endsWith('.ts'));
  const absolutePaths = sourcePaths.map((relativePath) => (
    path.join(repositoryRoot, ...relativePath.split('/'))
  ));
  const program = ts.createProgram(absolutePaths, {
    experimentalDecorators: true,
    module: ts.ModuleKind.CommonJS,
    moduleResolution: ts.ModuleResolutionKind.Node10,
    noEmit: true,
    skipLibCheck: true,
    target: ts.ScriptTarget.Latest,
  });
  const checker = program.getTypeChecker();
  const sourceByPath = new Map(sourcePaths.map((relativePath, index) => [
    relativePath,
    program.getSourceFile(absolutePaths[index]),
  ]));
  const providerDeclarations = [
    ['backend/src/modules/collaboration/internal/sharing.service.ts', 'SharingService'],
    ['backend/src/modules/collaboration/internal/invitation-delivery.service.ts', 'InvitationDeliveryService'],
    ['backend/src/modules/collaboration/internal/invite-access.service.ts', 'InviteAccessService'],
    ['backend/src/modules/collaboration/internal/permission.service.ts', 'PermissionService'],
  ];
  const providerBySymbol = new Map();
  for (const [relativePath, provider] of providerDeclarations) {
    const sourceFile = sourceByPath.get(relativePath);
    const classNode = sourceFile?.statements.find((statement) => (
      ts.isClassDeclaration(statement) && statement.name?.text === provider
    ));
    const symbol = classNode?.name && checker.getSymbolAtLocation(classNode.name);
    if (!symbol) throw new Error('R7 Sharing provider identity drift detected');
    providerBySymbol.set(symbol, provider);
  }

  const dereferenceAlias = (symbol) => {
    const seen = new Set();
    let current = symbol;
    while (current && (current.flags & ts.SymbolFlags.Alias) !== 0) {
      if (seen.has(current)) return current;
      seen.add(current);
      const target = checker.getAliasedSymbol(current);
      if (!target || target === current) return current;
      current = target;
    }
    return current;
  };
  const propertyName = (name) => (
    ts.isIdentifier(name) || ts.isStringLiteralLike(name) || ts.isNumericLiteral(name)
      ? name.text
      : null
  );
  const frozenArgument = (expression) => {
    const current = unwrapProviderExpression(expression);
    if (!ts.isCallExpression(current) || current.arguments.length !== 1) return null;
    const target = unwrapProviderExpression(current.expression);
    return ts.isPropertyAccessExpression(target)
      && ts.isIdentifier(target.expression)
      && target.expression.text === 'Object'
      && target.name.text === 'freeze'
      ? current.arguments[0]
      : null;
  };
  function bindingPatternSources(pattern, seenSymbols, seenNodes) {
    const owner = pattern.parent;
    if (ts.isVariableDeclaration(owner) && owner.initializer) {
      return [{
        expression: owner.initializer,
        seenSymbols: new Set(seenSymbols),
        seenNodes: new Set(seenNodes),
      }];
    }
    if (ts.isBindingElement(owner)) {
      return bindingElementValues(owner, seenSymbols, seenNodes);
    }
    return [];
  }
  function objectPropertyValues(expression, key, seenSymbols, seenNodes) {
    const values = [];
    const resolvedExpressions = concreteExpressions(expression, seenSymbols, seenNodes);
    if (resolvedExpressions.length === 0) {
      throw new Error('R7 Sharing provider topology could not resolve provider identity');
    }
    for (const resolved of resolvedExpressions) {
      const target = resolved.expression;
      if (!ts.isObjectLiteralExpression(target)) {
        throw new Error('R7 Sharing provider topology could not resolve provider identity');
      }
      for (const property of target.properties) {
        if (ts.isPropertyAssignment(property) && propertyName(property.name) === key) {
          values.push({
            expression: property.initializer,
            seenSymbols: new Set(resolved.seenSymbols),
            seenNodes: new Set(resolved.seenNodes),
          });
        } else if (ts.isShorthandPropertyAssignment(property)
            && property.name.text === key) {
          values.push({
            expression: property.name,
            seenSymbols: new Set(resolved.seenSymbols),
            seenNodes: new Set(resolved.seenNodes),
          });
        } else if (ts.isSpreadAssignment(property)) {
          values.push(...objectPropertyValues(
            property.expression,
            key,
            new Set(resolved.seenSymbols),
            new Set(resolved.seenNodes),
          ));
        }
      }
    }
    return values;
  }
  function arrayElementValues(expression, index, seenSymbols, seenNodes) {
    const values = [];
    const resolvedExpressions = concreteExpressions(expression, seenSymbols, seenNodes);
    if (resolvedExpressions.length === 0) {
      throw new Error('R7 Sharing provider topology could not resolve provider identity');
    }
    for (const resolved of resolvedExpressions) {
      const target = resolved.expression;
      if (!ts.isArrayLiteralExpression(target)) {
        throw new Error('R7 Sharing provider topology could not resolve provider identity');
      }
      const element = target.elements[index];
      if (element && !ts.isOmittedExpression(element) && !ts.isSpreadElement(element)) {
        values.push({
          expression: element,
          seenSymbols: new Set(resolved.seenSymbols),
          seenNodes: new Set(resolved.seenNodes),
        });
      }
    }
    return values;
  }
  function bindingElementValues(declaration, seenSymbols, seenNodes) {
    const pattern = declaration.parent;
    const sources = ts.isObjectBindingPattern(pattern) || ts.isArrayBindingPattern(pattern)
      ? bindingPatternSources(pattern, seenSymbols, seenNodes)
      : [];
    const values = declaration.initializer
      ? [{
        expression: declaration.initializer,
        seenSymbols: new Set(seenSymbols),
        seenNodes: new Set(seenNodes),
      }]
      : [];
    if (ts.isObjectBindingPattern(pattern)) {
      const key = declaration.propertyName
        ? propertyName(declaration.propertyName)
        : propertyName(declaration.name);
      if (key !== null) {
        for (const source of sources) {
          values.push(...objectPropertyValues(
            source.expression,
            key,
            new Set(source.seenSymbols),
            new Set(source.seenNodes),
          ));
        }
      }
    } else if (ts.isArrayBindingPattern(pattern)) {
      const index = pattern.elements.indexOf(declaration);
      for (const source of sources) {
        values.push(...arrayElementValues(
          source.expression,
          index,
          new Set(source.seenSymbols),
          new Set(source.seenNodes),
        ));
      }
    }
    return values;
  }
  function symbolValues(symbol, seenSymbols = new Set(), seenNodes = new Set()) {
    const current = dereferenceAlias(symbol);
    if (!current || seenSymbols.has(current)) return [];
    const nextSymbols = new Set(seenSymbols);
    nextSymbols.add(current);
    const values = [];
    for (const declaration of current.declarations || []) {
      if ((ts.isVariableDeclaration(declaration) || ts.isPropertyAssignment(declaration))
          && declaration.initializer) {
        values.push({
          expression: declaration.initializer,
          seenSymbols: new Set(nextSymbols),
          seenNodes: new Set(seenNodes),
        });
      } else if (ts.isShorthandPropertyAssignment(declaration)) {
        const valueSymbol = checker.getShorthandAssignmentValueSymbol(declaration);
        values.push(...symbolValues(valueSymbol, nextSymbols, new Set(seenNodes)));
      } else if (ts.isBindingElement(declaration)) {
        values.push(...bindingElementValues(declaration, nextSymbols, new Set(seenNodes)));
      }
    }
    return values;
  }
  function concreteExpressions(expression, seenSymbols = new Set(), seenNodes = new Set()) {
    const current = unwrapProviderExpression(expression);
    if (seenNodes.has(current)) return [];
    const nextNodes = new Set(seenNodes);
    nextNodes.add(current);
    const frozen = frozenArgument(current);
    if (frozen) return concreteExpressions(frozen, seenSymbols, nextNodes);
    if (ts.isIdentifier(current) || ts.isPropertyAccessExpression(current)) {
      const symbol = dereferenceAlias(checker.getSymbolAtLocation(current));
      if (symbol && seenSymbols.has(symbol)) return [];
      const values = symbolValues(symbol, seenSymbols, nextNodes);
      if (values.length > 0) {
        return values.flatMap((value) => concreteExpressions(
          value.expression,
          new Set(value.seenSymbols),
          new Set(value.seenNodes),
        ));
      }
    }
    return [{
      expression: current,
      seenSymbols: new Set(seenSymbols),
      seenNodes: nextNodes,
    }];
  }
  function providerIdentityFromSymbol(symbol, seenSymbols = new Set(), seenNodes = new Set()) {
    const current = dereferenceAlias(symbol);
    if (!current) return null;
    if (providerBySymbol.has(current)) return providerBySymbol.get(current);
    if (seenSymbols.has(current)) return null;
    const nextSymbols = new Set(seenSymbols);
    nextSymbols.add(current);
    for (const declaration of current.declarations || []) {
      if (ts.isShorthandPropertyAssignment(declaration)) {
        const valueSymbol = checker.getShorthandAssignmentValueSymbol(declaration);
        const identity = providerIdentityFromSymbol(
          valueSymbol,
          nextSymbols,
          new Set(seenNodes),
        );
        if (identity) return identity;
      }
    }
    for (const value of symbolValues(current, seenSymbols, seenNodes)) {
      const identity = providerIdentity(
        value.expression,
        new Set(value.seenSymbols),
        new Set(value.seenNodes),
      );
      if (identity) return identity;
    }
    return null;
  }
  function providerIdentity(expression, seenSymbols = new Set(), seenNodes = new Set()) {
    const current = unwrapProviderExpression(expression);
    if (seenNodes.has(current)) return null;
    const nextNodes = new Set(seenNodes);
    nextNodes.add(current);
    const frozen = frozenArgument(current);
    if (frozen) return providerIdentity(frozen, seenSymbols, nextNodes);
    const symbolCandidates = [checker.getSymbolAtLocation(current)];
    const type = checker.getTypeAtLocation(current);
    symbolCandidates.push(type?.aliasSymbol, type?.symbol);
    for (const symbol of symbolCandidates) {
      const identity = providerIdentityFromSymbol(symbol, seenSymbols, nextNodes);
      if (identity) return identity;
    }
    return null;
  }
  const references = [];
  const recordReference = (expression, registration, kind) => {
    const provider = providerIdentity(expression);
    if (provider) references.push(Object.freeze({ ...registration, kind, provider }));
    return Boolean(provider);
  };
  const resolutionTrail = (expression, seen, error) => {
    const current = unwrapProviderExpression(expression);
    const symbol = (ts.isIdentifier(current) || ts.isPropertyAccessExpression(current))
      ? dereferenceAlias(checker.getSymbolAtLocation(current))
      : null;
    const key = symbol || current;
    if (seen.has(key)) throw new Error(error);
    const next = new Set(seen);
    next.add(key);
    return next;
  };
  let inspectProviderObject;
  const inspectProviderEntry = (expression, registration, seen = new Set()) => {
    const nextSeen = resolutionTrail(
      expression,
      seen,
      'R7 Sharing provider topology could not resolve provider entry',
    );
    const targets = concreteExpressions(expression);
    if (targets.length === 0) {
      throw new Error('R7 Sharing provider topology could not resolve provider entry');
    }
    for (const resolved of targets) {
      const current = resolved.expression;
      if (recordReference(current, registration, 'bare')) continue;
      if (ts.isObjectLiteralExpression(current)) {
        const objectSeen = current === unwrapProviderExpression(expression) ? seen : nextSeen;
        inspectProviderObject(current, registration, new Set(objectSeen));
      } else if (ts.isConditionalExpression(current)) {
        inspectProviderEntry(current.whenTrue, registration, new Set(nextSeen));
        inspectProviderEntry(current.whenFalse, registration, new Set(nextSeen));
      }
    }
  };
  inspectProviderObject = (expression, registration, seen = new Set()) => {
    const nextSeen = resolutionTrail(
      expression,
      seen,
      'R7 Sharing provider topology could not resolve object spread',
    );
    const targets = concreteExpressions(expression);
    if (targets.length === 0) {
      throw new Error('R7 Sharing provider topology could not resolve object spread');
    }
    for (const resolved of targets) {
      const target = resolved.expression;
      if (!ts.isObjectLiteralExpression(target)) {
        throw new Error('R7 Sharing provider topology could not resolve object spread');
      }
      for (const property of target.properties) {
        if (ts.isSpreadAssignment(property)) {
          inspectProviderObject(property.expression, registration, new Set(nextSeen));
          continue;
        }
        if (ts.isPropertyAssignment(property)) {
          const kind = propertyName(property.name);
          if (kind === 'provide' || kind === 'useClass' || kind === 'useExisting') {
            recordReference(property.initializer, registration, kind);
          }
        } else if (ts.isShorthandPropertyAssignment(property)) {
          const kind = property.name.text;
          if (kind === 'provide' || kind === 'useClass' || kind === 'useExisting') {
            recordReference(property.name, registration, kind);
          }
        }
      }
    }
  };
  const inspectProviderCollection = (expression, registration, seen = new Set()) => {
    const nextSeen = resolutionTrail(
      expression,
      seen,
      'R7 Sharing provider topology could not resolve providers spread',
    );
    const targets = concreteExpressions(expression);
    if (targets.length === 0) {
      throw new Error('R7 Sharing provider topology could not resolve providers spread');
    }
    for (const resolved of targets) {
      const current = resolved.expression;
      if (ts.isArrayLiteralExpression(current)) {
        for (const element of current.elements) {
          if (ts.isSpreadElement(element)) {
            inspectProviderCollection(element.expression, registration, new Set(nextSeen));
          } else {
            inspectProviderEntry(element, registration, new Set(nextSeen));
          }
        }
      } else if (ts.isConditionalExpression(current)) {
        inspectProviderCollection(current.whenTrue, registration, new Set(nextSeen));
        inspectProviderCollection(current.whenFalse, registration, new Set(nextSeen));
      } else {
        throw new Error('R7 Sharing provider topology could not resolve providers spread');
      }
    }
  };
  const inspectModuleMetadata = (expression, registration, seen = new Set()) => {
    const nextSeen = resolutionTrail(
      expression,
      seen,
      'R7 Sharing provider topology could not resolve module metadata',
    );
    const targets = concreteExpressions(expression);
    if (targets.length === 0) {
      throw new Error('R7 Sharing provider topology could not resolve module metadata');
    }
    for (const resolved of targets) {
      const current = resolved.expression;
      if (!ts.isObjectLiteralExpression(current)) {
        throw new Error('R7 Sharing provider topology could not resolve module metadata');
      }
      for (const property of current.properties) {
        if (ts.isPropertyAssignment(property) && propertyName(property.name) === 'providers') {
          inspectProviderCollection(property.initializer, registration);
        } else if (ts.isShorthandPropertyAssignment(property)
            && property.name.text === 'providers') {
          inspectProviderCollection(property.name, registration);
        } else if (ts.isSpreadAssignment(property)) {
          inspectModuleMetadata(property.expression, registration, new Set(nextSeen));
        }
      }
    }
  };

  for (const [relativePath, sourceFile] of sourceByPath) {
    if (!sourceFile) throw new Error('R7 TypeScript source could not be parsed');
    for (const classNode of sourceFile.statements.filter(ts.isClassDeclaration)) {
      const moduleDecorator = decoratorsOf(classNode).find(
        (decorator) => decoratorName(decorator, sourceFile) === 'Module',
      );
      const expression = moduleDecorator?.expression;
      if (!expression || !ts.isCallExpression(expression)) continue;
      if (expression.arguments.length !== 1) {
        throw new Error('R7 Sharing provider topology could not resolve module metadata');
      }
      inspectModuleMetadata(expression.arguments[0], {
        file: relativePath,
        module: classNode.name?.text || '<anonymous>',
      });
    }
  }

  const expected = [
    {
      file: 'backend/src/modules/collaboration/internal/collaboration-permission.internal.module.ts',
      module: 'CollaborationPermissionInternalModule',
      kind: 'bare',
      provider: 'PermissionService',
    },
    {
      file: 'backend/src/modules/collaboration/internal/collaboration-permission.internal.module.ts',
      module: 'CollaborationPermissionInternalModule',
      kind: 'useExisting',
      provider: 'PermissionService',
    },
    {
      file: 'backend/src/modules/collaboration/internal/collaboration-services.internal.module.ts',
      module: 'CollaborationServicesInternalModule',
      kind: 'bare',
      provider: 'InvitationDeliveryService',
    },
    {
      file: 'backend/src/modules/collaboration/internal/collaboration-services.internal.module.ts',
      module: 'CollaborationServicesInternalModule',
      kind: 'bare',
      provider: 'InviteAccessService',
    },
    {
      file: 'backend/src/modules/collaboration/internal/collaboration-services.internal.module.ts',
      module: 'CollaborationServicesInternalModule',
      kind: 'bare',
      provider: 'SharingService',
    },
  ];
  const sortReferences = (entries) => [...entries].sort((left, right) => (
    JSON.stringify(left).localeCompare(JSON.stringify(right))
  ));
  if (JSON.stringify(sortReferences(references)) !== JSON.stringify(sortReferences(expected))) {
    throw new Error('R7 Sharing provider singleton drift detected');
  }
  return Object.freeze({
    providers: new Set(references.filter((entry) => entry.kind === 'bare')
      .map((entry) => entry.provider)).size,
    aliases: references.filter((entry) => entry.kind === 'useExisting').length,
  });
}

function verifyHistoryRelocation(repositoryRoot, manifest) {
  const sharingServicePath = activeMovePath(
    repositoryRoot,
    manifest,
    'backend/src/modules/collaboration/internal/sharing.service.ts',
  );
  const sharingHistorySpecifier = sharingServicePath
    === 'backend/src/modules/collaboration/internal/sharing.service.ts'
    ? './contribution-history.service'
    : '../modules/collaboration/internal/contribution-history.service';
  const requiredImports = [
    ['backend/src/modules/collaboration/api/contribution-history.controller.ts', 'AuthenticatedUser', '../../identity/public/identity-session.types'],
    ['backend/src/modules/collaboration/api/contribution-history.controller.ts', 'CurrentUser', '../../identity/public/current-user.decorator'],
    ['backend/src/modules/collaboration/api/contribution-history.controller.ts', 'JwtAuthGuard', '../../identity/public/jwt-auth.guard'],
    ['backend/src/modules/collaboration/api/contribution-history.controller.ts', 'ContributionHistoryService', '../internal/contribution-history.service'],
    ['backend/src/modules/collaboration/api/contribution-history.controller.ts', 'ListContributionsDto', './dto/list-contributions.dto'],
    ['backend/src/modules/collaboration/internal/contribution-history.service.ts', 'AuthenticatedUser', '../../identity/public/identity-session.types'],
    ['backend/src/modules/collaboration/internal/contribution-history.service.ts', 'CollaborationHistoryPort', '../public/collaboration-history.port'],
    ['backend/src/modules/collaboration/internal/contribution-history.service.ts', 'livePlanAuthorizationWhere', '../public/collaboration-permission.port'],
    ['backend/src/modules/collaboration/internal/contribution-history.service.ts', 'runRetryableTransaction', '../../../platform/database/serializable-transaction'],
    ['backend/src/modules/collaboration/internal/contribution-history.service.ts', 'PrismaService', '../../../platform/database/prisma.service'],
    ['backend/src/modules/collaboration/internal/contribution-history.service.ts', 'canonicalJson', '../public/contribution-snapshot.builder'],
    ['backend/src/modules/collaboration/internal/contribution-history.service.ts', 'ContributionHistoryPageResponse', './contribution-history.contracts'],
    ['backend/src/modules/collaboration/internal/contribution-history.service.ts', 'ListContributionsDto', '../api/dto/list-contributions.dto'],
    ['backend/src/modules/collaboration/internal/contributor-scope.service.ts', 'CollaborationScopePort', '../public/collaboration-scope.port'],
    ['backend/src/modules/collaboration/internal/contributor-scope.service.ts', 'ContributionHistoryService', './contribution-history.service'],
    ['backend/src/modules/collaboration/collaboration.module.ts', 'ContributionHistoryController', './api/contribution-history.controller'],
    ['backend/src/modules/collaboration/internal/collaboration-history.internal.module.ts', 'ContributionHistoryService', './contribution-history.service'],
    ['backend/src/modules/collaboration/internal/collaboration-scope.internal.module.ts', 'ContributorScopeService', './contributor-scope.service'],
    [sharingServicePath, 'ContributionHistoryService', sharingHistorySpecifier],
  ];
  const parsed = new Map();
  for (const [relativePath, importedName, specifier] of requiredImports) {
    if (!parsed.has(relativePath)) {
      parsed.set(relativePath, parseTypeScriptSource(repositoryRoot, relativePath));
    }
    if (importedSpecifier(parsed.get(relativePath), importedName) !== specifier) {
      throw new Error('R7 history internal import drift detected');
    }
  }
  for (const [relativePath, className] of [
    ['backend/src/modules/collaboration/api/contribution-history.controller.ts', 'ContributionHistoryController'],
    ['backend/src/modules/collaboration/internal/contribution-history.service.ts', 'ContributionHistoryService'],
    ['backend/src/modules/collaboration/internal/contributor-scope.service.ts', 'ContributorScopeService'],
  ]) {
    const sourceFile = parsed.get(relativePath) || parseTypeScriptSource(repositoryRoot, relativePath);
    if (!sourceFile.statements.some((statement) => (
      ts.isClassDeclaration(statement) && statement.name?.text === className && isExported(statement)
    ))) {
      throw new Error('R7 history provider identity drift detected');
    }
  }
  const historyMetadata = classModuleMetadata(
    parsed.get('backend/src/modules/collaboration/internal/collaboration-history.internal.module.ts'),
    'CollaborationHistoryInternalModule',
  );
  const scopeMetadata = classModuleMetadata(
    parsed.get('backend/src/modules/collaboration/internal/collaboration-scope.internal.module.ts'),
    'CollaborationScopeInternalModule',
  );
  assertExact(historyMetadata.get('imports'), ['PrismaModule'], 'R7 history module imports');
  assertExact(historyMetadata.get('providers'), [
    'ContributionHistoryService',
    '{provide:COLLABORATION_HISTORY_IMPLEMENTATION,useExisting:ContributionHistoryService,}',
  ], 'R7 history module providers');
  assertExact(historyMetadata.get('exports'), [
    'ContributionHistoryService', 'COLLABORATION_HISTORY_IMPLEMENTATION',
  ], 'R7 history module exports');
  assertExact(scopeMetadata.get('imports'), [
    'CollaborationHistoryInternalModule',
  ], 'R7 scope module imports');
  assertExact(scopeMetadata.get('providers'), [
    'ContributorScopeService',
    '{provide:COLLABORATION_SCOPE_IMPLEMENTATION,useExisting:ContributorScopeService,}',
  ], 'R7 scope module providers');
  assertExact(scopeMetadata.get('exports'), [
    'ContributorScopeService', 'COLLABORATION_SCOPE_IMPLEMENTATION',
  ], 'R7 scope module exports');
  const collaborationMetadata = classModuleMetadata(
    parsed.get('backend/src/modules/collaboration/collaboration.module.ts'),
    'CollaborationModule',
  );
  if ((collaborationMetadata.get('controllers') || [])
    .filter((entry) => entry === 'ContributionHistoryController').length !== 1) {
    throw new Error('R7 history controller registration drift detected');
  }
  let legacyRuntimeImports = 0;
  for (const relativePath of listPlainFiles(repositoryRoot, 'backend/src')
    .filter((entry) => entry.endsWith('.ts'))) {
    const sourceFile = parseTypeScriptSource(repositoryRoot, relativePath);
    const inspectSpecifier = (specifier) => {
      const resolved = resolvedImportPath(relativePath, specifier);
      if (resolved?.startsWith('backend/src/contribution-history/')) legacyRuntimeImports += 1;
    };
    for (const statement of sourceFile.statements) {
      if ((ts.isImportDeclaration(statement) || ts.isExportDeclaration(statement))
          && statement.moduleSpecifier && ts.isStringLiteralLike(statement.moduleSpecifier)) {
        inspectSpecifier(statement.moduleSpecifier.text);
      }
    }
    const visit = (node) => {
      if (ts.isCallExpression(node)
          && ((ts.isIdentifier(node.expression) && node.expression.text === 'require')
            || node.expression.kind === ts.SyntaxKind.ImportKeyword)
          && node.arguments.length === 1 && ts.isStringLiteralLike(node.arguments[0])) {
        inspectSpecifier(node.arguments[0].text);
      }
      ts.forEachChild(node, visit);
    };
    visit(sourceFile);
  }
  if (legacyRuntimeImports !== 0) throw new Error('R7 history legacy runtime import drift detected');
  return Object.freeze({
    controllers: 1,
    providers: 2,
    aliases: 2,
    exports: 4,
    legacyRuntimeImports,
  });
}

function verifySharingRelocation(repositoryRoot, manifest) {
  const requiredImports = [
    ['backend/src/modules/collaboration/api/sharing.controller.ts', 'AuthenticatedUser', '../../identity/public/identity-session.types'],
    ['backend/src/modules/collaboration/api/sharing.controller.ts', 'CurrentUser', '../../identity/public/current-user.decorator'],
    ['backend/src/modules/collaboration/api/sharing.controller.ts', 'JwtAuthGuard', '../../identity/public/jwt-auth.guard'],
    ['backend/src/modules/collaboration/api/sharing.controller.ts', 'InviteAccessService', '../internal/invite-access.service'],
    ['backend/src/modules/collaboration/api/sharing.controller.ts', 'SharingService', '../internal/sharing.service'],
    ['backend/src/modules/collaboration/internal/invitation-delivery.service.ts', 'IDENTITY_TRANSIENT_DELIVERY_PORT', '../../identity/public/identity-transient-delivery.port'],
    ['backend/src/modules/collaboration/internal/invite-access.service.ts', 'IDENTITY_AUTH_PORT', '../../identity/public/identity-auth.port'],
    ['backend/src/modules/collaboration/internal/invite-access.service.ts', 'authError', '../../identity/public/auth-error'],
    ['backend/src/modules/collaboration/internal/permission.service.ts', 'AuthenticatedUser', '../../identity/public/identity-session.types'],
    ['backend/src/modules/collaboration/internal/permission.service.ts', 'CollaborationPermissionPort', '../public/collaboration-permission.port'],
    ['backend/src/modules/collaboration/internal/sharing.service.ts', 'AuthenticatedUser', '../../identity/public/identity-session.types'],
    ['backend/src/modules/collaboration/internal/sharing.service.ts', 'ContributionHistoryService', './contribution-history.service'],
    ['backend/src/modules/collaboration/internal/sharing.service.ts', 'buildContributionSnapshot', '../public/contribution-snapshot.builder'],
    ['backend/src/modules/collaboration/collaboration.module.ts', 'ApiV1InviteAccessController', './api/sharing.controller'],
    ['backend/src/modules/collaboration/internal/collaboration-permission.internal.module.ts', 'PermissionService', './permission.service'],
    ['backend/src/modules/collaboration/internal/collaboration-services.internal.module.ts', 'InvitationDeliveryService', './invitation-delivery.service'],
    ['backend/src/modules/collaboration/internal/collaboration-services.internal.module.ts', 'InviteAccessService', './invite-access.service'],
    ['backend/src/modules/collaboration/internal/collaboration-services.internal.module.ts', 'SharingService', './sharing.service'],
  ];
  const parsed = new Map();
  for (const [relativePath, importedName, specifier] of requiredImports) {
    if (!parsed.has(relativePath)) {
      parsed.set(relativePath, parseTypeScriptSource(repositoryRoot, relativePath));
    }
    if (importedSpecifier(parsed.get(relativePath), importedName) !== specifier) {
      throw new Error('R7 Sharing internal import drift detected');
    }
  }
  for (const [relativePath, className] of [
    ['backend/src/modules/collaboration/internal/invitation-delivery.service.ts', 'InvitationDeliveryService'],
    ['backend/src/modules/collaboration/internal/invite-access.service.ts', 'InviteAccessService'],
    ['backend/src/modules/collaboration/internal/permission.service.ts', 'PermissionService'],
    ['backend/src/modules/collaboration/internal/sharing.service.ts', 'SharingService'],
  ]) {
    const sourceFile = parsed.get(relativePath) || parseTypeScriptSource(repositoryRoot, relativePath);
    if (!sourceFile.statements.some((statement) => (
      ts.isClassDeclaration(statement) && statement.name?.text === className && isExported(statement)
    ))) {
      throw new Error('R7 Sharing provider identity drift detected');
    }
  }
  const permissionMetadata = classModuleMetadata(
    parsed.get('backend/src/modules/collaboration/internal/collaboration-permission.internal.module.ts'),
    'CollaborationPermissionInternalModule',
  );
  const servicesMetadata = classModuleMetadata(
    parsed.get('backend/src/modules/collaboration/internal/collaboration-services.internal.module.ts'),
    'CollaborationServicesInternalModule',
  );
  assertExact(permissionMetadata.get('imports'), [
    'PrismaModule',
  ], 'R7 Sharing permission module imports');
  assertExact(permissionMetadata.get('providers'), [
    'PermissionService',
    '{provide:COLLABORATION_PERMISSION_IMPLEMENTATION,useExisting:PermissionService,}',
  ], 'R7 Sharing permission module providers');
  assertExact(permissionMetadata.get('exports'), [
    'PermissionService', 'COLLABORATION_PERMISSION_IMPLEMENTATION',
  ], 'R7 Sharing permission module exports');
  assertExact(servicesMetadata.get('imports'), [
    'IdentityAuthPublicModule',
    'IdentityTransientDeliveryPublicModule',
    'PrismaModule',
    'MessagingRealtimePublicModule',
    'NotificationsPublicModule',
    'CollaborationPermissionInternalModule',
    'CollaborationHistoryInternalModule',
  ], 'R7 Sharing module imports');
  assertExact(servicesMetadata.get('providers'), [
    'SharingService', 'InvitationDeliveryService', 'InviteAccessService',
  ], 'R7 sharing module providers');
  assertExact(servicesMetadata.get('exports'), [
    'SharingService', 'InvitationDeliveryService', 'InviteAccessService',
  ], 'R7 Sharing module exports');
  const collaborationMetadata = classModuleMetadata(
    parsed.get('backend/src/modules/collaboration/collaboration.module.ts'),
    'CollaborationModule',
  );
  const sharingControllers = [
    'ApiV1InviteAccessController',
    'SharedWeddingPlansController',
    'ApiV1WeddingPlanMembersController',
    'ApiV1WeddingPlanInvitesController',
    'ApiV1InvitesController',
    'ApiV1InviteAcceptController',
    'ApiV1WeddingPlanPermissionsController',
  ];
  assertExact(collaborationMetadata.get('controllers'), [
    ...sharingControllers,
    'ContributionHistoryController',
  ], 'R7 Sharing controller registration');
  const sharingControllerSource = parsed.get(
    'backend/src/modules/collaboration/api/sharing.controller.ts',
  );
  const sharingControllerClasses = sharingControllerSource.statements.filter((statement) => (
    ts.isClassDeclaration(statement)
    && statement.name
    && sharingControllers.includes(statement.name.text)
    && decoratorsOf(statement).some(
      (decorator) => decoratorName(decorator, sharingControllerSource) === 'Controller',
    )
  ));
  const sharingControllerInventory = controllerInventory(sharingControllerSource);
  if (sharingControllerClasses.length !== 7 || sharingControllerInventory.operations !== 17) {
    throw new Error('R7 Sharing controller inventory drift detected');
  }
  const providerTopology = sharingProviderTopology(repositoryRoot);
  let legacyRuntimeImports = 0;
  for (const relativePath of listPlainFiles(repositoryRoot, 'backend/src')
    .filter((entry) => entry.endsWith('.ts'))) {
    const sourceFile = parseTypeScriptSource(repositoryRoot, relativePath);
    const inspectSpecifier = (specifier) => {
      const resolved = resolvedImportPath(relativePath, specifier);
      if (resolved?.startsWith('backend/src/sharing/')) legacyRuntimeImports += 1;
    };
    for (const statement of sourceFile.statements) {
      if ((ts.isImportDeclaration(statement) || ts.isExportDeclaration(statement))
          && statement.moduleSpecifier && ts.isStringLiteralLike(statement.moduleSpecifier)) {
        inspectSpecifier(statement.moduleSpecifier.text);
      }
    }
    const visit = (node) => {
      if (ts.isCallExpression(node)
          && ((ts.isIdentifier(node.expression) && node.expression.text === 'require')
            || node.expression.kind === ts.SyntaxKind.ImportKeyword)
          && node.arguments.length === 1 && ts.isStringLiteralLike(node.arguments[0])) {
        inspectSpecifier(node.arguments[0].text);
      }
      ts.forEachChild(node, visit);
    };
    visit(sourceFile);
  }
  if (legacyRuntimeImports !== 0) {
    throw new Error('R7 Sharing legacy runtime import drift detected');
  }
  return Object.freeze({
    controllers: sharingControllerClasses.length,
    operations: sharingControllerInventory.operations,
    providers: providerTopology.providers,
    aliases: providerTopology.aliases,
    exports: 4,
    legacyRuntimeImports,
  });
}

function isCollaborationSource(relativePath) {
  return relativePath.startsWith('backend/src/contribution-history/')
    || relativePath.startsWith('backend/src/sharing/')
    || relativePath.startsWith('backend/src/modules/collaboration/');
}

function isTypeOnlyImport(statement) {
  if (!ts.isImportDeclaration(statement) || !statement.importClause) return false;
  if (statement.importClause.isTypeOnly) return true;
  if (statement.importClause.name) return false;
  const bindings = statement.importClause.namedBindings;
  return Boolean(bindings && ts.isNamedImports(bindings)
    && bindings.elements.length > 0
    && bindings.elements.every((element) => element.isTypeOnly));
}

function resolvedImportPath(importer, specifier) {
  if (specifier.startsWith('.')) {
    return path.posix.normalize(path.posix.join(path.posix.dirname(importer), specifier));
  }
  if (specifier.startsWith('src/')) return `backend/${specifier}`;
  return null;
}

function moduleReferenceSpecifiers(sourceFile) {
  const specifiers = [];
  for (const statement of sourceFile.statements) {
    if ((ts.isImportDeclaration(statement) || ts.isExportDeclaration(statement))
        && statement.moduleSpecifier
        && ts.isStringLiteralLike(statement.moduleSpecifier)) {
      specifiers.push(statement.moduleSpecifier.text);
    } else if (ts.isImportEqualsDeclaration(statement)
        && ts.isExternalModuleReference(statement.moduleReference)
        && statement.moduleReference.expression
        && ts.isStringLiteralLike(statement.moduleReference.expression)) {
      specifiers.push(statement.moduleReference.expression.text);
    }
  }
  const visit = (node) => {
    if (ts.isCallExpression(node)
        && ((ts.isIdentifier(node.expression) && node.expression.text === 'require')
          || node.expression.kind === ts.SyntaxKind.ImportKeyword)
        && node.arguments.length === 1
        && ts.isStringLiteralLike(node.arguments[0])) {
      specifiers.push(node.arguments[0].text);
    } else if (ts.isImportTypeNode(node)
        && ts.isLiteralTypeNode(node.argument)
        && ts.isStringLiteralLike(node.argument.literal)) {
      specifiers.push(node.argument.literal.text);
    }
    ts.forEachChild(node, visit);
  };
  visit(sourceFile);
  return specifiers;
}

function isLegacyCollaborationSpecifier(importer, specifier) {
  const resolved = resolvedImportPath(importer, specifier);
  if (!resolved) return false;
  return [
    'backend/src/contribution-history',
    'backend/src/sharing',
  ].some((legacyRoot) => resolved === legacyRoot || resolved.startsWith(`${legacyRoot}/`));
}

function verifyStrictSourceReferences(repositoryRoot) {
  let legacyImportLiterals = 0;
  let duplicatePublicExports = 0;
  const publicExports = new Set(EXPECTED_PUBLIC_SNAPSHOT_CONTRACT.exports);
  for (const relativePath of listPlainFiles(repositoryRoot, 'backend/src')) {
    if (!relativePath.endsWith('.ts')) continue;
    const sourceFile = parseTypeScriptSource(repositoryRoot, relativePath);
    legacyImportLiterals += moduleReferenceSpecifiers(sourceFile)
      .filter((specifier) => isLegacyCollaborationSpecifier(relativePath, specifier))
      .length;
    if (relativePath === EXPECTED_PUBLIC_SNAPSHOT_CONTRACT.path) continue;
    for (const statement of sourceFile.statements) {
      const names = exportedNames(statement, sourceFile);
      if (ts.isExportDeclaration(statement)
          && statement.exportClause
          && ts.isNamedExports(statement.exportClause)) {
        names.push(...statement.exportClause.elements.map((element) => element.name.text));
      }
      duplicatePublicExports += names.filter((name) => publicExports.has(name)).length;
    }
  }
  if (legacyImportLiterals !== 0) {
    throw new Error('R7 strict stage retains a legacy import literal');
  }
  if (duplicatePublicExports !== 0) {
    throw new Error('R7 strict stage contains a duplicate public snapshot export');
  }
  return Object.freeze({ legacyImportLiterals, duplicatePublicExports });
}

function verifyStrictNestState(repositoryRoot) {
  let forwardRef = 0;
  const globalModules = [];
  for (const relativePath of listPlainFiles(repositoryRoot, 'backend/src')) {
    if (!relativePath.endsWith('.ts')) continue;
    const sourceFile = parseTypeScriptSource(repositoryRoot, relativePath);
    const forwardRefBindings = new Set();
    const globalBindings = new Set();
    const nestNamespaces = new Set();
    for (const statement of sourceFile.statements.filter(ts.isImportDeclaration)) {
      if (!ts.isStringLiteralLike(statement.moduleSpecifier)
          || statement.moduleSpecifier.text !== '@nestjs/common'
          || !statement.importClause
          || !statement.importClause.namedBindings) continue;
      const bindings = statement.importClause.namedBindings;
      if (ts.isNamespaceImport(bindings)) {
        nestNamespaces.add(bindings.name.text);
        continue;
      }
      for (const element of bindings.elements) {
        const imported = element.propertyName ? element.propertyName.text : element.name.text;
        if (imported === 'forwardRef') forwardRefBindings.add(element.name.text);
        if (imported === 'Global') globalBindings.add(element.name.text);
      }
    }
    const nestCall = (expression, namedBindings, property) => (
      (ts.isIdentifier(expression) && namedBindings.has(expression.text))
      || (ts.isPropertyAccessExpression(expression)
        && ts.isIdentifier(expression.expression)
        && nestNamespaces.has(expression.expression.text)
        && expression.name.text === property)
    );
    const visit = (node) => {
      if (ts.isCallExpression(node)) {
        if (nestCall(node.expression, forwardRefBindings, 'forwardRef')) forwardRef += 1;
        if (nestCall(node.expression, globalBindings, 'Global')) globalModules.push(relativePath);
      }
      ts.forEachChild(node, visit);
    };
    visit(sourceFile);
  }
  if (forwardRef !== 0) throw new Error('R7 strict stage contains forwardRef()');
  assertExact(globalModules.sort(), EXPECTED_APPROVED_GLOBAL_MODULES, 'R7 strict globals');
  return Object.freeze({ forwardRef, globals: globalModules.length });
}

function verifyProtectedCollaborationImports(repositoryRoot) {
  const protectedPrefixes = [
    'backend/src/modules/collaboration/api/',
    'backend/src/modules/collaboration/internal/',
  ];
  for (const relativePath of listPlainFiles(repositoryRoot, 'backend/src')) {
    if (!relativePath.endsWith('.ts') || isCollaborationSource(relativePath)) continue;
    const sourceFile = parseTypeScriptSource(repositoryRoot, relativePath);
    const inspectSpecifier = (specifier) => {
      if (typeof specifier !== 'string') return;
      const resolved = resolvedImportPath(relativePath, specifier);
      if (resolved && protectedPrefixes.some((prefix) => resolved.startsWith(prefix))) {
        throw new Error('R7 cross-context runtime import enters Collaboration internal or api');
      }
    };
    for (const statement of sourceFile.statements) {
      if (ts.isImportDeclaration(statement) && !isTypeOnlyImport(statement)
          && ts.isStringLiteralLike(statement.moduleSpecifier)) {
        inspectSpecifier(statement.moduleSpecifier.text);
      } else if (ts.isExportDeclaration(statement) && !statement.isTypeOnly
          && statement.moduleSpecifier && ts.isStringLiteralLike(statement.moduleSpecifier)) {
        inspectSpecifier(statement.moduleSpecifier.text);
      } else if (ts.isImportEqualsDeclaration(statement)
          && !statement.isTypeOnly
          && ts.isExternalModuleReference(statement.moduleReference)
          && statement.moduleReference.expression
          && ts.isStringLiteralLike(statement.moduleReference.expression)) {
        inspectSpecifier(statement.moduleReference.expression.text);
      }
    }
    const visit = (node) => {
      if (ts.isCallExpression(node)
          && ((ts.isIdentifier(node.expression) && node.expression.text === 'require')
            || node.expression.kind === ts.SyntaxKind.ImportKeyword)
          && node.arguments.length === 1
          && ts.isStringLiteralLike(node.arguments[0])) {
        inspectSpecifier(node.arguments[0].text);
      }
      ts.forEachChild(node, visit);
    };
    visit(sourceFile);
  }
  return Object.freeze({ protectedRuntimeImports: 0 });
}

function verifyStrictRelocationState(repositoryRoot, manifest) {
  if (manifest.stage !== 'strict') {
    throw new Error('R7 strict relocation verification requires stage=strict');
  }
  const layout = validateStagedLayout(repositoryRoot, manifest);
  const baselines = verifyBaselines(repositoryRoot, manifest);
  const sourceReferences = verifyStrictSourceReferences(repositoryRoot);
  const protectedImports = verifyProtectedCollaborationImports(repositoryRoot);
  const nest = verifyStrictNestState(repositoryRoot);
  if (layout.sourceFiles !== 0 || layout.targetFiles !== manifest.moves.length) {
    throw new Error('R7 strict final inventory drift detected');
  }
  if (baselines.dependencyRecords !== manifest.expectedBaselines.strictDependencyRecords) {
    throw new Error('R7 strict dependency inventory drift detected');
  }
  return Object.freeze({
    legacyRoots: 0,
    legacyImportLiterals: sourceReferences.legacyImportLiterals,
    retiredDependencyKeys: 0,
    protectedRuntimeImports: protectedImports.protectedRuntimeImports,
    duplicatePublicExports: sourceReferences.duplicatePublicExports,
    unregisteredTargetFiles: 0,
    reparsePoints: 0,
    forwardRef: nest.forwardRef,
    globals: nest.globals,
  });
}

function scanR7CollaborationRelocation(options) {
  if (!options || typeof options !== 'object' || Array.isArray(options)) {
    throw new Error('R7 scan options are invalid');
  }
  const manifest = validateR7Manifest(options.manifest);
  if (typeof options.repositoryRoot !== 'string' || !path.isAbsolute(options.repositoryRoot)) {
    throw new Error('R7 repository root must be absolute');
  }
  const { sourceFiles, targetFiles } = validateStagedLayout(options.repositoryRoot, manifest);
  const baselines = verifyBaselines(options.repositoryRoot, manifest);
  verifySourceParity(options.repositoryRoot, manifest);
  verifyPublicSnapshotSource(options.repositoryRoot, manifest);
  verifyPublicSnapshotConsumers(options.repositoryRoot);
  verifyConstructorHandoffs(options.repositoryRoot, manifest);
  verifyControllerHandoffs(options.repositoryRoot, manifest);
  if (manifest.stage === 'history' || manifest.stage === 'relocated' || manifest.stage === 'strict') {
    verifyHistoryRelocation(options.repositoryRoot, manifest);
  }
  if (manifest.stage === 'relocated' || manifest.stage === 'strict') {
    verifySharingRelocation(options.repositoryRoot, manifest);
  }
  verifyProtectedCollaborationImports(options.repositoryRoot);
  if (manifest.stage === 'strict') {
    verifyStrictRelocationState(options.repositoryRoot, manifest);
  }
  return Object.freeze({
    ok: true,
    stage: manifest.stage,
    sourceFiles,
    targetFiles,
    dependencyRecords: baselines.dependencyRecords,
    ownershipRecords: baselines.ownershipRecords,
    ownershipOccurrences: baselines.ownershipOccurrences,
  });
}

function runCli(dependencies = {}) {
  const argv = dependencies.argv || process.argv.slice(2);
  const stdout = dependencies.stdout || ((message) => process.stdout.write(message + '\n'));
  const stderr = dependencies.stderr || ((message) => process.stderr.write(message + '\n'));
  const repositoryRoot = dependencies.repositoryRoot || path.resolve(__dirname, '../../..');
  try {
    if (argv.length !== 1 || argv[0] !== '--check') throw new Error('invalid arguments');
    const manifest = JSON.parse(fs.readFileSync(path.join(
      repositoryRoot,
      ...MANIFEST_PATH.split('/'),
    ), 'utf8'));
    const result = scanR7CollaborationRelocation({ repositoryRoot, manifest });
    stdout('PASS - R7 Collaboration relocation: stage=' + result.stage
      + ', source=' + result.sourceFiles + ', target=' + result.targetFiles
      + ', dependency=' + result.dependencyRecords
      + ', ownership=' + result.ownershipRecords + '/' + result.ownershipOccurrences);
    return 0;
  } catch {
    stderr('ERROR - R7 Collaboration relocation validation failed');
    return 2;
  }
}

module.exports = {
  EXPECTED_ALLOWED_PATHS,
  EXPECTED_BASELINES,
  EXPECTED_MOVES,
  MANIFEST_PATH,
  R7_BASE,
  runCli,
  scanR7CollaborationRelocation,
  validateR7Manifest,
  verifyConstructorHandoffs,
  verifyControllerHandoffs,
  verifyHistoryRelocation,
  verifySharingRelocation,
  verifyStrictRelocationState,
  verifySourceParity,
  verifyPublicSnapshotSource,
  verifyPublicSnapshotConsumers,
};

if (require.main === module) process.exitCode = runCli();
