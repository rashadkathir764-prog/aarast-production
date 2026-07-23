import { CostPaymentType, Prisma, WeddingCostStatus } from "@prisma/client";

export const weddingCostResponseInclude =
  Prisma.validator<Prisma.WeddingCostInclude>()({
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

export type WeddingCostWithDetails = Prisma.WeddingCostGetPayload<{
  include: typeof weddingCostResponseInclude;
}>;

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

export function toWeddingCostResponse(
  cost: WeddingCostWithDetails,
): WeddingCostResponse {
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
