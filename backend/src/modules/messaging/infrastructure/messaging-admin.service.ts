import { Injectable } from '@nestjs/common';
import { type ConversationReportStatus, Prisma } from '@prisma/client';
import type {
  AdminConversationReportRow,
  AdminConversationReportStatusRow,
  MessagingAdminPort,
} from '../public/messaging-admin.port';

const reportOrder = [{ createdAt: 'desc' }, { id: 'desc' }] as const;

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
      include: { conversation: { select: { providerId: true } } },
      orderBy: [...reportOrder],
      skip: page.skip,
      take: page.take,
    });
    return { total, items };
  }

  async lockConversationReportForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    reportId: string,
  ): Promise<boolean> {
    const rows = await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`
        SELECT "id"
        FROM "ConversationReport"
        WHERE "id" = ${reportId}
        FOR UPDATE
      `,
    );
    return rows.length === 1;
  }

  async setConversationReportStatusInTransaction(
    tx: Prisma.TransactionClient,
    reportId: string,
    status: ConversationReportStatus,
  ): Promise<AdminConversationReportStatusRow> {
    return tx.conversationReport.update({
      where: { id: reportId },
      data: { status },
      select: {
        id: true,
        conversationId: true,
        reason: true,
        status: true,
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
