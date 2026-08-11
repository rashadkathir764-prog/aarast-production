# Play Data Safety Form — Answers

Snapshot date: 2026-08-11

Fill the Play Console **Data safety** section with these answers. They
reflect what the code actually does (verified against the schema, the
Android manifest, and the media/upload paths), not aspirations. Re-verify
if data handling changes.

## Data collection & sharing summary

- **Does your app collect or share user data?** Yes (collect). **Share:
  No** — data is not sent to third parties for their own use.
- **Is all data encrypted in transit?** Yes (HTTPS).
- **Do you provide a way to request data deletion?** Yes (account
  deletion; support email and instructions in the privacy/support pages).

Store-facing source URLs:

- Privacy policy: `https://aarast.shadowgardn.com/privacy`
- Support and account deletion: `https://aarast.shadowgardn.com/support`

The repository contains static source for these pages, but the console answers
must not be submitted until both URLs and the current text are verified over
HTTPS in the release environment.

## Data types collected

| Category | Data type | Collected | Shared | Purpose | Optional? |
|----------|-----------|-----------|--------|---------|-----------|
| Personal info | Name | Yes | No | App functionality, account | Required |
| Personal info | Phone number | Yes | No | Account, OTP sign-in | Required |
| Personal info | Email address | Yes | No | Account | Optional |
| Personal info | Other (guest names/phones you add) | Yes | No | App functionality (guest list) | Optional |
| Financial info | Other (self-entered budgets, wedding costs, and payment schedules) | Yes | No | App functionality | Optional |
| Photos | Photos | Yes | No | App functionality (profile/provider media) | Optional |
| App activity | Other (wedding plan content) | Yes | No | App functionality | Required |
| Device or other IDs | Firebase Installation ID (FID) | Yes | No | App functionality (Android Push delivery and account/device binding) | Required in the configured Android Production build; account binding occurs only after notification authorization |
| App info & performance | Crash logs | Yes | No | Diagnostics | Required in the Production store build |
| App info & performance | Diagnostics (request ids and sampled performance traces) | Yes | No | Diagnostics | Required in the Production store build |
| App info & performance | Other diagnostics (Support report attachment) | Yes | No | App support | Optional — fresh consent for each send |

Notes for the reviewer form:

- **Financial info**: this is user-entered planning data (budgets,
  wedding costs, recorded payments, and payment schedules). The app does **not** collect payment-card or bank
  numbers and processes **no** in-app payments — do not tick "Payment
  info".
- **Contacts**: the `READ_CONTACTS` permission is used only to let the
  user pick a single contact's name/number when adding a guest. The
  full address book is not read or uploaded. On the form, this maps to
  the guest name/phone you enter, not to a "Contacts" upload.
- **Location**: not collected. No location permissions are requested.
- **Advertising / tracking**: none. No ad IDs, no cross-app tracking.
- **Push identifier**: the configured Android Production build initializes
  Firebase, which may create/process a Firebase Installation ID and the
  associated FCM delivery token. After the user authorizes notifications, the
  app explicitly registers the FID with Aarast for account-scoped Push
  delivery. Aarast does not persist the FCM token in its Backend and does not
  use either identifier for advertising or cross-app tracking.
- **Crash and diagnostic collection**: the Production store build requires a
  real Sentry DSN. Redacted crash/error events, request identifiers, and sampled
  performance traces are therefore automatic Production diagnostics, not a
  user-optional Support action. The separate in-memory Support report
  attachment is optional and requires a new explicit consent for every send.

## Security practices (declare)

- Data is encrypted in transit: **Yes**.
- Users can request data deletion: **Yes**.
- Committed to Play Families policy: N/A (not a children's app).

## Permissions declared in the manifest

- `INTERNET` — API communication.
- `READ_CONTACTS` — single-contact picker for the guest list (see above).
- `POST_NOTIFICATIONS` — Android notification permission for Firebase Push;
  denial keeps Push registration disabled and does not disable the in-app
  notification inbox.
