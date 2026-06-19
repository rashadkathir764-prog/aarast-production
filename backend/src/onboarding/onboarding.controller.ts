import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CompleteOnboardingDto } from './dto/complete-onboarding.dto';
import { OnboardingService } from './onboarding.service';

@Controller('onboarding')
@UseGuards(JwtAuthGuard)
export class OnboardingController {
  constructor(private readonly onboardingService: OnboardingService) {}

  @Post('complete')
  complete(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Body() dto: CompleteOnboardingDto,
  ) {
    return this.onboardingService.complete(currentUser, dto);
  }
}

@Controller('api/v1/onboarding')
@UseGuards(JwtAuthGuard)
export class ApiV1OnboardingController {
  constructor(private readonly onboardingService: OnboardingService) {}

  @Post('complete')
  complete(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Body() dto: CompleteOnboardingDto,
  ) {
    return this.onboardingService.complete(currentUser, dto);
  }
}
