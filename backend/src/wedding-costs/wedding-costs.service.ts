import {
  excludeOthersPrivateCosts,
  isOthersPrivateCost,
  isPrivateCostEntity,
} from "../modules/finance/infrastructure/cost-privacy.repository";
import { countCostReceipts } from "../modules/finance/infrastructure/cost-receipts.repository";
import {
  BadRequestException,
  ForbiddenException,
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
  PROVIDER_READ_PORT,
  type ProviderReadPort,
} from "../modules/marketplace/public/provider-read.port";
import { isPlanItemBooked } from "../modules/marketplace/public/plan-booked-services";
import {
  FINANCE_PORT,
  type FinancePort,
} from "../modules/finance/public/finance.port";
import { TASKS_PORT, type TasksPort } from "../modules/tasks/public/tasks.port";
import {
  QUOTE_READ_PORT,
  type QuoteReadPort,
} from "../modules/marketplace/public/quote-read.port";
import {
  COLLABORATION_PERMISSION_PORT,
  type CollaborationPermissionPort as PermissionService,
  type PlanAccessContext,
  seesWholePlan,
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
  type WeddingCostWithDetails,
} from "../modules/finance/public/wedding-cost.presenter";
import {
  costCancellationViolation,
  costDeletionViolation,
  deriveCostStatus,
  initialPaymentViolation,
  payableViolation,
  paymentAmountViolation,
  positiveAmountViolation,
  reversalViolation,
  totalAmountViolation,
} from "../modules/finance/domain/wedding-cost-aggregate";
import {
  scheduleAmountDue,
  scheduleAmountViolation,
  scheduledPaymentViolation,
  schedulesToCancelOnStatus,
} from "../modules/finance/domain/payment-schedule-policy";
import {
  insertWeddingCost,
  requireWeddingCost,
  listWeddingCosts,
  countWeddingCosts,
  findVisibleWeddingCost,
  findWeddingCost,
  updateWeddingCost,
  deleteWeddingCost,
  insertCostPayment,
  listCostPayments,
  countCostPayments,
  findVisibleCostPayment,
  findActiveSchedulePayment,
  findCostPayment,
  insertPaymentSchedule,
  listPaymentSchedules,
  requirePaymentSchedule,
  findPaymentSchedule,
  updatePaymentSchedules,
  updatePaymentSchedule,
  deletePaymentSchedule,
  lockBudgetCategoriesForCost,
  lockWeddingCost,
  lockCostPayment,
  lockPaymentSchedule,
  readBudgetCategoryKinds,
  findWeddingCostIdsMatchingSearch,
} from "../modules/finance/infrastructure/wedding-costs.repository";
import { arabicSearchKey } from "../shared-kernel/text/arabic-search";
import { financeConflict, raiseFinanceViolation } from "../modules/finance/internal/finance-violation.http";
import { mahrItemMoveViolation } from "../modules/finance/domain/mahr-policy";

const paymentInclude = Prisma.validator<Prisma.CostPaymentInclude>()({
  weddingCost: {
    include: {
      budgetCategory: { select: { name: true } },
    },
  },
  reversedBy: { select: { id: true } },
});

const scheduleInclude = Prisma.validator<Prisma.PaymentScheduleInclude>()({
  weddingCost: {
    include: {
      budgetCategory: { select: { name: true } },
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
  /** The amount as the person wrote it. */
  amount: string;
  /**
   * RA-BE-53: what a pending schedule asks for now, at most what its cost
   * still owes; what paying it records. "0" once it is paid or cancelled.
   */
  amountDue: string;
  /**
   * RA-BE-53: what the schedule's agreement still owes now. Schedules are
   * not reservations: two of one agreement each ask for up to this, so a
   * list that adds them up counts each agreement's together at most this.
   */
  costRemainingAmount: string;
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
    @Inject(PROVIDER_READ_PORT)
    private readonly providers: ProviderReadPort,
    @Inject(QUOTE_READ_PORT)
    private readonly quotes: QuoteReadPort,
    @Inject(COLLABORATION_SCOPE_PORT)
    private readonly contributorScope?: ContributorScopeService,
    @Inject(COLLABORATION_HISTORY_PORT)
    private readonly contributionHistory?: ContributionHistoryService,
    @Inject(FINANCE_PORT)
    private readonly finance?: FinancePort,
    @Inject(TASKS_PORT)
    private readonly tasks?: TasksPort,
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
    raiseFinanceViolation(initialPaymentViolation(initialPayment, totalAmount));

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
        const created = await insertWeddingCost(tx, {
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
            status: deriveCostStatus(totalAmount, initialPayment),
            payer: dto.payer ?? null,
            payerName: this.optionalText(dto.payerName),
            note: this.optionalText(dto.note),
            privateToUserId: this.privateOwnerForNewCost(context, currentUser, dto.isPrivate),
          },
        });
        if (initialPayment.gt(0)) {
          await insertCostPayment(tx, {
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
        await this.syncItemTasks(tx, weddingPlanId, [created.budgetCategoryId]);
        return requireWeddingCost(tx, {
          where: { id: created.id },
          include: weddingCostResponseInclude,
        });
      });
      if (initialPayment.gt(0)) paymentsRecordedTotal.inc();
      return this.presentCost(this.prisma, cost);
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
        const liveFilter = await this.permissions.liveAuthorizationFilter(
          tx,
          access,
          currentUser.id,
          ["canViewMoney"],
        );
        // RA-BE-09: an agreement is found by its title, party, item or
        // provider's name, folded as the phone folds them.
        const searchKey = search ? arabicSearchKey(search) : "";
        const searchedCostIds = searchKey
          ? await findWeddingCostIdsMatchingSearch(
              tx,
              weddingPlanId,
              searchKey,
              await this.providerIdsMatchingSearch(tx, weddingPlanId, searchKey),
            )
          : null;
        const costIds = intersectIds(scopedCostIds, searchedCostIds);
        const where = {
          weddingPlanId,
          ...(costIds ? { id: { in: costIds } } : {}),
          ...(query.status ? { status: query.status } : {}),
          ...(query.categoryId?.trim()
            ? { budgetCategoryId: query.categoryId.trim() }
            : {}),
          ...(query.payer ? { payer: query.payer } : {}),
          ...liveFilter,
        } satisfies Prisma.WeddingCostWhereInput;
        const [costs, total] = await Promise.all([
          listWeddingCosts(tx, {
            where,
            include: weddingCostResponseInclude,
            orderBy: [{ createdAt: "desc" }, { id: "desc" }],
            skip: (page - 1) * pageSize,
            take: pageSize,
          }),
          countWeddingCosts(tx, { where }),
        ]);
        return {
          items: await this.presentCosts(tx, costs),
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
        const liveFilter = await this.permissions.liveAuthorizationFilter(
          tx,
          access,
          currentUser.id,
          ["canViewMoney"],
        );
        const cost = await findVisibleWeddingCost(tx, {
          where: {
            id,
            weddingPlanId: identity.weddingPlanId,
            ...liveFilter,
          },
          include: weddingCostResponseInclude,
        });
        if (!cost) throw new NotFoundException("Wedding cost not found");
        return this.presentCost(tx, cost);
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
        const snapshot = await findWeddingCost(tx, { where: { id } });
        if (
          !snapshot ||
          snapshot.weddingPlanId !== current.weddingPlanId
        ) {
          throw new NotFoundException("Wedding cost not found");
        }
        // V1 checklist 4.10: privacy is chosen when the cost is recorded; a
        // shared cost never becomes private (it would vanish from the other
        // side), and only the account it is private to can share it.
        if (dto.isPrivate === true && !snapshot.privateToUserId) {
          throw new BadRequestException({
            statusCode: 400,
            code: "COST_PRIVACY_AT_CREATION_ONLY",
            message: "A shared cost cannot become private",
          });
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
        if (targetBudgetCategoryId !== snapshot.budgetCategoryId) {
          // C1 (D59): the agreement stays on its side of the budget.
          const kinds = await readBudgetCategoryKinds(tx, [
            snapshot.budgetCategoryId,
            targetBudgetCategoryId,
          ]);
          raiseFinanceViolation(
            mahrItemMoveViolation(
              kinds.get(snapshot.budgetCategoryId) ?? "WEDDING",
              kinds.get(targetBudgetCategoryId) ?? "WEDDING",
            ),
          );
        }
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
          throw financeConflict("Cancelled costs cannot be edited");
        }
        const totalAmount =
          dto.totalAmount === undefined
            ? locked.totalAmount
            : this.positiveAmount(dto.totalAmount, "totalAmount");
        raiseFinanceViolation(
          totalAmountViolation(totalAmount, locked.paidAmount),
        );
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
        const status = deriveCostStatus(totalAmount, locked.paidAmount);
        const updated = await updateWeddingCost(tx, {
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
            ...(dto.payer === undefined ? {} : { payer: dto.payer }),
            ...(dto.isPrivate === false ? { privateToUserId: null } : {}),
            ...(dto.payerName === undefined
              ? {}
              : { payerName: this.optionalText(dto.payerName) }),
            ...(dto.note === undefined
              ? {}
              : { note: this.optionalText(dto.note) }),
          },
          include: weddingCostResponseInclude,
        });
        await this.cancelPendingSchedulesWhenPaid(tx, id, status);
        await this.restoreSchedulesWhenOwedAgain(
          tx,
          id,
          status,
          totalAmount.minus(locked.paidAmount),
        );
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
        await this.syncItemTasks(tx, updated.weddingPlanId, [
          locked.budgetCategoryId,
          updated.budgetCategoryId,
        ]);
        return this.presentCost(tx, updated);
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
      const paymentsCount = await countCostPayments(tx, {
        where: { weddingCostId: id },
      });
      raiseFinanceViolation(
        costDeletionViolation(paymentsCount, locked.paidAmount),
      );
      // V1 checklist 4.4: a cost with receipts keeps them until they are
      // deleted one by one (each file is then scheduled for deletion).
      if ((await countCostReceipts(tx, id)) > 0) {
        throw new ConflictException({
          statusCode: 409,
          code: "COST_HAS_RECEIPTS",
          message: "Delete the cost's receipts first",
        });
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
      // RA-BE-24: its reminders go with it (cascade); their tasks wait on
      // nothing now, and the item may no longer be booked (D71), as when
      // an agreement is cancelled.
      const reminders = await listPaymentSchedules(tx, {
        where: { weddingCostId: id },
      });
      await deleteWeddingCost(tx, { where: { id } });
      for (const reminder of reminders) {
        await this.tasks?.unlinkTasks(tx, locked.weddingPlanId, {
          scheduleId: reminder.id,
        });
      }
      await this.syncItemTasks(tx, locked.weddingPlanId, [
        locked.budgetCategoryId,
      ]);
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
        return this.presentCost(
          tx,
          await requireWeddingCost(tx, {
            where: { id },
            include: weddingCostResponseInclude,
          }),
        );
      }
      raiseFinanceViolation(costCancellationViolation(locked.paidAmount));
      const dropped = await listPaymentSchedules(tx, {
        where: { weddingCostId: id, status: PaymentScheduleStatus.PENDING },
      });
      await updatePaymentSchedules(tx, {
        where: { weddingCostId: id, status: PaymentScheduleStatus.PENDING },
        data: { status: PaymentScheduleStatus.CANCELLED },
      });
      const cancelled = await updateWeddingCost(tx, {
        where: { id },
        data: { status: WeddingCostStatus.CANCELLED },
        include: weddingCostResponseInclude,
      });
      for (const schedule of dropped) {
        await this.tasks?.unlinkTasks(tx, cancelled.weddingPlanId, {
          scheduleId: schedule.id,
        });
      }
      await this.syncItemTasks(tx, cancelled.weddingPlanId, [
        cancelled.budgetCategoryId,
      ]);
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
      return this.presentCost(tx, cancelled);
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
          { settlement: true },
        );
        await this.assertScopedCostInTransaction(tx, context, costId);
        const amount = this.positiveAmount(dto.amount, "amount");
        const cost = await this.lockCost(tx, costId);
        this.assertCostPayable(cost.status);
        raiseFinanceViolation(
          paymentAmountViolation(amount, cost.totalAmount, cost.paidAmount),
        );
        const payment = await insertCostPayment(tx, {
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
        const status = deriveCostStatus(cost.totalAmount, paidAmount);
        await updateWeddingCost(tx, {
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
        return this.presentPayment(tx, payment);
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
        const liveFilter = await this.permissions.liveAuthorizationFilter(
          tx,
          access,
          currentUser.id,
          ["canViewMoney"],
        );
        const payments = await listCostPayments(tx, {
          where: {
            weddingCostId: costId,
            weddingCost: {
              weddingPlanId: identity.weddingPlanId,
              ...(scopedCostIds ? { id: { in: scopedCostIds } } : {}),
            },
            ...liveFilter,
          },
          include: paymentInclude,
          orderBy: [{ paidAt: "desc" }, { createdAt: "desc" }],
        });
        return this.presentPayments(tx, payments);
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
        const liveFilter = await this.permissions.liveAuthorizationFilter(
          tx,
          access,
          currentUser.id,
          ["canViewMoney"],
        );
        const where = {
          weddingCost: {
            weddingPlanId,
            ...(scopedCostIds ? { id: { in: scopedCostIds } } : {}),
          },
          ...liveFilter,
        } satisfies Prisma.CostPaymentWhereInput;
        const [payments, total] = await Promise.all([
          listCostPayments(tx, {
            where,
            include: paymentInclude,
            orderBy: [{ paidAt: "desc" }, { createdAt: "desc" }],
            skip: (page - 1) * pageSize,
            take: pageSize,
          }),
          countCostPayments(tx, { where }),
        ]);
        return {
          items: await this.presentPayments(tx, payments),
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
        const liveFilter = await this.permissions.liveAuthorizationFilter(
          tx,
          access,
          currentUser.id,
          ["canViewMoney"],
        );
        const payment = await findVisibleCostPayment(tx, {
          where: {
            id,
            weddingCostId: identity.weddingCostId,
            weddingCost: {
              weddingPlanId: identity.weddingPlanId,
              ...(scopedCostIds ? { id: { in: scopedCostIds } } : {}),
            },
            ...liveFilter,
          },
          include: paymentInclude,
        });
        if (!payment) throw new NotFoundException("Cost payment not found");
        return this.presentPayment(tx, payment);
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
          { settlement: true },
        );
      await this.assertScopedCostInTransaction(
        tx,
        context,
        current.weddingCostId,
      );
      const cost = await this.lockCost(tx, current.weddingCostId);
      await this.lockPayment(tx, id);
      const payment = await findCostPayment(tx, {
        where: { id },
        include: paymentInclude,
      });
      if (!payment) throw new NotFoundException("Cost payment not found");
      raiseFinanceViolation(
        reversalViolation(
          {
            entryType: payment.entryType,
            reversed: Boolean(payment.reversedBy),
            amount: payment.amount,
          },
          cost.paidAmount,
        ),
      );
      const paidAmount = cost.paidAmount.minus(payment.amount);
      const reversal = await insertCostPayment(tx, {
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
      await updateWeddingCost(tx, {
        where: { id: cost.id },
        data: {
          paidAmount,
          status: deriveCostStatus(cost.totalAmount, paidAmount),
        },
      });
      await this.restoreSchedulesWhenOwedAgain(
        tx,
        cost.id,
        deriveCostStatus(cost.totalAmount, paidAmount),
        cost.totalAmount.minus(paidAmount),
      );
      if (payment.paymentScheduleId) {
        await updatePaymentSchedule(tx, {
          where: { id: payment.paymentScheduleId },
          data: { status: PaymentScheduleStatus.PENDING, paidAt: null },
        });
        await this.tasks?.syncLinkedTasks(
          tx,
          cost.weddingPlanId,
          { scheduleId: payment.paymentScheduleId },
          false,
        );
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
          status: deriveCostStatus(cost.totalAmount, paidAmount),
          relevantDate: reversal.paidAt,
        },
        occurredAt: reversal.paidAt,
      });
      return this.presentPayment(tx, reversal);
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
      raiseFinanceViolation(
        scheduleAmountViolation(amount, cost.totalAmount, cost.paidAmount),
      );
      const schedule = await insertPaymentSchedule(tx, {
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
      return this.presentSchedule(tx, schedule);
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
        const liveFilter = await this.permissions.liveAuthorizationFilter(
          tx,
          access,
          currentUser.id,
          ["canViewMoney"],
        );
        const schedules = await listPaymentSchedules(tx, {
          where: {
            weddingCostId: costId,
            weddingCost: {
              weddingPlanId: identity.weddingPlanId,
              ...(scopedCostIds ? { id: { in: scopedCostIds } } : {}),
            },
            ...liveFilter,
          },
          include: scheduleInclude,
          orderBy: [{ dueDate: "asc" }, { createdAt: "asc" }],
        });
        return this.presentSchedules(tx, schedules);
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
        const liveFilter = await this.permissions.liveAuthorizationFilter(
          tx,
          access,
          currentUser.id,
          ["canViewMoney"],
        );
        const schedules = await listPaymentSchedules(tx, {
          where: {
            weddingCost: {
              weddingPlanId,
              ...(scopedCostIds ? { id: { in: scopedCostIds } } : {}),
              status: { not: WeddingCostStatus.CANCELLED },
            },
            status: PaymentScheduleStatus.PENDING,
            dueDate: { lte: through },
            ...liveFilter,
          },
          include: scheduleInclude,
          orderBy: [{ dueDate: "asc" }, { createdAt: "asc" }],
        });
        return this.presentSchedules(tx, schedules);
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
      const schedule = await requirePaymentSchedule(tx, {
        where: { id },
      });
      if (schedule.status !== PaymentScheduleStatus.PENDING) {
        throw financeConflict("Only pending payment schedules can be edited");
      }
      const paymentHistory = await countCostPayments(tx, {
        where: { paymentScheduleId: id },
      });
      if (paymentHistory > 0 && dto.amount !== undefined) {
        throw financeConflict("The amount of a payment schedule with ledger history cannot be changed");
      }
      const amount =
        dto.amount === undefined
          ? schedule.amount
          : this.positiveAmount(dto.amount, "amount");
      this.assertCostPayable(cost.status);
      raiseFinanceViolation(
        scheduleAmountViolation(amount, cost.totalAmount, cost.paidAmount),
      );
      const updated = await updatePaymentSchedule(tx, {
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
      return this.presentSchedule(tx, updated);
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
      const schedule = await requirePaymentSchedule(tx, {
        where: { id },
      });
      if (schedule.status !== PaymentScheduleStatus.PENDING) {
        throw financeConflict("Only pending payment schedules can be deleted");
      }
      const paymentHistory = await countCostPayments(tx, {
        where: { paymentScheduleId: id },
      });
      if (paymentHistory > 0) {
        throw financeConflict("A payment schedule with ledger history cannot be deleted");
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
      await deletePaymentSchedule(tx, { where: { id } });
      await this.tasks?.unlinkTasks(tx, current.weddingCost.weddingPlanId, {
        scheduleId: id,
      });
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
      const schedule = await requirePaymentSchedule(tx, {
        where: { id },
      });
      if (schedule.status === PaymentScheduleStatus.CANCELLED) {
        return this.presentSchedule(
          tx,
          await requirePaymentSchedule(tx, {
            where: { id },
            include: scheduleInclude,
          }),
        );
      }
      if (schedule.status !== PaymentScheduleStatus.PENDING) {
        throw financeConflict("Reverse the payment before cancelling this payment schedule");
      }
      const activePayment = await findActiveSchedulePayment(tx, {
        where: {
          paymentScheduleId: id,
          entryType: CostPaymentType.PAYMENT,
          reversedBy: null,
        },
        select: { id: true },
      });
      if (activePayment) {
        throw financeConflict("Reverse the payment before cancelling this payment schedule");
      }
      const cancelled = await updatePaymentSchedule(tx, {
        where: { id },
        data: { status: PaymentScheduleStatus.CANCELLED, paidAt: null },
        include: scheduleInclude,
      });
      await this.tasks?.unlinkTasks(tx, cancelled.weddingCost.weddingPlanId, {
        scheduleId: id,
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
      return this.presentSchedule(tx, cancelled);
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
          { settlement: true },
        );
      await this.assertScopedCostInTransaction(
        tx,
        context,
        current.weddingCostId,
      );
      const cost = await this.lockCost(tx, current.weddingCostId);
      await this.lockSchedule(tx, id);
      const schedule = await findPaymentSchedule(tx, { where: { id } });
      if (!schedule) throw new NotFoundException("Payment schedule not found");
      if (schedule.status === PaymentScheduleStatus.PAID) {
        const existing = await findActiveSchedulePayment(tx, {
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
        const paidSchedule = await requirePaymentSchedule(tx, {
          where: { id },
          include: scheduleInclude,
        });
        return {
          payment: await this.presentPayment(tx, existing),
          schedule: await this.presentSchedule(tx, paidSchedule),
          created: false,
        };
      }
      if (schedule.status !== PaymentScheduleStatus.PENDING) {
        throw financeConflict("Cancelled payment schedules cannot be paid");
      }
      const activePayment = await findActiveSchedulePayment(tx, {
        where: {
          paymentScheduleId: id,
          entryType: CostPaymentType.PAYMENT,
          reversedBy: null,
        },
        select: { id: true },
      });
      if (activePayment) {
        throw financeConflict("Payment schedule already has an active payment");
      }
      this.assertCostPayable(cost.status);
      // RA-BE-53: the reminder pays what it asks for now (its amount, or what
      // the cost still owes if a straight payment left less); paying its
      // whole amount over the remaining was refused and the reminder stuck.
      const due = scheduleAmountDue(
        schedule.amount,
        cost.totalAmount,
        cost.paidAmount,
      );
      raiseFinanceViolation(
        scheduledPaymentViolation(due, cost.totalAmount, cost.paidAmount),
      );
      // A paid schedule is the record of its payment: the ledger holds the
      // two equal (`CostPayment_entry_integrity`), so a schedule paid for
      // less than it asked takes the amount paid.
      if (!due.equals(schedule.amount)) {
        await updatePaymentSchedule(tx, {
          where: { id },
          data: { amount: due },
        });
      }
      const paidAt = this.optionalDate(dto.paidAt, "paidAt") ?? new Date();
      const payment = await insertCostPayment(tx, {
        data: {
          weddingCostId: cost.id,
          paymentScheduleId: schedule.id,
          amount: due,
          paidAt,
          method: this.optionalText(dto.method),
          note: this.optionalText(dto.note) ?? schedule.note,
        },
        include: paymentInclude,
      });
      const paidSchedule = await updatePaymentSchedule(tx, {
        where: { id },
        data: { status: PaymentScheduleStatus.PAID, paidAt },
        include: scheduleInclude,
      });
      await this.tasks?.syncLinkedTasks(
        tx,
        cost.weddingPlanId,
        { scheduleId: id },
        true,
      );
      const paidAmount = cost.paidAmount.plus(due);
      const status = deriveCostStatus(cost.totalAmount, paidAmount);
      await updateWeddingCost(tx, {
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
        payment: await this.presentPayment(tx, payment),
        schedule: await this.presentSchedule(tx, paidSchedule),
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
      const offer = await this.quotes.getQuoteOfferWithRequest(
        tx,
        quoteOfferId,
      );
      if (
        !offer ||
        offer.status !== QuoteOfferStatus.ACCEPTED ||
        offer.quoteRequest.weddingPlanId !== input.weddingPlanId
      ) {
        throw new BadRequestException(
          "quoteOfferId must reference an accepted offer for this plan",
        );
      }
      const offerProvider = await this.providers.getProvider(
        tx,
        offer.providerId,
      );
      if (offerProvider?.status !== ProviderStatus.ACTIVE) {
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
      const linkedCosts = await listWeddingCosts(tx, {
        where: { quoteOfferId: offer.id },
      });
      const otherCost = linkedCosts.find(
        (cost) => cost.id !== input.currentCostId,
      );
      if (otherCost) {
        throw new ConflictException(
          "This quote offer is already linked to a cost",
        );
      }
      providerId = offer.providerId;
    } else if (providerId) {
      const provider = await this.providers.getProvider(tx, providerId);
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
    const discoveredOffers = await this.quotes.getQuoteOfferProviders(
      tx,
      quoteOfferIds,
    );
    const providerIds = [
      ...new Set(
        [
          ...input.providerIds.map((id) => this.optionalText(id)),
          ...discoveredOffers.map((offer) => offer.providerId),
        ].filter((id): id is string => id !== null),
      ),
    ].sort();

    await this.providers.lockProviderRowsForShareInTransaction(
      tx,
      providerIds,
    );
    if (quoteOfferIds.length > 0) {
      const lockedOffers =
        await this.quotes.lockQuoteOfferRowsForUpdateInTransaction(
          tx,
          quoteOfferIds,
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
    const lockedIds = await lockBudgetCategoriesForCost(tx, orderedIds, weddingPlanId);
    if (!lockedIds.includes(normalizedId))
      throw new BadRequestException(
        "budgetCategoryId is invalid for this plan",
      );
  }

  private async lockCost(tx: Tx, id: string) {
    return lockWeddingCost(tx, id);
  }

  private async lockPayment(tx: Tx, id: string) {
    return lockCostPayment(tx, id);
  }

  private async lockSchedule(tx: Tx, id: string) {
    return lockPaymentSchedule(tx, id);
  }

  private async cancelPendingSchedulesWhenPaid(
    tx: Tx,
    costId: string,
    status: WeddingCostStatus,
  ) {
    if (!schedulesToCancelOnStatus(status)) return;
    const closed = await listPaymentSchedules(tx, {
      where: {
        weddingCostId: costId,
        status: PaymentScheduleStatus.PENDING,
      },
      select: { id: true, weddingCost: { select: { weddingPlanId: true } } },
    });
    await updatePaymentSchedules(tx, {
      where: {
        weddingCostId: costId,
        status: PaymentScheduleStatus.PENDING,
      },
      data: {
        status: PaymentScheduleStatus.CANCELLED,
        paidAt: null,
        cancelledByPaidInFullAt: new Date(),
      },
    });
    // R4: the agreement is paid in full, so these payments are settled too.
    for (const schedule of closed) {
      await this.tasks?.syncLinkedTasks(
        tx,
        schedule.weddingCost.weddingPlanId,
        { scheduleId: schedule.id },
        true,
      );
    }
  }

  /**
   * RA-BE-25: the reminders the agreement's being paid in full cancelled
   * come back, with their tasks, once money is owed on it again (a payment
   * reversed, the total raised). A pending reminder is never more than what
   * is left (`PaymentSchedule_amount_at_write_integrity`), so one larger than
   * the new balance comes back at the balance.
   */
  private async restoreSchedulesWhenOwedAgain(
    tx: Tx,
    costId: string,
    status: WeddingCostStatus,
    remaining: Prisma.Decimal,
  ) {
    if (
      status === WeddingCostStatus.PAID ||
      status === WeddingCostStatus.CANCELLED ||
      remaining.lte(0)
    ) {
      return;
    }
    const restored = await listPaymentSchedules(tx, {
      where: {
        weddingCostId: costId,
        status: PaymentScheduleStatus.CANCELLED,
        cancelledByPaidInFullAt: { not: null },
      },
      orderBy: [{ dueDate: "asc" }, { createdAt: "asc" }],
      include: scheduleInclude,
    });
    for (const schedule of restored) {
      await updatePaymentSchedule(tx, {
        where: { id: schedule.id },
        data: {
          status: PaymentScheduleStatus.PENDING,
          paidAt: null,
          cancelledByPaidInFullAt: null,
          ...(schedule.amount.gt(remaining) ? { amount: remaining } : {}),
        },
      });
      await this.tasks?.syncLinkedTasks(
        tx,
        schedule.weddingCost.weddingPlanId,
        { scheduleId: schedule.id },
        false,
      );
    }
  }

  /**
   * R4: an agreement with someone outside books its item; cancelling it, or
   * moving it to another item, may unbook one. `budgetCategoryIds` are the
   * items this change touched.
   */
  private async syncItemTasks(
    tx: Tx,
    weddingPlanId: string,
    budgetCategoryIds: readonly string[],
  ) {
    const { finance, tasks } = this;
    if (!finance || !tasks) return;
    for (const budgetCategoryId of new Set(budgetCategoryIds)) {
      await tasks.syncLinkedTasks(
        tx,
        weddingPlanId,
        { budgetCategoryId },
        await isPlanItemBooked(
          tx,
          { providers: this.providers, finance },
          weddingPlanId,
          budgetCategoryId,
        ),
      );
    }
  }

  /**
   * Whether the reader may see this cost, decided exactly as `getCost`
   * does; for the cost's receipts (V1 checklist 4.4).
   */
  async assertCostVisibleInTransaction(
    tx: Tx,
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<void> {
    // Read on the caller's transaction: a read from the pool here held the
    // transaction's connection while waiting for a second one, and the
    // receipts screen asks for every paid agreement's receipts at once.
    const identity = await this.costIdentityOrThrow(id, tx);
    const access = await this.permissions.assertMoneyReadableInTransaction(
      tx,
      identity.weddingPlanId,
      currentUser,
    );
    const scopedCostIds = await this.scopedCostIdsInTransaction(tx, access);
    if (scopedCostIds && !scopedCostIds.includes(id)) {
      throw new NotFoundException("Wedding cost not found");
    }
    const liveFilter = await this.permissions.liveAuthorizationFilter(
      tx,
      access,
      currentUser.id,
      ["canViewMoney"],
    );
    const cost = await findVisibleWeddingCost(tx, {
      where: { id, weddingPlanId: identity.weddingPlanId, ...liveFilter },
      select: { weddingPlanId: true },
    });
    if (!cost) throw new NotFoundException("Wedding cost not found");
  }

  /**
   * Whether the user may change this cost, decided exactly as `deleteCost`
   * does, with the cost row locked; for its receipts (V1 checklist 4.4).
   */
  async assertCostManageableInTransaction(
    tx: Tx,
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<void> {
    const current = await this.costOrThrow(id, tx);
    const context = await this.permissions.assertMoneyManageableInTransaction(
      tx,
      current.weddingPlanId,
      currentUser,
    );
    await this.assertScopedCostInTransaction(tx, context, id);
    await this.lockCost(tx, id);
  }

  /** The account a new cost is private to, or null for the shared plan (V1 checklist 4.10). */
  private privateOwnerForNewCost(
    context: PlanAccessContext,
    currentUser: AuthenticatedUser,
    isPrivate: boolean | undefined,
  ): string | null {
    if (!isPrivate) return null;
    if (!seesWholePlan(context)) {
      throw new ForbiddenException({
        statusCode: 403,
        code: "COST_PRIVACY_NOT_ALLOWED",
        message: "Only the plan owner or partner records a private cost",
      });
    }
    return currentUser.id;
  }

  private async scopedCostIdsInTransaction(
    tx: Tx,
    context: PlanAccessContext,
  ): Promise<string[] | null> {
    const contributed =
      seesWholePlan(context) || !context.sharedMember
        ? null
        : await this.requiredContributorScope().qualifyingEntityIdsInTransaction(
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
    // V1 checklist 4.10: another account's private costs never show.
    return excludeOthersPrivateCosts(
      tx,
      context.plan.id,
      readerUserId(context),
      contributed,
    );
  }

  private async assertScopedCostInTransaction(
    tx: Tx,
    context: PlanAccessContext,
    costId: string,
  ): Promise<void> {
    // V1 checklist 4.10: another account's private cost reads as missing.
    if (await isOthersPrivateCost(tx, costId, readerUserId(context))) {
      throw new NotFoundException("Wedding cost not found");
    }
    if (seesWholePlan(context) || !context.sharedMember) return;
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
    if (seesWholePlan(context) || !context.sharedMember) return;
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

  private async recordMoneyEvent(
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
    if (context.isOwner) return null;
    if (!this.contributionHistory) {
      throw new Error("ContributionHistoryService is required for contributor money writes");
    }
    // V1 checklist 4.10: a private cost leaves no trace in the history the
    // rest of the plan reads.
    if (
      (input.entityType === ContributionEntityType.WEDDING_COST ||
        input.entityType === ContributionEntityType.PAYMENT_SCHEDULE) &&
      (await isPrivateCostEntity(tx, input.entityType, input.entityId))
    ) {
      return null;
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

  private async costOrThrow(id: string, client: Tx = this.prisma) {
    const cost = await findWeddingCost(client, {
      where: { id },
      include: weddingCostResponseInclude,
    });
    if (!cost) throw new NotFoundException("Wedding cost not found");
    return cost;
  }

  private async costIdentityOrThrow(id: string, client: Tx = this.prisma) {
    const cost = await findWeddingCost(client, {
      where: { id },
      select: { weddingPlanId: true },
    });
    if (!cost) throw new NotFoundException("Wedding cost not found");
    return cost;
  }

  private async paymentOrThrow(id: string) {
    const payment = await findCostPayment(this.prisma, {
      where: { id },
      include: paymentInclude,
    });
    if (!payment) throw new NotFoundException("Cost payment not found");
    return payment;
  }

  private async paymentIdentityOrThrow(id: string) {
    const payment = await findCostPayment(this.prisma, {
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
    const schedule = await findPaymentSchedule(this.prisma, {
      where: { id },
      include: scheduleInclude,
    });
    if (!schedule) throw new NotFoundException("Payment schedule not found");
    return schedule;
  }

  // Marketplace owns the provider name shown on costs, payments and
  // schedules; it is read once per response through the provider port.
  private async providerNamesFor(
    client: Tx,
    providerIds: ReadonlyArray<string | null>,
  ): Promise<Map<string, string>> {
    const ids = [
      ...new Set(providerIds.filter((id): id is string => id !== null)),
    ];
    const providers = await this.providers.getProviders(client, ids);
    return new Map(
      providers.map((provider) => [provider.id, provider.businessName]),
    );
  }

  private async providerIdsMatchingSearch(
    client: Tx,
    weddingPlanId: string,
    search: string,
  ): Promise<string[]> {
    const costs = await listWeddingCosts(client, {
      where: { weddingPlanId, providerId: { not: null } },
      select: { providerId: true },
      distinct: ["providerId"],
    });
    return this.providers.filterProviderIdsByBusinessName(
      client,
      costs.map((cost) => cost.providerId).filter((id): id is string => id !== null),
      search,
    );
  }

  private async presentCosts(
    client: Tx,
    costs: WeddingCostWithDetails[],
  ): Promise<WeddingCostResponse[]> {
    const names = await this.providerNamesFor(
      client,
      costs.map((cost) => cost.providerId),
    );
    return costs.map((cost) =>
      toWeddingCostResponse(
        cost,
        cost.providerId === null ? null : (names.get(cost.providerId) ?? null),
      ),
    );
  }

  private async presentCost(
    client: Tx,
    cost: WeddingCostWithDetails,
  ): Promise<WeddingCostResponse> {
    const [response] = await this.presentCosts(client, [cost]);
    return response;
  }

  private async presentPayments(
    client: Tx,
    payments: PaymentWithDetails[],
  ): Promise<CostPaymentResponse[]> {
    const names = await this.providerNamesFor(
      client,
      payments.map((payment) => payment.weddingCost.providerId),
    );
    return payments.map((payment) =>
      this.paymentResponse(
        payment,
        payment.weddingCost.providerId === null
          ? null
          : (names.get(payment.weddingCost.providerId) ?? null),
      ),
    );
  }

  private async presentPayment(
    client: Tx,
    payment: PaymentWithDetails,
  ): Promise<CostPaymentResponse> {
    const [response] = await this.presentPayments(client, [payment]);
    return response;
  }

  private async presentSchedules(
    client: Tx,
    schedules: ScheduleWithDetails[],
  ): Promise<PaymentScheduleResponse[]> {
    const names = await this.providerNamesFor(
      client,
      schedules.map((schedule) => schedule.weddingCost.providerId),
    );
    return schedules.map((schedule) =>
      this.scheduleResponse(
        schedule,
        schedule.weddingCost.providerId === null
          ? null
          : (names.get(schedule.weddingCost.providerId) ?? null),
      ),
    );
  }

  private async presentSchedule(
    client: Tx,
    schedule: ScheduleWithDetails,
  ): Promise<PaymentScheduleResponse> {
    const [response] = await this.presentSchedules(client, [schedule]);
    return response;
  }

  private paymentResponse(
    payment: PaymentWithDetails,
    providerName: string | null,
  ): CostPaymentResponse {
    return {
      id: payment.id,
      costId: payment.weddingCostId,
      weddingPlanId: payment.weddingCost.weddingPlanId,
      budgetCategoryId: payment.weddingCost.budgetCategoryId,
      categoryName: payment.weddingCost.budgetCategory.name,
      providerId: payment.weddingCost.providerId,
      providerName,
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
    providerName: string | null,
  ): PaymentScheduleResponse {
    return {
      id: schedule.id,
      costId: schedule.weddingCostId,
      weddingCostId: schedule.weddingCostId,
      weddingPlanId: schedule.weddingCost.weddingPlanId,
      budgetCategoryId: schedule.weddingCost.budgetCategoryId,
      categoryName: schedule.weddingCost.budgetCategory.name,
      providerId: schedule.weddingCost.providerId,
      providerName,
      costTitle: schedule.weddingCost.title,
      amount: schedule.amount.toString(),
      amountDue:
        schedule.status === PaymentScheduleStatus.PENDING
          ? scheduleAmountDue(
              schedule.amount,
              schedule.weddingCost.totalAmount,
              schedule.weddingCost.paidAmount,
            ).toString()
          : "0",
      costRemainingAmount: Prisma.Decimal.max(
        schedule.weddingCost.totalAmount.minus(schedule.weddingCost.paidAmount),
        0,
      ).toString(),
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

  private assertCostPayable(status: WeddingCostStatus) {
    raiseFinanceViolation(payableViolation(status));
  }

  private positiveAmount(value: string | number, field: string) {
    const amount = new Prisma.Decimal(requiredMoneyAmount(value, field));
    raiseFinanceViolation(positiveAmountViolation(amount, field));
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

/** The account reading through this context (the owner or the member). */
function readerUserId(context: PlanAccessContext): string {
  return context.sharedMember?.userId ?? context.plan.ownerUserId;
}

/** The ids both lists allow; a null list allows every id. */
function intersectIds(
  first: string[] | null,
  second: string[] | null,
): string[] | null {
  if (first === null) return second;
  if (second === null) return first;
  const allowed = new Set(second);
  return first.filter((id) => allowed.has(id));
}
