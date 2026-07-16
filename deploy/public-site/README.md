# Aarast Public Site

This directory is the reproducible source for the public Aarast site served at
`https://aarast.shadowgardn.com`.

It contains only public static assets. The Docker build copies an explicit
allowlist and must never copy the repository, `.env`, Git metadata, deployment
files, or runtime secrets into the image.

## Routes

- `/` - current public landing page.
- `/contact.html` - current contact page.
- `/privacy.html` - current privacy policy.
- `/invites/:token` - generic participant-invite landing page.

The final Android and Apple association files are deliberately not generated
from temporary QA identities. Until the store-signing phase supplies the real
certificate fingerprint and Apple Team ID, both `/.well-known` association
paths return `404` instead of falling back to a misleading HTML `200`. The MVP
landing remains usable through its explicit `aarast://` open-app button.

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
