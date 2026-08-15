import { Inject, Injectable } from "@nestjs/common";
import {
  ContributionAction,
  ContributionEntityType,
  PaymentSchedule,
  PaymentScheduleStatus,
  WeddingTask,
  WeddingTaskStatus,
} from "@prisma/client";
import { AuthenticatedUser } from "../modules/identity/public/identity-session.types";
import {
  COLLABORATION_SCOPE_PORT,
  type CollaborationScopePort as ContributorScopeService,
} from "../modules/collaboration/public/collaboration-scope.port";
import { PrismaService } from "../platform/database/prisma.service";
import {
  COLLABORATION_PERMISSION_PORT,
  type CollaborationPermissionPort as PermissionService,
  livePlanAuthorizationWhere,
} from "../modules/collaboration/public/collaboration-permission.port";

export interface TimelineTaskResponse {
  id: string;
  weddingPlanId: string;
  title: string;
  description: string | null;
  dueDate: Date | null;
  taskCategory: string | null;
  reminderAt: Date | null;
  status: string;
  priority: string;
}

export interface TimelinePaymentScheduleResponse {
  id: string;
  weddingCostId: string;
  costTitle: string;
  amount: string;
  dueDate: Date;
  status: PaymentScheduleStatus;
}

export interface TimelineResponse {
  weddingDate: Date | null;
  upcomingTasks: TimelineTaskResponse[];
  paymentSchedules: TimelinePaymentScheduleResponse[];
}

type ScheduleWithCost = PaymentSchedule & { weddingCost: { title: string } };

@Injectable()
export class TimelineService {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(COLLABORATION_PERMISSION_PORT)
    private readonly permissions: PermissionService,
    @Inject(COLLABORATION_SCOPE_PORT)
    private readonly contributorScope: ContributorScopeService,
  ) {}

  async getForPlan(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
  ): Promise<TimelineResponse> {
    const context = await this.permissions.assertPlanReadable(
      weddingPlanId,
      currentUser,
    );
    const canViewMoney = this.permissions.canViewMoney(context);
    const isContributor = !context.isOwner && Boolean(context.sharedMember);
    const canManageTasks = this.permissions.canManageTasks(context);
    const taskPlanAuthorization = livePlanAuthorizationWhere(
      context,
      currentUser.id,
      ["canManageTasks"],
    );
    const moneyPlanAuthorization = canViewMoney
      ? livePlanAuthorizationWhere(context, currentUser.id, ["canViewMoney"])
      : null;
    const contributionIds =
      isContributor && canManageTasks
        ? new Set(
            await this.contributorScope.qualifyingEntityIds(
              weddingPlanId,
              currentUser.id,
              [ContributionEntityType.TASK],
              [ContributionAction.CREATED, ContributionAction.COMPLETED],
            ),
          )
        : null;
    const moneyCostIds =
      isContributor && canViewMoney
        ? new Set(
            await this.contributorScope.qualifyingEntityIds(
              weddingPlanId,
              currentUser.id,
              [ContributionEntityType.WEDDING_COST],
              [
                ContributionAction.CREATED,
                ContributionAction.COMPLETED,
                ContributionAction.PAYMENT_RECORDED,
              ],
            ),
          )
        : null;

    const [taskRows, paymentRows] = await Promise.all([
      isContributor && !canManageTasks
        ? Promise.resolve([])
        : this.prisma.weddingTask.findMany({
            where: {
              weddingPlanId,
              weddingPlan: { is: taskPlanAuthorization },
              dueDate: { not: null },
              status: {
                notIn: [WeddingTaskStatus.DONE, WeddingTaskStatus.CANCELLED],
              },
              ...(contributionIds
                ? {
                    OR: [
                      { assigneeUserId: currentUser.id },
                      { id: { in: [...contributionIds] } },
                    ],
                  }
                : {}),
            },
            orderBy: [{ dueDate: "asc" }, { createdAt: "asc" }],
          }),
      canViewMoney && (!isContributor || (moneyCostIds?.size ?? 0) > 0)
        ? this.prisma.paymentSchedule.findMany({
            where: {
              status: PaymentScheduleStatus.PENDING,
              weddingCost: {
                weddingPlanId,
                weddingPlan: { is: moneyPlanAuthorization! },
                status: { not: "CANCELLED" },
                ...(moneyCostIds
                  ? { id: { in: [...moneyCostIds] } }
                  : {}),
              },
            },
            include: { weddingCost: { select: { title: true } } },
            orderBy: [{ dueDate: "asc" }, { createdAt: "asc" }],
          })
        : Promise.resolve([]),
    ]);
    const tasks = taskRows.filter(
      (task) =>
        contributionIds === null ||
        task.assigneeUserId === currentUser.id ||
        contributionIds.has(task.id),
    );
    const paymentSchedules = paymentRows.filter(
      (schedule) =>
        moneyCostIds === null || moneyCostIds.has(schedule.weddingCostId),
    );

    return {
      weddingDate: context.plan.weddingDate,
      upcomingTasks: tasks.map((task) => this.toTaskResponse(task)),
      paymentSchedules: paymentSchedules.map((schedule) =>
        this.toPaymentScheduleResponse(schedule),
      ),
    };
  }

  private toTaskResponse(task: WeddingTask): TimelineTaskResponse {
    return {
      id: task.id,
      weddingPlanId: task.weddingPlanId,
      title: task.title,
      description: task.description,
      dueDate: task.dueDate,
      taskCategory: task.taskCategory,
      reminderAt: task.reminderAt,
      status: task.status,
      priority: task.priority,
    };
  }

  private toPaymentScheduleResponse(
    schedule: ScheduleWithCost,
  ): TimelinePaymentScheduleResponse {
    return {
      id: schedule.id,
      weddingCostId: schedule.weddingCostId,
      costTitle: schedule.weddingCost.title,
      amount: schedule.amount.toString(),
      dueDate: schedule.dueDate,
      status: schedule.status,
    };
  }
}
