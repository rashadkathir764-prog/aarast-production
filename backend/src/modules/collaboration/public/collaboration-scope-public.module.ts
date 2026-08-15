import { Module } from '@nestjs/common';
import {
  COLLABORATION_SCOPE_IMPLEMENTATION,
  CollaborationScopeInternalModule,
} from '../internal/collaboration-scope.internal.module';
import { COLLABORATION_SCOPE_PORT } from './collaboration-scope.port';

@Module({
  imports: [CollaborationScopeInternalModule],
  providers: [
    {
      provide: COLLABORATION_SCOPE_PORT,
      useExisting: COLLABORATION_SCOPE_IMPLEMENTATION,
    },
  ],
  exports: [COLLABORATION_SCOPE_PORT],
})
export class CollaborationScopePublicModule {}
