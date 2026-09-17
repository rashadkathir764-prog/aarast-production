import type {
  ConversationEvent,
  ConversationEventType,
  ConversationScope,
  Prisma,
} from '@prisma/client';

export const CONVERSATION_LIFECYCLE_PORT = Symbol(
  'CONVERSATION_LIFECYCLE_PORT',
);

export type ConversationLifecycleClient = Pick<
  Prisma.TransactionClient,
  | '$queryRaw'
  | 'conversation'
  | 'conversationEvent'
  | 'conversationParticipant'
  | 'outboxEvent'
  | 'provider'
  | 'weddingPlan'
>;

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
