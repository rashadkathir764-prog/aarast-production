import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../prisma/prisma.module';
import { SharingModule } from '../sharing/sharing.module';
import {
  ApiV1BudgetCategoriesController,
  ApiV1WeddingPlanBudgetCategoriesController,
  BudgetCategoriesController,
  WeddingPlanBudgetCategoriesController,
} from './budget-categories.controller';
import { BudgetCategoriesService } from './budget-categories.service';

@Module({
  imports: [AuthModule, PrismaModule, SharingModule],
  controllers: [
    WeddingPlanBudgetCategoriesController,
    BudgetCategoriesController,
    ApiV1WeddingPlanBudgetCategoriesController,
    ApiV1BudgetCategoriesController,
  ],
  providers: [BudgetCategoriesService],
})
export class BudgetCategoriesModule {}
