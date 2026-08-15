import { Module } from "@nestjs/common";
import { IdentityAuthPublicModule } from "../modules/identity/public/identity-auth-public.module";
import { CollaborationHistoryInternalModule } from "../modules/collaboration/internal/collaboration-history.internal.module";
import { CollaborationPermissionInternalModule } from "../modules/collaboration/internal/collaboration-permission.internal.module";
import { MessagingRealtimePublicModule } from "../modules/messaging/public/messaging-realtime-public.module";
import { NotificationsPublicModule } from "../modules/notifications/public/notifications-public.module";
import { PrismaModule } from "../platform/database/prisma.module";
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
    IdentityAuthPublicModule,
    PrismaModule,
    MessagingRealtimePublicModule,
    NotificationsPublicModule,
    CollaborationPermissionInternalModule,
    CollaborationHistoryInternalModule,
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
    SharingService,
    InvitationDeliveryService,
    InviteAccessService,
  ],
})
export class SharingModule {}
