import { Injectable, NotFoundException } from "@nestjs/common";
import {
  DebtStatus,
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
  manualDebtCommitmentTotal: string | null;
  deficitOrSurplus: string | null;
  debtTotal: string | null;
  totalDebts: string | null;
  paidDebtTotal: string | null;
  unpaidDebtTotal: string | null;
  debtRemaining: string | null;
  dueInstallmentsCount: number | null;
  overdueInstallmentsCount: number | null;
  paidInstallmentsCount: number | null;
  remainingInstallmentsCount: number | null;
  financialInstallmentsCount: number | null;
  financialDueInstallmentsCount: number | null;
  financialOverdueInstallmentsCount: number | null;
  financialRemainingInstallmentsCount: number | null;
  nextInstallment: {
    id: string;
    debtId: string;
    amount: string;
    dueAt: Date | null;
    status: InstallmentStatus;
  } | null;
  nextFinancialInstallment: {
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
  debtsCount: number | null;
  commitmentsCount: number | null;
  installmentsCount: number | null;
  permissions: {
    canViewBudget: boolean;
    canViewExpenses: boolean;
    canViewDebts: boolean;
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
    const canViewDebts = this.permissions.canReadFinancial(context, "debts");
    const canManageFinancialRecords =
      this.permissions.canManageFinancialRecords(context);

    if (!canViewBudget && !canViewExpenses && !canViewDebts) {
      throw new NotFoundException("Wedding plan not found");
    }

    const today = this.startOfToday();
    const [
      categories,
      expenses,
      debts,
      installmentsCount,
      dueInstallmentsCount,
      overdueInstallmentsCount,
      paidInstallmentsCount,
      remainingInstallmentsCount,
      dueSoonInstallmentsCount,
      nextInstallment,
      financialCommitments,
      financialInstallmentsCount,
      financialDueInstallmentsCount,
      financialOverdueInstallmentsCount,
      financialRemainingInstallmentsCount,
      financialDueSoonInstallmentsCount,
      nextFinancialInstallment,
    ] = await Promise.all([
      canViewBudget
        ? this.prisma.budgetCategory.findMany({ where: { weddingPlanId } })
        : Promise.resolve([]),
      canViewExpenses
        ? this.prisma.expense.findMany({ where: { weddingPlanId } })
        : Promise.resolve([]),
      canViewDebts
        ? this.prisma.debt.findMany({ where: { weddingPlanId } })
        : Promise.resolve([]),
      canViewDebts
        ? this.prisma.installment.count({ where: { debt: { weddingPlanId } } })
        : Promise.resolve(null),
      canViewDebts
        ? this.prisma.installment.count({
            where: {
              debt: { weddingPlanId },
              status: {
                in: [InstallmentStatus.PENDING, InstallmentStatus.OVERDUE],
              },
              dueDate: { lte: this.endOfToday(today) },
            },
          })
        : Promise.resolve(null),
      canViewDebts
        ? this.prisma.installment.count({
            where: {
              debt: { weddingPlanId },
              status: {
                in: [InstallmentStatus.PENDING, InstallmentStatus.OVERDUE],
              },
              dueDate: { lt: today },
            },
          })
        : Promise.resolve(null),
      canViewDebts
        ? this.prisma.installment.count({
            where: {
              debt: { weddingPlanId },
              status: InstallmentStatus.PAID,
            },
          })
        : Promise.resolve(null),
      canViewDebts
        ? this.prisma.installment.count({
            where: {
              debt: { weddingPlanId },
              status: {
                in: [InstallmentStatus.PENDING, InstallmentStatus.OVERDUE],
              },
            },
          })
        : Promise.resolve(null),
      canViewDebts
        ? this.prisma.installment.count({
            where: {
              debt: { weddingPlanId },
              status: {
                in: [InstallmentStatus.PENDING, InstallmentStatus.OVERDUE],
              },
              dueDate: { gte: today, lte: this.endOfDayOffset(today, 7) },
            },
          })
        : Promise.resolve(null),
      canViewDebts
        ? this.prisma.installment.findFirst({
            where: {
              debt: { weddingPlanId },
              status: {
                in: [InstallmentStatus.PENDING, InstallmentStatus.OVERDUE],
              },
            },
            orderBy: [{ dueDate: "asc" }, { createdAt: "asc" }],
          })
        : Promise.resolve(null),
      canViewDebts
        ? this.prisma.financialCommitment.findMany({
            where: { weddingPlanId },
          })
        : Promise.resolve([]),
      canViewDebts
        ? this.prisma.financialInstallment.count({ where: { weddingPlanId } })
        : Promise.resolve(null),
      canViewDebts
        ? this.prisma.financialInstallment.count({
            where: {
              weddingPlanId,
              status: {
                in: [InstallmentStatus.PENDING, InstallmentStatus.OVERDUE],
              },
              dueDate: { lte: this.endOfToday(today) },
            },
          })
        : Promise.resolve(null),
      canViewDebts
        ? this.prisma.financialInstallment.count({
            where: {
              weddingPlanId,
              status: {
                in: [InstallmentStatus.PENDING, InstallmentStatus.OVERDUE],
              },
              dueDate: { lt: today },
            },
          })
        : Promise.resolve(null),
      canViewDebts
        ? this.prisma.financialInstallment.count({
            where: {
              weddingPlanId,
              status: {
                in: [InstallmentStatus.PENDING, InstallmentStatus.OVERDUE],
              },
            },
          })
        : Promise.resolve(null),
      canViewDebts
        ? this.prisma.financialInstallment.count({
            where: {
              weddingPlanId,
              status: {
                in: [InstallmentStatus.PENDING, InstallmentStatus.OVERDUE],
              },
              dueDate: { gte: today, lte: this.endOfDayOffset(today, 7) },
            },
          })
        : Promise.resolve(null),
      canViewDebts
        ? this.prisma.financialInstallment.findFirst({
            where: {
              weddingPlanId,
              status: {
                in: [InstallmentStatus.PENDING, InstallmentStatus.OVERDUE],
              },
            },
            orderBy: [{ dueDate: "asc" }, { createdAt: "asc" }],
          })
        : Promise.resolve(null),
    ]);

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
    const debtTotals = canViewDebts ? this.debtTotals(debts) : null;
    const commitmentTotals = canViewDebts
      ? this.commitmentTotals(financialCommitments)
      : null;
    const remainingBudget =
      budgetTotal !== null && expenseTotals
        ? budgetTotal - expenseTotals.spentTotal
        : null;
    const confirmedCostTotal =
      commitmentTotals && debtTotals
        ? commitmentTotals.commitmentTotal + debtTotals.debtTotal
        : null;
    const paidTotal =
      commitmentTotals && debtTotals && expenseTotals
        ? commitmentTotals.commitmentPaidTotal +
          debtTotals.paidDebtTotal +
          expenseTotals.spentTotal
        : null;
    const outstandingTotal =
      commitmentTotals && debtTotals
        ? commitmentTotals.commitmentRemainingTotal + debtTotals.unpaidDebtTotal
        : null;
    const deficitOrSurplus =
      budgetTotal !== null && confirmedCostTotal !== null
        ? budgetTotal - confirmedCostTotal
        : null;
    const combinedOverdueInstallmentsCount = this.sumNullableCounts(
      overdueInstallmentsCount,
      financialOverdueInstallmentsCount,
    );
    const combinedDueSoonInstallmentsCount = this.sumNullableCounts(
      dueSoonInstallmentsCount,
      financialDueSoonInstallmentsCount,
    );
    const categorySummaries = this.buildCategorySummaries({
      canViewBudget,
      canViewExpenses,
      canViewDebts,
      categories,
      expenses,
      commitments: financialCommitments,
      financialInstallments: canViewDebts
        ? await this.prisma.financialInstallment.findMany({
            where: { weddingPlanId },
          })
        : [],
    });
    const financialWarnings = this.buildFinancialWarnings({
      remainingBudget,
      categorySummaries,
      overdueInstallmentsCount: combinedOverdueInstallmentsCount,
      dueSoonInstallmentsCount: combinedDueSoonInstallmentsCount,
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
      debtTotal: this.moneyOrNull(debtTotals?.debtTotal ?? null),
      totalDebts: this.moneyOrNull(debtTotals?.debtTotal ?? null),
      paidDebtTotal: this.moneyOrNull(debtTotals?.paidDebtTotal ?? null),
      unpaidDebtTotal: this.moneyOrNull(debtTotals?.unpaidDebtTotal ?? null),
      debtRemaining: this.moneyOrNull(debtTotals?.unpaidDebtTotal ?? null),
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
      manualDebtCommitmentTotal: this.moneyOrNull(
        commitmentTotals?.manualDebtCommitmentTotal ?? null,
      ),
      deficitOrSurplus: this.moneyOrNull(deficitOrSurplus),
      financialInstallmentsCount,
      financialDueInstallmentsCount,
      financialOverdueInstallmentsCount,
      financialRemainingInstallmentsCount,
      nextInstallment: nextInstallment
        ? {
            id: nextInstallment.id,
            debtId: nextInstallment.debtId,
            amount: nextInstallment.amount.toString(),
            dueAt: nextInstallment.dueDate,
            status: nextInstallment.status,
          }
        : null,
      nextFinancialInstallment: nextFinancialInstallment
        ? {
            id: nextFinancialInstallment.id,
            financialCommitmentId:
              nextFinancialInstallment.financialCommitmentId,
            amount: nextFinancialInstallment.amount.toString(),
            dueAt: nextFinancialInstallment.dueDate,
            status: nextFinancialInstallment.status,
          }
        : null,
      categorySummaries,
      financialWarnings,
      categoriesCount: canViewBudget ? categories.length : null,
      expensesCount: canViewExpenses ? expenses.length : null,
      debtsCount: canViewDebts ? debts.length : null,
      commitmentsCount: canViewDebts ? financialCommitments.length : null,
      installmentsCount,
      permissions: {
        canViewBudget,
        canViewExpenses,
        canViewDebts,
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
    canViewDebts,
    categories,
    expenses,
    commitments,
    financialInstallments,
  }: {
    canViewBudget: boolean;
    canViewExpenses: boolean;
    canViewDebts: boolean;
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
      const activeCommitments = canViewDebts
        ? commitments.filter(
            (commitment) =>
              commitment.budgetCategoryId === category.id &&
              commitment.status !== FinancialCommitmentStatus.CANCELLED,
          )
        : [];
      const confirmedCost = canViewDebts
        ? activeCommitments.reduce(
            (sum, commitment) =>
              sum + this.decimalToNumber(commitment.totalAmount),
            0,
          )
        : null;
      const commitmentPaid = canViewDebts
        ? activeCommitments.reduce(
            (sum, commitment) =>
              sum + this.decimalToNumber(commitment.paidAmount),
            0,
          )
        : null;
      const paid =
        commitmentPaid === null || spent === null
          ? null
          : commitmentPaid + spent;
      const outstanding =
        confirmedCost === null || commitmentPaid === null
          ? null
          : Math.max(confirmedCost - commitmentPaid, 0);
      const budgetRemaining =
        confirmedCost === null ? null : allocated - confirmedCost;
      const remaining = spent === null ? null : allocated - spent;
      const categoryInstallments = canViewDebts
        ? financialInstallments.filter(
            (installment) => installment.budgetCategoryId === category.id,
          )
        : [];

      return {
        categoryId: category.id,
        name: category.name,
        allocated: this.moneyOrNull(allocated),
        spent: this.moneyOrNull(spent),
        confirmedCost: this.moneyOrNull(confirmedCost),
        paid: this.moneyOrNull(paid),
        outstanding: this.moneyOrNull(outstanding),
        budgetRemaining: this.moneyOrNull(budgetRemaining),
        remaining: this.moneyOrNull(remaining),
        expensesCount: canViewExpenses ? categoryExpenses.length : null,
        commitmentsCount: canViewDebts ? activeCommitments.length : null,
        installmentsCount: canViewDebts ? categoryInstallments.length : null,
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

  private debtTotals(
    debts: {
      totalAmount: { toString(): string };
      paidAmount: { toString(): string };
      status: DebtStatus;
    }[],
  ) {
    const totals = debts.reduce(
      (summary, debt) => {
        if (debt.status === DebtStatus.CANCELLED) return summary;
        summary.debtTotal += this.decimalToNumber(debt.totalAmount);
        summary.paidDebtTotal += this.decimalToNumber(debt.paidAmount);
        return summary;
      },
      { debtTotal: 0, paidDebtTotal: 0 },
    );

    return {
      ...totals,
      unpaidDebtTotal: Math.max(totals.debtTotal - totals.paidDebtTotal, 0),
    };
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
          commitment.sourceType === FinancialCommitmentSourceType.MANUAL_DEBT
        ) {
          summary.manualDebtCommitmentTotal += totalAmount;
        }
        return summary;
      },
      {
        commitmentTotal: 0,
        commitmentPaidTotal: 0,
        providerCommitmentTotal: 0,
        manualDebtCommitmentTotal: 0,
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

  private sumNullableCounts(
    first: number | null,
    second: number | null,
  ): number | null {
    if (first === null && second === null) return null;
    return (first ?? 0) + (second ?? 0);
  }

  private decimalToNumber(value: { toString(): string } | null): number {
    if (!value) return 0;
    const parsed = Number(value.toString());
    return Number.isFinite(parsed) ? parsed : 0;
  }

  private moneyOrNull(value: number | null): string | null {
    return value === null ? null : value.toFixed(2);
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
