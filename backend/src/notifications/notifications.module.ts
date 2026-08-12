import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module";
import { PrismaModule } from "../platform/database/prisma.module";
import { OutboxModule } from "../outbox/outbox.module";
import { PermissionService } from "../sharing/permission.service";
import { NotificationsController } from "./notifications.controller";
import { NotificationRemindersScheduler } from "./notification-reminders.scheduler";
import { NotificationsService } from "./notifications.service";

@Module({
  imports: [AuthModule, PrismaModule, OutboxModule],
  controllers: [NotificationsController],
  providers: [
    NotificationsService,
    NotificationRemindersScheduler,
    PermissionService,
  ],
  exports: [NotificationsService],
})
export class NotificationsModule {}
