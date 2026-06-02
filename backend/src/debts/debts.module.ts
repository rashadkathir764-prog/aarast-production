import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../prisma/prisma.module';
import { DebtsController, WeddingPlanDebtsController } from './debts.controller';
import { DebtsService } from './debts.service';

@Module({
  imports: [AuthModule, PrismaModule],
  controllers: [WeddingPlanDebtsController, DebtsController],
  providers: [DebtsService],
  exports: [DebtsService],
})
export class DebtsModule {}
