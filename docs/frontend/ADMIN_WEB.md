# Admin Web

Snapshot date: 2026-07-05

The admin web app is a React/Vite dashboard under `admin-web/`. It supports
admin-facing management for dashboard stats, users, catalog references,
providers, services, reviews, notifications, operational reports, and
conversation-report moderation through the backend admin APIs.

## Commands

From `admin-web/`:

```powershell
npm run build
npm run typecheck
npm test
npm run smoke:admin-runtime
npm run smoke:routes
npm run smoke:honesty
```

Unit tests run on Vitest + Testing Library (jsdom). They cover the auth
API (ADMIN role gating, error mapping, token storage), the `apiRequest`
client (bearer header, error extraction), and the `ErrorBoundary`
recovery UI. `npm test` runs in CI on every push.

A top-level `ErrorBoundary` (`src/components/ErrorBoundary.tsx`) wraps
the app so a render-time exception shows a recoverable Arabic message
instead of a blank screen.

## Rules

- Admin surfaces must reflect real backend capabilities.
- Do not leave visible admin actions pretending unsupported features exist.
- Conversation moderation is limited to reviewing user/provider reports; the
  admin UI does not impersonate participants or expose financial data.
- Do not add payment, deposit, financing, AI, open chat, or confirmed-booking
  admin behavior unless explicitly approved.

## Routes

| Path | Page | Notes |
| --- | --- | --- |
| `/` | Dashboard | Overview stats and quick actions |
| `/users` | Users | List and manage end users |
| `/providers` | Providers | Approved provider directory |
| `/providers/applications` | Provider Applications | Review pending provider signups |
| `/services` | Services | Provider service CRUD |
| `/reviews` | Reviews | Moderate provider reviews |
| `/notifications` | Notifications | Operational notifications |
| `/reports` | Reports | Operational reports from `/admin/reports/overview` |
| `/conversation-reports` | Conversation Reports | Review participant reports without exposing messages |
| `/categories` | Provider Categories | Catalog CRUD |
| `/cities` | Cities | Catalog CRUD |

## Conversation Reports Moderation

The moderation surface is limited to report lists and status changes. Admins
cannot read conversation contents, impersonate participants, or see financial
data through this page.
