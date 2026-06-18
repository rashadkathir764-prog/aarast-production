import { Controller, Delete, Get, Param, Patch, Query, UseGuards } from '@nestjs/common';
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
  ) {
    return this.notificationsService.list(currentUser, weddingPlanId);
  }

  @Get('unread-count')
  unreadCount(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Query('weddingPlanId') weddingPlanId?: string,
  ) {
    return this.notificationsService.unreadCount(currentUser, weddingPlanId);
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

  @Delete(':id')
  remove(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
  ) {
    return this.notificationsService.remove(currentUser, id);
  }
}
