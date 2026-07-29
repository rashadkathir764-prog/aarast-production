# Admin Web

Snapshot date: 2026-07-17

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
recovery UI. They also enforce the shared accessible pagination control and its
use by every paginated admin list. `npm test` runs in CI on every push.

A top-level `ErrorBoundary` (`src/components/ErrorBoundary.tsx`) wraps
the app so a render-time exception shows a recoverable Arabic message
instead of a blank screen.

Admin authentication is a two-step password + phone OTP flow. The access JWT
lives only in JavaScript memory; neither `localStorage` nor `sessionStorage`
contains session material. Reload recovery and one guarded `401` retry use the
rotating path-scoped HttpOnly refresh cookie. Logout calls the backend before
clearing memory. Production therefore requires HTTPS, the configured admin/API
same-site origins, and a working WhatsApp OTP channel.

The login page also provides an enumeration-safe administrator recovery flow.
It always shows the same neutral request result, accepts the six-digit WhatsApp
code and a strong password containing an English letter and digit (12
characters, at most 72 UTF-8 bytes), clears secrets on cancel/success,
does not create a session automatically, and returns to normal password + OTP
login after the backend revokes prior sessions. This recovery changes only the
browser-administration password; it cannot overwrite the wedding-app password.

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
| `/providers` | Providers | Active/suspended provider directory by default |
| `/providers/applications` | Provider Applications | Pending/change-requested/rejected applications by default |
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

## List Pagination

Users, provider applications, providers, services, reviews, conversation
reports, and notifications request 20 rows per page and render the backend
`page`, `limit`, `total`, and `totalPages` metadata through one RTL control.
Changing a filter or submitting a new search returns to page 1. If an action
removes the last row on the current page, the screen clamps to the last valid
page instead of showing a stranded empty result. Catalog city/category lists
remain intentionally unpaginated reference sets.

Provider moderation is independently reviewed: an administrator cannot perform
any review transition on a provider profile owned by that same account.
The backend and UI share one lifecycle matrix: application states expose only
approve/request-changes/reject where valid, `ACTIVE` exposes suspend, and
`SUSPENDED` exposes activate. A suspended provider never shows both approve and
activate. Provider status changes create a durable notification for the owner.

Provider category create/edit also exposes two explicit customer-audience
flags: groom and bride. A category may appear in either path or both, but the UI
does not submit a category hidden from both. This changes discovery only; the
provider catalog itself remains one shared source.

List summary cards distinguish complete filtered totals from counts derived
only from the current 20-row page. Page-local cards are labeled
`في الصفحة`; they must not be presented as full-dataset statistics.
