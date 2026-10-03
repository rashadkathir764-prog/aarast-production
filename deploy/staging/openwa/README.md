# Staging OpenWA delivery confirmation

The reviewed OpenWA image is `0.8.17`, revision
`b7a52913ef1c32613ddd1b24f4bcb1ec912e4132`, with `whatsapp-web.js 1.34.7`.
Its local image ID is
`sha256:f8046e08d029cbb3433769f09034ffbea4e3d84c0ec78294f896cb1c9c9ff8b4`.

On the independently linked Staging session, WhatsApp Web message keys carry
`$1`, not `_serialized`. The installed library looks up the just-sent message
using `newMsgKey._serialized`, so `Client.sendMessage(): Promise<Message>`
actually returns `undefined`. Its message serializer also passes through an
ID without `_serialized`. This is an ID extraction defect, not permission to
interpret a send without an exception as delivery.

This build corrects those two extraction/serialization boundaries only. It
uses the real string identifier from `$1` when `_serialized` is absent and
normalizes the library's Message ID contract before return/events. It does
not invent an identifier, timestamp, ACK, correlation token, or success.
The hardened adapter still requires a valid Message ID and timestamp and a
device `message_ack` of delivered/read (2/3). Server ACK 1, missing fields,
timeouts, disconnects and negative ACKs retain their existing failure rules.
The Aarast Backend HTTP contract is unchanged and still fails closed.

The current path is Identity `AuthService.issueOtp` -> platform
`OpenWaOtpChannel` -> `sendOpenWaTransientText` -> OpenWA's
`send-transient-text` route -> `WhatsAppWebJsAdapter` -> installed
`Client.sendMessage` -> injected `WWebJS.sendMessage`. The Backend validates
the returned `messageId`, timestamp and `DELIVERED` status as transport proof;
it does not persist or return the identifier to the OTP caller. Keeping the
identifier required preserves that proof and requires no shared API change.

The actual Staging runtime was inspected by field shape only: the native key,
its serialized ID and the library message model had `$1` and lacked
`_serialized`. No recipient, message body, OTP or identifier is logged by this
correction. This matches the upstream reports
[201852](https://github.com/wwebjs/whatsapp-web.js/issues/201852) and
[201857](https://github.com/wwebjs/whatsapp-web.js/issues/201857), but the
installed source and actual Staging return shape are the proof for this fix.

`apply-message-key-fix.cjs` refuses an unreviewed package version or source
hash. This correction is pinned to the installed dependency; on an approved
dependency upgrade, review the upstream extraction, rerun these regression
tests, and remove this correction when the upstream implementation passes
them. Do not broaden the patch or suppress its build failure.

## Build outside the deployment server

Inspect the base ID/revision first. Use a new local tag only for that exact
ID, then build the image with network disabled. Never retag an existing
deployment image or modify a running old installation.

```powershell
docker image inspect sha256:f8046e08d029cbb3433769f09034ffbea4e3d84c0ec78294f896cb1c9c9ff8b4
docker tag sha256:f8046e08d029cbb3433769f09034ffbea4e3d84c0ec78294f896cb1c9c9ff8b4 aarast-openwa-reviewed-local:b7a52913-f8046e08
docker build --pull=false --network=none -t aarast-openwa-staging:delivery-<candidate-sha> deploy/staging/openwa
```

The build runs `message-key-contract.test.cjs` against the installed library,
Client, Message and hardened adapter. Tests use external WhatsApp browser
fixtures only; they never load a session or send a real message. The `$1`
case fails on the original image and passes after the correction. Tests also
protect old-format IDs, negative ACKs, delayed device ACKs, missing fields,
send failure and acknowledgement timeout.

Inspect the resulting immutable image ID and supply it as
`STAGING_OPENWA_IMAGE`. Keep the deployed runtime read-only and at **2 GiB /
1.5 CPU**. A real send must then pass the normal transient route and Backend
verification on the existing independent Staging session. No live monkey
patch, ordinary persisted-message route, fixed OTP, or old session fallback
is part of this fix.

## Verified delivery run — 2026-10-03

- Base Aarast source: `d828924044d51cebb816d7f806f0b518474d9834`.
- Original installed library: 4 regression failures / 5 passes. Corrected
  installed library and adapter: 9 passes / 0 failures, including the real
  10-second device-ACK timeout. The API contract and Backend code were unchanged.
- Corrected local image ID:
  `sha256:dce321f6f82914928fcf1d80d4eedd6106da3883d324f9aa283860e39e9def28`.
- The existing independently linked Staging session was restored without
  copying any old/Production session. A disposable Backend/DB proof issued a
  real registration OTP: `DELIVERED`, incorrect-code rejection, and successful
  correct-code registration. The normal API did not expose the code.
- Three further real Backend login OTP requests returned device-confirmed
  `DELIVERED` in 1112 / 1142 / 1574 ms. The real 60-second cooldown was respected.
  Correct verification succeeded, one-time reuse failed, and the final code
  failed after its actual five-minute expiration. No automatic retry occurred.
- The authorized recipient was the linked sender's own WhatsApp account.
  Device ACK and Backend verification prove this self-message scenario; delivery
  to a different recipient and phone Push are not claimed.
- A private diagnostic captured the actual randomly generated OTP only in
  volatile memory while forwarding the original Backend fetch unchanged. It
  never replaced generation, provider response, verification, or expiration.
  That diagnostic is not in this image or repository; its Backend was stopped
  after proof. No phone, code, token, private key or message ID is in this record.
- Fresh isolated PostgreSQL replay: 76 completed migrations / 0 pending;
  repeated deploy applied nothing and status reported up to date. DB, Redis,
  media, Backend, Admin and Invite services were healthy; `/live`, `/ready`,
  Admin, Invite `/healthz` and an `/invites/` page returned 200. The Invite root
  correctly remains 404 under its existing route contract.
- Firebase Staging credentials initialized and authenticated from inside the
  Backend using the current modular Admin SDK. No device Push was sent.
- Controlled local full-stack startup and OTP run used six CPU cores and an
  available-memory budget matching the server snapshot. `MemAvailable` was
  5484.95 MiB before startup, at least 4307.09 MiB throughout, and 4597.47 MiB
  at completion. Running-container usage at completion was 1045.55 MiB.
  OpenWA peak was 1059.70 MiB; its cap remained 2048 MiB / 1.5 CPU. Every
  measured container had zero current/peak swap usage, zero OOM kills and
  zero automatic restarts. OpenWA recorded about 3.13 seconds of cumulative
  CPU quota throttling; throttling was not reported as zero.
- This is a representative local workload measurement, not a run on the
  deployment server or proof of that server's concurrent project bursts.
  The 76-migration replay occurred before the controlled startup measurement;
  the measured restart ran the no-op migration job. Final same-server peak
  capacity under initial replay and existing-project load remains unproven.
- Backend typecheck/build, architecture gates, full tests (1568 passed,
  28 skipped, 0 failed), and 12 Staging/Invite contract tests passed. Docs
  validation had zero errors and 17 existing stale-date warnings. Backend
  image build reported 7 dependency advisories (2 moderate / 5 high), unchanged
  by this extraction correction; they were not silently fixed or suppressed.
- Only disposable local proof services and the local memory-load fixture were
  stopped. Containers, networks, volumes and session data were preserved; the
  corrected independent OpenWA session remains running. No server deployment,
  existing-server service change, resource deletion or main merge occurred.
