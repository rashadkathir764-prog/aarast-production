import { Module } from "@nestjs/common";
import { NotificationsPublicModule } from "../modules/notifications/public/notifications-public.module";
import { CollaborationHistoryPublicModule } from "../modules/collaboration/public/collaboration-history-public.module";
import { CollaborationPermissionPublicModule } from "../modules/collaboration/public/collaboration-permission-public.module";
import { CollaborationScopePublicModule } from "../modules/collaboration/public/collaboration-scope-public.module";
import { PrismaModule } from "../platform/database/prisma.module";
import {
  DashboardController,
  WeddingPlanDashboardController,
} from "./dashboard.controller";
import { DashboardService } from "./dashboard.service";

@Module({
  imports: [
    PrismaModule,
    CollaborationPermissionPublicModule,
    NotificationsPublicModule,
    CollaborationHistoryPublicModule,
    CollaborationScopePublicModule,
  ],
  controllers: [DashboardController, WeddingPlanDashboardController],
  providers: [DashboardService],
})
export class DashboardModule {}
