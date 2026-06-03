import { Injectable, NotFoundException } from '@nestjs/common';
import {
  Debt,
  DebtStatus,
  Installment,
  InstallmentStatus,
  WeddingPlan,
  WeddingTask,
  WeddingTaskStatus,
} from '@prisma/client';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { OwnershipContextService } from '../auth/ownership-context.service';
import { PrismaService } from '../prisma/prisma.service';

export interface TimelineTaskResponse {
  id: string;
  weddingPlanId: string;
  title: string;
  description: string | null;
  dueDate: Date | null;
  status: string;
  priority: string;
}

export interface TimelineDebtResponse {
  id: string;
  weddingPlanId: string;
  creditorName: string;
  title: string;
  totalAmount: string;
  paidAmount: string;
  dueDate: Date | null;
  status: string;
}

export interface TimelineInstallmentResponse {
  id: string;
  debtId: string;
  amount: string;
  dueDate: Date | null;
  status: string;
}

export interface TimelineResponse {
  weddingDate: Date | null;
  upcomingTasks: TimelineTaskResponse[];
  dueDebts: TimelineDebtResponse[];
  dueInstallments: TimelineInstallmentResponse[];
}

@Injectable()
export class TimelineService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly ownershipContext: OwnershipContextService,
  ) {}

  async getForPlan(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
  ): Promise<TimelineResponse> {
    const plan = await this.findOwnedWeddingPlanOrThrow(currentUser, weddingPlanId);

    const [tasks, debts, installments] = await Promise.all([
      this.prisma.weddingTask.findMany({
        where: {
          weddingPlanId,
          dueDate: { not: null },
          status: { notIn: [WeddingTaskStatus.DONE, WeddingTaskStatus.CANCELLED] },
        },
        orderBy: [{ dueDate: 'asc' }, { createdAt: 'asc' }],
      }),
      this.prisma.debt.findMany({
        where: {
          weddingPlanId,
          dueDate: { not: null },
          status: { in: [DebtStatus.OPEN, DebtStatus.PARTIALLY_PAID] },
        },
        orderBy: [{ dueDate: 'asc' }, { createdAt: 'asc' }],
      }),
      this.prisma.installment.findMany({
        where: {
          dueDate: { not: null },
          status: { in: [InstallmentStatus.PENDING, InstallmentStatus.OVERDUE] },
          debt: { weddingPlanId },
        },
        orderBy: [{ dueDate: 'asc' }, { createdAt: 'asc' }],
      }),
    ]);

    return {
      weddingDate: plan.weddingDate,
      upcomingTasks: tasks.map((task) => this.toTaskResponse(task)),
      dueDebts: debts.map((debt) => this.toDebtResponse(debt)),
      dueInstallments: installments.map((installment) =>
        this.toInstallmentResponse(installment),
      ),
    };
  }

  private async findOwnedWeddingPlanOrThrow(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
  ): Promise<WeddingPlan> {
    const plan = await this.prisma.weddingPlan.findUnique({
      where: { id: weddingPlanId },
    });

    if (!plan || !this.ownershipContext.isOwner(currentUser, plan.ownerUserId)) {
      throw new NotFoundException('Wedding plan not found');
    }

    return plan;
  }

  private toTaskResponse(task: WeddingTask): TimelineTaskResponse {
    return {
      id: task.id,
      weddingPlanId: task.weddingPlanId,
      title: task.title,
      description: task.description,
      dueDate: task.dueDate,
      status: task.status,
      priority: task.priority,
    };
  }

  private toDebtResponse(debt: Debt): TimelineDebtResponse {
    return {
      id: debt.id,
      weddingPlanId: debt.weddingPlanId,
      creditorName: debt.creditorName,
      title: debt.title,
      totalAmount: debt.totalAmount.toString(),
      paidAmount: debt.paidAmount.toString(),
      dueDate: debt.dueDate,
      status: debt.status,
    };
  }

  private toInstallmentResponse(installment: Installment): TimelineInstallmentResponse {
    return {
      id: installment.id,
      debtId: installment.debtId,
      amount: installment.amount.toString(),
      dueDate: installment.dueDate,
      status: installment.status,
    };
  }
}
