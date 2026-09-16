import type { Prisma } from '@prisma/client';

export const MESSAGING_ERASURE_PORT = Symbol('MESSAGING_ERASURE_PORT');

export interface OwnedConversationScope {
  userId: string;
  weddingPlanIds: readonly string[];
  providerIds: readonly string[];
}

// The messaging steps of account erasure, run by messaging on the saga's
// transaction at the point the saga reaches them.
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
  /** The explicit equivalents of the User cascades/SetNulls for a retained administrator identity. */
  eraseUserParticipationInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<void>;
}
