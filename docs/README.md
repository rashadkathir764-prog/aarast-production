# خريطة الوثائق

هذه هي الوثائق الحالية كلها. ما ليس هنا فهو ماضٍ، ومكانه تاريخ git فقط.

## ابدأ من هنا

| الوثيقة | تجيب عن |
|---|---|
| [الحالة](project/STATUS.md) | أين وصلنا، وما الباقي، وما ينتظر رشاد |
| [المنتج](project/PRODUCT.md) | ما هو اعّرست وحدوده |
| [القرارات](project/DECISIONS.md) | القرارات السارية |
| [حالة التصاميم](project/DESIGN_STATUS.md) | ما نُفذ وما بقي وما تأجل لكل مسار |

## المرجع

| المجال | الوثائق |
|---|---|
| المنتج | [رحلة العروسة والعريس](project/JOURNEY_PROFILE.md)، [رحلة المزود](project/PROVIDER_JOURNEY.md)، `project/research/` |
| الخادم | [العقد](backend/API_CONTRACT.md)، [قاعدة البيانات](backend/DATABASE.md)، [التشغيل](backend/README.md)، [الأوامر](SCRIPTS.md) |
| الجوال | [التصميم](frontend/DESIGN_SYSTEM.md)، [المسارات](frontend/MOBILE_ROUTES.md)، [البنية](frontend/MOBILE_ARCHITECTURE.md)، [بدون نت](frontend/OFFLINE_SQLITE.md)، [البدء](frontend/MOBILE.md) |
| الإدارة | [اللوحة](frontend/ADMIN_WEB.md)، [المسارات](frontend/ADMIN_ROUTES.md) |
| الفحص | [الفحوص](qa/README.md)، [الرحلات الآلية](qa/JOURNEY_WALKS.md)، [البيانات التجريبية](qa/DEMO_DATA.md)، [فحص الجوال](qa/MOBILE_QA.md) |
| النشر | [النشر](deployment/README.md)، [رموز الدخول](deployment/OPENWA_OTP_MVP.md)، [التوسع](deployment/SCALING.md)، [المتاجر](deployment/STORE_RELEASE.md) |
| التسليم | [التسليم](handover/README.md)، [الحسابات](handover/ACCOUNTS.md)، [البيئة](handover/ENVIRONMENT.md)، [التشغيل](handover/OPERATIONS.md)، [دليل الإدارة](handover/ADMIN_GUIDE.md) |
| القانوني | [سياسة الخصوصية](legal/PRIVACY_POLICY.md) |

## القواعد

- لا تُضاف وثيقة خطة أو تقرير أو جرد لكل مهمة. التقدم يُكتب في [الحالة](project/STATUS.md) والقرار في [القرارات](project/DECISIONS.md).
- الكود والمخطط والمسارات هي الحقيقة إذا اختلفت الوثيقة عنها، وتُصحح الوثيقة فورًا.
- بعد تغيير المسارات أو العقد شغّل `node scripts/docs-sync.mjs` ثم `node scripts/docs-verify.mjs`.
