# Aarast Privacy And Terms Notes

Date: 2026-06-19
Stage: Legal / Support / Disputes
Status: Planning document only

## 1. Purpose

This document captures privacy, terms, and legal-product notes needed before Aarast expands provider, support, dispute, monetization, analytics, payments, or marketplace behavior.

It is not final legal text and should be reviewed by qualified legal counsel before production publication.

## 2. Core Legal Position

Aarast is a wedding planning and coordination product first.

Current MVP behavior must not imply:

- Guaranteed provider agreement.
- Confirmed booking.
- Payment processing.
- Deposit collection.
- Provider quality guarantee.
- Financial advice.
- Loan, credit, or financing offer.
- Legal arbitration.
- Insurance or compensation promise.

## 3. Privacy Policy Topics Needed

Future privacy policy should explain:

- What account data is collected.
- What wedding plan data is stored.
- How budget, expenses, debts, installments, and tasks are protected.
- How sharing permissions affect visibility.
- How guest contacts are handled.
- How selected contact data differs from full contact-book upload.
- How location/address data is used.
- How provider quote requests share limited details.
- How notifications may include planning reminders.
- How support may access limited records during a user request.
- How analytics is disabled/enabled and minimized.
- How data deletion/export requests are handled later.

## 4. Terms Of Use Topics Needed

Future terms should cover:

- User responsibility for entered data.
- No guarantee of provider availability, quality, price, or final agreement.
- Quote requests are informational/planning leads unless a later approved legal flow says otherwise.
- Aarast is not responsible for offline agreements made outside the app.
- No payment/deposit flow exists in MVP.
- Users must not misuse contact or sharing features.
- Providers must submit accurate business information.
- Admin may review, suspend, or remove providers.
- Support/disputes are assistance workflows, not guaranteed legal resolution.

## 5. Provider Terms Topics Needed

Provider terms should cover:

- Provider identity/contact accuracy.
- Service area accuracy.
- Category/service/package accuracy.
- Prohibited misleading claims.
- Review/approval/suspension process.
- Response expectations for quote requests.
- No payment/deposit processing in MVP.
- No guarantee of lead volume.
- User privacy obligations.
- Dispute/report handling.

## 6. Permission Explanations

User-facing permission explanations should be plain and contextual:

- Contacts: only when selecting a specific guest/member contact.
- Location: only when user asks to use device location.
- Notifications: only after a plan/reminder/quote reason exists.
- Photos/files: only when upload feature exists later.

Do not ask for broad permissions at first launch.

## 7. Data Retention Notes

Retention policy should later define:

- Account retention.
- Wedding plan retention.
- Guest local draft retention.
- Offline queued data retention.
- Provider quote retention.
- Support ticket/dispute retention.
- Deleted account behavior.
- Backup retention.

Until then, avoid promising exact retention timelines in product copy.

## 8. Marketplace Disclaimer Notes

Marketplace/provider copy must say or imply:

- Providers are planning references until approved marketplace operations exist.
- Quote request is not a confirmed booking.
- Prices may change.
- Availability must be confirmed with provider.
- Aarast does not guarantee provider performance.

Marketplace/provider copy must not say:

- Booking confirmed.
- Deposit paid.
- Provider guaranteed.
- Contract completed.
- Payment secured.

## 9. Analytics And Observability Notes

Analytics requires:

- `enableAnalytics`.
- Privacy review.
- No raw financial/contact/address/token/OTP values.
- Stable event taxonomy.
- Ability to disable analytics.

Support debug bundles must exclude secrets, contacts, exact finance values, and exact addresses unless a user intentionally shares them for support.

## 10. Acceptance Criteria

- Privacy policy topics are identified.
- Terms of use topics are identified.
- Provider terms topics are identified.
- Permission explanations are defined.
- Marketplace disclaimer boundaries are defined.
- Analytics/support privacy boundaries are defined.
- No code is changed.

## 11. Risks

- Provider wording can imply guarantees or legal commitments.
- Contact/location permissions can break trust if requested too early.
- Support access can expose sensitive data without audit and minimization.
- Monetization or payments before legal review can create major liability.

## 12. Next Implementation Notes

- Next legal/support document: `docs/support/SUPPORT_DISPUTES_PLAN.md`.
- Before production publication, convert these notes into counsel-reviewed privacy policy, terms of use, provider terms, and support policy text.
