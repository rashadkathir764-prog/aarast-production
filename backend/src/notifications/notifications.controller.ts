import {
  Controller,
  Delete,
  Get,
  Header,
  Param,
  Patch,
  Query,
  UseGuards,
} from "@nestjs/common";
import { NotificationType } from "@prisma/client";
import { AuthenticatedUser } from "../modules/identity/public/identity-session.types";
import { CurrentUser } from "../modules/identity/public/current-user.decorator";
import { JwtAuthGuard } from "../modules/identity/public/jwt-auth.guard";
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
