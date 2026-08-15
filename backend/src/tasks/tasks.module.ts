import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module";
import { CollaborationHistoryPublicModule } from "../modules/collaboration/public/collaboration-history-public.module";
import { CollaborationPermissionPublicModule } from "../modules/collaboration/public/collaboration-permission-public.module";
import { CollaborationScopePublicModule } from "../modules/collaboration/public/collaboration-scope-public.module";
import { PrismaModule } from "../platform/database/prisma.module";
import { NotificationsModule } from "../notifications/notifications.module";
import {
  TasksController,
  WeddingPlanTasksController,
} from "./tasks.controller";
import { TasksService } from "./tasks.service";

@Module({
  imports: [
    AuthModule,
    PrismaModule,
    CollaborationPermissionPublicModule,
    NotificationsModule,
    CollaborationHistoryPublicModule,
    CollaborationScopePublicModule,
  ],
  controllers: [WeddingPlanTasksController, TasksController],
  providers: [TasksService],
})
export class TasksModule {}
