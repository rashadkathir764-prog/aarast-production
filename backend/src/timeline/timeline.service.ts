import { Inject, Injectable } from "@nestjs/common";
import {
  ContributionAction,
  ContributionEntityType,
  PaymentSchedule,
  PaymentScheduleStatus,
  Prisma,
  WeddingTask,
} from "@prisma/client";
import { AuthenticatedUser } from "../modules/identity/public/identity-session.types";
import {
  COLLABORATION_SCOPE_PORT,
  type CollaborationScopePort as ContributorScopeService,
} from "../modules/collaboration/public/collaboration-scope.port";
import { PrismaService } from "../platform/database/prisma.service";
import { runRetryableTransaction } from "../platform/database/serializable-transaction";
import {
  COLLABORATION_PERMISSION_PORT,
  type CollaborationPermissionPort as PermissionService,
  seesWholePlan,
} from "../modules/collaboration/public/collaboration-permission.port";
import type { TaskReadScope } from "../modules/tasks/public/tasks.port";
import { InsightsReadPorts } from "../dashboard/insights-read-ports";

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
    private readonly owners: InsightsReadPorts,
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
    const isContributor = !seesWholePlan(context) && Boolean(context.sharedMember);
    const canManageTasks = this.permissions.canManageTasks(context);
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

    // The final reads used to join planning's table with the live
    // membership predicate; the live re-check is asked of the permission
    // port and gates the task and schedule reads of their owners, in one
    // snapshot with those reads.
    const [taskRows, paymentRows] = await runRetryableTransaction(
      this.prisma,
      async (tx) => {
        const taskAccessLive = isEmptyFilter(
          await this.permissions.liveAuthorizationFilter(
            tx,
            context,
            currentUser.id,
            ["canManageTasks"],
          ),
        );
        const moneyAccessLive =
          canViewMoney &&
          isEmptyFilter(
            await this.permissions.liveAuthorizationFilter(
              tx,
              context,
              currentUser.id,
              ["canViewMoney"],
            ),
          );
        const taskScope: TaskReadScope = !taskAccessLive
          ? { kind: "none" }
          : contributionIds
            ? {
                kind: "contributor",
                assigneeUserId: currentUser.id,
                taskIds: [...contributionIds],
              }
            : { kind: "all", readerUserId: currentUser.id };
        return Promise.all([
          isContributor && !canManageTasks
            ? Promise.resolve([])
            : this.owners.tasks.listDatedOpenTasks(tx, weddingPlanId, taskScope),
          moneyAccessLive && (!isContributor || (moneyCostIds?.size ?? 0) > 0)
            ? this.owners.finance.listPendingPaymentSchedules(
                tx,
                weddingPlanId,
                // V1 checklist 4.10: never another account's private costs.
                await this.owners.finance.excludeOthersPrivateCosts(
                  tx,
                  weddingPlanId,
                  currentUser.id,
                  moneyCostIds ? [...moneyCostIds] : null,
                ),
              )
            : Promise.resolve([]),
        ]);
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );
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

/** The permission port returns `{}` while the reader's access still holds, a never-matching filter otherwise. */
function isEmptyFilter(filter: object): boolean {
  return Object.keys(filter).length === 0;
}
