import {
  type OnboardingPath,
  Prisma,
  type WeddingPersona,
  WeddingPlanStatus,
} from '@prisma/client';
import type { UpdateWeddingPlanBudgetInput } from '../public/planning-budget-write.port';

export async function updateWeddingPlanBudgetInTransaction(
  tx: Prisma.TransactionClient,
  input: UpdateWeddingPlanBudgetInput,
): Promise<void> {
  await tx.weddingPlan.update({
    where: { id: input.weddingPlanId },
    data: {
      estimatedBudget: input.estimatedBudget,
      currency: input.currency,
      // D114: undefined is "unchanged" (Prisma writes no column for it).
      budgetIncludesMahr: input.budgetIncludesMahr,
    },
  });
}

export interface WeddingPlanCreateData {
  ownerUserId: string;
  title: string;
  city: string | null;
  location?: Prisma.InputJsonValue | typeof Prisma.DbNull;
  weddingDate: Date | null;
  priorities: string[];
  estimatedBudget: string | Prisma.Decimal | null;
  /** D114: omitted is false, the mahr outside the budget. */
  budgetIncludesMahr?: boolean;
  currency: string;
  onboardingPath: OnboardingPath | null;
  persona: WeddingPersona | null;
  onboardingCompletedAt?: Date;
  importMigrationId?: string;
  importPayloadHash?: string;
}

export interface WeddingPlanUpdateData {
  title?: string;
  city?: string | null;
  location?: Prisma.InputJsonValue | typeof Prisma.DbNull;
  weddingDate?: Date | null;
  priorities?: string[];
  onboardingPath?: OnboardingPath | null;
  persona?: WeddingPersona | null;
  /** D114: set back to false when the persona changes. */
  budgetIncludesMahr?: boolean;
}

export function createWeddingPlan(tx: Prisma.TransactionClient, data: WeddingPlanCreateData) {
  // D116: every plan has its wedding row from the start; its day stays the
  // plan's, and the row holds the time, the place and its version.
  return tx.weddingPlan.create({
    data: { ...data, events: { create: { type: 'WEDDING' } } },
  });
}

export function updateWeddingPlan(
  tx: Prisma.TransactionClient,
  id: string,
  data: WeddingPlanUpdateData,
) {
  return tx.weddingPlan.update({ where: { id }, data: { ...data } });
}

export function listOwnedWeddingPlans(
  client: Prisma.TransactionClient,
  ownerUserId: string,
) {
  return client.weddingPlan.findMany({
    where: { ownerUserId },
    orderBy: { createdAt: 'desc' },
  });
}

export function listAccessibleWeddingPlans(
  client: Prisma.TransactionClient,
  userId: string,
  memberPlanIds: readonly string[],
) {
  return client.weddingPlan.findMany({
    where: {
      OR: [{ ownerUserId: userId }, { id: { in: [...memberPlanIds] } }],
    },
    orderBy: [{ updatedAt: 'desc' }, { createdAt: 'desc' }],
  });
}

export function findImportedWeddingPlan(
  client: Prisma.TransactionClient,
  ownerUserId: string,
  importMigrationId: string,
) {
  return client.weddingPlan.findFirst({
    where: { ownerUserId, importMigrationId },
  });
}

export function findAccessiblePlanningWeddingPlan(
  client: Prisma.TransactionClient,
  id: string,
  userId: string,
  memberPlanIds: readonly string[],
) {
  return client.weddingPlan.findFirst({
    where: {
      id,
      status: WeddingPlanStatus.PLANNING,
      OR: [{ ownerUserId: userId }, { id: { in: [...memberPlanIds] } }],
    },
  });
}

/** Q-45 (D124): the owner asks to delete the plan, erased at `scheduledFor`. */
export function markPlanDeletionRequested(
  tx: Prisma.TransactionClient,
  id: string,
  requestedAt: Date,
  scheduledFor: Date,
) {
  return tx.weddingPlan.update({
    where: { id },
    data: { deletionRequestedAt: requestedAt, deletionScheduledFor: scheduledFor },
  });
}

/** Q-45 (D124): the request is taken back; the plan is as it was. */
export function clearPlanDeletionRequest(tx: Prisma.TransactionClient, id: string) {
  return tx.weddingPlan.update({
    where: { id },
    data: { deletionRequestedAt: null, deletionScheduledFor: null },
  });
}

export function archiveWeddingPlan(tx: Prisma.TransactionClient, id: string) {
  return tx.weddingPlan.update({
    where: { id },
    data: { status: WeddingPlanStatus.ARCHIVED },
  });
}
