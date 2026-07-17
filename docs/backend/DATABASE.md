# Database Plan

This document describes the product data model at a planning/status level. It does not replace `backend/prisma/schema.prisma` as the schema source of truth.

Current documentation snapshot: 2026-07-17. Route-level behavior belongs in
`docs/backend/API_CONTRACT.md`.

## Current And Marketplace Entities

| Entity | Purpose |
| --- | --- |
| User | Represents a person using Aarast, such as groom, bride, family member, provider, or admin. `phone` is important for Yemen-first usage. `passwordHash` stores the application password for ordinary users/providers and the browser-administration password for admins. An admin may separately enroll `appPasswordHash` plus `appName`, `appEmail`, and `appAvatarUrl` for the wedding application; app responses project this identity as a normal user and never expose admin metadata. Neither password hash is returned or stored as plaintext. Current roles include `USER`, `ADMIN`, and `PROVIDER`; provider flows are implemented as planning/reference and quote-lead flows, not paid marketplace or confirmed booking flows. |
| Provider | Represents a vendor or business that offers wedding-related services. |
| Service | Represents a specific service offered by a provider, such as hall rental, photography, salon, catering, or decoration. |
| Category | Groups services into discoverable wedding-service categories. |
| City | Supports Yemen-specific location filtering and local availability. |
| BookingLead | Represents a non-binding planning lead tied to an accepted provider offer on a WeddingPlan. In the MVP, this means interest or lead tracking only, not paid booking, confirmed reservation, or deposit. Lifecycle is tracked via `BookingLeadStatus` (NEW, IN_PROGRESS, CONFIRMED, CANCELLED, COMPLETED). |
| Favorite | Lets users save providers or services for later comparison. |
| Review | Captures user feedback about a provider/service reference. Reviews are implemented as provider-reference support, not as paid marketplace monetization. |
| Package | Represents bundled provider offerings, such as full hall packages or photography packages. |

## Wedding Financial OS Entities

| Entity | Purpose |
| --- | --- |
| WeddingPlan | The main planning record for a wedding. The Prisma model and owner-scoped API are implemented with `ownerUserId`, `title`, `city`, `weddingDate`, `estimatedBudget`, `currency`, `status`, `createdAt`, and `updatedAt`. |
| Notification | Implemented for persisted user-owned alerts with optional WeddingPlan context, type, title, body, JSON data, read timestamp, dedupe key, and timestamps. Notifications are private to the authenticated user; inbox indexes cover account-wide and plan-scoped pagination without scanning another user's rows. |
| OutboxEvent | Durable PostgreSQL queue for notification-created and conversation-message-available events. Domain rows and events commit together; workers claim with `FOR UPDATE SKIP LOCKED`, reclaim stale locks, retry with bounded exponential delay, and retain exhausted events as `FAILED` dead letters. |
| BudgetCategory | One plan-owned budget group with an optional allocation. Allocations never replace `WeddingPlan.estimatedBudget`. A positive allocation requires a non-null general budget, and total allocations may not exceed it. |
| WeddingCost | The only cost backbone. Every cost belongs to a WeddingPlan and exactly one BudgetCategory, has a positive total, and may reference either an Aarast provider/accepted quote context or an external party. Paid and outstanding values come from its payment ledger. It has no due-date field; payment timing belongs only to `PaymentSchedule.dueDate`. |
| CostPayment | An append-only money-out ledger under one WeddingCost. `PAYMENT` and `REVERSAL` are immutable rows; the original payment remains, one payment may have at most one reversal, and category/provider context is inherited through the cost instead of duplicated client input. This is planning data, not payment processing. |
| PaymentSchedule | A dated, non-reserving reminder under one WeddingCost. `dueDate` is required and is the only payment-reminder date. A pending schedule never changes totals, reserves outstanding balance, or blocks a direct payment. Each schedule is independently capped by the row-locked outstanding cost on create/update. Paying creates one linked CostPayment; reversing it reopens that schedule, while fully paying the cost cancels all other pending reminders. |
| Task | Implemented as `WeddingTask` for WeddingPlan planning work, including title, optional description/due date, status, priority, checklist support, and two exclusive responsibility modes: a registered participant through `assigneeUserId`, or a manual/contact responsible through optional `responsibleName`, `responsiblePhone`, and `responsibleSource`. A database CHECK prevents both modes from being stored together. |
| WeddingTaskChecklistItem | Implemented for task checklist rows tied to a WeddingTask. |
| SharedMember | Implemented for permission-based WeddingPlan collaboration. `canViewMoney` controls all money reads and `canManageMoney` controls money writes; task, guest, provider, and member-management permissions remain separate. |
| PlanInvite | Implemented for identity-bound sharing and atomic acceptance. Only a SHA-256 token fingerprint is persisted; raw external invite tokens are returned at creation time only. |
| Guest | Implemented for WeddingPlan guest management with name, optional phone, side, invitation status, seats count, optional notes, and timestamps. |
| GuestGroup | Implemented for grouping WeddingPlan guests. |
| QuoteRequest | Implemented for non-binding pricing/package requests tied to a user, provider, service/category/city, and optionally a WeddingPlan. |
| QuoteOffer | Implemented for provider responses to quote requests. Accepting/rejecting an offer is a planning decision only, not a paid booking. |
| PlanProviderLink | Implemented to connect an accepted provider/offer to a WeddingPlan as planning context. |
| Attachment | Represents an optional supporting file or image for costs, payment records, payment schedules, quote requests, or provider agreements. This is planning-level only and does not imply payment processing. |

## Conversation And Session Entities

| Entity | Purpose |
| --- | --- |
| RefreshToken | Hashed, expiring, revocable refresh session with transactional rotation, replacement tracking, and persisted `APPLICATION`/`ADMIN` scope. |
| AdminLoginChallenge | Hashed, short-lived, one-time password-bound MFA challenge for browser admin login, bound by `otpId` to the exact private `ADMIN_LOGIN` OTP. It never stores the raw challenge or OTP. |
| AdminPasswordResetChallenge | Hashed, short-lived, one-time administrator password-recovery challenge bound to one exact OTP. It stores a token hash and HMAC phone digest, not the raw token or phone, and is invalidated on retry, expiry, failure ceiling, or success. |
| LoginThrottle | Durable cross-replica password-attempt window keyed only by an HMAC-SHA-256 account-and-realm digest using a deployment-only pepper. Application and administrator realms are isolated. Five failures lock one realm for fifteen minutes; successful authentication/reset clears it, and one hourly advisory-lock cleanup removes expired/inactive rows. |
| OtpDispatchQuota | Atomic cross-replica OTP delivery windows for phone, IP, and global scopes. Subjects are HMAC-SHA-256 digests; no raw phone or IP is persisted. Failed deliveries still consume quota and an hourly advisory-lock cleanup removes expired rows. |
| MediaUploadTicket | Durable owner, purpose, declared/verified byte size, expiry, verification state, and consumption state for every signed upload. It enforces a rolling per-account quota and allows bounded cleanup of abandoned objects without trusting a client-supplied URL. |
| Conversation | One quote-scoped thread joining the requester, provider, quote request, and WeddingPlan context, with a composite inbox-order index for cursor pagination. |
| ConversationParticipant | Per-user unread/read, mute, block, and participation state. |
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
- Marketplace entities support planning and quote/lead context; they must not replace the financial planning core.
- No payment processing, deposit, confirmed booking, loan, credit, or financing
  data should be added until explicitly approved in a later phase.
- Production migrations and Docker/Dokploy deployment work remain separate from docs-only tasks unless explicitly requested.
- New database migrations are outside docs-only tasks.

## Implemented Provider Reference Foundation

The backend now includes the approved provider-reference and quote-lead foundation:

- `OtpCode` for local, Meta WhatsApp, or temporary hardened OpenWA OTP
  request/verify flows, storing only
  hashed codes. A partial unique index permits one unconsumed code per
  phone/purpose, and consumption uses a compare-and-set update so concurrent
  replays cannot both succeed.
- `LoginThrottle` replaces process-local password counters with a PostgreSQL
  serializable failure window shared by all replicas. Its key is an
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
  new admin access JWTs are bound to the live refresh-session row so rotation
  and logout invalidate access immediately.
- `AdminPasswordResetChallenge` separates administrator recovery from general
  application password reset. An administrator may use one phone identity in
  both products, but the app password and browser-admin password remain
  independent and neither recovery route can overwrite the other.
- Refresh rows persist their application/administrator scope; logout, reset,
  rotation, and token-family compromise revocation stay inside that scope.
- Expired OTP and authentication challenge rows are retained for one day and
  then removed by a distinct advisory-lock cleanup job.
- User profile additions: `phoneVerifiedAt`, `lastLoginAt`, `avatarUrl`, and `locale`.
- `NotificationPreference` for safe default account settings.
- `Notification` for persisted task, payment-schedule, sharing, and quote alerts with deduplication.
- `IdempotencyKey` for client-generated request idempotency on mutating
  endpoints (offline-queue replays return the original response instead of
  duplicating financial records). Each key is bound to a SHA-256 fingerprint of
  method + concrete target + canonical body, while only the safe route template
  is stored in readable form. `expiresAt` bounds both pending reservations and
  completed replay responses; an hourly, advisory-lock-protected job removes
  expired rows across replicas. Migration
  `20260710173000_bind_idempotency_requests` expires legacy unbound rows. Stored
  paths use route templates only;
  migration `20260710140000_redact_legacy_idempotency_paths` removes legacy
  invite bearer values and query strings.
- `Guest` and `GuestGroup` for saved WeddingPlan guest lists and grouping.
- `City` and `ProviderCategory` for Yemen-first marketplace filters. Fresh
  databases receive an additive baseline catalog from migration
  `20260714100000_seed_provider_reference_catalog`; existing admin-managed rows
  are preserved without forced rename, reactivation, or deletion.
- `Provider`, `ProviderService`, `ProviderServiceImage`, and `ProviderPackage` for public planning references.
- `FavoriteProvider`, `ProviderReview`, `QuoteRequest`, `QuoteOffer`, `PlanProviderLink`, and `BookingLead` for saved providers, reviews, quote leads, accepted planning provider links, and non-paid lead context.
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
| `User` | 44 | `id`, `phoneVerifiedAt`, `lastLoginAt`, `activeWeddingPlanId`, `onboardingCompletedAt`, `createdAt`, `updatedAt` |
| `MediaUploadTicket` | 16 | `userId`, `expiresAt`, `verifiedAt`, `consumedAt`, `consumedById`, `deletedAt`, `createdAt`, `updatedAt` |
| `AdminLoginChallenge` | 9 | `id`, `userId`, `otpId`, `expiresAt`, `consumedAt`, `createdAt` |
| `AdminPasswordResetChallenge` | 12 | `id`, `userId`, `otpId`, `expiresAt`, `consumedAt`, `createdAt` |
| `AdminAuditLog` | 13 | `id`, `eventId`, `actorUserId`, `targetId`, `requestId`, `createdAt` |
| `RefreshToken` | 11 | `id`, `userId`, `expiresAt`, `revokedAt`, `replacedById`, `createdAt` |
| `LoginThrottle` | 5 | `windowStartedAt`, `updatedAt` |
| `OtpDispatchQuota` | 5 | `windowStartedAt`, `updatedAt` |
| `WeddingPlan` | 29 | `id`, `ownerUserId`, `onboardingCompletedAt`, `importMigrationId`, `createdAt`, `updatedAt` |
| `BudgetCategory` | 9 | `id`, `weddingPlanId`, `createdAt`, `updatedAt` |
| `WeddingCost` | 21 | `id`, `weddingPlanId`, `budgetCategoryId`, `providerId`, `quoteOfferId`, `createdAt`, `updatedAt` |
| `CostPayment` | 14 | `id`, `weddingCostId`, `paidAt`, `paymentScheduleId`, `reversalOfId`, `createdAt` |
| `PaymentSchedule` | 11 | `id`, `weddingCostId`, `paidAt`, `createdAt`, `updatedAt` |
| `WeddingTask` | 18 | `id`, `weddingPlanId`, `assigneeUserId`, `reminderAt`, `createdAt`, `updatedAt` |
| `WeddingTaskChecklistItem` | 8 | `id`, `taskId`, `createdAt`, `updatedAt` |
| `SharedMember` | 16 | `id`, `weddingPlanId`, `userId`, `createdAt`, `updatedAt` |
| `PlanInvite` | 27 | `id`, `weddingPlanId`, `inviterUserId`, `inviteeUserId`, `expiresAt`, `acceptedAt`, `declinedAt`, `revokedAt` |
| `OtpCode` | 12 | `id`, `expiresAt`, `consumedAt`, `createdAt`, `updatedAt` |
| `NotificationPreference` | 12 | `id`, `userId`, `createdAt`, `updatedAt` |
| `Notification` | 18 | `id`, `userId`, `weddingPlanId`, `entityId`, `readAt`, `archivedAt`, `createdAt`, `updatedAt` |
| `OutboxEvent` | 14 | `id`, `aggregateId`, `nextAttemptAt`, `lockedAt`, `processedAt`, `createdAt`, `updatedAt` |
| `Guest` | 18 | `id`, `weddingPlanId`, `groupId`, `createdAt`, `updatedAt` |
| `GuestGroup` | 9 | `id`, `weddingPlanId`, `createdAt`, `updatedAt` |
| `City` | 11 | `id`, `createdAt`, `updatedAt` |
| `ProviderCategory` | 11 | `id`, `createdAt`, `updatedAt` |
| `Provider` | 37 | `id`, `userId`, `cityId`, `primaryCategoryId`, `reviewedAt`, `reviewedById`, `createdAt`, `updatedAt` |
| `ProviderService` | 19 | `id`, `providerId`, `categoryId`, `cityId`, `createdAt`, `updatedAt` |
| `ProviderServiceImage` | 7 | `id`, `serviceId`, `createdAt` |
| `ProviderPackage` | 13 | `id`, `providerId`, `serviceId`, `createdAt`, `updatedAt` |
| `FavoriteProvider` | 6 | `id`, `userId`, `providerId`, `createdAt` |
| `ProviderReview` | 10 | `id`, `userId`, `providerId`, `createdAt`, `updatedAt` |
| `QuoteRequest` | 30 | `id`, `userId`, `weddingPlanId`, `providerId`, `serviceId`, `cityId`, `acceptedAt`, `rejectedAt` |
| `QuoteOffer` | 15 | `id`, `quoteRequestId`, `providerId`, `createdAt`, `updatedAt` |
| `PlanProviderLink` | 12 | `id`, `weddingPlanId`, `providerId`, `quoteRequestId`, `quoteOfferId`, `createdAt`, `updatedAt` |
| `BookingLead` | 15 | `id`, `userId`, `weddingPlanId`, `providerId`, `quoteRequestId`, `createdAt`, `updatedAt` |
| `Conversation` | 10 | `id`, `quoteRequestId`, `lastMessageAt`, `closedAt`, `createdAt`, `updatedAt` |
| `ConversationParticipant` | 11 | `id`, `conversationId`, `userId`, `lastReadAt`, `mutedAt`, `blockedAt`, `createdAt`, `updatedAt` |
| `ChatMessage` | 11 | `id`, `conversationId`, `senderUserId`, `editedAt`, `deletedAt`, `createdAt`, `updatedAt` |
| `ChatAttachment` | 7 | `id`, `messageId`, `createdAt` |
| `ConversationReport` | 9 | `id`, `conversationId`, `reporterUserId`, `createdAt`, `updatedAt` |

Total models: 41
<!-- DOCS-SYNC:END -->
