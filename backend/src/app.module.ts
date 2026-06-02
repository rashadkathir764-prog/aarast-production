import { Module } from '@nestjs/common';
import { HealthController } from './health.controller';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './auth/auth.module';
import { WeddingPlansModule } from './wedding-plans/wedding-plans.module';
import { BudgetCategoriesModule } from './budget-categories/budget-categories.module';
import { ExpensesModule } from './expenses/expenses.module';

@Module({
  imports: [PrismaModule, AuthModule, WeddingPlansModule, BudgetCategoriesModule, ExpensesModule],
  controllers: [HealthController],
})
export class AppModule {}

