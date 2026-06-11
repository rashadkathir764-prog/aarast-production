import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../prisma/prisma.module';
import { SharingModule } from '../sharing/sharing.module';
import { ExpensesController, WeddingPlanExpensesController } from './expenses.controller';
import { ExpensesService } from './expenses.service';

@Module({
  imports: [AuthModule, PrismaModule, SharingModule],
  controllers: [WeddingPlanExpensesController, ExpensesController],
  providers: [ExpensesService],
})
export class ExpensesModule {}
