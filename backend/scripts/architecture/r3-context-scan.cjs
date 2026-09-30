'use strict';

const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { createRequire, wrap: wrapModule } = require('node:module');
const vm = require('node:vm');
const { types: utilTypes } = require('node:util');
const ts = require('typescript');
const { scanPorts } = require('./ports-scan.cjs');
const {
  projectR3InventoryForR8,
  validateR8Manifest,
} = require('./r8-global-module-removal-scan.cjs');
const {
  expectedR12aSuccessorDependencyRecords,
  isAllowedR12aRuntimePublicEdge,
  readR12aImmutableEntry,
  validateR12aManifest,
} = require('./r12a-backoffice-catalog-public-contracts-scan.cjs');

const R3_BASE = '6b06eb096aca8cc6684d365d16e05d4cd8529898';
const R8_MANIFEST_PATH = path.resolve(
  __dirname,
  '../../architecture/r8-global-module-removal.json',
);
const R12A_MANIFEST_PATH = path.resolve(
  __dirname,
  '../../architecture/r12a-backoffice-catalog-public-contracts.json',
);
const R12A_PATH_MOVES = Object.freeze(new Map([
  ['backend/src/admin/admin.guard.ts', 'backend/src/modules/backoffice/public/admin.guard.ts'],
  ['backend/src/admin/admin-permission.decorator.ts', 'backend/src/modules/backoffice/public/admin-permission.decorator.ts'],
  ['backend/src/admin/admin-permission.guard.ts', 'backend/src/modules/backoffice/public/admin-permission.guard.ts'],
  ['backend/src/admin/admin-mutation-gate.ts', 'backend/src/modules/backoffice/public/admin-mutation-gate.ts'],
]));
const R12A_RUNTIME_PUBLIC_MOVES = Object.freeze(new Map([
  ['backend/src/marketplace/provider-review-rating.ts', 'backend/src/modules/marketplace/public/provider-review-rating.ts'],
]));

function projectR12aPath(relativePath, manifest) {
  if (!manifest || !['backoffice', 'strict'].includes(manifest.stage)) return relativePath;
  return R12A_PATH_MOVES.get(relativePath) || relativePath;
}

function projectR12aInventory(value, manifest) {
  if (!manifest || !['backoffice', 'strict'].includes(manifest.stage)) return value;
  if (typeof value === 'string') return projectR12aPath(value, manifest);
  if (Array.isArray(value)) return value.map((item) => projectR12aInventory(item, manifest));
  if (!value || typeof value !== 'object') return value;
  return Object.fromEntries(Object.entries(value).map(([key, item]) => [
    key, projectR12aInventory(item, manifest),
  ]));
}

function projectR12aSourceLaws(value, manifest) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return value;
  const diagnostics = Array.isArray(value.diagnostics)
    ? value.diagnostics.map((diagnostic) => {
      const projected = Object.fromEntries(Object.entries(diagnostic).map(([key, item]) => [
        key, typeof item === 'string' ? projectR12aPath(item, manifest) : item,
      ]));
      delete projected.node;
      delete projected.sourceFile;
      return projected;
    })
    : value.diagnostics;
  return { ...value, diagnostics };
}

// R12C forward projection (closed successor). R12C introduced one Messaging
// lifecycle public module (its port bound with useExisting to the internal
// value provider), the internal module behind it, one import of that public
// module in the Marketplace internal module, one constructor injection of the
// port at parameter index 3 in MarketplaceService and ProviderDashboardService,
// and runtime public edges from the declared consumers to the Finance and
// Marketplace public contracts. While R12C was open these facts were proven by
// replaying the R3 law over the reconstructed predecessor; once R12C is closed
// they are projected forward so the R3 law applies to the live tree.
const R12C_LIFECYCLE_MODULES = Object.freeze([
  Object.freeze({
    path: 'backend/src/modules/messaging/internal/conversation-lifecycle.internal.module.ts',
    className: 'ConversationLifecycleInternalModule',
    imports: [],
    providers: ['{ provide: CONVERSATION_LIFECYCLE_IMPLEMENTATION, useValue: conversationLifecycle }'],
    exports: ['CONVERSATION_LIFECYCLE_IMPLEMENTATION'],
    global: false,
  }),
  Object.freeze({
    path: 'backend/src/modules/messaging/public/conversation-lifecycle-public.module.ts',
    className: 'ConversationLifecyclePublicModule',
    imports: ['ConversationLifecycleInternalModule'],
    providers: ['{ provide: CONVERSATION_LIFECYCLE_PORT, useExisting: CONVERSATION_LIFECYCLE_IMPLEMENTATION }'],
    exports: ['CONVERSATION_LIFECYCLE_PORT'],
    global: false,
  }),
]);
const R12C_LIFECYCLE_WIRING = Object.freeze({
  module: 'backend/src/modules/marketplace/internal/marketplace-services.internal.module.ts',
  imported: 'ConversationLifecyclePublicModule',
});
const R12C_LIFECYCLE_PORT_INJECTIONS = Object.freeze(new Map([
  ['backend/src/marketplace/marketplace.service.ts#MarketplaceService', 3],
  ['backend/src/provider-dashboard/provider-dashboard.service.ts#ProviderDashboardService', 3],
]));

function r12cSuccessor(repoRoot) {
  const relative = 'backend/architecture/r12c-zero-cross-context-dependencies.json';
  const file = path.join(repoRoot, ...relative.split('/'));
  if (!fs.existsSync(file)) return null;
  const closure = require('./modular-monolith-closure.cjs').readClosure(repoRoot);
  if (!closure) return null;
  const r12c = require('./r12c-zero-cross-context-dependencies-scan.cjs');
  const manifest = r12c.validateR12cManifest(JSON.parse(fs.readFileSync(file, 'utf8')));
  if (manifest.stage !== 'strict') throw new Error('R12C closed projection requires the strict stage');
  return manifest;
}

function projectR12cModules(modules, r12cManifest) {
  if (!r12cManifest) return modules;
  const wired = modules.filter((module) => module.path === R12C_LIFECYCLE_WIRING.module);
  if (wired.length !== 1 || wired[0].imports.includes(R12C_LIFECYCLE_WIRING.imported)) {
    throw new Error('R12C lifecycle wiring projection is invalid');
  }
  const projected = modules.map((module) => (module.path === R12C_LIFECYCLE_WIRING.module
    ? { ...module, imports: [...module.imports, R12C_LIFECYCLE_WIRING.imported].sort() }
    : module));
  for (const entry of R12C_LIFECYCLE_MODULES) {
    if (projected.some((module) => module.path === entry.path)) throw new Error('R12C lifecycle module projection is duplicated');
    projected.push({ ...entry, imports: [...entry.imports], providers: [...entry.providers], exports: [...entry.exports] });
  }
  return projected.sort((left, right) => (left.path < right.path ? -1 : left.path > right.path ? 1 : 0));
}

function projectR12cConstructorUses(uses, r12cManifest) {
  if (!r12cManifest) return uses;
  return uses.map((use) => {
    const insertion = R12C_LIFECYCLE_PORT_INJECTIONS.get(use.consumerClass);
    return insertion !== undefined && use.parameterIndex >= insertion
      ? { ...use, parameterIndex: use.parameterIndex + 1 }
      : use;
  });
}

// Public contract tokens declared by the R12C port files and the runtime
// public edges from declared consumers to the R12C public contracts.
function r12cSourceLawAllowances(repoRoot, r12cManifest) {
  const tokens = new Set();
  const edges = new Set();
  if (!r12cManifest) return { tokens, edges };
  for (const family of r12cManifest.contractFamilies) {
    const targets = family.targets || [family.target];
    for (const target of targets) {
      if (target.endsWith('.port.ts')) {
        const source = fs.readFileSync(path.join(repoRoot, ...target.split('/')), 'utf8');
        for (const match of source.matchAll(/^export\s+const\s+([A-Z][A-Z0-9_]*)\s*=/gmu)) tokens.add(`${target}#${match[1]}`);
        continue;
      }
      if (target.endsWith('.module.ts')) continue;
      for (const consumer of family.consumers) edges.add(`${consumer}->${target}`);
    }
  }
  return { tokens, edges };
}

function sortR12aDecoratorInventory(value) {
  return [...value].sort((left, right) => {
    const leftKey = `${left.source}|${left.symbol}|${left.kind}`;
    const rightKey = `${right.source}|${right.symbol}|${right.kind}`;
    return leftKey < rightKey ? -1 : leftKey > rightKey ? 1 : 0;
  });
}
const CONTEXTS = Object.freeze([
  'identity', 'planning', 'finance', 'collaboration', 'tasks', 'guests',
  'marketplace', 'messaging', 'notifications', 'catalog', 'media', 'insights',
  'backoffice',
]);
const ROOTS = Object.freeze({
  identity: [],
  planning: ['wedding-plans', 'onboarding'],
  finance: ['money', 'budget-categories', 'wedding-costs'],
  collaboration: ['sharing', 'contribution-history'],
  tasks: ['tasks'], guests: ['guests'],
  marketplace: ['marketplace', 'provider-dashboard'],
  messaging: ['conversations'], notifications: ['notifications', 'push'],
  catalog: ['catalogs'], media: ['media'], insights: ['dashboard', 'timeline'],
  backoffice: ['admin'],
});
const ROOT_TO_CONTEXT = new Map(
  Object.entries(ROOTS).flatMap(([context, roots]) => roots.map((root) => [root, context])),
);
const DIAGNOSTIC_KINDS = new Set([
  'unresolved-nest-metadata', 'duplicate-provider', 'hollow-public-token',
  'concrete-public-export', 'illegal-boundary-import', 'illegal-composition-import',
  'public-binding-not-use-existing', 'public-imports-concrete',
  'implementation-token-misuse', 'forward-ref', 'unknown-context',
  'nest-module-cycle', 'inventory-drift', 'r4-writer-isolation',
  'injection-identity-drift', 'cross-context-injection',
]);
const COUNT_KEYS = Object.freeze([
  'contexts', 'legacyModules', 'crossContextInjections', 'compositionDependencies',
  'initialDuplicateProviders', 'remainingDuplicateProviders',
  'initialPlatformDebts', 'remainingPlatformDebts',
  'initialRetiredLegacyProviderEdges', 'remainingRetiredLegacyProviderEdges',
  'forwardRef', 'globals', 'nestModuleCycles', 'illegalEdges',
]);
const EXACT_DUPLICATE_PROVIDERS = Object.freeze([
  'AdminGuard', 'AdminPermissionGuard', 'PermissionService',
]);
const EXACT_PLATFORM_DEBTS = Object.freeze([
  'runtime-jwt-secret', 'readiness-media-storage', 'outbox-dispatcher-realtime',
  'outbox-dispatcher-push', 'outbox-module-realtime', 'outbox-module-push',
]);
const DUPLICATE_RETIREMENT_TASK = Object.freeze({
  AdminGuard: 7,
  AdminPermissionGuard: 7,
  PermissionService: 3,
});
const PLATFORM_RETIREMENT_TASK = Object.freeze({
  'runtime-jwt-secret': 5,
  'readiness-media-storage': 2,
  'outbox-dispatcher-realtime': 2,
  'outbox-dispatcher-push': 2,
  'outbox-module-realtime': 2,
  'outbox-module-push': 2,
});
const APPROVED_DUPLICATE_IDENTITIES = new Map([
  ['AdminGuard', 'backend/src/admin/admin.guard.ts'],
  ['AdminPermissionGuard', 'backend/src/admin/admin-permission.guard.ts'],
  ['PermissionService', 'backend/src/sharing/permission.service.ts'],
]);
const APPROVED_DUPLICATE_REGISTRATIONS = new Map([
  ['AdminGuard', new Set(['backend/src/admin/admin.module.ts', 'backend/src/catalogs/catalogs.module.ts'])],
  ['AdminPermissionGuard', new Set(['backend/src/admin/admin.module.ts', 'backend/src/catalogs/catalogs.module.ts'])],
  ['PermissionService', new Set(['backend/src/sharing/sharing.module.ts', 'backend/src/notifications/notifications.module.ts'])],
]);
const EXTERNAL_PROVIDER_CONTRACTS = new Map([
  ['IDENTITY_ACCESS_TOKEN_VERIFIER', Object.freeze({
    implementation: 'JwtService',
    module: 'JwtModule',
    packageName: '@nestjs/jwt',
  })],
]);
const COMPOSITION_DEPENDENCIES = Object.freeze([
  { key: 'app-jwt-module-availability', kind: 'module-availability', retirementTask: 5 },
  { key: 'readiness-media-storage', kind: 'provider', retirementTask: 2 },
  { key: 'outbox-dispatcher-realtime', kind: 'provider', retirementTask: 2 },
  { key: 'outbox-dispatcher-push', kind: 'provider', retirementTask: 2 },
  { key: 'outbox-module-realtime', kind: 'module', retirementTask: 2 },
  { key: 'outbox-module-push', kind: 'module', retirementTask: 2 },
]);
const TASK2_CANONICAL_INJECTION_IDENTITIES = Object.freeze({
  messagingRealtime: Object.freeze({
    token: 'backend/src/modules/messaging/public/messaging-realtime.port.ts#MESSAGING_REALTIME_PORT',
    parameterType: 'backend/src/modules/messaging/public/messaging-realtime.port.ts#MessagingRealtimePort',
  }),
  mediaStorage: Object.freeze({
    token: 'backend/src/modules/media/public/media-storage.port.ts#MEDIA_STORAGE_PORT',
    parameterType: 'backend/src/modules/media/public/media-storage.port.ts#MediaStoragePort',
  }),
  pushCapability: Object.freeze({
    token: 'backend/src/modules/notifications/public/push-capability.port.ts#PUSH_CAPABILITY_PORT',
    parameterType: 'backend/src/modules/notifications/public/push-capability.port.ts#PushCapabilityPort',
  }),
  pushDelivery: Object.freeze({
    token: 'backend/src/modules/notifications/public/push-delivery.port.ts#PUSH_DELIVERY_PORT',
    parameterType: 'backend/src/modules/notifications/public/push-delivery.port.ts#PushDeliveryPort',
  }),
  mediaReadiness: Object.freeze({
    token: 'backend/src/platform/health/media-readiness.port.ts#MEDIA_READINESS_PORT',
    parameterType: 'backend/src/platform/health/media-readiness.port.ts#MediaReadinessPort',
  }),
  outboxRealtime: Object.freeze({
    token: 'backend/src/platform/outbox/outbox.ports.ts#OUTBOX_REALTIME_SINK',
    parameterType: 'backend/src/platform/outbox/outbox.ports.ts#OutboxRealtimeSink',
  }),
  outboxPush: Object.freeze({
    token: 'backend/src/platform/outbox/outbox.ports.ts#OUTBOX_PUSH_SINK',
    parameterType: 'backend/src/platform/outbox/outbox.ports.ts#OutboxPushSink',
  }),
});
const TASK2_CONSUMER_IDENTITIES = new Map([
  ['MESSAGING_REALTIME_PORT', Object.freeze([
    TASK2_CANONICAL_INJECTION_IDENTITIES.messagingRealtime,
  ])],
  ['MEDIA_STORAGE_PORT', Object.freeze([
    TASK2_CANONICAL_INJECTION_IDENTITIES.mediaStorage,
  ])],
  ['PUSH_CAPABILITY_PORT', Object.freeze([
    TASK2_CANONICAL_INJECTION_IDENTITIES.pushCapability,
  ])],
  ['PUSH_DELIVERY_PORT', Object.freeze([
    TASK2_CANONICAL_INJECTION_IDENTITIES.pushDelivery,
    TASK2_CANONICAL_INJECTION_IDENTITIES.outboxPush,
  ])],
]);
const TASK2_EXACT_CONSTRUCTOR_USES = Object.freeze([
  Object.freeze({ source: 'backend/src/admin/admin.service.ts', consumerClass: 'backend/src/admin/admin.service.ts#AdminService', parameter: 'realtime', parameterIndex: 1, ...TASK2_CANONICAL_INJECTION_IDENTITIES.messagingRealtime }),
  Object.freeze({ source: 'backend/src/modules/identity/internal/auth/auth.service.ts', consumerClass: 'backend/src/modules/identity/internal/auth/auth.service.ts#AuthService', parameter: 'realtime', parameterIndex: 4, ...TASK2_CANONICAL_INJECTION_IDENTITIES.messagingRealtime }),
  Object.freeze({ source: 'backend/src/conversations/conversations.service.ts', consumerClass: 'backend/src/conversations/conversations.service.ts#ConversationsService', parameter: 'mediaStorage', parameterIndex: 3, ...TASK2_CANONICAL_INJECTION_IDENTITIES.mediaStorage }),
  Object.freeze({ source: 'backend/src/platform/health/readiness.service.ts', consumerClass: 'backend/src/platform/health/readiness.service.ts#ReadinessService', parameter: 'mediaStorage', parameterIndex: 1, ...TASK2_CANONICAL_INJECTION_IDENTITIES.mediaReadiness }),
  Object.freeze({ source: 'backend/src/platform/outbox/outbox.dispatcher.ts', consumerClass: 'backend/src/platform/outbox/outbox.dispatcher.ts#OutboxDispatcher', parameter: 'pushDelivery', parameterIndex: 1, ...TASK2_CANONICAL_INJECTION_IDENTITIES.outboxPush }),
  Object.freeze({ source: 'backend/src/platform/outbox/outbox.dispatcher.ts', consumerClass: 'backend/src/platform/outbox/outbox.dispatcher.ts#OutboxDispatcher', parameter: 'realtime', parameterIndex: 0, ...TASK2_CANONICAL_INJECTION_IDENTITIES.outboxRealtime }),
  Object.freeze({ source: 'backend/src/provider-dashboard/provider-dashboard.service.ts', consumerClass: 'backend/src/provider-dashboard/provider-dashboard.service.ts#ProviderDashboardService', parameter: 'mediaStorage', parameterIndex: 2, ...TASK2_CANONICAL_INJECTION_IDENTITIES.mediaStorage }),
  Object.freeze({ source: 'backend/src/modules/collaboration/internal/sharing.service.ts', consumerClass: 'backend/src/modules/collaboration/internal/sharing.service.ts#SharingService', parameter: 'realtime', parameterIndex: 5, ...TASK2_CANONICAL_INJECTION_IDENTITIES.messagingRealtime }),
  Object.freeze({ source: 'backend/src/modules/identity/internal/profile/users.service.ts', consumerClass: 'backend/src/modules/identity/internal/profile/users.service.ts#UsersService', parameter: 'mediaStorage', parameterIndex: 2, ...TASK2_CANONICAL_INJECTION_IDENTITIES.mediaStorage }),
  Object.freeze({ source: 'backend/src/modules/identity/internal/profile/users.service.ts', consumerClass: 'backend/src/modules/identity/internal/profile/users.service.ts#UsersService', parameter: 'realtime', parameterIndex: 3, ...TASK2_CANONICAL_INJECTION_IDENTITIES.messagingRealtime }),
  Object.freeze({ source: 'backend/src/modules/identity/internal/profile/users.service.ts', consumerClass: 'backend/src/modules/identity/internal/profile/users.service.ts#UsersService', parameter: 'firebasePush', parameterIndex: 4, ...TASK2_CANONICAL_INJECTION_IDENTITIES.pushCapability }),
]);
const TASK3_CANONICAL_INJECTION_IDENTITIES = Object.freeze({
  permission: Object.freeze({
    token: 'backend/src/modules/collaboration/public/collaboration-permission.port.ts#COLLABORATION_PERMISSION_PORT',
    parameterType: 'backend/src/modules/collaboration/public/collaboration-permission.port.ts#CollaborationPermissionPort',
  }),
  history: Object.freeze({
    token: 'backend/src/modules/collaboration/public/collaboration-history.port.ts#COLLABORATION_HISTORY_PORT',
    parameterType: 'backend/src/modules/collaboration/public/collaboration-history.port.ts#CollaborationHistoryPort',
  }),
  scope: Object.freeze({
    token: 'backend/src/modules/collaboration/public/collaboration-scope.port.ts#COLLABORATION_SCOPE_PORT',
    parameterType: 'backend/src/modules/collaboration/public/collaboration-scope.port.ts#CollaborationScopePort',
  }),
});
const TASK3_CONSUMER_IDENTITIES = new Map([
  ['COLLABORATION_PERMISSION_PORT', Object.freeze([
    TASK3_CANONICAL_INJECTION_IDENTITIES.permission,
  ])],
  ['COLLABORATION_HISTORY_PORT', Object.freeze([
    TASK3_CANONICAL_INJECTION_IDENTITIES.history,
  ])],
  ['COLLABORATION_SCOPE_PORT', Object.freeze([
    TASK3_CANONICAL_INJECTION_IDENTITIES.scope,
  ])],
]);
const TASK3_EXACT_CONSTRUCTOR_USES = Object.freeze([
  Object.freeze({ source: 'backend/src/budget-categories/budget-categories.service.ts', consumerClass: 'backend/src/budget-categories/budget-categories.service.ts#BudgetCategoriesService', parameter: 'permissions', parameterIndex: 1, ...TASK3_CANONICAL_INJECTION_IDENTITIES.permission }),
  Object.freeze({ source: 'backend/src/modules/identity/internal/profile/contexts.service.ts', consumerClass: 'backend/src/modules/identity/internal/profile/contexts.service.ts#ContextsService', parameter: 'permissions', parameterIndex: 1, ...TASK3_CANONICAL_INJECTION_IDENTITIES.permission }),
  Object.freeze({ source: 'backend/src/dashboard/dashboard.service.ts', consumerClass: 'backend/src/dashboard/dashboard.service.ts#DashboardService', parameter: 'permissions', parameterIndex: 1, ...TASK3_CANONICAL_INJECTION_IDENTITIES.permission }),
  Object.freeze({ source: 'backend/src/guests/guests.service.ts', consumerClass: 'backend/src/guests/guests.service.ts#GuestsService', parameter: 'permissions', parameterIndex: 1, ...TASK3_CANONICAL_INJECTION_IDENTITIES.permission }),
  Object.freeze({ source: 'backend/src/marketplace/marketplace.service.ts', consumerClass: 'backend/src/marketplace/marketplace.service.ts#MarketplaceService', parameter: 'permissions', parameterIndex: 1, ...TASK3_CANONICAL_INJECTION_IDENTITIES.permission }),
  Object.freeze({ source: 'backend/src/money/money-budget.service.ts', consumerClass: 'backend/src/money/money-budget.service.ts#MoneyBudgetService', parameter: 'permissions', parameterIndex: 1, ...TASK3_CANONICAL_INJECTION_IDENTITIES.permission }),
  Object.freeze({ source: 'backend/src/money/money-summary.service.ts', consumerClass: 'backend/src/money/money-summary.service.ts#MoneySummaryService', parameter: 'permissions', parameterIndex: 1, ...TASK3_CANONICAL_INJECTION_IDENTITIES.permission }),
  Object.freeze({ source: 'backend/src/notifications/notifications.service.ts', consumerClass: 'backend/src/notifications/notifications.service.ts#NotificationsService', parameter: 'permissions', parameterIndex: 1, ...TASK3_CANONICAL_INJECTION_IDENTITIES.permission }),
  Object.freeze({ source: 'backend/src/tasks/tasks.service.ts', consumerClass: 'backend/src/tasks/tasks.service.ts#TasksService', parameter: 'permissions', parameterIndex: 1, ...TASK3_CANONICAL_INJECTION_IDENTITIES.permission }),
  Object.freeze({ source: 'backend/src/timeline/timeline.service.ts', consumerClass: 'backend/src/timeline/timeline.service.ts#TimelineService', parameter: 'permissions', parameterIndex: 1, ...TASK3_CANONICAL_INJECTION_IDENTITIES.permission }),
  Object.freeze({ source: 'backend/src/modules/identity/internal/profile/users.service.ts', consumerClass: 'backend/src/modules/identity/internal/profile/users.service.ts#UsersService', parameter: 'permissionService', parameterIndex: 1, ...TASK3_CANONICAL_INJECTION_IDENTITIES.permission }),
  Object.freeze({ source: 'backend/src/wedding-costs/wedding-costs.service.ts', consumerClass: 'backend/src/wedding-costs/wedding-costs.service.ts#WeddingCostsService', parameter: 'permissions', parameterIndex: 1, ...TASK3_CANONICAL_INJECTION_IDENTITIES.permission }),
  Object.freeze({ source: 'backend/src/wedding-plans/wedding-plans.service.ts', consumerClass: 'backend/src/wedding-plans/wedding-plans.service.ts#WeddingPlansService', parameter: 'permissions', parameterIndex: 1, ...TASK3_CANONICAL_INJECTION_IDENTITIES.permission }),
  Object.freeze({ source: 'backend/src/budget-categories/budget-categories.service.ts', consumerClass: 'backend/src/budget-categories/budget-categories.service.ts#BudgetCategoriesService', parameter: 'contributionHistory', parameterIndex: 3, ...TASK3_CANONICAL_INJECTION_IDENTITIES.history }),
  Object.freeze({ source: 'backend/src/dashboard/dashboard.service.ts', consumerClass: 'backend/src/dashboard/dashboard.service.ts#DashboardService', parameter: 'contributionHistory', parameterIndex: 4, ...TASK3_CANONICAL_INJECTION_IDENTITIES.history }),
  Object.freeze({ source: 'backend/src/guests/guests.service.ts', consumerClass: 'backend/src/guests/guests.service.ts#GuestsService', parameter: 'contributionHistory', parameterIndex: 2, ...TASK3_CANONICAL_INJECTION_IDENTITIES.history }),
  Object.freeze({ source: 'backend/src/marketplace/marketplace.service.ts', consumerClass: 'backend/src/marketplace/marketplace.service.ts#MarketplaceService', parameter: 'contributionHistory', parameterIndex: 3, ...TASK3_CANONICAL_INJECTION_IDENTITIES.history }),
  Object.freeze({ source: 'backend/src/tasks/tasks.service.ts', consumerClass: 'backend/src/tasks/tasks.service.ts#TasksService', parameter: 'contributionHistory', parameterIndex: 3, ...TASK3_CANONICAL_INJECTION_IDENTITIES.history }),
  Object.freeze({ source: 'backend/src/wedding-costs/wedding-costs.service.ts', consumerClass: 'backend/src/wedding-costs/wedding-costs.service.ts#WeddingCostsService', parameter: 'contributionHistory', parameterIndex: 3, ...TASK3_CANONICAL_INJECTION_IDENTITIES.history }),
  Object.freeze({ source: 'backend/src/wedding-plans/wedding-plans.service.ts', consumerClass: 'backend/src/wedding-plans/wedding-plans.service.ts#WeddingPlansService', parameter: 'contributionHistory', parameterIndex: 2, ...TASK3_CANONICAL_INJECTION_IDENTITIES.history }),
  Object.freeze({ source: 'backend/src/budget-categories/budget-categories.service.ts', consumerClass: 'backend/src/budget-categories/budget-categories.service.ts#BudgetCategoriesService', parameter: 'contributorScope', parameterIndex: 2, ...TASK3_CANONICAL_INJECTION_IDENTITIES.scope }),
  Object.freeze({ source: 'backend/src/dashboard/dashboard.service.ts', consumerClass: 'backend/src/dashboard/dashboard.service.ts#DashboardService', parameter: 'contributorScope', parameterIndex: 3, ...TASK3_CANONICAL_INJECTION_IDENTITIES.scope }),
  Object.freeze({ source: 'backend/src/guests/guests.service.ts', consumerClass: 'backend/src/guests/guests.service.ts#GuestsService', parameter: 'contributorScope', parameterIndex: 3, ...TASK3_CANONICAL_INJECTION_IDENTITIES.scope }),
  Object.freeze({ source: 'backend/src/money/money-summary.service.ts', consumerClass: 'backend/src/money/money-summary.service.ts#MoneySummaryService', parameter: 'contributorScope', parameterIndex: 2, ...TASK3_CANONICAL_INJECTION_IDENTITIES.scope }),
  Object.freeze({ source: 'backend/src/tasks/tasks.service.ts', consumerClass: 'backend/src/tasks/tasks.service.ts#TasksService', parameter: 'contributorScope', parameterIndex: 4, ...TASK3_CANONICAL_INJECTION_IDENTITIES.scope }),
  Object.freeze({ source: 'backend/src/timeline/timeline.service.ts', consumerClass: 'backend/src/timeline/timeline.service.ts#TimelineService', parameter: 'contributorScope', parameterIndex: 2, ...TASK3_CANONICAL_INJECTION_IDENTITIES.scope }),
  Object.freeze({ source: 'backend/src/wedding-costs/wedding-costs.service.ts', consumerClass: 'backend/src/wedding-costs/wedding-costs.service.ts#WeddingCostsService', parameter: 'contributorScope', parameterIndex: 2, ...TASK3_CANONICAL_INJECTION_IDENTITIES.scope }),
]);
const TASK4_CANONICAL_INJECTION_IDENTITIES = Object.freeze({
  notifications: Object.freeze({
    token: 'backend/src/modules/notifications/public/notifications.port.ts#NOTIFICATIONS_PORT',
    parameterType: 'backend/src/modules/notifications/public/notifications.port.ts#NotificationsPort',
  }),
});
const TASK4_CONSUMER_IDENTITIES = new Map([
  ['NOTIFICATIONS_PORT', Object.freeze([
    TASK4_CANONICAL_INJECTION_IDENTITIES.notifications,
  ])],
]);
const TASK4_EXACT_CONSTRUCTOR_USES = Object.freeze([
  Object.freeze({ source: 'backend/src/admin/admin.service.ts', consumerClass: 'backend/src/admin/admin.service.ts#AdminService', parameter: 'notifications', parameterIndex: 2, ...TASK4_CANONICAL_INJECTION_IDENTITIES.notifications }),
  Object.freeze({ source: 'backend/src/conversations/conversations.service.ts', consumerClass: 'backend/src/conversations/conversations.service.ts#ConversationsService', parameter: 'notifications', parameterIndex: 1, ...TASK4_CANONICAL_INJECTION_IDENTITIES.notifications }),
  Object.freeze({ source: 'backend/src/dashboard/dashboard.service.ts', consumerClass: 'backend/src/dashboard/dashboard.service.ts#DashboardService', parameter: 'notifications', parameterIndex: 2, ...TASK4_CANONICAL_INJECTION_IDENTITIES.notifications }),
  Object.freeze({ source: 'backend/src/marketplace/marketplace.service.ts', consumerClass: 'backend/src/marketplace/marketplace.service.ts#MarketplaceService', parameter: 'notifications', parameterIndex: 2, ...TASK4_CANONICAL_INJECTION_IDENTITIES.notifications }),
  Object.freeze({ source: 'backend/src/provider-dashboard/provider-dashboard.service.ts', consumerClass: 'backend/src/provider-dashboard/provider-dashboard.service.ts#ProviderDashboardService', parameter: 'notifications', parameterIndex: 1, ...TASK4_CANONICAL_INJECTION_IDENTITIES.notifications }),
  Object.freeze({ source: 'backend/src/modules/collaboration/internal/sharing.service.ts', consumerClass: 'backend/src/modules/collaboration/internal/sharing.service.ts#SharingService', parameter: 'notifications', parameterIndex: 2, ...TASK4_CANONICAL_INJECTION_IDENTITIES.notifications }),
  Object.freeze({ source: 'backend/src/tasks/tasks.service.ts', consumerClass: 'backend/src/tasks/tasks.service.ts#TasksService', parameter: 'notifications', parameterIndex: 2, ...TASK4_CANONICAL_INJECTION_IDENTITIES.notifications }),
]);
const TASK5_CANONICAL_INJECTION_IDENTITIES = Object.freeze({
  auth: Object.freeze({
    token: 'backend/src/modules/identity/public/identity-auth.port.ts#IDENTITY_AUTH_PORT',
    parameterType: 'backend/src/modules/identity/public/identity-auth.port.ts#IdentityAuthPort',
  }),
  verifier: Object.freeze({
    token: 'backend/src/modules/identity/public/identity-auth.port.ts#IDENTITY_ACCESS_TOKEN_VERIFIER',
    parameterType: 'backend/src/modules/identity/public/identity-auth.port.ts#IdentityAccessTokenVerifier',
  }),
});
const TASK5_CONSUMER_IDENTITIES = new Map([
  ['IDENTITY_AUTH_PORT', Object.freeze([
    TASK5_CANONICAL_INJECTION_IDENTITIES.auth,
  ])],
  ['IDENTITY_ACCESS_TOKEN_VERIFIER', Object.freeze([
    TASK5_CANONICAL_INJECTION_IDENTITIES.verifier,
  ])],
]);
const TASK5_EXACT_CONSTRUCTOR_USES = Object.freeze([
  Object.freeze({ source: 'backend/src/modules/collaboration/internal/invite-access.service.ts', consumerClass: 'backend/src/modules/collaboration/internal/invite-access.service.ts#InviteAccessService', parameter: 'auth', parameterIndex: 1, ...TASK5_CANONICAL_INJECTION_IDENTITIES.auth }),
  Object.freeze({ source: 'backend/src/conversations/conversations.gateway.ts', consumerClass: 'backend/src/conversations/conversations.gateway.ts#ConversationsGateway', parameter: 'jwt', parameterIndex: 0, ...TASK5_CANONICAL_INJECTION_IDENTITIES.verifier }),
]);
const R7_DEPENDENCY_HANDOFF = Object.freeze({
  baseRevision: '31ea5324007fc71fa4b3590fbb98a454ee1deaa7',
  historicalSha256: '82f08c01aa76b18e1d64b725358ebac335750ffee7fe7b0898ea9c34b7c25a42',
  historicalRecords: 31,
  liveRecords: 22,
  retiredDependencyKeys: Object.freeze([
    'context-finance-cross-context|src/budget-categories/budget-categories.service.ts|src/contribution-history/contribution-snapshot.builder.ts',
    'context-finance-cross-context|src/wedding-costs/wedding-costs.service.ts|src/contribution-history/contribution-snapshot.builder.ts',
    'context-guests-cross-context|src/guests/guests.service.ts|src/contribution-history/contribution-snapshot.builder.ts',
    'context-marketplace-cross-context|src/marketplace/quote-offer-acceptance.ts|src/contribution-history/contribution-snapshot.builder.ts',
    'context-marketplace-cross-context|src/marketplace/quote-offer-rejection.ts|src/contribution-history/contribution-snapshot.builder.ts',
    'context-marketplace-cross-context|src/marketplace/quote-request-cancellation.ts|src/contribution-history/contribution-snapshot.builder.ts',
    'context-marketplace-cross-context|src/marketplace/quote-request-creation.ts|src/contribution-history/contribution-snapshot.builder.ts',
    'context-planning-cross-context|src/wedding-plans/wedding-plans.service.ts|src/contribution-history/contribution-snapshot.builder.ts',
    'context-tasks-cross-context|src/tasks/tasks.service.ts|src/contribution-history/contribution-snapshot.builder.ts',
  ]),
});
const R7_CONTRIBUTION_HISTORY_HANDOFF = Object.freeze({
  baseRevision: '31ea5324007fc71fa4b3590fbb98a454ee1deaa7',
  from: 'backend/src/contribution-history/contribution-history.controller.ts',
  to: 'backend/src/modules/collaboration/api/contribution-history.controller.ts',
  historicalDecoratorRuntimeReferencesSha256:
    '756164378747cbf0c8a1a2981432d5d18803e046a4552a585dd4db2f90ed01d2',
  historicalRuntimeDecoratorValueReferencesSha256:
    '1a2fe14b1237342c8d339f5a4b6f964a5067838f2db9b944d0004274b2cd3eda',
});
const R7_SHARING_HANDOFF = Object.freeze({
  baseRevision: '31ea5324007fc71fa4b3590fbb98a454ee1deaa7',
  from: 'backend/src/sharing/sharing.controller.ts',
  to: 'backend/src/modules/collaboration/api/sharing.controller.ts',
  historicalDecoratorRuntimeReferencesSha256:
    '756164378747cbf0c8a1a2981432d5d18803e046a4552a585dd4db2f90ed01d2',
  historicalRuntimeDecoratorValueReferencesSha256:
    '1a2fe14b1237342c8d339f5a4b6f964a5067838f2db9b944d0004274b2cd3eda',
});
const R7_COLLABORATION_RELOCATED_IMPORTS = new Set([
  'backend/src/modules/collaboration/api/contribution-history.controller.ts->backend/src/modules/identity/public/identity-session.types.ts',
  'backend/src/modules/collaboration/api/contribution-history.controller.ts->backend/src/modules/identity/public/current-user.decorator.ts',
  'backend/src/modules/collaboration/api/contribution-history.controller.ts->backend/src/modules/identity/public/jwt-auth.guard.ts',
  'backend/src/modules/collaboration/internal/contribution-history.service.ts->backend/src/modules/identity/public/identity-session.types.ts',
  'backend/src/modules/collaboration/api/sharing.controller.ts->backend/src/modules/identity/public/identity-session.types.ts',
  'backend/src/modules/collaboration/api/sharing.controller.ts->backend/src/modules/identity/public/current-user.decorator.ts',
  'backend/src/modules/collaboration/api/sharing.controller.ts->backend/src/modules/identity/public/jwt-auth.guard.ts',
  'backend/src/modules/collaboration/api/dto/verify-invite-otp.dto.ts->backend/src/modules/identity/public/max-utf8-bytes.decorator.ts',
  'backend/src/modules/collaboration/internal/invitation-delivery.service.ts->backend/src/modules/identity/public/identity-transient-delivery.port.ts',
  'backend/src/modules/collaboration/internal/invite-access.service.ts->backend/src/modules/identity/public/auth-error.ts',
  'backend/src/modules/collaboration/internal/invite-access.service.ts->backend/src/modules/identity/public/identity-auth.port.ts',
  'backend/src/modules/collaboration/internal/permission.service.ts->backend/src/modules/identity/public/identity-session.types.ts',
  'backend/src/modules/collaboration/internal/permission.service.ts->backend/src/modules/identity/public/user-lifecycle-lock.ts',
  'backend/src/modules/collaboration/internal/sharing.service.ts->backend/src/modules/identity/public/identity-session.types.ts',
  'backend/src/modules/collaboration/internal/sharing.service.ts->backend/src/modules/identity/public/context-key.ts',
  'backend/src/modules/collaboration/internal/sharing.service.ts->backend/src/modules/identity/public/user-lifecycle-lock.ts',
]);
const R6_CANONICAL_INJECTION_IDENTITIES = Object.freeze({
  transientDelivery: Object.freeze({
    token: 'backend/src/modules/identity/public/identity-transient-delivery.port.ts#IDENTITY_TRANSIENT_DELIVERY_PORT',
    parameterType: 'backend/src/modules/identity/public/identity-transient-delivery.port.ts#IdentityTransientDeliveryPort',
  }),
});
const R6_PUBLIC_PORT_PATH =
  'backend/src/modules/identity/public/identity-transient-delivery.port.ts';
const R6_CONSUMER_IDENTITIES = new Map([
  ['IDENTITY_TRANSIENT_DELIVERY_PORT', Object.freeze([
    R6_CANONICAL_INJECTION_IDENTITIES.transientDelivery,
  ])],
]);
const R6_EXACT_CONSTRUCTOR_USES = Object.freeze([
  Object.freeze({
    source: 'backend/src/modules/collaboration/internal/invitation-delivery.service.ts',
    consumerClass: 'backend/src/modules/collaboration/internal/invitation-delivery.service.ts#InvitationDeliveryService',
    parameter: 'transientDelivery',
    parameterIndex: 0,
    ...R6_CANONICAL_INJECTION_IDENTITIES.transientDelivery,
  }),
]);
const R4_CANONICAL_INJECTION_IDENTITIES = Object.freeze({
  planningBudgetWrite: Object.freeze({
    token: 'backend/src/modules/planning/public/planning-budget-write.port.ts#PLANNING_BUDGET_WRITE_PORT',
    parameterType: 'backend/src/modules/planning/public/planning-budget-write.port.ts#PlanningBudgetWritePort',
  }),
});
const R4_CONSUMER_IDENTITIES = new Map([
  ['PLANNING_BUDGET_WRITE_PORT', Object.freeze([
    R4_CANONICAL_INJECTION_IDENTITIES.planningBudgetWrite,
  ])],
]);
const R4_EXACT_CONSTRUCTOR_USES = Object.freeze([
  Object.freeze({
    source: 'backend/src/money/money-budget.service.ts',
    consumerClass: 'backend/src/money/money-budget.service.ts#MoneyBudgetService',
    parameter: 'planningBudgetWriter',
    parameterIndex: 2,
    ...R4_CANONICAL_INJECTION_IDENTITIES.planningBudgetWrite,
  }),
]);
const CONTRACT_SHAPE_HASH = '9a6a3d142b6b93e3e9cb4cc10f3585f737d4bc222368101264f3e48f5472609f';
const INITIAL_RETIRED_LEDGER_HASH = '18fb99438d6b7002ca3f55aac407985fa13252aff3a59073d126fa3dc4c9b3a3';
const MAX_ARRAY_ITEMS = 1000;
const MAX_TEXT_LENGTH = 2048;

function plainObject(value, label) {
  if (!value || typeof value !== 'object' || Array.isArray(value) || utilTypes.isProxy(value)
      || Object.getPrototypeOf(value) !== Object.prototype) {
    throw new Error(`${label} must be a plain object`);
  }
  for (const key of Reflect.ownKeys(value)) {
    if (typeof key !== 'string') throw new Error(`${label} must use string data properties only`);
    const descriptor = Object.getOwnPropertyDescriptor(value, key);
    if (!descriptor || !descriptor.enumerable
        || !Object.prototype.hasOwnProperty.call(descriptor, 'value')) {
      throw new Error(`${label} must use data properties; accessor found`);
    }
  }
  return value;
}

function denseArray(value, label) {
  if (!Array.isArray(value) || utilTypes.isProxy(value)
      || Object.getPrototypeOf(value) !== Array.prototype) {
    throw new Error(`${label} must be a plain array`);
  }
  if (value.length > MAX_ARRAY_ITEMS) throw new Error(`${label} is oversized`);
  for (let index = 0; index < value.length; index += 1) {
    const descriptor = Object.getOwnPropertyDescriptor(value, String(index));
    if (!descriptor) throw new Error(`${label} must be dense`);
    if (!descriptor.enumerable || !Object.prototype.hasOwnProperty.call(descriptor, 'value')) {
      throw new Error(`${label} must use data properties; accessor found`);
    }
  }
  const ownKeys = Reflect.ownKeys(value);
  if (ownKeys.some((key) => typeof key !== 'string') || ownKeys.length !== value.length + 1
      || !ownKeys.includes('length')) {
    throw new Error(`${label} must contain plain array data properties only`);
  }
  const lengthDescriptor = Object.getOwnPropertyDescriptor(value, 'length');
  if (!lengthDescriptor || !Object.prototype.hasOwnProperty.call(lengthDescriptor, 'value')) {
    throw new Error(`${label} must use a data length property`);
  }
  return value;
}

function assertDeepPlainData(value, label, seen = new Set(), depth = 0) {
  if (value === null || typeof value === 'string' || typeof value === 'boolean'
      || (typeof value === 'number' && Number.isFinite(value))) return;
  if (!value || typeof value !== 'object' || depth > 32 || seen.has(value)) {
    throw new Error(`${label} must be bounded plain data`);
  }
  seen.add(value);
  if (Array.isArray(value)) {
    const items = denseArray(value, label);
    for (let index = 0; index < items.length; index += 1) {
      const descriptor = Object.getOwnPropertyDescriptor(items, String(index));
      assertDeepPlainData(descriptor.value, `${label}[${index}]`, seen, depth + 1);
    }
  } else {
    const object = plainObject(value, label);
    for (const key of Object.keys(object)) {
      const descriptor = Object.getOwnPropertyDescriptor(object, key);
      assertDeepPlainData(descriptor.value, `${label}.${key}`, seen, depth + 1);
    }
  }
  seen.delete(value);
}

function exactObject(value, keys, label) {
  const object = plainObject(value, label);
  if (Object.keys(object).sort().join('|') !== [...keys].sort().join('|')) {
    throw new Error(`${label} keys are invalid`);
  }
  return object;
}

function text(value, label, pattern = null) {
  if (typeof value !== 'string' || value.length === 0 || value.length > MAX_TEXT_LENGTH
      || /[\u0000-\u0008\u000b\u000c\u000e-\u001f]/u.test(value)
      || (pattern && !pattern.test(value))) {
    throw new Error(`${label} has invalid length or text`);
  }
  return value;
}

function recordArray(value, label, validateRecord, keyOf) {
  const records = denseArray(value, label).map((item, index) => validateRecord(item, `${label}[${index}]`));
  const keys = records.map(keyOf);
  if (new Set(keys).size !== keys.length) throw new Error(`${label} contains a duplicate`);
  const sorted = [...keys].sort();
  if (keys.join('|') !== sorted.join('|')) throw new Error(`${label} is not in canonical order`);
  return records;
}

function sha256(value) {
  return crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
}

function uniqueStrings(value, label) {
  const items = denseArray(value, label);
  if (items.some((item) => typeof item !== 'string' || !item || item.length > MAX_TEXT_LENGTH)) {
    throw new Error(`${label} must contain bounded strings`);
  }
  if (new Set(items).size !== items.length) throw new Error(`${label} contains a duplicate`);
  return items;
}

function validateR3ContextManifest(value) {
  assertDeepPlainData(value, 'R3 context manifest');
  const manifest = plainObject(value, 'R3 context manifest');
  const required = [
    'schemaVersion', 'baseRevision', 'stage', 'contexts', 'contextRoots',
    'legacyModules', 'crossContextInjections', 'compositionDependencies',
    'providerContracts', 'decoratorRuntimeReferences', 'adminGuardMetadata',
    'runtimeDecoratorValueReferences', 'lifecycleProviders',
    'initialDuplicateProviders', 'remainingDuplicateProviders',
    'initialPlatformDebts', 'remainingPlatformDebts',
    'initialRetiredLegacyProviderEdges', 'remainingRetiredLegacyProviderEdges',
    'r7DependencyHandoff', 'r7ContributionHistoryHandoff', 'r7SharingHandoff',
    'allowedChangedPaths',
  ];
  if (Object.keys(manifest).sort().join('|') !== [...required].sort().join('|')) {
    throw new Error('R3 context manifest keys are invalid');
  }
  const stageMatch = typeof manifest.stage === 'string' && /^(?:inventory|task-[2-8]|strict)$/u.exec(manifest.stage);
  if (manifest.schemaVersion !== 1 || manifest.baseRevision !== R3_BASE || !stageMatch) {
    throw new Error('R3 context manifest identity is invalid');
  }
  const r7DependencyHandoff = exactObject(manifest.r7DependencyHandoff, [
    'baseRevision', 'historicalSha256', 'historicalRecords', 'liveRecords',
    'retiredDependencyKeys',
  ], 'R7 dependency handoff');
  if (JSON.stringify(r7DependencyHandoff) !== JSON.stringify(R7_DEPENDENCY_HANDOFF)) {
    throw new Error('R7 dependency handoff is not canonical');
  }
  const r7ContributionHistoryHandoff = exactObject(
    manifest.r7ContributionHistoryHandoff,
    [
      'baseRevision', 'from', 'to',
      'historicalDecoratorRuntimeReferencesSha256',
      'historicalRuntimeDecoratorValueReferencesSha256',
    ],
    'R7 Contribution History handoff',
  );
  if (JSON.stringify(r7ContributionHistoryHandoff)
      !== JSON.stringify(R7_CONTRIBUTION_HISTORY_HANDOFF)) {
    throw new Error('R7 Contribution History handoff is not canonical');
  }
  const r7SharingHandoff = exactObject(
    manifest.r7SharingHandoff,
    [
      'baseRevision', 'from', 'to',
      'historicalDecoratorRuntimeReferencesSha256',
      'historicalRuntimeDecoratorValueReferencesSha256',
    ],
    'R7 Sharing handoff',
  );
  if (JSON.stringify(r7SharingHandoff) !== JSON.stringify(R7_SHARING_HANDOFF)) {
    throw new Error('R7 Sharing handoff is not canonical');
  }
  const completedTask = manifest.stage === 'inventory'
    ? 1
    : manifest.stage === 'strict' ? 8 : Number(manifest.stage.slice('task-'.length));
  const contexts = uniqueStrings(manifest.contexts, 'contexts');
  if (contexts.join('|') !== CONTEXTS.join('|')) throw new Error('contexts do not match the canonical set');
  const contextRoots = denseArray(manifest.contextRoots, 'context roots').map((item, index) => {
    const record = exactObject(item, ['context', 'legacyRoots'], `context roots[${index}]`);
    text(record.context, 'context root context', /^[a-z-]+$/u);
    uniqueStrings(record.legacyRoots, 'context legacy roots').forEach((root) => text(root, 'legacy root', /^[a-z-]+$/u));
    return record;
  });
  if (JSON.stringify(contextRoots) !== JSON.stringify(Object.entries(ROOTS).map(([context, legacyRoots]) => ({ context, legacyRoots })))) {
    throw new Error('context root inventory is not canonical');
  }
  const validateStringList = (items, label) => uniqueStrings(items, label).map((item) => text(item, label));
  const legacyModules = recordArray(manifest.legacyModules, 'legacy modules', (item, label) => {
    const record = exactObject(item, ['path', 'className', 'imports', 'providers', 'exports', 'global'], label);
    text(record.path, `${label} path`, /^backend\/src\/.+\.ts$/u);
    text(record.className, `${label} class`, /^[A-Za-z_$][\w$]*$/u);
    for (const key of ['imports', 'providers', 'exports']) validateStringList(record[key], `${label} ${key}`);
    if (typeof record.global !== 'boolean') throw new Error(`${label} global is invalid`);
    return record;
  }, (record) => `${record.path}|${record.className}`);
  const injections = recordArray(manifest.crossContextInjections, 'cross-context injections', (item, label) => {
    const record = exactObject(item, ['source', 'parameter', 'target', 'targetPath', 'sourceContext', 'targetContext', 'kind'], label);
    text(record.source, `${label} source`, /^backend\/src\/.+\.ts$/u);
    text(record.targetPath, `${label} target path`, /^backend\/src\/.+\.ts$/u);
    for (const key of ['parameter', 'target']) text(record[key], `${label} ${key}`, /^[A-Za-z_$][\w$]*$/u);
    if (!CONTEXTS.includes(record.sourceContext) || !CONTEXTS.includes(record.targetContext)
        || record.sourceContext === record.targetContext || record.kind !== 'constructor-injection') {
      throw new Error(`${label} context or kind is invalid`);
    }
    return record;
  }, (record) => `${record.source}|${record.parameter}|${record.target}`);
  void legacyModules;
  void injections;
  const composition = denseArray(manifest.compositionDependencies, 'composition dependencies').map((item, index) => {
    const label = `composition dependencies[${index}]`;
    const record = exactObject(item, ['key', 'kind', 'retirementTask'], label);
    text(record.key, `${label} key`, /^[a-z0-9-]+$/u);
    if (!['module-availability', 'provider', 'module'].includes(record.kind)
        || ![2, 5].includes(record.retirementTask)) throw new Error(`${label} is invalid`);
    return record;
  });
  if (JSON.stringify(composition) !== JSON.stringify(COMPOSITION_DEPENDENCIES)) {
    throw new Error('composition dependency inventory is not canonical');
  }
  const providerContracts = denseArray(manifest.providerContracts, 'provider contracts').map((item, index) => {
    const label = `provider contracts[${index}]`;
    const record = exactObject(item, ['token', 'methods', 'implementations', 'consumers'], label);
    text(record.token, `${label} token`, /^[A-Z][A-Z0-9_]+$/u);
    validateStringList(record.methods, `${label} methods`).forEach((method) => text(method, `${label} method`, /^[A-Za-z_$][\w$]*$/u));
    validateStringList(record.implementations, `${label} implementations`).forEach((name) => text(name, `${label} implementation`, /^[A-Za-z_$][\w$]*$/u));
    recordArray(record.consumers, `${label} consumers`, (consumer, consumerLabel) => {
      const value = exactObject(consumer, ['source', 'kind'], consumerLabel);
      text(value.source, `${consumerLabel} source`, /^backend\/src\/.+\.ts$/u);
      if (!['constructor-injection', 'function-parameter', 'type-only', 'pure-function'].includes(value.kind)) {
        throw new Error(`${consumerLabel} kind is invalid`);
      }
      return value;
    }, (consumer) => `${consumer.source}|${consumer.kind}`);
    if (record.consumers.length === 0) throw new Error(`${label} has no present consumer`);
    return record;
  });
  const contractShape = providerContracts.map(({ token, methods, implementations }) => ({ token, methods, implementations }));
  if (sha256(contractShape) !== CONTRACT_SHAPE_HASH) throw new Error('provider contract inventory is not canonical');
  const validateUse = (item, label) => {
    const record = exactObject(item, ['controllerClass', 'method', 'routePrefix', 'routeMethod', 'routePath', 'parameterIndex'], label);
    text(record.controllerClass, `${label} controller`, /^[A-Za-z_$][\w$]*$/u);
    if (record.method !== null) text(record.method, `${label} method`, /^[A-Za-z_$][\w$]*$/u);
    for (const key of ['routePrefix', 'routePath']) {
      if (record[key] !== null && (typeof record[key] !== 'string' || record[key].length > MAX_TEXT_LENGTH
          || /[\u0000-\u0008\u000b\u000c\u000e-\u001f]/u.test(record[key]))) {
        throw new Error(`${label} ${key} is invalid`);
      }
    }
    if (record.routeMethod !== null) text(record.routeMethod, `${label} routeMethod`, /^[A-Z]+$/u);
    if (record.parameterIndex !== null && (!Number.isSafeInteger(record.parameterIndex) || record.parameterIndex < 0)) {
      throw new Error(`${label} parameter index is invalid`);
    }
    return record;
  };
  const validateDecoratorRecords = (items, label, kinds) => recordArray(items, label, (item, itemLabel) => {
    const record = exactObject(item, ['source', 'symbol', 'kind', 'uses'], itemLabel);
    text(record.source, `${itemLabel} source`, /^backend\/src\/.+\.ts$/u);
    text(record.symbol, `${itemLabel} symbol`, /^[A-Z][A-Za-z0-9_]+$/u);
    if (!kinds.includes(record.kind)) throw new Error(`${itemLabel} kind is invalid`);
    recordArray(record.uses, `${itemLabel} uses`, validateUse, (use) => (
      `${use.controllerClass}|${use.method}|${use.routeMethod}|${use.routePath}|${use.parameterIndex}`
    ));
    if (record.uses.length === 0) throw new Error(`${itemLabel} has no actual use`);
    return record;
  }, (record) => `${record.source}|${record.symbol}`);
  validateDecoratorRecords(manifest.decoratorRuntimeReferences, 'decorator runtime references', ['decorator-runtime']);
  validateDecoratorRecords(manifest.runtimeDecoratorValueReferences, 'runtime decorator value references', ['runtime-decorator', 'runtime-value']);
  recordArray(manifest.adminGuardMetadata, 'Admin guard metadata', (item, label) => {
    const record = exactObject(item, ['source', 'controllerClass', 'routePrefix', 'guards'], label);
    text(record.source, `${label} source`, /^backend\/src\/.+\.controller\.ts$/u);
    text(record.controllerClass, `${label} controller`, /^[A-Za-z_$][\w$]*$/u);
    text(record.routePrefix, `${label} route prefix`);
    validateStringList(record.guards, `${label} guards`).forEach((guard) => text(guard, `${label} guard`, /^[A-Za-z_$][\w$]*$/u));
    return record;
  }, (record) => `${record.source}|${record.controllerClass}`);
  recordArray(manifest.lifecycleProviders, 'lifecycle providers', (item, label) => {
    const record = exactObject(item, ['className', 'path'], label);
    text(record.className, `${label} class`, /^[A-Za-z_$][\w$]*$/u);
    text(record.path, `${label} path`, /^backend\/src\/.+\.ts$/u);
    return record;
  }, (record) => record.className);
  uniqueStrings(manifest.initialDuplicateProviders, 'initial duplicate providers');
  uniqueStrings(manifest.remainingDuplicateProviders, 'remaining duplicate providers');
  uniqueStrings(manifest.initialPlatformDebts, 'initial platform debts');
  uniqueStrings(manifest.remainingPlatformDebts, 'remaining platform debts');
  uniqueStrings(manifest.remainingRetiredLegacyProviderEdges, 'remaining retired legacy provider edges');
  uniqueStrings(manifest.allowedChangedPaths, 'allowed changed paths');
  if (manifest.initialDuplicateProviders.join('|') !== EXACT_DUPLICATE_PROVIDERS.join('|')) throw new Error('initial duplicate provider ledger is invalid');
  if (manifest.initialPlatformDebts.join('|') !== EXACT_PLATFORM_DEBTS.join('|')) throw new Error('initial platform debt ledger is invalid');
  const retiredKeys = manifest.initialRetiredLegacyProviderEdges.map((edge) => {
    const record = exactObject(edge, ['key', 'retirementTask'], 'retired legacy provider edge');
    if (typeof record.key !== 'string' || record.key.length > MAX_TEXT_LENGTH
        || !/^[^|]+\|[^|]+$/u.test(record.key) || ![2, 3, 4, 5, 7].includes(record.retirementTask)) {
      throw new Error('retired legacy provider edge is invalid');
    }
    return record.key;
  });
  if (new Set(retiredKeys).size !== retiredKeys.length) throw new Error('retired ledger contains a duplicate');
  if (retiredKeys.join('|') !== [...retiredKeys].sort().join('|')
      || sha256(manifest.initialRetiredLegacyProviderEdges) !== INITIAL_RETIRED_LEDGER_HASH) {
    throw new Error('initial retired legacy provider ledger is not canonical or immutable');
  }
  const expectedDuplicates = EXACT_DUPLICATE_PROVIDERS.filter((item) => DUPLICATE_RETIREMENT_TASK[item] > completedTask);
  const expectedPlatform = EXACT_PLATFORM_DEBTS.filter((item) => PLATFORM_RETIREMENT_TASK[item] > completedTask);
  const expectedRetired = manifest.initialRetiredLegacyProviderEdges
    .filter((item) => item.retirementTask > completedTask).map((item) => item.key);
  if (manifest.remainingDuplicateProviders.join('|') !== expectedDuplicates.join('|')) {
    throw new Error('duplicate provider retirement is early, late, or unscheduled for task');
  }
  if (manifest.remainingPlatformDebts.join('|') !== expectedPlatform.join('|')) {
    throw new Error('platform debt retirement is early, late, or unscheduled for task');
  }
  if (manifest.remainingRetiredLegacyProviderEdges.join('|') !== expectedRetired.join('|')) {
    throw new Error('retired legacy provider removal is early, late, renamed, or unscheduled for task');
  }
  return manifest;
}

function dependencyRecordKey(record) {
  return `${record.rule && record.rule.name}|${record.from}|${record.to}`;
}

function verifyR7DependencyHandoff(options) {
  const input = exactObject(options, [
    'historicalDependency', 'liveDependency',
  ], 'R7 dependency handoff input');
  assertDeepPlainData(input.historicalDependency, 'R7 historical dependency');
  if (!Array.isArray(input.historicalDependency)
      || input.historicalDependency.length !== R7_DEPENDENCY_HANDOFF.historicalRecords
      || sha256(input.historicalDependency) !== R7_DEPENDENCY_HANDOFF.historicalSha256) {
    throw new Error('R7 historical dependency identity is invalid');
  }
  assertDeepPlainData(input.liveDependency, 'R7 live dependency');
  if (!Array.isArray(input.liveDependency)) {
    throw new Error('R7 live dependency is invalid');
  }
  const retired = new Set(R7_DEPENDENCY_HANDOFF.retiredDependencyKeys);
  const expectedLive = input.historicalDependency.filter(
    (record) => !retired.has(dependencyRecordKey(record)),
  );
  if (expectedLive.length !== R7_DEPENDENCY_HANDOFF.liveRecords
      || input.liveDependency.length !== R7_DEPENDENCY_HANDOFF.liveRecords
      || JSON.stringify(input.liveDependency) !== JSON.stringify(expectedLive)) {
    throw new Error('R7 live dependency projection is invalid');
  }
  return Object.freeze({
    historicalDependencyRecords: input.historicalDependency.length,
    liveDependencyRecords: input.liveDependency.length,
    retiredDependencyRecords: input.historicalDependency.length - input.liveDependency.length,
  });
}

function verifyR12aSuccessorDependencyBaseline({ repoRoot, r12aManifest, readImmutableFile }) {
  const relative = 'backend/.dependency-cruiser-known-violations.json';
  const candidate = path.join(repoRoot, ...relative.split('/'));
  if (!fs.existsSync(candidate)) return null;
  const root = fs.realpathSync.native(repoRoot);
  const stat = fs.lstatSync(candidate);
  if (stat.isSymbolicLink() || !stat.isFile() || stat.size < 2 || stat.size > 2 * 1024 * 1024) {
    throw new Error('R3 dependency baseline is not a bounded plain file');
  }
  const real = fs.realpathSync.native(candidate);
  if (path.relative(root, real).startsWith('..')) throw new Error('R3 dependency baseline escapes repository');
  const entry = readR12aImmutableEntry({
    repositoryRoot: repoRoot,
    manifest: r12aManifest,
    readImmutableFile,
  });
  const expected = expectedR12aSuccessorDependencyRecords({
    repositoryRoot: repoRoot,
    r12aEntryRecords: entry.dependency,
    r12aManifest,
    readImmutableFile,
  });
  const bytes = fs.readFileSync(real);
  if (bytes.length !== stat.size || !Buffer.from(bytes.toString('utf8'), 'utf8').equals(bytes)) {
    throw new Error('R3 dependency baseline changed or is not exact UTF-8');
  }
  let live;
  try { live = JSON.parse(bytes.toString('utf8')); } catch { throw new Error('R3 dependency baseline contains invalid JSON'); }
  assertDeepPlainData(live, 'R3 dependency baseline');
  if (JSON.stringify(live) !== JSON.stringify(expected)) throw new Error('R3 successor dependency baseline drift detected');
  return live.length;
}

function projectR7HistoryDecoratorSources(records) {
  return records.map((record) => (
    record.source === R7_CONTRIBUTION_HISTORY_HANDOFF.from
      ? { ...record, source: R7_CONTRIBUTION_HISTORY_HANDOFF.to }
      : { ...record }
  )).sort((left, right) => {
    const leftKey = `${left.source}|${left.symbol}`;
    const rightKey = `${right.source}|${right.symbol}`;
    return leftKey < rightKey ? -1 : leftKey > rightKey ? 1 : 0;
  });
}

function projectR7SharingDecoratorSources(records) {
  return projectR7HistoryDecoratorSources(records).map((record) => (
    record.source === R7_SHARING_HANDOFF.from
      ? { ...record, source: R7_SHARING_HANDOFF.to }
      : { ...record }
  )).sort((left, right) => {
    const leftKey = `${left.source}|${left.symbol}`;
    const rightKey = `${right.source}|${right.symbol}`;
    return leftKey < rightKey ? -1 : leftKey > rightKey ? 1 : 0;
  });
}

function verifyR7HistoryDecoratorHandoff(options) {
  const input = exactObject(options, [
    'historicalDecoratorRuntimeReferences',
    'historicalRuntimeDecoratorValueReferences',
    'liveDecoratorRuntimeReferences',
    'liveRuntimeDecoratorValueReferences',
  ], 'R7 history decorator handoff input');
  assertDeepPlainData(
    input.historicalDecoratorRuntimeReferences,
    'R7 historical decorator references',
  );
  assertDeepPlainData(
    input.historicalRuntimeDecoratorValueReferences,
    'R7 historical runtime decorator references',
  );
  if (!Array.isArray(input.historicalDecoratorRuntimeReferences)
      || input.historicalDecoratorRuntimeReferences.length !== 23
      || sha256(input.historicalDecoratorRuntimeReferences)
        !== R7_CONTRIBUTION_HISTORY_HANDOFF.historicalDecoratorRuntimeReferencesSha256
      || !Array.isArray(input.historicalRuntimeDecoratorValueReferences)
      || input.historicalRuntimeDecoratorValueReferences.length !== 26
      || sha256(input.historicalRuntimeDecoratorValueReferences)
        !== R7_CONTRIBUTION_HISTORY_HANDOFF.historicalRuntimeDecoratorValueReferencesSha256) {
    throw new Error('R7 historical decorator identity is invalid');
  }
  assertDeepPlainData(input.liveDecoratorRuntimeReferences, 'R7 live decorator references');
  assertDeepPlainData(
    input.liveRuntimeDecoratorValueReferences,
    'R7 live runtime decorator references',
  );
  const expectedDecorator = projectR7HistoryDecoratorSources(
    input.historicalDecoratorRuntimeReferences,
  );
  const expectedRuntime = projectR7HistoryDecoratorSources(
    input.historicalRuntimeDecoratorValueReferences,
  );
  if (JSON.stringify(input.liveDecoratorRuntimeReferences) !== JSON.stringify(expectedDecorator)
      || JSON.stringify(input.liveRuntimeDecoratorValueReferences) !== JSON.stringify(expectedRuntime)) {
    throw new Error('R7 live decorator projection is invalid');
  }
  return Object.freeze({
    historicalDecoratorReferences: input.historicalDecoratorRuntimeReferences.length,
    historicalRuntimeDecoratorReferences:
      input.historicalRuntimeDecoratorValueReferences.length,
    liveDecoratorReferences: input.liveDecoratorRuntimeReferences.length,
    liveRuntimeDecoratorReferences: input.liveRuntimeDecoratorValueReferences.length,
    movedSources: 2,
  });
}

function verifyR7SharingDecoratorHandoff(options) {
  const input = exactObject(options, [
    'historicalDecoratorRuntimeReferences',
    'historicalRuntimeDecoratorValueReferences',
    'liveDecoratorRuntimeReferences',
    'liveRuntimeDecoratorValueReferences',
  ], 'R7 Sharing decorator handoff input');
  assertDeepPlainData(
    input.historicalDecoratorRuntimeReferences,
    'R7 historical decorator references',
  );
  assertDeepPlainData(
    input.historicalRuntimeDecoratorValueReferences,
    'R7 historical runtime decorator references',
  );
  if (!Array.isArray(input.historicalDecoratorRuntimeReferences)
      || input.historicalDecoratorRuntimeReferences.length !== 23
      || sha256(input.historicalDecoratorRuntimeReferences)
        !== R7_SHARING_HANDOFF.historicalDecoratorRuntimeReferencesSha256
      || !Array.isArray(input.historicalRuntimeDecoratorValueReferences)
      || input.historicalRuntimeDecoratorValueReferences.length !== 26
      || sha256(input.historicalRuntimeDecoratorValueReferences)
        !== R7_SHARING_HANDOFF.historicalRuntimeDecoratorValueReferencesSha256) {
    throw new Error('R7 historical decorator identity is invalid');
  }
  assertDeepPlainData(input.liveDecoratorRuntimeReferences, 'R7 live decorator references');
  assertDeepPlainData(
    input.liveRuntimeDecoratorValueReferences,
    'R7 live runtime decorator references',
  );
  const expectedDecorator = projectR7SharingDecoratorSources(
    input.historicalDecoratorRuntimeReferences,
  );
  const expectedRuntime = projectR7SharingDecoratorSources(
    input.historicalRuntimeDecoratorValueReferences,
  );
  if (JSON.stringify(input.liveDecoratorRuntimeReferences) !== JSON.stringify(expectedDecorator)
      || JSON.stringify(input.liveRuntimeDecoratorValueReferences) !== JSON.stringify(expectedRuntime)) {
    throw new Error('R7 live decorator projection is invalid');
  }
  return Object.freeze({
    historicalDecoratorReferences: input.historicalDecoratorRuntimeReferences.length,
    historicalRuntimeDecoratorReferences:
      input.historicalRuntimeDecoratorValueReferences.length,
    liveDecoratorReferences: input.liveDecoratorRuntimeReferences.length,
    liveRuntimeDecoratorReferences: input.liveRuntimeDecoratorValueReferences.length,
    movedSources: 2,
  });
}

function createProgram(backendRoot) {
  const configPath = path.join(backendRoot, 'tsconfig.json');
  const config = ts.readConfigFile(configPath, ts.sys.readFile);
  if (config.error) throw new Error('backend tsconfig cannot be read');
  const parsed = ts.parseJsonConfigFileContent(config.config, ts.sys, backendRoot, undefined, configPath);
  if (parsed.errors.length || !parsed.fileNames.length) throw new Error('backend tsconfig cannot be parsed');
  const program = ts.createProgram(parsed.fileNames, parsed.options);
  if (program.getSyntacticDiagnostics().length) throw new Error('backend source has syntax errors');
  return { program, checker: program.getTypeChecker() };
}

function repoPath(file, repoRoot) {
  const relative = path.relative(repoRoot, file);
  if (!relative || path.isAbsolute(relative) || relative === '..' || relative.startsWith(`..${path.sep}`)) {
    throw new Error('source path is outside repository');
  }
  return relative.replace(/\\/g, '/');
}

function alias(symbol, checker) {
  let current = symbol;
  const seen = new Set();
  while (current && (current.flags & ts.SymbolFlags.Alias) && !seen.has(current)) {
    seen.add(current);
    current = checker.getAliasedSymbol(current);
  }
  return current;
}

function nestSymbol(expression, expected, checker) {
  const target = ts.isPropertyAccessExpression(expression) ? expression.name : expression;
  const symbol = alias(checker.getSymbolAtLocation(target), checker);
  return Boolean(symbol && symbol.getName() === expected && (symbol.declarations || []).some((item) => (
    item.getSourceFile().fileName.replace(/\\/g, '/').includes('/node_modules/@nestjs/common/')
  )));
}

function decorators(node) {
  return ts.canHaveDecorators(node) ? (ts.getDecorators(node) || []) : [];
}

function decoratorCall(node, expected, checker) {
  return decorators(node).map((item) => item.expression).find((expression) => (
    ts.isCallExpression(expression) && nestSymbol(expression.expression, expected, checker)
  )) || null;
}

function lineOf(sourceFile, node) {
  return sourceFile.getLineAndCharacterOfPosition(node.getStart(sourceFile)).line + 1;
}

function addDiagnostic(diagnostics, kind, repositoryPath, sourceFile, node, extra = {}) {
  diagnostics.push({ kind, path: repositoryPath, line: lineOf(sourceFile, node || sourceFile), ...extra });
}

function expressionSymbol(expression, checker) {
  if (!expression) return null;
  const target = ts.isPropertyAccessExpression(expression) ? expression.name : expression;
  return alias(checker.getSymbolAtLocation(target), checker);
}

function symbolRepositoryDeclaration(symbol, repoRoot) {
  if (!symbol) return null;
  for (const declaration of symbol.declarations || []) {
    try {
      const declarationPath = repoPath(declaration.getSourceFile().fileName, repoRoot);
      if (declarationPath.startsWith('backend/src/')) return { declaration, declarationPath };
    } catch {
      // External declarations do not have repository identities.
    }
  }
  return null;
}

function symbolIdentity(expression, checker, repoRoot) {
  const symbol = expressionSymbol(expression, checker);
  const resolved = symbolRepositoryDeclaration(symbol, repoRoot);
  if (!symbol || !resolved) return null;
  return { symbol, name: symbol.getName(), ...resolved, key: `${resolved.declarationPath}#${symbol.getName()}` };
}

function resolvedIdentityFromSymbol(input, checker) {
  const symbol = alias(input, checker);
  if (!symbol) return null;
  const declaration = (symbol.declarations || [])[0];
  if (!declaration) return null;
  const declarationPath = path.resolve(declaration.getSourceFile().fileName).replace(/\\/g, '/');
  return {
    symbol,
    name: symbol.getName(),
    declaration,
    declarationPath,
    key: `${declarationPath}#${symbol.getName()}`,
  };
}

function resolvedSymbolIdentity(expression, checker) {
  return resolvedIdentityFromSymbol(expressionSymbol(expression, checker), checker);
}

function moduleExpressionIdentity(expression, checker) {
  let target = expression;
  if (ts.isCallExpression(target)) target = target.expression;
  if (ts.isPropertyAccessExpression(target)) target = target.expression;
  return resolvedSymbolIdentity(target, checker);
}

function canonicalExternalContractIdentity(contract, program, checker, backendRoot) {
  const containingFile = path.join(backendRoot, 'src', '__r3-contract-resolution__.ts');
  const resolution = ts.resolveModuleName(
    contract.packageName, containingFile, program.getCompilerOptions(), ts.sys,
  ).resolvedModule;
  if (!resolution) return null;
  const resolvedPath = path.resolve(resolution.resolvedFileName);
  const sourceFile = program.getSourceFiles().find(
    (candidate) => path.resolve(candidate.fileName) === resolvedPath,
  );
  if (!sourceFile) return null;
  const moduleSymbol = checker.getSymbolAtLocation(sourceFile) || sourceFile.symbol;
  if (!moduleSymbol) return null;
  const exports = new Map(checker.getExportsOfModule(moduleSymbol).map((item) => [item.getName(), item]));
  const implementation = resolvedIdentityFromSymbol(exports.get(contract.implementation), checker);
  const module = resolvedIdentityFromSymbol(exports.get(contract.module), checker);
  return implementation && module ? { implementation, module } : null;
}

function isDeclaredSymbolToken(identity) {
  if (!identity || !ts.isVariableDeclaration(identity.declaration) || !identity.declaration.initializer) return false;
  const initializer = identity.declaration.initializer;
  return ts.isCallExpression(initializer)
    && ts.isIdentifier(initializer.expression)
    && initializer.expression.text === 'Symbol'
    && initializer.arguments.length === 1
    && ts.isStringLiteral(initializer.arguments[0])
    && initializer.arguments[0].text === identity.name;
}

function classify(repositoryPath) {
  const prefix = 'backend/src/';
  if (!repositoryPath.startsWith(prefix)) return { kind: 'external' };
  const segments = repositoryPath.slice(prefix.length).split('/');
  if (segments[0] === 'application-composition') return { kind: 'composition' };
  if (segments[0] === 'platform') return { kind: 'platform' };
  if (segments[0] === 'modules') {
    return CONTEXTS.includes(segments[1])
      ? { kind: 'future', context: segments[1], slice: segments[2] || 'full' }
      : { kind: 'unknown-context' };
  }
  const context = ROOT_TO_CONTEXT.get(segments[0]);
  return context ? { kind: 'legacy', context } : { kind: 'other' };
}

function resolvedImportPath(sourceFile, specifier, program, repoRoot) {
  const result = ts.resolveModuleName(
    specifier, sourceFile.fileName, program.getCompilerOptions(), ts.sys,
  ).resolvedModule;
  if (!result) return null;
  try { return repoPath(result.resolvedFileName.replace(/\.d\.ts$/u, '.ts'), repoRoot); } catch { return null; }
}

function isTypeOnlyImport(node) {
  if (!node.importClause) return false;
  if (node.importClause.isTypeOnly) return true;
  const bindings = node.importClause.namedBindings;
  return Boolean(bindings && ts.isNamedImports(bindings) && bindings.elements.length
    && bindings.elements.every((element) => element.isTypeOnly));
}

function propertyName(property) {
  if (!property.name) return null;
  if (ts.isIdentifier(property.name) || ts.isStringLiteral(property.name)) return property.name.text;
  return null;
}

function moduleMetadata(classNode, call, sourceFile, repositoryPath, diagnostics) {
  const argument = call.arguments[0];
  const metadata = { imports: [], providers: [], exports: [] };
  if (!argument || !ts.isObjectLiteralExpression(argument)) {
    addDiagnostic(diagnostics, 'unresolved-nest-metadata', repositoryPath, sourceFile, call);
    return metadata;
  }
  for (const property of argument.properties) {
    if (!ts.isPropertyAssignment(property) || !propertyName(property)) {
      addDiagnostic(diagnostics, 'unresolved-nest-metadata', repositoryPath, sourceFile, property);
      continue;
    }
    const name = propertyName(property);
    if (!['imports', 'providers', 'exports'].includes(name)) continue;
    if (!ts.isArrayLiteralExpression(property.initializer)) {
      addDiagnostic(diagnostics, 'unresolved-nest-metadata', repositoryPath, sourceFile, property.initializer);
      continue;
    }
    metadata[name] = [...property.initializer.elements];
  }
  return { classNode, ...metadata };
}

function exactPropertyAssignments(object, names) {
  if (!ts.isObjectLiteralExpression(object) || object.properties.length !== names.length) return null;
  const properties = new Map();
  for (const property of object.properties) {
    if (!ts.isPropertyAssignment(property)) return null;
    const name = propertyName(property);
    if (!name || properties.has(name)) return null;
    properties.set(name, property.initializer);
  }
  return names.every((name) => properties.has(name)) ? properties : null;
}

function exactPropertyAccess(expression, root, property) {
  return ts.isPropertyAccessExpression(expression)
    && ts.isIdentifier(expression.expression)
    && expression.expression.text === root
    && expression.name.text === property;
}

function exactR4BudgetUpdateStatement(statement) {
  if (!ts.isExpressionStatement(statement) || !ts.isAwaitExpression(statement.expression)) return false;
  const call = statement.expression.expression;
  if (!ts.isCallExpression(call) || call.arguments.length !== 1
      || !ts.isPropertyAccessExpression(call.expression)
      || call.expression.name.text !== 'update'
      || !ts.isPropertyAccessExpression(call.expression.expression)
      || !exactPropertyAccess(call.expression.expression, 'tx', 'weddingPlan')) return false;
  const update = exactPropertyAssignments(call.arguments[0], ['where', 'data']);
  if (!update) return false;
  const where = exactPropertyAssignments(update.get('where'), ['id']);
  const data = exactPropertyAssignments(update.get('data'), ['estimatedBudget', 'currency']);
  return Boolean(where && data
    && exactPropertyAccess(where.get('id'), 'input', 'weddingPlanId')
    && exactPropertyAccess(data.get('estimatedBudget'), 'input', 'estimatedBudget')
    && exactPropertyAccess(data.get('currency'), 'input', 'currency'));
}

function exactR4BudgetDelegationStatement(statement) {
  if (!ts.isExpressionStatement(statement) || !ts.isAwaitExpression(statement.expression)) return false;
  const call = statement.expression.expression;
  return ts.isCallExpression(call)
    && ts.isIdentifier(call.expression)
    && call.expression.text === 'updateWeddingPlanBudgetInTransaction'
    && call.arguments.length === 2
    && ts.isIdentifier(call.arguments[0])
    && call.arguments[0].text === 'tx'
    && ts.isIdentifier(call.arguments[1])
    && call.arguments[1].text === 'input';
}

function scanR4PlanningBudgetWriterProgram(program, repoRoot) {
  const expectedPath = 'backend/src/modules/planning/internal/wedding-plan-budget-writer.ts';
  const repositoryPath = 'backend/src/modules/planning/infrastructure/wedding-plan.repository.ts';
  const sourceFile = program.getSourceFiles().find((candidate) => {
    if (candidate.isDeclarationFile) return false;
    try { return repoPath(candidate.fileName, repoRoot) === expectedPath; } catch { return false; }
  });
  if (!sourceFile) return { diagnostics: [] };
  const repositoryFile = program.getSourceFiles().find((candidate) => {
    if (candidate.isDeclarationFile) return false;
    try { return repoPath(candidate.fileName, repoRoot) === repositoryPath; } catch { return false; }
  });

  const diagnostics = [];
  const classes = sourceFile.statements.filter((statement) => (
    ts.isClassDeclaration(statement) && statement.name?.text === 'WeddingPlanBudgetWriter'
  ));
  const writer = classes.length === 1 ? classes[0] : null;
  const forbiddenImport = sourceFile.statements.some((statement) => {
    if (!ts.isImportDeclaration(statement) || !ts.isStringLiteral(statement.moduleSpecifier)) return false;
    const specifier = statement.moduleSpecifier.text.replace(/\\/gu, '/');
    const importsPrismaService = Boolean(statement.importClause?.namedBindings
      && ts.isNamedImports(statement.importClause.namedBindings)
      && statement.importClause.namedBindings.elements.some((element) => (
        (element.propertyName || element.name).text === 'PrismaService'
      )));
    return importsPrismaService || /(?:^|\/)(?:finance|money|budget-categories|wedding-costs)(?:\/|$)/u.test(specifier);
  });
  const members = writer ? [...writer.members] : [];
  const methods = members.filter(ts.isMethodDeclaration);
  const method = methods.length === 1 && methods[0].name
    && (ts.isIdentifier(methods[0].name) || ts.isStringLiteral(methods[0].name))
    && methods[0].name.text === 'updateBudgetInTransaction'
    ? methods[0] : null;
  const asyncModifier = Boolean(method?.modifiers?.some((modifier) => modifier.kind === ts.SyntaxKind.AsyncKeyword));
  const exactParameters = Boolean(method && method.parameters.length === 2
    && ts.isIdentifier(method.parameters[0].name) && method.parameters[0].name.text === 'tx'
    && ts.isIdentifier(method.parameters[1].name) && method.parameters[1].name.text === 'input');
  const exactBody = Boolean(method?.body && method.body.statements.length === 1
    && exactR4BudgetDelegationStatement(method.body.statements[0]));
  const exactRepositoryImport = sourceFile.statements.some((statement) => (
    ts.isImportDeclaration(statement)
    && ts.isStringLiteral(statement.moduleSpecifier)
    && statement.moduleSpecifier.text === '../infrastructure/wedding-plan.repository'
    && statement.importClause?.namedBindings
    && ts.isNamedImports(statement.importClause.namedBindings)
    && statement.importClause.namedBindings.elements.length === 1
    && statement.importClause.namedBindings.elements[0].name.text === 'updateWeddingPlanBudgetInTransaction'
  ));
  const repositoryFunctions = repositoryFile ? repositoryFile.statements.filter((statement) => (
    ts.isFunctionDeclaration(statement)
    && statement.name?.text === 'updateWeddingPlanBudgetInTransaction'
  )) : [];
  const repositoryFunction = repositoryFunctions.length === 1 ? repositoryFunctions[0] : null;
  const exactRepository = Boolean(repositoryFunction
    && repositoryFunction.modifiers?.some((modifier) => modifier.kind === ts.SyntaxKind.AsyncKeyword)
    && repositoryFunction.parameters.length === 2
    && ts.isIdentifier(repositoryFunction.parameters[0].name)
    && repositoryFunction.parameters[0].name.text === 'tx'
    && ts.isIdentifier(repositoryFunction.parameters[1].name)
    && repositoryFunction.parameters[1].name.text === 'input'
    && repositoryFunction.body?.statements.length === 1
    && exactR4BudgetUpdateStatement(repositoryFunction.body.statements[0]));
  const exactClass = Boolean(writer && classes.length === 1 && members.length === 1
    && method && asyncModifier && exactParameters && exactBody
    && exactRepositoryImport && exactRepository && !forbiddenImport);
  if (!exactClass) {
    addDiagnostic(diagnostics, 'r4-writer-isolation', expectedPath, sourceFile, writer || sourceFile);
  }
  return { diagnostics };
}

function scanR4PlanningBudgetWriter(options) {
  const repoRoot = path.resolve(options.repoRoot);
  const backendRoot = path.resolve(options.backendRoot);
  const { program } = createProgram(backendRoot);
  return scanR4PlanningBudgetWriterProgram(program, repoRoot);
}

function scanR3SourceLaws(options) {
  const repoRoot = path.resolve(options.repoRoot);
  const backendRoot = path.resolve(options.backendRoot);
  const { program, checker } = createProgram(backendRoot);
  const diagnostics = [];
  const modules = [];
  const imports = [];
  const providerContracts = [...(options.providerContracts || [])];
  const r12aManifest = options.r12aManifest === undefined
    ? null : validateR12aManifest(options.r12aManifest);
  const r12cAllowances = r12cSourceLawAllowances(repoRoot, options.r12cManifest || null);
  const contractsByToken = new Map(providerContracts.map((contract) => [
    contract.token,
    new Set(contract.implementations),
  ]));
  const enforceManifestImplementations = options.providerContracts !== undefined;
  // The frozen manifest names the contracts the relocation phases created;
  // every one of them must keep its exact implementation. After the R12C
  // closure the law also governs contracts the product adds later: a public
  // token is a contract when it is a declared `_PORT` Symbol of the owner's
  // public slice bound, `useExisting`, to the owner's `_IMPLEMENTATION` token
  // registered exactly once in an internal module the public module imports.
  // The R12C lifecycle contract keeps its own approved value-provider shape
  // and is governed by the R12C scanner, not by this law.
  const closedLiveContracts = Boolean(options.closed);
  const liveContractToken = (identity) => Boolean(identity
    && (!enforceManifestImplementations || closedLiveContracts)
    && identity.name.endsWith('_PORT')
    && !r12cAllowances.tokens.has(identity.key));
  const classIdentitiesByName = new Map();
  const sourceFiles = program.getSourceFiles().filter((sourceFile) => {
    if (sourceFile.isDeclarationFile) return false;
    try { return repoPath(sourceFile.fileName, repoRoot).startsWith('backend/src/'); } catch { return false; }
  });
  diagnostics.push(...scanR4PlanningBudgetWriterProgram(program, repoRoot).diagnostics);
  for (const sourceFile of sourceFiles) {
    const repositoryPath = repoPath(sourceFile.fileName, repoRoot);
    const sourceClass = classify(repositoryPath);
    if (sourceClass.kind === 'unknown-context') {
      addDiagnostic(diagnostics, 'unknown-context', repositoryPath, sourceFile, sourceFile);
    }
    const visit = (node) => {
      if (ts.isCallExpression(node) && nestSymbol(node.expression, 'forwardRef', checker)) {
        addDiagnostic(diagnostics, 'forward-ref', repositoryPath, sourceFile, node);
      }
      ts.forEachChild(node, visit);
    };
    visit(sourceFile);
    for (const statement of sourceFile.statements) {
      if (ts.isImportDeclaration(statement) && ts.isStringLiteral(statement.moduleSpecifier)) {
        if (repositoryPath === R6_PUBLIC_PORT_PATH) {
          addDiagnostic(
            diagnostics,
            'public-imports-concrete',
            repositoryPath,
            sourceFile,
            statement,
          );
        }
        const resolvedTargetPath = resolvedImportPath(sourceFile, statement.moduleSpecifier.text, program, repoRoot);
        const targetPath = resolvedTargetPath
          ? projectR12aPath(resolvedTargetPath, r12aManifest)
          : resolvedTargetPath;
        if (!targetPath) continue;
        const targetClass = classify(targetPath);
        imports.push({ sourcePath: repositoryPath, targetPath, sourceClass, targetClass, node: statement, sourceFile });
        if ((sourceClass.kind === 'platform' || sourceClass.kind === 'legacy' || sourceClass.kind === 'future')
            && targetClass.kind === 'composition') {
          addDiagnostic(diagnostics, 'illegal-composition-import', repositoryPath, sourceFile, statement);
        }
        if (sourceClass.kind === 'composition'
            && !(targetClass.kind === 'platform'
              || (targetClass.kind === 'future' && targetClass.slice === 'public')
              || targetClass.kind === 'external')) {
          addDiagnostic(diagnostics, 'illegal-composition-import', repositoryPath, sourceFile, statement);
        }
        if (sourceClass.kind === 'future' && targetClass.context && sourceClass.context !== targetClass.context) {
          const legalType = sourceClass.slice === 'public' && targetClass.kind === 'future'
            && targetClass.slice === 'public' && isTypeOnlyImport(statement);
          const importedNames = statement.importClause?.namedBindings
            && ts.isNamedImports(statement.importClause.namedBindings)
            ? statement.importClause.namedBindings.elements
              .map((item) => (item.propertyName || item.name).text).sort()
            : [];
          const sourceModuleImports = sourceFile.statements
            .filter(ts.isClassDeclaration)
            .flatMap((item) => {
              const call = decoratorCall(item, 'Module', checker);
              return call ? metadataTexts(call, 'imports', sourceFile) : [];
            });
          const legalPublicModuleDependency = sourceClass.slice === 'internal'
            && repositoryPath.endsWith('.internal.module.ts')
            && targetClass.kind === 'future' && targetClass.slice === 'public'
            && targetPath.endsWith('-public.module.ts')
            && importedNames.length > 0
            && importedNames.every((name) => sourceModuleImports.includes(name));
          const legalInternalPortDependency = ['internal', 'infrastructure'].includes(sourceClass.slice)
            && targetClass.kind === 'future' && targetClass.slice === 'public'
            && (sourceClass.slice === 'infrastructure' || targetPath.endsWith('.port.ts'));
          const r12aRuntimeTargetPath = r12aManifest && r12aManifest.stage === 'strict'
            ? (R12A_RUNTIME_PUBLIC_MOVES.get(resolvedTargetPath) || targetPath)
            : targetPath;
          const legalR12aRuntimePublicEdge = r12aManifest
            ? isAllowedR12aRuntimePublicEdge({
              sourcePath: repositoryPath,
              targetPath: r12aRuntimeTargetPath,
              importedNames,
              stage: r12aManifest.stage,
            }, r12aManifest)
            : false;
          const legalR7CollaborationRelocatedImport =
            R7_COLLABORATION_RELOCATED_IMPORTS.has(
              `${repositoryPath}->${targetPath}`,
            );
          const legalR12cRuntimePublicEdge = r12cAllowances.edges.has(`${repositoryPath}->${targetPath}`);
          if (!legalType && !legalPublicModuleDependency && !legalInternalPortDependency
              && !legalR12aRuntimePublicEdge
              && !legalR7CollaborationRelocatedImport
              && !legalR12cRuntimePublicEdge) {
            addDiagnostic(diagnostics, 'illegal-boundary-import', repositoryPath, sourceFile, statement);
          }
        }
        if (sourceClass.kind === 'future' && sourceClass.slice === 'public' && targetClass.kind === 'legacy') {
          addDiagnostic(diagnostics, 'public-imports-concrete', repositoryPath, sourceFile, statement);
        }
      }
      if (ts.isClassDeclaration(statement) && statement.name) {
        const classIdentity = symbolIdentity(statement.name, checker, repoRoot);
        if (classIdentity) {
          const identities = classIdentitiesByName.get(classIdentity.name) || [];
          identities.push(classIdentity);
          classIdentitiesByName.set(classIdentity.name, identities);
        }
        const call = decoratorCall(statement, 'Module', checker);
        if (!call) continue;
        modules.push({
          className: statement.name.text,
          path: repositoryPath,
          sourceFile,
          ...moduleMetadata(statement, call, sourceFile, repositoryPath, diagnostics),
        });
      }
    }
  }
  const providers = new Map();
  const modulesByIdentity = new Map(modules.map((module) => {
    const identity = symbolIdentity(module.classNode.name, checker, repoRoot);
    return identity ? [identity.key, module] : [null, null];
  }).filter(([key]) => key !== null));
  for (const module of modules) {
    for (const provider of module.providers) {
      if (!(ts.isIdentifier(provider) || ts.isPropertyAccessExpression(provider))) continue;
      const identity = symbolIdentity(provider, checker, repoRoot);
      if (!identity) continue;
      const list = providers.get(identity.key) || [];
      list.push({ module, node: provider, identity });
      providers.set(identity.key, list);
    }
  }
  const publicContractBindings = new Map();
  for (const module of modules) {
    const moduleClass = classify(module.path);
    if (moduleClass.kind !== 'future' || moduleClass.slice !== 'public') continue;
    for (const provider of module.providers) {
      if (!ts.isObjectLiteralExpression(provider)) continue;
      const properties = new Map(provider.properties.filter(ts.isPropertyAssignment)
        .map((item) => [propertyName(item), item]));
      const provide = properties.get('provide');
      const identity = provide && symbolIdentity(provide.initializer, checker, repoRoot);
      if (!identity || !(contractsByToken.has(identity.name)
          || liveContractToken(identity))) continue;
      const registrations = publicContractBindings.get(identity.name) || [];
      registrations.push({ module, provider, identity });
      publicContractBindings.set(identity.name, registrations);
    }
  }
  const internalModules = modules.filter((module) => {
    const moduleClass = classify(module.path);
    return moduleClass.kind === 'future' && moduleClass.slice === 'internal';
  });
  const externalContractIdentities = new Map([...EXTERNAL_PROVIDER_CONTRACTS].map(([token, contract]) => [
    token,
    canonicalExternalContractIdentity(contract, program, checker, backendRoot),
  ]));
  for (const module of modules) {
    if (!module.path.includes('/modules/') || !module.path.includes('/public/')) continue;
    const moduleClass = classify(module.path);
    const importedInternalModules = module.imports.map((expression) => symbolIdentity(expression, checker, repoRoot))
      .filter((identity) => identity && classify(identity.declarationPath).kind === 'future'
        && classify(identity.declarationPath).context === moduleClass.context
        && classify(identity.declarationPath).slice === 'internal');
    const importedInternalModuleSet = new Set(importedInternalModules
      .map((identity) => modulesByIdentity.get(identity.key)).filter(Boolean));
    const bindings = new Map();
    for (const provider of module.providers) {
      if (!ts.isObjectLiteralExpression(provider)) continue;
      const properties = new Map(provider.properties.filter(ts.isPropertyAssignment).map((item) => [propertyName(item), item]));
      const provide = properties.get('provide');
      if (!provide) continue;
      const publicToken = symbolIdentity(provide.initializer, checker, repoRoot);
      if (publicToken) bindings.set(publicToken.key, properties);
      if (!publicToken || publicToken.name.endsWith('_IMPLEMENTATION') || properties.has('useClass') || properties.has('useFactory')) {
        addDiagnostic(diagnostics, 'implementation-token-misuse', module.path, module.sourceFile, provider);
      }
      const manifestImplementations = publicToken && contractsByToken.get(publicToken.name);
      const isPublicContractToken = Boolean(publicToken && (
        manifestImplementations || liveContractToken(publicToken)
      ));
      if (isPublicContractToken) {
        const useExisting = properties.get('useExisting');
        const implementationToken = useExisting && symbolIdentity(useExisting.initializer, checker, repoRoot);
        const implementationClass = implementationToken ? classify(implementationToken.declarationPath) : null;
        const publicClass = classify(publicToken.declarationPath);
        const expectedImplementation = publicToken.name.replace(/_PORT$/u, '_IMPLEMENTATION');
        const expectedImplementationIdentities = manifestImplementations
          ? [...manifestImplementations].flatMap((name) => classIdentitiesByName.get(name) || [])
            .filter((identity) => {
              const identityClass = classify(identity.declarationPath);
              return identityClass.context === moduleClass.context && (
                identityClass.kind === 'legacy'
                || (identityClass.kind === 'future'
                  && ['internal', 'infrastructure'].includes(identityClass.slice))
              );
            })
          : [];
        const ownerInternalModules = internalModules.filter(
          (internalModule) => classify(internalModule.path).context === moduleClass.context,
        );
        const pairedInternalModules = implementationToken ? ownerInternalModules.filter((internalModule) => {
          const exportsImplementation = internalModule.exports.filter((expression) => (
            symbolIdentity(expression, checker, repoRoot)?.key === implementationToken.key
          )).length === 1;
          const bindings = internalModule.providers.filter((candidate) => {
            if (!ts.isObjectLiteralExpression(candidate)) return false;
            const internalProperties = new Map(candidate.properties.filter(ts.isPropertyAssignment)
              .map((item) => [propertyName(item), item]));
            const provide = internalProperties.get('provide');
            return Boolean(provide
              && symbolIdentity(provide.initializer, checker, repoRoot)?.key === implementationToken.key);
          });
          if (bindings.length !== 1) return false;
          const internalProperties = new Map(bindings[0].properties.filter(ts.isPropertyAssignment)
            .map((item) => [propertyName(item), item]));
          if (internalProperties.has('useClass') || internalProperties.has('useFactory')) return false;
          const targetProperty = internalProperties.get('useExisting');
          const target = targetProperty && symbolIdentity(targetProperty.initializer, checker, repoRoot);
          if (!target) return false;
          const exactManifestTarget = !enforceManifestImplementations
            || (closedLiveContracts && !manifestImplementations)
            || Boolean(manifestImplementations
              && expectedImplementationIdentities.some((identity) => identity.key === target.key));
          const registrations = providers.get(target.key) || [];
          const registeredExactlyOnce = registrations.length === 1
            && registrations[0].module === internalModule;
          const frozenMessagingBridge = publicToken.name === 'MESSAGING_REALTIME_PORT'
            && registrations.length === 1
            && registrations[0].module.path
              === 'backend/src/conversations/conversation-realtime.module.ts'
            && registrations[0].module.className === 'ConversationRealtimeModule'
            && internalModule.imports.some((expression) => {
              const importedIdentity = symbolIdentity(expression, checker, repoRoot);
              return importedIdentity
                && modulesByIdentity.get(importedIdentity.key) === registrations[0].module;
            });
          return exportsImplementation && exactManifestTarget
            && (registeredExactlyOnce || frozenMessagingBridge);
        }) : [];
        const publicTokenBindings = publicContractBindings.get(publicToken.name) || [];
        const publicBindingCount = publicTokenBindings.length;
        const publicBindingIdentityCount = new Set(
          publicTokenBindings.map((binding) => binding.identity.key),
        ).size;
        const publicBindingIdentityIsExact = publicBindingCount === 1
          && publicBindingIdentityCount === 1
          && publicTokenBindings[0].identity.key === publicToken.key;
        const manifestIdentityIsExact = !enforceManifestImplementations
          || (closedLiveContracts && !manifestImplementations)
          || Boolean(
            manifestImplementations && expectedImplementationIdentities.length === manifestImplementations.size,
          );
        const externalContract = EXTERNAL_PROVIDER_CONTRACTS.get(publicToken.name);
        let exactBinding = Boolean(implementationToken
          && implementationToken.name === expectedImplementation
          && implementationClass.kind === 'future' && implementationClass.slice === 'internal'
          && implementationClass.context === moduleClass.context && isDeclaredSymbolToken(implementationToken)
          && manifestIdentityIsExact && pairedInternalModules.length === 1
          && importedInternalModuleSet.has(pairedInternalModules[0]));
        if (externalContract) {
          const externalTarget = useExisting
            ? resolvedSymbolIdentity(useExisting.initializer, checker) : null;
          const canonicalExternal = externalContractIdentities.get(publicToken.name);
          const manifestExternalIsExact = Boolean(manifestImplementations
            && manifestImplementations.size === 1
            && manifestImplementations.has(externalContract.implementation));
          const pairedExternalModules = ownerInternalModules.filter((internalModule) => {
            const imports = internalModule.imports.map((expression) => moduleExpressionIdentity(expression, checker))
              .filter((identity) => canonicalExternal && identity.symbol === canonicalExternal.module.symbol);
            const exports = internalModule.exports.map((expression) => resolvedSymbolIdentity(expression, checker))
              .filter((identity) => canonicalExternal && identity.symbol === canonicalExternal.module.symbol);
            return imports.length === 1 && exports.length === 1;
          });
          exactBinding = Boolean(manifestExternalIsExact
            && canonicalExternal && externalTarget
            && externalTarget.symbol === canonicalExternal.implementation.symbol
            && pairedExternalModules.length === 1
            && importedInternalModuleSet.has(pairedExternalModules[0]));
        }
        if (!useExisting || !publicBindingIdentityIsExact
            || publicClass.kind !== 'future' || publicClass.slice !== 'public'
            || publicClass.context !== moduleClass.context || !isDeclaredSymbolToken(publicToken)
            || !exactBinding) {
          addDiagnostic(diagnostics, 'public-binding-not-use-existing', module.path, module.sourceFile, provider);
        }
      }
    }
    for (const exported of module.exports) {
      const identity = symbolIdentity(exported, checker, repoRoot);
      const isPublicContractToken = Boolean(identity && (
        contractsByToken.has(identity.name)
        || liveContractToken(identity)
        || r12cAllowances.tokens.has(identity.key)
      ));
      if (identity && isPublicContractToken && isDeclaredSymbolToken(identity)
          && classify(identity.declarationPath).context === moduleClass.context
          && classify(identity.declarationPath).slice === 'public') {
        if (!bindings.has(identity.key)) addDiagnostic(diagnostics, 'hollow-public-token', module.path, module.sourceFile, exported);
      } else {
        addDiagnostic(diagnostics, 'concrete-public-export', module.path, module.sourceFile, exported);
      }
    }
  }
  for (const registrations of providers.values()) {
    if (registrations.length < 2) continue;
    for (const registration of registrations) {
      addDiagnostic(diagnostics, 'duplicate-provider', registration.module.path, registration.module.sourceFile, registration.node, {
        provider: registration.identity.name,
        declarationPath: registration.identity.declarationPath,
      });
    }
  }
  const moduleBySymbol = new Map(modules.map((item) => [item.className, item]));
  const graph = new Map(modules.map((item) => [item.className, item.imports.filter(ts.isIdentifier).map((node) => node.text).filter((name) => moduleBySymbol.has(name))]));
  const visiting = new Set();
  const visited = new Set();
  let cycleFound = false;
  function walk(name) {
    if (visiting.has(name)) { cycleFound = true; return; }
    if (visited.has(name)) return;
    visiting.add(name);
    for (const next of graph.get(name) || []) walk(next);
    visiting.delete(name); visited.add(name);
  }
  for (const name of graph.keys()) walk(name);
  if (cycleFound && modules.length) {
    addDiagnostic(diagnostics, 'nest-module-cycle', modules[0].path, modules[0].sourceFile, modules[0].classNode);
  }
  diagnostics.sort((left, right) => `${left.path}|${left.line}|${left.kind}`.localeCompare(`${right.path}|${right.line}|${right.kind}`));
  return { modules: modules.map(({ className, path: modulePath }) => ({ className, path: modulePath })), diagnostics };
}

const ROUTE_DECORATORS = new Map([
  ['Get', 'GET'], ['Post', 'POST'], ['Put', 'PUT'], ['Patch', 'PATCH'],
  ['Delete', 'DELETE'], ['Options', 'OPTIONS'], ['Head', 'HEAD'], ['All', 'ALL'],
]);
const GUARD_DECLARATIONS = new Map([
  ['JwtAuthGuard', 'backend/src/modules/identity/public/jwt-auth.guard.ts'],
  ['JwtSessionGuard', 'backend/src/modules/identity/public/jwt-session.guard.ts'],
  ['AdminGuard', 'backend/src/admin/admin.guard.ts'],
  ['AdminPermissionGuard', 'backend/src/admin/admin-permission.guard.ts'],
]);
const CUSTOM_DECORATOR_DECLARATIONS = new Map([
  ['CurrentUser', 'backend/src/modules/identity/public/current-user.decorator.ts'],
  ['RequireAdminPermission', 'backend/src/admin/admin-permission.decorator.ts'],
]);

function staticDecoratorText(call) {
  if (!call || call.arguments.length === 0) return '';
  const value = call.arguments[0];
  return ts.isStringLiteralLike(value) || ts.isNoSubstitutionTemplateLiteral(value) ? value.text : null;
}

function routeForMethod(method, checker) {
  for (const [decoratorName, routeMethod] of ROUTE_DECORATORS) {
    const call = decoratorCall(method, decoratorName, checker);
    if (call) return { routeMethod, routePath: staticDecoratorText(call) };
  }
  return { routeMethod: null, routePath: null };
}

function namedDecoratorCall(node, expected, checker, repoRoot, declarations = CUSTOM_DECORATOR_DECLARATIONS) {
  return decorators(node).map((item) => item.expression).find((expression) => {
    if (!ts.isCallExpression(expression)) return false;
    const identity = symbolIdentity(expression.expression, checker, repoRoot);
    return Boolean(identity && identity.name === expected
      && identity.declarationPath === declarations.get(expected));
  }) || null;
}

function collectR3DecoratorInventory(options) {
  const repoRoot = path.resolve(options.repoRoot);
  const backendRoot = path.resolve(options.backendRoot);
  const supplied = options.program && options.checker
    ? { program: options.program, checker: options.checker }
    : createProgram(backendRoot);
  const { program, checker } = supplied;
  const r12aManifest = options.r12aManifest === undefined
    ? null : validateR12aManifest(options.r12aManifest);
  const projectedDeclaration = (value) => projectR12aPath(value, r12aManifest);
  const guardDeclarations = new Map([...GUARD_DECLARATIONS].map(([name, declaration]) => [
    name, projectedDeclaration(declaration),
  ]));
  const customDecoratorDeclarations = new Map([...CUSTOM_DECORATOR_DECLARATIONS].map(([name, declaration]) => [
    name, projectedDeclaration(declaration),
  ]));
  const groupedGuards = new Map();
  const groupedRuntime = new Map();
  const adminGuardMetadata = [];
  const sources = program.getSourceFiles().filter((sourceFile) => {
    if (sourceFile.isDeclarationFile) return false;
    try { return repoPath(sourceFile.fileName, repoRoot).startsWith('backend/src/'); } catch { return false; }
  }).sort((left, right) => repoPath(left.fileName, repoRoot).localeCompare(repoPath(right.fileName, repoRoot)));
  const addUse = (target, source, symbol, kind, use) => {
    const key = `${source}|${symbol}`;
    const record = target.get(key) || { source, symbol, kind, uses: [] };
    record.uses.push(use);
    target.set(key, record);
  };
  const useRecord = (controllerClass, method, routePrefix, routeMethod, routePath, parameterIndex = null) => ({
    controllerClass, method, routePrefix, routeMethod, routePath, parameterIndex,
  });
  for (const sourceFile of sources) {
    const source = repoPath(sourceFile.fileName, repoRoot);
    for (const statement of sourceFile.statements) {
      if (!ts.isClassDeclaration(statement) || !statement.name) continue;
      const controller = decoratorCall(statement, 'Controller', checker);
      if (!controller) continue;
      const controllerClass = statement.name.text;
      const routePrefix = staticDecoratorText(controller);
      if (routePrefix === null) throw new Error('controller route metadata is not statically resolvable');
      const collectGuards = (node, method, route) => {
        const call = decoratorCall(node, 'UseGuards', checker);
        if (!call) return [];
        const guardNames = [];
        for (const argument of call.arguments) {
          const identity = symbolIdentity(argument, checker, repoRoot);
          if (!identity) throw new Error('guard identity cannot be resolved');
          const exactGuard = guardDeclarations.get(identity.name) === identity.declarationPath;
          guardNames.push(exactGuard ? identity.name : `${identity.name}@${identity.declarationPath}`);
          if (exactGuard && ['JwtAuthGuard', 'JwtSessionGuard'].includes(identity.name)
              && source !== 'backend/src/modules/identity/api/auth.controller.ts') {
            addUse(groupedGuards, source, identity.name, 'decorator-runtime', useRecord(
              controllerClass, method, routePrefix, route.routeMethod, route.routePath,
            ));
          }
        }
        return guardNames;
      };
      const classGuards = collectGuards(statement, null, { routeMethod: null, routePath: null });
      if (classGuards.includes('AdminPermissionGuard')) {
        adminGuardMetadata.push({ source, controllerClass, routePrefix, guards: classGuards });
      }
      const classPermission = namedDecoratorCall(
        statement, 'RequireAdminPermission', checker, repoRoot, customDecoratorDeclarations,
      );
      if (classPermission) {
        addUse(groupedRuntime, source, 'RequireAdminPermission', 'runtime-decorator', useRecord(
          controllerClass, null, routePrefix, null, null,
        ));
      }
      for (const member of statement.members) {
        if (!ts.isMethodDeclaration(member) || !member.name) continue;
        const method = member.name.getText(sourceFile);
        const route = routeForMethod(member, checker);
        const methodGuards = collectGuards(member, method, route);
        if (methodGuards.includes('AdminPermissionGuard')) {
          throw new Error('Admin guard metadata must be controller-scoped');
        }
        if (namedDecoratorCall(
          member, 'RequireAdminPermission', checker, repoRoot, customDecoratorDeclarations,
        )) {
          addUse(groupedRuntime, source, 'RequireAdminPermission', 'runtime-decorator', useRecord(
            controllerClass, method, routePrefix, route.routeMethod, route.routePath,
          ));
        }
        for (let parameterIndex = 0; parameterIndex < member.parameters.length; parameterIndex += 1) {
          const parameter = member.parameters[parameterIndex];
          if (namedDecoratorCall(
            parameter, 'CurrentUser', checker, repoRoot, customDecoratorDeclarations,
          )
              && source !== 'backend/src/modules/identity/api/auth.controller.ts') {
            addUse(groupedRuntime, source, 'CurrentUser', 'runtime-decorator', useRecord(
              controllerClass, method, routePrefix, route.routeMethod, route.routePath, parameterIndex,
            ));
          }
        }
      }
    }
  }
  const metadataSource = sources.find((sourceFile) => (
    projectedDeclaration(repoPath(sourceFile.fileName, repoRoot))
      === projectedDeclaration('backend/src/admin/admin-permission.guard.ts')
  ));
  if (metadataSource) {
    let metadataUsed = false;
    let className = 'AdminPermissionGuard';
    for (const statement of metadataSource.statements) {
      if (ts.isClassDeclaration(statement) && statement.name) className = statement.name.text;
    }
    const visit = (node) => {
      if (ts.isIdentifier(node) && node.text === 'ADMIN_PERMISSIONS_KEY') {
        const symbol = alias(checker.getSymbolAtLocation(node), checker);
        const resolved = symbolRepositoryDeclaration(symbol, repoRoot);
        if (symbol && symbol.getName() === 'ADMIN_PERMISSIONS_KEY' && resolved
            && resolved.declarationPath === customDecoratorDeclarations.get('RequireAdminPermission')
            && !ts.isImportSpecifier(node.parent)) metadataUsed = true;
      }
      ts.forEachChild(node, visit);
    };
    visit(metadataSource);
    if (metadataUsed) {
      addUse(groupedRuntime, projectedDeclaration('backend/src/admin/admin-permission.guard.ts'), 'ADMIN_PERMISSIONS_KEY', 'runtime-value',
        useRecord(className, 'canActivate', null, null, null));
    }
  }
  const useKey = (use) => `${use.controllerClass}|${use.method}|${use.routeMethod}|${use.routePath}|${use.parameterIndex}`;
  const finalize = (map) => [...map.values()].map((record) => ({
    ...record,
    uses: record.uses.sort((left, right) => (useKey(left) < useKey(right) ? -1 : useKey(left) > useKey(right) ? 1 : 0)),
  })).sort((left, right) => {
    const leftKey = `${left.source}|${left.symbol}`;
    const rightKey = `${right.source}|${right.symbol}`;
    return leftKey < rightKey ? -1 : leftKey > rightKey ? 1 : 0;
  });
  adminGuardMetadata.sort((left, right) => {
    const leftKey = `${left.source}|${left.controllerClass}`;
    const rightKey = `${right.source}|${right.controllerClass}`;
    return leftKey < rightKey ? -1 : leftKey > rightKey ? 1 : 0;
  });
  return {
    decoratorRuntimeReferences: finalize(groupedGuards),
    runtimeDecoratorValueReferences: finalize(groupedRuntime),
    adminGuardMetadata,
  };
}

function metadataTexts(call, key, sourceFile) {
  const argument = call.arguments[0];
  if (!argument || !ts.isObjectLiteralExpression(argument)) return [];
  const property = argument.properties.find((item) => (
    ts.isPropertyAssignment(item) && propertyName(item) === key
  ));
  if (!property || !ts.isArrayLiteralExpression(property.initializer)) return [];
  return [...property.initializer.elements].map((item) => item.getText(sourceFile)).sort();
}

function collectLiveInventory(repoRoot, backendRoot, contractDefinitions, initialRetiredEdges, r12aManifest = null, r12cManifest = null) {
  const { program, checker } = createProgram(backendRoot);
  let globals = 0;
  const modules = [];
  const injections = [];
  const allConstructorUses = [];
  const importEdges = new Set();
  const sources = program.getSourceFiles().filter((sourceFile) => {
    if (sourceFile.isDeclarationFile) return false;
    try { return repoPath(sourceFile.fileName, repoRoot).startsWith('backend/src/'); } catch { return false; }
  }).sort((left, right) => repoPath(left.fileName, repoRoot).localeCompare(repoPath(right.fileName, repoRoot)));
  for (const sourceFile of sources) {
    const repositoryPath = repoPath(sourceFile.fileName, repoRoot);
    const first = repositoryPath.slice('backend/src/'.length).split('/')[0];
    const sourceContext = r12aManifest && ['backoffice', 'strict'].includes(r12aManifest.stage)
      ? classify(repositoryPath).context
      : ROOT_TO_CONTEXT.get(first);
    for (const statement of sourceFile.statements) {
      if (ts.isImportDeclaration(statement) && ts.isStringLiteral(statement.moduleSpecifier)) {
        const targetPath = resolvedImportPath(sourceFile, statement.moduleSpecifier.text, program, repoRoot);
        if (targetPath) importEdges.add(`${repositoryPath}|${targetPath}`);
      }
    }
    const visit = (node) => {
      if (ts.isClassDeclaration(node) && node.name) {
        const call = decoratorCall(node, 'Module', checker);
        if (call) {
          const global = Boolean(decoratorCall(node, 'Global', checker));
          if (global) globals += 1;
          modules.push({
            path: repositoryPath,
            className: node.name.text,
            imports: metadataTexts(call, 'imports', sourceFile),
            providers: metadataTexts(call, 'providers', sourceFile),
            exports: metadataTexts(call, 'exports', sourceFile),
            global,
          });
        }
      }
      if (ts.isConstructorDeclaration(node)) {
        const consumerClass = ts.isClassDeclaration(node.parent) && node.parent.name
          ? symbolIdentity(node.parent.name, checker, repoRoot)
          : null;
        for (const [parameterIndex, parameter] of node.parameters.entries()) {
          if (!parameter.type) continue;
          const expression = ts.isTypeReferenceNode(parameter.type) ? parameter.type.typeName : parameter.type;
          const symbol = alias(checker.getSymbolAtLocation(expression), checker);
          if (!symbol) continue;
          const injectCall = decoratorCall(parameter, 'Inject', checker);
          const injectionTokenExpression = injectCall?.arguments[0];
          const parameterTypeIdentity = symbolIdentity(expression, checker, repoRoot);
          const injectionTokenIdentity = symbolIdentity(injectionTokenExpression, checker, repoRoot);
          allConstructorUses.push({
            source: repositoryPath,
            consumerClassIdentity: consumerClass?.key || null,
            parameter: parameter.name.getText(sourceFile),
            parameterIndex,
            target: symbol.getName(),
            parameterTypeIdentity: parameterTypeIdentity?.key || null,
            injectionTokenIdentity: injectionTokenIdentity?.key || null,
          });
          if (!sourceContext) continue;
          const declaration = (symbol.declarations || []).find((item) => {
            try { return repoPath(item.getSourceFile().fileName, repoRoot).startsWith('backend/src/'); } catch { return false; }
          });
          if (!declaration) continue;
          const targetPath = repoPath(declaration.getSourceFile().fileName, repoRoot);
          const targetRoot = targetPath.slice('backend/src/'.length).split('/')[0];
          const targetContext = r12aManifest && ['backoffice', 'strict'].includes(r12aManifest.stage)
            ? (targetPath.startsWith('backend/src/modules/backoffice/public/')
              ? classify(targetPath).context
              : ROOT_TO_CONTEXT.get(targetRoot))
            : ROOT_TO_CONTEXT.get(targetRoot);
          if (targetContext && targetContext !== sourceContext) {
            injections.push({
              source: repositoryPath,
              parameter: parameter.name.getText(sourceFile),
              target: symbol.getName(),
              targetPath,
              sourceContext,
              targetContext,
              kind: 'constructor-injection',
            });
          }
        }
      }
      ts.forEachChild(node, visit);
    };
    visit(sourceFile);
  }
  modules.sort((left, right) => `${left.path}|${left.className}`.localeCompare(`${right.path}|${right.className}`));
  injections.sort((left, right) => `${left.source}|${left.parameter}|${left.target}`.localeCompare(`${right.source}|${right.parameter}|${right.target}`));
  const decoratorInventory = collectR3DecoratorInventory({
    repoRoot, backendRoot, program, checker, r12aManifest,
  });
  const lifecycleNames = new Set([
    'AuthChallengeCleanupScheduler', 'ConversationsGateway', 'IdempotencyCleanupScheduler',
    'LoginThrottleCleanupScheduler', 'MediaUploadCleanupScheduler',
    'NotificationRemindersScheduler', 'OtpDispatchQuotaCleanupScheduler',
    'OutboxCleanupScheduler', 'OutboxDispatcher', 'OutboxWorker',
  ]);
  const lifecycleProviders = [];
  for (const sourceFile of sources) {
    for (const statement of sourceFile.statements) {
      if (ts.isClassDeclaration(statement) && statement.name && lifecycleNames.has(statement.name.text)) {
        lifecycleProviders.push({ className: statement.name.text, path: repoPath(sourceFile.fileName, repoRoot) });
      }
    }
  }
  lifecycleProviders.sort((left, right) => left.className.localeCompare(right.className));
  const moduleByName = new Map(modules.map((item) => [item.className, item]));
  const compositionDependencies = [];
  const authModule = moduleByName.get('AuthModule');
  const appModule = moduleByName.get('AppModule');
  if (authModule && appModule && authModule.exports.includes('JwtModule') && appModule.imports.includes('AuthModule')) {
    compositionDependencies.push(COMPOSITION_DEPENDENCIES[0]);
  }
  const compositionEdges = [
    ['backend/src/platform/health/readiness.service.ts|backend/src/media/media-storage.service.ts', COMPOSITION_DEPENDENCIES[1]],
    ['backend/src/platform/outbox/outbox.dispatcher.ts|backend/src/conversations/conversation-realtime.publisher.ts', COMPOSITION_DEPENDENCIES[2]],
    ['backend/src/platform/outbox/outbox.dispatcher.ts|backend/src/push/push-delivery.service.ts', COMPOSITION_DEPENDENCIES[3]],
    ['backend/src/platform/outbox/outbox.module.ts|backend/src/conversations/conversation-realtime.module.ts', COMPOSITION_DEPENDENCIES[4]],
    ['backend/src/platform/outbox/outbox.module.ts|backend/src/push/push.module.ts', COMPOSITION_DEPENDENCIES[5]],
  ];
  for (const [edge, record] of compositionEdges) if (importEdges.has(edge)) compositionDependencies.push(record);
  const declarationsByName = new Map();
  for (const sourceFile of program.getSourceFiles()) {
    for (const statement of sourceFile.statements) {
      if (ts.isClassDeclaration(statement) && statement.name) declarationsByName.set(statement.name.text, statement);
    }
  }
  const providerContracts = contractDefinitions.map((contract) => {
    const canonicalConsumerIdentities = TASK2_CONSUMER_IDENTITIES.get(contract.token)
      || TASK3_CONSUMER_IDENTITIES.get(contract.token)
      || TASK4_CONSUMER_IDENTITIES.get(contract.token)
      || TASK5_CONSUMER_IDENTITIES.get(contract.token)
      || R6_CONSUMER_IDENTITIES.get(contract.token)
      || R4_CONSUMER_IDENTITIES.get(contract.token);
    const consumers = canonicalConsumerIdentities
      ? []
      : injections.filter((item) => contract.implementations.includes(item.target))
        .map((item) => ({ source: item.source, kind: 'constructor-injection' }));
    if (canonicalConsumerIdentities) {
      for (const use of allConstructorUses) {
        if (canonicalConsumerIdentities.some((identity) => (
          use.injectionTokenIdentity === identity.token
            && use.parameterTypeIdentity === identity.parameterType
        ))) {
          consumers.push({ source: use.source, kind: 'constructor-injection' });
        }
      }
    }
    if (contract.token === 'IDENTITY_ACCESS_TOKEN_VERIFIER'
        && allConstructorUses.some((item) => item.source === 'backend/src/conversations/conversations.gateway.ts'
          && item.target === 'JwtService')) {
      consumers.push({ source: 'backend/src/conversations/conversations.gateway.ts', kind: 'constructor-injection' });
    }
    const uniqueConsumers = [...new Map(consumers.map((item) => [
      `${item.source}|${item.kind}`,
      item,
    ])).values()];
    uniqueConsumers.sort((left, right) => `${left.source}|${left.kind}`.localeCompare(`${right.source}|${right.kind}`));
    let surfacePresent = true;
    for (const implementation of contract.implementations) {
      let declaration = declarationsByName.get(implementation);
      if (!declaration) {
        for (const sourceFile of program.getSourceFiles()) {
          const symbol = checker.getSymbolAtLocation(sourceFile);
          if (!symbol) continue;
          const exported = checker.getExportsOfModule(symbol).find((item) => item.getName() === implementation);
          if (exported) declaration = (alias(exported, checker).declarations || []).find(ts.isClassDeclaration);
          if (declaration) break;
        }
      }
      if (!declaration) { surfacePresent = false; continue; }
      const type = checker.getTypeAtLocation(declaration);
      const properties = new Set(checker.getPropertiesOfType(type).map((item) => item.getName()));
      if (contract.methods.some((method) => !properties.has(method))) surfacePresent = false;
    }
    return { ...contract, consumers: uniqueConsumers, surfacePresent };
  });
  const task2CanonicalPairs = new Set(Object.values(TASK2_CANONICAL_INJECTION_IDENTITIES)
    .map((identity) => `${identity.token}|${identity.parameterType}`));
  const task2ConstructorUseKey = (item) => (
    `${item.source}|${item.consumerClassIdentity || item.consumerClass}|${item.parameter}|${item.parameterIndex}`
      + `|${item.injectionTokenIdentity || item.token}|${item.parameterTypeIdentity || item.parameterType}`
  );
  const liveTask2ConstructorUses = allConstructorUses.filter((item) => task2CanonicalPairs.has(
    `${item.injectionTokenIdentity}|${item.parameterTypeIdentity}`,
  )).map(task2ConstructorUseKey).sort();
  const exactTask2ConstructorUses = projectR12cConstructorUses(TASK2_EXACT_CONSTRUCTOR_USES, r12cManifest).map(task2ConstructorUseKey).sort();
  const task2ConstructorInventoryPresent = JSON.stringify(liveTask2ConstructorUses)
    === JSON.stringify(exactTask2ConstructorUses);
  const task3CanonicalPairs = new Set(Object.values(TASK3_CANONICAL_INJECTION_IDENTITIES)
    .map((identity) => `${identity.token}|${identity.parameterType}`));
  const liveTask3ConstructorUses = allConstructorUses.filter((item) => task3CanonicalPairs.has(
    `${item.injectionTokenIdentity}|${item.parameterTypeIdentity}`,
  )).map(task2ConstructorUseKey).sort();
  const exactTask3ConstructorUses = projectR12cConstructorUses(TASK3_EXACT_CONSTRUCTOR_USES, r12cManifest).map(task2ConstructorUseKey).sort();
  const task3ConstructorInventoryPresent = JSON.stringify(liveTask3ConstructorUses)
    === JSON.stringify(exactTask3ConstructorUses);
  const task4CanonicalPairs = new Set(Object.values(TASK4_CANONICAL_INJECTION_IDENTITIES)
    .map((identity) => `${identity.token}|${identity.parameterType}`));
  const liveTask4ConstructorUses = allConstructorUses.filter((item) => task4CanonicalPairs.has(
    `${item.injectionTokenIdentity}|${item.parameterTypeIdentity}`,
  )).map(task2ConstructorUseKey).sort();
  const exactTask4ConstructorUses = projectR12cConstructorUses(TASK4_EXACT_CONSTRUCTOR_USES, r12cManifest).map(task2ConstructorUseKey).sort();
  const task4ConstructorInventoryPresent = JSON.stringify(liveTask4ConstructorUses)
    === JSON.stringify(exactTask4ConstructorUses);
  const task5CanonicalPairs = new Set(Object.values(TASK5_CANONICAL_INJECTION_IDENTITIES)
    .map((identity) => `${identity.token}|${identity.parameterType}`));
  const liveTask5ConstructorUses = allConstructorUses.filter((item) => task5CanonicalPairs.has(
    `${item.injectionTokenIdentity}|${item.parameterTypeIdentity}`,
  )).map(task2ConstructorUseKey).sort();
  const exactTask5ConstructorUses = projectR12cConstructorUses(TASK5_EXACT_CONSTRUCTOR_USES, r12cManifest).map(task2ConstructorUseKey).sort();
  const task5ConstructorInventoryPresent = JSON.stringify(liveTask5ConstructorUses)
    === JSON.stringify(exactTask5ConstructorUses);
  const r6CanonicalPairs = new Set(Object.values(R6_CANONICAL_INJECTION_IDENTITIES)
    .map((identity) => `${identity.token}|${identity.parameterType}`));
  const liveR6ConstructorUses = allConstructorUses.filter((item) => r6CanonicalPairs.has(
    `${item.injectionTokenIdentity}|${item.parameterTypeIdentity}`,
  )).map(task2ConstructorUseKey).sort();
  const exactR6ConstructorUses = projectR12cConstructorUses(R6_EXACT_CONSTRUCTOR_USES, r12cManifest).map(task2ConstructorUseKey).sort();
  const r6ConstructorInventoryPresent = JSON.stringify(liveR6ConstructorUses)
    === JSON.stringify(exactR6ConstructorUses);
  const r4CanonicalPairs = new Set(Object.values(R4_CANONICAL_INJECTION_IDENTITIES)
    .map((identity) => `${identity.token}|${identity.parameterType}`));
  const liveR4ConstructorUses = allConstructorUses.filter((item) => r4CanonicalPairs.has(
    `${item.injectionTokenIdentity}|${item.parameterTypeIdentity}`,
  )).map(task2ConstructorUseKey).sort();
  const exactR4ConstructorUses = projectR12cConstructorUses(R4_EXACT_CONSTRUCTOR_USES, r12cManifest).map(task2ConstructorUseKey).sort();
  const r4ConstructorInventoryPresent = JSON.stringify(liveR4ConstructorUses)
    === JSON.stringify(exactR4ConstructorUses);
  const retiredEdges = initialRetiredEdges.filter((edge) => {
    const [from, to] = edge.key.split('|');
    return importEdges.has(`backend/${from}|backend/${to}`);
  });
  return {
    modules, globals, injections, compositionDependencies,
    providerContracts: providerContracts.map(({ surfacePresent, ...contract }) => contract),
    providerContractSurfacesPresent: providerContracts.every((item) => item.surfacePresent),
    task2ConstructorInventoryPresent,
    task3ConstructorInventoryPresent,
    task4ConstructorInventoryPresent,
    task5ConstructorInventoryPresent,
    r6ConstructorInventoryPresent,
    r4ConstructorInventoryPresent,
    ...decoratorInventory,
    lifecycleProviders, retiredEdges,
    constructorUses: allConstructorUses,
  };
}

// Injection-identity law (closed successor). Every public contract token and
// port interface this scanner ever froze may be injected by any consumer, but
// only as its real declaration: a same-name Symbol or interface declared
// elsewhere is a lookalike, and a canonical token paired with a non-canonical
// parameter type (or the reverse) is a mismatched injection. Positions and
// consumer sets are not law.
const CANONICAL_INJECTION_GROUPS = Object.freeze([
  TASK2_CANONICAL_INJECTION_IDENTITIES, TASK3_CANONICAL_INJECTION_IDENTITIES,
  TASK4_CANONICAL_INJECTION_IDENTITIES, TASK5_CANONICAL_INJECTION_IDENTITIES,
  R6_CANONICAL_INJECTION_IDENTITIES, R4_CANONICAL_INJECTION_IDENTITIES,
]);

function canonicalInjectionIdentities() {
  const tokensByName = new Map();
  const typesByName = new Map();
  const pairs = new Set();
  for (const group of CANONICAL_INJECTION_GROUPS) {
    for (const identity of Object.values(group)) {
      tokensByName.set(identity.token.split('#')[1], identity.token);
      typesByName.set(identity.parameterType.split('#')[1], identity.parameterType);
      pairs.add(`${identity.token}|${identity.parameterType}`);
    }
  }
  return { tokensByName, typesByName, pairs };
}

function injectionIdentityDiagnostics(constructorUses) {
  const { tokensByName, typesByName, pairs } = canonicalInjectionIdentities();
  const diagnostics = [];
  for (const use of constructorUses) {
    const tokenName = use.injectionTokenIdentity ? use.injectionTokenIdentity.split('#')[1] : null;
    const typeName = use.parameterTypeIdentity ? use.parameterTypeIdentity.split('#')[1] : null;
    const canonicalToken = tokenName ? tokensByName.get(tokenName) : undefined;
    const canonicalType = typeName ? typesByName.get(typeName) : undefined;
    const tokenLookalike = canonicalToken !== undefined && canonicalToken !== use.injectionTokenIdentity;
    const typeLookalike = canonicalType !== undefined && canonicalType !== use.parameterTypeIdentity;
    const canonicalUse = canonicalToken === use.injectionTokenIdentity || canonicalType === use.parameterTypeIdentity;
    const mismatched = canonicalUse && !pairs.has(`${use.injectionTokenIdentity}|${use.parameterTypeIdentity}`);
    if (tokenLookalike || typeLookalike || mismatched) {
      diagnostics.push({ kind: 'injection-identity-drift', path: use.source, line: 1 });
    }
  }
  return diagnostics;
}

function scanR12cPredecessorContexts(options, successorManifest) {
  const r12c = require('./r12c-zero-cross-context-dependencies-scan.cjs');
  // Prove the actual successor before exposing any historical read view.
  // This executes the complete R12C and R12B laws, not just manifest shape.
  r12c.scanR12cZeroCrossContextDependencies({
    repositoryRoot: options.repoRoot, manifest: successorManifest,
  });
  const projection = r12c.projectR12cWorkingTreeToPredecessor({
    repositoryRoot: options.repoRoot, manifest: successorManifest,
  });
  const relativeSource = (file) => {
    const relative = path.relative(options.repoRoot, path.resolve(file)).replaceAll('\\', '/');
    return relative.startsWith('backend/src/') ? relative : null;
  };
  const projectedSys = {
    ...ts.sys,
    fileExists(file) {
      const relative = relativeSource(file);
      return relative === null ? ts.sys.fileExists(file) : projection.pathExists(relative);
    },
    readFile(file) {
      const relative = relativeSource(file);
      return relative === null ? ts.sys.readFile(file)
        : projection.pathExists(relative) ? projection.readWorkingFile(relative)?.toString('utf8') : undefined;
    },
  };
  const historicalTs = {
    ...ts,
    sys: projectedSys,
    createProgram(input, compilerOptions) {
      const rootNames = Array.isArray(input) ? input : input.rootNames;
      const programOptions = Array.isArray(input) ? compilerOptions : input.options;
      const restored = [
        successorManifest.financePublicCandidate.move.source,
        successorManifest.marketplacePublicCandidate.move.source,
      ].map((relative) => path.join(options.repoRoot, ...relative.split('/')));
      const names = [...new Set([...rootNames, ...restored])].filter(projectedSys.fileExists);
      const host = ts.createCompilerHost(programOptions);
      host.fileExists = projectedSys.fileExists;
      host.readFile = projectedSys.readFile;
      host.getSourceFile = (file, languageVersion) => {
        const source = projectedSys.readFile(file);
        return source === undefined ? undefined : ts.createSourceFile(file, source, languageVersion, true);
      };
      return ts.createProgram(names, programOptions, host);
    },
  };
  const loadHistorical = (relative) => {
    const file = path.join(options.repoRoot, ...relative.split('/'));
    const nativeRequire = createRequire(file);
    const projectedModule = { exports: {} };
    const compile = new vm.Script(wrapModule(projection.readWorkingFile(relative).toString('utf8')), {
      filename: `${file}#r12c-predecessor`,
    }).runInThisContext();
    compile(projectedModule.exports, (request) => {
      if (request === 'typescript') return historicalTs;
      if (request === './ports-scan.cjs') return loadHistorical('backend/scripts/architecture/ports-scan.cjs');
      return nativeRequire(request);
    }, projectedModule, file, path.dirname(file));
    return projectedModule.exports;
  };
  // These exact reconstructed scanners predate this successor hook. All their
  // source laws and inventories run unchanged; neither scanner can recurse.
  return loadHistorical('backend/scripts/architecture/r3-context-scan.cjs').scanR3Contexts(options);
}

function scanR3Contexts(options) {
  const successorPath = path.join(options.repoRoot, 'backend/architecture/r12c-zero-cross-context-dependencies.json');
  // While R12C is open, the live command proves the successor and then
  // replays the R3 law over the reconstructed predecessor; once R12C is
  // closed, the R3 law applies to the live tree again.
  if (fs.existsSync(successorPath)
      && !require('./modular-monolith-closure.cjs').readClosure(options.repoRoot)) {
    return scanR12cPredecessorContexts(options, JSON.parse(fs.readFileSync(successorPath, 'utf8')));
  }
  const r12aManifest = options.r12aManifest === undefined
    ? validateR12aManifest(JSON.parse(fs.readFileSync(
      options.r12aManifestPath || R12A_MANIFEST_PATH,
      'utf8',
    )))
    : validateR12aManifest(options.r12aManifest);
  verifyR12aSuccessorDependencyBaseline({
    repoRoot: options.repoRoot,
    r12aManifest,
    readImmutableFile: options.readImmutableFile,
  });
  const historicalManifest = validateR3ContextManifest(
    JSON.parse(fs.readFileSync(options.manifestPath, 'utf8')),
  );
  const r8Manifest = validateR8Manifest(JSON.parse(fs.readFileSync(
    options.r8ManifestPath || R8_MANIFEST_PATH,
    'utf8',
  )));
  if (r8Manifest.stage !== 'strict') throw new Error('R8 strict projection is required');
  let projectionValid = true;
  let manifest;
  try {
    manifest = projectR3InventoryForR8(historicalManifest, r8Manifest);
  } catch {
    projectionValid = false;
    manifest = historicalManifest;
  }
  if (options.stage !== manifest.stage) throw new Error('R3 stage does not match manifest');
  const contractDefinitions = manifest.providerContracts.map(({ token, methods, implementations }) => ({
    token, methods, implementations,
  }));
  // Fixtures pass the closed R12C manifest explicitly (they are not Git
  // repositories); the live command detects the closure from the tree.
  const r12cManifest = options.r12cManifest !== undefined
    ? require('./r12c-zero-cross-context-dependencies-scan.cjs').validateR12cManifest(options.r12cManifest)
    : r12cSuccessor(options.repoRoot);
  const closed = options.r12cManifest !== undefined
    ? Boolean(options.closed)
    : Boolean(require('./modular-monolith-closure.cjs').readClosure(options.repoRoot));
  const sourceLawScan = options.sourceLawScan || scanR3SourceLaws;
  const sourceLaws = sourceLawScan({
    repoRoot: options.repoRoot,
    backendRoot: options.backendRoot,
    providerContracts: contractDefinitions,
    r12aManifest,
    r12cManifest,
    closed,
  });
  const projectedHistoricalManifest = projectR12aInventory(
    { ...manifest, legacyModules: projectR12cModules(manifest.legacyModules, r12cManifest) },
    r12aManifest,
  );
  const projectedSourceLaws = projectR12aSourceLaws(sourceLaws, r12aManifest);
  const duplicateDiagnostics = projectedSourceLaws.diagnostics
    .filter((item) => item.kind === 'duplicate-provider' && typeof item.provider === 'string');
  const duplicateIdentities = new Set(duplicateDiagnostics
    .filter((item) => item.kind === 'duplicate-provider' && typeof item.provider === 'string')
    .map((item) => `${item.provider}|${item.declarationPath}`));
  const permittedDuplicates = new Set(manifest.remainingDuplicateProviders);
  const sourceDiagnostics = projectedSourceLaws.diagnostics.filter((item) => {
    if (item.kind !== 'duplicate-provider') return true;
    return !(permittedDuplicates.has(item.provider)
      && APPROVED_DUPLICATE_IDENTITIES.get(item.provider) === item.declarationPath
      && APPROVED_DUPLICATE_REGISTRATIONS.get(item.provider)?.has(item.path));
  });
  const live = projectR12aInventory(collectLiveInventory(
    options.repoRoot,
    options.backendRoot,
    contractDefinitions,
    manifest.initialRetiredLegacyProviderEdges,
    r12aManifest,
    r12cManifest,
  ), r12aManifest);
  const ports = scanPorts({ repoRoot: options.repoRoot, backendRoot: options.backendRoot });
  const exactRemainingDuplicates = manifest.remainingDuplicateProviders.every((provider) => {
    const registrations = duplicateDiagnostics.filter((item) => (
      item.provider === provider && item.declarationPath === APPROVED_DUPLICATE_IDENTITIES.get(provider)
    )).map((item) => item.path).sort();
    return JSON.stringify(registrations) === JSON.stringify([...APPROVED_DUPLICATE_REGISTRATIONS.get(provider)].sort());
  });
  const livePlatformDebts = live.compositionDependencies.map((item) => (
    item.key === 'app-jwt-module-availability' ? 'runtime-jwt-secret' : item.key
  ));
  // Closed successor. The exact inventories (module list, constructor uses by
  // position, decorator references, lifecycle providers, guard metadata) were
  // the proof that each relocation task changed nothing else; after the R12C
  // closure they are history verified at the recorded lineage commit. The
  // live law keeps every rule a product change must respect: the source laws,
  // no cross-context injection, no remaining platform debt or retired legacy
  // edge, every public contract surface present, no duplicate provider, no
  // project global, and the injection-identity law below.
  const identityDrift = closed ? injectionIdentityDiagnostics(live.constructorUses) : [];
  const crossContextInjections = closed
    ? live.injections.map((item) => ({ kind: 'cross-context-injection', path: item.source, line: 1 }))
    : [];
  const drift = closed
    ? (!projectionValid
      || livePlatformDebts.length !== 0
      || live.retiredEdges.length !== 0
      || !live.providerContractSurfacesPresent
      || live.globals !== 0)
    : !projectionValid
    || JSON.stringify(live.modules) !== JSON.stringify(projectedHistoricalManifest.legacyModules)
    || JSON.stringify(live.injections) !== JSON.stringify(projectedHistoricalManifest.crossContextInjections)
    || JSON.stringify(livePlatformDebts) !== JSON.stringify(projectedHistoricalManifest.remainingPlatformDebts)
    || JSON.stringify(live.providerContracts) !== JSON.stringify(projectedHistoricalManifest.providerContracts)
    || !live.providerContractSurfacesPresent
    || !live.task2ConstructorInventoryPresent
    || (manifest.stage !== 'task-2' && !live.task3ConstructorInventoryPresent)
    || (['task-4', 'task-5', 'task-6', 'task-7', 'task-8', 'strict'].includes(manifest.stage)
      && !live.task4ConstructorInventoryPresent)
    || (['task-5', 'task-6', 'task-7', 'task-8', 'strict'].includes(manifest.stage)
      && !live.task5ConstructorInventoryPresent)
    || !live.r6ConstructorInventoryPresent
    || (manifest.stage === 'strict' && !live.r4ConstructorInventoryPresent)
    || JSON.stringify(sortR12aDecoratorInventory(live.decoratorRuntimeReferences))
      !== JSON.stringify(sortR12aDecoratorInventory(projectR12aInventory(projectR7SharingDecoratorSources(manifest.decoratorRuntimeReferences), r12aManifest)))
    || JSON.stringify(sortR12aDecoratorInventory(live.runtimeDecoratorValueReferences))
      !== JSON.stringify(sortR12aDecoratorInventory(projectR12aInventory(projectR7SharingDecoratorSources(manifest.runtimeDecoratorValueReferences), r12aManifest)))
    || JSON.stringify(live.lifecycleProviders) !== JSON.stringify(projectedHistoricalManifest.lifecycleProviders)
    || JSON.stringify(live.retiredEdges.map((item) => item.key)) !== JSON.stringify(projectedHistoricalManifest.remainingRetiredLegacyProviderEdges)
    || JSON.stringify(live.adminGuardMetadata) !== JSON.stringify(projectedHistoricalManifest.adminGuardMetadata)
    || live.globals !== 0
    || !exactRemainingDuplicates;
  const diagnostics = [...sourceDiagnostics, ...identityDrift, ...crossContextInjections];
  if (drift) diagnostics.push({ kind: 'inventory-drift', path: 'backend/src/app.module.ts', line: 1 });
  if (ports.diagnostics.length) diagnostics.push({ kind: 'inventory-drift', path: 'backend/src/app.module.ts', line: 1 });
  return validateR3ScanResult({
    diagnostics,
    counts: {
      contexts: Object.keys(ROOTS).length,
      legacyModules: live.modules.length,
      crossContextInjections: live.injections.length,
      compositionDependencies: live.compositionDependencies.length,
      initialDuplicateProviders: manifest.initialDuplicateProviders.length,
      remainingDuplicateProviders: duplicateIdentities.size,
      initialPlatformDebts: manifest.initialPlatformDebts.length,
      remainingPlatformDebts: live.compositionDependencies.length,
      initialRetiredLegacyProviderEdges: manifest.initialRetiredLegacyProviderEdges.length,
      remainingRetiredLegacyProviderEdges: live.retiredEdges.length,
      forwardRef: ports.counts.forwardRef,
      globals: ports.counts.globals,
      nestModuleCycles: ports.counts.nestModuleCycles,
      illegalEdges: ports.counts.illegalFutureImports,
    },
  });
}

function validateR3ScanResult(value) {
  assertDeepPlainData(value, 'R3 scan result');
  const result = plainObject(value, 'R3 scan result');
  if (Object.keys(result).sort().join('|') !== 'counts|diagnostics') throw new Error('R3 scan result keys are invalid');
  const diagnostics = denseArray(result.diagnostics, 'R3 diagnostics').map((item) => {
    const record = plainObject(item, 'R3 diagnostic');
    if (!DIAGNOSTIC_KINDS.has(record.kind) || typeof record.path !== 'string'
        || !record.path.startsWith('backend/') || !Number.isSafeInteger(record.line) || record.line < 1) {
      throw new Error('R3 diagnostic is invalid');
    }
    return { kind: record.kind, path: record.path, line: record.line };
  });
  const counts = plainObject(result.counts, 'R3 counts');
  if (Object.keys(counts).sort().join('|') !== [...COUNT_KEYS].sort().join('|')) throw new Error('R3 count keys are invalid');
  for (const key of COUNT_KEYS) if (!Number.isSafeInteger(counts[key]) || counts[key] < 0) throw new Error('R3 count is invalid');
  return { diagnostics, counts };
}

function runCli(dependencies = {}) {
  const argv = dependencies.argv || process.argv.slice(2);
  const stdout = dependencies.stdout || ((message) => process.stdout.write(`${message}\n`));
  const stderr = dependencies.stderr || ((message) => process.stderr.write(`${message}\n`));
  try {
    if (argv.length !== 3 || argv[0] !== '--check' || argv[1] !== '--stage'
        || !/^(?:inventory|task-[2-8]|strict)$/u.test(argv[2])) {
      throw new Error('invalid arguments');
    }
    const backendRoot = path.resolve(__dirname, '../..');
    const repoRoot = path.resolve(backendRoot, '..');
    const scan = dependencies.scan || (() => scanR3Contexts({
      repoRoot, backendRoot,
      manifestPath: path.join(backendRoot, 'architecture', 'r3-context-boundaries.json'),
      stage: argv[2],
    }));
    const result = validateR3ScanResult(scan());
    if (result.diagnostics.length) {
      // Diagnostics are validated records (kind, repository path, line): a
      // bounded listing names the violation without echoing source text.
      stderr(`FAIL - R3 contexts: ${result.diagnostics.length} diagnostic(s)`);
      for (const item of result.diagnostics.slice(0, MAX_REPORTED_DIAGNOSTICS)) stderr(`  ${item.kind} ${item.path}:${item.line}`);
      if (result.diagnostics.length > MAX_REPORTED_DIAGNOSTICS) stderr(`  ... ${result.diagnostics.length - MAX_REPORTED_DIAGNOSTICS} more`);
      return 1;
    }
    stdout(`PASS - R3 contexts: contexts=${result.counts.contexts}, duplicates=${result.counts.remainingDuplicateProviders}/${result.counts.initialDuplicateProviders}, platform debts=${result.counts.remainingPlatformDebts}/${result.counts.initialPlatformDebts}, retired edges=${result.counts.remainingRetiredLegacyProviderEdges}/${result.counts.initialRetiredLegacyProviderEdges}, forwardRef=${result.counts.forwardRef}, globals=${result.counts.globals}, cycles=${result.counts.nestModuleCycles}, illegal=${result.counts.illegalEdges}`);
    return 0;
  } catch {
    stderr('ERROR - R3 context scan failed');
    return 2;
  }
}
const MAX_REPORTED_DIAGNOSTICS = 20;

module.exports = {
  collectR3DecoratorInventory,
  scanR3Contexts,
  scanR4PlanningBudgetWriter,
  scanR3SourceLaws,
  validateR3ContextManifest,
  validateR3ScanResult,
  verifyR7DependencyHandoff,
  verifyR7HistoryDecoratorHandoff,
  verifyR7SharingDecoratorHandoff,
  projectR12aPath,
  projectR12aInventory,
  runCli,
};
if (require.main === module) process.exitCode = runCli();
