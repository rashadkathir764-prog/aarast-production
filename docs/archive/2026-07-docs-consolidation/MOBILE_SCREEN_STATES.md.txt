# Mobile Screen States Specification

This document defines the possible states for each screen in the Aarast / اعّرست MVP. Handling these states gracefully is essential for a premium user experience.

## Global States Defined
- **Loading:** Data is being fetched or processed. Should use Shimmer effects for content, or circular spinners for actions.
- **Empty:** No data exists yet (e.g., first login, no expenses added). Must have clear empty state illustrations/text and a CTA.
- **Error:** API failure, invalid input, or unexpected crash. Must allow recovery/retry.
- **Success:** Operation completed successfully. Often transient (e.g., Snackbar) or updates the UI to reflect new data.
- **Offline/No Internet:** Network is unavailable. Show cached data if possible with a subtle offline indicator, or block actions that require network.
- **Permission/Private-Data:** User does not have access to view this data (applies to shared members in future).

---

## Screen-by-Screen State Breakdown

### 1. Splash
- **Loading:** Show logo and Deep Burgundy background.
- **Error:** N/A (Transitions automatically).
- **Offline:** Can transition to Offline mode if auth check fails due to network, but typically falls back to Login.

### 2. Onboarding
- **Loading:** Image assets loading.
- **Empty/Default:** Swiping through features.
- **Success:** User clicks "Start/Next" and finishes onboarding.

### 3. Login
- **Loading:** "Sign In" button shows spinner; inputs disabled.
- **Error:** Invalid credentials show inline form error or Snackbar.
- **Success:** Transitions to Dashboard.
- **Offline:** Snackbar indicating "لا يوجد اتصال بالإنترنت" (No internet connection).

### 4. Register
- **Loading:** Button shows spinner.
- **Error:** Validation errors (e.g., weak password, email taken).
- **Success:** Transitions to "Create Wedding Plan" or Dashboard.

### 5. Create Wedding Plan
- **Loading:** Saving plan data.
- **Error:** Validation error (missing name, date).
- **Success:** Navigates to Dashboard.

### 6. Dashboard
- **Loading:** Shimmer effect over financial cards and task lists.
- **Empty:** "First-use layout." Shows "Welcome to your wedding plan. Add your budget to get started" with a large CTA.
- **Error:** Failed to load dashboard data. Show "إعادة المحاولة" (Retry) button.
- **Offline:** Show cached dashboard data with a small banner: "أنت في وضع عدم الاتصال" (You are offline).
- **Permission:** If shared member has limited access, hide financial summary cards completely and show "Tasks Only" view.

### 7. Budget
- **Loading:** Shimmer on category list.
- **Empty:** No categories defined. Prompt: "أضف فئة جديدة" (Add a new category).
- **Error:** Retry fetching budget data.

### 8. Expenses
- **Loading:** Shimmer on expense rows.
- **Empty:** No expenses recorded. Illustration of an empty wallet/receipt with "إضافة مصروف" (Add Expense) button.
- **Permission:** Shared members see only public expenses. Private expenses are completely hidden from the list (no empty gaps).

### 9. Debts
- **Loading:** Shimmer on debt rows.
- **Empty:** "لا توجد ديون مسجلة" (No debts recorded).
- **Error:** Retry button.

### 10. Installments
- **Loading:** Shimmer effect.
- **Empty:** No upcoming installments.
- **Success:** After marking an installment as paid, show a checkmark animation briefly.

### 11. Tasks
- **Loading:** Skeleton list.
- **Empty:** "لا توجد مهام حالياً" (No tasks currently). CTA to add task.
- **Success:** Checking off a task plays a micro-animation (e.g., strikethrough, checkmark pop) and moves it to completed.

### 12. Timeline
- **Loading:** Shimmer on timeline nodes.
- **Empty:** Timeline empty (if no dated tasks/events exist).
- **Offline:** Read-only cached timeline.

### 13. Profile / Settings
- **Loading:** Fetching user details.
- **Error:** Failed to update profile (Snackbar).
- **Success:** Profile updated (Snackbar: "تم الحفظ بنجاح").

### 14. Shared Members (Placeholder)
- **Loading:** Fetching list of invitees.
- **Empty:** "لم تقم بدعوة أي شخص بعد" (You haven't invited anyone yet).
- **Error:** Failed to send invite.
