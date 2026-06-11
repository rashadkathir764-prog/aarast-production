import { Module } from '@nestjs/common';
import { HealthController } from './health.controller';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './auth/auth.module';
import { WeddingPlansModule } from './wedding-plans/wedding-plans.module';
import { BudgetCategoriesModule } from './budget-categories/budget-categories.module';
import { ExpensesModule } from './expenses/expenses.module';
import { DebtsModule } from './debts/debts.module';
import { InstallmentsModule } from './installments/installments.module';
import { TasksModule } from './tasks/tasks.module';
import { TimelineModule } from './timeline/timeline.module';
import { SharingModule } from './sharing/sharing.module';
import { UsersModule } from './users/users.module';
import { MarketplaceModule } from './marketplace/marketplace.module';
import { ProviderDashboardModule } from './provider-dashboard/provider-dashboard.module';
import { DashboardModule } from './dashboard/dashboard.module';

@Module({
  imports: [
    PrismaModule,
    AuthModule,
    WeddingPlansModule,
    BudgetCategoriesModule,
    ExpensesModule,
    DebtsModule,
    InstallmentsModule,
    TasksModule,
    TimelineModule,
    SharingModule,
    UsersModule,
    MarketplaceModule,
    ProviderDashboardModule,
    DashboardModule,
  ],
  controllers: [HealthController],
})
export class AppModule {}
