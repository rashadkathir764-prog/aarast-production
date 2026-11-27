import {
  Controller,
  Delete,
  Get,
  Header,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Query,
  UseGuards,
} from "@nestjs/common";
import { NotificationType } from "@prisma/client";
import { AuthenticatedUser } from "../modules/identity/public/identity-session.types";
import { CurrentUser } from "../modules/identity/public/current-user.decorator";
import { JwtAuthGuard } from "../modules/identity/public/jwt-auth.guard";
import { REMINDER_SCHEDULE } from "../shared-kernel/time/reminder-schedule";
import { preferenceCoverage } from "./notification-preferences";
import { NotificationsService } from "./notifications.service";

@Controller("api/v1/notifications")
@UseGuards(JwtAuthGuard)
export class NotificationsController {
  constructor(private readonly notificationsService: NotificationsService) {}

  @Get()
  @Header("Cache-Control", "private, no-store")
  list(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Query("weddingPlanId") weddingPlanId?: string,
    @Query("type") type?: NotificationType,
    @Query("unreadOnly") unreadOnly?: string,
    @Query("page") page?: string,
    @Query("limit") limit?: string,
  ) {
    return this.notificationsService.list(
      currentUser,
      weddingPlanId,
      type,
      unreadOnly === "true",
      page,
      limit,
    );
  }

  @Get("unread-count")
  @Header("Cache-Control", "private, no-store")
  unreadCount(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Query("weddingPlanId") weddingPlanId?: string,
  ) {
    return this.notificationsService.unreadCount(currentUser, weddingPlanId);
  }

  /**
   * The server's reminder table, as the reminders use it
   * (`REMINDER_SCHEDULE`): the phone's «متى يصلك» lines read it. Before
   * `:id`, so «schedule» is not read as a notice's id.
   */
  @Get("schedule")
  @Header("Cache-Control", "private, max-age=3600")
  schedule() {
    // What each alert switch silences, from the rule the notices are
    // written by: the settings page says it from here.
    return { reminderSchedule: REMINDER_SCHEDULE, preferenceCoverage: preferenceCoverage() };
  }

  @Get(":id")
  @Header("Cache-Control", "private, no-store")
  findOne(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
  ) {
    return this.notificationsService.findOne(currentUser, id);
  }

  @Patch(":id/read")
  markRead(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
  ) {
    return this.notificationsService.markRead(currentUser, id);
  }

  /** The person opened the notice from the phone: opened and read, once. */
  @Patch(":id/opened")
  @HttpCode(HttpStatus.NO_CONTENT)
  async markOpened(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
  ): Promise<void> {
    await this.notificationsService.markOpened(currentUser, id);
  }

  @Patch("read-all")
  markAllRead(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Query("weddingPlanId") weddingPlanId?: string,
  ) {
    return this.notificationsService.markAllRead(currentUser, weddingPlanId);
  }

  @Patch(":id/archive")
  archive(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
  ) {
    return this.notificationsService.archive(currentUser, id);
  }

  @Delete(":id")
  remove(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
  ) {
    return this.notificationsService.remove(currentUser, id);
  }
}
