import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module";
import { ContributionHistoryModule } from "../contribution-history/contribution-history.module";
import { PrismaModule } from "../prisma/prisma.module";
import { SharingModule } from "../sharing/sharing.module";
import { WeddingPlansController } from "./wedding-plans.controller";
import { WeddingPlansService } from "./wedding-plans.service";

@Module({
  imports: [AuthModule, PrismaModule, SharingModule, ContributionHistoryModule],
  controllers: [WeddingPlansController],
  providers: [WeddingPlansService],
  exports: [WeddingPlansService],
})
export class WeddingPlansModule {}
