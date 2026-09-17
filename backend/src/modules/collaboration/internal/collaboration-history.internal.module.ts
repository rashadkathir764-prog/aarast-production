import { Module } from '@nestjs/common';
import { ContributionHistoryService } from './contribution-history.service';
import { PrismaModule } from '../../../platform/database/prisma.module';
import { PlanReadPublicModule } from '../../planning/public/plan-read-public.module';
import { CollaborationPermissionInternalModule } from './collaboration-permission.internal.module';

export const COLLABORATION_HISTORY_IMPLEMENTATION = Symbol(
  'COLLABORATION_HISTORY_IMPLEMENTATION',
);

@Module({
  imports: [
    PrismaModule,
    PlanReadPublicModule,
    CollaborationPermissionInternalModule,
  ],
  providers: [
    ContributionHistoryService,
    {
      provide: COLLABORATION_HISTORY_IMPLEMENTATION,
      useExisting: ContributionHistoryService,
    },
  ],
  exports: [ContributionHistoryService, COLLABORATION_HISTORY_IMPLEMENTATION],
})
export class CollaborationHistoryInternalModule {}
