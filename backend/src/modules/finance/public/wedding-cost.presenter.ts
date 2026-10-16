import {
  CostPayer,
  CostPaymentType,
  Prisma,
  WeddingCostStatus,
} from "@prisma/client";

// Finance's own relations only. The provider name on a cost belongs to
// marketplace and is read through its port by whoever presents the cost.
export const weddingCostResponseInclude =
  Prisma.validator<Prisma.WeddingCostInclude>()({
    budgetCategory: { select: { name: true } },
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
  /** Who is expected to pay; payerName names them (e.g. «الوالد»). */
  payer: CostPayer | null;
  payerName: string | null;
  note: string | null;
  /** V1 checklist 4.10: seen only by the account that recorded it. */
  isPrivate: boolean;
  paymentsCount: number;
  paymentSchedulesCount: number;
  createdAt: Date;
  updatedAt: Date;
}

export function toWeddingCostResponse(
  cost: WeddingCostWithDetails,
  providerName: string | null,
): WeddingCostResponse {
  return {
    id: cost.id,
    weddingPlanId: cost.weddingPlanId,
    budgetCategoryId: cost.budgetCategoryId,
    categoryName: cost.budgetCategory.name,
    providerId: cost.providerId,
    providerName,
    quoteOfferId: cost.quoteOfferId,
    title: cost.title,
    partyName: cost.partyName,
    partyPhone: cost.partyPhone,
    totalAmount: cost.totalAmount.toString(),
    paidAmount: cost.paidAmount.toString(),
    remainingAmount: cost.totalAmount.minus(cost.paidAmount).toString(),
    agreementDate: cost.agreementDate,
    status: cost.status,
    payer: cost.payer,
    payerName: cost.payerName,
    note: cost.note,
    isPrivate: cost.privateToUserId !== null,
    paymentsCount: cost._count.payments,
    paymentSchedulesCount: cost._count.paymentSchedules,
    createdAt: cost.createdAt,
    updatedAt: cost.updatedAt,
  };
}
