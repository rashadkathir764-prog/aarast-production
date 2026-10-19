# API map A: account, auth, onboarding, plan lifecycle, settings, general states

Date: 2026-10-19. Rule: **the design is the reference** (owner decision, `LOGIC_LIFECYCLE_AUDIT.md`). The backend follows it later. No code was changed.

Sources: `screens_inventory.md`; the screen functions in `mobile/test/prototype/v3/*.dart` (strings quoted below come from those functions, not from the inventory text); `api_inventory.md`; backend source checks noted with `file:line`; `JOURNEY_PROFILE.md`; `DECISIONS.md`.

Legend: ✅ exists as-is · 🔧 exists but must change · ➕ new endpoint needed · 📱 client-only.
All paths are under `/api/v1` unless shown otherwise. "Owner" means `WeddingPlan.ownerUserId`. Every new mutating route takes `X-Client-Request-Id` (existing `IdempotencyInterceptor`).

Backend facts this map relies on, checked in source:
- The OTP is 6 digits (`identity/internal/auth/otp-channel.ts:28`). One code allows 5 attempts (`OTP_MAX_ATTEMPTS`) and expires after 5 minutes. Sending is limited per phone to 1 a minute, 5 an hour and 10 a day (`otp-dispatch-quota.service.ts:22,66-67`). Password login allows 5 failures in 15 minutes (`login-throttle.service.ts:19-20`). There is **no OTP lockout across codes**.
- The minimum password length is **6** (`complete-registration.dto.ts:25`).
- `/auth/register` does not reveal whether the phone already has an account. The duplicate is reported only at `/register/complete`, after the OTP proves the phone, as `409 ACCOUNT_ALREADY_EXISTS` (`auth.service.ts:~290`).
- `phone-change/confirm` and `password-reset/confirm` revoke **all** APPLICATION sessions, the current one included (`auth.service.ts:1030-1041, 1649-1651`). Neither returns tokens.
- `DELETE /users/me` erases the account **immediately** in one transaction (`users.service.ts:301`). It does not notify members or providers. Bookings and quotes are deleted with the account.
- `PATCH /wedding-plans/:id` **cannot clear** `weddingDate`. Null or an empty string gives 400 (`wedding-plans.service.ts:805`). The route has no `estimatedBudget` or `currency` fields.
- `PATCH /wedding-plans/:id/archive` needs `canEditPlan`, not owner. It is one-way (there is no unarchive), and it makes every write 409 `PLAN_ARCHIVED_READ_ONLY`.
- `WeddingPlanStatus = {PLANNING, ARCHIVED}`. The contexts endpoint marks every non-PLANNING plan `READ_ONLY` (`contexts.service.ts:229`).
- Contribution history does **not record owner actions** (`contribution-history.service.ts:96`).
- `RefreshToken` stores no device or session metadata.
- Payment reminders fire up to 7 days before the due date. There is no lead-time setting.
- No owner-level rule limits how many plans one user can own.
- `onboarding/import-local` always creates a **new** plan. It has no merge mode.

---

## 1. Screen → API table

### 1.1 Start, onboarding, register, login

| Screen | Reads | Writes / actions | Existing endpoint(s) | Status | Proposed contract (new or changed) |
|---|---|---|---|---|---|
| a01_splash | Is there a session? Account state (active, deletion pending). Is the PIN lock on? Selected context | Route to home, a02_who, w06 or w07 | `POST /auth/refresh`, `GET /me`, `GET /contexts` | 🔧 | `GET /me` gets `accountStatus: ACTIVE\|DELETION_PENDING`, `deletionScheduledFor?`. `POST /auth/refresh` on a pending account still issues tokens, but only with `scope=application` and the claim `restricted=deletion_pending`. Every guard except `/me`, `/users/me/deletion` and `/auth/logout*` answers `423 ACCOUNT_DELETION_PENDING`. The lock check is local. |
| a02_who | none | Choose: «أنشئ خطتك» → a02b, «مزود خدمة» → provider path, «عندي حساب» → a10, «عندي رابط دعوة» → x05 | (later) `POST /provider/apply` | 📱 | The bottom button reads «أنشئ حسابي», but the plan-first flow creates no account here (see §3 L9). |
| a02b_whose / a02c_whose_bride | none | Choose the plan type: «العريس» or «العروسة». This picks the theme and the wording file | none at this step (stored in the local draft) | 📱 | The value is later sent as `planType` (see a09 and the bride row). |
| a03_name | none | `ownerName` («اسمك»); partner name «اسم العروسة (اختياري)» (bride: «اسم العريس (اختياري)»); title made automatically, «عرس محمد وسلمى» | `POST /onboarding/complete` or `import-local`: `title` only | 🔧 | Add `partnerName?: string(≤80)` to the plan, `CompleteOnboardingDto` and `ImportLocalPlanDto`. The user name goes to `User.name` at register. |
| a04_date | Hijri for each month (client); Ramadan warning (client) | One of three: an exact date «اليوم بالضبط»; a month only (tap a month); «ما حددنا الموعد بعد» | `weddingDate` (exact only) | 🔧 | Plan fields: `dateMode: EXACT\|MONTH\|APPROX\|NONE`, `weddingDate?`, `approxMonth?: 'YYYY-MM'`, `approxKey?`, `approxStart?`, `approxEnd?`. Validation: EXACT needs `weddingDate`; MONTH needs `approxMonth`; APPROX needs `approxKey` plus a window; NONE nulls all of them. |
| a05_city | City list | Pick a city, or «مدينة ثانية» | `GET /cities` | ✅ | Store `cityId` as well as the `city` text (see L14 on governorate). |
| a06_mahr | none | «اتفقتوا على المهر؟» → `amount`, «سلّمت منه» amount, «موعد تسليم الباقي» date, or «ما اتفقنا بعد». Bride: «استلمتِ منه», «موعد استلامه» | none | ➕ | Created inside onboarding and import as `mahr: {status: AGREED\|NOT_AGREED, totalAmount?, settledAmount?, remainderDueDate?}`. Later: `GET/PUT /wedding-plans/:id/mahr` → `{status, direction: PAY\|RECEIVE (from planType), totalAmount, settledAmount, remaining, remainderDueDate, currency}`. Needs MONEY_R / MONEY_W. Errors: `400 MAHR_SETTLED_EXCEEDS_TOTAL`. The remainder date feeds the reminder cron. |
| a07_budget | none | Range buttons («أقل من 5 مليون» … «أكثر من 20 مليون») or «ما أدري، ساعدني أحسبها» | `estimatedBudget` (number) | 🔧 | Add `budgetBand?: LT_5M\|5_10M\|10_20M\|GT_20M\|UNKNOWN`. Keep `estimatedBudget` null until the user types a number (no invented midpoint, DEC:258). Mahr is not part of the budget. «ساعدني أحسبها» has no screen to open (L10). |
| a08_ready | Generated starter set: «3 مناسبات», «9 بنود», «30 مهمة», mahr summary | «احفظ خطتي برقم جوالي» → a08b; «بعدين، خلني أشوف أول» → local guest mode | `GET /catalogs/bootstrap` (categories; flags `showForGroom/Bride`) | 🔧 | The catalog must publish **plan-type templates**: `wedding_events` (groom: السمرة، المقيل، الزفاف; bride: الحفلة، النسمة، الزفة), `starter_items` per city and type, and `starter_tasks` with `offsetDays` from the wedding plus `sequence` (needed by x01). The client builds the draft locally from that catalog. The task count must match the design everywhere (L4). |
| a08b_register | The local draft summary «عرس محمد وسلمى · 30 مهمة · 9 بنود» | name, phone, password → OTP | `POST /auth/register` (name, phone) | ✅ | The password is held on the client until a09 (it is sent with `/register/complete`). The name is prefilled from a03. |
| a09_otp | Countdown «نعيد الإرسال بعد 0:42» | 6 digits that submit themselves; «تغيير» (edit the number) | `POST /auth/register/complete` (name, phone, password, otpCode), then `POST /onboarding/import-local` | 🔧 | `import-local` gains the new plan fields (`planType`, `partnerName`, `dateMode…`, `mahr`, `budgetBand`, `residence`, `groundHelper`). `409 ACCOUNT_ALREADY_EXISTS` after OTP leads to w02 (see w02). |
| a10_login | none | phone + password; «الدخول برمز واتساب»; «نسيت كلمة المرور؟» → w01 | `POST /auth/login`; `POST /auth/otp/request` (purpose LOGIN) + `POST /auth/otp/verify` | ✅ | After login: if a local draft exists and the account has a plan → w09. |
| y01_where_are_you | none | «في اليمن», «مغترب في السعودية», «مكان ثاني»; «مين على الأرض؟» → «صالح أخوي», «الوالد», «واحد ثاني» | none | 🔧 | Plan fields `residence: IN_YEMEN\|ABROAD`, `residenceCountry?: ISO2`. `groundHelper` is held as a **pending local helper** `{name, relation}`. After register it becomes `POST /wedding-plans/:id/invites`, which exists, with role HELPER and the phone asked at that moment. Ground tasks get `responsibleName`. Where y01 sits in the onboarding order is not decided (L11). |

### 1.2 Auth edges

| Screen | Reads | Writes / actions | Existing | Status | Proposed contract |
|---|---|---|---|---|---|
| x17_otp_wrong | «باقي لك محاولتين», resend countdown | Retry; «الرقم غلط؟ غيّره»; «ادخل بكلمة المرور» | `POST /auth/otp/verify`, `/register/complete` | 🔧 | The invalid-code error body becomes `{code: 'OTP_INVALID', attemptsRemaining: int, retryAfterSeconds: int}`. When the attempts run out: `{code:'OTP_EXHAUSTED', retryAfterSeconds}`. |
| w03_whatsapp_missing | Resend countdown | Resend; «الدخول بكلمة المرور»; change number | `POST /auth/otp/request` | 🔧 | Add the lockout the design promises: «بعد 5 محاولات غلط نوقف الرموز 15 دقيقة». After 5 failed verifies across codes for one phone and purpose, give `429 OTP_LOCKED {retryAfterSeconds}` for 15 minutes. Reuse `LoginThrottle` with an `otp:` subject prefix (no schema change). WhatsApp only: no SMS fallback. |
| w01_forgot_password | Three steps: «رقمك», «الرمز», «كلمة جديدة» | New password; «حفظ وتسجيل الدخول»; «بنطلعك من الأجهزة الثانية» | `POST /auth/password-reset/request`, `POST /auth/password-reset/confirm` | 🔧 | (1) Add `POST /auth/password-reset/verify {phone, code}` → `{resetToken, expiresAt}` so step 2 can fail before step 3. (2) `confirm {resetToken \| (phone, code), newPassword}` → **AuthResponse** for this device, revoking every other session. Errors: `OTP_INVALID`, `RESET_TOKEN_EXPIRED`, `400 PASSWORD_TOO_SHORT {min:6}`. |
| w02_register_errors | «هذا الرقم عليه حساب من قبل»; «قصيرة. خلّها 6 أحرف أو أكثر» | «ادخل» | `/auth/register/complete` → `409 ACCOUNT_ALREADY_EXISTS` | 🔧 | Keep the check **after** the OTP so phones cannot be enumerated. The design shows it on the form, before the OTP (L6). Change: on `ACCOUNT_ALREADY_EXISTS`, the same verified OTP claim may return `{code:'ACCOUNT_ALREADY_EXISTS', loginGrant: AuthResponse}`. «ادخل» then signs in with no second code, and w09 follows. Password length is checked on the client with min 6, the same as the server. |
| x18_session_expired | Prefilled phone «+967 777 123 456»; «3 أشياء سجّلتها بدون نت» | «أرسل الرمز على واتساب» → sign in again; replay the queue | `POST /auth/otp/request` (LOGIN), `POST /auth/otp/verify` | ✅ | The backend is fine. The client replay rule must allow the **same userId** after re-auth (L18). |
| w07_pin_entry / w08_pin_wrong / g08_lock | none | 4-digit PIN; after 3 wrong tries a 30 s cooldown; «نسيت الرمز؟» → re-auth with password or WhatsApp, then clear the PIN | `POST /auth/login` or OTP LOGIN, used to re-auth | 📱 | The PIN hash stays in the device keystore and never reaches the server. Biometric unlock is device-only. No PIN setup screen exists (L7). |
| g09_change_phone | «رقمك الحالي» | New number → OTP | `POST /auth/phone-change/request`, `POST /auth/phone-change/confirm` | 🔧 | `confirm` returns a fresh **AuthResponse** for the current device and revokes only the **other** sessions («بنخرجك من الأجهزة الثانية»). Today it revokes all of them, the current one included. Errors are kept: `PHONE_IN_USE`, `PHONE_UNCHANGED`. |
| w04_devices | List: «هذا الجوال · أنت هنا», model, city, last seen | «اطلع» on one; «اطلع من كل الأجهزة الثانية» | `POST /auth/logout-all` (logs out everything, current included) | ➕ | `GET /auth/sessions` → `[{id, deviceLabel, platform, approxCity?, lastSeenAt, createdAt, current: bool}]`. `DELETE /auth/sessions/:id` → 204 (`404 SESSION_NOT_FOUND`; `409 CANNOT_REVOKE_CURRENT`, which means use logout). `POST /auth/sessions/revoke-others` → `{revoked: n}`. All three emit `SESSION_REVOKED` or `USER_SESSIONS_REVOKED` to the outbox. Login, register and refresh accept an optional `device: {label, platform, appVersion}`. |
| g11_logout | none | «اخرج من هذا الجوال»; «احذف حسابي نهائيًا» → w05 | `POST /auth/logout` (+ `DELETE /push/installations/current`) | 🔧 | Logout itself is fine. The delete sub-line «وما ترجع» contradicts the 30-day grace (L2). The client must warn when the offline queue still holds changes (L19). |

### 1.3 Account deletion and privacy

| Screen | Reads | Writes / actions | Existing | Status | Proposed contract |
|---|---|---|---|---|---|
| w05_delete_account | Impact: plans, members to notify («صالح والوالد»), confirmed bookings, a link to export | Type «حذف» and confirm; «نزّلها» (export) | `DELETE /users/me` (immediate erasure, no notifications) | 🔧 | Replace it with `POST /users/me/deletion {confirmWord:'حذف'}` → `202 {status:'PENDING', requestedAt, scheduledFor (requestedAt+30d)}`. Errors: `400 CONFIRM_WORD_MISMATCH`, `409 DELETION_ALREADY_PENDING`. `GET /users/me/deletion/impact` → `{ownedPlans:[{id,title,members:[name],confirmedBookings:n}], memberOf:n, providerProfile:bool}`. Effects at request time: owned plans are **suspended** (`suspendedReason=ACCOUNT_DELETION`); members are told «الخطة متوقفة»; reminders stop. Effects at purge time (cron): the existing erasure saga runs, and **before** it confirmed bookings are cancelled with `BOOKING_UPDATED` sent to providers and members are notified. `DELETE /users/me` stays as a deprecated alias that creates the pending request. |
| w06_delete_pending | «حسابك ينحذف بعد 27 يوم», request date, deadline | «تراجعت، رجّع حسابي»; «اطلع» | `POST /account-deletions/status` (PUB; already knows `PENDING`) | ➕ | `GET /users/me/deletion` → `{status, requestedAt, scheduledFor, daysLeft}`. `DELETE /users/me/deletion` (restore) → `200 {status:'CANCELLED'}`; it lifts plan suspension and notifies members «رجعت الخطة». `410 DELETION_COMPLETED` if the purge already ran. Login during pending works but is restricted (a01). |
| w40_privacy | Toggles and labels | «أرسل تقارير الأعطال»; «المساعد الذكي» (30 a day); «اسمي في التقييمات: الاسم الأول بس»; «نزّل بياناتي»; links to w04 and w05 | `GET/PATCH /users/me/settings` (notifications only); assistant consent is per question | ➕ | `GET/PATCH /users/me/privacy` → `{crashReportsEnabled, aiAssistantConsentAt?, reviewNameDisplay: FIRST_NAME\|FULL\|HIDDEN}`. `POST /users/me/exports {scope:'ACCOUNT'\|'PLAN', weddingPlanId?, format:'JSON'\|'PDF'}` → `202 {exportId}`. `GET /users/me/exports/:id` → `{status: PENDING\|READY\|FAILED, downloadUrl?, expiresAt?}`. Errors: `429 EXPORT_RATE_LIMITED`. Ready exports are private signed URLs that expire in 24 h. |
| g10_support | Static: WhatsApp number, FAQ, privacy, terms | Open a WhatsApp link | Public static site (`deploy/public-site`) | 📱 | The FAQ may later come from the `ReferenceCatalog` key `faq`. |

### 1.4 Settings and notifications

| Screen | Reads | Writes / actions | Existing | Status | Proposed contract |
|---|---|---|---|---|---|
| g02_account | Name, phone, «موعد العرس», «المشاركين 3», look settings, «أخفِ المبالغ», «قفل التطبيق: رمز» | Edit profile; open sub-screens | `GET /me`, `PATCH /users/me`, `GET /wedding-plans/:id/members` | ✅ | Hijri, digits, large text, dark mode, data saver and «أخفِ المبالغ» stay on the device (📱). The menu has no entry for several screens (L8). |
| g07_notif | Categories and timing | Toggles: «الخطوة الجاية» (each morning), «الدفعات والأقساط» (3 days before), «ردود الضيوف» (one daily batch), «العروض والمحادثات» (at once), «ملخص الجمعة», «المشاركين», «الهدوء» 23:00–07:00 | `GET/PATCH /users/me/settings` (task/payment/provider flags and channels) | 🔧 | Add to the DTO and table: `nextStepDailyEnabled`, `paymentReminderLeadDays (default 3)`, `guestRepliesMode: IMMEDIATE\|DAILY_DIGEST\|OFF`, `weeklyDigestEnabled`, `participantActivityEnabled`, `quietHoursStart/End` (minutes, default 1380/420), `timezone (default 'Asia/Aden')`. The crons and push dispatch must respect quiet hours: hold the push, keep the in-app row. |
| b08_notifications | Groups «اليوم» and «هذا الأسبوع». Types: offer received, «صالح خلّص مهمتين», payment due, «قاعة سبأ أكدت حجز», «جمعة مباركة» digest | «قراءة الكل»; open one | `GET /notifications`, `PATCH /notifications/read-all`, `PATCH /notifications/:id/read` | 🔧 | New `NotificationType`s: `PARTICIPANT_ACTIVITY` (batched, the producer is a contribution event), `WEEKLY_DIGEST` (Friday cron), plus the lifecycle types in §4. Grouping is done on the client. Lock-screen push stays generic, as today. |
| w39_push_off | OS permission state | «افتح الإعدادات»; «لاحقًا» | (optional) `PUT /push/installations/current` | 📱 | Optional: add `permission: GRANTED\|DENIED` to the installation so the server stops pushing to dead tokens. |
| b09_widget | Countdown «96 يوم على عرسك», Hijri date, next step «دفعة القاعة بعد 5 أيام» | none | the cached `GET /wedding-plans/:id/dashboard-summary` | 📱 | The widget must follow «أخفِ المبالغ» and show no amounts or names. |
| b10_dark | the same home data | none | the same as home | 📱 | — |

### 1.5 General states

| Screen | Reads | Writes / actions | Existing | Status | Proposed contract |
|---|---|---|---|---|---|
| b14_loading | none | none | none | 📱 | Skeleton layout. |
| b15_error | The cached section | «حاول مرة ثانية»; «افتح طلباتي المحفوظة» | none | 📱 | Needs every list endpoint to return stable error codes (they already do). |
| w42_section_states | none | none | none | 📱 | Four states: loading, empty, error over the current data, offline read-only. |
| w41_pending_queue | Local queue: «دفعة للمصور 150 ألف», «خلّصت "احجز القاعة"», a conflict «صالح عدّله قبلك · اختر أي نسخة» | «حاول الحين»; «حل» (choose a version) | Entity PATCH routes (no versioning) | 🔧 | Optimistic concurrency on the PATCH routes for guest, cost, task and payment schedule: the request carries `expectedVersion`, a mismatch gives `409 EDIT_CONFLICT {serverVersion, serverValue, updatedBy:{name}, updatedAt}`. The client shows «حل». Needs a `version Int` column on those models. |
| x19_conflict | Two offline edits by **other** people («صالح» 1,000,000 vs «الوالد» 1,200,000 · «الأحدث»); «باقي التعديلات (3) اندمجت لحالها» | «اعتمد رقم الوالد»; «اسألهم في المحادثة» | none | ➕ | `GET /wedding-plans/:id/edit-conflicts?status=OPEN` → `[{id, entityType, entityId, field, versions:[{actorName, value, editedAt}], createdAt}]`. `POST /edit-conflicts/:id/resolve {chosenVersionIndex \| value}` → the updated entity; the access needed is the entity section's write permission. The server creates a conflict only when two replays carry the same `expectedVersion`: the first applies, the second is stored as a conflict instead of `409` to a device that has gone. «اسألهم في المحادثة» has no target: there is no participant chat (L20). |
| x20_activity | Feed: actor name, action text, time; filters «الكل/المال/المهام/الضيوف»; includes «أنت» (owner) and «انضمت للخطة» / «طلع من الخطة» | Filter | `GET /wedding-plans/:id/contributions?section=` | 🔧 | (1) Record **owner** actions too (an owner tenure row). (2) Add `ContributionAction.MEMBER_JOINED`. (3) The response includes `actor:{displayName, initial, isMe}`; names are visible only to the owner and members who can manage members. (4) MONEY events are hidden from readers without `canViewMoney`. (5) Paging with `cursor`. |

### 1.6 Plan lifecycle

| Screen | Reads | Writes / actions | Existing | Status | Proposed contract |
|---|---|---|---|---|---|
| x01_home_no_date | Ordered steps «خطواتك بالترتيب»; the mahr recorded; prompt «تقريبًا متى العرس؟» | «اختر تقريبًا» → x02; «ثبت الموعد» → w10 | `GET /wedding-plans/:id/dashboard-summary`, `GET /wedding-plans/:id/tasks` | 🔧 | The summary adds `dateMode`, `approxWindow`, and `orderedSteps[]` (tasks sorted by `sequence` when there is no date). Tasks need `sequence` and `offsetDays` so they spread themselves out once a date is set. |
| x02_date_approx | Options «بعد رمضان», «بعد العيد الكبير», «الصيف», «آخر السنة», «ما ندري بعد», each with a Gregorian window; the hint «بنذكّرك تحجز في مارس» | «رتّب خطتي على هذا» | `PATCH /wedding-plans/:id` (date only) | 🔧 | `PATCH /wedding-plans/:id {dateMode:'APPROX', approxKey: AFTER_RAMADAN\|AFTER_EID_ADHA\|SUMMER\|YEAR_END, approxStart, approxEnd}` or `{dateMode:'NONE'}`. Tasks are given dates from `approxStart` and marked `isTentative`. The server computes the venue-booking reminder. Errors: `400 APPROX_WINDOW_INVALID`. |
| w10_edit_plan | Name, date (exact / «موعد تقريبي» / «ما حددنا»), «المحافظة والمديرية», «العملة: ريال يمني (صنعاء)», budget | «حفظ»; «غيّر الموعد» → g03 | `PATCH /wedding-plans/:id` (title, city, location, weddingDate) | 🔧 | The PATCH accepts `dateMode` and its fields, **`weddingDate: null`**, `governorateId`, `districtId`, `currencyRegion: YER_SANAA\|YER_ADEN\|SAR\|USD…`, `estimatedBudget`, `partnerName`, `residence`. Changing an exact date through this route gives `409 USE_POSTPONE_FLOW` once the plan has dated tasks or bookings, so the change goes through g03. |
| g03_postpone | Preview: «كان 21 يناير / صار 15 أبريل», «18 مهمة تنتقل 84 يوم», «2 حجوزات على اليوم القديم», «الدفعات ما تتغير», guests | «أجّل العرس»; per-group choices | `PATCH /wedding-plans/:id` + `POST /wedding-plans/:id/tasks/shift-due-dates` (two separate calls, and shifting needs a member who sees the whole plan) | ➕ | `GET /wedding-plans/:id/postpone/preview?newDate=` (or `approx…`) → `{deltaDays, openTasksToShift, doneTasksUnchanged, bookingsOnOldDate:[{bookingId, providerName}], paymentSchedules: n (unchanged), guestsInvited: n}`. `POST /wedding-plans/:id/postpone {newDate \| approx, shiftTasks: true, bookingIdsToReschedule: [], notifyGuests: bool}` → `{plan, shiftedTasks, rescheduleRequests:[{bookingId,status:'REQUESTED'}]}`. Owner only (PLAN_W at minimum). Side effects: `PLAN_DATE_CHANGED` to members; a booking reschedule request (provider scope: a new `Booking.requestedEventDate`); optional guest notice through the RSVP channel; the countdown reminders reset. Payment schedules are not moved (but see L1). |
| w11_plan_switcher | «خطتك · 96 يوم · مفتوحة», «أنت مساعد · مارس», «في الذكريات · 2025 · مؤرشفة»; «خطة جديدة»; rule «خطة واحدة مفتوحة لك كصاحب عرس» | Switch; create | `GET /contexts` (gives `lifecycle`, `accessMode`, `persona`), `POST /wedding-plans/:id/set-active`, `POST /wedding-plans` | 🔧 | `GET /contexts` gets `daysToWedding?`, `dateMode`, `planType`, `roleLabel`, and lifecycle states PAUSED, DONE, ARCHIVED, SUSPENDED. `set-active` must allow an ARCHIVED plan (read-only opening of memories); today it gives 409. `POST /wedding-plans` and `import-local` (NEW mode) give `409 OWNER_OPEN_PLAN_LIMIT` when the user already owns a plan in PLANNING, PAUSED or DONE (L3). |
| w12_date_passed | «موعده كان الخميس 21 يناير» | «إيه، تم العرس» → DONE; «تأجل» → g03; «ما صار، أوقف الخطة» → x23; «اسألني بكرة» | none | ➕ | Trigger: cron, the day after `weddingDate` (or `approxEnd`) while the status is PLANNING. It creates notification `WEDDING_DATE_PASSED`, and the dashboard returns `prompt:'DATE_PASSED'`. `POST /wedding-plans/:id/complete` → `{status:'DONE', completedAt}`, owner only. `POST /wedding-plans/:id/date-prompt/snooze {until?: default +1d}` → 204. Errors: `409 PLAN_NOT_PLANNING`. |
| x23_pause_plan | What stops and what is kept; «حجوزات فيها عرابين» (three, with amounts) | Choice «بلّغهم عني بأدب، واطلب الاسترجاع» (a ready message for each provider, previewed) or «أبلّغهم بنفسي»; «أوقف الخطة»; «تبغى تأجيل بس؟» → g03 | none | ➕ | `GET /wedding-plans/:id/pause/preview` → `{bookingsWithDeposit:[{bookingId, providerName, depositPaid, conversationId?, draftMessage}], remindersToStop, loanRemindersContinue: n}`. `POST /wedding-plans/:id/pause {providerNotice: 'APP_SENDS'\|'SELF', messages?: [{bookingId, body}]}` → `{status:'PAUSED', pausedAt}`. Owner only. No reason field (design: «ما نسألك ليش»). Side effects: task, payment and countdown reminders stop; loan repayment reminders **continue**; members get `PLAN_PAUSED` with no reason; with APP_SENDS a chat message goes to each booking's conversation. Bookings are **not** cancelled automatically (L5). Writes become read-only except money refunds and loan repayments. |
| x24_plan_paused | «خطتك متوقفة»; «العرابين: 600 من 900 ألف رجعت» per provider (refunded, promised); loan «سلفة خالي أحمد باقي منها 300 ألف» | «رجّع الخطة»; «احذفها نهائيًا» → w15; «ذكّرهم» (per provider) | money: `POST /cost-payments/:id/reverse` (refund as a reversal) | ➕ | `GET /wedding-plans/:id/pause/summary` → `{deposits:[{costId, providerName, deposit, refunded, status: REFUNDED\|PARTIAL\|PROMISED\|NONE, promisedNote?}], totals, loans:[{sourceName, outstanding}]}`. `POST /wedding-plans/:id/resume` → `{status:'PLANNING'}`; reminders are rebuilt; members get `PLAN_RESUMED`. `POST /wedding-plans/:id/pause/deposits/:costId/remind` → sends a polite chat message to the provider (limit 1 a day; `409 NO_CONVERSATION` for a provider booked outside the app). Partial refunds need the money scope's partial-refund contract (w21). |
| w13_archive_plan | What stays: everything readable; «الرفد المتأخر تقدر تسجله، والشكر ترسله»; «التذكيرات توقف، إلا أقساط السلف»; members read-only; loan line | «حطها في الذكريات» | `PATCH /wedding-plans/:id/archive` (PLAN_W, one-way, blocks every write) | 🔧 | `POST /wedding-plans/:id/archive` → `{status:'ARCHIVED', archivedAt}`. **Owner only.** Allowed from DONE (and PAUSED); from PLANNING the answer is `409 PLAN_NOT_DONE`. The write rule while archived becomes an **allow-list**: rafd (gift) entries, thank-you sends, loan repayments, refunds, and reading or exporting. Everything else gets 409 `PLAN_ARCHIVED_READ_ONLY`. Members keep read access (today their invites are revoked; their memberships are kept). Keep the old PATCH as an alias. |
| w14_archived_view | «في الذكريات من 15 فبراير», «9.6 مليون المصروف», «412 حضروا», «2.1 مليون الرفد», «38 باقي ما وصلهم شكر» | «رجّعها»; «سجّل رفد وصل متأخر»; «نزّل ملخص العرس (PDF)» | none | ➕ | `GET /wedding-plans/:id/memories` → `{archivedAt, weddingDate, spentTotal (MONEY_R), attendedCount, rafdTotal (MONEY_R), thanksPending}`. `POST /wedding-plans/:id/restore` → back to the status before archive (DONE). Owner only. `409 OWNER_OPEN_PLAN_LIMIT` if restoring would make a second open plan; that is not possible from DONE, but is possible if the user archived and then made a new plan, so DONE counts as not open for the limit (L3). PDF: `POST /users/me/exports {scope:'PLAN', format:'PDF'}`. |
| w15_delete_plan | «حذف "عرس محمد"», impact: «المال والإيصالات والرفد», «23 مهمة و140 ضيف», members to notify, «حجزين مؤكدين ينلغون»; nudge toward pause or memories | Type the plan title to confirm | none (only whole-account erasure) | ➕ | `GET /wedding-plans/:id/deletion-impact` → `{tasks, guests, costs, receipts, members:[name], confirmedBookings:[providerName]}`. `DELETE /wedding-plans/:id {confirmTitle}`. Header `X-Client-Request-Id` is required. Response `{deleted:true, receipt}`. Owner only (`404` to others, `400 CONFIRM_TITLE_MISMATCH`). Side effects in one transaction: confirmed and requested bookings are cancelled (`cancelledBy=CUSTOMER`, `BOOKING_UPDATED` to providers); open quotes are cancelled; members get `PLAN_DELETED` and their tenures close with `PLAN_DELETED` (the enum already exists); receipt and chat media are scheduled for deletion; a `PlanDeletionReceipt` is written; then the per-plan part of the erasure saga runs. Immediate, with no grace period (unlike the account; see L13). |
| w09_local_draft | Device draft «5 بنود · 8 مهام · آخر تعديل اليوم» vs account plan «14 بند · 23 مهمة» | «ضمّها لخطتي» (duplicates are shown); «خلّها خطة ثانية»; «تجاهلها» (deleted from the phone only) | `POST /onboarding/import-local` (always a new plan) | 🔧 | `POST /onboarding/import-local/preview {targetPlanId, draft}` → `{toAdd:{costs,tasks,guests}, duplicates:[{kind, localTitle, existingId}]}`. `POST /onboarding/import-local {mode:'NEW'\|'MERGE', targetPlanId?, clientMigrationId, …, skipDuplicateIds?}` → `{imported, alreadyImported, planId}`. MERGE needs PLAN_W + TASKS + GUESTS + MONEY_W on the target. NEW is limited by `OWNER_OPEN_PLAN_LIMIT` (L3). The idempotency key stays `(ownerUserId, importMigrationId)`, now on the merge target. |

### 1.7 Bride profile (plan type drives theme, wording and categories)

| Concern | Reads | Existing | Status | Proposed contract |
|---|---|---|---|---|
| Plan type | `planType` on every plan context | `WeddingPlan.persona {GROOM,BRIDE,HELPER}`, exposed in `/contexts` as `persona` | 🔧 | Add `planType: GROOM\|BRIDE` on the plan; it is required and set once at creation. `persona=HELPER` becomes invalid for a plan (it describes a user, not a plan). Migrate: existing plans with HELPER or null map to GROOM unless the owner's `User.persona=BRIDE`. The theme and wording file come from the **selected plan's** `planType`, not from `User.persona`. A helper switching between a groom plan and a bride plan in w11 therefore sees the colour change. |
| Categories | Provider categories and starter items per type | `ProviderCategory.showForGroom/Bride`, `ReferenceCatalogItemRevision.showForGroom/Bride` | ✅ | Use the existing flags. |
| Events | السمرة، المقيل، الزفاف vs الحفلة، النسمة، الزفة | none (no event model) | ➕ | Seeded from the `wedding_events` catalog by `planType`. The events entity belongs to another scope (b12/b13). |
| Mahr direction | Groom «سلّمت / يسلّمه», bride «استلمتِ / تستلمه» | none | ➕ | `PlanMahr.direction` comes from `planType` (PAY for the groom, RECEIVE for the bride). For the bride, money received counts as **incoming** in money summaries and is never shown as a cost. |
| Partner label | «أهل العروسة» vs «العريس» | `CostPayer {GROOM,BRIDE,FAMILY,…}`, `GuestSide` | 🔧 | The client derives the label from `planType`. The server keeps the neutral enums. |
| Plan title | «عرس محمد وسلمى» vs «عرس سلمى ومحمد» | `title` | 📱 | The client builds it (owner name first). |

---

## 2. State machines

### 2.1 Account

```
ACTIVE ──POST /users/me/deletion──▶ DELETION_PENDING ──cron @ scheduledFor──▶ (erased; AccountDeletionReceipt)
   ▲                                   │
   └──────DELETE /users/me/deletion────┘   (restore, any time before scheduledFor)
ACTIVE ──admin──▶ DISABLED (existing)
```

| Transition | Actor | Endpoint | Side effects |
|---|---|---|---|
| ACTIVE → DELETION_PENDING | the user | `POST /users/me/deletion` | Set `deletionRequestedAt`/`deletionScheduledFor`. Every **owned** plan → `suspendedReason=ACCOUNT_DELETION` (write-blocked, members read «الخطة متوقفة» only, reminders stop). Members get `PLAN_PAUSED` with no reason. Provider profile (if any) → hidden from the directory. Other sessions are revoked; this session stays restricted. Push unregister is up to the client. Bookings are **not** cancelled yet, so a restore can bring everything back «كما هو». |
| DELETION_PENDING → ACTIVE | the user | `DELETE /users/me/deletion` | Suspension lifted, reminders rebuilt, members get `PLAN_RESUMED`. |
| DELETION_PENDING → erased | system cron (daily, advisory lock) | none | First cancel confirmed and requested bookings (`BOOKING_UPDATED` to providers: «ألغى العميل»), then notify members «طلع صاحب الخطة، والخطة انحذفت» (`PLAN_DELETED`), then run the **existing** erasure saga unchanged. `POST /account-deletions/status` → `DELETED`. |
| Member-of-others plans | — | — | During pending, the user's memberships in other people's plans are kept but inactive (they are shown no data). At purge, tenures close with `ACCOUNT_DELETED` (existing). |

### 2.2 Plan status

```
   (device) LOCAL_DRAFT ──register + import-local NEW──▶ PLANNING
                       └──login + import-local MERGE──▶ (merged into an existing PLANNING plan)
                       └──«تجاهلها»──▶ discarded (device only)

PLANNING ──pause──▶ PAUSED ──resume──▶ PLANNING
PLANNING ──complete (w12 «تم»)──▶ DONE ──archive──▶ ARCHIVED ──restore──▶ DONE
PAUSED ──archive──▶ ARCHIVED (allowed: «الذكريات» from a paused plan)
PLANNING|PAUSED|DONE|ARCHIVED ──delete (owner)──▶ (erased; PlanDeletionReceipt)
any ──owner account deletion requested──▶ suspendedReason=ACCOUNT_DELETION (overlay, not a status)
```

| Transition | Actor | Endpoint | Side effects |
|---|---|---|---|
| draft → PLANNING | new user | `/auth/register/complete` + `POST /onboarding/import-local {mode:NEW}` | Creates the plan, categories, starter tasks (with `sequence`/`offsetDays`), mahr and the pending ground helper. |
| draft → merged | user who logs in | `POST /onboarding/import-local {mode:MERGE}` | Adds the items; duplicates are skipped by choice. |
| PLANNING → PAUSED | owner | `POST …/pause` | Task, payment, countdown and date-passed reminders stop; **loan repayment reminders continue**; members get `PLAN_PAUSED` (no reason); optional polite messages to providers with deposits; bookings stay as they are; quotes stay open but providers cannot confirm a booking on a paused plan (`409 PLAN_NOT_ACCEPTING_BOOKINGS`); writes are read-only except refunds and loan repayments. |
| PAUSED → PLANNING | owner | `POST …/resume` | Reminders rebuilt from the current date; members get `PLAN_RESUMED`. If the date passed while paused, the dashboard shows the w12 prompt. |
| PLANNING → DONE | owner | `POST …/complete` | Home switches to the after-wedding layout (b07): rafd, thanks, rating (g04) unlocked; pre-wedding task and countdown reminders stop; payment and loan reminders continue; providers' rating window opens (another scope). |
| PLANNING → PLANNING (postponed) | owner | `POST …/postpone` | Open tasks shift by `deltaDays`; done tasks stay; payment schedules stay; reschedule requests go to the chosen bookings; `PLAN_DATE_CHANGED` to members; optional guest notice. |
| DONE/PAUSED → ARCHIVED | owner | `POST …/archive` | Reminders stop except loan repayments; members read-only; rafd, thanks and refunds stay writable; no new quotes or bookings; pending invites revoked (existing). |
| ARCHIVED → DONE | owner | `POST …/restore` | Back to the after-wedding mode; members regain their previous permissions. |
| any → erased | owner | `DELETE /wedding-plans/:id` | Bookings cancelled and providers told; members told; tenures closed `PLAN_DELETED`; media scheduled for deletion; receipt written. |
| auto (no transition) | system | cron | Day after the date while PLANNING: `WEDDING_DATE_PASSED` and the dashboard prompt; repeated every day the user taps «اسألني بكرة»; never changes the status by itself. |

Write policy (it replaces the single `ARCH` check): one function `planWritePolicy(status, suspendedReason, operation)`. PLANNING: everything. PAUSED: refunds, loan repayments, reading, export, resume, archive, delete. DONE: everything except new bookings and quotes for the old date. ARCHIVED: the allow-list in w13. Suspended: nothing except the owner's restore.

### 2.3 Wedding date

```
NONE ──pick month──▶ MONTH ──pick day──▶ EXACT
NONE ──x02 season──▶ APPROX ──fix date──▶ EXACT
EXACT ──g03 postpone──▶ EXACT (new date) | APPROX | NONE
EXACT|MONTH|APPROX ──date or window end passes──▶ prompt w12 (status stays PLANNING)
```

| Transition | Endpoint | Side effects |
|---|---|---|
| set or change while no dated work exists | `PATCH /wedding-plans/:id` | Tasks get dates from `offsetDays` (tentative for MONTH/APPROX). |
| change once dated tasks or bookings exist | `POST …/postpone` (w10 is routed here) | See 2.2. |
| clear (→ NONE) | `POST …/postpone {dateMode:'NONE'}` | Task due dates are cleared to `sequence` order; countdown reminders stop; bookings on the old day get reschedule requests if chosen. |

---

## 3. Logic problems found

| # | Where | Problem | Proposed fix (design side, since the design is the reference) |
|---|---|---|---|
| L1 | g03 vs w10 vs w12 | g03 says «الدفعات ما تتغير · لأنها اتفاق مع المزود». w10 says «لو غيّرت الموعد، المهام **والأقساط** تتحرك معه». w12 «تأجل» says «والمهام **والأقساط** تتحرك». A direct contradiction. | Choose one. Recommended: installments do **not** move (g03); change the w10 and w12 lines to «المهام تتحرك، والدفعات تبقى على اتفاقها». |
| L2 | g11 vs w05/w06 | g11's delete sub-line «تنحذف خطتك وكل بياناتك، **وما ترجع**» contradicts the 30-day restore window. | «تنحذف بعد 30 يوم، وتقدر تتراجع خلالها». |
| L3 | w11 vs w09 vs w11's own button | The rule «خطة واحدة مفتوحة لك كصاحب عرس» conflicts with w09 «خلّها خطة ثانية · مثلًا لو هي لعرس أخوك», with w11's «تنشئه لأحد من أهلك», and with the «خطة جديدة» button. A plan made for a brother is still owned by you. | Decide: (a) one open owned plan, and «لعرس أخوك» means creating it and then **handing ownership** to the brother (needs a transfer-ownership screen, which is missing); or (b) drop the limit. The backend has no limit today. |
| L4 | a08 / a08b / b02 vs w09 / w15 / audit 3.4 | The starter task count is «30 مهمة» in a08, a08b and home («من 30»), but «23 مهمة» in w09 and w15, and the audit says «23 مهمة جاهزة». | Use one number (the catalog decides; screens should show the real count). |
| L5 | x23 vs x24 | x23 offers «اطلب الاسترجاع» for deposits but never says whether the bookings are cancelled. x24 tracks refunds as if they were. Pausing without cancelling while asking for refunds is ambiguous for providers. | Add a line to x23: «الحجوزات تبقى محجوزة لين تلغيها» **or** «نلغي الحجوزات اللي طلبت استرجاعها». The proposed contract assumes the first. |
| L6 | w02 vs security decision | w02 shows «هذا الرقم عليه حساب من قبل» on the register form **before** the OTP. Phone ownership must be proved first (decision "Require verified phone ownership", and anti-enumeration). | Show w02's message after a09. The verified OTP then signs the user in directly («ادخل»). |
| L7 | g08 vs w07 / g02 | The g08 «قفل التطبيق» (described as «رمز أو بصمة») is drawn as an **entry pad** with a fingerprint key, almost the same as w07, which has no fingerprint. There is **no screen to set or change the PIN, or turn biometrics on or off**, and g02 only shows «قفل التطبيق: رمز». | Make g08 the lock **settings** (on/off, set PIN, confirm PIN, «البصمة», auto-lock delay). Keep w07 as the entry pad, with the fingerprint key added. |
| L8 | g02 | The account menu has no way into: g07 التنبيهات, w04 الأجهزة, w40 الخصوصية, g10 المساعدة, g11 الخروج, w10 بيانات الخطة, w11 خططك, x23 إيقاف الخطة, w13 الذكريات, w15 حذف الخطة. As drawn, those screens are unreachable from settings. | Add a «عرسي» group (بيانات الخطة، خططك، إيقاف، الذكريات، حذف) and an «الحساب» group (التنبيهات، الأجهزة، الخصوصية، المساعدة، الخروج). Move «موعد العرس» and «تأجيل العرس» under بيانات الخطة so the date has **one** entry point (w10 → g03). |
| L9 | a02_who | The main button «أنشئ حسابي» sits under the «أنشئ خطتك» and «مزود خدمة» choices, but in the plan-first flow the account comes at a08b. | Change it to «التالي» (as on a02b). |
| L10 | a07 | «ما أدري، ساعدني أحسبها» goes nowhere: no screen is defined. | Point it to a defined screen (for example w19 budget split or the w38 «ما نخمّن» state), or remove it. |
| L11 | y01 vs JOURNEY / audit | y01 is «سؤال واحد في البداية», but the onboarding is said to have «خمسة أسئلة» (a03–a07), and y01 is not placed in that order. | Place it (for example after a05), and say whether it is a sixth question or optional. Also say what happens to «صالح أخوي» before an account exists (the proposal: a pending local helper, invited after register, phone asked then). |
| L12 | a08b vs w01/w02 vs backend | a08b says «8 أحرف أو أكثر». w01 and w02 say «6 أحرف أو أكثر». The backend minimum is 6. | Use 6 on a08b. |
| L13 | w05/w06 vs w15 | Deleting the account (which deletes the plan) has a 30-day grace, but deleting just the plan is immediate «ما ترجع بعدها». Also w05 offers «نزّل نسخة» and w15 does not. | Either give w15 the same grace, or keep it immediate and **add «نزّل ملخص الخطة» to w15**. Minimum: the export link. |
| L14 | a05 vs w10 | Onboarding picks a **city** («صنعاء، عدن…»). w10 edits «المحافظة والمديرية». They are different backend models (legacy `City` vs typed `Governorate`/`District`, per the decision "Keep Yemen geography typed"). | Map a05 cities to governorates. Store `governorateId` (and later `districtId`). |
| L15 | w10 / a07 | «ريال يمني (صنعاء)» suggests regional rial notes (Sana'a vs Aden). The backend currency is just `YER`. Expat plans (y01) need SAR or USD as well. | Define `currencyRegion` values in the design (YER Sana'a, YER Aden, SAR, USD…), and say who can change it once money exists. |
| L16 | x23 vs w13 / x24 | x23 says «التذكيرات والمهام توقف» with no exception. x24 and w13 say loan installment reminders continue. | Add «إلا أقساط السلف» to x23. |
| L17 | w05 vs w06 | w05: «صالح والوالد يطلعون من الخطة… الحجوزات المؤكدة تنلغي». w06: «لين 15 نوفمبر تقدر ترجع **وكل شيء كما هو**». If members are removed and bookings cancelled when the request is made, a restore cannot bring things back «كما هو». The days do not add up either: requested 19 Oct, deadline 15 Nov = 27 days, not 30, but the title says «بعد 27 يوم» as if a few days had already passed. | Say in w05 that members are told **now** and removed **after 30 days**, and bookings are cancelled **after 30 days**. Fix the dates: 19 Oct → 18 Nov. |
| L18 | x18 vs DECISIONS "Bind offline replay to its originating session" | x18 promises «3 أشياء سجّلتها بدون نت… توصل أول ما تدخل» after a new login. The decision forbids a new token from authorizing old writes. | Update the decision: replay is allowed when the re-authenticated **userId** matches the queue owner and the plan access is still valid. A different account still drops the queue. |
| L19 | g11 / w41 | Logout while w41 has unsent changes is not covered. The decision says the queue is bound to the session, so the changes would be lost silently. | Add a state to g11: «عندك 3 تغييرات ما وصلت. انتظر النت، أو اخرج وتنحذف». |
| L20 | x19 vs w41 | Two different conflict models: x19 has the owner resolving **two other people's** offline edits (server must hold both), and w41 has the local user resolving against the server. «اسألهم في المحادثة» points to a chat between participants that does not exist (chat is provider-only). | Keep both, but change x19's second button to «اسألهم» (WhatsApp share) or remove it. Note that x19 needs a server conflict store (§4). |
| L21 | x17 (inventory text) | The inventory still says «ورسالة نصية لو واتساب ما وصل». The rendered x17 correctly says «تأكد من واتساب، أو ادخل بكلمة المرور». | Update the `screens_inventory.md` line. |
| L22 | g08 (inventory text) | The inventory calls g08 a settings item («رمز أو بصمة»), but the render is a lock pad. | See L7. |
| L23 | b08 vs g07 vs backend | b08 shows «دفعة القاعة بعد 5 أيام». g07 promises payment reminders «قبل موعدها بثلاثة أيام». The backend uses 7 days. | Pick one lead time. The proposed `paymentReminderLeadDays` default is 3; then b08 should read «بعد 3 أيام». |
| L24 | w12 vs dateMode | w12 is defined only for an exact date. When an approximate or month window ends there is no prompt («ثبت الموعد؟»), and with no date there is never a w12. | Add the variant «الموسم اللي اخترته خلص. ثبت الموعد أو اختر موسم ثاني». |
| L25 | w12 «تم» → b07 → w13 | There is no rule for when «الذكريات» is suggested (g05 says «لما تسدد آخر قسط»), and w13 shows a loan still open («باقي عليك 300 ألف»). | Suggest archiving after DONE plus N days, or when the last cost installment is paid. Loans do not block archiving. |
| L26 | w14 «رجّعها» | Where a restored plan lands is not stated (planning or after-wedding). | Land in after-wedding (DONE). Planning again would need «تأجل» semantics. |
| L27 | x24 «احذفها نهائيًا» → w15 | w15 nudges «أوقف الخطة بدل الحذف», but the plan is already paused. | Hide the pause nudge when the plan is PAUSED; offer only «حطها في الذكريات». |
| L28 | w09 vs DECISIONS "unimported guest plan … explicit double-confirmed discard" | «تجاهلها · تنحذف من الجوال بس» followed by one «متابعة» is a single confirmation. | Add a second confirm sheet, or update the decision. |
| L29 | Bride wording, w06 | The groom has «تراجعت، رجّع حسابي». The bride version is «تراجعت، **رجّعوا** حسابي». The user is talking **to the app**, and by JOURNEY_PROFILE §2 that must stay the same in both versions. | Use «تراجعت، رجّع حسابي» for both. |
| L30 | a02b bride card vs JOURNEY_PROFILE | The bride card says «في مسارك الخاص», while JOURNEY_PROFILE says «ما فيه شاشة تخص العروسة لوحدها». It is not wrong (the plan is separate), but «مسارك الخاص» reads as a different flow. | «تجهيزك وعرس النساء، في خطتك أنتِ». |
| L31 | w05/w06 with a provider account | a02 allows one phone to be both a customer and a provider («عندي حساب: عريس، عروسة، أو مزود»). Account deletion says nothing about the provider profile, its bookings or its customers. | Add a line to w05 when a provider profile exists: «ملفك كمزود وحجوزات زبائنك تنلغي ونبلّغهم». |
| L32 | Archived membership | Today archiving revokes **pending invites** (fine). The design says «المشاركين يشوفونها للقراءة بس», so memberships must stay. Code: they do stay, but `set-active` refuses archived plans, so members cannot open it. | Backend change is covered in w11 and w13. |

---

## 4. Data model changes (Prisma)

### identity.prisma
- `enum UserStatus { ACTIVE, DISABLED, DELETION_PENDING }`.
- `User`: `deletionRequestedAt DateTime?`, `deletionScheduledFor DateTime?`, `deletionClientRequestId String?`; `crashReportsEnabled Boolean @default(true)`; `aiAssistantConsentAt DateTime?`; `reviewNameDisplay ReviewNameDisplay @default(FIRST_NAME)` (`enum ReviewNameDisplay { FIRST_NAME, FULL, HIDDEN }`). Index `(status, deletionScheduledFor)` for the purge cron.
- **New `AuthSession`**: `id cuid`, `userId`, `scope AuthSessionScope`, `deviceLabel String?`, `platform PushPlatform?`, `appVersion String?`, `approxCity String?`, `createdAt`, `lastSeenAt`, `revokedAt?`, `revokeReason String?`. `RefreshToken.sessionId String?` FK, one session per rotation chain. Index `(userId, revokedAt)`.
- OTP lockout: no table; reuse `LoginThrottle` with the subject `otp:{purpose}:{phone}`.
- **New `DataExport`**: `id`, `userId`, `scope ExportScope{ACCOUNT,PLAN}`, `weddingPlanId?`, `format ExportFormat{JSON,PDF}`, `status ExportStatus{PENDING,READY,FAILED,EXPIRED}`, `storageKey?`, `expiresAt?`, `createdAt`. Rows are cascade-deleted with the user.

### planning.prisma
- `enum WeddingPlanStatus { PLANNING, PAUSED, DONE, ARCHIVED }`. Plan deletion stays a hard delete with a receipt.
- `enum PlanType { GROOM, BRIDE }`; `WeddingPlan.planType PlanType` (backfilled from `persona`, then required). `persona` is kept for compatibility and later dropped.
- `enum WeddingDateMode { EXACT, MONTH, APPROX, NONE }`; `dateMode`, `approxMonth String?` ('YYYY-MM'), `approxKey ApproxDateKey?` (`AFTER_RAMADAN, AFTER_EID_ADHA, SUMMER, YEAR_END`), `approxStart DateTime? @db.Date`, `approxEnd DateTime? @db.Date`, `datePromptSnoozedUntil DateTime?`.
- Lifecycle: `pausedAt?`, `completedAt?`, `archivedAt?`, `restoredAt?`, `statusBeforeArchive WeddingPlanStatus?`, `suspendedReason PlanSuspendedReason?` (`ACCOUNT_DELETION`), `suspendedAt?`.
- Profile: `partnerName String?`, `residence Residence?` (`IN_YEMEN, ABROAD`), `residenceCountry String? @db.Char(2)`, `governorateId String? (uuid)`, `districtId String?`, `cityId String?`, `currencyRegion String @default("YER_SANAA")`, `budgetBand BudgetBand?`.
- Open-plan limit: a partial unique index made in raw SQL migration: `CREATE UNIQUE INDEX … ON "WeddingPlan"("ownerUserId") WHERE status IN ('PLANNING','PAUSED')` (only if L3 keeps the limit; see risks).
- **New `PlanMahr`**: `weddingPlanId @unique`, `status MahrStatus{AGREED,NOT_AGREED}`, `direction MahrDirection{PAY,RECEIVE}`, `totalAmount Decimal(14,2)?`, `settledAmount Decimal(14,2) @default(0)`, `remainderDueDate DateTime? @db.Date`, `currency`, `note?`. Gold by the gram and settlement history belong to the money scope.
- **New `PlanLifecycleEvent`** (audit + x20): `id`, `weddingPlanId`, `actorUserId?`, `fromStatus?`, `toStatus?`, `kind` (`PAUSED, RESUMED, COMPLETED, ARCHIVED, RESTORED, DATE_CHANGED, SUSPENDED, UNSUSPENDED`), `data Json`, `occurredAt`.
- **New `PlanDeletionReceipt`**: `receiptHash Char(64) PK`, `deletedAt` (like `AccountDeletionReceipt`).
- **New `PendingGroundHelper`**: not needed; held on the device until the invite.

### collaboration.prisma
- `ContributionAction` += `MEMBER_JOINED`. An owner tenure row lets owner actions be recorded. `ContributionScopeStatus.ARCHIVED` (it already exists) is used on archive and cleared on restore.
- **New `PlanEditConflict`**: `id`, `weddingPlanId`, `entityType ContributionEntityType`, `entityId`, `field String`, `baseVersion Int`, `versions Json` ([{actorUserId, value, editedAt}]), `status ConflictStatus{OPEN,RESOLVED,DISCARDED}`, `resolvedByUserId?`, `resolvedAt?`, `createdAt`. Index `(weddingPlanId, status)`.

### tasks / guests / finance (columns this scope needs; their owners should agree)
- `version Int @default(1)` on `WeddingTask`, `Guest`, `WeddingCost`, `PaymentSchedule` (w41/x19).
- `WeddingTask.sequence Int?`, `offsetDays Int?`, `isTentative Boolean @default(false)` (x01/x02, starter templates).

### notifications.prisma
- `NotificationType` += `PARTICIPANT_ACTIVITY, WEEKLY_DIGEST, WEDDING_DATE_PASSED, PLAN_PAUSED, PLAN_RESUMED, PLAN_COMPLETED, PLAN_ARCHIVED, PLAN_RESTORED, PLAN_DELETED, PLAN_DATE_CHANGED, ACCOUNT_DELETION_SCHEDULED, MAHR_DUE_SOON`. The unused `PLAN_UPDATED` can be retired or reused.
- `NotificationPreference` += `nextStepDailyEnabled Boolean @default(true)`, `paymentReminderLeadDays Int @default(3)`, `guestRepliesMode GuestRepliesMode @default(DAILY_DIGEST)`, `weeklyDigestEnabled Boolean @default(true)`, `participantActivityEnabled Boolean @default(true)`, `quietHoursStart Int? @default(1380)`, `quietHoursEnd Int? @default(420)`, `timezone String @default("Asia/Aden")`.
- `PushInstallation.permission PushPermission?` (optional, w39).

### marketplace.prisma (owned by the provider scope; listed for dependency)
- `Booking.requestedEventDate DateTime? @db.Date`, `rescheduleStatus` (g03 postpone).
- A booking-confirm guard checks plan status (`PLAN_NOT_ACCEPTING_BOOKINGS` for PAUSED, ARCHIVED or suspended).

---

## 5. Implementation order (smallest safe steps)

| Step | Change | Risk notes |
|---|---|---|
| 1 | **Design text fixes** L1, L2, L4, L9, L12, L16, L17, L21, L23, L29 (wording only), then the missing screens L7 (lock settings), L8 (account menu), L10, L19, L24, L31. | No code. They unblock the contracts below. |
| 2 | Additive plan columns with defaults: `planType` (nullable → backfill → required), `partnerName`, `dateMode` (backfill `EXACT` where `weddingDate` is set, else `NONE`), the approx fields, `residence`, `cityId/governorateId`, `currencyRegion`, `budgetBand`. `PATCH /wedding-plans/:id` accepts `weddingDate:null`. `import-local` and `onboarding/complete` accept the new fields. | Backfill from `persona`. HELPER/null plans use the owner's `User.persona`, else GROOM; run a report first. `currencyRegion` default `YER_SANAA` could be wrong for Aden plans, so backfill from the city where known. |
| 3 | Auth refinements: `attemptsRemaining`/`retryAfterSeconds` on OTP errors; OTP 15-minute lockout via `LoginThrottle`; `password-reset/verify`; reset and phone change return tokens and revoke **others** only; `ACCOUNT_ALREADY_EXISTS` carries `loginGrant`. | Changing error bodies is visible to the current mobile client; keep the `code` values stable and only add fields. A login grant on the duplicate path must reuse the already-claimed OTP inside the same transaction. |
| 4 | `AuthSession` table + `GET/DELETE /auth/sessions`, `revoke-others`. | Existing refresh tokens have no session. Migration creates one `AuthSession` per live chain head labelled «جهاز سابق». No forced logout. |
| 5 | Notification preference columns + quiet hours in push dispatch + new types (`WEEKLY_DIGEST`, `PARTICIPANT_ACTIVITY`) + lead days. | Adding enum values to Postgres (`ALTER TYPE … ADD VALUE`) cannot run inside a transaction on older Postgres. Prisma migrations need care; deploy the enum migration on its own. Quiet hours need the timezone; default to Asia/Aden. |
| 6 | `PlanMahr` + `GET/PUT …/mahr` + the onboarding hook + `MAHR_DUE_SOON` cron. | New table only. Direction depends on step 2's `planType`. |
| 7 | **Plan status extension** (`PAUSED, DONE`) + one `planWritePolicy` replacing `status===PLANNING` / `ARCH` checks (contexts `isAvailable`, the `PLAN_ARCHIVED_READ_ONLY` port, `set-active`, quotes and bookings) + `pause/preview`, `pause`, `resume`, `complete`, `date-prompt/snooze`, the `WEDDING_DATE_PASSED` cron. | This is the riskiest step: every module that checks `PLANNING` must move to the policy. Grep `WeddingPlanStatus.PLANNING` and `PLAN_ARCHIVED_READ_ONLY`. The reminder crons must skip PAUSED except loans. Ship it behind a flag; the mobile client must understand the new `lifecycle` values before the server returns them. |
| 8 | Archive becomes owner-only, reversible and allow-listed; `restore`; `memories`. | Existing ARCHIVED plans become restorable, which is a behaviour change. Their `statusBeforeArchive` is null, so restore goes to DONE. Members whose invites were revoked are unaffected; members themselves were kept. |
| 9 | Postpone preview/apply (wrapping the existing shift-due-dates in one transaction) + booking reschedule request (with the provider scope). | Shifting must be owner-safe (today it needs a member who sees the whole plan). Bookings have a unique `quoteRequestId`, so the reschedule is a field on the booking, not a new row. |
| 10 | Plan deletion: `deletion-impact`, `DELETE /wedding-plans/:id`, receipt, provider and member notifications, reusing the per-plan steps of the erasure saga. | The saga is account-shaped today; extract the plan part without changing its lock order (cost → payment; quote → conversation). Notifications must be written **before** the plan rows they reference are deleted (`Notification.weddingPlanId` is SetNull). |
| 11 | Account deletion grace: `UserStatus.DELETION_PENDING`, request, impact, cancel, restricted session claim, plan suspension overlay, a daily purge cron that calls the existing saga. `DELETE /users/me` becomes an alias that creates the request. | Behaviour change for the current client, which expects immediate `{deleted:true}` and a receipt. Return `202` with `status:'PENDING'`. `account-deletions/status` already models `PENDING`. Admin dual accounts keep the existing admin-preserving path. The cron needs an advisory lock and must be idempotent. |
| 12 | `import-local` MERGE + preview; open-plan limit (if L3 decides to keep one). | Before adding the partial unique index, count owners with more than one PLANNING plan in production; grandfather them (the limit enforced in the service only, or the extra plans archived after asking the owner). |
| 13 | Activity feed: owner tenure, `MEMBER_JOINED`, actor display names, money filtering; `version` columns + `409 EDIT_CONFLICT`; `PlanEditConflict` + resolve. | Owner tenure rows must be backfilled for existing plans (one per plan, with `trackingStartedAt=now`; older owner history stays uncovered, which matches `historyCoverageStartsAt`). The append-only trigger on `ContributionEvent` stays. Version columns default to 1, so this is safe. |
| 14 | Privacy settings + `DataExport` (JSON first, PDF later) + memories PDF. | The export contains the most sensitive data. Use private storage, signed URLs with a 24 h expiry, and erase exports with the account. |

---

## Counts

53 screens in scope, plus the bride-profile rows:
- ✅ 5: a05, a08b, a10, g02, x18
- 🔧 24: a01, a03, a04, a07, a08, a09, y01, x17, w03, w01, w02, g09, g11, w05, g07, b08, w41, x20, x01, x02, w10, w11, w13, w09
- ➕ 11: a06, w04, w06, w40, x19, g03, w12, x23, x24, w14, w15
- 📱 13: a02, a02b/a02c (2), w07/w08/g08 (3), g10, w39, b09, b10, b14, b15, w42

Bride rows: 🔧 planType and the partner label; ✅ categories; ➕ events and mahr direction; 📱 the title.
