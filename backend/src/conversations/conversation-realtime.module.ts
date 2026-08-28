import { Module } from '@nestjs/common';
import { ConversationRealtimePublisher } from './conversation-realtime.publisher';

@Module({
  providers: [ConversationRealtimePublisher],
  exports: [ConversationRealtimePublisher],
})
export class ConversationRealtimeModule {}
