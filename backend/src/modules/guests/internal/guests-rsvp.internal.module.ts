import { Module } from "@nestjs/common";
import { GuestRsvpService } from "../../../guests/guest-rsvp.service";
import { PrismaModule } from "../../../platform/database/prisma.module";
import { CollaborationPermissionPublicModule } from "../../collaboration/public/collaboration-permission-public.module";
import { CollaborationScopePublicModule } from "../../collaboration/public/collaboration-scope-public.module";
import { MediaStoragePublicModule } from "../../media/public/media-storage-public.module";
import { NotificationsPublicModule } from "../../notifications/public/notifications-public.module";
import { PlanReadPublicModule } from "../../planning/public/plan-read-public.module";

/** Guest invitation links and RSVP (V1 checklist 4.7); D83: the card. */
@Module({
  imports: [
    PrismaModule,
    CollaborationPermissionPublicModule,
    CollaborationScopePublicModule,
    PlanReadPublicModule,
    NotificationsPublicModule,
    MediaStoragePublicModule,
  ],
  providers: [GuestRsvpService],
  exports: [GuestRsvpService],
})
export class GuestsRsvpInternalModule {}
