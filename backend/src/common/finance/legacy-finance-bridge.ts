import {
  DebtStatus,
  FinancialCommitment,
  FinancialCommitmentSourceType,
  FinancialCommitmentStatus,
  InstallmentStatus,
  Prisma,
} from "@prisma/client";
import { applyDebtPaymentDelta } from "../money/debt-balance";

export const LEGACY_DEBT_CATEGORY_NAME = "مستحقات قديمة";

export interface LegacyDebtRecord {
  id: string;
  weddingPlanId: string;
  creditorName: string;
  creditorPhone: string | null;
  title: string;
  totalAmount: Prisma.Decimal;
  paidAmount: Prisma.Decimal;
  dueDate: Date | null;
  status: DebtStatus;
  note: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface LegacyInstallmentRecord {
  id: string;
  debtId: string;
  amount: Prisma.Decimal;
  dueDate: Date | null;
  paidAt: Date | null;
  status: InstallmentStatus;
  note: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export function legacyDebtCategoryId(weddingPlanId: string): string {
  return `legacy-debt-category-${weddingPlanId}`;
}

export async function ensureLegacyDebtCategory(
  tx: Prisma.TransactionClient,
  weddingPlanId: string,
): Promise<string> {
  const id = legacyDebtCategoryId(weddingPlanId);
  await tx.budgetCategory.upsert({
    where: { id },
    update: { name: LEGACY_DEBT_CATEGORY_NAME },
    create: {
      id,
      weddingPlanId,
      name: LEGACY_DEBT_CATEGORY_NAME,
    },
  });
  return id;
}

export function legacyDebtCommitmentStatus(
  debt: Pick<LegacyDebtRecord, "totalAmount" | "paidAmount" | "status">,
): FinancialCommitmentStatus {
  if (debt.status === DebtStatus.CANCELLED) {
    return FinancialCommitmentStatus.CANCELLED;
  }
  const derived = applyDebtPaymentDelta(
    debt.totalAmount,
    debt.paidAmount,
    new Prisma.Decimal(0),
  );
  switch (derived.status) {
    case DebtStatus.PAID:
      return FinancialCommitmentStatus.PAID;
    case DebtStatus.PARTIALLY_PAID:
      return FinancialCommitmentStatus.PARTIALLY_PAID;
    case DebtStatus.CANCELLED:
      return FinancialCommitmentStatus.CANCELLED;
    case DebtStatus.OPEN:
    default:
      return FinancialCommitmentStatus.OPEN;
  }
}

export async function paidLegacyInstallmentsTotal(
  tx: Prisma.TransactionClient,
  debtId: string,
): Promise<Prisma.Decimal> {
  const aggregate = await tx.installment.aggregate({
    where: { debtId, status: InstallmentStatus.PAID },
    _sum: { amount: true },
  });
  return aggregate._sum.amount ?? new Prisma.Decimal(0);
}

export async function syncLegacyDebtCommitment(
  tx: Prisma.TransactionClient,
  debt: LegacyDebtRecord,
): Promise<FinancialCommitment> {
  const budgetCategoryId = await ensureLegacyDebtCategory(
    tx,
    debt.weddingPlanId,
  );
  const commitment = await tx.financialCommitment.upsert({
    where: { legacyDebtId: debt.id },
    update: {
      weddingPlanId: debt.weddingPlanId,
      budgetCategoryId,
      sourceType: FinancialCommitmentSourceType.MANUAL_DEBT,
      title: debt.title,
      partyName: debt.creditorName,
      partyPhone: debt.creditorPhone,
      totalAmount: debt.totalAmount,
      paidAmount: debt.paidAmount,
      dueDate: debt.dueDate,
      agreementDate: debt.createdAt,
      status: legacyDebtCommitmentStatus(debt),
      note: debt.note,
    },
    create: {
      weddingPlanId: debt.weddingPlanId,
      budgetCategoryId,
      sourceType: FinancialCommitmentSourceType.MANUAL_DEBT,
      title: debt.title,
      partyName: debt.creditorName,
      partyPhone: debt.creditorPhone,
      totalAmount: debt.totalAmount,
      paidAmount: debt.paidAmount,
      dueDate: debt.dueDate,
      agreementDate: debt.createdAt,
      status: legacyDebtCommitmentStatus(debt),
      note: debt.note,
      legacyDebtId: debt.id,
    },
  });

  await syncLegacyDebtBalancePaymentRecord(tx, debt, commitment);
  return commitment;
}

export async function removeLegacyDebtMirror(
  tx: Prisma.TransactionClient,
  legacyDebtId: string,
): Promise<void> {
  await tx.financialCommitment.deleteMany({
    where: { legacyDebtId },
  });
}

export async function syncLegacyInstallmentMirror(
  tx: Prisma.TransactionClient,
  installment: LegacyInstallmentRecord,
  debt?: LegacyDebtRecord,
): Promise<void> {
  const parentDebt =
    debt ??
    (await tx.debt.findUniqueOrThrow({
      where: { id: installment.debtId },
    }));
  const commitment = await syncLegacyDebtCommitment(tx, parentDebt);

  await tx.financialInstallment.upsert({
    where: { legacyInstallmentId: installment.id },
    update: {
      weddingPlanId: parentDebt.weddingPlanId,
      financialCommitmentId: commitment.id,
      budgetCategoryId: commitment.budgetCategoryId,
      amount: installment.amount,
      dueDate: installment.dueDate,
      paidAt: installment.paidAt,
      status: installment.status,
      note: installment.note,
    },
    create: {
      weddingPlanId: parentDebt.weddingPlanId,
      financialCommitmentId: commitment.id,
      budgetCategoryId: commitment.budgetCategoryId,
      amount: installment.amount,
      dueDate: installment.dueDate,
      paidAt: installment.paidAt,
      status: installment.status,
      note: installment.note,
      legacyInstallmentId: installment.id,
    },
  });

  await syncLegacyInstallmentPaymentRecord(tx, installment, commitment);
}

export async function removeLegacyInstallmentMirror(
  tx: Prisma.TransactionClient,
  legacyInstallmentId: string,
): Promise<void> {
  await tx.financialPaymentRecord.deleteMany({
    where: { legacyInstallmentId },
  });
  await tx.financialInstallment.deleteMany({
    where: { legacyInstallmentId },
  });
}

async function syncLegacyDebtBalancePaymentRecord(
  tx: Prisma.TransactionClient,
  debt: LegacyDebtRecord,
  commitment: FinancialCommitment,
): Promise<void> {
  if (debt.status === DebtStatus.CANCELLED) {
    await tx.financialPaymentRecord.deleteMany({
      where: { legacyDebtId: debt.id },
    });
    return;
  }

  const paidInstallmentsTotal = await paidLegacyInstallmentsTotal(tx, debt.id);
  const directPaid = debt.paidAmount.sub(paidInstallmentsTotal);
  const amount = directPaid.gt(0) ? directPaid : new Prisma.Decimal(0);
  if (amount.lte(0)) {
    await tx.financialPaymentRecord.deleteMany({
      where: { legacyDebtId: debt.id },
    });
    return;
  }

  await tx.financialPaymentRecord.upsert({
    where: { legacyDebtId: debt.id },
    update: {
      weddingPlanId: debt.weddingPlanId,
      financialCommitmentId: commitment.id,
      budgetCategoryId: commitment.budgetCategoryId,
      title: `دفعة مسجلة: ${debt.title}`,
      amount,
      paidAt: debt.updatedAt,
      note: debt.note,
    },
    create: {
      weddingPlanId: debt.weddingPlanId,
      financialCommitmentId: commitment.id,
      budgetCategoryId: commitment.budgetCategoryId,
      title: `دفعة مسجلة: ${debt.title}`,
      amount,
      paidAt: debt.updatedAt,
      note: debt.note,
      legacyDebtId: debt.id,
    },
  });
}

async function syncLegacyInstallmentPaymentRecord(
  tx: Prisma.TransactionClient,
  installment: LegacyInstallmentRecord,
  commitment: FinancialCommitment,
): Promise<void> {
  if (
    installment.status !== InstallmentStatus.PAID ||
    installment.amount.lte(0)
  ) {
    await tx.financialPaymentRecord.deleteMany({
      where: { legacyInstallmentId: installment.id },
    });
    return;
  }

  await tx.financialPaymentRecord.upsert({
    where: { legacyInstallmentId: installment.id },
    update: {
      weddingPlanId: commitment.weddingPlanId,
      financialCommitmentId: commitment.id,
      budgetCategoryId: commitment.budgetCategoryId,
      title: `قسط: ${commitment.title}`,
      amount: installment.amount,
      paidAt: installment.paidAt ?? installment.updatedAt,
      note: installment.note,
    },
    create: {
      weddingPlanId: commitment.weddingPlanId,
      financialCommitmentId: commitment.id,
      budgetCategoryId: commitment.budgetCategoryId,
      title: `قسط: ${commitment.title}`,
      amount: installment.amount,
      paidAt: installment.paidAt ?? installment.updatedAt,
      note: installment.note,
      legacyInstallmentId: installment.id,
    },
  });
}
