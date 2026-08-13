# Modular Monolith R2 Prisma Schema Folder Design

**Status:** Approved for staged local execution; implementation has not started

**Date:** 2026-08-13

**Execution base:** R1 local-closeout commit
`8ba0db78ac669bd6d17de878b77a4d1e6c5e542d` on branch
`modular-monolith` (`R2_BASE`)

## Objective

R2 replaces the single `backend/prisma/schema.prisma` file with Prisma's native
multi-file schema folder. The split follows the already-approved model
ownership registry and changes only physical schema organization and the tools
that read or package that schema. It must not change the database, generated
Prisma Client contract, seed behavior, application behavior, or migration
history.

R2 is complete only when:

- `backend/prisma/schema.prisma` is absent;
- `backend/prisma/schema/` contains exactly `_base.prisma` plus one file for
  each of the 13 current model owners;
- all 52 models and 41 enums occur exactly once in the approved file;
- `prisma.config.ts`, Docker build/runtime packaging, architecture tooling,
  documentation generation, tests, and migration rehearsal all consume the
  folder without a compatibility copy or deprecated package fallback;
- `prisma migrate diff` reports no difference from the immutable R2 base;
- all 76 committed migration directories and `prisma/seed.ts` remain
  byte-identical;
- Prisma validation, generation, Backend gates, migration smokes, full managed
  smoke, Docker runtime, unchanged Admin/Mobile gates, independent review, and
  the owner's application checkpoint pass.

## Non-Goals

R2 does not:

- add, remove, rename, or alter a model, enum, field, relation, index,
  constraint, native database type, generator, or datasource;
- create, edit, reorder, squash, or delete a migration;
- split `prisma/seed.ts` into module seed functions. Business Nest modules do
  not exist until later phases, so that fate-map item is deferred to the phase
  that owns those modules;
- change generated Prisma Client imports or application queries;
- create repositories, ports, business module slices, compatibility barrels,
  an aggregate `schema.prisma`, symlinks, copied schema mirrors, or fallback
  discovery through the deprecated `package.json#prisma` field;
- modify Backend application source, HTTP routes, DTOs, permissions, Arabic
  text, transaction behavior, Mobile source, Admin Web source, Compose files,
  Dokploy files, or deployment topology;
- remove either approved `@Global()` declaration or address R3-R8 dependency
  debt.

## Source-of-Truth Corrections

The 2026-08-04 external modular-monolith design remains architectural context,
but R2 uses these verified live facts:

1. The R1-closeout source contains 52 models, 41 enums, and 76 migration
   directories, not the older 48/75 count.
2. The ownership registry has 13 model-owning groups: platform, identity,
   planning, finance, collaboration, tasks, guests, marketplace, messaging,
   notifications, catalog, media, and backoffice. `insights` owns no model and
   therefore receives no empty schema file.
3. The target is 14 `.prisma` files: one `_base.prisma` plus 13 owner files.
   The phrase "12 owners + platform" describes those same 13 owners; it does
   not mean 13 files including `_base`.
4. Prisma CLI 6.19.3 supports a schema directory. A local external probe passed
   `prisma validate`, `prisma generate`, and an empty `prisma migrate diff`
   against a folder.
5. Prisma's default schema lookup does not discover `prisma/schema/` without
   configuration. The current Dockerfile copies `prisma/` but not
   `prisma.config.ts`; leaving it unchanged would break both image-time
   `prisma generate` calls and runtime `prisma migrate deploy`.
6. The root correction is to copy the existing config into both Docker stages.
   Adding deprecated `package.json#prisma.schema`, duplicating
   `schema.prisma`, or passing scattered `--schema` flags is rejected.
7. The original fate map's per-module seed split cannot occur in R2 without
   creating future-phase module structure. `prisma/seed.ts` is therefore frozen
   byte-for-byte in R2.

## Chosen Delivery Shape

R2 uses three reviewable checkpoints:

1. freeze the immutable base, exact schema manifest, reader inventory, hashes,
   protected surfaces, green DMMF fingerprint tooling, and a green R2-only
   scope verifier;
2. perform the atomic schema split and update only the canonical consumers,
   beginning with transient test-only RED for the missing loader/layout and
   ending with every committed test GREEN, then prove semantic and runtime
   equivalence;
3. run exhaustive closeout gates, build and run an immutable Docker image,
   record the receipt, complete independent review, and obtain the owner's
   application checkpoint.

The schema split and consumer updates remain one atomic implementation
checkpoint. A state where the old file and folder coexist would create two
sources of truth, while deleting the old file before all readers migrate would
leave the repository broken.

## Target Layout

```text
backend/prisma/
  schema/
    _base.prisma
    backoffice.prisma
    catalog.prisma
    collaboration.prisma
    finance.prisma
    guests.prisma
    identity.prisma
    marketplace.prisma
    media.prisma
    messaging.prisma
    notifications.prisma
    planning.prisma
    platform.prisma
    tasks.prisma
  migrations/               # unchanged: 76 directories
  seed.ts                    # byte-identical to R2_BASE
```

`_base.prisma` contains exactly the existing `generator client` and
`datasource db` blocks. It contains no enum or model.

## Machine-Readable Layout Contract

R2 adds `backend/architecture/prisma-schema-layout.json`. It is a governance
contract, not a debt baseline. It contains:

- `schemaVersion`;
- `splitBaseRevision` equal to the full immutable `R2_BASE`;
- `baseFile` equal to `_base.prisma`;
- the exact 13 owner filenames;
- the exact model and enum lists for each owner;
- `modelOrder`, preserving the 52-model order from the R2 base so generated
  database documentation stays byte-identical.

The architecture test must reject an extra/missing file, duplicate name,
unknown owner, mismatched registry model, wrong base revision, non-canonical
path, empty owner file, or changed global model order.

The durable manifest intentionally does not freeze seed, migration, comment, or
whole-schema hashes. Those are R2 transition proofs owned by the explicitly
invoked R2-only scope verifier. Keeping them out of the permanent layout test
prevents a legitimate later schema/migration phase from being blocked by an R2
checkpoint assertion. The durable test is independent of Git history in a
shallow CI checkout.

### Model Ownership

- `platform.prisma`: `IdempotencyKey`, `OutboxEvent`
- `identity.prisma`: `AccountDeletionReceipt`, `User`, `AdminLoginChallenge`,
  `AdminPasswordResetChallenge`, `RefreshToken`, `LoginThrottle`,
  `OtpDispatchQuota`, `OtpCode`
- `planning.prisma`: `WeddingPlan`
- `finance.prisma`: `BudgetCategory`, `WeddingCost`, `CostPayment`,
  `PaymentSchedule`
- `collaboration.prisma`: `SharedMember`, `ContributorHistoryScope`,
  `ContributorTenure`, `ContributionEvent`, `PlanInvite`
- `tasks.prisma`: `WeddingTask`, `WeddingTaskChecklistItem`
- `guests.prisma`: `Guest`, `GuestGroup`
- `marketplace.prisma`: `Provider`, `ProviderService`,
  `ProviderServiceImage`, `ProviderPackage`, `FavoriteProvider`,
  `ProviderReview`, `QuoteRequest`, `QuoteOffer`, `PlanProviderLink`
- `messaging.prisma`: `Conversation`, `ConversationParticipant`,
  `ConversationEvent`, `ChatMessage`, `ChatAttachment`, `ConversationReport`
- `notifications.prisma`: `NotificationPreference`, `PushInstallation`,
  `Notification`
- `catalog.prisma`: `City`, `Governorate`, `District`,
  `AdministrativeLocality`, `ReferenceCatalog`, `ReferenceCatalogItem`,
  `ReferenceCatalogItemRevision`, `ProviderCategory`
- `media.prisma`: `MediaUploadTicket`
- `backoffice.prisma`: `AdminAuditLog`

### Enum Ownership

- `backoffice.prisma`: `AdminRole`, `AdminAuditPhase`
- `identity.prisma`: `UserRole`, `AppRole`, `UserStatus`, `OtpPurpose`,
  `AuthSessionScope`
- `planning.prisma`: `OnboardingPath`, `WeddingPersona`,
  `WeddingPlanStatus`
- `finance.prisma`: `WeddingCostStatus`, `CostPaymentType`,
  `PaymentScheduleStatus`
- `collaboration.prisma`: `SharedMemberRole`, `ContributionScopeStatus`,
  `ContributorTenureEndReason`, `ContributionSection`,
  `ContributionEntityType`, `ContributionAction`,
  `ContributionProvenance`, `ContributionPermission`,
  `PlanInviteDeliveryStatus`
- `tasks.prisma`: `WeddingTaskStatus`, `WeddingTaskPriority`
- `guests.prisma`: `GuestSide`, `GuestStatus`, `GuestInvitationStatus`,
  `GuestAttendanceStatus`
- `marketplace.prisma`: `ProviderStatus`, `ReviewStatus`,
  `QuoteRequestStatus`, `QuoteOfferStatus`, `PlanProviderLinkStatus`
- `messaging.prisma`: `ConversationScope`, `ConversationEventType`,
  `ConversationReportStatus`
- `notifications.prisma`: `NotificationType`, `NotificationPriority`,
  `PushPlatform`
- `catalog.prisma`: `AdministrativeLocalityType`
- `media.prisma`: `MediaUploadStatus`
- `platform.prisma`: no enums

Cross-file references are native Prisma schema references. Enum placement
states semantic ownership; it does not authorize a business module to access
another owner's Prisma delegate.

## Canonical Schema Loader

R2 adds `backend/scripts/prisma/schema-files.cjs` as the sole repository helper
for tools that need schema text. It:

- resolves paths relative to the Backend root, not process cwd;
- validates the manifest and exact folder file set before reading;
- rejects symlinks, junctions, reparse escapes, absolute manifest paths,
  traversal, duplicate files, non-plain manifest data, and unexpected schema
  extensions;
- reads files in deterministic manifest order;
- returns individual file text, combined schema text, owner metadata, and
  `modelOrder` without rewriting content;
- exposes fixed, non-reflective failure output in any CLI boundary.

`backend/test/support/live-prisma-schema.ts` is the TypeScript test adapter for
this loader. Existing tests use it instead of each implementing folder walking.
No test receives a fallback to the old file.

## Consumer Migration

The following live consumers change in R2:

- `backend/prisma.config.ts` points `schema` to `prisma/schema`;
- `backend/Dockerfile` copies `prisma.config.ts` into the build stage and from
  the build stage into the runtime image; all commands, base images, ports,
  labels, users, and topology remain unchanged;
- `backend/scripts/architecture/ownership-scan.cjs` uses the canonical loader;
- `scripts/docs-sync.mjs` uses the canonical loader and renders models in
  manifest `modelOrder`;
- `backend/scripts/smoke/contributor-history-migration-smoke.js` copies the
  schema folder recursively into its isolated rehearsal and passes the folder
  to Prisma;
- the architecture ownership fixture copies the exact folder and manifest;
- the 10 current behavioral schema-reading tests import the TypeScript adapter
  and keep their assertions unchanged; `architecture-ownership.test.ts`
  instead copies the exact folder plus manifest into its synthetic fixture.

Historical R0/R1 plans, archived documents, and the R0 fixed-scope script/test
may retain the old literal as historical evidence. Active production tooling,
tests, scripts, and source may not.

The executable-code stale-literal allowlist is exact:

- `scripts/check-r0-scope.test.mjs`, whose R0 fixtures intentionally name the
  then-protected single schema;
- `backend/test/architecture-r2-schema-layout.test.ts`, whose negative contract
  must name the retired path;
- `backend/test/prisma-schema-files.test.ts`, only inside explicit negative
  fixtures.

No production script, Prisma config, behavioral test, or application source is
allowlisted. Documentation scanning may additionally preserve the literal in
`CHANGELOG.md`, historical sections of `docs/project/STATUS.md`, archived
`.md.txt` references, the completed R0/R1 plans, and this R2 design/plan. The
live source-of-truth sentence in `docs/backend/DATABASE.md` is not allowlisted
and must move to the folder path with implementation.

## Equivalence Contract

R2 uses the immutable single-file schema extracted from `R2_BASE` into a unique
OS-temp directory. No tracked backup is created. The candidate must pass all
of these independent checks:

1. exact manifest coverage: 52 unique models and 41 unique enums;
2. registry agreement: every model appears under its current owner;
3. exact generator/datasource block preservation;
4. comment preservation: every non-empty comment line from the base schema
   occurs the same number of times in the folder candidate;
5. `prisma migrate diff --exit-code` from the base file to the candidate folder
   reports `No difference detected`;
6. `prisma validate` and `prisma generate` pass against the folder;
7. generated Prisma DMMF canonical projections for models, enums, fields,
   relations, primary keys, unique fields/indexes, defaults, native types, and
   documentation are identical before/after. Ordinary `@@index` definitions
   are covered by the empty migrate diff and exact schema-block checks because
   Prisma's public generated-client DMMF does not expose them;
8. the generated database model table and all other generated docs remain
   byte-identical. The only allowed `docs/backend/DATABASE.md` delta is its
   source-of-truth sentence changing from the retired file to
   `backend/prisma/schema/`;
9. migrations and seed hashes remain identical to `R2_BASE`.

Any difference stops the checkpoint. R2 never explains a schema difference as
"expected" because no semantic schema difference is authorized.

## Docker and Runtime Contract

The Dockerfile change is an exact packaging correction required by the folder
split:

```dockerfile
COPY prisma.config.ts ./
...
COPY --from=build /app/prisma.config.ts ./
```

The first line is added beside the build-stage Prisma copy; the second is added
beside the runtime Prisma copy. The image must prove both image-time
`prisma generate` and startup `prisma migrate deploy` discover the folder.
No `--schema` duplication is added to Docker commands, and no Compose or
deployment configuration changes.

## Test and Verification Policy

R2 adds architecture tests for the manifest, exact file set, schema
equivalence, loader containment, config, Docker packaging, stale active
readers, seed/migration immutability, and protected surfaces. Existing
schema-reading tests may change only through the shared helper import and the
mechanical replacement of single-file reads; assertions, fixtures, expected
values, timeouts, skips, and product literals remain frozen.

Every implementation checkpoint runs focused tests, Prisma validation and
generation, architecture, Backend check/build, and relevant migration smoke.
Closeout runs the full Backend suite and `smoke:all`, both npm audits, unchanged
Admin gates, Mobile boundary/analyze/tests, docs gates, Docker build/runtime
health, independent review, and the owner's phone application test.

## Protected Surfaces

R2 permits tracked changes only to:

- the R2 design/plan and active receipt/navigation Markdown;
- `backend/prisma/schema.prisma` deletion and the 14 target schema files;
- `backend/architecture/prisma-schema-layout.json`;
- `backend/prisma.config.ts`;
- `backend/Dockerfile` with the two exact config-copy lines;
- the canonical loader and TypeScript test adapter;
- the R2-only fixed-base scope verifier and its durable injected-fixture test;
- the ownership scanner, docs sync, contributor-history migration smoke;
- the architecture tests and exact live schema-reading tests;
- `backend/scripts/prisma/dmmf-fingerprint.cjs` and its focused test under
  `backend/test/`, used to
  compare normalized generated-client metadata before and after the split.

The following are protected and must have zero diff from `R2_BASE` unless an
independently reproduced blocker requires an owner-approved contract update:

- `backend/src/**`;
- `backend/prisma/migrations/**` and `backend/prisma/seed.ts`;
- `backend/package.json` and lockfile;
- `mobile/lib/**`, `mobile/test/**`, `mobile/integration_test/**`;
- `admin-web/src/**` and Admin behavioral tests;
- `deploy/**`, Compose files, workflow files, and all Dockerfiles except the
  exact Backend Dockerfile packaging lines above.

## Checkpoint and Phase Transition

R2 continues locally on `modular-monolith` from immutable `R2_BASE`. Local
checkpoint commits are authorized; push, PR mutation, merge, branch creation,
and worktree creation are not. Each checkpoint requires green gates,
independent review, root-cause remediation, a clean local commit, and the
owner's continuation decision. The final implementation checkpoint also
requires a Docker-backed server and the owner's phone test.

Remote CI remains unclaimed until the owner separately authorizes a push. R3
must not start until R2 is locally closed and its owner application checkpoint
passes.

## Rejected Alternatives

- **Keep `schema.prisma` as an aggregator:** rejected because it preserves two
  schema authorities and defeats the folder split.
- **Use `package.json#prisma.schema`:** rejected because Prisma warns that the
  field is deprecated and it would duplicate the canonical config.
- **Scatter `--schema` flags:** rejected because missed commands would fail
  later and configuration would drift.
- **Leave Docker unchanged:** rejected by a real Prisma discovery probe and by
  the current Dockerfile's missing config copy.
- **Split seed functions now:** rejected as an early jump into business module
  phases.
- **Generate a migration and then prove it is empty:** rejected; R2 creates no
  migration directory at all.
- **Blindly concatenate files in filesystem order:** rejected because docs,
  fixtures, and future tools need a validated deterministic contract.

## Acceptance Summary

R2 is accepted locally only when the repository has one native 14-file Prisma
schema folder with exact owner coverage, no legacy schema file or compatibility
path, zero schema/DMMF/migration/seed/generated-table difference, only the exact
database source-path documentation correction, functional Prisma generation
and migration rehearsal, successful immutable Docker runtime, green exhaustive
gates, independent review, and the owner's phone checkpoint. No push, merge,
or remote-CI result is implied.
