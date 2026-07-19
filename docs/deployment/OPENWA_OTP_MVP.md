# Temporary OpenWA OTP MVP Gate

Snapshot date: 2026-07-12

This is a temporary, risk-accepted MVP transport. Meta Cloud API remains the
target production channel. OpenWA is unofficial and may be blocked by WhatsApp;
it must use a dedicated disposable number and must never be presented as a
zero-risk replacement for Meta.

## Non-Negotiable Source Gate

- Pin the reviewed OpenWA source tag and commit. Do not deploy `latest`.
- Build an Aarast-owned image from that source; do not trust an unreviewed
  third-party image.
- The stock `POST .../messages/send-text` endpoint is forbidden for OTP because
  it persists the message body and recipient in OpenWA history.
- The hardened fork must implement two private external-service capabilities:
  `send-transient-text` below the selected session's message resource and
  `otp-readiness` below the selected session resource. They are OpenWA routes,
  not Aarast controller routes.
- Transient delivery must bypass database/message-history persistence, plugins,
  webhooks, request-body logs, audit bodies, and failure payloads. It must also
  suppress any engine event that would re-persist the same outgoing message.
- A successful transient response must contain a non-empty `messageId` and
  `deliveryStatus: "DELIVERED"` only after WhatsApp reports the device-delivery
  acknowledgement. A send result or `SENT` acknowledgement alone is not
  success. A 503 body may expose only the stable codes `NOT_ATTEMPTED`,
  `REJECTED`, or `DELIVERY_UNCERTAIN`; it must never expose the recipient, body,
  Chromium error, or WhatsApp internals.
- The hardened adapter must address the normalized phone `@c.us` identifier
  first so a new recipient does not depend on an existing local contact/LID
  mapping. It may retry once through the canonical `@lid` only for the explicit
  `No LID for user` rejection. Ambiguous delivery outcomes must never trigger a
  second send. It must use `waitUntilMsgSent`, bound every wait, and
  force-recover Chromium only after a real timeout/unresponsive signal.
- Source tests and a live history query must prove a unique OTP marker is absent
  after delivery. Deleting a stored row after sending does not satisfy this
  requirement.

Until those gates pass, keep `AUTH_OTP_MODE=disabled` or `whatsapp`. Aarast
readiness deliberately reports `openwa: down` against an ordinary upstream
instance.

## Aarast Runtime Contract

Set secrets only in the deployment secret store:

- `AUTH_OTP_MODE=openwa`
- `OPENWA_BASE_URL` — private service URL; internal HTTP or public HTTPS only.
- `OPENWA_CREDENTIAL_FILE` — absolute path to the backend-specific,
  session-scoped credential file. The file contains the session id, key id,
  key, and expiry, is mounted read-only, and is re-read for every delivery.
- `OPENWA_AUDIT_API_KEY` — operator-only key used solely by the explicit
  real-send smoke to prove that no message row was persisted. Never give this
  key to the Aarast backend container; it keeps only its session-scoped
  `transient_sender` key.
- `OPENWA_OTP_TIMEOUT_MS=15000`
- `OTP_GLOBAL_DAILY_LIMIT=150`

The backend applies PostgreSQL-backed atomic quotas before delivery:

- one request per phone per 60 seconds;
- five per phone per hour and ten per phone per day;
- ten per IP per ten minutes and fifty per IP per day;
- a deployment-wide daily ceiling, initially 150.

Only HMAC digests are stored in `OtpDispatchQuota`; raw phone and IP values are
not persisted by the limiter. Failed provider deliveries still consume quota.

## Infrastructure Gate

- Expose no OpenWA port publicly. Only the backend and an operator-only QR path
  may reach it.
- Use a dedicated encrypted persistent volume for WhatsApp session state.
- Disable plugins, webhooks, inbound automation, message history, and dashboard
  access not required for the OTP session.
- Use a random API key, container capability drop, read-only root filesystem
  where supported, bounded CPU/memory/PIDs, and private network egress rules.
- Back up no QR/session state to ordinary application backups.
- In the full product deployment, `/ready` must show `database`, `redis`,
  `media`, and `openwa` as `up` before enabling OTP traffic. The isolated
  OTP-only lab has no media service by design: it requires `database`, `redis`,
  and `openwa` as `up` while `media` is explicitly `disabled`.

The isolated reproducible lab is under `deploy/openwa-otp-lab/`. It binds the
operator and Aarast ports to loopback, provisions a dedicated session-scoped
`transient_sender` credential into a Docker volume, and leaves the normal
Compose/Dokploy deployment untouched.

After the local laboratory passes, `deploy/openwa-otp-staging/` is the only
approved server acceptance manifest. It exposes only the Aarast backend through
`otp-lab-api.shadowgardn.com`, keeps the OpenWA operator surface on loopback,
and issues distinct expiring transport credentials for acceptance and
production plus a separate audit credential. A scheduled reconciler validates
new credentials before atomically replacing the mounted files and retains at
most one safe previous key until expiry. A passing local run does not authorize
pointing a release APK at an ephemeral tunnel.

## Manual Acceptance Gate

The operator must scan the QR with the dedicated number, then verify:

1. one real OTP arrives and verifies;
2. a second request before 60 seconds returns `429`;
3. disconnecting the WhatsApp session makes Aarast `/ready` return `503`;
4. restarting the service automatically restores the linked session from its
   protected volume and returns `/ready` to `200` without another QR scan or a
   manual session-start request;
5. OpenWA database, history, logs, hooks, webhooks, and crash output contain
   neither the marker, recipient, nor API key;
6. source tests prove that `DELIVERED` requires the device-delivery
   acknowledgement, that sent-only acknowledgement times out as uncertain, all
   three 503 codes, missing/invalid 2xx acknowledgements, direct `@c.us`
   delivery with explicit-only `@lid` fallback, and timeout-versus-rejection
   classification;
7. reconnect/relink behavior is stable for 24 hours.
8. an accelerated rotation proves both backends adopt new, distinct files
   without restart, the previous correctly-scoped key remains temporarily
   valid, and no third active transport key accumulates.

The optional `npm run smoke:openwa-otp` gate requires
`OPENWA_SMOKE_CONFIRM=I_ACCEPT_REAL_WHATSAPP_SEND`, the transient sender key in
`OPENWA_API_KEY`, and the separate operator key in `OPENWA_AUDIT_API_KEY`. It
rejects public plaintext HTTP and performs its history read without putting the
recipient in the request URL.

## Rollout And Stop Rules

Roll out manually: internal accounts, then at most 50 OTP/day; raise to 150/day
only after seven stable days. Stop immediately on an account warning/ban,
repeated relinking, delivery failure above 5%, p95 delivery above 60 seconds,
any plaintext OTP leak, or weekly average above the approved ceiling. Switch
back by setting `AUTH_OTP_MODE=disabled` or the approved `whatsapp` channel; no
mobile release is required.
