import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import {
  FundingSourceKind,
  FundingSourceStatus,
  LoanRepaymentStatus,
  Prisma,
} from "@prisma/client";
import { FundingSourcesService } from "../src/money/funding-sources.service";
import { buildMoneySummaryInTransaction } from "../src/money/money-summary.service";

// Funding sources (savings, family support, gifts, loans) and loan
// repayments: the owner's private money picture, tracking only.

const owner = { id: "owner-1" } as any;
const contributor = { id: "member-1" } as any;

function context(isOwner: boolean) {
  return {
    plan: { id: "plan-1", ownerUserId: "owner-1", status: "PLANNING", currency: "YER" },
    isOwner,
    sharedMember: isOwner ? null : { canViewMoney: true, canManageMoney: true },
  } as any;
}

/** An in-memory stand-in for the Prisma rows the repository reads and writes. */
function fakeDatabase() {
  let sequence = 0;
  const sources = new Map<string, any>();
  const repayments = new Map<string, any>();
  const withRepayments = (source: any) => ({
    ...source,
    repayments: [...repayments.values()]
      .filter((item) => item.fundingSourceId === source.id)
      .sort((a, b) => (a.dueDate?.getTime() ?? 0) - (b.dueDate?.getTime() ?? 0)),
  });
  const tx: any = {
    $queryRaw: async (query: { values: unknown[] }) => {
      const id = query.values[0] as string;
      return sources.has(id) ? [{ id }] : [];
    },
    fundingSource: {
      create: async ({ data }: any) => {
        const row = {
          id: `source-${++sequence}`,
          createdAt: new Date(),
          updatedAt: new Date(),
          sourcePhone: null,
          receivedAt: null,
          note: null,
          ...data,
        };
        sources.set(row.id, row);
        return withRepayments(row);
      },
      findMany: async ({ where }: any) =>
        [...sources.values()]
          .filter((row) => row.weddingPlanId === where.weddingPlanId)
          .filter((row) => !where.kind || row.kind !== where.kind.not)
          .map(withRepayments),
      findUnique: async ({ where }: any) =>
        sources.has(where.id) ? withRepayments(sources.get(where.id)) : null,
      findUniqueOrThrow: async ({ where }: any) => withRepayments(sources.get(where.id)),
      update: async ({ where, data }: any) => {
        const row = { ...sources.get(where.id), ...data, updatedAt: new Date() };
        sources.set(where.id, row);
        return withRepayments(row);
      },
      delete: async ({ where }: any) => {
        sources.delete(where.id);
        for (const [id, item] of repayments) {
          if (item.fundingSourceId === where.id) repayments.delete(id);
        }
      },
    },
    loanRepayment: {
      create: async ({ data }: any) => {
        const row = {
          id: `repayment-${++sequence}`,
          status: LoanRepaymentStatus.PLANNED,
          paidAt: null,
          createdAt: new Date(),
          updatedAt: new Date(),
          ...data,
        };
        repayments.set(row.id, row);
        return row;
      },
      findUnique: async ({ where }: any) => {
        const row = repayments.get(where.id);
        return row
          ? { ...row, fundingSource: { weddingPlanId: sources.get(row.fundingSourceId).weddingPlanId } }
          : null;
      },
      update: async ({ where, data }: any) => {
        const row = { ...repayments.get(where.id), ...data };
        repayments.set(where.id, row);
        return row;
      },
      delete: async ({ where }: any) => {
        repayments.delete(where.id);
      },
    },
  };
  const prisma: any = { $transaction: async (work: any) => work(tx) };
  return { tx, prisma };
}

function service(isOwner = true) {
  const { tx, prisma } = fakeDatabase();
  const permissions: any = {
    assertMoneyReadableInTransaction: async () => context(isOwner),
    assertMoneyManageableInTransaction: async () => context(isOwner),
  };
  return { tx, funding: new FundingSourcesService(prisma, permissions) };
}

test("the owner records savings, family support and a pledge", async () => {
  const { funding } = service();

  const savings = await funding.create(owner, "plan-1", {
    kind: FundingSourceKind.SAVINGS,
    sourceName: "مدخراتي",
    amount: "500000",
  });
  const pledge = await funding.create(owner, "plan-1", {
    kind: FundingSourceKind.FAMILY_SUPPORT,
    sourceName: "الوالد",
    amount: "300000",
    status: FundingSourceStatus.PLEDGED,
  });

  assert.equal(savings.status, FundingSourceStatus.RECEIVED);
  assert.ok(savings.receivedAt instanceof Date);
  assert.equal(pledge.receivedAt, null);
  assert.equal(savings.repaidAmount, null);
  assert.deepEqual(
    (await funding.findForPlan(owner, "plan-1")).map((item) => item.sourceName),
    ["مدخراتي", "الوالد"],
  );
});

test("a contributor with money rights can neither see nor change funding", async () => {
  const { funding } = service(false);

  assert.deepEqual(await funding.findForPlan(contributor, "plan-1"), []);
  await assert.rejects(
    funding.create(contributor, "plan-1", {
      kind: FundingSourceKind.GIFT,
      sourceName: "رفد",
      amount: "1000",
    }),
    (error: any) => error?.getStatus?.() === 404,
  );
});

test("a loan is paid back through planned repayments that never exceed it", async () => {
  const { funding } = service();
  const loan = await funding.create(owner, "plan-1", {
    kind: FundingSourceKind.LOAN,
    sourceName: "ابن العم",
    amount: "200000",
  });

  const scheduled = await funding.addRepayment(owner, loan.id, {
    amount: "150000",
    dueDate: "2027-01-01",
  });
  await assert.rejects(
    funding.addRepayment(owner, loan.id, { amount: "60000" }),
    (error: any) =>
      error?.getStatus?.() === 400 &&
      error.getResponse().detail === "Repayments cannot exceed the loan amount" &&
      error.getResponse().code === "FINANCE_REPAYMENTS_EXCEED_LOAN",
  );

  const paid = await funding.updateRepayment(owner, scheduled.repayments[0].id, {
    status: LoanRepaymentStatus.PAID,
  });
  assert.equal(paid.repaidAmount, "150000");
  assert.equal(paid.outstandingAmount, "50000");
  assert.ok(paid.repayments[0].paidAt instanceof Date);

  await assert.rejects(
    funding.updateRepayment(owner, paid.repayments[0].id, { amount: "1" }),
    (error: any) => error?.getStatus?.() === 409,
  );
  await assert.rejects(
    funding.update(owner, loan.id, { kind: FundingSourceKind.GIFT }),
    (error: any) => error?.getStatus?.() === 409,
  );
  await assert.rejects(
    funding.update(owner, loan.id, { amount: "100000" }),
    (error: any) => error?.getStatus?.() === 400,
  );
});

test("only a loan takes repayments", async () => {
  const { funding } = service();
  const gift = await funding.create(owner, "plan-1", {
    kind: FundingSourceKind.GIFT,
    sourceName: "نقوط",
    amount: "50000",
  });

  await assert.rejects(
    funding.addRepayment(owner, gift.id, { amount: "1000" }),
    (error: any) =>
      error?.getStatus?.() === 400 &&
      error.getResponse().detail === "Repayments can only be added to a loan" &&
      error.getResponse().code === "FINANCE_REPAYMENT_LOAN_ONLY",
  );
});

test("the owner's money summary weighs funding against confirmed costs", async () => {
  const { tx, funding } = service();
  const loan = await funding.create(owner, "plan-1", {
    kind: FundingSourceKind.LOAN,
    sourceName: "ابن العم",
    amount: "200000",
  });
  await funding.create(owner, "plan-1", {
    kind: FundingSourceKind.FAMILY_SUPPORT,
    sourceName: "الوالد",
    amount: "100000",
    status: FundingSourceStatus.PLEDGED,
  });
  await funding.addRepayment(owner, loan.id, { amount: "50000", dueDate: "2020-01-01" });
  Object.assign(tx, {
    budgetCategory: { findMany: async () => [] },
    weddingCost: {
      // V1 checklist 4.10: the private-cost pre-filter finds none.
      findMany: async ({ where }: any) =>
        where?.privateToUserId
          ? []
          : [
              { id: "cost-1", budgetCategoryId: "cat-1", totalAmount: new Prisma.Decimal("400000"), title: "القاعة" },
            ],
    },
    costPayment: {
      findMany: async () => [
        { weddingCostId: "cost-1", amount: new Prisma.Decimal("150000"), entryType: "PAYMENT" },
      ],
    },
    paymentSchedule: { findMany: async () => [] },
  });
  const plans: any = {
    getPlan: async () => ({ id: "plan-1", estimatedBudget: null, currency: "YER" }),
  };
  const permissions: any = { canViewMoney: () => true, canManageMoney: () => true };

  const catalog: any = { listActiveCategories: async () => [] };
  const summary = await buildMoneySummaryInTransaction(
    tx,
    permissions,
    plans,
    catalog,
    context(true),
  );
  const contributorSummary = await buildMoneySummaryInTransaction(
    tx,
    permissions,
    plans,
    catalog,
    context(false),
    { costIds: ["cost-1"], categoryIds: [] },
  );

  assert.equal(summary.funding?.total, "300000");
  assert.equal(summary.funding?.received, "200000");
  assert.equal(summary.funding?.pledged, "100000");
  assert.equal(summary.funding?.availableCash, "50000");
  assert.equal(summary.funding?.shortfall, "100000");
  assert.equal(summary.funding?.loanOutstanding, "200000");
  assert.equal(summary.funding?.overdueLoanRepayments, 1);
  assert.deepEqual(
    summary.warnings.map((warning) => warning.type).sort(),
    ["FUNDING_SHORTFALL", "LOAN_REPAYMENT_OVERDUE"],
  );
  assert.equal(contributorSummary.funding, null);
});
