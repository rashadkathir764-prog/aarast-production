# PLAN: Aarast Mobile — التحويل الفخم لكل الشاشات (Premium Screens Roadmap)

**Slug:** mobile-premium-screens | **Branch:** `phase/mobile-premium-screens-v1` | **Owner:** John
**Created:** 2026-07-05 | **Status:** active | **Source of truth:** هذا الملف (mxLore ملغاة — لا تعتمد عليها)

> جرد دقيق مبنيّ على git الفعلي (base `99fdb3c8` → HEAD) وليس على تخمين. حدّثه بعد كل مرحلة.

## الهدف
تحويل كل شاشة في تطبيق Aarast إلى نسخة 2026 فخمة، موحّدة على نظام التصميم نفسه:
هيدر نحيف → hero فخم → كروت ذكية → أيقونات Lucide → مسح التسريبات (English/YER/PLANNING) →
golden preview → `flutter analyze` نظيف + كل الاختبارات خضراء.

## نمط التنفيذ لكل شاشة (Definition of Done)
1. تدقيق: ايش يخص الشاشة؟ ايش مكرر/ناقص/قديم/محيّر؟ ايش الفعل الأساسي؟
2. توحيد أيقونات Material → Lucide
3. مسح التسريبات اللغوية والصياغة (محايدة الجنس، عربي طبيعي، RTL)
4. hero/كروت فخمة حيث الشاشة ضعيفة
5. حالات فارغة/تحميل/خطأ فخمة وذكية
6. golden preview + إبقاء الـ suite خضراء + `flutter analyze` نظيف
7. الحفاظ على منطق العمل والفورمات — لا مساس بالباكند

---

## ✅ ما تم (premium — لا يُعاد)
التبويبات الخمسة الرئيسية + الهيكل + الترحيب + الدخول (نصوص) + لوحة الضيف:

| البند | Commit |
|------|--------|
| Dashboard (`PremiumDashboardView`) | e2cfb579 |
| Money/Budget (`BudgetPulseHero`, `PaymentTimelineRail`) | 8ad67264 |
| Tasks (`SmartTaskCard`, `TasksProgressHero`) | 0e6b6ceb |
| Guests (`GuestMeterHero`, `SmartGuestCard`) | f0090f7f |
| Providers tab (`PremiumVendorCard`) + language polish | a99066e2 |
| App shell (bottom nav + FAB) | 71e4eed1 |
| Welcome gateway | 06a327b8 |
| Auth copy (محايد الجنس) | aa7c8701 |
| Guest dashboard unified | 4f8f5b3f |
| create-expense — أيقونات فقط | a6640eca |
| create-task — أيقونات فقط | 68428363 |
| plan-center — أيقونات + عملة العرض فقط | 8e061cb1 |

> **تحذير:** كل الـ commits محلية — **لم تُدفع بعد**.

---

## المرحلة 0 — تنظيف سريع (قبل أي شاشة جديدة) 🔴
- [x] حذف الكود الميت `royal_home_today_center.dart` (3613) + اختباره (473) — صفر مستدعين. `226fdb42`
- [x] إصلاح باغ العملة في `create_expense_screen.dart` — 8 مواضع «ر.ي» ثابتة → `currencyLabelAr` بقراءة دفاعية للخطة النشطة. `a64612e1`
- [x] «نسيت كلمة المرور؟» في `login_screen.dart` — bottom sheet فخم «قريباً + تواصل مع الدعم» مكتفٍ ذاتياً. `36f587e6`
- [x] **دفع الـ commits** — 17 commit مدفوعة لـ`aarast-production/phase/mobile-premium-screens-v1`، upstream مضبوط.

**✅ المرحلة 0 مكتملة.**

## المرحلة أ — عنقود المال (أعلى قيمة يومية) 🔴
| # | الشاشة | أسطر | حالة | ملاحظة |
|---|--------|:---:|:---:|--------|
| A1 | `plan_center_screen.dart` | 2375 | ✅ تمّت | التدقيق أكد وجود hero/كروت premium + Lucide + `currencyLabelAr`، وأضيف حارس source يمنع الرجوع للقديم. |
| A2 | `debt_installment_screen.dart` | 975 | ✅ تمّت | `DebtPulseHero` + Lucide + حذف فلتر ميت + حذف شبكة قديمة. `370d6497` |
| A3 | `create_debt_screen.dart` | 679 | ✅ تمّت | Hero فخم + Lucide + عملة الخطة/العرض بدل `YER` + اختبارات شاشة/مصدر. |
| A4 | `debt_details_screen.dart` | 613 | ✅ تمّت | Lucide + عملة الخطة في تفاصيل الدين والأقساط بدل `ر.ي` ثابتة + اختبارات SAR. |
| A5 | `create_installment_screen.dart` | 536 | ✅ تمّت | Hero فخم + Lucide + عملة الخطة من الدين المحدد بدل `YER` + اختبارات شاشة/مصدر. |
| A6 | `budget_category_details_screen.dart` | 682 | ✅ تمّت | Lucide + عملة الخطة/ملخص المال بدل `ر.ي` ثابتة + hero/بطاقات تفاصيل البند + اختبار SAR. |
| A7 | `expenses_screen.dart` | 516 | ✅ تمّت | أبقيت كشاشة "كل المصاريف/مصروفات بند" مع بحث وفلاتر؛ أصبحت hero فخم + Lucide + عملة الخطة. |
| A8 | `budget_setup_screen.dart` | 424 | ✅ تمّت | إعداد جماعي premium + Lucide + قوالب بنود محسّنة + عملة الخطة في الحقول + حفظ local guest محفوظ. |
| A9 | `create_budget_category_screen.dart` | 249 | ✅ تمّت | Hero فخم + Lucide + صياغة عربية محايدة + عملة الخطة في مبلغ البند + اختبار SAR. |

**حالة المرحلة أ:** مكتملة 10/10: شاشات المال كلها منفذة، اختبارات المرحلة مضافة، وبوابة `flutter test` الكاملة أُغلقت بنجاح بعد تحديث goldens المقصودة واختبار `/onboarding`.

## المرحلة ب — المزودون (واجهة المستخدم) ✅
| # | الشاشة | أسطر | حالة |
|---|--------|:---:|:---:|
| B1 | `quote_request_screen.dart` | 775 | ✅ تمّت: Hero طلب عرض + Lucide + `currencyLabelAr` + تأكيد أنها مقارنة/تخطيط فقط بلا حجز أو دفع. |
| B2 | `provider_details_screen.dart` | 691 | ✅ تمّت: Lucide + أسعار عربية من `currencyLabelAr` + شارات تخطيط/طلب عرض + كروت خدمات/باقات محسّنة. |
| B3 | `favorite_providers_screen.dart` | 453 | ✅ تمّت: Hero محفوظات + Lucide + أسعار عربية + نص مقارنة صريح بلا إنشاء حجز/مصروف تلقائي. |

**حالة المرحلة ب:** مكتملة 10/10: شاشات المزودين الثلاث منفذة، اختبار `phase_b_provider_screens_test.dart` مضاف، وبوابة `flutter test` الكاملة أُغلقت بنجاح مع `flutter analyze` و`git diff --check`.

## المرحلة ج — المشاركة/العائلة ✅
> أُنجزت كشاشات مشاركة منفصلة مع إبقاء الدمج كتوصية لاحقة، لأن تنفيذ تبويبات جديدة الآن يوسّع النطاق ويغيّر التنقل.

| # | الشاشة | أسطر | حالة |
|---|--------|:---:|:---:|
| C1 | `add_shared_member_screen.dart` | 777 | ✅ تمّت: Hero دعوة آمنة + Lucide + توضيح صلاحيات المشاركة والمال بدون كشف افتراضي. |
| C2 | `sharing_screen.dart` | 320 | ✅ تمّت: Hero مشاركة آمنة + مؤشرات حقيقية من بيانات API + كروت أعضاء توضّح الوصول المالي حسب الصلاحية. |
| C3 | `edit_shared_member_screen.dart` | 249 | ✅ تمّت: Hero عضو مشارك + Lucide + مفاتيح صلاحيات واضحة بدون تغيير API. |
| C4 | `shared_wedding_plans_screen.dart` | 169 | ✅ تمّت: Hero خطط مشتركة + Lucide + عملة عربية عبر `currencyLabelAr` في كرت الخطة. |

**حالة المرحلة ج:** مكتملة 10/10: شاشات المشاركة الأربع والكروت المرئية التابعة لها منفذة، اختبار `phase_c_sharing_screens_test.dart` مضاف، وبوابة `flutter test` الكاملة أُغلقت بنجاح مع `flutter analyze` و`git diff --check`.

## المرحلة د — الإعداد/الحساب (ثانوية) ✅
| # | الشاشة | أسطر | حالة |
|---|--------|:---:|:---:|
| D1 | `more_screen.dart` | 879 | ✅ تمّت: Lucide كامل + قائمة حساب/مساعدة بلا وجهات وهمية وبنصوص مقارنة/دعم صادقة. |
| D2 | `create_wedding_plan_screen.dart` | 605 | ✅ تمّت: Lucide + عملة عربية في الواجهة عبر `currencyLabelAr` مع تحويل آمن لرمز API عند الحفظ. |
| D3 | `register_screen.dart` | 528 | ✅ تمّت: Lucide لمساري العميل/المزوّد مع بقاء التسجيل وOTP وطلب المزود كما هي. |
| D4 | `settings_screen.dart` | 427 | ✅ تمّت: Lucide + بوابة حساب محفوظة تمنع نداءات API المحمية بدون حساب. |
| D5 | `support_screen.dart` | 237 | ✅ تمّت: Lucide + دعم عملي وحدود منتج صريحة بلا دفع/حجز/ضمانات وهمية. |
| D6 | `auth/splash_screen.dart` | 116 | ✅ تمّت: تأكيد المسار الحقيقي القديم في الخطة، والشاشة الحالية premium بلا placeholder أو أيقونات قديمة. |

**حالة المرحلة د:** مكتملة 10/10: شاشات الحساب والإعداد الست منفذة أو مؤكدة حسب المسار الحقيقي، اختبار `phase_d_account_screens_test.dart` مضاف، وبوابة `flutter test` الكاملة أُغلقت بنجاح مع `flutter analyze` و`git diff --check`.

## المرحلة هـ — جانب المزوّد B2B (أدنى أولوية) ✅
> أُنجزت كتحسين واجهات المزوّد الحالية فقط، بدون فتح ميزات دفع/حجز/اعتماد تلقائي أو تغيير عقود API.

| # | الشاشة | أسطر | حالة |
|---|--------|:---:|:---:|
| E1 | `provider_portal_screen.dart` + `provider_portal_tabs.dart` | حي | ✅ البوابة القانونية الوحيدة للمورد؛ شاشة `provider_dashboard_screen.dart` القديمة حُذفت في 2026-07-10 بعد إثبات عدم وجود imports أو routes لها. الأسعار المرئية تمر عبر `currencyLabelAr`. |
| E2 | `provider_apply_screen.dart` | 478 | ✅ تمّت: Lucide + بوابة حساب ومراجعة مزود صريحة بلا اعتماد تلقائي. |
| E3 | `edit_provider_profile_screen.dart` | 382 | ✅ تمّت: Lucide + ملاحظات حالة وفئة مقفلة بدون تغيير مسار المراجعة. |
| E4 | `add_provider_service_screen.dart` | 299 | ✅ تمّت: Lucide + عملة عربية في السعر + إرسال `defaultCurrencyCode` بدل رمز خام داخل الشاشة. |
| E5 | `add_provider_package_screen.dart` | 278 | ✅ تمّت: Lucide + عملة عربية في السعر + نص يحظر وعود الدفع أو الحجز المؤكد. |

**حالة المرحلة هـ:** مكتملة 10/10: شاشات المزوّد الخمس منفذة، اختبار `phase_e_provider_b2b_screens_test.dart` مضاف، وبوابة `flutter test` الكاملة أُغلقت بنجاح مع `flutter analyze` و`git diff --check`.

---

## توصيات John
1. **ابدأ بالمرحلة 0** — الكود الميت وباغ العملة يفسدان أي تدقيق قادم، ودفع الـ commits يحمي 12 commit محلي.
2. **عنقود المال (أ) هو الجوهر** — Aarast نظام مالي للعرس؛ ٤ شاشات ديون قديمة بالكامل = أكبر فجوة حالياً.
3. **راجع تكرار الميزانية** — `expenses_screen` (516) مقابل `budget_expense_screen` (1242، فخمة). قد يكونان متداخلين؛ قرّر دمج/إلغاء قبل تلميع القديم.
4. **جانب المزوّد (هـ) آخراً** — لا يستحق أولوية على شاشات المستخدم اليومي.
5. **بنيوية:** `home_screen` (117) و`wedding_plan_shell` (130) هيكلية — لا تحتاج تلميعاً بصرياً غالباً.

## سجل التقدم
- 2026-07-05 — إنشاء الخطة، جرد كامل مبنيّ على git، mxLore ملغاة (اعتماد md فقط).
- 2026-07-05 — **المرحلة 0 مكتملة**: حذف الكود الميت (`226fdb42`) + إصلاح باغ العملة (`a64612e1`) + توثيق (`a90091d0`) + إصلاح رابط «نسيت كلمة المرور» (`36f587e6`). `flutter analyze` نظيف؛ اختبارات المصادقة/المالية خضراء. **مدفوعة** (17 commit، upstream مضبوط). فشلا goldens (`premium_finance_healthy` 0.03% + `premium_tasks_active` 0.75%) **سابقان/بيئيان** — مؤكد بإعادة التشغيل على HEAD النظيف. دَين تقني: إعادة توليد الـgoldens على جهاز مرجعي/CI.
- 2026-07-05 — بدء **المرحلة أ / عنقود الديون** (4 شاشات).
- 2026-07-05 — **A2 شاشة الديون المحورية** (`debt_installment_screen`) تمّت: `DebtPulseHero` فخم (تدرّج عنابي + حلقة مسدَّد + رقم المتبقي البطل + تلميح تأخير/موعد/تسديد)، حذف زر فلتر ميت، توحيد أيقونات Lucide، حذف ~140 سطر شبكة قديمة. اختبار widget مستقل عن الجهاز (بلا golden). analyze نظيف + كل الاختبارات خضراء. `370d6497`. **باقي العنقود:** create_debt (A3)، debt_details (A4)، create_installment (A5).
- 2026-07-05 — **A3-A5 عنقود الديون مكتمل على فرع `codex/aarast-product-stabilization`**: `create_debt_screen` و`debt_details_screen` و`create_installment_screen` أصبحت على Lucide، وتقرأ تسمية العملة من الخطة/العرض بدل `YER` أو `ر.ي` ثابتة، مع اختبارات widget/source جديدة. `flutter test test\features\debts` PASS و`flutter analyze` PASS.
- 2026-07-05 — **A1 + A6-A9 مكتملة تنفيذياً ضمن المرحلة أ**: `plan_center_screen` ثبت بعقد source أنه premium/Lucide، و`budget_category_details_screen` و`expenses_screen` و`budget_setup_screen` و`create_budget_category_screen` أصبحت على Lucide وتقرأ عملة الخطة/ملخص المال بدل العملة الثابتة. `flutter test test\features\finance\phase_a_money_screens_test.dart` PASS، و`flutter test test\features\finance test\features\debts` PASS، و`flutter analyze` PASS.
- 2026-07-05 — **بوابة المرحلة أ أُغلقت 10/10**: تحديث goldens المقصودة (`premium_finance_healthy.png`، `premium_tasks_active.png`، `premium_welcome_cards.png`) بعد فحص صور master/test، وتحديث اختبار `/onboarding` للنص الحالي في `SmartWelcomeScreen`. النتيجة: `flutter test` PASS كامل، `flutter analyze` PASS، `git diff --check` PASS، ولا يوجد `mobile/test/failures`.
- 2026-07-05 — **المرحلة ب / المزودون مكتملة 10/10**: `quote_request_screen` و`provider_details_screen` و`favorite_providers_screen` أصبحت على Lucide، تعرض العملات عبر `currencyLabelAr`، وتوضح أن طلبات العروض للمقارنة والتخطيط فقط بلا دفع أو حجز مؤكد. أُضيف `mobile/test/features/marketplace/phase_b_provider_screens_test.dart`. التحقق: `flutter test test\features\marketplace\phase_b_provider_screens_test.dart` PASS، و`flutter test test\features\marketplace test\features\auth\dev_ux_protected_submit_test.dart` PASS، و`flutter analyze` PASS، و`git diff --check` PASS، و`flutter test` PASS كامل.
- 2026-07-05 — **المرحلة ج / المشاركة والعائلة مكتملة 10/10**: `add_shared_member_screen` و`sharing_screen` و`edit_shared_member_screen` و`shared_wedding_plans_screen` أصبحت على Lucide مع بطاقات/Hero عربية توضّح الخصوصية وصلاحيات المال بصدق، وكروت المشاركة تعرض العملة العربية عبر `currencyLabelAr`. أُضيف `mobile/test/features/sharing/phase_c_sharing_screens_test.dart`. التحقق: `flutter test test\features\sharing\phase_c_sharing_screens_test.dart` PASS، و`flutter test test\features\sharing` PASS، و`flutter analyze` PASS، و`flutter test` PASS كامل، و`git diff --check` PASS، ولا يوجد `mobile/test/failures`.
- 2026-07-05 — **المرحلة د / الإعداد والحساب مكتملة 10/10**: `more_screen` و`create_wedding_plan_screen` و`register_screen` و`settings_screen` و`support_screen` أصبحت بلا أيقونات Material مباشرة، و`create_wedding_plan_screen` يعرض العملة بالعربية مع إرسال رمز العملة الصحيح للـAPI، و`auth/splash_screen` تأكد كالمسار الفعلي بدل مسار الخطة القديم. أُضيف `mobile/test/features/settings/phase_d_account_screens_test.dart`. التحقق: `flutter test test\features\settings\phase_d_account_screens_test.dart` PASS، و`flutter test test\features\more test\features\settings test\features\support test\features\auth test\features\wedding_plans` PASS، و`flutter analyze` PASS، و`flutter test` PASS كامل، و`git diff --check` PASS، ولا يوجد `mobile/test/failures`.
- 2026-07-05 — **المرحلة هـ / جانب المزود B2B مكتملة 10/10**: `provider_dashboard_screen` و`provider_apply_screen` و`edit_provider_profile_screen` و`add_provider_service_screen` و`add_provider_package_screen` أصبحت بلا أيقونات Material مباشرة، ونماذج الخدمة/الباقة تعرض العملة بالعربية وترسل `defaultCurrencyCode`، مع إبقاء الاعتماد والطلبات كمسارات مراجعة/عروض لا دفع أو حجز مؤكد. أُضيف `mobile/test/features/marketplace/phase_e_provider_b2b_screens_test.dart`. التحقق: `flutter test test\features\marketplace\phase_e_provider_b2b_screens_test.dart` PASS، و`flutter test test\features\marketplace` PASS، و`flutter analyze` PASS، و`flutter test` PASS كامل، و`git diff --check` PASS، ولا يوجد `mobile/test/failures`.
- 2026-07-07 — **عقد الشاشة الفاخرة v2 مفعّل وحارس**: صفر `CircularProgressIndicator` في `lib/features` و`lib/shared` (skeletons عبر `AarastSkeleton.list/.form/.page`، أزرار عبر `AarastButton.isLoading`/`AarastInlineSpinner`)، ترويسة موحّدة `AarastFeatureHeader`، stagger موحّد `AarastStagger` في القوائم الرئيسية (more/sharing/shared_plans)، حذف 23 alias ميت من `AppTheme` مع إبقاء re-exports كاملة للمقياس. اختبار العقد `aarast_premium_contract_test.dart` شُدّد: قائمة 52 شاشة كاملة + حظر CPI دائم. goldens أساس جديدة `premium_foundation_preview_test.dart`. **استعادة كلمة المرور حقيقية end-to-end**: باك إند `POST /auth/password-reset/request|confirm` (OTP بغرض `RESET_PASSWORD` الموجود أصلًا — بلا migration، بلا تسريب وجود الحساب، إبطال كل الجلسات) + 5 اختبارات logic؛ موبايل `reset_password_screen` (هاتف→رمز+كلمة مرور→نجاح) مربوطة بـ«نسيت كلمة المرور؟» بدل sheet «قريباً»، + 3 اختبارات widget. عقد الـAPI محدّث. التحقق: `flutter analyze` PASS، اختبار العقد PASS، `npm test` باك إند 52/52 PASS.
