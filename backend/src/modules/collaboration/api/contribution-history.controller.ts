import { Controller, Get, Param, Query, UseGuards } from "@nestjs/common";
import { AuthenticatedUser } from "../../identity/public/identity-session.types";
import { CurrentUser } from "../../identity/public/current-user.decorator";
import { JwtAuthGuard } from "../../identity/public/jwt-auth.guard";
import { ContributionHistoryService } from "../internal/contribution-history.service";
import { ListContributionsDto } from "./dto/list-contributions.dto";

@Controller("api/v1/wedding-plans/:weddingPlanId/contributions")
@UseGuards(JwtAuthGuard)
export class ContributionHistoryController {
  constructor(private readonly history: ContributionHistoryService) {}

  // RA-BE-10: the summary has no route of its own; the plan's dashboard
  // reads it through the service.
  @Get()
  list(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("weddingPlanId") weddingPlanId: string,
    @Query() query: ListContributionsDto,
  ) {
    return this.history.list(currentUser, weddingPlanId, query);
  }
}
