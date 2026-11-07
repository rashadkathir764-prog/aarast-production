# Database Plan

This document describes the product data model at a planning/status level. It does not replace `backend/prisma/schema/` as the schema source of truth.

Current documentation snapshot: 2026-08-14. Route-level behavior belongs in
`docs/backend/API_CONTRACT.md`.

## R2 Physical Schema Layout

The live Prisma source is the native `backend/prisma/schema/` folder. It has
exactly 14 files: `_base.prisma` contains the existing generator and datasource,
and 13 owner files contain exactly 52 models and 41 enums. All 76 migration
directories and `backend/prisma/seed.ts` are byte-identical to immutable
`R2_BASE` `8ba0db78ac669bd6d17de878b77a4d1e6c5e542d`. The R2 normalized DMMF
fingerprint matched the base, `prisma migrate diff` was empty, and the generated
model table below remained byte-identical. This is a physical organization
change only; it does not alter the database, Prisma Client contract, migration
history, or product behavior. (This paragraph records R2. Since D47,
`backend/prisma/seed.ts` is retired: `npm run seed` and `prisma migrate reset`
run the local demo seed `backend/prisma/demo-seed.ts`, see
`docs/qa/DEMO_DATA.md`.)

## Current And Marketplace Entities

| Entity | Purpose |
| --- | --- |
| User | Represents one person using Aarast, such as groom, bride, family member, provider, or admin. `phone` is important for Yemen-first usage. `passwordHash` stores the application password for ordinary users/providers and the browser-administration password for admins. `appPasswordConfiguredAt` proves that an application credential was explicitly chosen; a bcrypt hash alone is insufficient because the historical invite flow generated an unreachable random password. An admin may separately enroll `appPasswordHash` plus `appName`, `appEmail`, and `appAvatarUrl` for the wedding application; app responses project this identity as a normal user and never expose admin metadata. Neither password hash is returned or stored as plaintext. `role`/`appRole` are legacy account-mode fields and are not sufficient to discover or authorize an active product context. Owner contexts derive from `WeddingPlan.ownerUserId`, contributor contexts from `SharedMember`, and provider contexts from `Provider.userId`. |
| Provider | Represents a vendor or business that offers wedding-related services. It has no featured flag: «مميز» is a `ProviderFeaturedPeriod` covering now (B-43; migration `20261025220000_add_provider_featured_periods` dropped `Provider.isFeatured`, which no back-office path ever wrote). |
| Service | Represents a specific service offered by a provider, such as hall rental, photography, salon, catering, or decoration. |
| Category | `ProviderCategory` groups services into one discoverable catalog. `showForGroom` and `showForBride` control customer-path discovery without duplicating provider categories; provider services and tags remain the flexible specialization layer. |
| City | Compatibility catalog currently referenced by providers, services, and quote requests. It supports existing market filtering but is not a synonym for a governorate or district. |
| Governorate | Authoritative Yemen first-level administrative reference with stable source code, Arabic/English names, center coordinates, active state, and ordered districts. The seeded set contains 22 units including `أمانة العاصمة`. |
| District | Authoritative second-level administrative reference related to one Governorate by `governorateId`, with a stable source code, Arabic/English names, and center coordinates. The seeded set contains 335 districts. |
| AdministrativeLocality | Optional third-level Yemen reference under one District. `type` distinguishes area, isolation, neighborhood, and zone; `parentId` supports a same-district hierarchy. Codes are stable, changes are soft-disabled, and public reads return active rows only. |
| ReferenceCatalog | Named, versioned container for flexible product reference data that may change without a mobile release. It is not used for security roles or financial lifecycle states. |
| ReferenceCatalogItem | Stable logical item key with pointers to the current draft revision and published revision. |
| ReferenceCatalogItemRevision | Append-only content snapshot containing Arabic/English labels, grouping, icon key, order, groom/bride/customer/provider audiences, recommendation and active flags, plus bounded JSON metadata. |
| Favorite | Lets users save providers or services for later comparison. |
| Review | Captures user feedback about a provider/service reference. Reviews are implemented as provider-reference support, not as paid marketplace monetization. A review requires a confirmed `Booking` with the provider whose day has passed (F10). |
| Package | Represents bundled provider offerings, such as full hall packages or photography packages. |
| Booking | The wedding day reserved with a provider after their offer was accepted (V1 checklist 4.6). One per quote request (`quoteRequestId` unique); the plan and the customer are the quote's. `status` is `REQUESTED → CONFIRMED / DECLINED`, `CANCELLED` by either side (`cancelledBy`), or `EXPIRED` (`expiredAt`) when the back office suspends the provider while it waits (B-42). `eventDate` is a calendar day. A provider holds at most `Provider.dailyBookingCapacity` (1 to 20, default 1, CHECK `Provider_dailyBookingCapacity_range`) `CONFIRMED` bookings on one day, counted under the provider's row lock (B-20); migration `20261027100000_provider_daily_capacity_and_expired_bookings` dropped the old one-a-day partial unique index `Booking_provider_confirmed_date_key`. Tracking only: no deposit or payment; the provider reads the customer's agreed, paid and left through finance's public port (B-18). |
| ProviderBlockedDate | A day the provider marked unavailable on their calendar; unique per provider and day. Requests and confirmations for it are refused. |
| ProviderProfileViewDay | How many times customers opened a provider's page on one day (`providerId`, `day` primary key, `views`). A daily total only: who viewed is not stored (V1 checklist 4.19). |
| ProviderReviewEvent | One step of a provider's review (B-01, B-02): an administrator's decision (`CHANGES_REQUESTED`, `REJECTED`, `APPROVED`, `SUSPENDED`, `ACTIVATED`) or the provider's own (`RESUBMITTED`, `REOPENED`), with `actorId` (a plain account id), `createdAt` and `sequence`, a serial that orders the steps (migration `20261025180000_order_provider_review_events`; every step is written under the provider's row lock, so it grows in the order the steps happened even when two share a `createdAt`; the steps already written were numbered by time, then id). Every read of «the latest decision» and of the history orders by `sequence`. Cascades with the provider. Replaces the single `Provider.reviewNote`, which migration `20261025120000_add_provider_review_and_claim_requests` moved into it (one event and one `GENERAL` note per stored note) before dropping the column. `Provider` keeps `reviewedAt`/`reviewedById` for the latest decision and gains `resubmittedAt`, `resubmitCount` and `reopenedAt`. |
| ProviderReviewNote | A note written with a review step: `GENERAL` (the whole profile) or one field the provider can fix before approval (`BUSINESS_NAME`, `CATEGORY`, `CITY`, `DESCRIPTION`, `SERVICE`); unique per step and field. The latest decision's notes are the ones the provider reads while `NEEDS_CHANGES`, `REJECTED` or `SUSPENDED`. |
| ProviderClaimRequest | An account asking for a listing the back office made under its phone (B-12, D41): `providerId`, `userId` (plain id; removed with the account), `status` `PENDING → APPROVED / REJECTED`, the team's `note`, `decidedAt`, `decidedById`. Partial unique indexes keep one `PENDING` claim per listing and per account. Only approval links the listing to the account. |
| ProviderFeaturedPeriod | A featured placement the back office recorded by hand after the provider paid outside the app (B-43, D41, D51): `providerId` (cascades with the provider), `startsAt`, `endsAt` (the start of the day after the last day covered, Sana'a time; a CHECK keeps `endsAt > startsAt`), the administrator's `note` (how he paid; no amount, no payment status), `grantedById` and `createdAt`, `endedAt`/`endedById`/`endNote` when an administrator stopped it early or cancelled it before its start, and `startNoticeAt`/`endingNoticeAt`/`endNoticeAt` so the hourly job tells the provider once that a booked placement started, that it ends within the week and that it ended (D54; `startNoticeAt` is set at the grant when it starts at once). Featured = a row with `startsAt <= now < endsAt` and no `endedAt` on a provider the placement rule holds for (listed: `ACTIVE` with an active service, and claimed), read at request time. One provider's rows that nobody ended never overlap: checked under the provider's row lock, and enforced by the exclusion constraint `ProviderFeaturedPeriod_no_overlap` (`EXCLUDE USING gist ("providerId" WITH =, tsrange("startsAt", "endsAt") WITH &&) WHERE ("endedAt" IS NULL)`, extension `btree_gist`, migration `20261026000000_featured_placement_review_fixes`; Prisma does not model it). `grantedById` and `endedById` are plain ids. |
| PortfolioItem | One photo of the provider's «معرض الشغل» (B-16, D62; p37, f03, n07): `providerId` (cascades with the provider), `mediaKey` (unique: the verified `provider-portfolio` upload, consumed by the item as `PORTFOLIO_ITEM`), `imageUrl`, `album` (a label of 1 to 30 characters, or none), `forWomen` (exactly when the album is «حفلات النساء»), `noFaces` (the provider's confirmation; required for a women's photo), `status` `PENDING → APPROVED / REJECTED` (every new photo, and a kept one whose album or `noFaces` changed, is PENDING), `rejectionReason` (REJECTED only), `reviewedAt`, `reviewedById` (a plain id), `sortOrder` (the provider's order). Customers read APPROVED photos only, the women's album a bride only. A refused or removed photo's image becomes a media deletion job. CHECKs `PortfolioItem_album_check`, `PortfolioItem_for_women_check`, `PortfolioItem_women_no_faces_check`, `PortfolioItem_decision_check`. `Provider.socialLinks` keeps `{ tiktok?, instagram?, facebook? }` (https profile links on those hosts only). |
| PlanEvent | One of the wedding's events (D65; b12, b13): the wedding itself (`WEDDING`, on the plan's date), the customary nights (السمرة، المقيل؛ الحفلة، النسمة), عقد القران, الغداء, العشاء or a named one, with its day, time of day (or exact hour), place, who is in charge and a note. The wedding week (b04) and the wedding day (b05) are built from them. Owned by planning; read by every plan member, changed by the owner or a plan editor. |

## Wedding Financial OS Entities

| Entity | Purpose |
| --- | --- |
| WeddingPlan | The main planning record for a wedding. The Prisma model and owner-scoped API are implemented with `ownerUserId`, `title`, `city`, `weddingDate`, `estimatedBudget`, `currency`, `status`, `createdAt`, and `updatedAt`. |
| Notification | Implemented for persisted user-owned alerts with optional WeddingPlan context, type, title, body, JSON data, read timestamp, dedupe key, and timestamps. Notifications are private to the authenticated user; inbox indexes cover account-wide and plan-scoped pagination without scanning another user's rows. New provider-audience quote/chat alerts store generic text and explicit audience metadata instead of requester/sender contact identity. |
| PushInstallation | One Firebase Installation ID bound to one authenticated account and platform. The globally unique FID is moved atomically when a shared device signs into another account; account deletion cascades installations. |
| OutboxEvent | Durable PostgreSQL queue for conversation message/activity availability, notification availability, FCM delivery requests, conversation-access revocation, all-user-session revocation, and one-session revocation. Domain/session rows and their events commit together. Workers claim with `FOR UPDATE SKIP LOCKED`, reclaim stale locks, retry with bounded exponential delay, and retain exhausted events as `FAILED` dead letters. Strict realtime and push dispatch are processed only after their adapter action resolves; unavailable or rejected delivery remains retryable. |
| BudgetCategory | One plan-owned budget group with an optional allocation. Allocations never replace `WeddingPlan.estimatedBudget`. A positive allocation requires a non-null general budget, and total allocations may not exceed it. `kind` (B5, D55) is `WEDDING` (default) or `MAHR`: the groom's mahr item, outside the wedding budget, at most one per plan (partial unique index `BudgetCategory_one_mahr_per_plan`) and never with an allocation (CHECK `BudgetCategory_mahr_has_no_allocation`); a budget replacement reads and replaces only `WEDDING` items, and the budget's confirmed cost, paid and remaining count only them. Migration `20261026100000_add_mahr_and_starter_defaults`. |
| WeddingCost | The only cost backbone. Every cost belongs to a WeddingPlan and exactly one BudgetCategory, has a positive total, and may reference either an Aarast provider/accepted quote context or an external party. Paid and outstanding values come from its payment ledger. It has no due-date field; payment timing belongs only to `PaymentSchedule.dueDate`. `privateToUserId` (V1 checklist 4.10), when set, is the one account (the owner or the partner who recorded it) that sees the cost; null is the shared plan's. |
| CostPayment | An append-only money-out ledger under one WeddingCost. `PAYMENT` and `REVERSAL` are immutable rows; the original payment remains, one payment may have at most one reversal, and category/provider context is inherited through the cost instead of duplicated client input. This is planning data, not payment processing. |
| PaymentSchedule | A dated, non-reserving reminder under one WeddingCost. `dueDate` is required and is the only payment-reminder date. A pending schedule never changes totals, reserves outstanding balance, or blocks a direct payment. Each schedule is independently capped by the row-locked outstanding cost on create/update. Paying creates one linked CostPayment; reversing it reopens that schedule, while fully paying the cost cancels all other pending reminders. |
| CostReceipt | A receipt photo kept with a WeddingCost, optionally naming one of its CostPayments (same-cost composite FK). `storageKey` names private media read only through short-lived signed URLs. `uploadedByUserId` is a plain id (no FK to User): account erasure deletes the account's receipts explicitly. A cost with receipts cannot be deleted (Restrict). |
| Task | Implemented as `WeddingTask` for WeddingPlan planning work, including title, optional description/due date, status, priority, checklist support, and two exclusive responsibility modes: a registered participant through `assigneeUserId`, or a manual/contact responsible through optional `responsibleName`, `responsiblePhone`, and `responsibleSource`. A database CHECK prevents both modes from being stored together. `privateToUserId` (V1 checklist 4.10), when set, is the one account (the owner or the partner who created it) that sees the task; null is the shared plan's. Account erasure deletes the account's private costs (with their payments, schedules and receipts) and private tasks in other plans. |
| WeddingTaskChecklistItem | Implemented for task checklist rows tied to a WeddingTask. |
| SharedMember | Implemented for permission-based WeddingPlan collaboration. Its stored booleans are the final non-owner authority; role defaults seed invitations only and never act as a runtime fallback. Direct member creation stores omitted authorization flags as `false`. `canViewMoney` controls money reads, `canManageMoney` controls money writes, and task, guest, provider, plan-edit, and member-management permissions remain separate. `authorityVersion` advances when role or authorization flags change and is captured with history events. |
| ContributorHistoryScope | One durable history boundary per WeddingPlan. `historyCoverageStartsAt` makes the cutover explicit, lifecycle fields preserve an archived/deleted plan's audit boundary, and deleting the live plan reference sets `weddingPlanId` null rather than cascading history. |
| ContributorTenure | One period of contributor membership inside a history scope. It binds the current `SharedMember` while active, retains a SHA-256 `actorReference` across re-invitations, records join/tracking/end state and roles, and permits only one active tenure per scope and actor reference. The direct user/member links may be nulled without deleting the historical events. |
| ContributionEvent | Append-only, privacy-allowlisted snapshot of a contributor action or revocation boundary. It records section, entity type, optional source id, action, frozen JSON, snapshot/fingerprint hashes, provenance, required permission, policy/authority versions, occurrence time, and capture time. It is not a live relation to the source row: later source changes cannot rewrite the snapshot. |
| PlanInvite | Implemented for identity-bound sharing and atomic acceptance. Only a SHA-256 token fingerprint is persisted; raw external invite tokens are returned at creation time only. Invite-access OTP rows reference the exact invitation through `OtpCode.planInviteId` and cascade when it is deleted. Pending grants above a delegated inviter's newly narrowed stored ceiling are revoked in the same member-update transaction; acceptance also requires an active owner and active delegated inviter. |
| Guest | Implemented for WeddingPlan guest management. A database unique constraint permits at most one non-null `normalizedPhone` per WeddingPlan regardless of display name; null phones remain repeatable. Stored `phone` and `normalizedPhone` are the same canonical value, enforced by a database CHECK. Migration `20260726030000_enforce_unique_guest_phone` fails closed for historical conflicts instead of merging or deleting private guest data. `rsvpTokenHash` (unique) is the SHA-256 of the guest's personal RSVP link token (V1 checklist 4.7; the token is never stored) and `respondedAt` the time of the guest's last answer through it. |
| GuestGroup | Implemented for grouping WeddingPlan guests. |
| QuoteRequest | Implemented for non-binding pricing/package requests tied to a user, provider, service/category/city, and optionally a WeddingPlan. Lifecycle mutations lock this row first, re-read its state, and update only from the expected prior state. B-04 (D50): `expiresAt` (non-null; seven days from the request, or from a withdrawn offer; the database default is the same seven days for direct inserts), `expiryWarnedAt` (the provider was told the day before; cleared with a new window) and `expiredAt`; status `EXPIRED`, written only by the hourly job, never by a migration (`QuoteRequest_status_expiresAt_idx` serves it). B-08: `shareBudget` and `shareContact` (default `false`). Migration `20261025200000_add_quote_offer_versions_withdrawal_and_request_expiry` gave existing rows `expiresAt = createdAt + 7 days` and shares nothing. |
| QuoteOffer | Implemented for provider responses to quote requests. Lifecycle mutations lock the parent QuoteRequest and then the offer in one serializable transaction, so a losing accept/reject/update/cancel race cannot overwrite the winner. Accepting a plan-scoped offer rechecks provider and money permissions in that transaction and atomically creates or returns its one linked WeddingCost through the unique `WeddingCost.quoteOfferId`; this is still a planning record, not a paid booking. The row is the current version (B-06): `currentVersionNo`, `versionChanges` (`[{ field, from, to }]` against the previous version) and `revisedAt`; a revision writes only from the version it read. B-03: `WITHDRAWN` is now written, with `withdrawnAt` and `withdrawnReason`. |
| QuoteOfferVersion | Every version of an offer as the customer received it (B-06, D41): `versionNo` (unique per offer), title, message, amount, currency, `validUntil`, `changes` against the version before, `createdAt`. Written once, never updated; cascades with its offer. The migration wrote version 1 of every existing offer from its stored values. |
| PlanProviderLink | Implemented to connect an accepted provider/offer to a WeddingPlan as planning context. |

## Conversation And Session Entities

| Entity | Purpose |
| --- | --- |
| RefreshToken | Hashed, expiring, revocable refresh session with transactional rotation, replacement-chain tracking, and persisted `APPLICATION`/`ADMIN` scope. Every access JWT carries the current row id as `sid`; authorization requires that exact row to remain live for the same user and scope. |
| AdminLoginChallenge | Hashed, short-lived, one-time password-bound MFA challenge for browser admin login, bound by `otpId` to the exact private `ADMIN_LOGIN` OTP. It never stores the raw challenge or OTP. |
| AdminPasswordResetChallenge | Hashed, short-lived, one-time administrator password-recovery challenge bound to one exact OTP. It stores a token hash and HMAC phone digest, not the raw token or phone, and is invalidated on retry, expiry, failure ceiling, or success. |
| LoginThrottle | Durable cross-replica password-attempt admission window keyed only by an HMAC-SHA-256 account-and-realm digest using a deployment-only pepper. Application and administrator realms are isolated. Each request reserves a slot under the row lock before password comparison; five admitted attempts lock one realm for fifteen minutes. Successful authentication/reset clears it, and one hourly advisory-lock cleanup removes expired/inactive rows. |
| OtpDispatchQuota | Atomic cross-replica OTP delivery windows for phone, IP, and global scopes. Subjects are HMAC-SHA-256 digests; no raw phone or IP is persisted. Failed deliveries still consume quota and an hourly advisory-lock cleanup removes expired rows. |
| AssistantUsageDay | The planning assistant's account quota (V1 checklist 4.12), owned by identity like the OTP quota: one row per account per local (Asia/Riyadh) day with the questions asked, tokens and cost in micro-dollars. A question is reserved in one `INSERT .. ON CONFLICT .. WHERE requests < limit` statement before the model is called and given back if the call fails; the monthly spending cap sums the cost column. No question or answer text is stored. Rows cascade with the user. |
| MediaUploadTicket | Durable owner, purpose, declared/verified byte size, expiry, verification state, and consumption state for every signed upload. It enforces a rolling per-account quota and allows bounded cleanup of abandoned objects without trusting a client-supplied URL. |
| Conversation | One provider relationship thread. `PLAN` is unique by WeddingPlan + Provider; `ACCOUNT` is unique by requester User + Provider. The row owns last activity, administrative close, and customer/provider-side block state. |
| ConversationParticipant | Per-user joined/revoked, last-read, and personal mute state. It is not an authorization source; access is derived live from plan ownership, explicit provider-management permission, account request ownership, or the provider account. Send and mark-read lock and recheck the active row in the same serializable transaction; only an explicit permission grant may clear `revokedAt`. |
| ConversationEvent | Idempotent, non-sensitive QuoteRequest/QuoteOffer lifecycle activity merged with messages at timeline read time. Human content remains in ChatMessage only. |
| ChatMessage | Authored conversation message with delivery/read timestamps and no payment semantics. |
| ChatAttachment | Private object `storageKey` plus MIME/size metadata tied to a message; permanent or public download URLs are never stored. |
| ConversationReport | Participant report with moderation status; admin views do not expose message bodies. |

## Planning Principles

- WeddingPlan is the center of the MVP data model.
- WeddingPlan implementation depends on database persistence and an authenticated user context.
- Persistence/Auth readiness work has already moved past the original docs-only foundation. Future schema changes must still be explicit, phased, migrated, and smoke-tested.
- WeddingPlan remains the first Wedding Financial OS domain module after persistence and ownership prerequisites are ready.
- WeddingPlan's canonical financial relations are BudgetCategory, WeddingCost,
  CostPayment, and PaymentSchedule. Removed prelaunch finance models are not
  compatibility surfaces.
- Every WeddingPlan must have clear ownership.
- WeddingPlan ownership must not rely on a mock-auth shortcut; ownership must come from authenticated user context.
- Owner-scoped records should use an explicit `ownerUserId` pattern and must be checked against the authenticated user before private access.
- Shared access must be permission-based, not full access by default.
- Stored `SharedMember` permission flags are the sole non-owner authorization
  source. `SharedMember.role` supplies defaults only to a new invitation;
  direct member creation stores omitted authorization flags as `false`, and
  changing a role preserves omitted booleans and cannot restore an explicitly
  revoked capability.
- Live contributor reads require a current `SharedMember` and the relevant
  current stored flag, then restrict rows to current assignment or qualifying
  `ContributionEvent` ids for that actor reference across current and previous
  tenures. The shared `weddingPlanId` is never sufficient to expose another
  contributor's rows. History evidence does not bypass a revoked flag.
- Account contexts are derived at read time from `WeddingPlan.ownerUserId`,
  `SharedMember`, and `Provider.userId`; there is no context table, migration,
  or backfill. One account may therefore be an owner, contributor, and provider
  simultaneously. `WeddingPlan.status` and `Provider.status` supply live
  lifecycle truth. `User.role`, `User.appRole`, and `User.onboardingPath`
  remain compatibility metadata only and are not context authority.
- `PLANNING` plans are active contexts. `ARCHIVED` plans remain discoverable as
  historical read-only contexts and cannot validate as an active selection.
  Provider profile/operation capabilities use the canonical provider access
  policy: `ACTIVE` is operational; `PENDING` and `NEEDS_CHANGES` allow profile
  edits only; `SUSPENDED` and `REJECTED` expose read-only profile/status.
- Invite acceptance creates or preserves `SharedMember`, returns the canonical
  contributor context key, and does not write `User.activeWeddingPlanId`.
- Available account contexts are a derived API projection, not a new database
  entity. No role-membership or active-context table is required for the first
  backend phase.
- `User.activeWeddingPlanId` records only an explicit plan selection. If that
  plan is missing, archived, or inaccessible, active-plan reads return null and
  never choose another accessible plan automatically.
- `appRole` is not mutable through the public profile route and is not a source
  of context authorization. Provider application/profile operations remain the
  trusted owner of provider identity state.
- Financial data such as budgets, allocations, costs, payments, and payment
  schedules is private by default.
- Confirmed cost is the sum of non-cancelled WeddingCost totals. Paid is the net
  CostPayment ledger after reversals. Outstanding is confirmed cost minus paid.
  A PaymentSchedule contributes nothing until it creates a real payment, does
  not reserve outstanding balance, and cannot block a direct payment. Its
  amount is validated independently against current outstanding on create or
  update; fully paying the cost cancels pending reminders.
- A null `WeddingPlan.estimatedBudget` remains unset. Category allocations are
  never summed as a fallback general budget. The budget may be saved before any
  categories exist, but positive category allocations require a non-null
  general budget.
- SharedMember permissions are implemented as a backend slice; financial
  endpoints must not expose money data without `canViewMoney`, and every
  mutation requires `canManageMoney`.
- WeddingPlan update/archive authorization is serialized with the write:
  `WeddingPlan FOR UPDATE` precedes the acting non-owner's
  `SharedMember FOR SHARE`. Active-plan selection uses `User FOR UPDATE`, then
  `WeddingPlan FOR SHARE`, then the applicable `SharedMember FOR SHARE`, so
  account deletion, membership removal, and selection use one stable order.
- Delegated member/invite administration uses retryable `SERIALIZABLE`
  transactions ordered as `WeddingPlan FOR SHARE`, acting
  `SharedMember FOR SHARE`, then the target row. Member update/removal take
  `SharedMember(target) FOR UPDATE`; invitation state transitions use
  conditional writes against their expected live state. Permission and
  lifecycle checks, authority ceilings, writes, and dependent cleanup share the
  same transaction.
- Task mutations use retryable `SERIALIZABLE` transactions ordered as
  `WeddingPlan FOR SHARE`, acting `SharedMember FOR SHARE`, applicable assignee
  `SharedMember FOR SHARE`, `WeddingTask FOR UPDATE`, then checklist row
  `FOR UPDATE` where applicable.
- Guest and GuestGroup mutations use retryable `SERIALIZABLE` transactions
  ordered as `WeddingPlan FOR SHARE`, acting `SharedMember FOR SHARE`,
  referenced `GuestGroup FOR SHARE`, then the target guest/group `FOR UPDATE`
  where applicable. Bulk guest creation is one atomic transaction, and
  `(weddingPlanId, normalizedPhone)` is the database-enforced concurrency
  invariant.
- All fifteen canonical financial mutations recheck lifecycle and authority in
  retryable `SERIALIZABLE` transactions. Budget/category replacement takes
  `WeddingPlan FOR UPDATE` before category rows. Cost create/update orders
  referenced `Provider` rows, `QuoteOffer` rows, `BudgetCategory` rows, then
  `WeddingCost`; payment and schedule writes order the plan/member gate before
  `WeddingCost` and child ledger/reminder rows. The money summary permission
  decision and data use one `REPEATABLE READ` snapshot, while a budget-write
  response summary is built inside the mutation transaction itself.
- Marketplace entities support planning and quote/lead context; they must not replace the financial planning core.
- No payment processing, deposit, confirmed booking, loan, credit, or financing
  data should be added until explicitly approved in a later phase.
- Production migrations and Docker/Dokploy deployment work remain separate from docs-only tasks unless explicitly requested.
- New database migrations are outside docs-only tasks.

## Implemented Contributor Authority And Frozen History

Migration `20260802090000_add_contributor_history` adds
`SharedMember.authorityVersion`, the contribution enums, and the three durable
history models. It creates one `ContributorHistoryScope` per existing plan and
one active `ContributorTenure` per existing `SharedMember`. Count assertions
abort the transaction if either baseline cannot be represented exactly.

Repair migration
`20260811180000_backfill_missing_contributor_history_scopes` closes the case in
which an older direct writer created a live `WeddingPlan` without its history
scope. With lock order matching runtime writes, it creates only missing scopes,
preserves planning/archived lifecycle truth, and reconstructs active tenures
only from an existing `SharedMember`. Postconditions require every live plan to
have one linked scope with matching lifecycle state and every live shared
member to have the expected active tenure; detached `DELETED` scopes remain
valid audit history. The migration is idempotent and was rehearsed twice on
PostgreSQL 16. Production revision
`900897a90e8b030c7c3ddfdc55cc2669b64f2e87` deployed it successfully: 15 live
plans, 15 linked scopes, and zero missing scopes, lifecycle mismatches, missing
tenures, or unfinished migrations.

Runtime writes create a `ContributionEvent` in the same domain transaction as
the contributor action. A canonical, recursively key-sorted JSON hash and an
event fingerprint make a retry with the same tenure/dedupe key safe; reuse of
that key for different content is a conflict. Database constraints require a
non-empty dedupe key, positive schema/policy/authority versions, matching
section/permission/action/provenance combinations, a JSON object no larger than
16 KiB, and a tenure from the same history scope. Unique and query indexes cover
one active tenure per `(historyScopeId, actorReference)`, one event per
`(contributorTenureId, dedupeKey)`, chronological contributor reads, section
reads, and source-entity qualification.

The frozen snapshot is built from an entity-type allowlist rather than a source
object dump. Runtime validation rejects contact/credential/payload keys and
phone, email, bearer, token, secret, or signature-shaped values, and bounds
string, array, object, depth, and total size. The snapshot is committed at the
time of the contributor's qualifying create/complete/payment/invite action.
Revoking a stored permission does not query or copy the live source row and
does not convert an assignment-only row into history; it writes only a
`SECTION_REVOKED` boundary before committing the authority change. A PostgreSQL
trigger rejects every later `UPDATE` or `DELETE` of `ContributionEvent`. A
separate tenure trigger keeps actor, plan scope, membership identity,
join/tracking timestamps, and starting role immutable; it permits only a valid
one-way close or the controlled user-reference detach required by account
deletion. Event-to-scope and event-to-tenure foreign keys use `RESTRICT`, while
`entityId` is a scalar audit reference rather than a cascading relation, so
source-row changes cannot erase the frozen event.

The migration backfill is evidence-only and deliberately incomplete:

- `WeddingTask.assigneeUserId` proves a current member's task assignment and is
  captured as `LEGACY_CAPTURED`.
- plan-scoped `QuoteRequest.userId` proves its current member creator and is
  captured as `LEGACY_CAPTURED`.
- `PlanInvite.inviterUserId` proves its current member inviter and is captured
  as `LEGACY_CAPTURED`.

Each legacy row is attributed only when the directly referenced user still has
the matching current tenure. The migration does not invent a previous tenure,
does not infer authorship from plan membership, and explicitly does not treat
an accepted invitation as proof of who created or managed a member. Historical
guest, money, completion, or other activity without a direct source column
remains unattributed. Legacy free text is omitted when it is oversized or
matches digits, email, token, secret, or signature patterns; no production row
is silently reassigned or deleted. `historyCoverageStartsAt` marks the point
from which complete runtime event capture is expected.

## Account Deletion Grace and Data Downloads (D63)

Migration `20261028200000_account_deletion_grace_and_data_exports` adds to
`User`: `deletionRequestedAt` and `deletionScheduledFor` (both null, or both set
with the schedule after the request: `User_deletion_request_whole_check`),
`deletionPurgeFailedAt` and `deletionPurgeFailure` (only on a pending request:
`User_deletion_failure_pending_check`), `reviewFirstNameOnly` (default true),
and the index on `deletionScheduledFor` the hourly purge reads. The new model
`DataExport` (identity) is one download of an account's own data: `userId`
(cascade), `tokenHash` (unique `CHAR(64)` digest; the token itself is never
stored), `createdAt`, `expiresAt` (after `createdAt`), `downloadedAt`. Rows
older than a week are removed by the purge job. The receipt below is written by
the purge (request id `grace:<requestedAt>`), no longer by an HTTP command.

## Durable Account Deletion Receipt

Migration `20260803110000_add_account_deletion_receipts` creates
`AccountDeletionReceipt` as an anonymous completion proof for central account
deletion. Its primary key is a 64-character lowercase SHA-256 digest over the
former user id, a separator, and the stable high-entropy client request id. The
transaction inserts this receipt before deleting the `User`; neither source
identifier, phone, token, profile, nor deletion payload is retained. An index
supports bounded operational retention by deletion time, and database triggers
reject every receipt `UPDATE` or `DELETE` so a committed lost response can be
reconciled without resurrecting or guessing account state.

The public status query derives the same digest and returns only `DELETED`,
`PENDING`, or `NOT_STARTED`. It reads the receipt and matching idempotency
reservation in one database snapshot. A fresh reservation remains `PENDING`;
an unfinished reservation older than twice the account-deletion transaction
timeout may be reclaimed only after locking the still-live `User` and
rechecking the receipt. This table has no foreign key to `User` by design: it
must survive successful erasure while remaining unlinkable without both
high-entropy source values.

## Implemented Provider Reference Foundation

The backend now includes the approved provider-reference and quote-lead foundation:

- `OtpCode` for local, Meta WhatsApp, or temporary hardened OpenWA OTP
  request/verify flows, storing only hashed codes. General purposes use one
  unconsumed row per `(phone, purpose)` with `planInviteId IS NULL`.
  `INVITE_ACCESS` uses a non-null `planInviteId` and one unconsumed row per
  `(phone, purpose, planInviteId)`, so a login code and multiple live
  invitations for one phone remain isolated. The invitation foreign key
  cascades on deletion. Migration
  `20260726040000_isolate_invite_access_otps` installs the enum value, relation,
  and both partial unique indexes. Migration
  `20260726041000_enforce_invite_otp_context` adds
  `OtpCode_invite_access_context_check`: `INVITE_ACCESS` requires a non-null
  `planInviteId`, while every other purpose requires it to be null.
  Migration `20260729010000_track_application_password_setup` adds
  `User.appPasswordConfiguredAt`, preserves explicitly configured ordinary and
  admin-application credentials, leaves only the historical generated invite
  accounts unset, and revokes their old application refresh sessions until a
  token-and-phone-bound recovery replaces the generated password.
  Verification takes a row lock and commits comparison outcome, bounded failure
  count, terminal exhaustion, or one-time consumption in one retryable
  transaction so concurrent attempts cannot exceed the stored ceiling or both
  succeed.
- `LoginThrottle` replaces process-local password counters with a PostgreSQL
  row-locked attempt-admission window shared by all replicas. A forced `upsert`
  acquires the subject row and reserves the attempt before password comparison,
  so concurrent requests observe the prior committed count without a
  serialization-conflict gap and cannot execute comparisons beyond the ceiling. Its key is an
  HMAC-SHA-256 digest made with `AUTH_LOGIN_THROTTLE_PEPPER`; it stores no raw
  phone, email, password, IP address, pepper, or request body. Production fails
  closed without the pepper. An hourly transaction-level advisory lock ensures
  one replica removes expired locks and inactive windows, supported by the
  `updatedAt` index added in `20260711223000_harden_login_throttle`.
- `OtpDispatchQuota` adds a durable sending safety ceiling independent from
  code verification. The composite scope/hash key makes each fixed window
  atomic across replicas; migration `20260712120000_add_otp_dispatch_quotas`
  adds its table and cleanup index.
- Existing accounts with null `phoneVerifiedAt` keep their data but all active
  refresh sessions are revoked; they must prove phone ownership before a new
  session can be issued. Verified registration claims an existing unverified
  user/provider row in place instead of creating a duplicate or discarding its
  role and relations.
- `AdminLoginChallenge` binds a successful admin password check to one private
  `ADMIN_LOGIN`
  OTP for at most ten minutes. Deployment revokes legacy admin refresh rows;
  every application and administrator access JWT is now bound through `sid` to
  its live refresh-session row, so rotation and logout invalidate the prior
  access token immediately.
- `AdminPasswordResetChallenge` separates administrator recovery from general
  application password reset. An administrator may use one phone identity in
  both products, but the app password and browser-admin password remain
  independent and neither recovery route can overwrite the other.
- The shared `User` row does not make those two identities one deletion realm.
  Application-account deletion removes an enrolled administrator's `app*`
  identity fields and application-owned relations, revokes only
  `APPLICATION` sessions/OTPs, and retains administrator credentials,
  challenges, audit links, `USER_AVATAR` media, and `ADMIN` sessions. Ordinary
  wedding users/providers continue to delete the complete User row. The same
  anonymous `AccountDeletionReceipt` proves completion in both cases without
  storing the former user id or client request id.
- Refresh rows persist their application/administrator scope; logout, reset,
  rotation, and token-family compromise revocation stay inside that scope.
  Rotation locks one replacement chain. Any reuse of a revoked or replaced
  token, including an immediate duplicate request, revokes active descendants
  in that family only. Independent login families and the other realm remain
  unaffected. Logout presented with an older token follows the chain to its
  live descendant. A cycle or traversal beyond the 4,096-row family limit makes
  the chain incomplete. One bounded recursive CTE retrieves at most 4,097 rows
  and locks the traversed token rows through one `FOR UPDATE` query rather than
  one lock query per generation. An incomplete family fails closed by revoking
  every active refresh row for the same user and scope. This realm-wide
  fallback remains isolated between `APPLICATION` and `ADMIN`; normal replay
  does not revoke independent login families.
  Application session revocations also enqueue `SESSION_REVOKED` or
  `USER_SESSIONS_REVOKED` in the same transaction for durable cross-replica
  Chat disconnect.
- Terminal refresh sessions have bounded security retention: revoked rows are
  removed 30 days after `revokedAt`, while unrevoked expired rows are removed
  30 days after `expiresAt`. The same hourly advisory-lock cleanup guarantees
  that only one replica performs the deletion.
- Expired OTP and authentication challenge rows are retained for one day and
  then removed by a distinct advisory-lock cleanup job.
- User profile additions: `phoneVerifiedAt`, `lastLoginAt`, `avatarUrl`, and `locale`.
- `NotificationPreference` stores three effective content preferences for task,
  payment, and provider/quote/chat notifications. In-app delivery is always
  available and is not a stored toggle. When no preference row exists, the
  three content categories default to enabled. SMS, WhatsApp, and email remain
  forced to `false`. Push is device-managed: registering the first
  `PushInstallation` enables it and removing the last enabled installation
  disables it. Settings writes cannot enable push directly. Preference-aware
  notification creation and installation reassignment lock the owning users so
  a committed change cannot be followed by delivery decided from stale state.
- `PushInstallation` stores a unique Firebase Installation ID, authenticated
  `userId`, platform, enabled state, and last-seen/timestamps. Migration
  `20260729020000_add_firebase_push_installations` also adds
  `NotificationType.TASK_ASSIGNED`.
- B4 (D58): migration `20261027000000_review_reply_and_notification_types`
  adds `NotificationType` values `BOOKING_REQUESTED`, `REVIEW_RECEIVED`,
  `REVIEW_REPLIED`, `PROVIDER_APPROVED`, `PROVIDER_NEEDS_CHANGES`,
  `PROVIDER_REJECTED`, `PROVIDER_SUSPENDED`, `PROVIDER_IN_REVIEW`,
  `PROVIDER_CLAIM_DECIDED`, `LISTING_PLAN_CHANGED`, and the provider's one
  reply on `ProviderReview` (`replyBody`, `repliedAt`, `replyStatus`
  PUBLISHED or HIDDEN; CHECK `ProviderReview_reply_complete`: all three or
  none). Migration `20261027000100_notice_types_and_routes_backfill` moves
  the notices already written to their types and to the routes the server
  writes now, and names each booking step in `data.bookingEvent`; their
  words stay as written.
- B3 (D60): migration `20261027100000_provider_daily_capacity_and_expired_bookings`
  adds `Provider.dailyBookingCapacity` (INTEGER NOT NULL DEFAULT 1, CHECK 1 to
  20), drops the partial unique index `Booking_provider_confirmed_date_key`,
  adds `BookingStatus.EXPIRED` and `Booking.expiredAt`. Existing providers
  keep one wedding a day; no row changes.
- B-16 (D62): migration `20261028100000_provider_portfolio` adds
  `NotificationType.PORTFOLIO_REVIEWED`, the enum `PortfolioItemStatus`
  (PENDING, APPROVED, REJECTED), `Provider.socialLinks` (JSONB, nullable) and
  the table `PortfolioItem` with its CHECKs (album 1 to 30 characters;
  `forWomen` exactly when the album is «حفلات النساء»; a women's photo has
  `noFaces`; PENDING has no decision, APPROVED a time, REJECTED a time and a
  reason). No row changes.
- D65: migration `20261029000000_plan_events` adds the enums `PlanEventType`
  (WEDDING, SAMRA, MAQEEL, HAFLA, NASHMA, AQD, LUNCH, DINNER, CUSTOM) and
  `PlanEventTimeSlot` (DUHA, DHUHR, AFTER_DHUHR, AFTER_ASR, AFTER_MAGHRIB,
  AFTER_ISHA, EXACT) and the planning-owned table `PlanEvent`
  (`weddingPlanId` RESTRICT, `type`, `title`, `date` DATE, `timeSlot`,
  `exactTime` `HH:mm`, `placeLabel`, `responsibleName`, `note`). The partial
  unique index `PlanEvent_one_per_type` keeps every kind but CUSTOM once per
  plan; CHECKs keep a CUSTOM event's name, keep the WEDDING event without a
  date of its own (it is the plan's wedding date) and tie `exactTime` to
  `EXACT`. Planning's plan erasure deletes a plan's events before the plan.
  No row changes.
- `Notification` for persisted task, payment-schedule, sharing, and quote alerts
  with deduplication. Migration
  `20260726010000_scrub_notification_contact_pii` rewrites historical
  provider-portal quote-request bodies and conversation-message alert bodies to
  generic text. Contact identity remains in the permission-checked
  quote/conversation records; the migration does not log the former values.
- `IdempotencyKey` for client-generated request idempotency on mutating
  endpoints (offline-queue replays return the original response instead of
  duplicating financial records). Each key is bound to a SHA-256 fingerprint of
  method + concrete target + canonical body, while only the safe route template
  is stored in readable form. `expiresAt` bounds active reservations and
  completed replay responses; an hourly, advisory-lock-protected job removes
  only expired completed rows across replicas. Expired rows with no
  `completedAt` remain fail-closed as ambiguous tombstones until the
  evidence-gated operations reconciler either releases one proven
  non-committed request or stores the exact replay for one proven committed
  request. Migration
  `20260710173000_bind_idempotency_requests` expires legacy unbound rows. Stored
  paths use route templates only;
  migration `20260710140000_redact_legacy_idempotency_paths` removes legacy
  invite bearer values and query strings.
- `Guest` and `GuestGroup` for saved WeddingPlan guest lists and grouping.
  Migration `20260726030000_enforce_unique_guest_phone` takes a bounded
  exclusive lock, canonicalizes accepted historical forms into both phone
  columns, and installs `Guest_weddingPlanId_normalizedPhone_key` plus
  `Guest_phone_normalizedPhone_match_check`. It aborts transactionally with
  generic non-PII errors on an orphaned normalized value, unparseable source
  value, or canonical duplicate; no guest is merged or deleted.
- `City` and `ProviderCategory` for Yemen-first marketplace filters. Fresh
  databases receive an additive baseline catalog from migration
  `20260714100000_seed_provider_reference_catalog`; existing admin-managed rows
  are preserved without forced deletion. Migration
  `20260729050000_reconcile_provider_category_catalog` handles the narrower
  historical production-bootstrap case by canonical slug: it normalizes the
  shared groom/bride catalog, moves provider and service references from eight
  known Arabic-slug duplicates, and deactivates those duplicates without
  deleting rows or losing relationships.
- The money starter items (`money.starter.categories`, G12, D55): honeymoon
  (groom, bride, shared) and the bride's home are recommended. Migration
  `20261026100000_add_mahr_and_starter_defaults` publishes revision 2 with
  `isRecommended = true` only for those items still on the system's first
  revision; an item an administrator edited keeps his revision. New items (the
  shared gold item, the bride's gold and trousseau tasks) reach a database
  from the system defaults like every system item.
- The mahr (B5, D55): `BudgetCategory.kind = MAHR` for the groom (above),
  `FundingSourceKind.MAHR` for the bride, and `FundingSource.expectedAt`, the
  day pledged money is expected (the mahr's rest). D59, no schema change: the
  groom's mahr counts as recorded while the MAHR item holds a non-cancelled
  `WeddingCost` (an emptied item is reused, never a second one); a
  `WeddingCost` never moves between a `WEDDING` and the `MAHR` item; `MAHR`
  funding exists only on a `BRIDE` plan and a source never changes kind to or
  from it; a pledged source past its `expectedAt` is reported overdue (read,
  not stored).
- `Provider`, `ProviderService`, `ProviderServiceImage`, and `ProviderPackage`
  for public planning references. Every externally supplied `numeric(14,2)`
  provider price is bounded by the central money validator before persistence;
  null/blank optional values remain null and extra precision is never delegated
  to database rounding. A service has no featured flag: migration
  `20261026000000_featured_placement_review_fixes` dropped
  `ProviderService.isFeatured` (the admin «تمييز» button); featuring is the
  provider's placement only (D54).
- `FavoriteProvider`, `ProviderReview`, `QuoteRequest`, `QuoteOffer`, and
  `PlanProviderLink` for saved providers, reviews, quote leads, and accepted
  planning provider links. The unused prelaunch `BookingLead` model was removed;
  accepting an offer remains a planning decision and never creates a booking.
  `Provider.ratingAverage` and `ratingCount` are cached public aggregates only:
  every review mutation locks the Provider row, changes the review, derives the
  published-only aggregate, and stores it inside one serializable transaction.
  Account erasure explicitly refreshes surviving providers instead of relying
  on the `ProviderReview.userId` cascade. Migration
  `20260724180500_reconcile_provider_rating_cache` safely re-derives all
  pre-existing caches during upgrade without deleting review data.
- `WeddingCost`, `CostPayment`, and `PaymentSchedule` for category-first costs,
  actual money-out records, and dated payment reminders.
- `WeddingTaskChecklistItem` plus task assignment support.
- `PlanInvite` for invite-based collaboration.

These models do not add payment processing, deposits, confirmed reservations,
loans, credit, or financing behavior.

The generated model inventory below is refreshed from Prisma by
`scripts/docs-sync.mjs`. Do not interpret stale generated rows from an in-flight
rewrite as permission to restore a removed live model.

<!-- DOCS-SYNC:START -->
<!-- AUTO-GENERATED by scripts/docs-sync.mjs. Do not edit by hand. -->

| Model | Field count | Notable fields |
| --- | --- | --- |
| `IdempotencyKey` | 10 | `id`, `userId`, `completedAt`, `expiresAt`, `createdAt` |
| `AccountDeletionReceipt` | 2 | `deletedAt` |
| `User` | 58 | `id`, `appAccountActivatedAt`, `phoneVerifiedAt`, `lastLoginAt`, `activeWeddingPlanId`, `onboardingCompletedAt`, `deletionRequestedAt`, `deletionPurgeFailedAt` |
| `DataExport` | 7 | `id`, `userId`, `createdAt`, `expiresAt`, `downloadedAt` |
| `MediaUploadTicket` | 16 | `userId`, `expiresAt`, `verifiedAt`, `consumedAt`, `consumedById`, `deletedAt`, `createdAt`, `updatedAt` |
| `AdminLoginChallenge` | 9 | `id`, `userId`, `otpId`, `expiresAt`, `consumedAt`, `createdAt` |
| `AdminPasswordResetChallenge` | 13 | `id`, `userId`, `otpId`, `expiresAt`, `consumedAt`, `verifiedAt`, `createdAt` |
| `AdminAuditLog` | 13 | `id`, `eventId`, `actorUserId`, `targetId`, `requestId`, `createdAt` |
| `RefreshToken` | 9 | `id`, `userId`, `expiresAt`, `revokedAt`, `replacedById`, `createdAt` |
| `LoginThrottle` | 5 | `windowStartedAt`, `updatedAt` |
| `OtpDispatchQuota` | 5 | `windowStartedAt`, `updatedAt` |
| `AssistantUsageDay` | 8 | `userId`, `updatedAt` |
| `WeddingPlan` | 33 | `id`, `ownerUserId`, `onboardingCompletedAt`, `importMigrationId`, `createdAt`, `updatedAt` |
| `PlanEvent` | 14 | `id`, `weddingPlanId`, `createdAt`, `updatedAt` |
| `BudgetCategory` | 12 | `id`, `weddingPlanId`, `createdAt`, `updatedAt` |
| `WeddingCost` | 25 | `id`, `weddingPlanId`, `budgetCategoryId`, `providerId`, `quoteOfferId`, `privateToUserId`, `createdAt`, `updatedAt` |
| `CostPayment` | 15 | `id`, `weddingCostId`, `paidAt`, `paymentScheduleId`, `reversalOfId`, `createdAt` |
| `CostReceipt` | 10 | `id`, `weddingCostId`, `costPaymentId`, `uploadedByUserId`, `createdAt` |
| `PaymentSchedule` | 11 | `id`, `weddingCostId`, `paidAt`, `createdAt`, `updatedAt` |
| `FundingSource` | 14 | `id`, `weddingPlanId`, `receivedAt`, `expectedAt`, `createdAt`, `updatedAt` |
| `LoanRepayment` | 10 | `id`, `fundingSourceId`, `paidAt`, `createdAt`, `updatedAt` |
| `WeddingTask` | 23 | `id`, `weddingPlanId`, `assigneeUserId`, `reminderAt`, `privateToUserId`, `linkedBudgetCategoryId`, `linkedCostId`, `linkedScheduleId` |
| `WeddingTaskChecklistItem` | 8 | `id`, `taskId`, `createdAt`, `updatedAt` |
| `SharedMember` | 18 | `id`, `weddingPlanId`, `userId`, `createdAt`, `updatedAt` |
| `ContributorHistoryScope` | 11 | `id`, `weddingPlanId`, `historyCoverageStartsAt`, `archivedAt`, `deletedAt`, `createdAt`, `updatedAt` |
| `ContributorTenure` | 17 | `id`, `historyScopeId`, `actorUserId`, `sharedMemberId`, `joinedAt`, `trackingStartedAt`, `endedAt`, `createdAt` |
| `ContributionEvent` | 20 | `id`, `historyScopeId`, `contributorTenureId`, `entityId`, `occurredAt`, `capturedAt` |
| `PlanInvite` | 30 | `id`, `weddingPlanId`, `inviterUserId`, `inviteeUserId`, `expiresAt`, `acceptedAt`, `declinedAt`, `revokedAt` |
| `OtpCode` | 14 | `id`, `expiresAt`, `consumedAt`, `createdAt`, `updatedAt`, `planInviteId` |
| `NotificationPreference` | 12 | `id`, `userId`, `createdAt`, `updatedAt` |
| `PushInstallation` | 9 | `id`, `userId`, `lastSeenAt`, `createdAt`, `updatedAt` |
| `Notification` | 18 | `id`, `userId`, `weddingPlanId`, `entityId`, `readAt`, `archivedAt`, `createdAt`, `updatedAt` |
| `OutboxEvent` | 14 | `id`, `aggregateId`, `nextAttemptAt`, `lockedAt`, `processedAt`, `createdAt`, `updatedAt` |
| `Guest` | 21 | `id`, `weddingPlanId`, `groupId`, `respondedAt`, `createdAt`, `updatedAt` |
| `GuestGroup` | 9 | `id`, `weddingPlanId`, `createdAt`, `updatedAt` |
| `GuestInvitationCard` | 10 | `id`, `weddingPlanId`, `createdAt`, `updatedAt` |
| `GuestEventInvite` | 10 | `id`, `guestId`, `planEventId`, `respondedAt`, `createdAt`, `updatedAt` |
| `City` | 11 | `id`, `createdAt`, `updatedAt` |
| `Governorate` | 11 | `id`, `createdAt`, `updatedAt` |
| `District` | 13 | `id`, `governorateId`, `createdAt`, `updatedAt` |
| `AdministrativeLocality` | 16 | `id`, `districtId`, `parentId`, `createdAt`, `updatedAt` |
| `ReferenceCatalog` | 9 | `id`, `createdAt`, `updatedAt` |
| `ReferenceCatalogItem` | 9 | `id`, `catalogId`, `createdAt`, `updatedAt` |
| `ReferenceCatalogItemRevision` | 19 | `id`, `itemId`, `createdAt` |
| `ProviderCategory` | 13 | `id`, `createdAt`, `updatedAt` |
| `Provider` | 49 | `id`, `userId`, `cityId`, `primaryCategoryId`, `reviewedAt`, `reviewedById`, `resubmittedAt`, `reopenedAt` |
| `ProviderService` | 19 | `id`, `providerId`, `categoryId`, `priceUpdatedAt`, `cityId`, `createdAt`, `updatedAt` |
| `ProviderServiceImage` | 7 | `id`, `serviceId`, `createdAt` |
| `ProviderPackage` | 13 | `id`, `providerId`, `serviceId`, `createdAt`, `updatedAt` |
| `FavoriteProvider` | 6 | `id`, `userId`, `providerId`, `createdAt` |
| `ProviderReview` | 14 | `id`, `userId`, `providerId`, `createdAt`, `updatedAt`, `repliedAt` |
| `QuoteRequest` | 39 | `id`, `userId`, `weddingPlanId`, `providerId`, `serviceId`, `cityId`, `acceptedAt`, `rejectedAt` |
| `QuoteOffer` | 28 | `id`, `quoteRequestId`, `providerId`, `revisedAt`, `revisionNoticeAt`, `withdrawnAt`, `createdAt`, `updatedAt` |
| `PlanProviderLink` | 12 | `id`, `weddingPlanId`, `providerId`, `quoteRequestId`, `quoteOfferId`, `createdAt`, `updatedAt` |
| `Booking` | 27 | `id`, `quoteRequestId`, `quoteOfferId`, `providerId`, `requestedByUserId`, `confirmedAt`, `declinedAt`, `cancelledAt` |
| `BookingChange` | 12 | `id`, `bookingId`, `requestedByUserId`, `decidedAt`, `createdAt`, `updatedAt` |
| `ProviderBlockedDate` | 5 | `id`, `providerId`, `createdAt` |
| `ProviderProfileViewDay` | 4 | `providerId` |
| `ProviderReviewEvent` | 8 | `id`, `providerId`, `actorId`, `createdAt` |
| `ProviderReviewNote` | 5 | `id`, `eventId` |
| `ProviderClaimRequest` | 9 | `id`, `providerId`, `userId`, `createdAt`, `decidedAt`, `decidedById` |
| `QuoteOfferVersion` | 13 | `id`, `quoteOfferId`, `createdAt` |
| `ProviderFeaturedPeriod` | 14 | `id`, `providerId`, `startsAt`, `endsAt`, `grantedById`, `createdAt`, `endedAt`, `endedById` |
| `PortfolioItem` | 15 | `id`, `providerId`, `reviewedAt`, `reviewedById`, `createdAt`, `updatedAt` |
| `ReviewReport` | 9 | `id`, `reviewId`, `reporterUserId`, `resolvedAt`, `createdAt`, `updatedAt` |
| `Conversation` | 23 | `id`, `weddingPlanId`, `accountRequesterUserId`, `providerId`, `createdByUserId`, `lastActivityAt`, `closedAt`, `customerSideBlockedAt` |
| `ConversationParticipant` | 11 | `id`, `conversationId`, `userId`, `joinedAt`, `revokedAt`, `lastReadAt`, `mutedAt`, `createdAt` |
| `ConversationEvent` | 14 | `id`, `conversationId`, `quoteRequestId`, `quoteOfferId`, `actorUserId`, `occurredAt`, `createdAt` |
| `ChatMessage` | 11 | `id`, `conversationId`, `senderUserId`, `editedAt`, `deletedAt`, `createdAt`, `updatedAt` |
| `ChatAttachment` | 7 | `id`, `messageId`, `createdAt` |
| `ConversationReport` | 9 | `id`, `conversationId`, `reporterUserId`, `createdAt`, `updatedAt` |

Total models: 71
<!-- DOCS-SYNC:END -->
