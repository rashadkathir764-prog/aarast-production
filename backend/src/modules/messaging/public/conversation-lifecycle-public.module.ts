import { Module } from '@nestjs/common';
import {
  ConversationLifecycleInternalModule,
  CONVERSATION_LIFECYCLE_IMPLEMENTATION,
} from '../internal/conversation-lifecycle.internal.module';
import { CONVERSATION_LIFECYCLE_PORT } from './conversation-lifecycle.port';

@Module({
  imports: [ConversationLifecycleInternalModule],
  providers: [{ provide: CONVERSATION_LIFECYCLE_PORT, useExisting: CONVERSATION_LIFECYCLE_IMPLEMENTATION }],
  exports: [CONVERSATION_LIFECYCLE_PORT],
})
export class ConversationLifecyclePublicModule {}
