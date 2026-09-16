import { Module } from '@nestjs/common';
import {
  COLLABORATION_ERASURE_IMPLEMENTATION,
  CollaborationPermissionInternalModule,
} from '../internal/collaboration-permission.internal.module';
import { COLLABORATION_ERASURE_PORT } from './collaboration-erasure.port';

@Module({
  imports: [CollaborationPermissionInternalModule],
  providers: [
    {
      provide: COLLABORATION_ERASURE_PORT,
      useExisting: COLLABORATION_ERASURE_IMPLEMENTATION,
    },
  ],
  exports: [COLLABORATION_ERASURE_PORT],
})
export class CollaborationErasurePublicModule {}
