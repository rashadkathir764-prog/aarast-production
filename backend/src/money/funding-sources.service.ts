import {
  BadRequestException,
  Inject,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import {
  FundingSourceKind,
  FundingSourceStatus,
  LoanRepaymentStatus,
  Prisma,
  type LoanRepayment,
} from "@prisma/client";
import { AuthenticatedUser } from "../modules/identity/public/identity-session.types";
import {
  COLLABORATION_PERMISSION_PORT,
  type CollaborationPermissionPort as PermissionService,
  type PlanAccessContext,
} from "../modules/collaboration/public/collaboration-permission.port";
import {
  fundingSourceChangeViolation,
  loanBackToPromisedViolation,
  repaymentOnPromisedLoanViolation,
  fundingSourceDeletionViolation,
  repaymentDeletionViolation,
  repaymentEditViolation,
  repaymentKindViolation,
  repaymentTotalViolation,
} from "../modules/finance/domain/funding-policy";
import { mahrFundingViolation } from "../modules/finance/domain/mahr-policy";
import {
  isPledgeOverdue,
  startOfTodayInRiyadh,
} from "../modules/finance/infrastructure/money-picture";
import {
  deleteFundingSource,
  deleteLoanRepayment,
  findFundingSource,
  findLoanRepayment,
  insertFundingSource,
  insertLoanRepayment,
  listFundingSources,
  lockFundingSource,
  updateFundingSource,
  updateLoanRepayment,
  type FundingSourceWithRepayments,
} from "../modules/finance/infrastructure/funding-sources.repository";
import { raiseFinanceViolation } from "../modules/finance/internal/finance-violation.http";
import {
  runRetryableTransaction,
  runSerializableTransaction,
} from "../platform/database/serializable-transaction";
import { PrismaService } from "../platform/database/prisma.service";
import { requiredMoneyAmount } from "../shared-kernel/money/money";
import {
  CreateFundingSourceDto,
  CreateLoanRepaymentDto,
  UpdateFundingSourceDto,
  UpdateLoanRepaymentDto,
} from "./dto/funding-source.dto";

export interface LoanRepaymentResponse {
  id: string;
  fundingSourceId: string;
  amount: string;
  dueDate: Date | null;
  paidAt: Date | null;
  status: LoanRepaymentStatus;
  note: string | null;
}

export interface FundingSourceResponse {
  id: string;
  weddingPlanId: string;
  kind: FundingSourceKind;
  sourceName: string;
  sourcePhone: string | null;
  /** D108: who gave or promised it. */
  contributorName: string | null;
  amount: string;
  status: FundingSourceStatus;
  receivedAt: Date | null;
  /** PLEDGED money: the day it is expected (the mahr's rest, a promise). */
  expectedAt: Date | null;
  /** D59: promised money whose expected day passed without it arriving («متأخر»). */
  isOverdue: boolean;
  note: string | null;
  createdAt: Date;
  updatedAt: Date;
  /** Loans only: what has been paid back and what is still owed. */
  repaidAmount: string | null;
  outstandingAmount: string | null;
  repayments: LoanRepaymentResponse[];
}

/**
 * Where the wedding money comes from (savings, family support, gifts,
 * loans) and how loans are paid back. Tracking only. This is the plan
 * owner's private money picture: other members, even with money rights, can
 * neither see nor change it.
 */
@Injectable()
export class FundingSourcesService {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(COLLABORATION_PERMISSION_PORT)
    private readonly permissions: PermissionService,
  ) {}

  async findForPlan(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
  ): Promise<FundingSourceResponse[]> {
    return runRetryableTransaction(
      this.prisma,
      async (tx) => {
        const access = await this.permissions.assertMoneyReadableInTransaction(
          tx,
          weddingPlanId,
          currentUser,
        );
        if (!access.isOwner) return [];
        const sources = await listFundingSources(tx, weddingPlanId, true);
        return sources.map(toFundingSourceResponse);
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );
  }

  async create(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    dto: CreateFundingSourceDto,
  ): Promise<FundingSourceResponse> {
    const created = await runSerializableTransaction(this.prisma, async (tx) => {
      const access = await this.permissions.assertMoneyManageableInTransaction(
        tx,
        weddingPlanId,
        currentUser,
      );
      this.requireOwner(access);
      raiseFinanceViolation(
        mahrFundingViolation({
          planPersona: access.plan.persona,
          currentKind: null,
          nextKind: dto.kind,
        }),
      );
      const status = dto.status ?? FundingSourceStatus.RECEIVED;
      return insertFundingSource(tx, weddingPlanId, {
        kind: dto.kind,
        sourceName: this.requiredText(dto.sourceName, "sourceName"),
        sourcePhone: this.optionalText(dto.sourcePhone),
        contributorName: this.optionalText(dto.contributorName),
        amount: this.amount(dto.amount, "amount"),
        status,
        receivedAt: this.receivedAt(status, dto.receivedAt),
        expectedAt: this.optionalDate(dto.expectedAt, "expectedAt"),
        note: this.optionalText(dto.note),
      });
    });
    return toFundingSourceResponse(created);
  }

  async update(
    currentUser: AuthenticatedUser,
    id: string,
    dto: UpdateFundingSourceDto,
  ): Promise<FundingSourceResponse> {
    const updated = await this.withOwnedSource(currentUser, id, async (tx, source, access) => {
      const nextKind = dto.kind ?? source.kind;
      raiseFinanceViolation(
        mahrFundingViolation({
          planPersona: access.plan.persona,
          currentKind: source.kind,
          nextKind,
        }),
      );
      const nextAmount =
        dto.amount !== undefined ? this.amount(dto.amount, "amount") : source.amount;
      raiseFinanceViolation(
        fundingSourceChangeViolation({
          currentKind: source.kind,
          nextKind,
          nextAmount,
          scheduledRepayments: scheduledTotal(source.repayments),
          repaymentCount: source.repayments.length,
        }),
      );
      const nextStatus = dto.status ?? source.status;
      raiseFinanceViolation(
        loanBackToPromisedViolation(source.status, nextStatus, source.repayments),
      );
      return updateFundingSource(tx, id, {
        kind: nextKind,
        ...(dto.sourceName !== undefined
          ? { sourceName: this.requiredText(dto.sourceName, "sourceName") }
          : {}),
        ...(dto.sourcePhone !== undefined
          ? { sourcePhone: this.optionalText(dto.sourcePhone) }
          : {}),
        ...(dto.contributorName !== undefined
          ? { contributorName: this.optionalText(dto.contributorName) }
          : {}),
        amount: nextAmount,
        status: nextStatus,
        receivedAt:
          dto.receivedAt !== undefined || dto.status !== undefined
            ? this.receivedAt(nextStatus, dto.receivedAt, source.receivedAt)
            : source.receivedAt,
        ...(dto.expectedAt !== undefined
          ? { expectedAt: this.optionalDate(dto.expectedAt, "expectedAt") }
          : {}),
        ...(dto.note !== undefined ? { note: this.optionalText(dto.note) } : {}),
      });
    });
    return toFundingSourceResponse(updated);
  }

  async remove(currentUser: AuthenticatedUser, id: string) {
    await this.withOwnedSource(currentUser, id, async (tx, source) => {
      raiseFinanceViolation(fundingSourceDeletionViolation(source.repayments));
      await deleteFundingSource(tx, id);
    });
    return { id, deleted: true as const };
  }

  async addRepayment(
    currentUser: AuthenticatedUser,
    fundingSourceId: string,
    dto: CreateLoanRepaymentDto,
  ): Promise<FundingSourceResponse> {
    const updated = await this.withOwnedSource(
      currentUser,
      fundingSourceId,
      async (tx, source) => {
        raiseFinanceViolation(repaymentKindViolation(source.kind));
        const amount = this.amount(dto.amount, "amount");
        raiseFinanceViolation(
          repaymentTotalViolation(
            scheduledTotal(source.repayments).plus(amount),
            source.amount,
          ),
        );
        await insertLoanRepayment(tx, fundingSourceId, {
          amount,
          dueDate: this.optionalDate(dto.dueDate, "dueDate"),
          note: this.optionalText(dto.note),
        });
        return lockFundingSource(tx, fundingSourceId);
      },
    );
    return toFundingSourceResponse(updated);
  }

  async updateRepayment(
    currentUser: AuthenticatedUser,
    repaymentId: string,
    dto: UpdateLoanRepaymentDto,
  ): Promise<FundingSourceResponse> {
    const repayment = await this.findRepaymentOrThrow(repaymentId);
    const updated = await this.withOwnedSource(
      currentUser,
      repayment.fundingSourceId,
      async (tx, source) => {
        const current = source.repayments.find((item) => item.id === repaymentId);
        if (!current) throw new NotFoundException("Loan repayment not found");
        raiseFinanceViolation(
          repaymentEditViolation(current.status, {
            amountOrDueDate: dto.amount !== undefined || dto.dueDate !== undefined,
            nextStatus: dto.status,
          }),
        );
        raiseFinanceViolation(
          repaymentOnPromisedLoanViolation(source.status, dto.status),
        );
        const nextAmount =
          dto.amount !== undefined ? this.amount(dto.amount, "amount") : current.amount;
        const nextStatus = dto.status ?? current.status;
        const others = source.repayments.filter((item) => item.id !== repaymentId);
        if (nextStatus !== LoanRepaymentStatus.CANCELLED) {
          raiseFinanceViolation(
            repaymentTotalViolation(
              scheduledTotal(others).plus(nextAmount),
              source.amount,
            ),
          );
        }
        await updateLoanRepayment(tx, repaymentId, {
          amount: nextAmount,
          ...(dto.dueDate !== undefined
            ? { dueDate: this.optionalDate(dto.dueDate, "dueDate") }
            : {}),
          status: nextStatus,
          paidAt:
            nextStatus === LoanRepaymentStatus.PAID
              ? (this.optionalDate(dto.paidAt, "paidAt") ?? current.paidAt ?? new Date())
              : null,
          ...(dto.note !== undefined ? { note: this.optionalText(dto.note) } : {}),
        });
        return lockFundingSource(tx, source.id);
      },
      // G15: marking a repayment paid or unpaid is settling the debt, which
      // an archived plan still allows; changing it is not.
      {
        settlement:
          dto.amount === undefined && dto.dueDate === undefined && dto.note === undefined,
      },
    );
    return toFundingSourceResponse(updated);
  }

  async removeRepayment(
    currentUser: AuthenticatedUser,
    repaymentId: string,
  ): Promise<FundingSourceResponse> {
    const repayment = await this.findRepaymentOrThrow(repaymentId);
    const updated = await this.withOwnedSource(
      currentUser,
      repayment.fundingSourceId,
      async (tx, source) => {
        const current = source.repayments.find((item) => item.id === repaymentId);
        if (!current) {
          throw new NotFoundException("Loan repayment not found");
        }
        raiseFinanceViolation(repaymentDeletionViolation(current.status));
        await deleteLoanRepayment(tx, repaymentId);
        return lockFundingSource(tx, source.id);
      },
    );
    return toFundingSourceResponse(updated);
  }

  /**
   * Runs [work] on a funding source the current user owns through its plan,
   * with the plan's money write rights checked and the source row locked.
   */
  private async withOwnedSource<T>(
    currentUser: AuthenticatedUser,
    id: string,
    work: (
      tx: Prisma.TransactionClient,
      source: FundingSourceWithRepayments,
      access: PlanAccessContext,
    ) => Promise<T>,
    options?: { settlement?: boolean },
  ): Promise<T> {
    const existing = await runRetryableTransaction(this.prisma, (tx) =>
      findFundingSource(tx, id),
    );
    if (!existing) throw new NotFoundException("Funding source not found");
    return runSerializableTransaction(this.prisma, async (tx) => {
      const access = await this.permissions.assertMoneyManageableInTransaction(
        tx,
        existing.weddingPlanId,
        currentUser,
        options,
      );
      this.requireOwner(access, "Funding source not found");
      const locked = await lockFundingSource(tx, id);
      return work(tx, locked, access);
    });
  }

  private async findRepaymentOrThrow(id: string) {
    const repayment = await runRetryableTransaction(this.prisma, (tx) =>
      findLoanRepayment(tx, id),
    );
    if (!repayment) throw new NotFoundException("Loan repayment not found");
    return repayment;
  }

  /** Only the plan owner sees or changes funding; others get a plain 404. */
  private requireOwner(
    context: PlanAccessContext,
    message = "Wedding plan not found",
  ) {
    if (!context.isOwner) throw new NotFoundException(message);
  }

  private amount(value: unknown, field: string) {
    const amount = new Prisma.Decimal(requiredMoneyAmount(value, field));
    if (!amount.gt(0)) {
      throw new BadRequestException(`${field} must be greater than zero`);
    }
    return amount;
  }

  /** A received source records when (today by default); a pledge has no date. */
  private receivedAt(
    status: FundingSourceStatus,
    value: string | null | undefined,
    current: Date | null = null,
  ) {
    if (status !== FundingSourceStatus.RECEIVED) return null;
    return this.optionalDate(value, "receivedAt") ?? current ?? new Date();
  }

  private requiredText(value: string, field: string) {
    const normalized = value.trim();
    if (!normalized) throw new BadRequestException(`${field} is required`);
    return normalized;
  }

  private optionalText(value: string | null | undefined) {
    const normalized = value?.trim();
    return normalized ? normalized : null;
  }

  private optionalDate(value: string | null | undefined, field: string) {
    if (value === null || value === undefined || value.trim() === "") return null;
    const date = new Date(value.trim());
    if (Number.isNaN(date.getTime())) {
      throw new BadRequestException(`${field} must be a valid ISO-8601 date`);
    }
    return date;
  }
}

/** Repayments still counted against the loan: planned or paid, not cancelled. */
function scheduledTotal(repayments: readonly LoanRepayment[]) {
  return repayments
    .filter((item) => item.status !== LoanRepaymentStatus.CANCELLED)
    .reduce((sum, item) => sum.plus(item.amount), new Prisma.Decimal(0));
}

function repaidTotal(repayments: readonly LoanRepayment[]) {
  return repayments
    .filter((item) => item.status === LoanRepaymentStatus.PAID)
    .reduce((sum, item) => sum.plus(item.amount), new Prisma.Decimal(0));
}

export function toFundingSourceResponse(
  source: FundingSourceWithRepayments,
): FundingSourceResponse {
  const isLoan = source.kind === FundingSourceKind.LOAN;
  const repaid = repaidTotal(source.repayments);
  return {
    id: source.id,
    weddingPlanId: source.weddingPlanId,
    kind: source.kind,
    sourceName: source.sourceName,
    sourcePhone: source.sourcePhone,
    contributorName: source.contributorName,
    amount: source.amount.toString(),
    status: source.status,
    receivedAt: source.receivedAt,
    expectedAt: source.expectedAt,
    isOverdue: isPledgeOverdue(source, startOfTodayInRiyadh(new Date())),
    note: source.note,
    createdAt: source.createdAt,
    updatedAt: source.updatedAt,
    repaidAmount: isLoan ? repaid.toString() : null,
    outstandingAmount: isLoan ? source.amount.minus(repaid).toString() : null,
    repayments: source.repayments.map((item) => ({
      id: item.id,
      fundingSourceId: item.fundingSourceId,
      amount: item.amount.toString(),
      dueDate: item.dueDate,
      paidAt: item.paidAt,
      status: item.status,
      note: item.note,
    })),
  };
}
