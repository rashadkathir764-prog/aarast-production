import { Module } from '@nestjs/common';
import { TasksPortService } from './tasks-port.service';

export const TASKS_IMPLEMENTATION = Symbol('TASKS_IMPLEMENTATION');

@Module({
  providers: [
    TasksPortService,
    {
      provide: TASKS_IMPLEMENTATION,
      useExisting: TasksPortService,
    },
  ],
  exports: [TasksPortService, TASKS_IMPLEMENTATION],
})
export class TasksPortInternalModule {}
