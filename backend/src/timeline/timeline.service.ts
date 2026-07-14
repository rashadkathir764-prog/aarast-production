import { Injectable } from "@nestjs/common";
import {
  PaymentSchedule,
  PaymentScheduleStatus,
  WeddingTask,
  WeddingTaskStatus,
} from "@prisma/client";
import { AuthenticatedUser } from "../auth/authenticated-user.interface";
import { PrismaService } from "../prisma/prisma.service";
import { PermissionService } from "../sharing/permission.service";

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
    private readonly permissions: PermissionService,
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

    const [tasks, paymentSchedules] = await Promise.all([
      this.prisma.weddingTask.findMany({
        where: {
          weddingPlanId,
          dueDate: { not: null },
          status: {
            notIn: [WeddingTaskStatus.DONE, WeddingTaskStatus.CANCELLED],
          },
        },
        orderBy: [{ dueDate: "asc" }, { createdAt: "asc" }],
      }),
      canViewMoney
        ? this.prisma.paymentSchedule.findMany({
            where: {
              status: PaymentScheduleStatus.PENDING,
              weddingCost: { weddingPlanId, status: { not: "CANCELLED" } },
            },
            include: { weddingCost: { select: { title: true } } },
            orderBy: [{ dueDate: "asc" }, { createdAt: "asc" }],
          })
        : Promise.resolve([]),
    ]);

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
