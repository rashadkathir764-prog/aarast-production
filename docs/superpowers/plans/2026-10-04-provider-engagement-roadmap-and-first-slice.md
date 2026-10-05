# Provider Engagement — Roadmap and First Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** تنظيم التعامل الحالي بين صاحب الخطة والمزود في مساحة واضحة، ثم تطويره بحزم مستقلة إلى عروض ذات نسخ واتفاقات وحجوزات ودفعات مسجلة وتقييم بعد تجربة فعلية.

**Architecture:** نحافظ على modular monolith ومالكي البيانات الحاليين. الحزمة A تعرض QuoteRequest/QuoteOffer/Conversation والتكلفة المصرح بها، دون جدول Engagement أو Backend route أو schema جديدة. الحزم B–G توسعات مشروطة بمواصفات واعتماد مستقلين؛ هذه الوثيقة لا تسمح بالقفز إليها.

**Tech Stack:** Flutter/Dart وProvider/go_router؛ NestJS/TypeScript، Prisma/PostgreSQL؛ React/Vite Admin؛ public ports وstrict architecture gates الحالية.

**Spec:** [2026-10-04-provider-engagement-product-design.md](../specs/2026-10-04-provider-engagement-product-design.md) — مسودة توصية غير معتمدة؛ source baseline `14eccb50c6b2e050b044c7b00ac38a7e64f5164b`.

## Global Constraints

- مهمة الآن: تقييم وخطة فقط. لا تنفيذ، commit، push، merge، deploy أو Git worktree creation.
- عند اعتماد التنفيذ، يحدد المستخدم قاعدة وفرع/worktree التنفيذ؛ لا يعمل Agent على main أو checkout الإغلاق المحفوظة.
- الدستور حاكم: owner واحد، Prisma في owner infrastructure، public ports، Finance pure، cycles/forwardRef/illegal globals صفر.
- لا baseline/ignore/exception جديدة، ولا إضعاف tests أو assertions لجعل السلوك الجديد يمر.
- «قبول العرض» في A لا ينشئ payment/schedule/task/deposit/booking؛ paid=0 invariant محفوظ.
- لا phone/budget leakage؛ live permissions وcontributor scope محفوظة. Groom/Bride ليستا تفويضًا مستقلًا عن membership.
- لا تعديل migrations الـ76. الحزم ذات schema تضيف migrations معتمدة وتثبتها في `backend/architecture/published-migrations.json`، مع بقاء sourceRevision وdigest للـ76 الأصلية كما هي.
- لا payment gateway أو settlements أو loans/AI/open chat أو public launch في هذه الخطة.
- لا لمس الخادم، Abdo، الموارد أو أي مشروع آخر. إعادة النشر وAPK الفعلية يحتاجان مهمة مصرحًا بها بعد اجتياز الحزم.
- لا وعود offline writes؛ الكتابة الحساسة تحتاج نجاحًا authoritative، والقراءة cached تذكر عمر البيانات.
- الحجز والعربون وshared financial claims توسعة غير معتمدة بعد؛ لا تغير PRODUCT/DECISIONS في مهمة التخطيط.

## Review Focus

1. تبديل الخطة/تسجيل الخروج أثناء fetch: تُرفض الاستجابة القديمة ولا يظهر تعامل الخطة السابقة — Task A1/A2/A3.
2. contributor يملك providers دون money: لا totals أو رابط مال قابل للوصول، ولا broadened scope — Task A1/A2.
3. العرض accepted وله تكلفة لكن لم يُدفع: تعرض «عرض مقبول»، ولا «حجز مؤكد» أو «عربون مستلم» — Task A1/A2/A3.
4. فشل أحد requests مع بقاء cache: لا يوصف القائمة الفارغة بأنها «لا تعاملات»، ولا يصبح فشل fetch فقدًا للعمل — Task A2/A3.
5. عدة requests لنفس plan/provider أو رفض أحدها: تبقى العلاقة وبقية الطلبات، ولا تتحول quote إلى conversation identity — Task A1/A2/A3.

## 1. خطة المشروع الكامل وترتيب الاعتماد

| الحزمة | الناتج المستقل | الاعتماد | ما يجب حسمه قبل خطة التنفيذ التفصيلية | Gate الإغلاق |
| --- | --- | --- | --- | --- |
| A | workspace للموجود + action inbox للمزود | الموافقة على هذه المسودة | أسماء صادقة؛ لا حجز ضمني؛ keep existing navigation contracts | focused Mobile/Backend + strict boundaries + API لا تتغير |
| B | structured revisions + immutable agreement/change request | A | snapshot، صلاحية النسخة، multiple agreements، إلغاء الاتفاق، legacy mapping | stale accept FAIL؛ acceptance/finance rollback؛ PostgreSQL race؛ لا duplicate cost |
| C | capabilities + availability + booking/external blocks | B | resource/slot/timezone/buffer/hold TTL/confirmation policy | DB capacity conflict؛ hold expiry vs confirmation؛ reschedule atomic؛ external overlap |
| D | receipt matching + balances + agreed payment reminders | B؛ C إذا الشرط booking deposit | payer acknowledgment، duplicate match، adjustments/refunds، private proof | provider cannot mutate ledger؛ one real payment counted once؛ disputed claim unpaid |
| E | completion/no-show/disputes + eligible reviews + notifications | B/C؛ D للمال المرتبط | أهلية المقيّم؛ no-show؛ عدم الرد؛ history/moderation | provider cannot suppress review؛ dedupe reminders؛ current rating atomicity |
| F | المقارنة وتجربة الطرفين المكتملة | A؛ B–E لكل status يعرض | مقارنة حسب الفئة؛ IA لا تخفي الطلبات القديمة؛ action priority | no fabricated availability/prices؛ profile change leaves agreements intact؛ RTL |
| G | إثبات تكامل DB ثم Release phone journeys | الحزم المعتمدة والمكتملة | بيانات اختبار مستقلة، candidate SHA، migration upgrade/backup | full tests/smokes + device acceptance مع SHA واحدة؛ main untouched |

لا تقدر مدة التنفيذ أو يدّعى اكتمال B–G قبل اعتماد مواصفات تلك الحزم وتقديرها.
التفصيل القابل للتنفيذ أدناه للحزمة A فقط، لتجنب اختراع models/DTOs لباقي
الحزم قبل حسم العقود. «Roadmap» لباقي النظام ليست إذن تنفيذ ولا بديلًا عن تلك الخطط.

## 2. خريطة ملفات الحزمة A ومسؤولياتها

| الملف | العملية لاحقًا | المسؤولية |
| --- | --- | --- |
| `mobile/lib/features/marketplace/models/provider_engagement_view.dart` | Create | read projection للطلبات المصرح بها؛ لا persistence أو booking state |
| `mobile/lib/features/marketplace/marketplace_api.dart` | Modify | تصدير model/screen العامة لمستهلك provider_portal |
| `mobile/lib/features/marketplace/screens/provider_engagement_screen.dart` | Create | شاشة تعامل customer/provider من الطلبات الحالية، التنقل للمحادثة والمال عبر composition callbacks |
| `mobile/lib/features/marketplace/screens/provider_marketplace_screen.dart` | Modify | مدخل طلبات/عروض مقبولة دون إزالة مسار الاكتشاف أو تغيير bottom navigation |
| `mobile/lib/features/marketplace/providers/marketplace_provider.quotes.dart` | Modify only if needed | refresh/error/context safety؛ reuse loadScopedQuoteRequests/loadQuoteRequest |
| `mobile/lib/features/provider_portal/screens/provider_requests_tab.dart` | Modify | فتح نفس workspace من الطلب المحدد |
| `mobile/lib/features/provider_portal/screens/provider_home_tab.dart` | Modify | إجراءات من current quote states؛ no booking/payment counters |
| `mobile/lib/features/provider_portal/providers/provider_dashboard_provider.dart` | Modify only if needed | selected request reload/permission denied handling؛ existing API مصدر الحقيقة |
| `mobile/lib/core/routing/app_router.marketplace.dart` | Modify | route composition للworkspace وتنقل chat/finance عبر public APIs |
| `mobile/lib/core/routing/app_router.provider_portal.dart` | Modify if needed | provider entry composition بنفس الـpublic screen |
| `mobile/test/features/marketplace/provider_engagement_view_test.dart` | Create | projection/permission/partition tests |
| `mobile/test/features/marketplace/provider_engagement_screen_test.dart` | Create | customer scope/failed fetch/stale response/real navigation |
| `mobile/test/features/marketplace/provider_action_inbox_test.dart` | Create | provider action logic/denied operations/no fictional jobs |
| `docs/frontend/MOBILE_ROUTES.md` | Modify only after approval | توثيق route الجديدة ومصفوفة السياقات؛ تحقق من المسار الحقيقي قبل التنفيذ |

`ProviderDashboardApi` موجود فعليًا في `mobile/lib/features/marketplace/data/marketplace_api.dart`؛
لا تنشئ نسخة API داخل provider_portal. Screen consumers يدخلون عبر
`marketplace_api.dart`، وchat/finance عبر feature public APIs/composition فقط.

## 3. عقد projection للحزمة A

الأسماء التالية **مقترحة** وتصبح عقد التنفيذ بعد اعتماد المسودة.

```dart
enum EngagementPerspective { customer, provider }

// Read model only; defined in provider_engagement_view.dart.
class ProviderEngagementView {
  final String providerId;
  final String? weddingPlanId;
  final List<QuoteRequest> visibleRequests;
  final List<QuoteRequest> pendingProviderRequests;
  final List<QuoteRequest> awaitingCustomerRequests;
  final List<QuoteRequest> acceptedRequests;
  final bool canOpenFinance;
}

ProviderEngagementView buildProviderEngagementView({
  required String providerId,
  required String? weddingPlanId,
  required EngagementPerspective perspective,
  required List<QuoteRequest> authorizedRequests,
  required bool canViewMoney,
});
```

- `authorizedRequests` تأتي من API المصرح بها أصلًا؛ projection لا يمنح صلاحية ولا يجلب requests إضافية.
- grouping by provider + exact plan. `weddingPlanId=null` account scope صريح، لا wildcard لكل الخطط.
- `pendingProviderRequests`: lifecycle=`PENDING_PROVIDER`؛ `awaitingCustomerRequests`: lifecycle=`RECEIVED` ومعه `pendingOffer != null`؛ `acceptedRequests`: lifecycle=`ACCEPTED` ومعه `acceptedOffer != null`. الحالات الأخرى تبقى في `visibleRequests` بلا action مصطنعة.
- ترتيب كل قائمة: `createdAt` ascending ثم `id` ascending؛ null dates في النهاية. لا Clock محلية جديدة بدل server lifecycle، و`pendingOffer` الحالية تستبعد expired.
- provider perspective: `canOpenFinance=false`. customer: true فقط إذا `canViewMoney` الحالية true ويوجد accepted request مع `costSuggestion.availableActions` تحتوي `VIEW_COST` وcostId غير فارغة؛ كل action يعيد التحقق للطلب المحدد.
- accepted list لا تعتمد على آخر PlanProviderLink وحده. العمل المقبول القديم يبقى ظاهرًا إذا API سمحت به.
- لا paidAmount/bookingState/depositState مصطنعة. Projection يعرض link/reference للتكلفة فقط عند السماح؛ Finance يقرأ بياناته بنفسه.
- constructor والحقول immutable؛ لا local mutation لتحويل quote إلى accepted قبل server confirmation.

## 4. مهام الحزمة A — RED → GREEN

### Task A0: اعتماد التصميم وسطح التغيير

**Files:** المسودة المرافقة وهذه الخطة فقط؛ approved docs لا تغير بعد.

**Interfaces:** Consumes: source baseline وR01–R20. Produces: approval صريح للحزمة A، وقائمة B–G المقبولة كمجال بحث لاحق فقط.

- [ ] راجع gap matrix وقواعد المال/الحجز/التقييم؛ اعتمد الحزمة A أو عدّل المسودة.
- [ ] قبل أي Git mutation، احصل على task تنفيذ مصرح بها تحدد isolated worktree/base؛ هذه المهمة لا تأذن بفرع/commit.
- [ ] تحقق `git rev-parse HEAD` و`git status --porcelain` في checkout التنفيذ؛ إذا تغير baseline أعد فقط قراءات interfaces المتأثرة.
- [ ] تثبت route الحالية في `mobile/lib/core/routing/app_router.marketplace.dart` واسم docs routes الفعلي؛ اختَر path تحت composition الحالية؛ لا deploy/upgrade/server touch.

### Task A1: projection واحدة، دون كيان DB مكرر

**Files:** Create model و`provider_engagement_view_test.dart`؛ Modify `marketplace_api.dart`.

**Interfaces:** Consumes: `QuoteRequest`, `QuoteOffer`, authoritative `lifecycleStatus`؛ Produces: `EngagementPerspective`, `ProviderEngagementView`, `buildProviderEngagementView(...)` وفق القسم 3.

- [ ] اكتب tests بأسماء `groups_exact_plan_provider_only`, `null_plan_is_account_not_wildcard`, `acceptance_is_not_booking_or_payment`, `expired_offer_is_not_actionable`, `contributor_sees_only_authorized_requests`, `provider_cannot_open_private_finance`, `one_rejected_request_does_not_hide_other_requests`.
- [ ] ثبّت assertions: plan-A/provider-P لا يضم plan-B/provider-P ولا plan-A/provider-Q؛ accepted=1 لا ينتج paid/booked fact؛ money=false لا يسمح link؛ expired offer خارج awaitingCustomerRequests.
- [ ] Run من mobile: `flutter test --no-pub test/features/marketplace/provider_engagement_view_test.dart`؛ Expected RED بسبب غياب projection الجديدة.
- [ ] نفّذ الدالة والحقول كما في القسم 3 وصدّرها عبر API؛ لا Prisma/schema/new Backend endpoint.
- [ ] أعد الأمر؛ Expected GREEN، ثم `node scripts/check-mobile-boundaries.mjs --strict` من root؛ Expected zero violations.
- [ ] Review diff لعدم foreign imports/private DTO leakage. Commit هذه المهمة فقط **إن كان Git work مصرحًا**؛ لا push/merge.

### Task A2: workspace صاحب الخطة من البيانات الحالية

**Files:** Create `provider_engagement_screen.dart`, `provider_engagement_screen_test.dart`؛ Modify marketplace screen/router وpublic export؛ quote provider فقط إذا أثبت test الحاجة.

**Interfaces:** Consumes: A1، existing `ProviderMarketplaceProvider.loadScopedQuoteRequests()` و`loadQuoteRequest(...)`. Produces: public `ProviderEngagementScreen` يستقبل view/loading/error/retry/open-quote/open-chat/open-cost callbacks؛ composition تقرر التنقل والحق الحقيقي.

Constructor المقترحة في `provider_engagement_screen.dart`:

```dart
const ProviderEngagementScreen({
  super.key,
  required ProviderEngagementView? view,
  required bool isLoading,
  required String? errorMessage,
  required VoidCallback onRetry,
  required ValueChanged<QuoteRequest> onOpenQuote,
  required ValueChanged<QuoteRequest> onOpenChat,
  required ValueChanged<QuoteRequest>? onOpenCost,
});
```

callbacks تستقبل quote نفسها لعدم تخمين conversationId غير الموجود في model.
`onOpenChat` تستخدم composition مسار quote-conversation الحالي، و`onOpenCost`
تعيد فحص availableActions/permission ثم Finance route العامة. null callback
تعني عدم وجود action، ولا زر disabled يوهم بحق ممنوع. controller/composition
تحمل مسؤوليّة fetch/context isolation؛ screen تعرض ولا تكتب.

- [ ] اكتب `shows_request_offer_and_accepted_cost_reference`, `does_not_label_accepted_offer_confirmed_booking`, `failed_refresh_is_not_empty_success`, `switch_plan_discards_late_response`, `money_permission_revocation_removes_cost_action`.
- [ ] Assertions: عنوان accepted «عرض مقبول»؛ لا «حجز مؤكد/عربون مستلم»؛ فشل API يظهر retry؛ delayed plan-A response بعد اختيار B لا تظهر؛ money=false يخفي finance action ولا يغير backend permission.
- [ ] Run: `flutter test --no-pub test/features/marketplace/provider_engagement_screen_test.dart`؛ Expected RED للscreen الجديدة.
- [ ] نفّذ عرض existing requests/offers والnavigation callbacks؛ scoped provider هو authority source. لا تنشئ conversation من مجرد تصفح، ولا local CostPayment.
- [ ] أعد الاختبار ثم existing `quote_request_success_flow_test.dart`, `marketplace_context_isolation_test.dart`, `quote_lifecycle_test.dart` من مجلد `test/features/marketplace/`؛ Expected GREEN.
- [ ] حدّث routes docs المعتمدة فقط لما اعتمد من routes، شغّل strict boundary ثم راجع RTL/error/loading. Commit مصرح لهذه المهمة فقط.

### Task A3: workspace المزود وقائمة إجراءات حقيقية

**Files:** Modify requests tab/home tab وrouter عند الحاجة؛ Create `provider_action_inbox_test.dart`؛ API/shared screen من A1/A2.

**Interfaces:** Consumes: A1/A2 و`ProviderDashboardProvider.quoteRequests/canUseProviderOperations/errorMessage`. Produces: نفس shared workspace، provider actions من lifecycle الحالية؛ existing five-tab portal يبقى صالحًا.

- [ ] اكتب `pending_request_opens_existing_reply_flow`, `responded_offer_is_waiting_for_customer`, `accepted_offer_has_no_deposit_or_booking_badge`, `suspended_provider_cannot_start_new_work`, `dashboard_partial_failure_is_not_zero_work`, `account_switch_clears_previous_provider_data`.
- [ ] Assertions: SENT/VIEWED يتطلب reply؛ RESPONDED pending يوضح waiting customer؛ ACCEPTED يعرض acceptance فقط؛ العمليات الجديدة مع SUSPENDED ممنوعة؛ failure مع cached items لا يزيلها بصمت.
- [ ] Run: `flutter test --no-pub test/features/marketplace/provider_action_inbox_test.dart`؛ Expected RED قبل تطوير action inbox.
- [ ] نفّذ actions من existing authorized data؛ لا calls لFinance الخاصة، لا job/calendar fake models، لا copying quote logic into provider_portal.
- [ ] Run new test + `provider_portal_chat_test.dart`, `provider_dashboard_resilience_test.dart`, `provider_marketplace_shell_navigation_regression_test.dart`؛ Expected GREEN.
- [ ] تأكد أن أماكن «الرئيسية/الطلبات/الخدمات/الرسائل/ملفي» الحالية لم تختف، وأن accepted requests لا تُعرض كحجوزات. Review + commit مصرح.

### Task A4: تثبيت الحزمة A واختبارها كرحلة واحدة

**Files:** new tests A1–A3، routes docs، هذه الخطة لتسجيل النتائج؛ لا Backend logic change.

**Interfaces:** Consumes: A1–A3. Produces: verified candidate للحزمة A، وقائمة نتائج فعلية؛ لا إعلان B–G مكتملة.

- [ ] نفّذ اختبارات A1–A3 ثم `flutter analyze` و`flutter test --no-pub`؛ Expected no new analysis errors/all tests PASS. لا تغير asserts القديمة؛ خلاف behavior يُراجع صراحة.
- [ ] Root: `node scripts/check-mobile-boundaries.mjs --strict` و`node --test scripts/check-mobile-boundaries.test.mjs`؛ Expected strict PASS.
- [ ] Backend: focused baseline command من section 9 في spec؛ Expected 36 existing tests PASS ما لم أضيفت tests مستقلة معتمدة.
- [ ] إذا توسع diff إلى Backend خطأً: توقف وحدد سبب التوسع؛ لا تمنح هذه الخطة ضمنًا تعديل API/schema. بعد اعتماد تغيير حقيقي شغّل `npm run check`, `npm run architecture`, `npm test` والفحوص المتأثرة.
- [ ] Docs: `node scripts/docs-sync.mjs --check`, `node scripts/docs-verify.mjs`, `git diff --check`؛ Expected exit0؛ سجّل warnings كما هي.
- [ ] تحقق أن changed files هي A فقط، ولا server/deploy/secrets/migrations. اسجل SHA بعد commit المصرح، ثم cleanliness. لا merge أو نشر من تلقاء النفس.
- [ ] اختبار هاتف لاحق مصرح: provider يرد → صاحب الخطة يرى العرض → قبول → التكلفة موجودة وغير مدفوعة → نفس المحادثة والأحداث للطرفين → contributor بدون money لا يرى المال → switch plan لا يسرب البيانات.

## 5. ملفات وعقود الحزم التالية — تُثبت في مواصفات مستقلة

هذه مناطق التغيير المتوقعة، **وليست قائمة إنشاء models محسومة**.

| حزمة | Existing files التي يجب البناء عليها | الاختبارات الحاسمة المطلوبة |
| --- | --- | --- |
| B | `backend/prisma/schema/marketplace.prisma`, `backend/src/provider-dashboard/dto/create-quote-offer.dto.ts`, `update-quote-offer.dto.ts`, `provider-dashboard.service.ts`, `backend/src/marketplace/quote-offer-acceptance.ts`, `backend/src/modules/marketplace/infrastructure/provider-dashboard.repository.ts`, `marketplace-quote-mutation.repository.ts`, `backend/src/modules/finance/public/finance.port.ts` إذا احتاج العقد فقط | revisions immutable؛ profile edit لا يغير snapshot؛ stale/expired revision conflict؛ concurrent accept/change/revoke leaves one accepted agreement/one cost؛ rollback across ports |
| C | `backend/prisma/schema/catalog.prisma`, `marketplace.prisma`, owner public contracts وowner infrastructure، `admin-web/src/features/catalog/CategoriesPage.tsx`, `admin-web/src/features/catalog/api.ts`, provider services/portal | two competing bookings؛ external block race؛ expire/confirm race؛ capacity/resource isolation؛ no booking for non-bookable؛ UTC/display zone؛ buffers boundaries |
| D | `backend/src/wedding-costs/wedding-costs.service.ts`, `backend/src/modules/finance/public/finance.port.ts`, Finance infrastructure، Marketplace infrastructure، `mobile/lib/features/finance/screens/cost_payment_screens.dart`, `cost_details_screen.dart` | claim alone leaves paid=0؛ confirm existing does not duplicate payment؛ wrong agreement/currency denied؛ contributor permissions؛ concurrent matching idempotent؛ cancellation retains ledger |
| E | `backend/src/marketplace/marketplace.service.ts`, `backend/src/modules/marketplace/infrastructure/provider-review-rating.repository.ts`, `backend/src/conversations/conversations.service.ts`, messaging lifecycle public port، notification public port، `admin-web/src/features/moderation/ReviewsPage.tsx`, `mobile/lib/features/marketplace/widgets/provider_details_sections.dart` | unauthorized reviewer denied؛ no-show review path؛ provider cannot block negative review؛ legacy unverified preserved؛ moderator conflicts؛ count/average concurrency؛ event/reminder dedupe |
| F | existing marketplace/details/results/providers، `provider_home_tab.dart`, `provider_requests_tab.dart`, shared workspace، provider models/public APIs | max3 comparable same-category candidates؛ unknown price/availability truthful؛ no hidden budget sharing؛ expired/stale offer acceptance forbidden؛ action list RTL 320px |
| G | approved new integration tests في isolated smoke harness، current contract/docs، candidate packaging pipeline existing | empty replay and upgrade from76 both PASS؛ second deploy no-op؛ schema parity؛ full role journeys/real Push/OTP/App Links/private media/offline interruption |

كل خطة لاحقة يجب أن تحدد أسماء models/functions/DTOs والـroutes والأخطاء
والـmigrations والملكية والlock order بعد اعتماد spec؛ لا يختارها المنفّذ
ضمنًا من هذه القائمة. اختبار RED قبل التعديل، GREEN بعده، وPostgreSQL proof
حقيقي للعمليات المتزامنة. لا ننقل source-harness PASS إلى DB PASS.

## 6. بوابات الحزم B–G

- Backend touched: `npm run check`, `npm run architecture`, `npm run build`, `npm test`.
- Relevant isolated smoke commands: `npm run smoke:phase2-quote-concurrency`, `npm run smoke:phase2-provider-rating-concurrency`, `npm run smoke:phase2-provider-dashboard-concurrency`, `npm run smoke:financial-ledger-concurrency`, `npm run smoke:conversation-unification`؛ تثبت أسماء package scripts قبل التشغيل.
- Closeout: `npm run smoke:all` باستخدام managed isolated fixtures فقط؛ لا أي database قائمة.
- Schema: generate/validate ثم replay 76+approved additions وupgrade من baseline76؛ schema equivalence وmigrate status وsecond deploy no-op. لا db push/no mark-resolved/no historical edit.
- Mobile: strict boundaries/analyze/tests، وعند G Release signing/config/App Links/device proof.
- Admin عند تغييره: `npm run architecture`, `npm run test:architecture`, `npm run typecheck`, `npm test -- --run`, `npm run build` بالإعداد المطلوب.
- Root docs checks و`git diff --check` بعد كل حزمة. تغير model counts في gates يُراجع وفق قانونها وnegative proof، ولا يخفف scanner.
- أي deploy لاحق مهمة منفصلة مصرح بها؛ same-server safety/existing-resource protection لا يستنتجان من خطة منتج.

## 7. السيناريو النهائي المطلوب بعد الحزم المعتمدة

اختبر خطتين منفصلتين ومزودين، أحدهما حجزي والآخر non-bookable، مع owner وBride
member وContributor محدود وProvider وAdmin. جرّب request/revise/stale accept/
accept/repeat، competition على نفس resource، external block، تسجيل دفع ومطابقة
وdispute، change/cancel/no-show/complete/review، suspension/revocation، file
privacy، notification failure، offline/reconnect وتبديل الخطة. لا تتسرب حقوق
الخطة A إلى B ولا يرى المزود ميزانية الخطة. يسجل التقرير لكل خطوة actor،
input، expected، observed، SHA وبيئة الاختبار؛ النجاح الشامل يتطلب الهاتف.

## 8. مراجعة ذاتية وحالة التسليم

- R01–R20 مرتبطة بالحزم أعلاه؛ قواعد المال والحجز والتقييم حسمت كتوصيات للمراجعة.
- الحزمة A تتجنب تعديل النطاق الحالي. B–G مؤجلة حتى specs مستقلة معتمدة؛ لا تدعي هذه الوثيقة تفاصيل implementation غير محسومة.
- projection types المستهلكة في A2/A3 معرفة في A1؛ الشاشات/routers تستعمل public exports/composition.
- Review Focus الخمسة لها RED tests محددة؛ لا placeholders على هيئة «اختبر edge cases» داخل A.
- الخطة لم تُنفذ. الاختبارات السابقة للموجود هي 36 Backend و21 Mobile فقط، كما في spec.
- أسلوب التنفيذ الموصى به عند الاعتماد: `superpowers:executing-plans` بحزمة واحدة كل مرة؛ independent review للمسارات الحساسة إذا فوضه المستخدم. لا agents أو Git work من مهمة التخطيط نفسها.

**نقطة البدء المناسبة: اعتماد الحزمة A أولًا؛ ونطاق B/C/D/E يراجع كمواصفات
منتج جديدة. الهدف النهائي محفوظ، والبداية تمنع تكرار النظام أو توسيع الصلاحيات.**
