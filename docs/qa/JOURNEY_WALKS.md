# مشي المسارات في التطبيق الحقيقي

أداة تفتح التطبيق الحقيقي على ويندوز مع خادم محلي، وتدخل بحسابات التجربة، وتمشي كل مسار بالضغط، وتحفظ صورة ونص كل شاشة، وتتأكد مما يجب أن يراه المستخدم. الخطوة الفاشلة تعني مشكلة، أو توقعًا قديمًا في الاختبار، فافحص نص الشاشة قبل الحكم.

## الملفات

الأداة والرحلات في `mobile/integration_test/journeys/`.

| الرحلة | الملف |
|---|---|
| العريس والعروسة | `groom_walk_test.dart`، `bride_walk_test.dart` |
| المشاركون | `participant_saleh_walk_test.dart`، `participant_father_walk_test.dart` |
| المزود | `provider_studio_walk_test.dart`، `provider_review_states_walk_test.dart` |
| كل المسارات مباشرة | `route_sweep_walk_test.dart` |
| من الطلبات إلى البند | `view_cost_from_requests_walk_test.dart` |
| من العرض إلى الحجز | `offer_to_booking_walk_test.dart`، `offer_confirm_walk_test.dart` |
| الحجز ينهي مهمته | `task_closed_by_booking_walk_test.dart` (بعد `offer_confirm` مباشرة) |
| تنبيه العرض قبل فتح المزودين | `notification_open_walk_test.dart` |
| عريس جديد يحفظ فعلًا | `fresh_groom_walk_test.dart` |

الرحلات الأخيرة تكتب في القاعدة، فلا تعيدها على نفس البيانات. والترتيب: العريس أولًا، ثم العروسة، ثم البقية، و`fresh_groom` آخرًا.

## التشغيل على قاعدة منفصلة

1. **قاعدة جديدة:** أنشئ قاعدة باسم جديد في `aarast-db`، ولا تستخدم `aarast_dev`.
2. **البيانات:** من `backend`، مع `DATABASE_URL` للقاعدة الجديدة:
   ```powershell
   npx prisma migrate deploy
   $env:DEMO_PASSWORD='<كلمة سر تجربة، 12 حرفًا أو أكثر>'
   $env:DEMO_SEED_TODAY='<تاريخ اليوم>'
   npx ts-node prisma/demo-seed.ts
   ```
3. **الخادم:** على منفذ لا يستخدمه شيء آخر، لأن `--env-file` لا يغيّر متغيرًا موجودًا:
   ```powershell
   $env:PORT='3116'; $env:AUTH_OTP_MODE='dev'; $env:AUTH_DEV_OTP_CODE='123456'; $env:NODE_ENV='development'
   node --env-file=.env -r ts-node/register -r tsconfig-paths/register src/main.ts
   ```
4. **ويندوز:** شيل `flutter_secure_storage_windows` محليًا من `mobile/windows/flutter/generated_plugins.cmake` و`generated_plugin_registrant.cc`، لأنه يحتاج ATL، واضبط `JAVA_HOME` على JDK 17. بعد المشي: `git checkout -- mobile/windows`. لا تحفظ هذا التعديل.
5. **المشي:** من `mobile`، ملف واحد في كل مرة:
   ```powershell
   flutter test --no-pub integration_test/journeys/groom_walk_test.dart -d windows `
     --dart-define=AARAST_API_BASE_URL=http://127.0.0.1:3116 `
     --dart-define=DEMO_PASSWORD=$env:DEMO_PASSWORD `
     --dart-define=AARAST_WALKS_DIR=$env:TEMP\aarast-walks
   ```
   `route_sweep` يحتاج أيضًا `--dart-define=AARAST_SWEEP_IDS=planId=...,costId=...` من القاعدة.
6. **النتيجة:** في `AARAST_WALKS_DIR\<الرحلة>\`: صورة ونص لكل خطوة، و`report.json`.

## تحذيرات

- **تأكد أن الكتابة وصلت القاعدة الصحيحة بعد الجولة.** `Get-NetTCPConnection` لا يرى منفذ الخادم على هذا الجهاز، فقد يبقى خادم قديم يرد دون أن تنتبه.
- `--no-pub` دائمًا.
- رحلة علقت 15 دقيقة بدون تقرير ليست نتيجة: أعدها وحدها.
- `flutter test` العادي لا يشغّل `integration_test/`.
