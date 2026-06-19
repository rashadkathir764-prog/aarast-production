# Aarast Mobile Visual System

Date: 2026-06-19
Stage: Visual Polish
Status: Planning document only

## 1. Purpose

This document defines the future visual system for Aarast mobile after the product, UX, data, architecture, QA, privacy, and release blueprints are complete.

It does not authorize Flutter UI implementation by itself.

## 2. Visual Direction

Aarast should feel:

- Arabic-first.
- Calm.
- Practical.
- Wedding-aware.
- Trustworthy.
- Warm without becoming decorative.
- Clear enough for repeated daily use.

The app should not feel like:

- A marketing landing page.
- A generic marketplace.
- A finance app with cold corporate styling.
- A decorative wedding gallery with weak task clarity.
- A one-color burgundy/gold wall.

## 3. First Screen Visual Rule

The first meaningful screen should communicate:

- This is for planning a wedding.
- The user can start without account.
- The app will guide step by step.
- User/provider paths are separate.

Do not place a login form as the first emotional signal unless the user explicitly chooses login.

## 4. Layout Hierarchy

Use consistent hierarchy:

1. Screen title or current plan context.
2. Primary next action.
3. Time-sensitive warnings.
4. Summary metrics.
5. Domain sections.
6. Secondary links.

Home should be a Today Center, not a grid of equal cards.

## 5. Palette Usage

Core palette direction:

- Burgundy for primary actions and brand anchors.
- Warm gold for celebration/accent moments.
- Soft white/ivory for page background.
- Neutral ink for high readability.
- Green for success/done.
- Blue for information.
- Orange for warning/pending.
- Red for danger/overdue/destructive.

Rules:

- Do not make every card burgundy/gold.
- Financial warning/danger states must be stronger than decorative accent.
- Disabled/locked/private states need icon and copy, not color alone.
- Offline/pending sync should have distinct visual treatment.

## 6. Typography Rules

Arabic text should be readable and calm:

- Page titles are clear but not oversized.
- Dense panels use compact headings.
- Metrics use strong numbers with clear labels.
- Amounts and phone numbers need correct LTR handling.
- Long Arabic labels must wrap gracefully.
- Avoid negative letter spacing.
- Do not scale text by viewport width.

## 7. Component Visual Contracts

Bottom navigation:

- Fixed stable height.
- Clear active item.
- Icons plus short labels.
- No unfinished feature tab visible.

Action sheet:

- Short rows.
- Icon per action.
- Disabled state with reason if needed.
- No duplicate action entry points.

Cards:

- One job per card.
- Repeated item cards only.
- No cards inside cards.
- No invented placeholder stats.

Forms:

- Labels visible.
- Error under field.
- Save/cancel consistent.
- Required/optional distinction clear.

Badges/chips:

- Status chips for due/overdue/done/pending/private/offline.
- Permission chips must be explicit and readable.

## 8. Domain Visual Rules

### Home / Today Center

Visual focus:

- Next best action.
- Days/status context.
- Urgent tasks or installment due.
- Budget risk only if user can view finance.
- Sync/offline state.

Avoid:

- Equal-weight card wall.
- Decorative hero that pushes useful action away.
- Contradictory summaries.

### Money

Visual focus:

- Total, spent, remaining.
- Category progress.
- Debt/installment due state.
- Private/locked state.

Avoid:

- Payment/deposit language.
- Hiding permission denial as generic error.
- Showing amounts in notifications/previews for unauthorized users.

### Tasks

Visual focus:

- Today.
- Upcoming.
- Overdue.
- Done.
- Priority.

Avoid:

- Timeline decoration that hides overdue urgency.
- Empty state without generated task suggestion.

### Providers

Visual focus:

- Provider name.
- Category.
- City/service area.
- Verification/status where available.
- Planning/quote CTA.

Avoid:

- Stock-like fake provider imagery.
- Confirmed booking visuals.
- Payment/deposit badges.

### Guests

Visual focus:

- Counts and invitation status.
- Clear add/edit actions.
- Contact privacy.

Avoid:

- Broad contact upload prompts.
- Exposing phone numbers outside needed views.

### Sharing

Visual focus:

- Member role.
- Permission chips.
- Locked finance explanation.

Avoid:

- Hidden privacy behavior.
- Technical user IDs.

### Notifications

Visual focus:

- Source type.
- Read/unread.
- Actionable destination.

Avoid:

- Sensitive preview for unauthorized finance/debt data.
- Push permission sales copy.

## 9. Empty, Error, Loading, Offline Visuals

Every major state should have:

- Small icon or symbol.
- Short Arabic title.
- One sentence of explanation.
- One primary action.
- Optional secondary action.

Loading:

- Use skeletons where possible.
- Keep old cached data during refresh.

Error:

- Explain what failed.
- Keep draft data.
- Offer retry.

Offline:

- Distinguish cached read from local-only write.
- Show pending sync badge on local records.

Locked/private:

- Explain permission issue.
- Say who can grant access when known.

## 10. Imagery And Icons

Use imagery carefully:

- Real provider photos only when provider data supports them.
- Generated/stock-style images should not hide missing data.
- Avoid decorative background visuals that reduce readability.
- Icons should be familiar and consistent.
- Directional icons must respect RTL.

## 11. Accessibility And Device Range

Requirements:

- Comfortable tap targets.
- Text scale resilience.
- RTL-safe layout.
- Color plus label/icon for state.
- No critical content hidden behind hover-only interactions.
- Works on common low/mid Android screens.
- Scroll behavior stays smooth with Arabic content.

## 12. Visual QA Checklist

Before accepting visual polish:

- Fresh guest onboarding screenshots.
- Logged-in owner screenshots.
- Shared member without finance permission screenshots.
- Offline/pending sync screenshots.
- Empty states for money/tasks/providers/guests/sharing/notifications.
- Error state screenshots.
- Provider path screenshots.
- Small device and larger text checks.
- No text overflow in Arabic.

## 13. Acceptance Criteria

- Visual direction is defined.
- Palette, typography, layout, and component contracts are defined.
- Domain-specific visual rules are defined.
- State visuals are defined.
- Accessibility and visual QA checklist are defined.
- No Flutter UI code is changed.

## 14. Risks

- Starting visual polish too early can hide unresolved product logic.
- Wedding decoration can reduce clarity if overused.
- Provider visuals can imply marketplace maturity before operations are ready.
- Finance visuals can leak private information if cards are reused without permission state.

## 15. Next Implementation Notes

- Next stage: `docs/AGENT_EXECUTION_RULES.md`.
- First visual implementation should target one flow with screenshots and QA, not global restyling.
