import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Debt, Installment, InstallmentStatus, WeddingPlan } from '@prisma/client';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { OwnershipContextService } from '../auth/ownership-context.service';
import { PrismaService } from '../prisma/prisma.service';
import { CreateInstallmentDto } from './dto/create-installment.dto';
import { UpdateInstallmentDto } from './dto/update-installment.dto';

export interface InstallmentResponse {
  id: string;
  debtId: string;
  amount: string;
  dueDate: Date | null;
  paidAt: Date | null;
  status: InstallmentStatus;
  note: string | null;
  createdAt: Date;
  updatedAt: Date;
}

@Injectable()
export class InstallmentsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly ownershipContext: OwnershipContextService,
  ) {}

  async create(
    currentUser: AuthenticatedUser,
    debtId: string,
    dto: CreateInstallmentDto,
  ): Promise<InstallmentResponse> {
    await this.findOwnedDebtOrThrow(currentUser, debtId);

    const installment = await this.prisma.installment.create({
      data: {
        debtId,
        amount: this.requiredNonNegativeDecimal(dto.amount, 'amount'),
        dueDate: this.optionalDate(dto.dueDate, 'dueDate'),
        paidAt: this.optionalDate(dto.paidAt, 'paidAt'),
        status: dto.status ?? InstallmentStatus.PENDING,
        note: this.optionalText(dto.note),
      },
    });

    return this.toResponse(installment);
  }

  async findForDebt(
    currentUser: AuthenticatedUser,
    debtId: string,
  ): Promise<InstallmentResponse[]> {
    await this.findOwnedDebtOrThrow(currentUser, debtId);

    const installments = await this.prisma.installment.findMany({
      where: { debtId },
      orderBy: [{ dueDate: 'asc' }, { createdAt: 'asc' }],
    });

    return installments.map((installment) => this.toResponse(installment));
  }

  async dueForPlan(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
  ): Promise<InstallmentResponse[]> {
    await this.findOwnedWeddingPlanOrThrow(currentUser, weddingPlanId);

    const installments = await this.prisma.installment.findMany({
      where: {
        status: { in: [InstallmentStatus.PENDING, InstallmentStatus.OVERDUE] },
        debt: { weddingPlanId },
      },
      orderBy: [{ dueDate: 'asc' }, { createdAt: 'asc' }],
    });

    return installments.map((installment) => this.toResponse(installment));
  }

  async update(
    currentUser: AuthenticatedUser,
    id: string,
    dto: UpdateInstallmentDto,
  ): Promise<InstallmentResponse> {
    await this.findOwnedInstallmentOrThrow(currentUser, id);

    const installment = await this.prisma.installment.update({
      where: { id },
      data: {
        ...(dto.amount !== undefined
          ? { amount: this.requiredNonNegativeDecimal(dto.amount, 'amount') }
          : {}),
        ...(dto.dueDate !== undefined
          ? { dueDate: this.optionalDate(dto.dueDate, 'dueDate') }
          : {}),
        ...(dto.paidAt !== undefined
          ? { paidAt: this.optionalDate(dto.paidAt, 'paidAt') }
          : {}),
        ...(dto.status !== undefined ? { status: dto.status } : {}),
        ...(dto.note !== undefined ? { note: this.optionalText(dto.note) } : {}),
      },
    });

    return this.toResponse(installment);
  }

  async remove(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<{ id: string; deleted: true }> {
    await this.findOwnedInstallmentOrThrow(currentUser, id);
    await this.prisma.installment.delete({ where: { id } });
    return { id, deleted: true };
  }

  private async findOwnedInstallmentOrThrow(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<Installment> {
    const installment = await this.prisma.installment.findUnique({ where: { id } });

    if (!installment) {
      throw new NotFoundException('Installment not found');
    }

    await this.findOwnedDebtOrThrow(currentUser, installment.debtId);
    return installment;
  }

  private async findOwnedDebtOrThrow(
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

  private requiredNonNegativeDecimal(value: string | number, field: string): string {
    const normalized = String(value).trim();
    if (!normalized || !/^\d+(\.\d+)?$/.test(normalized)) {
      throw new BadRequestException(`${field} must be a valid non-negative decimal value`);
    }

    return normalized;
  }

  private toResponse(installment: Installment): InstallmentResponse {
    return {
      id: installment.id,
      debtId: installment.debtId,
      amount: installment.amount.toString(),
      dueDate: installment.dueDate,
      paidAt: installment.paidAt,
      status: installment.status,
      note: installment.note,
      createdAt: installment.createdAt,
      updatedAt: installment.updatedAt,
    };
  }
}
