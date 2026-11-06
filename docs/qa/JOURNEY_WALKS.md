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
| بدون خادم ثم رجوعه (D85) | `offline_prime_walk_test.dart` ثم `offline_groom_walk_test.dart` ثم `offline_resume_walk_test.dart` |

الرحلات الأخيرة تكتب في القاعدة، فلا تعيدها على نفس البيانات. والترتيب: العريس أولًا، ثم العروسة، ثم البقية، و`fresh_groom` آخرًا.

رحلتا «بدون خادم» تحتاجان نسخة على الجوال وجلسة مفتوحة، تتركهما `offline_prime` (دخول وفتح كل التبويبات بلا خروج؛ رحلة العريس تخرج في آخرها): تُشغَّل `offline_groom` بعنوان خادم مغلق (`AARAST_API_BASE_URL=http://127.0.0.1:9`) ومع `boot(keepLocalData: true)` فتفتح الخطة من نسخة الجوال وتضيف ضيفًا بلا خادم؛ ثم `offline_resume` بالعنوان الطبيعي فتثبت أن الضيف وصل للخادم واللافتة انطفأت.

رحلة العريس فيها خطوتان لبطاقة الدعوة ومناسبات الضيوف (D83): تضيف «الغداء» لمناسبات الخطة برابط مباشر (لا زر لها قبل أسبوع العرس)، ثم تضيف ضيفًا يحضر الغداء أيضًا وتقرأ ردّه في تفاصيله. الخطوتان تحتاجان `planId` في `AARAST_SWEEP_IDS`؛ بدونه تُتخطّيان بملاحظة.

`fresh_groom` تختار الشهر بعد القادم واليوم 15 فيه من ساعة الجهاز، فتمر في أي شهر. وفيها خطوة تحرق الرمز بخمس محاولات غلط ثم تنتظر عدّاد الإرسال (حتى 75 ثانية) وترسله من جديد، فمدتها نحو ثلاث دقائق ونصف. ما تثبته وما لا تثبته في [COUPLE_JOURNEY.md](../project/COUPLE_JOURNEY.md).

## التشغيل بأمر واحد (2026-11-06)

كل الخطوات أدناه مجموعة في `scripts/walks/walks.ps1`: يعيد إنشاء القاعدة المعزولة `aarast_walks_20261101` ويزرعها ويشغّل الخادم على 3116 (`walks-clean.ps1`)، ويشيل `flutter_secure_storage_windows` من ملفي ويندوز ويرجعهما في النهاية، ويحفظ الصور والنصوص في `scripts/walks/out/<الرحلة>/`.

```powershell
& D:\projects\aarast\scripts\walks\walks.ps1 -walks @('groom','route_sweep')
```

- يحتاج Docker Desktop شغالًا (الحاوية `aarast-db`)، ويقول ذلك إن كان مطفأ.
- كلمة سر التجربة في `scripts/walks/walk-pass.txt` (خارج git). المعرّفات تُكتب في `scripts/walks/sweep-ids.txt` تلقائيًا.
- رحلة اسمها يبدأ بـ`offline_groom` تُشغَّل على منفذ مغلق (الخادم بعيد) وتعتمد على نسخة الجوال التي تركتها الرحلة السابقة: شغّل `offline_prime` أو `groom` قبلها.
- لا تشغّل `flutter test` أو اختبارات الخادم أثناء الرحلة.

## التشغيل على قاعدة منفصلة (الخطوات يدويًا)

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
4. **ويندوز:** شيل `flutter_secure_storage_windows` محليًا من `mobile/windows/flutter/generated_plugins.cmake` و`generated_plugin_registrant.cc`، لأنه يحتاج ATL، واضبط `JAVA_HOME` على JDK 17. بعد المشي أرجع الملفين وحدهما: `git checkout -- mobile/windows/flutter/generated_plugins.cmake mobile/windows/flutter/generated_plugin_registrant.cc`. لا تحفظ هذا التعديل.
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
