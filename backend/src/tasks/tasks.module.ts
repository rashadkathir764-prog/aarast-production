import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../prisma/prisma.module';
import { TasksController, WeddingPlanTasksController } from './tasks.controller';
import { TasksService } from './tasks.service';

@Module({
  imports: [AuthModule, PrismaModule],
  controllers: [WeddingPlanTasksController, TasksController],
  providers: [TasksService],
})
export class TasksModule {}
