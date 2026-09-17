import { Module } from '@nestjs/common';
import {
  ensureConversationContext,
  lockConversationForShare,
  lockConversationForUpdate,
  recordConversationEvent,
} from '../../../conversations/conversation-lifecycle';
import type { ConversationLifecyclePort } from '../public/conversation-lifecycle.port';

export const CONVERSATION_LIFECYCLE_IMPLEMENTATION = Symbol('CONVERSATION_LIFECYCLE_IMPLEMENTATION');
const conversationLifecycle: ConversationLifecyclePort = {
  ensureConversationContext: (tx, input) => ensureConversationContext(tx, input),
  recordConversationEvent: (tx, input) => recordConversationEvent(tx, input),
  lockConversationForUpdateInTransaction: (tx, id) => lockConversationForUpdate(tx, id),
  lockConversationForShareInTransaction: (tx, id) => lockConversationForShare(tx, id),
};

@Module({
  providers: [{ provide: CONVERSATION_LIFECYCLE_IMPLEMENTATION, useValue: conversationLifecycle }],
  exports: [CONVERSATION_LIFECYCLE_IMPLEMENTATION],
})
export class ConversationLifecycleInternalModule {}
