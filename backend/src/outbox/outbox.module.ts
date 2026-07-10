import { Module } from '@nestjs/common';
import { ConversationRealtimeModule } from '../conversations/conversation-realtime.module';
import { PrismaModule } from '../prisma/prisma.module';
import { OutboxDispatcher } from './outbox.dispatcher';
import { OutboxService } from './outbox.service';
import { OutboxWorker } from './outbox.worker';

@Module({
  imports: [PrismaModule, ConversationRealtimeModule],
  providers: [OutboxService, OutboxDispatcher, OutboxWorker],
  exports: [OutboxService],
})
export class OutboxModule {}
