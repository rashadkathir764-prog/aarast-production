import { Module } from '@nestjs/common';
import {
  NOTIFICATIONS_IMPLEMENTATION,
  NotificationsInternalModule,
} from '../internal/notifications-service.internal.module';
import { NOTIFICATIONS_PORT } from './notifications.port';

@Module({
  imports: [NotificationsInternalModule],
  providers: [
    {
      provide: NOTIFICATIONS_PORT,
      useExisting: NOTIFICATIONS_IMPLEMENTATION,
    },
  ],
  exports: [NOTIFICATIONS_PORT],
})
export class NotificationsPublicModule {}
