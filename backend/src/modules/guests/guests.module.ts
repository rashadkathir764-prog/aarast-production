import { Module } from "@nestjs/common";
import {
  GuestGroupsController,
  GuestsController,
  WeddingPlanGuestGroupsController,
  WeddingPlanGuestsController,
} from "../../guests/guests.controller";
import {
  GuestInvitationLinksController,
  PublicRsvpController,
} from "../../guests/guest-rsvp.controller";
import { GuestsRsvpInternalModule } from "./internal/guests-rsvp.internal.module";
import { GuestsServiceInternalModule } from "./internal/guests-service.internal.module";
import { GuestsPublicModule } from "./public/guests-public.module";

@Module({
  imports: [GuestsPublicModule, GuestsServiceInternalModule, GuestsRsvpInternalModule],
  controllers: [
    WeddingPlanGuestsController,
    WeddingPlanGuestGroupsController,
    GuestsController,
    GuestGroupsController,
    GuestInvitationLinksController,
    PublicRsvpController,
  ],
})
export class GuestsModule {}
