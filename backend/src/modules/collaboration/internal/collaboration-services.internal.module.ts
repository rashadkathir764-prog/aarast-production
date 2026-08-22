import { Module } from "@nestjs/common";
import { PrismaModule } from "../../../platform/database/prisma.module";
import { InvitationDeliveryService } from "../../../sharing/invitation-delivery.service";
import { InviteAccessService } from "../../../sharing/invite-access.service";
import { SharingService } from "../../../sharing/sharing.service";
import { IdentityAuthPublicModule } from "../../identity/public/identity-auth-public.module";
import { IdentityTransientDeliveryPublicModule } from "../../identity/public/identity-transient-delivery-public.module";
import { MessagingRealtimePublicModule } from "../../messaging/public/messaging-realtime-public.module";
import { NotificationsPublicModule } from "../../notifications/public/notifications-public.module";
import { CollaborationHistoryInternalModule } from "./collaboration-history.internal.module";
import { CollaborationPermissionInternalModule } from "./collaboration-permission.internal.module";

@Module({
  imports: [
    IdentityAuthPublicModule,
    IdentityTransientDeliveryPublicModule,
    PrismaModule,
    MessagingRealtimePublicModule,
    NotificationsPublicModule,
    CollaborationPermissionInternalModule,
    CollaborationHistoryInternalModule,
  ],
  providers: [SharingService, InvitationDeliveryService, InviteAccessService],
  exports: [SharingService, InvitationDeliveryService, InviteAccessService],
})
export class CollaborationServicesInternalModule {}
