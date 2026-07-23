import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { MediaModule } from '../media/media.module';
import { OutboxModule } from '../outbox/outbox.module';
import { PrismaModule } from '../prisma/prisma.module';
import {
  ConversationsController,
  QuoteRequestConversationsController,
} from './conversations.controller';
import { ConversationsService } from './conversations.service';
import { ConversationsGateway } from './conversations.gateway';
import { ConversationRealtimeModule } from './conversation-realtime.module';

@Module({
  imports: [
    AuthModule,
    PrismaModule,
    NotificationsModule,
    MediaModule,
    OutboxModule,
    ConversationRealtimeModule,
  ],
  controllers: [ConversationsController, QuoteRequestConversationsController],
  providers: [
    ConversationsService,
    ConversationsGateway,
  ],
  exports: [ConversationsService],
})
export class ConversationsModule {}
