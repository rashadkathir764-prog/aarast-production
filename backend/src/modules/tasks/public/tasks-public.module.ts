import { Module } from '@nestjs/common';
import {
  TASKS_IMPLEMENTATION,
  TasksPortInternalModule,
} from '../internal/tasks-port.internal.module';
import { TASKS_PORT } from './tasks.port';

@Module({
  imports: [TasksPortInternalModule],
  providers: [
    {
      provide: TASKS_PORT,
      useExisting: TASKS_IMPLEMENTATION,
    },
  ],
  exports: [TASKS_PORT],
})
export class TasksPublicModule {}
