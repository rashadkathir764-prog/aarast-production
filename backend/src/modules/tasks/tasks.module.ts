import { Module } from "@nestjs/common";
import { TasksController, WeddingPlanTasksController } from "../../tasks/tasks.controller";
import { TasksServiceInternalModule } from "./internal/tasks-service.internal.module";

@Module({
  imports: [TasksServiceInternalModule],
  controllers: [WeddingPlanTasksController, TasksController],
})
export class TasksModule {}
