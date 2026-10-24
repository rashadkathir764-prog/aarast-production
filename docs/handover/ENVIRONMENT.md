# إعدادات اعّرست (أسماء فقط)

آخر تحديث: 16 أكتوبر 2026 · للمشغّل التقني

هذه **أسماء** الإعدادات ومعناها. القيم سرية: لا تُكتب في هذا المستودع ولا
تُرسل في محادثة. مكانها:

- الخادم: `/opt/aarast/app/.env` على خادم الإنتاج (صلاحية `0600`).
- بناء التطبيق: متغيرات بيئة على جهاز البناء، أو `mobile/android/key.properties`
  (غير محفوظ في git) لمفتاح التوقيع.

## الخادم

| الاسم | المعنى | من أين |
|---|---|---|
| `AWS_REGION` | منطقة AWS | ثابت (`eu-central-1`) |
| `AARAST_API_HOST` / `AARAST_ADMIN_HOST` / `AARAST_SITE_HOST` | عناوين الخادم ولوحة الإدارة والموقع | الدومين |
| `AARAST_MEDIA_BUCKET` | حاوية S3 للصور | مخرجات بنية AWS |
| `OPENWA_LINK_TARGET` | المستخدم والخادم لنفق OpenWA | ثابت مؤقت |
| `POSTGRES_DB` | اسم قاعدة البيانات | ثابت |
| `POSTGRES_OWNER_USER` / `POSTGRES_OWNER_PASSWORD` | مالك قاعدة البيانات | يُولَّد على الخادم |
| `AARAST_DB_MIGRATOR_USER` / `AARAST_DB_MIGRATOR_PASSWORD` / `AARAST_DB_MIGRATOR_DATABASE_URL` | حساب تطبيق التحديثات | يُولَّد على الخادم |
| `AARAST_DB_RUNTIME_USER` / `AARAST_DB_RUNTIME_PASSWORD` / `AARAST_DB_RUNTIME_DATABASE_URL` | حساب التشغيل اليومي (صلاحيات أقل) | يُولَّد على الخادم |
| `JWT_ACCESS_SECRET` | توقيع جلسات الدخول؛ تغييره يُخرج الجميع | يُولَّد على الخادم |
| `AUTH_LOGIN_THROTTLE_PEPPER` | حماية عدّاد محاولات الدخول | يُولَّد على الخادم |
| `METRICS_TOKEN` | رمز قراءة `/metrics` | يُولَّد على الخادم |
| `SENTRY_DSN` | إرسال أعطال الخادم إلى Sentry (فارغ = متوقف) | حساب Sentry |
| `PUSH_NOTIFICATIONS_ENABLED` / `FIREBASE_PROJECT_ID` | إشعارات الجوال؛ مفتاح الخدمة يُحفظ في AWS SSM لا في الملف | حساب Firebase |
| `ANTHROPIC_API_KEY` | مفتاح المساعد الذكي (فارغ = المساعد متوقف) | حساب Anthropic |
| `AARAST_ASSISTANT_MODEL` | نموذج المساعد (الافتراضي `claude-opus-5-5`؛ المقبول أيضًا `claude-sonnet-5-5` و`claude-haiku-5-5`) | قرار |
| `AARAST_ASSISTANT_DAILY_LIMIT` | أسئلة المساعد لكل حساب في اليوم (الافتراضي 10) | قرار |
| `AARAST_ASSISTANT_MONTHLY_BUDGET_USD` | سقف إنفاق المساعد الشهري بالدولار (الافتراضي 30) | قرار |

يُستحسن أيضًا وضع حد إنفاق شهري من لوحة Anthropic نفسها، كضمان ثانٍ فوق
سقف التطبيق.

## بناء تطبيق Android

| الاسم | المعنى |
|---|---|
| `AARAST_API_BASE_URL` | عنوان الخادم الذي يتصل به التطبيق |
| `AARAST_INVITE_HOST` | دومين روابط الدعوات وتأكيد الحضور |
| `AARAST_FIREBASE_API_KEY` / `AARAST_FIREBASE_APP_ID` / `AARAST_FIREBASE_MESSAGING_SENDER_ID` / `AARAST_FIREBASE_PROJECT_ID` | ربط الإشعارات (من ملف `google-services.json` لمشروع Firebase) |
| `AARAST_SENTRY_DSN` / `AARAST_SENTRY_TRACES_SAMPLE_RATE` | أعطال التطبيق إلى Sentry |
| `AARAST_SUPPORT_WHATSAPP` | رقم واتساب فريق الدعم بالصيغة الدولية (مثل `+967777000111`)، يظهر في «المساعدة». بدونه تختفي بطاقة واتساب |
| `AARAST_ANDROID_APPLICATION_ID` | معرّف التطبيق (الافتراضي `com.aarast.aarast_mobile`) |
| `AARAST_ANDROID_APP_LABEL` | اسم التطبيق تحت الأيقونة (الافتراضي "اعّرست") |
| `AARAST_ANDROID_STORE_FILE` / `AARAST_ANDROID_STORE_PASSWORD` / `AARAST_ANDROID_KEY_ALIAS` / `AARAST_ANDROID_KEY_PASSWORD` | مفتاح توقيع التطبيق |
