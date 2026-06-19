# Aarast Mobile Product Logic Blueprint

Date: 2026-06-19
Stage: Product Logic Blueprint
Status: Draft ready for implementation planning

## 1. Product Rule

Aarast mobile must behave as a wedding management system, not a set of unrelated screens.

The app starts by helping a Yemen-based user create a useful wedding plan, then keeps money, tasks, guests, providers, notifications, sharing, location, privacy, and offline state connected to that plan.

The product must not become marketplace-first, AI-first, account-first, or visual-polish-first.

## 2. Primary Personas

### Wedding User

This path is for the person organizing a wedding.

Supported personas:

- Groom.
- Bride.
- Helper/family contributor.

Product effect:

- Copy tone changes by persona.
- Priorities can change the first recommended actions.
- Permissions and sharing defaults are affected later.
- The user sees wedding-planning navigation, not provider operations.

### Provider

This path is for a business or individual offering wedding services.

Product effect:

- Provider sees provider onboarding, profile status, service/package management, and quote requests.
- Provider must not see a user's private plan, budget, debts, guests, or shared members.
- Provider flow must not be mixed into the normal user dashboard.

### Guest Session

Guest session means a local, pre-account planning state.

Product effect:

- User can start planning without login.
- Local plan data can be created.
- Server-required actions show an auth gate at the moment of need.
- After signup/login, the guest plan must be attached to the account or safely migrated.

## 3. Wedding User Journey From First Open

1. App opens.
2. Splash checks whether a valid session exists.
3. If no session exists, the user still enters a guest-capable onboarding path, not a mandatory registration wall.
4. Welcome screen explains the promise in one short Arabic-first message:
   - "ألف مبروك، خلينا نرتب زفافك خطوة بخطوة."
5. User chooses path:
   - "أريد تنظيم زفافي"
   - "أنا مزود خدمة"
6. If user chooses wedding planning, ask persona:
   - Groom.
   - Bride.
   - Helper.
7. Ask location at a practical Yemen-first level:
   - Governorate.
   - City/district.
   - Neighborhood.
   - Street.
   - Optional address note.
   - "Use my location later" only as an explicit action, not automatic permission.
8. Ask wedding date:
   - Manual date.
   - Quick choices such as after 1, 3, 6, or 12 months.
9. Ask planning priorities:
   - Budget and expenses.
   - Debts and installments.
   - Tasks and dates.
   - Guests.
   - Nearby providers.
   - Family sharing.
10. Ask budget setup:
   - Currency.
   - Estimated budget.
   - Skip allowed.
11. Suggest categories:
   - Hall.
   - Food/dinner.
   - Photography.
   - Decoration/kosha.
   - Dress.
   - Suit.
   - Gold.
   - Henna.
   - Zaffa.
   - Invitations.
   - Transportation.
   - Hospitality.
   - Honeymoon.
   - Home setup.
   - Emergency.
12. Create a local generated plan.
13. Show a generated dashboard that is never blank.
14. The dashboard recommends one next best action based on missing data and priorities.
15. Registration is requested only when the user starts an account/server-required action.

## 4. Provider Journey

1. App opens.
2. User chooses "أنا مزود خدمة".
3. Provider path explains that provider accounts are reviewed before marketplace visibility.
4. If not authenticated, the provider sees an auth gate for provider registration/login.
5. Provider creates or completes profile:
   - Business name.
   - Owner/contact name.
   - Phone.
   - Category.
   - Governorate/city.
   - Service areas.
   - Description.
   - Starting price optional.
   - Photos later.
6. Provider profile status is one of:
   - draft.
   - pending_review.
   - approved.
   - verified.
   - suspended.
   - rejected.
7. Provider dashboard shows:
   - Profile status.
   - Services.
   - Packages.
   - Quote requests.
   - Operational guidance.
8. Provider can respond to quote requests only after account and profile rules are satisfied.
9. Provider never enters the wedding-user bottom navigation.

## 5. Guest-First Strategy

Guest can:

- Complete wedding-user onboarding.
- Create a local plan.
- View generated dashboard.
- Add local starter tasks.
- Add local starter categories.
- Add local expense/task/guest drafts if offline storage supports it safely.
- Browse cached or public providers as planning references.

Guest cannot complete:

- Send real quote request.
- Share a plan.
- Invite members.
- Sync cloud data.
- Receive server notifications.
- Accept or store provider offer.
- Save long-term sensitive records to server.
- Use provider dashboard.

The app must clearly label local-only state. It must not imply that a local guest action succeeded on the server.

## 6. When The App Requests An Account

Request account only when the action needs identity, server ownership, another participant, or long-term private storage.

Account gate triggers:

- Sending a quote request.
- Sharing a plan.
- Inviting a member.
- Enabling cloud sync.
- Enabling notifications.
- Accepting a provider offer.
- Managing provider profile.
- Persisting sensitive financial history beyond local-only usage.
- Opening account settings.

Gate behavior:

- Explain the reason in plain Arabic.
- Preserve intended action after login/signup.
- Offer login and signup.
- Do not lose guest plan data.
- After authentication, migrate or attach local plan data before resuming the action.

## 7. How A Plan Is Created

The plan is created from onboarding, not from a disconnected form.

Inputs:

- Persona.
- Location.
- Wedding date.
- Priorities.
- Budget/currency.
- Selected suggested categories.

Generated outputs:

- Wedding plan title.
- Location fields.
- Wedding date.
- Days remaining.
- Initial budget estimate if provided.
- Budget categories.
- Starter task templates based on date distance.
- First dashboard action.
- Empty-but-actionable guests/providers/sharing states.

Rules:

- If budget is skipped, the dashboard asks for budget later instead of blocking.
- If wedding date is unknown, task templates use flexible phases and ask for date later.
- The dashboard never opens as an empty collection of cards.
- Any repeated summary number must come from one planned summary source.

## 8. How Providers Appear

Providers appear only where they support planning.

Provider list should be ranked by:

1. Same city/district/neighborhood.
2. Matching selected category or priority.
3. Verified/approved provider status.
4. Budget fit when available.
5. Rating/reviews later.

Provider surfaces:

- Providers tab for browsing and search.
- Provider detail screen.
- Request quote action.
- Saved/favorite providers.
- Later: providers linked inside the plan.

Provider surfaces must not:

- Replace the wedding plan.
- Push paid booking or deposit behavior.
- Show provider admin operations to normal wedding users.
- Repeatedly ask wedding users to "join as provider" inside every planning context.

## 9. Quote Request To Plan Provider Flow

Planning-level quote flow:

1. User opens provider detail.
2. User taps request quote.
3. If guest, auth gate appears with reason.
4. User selects wedding plan.
5. User selects service/package/category context.
6. User enters event date, guest count, budget range, and note as needed.
7. Backend creates `QuoteRequest`.
8. Provider sees request in provider dashboard.
9. Provider responds or marks status.
10. User receives notification.
11. User views offer/status.
12. If user accepts later, backend creates `PlanProvider`.
13. Optional later link:
    - Create expense linked to provider.
    - Create debt/installment linked to provider.
    - Show provider in plan dashboard.

MVP boundary:

- Quote request is not a confirmed booking.
- No deposit.
- No payment status.
- No payment processing.
- No legally guaranteed agreement.

## 10. Budget And Providers

Budget and providers must be connected at the planning level.

Rules:

- Each provider/service can suggest a budget category.
- A quote request can include budget range.
- Accepted provider can later connect to a category.
- Expense or debt can optionally reference provider/quote once data model supports it.
- Dashboard can show provider-related financial impact only when source data exists.

Forbidden:

- Do not duplicate provider cost manually across dashboard, finance, and provider screens.
- Do not show fake provider cost totals.
- Do not imply a provider is booked unless an approved future booking flow exists.

## 11. Tasks And Wedding Date

Tasks must be derived from the wedding date and planning phase.

Task logic:

- If wedding date exists, calculate days remaining once.
- Task templates are generated by distance from wedding date.
- Tasks can be due today, upcoming, overdue, or done.
- The dashboard shows the next best task, not a random task list.
- If no wedding date exists, task templates use approximate phases and ask for date later.

Task examples:

- Six months before: set budget, choose hall, shortlist photographer, draft guest list.
- Three months before: confirm food, invitations, decoration, expense tracking.
- One month before: confirm providers, review installments, finalize guests.
- One week before: confirm attendance, review day schedule, pay remaining obligations.

## 12. Notifications

Notifications are event-driven and actionable.

Allowed notification categories:

- Task due today.
- Task overdue.
- Installment due.
- Debt overdue.
- Budget exceeded.
- Quote received.
- Quote status changed.
- Member joined.
- Permission changed.
- Guest status changed.
- Sync failed.

Rules:

- Every notification must deep link to a useful screen.
- No generic notifications without action.
- No push permission prompt on first app open.
- Ask push permission only after the user has a reason, such as created plan, due reminders, quote activity, or sharing.
- Guest can see local/in-app reminders, but server push requires account.

## 13. Sharing And Permissions

Sharing is plan-scoped and privacy-first.

Roles:

- Owner.
- Viewer.
- Contributor.
- Manager.
- Finance manager.
- Task manager.
- Guest manager.
- Provider manager later.

Rules:

- Owner controls sharing.
- Viewer does not edit.
- Task permissions do not imply financial visibility.
- Finance permissions are explicit.
- Debts/installments/expenses are private by default.
- Guest list visibility should be explicit if it becomes sensitive.
- Provider never sees plan internals unless a quote request reveals specific limited details.

UX rules:

- Explain what a permission allows before saving.
- Use presets for common family roles.
- Show locked states instead of broken navigation.
- Never expose hidden financial totals in summaries.

## 14. Single Product State

The product needs one current-plan and summary logic.

Required summary concepts:

- Current plan.
- Days remaining.
- Progress percentage.
- Budget total.
- Spent amount.
- Remaining amount.
- Total debt.
- Paid debt.
- Remaining debt.
- Due installments.
- Open/done/overdue tasks.
- Guest counts.
- Saved/accepted providers.
- Unread notifications.
- Offline pending sync count.

Current risk:

- Existing `HomeDashboardProvider`, `DashboardSummaryProvider`, plan list cards, and dashboard widgets can compute/display related values separately.

Required rule:

- No UI should invent its own progress, days remaining, or summary counts.

## 15. Forbidden Product Behaviors

Do not ship:

- Empty dashboard after first useful onboarding.
- Mandatory login at first app open.
- Visible AI feature that is not enabled.
- Provider/user flow mixed into the same shell.
- Repeated "join as provider" CTAs in normal wedding planning contexts.
- Payment processing.
- Deposits.
- Confirmed booking status.
- Loans, credit, financing, or FinTech flows.
- Internal chat.
- Subscriptions or monetization prompts.
- Push permission request at first launch.
- Backend/Prisma/API changes before their Blueprints.
- Route changes before Navigation Blueprint.
- Flutter refactor before core Blueprints.
- Fake dashboard/provider/guest/budget numbers.

## 16. Product Decisions For Existing Screens

- Keep finance/debt/task/guest/sharing MVP behavior as reusable foundations.
- Rebuild onboarding and plan creation into one product journey.
- Rebuild shell/navigation only after Navigation Blueprint.
- Rebuild dashboard into Today Center/Generated Dashboard after UX and Single Source of Truth plans.
- Keep marketplace as planning/reference and quote-lead support.
- Gate or soften provider CTAs until provider/user separation and admin operations are defined.
- Keep offline layer and specify exact screen behavior later.

## 17. Acceptance Criteria

- Wedding-user journey is defined from first app open through generated dashboard.
- Provider journey is defined separately from wedding-user flow.
- Guest-first behavior is defined, including what guest can and cannot do.
- Account gates are defined by action, not by app launch.
- Plan creation logic includes persona, location, wedding date, priorities, budget, categories, and generated dashboard.
- Provider display and quote request logic is tied to plan context.
- Quote request to future plan provider flow is defined without bookings/payments/deposits.
- Budget/provider relationship is defined at planning level.
- Tasks are tied to wedding date and templates.
- Notification rules require actionable deep links and delayed push permission request.
- Sharing and privacy rules keep financial data private by default.
- Forbidden behaviors are explicit.
- No application code is changed by this document.

## 18. Risks

- Guest-first requires careful local data migration; otherwise users may lose early planning data after signup.
- Provider/admin operations may be incomplete; provider features must remain controlled until admin review is ready.
- Quote-to-plan behavior requires data model work; implementing it early would break phase discipline.
- Existing UI already exposes provider and AI-like surfaces; later implementation must hide or gate anything not ready.
- Summary-source cleanup can touch many screens; it must wait for State Management and Single Source of Truth plans.

## 19. Next Implementation Notes

- Next stage is `docs/mobile-ux/UX_BLUEPRINT.md`.
- Do not edit routes yet.
- Do not edit Prisma or backend APIs yet.
- Do not rebuild Flutter onboarding yet.
- UX Blueprint must translate this product logic into per-screen state/action contracts.

