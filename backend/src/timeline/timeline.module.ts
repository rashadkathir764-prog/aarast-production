import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../prisma/prisma.module';
import { SharingModule } from '../sharing/sharing.module';
import { TimelineController } from './timeline.controller';
import { TimelineService } from './timeline.service';

@Module({
  imports: [AuthModule, PrismaModule, SharingModule],
  controllers: [TimelineController],
  providers: [TimelineService],
})
export class TimelineModule {}
