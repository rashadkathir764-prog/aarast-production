import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import {
  CostPaymentType,
  PaymentScheduleStatus,
  Prisma,
  ProviderStatus,
  QuoteOfferStatus,
  WeddingCostStatus,
} from "@prisma/client";
import { AuthenticatedUser } from "../auth/authenticated-user.interface";
import { paymentsRecordedTotal } from "../common/observability/metrics";
import { runSerializableTransaction } from "../common/prisma/serializable-transaction";
import { requiredMoneyAmount } from "../common/validation/money";
import { PrismaService } from "../prisma/prisma.service";
import { PermissionService } from "../sharing/permission.service";
import { CreateCostPaymentDto } from "./dto/create-cost-payment.dto";
import { CreatePaymentScheduleDto } from "./dto/create-payment-schedule.dto";
import { CreateWeddingCostDto } from "./dto/create-wedding-cost.dto";
import { ListCostPaymentsQueryDto } from "./dto/list-cost-payments-query.dto";
import { ListCostsQueryDto } from "./dto/list-costs-query.dto";
import { PayPaymentScheduleDto } from "./dto/pay-payment-schedule.dto";
import { ReverseCostPaymentDto } from "./dto/reverse-cost-payment.dto";
import { UpdatePaymentScheduleDto } from "./dto/update-payment-schedule.dto";
import { UpdateWeddingCostDto } from "./dto/update-wedding-cost.dto";

const costInclude = Prisma.validator<Prisma.WeddingCostInclude>()({
  budgetCategory: { select: { name: true } },
  provider: { select: { businessName: true } },
  _count: {
    select: {
      payments: {
        where: {
          entryType: CostPaymentType.PAYMENT,
          reversedBy: null,
        },
      },
      paymentSchedules: true,
    },
  },
});

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

type CostWithDetails = Prisma.WeddingCostGetPayload<{
  include: typeof costInclude;
}>;
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

export interface WeddingCostResponse {
  id: string;
  weddingPlanId: string;
  budgetCategoryId: string;
  categoryName: string;
  providerId: string | null;
  providerName: string | null;
  quoteOfferId: string | null;
  title: string;
  partyName: string | null;
  partyPhone: string | null;
  totalAmount: string;
  paidAmount: string;
  remainingAmount: string;
  agreementDate: Date | null;
  status: WeddingCostStatus;
  note: string | null;
  paymentsCount: number;
  paymentSchedulesCount: number;
  createdAt: Date;
  updatedAt: Date;
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
    private readonly permissions: PermissionService,
  ) {}

  async createCost(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    dto: CreateWeddingCostDto,
  ): Promise<WeddingCostResponse> {
    await this.permissions.assertMoneyManageable(
      weddingPlanId,
      currentUser,
    );
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
      const cost = await runSerializableTransaction(
        this.prisma,
        async (tx) => {
          const plan = await this.lockPlan(tx, weddingPlanId);
          await this.assertCategory(tx, dto.budgetCategoryId, weddingPlanId);
          const counterparty = await this.normalizeCounterparty(tx, {
            weddingPlanId,
            planCurrency: plan.currency,
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
          return tx.weddingCost.findUniqueOrThrow({
            where: { id: created.id },
            include: costInclude,
          });
        },
      );
      if (initialPayment.gt(0)) paymentsRecordedTotal.inc();
      return this.costResponse(cost);
    } catch (error) {
      this.rethrowKnownPrismaError(error);
    }
  }

  async listCosts(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    query: ListCostsQueryDto,
  ): Promise<PaginatedResponse<WeddingCostResponse>> {
    await this.permissions.assertMoneyReadable(weddingPlanId, currentUser);
    const page = query.page ?? 1;
    const pageSize = query.limit ?? 50;
    const search = query.search?.trim();
    const where: Prisma.WeddingCostWhereInput = {
      weddingPlanId,
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
    const [costs, total] = await this.prisma.$transaction([
      this.prisma.weddingCost.findMany({
        where,
        include: costInclude,
        orderBy: [{ createdAt: "desc" }, { id: "desc" }],
        skip: (page - 1) * pageSize,
        take: pageSize,
      }),
      this.prisma.weddingCost.count({ where }),
    ]);
    return {
      items: costs.map((cost) => this.costResponse(cost)),
      page,
      pageSize,
      total,
      totalPages: total === 0 ? 0 : Math.ceil(total / pageSize),
    };
  }

  async getCost(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<WeddingCostResponse> {
    const cost = await this.costOrThrow(id);
    await this.permissions.assertMoneyReadable(cost.weddingPlanId, currentUser);
    return this.costResponse(cost);
  }

  async updateCost(
    currentUser: AuthenticatedUser,
    id: string,
    dto: UpdateWeddingCostDto,
  ): Promise<WeddingCostResponse> {
    const current = await this.costOrThrow(id);
    const access = await this.permissions.assertMoneyManageable(
      current.weddingPlanId,
      currentUser,
    );
    if (current.status === WeddingCostStatus.CANCELLED) {
      throw new ConflictException("Cancelled costs cannot be edited");
    }

    try {
      return await runSerializableTransaction(
        this.prisma,
        async (tx) => {
          const locked = await this.lockCost(tx, id);
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
          await this.assertCategory(tx, budgetCategoryId, locked.weddingPlanId);
          const counterparty = await this.normalizeCounterparty(tx, {
            weddingPlanId: locked.weddingPlanId,
            planCurrency: access.plan.currency,
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
            include: costInclude,
          });
          await this.cancelPendingSchedulesWhenPaid(tx, id, status);
          return this.costResponse(updated);
        },
      );
    } catch (error) {
      this.rethrowKnownPrismaError(error);
    }
  }

  async deleteCost(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<{ deleted: true }> {
    const current = await this.costOrThrow(id);
    await this.permissions.assertMoneyManageable(
      current.weddingPlanId,
      currentUser,
    );
    await this.prisma.$transaction(async (tx) => {
      const locked = await this.lockCost(tx, id);
      const paymentsCount = await tx.costPayment.count({
        where: { weddingCostId: id },
      });
      if (paymentsCount > 0 || !locked.paidAmount.isZero()) {
        throw new ConflictException(
          "A cost with payment history cannot be deleted",
        );
      }
      await tx.weddingCost.delete({ where: { id } });
    });
    return { deleted: true };
  }

  async cancelCost(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<WeddingCostResponse> {
    const current = await this.costOrThrow(id);
    await this.permissions.assertMoneyManageable(
      current.weddingPlanId,
      currentUser,
    );
    return this.prisma.$transaction(async (tx) => {
      const locked = await this.lockCost(tx, id);
      if (locked.status === WeddingCostStatus.CANCELLED) {
        return this.costResponse(
          await tx.weddingCost.findUniqueOrThrow({
            where: { id },
            include: costInclude,
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
        include: costInclude,
      });
      return this.costResponse(cancelled);
    });
  }

  async createPayment(
    currentUser: AuthenticatedUser,
    costId: string,
    dto: CreateCostPaymentDto,
  ): Promise<CostPaymentResponse> {
    const current = await this.costOrThrow(costId);
    await this.permissions.assertMoneyManageable(
      current.weddingPlanId,
      currentUser,
    );
    const amount = this.positiveAmount(dto.amount, "amount");
    const response = await runSerializableTransaction(
      this.prisma,
      async (tx) => {
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
    const cost = await this.costOrThrow(costId);
    await this.permissions.assertMoneyReadable(cost.weddingPlanId, currentUser);
    const payments = await this.prisma.costPayment.findMany({
      where: { weddingCostId: costId },
      include: paymentInclude,
      orderBy: [{ paidAt: "desc" }, { createdAt: "desc" }],
    });
    return payments.map((payment) => this.paymentResponse(payment));
  }

  async listPaymentsForPlan(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    query: ListCostPaymentsQueryDto,
  ): Promise<PaginatedResponse<CostPaymentResponse>> {
    await this.permissions.assertMoneyReadable(weddingPlanId, currentUser);
    const page = query.page ?? 1;
    const pageSize = query.limit ?? 50;
    const where: Prisma.CostPaymentWhereInput = {
      weddingCost: { weddingPlanId },
    };
    const [payments, total] = await this.prisma.$transaction([
      this.prisma.costPayment.findMany({
        where,
        include: paymentInclude,
        orderBy: [{ paidAt: "desc" }, { createdAt: "desc" }],
        skip: (page - 1) * pageSize,
        take: pageSize,
      }),
      this.prisma.costPayment.count({ where }),
    ]);
    return {
      items: payments.map((payment) => this.paymentResponse(payment)),
      page,
      pageSize,
      total,
      totalPages: total === 0 ? 0 : Math.ceil(total / pageSize),
    };
  }

  async getPayment(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<CostPaymentResponse> {
    const payment = await this.paymentOrThrow(id);
    await this.permissions.assertMoneyReadable(
      payment.weddingCost.weddingPlanId,
      currentUser,
    );
    return this.paymentResponse(payment);
  }

  async reversePayment(
    currentUser: AuthenticatedUser,
    id: string,
    dto: ReverseCostPaymentDto,
  ): Promise<CostPaymentResponse> {
    const current = await this.paymentOrThrow(id);
    await this.permissions.assertMoneyManageable(
      current.weddingCost.weddingPlanId,
      currentUser,
    );
    return runSerializableTransaction(
      this.prisma,
      async (tx) => {
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
        return this.paymentResponse(reversal);
      },
    );
  }

  async createSchedule(
    currentUser: AuthenticatedUser,
    costId: string,
    dto: CreatePaymentScheduleDto,
  ): Promise<PaymentScheduleResponse> {
    const current = await this.costOrThrow(costId);
    await this.permissions.assertMoneyManageable(
      current.weddingPlanId,
      currentUser,
    );
    const amount = this.positiveAmount(dto.amount, "amount");
    return runSerializableTransaction(
      this.prisma,
      async (tx) => {
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
        return this.scheduleResponse(schedule);
      },
    );
  }

  async listSchedulesForCost(
    currentUser: AuthenticatedUser,
    costId: string,
  ): Promise<PaymentScheduleResponse[]> {
    const cost = await this.costOrThrow(costId);
    await this.permissions.assertMoneyReadable(cost.weddingPlanId, currentUser);
    const schedules = await this.prisma.paymentSchedule.findMany({
      where: { weddingCostId: costId },
      include: scheduleInclude,
      orderBy: [{ dueDate: "asc" }, { createdAt: "asc" }],
    });
    return schedules.map((schedule) => this.scheduleResponse(schedule));
  }

  async listDueSchedulesForPlan(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
  ): Promise<PaymentScheduleResponse[]> {
    await this.permissions.assertMoneyReadable(weddingPlanId, currentUser);
    const through = new Date(
      this.startOfTodayInRiyadh().getTime() + 30 * 24 * 60 * 60 * 1000,
    );
    const schedules = await this.prisma.paymentSchedule.findMany({
      where: {
        weddingCost: {
          weddingPlanId,
          status: { not: WeddingCostStatus.CANCELLED },
        },
        status: PaymentScheduleStatus.PENDING,
        dueDate: { lte: through },
      },
      include: scheduleInclude,
      orderBy: [{ dueDate: "asc" }, { createdAt: "asc" }],
    });
    return schedules.map((schedule) => this.scheduleResponse(schedule));
  }

  async updateSchedule(
    currentUser: AuthenticatedUser,
    id: string,
    dto: UpdatePaymentScheduleDto,
  ): Promise<PaymentScheduleResponse> {
    const current = await this.scheduleOrThrow(id);
    await this.permissions.assertMoneyManageable(
      current.weddingCost.weddingPlanId,
      currentUser,
    );
    return runSerializableTransaction(
      this.prisma,
      async (tx) => {
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
        return this.scheduleResponse(updated);
      },
    );
  }

  async deleteSchedule(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<{ deleted: true }> {
    const current = await this.scheduleOrThrow(id);
    await this.permissions.assertMoneyManageable(
      current.weddingCost.weddingPlanId,
      currentUser,
    );
    await this.prisma.$transaction(async (tx) => {
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
      await tx.paymentSchedule.delete({ where: { id } });
    });
    return { deleted: true };
  }

  async cancelSchedule(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<PaymentScheduleResponse> {
    const current = await this.scheduleOrThrow(id);
    await this.permissions.assertMoneyManageable(
      current.weddingCost.weddingPlanId,
      currentUser,
    );
    return runSerializableTransaction(this.prisma, async (tx) => {
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
      return this.scheduleResponse(cancelled);
    });
  }

  async paySchedule(
    currentUser: AuthenticatedUser,
    id: string,
    dto: PayPaymentScheduleDto,
  ): Promise<CostPaymentResponse> {
    const current = await this.scheduleOrThrow(id);
    await this.permissions.assertMoneyManageable(
      current.weddingCost.weddingPlanId,
      currentUser,
    );
    const result = await runSerializableTransaction(
      this.prisma,
      async (tx) => {
        const cost = await this.lockCost(tx, current.weddingCostId);
        await this.lockSchedule(tx, id);
        const schedule = await tx.paymentSchedule.findUnique({ where: { id } });
        if (!schedule)
          throw new NotFoundException("Payment schedule not found");
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
          return { payment: this.paymentResponse(existing), created: false };
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
        await tx.paymentSchedule.update({
          where: { id },
          data: { status: PaymentScheduleStatus.PAID, paidAt },
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
        return { payment: this.paymentResponse(payment), created: true };
      },
    );
    if (result.created) paymentsRecordedTotal.inc();
    return result.payment;
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

  private async lockPlan(tx: Tx, id: string) {
    const rows = await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`SELECT "id" FROM "WeddingPlan" WHERE "id" = ${id} FOR UPDATE`,
    );
    if (rows.length === 0)
      throw new NotFoundException("Wedding plan not found");
    return tx.weddingPlan.findUniqueOrThrow({ where: { id } });
  }

  private async assertCategory(tx: Tx, id: string, weddingPlanId: string) {
    const category = await tx.budgetCategory.findFirst({
      where: { id: id.trim(), weddingPlanId },
      select: { id: true },
    });
    if (!category)
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

  private async costOrThrow(id: string) {
    const cost = await this.prisma.weddingCost.findUnique({
      where: { id },
      include: costInclude,
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

  private async scheduleOrThrow(id: string) {
    const schedule = await this.prisma.paymentSchedule.findUnique({
      where: { id },
      include: scheduleInclude,
    });
    if (!schedule) throw new NotFoundException("Payment schedule not found");
    return schedule;
  }

  private costResponse(cost: CostWithDetails): WeddingCostResponse {
    return {
      id: cost.id,
      weddingPlanId: cost.weddingPlanId,
      budgetCategoryId: cost.budgetCategoryId,
      categoryName: cost.budgetCategory.name,
      providerId: cost.providerId,
      providerName: cost.provider?.businessName ?? null,
      quoteOfferId: cost.quoteOfferId,
      title: cost.title,
      partyName: cost.partyName,
      partyPhone: cost.partyPhone,
      totalAmount: cost.totalAmount.toString(),
      paidAmount: cost.paidAmount.toString(),
      remainingAmount: cost.totalAmount.minus(cost.paidAmount).toString(),
      agreementDate: cost.agreementDate,
      status: cost.status,
      note: cost.note,
      paymentsCount: cost._count.payments,
      paymentSchedulesCount: cost._count.paymentSchedules,
      createdAt: cost.createdAt,
      updatedAt: cost.updatedAt,
    };
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
