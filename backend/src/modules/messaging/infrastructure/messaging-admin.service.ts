import { Injectable } from '@nestjs/common';
import { type ConversationReportStatus, Prisma } from '@prisma/client';
import type {
  AdminConversationReportRow,
  AdminConversationReportStatusRow,
  ConversationReportStatusChange,
  LockedConversationReport,
  MessagingAdminPort,
} from '../public/messaging-admin.port';

const reportOrder = [{ createdAt: 'desc' }, { id: 'desc' }] as const;

/** RA-AD-22: the conversation's provider and its customer side, with each report. */
const reportConversation = {
  conversation: {
    select: { providerId: true, accountRequesterUserId: true, createdByUserId: true },
  },
} as const;

@Injectable()
export class MessagingAdminService implements MessagingAdminPort {
  async listConversationReports(
    client: Prisma.TransactionClient,
    status: ConversationReportStatus | null,
    page: { skip: number; take: number },
  ): Promise<{ total: number; items: AdminConversationReportRow[] }> {
    const where = status ? { status } : {};
    const total = await client.conversationReport.count({ where });
    const items = await client.conversationReport.findMany({
      where,
      include: reportConversation,
      orderBy: [...reportOrder],
      skip: page.skip,
      take: page.take,
    });
    return { total, items };
  }

  listAccountConversationReports(
    client: Prisma.TransactionClient,
    account: { userId: string; providerId: string | null },
    take: number,
  ): Promise<AdminConversationReportRow[]> {
    return client.conversationReport.findMany({
      where: {
        OR: [
          { reporterUserId: account.userId },
          { conversation: { accountRequesterUserId: account.userId } },
          { conversation: { createdByUserId: account.userId } },
          ...(account.providerId ? [{ conversation: { providerId: account.providerId } }] : []),
        ],
      },
      include: reportConversation,
      orderBy: [...reportOrder],
      take,
    });
  }

  async lockConversationReportForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    reportId: string,
  ): Promise<LockedConversationReport | null> {
    const rows = await tx.$queryRaw<LockedConversationReport[]>(
      Prisma.sql`
        SELECT r."status", r."reporterUserId", r."conversationId", c."providerId"
        FROM "ConversationReport" r
        JOIN "Conversation" c ON c."id" = r."conversationId"
        WHERE r."id" = ${reportId}
        FOR UPDATE OF r
      `,
    );
    return rows.length === 1 ? rows[0]! : null;
  }

  async setConversationReportStatusInTransaction(
    tx: Prisma.TransactionClient,
    reportId: string,
    change: ConversationReportStatusChange,
  ): Promise<AdminConversationReportStatusRow> {
    return tx.conversationReport.update({
      where: { id: reportId },
      data: {
        status: change.status,
        closingNote: change.closingNote,
        closedAt: change.closedAt,
      },
      select: {
        id: true,
        conversationId: true,
        reason: true,
        status: true,
        closingNote: true,
        closedAt: true,
        createdAt: true,
        updatedAt: true,
      },
    });
  }

  async listProviderConversationIds(
    client: Prisma.TransactionClient,
    providerId: string,
  ): Promise<string[]> {
    const conversations = await client.conversation.findMany({
      where: { providerId },
      orderBy: { id: 'asc' },
      select: { id: true },
    });
    return conversations.map((conversation) => conversation.id);
  }
}
