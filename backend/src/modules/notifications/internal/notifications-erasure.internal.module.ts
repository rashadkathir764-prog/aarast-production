import { Module } from '@nestjs/common';
import { NotificationsErasureService } from '../infrastructure/notifications-erasure.service';

export const NOTIFICATIONS_ERASURE_IMPLEMENTATION = Symbol(
  'NOTIFICATIONS_ERASURE_IMPLEMENTATION',
);

@Module({
  providers: [
    NotificationsErasureService,
    {
      provide: NOTIFICATIONS_ERASURE_IMPLEMENTATION,
      useExisting: NotificationsErasureService,
    },
  ],
  exports: [NotificationsErasureService, NOTIFICATIONS_ERASURE_IMPLEMENTATION],
})
export class NotificationsErasureInternalModule {}
