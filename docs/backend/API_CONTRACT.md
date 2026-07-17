# API Contract

This document is the route-level source of truth for the current Aarast backend contract. Other Markdown files should link here instead of copying endpoint lists.

Current documentation snapshot: 2026-07-17.

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
  "phone": "+967700000000"
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

The mobile client keeps the name and password draft in memory; the password is
not sent before phone proof. It sends the complete draft to
`POST /api/v1/auth/register/complete` with the six-digit `otpCode`. Production
responses never echo the code.

Completion request:

```json
{
  "name": "Rashad",
  "phone": "+967700000000",
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
    "email": null,
    "role": "USER",
    "status": "ACTIVE",
    "createdAt": "2026-06-04T00:00:00.000Z",
    "updatedAt": "2026-06-04T00:00:00.000Z"
  }
}
```

The OTP is consumed atomically in the same serializable transaction that
creates the verified User. A wrong, expired, already-consumed, or concurrently
replayed code creates no account and issues no access or refresh token. Email is
intentionally absent because a phone OTP cannot prove ownership of an email
address. The initial response is generic; phone conflicts are checked only
after valid phone proof so the start endpoint is not an account-enumeration
oracle.

After valid phone proof, an existing unverified `USER` or `PROVIDER` row is
claimed in place: its id, role, relations, and provider data are preserved while
the application password, display name, canonical phone, and verification time
are set atomically. A verified existing application account returns the stable
`ACCOUNT_ALREADY_EXISTS` code. For an `ADMIN` row, registration sets only the
separate `appPasswordHash`; it never changes the administrator password, role,
name, or MFA contract. The app display name/profile is stored separately and
the app response is projected as a normal `USER`. A second app enrollment returns
`ADMIN_APP_PASSWORD_ALREADY_SET`.

### `POST /api/v1/auth/login`

Request:

```json
{
  "phone": "+967700000000",
  "password": "secret123"
}
```

Response shape matches register.

An administrator may also use the wedding application after enrolling a
separate application password through the verified registration flow. General
application login reads `appPasswordHash` for an administrator; browser admin
login reads only `passwordHash`. Application password or OTP sessions never
carry the `admin_mfa` assurance. Every administration route requires the
dedicated admin password-plus-OTP flow and rejects an ordinary application
token through `AdminGuard`; the application response also omits the
administrator-role metadata and permission list.

Every application-facing relation (members, invitations, conversations,
reviews, quotes, and dashboard summaries) resolves an administrator through
`appName`/`appAvatarUrl` and never through the browser-admin profile. An
enrolled administrator may also create a provider application identity: that
changes only `appRole` and the provider profile, while the database security
role remains `ADMIN`.

Password login, refresh, and protected JWT routes reject accounts whose
`phoneVerifiedAt` is null. Existing unverified accounts must prove phone
ownership through OTP (or a password-reset OTP) before receiving a session.
Five failed password attempts within fifteen minutes lock that normalized
account identifier for fifteen minutes. Application and administrator lock
realms are independent, so one surface cannot lock the other. PostgreSQL stores only an
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

- Application and administration refresh tokens are separately scoped in both
  their opaque prefix and the persisted `RefreshToken.scope` column.
  `/api/v1/auth/refresh` rejects administration tokens, and
  `/api/v1/auth/admin/refresh` rejects application tokens. A general
  application session can never be upgraded into an MFA-assured administrator
  session through refresh.
- `POST /api/v1/auth/refresh` rotates one valid refresh token and returns a new access
  and refresh pair. Reuse of a revoked/expired token is rejected.
- `POST /api/v1/auth/logout` revokes the supplied application refresh token;
  when omitted it revokes all application sessions for that user.
- `POST /api/v1/auth/logout-all` revokes all active application refresh
  sessions. Administrator logout/recovery affects only administrator sessions.

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
  Consumes the OTP, sets the new password (min 6 chars, max 72 UTF-8 bytes),
  and revokes every application refresh token so app sessions die with the old
  password without logging out the independent administrator realm.
  Before valid phone proof, unknown phones and wrong codes are indistinguishable.
  After a correct OTP, a missing application account returns
  `ACCOUNT_NOT_FOUND_AFTER_PHONE_PROOF` and a disabled account returns
  `ACCOUNT_DISABLED_AFTER_PHONE_PROOF`, allowing the mobile UI to offer a safe
  create-account or support action. For an administrator, this route changes
  only an already-enrolled `appPasswordHash`; it never changes `passwordHash`.

### Administrator password recovery

- `POST /api/v1/auth/admin/password-reset/request` — body `{ phone }`. Returns
  one neutral, opaque challenge for active admins, non-admins, disabled users,
  and unknown phones. Every well-formed request executes the same quota,
  bcrypt, and WhatsApp delivery path; only an active administrator can complete
  the reset. The challenge stores an HMAC subject digest, token hash, and exact
  OTP relation, never the raw token or phone.
- `POST /api/v1/auth/admin/password-reset/confirm` — body
  `{ challengeToken, code, newPassword }`. Requires a 12-72 character password
  containing an English letter and a digit, with a hard maximum of 72 UTF-8
  bytes. Success changes only the browser-admin `passwordHash`, revokes only
  administrator refresh sessions and login/recovery challenges, consumes active
  administrator OTPs, and does not create a session. Invalid, expired,
  replayed, unknown, and non-admin challenges return
  the same `ADMIN_RESET_INVALID_OR_EXPIRED` code.

A definitive WhatsApp delivery failure returns the same `503` for every phone
and leaves no usable challenge. This preserves honest transport feedback
without disclosing administrator account existence through body or timing.

Additional current auth/profile routes:

- `POST /api/v1/auth/otp/request`
- `POST /api/v1/auth/otp/verify`
- `PATCH /api/v1/users/me`
- `DELETE /api/v1/users/me`
  - deletes an ordinary wedding-app account and its owned data;
  - refuses deletion when the database identity is an administrator, so an
    application bearer can never erase the separate administrator identity.
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

Administrator MFA uses the private `ADMIN_LOGIN` purpose, never the public
`LOGIN` purpose. Each password-bound login challenge references the exact OTP
row it issued, so a public app request cannot replace, consume, or satisfy an
administrator challenge. Expired OTP/login/reset security rows are retained for
one day, then removed by one advisory-lock-elected replica.

OpenWA delivery has an explicit acknowledgement contract. Success requires a
2xx response containing both a non-empty `messageId` and
`deliveryStatus: "SENT"`. A 503 is definitive only when its safe body code is
`NOT_ATTEMPTED` or `REJECTED`; those outcomes invalidate the newly created code
and return the generic unavailable response. `DELIVERY_UNCERTAIN`, an unknown or
malformed 5xx, a timeout/transport break, or a 2xx acknowledgement missing the
required fields may occur after WhatsApp accepted the message. In those cases
the code remains active and the request returns `200`, `delivery: "WHATSAPP"`,
and a safe `message` asking the user to enter the code if it arrives. The
response never echoes the OTP. This prevents an already delivered code from
being invalidated and avoids an immediate duplicate send.

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
- `financialWarnings`: simple computable warnings such as budget exceeded or a payment schedule due soon.

- `importantItems`: actionable task/payment-schedule/provider cards for "الأهم اليوم".
- `planProviders`: providers actually linked to the current WeddingPlan.
- `importantNotifications`: latest user-owned notifications for this WeddingPlan.
- `generatedAt`: server timestamp used by the mobile sync/status copy.

Dashboard `remainingBudget` and the money-card usage ratio use confirmed cost:
the sum of non-cancelled WeddingCost totals. CostPayment rows change the
paid/outstanding split and are not added to cost a second time. A pending
PaymentSchedule changes reminder state only; it does not deduct or reserve
outstanding money and cannot block a direct payment.

Payment-schedule details appear only when the current user has `canViewMoney`.
Notifications are always scoped to the authenticated
user. Provider cards are planning/reference data only and do not imply paid
booking, deposits, provider settlement/payment-processing status, loans,
credit, financing, or AI. This does not refer to the user's manual CostPayment
ledger.

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
scheduler idempotently repairs task and payment-schedule reminders.

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

## General Budget And Budget Categories

The optional general budget is `WeddingPlan.estimatedBudget`. The canonical
money setup write is the protected atomic route:

- `PUT /api/v1/wedding-plans/:planId/money-budget`

Its body contains `totalBudget`, `currency`, and `categories`:

```json
{
  "totalBudget": "3000000.00",
  "currency": "YER",
  "categories": []
}
```

`categories` may be an empty array so a user can save the general budget first
and add categories later. Null `totalBudget` means the general budget is unset.
The response contains the refreshed `summary`, canonical `categories`, and an
`idMap` for client-generated category IDs. The backend and offline client must
never replace null with the sum of category allocations.

Protected category routes:

- `POST /api/v1/wedding-plans/:weddingPlanId/budget-categories`
- `GET /api/v1/wedding-plans/:weddingPlanId/budget-categories`
- `PATCH /api/v1/budget-categories/:id`
- `DELETE /api/v1/budget-categories/:id`

Create request:

```json
{
  "name": "Hall",
  "allocatedAmount": "500000.00"
}
```

Category allocations are non-negative. Any positive allocation requires a
non-null general budget, and the sum of allocations may not exceed that budget.
A category referenced by any cost cannot be deleted until those costs are moved
or removed. All reads require `canViewMoney`; all mutations require
`canManageMoney`.

## Wedding Costs

`WeddingCost` is the only cost backbone. Every cost belongs to exactly one
budget category. It may optionally reference an Aarast provider/accepted quote
or an external party, but provider and external-party modes are mutually
exclusive. `WeddingCost` has no due-date field. `agreementDate` records when the
cost was agreed; every payment-reminder date belongs to
`PaymentSchedule.dueDate`.

Protected routes:

- `POST /api/v1/wedding-plans/:weddingPlanId/costs`
- `GET /api/v1/wedding-plans/:weddingPlanId/costs`
- `GET /api/v1/costs/:id`
- `PATCH /api/v1/costs/:id`
- `DELETE /api/v1/costs/:id`
- `POST /api/v1/costs/:id/cancel`

Create request:

```json
{
  "budgetCategoryId": "category_id",
  "title": "Hall agreement",
  "totalAmount": "500000.00",
  "initialPaymentAmount": "100000.00",
  "providerId": "provider_id",
  "quoteOfferId": "quote_offer_id",
  "agreementDate": "2026-07-06T00:00:00.000Z",
  "note": "Optional note"
}
```

For an external party, omit `providerId` and `quoteOfferId` and send optional
`partyName` and `partyPhone`. `totalAmount` must be positive.
`initialPaymentAmount`, when present, must be positive and no greater than the
total; the cost and initial CostPayment commit atomically. Update requests may
change the category, title, total, party/provider context, agreement date, and
note but cannot set a due date, paid amount, or derived payment status.

Accepted quote data may prefill this request only after explicit user
confirmation. Quote acceptance itself returns `automaticCostCreated: false`
and never invokes the cost route. Hard delete is limited to costs without
ledger history; cancellation is explicit and must not erase paid money.

## Cost Payments

Protected routes:

- `POST /api/v1/costs/:id/payments`
- `GET /api/v1/costs/:id/payments`
- `GET /api/v1/wedding-plans/:weddingPlanId/cost-payments`
- `GET /api/v1/cost-payments/:id`
- `POST /api/v1/cost-payments/:id/reverse`

Create request:

```json
{
  "amount": "100000.00",
  "paidAt": "2026-07-06T00:00:00.000Z",
  "method": "cash",
  "note": "Optional note"
}
```

Payment input never accepts category, provider, party, or WeddingPlan ids; they
are inherited from the selected cost. The amount must be positive and may not
exceed the row-locked outstanding cost. Pending payment schedules are ignored
for this limit because reminders do not reserve money or restrict direct
payments.

Payments are an append-only ledger. Reversal request:

```json
{ "reason": "Incorrect amount" }
```

Reversal creates one immutable `REVERSAL` row and retains the original payment.
Retries and concurrent submissions return the same single reversal rather than
duplicating it. There is no payment DELETE route.

## Payment Schedules

A `PaymentSchedule` is a non-reserving reminder under one cost, not a separate
cost or paid record. Its required `dueDate` is the only payment-reminder date in
the money contract. A pending schedule contributes nothing to confirmed cost,
paid, outstanding, or remaining-budget totals; it does not deduct or reserve
money and cannot block a direct payment.

Protected routes:

- `POST /api/v1/costs/:id/payment-schedules`
- `GET /api/v1/costs/:id/payment-schedules`
- `GET /api/v1/wedding-plans/:weddingPlanId/payment-schedules/due`
- `PATCH /api/v1/payment-schedules/:id`
- `DELETE /api/v1/payment-schedules/:id`
- `POST /api/v1/payment-schedules/:id/pay`

Create request:

```json
{
  "amount": "100000.00",
  "dueDate": "2026-12-15T00:00:00.000Z",
  "note": "Optional note"
}
```

On create and update, `amount` must be positive and no greater than the current
row-locked outstanding cost. The check is per reminder: other pending schedules
are not summed because they reserve nothing. Update accepts only `amount`,
`dueDate`, and `note`; clients cannot submit status or paid-at fields.

Paying accepts optional `paidAt`, `method`, and `note`, locks the schedule and
cost, rejects a reminder whose amount now exceeds the current outstanding cost,
creates one linked CostPayment, and makes concurrent retries idempotent. Any
direct or scheduled payment that fully pays the cost cancels every remaining
pending reminder. Reversing a schedule-linked payment reopens that schedule.
Paid schedules and schedules with payment history cannot be hard-deleted.

## Money Summary

Protected route:

- `GET /api/v1/wedding-plans/:planId/money-summary`

The response is one nested contract with no legacy aliases:

```json
{
  "weddingPlanId": "plan_id",
  "currency": "YER",
  "budget": {
    "total": "1500000.00",
    "allocated": "900000.00",
    "unallocated": "600000.00",
    "confirmedCost": "700000.00",
    "remaining": "800000.00"
  },
  "costs": {
    "total": "700000.00",
    "paid": "250000.00",
    "outstanding": "450000.00",
    "count": 3
  },
  "paymentSchedules": {
    "totalCount": 2,
    "upcomingCount": 1,
    "overdueCount": 1,
    "paidCount": 0,
    "next": {
      "id": "schedule_id",
      "weddingCostId": "cost_id",
      "amount": "100000.00",
      "dueAt": "2026-12-15T00:00:00.000Z",
      "status": "PENDING",
      "isOverdue": false
    }
  },
  "categories": [
    {
      "categoryId": "category_id",
      "name": "Hall",
      "allocatedAmount": "500000.00",
      "confirmedCost": "400000.00",
      "paid": "100000.00",
      "outstanding": "300000.00",
      "remainingAllocation": "100000.00",
      "costsCount": 1,
      "paymentSchedulesCount": 1,
      "overBudget": false
    }
  ],
  "warnings": [],
  "permissions": {
    "canViewMoney": true,
    "canManageMoney": true
  }
}
```

`budget.total` is the optional general budget and remains null when unset.
`budget.allocated` is still reported, but it never becomes the general budget;
`unallocated` and `remaining` are null when total is null. `costs.total` and
`budget.confirmedCost` are the sum of non-cancelled WeddingCost totals.
`costs.paid` is the net CostPayment ledger after reversals, and
`costs.outstanding` is total minus paid. Category values use the same rules.
Pending PaymentSchedule rows affect only schedule counts, `next`, and warning
types `PAYMENT_SCHEDULE_OVERDUE` or `PAYMENT_SCHEDULE_DUE_SOON`; they never
reserve outstanding balance or reduce direct-payment capacity. Schedule-warning
`amount` is therefore `null`: overlapping reminder amounts must not be presented
as debt or summed money. Callers use the warning type and schedule counts.

Callers without `canViewMoney` receive no private money values; hidden values
are not converted to zeros. Mutating routes require `canManageMoney`.

Removed prelaunch expense, commitment, financial-payment, and financial-
installment routes are not aliases and must return `404`.

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
- `duePaymentSchedules`

Each `duePaymentSchedules` item contains `id`, `costId`, `costTitle`, `amount`,
`dueDate`, `status`, and `isOverdue`.

Shared members can see task timeline items. Payment-schedule items are hidden
unless the shared member has `canViewMoney`.

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
- `GET /api/v1/wedding-plans/:weddingPlanId/invites`
- `POST /api/v1/wedding-plans/:weddingPlanId/invites/:inviteId/reissue`
- `DELETE /api/v1/wedding-plans/:weddingPlanId/invites/:inviteId`
- `GET /api/v1/invites/mine`
- `GET /api/v1/invites/:token`
- `POST /api/v1/invites/:token/accept`
- `POST /api/v1/invites/:token/decline`
- `GET /api/v1/wedding-plans/:weddingPlanId/permissions/me`

Invite token preview is not a public endpoint. The invite detail route requires
an authenticated user and returns only invitations targeted to that user id or
an equivalent normalized phone number.

The public web origin may serve a static
`https://aarast.shadowgardn.com/invites/TOKEN` landing for link previews and
the native-app CTA. That page is not an API route, performs no database lookup,
and exposes only generic metadata. It must never reveal invite validity, plan
names, dates, phone numbers, permissions, or participant data.

External invite tokens are random bearer values returned only when an invite is
created. PostgreSQL stores their SHA-256 fingerprints, never the raw value.
Authenticated invite lists use the invite id as an identity-checked action
handle. Accept/decline uses a conditional single-row claim, so concurrent
requests cannot both consume one invite. Access and error logs replace invite
path tokens and sensitive query values with redacted placeholders.

Creating an invitation runs the live-pending duplicate check, invite insert,
and optional registered-user notification/outbox write inside one retryable
`SERIALIZABLE` transaction. A notification failure therefore leaves no invite,
and concurrent creates for the same plan/participant leave one pending invite.
The transaction re-reads the inviter's current member-management authority and
delegation ceiling, so a concurrent permission revocation fails closed. Phone
target resolution prefers the exact canonical identity before any legacy local
variant.
The generic idempotency response store is not used for this route because it
must never persist or replay the raw bearer token.

After the transaction commits, a phone invitation is sent by the backend
through the same hardened OpenWA `send-transient-text` transport used by the
temporary MVP OTP channel. The message is generic and contains only the private
HTTPS invitation link; plan title, inviter identity, permissions, and phone are
not included. The create response reports `delivery.status` as `SENT` only after
the complete OpenWA acknowledgement above. `DELIVERY_UNCERTAIN`, transport
failures, and missing/unknown acknowledgements map to `UNCERTAIN`; explicit
`NOT_ATTEMPTED`/`REJECTED` outcomes map to `UNAVAILABLE`. Neither outcome
deletes the pending invite or falsely reports that WhatsApp succeeded.

`POST /api/v1/wedding-plans/:weddingPlanId/invites/:inviteId/reissue`
atomically replaces the SHA-256 fingerprint of an existing live pending invite
and may atomically replace its role and permission snapshot from the validated
request body before returning a new 43-character raw bearer once. Omitting the
optional role and permission fields preserves the existing snapshot. The prior bearer stops working
as soon as the transaction commits, including an accept/decline request that
looked it up before the rotation but has not yet claimed it. Reissue preserves the original expiry and
is rejected for expired, accepted, declined, or revoked invitations. Owners
may reissue any manageable invite; a delegated inviter may reissue only their
own invite and only while its effective permissions remain within their
current delegation ceiling.

`POST /api/v1/invites/:token/request-otp` is public but bearer-and-phone bound.
It sends a `LOGIN` OTP only when the 43-character raw token fingerprints a live
pending invitation and the canonical phone matches that exact invitation. A
mismatch returns stable code `INVITE_NOT_FOUND_FOR_PHONE` without plan details
and without dispatching an OTP. A private token link always starts verification
for the invited phone, even when the device still has another application
account signed in; it must not query the token through that stale account. After
OTP verification the application session is replaced by the verified invitee,
the exact token flow resumes in memory, and the client may accept the invite and
enter the shared plan. The server still performs the normal verified-phone and
atomic pending-invite claim checks.

Create shared member request:

```json
{
  "phone": "+967700000000",
  "role": "VIEWER",
  "canViewMoney": false,
  "canManageTasks": false,
  "canManageMoney": false
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
  "canViewMoney": false,
  "canManageTasks": false,
  "canManageMoney": false,
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
create paid bookings, deposits, provider settlement/payment-processing status,
loans, credit, financing, or AI. Manual CostPayment entries remain a separate
planning ledger and never move money.

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

- `automaticCostCreated: false`
- `costSuggestion`, containing `recommendedAction`, `message`, quoted amount,
  currency, provider id, and quote-offer id
- `nextActions`, including `createCost`, `createFollowUpTask`, and
  `viewAcceptedProvider`; payment recording is unavailable until a cost exists

Accepting an offer must not silently create costs, payment schedules, tasks,
payments, deposits, or confirmed bookings. A `CREATE_COST` suggestion may
prefill the cost form only after explicit confirmation. Quote presentation
uses `availableActions: ["CREATE_COST"]` while an accepted offer has no cost;
when a linked cost exists it may return `costId` and
`availableActions: ["VIEW_COST"]` instead.

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

Provider review actions require an independent administrator: an administrator
who owns the application-side provider profile cannot approve, reject, request
changes, suspend, or reactivate that same profile. The check is enforced inside
the review transaction before any status or reviewer field is written.

The admin user, provider application, provider, service, review, conversation
report, and notification list routes accept positive `page` and `limit` query
parameters (`limit` is capped server-side). They return
`{ items, page, limit, total, totalPages }`; the UI must use this metadata and
must not silently truncate to its first 50/80/100 results.

Admin services are real `ProviderService` management operations. Deleting a service safely deactivates it (`isActive=false`) instead of hard-deleting data.

Admin reviews are real `ProviderReview` moderation operations. Publishing or hiding a review recalculates the provider public rating from published reviews only. Reviewer contact details are not part of the moderation response or search contract.

Admin notifications expose a privacy-minimized operational view of persisted
notifications across users. The user reference contains `id`, `name`, and a
masked phone suffix only. Cost/payment-schedule notifications, notifications
with a financial entity, and even misclassified notifications carrying money data
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
- An administrator's general application token never carries `admin_mfa` and
  cannot access administration routes.

## MVP Exclusions

The current MVP backend contract does not include:

- payment processing
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
| POST | `/api/v1/auth/admin/password-reset/confirm` | `auth.confirmAdminPasswordReset` |  |
| POST | `/api/v1/auth/admin/password-reset/request` | `auth.requestAdminPasswordReset` |  |
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
| GET | `/api/v1/cost-payments/:id` | `wedding-costs.get` | 🔒 |
| POST | `/api/v1/cost-payments/:id/reverse` | `wedding-costs.reverse` | 🔒 |
| DELETE | `/api/v1/costs/:id` | `wedding-costs.remove` | 🔒 |
| GET | `/api/v1/costs/:id` | `wedding-costs.get` | 🔒 |
| PATCH | `/api/v1/costs/:id` | `wedding-costs.update` | 🔒 |
| POST | `/api/v1/costs/:id/cancel` | `wedding-costs.cancel` | 🔒 |
| GET | `/api/v1/costs/:id/payment-schedules` | `wedding-costs.listSchedules` | 🔒 |
| POST | `/api/v1/costs/:id/payment-schedules` | `wedding-costs.createSchedule` | 🔒 |
| GET | `/api/v1/costs/:id/payments` | `wedding-costs.listPayments` | 🔒 |
| POST | `/api/v1/costs/:id/payments` | `wedding-costs.createPayment` | 🔒 |
| GET | `/api/v1/dashboard/home` | `dashboard.getHome` | 🔒 |
| DELETE | `/api/v1/guest-groups/:id` | `guests.removeGroup` | 🔒 |
| PATCH | `/api/v1/guest-groups/:id` | `guests.updateGroup` | 🔒 |
| DELETE | `/api/v1/guests/:id` | `guests.remove` | 🔒 |
| GET | `/api/v1/guests/:id` | `guests.findOne` | 🔒 |
| PATCH | `/api/v1/guests/:id` | `guests.update` | 🔒 |
| GET | `/api/v1/invites/:token` | `sharing.getInvite` | 🔒 |
| POST | `/api/v1/invites/:token/accept` | `sharing.acceptInvite` | 🔒 |
| POST | `/api/v1/invites/:token/decline` | `sharing.declineInvite` | 🔒 |
| POST | `/api/v1/invites/:token/request-otp` | `sharing.requestOtp` |  |
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
| DELETE | `/api/v1/payment-schedules/:id` | `wedding-costs.remove` | 🔒 |
| PATCH | `/api/v1/payment-schedules/:id` | `wedding-costs.update` | 🔒 |
| POST | `/api/v1/payment-schedules/:id/cancel` | `wedding-costs.cancel` | 🔒 |
| POST | `/api/v1/payment-schedules/:id/pay` | `wedding-costs.pay` | 🔒 |
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
| PUT | `/api/v1/wedding-plans/:planId/money-budget` | `money-summary.replaceMoneyBudget` | 🔒 |
| GET | `/api/v1/wedding-plans/:planId/money-summary` | `money-summary.getMoneySummary` | 🔒 |
| GET | `/api/v1/wedding-plans/:weddingPlanId/budget-categories` | `budget-categories.findForPlan` | 🔒 |
| POST | `/api/v1/wedding-plans/:weddingPlanId/budget-categories` | `budget-categories.create` | 🔒 |
| GET | `/api/v1/wedding-plans/:weddingPlanId/cost-payments` | `wedding-costs.list` | 🔒 |
| GET | `/api/v1/wedding-plans/:weddingPlanId/costs` | `wedding-costs.list` | 🔒 |
| POST | `/api/v1/wedding-plans/:weddingPlanId/costs` | `wedding-costs.create` | 🔒 |
| GET | `/api/v1/wedding-plans/:weddingPlanId/guest-groups` | `guests.findGroups` | 🔒 |
| POST | `/api/v1/wedding-plans/:weddingPlanId/guest-groups` | `guests.createGroup` | 🔒 |
| GET | `/api/v1/wedding-plans/:weddingPlanId/guests` | `guests.findForPlan` | 🔒 |
| POST | `/api/v1/wedding-plans/:weddingPlanId/guests` | `guests.create` | 🔒 |
| POST | `/api/v1/wedding-plans/:weddingPlanId/guests/bulk` | `guests.bulkCreate` | 🔒 |
| GET | `/api/v1/wedding-plans/:weddingPlanId/guests/summary` | `guests.summary` | 🔒 |
| GET | `/api/v1/wedding-plans/:weddingPlanId/invites` | `sharing.findInvites` | 🔒 |
| POST | `/api/v1/wedding-plans/:weddingPlanId/invites` | `sharing.createInvite` | 🔒 |
| DELETE | `/api/v1/wedding-plans/:weddingPlanId/invites/:inviteId` | `sharing.cancelInvite` | 🔒 |
| POST | `/api/v1/wedding-plans/:weddingPlanId/invites/:inviteId/reissue` | `sharing.reissueInvite` | 🔒 |
| GET | `/api/v1/wedding-plans/:weddingPlanId/members` | `sharing.findMembers` | 🔒 |
| POST | `/api/v1/wedding-plans/:weddingPlanId/members` | `sharing.createMember` | 🔒 |
| DELETE | `/api/v1/wedding-plans/:weddingPlanId/members/:memberId` | `sharing.removeMember` | 🔒 |
| PATCH | `/api/v1/wedding-plans/:weddingPlanId/members/:memberId` | `sharing.updateMember` | 🔒 |
| GET | `/api/v1/wedding-plans/:weddingPlanId/payment-schedules/due` | `wedding-costs.due` | 🔒 |
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
