# Aarast Task Templates

Date: 2026-06-19
Stage: Task Templates
Status: Planning document only

## 1. Decision

Task templates should be generated from wedding date and priorities. They must give the user a useful first plan without forcing manual task entry.

## 2. Template Fields

Suggested fields:

- key.
- title.
- description.
- category.
- priority.
- due offset from wedding date.
- phase label.
- persona copy overrides.
- optional budget/provider category link.

## 3. Timeline Templates

### Before 6 Months

- تحديد الميزانية التقريبية.
- اختيار القاعة.
- البحث عن المصور.
- تحديد قائمة مبدئية للضيوف.
- تحديد أولويات المصاريف.

### Before 3 Months

- تأكيد المطعم أو العشاء.
- تجهيز الدعوات.
- اختيار الكوشة والديكور.
- متابعة المصروفات المفتوحة.
- مراجعة الديون والأقساط.

### Before 1 Month

- تأكيد الموردين.
- إرسال الدعوات.
- تأكيد قائمة الضيوف.
- مراجعة الأقساط القريبة.
- ترتيب جدول يوم الزفاف.

### Before 1 Week

- تأكيد الحضور النهائي.
- مراجعة جدول اليوم.
- دفع المتبقي إن وجد.
- تجهيز قائمة الطوارئ.
- تأكيد التواصل مع الموردين.

## 4. Priority Rules

- Budget priority adds more finance tasks.
- Debt/installment priority adds payment review tasks.
- Guest priority adds guest list/invitation tasks.
- Provider priority adds shortlist/quote tasks.
- Sharing priority adds invite family/helper task.

## 5. Persona Copy Examples

| Task | Groom | Bride | Helper |
|---|---|---|---|
| Budget | حدد الميزانية التقريبية | حددي الميزانية التقريبية | ساعد في ضبط الميزانية |
| Guests | أضف قائمة الضيوف الأولى | أضيفي قائمة الضيوف الأولى | ساعد في ترتيب الضيوف |
| Providers | اطلب عرض سعر من مورد مناسب | اطلبي عرض سعر من مورد مناسب | تابع عروض الموردين |

## 6. Generation Rules

- Do not duplicate template if task already exists.
- If wedding date missing, use phase buckets without exact due date.
- Generated tasks should be editable.
- User can skip generated tasks.
- Do not generate too many tasks at first launch.

## 7. Acceptance Criteria

- Template fields are defined.
- Timeline examples are defined.
- Priority and persona rules are documented.
- Generation rules are documented.
- No seed scripts or code are changed.

## 8. Risks

- Too many generated tasks overwhelm users.
- Bad due-date offsets create mistrust.
- Duplicate generation can clutter plans.
- Persona copy needs content system integration.

## 9. Next Implementation Notes

- Next stage: `docs/architecture/FEATURE_FLAGS_PLAN.md`.
- Future implementation should start with a small, testable template set.

