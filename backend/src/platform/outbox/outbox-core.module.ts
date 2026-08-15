import { Module } from '@nestjs/common';
import { PrismaModule } from '../database/prisma.module';
import { OutboxCleanupScheduler } from './outbox-cleanup.scheduler';
import { OutboxService } from './outbox.service';

@Module({
  imports: [PrismaModule],
  providers: [OutboxService, OutboxCleanupScheduler],
  exports: [OutboxService],
})
export class OutboxCoreModule {}
