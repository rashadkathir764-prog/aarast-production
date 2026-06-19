# Aarast / أعرست — Mobile Product, UX & Architecture Rebuild README

> **المسار المقترح داخل المشروع:**  
> `docs/mobile-ux/README_AARAST_MOBILE_PRODUCT_UX_REBUILD.md`

---

## 0. الغرض من هذا الملف

هذا الملف هو **مرجع العمل الرسمي** لإعادة ترتيب وتطوير تجربة موبايل مشروع **Aarast / أعرست**.

الغرض منه ليس تجميل الواجهة فقط، بل تثبيت المنتج كمنظومة متكاملة:

- تفهم المستخدم من أول دخول.
- تبني له خطة زفاف حقيقية.
- تربط المال، المهام، الضيوف، الموردين، الإشعارات، الموقع، الصلاحيات، والخصوصية.
- تمنع التكرار والفوضى في التنقل.
- تحدد متى نصلح شاشة ومتى نعيد بناءها.
- تعطي Codex / AI Agent / المطورين قواعد تنفيذ واضحة.
- تمنع الرجوع إلى الترقيع العشوائي.

---

## 1. القرار النهائي للمشروع

مشروع **أعرست** لا يجب أن يكون مجموعة شاشات جميلة فقط.

أعرست يجب أن يكون:

> **نظام إدارة زفاف مترابط، يبدأ بفهم المستخدم، يبني له خطة، ثم يوجهه يومياً ويربط ماله ومهامه وضيوفه ومورديه وإشعاراته وصلاحياته وموقعه وخصوصيته.**

أي تنفيذ جديد يجب أن يخدم هذا الاتجاه.

---

## 2. الوضع الحالي المختصر

الوضع الحالي للموبايل:

- يوجد Backend حقيقي ومتقدم نسبياً.
- توجد شاشات كثيرة في Flutter.
- توجد شاشات جيدة الاتجاه مثل المال، الموردين، خططي، والمزيد جزئياً.
- توجد شاشات خام أو تحتاج إعادة تنظيم مثل المهام، الضيوف، المشاركة، الإشعارات، والنماذج.
- الشاشة الأخطر حالياً هي **Home Dashboard** لأنها مزدحمة، غير موجهة، وتعرض كروت كثيرة بدون أولوية واضحة.
- يوجد تضارب بيانات بين الشاشات، مثل اختلاف نسبة التقدم أو الأيام المتبقية بين Home و My Plans.
- بعض عناصر UX ظهرت كمخطط بناء / Wireframe، وهذا كان مقصوداً مؤقتاً لفصل المنطق عن التجميل.
- المشكلة ليست الألوان فقط؛ المشكلة أن تجربة المنتج تحتاج إعادة تأسيس منطقية.

---

## 3. القاعدة الصارمة

لا ننفذ شاشة جميلة قبل أن نعرف:

1. من يستخدمها؟
2. لماذا يحتاجها؟
3. من أين يدخل إليها؟
4. ما البيانات التي تعرضها؟
5. ما الإجراء الأساسي فيها؟
6. ماذا يحدث بعد الإجراء؟
7. هل تحتاج حساباً؟
8. هل تعمل Offline؟
9. هل تختلف للعريس والعروسة والمساعد والمزود؟
10. هل تدعمها قاعدة البيانات والـ Backend؟

---

## 4. مبادئ العمل الثابتة

### 4.1 لا تنفيذ قبل Blueprint

قبل أي تعديل برمجي يجب وجود:

- Product Logic Blueprint.
- UX Blueprint.
- Navigation Blueprint.
- Acceptance Criteria واضحة.

### 4.2 لا ترقيع عشوائي

ليس كل شيء نصلحه. أحياناً إعادة البناء أفضل من إصلاح شاشة مبنية غلط.

### 4.3 لا تكرار مداخل

لا نكرر نفس العملية من أماكن كثيرة بشكل مربك.

مثال:

- إضافة مصروف لا تظهر من 10 أماكن.
- طلب عرض سعر لا يظهر في أماكن بلا سياق.
- الانضمام كمزود لا يظهر للمستخدم العادي في كل صفحة.

### 4.4 لا حساب إجباري عند البداية

المستخدم يبدأ كضيف. نطلب الحساب فقط عندما يحتاج:

- حفظ سحابي.
- طلب عرض سعر.
- مشاركة خطة.
- إشعارات.
- مزامنة.
- أعضاء.
- بيانات حساسة طويلة المدى.

### 4.5 المستخدم والمزود مساران مختلفان

أول تشغيل يجب أن يحدد:

- أريد تنظيم زفافي.
- أنا مزود خدمة.

ولا نخلط المسارين داخل نفس الواجهة.

### 4.6 الخطاب العربي حسب الشخصية

المستخدم يحدد:

- عريس.
- عروسة.
- مساعد / مساهم.

والتطبيق يخاطبه بناءً على ذلك:

- العريس: أضف، حدد، خطتك.
- العروسة: أضيفي، حددي، خطتكِ.
- المساعد: ساعد في، تابع، المهمة المسندة لك.
- المزود: أدر خدمتك، أرسل عرضك.

### 4.7 الموقع أساس في المنتج

المدينة والحي والشارع ليست حقول شكلية. هي أساس اقتراح المزودين القريبين.

### 4.8 أي رقم يظهر في أكثر من شاشة له مصدر واحد

لا نحسب الأيام المتبقية، نسبة الإنجاز، إجمالي الميزانية، المصروف، أو المهام المتأخرة في كل شاشة بطريقة مختلفة.

يجب وجود Single Source of Truth.

---

## 5. الهيكل النهائي عالي المستوى

الترتيب النهائي للعمل:

1. Current State Audit.
2. Product Logic Blueprint.
3. UX Blueprint.
4. Navigation Blueprint.
5. Roles & Permissions.
6. Data Model Blueprint.
7. Backend Flow Blueprint.
8. Auth & Guest Strategy.
9. Location & Provider Matching.
10. Notifications Blueprint.
11. Design System.
12. State Management Plan.
13. Single Source of Truth Plan.
14. Error / Loading / Empty States Guide.
15. Offline & Sync Plan.
16. Security & Privacy Plan.
17. Admin & Provider Operations.
18. Content System.
19. Data Seeding.
20. Task Templates.
21. Feature Flags.
22. Migration Plan.
23. Mobile Implementation Plan.
24. Testing & QA Plan.
25. Performance Plan.
26. Observability / Logs.
27. Release Plan.
28. Analytics Plan.
29. Monetization Later.
30. Legal / Support / Disputes.
31. Visual Polish.
32. Agent Execution Rules.

---

# PART A — Product Direction

---

## 6. Product Logic Blueprint

### 6.1 هدف المنتج

أعرست ليس:

- تطبيق مهام فقط.
- تطبيق مصاريف فقط.
- Marketplace فقط.
- دفتر ضيوف فقط.

أعرست هو:

> Wedding Management OS — نظام إدارة زفاف شامل، يربط التخطيط المالي، المهام، الموردين، الضيوف، الإشعارات، والمشاركة.

### 6.2 رحلة المستخدم الأساسية

1. يفتح التطبيق.
2. تظهر شاشة ترحيب.
3. يختار نوع الدخول: أريد تنظيم زفافي / أنا مزود خدمة.
4. إذا اختار تنظيم زفافي، يختار الشخصية: عريس / عروسة / مساعد.
5. يحدد الموقع: المحافظة، المدينة/المديرية، الحي، الشارع، وصف إضافي.
6. يحدد تاريخ الزواج.
7. يحدد أولوياته.
8. يحدد الميزانية التقريبية أو يتخطى.
9. يختار تصنيفات ميزانية جاهزة.
10. يتم إنشاء خطة مبدئية.
11. يدخل Dashboard مبني على البيانات.
12. عند أول عملية تحتاج حساباً، يظهر Gate للتسجيل.
13. بعد التسجيل، تنتقل بيانات الضيف إلى الحساب.

### 6.3 رحلة المزود الأساسية

1. يفتح التطبيق.
2. يختار: أنا مزود خدمة.
3. يدخل إلى مسار المزود.
4. ينشئ أو يكمل ملفه: الاسم التجاري، الفئة، المدينة، مناطق الخدمة، رقم التواصل، وصف الخدمة، صور أعمال لاحقاً.
5. حالة المزود تكون: قيد المراجعة / مقبول / موثق / موقوف / مرفوض.
6. يرى طلبات عروض السعر.
7. يرسل عرض سعر.
8. يتابع العروض المقبولة.

### 6.4 متى نطلب الحساب؟

نطلب الحساب عند:

- طلب عرض سعر.
- مشاركة الخطة.
- إضافة عضو.
- حفظ الخطة سحابياً.
- تفعيل الإشعارات.
- مزامنة البيانات.
- قبول عرض مزود.
- حفظ بيانات حساسة لفترة طويلة.

### 6.5 ما الذي يمنع؟

ممنوع:

- Dashboard فارغ عند أول دخول.
- حساب إجباري في البداية.
- “انضم كمزود” مكرر للمستخدم العادي.
- نصوص تقنية طويلة.
- أرقام متضاربة.
- AI Card غير مفعّل.
- Empty States بلا إجراء.

---

## 7. UX Blueprint

لكل شاشة يجب توثيق:

- الهدف.
- المستخدم المستهدف.
- نقطة الدخول.
- البيانات.
- الإجراء الأساسي.
- الإجراء الثانوي.
- Empty State.
- Loading State.
- Error State.
- Success State.
- هل تحتاج حساب؟
- هل تعمل Offline؟
- هل النص يتغير حسب persona؟
- هل لها Deep Link من إشعار؟

### 7.1 Onboarding Screens

#### 7.1.1 Welcome

الهدف: تهنئة المستخدم، شرح بسيط، وعدم طلب الحساب.

النص المقترح:

> ألف مبروك، خلينا نرتب زفافك خطوة بخطوة.

الإجراء: ابدأ الآن.

#### 7.1.2 Choose Path

الخيارات:

1. أريد تنظيم زفافي.
2. أنا مزود خدمة.

الغرض: فصل مسار المستخدم عن المزود ومنع تكرار CTA “انضم كمزود” داخل صفحات المستخدم.

#### 7.1.3 Persona

للمستخدم العادي:

- العريس.
- العروسة.
- مساعد / مساهم.

الاستخدام: صيغة الخطاب، ترتيب الأولويات، الصلاحيات لاحقاً، ومحتوى الداشبورد.

#### 7.1.4 Location Setup

الحقول:

- المحافظة.
- المدينة / المديرية.
- الحي.
- الشارع.
- وصف إضافي.
- زر: استخدم موقعي لاحقاً.

الشروط:

- اقتراحات للمدن.
- اقتراحات للمناطق.
- عدم الاعتماد على خرائط ثقيلة في البداية.
- حفظ الموقع مع الخطة.

#### 7.1.5 Wedding Date

الخيارات:

- اختر التاريخ يدوياً.
- بعد شهر.
- بعد 3 أشهر.
- بعد 6 أشهر.
- بعد سنة.

بعد الاختيار:

- حساب الأيام المتبقية.
- تجهيز Timeline.
- اقتراح مهام.

#### 7.1.6 Priorities

الخيارات:

- الميزانية والمصاريف.
- الديون والأقساط.
- المهام والمواعيد.
- الضيوف.
- الموردين القريبين.
- مشاركة الخطة مع العائلة.

الاستخدام: ترتيب Dashboard حسب اهتمام المستخدم واقتراح أول خطوة بعد إنشاء الخطة.

#### 7.1.7 Budget Setup

الحقول:

- العملة.
- الميزانية التقريبية.
- زر تخطي الآن.

القواعد:

- لا نجبر المستخدم على توزيع كامل للميزانية.
- لو تخطى، تظهر خطوة إكمال لاحقاً.

#### 7.1.8 Suggested Categories

تصنيفات يمنية جاهزة:

- القاعة.
- المطعم / العشاء.
- التصوير.
- الكوشة.
- الفستان.
- البدلة.
- الذهب.
- الحناء.
- الزفة.
- الدعوات.
- النقل.
- الضيافة.
- شهر العسل.
- تجهيز البيت.
- الطوارئ.

الإجراء: اختيار التصنيفات ثم إنشاء الخطة.

#### 7.1.9 Generated Dashboard

لا يكون فارغاً.

يعرض:

- اسم الخطة.
- تاريخ الزواج.
- الأيام المتبقية.
- المدينة.
- الميزانية إن وجدت.
- الأولويات.
- الخطوة التالية.
- أهم تنبيه أو مهمة.

---

## 8. Navigation Blueprint

### 8.1 Bottom Navigation للمستخدم

1. الرئيسية.
2. المال.
3. المهام.
4. الموردون.
5. المزيد.

### 8.2 Bottom Navigation للمزود

1. الرئيسية.
2. الطلبات.
3. العروض.
4. ملفي.
5. المزيد.

### 8.3 زر الإضافة +

لا يكون غامضاً.

للمستخدم:

- إضافة مصروف.
- إضافة مهمة.
- إضافة ضيف.
- إضافة دين.
- طلب عرض سعر.

القواعد:

- لا يكرر كل شيء في كل شاشة.
- لا يظهر إجراء خارج السياق.
- لا يكون بديلًا عن تنظيم Navigation.
- الإجراءات المتخصصة تظهر داخل صفحاتها أيضاً عند الضرورة فقط.

### 8.4 مداخل العمليات

| العملية | المدخل الصحيح |
|---|---|
| إضافة مصروف | صفحة المال + زر + |
| إضافة دين | صفحة المال + زر + |
| إضافة مهمة | صفحة المهام + زر + |
| إضافة ضيف | صفحة الضيوف/الضيوف داخل المزيد + زر + |
| طلب عرض سعر | صفحة الموردين + زر + إذا كان السياق مناسب |
| تعديل الخطة | خططي / المزيد |
| مشاركة الخطة | شاشة المشاركة فقط |
| إعدادات الحساب | المزيد |
| إعدادات المزود | مسار المزود فقط |

---

# PART B — Roles, Data, Backend

---

## 9. Roles & Permissions

### 9.1 النوع الرئيسي

- User.
- Provider.

### 9.2 Persona للمستخدم

- Groom / العريس.
- Bride / العروسة.
- Helper / مساعد.

### 9.3 صلاحيات داخل الخطة

- Owner / مالك.
- Editor / محرر.
- Viewer / مشاهد فقط.
- Finance Manager / مسؤول المال.
- Task Manager / مسؤول المهام.
- Guest Manager / مسؤول الضيوف.
- Provider Manager / مسؤول الموردين.

### 9.4 قواعد الصلاحيات

- المشاهد لا يعدل.
- مسؤول المال لا يرى بالضرورة الضيوف.
- مسؤول الضيوف لا يرى الديون إلا بصلاحية.
- المزود لا يرى الخطة كاملة.
- المزود يرى فقط تفاصيل الطلب المرسل له.

---

## 10. Data Model Blueprint

### 10.1 الكيانات الأساسية

- User.
- UserProfile.
- WeddingPlan.
- PlanMember.
- Location.
- BudgetCategory.
- Expense.
- Debt.
- Installment.
- Task.
- Guest.
- Provider.
- ProviderProfile.
- ProviderServiceArea.
- QuoteRequest.
- QuoteOffer.
- PlanProvider.
- Notification.
- Settings.
- OfflineSyncQueue.
- FeatureFlag.
- AuditLog لاحقاً.

### 10.2 علاقات مهمة

#### WeddingPlan

يرتبط بـ:

- owner User.
- PlanMembers.
- Location.
- BudgetCategories.
- Expenses.
- Debts.
- Installments.
- Tasks.
- Guests.
- PlanProviders.
- Notifications.

#### Provider Flow

Provider → QuoteRequest → QuoteOffer → PlanProvider → Expense/Debt optional.

#### Location Matching

WeddingPlan.Location يقارن مع Provider.ServiceAreas.

### 10.3 حقول location المقترحة

- governorate.
- city.
- district.
- neighborhood.
- street.
- addressNote.
- latitude optional later.
- longitude optional later.

### 10.4 حقول persona

- persona: groom / bride / helper / provider.
- genderTone: masculine / feminine / neutral.
- preferredCopyStyle optional.

---

## 11. Backend Flow Blueprint

### 11.1 Onboarding Flow

1. start onboarding.
2. choose path.
3. choose persona.
4. save location.
5. save wedding date.
6. save priorities.
7. save budget.
8. create suggested categories.
9. create guest/local plan.
10. return generated dashboard summary.

### 11.2 Provider Quote Flow

1. User opens provider.
2. User requests quote.
3. Backend creates QuoteRequest.
4. Provider receives request.
5. Provider sends QuoteOffer.
6. Backend creates Notification for user.
7. User opens offer.
8. User accepts.
9. Backend creates PlanProvider.
10. Dashboard updates.
11. Optional: create expense/debt linked to provider.

### 11.3 Money Flow

- Create budget category.
- Create expense.
- Link expense to category.
- Link expense to provider optional.
- Detect budget exceeded.
- Create debt.
- Create installment.
- Notify due installment.
- Update summary.

### 11.4 Tasks Flow

- Create task.
- Assign task.
- Set due date.
- Group by timeline.
- Detect overdue.
- Notify owner/assignee.
- Mark complete.
- Update progress.

### 11.5 Guests Flow

- Add guest manually.
- Pick number from contacts.
- Group guest.
- Set invitation status.
- Set attendance status.
- Count invited/confirmed/pending.

### 11.6 Notifications Flow

- Create event.
- Generate notification.
- Store in app.
- Optional push.
- Deep link to source.
- Mark read.

---

## 12. Auth & Guest Strategy

### 12.1 Guest can

- Complete onboarding.
- Create local plan.
- View generated dashboard.
- Add local simple data.
- Explore app.

### 12.2 Guest cannot fully do

- Send real quote request.
- Share plan.
- Invite member.
- Sync cloud.
- Receive real server notifications.
- Accept provider offer.

### 12.3 Signup gate appears when

- Operation needs ownership.
- Operation needs server.
- Operation involves another user/provider.
- Operation involves long-term sensitive storage.

### 12.4 After signup

- Create User.
- Migrate guest plan.
- Link local data.
- Enable sync.
- Resume the intended operation.

---

# PART C — Location, Notifications, Offline, Privacy

---

## 13. Location & Provider Matching

### 13.1 Initial approach

No heavy maps at first.

Use:

- governorate.
- city.
- district.
- neighborhood.
- street.
- service areas.

### 13.2 Suggestions

Fields must suggest:

- governorates.
- cities.
- districts.
- neighborhoods.
- common streets later.

### 13.3 Provider ranking

Order providers by:

1. same city.
2. same area/neighborhood.
3. matching category.
4. budget fit.
5. rating.
6. availability later.
7. verification status.

### 13.4 Provider data required

- businessName.
- category.
- phone.
- city.
- serviceAreas.
- description.
- photos later.
- verificationStatus.
- averagePrice optional.
- rating later.

---

## 14. Notifications Blueprint

### 14.1 Notification types

- quote_received.
- quote_accepted.
- quote_rejected.
- installment_due.
- debt_overdue.
- budget_exceeded.
- task_due_today.
- task_overdue.
- member_joined.
- permission_changed.
- guest_confirmed.
- sync_failed.

### 14.2 Notification fields

- id.
- userId.
- planId.
- type.
- title.
- body.
- sourceType.
- sourceId.
- deepLink.
- isRead.
- createdAt.

### 14.3 Rules

- كل إشعار يجب أن يفتح مكاناً مفيداً.
- لا إشعارات عامة بلا فعل.
- لا Push Permission من أول فتح.
- نطلب إذن Push عندما يوجد سبب واضح.

---

## 15. Offline & Sync Plan

### 15.1 Works Offline

- View cached plan.
- View budget.
- Add local expense.
- Add local task.
- Add local guest.
- Edit note.
- View cached providers partially.

### 15.2 Requires Online

- Send quote request.
- Receive offer.
- Accept provider offer.
- Invite member.
- Share plan.
- Cloud sync.
- Push notifications.

### 15.3 Sync states

- local_only.
- pending_sync.
- synced.
- sync_failed.
- needs_review.

### 15.4 Rule

Never make the user believe a cloud/server action succeeded if it is only local.

---

## 16. Security & Privacy Plan

### 16.1 Sensitive data

- phone numbers.
- contacts.
- address.
- budget.
- debts.
- plan members.
- provider agreements.
- guest list.

### 16.2 Privacy rules

- Do not upload all contacts.
- Only use selected contact number.
- Providers see only relevant request details.
- Plan members see by permission.
- Address sharing must be controlled.
- Debts and budget are private by default.
- Admin actions should be auditable later.

### 16.3 Device permissions

Request only when needed:

- Contacts: when tapping contact icon.
- Location: when tapping use my location.
- Notifications: after plan creation or quote flow.
- Photos/files: only when upload feature appears.

---

# PART D — Admin, Content, Data, AI Agent Rules

---

## 17. Admin & Provider Operations

### 17.1 Admin must manage

- provider applications.
- provider approval/rejection.
- provider suspension.
- provider verification.
- cities/areas.
- categories.
- quote requests overview.
- reports.
- disputes.
- content.

### 17.2 Provider statuses

- draft.
- pending_review.
- approved.
- verified.
- suspended.
- rejected.

### 17.3 Marketplace rule

No real marketplace launch without admin control.

---

## 18. Content System

### 18.1 Why

Because Arabic text changes by persona.

### 18.2 Content Matrix examples

| Context | Groom | Bride | Helper | Provider |
|---|---|---|---|---|
| Budget CTA | أضف ميزانيتك | أضيفي ميزانيتكِ | ساعد في ضبط الميزانية | حدد أسعار خدماتك |
| Wedding date | حدد موعد الزواج | حددي موعد الزفاف | تابع موعد الخطة | حدد توفرك |
| Empty tasks | لا توجد مهام بعد | لا توجد مهام بعد | لا توجد مهام مسندة لك | لا توجد طلبات بعد |
| Save | حفظ | حفظ | حفظ | حفظ |

### 18.3 Rule

Do not scatter Arabic copy randomly in widgets. Use structured constants/content service where possible.

---

## 19. Data Seeding Plan

Required seed data:

- Yemen governorates.
- Main cities/districts.
- Initial neighborhoods gradually.
- Budget categories.
- Provider categories.
- Task templates.
- Onboarding priorities.
- Empty state messages.
- Notification templates.

---

## 20. Task Templates

### 20.1 Timeline examples

#### Before 6 months

- تحديد الميزانية.
- اختيار القاعة.
- البحث عن المصور.
- تحديد قائمة مبدئية للضيوف.

#### Before 3 months

- تأكيد المطعم.
- تجهيز الدعوات.
- اختيار الكوشة.
- متابعة المصروفات.

#### Before 1 month

- تأكيد الموردين.
- إرسال الدعوات.
- مراجعة الأقساط.
- ترتيب يوم الزفاف.

#### Before 1 week

- تأكيد الحضور.
- مراجعة جدول اليوم.
- دفع المتبقي.
- مراجعة الطوارئ.

---

## 21. Budget Presets

Later support budget presets by wedding type:

- زفاف بسيط.
- زفاف متوسط.
- زفاف كبير.
- عرس رجالي ونسائي.
- عرس نسائي منفصل.
- خطوبة فقط.
- عقد / ملكة.
- تجهيز بيت.

Each preset affects:

- suggested categories.
- percentage allocation.
- task templates.
- provider suggestions.

---

## 22. Feature Flags

Features that must be controlled:

- enableProviderMode.
- enableProviderQuotes.
- enableGuestContacts.
- enableOfflineSync.
- enableAIHelper.
- enablePushNotifications.
- enableSubscriptions.
- enableMaps.
- enableAnalytics.

Rule:

Any incomplete feature stays hidden behind a feature flag.

---

## 23. Migration Plan

Because mobile has local/offline data, any rebuild must consider:

- existing local DB version.
- existing wedding plans.
- existing expenses.
- existing guests.
- existing providers.
- migration fallback.
- migration failure message.
- safe backup before destructive change.

Rule:

No local schema change without migration plan.

---

# PART E — Mobile Architecture & Quality

---

## 24. State Management Plan

### 24.1 Required global states

- currentUser.
- currentPlan.
- authState.
- userRole.
- persona.
- location.
- syncState.
- notifications.
- featureFlags.
- appSettings.

### 24.2 Required domain states

- budgetSummary.
- taskSummary.
- providerSummary.
- guestSummary.
- quoteRequests.
- offlineQueue.

### 24.3 Rule

Do not let Home and My Plans compute data separately.

---

## 25. Single Source of Truth

Any repeated number must come from one summary source.

Examples:

- days remaining.
- progress percentage.
- total budget.
- spent amount.
- remaining amount.
- overdue tasks.
- due installments.
- active providers.
- unread notifications.

Suggested services:

- PlanSummaryService.
- BudgetSummaryService.
- TaskSummaryService.
- ProviderSummaryService.
- NotificationSummaryService.
- GuestSummaryService.

---

## 26. Error / Loading / Empty State Guide

### 26.1 Error messages

Arabic, clear, action-oriented.

Bad:

> Something went wrong.

Good:

> تعذر حفظ المصروف. تأكد من الاتصال وحاول مرة أخرى.

### 26.2 Loading

Use:

- cached data when possible.
- skeleton cards.
- pull to refresh.
- no blank white screens.

### 26.3 Empty States

Must include action.

Bad:

> لا توجد مهام.

Good:

> لا توجد مهام بعد. أضف أول مهمة لتنظيم زفافك.

---

## 27. Design System

Not only colors.

Must define:

- color palette.
- typography.
- spacing.
- radius.
- shadows.
- buttons.
- cards.
- inputs.
- bottom sheets.
- chips.
- badges.
- alerts.
- empty states.
- loading skeletons.
- error states.
- success states.
- warning states.
- danger states.
- pending states.
- RTL components.

### 27.1 Identity direction

- Burgundy.
- Gold.
- Warm beige.
- Soft white.
- Elegant wedding feel.
- Arabic-first.

---

## 28. Performance Plan

Must consider:

- pagination for providers.
- caching.
- lazy loading.
- image compression.
- avoiding full dashboard rebuilds.
- controlling animations.
- efficient local DB queries.
- avoiding duplicated API calls.

---

## 29. Observability / Logs

Track important events:

- onboarding_started.
- onboarding_completed.
- role_selected.
- persona_selected.
- plan_created.
- expense_created.
- quote_request_created.
- quote_offer_sent.
- quote_offer_accepted.
- notification_created.
- sync_failed.
- auth_gate_shown.
- provider_profile_submitted.

Logs help debug user complaints.

---

## 30. Push Notification Infrastructure

Later define:

- FCM or equivalent.
- device token registration.
- permission timing.
- guest limitations.
- provider notifications.
- user notifications.
- notification deep links.

Rule:

Do not request notification permission on first app open.

---

## 31. Testing & QA Plan

### 31.1 Required tests

- UX smoke tests.
- Backend tests.
- Mobile widget tests.
- Role tests.
- Offline tests.
- Regression tests.
- Navigation tests.
- Permission tests.

### 31.2 Smoke test flows

- Complete onboarding.
- Create plan.
- Open dashboard.
- Add expense.
- Add task.
- Add guest.
- Request quote.
- Receive offer.
- Accept offer.
- Provider appears in plan.
- Notification opens correct screen.
- Offline expense syncs.

### 31.3 Release gate

No release without:

- Flutter analyze pass.
- Flutter test pass.
- Backend tests pass where applicable.
- Manual smoke test pass.
- Git status reviewed.
- Known issues documented.

---

## 32. Release Plan

Release stages:

1. Internal dev build.
2. QA build.
3. Test APK.
4. Pilot users.
5. Production candidate.
6. Production release.

Each release needs:

- version number.
- changelog.
- known issues.
- smoke test report.
- rollback plan.

---

## 33. Analytics Plan

Track later:

- onboarding start/completion.
- drop-off screen.
- role selection.
- persona selection.
- budget setup completion.
- category selection.
- dashboard actions.
- money actions.
- provider opens.
- quote requests.
- signup gate conversions.
- guest adds.
- sync failures.

Rule:

Design flows to be measurable even if analytics implementation comes later.

---

## 34. Monetization Later

Do not add monetization early.

Possible future revenue:

- provider subscription.
- featured provider placement.
- commission from confirmed deals.
- premium user features.
- PDF export.
- advanced sharing.
- respectful limited ads.

Rule:

Do not force payment before user understands value.

---

## 35. Legal / Terms / Privacy

Needed later:

- privacy policy.
- terms of use.
- provider terms.
- contact permission explanation.
- location permission explanation.
- quote/marketplace disclaimer.
- dispute policy.
- data retention policy.

Rule:

Aarast should not imply it guarantees provider agreements unless explicitly designed legally/operationally.

---

## 36. Support & Disputes

Need flows for:

- report provider.
- report wrong information.
- dispute quote.
- user complaint.
- provider complaint.
- admin review.
- support contact.

Provider agreements should have visible records.

---

## 37. Backup / Export

Future useful features:

- export budget PDF.
- export guest list.
- export plan summary.
- share read-only plan.
- backup local data.

Not immediate, but architecture should not block it.

---

# PART F — Implementation Roadmap

---

## 38. Sprint Plan

### Sprint 1 — Foundation Docs

Deliver:

- CURRENT_STATE_AUDIT.md.
- PRODUCT_LOGIC_BLUEPRINT.md.
- UX_BLUEPRINT.md.
- NAVIGATION_BLUEPRINT.md.

No coding except if needed for audit.

### Sprint 2 — Architecture Blueprints

Deliver:

- DATA_MODEL_BLUEPRINT.md.
- BACKEND_FLOW_BLUEPRINT.md.
- AUTH_GUEST_STRATEGY.md.
- LOCATION_PROVIDER_MATCHING.md.
- NOTIFICATIONS_BLUEPRINT.md.

### Sprint 3 — Onboarding Build

Build:

- Welcome.
- Choose path.
- Persona.
- Location.
- Wedding date.
- Priorities.
- Budget.
- Categories.
- Create plan.
- Generated dashboard source data.

### Sprint 4 — Navigation + Home Rebuild

Build:

- User bottom navigation.
- Action sheet.
- Route guards.
- Home as Today Center.
- Single dashboard summary source.

### Sprint 5 — Money Refactor

Build/refactor:

- Money overview.
- Budget categories.
- Expenses.
- Debts.
- Installments.
- Contacts picker for number fields where applicable.
- Suggested categories.
- Budget exceeded states.

### Sprint 6 — Providers Flow

Build/refactor:

- Provider browse.
- Provider detail.
- Request quote.
- Quote status.
- Notifications.
- Accept offer.
- PlanProvider.
- Dashboard integration.

### Sprint 7 — Tasks, Guests, Sharing

Build/refactor:

- Task timeline.
- Today/upcoming/overdue.
- Guests.
- Contact picker.
- Sharing permissions.
- More cleanup.
- Settings cleanup.

### Sprint 8 — Offline, QA, Polish, Release

Deliver:

- Offline/sync behavior.
- Error/loading/empty guide implementation.
- Design system application.
- QA pass.
- Test APK.
- Release report.

---

## 39. Patch vs Rebuild Matrix

### Likely Rebuild

- Onboarding.
- Home Dashboard.
- Role split.
- Provider/User separation.
- Notifications logic if currently only static.
- Sharing permissions if currently shallow.

### Likely Refactor

- Money.
- Providers.
- More.
- Forms.
- Settings.
- Guests.

### Review before decision

- Tasks.
- Debts/Installments.
- My Plans.
- Sync UI.

---

## 40. Files to Create

Recommended docs:

```txt
docs/mobile-ux/CURRENT_STATE_AUDIT.md
docs/mobile-ux/PRODUCT_LOGIC_BLUEPRINT.md
docs/mobile-ux/UX_BLUEPRINT.md
docs/mobile-ux/NAVIGATION_BLUEPRINT.md
docs/mobile-ux/DESIGN_SYSTEM.md
docs/mobile-ux/ERROR_LOADING_EMPTY_GUIDE.md
docs/mobile-ux/MOBILE_IMPLEMENTATION_PLAN.md
docs/mobile-ux/VISUAL_SYSTEM.md

docs/architecture/DATA_MODEL_BLUEPRINT.md
docs/architecture/BACKEND_FLOW_BLUEPRINT.md
docs/architecture/AUTH_GUEST_STRATEGY.md
docs/architecture/LOCATION_PROVIDER_MATCHING.md
docs/architecture/NOTIFICATIONS_BLUEPRINT.md
docs/architecture/OFFLINE_SYNC_PLAN.md
docs/architecture/MIGRATION_PLAN.md
docs/architecture/OBSERVABILITY_PLAN.md

docs/mobile-architecture/STATE_MANAGEMENT_PLAN.md
docs/mobile-architecture/SINGLE_SOURCE_OF_TRUTH_PLAN.md
docs/mobile-architecture/PERFORMANCE_PLAN.md

docs/security/SECURITY_PRIVACY_PLAN.md
docs/admin/ADMIN_PROVIDER_OPERATIONS.md
docs/content/ARABIC_COPY_MATRIX.md
docs/data/SEEDING_PLAN.md
docs/data/YEMEN_LOCATION_SEED.md
docs/testing/MOBILE_QA_PLAN.md
docs/analytics/ANALYTICS_PLAN.md
docs/business/MONETIZATION_LATER.md
docs/legal/PRIVACY_TERMS_NOTES.md
docs/support/SUPPORT_DISPUTES_PLAN.md
docs/release/MOBILE_RELEASE_PLAN.md
docs/AGENT_EXECUTION_RULES.md
```

---

# PART G — AI Agent / Codex Rules

---

## 41. Agent Execution Rules

Any AI agent working on this project must obey:

1. Do not work on `main` unless explicitly ordered.
2. Do not implement before reading the relevant Blueprint.
3. Do not change backend/admin if task is mobile-only.
4. Do not change unrelated files.
5. Do not introduce duplicate entry points.
6. Do not expose unfinished features without feature flag.
7. Do not force login at app launch.
8. Do not mix provider and user flows.
9. Do not hardcode Arabic copy randomly if content matrix exists.
10. Do not compute summary numbers separately in multiple screens.
11. Run formatting.
12. Run analyzer/tests.
13. Report modified files.
14. Report what passed/failed.
15. Report what was not done.
16. Do not commit unless user explicitly permits.
17. If a screen is structurally wrong, recommend rebuild instead of patching silently.

---

## 42. Acceptance Report Template

Each implementation task must end with:

```md
## Report

### What was changed
-

### Files modified
-

### Tests run
- dart format:
- flutter analyze:
- flutter test:
- backend tests:

### Result
PASS / FAIL

### Known issues
-

### Risks
-

### Next recommended step
-
```

---

# PART H — Final Decision

---

## 43. What must happen first

The first real task is not coding UI.

The first task is:

```txt
docs/mobile-ux/CURRENT_STATE_AUDIT.md
```

Then:

```txt
docs/mobile-ux/PRODUCT_LOGIC_BLUEPRINT.md
docs/mobile-ux/UX_BLUEPRINT.md
docs/mobile-ux/NAVIGATION_BLUEPRINT.md
```

Without these, implementation will become random patching again.

---

## 44. Final strict statement

Aarast must move from:

> شاشات وميزات متفرقة

To:

> نظام زفاف مترابط يعرف المستخدم، يبني خطة، يوجه يومياً، ويربط المال والمهام والضيوف والموردين والإشعارات والصلاحيات والموقع والخصوصية.

Any work that does not serve this direction should be rejected, delayed, or rebuilt.

---

## 45. Done Criteria for This README

This README is complete only if it reminds the team of:

- Product logic.
- UX blueprint.
- Roles.
- Data model.
- Backend flows.
- Auth strategy.
- Location matching.
- Notifications.
- Patch/rebuild rule.
- Testing.
- Offline.
- Security.
- Admin.
- Content.
- Analytics.
- Monetization.
- Accessibility.
- Design system.
- State management.
- Single source of truth.
- Error/loading/empty.
- Migration.
- Feature flags.
- Release.
- Observability.
- Push notifications.
- Legal/support.
- Provider verification.
- Data seeding.
- Task templates.
- Budget presets.
- Device permissions.
- Performance.
- Backup/export.
- Agent rules.

If any future task violates this README, stop and revise the task before coding.

---

**End of README.**
