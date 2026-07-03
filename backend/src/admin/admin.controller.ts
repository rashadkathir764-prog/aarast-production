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
} from '@nestjs/common';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminGuard } from './admin.guard';
import { AdminService } from './admin.service';
import { AdminCategoryDto, AdminCityDto } from './dto/admin-catalog.dto';
import { AdminNotificationQueryDto } from './dto/admin-notification.dto';
import { AdminProviderQueryDto } from './dto/admin-provider-query.dto';
import { AdminReportQueryDto } from './dto/admin-report.dto';
import {
  AdminReviewQueryDto,
  AdminReviewStatusDto,
} from './dto/admin-review.dto';
import { AdminReviewActionDto } from './dto/admin-review-action.dto';
import { AdminServiceDto, AdminServiceQueryDto } from './dto/admin-service.dto';

@Controller('admin')
@UseGuards(JwtAuthGuard, AdminGuard)
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  @Get('dashboard/stats')
  getDashboardStats() {
    return this.adminService.getDashboardStats();
  }

  @Get('reports/overview')
  getReportsOverview(@Query() query: AdminReportQueryDto) {
    return this.adminService.getReportsOverview(query);
  }

  @Get('providers/applications')
  listProviderApplications(@Query() query: AdminProviderQueryDto) {
    return this.adminService.listProviderApplications(query);
  }

  @Get('providers/applications/:id')
  getProviderApplication(@Param('id') id: string) {
    return this.adminService.getProviderApplication(id);
  }

  @Patch('providers/:id/approve')
  approveProvider(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
  ) {
    return this.adminService.approveProvider(currentUser, id);
  }

  @Patch('providers/:id/reject')
  rejectProvider(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: AdminReviewActionDto,
  ) {
    return this.adminService.rejectProvider(currentUser, id, dto);
  }

  @Patch('providers/:id/request-changes')
  requestProviderChanges(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: AdminReviewActionDto,
  ) {
    return this.adminService.requestProviderChanges(currentUser, id, dto);
  }

  @Patch('providers/:id/suspend')
  suspendProvider(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: AdminReviewActionDto,
  ) {
    return this.adminService.suspendProvider(currentUser, id, dto);
  }

  @Patch('providers/:id/activate')
  activateProvider(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
  ) {
    return this.adminService.activateProvider(currentUser, id);
  }

  @Get('providers')
  listProviders(@Query() query: AdminProviderQueryDto) {
    return this.adminService.listProviders(query);
  }

  @Get('providers/:id')
  getProvider(@Param('id') id: string) {
    return this.adminService.getProvider(id);
  }

  @Get('services')
  listServices(@Query() query: AdminServiceQueryDto) {
    return this.adminService.listServices(query);
  }

  @Post('services')
  createService(@Body() dto: AdminServiceDto) {
    return this.adminService.createService(dto);
  }

  @Patch('services/:id')
  updateService(@Param('id') id: string, @Body() dto: AdminServiceDto) {
    return this.adminService.updateService(id, dto);
  }

  @Delete('services/:id')
  deleteService(@Param('id') id: string) {
    return this.adminService.deleteService(id);
  }

  @Get('reviews')
  listReviews(@Query() query: AdminReviewQueryDto) {
    return this.adminService.listReviews(query);
  }

  @Patch('reviews/:id/status')
  updateReviewStatus(
    @Param('id') id: string,
    @Body() dto: AdminReviewStatusDto,
  ) {
    return this.adminService.updateReviewStatus(id, dto);
  }

  @Delete('reviews/:id')
  hideReview(@Param('id') id: string) {
    return this.adminService.hideReview(id);
  }

  @Get('notifications')
  listNotifications(@Query() query: AdminNotificationQueryDto) {
    return this.adminService.listNotifications(query);
  }

  @Get('notifications/unread-count')
  getUnreadNotificationsCount() {
    return this.adminService.getUnreadNotificationsCount();
  }

  @Patch('notifications/:id/read')
  markNotificationRead(@Param('id') id: string) {
    return this.adminService.markNotificationRead(id);
  }

  @Patch('notifications/:id/archive')
  archiveNotification(@Param('id') id: string) {
    return this.adminService.archiveNotification(id);
  }

  @Delete('notifications/:id')
  deleteNotification(@Param('id') id: string) {
    return this.adminService.deleteNotification(id);
  }

  @Get('provider-categories')
  listCategories() {
    return this.adminService.listCategories();
  }

  @Post('provider-categories')
  createCategory(@Body() dto: AdminCategoryDto) {
    return this.adminService.createCategory(dto);
  }

  @Patch('provider-categories/:id')
  updateCategory(@Param('id') id: string, @Body() dto: AdminCategoryDto) {
    return this.adminService.updateCategory(id, dto);
  }

  @Delete('provider-categories/:id')
  deleteCategory(@Param('id') id: string) {
    return this.adminService.deleteCategory(id);
  }

  @Get('cities')
  listCities() {
    return this.adminService.listCities();
  }

  @Post('cities')
  createCity(@Body() dto: AdminCityDto) {
    return this.adminService.createCity(dto);
  }

  @Patch('cities/:id')
  updateCity(@Param('id') id: string, @Body() dto: AdminCityDto) {
    return this.adminService.updateCity(id, dto);
  }

  @Delete('cities/:id')
  deleteCity(@Param('id') id: string) {
    return this.adminService.deleteCity(id);
  }

  @Get('users')
  listUsers(@Query() query: AdminProviderQueryDto) {
    return this.adminService.listUsers(query);
  }

  @Patch('users/:id/activate')
  activateUser(@Param('id') id: string) {
    return this.adminService.activateUser(id);
  }

  @Patch('users/:id/disable')
  disableUser(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
  ) {
    return this.adminService.disableUser(currentUser, id);
  }

  @Get('users/:id')
  getUser(@Param('id') id: string) {
    return this.adminService.getUser(id);
  }
}
