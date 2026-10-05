# جرد البداية لخطة فحص أعرست بالكامل

- التاريخ:2026-10-04.
- المصدر: `14eccb50c6b2e050b044c7b00ac38a7e64f5164b`.
- الغرض: منع سقوط قسم من خطة الفحص، لا إعلان فحص جميع العناصر أو اعتماد تصميم جديد.
- الحالة: **SOURCE INVENTORY SEED — NOT A COMPLETED PRODUCT AUDIT**.
- [الخطة](../superpowers/plans/2026-10-04-whole-product-discovery-and-acceptance-audit.md) و[تصميم الفحص](../superpowers/specs/2026-10-04-whole-product-audit-design.md).

## حدود العد

- 20 مجلدfeature في Mobile.
- 70 ملفًا داخل screens؛ تشمل tabs/parts، فلا تعد 70 شاشة منفصلة.
- 496 declaration candidates لـStatefulWidget/StatelessWidget من مسح نحوي؛ ليست 496 كرتًا.
- 64 string route مستخرجة في docs-sync، لا تثبت وحدها 64 GoRoute reachable؛ الجذر والـredirects والـconstants والـshell تحتاج reconciliation.
- 18 ملفPage.tsx لـAdmin و22 route، وبعضroutes aliases/redirects.
- الأقسام والـcards والـdialogs والـforms والـstates لا يمكن عدها من أسماء الملفات. سجل01-surface-register في التنفيذ هو مصدر تغطيتها النهائي.
- الأعداد لا تثبت الصحة أو الفائدة أو القبول. جميع النتائج التفصيلية **NOT STARTED** إلى حين تنفيذ المهام.

## نطاق Mobile: الغرض وأسئلة الفحص

الغرض هنا قراءة مبدئية للقصد المعتمد والبنية الحالية؛ يتأكد من مصدر كل عنصر ورحلته أثناء الفحص.

| Feature | ملفات screens في الجرد | الغرض | محور الفحص |
| --- | --- | --- | --- |
| welcome_gateway | 1 | يفهم الزائر المنتج ويختار بداية مناسبة | الدخول من رابط أو بداية جديدة؛ الوعد والخطوة التالية |
| onboarding | 1 | يجهز سياق العرس بالمعلومات اللازمة | ما يجب الآن وما يمكن تأجيله؛ عدم ضياع المدخل |
| auth | 5 | يثبت الحساب ويستعيد الوصول إليه | OTP/password/session؛ فشل صريح بلا تجاوز |
| account_contexts | 1 | يختار من يمثل وأي مساحة يستخدم | مالك/مساهم/مزود؛ الحقوق والبيانات لا تختلط |
| shell | 1 | يحافظ على التنقل والسياق العام | tab/back/deep link/cold start |
| home | 3 | يعرف المستخدم ما يحتاج فعله الآن | الأولوية، دقة الأرقام، الصلاحية، CTA |
| wedding_plans | 7 | ينشئ ويضبط ويختار ويدير سياق الخطة | مركز الخطة مقابل الرئيسية؛ مسؤولية كل مدخل |
| finance | 9 | يفهم الميزانية والتكلفة والمدفوع والمتبقي والتذكيرات | حقيقة ledger، الخصوصية، pending، أثر كل فعل |
| tasks | 5 | ينظم العمل ومن يقوم به ومتى | تكليف/إنجاز/عدادات/تاريخ/تعارض |
| guests | 2 | ينظم المدعوين والمجموعات والحضور | العدد والخصوصية والبحث والتعديل |
| sharing | 9 | يدعو ويشارك بحقوق ويعرف مسؤولية المساهم | accept/revoke/leave/history وتوافق UI/API |
| marketplace | 8 | يكتشف مزودًا ويطلب عرضًا ويراجع العلاقة | profile/services/favorites/reviews/quotes/plan link |
| chat | 2 | يتواصل ضمن طلب عرض حقيقي | الأطراف/التاريخ/الوسائط/الحالات/unread/moderation |
| provider_portal | 11 | يجهز ملفه ويعرف اعتماده ويدير طلباته وخدماته | Pending/Active؛ ما يستطيع فعله في كل مرحلة |
| notifications | 1 | يعرف الحدث ويصل إلى الإجراء الصحيح | الحقيقة، التكرار، القراءة، context وdevice delivery |
| wedding_day | 1 | يرى ما يهم التنفيذ في يوم العرس | مواعيد ومسؤوليات ومصادر الاتصال؛ offline |
| catalogs | 0 | يحصل على خيارات مرجعية صحيحة ومتسقة | مصدر/نسخة/cache ومصطلحات المنطقة والفئة |
| settings | 1 | يضبط الخيارات الموجودة بوضوح | أثر الخيار وحدود الجهاز/الحساب |
| more | 1 | يصل إلى وظائف أقل تكرارًا دون فقد السياق | التكرار مع الأقسام الأساسية ووضوح التنظيم |
| support | 1 | يجد مساعدة مفهومة وطريقة متابعة | الوعد الفعلي بالمساعدة والأخطاء والروابط |

## Mobile route strings — baseline for reconciliation

من docs/frontend/MOBILE_ROUTES.md وscanner الحالي. dev routes تصنف development-only إن أثبتت guards ذلك؛ لا تختفي من السجل. سجل root والـmodal/tab/context surfaces مستقلة عند اكتشافها.

- M-R01: `/conversations` — classification pending.
- M-R02: `/conversations/:id` — classification pending.
- M-R03: `/dashboard` — classification pending.
- M-R04: `/dev/guest-onboarding` — classification pending.
- M-R05: `/dev/user-navigation-shell` — classification pending.
- M-R06: `/home` — classification pending.
- M-R07: `/invites` — classification pending.
- M-R08: `/invites/:token` — classification pending.
- M-R09: `/login` — classification pending.
- M-R10: `/more` — classification pending.
- M-R11: `/notifications` — classification pending.
- M-R12: `/onboarding` — classification pending.
- M-R13: `/otp` — classification pending.
- M-R14: `/provider/apply` — classification pending.
- M-R15: `/provider/apply/status` — classification pending.
- M-R16: `/provider/dashboard` — classification pending.
- M-R17: `/provider/packages/new` — classification pending.
- M-R18: `/provider/profile/edit` — classification pending.
- M-R19: `/provider/services/new` — classification pending.
- M-R20: `/providers` — classification pending.
- M-R21: `/providers/:id` — classification pending.
- M-R22: `/providers/:id/quote` — classification pending.
- M-R23: `/providers/:id/quote-request` — classification pending.
- M-R24: `/providers/favorites` — classification pending.
- M-R25: `/quotes/:id/conversation` — classification pending.
- M-R26: `/register` — classification pending.
- M-R27: `/reset-password` — classification pending.
- M-R28: `/settings` — classification pending.
- M-R29: `/shared/wedding-plans` — classification pending.
- M-R30: `/support` — classification pending.
- M-R31: `/wedding-plans` — classification pending.
- M-R32: `/wedding-plans/:id/contributions` — classification pending.
- M-R33: `/wedding-plans/:id/dashboard` — classification pending.
- M-R34: `/wedding-plans/:id/guests` — classification pending.
- M-R35: `/wedding-plans/:id/guests/add` — classification pending.
- M-R36: `/wedding-plans/:id/money` — classification pending.
- M-R37: `/wedding-plans/:id/money/budget` — classification pending.
- M-R38: `/wedding-plans/:id/money/categories/:categoryId` — classification pending.
- M-R39: `/wedding-plans/:id/money/categories/:categoryId/edit` — classification pending.
- M-R40: `/wedding-plans/:id/money/categories/create` — classification pending.
- M-R41: `/wedding-plans/:id/money/costs` — classification pending.
- M-R42: `/wedding-plans/:id/money/costs/:costId` — classification pending.
- M-R43: `/wedding-plans/:id/money/costs/:costId/edit` — classification pending.
- M-R44: `/wedding-plans/:id/money/costs/:costId/payments/create` — classification pending.
- M-R45: `/wedding-plans/:id/money/costs/:costId/schedules/:scheduleId` — classification pending.
- M-R46: `/wedding-plans/:id/money/costs/:costId/schedules/:scheduleId/edit` — classification pending.
- M-R47: `/wedding-plans/:id/money/costs/:costId/schedules/:scheduleId/pay` — classification pending.
- M-R48: `/wedding-plans/:id/money/costs/:costId/schedules/create` — classification pending.
- M-R49: `/wedding-plans/:id/money/costs/create` — classification pending.
- M-R50: `/wedding-plans/:id/money/payments/:paymentId` — classification pending.
- M-R51: `/wedding-plans/:id/money/schedules` — classification pending.
- M-R52: `/wedding-plans/:id/notifications` — classification pending.
- M-R53: `/wedding-plans/:id/plan-center` — classification pending.
- M-R54: `/wedding-plans/:id/providers` — classification pending.
- M-R55: `/wedding-plans/:id/sharing` — classification pending.
- M-R56: `/wedding-plans/:id/sharing/:memberId/edit` — classification pending.
- M-R57: `/wedding-plans/:id/sharing/add` — classification pending.
- M-R58: `/wedding-plans/:id/tasks` — classification pending.
- M-R59: `/wedding-plans/:id/tasks/:taskId/edit` — classification pending.
- M-R60: `/wedding-plans/:id/tasks/create` — classification pending.
- M-R61: `/wedding-plans/:id/timeline` — classification pending.
- M-R62: `/wedding-plans/:id/wedding-day` — classification pending.
- M-R63: `/wedding-plans/create` — classification pending.
- M-R64: `/welcome` — classification pending.

## Mobile screen-source files — expand into semantic surfaces

كل ملف يحتاج ربطه بالسطح/الجزء والـroute أو parent screen، ثم جرد محتواه. لا يعتبر ملف part شاشة إضافية ولا يترك دون تغطية.

- M-S01: `mobile/lib/features/account_contexts/screens/account_context_selection_screen.dart`.
- M-S02: `mobile/lib/features/auth/screens/login_screen.dart`.
- M-S03: `mobile/lib/features/auth/screens/otp_screen.dart`.
- M-S04: `mobile/lib/features/auth/screens/register_screen.dart`.
- M-S05: `mobile/lib/features/auth/screens/reset_password_screen.dart`.
- M-S06: `mobile/lib/features/auth/screens/splash_screen.dart`.
- M-S07: `mobile/lib/features/chat/screens/chat_screen.dart`.
- M-S08: `mobile/lib/features/chat/screens/quote_conversation_entry_screen.dart`.
- M-S09: `mobile/lib/features/finance/screens/budget_category_details_screen.dart`.
- M-S10: `mobile/lib/features/finance/screens/budget_category_form_screen.dart`.
- M-S11: `mobile/lib/features/finance/screens/cost_details_screen.dart`.
- M-S12: `mobile/lib/features/finance/screens/cost_form_screen.dart`.
- M-S13: `mobile/lib/features/finance/screens/cost_payment_screens.dart`.
- M-S14: `mobile/lib/features/finance/screens/costs_screen.dart`.
- M-S15: `mobile/lib/features/finance/screens/money_budget_screen.dart`.
- M-S16: `mobile/lib/features/finance/screens/money_overview_screen.dart`.
- M-S17: `mobile/lib/features/finance/screens/payment_schedule_screens.dart`.
- M-S18: `mobile/lib/features/guests/screens/guest_list_screen_helpers.dart`.
- M-S19: `mobile/lib/features/guests/screens/guest_list_screen.dart`.
- M-S20: `mobile/lib/features/home/screens/dashboard_entry_screen.dart`.
- M-S21: `mobile/lib/features/home/screens/home_screen.dart`.
- M-S22: `mobile/lib/features/home/screens/local_guest_dashboard_screen.dart`.
- M-S23: `mobile/lib/features/marketplace/screens/favorite_providers_screen.dart`.
- M-S24: `mobile/lib/features/marketplace/screens/provider_details_screen.dart`.
- M-S25: `mobile/lib/features/marketplace/screens/provider_details_screen.widgets.dart`.
- M-S26: `mobile/lib/features/marketplace/screens/provider_marketplace_screen.dart`.
- M-S27: `mobile/lib/features/marketplace/screens/provider_marketplace_screen.labels.dart`.
- M-S28: `mobile/lib/features/marketplace/screens/provider_marketplace_screen.results.dart`.
- M-S29: `mobile/lib/features/marketplace/screens/provider_marketplace_screen.sections.dart`.
- M-S30: `mobile/lib/features/marketplace/screens/quote_request_screen.dart`.
- M-S31: `mobile/lib/features/more/screens/more_screen.dart`.
- M-S32: `mobile/lib/features/notifications/screens/notifications_screen.dart`.
- M-S33: `mobile/lib/features/onboarding/screens/local_plan_migration_screen.dart`.
- M-S34: `mobile/lib/features/provider_portal/screens/add_provider_package_screen.dart`.
- M-S35: `mobile/lib/features/provider_portal/screens/add_provider_service_screen.dart`.
- M-S36: `mobile/lib/features/provider_portal/screens/edit_provider_profile_screen.dart`.
- M-S37: `mobile/lib/features/provider_portal/screens/provider_apply_screen.dart`.
- M-S38: `mobile/lib/features/provider_portal/screens/provider_catalog_management_widgets.dart`.
- M-S39: `mobile/lib/features/provider_portal/screens/provider_home_tab.dart`.
- M-S40: `mobile/lib/features/provider_portal/screens/provider_portal_screen.dart`.
- M-S41: `mobile/lib/features/provider_portal/screens/provider_portal_tabs.dart`.
- M-S42: `mobile/lib/features/provider_portal/screens/provider_profile_tab.dart`.
- M-S43: `mobile/lib/features/provider_portal/screens/provider_requests_tab.dart`.
- M-S44: `mobile/lib/features/provider_portal/screens/provider_services_tab.dart`.
- M-S45: `mobile/lib/features/settings/screens/settings_screen.dart`.
- M-S46: `mobile/lib/features/sharing/screens/add_shared_member_screen.dart`.
- M-S47: `mobile/lib/features/sharing/screens/contribution_history_screen.dart`.
- M-S48: `mobile/lib/features/sharing/screens/edit_shared_member_screen.dart`.
- M-S49: `mobile/lib/features/sharing/screens/invite_decision_screen.dart`.
- M-S50: `mobile/lib/features/sharing/screens/invite_decision_screen.details.dart`.
- M-S51: `mobile/lib/features/sharing/screens/invite_decision_screen.notices.dart`.
- M-S52: `mobile/lib/features/sharing/screens/invite_decision_screen.steps.dart`.
- M-S53: `mobile/lib/features/sharing/screens/shared_wedding_plans_screen.dart`.
- M-S54: `mobile/lib/features/sharing/screens/sharing_screen.dart`.
- M-S55: `mobile/lib/features/shell/screens/wedding_plan_shell.dart`.
- M-S56: `mobile/lib/features/support/screens/support_screen.dart`.
- M-S57: `mobile/lib/features/tasks/screens/create_task_screen_draft.dart`.
- M-S58: `mobile/lib/features/tasks/screens/create_task_screen.dart`.
- M-S59: `mobile/lib/features/tasks/screens/task_timeline_screen.dart`.
- M-S60: `mobile/lib/features/tasks/screens/task_timeline_screen.logic.dart`.
- M-S61: `mobile/lib/features/tasks/screens/task_timeline_screen.timeline.dart`.
- M-S62: `mobile/lib/features/wedding_day/screens/wedding_day_mode_screen.dart`.
- M-S63: `mobile/lib/features/wedding_plans/screens/create_wedding_plan_screen.dart`.
- M-S64: `mobile/lib/features/wedding_plans/screens/my_wedding_plans_screen.dart`.
- M-S65: `mobile/lib/features/wedding_plans/screens/plan_center_screen.dart`.
- M-S66: `mobile/lib/features/wedding_plans/screens/plan_management_screen.contributor_account.dart`.
- M-S67: `mobile/lib/features/wedding_plans/screens/plan_management_screen.dart`.
- M-S68: `mobile/lib/features/wedding_plans/screens/plan_management_screen.plan_edit.dart`.
- M-S69: `mobile/lib/features/wedding_plans/screens/wedding_plan_dashboard_screen.dart`.
- M-S70: `mobile/lib/features/welcome_gateway/screens/smart_welcome_screen.dart`.

## Admin pages — purpose and control chain

القائمة تشمل login/dashboard/reports، approval/provider management، users، reference/catalog/locations/services، reviews/moderation، notifications/audit. تدقق تفاصيل كل عنصر والحقوق والأثر على الهاتف؛ لا يكفي فتح الصفحة.

- A-S01: `admin-web/src/features/audit/AuditLogsPage.tsx`.
- A-S02: `admin-web/src/features/auth/LoginPage.tsx`.
- A-S03: `admin-web/src/features/catalog/AdministrativeAreasPage.tsx`.
- A-S04: `admin-web/src/features/catalog/CategoriesPage.tsx`.
- A-S05: `admin-web/src/features/catalog/CitiesPage.tsx`.
- A-S06: `admin-web/src/features/catalog/ReferenceCatalogsPage.tsx`.
- A-S07: `admin-web/src/features/catalog/ServicesPage.tsx`.
- A-S08: `admin-web/src/features/dashboard/DashboardPage.tsx`.
- A-S09: `admin-web/src/features/dashboard/ReportsPage.tsx`.
- A-S10: `admin-web/src/features/moderation/ConversationReportsPage.tsx`.
- A-S11: `admin-web/src/features/moderation/ReviewsPage.tsx`.
- A-S12: `admin-web/src/features/notifications/NotificationsPage.tsx`.
- A-S13: `admin-web/src/features/providers/ProviderApplicationDetailsPage.tsx`.
- A-S14: `admin-web/src/features/providers/ProviderApplicationsPage.tsx`.
- A-S15: `admin-web/src/features/providers/ProviderDetailsPage.tsx`.
- A-S16: `admin-web/src/features/providers/ProvidersPage.tsx`.
- A-S17: `admin-web/src/features/users/UserDetailsPage.tsx`.
- A-S18: `admin-web/src/features/users/UsersPage.tsx`.

### Admin routes

`/new` ليس دليلًا على create screen؛ بعضهاredirect إلى  صفحة موجودة. يصنف كل alias بعد قراءة App.tsx، ولا يحسب كعيب تلقائي.

- A-R01: `/` — classification pending.
- A-R02: `/admin` — classification pending.
- A-R03: `/administrative-areas` — classification pending.
- A-R04: `/audit-logs` — classification pending.
- A-R05: `/categories` — classification pending.
- A-R06: `/cities` — classification pending.
- A-R07: `/cities/new` — classification pending.
- A-R08: `/conversation-reports` — classification pending.
- A-R09: `/login` — classification pending.
- A-R10: `/notifications` — classification pending.
- A-R11: `/providers` — classification pending.
- A-R12: `/providers/:id` — classification pending.
- A-R13: `/providers/applications` — classification pending.
- A-R14: `/providers/applications/:id` — classification pending.
- A-R15: `/providers/new` — classification pending.
- A-R16: `/reference-catalogs` — classification pending.
- A-R17: `/reports` — classification pending.
- A-R18: `/reviews` — classification pending.
- A-R19: `/services` — classification pending.
- A-R20: `/services/new` — classification pending.
- A-R21: `/users` — classification pending.
- A-R22: `/users/:id` — classification pending.

## Public and native surfaces

| السطح | المصدر/العقد | لماذا يدخل الفحص؟ |
| --- | --- | --- |
| صفحة الدعوة | deploy/public-site/invite.html + invite.js + invite.css | مدخل الرحلة بين browser والحساب والخطة |
| الخصوصية | deploy/public-site/privacy.html | ما يقال عن بيانات الناس مقارنة بالسلوك |
| الدعم | deploy/public-site/support.html | أين يذهب الشخص إذا لم يستطع الإكمال؟ |
| App Links/assetlinks | Android manifest/build config + deploy/staging/public-site/build.mjs | package/signing/host والـfallback ومسار الدعوة |
| Android permissions/notification entry | Native config + mobile client | رفض الإذن، foreground/background/killed، رابط التنبيه |
| OTP | auth API → OpenWA المستقلة | delivery/verification/failure؛ لا fake success |
| Push | backend registration/send → Firebase Staging → test device | وصول حقيقي وعزل الحساب/context |
| Media | signed upload/read contracts + consumers | حفظ/عرض/denied/expiry وخصوصية الملف |
| Offline/session | SQLite/cache/queue + consumer screens | stale/pending/recovery وسحب الحقوق وتغير الحساب |

هذه أسطح مرتبطة بالمنتج وليست تفويضًا لتغيير DNS/Traefik أو نشر أو إعادة تهيئة integrations.

## حالات لا يجوز إسقاطها

| مجموعة | الحالات المرشحة | قاعدة |
| --- | --- | --- |
| بيانات | no data / valid data / partial / stale / error | empty ليست خطأ مخفيًا |
| اتصال | online / offline cached / no cache / timeout / reconnect | pending ليستserver success |
| سلطة | allowed / view-only / denied / revoked / wrong context | permission ليستاسمrole |
| انتقال | first entry / back / repeated link / cold start / resume | حفظ وجهة الرحلة والسياق |
| عمليات | validation / success / failure / duplicate / retry / conflict | تحقق أثر الطرف الآخر |
| UI | RTL / long text / actual font scale / keyboard / scroll | كل زر لازم قابل للوصول |
| أطراف | Groom / Bride / Contributor / Provider states / Admin RBAC | كل دور يحتاجرحلة لا tab فقط |

لا تضرب الحالات في كل عناصر النظام آليًا. تحدد applicability لكل سطح وسبب N/A، وتبقى الحالات المحجوبة BLOCKED ولا توصف بأنها PASS.

## قالب مراجعة المعنى

لكل كرت أو قسم أو زر:

1. ما حاجة الشخص التي يخدمها؟
2. لماذا يظهر له الآن؟ ولماذا في هذا المكان؟
3. هل قيمته/نصه/حالته صحيح؟ من أين أتى؟
4. من يراه ومن يعدله؟ ماذا إذا تغيرت الصلاحية؟
5. ماذا يفعل؟ هل يمكن إكماله؟ ما أثره وكيف يتأكد الشخص؟
6. من ينتظر الخطوة التالية؟ وهل شاهد نفس الحقيقة؟
7. ماذا يحدث عند الفشل أو غياب البيانات؟
8. هل يكرر عنصرًا آخر؟ وهل التكرار ضروري؟
9. هل نبقيه أم نصلحه أم نبسطه أم نقترح دمجه/إزالته/إضافة غيره؟ ولماذا؟
10. ما الدليل وما الذي لم نثبته؟

## شرط اكتمال الجرد لاحقًا

كل Feature/file/route من القوائم مربوط بعناصره أو مصنف alias/internal/dev مع دليل. وكل سطح مرئي ليس له route له ID مستقل. لا صف غير مصنف ولا finding بلا دليل. هذا شرط تغطية، وليس حكمًا بأن كل العناصر ناجحة.

