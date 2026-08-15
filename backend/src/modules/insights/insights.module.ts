import { Module } from '@nestjs/common';
import {
  DashboardController,
  WeddingPlanDashboardController,
} from '../../dashboard/dashboard.controller';
import { TimelineController } from '../../timeline/timeline.controller';
import { InsightsServicesInternalModule } from './internal/insights-services.internal.module';

@Module({
  imports: [InsightsServicesInternalModule],
  controllers: [
    DashboardController,
    WeddingPlanDashboardController,
    TimelineController,
  ],
})
export class InsightsModule {}
