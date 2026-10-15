# API Contract

This document is the route-level source of truth for the current Aarast backend contract. Other Markdown files should link here instead of copying endpoint lists.

Current documentation snapshot: 2026-08-11.

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
- An expected `GET /ready` `503` from an orchestration probe is an availability
  signal, not an application error: it is not logged as an error or sent to
  Sentry. Other `5xx` responses remain logged and reported.

## Common Rules

- JSON request and response bodies are used for API routes.
- Protected routes require `Authorization: Bearer <accessToken>`.
- Access JWTs default to 15 minutes and are renewed through rotating refresh
  sessions. Every access JWT carries a signed `scope` claim: `application` for
  `/api/v1` product APIs and Chat, or `admin` for `/admin`. Scope-less,
  cross-scope, and contradictory claim combinations are rejected.
- Every application and administrator access JWT also carries a non-empty
  signed `sid` equal to its current persisted `RefreshToken.id`. Authorization
  requires a live, unrevoked, unexpired refresh row matching the JWT `sub`,
  `scope`, and `sid`; scope-only or sessionless tokens are rejected. Admin
  tokens additionally require `admin_mfa`, while application tokens must not
  carry that assurance.
- Production refuses to start with a missing, placeholder, short, repetitive,
  or low-entropy `JWT_SECRET`. The secret is validated without logging or
  returning its value.
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

Every OTP-producing endpoint uses one retryable availability contract. A
disabled or invalid channel configuration, an unavailable quota dependency,
or a definitive provider delivery failure returns HTTP `503` with:

```json
{
  "statusCode": 503,
  "code": "OTP_DELIVERY_UNAVAILABLE",
  "message": "خدمة إرسال رمز التحقق غير متاحة حاليًا. حاول لاحقًا."
}
```

The response never exposes channel configuration or provider details. Quota
exhaustion remains HTTP `429`, and an explicitly uncertain delivery keeps the
issued code active and follows the separate `200` notice contract documented
below.

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

OTP verification locks the current code row and commits the attempt or
one-time consumption before any account mutation begins. A wrong, expired,
already-consumed, exhausted, or concurrently replayed code creates no account
and issues no access or refresh token. If a later account transaction fails,
the successfully proved OTP remains consumed (fail closed) and the caller must
request a new code. Email is intentionally absent because a phone OTP cannot
prove ownership of an email address. The initial response is generic; phone
conflicts are checked only after valid phone proof so the start endpoint is not
an account-enumeration oracle.

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
Five admitted password attempts within fifteen minutes lock that normalized
account identifier for fifteen minutes. An attempt reserves its slot under the
database row lock before password comparison, so a concurrent burst cannot run
more comparisons than the configured ceiling. Application and administrator lock
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
  session through refresh. Rotation mints an access JWT with the same realm:
  `application` refresh sessions mint only `scope=application`, and `ADMIN`
  refresh sessions mint only `scope=admin`.
- `POST /api/v1/auth/refresh` rotates one valid refresh token and returns a new access
  and refresh pair. Rotation is serialized across that user, scope, and
  replacement chain. The replacement access JWT carries the new row id as
  `sid`, so the prior access token becomes invalid as soon as the old row is
  revoked.
- Any reuse of a revoked or replaced refresh token, including an immediate or
  concurrent duplicate request, is rejected and revokes the still-active
  descendants in that same user/scope replacement family. Independent login
  families and the other application/admin realm remain unaffected.
- If replacement-chain traversal detects a cycle or reaches the maximum depth
  of 4,096 without proving a terminal row, the family cannot be trusted.
  Traversal uses one bounded recursive CTE that reads at most `max + 1` rows and
  locks the traversed `RefreshToken` rows with one `FOR UPDATE` query. Refresh
  and logout fail closed by revoking every active refresh session for that same
  user and realm. `APPLICATION` and `ADMIN` remain isolated; an application
  failure cannot revoke administrator sessions and vice versa. This broader
  realm revocation is reserved for an incomplete/cyclic family; normal replay
  still preserves independent login families.
- `POST /api/v1/auth/logout` revokes the supplied application refresh token;
  when omitted it revokes all application sessions for that user. A supplied
  older token follows its replacement chain and revokes the live descendant
  rather than leaving the rotated session active.
- `POST /api/v1/auth/logout-all` revokes all active application refresh
  sessions. Administrator logout/recovery affects only administrator sessions.
- Application rotation, logout, reset, disable, and deletion commit
  `SESSION_REVOKED` or `USER_SESSIONS_REVOKED` outbox events with the
  authoritative session mutation. Chat sockets are grouped by `sid`; immediate
  disconnect is best-effort for low latency, while strict outbox dispatch makes
  revocation durable across backend replicas.
- A revoked refresh row is retained for 30 days from `revokedAt`; an unrevoked
  expired row is retained for 30 days from `expiresAt`. One hourly
  PostgreSQL-advisory-lock cleanup removes older rows on only one replica. This
  bounded history preserves token-family reuse detection and incident evidence
  without allowing terminal sessions to accumulate forever.

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
  OTP relation, never the raw token or phone. The response includes the same
  bounded `deliveryStatus` used by other OTP requests so the browser never
  claims delivery from provider acceptance alone.
- `POST /api/v1/auth/admin/password-reset/verify` — body
  `{ challengeToken, code }`. Proves and consumes the WhatsApp code on its own
  screen, then opens a 15-minute window (`{ verified: true, expiresAt }`) for
  choosing the password, so typing it never races the code's expiry. A wrong
  code burns one of the challenge's attempts; a challenge verifies once.
- `POST /api/v1/auth/admin/password-reset/confirm` — body
  `{ challengeToken, newPassword }`, accepted only on a verified, unexpired
  challenge. The password follows the application rule: any characters, at
  least 6, at most 72 UTF-8 bytes (admin sign-in always adds a WhatsApp code).
  Success changes only the browser-admin `passwordHash`, revokes only
  administrator refresh sessions and login/recovery challenges, consumes active
  administrator OTPs, and does not create a session. Invalid, expired,
  replayed, unknown, and non-admin challenges return
  the same `ADMIN_RESET_INVALID_OR_EXPIRED` code.

A definitive WhatsApp delivery failure returns the same
`503`/`OTP_DELIVERY_UNAVAILABLE` contract for every phone and leaves no usable
challenge. This preserves honest transport feedback without disclosing
administrator account existence through body or timing.

Additional current auth/profile routes:

- `POST /api/v1/auth/otp/request`
- `POST /api/v1/auth/otp/verify`
- `PATCH /api/v1/users/me`
- `DELETE /api/v1/users/me`
  - requires a valid, stable `X-Client-Request-Id`; a missing or malformed
    value returns `400` with `ACCOUNT_DELETION_REQUEST_ID_REQUIRED`;
  - deletes an ordinary wedding-app account and its owned data in the same
    transaction that commits an anonymous immutable deletion receipt;
  - when the underlying database row is also an administrator, deletes only
    the enrolled wedding-application identity and application-owned graph. It
    clears `appPasswordHash`, application profile/onboarding fields, app media,
    memberships, plans, provider/customer data, application OTPs and
    `APPLICATION` refresh sessions, while retaining the administrator
    password/profile/role, admin avatar, admin challenges, audit links,
    administrator idempotency history, and `ADMIN` refresh sessions;
  - is reachable only with an application-scoped bearer. An administrator
    bearer cannot call this product route or be downgraded into an application
    session.
- `POST /api/v1/account-deletions/status`
  - is intentionally unauthenticated because the successful command removes
    the account and its session;
  - is throttled to 10 requests per minute and accepts only
    `{ userId, clientRequestId }` safe opaque identifiers;
  - returns only `{ status: "DELETED" | "PENDING" | "NOT_STARTED" }` and no
    account, profile, or deletion-graph data.
- `GET /api/v1/users/lookup?weddingPlanId=<planId>&phone=<phone>`
  - requires an authenticated owner/member with permission to invite members
- `GET /api/v1/users/me/settings`
- `PATCH /api/v1/users/me/settings`
- `GET /api/v1/me`

OTP/profile routes are account and settings helpers. They do not add payment, booking, financing, AI, or chat behavior.

Account-deletion retries must reuse the exact same client request id. The
Backend hashes `userId + NUL + clientRequestId` and stores only that SHA-256
digest in `AccountDeletionReceipt`, atomically with application-account
erasure. For an ordinary account the User row is erased; for a dual
administrator/application identity the administrator row remains with all
application identity fields cleared. `DELETED` means the matching immutable
receipt committed. `PENDING` means the
matching DELETE idempotency reservation is still live. `NOT_STARTED` means
neither a receipt nor a live matching reservation exists. A reservation older
than 30 seconds may be reclaimed only after locking the still-live User and
rechecking the receipt; the account-deletion transaction itself has a
15-second timeout. A lost HTTP response must therefore be reconciled through
the status route before the client restores a dashboard, clears its durable
deletion marker, or retries with a different id.

The settings response includes the persisted content preferences plus an
additive `channelCapabilities` object:

```json
{
  "pushEnabled": true,
  "smsEnabled": false,
  "whatsappEnabled": false,
  "emailEnabled": false,
  "taskRemindersEnabled": true,
  "paymentRemindersEnabled": true,
  "providerMessagesEnabled": true,
  "channelCapabilities": {
    "inApp": { "supported": true, "configurable": false, "enabled": true },
    "push": { "supported": true, "configurable": false, "enabled": true },
    "sms": { "supported": false, "configurable": false, "enabled": false },
    "whatsapp": { "supported": false, "configurable": false, "enabled": false },
    "email": { "supported": false, "configurable": false, "enabled": false }
  }
}
```

The in-app inbox/realtime availability is supported and is not configurable.
`channelCapabilities.push.supported` reflects the live Backend delivery
capability: it is `true` only when `FirebasePushClient` is runtime-enabled
through `PUSH_NOTIFICATIONS_ENABLED=true`; otherwise it is `false`.
`channelCapabilities.push.enabled` and `pushEnabled` reflect whether the
account currently has an enabled registered device installation, independently
of that runtime capability. Push is managed by the authenticated
device-registration contract below and is not writable through settings.
Sending `pushEnabled: true` to settings returns HTTP `400` with code
`NOTIFICATION_CHANNEL_DEVICE_MANAGED`; legacy `false` remains accepted and is
ignored. SMS, WhatsApp, and email remain unsupported notification channels:
their booleans return `false`, and attempts to enable them return
`NOTIFICATION_CHANNEL_UNSUPPORTED`. OTP transport is a separate authentication
concern and does not make WhatsApp a general notification channel.

The three writable content preferences have direct effects:

- `taskRemindersEnabled` controls immediate and scheduled task reminders and
  the `WEDDING_COUNTDOWN` reminder.
- `paymentRemindersEnabled` controls scheduled payment reminders,
  `BUDGET_CATEGORY_EXCEEDED`, and `LOAN_REPAYMENT_DUE_SOON` /
  `LOAN_REPAYMENT_OVERDUE`.
- `providerMessagesEnabled` controls quote-request, quote-offer, quote-decision,
  and conversation-message notifications.

The hourly reminder scan (V1 checklist 4.8, 4.17) also creates plan-level
reminders, each idempotent through its dedupe key:

- `BUDGET_CATEGORY_EXCEEDED` (entity `budget_category`; `routeTarget` opens
  the plan's money screen in the app) when a category's non-cancelled costs
  exceed its allocation; again only after the allocation changes and is
  exceeded again.
- `LOAN_REPAYMENT_DUE_SOON` / `LOAN_REPAYMENT_OVERDUE` (entity
  `loan_repayment`; opens the plan's funding screen) for a planned loan
  repayment due within 7 days or overdue.
- `WEDDING_COUNTDOWN` (entity `wedding_plan`; opens the plan dashboard) once
  in each window: 30, 7 and 1 day(s) before the wedding date; a changed date
  starts the countdown again.

The two money reminders go to the plan owner only: a contributor's money view
covers only the categories they created, and funding is the owner's private
picture. They are money notifications (`budget_category` and `loan_repayment`
join `payment_schedule`): hidden without money access and purged when it is
lost. Only `WEDDING_COUNTDOWN` is pushed; like payment reminders, the money
reminders stay in the in-app inbox.

Missing preference rows keep the three content categories enabled by default.
General account/sharing notifications and the in-app inbox itself remain
available. A suppressed content notification creates neither a `Notification`
row nor a notification-created outbox event. Settings writes lock the recipient
`User` row `FOR UPDATE`; gated notification creation and the scheduler lock it
`FOR SHARE` before re-reading the preference. A disable that commits first
therefore wins deterministically.

`PATCH /api/v1/users/me` accepts profile fields such as name, email, avatar,
locale, and persona. It does not accept `appRole`; role/context discovery is
server-owned and a supplied `appRole` is rejected by the global validation
pipe. Provider application creation remains the trusted operation that owns
provider-profile state.

`REGISTER` codes are completed only through `POST /api/v1/auth/register/complete`;
the generic verify endpoint cannot consume a registration code without the
registration details. In production `AUTH_OTP_MODE=whatsapp` uses an approved
Meta authentication template. The temporary `AUTH_OTP_MODE=openwa` option calls
only the Aarast-hardened `send-transient-text` contract; it never falls back to
upstream `send-text`. Both modes refuse to boot when their selected channel is
incompletely configured, and production responses never echo the code.

Every successful OTP request response includes a machine-readable
`deliveryStatus`: `DELIVERED` only after a device acknowledgement, `PENDING`
when an official provider has only accepted the request, `UNCERTAIN` when
OpenWA may have sent it but delivery was not confirmed, and `LOCAL_DEV` only
for the explicit development channel. Mobile clients must not present
`PENDING` or `UNCERTAIN` as delivered.

Every non-development OTP request consumes atomic PostgreSQL quotas before
delivery: 60-second phone cooldown, bounded phone/IP windows, and an
`OTP_GLOBAL_DAILY_LIMIT` ceiling. Quota keys are HMAC digests made with
`AUTH_LOGIN_THROTTLE_PEPPER`; raw phone numbers and IP addresses are not stored.
Provider delivery failures also consume quota so a failing transport cannot be
used to bypass the safety ceiling.

OTP verification is serialized per code row. The compare, failed-attempt
increment, terminal attempt ceiling, and successful one-time consumption are
one retryable PostgreSQL transaction. Concurrent wrong attempts cannot record
more than `maxAttempts`, and a correct/wrong race cannot create two successful
consumers. Password login uses the same row-lock principle on the HMAC-keyed
`LoginThrottle` row. Each request reserves one attempt before password
comparison; a successful authentication clears the row, while a cross-replica
burst cannot execute more than five comparisons in one window.

For the official Meta channel, a valid 2xx response containing a message id
means API acceptance only and returns `deliveryStatus: "PENDING"`; it does not
claim device delivery. After the outbound request begins, a timeout/abort,
connection failure, 5xx response, unreadable response, or malformed 2xx
acknowledgement has an ambiguous outcome. The OTP remains active and the API
returns the bounded `UNCERTAIN` result without exposing the provider body or
OTP. An explicit Meta 4xx response is treated as a definitive rejection and
invalidates the newly-created code, except transport-ambiguous `408`, `425`,
and `499`, which remain `UNCERTAIN`.

Administrator MFA uses the private `ADMIN_LOGIN` purpose, never the public
`LOGIN` purpose. Each password-bound login challenge references the exact OTP
row it issued, so a public app request cannot replace, consume, or satisfy an
administrator challenge. Expired OTP/login/reset security rows are retained for
one day, then removed by one advisory-lock-elected replica.

OpenWA delivery has an explicit acknowledgement contract. Success requires a
2xx response containing both a non-empty `messageId` and
`deliveryStatus: "DELIVERED"`, emitted only after a WhatsApp device-delivery
acknowledgement. A send result or server-side `SENT` acknowledgement is not
delivery success. HTTP `408`, `425`, and `499` remain transport-uncertain. A
503 is definitive only when its safe body code is
`NOT_ATTEMPTED` or `REJECTED`; those outcomes invalidate the newly created code
and return the generic unavailable response. `DELIVERY_UNCERTAIN`, an unknown or
malformed 5xx, a timeout/transport break, or a 2xx acknowledgement missing the
required fields may occur after WhatsApp accepted the message. In those cases
the code remains active and the request returns `200`, `delivery: "WHATSAPP"`,
`deliveryStatus: "UNCERTAIN"`, and a safe `message` asking the user to enter the
code if it arrives. The response never echoes the OTP. This prevents an already delivered code from
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

## Account Contexts

Protected routes:

- `GET /api/v1/contexts`
- `POST /api/v1/contexts/validate`

Contexts are navigation metadata, not authorization grants. The backend derives
them live from `WeddingPlan.ownerUserId`, `SharedMember`, and `Provider.userId`;
it does not use `User.role` or `User.appRole` alone and does not trust a client
supplied plan, provider, role, or permissions object.

`GET /api/v1/contexts` returns every relational context currently accessible
to the account. Planning plans are available; archived plans remain
discoverable with `isAvailable: false` so a client can explain why a prior
selection is no longer usable.

Every context preserves the compatibility fields already consumed by clients
and adds:

- `persona`: the plan-owned `GROOM`, `BRIDE`, or `HELPER` value for plan
  contexts, and `null` for provider contexts. Clients use this only through
  the selected account context; route ids and legacy active-plan fields are
  not persona or navigation fallbacks.
- `lifecycle`: the live `WeddingPlan.status` or `Provider.status`.
- `accessMode`: `FULL`, `LIMITED`, or `READ_ONLY`. `FULL` means the lifecycle
  permits the context's normal feature set; it does not grant a route action
  that the stored fine-grained `permissions` deny. `LIMITED` is the editable
  provider-profile-only state. `READ_ONLY` is historical plan access or
  provider profile/status visibility without mutation.
- `capabilities`: `canViewProviderProfile`, `canManageProviderProfile`, and
  `canUseProviderOperations`.
- `membershipId` and `membershipAuthorityVersion`: the exact live
  `SharedMember` incarnation and stored authority version for contributor
  contexts; both are `null` for owner and provider contexts. They bind a
  durable self-leave request to the membership the user actually chose to
  leave, so a delayed replay cannot remove a later re-invited membership.

`permissions` remains for compatibility and route-specific client decisions.
For an archived plan, readable historical permissions remain truthful while
every plan write permission is `false`.

Owner example:

```json
{
  "contextKey": "plan:clx123:owner",
  "role": "OWNER",
  "weddingPlanId": "clx123",
  "providerId": null,
  "membershipId": null,
  "membershipAuthorityVersion": null,
  "persona": "GROOM",
  "displayName": "خطة زفاف محمد",
  "lifecycle": "PLANNING",
  "accessMode": "FULL",
  "capabilities": {
    "canViewProviderProfile": false,
    "canManageProviderProfile": false,
    "canUseProviderOperations": false
  },
  "permissions": {
    "canViewPlan": true,
    "canEditPlan": true,
    "canManageTasks": true,
    "canManageGuests": true,
    "canManageProviders": true,
    "canInviteMembers": true,
    "canViewMoney": true,
    "canManageMoney": true,
    "canManageProviderProfile": false
  },
  "isAvailable": true,
  "unavailableReason": null
}
```

Contributor example:

```json
{
  "contextKey": "plan:clx456:contributor",
  "role": "CONTRIBUTOR",
  "weddingPlanId": "clx456",
  "providerId": null,
  "membershipId": "member-clx456-user-7",
  "membershipAuthorityVersion": 7,
  "persona": "BRIDE",
  "displayName": "خطة زفاف أحمد",
  "lifecycle": "PLANNING",
  "accessMode": "FULL",
  "capabilities": {
    "canViewProviderProfile": false,
    "canManageProviderProfile": false,
    "canUseProviderOperations": false
  },
  "permissions": {
    "canViewPlan": true,
    "canEditPlan": false,
    "canManageTasks": true,
    "canManageGuests": true,
    "canManageProviders": false,
    "canInviteMembers": false,
    "canViewMoney": false,
    "canManageMoney": false,
    "canManageProviderProfile": false
  },
  "isAvailable": true,
  "unavailableReason": null
}
```

Provider example:

```json
{
  "contextKey": "provider:7c5301cb-0194-4f44-bb62-18dc9025bb52",
  "role": "PROVIDER",
  "weddingPlanId": null,
  "providerId": "7c5301cb-0194-4f44-bb62-18dc9025bb52",
  "membershipId": null,
  "membershipAuthorityVersion": null,
  "persona": null,
  "displayName": "قاعة السعادة",
  "lifecycle": "ACTIVE",
  "accessMode": "FULL",
  "capabilities": {
    "canViewProviderProfile": true,
    "canManageProviderProfile": true,
    "canUseProviderOperations": true
  },
  "permissions": {
    "canViewPlan": false,
    "canEditPlan": false,
    "canManageTasks": false,
    "canManageGuests": false,
    "canManageProviders": false,
    "canInviteMembers": false,
    "canViewMoney": false,
    "canManageMoney": false,
    "canManageProviderProfile": true
  },
  "isAvailable": true,
  "unavailableReason": null
}
```

Validation request:

```json
{
  "contextKey": "plan:clx456:contributor"
}
```

Success returns the same canonical context rebuilt from current database rows.
Malformed keys return `400` with `INVALID_CONTEXT_KEY`; a syntactically valid
but inaccessible plan/provider returns privacy-preserving `404` with
`CONTEXT_NOT_FOUND`; an archived context returns `409` with
`CONTEXT_UNAVAILABLE` and `unavailableReason: "PLAN_ARCHIVED"`.
Validation never replaces route-level `PermissionService`, provider ownership,
conversation authorization, or other domain checks.

Provider contexts remain available for profile/status display in all five
states:

| Provider status | `accessMode` | View profile | Manage profile | Provider operations |
| --- | --- | --- | --- | --- |
| `ACTIVE` | `FULL` | yes | yes | yes |
| `PENDING` | `LIMITED` | yes | yes | no |
| `NEEDS_CHANGES` | `LIMITED` | yes | yes | no |
| `SUSPENDED` | `READ_ONLY` | yes | no | no |
| `REJECTED` | `READ_ONLY` | yes | no | no |

This matrix uses the same provider access policy as the profile and operation
guards. It is not derived from `User.role`, `User.appRole`, or
`User.onboardingPath`; those remain compatibility metadata only.

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
`GET /api/v1/wedding-plans/active` returns the explicitly selected planning
plan with HTTP `200`. If the stored plan was deleted, archived, or is no
longer accessible, the response has no selected-plan body (Nest/Express
serializes the service `null` as an empty `200` body, which the mobile client
maps to `null`); it never selects another accessible plan as a fallback.

Shared members can read basic plan info. Updating or archiving requires owner access or manager-style sharing permission.

An archived WeddingPlan remains readable to users who still have access, but
its planning graph is read-only. `POST /api/v1/wedding-plans/:id/set-active`
and plan-scoped writes protected by the plan permission/lifecycle guards return
HTTP `409` with:

```json
{
  "code": "PLAN_ARCHIVED_READ_ONLY",
  "message": "Archived wedding plans are read-only"
}
```

The same denial applies to member/invite mutations, linked quote cancellation
and provider offer/status mutations, and sending a message in a plan-scoped
conversation. Historical reads remain available. Personal safety/inbox state
such as read, mute, block, and report is not treated as a planning-data write.

Plan update and archive now run inside retryable `SERIALIZABLE` transactions.
They lock `WeddingPlan FOR UPDATE` before re-reading lifecycle state, then lock
the acting non-owner's `SharedMember` row `FOR SHARE` before checking authority
and writing. Active-plan selection locks the authenticated `User FOR UPDATE`,
then locks and rechecks the selected `WeddingPlan` and applicable
`SharedMember` before storing `activeWeddingPlanId`. A permission revocation,
membership deletion, or archive that commits first therefore rejects the
waiting mutation instead of allowing a stale authorization decision.

Archiving a plan also revokes every invitation that is still live and pending
at that boundary: `acceptedAt`, `declinedAt`, and `revokedAt` are null and
`expiresAt` is still in the future. The plan update and invitation revocation
commit in the same serializable transaction; terminal invitation history is
not rewritten.

This concurrent contract is verified for plan update/archive/set-active,
invitation acceptance, all six member/invite administration mutations, all
seven task mutations, all seven guest/group mutations, all fifteen financial
mutations, quote lifecycle writes, plan-conversation state/send, provider
dashboard writes, marketplace writes, media verification/persistence,
notification mutations, administrator mutations, and authentication lifecycle
races. Sixteen named `smoke:phase2-*` gates cover the current inventory. This
does not claim that every future protected service or any deployed environment
is complete.

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
- `membershipId` and `membershipAuthorityVersion`: the same current
  contributor-membership identity returned by `/api/v1/contexts`, or `null`
  for an owner. Clients must not construct or guess these values.

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
Both paths honor the content preferences documented above before persisting a
notification or outbox row.

### Device push installations

Protected routes:

- `PUT /api/v1/push/installations/current`
- `DELETE /api/v1/push/installations/current`

Both accept:

```json
{
  "fid": "firebase_installation_id",
  "platform": "ANDROID"
}
```

The Firebase Installation ID is unique across accounts. Registration moves a
shared-device installation to the authenticated account in one serializable
transaction and enables that account's push preference. Unregistration deletes
only an installation owned by the authenticated account and disables the
preference only when no enabled installation remains.

Task assignment, task due/overdue, and chat-message notifications enqueue a
separate `PUSH_NOTIFICATION_REQUESTED` outbox event. This keeps FCM retry
independent from the existing Socket.IO notification event. Push delivery uses
generic lock-screen copy and never copies task titles, sender identity, contact
details, or notification bodies into the FCM alert. Invalid installations are
purged; transient Firebase failures remain retryable.

Push delivery is disabled unless `PUSH_NOTIFICATIONS_ENABLED=true`. When
enabled, the backend also requires `FIREBASE_PROJECT_ID` and Application
Default Credentials supplied by the runtime environment. Credentials are
never accepted from the mobile client or stored in this repository.

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

Browser clients are allowed to preflight this route with `PUT`; the canonical
CORS method list includes `GET`, `POST`, `PUT`, `PATCH`, `DELETE`, and
`OPTIONS`, while the origin and credential restrictions remain unchanged.

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

The budget write, category replacement, and returned summary use one retryable
`SERIALIZABLE` transaction. The response is calculated before that transaction
commits; the endpoint never commits a budget and then performs a separately
authorized summary read that could falsely return failure after the write.

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

All fifteen canonical financial mutation handlers—budget replacement, the
three category mutations, the six cost/payment entry points, payment reversal,
and the four payment-schedule mutations—recheck plan lifecycle and current
money-management authority inside their retryable `SERIALIZABLE` transaction.
An archive, membership removal, or permission revocation that commits first
rejects the waiting mutation without a financial write. Cost create/update lock
referenced providers and quote offers in sorted order before categories and the
cost row, so provider suspension or deletion cannot leave a newly linked or
updated cost using stale provider state.

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

The accepted-quote route creates this record inside the same serializable
transaction as offer acceptance. Manual cost creation remains available for
non-quote costs. Hard delete is limited to costs without ledger history;
cancellation is explicit and must not erase paid money.

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

## Cost Receipts

Receipt photos kept with a cost or one of its payments (V1 checklist 4.4):

- The app uploads the photo with media purpose `cost-receipt` (`POST
  /api/v1/media/uploads/presign`, then `verify`). It is private media like
  chat images: `verify` returns an `attachmentRef` and never a public URL.
- `POST /api/v1/costs/:costId/receipts` `{ attachmentRef, costPaymentId? }`
  keeps it with the cost (who may change the cost may add; the payment, when
  named, must belong to the cost). At most 10 per cost
  (`409 COST_RECEIPT_LIMIT`). An upload is attached once.
- `GET /api/v1/costs/:costId/receipts` lists them, newest first, for whoever
  may see the cost (the same decision as `GET /api/v1/costs/:id`, including a
  contributor's cost scope). Each item carries `downloadUrl`, a signed URL
  valid for 120 seconds (`Cache-Control: private, no-store`) and
  `downloadExpiresAt`.
- `DELETE /api/v1/costs/:costId/receipts/:receiptId` deletes the row and
  schedules the file's deletion.
- `DELETE /api/v1/costs/:id` is `409 COST_HAS_RECEIPTS` while the cost keeps
  receipts. Account deletion removes the receipts of the erased plans and
  those the account uploaded into other plans, with their files.

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
The pay response is always one canonical wrapper so online and replay clients
cache the same state:

```json
{
  "payment": { "id": "payment_id", "paymentScheduleId": "schedule_id" },
  "schedule": { "id": "schedule_id", "status": "PAID" }
}
```

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
      "dueDate": "2026-12-15T00:00:00.000Z",
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
The permission decision and all summary rows are read from the same
`REPEATABLE READ` transaction snapshot. A budget replacement returns the
summary built inside its own successful mutation transaction.

Removed prelaunch expense, commitment, financial-payment, and financial-
installment routes are not aliases and must return `404`.

### Cost payer

`POST /api/v1/wedding-plans/:id/costs` and `PATCH /api/v1/costs/:id` accept
an optional `payer` (`GROOM`, `BRIDE`, `FAMILY`, `SHARED`, `OTHER`) and
`payerName` (≤ 120, e.g. «الوالد»). Cost responses return both (null when
unset).

## Funding Sources and Loan Repayments

Where the wedding money comes from, tracked only: Aarast never holds,
collects or moves this money.

- `GET|POST /api/v1/wedding-plans/:planId/funding-sources`
- `PATCH|DELETE /api/v1/funding-sources/:id`
- `POST /api/v1/funding-sources/:id/repayments`
- `PATCH|DELETE /api/v1/loan-repayments/:id`

A funding source has `kind` (`SAVINGS`, `FAMILY_SUPPORT`, `GIFT` — rifd and
nuqut, `LOAN`, `OTHER`), `sourceName`, optional `sourcePhone`, positive
`amount`, and `status` `PLEDGED` (promised) or `RECEIVED` (default; then
`receivedAt` defaults to now). Responses include the ordered `repayments`
and, for a loan, `repaidAmount` and `outstandingAmount`.

Only a `LOAN` takes repayments (`amount`, optional `dueDate`). Planned and
paid repayments together never exceed the loan amount (`400`). `PATCH`
`status: PAID` records the repayment (`paidAt` defaults to now); a paid
repayment is reopened with `status: PLANNED` before it can be edited or
cancelled (`409`). A loan with repayments cannot change kind (`409`) or drop
below its scheduled repayments (`400`).

Privacy: funding is the plan owner's private money picture. A member, even
with money rights, gets an empty list from `GET` and `404` from every write.
The owner's `money-summary` adds `funding` (`total`, `received`, `pledged`,
`availableCash` = received − paid, `shortfall` = confirmed cost not covered
by any source, loan totals, `overdueLoanRepayments`, `nextLoanRepayment`) and
the warnings `FUNDING_SHORTFALL` and `LOAN_REPAYMENT_OVERDUE`; a member's
summary has `funding: null`. Account erasure deletes the plan's funding
sources and, by cascade, their repayments.

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

Every task response (list, detail, create, update, assign) carries the task's
checklist, ordered by `sortOrder` then creation time:

```json
{
  "id": "task-id",
  "title": "Confirm hall",
  "checklist": [
    { "id": "item-id", "taskId": "task-id", "title": "Call the manager", "isDone": true, "sortOrder": 0, "createdAt": "2026-10-11T09:00:00.000Z", "updatedAt": "2026-10-11T09:00:00.000Z" }
  ]
}
```

Checklist create/update return the single item in the same shape; delete
returns `{ "id": "item-id", "deleted": true }`.

Owners can manage tasks. For every non-owner, the stored
`SharedMember.canManageTasks` boolean is the final live authority. A role may
seed the boolean only when an invitation is created. Direct member creation is
fail-closed: every omitted authorization flag is stored as `false`, regardless
of role. The role is not a runtime permission fallback and changing it does not
restore a stored `false` value. The same stored-flag rule applies to guests,
providers, money, plan editing, and member management.

A current shared member whose task permission was revoked receives this stable
response from task mutations instead of the misleading plan-not-found error:

```json
{
  "statusCode": 403,
  "code": "TASK_PERMISSION_REVOKED",
  "message": "لم تعد لديك صلاحية لتنفيذ هذه المهمة"
}
```

The task list and task detail routes are contributor-scoped in the Backend. A
non-owner needs a current membership and current `canManageTasks = true`, and
then receives only tasks currently assigned to that user or tasks evidenced as
that contributor's own created/completed work. The evidence lookup spans the
same contributor's current and previous tenures; it does not admit another
member's rows merely because both users share the same `weddingPlanId`. Flutter
must not receive a broader list and hide it locally.

All seven task mutation shapes—create, update, assign, delete, and checklist
create/update/delete—run inside retryable `SERIALIZABLE` transactions. Lock
order is `WeddingPlan FOR SHARE`, the acting non-owner's
`SharedMember FOR SHARE`, an applicable assignee's
`SharedMember FOR SHARE`, then `WeddingTask FOR UPDATE`; checklist update/delete
additionally lock the checklist row `FOR UPDATE`. An archive, permission
revocation, or assignee removal that commits first therefore rejects the waiting
mutation without a task-side write.

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
- `DELETE /api/v1/wedding-plans/:weddingPlanId/members/me`
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
- `GET /api/v1/wedding-plans/:weddingPlanId/contributions`
- `GET /api/v1/wedding-plans/:weddingPlanId/contributions/summary`

The permission booleans persisted on `SharedMember` and the permission snapshot
persisted on `PlanInvite` are authoritative. `rolePermissionDefaults()` is used
only when a new invitation is created. Direct member creation stores explicit
flags and fail-closed `false` values for omitted authorization fields. Member
updates and invitation reissues preserve every omitted stored boolean even if `role` changes. In
particular, `CONTRIBUTOR` cannot implicitly re-grant a task, guest, provider, or
money permission that was explicitly stored as `false`. A non-owner may still
delegate only within the ceiling formed by that actor's current stored flags.
When any stored flag narrows, the same serializable member-update transaction
locks the actor's live pending invitations in id order and revokes every grant
that exceeds the new ceiling. A stale delegated invitation therefore reaches a
terminal `CANCELLED` state instead of remaining `PENDING`. Repeating the same
authority state is idempotent and does not rewrite terminal invitation history.

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
handle. Acceptance and decline each use a conditional single-row claim, so
only one request writes the terminal state and owner notification. Concurrent
calls or a lost-response retry by the same verified invitee using the same
current raw token fingerprint or authenticated invite-id handle return the
existing `ACCEPTED` or `DECLINED` result. Acceptance replay additionally
requires the corresponding live membership. Another account receives the
privacy-preserving not-found result, and a rotated or stale raw token cannot
replay success. Access and error logs replace invite path tokens and sensitive
query values with redacted placeholders.

Invite acceptance runs in a retryable `SERIALIZABLE` transaction. It locks the
`WeddingPlan` lifecycle row before the `PlanInvite` row, re-reads both states,
and then claims the still-live token. An existing `SharedMember` row is
authoritative and is never overwritten from an older invitation snapshot;
acceptance creates membership only when none exists. This prevents a stale
invite from restoring revoked provider or financial permissions and prevents
acceptance after an archive that commits first.
The locked plan owner and the delegated inviter, when present, must both still
have `User.status = ACTIVE`. Otherwise acceptance returns HTTP `409`, code
`INVITE_AUTHORITY_INACTIVE`, and creates no membership, contribution event, or
notification. Disabling an account transactionally revokes its issued pending
invitations before its sessions are revoked.
If the same invitee retries the same live token or authenticated invite-id
handle after the acceptance committed but its response was lost, the endpoint
returns the current accepted invite, authoritative membership, and canonical
context key without writing another acceptance notification. This replay is
available only while that exact invitee still owns the membership; another
user, a rotated raw token, or a removed membership cannot replay the success.

The acceptance response additively returns
`contextKey: "plan:<weddingPlanId>:contributor"` alongside the existing
`invite` and `member` objects. Acceptance does not change
`User.activeWeddingPlanId`; selecting the accepted context remains a separate
explicit action.

For an accepted invitation owned by the authenticated invitee,
`GET /api/v1/invites/mine` and `GET /api/v1/invites/:token` return the canonical
`contextKey` only while an active `SharedMember` row still exists for the same
user and plan. If that membership is removed, the invitation remains
historical `ACCEPTED` and retains `acceptedAt`, but `contextKey` is omitted.
Clients must treat `ACCEPTED` without `contextKey` as an ended membership and
must not synthesize or open a contributor route from `weddingPlanId`. Other
invite-list responses do not expose a contributor context key.

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
not included. The create response reports `delivery.status` as `DELIVERED` only
after the device-delivery acknowledgement above. `DELIVERY_UNCERTAIN`, transport
failures, and missing/unknown acknowledgements map to `UNCERTAIN`; explicit
`NOT_ATTEMPTED`/`REJECTED` outcomes map to `UNAVAILABLE`. Neither outcome
deletes the pending invite or falsely reports that WhatsApp succeeded.

Every invite response contains a durable delivery snapshot:

```json
{
  "delivery": {
    "channel": "WHATSAPP",
    "status": "UNCERTAIN",
    "attemptedAt": "2026-07-18T12:00:00.000Z",
    "retryAfterSeconds": 42
  }
}
```

`status` is one of `UNKNOWN`, `PENDING`, `DELIVERED`, `UNCERTAIN`, or
`UNAVAILABLE`. `UNKNOWN` is reserved for invitations created before durable
delivery tracking; it never claims a historical failure. `PENDING` means a
delivery attempt was durably claimed but its final outcome was not stored yet.
If the transport attempt finishes but its final database update is temporarily
unavailable, the API conservatively returns the one-time link with `PENDING`
instead of losing the link or claiming delivery; the bounded persistence-failure
metric records the incident for operations.
The snapshot is returned by create, list, detail, and reissue, so refreshing a
client cannot erase delivery truth or bypass the retry window.

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
Reissue is blocked for 60 seconds after every delivery attempt. The stable
response is HTTP `429`, code `INVITE_REISSUE_COOLDOWN`, and a positive
`retryAfterSeconds`. A completion from an older superseded token attempt can
never overwrite or borrow the newer attempt's result; it returns HTTP `409`
with code `INVITE_DELIVERY_ATTEMPT_SUPERSEDED` and no raw bearer.

`POST /api/v1/invites/:token/request-otp` is public but bearer-and-phone bound.
It issues an internal `INVITE_ACCESS` OTP only when the 43-character raw token
fingerprints a live pending invitation and the canonical phone matches that
exact invitation. The sole accepted-invite exception is credential recovery
for a pre-migration member whose `appPasswordConfiguredAt` is still null; the
same phone must resolve to the existing member of that exact plan. Configured
accounts and all other accepted links remain ineligible. The OTP row is bound
to that `PlanInvite.id` through
`planInviteId`; it is not a general `LOGIN` code. A mismatch returns stable code
`INVITE_NOT_FOUND_FOR_PHONE` without plan details and without dispatching an
OTP. General login and different pending invitations for the same phone keep
separate active OTP contexts. `INVITE_ACCESS` is intentionally unavailable
through the public `/api/v1/auth/otp/request` and `/api/v1/auth/otp/verify`
contract, and those routes reject it. Database constraint
`OtpCode_invite_access_context_check`, installed by migration
`20260726041000_enforce_invite_otp_context`, requires `planInviteId` for
`INVITE_ACCESS` and forbids it for every other purpose.

A private token link always starts verification for the invited phone, even
when the device still has another application account signed in; it must not
query the token through that stale account.
`POST /api/v1/invites/:token/verify-otp` locks and rechecks the same live
invitation, then consumes only the matching
`(phone, INVITE_ACCESS, planInviteId)` code. A general login code or a code for
another invitation cannot complete the flow.
After OTP verification the application session is replaced by the verified
invitee, the exact token flow resumes in memory, and the client must display the
invite, role, and permission snapshot with explicit accept and decline actions.
Verification itself never accepts the invitation or creates membership. Only
an explicit authenticated accept request may enter the shared plan, and the
server still performs the normal verified-phone and atomic pending-invite claim
checks.

After the token and phone match, the request response includes
`accountSetupRequired`. This boolean is mandatory. It is `true` only when the
invited phone still needs an application credential, including the bounded
historical recovery above. The client then collects the contributor name, a
6-to-72-byte password, and matching password confirmation before calling
`POST /api/v1/invites/:token/verify-otp` with `{ phone, code, name, password }`.
That verification is bound again to the exact live token and phone. It consumes
the same invite-bound `INVITE_ACCESS` OTP, creates or claims the application
account with the participant's chosen password, marks
`appPasswordConfiguredAt`, and returns a complete access token, refresh token,
and refresh expiry; no second registration OTP is sent. The mobile client
rejects and clears any incomplete authentication response instead of mounting a
temporary in-memory session. Existing verified
application accounts send only `{ phone, code }` and receive a normal login
session. General `POST /api/v1/auth/otp/verify` never creates an account merely
because another pending invitation exists.

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
own current stored-permission ceiling; the role label itself grants no runtime
permission in that comparison.
The owner cannot add themselves as a shared member, unknown phone numbers are
rejected without auto-creating users, and duplicate members are rejected. A
former tenure ended by `MEMBER_LEFT` cannot be reopened through direct member
creation: the route returns HTTP `409`, code
`MEMBER_REENTRY_REQUIRES_INVITE`; a new explicit invitation and acceptance are
required.

Member creation, invitation creation/cancellation/reissue, member update, and
member removal all recheck the actor inside a retryable `SERIALIZABLE`
transaction. Lock order begins with `WeddingPlan FOR SHARE`, followed by the
acting non-owner's `SharedMember FOR SHARE`. Member update/removal then lock the
target member `FOR UPDATE`; invitation cancellation/reissue use a conditional
claim against the expected live invitation state. Delegation ceilings,
dependent notification/conversation cleanup, and the database mutation commit
together. Realtime permission-revocation signals are emitted only after commit.
Consequently, a permission revocation or plan archive that commits first makes
the waiting operation fail closed and leaves the target unchanged.

Before deleting a membership, member removal locks matching live invitations
in id order and revokes every unexpired pending row whose `inviteeUserId` or
`normalizedPhone` identifies that member. This happens in the same transaction
as membership deletion and prevents an older pending link from recreating
access. Accepted, declined, revoked, and expired invitation history is not
rewritten.

`DELETE /api/v1/wedding-plans/:weddingPlanId/members/me` is the contributor's
plan-leave operation; it is separate from account deletion. It runs in one
retryable `SERIALIZABLE` transaction and, for that plan only, retains the
member's already-recorded action-time snapshots, records `MEMBER_LEFT`, closes the active
contributor tenure, revokes matching pending invitations, clears
`User.activeWeddingPlanId` when it points to that plan, deletes the live
`SharedMember`, revokes provider-conversation participation, and purges private
money notifications. The frozen contribution rows remain part of the plan's
history. A new invitation later creates a new membership tenure rather than
reopening the ended one.

The DELETE body is required and contains the membership identity obtained from
the current contexts/dashboard response:

```json
{
  "expectedMemberId": "member-clx456-user-7",
  "expectedAuthorityVersion": 7
}
```

Both values must still match the row locked inside the leave transaction. A
different member id or authority version returns HTTP `409`, code
`MEMBERSHIP_CHANGED_SINCE_LEAVE_REQUEST`, and the Arabic message
`تغيّرت عضويتك في الخطة. حدّث المسارات ثم أعد محاولة المغادرة.` No membership
is deleted in that case. This prevents a lost-response replay from deleting a
new membership created by a later invitation.

The leave route participates in the standard `X-Client-Request-Id` replay
contract. It is also domain-idempotent after the exact membership has already
left: a repeat returns success with `deleted: true` and `alreadyLeft: true`
only when no current membership exists and retained tenure evidence proves the
prior leave. The first successful leave returns `alreadyLeft: false`. If a new
membership now exists, the required expected identity fails with the `409`
contract above instead of treating the old request as a leave for the new
tenure.
The plan owner cannot use this route and receives HTTP `403`, code
`PLAN_OWNER_CANNOT_LEAVE`, and message `لا يمكن لمالك الخطة مغادرة خطته`.

Invite routes support explicit acceptance and decline flows. OTP verification
must not call either action implicitly. They do not create chat or broad social
collaboration features.
Phone and user-id invitations require the authenticated account's verified
phone. Email-only invitations are rejected until verified-email ownership is
implemented; an unverified email string is never treated as identity proof.

## Contributor Live Scope And Frozen History

Every non-owner plan surface is filtered by the Backend. A current
`SharedMember` and the relevant current stored permission are required before
live section data is returned. Inside that gate, task, guest, money, provider,
dashboard, and related detail queries restrict entity ids to current assignment
or to `ContributionEvent` evidence owned by that user. Evidence is joined by
the contributor reference across current and previous `ContributorTenure` rows,
so a newly invited tenure can see that same person's qualifying live items only
after the new membership has the current section permission. A historical
event is never authority by itself, and no same-plan shortcut exposes another
contributor's entities.

Returning live queries also carry the current membership and stored flag in
their final SQL predicate. Multi-query money summaries, cost/payment/schedule
reads, dashboard reads, and other aggregate surfaces use the transaction-based
permission boundary so a committed revocation cannot pass through an earlier
in-memory context. Quote detail never returns its unguarded seed row; member and
invite lists revalidate current member-management authority in the final query.

Every qualifying contributor action creates its privacy-allowlisted frozen
snapshot inside the same domain transaction that performs the action. A later
permission revocation never re-reads or re-snapshots the live entity and never
turns an assignment-only row into historical contribution evidence. It writes
only a deterministic `SECTION_REVOKED` authority-boundary event before the
stored permission update; the earlier created/completed/payment/invite events
remain the historical record. Later owner edits to the original task, guest,
financial item, provider item, or member item cannot alter those append-only
events. Phone numbers, email addresses,
tokens, messages, notes, attachments, headers, query/body payloads, and values
matching credential/contact patterns are rejected from a snapshot.

`GET /api/v1/wedding-plans/:weddingPlanId/contributions` supports optional
`section`, `limit` (1 to 100, default 50), `offset` (default 0), and
`contributorUserId`. Owners may read the plan history and optionally filter by
contributor. A current non-owner member always receives only that member's own
reference across all tenures; a supplied `contributorUserId` cannot widen the
result. The response contains `historyCoverageStartsAt`, `total`, and events
with `id`, hashed `contributorReference`, `section`, `entityType`, `action`, the
frozen `snapshot`, `provenance`, `occurredAt`, and `capturedAt`. It deliberately
does not expose the source `entityId`, a raw contributor user id, or a live
entity projection.

`GET /api/v1/wedding-plans/:weddingPlanId/contributions/summary` returns a
distinct contributed-entity count for every contribution section. Owners may
optionally pass `contributorUserId`; non-owners are always scoped to themselves.
Both history routes require either plan ownership or a current membership. A
member whose section permission is revoked keeps access to their own frozen
history while the live section is blocked. After self-leave or owner removal,
the former contributor no longer has plan-route access; the append-only history
remains available to the plan owner and survives a later re-invitation.

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

Users with readable plan access can list guests. Guest mutations follow the live
`PermissionService.canManageGuests` policy: owner access or the stored
`SharedMember.canManageGuests` flag. A role name never grants guest rights at
runtime; it may only seed the flag when an invitation is created (see the
stored-flag rule under tasks).

All seven guest/group mutation shapes—guest create/bulk/update/delete and group
create/update/delete—run inside retryable `SERIALIZABLE` transactions. Lock
order is `WeddingPlan FOR SHARE`, the acting non-owner's
`SharedMember FOR SHARE`, an applicable referenced `GuestGroup FOR SHARE`, then
the existing `Guest` or `GuestGroup FOR UPDATE`. Permission and lifecycle state
remain stable through the write.

Bulk creation accepts from 1 to 200 items and is all-or-nothing: every item is
created in one transaction, so an invalid or duplicate later item rolls back
all earlier items. Guest name changes write `name` and `normalizedName`
together from the locked row; an unrelated update does not rewrite
`normalizedName`.

A non-null normalized phone identifies at most one guest inside one WeddingPlan,
regardless of display name. Multiple guests may omit the phone. The service
performs a friendly duplicate check, while the database unique constraint on
`(weddingPlanId, normalizedPhone)` is the concurrency authority. Migration
`20260726030000_enforce_unique_guest_phone` stores `phone` and
`normalizedPhone` as the same canonical value and installs
`Guest_phone_normalizedPhone_match_check`, which rejects partial or divergent
pairs. The migration takes a bounded exclusive table lock, canonicalizes
accepted historical forms, and aborts transactionally with generic non-PII
errors on an orphaned normalized value, an unparseable source phone, or a
canonical duplicate. It never merges or deletes private guest data.

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
- `GET /api/v1/governorates`
- `GET /api/v1/governorates/:id/districts`
- `GET /api/v1/districts/:id/localities`
- `GET /api/v1/catalogs/bootstrap?version=<known-version>`
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

Provider categories are one shared service catalog, not duplicated groom and
bride tables. Every category response includes `showForGroom` and
`showForBride`. The Flutter plan marketplace filters that full cached catalog
from `AccountContextController.selectedContext.persona`; provider and helper
contexts may inspect the union. The administrator may edit both visibility
flags, and at least one customer audience must remain selected in the admin UI.
Migration
`20260729050000_reconcile_provider_category_catalog` corrects databases that
ran the historical UUID-generating production bootstrap before deterministic
catalog IDs existed. It identifies canonical rows by stable slug, moves
`Provider.primaryCategoryId` and `ProviderService.categoryId` references from
eight known duplicate Arabic-slug rows, then deactivates those duplicates
without deleting provider data or arbitrary administrator-created categories.

Yemen administrative geography is separate from the compatibility `City`
catalog. Migration
`20260729040000_add_yemen_administrative_catalog` installs 22 first-level
administrative units (including `أمانة العاصمة`) and 335 districts from OCHA
Yemen/CSO HDX version `v01`. Governorate responses contain stable `code`,
Arabic/English names, center coordinates, and `districtsCount`. District
responses contain their stable code and `governorateId`. Only active rows are
returned. `City` remains in provider and quote contracts until those existing
relations receive an explicit, separately migrated replacement; it must not be
treated as a synonym for governorate.

Managed reference catalogs use a versioned publication contract rather than
shipping mutable lists inside the application binary. `GET
/api/v1/catalogs/bootstrap` returns only active, published revisions together
with active provider categories, cities, and governorates. A client may send
its last `version`; when nothing changed the response is `{ version,
unchanged: true }` and omits the payload. Catalog-item edits create a draft
revision. `POST /admin/reference-catalogs/:catalogKey/items/:id/publish`
publishes either the current draft or a selected historical revision, so
rollback is explicit and does not overwrite history. `DELETE` on a catalog
item publishes an inactive revision; it never hard-deletes prior versions.

The API seeds two system catalogs on start and never overwrites an existing
row or an admin edit: `money.starter.categories` (budget starter items) and
`tasks.starter` (suggested tasks, V1 checklist 4.9). A task item's
`metadata.persona` is `GROOM`, `BRIDE`, `SHARED` or `FAMILY` (shared and family
items are visible to both), and `metadata.daysBefore` is how many days before
the wedding date the app places its due date (clamped to today, undated without
a wedding date). The app adds chosen templates through the ordinary task
create route, so they work offline and for local plans, and skips a template
whose title the plan already has.

Administrative geography is managed separately through CATALOG permissions:
`/admin/governorates`, nested governorate districts, and nested district
localities. A locality is typed as `AREA`, `ISOLATION`, `NEIGHBORHOOD`, or
`ZONE`, may reference a parent in the same district, and rejects cyclic
parentage. Administrative codes and parent governorate/district ownership are
immutable after creation. Delete routes soft-disable rows. Security roles,
permissions, finance lifecycle states, and payment semantics are code-owned
contracts and are deliberately not administrator-editable catalogs.

`GET /api/v1/providers` keeps the paginated provider card contract compact but
complete enough for discovery. Every item includes `primaryCategory` plus a
`serviceSummary` built only from active services:

- `activeCount`
- `titles`
- unique `categories`
- `minPrice`, `maxPrice`, and `currency` when all published prices use one
  currency; mixed or absent prices remain `null`
- `pricesUpdatedAt`: the latest `priceUpdatedAt` of the active services, or
  `null` when none has a price

Provider trust signals (V1 checklist 4.11):

- Every public provider response carries `verifiedAt`: set only when an
  administrator checked the provider's documents through
  `PATCH /admin/providers/:id/verify` (allowed only while the provider is
  `ACTIVE`; the owner of the listing cannot verify it) and cleared by
  `PATCH /admin/providers/:id/unverify`. Both need `PROVIDERS_WRITE`.
- Every service response carries `priceUpdatedAt`: stamped when the service is
  created with a price and whenever its `basePrice` amount or `currency`
  actually changes; other edits keep it. It is `null` while the service has no
  price.
- `GET /api/v1/providers/:id` adds `responsiveness`, or `null` with fewer than
  3 counted quote requests in the last 180 days:
  `{ sampleSize, answeredPercent, typicalResponseHours }`. A request counts
  when the provider sent an offer on it, or when it is unanswered, not
  cancelled and older than 48 hours. `typicalResponseHours` is the median time
  to the first offer rounded up to whole hours (`null` when none was answered).
- `POST /api/v1/providers/:id/views` (public, `200 { recorded: true }`, throttled to 30 per minute
  per client) counts one view of an active provider's page in a daily total
  (V1 checklist 4.19); who viewed is not stored. `404` when the provider is not
  active. The app calls it when a customer opens the page, not from the
  provider's own preview.
- `GET /api/v1/provider/me/summary` adds `stats` for the provider's last 30
  days: `{ windowDays, profileViews, quoteRequests, offersAccepted,
  offersDecided, acceptanceRate, upcomingBookings, completedBookings }`.
  `acceptanceRate` is the whole-percent share of accepted offers among the
  offers customers accepted or rejected (`null` before any decision);
  bookings count confirmed bookings from today on and before today.

Provider search matches the provider identity/address fields and active service
title/description. The summary does not replace the full service contract from
`GET /api/v1/providers/:id/services`.

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
Review create, update, delete, publish, and hide operations lock the provider
row and update `ratingAverage`/`ratingCount` from the published review rows in
the same serializable transaction. Account deletion explicitly removes the
user's reviews and refreshes every surviving provider under the same ordered
locks; a successful response therefore cannot leave the public aggregate
behind the review data.

Provider service `basePrice`, package `price`, and quote-offer `amount` use the
same money boundary as the planning ledger: a present value must be
non-negative, contain at most 12 integer digits and 2 decimal places, and fit
PostgreSQL `numeric(14,2)`. Null or blank optional prices clear/omit the value.
Provider create/update, administrator service create/update, and marketplace
price filters all share this validator. Invalid precision or overflow returns
`400` before Prisma writes, so PostgreSQL never silently rounds a provider
price and never surfaces numeric overflow as `500`.
Provider quote-offer creation is stricter: `amount` is required and must be
greater than zero. A plan-scoped offer must use the current WeddingPlan
currency; the provider quote response includes `weddingPlan.currency` so the
client does not guess or default a plan offer to `YER`.

Plan-scoped `/api/v1` quote routes:

- `POST /api/v1/wedding-plans/:weddingPlanId/quote-requests`
- `GET /api/v1/wedding-plans/:weddingPlanId/quote-requests`
- `GET /api/v1/quote-requests/:id`
- `PATCH /api/v1/quote-requests/:id/cancel`
- `PATCH /api/v1/quote-offers/:id/accept`
- `PATCH /api/v1/quote-offers/:id/reject`

Quote-request creation is an authenticated online mutation and should send a
stable `X-Client-Request-Id` for one logical submission. Replaying the same
method, target, and body with the same key returns the stored response without
duplicating the request, notification, or outbox event. A different key is a
new attempt, but the domain still rejects an identical active request with
`ACTIVE_QUOTE_REQUEST_EXISTS`. Identity is requester, provider, optional plan,
optional service (including `null`), event date, and city; message, budget,
contact, and guest details do not create a second active lead. `SENT`, `VIEWED`,
and `RESPONDED` are active, except that a `RESPONDED` cycle whose pending offers
are all past `validUntil` is effectively closed for starting a new request.
The provider's new-quote inbox notification is generic and does not persist the
requester's name or phone in its title, body, or metadata. Contact fields are
available only through the permission-checked quote contract. Migration
`20260726010000_scrub_notification_contact_pii` replaces historical
provider-portal quote-request bodies and conversation-message alert bodies that
copied requester/sender names with generic text.

Quote-offer responses expose derived `isExpired` and `isActionable` fields.
Expired pending offers remain historically `PENDING` in storage, cannot be
accepted or rejected, and return `QUOTE_OFFER_EXPIRED` if a stale client tries.
Provider offer creation locks the quote request and permits one offer for the
current request cycle. The provider may edit that one offer only while the
offer is `PENDING` and the request is `RESPONDED`; the resulting amount remains
positive and its currency remains equal to the linked plan currency.

Every quote decision uses one serializable transition policy. Request rows are
locked before offer rows, the current request/offer states are re-read under
those locks, and each write includes its expected prior state. A losing
accept/reject/update/cancel race therefore fails instead of overwriting the
winner. An accepted offer cannot be edited, rejected, or left behind a
cancelled request.

Accepting a plan-scoped offer requires both provider-management and
money-management permission. It atomically accepts the offer, links the
provider, and creates or returns the single `WeddingCost` identified by the
unique `quoteOfferId`. The offer amount must be positive and use the plan
currency. The service category is matched logically against
`BudgetCategory.normalizedName`; otherwise `أخرى` is reused or created without
an allocation. Acceptance first takes `WeddingPlan FOR SHARE` and re-reads its
lifecycle state inside the serializable transaction. For a non-owner it then
locks and re-reads the relevant `SharedMember` permission row before locking
`QuoteRequest`, `QuoteOffer`, and finally the live `Provider` row. If plan
archive or permission revocation commits first, acceptance fails and creates
no cost or provider link. If acceptance takes the lifecycle lock first, archive
waits until the complete acceptance graph commits. A new acceptance requires
the locked provider to remain `ACTIVE`. Replaying an already committed
`ACCEPTED` offer is a historical,
idempotent read: it returns the existing cost and provider link without
rewriting either or creating another notification, even if the provider later
became non-active. Missing or mismatched historical artifacts return a conflict
instead of being silently repaired by the replay.

The response contains:

- `automaticCostCreated: true`
- `weddingCost`, using the canonical cost response including
  `totalAmount`, `paidAmount`, and derived `remainingAmount`
- `costSuggestion` with `suggestedAction: "VIEW_COST"`, `costId`, and
  `availableActions: ["VIEW_COST"]`
- `nextActions: ["viewCost", "viewAcceptedProvider"]`

Retries return the existing cost and do not repeat notifications. Acceptance
does not create a CostPayment, PaymentSchedule, task, deposit, paid booking, or
confirmed booking. A `WeddingCost` or `PlanProviderLink` tied to an offer is
valid only while that offer and its request are `ACCEPTED`.

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

Listings the back office made before the provider had an account (V1
checklist 4.18):

- `POST /admin/providers` (`PROVIDERS_WRITE`) creates an `ACTIVE` provider with
  no account from `{ businessName, phone, whatsapp?, cityId, categoryId,
  address?, description? }`. The phone is normalized; a phone any provider
  already uses (in any of its spellings) is `409 PROVIDER_PHONE_TAKEN`. The
  listing shows in the directory once it has an active service
  (`POST /admin/services`).
- `GET /api/v1/provider/claimable` returns `{ listing: { id, businessName } }`
  when an active, unclaimed listing carries the caller's phone and the caller
  owns no provider; otherwise `{ listing: null }`. Every session's phone is
  verified by OTP, which is the proof of ownership.
- `POST /api/v1/provider/claim/:providerId` makes the caller that listing's
  provider (the account is promoted like an approved applicant) and returns
  the provider profile. A listing that is not the caller's to claim is `404`;
  a caller who already owns a provider is `409`.
- `POST /api/v1/provider/apply` is `409 PROVIDER_LISTING_CLAIMABLE` while such a
  listing waits under the caller's phone.
- Public provider responses carry `isClaimed`. A quote request to a provider
  without an account (unclaimed, or whose owner deleted their account) is
  `409 PROVIDER_NOT_CLAIMED`; customers reach it by phone or WhatsApp.

Provider capabilities are based on the current database status, not a JWT role
or a hidden UI action:

| Provider status | Read profile/status | Edit profile | Dashboard, catalog management, reviews, quote/customer data, provider-side conversations |
| --- | --- | --- | --- |
| `PENDING` | allow | allow | deny |
| `NEEDS_CHANGES` | allow | allow | deny |
| `ACTIVE` | allow | allow | allow |
| `SUSPENDED` | allow | deny | deny |
| `REJECTED` | allow | deny | deny |

An operational request from a non-active provider returns HTTP `403` with code
`PROVIDER_NOT_ACTIVE`. A profile mutation in `SUSPENDED` or `REJECTED` returns
HTTP `403` with code `PROVIDER_PROFILE_READ_ONLY`. Moving a linked provider to
a non-active status revokes that provider user's current conversation-room
access after the status transaction commits; every later HTTP/socket
authorization still rechecks live database state.

Every successful administrator lifecycle transition creates a durable
account-level `GENERAL` notification for the provider owner with the new
`providerStatus`, the review note when present, and
`routeTarget=/provider/dashboard`. Notification creation is inside the same
serializable transaction as the status update, so the two cannot diverge.

Provider-audience quote and chat notifications are filtered before inbox
pagination, counts, and bulk-read mutation while the provider is non-active.
Direct access to one hidden provider notification returns
`PROVIDER_NOT_ACTIVE`; wedding/customer/account notifications for the same user
remain available. Notification reads send `Cache-Control: private, no-store`.
New notification metadata records `recipientAudience`, while legacy provider
quote routes and chat `providerId` metadata remain recognized.

`/api/v1/contexts` and `/api/v1/contexts/validate` expose this same live
lifecycle/capability matrix additively while retaining the compatibility
`permissions`, `role`, identifiers, display, and availability fields.

Plan members may read plan quote requests through the plan-scoped route. Budget
and contact fields remain redacted unless the corresponding money/provider
permission allows them; quote mutations require provider-management permission,
and acceptance additionally requires money-management permission.

## Bookings And Provider Calendar

V1 checklist 4.6. A booking reserves the wedding day with a provider after the
customer accepted their offer. It is tracking only: no deposit, payment or
money moves through it.

- `POST /api/v1/me/quote-requests/:id/booking` `{ eventDate?: "YYYY-MM-DD", note? }`
  — the quote's requester or the plan owner (with provider-management
  permission) asks for the day; the quote's `eventDate` when omitted. The quote
  must be `ACCEPTED`. A declined or cancelled booking is reopened as
  `REQUESTED`; an open one returns `409 BOOKING_ALREADY_OPEN`.
- `PATCH /api/v1/me/bookings/:id/cancel` `{ note? }` — the customer cancels a
  requested or confirmed booking before its day.
- `GET /api/v1/provider/me/bookings` — the provider's open requests and
  confirmed bookings from today on, with `customerName`, `guestCount`,
  `location`.
- `PATCH /api/v1/provider/me/bookings/:id/confirm|decline|cancel` `{ note? }`.
- `GET|POST /api/v1/provider/me/blocked-dates` (`{ date }`) and
  `DELETE /api/v1/provider/me/blocked-dates/:date` — days the provider marks
  unavailable.

A booking response is `{ id, quoteRequestId, quoteOfferId, providerId,
eventDate, status, lifecycleStatus, cancelledBy, note, confirmedAt, declinedAt,
cancelledAt, createdAt, updatedAt }`. `status` is `REQUESTED | CONFIRMED |
DECLINED | CANCELLED`; `lifecycleStatus` adds `COMPLETED` for a confirmed
booking whose day has passed. Quote responses (customer and provider) carry
`booking` (or `null`).

Availability: a request or a confirmation for a blocked day, or for a day the
provider is already confirmed on, returns `409 BOOKING_DATE_UNAVAILABLE`; a
partial unique index keeps one `CONFIRMED` booking per provider per day, so of
two racing confirmations exactly one succeeds. Blocking a day that holds a
confirmed booking returns `409 BOOKING_DATE_HAS_BOOKING`. A past day returns
`400 BOOKING_DATE_IN_PAST`; a step the status does not allow returns
`409 BOOKING_NOT_ALLOWED`. Each step notifies the other side
(`BOOKING_UPDATED`).

Reviews (F10): `POST /api/v1/providers/:id/reviews` requires a confirmed
booking with the provider whose day has passed; otherwise
`403 REVIEW_REQUIRES_COMPLETED_BOOKING`.

## Guest Invitations And RSVP

V1 checklist 4.7. Each guest gets a personal link to confirm or decline,
without an account.

- `POST /api/v1/guests/:id/invitation-link` (guest-management permission; a
  contributor only for guests they added) returns `{ guestId, url, phone,
  invitationStatus, message }`. `url` is `INVITE_PUBLIC_ORIGIN/rsvp/<token>`
  with a 43-character token; only its SHA-256 is stored, and a new link
  retires the previous one. A `NOT_SENT` invitation becomes `SENT`.
  `message` is the Arabic WhatsApp text (plan title, date, place, link).
- `GET /api/v1/public/rsvp/:token` (no auth, 30/min) returns `{ guestName,
  planTitle, weddingDate, locationLabel, attendanceStatus, companionsCount,
  maxCompanions, respondedAt }`.
- `POST /api/v1/public/rsvp/:token` (no auth, 10/min) `{ attendance:
  "CONFIRMED" | "DECLINED", companionsCount? }` (0–20; 0 when declining)
  updates the guest's attendance, status and companions, and notifies the
  plan owner (`GUEST_RESPONDED`).

An unknown or malformed token, or an archived plan, returns
`404 RSVP_LINK_NOT_FOUND`. The public page `/rsvp/<token>` on the public site
calls these routes on its own origin; the edge proxy forwards
`/api/v1/public/rsvp/*` on the site host to the API.

## Quote Conversations And Media

Conversations begin only with a real quote request; open or unsolicited
messaging is excluded. A `PLAN` conversation is unique by WeddingPlan and
Provider. An `ACCOUNT` conversation is unique by requester account and
Provider. Creating a QuoteRequest creates or reuses that context inside the
same transaction, so opening chat never mutates server state.

- `GET /api/v1/quote-requests/:quoteRequestId/conversation` returns the existing
  conversation linked to that request.
- `GET /api/v1/conversations` lists the current account's conversations with
  optional `cursor` and `limit` (default 30, maximum 50), returning
  `{ items, nextCursor }`. A non-active provider's provider-side entries are
  excluded at query time, while plan-owner, contributor, and customer-side
  entries for the same account remain eligible.
- `GET /api/v1/conversations/:id` returns the exact participant-authorized
  conversation summary, so a direct route does not depend on that conversation
  appearing in the first inbox page.
- `GET /api/v1/conversations/:id/quote-requests` returns every linked request;
  price and contact fields remain permission-redacted.
- `GET /api/v1/conversations/:id/timeline` returns cursor-paginated human
  messages and request/offer system events in one stable chronological stream.
- `GET /api/v1/conversations/:id/messages` returns paginated message history.
- `POST /api/v1/conversations/:id/messages` sends text and approved signed-media
  attachments. Immediately before persistence, one serializable transaction
  locks the conversation and active participant row, rechecks current
  plan/provider authority, and locks an applicable shared-member permission
  row before deriving recipients. A permission revocation that commits first
  therefore rejects the send without creating a message, notification, or
  outbox event.
- A message remains a valid conversation write when a recipient has disabled
  `providerMessagesEnabled`, but no chat notification or notification-created
  outbox event is written for that recipient. Before deciding, notification
  creation locks the recipient `User` row `FOR SHARE` and re-reads the current
  preference.
- `GET /api/v1/conversations/:id/attachments/:attachmentId/download` refreshes a
  private attachment link after rechecking conversation membership.
- `PATCH /api/v1/conversations/:id/read`, `/mute`, and `/block` update participant
  state. Mark-read never reactivates a revoked participant.
- `POST /api/v1/conversations/:id/report` creates a moderation report.

Member/provider authority changes that revoke conversation access enqueue
`CONVERSATION_ACCESS_REVOKED` in the same transaction as the authoritative
permission or lifecycle mutation. The immediate Socket.IO leave/disconnect is a
best-effort low-latency path; strict outbox delivery keeps the revocation
retryable until the realtime adapter completes it.

Conversation summaries include `scope`, optional `weddingPlan`, `provider`,
`quoteRequestCount`, `latestQuoteRequest`, `lastActivityAt`,
`unreadMessageCount`, personal `muted`, aggregate/side block state,
`providerJoined`, `canSend`, and UI permissions. They never present one
QuoteRequest as the conversation identity. Unread counts include human messages
only; system events update activity but not unread.

For `PLAN`, access is derived live from plan ownership, explicit
`SharedMember.canManageProviders`, or `Provider.userId`. For `ACCOUNT`, access
is limited to the requester and linked provider account. Participant rows store
joined/revoked/read/mute state only. Removing `canManageProviders` revokes the
participant and forces current sockets out of the room. This permission is
strong because it exposes the prior conversation history and allows sending as
the plan; money fields still require money permissions. Role defaults populate
the stored flag only when an invitation is created. Direct member creation
stores an omitted provider-management flag as `false`, and later role changes
preserve it. An explicit stored `false` is authoritative for both provider APIs
and conversations; a role name never silently restores the capability. Revoked
participants are reactivated only by an explicit provider-management permission
grant, never as a side effect of opening, reading, marking read, or sending.

Authenticated Socket.IO events include `conversation:join`,
`conversation:message`, `conversation:read`, `conversation:event`,
`conversation:activity-available`, and `conversation:permission-revoked`.
Server authorization is rechecked before join, send, and read. A provider with
no linked User does not block quote creation; the summary returns
`providerJoined: false` and `canSend: false` until that provider account opens
or sends in the conversation. Customer reads do not falsely join the provider,
and the conversation remains readable while sending returns the stable
`PROVIDER_NOT_JOINED` conflict contract.

If the linked provider becomes non-active, provider-side rows disappear from
the inbox list. Direct provider-side read, join, and send return
`PROVIDER_NOT_ACTIVE`. This distinction preserves unrelated wedding/customer
contexts owned by the same account. The customer may still read the historical
conversation, but its summary reports `canSend: false`. If the linked
WeddingPlan is archived, authorized historical reads also remain available
while sending returns `PLAN_ARCHIVED_READ_ONLY`.

The serializable message-send path locks the conversation, then the linked
`Provider` lifecycle row, followed by the applicable shared-member permission
and participant rows before creating a message, notification, or outbox event.
If provider suspension commits first, a provider-side send fails with
`PROVIDER_NOT_ACTIVE` and produces no durable side effect. The transaction does
not yet make every conversation-state or marketplace mutation atomic with every
applicable participant, plan, provider, and account lifecycle row. Those
remaining boundaries stay explicit `BE-RACE-001` Phase 2 work.

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
  short-lived MFA challenge after sending a private `ADMIN_LOGIN` OTP.
- `POST /api/v1/auth/admin/login/complete` first consumes the exact OTP through
  the row-locked one-time verifier, then compare-and-set consumes the live
  challenge while issuing the administrator session. It returns a short-lived
  access JWT and sets the rotating refresh token only as a path-scoped
  `HttpOnly`, `SameSite=Strict` cookie (`Secure` in production).
- `POST /api/v1/auth/admin/refresh` rotates that cookie and its server session.
- `POST /api/v1/auth/admin/logout` revokes the server session and clears the cookie.

General password login, general OTP login, and general refresh never mint the
`scope=admin` plus `admin_mfa` assurance required by `AdminGuard`. Admin access
JWTs use the same mandatory live `sid` binding documented in Common Rules;
refresh or logout revokes the prior row, so its access JWT stops working
immediately. Admin access JWTs cannot authorize `/api/v1` product APIs or Chat,
and application access JWTs cannot authorize `/admin`. The JSON contract never
returns the admin refresh token.

- `GET /admin/dashboard/stats`
- `GET /admin/reports/overview`
- `GET /admin/reports/success` (`REPORTS_READ`, V1 checklist 4.21): `activeUsers`
  `{ windowDays: 7, active, total }` (accounts that signed in or renewed an
  application session in the window), `costs { recorded, plansWithCosts,
  perPlan }`, `conversion { windowDays: 30, quoteRequests, confirmedBookings,
  rate }` (bookings created in the window that are confirmed, over quote
  requests created in it; `rate` a whole percent or `null`),
  `visibleProviders` (active with an active service), and `prices`: per city,
  category and currency `{ cityName, categoryName, providers, services, min,
  median, max }` from active services of active providers, only for groups
  priced by at least 3 different providers so no provider's own price shows.
- `GET /admin/providers/applications`
- `GET /admin/providers/applications/:id`
- `POST /admin/providers` (a listing without an account, see Provider References)
- `PATCH /admin/providers/:id/approve`
- `PATCH /admin/providers/:id/reject`
- `PATCH /admin/providers/:id/request-changes`
- `PATCH /admin/providers/:id/suspend`
- `PATCH /admin/providers/:id/activate`
- `PATCH /admin/providers/:id/verify`
- `PATCH /admin/providers/:id/unverify`
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

Provider lifecycle actions also follow this server-enforced matrix:

| Current status | Allowed administrator actions |
| --- | --- |
| `PENDING` | approve, request changes, reject |
| `NEEDS_CHANGES` | approve, reject |
| `REJECTED` | approve, request changes |
| `ACTIVE` | suspend |
| `SUSPENDED` | activate |

Without an explicit `status` query, `/admin/providers/applications` returns
`PENDING`, `NEEDS_CHANGES`, and `REJECTED`, while `/admin/providers` returns
`ACTIVE` and `SUSPENDED`. Supplying a valid status remains an explicit
administrative filter and overrides that page default.

The admin user, provider application, provider, service, review, conversation
report, and notification list routes accept positive `page` and `limit` query
parameters (`limit` is capped server-side). They return
`{ items, page, limit, total, totalPages }`; the UI must use this metadata and
must not silently truncate to its first 50/80/100 results.

Admin services are real `ProviderService` management operations. Deleting a service safely deactivates it (`isActive=false`) instead of hard-deleting data.

Admin reviews are real `ProviderReview` moderation operations. Publishing or
hiding a review recalculates the provider public rating from published reviews
only, inside the same provider-row-locked transaction as the moderation
change. Reviewer contact details are not part of the moderation response or
search contract.

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
  Pending reservations expire after 24 hours by default and completed
  responses after 168 hours. The hourly cleanup deletes only expired completed
  responses. An expired row with `completedAt = NULL` is an ambiguous
  tombstone because its domain transaction may already have committed; it is
  retained, counted by an operations metric, and can be released or completed
  only through the id-bound, evidence-gated reconciliation command documented
  in the deployment runbook.
- Access/error telemetry records the matched route template only. Query
  strings, concrete resource ids, invite tokens, exception messages, and
  exception stacks are not sent to application logs or Sentry. Unmatched
  routes are recorded as `unmatched`, and invalid client request ids are
  replaced with a server-generated UUID. The expected `GET /ready` `503`
  readiness-probe result is excluded from error logging and Sentry; all other
  `5xx` responses remain reportable.
- Transactional outbox events are retained through retry and exhausted events
  remain as `FAILED` dead letters. The dispatcher validates each payload and
  awaits strict realtime delivery; an unavailable adapter or rejected socket
  action is not marked processed and remains retryable. A cross-replica
  scheduler removes only `PROCESSED` receipts older than seven days every six
  hours. Account deletion removes notification/conversation outbox rows owned
  by that account inside the same database transaction.
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
| DELETE | `/admin/districts/:id` | `catalogs.disableDistrict` | 🔒 |
| PATCH | `/admin/districts/:id` | `catalogs.updateDistrict` | 🔒 |
| GET | `/admin/districts/:id/localities` | `catalogs.listLocalities` | 🔒 |
| POST | `/admin/districts/:id/localities` | `catalogs.createLocality` | 🔒 |
| GET | `/admin/governorates` | `catalogs.listGovernorates` | 🔒 |
| POST | `/admin/governorates` | `catalogs.createGovernorate` | 🔒 |
| DELETE | `/admin/governorates/:id` | `catalogs.disableGovernorate` | 🔒 |
| PATCH | `/admin/governorates/:id` | `catalogs.updateGovernorate` | 🔒 |
| GET | `/admin/governorates/:id/districts` | `catalogs.listDistricts` | 🔒 |
| POST | `/admin/governorates/:id/districts` | `catalogs.createDistrict` | 🔒 |
| DELETE | `/admin/localities/:id` | `catalogs.disableLocality` | 🔒 |
| PATCH | `/admin/localities/:id` | `catalogs.updateLocality` | 🔒 |
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
| POST | `/admin/providers` | `admin.createListedProvider` | 🔒 |
| GET | `/admin/providers/:id` | `admin.getProvider` | 🔒 |
| PATCH | `/admin/providers/:id/activate` | `admin.activateProvider` | 🔒 |
| PATCH | `/admin/providers/:id/approve` | `admin.approveProvider` | 🔒 |
| PATCH | `/admin/providers/:id/reject` | `admin.rejectProvider` | 🔒 |
| PATCH | `/admin/providers/:id/request-changes` | `admin.requestProviderChanges` | 🔒 |
| PATCH | `/admin/providers/:id/suspend` | `admin.suspendProvider` | 🔒 |
| PATCH | `/admin/providers/:id/unverify` | `admin.unverifyProvider` | 🔒 |
| PATCH | `/admin/providers/:id/verify` | `admin.verifyProvider` | 🔒 |
| GET | `/admin/providers/applications` | `admin.listProviderApplications` | 🔒 |
| GET | `/admin/providers/applications/:id` | `admin.getProviderApplication` | 🔒 |
| GET | `/admin/reference-catalogs` | `catalogs.listCatalogs` | 🔒 |
| GET | `/admin/reference-catalogs/:catalogKey` | `catalogs.getCatalog` | 🔒 |
| POST | `/admin/reference-catalogs/:catalogKey/items` | `catalogs.createItem` | 🔒 |
| DELETE | `/admin/reference-catalogs/:catalogKey/items/:id` | `catalogs.disableItem` | 🔒 |
| PATCH | `/admin/reference-catalogs/:catalogKey/items/:id` | `catalogs.updateItem` | 🔒 |
| POST | `/admin/reference-catalogs/:catalogKey/items/:id/publish` | `catalogs.publishItem` | 🔒 |
| GET | `/admin/reports/overview` | `admin.getReportsOverview` | 🔒 |
| GET | `/admin/reports/success` | `admin.getSuccessReport` | 🔒 |
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
| POST | `/api/v1/account-deletions/status` | `account-deletion-status.status` |  |
| POST | `/api/v1/auth/admin/login` | `auth.startAdminLogin` |  |
| POST | `/api/v1/auth/admin/login/complete` | `auth.completeAdminLogin` |  |
| POST | `/api/v1/auth/admin/logout` | `auth.logoutAdmin` |  |
| POST | `/api/v1/auth/admin/password-reset/confirm` | `auth.confirmAdminPasswordReset` |  |
| POST | `/api/v1/auth/admin/password-reset/request` | `auth.requestAdminPasswordReset` |  |
| POST | `/api/v1/auth/admin/password-reset/verify` | `auth.verifyAdminPasswordReset` |  |
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
| GET | `/api/v1/catalogs/bootstrap` | `catalogs.getBootstrap` |  |
| GET | `/api/v1/cities` | `marketplace.findCities` |  |
| GET | `/api/v1/contexts` | `contexts.list` | 🔒 |
| POST | `/api/v1/contexts/validate` | `contexts.validate` | 🔒 |
| GET | `/api/v1/conversations` | `conversations.list` | 🔒 |
| GET | `/api/v1/conversations/:id` | `conversations.get` | 🔒 |
| GET | `/api/v1/conversations/:id/attachments/:attachmentId/download` | `conversations.downloadAttachment` | 🔒 |
| PATCH | `/api/v1/conversations/:id/block` | `conversations.block` | 🔒 |
| GET | `/api/v1/conversations/:id/messages` | `conversations.messages` | 🔒 |
| POST | `/api/v1/conversations/:id/messages` | `conversations.send` | 🔒 |
| PATCH | `/api/v1/conversations/:id/mute` | `conversations.mute` | 🔒 |
| GET | `/api/v1/conversations/:id/quote-requests` | `conversations.quoteRequests` | 🔒 |
| PATCH | `/api/v1/conversations/:id/read` | `conversations.markRead` | 🔒 |
| POST | `/api/v1/conversations/:id/report` | `conversations.report` | 🔒 |
| GET | `/api/v1/conversations/:id/timeline` | `conversations.timeline` | 🔒 |
| GET | `/api/v1/cost-payments/:id` | `wedding-costs.get` | 🔒 |
| POST | `/api/v1/cost-payments/:id/reverse` | `wedding-costs.reverse` | 🔒 |
| GET | `/api/v1/costs/:costId/receipts` | `cost-receipts.list` | 🔒 |
| POST | `/api/v1/costs/:costId/receipts` | `cost-receipts.add` | 🔒 |
| DELETE | `/api/v1/costs/:costId/receipts/:receiptId` | `cost-receipts.remove` | 🔒 |
| DELETE | `/api/v1/costs/:id` | `wedding-costs.remove` | 🔒 |
| GET | `/api/v1/costs/:id` | `wedding-costs.get` | 🔒 |
| PATCH | `/api/v1/costs/:id` | `wedding-costs.update` | 🔒 |
| POST | `/api/v1/costs/:id/cancel` | `wedding-costs.cancel` | 🔒 |
| GET | `/api/v1/costs/:id/payment-schedules` | `wedding-costs.listSchedules` | 🔒 |
| POST | `/api/v1/costs/:id/payment-schedules` | `wedding-costs.createSchedule` | 🔒 |
| GET | `/api/v1/costs/:id/payments` | `wedding-costs.listPayments` | 🔒 |
| POST | `/api/v1/costs/:id/payments` | `wedding-costs.createPayment` | 🔒 |
| GET | `/api/v1/dashboard/home` | `dashboard.getHome` | 🔒 |
| GET | `/api/v1/districts/:id/localities` | `catalogs.listLocalities` |  |
| DELETE | `/api/v1/funding-sources/:id` | `funding-sources.remove` | 🔒 |
| PATCH | `/api/v1/funding-sources/:id` | `funding-sources.update` | 🔒 |
| POST | `/api/v1/funding-sources/:id/repayments` | `funding-sources.addRepayment` | 🔒 |
| GET | `/api/v1/governorates` | `marketplace.findGovernorates` |  |
| GET | `/api/v1/governorates/:id/districts` | `marketplace.findDistricts` |  |
| DELETE | `/api/v1/guest-groups/:id` | `guests.removeGroup` | 🔒 |
| PATCH | `/api/v1/guest-groups/:id` | `guests.updateGroup` | 🔒 |
| DELETE | `/api/v1/guests/:id` | `guests.remove` | 🔒 |
| GET | `/api/v1/guests/:id` | `guests.findOne` | 🔒 |
| PATCH | `/api/v1/guests/:id` | `guests.update` | 🔒 |
| POST | `/api/v1/guests/:id/invitation-link` | `guest-rsvp.createInvitationLink` | 🔒 |
| GET | `/api/v1/invites/:token` | `sharing.getInvite` | 🔒 |
| POST | `/api/v1/invites/:token/accept` | `sharing.acceptInvite` | 🔒 |
| POST | `/api/v1/invites/:token/decline` | `sharing.declineInvite` | 🔒 |
| POST | `/api/v1/invites/:token/request-otp` | `sharing.requestOtp` |  |
| POST | `/api/v1/invites/:token/verify-otp` | `sharing.verifyOtp` |  |
| GET | `/api/v1/invites/mine` | `sharing.findMyInvites` | 🔒 |
| DELETE | `/api/v1/loan-repayments/:id` | `funding-sources.remove` | 🔒 |
| PATCH | `/api/v1/loan-repayments/:id` | `funding-sources.update` | 🔒 |
| GET | `/api/v1/me` | `me.me` | 🔒 |
| PATCH | `/api/v1/me/bookings/:id/cancel` | `bookings.cancelBooking` | 🔒 |
| GET | `/api/v1/me/favorite-providers` | `marketplace.findMyFavoriteProviders` | 🔒 |
| GET | `/api/v1/me/quote-requests` | `marketplace.findMyQuoteRequests` | 🔒 |
| GET | `/api/v1/me/quote-requests/:id` | `marketplace.findMyQuoteRequest` | 🔒 |
| POST | `/api/v1/me/quote-requests/:id/booking` | `bookings.requestBooking` | 🔒 |
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
| POST | `/api/v1/provider/claim/:providerId` | `provider-dashboard.claimListing` | 🔒 |
| GET | `/api/v1/provider/claimable` | `provider-dashboard.findClaimableListing` | 🔒 |
| GET | `/api/v1/provider/me/blocked-dates` | `bookings.listBlockedDates` | 🔒 |
| POST | `/api/v1/provider/me/blocked-dates` | `bookings.blockDate` | 🔒 |
| DELETE | `/api/v1/provider/me/blocked-dates/:date` | `bookings.unblockDate` | 🔒 |
| GET | `/api/v1/provider/me/bookings` | `bookings.listBookings` | 🔒 |
| PATCH | `/api/v1/provider/me/bookings/:id/cancel` | `bookings.cancel` | 🔒 |
| PATCH | `/api/v1/provider/me/bookings/:id/confirm` | `bookings.confirm` | 🔒 |
| PATCH | `/api/v1/provider/me/bookings/:id/decline` | `bookings.decline` | 🔒 |
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
| POST | `/api/v1/providers/:id/views` | `marketplace.recordProviderView` |  |
| GET | `/api/v1/public/rsvp/:token` | `guest-rsvp.getInvitation` |  |
| POST | `/api/v1/public/rsvp/:token` | `guest-rsvp.respond` |  |
| DELETE | `/api/v1/push/installations/current` | `push.unregister` | 🔒 |
| PUT | `/api/v1/push/installations/current` | `push.register` | 🔒 |
| PATCH | `/api/v1/quote-offers/:id/accept` | `marketplace.acceptOffer` | 🔒 |
| PATCH | `/api/v1/quote-offers/:id/reject` | `marketplace.rejectOffer` | 🔒 |
| GET | `/api/v1/quote-requests/:id` | `marketplace.findQuoteRequest` | 🔒 |
| PATCH | `/api/v1/quote-requests/:id/cancel` | `marketplace.cancelQuoteRequest` | 🔒 |
| GET | `/api/v1/quote-requests/:quoteRequestId/conversation` | `conversations.getForQuote` | 🔒 |
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
| GET | `/api/v1/wedding-plans/:planId/funding-sources` | `funding-sources.findForPlan` | 🔒 |
| POST | `/api/v1/wedding-plans/:planId/funding-sources` | `funding-sources.create` | 🔒 |
| PUT | `/api/v1/wedding-plans/:planId/money-budget` | `money-summary.replaceMoneyBudget` | 🔒 |
| GET | `/api/v1/wedding-plans/:planId/money-summary` | `money-summary.getMoneySummary` | 🔒 |
| GET | `/api/v1/wedding-plans/:weddingPlanId/budget-categories` | `budget-categories.findForPlan` | 🔒 |
| POST | `/api/v1/wedding-plans/:weddingPlanId/budget-categories` | `budget-categories.create` | 🔒 |
| GET | `/api/v1/wedding-plans/:weddingPlanId/contributions` | `contribution-history.list` | 🔒 |
| GET | `/api/v1/wedding-plans/:weddingPlanId/contributions/summary` | `contribution-history.summary` | 🔒 |
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
| DELETE | `/api/v1/wedding-plans/:weddingPlanId/members/me` | `sharing.leavePlan` | 🔒 |
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
