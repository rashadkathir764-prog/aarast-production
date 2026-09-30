import { PrismaService } from '../../../platform/database/prisma.service';

export function findLiveInviteForOtp(
  prisma: PrismaService,
  tokenHash: string,
  normalizedPhone: string,
  now: Date,
) {
  return prisma.planInvite.findFirst({
    where: {
      tokenHash,
      normalizedPhone,
      declinedAt: null,
      revokedAt: null,
      expiresAt: { gt: now },
    },
    select: { id: true, acceptedAt: true, weddingPlanId: true },
  });
}

export function findInviteMembership(
  prisma: PrismaService,
  weddingPlanId: string,
  userId: string,
) {
  return prisma.sharedMember.findUnique({
    where: { weddingPlanId_userId: { weddingPlanId, userId } },
    select: { id: true },
  });
}
