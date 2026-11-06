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
- Do not add plan, report, inventory or tracking files. Progress goes in `STATUS.md`, a decision goes in `DECISIONS.md` as one line.
- One exception, by the owner's order on 2026-11-06: `docs/project/RELEASE_AUDIT.md` is the pre-release closing round's inventory, coverage and issue log. Update it after every batch; `STATUS.md` points to it and holds the resume point.
- The seven files under `docs/superpowers/{plans,specs,reports}` dated 2026-08 and 2026-09 are pinned by the architecture gates. They are fixtures, not plans. Do not read them for direction.

## Frontend freeze (D67, D68)

- The look is frozen on «فيروز», with one colour per plan. No new palette, visual direction or redesign before real users are on the app. The `frontend-design` skill stays off until then.
- No new screen or feature unless it completes a broken journey.
- Every frontend change needs one of three reasons: a proven defect, a journey that stops, or a real user who stumbled. The owner may overrule after seeing the cost.
- Anything drawn uses the app's own widgets.
- Before touching a screen, fill the card in `.claude/skills/aarast-screen/SKILL.md`.
- «خلص» needs three proofs: checks you ran, a shot from the real app, and a walk with the user's eyes.
- The design reference is `docs/frontend/DESIGN_SYSTEM.md`.

## Git

- All work lands on `main` in `D:\projects\aarast`. No branch or worktree stays behind.
- Commit or push only when the owner asks, or when the task he gave says so.
- Commit only after the checks for the touched area pass.
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
