# Play Data Safety Form — Answers

Snapshot date: 2026-08-11. Updated 2026-11-07: the planning assistant and
its answer reports (RA-ST-04, D95), and review reports (RA-ST-05, D94).

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
| Contacts | Contacts (only the contacts the user picks to add as guests: name and number) | Yes | No | App functionality (guest list) | Optional |
| Financial info | Other (self-entered budgets, wedding costs, and payment schedules) | Yes | No | App functionality | Optional |
| Photos | Photos | Yes | No | App functionality (profile/provider media) | Optional |
| App activity | Other (wedding plan content) | Yes | No | App functionality | Required |
| App activity | Other user-generated content (reviews of providers, chat messages, reports of a review, a chat or an assistant answer) | Yes | No | App functionality, moderation | Optional |
| App activity | Other actions (questions to the planning assistant) | Yes (count only; a reported answer is kept) | No | App functionality (planning assistant) | Optional — explicit consent before the first question |
| Device or other IDs | Firebase Installation ID (FID) | Yes | No | App functionality (Android Push delivery and account/device binding) | Required in the configured Android Production build; account binding occurs only after notification authorization |
| App info & performance | Crash logs | Yes | No | Diagnostics | Required in the Production store build |
| App info & performance | Diagnostics (request ids and sampled performance traces) | Yes | No | Diagnostics | Required in the Production store build |
| App info & performance | Other diagnostics (Support report attachment) | Yes | No | App support | Optional — fresh consent for each send |

Notes for the reviewer form:

- **Financial info**: this is user-entered planning data (budgets,
  wedding costs, recorded payments, and payment schedules). The app does **not** collect payment-card or bank
  numbers and processes **no** in-app payments — do not tick "Payment
  info".
- **Contacts** (corrected 2026-11-08 from the code): with `READ_CONTACTS`,
  «من جهات الاتصال» reads the device's address book **on the device** to
  list it for picking (`contact_picker_service.dart` `loadAll`, used by the
  guest import), and the add-guest field opens a single-contact picker. The
  address book itself is never uploaded; only the contacts the user ticks
  are sent, as guests (name and number). On the form tick **Contacts →
  Collected** (not shared, app functionality, optional), as well as the
  guest name/phone under Personal info. Saying the address book is not
  read was not true and would not survive a review.
- **Location**: not collected. No location permissions are requested.
- **Advertising / tracking**: none. No ad IDs, no cross-app tracking.
- **Push identifier**: the configured Android Production build initializes
  Firebase, which may create/process a Firebase Installation ID and the
  associated FCM delivery token. After the user authorizes notifications, the
  app explicitly registers the FID with Aarast for account-scoped Push
  delivery. Aarast does not persist the FCM token in its Backend and does not
  use either identifier for advertising or cross-app tracking.
- **Planning assistant (AI-generated content)**: after the user's explicit
  in-app consent, a summary of the plan as that user sees it (city, date,
  counts, budget items and amounts only with money permission, received
  quotes, market ranges; never guest names or phone numbers, never another
  member's private items) is processed by Anthropic (Claude) as a service
  provider on Aarast's behalf, not for its own use and not for model
  training; under Play's definitions this is not "Sharing". Questions and
  answers are not stored, only their daily count. Every answer has «بلّغ عن
  الإجابة»: the reported answer, its question and the reason are stored for
  the moderation team («البلاغات» → «إجابات المساعد» in the admin panel)
  and deleted with the account. This is the in-app reporting Play's
  AI-generated content policy asks for.
- **User-generated content**: reviews, chat messages and reports can be
  reported in the app (reviews: RA-ST-05, D94; chats: «بلّغ عن مشكلة») and
  are moderated in the admin panel.
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
- `READ_CONTACTS` — the guest list's single-contact picker and «من جهات
  الاتصال», which lists the address book on the device so the user picks
  whom to add (see above). **Prominent disclosure (D112 Q-10, 2026-11-13):**
  before Android's own prompt, and every time the permission is not yet
  held, the app shows its own page (`ContactPickerService.confirmAccess`):
  «نقرأ جهات الاتصال من جوالك» with what is read (names and numbers, on the
  phone), what is kept (only who is picked) and that the address book does
  not leave the phone, with «موافق، كمّل» and «مو الآن». Nothing is read
  before the yes. Play's User Data policy asks for exactly this; keep the
  page's wording and this paragraph in step.
- `POST_NOTIFICATIONS` — Android notification permission for Firebase Push;
  denial keeps Push registration disabled and does not disable the in-app
  notification inbox.
