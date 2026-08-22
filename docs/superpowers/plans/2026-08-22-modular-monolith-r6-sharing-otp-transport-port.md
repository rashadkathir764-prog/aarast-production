# Modular Monolith R6 Sharing OTP Transport Port Implementation Plan

> **Execution rule:** Implement this plan task by task. Every task must end with
> its stated checks and a local checkpoint before the next task begins.

**Goal:** Remove Collaboration's direct dependency on the concrete OpenWA
transient sender by routing invitation delivery through one Identity-owned,
provider-neutral public port without changing invitation, OTP, message,
timeout, status, persistence, metric, or logging behavior.

**Architecture:** Identity owns the public transient-delivery demand contract.
An Identity internal adapter remains the only new consumer of the existing
platform OpenWA transient sender and maps its two concrete delivery errors to
provider-neutral Identity errors. Collaboration imports the Identity public
module and injects only the canonical Symbol token.

**Tech stack:** Node.js 22, TypeScript, NestJS 11, Prisma 6.19.3, Node test
runner, dependency-cruiser, Docker, Flutter/ADB runtime verification.

**Design:** docs/superpowers/specs/2026-08-22-modular-monolith-r6-sharing-otp-transport-port-design.md

## Global Constraints

- Work only in D:\projects\aarast-modular-monolith on branch
  modular-monolith.
- Immutable R6 base is ce0c0d19824bff79d91417e2fe4617914c6bcd70.
- Local commits are allowed by the owner's existing same-branch instruction.
  Do not create or switch branches or worktrees.
- Do not push, merge, mutate a pull request, deploy, or claim remote CI.
- Do not begin R7.
- Preserve every HTTP route, payload, status code, DTO rule, Arabic message,
  delivery status, persistence write, metric, log field, timeout, retry
  behavior, and error identity visible outside the new boundary.
- Do not change Prisma schema, migrations, seed, Mobile, Admin Web, workflows,
  Compose, deployment, OpenWaOtpChannel, or the existing platform transient
  sender.
- Do not move all Sharing source. R6 changes only the named invitation delivery
  dependency and the minimum boundary, tests, scanners, manifests, and docs
  required to prove it.
- Existing behavioral tests are frozen except exact dependency-injection,
  import, and provider-neutral error wiring required by this boundary.
- No compatibility barrel, duplicate sender, fallback import, hidden retry,
  silent failure, or conditional provider selection may be introduced.
- Real OpenWA recipient delivery is externally mutating. Do not run it without
  separate owner confirmation and a dedicated recipient.

## Planned File Responsibilities

| Path | Responsibility |
| --- | --- |
| backend/architecture/r6-sharing-otp-transport.json | Fixed-base R6 paths, forbidden edges, expected debt transition, and protected surfaces |
| backend/scripts/architecture/r6-sharing-otp-transport-scan.cjs | Strict R6 manifest, import, Nest binding, and protected-source gate |
| backend/test/architecture-r6-sharing-otp-transport.test.ts | Positive and adversarial permanent R6 architecture tests |
| backend/src/modules/identity/public/identity-transient-delivery.port.ts | Provider-neutral input, port interface, canonical token, and public errors |
| backend/src/modules/identity/internal/identity-transient-delivery.adapter.ts | One-to-one adapter over the existing platform sender |
| backend/src/modules/identity/internal/identity-transient-delivery.internal.module.ts | Private concrete adapter registration and internal alias |
| backend/src/modules/identity/public/identity-transient-delivery-public.module.ts | Public Symbol-token alias and export |
| backend/src/modules/identity/identity.module.ts | Full Identity module imports the public delivery module |
| backend/src/modules/collaboration/internal/collaboration-services.internal.module.ts | Imports the Identity public delivery module |
| backend/src/sharing/invitation-delivery.service.ts | Injects the Identity port and preserves invitation semantics |
| backend/test/invite-delivery.test.ts | Exact behavior and error-mapping regression coverage |
| backend/architecture/r3-context-boundaries.json | Removes the named Collaboration-to-platform concrete edge from deferred debt |
| backend/scripts/architecture/r3-context-scan.cjs | Recognizes the new Identity public port without weakening R3 |
| backend/test/architecture-r3-contexts.test.ts | R3 boundary regressions for the new public port |
| .superpowers/sdd/2026-08-22-modular-monolith-r6-sharing-otp-transport/task-*-report.md | Ignored local checkpoint evidence |

---

### Task 0: Approve And Checkpoint The R6 Contract

**Files:**

- Create: docs/superpowers/specs/2026-08-22-modular-monolith-r6-sharing-otp-transport-port-design.md
- Create: docs/superpowers/plans/2026-08-22-modular-monolith-r6-sharing-otp-transport-port.md
- Modify: ARCHITECTURE.md
- Modify: docs/README.md
- Modify: docs/project/DECISIONS.md
- Modify: docs/project/EXECUTION_PLAN.md
- Modify: docs/project/STATUS.md
- Modify: docs/qa/README.md

**Produces:** An approved R6 design, executable task order, explicit fixed base,
and an explicit no-R7 boundary. It produces no application behavior change.

- [ ] **Step 1: Verify the immutable preflight**

Run:

    Set-Location D:\projects\aarast-modular-monolith
    git branch --show-current
    git rev-parse HEAD
    git status --short
    git merge-base --is-ancestor ce0c0d19824bff79d91417e2fe4617914c6bcd70 HEAD

Expected: modular-monolith, exact R6 base, empty pre-planning status, and
ancestor exit zero.

- [ ] **Step 2: Record the live inventory**

State exactly: R5 is locally complete; R6 planning is approved; R6 application
implementation has not started; one named Collaboration direct dependency on
the concrete OpenWA transient sender remains; dependency baseline remains 31;
ownership remains 385 records / 781 occurrences; R7 is not authorized.

- [ ] **Step 3: Review the contract**

Run:

    $redFlags = @('T' + 'BD', 'T' + 'ODO', 'implement ' + 'later', 'fill in ' + 'details', 'similar ' + 'to') -join '|'
    rg -n $redFlags docs/superpowers/specs/2026-08-22-modular-monolith-r6-sharing-otp-transport-port-design.md docs/superpowers/plans/2026-08-22-modular-monolith-r6-sharing-otp-transport-port.md
    node scripts/docs-sync.mjs --check
    node scripts/docs-verify.mjs
    git diff --check

Expected: placeholder search has no matches; documentation and whitespace
checks pass.

- [ ] **Step 4: Create the local planning checkpoint**

Stage exactly the eight Markdown paths above, verify the staged path list, and
commit locally:

    git commit -m "docs: approve modular monolith R6 plan"

Verify the commit contains exactly those eight Markdown files. Do not push.

---

### Task 1: Freeze The R6 Scope And Architecture Contract

**Files:**

- Create: backend/architecture/r6-sharing-otp-transport.json
- Create: backend/scripts/architecture/r6-sharing-otp-transport-scan.cjs
- Create: backend/test/architecture-r6-sharing-otp-transport.test.ts
- Modify: backend/scripts/architecture/r3-scope.cjs
- Modify: backend/test/architecture-r3-scope.test.ts
- Modify: backend/package.json
- Modify generated: docs/SCRIPTS.md
- Create ignored: .superpowers/sdd/2026-08-22-modular-monolith-r6-sharing-otp-transport/task-1-report.md

**Produces:** validateR6Manifest, scanR6SharingOtpTransport, and
architecture:r6. No production source changes in this task.

- [ ] **Step 1: Write the manifest validation RED**

Add tests that pin:

- exact base revision;
- exact allowed implementation paths;
- exact current concrete import;
- exact target public token, port, errors, adapter, and Nest modules;
- unchanged protected OpenWA transport and OTP channel hashes;
- unchanged dependency and ownership counts;
- one named deferred R6 debt before cutover and zero after cutover;
- canonical ordering and strict plain-data parsing.

Add adversarial fixtures for unknown keys, duplicate paths, traversal, absolute
paths, wrong base, extra production files, wildcard allowances, altered
protected hashes, permissive token matching, and a second concrete sender.

- [ ] **Step 2: Run the RED**

    Set-Location D:\projects\aarast-modular-monolith\backend
    node --test -r ts-node/register test/architecture-r6-sharing-otp-transport.test.ts

Expected: FAIL because the R6 manifest and scanner do not exist.

- [ ] **Step 3: Implement the smallest strict scanner**

The scanner must:

- parse only strict plain JSON objects and arrays;
- validate the fixed base before filesystem reads;
- resolve imports with the TypeScript compiler rather than text-only matching;
- prove InvitationDeliveryService currently imports the named concrete sender;
- prove no other Collaboration file imports platform/otp-transport;
- prove protected transport and OTP channel bytes remain fixed;
- fail closed on unreadable, unresolved, or ambiguous declarations;
- expose a check mode for package scripts and a library API for tests.

- [ ] **Step 4: Integrate fixed-base scope**

Extend the existing R3 scope gate with the exact cumulative R6 allowlist. Use
no-renames diff semantics so a forbidden deletion cannot be hidden by Git
rename detection. Add tests for same-count substitution, hidden deletion,
renamed protected files, and an unrelated documentation or application path.

- [ ] **Step 5: Wire scripts without weakening prior gates**

Add architecture:r6 and append it to the aggregate architecture command after
R5. Regenerate docs/SCRIPTS.md using the repository generator.

- [ ] **Step 6: Run GREEN and checkpoint**

    node --test -r ts-node/register test/architecture-r6-sharing-otp-transport.test.ts test/architecture-r3-scope.test.ts
    npm run architecture:r6
    npm run architecture
    npm run check
    Set-Location ..
    node scripts/docs-sync.mjs --check
    node scripts/docs-verify.mjs
    git diff --check

Expected: PASS in inventory stage, with production behavior untouched.

Review the exact diff and create a local task checkpoint. Do not push.

---

### Task 2: Introduce The Identity Public Port And Internal Adapter

**Files:**

- Create: backend/src/modules/identity/public/identity-transient-delivery.port.ts
- Create: backend/src/modules/identity/internal/identity-transient-delivery.adapter.ts
- Create: backend/src/modules/identity/internal/identity-transient-delivery.internal.module.ts
- Create: backend/src/modules/identity/public/identity-transient-delivery-public.module.ts
- Modify: backend/src/modules/identity/identity.module.ts
- Modify: backend/architecture/r6-sharing-otp-transport.json
- Modify: backend/scripts/architecture/r3-context-scan.cjs
- Modify: backend/test/architecture-r3-contexts.test.ts
- Modify: backend/test/architecture-r6-sharing-otp-transport.test.ts
- Create ignored: .superpowers/sdd/2026-08-22-modular-monolith-r6-sharing-otp-transport/task-2-report.md

**Public interface:**

    export type IdentityTransientDeliveryInput = {
      phone: string;
      text: string;
    };

    export interface IdentityTransientDeliveryPort {
      send(input: IdentityTransientDeliveryInput): Promise<void>;
    }

    export const IDENTITY_TRANSIENT_DELIVERY_PORT = Symbol(
      'IDENTITY_TRANSIENT_DELIVERY_PORT',
    );

    export class IdentityTransientDeliveryUncertainError extends Error {}
    export class IdentityTransientDeliveryRejectedError extends Error {}

- [ ] **Step 1: Write port and adapter RED tests**

Prove the token is one canonical Symbol, the public module exports only the
token binding, the adapter is singleton-bound with useExisting, the adapter
calls the current sender exactly once with the exact phone/text, maps only the
two known concrete errors, and rethrows the exact unknown error object.

Add negative cases for useClass duplication, a second sender call, retries,
swallowed errors, changed input, provider-specific names in public declarations,
and public imports of OpenWA types.

- [ ] **Step 2: Run the RED**

    node --test -r ts-node/register test/architecture-r6-sharing-otp-transport.test.ts test/architecture-r3-contexts.test.ts

Expected: FAIL because the public contract and adapter do not exist.

- [ ] **Step 3: Add the provider-neutral public contract**

Create only the input, interface, canonical token, and two public delivery
errors. The public file must not import platform, OpenWA, config, Prisma,
logging, Collaboration, or Nest implementation details.

- [ ] **Step 4: Add the narrow internal adapter**

The adapter calls sendOpenWaTransientText once. It maps
OpenWaTransientDeliveryUncertainError to
IdentityTransientDeliveryUncertainError and
OpenWaTransientDeliveryRejectedError to
IdentityTransientDeliveryRejectedError. It rethrows every unknown object
unchanged. It adds no logging, retry, timeout, config branch, mutation, or
transaction.

- [ ] **Step 5: Bind singleton internal and public modules**

The internal module registers the concrete adapter once and exports the
Identity-internal implementation token. The public module imports the internal
module and aliases IDENTITY_TRANSIENT_DELIVERY_PORT with useExisting. The full
Identity module imports the public module without exporting internal providers.

- [ ] **Step 6: Run GREEN and checkpoint**

    node --test -r ts-node/register test/architecture-r6-sharing-otp-transport.test.ts test/architecture-r3-contexts.test.ts test/openwa-otp-channel.test.ts test/openwa-credential-file.test.ts
    npm run architecture:r3
    npm run architecture:r6
    npm run architecture
    npm run check
    npm run build

Expected: all PASS; Collaboration still uses its old dependency until Task 3.
Create a reviewed local task checkpoint and do not push.

---

### Task 3: Cut Collaboration Over To The Identity Port

**Files:**

- Modify: backend/src/sharing/invitation-delivery.service.ts
- Modify: backend/src/modules/collaboration/internal/collaboration-services.internal.module.ts
- Modify: backend/test/invite-delivery.test.ts
- Modify: backend/architecture/r6-sharing-otp-transport.json
- Modify: backend/test/architecture-r6-sharing-otp-transport.test.ts
- Create ignored: .superpowers/sdd/2026-08-22-modular-monolith-r6-sharing-otp-transport/task-3-report.md

**Consumes:** IDENTITY_TRANSIENT_DELIVERY_PORT and
IdentityTransientDeliveryPort.

- [ ] **Step 1: Write the consumer cutover RED**

Add or adapt tests that prove:

- InvitationDeliveryService injects only the canonical Identity token;
- the Collaboration internal module imports the Identity public module;
- no Collaboration source imports platform/otp-transport or provider-specific
  delivery errors;
- disabled/non-OpenWA and missing-phone branches still return before message
  validation/building and before the port call;
- delivered, uncertain, rejected, and unexpected outcomes retain exact status,
  metric, log, persistence, and error behavior;
- create and reissue still persist the same delivery status.

Do not alter existing expected values, Arabic copy, fixtures, or setup except
the exact injection/import wiring.

- [ ] **Step 2: Run the RED**

    node --test -r ts-node/register test/invite-delivery.test.ts test/architecture-r6-sharing-otp-transport.test.ts

Expected: FAIL because the consumer still imports the concrete platform sender.

- [ ] **Step 3: Make the smallest cutover**

Inject IDENTITY_TRANSIENT_DELIVERY_PORT into InvitationDeliveryService and
replace the concrete call with port.send using the exact existing phone and
message. Replace only the two concrete catches with their Identity equivalents.
Preserve branch order, text construction, metrics, logs, statuses, and unknown
error behavior byte-for-byte where possible.

- [ ] **Step 4: Import only the public module**

CollaborationServicesInternalModule imports
IdentityTransientDeliveryPublicModule. It must not import Identity internal or
full modules and must not register the adapter or token itself.

- [ ] **Step 5: Run focused GREEN**

    node --test -r ts-node/register test/invite-delivery.test.ts test/openwa-otp-channel.test.ts test/openwa-credential-file.test.ts test/architecture-r6-sharing-otp-transport.test.ts test/architecture-r3-contexts.test.ts
    npm run architecture:r3
    npm run architecture:r6
    npm run architecture
    npm run check
    npm run build

Expected: all PASS and the concrete Collaboration import is absent. Review and
checkpoint locally. Do not push.

---

### Task 4: Reconcile R3 Debt And Prove Baselines

**Files:**

- Modify: backend/architecture/r3-context-boundaries.json
- Modify: backend/architecture/r6-sharing-otp-transport.json
- Modify: backend/scripts/architecture/r3-context-scan.cjs
- Modify: backend/test/architecture-r3-contexts.test.ts
- Modify: backend/test/architecture-r6-sharing-otp-transport.test.ts
- Create ignored: .superpowers/sdd/2026-08-22-modular-monolith-r6-sharing-otp-transport/task-4-report.md

- [ ] **Step 1: Write debt-transition RED tests**

Pin the exact named Sharing-to-OpenWA deferred debt as one at the R6 base and
zero in the R6 target. Prove the new Collaboration-to-Identity edge resolves
only through the public port declaration and public Nest module.

Add adversarial cases for:

- deleting an unrelated R3 debt;
- adding a new dependency-baseline record;
- changing dependency count from 31;
- changing ownership from 385 records / 781 occurrences;
- importing the Identity internal or full module;
- concrete adapter injection;
- a second public port alias;
- text-only lookalike tokens or providers.

- [ ] **Step 2: Update the R3 manifest narrowly**

Remove only the exact deferred Sharing concrete transport entry. Register the
new Identity public contract/module and the legitimate Collaboration public
consumption. Do not modify any unrelated R3 context, provider edge, or retired
debt.

- [ ] **Step 3: Run all architecture gates**

    node --test -r ts-node/register test/architecture-r3-contexts.test.ts test/architecture-r6-sharing-otp-transport.test.ts
    npm run architecture

Expected:

- 344 current modules unless the new Nest files change the scanner's module
  inventory by the exact manifest-approved delta;
- dependency baseline exactly 31;
- ownership exactly 385 / 781;
- zero illegal edges and cycles;
- zero forwardRef;
- two approved globals;
- R3 contexts 13, platform debt zero, retired provider edges zero;
- R4 and R5 strict gates unchanged;
- R6 named debt zero.

Record exact observed counts, review, and checkpoint locally. Do not push.

---

### Task 5: Verify The Complete R6 Application Candidate

**Files:** No planned product behavior files beyond Tasks 1-4. Any additional
path is a stop signal requiring explicit owner review.

- [ ] **Step 1: Verify scope and protected surfaces**

Run the fixed-base R6 scope gate, protected OpenWA/OTP hashes, R3/R4/R5/R6
scanners, and a Git diff path review. Confirm no Prisma, migration, seed,
Mobile, Admin, workflow, Compose, deployment, or unrelated Sharing path changed.

- [ ] **Step 2: Run Backend quality gates**

    Set-Location D:\projects\aarast-modular-monolith\backend
    npm run architecture
    npm run check
    npm run build
    npm test
    npx prisma validate
    npx prisma generate
    npm audit --audit-level=high
    npm audit --omit=dev

Expected: all PASS with only a previously documented platform-specific
intentional skip, if still applicable. Record exact test totals and audit
findings.

- [ ] **Step 3: Run behavior and managed smokes**

Run the focused invite/OpenWA tests first, then the repository's complete
smoke:all suite using the same environment-aligned managed setup accepted in
R5. Do not run the externally mutating real-recipient OpenWA smoke.

Expected: all managed packages PASS, no secret output, and no managed residue.

- [ ] **Step 4: Run Prisma equivalence and documentation gates**

Use the existing R2-R5 Prisma/DMMF/migration equivalence commands without
changing schema input. Then run:

    Set-Location D:\projects\aarast-modular-monolith
    node scripts/docs-sync.mjs --check
    node scripts/docs-verify.mjs
    git diff --check

- [ ] **Step 5: Review the candidate**

Review architecture, security, error identity, timeout/retry behavior, provider
identity, singleton binding, protected hashes, logs, metrics, transactions,
scope, and rollback. Resolve every Critical or Important finding before
checkpointing. Document Minor findings truthfully.

- [ ] **Step 6: Create the application candidate checkpoint**

Stage only the approved R6 implementation paths, verify the staged list and
diff, create a local commit, record its immutable SHA, and confirm a clean
worktree. Do not push.

---

### Task 6: Bind Immutable Docker And Real Phone Evidence

**Files:** No source changes expected. Evidence reports are ignored local files.

- [ ] **Step 1: Build an immutable R6 image**

Build the Backend image from the exact R6 application candidate and label it
with that full revision. Verify image label, ID, and the included application
revision before starting a probe.

- [ ] **Step 2: Probe without disturbing R5 rollback**

Start an isolated loopback probe with the exact R6 configuration, verify
migration discovery and local live/ready endpoints, then stop the probe. Keep
aarast-backend:r5-final-8cfee451 and the stopped R4 runtime preserved.

- [ ] **Step 3: Protected cutover**

Start the R6 candidate on the approved local/LAN ports. Verify:

- local and LAN /live return 200;
- local and LAN /ready return 200;
- PostgreSQL, Redis, and media readiness are healthy;
- restart count is zero and OOM is false;
- sanitized logs contain no fatal marker or secret.

- [ ] **Step 4: Exercise the authenticated phone journey**

Use an R6-configured local APK or the previously accepted client only after
proving its API base points to the R6 LAN endpoint. Exercise:

1. login and context restore;
2. create a sharing invitation;
3. reissue the invitation;
4. read the related sharing state;
5. close the application fully and reopen it;
6. confirm the dashboard/session and sharing state remain correct.

If AUTH_OTP_MODE does not activate OpenWA invitation sending, record the
provider-disabled status honestly. Do not claim real WhatsApp delivery. A real
recipient delivery test requires separate confirmation and must never expose
the code or phone number.

- [ ] **Step 5: Sanitize and record runtime evidence**

Retain only status codes, route names, counts, timestamps, image/revision
identity, restart/OOM state, and owner PASS/FAIL. Do not retain tokens, phone
numbers, raw bodies, invitation tokens, OTP values, database credentials, or
business data.

---

### Task 7: Close R6 Locally And Stop Before R7

**Files:**

- Create: docs/superpowers/specs/2026-08-22-modular-monolith-r6-sharing-otp-transport-port-completion.md
- Create: docs/superpowers/plans/2026-08-22-modular-monolith-r6-sharing-otp-transport-port-completion.md
- Modify: ARCHITECTURE.md
- Modify: docs/README.md
- Modify: docs/project/DECISIONS.md
- Modify: docs/project/EXECUTION_PLAN.md
- Modify: docs/project/STATUS.md
- Modify: docs/qa/README.md

- [ ] **Step 1: Write exact completion receipts**

Record the R6 base, every local checkpoint, final application candidate, image
ID/tag, observed test counts, architecture counts, audit results, smokes,
runtime health, phone result, rollback state, changed paths, and remaining
uncertainty.

- [ ] **Step 2: State the boundary truthfully**

State explicitly:

- R6 locally complete only if every required gate passed;
- R5 remains the preserved rollback;
- no push, merge, PR mutation, deployment, or remote CI is claimed;
- R7 has not started and requires a separate design and owner approval;
- external Meta/OpenWA production activation remains outside this local
  architecture phase.

- [ ] **Step 3: Re-run final documentation and architecture gates**

    Set-Location D:\projects\aarast-modular-monolith\backend
    npm run architecture
    npm run check
    Set-Location ..
    node scripts/docs-sync.mjs --check
    node scripts/docs-verify.mjs
    git diff --check

- [ ] **Step 4: Create the local closeout checkpoint**

Stage exactly the eight completion-document paths, verify the staged list,
commit locally, and confirm the worktree is clean. Do not push.

- [ ] **Step 5: Stop**

Report R6 status and wait for the owner's next instruction. Do not design or
implement R7 in this task.

## Plan Self-Review Receipt

- Each production edit is tied to the one named R6 dependency.
- Test-first RED/GREEN steps precede every implementation boundary.
- Public contract, adapter, consumer, and debt reconciliation are separate
  checkpoints.
- Prior R3/R4/R5 gates remain cumulative; no baseline is silently reset.
- Runtime and real-phone verification are mandatory before local completion.
- Real OpenWA delivery is correctly classified as an external mutation.
- No step authorizes push, merge, deployment, remote CI, or R7.
