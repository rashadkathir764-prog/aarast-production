import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module";
import { CollaborationHistoryPublicModule } from "../modules/collaboration/public/collaboration-history-public.module";
import { CollaborationPermissionPublicModule } from "../modules/collaboration/public/collaboration-permission-public.module";
import { CollaborationScopePublicModule } from "../modules/collaboration/public/collaboration-scope-public.module";
import { PrismaModule } from "../platform/database/prisma.module";
import {
  GuestGroupsController,
  GuestsController,
  WeddingPlanGuestGroupsController,
  WeddingPlanGuestsController,
} from "./guests.controller";
import { GuestsService } from "./guests.service";

@Module({
  imports: [
    AuthModule,
    PrismaModule,
    CollaborationPermissionPublicModule,
    CollaborationHistoryPublicModule,
    CollaborationScopePublicModule,
  ],
  controllers: [
    WeddingPlanGuestsController,
    WeddingPlanGuestGroupsController,
    GuestsController,
    GuestGroupsController,
  ],
  providers: [GuestsService],
})
export class GuestsModule {}
