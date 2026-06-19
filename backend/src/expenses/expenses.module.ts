import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../prisma/prisma.module';
import { SharingModule } from '../sharing/sharing.module';
import {
  ApiV1ExpensesController,
  ApiV1WeddingPlanExpensesController,
  ExpensesController,
  WeddingPlanExpensesController,
} from './expenses.controller';
import { ExpensesService } from './expenses.service';

@Module({
  imports: [AuthModule, PrismaModule, SharingModule],
  controllers: [
    WeddingPlanExpensesController,
    ExpensesController,
    ApiV1WeddingPlanExpensesController,
    ApiV1ExpensesController,
  ],
  providers: [ExpensesService],
})
export class ExpensesModule {}
