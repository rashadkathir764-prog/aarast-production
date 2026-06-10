# UI Components Specification (Mobile)

This document defines the reusable UI components for the Aarast / اعّرست mobile application. It ensures a consistent, premium, Arabic-first (RTL) experience across all screens.

## Design Language Overview
- **Primary Color:** Deep Burgundy
- **Accent Color:** Warm Gold
- **Background:** Ivory
- **Text:** Dark Charcoal
- **Vibe:** Premium, calm, clear financial hierarchy, tailored for Yemeni weddings.

---

## 1. App Header (AppBar)
- **Purpose:** Provides context, navigation, and top-level actions for the current screen.
- **Visual Style:** Ivory background with Dark Charcoal text for title. Optional back button on the right (RTL). Deep Burgundy accents for action icons.
- **Arabic Label Examples:** الرئيسية (Home), الميزانية (Budget).
- **States:**
  - **Default:** Title and optional actions visible.
  - **Loading:** Skeleton loader for title if dynamically fetched.
- **Flutter Implementation Notes (Later):** Use `AppBar` with `centerTitle: false` (to align right in RTL), transparent or solid Ivory background with no elevation.

## 2. Bottom Navigation
- **Purpose:** Primary navigation between core features (Dashboard, Budget, Tasks, Timeline, Profile).
- **Visual Style:** Ivory background, subtle top shadow. Selected items use Deep Burgundy and Warm Gold, unselected use muted gray/charcoal.
- **Arabic Label Examples:** الرئيسية (Home), المهام (Tasks), الميزانية (Budget).
- **States:**
  - **Default:** Active tab highlighted, inactive tabs faded.
- **Flutter Implementation Notes (Later):** `BottomNavigationBar` or custom wrapper to handle RTL tab ordering naturally.

## 3. Primary Button
- **Purpose:** Main call-to-action (CTA) on a screen (e.g., Save, Submit).
- **Visual Style:** Solid Deep Burgundy background, white/Ivory text. Rounded corners. Premium feel, not overly pill-shaped.
- **Arabic Label Examples:** حفظ (Save), إضافة (Add).
- **States:**
  - **Default:** Solid color.
  - **Loading:** Shows circular progress indicator instead of text.
  - **Disabled:** Muted/grayed out background, unclickable.
  - **Error:** Shake animation or transitions to a red/danger state briefly.
- **Flutter Implementation Notes (Later):** Use `ElevatedButton` with custom `ButtonStyle`.

## 4. Secondary Button
- **Purpose:** Alternative actions (e.g., Cancel, Skip, Outline buttons).
- **Visual Style:** Transparent background, Deep Burgundy or Dark Charcoal border and text.
- **Arabic Label Examples:** إلغاء (Cancel), تخطي (Skip).
- **States:**
  - **Default:** Outlined style.
  - **Loading:** Shows circular progress indicator.
  - **Disabled:** Muted border and text.
- **Flutter Implementation Notes (Later):** Use `OutlinedButton` or `TextButton`.

## 5. Danger Button
- **Purpose:** Destructive actions (e.g., Delete, Remove).
- **Visual Style:** Red text on transparent background, or red outline. For high-impact, solid red background.
- **Arabic Label Examples:** حذف (Delete), إزالة (Remove).
- **States:**
  - **Default:** Red styling.
  - **Disabled:** Muted gray.
  - **Loading:** Spinner.
- **Flutter Implementation Notes (Later):** Custom styled `ElevatedButton` or `OutlinedButton` using semantic error colors.

## 6. Financial Summary Card (Hero & Budget)
- **Purpose:** Displays high-level budget overviews (Total, Paid, Remaining) and overall completion.
- **Visual Style:** 
  - **Hero Card:** Deep Maroon/Burgundy gradient background with a Gold Donut completion chart.
  - **Budget Card:** Donut chart separating Spent (Maroon) and Remaining (Gold).
- **Arabic Label Examples:** إجمالي الميزانية (Total Budget), المنصرف (Spent), المتبقي (Remaining).
- **States:**
  - **Default:** Shows calculated numbers and charts.
  - **Loading:** Shimmer effect on numbers.
  - **Error:** Displays "تعذر تحميل البيانات" (Failed to load data) with a retry icon.
- **Flutter Implementation Notes (Later):** Custom `Card` widgets with `Stack` and `CircularProgressIndicator` or custom painters for donuts. Ensure numbers are formatted with commas and currency symbols appropriate for Yemen (e.g., ر.ي).

## 7. Budget Category Card
- **Purpose:** Shows breakdown of budget by categories (e.g., Venue, Catering).
- **Visual Style:** Minimalist card, icon on the right (RTL), category name, amount spent vs. allocated. Optional progress bar.
- **Arabic Label Examples:** القاعة (Venue), الضيافة (Catering).
- **States:**
  - **Default:** Normal display.
  - **Warning (Over budget):** Progress bar turns red, warning icon appears.
- **Flutter Implementation Notes (Later):** `Card` or `Container` with `LinearProgressIndicator`.

## 8. Expense Item Row
- **Purpose:** Lists individual expense transactions.
- **Visual Style:** Clean list tile. Title, date, and amount. Private items have a subtle lock/privacy badge.
- **Arabic Label Examples:** دفعة أولى للقاعة (First payment for venue).
- **States:** Default, Loading (Shimmer), Error.
- **Flutter Implementation Notes (Later):** Use `ListTile`.

## 9. Debt Item Row
- **Purpose:** Displays debts owed to individuals/vendors.
- **Visual Style:** Similar to Expense row, but highlights "Due Date" prominently. Uses Warm Gold or warning colors if due soon.
- **Arabic Label Examples:** دين لعلي (Debt to Ali).
- **States:** Default, Loading.

## 10. Installment Item Row
- **Purpose:** Displays scheduled installment payments.
- **Visual Style:** Indicates "x of y" payments completed. Shows amount and next due date.
- **Arabic Label Examples:** القسط الثاني (Second installment).
- **States:** Default, Loading, Success (when paid).

## 11. Task Item Row
- **Purpose:** Displays to-do items.
- **Visual Style:** Checkbox on the right (RTL). Title and optional due date.
- **Arabic Label Examples:** حجز المصور (Book the photographer).
- **States:** Default, Completed (strikethrough text, faded), Loading.

## 12. Empty State Card
- **Purpose:** Shown when a list or screen has no data.
- **Visual Style:** Centered, subtle elegant illustration or icon, calm text, and a Primary Button to create the first item.
- **Arabic Label Examples:** لا توجد مصاريف بعد (No expenses yet).
- **States:** Static display.

## 13. Warning Banner
- **Purpose:** Alerts user to important system status or financial warnings (e.g., budget exceeded).
- **Visual Style:** Full-width banner below AppBar. Soft yellow/red background depending on severity, dark text.
- **Arabic Label Examples:** لقد تجاوزت الميزانية المحددة (You have exceeded the set budget).
- **States:** Visible, Dismissed.

## 14. Privacy Badge
- **Purpose:** Indicates that a financial record or item is private and not visible to shared members.
- **Visual Style:** Small lock icon (`lock` or `visibility_off`) placed next to the item title or amount. Subtle gray or Warm Gold.
- **Arabic Label Examples:** خاص (Private).
- **States:** Static icon.

## 15. Arabic Form Field
- **Purpose:** Input for text data (names, descriptions).
- **Visual Style:** RTL aligned by default. Ivory background or subtle underline. Dark Charcoal text. Deep Burgundy focus border.
- **Arabic Label Examples:** اسم العريس (Groom's Name).
- **States:** Default, Focused, Filled, Error (red border + message), Disabled.
- **Flutter Implementation Notes (Later):** `TextFormField` with `TextAlign.right` and `TextDirection.rtl`.

## 16. Date Picker Behavior
- **Purpose:** Selecting dates for tasks, weddings, debts.
- **Visual Style:** Bottom sheet or standard calendar dialog. Must support localized Arabic months/days.
- **Arabic Label Examples:** تاريخ الزفاف (Wedding Date).
- **States:** Default, Selecting, Error (invalid date).
- **Flutter Implementation Notes (Later):** Standard Flutter DatePicker localized to `ar`.

## 17. Amount Input Behavior
- **Purpose:** Specialized numeric input for currency.
- **Visual Style:** Large text, numeric keypad only. Right-to-left numeral entry.
- **Arabic Label Examples:** المبلغ (Amount).
- **States:** Default, Error (negative or invalid amounts).
- **Flutter Implementation Notes (Later):** `TextFormField` with `keyboardType: TextInputType.number`.
