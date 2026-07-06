# Mobile

Snapshot date: 2026-07-05

The mobile app is a Flutter Arabic-first Wedding Financial OS client. Current
source includes auth, onboarding, home/dashboard, money, debts, installments,
tasks, guests, sharing, notifications, providers/quotes, settings, support, and
offline/cache behavior, the five-tab provider portal, quote-scoped
conversations, signed image uploads, and rotating refresh sessions.

## Current Direction

- Arabic-first and RTL-safe.
- Wedding Financial OS first.
- Provider flows use a dedicated five-tab portal: Home, Requests, Services,
  Messages, and Profile.
- The approved messaging design starts only from a real quote request and
  remains an account-backed online action.
- Conversation/media actions remain online-only and never enter the wedding
  planning SQLite sync queue.
- Access and refresh tokens are stored securely; a failed authenticated API
  call receives at most one refresh-and-retry attempt.
- Guest/local planning can exist, but protected cloud/share/provider writes must
  remain account-gated.
- Premium-screen work is active and tracked in `docs/frontend/PREMIUM_ROADMAP.md`.

## Plan Management

- `إدارة الخطة` is the administrative profile for a wedding plan, not a second
  dashboard.
- It owns plan identity and date, structured wedding location, participants and
  permissions, saved preferences, data-completeness status, and supported plan
  administration.
- Tasks, money, guests, providers, quotes, debts, countdowns, and daily progress
  remain in the dashboard or their dedicated tabs.
- Copy, export, and delete actions stay hidden until their backend contracts are
  implemented. The current supported destructive action is archive.

## Implementation Rules

- Do not show fake counts, fake participants, or unsupported live actions.
- Do not expose private financial details to shared members without permission.
- Keep route guards honest for guest, account, provider, permission, and
  feature-disabled states.
- Do not introduce payment, deposit, confirmed booking, AI, FinTech, or open
  unsolicited messaging behavior.
