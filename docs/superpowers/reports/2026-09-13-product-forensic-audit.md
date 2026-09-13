# Product Forensic Audit

**Date:** 2026-09-13
**Tree:** branch `recovery/r12c-t5-takeover-20260913`, commits through
`ab840700` (Phase J remediation included; see section 9).
**Reviewer:** the implementing agent (same-agent; no independent reviewer in
this session).

## 1. Inventory and coverage (I1)

| Area | Files | Lines | Automated forensic passes (100% of files) | Targeted manual reads |
| --- | ---: | ---: | --- | --- |
| `backend/src` | 320 | 44,183 | tsc strict (0); dependency-cruiser 353/1,421/0; ownership scan 385/781 (fails closed without the generated client); ports/R3/R5/R6/R7/R8/R12A–C closed gates; AST route table (58 controllers, 237 routes, guard and throttle metadata); AST catch-clause audit; AST transaction-bypass audit (`this.prisma` inside `$transaction`/`runRetryableTransaction` callbacks: 0); raw SQL inventory (14 sites; 2 `Unsafe`, both parameterized `$1..$4` or constant `SELECT 1`); floating-promise audit (0 un-awaited promise statements); `Math.random` for tokens (0); sensitive-value logging (2 hits, both benign counts/warnings); DTO validation coverage (85 files, 100 classes, 469 properties, 0 unvalidated); TODO/FIXME/HACK (0); test-without-assertion scan (0 after helper resolution); npm audit 0/0 | `main.ts`, `cors-options.ts`, `metrics.controller.ts`, `list-query.dto.ts`, `auth.service.ts` (OTP issue, hashing, invite OTP), `otp-dispatch-quota.service.ts`, `invite-access.service.ts`, `sharing.controller.ts`, `auth.controller.ts` (throttles), `media-upload-policy.ts`, `media-storage.service.ts` (verification), `money-summary.service.ts`, `dashboard.service.ts`, `dashboard-home-queries.ts`, `dashboard-summary.presenter.ts`, `conversations.gateway.ts` (socket auth), `users.service.ts` (deletion order), `marketplace.controller.ts`, `catalogs.controller.ts` |
| `backend/prisma` | 92 (14 schema files, 76 migrations, seed) | — | `prisma validate`; `prisma format --check`; migrations replayed on an isolated database vs the split schema (`migrate diff --exit-code`, new managed package); referential-action inventory (71 relations: 36 Cascade, 20 Restrict, 27 SetNull, 3 defaults reviewed); FK-index inventory | `collaboration.prisma`, `_base.prisma`, migration `20260802090000` |
| `backend/test`, `backend/scripts` | 127 + 88 | — | full suite 1,482/1,454/0/28-declared; artifact-guard cleanliness; temp-root leak audit; skipped-test audit; scope-fence/dead-tool audit | governance suites (Phase H) |
| `admin-web/src` | 89 | 13,030 | tsc strict (0); vitest 101/101 (20 files); admin boundary scan strict 0/0/0/0; contract tests 35/35; `dangerouslySetInnerHTML` 0; `localStorage`/`sessionStorage` outside tests 0; `console.log/debug` 0; `any` 0; `eval` 0; npm audit 0/0 (after the dev-dependency fix) | `platform/api/client.ts` (auth header, `credentials: 'include'`) |
| `mobile/lib` | 313 | 95,731 | `flutter analyze` 0 issues; `flutter test` 1,164 pass; strict boundaries legal=159; `print(` 0, `debugPrint` 1; `// ignore:` 3 (2 `deprecated_member_use`, 1 `unused_element`); catch clauses that set user-facing error state (94, none silent); non-TLS URLs 1 (the dev default, refused by product builds); token storage via `FlutterSecureStorage` (`token_vault.dart`); pub advisories none reported | `api_config.dart` (release fail-closed), `token_vault.dart`, `auth_storage.dart`, `local_database.dart`, `marketplace_provider.dart` (error handling) |
| Contracts (I6) | 237 routes; 262 mobile call sites; 61 admin call sites | — | bidirectional path audit (section 6) | — |
| Deployment / CI | 55 files | — | unchanged since R0 except the R2 `prisma.config.ts` COPY lines; CI runs check/architecture/test (backend), boundary + analyze + test (mobile), architecture/test/typecheck/build/honesty/routes/container (admin) | `ci.yml`, `backend/Dockerfile` |

Coverage statement: every product file passed through the automated passes
listed for its area; the manual reads are the risk-bearing files named. No
file is excluded from any automated pass. A line-by-line human read of all
153,000 lines was not performed and is not claimed.

## 2. Backend domains (I2)

| Domain | Evidence | Finding |
| --- | --- | --- |
| Bootstrap / security posture | helmet, `trust proxy 1`, CORS allowlist from `getCorsOrigins()` with credentials, global `ValidationPipe` (whitelist, forbidNonWhitelisted, transform), global exception filter, shutdown hooks, JSON logs in production, Sentry optional, Redis Socket.IO adapter, fail-fast environment validation | VALID |
| Route protection | 203/237 routes guarded (`JwtAuthGuard`/`JwtSessionGuard`/admin guards); the 34 unguarded routes are the public surface: health/live/ready/metrics (metrics is 404 in production without `METRICS_TOKEN`, bearer-protected with it), auth (register/login/otp/password-reset/refresh/admin flows), invite OTP, public catalog and provider discovery | VALID |
| Rate limiting | global throttler 1,000/min (Redis storage when configured); per-IP `@Throttle` on every auth OTP/login/reset route; invite OTP routes had none | **FIXED** (`4b59faea`): invite request-otp 20/min, verify-otp 30/min, metadata test |
| OTP / credentials | OTP codes bcrypt(10), max attempts, dispatch quota per phone and IP via parameterized upsert; app passwords bcrypt(10), admin passwords bcrypt(12) with upgrade-on-login; refresh tokens hashed; socket auth through the identity access-token verifier | VALID |
| Transactions / locks | 0 `this.prisma` uses inside transaction callbacks; quote scripts and money mutations use `runRetryableTransaction`/serializable transactions; phase-2 concurrency smokes (re-run in the clean room) | VALID |
| Raw SQL | 14 sites; tagged templates parameterize every interpolation; the two `Unsafe` calls are `SELECT 1` and a `$1..$4` parameterized quota upsert | VALID |
| Money arithmetic | Finance sums `Prisma.Decimal`; the dashboard/home summaries accumulated floats and diverged by a cent at the column's magnitude (132 costs of `N0000000000.0M`) | **FIXED** (`f26d2c72`): exact decimal sums, Decimal comparisons, response shape unchanged |
| Pagination | `ListQueryDto` take 1–200, default cap 1,000 | VALID |
| Uploads | presigned S3 uploads with purpose/content-type/size policy; verification re-heads the object, checks owner metadata, sanitizes through sharp and re-uploads | VALID |
| Error handling | 8 non-rethrowing catch clauses, each a documented degradation path (Phase H, H-11) | VALID |
| Logging | no OTP/password/token/phone values logged | VALID |

## 3. Database and data integrity (I3)

| Check | Result |
| --- | --- |
| Migration history vs split schema (`migrate diff --from-migrations --to-schema-datamodel`, isolated shadow database) | **Drift found and fixed** (`bc6a3529`): migration `20260802090000` names an index with 73 characters, PostgreSQL stores 63, the schema's default name differed; the `@@index` now maps to the stored name. No migration, no data change. New managed package `smoke:schema-equivalence` keeps this equal. |
| Migrations added during the mission | 0 (76 migrations, all before R0) |
| Referential actions | 71 relations; the 3 relying on defaults (`Provider.city`, `ProviderService.category`, `WeddingPlan.owner`) restrict deletion, which matches the deletion saga's explicit ordering |
| Unique constraints on natural keys | phone-based user identity, `weddingPlanId_userId` membership, `contributorTenureId_dedupeKey` history dedupe present |
| FK columns without a leading index | 11 (`SharedMember.userId`, `PlanInvite.inviterUserId`, `Guest.groupId`, `User.activeWeddingPlanId`, `Provider.reviewedById`, `QuoteRequest.serviceId`, `QuoteRequest.cityId`, `Conversation.createdByUserId`, `Conversation.customerSideBlockedById`, `ConversationEvent.actorUserId`, `ConversationReport.reporterUserId`). No slow query is proven at product scale; an index migration is a data/ops decision — recorded in section 9, not applied. |
| Seed | byte-identical since R2 (R2/R10 receipts); not re-run here |

## 4. Flutter (I4)

`flutter analyze` 0 issues; 1,164 tests pass; strict boundaries legal=159;
release builds refuse to start without an explicit HTTPS API origin and with
dev login-gate bypasses; tokens live in `FlutterSecureStorage` (v10 migrates
legacy encrypted preferences); no `print(`; the 3 `// ignore:` directives are
two `deprecated_member_use` and one `unused_element`; the byte-identical web
local-database factory was removed (Phase H, `c3e28463`); the desktop
plugin registrants are now canonical for the pinned toolchain (`f69cb2c9`).
The Mobile fate-map remainder (provider_portal split, god-file splits) is an
architecture-target item (traceability matrix), not a defect.

## 5. Admin web (I5)

TypeScript strict, 0 `any`, no HTML injection sinks, no browser storage of
credentials (the API client sends the bearer header from memory and uses
`credentials: 'include'`), boundary scan strict, 101 tests, honesty/routes/
container smokes in CI. Four development-time advisories (browserslist high,
vitest mocker moderate, baseline-browser-mapping moderate) were **fixed**
(`ab840700`) inside declared ranges; audit 0/0.

## 6. Backend ↔ frontend contracts (I6)

- Every mobile call site (262 path literals) resolves to a registered
  backend route: 0 unmatched.
- Every admin call site (61) resolves to a registered route: 0 unmatched
  (four query-string template literals match their base routes).
- Backend routes referenced by no client (excluding health/live/ready/
  metrics, which are operational): `GET /api/v1/me`,
  `GET /api/v1/wedding-plans/:id/contributions/summary`,
  task checklist `POST/PATCH/DELETE`, `POST .../guests/bulk`,
  `PATCH/DELETE /api/v1/guest-groups/:id`, `GET /api/v1/services/:id`,
  `GET /api/v1/me/quote-requests/:id`, `PATCH .../cancel`,
  `PATCH/DELETE /api/v1/reviews/:id`,
  `GET /api/v1/provider/me/quote-requests/:id`, `GET /api/v1/dashboard/home`
  (15 routes). They are covered by smokes/tests and by the generated
  `docs/backend/API_CONTRACT.md`; whether to keep them is a product decision
  (section 9). No client calls a route that does not exist.

## 7. Lint, typecheck, advisories (I7)

Backend tsc 0, npm audit 0/0 (multer 2.3.0 / sharp 0.35.4 registered at
R12C); admin tsc 0, audit 0/0 after `ab840700`; mobile analyzer 0, no pub
advisories reported by `flutter pub get`.

## 8. Tests are not truth (I8)

- 1,275 backend tests scanned: none without an assertion (30 flagged by the
  scan use local assertion helpers).
- Skips: 27 lineage-only (reason printed, verified at the lineage commit)
  and 1 declared Windows POSIX-permission skip.
- Governance suites that pinned live product bytes were rebuilt from the
  lineage commit (Phase H); the dependency-surface copy is retry-safe.
- The Marketplace service growth guard moved by exactly the approved Task 3
  delta at R12C Task 6 (recorded there); no assertion or expected value was
  changed to make a test green in this audit.

## 9. Product remediation (Phase J) and decisions required

Fixed, each in its own commit with a RED-first regression test:

| Commit | Defect |
| --- | --- |
| `bc6a3529` | Schema/migration drift on the `ContributionEvent` index name (+ `smoke:schema-equivalence` gate) |
| `f26d2c72` | Dashboard money summed as floats |
| `4b59faea` | Invite OTP routes without the per-IP throttle of the OTP family |
| `ab840700` | Admin dev-dependency advisories |
| `c1436572` | Found by the first clean-room run: the Prisma-config security checkpoint fingerprinted the whole `package.json`, so the new `smoke:schema-equivalence` script failed the security gate, R5 and R12B; the fingerprint now covers the package security surface (every member except `scripts`), and the R7 script projection rejects an aggregate naming a gate without its standalone script |
| `d6e30207` | Found by the first clean-room run: the phase-0 source guard (pretest) did not know the new managed package; registered |
| `bf11ab17` | Found by the first clean-room run: Flutter rewrites its generated registrants with LF, a CRLF checkout reported seven files modified with an empty diff; `.gitattributes` now checks them out with LF |

**PRODUCT DECISION REQUIRED** (recorded, not acted on):

1. Fifteen backend routes have no mobile or admin caller (section 6). Keeping
   them preserves the HTTP contract invariant; removing them is a product
   change.
2. Eleven foreign-key columns have no leading index (section 3). Adding
   indexes needs a migration; no slow query is proven at product scale.
3. Desktop (Linux/Windows) targets: the toolchain no longer registers the
   secure-storage and file-selector desktop plugins; desktop packaging is
   unverified and undocumented as a target.

## 10. What this audit does not claim

- No independent reviewer; no line-by-line human read of every file.
- Smokes and the clean-room verification are reported in the final report.
