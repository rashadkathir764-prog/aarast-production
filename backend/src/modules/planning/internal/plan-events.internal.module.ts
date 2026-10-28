import { Module } from "@nestjs/common";
import { PlanEventsService } from "../../../wedding-plans/plan-events.service";
import { PrismaModule } from "../../../platform/database/prisma.module";
import { CollaborationPermissionPublicModule } from "../../collaboration/public/collaboration-permission-public.module";

/** The wedding's events (D65: b12, b13; the source of b04 and b05). */
@Module({
  imports: [PrismaModule, CollaborationPermissionPublicModule],
  providers: [PlanEventsService],
  exports: [PlanEventsService],
})
export class PlanEventsInternalModule {}
