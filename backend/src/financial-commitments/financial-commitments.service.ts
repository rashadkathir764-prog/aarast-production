import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import {
  FinancialCommitment,
  FinancialCommitmentSourceType,
  FinancialCommitmentStatus,
  FinancialInstallment,
  FinancialPaymentRecord,
  FinancialPaymentRecordType,
  InstallmentStatus,
  Prisma,
} from "@prisma/client";
import { AuthenticatedUser } from "../auth/authenticated-user.interface";
import { paymentsRecordedTotal } from "../common/observability/metrics";
import {
  DEFAULT_LIST_CAP,
  ListQueryDto,
  pageArgs,
} from "../common/pagination/list-query.dto";
import { requiredMoneyAmount } from "../common/validation/money";
import { PrismaService } from "../prisma/prisma.service";
import { PermissionService } from "../sharing/permission.service";
import { CreateFinancialCommitmentDto } from "./dto/create-financial-commitment.dto";
import { CreateFinancialInstallmentDto } from "./dto/create-financial-installment.dto";
import { CreateFinancialPaymentRecordDto } from "./dto/create-financial-payment-record.dto";
import { UpdateFinancialCommitmentDto } from "./dto/update-financial-commitment.dto";
import { UpdateFinancialInstallmentDto } from "./dto/update-financial-installment.dto";

export interface FinancialCommitmentResponse {
  id: string;
  weddingPlanId: string;
  budgetCategoryId: string;
  providerId: string | null;
  planProviderLinkId: string | null;
  quoteRequestId: string | null;
  quoteOfferId: string | null;
  sourceType: FinancialCommitmentSourceType;
  title: string;
  partyName: string | null;
  partyPhone: string | null;
  totalAmount: string;
  paidAmount: string;
  remainingAmount: string;
  dueDate: Date | null;
  agreementDate: Date | null;
  status: FinancialCommitmentStatus;
  note: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface FinancialPaymentRecordResponse {
  id: string;
  weddingPlanId: string;
  financialCommitmentId: string;
  budgetCategoryId: string;
  title: string;
  amount: string;
  entryType: FinancialPaymentRecordType;
  financialInstallmentId: string | null;
  reversalOfId: string | null;
  reversedById: string | null;
  reversible: boolean;
  paidAt: Date;
  method: string | null;
  note: string | null;
  createdAt: Date;
  updatedAt: Date;
}

type FinancialPaymentRecordWithReversal = FinancialPaymentRecord & {
  reversedBy?: Pick<FinancialPaymentRecord, "id"> | null;
};

export interface FinancialInstallmentResponse {
  id: string;
  weddingPlanId: string;
  financialCommitmentId: string;
  budgetCategoryId: string;
  amount: string;
  dueDate: Date | null;
  paidAt: Date | null;
  status: InstallmentStatus;
  note: string | null;
  createdAt: Date;
  updatedAt: Date;
}

interface NormalizedFinancialReferences {
  providerId: string | null;
  planProviderLinkId: string | null;
  quoteRequestId: string | null;
  quoteOfferId: string | null;
}

@Injectable()
export class FinancialCommitmentsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly permissionService: PermissionService,
  ) {}

  async create(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    dto: CreateFinancialCommitmentDto,
  ): Promise<FinancialCommitmentResponse> {
    await this.permissionService.assertFinancialManageable(
      weddingPlanId,
      currentUser,
    );
    await this.assertCategoryBelongsToPlan(dto.budgetCategoryId, weddingPlanId);
    const refs = await this.normalizeReferences(weddingPlanId, dto);
    const totalAmount = this.requiredPositiveDecimal(
      dto.totalAmount,
      "totalAmount",
    );
    const paidAmount = this.optionalNonNegativeDecimal(
      dto.paidAmount,
      "paidAmount",
    );
    const initialPaidAmount = paidAmount ?? new Prisma.Decimal(0);
    this.assertPaidDoesNotExceedTotal(totalAmount, initialPaidAmount);
    const status =
      dto.status === FinancialCommitmentStatus.CANCELLED
        ? FinancialCommitmentStatus.CANCELLED
        : this.deriveCommitmentStatus(totalAmount, initialPaidAmount);

    const commitment = await this.prisma.$transaction(async (tx) => {
      const created = await tx.financialCommitment.create({
        data: {
          weddingPlanId,
          budgetCategoryId: dto.budgetCategoryId.trim(),
          ...refs,
          sourceType:
            dto.sourceType ?? FinancialCommitmentSourceType.MANUAL_COMMITMENT,
          title: this.requiredText(dto.title, "title"),
          partyName: this.optionalText(dto.partyName),
          partyPhone: this.optionalText(dto.partyPhone),
          totalAmount,
          paidAmount: initialPaidAmount,
          dueDate: this.optionalDate(dto.dueDate, "dueDate"),
          agreementDate: this.optionalDate(dto.agreementDate, "agreementDate"),
          status,
          note: this.optionalText(dto.note),
        },
      });

      if (initialPaidAmount.gt(0)) {
        await tx.financialPaymentRecord.create({
          data: {
            weddingPlanId,
            financialCommitmentId: created.id,
            budgetCategoryId: created.budgetCategoryId,
            title: `دفعة أولى: ${created.title}`,
            amount: initialPaidAmount,
            paidAt: created.agreementDate ?? new Date(),
          },
        });
      }

      return created;
    });
    if (initialPaidAmount.gt(0)) paymentsRecordedTotal.inc();

    return this.toCommitmentResponse(commitment);
  }

  async findForPlan(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    query?: ListQueryDto,
  ): Promise<FinancialCommitmentResponse[]> {
    await this.permissionService.assertFinancialReadable(
      weddingPlanId,
      currentUser,
      "financialRecords",
    );

    const commitments = await this.prisma.financialCommitment.findMany({
      where: { weddingPlanId },
      orderBy: [{ createdAt: "desc" }],
      ...pageArgs(query),
    });

    return commitments.map((commitment) =>
      this.toCommitmentResponse(commitment),
    );
  }

  async findOne(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<FinancialCommitmentResponse> {
    const commitment = await this.findCommitmentOrThrow(id);
    await this.permissionService.assertFinancialReadable(
      commitment.weddingPlanId,
      currentUser,
      "financialRecords",
    );
    return this.toCommitmentResponse(commitment);
  }

  async update(
    currentUser: AuthenticatedUser,
    id: string,
    dto: UpdateFinancialCommitmentDto,
  ): Promise<FinancialCommitmentResponse> {
    const existing = await this.findCommitmentOrThrow(id);
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

    const referencesChanged =
      dto.providerId !== undefined ||
      dto.planProviderLinkId !== undefined ||
      dto.quoteRequestId !== undefined ||
      dto.quoteOfferId !== undefined;
    const refs = referencesChanged
      ? await this.normalizeReferences(existing.weddingPlanId, {
          providerId:
            dto.providerId !== undefined ? dto.providerId : existing.providerId,
          planProviderLinkId:
            dto.planProviderLinkId !== undefined
              ? dto.planProviderLinkId
              : existing.planProviderLinkId,
          quoteRequestId:
            dto.quoteRequestId !== undefined
              ? dto.quoteRequestId
              : existing.quoteRequestId,
          quoteOfferId:
            dto.quoteOfferId !== undefined
              ? dto.quoteOfferId
              : existing.quoteOfferId,
        })
      : null;
    const requestedTotal =
      dto.totalAmount !== undefined
        ? this.requiredPositiveDecimal(dto.totalAmount, "totalAmount")
        : null;

    const requestedBudgetCategoryId =
      dto.budgetCategoryId !== undefined
        ? dto.budgetCategoryId.trim()
        : null;
    const commitment = await this.prisma.$transaction(async (tx) => {
      const current = await this.lockCommitment(tx, id);
      const nextTotal = requestedTotal ?? current.totalAmount;
      this.assertPaidDoesNotExceedTotal(nextTotal, current.paidAmount);
      const nextStatus =
        dto.status === FinancialCommitmentStatus.CANCELLED
          ? FinancialCommitmentStatus.CANCELLED
          : dto.status !== undefined || dto.totalAmount !== undefined
            ? this.deriveCommitmentStatus(nextTotal, current.paidAmount)
            : current.status;
      const nextBudgetCategoryId =
        requestedBudgetCategoryId ?? current.budgetCategoryId;
      const updated = await tx.financialCommitment.update({
        where: { id },
        data: {
          ...(dto.budgetCategoryId !== undefined
            ? { budgetCategoryId: nextBudgetCategoryId }
            : {}),
          ...(refs ?? {}),
          ...(dto.sourceType !== undefined
            ? { sourceType: dto.sourceType }
            : {}),
          ...(dto.title !== undefined
            ? { title: this.requiredText(dto.title, "title") }
            : {}),
          ...(dto.partyName !== undefined
            ? { partyName: this.optionalText(dto.partyName) }
            : {}),
          ...(dto.partyPhone !== undefined
            ? { partyPhone: this.optionalText(dto.partyPhone) }
            : {}),
          ...(dto.totalAmount !== undefined ? { totalAmount: nextTotal } : {}),
          ...(dto.dueDate !== undefined
            ? { dueDate: this.optionalDate(dto.dueDate, "dueDate") }
            : {}),
          ...(dto.agreementDate !== undefined
            ? {
                agreementDate: this.optionalDate(
                  dto.agreementDate,
                  "agreementDate",
                ),
              }
            : {}),
          ...(dto.status !== undefined || dto.totalAmount !== undefined
            ? { status: nextStatus }
            : {}),
          ...(dto.note !== undefined
            ? { note: this.optionalText(dto.note) }
            : {}),
        },
      });
      if (nextBudgetCategoryId !== current.budgetCategoryId) {
        // Payment rows are historical ledger entries. A commitment may move
        // category, but past payments retain the category recorded at entry.
        await tx.financialInstallment.updateMany({
          where: { financialCommitmentId: id },
          data: { budgetCategoryId: nextBudgetCategoryId },
        });
      }
      return updated;
    });

    return this.toCommitmentResponse(commitment);
  }

  async remove(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<{ id: string; deleted: true }> {
    const commitment = await this.findCommitmentOrThrow(id);
    await this.permissionService.assertFinancialManageable(
      commitment.weddingPlanId,
      currentUser,
    );
    await this.prisma.$transaction(async (tx) => {
      await this.lockCommitmentInstallments(tx, id);
      await this.lockCommitment(tx, id);
      const paymentHistory = await tx.financialPaymentRecord.count({
        where: { financialCommitmentId: id },
      });
      if (paymentHistory > 0) {
        throw new BadRequestException(
          "Commitments with payment history cannot be deleted; cancel the commitment instead",
        );
      }
      await tx.financialCommitment.delete({ where: { id } });
    });
    return { id, deleted: true };
  }

  async createPaymentRecord(
    currentUser: AuthenticatedUser,
    financialCommitmentId: string,
    dto: CreateFinancialPaymentRecordDto,
  ): Promise<FinancialPaymentRecordResponse> {
    const commitment = await this.findCommitmentOrThrow(financialCommitmentId);
    await this.permissionService.assertFinancialManageable(
      commitment.weddingPlanId,
      currentUser,
    );
    this.assertCommitmentCanReceivePayment(commitment);
    const amount = this.requiredPositiveDecimal(dto.amount, "amount");

    const payment = await this.prisma.$transaction(async (tx) => {
      const locked = await this.lockCommitment(tx, financialCommitmentId);
      this.assertPaymentWithinRemaining(locked, amount);
      const created = await tx.financialPaymentRecord.create({
        data: {
          weddingPlanId: locked.weddingPlanId,
          financialCommitmentId: locked.id,
          budgetCategoryId: locked.budgetCategoryId,
          title: this.optionalText(dto.title) ?? `دفعة: ${locked.title}`,
          amount,
          paidAt: this.optionalDate(dto.paidAt, "paidAt") ?? new Date(),
          method: this.optionalText(dto.method),
          note: this.optionalText(dto.note),
        },
      });
      await this.applyPaymentDelta(tx, locked, amount);
      return created;
    });
    paymentsRecordedTotal.inc();

    return this.toPaymentRecordResponse(payment);
  }

  async listPaymentRecordsForCommitment(
    currentUser: AuthenticatedUser,
    financialCommitmentId: string,
  ): Promise<FinancialPaymentRecordResponse[]> {
    const commitment = await this.findCommitmentOrThrow(financialCommitmentId);
    await this.permissionService.assertFinancialReadable(
      commitment.weddingPlanId,
      currentUser,
      "expenses",
    );

    const records = await this.prisma.financialPaymentRecord.findMany({
      where: { financialCommitmentId },
      include: { reversedBy: { select: { id: true } } },
      orderBy: [{ paidAt: "desc" }, { createdAt: "desc" }],
      take: DEFAULT_LIST_CAP,
    });

    return records.map((record) => this.toPaymentRecordResponse(record));
  }

  async listPaymentRecordsForPlan(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    query?: ListQueryDto,
  ): Promise<FinancialPaymentRecordResponse[]> {
    await this.permissionService.assertFinancialReadable(
      weddingPlanId,
      currentUser,
      "expenses",
    );

    const records = await this.prisma.financialPaymentRecord.findMany({
      where: { weddingPlanId },
      include: { reversedBy: { select: { id: true } } },
      orderBy: [{ paidAt: "desc" }, { createdAt: "desc" }],
      ...pageArgs(query),
    });

    return records.map((record) => this.toPaymentRecordResponse(record));
  }

  async removePaymentRecord(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<{
    id: string;
    deleted: false;
    reversed: true;
    reversalRecord: FinancialPaymentRecordResponse;
  }> {
    const existing = await this.findPaymentRecordOrThrow(id);
    await this.permissionService.assertFinancialManageable(
      existing.weddingPlanId,
      currentUser,
    );

    const reversal = await this.prisma.$transaction(async (tx) => {
      await this.lockPaymentRecord(tx, id);
      const current = await tx.financialPaymentRecord.findUniqueOrThrow({
        where: { id },
        include: { reversedBy: true },
      });
      if (current.entryType === FinancialPaymentRecordType.REVERSAL) {
        throw new BadRequestException("Reversal entries cannot be reversed");
      }
      if (current.reversedBy) return current.reversedBy;

      if (current.financialInstallmentId) {
        await this.lockInstallment(tx, current.financialInstallmentId);
        const installment = await tx.financialInstallment.findUniqueOrThrow({
          where: { id: current.financialInstallmentId },
        });
        if (installment.status === InstallmentStatus.PAID) {
          await tx.financialInstallment.update({
            where: { id: installment.id },
            data: { status: InstallmentStatus.PENDING, paidAt: null },
          });
        }
      }

      const locked = await this.lockCommitment(
        tx,
        current.financialCommitmentId,
      );
      if (current.amount.gt(locked.paidAmount)) {
        throw new BadRequestException(
          "Payment cannot be reversed because the commitment balance is inconsistent",
        );
      }
      const created = await tx.financialPaymentRecord.create({
        data: {
          weddingPlanId: current.weddingPlanId,
          financialCommitmentId: current.financialCommitmentId,
          budgetCategoryId: current.budgetCategoryId,
          title: `عكس: ${current.title}`,
          amount: current.amount,
          entryType: FinancialPaymentRecordType.REVERSAL,
          paidAt: new Date(),
          method: current.method,
          note: `قيد عكس للسجل ${current.id}`,
          reversalOfId: current.id,
        },
      });
      await this.applyPaymentDelta(tx, locked, current.amount.negated());
      return created;
    });

    return {
      id,
      deleted: false,
      reversed: true,
      reversalRecord: this.toPaymentRecordResponse(reversal),
    };
  }

  async createInstallment(
    currentUser: AuthenticatedUser,
    financialCommitmentId: string,
    dto: CreateFinancialInstallmentDto,
  ): Promise<FinancialInstallmentResponse> {
    const commitment = await this.findCommitmentOrThrow(financialCommitmentId);
    await this.permissionService.assertFinancialManageable(
      commitment.weddingPlanId,
      currentUser,
    );
    const amount = this.requiredPositiveDecimal(dto.amount, "amount");
    const status = dto.status ?? InstallmentStatus.PENDING;

    const installment = await this.prisma.$transaction(async (tx) => {
      const locked = await this.lockCommitment(tx, financialCommitmentId);
      const created = await tx.financialInstallment.create({
        data: {
          weddingPlanId: locked.weddingPlanId,
          financialCommitmentId: locked.id,
          budgetCategoryId: locked.budgetCategoryId,
          amount,
          dueDate: this.optionalDate(dto.dueDate, "dueDate"),
          paidAt:
            this.optionalDate(dto.paidAt, "paidAt") ??
            (status === InstallmentStatus.PAID ? new Date() : null),
          status,
          note: this.optionalText(dto.note),
        },
      });
      if (status === InstallmentStatus.PAID) {
        this.assertPaymentWithinRemaining(locked, amount);
        await tx.financialPaymentRecord.create({
          data: {
            weddingPlanId: locked.weddingPlanId,
            financialCommitmentId: locked.id,
            budgetCategoryId: locked.budgetCategoryId,
            title: `قسط: ${locked.title}`,
            amount,
            financialInstallmentId: created.id,
            paidAt: created.paidAt ?? new Date(),
            note: created.note,
          },
        });
        await this.applyPaymentDelta(tx, locked, amount);
      }
      return created;
    });
    if (status === InstallmentStatus.PAID) paymentsRecordedTotal.inc();

    return this.toInstallmentResponse(installment);
  }

  async listInstallmentsForCommitment(
    currentUser: AuthenticatedUser,
    financialCommitmentId: string,
  ): Promise<FinancialInstallmentResponse[]> {
    const commitment = await this.findCommitmentOrThrow(financialCommitmentId);
    await this.permissionService.assertFinancialReadable(
      commitment.weddingPlanId,
      currentUser,
      "financialRecords",
    );

    const installments = await this.prisma.financialInstallment.findMany({
      where: { financialCommitmentId },
      orderBy: [{ dueDate: "asc" }, { createdAt: "asc" }],
    });

    return installments.map((installment) =>
      this.toInstallmentResponse(installment),
    );
  }

  async listDueInstallmentsForPlan(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
  ): Promise<FinancialInstallmentResponse[]> {
    await this.permissionService.assertFinancialReadable(
      weddingPlanId,
      currentUser,
      "financialRecords",
    );

    const installments = await this.prisma.financialInstallment.findMany({
      where: {
        weddingPlanId,
        status: { in: [InstallmentStatus.PENDING, InstallmentStatus.OVERDUE] },
      },
      orderBy: [{ dueDate: "asc" }, { createdAt: "asc" }],
    });

    return installments.map((installment) =>
      this.toInstallmentResponse(installment),
    );
  }

  async updateInstallment(
    currentUser: AuthenticatedUser,
    id: string,
    dto: UpdateFinancialInstallmentDto,
  ): Promise<FinancialInstallmentResponse> {
    const existing = await this.findInstallmentOrThrow(id);
    await this.permissionService.assertFinancialManageable(
      existing.weddingPlanId,
      currentUser,
    );
    if (existing.status === InstallmentStatus.PAID) {
      throw new BadRequestException(
        "Paid financial installments cannot be edited; adjust the payment record instead",
      );
    }
    if (dto.status === InstallmentStatus.PAID) {
      return this.payInstallment(currentUser, id, dto.paidAt);
    }

    const installment = await this.prisma.$transaction(async (tx) => {
      await this.lockInstallment(tx, id);
      const current = await tx.financialInstallment.findUniqueOrThrow({
        where: { id },
      });
      if (current.status === InstallmentStatus.PAID) {
        throw new BadRequestException(
          "Paid financial installments cannot be edited; reverse the linked payment instead",
        );
      }
      return tx.financialInstallment.update({
        where: { id },
        data: {
          ...(dto.amount !== undefined
            ? { amount: this.requiredPositiveDecimal(dto.amount, "amount") }
            : {}),
          ...(dto.dueDate !== undefined
            ? { dueDate: this.optionalDate(dto.dueDate, "dueDate") }
            : {}),
          ...(dto.status !== undefined ? { status: dto.status } : {}),
          ...(dto.note !== undefined
            ? { note: this.optionalText(dto.note) }
            : {}),
        },
      });
    });

    return this.toInstallmentResponse(installment);
  }

  async payInstallment(
    currentUser: AuthenticatedUser,
    id: string,
    paidAt?: string | null,
  ): Promise<FinancialInstallmentResponse> {
    const existing = await this.findInstallmentOrThrow(id);
    await this.permissionService.assertFinancialManageable(
      existing.weddingPlanId,
      currentUser,
    );

    // Repeating pay on an already-PAID installment is a no-op, so the
    // counter must only tick when a record was actually written.
    let recordedPayment = false;
    const installment = await this.prisma.$transaction(async (tx) => {
      await this.lockInstallment(tx, id);
      const current = await tx.financialInstallment.findUniqueOrThrow({
        where: { id },
      });
      if (current.status === InstallmentStatus.PAID) return current;

      const locked = await this.lockCommitment(
        tx,
        current.financialCommitmentId,
      );
      this.assertPaymentWithinRemaining(locked, current.amount);
      const paidDate = this.optionalDate(paidAt, "paidAt") ?? new Date();
      const updated = await tx.financialInstallment.update({
        where: { id },
        data: {
          status: InstallmentStatus.PAID,
          paidAt: paidDate,
        },
      });
      await tx.financialPaymentRecord.create({
        data: {
          weddingPlanId: locked.weddingPlanId,
          financialCommitmentId: locked.id,
          budgetCategoryId: locked.budgetCategoryId,
          title: `قسط: ${locked.title}`,
          amount: current.amount,
          financialInstallmentId: current.id,
          paidAt: paidDate,
          note: current.note,
        },
      });
      await this.applyPaymentDelta(tx, locked, current.amount);
      recordedPayment = true;
      return updated;
    });
    if (recordedPayment) paymentsRecordedTotal.inc();

    return this.toInstallmentResponse(installment);
  }

  async removeInstallment(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<{ id: string; deleted: true }> {
    const existing = await this.findInstallmentOrThrow(id);
    await this.permissionService.assertFinancialManageable(
      existing.weddingPlanId,
      currentUser,
    );
    await this.prisma.$transaction(async (tx) => {
      await this.lockInstallment(tx, id);
      const current = await tx.financialInstallment.findUniqueOrThrow({
        where: { id },
      });
      if (current.status === InstallmentStatus.PAID) {
        throw new BadRequestException(
          "Paid financial installments cannot be deleted; reverse the linked payment instead",
        );
      }
      const paymentHistory = await tx.financialPaymentRecord.count({
        where: { financialInstallmentId: id },
      });
      if (paymentHistory > 0) {
        throw new BadRequestException(
          "Installments with payment history cannot be deleted; keep the audit trail",
        );
      }
      await tx.financialInstallment.delete({ where: { id } });
    });
    return { id, deleted: true };
  }

  private async findCommitmentOrThrow(
    id: string,
  ): Promise<FinancialCommitment> {
    const commitment = await this.prisma.financialCommitment.findUnique({
      where: { id },
    });
    if (!commitment)
      throw new NotFoundException("Financial commitment not found");
    return commitment;
  }

  private async findPaymentRecordOrThrow(
    id: string,
  ): Promise<FinancialPaymentRecord> {
    const record = await this.prisma.financialPaymentRecord.findUnique({
      where: { id },
    });
    if (!record)
      throw new NotFoundException("Financial payment record not found");
    return record;
  }

  private async findInstallmentOrThrow(
    id: string,
  ): Promise<FinancialInstallment> {
    const installment = await this.prisma.financialInstallment.findUnique({
      where: { id },
    });
    if (!installment) {
      throw new NotFoundException("Financial installment not found");
    }
    return installment;
  }

  private async assertCategoryBelongsToPlan(
    budgetCategoryId: string | null | undefined,
    weddingPlanId: string,
  ): Promise<void> {
    const normalizedId = this.optionalId(budgetCategoryId);
    if (!normalizedId) {
      throw new BadRequestException("budgetCategoryId is required");
    }
    const category = await this.prisma.budgetCategory.findFirst({
      where: { id: normalizedId, weddingPlanId },
    });
    if (!category) {
      throw new BadRequestException(
        "budgetCategoryId must belong to the wedding plan",
      );
    }
  }

  private async normalizeReferences(
    weddingPlanId: string,
    input: {
      providerId?: string | null;
      planProviderLinkId?: string | null;
      quoteRequestId?: string | null;
      quoteOfferId?: string | null;
    },
  ): Promise<NormalizedFinancialReferences> {
    let providerId = this.optionalId(input.providerId);
    let planProviderLinkId = this.optionalId(input.planProviderLinkId);
    let quoteRequestId = this.optionalId(input.quoteRequestId);
    const quoteOfferId = this.optionalId(input.quoteOfferId);

    if (providerId) {
      const provider = await this.prisma.provider.findUnique({
        where: { id: providerId },
      });
      if (!provider) throw new BadRequestException("providerId is invalid");
    }

    if (planProviderLinkId) {
      const link = await this.prisma.planProviderLink.findFirst({
        where: { id: planProviderLinkId, weddingPlanId },
      });
      if (!link) {
        throw new BadRequestException(
          "planProviderLinkId must belong to the wedding plan",
        );
      }
      if (providerId && providerId !== link.providerId) {
        throw new BadRequestException(
          "providerId must match the linked plan provider",
        );
      }
      providerId = providerId ?? link.providerId;
    }

    if (quoteRequestId) {
      const quoteRequest = await this.prisma.quoteRequest.findFirst({
        where: { id: quoteRequestId, weddingPlanId },
      });
      if (!quoteRequest) {
        throw new BadRequestException(
          "quoteRequestId must belong to the wedding plan",
        );
      }
      if (providerId && providerId !== quoteRequest.providerId) {
        throw new BadRequestException(
          "providerId must match the quote request",
        );
      }
      providerId = providerId ?? quoteRequest.providerId;
    }

    if (quoteOfferId) {
      const offer = await this.prisma.quoteOffer.findFirst({
        where: {
          id: quoteOfferId,
          quoteRequest: { weddingPlanId },
        },
        include: { quoteRequest: true },
      });
      if (!offer) {
        throw new BadRequestException(
          "quoteOfferId must belong to the wedding plan",
        );
      }
      if (providerId && providerId !== offer.providerId) {
        throw new BadRequestException("providerId must match the quote offer");
      }
      if (quoteRequestId && quoteRequestId !== offer.quoteRequestId) {
        throw new BadRequestException(
          "quoteRequestId must match the quote offer",
        );
      }
      providerId = providerId ?? offer.providerId;
      quoteRequestId = quoteRequestId ?? offer.quoteRequestId;
    }

    return {
      providerId,
      planProviderLinkId,
      quoteRequestId,
      quoteOfferId,
    };
  }

  private async lockCommitment(
    tx: Prisma.TransactionClient,
    id: string,
  ): Promise<FinancialCommitment> {
    await tx.$queryRaw`SELECT id FROM "FinancialCommitment" WHERE id = ${id} FOR UPDATE`;
    return tx.financialCommitment.findUniqueOrThrow({ where: { id } });
  }

  private async lockInstallment(
    tx: Prisma.TransactionClient,
    id: string,
  ): Promise<void> {
    await tx.$queryRaw`SELECT id FROM "FinancialInstallment" WHERE id = ${id} FOR UPDATE`;
  }

  private async lockCommitmentInstallments(
    tx: Prisma.TransactionClient,
    financialCommitmentId: string,
  ): Promise<void> {
    await tx.$queryRaw`SELECT id FROM "FinancialInstallment" WHERE "financialCommitmentId" = ${financialCommitmentId} FOR UPDATE`;
  }

  private async lockPaymentRecord(
    tx: Prisma.TransactionClient,
    id: string,
  ): Promise<void> {
    await tx.$queryRaw`SELECT id FROM "FinancialPaymentRecord" WHERE id = ${id} FOR UPDATE`;
  }

  private async applyPaymentDelta(
    tx: Prisma.TransactionClient,
    commitment: FinancialCommitment,
    delta: Prisma.Decimal,
  ): Promise<void> {
    const nextPaid = this.clampDecimal(
      commitment.paidAmount.add(delta),
      new Prisma.Decimal(0),
      commitment.totalAmount,
    );
    await tx.financialCommitment.update({
      where: { id: commitment.id },
      data: {
        paidAmount: nextPaid,
        status:
          commitment.status === FinancialCommitmentStatus.CANCELLED
            ? FinancialCommitmentStatus.CANCELLED
            : this.deriveCommitmentStatus(commitment.totalAmount, nextPaid),
      },
    });
  }

  private assertCommitmentCanReceivePayment(
    commitment: FinancialCommitment,
  ): void {
    if (commitment.status === FinancialCommitmentStatus.CANCELLED) {
      throw new BadRequestException(
        "Cancelled commitments cannot receive payments",
      );
    }
  }

  private assertPaymentWithinRemaining(
    commitment: FinancialCommitment,
    amount: Prisma.Decimal,
  ): void {
    this.assertCommitmentCanReceivePayment(commitment);
    const remaining = commitment.totalAmount.sub(commitment.paidAmount);
    if (amount.gt(remaining)) {
      throw new BadRequestException("amount cannot exceed remainingAmount");
    }
  }

  private assertPaidDoesNotExceedTotal(
    totalAmount: Prisma.Decimal,
    paidAmount: Prisma.Decimal,
  ): void {
    if (paidAmount.gt(totalAmount)) {
      throw new BadRequestException("paidAmount cannot exceed totalAmount");
    }
  }

  private deriveCommitmentStatus(
    totalAmount: Prisma.Decimal,
    paidAmount: Prisma.Decimal,
  ): FinancialCommitmentStatus {
    if (totalAmount.lte(0) || paidAmount.lte(0)) {
      return FinancialCommitmentStatus.OPEN;
    }
    if (paidAmount.gte(totalAmount)) return FinancialCommitmentStatus.PAID;
    return FinancialCommitmentStatus.PARTIALLY_PAID;
  }

  private clampDecimal(
    value: Prisma.Decimal,
    min: Prisma.Decimal,
    max: Prisma.Decimal,
  ): Prisma.Decimal {
    if (value.lt(min)) return min;
    if (value.gt(max)) return max;
    return value;
  }

  private requiredText(value: string, field: string): string {
    const trimmed = value.trim();
    if (!trimmed) throw new BadRequestException(`${field} must not be empty`);
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

  private optionalDate(
    value: string | null | undefined,
    field: string,
  ): Date | null {
    if (value === undefined || value === null) return null;
    const trimmed = value.trim();
    if (!trimmed) return null;

    const timestamp = Date.parse(trimmed);
    if (Number.isNaN(timestamp)) {
      throw new BadRequestException(`${field} must be a valid ISO date string`);
    }
    return new Date(timestamp);
  }

  private requiredNonNegativeDecimal(
    value: string | number,
    field: string,
  ): Prisma.Decimal {
    return new Prisma.Decimal(requiredMoneyAmount(value, field));
  }

  private optionalNonNegativeDecimal(
    value: string | number | null | undefined,
    field: string,
  ): Prisma.Decimal | null {
    if (value === undefined || value === null) return null;
    return this.requiredNonNegativeDecimal(value, field);
  }

  private requiredPositiveDecimal(
    value: string | number,
    field: string,
  ): Prisma.Decimal {
    const amount = this.requiredNonNegativeDecimal(value, field);
    if (amount.lte(0)) {
      throw new BadRequestException(`${field} must be greater than zero`);
    }
    return amount;
  }

  private toCommitmentResponse(
    commitment: FinancialCommitment,
  ): FinancialCommitmentResponse {
    const remaining = commitment.totalAmount.sub(commitment.paidAmount);
    return {
      id: commitment.id,
      weddingPlanId: commitment.weddingPlanId,
      budgetCategoryId: commitment.budgetCategoryId,
      providerId: commitment.providerId,
      planProviderLinkId: commitment.planProviderLinkId,
      quoteRequestId: commitment.quoteRequestId,
      quoteOfferId: commitment.quoteOfferId,
      sourceType: commitment.sourceType,
      title: commitment.title,
      partyName: commitment.partyName,
      partyPhone: commitment.partyPhone,
      totalAmount: commitment.totalAmount.toString(),
      paidAmount: commitment.paidAmount.toString(),
      remainingAmount: remaining.gt(0) ? remaining.toString() : "0",
      dueDate: commitment.dueDate,
      agreementDate: commitment.agreementDate,
      status: commitment.status,
      note: commitment.note,
      createdAt: commitment.createdAt,
      updatedAt: commitment.updatedAt,
    };
  }

  private toPaymentRecordResponse(
    record: FinancialPaymentRecordWithReversal,
  ): FinancialPaymentRecordResponse {
    const reversedById = record.reversedBy?.id ?? null;
    return {
      id: record.id,
      weddingPlanId: record.weddingPlanId,
      financialCommitmentId: record.financialCommitmentId,
      budgetCategoryId: record.budgetCategoryId,
      title: record.title,
      amount: record.amount.toString(),
      entryType: record.entryType,
      financialInstallmentId: record.financialInstallmentId,
      reversalOfId: record.reversalOfId,
      reversedById,
      reversible:
        record.entryType === FinancialPaymentRecordType.PAYMENT &&
        !reversedById,
      paidAt: record.paidAt,
      method: record.method,
      note: record.note,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
    };
  }

  private toInstallmentResponse(
    installment: FinancialInstallment,
  ): FinancialInstallmentResponse {
    return {
      id: installment.id,
      weddingPlanId: installment.weddingPlanId,
      financialCommitmentId: installment.financialCommitmentId,
      budgetCategoryId: installment.budgetCategoryId,
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
