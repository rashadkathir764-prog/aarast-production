import {
  Prisma,
  WeddingCostStatus,
  WeddingTaskStatus,
} from "@prisma/client";
import {
  applicationNameFields,
  toApplicationUserContact,
} from "../shared-kernel/privacy/application-user-identity";
import {
  decimalToNumber,
  moneyOrNull,
} from "./dashboard-summary.presenter";

type DashboardHomeClient = Pick<
  Prisma.TransactionClient,
  | "favoriteProvider"
  | "provider"
  | "quoteRequest"
  | "sharedMember"
  | "weddingCost"
  | "weddingPlan"
  | "weddingTask"
>;

export async function loadDashboardHomeSections(
  client: DashboardHomeClient,
  userId: string,
  weddingPlanId: string | null,
) {
  const [marketplaceSummary, moneySummary, upcomingTasks, sharedMembers] =
    await Promise.all([
      getMarketplaceSummary(client, userId),
      weddingPlanId
        ? getMoneyHomeSummary(client, weddingPlanId)
        : Promise.resolve(null),
      weddingPlanId
        ? getUpcomingTasks(client, weddingPlanId)
        : Promise.resolve([]),
      weddingPlanId
        ? getSharedMembers(client, weddingPlanId)
        : Promise.resolve([]),
    ]);
  return { marketplaceSummary, moneySummary, upcomingTasks, sharedMembers };
}

async function getMarketplaceSummary(
  client: DashboardHomeClient,
  userId: string,
) {
  const [featuredProvidersCount, favoriteProvidersCount, quoteRequestsCount] =
    await Promise.all([
      client.provider.count({ where: { status: "ACTIVE", isFeatured: true } }),
      client.favoriteProvider.count({ where: { userId } }),
      client.quoteRequest.count({ where: { userId } }),
    ]);
  return {
    featuredProvidersCount,
    favoriteProvidersCount,
    quoteRequestsCount,
  };
}

async function getMoneyHomeSummary(
  client: DashboardHomeClient,
  weddingPlanId: string,
) {
  const [plan, costs] = await Promise.all([
    client.weddingPlan.findUniqueOrThrow({
      where: { id: weddingPlanId },
      select: { estimatedBudget: true, currency: true },
    }),
    client.weddingCost.findMany({
      where: {
        weddingPlanId,
        status: { not: WeddingCostStatus.CANCELLED },
      },
      select: { totalAmount: true, paidAmount: true },
    }),
  ]);
  const confirmedCost = costs.reduce(
    (sum, cost) => sum + decimalToNumber(cost.totalAmount),
    0,
  );
  const paid = costs.reduce(
    (sum, cost) => sum + decimalToNumber(cost.paidAmount),
    0,
  );
  const totalBudget = plan.estimatedBudget
    ? decimalToNumber(plan.estimatedBudget)
    : null;
  return {
    currency: plan.currency,
    totalBudget: moneyOrNull(totalBudget),
    confirmedCost: moneyOrNull(confirmedCost),
    paid: moneyOrNull(paid),
    outstanding: moneyOrNull(confirmedCost - paid),
    remainingBudget:
      totalBudget === null ? null : moneyOrNull(totalBudget - confirmedCost),
    costsCount: costs.length,
  };
}

async function getUpcomingTasks(
  client: DashboardHomeClient,
  weddingPlanId: string,
) {
  const tasks = await client.weddingTask.findMany({
    where: {
      weddingPlanId,
      status: {
        notIn: [WeddingTaskStatus.DONE, WeddingTaskStatus.CANCELLED],
      },
    },
    orderBy: [{ dueDate: "asc" }, { createdAt: "asc" }],
    take: 5,
  });
  return tasks.map((task) => ({
    id: task.id,
    weddingPlanId: task.weddingPlanId,
    title: task.title,
    description: task.description,
    dueDate: task.dueDate,
    taskCategory: task.taskCategory,
    reminderAt: task.reminderAt,
    status: task.status,
    priority: task.priority,
  }));
}

async function getSharedMembers(
  client: DashboardHomeClient,
  weddingPlanId: string,
) {
  const members = await client.sharedMember.findMany({
    where: { weddingPlanId },
    include: {
      user: { select: { id: true, phone: true, ...applicationNameFields } },
    },
    orderBy: { createdAt: "asc" },
  });
  return members.map((member) => ({
    id: member.id,
    weddingPlanId: member.weddingPlanId,
    userId: member.userId,
    user: toApplicationUserContact(member.user),
    role: member.role,
    canViewMoney: member.canViewMoney || member.canManageMoney,
    canEditPlan: member.canEditPlan,
    canManageTasks: member.canManageTasks,
    canManageGuests: member.canManageGuests,
    canManageProviders: member.canManageProviders,
    canInviteMembers: member.canInviteMembers,
    canManageMoney: member.canManageMoney,
    receiveNotifications: member.receiveNotifications,
    createdAt: member.createdAt,
    updatedAt: member.updatedAt,
  }));
}
