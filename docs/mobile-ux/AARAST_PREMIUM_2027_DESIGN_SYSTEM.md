# Aarast Premium 2027 Design System

Date: 2026-06-26
Scope: Flutter mobile production UI only.
Status: Implementation-layer reference for the current production mobile screens.

> Current identity note (2026-07-02): Premium 2027 is no longer the independent
> final visual source of truth. The final mobile product identity is
> `../../MOBILE_SOFT_ROYAL_UI_PLAN.md` (`Soft Royal Wedding`). This document
> remains valid as a technical implementation layer for tokens and shared
> components.

## Purpose

Aarast Premium 2027 is the shared implementation system for the mobile app. It supports the final Soft Royal Wedding identity across home, money, debts, tasks, providers, sharing, settings, notifications, onboarding, and supporting forms.

Old designs, Markdown decisions, screenshots, prototypes, rebuild screens, and legacy widgets are not final UI references. They may be inspected only to understand product logic, routes, data responsibilities, permissions, and forbidden behaviors. They must not be reused, restored, copied, or visually matched as the final Soft Royal Wedding interface.

This system does not add new product capabilities. It does not imply confirmed bookings, deposits, payment processing, financing, loans, provider acceptance, or any financial transaction beyond the already approved budget, expense, debt, and installment records.

## Source Files

The implementation source of truth is:

- `mobile/lib/core/theme/aarast_design_tokens.dart`
- `mobile/lib/core/theme/aarast_motion.dart`
- `mobile/lib/core/theme/app_theme.dart`
- `mobile/lib/core/widgets/aarast_ui.dart`
- `mobile/lib/core/widgets/aarast_scaffold.dart`
- `mobile/lib/core/widgets/aarast_screen_frame.dart`
- `mobile/lib/core/widgets/aarast_app_bar.dart`
- `mobile/lib/core/widgets/aarast_card.dart`
- `mobile/lib/core/widgets/aarast_button.dart`
- `mobile/lib/core/widgets/aarast_section_header.dart`
- `mobile/lib/core/widgets/aarast_empty_state.dart`
- `mobile/lib/core/widgets/aarast_status_badge.dart`
- `mobile/lib/core/widgets/aarast_loading_state.dart`
- `mobile/lib/core/widgets/aarast_error_state.dart`
- `mobile/lib/core/widgets/aarast_bottom_sheet.dart`
- `mobile/lib/core/widgets/aarast_metric_tile.dart`
- `mobile/lib/core/widgets/aarast_pressable.dart`

Existing `AppTheme` names remain supported as compatibility aliases so production screens can migrate without route, provider, or test churn. These aliases do not make older visual decisions authoritative.

## Palette

| Token | Value | Use |
| --- | --- | --- |
| `royalMaroon` | `#7A1F2B` | Primary brand actions, active navigation, important icons |
| `royalMaroonSoft` | `#F7E8EA` | Soft royal backgrounds and quiet elevated accents |
| `royalMaroonDeep` | `#4A0F18` | Deep contrast, shadows, premium hero surfaces |
| `champagneGold` | `#D8B26E` | Secondary accent, progress, premium emphasis |
| `champagneGoldDeep` | `#C9963E` | Readable gold text on light surfaces and warning states |
| `pearl` | `#FFF8EF` | Primary pearl surface |
| `warmIvory` | `#FBF4EA` | App background |
| `softSand` | `#F3E8DA` | Page gradient tail and quiet panels |
| `mutedRose` | `#FCECEC` | Soft danger treatment |
| `ink` | `#23181A` | Primary text |
| `inkSoft` | `#75666A` | Secondary text |
| `hairline` | `#EADBC9` | Borders and separators |
| `success` | `#2E7D5B` | Paid, done, success states |
| `warning` | `#C9963E` | Pending or caution states |
| `danger` | `#B94A48` | Delete, overdue, destructive states |
| `info` | `#4F6D7A` | Neutral informational states |

White text is reserved for dark maroon hero/overlay surfaces and high-contrast icon buttons. Status colors must come from semantic tokens instead of raw `Colors.green`, `Colors.red`, or ad hoc Material colors.

## Typography

The app uses Tajawal for body text and Amiri for display moments through `AppTheme`.

Rules:

- Use display typography only for first-level page or royal dashboard moments.
- Use tighter `titleMedium` and `titleSmall` styles inside cards and repeated list rows.
- Keep Arabic copy right-aligned in content areas.
- Use `maxLines` and `TextOverflow.ellipsis` in compact controls, headers, buttons, tabs, and repeated cards.
- Avoid viewport-scaled font sizes. Component dimensions, not text scaling formulas, should carry responsive layout.

## Layout Rhythm

Spacing tokens are defined at 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 24, 28, and 32 px.

Core rhythm:

- Screen horizontal padding: 16 px.
- Max readable mobile content width: 560 px.
- Card padding: 16 px unless an already-migrated child owns its own internal padding.
- Minimum tap target: 48 px.
- Bottom navigation height: 76 px.
- Repeated item minimum card height: 72 px.

## Corners And Surfaces

Cards and panels use:

- Small radius: 12 px.
- Medium radius: 16 px.
- Large radius: 20 px.
- Extra large radius: 24 px.
- Dialog/sheet radius: 32 px when the element is intentionally modal.

`AarastCard` is the default repeated item surface. Material `Card(` should not be used directly inside production feature or shared mobile widgets.

## Components

| Component | Contract |
| --- | --- |
| `AarastPageScaffold` | RTL-safe premium page shell with background gradient, safe area, max width, optional header, and bottom/FAB slots |
| `AarastScreenFrame` | Flexible routed-screen shell for custom slivers, bottom navigation, dashboards, and full production bodies that still need the Premium background and max width |
| `AarastScaffold` | Short alias for the standard premium page scaffold |
| `AarastAppBar` / `AarastSliverAppBar` | Premium header variants for screens that need app-bar-style composition |
| `AarastPageHeader` | Compact title/subtitle/actions header with overflow protection |
| `AarastCard` | Shared card surface with tokenized background, border, radius, shadow, optional tap behavior |
| `AarastButton` | Primary, secondary, ghost, and danger actions with icon and loading states |
| `AarastSectionHeader` | Shared section title/action row |
| `AarastEmptyState` | Reusable empty-state panel with icon and optional action |
| `AarastStatusBadge` | Semantic status label for paid, planned, overdue, done, pending, and permission states |
| `AarastLoadingState` | Tokenized skeleton list placeholder |
| `AarastErrorState` | Reusable retry/error panel |
| `AarastMetricTile` | Compact numeric summary tile for money, task, guest, and provider summaries |
| `AarastPressable` | Shared tap/press feedback primitive used by cards and tiles |
| `showAarastBottomSheet` | Shared modal sheet shape, background, and safe-area behavior |

## Motion

Motion must stay light and functional:

- Quick: 140 ms.
- Fast: 190 ms.
- Standard: 300 ms.
- Slow: 460 ms.
- Curve: `Cubic(0.22, 1, 0.36, 1)`.

`AarastMotion.reduceMotion(context)` must be honored by shared animated widgets. The current motion primitives are fade/slide entry, staggered entry, and skeleton pulse.

## Product Truth Rules

The visual system must not make incomplete states look completed.

- Budget and debt cards may show planned, paid, partial, cancelled, pending, and overdue states only when those states exist in the current models.
- Provider surfaces may request quotes and show provider details, but must not imply confirmed booking, deposit, or payment settlement.
- Shared members must not see private financial details unless existing permission checks allow it.
- Disabled or unavailable actions should stay visually honest through locked, coming-soon, empty, or API-required states.
- Screens using local guest data must not look like backend-synced account data unless the route has actually migrated or saved it.

## Migration Rules

1. Prefer the shared components above before adding local card, button, chip, loading, error, or sheet implementations.
2. Preserve existing routes, providers, models, keys, and tests unless the current task explicitly changes behavior.
3. Keep domain calculations in providers/adapters, not visual widgets.
4. Do not introduce new packages for polish while existing Flutter, `google_fonts`, `flutter_animate`, and icon support are sufficient.
5. When migrating older UI code, keep product copy and API behavior stable unless the current task explicitly changes them.
6. Do not reuse, restore, copy, or visually match old screenshots, prototypes, rebuild screens, or legacy widgets as final UI.
7. Use old files only as product-logic evidence, then express the UI through Premium 2027 tokens and shared components.

## QA Checklist

Before calling a Premium 2027 pass complete:

- `flutter analyze` passes.
- Focused widget tests for touched shared components pass.
- Full `flutter test` passes, or any unrelated failure is documented with evidence.
- Every routed production screen uses `AarastScreenFrame`, `AarastPageScaffold`, `AarastScaffold`, `AuthWeddingScaffold`, or `GuestOnboardingStepScaffold`.
- `rg -n "(^|[^\w])Scaffold\(|PrimaryActionButton|primary_action_button" mobile/lib/features -g "*screen.dart"` returns no legacy routed-screen shell/action usage.
- `rg -n "\bCard\(" mobile/lib/features mobile/lib/shared` returns no direct production feature/shared card usage.
- `git diff --check` passes.
- No backend, database, deployment, Docker, branch, commit, stage, push, reset, or clean action was introduced unless explicitly requested.
