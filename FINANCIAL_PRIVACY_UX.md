# Financial Privacy UX Specification

Privacy is a core pillar of Aarast / اعّرست. Because weddings involve complex financial arrangements (debts, family contributions, installments), users must feel absolute confidence that their sensitive data is protected from shared members unless explicitly granted.

## Core Privacy Principles
1. **Owner sees everything.** The creator of the Wedding Plan has absolute visibility and control.
2. **Private by default.** Financial data (expenses, debts, installments) is private to the Owner unless explicitly shared.
3. **No accidental exposure.** Sensitive numbers should never leak through UI placeholders, empty states, or error messages.

---

## UI/UX Behavior for Privacy

### 1. Visual Marking of Private Items (Owner View)
- Any expense, debt, or installment marked as private must display a **Privacy Badge** (a small lock icon or the word "خاص" - Private) next to the amount or title.
- This reassures the Owner that the system recognizes the item as restricted.

### 2. Hidden by Default (Shared Member View)
- If a shared member does not have permission to view financials, the **Financial Summary Card** on the Dashboard is completely hidden or replaced by a generic "Wedding Countdown" card.
- In lists (Expenses, Debts), private items do not show up as "Hidden Item" rows. They are completely omitted to prevent members from knowing that hidden records exist.

### 3. Masking Sensitive Numbers
- In public spaces or when screen sharing, the Owner can tap an "Eye" icon in the AppBar to mask all large financial numbers with asterisks (e.g., `**** ر.ي`).
- This applies to Total Budget, Total Expenses, and Individual Item amounts.

---

## Conceptual Permission Levels (Future Roadmap)
*Note: These are for conceptual UX planning only. No backend or UI implementation in the current MVP phase.*

To support future shared member features, the UI will eventually need to accommodate the following roles/permissions:

1. **View Tasks Only (Default for new members)**
   - Can see timeline and tasks.
   - Zero access to Budget, Expenses, Debts, Installments.
2. **View Budget Summary**
   - Can see the high-level dashboard numbers (Total Budget, Spent).
   - Cannot see individual expenses or who is owed money.
3. **View Expenses**
   - Can see the itemized list of public expenses.
   - Private expenses remain hidden.
4. **View Debts & Installments**
   - Can see the list of financial obligations.
5. **Manage Tasks**
   - Can add, edit, and complete tasks.
6. **Manage Financial Records (Co-Owner)**
   - Can add/edit expenses, debts, and adjust the budget.

## UX Copy (Arabic-First)
- **Privacy Toggle Label:** "اجعل هذا السجل خاصاً" (Make this record private).
- **Helper Text:** "السجلات الخاصة تظهر لك فقط ولا يراها الأعضاء المشاركون." (Private records are only visible to you and cannot be seen by shared members).
- **Restricted Access State:** If a user tries to access a link/notification for a financial item they don't have access to: "ليس لديك صلاحية لعرض هذه البيانات" (You do not have permission to view this data).
