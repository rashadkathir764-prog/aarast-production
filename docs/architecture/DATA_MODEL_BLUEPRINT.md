# Aarast Data Model Blueprint

Date: 2026-06-19
Stage: Data Model Blueprint
Source inspected: `backend/prisma/schema.prisma`
Status: Planning document only

## 1. Scope

This document describes the current Prisma-backed data model and the data gaps required for the mobile product/UX rebuild.

No Prisma schema, migration, backend API, or application code is changed by this document.

## 2. Current Prisma Enums

| Enum | Current values | Notes |
|---|---|---|
| `UserRole` | `USER`, `ADMIN`, `PROVIDER` | Basic account role. Does not yet model wedding persona. |
| `UserStatus` | `ACTIVE`, `DISABLED` | Basic account lifecycle. |
| `WeddingPlanStatus` | `PLANNING`, `ARCHIVED` | No draft/local/import state on server. |
| `ExpenseStatus` | `PLANNED`, `PAID`, `CANCELLED` | Covers basic expense lifecycle. |
| `DebtStatus` | `OPEN`, `PARTIALLY_PAID`, `PAID`, `CANCELLED` | Covers core debt state. |
| `InstallmentStatus` | `PENDING`, `PAID`, `OVERDUE`, `CANCELLED` | Supports due/installment tracking. |
| `WeddingTaskStatus` | `TODO`, `IN_PROGRESS`, `DONE`, `CANCELLED` | Supports task status. |
| `WeddingTaskPriority` | `LOW`, `MEDIUM`, `HIGH` | Supports task priority. |
| `SharedMemberRole` | `VIEWER`, `CONTRIBUTOR`, `MANAGER` | Needs permission presets and possibly domain-specific role labels. |
| `OtpPurpose` | `REGISTER`, `LOGIN`, `VERIFY_PHONE`, `RESET_PASSWORD` | Supports OTP/profile flows. |
| `ProviderStatus` | `PENDING`, `ACTIVE`, `NEEDS_CHANGES`, `SUSPENDED`, `REJECTED` | Maps partly to provider review lifecycle; "verified" is not explicit. |
| `ReviewStatus` | `PUBLISHED`, `HIDDEN`, `PENDING` | Supports provider reviews. |
| `QuoteRequestStatus` | `SENT`, `VIEWED`, `RESPONDED`, `ACCEPTED`, `REJECTED`, `CANCELLED` | Request lifecycle exists, but no separate QuoteOffer model. |
| `BookingLeadStatus` | `NEW`, `IN_PROGRESS`, `CONFIRMED`, `CANCELLED`, `COMPLETED` | Risk: `CONFIRMED` can imply booking; product must keep this as lead-only unless later approved. |
| `NotificationType` | `TASK_DUE_SOON`, `TASK_OVERDUE`, `INSTALLMENT_DUE_SOON`, `INSTALLMENT_OVERDUE`, `SHARING_INVITATION`, `SHARING_UPDATED`, `GENERAL` | Needs provider quote, budget, guest, sync, and permission-specific types. |
| `GuestSide` | `GROOM`, `BRIDE`, `FAMILY`, `FRIEND`, `OTHER` | Useful guest grouping base. |
| `GuestStatus` | `INVITED`, `CONFIRMED`, `DECLINED`, `PENDING` | Useful invitation/attendance base. |

## 3. Current Prisma Models

### 3.1 Identity And Account

| Model | Purpose | Important fields/relations |
|---|---|---|
| `User` | Authenticated account for wedding users, admins, and providers. | `name`, `phone`, `email`, `passwordHash`, `role`, `status`, `locale`, relations to wedding plans, shared plans, notifications, provider profile, favorites, reviews, quote requests, booking leads. |
| `OtpCode` | OTP request/verify flow. | `phone`, `codeHash`, `purpose`, `expiresAt`, `consumedAt`, `attempts`, indexes by phone/purpose. |
| `NotificationPreference` | User notification settings. | Push/SMS/WhatsApp/email and reminder toggles. |

Current gaps:

- No `UserProfile` or persona fields.
- No groom/bride/helper tone fields.
- No guest session or guest migration record.
- Provider role exists as `UserRole.PROVIDER`, but provider flow should be path/status-based, not just role-based.

### 3.2 Wedding Financial OS

| Model | Purpose | Important fields/relations |
|---|---|---|
| `WeddingPlan` | Central wedding planning record. | `ownerUserId`, `title`, `city`, `weddingDate`, `estimatedBudget`, `currency`, `status`, relations to categories, expenses, debts, tasks, sharing, quotes, leads, notifications, guests. |
| `BudgetCategory` | Budget grouping under a plan. | `weddingPlanId`, `name`, `targetAmount`, expenses relation. |
| `Expense` | Spending record under a plan. | `weddingPlanId`, optional `budgetCategoryId`, `title`, `amount`, `status`, `expenseDate`, `note`. |
| `Debt` | Obligation owed to person/provider. | `weddingPlanId`, `creditorName`, `creditorPhone`, `title`, `totalAmount`, `paidAmount`, `dueDate`, `status`, `note`, installments. |
| `Installment` | Scheduled debt payment. | `debtId`, `amount`, `dueDate`, `paidAt`, `status`, `note`. |
| `WeddingTask` | Task/timeline item. | `weddingPlanId`, `title`, `description`, `dueDate`, `taskCategory`, `reminderAt`, `status`, `priority`. |
| `SharedMember` | Plan collaboration and permission record. | `weddingPlanId`, `userId`, `role`, `canViewBudget`, `canViewExpenses`, `canViewDebts`, `canManageTasks`, `canManageFinancialRecords`. |
| `Guest` | Guest list item. | `weddingPlanId`, `name`, normalized name/phone, `side`, `status`, `seatsCount`, `notes`, uniqueness by plan/name/phone. |

Current gaps:

- `WeddingPlan.city` is a string, not a structured location relation.
- No governorate/district/neighborhood/street/address note fields.
- No persona/current onboarding state on `WeddingPlan`.
- No priority selections.
- No persisted plan summary table/view.
- No accepted provider link such as `PlanProvider`.
- Expenses/debts cannot yet link to provider, service, quote, package, or plan provider.
- Tasks do not have assignee/member relation.
- Guests do not yet have import/source metadata.
- Shared permissions do not yet include guest/provider/location/admin-style domain permissions.

### 3.3 Notifications

| Model | Purpose | Important fields/relations |
|---|---|---|
| `Notification` | Persisted alert for authenticated user. | `userId`, optional `weddingPlanId`, `type`, `title`, `body`, JSON `data`, `dedupeKey`, `readAt`, indexes by user/read/created and plan/created. |
| `NotificationPreference` | Delivery preferences. | Reminder and channel toggles. |

Current gaps:

- Missing notification types for quote received/status, budget exceeded, member joined, permission changed, guest confirmed, sync failed.
- No explicit `sourceType`, `sourceId`, or `deepLink` columns; these may be stored in JSON `data` today.
- No device token model for push.
- No guest/local notification model.

### 3.4 Location And Marketplace

| Model | Purpose | Important fields/relations |
|---|---|---|
| `City` | Yemen city seed/reference. | `nameAr`, `nameEn`, `countryCode`, `isActive`, `sortOrder`, providers/services/quote requests. |
| `ProviderCategory` | Provider/service category. | `nameAr`, `nameEn`, `slug`, `icon`, `isActive`, `sortOrder`, providers/services. |
| `Provider` | Provider business profile. | `userId`, `cityId`, `primaryCategoryId`, `businessName`, `ownerName`, phone/contact fields, description, address, lat/long, images, `status`, review metadata, featured/rating fields. |
| `ProviderService` | Service offered by provider. | `providerId`, `categoryId`, `title`, `description`, `basePrice`, `priceUnit`, `currency`, optional `cityId`, active/featured flags. |
| `ProviderServiceImage` | Service images. | `serviceId`, `imageUrl`, `altText`, `sortOrder`. |
| `ProviderPackage` | Provider package/bundle. | `providerId`, optional `serviceId`, `title`, `description`, `price`, `currency`, JSON `items`, active flag. |
| `FavoriteProvider` | User saved provider. | Unique user/provider pair. |
| `ProviderReview` | User review of provider. | Unique user/provider pair, rating/comment/status. |
| `QuoteRequest` | User request to provider. | `userId`, optional `weddingPlanId`, `providerId`, optional service/city, event date, guest count, message, budget min/max, status. |
| `BookingLead` | Non-payment provider lead record. | User/plan/provider/quote relation, title, event date, status, notes. |

Current gaps:

- No provider service areas beyond one `cityId`/address/lat/long.
- No governorate/district/neighborhood model.
- No many-to-many provider coverage areas.
- No `QuoteOffer` model for actual provider offer details.
- No `PlanProvider` model for accepted provider inside a wedding plan.
- `BookingLeadStatus.CONFIRMED` is dangerous wording for the current MVP and must remain lead-only or be renamed in a later migration.
- No admin dispute/support models.

## 4. Missing Or New Data Concepts

Required for the rebuild before implementation:

| Concept | Suggested shape | Why needed |
|---|---|---|
| `UserProfile` or profile fields | `userId`, `persona`, `genderTone`, `preferredCopyStyle`, default location | Persona copy, groom/bride/helper flow, onboarding continuity. |
| `WeddingPlanLocation` or structured plan location fields | `weddingPlanId`, governorate, city/district, neighborhood, street, addressNote, optional lat/long | Provider matching and local planning context. |
| `OnboardingState` or plan setup fields | persona, priorities, selected presets, setup completion flags | Guest-first and generated dashboard. |
| `PlanProvider` | `weddingPlanId`, `providerId`, `quoteRequestId`, optional service/package, status, acceptedAt | Connect accepted quote/provider to plan. |
| `QuoteOffer` | `quoteRequestId`, `providerId`, title, amount/range, message, status, expiresAt | Separate provider offer from request status. |
| Provider service area | providerId + governorate/city/district/neighborhood | Location/provider matching beyond single city. |
| Task template seed | key, phase, due offset, category, priority, persona copy | Generate tasks from wedding date. |
| Budget preset/category seed | wedding type, category, suggested allocation | Avoid blank money setup. |
| Feature flag | key, enabled, audience/environment | Hide incomplete AI/push/maps/subscriptions/provider features. |
| Device token | userId, platform, token, enabledAt, revokedAt | Push notifications later. |
| Audit log | actorId, targetType, targetId, action, metadata | Admin/provider/security traceability. |
| Support/dispute | user/provider/quote/lead references, type, status, message | Support and disputes planning. |
| Offline sync metadata | server-side version or conflict metadata if needed | Safe sync and conflict resolution. |

## 5. Relationship Blueprint

### 5.1 Wedding Plan Center

`WeddingPlan` remains the center of the wedding-user product.

Required relationship direction:

- `User` owns many `WeddingPlan`.
- `WeddingPlan` owns budget categories, expenses, debts, installments through debts, tasks, guests, shared members, notifications, quote requests, booking leads.
- `WeddingPlan` should own or reference structured location.
- `WeddingPlan` should reference generated setup state and selected priorities.

### 5.2 Provider Flow

Required relationship direction:

- `User` may have one `Provider`.
- `Provider` has services, packages, reviews, favorites, quote requests, and booking leads.
- `QuoteRequest` connects user, optional wedding plan, provider, optional service/city, and request details.
- Future `QuoteOffer` should connect to `QuoteRequest`.
- Future `PlanProvider` should connect accepted quote/provider into `WeddingPlan`.
- Future expenses/debts may reference `PlanProvider`, provider, service, package, or quote offer.

### 5.3 Location Matching

Current:

- `WeddingPlan.city` is a string.
- `Provider.cityId` points to `City`.
- `ProviderService.cityId` can point to `City`.
- `QuoteRequest.cityId` can point to `City`.

Required:

- Normalize plan location.
- Add governorate/district/neighborhood/service area concepts.
- Match provider by service area, not only business city.
- Keep map coordinates optional and later.

## 6. Roles And Permissions Blueprint

Current backend permission foundation:

- Account roles: `USER`, `ADMIN`, `PROVIDER`.
- Plan sharing roles: `VIEWER`, `CONTRIBUTOR`, `MANAGER`.
- Explicit booleans:
  - `canViewBudget`
  - `canViewExpenses`
  - `canViewDebts`
  - `canManageTasks`
  - `canManageFinancialRecords`

Required additions or clarifications:

- Persona is not the same as account role.
- Provider path is not the same as plan member role.
- Shared permissions need UX presets, not necessarily new schema first:
  - Viewer.
  - Task helper.
  - Finance helper.
  - Full manager.
  - Guest helper later.
- Future schema may need:
  - `canViewGuests`
  - `canManageGuests`
  - `canManageProviders`
  - `canViewLocation`
  - `canManageSharing`
- Providers must see only quote request fields intentionally sent to them.
- Admin permissions must stay separate from mobile plan sharing.

## 7. Guest-First Support

Current server schema assumes authenticated user ownership:

- `WeddingPlan.ownerUserId` is required.
- Financial/task/guest/sharing records are plan-owned server data.

Guest-first options:

1. Local-only guest plan first.
   - Mobile stores plan locally.
   - Signup migrates to server.
   - Best fit for current backend without immediate server schema changes.

2. Server anonymous session.
   - Requires `GuestSession` model and temporary ownership.
   - More backend work and privacy complexity.

Recommended first implementation path:

- Use local-only guest plan for onboarding and generated dashboard.
- Gate cloud actions.
- On signup/login, create server `WeddingPlan` and related starter categories/tasks.
- Record migration failures clearly.

Schema implications:

- No immediate Prisma change required for local guest plan.
- Migration plan must define local IDs to server IDs.
- Later `GuestMigration` or import log may help debugging.

## 8. Offline And Sync Support

Current mobile has offline/local database and sync queue code. Prisma does not have a dedicated sync-conflict model.

Data model requirements:

- Every syncable local record needs stable local ID and future server ID mapping.
- Server responses should include `updatedAt`.
- Conflict resolution rules must be defined before destructive local schema changes.
- Server-side `version` columns may be considered later if conflicts become common.
- Do not remove existing offline/sqflite/json support.

Recommended first scope:

- Preserve current server schema.
- Define local sync behavior in Offline & Sync Plan.
- Avoid server conflict tables until concrete conflict cases exist.

## 9. Expected Migration Groups

No migrations are created in this stage. Expected future migration groups:

### Migration Group A - Persona And Onboarding

- Add persona/gender tone/profile fields.
- Add plan setup/onboarding metadata if server-backed.
- Add selected priorities if server-backed.

### Migration Group B - Structured Location

- Add normalized Yemen location hierarchy or structured fields.
- Add plan location relation/fields.
- Add provider service areas.

### Migration Group C - Quote To Plan

- Add `QuoteOffer`.
- Add `PlanProvider`.
- Add optional links from expenses/debts to provider/quote/plan provider.

### Migration Group D - Notifications

- Extend notification enum.
- Add source/deep-link fields or standard JSON shape.
- Add device token model if push is implemented.

### Migration Group E - Feature/Operations

- Add feature flags if controlled server-side.
- Add audit logs.
- Add support/dispute records.

## 10. Data Risks

- Adding guest-first server records too early can weaken ownership and privacy unless carefully designed.
- `BookingLeadStatus.CONFIRMED` can be misread as confirmed booking; MVP must avoid paid/confirmed booking semantics.
- Duplicated plan summary calculations can cause inconsistent dashboard, plan list, and notification values.
- Missing structured location limits provider matching quality.
- Provider quote request status alone is not enough to represent offer details.
- Expanding sharing permissions without UI explanation can expose private financial data.
- Adding migrations before migration/QA plans can break local/offline users.

## 11. Acceptance Criteria

- Current Prisma models and enums are documented.
- Missing tables/concepts are documented.
- Current relationships and required future relationships are documented.
- Required fields for guest-first, provider quote flow, notifications, permissions, offline/sync, and location matching are identified.
- Expected migration groups are listed without creating migrations.
- Risks are documented.
- No Prisma/backend/mobile code is changed.

## 12. Next Implementation Notes

- Next stage: `docs/architecture/BACKEND_FLOW_BLUEPRINT.md`.
- Backend Flow Blueprint must stay planning-level and use this data model as input.
- Do not edit `backend/prisma/schema.prisma` yet.
- Do not add migrations yet.
- Do not implement quote offers, plan providers, feature flags, or structured location until implementation plan and tests are approved.

