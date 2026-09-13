# Architecture Exit Audit

**Date:** 2026-09-13
**Scope:** the whole repository at the R12C closure (`86df8c36` and after),
branch `recovery/r12c-t5-takeover-20260913`.
**Method:** each category below was swept by tooling (AST walks over
`backend/src`, `admin-web/src`, `mobile/lib`; `git ls-files`; content hashes;
grep over active documentation) and by running every gate against probes
(edits and violations planted in a clone). Every finding is classified
VALID / BROKEN / PARTIAL / DEAD / LEGACY / DUPLICATE / INCONSISTENT / UNSAFE /
UNTESTED and carries its disposition. **Open findings at the end of the
audit: 0.** Reviewer: the implementing agent (same-agent; recorded as such).

## 1. Findings and dispositions

| # | Category | Finding | Class | Disposition |
| --- | --- | --- | --- | --- |
| H-1 | Gates | R3, R5, R6, R7 and R8 carried their relocation proofs as live law: R5 pinned 38 Identity files (`auth.service.ts`, `main.ts`, every auth DTO) by normalized hash; R6 pinned the two OTP-transport adapters by raw hash; R7 pinned the normalized source of the 18 relocated Collaboration files, the exact Collaboration file inventory and exact constructor/controller handoffs; R3 pinned the exact Nest module inventory and the exact constructor-use inventory of every public port; R8 pinned the exact sets of PrismaModule and realtime-module importers. Proven by probes: an appended comment in `auth.service.ts` failed R5, in `openwa-transient-text.ts` failed R6, in `collaboration-permission.port.ts` failed R7; an empty new Nest module failed R3 (`inventory-drift`). Ordinary product work in those areas could not pass `npm run architecture`. | UNSAFE (blocks product change) | FIXED: closed mode for R3/R5/R6/R7/R8 reading the R12C closure record — live laws only (spec §19 addendum). Regression: `architecture-governance-portability.test.ts` proves in a clone that a new module, a new port consumer and edits inside Identity/OTP-transport/Collaboration pass every gate, while a project global, a foreign transport consumer, a recreated Identity root, a cross-context injection and a runtime import into Collaboration internals are rejected with named reasons. Suites: R3 55/55, R5 27/27, R6 18/18, R7 218/218, R8 102/102, portability 8 pass / 2 lineage skips. |
| H-2 | Gates | The R3 CLI exited 1 with no output when diagnostics existed (only exceptions printed a line). | BROKEN | FIXED: `FAIL - R3 contexts: N diagnostic(s)` plus a bounded list (20) of `kind path:line`, no source text; regression test added. R5/R6/R7/R8 print their failure reason under `ARCHITECTURE_DEBUG=1`. |
| H-3 | Gates | `architecture:ownership` recognizes Prisma access through the generated client types; in a checkout without `prisma generate` it measured nothing and reported `passed (0 current records)` (observed in the portability clone at the lineage commit). | UNSAFE (environment-dependent gate) | FIXED: the scan fails closed unless `PrismaClient` exported by `@prisma/client` resolves to a declaration inside the generated `.prisma/client`; regression test (RED first) with a stub wrapper whose generated re-export is absent and with a wrapper-declared class. |
| H-4 | Gates | Isolated dependency surface copy failed once under full-suite parallel load with Windows `ERROR_NO_SYSTEM_RESOURCES` (1450); the R8 after-hook then crashed on the undefined surface. | UNSAFE (environment-dependent gate) | FIXED in `fd197a4d` (bounded retry for transient OS errors, fail-fast otherwise, after-hook guard, temp-root cleanup on failure; 3 regression tests). |
| H-5 | Dead transitional code | `backend/scripts/architecture/r12c-strict-candidate.cjs` (no callers, no tests; a run at HEAD would rewrite a frozen manifest and fail every closed gate); `r12b-documentation-transition.cjs` (one-shot R12B documentation activation, completed; R12B closed mode asserts no transition artifacts) and its test file; `backend/scripts/prisma/r2-schema-scope.cjs` and test; `scripts/check-r0-scope.mjs`, `check-r9-scope.mjs`, `check-r10-scope.mjs` and tests (phase changed-path fences against base revisions the tree no longer describes; `npm run architecture:stage` in admin-web printed usage and exited 1). | DEAD | FIXED: removed (11 files, one runner-dependent R12B test, the admin `architecture:stage` script); `docs/qa/README.md` and `ARCHITECTURE.md` no longer list the fences as permanent gates; `docs/SCRIPTS.md` regenerated. The R9/R10 manifests keep the fence paths in their frozen historical changed-path lists (hashed records, not existence checks). |
| H-6 | Disabled/skipped tests | 28 lineage-only tests (R12C 10, R12B 13, R12A 2, R12B-docs 1 — now removed with its file —, portability 2) skip in closed mode with the printed reason; 1 declared Windows POSIX-permission skip (`openwa-credential-file.test.ts`). No `.only`, no `describe.skip`, no silently disabled test. | VALID | Kept: each skip names the lineage commit where the law is re-run; the portability suite re-runs the lineage gates there on every run. |
| H-7 | Test hygiene | R7, R12A, R12B and R12C suites created temp roots without an owning cleanup hook (428 stale `aarast-*` directories were found on this machine at recovery, two of them carrying junctions into the forensic installation); R7 fixtures were built from the *live* Collaboration tree, so the suite itself pinned product bytes. | UNSAFE / INCONSISTENT | FIXED: every temp root goes through a tracked helper removed in `after`; R7 fixtures are built from a shared clone of the lineage commit; R5 fixtures read lineage bytes through Git. Probe: an edit to `auth.service.ts` leaves R5 27/27. |
| H-8 | Duplicates | `mobile/lib/core/offline/local_database_web.dart` was byte-identical to `local_database_factory_stub.dart` (conditional-import pattern). No other content-identical files in `backend/src`, `admin-web/src`, `mobile/lib`, `scripts`. | DUPLICATE | FIXED: the conditional import falls back to the stub for non-`dart:io` platforms; the web file is removed. `flutter analyze` 0 issues, `flutter test` 1,164 pass, strict boundaries legal=159. |
| H-9 | Tracked generated artifacts | `mobile/{linux,windows}/flutter/generated_plugin_registrant.cc` and `generated_plugins.cmake` differed from what the pinned toolchain (Flutter 3.41.7, the CI version) regenerates on every `flutter pub get` (the desktop registrations of `file_selector` and `flutter_secure_storage` are no longer emitted). Desktop targets are not a release target and no document claims desktop packaging. | INCONSISTENT | FIXED: regenerated by the pinned toolchain and committed so the tree is canonical for it; `git status` stays clean after `flutter pub get`. Recorded, not claimed: desktop packaging remains unverified. `docs/SCRIPTS.md`, `API_CONTRACT.md`, `MOBILE_ROUTES.md`, `ADMIN_ROUTES.md` are generated and gated by `docs-sync --check` (drift 0): VALID. |
| H-10 | Stale docs | `docs/project/EXECUTION_PLAN.md` still said "R12B implementation has not begun" in its post-R11 narrative; `docs/qa/README.md` had no section for the gates that run today and listed removed fences as permanent gates. | INCONSISTENT | FIXED: narrative updated; "Current Gates (after the R12C closure)" section added; dated per-phase sections stay as historical receipts (the docs index declares that current sources override historical plans). |
| H-11 | Swallowed errors | AST sweep of every `catch` in `backend/src` (320 files): 8 clauses do not rethrow or log. Each is a documented degradation path: cookie decode → `null`; readiness probe → `down` with latency; request-target sanitizer → redacted; OpenWA delivery-code parse → `null`; push batch → `transientFailure` (retried); media cleanup batch → counted in `failed`; phone normalizer → `false`; OTP channel resolution → generic `otpDeliveryUnavailableError` (comment: channel details are operational secrets). None hides a product failure. | VALID | Kept. |
| H-12 | TODO/FIXME/HACK | 0 markers in `backend/src`, `backend/scripts`, `backend/test`, `admin-web/src`, `mobile/lib`, `scripts` (every `TODO` hit is the `WeddingTaskStatus.TODO` enum value). | VALID | — |
| H-13 | Baselines / ignore lists / exclusions | Dependency baseline: absent (R12C). Ownership baseline `backend/architecture/ownership-baseline.json`: 385/781, exact-subtraction only, the remaining-target design's R13–R18 program; not a hidden violation, it is the measured debt. tsconfig excludes: `node_modules`, `dist` only. No eslint ignore files. Mobile boundaries: strict mode is the gate; the counted baseline mode remains available to the script. | LEGACY (declared) | Kept and reported; retirement is R13–R18 (not remediation). |
| H-14 | Legacy imports / internal access / facades | depcruise 353/1,420/0 without allowance; R3 `illegal=0`, cross-context injections 0; R7 protected-import law 0; no `facade`/`strangler` code; 17 legacy backend roots (admin, budget-categories, catalogs, conversations, dashboard, guests, marketplace, media, money, notifications, onboarding, provider-dashboard, push, tasks, timeline, wedding-costs, wedding-plans) remain as the R13–R17 fate map. | LEGACY (declared) | Kept and reported in the traceability matrix. |
| H-15 | Temp scripts | `backend/scripts/dev/create-admin.cjs`, `backend/scripts/load/load-test.js`, `scripts/dev/*.ps1` are documented developer utilities (`docs/SCRIPTS.md`); no scratch files are tracked (`git ls-files` has no `*.log`, `*.tmp`, `*.bak`, `*.orig`, `build/`, `dist/`). | VALID | — |
| H-16 | Governance code retained at HEAD | The lineage machinery inside the R12A/R12B/R12C/R3/R5/R6/R7/R8 scanners is unreachable while the closure record exists and is exercised only by fixture tests from the lineage commit. It is retained because (a) it is the fail-closed path when the closure record is removed or tampered (proven by the portability probes), and (b) the lineage commit's own copy is what re-runs history. | LEGACY (declared) | Kept; documented in spec §19. |

## 2. Gates after the audit (recovery worktree)

Commits: `75758c70` (R3–R8 closed mode), `01c84217` (ownership fail-closed),
`b3b10f08` (dead tools), `0a0f76ae` (temp hygiene), `96b9451e` (R2 allowlist),
`c3e28463` (mobile dedupe), `f69cb2c9` (desktop registrants), plus this
report's commit.

- `npm run architecture`: 12/12 PASS — R3, R5, R6, R7, R8, R12A, R12B, R12C in
  closed mode; depcruise 353/1,420/0; ownership 385/781; ports 0/0/0/0.
- `npm run check` 0; `npm run security:prisma-config-merge` PASS.
- `npm test` on the complete audit tree: 1,482 tests, 1,454 pass, 0 fail,
  28 skipped (27 lineage-only with printed reason, 1 declared Windows skip).
- `node scripts/docs-sync.mjs --check` drift 0; `node scripts/docs-verify.mjs`
  0/0; `git diff --check` clean.
- Mobile: `flutter analyze` 0 issues, `flutter test` 1,164 pass, strict
  boundaries legal=159.
- Admin: architecture strict 0/0/0/0, typecheck 0, tests 101/101.

**ARCHITECTURE EXIT AUDIT: PASSED (0 open findings).** Declared legacy
(ownership baseline 385/781, 17 legacy backend roots, dormant lineage
machinery) is recorded, not hidden, and is not counted as open.

## 3. What the audit does not claim

- It does not close the modular-monolith target (see the traceability
  matrix): ownership 385/781 and the R13–R20 program remain.
- Reviews are same-agent.
