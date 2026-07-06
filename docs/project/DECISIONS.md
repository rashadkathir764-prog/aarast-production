# Decisions

## Current Decisions Addendum - 2026-06-14

| Decision | Status | Rationale |
| --- | --- | --- |
| Treat Flutter SQLite as a mobile cache/sync layer only. | Accepted | PostgreSQL remains the backend source of truth; SQLite supports offline UX and selected queued writes without storing credentials or replacing server data. |
| Keep provider marketplace work as planning/reference and quote-lead flows. | Accepted | Provider listings, favorites, reviews, quote requests, provider dashboard, and admin approval exist, but paid booking, deposits, payment status, and financing remain excluded. |
| Split production domains only after Compose/Dokploy/NPM are aligned. | Accepted | Current Dokploy Compose has backend on `8093` and admin-web on `8094`. A separate Flutter web service on `8095` is not configured in the committed production Compose file. |
| Meta WhatsApp OTP remains pending. | Accepted | Backend OTP is provider-agnostic/local; production WhatsApp delivery requires official provider setup, business verification, secure secrets, and explicit approval. |

## Current Decisions Addendum - 2026-07-06

| Decision | Status | Rationale |
| --- | --- | --- |
| Allow conversations only when attached to a real quote request. | Accepted | Messaging is limited to the requester and the provider account on that quote. Open or unsolicited messaging remains excluded. |
| Use short-lived access tokens with rotating refresh tokens. | Accepted and implemented | Access JWTs default to 15 minutes. Opaque 30-day refresh tokens are hashed at rest, rotated transactionally, and revocable per session or per user. |
| Keep one active documentation source per area. | Accepted | `docs/README.md` owns the source map. Historical plans and reports live as `.md.txt` under `docs/archive/` and must not compete with current docs. |

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
| Financial data is private by default. | Accepted | Expenses, debts, installments, attachments, and private tasks must not be visible to shared members unless permissions explicitly allow it. |
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
