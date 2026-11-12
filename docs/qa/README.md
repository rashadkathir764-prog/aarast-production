# QA And Testing

## Gates

One command runs them, on Windows or Linux, and prints a PASS, FAIL or SKIP
table (a skip names the missing tool; the exit code is 1 on any failure):

```powershell
node scripts/gates.mjs --quick                 # before a commit: static checks and unit tests
node scripts/gates.mjs --quick --only mobile   # one area or more: backend, admin, mobile, root
node scripts/gates.mjs --full --strict         # before a merge or a release: everything, no skip allowed
```

The list below is what it runs, command by command. Run the gates of the area
you touched before a commit, and all of them before a merge or a release.

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
node --test (git ls-files 'deploy/**/*.test.mjs' scripts/check-deploy-encoding.test.mjs scripts/supply-chain-contract.test.mjs)
node --test .\admin-web\scripts\staging-build-origin.contract.mjs
# The real Gradle release guard; needs Java (Android Studio's: $env:JAVA_HOME =
# 'C:\Program Files\Android\Android Studio\jbr'; $env:Path = "$env:JAVA_HOME\bin;$env:Path")
node .\scripts\test-android-release-config.mjs
git diff --check

# Admin web (from admin-web/)
npm run test:architecture
npm run architecture
npm test -- --run
npm run typecheck
npm run build
npm run smoke:honesty
npm run smoke:routes
npm run test:container-config
npm run smoke:admin-runtime     # a real backend and admin build, isolated like smoke:all

# Dependencies (backend/ and admin-web/)
npm audit --audit-level=high

# Mobile (from mobile/)
flutter analyze --no-pub
flutter test --no-pub
```

Set `ARCHITECTURE_DEBUG=1` to print the reason a scanner fails.

CI (`.github/workflows/ci.yml`) runs on every push to `main` again since
2026-11-12 (it was stopped by the account's billing). The list
above carries every check CI runs (the staging contracts, the admin smokes,
`npm audit`), so a red job on GitHub can be reproduced here; `gh run list`
shows the last runs, and a push is not done until its run is green.
`scripts/gates.mjs --full` adds the three CI checks that were missing from the
list: `docker compose config`, the secrets scan (`gitleaks detect`, when
gitleaks is installed) and the release Gradle guard. The image build and its
Trivy scan stay in CI only.

`--full --strict` needs three tools on this machine, or it fails on the skip:
Docker Desktop running (with `aarast-db` and `aarast-redis` started), Java on
the path (the two lines above for Android Studio's), and gitleaks
(`winget install --id Gitleaks.Gitleaks --exact`; a new terminal sees it).

Run a single backend or admin command from `D:\projects\aarast\…` with the
capital drive letter. Several checks compare paths letter for letter and fail
from `d:\…` on the same code; `scripts/gates.mjs` corrects this for the gates
it runs, a command typed by hand does not.

On Windows, `npm test` skips the one test that needs POSIX file modes
(`openwa-credential-file.test.ts`: the OpenWA credential file must refuse
broad permissions and symbolic links). CI runs it on Linux; to run it here,
use a Linux container (RA-TS-02):

```powershell
docker run --rm -v "D:\projects\aarast\backend:/app:ro" -w /app node:24-alpine `
  node --test -r ts-node/register test/openwa-credential-file.test.ts
```

The phone keeps its offline queue in encrypted SQLite (`sqflite_sqlcipher`);
Windows and the unit tests use the JSON store. So the queue's own statements
run on an Android device or emulator before a release (RA-MO-30). It wipes the
app's local data on that device:

```powershell
cd mobile
flutter test integration_test/offline_queue_sqlite_android_test.dart -d emulator-5554
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
