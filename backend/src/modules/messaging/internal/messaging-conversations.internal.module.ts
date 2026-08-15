import { Module } from '@nestjs/common';
import { ConversationsGateway } from '../../../conversations/conversations.gateway';
import { ConversationsService } from '../../../conversations/conversations.service';
import { ConversationRealtimeModule } from '../../../conversations/conversation-realtime.module';
import { OutboxCoreModule } from '../../../platform/outbox/outbox-core.module';
import { PrismaModule } from '../../../platform/database/prisma.module';
import { IdentityAuthPublicModule } from '../../identity/public/identity-auth-public.module';
import { MediaStoragePublicModule } from '../../media/public/media-storage-public.module';
import { NotificationsPublicModule } from '../../notifications/public/notifications-public.module';

@Module({
  imports: [
    IdentityAuthPublicModule,
    PrismaModule,
    NotificationsPublicModule,
    MediaStoragePublicModule,
    OutboxCoreModule,
    ConversationRealtimeModule,
  ],
  providers: [ConversationsService, ConversationsGateway],
  exports: [ConversationsService],
})
export class MessagingConversationsInternalModule {}
