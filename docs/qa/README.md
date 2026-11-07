# QA And Testing

## Gates

Run the gates of the area you touched. Run all of them before a merge or a release.

```powershell
# Backend (from backend/)
npm run check
npm run architecture          # pins migrations, then imports, ownership, ports and the context gates
npm run security:prisma-config-merge
npm test                      # guarded runner: preflight batch, then the main batch
npm run smoke:all             # managed isolated smoke packages (Docker stack)

# Repository root
node .\scripts\docs-sync.mjs --check
node .\scripts\docs-verify.mjs
node --test .\scripts\check-mobile-boundaries.test.mjs
node .\scripts\check-mobile-boundaries.mjs --strict
git diff --check

# Admin web (from admin-web/)
npm run test:architecture
npm run architecture
npm test -- --run
npm run typecheck
npm run build

# Mobile (from mobile/)
flutter analyze --no-pub
flutter test --no-pub
```

Set `ARCHITECTURE_DEBUG=1` to print the reason a scanner fails.

On Windows, `npm test` skips the one test that needs POSIX file modes
(`openwa-credential-file.test.ts`: the OpenWA credential file must refuse
broad permissions and symbolic links). While CI is off it runs nowhere else,
so run it in a Linux container before a release (RA-TS-02):

```powershell
docker run --rm -v "D:\projects\aarast\backend:/app:ro" -w /app node:24-alpine `
  node --test -r ts-node/register test/openwa-credential-file.test.ts
```

`npm run smoke:all` runs in isolated databases. If a run is killed, delete the Redis DB 15 lock `aarast:managed-smoke:lock` from `aarast-redis`.

## Rules

- **Migrations:** a new migration is added to the reviewed manifest. Changing a published one fails.
- **Existing tests:** behavioural assertions, expected values, fixtures and Arabic or error contracts do not change to make a defect pass.
- **Golden images:** a changed image is viewed before it is regenerated.
- **Reporting:** state the commands you ran and their exact results. Do not claim a check you did not run.
- **Done means:** checks you ran, a shot from the real app, and a walk with the user's eyes. See [JOURNEY_WALKS.md](JOURNEY_WALKS.md).

## Demo data

Accounts and seed are in [DEMO_DATA.md](DEMO_DATA.md). Manual phone checks are in [MOBILE_QA.md](MOBILE_QA.md).
