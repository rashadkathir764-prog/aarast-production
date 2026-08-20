import { Controller, Get, Param, Query, UseGuards } from "@nestjs/common";
import { AuthenticatedUser } from "../modules/identity/public/identity-session.types";
import { CurrentUser } from "../modules/identity/public/current-user.decorator";
import { JwtAuthGuard } from "../modules/identity/public/jwt-auth.guard";
import { ContributionHistoryService } from "./contribution-history.service";
import { ListContributionsDto } from "./dto/list-contributions.dto";

@Controller("api/v1/wedding-plans/:weddingPlanId/contributions")
@UseGuards(JwtAuthGuard)
export class ContributionHistoryController {
  constructor(private readonly history: ContributionHistoryService) {}

  @Get("summary")
  summary(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("weddingPlanId") weddingPlanId: string,
    @Query("contributorUserId") contributorUserId?: string,
  ) {
    return this.history.summary(currentUser, weddingPlanId, contributorUserId);
  }

  @Get()
  list(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("weddingPlanId") weddingPlanId: string,
    @Query() query: ListContributionsDto,
  ) {
    return this.history.list(currentUser, weddingPlanId, query);
  }
}
