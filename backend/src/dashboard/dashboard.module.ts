import { Module } from "@nestjs/common";
import { NotificationsModule } from "../notifications/notifications.module";
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
    NotificationsModule,
    CollaborationHistoryPublicModule,
    CollaborationScopePublicModule,
  ],
  controllers: [DashboardController, WeddingPlanDashboardController],
  providers: [DashboardService],
})
export class DashboardModule {}
