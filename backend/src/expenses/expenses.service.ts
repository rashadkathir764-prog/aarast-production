import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Expense, ExpenseStatus } from '@prisma/client';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { PrismaService } from '../prisma/prisma.service';
import { PermissionService } from '../sharing/permission.service';
import { CreateExpenseDto } from './dto/create-expense.dto';
import { UpdateExpenseDto } from './dto/update-expense.dto';

export interface ExpenseResponse {
  id: string;
  weddingPlanId: string;
  budgetCategoryId: string | null;
  title: string;
  amount: string;
  status: ExpenseStatus;
  expenseDate: Date | null;
  note: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface ExpenseSummaryResponse {
  totalPaid: string;
  totalPlanned: string;
  totalCancelled: string;
  countPaid: number;
  countPlanned: number;
  countCancelled: number;
}

@Injectable()
export class ExpensesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly permissionService: PermissionService,
  ) {}

  async create(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    dto: CreateExpenseDto,
  ): Promise<ExpenseResponse> {
    await this.permissionService.assertFinancialManageable(weddingPlanId, currentUser);
    await this.assertCategoryBelongsToPlan(dto.budgetCategoryId, weddingPlanId);

    const expense = await this.prisma.expense.create({
      data: {
        weddingPlanId,
        budgetCategoryId: this.optionalId(dto.budgetCategoryId),
        title: this.requiredText(dto.title, 'title'),
        amount: this.requiredNonNegativeDecimal(dto.amount, 'amount'),
        status: dto.status ?? ExpenseStatus.PAID,
        expenseDate: this.optionalDate(dto.expenseDate),
        note: this.optionalText(dto.note),
      },
    });

    return this.toResponse(expense);
  }

  async findForPlan(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
  ): Promise<ExpenseResponse[]> {
    await this.permissionService.assertFinancialReadable(
      weddingPlanId,
      currentUser,
      'expenses',
    );

    const expenses = await this.prisma.expense.findMany({
      where: { weddingPlanId },
      orderBy: { createdAt: 'desc' },
    });

    return expenses.map((expense) => this.toResponse(expense));
  }

  async summary(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
  ): Promise<ExpenseSummaryResponse> {
    await this.permissionService.assertFinancialReadable(
      weddingPlanId,
      currentUser,
      'expenses',
    );

    const expenses = await this.prisma.expense.findMany({
      where: { weddingPlanId },
    });

    const summary = {
      totalPaid: 0,
      totalPlanned: 0,
      totalCancelled: 0,
      countPaid: 0,
      countPlanned: 0,
      countCancelled: 0,
    };

    for (const expense of expenses) {
      const amount = Number(expense.amount.toString());
      if (expense.status === ExpenseStatus.PAID) {
        summary.totalPaid += amount;
        summary.countPaid++;
      } else if (expense.status === ExpenseStatus.PLANNED) {
        summary.totalPlanned += amount;
        summary.countPlanned++;
      } else if (expense.status === ExpenseStatus.CANCELLED) {
        summary.totalCancelled += amount;
        summary.countCancelled++;
      }
    }

    return {
      totalPaid: summary.totalPaid.toFixed(2),
      totalPlanned: summary.totalPlanned.toFixed(2),
      totalCancelled: summary.totalCancelled.toFixed(2),
      countPaid: summary.countPaid,
      countPlanned: summary.countPlanned,
      countCancelled: summary.countCancelled,
    };
  }

  async update(
    currentUser: AuthenticatedUser,
    id: string,
    dto: UpdateExpenseDto,
  ): Promise<ExpenseResponse> {
    const existing = await this.findExpenseOrThrow(id);
    await this.permissionService.assertFinancialManageable(
      existing.weddingPlanId,
      currentUser,
    );
    if (dto.budgetCategoryId !== undefined) {
      await this.assertCategoryBelongsToPlan(
        dto.budgetCategoryId,
        existing.weddingPlanId,
      );
    }

    const expense = await this.prisma.expense.update({
      where: { id },
      data: {
        ...(dto.title !== undefined
          ? { title: this.requiredText(dto.title, 'title') }
          : {}),
        ...(dto.amount !== undefined
          ? { amount: this.requiredNonNegativeDecimal(dto.amount, 'amount') }
          : {}),
        ...(dto.budgetCategoryId !== undefined
          ? { budgetCategoryId: this.optionalId(dto.budgetCategoryId) }
          : {}),
        ...(dto.status !== undefined ? { status: dto.status } : {}),
        ...(dto.expenseDate !== undefined
          ? { expenseDate: this.optionalDate(dto.expenseDate) }
          : {}),
        ...(dto.note !== undefined ? { note: this.optionalText(dto.note) } : {}),
      },
    });

    return this.toResponse(expense);
  }

  async remove(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<{ id: string; deleted: true }> {
    const expense = await this.findExpenseOrThrow(id);
    await this.permissionService.assertFinancialManageable(
      expense.weddingPlanId,
      currentUser,
    );
    await this.prisma.expense.delete({ where: { id } });
    return { id, deleted: true };
  }

  private async findExpenseOrThrow(
    id: string,
  ): Promise<Expense> {
    const expense = await this.prisma.expense.findUnique({ where: { id } });

    if (!expense) {
      throw new NotFoundException('Expense not found');
    }

    return expense;
  }

  private async assertCategoryBelongsToPlan(
    budgetCategoryId: string | null | undefined,
    weddingPlanId: string,
  ): Promise<void> {
    const normalizedId = this.optionalId(budgetCategoryId);
    if (!normalizedId) return;

    const category = await this.prisma.budgetCategory.findFirst({
      where: { id: normalizedId, weddingPlanId },
    });

    if (!category) {
      throw new BadRequestException('budgetCategoryId must belong to the wedding plan');
    }
  }

  private requiredText(value: string, field: string): string {
    const trimmed = value.trim();
    if (!trimmed) {
      throw new BadRequestException(`${field} must not be empty`);
    }
    return trimmed;
  }

  private optionalText(value: string | null | undefined): string | null {
    if (value === undefined || value === null) return null;
    const trimmed = value.trim();
    return trimmed || null;
  }

  private optionalId(value: string | null | undefined): string | null {
    if (value === undefined || value === null) return null;
    const trimmed = value.trim();
    return trimmed || null;
  }

  private optionalDate(value: string | null | undefined): Date | null {
    if (value === undefined || value === null) return null;
    const trimmed = value.trim();
    if (!trimmed) return null;

    const timestamp = Date.parse(trimmed);
    if (Number.isNaN(timestamp)) {
      throw new BadRequestException('expenseDate must be a valid ISO date string');
    }
    return new Date(timestamp);
  }

  private requiredNonNegativeDecimal(value: string | number, field: string): string {
    const normalized = String(value).trim();
    if (!normalized || !/^\d+(\.\d+)?$/.test(normalized)) {
      throw new BadRequestException(`${field} must be a valid non-negative decimal value`);
    }

    return normalized;
  }

  private toResponse(expense: Expense): ExpenseResponse {
    return {
      id: expense.id,
      weddingPlanId: expense.weddingPlanId,
      budgetCategoryId: expense.budgetCategoryId,
      title: expense.title,
      amount: expense.amount.toString(),
      status: expense.status,
      expenseDate: expense.expenseDate,
      note: expense.note,
      createdAt: expense.createdAt,
      updatedAt: expense.updatedAt,
    };
  }
}
