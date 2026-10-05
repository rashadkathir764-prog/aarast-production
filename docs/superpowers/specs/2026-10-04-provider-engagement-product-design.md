# Aarast — نظام التعامل مع المزود: تقييم وتصميم مقترح

Snapshot date: 2026-10-04

**الحالة: مسودة للمراجعة — ليست قرار نطاق معتمدًا ولا إذن تنفيذ.**

المصدر المفحوص: `14eccb50c6b2e050b044c7b00ac38a7e64f5164b`، الفرع
`staging/integration-decoupling-20261002`. كانت worktree نظيفة قبل هذه الوثائق.
الفحص محلي؛ لم يُفحص الخادم أو الهاتف في هذه المهمة.

## 1. الهدف الذي فهمناه

تمكين صاحب خطة العرس والمزود من متابعة التعامل نفسه: الطلب، العرض، ما قُبل،
الموعد، التنفيذ، الدفعات المتعلقة به، والمحادثة والتقييم. كل طرف يرى التفاصيل
المصرح بها والخطوة المطلوبة منه. تبقى خطة العرس وخصوصيتها مركز المنتج.

الحجز والتعاملات المالية المشتركة توسعة مقترحة. الوثائق المعتمدة الحالية
تستبعد confirmed bookings وdeposits. هذا الاختلاف ليس عيبًا في إغلاق المعمار
ولا إثباتًا أن مهمة سابقة أخفقت. لا تُعدّل PRODUCT أو DECISIONS حتى اعتماد
التوسعة ومواصفتها التنفيذية.

## 2. المصدر وحدود الإثبات

- [النطاق الحالي](../../project/PRODUCT.md): قبول العرض ينشئ تكلفة تبدأ بدون دفع؛ لا ينشئ حجزًا أو دفعة أو جدولًا.
- [القرارات](../../project/DECISIONS.md): السطران 194 و201 يثبتان قصد الربط المالي وتسلسل القرار؛ السطور 293–295 تستبعد الحجز والعربون الحاليين.
- [عقد API](../../backend/API_CONTRACT.md): quote-scoped conversations، الصلاحيات، المالية، التقييمات والإدارة.
- [الدستور](../../../ARCHITECTURE_CONSTITUTION.md) و[سجل الملكية](../../../backend/architecture/ownership-registry.json).
- [Schema المزودين](../../../backend/prisma/schema/marketplace.prisma): QuoteRequest، QuoteOffer، PlanProviderLink، ProviderReview، ProviderService، ProviderPackage.
- [Schema المحادثة](../../../backend/prisma/schema/messaging.prisma): Conversation وأحداث العروض؛ لا هوية محادثة جديدة لكل عرض.
- [قبول العرض](../../../backend/src/marketplace/quote-offer-acceptance.ts): reauthorization، عملة الخطة، انتهاء العرض، Finance port والتكلفة المرتبطة.
- [عمليات المزود](../../../backend/src/provider-dashboard/provider-dashboard.service.ts): منع العرض الثاني للطلب؛ تعديل العرض المعلّق فقط.
- [إنشاء التقييم](../../../backend/src/marketplace/marketplace.service.ts): منع self-review والتكرار؛ لا تحقق من اتفاق مكتمل.
- [نموذج طلب الهاتف](../../../mobile/lib/features/marketplace/screens/quote_request_screen.dart): تعبئة التاريخ والموقع والمدينة من الخطة، budget intent، مسودة scoped.
- [بوابة المزود](../../../mobile/lib/features/provider_portal/screens/provider_portal_screen.dart) و[التنقل](../../../mobile/lib/features/provider_portal/widgets/provider_portal_bottom_nav.dart).

الأرقام والخصائص أدناه مستندة إلى source والاختبارات المحلية المحددة. لا
يعني وجود اختبار mock إثبات سلامة PostgreSQL أو اختبار هاتف. لا يوصف غياب
ميزة مقترحة بأنه BUG ما لم يخالف مطلبًا معتمدًا قابلًا لإعادة الإنتاج.

## 3. Gap Matrix من الموجود إلى المطلوب

| ID | المطلب المقترح | الموجود فعليًا | التصنيف والقرار المناسب | الحزمة |
| --- | --- | --- | --- | --- |
| R01 | اكتشاف مناسب للخطة | city/category/search/featured/pagination؛ budget-match على خدمات؛ ليست availability | نبني على الموجود؛ لا ندعي أن ترتيب budget هو توصية ذكية أو توفر مؤكد | A ثم F |
| R02 | مقارنة ثلاثة مزودين حسب نوع الخدمة | لا عقد مقارنة أو بيانات حجز في المسار المفحوص | إضافة مقارنة ضمن الفئة بالبيانات الموجودة أولًا؛ معلومات ناقصة تعرض «غير محدد» | F |
| R03 | تعبئة الطلب من خطة العرس | تاريخ/موقع/مدينة وbudget intent موجودة؛ guestCount حقل إدخال | نحافظ على التعبئة وعرض سياق الطلب؛ سياسة مشاركة التفاصيل الاختيارية تحسم في F، ولا نخترع عدد ضيوف موثوقًا | A ثم F |
| R04 | عروض structured ونسخ غير قابلة للمحو | عنوان/رسالة/مبلغ/عملة/صلاحية؛ عرض واحد فعليًا لكل طلب؛ تعديل pending | توسيع مقترح: revisions للشروط والخدمة، قبول نسخة بعينها | B |
| R05 | اتفاق محفوظ مستقل عن profile | العرض المقبول لا يقبل تعديلًا؛ لا agreement snapshot كامل | نحتفظ بالحماية؛ نضيف snapshot واتفاقًا بعد اعتماد B | B |
| R06 | مساحة تعامل واحدة | محادثة plan/provider أو account/provider، طلبات وأحداث متكررة في timeline | projection للموجود أولًا؛ لا نضيف ProviderEngagement table لمجرد اسم المفهوم | A |
| R07 | أكثر من عمل مع نفس المزود | PlanProviderLink unique(plan,provider)، QuoteRequest متعددة | الرابط يظل grouping؛ اتفاق مستقل لكل قبول عند إضافة B؛ لا نخزن كل التاريخ في آخر link | B |
| R08 | تكلفة من قبول العرض دون دفع وهمي | موجودة عبر transaction وFinance port، paid=0 | نحافظ عليها وعلى idempotency والصلاحيات؛ لا نكرر ledger | A ثم B |
| R09 | تقويم وتوفر وحجز داخلي/خارجي | لا models للتوفر/حجز المورد في schema المفحوصة | توسعة منتج صريحة، تسبقها قواعد السعة والتعارض | C |
| R10 | قدرات مختلفة للفئات | categories/services/packages/priceUnit؛ لا capability profile حجزي | profiles محدودة ومختبرة؛ لا rules engine أو admin toggles حرة | C |
| R11 | عربون ومبالغ مستلمة ومتفق عليها | CostPayment وPaymentSchedule يخصان مال صاحب الخطة؛ لا shared receipt workflow | تسجيل ومطابقة دفع خارج المنصة، دون بوابة دفع أو كتابة المزود في ledger الخاص | D |
| R12 | موعد وتذكيرات متكاملة | plan date/tasks/payment reminders موجودة؛ قبول العرض لا ينشئها | ربط بعد العقد المعتمد؛ لا إنشاء تكلفة/تذكير مرتين | E |
| R13 | التغيير والإلغاء وعدم الحضور | quote reject/cancel/expiry؛ ليست service cancellation أو agreement amendment | نضيف مسارات التعثر مع الاتفاق والحجز؛ لا حذف التاريخ أو تسوية مالية افتراضية | B/C/D |
| R14 | تقييم بعد تعامل مثبت | تقييم user/provider واحد؛ moderation وتحديث rating ذري | سياسة أهلية جديدة؛ لا يعطّل المزود النقد برفض completion؛ القديم لا يتحول إلى verified تلقائيًا | E |
| R15 | home المزود تجيب «ماذا أفعل؟» | summary/latest requests/quick actions وlifecycle notice | تطوير action inbox من البيانات الحالية؛ حجوزات/دفعات تظهر بعد وجودها فقط | A ثم F |
| R16 | workspace المزود للعمل | الطلبات والخدمات والملف والرسائل موجودة؛ لا booked-job workspace | منظور لنفس الطلب/الاتفاق؛ لا نكرر marketplace أو chat أو finance داخله | A ثم F |
| R17 | الفصل بين أدوار وصلاحيات الخطة | قبول العرض يعيد التحقق من providers + money؛ contributor own-scope | الحقوق تتبع membership الفعلية لا لقب Groom/Bride؛ لا توسعة contributor ضمنًا | جميع الحزم |
| R18 | ملفات ومحادثة آمنة | quote-started chat، signed private media، block/report/revocation | نحافظ عليها؛ private attachment لا يتحول إلى public provider image | جميع الحزم |
| R19 | تعليق المزود لا يمحو حقوق الاتفاق القديم | lifecycle safeguards موجودة لعمليات quotes؛ لا اتفاقات جديدة بعد | القراءة/التواصل المحدود للعمل القديم يحتاج عقدًا صريحًا؛ suspension يمنع عملًا جديدًا ولا يخفي السجل | B/E |
| R20 | حقيقة بعد فقد الشبكة/تبديل الخطة | session/context isolation واختبارات reliability موجودة | cached view مع وقت تحديث؛ لا قبول/حجز/دفع offline نجاحًا محليًا مزيفًا | جميع الحزم |

## 4. تقييم تصور المستخدم

### ما نعتمده اتجاهًا مقترحًا

- علاقة مشتركة داخل الخطة، عروض واضحة، نسخة ثابتة عند القبول، أحداث في المحادثة.
- اكتشف / طلباتي / اتفاقاتي وجهة جيدة بعد وجود اتفاق حقيقي؛ قبل ذلك الاسم الصادق «العروض المقبولة».
- home مزود قائمة إجراءات، تقويم فقط للفئات التي تحتاجه، حجز خارجي يحمي التوفر.
- تقييم مرتبط بتجربة فعلية وصلاحيات providers منفصلة عن money.

### ما نصححه قبل البناء

- قبول العرض لا يضمن حجزًا. وجود مبلغ عربون لا يثبت دفعه. تأكيد المزود الاستلام لا يبيح له تعديل مال الخطة.
- دورة العلاقة ليست enum واحدة: العرض والاتفاق والحجز والتنفيذ والدفعات حالات مستقلة.
- حسابات العريس والعروسة لا تمنح صلاحيات متساوية تلقائيًا؛ owner/shared-member rules هي الحقيقة.
- لا نحذف quote/service/package/chat الحالية لإدخال مفهوم جديد يحمل البيانات نفسها.
- لا يحجب المزود التقييم بامتناعه عن إعلان التنفيذ، ولا يفتح قبول العرض وحده تقييم جودة خدمة لم تُقدّم.
- budget واحد لا يُشارك تلقائيًا مع جميع المزودين؛ إرسال الطلب له معاينة المعلومات المرسلة.
- لا يسمى المزود «متاحًا» اعتمادًا على تقويم غير مكتمل. الحالة «اسأل عن التوفر» عند غياب دليل موثوق.

## 5. الخيارات والتوصية

| الخيار | المكسب | الكلفة/المشكلة |
| --- | --- | --- |
| تطوير النظام الموجود على حزم مكتملة | يحفظ الكود والمال والصلاحيات؛ كل حزمة قابلة للاختبار | يحتاج انضباطًا في إظهار ما اكتمل وما لم يكتمل |
| بناء CRM/Booking مستقل ثم ربطه | استقلال واجهة المزود | خطر ازدواج الطلبات والمال والمحادثة؛ كلفة مزامنة غير لازمة الآن |
| بناء كامل التصور دفعة واحدة | اتساع سريع ظاهري | أخطاء التزامن والإلغاء والخصوصية يصعب عزلها، ومواصفة ضخمة غير محسومة |

**التوصية: الخيار الأول.** مساحة التعامل تبدأ كعرض موحد للموجود. نضيف
عروضًا ذات نسخ واتفاقات، ثم حجوزات موارد، ثم مطابقة الدفعات، ثم التنفيذ
والتقييم. لا subsystem معماري جديد أو reopening لـR0–R20.

## 6. القواعد المقترحة للمواصفات اللاحقة

هذه defaults موصى بها وليست حقائق حالية؛ تعتمد قبل حزمة التنفيذ المعنية.

### B — العرض والاتفاق

- QuoteRequest وConversation الحالية تبقيان الهوية؛ لا محادثة جديدة لكل revision.
- draft قابل للتعديل؛ النسخة المرسلة immutable. revision جديدة بدل تعديل ما رآه العميل.
- acceptance تستهدف revision ID/version محددة. stale/expired/replaced revision تعطي conflict ولا تنشئ تكلفة.
- snapshot: عنوان الخدمة، inclusions/exclusions، المبلغ كـdecimal string، العملة، الموعد/المورد إن عُرف، الشروط وسياسة الإلغاء، جدول الاستحقاق المقترح، parties ووقت القبول.
- agreement واحد لكل قبول، ويمكن وجود أكثر من agreement في plan/provider relationship. PlanProviderLink لا يتحول إلى archive للاتفاقات كلها.
- نقبل فقط عملة الخطة كما يفعل المصدر؛ لا conversion تلقائي.
- قبول اتفاق غير حجزي لا يولد reservation. قبول اتفاق حجزي لا يضمن confirmation قبل توفر المورد وشروط التأكيد.
- تعديل اتفاق مقبول يحتاج change request يقبله الطرف الآخر. expiry/reject يحفظان الاتفاق السابق.
- اتفاقات legacy لا تُختلق من reviews/رسائل؛ العرض المقبول القديم يحفظ كسجل legacy بما يمكن إثباته فقط.

### C — الحجز والقدرات

- resource صريح: قاعة/فريق/مقعد أو سعة موارد، مع فترة زمنية وtimezone مثبتة في المواصفة.
- capability presets: `appointment` أو `capacity` أو `non-bookable`؛ الموقع ونطاق الخدمة ووحدة السعر لا تستنتج من الاسم.
- first booking slice: مورد واحد بسعة 1 وحجز بفترة كاملة؛ فريق ثانٍ يمثل موردًا ثانيًا. لا نعد بمخزون delivery/e-commerce.
- interval conflict يكون على `[start,end)`؛ نهاية حجز عند بداية التالي لا تتعارض إلا إذا buffer مثبت في preset.
- holds لها expiresAt محددة ومشتركة server-side؛ انقضاؤها يحرر السعة مرة واحدة، ويُختبر بالتزامن مع confirmation.
- external block لا يحتاج هاتف/هوية عميل خارجي. يقيد المورد ولا يدخل ميزانية العرس.
- optional deposit policy؛ يمكن تأكيد booking بلا عربون وفق شروط الاتفاق. لا يجب أن يصبح العربون شرطًا لجميع الفئات.
- نقل الموعد ذري: لا نفقد الحجز القديم ثم نفشل في إنشاء الجديد؛ pending request لا يدعي أن الموعد الجديد محجوز ما لم يوجد hold.

### D — الدفع خارج المنصة

- لا gateway، ولا تحصيل، ولا حفظ أموال، ولا commissions أو settlements.
- owner المالي يظل Finance. المزود يسجل receipt declaration في سياق التعامل، لا CostPayment باسم العميل.
- إذا سجل العميل دفعًا موجودًا، acknowledgment من المزود يربط الدفعة ولا ينشئ أخرى.
- إذا بدأ المزود claim، يطابقه صاحب صلاحية المال مع دفعة موجودة أو يسجل الدفع الفعلي بإجراء صريح.
- rejection/dispute لا يمحو دفعًا فعليًا سجله العميل. تراجع acknowledgment لا يخصم ledger تلقائيًا.
- amount/currency/method/date/proof مرجعية، وidempotency لكل command. paid totals لا تعتمد على claimed-only entries.
- cancellation لا يحذف cost/payment. أي adjustment/refund يحتاج سياسة ledger مكتوبة؛ الحزمة D لا تبدأ قبل حسمها.
- المزود يرى المال الخاص باتفاقه فقط؛ لا plan budget أو مصروفات مزود آخر.

### E — التنفيذ والتقييم

- طرف يعلن completion والطرف الآخر يؤكد أو يعترض؛ تأخر الطرف الآخر لا يؤدي إلى fake completion.
- review eligibility بعد تجربة مثبتة؛ no-show/cancellation-after-agreement مسار شكوى/تقييم مؤهل حسب السياسة، لا ينتظر completion من المزود.
- first eligibility slice يحتفظ بunique(user,provider) الحالية. ربط كل review بمرجع تعامل قابل للإثبات؛ تقييمات متعددة لكل اتفاق ليست ضمن هذه الحزمة.
- تثبيت هوية المقيّم المخول في الخطة؛ لا تقييمات مضاعفة بنفس التجربة بهدف رفع المتوسط.
- legacy reviews تبقى كما هي وتظهر بلا شارة verified؛ لا حذف أو منح أهلية بأثر رجعي بلا دليل.
- moderation مستقلة؛ الحذف/الإخفاء يحدث حسب السلطة والسياسة، والrating cache يبقى دقيقًا تحت concurrency.

## 7. صلاحيات ومن يملك ماذا

| البيانات/الفعل | المالك الحالي أو المقترح | قاعدة الوصول |
| --- | --- | --- |
| Provider / offers / agreements / booking resources | Marketplace | صاحب المزود أو صاحب الخطة المصرح له؛ public DTO محدود |
| category preset | Catalog | backoffice يدير عبر public contract؛ التغيير لا يغير snapshot قائمًا |
| CostPayment / cost / payment reminder | Finance | plan money permissions؛ المزود لا يقرأ جداول Finance |
| receipt declaration / completion evidence | Marketplace | parties الفعلية؛ Finance يطابق الفعل المالي عبر port عند الحاجة |
| conversation/message/event | Messaging | current membership؛ أحداث من مالك الفعل بمعرّف dedupe |
| shared authority / actor scope | Collaboration | recheck داخل transaction؛ contributor scope لا يوسع ضمنًا |
| push/reminder | Notifications | after durable mutation؛ delivery failure لا يلغي الاتفاق |
| attachment | Media | private scope للتعامل؛ لا public bucket لمستند مالي |
| audit/moderation | Backoffice | عبر public ports؛ لا foreign Prisma |

ملكية الجداول الجديدة مقترحة للمراجعة قبل schema، وليست إذنًا لاختراع جداول.
Read models لا تنسخ foreign persistence. كل Prisma داخل owner infrastructure.

## 8. تعريف النجاح والمراحل

### حزمة A: الموجود يصبح مفهومًا

العميل والمزود يفتحان تعاملًا فعليًا فيه الطلبات والعرض الحالي والمقبول ورابط
المحادثة والتكلفة المصرح بها. لا لغة حجز أو استلام مبلغ غير مثبت. لا schema
ولا routes Backend جديدة. الحالات القديمة والخصوصية ثابتة.

### الحزم التالية

- B: نسخة عرض → قبول ثابت → اتفاق؛ concurrency وchange/cancel policy معها.
- C: capability preset → resource → availability/hold/booking/external block.
- D: سجل دفع فعلي → receipt matching → balances وتذكيرات صادقة.
- E: التنفيذ والتعثر → أهلية تقييم → moderation وإشعارات.
- F: مقارنة فئوية، action inbox، customer/provider workspaces مكتملة.
- G: replay/upgrade على DB معزولة ثم Release APK وتعدد الأدوار على الهاتف.

تكتب مواصفة تنفيذية مستقلة لكل حزمة قبل تنفيذها. لا تبدأ حزمة حتى بوابة
الحزمة السابقة المطلوبة لها خضراء. لا «كل شيء جاهز» من unit tests وحدها.

## 9. الأدلة المنفذة في مهمة التخطيط

- Backend: `node --test -r ts-node/register test/quote-stability.test.ts test/quote-lifecycle.test.ts test/quote-lifecycle-lock-order.test.ts test/provider-rating-atomicity.test.ts test/contributor-money-marketplace-scope.test.ts test/provider-chat-logic.test.ts test/provider-dashboard-mutation-atomicity.test.ts` — **36 PASS / 0 FAIL / 0 SKIP**.
- Mobile: `flutter test test/features/marketplace/quote_lifecycle_test.dart test/features/marketplace/quote_stability_test.dart test/features/marketplace/quote_request_success_flow_test.dart test/features/marketplace/provider_portal_chat_test.dart --reporter compact` — **21 PASS**.
- Flutter أظهر تنبيهات تحديث dependencies وتحذيرات desktop default plugins؛ لم تُعدّل dependencies لمعالجة هذه التحذيرات. النجاح هنا للاختبارات المحددة فقط.
- Docs: `node scripts/docs-sync.mjs --check` — PASS، drift=0/errors=0؛ `node scripts/docs-verify.mjs` — PASS، errors=0 مع 17 تحذير freshness في وثائق موجودة سابقًا. `git diff --check` — PASS؛ فحص الملفين الجديدين وجد trailing whitespace=0.
- لم تُشغّل DB integration أو architecture كاملة أو Admin suite أو device acceptance في هذا التقييم. أوامر الحماية موجودة في خطة التنفيذ وتنفذ عند لمس مجالها.

## 10. حدود هذه المهمة

كتابة وثيقتين Markdown جديدتين فقط. لا تعديل وثائق معتمدة، كود، schema،
migrations، dependencies، deployment أو Git state. لا SSH، ولا Docker، ولا
secrets، ولا لمس Abdo أو الموارد أو أي مشروع على الخادم.

الخطة المرافقة: [خريطة الحزم وخطة الحزمة الأولى](../plans/2026-10-04-provider-engagement-roadmap-and-first-slice.md).
