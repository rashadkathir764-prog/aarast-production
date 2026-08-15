import { Module } from "@nestjs/common";
import { OnboardingService } from "../../../onboarding/onboarding.service";
import { PrismaModule } from "../../../platform/database/prisma.module";
import { WeddingPlansService } from "../../../wedding-plans/wedding-plans.service";
import { CollaborationHistoryPublicModule } from "../../collaboration/public/collaboration-history-public.module";
import { CollaborationPermissionPublicModule } from "../../collaboration/public/collaboration-permission-public.module";

@Module({
  imports: [
    PrismaModule,
    CollaborationPermissionPublicModule,
    CollaborationHistoryPublicModule,
  ],
  providers: [WeddingPlansService, OnboardingService],
  exports: [WeddingPlansService, OnboardingService],
})
export class PlanningServicesInternalModule {}
