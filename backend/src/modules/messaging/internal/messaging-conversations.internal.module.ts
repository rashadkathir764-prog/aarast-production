import { Module } from '@nestjs/common';
import { ConversationRelationsService } from '../../../conversations/conversation-relations';
import { ConversationsGateway } from '../../../conversations/conversations.gateway';
import { ConversationsService } from '../../../conversations/conversations.service';
import { ConversationRealtimeModule } from '../../../conversations/conversation-realtime.module';
import { OutboxCoreModule } from '../../../platform/outbox/outbox-core.module';
import { PrismaModule } from '../../../platform/database/prisma.module';
import { CollaborationPermissionPublicModule } from '../../collaboration/public/collaboration-permission-public.module';
import { IdentityAuthPublicModule } from '../../identity/public/identity-auth-public.module';
import { IdentityRealtimeSessionPublicModule } from '../../identity/public/identity-realtime-session-public.module';
import { UserReadPublicModule } from '../../identity/public/user-read-public.module';
import { ProviderReadPublicModule } from '../../marketplace/public/provider-read-public.module';
import { QuoteReadPublicModule } from '../../marketplace/public/quote-read-public.module';
import { MediaStoragePublicModule } from '../../media/public/media-storage-public.module';
import { NotificationsPublicModule } from '../../notifications/public/notifications-public.module';
import { PlanReadPublicModule } from '../../planning/public/plan-read-public.module';

@Module({
  imports: [
    IdentityAuthPublicModule,
    IdentityRealtimeSessionPublicModule,
    PrismaModule,
    NotificationsPublicModule,
    MediaStoragePublicModule,
    OutboxCoreModule,
    ConversationRealtimeModule,
    ProviderReadPublicModule,
    QuoteReadPublicModule,
    UserReadPublicModule,
    PlanReadPublicModule,
    CollaborationPermissionPublicModule,
  ],
  providers: [ConversationRelationsService, ConversationsService, ConversationsGateway],
  exports: [ConversationsService],
})
export class MessagingConversationsInternalModule {}
