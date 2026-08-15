import { Module } from '@nestjs/common';
import { ConversationRealtimeModule } from '../../../conversations/conversation-realtime.module';
import { ConversationRealtimePublisher } from '../../../conversations/conversation-realtime.publisher';
import { MESSAGING_REALTIME_IMPLEMENTATION } from './messaging-realtime.implementation-token';

@Module({
  imports: [ConversationRealtimeModule],
  providers: [
    {
      provide: MESSAGING_REALTIME_IMPLEMENTATION,
      useExisting: ConversationRealtimePublisher,
    },
  ],
  exports: [MESSAGING_REALTIME_IMPLEMENTATION],
})
export class MessagingRealtimeInternalModule {}
