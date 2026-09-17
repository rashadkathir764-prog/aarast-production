import { Inject, Injectable } from '@nestjs/common';
import type { Prisma } from '@prisma/client';
import {
  PROVIDER_READ_PORT,
  type ProviderReadPort,
} from '../../marketplace/public/provider-read.port';
import {
  PLAN_READ_PORT,
  type PlanReadPort,
} from '../../planning/public/plan-read.port';
import type { MessagingParticipationPort } from '../public/messaging-participation.port';

@Injectable()
export class MessagingParticipationService implements MessagingParticipationPort {
  constructor(
    @Inject(PROVIDER_READ_PORT) private readonly providers: ProviderReadPort,
    @Inject(PLAN_READ_PORT) private readonly plans: PlanReadPort,
  ) {}

  async setPlanConversationParticipationInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    userId: string,
    active: boolean,
  ): Promise<string[]> {
    const conversations = await tx.conversation.findMany({
      where: { weddingPlanId },
      select: { id: true, providerId: true },
    });
    if (conversations.length === 0) return [];
    // The provider's account and the plan's owner are marketplace's and
    // planning's rows: read through their ports on this transaction.
    const providerUserIds = active
      ? new Map<string, string | null>()
      : new Map(
          (
            await this.providers.getProviders(
              tx,
              conversations.map((conversation) => conversation.providerId),
            )
          ).map((provider) => [provider.id, provider.userId]),
        );
    const plan = active ? null : await this.plans.getPlan(tx, weddingPlanId);
    const conversationIds = conversations
      .filter(
        (conversation) =>
          active ||
          (providerUserIds.get(conversation.providerId) !== userId &&
            plan?.ownerUserId !== userId),
      )
      .map((conversation) => conversation.id);
    if (conversationIds.length === 0) return [];

    if (active) {
      await tx.conversationParticipant.updateMany({
        where: {
          userId,
          conversationId: { in: conversationIds },
        },
        data: { revokedAt: null },
      });
      await tx.conversationParticipant.createMany({
        data: conversationIds.map((conversationId) => ({
          conversationId,
          userId,
        })),
        skipDuplicates: true,
      });
    } else {
      await tx.conversationParticipant.updateMany({
        where: {
          userId,
          conversationId: { in: conversationIds },
          revokedAt: null,
        },
        data: { revokedAt: new Date() },
      });
    }
    return conversationIds;
  }
}
