import { Prisma } from '@prisma/client';

// Finance-owned receipt rows (V1 checklist 4.4). The files are private
// media; these rows only name them (`storageKey`) next to the cost.

type Client = Prisma.TransactionClient;

export const MAX_RECEIPTS_PER_COST = 10;

export interface CostReceiptFields {
  weddingCostId: string;
  costPaymentId: string | null;
  storageKey: string;
  contentType: string;
  byteSize: number;
  uploadedByUserId: string;
}

export function countCostReceipts(client: Client, weddingCostId: string) {
  return client.costReceipt.count({ where: { weddingCostId } });
}

export function createCostReceipt(client: Client, fields: CostReceiptFields) {
  return client.costReceipt.create({ data: fields });
}

export function listCostReceipts(client: Client, weddingCostId: string) {
  return client.costReceipt.findMany({
    where: { weddingCostId },
    orderBy: [{ createdAt: 'desc' }, { id: 'asc' }],
  });
}

export function findCostReceipt(client: Client, id: string) {
  return client.costReceipt.findUnique({ where: { id } });
}

export function deleteCostReceipt(client: Client, id: string) {
  return client.costReceipt.delete({ where: { id } });
}

/** Whether the payment belongs to the cost (a receipt may name one). */
export async function isPaymentOfCost(
  client: Client,
  costPaymentId: string,
  weddingCostId: string,
): Promise<boolean> {
  const payment = await client.costPayment.findFirst({
    where: { id: costPaymentId, weddingCostId },
    select: { id: true },
  });
  return payment !== null;
}

/** Account erasure: the receipts of the plans' costs. */
export async function listPlanReceiptIds(
  client: Client,
  weddingPlanIds: readonly string[],
): Promise<string[]> {
  if (weddingPlanIds.length === 0) return [];
  const costs = await client.weddingCost.findMany({
    where: { weddingPlanId: { in: [...weddingPlanIds] } },
    select: { id: true },
  });
  if (costs.length === 0) return [];
  const receipts = await client.costReceipt.findMany({
    where: { weddingCostId: { in: costs.map((cost) => cost.id) } },
    select: { id: true },
    orderBy: { id: 'asc' },
  });
  return receipts.map((receipt) => receipt.id);
}

/** Account erasure: the receipts of the account's private costs (V1 checklist 4.10). */
export async function listPrivateCostReceiptIds(
  client: Client,
  userId: string,
): Promise<string[]> {
  const receipts = await client.costReceipt.findMany({
    where: { weddingCost: { privateToUserId: userId } },
    select: { id: true },
    orderBy: { id: 'asc' },
  });
  return receipts.map((receipt) => receipt.id);
}

/** Account erasure: receipts the account uploaded, in any plan. */
export async function listReceiptIdsUploadedBy(
  client: Client,
  userId: string,
): Promise<string[]> {
  const receipts = await client.costReceipt.findMany({
    where: { uploadedByUserId: userId },
    select: { id: true },
    orderBy: { id: 'asc' },
  });
  return receipts.map((receipt) => receipt.id);
}

export function deleteReceipts(client: Client, ids: readonly string[]) {
  if (ids.length === 0) return Promise.resolve({ count: 0 });
  return client.costReceipt.deleteMany({ where: { id: { in: [...ids] } } });
}
