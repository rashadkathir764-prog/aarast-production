import { Module } from '@nestjs/common';
import { NotificationsController } from '../../notifications/notifications.controller';
import { PushController } from '../../push/push.controller';
import { NotificationsLifecycleInternalModule } from './internal/notifications-lifecycle.internal.module';
import { NotificationsInternalModule } from './internal/notifications-service.internal.module';
import { PushInstallationsInternalModule } from './internal/push-installations.internal.module';

@Module({
  imports: [
    NotificationsInternalModule,
    NotificationsLifecycleInternalModule,
    PushInstallationsInternalModule,
  ],
  controllers: [NotificationsController, PushController],
})
export class NotificationsModule {}
