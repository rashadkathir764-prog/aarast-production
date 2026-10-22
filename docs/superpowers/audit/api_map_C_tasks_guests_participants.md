# API map C: tasks, guests, participants and collaboration

Date: 2026-10-19. Static audit. No code was changed.

**Rule (owner decision 2026-10-19):** the design (`mobile/test/prototype/v3`) is the reference. Where the backend differs, the backend changes later. Only contradictions *inside* the design are logic problems (section 4).

Sources: `docs/superpowers/audit/screens_inventory.md`, `mobile/test/prototype/v3/{sections,more,hard,gaps_a,gaps_b,touches,smart,participant,participant2}.dart`, `docs/superpowers/audit/api_inventory.md` (abbreviated **INV**), checked against `backend/src` and `backend/prisma/schema`, plus `LOGIC_LIFECYCLE_AUDIT.md` (**LLA**) and `DECISIONS.md` (**DEC:line**).

## Legend

- Status: ✅ exists and fits · 🔧 exists, needs a change (said what) · ➕ missing, new contract · 📱 client-only (no API needed beyond what is listed)
- `P` = `/api/v1/wedding-plans/:planId`. All routes are JWT unless marked **PUB**.
- Levels: `NONE | VIEW | MANAGE` for `tasks`, `guests`, `providers`, `money`; `NONE | WRITE` for `rafd`. "Schedule" (date and program) is always visible to every participant (g06 note: «الموعد والبرنامج يشوفه كل مشارك»).
- Shared error codes used below (new unless noted):
  - `403 SECTION_LEVEL_REQUIRED {section, required, current}` replaces today's mixed `TASK_PERMISSION_REVOKED` and empty-list behaviour.
  - `404 PLAN_NOT_FOUND` for non-members (current behaviour, kept).
  - `409 PLAN_READ_ONLY {planState}` replaces `PLAN_ARCHIVED_READ_ONLY` and also covers PAUSED/MEMORIES.
  - `409 STALE_AUTHORITY {authorityVersion}` when the client sends an older `X-Authority-Version`.
- Redaction rule **R-MONEY**: any amount shown inside a non-money section (task title or meta, d05 paper rows, guest rafd, z06 savings) is returned only when the caller's `money ≥ VIEW` (rafd amounts only to the owner, or to the writer for their own entries). Otherwise the field is **absent**, never 0 (DEC:142).

---

## 1. Screen-by-screen map

### 1.1 Tasks

| id | Data read | Actions | Existing endpoint(s) | Status | Proposed contract |
|---|---|---|---|---|---|
| d01_tasks «المهام» | Header «باقي 3 هذا الأسبوع، وواحدة متأخرة»; filter chips «لي / لصالح / للوالد»; «12 من 30»; groups «متأخرة / هذا الأسبوع / هذا الشهر»; per row: title, when, assignee initial, deep-link chip («أضف الموعد»، «قارن العروض»، «سجّل الدفعة»), amount in meta («الخميس · 500 ألف») | Swipe to complete («خلصت»); tap link → target screen; share; + | `GET P/tasks`, `GET P/tasks/summary`, `PATCH /tasks/:id` (status DONE) | 🔧 (a) list is item-scoped for non-partners: change to section-level (VIEW sees every non-private task); (b) add `assignee` filter and `dueBucket`; (c) summary lacks `dueThisWeek`; (d) task has no `link` (target entity) and no `amount`; (e) apply R-MONEY to amounts and drop money links for `money=NONE` | `GET P/tasks?assignee=me\|userId\|unassigned&bucket=overdue,week,month,later,done&take&skip` → `{items: TaskResponse[], counts:{total, done, overdue, dueThisWeek, byAssignee:[{userId, name, open}]}}`. `TaskResponse` adds `createdByUserId, origin, link?{type: EVENT\|QUOTE_COMPARE\|PAYMENT_SCHEDULE\|COST\|GUESTS\|MAHR\|TASK, entityId, label}, amount?` (R-MONEY), `dueTimeOfDay?, duePrecision, blockedBy[]`, `canEdit, canComplete` (computed). Complete: `POST /tasks/:id/complete` (idempotent) → TaskResponse; errors `403 SECTION_LEVEL_REQUIRED`, `409 TASK_BLOCKED {blockedBy}`, `409 PLAN_READ_ONLY` |
| d02_add_task «مهمة جديدة» | Members list for «لمين؟» («أنا / صالح / الوالد / شخص ثاني») | Title; «متى؟» chips «هذا الأسبوع / هذا الشهر / بعد العصر / تاريخ»; assignee; «حفظ المهمة» | `POST P/tasks`, `PATCH /tasks/:id/assign`, `GET P/members` | 🔧 Create cannot set the assignee in the same call (two calls). There is no fuzzy due (`duePrecision` WEEK/MONTH) and no `dueTimeOfDay` («بعد العصر»). The assignee must hold the TASKS flag, which blocks the father (L-C03). «شخص ثاني» maps to `responsibleName/Phone` (exists). | `POST P/tasks {title, dueDate?, duePrecision: DAY\|WEEK\|MONTH, dueTimeOfDay?: DUHA\|DHUHR\|AFTER_ASR\|AFTER_MAGHRIB\|AFTER_ISHA, assigneeUserId?, responsibleName?, responsiblePhone?, isPrivate?, clientId}` → TaskResponse. Errors `400 ASSIGNEE_NOT_MEMBER`, `403 ASSIGNEE_LEVEL_NONE` (assignee needs `tasks ≥ VIEW`), `403 SECTION_LEVEL_REQUIRED(tasks, MANAGE)` |
| d03_starter «مهام جاهزة لعرسك» | Template groups by offset («الحين · قبل العرس بثلاثة أشهر», «قبل بشهرين · ديسمبر», «قبل بشهر · يناير»); each item has a relative anchor («قبل العقد», «قبل السمرة») | Toggle items; «أضف 30 مهمة لخطتي» | `GET /catalogs/bootstrap` (ReferenceCatalog) exists. `POST onboarding/import-local` takes tasks[]. No starter endpoint. | ➕ (count conflict L-C01) | Catalog `starter_tasks` in ReferenceCatalog (metadata: `offsetDays`, `anchor: WEDDING\|CONTRACT\|EVENT:<kind>`, `group`, `persona`). `GET P/tasks/starter` → `{groups:[{key, title, subtitle, items:[{key, title, suggestedDue, anchorLabel, recommended}]}], catalogVersion}`. `POST P/tasks/from-starter {catalogVersion, keys[]}` → `{created, skippedExisting}` (idempotent per `[planId, starterKey]`). Owner or `tasks=MANAGE` |
| d04_task_detail «حدد موعد عقد القران» | Tags «متأخرة 7 أيام», «لك»; due «كان 12 أكتوبر»; who «أنت»; «مرتبطة بـ المهر · الباقي 15 نوفمبر»; checklist «خطوات صغيرة»; contact «الأمين الشرعي · الشيخ عبدالله المطري · من الوالد»; linked task «جهّز أوراق العقد · مهمة مرتبطة · 1 من 4 جاهزة» | «خلصت», «أجّلها», add step, call or WhatsApp the contact, edit contact, ⋯ menu | `GET /tasks/:id`, `POST/PATCH/DELETE /tasks/:id/checklist[/:itemId]`, `PATCH /tasks/:id` | 🔧 The checklist exists. Missing: the link to the mahr (R-MONEY: the «الباقي» date and amount only when `money ≥ VIEW`), a plan contact entity (`responsibleName/Phone/Source` is per-task, but the officiant is shared and also shows in y11 «الناس»), task-to-task relations, and snooze | `GET /tasks/:id` → TaskResponse + `checklist[]`, `contact?{id, name, phone, roleLabel, sourceLabel}`, `related[]{taskId, title, progress:{done,total}}`, `link?`. `POST /tasks/:id/snooze {until?\|preset: TOMORROW\|NEXT_WEEK}` → TaskResponse (+`snoozeCount`). Contacts: `GET/POST P/contacts`, `PATCH/DELETE /contacts/:id {name, phone, roleLabel, sourceLabel, sharedWithParticipants}` |
| d05_contract_papers «جهّز أوراق العقد» | «1 من 4 جاهزة»; «عليك»: «بطاقتك الشخصية», «شاهدين ومعهم بطاقاتهم · صالح أخوي · ناقص واحد» (chip «اختر»), «المهر كما اتفقتوا · 3,000,000 · ينكتب في العقد», «اللي بتسلّمه يوم العقد · 2,000,000 · من خطتك المالية»; «عند أهل العروسة»: «بطاقة الولي وأوراق العروسة» tag «عندهم» | Tick items; pick a witness; «كل الأوراق جاهزة»; «اسأل الشيخ عبدالله على واتساب» | checklist endpoints | 🔧 The checklist item has only `title/isDone/sortOrder`. It needs `holder` (ME / OTHER_SIDE), `note`, `linkedPersonId` (witness) and `moneyRef` (R-MONEY). The task needs `kind=CONTRACT_PAPERS` | `PATCH /tasks/:id/checklist/:itemId {isDone?, holder?: ME\|OTHER_SIDE, note?, linkedUserId?\|linkedContactId?}`. The item response adds `moneyRef?{type: MAHR_TOTAL\|MAHR_DUE_AT_CONTRACT, amount?}` (amount only if `money ≥ VIEW`). `POST /tasks/:id/complete {completeChecklist:true}` |
| x16_task_menu «رتّب سيارات الزفة · لصالح · قبل 15 يناير» | Task title, assignee, due | «حوّلها لأحد ثاني» («الوالد، أو أنت»), «غيّر موعدها» (free text «بعد العصر»), «أعد فتحها» («لو انقفلت بالغلط»), «ما نحتاجها» («تنلغي وتبقى في السجل») | `PATCH /tasks/:id/assign`, `PATCH /tasks/:id` (dueDate, status TODO/CANCELLED) | 🔧 Reassign to a VIEW member is rejected today (needs TASKS). Reopen and cancel work through generic PATCH, so add explicit verbs for idempotency and history. Free-text time is parsed on the client 📱 into `dueDate + dueTimeOfDay` | `POST /tasks/:id/reassign {assigneeUserId\|null(=owner)}`; `POST /tasks/:id/reschedule {dueDate, duePrecision, dueTimeOfDay?}`; `POST /tasks/:id/reopen`; `POST /tasks/:id/cancel {reason?}`. All → TaskResponse; errors `409 TASK_STATE_INVALID {from,to}`, `403 TASK_NOT_EDITABLE` (manage scope, §2.3), `403 TASK_PRIVATE_ASSIGNMENT` (exists) |
| w24_timeline «المهام · على الوقت» | Toggle «القائمة / الوقت»; months «أكتوبر», «نوفمبر · الحين», «ديسمبر», «يناير» with done or open tasks | Toggle view | `GET P/tasks`, `GET P/timeline` | 📱 Group by month on the client from the task list (dueDate plus wedding date). `GET P/timeline` stays for payment schedules (money-gated) | none beyond d01 |
| w25_private_task «مهمة جديدة» + «خاصة» | — | Toggle «خاصة · ما يشوفها غيرك، حتى المشاركين»; «أضف» | `POST P/tasks {isPrivate}` (seesWholePlan only, else 403 `TASK_PRIVACY_NOT_ALLOWED`; `TASK_PRIVACY_AT_CREATION_ONLY`) | 🔧 Visibility `privateToUserId ∈ {null, me}` already fits. The "who may create" rule must move off `seesWholePlan`: owner always, and participants with `tasks=MANAGE` (decision needed, L-C07). Private tasks need `createdByUserId` | `POST P/tasks {…, isPrivate:true}`. A private task is never returned to others, never counted in others' summaries, cannot be assigned to others (existing `TASK_PRIVATE_ASSIGNMENT`), and is not "returned to owner" on leave (§3.1) |
| w26_overdue «المهام · 3 متأخرة» | Overdue rows «كان قبل 5 نوفمبر · متأخرة 4 أيام», who («عليك»، «صالح»); note «التأخير ما يأثر على الموعد. نبلّغك بس إذا مهمة متأخرة توقف شيء ثاني…» | «أجّل» one tap | `GET P/tasks`, `PATCH /tasks/:id`; cron `TASK_OVERDUE` for every overdue task | 🔧 Add `overdueDays`. The snooze verb (d04). The notification policy changes: owner gets `TASK_OVERDUE` only when the task blocks another task or a dated dependency; the assignee still gets due-soon reminders (q21) | `GET P/tasks?bucket=overdue` → items with `overdueDays, blocks[]{taskId,title}`. `POST /tasks/:id/snooze`. Scheduler: emit `TASK_BLOCKING_OVERDUE` (new type) to owner |
| z05_smart_tasks «مهام تجي لحالها» | Banner «صالح عنده 7 مهام والوالد وحدة. تحوّل للوالد اثنتين؟»; auto tasks «ادفع عربون فرقة الأفراح · 100 ألف · قبل 25 أكتوبر» badge «جات لحالها من المزودين», «أكّد عدد الضيافة · 112 متوقع · قبل نوفمبر» badge «جات لحالها من الضيوف»; blocked «أرسل الدعوات · تنفتح لما تحدد موعد عقد القران» badge «تنتظر: حدد موعد عقد القران» | «وزّعها»; open task | none | ➕ (a) system-generated tasks with `origin` and `source`, created from payment schedules or bookings (amount R-MONEY) and from the guest forecast (z06); (b) dependencies; (c) load-balancing suggestion that respects levels (L-C24) | `TaskResponse.origin: MANUAL\|STARTER\|PROVIDER\|GUESTS\|MONEY\|SYSTEM`, `source?{type, id}`, `blockedBy[]{taskId,title}`. `POST /tasks/:id/dependencies {dependsOnTaskId}` / `DELETE /tasks/:id/dependencies/:dependsOnTaskId` (`409 TASK_DEPENDENCY_CYCLE`). `GET P/tasks/suggestions/rebalance` → `{suggestion?:{fromUserId, toUserId, taskIds[], text}}`. `POST P/tasks/rebalance {fromUserId, toUserId, taskIds[]}` → `{moved}` (owner only). Auto-generation is idempotent per `[planId, origin, sourceId]` |

### 1.2 Guests

| id | Data read | Actions | Existing endpoint(s) | Status | Proposed contract |
|---|---|---|---|---|---|
| e01_guests_men «الضيوف» | Header «124 مدعو · 86 أكدوا · 20 ما ردّوا»; «قاعة سبأ تتسع 150 · باقي 26 مقعد»; stacked bar confirmed, pending, declined; «حسب العائلة» rows: name, side or responsible («أهل العريس · يرسل لهم الوالد», «أهل العروسة», «محمد»), `yes/all` | «ذكّر الـ 20 على واتساب»; «بطاقة الدعوة»; search; + | `GET P/guests/summary` (byGroup, bySide, byAttendanceStatus), `GET P/guest-groups` | 🔧 (a) summary is contributor-scoped: make it section-level; (b) groups lack `side` and `responsibleUserId` («يرسل لهم الوالد»); (c) per-group confirmed counts; (d) venue capacity has no source (L-C08) | `GET P/guests/summary` → `{invited, confirmed, pending, declined, companionsConfirmed, venue?{name, capacity, source: BOOKING\|MANUAL, remainingSeats}, groups:[{id, name, side, responsible?{userId,name}, total, confirmed}]}` (`guests ≥ VIEW`) |
| e03_contacts «من جهات الاتصال» | Device contacts grouped by family («آل الحمدي · 6 من جهاتك»); duplicate warning «موجود من قبل» | Search; tick; «اختر العائلة»; «أضف 7 ضيوف لعرسك» | `POST P/guests/bulk` (skips phone duplicates silently, returns `{created}`) | 🔧 Reading contacts and grouping by surname is 📱. The duplicate check needs a server dry-run (phone and normalized name). Bulk must return per-item results and accept `groupName` to create a group inline | `POST P/guests/bulk {dryRun?:bool, groupId?\|groupName?, side?, items:[{clientId, name, phone?, companionsCount?}]}` → `{results:[{clientId, outcome: CREATED\|WOULD_CREATE\|DUPLICATE_PHONE\|POSSIBLE_DUPLICATE_NAME, guestId?, existingGuestId?}], created, groupId?}`. Max 500 items; `guests=MANAGE`; `409 PLAN_READ_ONLY` |
| e04_invite «بطاقة الدعوة · بدون صور» | Card: «يتشرف · عبدالرحمن الحمدي · بدعوتكم لحضور حفل زفاف نجله · محمد», «الخميس · 21 يناير», «13 شعبان · بعد العصر», «المكان · قاعة سبأ», «أكّد حضورك» | «أرسلها لـ 124 ضيف»; «كل ضيف يوصله رابط خاص يرد منه بضغطة» | `POST /guests/:id/invitation-link` (one guest, hash only) | ➕ Card model (host name and relation) and bulk send. Delivery channel undefined (L-C05). Links must be resendable (L-C06) | `GET/PUT P/invitation-card {hostName, hostRelation: SON\|DAUGHTER\|BROTHER\|SELF…, honoreeName, eventId?, timeLabel, venueLabel}` (owner or `guests=MANAGE`). `POST P/guests/invitations/send {guestIds[]\|filter:{status:NOT_SENT, groupId?}, senderUserId?, mode: SERVER\|DEVICE}` → `{queued, noWhatsapp:[{guestId, name, link}], device?:[{guestId, waUrl}]}` (`guests=MANAGE`; errors `409 CARD_INCOMPLETE`, `422 NO_RECIPIENTS`) |
| e05_rsvp «أهلًا أحمد» (public page) | URL «aarast.app/rsvp/…»; «عبدالرحمن الحمدي يدعوك لزفاف محمد»; «الخميس 21 يناير · 13 شعبان», «بعد العصر», «قاعة سبأ · حدة، صنعاء»; «ما تحتاج تنزل أي تطبيق» | «إن شاء الله حاضر» / «أعتذر»; «كم معك؟» «لحالي / +1 / +2 / +3» | **PUB** `GET/POST /public/rsvp/:token` | 🔧 Add `hostName`, `honoreeName`, `hijriDate`, `timeLabel`, `venueLabel`, `area`. Record `openedAt` on first GET (e07 «فتح الرابط»). Allow changing the answer until the wedding day | **PUB** `GET /api/v1/public/rsvp/:token` → `{guestFirstName, hostName, honoreeName, date, hijriDate, timeLabel, venueLabel, areaLabel, attendance, companionsCount, maxCompanions, respondedAt, canChange}`; `POST {attendance: CONFIRMED\|DECLINED, companionsCount 0..3}`; errors `404 RSVP_LINK_NOT_FOUND` (exists), `400 RSVP_INVALID_COMPANIONS` (exists), `410 RSVP_CLOSED` (after the wedding or plan not live) |
| e06_add_guest «ضيف جديد» | Group chips «آل الحمدي / آل السقاف / الأصحاب / العمل / جديدة» | Name; «رقم الجوال (اختياري)»; family; «كم معه؟» «لحاله / +1 / +2 / +3»; «حفظ» / «حفظ وأضف التالي» | `POST P/guests`, `POST P/guest-groups` | 🔧 On duplicate, return `existingGuestId`. Allow `groupName` for inline «جديدة». Drop the dual `status` vs `attendanceStatus` in the response | `POST P/guests {clientId, name, phone?, groupId?\|groupName?, side?, companionsCount}` → GuestResponse; `409 GUEST_DUPLICATE_PHONE {existingGuestId}` |
| e07_guest_detail «عبدالله الحمدي» | «آل الحمدي · +1»; tag «أكّد حضوره»; «الدعوة»: «انرسلت الدعوة · 2 نوفمبر», «فتح الرابط · 2 نوفمبر», «أكّد الحضور مع واحد · 3 نوفمبر»; «الرفد»: «رفدك 20,000 يوم العرس · ترده في عرسه» | Call; WhatsApp; ⋯ | `GET /guests/:id` (contributor: own-created only) | 🔧 Section-level read. Add the invitation timeline (`sentAt`, `openedAt`, `respondedAt`). The rafd block is owner-only (L-C33) and needs a rafd entity (map B) | `GET /guests/:id` → GuestResponse + `invitation:{sentAt?, openedAt?, respondedAt?, remindedAt?, channel}`, `rafd?{received:[{amount, eventLabel}], reciprocity?{weddingDate?}}` (owner only; omitted otherwise) |
| e08_reminder «تذكير اللي ما ردّوا» | Recipients chips «ياسر، مراد، فهد، سامي، نبيل، +15»; preview «أهلًا ياسر · نذكرك بزفاف محمد الحمدي يوم الخميس 21 يناير، بعد العصر في قاعة سبأ. · رد علينا من هنا بضغطة: aarast.app/rsvp/…» «باسم والد العريس» | «عدّل الرسالة»; «الوالد يرسلها»; «أرسل لـ 20 ضيف» | none | ➕ The reminder must reuse each guest's existing link, but only a hash is stored today (L-C06). The sender is the father (L-C04) | `GET P/guests/invitations/reminder-preview?filter=pending` → `{recipients:[{guestId, firstName}], template, senderUserId}`; `POST P/guests/invitations/remind {guestIds[]\|filter, messageOverride?, senderUserId?, mode}` → `{queued, skippedNoLink, noWhatsapp[]}`. Rate limit: 1 reminder per guest per 24 h (`429 REMINDER_TOO_SOON`) |
| x21_guests_empty «مين بتعزم؟» | «ما أضفت أحد بعد» | «من جهات الاتصال»; «عدد تقريبي بس · مثل 120، والأسماء بعدين»; «ضيف واحد» | none for the estimate | ➕ estimated guest count on the plan | `PATCH P/guest-estimate {estimatedGuestCount}` → `{estimatedGuestCount}`. It also feeds z06 when there are no names (`guests=MANAGE`) |
| w27_guest_groups «المجموعات · رتّب ضيوفك» | Side chips «أهلنا / أهل العروسة»; groups «الأهل · 42 ضيف», «الحارة», «زملاء الشغل», «أصحاب الجامعة», «بدون مجموعة · 16 ضيف» | «مجموعة جديدة»; reorder; delete («حذف مجموعة ما يحذف ضيوفها، ينقلهم "بدون مجموعة"») | `GET/POST P/guest-groups`, `PATCH/DELETE /guest-groups/:id` (FK SetNull ✅) | 🔧 Add `side`, `responsibleUserId`, counts, an ungrouped count, and bulk reorder. Uniqueness becomes `[plan, side, name]` | `GET P/guest-groups?side=OURS\|OTHER_SIDE` → `{groups:[{id,name,side,sortOrder,count,responsible?}], ungroupedCount}`; `POST P/guest-groups {name, side, responsibleUserId?}`; `PUT P/guest-groups/order {side, ids[]}`; `DELETE /guest-groups/:id` → `{movedToUngrouped}` |
| w28_bulk_guests «أضف مجموعة ضيوف» | Pasted lines; «فهمناها كذا»: «عبدالله الحمدي · 771 234 567», «يحيى السنيدار · بدون رقم», «أحمد ناجي · موجود من قبل · ما نضيفه مرتين»; target «المجموعة: الحارة», «أهلنا» | «أضف 12 ضيف» | `POST P/guests/bulk` | 🔧 same as e03: dry-run, per-line outcome, group and side for all items. Line parsing (name + optional number) can be 📱, with the server re-validating | same contract as e03 (`dryRun:true` first, then commit) |
| w29_guests_offline «الضيوف · 140 ضيف» | Cached list with status tags «أكد / ما رد / اعتذر»; «آخر تحديث قبل 20 دقيقة»; «تشوف القائمة. الإضافة والدعوات لما يرجع النت.» | Read only offline | `GET P/guests` | 📱 + 🔧 Add `ETag`/`updatedSince` so the client can show «آخر تحديث» honestly. The add-offline rule is ambiguous (L-C22) | `GET P/guests?updatedSince=` → `{items, deletedIds[], serverTime}`; `If-None-Match` → 304 |
| z06_attendance «كم بيحضر فعلًا؟» | «تقريبًا مع المرافقين»; segments «أكدوا / ما ردّوا / اعتذروا»; «86 أكدوا ومعهم 16 مرافق، ومن اللي ما ردّوا يجي عادة النص تقريبًا.»; suggestion «اطلب الضيافة لـ 118 مو 124 · 112 متوقع، و6 احتياط · تقريبًا 75 ألف توفير…»; «القاعة 130 · تكفي ومعك 18 كرسي» | «عدّل العدد»; «خلّه» | `GET P/guests/summary` | ➕ Forecast with source and sufficiency (DEC:258 / w38). Savings follow R-MONEY. Target of «عدّل العدد» undefined (L-C23) | `GET P/guests/attendance-forecast` → `{invited, confirmed, companions, pending, declined, expected, method: CONFIRMED_PLUS_HALF_PENDING, sufficient: bool, reason?, recommendedCatering?{count, reserve}, estimatedSaving?{amount, currency}` (only `money ≥ VIEW`), `venue?{capacity, spare}`}. `PUT P/catering-headcount {count}`; `POST P/suggestions/:key/dismiss` |

### 1.3 Participants and collaboration (owner side and participant side)

| id | Data read | Actions | Existing endpoint(s) | Status | Proposed contract |
|---|---|---|---|---|---|
| g01_family «المشاركين · مين يساعدك في عرسك» | Members: «صالح · أخوي · يساعد في المهام والضيوف · ويكتب الرفد», «الوالد · يشوف ملخص شهري بدون تفاصيل», «سلمى · العروسة · تشوف الموعد والبرنامج · بدون المال»; note «سلمى لها خطتها لجانبها…»; presets «مساعد / أهل / كاتب الرفد / يشوف بس» | Open member; «أضف مشارك»; «من جهات الاتصال» | `GET P/members` (role + 7 booleans) | 🔧 Return `preset`, `levels`, `relation`, and a server-composed `summaryAr`. Owner only (MEMBERS delegation retired, L-C31) | `GET P/members` → `{members:[{memberId, userId, name, relation, preset, levels:{tasks,guests,providers,money,rafd}, state: ACTIVE, joinedAt, authorityVersion}], invites:[…x07], former:[…x07]}` |
| g06_add_participant «أضف صالح · 771 554 220» | Presets «مساعد / أهل / كاتب الرفد / يشوف بس / العروسة»; levels «المهام / الضيوف / المزودين / المال» each «لا / يشوف / يعدّل», «الرفد» «لا / يكتب»; note «الموعد والبرنامج يشوفه كل مشارك. "المال: يشوف" يعني المجاميع بدون مصادر الفلوس والسلف.» | Pick preset, adjust levels, «أرسل الدعوة على واتساب» | `POST P/invites` (role + can* flags, default 14 days), `GET /users/lookup` | 🔧 Replace can* flags with `preset + levels`; expiry fixed at 7 days; add `relation`; WhatsApp-only delivery (exists via OpenWA, DEC:188); return `copyLink` when the number has no WhatsApp | `POST P/invites {name, phone, relation, preset, levels:{tasks,guests,providers,money,rafd}}` → `{inviteId, state, expiresAt(+7d), delivery:{status: PENDING\|DELIVERED\|UNCERTAIN\|UNAVAILABLE}, link?}` (the raw link is returned once, on create or reissue). Errors `409 ALREADY_MEMBER`, `409 INVITE_ALREADY_PENDING {inviteId}`, `400 OWNER_PHONE`, `400 LEVEL_INVALID` |
| x04_from_family «تساعد في عرس أحد؟» | Clipboard link «aarast.app/j/7KQ2…» («لقينا رابط في الحافظة. نفتحه؟») | «افتح الرابط»; «اطلب منه يضيفك · نجهز لك رسالة ترسلها له»; «أو أنت عريس؟ ابدأ خطتك» | token format checked in `invite-access.service.ts` | 📱 Clipboard detection and the prefilled WhatsApp text to the groom happen on the device. Then x05 or q01 | `GET /invites/:token/preview` (see x05) |
| x05_invite_landing «محمد يبغاك معه في عرسه» | «الخميس 21 يناير · صنعاء»; «بتقدر:» «تشوف الموعد والبرنامج», «تشوف المهام وتخلّصها», «تضيف ضيوف وترتبهم», «تكتب الرفد يوم العرس», «المال» (locked); note «محمد يقدر يغيّرها…» | «أبشر، معك»; «مو الحين» | `GET /invites/:token` (JWT, after OTP) | ➕/🔧 The design shows inviter, date and city before phone proof. That conflicts with DEC:188 (L-C11). Proposal: a minimal public preview; permissions only after OTP | **PUB** `GET /api/v1/invites/:token/preview` → `{state: PENDING\|EXPIRED\|REVOKED\|ACCEPTED, inviterFirstName, inviterInitial, weddingDate?, city?, persona}` (no phone, no levels; T20/min; sets `openedAt`). Errors `404 INVITE_NOT_FOUND` |
| x06_helper_home «أهلًا صالح · عرس محمد · أنت مساعد» | Countdown «يوم على عرس أخوك · الخميس 21 يناير · قاعة سبأ»; next task «رتّب الغداء مع أبو علي · محمد عطاك هذي المهمة · لأن أبو علي يبغى العدد قبل أسبوعين»; «مهامك» list; note «المال مخفي عنك. لو تحتاج تسجّل مبلغ، اطلب من محمد يفتح لك.» | «خلصت»; «كلّم أبو علي»; open task; request money | `GET /dashboard/home`, `GET P/dashboard-summary` | 🔧 Home must be level-driven: assigned tasks, relation wording («عرس أخوك»), task `reason` and `contact`, money absent (not zero). Add `requestableSections` | `GET /api/v1/dashboard/home` → `{context:{planId, ownerName, relationToOwner, persona, theme}, myRole:{preset, levels}, countdown, nextTask?{…TaskResponse, reason, contact?}, myTasks[], locks:[{section, requestable, pendingRequestId?}]}` |
| x07_participant_states «المشاركين · مين معك، ومين لسا» | «صالح · أخوي · مساعد · فعّال» «معك»; «ينتظرون»: «الوالد · الدعوة وصلت أمس · ما فتحها», «عادل · رقمه ما عليه واتساب · أرسل له الرابط بأي طريقة»; «طلعوا»: «فهد · طلع من الخطة 10 أكتوبر · مهامه رجعت لك» | «ذكّره»; «انسخ الرابط»; «أضفه» | `GET P/members`, `GET P/invites` (deliveryStatus ✅), `POST …/invites/:id/reissue` (cooldown), `DELETE …/invites/:id` | 🔧 Add `openedAt` (x05 preview), a remind action that does not silently kill the link already sent (L-C06), copy link (= reissue, returns a raw link), and former members (from ContributorTenure) with `tasksReturned` | `POST P/invites/:inviteId/remind` → `{delivery}` (`429 REMIND_TOO_SOON`); `POST P/invites/:inviteId/reissue` → `{link, expiresAt}` (old token dies; 7 days from now); `GET P/members?include=invites,former` (shape in g01) with `former[]{userId, name, endedAt, endReason: LEFT\|REMOVED, tasksReturned}`; «أضفه» = `POST P/invites {…, previousMemberUserId}` (prefills the old levels) |
| y10_father_home «عرس محمد · خط كبير» | «بعد 96 يوم · الخميس 21 يناير · قاعة سبأ»; «مطلوب منك»: «كلّم الأمين الشرعي · عن موعد العقد», «أكّد عدد آل السقاف · كم بيحضر منهم؟»; «الضيوف»: n «أكّدوا من 124 مدعو» | Act on assigned items | `GET /dashboard/home` | 🔧 Same as x06. Viewers must be able to hold and complete assigned tasks (L-C03). Large text is a device setting 📱 | same as x06; tasks with `canComplete:true` for the assignee at `tasks=VIEW` |
| w16_invite_states «الدعوة · لما الرابط ما يفتح» | «الدعوة انتهت · الرابط يشتغل 7 أيام…»; «الدعوة انلغت · محمد لغاها…»; «الدعوة لرقم ثاني · وصلت لـ 771 554 220 وأنت داخل بـ 777 123 456.»; «أنت معهم من قبل · قبلت هذي الدعوة 3 أكتوبر.» | «اطلب دعوة جديدة من محمد»; «كلّم محمد على واتساب»; «ادخل بالرقم المدعو»; «افتح عرس محمد» | All failures collapse to `404 INVITE_NOT_FOUND_FOR_PHONE` (`invite-access.service.ts:108`) | 🔧 Distinguishable states for the token holder (the token is 256-bit, so this enumerates nothing). Show the invited phone masked (L-C19). Expiry 14 → 7 days. Add a renewal request | Preview `state` (x05) plus JWT `GET /invites/:token` errors: `410 INVITE_EXPIRED {expiredAt}`, `410 INVITE_REVOKED`, `403 INVITE_PHONE_MISMATCH {invitedPhoneMasked:"77•••4220"}`, `409 INVITE_ALREADY_ACCEPTED {contextKey, acceptedAt}`. `POST /invites/:token/renewal-request` (**PUB**, T5/min, only when EXPIRED) → `202` + `INVITE_RENEWAL_REQUESTED` notification to the inviter |
| q01_invite_phone «دعوة للمشاركة · رقم الهاتف» | Steps «رقم الهاتف · التحقق · الدعوة»; inviter header «محمد يبغاك معه في عرسه · الخميس 21 يناير · صنعاء» | «771 554 220» → «إرسال رمز التحقق» («نفس الرقم اللي وصلته الدعوة عليه.») | **PUB** `POST /invites/:token/request-otp` → `{…, accountSetupRequired}` | 🔧 Header data comes from the new preview. A wrong phone returns `403 INVITE_PHONE_MISMATCH` (masked) instead of a generic 404, so the w16 path can show | as existing + preview |
| q02_invite_account «حسابك في اعّرست» | «أول مرة تدخل؟ نسوي لك حساب، وتقدر بعدين تبدأ خطتك أنت كمان.» | «اسمك», «كلمة المرور», «تأكيد كلمة المرور» → «متابعة إلى رمز التحقق» | **PUB** `POST /invites/:token/verify-otp {phone, code, name?, password?}` | ✅ (shown only when `accountSetupRequired`; DEC:188 one OTP) | — |
| q03_invite_decision «الدعوة · دورك: مساعد» | «الموعد والبرنامج», «المهام: تشوف وتخلّص», «الضيوف: تضيف وترتب», «تكتب الرفد يوم العرس», «المال» ✗, «المزودين» ✗; «محمد يقدر يغيّرها، وأنت تقدر تطلع من الخطة متى ما بغيت.» | «قبول والانضمام»; «رفض الدعوة» | `GET /invites/:token`, `POST /invites/:token/accept`, `POST /invites/:token/decline` | 🔧 Response carries `preset + levels + relation` instead of flags. Accept returns a `contextKey` (exists) | `GET /invites/:token` → `{inviteId, inviter{name}, plan{date, city, persona}, preset, levels, relation, expiresAt}`; accept → `{contextKey, memberId, authorityVersion}`; errors as w16 |
| q04_choose_path «اختر المسار» | «وش تفتح الحين؟ ما نطلب منك دخول مرة ثانية.»; contexts «عرس محمد · أخوك · الخميس 21 يناير · مساعد», «عرس ليلى · بنت عمك · تكتب الرفد · مساهم», «عرسي · بدأت خطتك · بدون موعد · عريس» | Pick a context | `GET /contexts` | 🔧 Add `relationToOwner`, `presetLabel`, `theme/persona` of the plan owner, and `dateLabel`. Label inconsistency «مساهم» (L-C12) | `GET /api/v1/contexts` → each item adds `{preset, levels, relationToOwner, ownerPersona, planState}` |
| q05_tasks_mine «المهام · عرس محمد · معك 4» | Chips «لي» / «كل مهام الخطة»; «لك»: «رتّب الغداء مع أبو علي · الجمعة · محمد عطاك هذي المهمة», «ذكّر آل الحمدي اللي ما ردّوا · 8 ضيوف · قبل 1 يناير», «رتّب سيارات الزفة», «استلم البدلة · خلصت أمس»; note «المهام اللي ما هي لك تشوفها في "كل مهام الخطة"، وما تقدر تعدّلها.» | Complete own; browse all read-only | `GET P/tasks` (contributor sees only own or assigned) | 🔧 «كل مهام الخطة» requires section-level VIEW of every non-private task; edits are limited by `canEdit` (§2.3, L-C02) | d01 contract with `assignee=me` and `canEdit/canComplete` per row |
| q06_money_view «المال · عرس محمد · تشوف بس» | «العرس بيكلف 10 مليون», «اندفع 4.6 · ناقص 2.5», bar; note «صلاحيتك "تشوف بس". ما فيه أزرار تسجيل، والمصادر والسلف مخفية.»; «الدفعات الجاية»: «دفعة القاعة · بعد 5 أيام · 500 ألف», «باقي المهر · 15 نوفمبر · مليون» | none | `GET P/money-summary` (contributor totals limited to own contributions; funding owner-only) | 🔧 For `money=VIEW`, return whole-plan totals and schedules, never funding or loan lists. Decide whether the aggregate shortfall «ناقص» may show (L-C09) | `GET P/money-summary` → `{access: VIEW, budget, costs, paymentSchedules, shortfall?}` with `funding` absent. Write routes return `403 SECTION_LEVEL_REQUIRED(money, MANAGE)` |
| q07_money_locked «المال خاص بمحمد» | «ما عندك صلاحية تشوف المال في هذي الخطة. لو تحتاج تسجّل مبلغ، اطلب منه.» | «اطلب من محمد» | none | ➕ permission request (q13/q14) | `POST P/permission-requests {section: MONEY, requestedLevel: VIEW\|MANAGE, reason?, sourceScreen}` → `{requestId, state: PENDING}`; `409 REQUEST_ALREADY_PENDING {requestId}`; `409 LEVEL_ALREADY_GRANTED` |
| q08_providers_locked «المزودين عند محمد» | «تشوف مواعيدهم في البرنامج، بس الطلبات والعروض خاصة بمحمد.» | «اطلب صلاحية» | Schedule endpoint does not exist (no Event model, INV §0) | ➕ The schedule must include provider slots (name + time only) for every participant. Request as q07 | `GET P/schedule` → `{events:[{kind, label, date, timeLabel, place, providers:[{name, slotLabel}]}]}` (every member; cross-ref map B events). Request: q07 contract with `section: PROVIDERS` |
| q09_bride_view «عرس محمد · أنتِ مشاركة» | «الموعد والبرنامج»; «96 · يوم على العرس · الخميس 21 يناير»; «برنامج عرس الرجال»: «السمرة · الثلاثاء 19 · الديوان», «المقيل · الأربعاء 20 · بيت الوالد», «الزفاف · الخميس 21 · قاعة سبأ»; «هذي خطة محمد بألوانها. خطتك أنتِ في "اختر المسار".» | Switch path | `GET /contexts`, plan detail | 🔧 Uses the `العروسة` preset (all sections NONE, schedule only) and `GET P/schedule` ➕. Theme from `ownerPersona` | `GET P/schedule` + contexts |
| q10_account_plans «حسابي · صالح الحمدي» | «الخطط اللي أشارك فيها»: «عرس محمد · مساعد · المهام والضيوف والرفد», «عرس ليلى · تكتب الرفد يوم العرس بس · مساهم»; «خطتي · ابدأ خطة عرسك · بنفس حسابك»; «في عرس محمد»: «اللي سجّلته · 12 حركة · تبقى باسمك», «اطلع من الخطة · مهامك ترجع لمحمد» | Open plan; start plan; view contributions; leave | `GET /contexts`, `GET P/contributions/summary` (self), `GET P/contributions` | ✅ for contributions; 🔧 contexts (q04) | `GET P/contributions/summary?contributorUserId=me` → `{total, bySection}` (exists) |
| q11_leave «تطلع من عرس محمد؟» | «تقدر ترجع لو أرسل لك دعوة ثانية»; «مهامك الأربع ترجع لمحمد», «الرفد اللي كتبته يبقى في دفتره باسمك», «توقف تنبيهات هذي الخطة» | «اطلع من الخطة»; «رجوع» | `DELETE P/members/me {expectedMemberId, expectedAuthorityVersion}` | 🔧 Leaving does not unassign tasks today (only account deletion calls `unassignUserTasksInTransaction`). Add a preview with counts, return tasks to the owner, and close pending permission requests | `GET P/members/me/leave-preview` → `{tasksToReturn, rafdEntriesKept, contributionsKept}`; `DELETE P/members/me` (existing body) → `{left:true, tasksReturned}`; `409 MEMBERSHIP_CHANGED_SINCE_LEAVE_REQUEST` (exists) |
| q12_changed «أهلًا صالح · محمد فتح لك المال» | «تقدر الحين تسجّل الدفعات والكاش اللي معك. المصادر والسلف تبقى خاصة فيه.»; next step «سجّل اللي صرفته من العهدة · معك 120 ألف للسمرة والمقيل · لأن محمد فتح لك المال، والعهدة تنقفل بعد العرس»; «ولو شالك محمد من الخطة، توصلك رسالة هادية، واللي سجّلته يبقى باسمك.» | «سجّل» | `PATCH P/members/:memberId` (bumps authorityVersion); `SHARING_UPDATED` has no producer | 🔧 Emit `PERMISSION_CHANGED {section, from, to}`. The client refreshes contexts on `authorityVersion` change. Custody («العهدة») is a money-map item (map B) | Notification `PERMISSION_CHANGED` data `{planId, section, fromLevel, toLevel, authorityVersion, nextAction?}`; `GET /dashboard/home` returns `nextTask` for the new level |
| q13_permission_request (owner) «صالح يطلب يشوف المال · من شاشة المال قبل ساعة» | Reason «أبغى أسجّل اللي أدفعه للغداء عشان ما ننسى»; options «يشوف ويسجّل · يسجّل الدفعات اللي هو يدفعها. المصادر والسلف تبقى لك», «يشوف بس · المجاميع بدون أزرار», «لا، مو الحين · توصله رسالة هادية بدون سبب» | «تمام» | none | ➕ | `GET P/permission-requests?state=PENDING` (owner) → `[{requestId, member{id,name}, section, requestedLevel, reason, sourceScreen, createdAt}]`; `POST /permission-requests/:id/answer {decision: GRANT_MANAGE\|GRANT_VIEW\|DECLINE}` → `{state, member{levels, authorityVersion}}`. Errors `409 REQUEST_NOT_PENDING`, `404`. Grant updates levels and emits `PERMISSION_REQUEST_ANSWERED` + `PERMISSION_CHANGED`; decline sends a calm message with no reason |
| q14_request_sent «طلبك وصل محمد» | «أول ما يرد نبلّغك. ما تحتاج تطلب مرة ثانية.»; «طلبت «يشوف ويسجّل» · قبل ساعة» | «ألغِ» | none | ➕ | `GET P/permission-requests/mine` → `[{requestId, section, requestedLevel, state, createdAt}]`; `DELETE /permission-requests/:id` (requester; PENDING only) → `{state: CANCELLED}` |
| q15_rafd_writer «أهلًا عبدالله · عرس محمد · كاتب الرفد» | «اليوم الزفاف · سجّل الرفد أول بأول»; «اللي كتبته · 23 اسم»; rows «عبدالله الحمدي · قبل 5 دقايق · 50,000», «أحمد ناجي · ينتظر النت»; «تشوف اللي كتبته أنت بس، وتقدر تصلّحه لين ينتهي اليوم. المجموع عند محمد.» | «سجّل رفد»; edit own | none (no rafd model in backend) | ➕ (rafd entity owned by map B; writer projection here) | `POST P/rafd {clientEntryId, giverName, amount, guestId?, eventId?, recordedAt}` (idempotent on `clientEntryId`; `rafd=WRITE` or owner); `GET P/rafd/mine` → `{count, items:[{id, giverName, amount, recordedAt, editable}]}` (no totals); `PATCH /rafd/:id` (own, while `editableUntil` not passed; `409 RAFD_EDIT_WINDOW_CLOSED`) |
| q16_providers_view «المزودين · عرس محمد · تشوف بس» | «المواعيد ومين تكلّم يوم العرس. الأسعار والعروض عند محمد.»; «قاعة سبأ · الخميس 21 · بعد العصر · محجوز», «فرقة الأفراح…محجوز», «استوديو الضوء · ينتظر تأكيدهم · ينتظر»; «مسؤول القاعة يوم العرس · أبو فهد · محمد شاركه معك» | «اتصل» | `GET /me/wedding-plans/:id/bookings` ([] without PROV), quotes (PROV) | ➕ A `providers=VIEW` projection: booked or awaited providers with slot and status, no price, no offers, no conversations. Contacts appear only when the owner shares them | `GET P/providers/overview` → `{items:[{providerId, name, category, slotLabel, status: BOOKED\|AWAITING\|REQUESTED}], dayContacts:[{name, roleLabel, phone}]}` (`providers ≥ VIEW`; prices only with `providers=MANAGE` **and** `money ≥ VIEW`). Contacts: `PlanContact.sharedWithParticipants` (d04 contract) |
| q17_bride_helper «أهلًا نورة · عرس سلمى · أنتِ مساعدة» | «96 · يوم على عرس أختك · الخميس 21 يناير · صالة الياسمين»; «مهامك · 2»: «ذكّري بنات العم اللي ما ردّن · 6 ضيفات · قبل 1 يناير», «موعد المنقشة · الأربعاء 20 · بعد العصر»; «الخطة بألوان صاحبتها…» | as x06 | `GET /dashboard/home` | 🔧 Same as x06. Wording needs `ownerPersona=BRIDE` and the participant's `relation` (sister). Gendered labels are 📱 from persona and relation | x06 contract |
| q18_wedding_day «أهلًا صالح · عرس أخوك» | «عليك اليوم»: «استلام الغداء من أبو علي · الظهر · بيت الوالد», «سيارات الزفة عند القاعة · بعد العشاء · 4 سيارات»; «برنامج اليوم»: «البرع · الضحى · الحارة», «المقيل · بعد العصر · بيت الوالد», «الزفة · بعد العشاء · قاعة سبأ» | «خلصت» | `GET P/tasks`, dashboard cache (DEC:262) | 🔧 Task `dueTimeOfDay` + `place`; schedule ➕ | `GET P/tasks?assignee=me&due=today`; `GET P/schedule?date=` |
| q19_plan_states «لما الخطة تتغير» | «الخطة متوقفة · محمد أوقفها. مهامك وقفت معها، وما يوصلك شيء لين يرجّعها.»; «العرس تأجل إلى 4 فبراير · مهامك انتقلت معه…» «شوف مهامك»; «الخطة في الذكريات · …للقراءة بس.» «اللي سجّلته»; «الخطة انحذفت · محمد حذفها. اللي سجّلته أنت راح معها.» | Open tasks; view contributions | `WeddingPlanStatus{PLANNING, ARCHIVED}` only; `POST P/tasks/shift-due-dates` (seesWholePlan) | 🔧 Plan states (map A/B scope) must reach participants through `contexts.planState` and notifications `PLAN_PAUSED / PLAN_RESUMED / PLAN_POSTPONED / PLAN_IN_MEMORIES / PLAN_DELETED` (`PLAN_UPDATED` has no producer today) | `GET /contexts` item `planState: ACTIVE\|PAUSED\|MEMORIES\|DELETED`; postponement notification `{oldDate, newDate, tasksShifted}` |
| q20_removed «ما عاد عندك وصول لعرس محمد» | «محمد رتّب المشاركين من جديد. شكرًا على مساعدتك.»; «اللي سجّلته يبقى باسمك عنده», «مهامك الثلاث رجعت لمحمد» | «ابدأ خطة عرسك»; «خططي الثانية» | `DELETE P/members/:memberId` deletes membership and purges notification access; tasks not unassigned | 🔧/➕ Return tasks to owner; keep a tombstone the removed user can read | `GET /api/v1/me/ended-memberships?unseen=true` → `[{planTitle, ownerFirstName, endedAt, reason: REMOVED\|PLAN_DELETED, tasksReturned, contributionsKept}]`; `POST /me/ended-memberships/:id/seen`. Plus notification `MEMBERSHIP_REMOVED` with `weddingPlanId=null` (it survives the plan visibility purge) |
| q21_notifications «التنبيهات · من عرس محمد» | «محمد عطاك مهمة · رتّب سيارات الزفة · قبل 15 يناير»; «صرت تشوف المال وتسجّل · محمد وافق على طلبك»; «مهمتك بكرة · ذكّر آل الحمدي اللي ما ردّوا»; «العرس تأجل · صار 4 فبراير، ومهامك انتقلت معه»; «توصلك بس الأشياء اللي تخصك. ومبالغ ما تطلع على شاشة القفل.» | Open | `GET /notifications` ✅, `TASK_ASSIGNED` ✅, `TASK_DUE_SOON` ✅, push generic copy ✅ | 🔧 New types `PERMISSION_CHANGED`, `PERMISSION_REQUEST_ANSWERED`, `PLAN_POSTPONED`, `TASK_RETURNED`, `MEMBERSHIP_REMOVED`, `PERMISSION_REQUESTED` (owner), `INVITE_RENEWAL_REQUESTED` (owner). Recipient filter = assignee or creator, plus level-based | `GET /notifications?weddingPlanId=` (existing shape) |

---

## 2. Permission model spec

### 2.1 Roles (presets) to levels

Presets only fill in defaults. The stored levels are the authority (this keeps DEC:238). Owner = `plan.ownerUserId` is implicitly MANAGE everywhere, and is the only one who sees funding sources and loans (DEC:400), invites or removes members, answers requests, and edits, pauses or deletes the plan.

| Preset (UI) | enum | tasks | guests | providers | money | rafd | Source |
|---|---|---|---|---|---|---|---|
| مساعد | HELPER | MANAGE | MANAGE | NONE | NONE | WRITE | g06 (levels 2,2,0,0,1); g01 «المهام والضيوف، والرفد إذا بغيت» |
| أهل | FAMILY | MANAGE | MANAGE | NONE | NONE (owner may set VIEW) | NONE | g01 «المهام والضيوف، ويشوف المال إذا سمحت» |
| كاتب الرفد | RAFD_WRITER | NONE | NONE | NONE | NONE | WRITE | g01, q15, DEC:400 |
| يشوف بس | VIEWER | VIEW | VIEW (summary + list) | NONE | NONE | NONE | g01 «الموعد والملخص بدون تفاصيل الفلوس»; y10 |
| العروسة / العريس | PARTNER_GUEST | NONE | NONE | NONE | NONE | NONE | g01 / x07 «الموعد والبرنامج · بدون المال»; q09. The other partner has their own plan |
| (custom) | CUSTOM | any | any | any | any | any | any manual change marks `preset=CUSTOM` |

Always on for every member: schedule (events, dates, provider slot names and times), plan title, owner name, countdown, own notifications, own contributions history.

### 2.2 What each level means per section (API enforcement)

| Section | NONE | VIEW | MANAGE |
|---|---|---|---|
| tasks | `GET` → `403 SECTION_LEVEL_REQUIRED`; home shows lock. Exception: tasks **assigned to me** are still readable and completable (L-C03 resolution) | Read every non-private task, checklist, summary. Complete, snooze and tick checklist on tasks assigned to me | VIEW + create (incl. private), edit, reassign, cancel or reopen tasks I created or that are assigned to me; delete only my own. Tasks created by others stay read-only (q05). Owner edits everything |
| guests | `403`; y10 count hidden | List, summary, groups, forecast (without savings); phones visible (needed to call). No RSVP links | VIEW + create, edit, group, bulk, mint links, send invites and reminders (as sender). Deleting a guest created by someone else: owner only |
| providers | `403`; schedule still shows provider names and times (q08) | `GET P/providers/overview` only: booked or awaited, slot, status, owner-shared contacts. No quotes, offers, prices, conversations (q16) | Full quotes, bookings, conversations of the plan. Offer and price amounts also require `money ≥ VIEW`; accepting an offer requires `money = MANAGE` (keeps `assertProviderAndMoneyManageable`) |
| money | `403`; amounts inside other sections redacted (R-MONEY) | Whole-plan budget, categories, costs, payments, schedules, warnings; **no** funding sources, loans, repayments; aggregate shortfall per L-C09 decision. No write buttons (q06) | VIEW + record costs and payments they pay, custody («العهدة») spend; edit and delete own records. Budget total, categories allocation, funding, loans: owner only (q13 «المصادر والسلف تبقى لك») |
| rafd | `403` | — | WRITE: create, list and edit **own** entries until `editableUntil`; never totals (q15). Owner sees the book |

Enforcement shape:

- One port method `assertSection(ctx, section, minLevel)` replaces `assertTaskManageable / assertGuestManageable / assertMoneyReadable / assertMoneyManageable / assertProviderManageable`. Write variants keep the existing row locks.
- Item edit rules (the MANAGE "own or assigned" clause) live in each service as a pure predicate. The API returns `canEdit/canComplete` per item so the client never guesses.
- `livePlanAuthorizationWhere` stays. It now compares levels, not booleans.
- Responses carry `X-Authority-Version`. Clients send it back on writes; a mismatch returns `409 STALE_AUTHORITY` and the client refreshes contexts (q12).

### 2.3 What changes from today

| Today | Becomes |
|---|---|
| `seesWholePlan = owner \|\| role ∈ {GROOM, BRIDE}` decides whole-plan vs item-level visibility | **Removed.** Visibility is section-level for everyone with `≥ VIEW`. Partners no longer exist inside one plan (each spouse owns a plan) |
| Contributor scope = entity ids from own `ContributionEvent`s (tasks, guests, costs, quotes, bookings, timeline, dashboard, notifications) | **Removed as authorization.** `ContributionEvent` is kept only for attribution («اللي سجّلته», «يبقى باسمه»). The only per-item scopes left: private tasks and costs (creator only), rafd writer (own entries), MANAGE edit predicate |
| 7 booleans `canViewMoney, canEditPlan, canManageTasks, canManageGuests, canManageProviders, canInviteMembers, canManageMoney` | 5 levels. `canEditPlan` and `canInviteMembers` become owner-only (no member equivalent in g06). `canViewMoney/canManageMoney` → `money VIEW/MANAGE` |
| Private task or cost creation only if `seesWholePlan` | Owner, plus members with section MANAGE (pending L-C07) |
| Delegated invites with permission ceiling (`assertPermissionCeiling`, `assertMemberWithinActorScope`) | Owner-only invites; the ceiling code becomes dead. Members created by delegates stay valid |
| Role defaults applied on invite only; direct add all-false | Presets apply on both; `POST P/members` (direct add) is retired in favour of invites (phone binding) |
| Assistant only for `seesWholePlan` | Owner only (or owner plus `money=MANAGE`, decide in map A) |
| Money summary contributor totals limited to own contributions | VIEW → whole-plan totals without funding |

### 2.4 Conversation scoping

- Access: owner, or member with `providers=MANAGE` (current `canManageProviders` rule, DEC:175). This already matches section-level semantics, so the inventory observation that conversations ignore contributor scoping stops being an inconsistency: quotes and bookings move to section-level too.
- `providers=VIEW` → no conversation list, no quote requests (q16). Provider phones show only through owner-shared `PlanContact`.
- Inside a conversation, offer amounts and budget fields need `money ≥ VIEW` (existing `canViewMoney` gate, renamed).
- A level downgrade below MANAGE fires `CONVERSATION_ACCESS_REVOKED` (existing outbox event) for that user and sets `ConversationParticipant.revokedAt`. Re-grant reactivates explicitly (DEC:202).
- Rafd writers, viewers and partner-guests never join provider conversations.

---

## 3. State machines

### 3.1 Invite lifecycle

```
            create (owner, 7d)                 preview GET (PUB)
  ──────────► PENDING ───────────────────────► PENDING+opened (openedAt)
               │  delivery: PENDING→DELIVERED | UNCERTAIN | UNAVAILABLE(→ copy link)
               │
               ├─ request-otp(phone ≠ invited) ──► stays PENDING, error INVITE_PHONE_MISMATCH (w16)
               ├─ verify-otp ─► PHONE_VERIFIED (sub-state; shows q03)
               │                   ├─ accept ──► ACCEPTED ──► creates Membership ACTIVE
               │                   └─ decline ─► DECLINED (terminal; inviter notified)
               ├─ reissue / copy link ─► SUPERSEDED (old token) + new PENDING (new 7d)
               ├─ remind ─► PENDING (lastRemindedAt; same token if stored, see L-C06)
               ├─ owner revoke ─► REVOKED
               ├─ plan paused ─► PENDING (accept blocked: 409 PLAN_READ_ONLY)
               ├─ plan memories/deleted, member removal ─► REVOKED (existing behaviour)
               └─ now > expiresAt ─► EXPIRED ─► renewal-request ─► (owner) reissue
```

w16 mapping: EXPIRED → «الدعوة انتهت»; REVOKED → «الدعوة انلغت»; phone mismatch → «الدعوة لرقم ثاني»; ACCEPTED (same user) → «أنت معهم من قبل» (only while the membership is live, DEC:232). DECLINED and SUPERSEDED show as REVOKED to the holder.

### 3.2 Membership lifecycle

```
 (invite ACCEPTED) ─► ACTIVE ──levels changed──► ACTIVE (authorityVersion++, PERMISSION_CHANGED)
                       │   ▲
                       │   └─ permission request answered GRANT_* ─┘
                       ├─ plan PAUSED ─► SUSPENDED_BY_PLAN (read-only, no notifications) ─resume─► ACTIVE
                       ├─ plan postponed ─► ACTIVE (tasks shifted, PLAN_POSTPONED)
                       ├─ plan MEMORIES ─► READ_ONLY (own contributions readable)
                       ├─ leave (q11) ─► ENDED(LEFT)
                       ├─ owner remove (q20) ─► ENDED(REMOVED)
                       ├─ plan deleted ─► ENDED(PLAN_DELETED)
                       └─ account deleted ─► ENDED(ACCOUNT_DELETED)
 ENDED ─(new invite accepted)─► ACTIVE (new SharedMember + new ContributorTenure)
```

Side effects on ENDED (one transaction, existing leave and remove paths plus the new steps marked +):
1. Revoke matching pending invites (exists).
2. + Non-private tasks assigned to the member → `assigneeUserId = owner`, `returnedFromUserId = member`, emit `TASK_RETURNED` to owner.
3. + The member's private tasks → soft-deleted. They are never shown to the owner (L-C07).
4. + Pending permission requests → `SUPERSEDED`.
5. Close tenure; contribution events stay attributed (exists). Rafd entries keep `recordedByName` snapshot.
6. Conversation access revoked (exists); notifications purged (exists). + Write the `ended-membership` tombstone and `MEMBERSHIP_REMOVED` (for REMOVED or PLAN_DELETED).

### 3.3 Permission request lifecycle

`PENDING ─answer GRANT_MANAGE|GRANT_VIEW─► GRANTED (levels updated)`; `PENDING ─DECLINE─► DECLINED` (calm message, no reason); `PENDING ─requester cancel─► CANCELLED`; `PENDING ─owner changes levels directly / member ENDED─► SUPERSEDED`. At most one PENDING per `(member, section)`. A declined request can be re-asked after 7 days (`429 REQUEST_COOLDOWN`).

---

## 4. Task and guest lifecycles

### 4.1 Task

```
 create (MANUAL | STARTER | PROVIDER | GUESTS | MONEY | SYSTEM)
   └─► TODO ──(blockedBy open)──► BLOCKED* ──(deps done)──► TODO
        │  ├─ snooze/reschedule ─► TODO (dueDate moved; snoozeCount++)
        │  ├─ now > due ─► OVERDUE* (derived; notify owner only if it blocks something)
        │  ├─ start ─► IN_PROGRESS
        │  ├─ complete/swipe ─► DONE (completedAt, completedBy) ──reopen──► TODO
        │  └─ «ما نحتاجها» ─► CANCELLED (kept in history) ──reopen──► TODO
 assignment: unassigned/owner ⇄ member (TASK_ASSIGNED) ─member ENDED─► owner (TASK_RETURNED)
 private: creator only; cannot be assigned; is not returned on leave (deleted)
 auto tasks: idempotent per (origin, sourceId); source cancelled → task CANCELLED automatically
 plan postponed: open tasks' dueDate shift by the same delta; plan paused: reminders suppressed
```
`*` = derived states, not stored. `IN_PROGRESS` exists in the enum but no screen uses it. Keep it, never show it.

### 4.2 Guest

```
 create (single | contacts | bulk | estimate-only has no guest rows)
   └─► NOT_SENT ─mint link─► LINK_READY ─send─► SENT (sentAt, sender) ─open─► OPENED (openedAt)
          ├─ RSVP CONFIRMED (+companions) ─► CONFIRMED ⇄ DECLINED (guest may change until wedding day)
          ├─ reminder (pending only, ≤1/24h) ─► SENT/OPENED (remindedAt)
          ├─ no WhatsApp ─► COPY_LINK (manual)
          └─ wedding day passed ─► RSVP closed (410)
 group: guest ∈ 0..1 group; group delete → guest ungrouped (kept)
 duplicates: same normalizedPhone per plan → rejected or skipped; same normalizedName without phone → POSSIBLE_DUPLICATE (warn only)
```
Collapse `Guest.status` into `attendanceStatus` (two fields hold the same truth today), and `invitationStatus` into timestamps.

---

## 5. Logic problems found in the design (ids L-Cxx)

Severity: **H** blocks a correct contract · **M** needs an owner decision · **L** cosmetic or data.

| id | Sev | Screens | Problem | Proposed resolution |
|---|---|---|---|---|
| L-C01 | M | d03, d01 vs inventory, LLA 3.4 | The starter button says «أضف 30 مهمة لخطتي» and d01 says «12 من 30», but the inventory and LLA say «23 مهمة» | Pick one number (LLA says 23) and fix the d03 button |
| L-C02 | H | g06, q03, q05, x05 | Tasks "manage" is defined three ways. g06 مساعد = «يعدّل»; q03 = «المهام: تشوف وتخلّص»; q05 = others' tasks «ما تقدر تعدّلها» | Adopt §2.2: MANAGE = create + edit own or assigned; others' tasks read-only. Reword q03 «تضيف مهام وتخلّص اللي عليك» |
| L-C03 | H | g01, d01, d02, x16, y10, z05 | The father is «يشوف بس», yet tasks are assigned to him («للوالد», «مطلوب منك») and z05 proposes moving two more to him. The backend refuses assignees without TASKS | Rule: any member with `tasks ≥ VIEW` can be an assignee and can complete and snooze their assigned tasks |
| L-C04 | H | e01, e04, e08 vs g01 | The father is the card host («يتشرف عبدالرحمن الحمدي») and the sender («الوالد يرسلها», «يرسل لهم الوالد»), but he is view-only and «guests: VIEW» cannot send | Separate "card host name" (text on the card) from "sender". A sender must have `guests=MANAGE`, or sending is done by the owner "باسم الوالد". Decide which |
| L-C05 | H | e04, e08 | «أرسلها لـ 124 ضيف» with WhatsApp only: it is undefined whether Aarast's server number sends 124 messages (Meta template cost and approval) or the sender's phone sends them one by one. Guests without WhatsApp have no path (x07 has «انسخ الرابط» only for participants) | Contract supports `mode: SERVER\|DEVICE` and returns `noWhatsapp[]` with copy links. Owner picks the default. Add a guest-side «انسخ الرابط» state |
| L-C06 | H | e08, x07 | The reminder reuses «رابطه», and «ذكّره» / «انسخ الرابط» reuse the invite link. The backend stores only token hashes, so any resend must remint, which kills the link in the first message | Store the token encrypted (KMS-wrapped, `tokenCiphertext`) for guests' RSVP links (low sensitivity), and rotate for participant invites (security) with the design text «الرابط القديم ما عاد يشتغل» |
| L-C07 | H | w25, q11, q20, x07 | «مهمة خاصة · ما يشوفها غيرك» conflicts with "his tasks return to the owner" on leave or removal. It is also unclear whether participants may create private tasks at all (today only owner or partner) | Private tasks are never returned: they are deleted with the membership. Participants with `tasks=MANAGE` may create private tasks. Add one line to q11 «مهامك الخاصة تنحذف» |
| L-C08 | M | e01 vs z06 | Hall capacity is «قاعة سبأ تتسع 150 · باقي 26 مقعد» in e01 (from invited) and «القاعة 130 · تكفي ومعك 18 كرسي» in z06 (from expected). Capacity has no source | One capacity (from the hall booking, or entered manually). Spare computed from *expected*. Align the mock numbers |
| L-C09 | M | q06, g06 note | «المال: يشوف» excludes «مصادر الفلوس والسلف», but q06 shows «ناقص 2.5», which is a funding-derived shortfall (b02 «معك وموعود وناقص») | Decide. Recommended: aggregate shortfall allowed, source list and loan list never |
| L-C10 | H | d01, d04, d05, z05, e07, z06 | Money amounts appear inside non-money screens («500 ألف», «3,000,000», «100 ألف», «رفدك 20,000», «75 ألف توفير»), while x06 promises «بدون أي رقم مالي» | Apply R-MONEY server-side to every cross-section amount. Add design variants without amounts for participants |
| L-C11 | M | x05 vs q01–q03; DEC:188 | Two decision screens with different buttons («أبشر، معك / مو الحين» vs «قبول والانضمام / رفض الدعوة»); «مو الحين» is ambiguous (decline vs later). x05 and q01 reveal inviter, date and city before OTP, against DEC:188 | Merge: x05 is the preview (no levels) before OTP; q03 is the decision. «مو الحين» = close without deciding (invite stays PENDING). Update DEC:188 to allow a minimal preview |
| L-C12 | L | q04, q10 vs g01, g06 | The rafd writer is tagged «مساهم» in q04 and q10 but the preset is «كاتب الرفد» | Use «كاتب الرفد» everywhere |
| L-C13 | L | q13 vs q14 | Owner sees «صالح يطلب يشوف المال»; participant sees «طلبت «يشوف ويسجّل»» | Owner title from `requestedLevel`: «صالح يطلب يشوف ويسجّل في المال» |
| L-C14 | M | q07, q08, x06 → q14 | No participant-side request form is drawn (pick level, reason). q13 shows a reason that was never typed anywhere | Add a request sheet (level chips + optional reason) between q07/q08 and q14 |
| L-C15 | H | q11, q20, x07 | "Tasks return to the owner" is promised, but backend leave and remove do not unassign tasks (only account deletion does) | §3.2 side effect 2 |
| L-C16 | H | q20 | The calm "removed" message has no data source: removal deletes membership and purges the user's plan notifications | Tombstone `ended-memberships` + plan-less `MEMBERSHIP_REMOVED` notification |
| L-C17 | L | q19 vs q11, q20 | Plan deleted: «اللي سجّلته أنت راح معها», while the backend keeps ContributionEvents in a DELETED scope | Align retention: purge the participant-visible history on plan deletion (keep only legal/audit data) |
| L-C18 | H | w16 | Four distinct states, but the backend returns one `INVITE_NOT_FOUND_FOR_PHONE`. Expiry is 14 days, design says 7 | Distinct errors (§1.3 w16); default and max 7 days |
| L-C19 | M | w16 | «اطلب دعوة جديدة من محمد» has no channel for a non-member; «كلّم محمد على واتساب» exposes the inviter's phone to anyone holding a revoked token; the wrong-phone message prints the full invited number | Renewal request as an in-app notification to the inviter; WhatsApp to inviter only for EXPIRED (not REVOKED); invited phone masked |
| L-C20 | M | w27 vs e01, e06 | Sides «أهلنا / أهل العروسة» exist only in w27. e01 mixes «آل السقاف · أهل العروسة» into one list. e06 has no side picker. The backend `GuestSide{GROOM,BRIDE,FAMILY,FRIEND,OTHER}` is absolute and mixes side with relation; in the bride's plan «أهلنا» = bride's family | Group-level relative side `OURS\|OTHER_SIDE` (label from the owner's persona). Guest side inherited from its group |
| L-C21 | L | e01 vs w27 vs e03 | Group names differ (families «آل الحمدي…» vs «الأهل، الحارة…»), counts differ (124 vs 140). The group "responsible / sender" («يرسل لهم الوالد») has no edit screen | Align mocks; add a responsible picker in the group edit sheet |
| L-C22 | M | w29 vs w41, q15 | Offline: guests say «الإضافة والدعوات لما يرجع النت» (blocked?) while rafd and w41 queue writes | Queue guest adds (idempotent `clientId`); block only sending invites offline. Reword w29 |
| L-C23 | M | z06 | The forecast «يجي عادة النص تقريبًا» needs a source and an "insufficient data" variant (DEC:258, w38). The target of «عدّل العدد» is undefined | `sufficient` flag + w38 variant; «عدّل العدد» writes `cateringHeadcount` (and updates the catering task) |
| L-C24 | M | z05 | «وزّعها» suggests giving tasks to the father (viewer) and ignores levels and relation | The suggestion only considers members with `tasks ≥ VIEW`, owner confirms per task |
| L-C25 | M | w26 vs q21 vs cron | «نبلّغك بس إذا مهمة متأخرة توقف شيء ثاني» vs current `TASK_OVERDUE` for every task; q21 shows «مهمتك بكرة» for assignees | Owner: blocking-only; assignee: due-soon (1 day) only |
| L-C26 | L | d02 | «شخص ثاني» (non-member responsible) has no notification path and no contact record | Store it as a `PlanContact`; nudges go through the owner (WhatsApp from device) |
| L-C27 | L | g01 vs y10 | g01 says the father «يشوف ملخص شهري بدون تفاصيل»; y10 is a live home with tasks and counts. "Monthly summary" is never drawn | Reword g01 to match y10 |
| L-C28 | M | g06, g01, x07; backend GROOM/BRIDE | The «العروسة» preset levels are not drawn. The backend partner role (`seesWholePlan`, money manage) is the opposite of «بدون المال» | Preset = schedule only (§2.1). Migrate existing partner members carefully (§7) |
| L-C29 | L | q16 | «محمد شاركه معك» needs an owner action to share a contact; none drawn | Toggle «شاركه مع المشاركين» on the contact (d04 edit) |
| L-C30 | M | q19 | Paused plan: «مهامك وقفت معها» does not say what the participant can still do | PAUSED = read-only for members, no reminders; invites cannot be accepted |
| L-C31 | M | g06 | No "members" or "plan edit" level, so participants cannot invite (x04 «اطلب منه يضيفك»). The backend allows delegated invites and members-of-members | Retire delegation; existing delegate-created members become owner-managed |
| L-C32 | M | q15 | «تقدر تصلّحه لين ينتهي اليوم»: which day (event day, Asia/Aden midnight)? Offline entries synced after the cutoff? | `editableUntil = event day 23:59 Asia/Aden`; offline creates accepted until +24 h, edits not |
| L-C33 | M | e07, e09 | Who may see a guest's rafd block? The writer sees only their own; guests MANAGE participants? | Rafd values owner-only; others see nothing |
| L-C34 | L | x07 | «أضفه» for a former member: restore old levels or the preset? | Prefill the old levels; owner confirms in g06 |

---

## 6. Prisma changes

```prisma
// collaboration.prisma
enum SectionLevel { NONE VIEW MANAGE }
enum RafdLevel { NONE WRITE }
enum ParticipantPreset { HELPER FAMILY RAFD_WRITER VIEWER PARTNER_GUEST CUSTOM }
enum ParticipantRelation { FATHER MOTHER BROTHER SISTER SON DAUGHTER UNCLE AUNT COUSIN FRIEND PARTNER RELATIVE OTHER }
enum PermissionRequestState { PENDING GRANTED DECLINED CANCELLED SUPERSEDED }
enum PlanSection { TASKS GUESTS PROVIDERS MONEY RAFD }

model SharedMember {                     // + fields; old booleans kept read-only until §7 step 5
  preset          ParticipantPreset @default(CUSTOM)
  relation        ParticipantRelation?
  tasksLevel      SectionLevel @default(NONE)
  guestsLevel     SectionLevel @default(NONE)
  providersLevel  SectionLevel @default(NONE)
  moneyLevel      SectionLevel @default(NONE)
  rafdLevel       RafdLevel    @default(NONE)
  legacyItemScope Boolean      @default(false)   // §7: keeps old item-level filtering until owner reviews
}
model PlanInvite {                       // + same 5 levels, preset, relation
  openedAt        DateTime?
  lastRemindedAt  DateTime?
  supersededById  String?   @unique
  // expiresAt default now()+7d (service), max 7d
}
model PermissionRequest {
  id              String @id @default(cuid())
  weddingPlanId   String
  sharedMemberId  String
  requesterUserId String
  section         PlanSection
  requestedLevel  String          // VIEW | MANAGE | WRITE
  reason          String?  @db.VarChar(280)
  sourceScreen    String?
  state           PermissionRequestState @default(PENDING)
  grantedLevel    String?
  answeredByUserId String?
  answeredAt      DateTime?
  createdAt       DateTime @default(now())
  @@index([weddingPlanId, state])
  // partial unique (sharedMemberId, section) WHERE state='PENDING' via raw SQL migration
}
model EndedMembership {                  // q20 tombstone (survives plan purge)
  id String @id @default(cuid())
  userId String
  weddingPlanId String?                  // SetNull on plan delete
  planTitleSnapshot String
  ownerFirstNameSnapshot String
  reason ContributorTenureEndReason
  tasksReturned Int @default(0)
  endedAt DateTime @default(now())
  seenAt DateTime?
  @@index([userId, seenAt])
}

// tasks.prisma
enum TaskOrigin { MANUAL STARTER PROVIDER GUESTS MONEY SYSTEM }
enum DuePrecision { DAY WEEK MONTH }
enum TimeOfDay { DUHA DHUHR AFTER_ASR AFTER_MAGHRIB AFTER_ISHA }
enum TaskKind { GENERAL CONTRACT_PAPERS }
enum ChecklistHolder { ME OTHER_SIDE }
model WeddingTask {                      // + fields
  createdByUserId   String?              // backfill from ContributionEvent CREATED, else owner
  origin            TaskOrigin @default(MANUAL)
  sourceType        String?
  sourceId          String?
  starterKey        String?
  kind              TaskKind @default(GENERAL)
  duePrecision      DuePrecision @default(DAY)
  dueTimeOfDay      TimeOfDay?
  place             String?
  reason            String?              // x06 «لأن …»
  linkType          String?
  linkEntityId      String?
  contactId         String?              // → PlanContact
  snoozeCount       Int @default(0)
  completedAt       DateTime?
  completedByUserId String?
  returnedFromUserId String?
  deletedAt         DateTime?            // private tasks of ended members
  @@unique([weddingPlanId, origin, sourceId])
  @@unique([weddingPlanId, starterKey])
}
model WeddingTaskDependency { taskId String; dependsOnTaskId String; @@id([taskId, dependsOnTaskId]) }
model WeddingTaskChecklistItem {         // + fields
  holder ChecklistHolder @default(ME)
  note String?
  linkedUserId String?
  linkedContactId String?
  moneyRefType String?                   // MAHR_TOTAL | MAHR_DUE_AT_CONTRACT (amount resolved live, R-MONEY)
}

// planning.prisma (or a new contacts.prisma)
model PlanContact {
  id String @id @default(cuid())
  weddingPlanId String
  name String
  phone String?
  normalizedPhone String?
  roleLabel String?                      // «الأمين الشرعي», «مسؤول القاعة»
  sourceLabel String?                    // «من الوالد»
  providerId String?
  sharedWithParticipants Boolean @default(false)
  createdByUserId String
  @@index([weddingPlanId])
}
model WeddingPlan {                      // + fields (guests side; plan states belong to map A)
  estimatedGuestCount Int?
  venueCapacity       Int?
  cateringHeadcount   Int?
  invitationCard      Json?              // hostName, hostRelation, honoreeName, timeLabel, venueLabel
}

// guests.prisma
enum GuestGroupSide { OURS OTHER_SIDE }
model GuestGroup {                       // + fields
  side GuestGroupSide @default(OURS)
  responsibleUserId String?
  // unique ([weddingPlanId, name]) → ([weddingPlanId, side, name])
}
model Guest {                            // + fields
  createdByUserId String?
  invitationSentAt DateTime?
  invitationOpenedAt DateTime?
  invitationRemindedAt DateTime?
  invitationSenderUserId String?
  rsvpTokenCiphertext String?            // L-C06 (KMS-wrapped) so reminders reuse the link
  // later: drop `status` (duplicate of attendanceStatus) and `invitationStatus` (derive from timestamps)
}

// notifications.prisma: NotificationType +=
//  PERMISSION_CHANGED, PERMISSION_REQUESTED, PERMISSION_REQUEST_ANSWERED, MEMBERSHIP_REMOVED,
//  TASK_RETURNED, TASK_BLOCKING_OVERDUE, PLAN_POSTPONED, PLAN_PAUSED, PLAN_RESUMED,
//  INVITE_RENEWAL_REQUESTED   (retire unused SHARING_UPDATED / PLAN_UPDATED or reuse them)
// Rafd entry (RafdEntry: clientEntryId unique, recordedByUserId SetNull, recordedByNameSnapshot,
// editableUntil) and custody belong to map B; this map only consumes them.
```

---

## 7. Implementation order and migration risks

### 7.1 Order

1. **Levels in the schema** (additive): new enums and columns on SharedMember and PlanInvite; backfill (7.2); dual-write the old booleans from the levels so the old code keeps working.
2. **Permission port**: `assertSection` + level-aware `livePlanAuthorizationWhere`; `GET permissions/me` and `/contexts` return `preset/levels/relation/planState`. Mobile (q04–q08 tab locks) can start from here.
3. **Invite v2**: preset and levels on create, 7-day expiry, preview (PUB), distinct w16 errors, masked mismatch, remind or reissue, renewal request, `openedAt`.
4. **Section-level reads**: tasks, guests, money-summary VIEW, provider overview, quotes and bookings. Remove contributor scope from authorization, behind `legacyItemScope` (7.2). Apply R-MONEY.
5. **Membership exits**: task return, private-task deletion, ended-membership tombstone, notifications; leave preview.
6. **Permission requests** (q07, q13, q14) + `PERMISSION_CHANGED` producer.
7. **Tasks v2**: createdBy, origin, fuzzy due and time-of-day, verbs (complete, snooze, reassign, reopen, cancel), contacts, checklist holder, dependencies, starter catalog, overdue policy. Then smart tasks (z05) and rebalance.
8. **Guests v2**: group side and responsible, bulk dry-run with per-item outcomes, invitation card, send and remind (after the L-C05 and L-C06 decisions), timeline timestamps, RSVP enrichments, forecast (z06), estimate (x21).
9. **Retire**: booleans, `seesWholePlan`, delegated invites (ceiling), direct member add, GROOM/BRIDE member roles; drop columns in a later release.

### 7.2 Migration risks for existing memberships

| Risk | Why | Mitigation |
|---|---|---|
| **Visibility expansion** (privacy) | Today a HELPER/FAMILY member with `canManageGuests` sees only the guests they created. Section-level VIEW/MANAGE suddenly shows every guest phone, every task and (with `canViewMoney`) whole-plan money | Backfill sets `legacyItemScope=true` for every existing non-owner member. The owner gets a one-time review card («صلاحيات المشاركين تغيرت…») per member; confirming clears the flag. Until then the services keep the old item filter for that member |
| Boolean → level mapping is lossy | e.g. `canManageTasks=false` today means "no tasks" (empty list), while VIEW is new | Map: `canManageX → MANAGE`, else `NONE`; money: `canManageMoney → MANAGE`, `canViewMoney → VIEW`, else `NONE`; `rafd=NONE` for all; `preset=CUSTOM` unless the levels exactly match a preset. Never map up to VIEW automatically |
| GROOM/BRIDE partner members | They have `seesWholePlan`, money manage, and may hold private tasks and costs. The new model has no in-plan partner | Map to all-MANAGE CUSTOM + `legacyItemScope=false`, keep their private items. Flag them in the owner review card ("each of you can have your own plan"). Do not auto-create plans for them |
| `canEditPlan` / `canInviteMembers` holders lose powers | The design has no member-level equivalents | Notify both sides. Members created by delegates stay; their management moves to the owner |
| Pending invites with old flags and a 14-day expiry | New rules are 7 days and levels | Backfill levels from flags. Keep the existing `expiresAt` (do not shorten live links); the new cap applies on reissue |
| Assignment rule change | Assignees without TASKS flag were impossible; now VIEW suffices. Old tasks assigned to members whose flag was later revoked are orphaned | Backfill: tasks assigned to members with `tasksLevel=NONE` → return to the owner with `returnedFromUserId` |
| `createdByUserId` unknown for old tasks and guests | The MANAGE "own" predicate and private deletion depend on it | Backfill from `ContributionEvent CREATED` where it exists (LEGACY_EXPLICIT provenance); else the owner. Such rows count as owner-created, i.e. read-only for members (safe default) |
| Contribution-scope code removal | Many services (§4.5 of INV) branch on `!seesWholePlan` | Remove per module behind the flag. Keep `ContributorScopeService` for attribution queries only. Contract tests per section × level × legacyItemScope |
| Conversations on downgrade | HELPER default had `canManageProviders=true`; the new مساعد preset has providers NONE | The mapping keeps stored flags (MANAGE), so nothing is revoked silently. Revocation happens only when the owner changes levels, through the existing outbox `CONVERSATION_ACCESS_REVOKED` |
| Mobile clients on the old contract | Old apps read `permissions{can*}` | Keep `permissions{}` computed from levels in `/contexts` and `permissions/me` for 2 releases |
