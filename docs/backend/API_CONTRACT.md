# API Contract

This document is the route-level source of truth for the current Aarast backend contract. Other Markdown files should link here instead of copying endpoint lists.

Current documentation snapshot: 2026-08-11.

Source status:

- Backend source contains the Wedding Financial OS API surface plus provider-reference and quote-lead support.
- Bookings are confirmed by the provider and carry no payment. No route moves money.

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

D112 (Q-14): a code-quota `429` says which limit was reached and how long is
left: `{ statusCode: 429, code, message, retryAfterSeconds }`. `code` is one
of `OTP_LIMIT_COOLDOWN` (a minute between two codes), `OTP_LIMIT_PHONE_HOUR`
(5 an hour for the number from the asking address), `OTP_LIMIT_PHONE_DAY` (10
a day for the number from the asking address), `OTP_LIMIT_PHONE_CEILING` (the
number across every address: 15 an hour, 30 a day), `OTP_LIMIT_NETWORK` (the
sender's address) and `OTP_LIMIT_SERVICE_DAY` (the whole app's day). D112
(Q-5): the number's allowance is counted per address, so codes a stranger
asks for someone's number do not use up what its owner may ask from their
own address; the ceiling keeps the WhatsApp sender safe. `retryAfterSeconds` runs to the turn of that limit's window;
`message` is the Arabic sentence the phone shows as is, with the wait rounded
up («هذا الرقم طلب 5 رموز في ساعة. يتاح رمز جديد بعد 50 دقيقة.»). The refused
request is not counted.

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
- Phone change (V1 checklist 4.14), both authenticated:
  `POST /api/v1/auth/phone-change/request` `{ phone }` sends a `VERIFY_PHONE`
  OTP to the new number (same delivery, quota and response as
  `otp/request`; throttled to 5 per minute) whether or not an account uses it,
  `400 PHONE_UNCHANGED` for the account's own number. `POST
  /api/v1/auth/phone-change/confirm` `{ phone, code }` claims the OTP; only
  then `409 PHONE_IN_USE` when any account uses the number (any spelling), so
  the answer reaches whoever holds it (RA-BE-21); otherwise it moves the
  account (`phone`, `phoneVerifiedAt`) and revokes every application session
  (`USER_SESSIONS_REVOKED`), returning `{ changed: true, phone }`; a wrong
  code is the usual OTP failure and changes nothing. An administrator's phone
  is the admin account's second factor and recovery: both steps answer `403
  ADMIN_PHONE_CHANGE_REFUSED`, and it changes with the admin provisioning only
  (RA-BE-19). The account signs in again with the new number and the same
  password, which also covers a lost SIM (sign in with the old number and the
  password, then change).
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
- Account deletion waits 30 days (D63; the immediate erasure route on
  `/api/v1/users/me` and the public deletion-status route are removed):
  - `GET /api/v1/users/me/deletion/impact` → `{ graceDays: 30, ownedPlans:
    [{ id, title, memberNames, upcomingBookings }], memberOfPlans, provider:
    { businessName, upcomingBookings } | null, blockedBy:
    "PROVIDER_HAS_UPCOMING_BOOKINGS" | null }`.
  - `POST /api/v1/users/me/deletion { confirmWord: "حذف" }` → `200 { status:
    "PENDING", requestedAt, scheduledFor }` (asking again answers the same
    request). `400 CONFIRM_WORD_MISMATCH`; `409 PROVIDER_HAS_UPCOMING_BOOKINGS
    { count, bookingIds }` (B-33). Members of owned plans get `PLAN_UPDATED`
    «خطة X متوقفة».
  - `GET /api/v1/users/me/deletion` → the same state, or `{ status: "NONE" }`;
    `DELETE /api/v1/users/me/deletion` takes it back (`409
    DELETION_NOT_PENDING` when nothing waits); members are told «رجعت».
  - While pending, every other application route answers `403
    ACCOUNT_DELETION_PENDING { scheduledFor }`; only `GET /api/v1/me`,
    `GET /api/v1/auth/me`, the two routes above, `POST /api/v1/auth/logout`
    and `DELETE /api/v1/push/installations/current` pass. The signed-in user
    carries `deletion: { requestedAt, scheduledFor } | null`. Owned plans are
    closed to members.
  - An hourly job erases due accounts through the one erasure saga (job only;
    an administrator's row keeps its admin identity as before). A failure
    (B-33 again, or any error) is recorded for n06 and retried next hour.
- `POST /api/v1/users/me/exports` → `201 { id, downloadPath, expiresAt }`
  (15 minutes, 5 a day: `429 EXPORT_RATE_LIMITED`), also while the account
  waits out its deletion (RA-BE-56), as `POST /api/v1/auth/logout-all` is; `GET
  /api/v1/data-exports/:token` (no session; the token is the credential)
  returns the account's own data as a JSON attachment once, then `404
  EXPORT_LINK_INVALID`.
- `GET`/`PATCH /api/v1/users/me/privacy` → `{ reviewFirstNameOnly }` (reviews
  show the first name only while on; default on).
- `GET /admin/data-requests` (`USERS_READ`) and `POST
  /admin/data-requests/:id/restore` (`USERS_WRITE`): n06.
- No route tells whether a phone number has an account (RA-BE-11): the old
  phone lookup was removed, since owning any plan was enough to ask it.
  Participants are invited by phone (D81). Adding a member directly adds
  nobody: by `phone` or by `userId` it is answered `400 ADD_BY_INVITE` before
  any lookup (RA-BE-20, RA-BE-42), and an invite names its account
  (`inviteeUserId`, `invitee`) only once accepted.
- `GET /api/v1/users/me/settings`
- `PATCH /api/v1/users/me/settings`
- `GET /api/v1/me`

OTP/profile routes are account and settings helpers. They do not add payment, booking, financing, AI, or chat behavior.

Account deletion waits 30 days (D63). `POST /api/v1/users/me/deletion` asks
for it, `GET /api/v1/users/me/deletion` reads the request and
`DELETE /api/v1/users/me/deletion` takes it back; asking twice returns the same
request. When the 30 days are up the purge job erases the account in one
transaction and stores only the SHA-256 digest of
`userId + NUL + "grace:" + deletionRequestedAt` in `AccountDeletionReceipt`, so
a second job instance finds the account gone and erases nothing twice. For an
ordinary account the User row is erased; for a dual
administrator/application identity the administrator row remains with all
application identity fields cleared. (The earlier immediate deletion keyed by
the client request id, with `DELETED`/`PENDING`/`NOT_STARTED`, is gone.)

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
The IP windows count a sender (RA-BE-55): an IPv6 address by its /64 network,
which one subscriber holds whole, and an IPv4 address written as IPv6
(`::ffff:a.b.c.d`) as that IPv4 address, so rotating addresses inside one
network does not spend the app's day of codes.
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
- `readerForm` (D59): `MASCULINE` or `FEMININE`, how the app speaks to this
  reader in this plan, resolved once by the server with the notifications'
  rule (`addressFormOf`: the account's persona, else the member's partner
  role `GROOM`/`BRIDE`, else the plan's side); `null` for provider contexts.
  The phone takes it as it is.
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

D112 (Q-21): the same holds for every answer a screen reads its buttons from:
`GET /api/v1/wedding-plans/:id/permissions/me`, the dashboard summary's
`permissions` and the money summary's `permissions` report `canManageTasks`,
`canManageGuests`, `canManageProviders`, `canManageMoney`, `canManagePlan`,
`canManageMembers` and `canRecordPrivateCost` as `false` for an archived
plan, to its owner too (they reported every right; the write then answered
`409 PLAN_ARCHIVED_READ_ONLY`). `canViewMoney`, `isOwner` and `role` are
unchanged: the owner reads the archived plan. Settling money already agreed
(G15) stays accepted by the writes themselves; no summary advertises it.

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
  "readerForm": "MASCULINE",
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
  "readerForm": "MASCULINE",
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
  "readerForm": null,
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

`permissions.canViewPlan` is the read right (D52): `true` for the owner and
every member of a plan context, whatever the role, because every member reads
the plan's tasks, guests by name and reply, and bookings
(`GET /api/v1/wedding-plans/:planId/plan-view`). The `canManage*` flags are
edit rights only; a client decides what a member sees by `canViewPlan` and
what they may change by the manage flags. Money stays behind `canViewMoney`.

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
- `PATCH /api/v1/wedding-plans/:id/archive`: the owner's alone (RA-BE-70).
  Archiving has no way back and revokes every live invite, so a member who
  may edit the plan gets `403 PLAN_ARCHIVE_OWNER_ONLY`
  («أرشفة الخطة لصاحبها بس.»), as the app offers it to the owner only.

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

`POST /api/v1/onboarding/complete` and `POST /api/v1/onboarding/import-local`
take an optional `mahr` (a06, B5): `{ total, settled?, remainingDueDate? }`
(amounts as money strings or numbers, the day as `YYYY-MM-DD`). It is
recorded in the new plan's money in the same transaction, exactly as
`POST /api/v1/wedding-plans/:planId/mahr` records it (below); a helper's plan answers
`409 MAHR_NOT_FOR_PLAN`. Completing onboarding for a helper's plan never
overwrites the account's known persona: an account that is a groom or a bride
stays so when it starts a plan for someone else, because the account's persona
is who the app speaks to (B5).

## WeddingPlan Dashboard Summary

Protected routes:

- `GET /api/v1/wedding-plans/:planId/dashboard-summary`

The old account home (`dashboard/home`) was removed (RA-BE-10): no client
read it.

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
- `venueSecured` (C24): `true` when the plan has a confirmed booking with a
  provider in the venue category (`wedding-halls`), or, for a caller who sees
  money, a non-cancelled cost in a venue budget category (قاعة، صالة). The
  home's «القاعة» step reads it; clients never work it out themselves.
- `bookedServices` (D60, the one «محجوز»): `{ count, budgetCategoryIds,
  quoteRequestIds }`. A service is booked when its provider `CONFIRMED` a
  booking (a past day included), or when its money item has a live cost with
  a named party and no provider or offer (booked outside اعّرست; the mahr is
  never one). A booked offer counts once under the money item its cost was
  filed in; one without an item (or whose cost is another account's private
  one) counts once by its request (`quoteRequestIds`). An accepted offer
  without a confirmed booking is never booked («اخترت X · اطلب الحجز»). A
  contributor reads his own requests; nobody reads another account's private
  costs; no amount is read. The home's «محجوز» tile and the providers board
  (f01) both read it (`plan-booked-services.ts`).
- `membershipId` and `membershipAuthorityVersion`: the same current
  contributor-membership identity returned by `/api/v1/contexts`, or `null`
  for an owner. Clients must not construct or guess these values.

Dashboard `remainingBudget` and the money-card usage ratio use confirmed cost:
the sum of non-cancelled WeddingCost totals of the wedding's items (C1).
D59: these figures and `moneySummary` (`confirmedCost`, `paid`, `outstanding`,
`remainingBudget`) are finance's one money read, the same as
`money-summary`'s `costs` and `budget.remaining`. The plan dashboard returns `paidByOwner` and
`paidByOthers` at the top level, beside the closed `moneySummary` shape (R12B
byte parity): of `paid`, what the owner's own money paid and what others paid
for the owner; `null` without money rights. CostPayment rows change the
paid/outstanding split and are not added to cost a second time. A pending
PaymentSchedule changes reminder state only; it does not deduct or reserve
outstanding money and cannot block a direct payment.

Payment-schedule details appear only when the current user has `canViewMoney`.
Notifications are always scoped to the authenticated
user. Provider cards are planning/reference data only and do not imply paid
booking, deposits, provider settlement/payment-processing status, loans,
credit, financing, or AI. This does not refer to the user's manual CostPayment
ledger.

## Plan Read View (D52)

Protected route:

- `GET /api/v1/wedding-plans/:planId/plan-view`

Reading is separate from editing. The owner and every member, in every role
(«يشوف بس» = `VIEWER` included), read the plan's non-money sections here;
the only rule is membership (`readsPlanSections` in the collaboration
permission port, enforced by `assertPlanReadable*`, the same rule the
contexts publish as `permissions.canViewPlan: true`). There is no stored read
flag because the rule has no exception. A non-member gets `404`, an
anonymous call `401`. Editing is unchanged: each write still needs the
section's manage flag and stays inside the editor's own work (contributor
scope); money still needs `canViewMoney`; phones stay with the members who
manage that section.

Response, every field listed by hand (nothing is spread from a row, so no
amount, budget, payment, funding source, task description, checklist, phone,
note, invitation link, offer or message can reach a reader through it):

```json
{
  "weddingPlanId": "…",
  "tasks": {
    "total": 20,
    "done": 12,
    "items": [
      {
        "id": "…",
        "title": "حدد موعد عقد القران",
        "status": "TODO",
        "dueDate": "2026-10-18T00:00:00.000Z",
        "assignee": { "kind": "OWNER", "firstName": "محمد" }
      }
    ]
  },
  "guests": {
    "total": 124,
    "confirmed": 86,
    "pending": 20,
    "declined": 18,
    "items": [{ "id": "…", "name": "عبدالله الحمدي", "attendanceStatus": "CONFIRMED" }]
  },
  "bookings": {
    "items": [
      {
        "id": "…",
        "businessName": "قاعة سبأ",
        "categoryName": "قاعات",
        "serviceTitle": "…",
        "status": "CONFIRMED",
        "eventDate": "2027-01-21T00:00:00.000Z"
      }
    ]
  }
}
```

- `tasks`: not cancelled, never another account's private task (V1
  checklist 4.10), in due order (undated last). `assignee.kind` is `YOU`
  (`firstName: null`), `OWNER`, `MEMBER` (first word of the name the app
  shows) or `PERSON` (the name the owner typed); `null` when nobody is named.
  No user id is returned.
- `guests`: every guest by name and reply (`attendanceStatus`), counted the
  same way; never a phone.
- `bookings`: the plan's live bookings (`REQUESTED` or `CONFIRMED`) by day,
  whoever made them; no amount or offer (q16).

The existing section lists (`GET /api/v1/wedding-plans/:weddingPlanId/tasks`,
`GET /api/v1/wedding-plans/:weddingPlanId/guests`,
`GET /api/v1/me/wedding-plans/:weddingPlanId/bookings` and the plan's quote
requests) keep their meaning: what the reader may work on.

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
A different `currency` is `409 FINANCE_CURRENCY_LOCKED` once the plan holds
money: any agreement (any state) or any funding source, whose amounts (the
bride's mahr and loans included) have no currency of their own and read in
the plan's (RA-BE-23; it counted agreements alone). The money summary carries
the same rule as `currencyLocked` for the owner (`null` for anyone else, as it
would tell them the owner's private funding exists); the app reads it and
falls back to counting agreements only before a server that sends it.
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

A payment made straight on the cost later can leave less than a pending
reminder's amount. Every schedule response therefore carries `amountDue`
(RA-BE-53): for a pending reminder the lesser of its `amount` and what the cost
still owes, else `"0"`; `amount` stays as the person wrote it. The money
summary's `paymentSchedules.next.amount`, the dashboard's next payment and due
items, and the payment reminders all name `amountDue`.

Paying accepts optional `paidAt`, `method`, and `note`, locks the schedule and
cost, and records `amountDue` (before RA-BE-53 a reminder above the remaining
was refused and could never be paid). A paid schedule is the record of its
payment, equal to it in the ledger, so a reminder paid for less takes the amount
paid. It creates one linked CostPayment and makes concurrent retries idempotent. Any
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
    "paid": "250000.00",
    "paidByOwner": "150000.00",
    "paidByOthers": "100000.00",
    "outstanding": "450000.00",
    "count": 3,
    "remaining": "800000.00"
  },
  "costs": {
    "total": "700000.00",
    "paid": "250000.00",
    "paidByOwner": "150000.00",
    "paidByOthers": "100000.00",
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
      "kind": "WEDDING",
      "allocatedAmount": "500000.00",
      "confirmedCost": "400000.00",
      "paid": "100000.00",
      "outstanding": "300000.00",
      "remainingAllocation": "100000.00",
      "costsCount": 1,
      "paymentSchedulesCount": 1,
      "overBudget": false,
      "providerCategoryIds": ["provider_category_id"]
    }
  ],
  "warnings": [],
  "permissions": {
    "canViewMoney": true,
    "canManageMoney": true
  },
  "mahr": {
    "side": "PAYS",
    "total": "3000000.00",
    "settled": "2000000.00",
    "remaining": "1000000.00",
    "nextDueAt": "2026-11-15T00:00:00.000Z",
    "complete": false
  },
  "payers": [
    {
      "payer": "GROOM",
      "payerName": null,
      "ownerMoney": true,
      "agreed": "3000000.00",
      "paid": "2000000.00",
      "outstanding": "1000000.00",
      "costsCount": 1
    }
  ]
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

**One money read (D59).** The summary is finance's one money read
(`readMoneyPicture`); the plan dashboard's `moneySummary` (and the home's),
and the planning assistant's money facts read the same picture through the
finance port, so no other figure adds the costs up again.

**Whose money paid (D59).** A payment carries no payer: it is the payer of its
agreement. The plan owner's own money paid an agreement whose payer is unset,
is the owner's own party (`GROOM` on a groom's plan, `BRIDE` on a bride's), or
is `SHARED` (the owner pays part of it, so it is counted as the owner's: «معك»
never shows money the owner may not have). Every other payer paid for the
owner. `paidByOwner` + `paidByOthers` = `paid`, in `costs` (every agreement)
and in `budget` (the wedding's items). `budget.outstanding` and `budget.count`
are the wedding's agreements not paid yet and how many there are. What was
agreed and what is left (`outstanding`) count every payment, whoever made it.

### The mahr (B5, D55)

- `POST /api/v1/wedding-plans/:planId/mahr` (`money-summary.recordMahr`)

a06 «اتفقتوا على المهر؟» for a plan that exists: `{ total, settled?,
remainingDueDate? }`. Only the plan owner records it (a member, even with
money rights, gets `404`), once while it is recorded (`409
MAHR_ALREADY_RECORDED`, then it is edited through the ordinary cost, payment,
schedule or funding routes). D59: the groom's mahr is recorded while the MAHR
item holds a non-cancelled agreement, the bride's while a MAHR source exists;
once the agreement (or every source) is deleted it can be recorded again, in
the same MAHR item. The
side follows the plan's persona: a groom's plan **pays** it, a bride's plan
**receives** it, a helper's plan has none (`409 MAHR_NOT_FOR_PLAN`). `total`
must be above zero and `settled` within it (`400`). The answer is the money
summary built in the same transaction.

- **Groom (PAYS):** a budget item `kind: "MAHR"` named «المهر», outside the
  wedding budget (it never holds an allocation: `PATCH` with an allocation is
  `400 MAHR_OUTSIDE_BUDGET`, and the database refuses it too), with one
  agreement «المهر» with «أهل العروسة» (`payer: GROOM`), the handed-over part
  as a payment and the rest as a payment schedule on its day. An item the
  plan already named «المهر» becomes that item with the agreements already in
  it (its allocation dropped; D59, no longer refused); when it holds a live
  agreement, that agreement is the mahr and no second one is added (RA-BE-18:
  3,000,000 read 6,000,000); its amount changes through the money. A budget
  replacement (`PUT /api/v1/wedding-plans/:planId/money-budget`) never
  touches the mahr item. An agreement never moves between a wedding item and
  the MAHR item: `PATCH /api/v1/costs/:id` with such a `budgetCategoryId` is
  `409` (D59).
- **Bride (RECEIVES):** funding sources `kind: "MAHR"`: «المهر من العريس»
  `RECEIVED` and «باقي المهر» `PLEDGED` with `expectedAt` (the rest's day).
  Funding stays the owner's private picture (below). D59: only a bride's plan
  creates `MAHR` funding (`400` elsewhere), and a source never changes to or
  from `MAHR` (`409`).

The summary's `mahr` (null before it is recorded, and for a reader who may
not see it: the bride's mahr is funding, owner only) reads both sides in one
shape: `side`, `total`, `settled` (handed over or received), `remaining`,
`nextDueAt` (the earliest pending schedule for the groom, the earliest
expected day for the bride; null once nothing is left) and `complete`.

The mahr is money of the plan but not of the wedding budget: `costs.*` and
`categories` include the mahr agreement; `budget.confirmedCost`,
`budget.paid` and `budget.remaining` (and the `BUDGET_EXCEEDED` warning, and
the dashboard's `remainingBudget`) count only items of `kind: "WEDDING"`.
`budget.paid` is what was paid of those (c01 «عرسك · دفعت»).

### Who paid what (G14)

`payers` groups the plan's non-cancelled agreements by their `payer` and the
trimmed `payerName` («الوالد» and «خالي أحمد» are two groups of `FAMILY`), in
the order GROOM, BRIDE, FAMILY, SHARED, OTHER, unset: `agreed`, `paid` (the
net payments), `outstanding`, `costsCount`, and `ownerMoney` (D59: whether
the group's payments came out of the plan owner's own money). A payment
carries no payer of its own; it counts under its agreement's payer. It is
part of the money summary, so it follows `canViewMoney`.

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
nuqut, `LOAN`, `MAHR` — the bride's mahr from the groom, `OTHER`),
`sourceName`, optional `sourcePhone`, positive `amount`, and `status`
`PLEDGED` (promised) or `RECEIVED` (default; then `receivedAt` defaults to
now). A source may carry `expectedAt` (an ISO date, the day pledged money is
expected; c05 «يوصلك يوم العقد 15 نوفمبر»; `null` clears it); responses
return it (null when unset) and `isOverdue` (D59: `PLEDGED` and its
`expectedAt` before today, Sana'a time; c05 «متأخر»). Responses include the
ordered `repayments` and, for a loan, `repaidAmount` and `outstandingAmount`.

Only a `LOAN` takes repayments (`amount`, optional `dueDate`). Planned and
paid repayments together never exceed the loan amount (`400`). `PATCH`
`status: PAID` records the repayment (`paidAt` defaults to now); a paid
repayment is reopened with `status: PLANNED` before it can be edited or
cancelled (`409`). A loan with repayments cannot change kind (`409`) or drop
below its scheduled repayments (`400`).

Privacy: funding is the plan owner's private money picture. A member, even
with money rights, gets an empty list from `GET` and `404` from every write.
The owner's `money-summary` adds `funding` (`total`, `received`, `pledged`,
`spent` = what the owner's own money paid (`costs.paidByOwner`, c05 «صرفت»),
`availableCash` = received − spent, never below 0 («معك»: a payment someone
else made for the owner never leaves the owner's hands, D59; an owner who
paid more than he recorded as received holds nothing, RA-BE-17),
`shortfall` = what is left to pay less what is in hand less what is promised
(the same, while he holds money, as every agreement less what others paid
for the owner less every source; null once covered; paid + in hand +
promised + shortfall make up every agreement), loan totals,
`overdueLoanRepayments`, `overduePledges` (promises past their day),
`nextLoanRepayment`) and
the warnings `FUNDING_SHORTFALL` and `LOAN_REPAYMENT_OVERDUE`; a member's
summary has `funding: null`. Account erasure deletes the plan's funding
sources and, by cascade, their repayments.

G40 (D57): every `categories[]` row carries `providerCategoryIds`, the active
directory categories whose accepted offers are filed under that item, by the
rule acceptance uses (`budgetItemForProviderCategory`: the category's topic
item among the plan's items in their own order, else the plan's «أخرى»),
limited to the categories the plan's persona sees in the directory
(`showForGroom` / `showForBride`; a plan without one sees both). It is read
over the whole plan's items, so a contributor's rows say the same as the
owner's. An empty list means no provider's offer lands there: the phone shows
no «ابحث» for it. The phone searches the directory with
`GET /api/v1/providers?categoryIds=<the list>`.

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
- `POST /api/v1/wedding-plans/:weddingPlanId/tasks/shift-due-dates` `{ days }`
  (V1 checklist 4.13, the plan's owner or partner, who see every task,
  `-730..730`, not `0`): the wedding
  moved, so the plan's `TODO`/`IN_PROGRESS` tasks with a due date move by
  `days` (due date and reminder together, one statement); done, cancelled
  and undated tasks keep theirs. Returns `{ shifted }`. The app offers it
  right after the owner changes the wedding date; payment schedules and
  bookings never move on their own. The move is relative, so the app sends
  one `X-Client-Request-Id` for every try of one move, and a retry after a
  lost answer is answered with the first answer (RA-BE-71).

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
seed the boolean only when an invitation is created (members join only by
accepting one, RA-BE-42). The role is not a runtime permission fallback and changing it does not
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

The other sections answer a current member the same way (RA-BE-40): a write
refused in guests, money, providers, member management, or plan editing
returns HTTP `403`, code `SECTION_PERMISSION_MISSING`, message
«ما عندك صلاحية تعدّل في هذا القسم. صاحب الخطة يقدر يفتحها لك.». Someone
outside the plan still receives the plan-not-found `404`, and reads keep
their own rules (a member without `canViewMoney` reading money gets `404`).

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

## Planning Assistant

V1 checklist 4.12. Protected routes:

- `GET /api/v1/wedding-plans/:weddingPlanId/assistant` returns
  `{ enabled, allowed, dailyLimit, remainingToday }`. `enabled` is false until
  the server has `ANTHROPIC_API_KEY` and a priced `AARAST_ASSISTANT_MODEL`;
  `allowed` is true only for the plan's owner and partner (V1 checklist 4.10).
- `POST /api/v1/wedding-plans/:weddingPlanId/assistant/questions` with
  `{ kind, question?, consent }` returns `200 { kind, answer, declined,
  marketDataAvailable, remainingToday }`. `kind` is one of `PLAN`,
  `BUDGET_SPLIT`, `COMPARE_QUOTES`, `CHEAPER`, `FORGOTTEN`, `NEGOTIATION`,
  `QUESTION` (`question`, at most 500 characters, is required for `QUESTION`).

The server sends the model the plan as the asker sees it: plan basics, guest
and task counts, open task titles, budget categories with allocated,
committed and paid sums only with money permission (never another account's
private costs or tasks), received quote offers only with provider
permission, and market price ranges (three or more providers) in the plan's
own city only. Names, phone numbers and notes of guests and contacts are not
sent. The rules forbid inventing prices and treat the plan data as data, not
instructions. Nothing asked or answered is stored; only counts and cost.

Refusals: `400 ASSISTANT_CONSENT_REQUIRED` (`consent` is not `true`),
`403 ASSISTANT_OWNER_OR_PARTNER_ONLY`, `429 ASSISTANT_DAILY_LIMIT`
(`AARAST_ASSISTANT_DAILY_LIMIT`, default 10 a day), `503 ASSISTANT_DISABLED`,
`503 ASSISTANT_BUDGET_EXHAUSTED` (the month's cost reached
`AARAST_ASSISTANT_MONTHLY_BUDGET_USD`, default 30), `503 ASSISTANT_BUSY` and
`503 ASSISTANT_UNAVAILABLE` (the model failed; the question is given back).
A safety decline returns `declined: true` with an Arabic explanation.

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

The permission booleans persisted on `SharedMember` and the permission snapshot
persisted on `PlanInvite` are authoritative. `rolePermissionDefaults()` is used
only when a new invitation is created. `POST /api/v1/wedding-plans/:weddingPlanId/members`
adds nobody (RA-BE-20, RA-BE-42): whoever joins a plan accepts an invite (P5),
so after the member-management check every request, by `userId` or `phone`,
returns HTTP `400`, code `ADD_BY_INVITE`, before any lookup. Member
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
have `User.status = ACTIVE` and must not be waiting out an account deletion
(D63, RA-BE-37). Otherwise acceptance returns HTTP `409`, code
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

`GET /api/v1/invites/mine` lists the invitations tied to the caller's account,
and by phone number only the invitations tied to no account (RA-BE-35). An
invitation tied to an account stays with that account after it changes its
number; whoever holds the old number next does not see it.

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

Invite messages leave from the number that sends the sign-in codes, so they
have daily budgets of their own (RA-BE-34), apart from the codes' budget: one
phone number receives at most 3 a day, the app sends at most 300 a day, and one
sender or one plan sends at most 20 a day (create and reissue alike). Past a
budget nothing is sent and `delivery.status` is `UNAVAILABLE`; the invite and
its link stand, for the inviter to copy.

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
permission in that comparison, with one exception: the partner roles `GROOM`
and `BRIDE` read the whole plan in every section their flags open, where other
members read their own work, so only the owner or a member holding a partner
role may give one (RA-BE-36). Anyone else gets HTTP `400`
`Cannot grant permission above inviter ceiling: partnerRole`.
An invitation cannot target the inviter, the owner, a current member, or a
person who already has a pending invitation. A former member, including one
whose tenure ended with `MEMBER_LEFT`, returns only through a new explicit
invitation and acceptance.

Invitation creation/cancellation/reissue, member update, and
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
contributor's entities. Guest and group lists are the D80 exception described
under Guests: every name is listed, while phones, notes and edits keep this
scope.

The one exception is the plan's partner (V1 checklist 4.10): a member whose
role is `GROOM` or `BRIDE` reads and manages the whole plan like its owner in
every section their current permissions open — every cost, category, payment,
schedule, task, guest, quote request and booking, the whole-plan money summary
and dashboard figures, and the plan's task and payment notifications and
reminders. The owner's funding sources and loans (V1 checklist 4.3), the
plan's currency and budget replacement, and member management stay the
owner's. Other roles keep the contribution-scoped view described above.

Private costs (V1 checklist 4.10): the owner or a partner may create a cost
with `isPrivate: true` (others get `403 COST_PRIVACY_NOT_ALLOWED`). Only that
account sees it: every money read (cost list and detail, payments,
schedules, budget-category counts, the money summary, the dashboard and home
figures, the timeline) narrows its cost scope without the costs private to
someone else, and reading or changing one by id is `404`. Responses carry
`isPrivate`. `PATCH /api/v1/costs/:id` with `isPrivate: false` shares it with
the plan; a shared cost never becomes private (`400
COST_PRIVACY_AT_CREATION_ONLY`). Its payment reminders go only to its
account, it never feeds the plan-wide over-budget alert, and it writes no
contribution-history event. The money summary's `permissions` gain
`canRecordPrivateCost`.

Private tasks follow the same rule: `POST
/api/v1/wedding-plans/:weddingPlanId/tasks` takes `isPrivate: true` from the
owner or a partner (others get `403 TASK_PRIVACY_NOT_ALLOWED`). Only that
account sees the task in the list, detail, summary, plan dashboard, home and
timeline; reading, changing, assigning or editing its checklist by id is
`404` for anyone else. Responses carry `isPrivate`. `PATCH
/api/v1/tasks/:id` with `isPrivate: false` shares it; a shared task never
becomes private (`400 TASK_PRIVACY_AT_CREATION_ONLY`). A private task is
assigned only to its own account (`400 TASK_PRIVATE_ASSIGNMENT`), reminds
only that account, and writes no contribution-history event. Moving the
plan's task dates moves private tasks too, but `shifted` counts only the
tasks the caller sees. `GET .../tasks/summary` gains `canKeepPrivateTask`.
Deleting an account deletes its private costs (with their payments,
schedules and receipts) and private tasks in other plans.

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

The contribution summary (a distinct contributed-entity count for every
section, scoped like the list) has no route of its own since RA-BE-10: the
plan's dashboard reads it through the service. The history route requires
either plan ownership or a current membership. A
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
- `GET /api/v1/wedding-plans/:weddingPlanId/guests/invitation-card`
- `PUT /api/v1/wedding-plans/:weddingPlanId/guests/invitation-card`
- `GET /api/v1/wedding-plans/:weddingPlanId/guest-groups`
- `POST /api/v1/wedding-plans/:weddingPlanId/guest-groups`
- `GET /api/v1/guests/:id`
- `PATCH /api/v1/guests/:id`
- `DELETE /api/v1/guests/:id`
- `PATCH /api/v1/guest-groups/:id`
- `DELETE /api/v1/guest-groups/:id`

### Events beyond the wedding (D83)

Every guest is invited to the wedding by being a guest; their reply to it is
the guest row's `attendanceStatus` and `companionsCount`. The plan's other
events (the lunch, the aqd, the samra...; `PlanEvent` rows whose type is not
`WEDDING`) are chosen per guest:

- `POST .../guests`, `POST .../guests/bulk` items and `PATCH /api/v1/guests/:id`
  take `eventIds?: string[]` (at most 20, ids of the plan's events other than
  the wedding row). On create, absent means none. On update, absent keeps the
  guest's events; a list replaces them, and the replies to events that stay
  are kept. An id that is not one of the plan's events, or the wedding row,
  answers `400 GUEST_EVENT_UNKNOWN` and nothing is saved.
- Every guest response carries `events: [{ planEventId, attendanceStatus,
  companionsCount, respondedAt }]`, one per event the guest is invited to.
- The summary carries `byEvent: [{ planEventId, label, invited, confirmed,
  declined, pending, companions }]` in the plan's event order, only for events
  with at least one invited guest. `label` is the event's title or its type's
  Arabic name.

### The invitation card (D83)

One card per plan, kept in the account. Every member reads it (RA-BE-86: a
read of the plan like its guest list, so an archived plan's card still
opens); whoever manages the plan's guests (the owner, a partner with the
guests right, a helper with it) writes it:

- `GET .../guests/invitation-card` returns `{ weddingPlanId, hostLine,
  freeText, photoUrl, mapUrl, address, updatedAt }`; every field is `null`
  (and `updatedAt` null) before the first write.
- `PUT .../guests/invitation-card` takes any of `hostLine` (≤80), `freeText`
  (≤300), `photoUrl`, `mapUrl` (≤500, HTTPS, else `400
  INVITATION_CARD_MAP_URL_INVALID`), `address` (≤160). A missing field keeps
  its stored value; `null` or blank clears it. `photoUrl` must be the writer's
  own verified public upload with purpose `guest-invitation-card`; the card
  consumes it, and a replaced or cleared photo is released for deletion.
  Returns the same shape as `GET`.

The names, the date, the time and the venue are the plan's and are not
stored on the card.

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
  "updatedAt": "2026-06-18T00:00:00.000Z",
  "editable": true
}
```

D80 (a refinement of D52): a contributor with `canManageGuests` lists every
guest and every group of the plan, with the guest summary counted over the
whole plan. `phone` and `notes` (a group's `notes`) are returned only for the
guests and groups that contributor added and are `null` for the rest; each row
carries `editable`, true for the owner (and a whole-plan partner with the
guests right) and for the contributor's own rows, false otherwise. A guest or
group outside that scope still answers `404` to `GET /api/v1/guests/:id`, update,
delete and invitation links. A contributor without `canManageGuests` gets `[]`
here and reads the names through the plan read view.

D99 (RA-BE-62): a plan holds at most 5000 guests (`PLAN_GUESTS_MAX`). `GET
.../guests` without `take` returns the whole list, newest first (`createdAt`,
then `id`, both descending, so pages never skip or repeat a guest); `take`
(≤200) and `skip` still page it. An add that would pass the limit (`POST
.../guests`, or a `bulk` list, refused whole) answers `422 PLAN_GUESTS_LIMIT`
with an Arabic message that says how many the plan has; it is counted after
the plan's lock in the `SERIALIZABLE` transaction that adds, so two adds at
once cannot both pass it. It is a 422, not a 409, because an older phone
reads any 409 on a guest save as «مضاف مسبقًا».

RA-BE-82: the guests' refusals say what happened in Arabic, with a code: a
group name the plan already has `409 DUPLICATE_VALUE`, a guest or group name
of only spaces `400 GUEST_NAME_REQUIRED` / `400 GUEST_GROUP_NAME_REQUIRED`, a
`groupId` that is not one of the plan's groups `400 GUEST_GROUP_NOT_IN_PLAN`.

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

`GET /api/v1/providers` filters by `cityId`, `search`, `featured`, and one
category (`categoryId`) or several (`categoryIds`, comma-separated, at most
50; G40): a provider is listed when its own category or an active service's
is among them. Sending both is `400`; a value that is not a UUID is `400`.

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

D112 (Q-7): a quote request of a wedding plan carries its money (`budgetMin`,
`budgetMax`, each offer's amounts and `costSuggestion`) only for a reader who
reads that plan's money: its owner, or a member with `canViewMoney`. This
holds for the requester too, in `/api/v1/me/quote-requests`, its `:id` and `cancel`,
and in the plan's quote list and detail, as in the request's conversation
(D52). A plan-less request is its requester's own and stays whole.

Every review response uses a privacy-safe reviewer identity containing only
`id` and `name`. Reviewer phone and email are never returned by public review,
review create/update, provider-dashboard review, or admin-review responses.
Review create, update, delete, publish, and hide operations lock the provider
row and update `ratingAverage`/`ratingCount` from the published review rows in
the same serializable transaction. Account deletion explicitly removes the
user's reviews and refreshes every surviving provider under the same ordered
locks; a successful response therefore cannot leave the public aggregate
behind the review data.

A review the moderation team hid is not deleted by its author:
`DELETE /api/v1/reviews/:id` returns HTTP `409`, code `REVIEW_HIDDEN`
(RA-BE-45). Deleting it let the author write another, published at once, so
what was hidden came back unmoderated; a hidden review shows to nobody.

Provider service `basePrice`, package `price`, and quote-offer `amount` use the
same money boundary as the planning ledger: a present value must be
non-negative, contain at most 12 integer digits and 2 decimal places, and fit
PostgreSQL `numeric(14,2)`. Null or blank optional prices clear/omit the value.

D112 (Q-25): every amount a request carries is whole (agreements, payments,
payment dates, budgets, funding, the mahr, a plan's estimated budget, a
provider's prices, an offer's amounts). `5000`, `5000.0` and `5000.00` are
accepted; a fraction answers `400 { statusCode, code: "MONEY_AMOUNT_NOT_WHOLE",
message: "المبلغ رقم صحيح، بدون كسور.", field }`. Columns stay `numeric(14,2)`:
a row saved with a fraction earlier is still read and summed as it is.
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

Offer versions, withdrawal, the answer window and privacy (B-03, B-04, B-06,
B-08, B-14, G19; D50):

- **One currency per plan (G19).** An offer in another currency than the
  plan's is `400 QUOTE_OFFER_CURRENCY_MISMATCH` with `planCurrency` and an
  Arabic message for whoever reads it (the provider sending, the customer
  accepting).
- **Versions (B-06, D41).** Every offer response (provider dashboard, the
  customer's quote reads, accept/reject and the conversation's latest quote)
  carries `versionNo`, `changes: [{ field, from, to }]` against the version
  before (`field` ∈ `amount`, `currency`, `title`, `message`, `validUntil`;
  `[]` on version 1; without `amount`/`currency` for a viewer with no money
  access), `revisedAt`, `withdrawnAt` and `withdrawnReason`. Sending an offer
  stores it as version 1. `PATCH /api/v1/provider/me/quote-offers/:id` that
  changes something writes version N+1 (one `QuoteOfferVersion` row), records
  one `QUOTE_OFFER_REVISED` conversation event whose data is only
  `{ versionNo }` (D53: every plan reader with the providers right reads the
  timeline's events as stored, so no event carries an amount or the
  changes; «ايش تغيّر» is read from the offer, money-aware) and notifies the
  customer («عدّل … عرضه», no amount; push «عدّلوا عرضهم»), at most once per
  offer per ten minutes (`QuoteOffer.revisionNoticeAt`): a revision inside
  that window is recorded on the timeline but not notified. An edit
  that changes nothing returns the offer unchanged. Renewing an expired offer
  is an edit like any other. Editing an offer that is not `PENDING` on a
  `RESPONDED` request is `409 QUOTE_OFFER_LOCKED`.
- **Accepting a version.** `PATCH /api/v1/quote-offers/:id/accept` takes an
  optional `{ versionNo }`; the app always sends the version it showed. A
  version that is no longer current is `409 QUOTE_OFFER_CHANGED` with
  `currentVersionNo` and writes nothing. A withdrawn offer is
  `409 QUOTE_OFFER_WITHDRAWN`. The cost created from the accepted offer takes
  the accepted version's amount, filed under the plan item of the service's
  category, else the provider's own category (G38), else «أخرى».
- **Withdrawal (B-03).** `POST /api/v1/provider/me/quote-offers/:id/withdraw`
  (`200`) with `{ reason?: string ≤ 500 }` takes back a `PENDING` offer on a
  `RESPONDED` request: the offer becomes `WITHDRAWN` (`withdrawnAt`,
  `withdrawnReason`), the request goes back to `VIEWED` with a new seven-day
  answer window, one `QUOTE_OFFER_WITHDRAWN` event and one customer notice
  («سحب … عرضه»). It returns the provider's quote. An accepted, rejected or
  otherwise decided offer is `409 QUOTE_OFFER_NOT_WITHDRAWABLE`; repeating a
  done withdrawal returns the quote unchanged. A withdrawn offer leaves room
  for one new offer on the same request.
- **Answer window (B-04).** Every request carries `expiresAt` (seven days
  after it was sent, or after a withdrawn offer) and `expiredAt`. While it is
  `SENT` or `VIEWED`, the provider answers (offer or apology) before
  `expiresAt`; after it, the answer is `409 QUOTE_REQUEST_EXPIRED`. An hourly
  job warns the provider once per window during the last day
  (`QUOTE_REQUEST_EXPIRING`, «طلب … ينتهي بكرة», whose route target is the
  app's own request page, D39), then moves the request to `EXPIRED`
  (`lifecycleStatus: "EXPIRED"`), records `QUOTE_REQUEST_EXPIRED` and tells
  the customer «ما رد … خلال 7 أيام» with «اطلب من غيره», unless the job
  reaches the request more than a day after its deadline (the first run
  after B-04 shipped, or the job was down): then the request ends and the
  event is recorded without that notice (D53). Each request moves
  in its own serializable transaction from the state it was read in, so a
  second instance of the job or a retry changes nothing twice; a run lists
  each due request once (cursor on `expiresAt`, `id`) and counts the ones it
  leaves as they were as skipped. An expired
  request does not block asking the same provider again; nor does one past
  its deadline that the job has not reached yet. The plan quote counters
  count `EXPIRED` as closed.
- **Privacy (B-08).** Both request creation routes take `shareBudget` and
  `shareContact` (default `false`; earlier requests share nothing). The
  provider's quote reads return `budgetMin`/`budgetMax` only with
  `shareBudget`, and `contactPhone`, `contactNormalizedPhone` and
  `user.phone` only with `shareContact`; both flags are in the response. The
  conversation's latest quote follows the same rule on the provider side.
- **Who the provider talks to (B-14, D53).** In a plan's conversation the
  provider side's `counterpart` is `{ firstName, weddingLabel, eventDate }`:
  the requester's first name and the request's day, with no phone and no
  picture. `weddingLabel` is always `null` and the conversation's
  `weddingPlan.title` is `null` on the provider side, as his request reads'
  `weddingPlan.title` are: D75 keeps the plan's title («عرس سلمى») for the
  people she chose (RA-BE-80); the fields stay for older phones (D93). An
  offer in a conversation carries the same version fields and `lines` as
  every offer response (`quoteOfferVersionView`): an extra's price only for
  a reader who sees the money (RA-BE-73). Wherever else the provider side reads a customer-side
  person (the conversation's `latestQuoteRequest.user`, an account-scoped
  conversation's `counterpart`, a message `sender`), it is
  `{ id, name, avatarUrl: null }`: the full name as p16 and p19 draw it
  («محمد الحمدي»), drawn with its initial, never the picture; the phone only
  as B-08 allows. Messages reach both sides in one realtime room, so a
  message carries a picture only for the provider's own account.
- **Response speed.** The provider's median first answer counts the first
  offer that was not withdrawn; a request whose only offer was withdrawn is
  unanswered (D53).

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
an allocation. The money summary lists the same placement per item
(`providerCategoryIds`, G40), from the same function and the same item order. Acceptance first takes `WeddingPlan FOR SHARE` and re-reads its
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

Every quote response's `costSuggestion` also carries `category` (the name)
and `categoryId` (G40): the category acceptance files the offer by, the
service's, else the provider's own. The phone places a request on the money
item whose `providerCategoryIds` hold it.

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
- `POST /api/v1/provider/me/quote-offers/:id/withdraw`
- `GET /api/v1/provider/me/reviews` (each review with `reply: { body,
  repliedAt, status } | null`, B-09)
- `POST /api/v1/provider/me/reviews/:id/reply` `{ body }` (1 to 1000
  characters; B-09, p27): his one reply to a published review of his. A
  second reply, or two at once, is `409 REVIEW_ALREADY_REPLIED`; a review
  that is not his or is hidden is `404`. The reviewer is told
  (`REVIEW_REPLIED`, opening the provider's page in the app). The public
  `GET /api/v1/providers/:id/reviews` returns `reply: { body, repliedAt }`
  once published, else `null`; a reviewer's `PATCH /api/v1/reviews/:id` on
  a replied review is `409 REVIEW_HAS_REPLY` (it may still be deleted). A
  new review tells the provider (`REVIEW_RECEIVED`, «تقييم جديد · 4 نجوم من
  …», opening p27 in the app).

Text bounds (RA-BE-15, RA-BE-16): every text field a request stores has a
bound, counted as the phone counts it (a character as the reader sees it,
`MaxCharacters` in `shared-kernel/text/text-length.ts`; a mark or a joined
emoji is not counted extra). A service's, a package's or an offer's title and
a business name take 160; a description, a provider's about and an offer's
message 2000; a price note 120; an address and an image's description 300; a
review's comment and a quote request's message 1000; a profile name 120. A
package's `items` is a list of up to 50 strings of up to 200 characters; any
other JSON is `400`. Longer text is `400`; the phone stops each field at the
same count first, so a queued change is never refused for its length.
One account sends at most 30 chat messages a minute, in all its
conversations (`429 MESSAGE_RATE_LIMITED` with `retryAfterSeconds`,
RA-BE-81); the phone keeps such a message waiting and sends it with the
same request id. A plan whose owner waits out the account's deletion (D63)
is closed in chat to everyone else: its conversations are not listed, and
reading or sending answers `404` (RA-BE-76); nobody waiting is told of a
message.
A chat message takes 2000 the same way (`400 MESSAGE_LENGTH`), a
conversation report's reason 500 (`400 REPORT_REASON_LENGTH`), and an
event's name and responsible 60, its place and note 120.
`test/dto-text-bounds.test.ts` fails on a new text field without a bound,
in any file that declares a request form.

Notifications (B-19, B-38): every notice carries `routeTarget`, the phone
route of its own screen, written once in
`backend/src/shared-kernel/routes/notification-routes.ts` (the table of
every type's route shapes, tested against the phone's router). Notice words
never carry an amount or a numeric date: a money reminder sends its owner
`data.amount` and `data.currency` for the phone to write (and hide under
«أخفِ المبالغ»); days read «الجمعة 30 أكتوبر». Provider notices about his
account have their own types (`PROVIDER_APPROVED`, `PROVIDER_NEEDS_CHANGES`,
`PROVIDER_REJECTED`, `PROVIDER_SUSPENDED`, `PROVIDER_IN_REVIEW`,
`PROVIDER_CLAIM_DECIDED`, `LISTING_PLAN_CHANGED`); a booking request is
`BOOKING_REQUESTED`, and every booking notice names its step in
`data.bookingEvent`.

Listings the back office made before the provider had an account (V1
checklist 4.18):

- `POST /admin/providers` (`PROVIDERS_WRITE`) creates an `ACTIVE` provider with
  no account from `{ businessName, phone, whatsapp?, cityId, categoryId,
  address?, description? }`. The phone is normalized; a phone any provider
  already uses (in any of its spellings) is `409 PROVIDER_PHONE_TAKEN`. The
  listing shows in the directory once it has an active service
  (`POST /admin/services`).
- `GET /api/v1/provider/claimable` returns `{ listing: { id, businessName,
  city: { id, nameAr }, primaryCategory: { id, nameAr } | null } }` (p02's
  «تصوير · صنعاء») when an active, unclaimed listing carries the caller's
  phone and the caller owns no provider; otherwise `{ listing: null }`. Every
  session's phone is verified by OTP, which is the proof of ownership.
- `POST /api/v1/provider/claim/:providerId` (B-12, D41) asks the review team
  for that listing after the same phone check and returns the claim
  `{ id, status: "PENDING", note, createdAt, decidedAt, provider: { id,
  businessName } }` (`201`). The listing stays unclaimed (and keeps refusing
  quote requests) until an administrator approves. A listing that is not the
  caller's to claim is `404`; a caller who already owns a provider is `409`;
  an open claim of this listing or by this account is
  `409 PROVIDER_CLAIM_PENDING`. One `PENDING` claim per listing and per
  account is enforced by partial unique indexes.
- `GET /api/v1/provider/me/claim` returns `{ claim }`, the caller's latest
  claim (`PENDING`, `APPROVED`, or `REJECTED` with the team's `note`), or
  `{ claim: null }`.
- Administrators review claims (`PROVIDERS_READ` / `PROVIDERS_WRITE`):
  `GET /admin/provider-claims?status&page&limit` (oldest first, with the
  listing, its city and category, and the claimant's name and phone),
  `POST /admin/provider-claims/:id/approve` (links the listing to the
  claimant, promotes the account, notifies «انقبل استلامك للملف»; `409
  PROVIDER_CLAIM_LISTING_TAKEN`, `PROVIDER_CLAIM_ACCOUNT_INACTIVE`,
  `PROVIDER_CLAIM_ACCOUNT_HAS_PROVIDER` or `PROVIDER_CLAIM_PHONE_CHANGED`
  when the claim can no longer be honoured; the last when the claimant's
  phone, re-read under the account's lock, no longer matches the listing's
  phone in any of its spellings, the same match the claim was sent with) and
  `POST /admin/provider-claims/:id/reject` with `{ note }`
  (required; the claimant is notified «ما قبلنا الاستلام» with it). A claim
  already decided is `409 PROVIDER_CLAIM_NOT_PENDING`. Account deletion
  removes the account's claims. There is no claim token, link or WhatsApp
  message (D41).
- `POST /api/v1/provider/apply` is `409 PROVIDER_LISTING_CLAIMABLE` while such a
  listing waits under the caller's phone. A refused claim leaves the listing
  offered to the same account, which may claim it again once it has fixed
  what the team named (the reason shows on p02); a listing that is not its
  own goes through support (B-13).

Featured placement (B-43, D41, D51, D54): the provider pays the owner outside the
app; an administrator records the days. No amount, payment or payment status
is taken or kept anywhere.

- **The placement rule (one, D54):** a placement shows only on a provider
  listed to customers (`ACTIVE` with at least one active service, the same
  rule as the customers' list) whose owner claimed the listing. The grant,
  a17's state and counts, the provider's notices, the ranking, the home
  counter and the admin report all read it (`featuredShowsWhere`).
- A provider is featured while that rule holds and one of its
  `ProviderFeaturedPeriod` rows covers the moment of the request
  (`startsAt <= now < endsAt`, not ended early). It is read at request time,
  so a placement lapses at its end by itself.
- `GET /api/v1/providers` lists the providers featured now first, then the
  others, each group by rating, age and id (a total order; the page is cut
  across both groups in one snapshot). `isFeatured` on every provider
  response (list, page, favorites) is that placement and `featuredUntil` its
  end (`null` when not featured): a phone showing a saved copy drops «مميز»
  once `featuredUntil` passed. `featured=true|false` filters by it. The
  customer card labels it «مميز»; a tap explains it is paid, not a
  recommendation.
- A service has no featured flag of its own (`ProviderService.isFeatured` and
  the admin «تمييز» are gone, D54): a provider's services read newest first
  (then id), the services search cheapest first, then newest, then id;
  `status=FEATURED` on `GET /admin/services` is `400`, and an `isFeatured`
  field in a service write is `400` (not whitelisted).
- `GET /api/v1/provider/me/profile` returns `featured: { startsAt, endsAt,
  active } | null`: the placement covering now (`active: true`) or the next
  one booked (`active: false`); `endsAt` is where its run of back-to-back
  renewals ends (a renewal booked from the day after the current one carries
  it on). `endsAt` is the start of the day after the last day covered
  (Sana'a, UTC+3). The profile has no `isFeatured`.
- `GET /admin/bookings?providerId&status&from&to&page&limit` and
  `GET /admin/bookings/:id` (`PROVIDERS_READ`; a12, B-40) — read only,
  newest day first: `{ id, eventDate, status, lifecycleStatus, provider: {
  id, businessName, status }, customer: { userId, name, weddingPlanId },
  quoteRequestId, guestCount, cancelledBy, note, requestedAt, confirmedAt,
  declinedAt, cancelledAt, expiredAt, updatedAt }`. `from`/`to` are days
  (`YYYY-MM-DD`, inclusive); a bad status or day is `400`, an unknown id
  `404`. No amount, offer or payment; the «ما صار» reports (B-22) are not
  built.
- `GET /api/v1/provider/me/profile` also returns `dailyBookingCapacity` (B-20).
- `GET /admin/featured-periods?state&providerId&page&limit`
  (`PROVIDERS_READ`): `state` is `CURRENT` (default: active or booked),
  `ACTIVE`, `SCHEDULED`, `FINISHED` or `ALL`; latest start first, then
  creation and id. Each item: `{ id, state: ACTIVE|SCHEDULED|EXPIRED|ENDED,
  providerShown, startsAt, endsAt, startsOn, lastDay, note, createdAt,
  grantedBy: { id, name } | null, endedAt, endedBy, endNote, startNoticeAt,
  endingNoticeAt, endNoticeAt, provider }` (`startsOn` and `lastDay` are
  Sana'a `YYYY-MM-DD` days; `providerShown` is the placement rule for its
  provider now: a running placement without it ranks and badges nothing, and
  a17 reads «مو ظاهر للعرسان»).
- `GET /admin/featured-periods/summary` (`PROVIDERS_READ`): `{
  listedProviders, featured, free, endingThisWeek }`: `listedProviders` are
  the providers customers see (active with an active service), `featured`
  those featured now by the rule, `free` the rest; `endingThisWeek` counts
  the rule's running placements ending within seven days with nothing booked
  right after. Four reads, whatever the number of placements.
- `POST /admin/providers/:id/featured-periods` (`PROVIDERS_WRITE`, re-checked
  live under the account locks) with `{ endsOn: "YYYY-MM-DD", startsOn?,
  note? }` (`note` up to 500 characters: how he paid, as the administrator
  writes it). It starts now, or on a later day `startsOn`; it covers whole
  days through `endsOn`. Refusals: `404` unknown provider; `400` the
  administrator's own listing; `409 FEATURED_PROVIDER_NOT_ACTIVE`;
  `409 FEATURED_PROVIDER_UNCLAIMED` (an unclaimed listing takes no requests);
  `409 FEATURED_PROVIDER_NOT_LISTED` (no active service: customers do not find
  him, so the placement would rank and badge nothing);
  `409 FEATURED_PERIOD_OVERLAP` with the clashing `startsOn` and `lastDay`
  (periods of one provider never overlap; a renewal starts the day after; the
  provider's row lock serialises two grants, so of two at the same moment one
  is recorded and the other is this `409`, and the database's exclusion
  constraint `ProviderFeaturedPeriod_no_overlap` refuses an overlap from any
  other writer, read as the same `409`);
  `422 FEATURED_PERIOD_START_PAST` (never back-dated);
  `422 FEATURED_PERIOD_INVALID` (not a day, or over before it starts);
  `422 FEATURED_PERIOD_TOO_LONG` (more than 366 days). The provider is told
  «تفعّل ظهورك المميز» «… ملفك يطلع مع المميزين أول، وعليه علامة «مميز».» (or
  «ظهورك المميز محجوز» for a later start). It does not promise «أول في قسمك
  ومدينتك»: several featured providers share the top.
- `POST /admin/featured-periods/:id/end` (`PROVIDERS_WRITE`) with `{ note? }`
  stops an active placement now or cancels a booked one; the provider is told
  «وقّفنا ظهورك المميز» or «لغينا ظهورك المميز»: the standard sentence, then
  «ملاحظة الفريق: …» when a note was written (the note never replaces it;
  «يظهر عادي» is said only while the placement rule holds). One that is over
  is `409 FEATURED_PERIOD_FINISHED`.
- Every write is in the admin audit log (route and target). An hourly job
  tells the provider, once each: «بدأ ظهورك المميز» when a placement booked
  for a later day starts (`startNoticeAt`; one recorded to start at once was
  told by the grant); «ظهورك المميز ينتهي قريب» in the last seven days, only
  of a run longer than seven days (no warning minutes after it started);
  «خلص ظهورك المميز» at the end. It says nothing where a renewal right before
  (start) or right after (warning, end) carries the run on. Where the rule
  does not hold it says the truth or nothing: the start says he is not shown
  to customers, no «جدّده» warning is sent, and the end says only which day
  was the last. Each notice is marked in its own serializable transaction
  under the period's row lock, so a retry or a second instance tells nobody
  twice. All these notices are `GENERAL`, provider-audience, routed to the
  provider portal.

Joining, changes and reopening (B-01, B-02, B-10):

- `POST /api/v1/provider/apply` takes `categoryIds` (at least one; the first
  is the profile's category) and `services: [{ title, basePrice, currency?,
  description? }]` (1 to 5). Without a service whose `basePrice` is above zero
  it is `422 PROVIDER_SERVICE_REQUIRED` and nothing is written; a `currency`
  other than `YER` (D48) is `422 PROVIDER_JOINING_CURRENCY`. The services
  are created in the same write, in the profile's category, and stay hidden
  until approval (every customer read requires an `ACTIVE` provider).
- The joining rule (B-10, D41) is one rule: the profile has an **active**
  service priced above zero. Resubmitting, approving
  (`PATCH /admin/providers/:id/approve` is `422 PROVIDER_SERVICE_REQUIRED`
  without one) and adding the joining service before approval all read it.
- While `PENDING` or `NEEDS_CHANGES` the provider reads his services
  (`GET /api/v1/provider/me/services[/:id]`) and changes only a service's
  `title`, `basePrice` and `description` (a `currency` other than `YER` is
  `422 PROVIDER_JOINING_CURRENCY`); another service, `categoryId`, `cityId`,
  `priceUnit`, `isActive`, images and packages are `403
  PROVIDER_JOINING_SERVICE_ONLY` / `PROVIDER_NOT_ACTIVE`. A profile without
  an active priced service (it applied before B-10, or the team switched its
  service off) may add one in its category with the same fields, in `YER`.
  `PATCH /api/v1/provider/me/profile` takes `primaryCategoryId` only before
  approval (`409 PROVIDER_CATEGORY_LOCKED` after); the joining services move
  with it.
- `POST /api/v1/provider/me/application/resubmit` (`200`) takes
  `{ latestDecisionId: string | null }`, the `latestDecision.id` of the
  profile he read (required; `null` only when no decision is on record). It
  moves `NEEDS_CHANGES` to `PENDING`, sets `resubmittedAt`, increments
  `resubmitCount`, records a `RESUBMITTED` review step and notifies the
  provider «وصلنا تعديلك». From any other state it is
  `409 PROVIDER_NOT_AWAITING_CHANGES`; when a newer decision exists (the team
  rewrote its notes after he read them) it is `409 PROVIDER_REVIEW_CHANGED`
  with the current `latestDecisionId`, and nothing changes; without an active
  priced service it is `422 PROVIDER_SERVICE_REQUIRED`.
- `POST /api/v1/provider/me/application/reopen` (`200`, no body) moves
  `REJECTED` to `NEEDS_CHANGES`, sets `reopenedAt` and records a `REOPENED`
  step; the refusal's reason stays the note he reads. From any other state it
  is `409 PROVIDER_NOT_REJECTED`. A refused profile is approved or asked for
  changes only after this (approve and request-changes from `REJECTED` are
  `409 INVALID_PROVIDER_STATUS_TRANSITION`).
- The provider profile (and the admin provider rows) return `reviewNote` (the
  latest decision's note on the whole profile), `fieldNotes: [{ field, note
  }]` (`BUSINESS_NAME`, `CATEGORY`, `CITY`, `DESCRIPTION`, `SERVICE`),
  `latestDecision: { id, kind, at } | null`, `resubmittedAt`,
  `resubmitCount` and `reopenedAt`. The notes are those of the latest
  administrator decision while the status is `NEEDS_CHANGES`, `REJECTED` or
  `SUSPENDED`, and empty otherwise. «The latest» is by the review steps'
  `sequence`, never by time alone. A profile sent back reads «كان مرفوض»
  when its `latestDecision.kind` is `REJECTED` and «كان يحتاج تعديل»
  otherwise.
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
  `location`, `day: { confirmed, capacity }` (B-20: the day's confirmed
  bookings and his daily number, p28 «باقي N») and `money` (B-18, below).
- `PATCH /api/v1/provider/me/bookings/:id/confirm|decline|cancel` `{ note? }`.
- `GET /api/v1/provider/me/ledger?month=YYYY-MM` (B-18, p47) — `{ month,
  totals: [{ currency, agreed, paid, left, bookings }], bookings: [{
  bookingId, quoteRequestId, customerName, eventDate, money }] }`: the month's
  `CONFIRMED` bookings (a past day included), each currency on its own line.
  A malformed month is `400 LEDGER_INVALID_MONTH`.
- `GET|POST /api/v1/provider/me/blocked-dates` (`{ date }`) and
  `DELETE /api/v1/provider/me/blocked-dates/:date` — days the provider marks
  unavailable. Closing a day needs an approved (`ACTIVE`) account: otherwise
  `403 PROVIDER_NOT_ACTIVE` (B-42).

A booking response is `{ id, quoteRequestId, quoteOfferId, providerId,
eventDate, status, lifecycleStatus, cancelledBy, note, confirmedAt, declinedAt,
cancelledAt, expiredAt, createdAt, updatedAt }`. `status` is `REQUESTED |
CONFIRMED | DECLINED | CANCELLED | EXPIRED` (`EXPIRED`: an open request of a
provider the back office suspended, B-42; the customer may ask again);
`lifecycleStatus` adds `COMPLETED` for a confirmed booking whose day has
passed. Quote responses (customer and provider) carry `booking` (or `null`);
on the provider's request responses the booking also carries `money`.

**Money for the provider (B-18, D41, D60).** `money` is `{ agreed, paid, left,
currency, lastPaidAt } | null`: the customer's agreement filed from the
accepted offer (finance's `listCostsForOffers`), its total, everyone's
payments net of reversals, what is left (never below zero), the offer's
currency (the plan's, G19) and the last payment's time. `null` when the
customer keeps no agreement for the offer. The provider reads these three
totals only: never a payment, who paid, a receipt or a note, and he records
nothing.

**Capacity (B-20).** `Provider.dailyBookingCapacity` (1 to 20, default 1;
`PATCH /api/v1/provider/me/profile { dailyBookingCapacity }`, outside the
range `400`; the profile returns it) is how many `CONFIRMED` bookings he takes
on one day. A request or a confirmation for a blocked day returns
`409 BOOKING_DATE_UNAVAILABLE`; for a day whose confirmed bookings (the
booking itself excluded) already reach his number, `409 BOOKING_DAY_FULL`. A
`REQUESTED` booking takes no seat. Both checks run under the provider's row
lock, the only guard (the one-a-day partial unique index is dropped by
migration `20261027100000`), so of racing confirmations exactly the number's
worth succeed (`smoke:booking`). Lowering the number keeps the bookings
already confirmed and refuses the next confirmation. Blocking a day that
holds a confirmed booking returns `409 BOOKING_DATE_HAS_BOOKING`. A past day
returns `400 BOOKING_DATE_IN_PAST`; a step the status does not allow returns
`409 BOOKING_NOT_ALLOWED`. Each step notifies the other side
(`BOOKING_UPDATED`).

**Suspension (B-42).** `PATCH /admin/providers/:id/suspend` also, in its
transaction and under the provider's row lock, moves his `REQUESTED` bookings
to `EXPIRED` (`expiredAt`) and tells each customer «[المزود] موقوف مؤقتًا ·
انتهى طلب حجز يوم …»; his `CONFIRMED` bookings from today on stay and their
customers are told «[المزود] موقوف مؤقتًا · حجزك المؤكد يوم … باقي»
(`BOOKING_UPDATED`, `data.bookingEvent = PROVIDER_SUSPENDED`,
`data.bookingKept`). A suspended provider requests, confirms and closes
nothing (`403 PROVIDER_NOT_ACTIVE`). V1 has no provider-side pause switch.

**Deleting a provider's account (B-33).** Asking for the deletion (`POST
/api/v1/users/me/deletion`, D63) and the erasure after 30 days, by the
owner of a provider with `CONFIRMED` bookings from today on (Sana'a) returns
`409 PROVIDER_HAS_UPCOMING_BOOKINGS { count, bookingIds }`; the check reads
under the provider rows' locks and the refusal rolls the whole erasure back.
Otherwise every customer whose open request (`SENT`, `VIEWED`, `RESPONDED`,
or `ACCEPTED` without a confirmed booking) goes with the account is told
«[المزود] أغلق حسابه» (`BOOKING_UPDATED`, `data.bookingEvent =
PROVIDER_CLOSED`, opening the phone's f01 «طلباتي» of the plan, or f02
without a plan), written after the purge and naming nothing erased.

Reviews (F10): `POST /api/v1/providers/:id/reviews` requires a confirmed
booking with the provider whose day has passed; otherwise
`403 REVIEW_REQUIRES_COMPLETED_BOOKING`.

### After The Booking (G25, 2026-10-27)

A booking stays `CONFIRMED`; its outcome, delivery and asked changes are
fields beside the status. Every booking response carries `completedAt`,
`notHappenedAt`, `notHappenedReason`, `deliveryDueAt`, `deliveredAt`,
`deliveryLink`, `deliveryNote`, `deliveryConfirmedAt` and `change` (the last
asked change: `id`, `fromDate`, `toDate`, `status`, `note`, `declineReason`).
`lifecycleStatus` reads `NOT_HAPPENED` once the provider reported it.

- `POST /api/v1/provider/me/bookings/:id/complete` — «تم», from the day to
  two days after (`409 BOOKING_OUTCOME_TOO_EARLY`, `_TOO_LATE`,
  `_ALREADY_DECIDED`, `_NOT_CONFIRMED`). Sets `deliveryDueAt` from the accepted
  offer's `deliveryDays`. The customer is asked to review.
- `POST /api/v1/provider/me/bookings/:id/not-happened`
  `{ reason: CUSTOMER_NO_SHOW | WE_DID_NOT_ATTEND | FORCE_MAJEURE | OFFICIAL_DECISION }`
  — «ما صار»; the booking is never reviewed. Same window and codes.
- The hourly booking job completes a confirmed booking once that window has
  passed and the provider said nothing (p26: «لو ما قلت شي خلال يومين ينحسب
  تم»), so «ما صار» is never offered after the booking already completed.
- `POST /api/v1/provider/me/bookings/:id/delivery` `{ link?: http(s) URL, note? }`
  — once, after «تم» (`409 BOOKING_DELIVERY_NOT_COMPLETED`, `_ALREADY_DELIVERED`).
- `POST /api/v1/me/bookings/:id/delivery/confirm` — the customer confirms, once
  (`409 BOOKING_DELIVERY_NOT_DELIVERED`, `_ALREADY_CONFIRMED`).
- `POST /api/v1/me/bookings/:id/change` `{ eventDate: "YYYY-MM-DD", note? }` — the
  customer asks to move a confirmed booking before its day; one pending change
  at a time (`409 BOOKING_CHANGE_CHANGE_PENDING`, `_SAME_DAY`, `_DAY_PASSED`,
  `_NOT_CONFIRMED`).
- `POST /api/v1/provider/me/booking-changes/:id/accept` — checks the new day
  against blocked days and the daily capacity (`409 BOOKING_DATE_UNAVAILABLE`,
  `BOOKING_DAY_FULL`) and moves the booking. A change left waiting until the
  booking's day or the new day passed can only be declined
  (`409 BOOKING_CHANGE_DAY_PASSED`, `_NEW_DAY_PASSED`, `_NOT_CONFIRMED`).
- `POST /api/v1/provider/me/booking-changes/:id/decline` `{ reason? }` — the
  booking keeps its day.
- RA-BE-48: «تم» and «ما صار» are said from the booking's day on, and that
  day a cancel and a move are still open, so once an outcome is said the
  booking is neither cancelled (`409 BOOKING_OUTCOME_ALREADY_DECIDED`) nor
  moved (`409 BOOKING_CHANGE_ALREADY_DECIDED`, asking and accepting alike). A
  booking asked again after a cancel or decline reuses its row and starts
  clean: no outcome, no delivery, and any change still waiting is closed
  (`CANCELLED`), so it can never be accepted onto the new booking.
- RA-BE-47: a provider cannot confirm a booking whose plan was archived
  (`409 BOOKING_PLAN_ARCHIVED`); declining stays open.
- RA-BE-46: a review needs a past confirmed booking that happened; «ما صار»
  closes it unless the provider's own reason is `WE_DID_NOT_ATTEND`, which
  leaves the review of not coming open.

### Offer Contents And Reasons (G24, 2026-10-27)

- B-05: `PATCH /api/v1/provider/me/quote-requests/:id/status` with `REJECTED`
  takes `declineReason` (`BUSY_THAT_DAY | OUT_OF_AREA | NOT_MY_SERVICE | OTHER`),
  `declineMessage` and `blockDay` (only with `BUSY_THAT_DAY` on a dated request;
  the day closes in the same transaction unless a confirmed booking holds it,
  and the response says `dayBlocked`). Quote responses carry `declineReason`
  and `declineMessage`.
- B-07: offer create and update take `lines`
  (`[{ label, kind: INCLUDED | EXCLUDED | EXTRA, amount? }]`, a positive amount
  only on `EXTRA`, at most 30; `400 QUOTE_OFFER_LINES_INVALID`) and
  `deliveryDays` (0 to 365). Both are part of each version and of «ايش تغيّر»;
  a viewer without money access reads no extra price and no `lines` change.
- B-11: `PATCH /api/v1/quote-offers/:id/reject` takes `{ reason?: PRICE |
  CHOSE_OTHER | DATE | NONE, message? }`; offers carry `rejectReason` and
  `rejectMessage`.

## Guest Invitations And RSVP

V1 checklist 4.7. Each guest gets a personal link to confirm or decline,
without an account.

- `POST /api/v1/guests/:id/invitation-link` (guest-management permission; a
  contributor only for guests they added) takes `{ reminder?: boolean }` and
  returns `{ guestId, url, phone, invitationStatus, message }`. `url` is
  `INVITE_PUBLIC_ORIGIN/rsvp/<token>` with a 43-character token; only its
  SHA-256 is stored, and a new link retires the previous one. A `NOT_SENT`
  invitation becomes `SENT`. `message` is the Arabic WhatsApp text the app
  sends as is (D83, one source): the host line of the card in the plan's form
  («يتشرف … بدعوتكم» / «تتشرف … بدعوتكن»), the card's free text, the wedding's
  date with its time and venue, the events beyond the wedding this guest is
  invited to, the map link or the address, and the link. With `reminder:
  true` it is the short reminder text with the new link instead.
- `GET /api/v1/public/rsvp/:token` (no auth, 30/min) returns `{ guestName,
  planTitle, weddingDate, locationLabel, attendanceStatus, companionsCount,
  maxCompanions, respondedAt, wedding, card, hostPhrase, events }`. `wedding`
  is the wedding row's `{ timeSlot, exactTime, timeLabel, placeLabel }` or
  null; `card` is `{ hostLine, freeText, photoUrl, mapUrl, address }` or null;
  `hostPhrase` is the host line as a sentence in the plan's form, or null;
  `events` lists the events beyond the wedding this guest is invited to:
  `{ id, label, date, timeSlot, exactTime, timeLabel, placeLabel,
  attendanceStatus, companionsCount, respondedAt }`.
- `POST /api/v1/public/rsvp/:token` (no auth, 10/min) `{ attendance:
  "CONFIRMED" | "DECLINED", companionsCount?, planEventId? }` (0–20; 0 when
  declining). Without `planEventId` it updates the guest's attendance, status
  and companions (the wedding); with it, the reply to that one event (`409
  RSVP_EVENT_NOT_INVITED` when the guest is not invited to it, RA-BE-74: the
  link works and the page reloads the invitation as it is now), leaving the
  wedding reply as it is. The plan owner is notified (`GUEST_RESPONDED`, the
  event named in the title) when the reply changes the attendance or the
  companions; the same reply sent again notifies nobody (RA-BE-87).

An unknown or malformed token, or an archived plan, returns
`404 RSVP_LINK_NOT_FOUND`. The public page `/rsvp/<token>` on the public site
calls these routes on its own origin; the edge proxy forwards
`/api/v1/public/rsvp/*` on the site host to the API.

## Wedding Events (b12, b13; D65)

The wedding's events, from which the phone builds the wedding week (b04,
y06, y12) and the wedding day (b05, y07). Planning owns them. Every plan
member reads them (D52: the week and the day are not money); the owner, or a
member with `canEditPlan`, changes them on a plan that is not archived.

- `GET /api/v1/wedding-plans/:weddingPlanId/events` → `{ weddingPlanId,
  party: "GROOM"|"BRIDE"|"HELPER"|null, canEdit, items: [PlanEvent],
  suggestions: [type] }`. `items` are ordered by day (an undated one last),
  then by the time of day each starts. The main event (`type: "WEDDING"`) is
  always there: its `date` is the plan's wedding date and its `id` is null
  until something about it is saved. `suggestions` are b12's «اقتراحات»: the
  party's customary nights (groom `SAMRA`, `MAQEEL`; bride `HAFLA`,
  `NASHMA`; a helper's plan both) and `AQD`, `LUNCH`, `DINNER` the plan has
  not added, then `CUSTOM`.
- `PlanEvent`: `{ id, type, title, date: "YYYY-MM-DD"|null, timeSlot,
  exactTime: "HH:mm"|null, placeLabel, responsibleName, note, isMain }`.
  `type` is one of `WEDDING SAMRA MAQEEL HAFLA NASHMA AQD LUNCH DINNER
  CUSTOM`; `timeSlot` one of `DUHA DHUHR AFTER_DHUHR AFTER_ASR
  AFTER_MAGHRIB AFTER_ISHA EXACT` (b13's times plus «الظهر», C8). The labels
  are the phone's (the bride's wedding is «الزفة»).
- `POST /api/v1/wedding-plans/:weddingPlanId/events` `{ type, title?, date?,
  timeSlot?, exactTime?, placeLabel? (120), responsibleName? (60), note?
  (120) }` → `201 PlanEvent`. Every kind but `CUSTOM` is once per plan; the
  wedding's first details are saved by posting `WEDDING` once.
- `PATCH /api/v1/wedding-plans/:weddingPlanId/events/:eventId` (the same
  fields) → `PlanEvent`. An absent field keeps its value, `null` clears it;
  a time other than `EXACT` drops a stored hour.
- `DELETE /api/v1/wedding-plans/:weddingPlanId/events/:eventId` →
  `{ deleted: true }`.
- Refusals: `409 EVENT_TYPE_EXISTS`, `409 EVENT_IS_MAIN` (the wedding stays),
  `409 EVENT_LIMIT_REACHED` (30 events), `400 EVENT_CUSTOM_TITLE_REQUIRED`,
  `400 EVENT_WEDDING_DATE_IS_PLAN_DATE` (its day moves with «أجّل العرس»),
  `400 EVENT_EXACT_TIME_REQUIRED`, `400 EVENT_EXACT_TIME_INVALID`,
  `400 EVENT_DATE_INVALID`, `409 PLAN_ARCHIVED_READ_ONLY`, `404` for a
  reader who may not edit or a stranger.

## Provider Portfolio («معرض الشغل», B-16, D62)

Every new portfolio photo waits for the moderation team; customers see only
approved photos; the women's album «حفلات النساء» is read by a bride only.

- Upload: the ordinary signed upload (`POST /api/v1/media/uploads/presign`
  then `verify`) with `purpose: "provider-portfolio"` (public object; JPEG,
  PNG or WebP, 10 MB at most, the account's rolling daily upload quota). The
  verify step re-encodes the image, which drops its EXIF (location, camera).
- `GET /api/v1/provider/me/portfolio` (the provider, any status) returns
  `{ items: [{ id, key, imageUrl, album, forWomen, noFaces, status,
  rejectionReason, reviewedAt, createdAt }], socialLinks: { tiktok?,
  instagram?, facebook? }, servesWomen, womenAlbum: "حفلات النساء",
  maxItems: 60 }`, items in his order. `status` is `PENDING`, `APPROVED` or
  `REJECTED`; a refused photo's `imageUrl` is null (its image is deleted)
  and `rejectionReason` is the team's words.
- `PUT /api/v1/provider/me/portfolio` (an approved provider only, else
  `403 PROVIDER_NOT_ACTIVE`, D41) `{ items: [{ key, album?, noFaces? }],
  socialLinks?: { tiktok?, instagram?, facebook? } }` replaces the whole
  portfolio in that order and returns it as above. A new `key` must be his
  own verified `provider-portfolio` upload, used once; it is created
  `PENDING`. A kept photo keeps its decision unless its album or `noFaces`
  changed (then `PENDING` again); a refused one stays refused. A photo left
  out is removed and its image becomes a media deletion job. `socialLinks`
  omitted keeps his links; given, it replaces them (an empty value removes
  one). Refusals: `422 PORTFOLIO_TOO_MANY_ITEMS { max: 60 }`,
  `422 PORTFOLIO_WOMEN_ALBUM_NOT_SERVED` (none of his sections is shown to
  brides), `422 PORTFOLIO_WOMEN_PHOTO_NEEDS_NO_FACES`,
  `422 PORTFOLIO_SOCIAL_LINK_INVALID { network }` (https only; hosts
  `tiktok.com`/`www.`/`m.` with `/@name`, `instagram.com`/`www.`/`m.` with
  `/name`, `facebook.com`/`www.`/`m.`/`web.` with `/name` or
  `/profile.php?id=`; written back in one form), `409 PORTFOLIO_CHANGED`
  (a new photo vanished meanwhile), `400` for a repeated key, an album over
  30 characters or a key that is not his.
- `GET /api/v1/provider/me/profile` adds `portfolio: { photos, pending,
  rejected, socialNetworks }` for p35's line «18 صورة · تيك توك مربوط».
- `GET /api/v1/providers/:id/portfolio` (signed in) returns `{ items: [{ id,
  imageUrl, album, forWomen }], socialLinks }`: the approved photos in his
  order, the women's album only when the reader's account persona is
  `BRIDE`. f03's photos are the cover, then these; the app shows no
  service photo (`ProviderServiceImage`) to customers, since those are
  never reviewed (D62).
- `GET /admin/portfolio-items?status=PENDING&page&limit` (n07,
  `PROVIDERS_READ`) lists photos of one status (PENDING by default), oldest
  first, with `provider { id, businessName, status }`.
- `PATCH /admin/portfolio-items/:id/decision` (`REVIEWS_WRITE`: the
  moderation team and the super admin) `{ decision: "APPROVE" | "REJECT",
  reason?, noFacesChecked? }`. A refusal needs `reason` (1 to 300
  characters); approving a women's photo needs `noFacesChecked: true` (else
  `422 PORTFOLIO_NO_FACES_NOT_CHECKED`); a decided or removed photo is
  `409 PORTFOLIO_ITEM_ALREADY_DECIDED` / `404`. A refusal deletes the image.
  The provider is told (`PORTFOLIO_REVIEWED`; its route target, from the
  notice registry's `providerPortfolio`, opens p37):
  «انقبلت صورة من معرضك · صورتك في «الزفة» تظهر الحين للعرسان.» (للعرائس for
  the women's album) or «ما قبلنا صورة من معرضك · … السبب: …». Audited.

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
the stored flag only when an invitation is created, and later role changes
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
- `GET /admin/providers/applications` (`resubmitted=true|false` narrows the
  list to `PENDING` profiles sent back after changes, or to the other
  `PENDING` ones, B-01, whatever statuses the list would hold otherwise; with
  a `status` other than `PENDING` it is `400`);
  `GET /admin/dashboard/stats` adds `resubmittedProviders` and
  `pendingClaims`.
- `GET /admin/providers/applications/:id`
- `GET /admin/providers/:id/review-history` (`PROVIDERS_READ`):
  `{ providerId, appliedAt, events: [{ id, kind, at, actor: { id, name } |
  null, notes: [{ field, note }] }] }`, oldest first; `kind` is
  `CHANGES_REQUESTED`, `REJECTED`, `APPROVED`, `SUSPENDED`, `ACTIVATED`,
  `RESUBMITTED` or `REOPENED`.
- `POST /admin/providers` (a listing without an account, see Provider References)
- `PATCH /admin/providers/:id/approve` (from `PENDING` or `NEEDS_CHANGES`;
  `422 PROVIDER_SERVICE_REQUIRED` without an active priced service, D41)
- `PATCH /admin/providers/:id/reject`
- `PATCH /admin/providers/:id/request-changes` with `{ note?, fieldNotes?:
  [{ field, note }] }` (at least one note; each field once). Allowed from
  `PENDING` and `NEEDS_CHANGES`, so the team can rewrite its notes while the
  provider is fixing; the newest decision's notes are the ones he reads.
- `GET /admin/provider-claims`, `POST /admin/provider-claims/:id/approve`,
  `POST /admin/provider-claims/:id/reject` (see Provider References)
- `GET /admin/featured-periods`, `GET /admin/featured-periods/summary`,
  `POST /admin/providers/:id/featured-periods`,
  `POST /admin/featured-periods/:id/end` (featured placement, B-43; see
  Provider References). Admin provider rows carry `isFeatured` and
  `featuredUntil` from the placement covering now, by the placement rule.
  Admin services carry no `isFeatured` and the services report no
  `services.featured` (D54).
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
- `PATCH /admin/reviews/:id/reply-status` `{ status: PUBLISHED | HIDDEN }`
  (`REVIEWS_WRITE`, B-09, a10): hides or shows the provider's reply; `404
  REVIEW_REPLY_NOT_FOUND` without one. `GET /admin/reviews` carries
  `reply: { body, repliedAt, status } | null`.
- `DELETE /admin/reviews/:id`
- `GET /admin/conversation-reports`
- `PATCH /admin/conversation-reports/:id/status`
- The desk reads and changes no one's notifications: the five
  `/admin/notifications` routes and `NOTIFICATIONS_READ` /
  `NOTIFICATIONS_WRITE` were removed with the page they served (D56, B4).
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

Every provider category the four `/admin/provider-categories` routes return
carries `budgetItems: { groom, bride, shared }`: the money item an accepted
offer of that category is filed under in a new groom's, bride's and shared
plan, computed by the acceptance matcher (G38) against the published money
starter items; `null` means «أخرى» (no item fits), which a08 shows in coral
and says after a save (D53). A category an administrator creates or renames
is not pinned by the migrations' test, so this is where its placement shows.

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

### Money Refusals (G22, 2026-10-27)

Every money rule a request can break answers `400` or `409` with
`{ statusCode, code, message, detail }`: `code` is stable
(`FINANCE_PAYMENT_EXCEEDS_REMAINING`, `FINANCE_FUNDING_HAS_PAID_REPAYMENTS`, …),
`message` is the reason in Arabic for the person, and `detail` keeps the rule
in English for logs. D112 (Q-3): `FINANCE_PAYMENT_EXCEEDS_REMAINING` names
what is left in its `message` («الدفعة أكبر من الباقي على الاتفاق. الباقي عليه
20,000.»); the payment is never cut to fit. `DELETE /api/v1/funding-sources/:id` refuses a source with
a paid repayment (`409 FINANCE_FUNDING_HAS_PAID_REPAYMENTS`).

An archived plan still accepts settlement of money already agreed: a cost
payment, a schedule paid, a payment reversal, and a loan repayment marked
paid or unpaid (G15). Its payment-date and loan-repayment reminders continue.

The dashboard summary carries `essentials` (G23): the six items the owner
named (`VENUE`, `DRESS`, `PHOTO`, `GOLD`, `HOME`, `HONEYMOON`), each `BOOKED`,
`AGREED`, `MISSING` or `NONE` with its `budgetCategoryId`; null without money
rights.

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
| GET | `/admin/assistant-reports` | `admin.listAssistantAnswerReports` | 🔒 |
| PATCH | `/admin/assistant-reports/:id/resolve` | `admin.resolveAssistantAnswerReport` | 🔒 |
| GET | `/admin/audit-logs` | `admin-audit.list` | 🔒 |
| GET | `/admin/bookings` | `admin.listBookings` | 🔒 |
| GET | `/admin/bookings/:id` | `admin.getBooking` | 🔒 |
| GET | `/admin/cities` | `admin.listCities` | 🔒 |
| POST | `/admin/cities` | `admin.createCity` | 🔒 |
| DELETE | `/admin/cities/:id` | `admin.deleteCity` | 🔒 |
| PATCH | `/admin/cities/:id` | `admin.updateCity` | 🔒 |
| GET | `/admin/conversation-reports` | `admin.listConversationReports` | 🔒 |
| PATCH | `/admin/conversation-reports/:id/status` | `admin.updateConversationReportStatus` | 🔒 |
| GET | `/admin/dashboard/stats` | `admin.getDashboardStats` | 🔒 |
| GET | `/admin/data-requests` | `admin.listDataRequests` | 🔒 |
| POST | `/admin/data-requests/:id/restore` | `admin.restoreAccountDeletion` | 🔒 |
| DELETE | `/admin/districts/:id` | `catalogs.disableDistrict` | 🔒 |
| PATCH | `/admin/districts/:id` | `catalogs.updateDistrict` | 🔒 |
| GET | `/admin/districts/:id/localities` | `catalogs.listLocalities` | 🔒 |
| POST | `/admin/districts/:id/localities` | `catalogs.createLocality` | 🔒 |
| GET | `/admin/featured-periods` | `admin.listFeaturedPeriods` | 🔒 |
| POST | `/admin/featured-periods/:id/end` | `admin.endFeaturedPeriod` | 🔒 |
| GET | `/admin/featured-periods/summary` | `admin.getFeaturedSummary` | 🔒 |
| GET | `/admin/governorates` | `catalogs.listGovernorates` | 🔒 |
| POST | `/admin/governorates` | `catalogs.createGovernorate` | 🔒 |
| DELETE | `/admin/governorates/:id` | `catalogs.disableGovernorate` | 🔒 |
| PATCH | `/admin/governorates/:id` | `catalogs.updateGovernorate` | 🔒 |
| GET | `/admin/governorates/:id/districts` | `catalogs.listDistricts` | 🔒 |
| POST | `/admin/governorates/:id/districts` | `catalogs.createDistrict` | 🔒 |
| DELETE | `/admin/localities/:id` | `catalogs.disableLocality` | 🔒 |
| PATCH | `/admin/localities/:id` | `catalogs.updateLocality` | 🔒 |
| GET | `/admin/portfolio-items` | `admin.listPortfolioItems` | 🔒 |
| PATCH | `/admin/portfolio-items/:id/decision` | `admin.decidePortfolioItem` | 🔒 |
| GET | `/admin/provider-categories` | `admin.listCategories` | 🔒 |
| POST | `/admin/provider-categories` | `admin.createCategory` | 🔒 |
| DELETE | `/admin/provider-categories/:id` | `admin.deleteCategory` | 🔒 |
| PATCH | `/admin/provider-categories/:id` | `admin.updateCategory` | 🔒 |
| GET | `/admin/provider-claims` | `admin.listClaimRequests` | 🔒 |
| POST | `/admin/provider-claims/:id/approve` | `admin.approveClaimRequest` | 🔒 |
| POST | `/admin/provider-claims/:id/reject` | `admin.rejectClaimRequest` | 🔒 |
| GET | `/admin/providers` | `admin.listProviders` | 🔒 |
| POST | `/admin/providers` | `admin.createListedProvider` | 🔒 |
| GET | `/admin/providers/:id` | `admin.getProvider` | 🔒 |
| PATCH | `/admin/providers/:id/activate` | `admin.activateProvider` | 🔒 |
| PATCH | `/admin/providers/:id/approve` | `admin.approveProvider` | 🔒 |
| POST | `/admin/providers/:id/featured-periods` | `admin.grantFeaturedPeriod` | 🔒 |
| PATCH | `/admin/providers/:id/reject` | `admin.rejectProvider` | 🔒 |
| PATCH | `/admin/providers/:id/request-changes` | `admin.requestProviderChanges` | 🔒 |
| GET | `/admin/providers/:id/review-history` | `admin.getProviderReviewHistory` | 🔒 |
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
| PATCH | `/admin/reviews/:id/reply-status` | `admin.updateReviewReplyStatus` | 🔒 |
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
| POST | `/api/v1/auth/admin/password-reset/verify` | `auth.verifyAdminPasswordReset` |  |
| POST | `/api/v1/auth/admin/refresh` | `auth.refreshAdmin` |  |
| POST | `/api/v1/auth/login` | `auth.login` |  |
| POST | `/api/v1/auth/logout` | `auth.logout` | 🔒 |
| POST | `/api/v1/auth/logout-all` | `auth.logoutAll` | 🔒 |
| GET | `/api/v1/auth/me` | `auth.me` | 🔒 |
| POST | `/api/v1/auth/otp/request` | `auth.requestOtp` |  |
| POST | `/api/v1/auth/otp/verify` | `auth.verifyOtp` |  |
| POST | `/api/v1/auth/password` | `auth.setPassword` | 🔒 |
| POST | `/api/v1/auth/password-reset/confirm` | `auth.confirmPasswordReset` |  |
| POST | `/api/v1/auth/password-reset/request` | `auth.requestPasswordReset` |  |
| POST | `/api/v1/auth/phone-change/confirm` | `auth.confirmPhoneChange` | 🔒 |
| POST | `/api/v1/auth/phone-change/request` | `auth.requestPhoneChange` | 🔒 |
| POST | `/api/v1/auth/refresh` | `auth.refresh` |  |
| POST | `/api/v1/auth/register` | `auth.register` |  |
| POST | `/api/v1/auth/register/complete` | `auth.completeRegistration` |  |
| DELETE | `/api/v1/budget-categories/:id` | `budget-categories.remove` | 🔒 |
| PATCH | `/api/v1/budget-categories/:id` | `budget-categories.update` | 🔒 |
| PUT | `/api/v1/budget-categories/:id/suggestion` | `budget-categories.setSuggestion` | 🔒 |
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
| GET | `/api/v1/data-exports/:token` | `data-exports.download` |  |
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
| POST | `/api/v1/me/bookings/:id/change` | `bookings.requestChange` | 🔒 |
| POST | `/api/v1/me/bookings/:id/delivery/confirm` | `bookings.confirmDelivery` | 🔒 |
| GET | `/api/v1/me/favorite-providers` | `marketplace.findMyFavoriteProviders` | 🔒 |
| GET | `/api/v1/me/quote-requests` | `marketplace.findMyQuoteRequests` | 🔒 |
| GET | `/api/v1/me/quote-requests/:id` | `marketplace.findMyQuoteRequest` | 🔒 |
| POST | `/api/v1/me/quote-requests/:id/booking` | `bookings.requestBooking` | 🔒 |
| PATCH | `/api/v1/me/quote-requests/:id/cancel` | `marketplace.cancelMyQuoteRequest` | 🔒 |
| GET | `/api/v1/me/wedding-plans/:weddingPlanId/bookings` | `bookings.listPlanBookings` | 🔒 |
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
| POST | `/api/v1/provider/me/application/reopen` | `provider-dashboard.reopenApplication` | 🔒 |
| POST | `/api/v1/provider/me/application/resubmit` | `provider-dashboard.resubmitApplication` | 🔒 |
| GET | `/api/v1/provider/me/blocked-dates` | `bookings.listBlockedDates` | 🔒 |
| POST | `/api/v1/provider/me/blocked-dates` | `bookings.blockDate` | 🔒 |
| DELETE | `/api/v1/provider/me/blocked-dates/:date` | `bookings.unblockDate` | 🔒 |
| POST | `/api/v1/provider/me/booking-changes/:id/accept` | `bookings.acceptChange` | 🔒 |
| POST | `/api/v1/provider/me/booking-changes/:id/decline` | `bookings.declineChange` | 🔒 |
| GET | `/api/v1/provider/me/bookings` | `bookings.listBookings` | 🔒 |
| PATCH | `/api/v1/provider/me/bookings/:id/cancel` | `bookings.cancel` | 🔒 |
| POST | `/api/v1/provider/me/bookings/:id/complete` | `bookings.complete` | 🔒 |
| PATCH | `/api/v1/provider/me/bookings/:id/confirm` | `bookings.confirm` | 🔒 |
| PATCH | `/api/v1/provider/me/bookings/:id/decline` | `bookings.decline` | 🔒 |
| POST | `/api/v1/provider/me/bookings/:id/delivery` | `bookings.deliver` | 🔒 |
| POST | `/api/v1/provider/me/bookings/:id/not-happened` | `bookings.notHappened` | 🔒 |
| GET | `/api/v1/provider/me/claim` | `provider-dashboard.getClaim` | 🔒 |
| GET | `/api/v1/provider/me/ledger` | `bookings.ledger` | 🔒 |
| GET | `/api/v1/provider/me/packages` | `provider-dashboard.findPackages` | 🔒 |
| POST | `/api/v1/provider/me/packages` | `provider-dashboard.createPackage` | 🔒 |
| DELETE | `/api/v1/provider/me/packages/:id` | `provider-dashboard.deactivatePackage` | 🔒 |
| PATCH | `/api/v1/provider/me/packages/:id` | `provider-dashboard.updatePackage` | 🔒 |
| GET | `/api/v1/provider/me/portfolio` | `provider-dashboard.getPortfolio` | 🔒 |
| PUT | `/api/v1/provider/me/portfolio` | `provider-dashboard.updatePortfolio` | 🔒 |
| GET | `/api/v1/provider/me/profile` | `provider-dashboard.getProfile` | 🔒 |
| PATCH | `/api/v1/provider/me/profile` | `provider-dashboard.updateProfile` | 🔒 |
| PATCH | `/api/v1/provider/me/quote-offers/:id` | `provider-dashboard.updateQuoteOffer` | 🔒 |
| POST | `/api/v1/provider/me/quote-offers/:id/withdraw` | `provider-dashboard.withdrawQuoteOffer` | 🔒 |
| GET | `/api/v1/provider/me/quote-requests` | `provider-dashboard.findQuoteRequests` | 🔒 |
| GET | `/api/v1/provider/me/quote-requests/:id` | `provider-dashboard.findQuoteRequest` | 🔒 |
| POST | `/api/v1/provider/me/quote-requests/:id/offers` | `provider-dashboard.createQuoteOffer` | 🔒 |
| PATCH | `/api/v1/provider/me/quote-requests/:id/status` | `provider-dashboard.updateQuoteRequestStatus` | 🔒 |
| GET | `/api/v1/provider/me/reviews` | `provider-dashboard.findReviews` | 🔒 |
| POST | `/api/v1/provider/me/reviews/:id/reply` | `provider-dashboard.replyToReview` | 🔒 |
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
| GET | `/api/v1/providers/:id/portfolio` | `marketplace.findProviderPortfolio` | 🔒 |
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
| POST | `/api/v1/reviews/:id/report` | `marketplace.reportReview` | 🔒 |
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
| PATCH | `/api/v1/users/me` | `users.updateMe` | 🔒 |
| DELETE | `/api/v1/users/me/deletion` | `account-deletion-status.cancelDeletion` | 🔒 |
| GET | `/api/v1/users/me/deletion` | `account-deletion-status.deletionStatus` | 🔒 |
| POST | `/api/v1/users/me/deletion` | `account-deletion-status.requestDeletion` | 🔒 |
| GET | `/api/v1/users/me/deletion/impact` | `account-deletion-status.deletionImpact` | 🔒 |
| POST | `/api/v1/users/me/exports` | `users.createExport` | 🔒 |
| GET | `/api/v1/users/me/privacy` | `users.getPrivacy` | 🔒 |
| PATCH | `/api/v1/users/me/privacy` | `users.updatePrivacy` | 🔒 |
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
| POST | `/api/v1/wedding-plans/:planId/mahr` | `money-summary.recordMahr` | 🔒 |
| PUT | `/api/v1/wedding-plans/:planId/money-budget` | `money-summary.replaceMoneyBudget` | 🔒 |
| GET | `/api/v1/wedding-plans/:planId/money-summary` | `money-summary.getMoneySummary` | 🔒 |
| GET | `/api/v1/wedding-plans/:planId/plan-view` | `dashboard.getPlanReadView` | 🔒 |
| GET | `/api/v1/wedding-plans/:weddingPlanId/assistant` | `assistant.status` | 🔒 |
| POST | `/api/v1/wedding-plans/:weddingPlanId/assistant/questions` | `assistant.ask` | 🔒 |
| POST | `/api/v1/wedding-plans/:weddingPlanId/assistant/reports` | `assistant.report` | 🔒 |
| GET | `/api/v1/wedding-plans/:weddingPlanId/budget-categories` | `budget-categories.findForPlan` | 🔒 |
| POST | `/api/v1/wedding-plans/:weddingPlanId/budget-categories` | `budget-categories.create` | 🔒 |
| GET | `/api/v1/wedding-plans/:weddingPlanId/contributions` | `contribution-history.list` | 🔒 |
| GET | `/api/v1/wedding-plans/:weddingPlanId/cost-payments` | `wedding-costs.list` | 🔒 |
| GET | `/api/v1/wedding-plans/:weddingPlanId/costs` | `wedding-costs.list` | 🔒 |
| POST | `/api/v1/wedding-plans/:weddingPlanId/costs` | `wedding-costs.create` | 🔒 |
| GET | `/api/v1/wedding-plans/:weddingPlanId/events` | `plan-events.list` | 🔒 |
| POST | `/api/v1/wedding-plans/:weddingPlanId/events` | `plan-events.create` | 🔒 |
| DELETE | `/api/v1/wedding-plans/:weddingPlanId/events/:eventId` | `plan-events.remove` | 🔒 |
| PATCH | `/api/v1/wedding-plans/:weddingPlanId/events/:eventId` | `plan-events.update` | 🔒 |
| GET | `/api/v1/wedding-plans/:weddingPlanId/guest-groups` | `guests.findGroups` | 🔒 |
| POST | `/api/v1/wedding-plans/:weddingPlanId/guest-groups` | `guests.createGroup` | 🔒 |
| GET | `/api/v1/wedding-plans/:weddingPlanId/guests` | `guests.findForPlan` | 🔒 |
| POST | `/api/v1/wedding-plans/:weddingPlanId/guests` | `guests.create` | 🔒 |
| POST | `/api/v1/wedding-plans/:weddingPlanId/guests/bulk` | `guests.bulkCreate` | 🔒 |
| GET | `/api/v1/wedding-plans/:weddingPlanId/guests/invitation-card` | `guests.invitationCard` | 🔒 |
| PUT | `/api/v1/wedding-plans/:weddingPlanId/guests/invitation-card` | `guests.setInvitationCard` | 🔒 |
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
| POST | `/api/v1/wedding-plans/:weddingPlanId/tasks/shift-due-dates` | `tasks.shiftDueDates` | 🔒 |
| GET | `/api/v1/wedding-plans/:weddingPlanId/tasks/summary` | `tasks.summary` | 🔒 |
| GET | `/api/v1/wedding-plans/:weddingPlanId/timeline` | `timeline.getForPlan` | 🔒 |
| GET | `/api/v1/wedding-plans/active` | `wedding-plans.findActive` | 🔒 |
| GET | `/api/v1/wedding-plans/my` | `wedding-plans.findMine` | 🔒 |
| GET | `/health` | `health.getCompatibilityHealth` |  |
| GET | `/live` | `health.getLiveness` |  |
| GET | `/metrics` | `metrics.metrics` |  |
| GET | `/ready` | `health.getReadiness` |  |
| GET | `/ready/core` | `health.getCoreReadiness` |  |
<!-- DOCS-SYNC:END -->
