import { Module } from "@nestjs/common";
import { PrismaModule } from "../prisma/prisma.module";
import { MediaModule } from "../media/media.module";
import { SharingModule } from "../sharing/sharing.module";
import { ConversationRealtimeModule } from "../conversations/conversation-realtime.module";
import { UsersController } from "./users.controller";
import { UsersService } from "./users.service";
import { AccountDeletionStatusController } from "./account-deletion-status.controller";

@Module({
  imports: [
    PrismaModule,
    SharingModule,
    MediaModule,
    ConversationRealtimeModule,
  ],
  controllers: [UsersController, AccountDeletionStatusController],
  providers: [UsersService],
})
export class UsersModule {}
