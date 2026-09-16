import { Module } from '@nestjs/common';
import {
  NOTIFICATIONS_ERASURE_IMPLEMENTATION,
  NotificationsErasureInternalModule,
} from '../internal/notifications-erasure.internal.module';
import { NOTIFICATIONS_ERASURE_PORT } from './notifications-erasure.port';

@Module({
  imports: [NotificationsErasureInternalModule],
  providers: [
    {
      provide: NOTIFICATIONS_ERASURE_PORT,
      useExisting: NOTIFICATIONS_ERASURE_IMPLEMENTATION,
    },
  ],
  exports: [NOTIFICATIONS_ERASURE_PORT],
})
export class NotificationsErasurePublicModule {}
