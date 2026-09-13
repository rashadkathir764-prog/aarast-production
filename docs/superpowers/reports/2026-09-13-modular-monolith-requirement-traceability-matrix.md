# Modular Monolith Requirement Traceability Matrix

**Date:** 2026-09-13
**Measured at:** recovery worktree `D:/projects/aarast-r12c-recovery`, branch
`recovery/r12c-t5-takeover-20260913`, HEAD `fd197a4d` (after the R12C
governance closure `86df8c36`).
**Authority:** the original architecture target
`docs/superpowers/specs/2026-08-04-modular-monolith-architecture-design.md`
(657 lines, SHA-256
`db4232f9795b5211532c454f838996af7e50d5aefee13a20d5e3e513539845f4`, the
same bytes the R11 reconciliation recorded from its external location; it is
tracked in this repository from this report's change onward), the
remaining-target design
`docs/superpowers/specs/2026-09-01-modular-monolith-remaining-target-design.md`
(R11), and the R0–R10, R12A, R12B and R12C specs, plans and reports.
**Reviewer:** the implementing agent (same-agent; no independent reviewer was
available in this session). Recorded as such.

## 1. Verdict

**MODULAR MONOLITH MISSION: NOT CLOSED.**

What is closed is the execution wave R0–R12C: the import law is strict and
unbaselined at zero, every context imports only public contracts, the
platform/shared-kernel/schema-folder/mobile-boundary/admin-boundary targets
are proven live, and the byte-lineage governance that carried R12A–R12C is
closed with its lineage provable. What remains open is the physical-ownership
half of the target — Prisma access inside owner `infrastructure/` only (385
records / 781 occurrences remain behind the ownership baseline), the pure
Finance domain, the erasure-port deletion saga, port-based reminder and
insights composition, the Public/Full split for five contexts — and the
unaudited remainder of the Mobile fate map (provider-portal split, god-file
splits, shared redistribution). These are R13–R20 of the binding
remaining-target design and are not remediation of a broken invariant; they
are the unfinished half of the target, and this report does not reinterpret
them as complete.

Status vocabulary: **CLOSED** = proven by a gate or test run in this session
at HEAD; **PARTIAL** = part proven, the rest named exactly; **OPEN** = not
started or not proven. No row is CLOSED without a named proof.

## 2. Evidence base (this session, HEAD `fd197a4d`)

| Gate | Result |
| --- | --- |
| `npm --prefix backend run architecture` | 12/12 PASS: depcruise 353 modules / 1,420 dependencies / 0 violations (no `--ignore-known`); ownership 385 records; ports forwardRef=0 globals=0 illegal-future-imports=0 cycles=0; R3 contexts=13 illegal=0 cycles=0; R4 12/12; R5 moves=44; R6; R7 dependency=0; R8 globals=0 Prisma=21/21 forwardRef=0 cycles=0; R12A/R12B/R12C `stage=strict (closed)`, dependency=0, ownership=385/781 |
| `npm --prefix backend run check` | 0 |
| `npm --prefix backend run security:prisma-config-merge` | PASS |
| `npm --prefix backend test` | 1,506 tests, 1,477 pass, 0 fail, 29 skipped (26 lineage-only + 2 portability lineage, printed reason; 1 declared Windows POSIX-permission skip) |
| Governance portability suite | 7 pass / 2 lineage skips; lineage gates re-run at `4bae5c6d` in a clone |
| `node scripts/docs-sync.mjs --check` / `node scripts/docs-verify.mjs` | drift 0 / errors 0 warnings 0 |
| `node scripts/check-mobile-boundaries.mjs --strict` | passed (legal=159) |
| `flutter analyze` / `flutter test` (Flutter 3.41.7) | 0 issues / 1,164 pass |
| `admin-web`: `npm run architecture` / `typecheck` / `test` | strict api=0 auth=0 components=0 pages=0 / 0 / 101 pass (20 files) |
| Migrations since the R0 contract commit `f009597b` | 0 (76 migrations, all predate R0) |
| Smokes (`smoke:all` 30/30, six phase-2 concurrency packages, account-deletion, sharing-security) | last full run: R12C Task 6, 2026-09-13, commit `fd21fed0` (this session's lineage); not re-run in this report |

## 3. The four dependency laws

| # | Requirement (spec §"The four dependency laws") | Proof | Status | Remaining |
| --- | --- | --- | --- | --- |
| L1 | Import law: a context imports only itself, other contexts' `public/`, `shared-kernel/`, `platform/` | `backend/.dependency-cruiser.cjs` context rules for all 13 contexts, `public-cross-owner-type-only`, `application-composition-*`, `platform-no-business-contexts`, `shared-kernel-is-foundational`; `architecture:imports` strict, 0 violations, no ledger (R12C T5); R3 `illegal=0` | **CLOSED** | — |
| L2 | Ownership law: only the owner's `infrastructure/` executes reads/writes on its models; single E1 exception | `ownership-scan.cjs` measures 385 records / 781 occurrences of foreign or unresolved Prisma access behind `architecture/ownership-baseline.json` (backoffice 67/152, marketplace 78/161, identity 60/78, insights 36/79, notifications 30/79, collaboration 28/80, messaging 28/39, planning 24/37, finance 20/48, tasks 6/12, guests 4/7, catalog 3/8, media 1/1). The baseline is exact-subtraction only (R4 retired the one Finance→Planning budget write via `PLANNING_BUDGET_WRITE_PORT`). No `infrastructure/` layer exists in any context. | **OPEN** (baseline-gated) | R13–R18 of the remaining-target design: retire 385/781 to 0/0 and delete the ownership baseline after strict zero |
| L3 | Purity law: `domain/` imports no `@nestjs/*` or runtime Prisma | depcruise `domain-no-nest-runtime` rule active; the only `domain/` folder is `modules/backoffice/domain/admin-permissions.ts` (pure) | **PARTIAL** | Finance domain layer (`WeddingCostAggregate`, `PaymentSchedulePolicy`, `BudgetAllocationPolicy`, `CostCategoryMatching`) does not exist; Finance invariants live in `wedding-costs.service.ts` (R13) |
| L4 | Acyclicity: module graph acyclic, `forwardRef` = 0 | ports scan `forwardRef=0 … Nest module cycles=0`; depcruise `no-circular`; R8 `forwardRef=0, cycles=0` | **CLOSED** | — |

## 4. Structural requirements

| # | Requirement | Proof | Status | Remaining |
| --- | --- | --- | --- | --- |
| S1 | Backend layout: `platform/`, `shared-kernel/`, `modules/<13>/`; `common/` dissolved | `src/platform/{config,database,health,http,idempotency,observability,otp-transport,outbox,redis}`, `src/shared-kernel/{money,phone,privacy,time}`, `src/modules/` with all 13 contexts; no `src/common`, `src/prisma`, `src/outbox`, `src/health`, `src/auth`, `src/users`, `src/me`, `src/contexts`, `src/sharing`, `src/contribution-history` (R1, R5, R6, R7) | **PARTIAL** | 17 legacy roots remain (admin 19 files, budget-categories 4, catalogs 6, conversations 10, dashboard 7, guests 7, marketplace 21, media 8, money 4, notifications 3, onboarding 6, provider-dashboard 13, push 6, tasks 7, timeline 2, wedding-costs 11, wedding-plans 4); their fate rows are R13–R17 |
| S2 | Module anatomy: `public/` ports+readmodels, `api/`, `application/`, `domain/`, `infrastructure/` | Every context has `<name>.module.ts` and `internal/`; 8 contexts have `public/` (identity, planning, finance, collaboration, marketplace, messaging, notifications, media); backoffice has `public/` (guards, gate) and `domain/`; identity and collaboration have `api/` | **PARTIAL** | No context has `application/` or `infrastructure/`; tasks, guests, catalog, insights have no `public/` (insights needs none by design) |
| S3 | Public/Full NestJS module split | 12 public modules: collaboration (history, permission, scope), identity (auth, transient-delivery), media (storage), messaging (conversation-lifecycle, realtime), notifications (notifications, push-capability, push-delivery), planning (budget-write); R3 proves cross-context injection 0 and composition dependencies 0 | **PARTIAL** | No public module for tasks, guests, catalog, backoffice (their consumers use `internal` modules/files through allowed paths); ports named in the spec that do not exist: `SessionAssertPort`, `UserReadPort`, `ActivePlanPort`, `SessionRevocationPort`, `PlanAccessPort`, `PlanReadPort`, `FinancePort`, `PermissionLockPort`, `ContributionRecorderPort` (exists as history port), `TaskReadPort`, `GuestReadPort`, `ProviderReadPort`, `QuoteReadPort`, `ModerationPort`, `CatalogReadPort`, `CatalogAdminPort`, `MediaVerifyPort`, every `AccountErasurePort` |
| S4 | Prisma schema folder split, one file per owner, `migrate diff` empty | `prisma/schema/{_base,platform,+12 owners}.prisma` (14 files); `test/prisma-dmmf-fingerprint.test.ts` and `test/prisma-r2-schema-scope.test.ts` pin DMMF equivalence (R2) | **CLOSED** | — |
| S5 | Zero new migrations in the mission | 0 migration directories added after `f009597b` (R0 contract, 2026-08-11); 76 migrations | **CLOSED** | — |
| S6 | Transaction propagation: `platform/database` exports `Tx` + `runRetryableTransaction`; explicit trailing `tx` | `src/platform/database/serializable-transaction.ts` exports `runRetryableTransaction`; the R12C lifecycle port takes `tx` on every method (Task 3, 9 call sites pass the exact `tx`) | **CLOSED** for the relocated seams | Ports not yet created (S3) will carry `tx` when created |
| S7 | Row-lock ordering preserved verbatim (request-first in quote flows, member-row in permission rechecks) | quote scripts moved intact (`marketplace/quote-*.ts`); phase-2 concurrency smokes (marketplace-write, provider-dashboard, provider-rating, quote, conversation-revocation, notification-*) PASS at Task 6 `fd21fed0` | **CLOSED** (behavior) | Physical move into `marketplace/application/quotes/` is R16 |
| S8 | Enforcement tooling: dependency-cruiser, ownership test, ports test, mobile boundary script, `ARCHITECTURE.md`, CI wiring | all present; CI runs `check`, `architecture`, `test` (backend) and the mobile/admin jobs; R0 baselines: dependency baseline deleted at R12C, ownership baseline remains (L2) | **PARTIAL** | Ownership baseline deletion (R18) |

## 5. Module contracts (spec §"Module Contracts")

| Context | Requirement | Proof | Status | Remaining |
| --- | --- | --- | --- | --- |
| platform | no business rules; database/outbox/otp-transport/idempotency/observability/redis/http/config/health | folders exist; depcruise `platform-no-business-contexts`; R1, R6 (otp-transport) | **CLOSED** | — |
| shared-kernel | money/phone/privacy/time, depends on nothing | folders exist; depcruise `shared-kernel-is-foundational` | **CLOSED** | — |
| identity | auth/session/OTP/profile/contexts/deletion; `SessionAssertPort`, `UserReadPort`, `InviteOtpPort`, `ActivePlanPort`, `SessionRevocationPort`; guards exported from `public/`; deletion saga via erasure ports in the current `deleteMany` order | 44 files relocated (R5); `public/` exports JwtAuthGuard, JwtSessionGuard, CurrentUser, safe-user, access-token-scope; `IDENTITY_AUTH_PORT` carries invite OTP dispatch/verify (R6); `IDENTITY_TRANSIENT_DELIVERY_PORT`; deletion sequence intact in `modules/identity/internal/profile/users.service.ts` (account-deletion smoke PASS at T6) | **PARTIAL** | Session-assert/user-read/active-plan/session-revocation ports and the erasure-port saga (identity 60/78) — R14A |
| planning | `WeddingPlan` lifecycle; `PlanAccessPort`, `PlanReadPort`; archive revokes invites via collaboration port | `PLANNING_BUDGET_WRITE_PORT` (R4 E1 seam); wedding-location read model published in `planning/public/wedding-location.ts` (R12B) | **PARTIAL** | Plan access/read ports, plan-graph deletion via erasure ports (planning 24/37) — R13 |
| finance | pure domain; `FinancePort.createCostFromAcceptedOffer(tx)`, `getPlanMoneySummary`, `listSchedulesDueBefore`; absorbs money/budget-categories/wedding-costs and `quote-cost-category` | Finance presenter published in `finance/public/wedding-cost.presenter.ts` (R12C T2); E1 write goes through the Planning port (R4); money-apis smoke PASS at T6 | **PARTIAL** | Domain layer, FinancePort, folder dissolution (finance 20/48) — R13 |
| collaboration | permissions, invites, tenures, history; `PermissionReadPort`, `PermissionLockPort`, `ContributionRecorderPort`, `ContributorScopePort`, invite revocation | `COLLABORATION_PERMISSION_PORT` (with the stable `TASK_PERMISSION_REVOKED` contract), `COLLABORATION_SCOPE_PORT`, `COLLABORATION_HISTORY_PORT`; relocation R7 (source 0 / target 18); sharing-security 38/38 and sharing-concurrency at R6/R7 completion, `smoke:all` at T6 | **PARTIAL** | Locked permission recheck port, invite lifecycle domain split (collaboration 28/80) — R14B |
| tasks / guests | 4-layer contexts; due/counter ports; erasure ports | `modules/tasks` and `modules/guests` exist with internal modules; stable denial contract owned by the collaboration permission port | **PARTIAL** | Service splits and ports (tasks 6/12, guests 4/7) — R15 |
| marketplace | providers, favorites, reviews (rating recompute under ordered lock), quotes, plan links, provider portal; `ProviderReadPort`, `QuoteReadPort`; quote scripts consume finance/collaboration/notifications/messaging ports | `provider-access-policy` and `provider-review-rating` published under `marketplace/public` (R12A M1, R12C T4); lifecycle calls go through the messaging port (R12C T3); provider-dashboard consumers use marketplace public | **PARTIAL** | Provider-dashboard merge, repository layer, read ports (marketplace 78/161) — R16 |
| messaging | conversations/participants/events/messages/reports; lifecycle port, moderation port, realtime publisher via `public`; socket auth via identity port | `CONVERSATION_LIFECYCLE_PORT` (tx-bound, R12C T3); `messaging-realtime` public module (R8, `@Global()` removed); gateway verifies JWT through `identity/public` (`IDENTITY_ACCESS_TOKEN_VERIFIER`, `resolveJwtSessionScope`) | **PARTIAL** | Gateway still reads `prisma.user`/`prisma.refreshToken` directly for session liveness (messaging 28/39); moderation port — R16 |
| notifications | rows/preferences/push; `NotificationWriterPort.create(tx)`, purge; reminder scan via tasks/finance ports (C2 query-based) | `NOTIFICATIONS_PORT`, push capability/delivery ports; reminder scan is query-based (C2 honored) | **PARTIAL** | Reminder scan queries `weddingTask`/`paymentSchedule` directly instead of `listTasksDueBefore`/`listSchedulesDueBefore` (notifications 30/79) — R16 |
| catalog | administrative references + categories; `CatalogReadPort`, `CatalogAdminPort` | `modules/catalog/internal` module; admin authority consumed through `backoffice/public` (R12A) | **PARTIAL** | Read/admin ports (catalog 3/8) — R16 |
| media | tickets, verification, signed URLs; `MediaVerifyPort` | `MEDIA_STORAGE` public port/module | **PARTIAL** | Verify port (media 1/1) — R16 |
| insights | no tables; dashboard+timeline over ports | `modules/insights/internal` module; wedding-location read model consumed from planning public (R12B) | **OPEN** | Dashboard/timeline re-expression over owner ports (insights 36/79) — R17 |
| backoffice | `AdminAuditLog`, guards/decorators, mutation gate/executor; all domain mutations via owner ports; `admin-permissions` in `domain/` | `backoffice/domain/admin-permissions.ts`; guards, decorator and mutation gate in `backoffice/public` (R10, R12A); Admin web restructured (R10) | **PARTIAL** | Mutation executor and audit still touch owner tables directly (backoffice 67/152) — R17 |

## 6. Binding external invariants (spec §"Binding External Invariants")

| Invariant | Proof | Status |
| --- | --- | --- |
| HTTP routes/methods/auth flags identical | `docs-sync --check` drift 0 (controller inventory regenerated identically) | **CLOSED** |
| Database schema identical, zero new migrations | S4, S5 | **CLOSED** |
| Response shapes/errors/Arabic identical | backend 1,477 pass with assertion-untouched tests (growth guard moved by the approved T3 delta only); smokes at T6 | **CLOSED** (as of T6 smokes) |
| Mobile route paths identical | `docs/frontend/MOBILE_ROUTES.md` regenerates identically (docs-sync); 1,164 mobile tests pass | **CLOSED** |
| Admin route paths identical | `docs/frontend/ADMIN_ROUTES.md` regenerates identically; 101 admin tests pass | **CLOSED** |
| Transaction boundaries/isolation identical | S6, S7; phase-2 concurrency smokes at T6 | **CLOSED** (as of T6) |
| Deployment artifacts identical | `deploy/`, `docker-compose.yml`, `admin-web/Dockerfile` untouched since R0; `backend/Dockerfile` gained two `COPY prisma.config.ts` lines at R2 (`9e3e51b5`), required by the schema-folder split; ports and domains unchanged (git history `f009597b..HEAD`) | **CLOSED** |
| Test-change policy | R12C T6 records the single non-import test edit (growth guard) with its reason; no assertion/expected value changed in R12A–R12C | **CLOSED** |

## 7. Mobile and Admin fate maps

| Requirement | Proof | Status | Remaining |
| --- | --- | --- | --- |
| Feature barrels `<f>_api.dart`; cross-feature imports via barrels; `core/` never imports `features/`; declared dependency list | 19 barrels under `mobile/lib/features/*/`; `check-mobile-boundaries.mjs --strict` legal=159 (R9) | **CLOSED** | — |
| `provider_portal` split from `marketplace` | no `mobile/lib/features/provider_portal/` | **OPEN** | R19 fate-map audit then confirmed work (remaining-target design) |
| God-file splits (≤ 700 lines), phone consolidation, `shared/` redistribution | not audited in this session | **OPEN** (unproven) | R19 |
| Admin: `platform/`, `design_system/`, `features/<area>/`, `layout/`, `pages/` dissolved | `admin-web/src/{platform,design_system,features/{audit,auth,catalog,dashboard,moderation,notifications,providers,users},layout}`; `admin-boundaries.mjs --strict` api=0 auth=0 components=0 pages=0 (R10) | **CLOSED** | — |

## 8. Phase reconciliation (R0–R12C)

| Phase | Original exit | Verified | Status |
| --- | --- | --- | --- |
| R0 Governance | ARCHITECTURE.md, registry, depcruise baseline, CI | present; baselines superseded by later phases | CLOSED |
| R1 Platform + shared-kernel | `common/` gone; docs identical | S1 | CLOSED |
| R2 Schema folder split | migrate diff empty; zero migrations | S4, S5 | CLOSED |
| R3 Ports-first strangler | 13 public slices; strict import rules; forwardRef 0 | 13 contexts; strict imports reached only at R12C; 12 public modules, not 13 slices | PARTIAL (S3) |
| R4 Finance internal | ownership strict for finance + E1 | E1 seam only | PARTIAL (finance 20/48) |
| R5 Identity internal | ownership strict for identity | relocation complete (44 moves); ownership 60/78 | PARTIAL |
| R6 Collaboration internal | ownership strict for collaboration | OTP transport separated; ownership 28/80 | PARTIAL |
| R7 Remaining modules | ownership strict for their tables | executed as Collaboration relocation | PARTIAL |
| R8 Consumers + hardening | zero direct Prisma outside owners; baselines deleted | project globals 0, Prisma wiring 21/21; ownership baseline remains | PARTIAL |
| R9 Mobile | boundaries strict; provider_portal; god-files | strict boundaries legal=159; fate-map remainder unproven | PARTIAL |
| R10 Admin + closeout | admin restructure; docs; final report | complete (R10 final report) | CLOSED for Admin; target closeout not claimed |
| R11 Reconciliation | docs agree; debt truthful | remaining-target design + report | CLOSED |
| R12A | dependency 22 → 16 | R12A report; closed-mode gate | CLOSED |
| R12B | 16 → 9 | R12B report; closed-mode gate | CLOSED |
| R12C | 9 → 0, baseline deleted, strict import gate | R12C report §1–7; closed-mode gate; closure record | CLOSED |

## 9. What this matrix does not claim

- It does not claim the architecture target complete; the remaining-target
  design's R13–R20 stay binding and unstarted. The mission that produced this
  report forbids opening them as new phases; they are recorded here as the
  exact remaining work with their live counts.
- It does not re-run the managed smoke suites; the last full smoke evidence
  is Task 6 (`fd21fed0`, this session). The clean-room verification report
  of this mission records what it re-runs.
- Reviews are same-agent.
