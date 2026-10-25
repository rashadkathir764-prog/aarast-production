import { ConflictException } from '@nestjs/common';
import {
  BudgetCategoryKind,
  CostPayer,
  FundingSourceKind,
  FundingSourceStatus,
  Prisma,
  WeddingCostStatus,
} from '@prisma/client';
import { normalizeBudgetCategoryName } from '../domain/cost-category-matching';
import {
  type MahrAgreement,
  type MahrSide,
  mahrAgreementViolation,
  mahrRemaining,
  mahrSideOf,
} from '../domain/mahr-policy';
import { deriveCostStatus } from '../domain/wedding-cost-aggregate';
import { raiseFinanceViolation } from '../internal/finance-violation.http';

/** The groom's mahr item and agreement, as c02 draws them. */
export const GROOM_MAHR_ITEM_NAME = 'المهر';
const GROOM_MAHR_PARTY = 'أهل العروسة';
/** The bride's mahr sources, as c05 draws them. */
const BRIDE_MAHR_RECEIVED = 'المهر من العريس';
const BRIDE_MAHR_REST = 'باقي المهر';

/** A plan without a wedding persona (a helper's plan) has no mahr side. */
export function mahrNotForPlan(): ConflictException {
  return new ConflictException({
    code: 'MAHR_NOT_FOR_PLAN',
    message: 'المهر يتسجّل في خطة العريس أو العروسة.',
  });
}

function mahrAlreadyRecorded(): ConflictException {
  return new ConflictException({
    code: 'MAHR_ALREADY_RECORDED',
    message: 'المهر مسجّل في هذي الخطة. عدّله من المال.',
  });
}

/**
 * Records a06's mahr in the plan's money, once, in the caller's transaction.
 *
 * The groom (PAYS): a MAHR item outside the budget with one agreement with
 * the bride's family, its handed-over part as a payment and the rest as a
 * payment schedule on its day; an item the plan already named «المهر» with no
 * agreement becomes that item (its allocation is dropped: the mahr is outside
 * the budget). The bride (RECEIVES): MAHR funding sources, the received part
 * RECEIVED and the rest PLEDGED with its expected day.
 */
export async function recordMahrInTransaction(
  tx: Prisma.TransactionClient,
  weddingPlanId: string,
  side: MahrSide,
  agreement: MahrAgreement,
  recordedAt: Date,
): Promise<void> {
  const rest = mahrRemaining(agreement);
  if (side === 'RECEIVES') {
    const existing = await tx.fundingSource.count({
      where: { weddingPlanId, kind: FundingSourceKind.MAHR },
    });
    if (existing > 0) throw mahrAlreadyRecorded();
    if (agreement.settled.gt(0)) {
      await tx.fundingSource.create({
        data: {
          weddingPlanId,
          kind: FundingSourceKind.MAHR,
          sourceName: BRIDE_MAHR_RECEIVED,
          amount: agreement.settled,
          status: FundingSourceStatus.RECEIVED,
          receivedAt: recordedAt,
        },
      });
    }
    if (rest.amount.gt(0)) {
      await tx.fundingSource.create({
        data: {
          weddingPlanId,
          kind: FundingSourceKind.MAHR,
          sourceName: agreement.settled.gt(0)
            ? BRIDE_MAHR_REST
            : BRIDE_MAHR_RECEIVED,
          amount: rest.amount,
          status: FundingSourceStatus.PLEDGED,
          expectedAt: rest.dueAt,
        },
      });
    }
    return;
  }

  const existingMahr = await tx.budgetCategory.findFirst({
    where: { weddingPlanId, kind: BudgetCategoryKind.MAHR },
    select: { id: true },
  });
  if (existingMahr) throw mahrAlreadyRecorded();
  const normalizedName = normalizeBudgetCategoryName(GROOM_MAHR_ITEM_NAME);
  const named = await tx.budgetCategory.findUnique({
    where: { weddingPlanId_normalizedName: { weddingPlanId, normalizedName } },
    select: {
      id: true,
      _count: {
        select: {
          weddingCosts: { where: { status: { not: WeddingCostStatus.CANCELLED } } },
        },
      },
    },
  });
  if (named && named._count.weddingCosts > 0) throw mahrAlreadyRecorded();
  const category = named
    ? await tx.budgetCategory.update({
        where: { id: named.id },
        data: { kind: BudgetCategoryKind.MAHR, allocatedAmount: null },
        select: { id: true },
      })
    : await tx.budgetCategory.create({
        data: {
          weddingPlanId,
          name: GROOM_MAHR_ITEM_NAME,
          normalizedName,
          kind: BudgetCategoryKind.MAHR,
        },
        select: { id: true },
      });
  await tx.weddingCost.create({
    data: {
      weddingPlanId,
      budgetCategoryId: category.id,
      title: GROOM_MAHR_ITEM_NAME,
      partyName: GROOM_MAHR_PARTY,
      totalAmount: agreement.total,
      paidAmount: agreement.settled,
      status: deriveCostStatus(agreement.total, agreement.settled),
      payer: CostPayer.GROOM,
      ...(agreement.settled.gt(0)
        ? { payments: { create: [{ amount: agreement.settled, paidAt: recordedAt }] } }
        : {}),
      ...(rest.amount.gt(0) && rest.dueAt
        ? { paymentSchedules: { create: [{ amount: rest.amount, dueDate: rest.dueAt }] } }
        : {}),
    },
  });
}

/**
 * a06 for a plan: its side follows the plan's persona (C1), the amounts
 * follow the mahr policy, then it is recorded once.
 */
export async function recordPlanMahrInTransaction(
  tx: Prisma.TransactionClient,
  weddingPlanId: string,
  persona: string | null,
  agreement: MahrAgreement,
  recordedAt: Date,
): Promise<void> {
  const side = mahrSideOf(persona);
  if (!side) throw mahrNotForPlan();
  raiseFinanceViolation(mahrAgreementViolation(agreement));
  await recordMahrInTransaction(tx, weddingPlanId, side, agreement, recordedAt);
}

/** Whether the plan's mahr is recorded, on either side. */
export async function hasRecordedMahr(
  client: Prisma.TransactionClient,
  weddingPlanId: string,
): Promise<boolean> {
  const [items, sources] = await Promise.all([
    client.budgetCategory.count({
      where: { weddingPlanId, kind: BudgetCategoryKind.MAHR },
    }),
    client.fundingSource.count({
      where: { weddingPlanId, kind: FundingSourceKind.MAHR },
    }),
  ]);
  return items + sources > 0;
}
