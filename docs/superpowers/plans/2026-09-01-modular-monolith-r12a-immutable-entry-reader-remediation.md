# R12A Immutable Entry Reader Remediation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore the complete R3-R8 strict fixture and live gates by separating candidate-root files from immutable Git-entry reads without fallbacks or copied `.git` workarounds.

**Architecture:** The R12A scanner will own one validated immutable-entry reader with an injectable byte source. R6, R7, and R8 will read live candidate baselines from `repositoryRoot`, but obtain the immutable dependency/ownership entry through that explicit reader; production defaults to bounded `git show` in the supplied repository and tests inject a real-repository reader. The helper validates canonical hashes and counts before any stage projection, so injection cannot broaden accepted candidates.

**Tech Stack:** Node.js CommonJS architecture scanners, TypeScript `node:test`, PowerShell, Git object reads.

**Spec:** `docs/superpowers/specs/2026-09-01-modular-monolith-r12a-backoffice-catalog-public-contracts-design.md`

## Global Constraints

- Repository: `D:\projects\aarast-modular-monolith`; immutable entry HEAD `4d0d3ee91fb32d0432aa3bd69fe018d9a5a323b1`.
- No commit, stage, push, merge, deploy, branch, checkout, reset, worktree, package, migration, schema, seed, mobile, admin-web, or deployment mutation.
- No silent fallback to the scanner checkout and no copied `.git` pointer in fixtures.
- Live CLI behavior remains fail-closed when the supplied repository cannot read the immutable revision.
- Historical R6/R7/R8 manifests and design fixtures retain dependency `22`; only live R12A stages project to `22/17/16`.
- Preserve all negative topology, import, global, ownership, ordering, hash, alias, and drift assertions.

---

### Task 1: Add the validated shared reader and repair R6-R8 strict handoffs

**Files:**

- Modify: `backend/scripts/architecture/r12a-backoffice-catalog-public-contracts-scan.cjs`
- Modify: `backend/scripts/architecture/r6-sharing-otp-transport-scan.cjs`
- Modify: `backend/scripts/architecture/r7-collaboration-relocation-scan.cjs`
- Modify: `backend/scripts/architecture/r8-global-module-removal-scan.cjs`
- Modify: `backend/test/architecture-r12a-backoffice-catalog-public-contracts.test.ts`
- Modify: `backend/test/architecture-r6-sharing-otp-transport.test.ts`
- Modify: `backend/test/architecture-r7-collaboration-relocation.test.ts`
- Modify: `backend/test/architecture-r8-global-module-removal.test.ts`
- Report only: `.superpowers/sdd/2026-09-01-modular-monolith-r12a-backoffice-catalog-public-contracts/task-5-remediation-1-report.md`

**Interfaces:**

- Produces in the R12A scanner:

  ```js
  readR12aImmutableEntry({
    repositoryRoot,
    manifest,
    readImmutableFile, // optional (revision, relativePath) => string | Buffer
  }) => Object.freeze({ dependency, ownership })
  ```

- The default byte source runs only:

  ```text
  git show <validated manifest.repository.baseCommit>:<exact relative path>
  ```

  with `cwd=repositoryRoot`, `windowsHide=true`, bounded buffer, and no shell.
- R6/R7/R8 scan options consume the optional `readImmutableFile` and forward
  it to baseline verification. Candidate baselines still come exclusively from
  the supplied candidate `repositoryRoot`.

- [ ] **Step 1: Write shared-reader RED tests**

Add focused R12A tests that call `readR12aImmutableEntry` with an injected
reader and independently assert:

```ts
assert.deepEqual(calls, [
  [manifest.repository.baseCommit, 'backend/.dependency-cruiser-known-violations.json'],
  [manifest.repository.baseCommit, 'backend/architecture/ownership-baseline.json'],
]);
assert.equal(entry.dependency.length, 22);
assert.equal(entry.ownership.violations.length, 385);
assert.equal(entry.ownership.violations.reduce((sum, item) => sum + item.count, 0), 781);
```

The tests must also reject a non-function reader, wrong return type, invalid
JSON, changed dependency metadata, changed ownership semantics/count, wrong
hash, and a throwing injected reader without falling back to Git.

- [ ] **Step 2: Write consumer RED tests**

Before scanner implementation:

- R6 temporary strict fixtures pass an injected reader and must reach the
  intended concrete-import diagnostic instead of immutable-entry-unavailable.
- R6 stage projection uses immutable entry `22`, then asserts `22/17/16`.
- R7 central fixture scan options pass the injected reader. Generic historical
  `stagedFixture` writes R12A `stage=design`; the dedicated R12A staged fixture
  selects `design/backoffice/strict` explicitly and contains no copied `.git`.
- R8 baseline tests pass the injected reader; its ownership projection starts
  from immutable ownership, not the already-projected live file.

- [ ] **Step 3: Run RED and confirm the boundary failure**

Run from `backend`:

```powershell
node --test -r ts-node/register test/architecture-r12a-backoffice-catalog-public-contracts.test.ts test/architecture-r6-sharing-otp-transport.test.ts test/architecture-r7-collaboration-relocation.test.ts test/architecture-r8-global-module-removal.test.ts
```

Expected before implementation: injected-reader tests fail because the shared
API/forwarding does not exist; at least one strict non-Git fixture still fails
at immutable-entry acquisition instead of its intended law.

- [ ] **Step 4: Implement `readR12aImmutableEntry` minimally**

Implement and export the exact interface above. Validate the manifest with
`validateR12aManifest`, require an absolute repository root, allow only the
optional function dependency, read only the two exact baseline paths, parse
plain JSON, then verify:

```text
dependency records = manifest.entry.dependencyRecords = 22
dependency canonical SHA-256 = manifest.entry.dependencySha256
ownership records = manifest.entry.ownershipRecords = 385
ownership occurrences = manifest.entry.ownershipOccurrences = 781
ownership canonical SHA-256 = manifest.entry.ownershipSha256
```

Return frozen entry data. Reuse this helper inside the R12A live scanner so
the primary gate and historical consumers share one immutable-entry contract.

- [ ] **Step 5: Integrate R6, R7, and R8**

Replace their direct R12A `git show` reads with the shared helper and forward
the optional reader through the scan/baseline boundary. Keep default CLI calls
reader-free so the shared helper performs bounded Git reads from the supplied
repository. R7 must also replace its scanner-checkout ownership fallback with
the same explicit reader; no candidate-root failure may fall back elsewhere.

For every R12A stage, compare the live candidate to the exact projection from
the validated immutable entry:

```text
design dependency=22 ownership=385/781
backoffice dependency=17 ownership=385/781
strict dependency=16 ownership=385/781
```

- [ ] **Step 6: Correct only live strict expectations**

- R7 live-root result and scope assertions use dependency `16`; generic
  historical fixture assertions remain `22`.
- R7 projection tests start from immutable `22`.
- R8 immutable ownership test starts from entry ownership. R8 live strict
  result and CLI message use dependency `16`; historical manifest/result
  validator assertions remain `22`.
- Do not change expected diagnostic identities unrelated to the baseline
  acquisition boundary.

- [ ] **Step 7: Run focused GREEN gates**

Run each file separately, then together:

```powershell
node --test -r ts-node/register test/architecture-r12a-backoffice-catalog-public-contracts.test.ts
node --test -r ts-node/register test/architecture-r6-sharing-otp-transport.test.ts
node --test -r ts-node/register test/architecture-r7-collaboration-relocation.test.ts
node --test -r ts-node/register test/architecture-r8-global-module-removal.test.ts
node --test -r ts-node/register test/architecture-r12a-backoffice-catalog-public-contracts.test.ts test/architecture-r6-sharing-otp-transport.test.ts test/architecture-r7-collaboration-relocation.test.ts test/architecture-r8-global-module-removal.test.ts
```

Expected: every test PASS; zero skipped/cancelled/todo.

- [ ] **Step 8: Re-run the exact Task 5 focused architecture gate**

```powershell
node --test -r ts-node/register test/architecture-dependencies.test.ts test/architecture-ports.test.ts test/architecture-r3-contexts.test.ts test/architecture-r3-scope.test.ts test/architecture-r5-identity-relocation.test.ts test/architecture-r6-sharing-otp-transport.test.ts test/architecture-r7-collaboration-relocation.test.ts test/architecture-r8-global-module-removal.test.ts test/architecture-r12a-backoffice-catalog-public-contracts.test.ts
```

Expected: all PASS. If another first failure remains, stop and report it; do
not broaden this remediation.

- [ ] **Step 9: Run non-regression gates**

```powershell
npm run architecture
npm run check
npm run build
node --check scripts/architecture/r12a-backoffice-catalog-public-contracts-scan.cjs
node --check scripts/architecture/r6-sharing-otp-transport-scan.cjs
node --check scripts/architecture/r7-collaboration-relocation-scan.cjs
node --check scripts/architecture/r8-global-module-removal-scan.cjs
git diff --check
```

Expected: PASS at strict dependency `16`, ownership `385/781`.

- [ ] **Step 10: Write the remediation report**

Record exact RED/GREEN counts, files changed, reader calls/hash validation,
fixture changes, every command and exit code, remaining uncertainty, and
no-Git/no-deploy confirmation in `task-5-remediation-1-report.md`.
