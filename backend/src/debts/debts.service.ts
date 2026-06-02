import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Debt, DebtStatus, WeddingPlan } from '@prisma/client';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { OwnershipContextService } from '../auth/ownership-context.service';
import { PrismaService } from '../prisma/prisma.service';
import { CreateDebtDto } from './dto/create-debt.dto';
import { UpdateDebtDto } from './dto/update-debt.dto';

export interface DebtResponse {
  id: string;
  weddingPlanId: string;
  creditorName: string;
  title: string;
  totalAmount: string;
  paidAmount: string;
  dueDate: Date | null;
  status: DebtStatus;
  note: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface DebtSummaryResponse {
  totalDebt: string;
  totalPaid: string;
  remainingDebt: string;
  countOpen: number;
  countPartiallyPaid: number;
  countPaid: number;
  countCancelled: number;
}

@Injectable()
export class DebtsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly ownershipContext: OwnershipContextService,
  ) {}

  async create(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    dto: CreateDebtDto,
  ): Promise<DebtResponse> {
    await this.findOwnedWeddingPlanOrThrow(currentUser, weddingPlanId);

    const debt = await this.prisma.debt.create({
      data: {
        weddingPlanId,
        creditorName: this.requiredText(dto.creditorName, 'creditorName'),
        title: this.requiredText(dto.title, 'title'),
        totalAmount: this.requiredNonNegativeDecimal(dto.totalAmount, 'totalAmount'),
        paidAmount: this.optionalNonNegativeDecimal(dto.paidAmount, 'paidAmount') ?? '0',
        dueDate: this.optionalDate(dto.dueDate, 'dueDate'),
        status: dto.status ?? DebtStatus.OPEN,
        note: this.optionalText(dto.note),
      },
    });

    return this.toResponse(debt);
  }

  async findForPlan(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
  ): Promise<DebtResponse[]> {
    await this.findOwnedWeddingPlanOrThrow(currentUser, weddingPlanId);

    const debts = await this.prisma.debt.findMany({
      where: { weddingPlanId },
      orderBy: { createdAt: 'desc' },
    });

    return debts.map((debt) => this.toResponse(debt));
  }

  async summary(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
  ): Promise<DebtSummaryResponse> {
    await this.findOwnedWeddingPlanOrThrow(currentUser, weddingPlanId);

    const debts = await this.prisma.debt.findMany({
      where: { weddingPlanId },
    });

    const summary = {
      totalDebt: 0,
      totalPaid: 0,
      countOpen: 0,
      countPartiallyPaid: 0,
      countPaid: 0,
      countCancelled: 0,
    };

    for (const debt of debts) {
      const totalAmount = Number(debt.totalAmount.toString());
      const paidAmount = Number(debt.paidAmount.toString());

      if (debt.status !== DebtStatus.CANCELLED) {
        summary.totalDebt += totalAmount;
        summary.totalPaid += paidAmount;
      }

      if (debt.status === DebtStatus.OPEN) summary.countOpen++;
      if (debt.status === DebtStatus.PARTIALLY_PAID) summary.countPartiallyPaid++;
      if (debt.status === DebtStatus.PAID) summary.countPaid++;
      if (debt.status === DebtStatus.CANCELLED) summary.countCancelled++;
    }

    return {
      totalDebt: summary.totalDebt.toFixed(2),
      totalPaid: summary.totalPaid.toFixed(2),
      remainingDebt: Math.max(summary.totalDebt - summary.totalPaid, 0).toFixed(2),
      countOpen: summary.countOpen,
      countPartiallyPaid: summary.countPartiallyPaid,
      countPaid: summary.countPaid,
      countCancelled: summary.countCancelled,
    };
  }

  async update(
    currentUser: AuthenticatedUser,
    id: string,
    dto: UpdateDebtDto,
  ): Promise<DebtResponse> {
    await this.findOwnedDebtOrThrow(currentUser, id);

    const debt = await this.prisma.debt.update({
      where: { id },
      data: {
        ...(dto.creditorName !== undefined
          ? { creditorName: this.requiredText(dto.creditorName, 'creditorName') }
          : {}),
        ...(dto.title !== undefined
          ? { title: this.requiredText(dto.title, 'title') }
          : {}),
        ...(dto.totalAmount !== undefined
          ? { totalAmount: this.requiredNonNegativeDecimal(dto.totalAmount, 'totalAmount') }
          : {}),
        ...(dto.paidAmount !== undefined
          ? { paidAmount: this.requiredNonNegativeDecimal(dto.paidAmount, 'paidAmount') }
          : {}),
        ...(dto.dueDate !== undefined
          ? { dueDate: this.optionalDate(dto.dueDate, 'dueDate') }
          : {}),
        ...(dto.status !== undefined ? { status: dto.status } : {}),
        ...(dto.note !== undefined ? { note: this.optionalText(dto.note) } : {}),
      },
    });

    return this.toResponse(debt);
  }

  async remove(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<{ id: string; deleted: true }> {
    await this.findOwnedDebtOrThrow(currentUser, id);
    await this.prisma.debt.delete({ where: { id } });
    return { id, deleted: true };
  }

  async findOwnedDebtOrThrow(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<Debt> {
    const debt = await this.prisma.debt.findUnique({ where: { id } });

    if (!debt) {
      throw new NotFoundException('Debt not found');
    }

    await this.findOwnedWeddingPlanOrThrow(currentUser, debt.weddingPlanId);
    return debt;
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

  private optionalDate(value: string | null | undefined, field: string): Date | null {
    if (value === undefined || value === null) return null;
    const trimmed = value.trim();
    if (!trimmed) return null;

    const timestamp = Date.parse(trimmed);
    if (Number.isNaN(timestamp)) {
      throw new BadRequestException(`${field} must be a valid ISO date string`);
    }
    return new Date(timestamp);
  }

  private optionalNonNegativeDecimal(
    value: string | number | null | undefined,
    field: string,
  ): string | null {
    if (value === undefined || value === null) return null;
    return this.requiredNonNegativeDecimal(value, field);
  }

  private requiredNonNegativeDecimal(value: string | number, field: string): string {
    const normalized = String(value).trim();
    if (!normalized || !/^\d+(\.\d+)?$/.test(normalized)) {
      throw new BadRequestException(`${field} must be a valid non-negative decimal value`);
    }

    return normalized;
  }

  private toResponse(debt: Debt): DebtResponse {
    return {
      id: debt.id,
      weddingPlanId: debt.weddingPlanId,
      creditorName: debt.creditorName,
      title: debt.title,
      totalAmount: debt.totalAmount.toString(),
      paidAmount: debt.paidAmount.toString(),
      dueDate: debt.dueDate,
      status: debt.status,
      note: debt.note,
      createdAt: debt.createdAt,
      updatedAt: debt.updatedAt,
    };
  }
}
