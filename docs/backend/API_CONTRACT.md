# API Contract

This document is the route-level source of truth for the current Aarast backend contract. Other Markdown files should link here instead of copying endpoint lists.

Current documentation snapshot: 2026-07-11.

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

The backend keeps operational probes at the origin root, while all mobile and
provider product APIs use the canonical `/api/v1` namespace. For example,
clients call `GET /health` and `POST /api/v1/auth/login`.

Health endpoints have distinct orchestration semantics:

- `GET /live` checks only that the HTTP process responds.
- `GET /health` is a compatibility alias of `/live`.
- `GET /ready` checks PostgreSQL and required Redis/media dependencies. When
  `AUTH_OTP_MODE=openwa`, it also requires the selected WhatsApp session and
  Aarast transient-delivery extension to be ready. It
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
- All mobile and provider product APIs use the single canonical `/api/v1`
  namespace. Unversioned product routes were removed in July 2026; only
  operational endpoints (`/live`, `/health`, `/ready`, `/metrics`) and the
  internal `/admin` surface remain outside that namespace.

## Auth

### `POST /api/v1/auth/register`

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
`POST /api/v1/auth/register/complete` with the six-digit `otpCode`. Production
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

### `POST /api/v1/auth/login`

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
Five failed password attempts within fifteen minutes lock that normalized
account identifier for fifteen minutes. PostgreSQL stores only an
HMAC-SHA-256 digest keyed by the deployment-only
`AUTH_LOGIN_THROTTLE_PEPPER`, not the phone number, so the lock is shared by
every backend replica and survives restarts. Production fails closed when the
pepper is missing. A successful password login or password reset clears the
record; an hourly PostgreSQL advisory-lock job removes expired locks and
inactive windows on one replica.

### Refresh Sessions

Register, password login, and OTP login return an access token, opaque refresh
token, and refresh expiry. Access JWTs default to 15 minutes; refresh sessions
expire after 30 days and are stored as hashes.

- `POST /api/v1/auth/refresh` rotates one valid refresh token and returns a new access
  and refresh pair. Reuse of a revoked/expired token is rejected.
- `POST /api/v1/auth/logout` revokes the supplied refresh token; when omitted for an
  authenticated user it revokes all of that user's sessions.
- `POST /api/v1/auth/logout-all` revokes all active refresh sessions for the
  authenticated user.

The mobile client stores both tokens in secure storage and retries one failed
request once after a successful refresh. Auth endpoints do not recursively
trigger refresh.

### `GET /api/v1/auth/me`

Requires JWT. Returns the safe current user object without `passwordHash`.

### Password reset

- `POST /api/v1/auth/password-reset/request` — body `{ phone }`. Issues a
  `RESET_PASSWORD` OTP through the same OTP channel policy as
  `/api/v1/auth/otp/request`. The response never reveals whether the phone belongs
  to an account.
- `POST /api/v1/auth/password-reset/confirm` — body `{ phone, code, newPassword }`.
  Consumes the OTP, sets the new password (min 6 chars), and revokes every
  refresh token for the account so old sessions die with the old password.
  Unknown phones and wrong codes return the same generic
  `OTP code is invalid or expired` error.

Additional current auth/profile routes:

- `POST /api/v1/auth/otp/request`
- `POST /api/v1/auth/otp/verify`
- `PATCH /api/v1/users/me`
- `GET /api/v1/users/lookup?weddingPlanId=<planId>&phone=<phone>`
  - requires an authenticated owner/member with permission to invite members
- `GET /api/v1/users/me/settings`
- `PATCH /api/v1/users/me/settings`
- `GET /api/v1/me`

OTP/profile routes are account and settings helpers. They do not add payment, booking, financing, AI, or chat behavior.

`REGISTER` codes are completed only through `POST /api/v1/auth/register/complete`;
the generic verify endpoint cannot consume a registration code without the
registration details. In production `AUTH_OTP_MODE=whatsapp` uses an approved
Meta authentication template. The temporary `AUTH_OTP_MODE=openwa` option calls
only the Aarast-hardened `send-transient-text` contract; it never falls back to
upstream `send-text`. Both modes refuse to boot when their selected channel is
incompletely configured, and production responses never echo the code.

Every non-development OTP request consumes atomic PostgreSQL quotas before
delivery: 60-second phone cooldown, bounded phone/IP windows, and an
`OTP_GLOBAL_DAILY_LIMIT` ceiling. Quota keys are HMAC digests made with
`AUTH_LOGIN_THROTTLE_PEPPER`; raw phone numbers and IP addresses are not stored.
Provider delivery failures also consume quota so a failing transport cannot be
used to bypass the safety ceiling.

### Profile image upload

Authenticated profile images use the existing account profile field and the
media upload flow:

1. `POST /api/v1/media/uploads/presign` with `purpose: "user-avatar"`, the file name,
   MIME type, and byte size.
2. Upload the bytes to the returned short-lived signed `uploadUrl`.
3. `POST /api/v1/media/uploads/verify` with the returned object `key` and
   `purpose: "user-avatar"`. The backend verifies ownership metadata, stored
   size/MIME, and the actual JPEG/PNG/WebP signature before returning the
   verified canonical `publicUrl`. Verification fully decodes, auto-orients,
   strips metadata/appended bytes, and re-encodes the image before persistence.
4. `PATCH /api/v1/users/me` with that verified `publicUrl` as `avatarUrl`.

Profile images accept JPEG, PNG, or WebP and must not exceed 5 MB. The mobile
client updates its cached safe user only after both the upload and profile
update succeed. Media storage credentials remain server-side and are never
returned to the client.

## Wedding Plans

Protected routes:

- `POST /api/v1/wedding-plans`
- `GET /api/v1/wedding-plans`
- `GET /api/v1/wedding-plans/my`
- `GET /api/v1/wedding-plans/active`
- `POST /api/v1/wedding-plans/:id/set-active`
- `GET /api/v1/wedding-plans/:id`
- `PATCH /api/v1/wedding-plans/:id`
- `PATCH /api/v1/wedding-plans/:id/archive`

These are the only live wedding-plan routes.

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
an existing plan should use `POST /api/v1/wedding-plans/:id/set-active`
before opening plan-scoped dashboards.

Shared members can read basic plan info. Updating or archiving requires owner access or manager-style sharing permission.

## Onboarding And Active Plan

Protected routes:

- `POST /api/v1/onboarding/complete`
- `GET /api/v1/wedding-plans/active`
- `POST /api/v1/wedding-plans/:id/set-active`

Onboarding completion creates real server-owned plan data, selected budget categories, and active-plan state for an authenticated user. Guest-first mobile drafts remain a mobile/local strategy until the user reaches an account gate.

## WeddingPlan Dashboard Summary

Protected routes:

- `GET /api/v1/dashboard/home`
- `GET /api/v1/wedding-plans/:planId/dashboard-summary`

The dashboard summary powers the mobile Home / Today Center. Existing count and money fields remain stable, and the response may also include source-backed detail arrays:

- `dataScope: "ACCOUNT_BACKED"` and `accountBacked: true` to distinguish server/account-backed data from local guest preview data.
- `currency`: the WeddingPlan currency used by every money figure; clients must
  not hardcode YER.
- `incompleteGuestsCount`: persisted guests missing basic planning contact/name fields.
- `quoteStatusBreakdown`: `pending`, `offered`, `accepted`, and `rejectedClosed` counts.
- `acceptedProvidersCount`: stable alias for accepted/active `PlanProviderLink` count.
- `financialWarnings`: simple computable warnings such as budget exceeded or installment due soon.

- `importantItems`: actionable task/installment/provider cards for "الأهم اليوم".
- `planProviders`: providers actually linked to the current WeddingPlan.
- `importantNotifications`: latest user-owned notifications for this WeddingPlan.
- `generatedAt`: server timestamp used by the mobile sync/status copy.

Dashboard `remainingBudget` and the money-card usage ratio use confirmed cost:
paid standalone expenses plus active financial commitments. This keeps Home
aligned with the Money tab and avoids treating an unpaid commitment as free
budget.

Financial installment details appear only when the current user has the required
financial-record permission. Notifications are always scoped to the authenticated
user. Provider cards are planning/reference data only and do not imply paid
booking, deposits, payment status, loans, credit, financing, or AI.

## Notifications

Protected routes:

- `GET /api/v1/notifications`
- `GET /api/v1/notifications/unread-count`
- `GET /api/v1/notifications/:id`
- `PATCH /api/v1/notifications/:id/read`
- `PATCH /api/v1/notifications/read-all`
- `PATCH /api/v1/notifications/:id/archive`
- `DELETE /api/v1/notifications/:id`

The list route accepts optional `weddingPlanId`, `type`, `unreadOnly`, `page`,
and `limit` query parameters. `limit` defaults to 20 and is capped at 50. It
returns `{ items, page, limit, total, totalPages, hasMore }`. The unread-count
route accepts optional `weddingPlanId`. Notifications are always owned by the
authenticated user. List, count, and mark-all reads never generate records;
task writes create immediate due reminders and an hourly cross-replica locked
scheduler idempotently repairs task and financial-installment reminders.

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

- `POST /api/v1/wedding-plans/:weddingPlanId/budget-categories`
- `GET /api/v1/wedding-plans/:weddingPlanId/budget-categories`
- `PATCH /api/v1/budget-categories/:id`
- `DELETE /api/v1/budget-categories/:id`

Create request:

```json
{
  "name": "Hall",
  "targetAmount": "500000.00"
}
```

Financial endpoints are private by default and must remain permission-aware for shared plan users.
No unversioned budget-category aliases are exposed.

## Expenses

Protected routes:

- `POST /api/v1/wedding-plans/:weddingPlanId/expenses`
- `GET /api/v1/wedding-plans/:weddingPlanId/expenses`
- `GET /api/v1/wedding-plans/:weddingPlanId/expenses/summary`
- `PATCH /api/v1/expenses/:id`
- `DELETE /api/v1/expenses/:id`

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
manual payables and installment schedules belong to `FinancialCommitment` and its
payment/installment records instead of `Expense`.

Additional current expense routes:

- `GET /api/v1/expenses/:id`

No unversioned expense aliases are exposed.

## Financial Commitments, Payment Records, And Financial Installments

Financial commitments are the phase-2 money backbone. Every commitment must
belong to a `budgetCategoryId`. Provider/service costs, manual payables, and other
agreed costs should be represented here before payments or installments are
recorded.

Commitment routes:

- `POST /api/v1/wedding-plans/:weddingPlanId/financial-commitments`
- `GET /api/v1/wedding-plans/:weddingPlanId/financial-commitments`
- `GET /api/v1/financial-commitments/:id`
- `PATCH /api/v1/financial-commitments/:id`
- `DELETE /api/v1/financial-commitments/:id`

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

`sourceType` values are `PROVIDER_SERVICE`, `MANUAL_PAYABLE`,
`MANUAL_COMMITMENT`, and `OTHER`. The backend derives `status` from
`totalAmount - paidAmount` except when the commitment is explicitly cancelled.
`remainingAmount` is returned; clients must not ask users to type the remaining
amount for provider/service commitments.

Payment record routes:

- `POST /api/v1/financial-commitments/:id/payment-records`
- `GET /api/v1/financial-commitments/:id/payment-records`
- `GET /api/v1/wedding-plans/:weddingPlanId/financial-payment-records`
- `DELETE /api/v1/financial-payment-records/:id`

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
append-only ledger: `DELETE /api/v1/financial-payment-records/:id` creates one
`REVERSAL` row and returns
`deleted: false, reversed: true`; it never deletes the original row. Repeating
or concurrently submitting the same reversal returns the same single reversal.
The response includes `entryType`, `financialInstallmentId`, `reversalOfId`,
`reversedById`, and `reversible`. Creating or reversing a payment updates the
parent commitment `paidAmount`, derived
`status`, and `remainingAmount`.

Financial installment routes:

- `POST /api/v1/financial-commitments/:id/installments`
- `GET /api/v1/financial-commitments/:id/installments`
- `GET /api/v1/wedding-plans/:weddingPlanId/financial-installments/due`
- `PATCH /api/v1/financial-installments/:id/pay`
- `PATCH /api/v1/financial-installments/:id`
- `DELETE /api/v1/financial-installments/:id`

Financial installments always belong to a financial commitment. Paying a
financial installment locks its PostgreSQL row before reading state, creates a
payment record uniquely linked by `financialInstallmentId`, and updates the
parent commitment balance. Concurrent pay requests therefore create exactly
one payment. Reversing that payment creates one compensating ledger row and
returns the installment to `PENDING`; installments or commitments with payment
history cannot be hard-deleted through product APIs.

No unversioned financial aliases are exposed.

## Money Summary

Protected routes:

- `GET /api/v1/wedding-plans/:planId/money-summary`

Money summaries must remain permission-aware. Shared users without financial permissions must not receive private budget, expense, commitment, payment, or installment details.

Super Money UI consumes the canonical route and may use stable response-field aliases:

- `totalBudget`, `totalSpent`, `commitmentTotal`, and
  `commitmentRemainingTotal`.
- `confirmedCostTotal` / `totalConfirmedCost`, `paidTotal`,
  `outstandingTotal`, and `deficitOrSurplus`.
- `commitmentTotal`, `commitmentPaidTotal`, `commitmentRemainingTotal`,
  `providerCommitmentTotal`, and `manualPayableCommitmentTotal`.
- `paidInstallmentsCount`, `remainingInstallmentsCount`, and `nextInstallment`.
- `categorySummaries` with allocated, spent, confirmedCost, paid, outstanding,
  budgetRemaining, remaining, commitmentsCount, and installmentsCount values
  when permissions allow them.
- `financialWarnings` for budget exceeded, category exceeded, overdue/due-soon installments, or uncategorized expenses when computable.

Day/week/month financial reports are not a current contract. The backend exposes current aggregate totals only.

Money-summary arithmetic uses one product definition across the backend and
offline mobile summary:

- `totalSpent` is standalone actual money-out from paid `Expense` rows.
- `confirmedCostTotal` is standalone paid expenses plus active commitment
  totals, including legacy obligations only when they are not already mirrored.
- `paidTotal` is standalone paid expenses plus the paid balance of active
  commitments.
- `outstandingTotal` is the unpaid balance of commitments/compatible legacy
  obligations; it does not include already-paid standalone expenses.
- `remainingBudget` and `deficitOrSurplus` are the visible budget minus
  `confirmedCostTotal`.
- Category `confirmedCost` and `budgetRemaining` use the same formula. A
  commitment payment is never added again because it is already contained in
  that commitment's total.

Every field remains permission-aware. If a caller cannot view one component,
the summary combines only the components that caller may see and does not
reveal the hidden amount.

## Tasks

Protected routes:

- `POST /api/v1/wedding-plans/:weddingPlanId/tasks`
- `GET /api/v1/wedding-plans/:weddingPlanId/tasks`
- `GET /api/v1/wedding-plans/:weddingPlanId/tasks/summary`
- `GET /api/v1/tasks/:id`
- `POST /api/v1/tasks/:id/checklist`
- `PATCH /api/v1/tasks/:id/checklist/:itemId`
- `DELETE /api/v1/tasks/:id/checklist/:itemId`
- `PATCH /api/v1/tasks/:id/assign`
- `PATCH /api/v1/tasks/:id`
- `DELETE /api/v1/tasks/:id`

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

No unversioned task aliases are exposed.

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

- `GET /api/v1/wedding-plans/:weddingPlanId/timeline`

Response includes:

- `weddingDate`
- `upcomingTasks`
- `dueCommitments`
- `dueInstallments`

Shared members can see task timeline items. Financial due items are hidden unless the shared member has `canViewFinancialRecords` or `canManageFinancialRecords`.

## Sharing

Protected routes:

- `POST /api/v1/wedding-plans/:weddingPlanId/members`
- `GET /api/v1/wedding-plans/:weddingPlanId/members`
- `PATCH /api/v1/wedding-plans/:weddingPlanId/members/:memberId`
- `DELETE /api/v1/wedding-plans/:weddingPlanId/members/:memberId`
- `GET /api/v1/shared/wedding-plans`
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
  "canViewFinancialRecords": false,
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
  "canViewFinancialRecords": false,
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

- `GET /api/v1/wedding-plans/:weddingPlanId/guests`
- `POST /api/v1/wedding-plans/:weddingPlanId/guests`
- `POST /api/v1/wedding-plans/:weddingPlanId/guests/bulk`
- `GET /api/v1/wedding-plans/:weddingPlanId/guests/summary`
- `GET /api/v1/wedding-plans/:weddingPlanId/guest-groups`
- `POST /api/v1/wedding-plans/:weddingPlanId/guest-groups`
- `GET /api/v1/guests/:id`
- `PATCH /api/v1/guests/:id`
- `DELETE /api/v1/guests/:id`
- `PATCH /api/v1/guest-groups/:id`
- `DELETE /api/v1/guest-groups/:id`

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

No unversioned guest aliases are exposed.

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

- `GET /api/v1/cities`
- `GET /api/v1/provider-categories`
- `GET /api/v1/providers`
- `GET /api/v1/providers/:id`
- `GET /api/v1/providers/:id/services`
- `GET /api/v1/providers/:id/packages`
- `GET /api/v1/providers/:id/reviews`
- `GET /api/v1/services`
- `GET /api/v1/services/:id`
- `GET /api/v1/provider-categories`
- `GET /api/v1/providers`
- `GET /api/v1/providers/:id`

Fresh databases receive an additive baseline catalog of active Yemeni cities
and provider categories through migration
`20260714100000_seed_provider_reference_catalog`. The migration never renames,
reactivates, or deletes admin-managed catalog rows. Both reference endpoints
return active rows only; clients must expose loading, empty/error, and retry
states instead of rendering enabled selectors with no options.

Authenticated user routes:

- `POST /api/v1/providers/:id/favorite`
- `DELETE /api/v1/providers/:id/favorite`
- `GET /api/v1/me/favorite-providers`
- `POST /api/v1/providers/:id/quote-requests`
- `GET /api/v1/me/quote-requests`
- `GET /api/v1/me/quote-requests/:id`
- `PATCH /api/v1/me/quote-requests/:id/cancel`
- `POST /api/v1/providers/:id/reviews`
- `PATCH /api/v1/reviews/:id`
- `DELETE /api/v1/reviews/:id`

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
financial installments, tasks, payments, deposits, or confirmed bookings.

Provider dashboard routes:

- `POST /api/v1/provider/apply`
- `GET /api/v1/provider/me/profile`
- `PATCH /api/v1/provider/me/profile`
- `GET /api/v1/provider/me/summary`
- `GET /api/v1/provider/me/services`
- `POST /api/v1/provider/me/services`
- `GET /api/v1/provider/me/services/:id`
- `PATCH /api/v1/provider/me/services/:id`
- `DELETE /api/v1/provider/me/services/:id`
- `POST /api/v1/provider/me/services/:id/images`
- `PATCH /api/v1/provider/me/services/:serviceId/images/:imageId`
- `DELETE /api/v1/provider/me/services/:serviceId/images/:imageId`
- `GET /api/v1/provider/me/packages`
- `POST /api/v1/provider/me/packages`
- `PATCH /api/v1/provider/me/packages/:id`
- `DELETE /api/v1/provider/me/packages/:id`
- `GET /api/v1/provider/me/quote-requests`
- `GET /api/v1/provider/me/quote-requests/:id`
- `PATCH /api/v1/provider/me/quote-requests/:id/status`
- `POST /api/v1/provider/me/quote-requests/:id/offers`
- `PATCH /api/v1/provider/me/quote-offers/:id`
- `GET /api/v1/provider/me/reviews`

Known follow-up from the 2026-06-20 audit: quote request/offer permissions should be tightened before shared-plan users are allowed to manage quote decisions broadly.

## Quote Conversations And Media

Conversations are available only for a real quote request and only to its
requester and provider account. Open or unsolicited messaging is excluded.

- `POST /api/v1/conversations/quote-requests/:quoteRequestId` creates or returns the
  quote conversation.
- `GET /api/v1/conversations` lists the current account's conversations with
  optional `cursor` and `limit` (default 30, maximum 50), returning
  `{ items, nextCursor }`.
- `GET /api/v1/conversations/:id` returns the exact participant-authorized
  conversation summary, including mute/block/read metadata, so a direct route
  does not depend on that conversation appearing in the first inbox page.
- `GET /api/v1/conversations/:id/messages` returns paginated message history.
- `POST /api/v1/conversations/:id/messages` sends text and approved signed-media
  attachments.
- `GET /api/v1/conversations/:id/attachments/:attachmentId/download` refreshes a
  private attachment link after rechecking conversation membership.
- `PATCH /api/v1/conversations/:id/read`, `/mute`, and `/block` update participant
  state.
- `POST /api/v1/conversations/:id/report` creates a moderation report.

Conversation list responses include the aggregate `blocked` value plus
`blockedByMe`, `blockedByCounterpart`, and `counterpartLastReadAt` so clients
can distinguish who owns a block and show read receipts without exposing other
private participant state. `unreadCount` is derived for the current account.

Authenticated Socket.IO events are `conversation:join`,
`conversation:message`, and `conversation:read`. Server authorization is
rechecked before room access and message actions.

`POST /api/v1/media/uploads/presign` issues short-lived S3-compatible upload
URLs for approved purposes and declared size/MIME limits. The returned
`requiredHeaders` includes `If-None-Match: *`; clients must send it with the
signed upload so the new object key cannot overwrite an existing object. After
uploading, the client must call `POST /api/v1/media/uploads/verify` with the
object key and purpose.

Every presign first creates a durable account-owned upload ticket under a
rolling per-account count and declared-byte quota. The ticket moves atomically
from `PENDING` to `VERIFYING` to `VERIFIED`; it is marked consumed only when a
profile/provider/chat write actually uses it. One replica performs bounded
hourly cleanup under an advisory lock for expired uploads, stalled verification,
and verified-but-unconsumed uploads, while storage failures retain the ticket
for retry. Clients cannot mint a usable public URL or attachment reference from
the presign response alone.

Verification reads the complete stored object, checks account ownership,
stored byte/MIME limits, and the JPEG/PNG/WebP signature, then fully decodes one
non-animated image within 25 million input pixels and an 8192-pixel maximum
dimension. The server auto-orients and re-encodes the image without retaining
untrusted metadata or appended payload bytes. It conditionally replaces the
original only when the ETag still matches and marks that sanitized object as
verified; a concurrent verifier rechecks the resulting object instead of
blindly overwriting it. Avatar, provider profile, provider cover, service, and
chat writes repeat this verification server-side, so a client cannot persist
an unverified object by skipping the client verification call. Public
avatar/provider purposes return the canonical verified `publicUrl`. A verified
`chat-image` instead returns an opaque `attachmentRef` and `publicUrl: null`;
the database stores only that private object key.
Conversation/message responses replace it with a signed GET URL that expires
after 120 seconds and include `expiresAt`; they never expose the storage key.
All responses carrying these links use `Cache-Control: private, no-store`.
Arbitrary external attachment URLs are rejected. Environment-backed
private-bucket and Socket.IO smoke remain release gates.

## Admin APIs

Admin routes are JWT-protected and require admin authorization:

- `POST /api/v1/auth/admin/login` validates the admin password and returns only a
  short-lived MFA challenge after sending a `LOGIN` OTP.
- `POST /api/v1/auth/admin/login/complete` atomically consumes the challenge + OTP,
  returns a short-lived access JWT, and sets the rotating refresh token only as
  a path-scoped `HttpOnly`, `SameSite=Strict` cookie (`Secure` in production).
- `POST /api/v1/auth/admin/refresh` rotates that cookie and its server session.
- `POST /api/v1/auth/admin/logout` revokes the server session and clears the cookie.

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
masked phone suffix only. Financial installment/commitment notifications, notifications with a
financial entity, and even misclassified notifications carrying financial data
keys return a generic Arabic title/body, `financialDetailsRedacted: true`, and
`null` for `data`, `entityId`, `routeTarget`, and plan details. The general
admin API has no endpoint that reveals that hidden financial content. Search
does not query notification bodies, user phones, or reviewer phones. User-owned
notification routes use only the canonical `/api/v1/notifications` namespace.

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
- Transactional outbox events are retained through retry and exhausted events
  remain as `FAILED` dead letters. A cross-replica scheduler removes only
  `PROCESSED` receipts older than seven days every six hours. Account deletion
  removes notification/conversation outbox rows owned by that account inside
  the same database transaction.
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
| GET | `/admin/audit-logs` | `admin-audit.list` | 🔒 |
| GET | `/admin/cities` | `admin.listCities` | 🔒 |
| POST | `/admin/cities` | `admin.createCity` | 🔒 |
| DELETE | `/admin/cities/:id` | `admin.deleteCity` | 🔒 |
| PATCH | `/admin/cities/:id` | `admin.updateCity` | 🔒 |
| GET | `/admin/conversation-reports` | `admin.listConversationReports` | 🔒 |
| PATCH | `/admin/conversation-reports/:id/status` | `admin.updateConversationReportStatus` | 🔒 |
| GET | `/admin/dashboard/stats` | `admin.getDashboardStats` | 🔒 |
| GET | `/admin/notifications` | `admin.listNotifications` | 🔒 |
| DELETE | `/admin/notifications/:id` | `admin.deleteNotification` | 🔒 |
| PATCH | `/admin/notifications/:id/archive` | `admin.archiveNotification` | 🔒 |
| PATCH | `/admin/notifications/:id/read` | `admin.markNotificationRead` | 🔒 |
| GET | `/admin/notifications/unread-count` | `admin.getUnreadNotificationsCount` | 🔒 |
| GET | `/admin/provider-categories` | `admin.listCategories` | 🔒 |
| POST | `/admin/provider-categories` | `admin.createCategory` | 🔒 |
| DELETE | `/admin/provider-categories/:id` | `admin.deleteCategory` | 🔒 |
| PATCH | `/admin/provider-categories/:id` | `admin.updateCategory` | 🔒 |
| GET | `/admin/providers` | `admin.listProviders` | 🔒 |
| GET | `/admin/providers/:id` | `admin.getProvider` | 🔒 |
| PATCH | `/admin/providers/:id/activate` | `admin.activateProvider` | 🔒 |
| PATCH | `/admin/providers/:id/approve` | `admin.approveProvider` | 🔒 |
| PATCH | `/admin/providers/:id/reject` | `admin.rejectProvider` | 🔒 |
| PATCH | `/admin/providers/:id/request-changes` | `admin.requestProviderChanges` | 🔒 |
| PATCH | `/admin/providers/:id/suspend` | `admin.suspendProvider` | 🔒 |
| GET | `/admin/providers/applications` | `admin.listProviderApplications` | 🔒 |
| GET | `/admin/providers/applications/:id` | `admin.getProviderApplication` | 🔒 |
| GET | `/admin/reports/overview` | `admin.getReportsOverview` | 🔒 |
| GET | `/admin/reviews` | `admin.listReviews` | 🔒 |
| DELETE | `/admin/reviews/:id` | `admin.hideReview` | 🔒 |
| PATCH | `/admin/reviews/:id/status` | `admin.updateReviewStatus` | 🔒 |
| GET | `/admin/services` | `admin.listServices` | 🔒 |
| POST | `/admin/services` | `admin.createService` | 🔒 |
| DELETE | `/admin/services/:id` | `admin.deleteService` | 🔒 |
| PATCH | `/admin/services/:id` | `admin.updateService` | 🔒 |
| GET | `/admin/users` | `admin.listUsers` | 🔒 |
| GET | `/admin/users/:id` | `admin.getUser` | 🔒 |
| PATCH | `/admin/users/:id/activate` | `admin.activateUser` | 🔒 |
| PATCH | `/admin/users/:id/disable` | `admin.disableUser` | 🔒 |
| POST | `/api/v1/auth/admin/login` | `auth.startAdminLogin` |  |
| POST | `/api/v1/auth/admin/login/complete` | `auth.completeAdminLogin` |  |
| POST | `/api/v1/auth/admin/logout` | `auth.logoutAdmin` |  |
| POST | `/api/v1/auth/admin/refresh` | `auth.refreshAdmin` |  |
| POST | `/api/v1/auth/login` | `auth.login` |  |
| POST | `/api/v1/auth/logout` | `auth.logout` | 🔒 |
| POST | `/api/v1/auth/logout-all` | `auth.logoutAll` | 🔒 |
| GET | `/api/v1/auth/me` | `auth.me` | 🔒 |
| POST | `/api/v1/auth/otp/request` | `auth.requestOtp` |  |
| POST | `/api/v1/auth/otp/verify` | `auth.verifyOtp` |  |
| POST | `/api/v1/auth/password-reset/confirm` | `auth.confirmPasswordReset` |  |
| POST | `/api/v1/auth/password-reset/request` | `auth.requestPasswordReset` |  |
| POST | `/api/v1/auth/refresh` | `auth.refresh` |  |
| POST | `/api/v1/auth/register` | `auth.register` |  |
| POST | `/api/v1/auth/register/complete` | `auth.completeRegistration` |  |
| DELETE | `/api/v1/budget-categories/:id` | `budget-categories.remove` | 🔒 |
| PATCH | `/api/v1/budget-categories/:id` | `budget-categories.update` | 🔒 |
| GET | `/api/v1/cities` | `marketplace.findCities` |  |
| GET | `/api/v1/conversations` | `conversations.list` | 🔒 |
| GET | `/api/v1/conversations/:id` | `conversations.get` | 🔒 |
| GET | `/api/v1/conversations/:id/attachments/:attachmentId/download` | `conversations.downloadAttachment` | 🔒 |
| PATCH | `/api/v1/conversations/:id/block` | `conversations.block` | 🔒 |
| GET | `/api/v1/conversations/:id/messages` | `conversations.messages` | 🔒 |
| POST | `/api/v1/conversations/:id/messages` | `conversations.send` | 🔒 |
| PATCH | `/api/v1/conversations/:id/mute` | `conversations.mute` | 🔒 |
| PATCH | `/api/v1/conversations/:id/read` | `conversations.markRead` | 🔒 |
| POST | `/api/v1/conversations/:id/report` | `conversations.report` | 🔒 |
| POST | `/api/v1/conversations/quote-requests/:quoteRequestId` | `conversations.ensureForQuote` | 🔒 |
| GET | `/api/v1/dashboard/home` | `dashboard.getHome` | 🔒 |
| DELETE | `/api/v1/expenses/:id` | `expenses.remove` | 🔒 |
| GET | `/api/v1/expenses/:id` | `expenses.findOne` | 🔒 |
| PATCH | `/api/v1/expenses/:id` | `expenses.update` | 🔒 |
| DELETE | `/api/v1/financial-commitments/:id` | `financial-commitments.remove` | 🔒 |
| GET | `/api/v1/financial-commitments/:id` | `financial-commitments.findOne` | 🔒 |
| PATCH | `/api/v1/financial-commitments/:id` | `financial-commitments.update` | 🔒 |
| GET | `/api/v1/financial-commitments/:id/installments` | `financial-commitments.listInstallments` | 🔒 |
| POST | `/api/v1/financial-commitments/:id/installments` | `financial-commitments.createInstallment` | 🔒 |
| GET | `/api/v1/financial-commitments/:id/payment-records` | `financial-commitments.listPaymentRecords` | 🔒 |
| POST | `/api/v1/financial-commitments/:id/payment-records` | `financial-commitments.createPaymentRecord` | 🔒 |
| DELETE | `/api/v1/financial-installments/:id` | `financial-commitments.remove` | 🔒 |
| PATCH | `/api/v1/financial-installments/:id` | `financial-commitments.update` | 🔒 |
| PATCH | `/api/v1/financial-installments/:id/pay` | `financial-commitments.pay` | 🔒 |
| DELETE | `/api/v1/financial-payment-records/:id` | `financial-commitments.remove` | 🔒 |
| DELETE | `/api/v1/guest-groups/:id` | `guests.removeGroup` | 🔒 |
| PATCH | `/api/v1/guest-groups/:id` | `guests.updateGroup` | 🔒 |
| DELETE | `/api/v1/guests/:id` | `guests.remove` | 🔒 |
| GET | `/api/v1/guests/:id` | `guests.findOne` | 🔒 |
| PATCH | `/api/v1/guests/:id` | `guests.update` | 🔒 |
| GET | `/api/v1/invites/:token` | `sharing.getInvite` | 🔒 |
| POST | `/api/v1/invites/:token/accept` | `sharing.acceptInvite` | 🔒 |
| POST | `/api/v1/invites/:token/decline` | `sharing.declineInvite` | 🔒 |
| GET | `/api/v1/invites/mine` | `sharing.findMyInvites` | 🔒 |
| GET | `/api/v1/me` | `me.me` | 🔒 |
| GET | `/api/v1/me/favorite-providers` | `marketplace.findMyFavoriteProviders` | 🔒 |
| GET | `/api/v1/me/quote-requests` | `marketplace.findMyQuoteRequests` | 🔒 |
| GET | `/api/v1/me/quote-requests/:id` | `marketplace.findMyQuoteRequest` | 🔒 |
| PATCH | `/api/v1/me/quote-requests/:id/cancel` | `marketplace.cancelMyQuoteRequest` | 🔒 |
| POST | `/api/v1/media/uploads/presign` | `media.presign` | 🔒 |
| POST | `/api/v1/media/uploads/verify` | `media.verify` | 🔒 |
| GET | `/api/v1/notifications` | `notifications.list` | 🔒 |
| DELETE | `/api/v1/notifications/:id` | `notifications.remove` | 🔒 |
| GET | `/api/v1/notifications/:id` | `notifications.findOne` | 🔒 |
| PATCH | `/api/v1/notifications/:id/archive` | `notifications.archive` | 🔒 |
| PATCH | `/api/v1/notifications/:id/read` | `notifications.markRead` | 🔒 |
| PATCH | `/api/v1/notifications/read-all` | `notifications.markAllRead` | 🔒 |
| GET | `/api/v1/notifications/unread-count` | `notifications.unreadCount` | 🔒 |
| POST | `/api/v1/onboarding/complete` | `onboarding.complete` | 🔒 |
| POST | `/api/v1/onboarding/import-local` | `onboarding.importLocal` | 🔒 |
| GET | `/api/v1/provider-categories` | `marketplace.findCategories` |  |
| POST | `/api/v1/provider/apply` | `provider-dashboard.apply` | 🔒 |
| GET | `/api/v1/provider/me/packages` | `provider-dashboard.findPackages` | 🔒 |
| POST | `/api/v1/provider/me/packages` | `provider-dashboard.createPackage` | 🔒 |
| DELETE | `/api/v1/provider/me/packages/:id` | `provider-dashboard.deactivatePackage` | 🔒 |
| PATCH | `/api/v1/provider/me/packages/:id` | `provider-dashboard.updatePackage` | 🔒 |
| GET | `/api/v1/provider/me/profile` | `provider-dashboard.getProfile` | 🔒 |
| PATCH | `/api/v1/provider/me/profile` | `provider-dashboard.updateProfile` | 🔒 |
| PATCH | `/api/v1/provider/me/quote-offers/:id` | `provider-dashboard.updateQuoteOffer` | 🔒 |
| GET | `/api/v1/provider/me/quote-requests` | `provider-dashboard.findQuoteRequests` | 🔒 |
| GET | `/api/v1/provider/me/quote-requests/:id` | `provider-dashboard.findQuoteRequest` | 🔒 |
| POST | `/api/v1/provider/me/quote-requests/:id/offers` | `provider-dashboard.createQuoteOffer` | 🔒 |
| PATCH | `/api/v1/provider/me/quote-requests/:id/status` | `provider-dashboard.updateQuoteRequestStatus` | 🔒 |
| GET | `/api/v1/provider/me/reviews` | `provider-dashboard.findReviews` | 🔒 |
| GET | `/api/v1/provider/me/services` | `provider-dashboard.findServices` | 🔒 |
| POST | `/api/v1/provider/me/services` | `provider-dashboard.createService` | 🔒 |
| DELETE | `/api/v1/provider/me/services/:id` | `provider-dashboard.deactivateService` | 🔒 |
| GET | `/api/v1/provider/me/services/:id` | `provider-dashboard.findService` | 🔒 |
| PATCH | `/api/v1/provider/me/services/:id` | `provider-dashboard.updateService` | 🔒 |
| POST | `/api/v1/provider/me/services/:id/images` | `provider-dashboard.createServiceImage` | 🔒 |
| DELETE | `/api/v1/provider/me/services/:serviceId/images/:imageId` | `provider-dashboard.deleteServiceImage` | 🔒 |
| PATCH | `/api/v1/provider/me/services/:serviceId/images/:imageId` | `provider-dashboard.updateServiceImage` | 🔒 |
| GET | `/api/v1/provider/me/summary` | `provider-dashboard.getSummary` | 🔒 |
| GET | `/api/v1/providers` | `marketplace.findProviders` |  |
| GET | `/api/v1/providers/:id` | `marketplace.findProvider` |  |
| DELETE | `/api/v1/providers/:id/favorite` | `marketplace.unfavoriteProvider` | 🔒 |
| POST | `/api/v1/providers/:id/favorite` | `marketplace.favoriteProvider` | 🔒 |
| GET | `/api/v1/providers/:id/packages` | `marketplace.findProviderPackages` |  |
| POST | `/api/v1/providers/:id/quote-requests` | `marketplace.createQuoteRequest` | 🔒 |
| GET | `/api/v1/providers/:id/reviews` | `marketplace.findProviderReviews` |  |
| POST | `/api/v1/providers/:id/reviews` | `marketplace.createReview` | 🔒 |
| GET | `/api/v1/providers/:id/services` | `marketplace.findProviderServices` |  |
| PATCH | `/api/v1/quote-offers/:id/accept` | `marketplace.acceptOffer` | 🔒 |
| PATCH | `/api/v1/quote-offers/:id/reject` | `marketplace.rejectOffer` | 🔒 |
| GET | `/api/v1/quote-requests/:id` | `marketplace.findQuoteRequest` | 🔒 |
| PATCH | `/api/v1/quote-requests/:id/cancel` | `marketplace.cancelQuoteRequest` | 🔒 |
| DELETE | `/api/v1/reviews/:id` | `marketplace.deleteReview` | 🔒 |
| PATCH | `/api/v1/reviews/:id` | `marketplace.updateReview` | 🔒 |
| GET | `/api/v1/services` | `marketplace.findServices` |  |
| GET | `/api/v1/services/:id` | `marketplace.findService` |  |
| GET | `/api/v1/shared/wedding-plans` | `sharing.findSharedPlans` | 🔒 |
| DELETE | `/api/v1/tasks/:id` | `tasks.remove` | 🔒 |
| GET | `/api/v1/tasks/:id` | `tasks.findOne` | 🔒 |
| PATCH | `/api/v1/tasks/:id` | `tasks.update` | 🔒 |
| PATCH | `/api/v1/tasks/:id/assign` | `tasks.assign` | 🔒 |
| POST | `/api/v1/tasks/:id/checklist` | `tasks.createChecklistItem` | 🔒 |
| DELETE | `/api/v1/tasks/:id/checklist/:itemId` | `tasks.removeChecklistItem` | 🔒 |
| PATCH | `/api/v1/tasks/:id/checklist/:itemId` | `tasks.updateChecklistItem` | 🔒 |
| GET | `/api/v1/users/lookup` | `users.lookupByPhone` | 🔒 |
| DELETE | `/api/v1/users/me` | `users.deleteMe` | 🔒 |
| PATCH | `/api/v1/users/me` | `users.updateMe` | 🔒 |
| GET | `/api/v1/users/me/settings` | `users.getSettings` | 🔒 |
| PATCH | `/api/v1/users/me/settings` | `users.updateSettings` | 🔒 |
| GET | `/api/v1/wedding-plans` | `wedding-plans.findAccessible` | 🔒 |
| POST | `/api/v1/wedding-plans` | `wedding-plans.create` | 🔒 |
| GET | `/api/v1/wedding-plans/:id` | `wedding-plans.findOne` | 🔒 |
| PATCH | `/api/v1/wedding-plans/:id` | `wedding-plans.update` | 🔒 |
| PATCH | `/api/v1/wedding-plans/:id/archive` | `wedding-plans.archive` | 🔒 |
| POST | `/api/v1/wedding-plans/:id/set-active` | `wedding-plans.setActive` | 🔒 |
| GET | `/api/v1/wedding-plans/:planId/dashboard-summary` | `dashboard.getDashboardSummary` | 🔒 |
| GET | `/api/v1/wedding-plans/:planId/money-summary` | `money-summary.getMoneySummary` | 🔒 |
| GET | `/api/v1/wedding-plans/:weddingPlanId/budget-categories` | `budget-categories.findForPlan` | 🔒 |
| POST | `/api/v1/wedding-plans/:weddingPlanId/budget-categories` | `budget-categories.create` | 🔒 |
| GET | `/api/v1/wedding-plans/:weddingPlanId/expenses` | `expenses.findForPlan` | 🔒 |
| POST | `/api/v1/wedding-plans/:weddingPlanId/expenses` | `expenses.create` | 🔒 |
| GET | `/api/v1/wedding-plans/:weddingPlanId/expenses/summary` | `expenses.summary` | 🔒 |
| GET | `/api/v1/wedding-plans/:weddingPlanId/financial-commitments` | `financial-commitments.findForPlan` | 🔒 |
| POST | `/api/v1/wedding-plans/:weddingPlanId/financial-commitments` | `financial-commitments.create` | 🔒 |
| GET | `/api/v1/wedding-plans/:weddingPlanId/financial-installments/due` | `financial-commitments.dueForPlan` | 🔒 |
| GET | `/api/v1/wedding-plans/:weddingPlanId/financial-payment-records` | `financial-commitments.findForPlan` | 🔒 |
| GET | `/api/v1/wedding-plans/:weddingPlanId/guest-groups` | `guests.findGroups` | 🔒 |
| POST | `/api/v1/wedding-plans/:weddingPlanId/guest-groups` | `guests.createGroup` | 🔒 |
| GET | `/api/v1/wedding-plans/:weddingPlanId/guests` | `guests.findForPlan` | 🔒 |
| POST | `/api/v1/wedding-plans/:weddingPlanId/guests` | `guests.create` | 🔒 |
| POST | `/api/v1/wedding-plans/:weddingPlanId/guests/bulk` | `guests.bulkCreate` | 🔒 |
| GET | `/api/v1/wedding-plans/:weddingPlanId/guests/summary` | `guests.summary` | 🔒 |
| GET | `/api/v1/wedding-plans/:weddingPlanId/invites` | `sharing.findInvites` | 🔒 |
| POST | `/api/v1/wedding-plans/:weddingPlanId/invites` | `sharing.createInvite` | 🔒 |
| DELETE | `/api/v1/wedding-plans/:weddingPlanId/invites/:inviteId` | `sharing.cancelInvite` | 🔒 |
| GET | `/api/v1/wedding-plans/:weddingPlanId/members` | `sharing.findMembers` | 🔒 |
| POST | `/api/v1/wedding-plans/:weddingPlanId/members` | `sharing.createMember` | 🔒 |
| DELETE | `/api/v1/wedding-plans/:weddingPlanId/members/:memberId` | `sharing.removeMember` | 🔒 |
| PATCH | `/api/v1/wedding-plans/:weddingPlanId/members/:memberId` | `sharing.updateMember` | 🔒 |
| GET | `/api/v1/wedding-plans/:weddingPlanId/permissions/me` | `sharing.permissionsForMe` | 🔒 |
| GET | `/api/v1/wedding-plans/:weddingPlanId/quote-requests` | `marketplace.findQuoteRequests` | 🔒 |
| POST | `/api/v1/wedding-plans/:weddingPlanId/quote-requests` | `marketplace.createQuoteRequest` | 🔒 |
| GET | `/api/v1/wedding-plans/:weddingPlanId/tasks` | `tasks.findForPlan` | 🔒 |
| POST | `/api/v1/wedding-plans/:weddingPlanId/tasks` | `tasks.create` | 🔒 |
| GET | `/api/v1/wedding-plans/:weddingPlanId/tasks/summary` | `tasks.summary` | 🔒 |
| GET | `/api/v1/wedding-plans/:weddingPlanId/timeline` | `timeline.getForPlan` | 🔒 |
| GET | `/api/v1/wedding-plans/active` | `wedding-plans.findActive` | 🔒 |
| GET | `/api/v1/wedding-plans/my` | `wedding-plans.findMine` | 🔒 |
| GET | `/health` | `health.getCompatibilityHealth` |  |
| GET | `/live` | `health.getLiveness` |  |
| GET | `/metrics` | `metrics.metrics` |  |
| GET | `/ready` | `health.getReadiness` |  |
<!-- DOCS-SYNC:END -->
