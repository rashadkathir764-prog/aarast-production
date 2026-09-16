import { Module } from "@nestjs/common";
import { OnboardingController } from "../../onboarding/onboarding.controller";
import { WeddingPlansController } from "../../wedding-plans/wedding-plans.controller";
import { PlanningServicesInternalModule } from "./internal/planning-services.internal.module";
import { PlanReadPublicModule } from "./public/plan-read-public.module";
import { PlanningBudgetWritePublicModule } from "./public/planning-budget-write-public.module";

@Module({
  imports: [
    PlanReadPublicModule,
    PlanningBudgetWritePublicModule,
    PlanningServicesInternalModule,
  ],
  controllers: [WeddingPlansController, OnboardingController],
})
export class PlanningModule {}
