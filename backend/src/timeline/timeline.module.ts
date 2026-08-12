import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { ContributionHistoryModule } from '../contribution-history/contribution-history.module';
import { PrismaModule } from '../platform/database/prisma.module';
import { SharingModule } from '../sharing/sharing.module';
import { TimelineController } from './timeline.controller';
import { TimelineService } from './timeline.service';

@Module({
  imports: [AuthModule, PrismaModule, SharingModule, ContributionHistoryModule],
  controllers: [TimelineController],
  providers: [TimelineService],
})
export class TimelineModule {}
