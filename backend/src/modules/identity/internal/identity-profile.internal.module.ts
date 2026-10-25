import { Module } from "@nestjs/common";
import { ContextsService } from "./profile/contexts.service";
import { UsersService } from "./profile/users.service";
import { PrismaModule } from "../../../platform/database/prisma.module";
import { CollaborationErasurePublicModule } from "../../collaboration/public/collaboration-erasure-public.module";
import { CollaborationPermissionPublicModule } from "../../collaboration/public/collaboration-permission-public.module";
import { FinancePublicModule } from "../../finance/public/finance-public.module";
import { GuestsPublicModule } from "../../guests/public/guests-public.module";
import { MarketplaceErasurePublicModule } from "../../marketplace/public/marketplace-erasure-public.module";
import { ProviderReadPublicModule } from "../../marketplace/public/provider-read-public.module";
import { MediaStoragePublicModule } from "../../media/public/media-storage-public.module";
import { MessagingErasurePublicModule } from "../../messaging/public/messaging-erasure-public.module";
import { NotificationsErasurePublicModule } from "../../notifications/public/notifications-erasure-public.module";
import { NotificationsPublicModule } from "../../notifications/public/notifications-public.module";
import { PlanErasurePublicModule } from "../../planning/public/plan-erasure-public.module";
import { PlanReadPublicModule } from "../../planning/public/plan-read-public.module";
import { TasksPublicModule } from "../../tasks/public/tasks-public.module";
import { MessagingRealtimePublicModule } from "../../messaging/public/messaging-realtime-public.module";
import { PushCapabilityPublicModule } from "../../notifications/public/push-capability-public.module";

@Module({
  imports: [
    PrismaModule,
    CollaborationPermissionPublicModule,
    MediaStoragePublicModule,
    MessagingRealtimePublicModule,
    PushCapabilityPublicModule,
    PlanReadPublicModule,
    ProviderReadPublicModule,
    PlanErasurePublicModule,
    MarketplaceErasurePublicModule,
    MessagingErasurePublicModule,
    NotificationsErasurePublicModule,
    CollaborationErasurePublicModule,
    FinancePublicModule,
    TasksPublicModule,
    GuestsPublicModule,
    NotificationsPublicModule,
  ],
  providers: [UsersService, ContextsService],
  exports: [UsersService, ContextsService],
})
export class IdentityProfileInternalModule {}
