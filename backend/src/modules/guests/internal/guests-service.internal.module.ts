import { Module } from "@nestjs/common";
import { GuestsService } from "../../../guests/guests.service";
import { PrismaModule } from "../../../platform/database/prisma.module";
import { CollaborationHistoryPublicModule } from "../../collaboration/public/collaboration-history-public.module";
import { CollaborationPermissionPublicModule } from "../../collaboration/public/collaboration-permission-public.module";
import { CollaborationScopePublicModule } from "../../collaboration/public/collaboration-scope-public.module";
import { PlanReadPublicModule } from "../../planning/public/plan-read-public.module";

@Module({
  imports: [
    PrismaModule,
    CollaborationPermissionPublicModule,
    CollaborationHistoryPublicModule,
    CollaborationScopePublicModule,
    // D83: the plan's events, to invite a guest to them.
    PlanReadPublicModule,
  ],
  providers: [GuestsService],
  exports: [GuestsService],
})
export class GuestsServiceInternalModule {}
