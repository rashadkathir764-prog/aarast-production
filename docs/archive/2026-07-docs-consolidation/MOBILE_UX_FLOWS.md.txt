# Aarast Mobile UX Flows

## 1. User Onboarding Flow
1. **Splash Screen**: Logo and brand colors. Loads app data.
2. **Onboarding Carousel** (3 screens):
   - Welcome to Aarast (Value proposition).
   - Manage your wedding budget clearly.
   - Keep track of tasks and debts easily.
3. **Authentication**:
   - Register (Phone number/Email, Password, Name).
   - Login (if existing user).
4. **Initial Setup (Create Wedding Plan)**:
   - Enter Partner Names (Groom & Bride).
   - Enter estimated Wedding Date.
   - Enter initial estimated total Budget.
5. **Success**: "Wedding created successfully" -> Redirect to Dashboard.

## 2. Core Financial Flow (Adding an Expense)
1. User taps floating action button (FAB) or "Add Expense" from Dashboard/Budget screen.
2. Bottom sheet or new screen opens: "Add New Expense".
3. User enters:
   - Title (e.g., "Hall Rental").
   - Category (dropdown: Venue, Food, Attire, etc.).
   - Total Amount.
   - Paid Amount (optional, defaults to 0).
4. User taps "Save".
5. App updates Budget Overview, Remaining amount, and shows success toast.

## 3. Debt & Installment Flow
1. User navigates to "Debts" tab.
2. User taps "Add Debt".
3. User enters:
   - Creditor Name (e.g., "Uncle Ahmed").
   - Total Amount Borrowed.
   - Expected Repayment Date (optional).
4. User taps "Save".
5. To log a repayment (Installment):
   - User taps on the specific Debt in the list.
   - Taps "Add Payment".
   - Enters amount paid and date.
   - Debt remaining balance updates automatically.

## 4. Task Management Flow
1. User navigates to "Tasks" tab.
2. User taps "Add Task".
3. User enters:
   - Task Title (e.g., "Book Photographer").
   - Due Date.
   - Notes (optional).
4. Task appears in list (grouped by upcoming/overdue).
5. User taps checkbox to mark as complete (Success color applied).

## 5. Privacy & Member Sharing Flow (Placeholder/Future)
1. User navigates to "Profile / Settings".
2. Taps "Manage Members".
3. Sees list of invited users (e.g., Bride, Brother).
4. For each user, UI shows toggle switches for visibility (Future implementation):
   - [ ] Can view total budget
   - [ ] Can view debts
   - [ ] Can view expenses
   - [x] Can view tasks
5. Note: Financial data remains completely private to the owner by default unless explicitly toggled on.
