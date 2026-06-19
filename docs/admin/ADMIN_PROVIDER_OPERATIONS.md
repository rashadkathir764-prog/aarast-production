# Aarast Admin & Provider Operations

Date: 2026-06-19
Stage: Admin & Provider Operations
Status: Planning document only

## 1. Decision

No real marketplace launch without admin control over provider applications, statuses, categories, cities, reports, and disputes.

Provider mobile features must remain planning/reference and quote-lead flows until operations are ready.

## 2. Provider Lifecycle

Required statuses:

- draft.
- pending_review.
- needs_changes.
- approved.
- verified.
- suspended.
- rejected.

Current Prisma has:

- `PENDING`
- `ACTIVE`
- `NEEDS_CHANGES`
- `SUSPENDED`
- `REJECTED`

Mapping:

- `PENDING` -> pending_review.
- `ACTIVE` -> approved.
- verified needs future flag/status.

## 3. Admin Must Manage

- Provider applications.
- Provider approval/rejection.
- Provider suspension.
- Provider verification.
- Provider review notes.
- Cities and service areas.
- Provider categories.
- Services/packages moderation.
- Quote request overview.
- Reports and complaints.
- Support/disputes.
- Public content templates later.

## 4. Provider Dashboard Rules

Provider can:

- View profile status.
- Complete profile.
- Manage services/packages if approved/active.
- View quote requests sent to them.
- Update quote request status within allowed lifecycle.

Provider cannot:

- See full wedding plan.
- See private finance data.
- Confirm paid booking.
- Collect deposit/payment through MVP.
- Override admin review.

## 5. Admin Review Rules

Approval checklist:

- Business name.
- Owner/contact name.
- Phone/WhatsApp.
- City/service areas.
- Category.
- Description.
- Basic quality/safety review.

Rejection/needs changes must include Arabic note.

## 6. Dispute/Support Needs

Future operations need:

- Report provider.
- Report wrong information.
- Dispute quote.
- User complaint.
- Provider complaint.
- Admin review status.
- Support contact record.

## 7. Acceptance Criteria

- Provider lifecycle is documented.
- Admin responsibilities are documented.
- Provider dashboard permissions are documented.
- Admin review checklist is documented.
- Support/dispute needs are documented.
- No admin-web or backend code is changed.

## 8. Risks

- Marketplace without admin review can expose low-quality providers.
- Provider status copy can promise approval incorrectly.
- Confirmed booking/payment language can violate MVP boundary.
- Support/dispute operations need legal/privacy planning.

## 9. Next Implementation Notes

- Next stage: `docs/content/ARABIC_COPY_MATRIX.md`.
- Provider implementation must remain feature-flagged where operations are incomplete.

