# Play Data Safety Form — Answers

Snapshot date: 2026-07-08

Fill the Play Console **Data safety** section with these answers. They
reflect what the code actually does (verified against the schema, the
Android manifest, and the media/upload paths), not aspirations. Re-verify
if data handling changes.

## Data collection & sharing summary

- **Does your app collect or share user data?** Yes (collect). **Share:
  No** — data is not sent to third parties for their own use.
- **Is all data encrypted in transit?** Yes (HTTPS).
- **Do you provide a way to request data deletion?** Yes (account
  deletion; support email in the privacy policy).

## Data types collected

| Category | Data type | Collected | Shared | Purpose | Optional? |
|----------|-----------|-----------|--------|---------|-----------|
| Personal info | Name | Yes | No | App functionality, account | Required |
| Personal info | Phone number | Yes | No | Account, OTP sign-in | Required |
| Personal info | Email address | Yes | No | Account | Optional |
| Personal info | Other (guest names/phones you add) | Yes | No | App functionality (guest list) | Optional |
| Financial info | Other (self-entered budgets, expenses, debts) | Yes | No | App functionality | Optional |
| Photos | Photos | Yes | No | App functionality (profile/provider media) | Optional |
| App activity | Other (wedding plan content) | Yes | No | App functionality | Required |
| App info & performance | Crash logs | Yes | No | Diagnostics | Optional |
| App info & performance | Diagnostics (request ids) | Yes | No | Diagnostics | Optional |

Notes for the reviewer form:

- **Financial info**: this is user-entered planning data (budgets,
  expenses, debts). The app does **not** collect payment-card or bank
  numbers and processes **no** in-app payments — do not tick "Payment
  info".
- **Contacts**: the `READ_CONTACTS` permission is used only to let the
  user pick a single contact's name/number when adding a guest. The
  full address book is not read or uploaded. On the form, this maps to
  the guest name/phone you enter, not to a "Contacts" upload.
- **Location**: not collected. No location permissions are requested.
- **Advertising / tracking**: none. No ad IDs, no cross-app tracking.

## Security practices (declare)

- Data is encrypted in transit: **Yes**.
- Users can request data deletion: **Yes**.
- Committed to Play Families policy: N/A (not a children's app).

## Permissions declared in the manifest

- `INTERNET` — API communication.
- `READ_CONTACTS` — single-contact picker for the guest list (see above).
