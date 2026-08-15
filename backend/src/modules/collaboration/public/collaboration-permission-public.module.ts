import { Module } from '@nestjs/common';
import {
  COLLABORATION_PERMISSION_IMPLEMENTATION,
  CollaborationPermissionInternalModule,
} from '../internal/collaboration-permission.internal.module';
import { COLLABORATION_PERMISSION_PORT } from './collaboration-permission.port';

@Module({
  imports: [CollaborationPermissionInternalModule],
  providers: [
    {
      provide: COLLABORATION_PERMISSION_PORT,
      useExisting: COLLABORATION_PERMISSION_IMPLEMENTATION,
    },
  ],
  exports: [COLLABORATION_PERMISSION_PORT],
})
export class CollaborationPermissionPublicModule {}
