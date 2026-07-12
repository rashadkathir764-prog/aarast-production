# Decisions

## Current Decisions Addendum - 2026-06-14

| Decision | Status | Rationale |
| --- | --- | --- |
| Treat Flutter SQLite as a mobile cache/sync layer only. | Accepted | PostgreSQL remains the backend source of truth; SQLite supports offline UX and selected queued writes without storing credentials or replacing server data. |
| Keep provider marketplace work as planning/reference and quote-lead flows. | Accepted | Provider listings, favorites, reviews, quote requests, provider dashboard, and admin approval exist, but paid booking, deposits, payment status, and financing remain excluded. |
| Split production domains only after Compose/Dokploy/NPM are aligned. | Accepted | Current Dokploy Compose has backend on `8093` and admin-web on `8094`. A separate Flutter web service on `8095` is not configured in the committed production Compose file. |
| Meta WhatsApp OTP has a production channel, while external activation remains pending. | Accepted and implemented in code | The backend sends approved authentication templates through Meta Cloud API, never echoes production codes, and fails boot on incomplete channel configuration. Live activation still requires Meta business/template approval and real secrets outside Git. |

## Current Decisions Addendum - 2026-07-06

| Decision | Status | Rationale |
| --- | --- | --- |
| Allow conversations only when attached to a real quote request. | Accepted | Messaging is limited to the requester and the provider account on that quote. Open or unsolicited messaging remains excluded. |
| Make `FinancialCommitment` the only obligation backbone of the money tab. | Accepted and implemented | Every agreed amount must belong to a budget category. Provider/service costs, manual payables, payment records, and financial installments attach to that commitment model. The former `Debt`/`Installment` models, routes, bridge fields, Flutter feature, and caches were removed before launch because there are no production users. |
| Calculate confirmed financial exposure without dropping or duplicating money-out records. | Accepted and implemented | Confirmed cost is the sum of standalone paid `Expense` rows and active commitment totals. Payments under a commitment update its paid balance but do not add its cost again. Remaining budget and category risk use this same exposure definition. |
| Use short-lived access tokens with rotating refresh tokens. | Accepted and implemented | Access JWTs default to 15 minutes. Opaque 30-day refresh tokens are hashed at rest, rotated transactionally, and revocable per session or per user. |
| Keep one active documentation source per area. | Accepted | `docs/README.md` owns the source map. Historical plans and reports live as `.md.txt` under `docs/archive/` and must not compete with current docs. |

## Current Decisions Addendum - 2026-07-10

| Decision | Status | Rationale |
| --- | --- | --- |
| Require verified phone ownership before account or invite access. | Accepted and implemented | Registration creates no User/session before OTP completion; legacy unverified sessions are revoked and JWT/refresh/password login remain blocked until phone proof. |
| Persist invite-token fingerprints and enforce delegated permission ceilings. | Accepted and implemented | Raw external tokens exist only in the create response, invite consumption is atomic, and a delegated inviter cannot grant effective authority above their own. Email-only invites remain disabled until verified-email identity exists. |
| Scope Flutter state by account and selected plan. | Accepted and implemented | Account identity changes dispose the complete data-provider subtree; plan changes replace plan-sensitive providers without rebuilding navigation. Late responses from disposed providers cannot repopulate another session. |
| Bind offline replay to its originating session. | Accepted and implemented | Replay captures the cache owner, session generation, and access token. Logout or account change stops the old loop, prevents the new token from authorizing an old write, and restarts only the new account queue. |
| Keep guest budget optional through dashboard entry. | Accepted and implemented | Saving an empty quick-setup budget records an explicit skip; completion accepts a budget or that skip, and legacy saved no-budget plans are upgraded while loading. |
| Fail mobile Release closed. | Accepted and implemented in source | Product builds require an explicit public HTTPS API origin, reject development login bypass, and Android refuses missing/placeholder/nonexistent signing configuration instead of falling back to debug keys. iOS runs the equivalent API gate before its Flutter build. |
| Keep native launch identity consistent with the live design system. | Accepted and implemented | Android adaptive/legacy icons and splash plus iOS AppIcon/LaunchImage use the same burgundy, gold, ivory, and celebration-spark mark as the in-app brand. Generated sizes are tested, while final store and device review remains a release gate. |
| Separate liveness from readiness. | Accepted and implemented | `/live` and `/health` prove only that the process responds; `/ready` verifies PostgreSQL and required Redis/media dependencies with bounded timeouts and redacted failures. Production containers use readiness before receiving dependent traffic. |
| Use a transactional PostgreSQL outbox before adding an external broker. | Accepted and implemented | Notification and chat availability events commit with their domain rows. Workers use `FOR UPDATE SKIP LOCKED`, stale-lock recovery, bounded retries, failed-event retention, metrics, and alerts. Immediate Socket.IO delivery remains the low-latency path; outbox availability events repair commit-to-publish crashes. |
| Bind and expire idempotency keys. | Accepted and implemented | A user key is valid only for one method, concrete target, and canonical body. Identical retries replay safely, mismatches return `409`, pending reservations and completed responses have bounded lifetimes, and cleanup uses a cross-replica PostgreSQL advisory lock. |
| Require password + phone OTP and server-bound browser sessions for administration. | Accepted and implemented | General login paths cannot mint admin assurance. Access tokens stay in memory, refresh tokens stay in rotating HttpOnly/SameSite cookies, each admin JWT references a live server session, and refresh/logout invalidate the prior JWT immediately. |

## Current Decisions Addendum - 2026-07-12

| Decision | Status | Rationale |
| --- | --- | --- |
| Allow a temporary hardened OpenWA OTP transport for the risk-accepted MVP, while retaining Meta as the target channel. | Accepted and locally verified; limited rollout gates remain | Aarast never calls stock `send-text`, applies durable HMAC-keyed phone/IP/global quotas, and fails readiness unless a connected session exposes the transient contract. The pinned fork, QR link, no-persistence proof, protected restart, and live self-recipient request/verify flow pass. An independently owned second recipient and 24-hour stability observation remain mandatory before widening the MVP rollout. |

## Initial Project Decisions

| Decision | Status | Rationale |
| --- | --- | --- |
| Use Flutter for the mobile app. | Accepted | Flutter supports cross-platform mobile delivery with a single codebase. |
| Use NestJS for the backend. | Accepted | NestJS provides a structured TypeScript backend suitable for modular API development. |
| Use PostgreSQL for the database. | Accepted | PostgreSQL is reliable for relational planning, marketplace, and financial records. |
| Use Git worktree workflow. | Accepted | Worktrees support isolated branches and safer phase-based development, but actual worktree usage must wait until the correct Git repository root is confirmed. Do not run git init, create branches, or create worktrees during Docs Foundation. |
| Run smoke tests before expanding core features. | Accepted | Smoke checks help confirm foundations are stable before more work is added. |
| MVP starts with Wedding Financial OS, not marketplace-first. | Accepted | The primary user problem is planning, money, obligations, and coordination. |
| Do not implement confirmed bookings, deposits, payment status, payment processing, loans, credit, financing flows, or FinTech features in MVP. | Accepted | These flows require later validation, privacy review, legal review, operational readiness, and explicit approval before implementation. |
| Financial data is private by default. | Accepted | Financial commitments, payment records, expenses, installments, attachments, and private tasks must not be visible to shared members unless permissions explicitly allow it. |
| Early provider/service features are planning references and quote/lead flows only. | Accepted | The MVP must not become marketplace-first, paid booking, confirmed reservation, or deposit-driven. |
| Phase 3 readiness order is Prisma + PostgreSQL, User, Auth, ownership context, then WeddingPlan. | Accepted | WeddingPlan ownership must be backed by persistence and real authenticated user context before domain implementation begins. |
| Do not use mock-auth shortcuts for WeddingPlan ownership. | Accepted | Ownership and privacy behavior must not be validated against fake or temporary identity assumptions. |
| MVP User model shape is minimal and phone-aware. | Accepted | The initial User design includes `id`, `name`, `phone`, `email`, `passwordHash`, `role`, `status`, `createdAt`, and `updatedAt`; phone matters for Yemen-first usage and `passwordHash` stores hashed passwords only. |
| Initial User roles are USER, ADMIN, and PROVIDER. | Accepted | `PROVIDER` is reserved for later provider flows and must not trigger provider logic in the User model slice. |
| Initial User statuses are ACTIVE and DISABLED. | Accepted | The MVP needs a simple account availability state before richer lifecycle rules are introduced. |
| Ownership checks use authenticated user context. | Accepted | Future private modules must compare resource `ownerUserId` with the authenticated user id before returning or mutating private data; this prepares WeddingPlan without creating it yet. |
| Shared access is explicit and permission-based. | Accepted | Shared members may collaborate on a WeddingPlan, but financial visibility and task management must be granted through explicit SharedMember permissions; private financial data remains hidden by default. |
| Docs Foundation is documentation-only. | Accepted | The current phase may create or update Markdown files only and must not create app code, backend modules, Flutter screens, tests, migrations, Docker files, or deployment configs. |
| Use Docker for local service isolation and reproducible runtime environments. | Accepted | Docker is an operations decision for consistent local services and runtime behavior; it is not an implementation task in the current documentation phase. |
| Use Dokploy for VPS deployment and operations. | Accepted | Dokploy is the approved production deployment path. The current Compose runbook lives in `deploy/dokploy/`, using backend host port `8093`, admin host port `8094`, `PORT=3000`, `CORS_ORIGINS=https://aarast.shadowgardn.com,https://aarast-admin.shadowgardn.com`, and `VITE_API_BASE_URL=https://aarast-api.shadowgardn.com`. |

## Deferred Decisions

- Final mobile UI structure.
- Final admin dashboard implementation details.
- Final database schema and migration sequence.
- AI planning approach.
- Payment, installment, savings, or financing partnerships.
- Confirming the actual Git repository root.
- Permission model details for shared members.
- Attachment storage implementation.
- Exact persistence package/setup sequence.
- Exact User model constraints, indexes, and uniqueness rules.
