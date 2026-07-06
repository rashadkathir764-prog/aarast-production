import { Module } from '@nestjs/common';
import { APP_GUARD, APP_INTERCEPTOR } from '@nestjs/core';
import { ScheduleModule } from '@nestjs/schedule';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { IdempotencyInterceptor } from './common/idempotency/idempotency.interceptor';
import { HealthController } from './health.controller';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './auth/auth.module';
import { MeModule } from './me/me.module';
import { WeddingPlansModule } from './wedding-plans/wedding-plans.module';
import { OnboardingModule } from './onboarding/onboarding.module';
import { BudgetCategoriesModule } from './budget-categories/budget-categories.module';
import { ExpensesModule } from './expenses/expenses.module';
import { DebtsModule } from './debts/debts.module';
import { InstallmentsModule } from './installments/installments.module';
import { MoneyModule } from './money/money.module';
import { TasksModule } from './tasks/tasks.module';
import { TimelineModule } from './timeline/timeline.module';
import { SharingModule } from './sharing/sharing.module';
import { UsersModule } from './users/users.module';
import { MarketplaceModule } from './marketplace/marketplace.module';
import { ProviderDashboardModule } from './provider-dashboard/provider-dashboard.module';
import { DashboardModule } from './dashboard/dashboard.module';
import { AdminModule } from './admin/admin.module';
import { NotificationsModule } from './notifications/notifications.module';
import { GuestsModule } from './guests/guests.module';
import { ConversationsModule } from './conversations/conversations.module';
import { MediaModule } from './media/media.module';

@Module({
  imports: [
    ScheduleModule.forRoot(),
    ThrottlerModule.forRoot([
      {
        ttl: 60_000,
        limit: 1_000,
      },
    ]),
    PrismaModule,
    AuthModule,
    MeModule,
    WeddingPlansModule,
    OnboardingModule,
    BudgetCategoriesModule,
    ExpensesModule,
    DebtsModule,
    InstallmentsModule,
    MoneyModule,
    TasksModule,
    TimelineModule,
    SharingModule,
    UsersModule,
    MarketplaceModule,
    ProviderDashboardModule,
    DashboardModule,
    NotificationsModule,
    GuestsModule,
    AdminModule,
    ConversationsModule,
    MediaModule,
  ],
  controllers: [HealthController],
  providers: [
    {
      provide: APP_GUARD,
      useClass: ThrottlerGuard,
    },
    {
      provide: APP_INTERCEPTOR,
      useClass: IdempotencyInterceptor,
    },
  ],
})
export class AppModule {}
