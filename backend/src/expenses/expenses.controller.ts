import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from "@nestjs/common";
import { AuthenticatedUser } from "../auth/authenticated-user.interface";
import { CurrentUser } from "../auth/current-user.decorator";
import { JwtAuthGuard } from "../auth/jwt-auth.guard";
import { ListQueryDto } from "../common/pagination/list-query.dto";
import { CreateExpenseDto } from "./dto/create-expense.dto";
import { UpdateExpenseDto } from "./dto/update-expense.dto";
import { ExpensesService } from "./expenses.service";

@Controller("api/v1/wedding-plans/:weddingPlanId/expenses")
@UseGuards(JwtAuthGuard)
export class WeddingPlanExpensesController {
  constructor(private readonly expensesService: ExpensesService) {}

  @Post()
  create(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("weddingPlanId") weddingPlanId: string,
    @Body() dto: CreateExpenseDto,
  ) {
    return this.expensesService.create(currentUser, weddingPlanId, dto);
  }

  @Get()
  findForPlan(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("weddingPlanId") weddingPlanId: string,
    @Query() query: ListQueryDto,
  ) {
    return this.expensesService.findForPlan(currentUser, weddingPlanId, query);
  }

  @Get("summary")
  summary(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("weddingPlanId") weddingPlanId: string,
  ) {
    return this.expensesService.summary(currentUser, weddingPlanId);
  }
}

@Controller("api/v1/expenses")
@UseGuards(JwtAuthGuard)
export class ExpensesController {
  constructor(private readonly expensesService: ExpensesService) {}

  @Get(":id")
  findOne(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
  ) {
    return this.expensesService.findOne(currentUser, id);
  }

  @Patch(":id")
  update(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
    @Body() dto: UpdateExpenseDto,
  ) {
    return this.expensesService.update(currentUser, id, dto);
  }

  @Delete(":id")
  remove(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
  ) {
    return this.expensesService.remove(currentUser, id);
  }
}
