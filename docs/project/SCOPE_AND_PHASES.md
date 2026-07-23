# Scope And Phases

Snapshot date: 2026-07-23

This is the compact phase source. Older phase files were archived during the
2026-07 documentation consolidation.

## Active Scope

Current implemented scope includes:

- Auth, profile, OTP helpers, and settings.
- WeddingPlan ownership and active-plan flows.
- Dashboard summary.
- One optional general budget, budget categories, `WeddingCost`, `CostPayment`,
  `PaymentSchedule`, and one canonical money summary.
- Tasks, checklists, assignments, and timeline.
- Guests and guest groups.
- Sharing, invites, roles, and permissions.
- Notifications.
- Provider references, quote requests/offers, favorites, reviews, services,
  packages, provider dashboard operations, and city/category catalog.
- Admin dashboard APIs and admin web operations.
- Flutter mobile flows for the planning, money, task, sharing, provider, and
  account surfaces.
- Mobile SQLite/offline cache and selected sync queue behavior.
- Five-tab provider portal and unified plan/provider or account/provider
  conversation UI.
- Quote-started conversations with multiple requests per conversation, unified
  message/system-event timeline, real-time delivery, unread/read state, mute,
  side-level block, reporting, and admin moderation.
- Signed provider, avatar, and chat media upload with full server-side image
  decode/sanitize/re-encode before persistence, durable ownership tickets,
  account quota, and abandoned-upload cleanup.
- Rotating refresh sessions and mobile single-retry behavior.

## Release Validation In Flight

The integrated provider portal, conversation/media, and refresh-session slices
have local Compose/MinIO-backed smoke coverage. A release claim still requires
the matching deployed environment plus signed physical-device reconnect,
secure-storage, and session QA.

## Current Phase Discipline

- Keep route-level backend details in `docs/backend/API_CONTRACT.md`.
- Keep deployment details in `docs/deployment/`.
- Keep mobile rebuild and premium-screen implementation work in
  `docs/frontend/`.
- Do not implement future-phase features early.
- Do not create backend, Flutter, admin, deployment, migration, or package
  changes from a documentation task.

## Later Phases

Later phases may explore a larger marketplace, production AI, or FinTech only
after explicit approval. Those areas are not current MVP behavior.
