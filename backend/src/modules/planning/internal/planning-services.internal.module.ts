import { Module } from "@nestjs/common";
import { OnboardingService } from "../../../onboarding/onboarding.service";
import { PrismaModule } from "../../../platform/database/prisma.module";
import { WeddingPlansService } from "../../../wedding-plans/wedding-plans.service";
import { PlanDeletionService } from "../../../wedding-plans/plan-deletion.service";
import { NotificationsPublicModule } from "../../notifications/public/notifications-public.module";
import { CollaborationHistoryPublicModule } from "../../collaboration/public/collaboration-history-public.module";
import { CollaborationPermissionPublicModule } from "../../collaboration/public/collaboration-permission-public.module";
import { FinancePublicModule } from "../../finance/public/finance-public.module";
import { GuestsPublicModule } from "../../guests/public/guests-public.module";
import { ActivePlanPublicModule } from "../../identity/public/active-plan-public.module";
import { UserReadPublicModule } from "../../identity/public/user-read-public.module";
import { TasksPublicModule } from "../../tasks/public/tasks-public.module";

@Module({
  imports: [
    PrismaModule,
    CollaborationPermissionPublicModule,
    CollaborationHistoryPublicModule,
    UserReadPublicModule,
    ActivePlanPublicModule,
    FinancePublicModule,
    TasksPublicModule,
    GuestsPublicModule,
    // Q-45 (D124): the members of a plan being deleted are told.
    NotificationsPublicModule,
  ],
  providers: [WeddingPlansService, PlanDeletionService, OnboardingService],
  exports: [WeddingPlansService, PlanDeletionService, OnboardingService],
})
export class PlanningServicesInternalModule {}
