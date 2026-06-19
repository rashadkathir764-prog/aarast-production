import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { PrismaModule } from '../prisma/prisma.module';
import { PermissionService } from './permission.service';
import {
  ApiV1InviteAcceptController,
  ApiV1InvitesController,
  ApiV1WeddingPlanInvitesController,
  ApiV1WeddingPlanMembersController,
  ApiV1WeddingPlanPermissionsController,
  SharedMembersController,
  SharedWeddingPlansController,
  WeddingPlanSharedMembersController,
} from './sharing.controller';
import { SharingService } from './sharing.service';

@Module({
  imports: [AuthModule, PrismaModule, NotificationsModule],
  controllers: [
    WeddingPlanSharedMembersController,
    SharedMembersController,
    SharedWeddingPlansController,
    ApiV1WeddingPlanMembersController,
    ApiV1WeddingPlanInvitesController,
    ApiV1InvitesController,
    ApiV1InviteAcceptController,
    ApiV1WeddingPlanPermissionsController,
  ],
  providers: [PermissionService, SharingService],
  exports: [PermissionService],
})
export class SharingModule {}
