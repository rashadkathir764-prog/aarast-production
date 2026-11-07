import { Module } from '@nestjs/common';
import { DashboardService } from '../../../dashboard/dashboard.service';
import { InsightsReadPorts } from '../../../dashboard/insights-read-ports';
import { TimelineService } from '../../../timeline/timeline.service';
import { PrismaModule } from '../../../platform/database/prisma.module';
import { CollaborationHistoryPublicModule } from '../../collaboration/public/collaboration-history-public.module';
import { CollaborationPermissionPublicModule } from '../../collaboration/public/collaboration-permission-public.module';
import { CollaborationScopePublicModule } from '../../collaboration/public/collaboration-scope-public.module';
import { NotificationsPublicModule } from '../../notifications/public/notifications-public.module';
import { IdentityAuthPublicModule } from '../../identity/public/identity-auth-public.module';
import { CatalogReadPublicModule } from '../../catalog/public/catalog-read-public.module';
import { FinancePublicModule } from '../../finance/public/finance-public.module';
import { GuestsPublicModule } from '../../guests/public/guests-public.module';
import { UserReadPublicModule } from '../../identity/public/user-read-public.module';
import { ProviderReadPublicModule } from '../../marketplace/public/provider-read-public.module';
import { QuoteReadPublicModule } from '../../marketplace/public/quote-read-public.module';
import { PlanReadPublicModule } from '../../planning/public/plan-read-public.module';
import { TasksPublicModule } from '../../tasks/public/tasks-public.module';
import { AssistantQuotaPublicModule } from '../../identity/public/assistant-quota-public.module';
import { AssistantReportPublicModule } from '../../identity/public/assistant-report-public.module';
import { AssistantRuntime } from '../../../dashboard/assistant/assistant-runtime';
import { AssistantService } from '../../../dashboard/assistant/assistant.service';

@Module({
  imports: [
    PrismaModule,
    CollaborationPermissionPublicModule,
    CollaborationHistoryPublicModule,
    CollaborationScopePublicModule,
    NotificationsPublicModule,
    IdentityAuthPublicModule,
    AssistantQuotaPublicModule,
    AssistantReportPublicModule,
    PlanReadPublicModule,
    TasksPublicModule,
    GuestsPublicModule,
    FinancePublicModule,
    ProviderReadPublicModule,
    QuoteReadPublicModule,
    UserReadPublicModule,
    CatalogReadPublicModule,
  ],
  providers: [
    InsightsReadPorts,
    DashboardService,
    TimelineService,
    AssistantRuntime,
    AssistantService,
  ],
  exports: [DashboardService, TimelineService, AssistantService],
})
export class InsightsServicesInternalModule {}
