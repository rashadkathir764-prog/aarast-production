# Final Mission Traceability And Plan — R13–R20 Against The Original Request

**Date:** 2026-09-16
**Worktree:** `D:/projects/aarast-final-closeout`, branch
`final/modular-monolith-mission-closeout-20260913`, created from `cd45e435`
(= clean-room-verified `053166bd` plus the docs-only final-report commit;
`git diff --stat 053166bd cd45e435` touches only `docs/README.md`,
`docs/project/STATUS.md` and the final report). Baseline re-proven in the
new worktree before any change: `npm run check` 0, `npm run architecture`
12/12, security PASS, docs-sync drift 0, tree clean.
**Authority:** `docs/superpowers/specs/2026-08-04-modular-monolith-architecture-design.md`
(the original request, tracked verbatim, SHA-256 `db4232f9…`), reconciled
by the owner-approved `2026-09-01-modular-monolith-remaining-target-design.md`
(R11), read together with every R0–R12C spec/plan/report, the traceability
matrix, the exit audit and the final report of 2026-09-13.

## 1. What the original request actually asks for

The design's Objective (five points) and its four dependency laws are the
contract; everything else in the document is the *means* it prescribes:

| # | Original requirement (verbatim intent) | Where in the spec |
| --- | --- | --- |
| O1 | Exactly one owning module per database table; only the owner's `infrastructure/` executes reads or writes; one declared exception (E1); cross-module reads through the owner's port or read models; a module never `include`s another module's relation | Objective 1, Ownership law, Data Ownership Registry |
| O2 | Cross-module access only through declared public contracts (imports from `modules/B/public/`, `shared-kernel/`, `platform/` only) | Objective 2, Import law |
| O3 | A pure domain layer for financial invariants (`domain/` imports no `@nestjs/*`, no runtime Prisma) | Objective 3, Purity law, finance contract |
| O4 | Machine-enforced boundaries in CI, not human discipline; baselines are frozen lists that are deleted when their phase lands (R3 import baseline, R8 all baselines) | Objective 4, Enforcement tooling, Execution order |
| O5 | Zero change to external behavior: HTTP contract, schema, routes, test expectations | Objective 5, Binding external invariants |
| M1 | Module anatomy template (`public/`, `api/`, `application/`, `domain/`, `infrastructure/`) and the Public/Full NestJS module pattern; `forwardRef` = 0 | Target architecture |
| M2 | Transaction propagation: explicit trailing `tx`, lock order moved verbatim | UnitOfWork decision |
| M3 | Module contracts: port names "binding", method lists "the minimum complete set discovered from current cross-module usage"; erasure ports; identity session port for socket auth; C2 reminder ports | Module Contracts |
| M4 | Backend file fate map (MOVE/SPLIT/REWRITE/PORT/DISSOLVE per file) | Backend File Fate Map |
| M5 | Prisma fate map (schema folder split, zero migrations) | Prisma Fate Map |
| M6 | Mobile fate map: `core/` unchanged, phone wrappers dissolved, `quote_finance_context` moved, barrels + boundary script, `provider_portal` split, god-file splits (≤ 700 lines), tests import-path edits only | Mobile File Fate Map |
| M7 | Admin fate map | Admin Web File Fate Map |
| M8 | Execution order R0–R10 with exit criteria | Execution Order |

R11 (owner-approved) reconciled the means to a binding final target of ten
items and scheduled the remainder as R13–R20. R11's target keeps O1–O5, M1's
Public/Full split and `forwardRef` 0, M2, M5, and states item 3 as "Prisma
access resides inside the owner context's `infrastructure/` path". R11
does not restate the per-file SPLIT/REWRITE fates as debt; it measures the
remainder as ownership 385/781 plus the Mobile fate-map audit.

## 2. Phase-by-phase traceability (R13–R20)

Classification: **A** required original scope · **B** required remediation
(made necessary by the campaign itself or by a contradiction that blocks the
spec) · **C** optional improvement / scope creep (not executed).

| Phase | Exact requirement | Original source | Why still incomplete | Current evidence | Required work | Closure proof | Class |
| --- | --- | --- | --- | --- | --- | --- | --- |
| R13 Planning + Finance internals | Planning owns `WeddingPlan` exclusively; Finance owns its 4 tables exclusively; Finance domain pure | O1, O3, finance/planning contracts | planning files reach 9 foreign models (24 records / 37 occurrences); finance files reach Provider/QuoteOffer/QuoteRequest/WeddingPlan (20/48); no `modules/finance/domain/` | ownership baseline; `modules/finance/` = `public/wedding-cost.presenter.ts` + internal module only | Route every foreign access from Planning/Finance through owner ports; extract the Finance invariants into pure `domain/` files used by the services; purity gate | Ownership records for planning and finance = 0; `modules/finance/domain` imports no `@nestjs/*`/runtime Prisma (depcruise rule + unit test); money/finance smokes unchanged | **A** |
| R13 (part) "Finance SPLIT into ≤ 6 use cases + repository", `money/`, `budget-categories/`, `wedding-costs/` folders DISSOLVE into `modules/finance/` | M4 fate rows | folders still exist | — | — | — | **C** — folder dissolution and use-case splitting do not change any invariant of O1–O5 once ownership is exclusive; R11 did not carry them as debt. Recorded, not executed. |
| R14A Identity internals | Identity owns its 8 tables; the deletion saga calls each owner's erasure port in the current order; `SessionAssertPort`, `UserReadPort`, `ActivePlanPort`, `SessionRevocationPort` exist | O1, identity contract ("Account deletion saga") | `users.service.ts` deletes 24 foreign models directly (47 records); `auth.service.ts` reads PlanInvite/SharedMember; `contexts.service.ts` reads SharedMember/Provider/WeddingPlan (60/78 total) | ownership baseline | Erasure ports on every table-owning module invoked in the verbatim order inside identity's transaction; identity read ports for contexts; foreign reads routed | identity records 0; account-deletion smoke and auth smokes unchanged | **A** |
| R14B Collaboration internals | Collaboration owns its 5 tables; permission/history/scope ports are the single authority; no foreign Prisma | O1, collaboration contract | sharing.service.ts reads User/Provider/Conversation/ConversationParticipant/WeddingPlan (20 records); permission/history/invite-access read WeddingPlan/User (28/80 total) | ownership baseline | Route through identity/planning/marketplace/messaging ports (`revokeParticipation`, plan access, safe users) | collaboration records 0; sharing-security 38/38, sharing concurrency smokes unchanged | **A** |
| R15 Tasks + Guests | Owner-only Prisma; `listTasksDueBefore`, counters, erasure ports | O1, tasks/guests contracts | tasks.service.ts reads SharedMember/WeddingPlan (6/12); guests has 4 dynamic shapes (4/7) | ownership baseline | Route plan/member reads through ports; make the guests query shapes provable | tasks/guests records 0 | **A** |
| R16 Catalog, Marketplace, Media, Messaging, Notifications | Owner-only Prisma; marketplace read ports; messaging socket auth via identity session port; notifications reminder via tasks/finance ports (C2) | O1, contracts (C2, C6) | marketplace 78/161 (quote scripts, contributor scope, locks read catalog/finance/planning/collaboration models), messaging 28/39 (gateway reads User/RefreshToken; service reads 7 foreign models), notifications 30/79 (reminder scan reads WeddingTask/PaymentSchedule/…), catalog 3/8 and media 1/1 dynamic shapes | ownership baseline | Ports on each owner; gateway → identity session port; reminder scan → tasks/finance ports; catalog/media shapes provable | records 0 per context; provider/quote/conversation/notification smokes and phase-2 concurrency unchanged | **A** |
| R17 Insights + Backoffice | Insights owns no tables and composes over ports; Backoffice mutations are port calls to owners | O1, insights/backoffice contracts | dashboard/timeline read 13 foreign models (36/79); admin services and executor read/write 12 foreign models (67/152) | ownership baseline | Owner read/admin ports (catalog admin, marketplace moderation, messaging moderation, notifications admin, identity user status, planning read) consumed by insights/backoffice | insights/backoffice records 0; admin/dashboard smokes and 101 admin tests unchanged | **A** |
| R18 Strict ownership, delete the baseline | "R8 deletes all baselines"; no hidden baseline | O4, Execution order | ownership baseline exists (385/781) | `backend/architecture/ownership-baseline.json` | After 0/0: run the scanner strict, delete the baseline, make the gate baseline-free | `architecture:ownership` passes with no baseline file; a planted foreign access fails it | **A** |
| R18 (part) scanner provability | The gate must be able to prove zero without a baseline: `unknown-relation-shape` records (83/216) are shapes the static walker cannot resolve (dynamic `where`/`select` objects), not proven foreign access | O4 | the walker resolves only literal objects and const spreads | scanner source | Resolve shapes through the TypeScript type of the argument (inferred object types name every present key) so provable same-owner shapes are not counted; keep fail-closed for genuinely unresolvable shapes | scanner unit tests; 0 unknown records at HEAD | **B** |
| R19 Mobile fate-map remainder | phone wrappers dissolved; `quote_finance_context` under finance; `provider_portal` split from `marketplace` (C9: separate persona); the seven god files split keeping public class names, touched files ≤ 700 lines; route trees per area file; routes/tests unchanged | M6 (explicit), R9 exit criteria | none executed: wrappers present, model in `shared/`, no `features/provider_portal/`, the seven files at 1,110–1,823 lines | file listing | Execute each fate with behavior unchanged; update the R9 strict manifest (frozen root inventory) with the reason | `flutter analyze` 0, `flutter test` 1,164, strict boundaries green, `MOBILE_ROUTES.md` identical, touched files ≤ 700 lines | **A** (all four items are explicit fates of the target's Mobile mission "boundaries, layering inside features, and god-file splits"; the current structure does not achieve them) |
| R20 Final closeout | Every original invariant re-proven in one run; report | Execution order (R10 row), R11 R20 definition | not run after R13–R19 | — | Clean-room run of every gate + adversarial original-spec audit | This mission's final report | **A** |
| Port *names* (`SessionAssertPort` etc.) | "Port names below are binding" | M3 | R3 implemented ports under different token names (`IDENTITY_AUTH_PORT`, `COLLABORATION_PERMISSION_PORT`, …) and R4–R12C, all owner-approved, kept them | 12 `*.port.ts` files | none — the contracts exist under approved names; renaming working ports is ceremony | mapping recorded in the final report | **C** (rename only) — missing ports are covered by R13–R17 rows |
| `infrastructure/` sub-path for every owner's own Prisma calls | M1 anatomy; R11 item 3 | owners query Prisma from their service files | e.g. `tasks/tasks.service.ts` queries `weddingTask` | — | — | **C** — where a context keeps its own persistence code is layering inside the owner, not a cross-module invariant; O1's enforceable content (owner exclusivity) is delivered by R13–R18 and the strict gate. Moving owner queries into `infrastructure/` files changes no boundary. Recorded, not executed. |
| Backend folder DISSOLVE / SPLIT fates (17 legacy roots, service splits) | M4 | legacy roots remain | — | — | — | **C** — same reasoning; the roots are already classified by context in the ownership registry and depcruise; no invariant depends on their path |
| Product decisions (15 unreferenced routes, 11 FK indexes, desktop targets) | not in the spec; O5 forbids removing routes | 2026-09-13 audit | — | — | — | not architecture scope; carried unchanged in the final report |

## 3. The specific remainders, understood

- **Ownership 385/781.** 301 records / 563 occurrences are proven foreign
  accesses (a file of context X queries a model owned by Y) — every one is
  a violation of O1 and must be routed through the owner. 83 / 216 are
  `unknown-relation-shape`: the scanner could not statically resolve a
  dynamic argument, so it fails closed; they are not proven violations.
  1 / 2 is an unresolvable SQL composition. The invariant is O1; the number
  is only its measurement. The end state is a scanner that proves 0 with no
  baseline — by routing the 301 and by making the 84 provable (type-based
  shape resolution) or, where a shape is genuinely dynamic, by writing it
  statically.
- **Pure Finance domain.** O3 requires the invariants (positive amounts,
  `paidAmount ≤ totalAmount`, mandatory category, one reversal per payment,
  schedule policy, allocation policy, category matching) in pure
  `modules/finance/domain/` code. `shared-kernel/money` already holds the
  Money value object; the invariants live in `wedding-costs.service.ts` and
  `money-budget.service.ts`. Minimal complete implementation: extract the
  policies as pure functions/classes, call them from the services, guard
  purity with depcruise and a unit test.
- **Erasure-port saga.** The deletion order in `users.service.ts` is the
  specification; each owner implements `eraseForUser(userId, tx)` over its
  own tables; identity calls them in that order inside its serializable
  transaction. Same behavior, owner-only Prisma.
- **Insights / reminders over ports.** Every foreign query in
  dashboard/timeline/notifications becomes a port method on the owner with
  the same query body; response shapes unchanged.
- **Public/Full split.** Tasks, guests, catalog and backoffice gain public
  modules exactly because R13–R17 create their ports; insights exposes no
  port and needs no public module.
- **Mobile fate-map remainder.** Executed as explicit fates (section 2).

## 4. Execution plan (bounded, no R21)

Order follows the dependency notes of the original design and R11:
ports are created on the owner before their consumers change.

| Step | Work | Files (exact) | Contracts | Tests / gates |
| --- | --- | --- | --- | --- |
| P0 | Scanner: type-based shape resolution for dynamic arguments (B) | `backend/scripts/architecture/ownership-scan.cjs`, `backend/test/architecture-ownership.test.ts` | — | RED: a dynamic same-owner `where` is counted today; GREEN: not counted; foreign relation inside a typed shape still counted |
| P1 | Planning read port (plan core/ownership/status, member of plan) and Planning erasure | `modules/planning/public/planning-read.port.ts`, `planning-read-public.module.ts`, `modules/planning/internal/*` | `PLANNING_READ_PORT` | ownership planning consumers |
| P2 | Identity read/session ports (safe users, session assert/revoke, active plan pointer) and identity erasure orchestration | `modules/identity/public/identity-user-read.port.ts`, `identity-session.port.ts`; `users.service.ts` deletion via erasure ports | `IDENTITY_USER_READ_PORT`, `IDENTITY_SESSION_PORT`, `ACCOUNT_ERASURE_PORTS` | account-deletion smoke, auth smokes |
| P3 | Finance ports (cost creation seam already exists via presenter/service; schedules due, plan money summary, erasure) + pure domain extraction | `modules/finance/public/finance.port.ts`, `modules/finance/domain/*.ts` | `FINANCE_PORT` | money smokes, financial-ledger-concurrency, purity test |
| P4 | Collaboration erasure + member/invite read methods on the existing permission/scope/history ports; collaboration consumers routed | `modules/collaboration/public/*.port.ts`, `internal/*` | existing tokens + `COLLABORATION_ERASURE` | sharing smokes |
| P5 | Tasks, Guests ports (due tasks, counters, erasure) | `modules/tasks/public/*`, `modules/guests/public/*` | `TASKS_READ_PORT`, `GUESTS_READ_PORT` | tasks/guests smokes |
| P6 | Marketplace ports (provider context/cards, quote read, erasure incl. review purge/rating recompute), Messaging (moderation, revoke participation, erasure; gateway → identity session port), Notifications (admin, erasure; reminder scan → tasks/finance ports), Catalog (read + admin), Media (erasure) | per-context `public/*.port.ts` + internal implementations | per-context tokens | marketplace/provider/quote/conversation/notification smokes, phase-2 concurrency |
| P7 | Insights and Backoffice re-expressed over ports | `dashboard/*`, `timeline/*`, `admin/*` | consumers only | dashboard/admin smokes, 101 admin tests |
| P8 | R18: strict ownership gate, delete the baseline, planted-violation probe | `ownership-scan.cjs`, `package.json`, portability probe | — | gate green without baseline; probe RED |
| P9 | R19: mobile fates (wrappers, model move, provider_portal, god-file splits, router split) + R9 manifest update with reason | `mobile/lib/**` | barrels | analyze/test/strict/routes identical |
| P10 | Docs: ARCHITECTURE.md, STATUS, CHANGELOG, DECISIONS, EXECUTION_PLAN, spec amendments (reason in the same change) | docs | — | docs gates |
| P11 | Independent original-spec exit audit + adversarial review + clean room + final report | reports | — | 77+ gates |

Entry gate: baseline above. Exit gate of every step: `npm run check`,
`npm run architecture` (with the ownership count decreasing by exactly the
retired records), focused suites, affected smokes; commit per step.
Rollback boundary: each commit; the mission branch can be reset to
`cd45e435` without touching any other worktree.
