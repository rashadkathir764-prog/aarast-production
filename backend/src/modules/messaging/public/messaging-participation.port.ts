import type { Prisma } from '@prisma/client';

export const MESSAGING_PARTICIPATION_PORT = Symbol('MESSAGING_PARTICIPATION_PORT');

// Messaging owns conversations and their participants. When a plan member
// gains or loses provider access, collaboration grants or revokes that
// member's participation in the plan's provider conversations through this
// port, inside its own transaction; the conversations of the provider the
// member owns and of the plan the member owns are never touched.
export interface MessagingParticipationPort {
  /** Returns the ids of the conversations whose participation changed. */
  setPlanConversationParticipationInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    userId: string,
    active: boolean,
  ): Promise<string[]>;
}
