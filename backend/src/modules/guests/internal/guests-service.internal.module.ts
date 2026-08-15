import { Module } from "@nestjs/common";
import { GuestsService } from "../../../guests/guests.service";
import { PrismaModule } from "../../../platform/database/prisma.module";
import { CollaborationHistoryPublicModule } from "../../collaboration/public/collaboration-history-public.module";
import { CollaborationPermissionPublicModule } from "../../collaboration/public/collaboration-permission-public.module";
import { CollaborationScopePublicModule } from "../../collaboration/public/collaboration-scope-public.module";

@Module({
  imports: [
    PrismaModule,
    CollaborationPermissionPublicModule,
    CollaborationHistoryPublicModule,
    CollaborationScopePublicModule,
  ],
  providers: [GuestsService],
  exports: [GuestsService],
})
export class GuestsServiceInternalModule {}
