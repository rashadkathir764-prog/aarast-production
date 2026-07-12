import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
} from "@nestjs/common";
import { AuthenticatedUser } from "../auth/authenticated-user.interface";
import { CurrentUser } from "../auth/current-user.decorator";
import { JwtAuthGuard } from "../auth/jwt-auth.guard";
import { BudgetCategoriesService } from "./budget-categories.service";
import { CreateBudgetCategoryDto } from "./dto/create-budget-category.dto";
import { UpdateBudgetCategoryDto } from "./dto/update-budget-category.dto";

@Controller("api/v1/wedding-plans/:weddingPlanId/budget-categories")
@UseGuards(JwtAuthGuard)
export class WeddingPlanBudgetCategoriesController {
  constructor(
    private readonly budgetCategoriesService: BudgetCategoriesService,
  ) {}

  @Post()
  create(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("weddingPlanId") weddingPlanId: string,
    @Body() dto: CreateBudgetCategoryDto,
  ) {
    return this.budgetCategoriesService.create(currentUser, weddingPlanId, dto);
  }

  @Get()
  findForPlan(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("weddingPlanId") weddingPlanId: string,
  ) {
    return this.budgetCategoriesService.findForPlan(currentUser, weddingPlanId);
  }
}

@Controller("api/v1/budget-categories")
@UseGuards(JwtAuthGuard)
export class BudgetCategoriesController {
  constructor(
    private readonly budgetCategoriesService: BudgetCategoriesService,
  ) {}

  @Patch(":id")
  update(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
    @Body() dto: UpdateBudgetCategoryDto,
  ) {
    return this.budgetCategoriesService.update(currentUser, id, dto);
  }

  @Delete(":id")
  remove(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
  ) {
    return this.budgetCategoriesService.remove(currentUser, id);
  }
}
