import { Global, Module } from '@nestjs/common';
import { ConversationRealtimePublisher } from './conversation-realtime.publisher';

@Global()
@Module({
  providers: [ConversationRealtimePublisher],
  exports: [ConversationRealtimePublisher],
})
export class ConversationRealtimeModule {}
