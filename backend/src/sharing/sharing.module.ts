import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module";
import { ContributionHistoryModule } from "../contribution-history/contribution-history.module";
import { NotificationsModule } from "../notifications/notifications.module";
import { PrismaModule } from "../platform/database/prisma.module";
import { PermissionService } from "./permission.service";
import {
  ApiV1InviteAcceptController,
  ApiV1InviteAccessController,
  ApiV1InvitesController,
  ApiV1WeddingPlanInvitesController,
  ApiV1WeddingPlanMembersController,
  ApiV1WeddingPlanPermissionsController,
  SharedWeddingPlansController,
} from "./sharing.controller";
import { InvitationDeliveryService } from "./invitation-delivery.service";
import { InviteAccessService } from "./invite-access.service";
import { SharingService } from "./sharing.service";

@Module({
  imports: [
    AuthModule,
    PrismaModule,
    NotificationsModule,
    ContributionHistoryModule,
  ],
  controllers: [
    ApiV1InviteAccessController,
    SharedWeddingPlansController,
    ApiV1WeddingPlanMembersController,
    ApiV1WeddingPlanInvitesController,
    ApiV1InvitesController,
    ApiV1InviteAcceptController,
    ApiV1WeddingPlanPermissionsController,
  ],
  providers: [
    PermissionService,
    SharingService,
    InvitationDeliveryService,
    InviteAccessService,
  ],
  exports: [PermissionService],
})
export class SharingModule {}
