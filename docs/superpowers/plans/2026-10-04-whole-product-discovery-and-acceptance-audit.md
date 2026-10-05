# Aarast Whole-Product Discovery and Acceptance Audit Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to execute this read-only audit task-by-task. Use superpowers:subagent-driven-development only if the user explicitly selects delegation. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **هذه خطة تنفيذ فحص، وليست خطة تنفيذ ميزات أو تصريح إصلاح أو نشر.**

**Goal:** فهم أعرست بالكامل من منظور كل شخص، وربط كل شاشة وقسم وكرت وخطوة ومسار بحاجته وحقيقته وصلاحيته، ثم إصدار قرارات مبررة عن الصحيح والخاطئ والناقص والزائد وأولوية العمل.

**Architecture:** الحفاظ على المعمار الحالي والدستور. نتتبع UI → state/repository → API → owner public contract فقط لفهم الرحلة؛ لا نعيد فتح مهمة Modular Monolith.

**Tech Stack:** Flutter/Android Release، SQLite/offline queue، NestJS/Prisma/PostgreSQL، React Admin، public invite site، OpenWA OTP وFirebase Push كتكاملات قبول.

**Spec:** [Whole-product audit design](../specs/2026-10-04-whole-product-audit-design.md).

## 1. Source and current evidence

- Checkout: `C:/Users/Rashad/.codex/worktrees/staging-integration-decoupling-20261002/aarast-final-closeout`.
- Branch: `staging/integration-decoupling-20261002`.
- Source HEAD: `14eccb50c6b2e050b044c7b00ac38a7e64f5164b`.
- التخطيط يجري هنا؛ checkout القديم عند `342422c6` ليس مصدر الحكم الحالي.
- توجد مسودتا المزود غير ملتزمتين؛ تحفظان كما هما ولا تعدان scope معتمدًا.
- [جرد البداية](../../frontend/2026-10-04-whole-product-surface-inventory.md): 20 feature Mobile، و70 ملف screen source تشمل أجزاء، و64 مسارًا مستخرجًا، و18 صفحة Admin source و22 route. الأرقام ليست عدد شاشات تجربة المستخدم النهائي أو إثبات اكتمالها.
- سجل الهاتف المحلي السابق: `C:/Users/Rashad/AppData/Local/Aarast/Staging/DeviceAcceptance-20261004/`. يقيد بما شاهده فعلًا؛ لا يعمم على كل التطبيق.
- تثبيت Release وتجربة بعض الرحلات ثبتا سابقًا. ما بقي يتضمن بقية الأدوار، الرحلات المتصلة، Push فعليًا، والحالات السلبية. لا نعود لاعتبار التطبيق غير مثبت لمجرد أن القبول الشامل غير مكتمل.

## 2. Global Constraints

1. لا إصلاح أو feature أو schema/migration/config/deploy أو إعادة بناء/تثبيت APK في تنفيذ هذه الخطة.
2. لا branch/worktree/checkout/commit/push/reset أو أي تعديل Git؛ لا main.
3. لا إيقاف أو تعديل موارد الخادم. Abdo والموارد وأي مشروع آخر خارج الوصول والفحص.
4. لا أسماء domains أو environment تثبت وحدها أنها منشورة للعامة؛ نثبت هوية المصدر والبيئة الفعلية.
5. لا secrets أو OTP أو هواتف كاملة أو رسائل خاصة في Git أو التقرير.
6. لا إعادة استخدام Firebase/OpenWA قديمة، ولا OTP ثابتة أو تجاوز verification في Staging أو قبول الهاتف. الـfixtures القائمة في اختبارات development محلية معزولة لا تثبت OTP حقيقية ولا تسمح بتغيير عقد Staging.
7. لا تسجيل ميزة مقترحة كـmissing approved requirement. لا تنفيذ مبكر للحجز والعربون والتسويات أو open chat.
8. لا إعادة فحوص مثبتة إلا إذا تغير المصدر/العقد أو احتجنا حالة لم يغطها الإثبات السابق.
9. كل اختبار له مصدر وبيئة ونتيجة وحدود. لا mock = device، لا health = release identity.
10. أي اختبار كتابي لاحق يحدد الحساب والخطة والأثر والتفويض أولًا. لا حذف حساب أو مال أو ملفات مهمة لأجل اختبار.
11. المانع في دور لا يوقف قراءة بقية النظام؛ يسجل NOT PROVEN وتستكمل المهام المستقلة.
12. خطة المعالجة اللاحقة تحتاج موافقة على scope؛ هذه الخطة لا تحول ملاحظات الفحص تلقائيًا إلى إصلاحات.

## 3. Review Focus

- دلالة المال: تكلفة/مدفوع/متبقي/ميزانية/تذكير، دون نجاح وهمي أو ازدواج.
- عزل الخطط والحسابات والحقوق في API وUI وSQLite والإشعارات والروابط.
- «من ينتظر من؟» في الدعوة والطلب والعرض والاعتماد والمحادثة.
- أي زر معروض في حالة لا تستطيع إكماله، وأي كرت غير صحيح أو بلا خطوة نافعة.
- entry/back/resume والتسجيل من رابط الدعوة والمشاركة بدون فقد السياق.
- حالات empty/loading/error/partial/offline/pending/denied/revoked/expired/retry.
- RTL، النص الطويل، تكبير الخط، لوحة المفاتيح، الوصول للزر، touch targets والتباين بمعيار معلوم.
- المعايير المعتمدة: docs/frontend/DESIGN_SYSTEM.md (touch target48×48، semantic labels، focus، AA)؛ docs/qa/MOBILE_QA.md (كل سطح مال عند320px RTL وtext scale1.3). القياس الفعلي1.15 على الهاتف دليل إضافي ولا يستبدل1.3.
- no data ≠ zero، no permission ≠ empty، provider pending ≠ public active، local saved ≠ synced.
- علامات النجاح واختبارات الحراس ليست بديلًا عن الرحلات المتعددة الأطراف.

## 4. File and responsibility map

| مصدر القراءة | مسؤوليته في الفحص |
| --- | --- |
| docs/project/PRODUCT.md, SCOPE_AND_PHASES.md, DECISIONS.md, STATUS.md | القصد والنطاق والقرارات؛ STATUS ليس إثبات runtime |
| docs/backend/API_CONTRACT.md, DATABASE.md | العقود والمعاني والصلاحيات؛ تقارن بالمصدر |
| docs/frontend/MOBILE_ROUTES.md, ADMIN_ROUTES.md, OFFLINE_SQLITE.md | جرد أولي وقواعد التنقل والمزامنة؛ تدقق بالمصدر |
| mobile/lib/core/routing/, mobile/lib/features/, mobile/lib/shared/ | routes، guards، الحالات، الأقسام والعناصر، state والعمليات |
| mobile/lib/core/ مع مسارات التخزين/الشبكة المكتشفة فعليًا | الجلسات وSQLite والمزامنة والإشعارات والروابط؛ لا يفترض اسم الملف |
| backend/src/, backend/prisma/ | API الفعلية، authority، أثر العمليات والمعاملات؛ قراءة فقط |
| admin-web/src/App.tsx, admin-web/src/features/ | Admin routes وRBAC والقرارات وأثرها على الأطراف |
| deploy/public-site/, deploy/staging/public-site/ | صفحة الدعوة والـfallback وassetlinks والخصوصية والدعم |
| mobile/test/, backend/test/, backend/scripts/, admin-web/src/test/ | الاختبارات القائمة وما تثبته فعلًا؛ لا تضعفها |
| ARCHITECTURE_CONSTITUTION.md, ARCHITECTURE.md | قوانين محمية لا اقتراح إعادة تصميم |
| مسودتا provider-engagement بتاريخ2026-10-04 | طموح مقارن، لا scope تلقائي |
| الأدلة المحلية خارج Git | صور وسجل خطوات ونتائج حساسة؛ روابط محلية منقحة فقط |

**Expected change surface لهذه المهمة:** تصميم الفحص، هذه الخطة، جرد البداية؛ Markdown فقط. نواتج التنفيذ اللاحق أدناه تحدد مسبقًا، ولا تنشأ ملفات application أو deployment.

## 5. Artifacts and evidence protocol

تنفيذ الفحص ينتج مجلدًا توثيقيًا واحدًا مقترحًا:
`docs/qa/whole-product-audit-20261004/`. تحفظ لقطات وبيانات الهاتف الحساسة خارج Git في مجلد evidence مميز. لا تلتزم ملفات تلقائيًا.

| Artifact | المحتوى |
| --- | --- |
| 00-source-and-contract.md | مصدر/نسخة/بيئة، القصد المعتمد، الدور، شروط الاختبار والحقوق |
| 01-surface-register.md | جميع الأسطح والعناصر والحالات ومصدرها وcoverage |
| 02-journeys-and-handoffs.md | خطوات الأطراف وانتقالات الحالة والشروط والنتائج |
| 03-findings.md | فقط النتائج المبررة، وخطوات إعادة الإنتاج وحدود الدليل |
| 04-product-decisions-and-priorities.md | إبقاء/تبسيط/إصلاح/تأجيل/توسعة مقترحة، المفاضلات وخطة العلاج |
| 05-acceptance-receipt.md | ما فحص وما لم يفحص، النتائج والأوامر والتغطية والموانع |

**Surface row:** ID | actor/context | route/entry | screen/section/card/control | state | user job | data/formula/unit/freshness | visibility/authority | action/effect | next actor | failure/recovery | source symbol | test | runtime evidence | verdict.

**Journey row:** actor → entry → precondition → action → system effect → other actor sees → next step → failure/recovery → proof.

**Finding row:** ID | classification | approved requirement (if applicable) | expected/actual | reproduction | source | evidence level | impact | priority | smallest valid remedy | acceptance | dependencies | uncertainty.

**Evidence levels:** CONTRACT / SOURCE / LOCAL TEST / ISOLATED DB / DEPLOYED API / REAL DEVICE. تسجل عدة أدلة مستقلًا؛ لا تختزلها في PASS عام.

**Coverage states:** NOT STARTED / SOURCE REVIEWED / TESTED / DEVICE OBSERVED / BLOCKED / N/A WITH REASON. Coverage لا يعني النجاح: يمكن إكمال فحص عنصر ونتيجته FAIL.

## 6. Execution tasks

### Task 0 — تثبيت نقطة الحقيقة ونطاق الاختبار

**Consumes:** source HEAD، الأدلة السابقة، دستور المشروع.
**Produces:** 00-source-and-contract.md.

- [ ] شغّل من checkout المحددة: `git rev-parse --show-toplevel`، `git branch --show-current`، `git rev-parse HEAD`، `git status --short`؛ احفظ الحالة ولا تغيرها.
- [ ] اقرأ AGENTS والدستور والوثائق المعتمدة ذات الصلة؛ سجل القرارات المتعارضة بدل اختيار تفسير صامت.
- [ ] قارن SHA التطبيق المثبت ونسخة Backend بعلامة revision موثوقة إن كانت متاحة. health وحده لا يكفي. لا تعيد build.
- [ ] ميز التقرير السابق عن التنفيذ الحي: ما شاهده الوكيل، ما قاله المالك، وما تثبته الاختبارات.
- [ ] حدد حسابات وأدوار وخطط اختبار مسموحة. افحص الموجود دون عرض credentials؛ إذا غير موجود سجل prerequisite لا تخمن.
- [ ] قبل استخدام ADB اقرأ skill الكمبيوتر/الأدوات المناسبة والقواعد الفعلية؛ تفويض اختبار الهاتف لا يسمح بفتح بيانات التطبيقات الأخرى.
- [ ] ضع سجل العمليات الكتابية المطلوبة وسببها وآثارها. استبعد الحسابات/البيانات غير المؤكد أنها للاختبار.
- [ ] Acceptance: source معلوم، حدود كل دليل واضحة، ولا اختبار موجّه إلى مشروع آخر.

### Task 1 — فهم النظام كعمل كامل قبل الحكم على الواجهة

**Consumes:** PRODUCT / SCOPE / DECISIONS / API / DATABASE + source.
**Produces:** القسم الأول من02-journeys، وخريطة المتطلبات في00.

- [ ] لكل دور اكتب: لماذا يفتح أعرست؟ ما نجاحه؟ ما القرار الذي يحتاجه؟ وما الذي ليس من حقه؟
- [ ] ارسم دورة الخطة من أول دخول إلى يوم العرس ثم الإغلاق/المتابعة، اعتمادًا على الرحلات الموجودة فقط.
- [ ] ارسم انتقالات الدعوة والمساهمة وعرض السعر واعتماد المزود، مع الطرف التالي والمعلومة التي تصل إليه.
- [ ] تحقق من تعريف كل مصطلح مالي ومن قواعد قبول عرض والتقييم وحالة المزود. لا تتبنى تسمية الكرت كدليل.
- [ ] قارن مسودة علاقة المزود بالنطاق الحالي: EXISTING / PARTIAL / PROPOSED / CONFLICT / NOT PROVEN.
- [ ] سجل «ما ينبغي أن يراه هذا الشخص الآن» كفرضية UX معللة، لا finding قبل الفحص.
- [ ] Acceptance: يمكن شرح النظام بالعربية من منظور الأشخاص دون أسماء classes؛ كل التزام له مرجع.

### Task 2 — جرد كل سطح وعنصر ومنع إسقاط أي قسم

**Consumes:** جرد البداية، routers، صفحات وتبويبات وwidgets.
**Produces:** 01-surface-register.md.

- [ ] ابدأ ب20 feature و64 route Mobile و18 Admin page و22 route، ثم صححها من source. استخرج root/redirect/dev routes والـaliases والسياقات الداخلية.
- [ ] لا تعد64 شاشة: native docs scanner يستخرج strings وقد لا يمثل كل GoRoute؛ راجع البناء والـguards والـshell والـentry بدون route.
- [ ] افتح ملفات screen والـparts والـwidgets التابعة، وسجل جميع الأقسام والكروت والعدادات والنماذج والـsheets والـdialogs والقوائم والأزرار.
- [ ] تتبع العناصر reusable إلى مواضع استخدامها. لا تساو496 widget declarations ب496 كرتًا أو شاشة.
- [ ] أضف Admin layouts/sidebar/action menus/modals، وصفحات public invite/privacy/support، ومداخل OS permissions/App Links.
- [ ] لكل عنصر سجل الغرض والمصدر والصلاحية والحالة والفعل والطرف التالي. عنصر لا تعرف فائدته يبقى سؤالًا صريحًا.
- [ ] عين الحالات المنطبقة من loading/empty/populated/error/offline/pending/revoked وغيرها. لا تترك فراغًا؛ N/A يحتاج سببًا.
- [ ] Acceptance: كل ملف/route له تغطية أو سبب alias/dev/internal. وكل سطح متاح للمستخدم له عناصر وحالات مسجلة.

### Task 3 — الدخول والتسجيل والهوية والسياق

**Files to inspect:** auth، welcome_gateway، onboarding، account_contexts، shell، routing، session storage/API.

- [ ] تتبع زيارة أولى، guest-first، signup/login/OTP/reset-password/logout/session expiry والعودة بعد restart.
- [ ] افحص دخولًا من رابط دعوة قبل الحساب وبعده، wrong account، token expired، فتحًا مكررًا، واستكمال الخطوة المقصودة بعد auth.
- [ ] تحقق من اختيار مالك/مساهم/مزود وخطة نشطة: back/deep link/cold start لا ينقل إلى سياق آخر.
- [ ] راجع كل حقل وتلميح وخطأ وموافقة وتسمية: لماذا نطلبه الآن؟ هل validation ورسالة الخطأ متطابقان مع API؟
- [ ] افحص فشل OTP/network/rate limit؛ لا تدعي إرسالًا أو حفظًا من دون تأكيد العقد.
- [ ] تحقق من ذاكرة الجلسة والـcache عند logout وتغيير الحساب. لا تقرأ أو تعرض token.
- [ ] Acceptance: كل مدخل ينتهي إلى الوجهة الصحيحة أو فشل قابل للتعافي، مع عزل الحسابات. UNKNOWN لا يتحول PASS.

### Task 4 — الرئيسية والخطة ومركزها ويوم العرس

**Files to inspect:** home، wedding_plans، wedding_day، onboarding، catalogs، dashboard contracts.

- [ ] افحص إنشاء/تعديل/اختيار خطة ومعلومات التاريخ والمنطقة والشخصية والعملة، وتوافق payload مع DTO.
- [ ] لكل كرت في الرئيسية/مركز الخطة حدد الصيغة ومصدر البيانات ووحدتها وهل يعرض مكتملًا أم متبقيًا.
- [ ] قارن الصفحة حين لا خطة، خطة فارغة، خطة بها عمل، عدة خطط، مشارك محدود، وقرب/مرور الموعد.
- [ ] تتبع كل CTA إلى الوجهة والخطوة التالية. افحص اقتراح إعداد شيء أُعد بالفعل، التكرار والأولوية.
- [ ] افحص timeline/wedding-day، مسؤولية الاتصال/الموعد، مصدر البيانات، cold-start offline وحدود المعلومات الخاصة.
- [ ] راجع empty/error/partial وفقد الشبكة: لا تعرض خطأ على أنه «لا يوجد».
- [ ] Acceptance: لكل كرت غرض وحقيقة وفعل أو سبب كونه informational؛ لا نص يوحي بتقدم أو رقم غير صحيح.

### Task 5 — المال كرحلة صحيحة ومفهومة وآمنة

**Files to inspect:** finance + money API/domain/contracts، cost/payment/schedule screens، local sync.

- [ ] تتبع budget unset/set، allocations، category، cost، actual payment، reversal، remaining، schedule، overdue/reminder.
- [ ] تحقق من الفروق: no budget ≠ zero budget؛ reminder ≠ payment؛ قبول عرض ≠ عربون؛ المدفوع لا يزيد دون حركة صحيحة.
- [ ] قارن كروت summary/detail/list/calendar بالأرقام نفسها، مع وحدات وlocale وأرقام عربية وحدود الحقول.
- [ ] افحص create/edit/delete/cancel المؤهلة، double tap/retry والعملية الجزئية وtransaction/idempotency حسب العقد.
- [ ] تحقق من amount privacy في كل مكان، ومنها upcoming card، والتنبيهات والروابط والـcache والصور، مع صلاحيات عرض/إدارة مختلفة.
- [ ] اختبر الانتقال من قبول عرض إلى تكلفة واحدة بpaid0، وما يحدث عند فتح المصدر أو سحب صلاحية.
- [ ] افحص offline writes الموجودة فعلًا: pending لا يعني server confirmed؛ blocked queue لا تختفي؛ refresh لا يكرر دفعة.
- [ ] Acceptance: الأرقام تتطابق مع ledger، العمليات لا تتكرر، والواجهة تشرح أثر العكس/الإلغاء ولا تسرب المال.

### Task 6 — المهام والضيوف والمسؤولية

**Files to inspect:** tasks، guests، timelines، sharing authority، API/local queue.

- [ ] تتبع إنشاء/تعديل/إنجاز/إلغاء مهمة، due date، المسؤول، الاقتراح والقائمة والفلترة والعودة.
- [ ] تحقق من عدادات المكتمل/المتبقي والـdashboard وtimeline، وربط مهمة بأثر مالي إن وجد دون اختراع دين/دفعة.
- [ ] تتبع guest/group/RSVP/count وvalidation والتكرار والبحث والتعديل، ومن يستطيع رؤية الهاتف أو تعديل الضيوف.
- [ ] افحص المالك والمشارك بصلاحيات مختلفة، assigned/unassigned، سحب الحقوق والبيانات القديمة.
- [ ] راجع empty states والأزرار في صفحة المساهم: هل يعرف كيف يضيف؟ هل يصل إلى الفعل ويعود؟
- [ ] Acceptance: المسؤولية مفهومة، العدد صحيح، لا تعارض UI/API، ولا حقول أو خطوات لا تخدم حاجة معلومة.

### Task 7 — الدعوات والمشاركة والمساهمين

**Files to inspect:** sharing، contributor workspace/account، invitations API، account_contexts، notifications.

- [ ] راجع inviter → link → recipient → review rights → accept/decline → workspace → revoke/leave.
- [ ] قارن كل checkbox permission بالحق المخزن والـAPI. اسم الدور ليس permission fallback.
- [ ] افحص رقم مختلف/حساب مختلف، token expiry/reuse، double accept، العضوية القائمة، تغيّر الحقوق أثناء التصفح.
- [ ] افحص عرض الحقوق والموافقة وسجل المساهمات والخصوصية بعد سحب العضوية أو تغير tenure.
- [ ] راجع إشعار الدعوة المقبولة: هل يعود إلى الخطوة المنطقية بدل بدء onboarding غير لازم؟ مع عدم تجاوز حماية الرابط.
- [ ] افحص scroll للـbottom sheets وتكبير الخط وقابلية الوصول لزر القرار.
- [ ] Acceptance: كل طرف يعرف ما يشارك ولمَن وبأي حقوق، والواجهة والـAPI والـcache تسحب السلطة الصحيحة.

### Task 8 — المزود عند صاحب الخطة: اكتشاف وعروض ومحادثة وتقييم

**Files to inspect:** marketplace، chat، plan providers، finance links، quote/provider/review APIs.

- [ ] تتبع البحث والفئة والمنطقة والمفضلة والملف والخدمات/الباقات والصور والأسعار وطلب العرض.
- [ ] افحص قيمة ومصدر كل معلومة: «متاح» و«موثق» وrating لا تتجاوز الدليل الحالي. لا تفترض وجود availability.
- [ ] تتبع request → provider reply → offer → accept/reject/expiry/cancel/repeat، وربط المحادثة بالخطة/الحساب الصحيح.
- [ ] قارن العميل والمزود لحظة تغير الحالة: نفس السعر والخدمة والحالة والمرجع، دون تعديل accepted snapshot بصمت إذا العقد يمنعه.
- [ ] افحص scoped chat، unread، الملفات، block/report/mute والسحب؛ لا تجعل محادثة مفتوحة feature مقترحة كأنها مطلوبة.
- [ ] تتبع قبول عرض خطة إلى المال. راجع account-scoped offers مستقلًا؛ لا تفرض خطة غير موجودة.
- [ ] افحص إنشاء/تعديل/تكرار/إزالة تقييم ضمن العقد الحالي؛ «تقييم بعد completion» حاجة مقترحة إن لم تعتمد.
- [ ] أخرج gap منفصلًا للحجز/العربون/المقارنة/اتفاق/versioning، مع حاجة وتعارض وتبعية؛ لا تنفذها.
- [ ] Acceptance: العلاقة الحالية مفهومة من طرفين؛ ما لا يمكن استكماله بسبب غياب مزود Active يسجل blocker لا اختبار ناجح.

### Task 9 — رحلة المزود واعتماده وتشغيل عمله

**Files to inspect:** provider_portal بكل تبويباته، onboarding/status، admin providers، contracts.

- [ ] تتبع apply/draft/pending/needs-changes/active/blocked وكل حالة موجودة فعليًا، وأسبابها وحقوقها.
- [ ] افحص الرئيسية والطلبات والخدمات والباقات والرسائل وملفي والوسائط؛ ما الفعل المناسب الآن في كل حالة؟
- [ ] قارن «preview public profile» بالقانون الذي يمنع نشر pending، والخطأ/CTA بحالة تحميل البيانات.
- [ ] راجع طلب صور الخدمات عندما إدارة الخدمات محجوبة؛ سجل contradiction بدل اعتماد المزود تلقائيًا.
- [ ] تتبع provider response عند العميل وAdmin decision عند المزود والإشعار، بما فيها rejection/retry وإعادة التقديم.
- [ ] افحص الأرقام والفلاتر وأحداث الرسائل وعدم اختلاط حساب المزود بسياق ملكية أو مساهمة.
- [ ] Acceptance: لا وعد أو زر يوحي بإمكان غير متاح؛ workflow الاعتماد والطلب يصل إلى الطرف المناسب.

### Task 10 — Admin بالكامل وأثر كل قرار

**Files to inspect:** جميع18 Page files و22 routes، layouts/RBAC، backend backoffice public contracts.

- [ ] جرد login/dashboard/reports/providers/applications/details/users/catalog/references/locations/services/reviews/moderation/notifications/audit.
- [ ] صنف aliases/redirects قبل الادعاء بغياب شاشة create؛ مثل routes new التي قد تعيد توجيهًا مقصودًا.
- [ ] لكل جدول وكرت: مصدر الرقم، الفلاتر/pagination/empty/error، selection والحالة، freshness والـexport إن وجد.
- [ ] لكل إجراء: permission، تأكيد، payload، أثر على الهاتف والطرف الآخر، audit log، وفشل قابل للتعافي.
- [ ] افحص Admin محدود الصلاحيات وAPI direct access وفق حساب اختبار مخول؛ اخفاؤه من sidebar لا يثبت authorization.
- [ ] افحص المرجعيات وأثر تعديلها على البيانات القديمة والـoffline cache دون تغيير سجل حقيقي.
- [ ] Approval أو block أو moderation عملية كتابية مشروطة ببيانات اختبار؛ لا تغير اعتماد مستخدم فعلي.
- [ ] Acceptance: كل صفحة وقرار مفهوم ومصرح وله أثر متتبع؛ Admin ليس خارج القبول لأن الهاتف هو الواجهة الأساسية.

### Task 11 — الإشعارات والوسائط والروابط والإعدادات والدعم

**Files to inspect:** notifications/settings/more/support، push client/token APIs، media، deploy/public-site، Android manifest/build contract.

- [ ] افحص notifications لكل سياق: event → feed → badge → read → route، وforeground/background/killed/deep-link بعد login.
- [ ] نفذ Push حقيقيًا فقط إلى device token الاختبار المسموح؛ Firebase initialize ليس دليل وصول، وdisabled ليس نجاح إرسال.
- [ ] افحص رفع/عرض/حذف/استعادة media ضمن بيانات اختبار، signed expiry/wrong owner/permission revocation، والتنظيف دون حذف محتوى مهم.
- [ ] اختبر invite link في browser مع/بدون app، package/signing/assetlinks، token safety، ورسالة fallback ومكان العودة.
- [ ] راجع support/privacy/settings/more والتنقل وسهولة الوصول للقرار، وإذن OS المرفوض أو المسحوب.
- [ ] account erasure destructive: source/tests أولًا؛ live فقط لحساب تضحية منفصل بتفويض صريح وخطة بيانات، وإلا NOT PROVEN runtime.
- [ ] Acceptance: لا رحلة معلقة بين browser/app/notification، ولا بيانات خاصة في تنبيه أو ملف أو سجل غير مخول.

### Task 12 — offline/recovery/concurrency عبر الأقسام

**Files to inspect:** OFFLINE_SQLITE.md، local stores/queue/session، tests القائمة؛ source الفعلي يحدد الملفات.

- [ ] اصنع مصفوفة operation → offline supported? → cache scope → pending UI → retry/idempotency → revoked/expired handling.
- [ ] قارنها بالنطاق الحقيقي: auth/OTP/quotes/provider/admin/permission mutations online-only حيث يلزم؛ لا تعمم قاعدة على كل كتابة.
- [ ] افحص restart/cold cache، stale/corrupt cache، network timeout بعد server commit، duplicate tap، out-of-order queue، reconnect.
- [ ] افحص switching account/plan/logout أثناء pending؛ لا تسرب ولا replay لحساب آخر.
- [ ] افحص server changes/revoked rights أثناء offline: UI cached ليس إذنًا جديدًا؛ الخطأ أو التعارض لا يختفي صامتًا.
- [ ] سجل الحاجة إلى isolated DB concurrency test إن mocks لا تثبت atomicity. لا تستخدم smokes على DB قائمة.
- [ ] Acceptance: يعرف المستخدم ما حفظ محليًا وما ثبت بالخادم، ولا يفقد عمله أو يعيد مالًا أو حقًا بلا تشخيص.

### Task 13 — المرور المتصل متعدد الأدوار والحالات البصرية

**Consumes:** registry، journeys، نتائج Tasks3–12.
**Produces:** evidence links و03-findings.

- [ ] نفذ سيناريو مالك من دخول إلى خطة/ميزانية/تكلفة/دفع/مهمة/ضيف/دعوة، على بيانات اختبار؛ لا تدعي إكماله بزيارة tabs فقط.
- [ ] نفذ سيناريو عروسة/مالك مستقل، ومساهم view-only وآخر بحقوق محددة، والتحويل بين السياقات.
- [ ] نفذ provider pending ثم Active عبر test account وAdmin مخول فقط؛ customer → request → quote → chat → acceptance → cost، بالحقوق المناسبة.
- [ ] تحقق من تغير الحالة عند الطرف الآخر والإشعارات لا فقط toast الطرف الأول؛ قبل/بعد كل عملية وسجل أثرها.
- [ ] مر على كل سطح فريد من registry على الهاتف/المتصفح؛ صور الحالات المهمة ومشكلات الاستخدام، وراجع shared widget في كل استعمال مختلف.
- [ ] اختبر RTL ونصوص طويلة وfont scale الفعلي1.15 والـkeyboard/scroll/back. تغيير settings إضافي يسجل ويعاد فقط إلى قيمته الأصلية بعد اختبار مأذون.
- [ ] تحقق من جميع أسطح المال المنطبقة عند320px RTL و1.3 text scale حسب MOBILE_QA؛ ومن touch targets48×48 وsemantic labels/focus وAA contrast حسب DESIGN_SYSTEM. استخدم الاختبارات القائمة، وسجل الحالات التي لم تغطها NOT PROVEN دون بناء APK أو تغيير مصدر.
- [ ] سجل recovery/error/retry والـdouble tap حيث لها أثر. لا تختبر cartesian product غير مبرر.
- [ ] Acceptance: كل رحلة أساسية لها بداية ونهاية أو توقف مفسر؛ لا تنفيذ لحجز غير موجود أو تفاصيل مالية وهمية.

### Task 14 — مراجعة فائدة كل عنصر والقرارات كشريك

**Consumes:** كل الأدلة؛ لا أحكام من الذوق وحده.
**Produces:** 04-product-decisions-and-priorities.md.

- [ ] لكل شاشة اكتب باختصار: وظيفتها، جمهورها، ما يجب أن يعرفه بعدها، وما الذي يفعل به.
- [ ] لكل قسم/كرت: هل يحتاجه هذا الشخص الآن؟ هل صحيح؟ هل له فعل أو غرض معلوماتي؟ هل يكرر؟ هل ترتيب الأولويات مناسب؟
- [ ] صنف KEEP / FIX / SIMPLIFY / MERGE PROPOSAL / REMOVE CANDIDATE / ADD PROPOSAL / NOT PROVEN، مع سبب ودليل.
- [ ] لكل finding: صِف المشكلة وما يحدث للمستخدم، سببها، أقل علاج صحيح، بديل إن كانت مفاضلة، acceptance وتبعية.
- [ ] اجمع التصحيحات حسب earliest wrong source: لا ترقيع كل شاشة إذا الحقيقة المشتركة خاطئة.
- [ ] افصل حاجات النطاق الحالي عن طموح المزود المتكامل. قارن التكلفة والفائدة والتعقيد والخطر قبل توصية expansion.
- [ ] رتب «لو كان مشروعي» إلى: ما أصلحه قبل توسعة، ما أبقيه، ما أبسطه، ما أضيفه بعد قرار، وما أؤجله.
- [ ] Acceptance: خطة قرار قابلة للنقاش باللغة العربية، مرتبطة بمعرفات evidence، دون وعود أو نسب جودة مختلقة.

### Task 15 — تدقيق الاكتمال والتسليم

**Produces:** 05-acceptance-receipt.md + خلاصة شريك نهائية.

- [ ] reconcile كل20feature/route/source/page/surface مقابلregistry؛ أي عنصر unclassified يعني الفحص غير مكتمل.
- [ ] احسب reviewed/tested/device/blocked منفصلة؛ لا تحول وجود سجل إلى device-tested.
- [ ] راجع false assertions: docs-only vs real، optional vs missing، denied vs bug، privacy hide vs authority، cached vs synced.
- [ ] راجع الملاحظات السابقة: بقيت/زالت/غير مثبتة عند المصدر الحالي، لا تكررها فقط لأنها في تقرير.
- [ ] شغّل docs checks وdiff whitespace؛ سجل الأمر ونتيجته الدقيقة. لا regenerate أو weaken لجعلها خضراء.
- [ ] قارن git status قبل/بعد واشرح كل Markdown جديد. افصل عدم تغيير كود التطبيق/main وإعدادات وموارد نشر الخادم وAbdo عن سجل تغييرات بيانات الاختبار المنفذة فعلًا؛ لا تدّع أن بيانات Backend لم تتغير إذا أجريت عمليات قبول/إنشاء.
- [ ] سلّم التقرير مع covered/not covered، findings بالأولوية، decisions المطلوبة، وخطة remediation لاحقة مستقلة.
- [ ] Acceptance: المالك يستطيع اختيار الخطوة التالية على أساس دليل، ويعرف بالضبط ما لم يثبت بعد.

## 7. Tests and commands: selection rules

هذه أوامر التنفيذ اللاحق، وليست ادعاء بأنها شغلت أثناء التخطيط. اقرأ package scripts/QA قبل أي smoke؛ بعضها يحتاج DB وبيانات ووقت. لا يشغل على DB أو جلسة موجودة لمجرد الاسم.

### Docs-only verification الآن وبعد كتابة التقرير

From repository root:

```powershell
node .\scripts\docs-sync.mjs --check
node .\scripts\docs-verify.mjs
git diff --check
git status --short
```

`git diff --check` لا يغطي الملفات الجديدة غير المتتبعة؛ تفحص whitespace وروابط Markdown الجديدة مستقلًا.

### Native frontend evidence عند تنفيذ الفحص

From `mobile/`، اختر القائمة المتصلة بالرحلة، وليس كل الاختبارات كل مرة:

```powershell
flutter test --no-pub test/features/sharing/invite_access_screen_test.dart test/features/sharing/accepted_invite_context_test.dart test/features/sharing/sharing_invite_state_hardening_test.dart test/features/wedding_plans/contributor_workspace_view_test.dart test/features/wedding_plans/contributor_account_actions_test.dart --reporter expanded
flutter test --no-pub test/features/finance/money_privacy_test.dart test/features/finance/money_summary_contract_test.dart test/features/finance/money_detail_screens_test.dart --reporter expanded
flutter test --no-pub test/offline/offline_session_isolation_test.dart test/offline/offline_sync_error_handling_test.dart test/offline/sync_queue_plan_ownership_test.dart --reporter expanded
flutter test --no-pub test/features/notifications/notification_context_isolation_test.dart test/features/notifications/notification_route_policy_test.dart --reporter expanded
flutter test --no-pub test/features/marketplace/provider_dashboard_resilience_test.dart test/features/marketplace/provider_details_view_test.dart --reporter expanded
flutter test --no-pub test/core/widgets/aarast_accessibility_test.dart test/core/theme/aarast_design_tokens_test.dart --reporter expanded
```

إذا لم يغط الاختبار السلوك المطلوب، تسجل حدود الدليل. لا تكتب test يطابقImplementation كبديل عن المطلوب، ولا تغير assertion في مهمة الفحص.

From `admin-web/`: `npm run test:architecture`، `npm run typecheck`، `npm test` عند الحاجة لعقد/RBAC محل الشك. Tests لا تثبت تجربة Admin browser وحدها. Build في الفحص ليس افتراضيًا لأن artifact الحالي هو محل القبول؛ يطلب فقط إذا فقد artifact ويحتاج تفويض مناسب.

### Backend isolated evidence عند الحاجة

- تحقق scripts في `backend/package.json` وwrapper العزل قبل التشغيل؛ DB integration يجب أن تستخدم proof DB مستقلة بلا أسرار حقيقية.
- قبل أي smoke: سجل Docker context/host وهوية Compose والخدمات والـDB/bucket وRedis namespace. المشغّل قد يكتشف خدمات موجودة؛ اسمه isolated ليس إثباتًا لعزل المضيف. services مشتركة أو هوية غير مثبتة = BLOCKED؛ لا تستخدم خادم المشروع للاختبارات.
- development OTP fixture القائمة مسموحة فقط في الاختبار المحلي المثبت العزل؛ ليست OpenWA ولا إثبات الهاتف، ولا تنقل إلى Staging أو تغيّر provider. لا تضف fixture أو bypass جديدًا.
- أمثلة موجودة: `npm run smoke:sharing-security`، `smoke:sharing-roles`، `smoke:money-apis`، `smoke:financial-ledger-concurrency`، `smoke:providers-quotes`، `smoke:quote-stability`، `smoke:conversation-unification`.
- اختيار smoke مربوط بمخاطرة باقية. لا تشغيل `smoke:all` أو real OTP send تلقائيًا؛ لا صلاحية إرسال غير محدود تستنتج من3 رسائل سابقة.
- Architecture gates القائمة مرجع حماية عند ضرورة trace معمارية، وليست دعوة لإعادة architecture audit. لا scanner جديدة.

## 8. Known observations to revalidate, not a substitute for discovery

| المدخل السابق | نوعه الأولي | ماذا يجب إثباته؟ |
| --- | --- | --- |
| تعديل الخطة يرسل currency ويرفضه DTO | BUG reported | payload الحالي وAPI الفعلية وخطوات المالك |
| إخفاء مبالغ المال لا يغطي upcoming payment card | Privacy BUG reported | مواضع عرض المبلغ وهل الحالة permission أو privacy toggle |
| زر تم في permissions sheet مقصوص | BUG observed on device | layout/scroll/font scale؛ هل بقي عند المصدر الحالي؟ |
| public preview لمزود Pending يفتح error وCTA باق | BUG observed on device | حق المعاينة ومسارactive-only وإجراء الخطأ |
| مزود Pending يطلب service gallery والخدمات محجوبة | UX inconsistency | ما البديل المشروع في مرحلة اعتماد الملف؟ |
| دعوة مقبولة تعيد مدخل الرقم عبر notification | UX flow observation | security contract، user context، الوجهة المتاحة |
| onboarding المالي للمساعد بصياغة مالك | UX observation | الفروق اللازمة دون نسخ business logic |
| عدادات/تذكيرات عامة لا توافق حالة الخطة | Reported observation | الصيغة والنص والمصدر والحالات قبل أي finding |
| Real device Push وبقية الأدوار والرحلات | NOT PROVEN | تنفيذ حي موثق، لا استنتاج من Firebase init |

## 9. Checkpoints and definition of done

- **Checkpoint A (Tasks0–2):** شرح وظيفة النظام وخريطة الأدوار وجرد الأسطح؛ قبل الأحكام النهائية.
- **Checkpoint B (Tasks3–12):** كل نطاق له source/contract review ونتائج وموانع محددة.
- **Checkpoint C (Task13):** الرحلات المتصلة والدليل الحي حيث ممكن. لا انتظار حساب واحد يمنع باقي القراءة.
- **Checkpoint D (Tasks14–15):** تقرير رأي واضح ومفاضلات وأولويات ومصفوفة كاملة؛ لا implementation.
- Done يعني: كل عنصر classified، كل journey لها نتيجة أو blocker، كل حكم له دليل وحدوده، وكل توسعة تحتاج decision معروفة.
- ليس Done: عدد صور كبير، مرور علىtabs، local green، أو إعلان «كل شيء ممتاز».
- تسلم الخطة للمالك للمراجعة. التوصية لتطبيقها: تنفيذ متتابع في الجلسة نفسها للحفاظ على فهم واحد للنظام؛ لا تعديل منتج قبل قبول النتائج وخطة علاج منفصلة.
