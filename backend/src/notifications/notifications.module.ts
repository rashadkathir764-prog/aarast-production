import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module";
import { PushModule } from "../push/push.module";
import { NotificationsServiceInternalModule } from "../modules/notifications/internal/notifications-service.internal.module";
import { NotificationsController } from "./notifications.controller";
import { NotificationRemindersScheduler } from "./notification-reminders.scheduler";
import { NotificationsService } from "./notifications.service";

@Module({
  imports: [
    AuthModule,
    PushModule,
    NotificationsServiceInternalModule,
  ],
  controllers: [NotificationsController],
  providers: [NotificationRemindersScheduler],
})
export class NotificationsModule {}
