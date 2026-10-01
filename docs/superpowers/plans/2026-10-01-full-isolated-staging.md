# Full Isolated Staging Implementation Plan

> **For agentic workers:** Execute this plan in `staging/full-isolated-staging-20261001` only. Do not touch production, build a phone APK, or create acceptance accounts.

**Goal:** Prepare a complete, independently named Aarast staging stack and QA configuration from the protected architecture baseline, then deploy only if external identity, routing, and host-capacity gates are satisfied.

**Architecture:** Reuse the proven PostgreSQL role SQL, media policy, Backend image, and Admin runtime guard as inputs to a new Compose project. Staging has its own database, Redis, media, backup, credentials, networks, image IDs, and public origins. QA invite/App Links and Admin build settings fail closed without explicit staging values.

**Tech stack:** Docker Compose, PostgreSQL 16, Redis 7, MinIO, NestJS, React/Vite, Flutter/Android.

**Spec:** User request “AARAST — FULL ISOLATED STAGING IMPLEMENTATION” (2026-10-01).

## Constraints and review focus

- Base SHA is `f42804e297b0304cac88652bd60d74676b370a89`; preserve `ARCHITECTURE_CONSTITUTION.md`, all 76 migrations, and existing product behavior.
- No production Compose mutation, production credential reuse, production data, or shared OpenWA session for phone QA.
- No real secrets in Git. Local staging secrets stay outside the checkout and are never printed.
- A missing origin, QA signing identity, Firebase project, or independent OTP sender must fail closed rather than select production.
- Review host capacity and existing Docker resources before any remote creation; leave every pre-existing resource untouched.

### Task 1: Staging isolation contracts

**Files:** Create `deploy/staging/docker-compose.yml`, `deploy/staging/docker-compose.build.yml`, `deploy/staging/.env.example`, `deploy/staging/README.md`, and `deploy/staging/staging-contract.test.mjs`.

- [x] Write a failing contract test for unique project/resources, separate DB roles and migration job, required Redis/media readiness, explicit HTTPS origins, and absence of production references.
- [x] Implement the smallest independent Compose topology using the existing PostgreSQL role SQL and media policy.
- [x] Validate Compose with a synthetic non-secret environment and run role/isolation tests.

### Task 2: Admin staging build safety

**Files:** Modify `admin-web/src/platform/api/client.ts`, `admin-web/Dockerfile`, and `admin-web/scripts/build-config-smoke.mjs`; add focused negative tests.

- [x] Prove the existing build can select the production fallback when staging input is missing.
- [x] Require an explicit API origin for production-like builds and prove the built artifact and runtime CSP match the staging API only.

### Task 3: QA invite and App Links safety

**Files:** Modify `mobile/android/app/build.gradle.kts`, `mobile/android/app/src/main/AndroidManifest.xml`, and `mobile/lib/core/routing/app_router.dart`; create staging public-site image/config and focused tests.

- [x] Prove a QA identity with no invite host would still select production today.
- [x] Require the staging invite host for a QA release, keep the existing production host for production builds, and verify manifest/Flutter host parity.
- [x] Keep staging `assetlinks.json` fail closed until the QA package and signing certificate fingerprint are supplied.

### Task 4: Final verification and guarded deployment decision

- [x] Run architecture, affected Backend/Admin/Mobile tests, Compose validation, docs checks, and `git diff --check`.
- [x] Inspect actual server projects, containers, networks, volumes, ports, DNS/TLS, independent OTP and Firebase availability, and memory headroom without reading secrets.
- [x] Decide against deployment while independent Meta/Firebase inputs and stage DNS/TLS routes are absent and host headroom is tight; leave the server unchanged.
- [x] Commit only the scoped staging changes after green source-side gates; do not push or merge.
