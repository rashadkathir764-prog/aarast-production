# Agent Rules

These rules apply to every AI agent working on Aarast / اعّرست.

## Read first, in this order

1. `docs/project/STATUS.md`: where we are, what is left. This is the only progress record.
2. `docs/project/DECISIONS.md`: the decisions in force.
3. `docs/project/DESIGN_STATUS.md`: which screens are built, left or deferred.
4. `docs/README.md`: the map of everything else.

## No going back

- The present is the code, the schema and these documents. Old plans, audits, reports and prototypes were removed on purpose.
- Do not restore, recreate or summarise anything from Git history as a plan. Read history only to answer one specific question.
- Do not open a new direction, redesign, audit or roadmap unless the owner asks for it. Take the next item in `STATUS.md`.
- Take the professional decision and keep working; show the owner the result per batch (D111). Do not invent a business rule: a money rule, a permission or a sensitive operation that the system does not settle is written under «أسئلة قواعد العمل» in `docs/project/DESIGN_STATUS.md` with its evidence and options, and the work that does not depend on it goes on.
- Record only what was done. A check that was not run is written as not run, with the reason.
- Do not add plan, report, inventory or tracking files. Progress goes in `STATUS.md`, a decision goes in `DECISIONS.md` as one line.
- Two exceptions, by the owner's order:
  - 2026-11-06: `docs/project/RELEASE_AUDIT.md` is the pre-release closing round's inventory, coverage and issue log. Update it after every batch; `STATUS.md` points to it and holds the resume point.
  - 2026-11-11: `docs/superpowers/plans/2026-11-11-groom-screens-home-language.md` and the mockups under `docs/superpowers/specs/2026-11-11-mockups/` are the plan of the UI work the owner opened (D110). No other plan file is added beside them.
- The seven files under `docs/superpowers/{plans,specs,reports}` dated 2026-08 and 2026-09 are pinned by the architecture gates. They are fixtures, not plans. Do not read them for direction.

## Frontend freeze (D67, D68)

- The look is frozen on «فيروز», with one colour per plan. No new palette, visual direction or redesign before real users are on the app. The `frontend-design` skill stays off until then.
- The owner opened the freeze this far, and no further: the money tab on its approved concept (D102), the couple's screens in the layout he approved on the plan's home (D110), and the pre-release quality round over every screen (D111). The reference in all three is the present identity: the «فيروز» colours, the type, the kit and the approved home. Composition, hierarchy, detail and consistency are raised; no new identity and no change of direction. Inside this round the `frontend-design` skill may be used, for composition only.
- A screen is judged in three separate dimensions, each with its own evidence: function, experience, looks (D111). A fixed defect is not a raised screen, and a green build, test run or CI is no verdict on experience or looks.
- A screen starts from its nature and its user's goals, not from one template. The screens share the system, not a mould.
- A shared widget is extracted only when a second screen needs it, after its present state is recorded, with pictures showing nothing went back.
- No new screen or feature unless it completes a broken journey.
- Every frontend change needs one of three reasons: a proven defect, a journey that stops, or a real user who stumbled. The owner may overrule after seeing the cost.
- Anything drawn uses the app's own widgets.
- Before touching a screen, fill the card in `.claude/skills/aarast-screen/SKILL.md`.
- «خلص» needs three proofs: checks you ran, a shot from the real app, and a walk with the user's eyes.
- The design reference is `docs/frontend/DESIGN_SYSTEM.md`.

## Git

- All work lands on `main` in `D:\projects\aarast`. No branch or worktree stays behind. One exception, by the owner's order (D111, 2026-11-12): the pre-release round lives on `phase/pre-release-audit`. It is never merged into `main`, deployed from, or used for any production operation without his explicit word; work on it is pushed to that branch only.
- Every session starts by looking for work that is not on `main`: `git fetch --all --prune`, then `git branch -a --no-merged main` and `git worktree list`. Anything listed is merged, or its fate decided with the owner, before new work starts. (On 2026-11-07 a local session and a cloud session fixed RA-BE-63, 64, 65 and 83 on the same night, each without seeing the other; one of the two fixes had to be thrown away.)
- A session that cannot write to this folder (a cloud session) works on one branch cut from the current `origin/main`, never from another unmerged branch's work it has not read, and writes in the first lines of `STATUS.md`: the branch, that it is not merged, and what it could not check there. The next session on this machine merges it first, runs the gates on Windows, and deletes the branch.
- A subagent's worktree is merged or removed in the session that made it.
- Commit or push only when the owner asks, or when the task he gave says so.
- Commit only after the checks for the touched area pass: `node scripts/gates.mjs --quick` (or `--only` the area). `main` is pushed only after `node scripts/gates.mjs --full --strict` passes on Windows, where the golden images are drawn.
- A push is not finished until its CI run on GitHub is green in every job (`gh run list --limit 3`, then `gh run view <id>`). A red job is fixed at its cause; no job, check or scan is removed, skipped or loosened to turn it green.
- A list of tests known to fail is not a gate. The one that exists (`docs/qa/mobile-test-baseline-linux.txt`, a Linux box's 54) may only shrink, never excuses a failure on Windows, and a session that leans on it says so in `STATUS.md`.
- Never commit secrets. Never read out `.env`, Meta/WhatsApp, SMTP, JWT, database or admin credentials.

## Architecture

- Read `ARCHITECTURE_CONSTITUTION.md` and `ARCHITECTURE.md` before architecture work.
- Cross-context backend code consumes only the owner's public contract. No foreign Prisma root, relation or SQL access, deep cross-context import, `forwardRef()`, or project-owned `@Global()`.
- Business-owner Prisma access belongs only in that owner's `infrastructure/`.
- Do not weaken a gate, add a masking baseline or exception, or change a behavioural test to make a defect pass.
- Preserve published migrations.
- No new Mobile boundary-baseline entry, unresolved local directive, or cross-area `part` relationship.

## Product limits

- No payment processing, deposits collected, financing, or anything that needs a licensed financial partner.
- Financial data is private by default. Shared members see it only when permissions allow it.
- Keep Arabic and RTL intact, Yemeni dialect, in the reader's gender. The word «أقساط» is banned in the UI.

## Engineering rules

1. Reproduce before fixing; if reproduction is impossible, provide concrete evidence and state the blocker.
2. Fix the root cause, not the symptom; reject band-aids, silent fallbacks, and cosmetic patches.
3. Do not introduce workarounds, hacks, or compatibility layers without explicit approval and a removal plan.
4. Verify before claiming completion; report the exact checks performed, results obtained, and remaining uncertainty.
5. Think like a production engineer: correctness, simplicity, safety, maintainability, operability.
6. Protect existing tests; never delete, skip, weaken, or rewrite them merely to make the implementation pass.
7. Fix the earliest incorrect source instead of patching the same symptom downstream.
8. Keep the design minimal; add abstractions or dependencies only for a concrete current need.
9. Handle success, failure, timeout, retry, invalid input, duplication, and other relevant edge cases.
10. Never hide errors, warnings, or failed checks.
11. Keep one implementation of each thing.
12. Keep changes tightly scoped and report every changed file.
