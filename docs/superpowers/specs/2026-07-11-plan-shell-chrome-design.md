# Canonical Plan Shell Chrome Design

**Status:** Implemented. The source contract keeps both production shells on
the shared `PlanShellChrome` frame.

## Decision

Use one shared `PlanShellChrome` widget for both `MainShell` and
`WeddingPlanShell`. It owns the `Scaffold`, bottom navigation, quick-add FAB,
FAB position, RTL direction, and tab-specific Lucide icon. The two shells keep
their existing navigation responsibilities: `MainShell` retains its lazy
`IndexedStack`, while `WeddingPlanShell` retains GoRouter path selection.

## Rejected alternatives

- Replacing both shells with one router-driven state machine would be a larger
  behavior rewrite and risks tab state, back navigation, and local guest flows.
- Sharing only helper functions would still leave two independent Scaffolds and
  two places where visibility or layout could drift.

## Behavioral contract

- Tab order stays dashboard, money, tasks, guests, providers.
- Providers has no shell quick-add FAB.
- Money shows the FAB only at its root and only with finance-management access.
- Tasks and guests keep their current direct-add behavior.
- Existing canonical quick-add actions and Arabic labels remain unchanged.
- Both shells use the same Lucide icon mapping and bottom navigation widget.

## Verification

A source contract must fail if either shell declares its own `Scaffold`,
`RoyalSmartFloatingActionButton`, or `RoyalDashboardBottomNav`. Existing routing,
quick-add, narrow-screen, and full Flutter tests remain the acceptance suite.
