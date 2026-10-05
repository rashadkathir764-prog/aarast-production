# Findings — rolling product audit

Source: `14eccb50c6b2e050b044c7b00ac38a7e64f5164b`. This is a rolling ledger, not a final or exhaustive list.

No fixes were applied. Historical device evidence below is explicitly dated2026-10-04; current source was read in this phase. Fresh device reproduction has not occurred in this phase.

## F01 — BUG / P1 — تعديل معلومات الخطة يرسل حقلًا يرفضه العقد

- User effect: حفظ تعديل معلومات الخطة يمكن أن يفشل حتى لو لم يغير المستخدم العملة؛ payload يرسلها دائمًا.
- Current source: mobile/lib/features/wedding_plans/screens/plan_management_screen.plan_edit.dart:424–441, toUpdateJson adds currency.
- Backend: backend/src/wedding-plans/dto/update-wedding-plan.dto.ts:13–49 has no currency validation field.
- Gate: backend/src/main.ts:75–77 enables whitelist and forbidNonWhitelisted.
- Previous device observation: plan update returned “property currency should not exist” in the local device ledger. No fresh server response attributed here.
- Proof level: SOURCE plus prior DEVICE evidence at this candidate; deployed Backend identity NOT PROVEN in this phase.
- Smallest remedy to decide later: align the plan edit payload with the approved update contract. Do not add currency mutability blindly; changing currency with existing costs needs a separate explicit product decision.
- Acceptance later: edit title/date/location/priority succeeds under actual DTO; rejected fields remain rejected; currency semantics unchanged.
- Status: source mismatch revalidated; no fix.

## F02 — BUG / P1 — إخفاء المبالغ لا يغطي كرت موعد الدفع التالي

- User effect: ضغط إخفاء المبالغ لا يخفي مبلغ الموعد التالي؛ قد ينكشف لمن ينظر إلى الهاتف.
- Not a claim: this is a local privacy-display defect, not proof of foreign-user API access or a broken canViewMoney rule.
- Current source: money_overview_screen.dart:128–147 passes amountsHidden to _MoneySnapshot but not _NextPaymentCard.
- money_overview_screen.dart:749–789: the card formats schedule.amount directly and includes it in reason text.
- Previous device observation: privacy-payment-leak.png in the local device acceptance evidence directory.
- Test boundary: money_privacy_test.dart:18–29 renders MoneyPrivacyButton and MoneyAmountText only, not MoneyOverviewScreen or _NextPaymentCard. Its name does not expand its coverage.
- Smallest remedy later: make this attention card consume the existing privacy-display state consistently; do not change financial permission contracts or hide errors.
- Acceptance later: next/overdue/summary/detail amounts respect the applicable hide policy; dates/actions remain understandable; no plaintext amount remains in semantics.
- Status: current source confirms the unmasked path; fresh physical-device reproduction pending.

## F03 — BUG / P2 — معاينة ملف مزود Pending تذهب إلى دليل Active فقط

- User effect: زر معاينة الملف العام ظاهر، لكنه يفتح خطأ للمزود الذي لم يعتمد بعد. Action footer remains available independently of detail error.
- Current source: provider_profile_tab.dart:91–97 opens AppRouter.providerDetails(profile.id) unconditionally.
- marketplace.service.ts:173–178 uses findActiveProviderWithServices and throws when absent.
- marketplace-core.repository.ts:35–38 filters status ACTIVE.
- provider_details_screen.dart:75–145 constructs quote actions separately from detailsError handling at:165–183.
- Previous device observation: pending-provider-public-preview-error.png; no quote was requested and no API status is claimed from that image.
- Smallest remedy later: state-appropriate profile preview/action; do not make Pending public or approve a provider to hide the defect.
- Acceptance later: Pending can understand/profile-review its actual state without public access being granted; error/unknown provider has no misleading actionable quote CTA.
- Status: source path revalidated, with prior device evidence; no fix.

## F04 — BUG / P2 — زر تم في نافذة حقوق المساهم قد يصبح مقصوصًا

- User effect: عند نافذة حقوق طويلة، زر الإغلاق غير قابل للوصول من داخل المحتوى. Android Back worked in the prior test; this is not claimed to be a permanent navigation trap.
- Current source: plan_management_screen.contributor_account.dart:297–305 creates a sheet and a non-scrolling Column; button near:383.
- Helper: core/widgets/aarast_bottom_sheet.dart:8 defaults isScrollControlled=false.
- Previous device evidence: contributor-permissions-bottom-clipped.png, font_scale1.15, screen1440×3120; swipe did not reveal the button.
- Smallest remedy later: content-size/scroll-safe sheet while preserving rights and action semantics; no permission logic changes.
- Acceptance later: every right and close action reachable at actual device scale and the applicable narrow/large-text criteria.
- Status: current layout path remains, prior physical reproduction retained; no fresh capture in this phase.

## F05 — BUG / P1 — حفظ المهمة جزئيًا ثم عرض نسخة قديمة بعد فشل تعيين المسؤول

- User effect: يغيّر المستخدم عنوان المهمة ومسؤولها معًا. قد يحفظ الخادم العنوان ثم يرفض تعيين المسؤول. حالة المهمة المحلية/القائمة تعرض النسخة القديمة؛ بعد التحديث يظهر العنوان الجديد. نتيجة «لم يحفظ» غير دقيقة، وقد يعيد المستخدم العملية دون معرفة ما ثبت. لم يثبت الـprobe رجوع نص حقل النموذج نفسه.
- Current source: mobile/lib/features/tasks/providers/task_timeline_provider.dart:295–303 sends updateTask then assignTask, in separate requests. Both catch paths at:315/:319 replace the task with previousTask.
- API paths: mobile/lib/features/tasks/data/task_timeline_api.dart, updateTask calls PATCH /api/v1/tasks/:id; assignTask calls PATCH /api/v1/tasks/:id/assign. backend/src/tasks/tasks.controller.ts:96–111 exposes separate handlers under the api/v1/tasks controller prefix; no shared HTTP transaction is assumed.
- Safe reproduction: outside-Git task_partial_save_probe_test.dart uses a Dio adapter only. Initial title=Original; first PATCH stores Updated and returns200; assignment returns400. Result=false and local title=Original; refresh reads Updated. Probe exit0,1 diagnostic test reproduced the defect. No real HTTP, DB, credentials or user data.
- Evidence: SOURCE + LOCAL REPRODUCTION. The test asserts the defect exists; its PASS is not a product correctness PASS. Real PostgreSQL/phone occurrence NOT PROVEN here.
- Smallest remedy to design later: reconcile the committed first result and communicate partial success before retrying the failed assignment. An atomic combined contract is an alternative only after explicit scope approval; do not blindly retry or claim full rollback.
- Acceptance later: first-step failure, second-step failure, timeout after commit, complete success and retry show the actual saved fields and assignment; no silent data rollback or duplicate side effects.
- Status: reproduced; no fix.

## F06 — BUG / P2 — اليوم الكبير يعرض فعل إنجاز رغم غياب حق إدارة المهام

- User effect: وجهات المهام/الضيوف/المزودين تظهر في اليوم الكبير بلا مراعاة الحقوق؛ البوابة اللاحقة قد تمنعها. وعند تمرير مهمة إلى مكوّن اليوم الكبير مع canManageTasks=false، يبقى زر إنجاز قابلًا للاستدعاء. هذا إثبات لمكوّن UI، وليس إثبات أن مساهمًا بلا الحق منذ البداية يرى مهمة بعد تحميل طبيعي.
- Reachability: app_router.dart:402 maps wedding-day to viewPlan, while timeline/tasks and guests/providers require their respective management capabilities. A Planning contributor can therefore reach this read surface without those rights.
- Current source: wedding_day_mode_screen.dart:147 passes _completeTask unconditionally; wedding_day_mode_view.dart:106 binds every priority row, and:340 sets onPressed=onComplete without summary.permissions. Quick destinations are unconditional too.
- Safe reproduction: outside-Git wedding_day_authority_probe_test.dart renders WeddingDayModeView with isOwner=false and canManageTasks/Guests/Providers=false. The completion button is visible and callback fires once. Probe exit0,1 diagnostic test; no API/data action.
- Independent review correction: tasks.service.ts:186–191 returns [] for a contributor without task rights; TaskTimelineProvider.load:78–83 replaces data on success. Old tasks can be retained on a failed load. A stale/revoked state is a candidate for end-to-end reproduction, not a verified device/server occurrence in this phase.
- Server boundary: collaboration/internal/permission.service.ts:374–382 checks owner or the stored permission flag; assertTasksManageable is used for mutation. This is NOT proof of server authorization bypass or successful forbidden completion.
- Smallest remedy later: consume the existing capability contract in the day view and distinguish informational rows from authorized actions. Preserve read access, real task ordering and server checks.
- Acceptance later: owner/write contributor can act; read-only contributor cannot invoke mutation UI; revoked rights and archived state are handled; permitted destinations remain accessible.
- Status: unconditional quick destinations and unguarded component callback reproduced; reachability of a task with revoked rights in the live full journey remains NOT PROVEN.

## F07 — BUG / P1 — دفعة محفوظة تُعرض كفشل إذا تعذر تحديث بيانات المال

- User effect: قد يقبل الخادم تسجيل دفعة، ثم يفشل تحميل ملخص المال. تعرض الشاشة فشل الحفظ وتبقى بيانات المبلغ القديم والنموذج؛ إعادة المحاولة قد ترسل عملية تسجيل ثانية بدل إعادة قراءة الدفعة المحفوظة. تسجيل الدفعة هنا سجل مالي داخل أعرست، وليس خصمًا عبر بوابة دفع.
- Current source: mobile/lib/features/finance/providers/finance_provider.dart:520–540 runs createPayment followed by _reloadData inside _submit. _submit:667–703 treats a refresh exception as submission failure. _reloadData assigns refreshed state only after the group of reads succeeds.
- UI: RecordCostPaymentScreen in mobile/lib/features/finance/screens/cost_payment_screens.dart:259–273 clears the draft/shows success only for a non-null result; failure retains the input. FinanceApi._mutation in data/finance_api.dart:167–196 generates a new X-Client-Request-Id for each new method invocation. A UI retry is therefore a new request, not necessarily replay of the successful request's identity.
- Safe reproduction: outside-Git payment_commit_refresh_probe_test.dart uses the actual provider/API with a Dio adapter. First POST returns200 and records100; subsequent money-summary GET returns500. recordPayment returns null and local paid amount remains0. Retrying issues a second POST with a distinct generated request ID; fake server records two payments. Probe exit0,1 diagnostic test reproduced this sequence. No real DB or transfer and no user data.
- Backend limit: wedding-costs.service.ts:649–710 checks permission, locks the cost, validates amount against the current remaining amount and inserts within a serializable transaction. The finding does not claim bypass of these checks or that a repeated amount exceeding the actual balance is accepted. A separate new payment may be valid when sufficient balance remains.
- Proof level: SOURCE + LOCAL REPRODUCTION of misleading failure and a distinct second write request. Real PostgreSQL duplicate payment and physical-device occurrence NOT PROVEN in this phase. The diagnostic test's PASS means the defect was reproduced, not fixed.
- Smallest remedy to design later: preserve the confirmed mutation result and separate refresh failure from write failure; show saved-but-not-refreshed state and offer read retry. Ambiguous write outcomes must retain their existing idempotency/reconciliation contract; never turn uncertain writes into fake success.
- Acceptance later: write rejected, write timeout, confirmed write followed by any refresh failure, retry, stale summary and full success display the correct truth. Confirmed-write refresh retry causes no new payment POST; permission/amount/transaction checks remain intact.
- Status: reproduced; independently reviewed against provider/API/UI/Backend; no fix.

## F08 — BUG / P2 — اختصارات Admin الرئيسية لا تراعي صلاحيات الوجهة

- User effect: يرى MODERATOR اختصارات الفئات/المدن/الخدمات رغم غياب CATALOG_READ وSERVICES_READ، ويرى SUPPORT التقييمات/التقارير رغم غياب REVIEWS_READ وREPORTS_READ. الضغط يعيد إلى الرئيسية عبر guard بدل الوصول إلى العمل المعروض أو شرح المنع.
- Current source: DashboardPage.tsx:245–285 renders these Link controls unconditionally. App.tsx protects categories/cities/services/reviews/reports by their separate read permissions. RequireAdminPermission.tsx:14–17 redirects a denied user to /. The allowed dashboard itself requires DASHBOARD_READ.
- Role proof: backend/src/modules/backoffice/domain/admin-permissions.ts defines MODERATOR and SUPPORT exactly as above; both have DASHBOARD_READ. This is a supported role combination, not an invented user with arbitrary flags.
- Evidence: SOURCE trace of visible control → route guard → supported role permissions. No current Admin account/browser click was performed, and no server access bypass is claimed. DashboardPage.test.tsx covers loaded/empty/error, not role-filtered quick links.
- Hypothesis rejected during inspection: dashboard stats combined with provider applications do NOT inherently fail for an existing role merely because of permission separation: all current dashboard roles also have PROVIDERS_READ. Do not count that hypothetical403 as another defect.
- Smallest remedy later: use the existing read-permission contract for quick destinations, preserving route/API guards and useful permitted actions. Do not broaden role permissions to make the links work.
- Acceptance later: SUPER_ADMIN/OPERATIONS/MODERATOR/SUPPORT see reachable quick links only; direct denied URLs remain denied; loaded/empty/error dashboard behavior remains intact.
- Status: source-proven UI navigation mismatch; live reproduction pending; no fix.

## F09 — BUG / P2 — عنوان تعديل الخطة يدخل منطقة شريط حالة الهاتف

- User effect: عنوان «تعديل بيانات الخطة» يتداخل مع شريط حالة Android عند فتح النافذة الطويلة. إعادة إغلاقها وفتحها أعادت التداخل. التمرير يصل إلى الحفظ؛ ليس احتجازًا دائمًا ولا دليلًا على نجاح/فشل الحفظ.
- Current source: mobile/lib/features/wedding_plans/screens/plan_management_screen.plan_edit.dart:8–16 opens a scroll-controlled sheet without useSafeArea. Its inner Padding/SafeArea/SingleChildScrollView at:258–275 does exist; do not report SafeArea as absent.
- Boundary cause: mobile/lib/core/widgets/aarast_bottom_sheet.dart:9/:23 defaults useSafeArea=false and forwards it. Installed Flutter bottom_sheet.dart:983–986/:1121–1123 removes top MediaQuery padding in that mode, so the inner SafeArea cannot restore it.
- Approved criterion: docs/frontend/DESIGN_SYSTEM.md:309–310 requires sheets to account for keyboard and safe area.
- Physical evidence:31-plan-edit.png and33-plan-edit-reopened.png outside Git, Samsung SM_S938B, font scale1.15.32-plan-edit-bottom.png shows reachable Save; no submit. APK source revision remains unbound.
- Local diagnostic: actual PlanCenterScreen, local guest-plan fixture,320×720/1.3 scale, top system inset30. Open actual editor and measure actual heading: y14 <30. Scroll reaches hit-testable Save without submitting. Dio adapter forbids real HTTP. Outside-Git plan_edit_safe_area_probe_test.dart, exit0/1 diagnostic test reproduces the defect, not product acceptance.
- First probe attempt: exit1 because the launcher tap occurred before the post-scroll layout settled, outside viewport at y927.5. Corrected only the scratch harness by settling and asserting a hit-testable launcher; no application/assertion weakened. Then the actual heading geometry reproduced the finding.
- Smallest later remedy: preserve the top inset at this sheet boundary; review keyboard/scroll/RTL at applicable sizes. Do not change every sheet globally or change plan fields/permissions as an audit shortcut.
- Status: SOURCE + CURRENT DEVICE OBSERVATION + LOCAL REPRODUCTION; no fix.

## D01 — DOCUMENTATION CONTRADICTION / P2 — وصف صلاحيات الضيوف القديم يخالف العقد الحالي

- docs/backend/API_CONTRACT.md:1700–1703 claims role names can grant guest mutation rights at runtime.
- The same document:1211–1216 says stored flags are final authority for tasks, guests, providers, money and member management.
- Current permission.service.ts:374–382 checks owner or stored canManageTasks/canManageGuests only. Mobile route access at app_router.dart:406–409 follows capabilities.
- Effect: a future agent or tester may provision/expect access from a role name incorrectly. This is a documentation defect, not evidence that current server grants that access.
- Proposed later correction: align the obsolete guest paragraph to the approved stored-flag policy; preserve role seeding at invitation creation where applicable. No approved document changed during this audit.

## UX questions — not promoted to mandatory defects

| ID | Observation | Current source/proof | Decision needed after fuller review |
| --- | --- | --- | --- |
| Q01 | بطاقة المهام قد تقرأ كأن صفرًا مكتملًا رغم اكتمال كل المهام | aarast_dashboard_mosaic.dart:204–218 shows remainingTasks and detail “مكتملة” at0; formula itself is correct | Wording/meaning test with completed versus remaining; do not call the arithmetic wrong |
| Q02 | اقتراح خدمات/صور قبل إتاحة العمليات للمزود | Prior Pending device observation; profile gallery shown outside operations guard | What can be prepared legitimately before approval, and which CTA should appear? |
| Q03 | إشعار دعوة مقبولة يعود إلى إدخال الرقم | Prior device observation; current invite_decision_screen.dart:70–83 deliberately requires recipient proof for a private link unless a verified resume was consumed;68 selected invite/auth tests PASS | Reopening a raw private link is not itself a bug. Review the notification destination and a safe current-context shortcut; do not remove proof or auto-accept |
| Q04 | إعداد المال للمساهم يتكلم بصياغة مالك | Prior device observation | Persona and granted capability wording without duplicating money business logic |
| Q05 | الرئيسية تعرض إنجاز100% مع بقاء إعداد الميزانية | Current phone: one completed task, no remaining tasks, budget starter. dashboard-summary.presenter.ts:392–398 computes task progress; aarast_dashboard_view.dart:483/:494 uses general plan completion label/semantics | Clarify whether the label should explicitly say task progress. Arithmetic is correct; no new readiness formula or code fix authorized. See06-device-observations.md |
| Q06 | الرئيسية تقترح إعداد الميزانية بينما الإضافة السريعة تسمي طلب عرض سعر «الأنسب الآن» | Current phone29-quick-add.png; quick_add_actions.dart uses creation-action ranking, providerCount/stage/urgency/last action, not budget presence or catalogue availability. Quote action opens plan provider discovery; it does not send a quote immediately.29 native focused tests PASS | Distinguish the main attention priority from a suggested creation action in wording. Different scopes are not a proven conflicting business rule; no mandatory recommendation-engine redesign or new API inferred |

## Proposed scope — separate

Basic comparison already exists in favorite_providers_screen.dart:132–186/:443–465: up to3 saved providers with category, city, price, rating and active-service count. Do not report comparison as wholly absent. Category-specific capacity/deposit/date-availability comparison is a proposed extension, not current functionality.

Full agreements/versioning, booking/availability, deposits, provider receipts and completion-gated ratings remain PROPOSED SCOPE GAP until approved. They are not counted as current-contract defects. Current reviews and the server guard against modifying accepted offers already exist; preserve them rather than creating parallel implementations.

## Remaining review

Every registered screen/control/state/role and handoff still needs traceability. Counts here must not be reported as the whole-project defect total.
