# Current Status

Snapshot date: 2026-08-10

This is the compact current-status source for Aarast. Source code, schema,
generated references, and observed checks override historical plans or
completion reports.

## Repository Baseline

- Repository root: `D:\projects\aarast`.
- Active working branch: `codex/aarast-soft-royal-v2-20260810`.
- Baseline commit: `9393b8e`, equal to `main` and the locally tracked
  `origin/main` at the time the branch was created.
- `main...HEAD` is `0/0`: no branch commit contains the current modernization,
  dynamic-catalog, or Soft Royal work. The complete package remains in the
  working tree by explicit owner request; no commit or push is authorized.
- The previous uncommitted Money/Guests work is preserved separately on
  `codex/snapshot-money-redesign-20260807` at `8c6c026` and in a verified local
  Git bundle. That snapshot is recovery evidence, not release-ready work.
- Existing stashes and alternate worktrees remain untouched pending an explicit
  branch-disposition pass.

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

Current Compose still treats Backend, Admin Web, and Mobile distribution as
separate concerns. The production Compose publishes Backend and Admin Web; it
does not define Flutter web as an additional production service. Mobile store
artifacts remain a separate release path.

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

The Admin dependency fix currently offered by npm is a major React Router
upgrade. It must be migrated and tested; a stale dependency branch must not be
merged blindly.

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

### Full working-tree closure audit — 2026-08-10

- Git truth: `HEAD` and `main` both resolve to `9393b8e`; the audited package is
  a large uncommitted working tree and is not yet a mergeable branch history.
- Backend: TypeScript checks, guarded unit tests, build, Prisma validation, and
  the Phase 0 source guard PASS. The managed reference-catalog smoke applied all
  75 migrations to a disposable database and verified versioned bootstrap,
  groom/bride audiences, and dynamic marketplace/location payloads.
- Admin Web: type-check, Vitest, source-honesty smoke, container-config tests,
  production build, and managed admin-runtime smoke PASS. Runtime coverage
  verified draft/publish/rollback/disable catalog behavior and governorate →
  district → locality administration without exposing private fields.
- Mobile: analysis and all 1134 tests PASS. The debug APK builds, installs over
  the existing app with data preserved, and the final Home plan moment was
  reviewed on the connected Samsung device.
- Documentation: generated route/model/script references are in sync,
  `docs-verify` reports zero errors and warnings, every deleted historical doc
  has an archive counterpart, and `git diff --check` reports no whitespace
  error.
- Current local Compose is not release-ready: `/live` returns `200`, while
  `/ready` returns `503`. Database and Redis are up and the MinIO health endpoint
  is reachable from Backend, but the S3 bucket check fails with
  `InvalidAccessKeyId`; local Backend/MinIO credentials are out of sync. Isolated
  current-source smokes pass. Rebuilding or changing deployment is outside this
  branch audit and remains an operations gate.
- Dependency audit: Backend production dependencies report zero vulnerabilities.
  Admin reports two moderate React Router advisories whose automated fix is the
  breaking v7 upgrade; the current app rejects external, backslash, encoded,
  query, and hash return paths, but dependency remediation remains open. Mobile
  reports 19 lockfile upgrades and six direct constraints behind resolvable
  versions, including major secure-storage and Socket.IO migrations; none were
  upgraded blindly in this closure pass.

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
2026-08-07 source review.

Current strengths include:

- separate application/admin JWT scopes and live server-session checks;
- admin access token in memory and rotating HttpOnly/SameSite refresh cookie;
- global DTO whitelist, unknown-field rejection, and transformation;
- production CORS allowlist behavior and protected Prometheus metrics;
- secure mobile token storage and SQLCipher key handling;
- image ownership, quota, signature, decode, sanitization, and re-encoding;
- fail-closed production configuration for auth and media dependencies.

Open security/release work includes the two Moderate Admin dependency findings,
dependency-by-dependency upgrade review, deployed-environment verification,
physical-device session tests, Sentry privacy/symbolication checks, WhatsApp
OTP acceptance, and recovery/restore evidence for the final release.

## Branch Status

- No divergent feature/remediation branch is approved for direct merge.
- Branches fully contained in `main` are deletion candidates only after checking
  worktree use and preserving recovery references.
- `codex/aarast-full-remediation` remains isolated because it diverges and is
  checked out in another worktree.
- `codex/bride-path-safety-20260725` requires manual comparison of its remaining
  unique patch; do not merge the branch directly.
- `origin/codex/guest-invitation-campaigns` remains quarantined: it is a large,
  stale WIP outside the approved current scope.
- Dependabot branches require current-base recreation or rebase and independent
  compatibility testing.

## Release Judgment

The repository has a green local clean baseline, but the product is not ready
for owner handoff or store/production approval. Documentation consolidation,
design/IA reset, source-quality work, flow-by-flow verification, dependency
remediation, physical-device acceptance, and deployed release evidence remain
required.

Current verdict: needs fixes before approval.

The active priority and acceptance order is defined in
`docs/project/EXECUTION_PLAN.md`.
