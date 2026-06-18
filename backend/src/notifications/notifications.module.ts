import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../prisma/prisma.module';
import { PermissionService } from '../sharing/permission.service';
import { NotificationsController } from './notifications.controller';
import { NotificationsService } from './notifications.service';

@Module({
  imports: [AuthModule, PrismaModule],
  controllers: [NotificationsController],
  providers: [NotificationsService, PermissionService],
  exports: [NotificationsService],
})
export class NotificationsModule {}
