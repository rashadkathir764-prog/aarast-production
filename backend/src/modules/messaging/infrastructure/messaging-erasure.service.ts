import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import type {
  MessagingErasurePort,
  OwnedConversationScope,
} from '../public/messaging-erasure.port';

@Injectable()
export class MessagingErasureService implements MessagingErasurePort {
  async lockOwnedConversationIdsForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    scope: OwnedConversationScope,
  ): Promise<string[]> {
    // Only contexts owned by the account are selected here. Merely being
    // a Participant or creator in somebody else's PLAN conversation does
    // not make that conversation eligible for deletion, and neither does
    // being the provider in it (RA-BE-178: the customer keeps it). An empty
    // id list is an empty `ANY`, and a null account an unknown `=`: that
    // predicate matches nothing.
    const weddingPlanIds = [...scope.weddingPlanIds];
    const conversations = await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`
        SELECT "id"
        FROM "Conversation"
        WHERE "accountRequesterUserId" = ${scope.userId}
           OR "weddingPlanId" = ANY(${weddingPlanIds}::text[])
        ORDER BY "id" ASC
        FOR UPDATE
      `,
    );
    return conversations.map((conversation) => conversation.id);
  }

  async listAttachmentIdsForConversations(
    tx: Prisma.TransactionClient,
    conversationIds: readonly string[],
  ): Promise<string[]> {
    if (conversationIds.length === 0) return [];
    const attachments = await tx.chatAttachment.findMany({
      where: { message: { conversationId: { in: [...conversationIds] } } },
      orderBy: { id: 'asc' },
      select: { id: true },
    });
    return attachments.map((attachment) => attachment.id);
  }

  async deleteConversationsInTransaction(
    tx: Prisma.TransactionClient,
    conversationIds: readonly string[],
  ): Promise<void> {
    if (conversationIds.length === 0) return;
    await tx.conversation.deleteMany({
      where: { id: { in: [...conversationIds] } },
    });
  }

  async closeProviderConversationsInTransaction(
    tx: Prisma.TransactionClient,
    providerIds: readonly string[],
    closedAt: Date,
  ): Promise<void> {
    if (providerIds.length === 0) return;
    await tx.conversation.updateMany({
      where: { providerId: { in: [...providerIds] }, closedAt: null },
      data: { closedAt },
    });
  }

  async eraseUserParticipationInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<void> {
    await tx.conversationParticipant.deleteMany({ where: { userId } });
    // RA-BE-178: the messages stay where they were written, with no author.
    await tx.chatMessage.updateMany({
      where: { senderUserId: userId },
      data: { senderUserId: null },
    });
    await tx.conversationReport.deleteMany({
      where: { reporterUserId: userId },
    });
    await tx.conversationEvent.updateMany({
      where: { actorUserId: userId },
      data: { actorUserId: null },
    });
    await tx.conversation.updateMany({
      where: { createdByUserId: userId },
      data: { createdByUserId: null },
    });
    await tx.conversation.updateMany({
      where: { customerSideBlockedById: userId },
      data: { customerSideBlockedById: null },
    });
    // RA-BE-139: a helper's own thread stays a helper's thread, with no one
    // named; his requests in it passed to the plan's owner (D112).
    await tx.conversation.updateMany({
      where: { helperUserId: userId },
      data: { helperUserId: null },
    });
  }
}
