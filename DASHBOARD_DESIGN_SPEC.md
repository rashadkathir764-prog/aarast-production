# Dashboard Design Specification

The Dashboard is the heart of the Aarast / اعّرست app. It provides a comprehensive, at-a-glance view of the wedding's financial and logistical health.

## Visual Hierarchy & Layout
The layout flows from top (high-level summary) to bottom (immediate actions and upcoming items), following an RTL structure.

---

## 1. Header Section
- **Wedding Name:** Displayed prominently at the top right.
- **Days Remaining:** A badge or prominent text indicating countdown. Example: "باقي ٤٥ يوم" (45 days left). Uses Warm Gold for emphasis.
- **Wedding Date:** Displayed subtly under the wedding name.

## 2. Financial Summary (The "Wallet" Card)
A premium, elevated card displaying core financials.
- **Estimated Budget:** The total planned amount.
- **Paid Amount:** How much has been spent so far.
- **Remaining Amount:** The balance remaining from the budget.
- **Visuals:** Uses Deep Burgundy background with Ivory/White text for the primary owner view to feel premium and distinct.

## 3. Quick Actions (Floating or Grid)
A horizontal scrolling list or a 2x2 grid of primary actions for fast data entry:
- **Add Expense** (إضافة مصروف)
- **Add Debt** (إضافة دين)
- **Add Installment** (إضافة قسط)
- **Add Task** (إضافة مهمة)

## 4. Warnings and Alerts (Dynamic Banner)
Appears only when conditions are met. Placed below the financial summary.
- **Budget Exceeded Warning:** Red/Soft red banner indicating the user has spent more than allocated.
- **Due Items Late:** Warning for overdue debts, installments, or critical tasks.

## 5. "Due Soon" Section
A consolidated list of urgent items coming up in the next 7-14 days.
- **Debts Due Soon:** Highlighted with a subtle warning icon.
- **Installments Due Soon:** Shows amount and who it is owed to.
- **Tasks Due Soon:** High-priority checkboxes.

## 6. Privacy Reminders
- If the user is the Owner, a subtle banner or badge at the bottom or top of the financial card states: "أنت تشاهد لوحة التحكم بصلاحيات المالك. البيانات المالية مخفية عن الأعضاء." (You are viewing the dashboard as Owner. Financial data is hidden from members).

## 7. Empty Dashboard (First-Use Layout)
When a user first creates an account and wedding plan:
- The Financial Summary shows zeros.
- The "Due Soon" section is replaced with an elegant onboarding illustration.
- A prominent "Get Started" checklist appears:
  1. Set your total budget
  2. Add your first expense
  3. Create your first task
- **Vibe:** Encouraging, not overwhelming.

---

## Design Principles
- **Clarity over Clutter:** Do not show everything at once. Use "See All" buttons for lists.
- **No Marketplace Elements:** The MVP dashboard is strictly a Financial OS and planner. No vendor ads or bookings.
- **Calm Finances:** Even if a user is over budget, the UI should remain elegant—no aggressive red flashing lights. Use subtle semantic colors.
