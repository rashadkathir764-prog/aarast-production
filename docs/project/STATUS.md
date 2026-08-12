# Current Status

Snapshot date: 2026-08-11

This is the compact current-status source for Aarast. Source code, schema,
generated references, and observed checks override historical plans or
completion reports.

## Repository Baseline

- Repository root: `D:\projects\aarast`.
- Canonical integration branch: `main`. Release-candidate changes are promoted
  through reviewed Git history only after the required CI jobs pass.
- Resolve the exact checked-out revision with `git rev-parse HEAD`. Deployed
  images and release artifacts must carry that immutable revision; this tracked
  document intentionally avoids a self-referential mutable HEAD claim.
- The pre-modernization state remains recoverable from the verified local Git
  bundle `_ai_backups/aarast-before-modernization-20260807.bundle`. The former
  snapshot branch has been removed during the explicit branch cleanup and is
  not a release candidate.
- No stash exists. One Codex-managed detached worktree remains untouched because
  deleting worktrees or ignored backups was not part of the authorized cleanup.

## Modular Monolith R0 Local Verification Receipt - 2026-08-12

R0 governance was verified locally on branch `modular-monolith` against the
fixed base revision `feafe3db0053d6c66d5f46b56ff9a512861dfbad`. This receipt
records local evidence only. The authoritative candidate revision and remote
CI result must come from immutable pull-request/workflow metadata; this tracked
receipt intentionally makes no claim about its own mutable branch tip or the
current remote CI state.

The exact fixed-base diff contains these 30 paths:

- `.github/workflows/ci.yml`
- `AGENTS.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`
- `backend/.dependency-cruiser-known-violations.json`
- `backend/.dependency-cruiser.cjs`
- `backend/architecture/ownership-baseline.json`
- `backend/architecture/ownership-registry.json`
- `backend/package-lock.json`
- `backend/package.json`
- `backend/scripts/architecture/ownership-scan.cjs`
- `backend/scripts/architecture/ports-scan.cjs`
- `backend/test/architecture-dependencies.test.ts`
- `backend/test/architecture-ownership.test.ts`
- `backend/test/architecture-ports.test.ts`
- `docs/README.md`
- `docs/SCRIPTS.md`
- `docs/backend/README.md`
- `docs/frontend/MOBILE_ARCHITECTURE.md`
- `docs/project/DECISIONS.md`
- `docs/project/EXECUTION_PLAN.md`
- `docs/project/STATUS.md`
- `docs/qa/README.md`
- `docs/superpowers/plans/2026-08-11-modular-monolith-r0-governance.md`
- `mobile/lib/features/welcome_gateway/widgets/aarast_path_card.dart`
- `scripts/architecture/mobile-boundaries-baseline.json`
- `scripts/check-mobile-boundaries.mjs`
- `scripts/check-mobile-boundaries.test.mjs`
- `scripts/check-r0-scope.mjs`
- `scripts/check-r0-scope.test.mjs`

The only application-source change is the owner-approved one-line local import
URI correction in
`mobile/lib/features/welcome_gateway/widgets/aarast_path_card.dart`. Its
content is unchanged from repair commit `464a23e0`. Backend application source,
schema, all 76 migrations, and routes; Mobile tests, integration tests, and
every other Mobile source file; Admin application source; deployment and
Compose artifacts; source locations; and business logic were untouched. No
module, port, repository, barrel, migration, route, endpoint, or product
behavior was added by R0.

The final review remediation was completed without widening the 30-path scope.
Commits `003474d9`, `302aec72`, `8de041ce`, `d8788ed8`, `8d0e8116`, and
`182ade08` close Backend ownership/ports provenance, alias, path-redaction,
non-reflective diagnostic, and atomic scan-result validation gaps. Commit
`ff35ea73` makes Mobile boundary parsing fail closed around canonical junction
identity and nested Dart interpolation. Commit `7f4cd70` reconciles the R0
plan's protected-source exception, documents the official local gates, and
records the distinct PR-head versus synthetic-merge CI semantics. These are
gate hardening and documentation corrections only; they add no runtime product
behavior.

Observed governance baselines:

- dependency-cruiser `18.1.0`: 269 unique known dependency violations. The live
  graph contains 303 modules and 1,307 dependencies, with no new violation.
- Prisma ownership: 386 keys and 782 occurrences. By reason this is 302/564
  foreign-model keys/occurrences, 83/216 unknown-relation-shape, and 1/2
  unknown-sql-composition. By source this is 183/303 delegate, 163/425
  relation, and 40/54 SQL keys/occurrences.
- Mobile boundaries: 269 keys/occurrences, comprising 62 core-to-feature and
  207 direct-cross-feature records. The live scan reported zero errors.
- Ports/Nest: zero `forwardRef()`, exactly two approved globals, zero illegal
  future imports, and zero Nest module cycles.
- Source counts: 52 Prisma models and 76 committed migration directories.

Local verification evidence:

| Area | Exact command | Result |
| --- | --- | --- |
| Protected surface | Task 7 Step 1 and Step 7 exact PowerShell gates using `git diff --name-status --no-renames --diff-filter=ACMRDTUXB`, `git diff --exit-code 464a23e0..HEAD -- mobile/lib/features/welcome_gateway/widgets/aarast_path_card.dart`, protected-path `git status`, and `node .\scripts\check-r0-scope.mjs --check` | PASS before and after tests: exactly the approved Mobile `M` path, repair unchanged, protected worktree clean, no unexpected R0 path |
| Backend | `npm run architecture` | PASS: imports, ownership, and ports |
| Backend | `npm run check` | PASS |
| Backend | `npm run build` | PASS |
| Backend | `npm test` | PASS: 737 total, 736 passed, 1 intentionally skipped |
| Backend | `npx prisma validate` | PASS with a process-scoped non-secret local validation URL; no database connection was used |
| Backend | `npm audit --audit-level=high` | PASS: 0 vulnerabilities |
| Backend | `npm audit --omit=dev` | PASS: 0 vulnerabilities |
| Admin | `npm run typecheck` | PASS |
| Admin | `npm test -- --run` | PASS: 96/96 |
| Admin | `npm run build` | PASS |
| Admin | `npm run smoke:honesty` | PASS: 12/12 |
| Admin | `npm run smoke:routes` | PASS: 16/16 |
| Admin | `npm run test:container-config` | PASS: 3/3 |
| Mobile architecture | `node --test .\scripts\check-mobile-boundaries.test.mjs` | PASS: 152/152 |
| Mobile architecture | `node .\scripts\check-mobile-boundaries.mjs --check-baseline` | PASS: 269 current records |
| Mobile | `flutter analyze --no-pub` | PASS: no issues |
| Mobile | `flutter test --no-pub` | PASS: 1,151/1,151, including the repository's current Golden behavior |
| Docs | `node .\scripts\docs-sync.mjs --check` | PASS: drift=0, errors=0 |
| Docs | `node .\scripts\docs-verify.mjs` | PASS: errors=0, warnings=0 |
| Repository | `git diff --check` | PASS |
| Source counts | `Select-String .\backend\prisma\schema.prisma -Pattern '^model\s+'` and `Get-ChildItem .\backend\prisma\migrations -Directory` | PASS: 52 models, 76 migrations |

The first bare `npx prisma validate` invocation reported Prisma `P1012` because
this isolated worktree has no `.env` and `DATABASE_URL` was unset. Inspection
confirmed that `prisma.config.ts` only loads `.env` when present. The same
validation then passed with a process-scoped, non-secret local PostgreSQL URL;
the value was not persisted and Prisma validation made no database connection.
Backend tests also emitted the existing Windows `DEP0190` fixture warning and
intentional warning/error logs. Admin's ErrorBoundary test printed its expected
`render failure`. Flutter printed existing desktop default-plugin-package
warnings while the analyzer and all 1,151 tests passed. These diagnostics were
not suppressed.

No separate local HTTP/database smoke run was required for R0: the only source
repair is the approved local Dart import URI correction, the full Mobile suite
passed, and R0 changed no Backend runtime source, schema, migration, route,
Admin source, deployment artifact, source location, or business logic. Remote
closure still requires the fixed-base `r0-scope` job to pass on the exact
immutable PR-head revision and every other CI job to pass on the corresponding
synthetic merge candidate for that pull request. This receipt does not claim
the current remote state of either Git object.

## Product Position

Aarast is an Arabic-first, Yemen-focused wedding planning product centered on
a Wedding Financial OS. The current product covers planning, tasks, guests,
sharing, provider references, quote leads, quote-scoped conversations, and
administration.

The current scope does not include confirmed bookings, deposits, payment
processing, provider settlements, loans, credit, financing, production AI, or
open unsolicited messaging. Accepting a provider offer creates one idempotent
`WeddingCost`; it does not create a payment, payment schedule, task, deposit,
or booking.

Financial data remains private by default. `canViewMoney` controls reads and
`canManageMoney` controls writes. Shared members must not receive hidden money
values as zero-valued substitutes.

## Current Stack

- Backend: NestJS 11, TypeScript strict mode, Prisma 6, PostgreSQL, Redis,
  Socket.IO, MinIO/S3-compatible media, and optional Sentry.
- Mobile: Flutter, Provider, go_router, dio, SQLCipher-backed SQLite, secure OS
  storage, Socket.IO, Firebase Messaging, and optional Sentry.
- Admin: React 18, Vite, strict TypeScript, Vitest, and React Router.
- Deployment: local Docker Compose plus the current production-oriented
  Dokploy Compose under `deploy/dokploy/`.

Current Compose still treats Backend, Admin Web, the static public safety
surface, and Mobile distribution as separate concerns. Production Compose
defines Backend on host port `8093`, Admin Web on `8094`, and the immutable
public invite/privacy/support site on `8095`. It does not define Flutter web as
an additional production service. Mobile store artifacts remain a separate
release path.

## Implemented Core

- Verified-phone registration, password/OTP login, password recovery, separate
  application/admin session scopes, rotating refresh sessions, and durable
  login throttling.
- Wedding plans, account contexts, onboarding, dashboard, settings, and
  account/session teardown.
- General budget, categories, `WeddingCost`, append-only `CostPayment`, and
  non-reserving `PaymentSchedule` reminders.
- Tasks, timeline, guests/groups, notifications, sharing, invitation consent,
  roles, permissions, contributor isolation, and immutable contribution
  history.
- Provider catalog, favorites, reviews, quote requests/offers, provider portal,
  admin approval/catalog operations, and quote-scoped conversations.
- Versioned managed catalogs with draft/publish/rollback, groom/bride and
  customer/provider audiences, Admin management, public bootstrap versioning,
  and Mobile offline cache. Money starter categories consume the published
  catalog with a bundled safe fallback.
- Admin-managed Yemen geography through governorate, district, and typed
  area/isolation/neighborhood/zone rows. Mobile keeps the enforced geographic
  order, offers remote locality suggestions, and preserves manual entry.
- Authenticated real-time chat, unread/read state, mute/block/report controls,
  private media signing, media ownership tickets, quotas, sanitization, and
  abandoned-upload cleanup.
- SQLCipher cache and selected offline replay with user/plan ownership and
  session-generation isolation.
- Redis-assisted throttling/realtime scaling, request correlation, protected
  metrics, structured logs, outbox delivery, and readiness checks.

## Verified Local Baseline — 2026-08-07

The following commands were run against the clean baseline or against areas
unchanged by the preserved Mobile-only WIP:

| Area | Command | Result |
| --- | --- | --- |
| Backend | `npm run check` | PASS |
| Backend | `npm test` | PASS — 655 tests, 654 passed, 1 skipped |
| Admin | `npm run typecheck` | PASS |
| Admin | `npm test` | PASS — 92/92 |
| Admin | `npm run build` | PASS |
| Mobile | `flutter analyze` | PASS — no issues |
| Mobile | `flutter test --no-pub` | PASS — 997 tests |
| Docs | `node scripts/docs-sync.mjs --check` | PASS |
| Docs | `node scripts/docs-verify.mjs` | PASS |
| Repository | `git diff --check` | PASS on the clean branch |
| Backend dependencies | `npm audit --omit=dev` | PASS — zero findings |
| Admin dependencies | `npm audit --omit=dev` | NEEDS FIX — two Moderate React Router findings |

This historical baseline predates the React Router 7 remediation recorded in
the 2026-08-11 closure below. At this checkpoint the offered npm fix was a major
upgrade and was intentionally not merged without migration coverage.

## P2 Modernization Checkpoint — 2026-08-08

The first Mobile navigation and Home slices are complete, but P2 is not
complete. Mobile and Admin now expose the shared semantic-token vocabulary,
with automated contrast coverage for the Mobile values. The first shared
Mobile primitives include quiet surfaces/sections and an accessible pressable
selection state.

- Plan and provider shells now use one plain, labelled navigation bar and one
  contextual add action. The migrated chrome has no glass, blur, ornamental
  gradient, automatic glow, crown, or rotated floating action button.
- The shell now keeps the current plan name and active destination visible in a
  smaller semantic context bar. Its navigation height adapts to enlarged text,
  labels remain available at 320px RTL, and the quick-action sheet scrolls on
  short viewports instead of overflowing.
- The provider home action now says `عرض الطلبات`; this keeps the visible
  navigation destination `الطلبات` unambiguous to assistive technology.
- Account-backed and local-guest Home now render through one semantic dashboard
  composition. It exposes the plan moment, one deterministic next action,
  truthful task/guest/provider counts, permission-aware money, setup progress,
  and plan-team state without changing data or route ownership.
- The reviewed Home direction is now a warm one-screen brief: one compact solid
  burgundy plan moment, one deterministic urgent action, three independent
  truth signals, one larger permission-aware Money surface, and a compact team
  strip. It avoids repeated dashboard facts and keeps the primary brief visible
  without a long phone scroll.
- The visible `+ إضافة` control now opens one labelled creation sheet for real
  task, guest, cost, and quote routes. Urgency wins first and the last useful
  action in the running session provides a secondary ordering signal. It now
  floats at the lower RTL side above navigation, becomes contextual on task,
  guest, and money roots, and compacts while scrolling down rather than taking
  space from the location header.
- Overdue tasks, incomplete/pending guests, and overdue payments expose direct
  contextual actions. Guest reply updates are backed by the existing status
  mutation; no unsupported reminder-delivery action is presented.
- Task, guest, cost, and quote-request creation now restore account-scoped
  drafts from secure storage, clear them after successful submit, and remove
  them on account teardown. The cost form adds an explicit total/paid/remaining
  confirmation summary without a blocking dialog.
- Provider details now keep the quote CTA labelled during loading/disabled
  states and render compact, explicit gallery loading/failure states instead
  of large blank image regions.
- Three real shell-plus-dashboard Goldens were generated only after behavior
  tests passed and were manually reviewed at 320px, 420px, and 1000px RTL. The
  former blank shell-only preview is no longer an active test.
- This slice did not change APIs, routes, auth/session behavior, permissions,
  offline SQLite ownership, database schema, provider capability boundaries, or
  contributor isolation.
- The Admin shell, dashboard, and login now use the same semantic direction:
  grouped navigation, visible location, operational priority, quiet surfaces,
  and one clear primary action. The Login migration retains the existing
  password + phone OTP, recovery, and session contracts.
- The migrated Login surface has no crown, burgundy/gold panel, ornamental
  gradient, or premium button. It was reviewed at wide desktop, 760px tablet,
  and 390px phone widths without horizontal overflow.
- The shared confirmation dialog now has verified Escape, focus containment and
  restoration, pending-dismissal protection, and mutation-error behavior. All
  12 current Admin tables use one labelled token-based responsive primitive,
  and all current search filters expose visible labels and named search
  landmarks without changing their backend queries.

Observed validation for this checkpoint:

| Area | Command | Result |
| --- | --- | --- |
| Mobile | `flutter analyze` | PASS — no issues |
| Mobile | `flutter test --exclude-tags golden` | PASS — 966 tests |
| Mobile | `flutter test --tags golden` | PASS — 42 reviewed Goldens, including 320px/420px/1000px RTL Home |
| Mobile | plan/provider navigation, contributor isolation, semantic-token and visual-contract tests | PASS |
| Mobile | `flutter build web --release` with the public HTTPS API origin | PASS |
| Mobile | `flutter build apk --debug` with the public HTTPS API origin | PASS |
| Admin | `npm test -- --run` | PASS — 96/96 |
| Admin | `npm run typecheck` and `npm run build` | PASS |
| Admin | `npm run smoke:routes` | PASS — 16/16 |
| Admin | `npm run smoke:honesty` | PASS — 12/12 |

### Mobile V3 density and source guard — 2026-08-09

- Home metrics are one operable 2x2 surface; the dashboard no longer reads as
  four unrelated cards.
- Guests, tasks, participants, notifications, settings, and More use the V3
  density/list hierarchy. Status and metadata stack safely at 320px, and
  secondary mutations remain in overflow or a dedicated account-action sheet.
- Provider details expose services first and move packages, provider detail,
  and reviews behind one explicit progressive disclosure.
- The old Premium splash mark was replaced by the flat `AarastBrandMark`.
  Production Dart now contains no gradient implementation or decorative
  `BoxShadow`; the visual-contract test scans all of `mobile/lib`.
- Mobile verification for this branch: `flutter analyze` PASS; 969/969
  non-Golden tests PASS; 42/42 serial reviewed Goldens PASS; Release Web and a
  public-API debug APK build PASS.
- This checkpoint did not change routes, APIs, auth/session behavior,
  permissions, database schema, or offline ownership. Money feature redesign
  remains intentionally deferred; only the shared flat-white canvas applies
  to it.

### Mobile V3 interaction and Wedding Day checkpoint — 2026-08-09

- Home now resolves one deterministic Plan Pulse from real task, guest,
  provider, and money attention. Tasks and Guests share a thin Plan Path
  signature and quiet shared-element navigation from their Home metrics.
- The floating creation control supports a labelled action sheet, session-last
  long press, contextual ordering, scroll compaction, and permission-aware
  absence. Reversible task/guest changes use unified haptics, feedback, and
  Undo; list gestures reveal the real contextual action without auto-deleting.
- Task, guest, and quote forms use Focus Mode with one opening decision,
  progressive detail, live summary, draft continuity, inline validation, and a
  keyboard-safe action area.
- Provider detail now orders identity, media, trust/price, services, and quote
  action before secondary detail. Broken media has an explicit designed state.
- Added `/wedding-plans/:id/wedding-day`, visible from Home only in the seven
  days before the event through the day after. It requires plan-view access and
  uses real plan/task/provider data with cached-task failure continuity; it
  introduces no API, schema, booking, payment, AI, or messaging contract.
- Verification: `flutter analyze` PASS; 981/981 non-Golden tests PASS; 44/44
  reviewed serial Goldens PASS; Release Web and public-API debug APK builds
  PASS.
- Physical Android/iOS acceptance and exhaustive routed edge-state review
  remain release gates. Money product redesign remains deferred.

### Mobile V3 global completion checkpoint — 2026-08-09

- Retired `Premium`/`Royal` production class, file, and token vocabulary from
  Mobile and extended the source contract so the legacy visual language cannot
  return through a newly routed screen.
- Every non-auth domain form is decision-led with a compact Focus prompt.
  Durable task, guest, quote, plan, sharing, provider, budget, cost, payment,
  and schedule forms restore encrypted account-scoped drafts and keep their
  primary action fixed above the keyboard. Password and OTP forms remain
  intentionally ephemeral and never persist credentials.
- Success feedback now uses one restrained haptic and non-blocking receipt.
  Reversible task, guest, and saved-provider changes expose a real Undo; no
  reminder, message, or delivery action is shown without a working contract.
- The deterministic wedding-stage engine now provides compact, offline-safe
  context on Tasks, Guests, Money, and Providers in addition to Home and plan
  chrome. It changes priority, not navigation or invented readiness. In the
  final month, real provider decisions such as open offers and conversations
  are ordered before discovery.
- `guest_list_screen.dart` was split at the independent filtering/summary
  boundary so the routed screen remains below the enforced 1,000-line limit.
- Verification on this working tree: `flutter analyze` PASS; 997/997 serial
  non-Golden tests PASS; 44/44 reviewed serial Goldens PASS; the focused
  320px/420px, 1.3x/2.0x, finance, provider, sharing, and contributor gate PASS
  (73/73); Release Web and public-API debug APK builds PASS.
- Installation of this latest APK and physical offline recovery are BLOCKED in
  this checkpoint because the previously available Android device disconnected
  from ADB. Physical iOS remains BLOCKED on the available Windows host.

### Mobile Soft Royal V2 identity checkpoint — 2026-08-10

- Mobile V3 now resolves one warm identity from semantic roles: near-white
  canvas, white paper, deep burgundy brand/actions, readable deep-gold accents,
  decorative champagne only on dark identity surfaces, and unchanged semantic
  success/warning/danger/information colors.
- Home now uses one solid-burgundy plan moment, one next decision, three
  independent compact truth signals, one expanded permission-aware Money
  surface, and the compact team strip. The layout preserves real data and does
  not restore gradients, glow, crowns, decorative shadows, or Royal/Premium
  compatibility names.
- Primary actions, selected controls, plan-level floating creation, native
  splash, and Android notification accent now share the burgundy identity.
  Forms, lists, providers, Money, feedback, and empty/error states keep their
  existing contracts and use semantic status color only where it adds meaning.
- Verification on this working tree: `flutter analyze --no-pub` PASS;
  `flutter test --no-pub` PASS with 1134/1134 total tests (1084 non-Golden plus
  50 reviewed Goldens); token contrast, native brand, visual source guard,
  accessibility, and responsive boundary tests PASS; docs sync and verification
  PASS; debug APK build PASS.
- The debug APK was installed with data-preserving `adb install -r` and the
  routed Home surface was physically reviewed on Samsung SM-S938B while the app
  held focus. The final plan moment uses a 146-176px responsive height range,
  keeps the wedding date above the location, and remains overflow-free at
  320px. Exhaustive physical secondary-route, short-height, mutation, and
  sync-recovery review remains OPEN. Physical iOS remains BLOCKED on the
  available Windows host.

### Product-truth and release-hardening checkpoint — 2026-08-11

- Provenance truth: the candidate must be committed, reviewed, green in CI, and
  bound to one immutable merge revision before deployment. The release receipt
  records that revision rather than freezing a stale branch tip in this file.
- Backend now reports push capability from the configured Firebase runtime,
  distinguishes it from per-user device registration, and suppresses expected
  `GET /ready` probe failures from error/Sentry reporting while preserving
  reporting for other server errors.
- Local Compose Backend was rebuilt and recreated without deleting data. The
  container is healthy; `/live` and `/ready` both return `200`, with database,
  Redis, and media all reported `up`.
- Admin Web now runs React Router `7.18.2`; the complete npm audit reports zero
  findings. Existing auth/return-path behavior, 96 tests, type-check, route and
  honesty smokes, container-config test, and production build pass.
- Mobile Marketplace failures no longer masquerade as empty data, blocked
  offline operations expose safe Arabic diagnostics and valid retry actions,
  and push availability requires both server support and a locally configured
  Firebase gateway. Missing capability data fails closed.
- The static public surface now serves actionable Arabic `/privacy` and
  `/support` pages alongside invitation links, with no scripts or forms and
  fail-closed unknown routes. Production Compose uses an immutable image ID and
  the build candidate is stamped with the same Git revision as Backend/Admin.
- Combined closure PASS: Backend `670` tests (669 passed, one skipped), build,
  Prisma validation, zero-finding npm audit, and all `30` managed smoke packages
  after `76` migrations; Admin `96/96`, type-check/build, routes `16/16`,
  honesty `12/12`, container `3/3`, and zero-finding full audit; Mobile analysis,
  `1150/1150`, reviewed Golden, and public-API debug APK; deployment contracts
  `38/38`, public Docker build/live routes, Compose validation; docs sync and
  verification with zero drift/errors/warnings; and `git diff --check` PASS.

## Account-deletion production correction - 2026-08-11

- A physical Android report exposed one dual-identity defect in the deployed
  revision: an administrator enrolled in the wedding application was projected
  correctly as an application user at login, but `DELETE /api/v1/users/me`
  re-read the shared database `role=ADMIN` and returned `403`. The durable
  idempotency reservation then appeared `PENDING`, and an immediate Mobile
  replay could surface `503` while the first reservation was still live.
- Deployed source corrects the realm boundary. Ordinary users/providers still
  delete the complete User graph. A dual administrator/application identity
  deletes only its app credential/profile/data/media, push registration,
  application OTP/idempotency rows and `APPLICATION` sessions; the admin
  password/profile/avatar, challenges, audit links/idempotency rows and
  `ADMIN` sessions remain. Flutter no longer replays DELETE while status is
  `PENDING` and shows a truthful account-deletion verification state.
- Corrective source evidence: Backend full suite `671` total (`670` passed,
  one intentionally skipped), Backend type/seed checks, 30 focused deletion /
  recovery / media tests, managed isolated account-deletion smoke after all 76
  migrations, Flutter analysis, 8 focused session-transition tests, and the
  complete `1151/1151` Flutter suite all PASS. Documentation/public-site and
  final diff/secret checks are recorded by the change receipt.
- PR `#74` passed all eight GitHub checks and application revision
  `959c47b756d0bebc3e4e4fda5f81ae3349d05e62` is deployed. The affected
  physical-device deletion path and administrator-browser survival check remain
  native acceptance gates.

## Production Deployment Receipt - 2026-08-11

- Application revision `959c47b756d0bebc3e4e4fda5f81ae3349d05e62` is deployed
  through Dokploy. Backend, Admin Web, and the public static site are healthy,
  use immutable image IDs, report the same full revision label, and have zero
  restarts and no OOM termination in the acceptance snapshot.
- A fresh pre-deployment PostgreSQL custom-format backup is retained at the
  production host with SHA-256
  `1c327dab578ee8879a2dd845f37d8d736dc5e76ad600bfbe3089294d55ff6c82`.
  Its catalog, checksum, full isolated restore, all `76` migrations, second
  idempotent migration pass, schema checks, and relational postconditions PASS
  against the exact deployed Backend image.
- Production migration status is current. All `16` live wedding plans have one
  linked contributor-history scope; there are zero missing scopes, lifecycle
  mismatches, missing contributor tenures, or unfinished migrations.
- External HTTPS acceptance PASS for Backend `/live` and `/ready`, Admin
  `/login`, and the allowlisted public `/privacy`, `/support`, participant
  invite, and Android `assetlinks.json` routes. Unknown public routes and the
  intentionally unavailable Apple association return `404`.
- The managed catalog bootstrap is live with 55 money items, 39 provider
  categories, 7 cities, and 22 governorates; exact-version replay is unchanged.

## Current Quality Debt

### Design And UX

The implementation does not yet close every release gate for the 2026-08
design-system reset:

- Production Mobile no longer contains the retired Royal/Premium class, file,
  token, gradient, glow, or decorative-shadow vocabulary. Source and visual
  contract tests now guard that boundary.
- Admin feature pages still mix one large legacy stylesheet with page/component
  inline styles, hard-coded colors, and local responsive grids. The shell,
  dashboard, and login surface have been migrated and are not a claim of
  repository-wide compliance.
- Existing visual contract tests enforce wrappers and primitives but do not
  prove navigation clarity, content hierarchy, accessibility, or usability.
- The preserved Money starter WIP can produce suggested allocations whose
  percentages exceed 100%; it must not be restored or merged without fixing
  the product logic and tests.

The active target contract is `docs/frontend/DESIGN_SYSTEM.md`.

### Maintainability

Several Backend services and Mobile screens/providers exceed 1,000 lines.
Notable examples include sharing, auth, notifications, wedding costs, provider
dashboard, invitation decisions, finance API, marketplace provider state, and
the mobile router.

Backend and Admin currently have strict TypeScript checks but no project ESLint
configuration. Flutter uses the default `flutter_lints` set without additional
architecture rules. Refactoring must preserve transaction lock order,
authorization decisions, session isolation, and offline ownership.

### Documentation

Historical implementation plans, the former Premium roadmap, and
`docs/superpowers/` working notes are preserved under
`docs/archive/2026-08-modernization-consolidation/`. The remaining
non-Markdown prototype assets are reference-only until the P2 design migration
replaces them. The obsolete Flutter documentation assertions that mandated the
Premium/Royal identity were replaced at the start of P2; the active contract
now verifies the semantic system and keeps the retired roadmap archived.

## Security Status

No confirmed Critical or High application vulnerability was found during the
latest repository security review. Backend and Admin npm audits currently
report zero findings.

Current strengths include:

- separate application/admin JWT scopes and live server-session checks;
- admin access token in memory and rotating HttpOnly/SameSite refresh cookie;
- global DTO whitelist, unknown-field rejection, and transformation;
- production CORS allowlist behavior and protected Prometheus metrics;
- secure mobile token storage and SQLCipher key handling;
- image ownership, quota, signature, decode, sanitization, and re-encoding;
- fail-closed production configuration for auth and media dependencies.

Open security/release work includes dependency-by-dependency Mobile upgrade
review, physical-device session and push delivery tests, Sentry
privacy/symbolication checks, WhatsApp OTP acceptance, a non-empty protected
metrics token plus an operated monitoring stack, real Apple Team/signing
configuration, and store evidence. Production backup/restore and deployed
Backend/Admin/public acceptance are complete as recorded above.

## Branch Status

- `main` is the canonical local and remote integration branch. Temporary
  release branches are removed only after a verified merge; use `git branch`
  and `git branch -r` for the exact live inventory.
- Fully merged remote remediation branches were removed during the explicit
  branch cleanup. `main` remains the default branch.
- `origin/codex/guest-invitation-campaigns` remains preserved and quarantined:
  it contains a large unique WIP commit outside the approved current scope.
- Open Dependabot branches remain because each is tied to an open dependency PR
  and requires independent compatibility testing; their automated count may
  change at any time, so they are not treated as disposable branches.

## Release Judgment

The Backend, Admin Web, public static site, database migrations, and production
backup/restore gate are deployed and accepted at application revision
`959c47b756d0bebc3e4e4fda5f81ae3349d05e62`. Production operations still have
explicit notes: `METRICS_TOKEN` and `SENTRY_DSN` are not configured, and no
Prometheus/Grafana/Alertmanager stack is running.

Current verdict: source, local-runtime hardening, and the current web/API
production deployment PASS with the operational notes above. Mobile store
release remains BLOCKED by physical-device OTP/Push/session acceptance, live
Sentry symbolication, repeatable store AAB signing/upload, iOS/macOS evidence,
store assets/approval, and the Apple association identity.

The active priority and acceptance order is defined in
`docs/project/EXECUTION_PLAN.md`.
