import {
  BadRequestException,
  ConflictException,
  Inject,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import {
  ContributionAction,
  ContributionEntityType,
  ContributionPermission,
  ContributionSection,
  CostPaymentType,
  PaymentScheduleStatus,
  Prisma,
  ProviderStatus,
  QuoteOfferStatus,
  WeddingCostStatus,
} from "@prisma/client";
import { AuthenticatedUser } from "../modules/identity/public/identity-session.types";
import {
  COLLABORATION_HISTORY_PORT,
  type CollaborationHistoryPort as ContributionHistoryService,
} from "../modules/collaboration/public/collaboration-history.port";
import { buildContributionSnapshot } from "../modules/collaboration/public/contribution-snapshot.builder";
import {
  COLLABORATION_SCOPE_PORT,
  type CollaborationScopePort as ContributorScopeService,
} from "../modules/collaboration/public/collaboration-scope.port";
import { paymentsRecordedTotal } from "../platform/observability/metrics";
import {
  runRetryableTransaction,
  runSerializableTransaction,
} from "../platform/database/serializable-transaction";
import { requiredMoneyAmount } from "../shared-kernel/money/money";
import { PrismaService } from "../platform/database/prisma.service";
import {
  COLLABORATION_PERMISSION_PORT,
  type CollaborationPermissionPort as PermissionService,
  type PlanAccessContext,
} from "../modules/collaboration/public/collaboration-permission.port";
import { CreateCostPaymentDto } from "./dto/create-cost-payment.dto";
import { CreatePaymentScheduleDto } from "./dto/create-payment-schedule.dto";
import { CreateWeddingCostDto } from "./dto/create-wedding-cost.dto";
import { ListCostPaymentsQueryDto } from "./dto/list-cost-payments-query.dto";
import { ListCostsQueryDto } from "./dto/list-costs-query.dto";
import { PayPaymentScheduleDto } from "./dto/pay-payment-schedule.dto";
import { ReverseCostPaymentDto } from "./dto/reverse-cost-payment.dto";
import { UpdatePaymentScheduleDto } from "./dto/update-payment-schedule.dto";
import { UpdateWeddingCostDto } from "./dto/update-wedding-cost.dto";
import {
  toWeddingCostResponse,
  weddingCostResponseInclude,
  type WeddingCostResponse,
} from "../modules/finance/public/wedding-cost.presenter";

const paymentInclude = Prisma.validator<Prisma.CostPaymentInclude>()({
  weddingCost: {
    include: {
      budgetCategory: { select: { name: true } },
      provider: { select: { businessName: true } },
    },
  },
  reversedBy: { select: { id: true } },
});

const scheduleInclude = Prisma.validator<Prisma.PaymentScheduleInclude>()({
  weddingCost: {
    include: {
      budgetCategory: { select: { name: true } },
      provider: { select: { businessName: true } },
    },
  },
});

type PaymentWithDetails = Prisma.CostPaymentGetPayload<{
  include: typeof paymentInclude;
}>;
type ScheduleWithDetails = Prisma.PaymentScheduleGetPayload<{
  include: typeof scheduleInclude;
}>;
type Tx = Prisma.TransactionClient;

export interface PaginatedResponse<T> {
  items: T[];
  page: number;
  pageSize: number;
  total: number;
  totalPages: number;
}

export interface CostPaymentResponse {
  id: string;
  costId: string;
  weddingPlanId: string;
  budgetCategoryId: string;
  categoryName: string;
  providerId: string | null;
  providerName: string | null;
  costTitle: string;
  amount: string;
  entryType: CostPaymentType;
  paymentScheduleId: string | null;
  reversalOfId: string | null;
  reversedById: string | null;
  reversible: boolean;
  paidAt: Date;
  method: string | null;
  note: string | null;
  createdAt: Date;
}

export interface PaymentScheduleResponse {
  id: string;
  costId: string;
  weddingCostId: string;
  weddingPlanId: string;
  budgetCategoryId: string;
  categoryName: string;
  providerId: string | null;
  providerName: string | null;
  costTitle: string;
  amount: string;
  dueDate: Date;
  paidAt: Date | null;
  status: PaymentScheduleStatus;
  isOverdue: boolean;
  note: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface SchedulePaymentResponse {
  payment: CostPaymentResponse;
  schedule: PaymentScheduleResponse;
}

interface NormalizedCounterparty {
  providerId: string | null;
  quoteOfferId: string | null;
  partyName: string | null;
  partyPhone: string | null;
}

@Injectable()
export class WeddingCostsService {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(COLLABORATION_PERMISSION_PORT)
    private readonly permissions: PermissionService,
    @Inject(COLLABORATION_SCOPE_PORT)
    private readonly contributorScope?: ContributorScopeService,
    @Inject(COLLABORATION_HISTORY_PORT)
    private readonly contributionHistory?: ContributionHistoryService,
  ) {}

  async createCost(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    dto: CreateWeddingCostDto,
  ): Promise<WeddingCostResponse> {
    const totalAmount = this.positiveAmount(dto.totalAmount, "totalAmount");
    const initialPayment = this.optionalAmount(
      dto.initialPaymentAmount,
      "initialPaymentAmount",
    );
    if (initialPayment.gt(totalAmount)) {
      throw new BadRequestException(
        "initialPaymentAmount cannot exceed totalAmount",
      );
    }

    try {
      const cost = await runSerializableTransaction(this.prisma, async (tx) => {
        const context =
          await this.permissions.assertMoneyManageableInTransaction(
            tx,
            weddingPlanId,
            currentUser,
          );
        await this.lockCounterpartyReferences(tx, {
          providerIds: [dto.providerId],
          quoteOfferIds: [dto.quoteOfferId],
        });
        await this.assertScopedCategoryInTransaction(
          tx,
          context,
          dto.budgetCategoryId.trim(),
        );
        await this.assertCategory(tx, dto.budgetCategoryId, weddingPlanId);
        const counterparty = await this.normalizeCounterparty(tx, {
          weddingPlanId,
          planCurrency: context.plan.currency,
          totalAmount,
          providerId: dto.providerId,
          quoteOfferId: dto.quoteOfferId,
          partyName: dto.partyName,
          partyPhone: dto.partyPhone,
        });
        const created = await tx.weddingCost.create({
          data: {
            weddingPlanId,
            budgetCategoryId: dto.budgetCategoryId.trim(),
            ...counterparty,
            title: this.requiredText(dto.title, "title"),
            totalAmount,
            paidAmount: initialPayment,
            agreementDate: this.optionalDate(
              dto.agreementDate,
              "agreementDate",
            ),
            status: this.deriveStatus(totalAmount, initialPayment),
            note: this.optionalText(dto.note),
          },
        });
        if (initialPayment.gt(0)) {
          await tx.costPayment.create({
            data: {
              weddingCostId: created.id,
              amount: initialPayment,
              paidAt: created.agreementDate ?? new Date(),
              note: "دفعة أولى",
            },
          });
        }
        await this.recordMoneyEvent(tx, context, {
          entityType: ContributionEntityType.WEDDING_COST,
          entityId: created.id,
          action: ContributionAction.CREATED,
          dedupeKey: `money:wedding-cost:${created.id}:created`,
          source: {
            title: created.title,
            currency: context.plan.currency,
            totalAmount: created.totalAmount,
            paidAmount: created.paidAmount,
            status: created.status,
            relevantDate: created.agreementDate,
          },
          occurredAt: created.createdAt,
        });
        return tx.weddingCost.findUniqueOrThrow({
          where: { id: created.id },
          include: weddingCostResponseInclude,
        });
      });
      if (initialPayment.gt(0)) paymentsRecordedTotal.inc();
      return toWeddingCostResponse(cost);
    } catch (error) {
      this.rethrowKnownPrismaError(error);
    }
  }

  async listCosts(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    query: ListCostsQueryDto,
  ): Promise<PaginatedResponse<WeddingCostResponse>> {
    const page = query.page ?? 1;
    const pageSize = query.limit ?? 50;
    const search = query.search?.trim();
    return runRetryableTransaction(
      this.prisma,
      async (tx) => {
        const access =
          await this.permissions.assertMoneyReadableInTransaction(
            tx,
            weddingPlanId,
            currentUser,
          );
        const scopedCostIds = await this.scopedCostIdsInTransaction(
          tx,
          access,
        );
        const where: Prisma.WeddingCostWhereInput = {
          weddingPlanId,
          weddingPlan: {
            is: this.permissions.livePlanAuthorizationWhere(
              access,
              currentUser.id,
              ["canViewMoney"],
            ),
          },
          ...(scopedCostIds ? { id: { in: scopedCostIds } } : {}),
          ...(query.status ? { status: query.status } : {}),
          ...(query.categoryId?.trim()
            ? { budgetCategoryId: query.categoryId.trim() }
            : {}),
          ...(search
            ? {
                OR: [
                  { title: { contains: search, mode: "insensitive" } },
                  { partyName: { contains: search, mode: "insensitive" } },
                  {
                    provider: {
                      businessName: { contains: search, mode: "insensitive" },
                    },
                  },
                  {
                    budgetCategory: {
                      name: { contains: search, mode: "insensitive" },
                    },
                  },
                ],
              }
            : {}),
        };
        const [costs, total] = await Promise.all([
          tx.weddingCost.findMany({
            where,
            include: weddingCostResponseInclude,
            orderBy: [{ createdAt: "desc" }, { id: "desc" }],
            skip: (page - 1) * pageSize,
            take: pageSize,
          }),
          tx.weddingCost.count({ where }),
        ]);
        return {
          items: costs.map(toWeddingCostResponse),
          page,
          pageSize,
          total,
          totalPages: total === 0 ? 0 : Math.ceil(total / pageSize),
        };
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );
  }

  async getCost(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<WeddingCostResponse> {
    const identity = await this.costIdentityOrThrow(id);
    return runRetryableTransaction(
      this.prisma,
      async (tx) => {
        const access =
          await this.permissions.assertMoneyReadableInTransaction(
            tx,
            identity.weddingPlanId,
            currentUser,
          );
        const scopedCostIds = await this.scopedCostIdsInTransaction(
          tx,
          access,
        );
        if (scopedCostIds && !scopedCostIds.includes(id)) {
          throw new NotFoundException("Wedding cost not found");
        }
        const cost = await tx.weddingCost.findFirst({
          where: {
            id,
            weddingPlanId: identity.weddingPlanId,
            weddingPlan: {
              is: this.permissions.livePlanAuthorizationWhere(
                access,
                currentUser.id,
                ["canViewMoney"],
              ),
            },
          },
          include: weddingCostResponseInclude,
        });
        if (!cost) throw new NotFoundException("Wedding cost not found");
        return toWeddingCostResponse(cost);
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );
  }

  async updateCost(
    currentUser: AuthenticatedUser,
    id: string,
    dto: UpdateWeddingCostDto,
  ): Promise<WeddingCostResponse> {
    const current = await this.costOrThrow(id);

    try {
      return await runSerializableTransaction(this.prisma, async (tx) => {
        const context =
          await this.permissions.assertMoneyManageableInTransaction(
            tx,
            current.weddingPlanId,
            currentUser,
          );
        await this.assertScopedCostInTransaction(tx, context, id);
        const snapshot = await tx.weddingCost.findUnique({ where: { id } });
        if (
          !snapshot ||
          snapshot.weddingPlanId !== current.weddingPlanId
        ) {
          throw new NotFoundException("Wedding cost not found");
        }
        const targetProviderId =
          dto.providerId === undefined ? snapshot.providerId : dto.providerId;
        const targetQuoteOfferId =
          dto.quoteOfferId === undefined
            ? snapshot.quoteOfferId
            : dto.quoteOfferId;
        await this.lockCounterpartyReferences(tx, {
          providerIds: [snapshot.providerId, targetProviderId],
          quoteOfferIds: [snapshot.quoteOfferId, targetQuoteOfferId],
        });
        const targetBudgetCategoryId =
          dto.budgetCategoryId === undefined
            ? snapshot.budgetCategoryId
            : dto.budgetCategoryId.trim();
        await this.assertScopedCategoryInTransaction(
          tx,
          context,
          targetBudgetCategoryId,
        );
        await this.assertCategory(
          tx,
          targetBudgetCategoryId,
          snapshot.weddingPlanId,
          [snapshot.budgetCategoryId],
        );
        const locked = await this.lockCost(tx, id);
        if (
          locked.weddingPlanId !== snapshot.weddingPlanId ||
          locked.budgetCategoryId !== snapshot.budgetCategoryId ||
          locked.providerId !== snapshot.providerId ||
          locked.quoteOfferId !== snapshot.quoteOfferId
        ) {
          throw new ConflictException(
            "Wedding cost references changed concurrently; retry the request",
          );
        }
        if (locked.status === WeddingCostStatus.CANCELLED) {
          throw new ConflictException("Cancelled costs cannot be edited");
        }
        const totalAmount =
          dto.totalAmount === undefined
            ? locked.totalAmount
            : this.positiveAmount(dto.totalAmount, "totalAmount");
        if (totalAmount.lt(locked.paidAmount)) {
          throw new BadRequestException(
            "totalAmount cannot be less than paidAmount",
          );
        }
        const budgetCategoryId =
          dto.budgetCategoryId === undefined
            ? locked.budgetCategoryId
            : dto.budgetCategoryId.trim();
        const counterparty = await this.normalizeCounterparty(tx, {
          weddingPlanId: locked.weddingPlanId,
          planCurrency: context.plan.currency,
          totalAmount,
          providerId:
            dto.providerId === undefined ? locked.providerId : dto.providerId,
          quoteOfferId:
            dto.quoteOfferId === undefined
              ? locked.quoteOfferId
              : dto.quoteOfferId,
          partyName:
            dto.partyName === undefined ? locked.partyName : dto.partyName,
          partyPhone:
            dto.partyPhone === undefined ? locked.partyPhone : dto.partyPhone,
          currentCostId: id,
        });
        const status = this.deriveStatus(totalAmount, locked.paidAmount);
        const updated = await tx.weddingCost.update({
          where: { id },
          data: {
            budgetCategoryId,
            ...counterparty,
            ...(dto.title === undefined
              ? {}
              : { title: this.requiredText(dto.title, "title") }),
            totalAmount,
            status,
            ...(dto.agreementDate === undefined
              ? {}
              : {
                  agreementDate: this.optionalDate(
                    dto.agreementDate,
                    "agreementDate",
                  ),
                }),
            ...(dto.note === undefined
              ? {}
              : { note: this.optionalText(dto.note) }),
          },
          include: weddingCostResponseInclude,
        });
        await this.cancelPendingSchedulesWhenPaid(tx, id, status);
        await this.recordMoneyEvent(tx, context, {
          entityType: ContributionEntityType.WEDDING_COST,
          entityId: updated.id,
          action: ContributionAction.UPDATED,
          dedupeKey: `money:wedding-cost:${updated.id}:updated:${updated.updatedAt.toISOString()}`,
          source: {
            title: updated.title,
            categoryLabel: updated.budgetCategory.name,
            currency: context.plan.currency,
            totalAmount: updated.totalAmount,
            paidAmount: updated.paidAmount,
            status: updated.status,
            relevantDate: updated.agreementDate,
          },
          occurredAt: updated.updatedAt,
        });
        return toWeddingCostResponse(updated);
      });
    } catch (error) {
      this.rethrowKnownPrismaError(error);
    }
  }

  async deleteCost(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<{ deleted: true }> {
    const current = await this.costOrThrow(id);
    await runSerializableTransaction(this.prisma, async (tx) => {
      const context = await this.permissions.assertMoneyManageableInTransaction(
        tx,
        current.weddingPlanId,
        currentUser,
      );
      await this.assertScopedCostInTransaction(tx, context, id);
      const locked = await this.lockCost(tx, id);
      const paymentsCount = await tx.costPayment.count({
        where: { weddingCostId: id },
      });
      if (paymentsCount > 0 || !locked.paidAmount.isZero()) {
        throw new ConflictException(
          "A cost with payment history cannot be deleted",
        );
      }
      await this.recordMoneyEvent(tx, context, {
        entityType: ContributionEntityType.WEDDING_COST,
        entityId: locked.id,
        action: ContributionAction.DELETED,
        dedupeKey: `money:wedding-cost:${locked.id}:deleted`,
        source: {
          title: locked.title,
          currency: context.plan.currency,
          totalAmount: locked.totalAmount,
          paidAmount: locked.paidAmount,
          status: locked.status,
          relevantDate: locked.agreementDate,
        },
      });
      await tx.weddingCost.delete({ where: { id } });
    });
    return { deleted: true };
  }

  async cancelCost(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<WeddingCostResponse> {
    const current = await this.costOrThrow(id);
    return runSerializableTransaction(this.prisma, async (tx) => {
      const context = await this.permissions.assertMoneyManageableInTransaction(
        tx,
        current.weddingPlanId,
        currentUser,
      );
      await this.assertScopedCostInTransaction(tx, context, id);
      const locked = await this.lockCost(tx, id);
      if (locked.status === WeddingCostStatus.CANCELLED) {
        return toWeddingCostResponse(
          await tx.weddingCost.findUniqueOrThrow({
            where: { id },
            include: weddingCostResponseInclude,
          }),
        );
      }
      if (!locked.paidAmount.isZero()) {
        throw new ConflictException(
          "Reverse the active payments before cancelling this cost",
        );
      }
      await tx.paymentSchedule.updateMany({
        where: { weddingCostId: id, status: PaymentScheduleStatus.PENDING },
        data: { status: PaymentScheduleStatus.CANCELLED },
      });
      const cancelled = await tx.weddingCost.update({
        where: { id },
        data: { status: WeddingCostStatus.CANCELLED },
        include: weddingCostResponseInclude,
      });
      await this.recordMoneyEvent(tx, context, {
        entityType: ContributionEntityType.WEDDING_COST,
        entityId: cancelled.id,
        action: ContributionAction.STATUS_CHANGED,
        dedupeKey: `money:wedding-cost:${cancelled.id}:cancelled`,
        source: {
          title: cancelled.title,
          categoryLabel: cancelled.budgetCategory.name,
          currency: context.plan.currency,
          totalAmount: cancelled.totalAmount,
          paidAmount: cancelled.paidAmount,
          status: cancelled.status,
          relevantDate: cancelled.updatedAt,
        },
        occurredAt: cancelled.updatedAt,
      });
      return toWeddingCostResponse(cancelled);
    });
  }

  async createPayment(
    currentUser: AuthenticatedUser,
    costId: string,
    dto: CreateCostPaymentDto,
  ): Promise<CostPaymentResponse> {
    const current = await this.costOrThrow(costId);
    const response = await runSerializableTransaction(
      this.prisma,
      async (tx) => {
        const context = await this.permissions.assertMoneyManageableInTransaction(
          tx,
          current.weddingPlanId,
          currentUser,
        );
        await this.assertScopedCostInTransaction(tx, context, costId);
        const amount = this.positiveAmount(dto.amount, "amount");
        const cost = await this.lockCost(tx, costId);
        this.assertCostPayable(cost.status);
        const remaining = cost.totalAmount.minus(cost.paidAmount);
        if (amount.gt(remaining)) {
          throw new BadRequestException(
            "Payment amount cannot exceed the remaining cost",
          );
        }
        const payment = await tx.costPayment.create({
          data: {
            weddingCostId: costId,
            amount,
            paidAt: this.optionalDate(dto.paidAt, "paidAt") ?? new Date(),
            method: this.optionalText(dto.method),
            note: this.optionalText(dto.note),
          },
          include: paymentInclude,
        });
        const paidAmount = cost.paidAmount.plus(amount);
        const status = this.deriveStatus(cost.totalAmount, paidAmount);
        await tx.weddingCost.update({
          where: { id: costId },
          data: {
            paidAmount,
            status,
          },
        });
        await this.cancelPendingSchedulesWhenPaid(tx, costId, status);
        await this.recordMoneyEvent(tx, context, {
          entityType: ContributionEntityType.WEDDING_COST,
          entityId: cost.id,
          action: ContributionAction.PAYMENT_RECORDED,
          dedupeKey: `money:wedding-cost:${cost.id}:payment:${payment.id}`,
          source: {
            title: cost.title,
            currency: context.plan.currency,
            totalAmount: cost.totalAmount,
            paidAmount,
            amount: payment.amount,
            status,
            relevantDate: payment.paidAt,
          },
          occurredAt: payment.paidAt,
        });
        return this.paymentResponse(payment);
      },
    );
    paymentsRecordedTotal.inc();
    return response;
  }

  async listPaymentsForCost(
    currentUser: AuthenticatedUser,
    costId: string,
  ): Promise<CostPaymentResponse[]> {
    const identity = await this.costIdentityOrThrow(costId);
    return runRetryableTransaction(
      this.prisma,
      async (tx) => {
        const access =
          await this.permissions.assertMoneyReadableInTransaction(
            tx,
            identity.weddingPlanId,
            currentUser,
          );
        const scopedCostIds = await this.scopedCostIdsInTransaction(
          tx,
          access,
        );
        if (scopedCostIds && !scopedCostIds.includes(costId)) {
          throw new NotFoundException("Wedding cost not found");
        }
        const payments = await tx.costPayment.findMany({
          where: {
            weddingCostId: costId,
            weddingCost: {
              weddingPlanId: identity.weddingPlanId,
              weddingPlan: {
                is: this.permissions.livePlanAuthorizationWhere(
                  access,
                  currentUser.id,
                  ["canViewMoney"],
                ),
              },
              ...(scopedCostIds ? { id: { in: scopedCostIds } } : {}),
            },
          },
          include: paymentInclude,
          orderBy: [{ paidAt: "desc" }, { createdAt: "desc" }],
        });
        return payments.map((payment) => this.paymentResponse(payment));
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );
  }

  async listPaymentsForPlan(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    query: ListCostPaymentsQueryDto,
  ): Promise<PaginatedResponse<CostPaymentResponse>> {
    const page = query.page ?? 1;
    const pageSize = query.limit ?? 50;
    return runRetryableTransaction(
      this.prisma,
      async (tx) => {
        const access =
          await this.permissions.assertMoneyReadableInTransaction(
            tx,
            weddingPlanId,
            currentUser,
          );
        const scopedCostIds = await this.scopedCostIdsInTransaction(
          tx,
          access,
        );
        const where: Prisma.CostPaymentWhereInput = {
          weddingCost: {
            weddingPlanId,
            weddingPlan: {
              is: this.permissions.livePlanAuthorizationWhere(
                access,
                currentUser.id,
                ["canViewMoney"],
              ),
            },
            ...(scopedCostIds ? { id: { in: scopedCostIds } } : {}),
          },
        };
        const [payments, total] = await Promise.all([
          tx.costPayment.findMany({
            where,
            include: paymentInclude,
            orderBy: [{ paidAt: "desc" }, { createdAt: "desc" }],
            skip: (page - 1) * pageSize,
            take: pageSize,
          }),
          tx.costPayment.count({ where }),
        ]);
        return {
          items: payments.map((payment) => this.paymentResponse(payment)),
          page,
          pageSize,
          total,
          totalPages: total === 0 ? 0 : Math.ceil(total / pageSize),
        };
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );
  }

  async getPayment(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<CostPaymentResponse> {
    const identity = await this.paymentIdentityOrThrow(id);
    return runRetryableTransaction(
      this.prisma,
      async (tx) => {
        const access =
          await this.permissions.assertMoneyReadableInTransaction(
            tx,
            identity.weddingPlanId,
            currentUser,
          );
        const scopedCostIds = await this.scopedCostIdsInTransaction(
          tx,
          access,
        );
        const payment = await tx.costPayment.findFirst({
          where: {
            id,
            weddingCostId: identity.weddingCostId,
            weddingCost: {
              weddingPlanId: identity.weddingPlanId,
              weddingPlan: {
                is: this.permissions.livePlanAuthorizationWhere(
                  access,
                  currentUser.id,
                  ["canViewMoney"],
                ),
              },
              ...(scopedCostIds ? { id: { in: scopedCostIds } } : {}),
            },
          },
          include: paymentInclude,
        });
        if (!payment) throw new NotFoundException("Cost payment not found");
        return this.paymentResponse(payment);
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );
  }

  async reversePayment(
    currentUser: AuthenticatedUser,
    id: string,
    dto: ReverseCostPaymentDto,
  ): Promise<CostPaymentResponse> {
    const current = await this.paymentOrThrow(id);
    return runSerializableTransaction(this.prisma, async (tx) => {
      const context = await this.permissions.assertMoneyManageableInTransaction(
        tx,
        current.weddingCost.weddingPlanId,
        currentUser,
      );
      await this.assertScopedCostInTransaction(
        tx,
        context,
        current.weddingCostId,
      );
      const cost = await this.lockCost(tx, current.weddingCostId);
      await this.lockPayment(tx, id);
      const payment = await tx.costPayment.findUnique({
        where: { id },
        include: paymentInclude,
      });
      if (!payment) throw new NotFoundException("Cost payment not found");
      if (payment.entryType !== CostPaymentType.PAYMENT) {
        throw new ConflictException("A reversal entry cannot be reversed");
      }
      if (payment.reversedBy) {
        throw new ConflictException("Payment has already been reversed");
      }
      if (payment.amount.gt(cost.paidAmount)) {
        throw new ConflictException("Payment ledger is inconsistent");
      }
      const paidAmount = cost.paidAmount.minus(payment.amount);
      const reversal = await tx.costPayment.create({
        data: {
          weddingCostId: cost.id,
          amount: payment.amount,
          entryType: CostPaymentType.REVERSAL,
          paidAt: new Date(),
          reversalOfId: payment.id,
          note: this.requiredText(dto.reason, "reason"),
        },
        include: paymentInclude,
      });
      await tx.weddingCost.update({
        where: { id: cost.id },
        data: {
          paidAmount,
          status: this.deriveStatus(cost.totalAmount, paidAmount),
        },
      });
      if (payment.paymentScheduleId) {
        await tx.paymentSchedule.update({
          where: { id: payment.paymentScheduleId },
          data: { status: PaymentScheduleStatus.PENDING, paidAt: null },
        });
      }
      await this.recordMoneyEvent(tx, context, {
        entityType: ContributionEntityType.WEDDING_COST,
        entityId: cost.id,
        action: ContributionAction.PAYMENT_REVERSED,
        dedupeKey: `money:wedding-cost:${cost.id}:reversal:${reversal.id}`,
        source: {
          title: cost.title,
          currency: context.plan.currency,
          totalAmount: cost.totalAmount,
          paidAmount,
          amount: reversal.amount,
          status: this.deriveStatus(cost.totalAmount, paidAmount),
          relevantDate: reversal.paidAt,
        },
        occurredAt: reversal.paidAt,
      });
      return this.paymentResponse(reversal);
    });
  }

  async createSchedule(
    currentUser: AuthenticatedUser,
    costId: string,
    dto: CreatePaymentScheduleDto,
  ): Promise<PaymentScheduleResponse> {
    const current = await this.costOrThrow(costId);
    return runSerializableTransaction(this.prisma, async (tx) => {
      const context = await this.permissions.assertMoneyManageableInTransaction(
        tx,
        current.weddingPlanId,
        currentUser,
      );
      await this.assertScopedCostInTransaction(tx, context, costId);
      const amount = this.positiveAmount(dto.amount, "amount");
      const cost = await this.lockCost(tx, costId);
      this.assertCostPayable(cost.status);
      if (amount.gt(cost.totalAmount.minus(cost.paidAmount))) {
        throw new BadRequestException(
          "Payment schedule amount cannot exceed the remaining cost",
        );
      }
      const schedule = await tx.paymentSchedule.create({
        data: {
          weddingCostId: costId,
          amount,
          dueDate: this.requiredDate(dto.dueDate, "dueDate"),
          note: this.optionalText(dto.note),
        },
        include: scheduleInclude,
      });
      await this.recordMoneyEvent(tx, context, {
        entityType: ContributionEntityType.PAYMENT_SCHEDULE,
        entityId: schedule.id,
        action: ContributionAction.CREATED,
        dedupeKey: `money:payment-schedule:${schedule.id}:created`,
        source: {
          title: schedule.weddingCost.title,
          categoryLabel: schedule.weddingCost.budgetCategory.name,
          currency: context.plan.currency,
          amount: schedule.amount,
          status: schedule.status,
          relevantDate: schedule.dueDate,
        },
        occurredAt: schedule.createdAt,
      });
      return this.scheduleResponse(schedule);
    });
  }

  async listSchedulesForCost(
    currentUser: AuthenticatedUser,
    costId: string,
  ): Promise<PaymentScheduleResponse[]> {
    const identity = await this.costIdentityOrThrow(costId);
    return runRetryableTransaction(
      this.prisma,
      async (tx) => {
        const access =
          await this.permissions.assertMoneyReadableInTransaction(
            tx,
            identity.weddingPlanId,
            currentUser,
          );
        const scopedCostIds = await this.scopedCostIdsInTransaction(
          tx,
          access,
        );
        if (scopedCostIds && !scopedCostIds.includes(costId)) {
          throw new NotFoundException("Wedding cost not found");
        }
        const schedules = await tx.paymentSchedule.findMany({
          where: {
            weddingCostId: costId,
            weddingCost: {
              weddingPlanId: identity.weddingPlanId,
              weddingPlan: {
                is: this.permissions.livePlanAuthorizationWhere(
                  access,
                  currentUser.id,
                  ["canViewMoney"],
                ),
              },
              ...(scopedCostIds ? { id: { in: scopedCostIds } } : {}),
            },
          },
          include: scheduleInclude,
          orderBy: [{ dueDate: "asc" }, { createdAt: "asc" }],
        });
        return schedules.map((schedule) => this.scheduleResponse(schedule));
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );
  }

  async listDueSchedulesForPlan(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
  ): Promise<PaymentScheduleResponse[]> {
    const through = new Date(
      this.startOfTodayInRiyadh().getTime() + 30 * 24 * 60 * 60 * 1000,
    );
    return runRetryableTransaction(
      this.prisma,
      async (tx) => {
        const access =
          await this.permissions.assertMoneyReadableInTransaction(
            tx,
            weddingPlanId,
            currentUser,
          );
        const scopedCostIds = await this.scopedCostIdsInTransaction(
          tx,
          access,
        );
        const schedules = await tx.paymentSchedule.findMany({
          where: {
            weddingCost: {
              weddingPlanId,
              weddingPlan: {
                is: this.permissions.livePlanAuthorizationWhere(
                  access,
                  currentUser.id,
                  ["canViewMoney"],
                ),
              },
              ...(scopedCostIds ? { id: { in: scopedCostIds } } : {}),
              status: { not: WeddingCostStatus.CANCELLED },
            },
            status: PaymentScheduleStatus.PENDING,
            dueDate: { lte: through },
          },
          include: scheduleInclude,
          orderBy: [{ dueDate: "asc" }, { createdAt: "asc" }],
        });
        return schedules.map((schedule) => this.scheduleResponse(schedule));
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );
  }

  async updateSchedule(
    currentUser: AuthenticatedUser,
    id: string,
    dto: UpdatePaymentScheduleDto,
  ): Promise<PaymentScheduleResponse> {
    const current = await this.scheduleOrThrow(id);
    return runSerializableTransaction(this.prisma, async (tx) => {
      const context = await this.permissions.assertMoneyManageableInTransaction(
        tx,
        current.weddingCost.weddingPlanId,
        currentUser,
      );
      await this.assertScopedCostInTransaction(
        tx,
        context,
        current.weddingCostId,
      );
      const cost = await this.lockCost(tx, current.weddingCostId);
      await this.lockSchedule(tx, id);
      const schedule = await tx.paymentSchedule.findUniqueOrThrow({
        where: { id },
      });
      if (schedule.status !== PaymentScheduleStatus.PENDING) {
        throw new ConflictException(
          "Only pending payment schedules can be edited",
        );
      }
      const paymentHistory = await tx.costPayment.count({
        where: { paymentScheduleId: id },
      });
      if (paymentHistory > 0 && dto.amount !== undefined) {
        throw new ConflictException(
          "The amount of a payment schedule with ledger history cannot be changed",
        );
      }
      const amount =
        dto.amount === undefined
          ? schedule.amount
          : this.positiveAmount(dto.amount, "amount");
      this.assertCostPayable(cost.status);
      if (amount.gt(cost.totalAmount.minus(cost.paidAmount))) {
        throw new BadRequestException(
          "Payment schedule amount cannot exceed the remaining cost",
        );
      }
      const updated = await tx.paymentSchedule.update({
        where: { id },
        data: {
          amount,
          ...(dto.dueDate === undefined
            ? {}
            : { dueDate: this.requiredDate(dto.dueDate, "dueDate") }),
          ...(dto.note === undefined
            ? {}
            : { note: this.optionalText(dto.note) }),
        },
        include: scheduleInclude,
      });
      await this.recordMoneyEvent(tx, context, {
        entityType: ContributionEntityType.PAYMENT_SCHEDULE,
        entityId: updated.id,
        action: ContributionAction.UPDATED,
        dedupeKey: `money:payment-schedule:${updated.id}:updated:${updated.updatedAt.toISOString()}`,
        source: {
          title: updated.weddingCost.title,
          categoryLabel: updated.weddingCost.budgetCategory.name,
          currency: context.plan.currency,
          amount: updated.amount,
          status: updated.status,
          relevantDate: updated.dueDate,
        },
        occurredAt: updated.updatedAt,
      });
      return this.scheduleResponse(updated);
    });
  }

  async deleteSchedule(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<{ deleted: true }> {
    const current = await this.scheduleOrThrow(id);
    await runSerializableTransaction(this.prisma, async (tx) => {
      const context = await this.permissions.assertMoneyManageableInTransaction(
        tx,
        current.weddingCost.weddingPlanId,
        currentUser,
      );
      await this.assertScopedCostInTransaction(
        tx,
        context,
        current.weddingCostId,
      );
      await this.lockCost(tx, current.weddingCostId);
      await this.lockSchedule(tx, id);
      const schedule = await tx.paymentSchedule.findUniqueOrThrow({
        where: { id },
      });
      if (schedule.status !== PaymentScheduleStatus.PENDING) {
        throw new ConflictException(
          "Only pending payment schedules can be deleted",
        );
      }
      const paymentHistory = await tx.costPayment.count({
        where: { paymentScheduleId: id },
      });
      if (paymentHistory > 0) {
        throw new ConflictException(
          "A payment schedule with ledger history cannot be deleted",
        );
      }
      await this.recordMoneyEvent(tx, context, {
        entityType: ContributionEntityType.PAYMENT_SCHEDULE,
        entityId: schedule.id,
        action: ContributionAction.DELETED,
        dedupeKey: `money:payment-schedule:${schedule.id}:deleted`,
        source: {
          title: current.weddingCost.title,
          categoryLabel: current.weddingCost.budgetCategory.name,
          currency: context.plan.currency,
          amount: schedule.amount,
          status: schedule.status,
          relevantDate: schedule.dueDate,
        },
      });
      await tx.paymentSchedule.delete({ where: { id } });
    });
    return { deleted: true };
  }

  async cancelSchedule(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<PaymentScheduleResponse> {
    const current = await this.scheduleOrThrow(id);
    return runSerializableTransaction(this.prisma, async (tx) => {
      const context = await this.permissions.assertMoneyManageableInTransaction(
        tx,
        current.weddingCost.weddingPlanId,
        currentUser,
      );
      await this.assertScopedCostInTransaction(
        tx,
        context,
        current.weddingCostId,
      );
      await this.lockCost(tx, current.weddingCostId);
      await this.lockSchedule(tx, id);
      const schedule = await tx.paymentSchedule.findUniqueOrThrow({
        where: { id },
      });
      if (schedule.status === PaymentScheduleStatus.CANCELLED) {
        return this.scheduleResponse(
          await tx.paymentSchedule.findUniqueOrThrow({
            where: { id },
            include: scheduleInclude,
          }),
        );
      }
      if (schedule.status !== PaymentScheduleStatus.PENDING) {
        throw new ConflictException(
          "Reverse the payment before cancelling this payment schedule",
        );
      }
      const activePayment = await tx.costPayment.findFirst({
        where: {
          paymentScheduleId: id,
          entryType: CostPaymentType.PAYMENT,
          reversedBy: null,
        },
        select: { id: true },
      });
      if (activePayment) {
        throw new ConflictException(
          "Reverse the payment before cancelling this payment schedule",
        );
      }
      const cancelled = await tx.paymentSchedule.update({
        where: { id },
        data: { status: PaymentScheduleStatus.CANCELLED, paidAt: null },
        include: scheduleInclude,
      });
      await this.recordMoneyEvent(tx, context, {
        entityType: ContributionEntityType.PAYMENT_SCHEDULE,
        entityId: cancelled.id,
        action: ContributionAction.STATUS_CHANGED,
        dedupeKey: `money:payment-schedule:${cancelled.id}:cancelled`,
        source: {
          title: cancelled.weddingCost.title,
          categoryLabel: cancelled.weddingCost.budgetCategory.name,
          currency: context.plan.currency,
          amount: cancelled.amount,
          status: cancelled.status,
          relevantDate: cancelled.dueDate,
        },
        occurredAt: cancelled.updatedAt,
      });
      return this.scheduleResponse(cancelled);
    });
  }

  async paySchedule(
    currentUser: AuthenticatedUser,
    id: string,
    dto: PayPaymentScheduleDto,
  ): Promise<SchedulePaymentResponse> {
    const current = await this.scheduleOrThrow(id);
    const result = await runSerializableTransaction(this.prisma, async (tx) => {
      const context = await this.permissions.assertMoneyManageableInTransaction(
        tx,
        current.weddingCost.weddingPlanId,
        currentUser,
      );
      await this.assertScopedCostInTransaction(
        tx,
        context,
        current.weddingCostId,
      );
      const cost = await this.lockCost(tx, current.weddingCostId);
      await this.lockSchedule(tx, id);
      const schedule = await tx.paymentSchedule.findUnique({ where: { id } });
      if (!schedule) throw new NotFoundException("Payment schedule not found");
      if (schedule.status === PaymentScheduleStatus.PAID) {
        const existing = await tx.costPayment.findFirst({
          where: {
            paymentScheduleId: id,
            entryType: CostPaymentType.PAYMENT,
            reversedBy: null,
          },
          include: paymentInclude,
          orderBy: { createdAt: "desc" },
        });
        if (!existing)
          throw new ConflictException(
            "Payment schedule ledger is inconsistent",
          );
        const paidSchedule = await tx.paymentSchedule.findUniqueOrThrow({
          where: { id },
          include: scheduleInclude,
        });
        return {
          payment: this.paymentResponse(existing),
          schedule: this.scheduleResponse(paidSchedule),
          created: false,
        };
      }
      if (schedule.status !== PaymentScheduleStatus.PENDING) {
        throw new ConflictException(
          "Cancelled payment schedules cannot be paid",
        );
      }
      const activePayment = await tx.costPayment.findFirst({
        where: {
          paymentScheduleId: id,
          entryType: CostPaymentType.PAYMENT,
          reversedBy: null,
        },
        select: { id: true },
      });
      if (activePayment) {
        throw new ConflictException(
          "Payment schedule already has an active payment",
        );
      }
      this.assertCostPayable(cost.status);
      const remaining = cost.totalAmount.minus(cost.paidAmount);
      if (schedule.amount.gt(remaining)) {
        throw new BadRequestException(
          "Scheduled payment exceeds the remaining cost",
        );
      }
      const paidAt = this.optionalDate(dto.paidAt, "paidAt") ?? new Date();
      const payment = await tx.costPayment.create({
        data: {
          weddingCostId: cost.id,
          paymentScheduleId: schedule.id,
          amount: schedule.amount,
          paidAt,
          method: this.optionalText(dto.method),
          note: this.optionalText(dto.note) ?? schedule.note,
        },
        include: paymentInclude,
      });
      const paidSchedule = await tx.paymentSchedule.update({
        where: { id },
        data: { status: PaymentScheduleStatus.PAID, paidAt },
        include: scheduleInclude,
      });
      const paidAmount = cost.paidAmount.plus(schedule.amount);
      const status = this.deriveStatus(cost.totalAmount, paidAmount);
      await tx.weddingCost.update({
        where: { id: cost.id },
        data: {
          paidAmount,
          status,
        },
      });
      await this.cancelPendingSchedulesWhenPaid(tx, cost.id, status);
      await this.recordMoneyEvent(tx, context, {
        entityType: ContributionEntityType.WEDDING_COST,
        entityId: cost.id,
        action: ContributionAction.PAYMENT_RECORDED,
        dedupeKey: `money:wedding-cost:${cost.id}:schedule-payment:${payment.id}`,
        source: {
          title: cost.title,
          currency: context.plan.currency,
          totalAmount: cost.totalAmount,
          paidAmount,
          amount: payment.amount,
          status,
          relevantDate: paidAt,
        },
        occurredAt: paidAt,
      });
      return {
        payment: this.paymentResponse(payment),
        schedule: this.scheduleResponse(paidSchedule),
        created: true,
      };
    });
    if (result.created) paymentsRecordedTotal.inc();
    return { payment: result.payment, schedule: result.schedule };
  }

  private async normalizeCounterparty(
    tx: Tx,
    input: {
      weddingPlanId: string;
      planCurrency: string;
      totalAmount: Prisma.Decimal;
      providerId?: string | null;
      quoteOfferId?: string | null;
      partyName?: string | null;
      partyPhone?: string | null;
      currentCostId?: string;
    },
  ): Promise<NormalizedCounterparty> {
    let providerId = this.optionalText(input.providerId);
    const quoteOfferId = this.optionalText(input.quoteOfferId);
    const partyName = this.optionalText(input.partyName);
    const partyPhone = this.optionalText(input.partyPhone);

    if (quoteOfferId) {
      const offer = await tx.quoteOffer.findUnique({
        where: { id: quoteOfferId },
        include: { quoteRequest: true, provider: true, weddingCosts: true },
      });
      if (
        !offer ||
        offer.status !== QuoteOfferStatus.ACCEPTED ||
        offer.quoteRequest.weddingPlanId !== input.weddingPlanId
      ) {
        throw new BadRequestException(
          "quoteOfferId must reference an accepted offer for this plan",
        );
      }
      if (offer.provider.status !== ProviderStatus.ACTIVE) {
        throw new BadRequestException("The quote provider is not active");
      }
      if (providerId && providerId !== offer.providerId) {
        throw new BadRequestException(
          "providerId must match the quote offer provider",
        );
      }
      if (offer.currency.toUpperCase() !== input.planCurrency.toUpperCase()) {
        throw new BadRequestException(
          "Quote currency must match the wedding plan currency",
        );
      }
      if (offer.amount !== null && !offer.amount.equals(input.totalAmount)) {
        throw new BadRequestException(
          "totalAmount must match the accepted quote amount",
        );
      }
      const otherCost = offer.weddingCosts.find(
        (cost) => cost.id !== input.currentCostId,
      );
      if (otherCost) {
        throw new ConflictException(
          "This quote offer is already linked to a cost",
        );
      }
      providerId = offer.providerId;
    } else if (providerId) {
      const provider = await tx.provider.findUnique({
        where: { id: providerId },
      });
      if (!provider || provider.status !== ProviderStatus.ACTIVE) {
        throw new BadRequestException(
          "providerId must reference an active provider",
        );
      }
    }

    if (providerId && (partyName || partyPhone)) {
      throw new BadRequestException(
        "partyName and partyPhone cannot be used with an application provider",
      );
    }
    return { providerId, quoteOfferId, partyName, partyPhone };
  }

  private async lockCounterpartyReferences(
    tx: Tx,
    input: {
      providerIds: Array<string | null | undefined>;
      quoteOfferIds: Array<string | null | undefined>;
    },
  ) {
    const quoteOfferIds = [
      ...new Set(
        input.quoteOfferIds
          .map((id) => this.optionalText(id))
          .filter((id): id is string => id !== null),
      ),
    ].sort();
    const discoveredOffers =
      quoteOfferIds.length === 0
        ? []
        : await tx.quoteOffer.findMany({
            where: { id: { in: quoteOfferIds } },
            select: { id: true, providerId: true },
          });
    const providerIds = [
      ...new Set(
        [
          ...input.providerIds.map((id) => this.optionalText(id)),
          ...discoveredOffers.map((offer) => offer.providerId),
        ].filter((id): id is string => id !== null),
      ),
    ].sort();

    if (providerIds.length > 0) {
      await tx.$queryRaw<Array<{ id: string }>>(
        Prisma.sql`
          SELECT "id"
          FROM "Provider"
          WHERE "id" IN (${Prisma.join(providerIds)})
          ORDER BY "id" ASC
          FOR SHARE
        `,
      );
    }
    if (quoteOfferIds.length > 0) {
      const lockedOffers = await tx.$queryRaw<
        Array<{ id: string; providerId: string }>
      >(
        Prisma.sql`
          SELECT "id", "providerId"
          FROM "QuoteOffer"
          WHERE "id" IN (${Prisma.join(quoteOfferIds)})
          ORDER BY "id" ASC
          FOR UPDATE
        `,
      );
      const lockedProviderByOffer = new Map(
        lockedOffers.map((offer) => [offer.id, offer.providerId]),
      );
      for (const discovered of discoveredOffers) {
        if (
          lockedProviderByOffer.get(discovered.id) !== discovered.providerId
        ) {
          throw new ConflictException(
            "Quote offer references changed concurrently; retry the request",
          );
        }
      }
    }
  }

  private async assertCategory(
    tx: Tx,
    id: string,
    weddingPlanId: string,
    additionalIds: string[] = [],
  ) {
    const normalizedId = id.trim();
    const orderedIds = [
      ...new Set([normalizedId, ...additionalIds.map((item) => item.trim())]),
    ].sort();
    const rows = await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`
        SELECT "id"
        FROM "BudgetCategory"
        WHERE "id" IN (${Prisma.join(orderedIds)})
          AND "weddingPlanId" = ${weddingPlanId}
        ORDER BY "id" ASC
        FOR SHARE
      `,
    );
    if (!rows.some((row) => row.id === normalizedId))
      throw new BadRequestException(
        "budgetCategoryId is invalid for this plan",
      );
  }

  private async lockCost(tx: Tx, id: string) {
    const rows = await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`SELECT "id" FROM "WeddingCost" WHERE "id" = ${id} FOR UPDATE`,
    );
    if (rows.length === 0)
      throw new NotFoundException("Wedding cost not found");
    return tx.weddingCost.findUniqueOrThrow({ where: { id } });
  }

  private async lockPayment(tx: Tx, id: string) {
    const rows = await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`SELECT "id" FROM "CostPayment" WHERE "id" = ${id} FOR UPDATE`,
    );
    if (rows.length === 0)
      throw new NotFoundException("Cost payment not found");
  }

  private async lockSchedule(tx: Tx, id: string) {
    const rows = await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`SELECT "id" FROM "PaymentSchedule" WHERE "id" = ${id} FOR UPDATE`,
    );
    if (rows.length === 0)
      throw new NotFoundException("Payment schedule not found");
  }

  private async cancelPendingSchedulesWhenPaid(
    tx: Tx,
    costId: string,
    status: WeddingCostStatus,
  ) {
    if (status !== WeddingCostStatus.PAID) return;
    await tx.paymentSchedule.updateMany({
      where: {
        weddingCostId: costId,
        status: PaymentScheduleStatus.PENDING,
      },
      data: { status: PaymentScheduleStatus.CANCELLED, paidAt: null },
    });
  }

  private async scopedCostIdsInTransaction(
    tx: Tx,
    context: PlanAccessContext,
  ): Promise<string[] | null> {
    if (context.isOwner || !context.sharedMember) return null;
    return this.requiredContributorScope().qualifyingEntityIdsInTransaction(
      tx,
      context.plan.id,
      context.sharedMember.userId,
      [ContributionEntityType.WEDDING_COST],
      [
        ContributionAction.CREATED,
        ContributionAction.COMPLETED,
        ContributionAction.PAYMENT_RECORDED,
      ],
    );
  }

  private async assertScopedCostInTransaction(
    tx: Tx,
    context: PlanAccessContext,
    costId: string,
  ): Promise<void> {
    if (context.isOwner || !context.sharedMember) return;
    const ids = await this.scopedCostIdsInTransaction(tx, context);
    if (!ids?.includes(costId)) {
      throw new NotFoundException("Wedding cost not found");
    }
  }

  private async assertScopedCategoryInTransaction(
    tx: Tx,
    context: PlanAccessContext,
    categoryId: string,
  ): Promise<void> {
    if (context.isOwner || !context.sharedMember) return;
    const categoryIds =
      await this.requiredContributorScope().qualifyingEntityIdsInTransaction(
        tx,
        context.plan.id,
        context.sharedMember.userId,
        [ContributionEntityType.BUDGET_CATEGORY],
        [ContributionAction.CREATED],
      );
    if (categoryIds.includes(categoryId)) return;
    throw new NotFoundException("Budget category not found");
  }

  private recordMoneyEvent(
    tx: Tx,
    context: PlanAccessContext,
    input: {
      entityType: ContributionEntityType;
      entityId: string;
      action: ContributionAction;
      dedupeKey: string;
      source: Record<string, unknown>;
      occurredAt?: Date | null;
    },
  ) {
    if (context.isOwner) return Promise.resolve(null);
    if (!this.contributionHistory) {
      throw new Error("ContributionHistoryService is required for contributor money writes");
    }
    return this.contributionHistory.recordForContextInTransaction(tx, context, {
      section: ContributionSection.MONEY,
      entityType: input.entityType,
      entityId: input.entityId,
      action: input.action,
      snapshot: buildContributionSnapshot(input.entityType, input.source),
      dedupeKey: input.dedupeKey,
      requiredPermission: ContributionPermission.MANAGE_MONEY,
      occurredAt: input.occurredAt ?? null,
    });
  }

  private requiredContributorScope(): ContributorScopeService {
    if (!this.contributorScope) {
      throw new Error(
        "ContributorScopeService is required for contributor money access",
      );
    }
    return this.contributorScope;
  }

  private async costOrThrow(id: string) {
    const cost = await this.prisma.weddingCost.findUnique({
      where: { id },
      include: weddingCostResponseInclude,
    });
    if (!cost) throw new NotFoundException("Wedding cost not found");
    return cost;
  }

  private async costIdentityOrThrow(id: string) {
    const cost = await this.prisma.weddingCost.findUnique({
      where: { id },
      select: { weddingPlanId: true },
    });
    if (!cost) throw new NotFoundException("Wedding cost not found");
    return cost;
  }

  private async paymentOrThrow(id: string) {
    const payment = await this.prisma.costPayment.findUnique({
      where: { id },
      include: paymentInclude,
    });
    if (!payment) throw new NotFoundException("Cost payment not found");
    return payment;
  }

  private async paymentIdentityOrThrow(id: string) {
    const payment = await this.prisma.costPayment.findUnique({
      where: { id },
      select: {
        weddingCostId: true,
        weddingCost: { select: { weddingPlanId: true } },
      },
    });
    if (!payment) throw new NotFoundException("Cost payment not found");
    return {
      weddingCostId: payment.weddingCostId,
      weddingPlanId: payment.weddingCost.weddingPlanId,
    };
  }

  private async scheduleOrThrow(id: string) {
    const schedule = await this.prisma.paymentSchedule.findUnique({
      where: { id },
      include: scheduleInclude,
    });
    if (!schedule) throw new NotFoundException("Payment schedule not found");
    return schedule;
  }

  private paymentResponse(payment: PaymentWithDetails): CostPaymentResponse {
    return {
      id: payment.id,
      costId: payment.weddingCostId,
      weddingPlanId: payment.weddingCost.weddingPlanId,
      budgetCategoryId: payment.weddingCost.budgetCategoryId,
      categoryName: payment.weddingCost.budgetCategory.name,
      providerId: payment.weddingCost.providerId,
      providerName: payment.weddingCost.provider?.businessName ?? null,
      costTitle: payment.weddingCost.title,
      amount: payment.amount.toString(),
      entryType: payment.entryType,
      paymentScheduleId: payment.paymentScheduleId,
      reversalOfId: payment.reversalOfId,
      reversedById: payment.reversedBy?.id ?? null,
      reversible:
        payment.entryType === CostPaymentType.PAYMENT &&
        payment.reversedBy === null,
      paidAt: payment.paidAt,
      method: payment.method,
      note: payment.note,
      createdAt: payment.createdAt,
    };
  }

  private scheduleResponse(
    schedule: ScheduleWithDetails,
  ): PaymentScheduleResponse {
    return {
      id: schedule.id,
      costId: schedule.weddingCostId,
      weddingCostId: schedule.weddingCostId,
      weddingPlanId: schedule.weddingCost.weddingPlanId,
      budgetCategoryId: schedule.weddingCost.budgetCategoryId,
      categoryName: schedule.weddingCost.budgetCategory.name,
      providerId: schedule.weddingCost.providerId,
      providerName: schedule.weddingCost.provider?.businessName ?? null,
      costTitle: schedule.weddingCost.title,
      amount: schedule.amount.toString(),
      dueDate: schedule.dueDate,
      paidAt: schedule.paidAt,
      status: schedule.status,
      isOverdue:
        schedule.status === PaymentScheduleStatus.PENDING &&
        schedule.dueDate < this.startOfTodayInRiyadh(),
      note: schedule.note,
      createdAt: schedule.createdAt,
      updatedAt: schedule.updatedAt,
    };
  }

  private deriveStatus(total: Prisma.Decimal, paid: Prisma.Decimal) {
    if (paid.gte(total)) return WeddingCostStatus.PAID;
    if (paid.gt(0)) return WeddingCostStatus.PARTIALLY_PAID;
    return WeddingCostStatus.OPEN;
  }

  private assertCostPayable(status: WeddingCostStatus) {
    if (status === WeddingCostStatus.CANCELLED) {
      throw new ConflictException("Cancelled costs cannot receive payments");
    }
    if (status === WeddingCostStatus.PAID) {
      throw new ConflictException("Cost is already fully paid");
    }
  }

  private positiveAmount(value: string | number, field: string) {
    const amount = new Prisma.Decimal(requiredMoneyAmount(value, field));
    if (!amount.gt(0))
      throw new BadRequestException(`${field} must be greater than zero`);
    return amount;
  }

  private optionalAmount(
    value: string | number | null | undefined,
    field: string,
  ) {
    if (
      value === null ||
      value === undefined ||
      (typeof value === "string" && value.trim() === "")
    ) {
      return new Prisma.Decimal(0);
    }
    return this.positiveAmount(value, field);
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

  private requiredDate(value: string, field: string) {
    const normalized = value.trim();
    const calendar = /^(\d{4})-(\d{2})-(\d{2})(?:$|T)/.exec(normalized);
    if (!calendar || !this.isRealCalendarDate(calendar)) {
      throw new BadRequestException(`${field} must be a valid ISO-8601 date`);
    }
    const date = new Date(normalized);
    if (Number.isNaN(date.getTime()))
      throw new BadRequestException(`${field} must be a valid ISO-8601 date`);
    return date;
  }

  private isRealCalendarDate(match: RegExpExecArray) {
    const year = Number(match[1]);
    const month = Number(match[2]);
    const day = Number(match[3]);
    if (year < 1 || month < 1 || month > 12 || day < 1) return false;
    const leap = year % 4 === 0 && (year % 100 !== 0 || year % 400 === 0);
    const days = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return day <= days[month - 1];
  }

  private optionalDate(value: string | null | undefined, field: string) {
    if (value === null || value === undefined || value.trim() === "")
      return null;
    return this.requiredDate(value, field);
  }

  private startOfTodayInRiyadh(now = new Date()) {
    const riyadh = new Date(now.getTime() + 3 * 60 * 60 * 1000);
    return new Date(
      Date.UTC(
        riyadh.getUTCFullYear(),
        riyadh.getUTCMonth(),
        riyadh.getUTCDate(),
      ) -
        3 * 60 * 60 * 1000,
    );
  }

  private rethrowKnownPrismaError(error: unknown): never {
    if (
      error instanceof BadRequestException ||
      error instanceof ConflictException ||
      error instanceof NotFoundException
    ) {
      throw error;
    }
    if (error instanceof Prisma.PrismaClientKnownRequestError) {
      if (error.code === "P2002") {
        throw new ConflictException(
          "A cost with the same unique reference already exists",
        );
      }
      if (error.code === "P2003") {
        throw new BadRequestException(
          "One of the referenced records is invalid",
        );
      }
    }
    throw error;
  }
}
