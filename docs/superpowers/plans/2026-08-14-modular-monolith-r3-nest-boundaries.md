# Modular Monolith R3 Nest Boundaries Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> `superpowers:subagent-driven-development` (recommended) or
> `superpowers:executing-plans` to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Execution status:** Approved for staged local execution after independent review. No R3
production source has been changed.

**Goal:** Compose all 13 Backend business contexts explicitly, replace current
cross-context provider injection with demand-driven public Symbol contracts,
and remove the six frozen platform-to-business dependencies without changing
runtime behavior.

**Architecture:** Provider-leaf internal modules own one legacy implementation
instance; demand-driven public modules alias that exact instance with
`useExisting` through internal implementation tokens. Full modules compose
controllers and private provider leaves for all 13 contexts. Application
composition has two explicit points: `AppModule` owns the readiness alias and
consumer in one scope, while `ApplicationOutboxRuntimeModule` owns Outbox sink
aliases and runtime providers. Platform never imports a business context.

**Tech Stack:** NestJS 11, TypeScript 5.9, Prisma 6.19.3, Node.js 22 in CI,
dependency-cruiser 18.1.0, Node's built-in test runner, Flutter 3.41.7,
GitHub Actions, Markdown documentation.

## Global Constraints

- `R3_BASE` is exactly
  `6b06eb096aca8cc6684d365d16e05d4cd8529898`.
- Work only on the existing `modular-monolith` branch. Do not create a branch
  or worktree, push, merge, mutate PR #76, or claim remote CI.
- Use local checkpoint commits only after focused/full gates and independent
  review pass. Stop for the owner application checkpoint after each task.
- Preserve routes, controller metadata, payloads, status codes, error/Arabic
  text, permissions, transaction/lock/retry behavior, schedules, event names,
  Socket.IO semantics, and lifecycle counts.
- Do not move controller or service implementation files from their current
  roots. Public type/pure-policy extraction and deletion of superseded
  `*.module.ts` metadata are the only R3 source-layout changes outside
  `src/modules/` and `src/application-composition/`.
- Do not add a speculative public token. Every public token must have at least
  one exact current consumer recorded in the tracked R3 manifest.
- Public modules export Symbol tokens only; there is no runtime-class export
  exception. Owner-private internal leaves may export their concrete provider
  token only to owner modules and their paired PublicModule.
- Provider classes are registered once. Every public token must resolve to the
  same object as its legacy implementation class. Exact Nest controller-local
  `@UseGuards(Class)` enhancer wrappers are classified as `decorator-runtime`,
  not provider ownership or singleton candidates.
- `forwardRef()` remains zero. The two current approved `@Global()` declarations
  and their paths remain exact until R8.
- Platform imports no business context or application-composition source.
  Shared-kernel imports neither platform nor business source.
- Delete only the exact immutable union of `initialPlatformDebts` and
  `initialRetiredLegacyProviderEdges`. Do not add, rename, increase, or silently
  remove any other dependency or ownership record.
- Keep sharing's direct OpenWA transient-text use unchanged until R6.
- Keep the Prisma folder at 14 files / 52 models / 41 enums / 76 migrations;
  preserve seed, migrations, normalized DMMF, generated contracts, Mobile,
  Admin Web, Compose/deploy, package/lock files, and CI unless a task explicitly
  names the file.
- Existing behavioral tests may change only for mechanical public-contract
  import/type paths, `@Inject(Symbol)` wiring, Nest test-module providers, and
  adding the required real/deterministic identity-secret callback to existing
  runtime-validator calls. Do not change assertions, values, fixtures, errors,
  Arabic text, timeouts, skips, or test selection.
- RED must precede production edits. Never weaken a failing gate; fix the
  earliest incorrect source boundary.
- Never expose environment values, credentials, tokens, request/response bodies,
  or raw production logs in reports.

## File and Contract Map

### Full modules created by R3

```text
backend/src/modules/identity/identity.module.ts
backend/src/modules/planning/planning.module.ts
backend/src/modules/finance/finance.module.ts
backend/src/modules/collaboration/collaboration.module.ts
backend/src/modules/tasks/tasks.module.ts
backend/src/modules/guests/guests.module.ts
backend/src/modules/marketplace/marketplace.module.ts
backend/src/modules/messaging/messaging.module.ts
backend/src/modules/notifications/notifications.module.ts
backend/src/modules/catalog/catalog.module.ts
backend/src/modules/media/media.module.ts
backend/src/modules/insights/insights.module.ts
backend/src/modules/backoffice/backoffice.module.ts
```

### Public contracts created by R3

| Token | Interface surface required by current foreign consumers |
| --- | --- |
| `IDENTITY_AUTH_PORT` | `requestInviteOtp`, `verifyInviteOtp` |
| `IDENTITY_ACCESS_TOKEN_VERIFIER` | `verifyAsync<T extends object>(token: string): Promise<T>` |
| `COLLABORATION_PERMISSION_PORT` | `assertPlanReadable`, `assertPlanReadableInTransaction`, `assertPlanReadableForUserUpdateInTransaction`, `assertPlanManageableForUpdateInTransaction`, `assertTaskManageableInTransaction`, `assertGuestManageableInTransaction`, `assertMoneyReadable`, `assertMoneyReadableInTransaction`, `assertMoneyManageable`, `assertMoneyManageableInTransaction`, `assertMoneyManageableForUpdateInTransaction`, `assertProviderManageable`, `assertProviderManageableInTransaction`, `assertProviderAndMoneyManageableInTransaction`, `assertMemberManageable`, `assertMemberManageableInTransaction`, `canViewMoney`, `canManageTasks`, `canManageGuests`, `canManageMoney`, `canManagePlan`, `canManageProviders`, `canManageMembers`, `livePlanAuthorizationWhere` |
| `COLLABORATION_HISTORY_PORT` | `recordInTransaction`, `recordForContextInTransaction`, `ensureTenureInTransaction` |
| `COLLABORATION_SCOPE_PORT` | `qualifyingEntityIds`, `qualifyingEntityIdsInTransaction` |
| `MESSAGING_REALTIME_PORT` | `revokeConversationAccess`, `dispatchMessageAvailable`, `dispatchActivityAvailable`, `dispatchNotificationAvailable`, `dispatchConversationAccessRevoked`, `dispatchUserSessionsRevoked`, `dispatchSessionRevoked`, `disconnectUser`, `disconnectSession` |
| `NOTIFICATIONS_PORT` | `createNotificationInTransaction`, `resolveProviderUpdateRecipientInTransaction`, `notifyTaskDue`, `purgeMoneyForMember`, `visibilityWhereForUser` |
| `PUSH_DELIVERY_PORT` | `dispatchNotification` |
| `PUSH_CAPABILITY_PORT` | readonly `enabled: boolean` |
| `MEDIA_STORAGE_PORT` | `createDownloadUrl`, `verifyUpload`, `verifyPublicMediaUrl`, `consumeUpload`, `consumePublicMediaUrl`, `scheduleTargetDeletion`, `scheduleAllOwnedMediaDeletion`, `scheduleApplicationIdentityMediaDeletion`, `lockAccountDeletionBoundary`, `checkReadiness` |

The public interfaces copy the exact existing parameter and return types. Move
only the type declarations required by those signatures into the owner's
`public/` slice; make the legacy implementation import and implement the public
interface. Do not use `Pick<LegacyService, ...>` or type-import an implementation
class from a public contract.

Task 2 first moves `AuthenticatedUser` and `JwtSessionScope` into the Identity
public slice, updates every source/test type consumer mechanically, and deletes
the retired type file without a compatibility re-export. `MEDIA_STORAGE_PORT`
uses that public Identity type. Cross-public `import type` edges are permitted;
runtime imports and Nest PublicModule metadata imports across owners are not.

### Exact current foreign provider consumers

The tracked manifest must contain these files and classify each resolved symbol
use as `constructor-injection`, `function-parameter`, `type-only`, or
`pure-function`; a flat lexical consumer list is not accepted:

- `PermissionService` provider-contract consumers:
  `budget-categories/budget-categories.service.ts`,
  `contexts/contexts.service.ts`, `dashboard/dashboard.service.ts`,
  `guests/guests.service.ts`,
  `marketplace/marketplace-contributor-quote-scope.ts`,
  `marketplace/marketplace.service.ts`,
  `marketplace/quote-offer-acceptance.ts`,
  `marketplace/quote-offer-rejection.ts`,
  `marketplace/quote-request-cancellation.ts`,
  `marketplace/quote-request-creation.ts`, `money/money-budget.service.ts`,
  `money/money-summary.service.ts`, `notifications/notifications.service.ts`,
  `tasks/tasks.service.ts`, `timeline/timeline.service.ts`,
  `users/users.service.ts`,
  `wedding-costs/wedding-costs.service.ts`, and
  `wedding-plans/wedding-plans.service.ts`.
- Collaboration permission type-only users:
  `dashboard/dashboard-contributor-scope.ts` (`PlanAccessContext`).
- Collaboration pure policy/type users:
  `contribution-history/contribution-history.service.ts`
  (`livePlanAuthorizationWhere`, `PlanAccessContext`),
  `conversations/conversations.service.ts` (`assertWeddingPlanWritable`,
  `isWeddingPlanWritable`), `marketplace/marketplace-write-locks.ts`
  (`assertWeddingPlanWritable`), and
  `provider-dashboard/provider-dashboard.service.ts`
  (`assertWeddingPlanWritable`). These pure exports move to the Collaboration
  public slice but are not DI token consumers.
- `ContributionHistoryService`: `budget-categories/budget-categories.service.ts`,
  `dashboard/dashboard.service.ts`, `guests/guests.service.ts`,
  `marketplace/marketplace.service.ts`, `marketplace/quote-offer-acceptance.ts`,
  `marketplace/quote-offer-rejection.ts`,
  `marketplace/quote-request-cancellation.ts`,
  `marketplace/quote-request-creation.ts`, `tasks/tasks.service.ts`,
  `wedding-costs/wedding-costs.service.ts`, and
  `wedding-plans/wedding-plans.service.ts`. The same-context
  `sharing/sharing.service.ts` remains concrete.
- `ContributorScopeService`: `budget-categories/budget-categories.service.ts`,
  `dashboard/dashboard-contributor-scope.ts`, `dashboard/dashboard.service.ts`,
  `guests/guests.service.ts`, `money/money-summary.service.ts`,
  `tasks/tasks.service.ts`, `timeline/timeline.service.ts`, and
  `wedding-costs/wedding-costs.service.ts`.
- `NotificationsService`: `admin/admin.service.ts`,
  `conversations/conversations.service.ts`, `dashboard/dashboard.service.ts`,
  `marketplace/marketplace.service.ts`, `marketplace/quote-notifications.ts`,
  `marketplace/quote-offer-acceptance.ts`,
  `marketplace/quote-offer-rejection.ts`,
  `marketplace/quote-request-creation.ts`,
  `provider-dashboard/provider-dashboard.service.ts`,
  `sharing/sharing.service.ts`, and `tasks/tasks.service.ts`.
- `MediaStorageService`: `conversations/conversations.service.ts`,
  `provider-dashboard/provider-dashboard.service.ts`, `users/users.service.ts`,
  and platform readiness through the composition token.
- `ConversationRealtimePublisher`: `admin/admin.service.ts`,
  `auth/auth.service.ts`, `sharing/sharing.service.ts`,
  `users/users.service.ts`, and Outbox through the composition sink.
- `FirebasePushClient`: `users/users.service.ts` capability read only.
- `PushDeliveryService`: Outbox through the composition sink only.
- `AuthService`: `sharing/invite-access.service.ts`.
- `JwtService`: `conversations/conversations.gateway.ts` verification only.

---

### Task 0: Approve and Checkpoint the R3 Contract

**Files:**

- Create:
  `docs/superpowers/specs/2026-08-14-modular-monolith-r3-nest-boundaries-design.md`
- Create:
  `docs/superpowers/plans/2026-08-14-modular-monolith-r3-nest-boundaries.md`

**Interfaces:** Produces the independently approved R3 design and executable
plan. It changes no production, test, baseline, runtime, or active receipt file.

- [ ] **Step 1: Reconcile the contract with live source**

Verify the 13 contexts, six platform debts, exact legacy provider consumers,
Nest provider visibility/export laws, staging order, runtime validation order,
and rollback/runtime constraints against `R3_BASE`.

- [ ] **Step 2: Obtain independent plan review**

Require findings-first review of the two complete documents. Correct every
Critical/Important/Minor contradiction before approval; rerun docs sync/verify
and whitespace checks after each correction.

- [ ] **Step 3: Commit the planning checkpoint**

After review PASS, set both status fields to approved, stage exactly these two
Markdown files, and create one local commit:

```powershell
git commit -m "docs: approve modular monolith R3 plan"
```

Leave the worktree clean. `R3_BASE` remains the immutable R2 closeout SHA above;
Task 1 measures cumulative R3 scope from that SHA.

---

### Task 1: Freeze R3 Inventory, Scope, and Nest Laws

**Files:**

- Create: `backend/architecture/r3-context-boundaries.json`
- Create: `backend/scripts/architecture/r3-context-scan.cjs`
- Create: `backend/scripts/architecture/r3-scope.cjs`
- Create: `backend/test/architecture-r3-contexts.test.ts`
- Create: `backend/test/architecture-r3-scope.test.ts`
- Modify: `backend/scripts/architecture/ports-scan.cjs`
- Modify: `backend/test/architecture-ports.test.ts`
- Modify: `backend/.dependency-cruiser.cjs`
- Modify: `backend/test/architecture-dependencies.test.ts`
- Modify: `backend/package.json`

**Interfaces:**

- Produces: canonical `R3ContextManifest`, `scanR3Contexts(options)`, and
  `validateR3Scope({ repositoryRoot, baseRef, reportPath? })`.
- Consumes: only tracked source/config and immutable `R3_BASE`; no runtime or
  database.

- [ ] **Step 1: Add test-only RED fixtures**

Add tests that require the exact 13-context map, the current legacy Nest
metadata, 43 cross-context constructor/provider injections, six composition
dependencies (JWT-module availability plus five platform provider/module
relations), three duplicate provider classes, six exact platform debts, the
AST-derived legacy provider-debt records scheduled for retirement, the exact 23
foreign `decorator-runtime` controller references (20 `JwtAuthGuard`, 3
`JwtSessionGuard`) plus Admin/Catalog guard metadata; exact frozen
`runtime-decorator/value` references including 22 `CurrentUser` controller
consumers, 3 `RequireAdminPermission` controller consumers, and the guard's
metadata-key import; and one instance each for Worker/Dispatcher/Gateway/
Schedulers. Add adversarial
fixtures for aliased/namespace Nest symbols, spreads, computed metadata,
duplicate providers, hollow tokens, concrete public exports, wrong-context
internal/full imports, cross-public runtime or Nest metadata imports (with a
legal type-only control), composition imports outside `public/`, `forwardRef`,
cycles, unknown contexts, path traversal, proxies,
accessors, sparse arrays, and mixed valid/invalid atomic output.

Run:

```powershell
cd backend
node --test -r ts-node/register `
  test/architecture-r3-contexts.test.ts `
  test/architecture-r3-scope.test.ts `
  test/architecture-dependencies.test.ts `
  test/architecture-ports.test.ts
```

Expected: RED because the manifest/scanners do not exist and current tools do
not enforce the R3 laws. Record exact pass/fail counts before production edits.

- [ ] **Step 2: Implement the exact manifest**

Use exact plain JSON with:

```json
{
  "schemaVersion": 1,
  "baseRevision": "6b06eb096aca8cc6684d365d16e05d4cd8529898",
  "stage": "inventory",
  "contexts": [
    "identity", "planning", "finance", "collaboration", "tasks",
    "guests", "marketplace", "messaging", "notifications", "catalog",
    "media", "insights", "backoffice"
  ],
  "initialDuplicateProviders": [
    "AdminGuard", "AdminPermissionGuard", "PermissionService"
  ],
  "remainingDuplicateProviders": [
    "AdminGuard", "AdminPermissionGuard", "PermissionService"
  ],
  "initialPlatformDebts": [
    "runtime-jwt-secret", "readiness-media-storage",
    "outbox-dispatcher-realtime", "outbox-dispatcher-push",
    "outbox-module-realtime", "outbox-module-push"
  ],
  "remainingPlatformDebts": [
    "runtime-jwt-secret", "readiness-media-storage",
    "outbox-dispatcher-realtime", "outbox-dispatcher-push",
    "outbox-module-realtime", "outbox-module-push"
  ],
  "initialRetiredLegacyProviderEdges": [
    { "key": "<exact dependency key>", "retirementTask": 2 }
  ],
  "remainingRetiredLegacyProviderEdges": [
    "<exact dependency key>"
  ]
}
```

The placeholders above describe record shape only. Step 2 must replace them
with the complete canonically sorted live-AST sets and tests must freeze their
exact counts and identities before any production source edit. Initial arrays
are immutable for all later stages; only remaining arrays may shrink.

Add the exact module metadata, token/implementation/method/consumer records,
lifecycle providers, and exact allowed changed paths from the tables above and
the live TypeScript AST. Sort every set canonically and reject duplicates.

- [ ] **Step 3: Implement scanners fail-closed**

Resolve imports and Nest decorators through the TypeScript checker. Accept
plain dense data only. Stage `inventory` permits only the exact three known
duplicate classes and the immutable manifest union of initial platform and
retired-legacy debts; additions fail. Later stages may only delete records from
the corresponding remaining arrays at their declared task. Internal leaves
must export both their concrete provider token for owner-only consumers and an
implementation Symbol for the paired PublicModule; foreign internal/concrete
imports fail. Exact framework-created decorator enhancers are excluded from
provider ownership but any decorator class/controller/route drift fails. Render
only fixed catalog messages plus canonical repository paths after the full
batch validates.

Extend dependency and ports classification with
`backend/src/application-composition/**`: it may import platform and exact
business `public/` modules; platform may not import it; business/internal/public
code may not import it. Cross-owner public-slice `import type` is allowed, while
runtime imports and Nest PublicModule metadata imports remain forbidden.
Same-context future-to-legacy imports are allowed only from declared
internal/full files. A paired PublicModule may import its declared
internal module and internal implementation token, but never the legacy class;
the implementation token may appear only as `useExisting` for the matching
public token. Add near-misses for direct concrete imports, wrong-owner tokens,
`useClass`/`useFactory`, and non-provider uses.

- [ ] **Step 4: Implement fixed-base scope validation**

Pin the exact SHA internally. Validate the manifest's explicit path allowlist,
not a broad `modules/**` glob. Machine reports are absolute unique OS-temp JSON,
pairwise distinct from inputs, reparse-safe, and atomically committed with
rename as the last filesystem operation. CLI failures emit one fixed line and
exit 2.

- [ ] **Step 5: Reach focused GREEN and run the live inventory gate**

Run the Step 1 command and:

```powershell
node scripts/architecture/r3-context-scan.cjs --check --stage inventory
node scripts/architecture/r3-scope.cjs --check `
  --base-ref 6b06eb096aca8cc6684d365d16e05d4cd8529898
npm run architecture
npm run check
npm run build
```

Expected: all PASS; live output truthfully reports 13 contexts, 3 initial and
remaining duplicate classes, 6 initial and remaining platform debts, equal
nonzero initial/remaining retired-legacy inventories, zero `forwardRef`, 2
globals, and zero cycles/new illegal edges.

- [ ] **Step 6: Independently review, smoke, checkpoint, and stop**

Run `npm run smoke:health`, docs sync/verify/diff checks, protected-surface
checks, and independent adversarial review. Fix findings through new RED tests.
Then commit only reviewed Task 1 files:

```powershell
git commit -m "test: freeze modular monolith R3 Nest contract"
```

Leave the worktree clean and stop for owner application/continuation approval.

---

### Task 2: Establish Realtime, Media, Push, and Application Composition Leaves

**Files:**

- Create: `backend/src/modules/identity/public/identity-session.types.ts`
- Delete: `backend/src/auth/authenticated-user.interface.ts`
- Modify: `backend/src/auth/jwt-payload.interface.ts`
- Modify: every exact source/test consumer of `AuthenticatedUser` and
  `JwtSessionScope` mechanically
- Create: `backend/src/modules/messaging/public/messaging-realtime.port.ts`
- Create: `backend/src/modules/messaging/public/messaging-realtime-public.module.ts`
- Create: `backend/src/modules/messaging/internal/messaging-realtime.internal.module.ts`
- Create: `backend/src/modules/messaging/internal/messaging-realtime.implementation-token.ts`
- Create: `backend/src/modules/media/internal/media-storage.internal.module.ts`
- Create: `backend/src/modules/media/internal/media-lifecycle.internal.module.ts`
- Create: `backend/src/modules/media/public/media-storage.port.ts`
- Create: `backend/src/modules/media/public/media-storage-public.module.ts`
- Create: `backend/src/modules/notifications/internal/push-transport.internal.module.ts`
- Create: `backend/src/modules/notifications/public/push-delivery.port.ts`
- Create: `backend/src/modules/notifications/public/push-delivery-public.module.ts`
- Create: `backend/src/modules/notifications/public/push-capability.port.ts`
- Create: `backend/src/modules/notifications/public/push-capability-public.module.ts`
- Create: `backend/src/platform/health/media-readiness.port.ts`
- Create: `backend/src/platform/outbox/outbox.ports.ts`
- Create: `backend/src/platform/outbox/outbox-core.module.ts`
- Create: `backend/src/application-composition/application-outbox-runtime.module.ts`
- Create: `backend/test/architecture-r3-composition.test.ts`
- Modify: exact realtime/media/push consumer files and their legacy modules
- Modify: `backend/src/push/push.module.ts`
- Modify: `backend/src/notifications/notifications.module.ts`
- Modify: `backend/src/platform/health/readiness.service.ts`
- Modify: `backend/src/platform/outbox/outbox.dispatcher.ts`
- Modify: `backend/src/app.module.ts`
- Delete: `backend/src/platform/outbox/outbox.module.ts`
- Modify: dependency baseline/config only after the semantic audit passes

**Interfaces:**

- Produces: `MESSAGING_REALTIME_PORT`, `MEDIA_STORAGE_PORT`,
  `PUSH_DELIVERY_PORT`, `PUSH_CAPABILITY_PORT`, `MEDIA_READINESS_PORT`,
  `OUTBOX_REALTIME_SINK`, `OUTBOX_PUSH_SINK`, `OutboxCoreModule`, and
  `ApplicationOutboxRuntimeModule`.

- [ ] **Step 1: Write singleton/composition RED tests**

Assert token identity, complete interface surfaces, exact Identity public type
shape/consumer set, allowed type-only public edge and rejected runtime/public
metadata near-misses, exact continued Push controller/route reachability,
readiness response parity,
outbox dispatch parity for every event type, optional push failure identity,
one Worker/Dispatcher/CleanupScheduler, no platform business import, no
concrete foreign injection, and no duplicate provider registration. Run the
focused R3 composition and existing media/push/outbox tests; capture RED.

- [ ] **Step 2: Extract Identity public types, then add provider leaves**

First move `AuthenticatedUser` and `JwtSessionScope` to Identity public, update
every AST-recorded type consumer, and delete the old interface path without a
barrel or re-export. Then use `useExisting` aliases only. Every internal leaf
exports its concrete provider for owner-only controllers/schedulers plus its
internal implementation token for the paired PublicModule. Keep
`conversations/conversation-realtime.module.ts` byte-for-byte at its exact
global path. The messaging realtime internal bridge imports that global module,
aliases the existing publisher to the internal implementation token, and
exports only that token; the public realtime module aliases the internal token
to `MESSAGING_REALTIME_PORT` and never imports the publisher class. Make
`MediaStorageInternalModule` own `MediaUploadTicketService` and
`MediaStorageService`; make the lifecycle leaf own only
`MediaUploadCleanupScheduler` and import `MediaStorageInternalModule` because
the scheduler needs both ticket and storage services. Make
`PushTransportInternalModule` own
`FirebasePushClient` and `PushDeliveryService`.

- [ ] **Step 3: Migrate exact foreign consumers**

Replace concrete constructor types with the public interfaces and add
`@Inject(TOKEN)`. Update only these provider consumer files:

```text
admin/admin.service.ts
auth/auth.service.ts
sharing/sharing.service.ts
users/users.service.ts
conversations/conversations.service.ts
provider-dashboard/provider-dashboard.service.ts
platform/health/readiness.service.ts
platform/outbox/outbox.dispatcher.ts
```

Update their Nest module imports to the corresponding public modules. Same-owner
controllers/schedulers may continue to inject the concrete class from the
internal leaf. Remove `PushModule` from Users after Push Capability Public is
imported, but keep the refactored legacy `PushModule` reachable exactly once by
temporarily importing it from same-context `NotificationsModule`. The legacy
PushModule owns only `PushController` and `PushInstallationsService`; it retains
its existing AuthModule import until Task 5 and imports Prisma, but must not
re-register Firebase or Push Delivery providers now owned by
`PushTransportInternalModule`.

- [ ] **Step 4: Split Outbox at the composition boundary**

`OutboxCoreModule` provides/exports `OutboxService` and owns
`OutboxCleanupScheduler`. `ApplicationOutboxRuntimeModule` imports Core plus
Messaging Realtime Public and Push Delivery Public, binds both platform sink
tokens with `useExisting`, and provides exactly `OutboxDispatcher` and
`OutboxWorker`. For Outbox access, Notifications and Conversations import Core
rather than the runtime module; Notifications also retains the exact temporary
PushModule reachability import declared above. `AppModule` imports the runtime
module once.

- [ ] **Step 5: Bind readiness in AppModule**

Register the media readiness alias and `ReadinessService` in `AppModule`, which
imports Media Storage Public. Preserve `READINESS_FETCH`, check order, timeout,
disabled/down semantics, and response shape exactly.

- [ ] **Step 6: Verify five exact debts disappear**

Generate a dependency candidate, compare it semantically to the tracked
baseline, and require platform debts 2-6 plus only the Task-2 subset of
`remainingRetiredLegacyProviderEdges` to disappear. Copy the candidate only after the
verifier reports zero unexpected deletion/addition/rename/increase. The
runtime/JWT platform debt remains exactly one for Task 5.

- [ ] **Step 7: Full gate, review, checkpoint, stop**

Run focused suites, architecture/check/build, full Backend tests, then these
exact managed smokes with exit 0 and independent zero-residue audits:

```powershell
npm run smoke:health
npm run smoke:notifications
npm run smoke:phase2-media-verification-lifecycle
npm run smoke:conversation-unification
```

Run scope/protected/docs gates and independent review. Commit:

```powershell
git commit -m "refactor: establish R3 composition provider leaves"
```

Stop for owner application testing.

---

### Task 3: Publish Collaboration Permission and History Contracts

**Files:**

- Create: `backend/src/modules/collaboration/public/collaboration-permission.port.ts`
- Create: `backend/src/modules/collaboration/public/collaboration-permission-public.module.ts`
- Create: `backend/src/modules/collaboration/public/collaboration-history.port.ts`
- Create: `backend/src/modules/collaboration/public/collaboration-history-public.module.ts`
- Create: `backend/src/modules/collaboration/public/collaboration-scope.port.ts`
- Create: `backend/src/modules/collaboration/public/collaboration-scope-public.module.ts`
- Create: `backend/src/modules/collaboration/internal/collaboration-permission.internal.module.ts`
- Create: `backend/src/modules/collaboration/internal/collaboration-history.internal.module.ts`
- Create: `backend/src/modules/collaboration/internal/collaboration-scope.internal.module.ts`
- Create: `backend/test/architecture-r3-collaboration-ports.test.ts`
- Modify: exact consumer files listed in the File and Contract Map
- Modify: `backend/src/sharing/sharing.module.ts`
- Modify: `backend/src/contribution-history/contribution-history.module.ts`
- Modify: every legacy module that currently imports those two full modules only
  for the three exported providers

**Interfaces:** Produces the three collaboration tokens and public contract
types including `PlanAccessContext`, `LivePlanPermission`, contribution record
inputs, and scope signatures. It also moves the exact currently imported pure
permission policies (`livePlanAuthorizationWhere`, `isWeddingPlanWritable`,
`assertWeddingPlanWritable`, and their constants) into the Collaboration public
slice without treating pure/type-only users as DI consumers.

- [ ] **Step 1: Write RED contract and consumer tests**

Test the complete method lists from the contract map, singleton identity,
structural assignability, exact consumer set, same-context concrete use, no
public import of legacy implementation, and current duplicate
`PermissionService` rejection.

- [ ] **Step 2: Extract public types and create leaves**

Move the exact contract type and pure-function declarations, update the legacy
classes to `implements` their public interfaces, and register each class once.
Each internal leaf exports the concrete class to owner-only modules plus an
internal implementation token; its PublicModule aliases that token and never
imports or exports the legacy class. The history leaf may
import the same-context permission internal leaf; it must not import the
permission public leaf or create a reciprocal module edge.

- [ ] **Step 3: Migrate every listed foreign consumer atomically**

For each constructor/provider/function parameter, import the public interface
and token, add `@Inject(TOKEN)` where Nest constructs the class, and update the
owning legacy module to import the matching PublicModule. Type-only and
pure-function users import the exact public declarations without a Nest module
dependency. Replace module imports of `SharingModule`/`ContributionHistoryModule`
when they existed only for these providers. Do not change method calls or
function bodies.

- [ ] **Step 4: Remove duplicate PermissionService ownership**

Delete `PermissionService` from `NotificationsModule.providers`; import
`CollaborationPermissionPublicModule` and inject its token. The remaining
duplicate set must decrease from three classes to two while its immutable
initial set stays unchanged.

- [ ] **Step 5: Verify and checkpoint**

Require only the Task-3 manifest subset of `remainingRetiredLegacyProviderEdges` to
disappear, with no unexpected dependency change. Run collaboration plus all
consumer suites, architecture/check/build, full Backend tests, and these exact
managed smokes with exit 0 and independent zero-residue audits:

```powershell
npm run smoke:sharing
npm run smoke:phase2-sharing-permission-concurrency
npm run smoke:contributor-history-migration
npm run smoke:money-apis
npm run smoke:tasks-apis
npm run smoke:guests-apis
npm run smoke:marketplace
```

Run scope/protected/docs gates and independent review. Commit:

```powershell
git commit -m "refactor: publish collaboration provider contracts"
```

Stop for owner application testing.

---

### Task 4: Publish Notifications Service Contract

**Files:**

- Create: `backend/src/modules/notifications/public/notifications.port.ts`
- Create: `backend/src/modules/notifications/public/notifications-public.module.ts`
- Create: `backend/src/modules/notifications/internal/notifications-service.internal.module.ts`
- Create: `backend/test/architecture-r3-notifications-port.test.ts`
- Modify: `backend/src/notifications/notifications.service.ts`
- Modify: `backend/src/notifications/notifications.module.ts`
- Modify: exact NotificationsService consumer files listed above
- Modify: every legacy module that imports `NotificationsModule` only for the
  exported service

**Interfaces:** Produces `NOTIFICATIONS_PORT` and public notification input,
response, visibility-client, create-client, and purge-client types.

- [ ] **Step 1: Write RED tests for the exact service surface and consumers**

Include transaction-client preservation, nullable notification behavior,
visibility filtering, purge counts, task-due behavior, singleton identity, and
no concrete foreign import.

- [ ] **Step 2: Create the internal/public leaf**

The internal leaf imports Prisma, Outbox Core, and Collaboration Permission
Public, owns `NotificationsService`, and exports the concrete class for
owner-only controller/scheduler resolution plus its internal implementation
token. The public leaf aliases that token and never imports or exports the
legacy class. Keep
`NotificationRemindersScheduler` outside the public leaf so importing the port
cannot duplicate scheduled work.

- [ ] **Step 3: Migrate all exact consumers**

Update the 11 files in the contract map and their owner modules. Preserve all
calls and transaction objects. `quote-notifications.ts` imports public types
only and does not inject a provider.

- [ ] **Step 4: Verify and checkpoint**

Require only the Task-4 manifest subset of `remainingRetiredLegacyProviderEdges` to
disappear. Run focused notifications, outbox, task, sharing, marketplace,
provider, conversation, dashboard, and admin suites; architecture/check/build;
full tests; then exact managed smokes:

```powershell
npm run smoke:notifications
npm run smoke:notifications-apis
npm run smoke:phase2-notification-preferences
npm run smoke:phase2-notification-authorization-concurrency
```

Require exit 0 and zero residue, then scope/protected/docs and independent
review. Commit:

```powershell
git commit -m "refactor: publish notifications provider contract"
```

Stop for owner application testing.

---

### Task 5: Publish Identity Auth Contracts and Remove Runtime/JWT Debt

**Files:**

- Create: `backend/src/modules/identity/public/identity-auth.port.ts`
- Create: `backend/src/modules/identity/public/identity-auth-public.module.ts`
- Create: `backend/src/modules/identity/internal/identity-auth.internal.module.ts`
- Create: `backend/test/architecture-r3-identity-port.test.ts`
- Modify: `backend/src/auth/auth.service.ts`
- Modify: `backend/src/auth/auth.module.ts`
- Modify: `backend/src/sharing/invite-access.service.ts`
- Modify: `backend/src/conversations/conversations.gateway.ts`
- Modify: `backend/src/conversations/conversations.module.ts`
- Modify: `backend/src/notifications/notifications.module.ts`
- Modify: `backend/src/push/push.module.ts`
- Modify: `backend/src/timeline/timeline.module.ts`
- Modify: `backend/src/platform/config/runtime-environment.ts`
- Modify: `backend/src/main.ts`
- Modify: existing runtime/auth/WebSocket tests only for mechanical injection
  wiring; add new error-precedence assertions
- Modify: dependency baseline only after semantic verification

**Interfaces:** Produces `IDENTITY_AUTH_PORT`,
`IDENTITY_ACCESS_TOKEN_VERIFIER`, public invite OTP types, and exact runtime
secret-validator composition callback.

- [ ] **Step 1: Write RED identity and runtime-order tests**

Assert Auth and verifier token identity, InviteAccess behavior parity, WebSocket
valid/invalid/expired/scope/session behavior parity, one JwtStrategy, and this
exact error order: missing required variables; identity secret callback; OTP
mode; production login-throttle pepper; global OTP limit; push; media; then
WhatsApp/OpenWA transport-specific validation. Assert callback count is one on a
valid path and zero when required variables are missing.

- [ ] **Step 2: Create the Auth provider leaf**

The internal leaf owns AuthService, JwtStrategy, throttle/quota providers and
schedulers, imports Messaging Realtime Public, Passport, Prisma, and the one
configured JwtModule. It exports AuthService for owner-only controller/provider
resolution, aliases it to the internal implementation token, and re-exports the
configured `JwtModule` rather than attempting to export `JwtService` as an
unowned provider. The public leaf imports the internal leaf,
aliases the Auth implementation token and the visible `JwtService` to the two
public tokens, and exports only those tokens.

- [ ] **Step 3: Migrate InviteAccess and WebSocket consumers**

Inject `IDENTITY_AUTH_PORT` into InviteAccess. Inject
`IDENTITY_ACCESS_TOKEN_VERIFIER` into `ConversationsGateway` and preserve its
generic verification call and error behavior. Before Task 6 deletes
`AuthModule`, migrate the surviving Conversations, Notifications, Push, and
Timeline legacy modules to import `IdentityAuthPublicModule`; this preserves the
one JwtStrategy/Passport runtime path for their `JwtAuthGuard` controllers. The
other AuthModule importers are replaced atomically by their full modules in
Task 6. No foreign module imports `AuthModule` when Task 6 deletes it.

- [ ] **Step 4: Compose runtime secret validation**

Change the platform function to require the callback with no default. Import
`getJwtSecret` only in `main.ts` and pass it at the existing call site. Update
all direct unit-test calls to provide the real function or a deterministic
test callback, without changing expected errors.

- [ ] **Step 5: Delete the final platform debt**

Run the baseline relocation/decrease verifier. Require the runtime/JWT platform
key plus only the Task-5 subset of `remainingRetiredLegacyProviderEdges` to be
deleted, with zero unexpected deletion/addition/rename/increase. The
`remainingPlatformDebts` array must now be empty while its immutable initial
ledger stays unchanged.

- [ ] **Step 6: Verify and checkpoint**

Run focused auth/OTP/WebSocket/runtime tests, architecture/check/build, full
Backend tests, then exact managed smokes:

```powershell
npm run smoke:health
npm run smoke:auth
npm run smoke:auth-verification
npm run smoke:otp-profile
npm run smoke:conversation-unification
```

Require exit 0 and zero residue, then scope/protected/docs and independent
review. Commit:

```powershell
git commit -m "refactor: publish identity auth contracts"
```

Stop for owner application testing.

---

### Task 6: Cut Over Identity, Planning, Finance, Collaboration, Tasks, and Guests

**Files:**

- Create the six full modules from the full-module map
- Create private internal modules under each owner's `internal/` directory for
  providers that are not already owned by public leaves
- Create: `backend/test/architecture-r3-context-modules-a.test.ts`
- Modify: `backend/src/app.module.ts`
- Delete superseded full metadata files:
  `auth/auth.module.ts`, `users/users.module.ts`, `me/me.module.ts`,
  `contexts/contexts.module.ts`, `wedding-plans/wedding-plans.module.ts`,
  `onboarding/onboarding.module.ts`, `money/money.module.ts`,
  `budget-categories/budget-categories.module.ts`,
  `wedding-costs/wedding-costs.module.ts`, `sharing/sharing.module.ts`,
  `contribution-history/contribution-history.module.ts`, `tasks/tasks.module.ts`,
  and `guests/guests.module.ts`

**Interfaces:** Produces six full context modules. No new public application
port is introduced.

- [ ] **Step 1: Write metadata parity RED tests**

Use the Task 1 manifest to assert semantic composition parity: exact
controller/route/OpenAPI metadata; equivalent provider/lifecycle ownership with
no duplicate classes and one scheduler per class; every old concrete export
replaced by a manifest-listed public token or proved to have no consumer; and
every old module import replaced by its declared public/internal dependency.
Literal import/export-array equality is not expected. Assert the old active
module files still cause RED.

- [ ] **Step 2: Build provider internals and six full modules**

Register each legacy provider once in the smallest owner internal module that
matches its real dependencies. Import only Prisma/platform/same-context internals
and foreign PublicModules. Full modules register the exact legacy controllers
and import owner internals/public leaves. Do not export concrete providers.

- [ ] **Step 3: Cut AppModule and delete old metadata atomically**

Replace the 13 listed legacy imports for these roots with the six new full
modules in one change. Delete the superseded module files only after focused
compile/parity is green. Assert every surviving legacy module has already
stopped importing `AuthModule` before deleting it. Keep controller/service
implementation paths intact.

- [ ] **Step 4: Verify and checkpoint**

Require only the Task-6 manifest subset of `remainingRetiredLegacyProviderEdges` to
disappear. Run parity/boot/singleton tests, every affected domain suite,
architecture, check/build, full tests, and these exact managed smokes:

```powershell
npm run smoke:wedding-plan
npm run smoke:onboarding-active-plan
npm run smoke:money-apis
npm run smoke:tasks-apis
npm run smoke:guests-apis
npm run smoke:sharing
npm run smoke:contributor-history-migration
```

Require exit 0 and zero residue, then scope/protected/docs and independent
review. Commit:

```powershell
git commit -m "refactor: compose core R3 business contexts"
```

Stop for owner application testing.

---

### Task 7: Cut Over Marketplace, Catalog, Media, Insights, and Backoffice

**Files:**

- Create the five full modules from the full-module map
- Create owner-private internal modules for remaining providers
- Create: `backend/test/architecture-r3-context-modules-b.test.ts`
- Modify: `backend/src/app.module.ts`
- Delete superseded metadata files:
  `marketplace/marketplace.module.ts`,
  `provider-dashboard/provider-dashboard.module.ts`,
  `catalogs/catalogs.module.ts`, `media/media.module.ts`,
  `dashboard/dashboard.module.ts`, `timeline/timeline.module.ts`, and
  `admin/admin.module.ts`

**Interfaces:** Produces five full context modules, removes the two redundant
explicit Backoffice guard provider registrations, and preserves exact
controller-local decorator runtime metadata.

- [ ] **Step 1: Write RED parity and decorator-runtime tests**

Assert exact controllers/providers, byte-equivalent `@UseGuards` class/order and
route metadata in Admin and `catalogs/catalogs.controller.ts`, no explicit guard
provider registration, no guard PublicModule/concrete public export, exact
framework enhancer classification, and the continued exact R1 pure-domain
exception. Prove a fake exported guard module creates an unused extra provider
and is rejected.

- [ ] **Step 2: Remove redundant explicit guard ownership**

Do not list `AdminGuard` or `AdminPermissionGuard` in either new full module's
providers. Do not create a guard-owning module or wrapper. Preserve the existing
controller class imports and decorator metadata exactly; Nest owns their
controller-local enhancer wrappers. Reduce `remainingDuplicateProviders` from
the two guards to empty while `initialDuplicateProviders` remains immutable.
The scanner names the real legacy consumer path
`catalogs/catalogs.controller.ts` and its Catalog context union, not a
nonexistent `modules/catalog/**` controller.

- [ ] **Step 3: Build and cut over five full modules**

Compose the exact legacy controllers/providers using private leaves and current
public dependencies. Replace AppModule imports and delete old metadata after
parity/boot tests pass.

- [ ] **Step 4: Verify and checkpoint**

Require only the Task-7 manifest subset of `remainingRetiredLegacyProviderEdges` to
disappear. Run affected marketplace/catalog/media/insights/admin tests,
architecture, check/build, full tests, and exact managed smokes:

```powershell
npm run smoke:marketplace
npm run smoke:provider-dashboard
npm run smoke:reference-catalog
npm run smoke:dashboard-summary
npm run smoke:phase2-admin-mutation-authorization
npm run smoke:health
```

Require exit 0 and zero residue, then scope/protected/docs and independent
review. Commit:

```powershell
git commit -m "refactor: compose remaining R3 business contexts"
```

Stop for owner application testing.

---

### Task 8: Cut Over Messaging and Notifications and Activate Strict R3 Gates

**Files:**

- Create: `backend/src/modules/messaging/messaging.module.ts`
- Create: `backend/src/modules/messaging/internal/messaging-conversations.internal.module.ts`
- Create: `backend/src/modules/notifications/notifications.module.ts`
- Create notifications private lifecycle/installations internals
- Create: `backend/test/architecture-r3-closure.test.ts`
- Modify: `backend/src/app.module.ts`
- Delete: `backend/src/conversations/conversations.module.ts`
- Delete: `backend/src/notifications/notifications.module.ts`
- Delete: `backend/src/push/push.module.ts`
- Preserve unchanged: `backend/src/conversations/conversation-realtime.module.ts`
- Modify: R3 manifest stage from `inventory` to `strict`
- Modify: dependency baseline and architecture docs/receipts only from verified
  final candidates

**Interfaces:** Produces the final two full context modules and strict R3
architecture state.

- [ ] **Step 1: Write final module/strict-gate RED tests**

Require AppModule's exact 13 full context imports, one application Outbox
runtime seam, the explicit root readiness composition binding, no superseded
legacy metadata except the approved realtime global leaf, empty remaining
duplicate/platform/retired-legacy arrays with immutable initial ledgers intact,
no hollow ports,
every token consumed, exact singleton identities, exact lifecycle counts, zero
cycles/forwardRef/new globals, and frozen route/OpenAPI/provider parity.

- [ ] **Step 2: Build Messaging and Notifications full modules**

Messaging owns conversations controllers/service/gateway and imports Identity
Auth Public, Media Storage Public, Notifications Public, Outbox Core, Prisma,
and the existing realtime internal/global leaf. Notifications owns notification
and push controllers, reminders, installations, public provider leaves, and
private lifecycle providers. Remove the temporary
Notifications-to-legacy-PushModule import in the same atomic change that moves
`PushController` and `PushInstallationsService` into the Notifications full
module. Register every provider exactly once and prove route/controller
reachability never dropped from Task 2 through Task 8.

- [ ] **Step 3: Complete AppModule cutover and delete old metadata**

AppModule must import exactly the 13 full modules, platform infrastructure, and
`ApplicationOutboxRuntimeModule`, plus Media Storage Public for the root-owned
readiness alias/service. Keep health/metrics/root interceptors and guards
unchanged. Delete the three superseded module files; retain the realtime global
leaf byte-for-byte for R8.

- [ ] **Step 4: Activate strict machine gates**

Set manifest stage to `strict`, empty only the three remaining arrays, preserve
all initial ledgers byte-exact, and require all public token consumer and
singleton checks. Generate dependency and
ownership candidates into unique OS-temp paths; require the cumulative
dependency deletions to equal exactly the immutable manifest union of
`initialPlatformDebts` and `initialRetiredLegacyProviderEdges`, while both
remaining arrays are empty, with no other removal, addition, rename, or increase
and byte-identical ownership semantics before copying the dependency candidate.

- [ ] **Step 5: Exhaustive local closure**

Run:

```powershell
cd backend
npm run architecture
npm run check
npm run build
npm test
npx prisma validate
npm audit --audit-level=high
npm audit --omit=dev
npm run smoke:all

cd ../admin-web
npm run typecheck
npm test -- --run
npm run build
npm run smoke:honesty
npm run smoke:routes
npm run test:container-config

cd ../mobile
node --test scripts/check-mobile-boundaries.test.mjs
node scripts/check-mobile-boundaries.mjs --check-baseline
flutter analyze --no-pub
flutter test --no-pub

cd ..
node scripts/docs-sync.mjs --check
node scripts/docs-verify.mjs
git diff --check
```

Use the normal process-scoped non-secret Prisma validation precondition. Record
all expected warnings honestly. In one fail-clean orchestration with a unique
verified OS-temp directory, run the exact semantic proof (the angle-bracket
paths are variables bound to that directory, never repository paths):

```powershell
git archive 6b06eb096aca8cc6684d365d16e05d4cd8529898 `
  backend/prisma/schema | tar -xf - -C <unique-r3-prisma-temp>
npx prisma generate --schema `
  <unique-r3-prisma-temp>/backend/prisma/schema
node scripts/prisma/dmmf-fingerprint.cjs --output `
  <unique-r3-prisma-temp>/base-dmmf.json

npx prisma validate
npx prisma generate
node scripts/prisma/dmmf-fingerprint.cjs --output `
  <unique-r3-prisma-temp>/candidate-dmmf.json
npx prisma migrate diff --exit-code `
  --from-schema-datamodel `
  <unique-r3-prisma-temp>/backend/prisma/schema `
  --to-schema-datamodel prisma/schema
```

Require base/candidate DMMF bytes equal at the frozen 52-model/41-enum
fingerprint and migrate diff exit 0 with `No difference detected`; remove the
process-scoped placeholder and the exact temp tree in `finally`, then prove the
tree is absent. Verify schema 14/52/41/76, seed/migration recursive hashes,
generated docs, protected surfaces, API/Mobile/Admin/deploy hashes, and no
managed residue.

- [ ] **Step 6: Independent final review and checkpoint**

Obtain independent adversarial source/contract/runtime review. Fix every
Critical/Important/Minor finding through RED→GREEN before committing:

```powershell
git commit -m "refactor: enforce modular monolith R3 Nest boundaries"
```

Leave the worktree clean and stop before runtime cutover.

---

### Task 9: Immutable Runtime, Owner Phone Gate, and R3 Receipt

**Files:**

- Modify before runtime only: `docs/project/STATUS.md`, as the immutable
  preliminary candidate receipt with runtime/phone explicitly pending.
- Modify the remaining approved active Markdown receipt/navigation files only
  after runtime and owner evidence is complete.
- Create ignored reports under
  `.superpowers/sdd/2026-08-14-modular-monolith-r3-nest-boundaries/`.

**Interfaces:** Produces one immutable R3 image, preserved R2 rollback, final
local receipt commit, and explicit R4-not-started status.

- [ ] **Step 1: Create an immutable docs-only runtime candidate**

Record local automated gates as passed but runtime/phone as pending. Commit only
the approved preliminary status file, bind the Docker image label/revision to
that full commit, and do not mutate it afterward.

- [ ] **Step 2: Probe and cut over safely**

Build the R3 image, inspect revision/files without printing environment values,
run a unique host-port probe, verify migrations/live/ready/restart/log gates,
then stop and preserve the exact R2 container before binding R3 to port 3120.
Verify local and current LAN health and zero probe/temp residue.

- [ ] **Step 3: Owner application checkpoint**

The owner tests login/OTP, Home, one core read/write, notifications, and
messaging when available. On FAIL, collect sanitized evidence and immediately
restore the verified R2 container. On PASS, parse only safe method/path/status
events and forbidden fatal markers; do not retain tokens, bodies, or secrets.

- [ ] **Step 4: Write the final receipt and review it independently**

Update `ARCHITECTURE.md`, `docs/README.md`, `docs/project/STATUS.md`,
`docs/project/DECISIONS.md`, `docs/project/EXECUTION_PLAN.md`,
`docs/qa/README.md`, and `CHANGELOG.md` only with verified counts, hashes,
runtime identity, warnings, owner result, preserved rollback, and explicit
`no push/no merge/no remote CI/R4 not started` language. Run docs/scope/
protected/runtime gates and independent receipt review.

- [ ] **Step 5: Commit the local R3 receipt**

```powershell
git commit -m "docs: close modular monolith R3 locally"
```

Leave the branch clean. Do not push, merge, open/mutate a PR, or begin R4
without a new owner instruction.

## Plan Self-Review Checklist

- [ ] Every design requirement maps to one task.
- [ ] No task creates a hollow token or speculative public API.
- [ ] Every concrete provider has one owner and every public token has a live
  consumer.
- [ ] Decorator-runtime guard references and route metadata are exact;
  redundant explicit Admin/Catalog guard provider registrations are gone
  without a guard PublicModule or concrete public export.
- [ ] The Outbox alias providers and consumers share the composition module.
- [ ] Runtime/JWT callback order and invocation count are frozen.
- [ ] The six platform debts and exact retired legacy provider-edge set can
  only decrease to zero; no baseline regeneration is accepted without semantic
  comparison.
- [ ] All 13 full modules are created and all superseded metadata is removed at
  a reviewed checkpoint.
- [ ] Two globals and zero `forwardRef` remain exact.
- [ ] Existing behavior, tests, schema, API, Mobile, Admin, deployment, and
  later-phase boundaries are protected.
- [ ] Every task ends with tests, managed smoke, independent review, a local
  checkpoint commit, and owner continuation.
