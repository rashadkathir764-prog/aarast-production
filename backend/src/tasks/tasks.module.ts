import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../prisma/prisma.module';
import { SharingModule } from '../sharing/sharing.module';
import {
  ApiV1TasksController,
  ApiV1WeddingPlanTasksController,
  TasksController,
  WeddingPlanTasksController,
} from './tasks.controller';
import { TasksService } from './tasks.service';

@Module({
  imports: [AuthModule, PrismaModule, SharingModule],
  controllers: [
    WeddingPlanTasksController,
    TasksController,
    ApiV1WeddingPlanTasksController,
    ApiV1TasksController,
  ],
  providers: [TasksService],
})
export class TasksModule {}
