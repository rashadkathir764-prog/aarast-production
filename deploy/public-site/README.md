# Aarast Public Site

Snapshot date: 2026-08-11

This directory is the reproducible source for Aarast's small public surface at
`https://aarast.shadowgardn.com`. It serves the privacy policy, support page,
participant-invite landing, and mobile-link association files. It is not the
Flutter web application.

It contains only public static assets. The Docker build copies an explicit
allowlist and must never copy the repository, `.env`, Git metadata, deployment
files, or runtime secrets into the image.

## Routes

- `/healthz` - container health probe only.
- `/privacy` and `/privacy/` - Arabic privacy policy.
- `/support` and `/support/` - Arabic support and account-deletion guidance.
- `/terms` and `/terms/` - Arabic terms of use.
- `/download` and `/download/` - Arabic app download page. Its script draws a
  QR code of the serving origin's `/download` with the vendored, unmodified
  `qrcode-generator.js` 1.4.4 (MIT, Kazuhiko Arase); the source check pins the
  file's hash. The Google Play button works once the store listing is live.
- `/rsvp/:token` - a guest's personal RSVP page.
- `/invites/:token` - generic participant-invite landing page.
- `/invite-preview.png` - generic social preview used by the landing page.
- `/.well-known/assetlinks.json` - Android App Link association for the signed
  MVP APK.
- `/.well-known/apple-app-site-association` - deliberately returns `404` until
  the real Apple Team ID and bundle association are approved.

Only the explicitly allowlisted page assets are also served. The root and every
other route return `404`; marketing, account, API, directory listing, and SPA
fallback behavior do not belong in this narrowly scoped image.

Android association uses the current signed MVP APK certificate so an installed
build can open invitation links directly. If Google Play App Signing replaces
that certificate, this file must be updated before store rollout. Apple
association remains fail-closed until a real Apple Team ID exists. The landing
also keeps its explicit `aarast://` open-app button as a browser fallback.

The privacy, terms and support pages are static HTML/CSS with no JavaScript,
forms, analytics, or third-party resources. The participant-invite route disables
access logs, browser caching, and search indexing. Its small first-party script
keeps the token in memory for the current page lifetime and never writes it to
browser storage, cookies, analytics, or console output.

Production Compose exposes this image on host `8095` and requires the immutable
content-addressed `AARAST_PUBLIC_SITE_IMAGE_ID`. The release build Compose passes
the same full 40-character `AARAST_GIT_REVISION` used by Backend and Admin Web
into this image and records it in `org.opencontainers.image.revision`. These are
source/runtime contracts only; they do not prove that the public domain has
been deployed or verified.

## Verify

```powershell
node --test .\deploy\public-site\public-site.test.mjs
docker build --tag aarast-public-site:verify .\deploy\public-site
```

No production deployment or secret is required for the source test or image
build.
