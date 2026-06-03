import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../prisma/prisma.module';
import { PermissionService } from './permission.service';
import {
  SharedMembersController,
  SharedWeddingPlansController,
  WeddingPlanSharedMembersController,
} from './sharing.controller';
import { SharingService } from './sharing.service';

@Module({
  imports: [AuthModule, PrismaModule],
  controllers: [
    WeddingPlanSharedMembersController,
    SharedMembersController,
    SharedWeddingPlansController,
  ],
  providers: [PermissionService, SharingService],
  exports: [PermissionService],
})
export class SharingModule {}
