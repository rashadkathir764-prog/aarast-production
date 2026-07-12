import { Injectable, NotFoundException } from "@nestjs/common";
import {
  ExpenseStatus,
  FinancialCommitmentSourceType,
  FinancialCommitmentStatus,
  InstallmentStatus,
  WeddingPlan,
} from "@prisma/client";
import { AuthenticatedUser } from "../auth/authenticated-user.interface";
import { endOfRiyadhDay, startOfRiyadhDay } from "../common/time/business-day";
import { PrismaService } from "../prisma/prisma.service";
import { PermissionService } from "../sharing/permission.service";
import { combineVisibleMoney } from "./money-summary.math";

export interface MoneySummaryResponse {
  weddingPlanId: string;
  currency: string;
  budgetTotal: string | null;
  totalBudget: string | null;
  categoryTargetTotal: string | null;
  spentTotal: string | null;
  totalSpent: string | null;
  plannedExpensesTotal: string | null;
  cancelledExpensesTotal: string | null;
  remainingBudget: string | null;
  confirmedCostTotal: string | null;
  totalConfirmedCost: string | null;
  paidTotal: string | null;
  outstandingTotal: string | null;
  commitmentTotal: string | null;
  commitmentPaidTotal: string | null;
  commitmentRemainingTotal: string | null;
  providerCommitmentTotal: string | null;
  manualPayableCommitmentTotal: string | null;
  deficitOrSurplus: string | null;
  dueInstallmentsCount: number | null;
  overdueInstallmentsCount: number | null;
  paidInstallmentsCount: number | null;
  remainingInstallmentsCount: number | null;
  nextInstallment: {
    id: string;
    financialCommitmentId: string;
    amount: string;
    dueAt: Date | null;
    status: InstallmentStatus;
  } | null;
  categorySummaries: {
    categoryId: string;
    name: string;
    allocated: string | null;
    spent: string | null;
    confirmedCost: string | null;
    paid: string | null;
    outstanding: string | null;
    budgetRemaining: string | null;
    remaining: string | null;
    expensesCount: number | null;
    commitmentsCount: number | null;
    installmentsCount: number | null;
    overBudget: boolean | null;
  }[];
  financialWarnings: {
    type:
      | "BUDGET_EXCEEDED"
      | "CATEGORY_EXCEEDED"
      | "INSTALLMENT_OVERDUE"
      | "INSTALLMENT_DUE_SOON"
      | "EXPENSE_WITHOUT_CATEGORY"
      | "COMMITMENT_BUDGET_EXCEEDED";
    severity: "WARNING" | "DANGER";
    message: string;
    count: number | null;
    amount: string | null;
  }[];
  categoriesCount: number | null;
  expensesCount: number | null;
  commitmentsCount: number | null;
  installmentsCount: number | null;
  permissions: {
    canViewBudget: boolean;
    canViewExpenses: boolean;
    canViewFinancialRecords: boolean;
    canManageFinancialRecords: boolean;
  };
}

@Injectable()
export class MoneySummaryService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly permissions: PermissionService,
  ) {}

  async getSummary(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
  ): Promise<MoneySummaryResponse> {
    const context = await this.permissions.assertPlanReadable(
      weddingPlanId,
      currentUser,
    );
    const canViewBudget = this.permissions.canReadFinancial(context, "budget");
    const canViewExpenses = this.permissions.canReadFinancial(
      context,
      "expenses",
    );
    const canViewFinancialRecords = this.permissions.canReadFinancial(
      context,
      "financialRecords",
    );
    const canManageFinancialRecords =
      this.permissions.canManageFinancialRecords(context);

    if (!canViewBudget && !canViewExpenses && !canViewFinancialRecords) {
      throw new NotFoundException("Wedding plan not found");
    }

    const today = this.startOfToday();
    const [categories, expenses, financialCommitments, financialInstallments] =
      await Promise.all([
      canViewBudget
        ? this.prisma.budgetCategory.findMany({ where: { weddingPlanId } })
        : Promise.resolve([]),
      canViewExpenses
        ? this.prisma.expense.findMany({ where: { weddingPlanId } })
        : Promise.resolve([]),
      canViewFinancialRecords
        ? this.prisma.financialCommitment.findMany({
            where: { weddingPlanId },
          })
        : Promise.resolve([]),
      canViewFinancialRecords
        ? this.prisma.financialInstallment.findMany({
            where: { weddingPlanId },
            orderBy: [{ dueDate: "asc" }, { createdAt: "asc" }],
          })
        : Promise.resolve([]),
      ]);
    const openFinancialInstallments = financialInstallments.filter(
      (installment) => this.isOpenInstallment(installment.status),
    );
    const installmentsCount = canViewFinancialRecords
      ? financialInstallments.length
      : null;
    const dueInstallmentsCount = canViewFinancialRecords
      ? openFinancialInstallments.filter(
          (installment) =>
            installment.dueDate !== null &&
            installment.dueDate <= this.endOfToday(today),
        ).length
      : null;
    const overdueInstallmentsCount = canViewFinancialRecords
      ? openFinancialInstallments.filter(
          (installment) =>
            installment.dueDate !== null && installment.dueDate < today,
        ).length
      : null;
    const paidInstallmentsCount = canViewFinancialRecords
      ? financialInstallments.filter(
          (installment) => installment.status === InstallmentStatus.PAID,
        ).length
      : null;
    const remainingInstallmentsCount = canViewFinancialRecords
      ? openFinancialInstallments.length
      : null;
    const dueSoonInstallmentsCount = canViewFinancialRecords
      ? openFinancialInstallments.filter(
          (installment) =>
            installment.dueDate !== null &&
            installment.dueDate >= today &&
            installment.dueDate <= this.endOfDayOffset(today, 7),
        ).length
      : null;
    const nextInstallment = openFinancialInstallments[0] ?? null;

    const categoryTargetTotal = canViewBudget
      ? categories.reduce(
          (sum, category) => sum + this.decimalToNumber(category.targetAmount),
          0,
        )
      : null;
    const budgetTotal = canViewBudget
      ? this.resolveBudgetTotal(context.plan, categoryTargetTotal ?? 0)
      : null;
    const expenseTotals = canViewExpenses ? this.expenseTotals(expenses) : null;
    const commitmentTotals = canViewFinancialRecords
      ? this.commitmentTotals(financialCommitments)
      : null;
    const confirmedCostTotal = combineVisibleMoney(
      expenseTotals?.spentTotal ?? null,
      commitmentTotals?.commitmentTotal ?? null,
    );
    const paidTotal = combineVisibleMoney(
      expenseTotals?.spentTotal ?? null,
      commitmentTotals?.commitmentPaidTotal ?? null,
    );
    const remainingBudget =
      budgetTotal !== null && confirmedCostTotal !== null
        ? budgetTotal - confirmedCostTotal
        : null;
    const outstandingTotal =
      commitmentTotals?.commitmentRemainingTotal ?? null;
    const deficitOrSurplus =
      budgetTotal !== null && confirmedCostTotal !== null
        ? budgetTotal - confirmedCostTotal
        : null;
    const categorySummaries = this.buildCategorySummaries({
      canViewBudget,
      canViewExpenses,
      canViewFinancialRecords,
      categories,
      expenses,
      commitments: financialCommitments,
      financialInstallments: canViewFinancialRecords
        ? financialInstallments
        : [],
    });
    const financialWarnings = this.buildFinancialWarnings({
      remainingBudget,
      categorySummaries,
      overdueInstallmentsCount,
      dueSoonInstallmentsCount,
      uncategorizedExpenseCount: expenseTotals?.uncategorizedCount ?? null,
    });

    return {
      weddingPlanId,
      currency: context.plan.currency,
      budgetTotal: this.moneyOrNull(budgetTotal),
      totalBudget: this.moneyOrNull(budgetTotal),
      categoryTargetTotal: this.moneyOrNull(categoryTargetTotal),
      spentTotal: this.moneyOrNull(expenseTotals?.spentTotal ?? null),
      totalSpent: this.moneyOrNull(expenseTotals?.spentTotal ?? null),
      plannedExpensesTotal: this.moneyOrNull(
        expenseTotals?.plannedExpensesTotal ?? null,
      ),
      cancelledExpensesTotal: this.moneyOrNull(
        expenseTotals?.cancelledExpensesTotal ?? null,
      ),
      remainingBudget: this.moneyOrNull(remainingBudget),
      dueInstallmentsCount,
      overdueInstallmentsCount,
      paidInstallmentsCount,
      remainingInstallmentsCount,
      confirmedCostTotal: this.moneyOrNull(confirmedCostTotal),
      totalConfirmedCost: this.moneyOrNull(confirmedCostTotal),
      paidTotal: this.moneyOrNull(paidTotal),
      outstandingTotal: this.moneyOrNull(outstandingTotal),
      commitmentTotal: this.moneyOrNull(
        commitmentTotals?.commitmentTotal ?? null,
      ),
      commitmentPaidTotal: this.moneyOrNull(
        commitmentTotals?.commitmentPaidTotal ?? null,
      ),
      commitmentRemainingTotal: this.moneyOrNull(
        commitmentTotals?.commitmentRemainingTotal ?? null,
      ),
      providerCommitmentTotal: this.moneyOrNull(
        commitmentTotals?.providerCommitmentTotal ?? null,
      ),
      manualPayableCommitmentTotal: this.moneyOrNull(
        commitmentTotals?.manualPayableCommitmentTotal ?? null,
      ),
      deficitOrSurplus: this.moneyOrNull(deficitOrSurplus),
      nextInstallment: nextInstallment
        ? {
            id: nextInstallment.id,
            financialCommitmentId: nextInstallment.financialCommitmentId,
            amount: nextInstallment.amount.toString(),
            dueAt: nextInstallment.dueDate,
            status: nextInstallment.status,
          }
        : null,
      categorySummaries,
      financialWarnings,
      categoriesCount: canViewBudget ? categories.length : null,
      expensesCount: canViewExpenses ? expenses.length : null,
      commitmentsCount: canViewFinancialRecords
        ? financialCommitments.length
        : null,
      installmentsCount,
      permissions: {
        canViewBudget,
        canViewExpenses,
        canViewFinancialRecords,
        canManageFinancialRecords,
      },
    };
  }

  private resolveBudgetTotal(
    plan: WeddingPlan,
    categoryTargetTotal: number,
  ): number {
    if (plan.estimatedBudget) return this.decimalToNumber(plan.estimatedBudget);
    return categoryTargetTotal;
  }

  private expenseTotals(
    expenses: {
      amount: { toString(): string };
      budgetCategoryId: string | null;
      status: ExpenseStatus;
    }[],
  ) {
    return expenses.reduce(
      (summary, expense) => {
        const amount = this.decimalToNumber(expense.amount);
        if (expense.status === ExpenseStatus.PAID) summary.spentTotal += amount;
        if (expense.status === ExpenseStatus.PLANNED) {
          summary.plannedExpensesTotal += amount;
        }
        if (expense.status === ExpenseStatus.CANCELLED) {
          summary.cancelledExpensesTotal += amount;
        }
        if (!expense.budgetCategoryId) summary.uncategorizedCount++;
        return summary;
      },
      {
        spentTotal: 0,
        plannedExpensesTotal: 0,
        cancelledExpensesTotal: 0,
        uncategorizedCount: 0,
      },
    );
  }

  private buildCategorySummaries({
    canViewBudget,
    canViewExpenses,
    canViewFinancialRecords,
    categories,
    expenses,
    commitments,
    financialInstallments,
  }: {
    canViewBudget: boolean;
    canViewExpenses: boolean;
    canViewFinancialRecords: boolean;
    categories: {
      id: string;
      name: string;
      targetAmount: { toString(): string } | null;
    }[];
    expenses: {
      budgetCategoryId: string | null;
      amount: { toString(): string };
      status: ExpenseStatus;
    }[];
    commitments: {
      budgetCategoryId: string;
      totalAmount: { toString(): string };
      paidAmount: { toString(): string };
      status: FinancialCommitmentStatus;
    }[];
    financialInstallments: {
      budgetCategoryId: string;
      status: InstallmentStatus;
    }[];
  }): MoneySummaryResponse["categorySummaries"] {
    if (!canViewBudget) return [];

    return categories.map((category) => {
      const allocated = this.decimalToNumber(category.targetAmount);
      const categoryExpenses = canViewExpenses
        ? expenses.filter((expense) => expense.budgetCategoryId === category.id)
        : [];
      const spent = canViewExpenses
        ? categoryExpenses.reduce((sum, expense) => {
            if (expense.status !== ExpenseStatus.PAID) return sum;
            return sum + this.decimalToNumber(expense.amount);
          }, 0)
        : null;
      const activeCommitments = canViewFinancialRecords
        ? commitments.filter(
            (commitment) =>
              commitment.budgetCategoryId === category.id &&
              commitment.status !== FinancialCommitmentStatus.CANCELLED,
          )
        : [];
      const confirmedCost = canViewFinancialRecords
        ? activeCommitments.reduce(
            (sum, commitment) =>
              sum + this.decimalToNumber(commitment.totalAmount),
            0,
          )
        : null;
      const commitmentPaid = canViewFinancialRecords
        ? activeCommitments.reduce(
            (sum, commitment) =>
              sum + this.decimalToNumber(commitment.paidAmount),
            0,
          )
        : null;
      const paid = combineVisibleMoney(commitmentPaid, spent);
      const totalConfirmedCost = combineVisibleMoney(confirmedCost, spent);
      const outstanding =
        confirmedCost === null || commitmentPaid === null
          ? null
          : Math.max(confirmedCost - commitmentPaid, 0);
      const budgetRemaining =
        totalConfirmedCost === null ? null : allocated - totalConfirmedCost;
      const remaining = spent === null ? null : allocated - spent;
      const categoryInstallments = canViewFinancialRecords
        ? financialInstallments.filter(
            (installment) => installment.budgetCategoryId === category.id,
          )
        : [];

      return {
        categoryId: category.id,
        name: category.name,
        allocated: this.moneyOrNull(allocated),
        spent: this.moneyOrNull(spent),
        confirmedCost: this.moneyOrNull(totalConfirmedCost),
        paid: this.moneyOrNull(paid),
        outstanding: this.moneyOrNull(outstanding),
        budgetRemaining: this.moneyOrNull(budgetRemaining),
        remaining: this.moneyOrNull(remaining),
        expensesCount: canViewExpenses ? categoryExpenses.length : null,
        commitmentsCount: canViewFinancialRecords
          ? activeCommitments.length
          : null,
        installmentsCount: canViewFinancialRecords
          ? categoryInstallments.length
          : null,
        overBudget:
          budgetRemaining === null
            ? remaining === null
              ? null
              : remaining < 0
            : budgetRemaining < 0,
      };
    });
  }

  private buildFinancialWarnings({
    remainingBudget,
    categorySummaries,
    overdueInstallmentsCount,
    dueSoonInstallmentsCount,
    uncategorizedExpenseCount,
  }: {
    remainingBudget: number | null;
    categorySummaries: MoneySummaryResponse["categorySummaries"];
    overdueInstallmentsCount: number | null;
    dueSoonInstallmentsCount: number | null;
    uncategorizedExpenseCount: number | null;
  }): MoneySummaryResponse["financialWarnings"] {
    const warnings: MoneySummaryResponse["financialWarnings"] = [];
    const exceededCategories = categorySummaries.filter(
      (category) => category.overBudget === true,
    );

    if (remainingBudget !== null && remainingBudget < 0) {
      warnings.push({
        type: "BUDGET_EXCEEDED",
        severity: "DANGER",
        message: "Spent total is above the available wedding budget.",
        count: null,
        amount: this.moneyOrNull(Math.abs(remainingBudget)),
      });
    }
    if (exceededCategories.length > 0) {
      warnings.push({
        type: "COMMITMENT_BUDGET_EXCEEDED",
        severity: "WARNING",
        message:
          "One or more budget categories have confirmed costs above their allocation.",
        count: exceededCategories.length,
        amount: null,
      });
    }
    if (overdueInstallmentsCount !== null && overdueInstallmentsCount > 0) {
      warnings.push({
        type: "INSTALLMENT_OVERDUE",
        severity: "DANGER",
        message: "There are overdue installments.",
        count: overdueInstallmentsCount,
        amount: null,
      });
    }
    if (dueSoonInstallmentsCount !== null && dueSoonInstallmentsCount > 0) {
      warnings.push({
        type: "INSTALLMENT_DUE_SOON",
        severity: "WARNING",
        message: "There are installments due soon.",
        count: dueSoonInstallmentsCount,
        amount: null,
      });
    }
    if (uncategorizedExpenseCount !== null && uncategorizedExpenseCount > 0) {
      warnings.push({
        type: "EXPENSE_WITHOUT_CATEGORY",
        severity: "WARNING",
        message: "Some expenses are not assigned to a budget category.",
        count: uncategorizedExpenseCount,
        amount: null,
      });
    }

    return warnings;
  }

  private commitmentTotals(
    commitments: {
      totalAmount: { toString(): string };
      paidAmount: { toString(): string };
      status: FinancialCommitmentStatus;
      sourceType: FinancialCommitmentSourceType;
      providerId: string | null;
    }[],
  ) {
    const totals = commitments.reduce(
      (summary, commitment) => {
        if (commitment.status === FinancialCommitmentStatus.CANCELLED) {
          return summary;
        }
        const totalAmount = this.decimalToNumber(commitment.totalAmount);
        const paidAmount = this.decimalToNumber(commitment.paidAmount);
        summary.commitmentTotal += totalAmount;
        summary.commitmentPaidTotal += paidAmount;
        if (
          commitment.sourceType ===
            FinancialCommitmentSourceType.PROVIDER_SERVICE ||
          commitment.providerId
        ) {
          summary.providerCommitmentTotal += totalAmount;
        }
        if (
          commitment.sourceType ===
          FinancialCommitmentSourceType.MANUAL_PAYABLE
        ) {
          summary.manualPayableCommitmentTotal += totalAmount;
        }
        return summary;
      },
      {
        commitmentTotal: 0,
        commitmentPaidTotal: 0,
        providerCommitmentTotal: 0,
        manualPayableCommitmentTotal: 0,
      },
    );

    return {
      ...totals,
      commitmentRemainingTotal: Math.max(
        totals.commitmentTotal - totals.commitmentPaidTotal,
        0,
      ),
    };
  }

  private decimalToNumber(value: { toString(): string } | null): number {
    if (!value) return 0;
    const parsed = Number(value.toString());
    return Number.isFinite(parsed) ? parsed : 0;
  }

  private moneyOrNull(value: number | null): string | null {
    return value === null ? null : value.toFixed(2);
  }

  private isOpenInstallment(status: InstallmentStatus): boolean {
    return (
      status === InstallmentStatus.PENDING ||
      status === InstallmentStatus.OVERDUE
    );
  }

  private startOfToday(): Date {
    return startOfRiyadhDay();
  }

  private endOfToday(today: Date): Date {
    return endOfRiyadhDay(today);
  }

  private endOfDayOffset(today: Date, days: number): Date {
    const target = new Date(today.getTime());
    target.setDate(target.getDate() + days);
    return endOfRiyadhDay(target);
  }
}
