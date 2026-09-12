# Modular Monolith R12C Zero Cross-Context Dependencies Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** APPROVED — independent review 0 Critical / 0 Important / 0 Minor; implementation not started  

**Goal:** Retire the exact R11 dependency IDs `10, 12-17, 19-20`, prove unbaselined cross-context dependency zero, and delete only the dependency-cruiser known-violations baseline while preserving Product Logic and physical ownership `385/781`.

**Architecture:** Use one exact Finance public response projection, one synchronous transaction-bound Messaging lifecycle port backed by the existing private implementation, and one pure Marketplace public provider-access policy. Advance through `9 -> 7 -> 2 -> 0`, independently review each batch, prove zero without ignores before deleting the dependency baseline, and keep the ownership baseline byte-identical.

**Tech Stack:** NestJS 11, TypeScript, Prisma 6, PostgreSQL transaction contracts, Node test runner, dependency-cruiser 18, repository architecture scanners, PowerShell, Markdown SDD.

**Spec:** `docs/superpowers/specs/2026-09-08-modular-monolith-r12c-zero-cross-context-dependencies-design.md`

## Global Constraints

- This plan is not implementation authorization. A later session must receive
  explicit owner approval before Task 1.
- Execute Tasks 1-7 in order. Stop safely after any task; never combine source
  batches or skip an independent review.
- Preserve routes, payloads, DTO validation, errors, Arabic text, permissions,
  Product Logic, transaction boundaries, lock order, retry semantics,
  idempotency, and public response behavior.
- Do not change Prisma schema, migrations, model ownership, ownership registry,
  or the ownership baseline. Its raw SHA-256 must remain
  `5f42f33300a9727f587e62327c5261a88a6ce5928437241c9e7c20f726906496`.
- Do not implement R13-R18 work. Existing ownership leaks in Marketplace,
  Messaging, and Notifications remain visible and assigned to later phases.
- Do not add compatibility re-exports, forwarding facades, default fallback
  implementations, optional port fallbacks, duplicate code, broad allowlists,
  or new dependency exceptions.
- Do not weaken, delete, skip, disable, or rename behavioral assertions to make
  a gate pass. Constructor fixtures may add only the new required port double;
  their behavioral assertions remain unchanged.
- The live dependency ledger may only be the exact R12B nine minus the IDs
  approved for the current stage. Never regenerate or reorder it.
- Delete `.dependency-cruiser-known-violations.json` only after Task 4 has
  independently proven an exact empty ledger and a direct unignored scan.
- All generated/candidate files must be plain regular files under the exact
  repository root; reject symlinks, reparse points, alternate paths, duplicate
  records, unsafe JSON, and unregistered changes.
- No commit, push, merge, branch, checkout, reset, worktree, deploy, production
  mutation, remote CI, provider delivery, phone, or release action is included.
- Every review exit is Critical `0`, Important `0`, Minor `0`. A nonzero review
  finding blocks the next task.

## Immutable Entry Ledger

| ID | Exact live source -> target |
| ---: | --- |
| 10 | `src/marketplace/marketplace.service.ts` -> `src/wedding-costs/wedding-cost.presenter.ts` |
| 12 | `src/marketplace/quote-offer-acceptance.ts` -> `src/conversations/conversation-lifecycle.ts` |
| 13 | `src/marketplace/quote-offer-acceptance.ts` -> `src/wedding-costs/wedding-cost.presenter.ts` |
| 14 | `src/marketplace/quote-offer-rejection.ts` -> `src/conversations/conversation-lifecycle.ts` |
| 15 | `src/marketplace/quote-request-cancellation.ts` -> `src/conversations/conversation-lifecycle.ts` |
| 16 | `src/marketplace/quote-request-creation.ts` -> `src/conversations/conversation-lifecycle.ts` |
| 17 | `src/provider-dashboard/provider-dashboard.service.ts` -> `src/conversations/conversation-lifecycle.ts` |
| 19 | `src/conversations/conversations.service.ts` -> `src/provider-dashboard/provider-access-policy.ts` |
| 20 | `src/notifications/notifications.service.ts` -> `src/provider-dashboard/provider-access-policy.ts` |

The entry dependency file raw SHA-256 is
`fe4d3bfe23cf0400266bbfea8bd0357d578b93cad005c77af0814ec52ccfcb53`.
The predecessor R12B manifest raw SHA-256 is
`1bf0c2d00886f1ec442187f2719c4d604b0ebcc57a3ada56d97006015c029845`.

---

### Task 1: Freeze R12C Successor Governance At Dependency 9

**Objective:** Create the fail-closed R12C manifest, scanner, and TDD contract
at the exact closed R12B entry without changing source behavior or debt.

**Exact dependencies closed:** none; entry remains `9`.

**Files:**

- Create: `backend/architecture/r12c-zero-cross-context-dependencies.json`
- Create: `backend/scripts/architecture/r12c-zero-cross-context-dependencies-scan.cjs`
- Create: `backend/test/architecture-r12c-zero-cross-context-dependencies.test.ts`
- Modify: `backend/scripts/architecture/r12b-planning-public-contracts-scan.cjs`
- Modify: `backend/test/architecture-r12b-planning-public-contracts.test.ts`
- Modify: `backend/package.json`
- Modify only for exact package-script projection:
  `backend/scripts/security/prisma-config-merge-security.cjs`
- Modify only for that security projection:
  `backend/test/prisma-config-merge-security.test.ts`
- Create SDD evidence under:
  `.superpowers/sdd/2026-09-08-modular-monolith-r12c-zero-cross-context-dependencies/`

**Forbidden surfaces:** all `backend/src/**`, dependency and ownership
baselines, package lock/dependencies, R12A/R12B manifests, product docs, Mobile,
Admin Web, Prisma, deployment.

**Interfaces:**

- Manifest stage names are exactly `design`, `finance-public`,
  `messaging-lifecycle-public`, `zero-proven`, `strict`.
- Immutable retired ID prefixes are exactly `[]`, `[10,13]`,
  `[10,12,13,14,15,16,17]`, and
  `[10,12,13,14,15,16,17,19,20]` for both final stages.
- Counts are exactly `9`, `7`, `2`, `0`, `0`.
- R12B successor projection must reconstruct the exact activated R12B
  predecessor; fixtures without an R12C manifest remain governed by the
  unchanged historical path.
- `architecture:r12c` is appended once after `architecture:r12b`; the aggregate
  still uses the baselined import command until Task 5.

- [ ] **Step 1: Capture immutable entry and scope evidence**

Run from repository root:

```powershell
git rev-parse --show-toplevel
git branch --show-current
git rev-parse HEAD
git diff --cached --name-only
Get-FileHash -Algorithm SHA256 backend/.dependency-cruiser-known-violations.json
Get-FileHash -Algorithm SHA256 backend/architecture/ownership-baseline.json
Get-FileHash -Algorithm SHA256 backend/architecture/r12b-planning-public-contracts.json
npm --prefix backend run architecture:imports
npm --prefix backend run architecture:ownership
npm --prefix backend run architecture:r12b
```

Expected: exact identity above; staged 0; dependency 9; R12B activated/4;
ownership 385/781.

- [ ] **Step 2: Write the RED architecture tests before scanner/manifest logic**

The new test must assert:

1. all nine semantic keys and original IDs occur exactly once;
2. any missing, added, reordered, duplicated, or mutated record fails;
3. stage/retired-prefix mismatch fails;
4. forged R12B hash, receipt, documentation stage, branch, root, or HEAD fails;
5. non-plain manifest/scanner inputs fail;
6. ownership bytes/counts are exact and immutable;
7. an R12C successor can project to the activated R12B predecessor;
8. fixtures without R12C still exercise the R12B historical contract;
9. future contract paths cannot appear at `design`;
10. Task 1 planning docs are the only new non-source planning surface.

Run:

```powershell
cd backend
node --test -r ts-node/register test/architecture-r12c-zero-cross-context-dependencies.test.ts
```

Expected RED: failure is specifically missing R12C manifest/scanner/successor
authority. Save command, exit, pass/fail/skip, and the exact failing assertion.

- [ ] **Step 3: Implement the minimal design-stage manifest and scanner**

The manifest must bind:

- repository identity and exact R12B predecessor hash/state;
- all nine full dependency records with R11 IDs;
- all three contract families, exact consumers, target source hashes, stages,
  exception retirement, behavior tests, protected surfaces, and inverse
  transforms;
- the unchanged ownership hash/totals;
- normalized self-fingerprint and raw fingerprints for all governed files.

The scanner must export bounded validators/projectors for later tasks but accept
only `stage=design` at this step. It must use existing safe-path/plain-file and
plain-data patterns rather than a second path normalizer.

- [ ] **Step 4: Add the R12B successor handoff and package/security projection**

The R12B scanner must recognize the exact R12C manifest, project R12C planning
files away when reconstructing its predecessor, and otherwise retain all
activated/receipt/security assertions. Add only:

```json
"architecture:r12c": "node scripts/architecture/r12c-zero-cross-context-dependencies-scan.cjs --check"
```

and append `&& npm run architecture:r12c` once to the aggregate. Extend Prisma
security projection for that exact pair; no dependency or lock change.

- [ ] **Step 5: Prove GREEN and historical regression**

```powershell
cd backend
node --test -r ts-node/register `
  test/architecture-r12c-zero-cross-context-dependencies.test.ts `
  test/architecture-r12b-planning-public-contracts.test.ts `
  test/prisma-config-merge-security.test.ts
npm run architecture:r12b
npm run architecture:r12c
npm run security:prisma-config-merge
npm run check
```

Expected: no skip; R12C design/dependency9/ownership385/781; R12B still
activated/4; TypeScript and security PASS.

- [ ] **Step 6: Independent Task 1 review**

Create `task-1-report.md`, `task-1-review-package.md`, and independent
`task-1-review.md`. Reviewer must inspect record completeness, predecessor
reconstruction, unsafe-input rejection, package/security projection, and scope.
Exit only at 0/0/0.

**Rollback point:** remove the three new R12C governance files and reverse only
the exact R12B/package/security successor hunks. The original R12B scanner must
again pass activated/4/dependency9.

**Completion evidence:** exact entry hashes, RED cause, GREEN totals, full
nine-ID inventory, staged/protected status, reviewer 0/0/0.

---

### Task 2: Publish The Finance Wedding-Cost Projection And Close IDs 10/13

**Objective:** Move the existing canonical wedding-cost query/response
projection into Finance public ownership and rewrite its three consumers
without changing money or quote behavior.

**Exact dependencies closed:** IDs `10`, `13`; debt `9 -> 7`.

**Files:**

- Move: `backend/src/wedding-costs/wedding-cost.presenter.ts` ->
  `backend/src/modules/finance/public/wedding-cost.presenter.ts`
- Modify imports only: `backend/src/wedding-costs/wedding-costs.service.ts`
- Modify import only: `backend/src/marketplace/marketplace.service.ts`
- Modify import only: `backend/src/marketplace/quote-offer-acceptance.ts`
- Modify exact subtraction: `backend/.dependency-cruiser-known-violations.json`
- Modify R12C governance: manifest, scanner, R12C test
- Create Task 2 SDD report/review artifacts

**Forbidden surfaces:** presenter behavior/body/export changes, Finance writes,
Prisma schema/migrations, ownership files, DTOs/controllers, other tests,
packages, shared-kernel, R13.

**Interfaces:** final public export inventory remains exactly
`weddingCostResponseInclude`, `WeddingCostWithDetails`,
`WeddingCostResponse`, `toWeddingCostResponse`.

- [ ] **Step 1: Preregister exact Task 2 candidate hashes and inverse move**

Update only the R12C manifest governance metadata while it remains at design.
Forward and inverse reconstruction must prove the moved file is byte-identical
and only import specifiers change in the three consumers.

- [ ] **Step 2: Add RED contract and architecture assertions**

Tests must expect one Finance public file, no legacy file, exactly three
consumer imports, exact export inventory/source parity, baseline equal to entry
minus IDs 10/13, no other retirement, and ownership raw hash unchanged.

```powershell
cd backend
node --test --test-name-pattern="R12C Finance projection" `
  -r ts-node/register test/architecture-r12c-zero-cross-context-dependencies.test.ts
```

Expected RED: public target/rewrites are absent; fixture and entry authority
remain valid.

- [ ] **Step 3: Perform the exact one-to-one move and import rewrites**

Do not retain a re-export, forwarding file, copied include, or copied mapper.
Remove only the two immutable dependency records and set stage
`finance-public`.

- [ ] **Step 4: Prove source parity and focused behavior GREEN**

```powershell
cd backend
node --test -r ts-node/register `
  test/architecture-r12c-zero-cross-context-dependencies.test.ts `
  test/financial-integrity.test.ts `
  test/quote-provider-notifications.test.ts `
  test/quote-stability.test.ts
npm run architecture:r12c
npm run architecture:imports
npm run architecture:ownership
npm run check
```

Expected: dependency 7, IDs 10/13 absent, added/unexpected removed 0,
ownership hash and 385/781 unchanged, all behavior PASS with no skip.

- [ ] **Step 5: Independent Task 2 review**

Review money Decimal/count/date/null semantics, accepted-offer replay and
idempotency, exact move, no duplicate/facade, named ID subtraction, and scope.
Exit 0/0/0.

**Rollback point:** restore the legacy presenter, three original imports, exact
nine-row ledger, and design manifest as one unit.

**Completion evidence:** RED/GREEN totals, old/public path `0/1`, consumers 3,
dependency 7, ownership unchanged, review 0/0/0.

---

### Task 3: Introduce The Transaction-Bound Messaging Lifecycle Port

**Objective:** Replace five direct lifecycle imports with one Messaging-owned
application port while preserving the exact caller transaction and private
lifecycle implementation.

**Exact dependencies closed:** IDs `12`, `14`, `15`, `16`, `17`; debt `7 -> 2`.

**Files:**

- Create: `backend/src/modules/messaging/public/conversation-lifecycle.port.ts`
- Create:
  `backend/src/modules/messaging/public/conversation-lifecycle-public.module.ts`
- Create:
  `backend/src/modules/messaging/internal/conversation-lifecycle.internal.module.ts`
- Modify type declarations/imports only, without algorithm or runtime behavior
  change: `backend/src/conversations/conversation-lifecycle.ts`
- Modify: `backend/src/modules/marketplace/internal/marketplace-services.internal.module.ts`
- Modify constructor/threading: `backend/src/marketplace/marketplace.service.ts`
- Modify threading: `backend/src/marketplace/quote-offer-acceptance.ts`
- Modify threading: `backend/src/marketplace/quote-offer-rejection.ts`
- Modify threading: `backend/src/marketplace/quote-request-cancellation.ts`
- Modify threading: `backend/src/marketplace/quote-request-creation.ts`
- Modify constructor/calls: `backend/src/provider-dashboard/provider-dashboard.service.ts`
- Modify exact subtraction: `backend/.dependency-cruiser-known-violations.json`
- Modify R12C manifest/scanner/test
- Modify only constructor fixtures containing `new MarketplaceService` or
  `new ProviderDashboardService` in these current files:
  - `backend/test/admin-app-identity.test.ts`
  - `backend/test/archived-plan-lifecycle.test.ts`
  - `backend/test/contributor-money-marketplace-scope.test.ts`
  - `backend/test/contributor-live-read-boundary.test.ts`
  - `backend/test/marketplace-my-quote-authorization.test.ts`
  - `backend/test/media-url-ownership.test.ts`
  - `backend/test/provider-price-validation.test.ts`
  - `backend/test/provider-rating-atomicity.test.ts`
  - `backend/test/provider-status-access.test.ts`
  - `backend/test/quote-provider-notifications.test.ts`
  - `backend/test/quote-guest-visibility.test.ts`
  - `backend/test/quote-stability.test.ts`
  - `backend/scripts/smoke/phase2-marketplace-write-concurrency-smoke.ts`
  - `backend/scripts/smoke/phase2-quote-concurrency-smoke.ts`
  - `backend/scripts/smoke/phase2-provider-dashboard-concurrency-smoke.ts`
  - `backend/scripts/smoke/phase2-provider-rating-concurrency-smoke.ts`
  - `backend/scripts/smoke/phase3-context-transition-smoke.ts`
- Modify the direct standalone-helper call sites in exactly these three already
  listed test files so the required lifecycle port is passed explicitly:
  - `backend/test/provider-status-access.test.ts`
    (`acceptQuoteOfferInTransaction`)
  - `backend/test/quote-provider-notifications.test.ts`
    (`acceptQuoteOfferInTransaction`)
  - `backend/test/quote-stability.test.ts`
    (`createQuoteRequestInTransaction`)
- Create Task 3 SDD report/review artifacts

If a fresh exact `rg` finds a constructor call outside this list, stop and seek
scope approval before editing it. Do not use an optional/default fallback to
avoid a fixture update.

**Forbidden surfaces:** lifecycle algorithm, SQL, event data, dedupe keys,
transactions, lock order, notifications, controller/DTO/API behavior,
ownership baseline, realtime port, packages, R16.

**Interfaces:**

```typescript
import type {
  ConversationEvent,
  ConversationEventType,
  ConversationScope,
  Prisma,
} from '@prisma/client';

export const CONVERSATION_LIFECYCLE_PORT = Symbol(
  'CONVERSATION_LIFECYCLE_PORT',
);

export type ConversationLifecycleClient = Pick<
  Prisma.TransactionClient,
  | '$queryRaw'
  | 'conversation'
  | 'conversationEvent'
  | 'conversationParticipant'
  | 'outboxEvent'
  | 'provider'
  | 'weddingPlan'
>;

export interface EnsureConversationContextInput {
  requesterUserId: string;
  providerId: string;
  weddingPlanId: string | null;
  activityAt?: Date;
}

export interface RecordConversationEventInput {
  conversationId: string;
  quoteRequestId?: string | null;
  quoteOfferId?: string | null;
  actorUserId?: string | null;
  type: ConversationEventType;
  occurredAt?: Date;
  dedupeKey: string;
  data?: Prisma.InputJsonObject;
}

export interface RecordConversationEventResult {
  event: ConversationEvent;
  created: boolean;
}

export interface ConversationLifecyclePort {
  ensureConversationContext(
    tx: ConversationLifecycleClient,
    input: EnsureConversationContextInput,
  ): Promise<{ id: string; scope: ConversationScope }>;
  recordConversationEvent(
    tx: ConversationLifecycleClient,
    input: RecordConversationEventInput,
  ): Promise<RecordConversationEventResult>;
}
```

These are the canonical public types. The legacy implementation removes its
local duplicate type declarations and imports these types type-only; its
algorithm and runtime enum/Prisma use remain unchanged. The internal module
binds one object that delegates directly to the two existing Messaging
functions. The public module exposes only the token and public types through
one `useExisting` identity. It must not import Marketplace.

- [ ] **Step 1: Preregister exact port/module/consumer candidates**

Record all raw hashes, exact constructor sites, expected imported symbols, and
inverse transforms before publishing any Task 3 source.

- [ ] **Step 2: Add RED port, wiring, transaction-identity, and no-dual-path tests**

Assert:

- one public token/interface and one public module;
- one internal implementation provider and one `useExisting` binding;
- public and internal provider identities are the same;
- exact transaction object is passed to each lifecycle call;
- `ensureConversationContext` and `recordConversationEvent` preserve argument
  order and return/error identity;
- exactly five deep dependency rows disappear;
- no direct legacy import, dynamic require, public re-export, fallback, nested
  transaction, or second implementation exists;
- ownership hash remains exact.

Expected RED must identify missing port/wiring, not a broken fixture.

- [ ] **Step 3: Create port and internal/public binding**

The adapter delegates to the existing functions and contains no business
branch. `MarketplaceServicesInternalModule` imports only the Messaging public
module. No reciprocal public-slice import is allowed.

- [ ] **Step 4: Inject and thread the required port**

Add the required port before MarketplaceService's optional history argument and
as the final required ProviderDashboardService argument. Pass it explicitly to
all four standalone quote helpers. Update the three enumerated direct-helper
fixtures as well as the listed constructor fixtures by supplying a strict fake
that fails unexpected methods; preserve every existing assertion.

- [ ] **Step 5: Subtract exact IDs and prove focused GREEN**

```powershell
cd backend
node --test -r ts-node/register `
  test/architecture-r12c-zero-cross-context-dependencies.test.ts `
  test/admin-app-identity.test.ts `
  test/archived-plan-lifecycle.test.ts `
  test/contributor-money-marketplace-scope.test.ts `
  test/contributor-live-read-boundary.test.ts `
  test/provider-dashboard-mutation-atomicity.test.ts `
  test/marketplace-my-quote-authorization.test.ts `
  test/media-url-ownership.test.ts `
  test/provider-price-validation.test.ts `
  test/provider-rating-atomicity.test.ts `
  test/provider-status-access.test.ts `
  test/quote-provider-notifications.test.ts `
  test/quote-guest-visibility.test.ts `
  test/quote-stability.test.ts `
  test/provider-chat-logic.test.ts `
  test/outbox-logic.test.ts
npm run architecture:r12c
npm run architecture:imports
npm run architecture:ownership
npm run check
npm run build
```

Expected: dependency 2, IDs 12/14/15/16/17 absent, no other subtraction,
ownership raw unchanged, and every modified test fixture executes with
fail/skip/todo `0`. Record the combined test/pass/fail/skip/todo totals.

- [ ] **Step 6: Run transaction/concurrency smokes**

```powershell
npm run smoke:providers-quotes
npm run smoke:provider-dashboard
npm run smoke:phase2-marketplace-write-concurrency
npm run smoke:phase2-quote-concurrency
npm run smoke:phase2-provider-dashboard-concurrency
npm run smoke:phase2-provider-rating-concurrency
npm run smoke:phase2-conversation-revocation
npm run smoke:phase3-context-transition
```

- [ ] **Step 7: Independent Task 3 review**

Reviewer must trace the same `tx` from caller to Messaging writes, check
provider singleton identity/module cycles, verify no dual path, inspect every
constructor fixture change, and reproduce focused gates. Exit 0/0/0.

**Rollback point:** remove port modules, restore original constructors/helper
signatures/imports and fixture argument lists, restore exact seven-row ledger,
and return manifest to `finance-public` atomically.

**Completion evidence:** RED cause; the combined totals proving every modified
constructor/direct-helper fixture executed with fail/skip/todo 0; port identity;
same-tx proof; dependency 2; ownership unchanged; all eight listed smoke command
results including both newly enumerated smokes; review 0/0/0.

---

### Task 4: Publish Marketplace Provider Access Policy And Prove Zero

**Objective:** Move the pure provider lifecycle policy into Marketplace public,
rewrite every exact consumer, retire the historical exception, remove IDs
19/20, and prove zero with an empty ledger still present.

**Exact dependencies closed:** IDs `19`, `20`; debt `2 -> 0`.

**Files:**

- Move: `backend/src/provider-dashboard/provider-access-policy.ts` ->
  `backend/src/modules/marketplace/public/provider-access-policy.ts`
- Modify imports only, except for the one exact legacy re-export deletion noted
  below:
  - `backend/src/provider-dashboard/provider-dashboard.service.ts`
  - `backend/src/provider-dashboard/provider-mutation-locks.ts`
  - `backend/src/marketplace/quote-offer-acceptance.ts`
  - `backend/src/marketplace/quote-notifications.ts`
  - `backend/src/conversations/conversations.service.ts`
  - `backend/src/notifications/notifications.service.ts`
  - `backend/src/modules/identity/internal/profile/contexts.service.ts`
- Modify exact exception retirement:
  - `backend/.dependency-cruiser.cjs`
  - `backend/scripts/architecture/ports-scan.cjs`
  - `backend/scripts/architecture/r3-context-scan.cjs`
  - `backend/scripts/architecture/r12a-backoffice-catalog-public-contracts-scan.cjs`
  - `backend/scripts/architecture/r12b-planning-public-contracts-scan.cjs`
- Modify exact empty ledger: `backend/.dependency-cruiser-known-violations.json`
- Modify R12C manifest/scanner/test
- Modify path/exception fixtures only:
  - `backend/test/architecture-dependencies.test.ts`
  - `backend/test/architecture-ports.test.ts`
  - `backend/test/architecture-r3-contexts.test.ts`
  - `backend/test/architecture-r12a-backoffice-catalog-public-contracts.test.ts`
  - `backend/test/architecture-r12b-planning-public-contracts.test.ts`
- Create Task 4 SDD report/review artifacts

`backend/src/marketplace/quote-notifications.ts` currently re-exports
`PROVIDER_PORTAL_ROUTE` from the legacy policy path. Remove exactly that
re-export while changing its own import to the new owner-public path; no current
consumer imports the constant through this file. This deletion is required by
the no-re-export proof and does not authorize any other export-surface change.

**Forbidden surfaces:** policy constants, messages, conditions, or the moved
policy's exact export set; any export-surface change other than deletion of the
single legacy `quote-notifications.ts` re-export stated above; provider data
access; notification/conversation logic; new shared-kernel policy; new
exception/allowlist; baseline deletion; ownership files; packages; R16.

**Interfaces:** exact exports remain `PROVIDER_NOT_ACTIVE`,
`PROVIDER_PROFILE_READ_ONLY`, `PROVIDER_PORTAL_ROUTE`,
`ProviderAccessCapabilities`, `ProviderAccessMode`, `ProviderAccessPolicy`,
`isProviderOperational`, `providerAccessPolicy`,
`assertProviderOperational`, `assertProviderProfileWritable`.

- [ ] **Step 1: Preregister the exact move, seven consumers, and three exception sites**

Bind immutable source parity and reject unlisted consumers, alternate public
paths, near-miss exceptions, or any policy content change.

- [ ] **Step 2: Add RED tests for public path and exception retirement**

Tests must require legacy/public paths `0/1`, seven exact production consumer
rewrites, IDs 19/20 absent, an exact empty ledger, and absence of the exception
from dependency-cruiser/ports/R3. Negative cases must reject policy copies,
re-exports, wildcard allowances, renamed/nested paths, duplicate consumers,
content drift, and non-plain files.

- [ ] **Step 3: Move the policy and rewrite all seven consumers**

The target bytes are identical apart from line-ending normalization already
accounted for by the manifest. Do not change policy behavior. The Identity
consumer now uses a legal Marketplace public import, eliminating the
non-baseline exception assigned by R12A to R12C.

- [ ] **Step 4: Retire only the exact exception and two records**

Remove the exact provider-access-policy exception from the three live
authorities. Historical no-R12C fixtures retain the old assertion through the
R12C successor projector. Write the baseline as exact canonical `[]` plus its
normal newline; do not delete it yet. Set stage `zero-proven`.

- [ ] **Step 5: Prove direct unignored zero before deletion**

```powershell
cd backend
npx depcruise --config .dependency-cruiser.cjs src
node -e "const x=require('./.dependency-cruiser-known-violations.json'); if (!Array.isArray(x)||x.length!==0) process.exit(1)"
```

Expected: unignored dependency scan PASS, ledger length 0. No ignore/baseline
argument may appear in the first command.

- [ ] **Step 6: Prove focused behavior and architecture GREEN**

```powershell
cd backend
node --test -r ts-node/register `
  test/architecture-r12c-zero-cross-context-dependencies.test.ts `
  test/architecture-dependencies.test.ts `
  test/architecture-ports.test.ts `
  test/architecture-r3-contexts.test.ts `
  test/architecture-r12a-backoffice-catalog-public-contracts.test.ts `
  test/architecture-r12b-planning-public-contracts.test.ts `
  test/provider-status-access.test.ts `
  test/provider-notification-visibility.test.ts `
  test/notification-mutation-atomicity.test.ts `
  test/provider-chat-logic.test.ts
npm run architecture:ports
npm run architecture:r3
npm run architecture:r12a
npm run architecture:r12b
npm run architecture:r12c
npm run architecture:ownership
npm run check
```

Expected: zero-proven, original IDs all absent, exceptions 0, ownership exact,
and the combined test run reports fail/skip/todo `0`.

- [ ] **Step 7: Independent Task 4 review**

Reviewer must inspect provider authorization/error parity, notification
visibility and legacy route behavior, exact seven consumers, Identity exception
retirement, empty-ledger provenance, and unignored zero. Exit 0/0/0.

**Rollback point:** restore policy/consumers, exact three exceptions, two-row
ledger, and `messaging-lifecycle-public` manifest together.

**Completion evidence:** RED/GREEN, public/legacy 1/0, consumers 7, exceptions
0, exact empty ledger, unignored scan zero, ownership unchanged, review 0/0/0.

---

### Task 5: Delete The Dependency Baseline And Activate Strict Cumulative Zero

**Objective:** After zero is independently proven, delete the dependency debt
ledger, make the canonical import command unbaselined, and keep all historical
R3-R12B authorities valid through an exact R12C successor projection.

**Exact dependencies closed:** none; all nine were closed in Tasks 2-4.

**Files:**

- Delete: `backend/.dependency-cruiser-known-violations.json`
- Modify command only: `backend/package.json`
- Modify exact successor projections as proven necessary:
  - `backend/scripts/architecture/r3-context-scan.cjs`
  - `backend/scripts/architecture/r5-identity-scan.cjs`
  - `backend/scripts/architecture/r6-sharing-otp-transport-scan.cjs`
  - `backend/scripts/architecture/r7-collaboration-relocation-scan.cjs`
  - `backend/scripts/architecture/r8-global-module-removal-scan.cjs`
  - `backend/scripts/architecture/r12a-backoffice-catalog-public-contracts-scan.cjs`
  - `backend/scripts/architecture/r12b-planning-public-contracts-scan.cjs`
  - `backend/scripts/security/prisma-config-merge-security.cjs`
- Modify their exact existing tests only:
  - `backend/test/architecture-r3-contexts.test.ts`
  - `backend/test/architecture-r5-identity-relocation.test.ts`
  - `backend/test/architecture-r6-sharing-otp-transport.test.ts`
  - `backend/test/architecture-r7-collaboration-relocation.test.ts`
  - `backend/test/architecture-r8-global-module-removal.test.ts`
  - `backend/test/architecture-r12a-backoffice-catalog-public-contracts.test.ts`
  - `backend/test/architecture-r12b-planning-public-contracts.test.ts`
  - `backend/test/architecture-r3-scope.test.ts`
  - `backend/test/prisma-config-merge-security.test.ts`
- Modify R12C manifest/scanner/test
- Create Task 5 SDD report/review artifacts

Do not edit a listed historical scanner/test unless its fresh RED proves it
actually requires the successor projection. If another file is required, stop
for scope approval.

**Forbidden surfaces:** dependency-cruiser rules except Task 4's completed
exception removal, Product Logic, ownership files, package lock/dependencies,
schema/migrations, future baselines, R13.

- [ ] **Step 1: Record the independently approved zero-proven state**

Re-run Task 4's direct unignored dependency command and hash the empty ledger.
If it is not exact zero, stop; do not delete.

- [ ] **Step 2: Add RED absence/successor tests before deleting**

Tests must expect:

- dependency baseline absent only at `strict`;
- `architecture:imports` exactly
  `depcruise --config .dependency-cruiser.cjs src`;
- aggregate ends once with `architecture:r12c`;
- every historical live scanner accepts the exact R12C successor zero;
- historical fixtures without R12C still require and validate their original
  baselines;
- renamed/empty alternate baselines, ignore flags, new exceptions, and forged
  successor projections fail.

Expected RED: live baseline still exists and package import command still
contains `--ignore-known`.

- [ ] **Step 3: Delete the ledger and make the import gate strict**

Delete only the known-violations file. Change `architecture:imports` to the
exact unignored command. Keep `architecture:imports:baseline` only as a manual
generator if current security policy permits; it must not be invoked by any
gate and must not recreate a live allowance. Record the design decision in the
Task 5 report.

- [ ] **Step 4: Add the smallest stage-neutral successor projection**

Use the R12C manifest's immutable nine-record entry and retirement set as the
sole source of truth. Historical authorities must project the strict working
tree back through R12C -> activated R12B -> R12A/R7/R6/R5/R3. Do not change
historical expected counts or replace missing-baseline proof with shallow
existence assertions.

- [ ] **Step 5: Run complete cumulative architecture GREEN**

```powershell
cd backend
npm run architecture:imports
npm run architecture:ownership
npm run architecture:ports
npm run architecture:r3
npm run architecture:r4
npm run architecture:r5
npm run architecture:r6
npm run architecture:r7
npm run architecture:r8
npm run architecture:r12a
npm run architecture:r12b
npm run architecture:r12c
npm run architecture
npm run security:prisma-config-merge
npm run check
npm run build
```

Expected: baseline absent; dependency 0; ownership 385/781; cycles,
`forwardRef()`, globals, illegal imports 0; all commands exit 0.

- [ ] **Step 6: Run all changed architecture test files together**

Use one `node --test -r ts-node/register` invocation listing every modified
architecture/security test. Record tests/pass/fail/skip/todo; expected fail,
skip, todo 0.

- [ ] **Step 7: Independent Task 5 review**

Reviewer must prove zero without ignore/baseline, nine named closures, exact
historical reconstruction, no weakened count, package/security command parity,
ownership hash, and protected scope. Exit 0/0/0.

**Rollback point:** restore the reviewed empty ledger, previous baselined import
command, pre-strict scanner/test files, and `zero-proven` manifest together.

**Completion evidence:** deletion proof, canonical command, aggregate gates,
historical/no-successor fixtures, named-ID closure, review 0/0/0.

---

### Task 6: Run The Full R12C Verification Gate

**Objective:** Re-prove behavior, architecture, build, security, audit, smoke,
scope, and protected surfaces from Step 1 after all five implementation tasks
are independently approved.

**Exact dependencies closed:** verifies all `10,12-17,19-20`; changes none.

**Files:**

- Read only: repository production/tests/scripts/configuration
- Create: Task 6 report, review package, independent review under the R12C SDD
  directory
- Modify an approved Task 1-5 file only if a gate proves a root-cause R12C
  implementation defect. Otherwise stop and request a separate remediation.

**Forbidden surfaces:** new refactor, new contract, test weakening, Product
Logic, ownership work, package change, R13, docs closeout before approval.

- [ ] **Step 1: Run the complete focused behavior and architecture suite**

At minimum include:

```powershell
cd backend
node --test -r ts-node/register `
  test/architecture-r12c-zero-cross-context-dependencies.test.ts `
  test/financial-integrity.test.ts `
  test/quote-provider-notifications.test.ts `
  test/quote-stability.test.ts `
  test/marketplace-my-quote-authorization.test.ts `
  test/provider-dashboard-mutation-atomicity.test.ts `
  test/provider-status-access.test.ts `
  test/provider-notification-visibility.test.ts `
  test/notification-mutation-atomicity.test.ts `
  test/provider-chat-logic.test.ts `
  test/conversation-pagination.test.ts `
  test/outbox-logic.test.ts `
  test/account-deletion.test.ts
```

Expected: exit 0, fail/skip/todo 0.

- [ ] **Step 2: Run architecture, TypeScript, build, and Prisma security**

```powershell
npm run architecture
npm run check
npm run build
npm run security:prisma-config-merge
```

Expected: dependency 0 without baseline; ownership 385/781; forwardRef,
project globals, illegal imports, cycles 0; all exit 0.

- [ ] **Step 3: Run both dependency audits**

```powershell
npm audit --audit-level=high
npm audit --omit=dev --audit-level=high
```

Expected: vulnerabilities 0 in both; no package or lock mutation.

- [ ] **Step 4: Run the full Backend test suite**

```powershell
npm test
```

Expected: exit 0, failures 0, no new skipped/disabled/todo test. Record the
exact current total rather than copying R12B numbers.

- [ ] **Step 5: Run affected managed smokes serially**

```powershell
npm run smoke:money-apis
npm run smoke:marketplace
npm run smoke:providers-quotes
npm run smoke:provider-dashboard
npm run smoke:conversation-unification
npm run smoke:notifications
npm run smoke:notifications-apis
npm run smoke:phase2-marketplace-write-concurrency
npm run smoke:phase2-provider-dashboard-concurrency
npm run smoke:phase2-quote-concurrency
npm run smoke:phase2-conversation-revocation
npm run smoke:phase2-notification-authorization-concurrency
npm run smoke:phase2-notification-preferences
npm run smoke:account-deletion
```

Expected: every package PASS; preserve exact transaction, money, provider,
conversation, notification, revocation, and deletion behavior.

- [ ] **Step 6: Run all managed smokes**

```powershell
npm run smoke:all
```

Expected: every managed package PASS. Record exact package totals.

- [ ] **Step 7: Prove exact exit state and protected surfaces**

The report must contain:

```text
dependency entry=9 retiredIds=10,12,13,14,15,16,17,19,20 live=0
dependency baselineExists=false ignoreKnownInLiveGate=false
dependency added=0 unexpectedRemoved=0
ownership entry=385/781 live=385/781 rawHashUnchanged=true
finance legacy/public=0/1 consumers=3
messaging directImports=0 publicPort=1 implementationProviders=1
marketplacePolicy legacy/public=0/1 consumers=7 historicalExceptions=0
forwardRef=0 projectGlobals=0 illegalFutureImports=0 cycles=0 staged=0
```

Use `git diff --cached --name-only`, `git diff --name-only`, and
`git ls-files --others --exclude-standard`. Compare exact allowed paths; do not
infer from directory summaries. Confirm no Mobile/Admin/Prisma
schema/migration/dependency/lock/deployment changes.

- [ ] **Step 8: Independent Task 6 full-gate review**

Reviewer reruns the strict scanner, named-ID proof, representative focused
tests, ownership/protected checks, audits, and samples affected smokes. Any
finding restarts Task 6 from Step 1 after an in-scope correction. Exit 0/0/0.

**Rollback point:** verification makes no production change. On failure return
to the last approved implementation task; never advance to Task 7.

**Completion evidence:** every command/exit/total, warnings and skips disclosed,
dependency/ownership exact, protected scope, reviewer 0/0/0.

---

### Task 7: Close And Document R12C Locally

**Objective:** Update only the active architecture/project truth and produce a
final local R12C report after Task 6 is independently approved.

**Exact dependencies closed:** documents the nine already closed; changes none.

**Files:**

- Modify only the active Markdown files whose current R12B statements become
  stale, expected to be:
  - `ARCHITECTURE.md`
  - `CHANGELOG.md`
  - `docs/README.md`
  - `docs/project/STATUS.md`
  - `docs/project/DECISIONS.md`
  - `docs/project/EXECUTION_PLAN.md`
- Modify generated catalog only through `node scripts/docs-sync.mjs`:
  - `docs/SCRIPTS.md`
- Create:
  `docs/superpowers/reports/2026-09-08-modular-monolith-r12c-zero-cross-context-dependencies-report.md`
- Modify R12C manifest documentation fingerprints only as required by the
  approved documentation state
- Create Task 7 report/review package/final review in the R12C SDD directory

Register `docs/SCRIPTS.md` in the R12C documentation candidate fingerprint
set. If docs-sync proves any other generated Markdown file must change, stop and
add it only after explicit scope review. Do not edit Product scope/logic claims.

**Forbidden surfaces:** all source/tests/config/baselines/packages, R13,
architecture-target-complete wording, Git/external actions.

- [ ] **Step 1: Render a verified documentation candidate**

State truthfully:

- R12C local dependency boundary is complete at zero;
- the dependency baseline is absent;
- ownership remains 385/781 and R13-R18 remain;
- R12C is not the final modular-monolith target;
- no Product/API/Mobile/Admin/deployment/release behavior changed;
- no Git integration or external action occurred.

After the package commands have their final approved Task 5 bytes, run
`node scripts/docs-sync.mjs` exactly once. Accept only the expected
`docs/SCRIPTS.md` generated delta. Verify the catalog contains the exact new
`architecture:r12c` row and the final strict `architecture:imports` command
without `--ignore-known`; reject hand edits or any other generated-doc delta.

- [ ] **Step 2: Run docs and exact-scope gates**

```powershell
node scripts/docs-sync.mjs --check
node scripts/docs-verify.mjs
git diff --check
git diff --cached --name-only
```

Expected: docs drift/errors/warnings 0; diff check exit 0; staged 0.

- [ ] **Step 3: Re-run strict architecture after docs only**

```powershell
npm --prefix backend run architecture:r12c
npm --prefix backend run architecture
npm --prefix backend run check
```

Expected: dependency 0, ownership 385/781, all zero guards unchanged.

- [ ] **Step 4: Independent final documentation and closure review**

Reviewer compares the nine original IDs, three contract families, all task
reviews, exact gates, docs wording, scope, identity, and no-Git/no-deploy state.
Required separate verdicts:

```text
Design consistency: Critical 0 / Important 0 / Minor 0
Implementation evidence: Critical 0 / Important 0 / Minor 0
Documentation truth: Critical 0 / Important 0 / Minor 0
Overall R12C: APPROVED
```

- [ ] **Step 5: Record local closure and stop**

Only after Step 4, set R12C `CLOSED` in the local final report/progress ledger.
Stop. Do not start R13, commit, push, merge, deploy, or mutate production.

**Rollback point:** restore the pre-Task-7 Markdown candidate and manifest doc
fingerprints; Tasks 1-6 remain approved but R12C stays not closed.

**Completion evidence:** final report, docs 0/0, exact scope, final review 0/0/0,
R12C CLOSED, exact next milestone `R13 design/planning only after separate owner
approval`.

## Execution Handoff

This plan is complete only as a planning artifact. Do not execute Task 1 in the
same design/planning session. A future owner-authorized implementation session
must use `superpowers:subagent-driven-development` or
`superpowers:executing-plans`, begin at Task 1 Step 1, and stop at every review
gate. No Git integration step is part of this plan.
