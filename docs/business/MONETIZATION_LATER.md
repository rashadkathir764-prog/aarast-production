# Aarast Monetization Later

Date: 2026-06-19
Stage: Monetization Later
Status: Planning document only

## 1. Decision

Monetization is deferred.

Aarast must prove the Wedding Financial OS first: plan creation, money clarity, debts/installments, tasks, guests, providers as planning references, sharing, privacy, offline behavior, and reliable Arabic-first UX.

## 2. Not In MVP

The current MVP must not include:

- Payment processing.
- Deposits.
- Confirmed paid bookings.
- Provider subscriptions.
- Featured paid placement.
- Commission collection.
- User premium plan.
- Loans.
- Credit.
- Financing.
- Savings products.
- AI paid helper.
- Internal chat monetization.
- Ads.

These are future possibilities only and require explicit approval.

## 3. Product Rule

Do not ask users to pay before they understand value.

Value must be proven by:

- Creating a useful wedding plan.
- Tracking budget, expenses, debts, installments, and tasks.
- Helping family collaboration without privacy leaks.
- Showing relevant providers as planning references.
- Handling offline and sync honestly.

## 4. Possible Future Revenue Lines

Future options, not current scope:

- Provider subscription after provider operations are stable.
- Featured provider placement after ranking ethics and disclosure are defined.
- Commission from confirmed deals after legal/operational contract model exists.
- Premium user features such as export, advanced sharing, or advanced reports.
- PDF export or printable plan package.
- Respectful limited ads only after user trust and product fit are proven.
- FinTech partnerships only after legal, privacy, financial-risk, and compliance review.

## 5. Conditions Before Monetization

No monetization implementation should start until:

- Core mobile QA passes.
- Provider operations/admin review flow is stable.
- Support and disputes flow is defined.
- Legal/provider terms are written.
- Privacy policy covers payment/monetization data.
- Analytics/observability is approved and privacy-safe.
- Feature flags can disable monetized surfaces.
- Clear refund/cancellation/support process exists for any paid flow.
- Backend data model supports the monetization concept safely.

## 6. Forbidden Copy

Do not show copy that implies:

- "Book now" as a confirmed booking.
- "Pay deposit" or "Pay now".
- "Guaranteed provider".
- "Official agreement completed".
- "Financing approved".
- "Loan available".
- "Subscription required" for current MVP value.

Allowed planning copy:

- Compare providers.
- Request a quote.
- Save provider.
- Add provider to planning notes later if approved.
- Track expected cost manually inside money flow.

## 7. Provider Monetization Later

Provider monetization can be considered only after:

- Provider profile lifecycle is reviewed by admin.
- Provider status is visible and reliable.
- Quote requests work without false booking promises.
- Support/disputes process exists.
- Provider terms are approved.
- Ranking/featured placement labels are transparent.

Possible provider revenue:

- Monthly provider profile subscription.
- Featured placement with clear label.
- Paid lead package after anti-spam and support rules.

## 8. User Monetization Later

User monetization can be considered only after:

- Free planning value is strong.
- Export/share/advanced reporting value is proven.
- Data portability is considered.
- No private financial data is used for manipulative upsell.

Possible user revenue:

- PDF export.
- Advanced family permissions.
- Advanced budget reports.
- Multiple plan/archive support.

## 9. FinTech Later

Payment, installment, savings, loan, credit, or financing concepts are high-risk.

Before any FinTech work:

- Legal review.
- Compliance review.
- Partner due diligence.
- Explicit consent and disclosures.
- Data minimization.
- Clear financial-risk language.
- No dark patterns around wedding pressure.

## 10. Acceptance Criteria

- Monetization is explicitly deferred.
- Subscriptions, payments, commissions, deposits, and FinTech are excluded from MVP.
- Future revenue options are listed as later-only concepts.
- Conditions before monetization are defined.
- Forbidden copy is documented.
- No code is changed.

## 11. Risks

- Early monetization can damage trust before planning value is proven.
- Payment/deposit language can imply legal commitments Aarast does not support.
- Featured placement can reduce provider trust if not clearly labeled.
- FinTech ideas can create legal, ethical, and privacy risk.

## 12. Next Implementation Notes

- Next stage: `docs/legal/PRIVACY_TERMS_NOTES.md`.
- If future monetization is approved, update product scope, API/database plans, legal docs, QA plan, and feature flags before code.
