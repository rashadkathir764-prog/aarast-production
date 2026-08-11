# Admin Web

Snapshot date: 2026-08-11

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
use by every paginated admin list. Shared-component coverage also verifies
confirmation-dialog focus/keyboard behavior, named responsive data tables, and
labelled search landmarks. `npm test` runs in CI on every push.

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

## Modernization checkpoint

The Admin shell, dashboard, and login surface now use the shared semantic
vocabulary: visible location, operational hierarchy, quiet surfaces, one
primary action, and RTL-friendly responsive behavior. The login surface keeps
the password + phone OTP and recovery contracts unchanged, removes retired
ornamental branding, and was reviewed at wide desktop, 760px tablet, and 390px
phone widths. The shared confirmation dialog now traps and restores focus,
blocks dismissal while an operation is pending, and reports mutation failures.
All 12 current Admin tables use one token-based, labelled, horizontally
scrollable `DataTable`, and all current search filters expose a visible label
and named search landmark. The remaining management pages still require
migration onto the shared page-header, field, and state primitives.

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
| `/reference-catalogs` | Dynamic Catalogs | Draft, review, publish, rollback, audience targeting, and soft-disable |
| `/administrative-areas` | Yemen Administrative Areas | Governorate → district → area/isolation/neighborhood/zone management |

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

Dynamic catalog edits are draft-first. A saved edit does not reach mobile
users until an administrator explicitly publishes that revision. The page
also exposes historical revision selection for rollback and publishes an
inactive revision when an item is disabled. Administrative geography uses a
separate ordered hierarchy; child ownership and stable codes cannot be moved
after creation. All reads require `CATALOG_READ`, all writes require
`CATALOG_WRITE`, and the existing append-only admin audit interceptor records
every attempt and terminal outcome.

List summary cards distinguish complete filtered totals from counts derived
only from the current 20-row page. Page-local cards are labeled
`في الصفحة`; they must not be presented as full-dataset statistics.

## Latest Local Verification — 2026-08-11

- PASS — React Router `7.18.2`, TypeScript type-check, Vitest `96/96`, route
  smoke `16/16`, source-honesty smoke `12/12`, container runtime contract
  tests `3/3`, and production build.
- PASS — full `npm audit` reports zero findings after the tested React Router 7
  migration and transitive `nanoid` remediation.
- PASS — managed admin-runtime smoke against a disposable database after all 76
  migrations. It covered admin authentication/session rotation, private-field
  exclusion, catalog draft/publish/edit/rollback/disable, and governorate →
  district → locality create/visibility/soft-disable behavior.
- PASS — deployed Admin container at application revision
  `959c47b756d0bebc3e4e4fda5f81ae3349d05e62` was healthy with zero restarts and
  no OOM termination; external `/login` returned `200`, and Production had all
  76 migrations current. This proves deployment/runtime availability, not a
  completed real-OTP administrator login. OpenWA/Meta acceptance remains an
  external gate.
