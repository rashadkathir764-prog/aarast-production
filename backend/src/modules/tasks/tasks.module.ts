import { Module } from "@nestjs/common";
import { TasksController, WeddingPlanTasksController } from "../../tasks/tasks.controller";
import { TasksServiceInternalModule } from "./internal/tasks-service.internal.module";
import { TasksPublicModule } from "./public/tasks-public.module";

@Module({
  imports: [TasksPublicModule, TasksServiceInternalModule],
  controllers: [WeddingPlanTasksController, TasksController],
})
export class TasksModule {}
