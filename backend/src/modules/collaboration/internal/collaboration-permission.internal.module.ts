import { Module } from '@nestjs/common';
import { PrismaModule } from '../../../platform/database/prisma.module';
import { PlanReadPublicModule } from '../../planning/public/plan-read-public.module';
import { PermissionService } from './permission.service';

export const COLLABORATION_PERMISSION_IMPLEMENTATION = Symbol(
  'COLLABORATION_PERMISSION_IMPLEMENTATION',
);

@Module({
  imports: [PrismaModule, PlanReadPublicModule],
  providers: [
    PermissionService,
    {
      provide: COLLABORATION_PERMISSION_IMPLEMENTATION,
      useExisting: PermissionService,
    },
  ],
  exports: [PermissionService, COLLABORATION_PERMISSION_IMPLEMENTATION],
})
export class CollaborationPermissionInternalModule {}
