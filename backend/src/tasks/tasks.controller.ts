import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from "@nestjs/common";
import { AuthenticatedUser } from "../modules/identity/public/identity-session.types";
import { CurrentUser } from "../modules/identity/public/current-user.decorator";
import { JwtAuthGuard } from "../modules/identity/public/jwt-auth.guard";
import { ListQueryDto } from "../platform/http/list-query.dto";
import { AssignTaskDto } from "./dto/assign-task.dto";
import { CreateChecklistItemDto } from "./dto/create-checklist-item.dto";
import { CreateTaskDto } from "./dto/create-task.dto";
import { UpdateChecklistItemDto } from "./dto/update-checklist-item.dto";
import { UpdateTaskDto } from "./dto/update-task.dto";
import { TasksService } from "./tasks.service";

@Controller("api/v1/wedding-plans/:weddingPlanId/tasks")
@UseGuards(JwtAuthGuard)
export class WeddingPlanTasksController {
  constructor(private readonly tasksService: TasksService) {}

  @Post()
  create(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("weddingPlanId") weddingPlanId: string,
    @Body() dto: CreateTaskDto,
  ) {
    return this.tasksService.create(currentUser, weddingPlanId, dto);
  }

  @Get()
  findForPlan(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("weddingPlanId") weddingPlanId: string,
    @Query() query: ListQueryDto,
  ) {
    return this.tasksService.findForPlan(currentUser, weddingPlanId, query);
  }

  @Get("summary")
  summary(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("weddingPlanId") weddingPlanId: string,
  ) {
    return this.tasksService.summary(currentUser, weddingPlanId);
  }
}

@Controller("api/v1/tasks")
@UseGuards(JwtAuthGuard)
export class TasksController {
  constructor(private readonly tasksService: TasksService) {}

  @Get(":id")
  findOne(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
  ) {
    return this.tasksService.findOne(currentUser, id);
  }

  @Post(":id/checklist")
  createChecklistItem(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
    @Body() dto: CreateChecklistItemDto,
  ) {
    return this.tasksService.createChecklistItem(currentUser, id, dto);
  }

  @Patch(":id/checklist/:itemId")
  updateChecklistItem(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
    @Param("itemId") itemId: string,
    @Body() dto: UpdateChecklistItemDto,
  ) {
    return this.tasksService.updateChecklistItem(currentUser, id, itemId, dto);
  }

  @Delete(":id/checklist/:itemId")
  removeChecklistItem(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
    @Param("itemId") itemId: string,
  ) {
    return this.tasksService.removeChecklistItem(currentUser, id, itemId);
  }

  @Patch(":id/assign")
  assign(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
    @Body() dto: AssignTaskDto,
  ) {
    return this.tasksService.assign(currentUser, id, dto);
  }

  @Patch(":id")
  update(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
    @Body() dto: UpdateTaskDto,
  ) {
    return this.tasksService.update(currentUser, id, dto);
  }

  @Delete(":id")
  remove(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
  ) {
    return this.tasksService.remove(currentUser, id);
  }
}
