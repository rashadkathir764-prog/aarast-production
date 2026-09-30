import { Prisma } from '@prisma/client';

export function findConversationIdentitySeed(
  client: Prisma.TransactionClient,
  conversationId: string,
) {
  return client.conversation.findUnique({
    where: { id: conversationId },
    select: {
      scope: true,
      weddingPlanId: true,
      accountRequesterUserId: true,
      providerId: true,
    },
  });
}
