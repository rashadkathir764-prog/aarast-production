import { Module } from "@nestjs/common";
import { ContextsService } from "./profile/contexts.service";
import { UsersService } from "./profile/users.service";
import { PrismaModule } from "../../../platform/database/prisma.module";
import { CollaborationPermissionPublicModule } from "../../collaboration/public/collaboration-permission-public.module";
import { MediaStoragePublicModule } from "../../media/public/media-storage-public.module";
import { MessagingRealtimePublicModule } from "../../messaging/public/messaging-realtime-public.module";
import { PushCapabilityPublicModule } from "../../notifications/public/push-capability-public.module";

@Module({
  imports: [
    PrismaModule,
    CollaborationPermissionPublicModule,
    MediaStoragePublicModule,
    MessagingRealtimePublicModule,
    PushCapabilityPublicModule,
  ],
  providers: [UsersService, ContextsService],
  exports: [UsersService, ContextsService],
})
export class IdentityProfileInternalModule {}
