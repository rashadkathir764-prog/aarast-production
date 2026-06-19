# Aarast Error, Loading, Empty States Guide

Date: 2026-06-19
Stage: Error / Loading / Empty States Guide
Status: Planning document only

## 1. Decision

Every screen must have clear Arabic loading, error, empty, success, locked, offline, and pending-sync behavior.

No blank white screens. No generic "Something went wrong." No empty state without an action.

## 2. Loading Rules

Use:

- Cached data first where safe.
- Skeleton cards for dashboard/list surfaces.
- Inline loading for small actions.
- Pull-to-refresh for refreshable lists.

Avoid:

- Clearing old data during refresh.
- Full-screen spinners when cached data exists.
- Loading indicators that resize the layout.

## 3. Error Rules

Errors must:

- Explain what failed.
- Offer retry or next action.
- Preserve draft form data.
- Avoid leaking private data.

Examples:

- "تعذر تحميل الخطة. حاول مرة أخرى."
- "الميزانية خاصة. ليست لديك صلاحية عرض التفاصيل المالية."
- "هذا الإجراء يحتاج اتصالاً بالإنترنت."
- "تعذر حفظ المصروف. تأكد من الاتصال وحاول مرة أخرى."

## 4. Empty State Rules

Every empty state needs:

- Clear title.
- One-sentence explanation.
- Primary action.
- Optional secondary action.

Examples:

- Money: add first category or budget.
- Tasks: generate starter tasks or add first task.
- Guests: add first guest.
- Providers: broaden search or add location.
- Sharing: add trusted member.
- Notifications: no alerts yet; do not push permission immediately.

## 5. Locked State Rules

Use locked state when a user can reach a surface but cannot see data:

- Financial data without finance permission.
- Debts/installments without debt permission.
- Provider dashboard without provider profile.
- Sharing management for non-owner.

Locked state must explain why and who can grant access.

## 6. Offline And Pending Sync

States:

- offline readable.
- local only.
- pending sync.
- sync failed.
- synced.

Rules:

- Never claim server success for local-only action.
- Show pending badge on local records.
- Keep retry path for failed sync.
- Quote/sharing/provider actions show online/account requirement.

## 7. Success States

Success should:

- Confirm action.
- Update list/summary.
- Return to the correct previous surface.
- Resume gated action after auth/migration.

Avoid success snackbars that hide real next step.

## 8. Domain State Matrix

| Domain | Empty action | Error action | Locked action |
|---|---|---|---|
| Home | Create/continue plan | Retry summary | Not applicable except hidden sections |
| Money | Add budget/category | Retry finance load | Ask owner for finance permission |
| Debts | Add debt | Retry debt load | Ask owner for debt permission |
| Tasks | Generate/add task | Retry tasks | Ask owner for task permission |
| Guests | Add guest | Retry guests | Ask owner for guest access later |
| Providers | Reset filters/add location | Retry/cached list | Account gate for quote |
| Notifications | No alerts yet | Retry notifications | Login/account required |
| Sharing | Add member | Retry members | Owner-only management |
| Provider Dashboard | Apply/complete profile | Retry profile | Provider status explanation |

## 9. Acceptance Criteria

- Loading, error, empty, locked, offline, pending sync, and success rules are documented.
- Domain matrix is documented.
- Arabic copy rules are documented.
- No code is changed.

## 10. Risks

- Empty states without actions make MVP feel unfinished.
- Generic errors reduce user trust.
- Offline success ambiguity can corrupt expectations.
- Locked states hidden as errors can confuse shared members.

## 11. Next Implementation Notes

- Next stage: `docs/architecture/OFFLINE_SYNC_PLAN.md`.
- Implementation should convert existing one-off states into reusable components after Design System and Mobile Implementation Plan.

