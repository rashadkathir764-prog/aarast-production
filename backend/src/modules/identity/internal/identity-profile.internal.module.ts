import { Module } from "@nestjs/common";
import { ContextsService } from "./profile/contexts.service";
import { UsersService } from "./profile/users.service";
import { AccountDeletionService } from "./profile/account-deletion.service";
import { AccountDeletionPurgeScheduler } from "./profile/account-deletion-purge.scheduler";
import { DataExportService } from "./profile/data-export.service";
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

export const ACCOUNT_DELETION_ADMIN_IMPLEMENTATION = Symbol(
  "ACCOUNT_DELETION_ADMIN_IMPLEMENTATION",
);

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
  providers: [
    UsersService,
    ContextsService,
    // D63: the 30 days before erasure, their hourly purge, and the download
    // of the account's own data.
    AccountDeletionService,
    AccountDeletionPurgeScheduler,
    DataExportService,
    {
      provide: ACCOUNT_DELETION_ADMIN_IMPLEMENTATION,
      useExisting: AccountDeletionService,
    },
  ],
  exports: [
    UsersService,
    ContextsService,
    AccountDeletionService,
    DataExportService,
    ACCOUNT_DELETION_ADMIN_IMPLEMENTATION,
  ],
})
export class IdentityProfileInternalModule {}
