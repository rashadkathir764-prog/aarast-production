import { NotFoundException } from '@nestjs/common';
import {
  FundingSourceKind,
  FundingSourceStatus,
  LoanRepaymentStatus,
  Prisma,
} from '@prisma/client';

const withRepayments = Prisma.validator<Prisma.FundingSourceInclude>()({
  repayments: { orderBy: [{ dueDate: 'asc' }, { createdAt: 'asc' }] },
});

export type FundingSourceWithRepayments = Prisma.FundingSourceGetPayload<{
  include: typeof withRepayments;
}>;

export interface FundingSourceValues {
  kind: FundingSourceKind;
  sourceName: string;
  sourcePhone: string | null;
  amount: Prisma.Decimal;
  status: FundingSourceStatus;
  receivedAt: Date | null;
  expectedAt: Date | null;
  note: string | null;
}

export interface LoanRepaymentValues {
  amount?: Prisma.Decimal;
  dueDate?: Date | null;
  paidAt?: Date | null;
  status?: LoanRepaymentStatus;
  note?: string | null;
}

/** A plan's funding sources; LOAN rows only when [includeLoans]. */
export function listFundingSources(
  tx: Prisma.TransactionClient,
  weddingPlanId: string,
  includeLoans: boolean,
): Promise<FundingSourceWithRepayments[]> {
  return tx.fundingSource.findMany({
    where: {
      weddingPlanId,
      ...(includeLoans ? {} : { kind: { not: FundingSourceKind.LOAN } }),
    },
    include: withRepayments,
    orderBy: [{ createdAt: 'asc' }],
  });
}

export function insertFundingSource(
  tx: Prisma.TransactionClient,
  weddingPlanId: string,
  values: FundingSourceValues,
): Promise<FundingSourceWithRepayments> {
  return tx.fundingSource.create({
    data: { weddingPlanId, ...values },
    include: withRepayments,
  });
}

export function updateFundingSource(
  tx: Prisma.TransactionClient,
  id: string,
  values: Partial<FundingSourceValues>,
): Promise<FundingSourceWithRepayments> {
  return tx.fundingSource.update({
    where: { id },
    data: values,
    include: withRepayments,
  });
}

/** Repayments go with their loan (`onDelete: Cascade`). */
export async function deleteFundingSource(tx: Prisma.TransactionClient, id: string) {
  await tx.fundingSource.delete({ where: { id } });
}

export function findFundingSource(
  tx: Prisma.TransactionClient,
  id: string,
): Promise<FundingSourceWithRepayments | null> {
  return tx.fundingSource.findUnique({ where: { id }, include: withRepayments });
}

/** Locks a funding source row, then reads it with its repayments. */
export async function lockFundingSource(
  tx: Prisma.TransactionClient,
  id: string,
): Promise<FundingSourceWithRepayments> {
  const rows = await tx.$queryRaw<Array<{ id: string }>>(
    Prisma.sql`SELECT "id" FROM "FundingSource" WHERE "id" = ${id} FOR UPDATE`,
  );
  if (rows.length === 0) throw new NotFoundException('Funding source not found');
  return tx.fundingSource.findUniqueOrThrow({ where: { id }, include: withRepayments });
}

export function insertLoanRepayment(
  tx: Prisma.TransactionClient,
  fundingSourceId: string,
  values: { amount: Prisma.Decimal; dueDate: Date | null; note: string | null },
) {
  return tx.loanRepayment.create({ data: { fundingSourceId, ...values } });
}

export function findLoanRepayment(tx: Prisma.TransactionClient, id: string) {
  return tx.loanRepayment.findUnique({
    where: { id },
    include: { fundingSource: { select: { weddingPlanId: true } } },
  });
}

export function updateLoanRepayment(
  tx: Prisma.TransactionClient,
  id: string,
  values: LoanRepaymentValues,
) {
  return tx.loanRepayment.update({ where: { id }, data: values });
}

export async function deleteLoanRepayment(tx: Prisma.TransactionClient, id: string) {
  await tx.loanRepayment.delete({ where: { id } });
}

/** Account erasure: a plan's funding sources and, by cascade, their repayments. */
export async function deletePlanFundingSources(
  tx: Prisma.TransactionClient,
  weddingPlanIds: readonly string[],
) {
  await tx.fundingSource.deleteMany({ where: { weddingPlanId: { in: [...weddingPlanIds] } } });
}
