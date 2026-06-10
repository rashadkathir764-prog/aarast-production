# Aarast Mobile Screen Wireframes

This document details the layout and components of the core MVP screens. All layouts assume Right-to-Left (RTL) direction.

## 1. Splash Screen
- **Purpose**: Brand introduction while app loads.
- **Main Sections**: Central logo, soft Ivory background.
- **Important UI Components**: App Logo, subtle loading indicator (Deep Burgundy).
- **States**: Transitions automatically to Onboarding or Dashboard depending on auth state.
- **Arabic Labels**: "اعّرست" (Aarast)

## 2. Onboarding Screens
- **Purpose**: Explain the app's value.
- **Main Sections**: Illustration/Icon (top), Title (middle), Description (middle-bottom), Controls (bottom).
- **Important UI Components**: Carousel dots, "Next" primary button, "Skip" text button.
- **Arabic Labels**: "التالي" (Next), "تخطي" (Skip), "ابدأ الآن" (Start Now).

## 3. Login Screen
- **Purpose**: User authentication.
- **Main Sections**: Header (Welcome back), Form, Footer (Register link).
- **Important UI Components**: Email/Phone input, Password input, "Login" primary button, "Forgot Password" link.
- **Error State**: Red border on inputs, error text below inputs.
- **Arabic Labels**: "تسجيل الدخول" (Login), "رقم الهاتف أو البريد الإلكتروني" (Phone/Email), "كلمة المرور" (Password), "ليس لديك حساب؟ سجل هنا" (Don't have an account? Register here).

## 4. Register Screen
- **Purpose**: Create a new account.
- **Main Sections**: Header, Form (Name, Phone/Email, Password, Confirm Password), Footer (Login link).
- **Primary Action**: "إنشاء حساب" (Create Account) button.
- **Arabic Labels**: "الاسم الكامل" (Full Name), "إنشاء حساب" (Create Account), "لديك حساب بالفعل؟ تسجيل الدخول" (Already have an account? Login).

## 5. Create Wedding Plan Screen
- **Purpose**: Initial data gathering for the wedding.
- **Main Sections**: Form fields for basic wedding details.
- **Important UI Components**: Date picker, numeric input for budget.
- **Primary Action**: "حفظ ومتابعة" (Save and Continue).
- **Arabic Labels**: "اسم العريس" (Groom Name), "اسم العروس" (Bride Name), "تاريخ الزفاف المتوقع" (Expected Wedding Date), "الميزانية التقديرية" (Estimated Budget).

## 6. Wedding Plan Dashboard
- **Purpose**: High-level overview of everything important with an elegant, premium look.
- **Main Sections**:
  - **Header**: Custom greeting (e.g., "مساء الخير، رشاد 💛") + App Logo ("أعرسِت") + Notification Bell with red dot.
  - **Hero Card (Progress Card)**: Maroon gradient background with a Gold Donut progress chart, wedding title, remaining days, and an action link ("استكمال المهام >").
  - **Mini Stats (نظرة سريعة)**: 2x2 grid in pastel colors (Vendors/Green, Tasks/Red, Guests/Orange, Payments/Purple).
  - **Budget Donut (ملخص الميزانية)**: Donut chart displaying Spent vs. Remaining (Maroon/Gold).
  - **Quick Actions (إجراءات سريعة)**: Horizontally scrollable list of circular outlined action buttons.
  - **Alerts/Notes**: Vertical list of soft-colored note cards.
  - **Shared Plans**: Overlapping avatars for shared members.
  - **Bottom Navigation**: Custom white bar with an elevated central FAB (+) in maroon.
- **Arabic Labels**: "نظرة سريعة" (Quick Glance), "ملخص الميزانية" (Budget Summary), "المنصرف" (Spent), "المتبقي" (Remaining), "إجراءات سريعة" (Quick Actions), "الموردين" (Vendors), "المهام" (Tasks).
- **Implementation Note**: The dashboard layout strictly follows the "Image 2" visual blueprint, avoiding the deprecated "Claude Design" entirely.

## 7. Budget Overview Screen
- **Purpose**: Detailed breakdown of the budget.
- **Main Sections**: Total Budget vs Spent visual (progress bar/ring), List of Categories with amounts.
- **Important UI Components**: Add Category button, Category list items showing budget vs actual.
- **Arabic Labels**: "تفاصيل الميزانية" (Budget Details), "الفئات" (Categories).

## 8. Expenses Screen
- **Purpose**: List and manage all expenses.
- **Main Sections**: Filter/Sort (Date, Category), List of expense cards.
- **Important UI Components**: Expense Card (Title, Category, Total, Paid, Date). Floating Action Button (FAB) to add new.
- **Empty State**: "لا توجد منصرفات بعد" (No expenses yet) + illustration.
- **Arabic Labels**: "المنصرفات" (Expenses), "تاريخ" (Date), "إضافة منصرف جديد" (Add New Expense).

## 9. Debts Screen
- **Purpose**: Track borrowed money.
- **Main Sections**: Total Debt Summary, List of Creditors/Debts.
- **Important UI Components**: Debt Card (Creditor name, Total debt, Remaining to pay, Due date).
- **Arabic Labels**: "الديون" (Debts), "الدائن" (Creditor), "المبلغ الإجمالي" (Total Amount), "المتبقي للسداد" (Remaining to Pay).
- **Privacy Note**: Visually mark these items as private (e.g., a subtle lock icon) indicating shared members cannot see this.

## 10. Installments Screen
- **Purpose**: Track specific repayment plans or vendor installments.
- **Main Sections**: List of active installment plans, upcoming payments.
- **Important UI Components**: Progress bar per installment plan.
- **Arabic Labels**: "الأقساط" (Installments), "القسط القادم" (Next Installment), "تاريخ الاستحقاق" (Due Date).

## 11. Tasks Screen
- **Purpose**: Manage wedding to-dos.
- **Main Sections**: Tabs (Pending, Completed), List of tasks.
- **Important UI Components**: Checkbox list items. Warning color for due soon, Danger for overdue.
- **Arabic Labels**: "المهام" (Tasks), "قيد الانتظار" (Pending), "مكتملة" (Completed), "أضف مهمة" (Add Task).

## 12. Timeline / Due Dates Screen
- **Purpose**: Chronological view of upcoming financial and task obligations.
- **Main Sections**: Vertical timeline layout.
- **Important UI Components**: Timeline nodes (Tasks, Payment due dates).
- **Arabic Labels**: "الجدول الزمني" (Timeline), "الاستحقاقات القادمة" (Upcoming Due Dates).

## 13. Profile / Settings Screen
- **Purpose**: Manage account and app preferences.
- **Main Sections**: User Info, Wedding Settings, Members, Logout.
- **Important UI Components**: Standard list items with trailing chevron icons.
- **Arabic Labels**: "الملف الشخصي" (Profile), "الإعدادات" (Settings), "تعديل تفاصيل الزفاف" (Edit Wedding Details), "تسجيل الخروج" (Logout).

## 14. Privacy and Shared Members (Placeholder)
- **Purpose**: Manage who sees what (future feature).
- **Main Sections**: List of invited members, Permission toggles.
- **Important UI Components**: Switch toggles, "Invite Member" button.
- **Empty State**: "لم تقم بدعوة أي شخص بعد" (You haven't invited anyone yet).
- **Arabic Labels**: "الأعضاء والصلاحيات" (Members and Permissions), "دعوة عضو" (Invite Member), "صلاحية العرض" (View Permission).
- **Future Note**: Default state for financial toggles must be OFF.
