import { Module } from "@nestjs/common";
import { APP_GUARD, APP_INTERCEPTOR } from "@nestjs/core";
import { ScheduleModule } from "@nestjs/schedule";
import { ThrottlerGuard, ThrottlerModule } from "@nestjs/throttler";
import { ThrottlerStorageRedisService } from "@nest-lab/throttler-storage-redis";
import { IdempotencyInterceptor } from "./common/idempotency/idempotency.interceptor";
import { MetricsController } from "./common/observability/metrics.controller";
import { HealthController } from "./health.controller";
import { PrismaModule } from "./prisma/prisma.module";
import { AuthModule } from "./auth/auth.module";
import { MeModule } from "./me/me.module";
import { WeddingPlansModule } from "./wedding-plans/wedding-plans.module";
import { OnboardingModule } from "./onboarding/onboarding.module";
import { BudgetCategoriesModule } from "./budget-categories/budget-categories.module";
import { ExpensesModule } from "./expenses/expenses.module";
import { DebtsModule } from "./debts/debts.module";
import { InstallmentsModule } from "./installments/installments.module";
import { FinancialCommitmentsModule } from "./financial-commitments/financial-commitments.module";
import { MoneyModule } from "./money/money.module";
import { TasksModule } from "./tasks/tasks.module";
import { TimelineModule } from "./timeline/timeline.module";
import { SharingModule } from "./sharing/sharing.module";
import { UsersModule } from "./users/users.module";
import { MarketplaceModule } from "./marketplace/marketplace.module";
import { ProviderDashboardModule } from "./provider-dashboard/provider-dashboard.module";
import { DashboardModule } from "./dashboard/dashboard.module";
import { AdminModule } from "./admin/admin.module";
import { NotificationsModule } from "./notifications/notifications.module";
import { GuestsModule } from "./guests/guests.module";
import { ConversationsModule } from "./conversations/conversations.module";
import { MediaModule } from "./media/media.module";

@Module({
  imports: [
    ScheduleModule.forRoot(),
    // With REDIS_URL the throttle counters are shared across replicas;
    // without it they fall back to per-process memory, which is only
    // correct while a single instance is deployed.
    ThrottlerModule.forRootAsync({
      useFactory: () => {
        const redisUrl = process.env.REDIS_URL?.trim();
        return {
          throttlers: [
            {
              ttl: 60_000,
              limit: 1_000,
            },
          ],
          ...(redisUrl
            ? { storage: new ThrottlerStorageRedisService(redisUrl) }
            : {}),
        };
      },
    }),
    PrismaModule,
    AuthModule,
    MeModule,
    WeddingPlansModule,
    OnboardingModule,
    BudgetCategoriesModule,
    ExpensesModule,
    DebtsModule,
    InstallmentsModule,
    FinancialCommitmentsModule,
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
  controllers: [HealthController, MetricsController],
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
