import { Module } from "@nestjs/common";
import { PrismaModule } from "../../../platform/database/prisma.module";
import { InvitationDeliveryService } from "./invitation-delivery.service";
import { InviteAccessService } from "./invite-access.service";
import { SharingService } from "./sharing.service";
import { ActivePlanPublicModule } from "../../identity/public/active-plan-public.module";
import { IdentityAuthPublicModule } from "../../identity/public/identity-auth-public.module";
import { IdentityTransientDeliveryPublicModule } from "../../identity/public/identity-transient-delivery-public.module";
import { UserReadPublicModule } from "../../identity/public/user-read-public.module";
import { MessagingParticipationPublicModule } from "../../messaging/public/messaging-participation-public.module";
import { MessagingRealtimePublicModule } from "../../messaging/public/messaging-realtime-public.module";
import { NotificationsPublicModule } from "../../notifications/public/notifications-public.module";
import { PlanReadPublicModule } from "../../planning/public/plan-read-public.module";
import { TasksPublicModule } from "../../tasks/public/tasks-public.module";
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
    PlanReadPublicModule,
    UserReadPublicModule,
    ActivePlanPublicModule,
    MessagingParticipationPublicModule,
    TasksPublicModule,
  ],
  providers: [SharingService, InvitationDeliveryService, InviteAccessService],
  exports: [SharingService, InvitationDeliveryService, InviteAccessService],
})
export class CollaborationServicesInternalModule {}
