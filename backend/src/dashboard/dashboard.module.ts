import { Module } from "@nestjs/common";
import { NotificationsModule } from "../notifications/notifications.module";
import { ContributionHistoryModule } from "../contribution-history/contribution-history.module";
import { PrismaModule } from "../prisma/prisma.module";
import { SharingModule } from "../sharing/sharing.module";
import {
  DashboardController,
  WeddingPlanDashboardController,
} from "./dashboard.controller";
import { DashboardService } from "./dashboard.service";

@Module({
  imports: [
    PrismaModule,
    SharingModule,
    NotificationsModule,
    ContributionHistoryModule,
  ],
  controllers: [DashboardController, WeddingPlanDashboardController],
  providers: [DashboardService],
})
export class DashboardModule {}
