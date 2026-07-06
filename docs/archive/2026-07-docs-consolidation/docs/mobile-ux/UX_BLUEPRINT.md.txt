# Aarast Mobile UX Blueprint

Date: 2026-06-19
Stage: UX Blueprint
Status: Draft ready for navigation and implementation planning

## 1. UX Principles

- Arabic-first, RTL-first.
- Guest-first until an action requires account ownership or server participation.
- Wedding-user and provider paths must be separated.
- Every screen must have one clear primary action.
- No screen should be visually polished before its product role, data, and states are defined.
- Empty states must explain the next action.
- Loading states should prefer cached/local data when available.
- Error states must be Arabic, specific, and recoverable.
- Financial data is private by default.
- Any repeated number must come from a single summary source.

## 2. Screen Contracts

### 2.1 Welcome

- Goal: Welcome the user and introduce Aarast as step-by-step wedding planning.
- Target user: New wedding user or provider before path selection.
- Entry point: First launch after splash when no active session/current local plan exists.
- Displayed data: Brand, short promise, no account form.
- Primary action: Start.
- Secondary action: Login for existing account.
- Empty State: Not applicable.
- Loading State: Splash or short brand skeleton only.
- Error State: If local storage fails, show "تعذر بدء التطبيق. أعد المحاولة."
- Success State: Move to Choose Path.
- Requires account: No.
- Works offline: Yes.
- Persona copy: Neutral until persona is selected.
- Notification deep link: No.

### 2.2 Choose Path

- Goal: Separate wedding-user and provider journeys early.
- Target user: New user deciding why they opened the app.
- Entry point: Welcome primary action, or More switch path later if approved.
- Displayed data: Two choices: "أريد تنظيم زفافي" and "أنا مزود خدمة".
- Primary action: Choose wedding planning.
- Secondary action: Choose provider path.
- Empty State: Not applicable.
- Loading State: None beyond normal transition.
- Error State: If choice cannot be saved locally, explain and retry.
- Success State: Wedding user goes to Persona; provider goes to Provider Intro/Auth Gate.
- Requires account: No for choosing path.
- Works offline: Wedding path yes; provider path can explain online requirement.
- Persona copy: Neutral.
- Notification deep link: No.

### 2.3 Persona

- Goal: Capture groom/bride/helper tone and planning role.
- Target user: Wedding-user path only.
- Entry point: Choose Path -> wedding planning.
- Displayed data: Groom, Bride, Helper choices with short examples.
- Primary action: Select persona and continue.
- Secondary action: Change path.
- Empty State: No selection disables continue with helper text.
- Loading State: Local save spinner only if needed.
- Error State: "تعذر حفظ اختيارك. حاول مرة أخرى."
- Success State: Move to Location Setup.
- Requires account: No.
- Works offline: Yes.
- Persona copy: Starts applying after selection.
- Notification deep link: No.

### 2.4 Location Setup

- Goal: Capture planning location for provider matching and local context.
- Target user: Wedding user.
- Entry point: Persona step or later dashboard completion prompt.
- Displayed data: Governorate, city/district, neighborhood, street, address note, optional "use my location later".
- Primary action: Save location.
- Secondary action: Skip precise details and continue with city only.
- Empty State: If no local seed data, allow manual entry and document missing seed need.
- Loading State: Loading location seed suggestions.
- Error State: "تعذر تحميل المدن. يمكنك إدخال المدينة يدوياً الآن."
- Success State: Continue to Wedding Date.
- Requires account: No.
- Works offline: Yes if seed data/cache exists.
- Persona copy: Use selected persona tone in labels.
- Notification deep link: No.

### 2.5 Wedding Date

- Goal: Establish planning timeline and task generation basis.
- Target user: Wedding user.
- Entry point: Location Setup or dashboard completion prompt.
- Displayed data: Calendar picker, quick choices after 1/3/6/12 months, unknown date option.
- Primary action: Select date.
- Secondary action: "لا أعرف التاريخ الآن".
- Empty State: Unknown date state should continue with flexible timeline.
- Loading State: None.
- Error State: Invalid date message if date is in unsupported range.
- Success State: Days remaining is calculated by one shared date utility later.
- Requires account: No.
- Works offline: Yes.
- Persona copy: Groom/bride/helper wording changes for "حدد/حددي/ساعد في تحديد".
- Notification deep link: Later reminder can deep link here if date missing.

### 2.6 Priorities

- Goal: Decide what the dashboard should recommend first.
- Target user: Wedding user.
- Entry point: Wedding Date step.
- Displayed data: Budget, debts/installments, tasks, guests, providers, sharing options.
- Primary action: Select one or more priorities.
- Secondary action: Use recommended defaults.
- Empty State: If none selected, use default priorities: budget, tasks, providers.
- Loading State: None.
- Error State: Local save failure message.
- Success State: Continue to Budget Setup.
- Requires account: No.
- Works offline: Yes.
- Persona copy: Helper copy should say "ما الذي ستساعد فيه؟"
- Notification deep link: No.

### 2.7 Budget Setup

- Goal: Capture estimated budget without blocking users who are unsure.
- Target user: Wedding user.
- Entry point: Priorities step or Money completion prompt.
- Displayed data: Currency, estimated budget, explanation that it can change.
- Primary action: Save budget.
- Secondary action: Skip for now.
- Empty State: If skipped, generated dashboard shows a clear "أضف ميزانية تقريبية" action.
- Loading State: None.
- Error State: Invalid amount message.
- Success State: Continue to Suggested Categories.
- Requires account: No.
- Works offline: Yes.
- Persona copy: Persona-specific CTA.
- Notification deep link: Later budget reminder can deep link to Money/Budget Setup.

### 2.8 Suggested Categories

- Goal: Create useful starter budget categories and avoid blank money screen.
- Target user: Wedding user.
- Entry point: Budget Setup step.
- Displayed data: Yemen wedding category presets with selected defaults.
- Primary action: Create plan with selected categories.
- Secondary action: Customize later.
- Empty State: If seed list unavailable, show manual category fallback and continue.
- Loading State: Load presets from local seed/cache.
- Error State: "تعذر تحميل التصنيفات المقترحة. سننشئ خطة بدون تصنيفات ويمكنك إضافتها لاحقاً."
- Success State: Plan is created locally or on server depending auth/sync state.
- Requires account: No for local plan; account required for cloud plan.
- Works offline: Yes with local storage.
- Persona copy: Persona-specific explanatory copy.
- Notification deep link: No.

### 2.9 Generated Dashboard

- Goal: Show that Aarast has built a useful first plan, not an empty dashboard.
- Target user: Wedding user after onboarding.
- Entry point: Suggested Categories completion or returning user with a current plan.
- Displayed data: Plan title, city, wedding date/days, budget if provided, selected priorities, next best action, top alert/task.
- Primary action: Complete the next best action.
- Secondary action: Explore plan sections.
- Empty State: Must never be empty; if no plan exists, route to Welcome/Plan creation.
- Loading State: Skeleton plus cached local plan when available.
- Error State: If server summary fails, show local/cached summary and retry option.
- Success State: User lands in Home/Today Center with a useful plan summary.
- Requires account: No for local generated dashboard.
- Works offline: Yes for local/cached plan.
- Persona copy: Yes, hero and CTAs adapt.
- Notification deep link: Yes, notifications can open relevant dashboard section.

### 2.10 Home / Today Center

- Goal: Daily command center: what matters now, not a noisy card wall.
- Target user: Wedding user with a current plan.
- Entry point: User bottom navigation "الرئيسية", app resume, notification to home-level item.
- Displayed data: Next best action, days remaining, urgent tasks, due installments, budget warning, unread notifications, sync status.
- Primary action: Complete the next recommended action.
- Secondary action: Open plan center or switch plan.
- Empty State: If no plan, show create/continue onboarding action.
- Loading State: Use cached summary first, then refresh.
- Error State: Show partial sections with inline retry where possible.
- Success State: Recommended action updates and summary refreshes.
- Requires account: No for local plan; account gate appears for sharing/quote/sync.
- Works offline: Yes for cached/local plan; clearly label pending sync.
- Persona copy: Yes.
- Notification deep link: Yes.

### 2.11 Money

- Goal: Centralize budget, expenses, debts, and installments.
- Target user: Wedding owner or shared member with finance permission.
- Entry point: Bottom navigation "المال", Home money card, + action sheet.
- Displayed data: Budget total, spent, remaining, budget categories, expenses, debts summary, due installments, permission state.
- Primary action: Add expense or complete budget setup depending current state.
- Secondary action: Add category, add debt, view installments.
- Empty State: If no budget/categories/expenses, explain and offer first setup action.
- Loading State: Skeleton or cached finance summary.
- Error State: Financial fetch failure must not expose hidden data; show retry.
- Success State: Summary updates from one finance source.
- Requires account: For server/cloud financial history; local draft allowed only if offline plan supports it.
- Works offline: Read cached; local writes can be pending sync only if Offline Plan allows it.
- Persona copy: Yes.
- Notification deep link: Installment/budget notifications deep link here.

### 2.12 Tasks

- Goal: Track wedding work by timeline, priority, status, and due dates.
- Target user: Owner, helper, task manager, or shared member with task access.
- Entry point: Bottom navigation "المهام", Home next task, + action sheet, notification.
- Displayed data: Timeline summary, today/upcoming/overdue/done filters, task templates, assignee later.
- Primary action: Complete current task or add first task.
- Secondary action: Add task, filter, edit, reopen, delete.
- Empty State: Offer generated tasks based on wedding date before manual blank state.
- Loading State: Cached tasks or skeleton.
- Error State: Inline retry and keep cached tasks if available.
- Success State: Progress and dashboard update from one task summary source.
- Requires account: No for local tasks; account for shared assignment/sync.
- Works offline: Yes for local/cached tasks with pending sync label.
- Persona copy: Yes, especially helper tasks.
- Notification deep link: Task notifications deep link to task detail/filter.

### 2.13 Providers

- Goal: Help users compare planning references and request quotes in plan context.
- Target user: Wedding user; provider CTA only in controlled path.
- Entry point: Bottom navigation "الموردون", Home provider prompt, quote notification.
- Displayed data: Search, filters, location/category suggestions, provider cards, favorite state, provider detail links.
- Primary action: Open provider or request quote depending context.
- Secondary action: Favorite, filter, change city/category.
- Empty State: Explain no matching providers and offer filter reset or broader city.
- Loading State: Cached provider list or skeleton.
- Error State: Use cached providers if available and show retry.
- Success State: Provider detail opens; quote request created when authenticated.
- Requires account: Browse no; favorite/quote yes unless local favorite is explicitly supported.
- Works offline: Cached browse/favorites may work; quote request requires online/account.
- Persona copy: Wedding-user copy; provider join CTA must be limited and not repeated everywhere.
- Notification deep link: Quote-related notifications deep link to provider/quote detail.

### 2.14 Guests

- Goal: Manage guest list, invitation status, attendance, and counts.
- Target user: Owner or member with guest permission.
- Entry point: More/Guests, Home guest prompt, + action sheet.
- Displayed data: Guest count, invited/confirmed/pending, guest rows, side/status/seats/phone.
- Primary action: Add guest.
- Secondary action: Edit guest, change invitation status, delete.
- Empty State: "لا توجد ضيوف بعد" with add guest action and optional import explanation.
- Loading State: Cached guests or skeleton.
- Error State: Retry without losing local form data.
- Success State: Guest summary updates.
- Requires account: Server guest list yes; local guest draft can be allowed if offline plan supports it.
- Works offline: Yes if offline sync plan allows local guest writes.
- Persona copy: Yes.
- Notification deep link: Guest status notifications can deep link here later.

### 2.15 Notifications

- Goal: Show actionable alerts that open the right place.
- Target user: Authenticated user; guest can see local reminders separately if supported.
- Entry point: More, dashboard bell, notification tap.
- Displayed data: Notification list, unread state, type icon, title/body, created time.
- Primary action: Open notification source.
- Secondary action: Mark read, read all, delete.
- Empty State: Explain no notifications and avoid "turn on push" until reason exists.
- Loading State: Skeleton or cached in-app notifications.
- Error State: Retry and keep cached notifications if possible.
- Success State: Mark read and navigate to source.
- Requires account: Server notifications yes.
- Works offline: Cached read yes; marking read queues only if supported.
- Persona copy: Notification body can use persona tone.
- Notification deep link: Yes, this is the source list.

### 2.16 Sharing

- Goal: Invite collaborators and control what each person can see/do.
- Target user: Owner and shared members.
- Entry point: More, Home sharing card, Plan Center.
- Displayed data: Members, roles, permission chips, privacy notice.
- Primary action: Add member.
- Secondary action: Edit permissions, remove member.
- Empty State: Explain privacy and offer add member.
- Loading State: Skeleton member cards.
- Error State: Specific Arabic errors for duplicate/unknown phone/permission failure.
- Success State: Member list updates with safe display data.
- Requires account: Yes.
- Works offline: No for inviting members; cached view can work read-only.
- Persona copy: Yes, especially helper/family copy.
- Notification deep link: Member/permission notifications deep link here.

### 2.17 More

- Goal: Secondary hub without duplicating core navigation.
- Target user: Wedding user or authenticated user.
- Entry point: Bottom navigation "المزيد".
- Displayed data: Account profile, shared plans, my plans, settings, support, provider path if allowed, logout.
- Primary action: Depends on row tapped; no single forced action.
- Secondary action: Logout.
- Empty State: If unauthenticated, show login/signup gate for account actions.
- Loading State: Account/settings skeleton if needed.
- Error State: Account action errors shown inline/snackbar.
- Success State: Opens selected secondary surface.
- Requires account: Some rows yes.
- Works offline: Read-only account/local settings only.
- Persona copy: Yes.
- Notification deep link: Usually no, except support/settings notifications later.

### 2.18 Settings

- Goal: Manage account, notification preferences, language/content preferences, and later persona/location defaults.
- Target user: Authenticated user.
- Entry point: More -> Settings.
- Displayed data: Safe account info, notification preferences, locale/persona/location settings later.
- Primary action: Save settings.
- Secondary action: Cancel/back.
- Empty State: If settings missing, create defaults.
- Loading State: Settings skeleton.
- Error State: Retry and keep draft values.
- Success State: Show saved message and update local state.
- Requires account: Yes for server settings.
- Works offline: Draft local settings only if sync plan allows it.
- Persona copy: Yes after persona is available.
- Notification deep link: Settings/permission reminders can deep link here later.

## 3. Cross-Screen State Rules

- Current plan must be selected by a single current-plan state.
- Home, Money, Tasks, Plans, and Dashboard must not compute progress independently.
- Any hidden financial data must stay hidden in Home and notifications as well.
- Local-only actions must show local-only or pending-sync state.
- Every server-required action from guest mode must pass through an auth gate and then resume.
- Provider mode must have a separate navigation shell or controlled route group.
- Support placeholder must not be treated as completed support UX.

## 4. Acceptance Criteria

- Every requested screen has a defined goal, target user, entry point, displayed data, actions, states, account need, offline rule, persona behavior, and notification/deep-link rule.
- Guest-first flow is reflected in Welcome through Generated Dashboard.
- Home is defined as Today Center rather than a decorative dashboard.
- Money, Tasks, Providers, Guests, Notifications, Sharing, More, and Settings have actionable empty/loading/error/success rules.
- Provider/user separation is preserved.
- No app code is changed by this document.
- The next stage can create a Navigation Blueprint from these contracts.

## 5. Risks

- The current app already has active routes for many surfaces; implementation must avoid breaking MVP flows while rebuilding onboarding/navigation.
- Offline behavior is partly implemented but not yet defined per action; implementation must wait for Offline & Sync Plan.
- Deep links need backend notification type/source mapping before code changes.
- Persona copy requires a content system; hardcoding copy during implementation will create drift.
- Guest-first migration can cause data loss if implemented before migration and single-source plans.

## 6. Next Implementation Notes

- Next document: `docs/mobile-ux/NAVIGATION_BLUEPRINT.md`.
- Navigation Blueprint must decide which screens are bottom tabs, which are pushed details, and which are auth/provider-only.
- Do not alter routes before Navigation Blueprint is complete.
- Do not visually polish dashboard before Design System and Single Source of Truth plans.

