# Groom Journey Build — Handoff (2026-10-23)

## ملخص لرشاد

- الفرع `groom-journey-build`، وكل الشغل المكتمل مرفوع على `origin`.
- خلصت الشرائح 1 إلى 6: البداية، الرئيسية، الفلوس، المهام، الضيوف.
- الشريحة 7 (المزودين، جهة العميل) مكتملة: 24 شاشة من 24.
- شاشة «استكشف» (f02 وw33) مكتملة ومرفوعة، وبعدها «نبدأ بالقاعة» (x22) وصفحة المزود (f03).
- إصلاحات 2026-10-24 من تشغيل التطبيق الحقيقي: موعد العرس ما عاد ينقص يوم (D11)، الخطة المحفوظة تنفتح بدون «اختر المسار»، الرئيسية ما تقول «ما عندك خطة بعد» وهي تحمّل، و«استكشف» ما فيه «خدمات قريبة من بندك» (D12).
- باقي: بقية الشريحة 7، ثم الشريحة 8 (الحساب والإعدادات والخطة)، ثم الشريحة 9 (المشارك)، ثم التنظيف والتسليم.

## RULE ZERO: the prototype is the law (read before anything else)

It holds for **every journey**, each against its own prototype:
- groom and participant: `mobile/test/prototype/v3/out/` (187 PNGs);
- provider: `mobile/test/prototype/provider/` (54 PNGs), spec
  `docs/project/PROVIDER_JOURNEY.md`;
- admin web: `mobile/test/prototype/admin/` (26 PNGs);
- bride: the groom screens with rose colours, feminine wording and her
  items, per `docs/project/JOURNEY_PROFILE.md` and
  `mobile/test/prototype/bride_profile/changes.tsv` (no PNGs of its own).

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
7. **Old screens to delete, not to polish:** the money starter
   (`money_starter_setup.dart`, still a fallback for plans made before
   `c9b2ce56`), `costs_screen.dart`, the old payment schedule screens, the
   old w09 import, quick add, `WeddingStageContextLine`. Remove each with its
   tests and pins in the cleanup step.

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
| 1 Start / sign-in (17) | Done. **Verify w09**, the local-plan import: no commit names it, and the old-screens cleanup still lists it. |
| 2 Shell and home (8) | Done |
| 3 Money read (8) | Done, except **x03**, which no commit names. Verify it. |
| 4 Money write (12) | Done. c04 needed no code. |
| 5 Tasks (10) | Done, except **y14**, which no commit names. Its hero must be a CustomPainter, with no gradient (D3). |
| 6 Guests (12) | Done, except **w38**, which no commit names. Verify it. |
| 7 Providers, customer side (24) | **Done.** Done: f01, f02, f03, f04, f05, f06, f07, f08, f09, x10, x11, x22, w30 (filter sheet), w31, w32, w33, w34, w35, x09, x12, y09, g04, b07; y13 needs no code (f02 with the «زينة البيت» category, which is admin data). |
| 8 Account / settings / plan (15) | Not started: g02, g07, g10, g11, w39, w07, w08, g08, w10, g03, w11, g01, g06, x07, x20 |
| 9 Participant (15) | Not started: x04, q01, q02, q03, q04, x06, q17, q05, q18, q07, q08, q10, q12, q19, q21 |
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

- **Money starter:** NOT in the prototype; do not redo it. Since `c9b2ce56` a new plan (phone or account) opens Money on its a05 items, so the starter only appears for plans made before that. Delete it in the cleanup step (rule zero, 7).
- **Dead code to remove, with pin updates:**
  - `WeddingStageContextLine` and `WeddingStageDomainGuidance`, which have no screen left;
  - `GuestOnboardingProvider`, which nothing provides.
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

## At the end of the groom path

1. Clean up the old screens: costs_screen, the payment schedules, the old w09 and quick add.
2. Regenerate the goldens.
3. Build the release APK. Firebase dart-defines are read at build time from `%USERPROFILE%\Downloads\google-services (3).json`, and their values are never printed. A cloud session cannot do this step; it needs Rashad's machine.
4. Update the prototype with the differences above.
5. Rashad runs `deploy/aws/release.ps1`.
6. A real domain is still needed.
