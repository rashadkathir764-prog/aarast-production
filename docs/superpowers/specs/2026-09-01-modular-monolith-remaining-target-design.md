# Modular Monolith Remaining Target Design

**Status:** Active after the owner-approved R11 documentation reconciliation
passed every local scope, architecture, documentation, and independent-review
gate on 2026-09-01. It does not authorize R12 source implementation,
additional Git mutation, deployment, or release activity.

The 2026-08-04 architecture document remains the source of the final target.
`ARCHITECTURE.md` remains the repository's canonical human-readable law. This
design resolves execution-sequence drift after the locally closed R0-R10 wave;
it does not weaken, cancel, or silently redefine the original target.

`R0-R10 execution wave locally closed` is not equivalent to
`modular-monolith architecture target complete`. The latter remains false
while dependency debt is 22 or ownership debt is 385/781.

## Authority And Immutable Inputs

- Repository: `D:\projects\aarast-modular-monolith`.
- Branch: `modular-monolith`.
- Historical R10 comparison base and immutable R9 closeout:
  `e560e5784278907dd6bf565327c3abfa0c9b8cab`.
- Local R10 closeout and R11 comparison base:
  `4d0d3ee91fb32d0432aa3bd69fe018d9a5a323b1`.
- Original target SHA-256:
  `db4232f9795b5211532c454f838996af7e50d5aefee13a20d5e3e513539845f4`.
- R10 is committed locally. Push, merge, deployment, remote CI, real provider
  delivery, and store release are outside the verified state.

If any identity or live debt count differs, the next phase stops for a fresh
read-only audit. A later plan may narrow only its own implementation scope; it
may not change the final target defined here and in the original specification.

## Binding Final Target

The remaining program preserves every original invariant:

1. Every Prisma table has exactly one owning bounded context.
2. Cross-context access uses owner public contracts only.
3. Prisma access resides inside the owner context's `infrastructure/` path.
4. Finance domain policy remains pure and free from framework and Prisma code.
5. Backend module and dependency graphs remain acyclic.
6. `forwardRef()` and project-owned `@Global()` counts remain zero.
7. Dependency and ownership boundaries are enforced by machine gates.
8. Routes, methods, auth flags, DTOs, response shapes, errors, Arabic copy,
   permissions, transaction scope, lock order, schema, migrations, Mobile
   routes, Admin routes, and deployment topology preserve observable behavior.
9. Existing tests remain behavior oracles and are not weakened to make a move
   pass.
10. Baselines shrink only by exact reviewed deletion and disappear only at
    strict zero.

## R0-R10 Reconciliation Matrix

| Original phase | Verified result through local R10 closeout | Reconciliation |
| --- | --- | --- |
| R0 Governance | Governance, scanners, baselines, and CI foundations exist | Complete for its original scope |
| R1 Platform + shared-kernel | Target platform/shared-kernel relocation completed | Complete for its original scope |
| R2 Schema folder split | Native Prisma schema-folder split and equivalence gates completed | Complete for its original scope |
| R3 Ports-first strangler | 13 contexts and public/full module structure exist, but 22 cross-context records remain behind a baseline | Partial against the original zero-baseline exit |
| R4 Finance internal | One Finance-to-Planning budget write debt was retired; the full Finance internal/domain target remains | Partial |
| R5 Identity internal | 44 Identity files relocated and old roots removed; Identity ownership remains 60/78 | Partial against the original ownership-strict exit |
| R6 Collaboration internal | OTP transport separation and later Collaboration relocation landed; Collaboration ownership remains 28/80 | Partial against the original ownership-strict exit |
| R7 Remaining modules internal | The executed R7 relocated Collaboration, not all originally listed remaining modules | Original R7 scope remains incomplete |
| R8 Consumers + hardening | Project globals and missing Prisma wiring were corrected; Insights/Backoffice port-only consumption, repo-wide ownership zero, and baseline deletion remain | Partial |
| R9 Mobile | Strict public APIs and legal projection 159 passed; the broader provider-portal/god-file/phone/shared fate map was not fully re-proven | Partial until a fate-map audit closes it |
| R10 Admin + closeout | Admin restructure is complete, committed locally, and verified; the whole architecture target is not closed | Admin complete; final closeout incomplete |

This matrix preserves completed work as evidence. It does not reinterpret a
partial original exit gate as complete, and it does not schedule gratuitous
rework of an already proven outcome.

## Dependency Debt Ledger

The live known-violations file contains exactly 22 records. IDs are immutable
so each R12 subphase deletes named records instead of regenerating a count.

| ID | Consumer -> deep dependency |
| ---: | --- |
| 1 | `src/admin/admin-mutation-executor.ts` -> `src/marketplace/provider-review-rating.ts` |
| 2 | `src/catalogs/administrative-catalog.service.ts` -> `src/admin/admin-mutation-gate.ts` |
| 3 | `src/catalogs/catalogs.controller.ts` -> `src/admin/admin-permission.decorator.ts` |
| 4 | `src/catalogs/catalogs.controller.ts` -> `src/admin/admin-permission.guard.ts` |
| 5 | `src/catalogs/catalogs.controller.ts` -> `src/admin/admin.guard.ts` |
| 6 | `src/catalogs/reference-catalog.service.ts` -> `src/admin/admin-mutation-gate.ts` |
| 7 | `src/dashboard/dashboard.contracts.ts` -> `src/wedding-plans/wedding-location.ts` |
| 8 | `src/dashboard/dashboard.service.ts` -> `src/wedding-plans/wedding-location.ts` |
| 9 | `src/marketplace/marketplace.presenter.ts` -> `src/wedding-plans/wedding-location.ts` |
| 10 | `src/marketplace/marketplace.service.ts` -> `src/wedding-costs/wedding-cost.presenter.ts` |
| 11 | `src/marketplace/marketplace.service.ts` -> `src/wedding-plans/wedding-location.ts` |
| 12 | `src/marketplace/quote-offer-acceptance.ts` -> `src/conversations/conversation-lifecycle.ts` |
| 13 | `src/marketplace/quote-offer-acceptance.ts` -> `src/wedding-costs/wedding-cost.presenter.ts` |
| 14 | `src/marketplace/quote-offer-rejection.ts` -> `src/conversations/conversation-lifecycle.ts` |
| 15 | `src/marketplace/quote-request-cancellation.ts` -> `src/conversations/conversation-lifecycle.ts` |
| 16 | `src/marketplace/quote-request-creation.ts` -> `src/conversations/conversation-lifecycle.ts` |
| 17 | `src/provider-dashboard/provider-dashboard.service.ts` -> `src/conversations/conversation-lifecycle.ts` |
| 18 | `src/provider-dashboard/provider-dashboard.service.ts` -> `src/wedding-plans/wedding-location.ts` |
| 19 | `src/conversations/conversations.service.ts` -> `src/provider-dashboard/provider-access-policy.ts` |
| 20 | `src/notifications/notifications.service.ts` -> `src/provider-dashboard/provider-access-policy.ts` |
| 21 | `src/onboarding/dto/import-local-plan.dto.ts` -> `src/guests/dto/create-guest.dto.ts` |
| 22 | `src/onboarding/dto/import-local-plan.dto.ts` -> `src/tasks/dto/create-task.dto.ts` |

The current rule projection is:

| Dependency rule | Records |
| --- | ---: |
| `context-backoffice-cross-context` | 1 |
| `context-catalog-cross-context` | 5 |
| `context-insights-cross-context` | 2 |
| `context-marketplace-cross-context` | 10 |
| `context-messaging-cross-context` | 1 |
| `context-notifications-cross-context` | 1 |
| `context-planning-cross-context` | 2 |
| **Total** | **22** |

## Ownership Debt Ledger

The live ownership baseline contains exactly 385 records and 781 occurrences.

| Context | Records | Occurrences |
| --- | ---: | ---: |
| backoffice | 67 | 152 |
| catalog | 3 | 8 |
| collaboration | 28 | 80 |
| finance | 20 | 48 |
| guests | 4 | 7 |
| identity | 60 | 78 |
| insights | 36 | 79 |
| marketplace | 78 | 161 |
| media | 1 | 1 |
| messaging | 28 | 39 |
| notifications | 30 | 79 |
| planning | 24 | 37 |
| tasks | 6 | 12 |
| **Total** | **385** | **781** |

The reason projection is an alternate classification of those same records,
not a second backlog:

| Reason | Records | Occurrences |
| --- | ---: | ---: |
| `foreign-model` | 301 | 563 |
| `unknown-relation-shape` | 83 | 216 |
| `unknown-sql-composition` | 1 | 2 |
| **Total** | **385** | **781** |

### Exact Ownership Allocation

R13-R17 own the entire retirement exactly once:

| Phase | Context allocation | Records | Occurrences |
| --- | --- | ---: | ---: |
| R13 | Planning + Finance | 44 | 85 |
| R14A | Identity | 60 | 78 |
| R14B | Collaboration, after R14A | 28 | 80 |
| R15 | Tasks + Guests | 10 | 19 |
| R16 | Catalog + Marketplace + Media + Messaging + Notifications | 140 | 288 |
| R17 | Insights + Backoffice | 103 | 231 |
| **Total** | **All 13 contexts** | **385** | **781** |

R18 owns no debt retirement. It may enter only after R17 proves 0 records and
0 occurrences. If any record remains, R18 stops and returns it to the exact
R13-R17 owning phase. R18 then runs the strict scanner without the baseline and
deletes the zero-valued baseline only after strict zero passes.

### Retirement Rules

Every ownership implementation plan must:

1. Name the exact records and occurrences it owns before source edits.
2. Add RED scanner or contract coverage for every intended boundary.
3. Route foreign access through the owner public contract.
4. Move Prisma access into the owner's `infrastructure/` path.
5. Delete only the approved baseline entries; never regenerate the baseline.
6. Stop on unrelated additions, count increases, or scanner ambiguity.
7. Preserve transaction scope, lock order, errors, routes, DTOs, and Arabic.
8. Recompute both context and reason projections after exact subtraction.

## R11-R20 Completion Program

Each row after R11 is a planning boundary, not permission to edit source code.
Every phase requires its own design, implementation plan, scope fence,
independent review, affected tests, architecture gates, and documentation gate.

| Phase | Bounded outcome | Required zero/projection gate |
| --- | --- | --- |
| R11 | Reconcile target, current state, debt ledger, and future phase order in active docs | Docs agree; live debt remains truthfully 22 and 385/781 |
| R12A | Replace Backoffice/Catalog authority and mutation deep imports with owner public contracts | Retire dependency records 1-6; 22 -> 16 |
| R12B | Replace Planning DTO reuse and Planning-location read-model deep imports | Retire dependency records 7-9, 11, 18, 21-22; 16 -> 9 |
| R12C | Replace Finance presenter, Messaging lifecycle, and Marketplace access-policy deep imports | Retire dependency records 10, 12-17, 19-20; 9 -> 0; delete dependency baseline only after strict scan passes |
| R13 | Complete Planning and Finance internals, including pure Finance domain and owner-only Prisma infrastructure | Retire Planning 24/37 and Finance 20/48; phase total 44/85 |
| R14A | Complete Identity internals and preserve the owner-side invite OTP port | Retire Identity 60/78 before Collaboration begins |
| R14B | Complete Collaboration internals without changing OTP, deletion, permission, sharing, or history behavior | Enter only after R14A exits; retire Collaboration 28/80; combined R14 total 88/158 |
| R15 | Complete Tasks and Guests internals as separate bounded contexts | Retire Tasks 6/12 and Guests 4/7; phase total 10/19 |
| R16 | Complete Catalog, Marketplace, Media, Messaging, and Notifications internals in five separately reviewed subplans | Retire Catalog 3/8, Marketplace 78/161, Media 1/1, Messaging 28/39, Notifications 30/79; phase total 140/288 |
| R17 | Re-express Insights and Backoffice as consumers of owner ports only | Retire Insights 36/79 and Backoffice 67/152; phase total 103/231; ownership reaches 0/0 |
| R18 | Prove repo-wide ownership strictness without a baseline and delete the zero-valued ownership baseline | Entry 0/0; strict scan remains 0/0 after baseline deletion |
| R19 | Audit the unproven remainder of the original Mobile fate map, then execute only confirmed gaps in separate Mobile plans | Provider portal, god-file, phone, and shared redistribution are either proven complete or completed; strict boundary gate stays green |
| R20 | Run one final all-surface closeout and produce the architecture-target completion report | Dependency 0, ownership 0/0, all baselines gone, all binding invariants re-proven in one run |

### Entry And Exit Dependencies

```text
R11 -> R12A -> R12B -> R12C -> R13 -> R14A Identity
R14A Identity -> R14B Collaboration -> R15
R15 -> R16 catalog -> R16 marketplace -> R16 media
R16 marketplace -> R16 messaging -> R16 notifications
R16 all -> R17 -> R18 -> R19 audit/confirmed work -> R20
```

R16 consists of five separately reviewable subplans. R19 starts with a
read-only fate-map audit; Mobile implementation is forbidden when the audit
proves an original target already satisfied. Real-phone QA is mandatory for
every confirmed Mobile behavior change.

## Permanent Stop Rules

Stop the active phase immediately when any of the following occurs:

- repository identity, base commit, or approved source hash drifts;
- a changed path falls outside the phase fence;
- a baseline count grows, is regenerated, or loses exact subtraction evidence;
- routes, schema, migrations, errors, permissions, transaction semantics, or
  Arabic product behavior change without separate approval;
- a test is weakened, skipped, or deleted to make relocation pass;
- a future phase is implemented before its design and plan are approved;
- a runtime or real-phone gate fails in a behavior-affecting phase;
- a report confuses local proof with push, merge, deployment, provider delivery,
  remote CI, or store release.

## Final R20 Definition Of Done

R20 may use `architecture target complete` only when one fresh verified run
proves all of the following:

- dependency-cruiser strict with no known-violations file;
- ownership strict at 0 records / 0 occurrences with no ownership baseline;
- all 13 Backend contexts import only public contracts;
- owner-only Prisma access, pure Finance domain, acyclic graph,
  `forwardRef()` 0, and project `@Global()` 0;
- unchanged Prisma schema and migrations with equivalence proof;
- Backend check, build, full tests, and full managed smoke pass;
- Mobile analyze, full tests, strict boundaries, and affected real-phone
  journeys pass;
- Admin architecture, typecheck, build, full tests, honesty, and runtime checks
  pass;
- generated Backend, Mobile, and Admin route contracts remain unchanged;
- documentation sync, documentation verification, and `git diff --check` pass;
- independent code, architecture, runtime, and cumulative-plan reviews approve;
- the final report distinguishes local completion from push, merge, deployment,
  remote CI, real provider delivery, and store release.

Until then, the truthful verdict remains: the locally closed execution wave is
healthy, but the original modular-monolith architecture target is incomplete.
