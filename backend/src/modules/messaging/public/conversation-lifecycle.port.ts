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
  /**
   * RA-BE-139 (Q-33 (أ)): in a plan, the helper whose own thread with the
   * provider the request goes to; null for the plan's owner and partners,
   * who share one thread (and for a request without a plan).
   */
  helperUserId: string | null;
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
  /** The provider a conversation belongs to (a chat notification is checked against it). */
  findConversationProviderId(
    client: ConversationLifecycleClient,
    conversationId: string,
  ): Promise<string | null>;
  /**
   * RA-BE-169: whether either side blocked the conversation; a provider's
   * new offer or edit of one is refused there. Read after the share lock.
   */
  isConversationBlockedInTransaction(
    tx: ConversationLifecycleClient,
    conversationId: string,
  ): Promise<boolean>;
  /**
   * Q-42 (أ), RA-BE-170: from [endsAt] the conversation's messages make no
   * notice or phone alert (it stays open to writing); null starts them
   * again. Marketplace says it when a request or booking ends and nothing
   * else in the conversation is alive, and when one is asked again.
   */
  setConversationPushStopInTransaction(
    tx: ConversationLifecycleClient,
    conversationId: string,
    endsAt: Date | null,
  ): Promise<void>;
}
