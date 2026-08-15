import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module";
import { PrismaModule } from "../platform/database/prisma.module";
import { OutboxCoreModule } from "../platform/outbox/outbox-core.module";
import { PushModule } from "../push/push.module";
import { PermissionService } from "../sharing/permission.service";
import { NotificationsController } from "./notifications.controller";
import { NotificationRemindersScheduler } from "./notification-reminders.scheduler";
import { NotificationsService } from "./notifications.service";

@Module({
  imports: [AuthModule, PrismaModule, OutboxCoreModule, PushModule],
  controllers: [NotificationsController],
  providers: [
    NotificationsService,
    NotificationRemindersScheduler,
    PermissionService,
  ],
  exports: [NotificationsService],
})
export class NotificationsModule {}
