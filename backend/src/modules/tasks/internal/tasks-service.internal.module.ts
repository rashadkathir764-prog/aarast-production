import { Module } from "@nestjs/common";
import { PrismaModule } from "../../../platform/database/prisma.module";
import { TasksService } from "../../../tasks/tasks.service";
import { CollaborationHistoryPublicModule } from "../../collaboration/public/collaboration-history-public.module";
import { CollaborationPermissionPublicModule } from "../../collaboration/public/collaboration-permission-public.module";
import { CollaborationScopePublicModule } from "../../collaboration/public/collaboration-scope-public.module";
import { NotificationsPublicModule } from "../../notifications/public/notifications-public.module";

@Module({
  imports: [
    PrismaModule,
    CollaborationPermissionPublicModule,
    NotificationsPublicModule,
    CollaborationHistoryPublicModule,
    CollaborationScopePublicModule,
  ],
  providers: [TasksService],
  exports: [TasksService],
})
export class TasksServiceInternalModule {}
