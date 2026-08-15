import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module";
import { CollaborationHistoryInternalModule } from "../modules/collaboration/internal/collaboration-history.internal.module";
import { CollaborationPermissionInternalModule } from "../modules/collaboration/internal/collaboration-permission.internal.module";
import { MessagingRealtimePublicModule } from "../modules/messaging/public/messaging-realtime-public.module";
import { NotificationsModule } from "../notifications/notifications.module";
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
    AuthModule,
    PrismaModule,
    MessagingRealtimePublicModule,
    NotificationsModule,
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
