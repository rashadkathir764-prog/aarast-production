# Aarast Participant Invite Landing

This directory is the reproducible source for the participant-invite landing
served at `https://aarast.shadowgardn.com/invites/:token`.

It contains only public static assets. The Docker build copies an explicit
allowlist and must never copy the repository, `.env`, Git metadata, deployment
files, or runtime secrets into the image.

## Routes

- `/healthz` - container health probe only.
- `/invites/:token` - generic participant-invite landing page.
- `/invite-preview.png` - generic social preview used by the landing page.
- `/.well-known/assetlinks.json` - Android App Link association for the signed
  MVP APK.

Every other path returns `404`. Marketing, contact, legal, account, and API
surfaces do not belong in this narrowly scoped image.

Android association uses the current signed MVP APK certificate so an installed
build can open invitation links directly. If Google Play App Signing replaces
that certificate, this file must be updated before store rollout. Apple
association remains fail-closed until a real Apple Team ID exists. The landing
also keeps its explicit `aarast://` open-app button as a browser fallback.

The participant-invite route disables access logs, browser caching, and search
indexing. Its JavaScript keeps the token in memory for the current page lifetime
and never writes it to browser storage, cookies, analytics, or console output.

## Verify

```powershell
node --test .\deploy\public-site\public-site.test.mjs
docker build --tag aarast-public-site:verify .\deploy\public-site
```

No production deployment or secret is required for the source test or image
build.
