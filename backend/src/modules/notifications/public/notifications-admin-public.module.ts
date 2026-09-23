import { Module } from '@nestjs/common';
import {
  NOTIFICATIONS_ADMIN_IMPLEMENTATION,
  NotificationsAdminInternalModule,
} from '../internal/notifications-admin.internal.module';
import { NOTIFICATIONS_ADMIN_PORT } from './notifications-admin.port';

@Module({
  imports: [NotificationsAdminInternalModule],
  providers: [
    {
      provide: NOTIFICATIONS_ADMIN_PORT,
      useExisting: NOTIFICATIONS_ADMIN_IMPLEMENTATION,
    },
  ],
  exports: [NOTIFICATIONS_ADMIN_PORT],
})
export class NotificationsAdminPublicModule {}
