import { Injectable } from '@nestjs/common';
import { ContributionScopeStatus, type Prisma } from '@prisma/client';
import type { CollaborationErasurePort } from '../public/collaboration-erasure.port';

@Injectable()
export class CollaborationErasureService implements CollaborationErasurePort {
  async markPlansDeletedInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanIds: readonly string[],
    at: Date,
  ): Promise<void> {
    await tx.contributorTenure.updateMany({
      where: {
        endedAt: null,
        historyScope: { weddingPlanId: { in: [...weddingPlanIds] } },
      },
      data: {
        endedAt: at,
        endReason: 'PLAN_DELETED',
        sharedMemberId: null,
      },
    });
    await tx.contributorHistoryScope.updateMany({
      where: { weddingPlanId: { in: [...weddingPlanIds] } },
      data: {
        status: ContributionScopeStatus.DELETED,
        deletedAt: at,
      },
    });
  }

  async closeActorTenuresInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
    at: Date,
  ): Promise<void> {
    await tx.contributorTenure.updateMany({
      where: { actorUserId: userId, endedAt: null },
      data: {
        endedAt: at,
        endReason: 'ACCOUNT_DELETED',
        sharedMemberId: null,
      },
    });
  }

  async deletePlanMembersAndInvitesInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanIds: readonly string[],
  ): Promise<void> {
    const inPlans = { weddingPlanId: { in: [...weddingPlanIds] } };
    await tx.sharedMember.deleteMany({ where: inPlans });
    await tx.planInvite.deleteMany({ where: inPlans });
  }

  async detachUserInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<void> {
    await tx.contributorTenure.updateMany({
      where: { actorUserId: userId },
      data: { actorUserId: null },
    });
    await tx.sharedMember.deleteMany({ where: { userId } });
    await tx.planInvite.deleteMany({ where: { inviterUserId: userId } });
    await tx.planInvite.updateMany({
      where: { inviteeUserId: userId },
      data: { inviteeUserId: null },
    });
  }
}
