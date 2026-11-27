# Agent Rules

For every AI agent working on Aarast (Flutter app in `mobile/`, NestJS + Prisma + PostgreSQL in `backend/`, admin panel in `admin-web/`).

## Start here

- Read `docs/project/STATUS.md`. Nothing else is read up front.
- Look things up only when the task needs them: a decision by its number or topic in `docs/project/DECISIONS.md` (search it, do not read it whole); everything else through the map in `docs/README.md`.
- `docs/archive/` holds closed records. Search it for one id (`RA-MO-368`, `Q-54`); never read it for direction, never update it.
- If a rule here disagrees with the code or with what the owner has just said, tell him and fix the rule. Do not work around it.

## How the work is done

- One small task per session. Before any change, write one acceptance scenario: who the user is, what they do, what they must see. The same scenario is run on the real app at the end.
- Reproduce a defect before fixing it. Fix the earliest wrong source, not the symptom. One implementation of each thing.
- Touch only what the task needs. Never remove a function while simplifying: check its callers first.
- No new audit, redesign, roadmap, screen or feature unless the owner asks for it.
- Do not invent a business rule (money, permission, sensitive operation). Write the question under «ينتظر رشاد» in `STATUS.md` and go on with what does not depend on it.
- No new plan, report, inventory or log files. Progress replaces the matching lines in `STATUS.md` (it stays under 60 lines). A decision is one line in `DECISIONS.md`.

## Done means

1. The checks for the touched area ran and passed: give the command and its result.
2. A screenshot or walk from the real app shows the acceptance scenario.
3. What was not run is written as not run, with the reason.

Green tests, a green build or green CI are no verdict on experience or looks.

## Screens

- The look is «فيروز» and it is approved. No new palette, identity or visual direction.
- Keep the approved screen's anatomy and add only the correct logic (D133). Show the change as a side-by-side picture at phone size (before | after).
- The owner approves that picture before a visual change is built further.
- Fill the card in `.claude/skills/aarast-screen/SKILL.md` before touching a screen. It is the only design guide here: no other design skill and no design subagent.
- References: `docs/frontend/DESIGN_SYSTEM.md`, copy in `docs/project/LANGUAGE.md`, money figures in `docs/project/MONEY_TERMS.md`.

## Checks

```powershell
node scripts/gates.mjs --quick                  # before a commit
node scripts/gates.mjs --quick --only mobile    # one area: backend, admin, mobile, root
node scripts/gates.mjs --full --strict          # before a merge into main, on Windows
& D:\projects\aarast\scripts\walks\walks.ps1 -walks @('groom')   # the real app, see docs/qa/JOURNEY_WALKS.md
```

Details in `docs/qa/README.md`. Never weaken, skip or remove a gate, a test or a scan to get green, and never add a masking baseline.

## Git

- The work is on the branch named in `STATUS.md`. Do not create a branch or a worktree. No merge into `main`, no push of `main` and no deploy without the owner's explicit word.
- Commit or push only when the owner asks, and only after the gates of the touched area pass.
- Never reset, clean, stash or check out over uncommitted work.
- At the start of a session run `git status` and `git branch -a --no-merged main`. If anything other than the branch in `STATUS.md` shows up, tell the owner before working.
- Never commit or print secrets (`.env`, keys, tokens, passwords).

## Architecture

- Read `ARCHITECTURE_CONSTITUTION.md` and `ARCHITECTURE.md` before architecture work.
- Backend code that crosses a context uses only the owning context's public contract: no foreign Prisma access, no deep import, no `forwardRef()`, no project-owned `@Global()`. Prisma access for a context lives in its own `infrastructure/`.
- Mobile: no new boundary-baseline entry and no cross-area `part`.
- Published migrations are never edited.
- The 2026-08 and 2026-09 files under `docs/superpowers/` are fixtures pinned by the architecture gates. Do not read them for direction and do not delete them.

## Product limits

- The app tracks money only: no payment processing, deposits, wallet or financing.
- Financial data is private. A shared member sees it only when their permission allows it.
- Arabic and RTL everywhere, in the reader's gender. Copy follows `docs/project/LANGUAGE.md`. The word «أقساط» is banned in the UI.
