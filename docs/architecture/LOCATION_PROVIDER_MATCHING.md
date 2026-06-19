# Aarast Location & Provider Matching

Date: 2026-06-19
Stage: Location & Provider Matching
Status: Planning document only

## 1. Decision

Location is a product input, not a decorative form field. Aarast uses location to make the wedding plan locally relevant and to rank providers by practical proximity and service area.

Do not start with heavy maps. Start with Yemen-first structured location fields and optional coordinates later.

## 2. Current Data Reality

Current Prisma schema has:

- `WeddingPlan.city` as an optional string.
- `City` model with `nameAr`, `nameEn`, `countryCode`, `isActive`, `sortOrder`.
- `Provider.cityId`.
- `Provider.address`, optional `latitude`, `longitude`.
- `ProviderService.cityId`.
- `QuoteRequest.cityId`.

Current gaps:

- No governorate/district/neighborhood/street fields for a plan.
- No provider service-area table.
- No normalized location hierarchy beyond city.
- No explicit matching score.

## 3. Required Location Fields

Wedding plan location:

- governorate.
- city/district.
- neighborhood.
- street.
- address note.
- optional latitude later.
- optional longitude later.

Provider location:

- business city.
- business address.
- primary category.
- service areas.
- optional coordinates later.

Provider service area:

- providerId.
- governorate.
- city/district.
- neighborhood optional.
- service radius later if maps are approved.

## 4. Onboarding Location UX

The location step must:

- Ask for governorate and city first.
- Allow neighborhood/street details but not block progress unnecessarily.
- Offer "use my location later" only by explicit tap.
- Not request OS location permission on first launch.
- Save local guest location before account creation.

If location seed data is missing:

- Allow manual entry.
- Mark seed gap in Data Seeding Plan.

## 5. Provider Matching Rules

Provider ranking should use this order:

1. Same city/district as wedding plan.
2. Matching service area/neighborhood.
3. Matching selected budget category or provider category.
4. Active/approved provider status.
5. Verified provider status when available.
6. Budget fit when provider price exists.
7. Rating/review quality later.
8. Featured placement later only if monetization/ethics are approved.

Do not rank providers by:

- Paid placement in MVP.
- Fake distance.
- Unavailable map coordinates.
- Provider status that is not approved/active.

## 6. Provider List Behavior

When plan location exists:

- Providers tab defaults to plan city/area.
- User can broaden search manually.
- Empty state offers broader city/category reset.

When plan location is missing:

- Ask user to add city.
- Show broad active providers only if useful.
- Do not pretend matching is personalized.

When offline:

- Show cached providers if available.
- Clearly label if results may be stale.
- Quote request remains online/account-required.

## 7. Quote Request Location

Quote request should carry location context:

- weddingPlanId if available.
- cityId or structured city when schema supports it.
- event date.
- guest count.
- optional address note only if needed.

Privacy rule:

- Provider should receive only the location detail required to prepare quote.
- Exact street/address should not be exposed by default unless user chooses to include it.

## 8. Data Model Implications

Possible future schema:

- `Governorate`
- `District` or extended `City`
- `Neighborhood`
- `WeddingPlanLocation`
- `ProviderServiceArea`

Keep first migration small:

- Add structured location to plan.
- Add provider service areas.
- Preserve existing `City` data and route compatibility.

## 9. Acceptance Criteria

- Plan location fields are defined.
- Provider location/service area needs are defined.
- Matching/ranking rules are defined.
- OS location permission timing is defined.
- Offline/cached provider behavior is defined.
- Quote location privacy rules are defined.
- No schema, API, or mobile code is changed.

## 10. Risks

- Asking for precise location too early can reduce trust.
- Matching by only `WeddingPlan.city` will feel weak in large cities.
- Provider service areas without admin maintenance can become stale.
- Exact address sharing can create privacy risk.
- Paid/featured provider ranking should not enter MVP accidentally.

## 11. Next Implementation Notes

- Next stage: `docs/architecture/NOTIFICATIONS_BLUEPRINT.md`.
- Data Seeding Plan must define Yemen location seed order.
- Mobile Implementation Plan must decide first safe location UI slice.

