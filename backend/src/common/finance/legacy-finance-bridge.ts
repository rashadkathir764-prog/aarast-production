import {
  DebtStatus,
  FinancialCommitment,
  FinancialCommitmentSourceType,
  FinancialCommitmentStatus,
  FinancialPaymentRecordType,
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
  const commitment = await tx.financialCommitment.findUnique({
    where: { legacyDebtId },
  });
  if (!commitment) return;

  // Keep the commitment and every payment entry as financial history. Bring
  // the ledger back to zero with one compensating entry, remove only the
  // mutable installment projection, then mark the historical commitment
  // cancelled before the legacy Debt row is deleted.
  await appendLedgerToDesiredBalance(
    tx,
    { financialCommitmentId: commitment.id },
    new Prisma.Decimal(0),
    {
      weddingPlanId: commitment.weddingPlanId,
      financialCommitmentId: commitment.id,
      budgetCategoryId: commitment.budgetCategoryId,
      title: `إغلاق مستحق قديم: ${commitment.title}`,
      paidAt: new Date(),
      note: "قيد عكس تلقائي عند حذف المستحق القديم",
      legacyDebtId,
    },
  );
  await tx.financialInstallment.deleteMany({
    where: { financialCommitmentId: commitment.id },
  });
  await tx.financialCommitment.update({
    where: { id: commitment.id },
    data: {
      paidAmount: new Prisma.Decimal(0),
      status: FinancialCommitmentStatus.CANCELLED,
    },
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
  const mirror = await tx.financialInstallment.findUnique({
    where: { legacyInstallmentId },
  });
  const priorEntry = await tx.financialPaymentRecord.findFirst({
    where: { legacyInstallmentId },
    orderBy: { createdAt: "asc" },
  });
  if (mirror || priorEntry) {
    await appendLedgerToDesiredBalance(
      tx,
      { legacyInstallmentId },
      new Prisma.Decimal(0),
      {
        weddingPlanId: mirror?.weddingPlanId ?? priorEntry!.weddingPlanId,
        financialCommitmentId:
          mirror?.financialCommitmentId ?? priorEntry!.financialCommitmentId,
        budgetCategoryId:
          mirror?.budgetCategoryId ?? priorEntry!.budgetCategoryId,
        title: "عكس قسط قديم محذوف",
        paidAt: new Date(),
        note: "قيد عكس تلقائي عند حذف القسط القديم",
        legacyInstallmentId,
      },
    );
  }
  await tx.financialInstallment.deleteMany({
    where: { legacyInstallmentId },
  });
}

async function syncLegacyDebtBalancePaymentRecord(
  tx: Prisma.TransactionClient,
  debt: LegacyDebtRecord,
  commitment: FinancialCommitment,
): Promise<void> {
  const paidInstallmentsTotal = await paidLegacyInstallmentsTotal(tx, debt.id);
  const directPaid = debt.paidAmount.sub(paidInstallmentsTotal);
  const desired =
    debt.status !== DebtStatus.CANCELLED && directPaid.gt(0)
      ? directPaid
      : new Prisma.Decimal(0);
  await appendLedgerToDesiredBalance(
    tx,
    { legacyDebtId: debt.id },
    desired,
    {
      weddingPlanId: debt.weddingPlanId,
      financialCommitmentId: commitment.id,
      budgetCategoryId: commitment.budgetCategoryId,
      title: `دفعة مسجلة: ${debt.title}`,
      paidAt: debt.updatedAt,
      note: debt.note,
      legacyDebtId: debt.id,
    },
  );
}

async function syncLegacyInstallmentPaymentRecord(
  tx: Prisma.TransactionClient,
  installment: LegacyInstallmentRecord,
  commitment: FinancialCommitment,
): Promise<void> {
  const desired =
    installment.status === InstallmentStatus.PAID && installment.amount.gt(0)
      ? installment.amount
      : new Prisma.Decimal(0);
  await appendLedgerToDesiredBalance(
    tx,
    { legacyInstallmentId: installment.id },
    desired,
    {
      weddingPlanId: commitment.weddingPlanId,
      financialCommitmentId: commitment.id,
      budgetCategoryId: commitment.budgetCategoryId,
      title: `قسط: ${commitment.title}`,
      paidAt: installment.paidAt ?? installment.updatedAt,
      note: installment.note,
      legacyInstallmentId: installment.id,
    },
  );
}

interface LedgerEntryContext {
  weddingPlanId: string;
  financialCommitmentId: string;
  budgetCategoryId: string;
  title: string;
  paidAt: Date;
  note: string | null;
  legacyDebtId?: string;
  legacyInstallmentId?: string;
}

async function appendLedgerToDesiredBalance(
  tx: Prisma.TransactionClient,
  where: Prisma.FinancialPaymentRecordWhereInput,
  desired: Prisma.Decimal,
  context: LedgerEntryContext,
): Promise<void> {
  const entries = await tx.financialPaymentRecord.findMany({
    where,
    select: { amount: true, entryType: true },
  });
  const current = entries.reduce(
    (sum, entry) =>
      entry.entryType === FinancialPaymentRecordType.REVERSAL
        ? sum.sub(entry.amount)
        : sum.add(entry.amount),
    new Prisma.Decimal(0),
  );
  const delta = desired.sub(current);
  if (delta.equals(0)) return;

  await tx.financialPaymentRecord.create({
    data: {
      weddingPlanId: context.weddingPlanId,
      financialCommitmentId: context.financialCommitmentId,
      budgetCategoryId: context.budgetCategoryId,
      title:
        delta.lt(0) && !context.title.startsWith("عكس")
          ? `عكس: ${context.title}`
          : context.title,
      amount: delta.abs(),
      entryType:
        delta.lt(0)
          ? FinancialPaymentRecordType.REVERSAL
          : FinancialPaymentRecordType.PAYMENT,
      paidAt: context.paidAt,
      note: context.note,
      legacyDebtId: context.legacyDebtId,
      legacyInstallmentId: context.legacyInstallmentId,
    },
  });
}
