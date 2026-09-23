import type {
  ConversationReport,
  ConversationReportStatus,
  Prisma,
} from '@prisma/client';

export const MESSAGING_ADMIN_PORT = Symbol('MESSAGING_ADMIN_PORT');

/** A conversation report with the provider its conversation belongs to. */
export type AdminConversationReportRow = ConversationReport & {
  conversation: { providerId: string };
};

export type AdminConversationReportStatusRow = Pick<
  ConversationReport,
  'id' | 'conversationId' | 'reason' | 'status' | 'createdAt' | 'updatedAt'
>;

// Messaging owns conversations and their reports. The back office triages
// reports and learns which conversations a provider decision revokes through
// this port, on the client it passes (its authorized serializable
// transaction, or the shared Prisma service).
export interface MessagingAdminPort {
  /** Newest first; every report, or those in `status`. */
  listConversationReports(
    client: Prisma.TransactionClient,
    status: ConversationReportStatus | null,
    page: { skip: number; take: number },
  ): Promise<{ total: number; items: AdminConversationReportRow[] }>;
  /** Locks the report FOR UPDATE; false when it does not exist. */
  lockConversationReportForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    reportId: string,
  ): Promise<boolean>;
  setConversationReportStatusInTransaction(
    tx: Prisma.TransactionClient,
    reportId: string,
    status: ConversationReportStatus,
  ): Promise<AdminConversationReportStatusRow>;
  /** The provider's conversations, by id. */
  listProviderConversationIds(
    client: Prisma.TransactionClient,
    providerId: string,
  ): Promise<string[]>;
}
