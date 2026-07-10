import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../prisma/prisma.module';
import { OutboxModule } from '../outbox/outbox.module';
import { PermissionService } from '../sharing/permission.service';
import {
  ApiV1NotificationsController,
  NotificationsController,
} from './notifications.controller';
import { NotificationsService } from './notifications.service';

@Module({
  imports: [AuthModule, PrismaModule, OutboxModule],
  controllers: [NotificationsController, ApiV1NotificationsController],
  providers: [NotificationsService, PermissionService],
  exports: [NotificationsService],
})
export class NotificationsModule {}
