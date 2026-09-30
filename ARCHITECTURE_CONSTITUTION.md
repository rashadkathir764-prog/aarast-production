# Aarast Architecture Constitution

This is the binding statement of the **implemented** modular-monolith laws at
proven commit `6a6ce5c4a9a4d9b48db6e1eee4d4a7567385bd1b`. It is a floor for
later work, not a proposal to restart R0–R20. The original design and
`ARCHITECTURE.md` explain the migration history; the live schema, source, owner
registry, and strict gates determine whether a proposed change still obeys
these laws. A contradiction is a finding to investigate, never permission to
silently weaken a gate.

## Binding laws

| ID | Current law |
| --- | --- |
| L01 | Every Prisma model/table has exactly one physical owner. `backend/architecture/ownership-registry.json` maps the current 52 models to the 13 business contexts and platform; Insights owns no table. Root delegates, relations, nested writes, and SQL count as physical access. |
| L02 | A business owner's Prisma implementation belongs only in `backend/src/modules/<owner>/infrastructure/`. Application, internal, domain, API, and public code use the owner's repository/port. Platform is itself infrastructure for its two owned models. Generated Prisma types alone do not constitute database access. |
| L03 | No context executes a foreign owner's Prisma access. The owner performs the operation, including within a caller-supplied transaction when the existing behavior requires it. |
| L04 | Cross-context consumption uses the target owner's `public/` contract or port. Preserve the caller's transaction, authorization snapshot, and lock order where the contract requires them. |
| L05 | No direct import of another context's domain, internal, infrastructure, API, or full module. A public contract does not authorize copying its business logic into a consumer. A public slice may import another owner's public slice only for types. |
| L06 | Finance domain policies remain pure: no Nest runtime, runtime Prisma client, or persistence-layer dependency. The existing money invariants stay in Finance domain policy and services map violations to the established API errors. |
| L07 | Project-owned `forwardRef()` count remains zero. |
| L08 | TypeScript dependency cycles and Nest module cycles remain zero. |
| L09 | Illegal globals and imports remain zero. Project-owned `@Global()` modules are forbidden; platform and shared-kernel dependency direction remains enforced. Dependency-owned Nest globals are outside this count. |
| L10 | Use the existing owner `PublicModule`/full-module split where a contract is exposed. Consumers import the public module/token, not the owner's full or private module. Do not impose a new split on an area that does not need one. |
| L11 | Mobile feature boundaries remain strict: cross-feature consumption goes through the owner feature API; the narrow core routing composition edge remains the only declared core-to-feature composition edge. Cross-area `part` relationships and unresolved local directives fail. |
| L12 | Admin feature/API, auth, component, page, and composition boundaries remain strict as implemented by the Admin boundary gate. |
| L13 | No baseline, ignore, allowance, or exception may hide a live violation. Backend dependency and ownership debt are zero without live baselines. The retained R9 Mobile historical baseline is a lineage record; strict Mobile mode cannot use it to permit a violation. |
| L14 | Never weaken, bypass, or turn a failing architecture gate into a warning to obtain a green build. A gate defect requires a failing negative proof and the smallest correction. |
| L15 | Never change a behavioral test assertion, fixture, or expected result merely to make a defect appear correct. An approved behavior change needs its own decision and truthful regression proof. |
| L16 | Published migrations are immutable. The 76 migrations and migration lock in the proven baseline are pinned by the published-migration gate; a newly approved migration is added and pinned, not used to rewrite history. |
| L17 | Route paths, methods, auth, DTOs, responses, errors, Arabic copy, permissions, schema, transaction scope, lock order, Mobile/Admin routes, and deployment behavior must not change accidentally. Intentional changes require explicit scope, approval, and matching tests/docs. |
| L18 | Architecture gates must work in clean checkouts and worktrees with different names, paths, and branches. No absolute workspace path, dirty-tree check, or current-branch name may be a condition for PASS. |
| L19 | The proven architecture is the protected baseline. Optional redesign, naming, layout, or performance preferences do not reopen the modular-monolith mission. |

The ownership registry, not a copied table in this document, is the current
model-to-owner map. The historical `WeddingPlan.estimatedBudget` E1 note in the
original design is **not** a present-day foreign-owner permission: Finance calls
Planning's public budget-write port and Planning performs the Prisma update.
Backoffice permission consumers use its public contract; the former
Catalog-to-Backoffice-domain carveout is retired.

The published-migration hashes represent canonical Git LF text. The gate
normalizes Windows CRLF checkout conversion before comparison; it still
rejects a changed SQL statement, a missing migration, or an unpinned addition.

## Agent operating protocol

For Claude, Codex, and any other agent, before an authorized code change:

`UNDERSTAND` → `IDENTIFY OWNER` → `IDENTIFY PUBLIC CONTRACT` → `CHECK EXISTING TESTS` → `MAKE ISOLATED CHANGE` → `RUN FOCUSED TESTS` → `RUN ARCHITECTURE GATES` → `REVIEW DIFF` → `COMMIT`

Confirm the task's scope and repository instructions first. Do not work
directly on `main`; use an isolated worktree for significant work and verify
its base SHA and clean status. Do not infer ownership or contracts from folder
names or comments alone: inspect the registry, actual imports, ports, source,
and tests. Keep owner boundaries and business logic single-sourced. Do not
create a new exception without an explicit owner decision. Do not alter the
architecture because of personal preference. `COMMIT` applies only when the
user has authorized Git work and all required gates are green; it does not
authorize push, merge, or deployment.

For Backend boundary changes, run `npm run architecture` from `backend/` and
the affected tests. For Mobile run the strict boundary script and its tests;
for Admin run its architecture script and contract tests. Run affected
behavior tests, docs checks, and `git diff --check` before a commit. Review the
diff for test weakening, hidden allowances, migration edits, API changes, and
unrelated files. A passing scanner alone is not evidence of behavior parity.

## Finding classification

| Class | Meaning |
| --- | --- |
| `BUG` | A reproducible defect in current behavior. It reopens this mission only when it proves a binding architecture invariant is broken. |
| `MISSING REQUIREMENT` | An explicit original modular-monolith requirement remains unmet in the current code. |
| `ARCHITECTURE VIOLATION` | A reproducible breach of one of the binding laws, with a source path, dependency, ownership record, or runtime proof. |
| `FALSE-GREEN GATE` | A gate reports PASS for a violation it is responsible for catching, proven by a negative case. |
| `OPTIONAL IMPROVEMENT` | A preference or enhancement without a breached requirement or invariant. It is not a blocker and does not reopen the mission. |

Reopen Modular Monolith only for a missing original requirement, a
reproducible bug that breaks an invariant, a real architecture violation, or a
proven false-green gate. Record evidence before proposing a fix.

## Ratchet

The current zero-violation state is the floor. Do not increase violations,
regenerate a baseline, add an ignore to mask a violation, increase skipped
tests without a reviewed reason, turn FAIL into a warning, relax a scanner,
restore direct Prisma outside the owner's infrastructure, or restore a deep
cross-context import. Preserve the existing negative tests when changing a
gate. A new legitimate exception needs an explicit approval, a narrow scope,
a written reason, a protecting test, and a removal plan if temporary. It may
never be disguised as a baseline entry.

## Law-to-gate protection

`Protected` distinguishes executable checks from decisions that require
human review. The latter cannot be inferred reliably from source text alone.

| Law | Existing gate/test or required control | Protected? |
| --- | --- | --- |
| L01 | `architecture:ownership`; owner registry/schema equivalence tests | Yes — machine |
| L02 | `architecture:ownership`; owner-outside-infrastructure negative fixture | Yes — machine |
| L03 | `architecture:ownership`; foreign-owner and SQL/relation negative fixtures | Yes — machine |
| L04 | `architecture:imports`, `architecture:ports`, R3/R12C contracts; transaction/lock behavior tests | Yes — machine plus behavior tests |
| L05 | dependency-cruiser cross-context rules; Catalog-to-Backoffice-domain negative test; ports scan | Yes — machine |
| L06 | dependency-cruiser `domain-no-nest-runtime` and `domain-no-runtime-prisma`; Finance policy tests | Yes — machine |
| L07 | `architecture:ports`, R3/R8 | Yes — machine |
| L08 | dependency-cruiser `no-circular`; ports Nest-cycle detection and negative tests | Yes — machine |
| L09 | `architecture:ports`, R3/R8, platform/shared-kernel import rules | Yes — machine |
| L10 | `architecture:ports`, R3 and owner public-contract tests | Yes — machine |
| L11 | `node scripts/check-mobile-boundaries.mjs --strict`; boundary contract tests | Yes — machine |
| L12 | Admin `npm run architecture`; `npm run test:architecture` | Yes — machine |
| L13 | strict ownership/closed dependency gates; strict Mobile gate and baseline-integrity tests | Yes — machine for violations; review gate diffs |
| L14 | negative architecture tests and mandatory review of scanner/CI diffs | Yes — machine proof plus review of changes |
| L15 | existing behavioral suites and mandatory assertion/fixture diff review | Yes — behavior tests plus review of intent |
| L16 | `architecture:migrations`; published-migration negative tests | Yes — machine |
| L17 | docs-sync, docs-verify, API/route tests, smokes, concurrency tests, and explicit change review | Yes — tested contracts plus review of intent |
| L18 | architecture governance portability test; path/branch-independent gate inputs | Yes — machine |
| L19 | this constitution, `AGENTS.md`, CI architecture gates, and scope review | Yes — governance plus machine boundary checks |

The machine cannot decide whether a changed assertion, skipped test, API
behavior, or exception was *approved*. That decision remains a mandatory
review step; it is not a reason to weaken an executable boundary gate.
