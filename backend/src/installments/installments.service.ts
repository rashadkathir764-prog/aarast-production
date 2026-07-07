import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Debt, Installment, InstallmentStatus, Prisma } from '@prisma/client';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { applyDebtPaymentDelta } from '../common/money/debt-balance';
import { DEFAULT_LIST_CAP } from '../common/pagination/list-query.dto';
import { requiredMoneyAmount } from '../common/validation/money';
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

    const status = dto.status ?? InstallmentStatus.PENDING;
    const installment = await this.prisma.$transaction(async (tx) => {
      const created = await tx.installment.create({
        data: {
          debtId,
          amount: this.requiredNonNegativeDecimal(dto.amount, 'amount'),
          dueDate: this.optionalDate(dto.dueDate, 'dueDate'),
          paidAt:
            this.optionalDate(dto.paidAt, 'paidAt') ??
            (status === InstallmentStatus.PAID ? new Date() : null),
          status,
          note: this.optionalText(dto.note),
        },
      });

      // Creating an already-paid installment must count towards the debt.
      if (status === InstallmentStatus.PAID) {
        await this.applyDebtDelta(tx, debtId, created.amount);
      }

      return created;
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
      take: DEFAULT_LIST_CAP,
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
      take: DEFAULT_LIST_CAP,
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

    const nextAmount =
      dto.amount !== undefined
        ? this.requiredNonNegativeDecimal(dto.amount, 'amount')
        : undefined;

    const installment = await this.prisma.$transaction(async (tx) => {
      // Row lock so a concurrent pay/update cannot interleave between our
      // read and our write — debt consistency depends on the exact
      // before/after states.
      await this.lockInstallmentRow(tx, id);
      const current = await tx.installment.findUniqueOrThrow({
        where: { id },
      });

      const updated = await tx.installment.update({
        where: { id },
        data: {
          ...(nextAmount !== undefined ? { amount: nextAmount } : {}),
          ...(dto.dueDate !== undefined
            ? { dueDate: this.optionalDate(dto.dueDate, 'dueDate') }
            : {}),
          ...(dto.paidAt !== undefined
            ? { paidAt: this.optionalDate(dto.paidAt, 'paidAt') }
            : {}),
          ...(dto.status !== undefined ? { status: dto.status } : {}),
          ...(dto.note !== undefined
            ? { note: this.optionalText(dto.note) }
            : {}),
          // Marking as paid through a generic update still stamps paidAt.
          ...(dto.status === InstallmentStatus.PAID &&
          dto.paidAt === undefined &&
          !current.paidAt
            ? { paidAt: new Date() }
            : {}),
        },
      });

      // Every status/amount transition keeps the parent debt consistent:
      // pay adds, un-pay subtracts, editing a paid amount applies the diff.
      const wasPaid = current.status === InstallmentStatus.PAID;
      const isPaid = updated.status === InstallmentStatus.PAID;
      const zero = new Prisma.Decimal(0);
      let delta = zero;
      if (!wasPaid && isPaid) {
        delta = updated.amount;
      } else if (wasPaid && !isPaid) {
        delta = current.amount.negated();
      } else if (wasPaid && isPaid && !updated.amount.equals(current.amount)) {
        delta = updated.amount.sub(current.amount);
      }
      if (!delta.equals(zero)) {
        await this.applyDebtDelta(tx, current.debtId, delta);
      }

      return updated;
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
      // Atomic compare-and-set: two concurrent pays of the same
      // installment must increment the debt exactly once.
      const transition = await tx.installment.updateMany({
        where: { id, status: { not: InstallmentStatus.PAID } },
        data: { status: InstallmentStatus.PAID },
      });

      if (transition.count === 1) {
        const paid = await tx.installment.findUniqueOrThrow({
          where: { id },
        });
        if (!paid.paidAt) {
          await tx.installment.update({
            where: { id },
            data: { paidAt: now },
          });
        }
        await this.applyDebtDelta(tx, paid.debtId, paid.amount);
      }

      return tx.installment.findUniqueOrThrow({ where: { id } });
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

    await this.prisma.$transaction(async (tx) => {
      await this.lockInstallmentRow(tx, id);
      const current = await tx.installment.findUnique({ where: { id } });
      if (!current) return; // Already deleted — idempotent.

      await tx.installment.delete({ where: { id } });

      // Deleting a paid installment gives the amount back to the debt
      // balance; the ledger and its installments must never diverge.
      if (current.status === InstallmentStatus.PAID) {
        await this.applyDebtDelta(tx, current.debtId, current.amount.negated());
      }
    });

    return { id, deleted: true };
  }

  /**
   * Applies a payment delta to the parent debt INSIDE the caller's
   * transaction. The debt row is re-read within the transaction and the
   * update itself holds the row lock until commit, so concurrent payments
   * of different installments cannot lose increments.
   */
  private async applyDebtDelta(
    tx: Prisma.TransactionClient,
    debtId: string,
    delta: Prisma.Decimal,
  ): Promise<void> {
    await tx.$queryRaw`SELECT id FROM "Debt" WHERE id = ${debtId} FOR UPDATE`;
    const debt = await tx.debt.findUniqueOrThrow({ where: { id: debtId } });
    const next = applyDebtPaymentDelta(debt.totalAmount, debt.paidAmount, delta);
    await tx.debt.update({
      where: { id: debtId },
      data: { paidAmount: next.paidAmount, status: next.status },
    });
  }

  private async lockInstallmentRow(
    tx: Prisma.TransactionClient,
    id: string,
  ): Promise<void> {
    await tx.$queryRaw`SELECT id FROM "Installment" WHERE id = ${id} FOR UPDATE`;
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
    return requiredMoneyAmount(value, field);
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
