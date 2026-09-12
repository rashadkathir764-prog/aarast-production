# R12A Task 5 Full-Test Remediation Plan

## Objective

Remove the two root causes exposed by the first fresh `npm test` run without
changing production behavior, package versions, the lockfile, API contracts,
database state, or any non-Backend surface.

## Immutable evidence

- Entry revision remains `4d0d3ee91fb32d0432aa3bd69fe018d9a5a323b1`.
- Focused behavior passed `31/31`.
- Focused architecture passed `522/522`.
- Full Backend architecture, type checking, and build passed.
- Full tests stopped at `1406` tests: `1397` passed, `8` failed, `1` skipped.
- Four failures come from the Prisma merge-security checker not projecting the
  exact R12A standalone/aggregate package-script pair before its immutable R8
  to R6 package fingerprint comparison.
- Four failures come from a test-only invitation fixture whose fixed expiry
  instant, `2026-09-02T00:00:00.000Z`, has now elapsed.

## Allowed change surface

- `backend/scripts/security/prisma-config-merge-security.cjs`
- `backend/test/prisma-config-merge-security.test.ts`
- `backend/test/sharing-reinvite-authority.test.ts`
- this plan, the main R12A plan reference, and ignored SDD reports/progress

No production Collaboration source is authorized because its expiry check is
correct and the failure is entirely fixture-owned.

## Task 1: Prove the missing security handoff RED

Add an exact R12A projection contract to the Prisma merge-security tests. It
must accept only the canonical `architecture:r12a` standalone/aggregate pair,
project through the unchanged R8, R7, and R6 chain, preserve the historical
package fingerprint, and reject missing, changed, duplicated, or partial R12A
identities. Run the focused test and require a failure before implementation.

## Task 2: Implement one fail-closed R12A projection

Add fixed R12A script constants and a single explicit projection function to
the Prisma merge-security checker. Reuse the existing R8 to R6 projection;
do not update the pinned package or lock fingerprints and do not add a fallback.
The live checker must start at the R12A projection.

## Task 3: Repair the expired test fixture at its source

Make the authority-focused invitation fixture unexpired relative to the test
run. Do not alter production expiry semantics or the assertions about authority,
locking, atomicity, status, or writes.

## Task 4: Verify and restart Task 5

Run the two focused test files, the Prisma security CLI, architecture, check,
and build. Then restart Task 5 from immutable projection Step 1. Do not run
smoke suites until the complete `npm test` gate passes.

## Task 5: Repair stale managed-smoke constructors at the fixture boundary

The restarted affected-smoke gate exposed a separate pre-existing fixture
compile failure: two managed smoke scripts still construct `AdminService` with
two dependencies even though the immutable entry contract requires Prisma,
realtime, and notifications. Keep production `AdminService` unchanged. Supply
the explicit notification-port stub in only these two smoke fixtures:

- `backend/scripts/smoke/phase2-provider-rating-concurrency-smoke.ts`
- `backend/scripts/smoke/phase2-provider-dashboard-concurrency-smoke.ts`

The provider-rating smoke failure itself is the RED reproduction. Rerun it to
GREEN, then run the provider-dashboard smoke and the complete managed smoke
gate so the second stale constructor cannot remain latent.

The same provider-rating execution also proved that its account-deletion
fixture predates the media-storage deletion-boundary port. Add the required
no-op lock to that smoke-owned port double while retaining the existing media
deletion scheduling assertion path; do not change `UsersService`.

## Task 6: Reject duplicate raw JSON members before projection

Independent Task 5 closeout review proved that native `JSON.parse` erases a
duplicate raw `architecture:r12a` member before the fail-closed projection can
inspect it. Add an adversarial CLI regression that injects both an exact raw
duplicate and a Unicode-escaped equivalent into the live package input without
modifying the real file. Require RED first. Then make the security reader reject
duplicate members in every JSON object before native parsing, including decoded
escape equivalence. Do not special-case only R12A, change pinned fingerprints,
or alter the package/lock files.
