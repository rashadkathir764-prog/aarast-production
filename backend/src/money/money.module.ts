import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../prisma/prisma.module';
import { SharingModule } from '../sharing/sharing.module';
import {
  ApiV1MoneySummaryController,
  MoneySummaryController,
} from './money-summary.controller';
import { MoneySummaryService } from './money-summary.service';

@Module({
  imports: [AuthModule, PrismaModule, SharingModule],
  controllers: [MoneySummaryController, ApiV1MoneySummaryController],
  providers: [MoneySummaryService],
})
export class MoneyModule {}
