import { Injectable } from '@nestjs/common';
import {
  FinancialCommitment,
  FinancialCommitmentStatus,
  FinancialInstallment,
  InstallmentStatus,
  WeddingTask,
  WeddingTaskStatus,
} from '@prisma/client';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { PrismaService } from '../prisma/prisma.service';
import { PermissionService } from '../sharing/permission.service';

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

export interface TimelineCommitmentResponse {
  id: string;
  weddingPlanId: string;
  partyName: string | null;
  title: string;
  totalAmount: string;
  paidAmount: string;
  dueDate: Date | null;
  status: string;
}

export interface TimelineFinancialInstallmentResponse {
  id: string;
  financialCommitmentId: string;
  amount: string;
  dueDate: Date | null;
  status: string;
}

export interface TimelineResponse {
  weddingDate: Date | null;
  upcomingTasks: TimelineTaskResponse[];
  dueCommitments: TimelineCommitmentResponse[];
  dueInstallments: TimelineFinancialInstallmentResponse[];
}

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
    const canViewFinancialRecords = this.permissions.canReadFinancial(
      context,
      'financialRecords',
    );

    const [tasks, commitments, installments] = await Promise.all([
      this.prisma.weddingTask.findMany({
        where: {
          weddingPlanId,
          dueDate: { not: null },
          status: {
            notIn: [WeddingTaskStatus.DONE, WeddingTaskStatus.CANCELLED],
          },
        },
        orderBy: [{ dueDate: 'asc' }, { createdAt: 'asc' }],
      }),
      canViewFinancialRecords
        ? this.prisma.financialCommitment.findMany({
            where: {
              weddingPlanId,
              dueDate: { not: null },
              status: {
                in: [
                  FinancialCommitmentStatus.OPEN,
                  FinancialCommitmentStatus.PARTIALLY_PAID,
                ],
              },
            },
            orderBy: [{ dueDate: 'asc' }, { createdAt: 'asc' }],
          })
        : Promise.resolve([]),
      canViewFinancialRecords
        ? this.prisma.financialInstallment.findMany({
            where: {
              weddingPlanId,
              dueDate: { not: null },
              status: {
                in: [InstallmentStatus.PENDING, InstallmentStatus.OVERDUE],
              },
            },
            orderBy: [{ dueDate: 'asc' }, { createdAt: 'asc' }],
          })
        : Promise.resolve([]),
    ]);

    return {
      weddingDate: context.plan.weddingDate,
      upcomingTasks: tasks.map((task) => this.toTaskResponse(task)),
      dueCommitments: commitments.map((commitment) =>
        this.toCommitmentResponse(commitment),
      ),
      dueInstallments: installments.map((installment) =>
        this.toInstallmentResponse(installment),
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

  private toCommitmentResponse(
    commitment: FinancialCommitment,
  ): TimelineCommitmentResponse {
    return {
      id: commitment.id,
      weddingPlanId: commitment.weddingPlanId,
      partyName: commitment.partyName,
      title: commitment.title,
      totalAmount: commitment.totalAmount.toString(),
      paidAmount: commitment.paidAmount.toString(),
      dueDate: commitment.dueDate,
      status: commitment.status,
    };
  }

  private toInstallmentResponse(
    installment: FinancialInstallment,
  ): TimelineFinancialInstallmentResponse {
    return {
      id: installment.id,
      financialCommitmentId: installment.financialCommitmentId,
      amount: installment.amount.toString(),
      dueDate: installment.dueDate,
      status: installment.status,
    };
  }
}
