# Groom Journey Build — Handoff (2026-10-23)

## ملخص لرشاد

- **آخر حالة (2026-10-24):** اقرأ `2026-10-24-status-and-remaining.md`. فيه كل اللي انعمل للمزود والعروسة والإدارة، والباقي، وقرارات تنتظرك.
- الفرع `groom-journey-build`، وكل الشغل المكتمل مرفوع على `origin`.
- خلصت الشرائح 1 إلى 6: البداية، الرئيسية، الفلوس، المهام، الضيوف.
- الشريحة 7 (المزودين، جهة العميل) مكتملة: 24 شاشة من 24.
- شاشة «استكشف» (f02 وw33) مكتملة ومرفوعة، وبعدها «نبدأ بالقاعة» (x22) وصفحة المزود (f03).
- إصلاحات 2026-10-24 من تشغيل التطبيق الحقيقي: موعد العرس ما عاد ينقص يوم (D11)، الخطة المحفوظة تنفتح بدون «اختر المسار»، الرئيسية ما تقول «ما عندك خطة بعد» وهي تحمّل، و«استكشف» ما فيه «خدمات قريبة من بندك» (D12).
- الشريحة 9 (المشارك) مكتملة (D34): الدعوة من الأهل إلى القرار، «اختر المسار»، تبويبات المشارك ورئيسيته ومهامه والأقفال، «حسابي» للمشارك، الخطة في الذكريات، وتنبيهاته.
- باقي: التسليم.
- التنظيف (2026-10-25، D32): شلنا زر الإضافة العائم وشاشات المال القديمة ومرحلة «جهّز ميزانية عرسك» ونموذج الخطة القديم، وبنينا w01 وg09 وb11 على تصميمها. التفاصيل في D32.

## RULE ZERO: the prototype is the law (read before anything else)

It holds for **every journey**, each against its own prototype:
- groom and participant: `mobile/test/prototype/v3/out/` (187 PNGs);
- provider: `mobile/test/prototype/provider/` (54 PNGs), spec
  `docs/project/PROVIDER_JOURNEY.md`;
- admin web: `mobile/test/prototype/admin/out/` (26 PNGs);
- bride: `mobile/test/prototype/bride_profile/out/` (160 PNGs, the groom
  screens with rose colours, feminine wording and her items). Regenerate
  from `mobile/`: `PYTHONUTF8=1 python test/prototype/bride_profile/gen.py`
  then `flutter test test/prototype/bride_profile/gen/v3/v3_bride.dart
  --dart-define=BRIDE=true --update-goldens`, and copy `gen/v3/out/*.png`
  to `bride_profile/out/`. The generated entry is `v3_bride.dart`, not
  `_test.dart`, so a plain `flutter test` never runs it without BRIDE.
  Rules: `docs/project/JOURNEY_PROFILE.md`.

Rashad's complaint (2026-10-24): a session "improved" the old «جهّز ميزانية
عرسك» screen, which is not in the prototype, and showed him a misleading
comparison. That must never happen again.

1. **The app shows only screens that are in the prototype.** The 186 renders
   are committed in `mobile/test/prototype/v3/out/<id>.png` (regenerate with
   `flutter test test/prototype/v3/v3_test.dart --update-goldens`). Open the
   PNG of every screen you touch, with the Read tool, before writing code.
2. **When the running app shows something that is not in the prototype** (an
   old screen, an old bar, an extra card, a setup step), do not restyle it.
   Find why it appears and remove the cause. Restyling an old screen is a
   failure, not progress.
   - Example: «جهّز ميزانية عرسك» appeared because a phone plan never wrote
     its a05 items into money. Fixed at the cause in `c9b2ce56`.
3. **Nothing in the prototype may be missing.** Every text, row, tag and
   button of the PNG is built, unless the classification row
   (`docs/superpowers/audit/groom_build_classification.md`) drops it or a
   decision in `docs/project/DECISIONS.md` changes it. Anything else you drop
   goes into «Design differences» below, with the reason, and you tell Rashad.
4. **Never invent a screen, a flow or a decision.** If the prototype is
   illogical, fix it properly and record it below; do not add new screens.
5. **Compare like with like.** When you show Rashad the app beside the
   prototype, use the prototype's own data (عرس محمد، 21 يناير، 124 ضيف،
   7 مليون), never an empty plan beside a full one.
6. **Finish the work in progress first.** Run `git status` and `git log -5`
   before starting; never build on someone's half-done change without
   understanding it.
7. **Old screens to delete, not to polish:** done in the cleanup (D32): the
   money starter, `costs_screen.dart`, the old payment schedule screens,
   quick add, `WeddingStageContextLine`, the old plan creation form and
   `GuestOnboardingProvider` are gone with their tests and pins. Still
   undesigned and reachable: `WeddingDayModeScreen` (from the home on the
   day; map it to b05/y07 or remove it).

## For the next agent: read this first

1. **Where:** repo `D:\projects\aarast-groom-build` (a git worktree). Branch `groom-journey-build`. The Flutter app is in `mobile/`.
2. **Master plan:** `docs/superpowers/plans/2026-10-20-groom-journey-build.md`. Read its Global Constraints, Part 2 (definition of done) and the slices table in Part 3.
3. **Spec per screen:**
   - The prototype source is in `mobile/test/prototype/v3/*.dart`, and its renders are in `mobile/test/prototype/v3/out/<id>.png`.
   - What to keep and what to drop for each screen: `docs/superpowers/audit/groom_build_classification.md`, section A row `<id>`. The decisions are in section C.
   - The real file for each screen: `docs/superpowers/audit/mobile_arch_map.md` §6.
   - Endpoint contracts: `docs/superpowers/audit/api_map_*.md`.
4. **Rules:** read `AGENTS.md` and `ARCHITECTURE_CONSTITUTION.md` before coding.

## Rashad's standing rules (do not break)

- **Never merge** `groom-journey-build` into anything.
- Commit and push only to `groom-journey-build`: `git push -q origin groom-journey-build`.
- Commit one screen, or one tight group, per commit. Put the screen ids in the message, for example `feat(providers): ... (f02, w33)`.
- End every commit message with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Before every commit, run `git checkout -- mobile/linux mobile/windows`.
- Never stage `scripts/review-ledger*.mjs`, `mobile/linux`, `mobile/windows` or any keystore file.
- **No subagents.**
- Do not stop until the groom path is complete. Rashad's words: «ممنوع توقف الا وقد اكملت مسار العريس بالكامل».
- Own the logic. When the design is illogical, fix it properly, without patches. Record each difference in the list below so the prototype can be updated later.
- Reply to Rashad in simple Arabic, as an honest, critical partner who gives one recommendation.
- **Security:**
  - Never print or commit secrets: `.env`, Firebase, Meta/WhatsApp, SMTP, JWT, DB or admin credentials.
  - Never use or store Rashad's passwords.
  - Do not touch the phone R5CY31TM4PW unless needed.
- **Money:** tracking only. Never add payment processing or money movement.
- **Backend:** it is deployed once, at the end, by Rashad running `deploy/aws/release.ps1`. Auto mode blocks the agent from running it.
- **Encoding:** keep BOMs. For example, `guest.dart` and `contact_picker_service.dart` start with a BOM. For long edits, write a Python script to the scratchpad with the Write tool rather than inlining it in bash, because bash quoting breaks.

## Checks (run in `mobile/` before each commit)

```
flutter analyze --no-pub
flutter test --no-pub --exclude-tags golden          # 1319+ tests
node ../scripts/check-mobile-boundaries.mjs --strict # legal count = 188
node --test ../scripts/check-mobile-boundaries.test.mjs
```

From the repo root, also run `git diff --check`.

When you add or move a file, update the pins in `scripts/check-mobile-boundaries.test.mjs`:
- the owner export lists,
- the import records,
- the router show list,
- `r19LegalRecordCount`.

The visual contract is `test/core/widgets/aarast_visual_contract_test.dart`. Its rules:
- Every new screen is added to `screenFiles`.
- A file with `Form(` needs `AarastV3FocusPrompt`.
- Durable drafts need a draft binding.
- No gradients and no `BoxShadow(`.
- No raw `CircularProgressIndicator` or `LinearProgressIndicator`. Use `AarastInlineSpinner` or `AarastV3ProgressLine`.

The word «أقساط» is banned. Use «على دفعات».

**Journey kit:** build screens from these widgets:
- JourneyTextField, JourneyChip, JourneyButton, JourneyListRow, JourneyBox, JourneyNote, JourneyListState
- JourneyTabHeader, JourneySubHeader, JourneyRoundButton, JourneyTabSwitch
- JourneyAvatar, JourneyTag, JourneyBar, JourneyChoiceCard, JourneyPickerField

**Helpers:**
- `context.popOrGo(...)`
- `addMonthsClamped`
- `whatsAppChatUri` and `phoneCallUri`
- `arabicOrdinal`
- `nextLocalId(prefix)`. Use it for local ids, never the wall clock.

## Progress by slice

| Slice | State |
|---|---|
| 0 Foundation | Done |
| 1 Start / sign-in (17) | Done. w09 is built as drawn without «ضمّها لخطتي» (D31); the old w09 page is gone. |
| 2 Shell and home (8) | Done |
| 3 Money read (8) | Done, except **x03**, which no commit names. Verify it. |
| 4 Money write (12) | Done. c04 needed no code. |
| 5 Tasks (10) | Done. y14 adds the fireworks hero (`JourneyFireworksPainter`, no gradient) and the safety note to a fireworks task's details, without «150 ألف» (D31). |
| 6 Guests (12) | Done. w38 «كم بيحضر؟» opens from the guests summary card and shows the real answers only, no forecast (D31). |
| 7 Providers, customer side (24) | **Done.** Done: f01, f02, f03, f04, f05, f06, f07, f08, f09, x10, x11, x22, w30 (filter sheet), w31, w32, w33, w34, w35, x09, x12, y09, g04, b07; y13 needs no code (f02 with the «زينة البيت» category, which is admin data). |
| 8 Account / settings / plan (15) | **Done.** Done: g02, g07, g08, w07, w08, w39, g10, g11, w10, g03, w11, g01, g06, x07, x20. |
| 9 Participant (15) | **Done (D34).** Done: x04, q01, q02, q03, q04, x06, q17, q05, q18, q07, q08, q10, q12, q19, q21. Left: none; the old workspace, shared plans list and invite list are removed. |
| 10 V1.1 extras | Out of scope until after V1 |

**Slice 7 warning (AGENTS.md):**
- Do not overwrite the marketplace flows blindly.
- Port the UI only, and keep the `marketplace_api` calls as they are.
- The chat files are part of this slice: `chat/screens/chat_screen.dart` and `chat/widgets/conversation_list_view.dart`.

## Update 2026-10-24: f02 and w33 done, plus a cleanup pass

The f02/w33 work above is finished and committed, together with fixes found by running the real app:
- **D10:** the old shell bar («المال · التخطيط / عرس محمد») and the stage line («التخطيط · احسم المقارنة») are gone from every tab. The shell keeps only the status bar inset.
- **w29:** a plan kept on the phone shows no «بدون نت» line, because nothing in it waits. An account plan that is offline hides adding guests, because that write is not queued.
- **Q01 (real bug):** the money and task starters read the persona from `GuestOnboardingProvider`, which the app never creates. A groom's phone plan was offered «حجز قاعة النساء» and «اختيار فستان الزفاف». The persona now travels in `DashboardSummary.persona`.
- The quick-add button takes its tab's colour.
- «الحين» became «الآن» everywhere (the Yemeni dialect decision).
- `MOBILE_ROUTES.md` was regenerated: 5 routes were missing.

## Quality protocol: every screen, every session

Nothing is called done without all of these:
1. **Read first:**
   - the prototype PNG and its source,
   - the classification row (what to keep and what to drop),
   - the current code.
2. **Build, then run the real app.** Do not trust the widget tests alone. Use the web build at 384 px wide, at 100% and at 115% text. See "How to see the real app" below.
3. **Compare with the prototype on screen.** Look for:
   - two titles, or stacked notices,
   - wrong colours,
   - formal Arabic or Gulf words,
   - a promise the code does not keep,
   - another persona's content.
4. **Fix the cause.** When the same problem appears on two screens, fix the shared piece.
5. **Test what changed.** Add a widget test for the new behaviour. Do not edit an assertion unless a decision backs the change.
6. **Run the checks:**
   - `flutter analyze`,
   - the full `flutter test`,
   - both boundary gates,
   - `docs-sync --check`, `docs-verify` and `git diff --check`.
7. **Commit and push**, with the screen ids in the message.

### How to see the real app (verified 2026-10-24)

- **Local API:**
  - Database `aarast_groom` in the `aarast-db` container on port 5433.
  - Its env file is `backend/.env`, which is git-ignored. It holds local random secrets and dev OTP only.
  - The API runs on port 3215: `cd backend && npm run start:dev`.
  - `prisma/seed.ts` stops at a removed `dueDate` field on costs, so only cities, categories and 3 providers load. That bug is in the seed script, not the app.
- **Web build:** `cd mobile && flutter build web --profile --no-pub --dart-define=AARAST_API_BASE_URL=http://127.0.0.1:3215`.
- **Serving it:** run `python -m http.server 8790 --directory mobile/build/web` and open the browser pane at 384×832.
- **After a rebuild, the browser keeps the old `main.dart.js`.** Re-fetch the files with `fetch(path, {cache: 'reload'})`, then reload the page.
- **To test 115% text:** run `document.documentElement.style.fontSize = '115%'` in the page.

## Known follow-ups (not done yet)

- **Money starter:** deleted (D32). Money with nothing in it opens on «البنود» with «أضف أول بند».
- **Dead code:** removed (D32). Still without a screen: the Yemen governorate provider, API and offline cache (leave with the offline database's next schema step) and the unrouted `HomeScreen`.
- **`AarastButton`** keeps one user, `WeddingDayModeScreen`. Delete it once that screen moves to the kit (or is removed).
- **Tasks:** the «تحديد الميزانية» starter task stays open after the budget is divided.
- **Promised to the client in `V1_DELIVERY_CHECKLIST.md` but not in this build (section B: needs backend):**
  - 4.1 the wedding events (المقيل، السمرة، الزفاف، الحناء);
  - the rafd book;
  - the mahr agreement section. Since C1 hides the mahr from the budget, the groom has nowhere to track it now.
  - Discuss these with Rashad right after the groom path.

## Design differences to record in the prototype later

Each line is a place where the app differs from the prototype:

- «أقساط» becomes «على دفعات».
- A cost with payments cannot be cancelled (w23).
- No partial pledge.
- No undo after an offline payment (c04).
- No reminder toggle per loan.
- No task links or amounts.
- No «بعد العصر».
- No hall capacity line.
- No guest timeline and no rafd.
- The invite card is a solid colour, not a gradient.
- The task form has no category or priority.
- The data-saver images mode waits for its setting in slice 8.
- x22: «قاعات لعرسك» instead of «قاعات فاضية يوم عرسك» (no free-day data); «على قد بندك» only when the hall item has an amount.
- y13: no category line («تركيب قبل السمرة وفك بعد العرس · يغطون صنعاء»; a category has no description) and no «فاضي يوم 17».
- f07: no «المناسبة» row, no «شاركهم رقمك», no 7-day expiry (D15); the time goes into the message.
- f06/w32 (D17): w32 opens by pressing the provider's name (the prototype shows no opener); no «نسخة 2» line on the offer; «احظر المزود» says only «ما يقدر يراسلك»; the photo button stays inside the field.
- b07 (D22): no payoff month, no rafd/thanks/ledger/book cards, no provider count on the rating card.
- g04/x12/w35 (D21): no quick tags, no provider reply line, no reminder, «يطلع باسمك: …» instead of «باسمك الأول بس».
- x09 (D20): no banner, no «سحب عرضه», no «ذكّره», no reason or free-alternatives count.
- y09 (D19): «ليلتك محجوزة / عند …» instead of «… محجوزة ليلتك»; no «صار محجوز 4 من 6»; solid cobalt instead of the sky gradient.
- w34 (D18): opened from the providers status line (the prototype shows no opener); a back-arrow page; no «ذكّرهم», no response time, «شوف غيرهم» instead of «شوف فنانين فاضيين يوم 21».
- f03: no «عرسان دفعوا فعلًا · من 11 عرس», no «فاضي ليلة 21 · باقي فريقين», no «عنده فريق مصوّرات» (no data behind any of them). The price box is labelled «أسعاره». Prices read 450,000 ر.ي, not «450 ألف».
- w09 (D31): no «ضمّها لخطتي» (import-local always makes a new plan), «خلّها خطة ثانية» chosen to start with, no «آخر تعديل» lines; «تجاهلها» asks a second time.
- y14 (D31): no «البند · 150 ألف» row, no «ليلة الزفاف · قدام البيت», the d04 rows and actions of every task; known by its title.
- w38 (D31): real counts only, «· N اعتذروا» when some declined, the no-guess note only up to half answered, opened from the guests summary card.
- No floating «إضافة» on any tab (D32); the tasks and guests add from their header «+».
- c02/c07 (D32): «باقي البنود» loads more agreements; a payment date is added, changed or removed in a sheet from c07 and from «عدّل الموعد» on c06; a private agreement shows a lock.
- g09 (D32): a sheet, not a page; the note says every device is signed out.
- w01 (D32): no «تأكدنا إنه رقمك»; a refused code goes back to «الرمز»; a closing «غيّرنا كلمة المرور» when signing in again fails.
- w11 (D32): «خطة جديدة» starts the welcome steps at a02b.
- b11/w36/w37 (D32): no «لو» box, market range or microphone; w36 without «ويقرأ الفواتير» and the account switch line; w37 only the limit and offline cards, without «سجّل يدوي».
- Participant (D34, D55): no relation («أخوك») or owner name is sent, so the owner is «العريس/العروسة»; the participant is spoken to as who they are (D55: the account's persona, else the member's role) and sees the plan's colours, so a groom helping in a bride's plan reads «تساعد فيها» on rose (q04 drew «تساعدين فيها» for him); no «اطلب من محمد» or request buttons (q13), no rafd rows, no programme or time of day, no custody step; x06 has a bell; q05's «كل مهام الخطة» is back since D52; q10 leave says «تقدر ترجع لو أرسل لك دعوة ثانية» and keeps g02's settings below; q19 only «في الذكريات»; q21 plain rows.
- Provider «خدمتك وسعرها» sheet (D48, D49): not drawn. p09's service field and p08's «عدّل طلبك» open a journey-kit sheet (`provider_joining_service_sheet.dart`) with the team's note, the name, the price in ر.ي and «ايش تشمل»; before approval only these change (B-10), so the drawn p06/p36 service form is not reused.
- a17 (D51, B-43): one paid plan «مميز»; the «احترافي» card and plan are not built (nothing in the app would make it differ). The «الدفع» column shows the administrator's note on how he paid («كاش · 3 شهور») with «سجّلها …», no amount; there is no «ينتظر الدفع / ما تفعّل» row (a placement exists only once recorded); «خلص · ذكّره» is «خلص» (the hourly job tells the provider at the end). The record form, «جدّد», «وقّفه» and «ألغه» are not drawn; a booked one reads «يبدأ …», a stopped one «انوقف». D54: the table lists the running and booked placements by default (its title «الشغّالة والمحجوزة»), the finished ones behind the undrawn filter «اللي خلصت»; a running placement on a provider customers cannot find reads «مو ظاهر للعرسان» instead of «شغّال»; the record dialog says «يطلع مع المميزين أول» instead of «يطلع أول في قسمه ومدينته» (several featured providers share the top).
- p35 (D51, B-43): an undrawn «الظهور المميز» row after «أداؤك»: «مميز لين 31 ديسمبر», «يبدأ … · لين …», or «ظهور عادي · تبي تطلع أول؟ كلّم فريق اعّرست»; it opens support. B-43 named p35 for the provider's plan, but p35 draws none. D54: the date is the end of his run of back-to-back renewals, read against the clock when shown.
- f02 (D54, B-43): the drawn «مميز» tag stays as drawn; tapping it opens an undrawn journey-kit sheet «مميز» «هذا المزود دفع عشان يطلع أول. مو ترشيح من اعّرست.» with «فهمت», so a paid placement is never read as اعّرست's recommendation (a17's own note asks for that). The tag shows only until the placement's `featuredUntil`, also on a saved offline copy.
- p08 (D49): «عدّل طلبك» first asks «ايش تبي تعدّل؟» (the journey kit's option sheet) with «بيانات ملفك» and «خدمة «…» وسعرها»; the design draws only the button. «تقدر تعدّل وتضيف صور وأنت تنتظر» stays «تقدر تعدّل بيانات ملفك وأنت تنتظر» (photos after approval, F2).
- Request and offer (D50): p19 «اسحب العرض» is confirmed in an undrawn journey sheet «تسحب عرضك لمحمد؟»; p16 shows undrawn rows «ميزانيته» / «رقمه» when the customer shared them and an undrawn note after a withdrawn offer; f06 «نسخة 2 · …» is worded from the changed field («غيّروا التفاصيل بنفس السعر») instead of the drawn «أضافوا الألبوم»; the same version line sits on the customer's offer card; x09 adds an undrawn «انتهى بدون رد» card; amounts read «480,000 ر.ي» instead of «480 ألف».
- Reading is separate from editing (D52): the read-only states are not drawn, so each is its drawn screen without its controls. «يشوف بس»'s home is x06 with the plan's next open task («على صالح», no «خلصت») and «مهام الخطة · خلصت 12 من 20»; his tasks are d01's sections without the circle's action, «+», share, swipe or person chips, under «تتابع المهام وين وصلت…»; «كل مهام الخطة» on q05 opens the same list; guests without the guests right are e01's figures and every guest by name and reply, without phones, reminders, add or groups; q16 has no «مسؤول القاعة يوم العرس · اتصل» card (no contact is shared) and no time of day, its line reads «المواعيد ومين محجوز. الأسعار والعروض عند العريس.»; a helper's «طلباتي» adds an undrawn «في الخطة» card (the plan's bookings) above his own requests. The role pill reads «أنت تتابع بس» (q16's subtitle «تشوف بس» stays on the providers page).
- Admin (D56): the old «الإشعارات» page is deleted (no design, no link). The pages the admin designs list in the sidebar but never draw («الخدمات», «المستخدمون») and the catalog's undrawn pages («المدن», «المحافظات والمديريات»), sign-in, the unknown-address and error pages, and a05's «أضف مزود بلا حساب» and «استيراد ملف» windows are drawn with the desk kit of the designed pages. The catalog's undrawn links row «الأقسام · الكتالوجات · المدن · المحافظات والمديريات» stays: a08 and a09 share one «الكتالوج» link, so without it a09, the cities and the areas cannot be reached. Every other undrawn admin button leads to a working action and stays (listed in the admin classification). «المستخدمون» changes no account itself: a row opens a13, where disabling says what it does. The moderator sees «ملفات بلا حساب» (drawn for operations and support) and the moderator and support see «الباقات والظهور المميز» (drawn for operations), read-only, because the server lets every role read providers.
- The mahr (D55): a06 is the welcome's third step as drawn; for a plan that already exists, b01's «المهر» step opens the same fields on an undrawn page of their own («اتفقتوا على المهر؟» with «احفظ المهر» and «ما اتفقنا بعد»). b02's mahr card stays until the mahr is complete, then leaves the home; y08's moment is not built, and b02's «بعدها» mahr row and «ذكّرني» are not built. c01's mahr card opens the agreement (c07) for the groom and «من وين» for the bride. A mahr recorded once is changed through its agreement, payments and sources, not through a06 again.
- w20 (D55, G14): opened from c03 by an undrawn «مين دفع ايش» link; the chips are each payer with the name written on the agreement («الوالد», «خالي أحمد») and «أنا» for the plan owner's own party; a payment is listed under its agreement's payer, because a payment records no payer of its own.
- Voice (D55): every sentence follows its reader's gender and every noun about the plan's people follows the plan (a bride's guests are «الضيفات», her hall «الصالة», and its tab «الضيفات», for whoever reads); the provider portal stays masculine as drawn, and an administrator's free-text note is shown as written. p16's «اسأله قبل ما ترد» is «اسأل قبل ما ترد»: the customer may be the bride.
- Search from a money item (D57, G40): f02 draws one chip for the kind searched («فنانين وفرق», «مزينات ونقاشات»); the app's first chip is the item's own name («الفنان والفرقة», «المزينة والنقاشة»), selected, before «الكل», and it searches every directory category the server lists for that item. The bride's f02 lists «صالون لمسة» under «مزينات ونقاشات»; a salon's offer files under the makeup-and-hair item, so it is not in that search and the demo leaves it out. An item no provider's offer lands in shows no «ابحث» (f01 draws one on every row not started). The board's row icons are pictures only: «البخور» a flame and «المزينة والنقاشة» sparkles, as f01 draws them.
- Whose money paid (D59): the designs draw every payment as the owner's («دفعت منها 4.6», «صرفت 4.6 · معك 2.9»), while w20 draws the father paying 2.2 of it. The app splits it: c01's sentence reads «دفعت منها X، ودفع عنك الوالد Y» and its bar has a «دفع عنك» piece, «عرسك» reads «دفعت X · دفع عنك Y», c05 reads «صرفت» as what the owner's own money paid, and «معك» leaves out what others paid; b02's side figures do the same before money in is known. A participant reads the owner named («اتفق العريس على …»، «العريس سلّم 2 مليون»، «باقي على العروسة») instead of the drawn «اتفقت» or «باقي تدفع».
- «سجّل المهر» (D59): not drawn (the designs always have the mahr). c01 and c02 show it, in the journey kit's row, to the owner of a groom's or a bride's plan whose mahr is not recorded (a06 skipped, an older plan, or its agreement deleted); it opens a06's page.
- c14 (D59): the drawn message counts the mahr in «العرس بيكلف 10 مليون» and lists «المهر 3 مليون (سلّمنا 2)» first among «أكبر البنود». The shared summary keeps the wedding budget's own figures, gives the groom's mahr its own line «المهر (خارج الميزانية)» and never lists it among the items; the bride's mahr is her funding and is never shared.
- w20 (D59): the drawn avatar of «الوالد» is «ع», which no rule derives from «الوالد»; the app shows the first letter after the article («و», «ع» for «العروسة», «خ» for «خالي أحمد»). The heading's verb agrees with the payer («العروسة دفعت», «الأهل دفعوا»), and a shared agreement reads «المدفوع المشترك».
- c05 (D59): matches the bride's PNG: «صرفتِ 2.6 · معك 1.9» and the sources received first with the mahr leading them, then what is promised, in the order recorded. A promise past its day reads «متأخر» with «كان موعده …» (not drawn), and c12 asks «متى توصل؟» for promised money (not drawn).

## At the end of the groom path

1. ~~Clean up the old screens~~: done (D32), except `WeddingDayModeScreen`.
2. Regenerate the goldens.
3. Build the release APK. Firebase dart-defines are read at build time from `%USERPROFILE%\Downloads\google-services (3).json`, and their values are never printed. A cloud session cannot do this step; it needs Rashad's machine.
4. Update the prototype with the differences above.
5. Rashad runs `deploy/aws/release.ps1`.
6. A real domain is still needed.
