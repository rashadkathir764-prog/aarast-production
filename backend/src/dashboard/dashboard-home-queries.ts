import type { Prisma, WeddingPlan } from "@prisma/client";
import type { CollaborationPermissionPort } from "../modules/collaboration/public/collaboration-permission.port";
import { toApplicationUserContact } from "../shared-kernel/privacy/application-user-identity";
import {
  moneyOrNull,
  resolveBudgetDecimal,
  sumMoney,
} from "./dashboard-summary.presenter";
import type { InsightsReadPorts } from "./insights-read-ports";

// The home dashboard composes what the owners serve: marketplace's
// counters, finance's cost amounts, tasks' upcoming tasks, collaboration's
// members and identity's people, all read through their ports on the given
// client.
export async function loadDashboardHomeSections(
  client: Prisma.TransactionClient,
  ports: InsightsReadPorts,
  permissions: CollaborationPermissionPort,
  userId: string,
  currentWeddingPlan: WeddingPlan | null,
) {
  const weddingPlanId = currentWeddingPlan?.id ?? null;
  const [marketplaceSummary, moneySummary, upcomingTasks, sharedMembers] =
    await Promise.all([
      getMarketplaceSummary(client, ports, userId),
      currentWeddingPlan
        ? getMoneyHomeSummary(client, ports, currentWeddingPlan, userId)
        : Promise.resolve(null),
      weddingPlanId
        ? getUpcomingTasks(client, ports, weddingPlanId, userId)
        : Promise.resolve([]),
      weddingPlanId
        ? getSharedMembers(client, ports, permissions, weddingPlanId)
        : Promise.resolve([]),
    ]);
  return { marketplaceSummary, moneySummary, upcomingTasks, sharedMembers };
}

async function getMarketplaceSummary(
  client: Prisma.TransactionClient,
  ports: InsightsReadPorts,
  userId: string,
) {
  const [featuredProvidersCount, favoriteProvidersCount, quoteRequestsCount] =
    await Promise.all([
      ports.providers.countFeaturedActiveProviders(client),
      ports.providers.countUserFavorites(client, userId),
      ports.quotes.countUserQuoteRequests(client, userId),
    ]);
  return {
    featuredProvidersCount,
    favoriteProvidersCount,
    quoteRequestsCount,
  };
}

// The plan row is the one the home just read (its budget and currency);
// the costs are finance's.
async function getMoneyHomeSummary(
  client: Prisma.TransactionClient,
  ports: InsightsReadPorts,
  plan: Pick<WeddingPlan, "id" | "estimatedBudget" | "currency">,
  userId: string,
) {
  // V1 checklist 4.10: another account's private costs count nowhere.
  const costIds = await ports.finance.excludeOthersPrivateCosts(
    client,
    plan.id,
    userId,
    null,
  );
  const costs = await ports.finance.listPlanCostAmounts(client, plan.id, costIds);
  // Exact decimal sums: the home summary must agree with Finance to the cent.
  const confirmedCost = sumMoney(costs.map((cost) => cost.totalAmount));
  const paid = sumMoney(costs.map((cost) => cost.paidAmount));
  const totalBudget = resolveBudgetDecimal(plan);
  return {
    currency: plan.currency,
    totalBudget: moneyOrNull(totalBudget),
    confirmedCost: moneyOrNull(confirmedCost),
    paid: moneyOrNull(paid),
    outstanding: moneyOrNull(confirmedCost.minus(paid)),
    remainingBudget:
      totalBudget === null ? null : moneyOrNull(totalBudget.minus(confirmedCost)),
    costsCount: costs.length,
  };
}

async function getUpcomingTasks(
  client: Prisma.TransactionClient,
  ports: InsightsReadPorts,
  weddingPlanId: string,
  userId: string,
) {
  // V1 checklist 4.10: another account's private tasks are not listed.
  const tasks = await ports.tasks.listUpcomingTasks(client, weddingPlanId, 5, userId);
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
  client: Prisma.TransactionClient,
  ports: InsightsReadPorts,
  permissions: CollaborationPermissionPort,
  weddingPlanId: string,
) {
  const members = (await permissions.listPlanMembers(client, [weddingPlanId]))
    .slice()
    .sort((left, right) => left.createdAt.getTime() - right.createdAt.getTime());
  const users = new Map(
    (
      await ports.users.getAppIdentities(
        client,
        members.map((member) => member.userId),
      )
    ).map((user) => [user.id, user]),
  );
  return members.map((member) => {
    const user = users.get(member.userId);
    // The member's user is a required relation: it is missing only when
    // the account disappeared between the two statements.
    if (!user) throw new Error("Plan member user not found");
    return { member, user };
  }).map(({ member, user }) => ({
    id: member.id,
    weddingPlanId: member.weddingPlanId,
    userId: member.userId,
    user: toApplicationUserContact(user),
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
