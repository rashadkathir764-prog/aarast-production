# Project Phases

## Current Phase Reality - 2026-06-14

The repository has progressed past the original docs foundation:

| Phase area | Current status |
| --- | --- |
| Backend foundation | DONE |
| Wedding Financial OS backend | DONE for current MVP modules |
| Flutter MVP planning flows | DONE for current core flows |
| Provider references and quote leads | DONE as planning/reference flows, not paid bookings |
| Provider dashboard and admin approval | DONE for current backend/admin-web workflow |
| Mobile SQLite offline cache/sync queue | DONE for selected safe mobile workflows |
| Dokploy deployment | IN PROGRESS/PARTIAL: API and current admin domain respond, but target admin/mobile domain split is not fully represented in Compose |
| Marketplace expansion | PARTIAL: references, quote requests, favorites, reviews, and provider/admin operations exist; marketplace optimization is still future |
| AI and FinTech | NOT STARTED |

Continue to treat payment processing, confirmed booking/deposit flows, loans, credit, financing, AI, and internal chat as future work requiring explicit approval.

## Phase 0: Documentation And Smoke-Test Foundation

Goal: Define the product, scope, technical plan, phase boundaries, and test expectations before expanding implementation.

Scope:
- Root Markdown documentation.
- Product vision.
- MVP scope.
- Planned database and API modules.
- Deployment planning for Docker and Dokploy.
- Testing and smoke-test strategy.
- Git worktree workflow.
- AI-agent rules.

Expected output:
- Documentation files at the project root.
- Clear MVP boundaries.
- Planning-only deployment documentation.
- Clear PASS/FAIL smoke-test reporting expectations.

Acceptance criteria:
- All required Markdown files exist.
- Documentation states that no code implementation belongs to this phase.
- MVP is positioned as Wedding Financial OS first.
- Future marketplace, AI, and FinTech work are deferred.
- Docker and Dokploy are documented as future operations choices only; no Dockerfile, docker-compose, or Dokploy configuration is created in this phase.

## Phase 1: Backend Foundation

Goal: Establish the NestJS backend foundation and database connection without building broad product features.

Scope:
- NestJS project structure.
- PostgreSQL configuration.
- Prisma or database access foundation if selected.
- Auth foundation if included in the approved scope.
- Basic health and smoke-check endpoints.

Expected output:
- Backend can start locally.
- Database configuration is isolated to Aarast.
- Critical setup checks are documented.

Acceptance criteria:
- Backend build passes.
- Basic tests pass.
- Health or equivalent smoke check passes.
- No Flutter, payment, AI, or unrelated modules are added.

## Phase 2: Existing Units Smoke-Test Baseline

Goal: Validate existing critical units before adding new product scope.

Scope:
- Auth.
- Cities.
- Categories.
- Services.
- Bookings if already present.
- Favorites.
- Reviews.
- Provider Profile.
- Smoke-test reporting for each validated unit.

Expected output:
- A PASS/FAIL smoke-test baseline for existing critical units.
- Clear notes about broken, missing, or unstable units.
- A stable foundation for the Wedding Financial OS backend MVP.

Acceptance criteria:
- Auth, Cities, Categories, Services, existing Bookings, Favorites, Reviews, and Provider Profile are smoke tested.
- The phase does not expand marketplace features.
- Any failed checks are documented before new feature work begins.

## Phase 3: Wedding Financial OS Backend MVP

Goal: Build the core backend MVP for wedding financial planning before marketplace expansion.

Scope:
- Backend persistence readiness needed for WeddingPlan data.
- Authenticated user context needed for WeddingPlan ownership.
- Readiness order: Prisma + PostgreSQL foundation, User model, Auth foundation, ownership context, then WeddingPlan module.
- WeddingPlan.
- BudgetCategory.
- Expense.
- Debt.
- Installment.
- Task.
- SharedMember.
- Due dates and basic timeline visibility.
- Permissions and ownership rules.
- Privacy-aware access for groom, bride, and family collaboration.

Expected output:
- Backend APIs and data behavior for the Wedding Financial OS MVP.
- Users can manage the financial and task structure of a wedding.
- Shared members can collaborate according to permissions and privacy boundaries.

Acceptance criteria:
- Phase 3 begins with persistence and authenticated ownership readiness before implementing the WeddingPlan module.
- Persistence/Auth readiness follows the approved order: Prisma + PostgreSQL foundation first, User model second, Auth foundation third, ownership context fourth, and WeddingPlan after those prerequisites.
- WeddingPlan ownership must use real authenticated user context; no mock-auth shortcut is accepted for ownership behavior.
- Production migrations, Docker, Docker Compose, Dokploy, and deployment configuration are outside the Persistence/Auth readiness planning task.
- WeddingPlan is the first Wedding Financial OS domain module after those prerequisites are in place.
- The first WeddingPlan slice is limited to owner, title, city, wedding date, estimated budget, currency, status, and timestamps.
- SharedMember, BudgetCategory, Expense, Debt, Installment, and Task are not part of the first WeddingPlan slice.
- WeddingPlan, BudgetCategory, Expense, Debt, Installment, Task, SharedMember, due dates, permissions, and privacy-aware access pass smoke checks.
- Ownership and authorization tests cover private wedding-plan data.
- Sensitive financial details, debts, installments, and private tasks are not exposed to the wrong shared members.
- No payment, confirmed deposit, AI, or FinTech implementation is introduced.

## Phase 4: MVP Flutter Mobile Experience

Goal: Build the minimum Flutter experience needed to validate the Wedding Financial OS.

Scope:
- Login/session flow.
- Wedding plan dashboard.
- Budget and expenses views.
- Debts and installments views.
- Tasks and due dates view.
- Shared member visibility with privacy-aware access.
- Clean, usable, Arabic-first MVP interface.

Expected output:
- A usable mobile MVP for core planning flows.

Acceptance criteria:
- Critical flows work against the backend.
- Manual QA passes on core user journeys.
- Screens remain focused on MVP planning flows.
- Advanced Flutter animations and premium UI polish are deferred.

## Phase 5: Basic Provider References And Quote Leads

Goal: Add limited provider/service support only where it helps wedding planning context.

Scope:
- Provider and service references for planning.
- Packages as planning references.
- Quote requests.
- Booking leads only.
- Saved providers/services for comparison.

Expected output:
- Users can reference providers and request quotes in the context of a real wedding plan.
- Provider/service data supports planning without becoming a full marketplace.

Acceptance criteria:
- Provider/service work is limited to planning references, quote requests, and booking leads.
- Payment processing is excluded.
- Confirmed deposits are excluded.
- Full marketplace optimization is excluded.
- Smoke tests cover affected provider-reference and quote-lead flows.

## Phase 6: Marketplace Expansion

Goal: Expand into a real marketplace only after the financial planning MVP is stable.

Scope:
- Rich vendor/service discovery.
- Package improvements.
- Booking workflow improvements.
- Review improvements.
- Marketplace search, filtering, and ranking.
- Admin marketplace operations.

Expected output:
- Users can compare and engage vendors after their wedding financial plan is already useful and stable.

Acceptance criteria:
- The Wedding Financial OS MVP remains stable.
- Marketplace flows do not weaken privacy, permissions, or financial planning behavior.
- Smoke tests cover new marketplace units.
- Any payment or deposit behavior still requires explicit later approval.

## Phase 7: AI And FinTech Exploration

Goal: Explore AI assistance and financial partnerships only after the core MVP proves useful.

Scope:
- AI planning suggestions.
- Smart reminders.
- Vendor matching concepts.
- Payment, savings, installment, or financing partnership concepts.
- Research notes, proposals, or isolated prototypes.

Expected output:
- Research-backed proposals or isolated prototypes.

Acceptance criteria:
- AI and FinTech remain exploration, proposals, or prototypes only unless explicitly approved later.
- No production AI or FinTech feature ships without explicit approval.
- Privacy, consent, financial-risk, and legal concerns are documented first.

## Phase 8: Deployment Readiness

Goal: Prepare Docker and Dokploy implementation only after the backend and mobile MVP foundations are stable.

Scope:
- Dockerfile planning and implementation when explicitly approved.
- Docker Compose planning and implementation when explicitly approved.
- Dokploy VPS deployment configuration when explicitly approved.
- Environment variable documentation.
- Domain, database, storage, backups, logs, monitoring, and rollback planning.

Expected output:
- A documented deployment runbook.
- Verified local runtime isolation.
- A reviewed Dokploy deployment path for VPS operations.

Acceptance criteria:
- Backend and mobile MVP foundations are stable before deployment implementation begins.
- Docker, Docker Compose, and Dokploy files are created or modified only in an explicitly approved deployment task.
- Production deployment documents environment variables, domains, database, storage, backups, logs, and rollback.
- Smoke checks pass after deployment setup is introduced.
