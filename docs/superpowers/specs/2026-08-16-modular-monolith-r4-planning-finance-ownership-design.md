# Modular Monolith R4 Planning/Finance Ownership Design

**Status:** Implementation in progress. Tasks 1-3 are implemented and Task 4
is verified through the pre-Git gate; Git authorization, immutable runtime,
owner phone verification, final receipts, and R4 closeout remain. R5 has not
started.

**Date:** 2026-08-16

**Immutable planning base:**
`502b181a2ce624458fd7eae064f194497ec0151e`

**Execution branch:** `modular-monolith`

## Objective

R4 removes the one explicitly scheduled physical-ownership debt in Finance:
`MoneyBudgetService` currently writes `WeddingPlan.estimatedBudget` and
`WeddingPlan.currency` through `tx.weddingPlan.update(...)`, although
`WeddingPlan` is physically owned by Planning.

R4 replaces that direct delegate access with one demand-driven Planning public
write port. Finance keeps the existing serializable transaction, permission
lock order, validation, category mutations, summary calculation, response,
errors, and retry behavior. It passes the same caller-owned Prisma transaction
client to Planning, and Planning performs the `WeddingPlan` write inside that
transaction.

R4 is complete only when:

- Finance has no direct `WeddingPlan` write;
- Planning owns the only implementation of the new write operation;
- the public token resolves to the exact singleton implementation through the
  R3 internal/public module pattern;
- the caller's exact transaction client reaches the Planning writer;
- the one frozen ownership record is removed and no other ownership or
  dependency record is added, renamed, or silently removed;
- HTTP routes, DTOs, payloads, status codes, product/error/Arabic text,
  permissions, locks, transaction/retry behavior, schema, migrations, Mobile,
  Admin Web, and deployment topology remain unchanged;
- focused, full, managed-runtime, independent-review, and owner phone gates
  pass on an immutable local candidate.

## Verified Starting State

The design is based on the live tree at the immutable planning base:

- branch `modular-monolith` is clean at
  `502b181a2ce624458fd7eae064f194497ec0151e`;
- `MoneyBudgetService.replace(...)` opens one serializable transaction, obtains
  the update permission/plan lock, mutates `BudgetCategory`, directly updates
  `WeddingPlan`, then builds the summary in the same transaction;
- the exact baseline record is:

  ```text
  backend/src/money/money-budget.service.ts|finance|planning|WeddingPlan|update|write|delegate|foreign-model
  ```

  with count `1`;
- the tracked ownership baseline has 386 records and 782 occurrences;
- Planning currently has `PlanningModule` and
  `PlanningServicesInternalModule`, but no public provider contract;
- Finance currently owns `MoneyBudgetService` through
  `FinanceServicesInternalModule`;
- R3 is locally complete with 13 contexts, zero duplicate registrations, zero
  platform debts, zero retired provider edges, zero `forwardRef()`, two frozen
  globals, zero cycles, and zero illegal boundary edges.

## Approaches Considered

### A. Dedicated Planning budget-write leaf and public port — selected

Create one small Planning internal provider with no database service and no
transaction boundary of its own. It accepts the caller's transaction client and
updates only `WeddingPlan.estimatedBudget` and `WeddingPlan.currency`. A public
module exposes the exact provider instance through a Symbol token.

This is the smallest boundary that closes the real debt, preserves atomicity,
keeps the interface demand-driven, and avoids exposing unrelated Planning
behavior.

### B. Add the method to `WeddingPlansService` and expose that service

This avoids one provider class, but it exposes a large legacy service leaf with
collaboration dependencies and many unrelated responsibilities. It increases
the public slice's dependency surface and makes future cycles or accidental
method expansion more likely. R4 rejects this approach.

### C. Let Planning open a second transaction

This would make the public API superficially simple, but the plan update could
commit separately from category replacement and summary calculation. It would
break the explicitly required caller transaction boundary and change failure
semantics. R4 rejects this approach.

## Architecture

R4 adds one owner-private leaf and one owner public contract:

```text
FinanceServicesInternalModule
  -> PlanningBudgetWritePublicModule
       -> PlanningBudgetWriteInternalModule
            -> WeddingPlanBudgetWriter
```

`PlanningModule` imports the same static public module token so the public slice
is part of the Planning context composition. Nest must reuse the same static
module/provider identity when Finance imports it. No Finance source imports a
Planning internal module or implementation class.

The public contract is exact:

```typescript
import type { Prisma } from '@prisma/client';

export const PLANNING_BUDGET_WRITE_PORT = Symbol(
  'PLANNING_BUDGET_WRITE_PORT',
);

export interface UpdateWeddingPlanBudgetInput {
  weddingPlanId: string;
  estimatedBudget: Prisma.Decimal | null;
  currency: string;
}

export interface PlanningBudgetWritePort {
  updateBudgetInTransaction(
    tx: Prisma.TransactionClient,
    input: UpdateWeddingPlanBudgetInput,
  ): Promise<void>;
}
```

The internal implementation is exact:

```typescript
@Injectable()
export class WeddingPlanBudgetWriter implements PlanningBudgetWritePort {
  async updateBudgetInTransaction(
    tx: Prisma.TransactionClient,
    input: UpdateWeddingPlanBudgetInput,
  ): Promise<void> {
    await tx.weddingPlan.update({
      where: { id: input.weddingPlanId },
      data: {
        estimatedBudget: input.estimatedBudget,
        currency: input.currency,
      },
    });
  }
}
```

The implementation has no constructor dependencies and imports no Finance
source. It does not inject `PrismaService`, call `$transaction`, validate the
DTO again, catch/remap errors, or read another model.

The binding follows the R3 singleton law:

```typescript
export const PLANNING_BUDGET_WRITE_IMPLEMENTATION = Symbol(
  'PLANNING_BUDGET_WRITE_IMPLEMENTATION',
);

@Module({
  providers: [
    WeddingPlanBudgetWriter,
    {
      provide: PLANNING_BUDGET_WRITE_IMPLEMENTATION,
      useExisting: WeddingPlanBudgetWriter,
    },
  ],
  exports: [
    WeddingPlanBudgetWriter,
    PLANNING_BUDGET_WRITE_IMPLEMENTATION,
  ],
})
export class PlanningBudgetWriteInternalModule {}

@Module({
  imports: [PlanningBudgetWriteInternalModule],
  providers: [
    {
      provide: PLANNING_BUDGET_WRITE_PORT,
      useExisting: PLANNING_BUDGET_WRITE_IMPLEMENTATION,
    },
  ],
  exports: [PLANNING_BUDGET_WRITE_PORT],
})
export class PlanningBudgetWritePublicModule {}
```

The concrete provider export is owner-private. The public module exports only
`PLANNING_BUDGET_WRITE_PORT`. The architecture scanner must prove that the
public token, internal implementation token, and concrete class resolve through
one exact `useExisting` chain and one exact provider registration.

## Data Flow and Transaction Law

The successful `MoneyBudgetService.replace(...)` flow remains:

1. Parse and validate general budget, currency, and categories before opening a
   transaction.
2. Enter the existing `runSerializableTransaction(...)` boundary.
3. Lock and recheck the user's money-management authority through the existing
   collaboration permission port.
4. Preserve the owner-only replacement rule and existing currency-change guard.
5. Delete, re-key, update, and create categories exactly as today.
6. Call `PLANNING_BUDGET_WRITE_PORT.updateBudgetInTransaction(tx, input)` with
   the exact same `tx` object.
7. Build the money summary through the same `tx` after the Planning write.
8. Return the existing response unchanged.

R4 does not move validation or Finance's category/cost logic into Planning. It
does not make Planning responsible for Finance rules. Planning owns only the
physical `WeddingPlan` mutation.

## Error and Concurrency Behavior

- Input validation remains before the transaction.
- Permission and plan lifecycle locks remain before category and plan writes.
- The existing serializable retry wrapper remains the only transaction/retry
  boundary.
- The Planning writer does not swallow, translate, retry, or log errors.
- Existing `BadRequestException`, `ConflictException`, `NotFoundException`, and
  Prisma error mapping in `MoneyBudgetService` remain byte/behavior-equivalent.
- If the Planning write fails, the surrounding transaction rolls back category
  mutations exactly as the direct delegate write does today.
- The summary read must occur after the Planning port call and inside the same
  transaction so it observes the new budget and currency.

## Architecture and Ownership Gates

R4 extends the canonical context manifest with one demand-driven contract:

| Field | Exact value |
| --- | --- |
| Token | `PLANNING_BUDGET_WRITE_PORT` |
| Method | `updateBudgetInTransaction` |
| Implementation | `WeddingPlanBudgetWriter` |
| Consumer | `backend/src/money/money-budget.service.ts` |
| Consumer kind | `constructor-injection` |

The R4 gate must reject:

- a same-name local/fake token or interface in Finance;
- direct import of Planning internal/full/implementation source from Finance;
- a second provider registration or a non-`useExisting` alias;
- a new transaction or `PrismaService` dependency inside the writer;
- any remaining `tx.weddingPlan` access in `MoneyBudgetService`;
- removal of any ownership record other than the exact frozen debt;
- any new or increased ownership/dependency record;
- paths outside the explicit R4 allowlist.

The ownership candidate must equal the tracked pre-R4 baseline minus exactly
the one debt record. Therefore the strict candidate is expected to have 385
records and 781 occurrences, subject to independent regeneration from the live
scanner. These counts are evidence, not a substitute for exact-key comparison.

## Test Strategy

### RED before production

The first strict R4 test must fail because:

- the public/internal files and Symbol binding do not exist;
- Finance still directly calls `tx.weddingPlan.update(...)`;
- the manifest lacks the Planning contract;
- the ownership baseline still contains the frozen debt.

No production file changes before that RED receipt.

### Focused GREEN

- exact Nest module metadata and singleton identity;
- canonical TypeChecker-resolved token/interface/implementation/consumer;
- same transaction object and exact update input;
- write-before-summary ordering;
- existing invalid input, owner-only, archived/lifecycle, category conflict,
  currency, Prisma error, and serializable retry behavior;
- exact one-key ownership decrease;
- no foreign internal/full import and no fake same-name token.

Existing behavioral assertions and expected values stay frozen. Direct
constructor fixtures may only add the exact deterministic Planning port stub
required by the new constructor parameter.

### Full and runtime gates

- Backend architecture, check, build, full test suite, Prisma validation, npm
  audits, and generated-artifact cleanliness;
- managed money-budget, money-APIs, money-authorization-concurrency, health,
  and final `smoke:all` runs with zero residue;
- unchanged schema/migrations/seed/API/Mobile/Admin/deployment surfaces;
- docs sync/verify and whitespace gates;
- immutable Docker candidate with preserved R3 and R2 rollback artifacts;
- owner phone test: login/OTP, Home, open Money, replace the general budget and
  at least one category, confirm the saved value, force-stop/reopen, and confirm
  the authenticated context and saved value remain.

## Exact Scope

R4 may change only:

- the new Planning public/internal budget-write files;
- `PlanningModule`, `FinanceServicesInternalModule`, and
  `MoneyBudgetService` wiring;
- the exact Finance behavioral fixture wiring required by the constructor;
- the existing money authorization smoke constructor wiring required by the
  same exact owner writer;
- the R3 context manifest and exact module/contract architecture tests;
- the R3 context scanner/test only to extend its canonical TypeChecker identity
  inventory with this one R4 contract;
- the R3 scope verifier/test only for a fail-closed handoff that keeps the R3
  receipt immutable and delegates the byte-exact R4 manifest paths;
- a new R4 architecture/scope test and package script wiring;
- the ownership baseline after exact candidate comparison;
- generated script documentation caused only by the new package script;
- the R4 design, plan, ignored reports, and final approved Markdown receipts.

Any additional application, schema, migration, seed, lockfile, Mobile, Admin,
Docker/Compose/deploy, workflow, or CI path is a stop signal requiring a new
owner decision.

## Non-Goals

R4 does not:

- address any other ownership record in Planning, Finance, or another context;
- move model files, Prisma schema blocks, controllers, DTOs, services, routes,
  or product behavior;
- create a read port, generic repository, unit-of-work abstraction, event, or
  compatibility facade;
- change shared-member privacy or money permissions;
- begin R5 or any later phase;
- push, merge, open/update a PR, or claim remote CI.

## Review and Completion

Each implementation checkpoint must receive a fresh independent read-only
review. Findings are fixed with a new RED before the smallest root correction.
The candidate is not complete until the final independent source/runtime/receipt
review and owner phone checkpoint pass.

Git state is not authorized by the current request. The implementation plan may
name recommended local checkpoint commits for continuity, but no stage, commit,
push, merge, branch, checkout, reset, or worktree action occurs without separate
explicit owner authorization.
