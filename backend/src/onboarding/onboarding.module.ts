import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { WeddingPlansModule } from '../wedding-plans/wedding-plans.module';
import {
  ApiV1OnboardingController,
  OnboardingController,
} from './onboarding.controller';
import { OnboardingService } from './onboarding.service';

@Module({
  imports: [AuthModule, WeddingPlansModule],
  controllers: [OnboardingController, ApiV1OnboardingController],
  providers: [OnboardingService],
})
export class OnboardingModule {}
