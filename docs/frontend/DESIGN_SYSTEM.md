# Aarast Design System And Tokens

Snapshot date: 2026-07-05

The mobile dashboard is the visual source of truth for Aarast. New mobile UI
should extend the dashboard language instead of inventing a parallel style.

Primary code sources:

- `mobile/lib/core/theme/aarast_design_tokens.dart`
- `mobile/lib/core/theme/app_theme.dart`
- `mobile/lib/core/widgets/aarast_ui.dart`
- `mobile/lib/features/wedding_plans/widgets/premium/premium_dashboard_view.dart`
- `mobile/lib/features/wedding_plans/widgets/premium/smart_dashboard_cards.dart`
- `mobile/lib/features/wedding_plans/widgets/premium/countdown_hero.dart`
- `mobile/lib/features/wedding_plans/widgets/royal_home_chrome.dart`

## Product Feel

Aarast should feel:

- Arabic-first.
- Calm and premium.
- Wedding-aware without becoming decorative.
- Financially trustworthy.
- Compact enough for real phone use.
- Honest about local, synced, locked, pending, and permission-limited states.

The winning dashboard pattern is:

Header -> burgundy countdown hero -> smart next action -> setup journey when
needed -> compact pulse cards -> money glance -> all-clear or state feedback.

## Color Tokens

Use `AarastDesignTokens` as the code source of truth.

| Token | Hex | Use |
| --- | --- | --- |
| `ivory` | `#FCF8F5` | Screen background. |
| `pearl` | `#FFF8F3` | Soft page gradient and warm surfaces. |
| `surface` | `#FFFFFF` | Main cards and controls. |
| `surfaceElevated` | `#FFFDFB` | Inputs and elevated surfaces. |
| `burgundy` | `#800020` | Primary brand action and nav active state. |
| `burgundyDark` | `#5A0015` | Strong title, hero depth, shadows. |
| `burgundySoft` | `#F8E8EC` | Soft brand backgrounds and locked states. |
| `gold` | `#D4AF37` | Premium accent, progress, highlights. |
| `goldSoft` | `#FFF3CF` | Soft gold chips and setup states. |
| `ink` | `#2D1A1E` | Main body text. |
| `muted` | `#8A7B7E` | Secondary text. |
| `border` | `#EADDE2` | Hairline borders. |
| `success` | `#3D8252` | Completed, safe, all-clear states. |
| `warning` | `#D98A2C` | Budget near limit, local/sync caution. |
| `danger` | `#BA2D3F` | Urgent or failed states. |
| `info` | `#4F6D7A` | Informational states. |

Rules:

- Burgundy is for identity and decisive action.
- Gold is for premium emphasis, progress, and guided setup.
- Do not turn every card gold or burgundy. Most cards stay white with border.
- Semantic colors should be soft in backgrounds and strong only for icons,
  rails, and short labels.

## Typography

Code source:

- Body/default: `Tajawal`.
- Display/headlines: `IBMPlexSansArabic`.
- `Amiri` is reserved for brand/logo identity only.

Use:

- Headline medium: 24, weight 700, display font.
- Title large: 20, weight 800.
- Title medium: 16, weight 700.
- Body medium: 14.
- Label medium: 12, weight 700.
- Letter spacing: 0.

Rules:

- Keep Arabic text short and direct.
- Use ellipsis for compact cards.
- Do not use viewport-scaled font sizes.
- For dense phone cards, prefer 11-14 labels and 16-19 key numbers.

## Spacing

Code source: `AarastDesignTokens.space*`.

Scale:

- 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 24, 28, 32.

Dashboard defaults:

- Screen horizontal padding: 20 on the premium dashboard.
- Common section gap: 14.
- Header to hero gap: 18.
- Small inline gaps: 5-10.
- Bottom padding inside shell: 158 to clear bottom nav and FAB.

Rules:

- Phone surfaces should be compact, not sparse.
- Use stable dimensions for nav, FAB, pulse cards, and hero rings.
- Do not stack cards inside cards.

## Radius

Code source: `AarastDesignTokens`.

- `radiusSm`: 12.
- `radiusMd`: 16.
- `radiusLg`: 20.
- `radiusXl`: 24.
- `radius2xl`: 32.
- `radiusPill`: 999.

Rules:

- Main cards: 20.
- Hero cards: 24.
- Small icon containers: 12-16.
- Chips and badges: pill.
- Avoid excessive rounding on dense operational cards.

## Shadows And Elevation

Use shadows softly:

- Card shadow: ink at 0.04-0.05, blur 16-22, y 6-10.
- Lifted/hero shadow: burgundy dark at about 0.32, blur 26, y 12.

Rules:

- Shadows support hierarchy; they are not decoration.
- Cards can rely on border only when the surface is dense.
- Do not use decorative blobs or unrelated gradient ornaments.

## Icons

Dashboard direction:

- Prefer Lucide icons.
- Use Material icons only for existing compatibility or where no Lucide
  equivalent is currently wired.

Sizes:

- Small: 16.
- Medium: 20.
- Large: 24.
- Extra large: 30.

Rules:

- Icons should clarify action, area, or state.
- Use icon buttons for common commands instead of text-heavy controls.
- Provide tooltip/semantic label for icon-only actions.

## Core Components

### Screen Frame

Use `AarastScreenFrame` for mobile screens:

- RTL direction.
- Ivory background.
- Centered constrained content.
- Typical max width: 520-560.

### Dashboard Header

Pattern:

- Greeting line.
- Product/name line.
- Notification icon with unread dot.
- Profile/more icon.
- Optional local-only chip.

### Countdown Hero

Use for the main plan identity:

- Burgundy gradient.
- Plan title.
- Optional persona headline.
- Wedding date.
- City.
- Progress ring with days remaining.

Rules:

- Hero should be tappable to `إدارة الخطة`, the administrative plan profile.
- Hero owns the emotional moment; do not add another competing hero on the same
  screen.

### Smart Next Action

Use when there is a clear next best action:

- Urgent money/installment.
- Overdue tasks.
- Received quotes.
- Today tasks.
- Pending invites.
- Backend-provided important item.

Rules:

- One smart action at a time.
- It must navigate to the real route.
- If no useful action exists, hide it and show all-clear when appropriate.

### Setup Journey

Use for fresh plans:

- Set budget.
- Add first task.
- Add first guest.

Rules:

- Do not show dead zero cards to new users.
- Show setup only when budget, tasks, or guests are missing.

### Pulse Row

Use for three compact status tiles:

- Tasks.
- Guests.
- Providers.

Rules:

- Three tiles maximum per row.
- Values must be honest and source-backed.
- Captions should explain the number, not repeat the label.

### Money Glance

Use only when permissions allow money visibility.

Shows:

- Allocated budget.
- Spent.
- Remaining.
- Usage progress.
- Add expense action.

Rules:

- Hide the money card when permissions do not allow it.
- Use warning state near budget limits.
- Do not fake currency or totals.

### Bottom Navigation

Use `RoyalDashboardBottomNav`:

- Home.
- Money.
- Tasks.
- Guests.
- Providers.

Rules:

- Keep order stable.
- Active state uses burgundy/gold language.
- Shell state should be preserved through `IndexedStack` where appropriate.

### Floating Action

Use `RoyalSmartFloatingActionButton`.

Canonical quick actions:

- Add expense.
- Add task.
- Add guest.
- Add debt/installment.
- Request quote.
- Add budget category in money context.

Rules:

- Use the canonical quick action builder.
- Avoid duplicate create affordances on the same surface.
- Protected submit actions must remain account-gated for local guest plans.

## States

Every important screen should define:

- Loading skeleton or loading state.
- Empty state.
- Error state with retry when useful.
- Locked/permission state.
- Offline/local/pending-sync state where relevant.

Dashboard state examples:

- `PremiumDashboardSkeleton`.
- Dashboard error card with retry.
- Empty state that sends user to onboarding.
- Local sync notice for guest plans.

## Motion

Code source:

- `AarastMotion`.
- `AarastDesignTokens.motion*`.

Rules:

- Respect reduced motion.
- Use short staggered entry on dashboard sections.
- Use shimmer only for skeleton or a single premium hero moment.
- Do not make motion block task completion or navigation.

## RTL And Arabic

Rules:

- UI is RTL by default.
- Arabic labels must stay short enough for 320px phones.
- Use `Expanded`, `Flexible`, `FittedBox`, or ellipsis where numbers and labels
  can grow.
- Avoid English status leaks like `PLANNING`, `YER`, or raw enum names.
- Currency should use clear Arabic/Yemeni formatting, not unclear shorthand.

## Migration Rule

When improving an existing screen:

1. Keep API behavior and routes unchanged.
2. Use tokens from `AarastDesignTokens`.
3. Reuse existing core widgets before creating new ones.
4. Match the dashboard visual language.
5. Verify narrow phone layout.
6. Run the checks required for the touched area.

## Premium Screen Contract v2

Enforced automatically by
`mobile/test/core/widgets/aarast_premium_contract_test.dart`. Every routed
screen must:

1. Render through a premium wrapper: `AarastScreenFrame`,
   `AarastPageScaffold`/`AarastScaffold` (built on the frame), or
   `AuthWeddingScaffold` for auth. Raw `Scaffold(`/`Card(` are banned in
   `lib/features/**/_screen.dart`.
2. Show body loading as `AarastSkeleton` (`.list`/`.form`/`.page`) — raw
   `CircularProgressIndicator` is banned in `lib/features` and `lib/shared`.
   Text-button loading goes through `AarastButton.isLoading`; icon-button
   loading through `AarastInlineSpinner`.
3. Show errors as `AarastErrorState` with a retry action, and empties as
   `AarastEmptyState` with a CTA.
4. Use staggered entry (`AarastStagger.children`) for main content lists,
   always honoring `AarastMotion.reduceMotion`.
5. Use the unified feature header (`AarastFeatureHeader`) or the built-in
   `AarastPageScaffold` header — no bespoke local headers.
6. Use tokens only (`AppTheme` re-exports the full `AarastDesignTokens`
   scale: colors, `space*`, `icon*`, radii, motion, `minTapTarget`).

Golden previews for the shared foundation live in
`mobile/test/premium_foundation_preview_test.dart`.

## Shipped Feature Flags Matrix

Only rollout switches consumed by live code remain in
`mobile/lib/core/config/app_feature_flags.dart`:

| Flag | Default | Live consumer |
| --- | --- | --- |
| enableGuestFirstOnboarding | ON | Smart welcome/onboarding redirect |
| enableOfflineSync | ON | Offline release-readiness state |
| enablePushNotifications | OFF | Notification permission/readiness state |
| devBypassLoginGatesForUxExploration | OFF | Compile-time development escape hatch |

Provider access, quote ownership, contact selection, and deferred product scope
are enforced by real auth/route/domain contracts. AI, subscriptions/payments,
maps, and analytics are absent or explicitly out of scope; inert OFF flags are
not treated as protection. Release builds reject the development escape hatch.
