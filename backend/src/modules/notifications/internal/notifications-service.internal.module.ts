import { Module } from '@nestjs/common';
import { NotificationsService } from '../../../notifications/notifications.service';
import { CollaborationPermissionPublicModule } from '../../collaboration/public/collaboration-permission-public.module';
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
