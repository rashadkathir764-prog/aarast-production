import { Module } from '@nestjs/common';
import { ContributorScopeService } from '../../../contribution-history/contributor-scope.service';
import { CollaborationHistoryInternalModule } from './collaboration-history.internal.module';

export const COLLABORATION_SCOPE_IMPLEMENTATION = Symbol(
  'COLLABORATION_SCOPE_IMPLEMENTATION',
);

@Module({
  imports: [CollaborationHistoryInternalModule],
  providers: [
    ContributorScopeService,
    {
      provide: COLLABORATION_SCOPE_IMPLEMENTATION,
      useExisting: ContributorScopeService,
    },
  ],
  exports: [ContributorScopeService, COLLABORATION_SCOPE_IMPLEMENTATION],
})
export class CollaborationScopeInternalModule {}
