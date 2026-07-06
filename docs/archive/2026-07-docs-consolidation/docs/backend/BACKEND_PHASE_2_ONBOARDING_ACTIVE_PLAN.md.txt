# Backend Phase 2 - Onboarding Active Plan

Date: 2026-06-19
Status: Implemented

## Scope

Phase 2 completes the authenticated backend path for:

1. Completing onboarding.
2. Creating a real `WeddingPlan`.
3. Creating selected budget categories as real `BudgetCategory` rows.
4. Setting the created plan as the user's active plan.
5. Listing plans accessible to the current user as owner or shared member.

No guest-local storage, Flutter UI, admin-web behavior, payments, deposits, maps, AI, push, or production configuration was changed.

## Endpoints

New `/api/v1` compatibility endpoints:

- `GET /api/v1/me`
- `GET /api/v1/wedding-plans`
- `POST /api/v1/wedding-plans`
- `GET /api/v1/wedding-plans/active`
- `POST /api/v1/wedding-plans/:id/set-active`
- `POST /api/v1/onboarding/complete`

Unprefixed backend endpoints remain available for existing clients:

- `GET /me`
- `GET /wedding-plans`
- `POST /wedding-plans`
- `GET /wedding-plans/active`
- `POST /wedding-plans/:id/set-active`
- `POST /onboarding/complete`
- Existing `/auth/me` and `/wedding-plans/my` behavior is preserved.

## Data Model

Migration:

- `backend/prisma/migrations/20260619121203_add_onboarding_active_plan/migration.sql`

Schema additions:

- `OnboardingPath`: `USER`, `PROVIDER`
- `WeddingPersona`: `GROOM`, `BRIDE`, `HELPER`
- `User.activeWeddingPlanId`
- `User.onboardingPath`
- `User.persona`
- `User.onboardingCompletedAt`
- `WeddingPlan.location`
- `WeddingPlan.priorities`
- `WeddingPlan.onboardingPath`
- `WeddingPlan.persona`
- `WeddingPlan.onboardingCompletedAt`
- `WeddingPlan_ownerUserId_status_idx`

## Rules Implemented

- JWT is required for all new Phase 2 endpoints.
- Users can list only plans they own or plans shared with them.
- `complete onboarding` creates a real wedding plan in the database.
- `complete onboarding` sets the new plan as the user's active plan.
- `selectedCategories` creates real `BudgetCategory` rows.
- Setting another user's plan as active is blocked by the existing plan access guard.
- Negative `estimatedBudget` is rejected.
- Invalid `weddingDate` is rejected.
- No fake `planId` or fake dashboard data is generated.

## Smoke Coverage

Added:

- `npm run smoke:onboarding-active-plan`

Included in:

- `npm run smoke:all`

Covered cases:

- Register user.
- Read `/api/v1/me`.
- Active plan is empty before onboarding.
- Complete onboarding creates a plan.
- Active plan is set after onboarding.
- Selected categories are persisted.
- Accessible plans include the onboarding plan.
- A second plan can be set active.
- Negative budget returns `400`.
- Missing token returns `401`.

## Verification

Commands run successfully:

- `npx.cmd prisma format`
- `npx.cmd prisma validate`
- `npx.cmd prisma migrate dev --name add_onboarding_active_plan`
- `npm.cmd run check`
- `npm.cmd run smoke:onboarding-active-plan`
- `npm.cmd run smoke:all`
- `git diff --check`
- `git diff --cached --check`

Local database note:

- Prisma migration initially failed because local role `aarast_user` could not create the shadow database.
- The local Docker Postgres role was granted `CREATEDB` to allow `prisma migrate dev` to run.
- No Docker, deployment, or production configuration files were changed.

## Known Notes

- `GET /api/v1/wedding-plans/active` returns no body when no active plan exists because Nest serializes `null` that way in this app runtime. The smoke treats this as an empty active plan state.
- Provider path is accepted as onboarding metadata, but provider mode behavior remains separated for later backend phases.
