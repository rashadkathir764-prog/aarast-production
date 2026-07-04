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
| A1 | `plan_center_screen.dart` | 2375 | أيقونات فقط | يحتاج hero/كروت فخمة (إكمال التدقيق الكامل) |
| A2 | `debt_installment_screen.dart` | 975 | ✅ تمّت | `DebtPulseHero` + Lucide + حذف فلتر ميت + حذف شبكة قديمة. `370d6497` |
| A3 | `create_debt_screen.dart` | 679 | قديمة | |
| A4 | `debt_details_screen.dart` | 613 | قديمة | |
| A5 | `create_installment_screen.dart` | 536 | قديمة | |
| A6 | `budget_category_details_screen.dart` | 682 | قديمة | |
| A7 | `expenses_screen.dart` | 516 | قديمة | راجع التكرار مع `budget_expense_screen` |
| A8 | `budget_setup_screen.dart` | 424 | قديمة | |
| A9 | `create_budget_category_screen.dart` | 249 | قديمة | |

## المرحلة ب — المزودون (واجهة المستخدم) 🟠
| # | الشاشة | أسطر | حالة |
|---|--------|:---:|:---:|
| B1 | `quote_request_screen.dart` | 775 | العملة تمّت — يحتاج fخم |
| B2 | `provider_details_screen.dart` | 691 | قديمة |
| B3 | `favorite_providers_screen.dart` | 453 | قديمة |

## المرحلة ج — المشاركة/العائلة 🟡
> اقتراح دمج: راجع دمج `shared_wedding_plans` + `sharing_screen` في سطح واحد بتبويبات فرعية.

| # | الشاشة | أسطر | حالة |
|---|--------|:---:|:---:|
| C1 | `add_shared_member_screen.dart` | 777 | قديمة |
| C2 | `sharing_screen.dart` | 320 | قديمة |
| C3 | `edit_shared_member_screen.dart` | 249 | قديمة |
| C4 | `shared_wedding_plans_screen.dart` | 169 | قديمة |

## المرحلة د — الإعداد/الحساب (ثانوية) 🟡
| # | الشاشة | أسطر | حالة |
|---|--------|:---:|:---:|
| D1 | `more_screen.dart` | 879 | قديمة |
| D2 | `create_wedding_plan_screen.dart` | 605 | قديمة |
| D3 | `register_screen.dart` | 528 | قديمة (الدخول/OTP فقط لُمسا نصياً) |
| D4 | `settings_screen.dart` | 427 | قديمة |
| D5 | `support_screen.dart` | 237 | قديمة |
| D6 | `splash_screen.dart` | 116 | قديمة |

## المرحلة هـ — جانب المزوّد B2B (أدنى أولوية) 🟢
> يشوفها ~1% من المستخدمين. آخر ما يُنجز.

| # | الشاشة | أسطر | حالة |
|---|--------|:---:|:---:|
| E1 | `provider_dashboard_screen.dart` | 1378 | لُمست جزئياً في P4 |
| E2 | `provider_apply_screen.dart` | 478 | قديمة |
| E3 | `edit_provider_profile_screen.dart` | 382 | قديمة |
| E4 | `add_provider_service_screen.dart` | 299 | قديمة |
| E5 | `add_provider_package_screen.dart` | 278 | قديمة |

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
