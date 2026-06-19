import { Controller, Get, Param, UseGuards } from '@nestjs/common';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { MoneySummaryService } from './money-summary.service';

@Controller('wedding-plans/:planId')
@UseGuards(JwtAuthGuard)
export class MoneySummaryController {
  constructor(private readonly moneySummaryService: MoneySummaryService) {}

  @Get('money-summary')
  getMoneySummary(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('planId') planId: string,
  ) {
    return this.moneySummaryService.getSummary(currentUser, planId);
  }
}

@Controller('api/v1/wedding-plans/:planId')
@UseGuards(JwtAuthGuard)
export class ApiV1MoneySummaryController {
  constructor(private readonly moneySummaryService: MoneySummaryService) {}

  @Get('money-summary')
  getMoneySummary(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('planId') planId: string,
  ) {
    return this.moneySummaryService.getSummary(currentUser, planId);
  }
}
