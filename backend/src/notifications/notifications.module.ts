import { Module } from "@nestjs/common";
import { IdentityAuthPublicModule } from "../modules/identity/public/identity-auth-public.module";
import { PushModule } from "../push/push.module";
import { NotificationsServiceInternalModule } from "../modules/notifications/internal/notifications-service.internal.module";
import { NotificationsController } from "./notifications.controller";
import { NotificationRemindersScheduler } from "./notification-reminders.scheduler";
import { NotificationsService } from "./notifications.service";

@Module({
  imports: [
    IdentityAuthPublicModule,
    PushModule,
    NotificationsServiceInternalModule,
  ],
  controllers: [NotificationsController],
  providers: [NotificationRemindersScheduler],
})
export class NotificationsModule {}
