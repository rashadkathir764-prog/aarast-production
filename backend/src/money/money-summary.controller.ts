import { Body, Controller, Get, Param, Put, UseGuards } from "@nestjs/common";
import { AuthenticatedUser } from "../auth/authenticated-user.interface";
import { CurrentUser } from "../auth/current-user.decorator";
import { JwtAuthGuard } from "../auth/jwt-auth.guard";
import { MoneySummaryService } from "./money-summary.service";
import { MoneyBudgetService } from "./money-budget.service";
import { ReplaceMoneyBudgetDto } from "./dto/replace-money-budget.dto";

@Controller("api/v1/wedding-plans/:planId")
@UseGuards(JwtAuthGuard)
export class MoneySummaryController {
  constructor(
    private readonly moneySummaryService: MoneySummaryService,
    private readonly moneyBudgetService: MoneyBudgetService,
  ) {}

  @Get("money-summary")
  getMoneySummary(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("planId") planId: string,
  ) {
    return this.moneySummaryService.getSummary(currentUser, planId);
  }

  @Put("money-budget")
  async replaceMoneyBudget(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("planId") planId: string,
    @Body() dto: ReplaceMoneyBudgetDto,
  ) {
    const result = await this.moneyBudgetService.replace(
      currentUser,
      planId,
      dto,
    );
    return {
      summary: result.summary,
      categories: result.categories,
      idMap: result.idMap,
    };
  }
}
