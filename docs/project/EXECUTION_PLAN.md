# Modernization Execution Plan

Snapshot date: 2026-08-12

This is the active execution plan for the Aarast modernization. It replaces
implementation assumptions made in historical remediation and premium-roadmap
notes. Product, API, database, privacy, and phase boundaries remain governed by
the current source documents listed in `docs/README.md`.

## Delivery Standard

The goal is a trustworthy, Arabic-first wedding-planning product that can be
handed to its owner with evidence. A screen is not complete because it looks
different, builds, or has a passing isolated widget test. It is complete only
when its product contract, permissions, offline behavior, responsive RTL
layout, error states, and relevant integration tests are verified.

Do not introduce booking confirmation, deposits, payment processing, loans,
credit, financing, AI automation, or open messaging while carrying out this
plan. Quote-scoped conversations and the manual money ledger keep their
existing approved boundaries.

## Baseline And Safety

- Historical implementation base: `codex/aarast-modernization-20260807` was
  created from `main` at `9393b8e` and later removed during the explicit branch
  cleanup after its relevant history was incorporated or preserved.
- The 2026-08-11 closure package is promoted to canonical `main` only through a
  reviewed PR with all required CI jobs green. Exact candidate, merge, image,
  and artifact revisions come from Git and release metadata; this tracked plan
  intentionally does not claim a mutable branch tip as its own source SHA.
- The former WIP snapshot branch has been removed during the explicit branch
  cleanup. Its pre-modernization recovery state remains in the verified local
  Git bundle below; it is not an approved release candidate.
- Verified local bundle: `_ai_backups/aarast-before-modernization-20260807.bundle`.
- No stash exists. The remaining Codex-managed detached worktree and ignored
  recovery artifacts stay untouched unless the owner explicitly authorizes
  their removal.

## Priority Order

### P0 — Baseline Protection — Complete

- Preserve the dirty Money/Guests WIP in a dedicated commit and verified bundle.
- Start from a clean branch equal to `main`.
- Re-run the mobile analysis, full test suite, generated-doc checks, and
  whitespace check on the clean branch.

Acceptance evidence on 2026-08-07:

- `flutter analyze`: PASS.
- `flutter test --no-pub`: PASS, 997 tests.
- `node scripts/docs-sync.mjs --check`: PASS.
- `node scripts/docs-verify.mjs`: PASS.
- `git diff --check`: PASS on the clean branch.

### P1 — Product Truth And Documentation — Complete

1. Reduce active documentation to one source per concern; archive working
   plans, the superseded release/remediation documents, and the retired
   Premium roadmap as historical references. Non-Markdown prototype assets stay
   reference-only until P2 replaces them and captures any required evidence.
2. Replace stale status claims with observed repository, branch, and test facts.
3. Make the current product exclusions, financial contract, deployment split,
   release gates, and external dependencies explicit.
4. Keep generated API/database/route/script references generated; never edit
   their auto-generated sections manually.

Acceptance:

- The documentation map names one active source for each concern.
- No active document mandates the retired Royal/Premium ornamental component
  direction; the active Mobile identity uses semantic burgundy, near-white, and
  restrained champagne roles without restoring that implementation.
- `docs-sync --check`, `docs-verify`, and `git diff --check` pass.
- The obsolete Flutter contract test was recorded for P2 rather than being
  satisfied by restoring retired design language.

### P2 — Design System And Information Architecture Reset — Paused By Owner Direction

The completed P2 checkpoints below remain accepted. Further P2 implementation
is paused while P3 R1 Platform And Shared Kernel is active; this transition
does not reopen or invalidate the accepted P2 evidence.

#### Completed checkpoint — semantic foundation, Mobile core journeys, and smart Home

- Added the shared semantic-token contract for Mobile and Admin, including a
  Mobile contrast gate and shared quiet surface/section primitives.
- Replaced the active Royal plan chrome and the provider-specific glass chrome
  with one labelled plan/provider navigation bar and a contextual add action.
  The contributor workspace remains without owner navigation tabs.
- Added a visible plan-context/location bar, responsive navigation height for
  enlarged text, a scrollable quick-action sheet, and an accessible unread
  count announcement for navigation badges.
- Replaced the old visual contract with a semantic/accessibility contract,
  added reviewed 320px/420px RTL shell Goldens, and removed the obsolete Royal
  shell Goldens.
- Replaced the account-backed and local-guest Home bodies with one responsive
  semantic dashboard. Its next action is resolved from real plan state, money
  remains permission-aware, and no route, API, offline, or authorization
  contract changed.
- Evolved Home into a warm one-screen brief with one solid-burgundy plan
  moment, one deterministic urgent action, three truthful compact signals, one
  expanded permission-aware Money surface, a compact team strip, and a labelled
  non-overlapping creation entry.
- Made the creation entry state-aware across its four real routes, added direct
  contextual actions for overdue tasks, guest completion/replies, and overdue
  payments, and kept unsupported reminder delivery out of the UI. The single
  creation control now floats at the lower RTL side, compacts on downward
  scroll, and leaves the plan/destination header smaller and read-only.
- Added account-scoped secure draft restore/clear behavior to task, guest, cost,
  and quote-request creation; added inline validation, keyboard traversal, and
  a total/paid/remaining review summary for cost creation.
- Reworked provider-detail CTA and image failure/loading states for narrow RTL
  layouts, including explicit 320px behavior coverage.
- Added reviewed real shell-plus-dashboard Goldens at 320px, 420px, and 1000px
  RTL; retired the blank shell-only preview and the obsolete Premium Home Dart
  implementation.
- Preserved all routes, API contracts, auth/session behavior, permissions,
  offline SQLite ownership, provider capability boundaries, and database
  behavior.
- Validation: `flutter analyze` PASS; 966 non-Golden tests PASS; all 42 reviewed
  Goldens PASS; focused provider, contributor, quick-action, visual-contract,
  and real shell-plus-dashboard tests PASS. Release Web and a public-API debug
  APK build PASS.

#### Completed checkpoint — Mobile density, continuous lists, and source guard — 2026-08-09

- Added five screen archetypes and a shared responsive continuous-row contract.
- Replaced Home's equal metric cards with three compact independent signals and
  one larger decision-ready Money surface.
- Reworked Guests, Participants, Notifications, Settings, and More around dense
  white rows, two utility groups, and isolated destructive account actions;
  Tasks remains the reference contextual-action list.
- Kept provider services and quote selection immediate while packages, about,
  and reviews open progressively.
- Replaced the old Premium splash mark with `AarastBrandMark`; removed all
  production gradients and decorative `BoxShadow` implementations and expanded
  the source guard to all of `mobile/lib`.
- Validation: `flutter analyze` PASS; 969 non-Golden tests PASS; 42 serial
  reviewed Goldens PASS; Release Web and public-API debug APK builds PASS.
- Preserved routes, APIs, permissions, auth/session behavior, offline ownership,
  and the deferred Money product flow.

#### Completed checkpoint — Mobile interaction system and Wedding Day Mode — 2026-08-09

- Added one RTL-aware route motion language, shared-element continuity from
  Home metrics into Tasks/Guests, reduced-motion handling, restrained haptics,
  and Undo for reversible contextual actions.
- Reconciled the Home Plan Pulse with real task, guest, provider, and permitted
  money state; added the thin Plan Path signature across Home, Tasks, and
  Guests without adding a second synthetic readiness score.
- Added Focus Mode prompts, progressive detail, live summaries, inline errors,
  keyboard-safe actions, and draft continuity to the primary task, guest, and
  quote forms.
- Reordered provider detail around media, trust/price, services, and quote
  action; kept secondary information progressive and image failure designed.
- Added the permission-aware Wedding Day command route for the seven-day event
  window, backed by real plan/task/provider data and cached-task failure
  continuity. No backend, schema, booking, payment, AI, or messaging contract
  changed.
- Validation: `flutter analyze` PASS; 981 non-Golden tests PASS; all 44 serial
  reviewed Goldens PASS; Release Web and public-API debug APK builds PASS.

The legacy-name cleanup and automated high-risk 320px/420px edge-state gate are
completed in the next checkpoint below. Physical routed review and device
recovery remain separate release evidence.
The Admin shell, dashboard, login, confirmation dialog, data tables, and search
filters are already on the semantic direction; individual Admin feature-page
rewrites remain deferred behind the Mobile priority.

#### Completed checkpoint — Mobile V3 global forms, feedback, and stage context — 2026-08-09

- Removed the remaining Premium/Royal production source names and kept the
  flat-white semantic source guard fail-closed.
- Applied compact decision prompts to every non-auth domain form, expanded
  encrypted account-scoped draft continuity across durable plan, sharing,
  provider, budget, cost, payment, and schedule forms, and kept password/OTP
  input out of persistence.
- Moved full-screen form submits into fixed keyboard-safe action bars and added
  truthful next actions, one restrained success haptic, inline loading, and real
  Undo where the mutation can be reversed.
- Extended deterministic stage context into Tasks, Guests, Money, and Providers
  without changing routes, APIs, permissions, financial privacy, offline queue
  ownership, or the deferred Money product model.
- Split guest filter/summary helpers from the routed guest screen to restore the
  enforced architecture boundary instead of raising its threshold.
- Validation: `flutter analyze` PASS; 997 serial non-Golden tests PASS; all 44
  reviewed serial Goldens PASS; the 73-case 320px/420px, enlarged-text, finance,
  provider, sharing, and contributor gate PASS; Release Web and public-API debug
  APK builds PASS.

Android later reconnected: data-preserving install, root-tab smoke, and cached
Home airplane-mode cold start now PASS. Exhaustive physical secondary routes,
short-height forms, offline mutation/sync recovery, and physical iOS review on
macOS remain release gates; they are not recorded as product PASS.

#### Completed checkpoint — Mobile Soft Royal V2 identity and asymmetric Home — 2026-08-10

- Restored Aarast's restrained near-white, burgundy, and champagne identity through
  V3 semantic roles without restoring Royal/Premium names, gradients, crowns,
  glow, glass, decorative shadows, or local feature palettes.
- Made burgundy the primary action/selection/FAB role, limited decorative gold
  to contrast-safe dark identity surfaces, retained a deeper AA-capable gold
  role for light surfaces, and aligned Android/iOS splash plus Android heads-up
  notification accent with the same identity.
- Replaced equal Home metrics with three independent compact signals and one
  larger permission-aware Money decision surface beneath the solid-burgundy
  plan moment and one next action.
- Validation: `flutter analyze --no-pub` PASS; `flutter test --no-pub` PASS with
  1134/1134 tests (1084 non-Golden plus all 50 reviewed Goldens); focused
  visual/accessibility/native/contrast gates PASS; docs sync/verification PASS;
  debug APK build and data-preserving install to Samsung SM-S938B PASS.
- Physical Home review PASS after the final plan-moment height and stacked
  date/location refinement. Exhaustive physical secondary-route, short-height,
  offline mutation/sync-recovery, and physical iOS review remain release gates.

#### Historical checkpoint — Full working-tree source audit — 2026-08-10

- At that checkpoint, `main...HEAD = 0/0`; no commit or push was created.
- Backend check/test/build/Prisma validation, reference-catalog isolated smoke,
  Admin type-check/test/honesty/build/container/runtime smoke, Mobile analysis
  and 1134 tests, documentation sync/verification, and whitespace checks PASS.
- The reference-catalog and geography migration applied as migration 75 at that
  historical checkpoint. The later history-scope repair is migration 76 and is
  included in the current full and production gates. Draft edits remain private
  until publish, rollback republishes history, disable preserves history, and
  locality changes appear to Mobile only while active.
- At that checkpoint, local Compose `/ready` returned `503` because the media
  bucket check rejected its credentials. This historical result was closed by
  the 2026-08-11 current-source rebuild described below.
- At that checkpoint, Backend dependencies were clean and Admin carried two
  moderate React Router advisories. The tested React Router 7 migration and
  transitive audit cleanup described below close those Admin findings. Mobile
  dependency upgrades remain a separate compatibility pass because
  secure-storage and Socket.IO have major-version changes.

#### Completed checkpoint — Product truth and release hardening — 2026-08-11

- Corrected Marketplace favorite/detail failure states so stale successful data
  remains visible and each failed section offers an honest retry instead of
  presenting a false empty state.
- Bound Push truth end to end: Backend reports configured Firebase capability,
  Mobile requires server and local-device support, and missing capabilities
  fail closed. In-app notifications remain the unconditional supported channel.
- Made blocked offline queue items diagnosable through safe Arabic summaries and
  retry only where the queue contract permits it; no unsafe generic
  discard/edit action was invented.
- Upgraded Admin to React Router `7.18.2`, remediated the transitive `nanoid`
  advisory, and retained passing auth, route, type, test, honesty, container,
  and production-build gates with a zero-finding npm audit.
- Added static Arabic privacy and support routes to the public safety surface,
  kept it script/form-free and fail-closed, and added an immutable public image
  to production/build Compose with the same Git-revision contract.
- Rebuilt the current Backend image and recreated Backend/media initialization
  without deleting data. Local `/live` and `/ready` now return `200`, and
  database, Redis, and media all report `up`.
- Full combined closure PASS: Backend `670` tests (669 passed, one skipped),
  build, Prisma, zero-finding audit, and all `30` isolated smoke packages after
  `76` migrations; Admin
  `96/96`, type/build/route/honesty/container gates and zero-finding audit;
  Mobile analysis, `1150/1150`, reviewed Golden, and public-API debug APK;
  deployment contracts `38/38`, public image/live-route and Compose checks;
  generated docs, links, snapshots, and whitespace checks. The later
  2026-08-11 production receipt in `STATUS.md` separately proves the current
  Backend/Admin/public deployment, all migrations, and backup/restore gate.
  Store approval and physical iOS/complete Android acceptance remain open.

#### Completed Admin web slice — 2026-08-08

- Unified Admin navigation around operational groups, visible breadcrumbs, and
  a responsive accessible drawer.
- Reworked the dashboard around pending work and operational exceptions rather
  than decorative metric walls.
- Rebuilt the login surface without retired crown, burgundy/gold, gradient, or
  premium branding while preserving password + phone OTP, recovery, and admin
  session behavior.
- Added behavioral coverage for the shell, dashboard, and login surface.
- Validation: Admin tests PASS — 92/92; typecheck PASS; build PASS; route
  smoke PASS — 16/16; source-honesty smoke PASS — 12/12.

#### Completed Admin shared-primitives slice — 2026-08-08

- Closed the interrupted `ConfirmDialog` work with stable IDs, Escape and Tab
  handling, focus restoration, pending-dismissal protection, and explicit
  mutation-error feedback.
- Replaced per-render table CSS and hard-coded colors with one semantic-token
  `DataTable`; all 12 current tables now provide captions, scoped column
  headers, and named keyboard-focusable horizontal scroll regions.
- Rebuilt all current Admin search filters around visible labels, named search
  landmarks, and native search inputs while preserving their existing query and
  pagination behavior.
- Validation: Admin tests PASS — 96/96; typecheck PASS; build PASS; route smoke
  PASS — 16/16; source-honesty smoke PASS — 12/12.

1. Establish one semantic design-token contract for Mobile and Admin: canvas,
   surface, raised surface, text, muted text, border, brand, focus, success,
   warning, danger, and disabled.
2. Retire Royal/Premium naming, crowns, ornamental gradients, automatic glow,
   glass, and decorative card APIs. Keep burgundy/near-white/champagne only as
   semantic identity roles with contrast and usage limits.
3. Define shared primitives before page rewrites: app shell, page header,
   section, list row, metric, form field, button, status, empty/error/loading,
   confirmation dialog, and data table.
4. Redesign navigation around the current plan/context and a visible location
   hierarchy so the user can always answer: where am I, what am I viewing, and
   what can I do next?
5. Approve screen-level behavior contracts before visual implementation.

Acceptance:

- No new hard-coded color, radius, shadow, or inline layout token in product
  components unless it represents runtime data such as a chart percentage.
- Every priority flow has 320px/420px RTL, large-text, loading, empty, error,
  offline, permission-denied, and read-only acceptance criteria where relevant.
- Design review includes real routed screens, not only component previews.

### P3 — Source Quality And Architecture — R4 Locally Complete

#### Completed R1 — Platform And Shared Kernel

- R0 governance is closed at immutable candidate
  `94b677b7b8e2219e0db2cbc553fa3d26b4876456`; this revision is the fixed R1
  comparison base.
- By owner decision, R1 continues locally on the same `modular-monolith`
  branch without merging between phases. PR #76 is not pushed or mutated by
  staged local execution.
- The R1 target layout is implemented locally: infrastructure is under
  `platform/`, foundational helpers are under `shared-kernel/`, and the legacy
  infrastructure roots are gone without compatibility facades.
- R1 closed locally on 2026-08-13 after the full Backend/Admin/Mobile/docs
  gates, managed `smoke:all`, independent final source/runtime review, clean
  receipt checkpoints, and the owner's phone application test passed. It is the
  immutable base of the executed R2 candidate.
- At R1 closeout, six exact platform-to-business edges were assigned to R3; R3
  later removed all six. Sharing's direct OTP transport migration remains
  assigned to R6, and the two approved globals remain until R8.
- R1 preserves all routes, errors/Arabic, permissions, transactions, 52
  models, 76 migrations, Mobile/Admin source, and deployment artifacts.

#### R2 — Native Prisma Schema Folder — Locally Complete

- R2 implementation, exhaustive local gates, immutable Docker runtime, the
  owner's corrected R2Local phone checkpoint, and final independent
  source/contract/runtime/receipt sign-off passed on 2026-08-14.
- Immutable `R2_BASE` is the R1 local-closeout commit
  `8ba0db78ac669bd6d17de878b77a4d1e6c5e542d` on the same
  `modular-monolith` branch.
- The verified live source is now exactly 14 `.prisma` files:
  `_base.prisma` plus one file for each of the 13 current model owners, with 52
  models, 41 enums, and all 76 migrations preserved.
- The physical schema organization and required canonical readers/config/Docker
  packaging were implemented without schema semantic, migration, seed, package,
  Backend application, Mobile/Admin, Compose/deploy, route, or product changes.
- Empty migrate diff, normalized DMMF equality, frozen seed/migrations/generated
  docs, exhaustive Backend/Admin/Mobile/docs/smoke/audit gates, immutable Docker
  probe/cutover, and explicit owner PASS are locally green. The initial phone
  attempt used a stale loopback R1 APK and emitted no R2 request; only the
  corrected R2Local APK result is accepted as R2 evidence.
- R2 is the immutable accepted base for completed local R3 execution. Remote CI
  was not run, and no push or merge is claimed.

#### R3 — Strict Nest Boundaries — Locally Complete

- R3 executed from immutable base
  `6b06eb096aca8cc6684d365d16e05d4cd8529898` and closed the initial 3 duplicate
  registrations, 6 platform debts, and 163 retired provider edges across all 13
  business contexts, with zero `forwardRef()`, cycles, or illegal boundaries.
- Exhaustive Backend/Admin/Mobile/docs/schema/audit/smoke gates and independent
  task reviews passed. The final fixed-base scope contains exactly 214 reviewed
  paths and zero unexpected paths.
- The phone gate exposed a pre-existing Mobile session-restore race. The exact
  ApiClient correction was reproduced RED, verified GREEN, and accepted only
  after the owner reached the dashboard and an independent ADB force-stop and
  relaunch restored that dashboard without logout.
- Immutable runtime candidate `dfc5488cf30d4eb36dc2d72c618b2442f34ea058`
  and the R3Local APK passed identity, health, safe-log, and device gates. The
  prior R3 and R2 runtimes remain preserved as rollback artifacts.
- R3 is locally complete and provided the immutable base for completed R4.

#### R4 — Planning/Finance Physical Ownership — Locally Complete

- R4 executed from immutable base
  `502b181a2ce624458fd7eae064f194497ec0151e` and routed Finance's one direct
  `WeddingPlan` budget write through the singleton Planning public write port.
- The caller-owned serializable transaction, input fields, mutation order,
  retry/error behavior, routes, payloads, and response ordering remain unchanged.
  The ownership baseline is exactly 385 records / 781 occurrences after removing
  only the frozen Finance-to-Planning debt.
- Architecture/check/build/tests/audits, affected and aggregate managed smokes,
  schema/docs/frozen-surface checks, immutable Docker probe/cutover, independent
  review, and the owner Money save/reload/force-close checkpoint passed locally.
- Application candidate `536890ccafcabebcd4d095a33c014933d6451fdb` runs as
  `aarast-backend:r4-final-536890cc` with local/LAN live/ready HTTP 200, zero
  restarts, and the stopped R3 artifact preserved for rollback.
- R4 is locally complete. Remote CI was not run; no push, merge, PR mutation, or
  deployment is claimed.

Current working plan:
`docs/superpowers/plans/2026-08-20-modular-monolith-r5-identity-relocation.md`.

R5 starts from immutable local R4 receipt
`9dab73acdc187a4a18d8a675713d8ded40a16d02`. Its approved scope is the exact
44-file Identity source consolidation from `auth`, `users`, `me`, and
`contexts` into `modules/identity`, plus deterministic import, manifest,
dependency-baseline, ownership-baseline, test, smoke, and receipt updates. It
does not change application behavior, schema, model ownership semantics,
Mobile, Admin, deployment, or another business context. Implementation remains
pending the Task 0 planning checkpoint; R6 and later work must not start early.

The completed R4 execution snapshot remains:
`docs/superpowers/plans/2026-08-16-modular-monolith-r4-planning-finance-ownership.md`.

The numbered P3 modernization work below treats locally completed R4 as the
immutable base and the R5 plan above as the current checkpoint; R6 and
later-phase work must not move forward early.

1. Add project-specific lint/quality gates for Backend, Admin, and Flutter.
2. Split oversized services, providers, route definitions, and screens along
   domain boundaries without moving transaction or authorization decisions into
   presentation code.
3. Keep SQLite ownership, secure storage, sync queue, provider marketplace,
   provider dashboard, and admin approval boundaries intact while extracting
   modules.
4. Add focused tests before each extraction and reject compatibility layers
   that preserve obsolete implementations without a real consumer.

Acceptance:

- Each extraction has a bounded responsibility, explicit public API, and tests.
- Existing backend, admin, and mobile suites remain green.
- No migration, API, or permission behavior changes are hidden in refactoring.

### P4 — Flow-by-Flow UI Delivery

Order of work:

1. Authentication, account contexts, onboarding, and shell navigation.
2. Money: budget, categories, costs, payments, schedules, and offline states.
3. Guests and tasks/timeline.
4. Sharing, contributors, privacy, and role-specific workspaces.
5. Provider discovery, quote lifecycle, provider portal, and quote-scoped chat.
6. Admin operations and moderation.

Each flow must first fix information architecture and interaction logic, then
apply visual polish. Golden updates require a reviewed behavior/UX change; they
are never used to hide a regression.

### P5 — Release Acceptance

- Run Backend check/test/smoke suites, Admin tests/typecheck/build/runtime
  smoke, Mobile analysis/full tests, generated-doc checks, and dependency audit.
- Test critical account, money, sharing, provider, chat, logout, and offline
  recovery scenarios on physical Android and iOS devices.
- Complete deployment, backup/restore, metrics, push, WhatsApp OTP, Sentry,
  signing, store metadata, and privacy acceptance gates with the deployed
  immutable release.

## Branch Disposition Rules

- Do not merge a branch merely because it has commits not in `main`.
- Fully contained branches may be deleted only after checking worktree use and
  preserving the recovery reference.
- Divergent remediation and safety branches require a commit-by-commit
  extraction decision.
- The large guest-invitation-campaign branch remains quarantined because it is
  both stale and outside the approved active scope.
- Dependency branches are rebased and tested independently; major upgrades are
  not bulk-merged.

## Current Stop Conditions

Stop and investigate rather than papering over any of the following:

- A Golden changes without an approved interaction or layout reason.
- A budget setup can create allocations above the general budget.
- A UI rewrite weakens privacy, permissions, offline ownership, or session
  isolation.
- A refactor changes a backend transaction/lock order without regression tests.
- A release claim lacks the matching device or deployed-environment evidence.
