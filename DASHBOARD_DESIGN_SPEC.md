# Dashboard Design Specification

The Dashboard is the heart of the Aarast / اعّرست app. It provides a comprehensive, at-a-glance view of the wedding's financial and logistical health.

## Visual Hierarchy & Layout
The layout flows from top (high-level summary) to bottom (immediate actions and upcoming items), following an RTL structure.

---

## 1. Header Section
- **Welcome Message:** "مساء الخير، رشاد 💛" (or current user's name).
- **Logo/Title:** "أعرسِت" displayed prominently at the top right in an elegant custom font.
- **Notification Bell:** With a red notification dot at the top left.
- **Profile Avatar:** User's avatar next to the notification bell.

## 2. Hero Card (The Progress Card)
A premium, elevated card displaying overall completion.
- **Background:** Deep Burgundy/Maroon subtle gradient with a light pattern.
- **Completion Ring:** A circular progress chart (Donut) on the left side, using Gold for the filled portion and a darker maroon for the track. Inside the ring: "٪XX اكتمل".
- **Main Text:** "خطة زفاف [اسم العريس]" on the right.
- **Remaining Days:** "تبقى XX يوم" below the title.
- **Action Link:** "استكمال المهام >" at the bottom left.

## 3. Mini Stats Grid (نظرة سريعة)
A 2x2 grid of small pastel-colored cards on the left side (or right, depending on layout split):
- **Vendors (الموردين):** Soft Green background, Green icon.
- **Tasks (المهام):** Soft Red/Pink background, Red icon.
- **Guests (الضيوف):** Soft Orange background, Orange icon.
- **Payments (المدفوعات):** Soft Purple/Blue background, Purple icon.

## 4. Budget Summary (ملخص الميزانية)
A card adjacent to the mini stats grid.
- **Budget Donut Chart:** A half-donut or full donut chart showing "المنصرف" (Spent) vs "المتبقي" (Remaining).
- **Colors:** Deep Burgundy for Spent, Gold for Remaining.

## 5. Quick Actions (إجراءات سريعة)
A horizontal scrolling list of circular buttons.
- **Design:** Circular outlined buttons (border color matches the icon color), transparent background.
- **Icons & Labels:**
  - Add Expense (إضافة مصروف) - Maroon/Burgundy
  - Add Debt (إضافة دين) - Deep Blue
  - Add Installment (إضافة قسط) - Green
  - Add Task (إضافة مهمة) - Orange

## 6. Alerts & Notes (تنبيهات / ملاحظات)
A vertical list of soft-colored cards.
- **Design:** Soft gray/white background, with a colored dot indicator on the right.
- **Content:** Title on the right, time/date on the left.

## 7. Shared Plans (الخطط المشتركة)
Shows avatars of members sharing the plan.
- **Design:** Overlapping circular avatars.

## 8. Bottom Navigation
A clean white bottom navigation bar with a central prominent floating action button (+).
- **Items:** Home, Vendors, (Space for FAB), Tasks, More.
- **Active State:** Deep Burgundy icon and bold text.
- **FAB:** A circular button with a Deep Burgundy background, elevated, positioned slightly above the bar.

---

## Design Principles
- **Clarity over Clutter:** Use spacing and pastel colors to separate information without heavy borders.
- **Premium Feel:** The use of Burgundy, Gold, and a creamy background gives a luxurious yet calm feeling appropriate for weddings.
- **RTL First:** All alignments are right-to-left.
