# Groom journey: what can be built now, and what needs the backend first

Date: 2026-10-20. Static audit. No code was changed.

**Purpose.** The owner wants to start building the redesigned groom journey with the screens whose data and actions the **current** backend already serves. Screens that need a new or changed endpoint are listed in section B for discussion. Section C lists the contradictions inside the new design that must be decided before building. Section D gives a build order.

**Inputs.** `screens_inventory.md`; `api_map_A_account_plan.md` (map A), `api_map_B_home_money.md` (map B), `api_map_C_tasks_guests_participants.md` (map C), `api_map_D_providers.md` (map D, customer side only); `api_inventory.md` (INV); `LOGIC_LIFECYCLE_AUDIT.md` (LLA); `GROOM_JOURNEY_PHASES.md` (phase tags); prototype source `mobile/test/prototype/v3/*.dart`, including `prov_side.dart` (f10 to f14), `gaps_a.dart` / `gaps_b.dart` (w01 to w42) and `participant2.dart` (q13 to q21). Doubtful cases were checked in `backend/src` (section 0).

**Scope.** Groom journey = every screen in `v3_test.dart` except the provider screens (p*), admin, the bride-only `a02c_whose_bride`, and the participant screens. Participant screens (q01 to q21, plus x04, x05, x06, y10 and w16, which the inventory lists in the participant journey) are classified in their own sub-sections, because they live in the same app.

## How to read this

- **A, buildable now:** the screen ships correctly on today's endpoints. This includes ✅ and 📱 rows, and 🔧 rows where the change can wait because a sub-element can be dropped or deferred without making the screen lie. The "Drop or defer" column names exactly what is left out. A screen in A must not show a number, state or promise that the backend cannot back.
- **B, needs backend first:** the screen cannot be built honestly without a new or changed endpoint. The contract comes from the api_map docs (section references given).
- Map status: the status the api_map docs gave the screen (✅ / 🔧 / ➕ / 📱). "🔧→A" means the change is real but not needed for a first honest version.
- Phase: `V1`, `1.1` or `later` from `GROOM_JOURNEY_PHASES.md`. "new" = the screen was added after that file (a08b, w*, q*, f10 to f14) and has no phase yet.
- `P` = `/api/v1/wedding-plans/:planId`. Every other path is under `/api/v1` too.
- "C#" refers to a logic decision in section C.

## Counts

| Section | Groom journey | Participant journey | Total |
|---|---|---|---|
| A. Buildable now | 113 | 15 | 128 |
| B. Needs backend first | 48 | 11 | 59 |
| Screens classified | 161 | 26 | 187 |
| C. Logic decisions | 43 rows, 47 ids (17 decide a section A screen, 15 are wording or state fixes on section A screens, 11 affect only section B) | | |
| D. Build slices | 10 slices covering all 128 section A screens | | |

---

## 0. Backend facts checked in source for this classification

These either correct an api_map row or decide a borderline case.

| # | Fact | Evidence | Effect |
|---|---|---|---|
| F1 | A starter-task catalog **already exists**: reference catalog `tasks.starter`, served by `GET /catalogs/bootstrap`, with `persona` and `daysBefore` per item. The mobile code already reads it (`mobile/lib/features/tasks/models/task_starter_catalog.dart`). | `backend/src/catalogs/reference-catalog.defaults.ts:182-271` | d03 moves from ➕ (map C) to A. |
| F2 | The real groom starter set is **20 tasks**: shared 8 + groom 9 + family 3 (bride: 8 + 6 + 3 = 17). The design says 30 (a08, a08b, d03, b02) and 23 (w09, w15, LLA). Neither matches. | same file, lines 195-257 | C6. Screens must show the catalog count. |
| F3 | A money starter catalog `money.starter.categories` exists (groom groups: agreement 4 items including «المهر والاتفاقات», event 10, look 5, life 7). | same file, lines 1-182 | a08 can show real item counts. The mahr is an ordinary category there (C1). |
| F4 | `GET P/payment-schedules/due` returns every PENDING schedule that is overdue or due within **30 days** (Asia/Riyadh day). | `wedding-costs/wedding-costs.service.ts:1063-1095` | Exactly c03's «خلال 30 يوم» window, so c03 is in A. |
| F5 | `summarizeFunding`: `shortfall = confirmedCost − (received + pledged)`, `null` when there are no sources. `availableCash = received − paid`. `confirmedCost` is the sum of costs, never allocations. | `money/money-summary.service.ts:340-411` | The server shortfall equals the design's «ومع الموعود», not «ناقصك» (C2). |
| F6 | `PUT P/money-budget` writes `WeddingPlan.estimatedBudget` (the budget total). `PATCH P` does not take the budget. | `money/money-budget.service.ts:163` | w10 and x03 set the budget through `money-budget`. |
| F7 | A new quote request to the same provider is allowed once every offer of the active request has expired; otherwise `409 ACTIVE_QUOTE_REQUEST_EXISTS`. | `marketplace/quote-request-creation.ts:139-157` | w31 «اطلب عرض جديد» works today. |
| F8 | `contactPhone` defaults to the user's phone when the client sends none, so the provider always gets a phone. Budget fields are sent only if the client sends them. | `marketplace/marketplace.service.ts:394-398` | f07 can keep «بندك ما يوصلهم إلا إذا فعّلته» honestly. The phone is always shared (C46). |
| F9 | The public RSVP page already exists (`deploy/public-site/rsvp.html/js/css`), on top of `GET/POST /public/rsvp/:token`. | `deploy/public-site/` | e05 is in A. |
| F10 | `weddingDate` is optional in `CompleteOnboardingDto` and `CreateWeddingPlanDto`; `PATCH` cannot clear it (map A). | `onboarding/dto/complete-onboarding.dto.ts:36` | «ما حددنا الموعد بعد» works at creation; clearing a date later does not. |
| F11 | Provider search results carry `verifiedAt`, `isClaimed`, and per service `basePrice`, `currency`, `priceUpdatedAt`. `GET /services` filters by `minPrice/maxPrice`. | `marketplace/marketplace.presenter.ts:155-160, 296-332` | f02, w30 and w33 have honest price and status data. |
| F12 | `ConversationEventType` = `QUOTE_REQUEST_CREATED/CANCELLED/REJECTED`, `QUOTE_OFFER_RECEIVED/REJECTED/ACCEPTED`. No revise, withdraw or expire events. | `prisma/schema/messaging.prisma:6-13` | f06 shows offer cards without versions. |
| F13 | `BookingStatus` = `REQUESTED, CONFIRMED, DECLINED, CANCELLED`, with `declinedAt`, `cancelledAt`, `cancelledBy` and the party's `note`. | `prisma/schema/marketplace.prisma:36-41`; `bookings.service.ts:472-473` | w34 can show the provider's own decline note as the reason. |
| F14 | Contributor scoping (INV §4.5): a non-owner, non-partner member sees only tasks, guests and costs they created or were assigned. Money summary totals are limited to their own contributions. | INV §4.5 | Participant task screens work. Participant money and guest totals do not (q06, y10 in B). |
| F15 | f10 to f14 (`prov_side.dart`) are not in any api_map. They show named units (هالة كبرى / صغرى, cars «باقي 4 من 6»), a deposit list confirmed by the provider («أكّدوا الاستلام / قالوا ما وصلت»), a night held for the customer «لين السبت 10 الليل», live team status «في الطريق / وصلوا 7:40», and a photo delivery checklist. None of these exist in the backend. | `mobile/test/prototype/v3/prov_side.dart:45-210` | All five are in B. |

---

## A. Buildable now

### A.1 Start, onboarding, sign-in (20 screens)

| id | Title | Phase | Map | Endpoints used | Drop or defer to stay honest | Depends on |
|---|---|---|---|---|---|---|
| a01_splash | شاشة البداية | V1 | 🔧→A | `POST /auth/refresh`, `GET /me`, `GET /contexts` | Drop the "deletion pending" route (w06 is B). The PIN check is local. | a02, home (b01/b02), w07 |
| a02_who | أهلًا فيك | V1 | 📱 | none | Main button reads «التالي», not «أنشئ حسابي» (C52). «مزود خدمة» is out of this journey. | a02b, a10, x04/q01 |
| a02b_whose | خطة مين؟ | V1 | 📱 | none (the choice is kept in the local draft and later sent as the existing `persona` field) | — | a03 |
| a03_name | اسمك | V1 | 🔧→A | name goes to `POST /auth/register`; plan `title` («عرس محمد وسلمى») is built on the client and sent as `title` | The partner name is not stored as its own field. It lives only inside the title. | a08b |
| a04_date | متى العرس؟ | V1 | 🔧→A | `weddingDate` in `POST /onboarding/import-local`; Hijri and the Ramadan warning on the client | Defer "month only". A month tap must lead to a day pick or to «ما حددنا» (no date, F10). | x01 |
| a05_city | المدينة | V1 | ✅ | `GET /cities`; `city` text in import-local | Governorate and district later (map A L14). | w10 |
| a07_budget | ميزانية عرسك | V1 | 🔧→A | `estimatedBudget` in import-local | Replace the range buttons with a typed number. Never store a band midpoint. Drop «ما أدري، ساعدني أحسبها» (dead end, map A L10). The line «المهر محسوب لحاله» waits for C1. | C1 |
| a08_ready | خطتك جاهزة | V1 | 🔧→A | `GET /catalogs/bootstrap` (`money.starter.categories`, `tasks.starter`) | Drop «3 مناسبات» (events are B) and the mahr summary (a06 is B). Show the real catalog counts: 20 tasks for a groom today (C6). | a03 to a07 |
| a08b_register | احفظ خطتك | new | ✅ | `POST /auth/register` | Password minimum 6, not 8 (C7). | a09 |
| a09_otp | رمز واتساب | V1 | 🔧→A | `POST /auth/register/complete`, then `POST /onboarding/import-local` with today's fields (title, city, weddingDate, estimatedBudget, persona, selectedCategories, costs[], tasks[], guests[]) | Defer the new plan fields (partnerName, dateMode, mahr, budgetBand, residence). `409 ACCOUNT_ALREADY_EXISTS` goes to w02. | a08b, w02, w09 |
| a10_login | تسجيل الدخول | V1 | ✅ | `POST /auth/login`; `POST /auth/otp/request` + `POST /auth/otp/verify` (purpose LOGIN) | — | w01, w09 |
| w01_forgot_password | نسيت كلمة المرور | new | 🔧→A | `POST /auth/password-reset/request`, `POST /auth/password-reset/confirm`, then `POST /auth/login` with the new password | No separate verify step exists, so «الرمز» and «كلمة جديدة» are submitted together and a wrong code shows after submit. Confirm returns no tokens and signs out every device, this one included; the app then signs in again with the new password. | a10 |
| w02_register_errors | أخطاء التسجيل | new | 🔧→A | `409 ACCOUNT_ALREADY_EXISTS` from `/auth/register/complete`; password length checked on the client (min 6) | Show «هذا الرقم عليه حساب» **after** the OTP, not on the form (C49). «ادخل» opens a10 with the phone filled in (there is no login grant). | a09, a10 |
| w03_whatsapp_missing | الرمز ما وصل | new | 🔧→A | `POST /auth/otp/request` (resend; quota 1 a minute) | Drop «بعد 5 محاولات وقفة 15 دقيقة»: no lockout across codes exists. | a09, a10 |
| x17_otp_wrong | الرمز غلط | V1 | 🔧→A | errors of `/auth/otp/verify` and `/auth/register/complete` | Drop the «باقي لك محاولتين» counter (the error body has no `attemptsRemaining`). Show a plain «الرمز غلط». No SMS line (WhatsApp only). | a09 |
| x18_session_expired | ادخل مرة ثانية | V1 | ✅ | `POST /auth/otp/request` + `/auth/otp/verify` (LOGIN) | Replaying the offline queue after a new login needs C58. Until then say the changes are kept and sent only if the same account signs in. | w41, C58 |
| w07_pin_entry | رمز القفل | new | 📱 | none (PIN hash in the device keystore); «نسيت الرمز؟» uses `/auth/login` or OTP LOGIN | — | g08 |
| w08_pin_wrong | الرمز غلط (القفل) | new | 📱 | same as w07 | — | w07 |
| g08_lock | قفل التطبيق | V1 | 📱 | none | Must be redrawn as the lock **settings** (on/off, set PIN, confirm, fingerprint), since no setup screen exists (C50). | w07, g02 |
| w09_local_draft | خطة على الجوال وخطة في الحساب | new | 🔧→A | `POST /onboarding/import-local` (always a new plan) | Drop «ضمّها لخطتي» (no merge mode). Keep «خلّها خطة ثانية» (subject to C5) and «تجاهلها» (local only, double confirmation, C62). | a10, a09 |

### A.2 Home and shell (11 screens)

| id | Title | Phase | Map | Endpoints used | Drop or defer to stay honest | Depends on |
|---|---|---|---|---|---|---|
| b01_home_fresh | البداية | V1 | 🔧→A | `GET P/dashboard-summary`, `GET P/money-summary` (budget), `GET P/guests/summary`, `GET /me/wedding-plans/:id/bookings`, `GET P/costs` (venue) | Steps are worked out on the client. Drop the mahr step (a06 is B), so the hero reads «ثلاث خطوات». The venue step needs a done rule (C24). | a07, f01, e01, C24 |
| b02_home_active | التجهيز | V1 | 🔧→A | `GET P/dashboard-summary` (budget/paid/outstanding totals, nextBestActions, task, guest and provider summaries), `GET P/money-summary` (owner funding), `GET P/payment-schedules/due` | Drop the agreement line (mahr), «حط 450 ألف كل شهر», the «ليش» why-line unless the server action carries one, the providers denominator «من 6» (C25), «ذكّرني» (no generic reminder) and the quick-entry box (b03 is B). The money tile follows C2. | c01, c06, d01, e01, f01 |
| b07_home_after | بعد العرس | V1 | 🔧→A | `GET P/money-summary` (`funding.loanOutstanding`, `nextLoanRepayment`, `costs.outstanding`), `GET /me/wedding-plans/:id/bookings` (completed, for rating) | The client picks the after-wedding stage from the date (today's rule). Drop the rafd card, «اشكرهم», the reciprocal line, «كتاب عرسك» and «تخلص منها في يونيو». The debt figure needs a definition (C12). | c13, g04, C12 |
| b08_notifications | التنبيهات | V1 | 🔧→A | `GET /notifications`, `PATCH /notifications/read-all`, `PATCH /notifications/:id/read` | Only the existing types (offer, task, payment, booking, countdown, guest replied). Drop «صالح خلّص مهمتين» and the Friday digest card. Lead-time wording follows C60. | g07 |
| b09_widget | ودجت الجوال | 1.1 | 📱 | cached `GET P/dashboard-summary` | No amounts or names on the widget. | b02 |
| b10_dark | الوضع الليلي | 1.1 | 📱 | same as home | — | b02 |
| b11_assistant | اسأل اعّرست | 1.1 | 🔧→A | `GET P/assistant`, `POST P/assistant/questions` (consent sent per question) | Drop the «عرسان صنعاء على اعّرست» range: market facts are provider list prices, not couple spend (C22). The remaining count comes from the server's `dailyLimit` (10 today, design says 30). Owner only. | w36, w37 |
| b14_loading | يحمّل | V1 | 📱 | none | — | — |
| b15_error | ما قدرنا | V1 | 📱 | none (stable error codes already exist) | — | w41 |
| x01_home_no_date | الموعد لسا ما ثبت | V1 | 🔧→A | `GET P/dashboard-summary`, `GET P/tasks` (plan with `weddingDate` null) | Drop «اختر تقريبًا» (x02 is B); keep «ثبت الموعد» → w10. «خطواتك بالترتيب» lists open tasks without dates in creation order (no `sequence` field exists). | w10, d03 |
| y09_moment_booked | محجوزة ليلتك | V1 | 🔧→A | `BOOKING_UPDATED` notification, `GET /me/wedding-plans/:id/bookings`; «سجّل العربون» → `POST /payment-schedules/:id/pay` or c06 | Drop «صار محجوز 4 من 6» (no needed-providers list, C25). The moment is shown once per device (no server acknowledgement). | f05, c06 |

### A.3 Money (21 screens)

| id | Title | Phase | Map | Endpoints used | Drop or defer to stay honest | Depends on |
|---|---|---|---|---|---|---|
| c01_money_summary | الملخص | V1 | 🔧→A | `GET P/money-summary` | Show `costs.total` («اتفقت على»), `costs.paid`, `costs.outstanding`, `budget.total/allocated/unallocated`; for the owner also `funding.received`, `pledged`, `availableCash` («معك»), and the server `shortfall` labelled with its real meaning («ومع الموعود ناقصك»). Defer «ناقصك» without pledges, the two sections «الاتفاق مع أهل العروسة / عرسك», the four-part bar and «كيف تقفل الناقص؟» until C1 and C2 are decided. Do not recompute the gap on the client (map B §0.1). | C1, C2 |
| c02_money_items | البنود | V1 | 🔧→A | `GET P/budget-categories`, `GET P/costs`, `GET P/payment-schedules/due` | One list (no AGREEMENT/WEDDING split). Item status (خالص / جزء / ما دفعت) from cost totals. Drop «عرضين وصلوا» and the gram unit. «الذهب، إذا كان عليك» stays a plain suggestion (C20). | c07, c09 |
| c03_money_payments | الدفعات | V1 | 🔧→A | `GET P/payment-schedules/due` (overdue + next 30 days, F4), `POST /payment-schedules/:id/pay` | Rows after 30 days are not shown. Swipe records the payment with no funding source. The mahr remainder row is absent (a06 is B). | c06, C17 |
| c04_money_offline | بدون نت | V1 | 📱 | replay of `POST /payment-schedules/:id/pay` with `X-Client-Request-Id` | A paid row waiting to send must leave «قادمة» and the window total (C17). | c03, w41 |
| c05_money_funding | من وين | V1 | 🔧→A | `GET P/funding-sources` (owner), `GET P/money-summary` (`funding.received`, `pledged`, `availableCash`) | Totals summed on the client. Drop «صرفت» per source (payments have no source) and the rafd note. Non-owners see a locked state (the API returns `[]`). | c12, c13, x08 |
| c06_pay_sheet | تسجيل دفعة | V1 | 🔧→A | `POST /costs/:id/payments` {amount, paidAt, method, note} or `POST /payment-schedules/:id/pay`; receipt: `POST /media/uploads/presign` → `/verify` → `POST /costs/:costId/receipts` {attachmentRef, costPaymentId} | Drop «من وين» (no funding link on a payment), the $ and ر.س chips (plan currency only) and the per-payment «خاصة بي» (C18). | c03, c07 |
| c07_item_detail | تفاصيل البند | V1 | 🔧→A | `GET /costs/:id`, `GET /costs/:id/payments`, `GET /costs/:id/payment-schedules`, `GET /costs/:costId/receipts`, `GET /quote-requests/:id/conversation` | Drop «150 مقعد» (no capacity field). «يوم العرس» shows as the date (no event-relative schedule). | c06, c11, x15, w23 |
| c09_add_item | بند جديد | V1 | 🔧→A | `POST P/budget-categories` {name, allocatedAmount} | Drop the gram unit and karat, the foreign-currency units and the section. Over budget: the 422 is shown with the w18 wording. | c02, w18, C20 |
| c10_add_cost | اتفاق جديد | V1 | 🔧→A | `POST P/costs` {budgetCategoryId, title, totalAmount, initialPaymentAmount, providerId?, quoteOfferId?, partyName?}, then `POST /costs/:id/payment-schedules` for each line | Not atomic: the client retries each call with `X-Client-Request-Id`. «الباقي يوم العرس» is saved as the fixed wedding date (C3). | c07, f04 |
| c11_payment_detail | تفاصيل دفعة | V1 | 🔧→A | `GET /cost-payments/:id`, `POST /cost-payments/:id/reverse` | Drop «من وين» and «سجّلها أنت» (no source or actor on a payment). | x14 |
| c12_add_source | مصدر فلوس | V1 | 🔧→A | `POST P/funding-sources` {kind, sourceName, amount, status, receivedAt}, then `POST /funding-sources/:id/repayments` per instalment | Drop the pledge's expected date. Instalments are created one by one (not atomic). Sample dates follow C12. | c05, c13 |
| c13_loan | السلفة | V1 | 🔧→A | `GET P/funding-sources` (repayments inside), `PATCH /loan-repayments/:id` {status: PAID, paidAt} | Drop the «ذكّرني قبل كل قسط بثلاثة أيام» toggle: loan reminders are a fixed cron and the lead time is not set per loan. | c12 |
| c14_share | شارك الملخص | 1.1 | 📱 | text built from `GET P/money-summary`, `GET P/costs`, `GET P/payment-schedules/due` | Never read `funding-sources`. «معنا 2.9» only for the owner. | c01 |
| x03_money_no_budget | بدون ميزانية | V1 | 🔧→A | `GET P/money-summary` (budget null); «حط رقم» → `PUT P/money-budget` {totalBudget} | Drop «ساعدني أقدّر» and the Sanaa peer range (no couple-spend data, C22). | c01, w10 |
| x08_pledge_check | وصلت فلوس عادل؟ | V1 | 🔧→A | `PATCH /funding-sources/:id` {status: RECEIVED, receivedAt}; «ما بتوصل» = `DELETE /funding-sources/:id`; «لسا» closes the sheet | Drop «وصل جزء» (no partial receipt). Fix the «ويزيد الناقص» line (C2). For a loan pledge, open the c12 repayment step afterwards so it is not a dead end. | c05, c12, C2 |
| x14_payment_reversed | دفعة انعكست | V1 | 🔧→A | `POST /cost-payments/:id/reverse` {reason}, `GET /cost-payments/:id` | Drop «مين · أنت» and «رجعت 100 ألف لمدخراتك» (no actor or source stored). «سجّلها على التصوير» = a new payment on the other item through c06, after the reversal. | c11, c06 |
| x15_cancel_item | شيل بند | V1 | 🔧→A | `GET P/costs?categoryId=`, `PATCH /budget-categories/:id` {allocatedAmount: 0}, `DELETE /budget-categories/:id` | Delete is a hard delete, so «يبقى في السجل» becomes «ينحذف البند». Drop «مهمة … تنلغي» (no task link). Fix «ميزانيتك تخف» (C15). | c07, w23, C15 |
| w18_category_over | البند زاد | new | 🔧→A | `GET P/money-summary` (warning `CATEGORY_EXCEEDED`, `budget.unallocated` = reserve), `PATCH /budget-categories/:id` or `PUT P/money-budget` | Drop the cause line «زاد عدد الضيوف». «خلّها كذا» changes nothing and the warning stays. | c02, w19 |
| w19_allocate | توزيع الميزانية | new | 🔧→A | `PUT P/money-budget` {totalBudget, categories[]}; reserve = `budget.unallocated` | Remove the «المهر والشبكة» row and align the sample amounts with c02 (C1). | C1 |
| w22_receipts | الإيصالات | new | 🔧→A | `GET P/cost-payments`, `GET /costs/:costId/receipts` per cost, `POST` / `DELETE /costs/:costId/receipts` | Coverage («9 من 12») is counted on the client from one call per cost. Replace = attach the new one, then delete the old. | c06, c07 |
| w23_item_locked | ما ينحذف | new | 🔧→A | `DELETE /costs/:id` (refused when payments or receipts exist), `POST /costs/:id/cancel`, `POST /cost-payments/:id/reverse` | Drop «بدّل المصور · الدفعة تنتقل للمصور الجديد» (wrong in accounting, map B issue 31). | c07, x14 |

### A.4 Tasks (10 screens)

| id | Title | Phase | Map | Endpoints used | Drop or defer to stay honest | Depends on |
|---|---|---|---|---|---|---|
| d01_tasks | المهام | V1 | 🔧→A | `GET P/tasks`, `GET P/tasks/summary`, `PATCH /tasks/:id` {status: DONE} | Filter chips and week groups on the client (the owner sees every task). Drop the deep-link chips and the amounts in row meta (tasks have no link or amount). The counter uses the real total (C6). | d02, d04, d03 |
| d02_add_task | مهمة جديدة | V1 | 🔧→A | `POST P/tasks` {title, dueDate, responsibleName/Phone}, then `PATCH /tasks/:id/assign` | «هذا الأسبوع / هذا الشهر» become a date; drop «بعد العصر» (no time of day). The assignee must hold the tasks flag (C28). «شخص ثاني» = `responsibleName/Phone`. | d01, g01, C28 |
| d03_starter | مهام جاهزة | V1 | ➕ in map C, **✅ here (F1)** | `GET /catalogs/bootstrap` (`tasks.starter`), `POST P/tasks` per chosen item (or `tasks[]` in import-local during onboarding) | Drop the anchors «قبل العقد / قبل السمرة». Groups by `daysBefore`. The button shows the real count (C6). | a08, d01, C6 |
| d04_task_detail | تفاصيل مهمة | V1 | 🔧→A | `GET /tasks/:id` (checklist, `responsibleName/Phone/Source`), `POST/PATCH/DELETE /tasks/:id/checklist[/:itemId]`, `PATCH /tasks/:id` (dueDate for «أجّلها», status) | Drop the mahr link and the related-task card. The contact is the task's responsible person (call and `wa.me`). | d05, x16 |
| d05_contract_papers | أوراق العقد | V1 | 🔧→A | checklist endpoints (as d04) | Drop the «عليك / عند أهل العروسة» split, the witness picker and the mahr amounts. It ships as a titled checklist. | d04 |
| x16_task_menu | خيارات المهمة | V1 | 🔧→A | `PATCH /tasks/:id/assign`, `PATCH /tasks/:id` {dueDate, status: TODO \| CANCELLED} | Free-text time («بعد العصر») is dropped. Moving a task to a view-only member fails today (C28). | d01, C28 |
| w24_timeline | المهام على الوقت | new | 📱 | `GET P/tasks` grouped by month on the client | — | d01 |
| w25_private_task | مهمة خاصة | new | ✅ (owner) | `POST P/tasks` {isPrivate: true} | Owner only. | d02 |
| w26_overdue | المتأخرة | new | 🔧→A | `GET P/tasks` (overdue days on the client), `PATCH /tasks/:id` {dueDate} | Drop «نبلّغك بس إذا مهمة متأخرة توقف شيء ثاني»: the cron notifies every overdue task (C39). | d01 |
| y14_fireworks_task | الألعاب النارية | V1 | ✅ | tasks endpoints (title, responsible, due date) | Drop «150 ألف» from the task (no money link). | d02 |

### A.5 Guests (12 screens)

| id | Title | Phase | Map | Endpoints used | Drop or defer to stay honest | Depends on |
|---|---|---|---|---|---|---|
| e01_guests_men | الضيوف | V1 | 🔧→A | `GET P/guests/summary`, `GET P/guest-groups`, `GET P/guests` | Drop «قاعة سبأ تتسع 150 · باقي 26 مقعد» (no capacity source, C33) and «يرسل لهم الوالد». «ذكّر الـ 20» opens e08. | e06, e08, w27 |
| e03_contacts | من جهات الاتصال | V1 | 🔧→A | device contacts; `POST P/guest-groups`, then `POST P/guests/bulk` {items[]} | The server skips duplicate phones silently, so «موجود من قبل» is marked on the client against the loaded list. | e01 |
| e04_invite | بطاقة الدعوة | V1 | ➕ in map C, A with deferral | `POST /guests/:id/invitation-link` per guest; sent from the owner's phone through `wa.me`, one guest after another | Card text is built on the client; «يتشرف عبدالرحمن الحمدي» is card text only (C29). «أرسلها لـ 124 ضيف» becomes a step-through sender «التالي 3 من 124» (C30). | e01, e05, C29, C30 |
| e05_rsvp | صفحة الضيف | V1 | 🔧→A | PUB `GET` / `POST /public/rsvp/:token`; existing page `deploy/public-site/rsvp.*` | Drop the host line «عبدالرحمن الحمدي يدعوك» and «بعد العصر» (not in the payload). Hijri is computed in the page. | e04 |
| e06_add_guest | ضيف جديد | V1 | 🔧→A | `POST P/guests`, `POST P/guest-groups` (inline «جديدة» = two calls) | `409` duplicate phone shows the existing guest by name from the loaded list. | e01 |
| e07_guest_detail | تفاصيل ضيف | V1 | 🔧→A | `GET /guests/:id` (`invitationStatus`, `attendanceStatus`, companions) | Drop the dated timeline (sent / opened / answered) and the rafd block. | e01 |
| e08_reminder | تذكير اللي ما ردوا | V1 | ➕ in map C, A with deferral | `POST /guests/:id/invitation-link` per pending guest (a new link) + `wa.me` step-through | The old link stops working when a new one is minted, so the message says «هذا رابطك الجديد» (C31). Drop «الوالد يرسلها» (C29). | e04, C30, C31 |
| x21_guests_empty | الضيوف أول مرة | V1 | ➕ in map C, A with deferral | none (opens e03 or e06) | Drop «عدد تقريبي بس» (no estimate field). | e03, e06 |
| w27_guest_groups | المجموعات | new | 🔧→A | `GET` / `POST P/guest-groups`, `PATCH` / `DELETE /guest-groups/:id` (guests move to «بدون مجموعة», FK SetNull) | Drop the side tabs «أهلنا / أهل العروسة» (map C L-C20). Counts from the guest list. | e01 |
| w28_bulk_guests | أضف مجموعة | new | 🔧→A | lines parsed on the client, `POST P/guests/bulk` | Duplicates marked on the client. | e03 |
| w29_guests_offline | الضيوف بدون نت | new | 📱 | cache of `GET P/guests` | «آخر تحديث» = time of the last good fetch. Adds wait for the network (as drawn). | e01 |
| w38_not_enough_data | ما نخمّن | new | 🔧→A | `GET P/guests/summary` | Shows the real counts only. There is no forecast endpoint, so this is the only state. | e01, e08 |

### A.6 Providers, customer side (22 screens)

| id | Title | Phase | Map | Endpoints used | Drop or defer to stay honest | Depends on |
|---|---|---|---|---|---|---|
| f01_prov_requests | طلباتي | V1 | 🔧→A | `GET P/quote-requests`, `GET /me/wedding-plans/:id/bookings`, `GET P/costs` (outside bookings = a cost with a party name and no provider) | Board built on the client. Drop the denominator «من 6» (C25). | f07, f05, x22 |
| f02_prov_explore | استكشف | V1 | 🔧→A | `GET /provider-categories`, `GET /providers?categoryId&cityId&search&page` (F11) | Drop «فاضية 21 يناير». «ضمن بندك» only when the price and the item share a currency (client compare with the owner's allocation). | f03, w30 |
| f03_prov_page | صفحة المزود | V1 | 🔧→A | `GET /providers/:id` (with responsiveness), `/providers/:id/services`, `/packages`, `/reviews`, `POST /providers/:id/views`, `POST` / `DELETE /providers/:id/favorite` | Drop «عرسان دفعوا فعلًا · من 11 عرس» and «فاضي 21 يناير». | f07, f09 |
| f04_compare | قارن العروض | V1 | 🔧→A | `GET P/quote-requests` (offers: amount, currency, title, message, validUntil), `PATCH /quote-offers/:id/accept`, then `POST /me/quote-requests/:id/booking` | Offers have no structured lines, so the compare shows the offer text side by side. Drop «أنسب لك». Accept and booking are two calls (C44). | f06, f05, c10 |
| f05_book_sheet | طلب الحجز | V1 | 🔧→A | `POST /me/quote-requests/:id/booking` {eventDate, note} | The time slot goes in the note. | f04, w34 |
| f06_chat | المحادثة | V1 | 🔧→A | `GET /conversations/:id/timeline`, `POST /conversations/:id/messages`, `PATCH /conversations/:id/read`, `GET /quote-requests/:id` | The offer card comes from the `QUOTE_OFFER_RECEIVED` event (F12). «ينتهي بعد 6 أيام» only when `validUntil` is set. No versions. | f04, w32 |
| f07_quote | اطلب عرض سعر | V1 | 🔧→A | `POST P/quote-requests` {providerId, serviceId, eventDate, location, cityId, guestCount?, message} | Send `budgetMin/Max` only when the toggle is on (F8). Send `guestCount` only for halls and catering (C45). The phone is always shared (C46). | f03 |
| f08_chats | المحادثات | V1 | 🔧→A | `GET /conversations` | Drop the latest offer amount unless the last message or `latestQuoteRequest` carries it. | f06 |
| f09_favorites | المفضلة | V1 | ✅ | `GET /me/favorite-providers`, `POST` / `DELETE /providers/:id/favorite` | Rename «قارن الاثنين» to «قارن الملفين» (C47). | f03 |
| g04_rate | قيّم مزودينك | V1 | 🔧→A | `GET /me/wedding-plans/:id/bookings` (completed), `GET P/costs` (paid per provider), `POST /providers/:id/reviews` {rating, comment} | Drop the quick tags. One review per provider (not per booking). | w35, x12 |
| x09_prov_hard | المزود اعتذر | V1 | ➕ in map D, A with deferral | `GET P/quote-requests` (VIEWED = «شاف وما رد»; REJECTED with no offer = the provider declined), `GET /providers?categoryId&cityId` for alternatives, chat via f06 | Keep the «اعتذر» and «شاف وما رد» variants. Drop «فاضيين يومك» on alternatives, the suspended-provider banner, «سحب عرضه» and «ذكّره». | f01, f06 |
| x10_reject_offer | اعتذر بأدب | V1 | 🔧→A | `POST /conversations/:id/messages` (the polite text), then `PATCH /quote-offers/:id/reject` | The reason chips only pick the message template; the reason is not stored. | f06 |
| x11_cancel_booking | إلغاء حجز | V1 | 🔧→A | `PATCH /me/bookings/:id/cancel` {note}; preview from `GET P/costs`, `GET /costs/:id/payment-schedules`, `GET /costs/:id/payments`; then `POST /payment-schedules/:id/cancel`, `POST /costs/:id/cancel`, and `POST /cost-payments/:id/reverse` for «رجّعوه كله» | Drop «رجّعوا جزء» (w21 is B) and the task cancellation. The steps are separate calls (not atomic). | w34, c07 |
| x12_rate_sent | وصل تقييمك | V1 | 🔧→A | response of `POST /providers/:id/reviews` | Copy must say it is published now and hidden only if it breaks the rules (C40). | g04 |
| x22_providers_empty | المزودين أول مرة | V1 | 🔧→A | `GET /providers?categoryId=<hall>&cityId`; «حجزت برا اعّرست» → `POST P/costs` {partyName, …} | Drop «فاضية يوم عرسك». | f02, c10 |
| y13_decor_providers | زينة البيت | V1 | 🔧→A | `GET /providers?categoryId=<decor>` | Needs the category «زينة البيت» created through the existing admin category route (data, not code). Drop «فاضي يوم 17» (no day-range availability). | f02 |
| w30_directory_filters | فلتر المزودين | new | 🔧→A | `GET /providers?categoryId&cityId&search` (with `total`), `GET /services?minPrice&maxPrice&categoryId&cityId` | Drop «يجون من محافظة ثانية» and «فاضي يوم 21 يناير بس». | f02 |
| w31_offer_expired | العرض انتهى | new | 🔧→A | offer `validUntil` / expiry; «اطلب عرض جديد» = `POST P/quote-requests` (allowed after expiry, F7) | Drop «ما أبغاه، سكّر الطلب» (no close transition, map D L6). | f06, f07 |
| w32_chat_menu | خيارات المحادثة | new | 🔧→A | `PATCH /conversations/:id/mute`, `PATCH /conversations/:id/block`, `POST /conversations/:id/report` {reason as text} | Drop «وطلباتك معه تتسكر». Keep «الحظر ما يلغي الحجز المؤكد». | f06 |
| w33_provider_status | حالة المزود | new | 🔧→A | `GET /providers`, `GET /providers/:id` (`verifiedAt`, `isClaimed`, `priceUpdatedAt`) | Plain «موثّق» without the method. For an unclaimed listing, replace «تقدر تطلب عرض» with «ما يستقبل طلبات لين يستلم ملفه» (`409 PROVIDER_NOT_CLAIMED`). | f02, f03 |
| w34_booking_states | الحجوزات | new | 🔧→A | `GET /me/wedding-plans/:id/bookings` (status, declinedAt, cancelledAt, cancelledBy, note, F13); «اطلب حجز مرة ثانية» = `POST /me/quote-requests/:id/booking` | The provider's note is shown as the decline reason. Drop «ذكّرهم» and any expiry. | f05, x11 |
| w35_rate_locked | التقييم بعد العرس | new | 🔧→A | `403 REVIEW_REQUIRES_COMPLETED_BOOKING`; date from the booking | Drop the server reminder «نذكّرك يوم 22 يناير», or schedule it as a device-local notification. | g04 |

### A.7 Account, settings, plan, participants seen by the owner (17 screens)

| id | Title | Phase | Map | Endpoints used | Drop or defer to stay honest | Depends on |
|---|---|---|---|---|---|---|
| g01_family | المشاركين | V1 | 🔧→A | `GET P/members` (role + flags), `GET P/invites` | The summary line is built from the stored flags. Presets map to today's roles (C63). Drop «ويكتب الرفد». | g06, x07, C63 |
| g02_account | حسابي | V1 | ✅ | `GET /me`, `PATCH /users/me`, `GET P/members`; look, Hijri, digits, data saver and «أخفِ المبالغ» on the device | Menu entries to section B screens stay hidden until they ship; add the missing groups (C51). | g07, g08, g09, g10, g11, w10, w11 |
| g03_postpone | تأجيل العرس | V1 | ➕ in map A, A with deferral | preview on the client from `GET P/tasks`, `GET /me/wedding-plans/:id/bookings`, `GET P/payment-schedules/due`; apply = `PATCH P` {weddingDate} + `POST P/tasks/shift-due-dates` {days} | Drop «الحجوزات نطلب لها اليوم الجديد»: say «كلّم المزودين على اليوم الجديد» with links to their chats. Drop the guest notice. Two calls, not atomic. Payment wording follows C3. | w10, f06, C3 |
| g06_add_participant | أضف مشارك | V1 | 🔧→A | `POST P/invites` {name, phone, role, can* flags, expiresInDays: 7} (WhatsApp delivery and `deliveryStatus` exist) | Levels are «لا / يعدّل» for tasks, guests and providers, «لا / يشوف / يعدّل» for money. Drop the rafd row and the «العروسة» preset (C63). | g01, C27, C63 |
| g07_notif | التنبيهات (الإعدادات) | V1 | 🔧→A | `GET` / `PATCH /users/me/settings` (task, payment and provider reminders; channels) | Drop the quiet hours, «ملخص الجمعة», guest-reply batching, participant activity, and the «قبل بثلاثة أيام» timing (C60). | b08 |
| g09_change_phone | تغيير الرقم | 1.1 | 🔧→A | `POST /auth/phone-change/request`, `POST /auth/phone-change/confirm`, then sign in again | Confirm signs out every device, this one too; copy «بنطلعك من كل الأجهزة وتدخل من جديد». | g02 |
| g10_support | المساعدة | V1 | 📱 | static public site, WhatsApp link | — | g02 |
| g11_logout | الخروج | V1 | 🔧→A | `POST /auth/logout`, `DELETE /push/installations/current` | Hide «احذف حسابي نهائيًا» until w05 ships (C4). Warn when unsent changes exist (C59). | w41, C4 |
| w10_edit_plan | بيانات الخطة | new | 🔧→A | `PATCH P` {title, city, location, weddingDate}, `PUT P/money-budget` {totalBudget} | Drop «موعد تقريبي» and «ما حددنا» once a date exists (cannot clear), «المحافظة والمديرية» and the currency. A date change goes through g03. | g03, x01 |
| w11_plan_switcher | خططك | new | 🔧→A | `GET /contexts`, `POST P/set-active`, `POST /wedding-plans` | Archived plans are listed but cannot be opened (`set-active` refuses them). The rule «خطة واحدة مفتوحة» waits for C5. | C5 |
| w36_ai_consent | تشغيل المساعد | new | 🔧→A | `GET P/assistant`; consent kept on the device and sent as `consent: true` | «30 طلب في اليوم» becomes the server's `dailyLimit`. Account-level consent comes later. | b11 |
| w37_ai_limit | لما المساعد ما يقدر | new | 🔧→A | `429 ASSISTANT_DAILY_LIMIT`; offline detected on the client | Drop «ما قدرت أقرأ الفاتورة» (no receipt reading) and «ما فهمت قصدك» (no entry drafts). | b11 |
| w39_push_off | التنبيهات مقفلة | new | 📱 | none (`PUT /push/installations/current` optional) | — | g07 |
| w41_pending_queue | تنتظر النت | new | 📱 | replays with `X-Client-Request-Id` | Drop the conflict row «صالح عدّله قبلك · حل»: entities have no version, so conflicts cannot be detected. | c04, x18 |
| w42_section_states | حالات كل قائمة | new | 📱 | none | — | all lists |
| x07_participant_states | مين معك ومين لسا | V1 | 🔧→A | `GET P/members`, `GET P/invites` (deliveryStatus), `POST P/invites/:inviteId/reissue` (copy link), `DELETE P/invites/:inviteId` | Drop «ما فتحها» (no `openedAt`) and the «طلعوا» section. «ذكّره» and «انسخ الرابط» make a new link and say the old one stops (C31). | g01, g06, C31 |
| x20_activity | وش صار | V1 | 🔧→A | `GET P/contributions?section=` | Owner actions are not recorded, so the title becomes «وش سوّى المشاركين» and the «أنت» rows and «انضمت للخطة» are dropped. | g01 |

### A.8 Participant journey, buildable now (15 screens)

These run under today's contributor scoping (F14): a member sees the tasks they created or were given.

| id | Title | Map | Endpoints used | Drop or defer to stay honest | Depends on |
|---|---|---|---|---|---|
| x04_from_family | من الأهل | 📱 | clipboard check; a prefilled `wa.me` message to the groom | — | q01 |
| q01_invite_phone | دعوة: رقم الهاتف | 🔧→A | PUB `POST /invites/:token/request-otp` | Drop the inviter header «محمد يبغاك معه … الخميس 21 يناير» (needs the public preview, x05 is B). | q02 |
| q02_invite_account | دعوة: الحساب | ✅ | PUB `POST /invites/:token/verify-otp` {phone, code, name, password} | Password min 6 (C7). | q03 |
| q03_invite_decision | دعوة: القرار | 🔧→A | `GET /invites/:token` (role + flags), `POST /invites/:token/accept`, `POST /invites/:token/decline` | Rights list built from flags; the tasks wording follows C27. | q04 |
| q04_choose_path | اختر المسار | 🔧→A | `GET /contexts` (role, displayName, persona, lifecycle) | Drop the relation «أخوك / بنت عمك». Rafd-writer label waits for rafd (B). | x06 |
| x06_helper_home | رئيسية المساعد | 🔧→A | `GET /dashboard/home`, `GET P/tasks` (own and assigned), `PATCH /tasks/:id` {status: DONE} | Drop «عرس أخوك» (no relation), the task reason «لأن …», and «اطلب من محمد يفتح لك» (q13 is B). No money anywhere. | q05 |
| q05_tasks_mine | المهام (لي) | 🔧→A | `GET P/tasks` (contributor scope) | Drop «كل مهام الخطة» (a member cannot read others' tasks). | x06 |
| q07_money_locked | المال: مقفل | 📱 | `GET /contexts` or `GET P/permissions/me` | Drop «اطلب من محمد» (q13 is B); a calm lock only. | — |
| q08_providers_locked | المزودين: مقفل | 📱 | as q07 | Drop «تشوف مواعيدهم في البرنامج» (no schedule) and the request button. | — |
| q10_account_plans | حسابي (المشارك) | ✅ / 🔧 | `GET /contexts`, `GET P/contributions/summary?contributorUserId=me` | «اطلع من الخطة» is hidden until q11 ships. | q04 |
| q12_changed | تغيّرت صلاحياتك | 🔧→A | the client compares `membershipAuthorityVersion` and permissions from `GET /contexts` (or `GET P/permissions/me`) with its cache | The message is raised on the device (no `PERMISSION_CHANGED` notification). Drop the custody next step. | q04 |
| q17_bride_helper | مساعدة في عرس سلمى | 🔧→A | same as x06; theme from the context's persona BRIDE | Same drops as x06 («عرس أختك» needs the relation). | x06 |
| q18_wedding_day | يوم العرس (المشارك) | 🔧→A | `GET P/tasks` filtered on the client to today | Drop «برنامج اليوم» (no events) and time of day. | x06 |
| q19_plan_states | لما الخطة تتغير | 🔧→A | `GET /contexts` (`lifecycle` / `accessMode` READ_ONLY for an archived plan) | Only the «في الذكريات» variant. Paused, postponed and deleted need plan states (B). | q04 |
| q21_notifications | تنبيهاته | 🔧→A | `GET /notifications` (TASK_ASSIGNED, TASK_DUE_SOON, sharing types) | Drop the permission-changed and postponed rows. | x06 |

---

## B. Needs backend first

Contracts are summarised; the full shape is in the api_map section given. Size: **S** = one route or field on existing models; **M** = a new model or several routes in one module; **L** = a new domain, a cross-module change, or a migration with risk.

### B.1 Groom journey (48 screens)

| id | Title | Phase | Missing capability | Proposed contract (source) | Size |
|---|---|---|---|---|---|
| a06_mahr | المهر | V1 | No mahr model: total, delivered, remainder date, direction. | `mahr {status, totalAmount, settledAmount, remainderDueDate}` in onboarding/import-local; `GET/PUT P/mahr`; `MAHR_DUE_SOON` cron (map A §1.1, map B §0.2 AGREEMENT section). Depends on C1. | M |
| y01_where_are_you | في اليمن ولا برا؟ | 1.1 | No residence fields on the plan; the "ground helper" before an account exists. | `residence`, `residenceCountry` on the plan; helper held locally then `POST P/invites` (map A §1.1). | S |
| b03_quick_entry | اكتب وش صار | later | No text or voice to draft extraction. | `POST P/assistant/entry-drafts` (nothing saved) (map B §1). | L |
| b04_home_week | أسبوع العرس | V1 | No events, no week projection, no booking reconfirmation, no cash per night. | `GET P/home` stage WEEK, `PlanEvent`, `POST /bookings/:id/reconfirm-request` (map B §1, §8). | L |
| b05_home_day | يوم العرس | V1 | No program items, no rafd totals. | `GET P/home` stage DAY with program and rafd summary (map B §1). Needs b12 and b06. | L |
| b06_rafd | سجّل رفد | V1 | No rafd model, no offline batch. | `POST P/rafd`, `POST P/rafd/batch` with `clientId` (map B §1, §10). | M |
| b12_events | مناسبات عرسك | V1 | No event model (INV §0). | `GET/POST P/events`, seeded per plan type (map B §2, §8). | M |
| b13_event_edit | تعديل مناسبة | V1 | Same. | `PATCH/DELETE /events/:id`, time slots incl. «الظهر» (map B §2). Needs b12, C8. | S |
| y06_moment_week | دخلت أسبوع عرسك | V1 | Payload is events, providers reconfirmed, cash. | `home.moments` + `POST P/moments/:key/ack` (map B §5). Needs b04. | S |
| y07_moment_day | اليوم عرسك | V1 | Program and rafd writers. | Same moment mechanism (map B §5). Needs b05. | S |
| y08_moment_mahr | سلّمت المهر كامل | V1 | No mahr completion event. | `MAHR_COMPLETED` moment (map B §5). Needs a06. | S |
| y12_lights_home | أسبوع العرس بالأنوار | V1 | Events, program, decor banner. | `home.week` + `banners[DECOR_LIVE]` (map B §5). Needs b04. | M |
| x13_rafd_later | الرفد بعد العرس | 1.1 | Rafd reciprocals, writes on archived plans. | `GET P/rafd/reciprocals`, `POST /rafd/:id/return`, archive allow-list (map B §4, §7.5). Needs b06, w13. | M |
| c08_what_if | لو خففت… | 1.1 | No dry run; the server gap ignores allocations (F5), so a slider cannot change it honestly. | `PUT P/money-budget?dryRun=true` + the §0.1 formula (map B §3). Needs C2, C16. | M |
| w20_payer_filter | مين دفع | new | Payments do not record who paid. | `CostPayment.paidBy`, `GET P/cost-payments?paidBy=` (map B §6). Needs C19. | S |
| w21_partial_refund | رجع لك جزء | new | Only full reversal exists. | `POST /cost-payments/:id/refunds`, `CostRefund` (map B §6, §7.3). | M |
| y02_expat_home | رئيسية المغترب | 1.1 | Residence, FX, helper activity. | plan residence + `home.expat` (map B §5). Needs y01, y03. | L |
| y03_remit | حوالة لصالح | 1.1 | No FX rates, no custody. | `GET /exchange-rates`, `POST P/custody/handovers` (map B §5). | M |
| y04_custody | العهدة | 1.1 | No custody model. | `GET P/custody`, `/custody/mine`, settle (map B §5). | M |
| y05_hand_cash | سلّم كاش | 1.1 | Same, plus holder confirmation. | handovers, confirm, spends, `CUSTODY_HOLDER` (map B §5, §7.6). | M |
| z01_impact_chain | سلسلة التأثير | 1.1 | No impact record or undo. | `impact` on mutations, `/activities/:id/undo` (map B §6). | L |
| z02_weekly_digest | ملخص الجمعة | 1.1 | No digest job, no money snapshots. | `WeeklyDigest`, `MoneySnapshot`, `GET P/digests/latest` (map B §6). | M |
| z03_cashflow | المال شهر بشهر | 1.1 | No cash flow, pledge dates, deferral requests. | `GET P/money/cashflow`, `POST /payment-schedules/:id/deferral-requests` (map B §6). Needs the map B issue 5 samples fixed first. | L |
| z04_receipt_scan | صوّر الإيصال | later | No receipt reading. | `POST P/assistant/receipt-extractions` (map B §6). | L |
| z05_smart_tasks | مهام تجي لحالها | 1.1 | No task origin, dependencies or rebalance. | `origin`, `blockedBy`, `/tasks/suggestions/rebalance` (map C §1.1). | L |
| e09_rafd_book | دفتر الرفد | V1 | No rafd model. | `GET P/rafd` with summary for the owner (map B §6). Needs b06. | M |
| e10_thanks | رسالة الشكر | V1 | No thanks queue or marks. | `GET P/rafd/thanks-queue`, `POST P/rafd/thanks/mark-sent` (map B §6). Needs e09, C23. | S |
| z06_attendance | كم بيحضر فعلًا | 1.1 | No forecast or catering headcount. | `GET P/guests/attendance-forecast`, `PUT P/catering-headcount` (map C §1.2). | M |
| f10_pick_unit | قاعة سبأ: أي قاعة؟ | new | No named units or counted resources per day (F15). | `Resource`, `SlotLoad`, booking `resourceId/quantity`, availability per unit (map D §4.1, f05 row). | L |
| f11_deposits | الدفعات المقدمة | new | No deposit fact shared with the provider, no acknowledgement or dispute. | `DepositMovement` + `POST /me/deposits/:id/ack`, provider ack (map D §4.1, c06 row, p23). Needs the DECISIONS approval (C66). | L |
| f12_held | ماسكين لك الليلة | new | No provider holds. | `Hold` with `caseId`, expiry job, convert (map D p31). | M |
| f13_team_arrived | المزودين الليلة | new | No provider en-route or arrived status on the day. | New: booking day-status `{EN_ROUTE, ARRIVED, READY}` with time and contact, pushed to the customer. Not in any api_map; needs a provider-side screen too. | M |
| f14_delivery | سلّموا الصور | new | No deliverables checklist, delivery state or link. | `Booking` ORDER/delivery states (map D p26: ready, delivered, received) plus deliverable items from the offer lines. | M |
| g05_book | كتاب عرسك | later | No summary book or shareable template. | Out of the api_maps except the template rule (map D g05). | M |
| z07_agreement | اللي اتفقنا عليه | later | No agreement points or provider confirmation. | `GET /bookings/:id/agreement`, points, provider confirm (map D z07). AI extraction gated (C66). | L |
| w04_devices | الأجهزة | new | Refresh tokens carry no device data. | `AuthSession`; `GET /auth/sessions`, `DELETE /auth/sessions/:id`, `POST /auth/sessions/revoke-others` (map A §1.2). | M |
| w05_delete_account | حذف الحساب | new | Deletion is immediate; no grace, impact or notices. | `POST /users/me/deletion`, `GET /users/me/deletion/impact`, purge cron (map A §1.3). Needs C4. | L |
| w06_delete_pending | الحذف بعد 30 يوم | new | Same. | `GET/DELETE /users/me/deletion` (map A §1.3). Needs w05. | S |
| w12_date_passed | تم العرس؟ | new | No DONE status, no date-passed prompt. | `POST P/complete`, `date-prompt/snooze`, `WEDDING_DATE_PASSED` cron (map A §1.6). | M |
| w13_archive_plan | الذكريات | new | Archive is one-way, any editor can do it, and it blocks all writes. | Owner-only archive from DONE or PAUSED with a write allow-list (map A §1.6, map B §7.5). | M |
| w14_archived_view | خطة في الذكريات | new | No memories summary or restore. | `GET P/memories`, `POST P/restore` (map A §1.6). Needs w13. | S |
| w15_delete_plan | حذف الخطة | new | Only whole-account erasure exists. | `GET P/deletion-impact`, `DELETE P {confirmTitle}`, receipt, notices (map A §1.6). Needs C4. | L |
| w40_privacy | الخصوصية | new | No privacy settings or data export. | `GET/PATCH /users/me/privacy`, `POST /users/me/exports` (map A §1.3). | M |
| x02_date_approx | تقريبًا متى؟ | V1 | No approximate date mode or tentative tasks. | `dateMode: APPROX`, `approxKey/Start/End` on `PATCH P`, tentative tasks (map A §1.6). | M |
| x19_conflict | تعديلين على نفس البند | 1.1 | No versions, no conflict store. | `version` columns, `409 EDIT_CONFLICT`, `PlanEditConflict` + resolve (map A §1.5). | L |
| x23_pause_plan | إيقاف الخطة | 1.1 | No PAUSED status or write policy. | `GET P/pause/preview`, `POST P/pause`, `planWritePolicy` (map A §1.6). Needs C57. | L |
| x24_plan_paused | خطتك متوقفة | 1.1 | Same, plus deposit refund tracking. | `GET P/pause/summary`, `POST P/resume`, deposit remind (map A §1.6). Needs x23, w21. | M |
| y11_search | بحث واحد | 1.1 | Search exists on costs only. | `GET P/search?q=&sections=` filtered by rights (map B §5). | M |

### B.2 Participant journey (11 screens)

| id | Title | Missing capability | Proposed contract (source) | Size |
|---|---|---|---|---|
| x05_invite_landing | محمد يبغاك معه | No preview before the OTP (DEC:188 forbids details before phone proof). | PUB `GET /invites/:token/preview` with first name, date, city only (map C x05). Needs C35. | S |
| w16_invite_states | الدعوة ما تفتح | Every failure collapses to one 404; expiry is 14 days, design says 7. | `410 INVITE_EXPIRED`, `410 INVITE_REVOKED`, `403 INVITE_PHONE_MISMATCH {masked}`, `409 INVITE_ALREADY_ACCEPTED`, `POST /invites/:token/renewal-request` (map C w16). | S |
| q06_money_view | المال: يشوف بس | A money viewer gets only their own contributions (F14), so the totals would be wrong. | Section-level money VIEW: whole-plan totals and schedules, no funding (map C §2.2). Needs C65. | M |
| q09_bride_view | العروسة مشاركة عند العريس | The partner role sees everything including money (opposite of the design); no schedule. | `PARTNER_GUEST` preset + `GET P/schedule` (map C q09). Needs b12, C63. | M |
| q11_leave | اطلع من الخطة | Leaving does not hand the member's tasks back, so «مهامك ترجع لمحمد» would be false. | `GET P/members/me/leave-preview`; leave returns tasks to the owner (map C §3.2). | S |
| q13_permission_request | الطلب يوصل محمد | No permission requests. | `POST P/permission-requests`, `GET` (owner), `POST /permission-requests/:id/answer` (map C q13). Needs the participant request sheet (map C L-C14). | M |
| q14_request_sent | طلبك وصل | Same. | `GET P/permission-requests/mine`, `DELETE /permission-requests/:id` (map C q14). Needs q13. | S |
| q15_rafd_writer | كاتب الرفد | No rafd model or writer role. | `POST P/rafd`, `GET P/rafd/mine`, `rafd=WRITE` level (map C q15, map B §7.6). Needs b06. | M |
| q16_providers_view | المزودين: يشوف بس | No providers VIEW level, no shared day contacts. | `GET P/providers/overview`, `PlanContact.sharedWithParticipants` (map C q16). | M |
| q20_removed | انشال من الخطة | Removal purges everything the member could read; tasks are not returned. | `EndedMembership` tombstone, `GET /me/ended-memberships`, task return (map C q20). | M |
| y10_father_home | وضع الوالد | A view-only member cannot hold tasks, and guest counts are scoped to his own guests. | Section-level VIEW + "assignee needs tasks ≥ VIEW" (map C §2.2, L-C03). Needs C28. | M |

### B.3 The backend work behind section B, grouped

| Epic | Unblocks | Size |
|---|---|---|
| Section-level permission levels (`NONE/VIEW/MANAGE`, presets, migration of existing members) | q06, q09, q16, y10; later the full g01/g06/x07 design | L |
| Plan events + program + home projection (`GET P/home`) | b04, b05, b12, b13, y06, y07, y12, q09 program, q18 program | L |
| Rafd book (entries, offline batch, writer and viewer rights, thanks, reciprocals) | b05, b06, e09, e10, x13, q15 | M |
| Mahr and the money formula (AGREEMENT section, §0.1 formula, server gap) | a06, y08, c08; the deferred parts of b01, b02, c01, c02 | M |
| Plan lifecycle (PAUSED, DONE, owner-only reversible archive, plan delete, write policy) | w12, w13, w14, w15, x23, x24, q19 variants | L |
| Account deletion grace + sessions | w04, w05, w06 | L |
| Marketplace v2 customer side (units, holds, deposits with acknowledgement, day status, delivery) | f10, f11, f12, f13, f14 | L |
| Permission requests + membership exits | q11, q13, q14, q20 | M |
| Invite v2 (preview, distinct errors, 7 days) | x05, w16 | S |

---

## C. Logic errors in the new design to decide before building

"Blocks A?" says whether a section A screen must wait for the decision. "Copy" means only the wording has to be fixed. Sources: map A L-numbers (L#), map B §9 issue numbers (B#), map C L-C numbers, map D L-numbers (D-L#), and `LOGIC_LIFECYCLE_AUDIT.md` (LLA).

### C.1 Decisions that block a section A screen (17)

| # | Screens | Contradiction | Recommended resolution | Blocks A? |
|---|---|---|---|---|
| C1 | a07, x03, b01, w19, c01, c02, a06 (source B#1) | Is the mahr inside the budget? a07 «المهر محسوب لحاله» and x03 «بدون المهر», but b01 «ميزانيتك 10 مليون: 3 للاتفاق و7 لعرسك» and w19 allocates «المهر والشبكة 2.5 مليون» inside the 10 million. The w19 amounts also disagree with c02. The current starter catalog makes «المهر والاتفاقات» an ordinary budget category (F3). | Budget = the wedding only. The mahr sits outside it, in its own agreement section. b01 «ميزانية عرسك 7 مليون، والاتفاق 3 لحاله». Remove the mahr row from w19. **Interim (section A):** do not offer mahr as a normal budget item; hide `groom-mahr` from the starter categories until a06 ships, so no data needs migrating later. | **Yes**: a07 copy, w19, c01, c02 |
| C2 | c01, b02, x08, q06 (B#2, B#3, L-C09) | The server `shortfall` counts pledges (F5), so it equals the design's «ومع الموعود 1.3», not «ناقصك 2.5». The c01 bar labels the 1.3 segment «ناقصك». x08 says «ما بتوصل … ويزيد الناقص», but the gap never included the pledge. The design's «العرس بيكلفك» counts allocations for items without an agreement; the server counts agreements only. | Adopt the map B §0.1 formula on the server (gap = remaining − inHand; gapIfPledges = gap − pledged; committed counts allocations when no agreement exists). **Interim:** show the server's numbers with their real labels («اتفقت على», «ومع الموعود ناقصك»), never compute the gap on the client, and fix the x08 line to «تنشال من الموعود». | **Yes**: c01, b02, x08 labels |
| C3 | g03, w10, w12, c07, c10 (L1, B#27) | g03 says «الدفعات ما تتغير», w10 and w12 say «المهام والأقساط تتحرك». A direct contradiction. «الباقي يوم العرس» schedules are relative to the date. | Fixed-date payments stay; «يوم العرس» payments move with the date once events exist. **Interim:** every schedule has a fixed date, so g03 says «المهام تنتقل، والدفعات تبقى على مواعيدها»; change w10 and w12 to match. | **Yes**: g03, w10 copy |
| C4 | g11, w05, w06, w15 (L2, L13, L17) | g11 «تنحذف خطتك … وما ترجع» against the 30-day restore in w06. w06's dates are 27 days, not 30. w15 deletes a plan at once while account deletion waits 30 days. | 30-day grace for the account; g11 «تنحذف بعد 30 يوم، وتقدر تتراجع». Fix the dates (19 Oct → 18 Nov). Give w15 an export link at least. **Interim:** hide the delete entry in g11 until w05 ships, so today's immediate delete is never presented with grace wording. | **Yes**: g11 |
| C5 | w11, w09, a08 (L3) | «خطة واحدة مفتوحة لك كصاحب عرس» conflicts with w09 «خلّها خطة ثانية · لعرس أخوك», w11 «تنشئه لأحد من أهلك» and the «خطة جديدة» button. The backend has no limit. | Drop the limit for now (the plan for a brother is just a second owned plan), or keep it and add an ownership-transfer screen. Recommended: drop it, and remove the rule line from w11. | **Yes**: w11, w09 copy |
| C6 | a08, a08b, b02, d01, d03, w09, w15 (L4, L-C01, LLA 3.4) | 30 tasks (a08, a08b, b02, d03) vs 23 (w09, w15, LLA). The catalog actually holds 20 groom tasks (F2). | Screens show the catalog's real count, never a fixed number. Update the mocks and LLA 3.4. Decide whether to grow the catalog to the designed list. | **Copy**: render the real count |
| C7 | a08b vs w01, w02, q02 (L12) | a08b «8 أحرف أو أكثر»; w01 and w02 «6 أحرف»; the backend minimum is 6. | 6 everywhere (or raise the backend to 8 on purpose, then change w01 and w02). | **Yes**: a08b copy |
| C12 | b07, c13, c05 (B#10, B#11) | «سددت 2.3 من 4.2 مليون بعد العرس» and «1.9 باقي عليك» do not add up from any listed loan; c13 ends in March while c12 says four monthly instalments from February. | Debt after the wedding = loans outstanding + agreements still unpaid after the date (both exist today: `funding.loanOutstanding`, `costs.outstanding`). Align c12/c13 samples (February to May). | **Yes**: b07 |
| C15 | x15 (B#13) | «ميزانيتك تخف · 200 ألف»: removing an item frees its allocation into the reserve; the budget does not shrink. Also «يبقى في السجل» is false: delete is hard today. | «يرجع 200 ألف للاحتياط», and «ينحذف البند» until soft removal exists. | **Yes**: x15 copy |
| C24 | b01 (B#33) | The «القاعة» step has no done rule. | Done = a confirmed venue booking **or** a recorded venue agreement (cost in the venue category). | **Yes**: b01 |
| C27 | g06, q03, q05, x05 (L-C02) | Tasks "manage" is drawn three ways: g06 «يعدّل», q03 «تشوف وتخلّص», q05 «ما تقدر تعدّلها». | MANAGE = add tasks and finish your own or assigned; others' tasks read-only. q03 «تضيف مهام وتخلّص اللي عليك». | **Yes**: g06, q03 copy |
| C28 | d02, x16, g01, y10, z05 (L-C03) | The father is «يشوف بس», yet tasks are assigned to him («للوالد», «مطلوب منك»). The backend refuses an assignee without the tasks flag. | Any member with tasks ≥ VIEW can hold and finish assigned tasks. **Interim:** the «للوالد» chip appears only for members whose stored flags allow it. | **Yes**: d02, x16 assignee list |
| C29 | e01, e04, e08 (L-C04) | The father is the card host and the sender («الوالد يرسلها»), but he is view-only and cannot send. | The host name is card text only; the owner sends from his own phone «باسم الوالد». | **Yes**: e04, e08 copy |
| C30 | e04, e08, e10 (L-C05, B#24) | «أرسلها لـ 124 ضيف» on WhatsApp: personal bulk sending needs the Business API (cost, template approval). Guests without WhatsApp have no path. | Step-through sending from the owner's phone («التالي 3 من 124»), plus «انسخ الرابط» for guests without WhatsApp. Server sending can come later. | **Yes**: e04, e08 |
| C31 | e08, x07 (L-C06) | Reminders and «انسخ الرابط» reuse the link already sent, but the backend stores only a hash, so a resend must mint a new link and kill the old one. | Guests: store the RSVP token encrypted so reminders reuse it (later). Participants: rotate and say so. **Interim:** both say «هذا رابطك الجديد، والقديم ما عاد يشتغل». | **Yes**: e08, x07 copy |
| C58 | x18, w41 (L18 vs DECISIONS "Bind offline replay to its originating session") | x18 promises the offline changes are sent after a new sign-in; the decision forbids a new token from authorising old writes. | Update the decision: replay is allowed when the same userId signs in again and plan access still holds; another account drops the queue. | **Yes**: x18, w41 |
| C63 | g01, g06, x07, q03, q04, q09 (map C §2, L-C28) | The design's presets (مساعد، أهل، كاتب الرفد، يشوف بس، العروسة) with «لا / يشوف / يعدّل» per section do not match today's roles and booleans. The «العروسة» preset means "schedule only", but the backend partner role sees everything including money. | Adopt map C §2 later. **Interim mapping:** مساعد = HELPER, أهل = FAMILY, يشوف بس = VIEWER; «العروسة» is not offered; «يشوف» exists only for money. | **Yes**: g01, g06 |

### C.2 Wording or state fixes on section A screens that do not need a product decision (15 rows, 19 ids)

| # | Screens | Problem | Fix |
|---|---|---|---|
| C17 | c04 (B#15) | A payment saved offline stays under «قادمة» and in the 30-day total. | Move it to «دُفعت · ينتظر الإرسال» and out of the total. |
| C18 | c06 (B#16, D-L15) | A per-payment «خاصة بي» makes paid totals differ between people. | Drop it now; later «أخفِ التفاصيل» (source, receipt, note), the amount stays shared. |
| C20 | c02, c09, w19 (B#20) | Gold: «إذا كان عليك» and «يدخل في الميزانية» vs w19 «المهر والشبكة». Grams cannot be summed. | Decide the section with C1; a gram item needs an estimated value. In A, gold is a normal item in money. |
| C22 | b11, x03, w38 (B#22) | «النطاق اللي سجله عرسان صنعاء على اعّرست» but the data is provider list prices. | Remove the claim until couple-spend data with ≥ 20 plans exists. |
| C25 | b02, f01, y09 (B#32, D-L13) | «3 من 6», «4 من 6»: no list of needed provider types. | Show booked counts only until `PlanProviderNeed` exists. |
| C33 | e01, z06 (L-C08) | Hall capacity 150 in e01, 130 in z06, with no source. | Drop the capacity line until it comes from a venue booking or manual entry. |
| C39 | w26 (L-C25) | «نبلّغك بس إذا … توقف شيء ثاني», but every overdue task notifies. | Drop the sentence now; change the cron later. |
| C40 | x12 (D-L1) | «نراجعه خلال يوم» while reviews publish at once. | «انرسل وانتشر، وإذا خالف الشروط نخفيه ونقول لك ليش». |
| C47 | f09 (D-L22) | «قارن الاثنين» compares profiles, f04 compares offers; same name. | «قارن الملفين». |
| C49 | w02 (L6) | «هذا الرقم عليه حساب» on the form before the OTP (phone enumeration). | Show it after a09. |
| C50, C51 | g08, g02 (L7, L8) | No screen to set the PIN or fingerprint; g02 has no way into ten screens. | g08 = lock settings; add «عرسي» and «الحساب» groups to g02. |
| C52, C59, C60, C62 | a02, g11, b08/g07, w09 (L9, L19, L23, L28) | «أنشئ حسابي» before any account; logout with unsent changes; payment reminder 3 vs 7 days (backend 7); a single confirm to discard a local plan against DEC. | «التالي»; add a g11 warning state; use the server's 7 days in copy until the lead-time setting exists; add a second confirmation on «تجاهلها». |
| C44 | f04 (D-L8) | f04 promises «لما تختار … نطلب منهم حجز يوم عرسك», but accept and booking request are two calls, so a failure leaves an accepted offer with no booking. | Ship two calls with client retry and a visible «كمّل طلب الحجز» state; make it atomic later (map D f04 contract). |
| C45 | f07 (D-L31) | f07 sends «124 تقريبًا» to every provider; PJ §5 limits guest count to halls and catering. | Send `guestCount` only for those categories (client rule now, `needsGuestCount` later). |
| C46 | f07 (D-L10, F8) | The provider always receives the customer's phone (it defaults to the account phone). | Do not promise phone privacy on f07; add a phone toggle only when the backend supports `shareContact`. |

### C.3 Decisions that only affect section B screens (11)

| # | Screens | Contradiction | Recommended resolution |
|---|---|---|---|
| C8 | b05, b12, b13, y06, y07, q18 (B#7) | The wedding-day program differs: b12 «المقيل» Wednesday and «الزفاف بعد العصر»; b05 «المقيل بعد العصر», «الزفة بعد المغرب»; y07 «الزفاف بعد العصر». b05 uses «الظهر», missing from b13's slots. | One program: «الغداء · الظهر», «الزفاف · بعد العصر» (main), «العشاء · بعد العشاء». Add «الظهر» to b13. |
| C9 | b04, y04, c07, c10 (B#6) | «الكاش اللي تحتاجه · الزفاف 400 ألف», but day-of payments are 1.3 million; y04's 160 ألف deposit contradicts the 100 ألف deposit paid in October. | Cash per night = schedules due at the event + planned custody. Fix the samples. |
| C10 | b04 vs y09 (B#8) | Booked in y09, «ما أكّدت» in b04. | A wedding-week reconfirmation state; wording «ما أكّدت الموعد هذا الأسبوع». |
| C11 | b07, e09, x13 (B#9) | Salem's rafd is 20 ألف, 50,000 and «أبريل» in three places; «رفدك» is ambiguous. | 50,000 everywhere; «رفدك بـ» = he gave you. |
| C16 | c08 (B#14) | «عدد الضيوف 124 → 100» then «طبّق»: applying cannot remove 24 guests. | Make it «عدد الضيافة» (catering headcount), or simulation only. |
| C19 | w20, c05 (B#17, B#39) | Payer is mixed with source («خالي أحمد» as payer); the father's direct payments double-count «دعم الوالد»; rafd vs GIFT sources. | Payer ≠ source; a father's payment uses the «دعم الوالد» source; the rafd book is the single truth for rafd. |
| C23 | e10 (B#25) | «اذكر المبلغ» vs the rule «بدون مبلغ». | Remove the option. |
| C35 | x05, q01 to q03 (L-C11) | Two decision screens with different buttons; «مو الحين» is ambiguous; x05 shows details before the OTP (DEC:188). | x05 = minimal preview before OTP (update DEC:188); q03 = the decision; «مو الحين» closes without deciding. |
| C57 | x23, x24, w13 (L5, L16, L25 to L27) | Pausing does not say if bookings are cancelled; x23 forgets loan reminders; no archive rule; restore target undefined; w15 nudges a paused plan to pause. | Bookings stay until cancelled; «إلا أقساط السلف»; suggest memories after DONE + N days; restore → DONE; hide the pause nudge on a paused plan. |
| C65 | q06 (L-C09) | «المال: يشوف» hides sources and loans, yet shows «ناقص 2.5», which is derived from funding. | Allow the aggregate gap, never the source and loan lists (or hide the gap too). |
| C66 | f11, z07, b03, z04 (D-L16, D-L17, AGENTS.md) | Deposits, provider acknowledgement and AI extraction are fenced by AGENTS.md unless explicitly approved; PJ §8.1 is still a draft. | Record the approvals in `DECISIONS.md` before building these. |

Total in section C: 17 + 15 + 11 = 43 rows covering 47 ids (some rows group several ids). Other map items (bride direction B#21, FX, expat, provider-side L-numbers) belong to the bride or provider journeys and are not repeated here.

---

## D. Suggested build order for section A

Each slice is a vertical cut: screens, the client data layer for their endpoints, and their tests. Order follows dependencies: auth before data, reads before writes, money before providers (accepting an offer creates a cost).

| Slice | Screens | Decide first (section C) | Notes |
|---|---|---|---|
| 1. Auth and onboarding (17) | a01, a02, a02b, a03, a04, a05, a07, a08, a08b, a09, a10, w01, w02, w03, x17, x18, w09 | C1 (a07 copy, mahr hidden from starters), C5, C6, C7, C49, C52, C58, C62 | Plan-first draft, then register and import-local. |
| 2. Shell and home (8) | b14, b15, w42, w41, b08, b01, b02, x01 | C2, C17, C24, C25, C60 | The home reads dashboard-summary and money-summary as they are. |
| 3. Money read (8) | c01, c02, c03, c05, c07, c11, x03, w22 | C1, C2, C20, C22 | Owner view first; non-owners see locks. |
| 4. Money write (12) | c04, c06, c09, c10, c12, c13, x08, x14, x15, w18, w19, w23 | C2, C3, C12 (samples), C15, C18 | All writes carry `X-Client-Request-Id`. |
| 5. Tasks (10) | d01, d02, d03, d04, d05, x16, w24, w25, w26, y14 | C6, C28, C39 | d03 uses the existing `tasks.starter` catalog. |
| 6. Guests (12) | e01, e03, e06, e07, w27, w28, w29, x21, e04, e05, e08, w38 | C29, C30, C31, C33 | Invitations sent step by step from the owner's phone. |
| 7. Providers, customer side (24) | x22, f02, w30, w33, f03, f09, y13, f07, f08, f06, w32, f01, f04, f05, y09, x10, x09, w31, w34, x11, w35, g04, x12, b07 | C25, C40, C44, C45, C46, C47 | Needs slice 4 (accepting an offer creates a cost). b07 closes the after-wedding loop (loans, rating). |
| 8. Account, settings, plan (15) | g02, g07, g10, g11, w39, w07, w08, g08, w10, g03, w11, g01, g06, x07, x20 | C3, C4, C5, C27, C31, C50, C51, C59, C63 | Participants managed by the owner with today's roles. |
| 9. Participant (15) | x04, q01, q02, q03, q04, x06, q17, q05, q18, q07, q08, q10, q12, q19, q21 | C7, C27, C63 | Runs on today's contributor scoping. |
| 10. Version 1.1 extras (7) | b09, b10, b11, w36, w37, c14, g09 | C22 | Phase 1.1 in `GROOM_JOURNEY_PHASES.md`; build after V1. |

Slice totals: 17 + 8 + 8 + 12 + 10 + 12 + 24 + 15 + 15 + 7 = 128 = all section A screens.

## Top blockers

1. **Permission model (C63, C27, C28):** decides the presets in g01, g06 and x07, and every participant screen. It also gates 6 of the 11 participant B screens (section-level levels).
2. **Money meaning (C1, C2):** mahr inside or outside the budget and the gap formula. Slices 2 to 4 cannot settle their labels without them. Behind it sits the mahr epic (a06, y08).
3. **Events model:** the largest single backend gap for the groom (b04, b05, b12, b13, y06, y07, y12, plus q09 and the participant program). Needs C8 first.
4. **Rafd book:** b05, b06, e09, e10, x13, q15.
5. **Plan lifecycle:** w12 to w15, x23, x24 and the participant plan states. Needs C4 and C57.
6. **WhatsApp sending and link reuse (C30, C31):** must be decided before the guests slice ships invitations.
