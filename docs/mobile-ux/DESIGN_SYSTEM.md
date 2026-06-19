# Aarast Mobile Design System

Date: 2026-06-19
Stage: Design System
Status: Planning document only

## 1. Design Direction

Aarast should feel Arabic-first, calm, practical, wedding-aware, and trustworthy. It should not become decorative at the expense of clarity.

Visual polish comes later. This document defines reusable design rules for future implementation.

## 2. Identity

Core identity:

- Burgundy: primary brand/action.
- Warm gold: accent and celebration.
- Soft white/ivory: background.
- Neutral ink: readable text.
- Green/blue/red/orange: semantic states only.

Rules:

- Do not create a one-note burgundy/gold-only interface.
- Use color to clarify state, not merely decoration.
- Financial danger/warning states must be obvious and accessible.

## 3. Typography

Rules:

- Arabic-first text hierarchy.
- Avoid oversized headings inside dense tool surfaces.
- Use compact, readable dashboard headings.
- Do not scale font size by viewport width.
- Avoid negative letter spacing.
- Numbers should use clear LTR handling where needed.

Recommended roles:

- Page title.
- Section title.
- Card title.
- Body.
- Caption/meta.
- Metric number.
- Button label.

## 4. Spacing And Layout

Rules:

- Stable dimensions for bottom nav, action sheet rows, cards, buttons, and counters.
- Avoid layout shifts when loading/error/empty states appear.
- Use responsive max-width constraints for web/tablet without turning mobile into a desktop layout.
- Keep cards for repeated items and framed tools only.
- Do not nest cards inside cards.

## 5. Core Components

Required components:

- Page scaffold.
- Page header.
- Bottom navigation.
- Provider bottom navigation.
- Action sheet.
- Primary/secondary/destructive buttons.
- Icon buttons.
- Text field.
- Selector field.
- Segmented control.
- Switch/toggle row.
- Permission chip.
- Status badge.
- Metric tile.
- Summary card.
- List item.
- Empty state.
- Error state.
- Loading skeleton.
- Offline/pending-sync badge.
- Locked permission state.
- Notification card.
- Provider card.
- Guest card.
- Task card.
- Money/debt card.

## 6. Buttons

Rules:

- Primary action appears once per screen when possible.
- Destructive actions require confirmation.
- Disabled actions explain why when the reason is not obvious.
- Icon-only controls need tooltip/semantic label.
- Domain forms should use consistent save/cancel placement.

## 7. Cards And Lists

Rules:

- Cards show one job.
- Repeated rows should be scannable.
- Dashboard cards should not invent numbers.
- Locked financial cards must show privacy reason.
- Empty cards should offer action or route to setup.

## 8. States

Required visual states:

- Loading.
- Empty.
- Error.
- Success.
- Warning.
- Danger.
- Pending review.
- Pending sync.
- Offline.
- Locked/private.
- Disabled feature.

State copy must be Arabic, short, and actionable.

## 9. RTL And Accessibility

Rules:

- RTL is default.
- Icons that imply direction must be mirrored where appropriate.
- Touch targets must be comfortable.
- Text must not overflow buttons/cards.
- Color cannot be the only state indicator.
- Forms must have labels, not placeholder-only meaning.

## 10. Domain Rules

Home:

- Today Center layout, not decorative hero-only dashboard.

Money:

- Amounts, status, and privacy state must be clear.

Tasks:

- Due/overdue/done states must be visually distinct.

Providers:

- Provider cards must show real provider info, not stock/placeholder claims.

Sharing:

- Permission controls must be explicit.

Notifications:

- Read/unread and source type must be clear.

## 11. Acceptance Criteria

- Design identity and palette rules are documented.
- Typography and spacing rules are documented.
- Required component inventory is documented.
- State vocabulary is documented.
- RTL/accessibility requirements are documented.
- Domain-specific UI rules are documented.
- No Flutter UI code is changed.

## 12. Risks

- Visual polish before state/source rules can hide product contradictions.
- Over-decorated dashboard can reduce task clarity.
- Inconsistent empty/error states can make the product feel unreliable.
- Poor RTL handling can break Arabic trust.

## 13. Next Implementation Notes

- Next stage: `docs/mobile-architecture/STATE_MANAGEMENT_PLAN.md`.
- Implementation must reuse existing components where safe.
- Visual System later can refine actual styling after architecture plans.

