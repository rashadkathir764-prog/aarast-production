import { listOthersPrivateCostIds } from "../modules/finance/infrastructure/cost-privacy.repository";
import { Inject, Injectable, NotFoundException } from "@nestjs/common";
import {
  BudgetCategoryKind,
  ContributionAction,
  ContributionEntityType,
  CostPayer,
  CostPaymentType,
  FundingSourceKind,
  FundingSourceStatus,
  LoanRepaymentStatus,
  PaymentScheduleStatus,
  Prisma,
  WeddingCostStatus,
} from "@prisma/client";
import { AuthenticatedUser } from "../modules/identity/public/identity-session.types";
import {
  COLLABORATION_SCOPE_PORT,
  type CollaborationScopePort as ContributorScopeService,
} from "../modules/collaboration/public/collaboration-scope.port";
import { runRetryableTransaction } from "../platform/database/serializable-transaction";
import { PrismaService } from "../platform/database/prisma.service";
import { loadMoneySummaryRows } from "../modules/finance/infrastructure/money-summary.repository";
import {
  type MahrPicture,
  type MahrSide,
  mahrPicture,
  mahrSideOf,
} from "../modules/finance/domain/mahr-policy";
import {
  listFundingSources,
  type FundingSourceWithRepayments,
} from "../modules/finance/infrastructure/funding-sources.repository";
import {
  PLAN_READ_PORT,
  type PlanReadPort,
} from "../modules/planning/public/plan-read.port";
import {
  CATALOG_READ_PORT,
  type CatalogReadPort,
} from "../modules/catalog/public/catalog-read.port";
import { listPlanItemsForProviderSearch } from "../modules/finance/infrastructure/budget-item-search.repository";
import { budgetItemSearchCategories } from "../modules/finance/public/provider-category-budget-item";
import {
  COLLABORATION_PERMISSION_PORT,
  type CollaborationPermissionPort as PermissionService,
  PlanAccessContext,
  seesWholePlan,
} from "../modules/collaboration/public/collaboration-permission.port";

type WarningType =
  | "BUDGET_EXCEEDED"
  | "CATEGORY_EXCEEDED"
  | "PAYMENT_SCHEDULE_OVERDUE"
  | "PAYMENT_SCHEDULE_DUE_SOON"
  | "FUNDING_SHORTFALL"
  | "LOAN_REPAYMENT_OVERDUE";

@Injectable()
export class MoneySummaryService {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(COLLABORATION_PERMISSION_PORT)
    private readonly permissions: PermissionService,
    @Inject(PLAN_READ_PORT)
    private readonly plans: PlanReadPort,
    @Inject(CATALOG_READ_PORT)
    private readonly catalog: CatalogReadPort,
    @Inject(COLLABORATION_SCOPE_PORT)
    private readonly contributorScope?: ContributorScopeService,
  ) {}

  async getSummary(currentUser: AuthenticatedUser, weddingPlanId: string) {
    return runRetryableTransaction(
      this.prisma,
      async (tx) => {
        const access =
          await this.permissions.assertMoneyReadableInTransaction(
            tx,
            weddingPlanId,
            currentUser,
          );
        const contributionScope = seesWholePlan(access)
          ? null
          : {
              costIds: await this.requiredContributorScope().qualifyingEntityIdsInTransaction(
                tx,
                weddingPlanId,
                currentUser.id,
                [ContributionEntityType.WEDDING_COST],
                [
                  ContributionAction.CREATED,
                  ContributionAction.COMPLETED,
                  ContributionAction.PAYMENT_RECORDED,
                ],
              ),
              categoryIds: await this.requiredContributorScope().qualifyingEntityIdsInTransaction(
                tx,
                weddingPlanId,
                currentUser.id,
                [ContributionEntityType.BUDGET_CATEGORY],
                [ContributionAction.CREATED],
              ),
            };
        return buildMoneySummaryInTransaction(
          tx,
          this.permissions,
          this.plans,
          this.catalog,
          access,
          contributionScope,
        );
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );
  }

  private requiredContributorScope(): ContributorScopeService {
    if (!this.contributorScope) {
      throw new Error("ContributorScopeService is required for contributor money summaries");
    }
    return this.contributorScope;
  }
}

export async function buildMoneySummaryInTransaction(
  tx: Prisma.TransactionClient,
  permissions: PermissionService,
  plans: PlanReadPort,
  catalog: CatalogReadPort,
  access: PlanAccessContext,
  contributionScope: {
    costIds: readonly string[];
    categoryIds: readonly string[];
  } | null = null,
) {
  const weddingPlanId = access.plan.id;
  // Funding (savings, family support, gifts, loans) is the owner's private
  // money picture; a contributor's summary never includes it.
  const fundingVisible = access.isOwner && contributionScope === null;
  const [
    plan,
    [categories, scopedCosts, scopedPayments, scopedSchedules],
    fundingSources,
    hidden,
    planItems,
    providerCategories,
  ] = await Promise.all([
    plans.getPlan(tx, weddingPlanId),
    loadMoneySummaryRows(tx, weddingPlanId, contributionScope),
    fundingVisible ? listFundingSources(tx, weddingPlanId, true) : null,
    // V1 checklist 4.10: another account's private costs count nowhere.
    listOthersPrivateCostIds(
      tx,
      weddingPlanId,
      access.sharedMember?.userId ?? access.plan.ownerUserId,
    ),
    listPlanItemsForProviderSearch(tx, weddingPlanId),
    catalog.listActiveCategories(tx),
  ]);
  const costs = scopedCosts.filter((cost) => !hidden.has(cost.id));
  const payments = scopedPayments.filter(
    (payment) => !hidden.has(payment.weddingCostId),
  );
  const schedules = scopedSchedules.filter(
    (schedule) => !hidden.has(schedule.weddingCostId),
  );

  if (!plan) {
    throw new NotFoundException("Wedding plan not found");
  }
  // G40: the directory categories «ابحث» on each item searches, by the rule
  // acceptance files an offer with, over the whole plan's items.
  const searchCategories = budgetItemSearchCategories(
    planItems,
    providerCategories,
    plan.persona,
  );

  const zero = () => new Prisma.Decimal(0);
  const totalCost = costs.reduce(
    (sum, cost) => sum.plus(cost.totalAmount),
    zero(),
  );
  // C1: the groom's mahr item is outside the wedding budget. Its costs count
  // in what he agreed, paid and owes, never against the budget.
  const mahrCategoryIds = new Set(
    categories
      .filter((category) => category.kind === BudgetCategoryKind.MAHR)
      .map((category) => category.id),
  );
  const weddingCosts = costs.filter(
    (cost) => !mahrCategoryIds.has(cost.budgetCategoryId),
  );
  const weddingCost = weddingCosts.reduce(
    (sum, cost) => sum.plus(cost.totalAmount),
    zero(),
  );
  const netPaidByCost = new Map<string, Prisma.Decimal>();
  for (const payment of payments) {
    const signed =
      payment.entryType === CostPaymentType.REVERSAL
        ? payment.amount.negated()
        : payment.amount;
    netPaidByCost.set(
      payment.weddingCostId,
      (netPaidByCost.get(payment.weddingCostId) ?? zero()).plus(signed),
    );
  }
  const paid = costs.reduce(
    (sum, cost) => sum.plus(netPaidByCost.get(cost.id) ?? zero()),
    zero(),
  );
  const weddingPaid = weddingCosts.reduce(
    (sum, cost) => sum.plus(netPaidByCost.get(cost.id) ?? zero()),
    zero(),
  );
  const allocated = categories.reduce(
    (sum, category) => sum.plus(category.allocatedAmount ?? zero()),
    zero(),
  );
  // The plan-wide budget belongs to the owner. A contributor receives only
  // totals derived from their own scoped costs/categories, never a value (or
  // a remaining/unallocated derivative) based on the owner's budget.
  const totalBudget = contributionScope ? null : plan.estimatedBudget;
  const now = new Date();
  const today = startOfTodayInRiyadh(now);
  const dueSoonEnd = new Date(today.getTime() + 7 * 24 * 60 * 60 * 1000);
  const pendingSchedules = schedules.filter(
    (schedule) => schedule.status === PaymentScheduleStatus.PENDING,
  );
  const overdueSchedules = pendingSchedules.filter(
    (schedule) => schedule.dueDate < today,
  );
  const upcomingSchedules = pendingSchedules.filter(
    (schedule) => schedule.dueDate >= today,
  );
  const dueSoonSchedules = upcomingSchedules.filter(
    (schedule) => schedule.dueDate <= dueSoonEnd,
  );

  const categoryRows = categories.map((category) => {
    const categoryCosts = costs.filter(
      (cost) => cost.budgetCategoryId === category.id,
    );
    const confirmedCost = categoryCosts.reduce(
      (sum, cost) => sum.plus(cost.totalAmount),
      zero(),
    );
    const categoryPaid = categoryCosts.reduce(
      (sum, cost) => sum.plus(netPaidByCost.get(cost.id) ?? zero()),
      zero(),
    );
    const categorySchedules = schedules.filter(
      (schedule) => schedule.weddingCost.budgetCategoryId === category.id,
    );
    return {
      categoryId: category.id,
      name: category.name,
      kind: category.kind,
      allocatedAmount: category.allocatedAmount?.toString() ?? null,
      confirmedCost: confirmedCost.toString(),
      paid: categoryPaid.toString(),
      outstanding: confirmedCost.minus(categoryPaid).toString(),
      remainingAllocation:
        category.allocatedAmount?.minus(confirmedCost).toString() ?? null,
      costsCount: categoryCosts.length,
      paymentSchedulesCount: categorySchedules.length,
      overBudget:
        category.allocatedAmount === null
          ? null
          : confirmedCost.gt(category.allocatedAmount),
      /** G40: empty when no provider's offer lands here (no «ابحث»). */
      providerCategoryIds: searchCategories.get(category.id) ?? [],
    };
  });

  const warnings: Array<{
    type: WarningType;
    severity: "WARNING" | "DANGER";
    categoryId?: string;
    count: number | null;
    amount: string | null;
  }> = [];
  if (totalBudget !== null && weddingCost.gt(totalBudget)) {
    warnings.push({
      type: "BUDGET_EXCEEDED",
      severity: "DANGER",
      count: null,
      amount: weddingCost.minus(totalBudget).toString(),
    });
  }
  for (const category of categoryRows) {
    if (category.overBudget && category.allocatedAmount !== null) {
      warnings.push({
        type: "CATEGORY_EXCEEDED",
        severity: "DANGER",
        categoryId: category.categoryId,
        count: category.costsCount,
        amount: new Prisma.Decimal(category.confirmedCost)
          .minus(category.allocatedAmount)
          .toString(),
      });
    }
  }
  if (overdueSchedules.length > 0) {
    warnings.push({
      type: "PAYMENT_SCHEDULE_OVERDUE",
      severity: "DANGER",
      count: overdueSchedules.length,
      amount: null,
    });
  }
  if (dueSoonSchedules.length > 0) {
    warnings.push({
      type: "PAYMENT_SCHEDULE_DUE_SOON",
      severity: "WARNING",
      count: dueSoonSchedules.length,
      amount: null,
    });
  }
  const funding = fundingSources
    ? summarizeFunding(fundingSources, totalCost, paid, today)
    : null;
  if (funding && funding.shortfall !== null) {
    warnings.push({
      type: "FUNDING_SHORTFALL",
      severity: "WARNING",
      count: null,
      amount: funding.shortfall,
    });
  }
  if (funding && funding.overdueLoanRepayments > 0) {
    warnings.push({
      type: "LOAN_REPAYMENT_OVERDUE",
      severity: "DANGER",
      count: funding.overdueLoanRepayments,
      amount: null,
    });
  }

  const next = pendingSchedules[0] ?? null;
  const mahr = summarizeMahr({
    side: mahrSideOf(plan.persona),
    costs: costs.filter((cost) => mahrCategoryIds.has(cost.budgetCategoryId)),
    netPaidByCost,
    pendingSchedules: pendingSchedules.filter((schedule) =>
      mahrCategoryIds.has(schedule.weddingCost.budgetCategoryId),
    ),
    fundingSources,
  });
  return {
    weddingPlanId,
    currency: plan.currency,
    // The wedding budget (C1): the mahr item is not in it.
    budget: {
      total: totalBudget?.toString() ?? null,
      allocated: allocated.toString(),
      unallocated: totalBudget?.minus(allocated).toString() ?? null,
      confirmedCost: weddingCost.toString(),
      paid: weddingPaid.toString(),
      remaining: totalBudget?.minus(weddingCost).toString() ?? null,
    },
    costs: {
      total: totalCost.toString(),
      paid: paid.toString(),
      outstanding: totalCost.minus(paid).toString(),
      count: costs.length,
    },
    paymentSchedules: {
      totalCount: schedules.length,
      upcomingCount: upcomingSchedules.length,
      overdueCount: overdueSchedules.length,
      paidCount: schedules.filter(
        (schedule) => schedule.status === PaymentScheduleStatus.PAID,
      ).length,
      next: next
        ? {
            id: next.id,
            weddingCostId: next.weddingCostId,
            amount: next.amount.toString(),
            dueDate: next.dueDate,
            status: next.status,
            isOverdue: next.dueDate < today,
          }
        : null,
    },
    categories: categoryRows,
    /**
     * The plan's mahr (a06): the groom's agreement with the bride's family
     * (PAYS, from his MAHR item) or the bride's mahr coming in (RECEIVES,
     * from her MAHR funding sources, so the owner's only). Null before it is
     * recorded, on a plan without a persona, or for a reader who may not see it.
     */
    mahr,
    /** G14: who pays what, by each item's payer (the payer is set per item). */
    payers: summarizePayers(costs, netPaidByCost),
    /** Owner only; null for a contributor. */
    funding,
    warnings,
    permissions: {
      canViewMoney: permissions.canViewMoney(access),
      canManageMoney: permissions.canManageMoney(access),
      // V1 checklist 4.10: the owner or partner may record a private cost.
      canRecordPrivateCost:
        permissions.canManageMoney(access) && seesWholePlan(access),
    },
  };
}

export type MoneySummaryResult = Awaited<
  ReturnType<typeof buildMoneySummaryInTransaction>
>;

function summarizeMahr(input: {
  side: MahrSide | null;
  costs: ReadonlyArray<{ id: string; totalAmount: Prisma.Decimal }>;
  netPaidByCost: ReadonlyMap<string, Prisma.Decimal>;
  pendingSchedules: ReadonlyArray<{ dueDate: Date }>;
  fundingSources: readonly FundingSourceWithRepayments[] | null;
}): MahrPicture | null {
  const zero = new Prisma.Decimal(0);
  if (input.side === "PAYS") {
    if (input.costs.length === 0) return null;
    const total = input.costs.reduce(
      (sum, cost) => sum.plus(cost.totalAmount),
      zero,
    );
    const settled = input.costs.reduce(
      (sum, cost) => sum.plus(input.netPaidByCost.get(cost.id) ?? zero),
      zero,
    );
    return mahrPicture(
      "PAYS",
      total,
      settled,
      input.pendingSchedules[0]?.dueDate ?? null,
    );
  }
  if (input.side === "RECEIVES" && input.fundingSources) {
    const sources = input.fundingSources.filter(
      (source) => source.kind === FundingSourceKind.MAHR,
    );
    if (sources.length === 0) return null;
    const total = sources.reduce((sum, source) => sum.plus(source.amount), zero);
    const received = sources
      .filter((source) => source.status === FundingSourceStatus.RECEIVED)
      .reduce((sum, source) => sum.plus(source.amount), zero);
    const expected = sources
      .filter(
        (source) =>
          source.status === FundingSourceStatus.PLEDGED &&
          source.expectedAt !== null,
      )
      .map((source) => source.expectedAt as Date)
      .sort((a, b) => a.getTime() - b.getTime());
    return mahrPicture("RECEIVES", total, received, expected[0] ?? null);
  }
  return null;
}

const PAYER_ORDER: ReadonlyArray<CostPayer | null> = [
  CostPayer.GROOM,
  CostPayer.BRIDE,
  CostPayer.FAMILY,
  CostPayer.SHARED,
  CostPayer.OTHER,
  null,
];

/**
 * G14: what each payer agreed to and paid, grouped by the item's payer and
 * the name written with it («الوالد», «خالي أحمد»); items without a payer
 * are one group with `payer: null`.
 */
function summarizePayers(
  costs: ReadonlyArray<{
    id: string;
    totalAmount: Prisma.Decimal;
    payer: CostPayer | null;
    payerName: string | null;
  }>,
  netPaidByCost: ReadonlyMap<string, Prisma.Decimal>,
) {
  const groups = new Map<
    string,
    {
      payer: CostPayer | null;
      payerName: string | null;
      agreed: Prisma.Decimal;
      paid: Prisma.Decimal;
      costsCount: number;
    }
  >();
  for (const cost of costs) {
    const payerName = cost.payerName?.trim() || null;
    const key = `${cost.payer ?? ""}|${payerName ?? ""}`;
    const group = groups.get(key) ?? {
      payer: cost.payer,
      payerName,
      agreed: new Prisma.Decimal(0),
      paid: new Prisma.Decimal(0),
      costsCount: 0,
    };
    group.agreed = group.agreed.plus(cost.totalAmount);
    group.paid = group.paid.plus(netPaidByCost.get(cost.id) ?? 0);
    group.costsCount += 1;
    groups.set(key, group);
  }
  return [...groups.values()]
    .sort(
      (a, b) =>
        PAYER_ORDER.indexOf(a.payer) - PAYER_ORDER.indexOf(b.payer) ||
        (a.payerName ?? "").localeCompare(b.payerName ?? "", "ar"),
    )
    .map((group) => ({
      payer: group.payer,
      payerName: group.payerName,
      agreed: group.agreed.toString(),
      paid: group.paid.toString(),
      outstanding: group.agreed.minus(group.paid).toString(),
      costsCount: group.costsCount,
    }));
}

/**
 * Money in versus money committed. `total` counts pledged and received
 * sources; `availableCash` is what was received minus what was already paid;
 * `shortfall` is how much confirmed cost is not yet covered by any source
 * (null once covered, or before any source is recorded).
 */
function summarizeFunding(
  sources: readonly FundingSourceWithRepayments[],
  confirmedCost: Prisma.Decimal,
  paid: Prisma.Decimal,
  today: Date,
) {
  const zero = () => new Prisma.Decimal(0);
  let received = zero();
  let pledged = zero();
  let loanTotal = zero();
  let loanRepaid = zero();
  let overdueLoanRepayments = 0;
  let nextRepayment: {
    id: string;
    fundingSourceId: string;
    sourceName: string;
    amount: string;
    dueDate: Date;
    isOverdue: boolean;
  } | null = null;
  for (const source of sources) {
    if (source.status === FundingSourceStatus.RECEIVED) {
      received = received.plus(source.amount);
    } else {
      pledged = pledged.plus(source.amount);
    }
    if (source.kind !== FundingSourceKind.LOAN) continue;
    loanTotal = loanTotal.plus(source.amount);
    for (const repayment of source.repayments) {
      if (repayment.status === LoanRepaymentStatus.PAID) {
        loanRepaid = loanRepaid.plus(repayment.amount);
        continue;
      }
      if (repayment.status !== LoanRepaymentStatus.PLANNED || !repayment.dueDate) {
        continue;
      }
      const isOverdue = repayment.dueDate < today;
      if (isOverdue) overdueLoanRepayments += 1;
      if (!nextRepayment || repayment.dueDate < nextRepayment.dueDate) {
        nextRepayment = {
          id: repayment.id,
          fundingSourceId: source.id,
          sourceName: source.sourceName,
          amount: repayment.amount.toString(),
          dueDate: repayment.dueDate,
          isOverdue,
        };
      }
    }
  }
  const total = received.plus(pledged);
  const uncovered = confirmedCost.minus(total);
  return {
    total: total.toString(),
    received: received.toString(),
    pledged: pledged.toString(),
    availableCash: received.minus(paid).toString(),
    shortfall:
      sources.length > 0 && uncovered.gt(0) ? uncovered.toString() : null,
    loanTotal: loanTotal.toString(),
    loanRepaid: loanRepaid.toString(),
    loanOutstanding: loanTotal.minus(loanRepaid).toString(),
    overdueLoanRepayments,
    nextLoanRepayment: nextRepayment,
    sourcesCount: sources.length,
  };
}

function startOfTodayInRiyadh(now: Date) {
  const riyadh = new Date(now.getTime() + 3 * 60 * 60 * 1000);
  return new Date(
    Date.UTC(
      riyadh.getUTCFullYear(),
      riyadh.getUTCMonth(),
      riyadh.getUTCDate(),
    ) -
      3 * 60 * 60 * 1000,
  );
}
