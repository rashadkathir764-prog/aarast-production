import { Module } from "@nestjs/common";
import { IdentityAuthPublicModule } from "../modules/identity/public/identity-auth-public.module";
import { CollaborationHistoryPublicModule } from "../modules/collaboration/public/collaboration-history-public.module";
import { CollaborationPermissionPublicModule } from "../modules/collaboration/public/collaboration-permission-public.module";
import { CollaborationScopePublicModule } from "../modules/collaboration/public/collaboration-scope-public.module";
import { PrismaModule } from "../platform/database/prisma.module";
import { NotificationsPublicModule } from "../modules/notifications/public/notifications-public.module";
import {
  TasksController,
  WeddingPlanTasksController,
} from "./tasks.controller";
import { TasksService } from "./tasks.service";

@Module({
  imports: [
    IdentityAuthPublicModule,
    PrismaModule,
    CollaborationPermissionPublicModule,
    NotificationsPublicModule,
    CollaborationHistoryPublicModule,
    CollaborationScopePublicModule,
  ],
  controllers: [WeddingPlanTasksController, TasksController],
  providers: [TasksService],
})
export class TasksModule {}
