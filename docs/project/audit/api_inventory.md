# Backend API inventory (اعّرست)

Generated 2026-10-19 by static reading of `backend/` (no code changed). Paths in tables are relative to `backend/src/` unless prefixed.

## 0. Conventions

- **No global prefix.** `main.ts` does not call `setGlobalPrefix`; every controller writes its own path. App routes use `api/v1/...`; back-office uses `admin/...` (no `/api/v1`); ops routes are `/health`, `/live`, `/ready`, `/metrics`.
- Global: `ThrottlerGuard` (APP_GUARD, default 1000 req/60 s, env `THROTTLE_LIMIT`/`THROTTLE_TTL_MS`, Redis-backed when `REDIS_URL`), `IdempotencyInterceptor` (header `X-Client-Request-Id`, authenticated mutating methods only; presign + invite create/reissue excluded), `AdminAuditInterceptor` (routes starting `/admin` with an `adminRole` actor → `AdminAuditLog` ATTEMPT/SUCCEEDED/FAILED), `ValidationPipe{whitelist, forbidNonWhitelisted, transform}`, `GlobalExceptionFilter`, helmet, CORS.
- Auth legend:
  - **PUB** — no guard (throttle only).
  - **JWT** — `JwtAuthGuard` (`modules/identity/public/jwt-auth.guard.ts`): valid access token whose `sessionScope === 'application'`.
  - **ADM:X** — `JwtSessionGuard + AdminGuard + AdminPermissionGuard` + `@RequireAdminPermission(X)`. AdminGuard requires `role=ADMIN`, `adminMfa=true`, `sessionScope='admin'` (`modules/backoffice/public/admin.guard.ts:12`).
  - Plan-level checks happen **inside services** via `CollaborationPermissionPort` (`modules/collaboration/public/collaboration-permission.port.ts`). Notation: **R** = owner or any member (`assertPlanReadable`); **TASKS / GUESTS / MONEY_R / MONEY_W / PROV / MEMBERS / PLAN_W** = owner or member flag `canManageTasks / canManageGuests / canViewMoney / canManageMoney / canManageProviders / canInviteMembers / canEditPlan`; **OWNER** = plan owner only; **WP** = item-level contributor scoping applies (non-owner, non-partner sees/mutates only own contributions, see §4); **ARCH** = archived plan → 409 `PLAN_ARCHIVED_READ_ONLY` on writes.
  - **PROVIDER** = caller owns a `Provider` row (`Provider.userId = me`); **PROVIDER+ACTIVE** = additionally `status=ACTIVE` (`assertProviderOperational`, 403 `PROVIDER_NOT_ACTIVE`; `modules/marketplace/public/provider-access-policy.ts:49`).
- Throttle overrides shown as `T n/min`.
- Not found anywhere in backend: wedding sub-**events** model/endpoints (no `Event` model; only `timeline`), generic **sync/offline** endpoints (only `POST onboarding/import-local`), file **download** route other than chat attachment (receipts are referenced via `attachmentRef`), city CRUD outside admin.

Totals: **273 HTTP routes** across 32 controller files (67 controller classes), **1 Socket.IO gateway**, **59 Prisma models**, **47 enums**.

---

## 1. HTTP endpoints

### 1.1 Auth / identity (29)

| Method | Path | Ctrl file:line | Auth | Purpose | Key request | Key response |
|---|---|---|---|---|---|---|
| POST | /api/v1/auth/register | modules/identity/api/auth.controller.ts:44 | PUB T10 | Start registration, sends OTP | name, phone | OtpRequestResponse (phone, purpose, expiresAt, delivery, deliveryStatus, code? in dev) |
| POST | /api/v1/auth/register/complete | auth.controller.ts:50 | PUB T20 | Finish registration | name, phone, password, otpCode | AuthResponse (user, accessToken, refreshToken, refreshTokenExpiresAt) |
| POST | /api/v1/auth/login | auth.controller.ts:56 | PUB T20 | Phone+password login | phone, password | AuthResponse |
| POST | /api/v1/auth/admin/login | auth.controller.ts:63 | PUB T10 | Admin login step 1 (trusted-device cookie may skip MFA) | phone, password; cookie admin trusted device | {mfaRequired:true, challengeToken, expiresAt, delivery} or {mfaRequired:false, user, accessToken, accessTokenExpiresIn} + `aarast_admin_refresh` httpOnly cookie |
| POST | /api/v1/auth/admin/login/complete | auth.controller.ts:92 | PUB T10 | Admin MFA OTP | challengeToken, code | user, accessToken, accessTokenExpiresIn; sets refresh + trusted-device cookies (path `/api/v1/auth/admin`) |
| POST | /api/v1/auth/admin/password-reset/request | auth.controller.ts:124 | PUB T10 | Admin reset start | phone | accepted, challengeToken, expiresAt, retryAfterSeconds, deliveryStatus |
| POST | /api/v1/auth/admin/password-reset/verify | auth.controller.ts:134 | PUB T10 | Verify reset OTP | challengeToken, code | verification result |
| POST | /api/v1/auth/admin/password-reset/confirm | auth.controller.ts:141 | PUB T10 | Set new admin password | challengeToken, newPassword | result |
| POST | /api/v1/auth/admin/refresh | auth.controller.ts:148 | PUB(cookie) T30 | Rotate admin refresh cookie | cookie `aarast_admin_refresh` | user, accessToken |
| POST | /api/v1/auth/admin/logout | auth.controller.ts:172 | PUB(cookie) | Revoke admin refresh, clear cookie | cookie | {revoked} |
| POST | /api/v1/auth/refresh | auth.controller.ts:191 | PUB T30 | Rotate app refresh token | refreshToken | AuthResponse |
| POST | /api/v1/auth/logout | auth.controller.ts:198 | JWT | Revoke one refresh token | refreshToken? | result |
| POST | /api/v1/auth/logout-all | auth.controller.ts:205 | JWT | Revoke all sessions | – | result |
| POST | /api/v1/auth/phone-change/request | auth.controller.ts:213 | JWT T5 | OTP to new phone | phone | OtpRequestResponse |
| POST | /api/v1/auth/phone-change/confirm | auth.controller.ts:225 | JWT T10 | Move account to new phone | phone, code | user |
| POST | /api/v1/auth/otp/request | auth.controller.ts:236 | PUB T20 | Generic OTP | phone, purpose (OtpPurpose) | OtpRequestResponse |
| POST | /api/v1/auth/otp/verify | auth.controller.ts:243 | PUB T30 | Verify OTP (LOGIN purpose may issue tokens) | phone, code, purpose | verified, phone, purpose, user?, accessToken?, refreshToken? |
| POST | /api/v1/auth/password-reset/request | auth.controller.ts:250 | PUB T10 | App reset OTP | phone | OtpRequestResponse |
| POST | /api/v1/auth/password-reset/confirm | auth.controller.ts:260 | PUB T10 | App reset | phone, code, newPassword | result |
| GET | /api/v1/auth/me | auth.controller.ts:267 | JWT | Current safe user (dup of /me) | – | SafeUser |
| GET | /api/v1/me | modules/identity/api/me.controller.ts:10 | JWT | Current safe user | – | SafeUser |
| PATCH | /api/v1/users/me | modules/identity/api/users.controller.ts:27 | JWT | Update profile | name, email, avatarUrl, locale, persona | user |
| DELETE | /api/v1/users/me | users.controller.ts:35 | JWT; header `X-Client-Request-Id` required | Delete account | header | deletion receipt |
| GET | /api/v1/users/lookup | users.controller.ts:50 | JWT T15 + MEMBERS on weddingPlanId | Find user by phone to share plan | q: weddingPlanId, phone | UserLookupResponse (id, name, phone) |
| GET | /api/v1/users/me/settings | users.controller.ts:63 | JWT | Notification prefs | – | NotificationPreferenceResponse (+channelCapabilities) |
| PATCH | /api/v1/users/me/settings | users.controller.ts:68 | JWT | Update prefs | pushEnabled, smsEnabled, whatsappEnabled, emailEnabled, taskRemindersEnabled, paymentRemindersEnabled, providerMessagesEnabled | NotificationPreferenceResponse |
| POST | /api/v1/account-deletions/status | modules/identity/api/account-deletion-status.controller.ts:10 | **PUB** T10 | Check whether a deletion completed (via receipt hash) | userId, clientRequestId | status |
| GET | /api/v1/contexts | modules/identity/api/contexts.controller.ts:13 | JWT | List switchable contexts (plans per role + provider) | – | AvailableContext[]: contextKey (`plan:{id}:{role}` / `provider:{id}`), role, weddingPlanId, providerId, membershipId, membershipAuthorityVersion, persona, displayName, lifecycle, accessMode, capabilities, permissions{canViewPlan, canEditPlan, canManageTasks, canManageGuests, canManageProviders, canInviteMembers, canViewMoney, canManageMoney, canManageProviderProfile}, isAvailable, unavailableReason |
| POST | /api/v1/contexts/validate | contexts.controller.ts:18 | JWT | Validate a contextKey | contextKey | AvailableContext |

### 1.2 Wedding plans, onboarding, dashboard, assistant, timeline (15)

| Method | Path | Ctrl file:line | Auth / plan perm | Purpose | Key request | Key response |
|---|---|---|---|---|---|---|
| POST | /api/v1/wedding-plans | wedding-plans/wedding-plans.controller.ts:22 | JWT (active user) | Create plan | title, city, location, weddingDate, priorities[], estimatedBudget, currency, onboardingPath, persona, selectedCategories[] | WeddingPlanResponse |
| GET | /api/v1/wedding-plans | :30 | JWT | Owned + shared plans | – | WeddingPlanResponse[] |
| GET | /api/v1/wedding-plans/my | :35 | JWT | Owned plans | – | WeddingPlanResponse[] |
| GET | /api/v1/wedding-plans/active | :40 | JWT | User's active plan | – | WeddingPlanResponse \| null |
| POST | /api/v1/wedding-plans/:id/set-active | :45 | JWT R, ARCH | Set `User.activeWeddingPlanId` | – | plan |
| GET | /api/v1/wedding-plans/:id | :53 | JWT R | Plan detail (estimatedBudget hidden w/o MONEY_R) | – | WeddingPlanResponse (id, ownerUserId, title, city, location, weddingDate, priorities, estimatedBudget, currency, onboardingPath, persona, status…) |
| PATCH | /api/v1/wedding-plans/:id | :61 | JWT PLAN_W, ARCH | Update plan | title, city, location, weddingDate, priorities, onboardingPath, persona | WeddingPlanResponse |
| PATCH | /api/v1/wedding-plans/:id/archive | :70 | JWT PLAN_W | Archive plan; revokes live invites | – | WeddingPlanResponse |
| POST | /api/v1/onboarding/complete | onboarding/onboarding.controller.ts:14 | JWT | Finish onboarding, create plan + categories | path, persona, title, city, location, weddingDate, priorities, estimatedBudget, currency, selectedCategories | OnboardingCompletionResponse (user, activeWeddingPlan, budgetCategories) |
| POST | /api/v1/onboarding/import-local | onboarding.controller.ts:22 | JWT | Import guest-mode local plan (idempotent by `clientMigrationId`, unique `[ownerUserId, importMigrationId]`) | onboarding fields + clientMigrationId, costs[{title,totalAmount,categoryName,partyName,…,payments[],paymentSchedules[]}], tasks[], guests[] | LocalPlanImportResponse (imported, alreadyImported) |
| GET | /api/v1/dashboard/home | dashboard/dashboard.controller.ts:12 | JWT | Home for active context | – | home payload |
| GET | /api/v1/wedding-plans/:planId/dashboard-summary | dashboard.controller.ts:23 | JWT R, WP | Plan dashboard | – | WeddingPlanDashboardSummaryResponse (dataScope, budgetTotal, paidTotal, outstandingTotal, task/guest/provider/participant/notification summaries, importantItems, nextBestActions, financialWarnings, currentUserRole, permissions, contributionHistory…) |
| GET | /api/v1/wedding-plans/:weddingPlanId/assistant | dashboard/assistant/assistant.controller.ts:14 | JWT R | AI assistant status (allowed only if seesWholePlan) | – | enabled, allowed, dailyLimit, remainingToday |
| POST | /api/v1/wedding-plans/:weddingPlanId/assistant/questions | assistant.controller.ts:24 | JWT R + seesWholePlan (else 403) T30, 200 | Ask LLM assistant | kind (PLAN, BUDGET_SPLIT, COMPARE_QUOTES, CHEAPER, FORGOTTEN, NEGOTIATION…), question?, consent | kind, answer, declined, marketDataAvailable, remainingToday |
| GET | /api/v1/wedding-plans/:weddingPlanId/timeline | timeline/timeline.controller.ts:12 | JWT R, WP (tasks need TASKS; schedules need MONEY_R) | Upcoming tasks + payment schedules | – | weddingDate, upcomingTasks[], paymentSchedules[] |

### 1.3 Contributors / memberships / permissions / invites (19)

All in `modules/collaboration/api/`.

| Method | Path | Ctrl file:line | Auth / plan perm | Purpose | Key request | Key response |
|---|---|---|---|---|---|---|
| POST | /api/v1/invites/:token/request-otp | sharing.controller.ts:32 | PUB T20 | Invitee (maybe no account) requests OTP | phone | InviteOtpRequestResponse |
| POST | /api/v1/invites/:token/verify-otp | sharing.controller.ts:42 | PUB T30 | Verify; may create account + tokens | phone, code, name?, password? | verified, user?, accessToken?, refreshToken? |
| GET | /api/v1/shared/wedding-plans | sharing.controller.ts:54 | JWT | Plans shared with me | – | SharedWeddingPlanResponse[] (id, title, city, weddingDate, currency, status, sharedMember) |
| POST | /api/v1/wedding-plans/:weddingPlanId/members | sharing.controller.ts:65 | JWT MEMBERS + ceiling | Directly add existing user as member | userId \| phone, role (≠OWNER, default VIEWER), can* flags, receiveNotifications | SharedMemberResponse |
| GET | /api/v1/wedding-plans/:weddingPlanId/members | :74 | JWT R | List members (owner pseudo-row `owner:` id) | – | PlanMemberResponse[] (SharedMemberResponse + isOwner) |
| DELETE | /api/v1/wedding-plans/:weddingPlanId/members/me | :82 | JWT member | Leave plan (optimistic) | expectedMemberId, expectedAuthorityVersion | result |
| PATCH | /api/v1/wedding-plans/:weddingPlanId/members/:memberId | :95 | JWT MEMBERS; non-owner only members they created; ceiling | Change role/flags; revocation snapshots history | role, can* flags, receiveNotifications | SharedMemberResponse |
| DELETE | /api/v1/wedding-plans/:weddingPlanId/members/:memberId | :110 | JWT MEMBERS; non-owner only own-created; ceiling | Remove member | – | result |
| POST | /api/v1/wedding-plans/:weddingPlanId/invites | :129 | JWT MEMBERS + ceiling, ARCH | Create invite (default 14 d) | name, userId, phone, email, role, can* flags, receiveNotifications, expiresInDays | PlanInviteResponse incl. one-time raw `token`, delivery |
| GET | /api/v1/wedding-plans/:weddingPlanId/invites | :138 | JWT R (MEMBERS to see; non-owner sees own) | List invites | – | PlanInviteResponse[] |
| DELETE | /api/v1/wedding-plans/:weddingPlanId/invites/:inviteId | :146 | JWT MEMBERS + ceiling | Revoke invite | – | result |
| POST | /api/v1/wedding-plans/:weddingPlanId/invites/:inviteId/reissue | :159 | JWT MEMBERS + ceiling + cooldown | Reissue token (body = UpdateSharedMemberDto) | role, can* flags | PlanInviteResponse (new token) |
| GET | /api/v1/invites/mine | :180 | JWT | Invites addressed to me | – | PlanInviteResponse[] |
| GET | /api/v1/invites/:token | :185 | JWT (invite must belong to me) | Invite detail | – | PlanInviteResponse |
| POST | /api/v1/invites/:token/accept | :199 | JWT, ARCH | Accept → SharedMember | – | membership / plan |
| POST | /api/v1/invites/:token/decline | :207 | JWT | Decline | – | invite |
| GET | /api/v1/wedding-plans/:weddingPlanId/permissions/me | :221 | JWT R | My effective permissions | – | PermissionSummaryResponse (isOwner, role, canViewMoney, canManageTasks, canManageGuests, canManageProviders, canManageMoney, canManagePlan, canManageMembers, receiveNotifications) |
| GET | /api/v1/wedding-plans/:weddingPlanId/contributions/summary | contribution-history.controller.ts:13 | JWT R (owner sees all; others self) | Contribution counts | q: contributorUserId? | summary |
| GET | /api/v1/wedding-plans/:weddingPlanId/contributions | contribution-history.controller.ts:22 | JWT R | Contribution event history | q: section (ContributionSection), contributorUserId | historyCoverageStartsAt, events[{id, contributorReference, section, entityType, action, snapshot, provenance, occurredAt, capturedAt}], total |

### 1.4 Money: budget, costs, payments, schedules, reversals, receipts, funding, loans (34)

No refund endpoint exists; "refund" = `POST cost-payments/:id/reverse` (REVERSAL entry, `CostPayment.reversalOfId`).

| Method | Path | Ctrl file:line | Auth / plan perm | Purpose | Key request | Key response |
|---|---|---|---|---|---|---|
| POST | /api/v1/wedding-plans/:weddingPlanId/budget-categories | budget-categories/budget-categories.controller.ts:25 | JWT MONEY_W, allocation must fit budget | Create category | name, allocatedAmount | BudgetCategoryResponse (id, weddingPlanId, name, allocatedAmount, costsCount) |
| GET | /api/v1/wedding-plans/:weddingPlanId/budget-categories | :34 | JWT MONEY_R, WP | List categories | – | BudgetCategoryResponse[] |
| PATCH | /api/v1/budget-categories/:id | :50 | JWT MONEY_W, WP | Update | name, allocatedAmount | BudgetCategoryResponse |
| DELETE | /api/v1/budget-categories/:id | :59 | JWT MONEY_W, WP | Delete | – | result |
| GET | /api/v1/wedding-plans/:planId/money-summary | money/money-summary.controller.ts:17 | JWT MONEY_R, WP | Aggregated money | – | weddingPlanId, currency, budget{total, allocated, unallocated, confirmedCost, remaining}, costs{total, paid, outstanding, count}, paymentSchedules{totalCount, upcomingCount, overdueCount, paidCount, next}, categories[], funding{total, received, pledged, availableCash, shortfall, loanTotal…} (owner), warnings[] (BUDGET_EXCEEDED, CATEGORY_EXCEEDED, PAYMENT_SCHEDULE_OVERDUE/DUE_SOON, FUNDING_SHORTFALL, LOAN_REPAYMENT_OVERDUE), permissions{canViewMoney, canManageMoney} |
| PUT | /api/v1/wedding-plans/:planId/money-budget | money-summary.controller.ts:25 | JWT MONEY_W | Replace total budget + categories in one go | totalBudget, currency, categories[{id?, clientId?, name, allocatedAmount}] | summary, categories, idMap (clientId→id) |
| GET | /api/v1/wedding-plans/:planId/funding-sources | money/funding-sources.controller.ts:27 | JWT MONEY_R; **non-owner gets []** | Funding sources + loans | – | FundingSourceResponse[] (kind, sourceName, amount, status, receivedAt, repaidAmount, outstandingAmount, repayments[]) |
| POST | /api/v1/wedding-plans/:planId/funding-sources | :35 | JWT MONEY_W + **OWNER** (else 404) | Add funding | kind (SAVINGS/FAMILY_SUPPORT/GIFT/LOAN/OTHER), sourceName, sourcePhone, amount, status, receivedAt, note | FundingSourceResponse |
| PATCH | /api/v1/funding-sources/:id | :50 | JWT MONEY_W + OWNER | Update | same, optional | FundingSourceResponse |
| DELETE | /api/v1/funding-sources/:id | :59 | JWT MONEY_W + OWNER | Delete | – | result |
| POST | /api/v1/funding-sources/:id/repayments | :67 | JWT MONEY_W + OWNER | Add loan repayment | amount, dueDate, note | LoanRepaymentResponse |
| PATCH | /api/v1/loan-repayments/:id | :82 | JWT MONEY_W + OWNER | Update repayment | amount, dueDate, status (PLANNED/PAID/CANCELLED), paidAt, note | LoanRepaymentResponse |
| DELETE | /api/v1/loan-repayments/:id | :91 | JWT MONEY_W + OWNER | Delete repayment | – | result |
| POST | /api/v1/wedding-plans/:weddingPlanId/costs | wedding-costs/wedding-costs.controller.ts:31 | JWT MONEY_W, WP (category scoped); isPrivate only if seesWholePlan (403 `COST_PRIVACY_NOT_ALLOWED`) | Create cost (optional initial payment) | budgetCategoryId, title, totalAmount, initialPaymentAmount, providerId, quoteOfferId, partyName, partyPhone, agreementDate, payer (GROOM/BRIDE/FAMILY/SHARED/OTHER), payerName, note, isPrivate | WeddingCostResponse (… totalAmount, paidAmount, remainingAmount, status, isPrivate, paymentsCount, paymentSchedulesCount) |
| GET | /api/v1/wedding-plans/:weddingPlanId/costs | :40 | JWT MONEY_R, WP, others' private hidden | List costs | q: status, categoryId, search, payer | WeddingCostResponse[] |
| GET | /api/v1/costs/:id | :55 | JWT MONEY_R, WP | Cost detail | – | WeddingCostResponse |
| PATCH | /api/v1/costs/:id | :60 | JWT MONEY_W, WP | Update cost | same as create minus initialPaymentAmount | WeddingCostResponse |
| DELETE | /api/v1/costs/:id | :69 | JWT MONEY_W, WP | Delete cost | – | result |
| POST | /api/v1/costs/:id/cancel | :74 | JWT MONEY_W, WP | Cancel cost | – | WeddingCostResponse |
| POST | /api/v1/costs/:id/payments | :79 | JWT MONEY_W, WP, cost payable | Record payment | amount, paidAt, method, note | CostPaymentResponse |
| GET | /api/v1/costs/:id/payments | :88 | JWT MONEY_R, WP | Payments for cost | – | CostPaymentResponse[] |
| POST | /api/v1/costs/:id/payment-schedules | :96 | JWT MONEY_W, WP | Add installment | amount, dueDate, note | PaymentScheduleResponse |
| GET | /api/v1/costs/:id/payment-schedules | :105 | JWT MONEY_R, WP | Installments for cost | – | PaymentScheduleResponse[] |
| GET | /api/v1/wedding-plans/:weddingPlanId/cost-payments | :119 | JWT MONEY_R, WP | Paged plan payments | q: page (1), limit (≤100, 50) | {items, page, pageSize, total, totalPages} of CostPaymentResponse (amount, entryType PAYMENT/REVERSAL, reversalOfId, reversedById, reversible…) |
| GET | /api/v1/cost-payments/:id | :134 | JWT MONEY_R, WP | Payment detail | – | CostPaymentResponse |
| POST | /api/v1/cost-payments/:id/reverse | :139 | JWT MONEY_W, WP | Reverse (refund) a payment | reason | reversal CostPaymentResponse |
| GET | /api/v1/wedding-plans/:weddingPlanId/payment-schedules/due | :154 | JWT MONEY_R, WP | Due/overdue installments | – | PaymentScheduleResponse[] (isOverdue) |
| PATCH | /api/v1/payment-schedules/:id | :168 | JWT MONEY_W, WP | Update installment | amount, dueDate, note | PaymentScheduleResponse |
| DELETE | /api/v1/payment-schedules/:id | :177 | JWT MONEY_W, WP | Delete installment | – | result |
| POST | /api/v1/payment-schedules/:id/cancel | :182 | JWT MONEY_W, WP | Cancel installment | – | PaymentScheduleResponse |
| POST | /api/v1/payment-schedules/:id/pay | :187 | JWT MONEY_W, WP | Pay installment → creates CostPayment | paidAt, method, note | {payment, schedule} |
| GET | /api/v1/costs/:costId/receipts | wedding-costs/cost-receipts.controller.ts:22 | JWT MONEY_R + cost visible | List receipts (signed URLs) | – | receipts |
| POST | /api/v1/costs/:costId/receipts | :30 | JWT MONEY_W + cost scoped | Attach verified upload | attachmentRef, costPaymentId? | receipt |
| DELETE | /api/v1/costs/:costId/receipts/:receiptId | :39 | JWT MONEY_W + cost scoped | Delete receipt | – | result |

### 1.5 Tasks (11) — `tasks/tasks.controller.ts`

| Method | Path | line | Auth / plan perm | Purpose | Key request | Key response |
|---|---|---|---|---|---|---|
| POST | /api/v1/wedding-plans/:weddingPlanId/tasks | :30 | JWT TASKS, ARCH; isPrivate only if seesWholePlan (403 `TASK_PRIVACY_NOT_ALLOWED`) | Create task | title, description, dueDate, taskCategory, responsibleName/Phone/Source, reminderAt, status, priority, isPrivate | TaskResponse (…, isPrivate, checklist[]) |
| GET | /api/v1/wedding-plans/:weddingPlanId/tasks | :39 | JWT R; contributor w/o TASKS → []; WP | List | q: take, skip (cap 1000) | TaskResponse[] |
| POST | /api/v1/wedding-plans/:weddingPlanId/tasks/shift-due-dates | :49 | JWT TASKS + seesWholePlan (else 403), 200 | Shift all open due dates | days (≠0 int) | {shifted} |
| GET | /api/v1/wedding-plans/:weddingPlanId/tasks/summary | :59 | JWT R, WP | Counters | – | TaskSummaryResponse (total, completed, overdue, dueToday, assignedToMe, byStatus, byPriority, canKeepPrivateTask…) |
| GET | /api/v1/tasks/:id | :73 | JWT R; contributor w/o TASKS → 403 `TASK_PERMISSION_REVOKED`; WP | Detail | – | TaskResponse |
| POST | /api/v1/tasks/:id/checklist | :81 | JWT TASKS, WP | Add checklist item | title, isDone, sortOrder | ChecklistItemResponse |
| PATCH | /api/v1/tasks/:id/checklist/:itemId | :90 | JWT TASKS, WP | Update item | title, isDone, sortOrder | ChecklistItemResponse |
| DELETE | /api/v1/tasks/:id/checklist/:itemId | :100 | JWT TASKS, WP | Delete item | – | result |
| PATCH | /api/v1/tasks/:id/assign | :109 | JWT TASKS, WP; assignee must be member with task perm | Assign/unassign | assigneeUserId \| null | TaskResponse (TASK_ASSIGNED notif) |
| PATCH | /api/v1/tasks/:id | :118 | JWT TASKS, WP | Update | CreateTaskDto fields + isPrivate | TaskResponse |
| DELETE | /api/v1/tasks/:id | :127 | JWT TASKS, WP | Delete | – | result |

### 1.6 Guests, groups, invitations, public RSVP (14)

| Method | Path | Ctrl file:line | Auth / plan perm | Purpose | Key request | Key response |
|---|---|---|---|---|---|---|
| GET | /api/v1/wedding-plans/:weddingPlanId/guests | guests/guests.controller.ts:28 | JWT R; private details need GUESTS; contributor w/o GUESTS → []; WP | List | q: take, skip | GuestResponse[] (name, phone, side, status, invitationStatus, attendanceStatus, seatsCount, companionsCount, notes, groupId) |
| POST | /api/v1/wedding-plans/:weddingPlanId/guests | :37 | JWT GUESTS, ARCH | Add guest (unique `[plan, normalizedPhone]`) | name, phone, groupId, side, status, invitationStatus, attendanceStatus, seatsCount, companionsCount, notes | GuestResponse |
| POST | /api/v1/wedding-plans/:weddingPlanId/guests/bulk | :46 | JWT GUESTS | Bulk add | items[CreateGuestDto] | {created} |
| GET | /api/v1/wedding-plans/:weddingPlanId/guests/summary | :55 | JWT R, WP | Counters | – | GuestsSummaryResponse (totalGuests, confirmed, declined, pending, seatsTotal, companionsTotal, bySide, byGroup, byInvitationStatus, byAttendanceStatus…) |
| GET | /api/v1/wedding-plans/:weddingPlanId/guest-groups | :69 | JWT R, WP | List groups | – | GuestGroupResponse[] |
| POST | /api/v1/wedding-plans/:weddingPlanId/guest-groups | :77 | JWT GUESTS | Create group (unique `[plan, name]`) | name, notes, sortOrder | GuestGroupResponse |
| GET | /api/v1/guests/:id | :92 | JWT R; contributor must be own-created | Detail | – | GuestResponse |
| PATCH | /api/v1/guests/:id | :100 | JWT GUESTS, WP | Update | UpdateGuestDto | GuestResponse |
| DELETE | /api/v1/guests/:id | :109 | JWT GUESTS, WP | Delete | – | result |
| PATCH | /api/v1/guest-groups/:id | :123 | JWT GUESTS, WP | Update group | name, notes, sortOrder | GuestGroupResponse |
| DELETE | /api/v1/guest-groups/:id | :132 | JWT GUESTS, WP | Delete group | – | result |
| POST | /api/v1/guests/:id/invitation-link | guests/guest-rsvp.controller.ts:33 | JWT GUESTS, WP (own-created guest) | Mint personal RSVP link (stores `rsvpTokenHash`) | – | link/token |
| GET | /api/v1/public/rsvp/:token | guest-rsvp.controller.ts:50 | **PUB** T30 | Guest views invitation | – | PublicInvitation (guestName, planTitle, weddingDate, locationLabel, attendanceStatus, companionsCount, maxCompanions, respondedAt) |
| POST | /api/v1/public/rsvp/:token | guest-rsvp.controller.ts:56 | **PUB** T10 | Guest answers (→ GUEST_RESPONDED notif) | attendance (CONFIRMED/DECLINED), companionsCount (0..RSVP_MAX_COMPANIONS) | PublicInvitation |

### 1.7 Notifications, push devices (9)

| Method | Path | Ctrl file:line | Auth | Purpose | Key request | Key response |
|---|---|---|---|---|---|---|
| GET | /api/v1/notifications | notifications/notifications.controller.ts:22 | JWT (plan visibility + WP entity filtering) | Paged list | q: weddingPlanId, type, unreadOnly, page, limit | {items: NotificationResponse[], page, limit, total, totalPages, hasMore} |
| GET | /api/v1/notifications/unread-count | :42 | JWT | Unread count | q: weddingPlanId | count |
| GET | /api/v1/notifications/:id | :51 | JWT own + visibility | Detail | – | NotificationResponse (type, priority, title, body, entityType, entityId, routeTarget, data, readAt, archivedAt) |
| PATCH | /api/v1/notifications/:id/read | :60 | JWT own | Mark read | – | NotificationResponse |
| PATCH | /api/v1/notifications/read-all | :68 | JWT | Mark all read | q: weddingPlanId | count |
| PATCH | /api/v1/notifications/:id/archive | :76 | JWT own | Archive | – | NotificationResponse |
| DELETE | /api/v1/notifications/:id | :84 | JWT own | Delete | – | result |
| PUT | /api/v1/push/installations/current | push/push.controller.ts:22 | JWT T30 | Register FCM installation | fid, platform (ANDROID/IOS) | installation |
| DELETE | /api/v1/push/installations/current | push.controller.ts:31 | JWT T30 | Unregister | fid, platform | result |

All notification/push/conversation GETs send `Cache-Control: private, no-store`.

### 1.8 Files / uploads (2)

| Method | Path | Ctrl file:line | Auth | Purpose | Key request | Key response |
|---|---|---|---|---|---|---|
| POST | /api/v1/media/uploads/presign | media/media.controller.ts:15 | JWT T20 | Reserve `MediaUploadTicket`, presigned S3 PUT | purpose (user-avatar, provider-logo, provider-cover, service-image, chat-image, cost-receipt), fileName, contentType, byteSize | key, uploadUrl, requiredHeaders{If-None-Match:*}, expiresInSeconds, publicUrl (null), attachmentRef (null) |
| POST | /api/v1/media/uploads/verify | media.controller.ts:25 | JWT T30 | Verify uploaded object (sanitized image) | key, purpose | VerifiedMediaUpload (key, attachmentRef for private purposes, publicUrl for public, contentType, byteSize) |

Private purposes (signed URL only): `chat-image`, `cost-receipt` (`modules/media/public/media-storage.port.ts:19`).

### 1.9 Conversations / chat / reports (12) — `conversations/conversations.controller.ts`

Access (`conversations/conversations.service.ts:823 accessFor`): provider owner (must be ACTIVE); ACCOUNT-scope requester; PLAN-scope plan owner; plan member with `canManageProviders` (no WP scoping — any such member sees every plan conversation). Money fields gated by canViewMoney.

| Method | Path | line | Purpose | Key request | Key response |
|---|---|---|---|---|---|
| GET | /api/v1/conversations | :24 | Cursor list | q: cursor, limit | items[{id, scope, weddingPlan, provider{id, businessName, logoUrl}, quoteRequestCount, latestQuoteRequest, lastMessage, lastActivityAt, unread, muted, blockedByMe, blockedByCounterpart, canSend, permissions{canManageProviders, canViewMoney, canManageMoney, canViewContact}, closedAt}] |
| GET | /api/v1/conversations/:id | :34 | Detail | – | conversation |
| GET | /api/v1/conversations/:id/messages | :40 | Messages page (≤50, default 30) | cursor, limit | messages |
| GET | /api/v1/conversations/:id/quote-requests | :51 | Quotes in thread | – | quote requests |
| GET | /api/v1/conversations/:id/timeline | :60 | Messages + ConversationEvents merged | cursor, limit | timeline items |
| POST | /api/v1/conversations/:id/messages | :71 | Send (409 if blocked; provider must have joined) | body (1–2000), attachments[{attachmentRef, contentType, byteSize}] | message (→ CHAT_MESSAGE_RECEIVED, outbox realtime) |
| GET | /api/v1/conversations/:id/attachments/:attachmentId/download | :81 | Signed download URL | – | downloadUrl, expiresInSeconds, expiresAt |
| PATCH | /api/v1/conversations/:id/read | :91 | Mark read | – | receipt |
| PATCH | /api/v1/conversations/:id/mute | :96 | Mute toggle | enabled | state |
| PATCH | /api/v1/conversations/:id/block | :105 | Block toggle (side-specific) | enabled | state |
| POST | /api/v1/conversations/:id/report | :114 | Report (unique per reporter) | reason | ConversationReport |
| GET | /api/v1/quote-requests/:quoteRequestId/conversation | :129 | Conversation for a quote | – | conversation |

All JWT.

### 1.10 Marketplace: public directory, catalogs, favorites, reviews (24)

| Method | Path | Ctrl file:line | Auth | Purpose | Key request | Key response |
|---|---|---|---|---|---|---|
| GET | /api/v1/cities | marketplace/marketplace.controller.ts:29 | PUB | Active cities | – | City[] |
| GET | /api/v1/governorates | :39 | PUB | Governorates | – | Governorate[] |
| GET | /api/v1/governorates/:id/districts | :44 | PUB | Districts | – | District[] |
| GET | /api/v1/provider-categories | :54 | PUB | Active categories | – | ProviderCategory[] (nameAr, slug, icon, showForGroom/Bride) |
| GET | /api/v1/providers | :64 | PUB | Search ACTIVE providers | q: cityId, categoryId, search, featured, page, limit | {items, page, limit, total, totalPages} |
| GET | /api/v1/providers/:id/services | :69 | PUB | Provider services | – | services+images |
| GET | /api/v1/providers/:id/packages | :74 | PUB | Packages | – | packages |
| GET | /api/v1/providers/:id/reviews | :79 | PUB | Published reviews | – | reviews |
| POST | /api/v1/providers/:id/favorite | :84 | JWT | Favorite (provider ACTIVE) | – | favorite |
| DELETE | /api/v1/providers/:id/favorite | :93 | JWT | Unfavorite | – | result |
| POST | /api/v1/providers/:id/quote-requests | :102 | JWT; if weddingPlanId → PROV | Ask provider for quote (creates/attaches Conversation) | weddingPlanId?, serviceId, eventDate, location, cityId, guestCount, message, contactName, contactPhone, budgetMin, budgetMax | quote request |
| POST | /api/v1/providers/:id/reviews | :112 | JWT; provider ACTIVE; 403 rules (eligibility) | Review (unique user+provider) | rating, comment | review |
| POST | /api/v1/providers/:id/views | :124 | PUB T30, 200 | Count profile view (`ProviderProfileViewDay`) | – | ok |
| GET | /api/v1/providers/:id | :131 | PUB | Provider profile (+responsiveness) | – | provider |
| GET | /api/v1/services | :141 | PUB | Search services | q: cityId, categoryId, providerId, search, minPrice, maxPrice, page, limit | paginated |
| GET | /api/v1/services/:id | :146 | PUB | Service detail | – | service |
| GET | /api/v1/me/favorite-providers | :157 | JWT | My favorites | – | favorites |
| GET | /api/v1/me/quote-requests | :162 | JWT (own + plans I may see, WP) | My quote requests | – | quotes |
| GET | /api/v1/me/quote-requests/:id | :167 | JWT | One | – | quote (+offers) |
| PATCH | /api/v1/me/quote-requests/:id/cancel | :175 | JWT | Cancel | – | quote |
| PATCH | /api/v1/reviews/:id | :189 | JWT own | Edit review | rating, comment | review |
| DELETE | /api/v1/reviews/:id | :198 | JWT own | Delete review | – | result |
| GET | /api/v1/catalogs/bootstrap | catalogs/catalogs.controller.ts:34 | PUB | Published reference catalogs (versioned) | q: version | catalogs/items |
| GET | /api/v1/districts/:id/localities | catalogs.controller.ts:44 | PUB | Localities of district | – | AdministrativeLocality[] |

### 1.11 Quotes / offers (plan side) (6) — `marketplace/marketplace.controller.ts`

| Method | Path | line | Auth / plan perm | Purpose | Key request | Key response |
|---|---|---|---|---|---|---|
| POST | /api/v1/wedding-plans/:weddingPlanId/quote-requests | :212 | JWT PROV, ARCH | Plan quote request | providerId, serviceId, eventDate, location, cityId, guestCount, message, contactName, contactPhone, budgetMin, budgetMax | quote (→ QUOTE_REQUEST_SUBMITTED to provider) |
| GET | /api/v1/wedding-plans/:weddingPlanId/quote-requests | :225 | JWT R + PROV live; WP (contributor sees own QUOTE_REQUEST contributions); budget fields need MONEY_R | List | – | quotes+offers |
| GET | /api/v1/quote-requests/:id | :242 | JWT (same scoping) | Detail | – | quote |
| PATCH | /api/v1/quote-requests/:id/cancel | :253 | JWT PROV, ARCH, WP | Cancel | – | quote |
| PATCH | /api/v1/quote-offers/:id/accept | :270 | JWT PROV **and** MONEY_W, WP | Accept offer → creates WeddingCost + PlanProviderLink | – | offer, cost, link (→ QUOTE_ACCEPTED) |
| PATCH | /api/v1/quote-offers/:id/reject | :278 | JWT PROV, WP | Reject offer | – | offer (→ QUOTE_REJECTED) |

### 1.12 Bookings / calendar (10) — `marketplace/bookings.controller.ts`

| Method | Path | line | Auth | Purpose | Key request | Key response |
|---|---|---|---|---|---|---|
| POST | /api/v1/me/quote-requests/:id/booking | :28 | JWT; plan quote → R+PROV, ARCH, WP (403 `PROVIDER_PERMISSION_REVOKED`); account quote → requester; provider ACTIVE, day available | Request booking (unique per quote) | eventDate, note | Booking (status REQUESTED) |
| PATCH | /api/v1/me/bookings/:id/cancel | :37 | JWT same as above | Customer cancels | note | Booking |
| GET | /api/v1/me/wedding-plans/:weddingPlanId/bookings | :47 | JWT R; w/o PROV → []; WP | Plan bookings | – | Booking[] + providerName |
| GET | /api/v1/provider/me/bookings | :62 | JWT PROVIDER | Provider's bookings | – | Booking[] |
| PATCH | /api/v1/provider/me/bookings/:id/confirm | :67 | JWT PROVIDER+ACTIVE, day available | Confirm | note | Booking (→ BOOKING_UPDATED) |
| PATCH | /api/v1/provider/me/bookings/:id/decline | :76 | JWT PROVIDER+ACTIVE | Decline | note | Booking |
| PATCH | /api/v1/provider/me/bookings/:id/cancel | :85 | JWT PROVIDER+ACTIVE | Provider cancels | note | Booking |
| GET | /api/v1/provider/me/blocked-dates | :94 | JWT PROVIDER | Blocked dates | – | dates |
| POST | /api/v1/provider/me/blocked-dates | :99 | JWT PROVIDER | Block date (unique provider+date) | date | blocked date |
| DELETE | /api/v1/provider/me/blocked-dates/:date | :107 | JWT PROVIDER | Unblock | – | result |

### 1.13 Provider dashboard (24) — `provider-dashboard/provider-dashboard.controller.ts`

Profile reads work for any status; writes blocked for SUSPENDED/REJECTED (`PROVIDER_PROFILE_READ_ONLY`); services/packages/quotes/summary require ACTIVE (`findActiveOwnedProviderOrThrow`, service:1243).

| Method | Path | line | Auth | Purpose | Key request | Key response |
|---|---|---|---|---|---|---|
| POST | /api/v1/provider/apply | :36 | JWT (no existing provider; unclaimed listing with my phone → must claim) | Apply as provider (status PENDING) | businessName, phone, cityId, categoryIds[], description | provider |
| GET | /api/v1/provider/claimable | :45 | JWT | Admin-created listing matching my phone | – | {listing} |
| POST | /api/v1/provider/claim/:providerId | :50 | JWT (phone match, listing ACTIVE) | Claim listing | – | provider |
| GET | /api/v1/provider/me/profile | :66 | JWT PROVIDER | Profile + access policy | – | profile (accessMode FULL/LIMITED/READ_ONLY, capabilities) |
| PATCH | /api/v1/provider/me/profile | :71 | JWT PROVIDER (writable) | Update | businessName, ownerName, phone, whatsapp, email, description, address, cityId, latitude, longitude, logoUrl, coverUrl | profile |
| GET | /api/v1/provider/me/summary | :79 | PROVIDER+ACTIVE | Stats | – | summary |
| GET | /api/v1/provider/me/services | :84 | PROVIDER+ACTIVE | My services | – | services |
| POST | /api/v1/provider/me/services | :89 | PROVIDER+ACTIVE | Create service | categoryId, title, description, basePrice, priceUnit, currency, cityId | service |
| POST | /api/v1/provider/me/services/:id/images | :97 | PROVIDER+ACTIVE | Add image | imageUrl, altText, sortOrder | image |
| PATCH | /api/v1/provider/me/services/:serviceId/images/:imageId | :110 | PROVIDER+ACTIVE | Update image | imageUrl, altText, sortOrder | image |
| DELETE | /api/v1/provider/me/services/:serviceId/images/:imageId | :125 | PROVIDER+ACTIVE | Delete image | – | result |
| GET | /api/v1/provider/me/services/:id | :138 | PROVIDER+ACTIVE | Service | – | service |
| PATCH | /api/v1/provider/me/services/:id | :146 | PROVIDER+ACTIVE | Update service | + isActive | service |
| DELETE | /api/v1/provider/me/services/:id | :155 | PROVIDER+ACTIVE | Deactivate (soft) | – | service |
| GET | /api/v1/provider/me/packages | :163 | PROVIDER+ACTIVE | Packages | – | packages |
| POST | /api/v1/provider/me/packages | :168 | PROVIDER+ACTIVE | Create package | serviceId, title, description, price, currency, items(json) | package |
| PATCH | /api/v1/provider/me/packages/:id | :176 | PROVIDER+ACTIVE | Update | + isActive | package |
| DELETE | /api/v1/provider/me/packages/:id | :185 | PROVIDER+ACTIVE | Deactivate | – | package |
| GET | /api/v1/provider/me/quote-requests | :193 | PROVIDER+ACTIVE | Incoming quotes | – | quotes |
| GET | /api/v1/provider/me/quote-requests/:id | :198 | PROVIDER+ACTIVE | Quote (marks VIEWED) | – | quote |
| PATCH | /api/v1/provider/me/quote-requests/:id/status | :206 | PROVIDER+ACTIVE, plan writable, valid transition | Set status | status (QuoteRequestStatus) | quote |
| POST | /api/v1/provider/me/quote-requests/:id/offers | :219 | PROVIDER+ACTIVE | Send offer (→ QUOTE_OFFER_RECEIVED) | title, message, amount, currency, validUntil | offer |
| PATCH | /api/v1/provider/me/quote-offers/:id | :228 | PROVIDER+ACTIVE | Edit offer | title, message, amount, currency, validUntil | offer |
| GET | /api/v1/provider/me/reviews | :237 | PROVIDER+ACTIVE | Reviews | – | reviews |

### 1.14 Admin / back office (60) — no `/api/v1` prefix

`admin/admin.controller.ts` (all ADM). Admin role → permission map in `modules/backoffice/domain/admin-permissions.ts`.

| Method | Path | line | Perm | Purpose / key request |
|---|---|---|---|---|
| GET | /admin/dashboard/stats | :41 | DASHBOARD_READ | KPIs |
| GET | /admin/reports/success | :48 | REPORTS_READ | Success report |
| GET | /admin/reports/overview | :54 | REPORTS_READ | q: from, to |
| GET | /admin/providers/applications | :60 | PROVIDERS_READ | q: status, cityId, categoryId, search, page, limit |
| GET | /admin/providers/applications/:id | :66 | PROVIDERS_READ | Application detail |
| PATCH | /admin/providers/:id/approve | :72 | PROVIDERS_WRITE | → ACTIVE |
| PATCH | /admin/providers/:id/reject | :81 | PROVIDERS_WRITE | reason, note |
| PATCH | /admin/providers/:id/request-changes | :91 | PROVIDERS_WRITE | → NEEDS_CHANGES; reason, note |
| PATCH | /admin/providers/:id/suspend | :101 | PROVIDERS_WRITE | reason, note |
| PATCH | /admin/providers/:id/activate | :111 | PROVIDERS_WRITE | Reactivate |
| PATCH | /admin/providers/:id/verify | :120 | PROVIDERS_WRITE | Set verifiedAt |
| PATCH | /admin/providers/:id/unverify | :129 | PROVIDERS_WRITE | Clear verifiedAt |
| POST | /admin/providers | :139 | PROVIDERS_WRITE | Create unclaimed listing: businessName, phone, whatsapp, cityId, categoryId, description, address |
| GET | /admin/providers | :148 | PROVIDERS_READ | List |
| GET | /admin/providers/:id | :154 | PROVIDERS_READ | Detail |
| GET | /admin/services | :160 | SERVICES_READ | q: status, providerId, cityId, categoryId, search, page, limit |
| POST | /admin/services | :166 | SERVICES_WRITE | providerId, categoryId, title, description, basePrice, priceUnit, currency, cityId, isActive, isFeatured |
| PATCH | /admin/services/:id | :175 | SERVICES_WRITE | same |
| DELETE | /admin/services/:id | :185 | SERVICES_WRITE | Delete service |
| GET | /admin/reviews | :194 | REVIEWS_READ | q: status, providerId, search, page, limit |
| PATCH | /admin/reviews/:id/status | :200 | REVIEWS_WRITE | status |
| DELETE | /admin/reviews/:id | :210 | REVIEWS_WRITE | Hide review |
| GET | /admin/conversation-reports | :219 | CONVERSATION_REPORTS_READ | q: status, page, limit |
| PATCH | /admin/conversation-reports/:id/status | :225 | CONVERSATION_REPORTS_WRITE | status (OPEN/REVIEWED/DISMISSED) |
| GET | /admin/notifications | :239 | NOTIFICATIONS_READ | q: type, priority, unreadOnly, search, page, limit (privacy-redacted) |
| GET | /admin/notifications/unread-count | :245 | NOTIFICATIONS_READ | count |
| PATCH | /admin/notifications/:id/read | :251 | NOTIFICATIONS_WRITE | |
| PATCH | /admin/notifications/:id/archive | :260 | NOTIFICATIONS_WRITE | |
| DELETE | /admin/notifications/:id | :269 | NOTIFICATIONS_WRITE | |
| GET | /admin/provider-categories | :278 | CATALOG_READ | |
| POST | /admin/provider-categories | :284 | CATALOG_WRITE | nameAr, nameEn, slug, icon, isActive, showForGroom, showForBride, sortOrder |
| PATCH | /admin/provider-categories/:id | :293 | CATALOG_WRITE | same |
| DELETE | /admin/provider-categories/:id | :303 | CATALOG_WRITE | |
| GET | /admin/cities | :312 | CATALOG_READ | |
| POST | /admin/cities | :318 | CATALOG_WRITE | nameAr, nameEn, countryCode, isActive, sortOrder |
| PATCH | /admin/cities/:id | :327 | CATALOG_WRITE | same |
| DELETE | /admin/cities/:id | :337 | CATALOG_WRITE | |
| GET | /admin/users | :346 | USERS_READ | q (reuses AdminProviderQueryDto) |
| PATCH | /admin/users/:id/activate | :352 | USERS_WRITE | |
| PATCH | /admin/users/:id/disable | :361 | USERS_WRITE | Disable; revokes sessions + issued invites |
| GET | /admin/users/:id | :370 | USERS_READ | |
| GET | /admin/audit-logs | admin/admin-audit.controller.ts:15 | AUDIT_READ | q: page, limit, action, actorUserId, phase, from, to |
| GET | /admin/reference-catalogs | catalogs/catalogs.controller.ts:55 | CATALOG_READ | List catalogs |
| GET | /admin/reference-catalogs/:catalogKey | :61 | CATALOG_READ | Catalog + items |
| POST | /admin/reference-catalogs/:catalogKey/items | :67 | CATALOG_WRITE | key, nameAr, nameEn, groupKey, groupNameAr, groupSubtitleAr, icon, sortOrder, showForGroom/Bride/Customer/Provider, isRecommended, isActive, metadata |
| PATCH | /admin/reference-catalogs/:catalogKey/items/:id | :77 | CATALOG_WRITE | New revision |
| POST | /admin/reference-catalogs/:catalogKey/items/:id/publish | :88 | CATALOG_WRITE | revision |
| DELETE | /admin/reference-catalogs/:catalogKey/items/:id | :99 | CATALOG_WRITE | Disable |
| GET | /admin/governorates | :115 | CATALOG_READ | |
| POST | /admin/governorates | :121 | CATALOG_WRITE | code, nameAr, nameEn, latitude, longitude, isActive, sortOrder |
| PATCH | /admin/governorates/:id | :130 | CATALOG_WRITE | |
| DELETE | /admin/governorates/:id | :140 | CATALOG_WRITE | Disable |
| GET | /admin/governorates/:id/districts | :149 | CATALOG_READ | |
| POST | /admin/governorates/:id/districts | :155 | CATALOG_WRITE | + governorateId |
| PATCH | /admin/districts/:id | :165 | CATALOG_WRITE | |
| DELETE | /admin/districts/:id | :175 | CATALOG_WRITE | Disable |
| GET | /admin/districts/:id/localities | :184 | CATALOG_READ | |
| POST | /admin/districts/:id/localities | :190 | CATALOG_WRITE | + districtId, parentId, type (AREA/ISOLATION/NEIGHBORHOOD/ZONE) |
| PATCH | /admin/localities/:id | :200 | CATALOG_WRITE | |
| DELETE | /admin/localities/:id | :210 | CATALOG_WRITE | Disable |

Admin role matrix: SUPER_ADMIN = all; OPERATIONS = DASHBOARD_R, REPORTS_R, USERS_R/W, PROVIDERS_R/W, SERVICES_R/W, CATALOG_R/W, REVIEWS_R, NOTIFICATIONS_R; MODERATOR = DASHBOARD_R, PROVIDERS_R, REVIEWS_R/W, CONVERSATION_REPORTS_R/W, NOTIFICATIONS_R/W; SUPPORT = DASHBOARD_R, USERS_R, PROVIDERS_R, SERVICES_R, CATALOG_R, NOTIFICATIONS_R. AUDIT_READ = SUPER_ADMIN only.

### 1.15 Health / ops (4)

| Method | Path | file:line | Auth | Purpose |
|---|---|---|---|---|
| GET | /health | platform/health/health.controller.ts:14 | PUB | Liveness (compat alias) |
| GET | /live | health.controller.ts:19 | PUB | Liveness |
| GET | /ready | health.controller.ts:27 | PUB | Readiness (DB, media storage via `ReadinessService`) |
| GET | /metrics | platform/observability/metrics.controller.ts:18 | `Bearer METRICS_TOKEN`; if unset: 404 in prod, open in dev | Prometheus text |

### 1.16 Counts

| Module | Routes |
|---|---|
| Auth / identity / contexts | 29 |
| Wedding plans + onboarding + dashboard + assistant + timeline | 15 |
| Collaboration (members, invites, permissions, contributions) | 19 |
| Money (budget, costs, payments, schedules, receipts, funding, loans) | 34 |
| Tasks | 11 |
| Guests + RSVP | 14 |
| Notifications + push | 9 |
| Media uploads | 2 |
| Conversations | 12 |
| Marketplace directory/catalog/favorites/reviews | 24 |
| Quotes / offers (plan side) | 6 |
| Bookings / calendar | 10 |
| Provider dashboard | 24 |
| Admin (incl. audit, reference + administrative catalogs) | 60 |
| Health / metrics | 4 |
| **Total** | **273** |

---

## 2. Prisma models (`backend/prisma/schema/*.prisma`, PostgreSQL)

IDs: `cuid()` unless noted `uuid`. Money = `Decimal(14,2)`.

### identity.prisma
Enums: `UserRole{USER,ADMIN,PROVIDER}`, `AppRole{WEDDING_USER,PROVIDER}`, `UserStatus{ACTIVE,DISABLED}`, `OtpPurpose{REGISTER,LOGIN,INVITE_ACCESS,ADMIN_LOGIN,VERIFY_PHONE,RESET_PASSWORD,ADMIN_RESET_PASSWORD}`, `AuthSessionScope{APPLICATION,ADMIN}`.

| Model | Key fields | Relations | Unique / notable indexes |
|---|---|---|---|
| User | name, phone, email, passwordHash, appPasswordHash, appName, appEmail, appAvatarUrl, role, adminRole?, appRole, status, phoneVerifiedAt, lastLoginAt, avatarUrl, locale(ar), activeWeddingPlanId, onboardingPath, persona, onboardingCompletedAt | owns WeddingPlan[], activeWeddingPlan, SharedMember[], NotificationPreference, Notification[], PushInstallation[], Provider?, favorites, reviews, QuoteRequest[], conversations, tasks assigned, invites sent/received, RefreshToken[], admin challenges, chat, MediaUploadTicket[], ContributorTenure[], AssistantUsageDay[] | phone, email, appEmail unique |
| AccountDeletionReceipt | receiptHash(PK char64), deletedAt | – | idx deletedAt |
| AdminLoginChallenge | userId, otpId, tokenHash, expiresAt, consumedAt | User, OtpCode | otpId, tokenHash unique |
| AdminPasswordResetChallenge | userId?, otpId, tokenHash, subjectHash, expiresAt, consumedAt, verifiedAt, attempts, maxAttempts(5) | User?, OtpCode | otpId, tokenHash unique |
| RefreshToken | userId, tokenHash, scope, expiresAt, revokedAt, replacedById | User | tokenHash, replacedById unique |
| LoginThrottle | subjectHash(PK), failedCount, windowStartedAt, lockedUntil | – | |
| OtpDispatchQuota | (scope, subjectHash) PK, count, windowStartedAt | – | |
| AssistantUsageDay | (userId, day) PK, requests, inputTokens, outputTokens, costMicroUsd | User | |
| OtpCode (uuid) | phone, codeHash, purpose, expiresAt, consumedAt, attempts, maxAttempts(5), planInviteId? | PlanInvite?, admin challenges | idx (phone,purpose,consumedAt) |

### planning.prisma
Enums: `OnboardingPath{USER,PROVIDER}`, `WeddingPersona{GROOM,BRIDE,HELPER}`, `WeddingPlanStatus{PLANNING,ARCHIVED}`.

| Model | Key fields | Relations | Unique |
|---|---|---|---|
| WeddingPlan | ownerUserId, title, city, location(Json), weddingDate, priorities[], estimatedBudget, currency(YER), onboardingPath, persona, onboardingCompletedAt, importMigrationId, status | owner, budgetCategories, weddingCosts, fundingSources, tasks, sharedMembers, planInvites, quoteRequests, notifications, guests, guestGroups, providerLinks, conversations, contributorHistoryScope | (ownerUserId, importMigrationId) |

### collaboration.prisma
Enums: `SharedMemberRole{OWNER,GROOM,BRIDE,FAMILY,VIEWER,EDITOR,FINANCE_MANAGER,HELPER,CONTRIBUTOR,MANAGER}`, `ContributionScopeStatus{ACTIVE,ARCHIVED,DELETED}`, `ContributorTenureEndReason{MEMBER_REMOVED,MEMBER_LEFT,ACCOUNT_DELETED,PLAN_DELETED}`, `ContributionSection{TASKS,GUESTS,MONEY,PROVIDERS,MEMBERS,PLAN}`, `ContributionEntityType{TASK,TASK_CHECKLIST_ITEM,GUEST,GUEST_GROUP,MONEY_ITEM,BUDGET_CATEGORY,WEDDING_COST,COST_PAYMENT,PAYMENT_SCHEDULE,PROVIDER_ITEM,QUOTE_REQUEST,PLAN_PROVIDER_LINK,MEMBER_ITEM,PLAN_INVITE,PLAN,SECTION}`, `ContributionAction{CREATED,UPDATED,DELETED,ASSIGNED,UNASSIGNED,COMPLETED,REOPENED,STATUS_CHANGED,PAYMENT_RECORDED,PAYMENT_REVERSED,INVITED,SECTION_REVOKED,MEMBER_LEFT,MEMBER_REMOVED,LEGACY_CAPTURED}`, `ContributionProvenance{RUNTIME,REVOCATION_SNAPSHOT,LEGACY_EXPLICIT}`, `ContributionPermission{MANAGE_TASKS,MANAGE_GUESTS,VIEW_MONEY,MANAGE_MONEY,MANAGE_PROVIDERS,MANAGE_MEMBERS,MANAGE_PLAN}`, `PlanInviteDeliveryStatus{UNKNOWN,PENDING,DELIVERED,UNCERTAIN,UNAVAILABLE}`.

| Model | Key fields | Relations | Unique |
|---|---|---|---|
| SharedMember | weddingPlanId, userId, role(VIEWER), canViewMoney, canEditPlan, canManageTasks, canManageGuests, canManageProviders, canInviteMembers, canManageMoney (all default false), receiveNotifications(true), authorityVersion | plan (Restrict), user (Cascade), ContributorTenure? | (weddingPlanId, userId) |
| ContributorHistoryScope (uuid) | weddingPlanId?, status, historyCoverageStartsAt, archivedAt, deletedAt | plan (SetNull), tenures, events | weddingPlanId |
| ContributorTenure (uuid) | historyScopeId, actorUserId?, actorReference(char64), sharedMemberId?, joinedAt, trackingStartedAt, endedAt, endReason, roleAtTrackingStart, roleAtEnd | scope, user, member | sharedMemberId; (id, historyScopeId) |
| ContributionEvent (uuid) | historyScopeId, contributorTenureId, section, entityType, entityId, action, snapshot(Json), snapshotHash, dedupeKey, eventFingerprint, provenance, requiredPermission, authorityVersion, occurredAt, capturedAt | scope, tenure | (contributorTenureId, dedupeKey) |
| PlanInvite | weddingPlanId, inviterUserId, inviteeUserId?, name, phone, normalizedPhone, email, tokenHash, role, 7 can* flags, receiveNotifications, expiresAt, acceptedAt, declinedAt, revokedAt, deliveryStatus, deliveryAttemptedAt | plan, inviter, invitee, OtpCode[] | tokenHash |

### finance.prisma
Enums: `WeddingCostStatus{OPEN,PARTIALLY_PAID,PAID,CANCELLED}`, `CostPaymentType{PAYMENT,REVERSAL}`, `PaymentScheduleStatus{PENDING,PAID,CANCELLED}`, `FundingSourceKind{SAVINGS,FAMILY_SUPPORT,GIFT,LOAN,OTHER}`, `FundingSourceStatus{PLEDGED,RECEIVED}`, `LoanRepaymentStatus{PLANNED,PAID,CANCELLED}`, `CostPayer{GROOM,BRIDE,FAMILY,SHARED,OTHER}`.

| Model | Key fields | Relations | Unique |
|---|---|---|---|
| BudgetCategory | weddingPlanId, name, normalizedName, allocatedAmount? | plan, costs | (plan, normalizedName); (id, plan) |
| WeddingCost | weddingPlanId, budgetCategoryId, providerId?, quoteOfferId?, title, partyName, partyPhone, totalAmount, paidAmount, agreementDate, status, payer, payerName, note, privateToUserId? | plan, category (same-plan composite FK), provider (SetNull), quoteOffer, payments, schedules, receipts | quoteOfferId |
| CostPayment | weddingCostId, amount, entryType, paidAt, method, note, paymentScheduleId?, reversalOfId? | cost, schedule (same-cost FK), reversalOf/reversedBy self, receipts | reversalOfId; (id, cost); (reversalOfId, cost) |
| CostReceipt | weddingCostId, costPaymentId?, storageKey, contentType, byteSize, uploadedByUserId | cost, payment (same-cost FK) | storageKey |
| PaymentSchedule | weddingCostId, amount, dueDate, paidAt, status, note | cost (Cascade), payments | (id, cost) |
| FundingSource | weddingPlanId, kind, sourceName, sourcePhone, amount, status, receivedAt, note | plan, repayments | (id, plan) |
| LoanRepayment | fundingSourceId, amount, dueDate, paidAt, status, note | fundingSource (Cascade) | – |

### tasks.prisma
Enums: `WeddingTaskStatus{TODO,IN_PROGRESS,DONE,CANCELLED}`, `WeddingTaskPriority{LOW,MEDIUM,HIGH,URGENT}`.

| Model | Key fields | Relations | Unique |
|---|---|---|---|
| WeddingTask | weddingPlanId, assigneeUserId?, responsibleName/Phone/Source, title, description, dueDate, taskCategory, reminderAt, status, priority, privateToUserId? | plan, assignee (SetNull), checklistItems | – |
| WeddingTaskChecklistItem | taskId, title, isDone, sortOrder | task (Cascade) | – |

### guests.prisma
Enums: `GuestSide{GROOM,BRIDE,FAMILY,FRIEND,OTHER}`, `GuestStatus{INVITED,CONFIRMED,DECLINED,PENDING}`, `GuestInvitationStatus{NOT_SENT,SENT,DELIVERED}`, `GuestAttendanceStatus{PENDING,CONFIRMED,DECLINED}`.

| Model | Key fields | Relations | Unique |
|---|---|---|---|
| Guest | weddingPlanId, groupId?, name, normalizedName, phone, normalizedPhone, side, status, invitationStatus, attendanceStatus, seatsCount(1), companionsCount(0), notes, rsvpTokenHash?, respondedAt | plan, group (SetNull) | rsvpTokenHash; (plan, normalizedPhone) |
| GuestGroup | weddingPlanId, name, notes, sortOrder | plan, guests | (plan, name) |

### marketplace.prisma (all uuid)
Enums: `ProviderStatus{PENDING,ACTIVE,NEEDS_CHANGES,SUSPENDED,REJECTED}`, `ReviewStatus{PUBLISHED,HIDDEN,PENDING}`, `QuoteRequestStatus{SENT,VIEWED,RESPONDED,ACCEPTED,REJECTED,CANCELLED}`, `QuoteOfferStatus{PENDING,ACCEPTED,REJECTED,WITHDRAWN}`, `PlanProviderLinkStatus{ACTIVE,ARCHIVED}`, `BookingStatus{REQUESTED,CONFIRMED,DECLINED,CANCELLED}`, `BookingParty{CUSTOMER,PROVIDER}`.

| Model | Key fields | Relations | Unique |
|---|---|---|---|
| Provider | userId? (null = unclaimed admin listing), cityId, primaryCategoryId, businessName, ownerName, phone, whatsapp, email, description, address, lat/lng, logoUrl, coverUrl, status(PENDING), reviewNote, reviewedAt/ById, verifiedAt/ById, isFeatured, ratingAverage, ratingCount | user, city, category, services, packages, favorites, reviews, quotes, offers, planLinks, costs, conversations, bookings, blockedDates, profileViewDays | userId |
| ProviderService | providerId, categoryId, title, description, basePrice, priceUnit, currency, priceUpdatedAt, cityId, isActive, isFeatured | provider, category, city, images, packages, quotes | – |
| ProviderServiceImage | serviceId, imageUrl, altText, sortOrder | service | – |
| ProviderPackage | providerId, serviceId?, title, description, price, currency, items(Json), isActive | provider, service | – |
| FavoriteProvider | userId, providerId | user, provider | (userId, providerId) |
| ProviderReview | userId, providerId, rating, comment, status(PUBLISHED) | user, provider | (userId, providerId) |
| QuoteRequest | userId, weddingPlanId?, providerId, serviceId, eventDate, location, cityId, guestCount, contactName, contactPhone, contactNormalizedPhone, message, budgetMin/Max, status, accepted/rejected/cancelledAt, conversationId (required) | user, plan (SetNull), provider, service, city, offers, providerLinks, conversation (Restrict), conversationEvents, booking? | – |
| QuoteOffer | quoteRequestId, providerId, title, message, amount, currency, validUntil, status | quote, provider, links, costs, events, bookings | – |
| PlanProviderLink | weddingPlanId, providerId, quoteRequestId?, quoteOfferId?, status | plan, provider, quote, offer | (plan, provider) |
| Booking | quoteRequestId, quoteOfferId?, providerId, eventDate(Date), status, requestedByUserId, cancelledBy, note, confirmed/declined/cancelledAt | quote, offer, provider | quoteRequestId |
| ProviderBlockedDate | providerId, date | provider | (providerId, date) |
| ProviderProfileViewDay | (providerId, day) PK, views | provider | – |

### messaging.prisma
Enums: `ConversationScope{PLAN,ACCOUNT}`, `ConversationEventType{QUOTE_REQUEST_CREATED,QUOTE_REQUEST_CANCELLED,QUOTE_REQUEST_REJECTED,QUOTE_OFFER_RECEIVED,QUOTE_OFFER_REJECTED,QUOTE_OFFER_ACCEPTED}`, `ConversationReportStatus{OPEN,REVIEWED,DISMISSED}`.

| Model | Key fields | Relations | Unique |
|---|---|---|---|
| Conversation | scope, weddingPlanId?, accountRequesterUserId?, providerId, createdByUserId, lastActivityAt, closedAt, customerSideBlockedAt/ById, providerSideBlockedAt | plan, requester, provider, quotes, participants, messages, events, reports | – |
| ConversationParticipant | conversationId, userId, joinedAt, revokedAt, lastReadAt, mutedAt | conversation, user | (conversationId, userId) |
| ConversationEvent | conversationId, quoteRequestId?, quoteOfferId?, actorUserId?, type, occurredAt, dedupeKey, data | conversation, quote, offer, actor | dedupeKey |
| ChatMessage | conversationId, senderUserId, body, editedAt, deletedAt | conversation, sender, attachments | – |
| ChatAttachment | messageId, storageKey, contentType, byteSize | message | – |
| ConversationReport | conversationId, reporterUserId, reason, status | conversation, reporter | (conversationId, reporterUserId) |

### notifications.prisma
Enums: `NotificationType` (23, see §3), `NotificationPriority{LOW,NORMAL,HIGH,URGENT}`, `PushPlatform{ANDROID,IOS}`.

| Model | Key fields | Relations | Unique |
|---|---|---|---|
| NotificationPreference (uuid) | userId, pushEnabled(false), smsEnabled, whatsappEnabled, emailEnabled, taskRemindersEnabled(true), paymentRemindersEnabled(true), providerMessagesEnabled(true) | user | userId |
| PushInstallation | userId, fid(≤200), platform, enabled, lastSeenAt | user | fid |
| Notification | userId, weddingPlanId?, type, priority, title, body, entityType, entityId, routeTarget, data, dedupeKey, readAt, archivedAt | user, plan (SetNull) | dedupeKey |

### catalog.prisma (uuid)
Enum: `AdministrativeLocalityType{AREA,ISOLATION,NEIGHBORHOOD,ZONE}`.

| Model | Key fields | Unique |
|---|---|---|
| City | nameAr, nameEn, countryCode(YE), isActive, sortOrder | (nameAr, countryCode) |
| Governorate | code, nameAr, nameEn, lat/lng, isActive, sortOrder | code |
| District | governorateId, code, nameAr, nameEn, … | code; (governorateId, nameAr) |
| AdministrativeLocality | districtId, parentId? (tree), code, type, nameAr, … | code; (districtId, type, nameAr) |
| ReferenceCatalog | key, nameAr, description, version, isActive | key |
| ReferenceCatalogItem | catalogId, key, currentRevision, publishedRevision | (catalogId, key) |
| ReferenceCatalogItemRevision | itemId, revision, groupKey, groupNameAr, groupSubtitleAr, nameAr, nameEn, icon, sortOrder, showForGroom/Bride/Customer/Provider, isRecommended, isActive, metadata | (itemId, revision) |
| ProviderCategory | nameAr, nameEn, slug, icon, showForGroom, showForBride, isActive, sortOrder | slug |

### backoffice / media / platform

| Model | Key fields | Unique |
|---|---|---|
| AdminAuditLog | eventId, actorUserId, actorAdminRole (`AdminRole{SUPER_ADMIN,OPERATIONS,MODERATOR,SUPPORT}`), action, method, route, targetId, phase (`AdminAuditPhase{ATTEMPT,SUCCEEDED,FAILED}`), statusCode, errorType, requestId | (eventId, phase) |
| MediaUploadTicket | key(PK), userId?, purpose, contentType, declaredByteSize, verifiedByteSize, status (`MediaUploadStatus{PENDING,VERIFYING,VERIFIED,DELETE_PENDING,DELETED}`), expiresAt, verifiedAt, consumedAt, consumedByType, consumedById, deletedAt | – |
| IdempotencyKey | userId, key, method, path, requestHash, response, completedAt, expiresAt | (userId, key) |
| OutboxEvent | type, aggregateType, aggregateId, payload, status (string PENDING/PROCESSING/PROCESSED/FAILED), attemptCount, nextAttemptAt, lockedAt, lockedBy, processedAt, lastError | – |

Model count by file: identity 9, planning 1, collaboration 5, finance 7, tasks 2, guests 2, marketplace 12, messaging 6, notifications 3, catalog 8, backoffice 1, media 1, platform 2 = **59 models**; 47 enums.

---

## 3. Background jobs, outbox, notification types

### 3.1 Schedulers (`@nestjs/schedule`)

| Class (file) | Trigger | Job |
|---|---|---|
| NotificationRemindersScheduler (notifications/notification-reminders.scheduler.ts:11) | `@Cron('15 * * * *')` hourly | `generateDueNotifications()` under advisory lock (`tryLockDueScheduler`): tasks due ≤7 days / overdue, payment schedules due/overdue, loan repayments, budget category exceeded, wedding countdown (milestones 30/7/1 days, `plan-reminders.ts:16`); Riyadh-day boundaries; respects NotificationPreference reminder flags; contributor-scoped recipients |
| BookingRemindersScheduler (marketplace/booking-reminders.scheduler.ts:12) | `@Cron('25 * * * *')` hourly | Remind both sides of CONFIRMED bookings 7 and 1 days before (`BOOKING_REMINDER_MILESTONES`, booking-notifications.ts:105) |
| OutboxWorker.drainOnce (platform/outbox/outbox.worker.ts:27) | `@Interval(1s)` | Claim & dispatch OutboxEvent batch; retry backoff 1s·2^n capped 5 min; max 8 attempts → FAILED |
| OutboxWorker.refreshMetrics (:41) | `@Interval(15s)` | Outbox gauges |
| OutboxCleanupScheduler (platform/outbox/outbox-cleanup.scheduler.ts:14) | every 6 h | Purge processed receipts |
| IdempotencyCleanupScheduler (platform/idempotency/idempotency-cleanup.scheduler.ts:14) | hourly | Delete expired IdempotencyKey |
| AuthChallengeCleanupScheduler (modules/identity/internal/auth/auth-challenge-cleanup.scheduler.ts:14) | hourly | Expired OTP/admin challenges/refresh state |
| OtpDispatchQuotaCleanupScheduler (…/otp-dispatch-quota-cleanup.scheduler.ts:15) | hourly | Expired quota windows |
| LoginThrottleCleanupScheduler (…/login-throttle-cleanup.scheduler.ts:15) | hourly | Expired throttle windows |
| MediaUploadCleanupScheduler (media/media-upload-cleanup.scheduler.ts:19) | every 5 min | Delete abandoned/unconsumed uploads |

No BullMQ/queues; durable async = `OutboxEvent` table.

### 3.2 Outbox event types (`platform/outbox/outbox.constants.ts`, dispatcher `outbox.dispatcher.ts`)

| Type | Effect |
|---|---|
| CONVERSATION_MESSAGE_AVAILABLE | Socket `conversation:message-available` to conversation room |
| CONVERSATION_ACTIVITY_AVAILABLE | `conversation:activity-available` (+`conversation:event` for EVENT kind) |
| NOTIFICATION_CREATED | `notification:available` to `user:{id}` room |
| PUSH_NOTIFICATION_REQUESTED | FCM push via `firebase-push.client.ts` |
| CONVERSATION_ACCESS_REVOKED | `conversation:permission-revoked` + socketsLeave |
| USER_SESSIONS_REVOKED | disconnect all sockets of user |
| SESSION_REVOKED | disconnect sockets of session |

### 3.3 NotificationType enum (23) and producers

| Type | Producer | Push? |
|---|---|---|
| QUOTE_REQUEST_SUBMITTED | marketplace/quote-notifications.ts | no |
| QUOTE_OFFER_RECEIVED | quote-notifications.ts | yes |
| QUOTE_ACCEPTED | quote-notifications.ts | no |
| QUOTE_REJECTED | quote-notifications.ts | no |
| TASK_ASSIGNED | tasks/tasks.service.ts | yes |
| TASK_DUE_SOON / TASK_OVERDUE | notifications.service.ts (cron) | yes |
| PAYMENT_SCHEDULE_DUE_SOON / _OVERDUE | notifications.service.ts (cron) | no |
| LOAN_REPAYMENT_DUE_SOON / _OVERDUE | plan-reminders.ts (cron) | no |
| BUDGET_CATEGORY_EXCEEDED | plan-reminders.ts | no |
| WEDDING_COUNTDOWN | plan-reminders.ts (cron) | yes |
| SHARING_INVITATION / SHARING_INVITE_ACCEPTED / SHARING_INVITE_DECLINED | collaboration sharing.service.ts | no |
| CHAT_MESSAGE_RECEIVED | conversations.service.ts | yes |
| BOOKING_UPDATED | marketplace/booking-notifications.ts (+ reminders) | yes |
| GUEST_RESPONDED | guests/guest-rsvp.service.ts | no |
| GENERAL | admin/admin.service.ts | no |
| SHARING_UPDATED, PLAN_UPDATED, SYNC_REQUIRED | **no producer found** (enum only) | – |

Push allow-list: `push/push-notification.policy.ts` (`PUSH_NOTIFICATION_TYPES`); push copy is generic Arabic text (no content leakage).

---

## 4. Permission model

### 4.1 Account level
- `User.role`: USER / ADMIN / PROVIDER; `adminRole` (SUPER_ADMIN/OPERATIONS/MODERATOR/SUPPORT); `appRole`: WEDDING_USER / PROVIDER; `status` DISABLED blocks sessions.
- Session scope in JWT: `application` (JwtAuthGuard) vs `admin` (AdminGuard, requires MFA). Admin perms §1.14.
- Provider capability is not a role check: it is ownership of a `Provider` row + `ProviderStatus` (`modules/marketplace/public/provider-access-policy.ts:19-45`): ACTIVE → FULL; PENDING/NEEDS_CHANGES → LIMITED (profile editable, no operations); SUSPENDED/REJECTED → READ_ONLY.
- Contexts: `plan:{planId}:{role}` and `provider:{providerId}` (`modules/identity/public/context-key.ts:3,10`), listed by `contexts.service.ts`.

### 4.2 Plan roles and default flags (`modules/collaboration/internal/plan-permissions.ts:25-75`)

| Role | canViewMoney | canEditPlan | canManageTasks | canManageGuests | canManageProviders | canInviteMembers | canManageMoney | seesWholePlan |
|---|---|---|---|---|---|---|---|---|
| OWNER (reserved; plan.ownerUserId) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| GROOM / BRIDE (partner) | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ | ✓ | ✓ |
| FAMILY | ✗ | ✗ | ✓ | ✓ | ✗ | ✗ | ✗ | ✗ |
| HELPER / CONTRIBUTOR | ✗ | ✗ | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ |
| MANAGER | ✗ | ✓ | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ |
| EDITOR | ✗ | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ | ✗ |
| FINANCE_MANAGER | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ | ✓ | ✗ |
| VIEWER | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |

`receiveNotifications` defaults true. Defaults apply on **invite** creation (`sharing.service.ts:2353 permissionDataForCreate`); **direct member add** defaults every flag to false regardless of role (`:2373 permissionDataForDirectMemberCreate`). Any DTO flag overrides; `canManageMoney=true` forces `canViewMoney=true`. Stored flags are authoritative at runtime (`permission.service.ts:369-402`: owner → true, else `sharedMember.<flag>`; `canManagePlan`↔`canEditPlan`, `canManageMembers`↔`canInviteMembers`).

Grant rules (`sharing.service.ts`):
- `assignableRole` rejects OWNER (:2345).
- `assertPermissionCeiling` (:2410): non-owner may not grant any flag they lack (compares effective permissions, 400 `Cannot grant permission above inviter ceiling`).
- `assertMemberWithinActorScopeInTransaction` (:2086): non-owner can update/remove only members they created (MEMBER_ITEM CREATED contribution).
- Revocations snapshot contributor history and revoke pending invites exceeding new authority (:1243-1260).
- Invite expiry default 14 days (:2485); reissue has a cooldown.

### 4.3 Access checks (`modules/collaboration/internal/permission.service.ts`)
- Context: `{plan, isOwner = plan.ownerUserId===me, sharedMember}` (:56-73). Non-member → 404 (not 403).
- `assertPlanReadable*` owner or member; `assertTaskManageable*` TASKS; `assertGuestManageable*` GUESTS; `assertMoneyReadable*` canViewMoney; `assertMoneyManageable*` canManageMoney; `assertProviderManageable*` canManageProviders; `assertProviderAndMoneyManageableInTransaction` both (offer accept); `assertMemberManageable*` canInviteMembers; `assertPlanManageable*` canEditPlan. Write variants lock plan row (SHARE/UPDATE) then membership FOR SHARE.
- Live re-check: `livePlanAuthorizationWhere` / `liveAuthorizationFilter` (port :57, service ~:425) re-evaluate ownership/membership+flags in the same snapshot as the final read → `NEVER_MATCHING_ROW_FILTER`.
- Archived plan writes → 409 `PLAN_ARCHIVED_READ_ONLY` (port :86).

### 4.4 seesWholePlan (`modules/collaboration/public/collaboration-permission.port.ts:28-41`)
```ts
isPlanPartnerRole(role) = role === GROOM || role === BRIDE
seesWholePlan(ctx) = ctx.isOwner || (ctx.sharedMember != null && isPlanPartnerRole(ctx.sharedMember.role))
```
"Contributor" in services = `!seesWholePlan(ctx) && ctx.sharedMember` (e.g. tasks.service.ts:836, guests.service.ts:686, timeline.service.ts:74). Contributor scope = entity ids from the actor's `ContributionEvent`s (`contributor-scope.service.ts:26-61`, default actions CREATED/COMPLETED/PAYMENT_RECORDED).

### 4.5 Item-level filtering rules

| Area | Rule | file:line |
|---|---|---|
| Tasks list/read | Contributor: no TASKS → [] / 403 `TASK_PERMISSION_REVOKED`; else only tasks they CREATED/COMPLETED or are assigned to | tasks/tasks.service.ts:213-258, 840-854 |
| Tasks mutate | Others' private task → 404; contributor only assigned-to-me or own CREATED/COMPLETED | tasks.service.ts:856-876 |
| Private tasks | `isPrivate` only when seesWholePlan (403 `TASK_PRIVACY_NOT_ALLOWED`); visibility `privateToUserId IN (null, me)` | tasks.service.ts:967-981; modules/tasks/infrastructure/task-work.repository.ts:27 |
| Shift due dates | seesWholePlan only | tasks.service.ts:205 |
| Guests list/read | Contributor: no GUESTS → []/404; else own CREATED guests; private details (phone etc.) need GUESTS | guests/guests.service.ts:140-215, 690-745 |
| Guests/groups mutate | Contributor only own CREATED guest/group | guests.service.ts:746-780 |
| RSVP link | Contributor only own CREATED guest | guests/guest-rsvp.service.ts:142 |
| Budget categories | Contributor sees/edits only categories they CREATED (and those of own costs) | budget-categories/budget-categories.service.ts:139, 213, 355-390 |
| Costs/payments/schedules/receipts | Contributor: only costs they CREATED/COMPLETED/PAYMENT_RECORDED; others' private costs always hidden (404); private cost creation only seesWholePlan (403 `COST_PRIVACY_NOT_ALLOWED`) | wedding-costs/wedding-costs.service.ts:1664-1735; modules/finance/infrastructure/cost-privacy.repository.ts:16,41 |
| Money summary | Contributor totals limited to own contributions; funding only for owner | money/money-summary.service.ts:67, 328-332 |
| Funding sources & loans | Owner only (partners excluded); non-owner GET → [], writes → 404 | money/funding-sources.service.ts:107, 322-327 |
| Quote requests/offers | Contributor: only QUOTE_REQUEST contributions they own; budget fields need canViewMoney, contact needs PROV | marketplace/marketplace-contributor-quote-scope.ts:35-110; marketplace.service.ts:460, 855; quote-offer-acceptance.ts:88; quote-offer-rejection.ts:77; quote-request-cancellation.ts:96-115 |
| Bookings | No PROV → []; contributor only bookings of quotes they requested | marketplace/bookings.service.ts:209-213, 391-419 |
| Timeline | Tasks scoped as above (need TASKS), schedules need canViewMoney + own cost scope | timeline/timeline.service.ts:69-90 |
| Dashboard | Contributor counts scoped; money totals only canViewMoney && seesWholePlan | dashboard/dashboard.service.ts:130, 292, 336 |
| Assistant | seesWholePlan only | dashboard/assistant/assistant.service.ts:106, 137 |
| Notifications | Task/payment-schedule notifications hidden for contributors unless entity in scope | notifications/notifications.service.ts:1583-1600 |
| Members list | Non-owner with MEMBERS sees members they created (plus self) | modules/collaboration/internal/sharing.service.ts:457-470 |
| Conversations | Any member with canManageProviders sees all plan conversations (**no** contributor scoping); money visibility by canViewMoney | conversations/conversations.service.ts:823-874, 876-897 |

---

## 5. Websocket / realtime

- Socket.IO gateway `ConversationsGateway`, **namespace `/chat`** (`conversations/conversations.gateway.ts:53`), CORS = configured origins, credentials. Redis adapter (`platform/redis/redis-io.adapter.ts`) when `REDIS_URL` set (multi-replica fan-out).
- Auth on connect (:80): JWT from `handshake.auth.token` or `Authorization` header; requires `sub`, `exp`, scope `application`; identity checks user active/phone-verified/live session. Joins `user:{id}` and `session:{sid}` rooms; emits `chat:ready {userId}`. Socket auto-disconnects at token expiry (:121-155). Each message re-checks session liveness.
- Client → server events:

| Event | Payload | Behaviour |
|---|---|---|
| `conversation:join` | {conversationId} | authorize, join `conversation:{id}`, re-authorize after join |
| `conversation:message` | {conversationId, body, attachments?} | per-socket 20 msg/60 s limit; same as POST messages |
| `conversation:read` | {conversationId} | mark read |

- Server → client events (`conversations/conversation-realtime.publisher.ts`): `conversation:message`, `conversation:read`, `conversation:event`, `conversation:activity-available`, `conversation:message-available`, `conversation:permission-revoked`, `notification:available`; forced `disconnectSockets` on user/session revocation. Most are driven by the outbox (§3.2).
- Room naming single source: `conversations/conversation-rooms.ts`.

---

## 6. Observations (factual, for follow-up)

1. No global `/api/v1` prefix; admin API lives at `/admin/*`, so proxies/CORS must route two roots.
2. Duplicate endpoints: `GET /api/v1/me` = `GET /api/v1/auth/me`; quote read/cancel exist under both `/api/v1/me/quote-requests/:id[/cancel]` and `/api/v1/quote-requests/:id[/cancel]`.
3. `POST /api/v1/account-deletions/status` is unauthenticated (throttled 10/min), keyed by `userId + clientRequestId`.
4. Conversations do not apply contributor (seesWholePlan) scoping while quotes/bookings do — a HELPER with canManageProviders can read every provider thread of the plan.
5. Partners (GROOM/BRIDE) are excluded from funding sources/loans (owner-only), though they otherwise see the whole plan.
6. Direct member add (`POST …/members`) ignores role defaults (all flags false unless passed); invites apply role defaults.
7. Legacy roles VIEWER/EDITOR/FINANCE_MANAGER/CONTRIBUTOR/MANAGER remain in enum and defaults.
8. NotificationType `SHARING_UPDATED`, `PLAN_UPDATED`, `SYNC_REQUIRED` have no producer.
9. No wedding sub-event (henna/zaffa) entity, no sync endpoint beyond one-shot `onboarding/import-local`, no refund entity (reversal entries only).
10. `POST …/invites/:inviteId/reissue` takes `UpdateSharedMemberDto` (can change role/flags on reissue).
