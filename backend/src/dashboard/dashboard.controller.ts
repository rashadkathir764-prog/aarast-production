import { Controller, Get, Param, UseGuards } from "@nestjs/common";
import { AuthenticatedUser } from "../modules/identity/public/identity-session.types";
import { CurrentUser } from "../modules/identity/public/current-user.decorator";
import { JwtAuthGuard } from "../modules/identity/public/jwt-auth.guard";
import { DashboardService } from "./dashboard.service";

// RA-BE-10: the old account home (`GET /api/v1/dashboard/home`) is gone; the
// app reads each plan's dashboard summary below.
@Controller("api/v1/wedding-plans/:planId")
@UseGuards(JwtAuthGuard)
export class WeddingPlanDashboardController {
  constructor(private readonly dashboardService: DashboardService) {}

  @Get("dashboard-summary")
  getDashboardSummary(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("planId") planId: string,
  ) {
    return this.dashboardService.getWeddingPlanDashboardSummary(
      currentUser,
      planId,
    );
  }

  /** D52: the plan's non-money sections as every member reads them. */
  @Get("plan-view")
  getPlanReadView(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("planId") planId: string,
  ) {
    return this.dashboardService.getPlanReadView(currentUser, planId);
  }
}
