# API Contract

This document is the route-level source of truth for the current Aarast backend contract. Other Markdown files should link here instead of copying endpoint lists.

Current documentation snapshot: 2026-07-06.

Source status:

- Backend source contains the Wedding Financial OS API surface plus provider-reference and quote-lead support.
- Archived backend reports record a 2026-06-19 local PASS for backend completion
  smoke and a later 2026-06-20 Docker runtime/source mismatch in dashboard
  summary smoke. Current backend risks are summarized in
  `docs/backend/STATUS_AND_RISKS.md`.
- Provider/quote routes are planning and lead workflows only. They are not paid marketplace, payment, deposit, or confirmed booking flows.

## Base URL

Local backend example:

```text
http://127.0.0.1:3115
```

The current backend does not configure a global `/api` prefix. Flutter clients should call routes directly from the base URL, for example `GET /health` and `POST /auth/login`.

Health endpoints have distinct orchestration semantics:

- `GET /live` checks only that the HTTP process responds.
- `GET /health` is a compatibility alias of `/live`.
- `GET /ready` checks PostgreSQL and required Redis/media dependencies. It
  returns `503` with redacted dependency states when the instance must not
  receive traffic.

## Common Rules

- JSON request and response bodies are used for API routes.
- Protected routes require `Authorization: Bearer <accessToken>`.
- Access JWTs default to 15 minutes and are renewed through rotating refresh
  sessions.
- Private resources use ownership and sharing checks.
- Some unauthorized private-resource access is intentionally returned as not found style behavior.
- `passwordHash` is never returned.
- Owner user objects are not exposed in WeddingPlan responses.
- Financial visibility is private by default and controlled by owner access or explicit sharing permissions.
- Direct legacy routes and `/api/v1` aliases coexist for many current modules. Existing mobile consumers may continue using direct routes while new rebuild work should prefer the documented `/api/v1` route where present.

## Auth

### `POST /auth/register`

Registration is a two-call verified-phone flow. The first call sends a
`REGISTER` OTP and does not create a User or issue a session.

Initial request:

```json
{
  "name": "Rashad",
  "phone": "+967700000000",
  "email": "optional@example.com",
  "password": "secret123"
}
```

Pending response:

```json
{
  "registrationPending": true,
  "phone": "+967700000000",
  "purpose": "REGISTER",
  "expiresAt": "2026-07-10T12:00:00.000Z",
  "delivery": "WHATSAPP"
}
```

The mobile client keeps the registration draft in memory and sends it to
`POST /auth/register/complete` with the six-digit `otpCode`. Production
responses never echo the code.

Completion request:

```json
{
  "name": "Rashad",
  "phone": "+967700000000",
  "email": "optional@example.com",
  "password": "secret123",
  "otpCode": "123456"
}
```

Verified response:

```json
{
  "accessToken": "jwt-token",
  "user": {
    "id": "user_id",
    "name": "Rashad",
    "phone": "+967700000000",
    "email": "optional@example.com",
    "role": "USER",
    "status": "ACTIVE",
    "createdAt": "2026-06-04T00:00:00.000Z",
    "updatedAt": "2026-06-04T00:00:00.000Z"
  }
}
```

The OTP is consumed atomically in the same serializable transaction that
creates the verified User. A wrong, expired, already-consumed, or concurrently
replayed code creates no account and issues no access or refresh token.
The initial response is generic; phone/email conflicts are checked only after
valid phone proof so the start endpoint is not an account-enumeration oracle.

### `POST /auth/login`

Request:

```json
{
  "phone": "+967700000000",
  "password": "secret123"
}
```

Response shape matches register.

Password login, refresh, and protected JWT routes reject accounts whose
`phoneVerifiedAt` is null. Existing unverified accounts must prove phone
ownership through OTP (or a password-reset OTP) before receiving a session.

### Refresh Sessions

Register, password login, and OTP login return an access token, opaque refresh
token, and refresh expiry. Access JWTs default to 15 minutes; refresh sessions
expire after 30 days and are stored as hashes.

- `POST /auth/refresh` rotates one valid refresh token and returns a new access
  and refresh pair. Reuse of a revoked/expired token is rejected.
- `POST /auth/logout` revokes the supplied refresh token; when omitted for an
  authenticated user it revokes all of that user's sessions.
- `POST /auth/logout-all` revokes all active refresh sessions for the
  authenticated user.

The mobile client stores both tokens in secure storage and retries one failed
request once after a successful refresh. Auth endpoints do not recursively
trigger refresh.

### `GET /auth/me`

Requires JWT. Returns the safe current user object without `passwordHash`.

### Password reset

- `POST /auth/password-reset/request` — body `{ phone }`. Issues a
  `RESET_PASSWORD` OTP through the same OTP channel policy as
  `/auth/otp/request`. The response never reveals whether the phone belongs
  to an account.
- `POST /auth/password-reset/confirm` — body `{ phone, code, newPassword }`.
  Consumes the OTP, sets the new password (min 6 chars), and revokes every
  refresh token for the account so old sessions die with the old password.
  Unknown phones and wrong codes return the same generic
  `OTP code is invalid or expired` error.

Additional current auth/profile routes:

- `POST /auth/otp/request`
- `POST /auth/otp/verify`
- `PATCH /users/me`
- `GET /users/lookup?weddingPlanId=<planId>&phone=<phone>`
  - requires an authenticated owner/member with permission to invite members
- `GET /users/me/settings`
- `PATCH /users/me/settings`
- `GET /me`
- `GET /api/v1/me`

OTP/profile routes are account and settings helpers. They do not add payment, booking, financing, AI, or chat behavior.

`REGISTER` codes are completed only through `POST /auth/register/complete`;
the generic verify endpoint cannot consume a registration code without the
registration details. In production `AUTH_OTP_MODE=whatsapp` uses an approved Meta
authentication template and the API refuses to boot when the channel is
incompletely configured.

### Profile image upload

Authenticated profile images use the existing account profile field and the
media upload flow:

1. `POST /media/uploads/presign` with `purpose: "user-avatar"`, the file name,
   MIME type, and byte size.
2. Upload the bytes to the returned short-lived signed `uploadUrl`.
3. `PATCH /users/me` with the returned `publicUrl` as `avatarUrl`.

Profile images accept JPEG, PNG, or WebP and must not exceed 5 MB. The mobile
client updates its cached safe user only after both the upload and profile
update succeed. Media storage credentials remain server-side and are never
returned to the client.

## Wedding Plans

Protected routes:

- `POST /wedding-plans`
- `GET /wedding-plans`
- `GET /wedding-plans/my`
- `GET /wedding-plans/active`
- `POST /wedding-plans/:id/set-active`
- `GET /wedding-plans/:id`
- `PATCH /wedding-plans/:id`
- `PATCH /wedding-plans/:id/archive`

Current `/api/v1/wedding-plans` aliases exist for the same create/list/my/active/set-active/get/update/archive surface.

Create request:

```json
{
  "title": "Wedding Plan",
  "city": "Sanaa",
  "weddingDate": "2026-12-25T00:00:00.000Z",
  "estimatedBudget": "1500000.00",
  "currency": "YER"
}
```

Response:

```json
{
  "id": "plan_id",
  "ownerUserId": "user_id",
  "title": "Wedding Plan",
  "city": "Sanaa",
  "weddingDate": "2026-12-25T00:00:00.000Z",
  "estimatedBudget": "1500000.00",
  "currency": "YER",
  "status": "PLANNING",
  "createdAt": "2026-06-04T00:00:00.000Z",
  "updatedAt": "2026-06-04T00:00:00.000Z"
}
```

Creating a WeddingPlan makes it the authenticated user's active plan. Selecting
an existing plan should use `POST /wedding-plans/:id/set-active` or the `/api/v1`
alias before opening plan-scoped dashboards.

Shared members can read basic plan info. Updating or archiving requires owner access or manager-style sharing permission.

## Onboarding And Active Plan

Protected routes:

- `POST /onboarding/complete`
- `POST /api/v1/onboarding/complete`
- `GET /wedding-plans/active`
- `GET /api/v1/wedding-plans/active`
- `POST /wedding-plans/:id/set-active`
- `POST /api/v1/wedding-plans/:id/set-active`

Onboarding completion creates real server-owned plan data, selected budget categories, and active-plan state for an authenticated user. Guest-first mobile drafts remain a mobile/local strategy until the user reaches an account gate.

## WeddingPlan Dashboard Summary

Protected routes:

- `GET /dashboard/home`
- `GET /wedding-plans/:planId/dashboard-summary`
- `GET /api/v1/wedding-plans/:planId/dashboard-summary`

The dashboard summary powers the mobile Home / Today Center. Existing count and money fields remain stable, and the response may also include source-backed detail arrays:

- `dataScope: "ACCOUNT_BACKED"` and `accountBacked: true` to distinguish server/account-backed data from local guest preview data.
- `incompleteGuestsCount`: persisted guests missing basic planning contact/name fields.
- `quoteStatusBreakdown`: `pending`, `offered`, `accepted`, and `rejectedClosed` counts.
- `acceptedProvidersCount`: stable alias for accepted/active `PlanProviderLink` count.
- `financialWarnings`: simple computable warnings such as budget exceeded or installment due soon.

- `importantItems`: actionable task/installment/provider cards for "الأهم اليوم".
- `planProviders`: providers actually linked to the current WeddingPlan.
- `importantNotifications`: latest user-owned notifications for this WeddingPlan.
- `generatedAt`: server timestamp used by the mobile sync/status copy.

Financial installment details appear only when the current user has the required
debt/financial permission. Notifications are always scoped to the authenticated
user. Provider cards are planning/reference data only and do not imply paid
booking, deposits, payment status, loans, credit, financing, or AI.

## Notifications

Protected routes:

- `GET /notifications`
- `GET /notifications/unread-count`
- `GET /notifications/:id`
- `PATCH /notifications/:id/read`
- `PATCH /notifications/read-all`
- `DELETE /notifications/:id`

The same notification routes are also exposed under `/api/v1/notifications`.

`GET /notifications`, `GET /api/v1/notifications`, `GET /notifications/unread-count`, and `GET /api/v1/notifications/unread-count` accept an optional `weddingPlanId` query parameter. Notifications are always owned by the authenticated user. The backend may create idempotent task and installment due notifications while listing/counting notifications.

Notification response:

```json
{
  "id": "notification_id",
  "userId": "user_id",
  "weddingPlanId": "plan_id",
  "type": "TASK_DUE_SOON",
  "title": "مهمة قريبة",
  "body": "Confirm hall - تستحق قريباً (20/12/2026).",
  "data": {
    "taskId": "task_id",
    "weddingPlanId": "plan_id"
  },
  "readAt": null,
  "createdAt": "2026-06-18T00:00:00.000Z",
  "updatedAt": "2026-06-18T00:00:00.000Z"
}
```

Unread count response:

```json
{ "count": 3 }
```

## Budget Categories

Protected routes:

- `POST /wedding-plans/:weddingPlanId/budget-categories`
- `GET /wedding-plans/:weddingPlanId/budget-categories`
- `PATCH /budget-categories/:id`
- `DELETE /budget-categories/:id`

Create request:

```json
{
  "name": "Hall",
  "targetAmount": "500000.00"
}
```

Financial endpoints are private by default and must remain permission-aware for shared plan users.
Current `/api/v1/wedding-plans/:weddingPlanId/budget-categories` and `/api/v1/budget-categories/:id` aliases exist for create/list/update/delete.

## Expenses

Protected routes:

- `POST /wedding-plans/:weddingPlanId/expenses`
- `GET /wedding-plans/:weddingPlanId/expenses`
- `GET /wedding-plans/:weddingPlanId/expenses/summary`
- `PATCH /expenses/:id`
- `DELETE /expenses/:id`

Create request:

```json
{
  "title": "Hall expense reference",
  "amount": "250000.00",
  "budgetCategoryId": "category_id",
  "status": "PAID",
  "expenseDate": "2026-06-04T00:00:00.000Z",
  "note": "Optional note"
}
```

Expense responses use decimal values as strings.

Expense creation is for actual money-out records only. `budgetCategoryId` is
required, `amount` must be greater than zero, and new create/update requests may
only use `status: "PAID"`. Planned provider/service costs, remaining amounts,
manual debts, and installment schedules belong to `FinancialCommitment` and its
payment/installment records instead of `Expense`.

Additional current expense routes:

- `GET /expenses/:id`
- `GET /api/v1/expenses/:id`

Current `/api/v1/wedding-plans/:weddingPlanId/expenses` and `/api/v1/expenses/:id` aliases exist for create/list/get/update/delete.

## Debts And Installments

These routes are now compatibility adapters for legacy debt clients. New money
planning uses `FinancialCommitment` as the backbone. Creating or changing a
legacy debt/installment mirrors it into `FinancialCommitment`,
`FinancialInstallment`, and payment records with legacy link keys, so money
summary totals do not double-count the old and new systems.

Debt routes:

- `POST /wedding-plans/:weddingPlanId/debts`
- `GET /wedding-plans/:weddingPlanId/debts`
- `GET /wedding-plans/:weddingPlanId/debts/summary`
- `GET /debts/:id`
- `PATCH /debts/:id`
- `DELETE /debts/:id`

Create debt request:

```json
{
  "creditorName": "Vendor or person",
  "creditorPhone": "+967 777 123 456",
  "title": "Remaining hall amount",
  "totalAmount": "300000.00",
  "paidAmount": "50000.00",
  "dueDate": "2026-12-15T00:00:00.000Z",
  "status": "OPEN",
  "note": "Optional note"
}
```

`creditorPhone` is optional and may be `null`. Phase 2A accepts manual entry only; contact picking is not implemented.
When debt amounts change, the backend clamps `paidAmount` to the valid balance
range and derives the debt status from the resulting balance, so clients cannot
persist an inconsistent pair such as a partially paid amount with `OPEN` status.

Installment routes:

- `POST /debts/:debtId/installments`
- `GET /debts/:debtId/installments`
- `GET /wedding-plans/:weddingPlanId/installments/due`
- `PATCH /installments/:id/pay`
- `PATCH /installments/:id`
- `DELETE /installments/:id`

Create installment request:

```json
{
  "amount": "100000.00",
  "dueDate": "2026-12-20T00:00:00.000Z",
  "paidAt": null,
  "status": "PENDING",
  "note": "Optional note"
}
```

Current `/api/v1` aliases exist for debt list/get/update/delete, installment create/list/pay/update/delete, and due-installment reads.

## Financial Commitments, Payment Records, And Financial Installments

Financial commitments are the phase-2 money backbone. Every commitment must
belong to a `budgetCategoryId`. Provider/service costs, manual debts, and other
agreed costs should be represented here before payments or installments are
recorded.

Commitment routes:

- `POST /wedding-plans/:weddingPlanId/financial-commitments`
- `GET /wedding-plans/:weddingPlanId/financial-commitments`
- `GET /financial-commitments/:id`
- `PATCH /financial-commitments/:id`
- `DELETE /financial-commitments/:id`

Create commitment request:

```json
{
  "budgetCategoryId": "category_id",
  "sourceType": "PROVIDER_SERVICE",
  "providerId": "provider_id",
  "planProviderLinkId": "plan_provider_link_id",
  "quoteRequestId": "quote_request_id",
  "quoteOfferId": "quote_offer_id",
  "title": "Hall agreement",
  "partyName": "Hall provider",
  "partyPhone": "+967 777 123 456",
  "totalAmount": "500000.00",
  "paidAmount": "100000.00",
  "dueDate": "2026-12-15T00:00:00.000Z",
  "agreementDate": "2026-07-06T00:00:00.000Z",
  "note": "Optional note"
}
```

`sourceType` values are `PROVIDER_SERVICE`, `MANUAL_DEBT`,
`MANUAL_COMMITMENT`, and `OTHER`. The backend derives `status` from
`totalAmount - paidAmount` except when the commitment is explicitly cancelled.
`remainingAmount` is returned; clients must not ask users to type the remaining
amount for provider/service commitments.

Payment record routes:

- `POST /financial-commitments/:id/payment-records`
- `GET /financial-commitments/:id/payment-records`
- `GET /wedding-plans/:weddingPlanId/financial-payment-records`
- `DELETE /financial-payment-records/:id`

Create payment record request:

```json
{
  "amount": "100000.00",
  "title": "Deposit paid",
  "paidAt": "2026-07-06T00:00:00.000Z",
  "method": "cash",
  "note": "Optional note"
}
```

A payment record means money actually left the user. Payment records are an
append-only ledger: `DELETE /financial-payment-records/:id` is retained as a
compatibility route but creates one `REVERSAL` row and returns
`deleted: false, reversed: true`; it never deletes the original row. Repeating
or concurrently submitting the same reversal returns the same single reversal.
The response includes `entryType`, `financialInstallmentId`, `reversalOfId`,
`reversedById`, and `reversible`. Legacy bridge entries are adjusted from their
original debt/installment routes and return `reversible: false`. Creating or
reversing a payment updates the parent commitment `paidAmount`, derived
`status`, and `remainingAmount`.

Financial installment routes:

- `POST /financial-commitments/:id/installments`
- `GET /financial-commitments/:id/installments`
- `GET /wedding-plans/:weddingPlanId/financial-installments/due`
- `PATCH /financial-installments/:id/pay`
- `PATCH /financial-installments/:id`
- `DELETE /financial-installments/:id`

Financial installments always belong to a financial commitment. Paying a
financial installment locks its PostgreSQL row before reading state, creates a
payment record uniquely linked by `financialInstallmentId`, and updates the
parent commitment balance. Concurrent pay requests therefore create exactly
one payment. Reversing that payment creates one compensating ledger row and
returns the installment to `PENDING`; installments or commitments with payment
history cannot be hard-deleted through product APIs.

Current `/api/v1` aliases exist for all financial commitment, payment-record,
and financial-installment routes.

## Money Summary

Protected routes:

- `GET /wedding-plans/:planId/money-summary`
- `GET /api/v1/wedding-plans/:planId/money-summary`

Money summaries must remain permission-aware. Shared users without financial permissions must not receive private budget, expense, debt, or installment details.

Super Money UI should consume the `/api/v1` route and may use stable aliases in addition to existing fields:

- `totalBudget`, `totalSpent`, `totalDebts`, and `debtRemaining`.
- `confirmedCostTotal` / `totalConfirmedCost`, `paidTotal`,
  `outstandingTotal`, and `deficitOrSurplus`.
- `commitmentTotal`, `commitmentPaidTotal`, `commitmentRemainingTotal`,
  `providerCommitmentTotal`, and `manualDebtCommitmentTotal`.
- `paidInstallmentsCount`, `remainingInstallmentsCount`, and `nextInstallment`.
- `financialInstallmentsCount`, `financialDueInstallmentsCount`,
  `financialOverdueInstallmentsCount`, `financialRemainingInstallmentsCount`,
  and `nextFinancialInstallment`.
- `categorySummaries` with allocated, spent, confirmedCost, paid, outstanding,
  budgetRemaining, remaining, commitmentsCount, and installmentsCount values
  when permissions allow them.
- `financialWarnings` for budget exceeded, category exceeded, overdue/due-soon installments, or uncategorized expenses when computable.

Day/week/month financial reports are not a current contract. The backend exposes current aggregate totals only.

## Tasks

Protected routes:

- `POST /wedding-plans/:weddingPlanId/tasks`
- `GET /wedding-plans/:weddingPlanId/tasks`
- `GET /wedding-plans/:weddingPlanId/tasks/summary`
- `GET /tasks/:id`
- `POST /tasks/:id/checklist`
- `PATCH /tasks/:id/checklist/:itemId`
- `DELETE /tasks/:id/checklist/:itemId`
- `PATCH /tasks/:id/assign`
- `PATCH /tasks/:id`
- `DELETE /tasks/:id`

Create request:

```json
{
  "title": "Confirm hall",
  "description": "Call the hall manager",
  "dueDate": "2026-12-05T00:00:00.000Z",
  "responsibleName": "Mohammed",
  "responsiblePhone": "+967777123456",
  "responsibleSource": "manual",
  "status": "TODO",
  "priority": "HIGH"
}
```

Owners can manage tasks. Shared members can list tasks and can manage tasks only when `canManageTasks` is true or their role is `MANAGER`.

Current `/api/v1/wedding-plans/:weddingPlanId/tasks` and `/api/v1/tasks/:id` aliases exist for create/list/summary/get/checklist/assign/update/delete.

Task summary also exposes Super UI aliases: `total`, `completed`, `pendingInProgress`, `overdue`, `dueToday`, `highPriority`, and `assigneeSummary`.

Task responsibility has two mutually exclusive modes. A registered plan owner or
member uses `assigneeUserId`. A person who is not a registered plan member uses
optional `responsibleName`, `responsiblePhone`, and `responsibleSource`
(`manual`, `deviceContact`, or `planContact`). Assigning a registered participant
clears the manual-responsibility fields, while writing non-empty manual fields
clears `assigneeUserId`. `responsiblePhone` may be omitted or `null`.

Task summary assignment counts include registered `assigneeUserId` assignments
only. Money/guest/provider entity links are not part of the current task model
and must not be faked by clients.

`responsiblePhone` is returned only to the plan owner or a member who can
manage tasks. Read-only plan members receive `null` for that field.

## Timeline

Protected route:

- `GET /wedding-plans/:weddingPlanId/timeline`

Response includes:

- `weddingDate`
- `upcomingTasks`
- `dueDebts`
- `dueInstallments`

Shared members can see task timeline items. Financial due items are hidden unless the shared member has the relevant debt permission.

## Sharing

Protected routes:

- `POST /wedding-plans/:weddingPlanId/shared-members`
- `GET /wedding-plans/:weddingPlanId/shared-members`
- `PATCH /shared-members/:id`
- `DELETE /shared-members/:id`
- `GET /shared/wedding-plans`
- `GET /api/v1/wedding-plans/:weddingPlanId/members`
- `PATCH /api/v1/wedding-plans/:weddingPlanId/members/:memberId`
- `DELETE /api/v1/wedding-plans/:weddingPlanId/members/:memberId`
- `POST /api/v1/wedding-plans/:weddingPlanId/invites`
- `GET /api/v1/invites/:token`
- `POST /api/v1/invites/:token/accept`
- `GET /api/v1/wedding-plans/:weddingPlanId/permissions/me`

Invite token preview is not a public endpoint. The invite detail route requires
an authenticated user and returns only invitations targeted to that user id or
an equivalent normalized phone number.

External invite tokens are random bearer values returned only when an invite is
created. PostgreSQL stores their SHA-256 fingerprints, never the raw value.
Authenticated invite lists use the invite id as an identity-checked action
handle. Accept/decline uses a conditional single-row claim, so concurrent
requests cannot both consume one invite. Access and error logs replace invite
path tokens and sensitive query values with redacted placeholders.

Create shared member request:

```json
{
  "phone": "+967700000000",
  "role": "VIEWER",
  "canViewBudget": false,
  "canViewExpenses": false,
  "canViewDebts": false,
  "canManageTasks": false,
  "canManageFinancialRecords": false
}
```

The create route accepts either `phone` or `userId`. Flutter uses `phone` so owners can add an already-registered user by phone number. Existing `userId` request support is preserved for compatibility. Requests that provide both `userId` and `phone` are rejected with `400`.

Shared member response:

```json
{
  "id": "shared_member_id",
  "weddingPlanId": "plan_id",
  "userId": "shared_user_id",
  "user": {
    "id": "shared_user_id",
    "name": "Shared Member Name",
    "phone": "+967700000000"
  },
  "role": "VIEWER",
  "canViewBudget": false,
  "canViewExpenses": false,
  "canViewDebts": false,
  "canManageTasks": false,
  "canManageFinancialRecords": false,
  "createdAt": "2026-06-04T00:00:00.000Z",
  "updatedAt": "2026-06-04T00:00:00.000Z"
}
```

The `user` object is safe display data only. It must not include `passwordHash`, refresh tokens, email, role, status, or a full user object.

The owner, or a member explicitly holding `canInviteMembers`, can manage shared
members. A non-owner cannot grant any effective role or permission above their
own current ceiling; role-implied permissions are included in that comparison.
The owner cannot add themselves as a shared member, unknown phone numbers are
rejected without auto-creating users, and duplicate members are rejected.

Invite routes support explicit acceptance flows. They do not create chat or broad social collaboration features.
Phone and user-id invitations require the authenticated account's verified
phone. Email-only invitations are rejected until verified-email ownership is
implemented; an unverified email string is never treated as identity proof.

## Guests

Protected routes:

- `GET /wedding-plans/:weddingPlanId/guests`
- `POST /wedding-plans/:weddingPlanId/guests`
- `POST /wedding-plans/:weddingPlanId/guests/bulk`
- `GET /wedding-plans/:weddingPlanId/guests/summary`
- `GET /wedding-plans/:weddingPlanId/guest-groups`
- `POST /wedding-plans/:weddingPlanId/guest-groups`
- `GET /guests/:id`
- `PATCH /guests/:id`
- `DELETE /guests/:id`
- `PATCH /guest-groups/:id`
- `DELETE /guest-groups/:id`

Create guest request:

```json
{
  "name": "Guest Name",
  "phone": "+967700000000",
  "side": "FAMILY",
  "status": "INVITED",
  "seatsCount": 1,
  "notes": "Optional note"
}
```

Guest response:

```json
{
  "id": "guest_id",
  "weddingPlanId": "plan_id",
  "name": "Guest Name",
  "phone": "+967700000000",
  "side": "FAMILY",
  "status": "INVITED",
  "seatsCount": 1,
  "notes": "Optional note",
  "createdAt": "2026-06-18T00:00:00.000Z",
  "updatedAt": "2026-06-18T00:00:00.000Z"
}
```

Users with readable plan access can list guests. Creating, updating, and deleting guests requires owner or manager access.

Current `/api/v1` aliases exist for guest list/create/bulk/summary/groups/get/update/delete.

Guest summary also exposes Super UI aliases and cleanup fields:

- `confirmed`, `pending`, `waiting`, `declined`, and `notAttending`.
- `missingPhoneCount`, `missingNameCount`, and `incompleteGuestsCount`.
- `expectedSeatsCount` and `companionsExpectedCount`.
- `bySideForSuper` with `groom`, `bride`, and `unknown` buckets while preserving the existing enum-keyed `bySide`.
- `byGroup` counts when guest groups exist.

Incomplete guest detection is informational only. It must not block saving guests.

## Provider References And Quote Leads

Current provider routes are planning/reference and lead workflows. They do not
create paid bookings, deposits, payment status, loans, credit, financing, or AI.

Public/reference routes:

- `GET /cities`
- `GET /provider-categories`
- `GET /providers`
- `GET /providers/:id`
- `GET /providers/:id/services`
- `GET /providers/:id/packages`
- `GET /providers/:id/reviews`
- `GET /services`
- `GET /services/:id`
- `GET /api/v1/provider-categories`
- `GET /api/v1/providers`
- `GET /api/v1/providers/:id`

Authenticated user routes:

- `POST /providers/:id/favorite`
- `DELETE /providers/:id/favorite`
- `GET /me/favorite-providers`
- `POST /providers/:id/quote-requests`
- `GET /me/quote-requests`
- `GET /me/quote-requests/:id`
- `PATCH /me/quote-requests/:id/cancel`
- `POST /providers/:id/reviews`
- `PATCH /reviews/:id`
- `DELETE /reviews/:id`

Every review response uses a privacy-safe reviewer identity containing only
`id` and `name`. Reviewer phone and email are never returned by public review,
review create/update, provider-dashboard review, or admin-review responses.

Plan-scoped `/api/v1` quote routes:

- `POST /api/v1/wedding-plans/:weddingPlanId/quote-requests`
- `GET /api/v1/wedding-plans/:weddingPlanId/quote-requests`
- `GET /api/v1/quote-requests/:id`
- `PATCH /api/v1/quote-requests/:id/cancel`
- `PATCH /api/v1/quote-offers/:id/accept`
- `PATCH /api/v1/quote-offers/:id/reject`

Accepting an offer returns the accepted offer and `planProviderLink`, and explicitly returns:

- `automaticFinancialRecordCreated: false`
- `financialSuggestion`
- `nextActions`, including `createFinancialCommitment`, `recordPayment`,
  `createFollowUpTask`, and `viewAcceptedProvider`

Accepting an offer must not silently create financial commitments, expenses,
debts, installments, tasks, payments, deposits, or confirmed bookings.

Provider dashboard routes:

- `POST /provider/apply`
- `GET /provider/me/profile`
- `PATCH /provider/me/profile`
- `GET /provider/me/summary`
- `GET /provider/me/services`
- `POST /provider/me/services`
- `GET /provider/me/services/:id`
- `PATCH /provider/me/services/:id`
- `DELETE /provider/me/services/:id`
- `POST /provider/me/services/:id/images`
- `PATCH /provider/me/services/:serviceId/images/:imageId`
- `DELETE /provider/me/services/:serviceId/images/:imageId`
- `GET /provider/me/packages`
- `POST /provider/me/packages`
- `PATCH /provider/me/packages/:id`
- `DELETE /provider/me/packages/:id`
- `GET /provider/me/quote-requests`
- `GET /provider/me/quote-requests/:id`
- `PATCH /provider/me/quote-requests/:id/status`
- `GET /provider/me/reviews`
- `GET /api/v1/provider/me`
- `POST /api/v1/provider/profile`
- `PATCH /api/v1/provider/profile`
- `POST /api/v1/provider/services`
- `PATCH /api/v1/provider/services/:id`
- `DELETE /api/v1/provider/services/:id`
- `GET /api/v1/provider/quote-requests`
- `GET /api/v1/provider/quote-requests/:id`
- `POST /api/v1/provider/quote-requests/:id/offers`
- `PATCH /api/v1/provider/quote-offers/:id`

Known follow-up from the 2026-06-20 audit: quote request/offer permissions should be tightened before shared-plan users are allowed to manage quote decisions broadly.

## Quote Conversations And Media

Conversations are available only for a real quote request and only to its
requester and provider account. Open or unsolicited messaging is excluded.

- `POST /conversations/quote-requests/:quoteRequestId` creates or returns the
  quote conversation.
- `GET /conversations` lists the current account's conversations.
- `GET /conversations/:id/messages` returns paginated message history.
- `POST /conversations/:id/messages` sends text and approved signed-media
  attachments.
- `GET /conversations/:id/attachments/:attachmentId/download` refreshes a
  private attachment link after rechecking conversation membership.
- `PATCH /conversations/:id/read`, `/mute`, and `/block` update participant
  state.
- `POST /conversations/:id/report` creates a moderation report.

Conversation list responses include the aggregate `blocked` value plus
`blockedByMe`, `blockedByCounterpart`, and `counterpartLastReadAt` so clients
can distinguish who owns a block and show read receipts without exposing other
private participant state. `unreadCount` is derived for the current account.

Authenticated Socket.IO events are `conversation:join`,
`conversation:message`, and `conversation:read`. Server authorization is
rechecked before room access and message actions.

`POST /media/uploads/presign` issues short-lived S3-compatible upload URLs for
approved purposes and size/MIME limits. Public avatar/provider purposes return
`publicUrl`. A `chat-image` upload instead returns an opaque `attachmentRef`
and `publicUrl: null`; the message write accepts that reference only when its
path belongs to the authenticated sender. The database stores only the private
object key. Conversation/message responses replace it with a signed GET URL
that expires after 120 seconds and include `expiresAt`; they never expose the
storage key. All responses carrying these links use `Cache-Control: private,
no-store`. Arbitrary external attachment URLs are rejected. Environment-backed
private-bucket and Socket.IO smoke remain release gates.

## Admin APIs

Admin routes are JWT-protected and require admin authorization:

- `POST /auth/admin/login` validates the admin password and returns only a
  short-lived MFA challenge after sending a `LOGIN` OTP.
- `POST /auth/admin/login/complete` atomically consumes the challenge + OTP,
  returns a short-lived access JWT, and sets the rotating refresh token only as
  a path-scoped `HttpOnly`, `SameSite=Strict` cookie (`Secure` in production).
- `POST /auth/admin/refresh` rotates that cookie and its server session.
- `POST /auth/admin/logout` revokes the server session and clears the cookie.

General password login, general OTP login, and general refresh never mint the
`admin_mfa` assurance required by `AdminGuard`. Each admin access JWT also
carries a server-side refresh-session id; refresh or logout revokes that row,
so the prior access JWT stops working immediately. The JSON contract never
returns the admin refresh token.

- `GET /admin/dashboard/stats`
- `GET /admin/reports/overview`
- `GET /admin/providers/applications`
- `GET /admin/providers/applications/:id`
- `PATCH /admin/providers/:id/approve`
- `PATCH /admin/providers/:id/reject`
- `PATCH /admin/providers/:id/request-changes`
- `PATCH /admin/providers/:id/suspend`
- `PATCH /admin/providers/:id/activate`
- `GET /admin/providers`
- `GET /admin/providers/:id`
- `GET /admin/services`
- `POST /admin/services`
- `PATCH /admin/services/:id`
- `DELETE /admin/services/:id`
- `GET /admin/reviews`
- `PATCH /admin/reviews/:id/status`
- `DELETE /admin/reviews/:id`
- `GET /admin/conversation-reports`
- `PATCH /admin/conversation-reports/:id/status`
- `GET /admin/notifications`
- `GET /admin/notifications/unread-count`
- `PATCH /admin/notifications/:id/read`
- `PATCH /admin/notifications/:id/archive`
- `DELETE /admin/notifications/:id`
- `GET /admin/provider-categories`
- `POST /admin/provider-categories`
- `PATCH /admin/provider-categories/:id`
- `DELETE /admin/provider-categories/:id`
- `GET /admin/cities`
- `POST /admin/cities`
- `PATCH /admin/cities/:id`
- `DELETE /admin/cities/:id`
- `GET /admin/users`
- `PATCH /admin/users/:id/activate`
- `PATCH /admin/users/:id/disable`
- `GET /admin/users/:id`

The admin user, provider application, provider, service, review, conversation
report, and notification list routes accept positive `page` and `limit` query
parameters (`limit` is capped server-side). They return
`{ items, page, limit, total, totalPages }`; the UI must use this metadata and
must not silently truncate to its first 50/80/100 results.

Admin services are real `ProviderService` management operations. Deleting a service safely deactivates it (`isActive=false`) instead of hard-deleting data.

Admin reviews are real `ProviderReview` moderation operations. Publishing or hiding a review recalculates the provider public rating from published reviews only. Reviewer contact details are not part of the moderation response or search contract.

Admin notifications expose a privacy-minimized operational view of persisted
notifications across users. The user reference contains `id`, `name`, and a
masked phone suffix only. Installment/debt notifications, notifications with a
financial entity, and even misclassified notifications carrying financial data
keys return a generic Arabic title/body, `financialDetailsRedacted: true`, and
`null` for `data`, `entityId`, `routeTarget`, and plan details. The general
admin API has no endpoint that reveals that hidden financial content. Search
does not query notification bodies, user phones, or reviewer phones. User-owned
notification routes remain separate under `/notifications` and
`/api/v1/notifications`.

`GET /admin/reports/overview` is an operational database report for users,
providers, services, reviews, quote requests, notifications, catalog counts,
and wedding-plan counts. Conversation-report moderation exposes report,
reporter, provider, and quote context but never message bodies. None of these routes adds payment
processing, deposits, confirmed booking payments, loans, credit, financing, or
AI behavior.

Admin runtime smoke coverage exists in `admin-web/scripts/admin-runtime-smoke.mjs` for dashboard stats, users, catalog references, providers, services, reviews, notifications, and operational reports.

## Error Behavior

- Missing or invalid JWT returns `401`.
- Validation errors are rejected by the global validation pipe.
- Authenticated `POST`, `PUT`, `PATCH`, and `DELETE` requests may send
  `X-Client-Request-Id`. The key is scoped to the user and bound to the HTTP
  method, concrete path/query, and canonical JSON body. An identical retry
  replays the stored success; concurrent identical requests execute once. Reuse
  for different request content returns `409`, while an identical request still
  in progress returns retryable `503`. Raw paths, query values, and invite
  tokens are represented only by a SHA-256 fingerprint and are not persisted.
  Pending reservations expire after 24 hours by default, completed responses
  after 168 hours; both are environment-bounded and cleaned hourly.
- Access/error telemetry records the matched route template only. Query
  strings, concrete resource ids, invite tokens, exception messages, and
  exception stacks are not sent to application logs or Sentry. Unmatched
  routes are recorded as `unmatched`, and invalid client request ids are
  replaced with a server-generated UUID.
- Access to private resources that the user does not own or cannot access may return a not-found style response.
- Login with a wrong password returns `401`.

## MVP Exclusions

The current MVP backend contract does not include:

- payments
- deposits
- paid bookings
- confirmed booking or reservation lifecycle
- marketplace checkout, commissions, subscriptions, or monetization
- AI
- FinTech
- open or unsolicited marketplace messaging outside a quote request
- Docker/Dokploy deployment implementation

## Generated Controller Inventory

The generated table below inventories controller decorators found in source.
Runtime readiness still depends on matching migrations, environment
configuration, and smoke checks.

<!-- DOCS-SYNC:START -->
<!-- AUTO-GENERATED by scripts/docs-sync.mjs. Do not edit by hand. -->

| Method | Path | Controller.Handler | Auth |
| --- | --- | --- | --- |
| GET | `/admin/audit-logs` | `admin-audit.list` |  |
| GET | `/admin/cities` | `admin.listCities` |  |
| POST | `/admin/cities` | `admin.createCity` |  |
| DELETE | `/admin/cities/:id` | `admin.deleteCity` |  |
| PATCH | `/admin/cities/:id` | `admin.updateCity` |  |
| GET | `/admin/conversation-reports` | `admin.listConversationReports` |  |
| PATCH | `/admin/conversation-reports/:id/status` | `admin.updateConversationReportStatus` |  |
| GET | `/admin/dashboard/stats` | `admin.getDashboardStats` |  |
| GET | `/admin/notifications` | `admin.listNotifications` |  |
| DELETE | `/admin/notifications/:id` | `admin.deleteNotification` |  |
| PATCH | `/admin/notifications/:id/archive` | `admin.archiveNotification` |  |
| PATCH | `/admin/notifications/:id/read` | `admin.markNotificationRead` |  |
| GET | `/admin/notifications/unread-count` | `admin.getUnreadNotificationsCount` |  |
| GET | `/admin/provider-categories` | `admin.listCategories` |  |
| POST | `/admin/provider-categories` | `admin.createCategory` |  |
| DELETE | `/admin/provider-categories/:id` | `admin.deleteCategory` |  |
| PATCH | `/admin/provider-categories/:id` | `admin.updateCategory` |  |
| GET | `/admin/providers` | `admin.listProviders` |  |
| GET | `/admin/providers/:id` | `admin.getProvider` |  |
| PATCH | `/admin/providers/:id/activate` | `admin.activateProvider` |  |
| PATCH | `/admin/providers/:id/approve` | `admin.approveProvider` |  |
| PATCH | `/admin/providers/:id/reject` | `admin.rejectProvider` |  |
| PATCH | `/admin/providers/:id/request-changes` | `admin.requestProviderChanges` |  |
| PATCH | `/admin/providers/:id/suspend` | `admin.suspendProvider` |  |
| GET | `/admin/providers/applications` | `admin.listProviderApplications` |  |
| GET | `/admin/providers/applications/:id` | `admin.getProviderApplication` |  |
| GET | `/admin/reports/overview` | `admin.getReportsOverview` |  |
| GET | `/admin/reviews` | `admin.listReviews` |  |
| DELETE | `/admin/reviews/:id` | `admin.hideReview` |  |
| PATCH | `/admin/reviews/:id/status` | `admin.updateReviewStatus` |  |
| GET | `/admin/services` | `admin.listServices` |  |
| POST | `/admin/services` | `admin.createService` |  |
| DELETE | `/admin/services/:id` | `admin.deleteService` |  |
| PATCH | `/admin/services/:id` | `admin.updateService` |  |
| GET | `/admin/users` | `admin.listUsers` |  |
| GET | `/admin/users/:id` | `admin.getUser` |  |
| PATCH | `/admin/users/:id/activate` | `admin.activateUser` |  |
| PATCH | `/admin/users/:id/disable` | `admin.disableUser` |  |
| POST | `/auth/admin/login` | `auth.startAdminLogin` |  |
| POST | `/auth/admin/login/complete` | `auth.completeAdminLogin` |  |
| POST | `/auth/admin/logout` | `auth.logoutAdmin` |  |
| POST | `/auth/admin/refresh` | `auth.refreshAdmin` |  |
| POST | `/auth/login` | `auth.login` |  |
| POST | `/auth/logout` | `auth.logout` | 🔒 |
| POST | `/auth/logout-all` | `auth.logoutAll` | 🔒 |
| GET | `/auth/me` | `auth.me` | 🔒 |
| POST | `/auth/otp/request` | `auth.requestOtp` |  |
| POST | `/auth/otp/verify` | `auth.verifyOtp` |  |
| POST | `/auth/password-reset/confirm` | `auth.confirmPasswordReset` |  |
| POST | `/auth/password-reset/request` | `auth.requestPasswordReset` |  |
| POST | `/auth/refresh` | `auth.refresh` |  |
| POST | `/auth/register` | `auth.register` |  |
| POST | `/auth/register/complete` | `auth.completeRegistration` |  |
| DELETE | `/budget-categories/:id` | `budget-categories.remove` |  |
| PATCH | `/budget-categories/:id` | `budget-categories.update` |  |
| GET | `/cities` | `marketplace.findCities` |  |
| GET | `/conversations` | `conversations.list` |  |
| GET | `/conversations/:id/attachments/:attachmentId/download` | `conversations.downloadAttachment` |  |
| PATCH | `/conversations/:id/block` | `conversations.block` |  |
| GET | `/conversations/:id/messages` | `conversations.messages` |  |
| POST | `/conversations/:id/messages` | `conversations.send` |  |
| PATCH | `/conversations/:id/mute` | `conversations.mute` |  |
| PATCH | `/conversations/:id/read` | `conversations.markRead` |  |
| POST | `/conversations/:id/report` | `conversations.report` |  |
| POST | `/conversations/quote-requests/:quoteRequestId` | `conversations.ensureForQuote` |  |
| GET | `/dashboard/home` | `dashboard.getHome` |  |
| GET | `/debts/:debtId/installments` | `installments.findForDebt` |  |
| POST | `/debts/:debtId/installments` | `installments.create` |  |
| DELETE | `/debts/:id` | `debts.remove` |  |
| GET | `/debts/:id` | `debts.findOne` |  |
| PATCH | `/debts/:id` | `debts.update` |  |
| DELETE | `/expenses/:id` | `expenses.remove` |  |
| GET | `/expenses/:id` | `expenses.findOne` |  |
| PATCH | `/expenses/:id` | `expenses.update` |  |
| DELETE | `/financial-commitments/:id` | `financial-commitments.remove` |  |
| GET | `/financial-commitments/:id` | `financial-commitments.findOne` |  |
| PATCH | `/financial-commitments/:id` | `financial-commitments.update` |  |
| GET | `/financial-commitments/:id/installments` | `financial-commitments.listInstallments` |  |
| POST | `/financial-commitments/:id/installments` | `financial-commitments.createInstallment` |  |
| GET | `/financial-commitments/:id/payment-records` | `financial-commitments.listPaymentRecords` |  |
| POST | `/financial-commitments/:id/payment-records` | `financial-commitments.createPaymentRecord` |  |
| DELETE | `/financial-installments/:id` | `financial-commitments.remove` |  |
| PATCH | `/financial-installments/:id` | `financial-commitments.update` |  |
| PATCH | `/financial-installments/:id/pay` | `financial-commitments.pay` |  |
| DELETE | `/financial-payment-records/:id` | `financial-commitments.remove` |  |
| DELETE | `/guest-groups/:id` | `guests.removeGroup` |  |
| PATCH | `/guest-groups/:id` | `guests.updateGroup` |  |
| DELETE | `/guests/:id` | `guests.remove` |  |
| GET | `/guests/:id` | `guests.findOne` |  |
| PATCH | `/guests/:id` | `guests.update` |  |
| GET | `/health` | `health.getCompatibilityHealth` |  |
| DELETE | `/installments/:id` | `installments.remove` |  |
| PATCH | `/installments/:id` | `installments.update` |  |
| PATCH | `/installments/:id/pay` | `installments.pay` |  |
| GET | `/live` | `health.getLiveness` |  |
| GET | `/me` | `me.me` |  |
| GET | `/me/favorite-providers` | `marketplace.findMyFavoriteProviders` |  |
| GET | `/me/quote-requests` | `marketplace.findMyQuoteRequests` |  |
| GET | `/me/quote-requests/:id` | `marketplace.findMyQuoteRequest` |  |
| PATCH | `/me/quote-requests/:id/cancel` | `marketplace.cancelMyQuoteRequest` |  |
| POST | `/media/uploads/presign` | `media.presign` |  |
| GET | `/metrics` | `metrics.metrics` |  |
| GET | `/notifications` | `notifications.list` |  |
| DELETE | `/notifications/:id` | `notifications.remove` |  |
| GET | `/notifications/:id` | `notifications.findOne` |  |
| PATCH | `/notifications/:id/archive` | `notifications.archive` |  |
| PATCH | `/notifications/:id/read` | `notifications.markRead` |  |
| PATCH | `/notifications/read-all` | `notifications.markAllRead` |  |
| GET | `/notifications/unread-count` | `notifications.unreadCount` |  |
| POST | `/onboarding/complete` | `onboarding.complete` |  |
| POST | `/onboarding/import-local` | `onboarding.importLocal` |  |
| GET | `/provider-categories` | `marketplace.findCategories` |  |
| POST | `/provider/apply` | `provider-dashboard.apply` |  |
| GET | `/provider/me/packages` | `provider-dashboard.findPackages` |  |
| POST | `/provider/me/packages` | `provider-dashboard.createPackage` |  |
| DELETE | `/provider/me/packages/:id` | `provider-dashboard.deactivatePackage` |  |
| PATCH | `/provider/me/packages/:id` | `provider-dashboard.updatePackage` |  |
| GET | `/provider/me/profile` | `provider-dashboard.getProfile` |  |
| PATCH | `/provider/me/profile` | `provider-dashboard.updateProfile` |  |
| GET | `/provider/me/quote-requests` | `provider-dashboard.findQuoteRequests` |  |
| GET | `/provider/me/quote-requests/:id` | `provider-dashboard.findQuoteRequest` |  |
| POST | `/provider/me/quote-requests/:id/offers` | `provider-dashboard.createQuoteOffer` |  |
| PATCH | `/provider/me/quote-requests/:id/status` | `provider-dashboard.updateQuoteRequestStatus` |  |
| GET | `/provider/me/reviews` | `provider-dashboard.findReviews` |  |
| GET | `/provider/me/services` | `provider-dashboard.findServices` |  |
| POST | `/provider/me/services` | `provider-dashboard.createService` |  |
| DELETE | `/provider/me/services/:id` | `provider-dashboard.deactivateService` |  |
| GET | `/provider/me/services/:id` | `provider-dashboard.findService` |  |
| PATCH | `/provider/me/services/:id` | `provider-dashboard.updateService` |  |
| POST | `/provider/me/services/:id/images` | `provider-dashboard.createServiceImage` |  |
| DELETE | `/provider/me/services/:serviceId/images/:imageId` | `provider-dashboard.deleteServiceImage` |  |
| PATCH | `/provider/me/services/:serviceId/images/:imageId` | `provider-dashboard.updateServiceImage` |  |
| GET | `/provider/me/summary` | `provider-dashboard.getSummary` |  |
| GET | `/providers` | `marketplace.findProviders` |  |
| GET | `/providers/:id` | `marketplace.findProvider` |  |
| DELETE | `/providers/:id/favorite` | `marketplace.unfavoriteProvider` | 🔒 |
| POST | `/providers/:id/favorite` | `marketplace.favoriteProvider` | 🔒 |
| GET | `/providers/:id/packages` | `marketplace.findProviderPackages` |  |
| POST | `/providers/:id/quote-requests` | `marketplace.createQuoteRequest` | 🔒 |
| GET | `/providers/:id/reviews` | `marketplace.findProviderReviews` |  |
| POST | `/providers/:id/reviews` | `marketplace.createReview` | 🔒 |
| GET | `/providers/:id/services` | `marketplace.findProviderServices` |  |
| GET | `/ready` | `health.getReadiness` |  |
| DELETE | `/reviews/:id` | `marketplace.deleteReview` |  |
| PATCH | `/reviews/:id` | `marketplace.updateReview` |  |
| GET | `/services` | `marketplace.findServices` |  |
| GET | `/services/:id` | `marketplace.findService` |  |
| DELETE | `/shared-members/:id` | `sharing.remove` |  |
| PATCH | `/shared-members/:id` | `sharing.update` |  |
| GET | `/shared/wedding-plans` | `sharing.findSharedPlans` |  |
| DELETE | `/tasks/:id` | `tasks.remove` |  |
| GET | `/tasks/:id` | `tasks.findOne` |  |
| PATCH | `/tasks/:id` | `tasks.update` |  |
| PATCH | `/tasks/:id/assign` | `tasks.assign` |  |
| POST | `/tasks/:id/checklist` | `tasks.createChecklistItem` |  |
| DELETE | `/tasks/:id/checklist/:itemId` | `tasks.removeChecklistItem` |  |
| PATCH | `/tasks/:id/checklist/:itemId` | `tasks.updateChecklistItem` |  |
| GET | `/users/lookup` | `users.lookupByPhone` |  |
| DELETE | `/users/me` | `users.deleteMe` |  |
| PATCH | `/users/me` | `users.updateMe` |  |
| GET | `/users/me/settings` | `users.getSettings` |  |
| PATCH | `/users/me/settings` | `users.updateSettings` |  |
| GET | `/wedding-plans` | `wedding-plans.findAccessible` |  |
| POST | `/wedding-plans` | `wedding-plans.create` |  |
| GET | `/wedding-plans/:id` | `wedding-plans.findOne` |  |
| PATCH | `/wedding-plans/:id` | `wedding-plans.update` |  |
| PATCH | `/wedding-plans/:id/archive` | `wedding-plans.archive` |  |
| POST | `/wedding-plans/:id/set-active` | `wedding-plans.setActive` |  |
| GET | `/wedding-plans/:planId/dashboard-summary` | `dashboard.getDashboardSummary` |  |
| GET | `/wedding-plans/:planId/money-summary` | `money-summary.getMoneySummary` |  |
| GET | `/wedding-plans/:weddingPlanId/budget-categories` | `budget-categories.findForPlan` |  |
| POST | `/wedding-plans/:weddingPlanId/budget-categories` | `budget-categories.create` |  |
| GET | `/wedding-plans/:weddingPlanId/debts` | `debts.findForPlan` |  |
| POST | `/wedding-plans/:weddingPlanId/debts` | `debts.create` |  |
| GET | `/wedding-plans/:weddingPlanId/debts/summary` | `debts.summary` |  |
| GET | `/wedding-plans/:weddingPlanId/expenses` | `expenses.findForPlan` |  |
| POST | `/wedding-plans/:weddingPlanId/expenses` | `expenses.create` |  |
| GET | `/wedding-plans/:weddingPlanId/expenses/summary` | `expenses.summary` |  |
| GET | `/wedding-plans/:weddingPlanId/financial-commitments` | `financial-commitments.findForPlan` |  |
| POST | `/wedding-plans/:weddingPlanId/financial-commitments` | `financial-commitments.create` |  |
| GET | `/wedding-plans/:weddingPlanId/financial-installments/due` | `financial-commitments.dueForPlan` |  |
| GET | `/wedding-plans/:weddingPlanId/financial-payment-records` | `financial-commitments.findForPlan` |  |
| GET | `/wedding-plans/:weddingPlanId/guest-groups` | `guests.findGroups` |  |
| POST | `/wedding-plans/:weddingPlanId/guest-groups` | `guests.createGroup` |  |
| GET | `/wedding-plans/:weddingPlanId/guests` | `guests.findForPlan` |  |
| POST | `/wedding-plans/:weddingPlanId/guests` | `guests.create` |  |
| POST | `/wedding-plans/:weddingPlanId/guests/bulk` | `guests.bulkCreate` |  |
| GET | `/wedding-plans/:weddingPlanId/guests/summary` | `guests.summary` |  |
| GET | `/wedding-plans/:weddingPlanId/installments/due` | `installments.dueForPlan` |  |
| GET | `/wedding-plans/:weddingPlanId/shared-members` | `sharing.findForPlan` |  |
| POST | `/wedding-plans/:weddingPlanId/shared-members` | `sharing.create` |  |
| GET | `/wedding-plans/:weddingPlanId/tasks` | `tasks.findForPlan` |  |
| POST | `/wedding-plans/:weddingPlanId/tasks` | `tasks.create` |  |
| GET | `/wedding-plans/:weddingPlanId/tasks/summary` | `tasks.summary` |  |
| GET | `/wedding-plans/:weddingPlanId/timeline` | `timeline.getForPlan` |  |
| GET | `/wedding-plans/active` | `wedding-plans.findActive` |  |
| GET | `/wedding-plans/my` | `wedding-plans.findMine` |  |
<!-- DOCS-SYNC:END -->
