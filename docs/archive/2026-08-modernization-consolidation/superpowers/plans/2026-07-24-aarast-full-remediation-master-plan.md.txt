# Aarast Full Remediation Master Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** إغلاق نتائج التدقيق الأمني والتشغيلي والمنتجي بالكامل، ثم إثبات أن Aarast صالح للإطلاق العام دون كسر المال أو المحادثات أو بيانات المستخدمين.

**Architecture:** تُنفذ الخطة كسلسلة حزم مستقلة لا كإصلاح ضخم واحد. تبدأ بحماية بيئة العمل وإضافة اختبارات إعادة الإنتاج، ثم تغلق حدود الهوية والتزامن، وبعدها صلاحيات البنية التحتية، ثم موثوقية Admin وFlutter، وأخيرًا متطلبات الإصدار والمراقبة والتوثيق. لا تنتقل أي مرحلة إلى التالية قبل نجاح بوابة الخروج الخاصة بها.

**Tech Stack:** NestJS 11، Prisma 6، PostgreSQL 16، Redis، MinIO، React/Vite، Flutter 3.41.7، Docker Compose، Dokploy، GitHub Actions.

## Global Constraints

- لا تنفيذ مباشر على `main`، ولا merge قبل اجتياز بوابة المرحلة.
- إنشاء فرع/مساحة عمل معزولة عند بدء التنفيذ فقط وبعد موافقة المستخدم على عمل Git.
- لا `prisma migrate reset` ولا `prisma db push` ولا تعديل migrations مطبقة.
- لا حذف أو تنظيف بيانات دون backup وdry run وموافقة صريحة.
- كل Smoke يكتب بيانات يجب أن يعمل على قاعدة `test` أو `smoke` معزولة.
- إصلاح Backend لا يغيّر تصميم Flutter إلا عندما تكون المشكلة عقدًا ظاهرًا للمستخدم.
- لا تحديث Goldens إلا بعد مقارنة Actual وتوثيق سبب الفرق.
- لا تُطبع الأسرار أو tokens أو بيانات المستخدمين في الأوامر أو التقارير.
- كل إصلاح يبدأ باختبار يفشل، ثم أقل تعديل ممكن، ثم اختبار يمر.
- كل مرحلة لها commit/PR مستقل ومراجعة مستقلة؛ لا تُجمع المراحل في commit واحد.

---

## ترتيب المراحل

| المرحلة | الحزمة | الأولوية | المدة التقديرية |
|---|---|---:|---:|
| 0 | تثبيت خط الأساس وبيئة الاختبار | P0 | 1 يوم |
| 1 | الهوية وRBAC وOTP | P0 | 2-3 أيام |
| 2 | اتساق العروض والمحادثات والمعاملات | P0 | 3-5 أيام |
| 3 | أقل صلاحية للبنية التحتية والنسخ الاحتياطي | P0 | 3-5 أيام |
| 4 | توحيد بيئات Prisma والبناء وCI | P1 | 2-3 أيام |
| 5 | تأمين وموثوقية Admin Web | P1 | 3-4 أيام |
| 6 | صحة Flutter وOffline والصدق المنتجـي | P1 | 3-5 أيام |
| 7 | Push وDeep Links ومتطلبات المتاجر | P1 | 4-7 أيام |
| 8 | التوثيق والمراقبة وإثبات التشغيل | P2 | 2-3 أيام |
| 9 | بوابة الإصدار والتشغيل المرحلي | Release Gate | 2-4 أيام + مراقبة |

المدة الإجمالية المحافظة لمهندس واحد: 4-6 أسابيع. يمكن تنفيذ أجزاء Admin وFlutter بالتوازي فقط بعد إغلاق المرحلتين 1 و2.

---

## Phase 0: تثبيت خط الأساس وبيئة الاختبار

**الهدف:** منع أي إصلاح من تلويث `aarast` أو الاختلاط بتغييرات أخرى، وتحويل كل نتيجة High إلى إعادة إنتاج قابلة للقياس.

**الملفات المتوقعة:**

- Modify: `backend/test/admin-rbac-audit.test.ts`
- Modify: `backend/test/login-throttle.test.ts`
- Modify: `backend/test/otp-controller-context.test.ts`
- Modify: `backend/test/quote-stability.test.ts`
- Modify: `backend/test/provider-chat-logic.test.ts`
- Modify: `backend/test/smoke-isolation.test.ts`
- Modify: `.github/workflows/ci.yml`
- Create عند الحاجة: اختبارات PostgreSQL integration مركزة تحت `backend/test/integration/`

**المهام:**

- [ ] تسجيل `HEAD` و`git status` ونسخ نتائج البوابات الحالية في تقرير المرحلة.
- [ ] إنشاء backup كامل لقاعدة Compose قبل أي migration أو تغيير صلاحيات في المراحل اللاحقة.
- [ ] إثبات أن كل اختبار تكاملي يستخدم قاعدة اسمها يتضمن `test` أو `smoke`.
- [ ] إضافة fail-safe يمنع اختبارات الكتابة من الاتصال بـ`aarast` و`aarast_dev`.
- [ ] تجهيز fixtures وPostgreSQL harness لكل High: تعطيل SUPER_ADMIN، تجاوز OTP بالتزامن، accept/reject race، accept/update race، send/revoke race، مع توثيق أمر إعادة الإنتاج الذي سيبدأ به إصلاحه في المرحلة 1 أو 2.
- [ ] إبقاء Baseline المرحلة 0 أخضر بالكامل؛ يبدأ كل إصلاح لاحق باختبار RED فعلي ثم GREEN داخل مرحلته، ولا تُدمج اختبارات فاشلة عمدًا في خط الأساس.
- [ ] إضافة فحص Git نهائي يثبت أن الاختبارات لم تعدل Goldens أو fixtures بصورة غير مقصودة.

**أوامر البوابة:**

```powershell
git status --short
cd backend
npm.cmd run check
npm.cmd test
npx.cmd prisma validate
cd ../mobile
flutter analyze
flutter test
cd ../admin-web
npm.cmd run typecheck
npm.cmd test
```

**شرط الخروج:**

- لكل نتيجة High fixture وأمر إعادة إنتاج موثّق، ويُسجّل RED الفعلي كأول خطوة في مرحلة إصلاحها قبل كتابة كود المنتج.
- Baseline المرحلة 0 يظل بصفر اختبارات فاشلة أو متخطاة جديدة.
- لا كتابة في `aarast`.
- backup موثّق بالحجم وSHA-256 و`pg_restore --list`.
- الشجرة لا تحتوي تغييرات خارج ملفات الاختبارات/خطة المرحلة.

---

## Phase 1: الهوية وRBAC وOTP

**الهدف:** إغلاق مسارات السيطرة على الحسابات وتجاوز التحقق قبل إصلاح منطق الأعمال.

### 1A — هرمية إدارة الحسابات

**الملفات:**

- Modify: `backend/src/common/admin/admin-permissions.ts`
- Modify: `backend/src/admin/admin.controller.ts`
- Modify: `backend/src/admin/admin.service.ts`
- Modify: `backend/test/admin-rbac-audit.test.ts`
- Modify: `admin-web/src/pages/UsersPage.tsx`

**المتطلبات:**

- [x] `OPERATIONS` لا يستطيع تعطيل أو تفعيل حساب `ADMIN`.
- [x] إدارة حسابات الإدارة تتطلب `SUPER_ADMIN`.
- [x] منع تعطيل النفس.
- [x] منع تعطيل آخر `SUPER_ADMIN` نشط داخل transaction ذرية.
- [x] إخفاء/تعطيل الإجراء في Admin UI مع بقاء Backend مصدر الحقيقة.
- [x] تسجيل Audit Log للفاعل والهدف والنتيجة دون أسرار.

### 1B — فصل جلسة Admin عن جلسة التطبيق

**الملفات:**

- Modify: `backend/src/auth/jwt-payload.interface.ts`
- Modify: `backend/src/auth/jwt.strategy.ts`
- Modify: `backend/src/auth/jwt-auth.guard.ts`
- Modify: `backend/src/admin/admin.guard.ts`
- Modify: `backend/src/auth/auth.service.ts`
- Modify: `backend/test/admin-auth-session-security.test.ts`
- Modify: `backend/test/auth-refresh-wiring.test.ts`

**المتطلبات:**

- [x] إضافة scope صريح وموقع داخل access JWT: `application` أو `admin`.
- [x] `JwtAuthGuard` لمسارات المنتج يرفض admin-scoped tokens.
- [x] `AdminGuard` يطلب admin scope وMFA session حية.
- [x] refresh لا يستطيع تبديل scope.
- [x] logout/revocation يبقيان مفصولين حسب scope.

### 1C — قوة الأسرار وحدود OTP الذرية

**الملفات:**

- Modify: `backend/src/auth/jwt-secret.ts`
- Modify: `backend/src/common/config/runtime-environment.ts`
- Modify: `backend/src/auth/auth.service.ts`
- Modify: `backend/src/auth/login-throttle.service.ts`
- Modify: `backend/test/auth-otp-mode.test.ts`
- Modify: `backend/test/login-throttle.test.ts`
- Modify: `backend/test/auth-registration-security.test.ts`

**المتطلبات:**

- [x] فرض حد آمن لقوة `JWT_SECRET` في production دون طباعة القيمة.
- [x] جعل قراءة OTP وفحصه وزيادة المحاولات/استهلاكه عملية ذرية.
- [x] قفل سجل OTP أو استخدام update مشروط يضمن عدم تجاوز `maxAttempts`.
- [x] اختبار 20 محاولة خاطئة متزامنة يثبت أن عدد المقارنات المقبولة لا يتجاوز الحد.
- [x] اختبار تعارض محاولة صحيحة مع محاولات خاطئة.
- [x] حجز محاولة login قبل مقارنة كلمة المرور بصورة تمنع burst متزامن من تجاوز السقف.

**شرط خروج المرحلة 1:**

- [x] جميع اختبارات الهوية وRBAC تمر.
- [x] اختبارات التزامن تعمل على PostgreSQL حقيقي، لا mocks فقط.
- [x] لا admin token يصل إلى product API.
- [x] لا يمكن تعطيل آخر SUPER_ADMIN.
- [x] لا يمكن تجاوز OTP/login thresholds بالتزامن.

**نتيجة التقييم:** `10/10 — APPROVED` بتاريخ 2026-07-24. أثبت Smoke
معزول على PostgreSQL الحقيقي أن 20 محاولة OTP خاطئة لا تتجاوز السقف، وأن
سباق الصحيح/الخاطئ يملك مستهلكًا ناجحًا واحدًا فقط، وأن 20 محاولة كلمة مرور
متزامنة تسمح بخمس مقارنات فقط وترفض الخمس عشرة الباقية بالقفل. نجحت كذلك
مجموعات Backend وAdmin Web وFlutter الكاملة دون فشل.

---

## Phase 2: اتساق العروض والمحادثات والمعاملات

**الهدف:** جعل كل انتقال حالة وصلاحية يعتمد صفًا مقفولًا وحالة متوقعة داخل transaction واحدة.

### 2A — دورة حياة العرض

**الملفات:**

- Modify: `backend/src/marketplace/quote-offer-acceptance.ts`
- Modify: `backend/src/marketplace/marketplace.service.ts`
- Modify: `backend/src/provider-dashboard/provider-dashboard.service.ts`
- Modify: `backend/src/marketplace/quote-lifecycle.ts`
- Modify: `backend/test/quote-stability.test.ts`
- Modify: `backend/test/financial-integrity.test.ts`

**المتطلبات:**

- [x] accept/reject/update/cancel تستخدم نفس سياسة القفل والحالة المتوقعة.
- [x] reject/update لا يكتبان بعد انتقال العرض من `PENDING`.
- [x] قبول العرض يعيد فحص صلاحيات الخطة والمال داخل المعاملة.
- [x] منع تغيير مبلغ عرض `ACCEPTED`.
- [x] الحفاظ على idempotency: إعادة القبول تعيد نفس `WeddingCost`.
- [x] اختبارات accept-vs-reject وaccept-vs-update وaccept-vs-permission-revoke.
- [x] إثبات عدم وجود Cost أو PlanProviderLink مرتبط بعرض غير مقبول.

**نتيجة تقييم 2A:** `10/10 — APPROVED` بتاريخ 2026-07-24. أصبحت جميع
انتقالات الطلب/العرض تأخذ قفل `QuoteRequest` أولًا ثم `QuoteOffer`، وتعيد قراءة
الحالة والصلاحيات داخل معاملة serializable قبل كتابة مشروطة بالحالة المتوقعة.
نجح Smoke معزول في 100 تكرار لكل من قبول-رفض، قبول-تعديل، قبول-إلغاء،
وقبول-سحب صلاحية (400 سباق حقيقي)، مع تكلفة واحدة ثابتة في replay وصفر
`WeddingCost` و`PlanProviderLink` عندما يفشل القبول. نجحت مجموعة Backend
الكاملة والبناء وPrisma والتوثيق، وعادت موارد Smoke في PostgreSQL وRedis
وMinIO إلى الصفر.

### 2B — سحب صلاحية المحادثة

**الملفات:**

- Modify: `backend/src/conversations/conversations.service.ts`
- Modify: `backend/src/conversations/conversation-policy.ts`
- Modify: `backend/src/sharing/sharing.service.ts`
- Modify: `backend/test/provider-chat-logic.test.ts`
- Modify: `backend/test/websocket-session-hardening.test.ts`

**المتطلبات:**

- [x] إعادة فحص access والمشارك النشط داخل transaction الإرسال.
- [x] عدم استخدام `revokedAt: null` كتأثير جانبي للإرسال أو mark-read.
- [x] فشل إرسال بدأ قبل سحب الصلاحية إذا سبق السحب commit الرسالة.
- [x] قطع Socket وعدم إنشاء Message/Notification/Outbox بعد السحب.
- [x] الحفاظ على فتح المحادثة read-only عندما يكون `providerJoined=false`.

**نتيجة تقييم 2B:** `10/10 — APPROVED` بتاريخ 2026-07-24. أصبح الإرسال وmark-read
يعيدان فحص الصلاحية الحية والمشارك النشط داخل معاملة serializable وبترتيب أقفال
متوافق مع سحب صلاحية المشاركة. لا يعيد أي مسار قراءة أو إرسال تفعيل
`revokedAt`؛ التفعيل محصور في منح `canManageProviders` الصريح. يزيل السحب
Sockets من غرفة المحادثة، وإذا سبق commit الإرسال فلا تُنشأ Message أو
Notification أو Outbox. نجح السباق الحقيقي 100 مرة، ونجح كذلك انضمام المورد
بأول إرسال، وبقاء صلاحية المورد المستقلة إذا كان الحساب عضوًا في الخطة، وحالة
`providerJoined=false` القابلة للقراءة مع منع الإرسال. نجحت مجموعة Backend
الكاملة وSmoke توحيد المحادثات والبناء وPrisma والتوثيق، وعادت موارد Smoke في
PostgreSQL وRedis وMinIO إلى الصفر.

### 2C — الذرية الثانوية

**الملفات:**

- Modify: `backend/src/marketplace/marketplace.service.ts`
- Modify: `backend/src/sharing/sharing.service.ts`
- Modify: `backend/src/common/idempotency/idempotency.interceptor.ts`
- Modify: `backend/src/common/idempotency/idempotency-cleanup.scheduler.ts`
- Modify: `backend/src/auth/auth-challenge-cleanup.scheduler.ts`
- Modify: `backend/src/provider-dashboard/provider-dashboard.service.ts`
- Modify: `backend/src/common/validation/money.ts`
- Modify: `backend/src/main.ts`

**المتطلبات:**

- [x] الإشعارات المهمة تُكتب داخل transaction أو Outbox، ولا ترجع mutation ناجحة كـ5xx بسبب notification.
- [x] إضافة reconciliation موثّق لـambiguous idempotency tombstones.
- [x] تنظيف RefreshToken المنتهي/الملغى بسياسة retention واضحة.
- [x] جعل rating aggregate ذريًا أو اشتقاقه من البيانات بدل cache قابل للفقد.
- [x] استخدام money validator المركزي لكل أسعار المزود.
- [x] إضافة `PUT` إلى CORS واختبار preflight.
- [x] توحيد تفسير `canManageProviders` بين PermissionService والمحادثات.

**شرط خروج المرحلة 2:**

- [x] جميع سباقات quote/chat تمر 100 مرة دون حالة غير صالحة.
- [x] استعلامات invariants تعيد صفر مخالفات.
- [x] اختبارات المال والمحادثات والمشاركة وidempotency كلها خضراء.
- [x] Smoke معزول يثبت القبول والرفض والتعديل والسحب.

**نتيجة تقييم المرحلة 2:** `10/10 — APPROVED` بتاريخ 2026-07-24. مرّت
سباقات العرض والمحادثة 100 مرة لكل بوابة، ونجحت Smokes القبول والرفض
والتعديل والسحب والمال والمشاركة وidempotency وتجميع تقييم المزود. نجحت ترقية
نسخة كاملة معزولة من قاعدة `aarast`: طُبقت المهاجرتان المعلقتان، وأصبح
`migrate status` محدثًا و`migrate diff` فارغًا. أعادت استعلامات العرض المقبول
والتكلفة والرابط وسياق المحادثة ووحدانيتها سبعة أعداد صفرية. نجحت مجموعة
Backend الكاملة: 396 اختبارًا، منها 395 ناجحًا وواحد متجاوز عمدًا على Windows،
مع نجاح TypeScript والبناء وتزامن الوثائق. لم تتغير قاعدة `aarast` الأصلية،
وعادت قواعد Smoke ومفاتيح Redis وحاويات MinIO المؤقتة إلى الصفر.

---

## Phase 3: أقل صلاحية للبنية التحتية والنسخ الاحتياطي

**الهدف:** ألا يمنح اختراق Backend صلاحيات root، وألا تعطي النسخ الاحتياطية نجاحًا كاذبًا.

### 3A — PostgreSQL least privilege

**الملفات:**

- Modify: `deploy/dokploy/docker-compose.yml`
- Modify: `deploy/dokploy/.env.example`
- Modify: `docs/deployment/DOKPLOY_RUNBOOK.md`
- Create: migration/operations SQL آمن لإنشاء `aarast_runtime` و`aarast_migrator`
- Modify: اختبارات Compose والنشر المناسبة

**المتطلبات:**

- [x] فصل owner/migrator عن runtime user.
- [x] Backend runtime لا يملك `SUPERUSER` أو `CREATEDB` أو `CREATEROLE`.
- [x] migrations تعمل في job منفصلة بهوية migrator قبل تشغيل Backend.
- [x] runtime يملك أقل CRUD/sequence privileges اللازمة على schema التطبيق فقط.
- [x] تدوير credentials دون downtime مع خطة rollback.

**نتيجة تقييم 3A:** `10/10 — APPROVED` بتاريخ 2026-07-24. يفصل Compose
الإنتاجي ثلاثة أدوار، ويشغّل تهيئة الصلاحيات ثم migration job قبل Backend الذي
لا ينفذ أي DDL عند startup. طبّق migrator غير المميز 62/62 migration وحقق
فرق Prisma صفرًا. نجح runtime في CRUD وفشل عمدًا في إنشاء جدول وقاعدة ودور
وفي التحول إلى migrator. أثبتت استعلامات الأدوار أن
`SUPERUSER/CREATEDB/CREATEROLE/REPLICATION/BYPASSRLS=false` وأن عضوياته
المميزة صفر. نجحت إعادة SQL بعد وجود جميع الجداول والدوال، وانتقلت ملكيتها
كلها إلى migrator، ونجح تدوير كلمة runtime عبر مصادقة SCRAM فعلية مع رفض
السر القديم. نُظفت قاعدة الاختبار والأدوار بعد كل جولة ولم تتغير `aarast`.

### 3B — MinIO least privilege

**الملفات:**

- Modify: `deploy/dokploy/docker-compose.yml`
- Modify: `docker-compose.yml`
- Modify: media-init scripts/config
- Modify: `docs/deployment/DOKPLOY_RUNBOOK.md`

**المتطلبات:**

- [x] Root credentials تُستخدم لتهيئة MinIO فقط ولا تدخل Backend.
- [x] إنشاء service account بسياسة bucket/prefix محدودة.
- [x] backend لا يستطيع إدارة المستخدمين أو السياسات أو buckets أخرى.
- [x] اختبار public prefixes والـprivate `chat-image` بعد التغيير.

**نتيجة تقييم 3B:** `10/10 — APPROVED` بتاريخ 2026-07-24. أصبحت root
credentials محصورة في MinIO وinitializer، ويستلم Backend service account
مقيدًا بالـbucket وخمسة prefixes وبأفعال location/put/get/delete فقط. استبدل
فحص الجاهزية `HeadBucket` بـ`GetBucketLocation` حتى لا يحتاج ListBucket.
أثبتت بروفة حية أن تدوير السر يلغي القديم، وأن CRUD يعمل في public وprivate
prefixes، وأن القراءة المجهولة تنجح للأصول العامة وتُرفض لـ`chat-image`.
فشلت عمدًا إدارة bucket والسياسة والكتابة خارج النطاق والوصول إلى bucket
آخر، وأعادت قائمة MinIO المرشحة الـbucket المسموح وحده. لا تطبع عملية
initializer السر، ونُظف الحساب والـbucketان المعزولان بعد الاختبار.

### 3C — Backup/restore proof

**الملفات:**

- Modify: `deploy/dokploy/scripts/verify-backup-restore.sh`
- Modify: `deploy/dokploy/scripts/verify-backup-restore.test.mjs`
- Modify: `docs/deployment/DOKPLOY_RUNBOOK.md`

**المتطلبات:**

- [ ] SHA-256 يصبح إلزاميًا في مسار release.
- [ ] إنشاء manifest قبل backup: الجداول الحرجة، counts، migration head، وحجم تقريبي.
- [ ] الاستعادة تقارن counts/manifest ولا تكتفي بوجود الجداول.
- [ ] dump فارغ أو schema-only يجب أن يفشل اختبارًا صريحًا.
- [ ] dump تالف أو ناقص جدولًا حرجًا يجب أن يفشل.
- [ ] إثبات نسخة off-host مشفرة وسياسة retention.

### 3D — الشبكات والمنافذ

**الملفات:**

- Modify: `docker-compose.yml`
- Modify: `deploy/dokploy/docker-compose.yml`
- Modify: `deploy/monitoring/docker-compose.yml`
- Modify: `docs/deployment/README.md`

**المتطلبات:**

- [ ] منافذ التطوير الحساسة ترتبط بـ`127.0.0.1`.
- [ ] Redis لا يُنشر على LAN؛ أضف auth إذا بقي منشورًا لسبب حقيقي.
- [ ] فصل شبكة Admin عن DB/Redis/Media حيث لا توجد حاجة مباشرة.
- [ ] جعل OpenWA network/profile مشروطًا فعليًا بـOpenWA.
- [ ] clean WhatsApp deployment ينجح دون شبكة staging.
- [ ] توصيل Prometheus بالشبكة الفعلية واختبار scrape.
- [ ] إعداد Alertmanager receiver حقيقي واختبار alert تجريبي.

**شرط خروج المرحلة 3:**

- runtime DB role وMinIO key محدودان مثبتان بأوامر read-only.
- restore كامل يطابق manifest، والنسخة الفارغة تفشل.
- clean deploy ينجح في WhatsApp mode دون OpenWA.
- لا منافذ DB/Redis/MinIO dev على `0.0.0.0`.

---

## Phase 4: توحيد Prisma والبناء وCI

**الهدف:** جعل المصدر والمخطط والحاوية وCI قابلة لإعادة الإنتاج من commit محدد.

**الملفات:**

- Modify محليًا فقط عند الموافقة: `backend/.env`
- Modify: env examples والوثائق ذات الصلة
- Create: `backend/prisma.config.ts`
- Modify: `backend/package.json`
- Create: `.nvmrc` أو ملف pinning معتمد لـNode 22
- Modify: `.github/workflows/ci.yml`
- Modify: Dependabot config
- Modify: Dockerfiles غير المثبتة

**المهام:**

- [ ] اعتماد `aarast` كقاعدة Compose المحلية الوحيدة للـruntime.
- [ ] عدم حذف `aarast_dev`؛ أخذ backup ثم إما migrate deploy أو إيقاف استخدامها بقرار موثق.
- [ ] إثبات 60/60 migrations وdiff فارغ على كل بيئة معتمدة.
- [ ] نقل Prisma config بعيدًا عن `package.json#prisma`.
- [ ] تثبيت Node 22 محليًا وCI وDocker.
- [ ] كل image تحمل full Git SHA وcontent digest؛ `/live` أو metadata آمنة تعرض revision.
- [ ] تثبيت GitHub Actions على commit SHAs وإضافة least-privilege permissions وtimeouts.
- [ ] إضافة Windows Golden job أو artifact comparison مع بوابة مراجعة.
- [ ] جعل dependency gate تتعامل مع Moderate المعروفة بسياسة زمنية صريحة، لا تتجاهلها.
- [ ] توسيع Dependabot ليغطي Docker/Compose/deploy images.

**شرط الخروج:**

- build نظيف من clone جديد ينتج نفس العقود.
- container revision يساوي source HEAD.
- CI كامل أخضر على commit المرحلة.
- لا قاعدة افتراضية بمigrations معلقة.

---

## Phase 5: تأمين وموثوقية Admin Web

**الهدف:** إغلاق اعتماديات الإدارة وتجربة الجلسة والأخطاء والـCSP.

**الملفات المتوقعة:**

- Modify: `admin-web/package.json`
- Modify: `admin-web/package-lock.json`
- Modify: `admin-web/src/api/client.ts`
- Modify: `admin-web/src/auth/AuthProvider.tsx`
- Modify: `admin-web/src/layout/Topbar.tsx`
- Modify: `admin-web/src/components/ConfirmDialog.tsx`
- Modify: الصفحات التي تنفذ mutations
- Modify: `admin-web/nginx.conf`
- Modify: `admin-web/Dockerfile`
- Modify/Add: اختبارات Admin ذات الصلة

**المهام:**

- [ ] ترقية React Router إلى إصدار مصحح، مع خطة ترحيل router واختبارات routes.
- [ ] عند فشل refresh: مسح user state، إلغاء الطلبات، والتوجيه إلى login مرة واحدة.
- [ ] إزالة `ui-avatars.com` أو توليد avatar محلي؛ لا توسيع CSP إلى wildcard.
- [ ] السماح فقط بـmedia origin الرسمي عندما تكون الصور مطلوبة.
- [ ] تحديث Nginx إلى إصدار مصحح مثبت digest، وتفعيل HSTS و`server_tokens off`.
- [ ] إضافة confirmation للإجراءات المدمرة.
- [ ] عرض أخطاء mutation ومنع double submit.
- [ ] إصلاح قوائم المزودين التي تتوقف عند أول 100 صف.
- [ ] تقليل ظهور هاتف المبلّغ حسب الدور والحاجة.
- [ ] تقوية build-config smoke لرفض كل HTTP/private/local origins في release.

**شرط الخروج:**

- `npm audit --omit=dev` صفر known vulnerabilities أو استثناء موثق مؤقت بموعد إزالة.
- Admin typecheck/test/build/routes/runtime smoke كلها خضراء.
- CSP report لا يحتوي blocked app resources.
- انتهاء الجلسة ينقل المستخدم إلى login دون loop.

---

## Phase 6: صحة Flutter وOffline والصدق المنتجـي

**الهدف:** منع فساد Queue أو فشل ترحيل الضيف وإزالة عناصر UI التي لا تنفذ ما توحي به.

**الملفات المتوقعة:**

- Modify: `mobile/lib/core/config/app_feature_flags.dart`
- Modify: `mobile/lib/core/routing/app_router.dart`
- Modify: `mobile/lib/main.dart`
- Modify: `mobile/lib/features/onboarding/data/local_plan_migration.dart`
- Modify: `mobile/lib/core/offline/local_database_mobile.dart`
- Modify: `mobile/lib/core/offline/local_database_json.dart`
- Modify: `mobile/lib/features/finance/providers/finance_provider.dart`
- Modify: `mobile/lib/features/settings/screens/settings_screen.dart`
- Modify: `mobile/lib/features/support/screens/support_screen.dart`
- Modify: accessibility/terminology widgets
- Modify/Add: الاختبارات المطابقة

**المهام:**

- [ ] إما ربط feature flags فعليًا بالتشغيل أو حذف الأعلام الميتة؛ لا إبقاء rollout claims وهمية.
- [ ] إزالة `dueDate` من WeddingCost import مع fixture legacy يثبت نجاح الترحيل.
- [ ] استبدال `replaceAll` الخام بإعادة كتابة JSON structured لمفاتيح FK المعروفة وpath segments المطابقة.
- [ ] توحيد سلوك SQLCipher وJSON fallback واختبار النصوص التي تحتوي local ID دون تغييرها.
- [ ] عند 401/403/404 مالي: إزالة البيانات الخاصة غير المسموح بها وتحديث access state.
- [ ] إخفاء Push switch حتى اكتمال Phase 7 أو تسميته كسلوك in-app حقيقي فقط.
- [ ] إضافة قناة دعم فعلية مع رابط موثوق وسياسة خصوصية.
- [ ] توحيد مصطلحات المال وإغلاق صيغ الجمع غير المغطاة.
- [ ] إضافة Semantics/Tooltip واختبارات accessibility.
- [ ] ترقية dependencies المباشرة تدريجيًا، مع اختبار توافق Socket.IO قبل major upgrade.

**شرط الخروج:**

- Flutter Analyze و721+ tests وGoldens تمر.
- اختبارات SQLCipher وJSON parity تمر.
- legacy local-plan migration ينجح حيًا على Backend معزول.
- لا عنصر إعدادات ظاهر بلا أثر حقيقي.
- 320px وRTL وtext scaling بلا overflow.

---

## Phase 7: Push وDeep Links ومتطلبات المتاجر

**الهدف:** تحويل متطلبات الإصدار الخارجية من placeholders إلى عقود حية مثبتة.

**الملفات المتوقعة:**

- Create: Prisma migration لنموذج DeviceToken بعد اعتماد التصميم
- Create/Modify: Backend notification delivery/outbox endpoints
- Modify: `mobile/pubspec.yaml`
- Modify: Android/iOS notification configuration
- Modify: `deploy/public-site/assetlinks.json`
- Create: `deploy/public-site/apple-app-site-association`
- Modify: `deploy/public-site/nginx.conf`
- Modify: store/release documentation

**المهام:**

- [ ] اعتماد تصميم DeviceToken: user/device/platform/token hash/lastSeen/revocation.
- [ ] تسجيل وإبطال tokens مع logout/account deletion.
- [ ] fan-out عبر Outbox مع retries وdead-letter/metrics دون كشف payloads حساسة.
- [ ] إضافة `firebase_messaging` وpermissions وclick routing.
- [ ] احترام notification preferences والخصوصية المالية.
- [ ] نشر AASA بهوية Apple الحقيقية واختباره على جهاز فعلي.
- [ ] مطابقة Android assetlinks مع production Play signing certificate.
- [ ] بناء AAB موقّع وتحقق signer/versionCode.
- [ ] بناء iOS Archive/TestFlight على macOS.
- [ ] استكمال privacy policy، data safety، screenshots، support contact وstore listing.

**شرط الخروج:**

- Push يصل في foreground/background/terminated ويفتح المسار الصحيح.
- logout/revocation يمنع الإرسال للجهاز القديم.
- App Links وUniversal Links ينجحان على أجهزة فعلية.
- AAB وiOS Archive موقعان بالهويات النهائية.
- لا بيانات مالية حساسة في notification lock-screen payload.

---

## Phase 8: التوثيق والمراقبة وإثبات التشغيل

**الهدف:** جعل الوثائق والفحوص تكشف drift بدل تمريره.

**الملفات:**

- Modify: `scripts/docs-sync.mjs`
- Modify/Add: اختبارات parser
- Regenerate: `docs/frontend/ADMIN_ROUTES.md`
- Modify: `docs/project/STATUS.md`
- Modify: `docs/project/RELEASE_PLAN.md`
- Modify: `docs/qa/MOBILE_QA.md`
- Modify: `docs/deployment/*`
- Modify: monitoring configs/runbook

**المهام:**

- [ ] جعل parser يقرأ multi-line `<Route>` ويثبت نحو 21 route فعلية.
- [ ] إضافة fixture يفشل parser القديم.
- [ ] تحديث أرقام tests/migrations/revision من نتائج آلية.
- [ ] توحيد bottom navigation contract.
- [ ] إزالة منتجات قديمة من store listing.
- [ ] توثيق DB/MinIO role separation وbackup manifest وclean deploy.
- [ ] نشر dashboards وalerts للمصادقة وOTP/outbox/idempotency/media/DB.
- [ ] اختبار receiver فعليًا وإثبات وصول alert.

**شرط الخروج:**

- docs-sync يفشل عمدًا عند حذف route fixture.
- لا أرقام release قديمة أو placeholders.
- monitoring scrape وalert delivery مثبتان.
- runbooks قابلة للتنفيذ من مشغل لا يعرف تاريخ المشروع.

---

## Phase 9: بوابة الإصدار والتشغيل المرحلي

**الهدف:** قرار إطلاق قائم على أدلة جديدة من نفس commit والصور النهائية.

**الترتيب الإلزامي:**

- [ ] تجميد release candidate commit.
- [ ] بناء صور immutable تحمل SHA الكامل وتسجيل digests.
- [ ] `prisma validate` وmigrate status/diff على قاعدة ترقية مماثلة للإنتاج.
- [ ] استعادة أحدث backup إلى بيئة معزولة ومقارنة manifest.
- [ ] Backend check/build/test الكامل.
- [ ] كل Smoke المعزولة، بما فيها concurrency وaccount deletion وmedia وquotes/chat.
- [ ] Admin typecheck/test/build/honesty/routes/runtime smoke.
- [ ] Flutter analyze/test/Goldens وRelease AAB.
- [ ] فحص dependency/secret/container images.
- [ ] clean deploy إلى staging من صفر.
- [ ] QA جهاز فعلي: Android وiOS، offline/reconnect/logout/deep links/push/media.
- [ ] load test محدود للـOTP وquotes/chat والمال.
- [ ] نشر production مع backup وrollback plan.
- [ ] تحقق post-deploy من revision والداتابيس وRedis وMinIO وOpenWA/WhatsApp.
- [ ] مراقبة 24 ساعة على الأقل مع alert receiver فعلي.
- [ ] قرار GO/NO-GO مكتوب.

**معايير GO النهائية:**

- صفر Critical أو High مفتوحة.
- صفر اختبارات فاشلة، وكل skip مبرر ومقبول.
- صفر فرق Prisma.
- restore يطابق manifest.
- لا runtime root credentials.
- CI على release SHA أخضر.
- AAB/iOS/deep links/push والجهاز الفعلي مثبتة.
- لا drift بين source/schema/database/container/deployed revision.

---

## ما لا ينبغي فعله

- لا إصلاح كل النتائج في PR واحد.
- لا ترقية React Router أو Socket.IO مع تغييرات منطق أعمال في الحزمة نفسها.
- لا تغيير Models المالية لمعالجة سباقات Quote؛ أصلح حدود transaction أولًا.
- لا استخدام Goldens كطريقة لإخفاء regression.
- لا تشغيل smokes على `aarast`.
- لا حذف `aarast_dev` أو بياناتها لإجبار الاتساق.
- لا إبقاء backend migrations في startup بعد فصل runtime DB user.
- لا اعتماد Health 200 كإثبات أن revision الصحيح منشور.
- لا إطلاق Push قبل مراجعة خصوصية payloads المالية.

## نقطة التوقف والمراجعة

بعد كل مرحلة يُسلّم تقرير يحتوي:

1. السبب الجذري الذي أُغلق.
2. الملفات المعدلة.
3. migrations وأثرها، إن وجدت.
4. اختبارات الفشل قبل الإصلاح والنجاح بعده.
5. نتائج suite كاملة.
6. أثر البيانات وخطة rollback.
7. `git diff --check` و`git status`.
8. قرار واضح: الانتقال للمرحلة التالية أو التوقف.
