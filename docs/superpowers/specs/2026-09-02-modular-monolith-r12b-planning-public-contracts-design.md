# Modular Monolith R12B Planning Public Contracts Design

**Status:** APPROVED FOR IMPLEMENTATION PLANNING; SOURCE IMPLEMENTATION NOT STARTED  
**Date:** 2026-09-02  
**Repository:** `D:\projects\aarast-modular-monolith`  
**Branch:** `modular-monolith`  
**Immutable Git base:** `4d0d3ee91fb32d0432aa3bd69fe018d9a5a323b1`

## Decision Summary

R12B retires only dependency records `7-9`, `11`, `18`, and `21-22` from the
post-R12A ledger. It publishes the existing Planning-owned wedding-location
implementation from `modules/planning/public` by one-to-one relocation, rewrites
the five cross-context consumers plus Planning's own consumer and the focused
behavior test, and re-expresses the two nested local-import DTOs inside the
Planning-owned Onboarding root.

The phase changes dependency debt from `16` to `9`. Ownership remains exactly
`385` records / `781` occurrences. It creates no DI port, forwarding facade,
duplicate runtime implementation, compatibility layer, schema change, route,
payload, validation, error, permission, transaction, lock-order, Arabic, Mobile,
Admin Web, Docker, Compose, or deployment behavior change. The package lock
changes only through the exact owner-approved qs security prerequisite receipt
defined below; that receipt changes no Product Logic or parent dependency.

## Authority And Composite Entry

R12B starts from a composite local entry because the owner deliberately did not
authorize a Git commit for R11 or R12A:

- Git root: `D:/projects/aarast-modular-monolith`.
- Branch: `modular-monolith`.
- HEAD: `4d0d3ee91fb32d0432aa3bd69fe018d9a5a323b1`.
- Preserved R11/R12A overlay: exactly `65` paths.
- Overlay fingerprint: `30e2de6928edd7ac1b44598fae4ad18dbcd452b34f7e9a6fb792e1936ce8561c`.
- Post-R12A dependency baseline SHA-256:
  `4dd61610c6583e369b836b3b0fe80ffc63153e70a0fbe86a089509962b35c71e`.
- Post-R12A ownership baseline SHA-256:
  `5f42f33300a9727f587e62327c5261a88a6ce5928437241c9e7c20f726906496`.
- R12A manifest SHA-256:
  `b2904ef15dd104da8cc27315d89880b75042a6175df3a756897b0b45e4a269fd`.

The overlay fingerprint is calculated from sorted
`<porcelain-status>|<forward-slash-path>|<live-sha-or-DELETED>` entries for
`git status --porcelain=v1 -uall`. The R12B design and plan are additional
approved documentation paths and are not folded back into the 65-path R12A
fingerprint.

The implementation scanner must reconstruct and validate the R12A predecessor
through its manifest and immutable Git base. It must not copy a `.git` folder,
read another worktree, accept a fallback snapshot, or silently replace the
composite entry with the mutable working tree.

### Complete 65-path predecessor preimage

The manifest must embed every row below as structured data with the exact
two-character porcelain status, forward-slash path, and content SHA-256 (or the
literal `DELETED`). This is the preimage of the overlay fingerprint above:

```text
 D|backend/src/admin/admin-mutation-gate.ts|DELETED
 D|backend/src/admin/admin-permission.decorator.ts|DELETED
 D|backend/src/admin/admin-permission.guard.ts|DELETED
 D|backend/src/admin/admin.guard.ts|DELETED
 D|backend/src/marketplace/provider-review-rating.ts|DELETED
 M|ARCHITECTURE.md|f831577a63cd50537c35b78a160fabfa99317a0e5327a2a5d9035e87892910da
 M|backend/.dependency-cruiser-known-violations.json|4dd61610c6583e369b836b3b0fe80ffc63153e70a0fbe86a089509962b35c71e
 M|backend/.dependency-cruiser.cjs|496efadf8629e80a6c61cdf8179e1287a2fbb81c1fd9659c618ba4fb6caeec04
 M|backend/architecture/ownership-baseline.json|5f42f33300a9727f587e62327c5261a88a6ce5928437241c9e7c20f726906496
 M|backend/package.json|43a685312a0ddd9904f99a7cd9ff2fa1d20aa163415f623858a7998ff74e2044
 M|backend/scripts/architecture/ports-scan.cjs|1539c1c9e12277401f6612775b45088df1a9916523712f42d60a7b2c85ef3182
 M|backend/scripts/architecture/r3-context-scan.cjs|4e9355858416a3475ccf8d16c8c659a299df1e39a62ba4d80d58cc29896254bb
 M|backend/scripts/architecture/r5-identity-scan.cjs|a94cb81765c1e395a36c605f1f9f642ec16333870b7769e9af2bac9900340492
 M|backend/scripts/architecture/r6-sharing-otp-transport-scan.cjs|3a3638adae8902d8b1ffd9e6281f544907496555b77a848639dedc69bc5e20d2
 M|backend/scripts/architecture/r7-collaboration-relocation-scan.cjs|2adf51070927fd46f82894f6512ffbe31f43a298fc8f314c03eb5016805de818
 M|backend/scripts/architecture/r8-global-module-removal-scan.cjs|72cd9259b4a2d16f33669042788f3d387cb6feb6045aad83c5c3fec59c973eb1
 M|backend/scripts/security/prisma-config-merge-security.cjs|5050a7ac3e5cf584bee5152b5789bd3101465bc87444f22552a4864f373911c8
 M|backend/scripts/smoke/phase2-provider-dashboard-concurrency-smoke.ts|3903d9eb223481442a1252a64c3423721ddb74bd45f5f05b9f6c3260a5d1a88d
 M|backend/scripts/smoke/phase2-provider-rating-concurrency-smoke.ts|2b686e2c9e18f9c05933a960e2e65375c9802db1ba574bbfcc7db6849fa64ffc
 M|backend/src/admin/admin-audit.controller.ts|dcbb59262195f19877219a58c96be72d57b14faac1a303ce260d5ec9a274cabd
 M|backend/src/admin/admin-mutation-executor.ts|6a3880d53ed4666ba096817be1cf39d56c3c2a28d84517e720319edd505601fb
 M|backend/src/admin/admin-user-status.ts|212d6b1ab4a7df70b939e8314f26e8f9c23fe67bddeed8674908870f72fea664
 M|backend/src/admin/admin.controller.ts|b22c39bcad4d3694ecdf59eae51e4529d9064d7831ce6e3ed08aa38c29abbf85
 M|backend/src/catalogs/administrative-catalog.service.ts|8683e817fd895a9f518ecbe23395244fb1b1c3676d11f550fc588c257eed543f
 M|backend/src/catalogs/catalogs.controller.ts|f7c1784ca8343e6d79a9e3ad09f8f7341df1fcdd145f1418cad002560e7cc840
 M|backend/src/catalogs/reference-catalog.service.ts|4d0dc0c79800537534849e0441b8b9a26a20dc168115ddbecafd2fefc81d1ea7
 M|backend/src/marketplace/marketplace.service.ts|51d5f6412c10763bd11b60540203d59fac77e594edaf9de24b376f48e22721a1
 M|backend/src/modules/identity/internal/profile/users.service.ts|0db5c90531747da8d43548df8764f3ba892a4aa591a85cf62c057b84a01e71b9
 M|backend/test/admin-auth-session-security.test.ts|222a7d78e5c7707547c53719e21f9cced4d8052c07cd58d547329fe9d83de491
 M|backend/test/admin-mutation-authorization.test.ts|7a643f043a70beefa64ad88292f4575d99772ce1dbab573665ed986f8f9c4611
 M|backend/test/admin-rbac-audit.test.ts|d346fa54dce9768dcf47b0a249b9afc956f9f010925571dc5e1b01eb302ec9a2
 M|backend/test/architecture-dependencies.test.ts|f96cea9c75534044c7d43066c72eaf37cf71380aad29f76cd680f417c751b7a2
 M|backend/test/architecture-ports.test.ts|fa0296ebd6fe7be5d6f7653eee424bd7860255399449dce5b87e16efe53e5f36
 M|backend/test/architecture-r3-contexts.test.ts|65b1424d37760724ef7cc5a2671cea0bb8f685114ba71c97f7503f13a876b065
 M|backend/test/architecture-r3-scope.test.ts|c38b7533dc838b4e474364a3ec66e05715000bf058334b64ea5892e70b7ef90d
 M|backend/test/architecture-r4-planning-finance-boundary.test.ts|ae49fcd3d2fd86bfe6ff2349a3609943087d8e485a2d69fe5fdd06343205353d
 M|backend/test/architecture-r5-identity-relocation.test.ts|d71483a026051e8d5d4ac134c1a4830a63055e47f8d4c985cbc63358310a3662
 M|backend/test/architecture-r6-sharing-otp-transport.test.ts|f17808b4ba93fca092d8a8edc0739a67b3d1504bb4cfbb2a69868c3b63e02477
 M|backend/test/architecture-r7-collaboration-relocation.test.ts|baf4acf775fa3a64e55b6d09515f02ada1c30095cd594ab0740784f6070a6e85
 M|backend/test/architecture-r8-global-module-removal.test.ts|a033fe9484fdd61f6aebe6a7f33847248bb9f12a2ae2ce1acace08774e987b3f
 M|backend/test/prisma-config-merge-security.test.ts|0b8f0af5256c6b6b9d8ebaa8ac664a8a1dee732c9845146f73ecf221b4f25d80
 M|backend/test/provider-rating-atomicity.test.ts|74585e67e2ec4d7933f38e7f8f92e849d7a3c321d2c33da2e0998f3fcceee4e3
 M|backend/test/sharing-reinvite-authority.test.ts|964bebecd5c8fd299c1c8625215b48e8087c3f8e60c5e255765ad78567f1bba0
 M|CHANGELOG.md|5b86073af49e1f1b05f2d788a376d3d3bc386dfec93b46e7cbfbffac86b3568b
 M|docs/project/DECISIONS.md|f2ece280a72c5fad31a626a9c0962ca627c33073cdf7ba93fba4c8deb44a1601
 M|docs/project/EXECUTION_PLAN.md|8f46c6ae9112d899a2c9ea97fdc4ca3a36c48ab09c715bc68aff1d570ead72a8
 M|docs/project/STATUS.md|0e5740f2c22106235c1618459b60dd2462a5a45a9dfd65c59a7752d91b437831
 M|docs/README.md|546dee5d63b03fda63ad9e976af85852c63976e8eb0e48eedf6c460444bcdfb5
 M|docs/SCRIPTS.md|975f628fe69bb77cc8237e5929808705a7ad8ee766813b762dd5c6413b34d1d2
??|backend/architecture/r12a-backoffice-catalog-public-contracts.json|b2904ef15dd104da8cc27315d89880b75042a6175df3a756897b0b45e4a269fd
??|backend/scripts/architecture/r12a-backoffice-catalog-public-contracts-scan.cjs|e69b3b2bb52a806df821d57243d7b551f2e7478b70d2624873f8b828c7bf0a9e
??|backend/src/modules/backoffice/public/admin-mutation-gate.ts|ed67b8c511b1cadad882f7170cae9a4c9442955c5b925c6c9f3519d821d26389
??|backend/src/modules/backoffice/public/admin-permission.decorator.ts|c0147df52be408ab745cbb96e891098fcd68eaa68a010efe32ebe260926fe2c2
??|backend/src/modules/backoffice/public/admin-permission.guard.ts|3be18a4b9f43ee6040b58ebfa46bd3e4d7c34a1fd0e85aa26341faab9088c4e5
??|backend/src/modules/backoffice/public/admin.guard.ts|4bee3dbc5c4167378ffa741d104c78ace9ea00714e23356d45bde4084cfbb2db
??|backend/src/modules/marketplace/public/provider-review-rating.ts|fdd12341d7b05298adb38fdb05e9232298045b00422b3815aa2a1df3380774d9
??|backend/test/architecture-r12a-backoffice-catalog-public-contracts.test.ts|3231763b3e607e72911082c1ad306d48b61b96582ac627b11da924664dd23999
??|docs/superpowers/plans/2026-09-01-modular-monolith-r11-target-reconciliation.md|c2e02ddbf86a5849f088cb01bd9389c6f11aca0f71df98b951c3d994dcf4a37e
??|docs/superpowers/plans/2026-09-01-modular-monolith-r12a-backoffice-catalog-public-contracts.md|45e16c81966659073b135296871a63735c6feba5253e9cb562a47f5bca45b09b
??|docs/superpowers/plans/2026-09-01-modular-monolith-r12a-immutable-entry-reader-remediation.md|2aa92b61cb263b52891634c538cf1aa2eba23cbe2a7ab3b0ea633789a34c0d8d
??|docs/superpowers/plans/2026-09-02-modular-monolith-r12a-task5-full-test-remediation.md|0c97663c3bfb6cef4c0f3e5e52242cfa9c5c063f84e1c3c78e0e2f3a25877b63
??|docs/superpowers/reports/2026-09-01-modular-monolith-r11-reconciliation-report.md|788e2c3c3b89ff100be1dccd18ff65bc1762c88884f1233fa1e9c72e3d6efc4a
??|docs/superpowers/reports/2026-09-01-modular-monolith-r12a-backoffice-catalog-public-contracts-report.md|5994bb7d09b1aabc498ae4a32482568ef60cbd0e9d337641f38384ce273a48c7
??|docs/superpowers/specs/2026-09-01-modular-monolith-r12a-backoffice-catalog-public-contracts-design.md|c058b288cd5c6eff6a1d039b2902725ea11bf78360398859a1b8c0fe7ac7516c
??|docs/superpowers/specs/2026-09-01-modular-monolith-remaining-target-design.md|10a405fa5adb666be517d9f17f45972af854d281534bccfa2ccaa464508bea69
```

Before Task 1 creates any governance file, a read-only script must reproduce
all 65 rows and the aggregate fingerprint. After R12B files exist, the scanner
must project the working tree back to this preimage. Each predecessor path is
either byte/status unchanged or has one manifest-declared inverse transform
whose normalized result matches the row hash above. R12B-only new paths must
match an exact allowlist and their own manifest/hash contracts before they are
removed from the predecessor projection.

The aggregate fingerprint algorithm is exact: serialize each row as
`status|path|sha256-or-DELETED`, preserve the table order, join the 65 rows with
one UTF-8 LF byte between rows, append no final newline, and hash those bytes
with SHA-256. The result must be
`30e2de6928edd7ac1b44598fae4ad18dbcd452b34f7e9a6fb792e1936ce8561c`.

Every inverse transform is registered and hash-pinned in the R12B scanner
before its target file is edited. Supported transform kinds are restricted to:

- exact module/literal rewrite with declared old/new text and occurrence count;
- exact one-to-one move restoring the old path and deleting the new path;
- exact dependency-record subtraction restoring full reviewed records at their
  original ordinals;
- exact package-script projection restoring the R12A aggregate;
- exact bounded multi-hunk replay for the 15 declared cumulative scanner/test
  handoff paths, under the schema-version-2 correction below;
- generated/narrative documentation transition with explicit entry, candidate,
  and activated hashes registered before either target publication.

Documentation transforms use a separate fail-closed state machine while the
dependency stage remains `strict`:

```text
entry                -> target bytes must match entrySha256
candidate-prepared   -> target bytes still match entrySha256; candidateSha256
                        and activatedSha256 are already registered
candidate            -> target bytes match candidateSha256
activation-prepared  -> target bytes still match candidateSha256 and the
                        re-rendered activation bytes match activatedSha256
activated            -> target bytes match activatedSha256
```

At the original design/implementation stages, every documentation transform is
present with `entrySha256` and explicit null candidate/activated hashes. Before
Task 6 touches a target, both candidate and activated bytes are rendered outside
the repository, their hashes replace those nulls, and the manifest moves to
`candidate-prepared`. Missing hashes, hashes derived after target publication,
invalid state transitions, or bytes inconsistent with the current state fail.

The state cannot be asserted from a final snapshot alone. The manifest therefore
contains an append-only `documentationTransitions` chain with exactly these four
ordered transitions:

```text
1  entry               -> candidate-prepared
2  candidate-prepared  -> candidate
3  candidate            -> activation-prepared
4  activation-prepared -> activated
```

Each receipt contains exactly `sequence`, `from`, `to`,
`previousReceiptSha256`, the seven explicitly ordered
`beforeDocuments`, `afterDocuments`, `candidateDocuments`, and
`activatedDocuments` path/hash arrays, plus `receiptSha256`. Receipt SHA-256 is
computed by `JSON.stringify` with no replacer or spacing, encoded as UTF-8
without BOM or final newline, using that fixed top-level field order and
excluding only `receiptSha256`. Every document array uses this literal path
order—never `sort`, `localeCompare`, case folding, or host locale:

```text
ARCHITECTURE.md
CHANGELOG.md
docs/project/DECISIONS.md
docs/project/EXECUTION_PLAN.md
docs/project/STATUS.md
docs/README.md
docs/SCRIPTS.md
```

Every array element is an object whose keys occur exactly as `path` then
`sha256`. The first previous hash is the pinned genesis
`e60fbd3d8820a9bfa00199937e0ce44025a32a73f41454786a3d53aef1adf4ad`;
later receipts point to the immediately preceding receipt. The complete genesis
preimage is this single literal line; hash exactly its UTF-8 bytes with no BOM
or trailing newline:

```json
{"phase":"R12B","baseCommit":"4d0d3ee91fb32d0432aa3bd69fe018d9a5a323b1","documentationStage":"entry","documents":[{"path":"ARCHITECTURE.md","sha256":"f831577a63cd50537c35b78a160fabfa99317a0e5327a2a5d9035e87892910da"},{"path":"CHANGELOG.md","sha256":"5b86073af49e1f1b05f2d788a376d3d3bc386dfec93b46e7cbfbffac86b3568b"},{"path":"docs/project/DECISIONS.md","sha256":"f2ece280a72c5fad31a626a9c0962ca627c33073cdf7ba93fba4c8deb44a1601"},{"path":"docs/project/EXECUTION_PLAN.md","sha256":"8f46c6ae9112d899a2c9ea97fdc4ca3a36c48ab09c715bc68aff1d570ead72a8"},{"path":"docs/project/STATUS.md","sha256":"0e5740f2c22106235c1618459b60dd2462a5a45a9dfd65c59a7752d91b437831"},{"path":"docs/README.md","sha256":"546dee5d63b03fda63ad9e976af85852c63976e8eb0e48eedf6c460444bcdfb5"},{"path":"docs/SCRIPTS.md","sha256":"975f628fe69bb77cc8237e5929808705a7ad8ee766813b762dd5c6413b34d1d2"}]}
```

At `entry`, the chain is empty. At every later state its length, final `to`, and
all preceding receipts must match the exact prefix above. A missing, reordered,
duplicated, rewritten, or hash-disconnected receipt fails. The current
`documentationStage` must be derived from the final receipt rather than trusted
independently.

Only `backend/scripts/architecture/r12b-documentation-transition.cjs` may
advance documentation state. It receives the exact current manifest SHA-256,
checks live/prepared bytes and the receipt-chain prefix, then appends one receipt
and atomically replaces the manifest. Publication transitions use a journal,
verified backups, sibling temporary files, atomic per-file replacement, and
rollback/recovery. `architecture:r12b` fails while a journal, backup, or partial
publication remains. The runner has no skip, force, rewrite-history, or direct
stage-set option.

The only predecessor-overlay paths R12B may mutate are these 25 rows:

```text
ARCHITECTURE.md
CHANGELOG.md
backend/.dependency-cruiser-known-violations.json
backend/package.json
backend/scripts/architecture/r3-context-scan.cjs
backend/scripts/architecture/r5-identity-scan.cjs
backend/scripts/architecture/r6-sharing-otp-transport-scan.cjs
backend/scripts/architecture/r7-collaboration-relocation-scan.cjs
backend/scripts/architecture/r8-global-module-removal-scan.cjs
backend/scripts/architecture/r12a-backoffice-catalog-public-contracts-scan.cjs
backend/scripts/security/prisma-config-merge-security.cjs
backend/src/marketplace/marketplace.service.ts
backend/test/architecture-r3-contexts.test.ts
backend/test/architecture-r3-scope.test.ts
backend/test/architecture-r5-identity-relocation.test.ts
backend/test/architecture-r6-sharing-otp-transport.test.ts
backend/test/architecture-r7-collaboration-relocation.test.ts
backend/test/architecture-r8-global-module-removal.test.ts
backend/test/architecture-r12a-backoffice-catalog-public-contracts.test.ts
backend/test/prisma-config-merge-security.test.ts
docs/README.md
docs/SCRIPTS.md
docs/project/DECISIONS.md
docs/project/EXECUTION_PLAN.md
docs/project/STATUS.md
```

Each of these 25 paths needs exactly one predeclared inverse-transform record.
The other 40 ledger rows must remain byte/status identical. No implementation
task may expand this set; an additional predecessor-overlay edit requires a new
reviewed design revision before the file is touched.

Unknown transform kinds, missing inverse transforms, duplicate path ownership,
post-hoc manifest widening, a mismatched reconstructed hash, or a changed
porcelain status fail closed. Tests must mutate the status, path, and hash of
every ledger category, with dedicated shared-file cases for the dependency
baseline, `package.json`, `marketplace.service.ts`, cumulative scanners/tests,
and active documentation.


### Owner-approved Task 4 inverse-contract correction — 2026-09-03

The owner approved correcting the Task 4 contract and final-hash enforcement,
independent review, then continuation. The independent diagnostic found two
Important issues: single insertion-only replay cannot represent the required
separated input/import/call/export edits, and changed live bytes were not
compared with `intendedFinalSha256`. Neither finding authorizes product changes,
extra predecessor paths, extra dependency retirements, or weaker historical
assertions. Tasks 1-3 approval receipts remain historical; they do not close
these later-discovered issues.

This revision supersedes only the insertion-only handoff representation and
clarifies the already-required final-byte hash check. The original design hash
was `0f34b027227ce6b249168518837c901aee0ea82a3ddba430d28cfbbbb7b6ce7f`;
the original plan hash was
`6cc90a6d7414f516e2caa9ba4ae30e12cf5c56a07686bd5bf66797728efcb2c0`.
Their exact pre-revision bytes, and the four affected governance files, are
preserved in the ignored Task 4 correction entry snapshot. No extra tracked
document or registry path is introduced.

The R12B schema becomes version `2`. Version `1` and
`bounded-insertion-removal` are rejected after migration; there is no runtime
compatibility adapter. The exact 25 inverse paths, 65-row predecessor ledger,
11 R12B-only path contracts, stage/debt/ownership values, and documentation
receipt machine remain unchanged. Exactly the 15 existing handoff records
(historical scanners, security checker, and their already-listed tests) use
`bounded-hunk-replay`; all other paths keep their existing transform kind.
Kinds must be checked against their exact path, not just a generic kind list.

Each handoff record retains exact keys `path`, `entrySha256`, `kind`,
`payload`, `intendedFinalSha256`. Pending registration is explicitly:

```json
{"entryByteLength":null,"hunks":null}
```

with `intendedFinalSha256:null`, and accepts only unchanged predecessor bytes.
Registered payloads contain an integer `entryByteLength` from 0 through
2097152 and a dense array of 1 through 128 hunks. Each hunk has exactly, in order:

```json
{"offset":0,"before":"old bytes as UTF-8 text","after":"new bytes as UTF-8 text"}
```

Offsets count bytes in the immutable entry file, never JavaScript characters
or positions in a previously edited buffer. Hunks are strictly ordered by
offset, may not overlap, and may not share an offset (including insertions).
Each before-range must fit inside `entryByteLength`; equal before/after text is
rejected. Text must round-trip exactly through UTF-8, preserving CRLF and Arabic.
The sum of all before/after text is at most 1048576 bytes; entry and final files
are at most 2097152 bytes. Unknown keys, sparse arrays, unsafe/negative numbers,
reordering, duplicate offsets, overlap, out-of-range edits, malformed Unicode,
and no-op hunks fail closed.

The production helper `applyR12bHunkTransform({ bytes, inverse, direction })`
supports only `forward` and `inverse`. Forward replay requires the entry hash,
entry length, and each original byte slice; it produces the registered final
hash. Inverse replay first requires the final length and final hash, then checks
each replacement slice and reconstructs the original bytes at the original
hash. Inverse live offsets are `offset + sum(previous afterBytes-beforeBytes)`.
Replay applies checked operations from highest offset downward. The result must
remain exact UTF-8. No fuzzy patching, substring search, eval, code wrappers,
export monkeypatching, hidden context, or duplicate implementations is allowed.

For every changed non-documentation predecessor path, irrespective of transform
kind, compare live SHA-256 with its registered `intendedFinalSha256` before
inverse execution; then independently compare reconstructed bytes with
`entrySha256`. Matching only the latter is insufficient. A registered but
still-unchanged handoff file is permitted only if forward replay against those
entry bytes validates all hunks and produces its preregistered final hash.

Before a shared target edit, prepare candidate bytes in ignored task scratch,
derive the exact hunks from the immutable entry, and register them plus the final
hash. Initial publication requires successful projection while live bytes still
match entry, followed by publication of only those candidates. For subsequent
RED/GREEN or review revisions, first verify the current bytes against the prior
registered final hash; prepare and validate the next candidate against the same
immutable entry, register the next hunks/hash, then publish. Any transient
old-file/new-registration mismatch remains a closed gate, never a PASS or a
retroactive hash update. An interruption requires checking previous/next hashes
and preserved candidates; publish only a validated prepared candidate or restore
only this task's verified previous registration. Unrecognized bytes stop work.

The correction checkpoint may modify only the existing R12B manifest, scanner,
planning-contract test, and schema fixture setup in the documentation-transition
test (if required), plus these existing design/plan documents. Existing assertions
must remain; only schema-version/kind expectations, honest fixture construction,
and appending the single `applyR12bHunkTransform` export after `runCli` in both
production exports and the exact ordered `Object.keys(api)` assertion may be
adjusted. Preserve every prior export, its order, and the exact equality check;
do not allow arbitrary extra exports. The transition runner and seven live documentation targets are
not part of this checkpoint. New negative behavior tests must prove final-hash
enforcement, exact forward/inverse replay, malformed-hunk rejection, unchanged
prepared state, and rejection of unregistered changed bytes.

Independent review must reach Critical 0 / Important 0 / Minor 0 before the
original Task 4 historical/package/security edits resume. Task 5 and Task 6 retain
their original gates; no R12C work or Git integration is authorized.

## Exact Dependency Exit

The post-R12A baseline contains 16 records. R12B owns exactly these seven:

| ID | Consumer | Current deep dependency |
| ---: | --- | --- |
| 7 | `backend/src/dashboard/dashboard.contracts.ts` | `backend/src/wedding-plans/wedding-location.ts` |
| 8 | `backend/src/dashboard/dashboard.service.ts` | `backend/src/wedding-plans/wedding-location.ts` |
| 9 | `backend/src/marketplace/marketplace.presenter.ts` | `backend/src/wedding-plans/wedding-location.ts` |
| 11 | `backend/src/marketplace/marketplace.service.ts` | `backend/src/wedding-plans/wedding-location.ts` |
| 18 | `backend/src/provider-dashboard/provider-dashboard.service.ts` | `backend/src/wedding-plans/wedding-location.ts` |
| 21 | `backend/src/onboarding/dto/import-local-plan.dto.ts` | `backend/src/guests/dto/create-guest.dto.ts` |
| 22 | `backend/src/onboarding/dto/import-local-plan.dto.ts` | `backend/src/tasks/dto/create-task.dto.ts` |

The stage projection is exact:

| Stage | Retired IDs | Dependency count | Ownership |
| --- | --- | ---: | ---: |
| `design` | none | 16 | 385/781 |
| `planning-public` | 7, 8, 9, 11, 18 | 11 | 385/781 |
| `strict` | 7, 8, 9, 11, 18, 21, 22 | 9 | 385/781 |

The dependency baseline remains present with nine records for R12C. It is not
regenerated, reordered for convenience, or deleted. The ownership baseline is
byte-identical throughout R12B because no R12B source path appears in it.

## Planning Location Public Contract

Move exactly:

```text
backend/src/wedding-plans/wedding-location.ts
  -> backend/src/modules/planning/public/wedding-location.ts
```

The target retains the historical source bytes exactly. It exports the same
surface:

```ts
export interface WeddingLocationResponse {
  governorate?: string;
  cityOrDistrict?: string;
  areaOrNeighborhood?: string;
  street?: string;
  detailedAddress?: string;
  city?: string;
  district?: string;
  neighborhood?: string;
  addressNote?: string;
  shortLabel?: string;
  mediumLabel?: string;
  fullLabel?: string;
  displayLabel?: string;
}

export function normalizeWeddingLocationInput(
  value: Record<string, unknown> | null | undefined,
  cityFallback?: string | null,
): Prisma.InputJsonObject | null;

export function weddingLocationResponse(
  value: Prisma.JsonValue | null,
  cityFallback?: string | null,
): WeddingLocationResponse | null;

export function cityFromWeddingLocation(
  value: Prisma.InputJsonObject | null,
): string | null;
```

`BadRequestException`, Prisma JSON types, normalization limits, fallback order,
legacy compatibility keys, Arabic/English error text, trimming, and label
composition remain byte-for-byte unchanged. R13, not R12B, owns any later
Planning internal/infrastructure separation.

The legacy file is absent after the move. A re-export, forwarding barrel,
duplicate implementation, alias package, or fallback resolution is forbidden.

## Complete Location Consumer Projection

The following source consumers change only their module specifier:

| Consumer | New module specifier |
| --- | --- |
| `backend/src/dashboard/dashboard.contracts.ts` | `../modules/planning/public/wedding-location` |
| `backend/src/dashboard/dashboard.service.ts` | `../modules/planning/public/wedding-location` |
| `backend/src/marketplace/marketplace.presenter.ts` | `../modules/planning/public/wedding-location` |
| `backend/src/marketplace/marketplace.service.ts` | `../modules/planning/public/wedding-location` |
| `backend/src/provider-dashboard/provider-dashboard.service.ts` | `../modules/planning/public/wedding-location` |
| `backend/src/wedding-plans/wedding-plans.service.ts` | `../modules/planning/public/wedding-location` |

The focused behavior oracle changes only its module specifier:

| Test | New module specifier |
| --- | --- |
| `backend/test/backend-support.test.ts` | `../src/modules/planning/public/wedding-location` |

The R12B scanner normalizes those declared path rewrites back to the composite
entry and rejects any other source or test edit.

`backend/src/marketplace/marketplace.service.ts` already contains one approved
R12A import rewrite. R12B parity must reverse both the R12A provider-rating
rewrite and the R12B Planning-location rewrite before comparing with the Git
base. Treating that file as if it were still equal to HEAD is forbidden.

## Onboarding-Owned Import DTOs

Create:

```text
backend/src/onboarding/dto/import-local-task.dto.ts
backend/src/onboarding/dto/import-local-guest.dto.ts
```

`ImportLocalTaskDto` is byte-equivalent to immutable
`CreateTaskDto` after the single exact class-name substitution
`CreateTaskDto -> ImportLocalTaskDto`. `ImportLocalGuestDto` is byte-equivalent
to immutable `CreateGuestDto` after
`CreateGuestDto -> ImportLocalGuestDto`. Property order, optionality, TypeScript
types, enums, decorator order, decorator arguments, limits, and validation
messages remain unchanged.

`backend/src/onboarding/dto/import-local-plan.dto.ts` changes only:

```ts
import { ImportLocalGuestDto } from './import-local-guest.dto';
import { ImportLocalTaskDto } from './import-local-task.dto';
```

and these constructor/type references:

```ts
@Type(() => ImportLocalTaskDto)
tasks?: ImportLocalTaskDto[];

@Type(() => ImportLocalGuestDto)
guests?: ImportLocalGuestDto[];
```

The canonical Tasks and Guests API DTOs remain unchanged in their current
owners. Onboarding intentionally owns its import payload shape so later Tasks
or Guests API evolution cannot silently change the local-plan import contract.
There is no shared DTO package and no Tasks/Guests public DTO export.

## DTO Behavior Proof

Create `backend/test/import-local-plan-dto-contract.test.ts`. It must:

1. compare valid and invalid task samples through `CreateTaskDto` and
   `ImportLocalTaskDto` using `plainToInstance` plus `validate`;
2. compare valid and invalid guest samples through `CreateGuestDto` and
   `ImportLocalGuestDto`;
3. normalize validation errors to property, constraints, and nested children;
4. prove `ImportLocalPlanDto` transforms nested values into the two local DTO
   constructors;
5. prove the external JSON keys and accepted/rejected values are unchanged;
6. reject accidental imports from `guests/dto` or `tasks/dto` in Onboarding.

The architecture scanner additionally proves byte parity after the one allowed
class-name substitution. Behavioral tests and structural parity are both
required; neither substitutes for the other.

## R12B Governance Contract

Create:

```text
backend/architecture/r12b-planning-public-contracts.json
backend/scripts/architecture/r12b-planning-public-contracts-scan.cjs
backend/scripts/architecture/r12b-documentation-transition.cjs
backend/test/architecture-r12b-planning-public-contracts.test.ts
backend/test/architecture-r12b-documentation-transition.test.ts
```

The manifest contains exact repository identity, the complete ordered 65-row
predecessor ledger and its hashes, the derived `documentationStage`, the
append-only `documentationTransitions` chain, the predeclared inverse-transform
registry,
the seven dependency records, three stages, the location move, seven import
consumers, two DTO re-expressions, the focused behavior tests, immutable entry
hashes, and the protected surfaces. Empty collections are forbidden where the
design declares records.

The scanner exports at least:

```js
validateR12bManifest(value)
expectedR12bDependencyRecords(r12aRecords, manifest)
validateR12bPredecessorOverlay(input)
projectR12bWorkingTreeToPredecessor(input)
verifyR12bLocationSourceParity(input)
verifyR12bConsumerParity(input)
verifyR12bDtoParity(input)
scanR12bPlanningPublicContracts(input)
runCli()
```

The CLI accepts only `--check` and reports one bounded result:

```text
PASS - R12B Planning public contracts: stage=strict, documentation=activated, receipts=4, dependency=9, ownership=385/781
```

All JSON read by the new authority must pass bounded plain-data validation.
Unknown keys, sparse arrays, duplicate semantic records, unsafe paths,
symlinks/reparse points, wrong hashes, extra retirements, count drift, and
unapproved consumers fail closed.

## Historical And Security Handoff

R3, R5, R6, R7, R8, and R12A remain historical authorities. Their immutable
bases, historical stage results, and phase-specific assertions do not change.
Live checks may consume the validated R12B successor projection only when the
exact R12B manifest exists and identifies the approved R12A predecessor.
Fixtures without R12B remain valid at their historical R12A count of 16.

`backend/package.json` adds exactly:

```json
"architecture:r12b": "node scripts/architecture/r12b-planning-public-contracts-scan.cjs --check"
```

and appends `&& npm run architecture:r12b` to the aggregate architecture script.
`backend/package-lock.json` remains protected. Before Task 5 restarts, its sole
approved security prerequisite changes raw SHA-256 from
`30bd3b228b763b3bbe895554a71623465e9717409c71266dbdff41e4c079cf0b` to
`650bc45c00cd3cdf8298e33570481bb969fdbae78a63167cca9f8ff243b25f60`,
with exactly one semantic package delta: `node_modules/qs` changes from
`6.15.3` to `6.16.0`. `package.json`, `@nestjs/platform-express@11.1.28`,
`express@5.2.1`, and `body-parser@2.3.0` remain unchanged. Task 4 lock-freeze
evidence remains historical and is not rewritten.

The Prisma merge-security projector must add an exact R12B layer:

```js
const R12B_ARCHITECTURE_SCRIPT =
  R12A_ARCHITECTURE_SCRIPT + ' && npm run architecture:r12b';
const R12B_STANDALONE_SCRIPT =
  'node scripts/architecture/r12b-planning-public-contracts-scan.cjs --check';
```

`projectR12BArchitectureScripts` validates the unique R12B key and aggregate,
deletes only `architecture:r12b`, restores the R12A aggregate, and delegates to
the existing R12A projector. The pinned package fingerprint does not change;
the normalized whole-lock fingerprint changes only to the reviewed safe-lock
fingerprint. Exact and Unicode-escaped duplicate JSON members must still fail
through the live security CLI.

## Test Change Policy

Existing behavior assertions, fixtures, Arabic/error expectations, and runtime
smokes are immutable unless a failing test is proven to encode an obsolete file
path only. An approved path-only rewrite must be declared in the R12B manifest
and normalized back to the composite entry by the scanner.

New architecture tests may exercise malicious manifests, path traversal,
duplicate records, symlinks, source/consumer drift, DTO drift, wrong stage
counts, and successor handoff failures. They may not weaken any R3-R12A gate.

## Scope Fence

R12B implementation may touch only:

1. the new R12B manifest, scanner, documentation-transition runner, their two
   architecture tests, and the DTO contract test;
2. the one moved Planning location file and its seven declared consumers/tests;
3. the two new Onboarding-owned DTO files and
   `import-local-plan.dto.ts`;
4. the dependency baseline by exact seven-record subtraction;
5. `backend/package.json` script wiring;
6. the Prisma security projector/test and only the R3/R5/R6/R7/R8/R12A
   scanner/tests needed for the exact successor handoff;
7. active R12B documentation and generated `docs/SCRIPTS.md` after source gates
   pass.

Protected, with exactly one approved exception:

- `backend/package-lock.json` stays in the protected inventory and is accepted
  only at status ` M`, with the exact old/new raw hashes and `qs@6.16.0`
  identity above; every other lock or protected-path drift fails;
- `backend/prisma/**`, schema, migrations, seeds, and database structure;
- `backend/architecture/ownership-baseline.json` bytes and totals;
- route decorators, controller methods, DTO JSON keys, validation behavior,
  response shapes, errors, permissions, transaction and lock order;
- `mobile/**`, `admin-web/**`, `deploy/**`, Docker, Compose, Dokploy, and
  production;
- all R12C and R13-R20 implementation.

## Verification And Exit Gates

### Owner-approved Task 6 final-report contract correction — 2026-09-07

The live correction entry remains the independently reviewed R12B candidate:
`documentationStage=candidate`, exactly two receipts, dependency debt `9`,
ownership `385/781`, protected prerequisite `1/0`, no transition artifacts,
empty staging, and no live R12B final report. The correction may change only
the R12B scanner, its two architecture tests, this specification, the active
R12B plan, and the manifest registrations for those five raw targets plus the
single normalized-self fingerprint. The exact final report is prepared outside
the repository and is not published during the correction implementation.

The tests own this literal receipt-prefix authority independently of scanner
output:

```text
entry               -> 0 receipts
candidate-prepared  -> 1 receipt
candidate           -> 2 receipts
activation-prepared -> 3 receipts
activated           -> 4 receipts
```

Each authorized test file carries its own portable, verified byte authority for
the exact seven entry documents and the fourteen registered candidate/activated
documents. Decode or deterministic reconstruction must prove path order, byte
length, exact UTF-8 round-trip, and every registered SHA-256 before production
code consumes the bytes. Fixtures use fresh temporary roots and clean receipt
prefixes for every case; they do not obtain documentation-state bytes from the
live checkout, ignored evidence, controller scratch, ambient temporary state,
or another process. The standalone generated-scripts oracle seeds
`docs/SCRIPTS.md` from the registered portable entry bytes and checks its
generated output against the registered candidate hash.

The only final-report path is the exact literal:

```text
docs/superpowers/reports/2026-09-02-modular-monolith-r12b-planning-public-contracts-report.md
```

It is forbidden at `entry`, `candidate-prepared`, `candidate`, and
`activation-prepared`. At `activated` it is required exactly once in Git status
with status `??` and must pass the existing `inspectPlainFile` filesystem
boundary. It is not a member of `NEW_R12B_PATHS`, `R12B_PATHS`, or manifest
`r12bPaths`. Prefixes, suffixes, alternate directories, nested paths, renamed
variants, duplicates, wrong status, absence, directories, symbolic links, and
supported reparse points fail closed. The general undeclared-path classifier
may bypass only exact equality with this literal after the stage, count, status,
and plain-file checks pass.

For all five documentation stages,
`projectionDetails.documentation` contains exactly seven records and seven
unique paths. The scanner removes only the earlier changed-document append and
retains the canonical seven-transform append; it does not deduplicate or alter
unrelated projection behavior.

All five final raw candidates are hashed before publication. The next manifest
changes only the scanner, planning-test, transition-test, specification, and
plan raw fingerprints plus normalized self, preserving both receipts, all
fourteen candidate/activated hashes, all 25 inverse transforms, all 11 path
contracts, and every dependency, ownership, security, and repository identity
field. Publication order is manifest first, then this specification, the plan,
and both tests while the scanner remains at its correction-entry bytes. Valid
RED must prove only the unchanged scanner defects: the exact activated report is
undeclared, file-type diagnostics are not reached, and non-entry projection
emits 14 rather than seven records. Fixture, receipt, hash, syntax, manifest, or
state-construction failures invalidate RED.

GREEN changes only the preregistered scanner: one literal report constant,
activated-only exact count/status/plain-file enforcement, one exact-equality
classifier bypass, and removal of the duplicate documentation producer. Both
complete test files separately and together, R12B architecture, aggregate
architecture, TypeScript check, build, scope/state checks, and scratch mutations
must pass with zero test failure and zero skip. The scratch mutations must kill
pre-activated prohibition, activated count, exact equality, status,
`inspectPlainFile`, and the single projection producer independently.

The correction implementation then stops for fresh independent review at
Critical `0`, Important `0`, Minor `0`. Only after that approval may a separate
candidate re-review authorize receipt 3. Receipt 4 is appended before the exact
prepared final report is published; the report is then published at the literal
path before the first activated strict scanner invocation. No correction step
creates receipt 3 or 4, publishes the report, starts R12C, changes Product Logic,
packages, generators, baselines, any other test, Git state, deployment,
production, provider, phone, remote CI, or release state.

### Owner-approved Task 6 generated-scripts transition correction — 2026-09-06

The Task 6 documentation state machine is path-specific at candidate
registration. The six narrative documents must each have three distinct byte
states: entry, candidate, and activated. The generated `docs/SCRIPTS.md` path
alone must have a candidate hash different from its registered entry hash and
an activated hash exactly equal to its candidate hash. No other path may share
candidate and activated hashes.

Both outside-repository candidate and activated mirrors must pass
`node scripts/docs-sync.mjs --check` with unchanged Backend and Admin package
metadata before the live transition runner is invoked. Those two canonical
generator runs must produce byte-identical `docs/SCRIPTS.md` artifacts while
the generated hash remains different from the registered entry hash. This
correction does not change the four receipt states, receipt fields, ordering,
hash preregistration, journal/recovery behavior, generator, package metadata,
Product Logic, dependency or ownership baselines, debt, or any later phase.

The runner enforces this rule only by the literal `docs/SCRIPTS.md` path. A
candidate equal to entry, generated candidate/activation inequality, or
narrative candidate/activation equality fails before any receipt is written.

R12B exits only when one fresh exact-state run proves:

1. root, branch, and HEAD match the composite entry;
2. the preserved R12A 65-path overlay and its protected files did not drift
   outside declared R12B paths and the exact security receipt, reported as
   `approvedSecurityPrerequisite=1 unapprovedProtected=0`;
3. dependency baseline equals R12A 16 minus exactly IDs
   `7-9`, `11`, `18`, `21-22`, producing 9 with additions 0 and unrelated
   removals 0;
4. ownership baseline is byte-identical at `385/781`;
5. the legacy location path is absent and the public target exists once;
6. the five debt consumers, Planning internal consumer, and behavior test use
   the exact public path;
7. Onboarding imports neither Tasks nor Guests DTO paths;
8. location implementation and declared consumer parity pass;
9. both local DTOs pass exact transformed-source and validation parity;
10. R3/R5/R6/R7/R8/R12A historical negative selections and live CLIs pass;
11. Prisma security, duplicate-key rejection, pinned package graph, and audits
    pass with the lock at the exact approved prerequisite hash and no gate-time
    package-file mutation;
12. focused architecture and behavior tests pass;
13. `npm run architecture`, `npm run check`, `npm run build`, and full
    `npm test` pass without new skips;
14. affected wedding-plan, onboarding, dashboard, marketplace, quote, provider
    dashboard, and concurrency smokes pass;
15. `npm run smoke:all` passes all managed smoke packages;
16. docs sync/check/verify and `git diff --check` pass;
17. exact scope, protected-surface, staging, and identity gates pass with
    `approvedSecurityPrerequisite=1 unapprovedProtected=0`;
18. predecessor reconstruction passes at documentation states `candidate` and
    `activated`, with candidate/activated hashes registered before publication;
19. the activated state contains the exact four-receipt chain and no transition
    journal, backup, sibling temporary file, or partial publication remains;
20. an independent final review reports Critical `0`, Important `0`, Minor `0`.

No physical-phone gate is required because R12B is a Backend-only internal
boundary refactor with frozen observable behavior and no Mobile change. Any
observed behavior change invalidates that assumption, stops R12B, and requires
separate owner approval plus affected runtime/phone acceptance.

## Permanent Stop Rules

Stop immediately if:

- the Git identity, R12A predecessor manifest/hash, 65-path overlay, or approved
  source hashes drift before implementation;
- the dependency baseline is regenerated, reaches any count other than the
  active stage, or loses an unapproved record;
- ownership bytes or `385/781` totals change;
- location source changes beyond its path;
- local DTOs differ beyond the exact class-name substitutions;
- an old and new implementation coexist;
- a wrapper, barrel, facade, fallback, alias, or public Tasks/Guests DTO export
  becomes necessary;
- API, validation, error, permission, transaction, schema, Arabic, Mobile,
  Admin Web, any unapproved package-lock change, deployment, or release
  behavior changes;
- R12C or later-phase work becomes necessary to make R12B pass;
- a test is deleted, skipped, weakened, or rewritten beyond a declared path
  change.

## Rejected Alternatives

### Split location into type, parser, validator, and presenter ports now

Rejected for R12B. It broadens the export surface, changes implementation
topology, and risks exception/type drift. R13 owns Planning internal completion.

### Keep the legacy path as a re-export

Rejected. It preserves the forbidden deep dependency and creates a permanent
compatibility facade.

### Publish `CreateTaskDto` and `CreateGuestDto` from owner public packages

Rejected. API DTO reuse is the coupling R12B must remove; exporting it merely
moves the same dependency behind a new path.

### Put task and guest nested shapes into a shared-kernel DTO

Rejected. The payload belongs to the one-shot Planning/Onboarding import
contract. A shared DTO would create false shared ownership.

## Authorization Boundary

This approved design authorizes writing and independently reviewing the R12B
implementation plan. It does not authorize source implementation, Git staging,
commit, push, merge, branch/worktree changes, deployment, production mutation,
remote CI, provider delivery, store release, R12C, or any later phase. Source
implementation requires separate owner approval after the reviewed plan.
