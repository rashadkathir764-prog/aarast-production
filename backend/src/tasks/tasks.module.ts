import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module";
import { ContributionHistoryModule } from "../contribution-history/contribution-history.module";
import { PrismaModule } from "../platform/database/prisma.module";
import { NotificationsModule } from "../notifications/notifications.module";
import { SharingModule } from "../sharing/sharing.module";
import {
  TasksController,
  WeddingPlanTasksController,
} from "./tasks.controller";
import { TasksService } from "./tasks.service";

@Module({
  imports: [
    AuthModule,
    PrismaModule,
    SharingModule,
    NotificationsModule,
    ContributionHistoryModule,
  ],
  controllers: [WeddingPlanTasksController, TasksController],
  providers: [TasksService],
})
export class TasksModule {}
