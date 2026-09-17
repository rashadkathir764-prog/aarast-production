import { Module } from '@nestjs/common';
import { NotificationsService } from '../../../notifications/notifications.service';
import { CollaborationPermissionPublicModule } from '../../collaboration/public/collaboration-permission-public.module';
import { CollaborationScopePublicModule } from '../../collaboration/public/collaboration-scope-public.module';
import { FinancePublicModule } from '../../finance/public/finance-public.module';
import { ProviderReadPublicModule } from '../../marketplace/public/provider-read-public.module';
import { ConversationLifecyclePublicModule } from '../../messaging/public/conversation-lifecycle-public.module';
import { PlanReadPublicModule } from '../../planning/public/plan-read-public.module';
import { TasksPublicModule } from '../../tasks/public/tasks-public.module';
import { PrismaModule } from '../../../platform/database/prisma.module';
import { OutboxCoreModule } from '../../../platform/outbox/outbox-core.module';

export const NOTIFICATIONS_IMPLEMENTATION = Symbol(
  'NOTIFICATIONS_IMPLEMENTATION',
);

@Module({
  imports: [
    PrismaModule,
    OutboxCoreModule,
    CollaborationPermissionPublicModule,
    CollaborationScopePublicModule,
    PlanReadPublicModule,
    TasksPublicModule,
    FinancePublicModule,
    ProviderReadPublicModule,
    ConversationLifecyclePublicModule,
  ],
  providers: [
    NotificationsService,
    {
      provide: NOTIFICATIONS_IMPLEMENTATION,
      useExisting: NotificationsService,
    },
  ],
  exports: [NotificationsService, NOTIFICATIONS_IMPLEMENTATION],
})
export class NotificationsInternalModule {}

export const NotificationsServiceInternalModule = NotificationsInternalModule;
