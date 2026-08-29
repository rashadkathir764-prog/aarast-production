# Modular Monolith R9 Mobile Strict Boundaries Completion

Date: 2026-08-30

Status: Locally complete

Branch: `modular-monolith`

Immutable R9 base: `833a4f1d31781b45cd0a68ecee1b969ac85f237f`

Design checkpoint: `2ea231b03f1eb7b56e6e8643e9ce90b4733a262c`

Approved-plan checkpoint: `91e236852e8265b76a7995227527fe7d898cba04`

Strict-CI HEAD: `6b1602decd09a266634e2a98debc7fcf650e12cd`

Application candidate: `0f61bf283b455c4404182f5028ab78d2448053d3`

C5 working-tree diff SHA-256:
`bc954f149febc5c8f8a7394b26bb9194d6691cbf2efee6dbcf249634e3224c1b`

Final R9 plan SHA-256:
`061e26f63393d9c988c3dbec1043e633ed32f9a213fda55b6db4406beccb2a0a`

Final 157-path fence SHA-256:
`eda3b152a7eb8986482fa1b2d0aeaa32120a26f721be1cf1c36515ba107f967c`

The final docs-only checkpoint is the commit containing this receipt. Its SHA
is recorded after commit because a commit cannot truthfully contain its own
final hash.

## Completed Contract

R9 converts the existing Mobile architecture debt baseline into a strict,
fail-closed feature boundary:

- all 19 Mobile feature owners expose exact public `<feature>_api.dart`
  surfaces;
- cross-feature imports consume those surfaces with exact `show` symbols;
- `app.dart`, `app_router.dart`, and `main.dart` remain the only approved
  composition roots;
- historical feature debt falls from 269 records to zero and root debt from 34
  records to zero while the final legal projection is 159 records;
- `SafeUser` has one canonical persisted implementation under `core/session`;
- Push lifecycle binding consumes immutable nullable identity data and keeps
  bind/unbind/replacement/resume/pending-tap behavior;
- CI runs the same strict boundary mode accepted locally;
- C5 corrects one phone-discovered product defect at the earliest boundary:
  ordinary logout, restore rejection, and confirmed session expiry preserve an
  unimported installation-owned guest plan, while confirmed account deletion
  may clear it. Successful import and explicit double-confirmed discard retain
  their existing deletion contracts.

C5 is the only approved behavior correction. R9 otherwise changes no Backend
API, database schema, migration, dependency, route, UI scope, product scope,
Compose, Dokploy, or deployment behavior.

## Local Commit Sequence

The committed R9 sequence from the immutable base to Strict-CI HEAD is:

1. `2ea231b03f1eb7b56e6e8643e9ce90b4733a262c` — design.
2. `91e236852e8265b76a7995227527fe7d898cba04` — implementation plan.
3. `7e23299d61014bc198f93dace13c56ceacc58bbd` — R9 governance.
4. `3b10a14f041a1dc99c25961f959b07f344a6f217` — final legal inventory fix.
5. `95acb4964d85ad83900de4485f665a26bbf18acd` — formatter prerequisite.
6. `5dd99a81d41a87a7edd506d9c59fd992decdcf1e` — session/Push decoupling.
7. `5e19366a85bbfd558e309870b3b365a3ed76daab` — feature public APIs.
8. `569597a8840d42ae03fdd1d7d4f63c11fbb9ba95` — Identity consumers.
9. `d79948f151de04cf876aad315f6889361c03be0e` — Collaboration consumers.
10. `910ee8c33549f9e6f693fbb00863424f5e58eba1` — formatter ownership test.
11. `9f0e2e356a5a524ed2447696294822d9278cd122` — Planning consumers.
12. `dbfd0576473412ec925b4b127d52f7b104e7afb3` — Shell consumers.
13. `ce5da3311b01e762e7a834d61ed0ef7a3b4d976f` — composition roots.
14. `0fe897de914c0a121c98cbc335bc2fa307b07fef` — CI path correction.
15. `ec812a1c9fec68483bceb9ff47f2a354ab02aa0e` — exhaustive gate contracts.
16. `6b1602decd09a266634e2a98debc7fcf650e12cd` — strict CI activation.
17. `0f61bf283b455c4404182f5028ab78d2448053d3` — preserve the installation-owned
    guest plan across ordinary session termination.

## Changed-Path Receipt

- Immutable base to Strict-CI HEAD: 143 actual paths.
- C5 adds two new path identities and modifies six already-present identities:
  145 actual paths before documentation closeout.
- Task 11 changes exactly ten documentation paths; the final actual R9 union is
  155 paths, inside the 157-path approved fence.
- The full canonical fence is Appendix D of the approved R9 plan. No historical
  baseline, package lock, Prisma schema/migration, Docker/Dokploy, or deployment
  path is changed.

C5's exact eight tracked paths are the R9 plan, manifest, boundary validator,
scope tests, session teardown coordinator, auth controller, coordinator test,
and session-transition test. Task 11's exact ten documentation paths are listed
in the completion plan.

## Verification Receipt

| Gate | Observed result |
| --- | --- |
| R9 scanner/scope governance | PASS: 230/230 |
| Historical projection | PASS: `legacy=0`, `root=0`, `legal=159` |
| Strict projection | PASS: zero violations, `legal=159` |
| Feature public APIs | PASS: all 19 exact paths and export surfaces |
| SafeUser + Push focused proof | PASS: 10/10 |
| C5 direct teardown/transition proof | PASS: 18/18 |
| Expanded session group | PASS: 19/19 |
| Flutter analysis | PASS: no issues |
| Full Flutter | PASS: 1164/1164 |
| Backend architecture/check/build | PASS |
| Backend tests | PASS: 1346 pass, 0 fail, 1 intentional skip |
| Backend dependency audits | PASS: 0 vulnerabilities, full and production |
| Admin Web | PASS: 18 files / 96 tests; typecheck, build, honesty, and 3/3 container checks |
| Prisma at Task 9 | `BLOCKED — environment`: no approved worktree `DATABASE_URL` |
| Isolated Task 10 database | PASS: 76/76 migrations; managed Marketplace smoke 62/62 |
| Documentation, final scope, and whitespace | PASS after Task 11 verification |
| Independent Task 10/C5 review | APPROVE: Critical 0 / Important 0 / Minor 0 |

One full Flutter attempt during concurrent independent review reported one
transient failure. The unchanged immediate diagnostic rerun and the reviewer's
independent full rerun both passed 1164/1164. No assertion, fixture, timeout,
skip, or runner setting was weakened.

The final unchanged full rerun also passed 1164/1164 but emitted the existing
Flutter desktop-plugin metadata notices for missing Windows/Linux default
implementation packages. They did not fail analysis or tests and do not affect
the accepted Android R9 scope; Windows/Linux desktop packaging is not claimed.

The repository seed remains adjacent stale-fixture debt: its Task 10 run still
supplied removed `WeddingCost.dueDate` and a legacy application credential
field. No R9 patch was made outside the approved Mobile boundary scope.

## Physical-Phone Acceptance

The owner-selected `SM-S938B` was the sole authorized device; S10/SM-G97 was
not used. The corrected candidate created a synthetic local plan, logged into
a synthetic account in a disposable QA database, and showed the local-plan
migration gate. Neither Upload nor Discard was selected. Server `logout-all`
revoked three synthetic sessions. After access expiry and refresh rejection,
two separate force-stop/relaunch cycles restored the same local plan Dashboard
without the synthetic authenticated account or migration gate.

The accepted debug APK is package `com.aarast.aarast_mobile`, version
`1.0.0+8`, size `186,150,778` bytes, SHA-256
`917505e72b9c6697673ba6493c9cdc873b8eb58e4303a3302638904e590a7f9a`.
The package was absent before this corrected install, so an installed-signer
comparison was not applicable; `apksigner verify` and installation passed.
The prior rollback artifact remains outside the repository.

The early Task 10 local-environment diagnosis was read-only and exposed schema
lag without migration or repair. Accepted functional and phone journeys used a
disposable isolated current-R9 runtime/database. Cleanup proved port 3120 had
zero listeners, Redis DB 14 was empty, and no Task-owned QA database remained.

No device identifier, LAN address, phone, OTP, password, token, raw UI XML,
screenshot, logcat, response body, or private business value is retained.

## Remaining Risks And Stop Boundary

- Live Firebase Push: `UNVERIFIED`.
- Bare Task 9 Prisma validation remains `BLOCKED — environment`, while isolated
  Task 10 migration/runtime proof passed.
- The stale repository seed fixture is not corrected in R9.
- Windows/Linux Flutter desktop-plugin metadata notices remain outside the
  Android R9 acceptance surface.
- iOS, store signing/upload, remote CI, deployment, and production acceptance
  are outside R9.
- No push, merge, PR mutation, deployment, remote CI, store release, S10 work,
  or R10 work is claimed.

Verdict: **Ready with notes — R9 is locally complete; external integration
remains stopped.**
