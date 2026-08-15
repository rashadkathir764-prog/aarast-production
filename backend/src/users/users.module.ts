import { Module } from "@nestjs/common";
import { PrismaModule } from "../platform/database/prisma.module";
import { CollaborationPermissionPublicModule } from "../modules/collaboration/public/collaboration-permission-public.module";
import { MediaStoragePublicModule } from "../modules/media/public/media-storage-public.module";
import { MessagingRealtimePublicModule } from "../modules/messaging/public/messaging-realtime-public.module";
import { PushCapabilityPublicModule } from "../modules/notifications/public/push-capability-public.module";
import { UsersController } from "./users.controller";
import { UsersService } from "./users.service";
import { AccountDeletionStatusController } from "./account-deletion-status.controller";

@Module({
  imports: [
    PrismaModule,
    CollaborationPermissionPublicModule,
    MediaStoragePublicModule,
    MessagingRealtimePublicModule,
    PushCapabilityPublicModule,
  ],
  controllers: [UsersController, AccountDeletionStatusController],
  providers: [UsersService],
})
export class UsersModule {}
