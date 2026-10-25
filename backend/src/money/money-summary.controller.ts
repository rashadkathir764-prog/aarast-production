import { Body, Controller, Get, Param, Post, Put, UseGuards } from "@nestjs/common";
import { AuthenticatedUser } from "../modules/identity/public/identity-session.types";
import { CurrentUser } from "../modules/identity/public/current-user.decorator";
import { JwtAuthGuard } from "../modules/identity/public/jwt-auth.guard";
import { MoneySummaryService } from "./money-summary.service";
import { MoneyBudgetService } from "./money-budget.service";
import { ReplaceMoneyBudgetDto } from "./dto/replace-money-budget.dto";
import { RecordMahrDto } from "./dto/record-mahr.dto";

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

  /** a06 / b01's mahr step: the owner records the mahr once (C1). */
  @Post("mahr")
  recordMahr(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("planId") planId: string,
    @Body() dto: RecordMahrDto,
  ) {
    return this.moneyBudgetService.recordMahr(currentUser, planId, dto);
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
