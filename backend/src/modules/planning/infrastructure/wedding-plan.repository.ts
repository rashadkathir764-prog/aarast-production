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
}

export function createWeddingPlan(tx: Prisma.TransactionClient, data: WeddingPlanCreateData) {
  return tx.weddingPlan.create({ data: { ...data } });
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

export function archiveWeddingPlan(tx: Prisma.TransactionClient, id: string) {
  return tx.weddingPlan.update({
    where: { id },
    data: { status: WeddingPlanStatus.ARCHIVED },
  });
}
