# Backend Phase 8 - Providers and Quote Requests

Date: 2026-06-19
Status: Implemented

## Scope

Phase 8 completes provider and quote backend support for the mobile UX without payments or confirmed bookings:

- `/api/v1` provider listing aliases
- `/api/v1` provider profile basics
- provider service create/update/delete aliases
- plan-scoped quote request APIs
- provider quote request APIs
- quote offer create/update
- quote offer accept/reject
- plan-provider linking after accepted offer

No payment processing, deposits, subscriptions, booking confirmation, Flutter UI, admin-web code, AI, push, maps, or production configuration was changed.

## Migration

Created:

- `backend/prisma/migrations/20260619130835_add_quote_offers_plan_provider_links/migration.sql`

Schema additions:

- `QuoteOfferStatus`
- `PlanProviderLinkStatus`
- `QuoteOffer`
- `PlanProviderLink`
- relations from `Provider`, `QuoteRequest`, and `WeddingPlan`

## Endpoints

Public `/api/v1` endpoints:

- `GET /api/v1/providers`
- `GET /api/v1/providers/:id`
- `GET /api/v1/provider-categories`

Provider profile endpoints:

- `GET /api/v1/provider/me`
- `POST /api/v1/provider/profile`
- `PATCH /api/v1/provider/profile`
- `POST /api/v1/provider/services`
- `PATCH /api/v1/provider/services/:id`
- `DELETE /api/v1/provider/services/:id`

User quote endpoints:

- `POST /api/v1/wedding-plans/:planId/quote-requests`
- `GET /api/v1/wedding-plans/:planId/quote-requests`
- `GET /api/v1/quote-requests/:id`
- `PATCH /api/v1/quote-requests/:id/cancel`
- `PATCH /api/v1/quote-offers/:id/accept`
- `PATCH /api/v1/quote-offers/:id/reject`

Provider quote endpoints:

- `GET /api/v1/provider/quote-requests`
- `GET /api/v1/provider/quote-requests/:id`
- `POST /api/v1/provider/quote-requests/:id/offers`
- `PATCH /api/v1/provider/quote-offers/:id`

Existing unprefixed marketplace and provider dashboard endpoints remain available.

## Rules

- Public provider listing still returns active providers only.
- Provider profile creation starts with the existing `PENDING` review state.
- Quote requests require an accessible wedding plan when created through plan-scoped APIs.
- Providers only see quote requests addressed to their own provider profile.
- Providers can create and edit pending offers only.
- Accepting an offer marks it `ACCEPTED`, rejects other pending offers for the same quote, marks the quote request `ACCEPTED`, and upserts a real `PlanProviderLink`.
- Rejecting an offer marks that offer `REJECTED`.
- No deposits, payments, booking confirmation, or booking status transition was added.

## Dashboard Impact

`GET /api/v1/wedding-plans/:planId/dashboard-summary` now calculates `providerCount` from real `PlanProviderLink` rows created by accepted quote offers.

## Smoke Coverage

Added:

- `npm run smoke:providers-quotes`

Included in:

- `npm run smoke:all`

Covered cases:

- provider profile create/read/update
- provider service create/update/delete
- public provider categories/list/detail aliases
- plan quote request create/list/detail
- provider quote request list/detail
- offer create/update
- offer accept creates plan-provider link
- dashboard provider count after accepted offer
- accepted offer cannot be edited
- second offer reject flow
- unrelated user blocked from plan quote list
- unauthenticated provider quote list blocked

## Verification

Expected commands for this phase:

- `npx.cmd prisma format`
- `npx.cmd prisma validate`
- `npx.cmd prisma migrate dev --name add_quote_offers_plan_provider_links`
- `npm.cmd run check`
- `npm.cmd run smoke:providers-quotes`
- `npm.cmd run smoke:all`
- `git diff --check`
- `git diff --cached --check`
