import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module";
import { WeddingPlansModule } from "../wedding-plans/wedding-plans.module";
import { OnboardingController } from "./onboarding.controller";
import { OnboardingService } from "./onboarding.service";

@Module({
  imports: [AuthModule, WeddingPlansModule],
  controllers: [OnboardingController],
  providers: [OnboardingService],
})
export class OnboardingModule {}
