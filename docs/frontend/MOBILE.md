# Mobile

Snapshot date: 2026-07-17

The mobile app is a Flutter Arabic-first Wedding Financial OS client. Current
product scope includes auth, onboarding, home/dashboard, one money system,
tasks, guests, sharing, notifications, providers/quotes, settings, support,
offline/cache behavior, the five-tab provider portal, quote-scoped
conversations, signed image uploads, and rotating refresh sessions.

## Current Direction

- Arabic-first and RTL-safe.
- Wedding Financial OS first.
- Money uses five user-facing terms only: `الميزانية`, `التصنيف`, `التكلفة`,
  `الدفعة`, and `موعد الدفع`.
- Provider flows use a dedicated five-tab portal: Home, Requests, Services,
  Messages, and Profile.
- The approved messaging design starts only from a real quote request and
  remains an account-backed online action.
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
  and are removed; plan selectors may remain there because they contain no
  profile, contact, or financial payload.
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
- Premium-screen work is active and tracked in `docs/frontend/PREMIUM_ROADMAP.md`.
- Product builds require a public HTTPS API origin and cannot enable the
  development login bypass. Android refuses debug signing for Release.
- Canonical invitation links are
  `https://aarast.shadowgardn.com/invites/TOKEN` and
  `aarast://open/invites/TOKEN`. The create-invite flow keeps the one-time raw
  token in screen memory only and offers manual WhatsApp delivery or copy-link
  without routing invitations through the OTP/OpenWA service. The public HTTPS
  landing exposes generic Open Graph metadata only; names, dates, permissions,
  and plan details remain hidden until authenticated phone verification.
  Deployed association files and physical-device validation remain release
  requirements.
- Native Android/iOS launcher and splash assets use the current Aarast brand
  mark rather than Flutter defaults.

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
- Accepted quote data may prefill the cost form only after explicit user
  confirmation. Quote acceptance alone never creates money data.
- A payment schedule requires a date and remains a reminder until paid.
- A missing general budget must render as unset, not zero and not the sum of
  category allocations.
- Keep route guards honest for guest, account, provider, permission, and
  feature-disabled states.
- Do not introduce payment, deposit, confirmed booking, AI, FinTech, or open
  unsolicited messaging behavior.
