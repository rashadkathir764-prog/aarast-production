import type { Prisma } from '@prisma/client';

export const MESSAGING_ERASURE_PORT = Symbol('MESSAGING_ERASURE_PORT');

/**
 * The conversations that go: the account's own (`userId`; null when only
 * plans are purged) and those of the plans that go. RA-BE-178: a provider's
 * conversations with his customers are theirs too and are not in it.
 */
export interface OwnedConversationScope {
  userId: string | null;
  weddingPlanIds: readonly string[];
}

// The messaging steps of account and plan erasure, run by messaging on the
// saga's transaction at the point the saga reaches them.
export interface MessagingErasurePort {
  /** Locks (`FOR UPDATE`, ascending) and returns the conversations in contexts the account owns. */
  lockOwnedConversationIdsForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    scope: OwnedConversationScope,
  ): Promise<string[]>;
  /** Attachment ids of the messages in these conversations, ascending. */
  listAttachmentIdsForConversations(
    tx: Prisma.TransactionClient,
    conversationIds: readonly string[],
  ): Promise<string[]>;
  deleteConversationsInTransaction(
    tx: Prisma.TransactionClient,
    conversationIds: readonly string[],
  ): Promise<void>;
  /**
   * RA-BE-178: an erased provider's conversations stay with his customers,
   * closed: they read them and write nothing more.
   */
  closeProviderConversationsInTransaction(
    tx: Prisma.TransactionClient,
    providerIds: readonly string[],
    closedAt: Date,
  ): Promise<void>;
  /** The explicit equivalents of the User cascades/SetNulls for a retained administrator identity. */
  eraseUserParticipationInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<void>;
}
