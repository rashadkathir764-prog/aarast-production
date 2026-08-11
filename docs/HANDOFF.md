# Aarast Project Handoff

Snapshot date: 2026-08-11

This is the continuation guide for the next maintainer. It summarizes the
observed repository, deployed application, recovery assets, external gates,
and safe first actions. Detailed product, API, database, QA, and deployment
contracts remain in the active documents listed by `docs/README.md`.

## Start Here

1. Read `README.md`, `AGENTS.md`, `docs/README.md`, this file,
   `docs/project/STATUS.md`, and `docs/project/EXECUTION_PLAN.md`.
2. Confirm the repository root and current truth instead of trusting a copied
   branch count or mutable SHA:

   ```powershell
   cd D:\projects\aarast
   git status --short --branch
   git rev-parse HEAD
   git rev-parse origin/main
   git worktree list
   git stash list
   ```

3. Keep `main` as the canonical integration branch. Use reviewed PRs and green
   CI for every change. GitHub branch protection is not enabled on the current
   private repository, so maintainers must enforce this process operationally.
4. Do not merge or delete `origin/codex/guest-invitation-campaigns`. It contains
   one unique out-of-scope WIP commit and is preserved separately in
   `_ai_backups/guest-invitation-campaigns-21aee9e-20260811.bundle`.
5. Treat Dependabot branches as open compatibility reviews, not disposable
   cleanup. Their count changes automatically.

## Product And Scope

Aarast is a Yemen-first Arabic/RTL wedding-planning product. The canonical
money contract is an optional general budget, categories, costs, recorded
payments, and dated payment schedules. Provider flows support discovery,
quotes, provider operations, and quote-scoped conversations.

Do not introduce confirmed bookings, deposits, payment processing, loans,
credit, financing, production AI automation, or open unsolicited messaging
without a new explicit product and architecture decision.

## Repository And Verification State

- Canonical branch: `main`; resolve its current immutable revision with Git.
- The final documented closure passed GitHub CI for Backend, Mobile, Admin,
  Backend E2E, Backend image, dependency audit, documentation, and secret scan.
- Latest recorded full source gate: Backend 670 tests total (669 passed and one
  intentionally skipped), 30 managed smoke packages, 76 migrations; Mobile
  1150/1150; Admin 96/96; deployment contracts 38/38.
- Generated API, database, route, and script references are checked by
  `scripts/docs-sync.mjs` and `scripts/docs-verify.mjs`.
- One detached Codex-managed worktree exists outside the main checkout. Inspect
  it before removing it; do not delete it as routine cleanup.

### Unreleased account-deletion correction

The deployed revision listed below has a confirmed dual-identity edge case:
deleting the wedding-application account of a person who is also an Aarast
administrator returns `403`, and the old Mobile retry can temporarily enter a
`PENDING`/`503` reconciliation loop. The corrective source on
`codex/admin-application-account-deletion` keeps the administrator identity and
`ADMIN` sessions but erases the separate app identity/data and `APPLICATION`
sessions. It also stops Mobile from replaying DELETE while status is `PENDING`.

Local corrective gates pass: Backend `671` total (`670` passed, one skipped),
type/seed checks, managed isolated deletion smoke over all 76 migrations;
Flutter analysis, focused transition `8/8`, and full `1151/1151`. Do not call
Production fixed until this change is reviewed, merged, deployed, and repeated
on the affected physical-device path. The administrator browser login must be
tested after app deletion as a release acceptance condition.

## Production Receipt

The currently accepted application deployment uses revision
`900897a90e8b030c7c3ddfdc55cc2669b64f2e87`. Later repository commits may be
documentation-only and do not change the running application revision.

- Backend, Admin Web, public site, PostgreSQL, Redis, media, and backup sidecar
  were healthy with zero restarts and no OOM termination at final acceptance.
- External Backend `/live` and `/ready`, Admin `/login`, public `/privacy`,
  `/support`, a valid-shape invitation route, and Android association passed.
  Unknown public routes and Apple association intentionally return `404`.
- All 76 migrations are applied. Production has 15 live plans, 15 linked
  contributor-history scopes, and zero missing scopes, lifecycle mismatches,
  missing active tenures, or unfinished migrations.
- Fresh pre-deployment backup SHA-256:
  `b86d11263262f6e4a709d3638c250fa59ac88e7dbce4aff0841d0a91122dbc4b`.
  Its checksum, catalog, full isolated restore, second migration pass, schema,
  and relational postconditions passed against the exact deployed Backend
  image.
- Rollback evidence is retained on the production host under the protected
  release backup directory documented in `docs/deployment/README.md`. Do not
  delete it as ordinary cleanup.

## Android Artifact

The latest signed direct-install APK is
`mobile/build/app/outputs/flutter-apk/app-release.apk`:

- version `1.0.0+8`, package `com.aarast.aarast_mobile`;
- source revision `2ffbe95d7a8e412ead47220536046501f4ac86bf`;
- size 88,634,008 bytes;
- SHA-256
  `075D82E24BEF4DED75F34D663B76132C9A6D6F89C7FE6535009C734A0CA1C69D`;
- non-debuggable, APK Signature Scheme v2, Aarast RSA-3072 upload signer;
- Production API and private Firebase client resources embedded;
- Sentry release identity embedded, but DSN delivery intentionally disabled.

This APK is not a Play Store AAB and is not physical-device/store acceptance.
Do not describe it as published in Google Play or the App Store.

## External And Operational Gates

These are real remaining gates, not code placeholders:

1. Production currently selects `AUTH_OTP_MODE=openwa`, but the real-device OTP
   delivery/verification, disconnect/recovery, privacy-history, rotation, and
   24-hour stability acceptance is not recorded as passed. Freeze wider OTP
   rollout until `docs/deployment/OPENWA_OTP_MVP.md` is completed, or switch to
   an approved disabled/Meta channel.
2. Production `METRICS_TOKEN` and `SENTRY_DSN` are not configured, and no
   Prometheus/Grafana/Alertmanager containers are running. The source stack is
   available but not operated.
3. Repeat the owner/two-contributor/session scenario against the deployed
   Backend on a physical Android device. Verify background and terminated Push,
   WhatsApp OTP, slow/offline/interruption behavior, and Android App Links.
4. Run the corresponding iOS SQLCipher upgrade, session, Push, Universal Link,
   Archive, and symbol-upload gates on macOS with the real Apple identity.
5. Build the final AAB from the approved release revision, enable live Sentry
   symbol upload, verify the final Play signing association, prepare store
   assets, and complete Play/App Store review.
6. Treat the recorded load tests as single-instance evidence only. Multi-server
   behavior, Postgres HA, and a real load-balanced fleet remain unverified.

## Secrets And Access

No production secret belongs in Git or this handoff. The next maintainer needs
authorized access to GitHub, Dokploy/SSH, DNS/TLS, PostgreSQL backup storage,
OpenWA/Meta WhatsApp, Firebase service credentials, Sentry, Android upload/store
signing, and Apple developer accounts as applicable. Rotate access deliberately;
never paste secret values into issues, commits, logs, or documentation.

## Required Checks Before A Change Is Accepted

Documentation:

```powershell
node .\scripts\docs-sync.mjs --check
node .\scripts\docs-verify.mjs
git diff --check
```

Backend:

```powershell
cd .\backend
npm run check
npm run build
npm test
npm run smoke:all
```

Admin Web:

```powershell
cd .\admin-web
npm run typecheck
npm test -- --run
npm run build
```

Mobile:

```powershell
cd .\mobile
flutter analyze --no-pub
flutter test --no-pub
```

Use the managed smoke wrappers and disposable databases. Never run destructive
database commands against Production or permanent local data. Re-run the
deployment restore rehearsal before any migration-bearing production release.

## Recommended Continuation Order

1. Close or disable the unaccepted OpenWA production path.
2. Configure protected metrics/Sentry and operate the monitoring stack.
3. Complete deployed physical Android acceptance, then iOS/macOS acceptance.
4. Review Dependabot PRs individually with compatibility tests.
5. Continue the P2 design/maintainability work in
   `docs/project/EXECUTION_PLAN.md` without restoring archived Royal/Premium or
   removed finance implementations.
6. Produce a store AAB only from a clean, reviewed, green release revision.

When state changes, update `docs/project/STATUS.md`, this handoff, the relevant
area document, and `CHANGELOG.md` in the same PR.
