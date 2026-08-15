import { Module } from '@nestjs/common';
import { IdentityAuthPublicModule } from '../modules/identity/public/identity-auth-public.module';
import { NotificationsPublicModule } from '../modules/notifications/public/notifications-public.module';
import { MediaStoragePublicModule } from '../modules/media/public/media-storage-public.module';
import { OutboxCoreModule } from '../platform/outbox/outbox-core.module';
import { PrismaModule } from '../platform/database/prisma.module';
import {
  ConversationsController,
  QuoteRequestConversationsController,
} from './conversations.controller';
import { ConversationsService } from './conversations.service';
import { ConversationsGateway } from './conversations.gateway';
import { ConversationRealtimeModule } from './conversation-realtime.module';

@Module({
  imports: [
    IdentityAuthPublicModule,
    PrismaModule,
    NotificationsPublicModule,
    MediaStoragePublicModule,
    OutboxCoreModule,
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
