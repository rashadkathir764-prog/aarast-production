# Aarast Mobile Soft Royal Wedding UI Plan

Date: 2026-07-02
Scope: Flutter mobile only.
Status: Active final mobile product identity and stabilization plan.

## Decision

Soft Royal Wedding is the final visual and product identity for Aarast Mobile.
Premium 2027, `AppTheme`, and `AarastDesignTokens` are implementation layers only.
They are useful technical foundations, but they are not an independent visual direction.

`DESIGN_IDENTITY.md` remains a supporting identity guide. This file is the execution
contract for product stabilization.

## Fixed Scope

- Mobile only.
- No backend changes.
- No API changes.
- No database changes.
- No Prisma changes.
- No web/admin-web changes.
- No future-phase features.
- No payments, deposits, confirmed bookings, loans, credit, financing, AI, or chat.
- No commit or push unless explicitly requested.

## Product Goal

Every production mobile screen should feel like one product:

- Same warm wedding background.
- Same card grammar.
- Same button hierarchy.
- Same section rhythm.
- Same empty, loading, error, locked, and unavailable states.
- Same bottom navigation language.
- Same Arabic-first RTL behavior.
- Same truthfulness about local, guest, account-backed, and unavailable data.

The work is not quick decoration. The work is product stabilization.

## Soft Royal Wedding Contract

### Visual Identity

| Role | Token direction | Rule |
| --- | --- | --- |
| App background | Warm bridal ivory `#FDFBF9` / pearl cream `#FFFAF5` | The default mobile surface should stay soft, warm, and calm. |
| Primary action | Royal rose burgundy `#800020` | Use for the single most important action. |
| Deep identity | Deep burgundy `#5A0015` | Use for hero depth, strong titles, and high-contrast surfaces. |
| Premium accent | Champagne gold `#D4AF37` | Use sparingly for emphasis, borders, icons, and priority moments. |
| Card surface | Warm white `#FFFFFF` | Use shared cards, not local card systems. |
| Primary text | Deep ink `#2D1A1E` | Keep Arabic copy readable and calm. |
| Secondary text | Muted cocoa `#8A7B7E` | Use for helper copy and metadata. |
| Borders | Soft border `#F2E7DC` | Keep separators warm and subtle. |
| Success | Safe green `#3D8252` | Success only, never decoration. |
| Danger | Danger red `#BA2D3F` | Destructive, overdue, or error only. |
| Warning | Warning gold `#D98A2C` | Caution, near-risk, or priority only. |

### Implementation Rules

- Prefer shared components from `mobile/lib/core/widgets`.
- Do not create a private visual system inside a screen.
- Do not add local color classes such as `_RoyalColors` for production UI.
- Do not use raw `Colors.red`, `Colors.green`, or `Colors.blue` for semantic states.
- Do not use raw hex colors in feature screens unless the value is being migrated
  into a token or is explicitly documented as a temporary audit debt.
- Do not use direct Material `Card(` in feature/shared production UI.
- Do not use direct `Scaffold(` in routed production screens except approved shell
  surfaces.
- Do not show placeholder or coming-soon content inside the core flow unless it is
  intentional, explicit, and outside the MVP-critical journey.

Allowed low-risk exceptions while migrating:

- `Colors.transparent`.
- `Colors.white` for text/icons on dark burgundy surfaces where contrast requires it.
- Temporary compatibility aliases in `AppTheme`.
- Shell-level scaffolds when they are intentionally responsible for tab/navigation
  structure and documented during audit.

## Screen Product Questions

Every screen must answer four questions:

1. Where am I?
2. What is the most important thing now?
3. What is the next valid action?
4. What can I not do here, and why?

If a screen cannot answer those questions, the issue is product logic or content
placement, not only visual styling.

## Stabilization Phases

### Phase A: Audit Only

- Do not change UI.
- Inventory production mobile screens from `AppRouter`, `MainShell`, and shell routes.
- Mark each screen as `Aligned`, `Partially aligned`, `Broken logic`,
  `Visual drift`, or `Content misplaced`.
- Identify the top 10 visually or logically painful screens.
- Produce the problem, reason, priority, and shared component needed.

### Phase B: Design Contract

- Align Soft Royal identity with tokens and shared components.
- Do not redesign screens yet.
- Add or update tests that prevent regression into visual drift:
  raw semantic colors, local card systems, legacy buttons, direct cards, and 320px
  overflow risk for touched screens.

### Phase C: Critical User Journey

Only fix the first five minutes:

- Splash / Welcome.
- Guest onboarding.
- Generated preview.
- Home dashboard.
- Bottom navigation.
- More.

The goal is a coherent, understandable, respectable first-run experience.

### Phase D: Core Planning Screens

Fix based on audit priority, not taste:

- Money.
- Tasks.
- Guests.
- Providers.
- Plan Center.

### Phase E: Secondary Screens + Release QA

- Login, register, and OTP.
- Sharing.
- Notifications.
- Settings and support.
- Provider account screens.
- Manual QA on a real device.
- APK release check.

## Acceptance Gates

- `flutter analyze` passes.
- `flutter test` passes.
- Dashboard or critical golden snapshots are updated only after approved visual change.
- Any touched production screen has a 320px RTL regression test when practical.
- No new direct `Card(` in feature/shared production UI.
- No new direct routed-screen `Scaffold(` unless it is a documented shell exception.
- No new raw semantic colors for status states outside tokens.
- No core-flow placeholder unless explicitly intentional.
- Every changed screen has a clear title, one primary action, honest states, logical
  content placement, and no Arabic overflow.

## Current Execution Rule

Start with Phase A and Phase B foundations. Do not jump into Phase C/D screen
rewrites until the audit matrix and design contract are stable.
