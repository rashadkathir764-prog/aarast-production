import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module";
import { ContributionHistoryModule } from "../contribution-history/contribution-history.module";
import { PrismaModule } from "../platform/database/prisma.module";
import { SharingModule } from "../sharing/sharing.module";
import {
  GuestGroupsController,
  GuestsController,
  WeddingPlanGuestGroupsController,
  WeddingPlanGuestsController,
} from "./guests.controller";
import { GuestsService } from "./guests.service";

@Module({
  imports: [AuthModule, PrismaModule, SharingModule, ContributionHistoryModule],
  controllers: [
    WeddingPlanGuestsController,
    WeddingPlanGuestGroupsController,
    GuestsController,
    GuestGroupsController,
  ],
  providers: [GuestsService],
})
export class GuestsModule {}
