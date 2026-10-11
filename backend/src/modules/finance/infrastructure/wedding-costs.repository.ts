import { NotFoundException } from '@nestjs/common';
import { CostPaymentType, PaymentScheduleStatus, Prisma, WeddingCostStatus, type CostPayer, type WeddingCost } from '@prisma/client';
import type { PrismaService } from '../../../platform/database/prisma.service';
import { weddingCostResponseInclude } from '../public/wedding-cost.presenter';

type Client = Prisma.TransactionClient | PrismaService;

const paymentInclude = Prisma.validator<Prisma.CostPaymentInclude>()({
  weddingCost: { include: { budgetCategory: { select: { name: true } } } },
  reversedBy: { select: { id: true } },
});
const scheduleInclude = Prisma.validator<Prisma.PaymentScheduleInclude>()({
  weddingCost: { include: { budgetCategory: { select: { name: true } } } },
});

type TextSearch = { contains: string; mode: 'insensitive' };
type IdSet = { in: string[] };
type CostWhere = {
  id?: string | IdSet;
  weddingPlanId?: string;
  status?: WeddingCostStatus;
  budgetCategoryId?: string;
  quoteOfferId?: string;
  providerId?: { not: null };
  OR?: Array<{
    title?: TextSearch;
    partyName?: TextSearch;
    providerId?: IdSet;
    budgetCategory?: { name: TextSearch };
  }>;
};
type CostData = {
  weddingPlanId: string;
  budgetCategoryId: string;
  providerId: string | null;
  quoteOfferId: string | null;
  partyName: string | null;
  partyPhone: string | null;
  title: string;
  totalAmount: Prisma.Decimal;
  paidAmount: Prisma.Decimal;
  agreementDate: Date | null;
  status: WeddingCostStatus;
  payer?: CostPayer | null;
  payerName?: string | null;
  note: string | null;
};
type CostUpdate = Partial<Omit<CostData, 'weddingPlanId'>>;
type CostSort = { createdAt?: 'asc' | 'desc'; id?: 'asc' | 'desc' };
type CostReadArgs = {
  where: CostWhere;
  include?: typeof weddingCostResponseInclude;
  select?: { weddingPlanId?: true; providerId?: true };
  orderBy?: CostSort[];
  skip?: number;
  take?: number;
  distinct?: ['providerId'];
};
type CostFindArgs = {
  where: { id: string };
  include?: typeof weddingCostResponseInclude;
  select?: { weddingPlanId: true };
};
type CostUpdateArgs = {
  where: { id: string };
  data: CostUpdate;
  include?: typeof weddingCostResponseInclude;
};
type PaymentWhere = {
  id?: string | IdSet;
  weddingCostId?: string;
  paymentScheduleId?: string;
  entryType?: CostPaymentType;
  weddingCost?: { weddingPlanId: string; id?: IdSet };
};
type PaymentData = {
  weddingCostId: string;
  amount: Prisma.Decimal;
  paidAt: Date;
  entryType?: CostPaymentType;
  paymentScheduleId?: string;
  reversalOfId?: string;
  method?: string | null;
  note?: string | null;
};
type PaymentReadArgs = {
  where: PaymentWhere;
  include?: typeof paymentInclude;
  select?: { id: true } | { weddingCostId: true; weddingCost: { select: { weddingPlanId: true } } };
  orderBy?: { paidAt?: 'asc' | 'desc'; createdAt?: 'asc' | 'desc' }[];
  skip?: number;
  take?: number;
};
type PaymentFindArgs = {
  where: { id: string };
  include?: typeof paymentInclude;
  select?: { weddingCostId: true; weddingCost: { select: { weddingPlanId: true } } };
};
type ActivePaymentArgs = {
  where: { paymentScheduleId: string; entryType: CostPaymentType; reversedBy: null };
  select?: { id: true };
  include?: typeof paymentInclude;
  orderBy?: { createdAt: 'desc' };
};
type ScheduleWhere = {
  id?: string | IdSet;
  weddingCostId?: string;
  weddingCost?: { weddingPlanId: string; id?: IdSet; status?: { not: WeddingCostStatus } };
  status?: PaymentScheduleStatus;
  dueDate?: { lte: Date };
};
type ScheduleData = {
  weddingCostId: string;
  amount: Prisma.Decimal;
  dueDate: Date;
  note: string | null;
};
type ScheduleUpdate = {
  amount?: Prisma.Decimal;
  dueDate?: Date;
  note?: string | null;
  status?: PaymentScheduleStatus;
  paidAt?: Date | null;
};
type ScheduleReadArgs = {
  where: ScheduleWhere;
  include?: typeof scheduleInclude;
  orderBy?: { dueDate?: 'asc' | 'desc'; createdAt?: 'asc' | 'desc' }[];
};

// The application service keeps authorization and transaction order; this file
// owns the Finance persistence operations on the supplied client.
export function insertWeddingCost(client: Client, args: { data: CostData }): Promise<WeddingCost>;
export function insertWeddingCost(client: Client, args: { data: CostData }) {
  return client.weddingCost.create(args as Prisma.WeddingCostCreateArgs);
}

export function requireWeddingCost<T extends CostFindArgs>(client: Client, args: T): Promise<Prisma.WeddingCostGetPayload<T>>;
export function requireWeddingCost(client: Client, args: CostFindArgs) {
  return client.weddingCost.findUniqueOrThrow(args as Prisma.WeddingCostFindUniqueOrThrowArgs);
}

export function listWeddingCosts<T extends CostReadArgs>(client: Client, args: T): Promise<Prisma.WeddingCostGetPayload<T>[]>;
export function listWeddingCosts(client: Client, args: CostReadArgs) {
  return client.weddingCost.findMany(args as Prisma.WeddingCostFindManyArgs);
}

export function countWeddingCosts(client: Client, args: { where: CostWhere }) {
  return client.weddingCost.count(args);
}

export function findVisibleWeddingCost<T extends CostReadArgs>(client: Client, args: T): Promise<Prisma.WeddingCostGetPayload<T> | null>;
export function findVisibleWeddingCost(client: Client, args: CostReadArgs) {
  return client.weddingCost.findFirst(args as Prisma.WeddingCostFindFirstArgs);
}

export function findWeddingCost<T extends CostFindArgs>(client: Client, args: T): Promise<Prisma.WeddingCostGetPayload<T> | null>;
export function findWeddingCost(client: Client, args: CostFindArgs) {
  return client.weddingCost.findUnique(args as Prisma.WeddingCostFindUniqueArgs);
}

export function updateWeddingCost<T extends CostUpdateArgs>(client: Client, args: T): Promise<Prisma.WeddingCostGetPayload<T>>;
export function updateWeddingCost(client: Client, args: CostUpdateArgs) {
  return client.weddingCost.update(args as Prisma.WeddingCostUpdateArgs);
}

export function deleteWeddingCost(client: Client, args: { where: { id: string } }) {
  return client.weddingCost.delete(args);
}

export function insertCostPayment<T extends { data: PaymentData; include?: typeof paymentInclude }>(client: Client, args: T): Promise<Prisma.CostPaymentGetPayload<T>>;
export function insertCostPayment(client: Client, args: { data: PaymentData; include?: typeof paymentInclude }) {
  return client.costPayment.create(args as Prisma.CostPaymentCreateArgs);
}

export function listCostPayments<T extends PaymentReadArgs>(client: Client, args: T): Promise<Prisma.CostPaymentGetPayload<T>[]>;
export function listCostPayments(client: Client, args: PaymentReadArgs) {
  return client.costPayment.findMany(args as Prisma.CostPaymentFindManyArgs);
}

export function countCostPayments(client: Client, args: { where: PaymentWhere }) {
  return client.costPayment.count(args);
}

export function findVisibleCostPayment<T extends PaymentReadArgs>(client: Client, args: T): Promise<Prisma.CostPaymentGetPayload<T> | null>;
export function findVisibleCostPayment(client: Client, args: PaymentReadArgs) {
  return client.costPayment.findFirst(args as Prisma.CostPaymentFindFirstArgs);
}

export function findActiveSchedulePayment<T extends ActivePaymentArgs>(client: Client, args: T): Promise<Prisma.CostPaymentGetPayload<T> | null>;
export function findActiveSchedulePayment(client: Client, args: ActivePaymentArgs) {
  return client.costPayment.findFirst(args as Prisma.CostPaymentFindFirstArgs);
}

export function findCostPayment<T extends PaymentFindArgs>(client: Client, args: T): Promise<Prisma.CostPaymentGetPayload<T> | null>;
export function findCostPayment(client: Client, args: PaymentFindArgs) {
  return client.costPayment.findUnique(args as Prisma.CostPaymentFindUniqueArgs);
}

export function insertPaymentSchedule<T extends { data: ScheduleData; include: typeof scheduleInclude }>(client: Client, args: T): Promise<Prisma.PaymentScheduleGetPayload<T>>;
export function insertPaymentSchedule(client: Client, args: { data: ScheduleData; include: typeof scheduleInclude }) {
  return client.paymentSchedule.create(args as Prisma.PaymentScheduleCreateArgs);
}

export function listPaymentSchedules<T extends ScheduleReadArgs>(client: Client, args: T): Promise<Prisma.PaymentScheduleGetPayload<T>[]>;
export function listPaymentSchedules(client: Client, args: ScheduleReadArgs) {
  return client.paymentSchedule.findMany(args as Prisma.PaymentScheduleFindManyArgs);
}

export function findPaymentSchedule<T extends { where: { id: string }; include?: typeof scheduleInclude }>(client: Client, args: T): Promise<Prisma.PaymentScheduleGetPayload<T> | null>;
export function findPaymentSchedule(client: Client, args: { where: { id: string }; include?: typeof scheduleInclude }) {
  return client.paymentSchedule.findUnique(args as Prisma.PaymentScheduleFindUniqueArgs);
}

export function requirePaymentSchedule<T extends { where: { id: string }; include?: typeof scheduleInclude }>(client: Client, args: T): Promise<Prisma.PaymentScheduleGetPayload<T>>;
export function requirePaymentSchedule(client: Client, args: { where: { id: string }; include?: typeof scheduleInclude }) {
  return client.paymentSchedule.findUniqueOrThrow(args as Prisma.PaymentScheduleFindUniqueOrThrowArgs);
}

export function updatePaymentSchedule<T extends { where: { id: string }; data: ScheduleUpdate; include?: typeof scheduleInclude }>(client: Client, args: T): Promise<Prisma.PaymentScheduleGetPayload<T>>;
export function updatePaymentSchedule(client: Client, args: { where: { id: string }; data: ScheduleUpdate; include?: typeof scheduleInclude }) {
  return client.paymentSchedule.update(args as Prisma.PaymentScheduleUpdateArgs);
}

export function updatePaymentSchedules(client: Client, args: { where: ScheduleWhere; data: ScheduleUpdate }) {
  return client.paymentSchedule.updateMany(args);
}

export function deletePaymentSchedule(client: Client, args: { where: { id: string } }) {
  return client.paymentSchedule.delete(args);
}

export async function lockBudgetCategoriesForCost(
  tx: Prisma.TransactionClient,
  orderedIds: string[],
  weddingPlanId: string,
): Promise<string[]> {
  const rows = await tx.$queryRaw<Array<{ id: string }>>(
    Prisma.sql`
      SELECT "id" FROM "BudgetCategory"
      WHERE "id" IN (${Prisma.join(orderedIds)}) AND "weddingPlanId" = ${weddingPlanId}
      ORDER BY "id" ASC FOR SHARE
    `,
  );
  return rows.map((row) => row.id);
}

export async function lockWeddingCost(tx: Prisma.TransactionClient, id: string) {
  const rows = await tx.$queryRaw<Array<{ id: string }>>(
    Prisma.sql`SELECT "id" FROM "WeddingCost" WHERE "id" = ${id} FOR UPDATE`,
  );
  if (rows.length === 0) throw new NotFoundException('Wedding cost not found');
  return tx.weddingCost.findUniqueOrThrow({ where: { id } });
}

export async function lockCostPayment(tx: Prisma.TransactionClient, id: string) {
  const rows = await tx.$queryRaw<Array<{ id: string }>>(
    Prisma.sql`SELECT "id" FROM "CostPayment" WHERE "id" = ${id} FOR UPDATE`,
  );
  if (rows.length === 0) throw new NotFoundException('Cost payment not found');
}

export async function lockPaymentSchedule(tx: Prisma.TransactionClient, id: string) {
  const rows = await tx.$queryRaw<Array<{ id: string }>>(
    Prisma.sql`SELECT "id" FROM "PaymentSchedule" WHERE "id" = ${id} FOR UPDATE`,
  );
  if (rows.length === 0) throw new NotFoundException('Payment schedule not found');
}
