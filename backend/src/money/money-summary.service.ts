import { Injectable, NotFoundException } from "@nestjs/common";
import {
  CostPaymentType,
  PaymentScheduleStatus,
  Prisma,
  WeddingCostStatus,
} from "@prisma/client";
import { AuthenticatedUser } from "../auth/authenticated-user.interface";
import { runRetryableTransaction } from "../common/prisma/serializable-transaction";
import { PrismaService } from "../prisma/prisma.service";
import {
  PermissionService,
  PlanAccessContext,
} from "../sharing/permission.service";

type WarningType =
  | "BUDGET_EXCEEDED"
  | "CATEGORY_EXCEEDED"
  | "PAYMENT_SCHEDULE_OVERDUE"
  | "PAYMENT_SCHEDULE_DUE_SOON";

@Injectable()
export class MoneySummaryService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly permissions: PermissionService,
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
        return buildMoneySummaryInTransaction(
          tx,
          this.permissions,
          access,
        );
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );
  }
}

export async function buildMoneySummaryInTransaction(
  tx: Prisma.TransactionClient,
  permissions: PermissionService,
  access: PlanAccessContext,
) {
  const weddingPlanId = access.plan.id;
  const [plan, categories, costs, payments, schedules] = await Promise.all([
    tx.weddingPlan.findUnique({
      where: { id: weddingPlanId },
      select: { estimatedBudget: true, currency: true },
    }),
    tx.budgetCategory.findMany({
      where: { weddingPlanId },
      orderBy: [{ createdAt: "asc" }, { id: "asc" }],
    }),
    tx.weddingCost.findMany({
      where: {
        weddingPlanId,
        status: { not: WeddingCostStatus.CANCELLED },
      },
      select: {
        id: true,
        budgetCategoryId: true,
        totalAmount: true,
        title: true,
      },
    }),
    tx.costPayment.findMany({
      where: {
        weddingCost: {
          weddingPlanId,
          status: { not: WeddingCostStatus.CANCELLED },
        },
      },
      select: { weddingCostId: true, amount: true, entryType: true },
    }),
    tx.paymentSchedule.findMany({
      where: {
        weddingCost: {
          weddingPlanId,
          status: { not: WeddingCostStatus.CANCELLED },
        },
      },
      include: {
        weddingCost: { select: { budgetCategoryId: true } },
      },
      orderBy: [{ dueDate: "asc" }, { createdAt: "asc" }],
    }),
  ]);

  if (!plan) {
    throw new NotFoundException("Wedding plan not found");
  }

  const zero = () => new Prisma.Decimal(0);
  const totalCost = costs.reduce(
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
  const allocated = categories.reduce(
    (sum, category) => sum.plus(category.allocatedAmount ?? zero()),
    zero(),
  );
  const totalBudget = plan.estimatedBudget;
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
    };
  });

  const warnings: Array<{
    type: WarningType;
    severity: "WARNING" | "DANGER";
    categoryId?: string;
    count: number | null;
    amount: string | null;
  }> = [];
  if (totalBudget !== null && totalCost.gt(totalBudget)) {
    warnings.push({
      type: "BUDGET_EXCEEDED",
      severity: "DANGER",
      count: null,
      amount: totalCost.minus(totalBudget).toString(),
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

  const next = pendingSchedules[0] ?? null;
  return {
    weddingPlanId,
    currency: plan.currency,
    budget: {
      total: totalBudget?.toString() ?? null,
      allocated: allocated.toString(),
      unallocated: totalBudget?.minus(allocated).toString() ?? null,
      confirmedCost: totalCost.toString(),
      remaining: totalBudget?.minus(totalCost).toString() ?? null,
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
    warnings,
    permissions: {
      canViewMoney: permissions.canViewMoney(access),
      canManageMoney: permissions.canManageMoney(access),
    },
  };
}

export type MoneySummaryResult = Awaited<
  ReturnType<typeof buildMoneySummaryInTransaction>
>;

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
