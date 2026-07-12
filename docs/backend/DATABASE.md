# Database Plan

This document describes the product data model at a planning/status level. It does not replace `backend/prisma/schema.prisma` as the schema source of truth.

Current documentation snapshot: 2026-07-11. Route-level behavior belongs in
`docs/backend/API_CONTRACT.md`.

## Current And Marketplace Entities

| Entity | Purpose |
| --- | --- |
| User | Represents a person using Aarast, such as groom, bride, family member, provider, or admin. `phone` is important for Yemen-first usage. `passwordHash` must store hashed passwords only, never plaintext passwords. Current roles include `USER`, `ADMIN`, and `PROVIDER`; provider flows are implemented as planning/reference and quote-lead flows, not paid marketplace or confirmed booking flows. |
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
| BudgetCategory | Implemented for owner-scoped WeddingPlan budget groups, with optional target amounts and links to expenses, financial commitments, payment records, and financial installments. |
| FinancialCommitment | Implemented as the phase-2 money backbone for agreed costs. Every commitment belongs to a WeddingPlan and BudgetCategory and may link to a provider, accepted quote, or plan-provider link. Remaining amount is derived from total amount minus paid amount. |
| FinancialPaymentRecord | Implemented as an append-only planning ledger under a FinancialCommitment. `PAYMENT` and `REVERSAL` are separate immutable rows; the original payment is retained. A one-to-one `financialInstallmentId` and unique `reversalOfId` prevent duplicate installment payments and duplicate reversals. This is manual planning data, not payment processing. |
| FinancialInstallment | Implemented for scheduled commitment payments. A financial installment belongs to a FinancialCommitment and BudgetCategory; paying it locks the installment row, creates one uniquely linked payment record, and updates the commitment balance. Reversing that payment reopens the installment without deleting history. |
| Expense | Implemented for owner-scoped WeddingPlan actual money-out records with amount, paid status, optional date, optional note, and required BudgetCategory link for new records. New money flows should use FinancialCommitment + FinancialPaymentRecord for agreed costs, remaining balances, and payments. |
| Task | Implemented as `WeddingTask` for WeddingPlan planning work, including title, optional description/due date, status, priority, checklist support, and two exclusive responsibility modes: a registered participant through `assigneeUserId`, or a manual/contact responsible through optional `responsibleName`, `responsiblePhone`, and `responsibleSource`. A database CHECK prevents both modes from being stored together. |
| WeddingTaskChecklistItem | Implemented for task checklist rows tied to a WeddingTask. |
| SharedMember | Implemented for permission-based WeddingPlan collaboration. A shared member links a User to a WeddingPlan with explicit permissions for budget, expenses, financial records, tasks, guests, providers, and member management. |
| PlanInvite | Implemented for identity-bound sharing and atomic acceptance. Only a SHA-256 token fingerprint is persisted; raw external invite tokens are returned at creation time only. |
| Guest | Implemented for WeddingPlan guest management with name, optional phone, side, invitation status, seats count, optional notes, and timestamps. |
| GuestGroup | Implemented for grouping WeddingPlan guests. |
| QuoteRequest | Implemented for non-binding pricing/package requests tied to a user, provider, service/category/city, and optionally a WeddingPlan. |
| QuoteOffer | Implemented for provider responses to quote requests. Accepting/rejecting an offer is a planning decision only, not a paid booking. |
| PlanProviderLink | Implemented to connect an accepted provider/offer to a WeddingPlan as planning context. |
| Attachment | Represents an optional supporting file or image for expenses, commitments, installments, quote requests, or provider agreements. This is planning-level only and does not require implementation in the Docs Foundation phase. |

## Conversation And Session Entities

| Entity | Purpose |
| --- | --- |
| RefreshToken | Hashed, expiring, revocable refresh session with transactional rotation and replacement tracking. |
| AdminLoginChallenge | Hashed, short-lived, one-time password-bound MFA challenge for browser admin login. It never stores the raw challenge or OTP. |
| LoginThrottle | Durable cross-replica password-attempt window keyed only by an HMAC-SHA-256 account-identifier digest using a deployment-only pepper. Five failures lock the identifier for fifteen minutes; successful authentication/reset clears it, and one hourly advisory-lock cleanup removes expired/inactive rows. |
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
- WeddingPlan now has implemented BudgetCategory, FinancialCommitment,
  FinancialPaymentRecord, FinancialInstallment, Expense, WeddingTask, and
  SharedMember relations.
- Every WeddingPlan must have clear ownership.
- WeddingPlan ownership must not rely on a mock-auth shortcut; ownership must come from authenticated user context.
- Owner-scoped records should use an explicit `ownerUserId` pattern and must be checked against the authenticated user before private access.
- Shared access must be permission-based, not full access by default.
- Financial data such as financial commitments, payment records, expenses,
  commitments, payment records, and installments must be private by default.
- A standalone paid `Expense` contributes once to confirmed financial exposure.
  An active `FinancialCommitment` contributes its full agreed total once;
  payment records only change its paid/outstanding split and never add the
  commitment cost a second time.
- SharedMember permissions are implemented as a backend slice; financial
  endpoints remain protected and must not expose financial commitments, payment
  records, expenses, commitments, or installments to shared members unless permissions
  explicitly allow it in an approved endpoint flow.
- Marketplace entities support planning and quote/lead context; they must not replace the financial planning core.
- No payment processing, deposit, confirmed booking, loan, credit, or financing
  data should be added until explicitly approved in a later phase.
- Production migrations and Docker/Dokploy deployment work remain separate from docs-only tasks unless explicitly requested.
- New database migrations are outside docs-only tasks.

## Implemented Provider Reference Foundation

The backend now includes the approved provider-reference and quote-lead foundation:

- `OtpCode` for local or Meta WhatsApp OTP request/verify flows, storing only
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
- Existing accounts with null `phoneVerifiedAt` keep their data but all active
  refresh sessions are revoked; they must prove phone ownership before a new
  session can be issued.
- `AdminLoginChallenge` binds a successful admin password check to one LOGIN
  OTP for at most ten minutes. Deployment revokes legacy admin refresh rows;
  new admin access JWTs are bound to the live refresh-session row so rotation
  and logout invalidate access immediately.
- User profile additions: `phoneVerifiedAt`, `lastLoginAt`, `avatarUrl`, and `locale`.
- `NotificationPreference` for safe default account settings.
- `Notification` for persisted task, installment, sharing, and quote alerts with deduplication.
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
- `City` and `ProviderCategory` for Yemen-first marketplace filters.
- `Provider`, `ProviderService`, `ProviderServiceImage`, and `ProviderPackage` for public planning references.
- `FavoriteProvider`, `ProviderReview`, `QuoteRequest`, `QuoteOffer`, `PlanProviderLink`, and `BookingLead` for saved providers, reviews, quote leads, accepted planning provider links, and non-paid lead context.
- `FinancialCommitment`, `FinancialPaymentRecord`, and
  `FinancialInstallment` for category-first agreed costs, actual money-out
  records, and scheduled commitment payments.
- `WeddingTaskChecklistItem` plus task assignment support.
- `PlanInvite` for invite-based collaboration.

These models do not add payment processing, deposits, confirmed reservations, loans, credit, or financing behavior.

<!-- DOCS-SYNC:START -->
<!-- AUTO-GENERATED by scripts/docs-sync.mjs. Do not edit by hand. -->

| Model | Field count | Notable fields |
| --- | --- | --- |
| `IdempotencyKey` | 10 | `id`, `userId`, `completedAt`, `expiresAt`, `createdAt` |
| `User` | 39 | `id`, `phoneVerifiedAt`, `lastLoginAt`, `activeWeddingPlanId`, `onboardingCompletedAt`, `createdAt`, `updatedAt` |
| `MediaUploadTicket` | 16 | `userId`, `expiresAt`, `verifiedAt`, `consumedAt`, `consumedById`, `deletedAt`, `createdAt`, `updatedAt` |
| `AdminLoginChallenge` | 7 | `id`, `userId`, `expiresAt`, `consumedAt`, `createdAt` |
| `AdminAuditLog` | 13 | `id`, `eventId`, `actorUserId`, `targetId`, `requestId`, `createdAt` |
| `RefreshToken` | 10 | `id`, `userId`, `expiresAt`, `revokedAt`, `replacedById`, `createdAt` |
| `LoginThrottle` | 5 | `windowStartedAt`, `updatedAt` |
| `WeddingPlan` | 32 | `id`, `ownerUserId`, `onboardingCompletedAt`, `importMigrationId`, `createdAt`, `updatedAt` |
| `BudgetCategory` | 11 | `id`, `weddingPlanId`, `createdAt`, `updatedAt` |
| `Expense` | 12 | `id`, `weddingPlanId`, `budgetCategoryId`, `createdAt`, `updatedAt` |
| `FinancialCommitment` | 27 | `id`, `weddingPlanId`, `budgetCategoryId`, `providerId`, `planProviderLinkId`, `quoteRequestId`, `quoteOfferId`, `createdAt` |
| `FinancialPaymentRecord` | 20 | `id`, `weddingPlanId`, `financialCommitmentId`, `budgetCategoryId`, `paidAt`, `financialInstallmentId`, `reversalOfId`, `createdAt` |
| `FinancialInstallment` | 15 | `id`, `weddingPlanId`, `financialCommitmentId`, `budgetCategoryId`, `paidAt`, `createdAt`, `updatedAt` |
| `WeddingTask` | 18 | `id`, `weddingPlanId`, `assigneeUserId`, `reminderAt`, `createdAt`, `updatedAt` |
| `WeddingTaskChecklistItem` | 8 | `id`, `taskId`, `createdAt`, `updatedAt` |
| `SharedMember` | 18 | `id`, `weddingPlanId`, `userId`, `createdAt`, `updatedAt` |
| `PlanInvite` | 29 | `id`, `weddingPlanId`, `inviterUserId`, `inviteeUserId`, `expiresAt`, `acceptedAt`, `declinedAt`, `revokedAt` |
| `OtpCode` | 10 | `id`, `expiresAt`, `consumedAt`, `createdAt`, `updatedAt` |
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
| `QuoteRequest` | 31 | `id`, `userId`, `weddingPlanId`, `providerId`, `serviceId`, `cityId`, `acceptedAt`, `rejectedAt` |
| `QuoteOffer` | 15 | `id`, `quoteRequestId`, `providerId`, `createdAt`, `updatedAt` |
| `PlanProviderLink` | 13 | `id`, `weddingPlanId`, `providerId`, `quoteRequestId`, `quoteOfferId`, `createdAt`, `updatedAt` |
| `BookingLead` | 15 | `id`, `userId`, `weddingPlanId`, `providerId`, `quoteRequestId`, `createdAt`, `updatedAt` |
| `Conversation` | 10 | `id`, `quoteRequestId`, `lastMessageAt`, `closedAt`, `createdAt`, `updatedAt` |
| `ConversationParticipant` | 11 | `id`, `conversationId`, `userId`, `lastReadAt`, `mutedAt`, `blockedAt`, `createdAt`, `updatedAt` |
| `ChatMessage` | 11 | `id`, `conversationId`, `senderUserId`, `editedAt`, `deletedAt`, `createdAt`, `updatedAt` |
| `ChatAttachment` | 7 | `id`, `messageId`, `createdAt` |
| `ConversationReport` | 9 | `id`, `conversationId`, `reporterUserId`, `createdAt`, `updatedAt` |

Total models: 40
<!-- DOCS-SYNC:END -->
