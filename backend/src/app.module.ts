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
import { OTP_CAPACITY_READINESS_PORT } from "./platform/health/otp-capacity-readiness.port";
import { OtpCapacityPublicModule } from "./modules/identity/public/otp-capacity-public.module";
import { OTP_CAPACITY_PORT } from "./modules/identity/public/otp-capacity.port";
import { PrismaModule } from "./platform/database/prisma.module";
import { MediaStoragePublicModule } from "./modules/media/public/media-storage-public.module";
import { MEDIA_STORAGE_PORT } from "./modules/media/public/media-storage.port";
import { ApplicationOutboxRuntimeModule } from "./application-composition/application-outbox-runtime.module";
import { IdentityModule } from "./modules/identity/identity.module";
import { PlanningModule } from "./modules/planning/planning.module";
import { FinanceModule } from "./modules/finance/finance.module";
import { CollaborationModule } from "./modules/collaboration/collaboration.module";
import { TasksModule } from "./modules/tasks/tasks.module";
import { GuestsModule } from "./modules/guests/guests.module";
import { MarketplaceModule } from "./modules/marketplace/marketplace.module";
import { CatalogModule } from "./modules/catalog/catalog.module";
import { MediaModule } from "./modules/media/media.module";
import { InsightsModule } from "./modules/insights/insights.module";
import { BackofficeModule } from "./modules/backoffice/backoffice.module";
import { AdminAuditLogPublicModule } from "./modules/backoffice/public/admin-audit-log-public.module";
import { MessagingModule } from "./modules/messaging/messaging.module";
import { NotificationsModule } from "./modules/notifications/notifications.module";

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
    MarketplaceModule,
    CatalogModule,
    InsightsModule,
    NotificationsModule,
    GuestsModule,
    BackofficeModule,
    AdminAuditLogPublicModule,
    MessagingModule,
    MediaModule,
    MediaStoragePublicModule,
    OtpCapacityPublicModule,
  ],
  controllers: [HealthController, MetricsController],
  providers: [
    { provide: READINESS_FETCH, useValue: fetch },
    { provide: MEDIA_READINESS_PORT, useExisting: MEDIA_STORAGE_PORT },
    // J1-19, RA-BE-02: /ready warns before the daily code limit stops sign-ups.
    { provide: OTP_CAPACITY_READINESS_PORT, useExisting: OTP_CAPACITY_PORT },
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
