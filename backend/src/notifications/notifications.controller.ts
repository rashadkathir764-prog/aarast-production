import { Controller, Delete, Get, Param, Patch, Query, UseGuards } from '@nestjs/common';
import { NotificationType } from '@prisma/client';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { NotificationsService } from './notifications.service';

@Controller('notifications')
@UseGuards(JwtAuthGuard)
export class NotificationsController {
  constructor(private readonly notificationsService: NotificationsService) {}

  @Get()
  list(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Query('weddingPlanId') weddingPlanId?: string,
    @Query('type') type?: NotificationType,
    @Query('unreadOnly') unreadOnly?: string,
  ) {
    return this.notificationsService.list(
      currentUser,
      weddingPlanId,
      type,
      unreadOnly === 'true',
    );
  }

  @Get('unread-count')
  unreadCount(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Query('weddingPlanId') weddingPlanId?: string,
  ) {
    return this.notificationsService.unreadCount(currentUser, weddingPlanId);
  }

  @Get(':id')
  findOne(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
  ) {
    return this.notificationsService.findOne(currentUser, id);
  }

  @Patch(':id/read')
  markRead(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
  ) {
    return this.notificationsService.markRead(currentUser, id);
  }

  @Patch('read-all')
  markAllRead(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Query('weddingPlanId') weddingPlanId?: string,
  ) {
    return this.notificationsService.markAllRead(currentUser, weddingPlanId);
  }

  @Patch(':id/archive')
  archive(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
  ) {
    return this.notificationsService.archive(currentUser, id);
  }

  @Delete(':id')
  remove(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
  ) {
    return this.notificationsService.remove(currentUser, id);
  }
}

@Controller('api/v1/notifications')
@UseGuards(JwtAuthGuard)
export class ApiV1NotificationsController extends NotificationsController {
  constructor(notificationsService: NotificationsService) {
    super(notificationsService);
  }
}
