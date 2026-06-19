# Aarast Support And Disputes Plan

Date: 2026-06-19
Stage: Legal / Support / Disputes
Status: Planning document only

## 1. Purpose

This document defines the support and dispute boundaries needed before Aarast treats support as a real product surface.

It does not create support backend models, admin screens, mobile screens, legal arbitration, payment handling, or guaranteed provider agreement resolution.

## 2. Product Boundary

Support helps users report and understand issues.

Support does not guarantee:

- Provider response.
- Provider quality.
- Final agreement.
- Refund.
- Deposit recovery.
- Legal resolution.
- Financial compensation.
- Booking confirmation.

## 3. Support Entry Points

Future support entry points:

- More -> Support.
- Provider detail -> Report provider.
- Quote request -> Report/dispute quote.
- Settings -> Account/help.
- Error states -> Contact support when retry fails.
- Provider dashboard -> Provider complaint/support.

Until support is implemented, entry points may show a respectful coming-soon state.

## 4. Support Case Types

Initial case types:

- Account access issue.
- Plan data issue.
- Sync/offline issue.
- Privacy/permission issue.
- Provider information is wrong.
- Provider did not respond.
- Provider behavior complaint.
- Quote request issue.
- Suspected abuse/spam.
- App bug.
- Other.

## 5. Dispute Types

Future disputes may include:

- Quote mismatch.
- Provider changed price after quote.
- Provider did not respond.
- Provider profile information incorrect.
- User says provider behaved inappropriately.
- Provider says user submitted misleading request.
- User/provider asks to remove incorrect review later.

Not supported in MVP:

- Payment dispute.
- Deposit refund.
- Contract enforcement.
- Confirmed booking cancellation.
- Legal claim handling.

## 6. Required Support Record Fields Later

Suggested future support/dispute record:

- `id`
- `type`
- `status`
- `priority`
- `reporterUserId`
- `reporterRole`
- `weddingPlanId` optional
- `providerId` optional
- `quoteRequestId` optional
- `bookingLeadId` optional, lead-only
- `subject`
- `message`
- `adminNotes`
- `assignedAdminId`
- `createdAt`
- `updatedAt`
- `resolvedAt`

Sensitive fields must be minimized.

## 7. Status Lifecycle

Suggested statuses:

- `new`
- `triage`
- `waiting_on_user`
- `waiting_on_provider`
- `under_review`
- `resolved`
- `closed`
- `rejected`

Every status change should be auditable later.

## 8. Privacy Rules

Support must:

- Show only data needed for the case.
- Avoid exposing full plan financial data to support by default.
- Avoid exposing full guest/contact lists.
- Avoid exposing exact address unless the user includes it intentionally.
- Redact tokens, OTPs, passwords, and secrets.
- Keep provider and user messages separate where appropriate.
- Log admin access later.

## 9. User-Facing Copy Rules

Allowed language:

- "We will review your report."
- "This report helps us improve provider quality."
- "Aarast does not confirm agreements between users and providers in this version."
- "Do not share payment or password information in support messages."

Forbidden language:

- "We guarantee resolution."
- "Your booking is protected."
- "Your deposit is secured."
- "Provider agreement is confirmed."
- "Aarast will refund you."

## 10. Admin Handling Rules Later

Admins may need to:

- View case list.
- Filter by type/status/priority.
- View limited related context.
- Add internal notes.
- Ask user/provider for more information.
- Suspend provider if serious abuse is confirmed.
- Mark case resolved/closed.

Admin must not:

- Change financial records without explicit product/legal approval.
- Promise refunds or compensation.
- Reveal one user's private plan details to a provider.
- Resolve legal disputes as if Aarast is a court/arbitrator.

## 11. Provider Report Handling

Provider reports should be connected to provider operations:

- Repeated reports can affect provider review.
- Serious reports can trigger temporary suspension.
- Provider should receive clear reason if action is taken.
- False or abusive reports should also be handled.

## 12. QA For Support Later

Required checks when implemented:

- User can submit support case.
- Provider can submit support case.
- Reporter cannot see other users' cases.
- Provider cannot see private plan data.
- Admin can change status with note.
- Closed case remains read-only unless reopened.
- Forbidden copy is not used.

## 13. Acceptance Criteria

- Support boundaries are defined.
- Case and dispute types are listed.
- Unsupported MVP dispute types are listed.
- Suggested record fields and statuses are defined.
- Privacy and copy rules are defined.
- Admin/provider handling rules are defined.
- No code is changed.

## 14. Risks

- Support copy can accidentally imply guarantees.
- Support records can expose sensitive plan, contact, or financial data.
- Provider disputes need admin process before marketplace growth.
- Payment/deposit disputes cannot be supported before payment/deposit features legally exist.

## 15. Next Implementation Notes

- Next stage: `docs/mobile-ux/VISUAL_SYSTEM.md`.
- Replace current `/support` placeholder only after a scoped support implementation task defines backend/admin/mobile acceptance criteria.
