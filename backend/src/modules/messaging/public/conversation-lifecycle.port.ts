import type {
  ConversationEvent,
  ConversationEventType,
  ConversationScope,
  Prisma,
} from '@prisma/client';

export const CONVERSATION_LIFECYCLE_PORT = Symbol(
  'CONVERSATION_LIFECYCLE_PORT',
);

// The caller's transaction. The lifecycle reads planning's and
// marketplace's rows through their ports on it, so the whole client is
// required (the earlier pick named those tables for the lifecycle's own
// reads, which are gone).
export type ConversationLifecycleClient = Prisma.TransactionClient;

export interface EnsureConversationContextInput {
  requesterUserId: string;
  providerId: string;
  weddingPlanId: string | null;
  activityAt?: Date;
}

export interface RecordConversationEventInput {
  conversationId: string;
  quoteRequestId?: string | null;
  quoteOfferId?: string | null;
  actorUserId?: string | null;
  type: ConversationEventType;
  occurredAt?: Date;
  dedupeKey: string;
  data?: Prisma.InputJsonObject;
}

export interface RecordConversationEventResult {
  event: ConversationEvent;
  created: boolean;
}

export interface ConversationLifecyclePort {
  ensureConversationContext(
    tx: ConversationLifecycleClient,
    input: EnsureConversationContextInput,
  ): Promise<{ id: string; scope: ConversationScope }>;
  recordConversationEvent(
    tx: ConversationLifecycleClient,
    input: RecordConversationEventInput,
  ): Promise<RecordConversationEventResult>;
  /**
   * Quote transitions record events on the conversation row; they lock it
   * first (before their request and offer rows) so their order matches
   * account deletion. True when the row exists.
   */
  lockConversationForUpdateInTransaction(
    tx: ConversationLifecycleClient,
    conversationId: string,
  ): Promise<boolean>;
  lockConversationForShareInTransaction(
    tx: ConversationLifecycleClient,
    conversationId: string,
  ): Promise<boolean>;
}
