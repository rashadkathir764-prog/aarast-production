import { Body, Controller, Post, UseGuards } from "@nestjs/common";
import { AuthenticatedUser } from "../modules/identity/public/identity-session.types";
import { CurrentUser } from "../modules/identity/public/current-user.decorator";
import { JwtAuthGuard } from "../modules/identity/public/jwt-auth.guard";
import { CompleteOnboardingDto } from "./dto/complete-onboarding.dto";
import { ImportLocalPlanDto } from "./dto/import-local-plan.dto";
import { OnboardingService } from "./onboarding.service";

@Controller("api/v1/onboarding")
@UseGuards(JwtAuthGuard)
export class OnboardingController {
  constructor(private readonly onboardingService: OnboardingService) {}

  @Post("complete")
  complete(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Body() dto: CompleteOnboardingDto,
  ) {
    return this.onboardingService.complete(currentUser, dto);
  }

  @Post("import-local")
  importLocal(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Body() dto: ImportLocalPlanDto,
  ) {
    return this.onboardingService.importLocal(currentUser, dto);
  }
}
