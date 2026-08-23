# Modular Monolith R7 Collaboration Relocation Design

Date: 2026-08-23

Status: Owner-approved design; staged implementation plan approved separately

Branch: `modular-monolith`

Immutable R7 base: `31ea5324007fc71fa4b3590fbb98a454ee1deaa7`

## Objective

Move the complete Collaboration implementation from the legacy
`backend/src/sharing` and `backend/src/contribution-history` roots into the
existing `backend/src/modules/collaboration` boundary without changing product
behavior. The final tree has one physical Collaboration source owner, no old
path facade, no duplicate implementation, and no new dependency or ownership
debt.

R7 is a physical source relocation and public-boundary completion phase. It is
not a Sharing product rewrite, a service decomposition, or a permissions,
schema, client, or deployment phase.

## Verified Starting State

The immutable R6 closeout is clean at
`31ea5324007fc71fa4b3590fbb98a454ee1deaa7`. R6 already removed
Collaboration's direct concrete OpenWA dependency through the Identity public
transient-delivery port. That correction makes a complete Collaboration move
possible without carrying a provider-specific transport edge into the module.

The live Collaboration context is still split across:

- 18 TypeScript files under `sharing` and `contribution-history`;
- 5,263 lines of source;
- 11 existing composition/public module files under `modules/collaboration`;
- 9 dependency-baseline records from Planning, Finance, Tasks, Guests, and
  Marketplace into the legacy contribution-snapshot builder;
- ownership records whose Collaboration semantics are correct but whose file
  paths still point at the two legacy roots.

The routed surface is 19 existing controller operations: 17 sharing/invitation
operations and 2 contribution-history reads. The dependency baseline contains
31 records, including exactly the 9 contribution-snapshot edges. The ownership
baseline contains 385 records / 781 occurrences.

## Root-Cause Standard

R7 fixes the physical-boundary cause instead of hiding it. Completion requires:

- every approved source file exists only at its final Collaboration path;
- both legacy roots are absent;
- all cross-context snapshot consumers import the final public Collaboration
  path;
- the 9 obsolete dependency records are deleted, not renamed or re-baselined;
- the ownership projection changes paths only and preserves all semantic fields
  and counts;
- all behavior, architecture, runtime, and phone gates pass on one immutable
  candidate.

R7 forbids:

- old-path re-exports, barrels, facades, symlinks, junctions, or build shims;
- parallel old/new implementations;
- new relocation-related fallback imports, new optional/default constructor
  dependencies, or new local token lookalikes;
- wrappers whose only purpose is temporary compatibility;
- blind baseline regeneration;
- a new baseline exception for any edge that R7 moves;
- deleted, skipped, weakened, or rewritten behavioral assertions;
- any deferred-removal marker or plan for an R7 compatibility artifact.

Test fixtures and staged manifests are verification infrastructure, not runtime
compatibility. They may not be imported by product source or packaged into the
runtime image.

The existing `SharingService` realtime dependency is deliberately frozen, not
forbidden: `MESSAGING_REALTIME_PORT`, constructor parameter `realtime`, index
5, remains decorated with `@Optional()` and keeps the exact current behavior
when the dependency is `undefined`. R7 may neither remove that optionality nor
introduce another optional/default dependency.

## Chosen Architecture

R7 uses a staged, one-to-one relocation into the existing three Collaboration
slices:

- `api/` owns controllers and DTOs;
- `internal/` owns services, internal policies, and private contracts;
- `public/` owns only contracts or stateless behavior required by a real
  current cross-context consumer.

The public contribution-snapshot builder is a final boundary, not a bridge.
Nine real callers across five contexts need its canonical privacy/sanitization
behavior. It remains one stateless implementation with the exact exports
`buildContributionSnapshot`, `canonicalJson`, `hashContributionSnapshot`, and
`validateContributionSnapshot`, plus the same validation, limits, hashes,
exception types, and messages. It may depend only
on its current runtime primitives (`node:crypto`, the Nest bad-request
exception, and Prisma enums/JSON types). It must not depend on a Collaboration
internal/API path, a Nest provider, `PrismaService`, or database access.

The existing Collaboration public ports remain the public service boundary:

- `COLLABORATION_PERMISSION_PORT`;
- `COLLABORATION_HISTORY_PORT`;
- `COLLABORATION_SCOPE_PORT`.

R7 adds no speculative service port and does not change token identity,
provider lifetime, or `useExisting` singleton bindings.

## Exact Source Fate Map

The move map is sorted, unique, one-to-one, and exhaustive.

| Current path | Final path |
| --- | --- |
| `backend/src/contribution-history/contribution-history.contracts.ts` | `backend/src/modules/collaboration/internal/contribution-history.contracts.ts` |
| `backend/src/contribution-history/contribution-history.controller.ts` | `backend/src/modules/collaboration/api/contribution-history.controller.ts` |
| `backend/src/contribution-history/contribution-history.service.ts` | `backend/src/modules/collaboration/internal/contribution-history.service.ts` |
| `backend/src/contribution-history/contribution-snapshot.builder.ts` | `backend/src/modules/collaboration/public/contribution-snapshot.builder.ts` |
| `backend/src/contribution-history/contributor-scope.service.ts` | `backend/src/modules/collaboration/internal/contributor-scope.service.ts` |
| `backend/src/contribution-history/dto/list-contributions.dto.ts` | `backend/src/modules/collaboration/api/dto/list-contributions.dto.ts` |
| `backend/src/sharing/dto/create-plan-invite.dto.ts` | `backend/src/modules/collaboration/api/dto/create-plan-invite.dto.ts` |
| `backend/src/sharing/dto/create-shared-member.dto.ts` | `backend/src/modules/collaboration/api/dto/create-shared-member.dto.ts` |
| `backend/src/sharing/dto/leave-plan.dto.ts` | `backend/src/modules/collaboration/api/dto/leave-plan.dto.ts` |
| `backend/src/sharing/dto/request-invite-otp.dto.ts` | `backend/src/modules/collaboration/api/dto/request-invite-otp.dto.ts` |
| `backend/src/sharing/dto/update-shared-member.dto.ts` | `backend/src/modules/collaboration/api/dto/update-shared-member.dto.ts` |
| `backend/src/sharing/dto/verify-invite-otp.dto.ts` | `backend/src/modules/collaboration/api/dto/verify-invite-otp.dto.ts` |
| `backend/src/sharing/invitation-delivery.service.ts` | `backend/src/modules/collaboration/internal/invitation-delivery.service.ts` |
| `backend/src/sharing/invite-access.service.ts` | `backend/src/modules/collaboration/internal/invite-access.service.ts` |
| `backend/src/sharing/permission.service.ts` | `backend/src/modules/collaboration/internal/permission.service.ts` |
| `backend/src/sharing/plan-permissions.ts` | `backend/src/modules/collaboration/internal/plan-permissions.ts` |
| `backend/src/sharing/sharing.controller.ts` | `backend/src/modules/collaboration/api/sharing.controller.ts` |
| `backend/src/sharing/sharing.service.ts` | `backend/src/modules/collaboration/internal/sharing.service.ts` |

No source file converges with another target. No extra file may move under the
R7 relocation exception.

## Dependency And Ownership Outcome

The nine current dependency records all target
`contribution-history/contribution-snapshot.builder.ts`. R7 updates their real
callers to `modules/collaboration/public/contribution-snapshot.builder.ts` and
removes those nine records from the dependency baseline. If no unrelated debt
moves, the strict current baseline becomes exactly 22 records.

This is debt retirement, not a rule exception. A new R7 scanner must reject:

- any current import of either legacy root;
- an internal/API Collaboration import from another context;
- a new dependency-baseline key or count increase;
- retention or path-renaming of any of the nine retired keys;
- an unexpected baseline decrease that is not mapped and reviewed;
- any cycle or `forwardRef()`.

The Collaboration model owner does not change. For every moved Prisma-using
file, the ownership baseline projection may change only the exact file path.
Context, owner, model, operation, mode, source kind, reason, and occurrence
count must be identical or decrease through a separately explained real debt
removal. The expected R7 result is 385 records / 781 occurrences.

Historical R3-R6 gates remain cumulative. Where a historical scanner pins a
legacy Collaboration path, R7 may add only an exact immutable handoff/projection
to the final path. It may not loosen the old assertion, rewrite the historical
base, or let an arbitrary future path pass. The R7 strict scanner becomes the
authority for the current physical layout while the earlier scanners continue
to prove their own phase contracts.

The handoff is machine-readable in
`backend/architecture/r7-collaboration-relocation.json`. R3 delegates the exact
R7 path fence through that separately validated manifest; immutable R3-R6
allowlists are not widened or rewritten. The design-stage fence contains the
approved design and the exact future R7 change surface only.

The four moved constructor-consumer identities are exact:

| Current consumer | Final consumer | Parameter | Index | Token |
| --- | --- | --- | ---: | --- |
| `sharing/invitation-delivery.service.ts#InvitationDeliveryService` | `modules/collaboration/internal/invitation-delivery.service.ts#InvitationDeliveryService` | `transientDelivery` | 0 | `IDENTITY_TRANSIENT_DELIVERY_PORT` |
| `sharing/invite-access.service.ts#InviteAccessService` | `modules/collaboration/internal/invite-access.service.ts#InviteAccessService` | `auth` | 1 | `IDENTITY_AUTH_PORT` |
| `sharing/sharing.service.ts#SharingService` | `modules/collaboration/internal/sharing.service.ts#SharingService` | `notifications` | 2 | `NOTIFICATIONS_PORT` |
| `sharing/sharing.service.ts#SharingService` | `modules/collaboration/internal/sharing.service.ts#SharingService` | `realtime` | 5 | `MESSAGING_REALTIME_PORT` |

The two decorator/controller source identities move exactly from
`contribution-history/contribution-history.controller.ts` to
`modules/collaboration/api/contribution-history.controller.ts` and from
`sharing/sharing.controller.ts` to
`modules/collaboration/api/sharing.controller.ts`. Their class, method, route,
guard, and `CurrentUser` inventories remain otherwise identical.

The same manifest pins all nine retired dependency keys and this ownership
projection:

| Current source | Final source | Records | Occurrences |
| --- | --- | ---: | ---: |
| `contribution-history/contribution-history.service.ts` | `modules/collaboration/internal/contribution-history.service.ts` | 5 | 7 |
| `sharing/invite-access.service.ts` | `modules/collaboration/internal/invite-access.service.ts` | 1 | 1 |
| `sharing/permission.service.ts` | `modules/collaboration/internal/permission.service.ts` | 2 | 6 |
| `sharing/sharing.service.ts` | `modules/collaboration/internal/sharing.service.ts` | 20 | 66 |

That is exactly 28 records / 80 occurrences inside the unchanged 385 / 781
ownership total. The nine dependency keys are evidence at the immutable R5/R6
revision and must be absent from the live R7 baseline; only R7 may certify the
live 22-record result.

## Runtime And Data-Flow Invariants

The runtime flow remains:

1. the same controller decorator and DTO validation receives the request;
2. the same internal service instance executes the use case;
3. the same Identity, Messaging, Notifications, and Collaboration public tokens
   are injected at the same constructor positions;
4. the same caller-owned Prisma transaction, isolation, raw SQL lock order, and
   retry policy execute;
5. the same contribution event, outbox event, notification, realtime
   revocation, persistence write, metric, and privacy-safe log is produced;
6. the same response or exact error propagates.

R7 freezes:

- all 19 HTTP methods/paths, guards, auth flags, parameters, DTO fields,
  validation rules, payloads, status codes, and response ordering;
- Arabic and English messages, stable error codes, exception types, and unknown
  error identity;
- invitation state transitions, delivery statuses, cooldowns, expiry, dedupe,
  hashing, and uncertain/rejected behavior;
- membership roles, permission ceilings, financial privacy, plan-not-found
  privacy behavior, owner protection, and self-leave rules;
- serializable and retryable transaction boundaries, `FOR UPDATE` statements,
  advisory/row lock order, retries, and idempotency;
- contribution snapshot keys, PII rejection, limits, canonical JSON, hashing,
  event immutability, tenure/scope rules, and dedupe behavior;
- notification/outbox/realtime event timing and transaction atomicity;
- provider registration count, singleton identity, controller identity, and
  module import graph.

`SharingService` remains byte-equivalent except required import paths. Its
3,097-line size is a separate maintainability concern. Splitting it during the
physical move would mix behavioral refactoring with relocation and make parity
unreviewable. R7 moves it directly to its final owner path without a temporary
wrapper. Any later decomposition must be a separately designed, test-first
phase and is not implied by R7.

## Staged Execution Model

Implementation uses clean local checkpoints on the same branch:

1. freeze R7 base, exact fate map, exact scope delegation, protected surfaces,
   route/provider identity, behavior hashes, dependency/ownership projections,
   and adversarial cases;
2. relocate the final public contribution-snapshot contract and update its nine
   cross-context consumers in the same checkpoint that removes the exact nine
   live dependency records, freezes R5/R6 evidence to their immutable
   revision/hash, and makes R7 alone certify the live 22-record baseline;
3. relocate Contribution History API/internal source and rewire its existing
   modules in the same checkpoint as its exact R3 decorator-source and
   ownership projections;
4. relocate Sharing API/internal source and rewire its existing modules in the
   same checkpoint as the four exact R3/R6 constructor handoffs, the second
   decorator-source handoff, and the remaining ownership projections;
5. delete the now-empty legacy roots, confirm every historical scanner proves
   its frozen phase revision while R7 proves the live final paths, reconcile
   generated script docs, and promote R7 to strict;
6. run exhaustive candidate verification and an independent diff/architecture
   review, correcting only proved root causes within the approved scope;
7. build an immutable image, probe, cut over locally, preserve the stopped R6
   rollback, and exercise the authenticated phone journey;
8. write exact completion receipts, run final gates, create a docs-only local
   closeout checkpoint, and stop before R8.

Each checkpoint must pass its focused RED/GREEN tests, architecture gates,
TypeScript check, diff review, and whitespace check before the next starts.
An unresolved behavior difference or unapproved test change stops execution.

## Test-Change Law

Existing behavioral assertions, expected values, fixtures, Arabic/error text,
timeouts, skips, test selection, setup order, and cleanup semantics are frozen.
R7 may make only reviewed mechanical import/require/path-literal changes caused
by the exact move map or exact DI path wiring. A failing behavioral test is
evidence of a relocation defect; it is not permission to edit the assertion.

New R7 tests must prove at minimum:

- immutable base identity and exact 18-entry fate map;
- sorted, unique, repository-relative, traversal-safe paths;
- source/target byte equivalence after normalizing only mechanical import paths;
- no missing, extra, converging, overlapping, or compatibility path;
- old roots absent at strict stage;
- exact API/controller/provider/token identity;
- public snapshot exports and allowed dependency set;
- no external internal/API import and no duplicate implementation;
- dependency baseline 31 minus the exact 9 retired records equals 22;
- ownership 385/781 with path-only semantic projection;
- protected schema, migration, seed, package-lock, Mobile, Admin, workflow,
  Compose, Docker, and deployment surfaces unchanged;
- historical R3-R6 gates remain strict rather than silently reset.

The design-stage scanner parses the live TypeScript sources with the compiler
AST. It rejects drift in the four public exports, their three allowed package
imports, constructor class/parameter/index/token/optionality contracts, and the
two controller class/method/route/guard/parameter-decorator inventories. The
114-path fence includes the three live R3 tests whose path literals must move
mechanically, and excludes generic dependency-cruiser and ownership-scanner
implementations because their existing rules already cover Collaboration.

## Verification And Acceptance

Focused verification covers Collaboration architecture and all current
sharing, invitation, permission, contribution-history, contributor-scope,
notification, conversation-revocation, plan, money, task, guest, and marketplace
behavior that imports or exercises the moved source.

The final candidate must pass:

- R7 exact scope/relocation/behavior tests;
- full R1-R7 architecture, dependency, ownership, ports, and Nest graph gates;
- Backend TypeScript check, build, and complete test suite;
- Prisma 6.19.3 validate/generate and DMMF/migration equivalence;
- full and production-only high-level npm audits with zero qualifying findings;
- targeted sharing/history/concurrency managed smokes and all 30 aggregate
  `smoke:all` packages;
- documentation sync/verify, protected-surface diff, whitespace, artifact, and
  managed-residue checks;
- independent exact-diff review with no unresolved Critical or Important
  finding.

No pass result may be inherited from R6 after an R7 source edit. Every claimed
gate is rerun on the exact R7 candidate.

## Immutable Runtime And Phone Gate

The exact committed application candidate is packaged as an immutable local
Backend image carrying the full revision. Before cutover, an isolated loopback
probe must pass migration discovery, dependency audit, `/live`, `/ready`,
restart/OOM, and sanitized fatal/secret-marker checks. The probe is then
removed.

Protected cutover reuses the accepted local configuration without printing or
persisting secrets. The R7 candidate must pass local and LAN `/live` and
`/ready`, required database/Redis/media readiness, zero restarts, no OOM, and
sanitized logs. R6 is stopped but preserved as rollback; it is not deleted or
overwritten.

The authenticated phone journey must prove that the accepted client reaches the
R7 LAN endpoint, then exercise:

1. session and context restoration;
2. dashboard and sharing-state reads;
3. creation of a local synthetic invitation;
4. invitation reissue after the existing cooldown;
5. related member/invitation/permission reads;
6. cancel the synthetic invitation through the existing API route and verify a
   post-cleanup read no longer returns it; cleanup failure fails the phone gate;
7. full force-close and reopen;
8. restored dashboard/session and sharing state.

Contribution-history correctness is covered by focused tests and managed
database smokes when no routed phone screen exposes the history directly. The
phone gate must not invent a UI path.

If OpenWA is disabled, the result records provider-disabled delivery truthfully.
No real WhatsApp-send claim is made. A real-recipient delivery test remains an
external mutation requiring separate owner confirmation. No phone number, OTP,
access token, invitation token, credential, raw body, or business value is
retained in receipts.

## Non-Goals And Frozen Surfaces

R7 does not:

- split, rewrite, simplify, or optimize `SharingService` or another moved file;
- change a route, DTO, permission, privacy rule, transaction, lock, retry,
  persistence write, response, error, metric, log, event, or provider behavior;
- create a repository or speculative public port;
- change Prisma schema, migrations, seed, generated client semantics, model
  ownership, or database data;
- change dependency versions or `package-lock.json`;
- edit Mobile, Admin Web, workflows, Dockerfiles, Compose, Dokploy, deployment,
  domains, ports, or secrets;
- remove either approved `@Global()` declaration; that remains R8;
- activate R9 Mobile strict mode or begin R10 Admin restructuring;
- push, merge, mutate PR #76, deploy, or claim remote CI.

## Rejected Alternatives

- **Move all 18 files in one unchecked change:** rejected because the 5,263-line
  surface and 3,097-line service make review and fault isolation weak.
- **Move only `sharing`:** rejected because it leaves one context split and all
  nine contribution-snapshot debts active.
- **Keep the builder in a legacy/shared path:** rejected because it preserves
  the wrong physical owner or turns business privacy policy into shared-kernel.
- **Wrap the old builder or services:** rejected as a compatibility layer and a
  second identity/lifecycle risk.
- **Copy then delete later:** rejected because parallel implementations make
  source and runtime identity ambiguous.
- **Regenerate baselines after moving:** rejected because it can rename debt
  into permission.
- **Split `SharingService` during relocation:** rejected because it mixes two
  independent high-risk transformations and weakens behavior-parity review.
- **Combine R7 with R8 globals:** rejected because global removal has different
  composition/bootstrap risks and deserves its own fixed-base phase.

## Completion Boundary

R7 is locally complete only when the exact 18 files live solely at their final
paths, both legacy roots are absent, the nine dependency debts are retired,
ownership remains semantically identical, every focused/full/smoke/runtime/
phone gate passes on one immutable candidate, exact receipts are committed
locally, and the worktree is clean.

No push, merge, PR mutation, deployment, remote CI, real-recipient message, or
R8 start is implied by local R7 completion.
