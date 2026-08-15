import { Injectable } from '@nestjs/common';
import { AuthenticatedUser } from '../modules/identity/public/identity-session.types';
import { WeddingPlansService } from '../wedding-plans/wedding-plans.service';
import { CompleteOnboardingDto } from './dto/complete-onboarding.dto';
import { ImportLocalPlanDto } from './dto/import-local-plan.dto';

@Injectable()
export class OnboardingService {
  constructor(private readonly weddingPlansService: WeddingPlansService) {}

  complete(currentUser: AuthenticatedUser, dto: CompleteOnboardingDto) {
    return this.weddingPlansService.completeOnboarding(currentUser, dto);
  }

  importLocal(currentUser: AuthenticatedUser, dto: ImportLocalPlanDto) {
    return this.weddingPlansService.importLocalPlan(currentUser, dto);
  }
}
