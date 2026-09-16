import { Module } from '@nestjs/common';
import { PrismaModule } from '../../../platform/database/prisma.module';
import { PlanReadPublicModule } from '../../planning/public/plan-read-public.module';
import { CollaborationErasureService } from './collaboration-erasure.service';
import { PermissionService } from './permission.service';

export const COLLABORATION_PERMISSION_IMPLEMENTATION = Symbol(
  'COLLABORATION_PERMISSION_IMPLEMENTATION',
);
export const COLLABORATION_ERASURE_IMPLEMENTATION = Symbol(
  'COLLABORATION_ERASURE_IMPLEMENTATION',
);

@Module({
  imports: [PrismaModule, PlanReadPublicModule],
  providers: [
    PermissionService,
    CollaborationErasureService,
    {
      provide: COLLABORATION_PERMISSION_IMPLEMENTATION,
      useExisting: PermissionService,
    },
    {
      provide: COLLABORATION_ERASURE_IMPLEMENTATION,
      useExisting: CollaborationErasureService,
    },
  ],
  exports: [
    PermissionService,
    CollaborationErasureService,
    COLLABORATION_PERMISSION_IMPLEMENTATION,
    COLLABORATION_ERASURE_IMPLEMENTATION,
  ],
})
export class CollaborationPermissionInternalModule {}
