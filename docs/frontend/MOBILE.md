# Mobile

Snapshot date: 2026-08-11

The mobile app is a Flutter Arabic-first Wedding Financial OS client. Current
product scope includes auth, onboarding, home/dashboard, one money system,
tasks, guests, sharing, notifications, providers/quotes, settings, support,
offline/cache behavior, the five-tab provider portal, unified provider
conversations, signed image uploads, and rotating refresh sessions.

## Current Direction

- Arabic-first and RTL-safe.
- Wedding Financial OS first.
- Money uses five user-facing terms only: `الميزانية`, `التصنيف`, `التكلفة`,
  `الدفعة`, and `موعد الدفع`.
- The Money root shows the canonical summary followed by WeddingCost cards;
  payment history stays inside each cost. `إضافة تكلفة` remains available when
  the general budget is unset. Accepting a provider offer refreshes Money so
  the automatically created cost appears immediately.
- Provider flows use a dedicated five-tab portal: Home, Requests, Services,
  Messages, and Profile.
- The provider profile/status endpoint loads independently from operational
  endpoints. Pending, change-requested, rejected, and suspended providers keep
  their business identity and administration note visible without attempting
  active-only services, requests, reviews, or chat APIs.
- After a provider application is submitted, its pending receipt offers only
  the logical return to Home. It does not send the new provider identity into
  the customer-facing provider marketplace through a `فتح الموردين` action.
- Provider services and packages support create, edit, pause, and reactivate;
  published customer reviews are visible in the provider Profile tab. A
  pending quote offer requires a positive amount in the linked plan currency
  and remains editable until accepted, rejected, cancelled, or expired.
- Provider sync refreshes live account contexts before loading portal data.
  The Profile account section separates workspace exit (return to path choice,
  keep the account session) from full logout.
- Provider categories are fetched and cached once as a shared catalog, then
  filtered for plan browsing by
  `AccountContextController.selectedContext.persona`: groom-only categories do
  not appear in a bride plan and bride-only categories do not appear in a
  groom plan. Route plan ids, legacy active-plan state, and provider state are
  never alternate persona sources. Provider context sees the catalog union for
  service management. The local database upgrade clears pre-audience category
  cache rows, and category JSON without both server-owned audience flags is
  rejected instead of being treated as visible to both personas.
- Marketplace distinguishes a successful empty response from a failed refresh.
  A failed favorites, services, packages, or reviews refresh keeps the last
  successful data visible as stale, shows an explicit Arabic error, and offers
  retry; it must never present a transport failure as a genuinely empty list.
- Remote push is available only when the server capability and local Firebase
  capability are both available. Missing either capability fails closed for
  remote push registration/delivery; supported in-app notifications remain
  available.
- Wedding location setup reads governorates and districts from the backend
  Yemen administrative catalog instead of a hardcoded six-location list.
  Governorates and per-governorate districts are cached in the encrypted local
  database. The existing `cityOrDistrict` draft field temporarily carries the
  selected district name for serialization compatibility.
- The approved messaging design starts only from a real quote request and
  remains an account-backed online action. The inbox shows one row per
  plan/provider or account/provider context, even when it contains multiple
  requests.
- Quote entry reads the conversation already linked by Backend. Chat renders a
  single message/system-event timeline, distinguishes PLAN from ACCOUNT, and
  disables sending with a clear state when the provider has no linked account.
- `canManageProviders` is a strong sharing permission: it grants the existing
  plan conversation history and authority to send as the plan. The sharing UI
  must state this explicitly.
- Conversation/media actions remain online-only and never enter the wedding
  planning SQLite sync queue.
- Access and refresh tokens are stored through `flutter_secure_storage` 10.3.1;
  Android legacy algorithms migrate automatically to RSA-OAEP + AES-GCM. A
  failed authenticated API call receives at most one refresh-and-retry attempt.
- Mobile offline data and queued writes use SQLCipher with a random 256-bit key
  held only by the OS keystore/keychain. Supported mobile platforms fail closed
  if secure storage cannot be opened; they never fall back to plaintext JSON.
- The cached safe-user profile and guest-onboarding draft use a separate secure
  storage namespace in production. Legacy SharedPreferences values migrate once
  and are removed; the selected account-context key is also stored in the
  secure namespace. The non-sensitive active-plan preference may remain in
  SharedPreferences for compatibility.
- Post-auth entry is centralized: auth/session check -> live account-context
  fetch -> zero contexts uses the existing onboarding state, one available
  context is selected automatically, multiple contexts show the standalone
  Arabic `اختر المسار` screen, and the selected context opens only its matching
  dashboard. `AccountContextController.selectedContext` is the only shell and
  route authority. Owner and contributor shells are separate and keyed by
  `contextKey`. The contributor shell is one `مساحتي` surface without bottom
  tabs; its task, money, guest, provider, and participant sections are rendered
  only from the selected context permissions. Its account menu separates
  workspace exit (back to path choice, session preserved) from full account
  logout (session cleared, login shown). Dashboard shells do not contain a
  path/context switcher.
- Registration keeps the pending draft in navigation memory only. No account
  or local session exists until `REGISTER` OTP completion succeeds; password
  and OTP login remain available for verified or legacy accounts. Registration
  contains only phone-owned fields; email is not accepted from a phone-only
  proof. A valid OTP can safely claim an old unverified user/provider row
  without losing its role or relations.
- The first registration request sends only name and phone. The password stays
  in in-memory navigation state until the verified completion request and is
  rejected above bcrypt's 72-byte UTF-8 boundary.
- Stable auth error codes are translated to Arabic at the network boundary.
  Before phone proof, login remains enumeration-safe and always offers recovery
  and account creation. After a correct OTP, a missing app account is stated
  explicitly and the user can open registration with the verified phone
  prefilled. An administrator may enroll a separate application password;
  mobile login/reset/profile never reads or changes the browser-admin password,
  identity, sessions, or MFA challenges. Application-facing names and avatars
  also come only from the separate app profile. Choosing the provider path may
  create an app-side provider profile but never converts or removes the
  browser-administrator role.
- Guest/local planning can exist, but protected cloud/share/provider writes must
  remain account-gated.
- Mobile Experience System V3 is the active visual contract. Its foundations
  live under `mobile/lib/core/experience_v3/`; the former Premium/Royal
  palette, compatibility aliases, and shared editorial hero are removed from
  active Mobile code. White owns every primary screen and color is limited to
  small semantic accents. The owner shell separates a compact plan-context
  anchor from a white five-destination dock that keeps every label visible.
  Home is a smart one-screen brief with one calculated next decision and a
  truthful continuous 2x2 metric surface. Its deterministic Plan Pulse
  reconciles real task, guest, provider, and money attention; it is not an AI
  claim. Money, Guests, Tasks, and Providers start with
  compact white summaries so working content remains above the fold. Empty,
  error, setup, utility, cost, and task states prefer continuous rows and
  dividers over nested cards; authentication and common forms use filled
  fields with a focus line and progressive disclosure. Routes, APIs,
  permissions, and offline ownership remain unchanged.
  The plan-level `+ إضافة` control is the single creation entry and orders its
  four real routes (task, guest, cost, quote) by current urgency and recent
  session use. It floats at the lower RTL side above navigation, shows a
  contextual label on task/guest/money roots, compacts while scrolling down,
  and stays absent when the current route or permission cannot create. The
  compact header now identifies plan, destination, and the deterministic
  wedding stage without increasing its height. Home renders only one
  deterministic priority at a time. Task,
  guest, and payment rows expose one truthful contextual action while keeping
  secondary mutations in overflow menus; pending guests use `تحديث الرد`, not
  a fake reminder action. Durable task, guest, quote, plan, sharing, provider,
  budget, cost, payment, and schedule forms securely autosave account-scoped
  drafts, restore values after navigation/interruption, and clear them only
  after successful submit or account teardown. Password and OTP input is never
  persisted. Every non-auth domain form starts with one Focus decision and uses
  a fixed keyboard-safe primary action; progressive detail and live summaries
  appear where they resolve a real user decision.
  Guest, participant, notification, and settings collections now use one
  shared continuous-row hierarchy rather than a card per record. More is
  limited to two utility groups and isolates logout/deletion in an
  account-action sheet. Provider details put real media immediately after
  identity, then trust/price, services, and the quote decision while packages,
  about, and reviews open progressively. Failed media renders a designed state.
  Home, Tasks, and Guests share the thin `AarastV3PlanPath` product signature
  and the matching Home metrics use quiet shared-element transitions.
  A shared date-stage engine resolves `بداية التخطيط`, `مرحلة التخطيط`,
  `الشهر الأخير`, `الأسبوع الأخير`, `يوم العرس`, and `إغلاق الخطة` from the
  real wedding date. The same stage appears in plan chrome, Home, Tasks, Guests,
  Money, and Providers and adapts priority and quick-add ordering; it is
  deterministic, offline-safe, and never claims AI readiness. Tasks,
  notifications, and payment schedules share the same
  `الآن / اليوم / هذا الأسبوع / لاحقًا / مكتمل` time grammar. Saved providers
  use one two-or-three-column comparison surface instead of repeated full
  provider cards. Successful forms use one non-blocking receipt and either a
  truthful next action or an automatic return to the logical destination.
  Production Mobile code contains no
  gradients or decorative box shadows; the source contract enforces this.
  The current 50-Golden catalog has been reviewed against the flat-white V3
  foundation. Active routes also resolve one runtime screen contract carrying
  purpose, archetype, state support, privacy, offline, and one-hand metadata;
  unmapped routes fail visibly instead of inheriting a silent generic design.
  Complete physical loading/error/offline/read-only coverage at both 320px and
  420px remains an open release gate. See
  `docs/frontend/DESIGN_SYSTEM.md` and
  `docs/design/AARAST_MOBILE_EXPERIENCE_SYSTEM_V3.docx`.
- `/wedding-plans/:id/wedding-day` is the permission-aware Wedding Day command
  view. Home exposes it only from seven days before the event through the day
  after. It uses real plan time/location, urgent unfinished tasks, responsible
  contacts, and existing providers; missing provider contact data is not
  invented. Mobile schema version 8 caches the complete dashboard summary, so
  date/time/location, permission snapshot, important items, and provider
  previews remain available with cached tasks after a cold offline start. This
  adds no backend, booking, payment-processing, or open-messaging contract.
- Product builds require a public HTTPS API origin and cannot enable the
  development login bypass. Android refuses debug signing for Release.
- Canonical invitation links are
  `https://aarast.shadowgardn.com/invites/TOKEN` and
  `aarast://open/invites/TOKEN`. The create-invite flow keeps the one-time raw
  token in screen memory only and asks the backend to deliver a generic private
  link through the hardened transient OpenWA contract. Delivery uncertainty is
  reported honestly and the owner may copy the link as a fallback. A linked
  invite requests OTP only after the bearer and entered phone match the same
  live pending invitation. Successful phone proof resumes the private flow and
  shows the invitation, role, and permissions without accepting it. The
  participant must then explicitly accept or reject; only acceptance opens the
  contributor plan space. When that phone has no application
  credential, the same invite OTP also creates the contributor account with a
  name, password, and matching confirmation chosen by the participant; no
  random hidden password or second OTP is used. The response must include the
  complete access/refresh session before the app treats the user as signed in.
  Closing and reopening the app restores the rotating
  session from secure storage. Explicit logout still revokes the session and
  routes to password login, where OTP remains an optional login/recovery path.
  The public HTTPS landing and WhatsApp
  message expose no names, dates, permissions, or plan details before phone
  verification. Android App Link association is part of the public-site image;
  its certificate fingerprint and the physical-device flow must be revalidated
  whenever release signing changes.
- Native Android/iOS launcher and splash assets use the current Aarast brand
  mark rather than Flutter defaults.

## Contributor Workspace And Account Actions

- Contributor section visibility and mutations use the intersection of the
  selected account-context permissions and the refreshed dashboard permission
  snapshot. Flutter does not treat a role label as authority and does not
  download plan-wide rows for local filtering; each section consumes the
  Backend-scoped response.
- The live section contract requires a current membership, the current stored
  section permission, and item-level assignment or the contributor's own
  created/completed contribution evidence where applicable. Contribution
  evidence from an earlier tenure can identify the same person's prior work,
  but cannot restore a departed plan context or bypass a currently revoked
  permission.
- Each write-capable section card places its Arabic create action below the
  section summary as a full-width `FilledButton.icon`. The action is omitted
  when the current write permission is false. The contributor workspace must
  contain no nested `FloatingActionButton`, and its contract covers 320px RTL
  layouts at 1.3 and 2.0 text scale without clipping `إضافة مهمة`,
  `إضافة ضيف`, or `إضافة تكلفة`.
- `سجل مساهماتي` is a separate read-only screen backed by
  `/api/v1/wedding-plans/:weddingPlanId/contributions`. It displays immutable,
  privacy-allowlisted snapshots and the server coverage date. Its response
  model has no `entityId`, and cards do not navigate to a mutable live row. The
  client uses strict parsing and 50-item pagination; malformed rows, duplicate
  ids, invalid dates, non-string snapshot keys, or overlapping/inconsistent
  pages produce an explicit Arabic refresh state rather than silently losing
  history.
- The contributor account sheet distinguishes four operations: `الخروج من
  المساحة` returns to context choice without ending membership; `مغادرة
  الخطة` ends only the selected plan membership; `تسجيل الخروج من الحساب`
  ends the device session; and `حذف الحساب` invokes the central Aarast account
  deletion flow. Before leaving, Flutter stores a durable
  installation/user/plan-bound cleanup marker and one client request id. An
  ambiguous result keeps the plan quarantined across restart, cache clear, and
  logout; replay runs before contexts load. The exact plan-scoped local graph is
  deleted and filtered contexts are committed before the marker is removed.
- Offline schema version 8 stores an explicit `planId` for plan-scoped queue
  rows. Unknown or contradictory legacy ownership is permanently blocked, and
  neither migration nor cleanup guesses a plan from endpoints, ids, nested JSON,
  or substrings. Version 8 also adds the plan-scoped full dashboard-summary
  cache used by Home and Wedding Day; it does not expand the write queue.
- Account deletion uses the shared typed `حذف` confirmation in
  `account_deletion_flow.dart`; provider, contributor, and general account
  surfaces must not implement separate deletion semantics. Before the first
  request, Flutter securely persists one account/user-bound deletion marker and
  stable client request id, unmounts the old dashboard, and enters the safe
  termination gate. A lost or ambiguous response is reconciled through
  `/api/v1/account-deletions/status`; the marker is removed only after a
  confirmed deletion and centralized local teardown, or after a definitive
  rejection paired with `NOT_STARTED`. Local teardown is retryable without
  changing the server request id, and only this deleted-account path removes
  that user's durable leave markers. A `PENDING` status never triggers an
  immediate competing DELETE: the gate truthfully says that deletion is being
  verified and retries status later with the same id. The app intentionally
  receives only the projected application user, so it does not guess whether
  the underlying row is also an administrator; Backend applies the dual-realm
  deletion boundary and returns the unchanged `{ deleted: true }` contract.
- A task write rejected after permission revocation must surface Backend HTTP
  `403`, code `TASK_PERMISSION_REVOKED`, and the Arabic message
  `لم تعد لديك صلاحية لتنفيذ هذه المهمة`; `Plan not found` is not the task
  permission-revocation contract.

These behaviors are present in the current source. On 2026-08-11 the combined
working-tree gate passed `flutter analyze --no-pub`, all 1150 Flutter tests,
the visually reviewed settings Golden, and a public-API debug APK build. No
physical-device run was performed for that exact working tree. The latest
physical evidence remains the 2026-08-10 checkpoint, where the branch-closure
gate passed 1134/1134 tests (1084 non-Golden plus 50 reviewed Goldens), Release
Web, and a public-API debug APK build. That APK installed and cold-launched on a Samsung
SM-S938B at 1440x3120 and 1.15 text scale; Home, Money, Tasks, Guests, and
Providers rendered without Flutter, RenderFlex, SQLite, or fatal runtime
errors. On 2026-08-03 the earlier final
combined gate also passed all 997 Flutter tests, and a local
Flutter Web runtime rendered the Arabic welcome gateway without console errors.
The latest direct-install Android Release APK is `1.0.0+8`, built from exact
Mobile source revision `2ffbe95d7a8e412ead47220536046501f4ac86bf`. It is
non-debuggable, min SDK 24/target SDK 36, APK Signature Scheme v2 verified, and
signed by the Aarast RSA-3072 upload identity that matches deployed Android
association. Its size is 88,634,008 bytes and SHA-256 is
`075D82E24BEF4DED75F34D663B76132C9A6D6F89C7FE6535009C734A0CA1C69D`.
The owner-plus-two-contributor Backend HTTP scenario and both fresh and populated
legacy migration paths also passed. The earlier Release APK installed and
launched on a physical Android 16 device
without a fatal process or SQLite error, but the retained authenticated session
correctly stopped at the explicit context-load retry state because Production
then served the old Backend contract. Production revision
`959c47b756d0bebc3e4e4fda5f81ae3349d05e62` now includes the coordinated
contract and all 76 migrations, so the old run is historical and must be
repeated; it is not retroactive device acceptance. The latest local APK was
built with private Firebase client inputs without writing their values to
source or logs, but repeatable CI/store packaging remains a release gate. Its
Sentry release ID is embedded while the Sentry DSN is intentionally empty. The
SQLCipher schema-v6-to-v7
migration remains a post-deployment Android/iOS device gate even though shared
JSON migration and SQLite ownership source contracts pass locally. The latest
2026-08-10 debug APK installed and passed the owner root-tab smoke on the
connected Samsung device. Home was reviewed again after the plan moment was
expanded to its 146-176px responsive range with date above location. A cached
owner dashboard also passed an airplane-mode cold start without fatal, Flutter,
layout, or SQLite errors. Exhaustive
secondary/auth/form coverage and offline mutation/sync recovery remain open
physical Android gates; physical iOS remains blocked on the available Windows
host. Real WhatsApp OTP, background/terminated Push, Sentry symbolication,
store AAB upload, and store review also remain open.

## Plan Management

- `إدارة الخطة` is the administrative profile for a wedding plan, not a second
  dashboard.
- It owns plan identity and date, structured wedding location, participants and
  permissions, saved preferences, data-completeness status, and supported plan
  administration.
- Tasks, money, guests, providers, quotes, costs, countdowns, and daily progress
  remain in the dashboard or their dedicated tabs.
- Copy, export, and delete actions stay hidden until their backend contracts are
  implemented. The current supported destructive action is archive.

## Implementation Rules

- Do not show fake counts, fake participants, or unsupported live actions.
- Do not expose private financial details to shared members without
  `canViewMoney`.
- Resolve the current plan's effective permissions before loading finance
  resources or showing money write actions. Every write action and direct write
  route requires `canManageMoney` and fails closed otherwise.
- Render every money amount with the selected plan currency; `ر.ي` is not a
  valid fallback for a plan whose currency is `SAR`, `USD`, or another code.
- Clear plan-scoped finance state before loading a different plan so a failed
  request cannot leave the previous plan's private data visible.
- The Money root presents one budget card, categories, costs, upcoming payment
  dates, and recent payments. Its FAB contains only add cost, record payment,
  and add category. Budget editing belongs to the budget card.
- A cost always requires a category. It may optionally use either an Aarast
  provider or an external party; payment entry never asks for category or party
  again because those values are inherited from the selected cost.
- Accepting a valid plan-scoped quote creates exactly one linked `WeddingCost`
  automatically with `paidAmount = 0`. It does not create a payment, payment
  schedule, wedding task, or confirmed booking.
- A payment schedule requires a date and remains a reminder until paid.
- A missing general budget must render as unset, not zero and not the sum of
  category allocations.
- Keep route guards honest for guest, account, provider, permission, and
  feature-disabled states.
- Do not introduce payment, deposit, confirmed booking, AI, FinTech, or open
  unsolicited messaging behavior.
