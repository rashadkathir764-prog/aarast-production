import { Inject, Injectable } from "@nestjs/common";
import { Prisma, SharedMemberRole } from "@prisma/client";
import { AuthenticatedUser } from "../modules/identity/public/identity-session.types";
import {
  COLLABORATION_HISTORY_PORT,
  type CollaborationHistoryPort as ContributionHistoryService,
} from "../modules/collaboration/public/collaboration-history.port";
import type { ContributionHistorySummaryResponse } from "../modules/collaboration/public/collaboration-history.port";
import {
  COLLABORATION_SCOPE_PORT,
  type CollaborationScopePort as ContributorScopeService,
} from "../modules/collaboration/public/collaboration-scope.port";
import { runRetryableTransaction } from "../platform/database/serializable-transaction";
import { endOfRiyadhDay, startOfRiyadhDay } from "../shared-kernel/time/business-day";
import {
  NOTIFICATIONS_PORT,
  type NotificationsPort,
} from "../modules/notifications/public/notifications.port";
import { PrismaService } from "../platform/database/prisma.service";
import { InsightsReadPorts } from "./insights-read-ports";
import type { DashboardSetupFacts } from "./dashboard-setup.contracts";
import { VENUE_PROVIDER_CATEGORY_SLUG } from "../modules/catalog/public/catalog-read.port";
import {
  COLLABORATION_PERMISSION_PORT,
  type CollaborationPermissionPort as PermissionService,
  PlanAccessContext,
  seesWholePlan,
} from "../modules/collaboration/public/collaboration-permission.port";
import { weddingLocationResponse } from "../modules/planning/public/wedding-location";
import {
  DashboardPermissionSummary,
  WeddingPlanDashboardSummaryResponse,
} from "./dashboard.contracts";
import {
  dashboardQuoteIds,
  dashboardTaskReadScope,
  resolveDashboardContributorDataScope,
} from "./dashboard-contributor-scope";
import { loadDashboardHomeSections } from "./dashboard-home-queries";
import { loadPlanReadView, type PlanReadViewResponse } from "./plan-read-view";
import {
  buildFinancialWarnings,
  buildImportantItems,
  compareDates,
  daysRemaining,
  moneyOrNull,
  nextProviderAction,
  progressPercentage,
  resolveBudgetDecimal,
  sumMoney,
  toPaymentScheduleDueMoneyItem,
  toNotificationPreview,
  toPlanResponse,
  toProviderPreviewResponse,
} from "./dashboard-summary.presenter";

export type {
  DashboardImportantItemResponse,
  DashboardImportantItemType,
  DashboardNotificationPreviewResponse,
  DashboardPermissionSummary,
  DashboardProviderPreviewResponse,
  WeddingPlanDashboardSummaryResponse,
} from "./dashboard.contracts";

@Injectable()
export class DashboardService {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(COLLABORATION_PERMISSION_PORT)
    private readonly permissions: PermissionService,
    @Inject(NOTIFICATIONS_PORT)
    private readonly notifications: NotificationsPort,
    private readonly owners: InsightsReadPorts,
    @Inject(COLLABORATION_SCOPE_PORT)
    private readonly contributorScope?: ContributorScopeService,
    @Inject(COLLABORATION_HISTORY_PORT)
    private readonly contributionHistory?: ContributionHistoryService,
  ) {}

  async getHome(currentUser: AuthenticatedUser) {
    const currentWeddingPlan = await this.owners.plans.findCurrentPlanningPlan(
      this.prisma,
      currentUser.id,
    );

    const sections = await loadDashboardHomeSections(
      this.prisma,
      this.owners,
      this.permissions,
      currentUser.id,
      currentWeddingPlan,
    );

    return {
      currentWeddingPlan: currentWeddingPlan
        ? toPlanResponse(currentWeddingPlan)
        : null,
      ...sections,
    };
  }

  /**
   * D52: what every member of the plan reads, whatever their role: the
   * tasks, the guests by name and reply, and the bookings, without money or
   * phones. Membership is proved on the same snapshot as the read.
   */
  async getPlanReadView(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
  ): Promise<PlanReadViewResponse> {
    return runRetryableTransaction(
      this.prisma,
      async (tx) => {
        const context = await this.permissions.assertPlanReadableInTransaction(
          tx,
          weddingPlanId,
          currentUser,
        );
        return loadPlanReadView(tx, this.owners, context, currentUser.id);
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );
  }

  async getWeddingPlanDashboardSummary(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
  ): Promise<WeddingPlanDashboardSummaryResponse & DashboardSetupFacts> {
    return runRetryableTransaction(
      this.prisma,
      (tx) =>
        this.getWeddingPlanDashboardSummaryInTransaction(
          tx,
          currentUser,
          weddingPlanId,
        ),
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );
  }

  private async getWeddingPlanDashboardSummaryInTransaction(
    tx: Prisma.TransactionClient,
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
  ): Promise<WeddingPlanDashboardSummaryResponse & DashboardSetupFacts> {
    const context = await this.permissions.assertPlanReadableInTransaction(
      tx,
      weddingPlanId,
      currentUser,
    );
    const today = startOfRiyadhDay();
    const endOfToday = endOfRiyadhDay(today);
    const dueSoonEnd = new Date(endOfToday.getTime() + 7 * 86_400_000);
    const canViewMoney = this.permissions.canViewMoney(context);
    const contributorIds = seesWholePlan(context)
      ? null
      : await resolveDashboardContributorDataScope({
          tx,
          context,
          weddingPlanId,
          actorUserId: currentUser.id,
          canViewMoney,
          contributorScope: this.requiredContributorScope(),
        });
    // Every figure below is its owner's read on this repeatable-read
    // transaction, narrowed to the contributor's own work where the reader
    // is a contributor (collaboration's history qualified the ids).
    const taskScope = dashboardTaskReadScope(contributorIds, currentUser.id);
    const quoteIds = dashboardQuoteIds(contributorIds);
    // V1 checklist 4.10: another account's private costs count nowhere.
    const costIds = canViewMoney
      ? await this.owners.finance.excludeOthersPrivateCosts(
          tx,
          weddingPlanId,
          currentUser.id,
          contributorIds ? contributorIds.costIds : null,
        )
      : null;

    const [
      costs,
      paymentSchedules,
      taskDashboard,
      guestCounters,
      providerCount,
      planProviderLinkRows,
      quoteCounters,
      participantMembersCount,
      pendingInvites,
      notificationDashboard,
    ] = await Promise.all([
      canViewMoney
        ? this.owners.finance.listPlanCostAmounts(tx, weddingPlanId, costIds)
        : Promise.resolve([]),
      canViewMoney
        ? this.owners.finance.listPendingPaymentSchedules(
            tx,
            weddingPlanId,
            costIds,
          )
        : Promise.resolve([]),
      this.owners.tasks.getPlanTaskDashboard(tx, {
        weddingPlanId,
        scope: taskScope,
        today,
        endOfToday,
      }),
      this.owners.guests.getPlanGuestCounters(
        tx,
        weddingPlanId,
        contributorIds ? contributorIds.guestIds : null,
      ),
      this.owners.providers.countActivePlanProviderLinks(
        tx,
        weddingPlanId,
        quoteIds,
      ),
      this.owners.providers.listActivePlanProviderLinks(
        tx,
        weddingPlanId,
        quoteIds,
        3,
      ),
      this.owners.quotes.getPlanQuoteCounters(tx, weddingPlanId, quoteIds),
      this.permissions.countPlanMembers(
        tx,
        weddingPlanId,
        contributorIds
          ? { userId: currentUser.id, memberIds: contributorIds.memberIds }
          : null,
      ),
      this.permissions.countLivePlanInvites(
        tx,
        weddingPlanId,
        new Date(),
        contributorIds ? contributorIds.inviteIds : null,
      ),
      this.notifications.getPlanNotificationDashboard(
        tx,
        currentUser.id,
        weddingPlanId,
      ),
    ]);
    const {
      urgentTasks,
      nextTask,
      totalTasks,
      completedTasks,
      openTasks,
      overdueTasks,
      todayTasks,
    } = taskDashboard;
    const {
      total: guestCount,
      confirmed: confirmedGuests,
      pending: pendingGuests,
      declined: declinedGuests,
      incomplete: incompleteGuestsCount,
    } = guestCounters;
    const {
      total: quoteRequestsCount,
      pending: pendingQuoteRequests,
      received: receivedQuotes,
      accepted: acceptedQuoteRequests,
      closed: rejectedClosedQuoteRequests,
    } = quoteCounters;
    const {
      unreadCount: unreadNotificationsCount,
      highPriorityCount: highPriorityNotificationsCount,
      latest: latestNotifications,
      latestImportant: latestImportantNotification,
    } = notificationDashboard;
    // The provider's primary category is catalog's row.
    const categories = new Map(
      (
        await this.owners.catalog.getCategories(tx, [
          ...new Set(
            planProviderLinkRows.flatMap((link) =>
              link.provider.primaryCategoryId
                ? [link.provider.primaryCategoryId]
                : [],
            ),
          ),
        ])
      ).map((category) => [category.id, category]),
    );
    const planProviderLinks = planProviderLinkRows.map((link) => ({
      ...link,
      provider: {
        ...link.provider,
        primaryCategory: link.provider.primaryCategoryId
          ? (categories.get(link.provider.primaryCategoryId) ?? null)
          : null,
      },
    }));

    // C24: a venue is secured by a confirmed booking with a venue provider,
    // or by a recorded agreement (a cost in a venue budget category). Each
    // owner answers for its own rows; catalog names the venue category.
    const [venueCost, bookedCategoryIds] = await Promise.all([
      canViewMoney
        ? this.owners.finance.hasVenueCost(tx, weddingPlanId, costIds)
        : Promise.resolve(false),
      this.owners.quotes.listConfirmedBookingCategoryIds(
        tx,
        weddingPlanId,
        quoteIds,
      ),
    ]);
    const venueBooked =
      bookedCategoryIds.length > 0 &&
      (await this.owners.catalog.getCategories(tx, bookedCategoryIds)).some(
        (category) => category.slug === VENUE_PROVIDER_CATEGORY_SLUG,
      );

    const dueSoonSchedules = paymentSchedules.filter(
      (schedule) => schedule.dueDate >= today && schedule.dueDate <= dueSoonEnd,
    );
    const overdueSchedules = paymentSchedules.filter(
      (schedule) => schedule.dueDate < today,
    );
    const actionableSchedules = paymentSchedules
      .filter((schedule) => schedule.dueDate <= dueSoonEnd)
      .map(toPaymentScheduleDueMoneyItem)
      .sort((a, b) => compareDates(a.dueDate, b.dueDate));
    const dueMoneyItems = actionableSchedules.slice(0, 2);
    const nextPaymentSchedule = paymentSchedules[0]
      ? toPaymentScheduleDueMoneyItem(paymentSchedules[0])
      : null;
    const effectiveDuePaymentSchedulesCount = canViewMoney
      ? actionableSchedules.length
      : null;

    // Exact decimal sums: the dashboard must agree with Finance to the cent.
    const budgetTotalNumber =
      canViewMoney && seesWholePlan(context)
        ? resolveBudgetDecimal(context.plan)
        : null;
    const confirmedCostNumber = canViewMoney
      ? sumMoney(costs.map((cost) => cost.totalAmount))
      : null;
    const paidNumber = canViewMoney
      ? sumMoney(costs.map((cost) => cost.paidAmount))
      : null;
    const outstandingNumber =
      confirmedCostNumber !== null && paidNumber !== null
        ? confirmedCostNumber.minus(paidNumber)
        : null;
    const remainingBudgetNumber =
      budgetTotalNumber !== null && confirmedCostNumber !== null
        ? budgetTotalNumber.minus(confirmedCostNumber)
        : null;
    const location = weddingLocationResponse(
      context.plan.location,
      context.plan.city,
    );
    const nextProviderActionValue = nextProviderAction(
      pendingQuoteRequests,
      receivedQuotes,
      providerCount,
    );
    const financialWarnings = buildFinancialWarnings({
      remainingBudget: remainingBudgetNumber,
      overdueCount: canViewMoney ? overdueSchedules.length : null,
      dueSoonCount: canViewMoney ? dueSoonSchedules.length : null,
    });
    const importantItems = buildImportantItems({
      weddingPlanId,
      tasks: urgentTasks,
      paymentSchedules: dueMoneyItems,
      providers: planProviderLinks,
      today,
      receivedQuotes,
      pendingInvites,
      hasLocation: location !== null,
      // A contributor must not learn whether the owner configured a plan-wide
      // budget, nor receive a misleading SET_BUDGET action for a value they
      // are not allowed to inspect.
      hasBudget:
        !seesWholePlan(context) ||
        (budgetTotalNumber !== null && budgetTotalNumber.greaterThan(0)),
      guestCount,
      quoteRequestsCount,
      acceptedProviders: providerCount,
      currency: context.plan.currency,
    });
    const currentUserRole = this.currentUserRole(context);
    const notificationPreviews = latestNotifications.map((notification) =>
      toNotificationPreview(notification),
    );
    const contributionHistory: ContributionHistorySummaryResponse | null =
      context.isOwner
        ? null
        : await this.requiredContributionHistory().summary(
            currentUser,
            weddingPlanId,
          );

    return {
      dataScope: "ACCOUNT_BACKED",
      accountBacked: true,
      planId: context.plan.id,
      membershipId: context.sharedMember?.id ?? null,
      membershipAuthorityVersion:
        context.sharedMember?.authorityVersion ?? null,
      title: context.plan.title,
      currency: context.plan.currency,
      weddingDate: context.plan.weddingDate,
      city: context.plan.city,
      location,
      status: context.plan.status,
      daysRemaining: daysRemaining(context.plan.weddingDate, today),
      progressPercentage: progressPercentage(totalTasks, completedTasks),
      budgetTotal: moneyOrNull(budgetTotalNumber),
      confirmedCostTotal: moneyOrNull(confirmedCostNumber),
      paidTotal: moneyOrNull(paidNumber),
      outstandingTotal: moneyOrNull(outstandingNumber),
      remainingBudget: moneyOrNull(remainingBudgetNumber),
      duePaymentSchedulesCount: effectiveDuePaymentSchedulesCount,
      totalTasks,
      completedTasks,
      overdueTasks,
      todayTasks,
      guestCount,
      confirmedGuests,
      pendingGuests,
      declinedGuests,
      incompleteGuestsCount,
      providerCount,
      quoteRequestsCount,
      pendingQuoteRequests,
      receivedQuotes,
      acceptedProviders: providerCount,
      acceptedProvidersCount: providerCount,
      quoteStatusBreakdown: {
        pending: pendingQuoteRequests,
        offered: receivedQuotes,
        accepted: acceptedQuoteRequests,
        rejectedClosed: rejectedClosedQuoteRequests,
      },
      nextProviderAction: nextProviderActionValue,
      participantCount: participantMembersCount + 1,
      pendingInvites,
      unreadNotificationsCount,
      highPriorityNotificationsCount,
      importantItems,
      nextBestActions: importantItems,
      planProviders: planProviderLinks.map((link) =>
        toProviderPreviewResponse(link),
      ),
      importantNotifications: notificationPreviews,
      latestImportantNotification: latestImportantNotification
        ? toNotificationPreview(latestImportantNotification)
        : null,
      nextTask: nextTask
        ? {
            id: nextTask.id,
            title: nextTask.title,
            dueAt: nextTask.dueDate,
            status: nextTask.status,
          }
        : null,
      nextPaymentScheduleDue: nextPaymentSchedule
        ? {
            id: nextPaymentSchedule.id,
            weddingCostId: nextPaymentSchedule.weddingCostId,
            title: nextPaymentSchedule.title,
            amount: nextPaymentSchedule.amount.toString(),
            dueDate: nextPaymentSchedule.dueDate,
            status: nextPaymentSchedule.status,
          }
        : null,
      venueSecured: venueCost || venueBooked,
      moneySummary: {
        totalBudget: moneyOrNull(budgetTotalNumber),
        confirmedCost: moneyOrNull(confirmedCostNumber),
        paid: moneyOrNull(paidNumber),
        outstanding: moneyOrNull(outstandingNumber),
        remainingBudget: moneyOrNull(remainingBudgetNumber),
        overBudget:
          remainingBudgetNumber === null ? null : remainingBudgetNumber.isNegative(),
      },
      financialWarnings,
      taskSummary: {
        total: totalTasks,
        completed: completedTasks,
        pendingInProgress: openTasks,
        overdue: overdueTasks,
        dueToday: todayTasks,
      },
      guestSummary: {
        total: guestCount,
        confirmed: confirmedGuests,
        pending: pendingGuests,
        declined: declinedGuests,
        incompleteGuestsCount,
      },
      providerQuoteSummary: {
        pending: pendingQuoteRequests,
        received: receivedQuotes,
        offered: receivedQuotes,
        accepted: providerCount,
        rejectedClosed: rejectedClosedQuoteRequests,
        nextAction: nextProviderActionValue,
      },
      participantSummary: {
        count: participantMembersCount + 1,
        pendingInvites,
        currentUserRole,
      },
      notificationSummary: {
        unread: unreadNotificationsCount,
        highPriority: highPriorityNotificationsCount,
      },
      generatedAt: new Date(),
      currentUserRole,
      permissions: this.permissionSummary(context),
      contributionHistory,
    };
  }

  private requiredContributorScope(): ContributorScopeService {
    if (!this.contributorScope) {
      throw new Error(
        "ContributorScopeService is required for contributor dashboard access",
      );
    }
    return this.contributorScope;
  }

  private requiredContributionHistory(): ContributionHistoryService {
    if (!this.contributionHistory) {
      throw new Error(
        "ContributionHistoryService is required for contributor dashboard access",
      );
    }
    return this.contributionHistory;
  }

  private currentUserRole(
    context: PlanAccessContext,
  ): "OWNER" | SharedMemberRole | null {
    if (context.isOwner) return "OWNER";
    return context.sharedMember?.role ?? null;
  }

  private permissionSummary(
    context: PlanAccessContext,
  ): DashboardPermissionSummary {
    const role = this.currentUserRole(context);
    return {
      isOwner: context.isOwner,
      role,
      canViewMoney: this.permissions.canViewMoney(context),
      canManageMoney: this.permissions.canManageMoney(context),
      canManageTasks: this.permissions.canManageTasks(context),
      canManageGuests: this.permissions.canManageGuests(context),
      canManageProviders: this.permissions.canManageProviders(context),
      canManageMembers: this.permissions.canManageMembers(context),
      canManagePlan: this.permissions.canManagePlan(context),
    };
  }
}
