import { Module } from "@nestjs/common";
import { APP_GUARD, APP_INTERCEPTOR } from "@nestjs/core";
import { ScheduleModule } from "@nestjs/schedule";
import { ThrottlerGuard, ThrottlerModule } from "@nestjs/throttler";
import { ThrottlerStorageRedisService } from "@nest-lab/throttler-storage-redis";
import { IdempotencyInterceptor } from "./platform/idempotency/idempotency.interceptor";
import { IdempotencyCleanupScheduler } from "./platform/idempotency/idempotency-cleanup.scheduler";
import { AdminAuditInterceptor } from "./admin/admin-audit.interceptor";
import { MetricsController } from "./platform/observability/metrics.controller";
import { ResilientThrottlerStorage } from "./platform/redis/resilient-throttler-storage";
import { HealthController } from "./platform/health/health.controller";
import { READINESS_FETCH, ReadinessService } from "./platform/health/readiness.service";
import { MEDIA_READINESS_PORT } from "./platform/health/media-readiness.port";
import { PrismaModule } from "./platform/database/prisma.module";
import { TimelineModule } from "./timeline/timeline.module";
import { MarketplaceModule } from "./marketplace/marketplace.module";
import { ProviderDashboardModule } from "./provider-dashboard/provider-dashboard.module";
import { DashboardModule } from "./dashboard/dashboard.module";
import { AdminModule } from "./admin/admin.module";
import { NotificationsModule } from "./notifications/notifications.module";
import { ConversationsModule } from "./conversations/conversations.module";
import { MediaModule } from "./media/media.module";
import { MediaStoragePublicModule } from "./modules/media/public/media-storage-public.module";
import { MEDIA_STORAGE_PORT } from "./modules/media/public/media-storage.port";
import { ApplicationOutboxRuntimeModule } from "./application-composition/application-outbox-runtime.module";
import { CatalogsModule } from "./catalogs/catalogs.module";
import { IdentityModule } from "./modules/identity/identity.module";
import { PlanningModule } from "./modules/planning/planning.module";
import { FinanceModule } from "./modules/finance/finance.module";
import { CollaborationModule } from "./modules/collaboration/collaboration.module";
import { TasksModule } from "./modules/tasks/tasks.module";
import { GuestsModule } from "./modules/guests/guests.module";

@Module({
  imports: [
    ScheduleModule.forRoot(),
    // With REDIS_URL the throttle counters are shared across replicas;
    // without it they fall back to per-process memory, which is only
    // correct while a single instance is deployed.
    ThrottlerModule.forRootAsync({
      useFactory: () => {
        const redisUrl = process.env.REDIS_URL?.trim();
        // Tunable so load tests and unusual deployments can raise the
        // global ceiling without a rebuild. Per-route @Throttle limits
        // on auth endpoints are unaffected.
        const limit = Number(process.env.THROTTLE_LIMIT ?? 1_000);
        const ttl = Number(process.env.THROTTLE_TTL_MS ?? 60_000);
        return {
          throttlers: [
            {
              ttl: Number.isFinite(ttl) && ttl > 0 ? ttl : 60_000,
              limit: Number.isFinite(limit) && limit > 0 ? limit : 1_000,
            },
          ],
          ...(redisUrl
            ? {
                storage: new ResilientThrottlerStorage(
                  new ThrottlerStorageRedisService(redisUrl),
                ),
              }
            : {}),
        };
      },
    }),
    PrismaModule,
    ApplicationOutboxRuntimeModule,
    IdentityModule,
    PlanningModule,
    FinanceModule,
    CollaborationModule,
    TasksModule,
    TimelineModule,
    MarketplaceModule,
    ProviderDashboardModule,
    DashboardModule,
    NotificationsModule,
    GuestsModule,
    AdminModule,
    ConversationsModule,
    MediaModule,
    MediaStoragePublicModule,
    CatalogsModule,
  ],
  controllers: [HealthController, MetricsController],
  providers: [
    { provide: READINESS_FETCH, useValue: fetch },
    { provide: MEDIA_READINESS_PORT, useExisting: MEDIA_STORAGE_PORT },
    ReadinessService,
    IdempotencyCleanupScheduler,
    {
      provide: APP_GUARD,
      useClass: ThrottlerGuard,
    },
    {
      provide: APP_INTERCEPTOR,
      useClass: IdempotencyInterceptor,
    },
    {
      provide: APP_INTERCEPTOR,
      useClass: AdminAuditInterceptor,
    },
  ],
})
export class AppModule {}
