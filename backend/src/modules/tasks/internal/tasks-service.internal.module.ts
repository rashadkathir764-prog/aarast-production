import { Module } from "@nestjs/common";
import { PrismaModule } from "../../../platform/database/prisma.module";
import { TasksService } from "../../../tasks/tasks.service";
import { CollaborationHistoryPublicModule } from "../../collaboration/public/collaboration-history-public.module";
import { CollaborationPermissionPublicModule } from "../../collaboration/public/collaboration-permission-public.module";
import { CollaborationScopePublicModule } from "../../collaboration/public/collaboration-scope-public.module";
import { FinancePublicModule } from "../../finance/public/finance-public.module";
import { ProviderReadPublicModule } from "../../marketplace/public/provider-read-public.module";
import { NotificationsPublicModule } from "../../notifications/public/notifications-public.module";

@Module({
  imports: [
    PrismaModule,
    // R4: linking a task reads the item and the payment it waits on.
    FinancePublicModule,
    ProviderReadPublicModule,
    CollaborationPermissionPublicModule,
    NotificationsPublicModule,
    CollaborationHistoryPublicModule,
    CollaborationScopePublicModule,
  ],
  providers: [TasksService],
  exports: [TasksService],
})
export class TasksServiceInternalModule {}
