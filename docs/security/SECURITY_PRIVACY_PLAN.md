# Aarast Security & Privacy Plan

Date: 2026-06-19
Stage: Security & Privacy Plan
Status: Planning document only

## 1. Decision

Aarast financial and planning data is private by default. Sharing must be explicit, permission-scoped, and understandable in Arabic.

## 2. Sensitive Data

Sensitive data includes:

- Phone numbers.
- Contacts.
- Home/wedding address.
- Budget.
- Expenses.
- Debts.
- Installments.
- Attachments/receipts later.
- Guest list.
- Shared members.
- Provider quote details.
- Provider agreements/leads.
- Notification content.

## 3. Privacy Rules

- Do not upload all contacts.
- Only use selected contact data when user explicitly chooses it.
- Do not expose financial details to shared members unless permission allows.
- Providers see only quote request details submitted to them.
- Admin access must be auditable later.
- Exact address sharing must be explicit.
- Guest local data remains private on device.
- Notification previews must not leak hidden financial details.

## 4. Permission Rules

Current permissions:

- `canViewBudget`
- `canViewExpenses`
- `canViewDebts`
- `canManageTasks`
- `canManageFinancialRecords`

Required behavior:

- UI must show locked state when permission is missing.
- Backend must enforce permission; UI hiding is not enough.
- Financial summaries must be hidden, not only detail screens.
- Owner can manage sharing.
- Provider is not a plan member.

## 5. Device Permission Timing

Ask only when needed:

- Contacts: when tapping contact picker.
- Location: when tapping use my location.
- Notifications: after plan/reminder/quote context exists.
- Photos/files: only when upload feature is available.

Never request:

- Push permission on first launch.
- Contacts permission during onboarding without action.
- Location permission as a mandatory first step.

## 6. Auth And Token Rules

- Password hash never returns to clients.
- Access token is sent only as Bearer token.
- Logout clears local auth state.
- Guest data migration must not expose local data to wrong account.
- Resume targets should not store secrets.

## 7. Provider Privacy

Provider can see:

- Request message.
- Event date if user submitted it.
- Guest count if user submitted it.
- Budget range if user submitted it.
- City/location detail intentionally submitted.

Provider cannot see:

- Full wedding plan.
- Expenses.
- Debts.
- Installments.
- Guest list.
- Shared members.
- Private address unless user explicitly includes it.

## 8. Admin And Audit Later

Future admin-sensitive actions need audit logs:

- Provider approval/rejection/suspension.
- Dispute handling.
- Content changes.
- Permission override if ever allowed.
- Support access to user data.

## 9. Acceptance Criteria

- Sensitive data categories are listed.
- Privacy and permission rules are documented.
- Device permission timing is documented.
- Provider visibility rules are documented.
- Admin audit needs are documented.
- No security-sensitive code is changed.

## 10. Risks

- UI-only permissions can leak data through APIs.
- Contact upload can break trust.
- Notification previews can reveal private finances.
- Provider quote flow can accidentally expose full plan context.
- Guest migration can attach local data to wrong account if not guarded.

## 11. Next Implementation Notes

- Next stage: `docs/admin/ADMIN_PROVIDER_OPERATIONS.md`.
- Future security implementation must include tests around shared financial visibility.

