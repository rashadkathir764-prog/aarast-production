import { ConversationScope, Prisma } from '@prisma/client';
import type { PrismaService } from '../../../platform/database/prisma.service';
import { conversationOwnInclude } from '../../../conversations/conversation-relations';

type Client = PrismaService | Prisma.TransactionClient;

export interface ConversationAccessFilter {
  providerIds: string[];
  accountRequesterUserId: string;
  planIds: string[];
}

export class ConversationsRepository {
  listPage(client: Client, filter: ConversationAccessFilter, cursor: string | undefined, limit: number) {
    return client.conversation.findMany({
      where: {
        OR: [
          { providerId: { in: filter.providerIds } },
          { scope: ConversationScope.ACCOUNT, accountRequesterUserId: filter.accountRequesterUserId },
          { scope: ConversationScope.PLAN, weddingPlanId: { in: filter.planIds } },
        ],
      },
      orderBy: [{ lastActivityAt: 'desc' }, { createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
      select: { id: true },
    });
  }

  listByIds(client: Client, ids: readonly string[]) {
    return client.conversation.findMany({
      where: { id: { in: [...ids] } },
      orderBy: [{ lastActivityAt: 'desc' }, { createdAt: 'desc' }, { id: 'desc' }],
      include: conversationOwnInclude,
    });
  }

  listMessages(client: Client, conversationId: string, cursor: string | undefined, limit: number) {
    return client.chatMessage.findMany({
      where: { conversationId, deletedAt: null },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
      include: { attachments: { orderBy: { createdAt: 'asc' as const } } },
    });
  }

  listTimelineMessages(client: Client, conversationId: string, before: Date | undefined, limit: number) {
    return client.chatMessage.findMany({
      where: { conversationId, deletedAt: null, ...(before ? { createdAt: { lte: before } } : {}) },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
      include: { attachments: { orderBy: { createdAt: 'asc' as const } } },
    });
  }

  listTimelineEvents(client: Client, conversationId: string, before: Date | undefined, limit: number) {
    return client.conversationEvent.findMany({
      where: { conversationId, ...(before ? { occurredAt: { lte: before } } : {}) },
      orderBy: [{ occurredAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
    });
  }

  /** RA-BE-81: how many messages this account sent since then, everywhere. */
  countMessagesSentSince(tx: Prisma.TransactionClient, senderUserId: string, since: Date) {
    return tx.chatMessage.count({ where: { senderUserId, createdAt: { gte: since } } });
  }

  createMessage(
    tx: Prisma.TransactionClient,
    conversationId: string,
    senderUserId: string,
    body: string,
    attachments: readonly { key: string; contentType: string; byteSize: number }[],
  ) {
    return tx.chatMessage.create({
      data: {
        conversationId, senderUserId, body,
        attachments: {
          create: attachments.map((attachment) => ({
            storageKey: attachment.key,
            contentType: attachment.contentType,
            byteSize: attachment.byteSize,
          })),
        },
      },
      include: { attachments: true },
    });
  }

  touchConversation(tx: Prisma.TransactionClient, conversationId: string, at: Date) {
    return tx.conversation.update({ where: { id: conversationId }, data: { lastActivityAt: at } });
  }

  markParticipantRead(tx: Prisma.TransactionClient, conversationId: string, userId: string, at: Date) {
    return tx.conversationParticipant.updateMany({
      where: { conversationId, userId, revokedAt: null }, data: { lastReadAt: at },
    });
  }

  recipientStates(tx: Prisma.TransactionClient, conversationId: string, userIds: readonly string[]) {
    return tx.conversationParticipant.findMany({
      where: { conversationId, userId: { in: [...userIds] }, revokedAt: null },
      select: { userId: true, mutedAt: true },
    });
  }

  findAttachment(client: Client, conversationId: string, attachmentId: string) {
    return client.chatAttachment.findFirst({
      where: { id: attachmentId, message: { conversationId, deletedAt: null } },
      select: { storageKey: true },
    });
  }

  setParticipantMuted(tx: Prisma.TransactionClient, conversationId: string, userId: string, mutedAt: Date | null) {
    return tx.conversationParticipant.updateMany({
      where: { conversationId, userId, revokedAt: null }, data: { mutedAt },
    });
  }

  setConversationBlocked(tx: Prisma.TransactionClient, conversationId: string, userId: string, providerSide: boolean, enabled: boolean) {
    return tx.conversation.update({
      where: { id: conversationId },
      data: providerSide
        ? { providerSideBlockedAt: enabled ? new Date() : null }
        : { customerSideBlockedAt: enabled ? new Date() : null, customerSideBlockedById: enabled ? userId : null },
      select: { customerSideBlockedAt: true, customerSideBlockedById: true, providerSideBlockedAt: true },
    });
  }

  reportConversation(tx: Prisma.TransactionClient, conversationId: string, reporterUserId: string, reason: string) {
    return tx.conversationReport.upsert({
      where: { conversationId_reporterUserId: { conversationId, reporterUserId } },
      update: { reason, status: 'OPEN' },
      create: { conversationId, reporterUserId, reason },
      select: { id: true, status: true, createdAt: true, updatedAt: true },
    });
  }

  revokeParticipant(client: Client, conversationId: string, userId: string, at: Date) {
    return client.conversationParticipant.updateMany({
      where: { conversationId, userId, revokedAt: null }, data: { revokedAt: at },
    });
  }

  lockConversation(tx: Prisma.TransactionClient, conversationId: string, mode: 'UPDATE' | 'SHARE') {
    return mode === 'UPDATE'
      ? tx.$queryRaw<Array<{ id: string }>>(Prisma.sql`SELECT "id" FROM "Conversation" WHERE "id" = ${conversationId} FOR UPDATE`)
      : tx.$queryRaw<Array<{ id: string }>>(Prisma.sql`SELECT "id" FROM "Conversation" WHERE "id" = ${conversationId} FOR SHARE`);
  }

  ensureParticipants(client: Client, values: readonly { conversationId: string; userId: string }[]) {
    return client.conversationParticipant.createMany({ data: [...values], skipDuplicates: true });
  }

  lockParticipants(tx: Prisma.TransactionClient, conversationId: string, sortedUserIds: readonly string[], mode: 'UPDATE' | 'SHARE') {
    return mode === 'UPDATE'
      ? tx.$queryRaw(Prisma.sql`SELECT "id" FROM "ConversationParticipant" WHERE "conversationId" = ${conversationId} AND "userId" IN (${Prisma.join([...sortedUserIds])}) ORDER BY "userId" ASC FOR UPDATE`)
      : tx.$queryRaw(Prisma.sql`SELECT "id" FROM "ConversationParticipant" WHERE "conversationId" = ${conversationId} AND "userId" IN (${Prisma.join([...sortedUserIds])}) ORDER BY "userId" ASC FOR SHARE`);
  }

  findConversation(client: Client, conversationId: string) {
    return client.conversation.findUnique({ where: { id: conversationId }, include: conversationOwnInclude });
  }

  unreadCounts(client: Client, userId: string, conversationIds: readonly string[]) {
    return client.$queryRaw<Array<{ conversationId: string; count: bigint }>>(
      Prisma.sql`
        SELECT m."conversationId", count(*)::bigint AS "count"
        FROM "ChatMessage" m
        JOIN "ConversationParticipant" p
          ON p."conversationId" = m."conversationId"
         AND p."userId" = ${userId}
         AND p."revokedAt" IS NULL
        WHERE m."conversationId" IN (${Prisma.join([...conversationIds])})
          AND m."senderUserId" <> ${userId}
          AND m."deletedAt" IS NULL
          AND (p."lastReadAt" IS NULL OR m."createdAt" > p."lastReadAt")
        GROUP BY m."conversationId"
      `,
    );
  }

  findAccessibleCursor(client: Client, filter: ConversationAccessFilter, cursor: string) {
    return client.conversation.findFirst({
      where: {
        AND: [
          { id: cursor },
          { OR: [
            { providerId: { in: filter.providerIds } },
            { scope: ConversationScope.ACCOUNT, accountRequesterUserId: filter.accountRequesterUserId },
            { scope: ConversationScope.PLAN, weddingPlanId: { in: filter.planIds } },
          ] },
        ],
      },
      select: { id: true },
    });
  }

  findMessageCursor(client: Client, conversationId: string, cursor: string) {
    return client.chatMessage.findFirst({
      where: { id: cursor, conversationId, deletedAt: null }, select: { id: true },
    });
  }
}
