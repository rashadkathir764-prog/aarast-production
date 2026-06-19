import { Injectable } from '@nestjs/common';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { WeddingPlansService } from '../wedding-plans/wedding-plans.service';
import { CompleteOnboardingDto } from './dto/complete-onboarding.dto';

@Injectable()
export class OnboardingService {
  constructor(private readonly weddingPlansService: WeddingPlansService) {}

  complete(currentUser: AuthenticatedUser, dto: CompleteOnboardingDto) {
    return this.weddingPlansService.completeOnboarding(currentUser, dto);
  }
}
