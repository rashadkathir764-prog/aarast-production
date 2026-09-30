import { Module } from '@nestjs/common';
import { NotificationsAdminService } from '../infrastructure/notifications-admin.service';

export const NOTIFICATIONS_ADMIN_IMPLEMENTATION = Symbol(
  'NOTIFICATIONS_ADMIN_IMPLEMENTATION',
);

@Module({
  providers: [
    NotificationsAdminService,
    {
      provide: NOTIFICATIONS_ADMIN_IMPLEMENTATION,
      useExisting: NotificationsAdminService,
    },
  ],
  exports: [NotificationsAdminService, NOTIFICATIONS_ADMIN_IMPLEMENTATION],
})
export class NotificationsAdminInternalModule {}
