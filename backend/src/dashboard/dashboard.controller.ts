import { Controller, Get, Param, UseGuards } from '@nestjs/common';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { DashboardService } from './dashboard.service';

@Controller('dashboard')
@UseGuards(JwtAuthGuard)
export class DashboardController {
  constructor(private readonly dashboardService: DashboardService) {}

  @Get('home')
  getHome(@CurrentUser() currentUser: AuthenticatedUser) {
    return this.dashboardService.getHome(currentUser);
  }
}

@Controller('wedding-plans/:planId')
@UseGuards(JwtAuthGuard)
export class WeddingPlanDashboardController {
  constructor(private readonly dashboardService: DashboardService) {}

  @Get('dashboard-summary')
  getDashboardSummary(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('planId') planId: string,
  ) {
    return this.dashboardService.getWeddingPlanDashboardSummary(
      currentUser,
      planId,
    );
  }
}

@Controller('api/v1/wedding-plans/:planId')
@UseGuards(JwtAuthGuard)
export class ApiV1WeddingPlanDashboardController {
  constructor(private readonly dashboardService: DashboardService) {}

  @Get('dashboard-summary')
  getDashboardSummary(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('planId') planId: string,
  ) {
    return this.dashboardService.getWeddingPlanDashboardSummary(
      currentUser,
      planId,
    );
  }
}
