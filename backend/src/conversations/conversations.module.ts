import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { PrismaModule } from '../prisma/prisma.module';
import { ConversationsController } from './conversations.controller';
import { ConversationsService } from './conversations.service';
import { ConversationsGateway } from './conversations.gateway';
import { ConversationRealtimePublisher } from './conversation-realtime.publisher';

@Module({
  imports: [AuthModule, PrismaModule, NotificationsModule],
  controllers: [ConversationsController],
  providers: [
    ConversationsService,
    ConversationsGateway,
    ConversationRealtimePublisher,
  ],
  exports: [ConversationsService],
})
export class ConversationsModule {}
