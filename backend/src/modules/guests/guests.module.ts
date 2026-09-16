import { Module } from "@nestjs/common";
import {
  GuestGroupsController,
  GuestsController,
  WeddingPlanGuestGroupsController,
  WeddingPlanGuestsController,
} from "../../guests/guests.controller";
import { GuestsServiceInternalModule } from "./internal/guests-service.internal.module";
import { GuestsPublicModule } from "./public/guests-public.module";

@Module({
  imports: [GuestsPublicModule, GuestsServiceInternalModule],
  controllers: [
    WeddingPlanGuestsController,
    WeddingPlanGuestGroupsController,
    GuestsController,
    GuestGroupsController,
  ],
})
export class GuestsModule {}
