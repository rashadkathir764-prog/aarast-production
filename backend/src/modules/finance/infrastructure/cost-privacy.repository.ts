import { Prisma } from '@prisma/client';

// Private costs (V1 checklist 4.10): a cost recorded as private by the
// plan's owner or partner is visible to that account alone. Every money read
// already narrows by a cost-id scope (null = the whole plan); this removes
// the other side's private costs from that scope, so the same narrowing
// hides them from lists, details, payments, summaries and dashboards.

type Client = Prisma.TransactionClient;

/**
 * The reader's cost scope without the costs private to someone else.
 * Returns the scope unchanged (null stays null) when the plan has no such
 * cost, so the common case costs one indexed query.
 */
export async function excludeOthersPrivateCosts(
  client: Client,
  weddingPlanId: string,
  readerUserId: string,
  scopedCostIds: readonly string[] | null,
): Promise<string[] | null> {
  const foreign = await client.weddingCost.findMany({
    where: {
      weddingPlanId,
      privateToUserId: { not: null },
      NOT: { privateToUserId: readerUserId },
    },
    select: { id: true },
  });
  if (foreign.length === 0) return scopedCostIds ? [...scopedCostIds] : null;
  const hidden = new Set(foreign.map((cost) => cost.id));
  if (scopedCostIds) return scopedCostIds.filter((id) => !hidden.has(id));
  const all = await client.weddingCost.findMany({
    where: { weddingPlanId },
    select: { id: true },
  });
  return all.map((cost) => cost.id).filter((id) => !hidden.has(id));
}

/** Whether the cost is private to someone other than the reader. */
export async function isOthersPrivateCost(
  client: Client,
  costId: string,
  readerUserId: string,
): Promise<boolean> {
  const cost = await client.weddingCost.findUnique({
    where: { id: costId },
    select: { privateToUserId: true },
  });
  return (
    cost?.privateToUserId !== null &&
    cost?.privateToUserId !== undefined &&
    cost.privateToUserId !== readerUserId
  );
}

/**
 * Whether a money contribution event would describe a private cost (the
 * cost itself, or one of its payment schedules). Such events are not
 * written: their snapshot would show the cost to whoever reads the plan's
 * contribution history.
 */
export async function isPrivateCostEntity(
  client: Client,
  entity: 'WEDDING_COST' | 'PAYMENT_SCHEDULE',
  entityId: string,
): Promise<boolean> {
  const costId =
    entity === 'WEDDING_COST'
      ? entityId
      : (
          await client.paymentSchedule.findUnique({
            where: { id: entityId },
            select: { weddingCostId: true },
          })
        )?.weddingCostId;
  if (!costId) return false;
  const cost = await client.weddingCost.findUnique({
    where: { id: costId },
    select: { privateToUserId: true },
  });
  return Boolean(cost?.privateToUserId);
}

/** The plan's costs private to someone other than the reader (V1 checklist 4.10). */
export async function listOthersPrivateCostIds(
  client: Client,
  weddingPlanId: string,
  readerUserId: string,
): Promise<Set<string>> {
  const foreign = await client.weddingCost.findMany({
    where: {
      weddingPlanId,
      privateToUserId: { not: null },
      NOT: { privateToUserId: readerUserId },
    },
    select: { id: true },
  });
  return new Set(foreign.map((cost) => cost.id));
}
