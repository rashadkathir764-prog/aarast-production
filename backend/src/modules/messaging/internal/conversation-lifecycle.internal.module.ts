import { Inject, Injectable, Module } from '@nestjs/common';
import {
  ensureConversationContext,
  lockConversationForShare,
  lockConversationForUpdate,
  recordConversationEvent,
} from '../../../conversations/conversation-lifecycle';
import {
  PROVIDER_READ_PORT,
  type ProviderReadPort,
} from '../../marketplace/public/provider-read.port';
import { ProviderReadPublicModule } from '../../marketplace/public/provider-read-public.module';
import {
  PLAN_READ_PORT,
  type PlanReadPort,
} from '../../planning/public/plan-read.port';
import { PlanReadPublicModule } from '../../planning/public/plan-read-public.module';
import type {
  ConversationLifecycleClient,
  ConversationLifecyclePort,
  EnsureConversationContextInput,
  RecordConversationEventInput,
} from '../public/conversation-lifecycle.port';

export const CONVERSATION_LIFECYCLE_IMPLEMENTATION = Symbol('CONVERSATION_LIFECYCLE_IMPLEMENTATION');

// The lifecycle helpers stay plain functions; a new conversation's core
// participants are planning's owner and marketplace's provider account,
// read through their ports, so the implementation carries those ports.
@Injectable()
export class ConversationLifecycleService implements ConversationLifecyclePort {
  constructor(
    @Inject(PLAN_READ_PORT) private readonly plans: PlanReadPort,
    @Inject(PROVIDER_READ_PORT) private readonly providers: ProviderReadPort,
  ) {}

  ensureConversationContext(tx: ConversationLifecycleClient, input: EnsureConversationContextInput) {
    return ensureConversationContext(tx, input, { plans: this.plans, providers: this.providers });
  }

  recordConversationEvent(tx: ConversationLifecycleClient, input: RecordConversationEventInput) {
    return recordConversationEvent(tx, input);
  }

  lockConversationForUpdateInTransaction(tx: ConversationLifecycleClient, conversationId: string) {
    return lockConversationForUpdate(tx, conversationId);
  }

  lockConversationForShareInTransaction(tx: ConversationLifecycleClient, conversationId: string) {
    return lockConversationForShare(tx, conversationId);
  }
}

@Module({
  imports: [PlanReadPublicModule, ProviderReadPublicModule],
  providers: [
    ConversationLifecycleService,
    { provide: CONVERSATION_LIFECYCLE_IMPLEMENTATION, useExisting: ConversationLifecycleService },
  ],
  exports: [CONVERSATION_LIFECYCLE_IMPLEMENTATION],
})
export class ConversationLifecycleInternalModule {}
