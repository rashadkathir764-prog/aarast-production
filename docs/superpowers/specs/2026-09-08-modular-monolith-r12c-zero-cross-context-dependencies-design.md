# Modular Monolith R12C Zero Cross-Context Dependencies Design

**Date:** 2026-09-08  
**Status:** APPROVED — independent review 0 Critical / 0 Important / 0 Minor  
**Phase boundary:** DESIGN AND PLANNING ONLY; SOURCE IMPLEMENTATION NOT STARTED  
**Immutable base commit:** `4d0d3ee91fb32d0432aa3bd69fe018d9a5a323b1`  
**Entry provenance (recorded, not a constraint — see section 18):** captured in
`D:/projects/aarast-modular-monolith` on branch `modular-monolith`  
**Amended:** 2026-09-13 — section 18, governance portability

## 1. Decision Summary

R12C will retire the exact nine dependency records left by R12B. It will not
retire, reclassify, regenerate, or conceal any physical-ownership record. The
recommended architecture is deliberately hybrid because the three dependency
families have different semantics:

1. relocate the existing Finance wedding-cost response projection into the
   Finance owner-public slice, without changing its exports or behavior;
2. replace five direct Marketplace-to-Messaging lifecycle imports with one
   synchronous transaction-bound Messaging application port; and
3. relocate the existing pure provider-access policy into the Marketplace
   owner-public slice and retire the exact historical Identity exception that
   R12A assigned to R12C.

The stage projection is exact:

| Stage | Closed original IDs | Live dependency records | Ownership |
| --- | --- | ---: | ---: |
| `design` | none | 9 | 385 / 781 |
| `finance-public` | 10, 13 | 7 | 385 / 781 |
| `messaging-lifecycle-public` | 10, 12-17 | 2 | 385 / 781 |
| `zero-proven` | 10, 12-17, 19-20 | 0 in an exact empty ledger; direct unignored scan passes | 385 / 781 |
| `strict` | 10, 12-17, 19-20 | 0; dependency baseline absent | 385 / 781 |

The physical-ownership baseline remains byte-identical throughout R12C. The
Finance and Marketplace files selected for owner-public relocation have zero
ownership-baseline records. The Messaging lifecycle implementation remains at
its existing Messaging-owned path, so its four current ownership records do
not move. R13-R17 retain exclusive authority over ownership retirement.

## 2. Authority And Reconstructed Current State

The binding predecessor chain is R11 -> R12A -> R12B:

- R11 numbered all 22 original dependency records and assigned IDs
  `10, 12-17, 19-20` to R12C.
- R12A retired IDs `1-6`, established five owner-public contracts, and retained
  the provider-access-policy exception explicitly for R12C.
- R12B retired IDs `7-9`, `11`, `18`, and `21-22`; its activated manifest has
  four receipts and leaves exactly nine records.

The live evidence at R12C design entry is:

| Evidence | Value |
| --- | --- |
| R12B state | `CLOSED` |
| R12B documentation | `activated`, receipts `4` |
| dependency baseline | 9 records; SHA-256 `fe4d3bfe23cf0400266bbfea8bd0357d578b93cad005c77af0814ec52ccfcb53` |
| ownership baseline | 385 records / 781 occurrences; SHA-256 `5f42f33300a9727f587e62327c5261a88a6ce5928437241c9e7c20f726906496` |
| `npm run architecture:imports` | PASS; 350 modules, 1,410 edges, 9 known records, no new violation |
| `npm run architecture:ownership` | PASS; 385 current records |
| `npm run architecture:r12b` | PASS; dependency 9, activated/4, ownership 385/781 |
| forward references | 0 |
| project-owned globals | 0 |
| illegal future imports | 0 |
| cycles | 0 |
| staged paths | 0 |
| R12C implementation | NOT STARTED |

The number nine remains because R12A and R12B subtracted only their immutable
ID sets. It is not a rounded baseline count: every remaining row is still an
actual runtime import in source, and every row is reproduced below.

## 3. Exact Nine-Dependency Inventory

All nine are runtime ES imports (`local`, `import`); none is type-only. Line
numbers refer to the R12C design-entry working tree.

| ID | SOURCE_CONTEXT | SOURCE_FILE / SYMBOL | TARGET_CONTEXT | TARGET_FILE / SYMBOL | DEPENDENCY_TYPE | IMPORT_DIRECTION | RUNTIME_OR_TYPE_ONLY | WHY_IT_EXISTS | CURRENT_CALL_FLOW | OWNERSHIP_OF_DATA | PUBLIC_CONTRACT_EXISTS? | PUBLIC_CONTRACT_USABLE? | REQUIRED_BEHAVIOR | RISK | CANDIDATE_RESOLUTION |
| ---: | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 10 | Marketplace | `backend/src/marketplace/marketplace.service.ts:34,576-625`; `MarketplaceService.acceptQuoteOffer` | Finance | `backend/src/wedding-costs/wedding-cost.presenter.ts:47-71`; `toWeddingCostResponse` | response projection | Marketplace -> Finance deep | runtime | Accepted-offer response must use the canonical money response shape | controller `marketplace.controller.ts:264` -> `MarketplaceService.acceptQuoteOffer` -> `acceptQuoteOfferInTransaction` -> `toWeddingCostResponse` at line 613 | Finance owns WeddingCost; Marketplace already holds the returned payload | no Finance owner-public presentation contract | no | identical strings, Decimal subtraction, counts, dates, nullable provider, and HTTP response shape | High: money response drift | Move the exact projection into Finance `public/`; rewrite owner and consumer imports; no duplicate or facade |
| 12 | Marketplace | `backend/src/marketplace/quote-offer-acceptance.ts:21,327-347`; `acceptQuoteOfferInTransaction` | Messaging | `backend/src/conversations/conversation-lifecycle.ts:109-150`; `recordConversationEvent` | transaction-bound command | Marketplace -> Messaging deep | runtime | Quote acceptance records rejected sibling offers and the accepted offer atomically | controller -> `MarketplaceService.acceptQuoteOffer` -> serializable acceptance transaction -> lifecycle event create/dedupe -> conversation activity update -> outbox create | Messaging owns ConversationEvent/Conversation; Platform owns OutboxEvent; Marketplace owns QuoteOffer/QuoteRequest | `MESSAGING_REALTIME_PORT` exists but has different post-commit delivery semantics | no | same caller transaction, event order, dedupe keys, occurrence time, outbox atomicity, and retry behavior | Critical: split transaction or duplicate event | New Messaging lifecycle application port; injected once and passed the exact caller transaction |
| 13 | Marketplace | `backend/src/marketplace/quote-offer-acceptance.ts:26,133,272,297`; `acceptQuoteOfferInTransaction` | Finance | `backend/src/wedding-costs/wedding-cost.presenter.ts:3-22`; `weddingCostResponseInclude` | read/write result projection | Marketplace -> Finance deep | runtime | Quote acceptance needs the canonical Finance include to read/create one cost and return the exact projection | controller -> acceptance transaction -> locked quote -> cost read/create with include -> ID 10 presenter | Finance owns BudgetCategory/WeddingCost; the existing Marketplace direct Finance write remains explicit ownership debt for R13 | no Finance owner-public projection contract | no | exact Prisma include, active-payment count predicate, schedule count, idempotent cost reuse | Critical: cost/idempotency or money-count drift | Expose the existing exact include and response mapper together as one bounded Finance public projection; do not move the write in R12C |
| 14 | Marketplace | `backend/src/marketplace/quote-offer-rejection.ts:15,36-173`; `rejectQuoteOfferInTransaction` | Messaging | `backend/src/conversations/conversation-lifecycle.ts:109-150`; `recordConversationEvent` | transaction-bound command | Marketplace -> Messaging deep | runtime | Rejection records both offer and request lifecycle events in the quote transaction | controller `marketplace.controller.ts:272` -> service -> serializable rejection -> two deduplicated Messaging events | Messaging owns event/conversation; Marketplace owns quote state | no lifecycle command port; realtime port is not usable | no | event order, two keys, status payloads, no event on failed transition | Critical: partial rejection or duplicate history | Reuse the same new Messaging lifecycle application port as ID 12 |
| 15 | Marketplace | `backend/src/marketplace/quote-request-cancellation.ts:18,43-190`; `cancelQuoteRequestInTransaction` | Messaging | `backend/src/conversations/conversation-lifecycle.ts:109-150`; `recordConversationEvent` | transaction-bound command | Marketplace -> Messaging deep | runtime | Cancellation records the durable conversation event before commit | controller -> service -> serializable cancellation -> event/outbox on same transaction | Messaging owns event/conversation; Marketplace owns request | no lifecycle command port | no | authorization and lock order unchanged; exact cancellation key/type/status | Critical: unauthorized or non-atomic cancellation | Reuse the new Messaging lifecycle application port |
| 16 | Marketplace | `backend/src/marketplace/quote-request-creation.ts:17-20,50-206`; `createQuoteRequestInTransaction` | Messaging | `backend/src/conversations/conversation-lifecycle.ts:27-95,109-150`; `ensureConversationContext`, `recordConversationEvent` | transaction-bound commands | Marketplace -> Messaging deep | runtime | A quote request requires one canonical plan/account conversation, participants, first event, and outbox in one transaction | controller `marketplace.controller.ts:102-107,202-207` -> service -> serializable create -> conversation upsert/participants -> quote create -> lifecycle event | Messaging owns Conversation/Participant/Event; Marketplace owns QuoteRequest; Planning/Marketplace reads inside lifecycle remain visible ownership debt | no lifecycle command port | no | unique conversation reuse, participant idempotency, lock order, quote/event atomicity, dedupe | Critical: duplicate conversation or orphan quote/event | Lifecycle port exposes both exact commands over the same transaction client |
| 17 | Marketplace (`provider-dashboard` root) | `backend/src/provider-dashboard/provider-dashboard.service.ts:37,786-872,875-975`; `updateQuoteRequestStatus`, `createQuoteOffer` | Messaging | `backend/src/conversations/conversation-lifecycle.ts:109-150`; `recordConversationEvent` | transaction-bound command | Marketplace -> Messaging deep | runtime | Provider rejection and offer creation append conversation lifecycle events atomically | provider controller `:193-211` -> dashboard service serializable transaction -> quote transition/create -> event/outbox | Messaging owns event/conversation; Marketplace owns provider/quote | no lifecycle command port | no | provider authorization, quote transition, event keys, notifications, and same commit boundary | Critical: provider mutation/event divergence | Inject and reuse the same Messaging lifecycle port in ProviderDashboardService |
| 19 | Messaging | `backend/src/conversations/conversations.service.ts:29-32,895-923,1006-1047,1167-1246`; `assertActiveAccessInTransaction`, `assertConversationSendable`, `accessFor`, `toConversationResponse` | Marketplace | `backend/src/provider-dashboard/provider-access-policy.ts:21-57`; `isProviderOperational`, `assertProviderOperational` | pure owner policy | Messaging -> Marketplace deep | runtime | Messaging must fail closed for provider actions and report truthful `canSend` | conversation HTTP/WebSocket entry -> ConversationsService authorization/send/read projection -> provider-status policy | Marketplace owns Provider lifecycle/status; Messaging already reads Provider as ownership debt assigned to R16 | no Marketplace owner-public access-policy contract | no | ACTIVE-only operations, exact forbidden error/code, history readability, truthful `canSend` | High: authorization/privacy regression | Move exact pure policy to Marketplace `public/`; keep it synchronous and owner-controlled |
| 20 | Notifications | `backend/src/notifications/notifications.service.ts:28-32,1944-2099`; provider visibility helpers | Marketplace | `backend/src/provider-dashboard/provider-access-policy.ts:4-57`; `PROVIDER_PORTAL_ROUTE`, `isProviderOperational`, `assertProviderOperational` | pure owner policy/value | Notifications -> Marketplace deep | runtime | Notification list/mutation visibility must hide provider-only content while inactive, including legacy route cases | notifications controller/scheduler -> visibility/mutation helpers -> provider-status policy and exact route literal | Marketplace owns Provider lifecycle; Notifications owns notification data; cross-model reads remain R16 ownership debt | no Marketplace owner-public access-policy contract | no | pagination-before-visibility, fail-closed direct mutation, legacy route handling, ACTIVE reappearance | Critical: notification content exposure | Reuse the same moved Marketplace public policy as ID 19 |

The immutable R11 IDs remain the identifiers above even though the live
nine-row JSON has no `id` member. R12C governance must reconstruct the rows from
the R11/R12A/R12B chain and delete them by exact semantic identity, never by
array position alone.

## 4. Root-Cause Classification

Each dependency has one primary classification:

| ID | Classification | Reason |
| ---: | --- | --- |
| 10 | A. Missing public contract | Finance owns the canonical response projection, but it is only reachable through a legacy deep file |
| 12 | E. Cross-context command that should use explicit application contract | Messaging event writes must join the caller transaction through an owner contract |
| 13 | D. Cross-context read that should use projection/query contract | Marketplace imports Finance's exact Prisma result projection; the write ownership itself is explicitly deferred to R13 |
| 14 | E. Cross-context command that should use explicit application contract | Two Messaging lifecycle events are part of one Marketplace transaction |
| 15 | E. Cross-context command that should use explicit application contract | Cancellation must append its Messaging event atomically |
| 16 | E. Cross-context command that should use explicit application contract | Conversation ensure plus first event are synchronous transaction-bound commands |
| 17 | E. Cross-context command that should use explicit application contract | Provider quote transitions and Messaging events must not split |
| 19 | A. Missing public contract | A Marketplace-owned pure lifecycle policy is consumed through a deep legacy path |
| 20 | A. Missing public contract | Notifications needs the same Marketplace-owned policy and route value through a public path |

None is classified G because R12C can remove each import edge correctly
without moving model ownership. The already-visible ownership leaks in the same
files remain G-class debt for R13/R16, but they are not any of these nine import
records and must not be changed to make R12C pass.

## 5. Domain-Boundary Validation

| Dependency family | True behavior owner | Data owner | Caller need | Existing usable contract? | Sync/event decision | Shared-kernel decision |
| --- | --- | --- | --- | --- | --- | --- |
| IDs 10/13, wedding-cost presentation | Finance | Finance owns WeddingCost/BudgetCategory | synchronous projection of an already transaction-bound Finance-shaped result | no | remain synchronous; an event cannot produce the required HTTP response or query include | rejected: money presentation and payment-count semantics are Finance policy, not universal values |
| IDs 12,14-17, conversation lifecycle | Messaging | Messaging owns Conversation, Participant, and Event; Platform owns Outbox | commands that execute inside the caller's existing transaction | realtime port is post-commit transport only and is not usable | explicit synchronous application port; event-only handoff would introduce unwanted eventual consistency and break quote/event atomicity | rejected: lifecycle persistence is Messaging behavior, not shared policy |
| IDs 19/20, provider access | Marketplace | Marketplace owns Provider status/lifecycle | a pure policy evaluation plus the canonical provider portal route | provider-rating public helper is unrelated | remain synchronous pure calls; no query or event is necessary because callers already hold status | rejected: Provider lifecycle is Marketplace-specific and would turn shared-kernel into a domain dumping ground |

### Transaction ownership clarification

The Messaging port accepts the exact transaction client supplied by the
Marketplace caller. It must not open another transaction, catch/translate an
owner error, enqueue after commit, or perform a second read outside the caller
transaction. The implementation remains owned by Messaging at
`backend/src/conversations/conversation-lifecycle.ts`; only its callable
surface becomes explicit.

### Finance ownership clarification

Publishing the exact wedding-cost projection does not authorize Marketplace's
existing direct BudgetCategory/WeddingCost read/write ownership. Those records
remain visible in the 385/781 ledger and belong to R13. R12C merely replaces a
legacy deep import with a bounded, owner-named projection contract. If the
projection cannot remain byte/behavior equivalent without moving the write,
R12C must stop rather than absorb R13.

## 6. R12A/R12B Public-Contract Audit

Six logical owner-public contracts were created by R12A/R12B. All are used;
none is a correct substitute for the nine remaining edges.

| Contract | Current source consumers | Used? | Solves an R12C edge? | Assessment |
| --- | ---: | --- | --- | --- |
| Backoffice `AdminGuard` | 3 | yes | no | complete for authentication guard consumption |
| Backoffice `RequireAdminPermission` | 3 | yes | no | complete for decorator consumption |
| Backoffice `AdminPermissionGuard` | 3 | yes | no | complete for authorization guard consumption |
| Backoffice admin mutation gate | 4 | yes | no | complete for R12A; its eventual R17 ownership/layout work remains explicit |
| Marketplace provider-review rating helper | 3 | yes | no | complete for R12A; R16 owns its final infrastructure shape |
| Planning wedding-location contract | 6 production + 1 behavioral test | yes | no | complete and appropriately pure |

Audit result:

- contracts used: `6/6`;
- unused contracts: `0`;
- existing R12A/R12B contracts usable for the nine: `0`;
- confirmed incomplete contracts: `0` for their approved scopes;
- confirmed over-designed contracts: `0`;
- new logical R12C contracts justified: `3`.

Earlier contracts were also checked for semantic reuse. In particular,
`MESSAGING_REALTIME_PORT` cannot be reused for transaction-bound persistence,
and Marketplace provider-rating cannot represent provider lifecycle access.
Reusing either would conflate behavior solely to reduce file count.

The new Messaging lifecycle port owns the canonical boundary types rather than
importing types from the legacy implementation. Its transaction type is the
exact `Pick<Prisma.TransactionClient, '$queryRaw' | 'conversation' |
'conversationEvent' | 'conversationParticipant' | 'outboxEvent' | 'provider' |
'weddingPlan'>`; its two inputs preserve the current fields; and its record
result is `{ event: ConversationEvent; created: boolean }`. The existing
`conversation-lifecycle.ts` implementation imports those public input/client/
result types with type-only imports while retaining the current algorithm and
runtime enum use. This makes the new public contract canonical without moving
the implementation or its ownership records.

## 7. Current And Target Dependency Graphs

### Current graph: nine illegal deep edges

```text
Marketplace
  --[10]--> Finance legacy wedding-cost presenter
  --[13]--> Finance legacy wedding-cost query projection
  --[12]--> Messaging legacy lifecycle (accept)
  --[14]--> Messaging legacy lifecycle (reject)
  --[15]--> Messaging legacy lifecycle (cancel)
  --[16]--> Messaging legacy lifecycle (create/ensure)
  --[17]--> Messaging legacy lifecycle (provider dashboard)

Messaging
  --[19]--> Marketplace legacy provider-access policy

Notifications
  --[20]--> Marketplace legacy provider-access policy
```

An additional historical Identity -> Marketplace provider-access-policy edge is
not one of the nine because it is covered by an exact temporary exception.
R12A explicitly assigns retirement of that exception to R12C.

### Target graph: zero illegal dependency records

```text
Marketplace
  --[public projection; closes 10,13]--> Finance.public.WeddingCostPresentation
  --[transaction command port; closes 12,14,15,16,17]
      --> Messaging.public.ConversationLifecyclePort

Messaging
  --[pure public policy; closes 19]--> Marketplace.public.ProviderAccessPolicy

Notifications
  --[pure public policy; closes 20]--> Marketplace.public.ProviderAccessPolicy

Identity
  --[same pure public policy; retires historical exception]
      --> Marketplace.public.ProviderAccessPolicy
```

Reciprocal Marketplace/Messaging consumption is legal only because the two
public slices do not import one another. The concrete module/import graph must
remain acyclic. A public-to-public runtime import in either contract is a hard
failure.

## 8. Approaches Considered

### Approach A - relocate all three implementations into public slices

Move the Finance presenter, Messaging lifecycle implementation, and
Marketplace policy directly under owner `public/` roots.

Benefits:

- smallest import rewrite;
- closely resembles the mechanical R12A move pattern;
- preserves function call sites.

Risks:

- exposes Messaging persistence implementation and transaction delegate shape
  as public implementation rather than an application contract;
- moves four Messaging ownership-ledger paths and creates avoidable baseline
  projection work;
- weakens the intended public token/type boundary.

Future impact: R16 would need to undo a knowingly leaky Messaging public
implementation. Rejected for the lifecycle family.

### Approach B - hybrid owner-public projection/policy plus lifecycle port

Relocate the two pure/synchronous owner surfaces, but use a transaction-bound
Messaging port backed by the existing private lifecycle implementation.

Benefits:

- preserves exact synchronous behavior and transaction atomicity;
- leaves ownership bytes and lifecycle implementation location unchanged;
- adds only three logical contracts, each justified by a distinct behavior;
- aligns with the existing Planning budget-write transaction-port precedent;
- keeps R13/R16 ownership work visible.

Risks:

- adds Messaging public/internal module wiring and constructor injection;
- requires careful single-provider identity and no-cycle proof;
- the Finance projection remains intentionally narrow and transitional until
  R13 moves Finance-owned writes.

Future impact: R13 can replace the Finance projection's infrastructure-facing
shape behind the same behavior boundary; R16 can complete Messaging and
Marketplace internals without reversing a public implementation leak.

### Approach C - use events/facades now or postpone ownership-dependent edges

Publish quote events asynchronously, copy presenters/policies into callers, or
leave ID 13 until Finance ownership migration.

Benefits:

- could reduce immediate module wiring;
- postponement avoids defining the Finance projection now.

Risks:

- events break the required transaction and response timing;
- copying or forwarding hides rather than removes coupling;
- leaving any ID fails R12C's exact zero target;
- pulling Finance/Marketplace ownership into R12C violates R13/R16 boundaries.

Rejected. If the bounded Finance projection proves impossible under tests,
R12C must be replanned rather than use this approach.

### Recommendation

Use Approach B. It is the least architecture that makes each boundary truthful
while preserving current behavior, transaction semantics, and the future
ownership program.

## 9. Exact R12C Scope

### In scope

- exact immutable inventory and retirement of IDs `10, 12-17, 19-20`;
- one Finance owner-public wedding-cost projection, preserving exact exports;
- one Messaging transaction-bound lifecycle port, internal binding, and exact
  consumer injection;
- one Marketplace owner-public provider-access policy;
- exact retirement of the provider-access-policy temporary exception from
  dependency-cruiser, ports, and R3 authorities;
- exact subtractive dependency stages `9 -> 7 -> 2 -> 0`;
- deletion of `.dependency-cruiser-known-violations.json` only after an
  unbaselined strict dependency scan proves zero;
- R12C successor manifest/scanner/tests and narrowly required historical guard
  projections;
- affected behavior, architecture, security, build, audit, smoke, scope, and
  independent-review gates;
- R12C documentation and local-only closeout.

### Out of scope

- Prisma ownership migration;
- reduction of ownership `385/781` as an exit criterion or incidental target;
- any edit to the ownership baseline or registry;
- moving Marketplace's current BudgetCategory/WeddingCost ownership work;
- moving Messaging's Provider/WeddingPlan/Outbox ownership work;
- moving Messaging/Notifications provider reads;
- schema or migration changes;
- Product Logic redesign;
- API, error, route, payload, DTO, Arabic-copy, authorization, or privacy change;
- UI, Mobile, Admin Web, booking, payment-processing, credit, or product work;
- shared-kernel expansion;
- unrelated refactoring;
- R13 or later work, including R18 ownership-baseline deletion;
- commit, push, merge, deploy, production mutation, provider delivery, or
  release work.

## 10. Invariants And Per-Task Proof

| Invariant | Required proof after every affected task |
| --- | --- |
| money correctness | canonical include and mapper parity; `financial-integrity`, `quote-provider-notifications`, and money/quote smokes |
| one accepted offer -> one cost | accepted-offer idempotency, replay, concurrent quote smoke, unchanged unique linkage |
| transaction atomicity | static same-`tx` contract assertion plus quote/provider mutation rollback tests and concurrency smokes |
| conversation identity/idempotency | exact plan/account upsert, participant `skipDuplicates`, event dedupe keys, conversation/quote tests |
| outbox durability | lifecycle port uses caller `tx`; `outbox-logic` and relevant smokes pass |
| authorization/privacy | provider status, quote authorization, provider notification visibility, and mutation-atomicity tests |
| context ownership | ownership baseline raw hash remains `5f42...0696`; count remains 385/781 |
| API compatibility | no controller/DTO edits unless import-only test fixture path; focused HTTP smokes and full tests |
| public-contract compatibility | exact export inventory, parameter/result types, error identity, no legacy re-export/facade |
| zero new dependency | identify each original ID absence plus unbaselined dependency-cruiser zero |
| zero cycles/forwardRef/globals | aggregate architecture reports cycles 0, `forwardRef()` 0, project globals 0 |
| historical authority | R12A/R12B entry reconstruction and no-successor fixtures remain green |

## 11. Test Strategy

### Task 1 governance

- RED: a new R12C architecture test fails because no R12C successor authority,
  exact nine-record manifest, or stage projector exists.
- GREEN: design stage recognizes exactly nine immutable records and ownership
  `385/781`, rejects reordered/added/removed/forged records, and preserves the
  activated R12B predecessor.
- Regression: R3/R5/R6/R7/R8/R12A/R12B historical fixtures remain valid.
- Architecture proof: R12C test names all nine IDs; total count alone is
  insufficient.

### Task 2 Finance projection

- RED: test expects one Finance public projection, exact two consumer rewrites,
  owner rewrite, legacy absence, and baseline IDs 10/13 removed; current source
  fails.
- GREEN: exact exports and source behavior match; dependency stage is 7.
- Regression: money response, accepted-offer idempotency/replay, financial
  integrity, quote/provider notifications.
- Architecture proof: both semantic dependency keys are absent, no copied
  mapper/include or legacy facade exists.

### Task 3 Messaging lifecycle port

- RED: test expects one public token/interface, one `useExisting` binding,
  exact five consumers through injected port, and no direct lifecycle import.
- GREEN: IDs 12,14-17 are absent and dependency stage is 2.
- Regression: quote stability, authorization, provider mutations,
  conversation lifecycle, notification/outbox, concurrency.
- Architecture proof: exact same transaction argument reaches both lifecycle
  methods; no nested transaction, second provider, direct import, or dual path.

### Task 4 Marketplace provider policy and strict zero

- RED: test expects exact owner-public policy, all seven live consumer imports,
  old path absence, exact three-place exception retirement, two record removal,
  and a direct unignored scan with the reviewed empty known-violations ledger
  still present.
- GREEN: IDs 19/20 absent, historical exception absent, dependency-cruiser runs
  without `--ignore-known`, baseline content is exact canonical `[]`, and the
  direct scan reports zero violations. Baseline deletion belongs only to Task 5.
- Regression: provider status/access, provider notification visibility,
  conversation sendability, Identity context presentation, ports/R3 guards.
- Architecture proof: no alternate/deep/legacy path, no re-export, no hidden
  dynamic `require`, no public-slice cycle.

### Task 5 baseline retirement

- RED: the cumulative architecture suite rejects an absent dependency baseline
  or still invokes dependency-cruiser with `--ignore-known`.
- GREEN: the already-proven empty ledger is deleted, the canonical import gate
  runs unignored, and every historical authority validates the R12C successor
  without weakening its own no-successor fixtures.
- Regression: R3/R5/R6/R7/R8/R12A/R12B and Prisma security projections.
- Architecture proof: the baseline path is absent and no ignore/alternate
  baseline is referenced by the live aggregate command.

### Tasks 6-7 full gate and closeout

- all focused suites pass with no skip;
- full Backend suite passes with no new skip;
- affected smokes and `smoke:all` pass;
- strict architecture proves every original ID absent and no baseline file;
- TypeScript, build, Prisma security, full/prod audits, docs, scope, staging,
  protected surfaces, and independent review pass.

## 12. Ordering, Batches, And Rollback Boundaries

| Batch / task | IDs | Independent? | Prerequisite | Affects another batch? | Rollback boundary | Verification boundary |
| --- | --- | --- | --- | --- | --- | --- |
| Task 1: successor governance | none | yes | closed R12B | authorizes every later staged projection | restore Task 1 planning/guard files to exact R12B entry | design-stage scanner, historical fixtures, review 0/0/0 |
| Task 2: Finance public projection | 10,13 | yes after Task 1 | governance GREEN | no code dependency on Tasks 3/4 | revert exact move/imports and restore 9-row baseline | dependency 7 + money/quote tests + review |
| Task 3: Messaging lifecycle port | 12,14,15,16,17 | yes after Task 1; executed after Task 2 for monotonic ledger | governance; Finance stage receipt | adds Marketplace module import but does not require policy move | revert port/module/injection atomically and restore 7-row baseline | dependency 2 + transaction/conversation tests + review |
| Task 4: Marketplace policy + zero proof | 19,20 plus exception | yes after Task 1 | prior two stage receipts | produces exact empty ledger but does not delete it | restore old policy/imports, exact exceptions, and 2-row baseline as one unit | direct unignored zero + provider/privacy tests + review |
| Task 5: baseline retirement and strict cumulative authority | none | only after zero proof | Task 4 review approved | deletes the dependency baseline and activates strict historical projections | restore the reviewed empty ledger and pre-strict package/guards as one unit | baseline absent + aggregate architecture + review |
| Task 6: full verification | none | no changes unless a proven in-scope defect | Tasks 1-5 reviews approved | gates closeout | return to last approved batch; never patch tests broadly | complete local gate matrix + review |
| Task 7: documentation/closure | none | after Task 6 | Task 6 0/0/0 | none | restore pre-closeout docs; source remains approved | docs/scope/final review 0/0/0 |

The three source batches share contracts within each family, but not across
families. Combining all nine into one task would erase rollback and review
boundaries and is forbidden.

## 13. Failure And Rollback Strategy

For every source batch:

1. capture exact entry hashes and the semantic dependency set before RED;
2. preregister only the approved candidate paths in the R12C manifest;
3. prove RED for the intended missing contract, not fixture drift;
4. publish one atomic batch;
5. run focused behavior and architecture gates;
6. independently review at Critical/Important/Minor `0/0/0` before advancing.

A partial contract migration is detected when any of these holds:

- old direct import and new public import coexist;
- old file and new file coexist;
- direct function call remains beside port injection;
- consumer count differs from the exact manifest;
- dependency count falls but one named ID remains, or an unlisted row vanished;
- the ownership hash changes;
- a public slice imports the reciprocal public slice;
- dependency-cruiser zero is achieved only with an ignore/baseline/exception.

No dual-path compatibility period is permitted at a batch boundary. A batch
either lands complete and reviewed or is rolled back to its exact prior stage.
Hidden dependencies are detected by dependency-cruiser without a baseline,
AST-resolved import/require scans, literal near-miss tests, legacy-path absence,
public export inventory, and full runtime behavior tests.

## 14. Risk Analysis

| Risk | Severity | Control |
| --- | --- | --- |
| Lifecycle port accidentally opens a nested transaction or writes after commit | Critical | interface accepts exact caller client; static same-object test; rollback/concurrency smokes |
| Finance projection changes Decimal/count semantics | Critical | immutable source parity plus accepted-offer/money tests |
| Policy move changes fail-closed authorization or exposes notifications | Critical | exact source/export parity and provider visibility/mutation tests |
| Final zero is cosmetic because ignore-known or exception remains | Critical | delete baseline; strict unignored depcruise; exact exception absence; named-ID proof |
| R12C absorbs Finance/Marketplace/Messaging ownership work | Important | ownership hash byte-identical; explicit R13/R16 handoffs; stop on any ownership delta |
| New Nest module creates duplicate provider or cycle | Important | `useExisting` singleton identity; provider graph/cycle tests; no `forwardRef()` |
| Historical R12A/R12B authority breaks on baseline deletion | Important | successor projection plus no-successor historical fixtures before strict stage |
| Public projection becomes a permanent infrastructure leak | Important | narrow export inventory and explicit R13 handoff; no additional Finance API in R12C |

## 15. Exit Criteria

R12C is complete only when all conditions are true:

1. dependency debt is exactly `0` under dependency-cruiser with no known-
   violations file and no ignore option;
2. original IDs `10, 12-17, 19-20` are each closed by semantic-key evidence;
3. no unlisted dependency record was removed and no new illegal dependency
   exists;
4. the exact provider-access-policy historical exception is absent from all
   three authorities and no wider allowance replaces it;
5. ownership baseline SHA-256 remains `5f42...0696` and totals remain 385/781;
6. cycles, `forwardRef()`, project globals, and illegal future imports are zero;
7. TypeScript and build pass;
8. all R12C architecture and historical guards pass;
9. relevant focused tests pass with no skip;
10. full required Backend tests pass with no new skip;
11. Prisma/security guards pass unchanged in meaning;
12. full and production-only npm audits report zero vulnerabilities;
13. all affected managed smokes and `smoke:all` pass;
14. docs-sync reports drift/errors 0 and docs-verify reports errors/warnings 0;
15. protected Mobile/Admin/Prisma schema/migration/package dependency/deployment
    surfaces have no R12C semantic change;
16. staging is zero and every changed path belongs to the approved manifest;
17. no Product Logic regression is observed;
18. independent implementation and final reviews each report Critical 0,
    Important 0, Minor 0.

No phase may claim success from total count alone. Each named dependency,
contract, consumer, exception, transaction boundary, and baseline-deletion
condition must be proven separately.

## 16. Relationship To R13-R18

- R13 remains responsible for Planning/Finance internal completion and the
  direct Finance model ownership now visible in Marketplace quote acceptance.
- R16 remains responsible for Marketplace, Messaging, and Notifications
  internal/model ownership, including direct Provider/Conversation relations
  and the final infrastructure shape of earlier public helpers.
- R17 remains responsible for Insights/Backoffice owner-port consumption.
- R18 still enters only at ownership 0/0 and deletes the ownership baseline.

R12C deletes only the dependency-cruiser known-violations baseline after strict
zero. It must not edit or delete the ownership baseline. Completing R12C means
dependency-boundary zero, not the final modular-monolith target.

## 17. Explicit Non-Goals And Stop Rules

Stop R12C and request a revised design if:

- any ID requires a model-ownership move to close correctly;
- the Finance projection cannot preserve behavior without moving its write;
- the Messaging port cannot preserve one transaction and existing lock order;
- a public contract would need a reciprocal public-slice import;
- ownership bytes change;
- a new exception, baseline, override, facade, duplicate implementation, or
  shared-kernel domain policy is proposed;
- an additional Product/API/schema/migration/Mobile/Admin/deployment surface is
  required;
- any batch review is not 0/0/0.

This document authorizes planning only. It does not authorize Task 1, source
implementation, Git integration, R13, deployment, or release work.

## 18. Governance Portability Amendment (2026-09-13)

This section amends the identity model of the whole R12A/R12B/R12C governance
chain. It is recorded here because R12A and R12B are closed phases whose
design documents are byte-bound by their successors' manifests; the clauses of
those documents that bind identity to an environment (R12A/R12B
"**Repository**"/"**Branch**" headers, R12B "Authority And Composite Entry"
items *Git root*, *Branch*, *HEAD*, R12B exit criterion 1 "root, branch, and
HEAD match the composite entry", and the R12B stop rule on "Git identity") are
superseded by this section. Their `repository.rootName`, `repository.branch`
and this manifest's `repository.root` fields remain in the manifests as the
recorded provenance of each design entry; no scanner compares them to the
environment any more.

### What was pinned, and why it was fragile

Until this amendment the scanners required, before reading any content:

- the absolute working-tree path `D:/projects/aarast-modular-monolith` (R12C)
  and the directory name `aarast-modular-monolith` (R12B);
- the branch name `modular-monolith` (R12B, R12C);
- `HEAD` equal to the base commit `4d0d3ee9…` (R12A, R12B, R12C), which forced
  the entire R11–R12C overlay to stay uncommitted forever;
- an empty index (R12C);
- `git status --porcelain` equal to the manifest's overlay inventory, which is
  the same requirement expressed through the working tree.

None of these facts is architecture. They could not hold in a linked worktree,
a differently named clone, a CI checkout, or any commit of the work — so the
gates were only ever executable on one machine, in one directory, in one
uncommitted state. That is not a verification environment; a law that cannot be
re-run elsewhere cannot be independently verified. Worse, seven fingerprinted
scanners (`ports-scan`, `r3-context-scan`, `r5`–`r8`, `prisma-config-merge-security`)
had been registered with mixed CRLF/LF bytes that Git normalizes on commit,
so even a checkout at the exact commit could not reproduce the registered
bytes.

### What replaces it

Identity is now repository and content identity, implemented once in
`backend/scripts/architecture/repository-identity.cjs` and used by the R12A,
R12B and R12C scanners:

1. the given root must be the Git top level it discovers (`rev-parse
   --show-toplevel`, `--absolute-git-dir`), never a parent or nested
   directory, never a reparse point;
2. the phase's immutable base commit must exist and be an ancestor of, or
   equal to, `HEAD` (`merge-base --is-ancestor`): the current state must be a
   genuine extension of the entry;
3. the overlay is measured against the base commit (`git diff --no-renames
   --name-status <base>` plus `ls-files --others --exclude-standard`) with the
   manifests' unchanged vocabulary — `' M'` modified, `' D'` deleted, `'??'`
   added — so a committed and an uncommitted extension of the base project
   identically;
4. every governed byte is still bound by its registered fingerprint, every
   predecessor is still reconstructed byte-for-byte, and the exact overlay
   inventory is still enforced.

The historical replay of the R12B closure scanner inside the R12C projection
executes every closure byte verbatim except the six-line environment preamble
of `scanR12bPlanningPublicContracts`, which is pinned by hash in
`R12B_CLOSURE_ENVIRONMENT_PREAMBLE` and replaced by the portable identity
check. The replay fails closed if that preamble is absent, duplicated, or
altered; no other closure byte is touched.

Canonical bytes: `.gitattributes` now declares `*.cjs`, `*.mjs`, `Dockerfile`,
`.dockerignore`, `.gitattributes`, `.gitignore` and `.gitleaksignore` as LF
text, and the seven mixed-ending scanners were normalized to LF. The strict
candidate registers each of them as a `line-ending-normalization` record: the
LF-only terminators of the historical entry and the Task 5 splices, from which
the exact historical bytes reconstruct and whose entry hash proves that nothing
beyond line endings and the registered splices changed.

### Strict-candidate scope extension

Task 5's registrable path set (`STRICT_CANDIDATE_PATHS`, enforced by the
scanner) is extended by exactly: `.gitattributes`,
`backend/scripts/architecture/ports-scan.cjs`,
`backend/scripts/architecture/repository-identity.cjs`,
`backend/scripts/architecture/r12c-strict-candidate.cjs` and
`backend/test/architecture-governance-portability.test.ts`. The strict layer
may also register `new-file` records; the predecessor projection treats them
as absent. Registration is performed by the tracked tool
`r12c-strict-candidate.cjs`, which derives the Task 5 entry bytes from the last
registered state by content hash and refreshes only the fingerprints that
depend on the registration.

### Guarantees retained

- unauthorized change of any governed file fails (raw fingerprints, inverse
  and candidate reconstruction, normalized-self manifest hash);
- a forged or broken manifest fails (immutable design authority hash,
  preregistered candidate hashes, path scope of the strict candidate);
- an added dependency violation fails (strict, unbaselined dependency-cruiser
  command projected through every historical authority);
- an unregistered change to a protected surface or an undeclared file fails
  (exact base-relative overlay inventory, R12B protected paths and security
  receipt);
- identical content on a history that does not extend the base commit fails.

`backend/test/architecture-governance-portability.test.ts` proves all of the
above by running the real gate commands inside a fresh, renamed clone on a
different branch, both with the work committed and with it uncommitted, after a
clean dependency install, and by probing each rejection.

### Task 5 decisions recorded on completion (2026-09-13)

- **Baseline generator retired.** `architecture:imports:baseline` is removed
  from `backend/package.json`. At strict zero there is no ledger to regenerate
  and the scanner rejects the ledger's existence, so the command could only
  produce a rejected artifact or invite `--ignore-known` back. The R12C strict
  projection and the Prisma security checker fail if a strict package carries
  it, and the security projection restores the historical command so the
  R5–R12B fingerprint chain still closes. Historical package fixtures in the
  security test restore it explicitly.
- **Stage record encoding.** The approved Task 3/4 records were re-encoded
  losslessly from one whole-span splice each (which carried every unchanged
  byte between the first and last edit twice, 1.7 MB) to the bounded
  multi-splice form Task 5 already used. Path, entry and candidate
  fingerprints, statuses and entry lengths are unchanged for all 48 records
  and every record still reconstructs its exact entry bytes; only the
  preregistered candidate hashes in the scanner were rebound. The manifest
  fell from 2.16 MB to 0.58 MB, inside the raised 8 MiB JSON authority bound
  without relying on it.
- **Historical fixtures projected.** The R12B generated-catalog mirrors build
  from the R12B-era `backend/package.json` reconstructed by the R12C
  predecessor projection, and no fixture probe targets a real repository file.

## 19. Closure Of The Byte-Lineage Regime (2026-09-13)

This section records why and how the R12A/R12B/R12C governance chain was
closed after Task 7, what the gates verify from the closure onwards, and what
remains provable about the lineage. It is recorded in the same change that
introduced the closure because it changes the governing law of three phases.

### Why the lineage regime could not remain the live law

Sections 5–8 bind every gate to a byte lineage: the strict candidate is the
exact overlay of the working tree over the immutable base commit, every
governed file (the scanners, their tests, the security checker, the design
documents, the package and lock files) is fingerprinted, and the predecessor
tree is reconstructed byte-for-byte before the invariants are checked. That
regime proved that each transformation was exactly the one designed. It is
also, by construction, a regime in which no governed byte can change without
re-registering the whole candidate: fixing a scanner defect, extending a test,
or correcting a sentence of a design document invalidates the lineage until
`r12c-strict-candidate.cjs` re-registers it, and a re-registration is a
mutable authority that can register anything. Kept as the live law it is not
a guarantee but a deferred obstacle: the next engineering change to any
governed file is either forbidden or laundered through a re-registration.
The mission rule that a problem may not be replaced by a deferred one applies
to the governance itself.

### The closure record

`backend/architecture/modular-monolith-closure.json` is a tracked record with
exactly these members: `schemaVersion` (1), `phase` (`R12C`), `closedOn`,
`baseCommit` (the immutable base `4d0d3ee9…`), `lineageCommit` (the commit at
which the complete lineage gates last passed verbatim, `4bae5c6d…`, the Task 7
closeout), `manifests` (the SHA-256 of the three frozen manifests
`r12a`/`r12b`/`r12c`), and `lineageGates` (the commands that constitute the
lineage proof). `backend/scripts/architecture/modular-monolith-closure.cjs`
reads it and fails closed on any deviation: a member added or removed, a
manifest whose bytes no longer match, a lineage commit that is not present,
that does not extend the base commit, or that `HEAD` does not extend. The
record is read by the R12A, R12B, R12C, R3 and R5 scanners; while it is
absent the gates run exactly as sections 5–8 specify, so a checkout of any
commit before the closure still replays its lineage.

### What the gates verify once closed

- **R12C** verifies the live invariants of Tasks 2–5 directly: the Finance
  legacy presenter is absent and the public projection exports its declared
  surface; the Messaging lifecycle port files exist and nothing outside
  `conversations/` and `modules/messaging/` imports
  `conversations/conversation-lifecycle`; the Marketplace legacy policy is
  absent, the public policy exports its declared surface, no alternate
  import path, re-export, dynamic import or copied declaration exists; the
  dependency ledger is absent, `architecture:imports` is the exact
  unbaselined command, the baseline generator is retired, and the package
  script chain still projects to the R12B/R5 security fingerprints.
- **R12B** verifies that the transition artifacts are gone, the Planning
  wedding-location contract exists once under its owner public slice with the
  strict DTO layout, its legacy location is absent and unimported, the
  successor dependency count is zero, and the qs security prerequisite is
  measured on the live lock (exactly one qs copy, not below the approved
  version, and a package graph the Prisma security checker accepts through
  its own projection chain). The lineage stage's `unapprovedProtected`
  counter has no closed counterpart and is no longer reported: the package
  and lock are pinned by the security checker and R5, and the other formerly
  protected files are ordinary reviewed code.
- **R12A** verifies the Backoffice/Catalog move layout and export inventory,
  the absence of the retired exception and of the sibling-exception needles,
  the guard order and runtime edges, zero successor dependencies, and live
  ownership.
- **R3** replays no lineage; the two R12C lifecycle modules and the port
  injections are declared as exact inventory entries and projected forward,
  so the strict stage counts them and the source law accepts the port tokens.
- **R5** treats the R12C predecessor projection as historical; the one
  Identity import moved by Task 4 and the QA-harness smoke file are
  normalized from the frozen R12C records.
- The **security prerequisite** and **R5** still pin `backend/package.json`
  and the approved `backend/package-lock.json` lineage; the strict import
  command remains unbaselined and unallowanced.

Nothing is baselined, allowed, ignored or excluded by the closure. The three
manifests are frozen by hash, not consulted for byte replay.

### What remains provable, and where

- At `lineageCommit` the complete lineage gates pass verbatim with no closure
  record present. The governance-portability suite proves this on every run:
  it checks the lineage commit out in its clone and runs the architecture
  aggregate and the security prerequisite there, asserting that R12A/R12B/R12C
  report `stage=strict` without `(closed)`. The typecheck gate at the lineage
  commit needs the generated Prisma client, an install-time step the clone
  does not perform; it is verified in clean-room checkouts.
- Tests that exercise lineage-only laws (predecessor reconstruction, overlay
  inventory, governed-fingerprint drift, documentation mirrors) are skipped
  in closed mode with the reason printed in the test output; none is deleted
  or weakened, and every one runs again at any commit before the closure.
- The closure cannot be moved to hide a change: a lineage commit that already
  contains the closure record fails the lineage proof, a lineage commit whose
  gates fail fails it, and a manifest edited after closure fails every
  closed gate.

### Governance after closure

Governed files are ordinary reviewed code from the closure onwards: the
scanners, tests, security checker and design documents change through
regular commits, guarded by their test suites and by the live invariants
above, not by byte fingerprints. The strict-candidate tool remains only for
reproducing the historical registration at commits before the closure.
