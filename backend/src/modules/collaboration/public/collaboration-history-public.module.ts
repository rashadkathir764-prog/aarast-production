import { Module } from '@nestjs/common';
import {
  COLLABORATION_HISTORY_IMPLEMENTATION,
  CollaborationHistoryInternalModule,
} from '../internal/collaboration-history.internal.module';
import { COLLABORATION_HISTORY_PORT } from './collaboration-history.port';

@Module({
  imports: [CollaborationHistoryInternalModule],
  providers: [
    {
      provide: COLLABORATION_HISTORY_PORT,
      useExisting: COLLABORATION_HISTORY_IMPLEMENTATION,
    },
  ],
  exports: [COLLABORATION_HISTORY_PORT],
})
export class CollaborationHistoryPublicModule {}
