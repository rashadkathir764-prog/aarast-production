# Batch 7 report (integration fixes + Batch 7)

Status: DONE_WITH_CONCERNS (see Concerns).

## Part A: the 11 backend failures

| Test | Cause | Fix |
|---|---|---|
| 15, 29 account-deletion; 2444 plan-deletion | 031f6bc5 (RA-OP-32) added the ErasedPlan re-deletion list; the fakes had no `erasedPlan` | Fakes gain it. account-deletion now also asserts the plan ids are listed after the plans are deleted; the plan store answers `findUnique` from its real erased state. Product unchanged. |
| 345, 346 R12B | 3ccef689 (RA-MO-335, «صنعاء» said once) edited the R12B-moved `planning/public/wedding-location.ts`. After the R12C closure the gate checks live invariants only (`scanR12bClosed`), but these two tests read live bytes as lineage | The byte lineage is read at the closure's lineage commit, as R12C already does (b9b0f271). Export checks stay on the live file. No pinned hash changed (7836f0cf is the lineage bytes). |
| 575, 576 R6 | 5b4ca4e5 (RA-MO-360) and 3434fb98 (Q-52) edited the protected `openwa-otp.channel.ts`. The lineage fixture copied the live file | The fixture writes the two protected files from the lineage commit, as it already did for the ownership baseline. Pinned hashes unchanged. |
| 582 R6 Task 2 | ec7c5bda (RA-BE-141) exported the adapter class from the internal module. This broke "only the token leaves" | Product fix: AuthService injects `IDENTITY_TRANSIENT_DELIVERY_IMPLEMENTATION` typed as the adapter, and the internal module exports only the token. R3 injection identity still passes (not a canonical port pair). |
| 937 auth-refresh-wiring | b9f1234e (RA-BE-149) moved `JWT_ACCESS_EXPIRES_IN` into `identityJwtModuleOptions` | The source match becomes: the module registers those options, and the options give 15m by default and the configured value when set. |
| 1244 lifecycle locks | f3b80d06 (Q-42 أ, RA-BE-170) added `setConversationPushStopInTransaction` | The exact method set includes it. |
| 1321 dto-text-bounds | 348d43ae (Q-50 أ) added `AdminConversationReportStatusDto.note` with no DTO bound | Product fix: `@MaxLength(CONVERSATION_REPORT_CLOSING_NOTE_MAX_LENGTH)` (500). |

## Part B: Batch 7

1. **bcrypt (RA-BE-149).**
   - `password-hash.ts` defines `PASSWORD_HASH_COST = 12` and `OTP_CODE_HASH_COST = 10`, with the reason for 10 in a comment.
   - Every password write uses it.
   - After an application password login, a hash below 12 is re-hashed into its own field. This runs as a compare-and-swap after the login transaction. A failure is logged as `password_hash_upgrade_failed` and never fails the login.
   - The admin console keeps its existing upgrade, now on the same constant.
   - Dummy hashes: 12 for passwords, 10 for codes.
   - The demo seed and `create-admin.cjs` follow the new cost.
   - Two tests pinned the old rule and were moved to the new one: `auth-app-password-phone-proof` (cost 10) and `admin-dto-text-bounds` (currency of 8 characters).
   - Tests: `backend/test/password-hash-cost.test.ts`.
2. **Currency (RA-BE-149).**
   - `shared-kernel/money/currency.ts` holds `SUPPORTED_CURRENCIES` = YER, SAR, USD. These are the mobile `weddingCurrencyOptions`, and offers must be in their plan's currency.
   - `@SupportedCurrency()` replaces `@MaxLength(8)` in all 11 currency DTOs. `ImportLocalPlanDto` inherits it.
   - Any other value gets a 400 whose message starts with `UNSUPPORTED_CURRENCY:`.
   - **No DB CHECK was added.** `WeddingPlan.currency` already has `^[A-Z]{3}$`, and the API accepted any 3 letters for plans and any text up to 8 for prices. Migrations and seeds cannot prove that production rows fall inside the list, so a narrower CHECK could fail the deploy or later updates.
   - Tests: `backend/test/supported-currency.test.ts`.
3. **RA-MO-339 rest.**
   - `AuthStorage.readRemovedPlanPaths` and `saveRemovedPlanPaths` store the data in the secure vault where one exists, otherwise in preferences. The data is bound to the signed-in user and cleared on `clear()`.
   - The controller restores it on construction and persists it after each refresh.
   - The gate calls `removedPlanPathShown`, which drops the entry from the phone. It stays in memory for the rest of that run.
   - The entry is also dropped when the plan is held again, and when the context is cleared (logout or exit).
   - Tests: `mobile/test/features/account_contexts/removed_plan_memory_test.dart`.
4. **Guest words (D55).**
   - `planEventLabel(event, planEventNaming(persona, events))`: in a BRIDE plan, SAMRA is «الحفلة» and MAQEEL is «النسمة». This applies to the RSVP texts and page, the reply notice and the summary counters.
   - **Duplicate rule:** if another occasion of the plan is already called by that word (her HAFLA or NASHMA, or a title with that word), the groom's event keeps its kind's word («السمرة»/«المقيل»). A date cannot disambiguate, because it may be missing or the same day.
   - The mobile `occasionText` (now takes `planEvents`) applies the same rule. Samra and maqeel are removed from `_serverEventWords`.
   - Tests: `backend/test/plan-event-guest-words.test.ts` and `mobile/test/features/guests/occasion_guest_words_test.dart`.

RELEASE_AUDIT:
- RA-BE-149 → «أُصلح».
- RA-MO-339 → «أُصلح» (all of its listed defects are now fixed).
- The RA-MO-324 cell is extended with what this batch did.

## Commits (on ccr-4726748a-8lm5a4, not pushed)
- 152e80e1 test(erasure): the account and plan erasure fakes hold the re-deletion list of plans (RA-OP-32)
- 74c50a1f test(r12b): the moved location's byte lineage is read at the lineage commit once closed
- 8e9147d9 test(r6): the lineage fixture holds the protected transport files at the lineage commit
- 9f456141 fix(identity): the old-number notice reaches the adapter by its internal token; the internal module exports only that token (R6, RA-BE-141)
- da99a504 test(auth): the access lifetime is checked through the JWT options jwt-keys builds (RA-BE-149)
- 50925a9f test(messaging): the lifecycle's exact method set holds setConversationPushStopInTransaction (Q-42 (أ), RA-BE-170)
- 5df1867d fix(admin): the report's closing note is bounded in its form (RA-BE-15, Q-50 (أ))
- b29a34b2 fix(auth): passwords hash at bcrypt 12 from one constant, and a sign-in re-hashes an older one (RA-BE-149, D124)
- 030a688a fix(money): a request's currency is one of the product's three, else a 400 naming UNSUPPORTED_CURRENCY (RA-BE-149, D124)
- 56641d5a fix(contexts): whose plan a participant was taken off survives the app's restart until the gate has said it (RA-MO-339)
- df627200 fix(guests): a bride's plan tells its guests the groom's night and afternoon in her words, never two occasions by one name (D55, Batch 5 note)
- 8af21d1c fix(identity): the password re-hash names its field in each statement, so the ownership scan reads it (RA-BE-149)
- a39a360e test(admin): a service's currency is checked against the product's list, not by length (RA-BE-149)
- 9ad84ece docs(audit): RA-BE-149 and RA-MO-339 fixed, RA-MO-324's guest words follow on the server (Batch 7)

## Verification
- Backend `npm test` (full): tests 3087, pass 3060, fail 0, skipped 27 (on HEAD 9ad84ece). The run before it failed 1: the old currency-length case, which a39a360e moved to the list rule.
- `npm run check`, `npm run architecture` (all PASS, published migrations pinned=145, none added), `security:prisma-config-merge`, docs-sync, docs-verify, mobile boundaries (strict and tests), `git diff --check`, `flutter analyze`: all clean.
- Flutter:
  - The new tests pass: removed_plan_memory 5/5, occasion_guest_words 4/4.
  - `test/features/{account_contexts,guests,wedding_day,shell}` and `test/core/storage` fail only on golden pixel tests: `account_context_error.png` and the 7 cases in `guest_invite_golden_test`. They fail identically on the untouched tree, so they are Linux font rendering.

## Goldens to redraw
None. The invite goldens use the groom's profile (labels unchanged), and no golden draws the removal gate.

## Concerns
- Resolved after this report: one naming rule, `PlanEvent.nameIn(profile, planEvents)`, now names every event of a plan (guests chips and screens, plan events screen and sheet, wedding moment, dashboard week and day, partner home); a bride's plan with samra plus hafla reads «السمرة» and «الحفلة», not «الحفلة» twice (`plan_event_names_screens_test.dart`, `plan_event_names_test.dart`). No golden changes.
- The server labels the wedding row «العرس», while the mobile `occasionText` gives the wedding the app word. This was pre-existing and is not touched.
- A plan stored with a currency outside the list (none known; only possible through the API before this batch) can no longer send its own currency in `ReplaceMoneyBudgetDto`.
- Golden tests were not run on Windows here.
