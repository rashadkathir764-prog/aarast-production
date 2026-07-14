# PLAN: Aarast Release — من الفحص العميق إلى الإطلاق العام
**Slug:** aarast-release-plan | **Created:** 2026-07-04 | **Updated:** 2026-07-14 | **Status:** active

## Goal
إيصال Aarast من حالة ما بعد الفحص العميق (تقييم 6.5/10) إلى إطلاق عام كامل على Google Play خلال ~6-7 أسابيع عبر 9 مراحل مرتبة بحرجية الثقة.

## Related
- none

## Non-goals
- تغييرات إضافية على دورة الجلسة خارج دمج Refresh Tokens الجاري
- تقسيم كل الملفات العملاقة (أكبر ملفين فقط time-boxed)
- دفع/حجوزات مالية (خارج MVP)
- ترجمة إنجليزية/l10n

## Milestones
1. م1 — إغلاق ثغرات الثقة الفورية (موبايل) — ~3 أيام
2. م2 — إصلاح Onboarding + ترحيل الضيف→الحساب — ~6 أيام
3. م3 — سلامة المال (باكند) — ~5 أيام
4. م4 — صحّة المزامنة ودورة الجلسة (موبايل) — ~6 أيام
5. م5 — تشغيل إنتاجي للباكند — ~5 أيام
6. م6 — FCM + Deep Links — ~6 أيام
7. م7 — تلميع المنتج والـUX — ~5 أيام
8. م8 — واتساب OTP + استعادة كلمة المرور — ~5 أيام
9. م9 — بوابة الإصدار — ~5 أيام

## Tasks
- [x] م1: نقل JWT إلى flutter_secure_storage مع ترحيل صامت (auth_storage.dart)
- [x] م1: مسح SQLite+طابور المزامنة عند الخروج + عزل الكاش بالحساب (auth_repository.dart:100)
- [x] م1: إصلاح حارس provider_dashboard المقلوب (:31-33) + إخراج GoRouter من build() (app.dart:24)
- [x] م2: باكند POST /api/v1/onboarding/import-local — transactional + idempotent (clientMigrationId)
- [x] م2: ربط SmartWelcome بـcompleteOnboarding للمستخدم المسجّل + كسر حلقة MainShell:44-48
- [x] م2: تدفق ترحيل الضيف→الحساب بعد الدخول (شاشة ترحيل + لا حذف قبل تأكيد الخادم)
- [x] م2: حذف كود onboarding الميت (active_plan_onboarding SAR، مسار 8 خطوات، rebuild tabs، readiness models)
- [ ] م3: إغلاق إعادة بناء المال قبل الإطلاق: ميزانية عامة + تصنيفات + WeddingCost + CostPayment + PaymentSchedule فقط، مع حذف العقود والمسارات والكاشات السابقة
- [ ] م3: إثبات ledger عكسي append-only، دفع موعد ذري، منع overpay، ميزانية null صادقة، وصلاحيات canViewMoney/canManageMoney عبر اختبارات fresh/upgrade/concurrency
- [x] م4: idempotency clientRequestId في syncQueue + جدول IdempotencyKey باكند + إصلاح سباق syncPendingChanges:79-92
- [x] م4: إعادة ربط FK المحلية في payloads الطابور + سقف محاولات/blocked + توحيد تغطية update/deleteBudgetCategory
- [x] م4: دمج Refresh Token كاملًا في Prisma وAuthController والموبايل، مع إعادة محاولة واحدة على 401 وإبطال الجلسة عند فشل التحديث
- [x] م5: trust proxy + قفل حساب + exception filter (P2002→409) + Logger + config validation + PrismaService.$connect
- [x] م5: تقييد users/lookup + cron OVERDUE + تجريد OtpChannel (pagination انتقل لبند مستقل)
- [ ] م5+: pagination للقوائم الكبيرة (تكاليف/دفعات/ضيوف/مهام/عروض) + تحديث الموبايل معها
- [ ] م6: FCM — موديل DeviceToken + fan-out + firebase_messaging + توجيه النقر ⚠️ يتطلب مشروع Firebase من المالك
- [x] م6: Deep links للدعوات /invites/:token (Android VIEW + https App Links + iOS scheme؛ assetlinks.json في م9)
- [ ] م7: تلميع UX — حالات فارغة أولى، قناة دعم حقيقية، مصطلحات المال الخمسة فقط، actual-screen goldens، أعلام ميتة، وتقسيم أكبر ملفين
- [ ] م8: واتساب OTP عبر OtpChannel + endpoints استعادة كلمة المرور + شاشات نسيت كلمة المرور
- [ ] م9: e2e باكند (supertest) + تثبيت النشر (NODE_ENV/CORS/502 admin) + إصدار Android موقّع + QA نهائي

## Risks
- حد جلسات AI (فقدان سياق — يعالَج بالحفظ في DB)
- موافقة Meta على WhatsApp قد تتأخر (م8 آخر مرحلة عمداً)
- migration الترحيل على بيانات ضيف غير متوقعة الشكل
- تعارض pagination مع نسخ الموبايل القديمة

## Notes
- التبعيات: م1 مستقلة؛ م2 تعتمد م1؛ م3/م5 (باكند) توازيان م1/م4 (موبايل)؛ م6 تعتمد cron م5؛ م8 تعتمد OtpChannel م5؛ م9 أخيرة.
- هذه هي النسخة المعتمدة داخل المستودع. أي ملاحظات محلية أو سجلات خارجية
  تاريخية ولا تتقدم على `docs/project/STATUS.md` أو هذا الملف.
