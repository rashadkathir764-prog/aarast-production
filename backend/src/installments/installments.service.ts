import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Debt, DebtStatus, Installment, InstallmentStatus } from '@prisma/client';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { PrismaService } from '../prisma/prisma.service';
import { PermissionService } from '../sharing/permission.service';
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
    private readonly permissionService: PermissionService,
  ) {}

  async create(
    currentUser: AuthenticatedUser,
    debtId: string,
    dto: CreateInstallmentDto,
  ): Promise<InstallmentResponse> {
    const debt = await this.findDebtOrThrow(debtId);
    await this.permissionService.assertFinancialManageable(
      debt.weddingPlanId,
      currentUser,
    );

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
    const debt = await this.findDebtOrThrow(debtId);
    await this.permissionService.assertFinancialReadable(
      debt.weddingPlanId,
      currentUser,
      'debts',
    );

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
    await this.permissionService.assertFinancialReadable(
      weddingPlanId,
      currentUser,
      'debts',
    );

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
    const existing = await this.findInstallmentOrThrow(id);
    const debt = await this.findDebtOrThrow(existing.debtId);
    await this.permissionService.assertFinancialManageable(
      debt.weddingPlanId,
      currentUser,
    );

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

  async pay(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<InstallmentResponse> {
    const existing = await this.findInstallmentOrThrow(id);
    const debt = await this.findDebtOrThrow(existing.debtId);
    await this.permissionService.assertFinancialManageable(
      debt.weddingPlanId,
      currentUser,
    );

    const now = new Date();
    const installment = await this.prisma.$transaction(async (tx) => {
      const paidInstallment = await tx.installment.update({
        where: { id },
        data: {
          status: InstallmentStatus.PAID,
          paidAt: existing.paidAt ?? now,
        },
      });

      if (existing.status !== InstallmentStatus.PAID) {
        const currentPaidAmount = Number(debt.paidAmount.toString());
        const installmentAmount = Number(existing.amount.toString());
        const totalAmount = Number(debt.totalAmount.toString());
        const nextPaidAmount = Math.min(
          currentPaidAmount + installmentAmount,
          totalAmount,
        );

        await tx.debt.update({
          where: { id: debt.id },
          data: {
            paidAmount: nextPaidAmount.toFixed(2),
            status:
              nextPaidAmount >= totalAmount
                ? DebtStatus.PAID
                : nextPaidAmount > 0
                  ? DebtStatus.PARTIALLY_PAID
                  : DebtStatus.OPEN,
          },
        });
      }

      return paidInstallment;
    });

    return this.toResponse(installment);
  }

  async remove(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<{ id: string; deleted: true }> {
    const installment = await this.findInstallmentOrThrow(id);
    const debt = await this.findDebtOrThrow(installment.debtId);
    await this.permissionService.assertFinancialManageable(
      debt.weddingPlanId,
      currentUser,
    );
    await this.prisma.installment.delete({ where: { id } });
    return { id, deleted: true };
  }

  private async findInstallmentOrThrow(
    id: string,
  ): Promise<Installment> {
    const installment = await this.prisma.installment.findUnique({ where: { id } });

    if (!installment) {
      throw new NotFoundException('Installment not found');
    }

    return installment;
  }

  private async findDebtOrThrow(
    id: string,
  ): Promise<Debt> {
    const debt = await this.prisma.debt.findUnique({ where: { id } });

    if (!debt) {
      throw new NotFoundException('Debt not found');
    }

    return debt;
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
