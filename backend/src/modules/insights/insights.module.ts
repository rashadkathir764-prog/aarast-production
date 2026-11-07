import { Module } from '@nestjs/common';
import { WeddingPlanDashboardController } from '../../dashboard/dashboard.controller';
import { TimelineController } from '../../timeline/timeline.controller';
import { WeddingPlanAssistantController } from '../../dashboard/assistant/assistant.controller';
import { InsightsServicesInternalModule } from './internal/insights-services.internal.module';

@Module({
  imports: [InsightsServicesInternalModule],
  controllers: [
    WeddingPlanDashboardController,
    TimelineController,
    WeddingPlanAssistantController,
  ],
})
export class InsightsModule {}
