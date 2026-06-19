# Aarast Notifications Blueprint

Date: 2026-06-19
Stage: Notifications Blueprint
Status: Planning document only

## 1. Decision

Notifications in Aarast must be actionable, source-linked, privacy-safe, and delayed until the user has a clear reason to receive them.

Do not request push notification permission on first launch.

## 2. Current State

Current schema has:

- `Notification`
- `NotificationPreference`
- `NotificationType`

Current mobile has:

- `NotificationsScreen`.
- `NotificationsProvider`.
- plan-specific notification route.
- unread count endpoint support.

Current gaps:

- Notification enum is limited.
- Deep links are not a typed column.
- Push device token infrastructure is not defined.
- Guest/local reminders are not defined.

## 3. Notification Types

Required types:

- `quote_received`
- `quote_status_changed`
- `quote_accepted`
- `quote_rejected`
- `installment_due`
- `installment_overdue`
- `debt_overdue`
- `budget_exceeded`
- `task_due_today`
- `task_overdue`
- `member_joined`
- `permission_changed`
- `guest_confirmed`
- `sync_failed`
- `general` only for admin/system messages with clear action.

Mapping to current enum can be temporary, but future migration should avoid overusing `GENERAL`.

## 4. Notification Fields

Required logical fields:

- id.
- userId.
- weddingPlanId optional.
- type.
- title.
- body.
- sourceType.
- sourceId.
- deepLink.
- data JSON.
- readAt.
- createdAt.

Current schema can use `data` for `sourceType`, `sourceId`, and `deepLink` until a migration adds typed fields.

## 5. Deep Link Rules

Every notification must open a useful place:

| Type | Deep link target |
|---|---|
| task_due_today/task_overdue | Task detail or Tasks tab filtered to due/overdue |
| installment_due/installment_overdue | Money/Debt detail if finance permission allows |
| budget_exceeded | Money screen |
| quote_received/status | Quote request/offer detail |
| member_joined/permission_changed | Sharing screen |
| guest_confirmed | Guests screen |
| sync_failed | Offline/sync status surface |

If access is denied:

- Show a safe explanation.
- Do not reveal sensitive amounts or titles.
- Offer Home fallback.

## 6. Push Permission Timing

Ask for push permission only after one of these moments:

- User created or migrated a plan.
- User set a wedding date and task reminders exist.
- User created debt/installment reminders.
- User sent or received a quote request.
- User joined/shared a plan.

Do not ask:

- On first app open.
- Before user understands value.
- While user is still guest unless local OS reminders are intentionally supported.

## 7. Guest And Offline Behavior

Guest:

- Can see local in-app reminders if implemented locally.
- Cannot receive server push.
- Must be asked to create account for cloud/server notifications.

Offline:

- Cached notifications can display.
- Mark read can be queued only if Offline & Sync Plan approves it.
- Sync failure notification must not loop infinitely.

## 8. Privacy Rules

- Financial notification previews must avoid amounts for users without finance permission.
- Provider notification must include only submitted quote request fields.
- Guest list notifications must respect future guest permissions.
- Deleted or inaccessible source records must show safe fallback.
- Notification data must not contain secrets, tokens, or full private objects.

## 9. Backend Generation Rules

Generate notifications from domain events:

- task due/overdue checks.
- installment due/overdue checks.
- quote request status changes.
- sharing add/update.
- budget summary threshold.
- sync failure if server-side sync is added.

Deduplication:

- Use dedupe keys for recurring task/installment reminders.
- Do not create duplicate unread alerts for the same due item/day.

## 10. UX Rules

Notifications screen must:

- Show unread/read state.
- Allow mark read/read all/delete.
- Open source on tap.
- Explain empty state.
- Show retry on failed load.
- Preserve cached list when refresh fails if possible.

Notification copy:

- Arabic.
- Short.
- Action-oriented.
- Persona-aware where appropriate.

## 11. Acceptance Criteria

- Notification types are defined.
- Required fields and temporary/current schema mapping are documented.
- Deep-link targets are documented.
- Push permission timing is documented.
- Guest/offline behavior is documented.
- Privacy and dedupe rules are documented.
- No notification code or schema is changed.

## 12. Risks

- Generic notifications without deep links become noise.
- Push permission too early reduces trust.
- Financial notification previews can leak private details.
- Missing dedupe can spam users.
- Deep links without route guards can expose inaccessible data.

## 13. Next Implementation Notes

- Next stage: `docs/mobile-ux/DESIGN_SYSTEM.md`.
- Notification implementation must wait for route guard and permissions alignment.
- Push infrastructure must wait for Feature Flags, Security, and Release planning.

