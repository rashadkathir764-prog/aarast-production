import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { AdminController } from './admin.controller';
import { AdminAuditController } from './admin-audit.controller';
import { AdminAuditService } from './admin-audit.service';
import { AdminGuard } from './admin.guard';
import { AdminPermissionGuard } from './admin-permission.guard';
import { AdminService } from './admin.service';
import { ConversationRealtimeModule } from '../conversations/conversation-realtime.module';

@Module({
  imports: [PrismaModule, ConversationRealtimeModule],
  controllers: [AdminController, AdminAuditController],
  providers: [
    AdminGuard,
    AdminPermissionGuard,
    AdminService,
    AdminAuditService,
  ],
})
export class AdminModule {}
