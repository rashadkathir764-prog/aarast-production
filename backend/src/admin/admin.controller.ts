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
import { AuthenticatedUser } from '../modules/identity/public/identity-session.types';
import { CurrentUser } from '../modules/identity/public/current-user.decorator';
import { JwtSessionGuard } from '../modules/identity/public/jwt-session.guard';
import { AdminGuard } from '../modules/backoffice/public/admin.guard';
import { AdminPermissionGuard } from '../modules/backoffice/public/admin-permission.guard';
import { RequireAdminPermission } from '../modules/backoffice/public/admin-permission.decorator';
import { AdminPermission } from '../modules/backoffice/domain/admin-permissions';
import { AdminService } from './admin.service';
import { AdminCategoryDto, AdminCityDto } from './dto/admin-catalog.dto';
import { AdminListedProviderDto } from './dto/admin-listed-provider.dto';
import { AdminProviderQueryDto } from './dto/admin-provider-query.dto';
import { AdminReportQueryDto } from './dto/admin-report.dto';
import {
  AdminReviewQueryDto,
  AdminReviewStatusDto,
} from './dto/admin-review.dto';
import { AdminReviewActionDto } from './dto/admin-review-action.dto';
import { AdminRequestChangesDto } from './dto/admin-request-changes.dto';
import {
  AdminEndFeaturedPeriodDto,
  AdminFeaturedPeriodQueryDto,
  AdminGrantFeaturedPeriodDto,
} from './dto/admin-featured-period.dto';
import {
  AdminClaimDecisionDto,
  AdminClaimRequestQueryDto,
} from './dto/admin-claim-request.dto';
import { AdminServiceDto, AdminServiceQueryDto } from './dto/admin-service.dto';
import {
  AdminConversationReportQueryDto,
  AdminConversationReportStatusDto,
} from './dto/admin-conversation-report.dto';

@Controller('admin')
@UseGuards(JwtSessionGuard, AdminGuard, AdminPermissionGuard)
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  @Get('dashboard/stats')
  @RequireAdminPermission(AdminPermission.DASHBOARD_READ)
  getDashboardStats() {
    return this.adminService.getDashboardStats();
  }

  // V1 checklist 4.21: success indicators and the market price report.
  @Get('reports/success')
  @RequireAdminPermission(AdminPermission.REPORTS_READ)
  getSuccessReport() {
    return this.adminService.getSuccessReport();
  }

  @Get('reports/overview')
  @RequireAdminPermission(AdminPermission.REPORTS_READ)
  getReportsOverview(@Query() query: AdminReportQueryDto) {
    return this.adminService.getReportsOverview(query);
  }

  @Get('providers/applications')
  @RequireAdminPermission(AdminPermission.PROVIDERS_READ)
  listProviderApplications(@Query() query: AdminProviderQueryDto) {
    return this.adminService.listProviderApplications(query);
  }

  @Get('providers/applications/:id')
  @RequireAdminPermission(AdminPermission.PROVIDERS_READ)
  getProviderApplication(@Param('id') id: string) {
    return this.adminService.getProviderApplication(id);
  }

  @Patch('providers/:id/approve')
  @RequireAdminPermission(AdminPermission.PROVIDERS_WRITE)
  approveProvider(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
  ) {
    return this.adminService.approveProvider(currentUser, id);
  }

  @Patch('providers/:id/reject')
  @RequireAdminPermission(AdminPermission.PROVIDERS_WRITE)
  rejectProvider(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: AdminReviewActionDto,
  ) {
    return this.adminService.rejectProvider(currentUser, id, dto);
  }

  @Patch('providers/:id/request-changes')
  @RequireAdminPermission(AdminPermission.PROVIDERS_WRITE)
  requestProviderChanges(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: AdminRequestChangesDto,
  ) {
    return this.adminService.requestProviderChanges(currentUser, id, dto);
  }

  // B-01, B-02: when the provider applied and every review step since.
  @Get('providers/:id/review-history')
  @RequireAdminPermission(AdminPermission.PROVIDERS_READ)
  getProviderReviewHistory(@Param('id') id: string) {
    return this.adminService.getProviderReviewHistory(id);
  }

  // B-12: claims of a listing the back office made, reviewed before the
  // listing becomes the account's.
  @Get('provider-claims')
  @RequireAdminPermission(AdminPermission.PROVIDERS_READ)
  listClaimRequests(@Query() query: AdminClaimRequestQueryDto) {
    return this.adminService.listClaimRequests(query);
  }

  @Post('provider-claims/:id/approve')
  @RequireAdminPermission(AdminPermission.PROVIDERS_WRITE)
  approveClaimRequest(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
  ) {
    return this.adminService.approveClaimRequest(currentUser, id);
  }

  @Post('provider-claims/:id/reject')
  @RequireAdminPermission(AdminPermission.PROVIDERS_WRITE)
  rejectClaimRequest(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: AdminClaimDecisionDto,
  ) {
    return this.adminService.rejectClaimRequest(currentUser, id, dto);
  }

  // B-43: featured placement the provider paid for outside the app, switched
  // on by hand. No money is taken or kept; every write is audited.
  @Get('featured-periods')
  @RequireAdminPermission(AdminPermission.PROVIDERS_READ)
  listFeaturedPeriods(@Query() query: AdminFeaturedPeriodQueryDto) {
    return this.adminService.listFeaturedPeriods(query);
  }

  @Get('featured-periods/summary')
  @RequireAdminPermission(AdminPermission.PROVIDERS_READ)
  getFeaturedSummary() {
    return this.adminService.getFeaturedSummary();
  }

  @Post('providers/:id/featured-periods')
  @RequireAdminPermission(AdminPermission.PROVIDERS_WRITE)
  grantFeaturedPeriod(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: AdminGrantFeaturedPeriodDto,
  ) {
    return this.adminService.grantFeaturedPeriod(currentUser, id, dto);
  }

  @Post('featured-periods/:id/end')
  @RequireAdminPermission(AdminPermission.PROVIDERS_WRITE)
  endFeaturedPeriod(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: AdminEndFeaturedPeriodDto,
  ) {
    return this.adminService.endFeaturedPeriod(currentUser, id, dto);
  }

  @Patch('providers/:id/suspend')
  @RequireAdminPermission(AdminPermission.PROVIDERS_WRITE)
  suspendProvider(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: AdminReviewActionDto,
  ) {
    return this.adminService.suspendProvider(currentUser, id, dto);
  }

  @Patch('providers/:id/activate')
  @RequireAdminPermission(AdminPermission.PROVIDERS_WRITE)
  activateProvider(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
  ) {
    return this.adminService.activateProvider(currentUser, id);
  }

  @Patch('providers/:id/verify')
  @RequireAdminPermission(AdminPermission.PROVIDERS_WRITE)
  verifyProvider(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
  ) {
    return this.adminService.setProviderVerified(currentUser, id, true);
  }

  @Patch('providers/:id/unverify')
  @RequireAdminPermission(AdminPermission.PROVIDERS_WRITE)
  unverifyProvider(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
  ) {
    return this.adminService.setProviderVerified(currentUser, id, false);
  }

  // V1 checklist 4.18: a listing for a provider without an account yet.
  @Post('providers')
  @RequireAdminPermission(AdminPermission.PROVIDERS_WRITE)
  createListedProvider(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Body() dto: AdminListedProviderDto,
  ) {
    return this.adminService.createListedProvider(currentUser, dto);
  }

  @Get('providers')
  @RequireAdminPermission(AdminPermission.PROVIDERS_READ)
  listProviders(@Query() query: AdminProviderQueryDto) {
    return this.adminService.listProviders(query);
  }

  @Get('providers/:id')
  @RequireAdminPermission(AdminPermission.PROVIDERS_READ)
  getProvider(@Param('id') id: string) {
    return this.adminService.getProvider(id);
  }

  @Get('services')
  @RequireAdminPermission(AdminPermission.SERVICES_READ)
  listServices(@Query() query: AdminServiceQueryDto) {
    return this.adminService.listServices(query);
  }

  @Post('services')
  @RequireAdminPermission(AdminPermission.SERVICES_WRITE)
  createService(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Body() dto: AdminServiceDto,
  ) {
    return this.adminService.createService(currentUser, dto);
  }

  @Patch('services/:id')
  @RequireAdminPermission(AdminPermission.SERVICES_WRITE)
  updateService(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: AdminServiceDto,
  ) {
    return this.adminService.updateService(currentUser, id, dto);
  }

  @Delete('services/:id')
  @RequireAdminPermission(AdminPermission.SERVICES_WRITE)
  deleteService(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
  ) {
    return this.adminService.deleteService(currentUser, id);
  }

  @Get('reviews')
  @RequireAdminPermission(AdminPermission.REVIEWS_READ)
  listReviews(@Query() query: AdminReviewQueryDto) {
    return this.adminService.listReviews(query);
  }

  @Patch('reviews/:id/status')
  @RequireAdminPermission(AdminPermission.REVIEWS_WRITE)
  updateReviewStatus(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: AdminReviewStatusDto,
  ) {
    return this.adminService.updateReviewStatus(currentUser, id, dto);
  }

  // B-09 (a10): hide or show the provider's reply.
  @Patch('reviews/:id/reply-status')
  @RequireAdminPermission(AdminPermission.REVIEWS_WRITE)
  updateReviewReplyStatus(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: AdminReviewStatusDto,
  ) {
    return this.adminService.updateReviewReplyStatus(currentUser, id, dto);
  }

  @Delete('reviews/:id')
  @RequireAdminPermission(AdminPermission.REVIEWS_WRITE)
  hideReview(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
  ) {
    return this.adminService.hideReview(currentUser, id);
  }

  @Get('conversation-reports')
  @RequireAdminPermission(AdminPermission.CONVERSATION_REPORTS_READ)
  listConversationReports(@Query() query: AdminConversationReportQueryDto) {
    return this.adminService.listConversationReports(query);
  }

  @Patch('conversation-reports/:id/status')
  @RequireAdminPermission(AdminPermission.CONVERSATION_REPORTS_WRITE)
  updateConversationReportStatus(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: AdminConversationReportStatusDto,
  ) {
    return this.adminService.updateConversationReportStatus(
      currentUser,
      id,
      dto,
    );
  }

  @Get('provider-categories')
  @RequireAdminPermission(AdminPermission.CATALOG_READ)
  listCategories() {
    return this.adminService.listCategories();
  }

  @Post('provider-categories')
  @RequireAdminPermission(AdminPermission.CATALOG_WRITE)
  createCategory(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Body() dto: AdminCategoryDto,
  ) {
    return this.adminService.createCategory(currentUser, dto);
  }

  @Patch('provider-categories/:id')
  @RequireAdminPermission(AdminPermission.CATALOG_WRITE)
  updateCategory(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: AdminCategoryDto,
  ) {
    return this.adminService.updateCategory(currentUser, id, dto);
  }

  @Delete('provider-categories/:id')
  @RequireAdminPermission(AdminPermission.CATALOG_WRITE)
  deleteCategory(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
  ) {
    return this.adminService.deleteCategory(currentUser, id);
  }

  @Get('cities')
  @RequireAdminPermission(AdminPermission.CATALOG_READ)
  listCities() {
    return this.adminService.listCities();
  }

  @Post('cities')
  @RequireAdminPermission(AdminPermission.CATALOG_WRITE)
  createCity(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Body() dto: AdminCityDto,
  ) {
    return this.adminService.createCity(currentUser, dto);
  }

  @Patch('cities/:id')
  @RequireAdminPermission(AdminPermission.CATALOG_WRITE)
  updateCity(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: AdminCityDto,
  ) {
    return this.adminService.updateCity(currentUser, id, dto);
  }

  @Delete('cities/:id')
  @RequireAdminPermission(AdminPermission.CATALOG_WRITE)
  deleteCity(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
  ) {
    return this.adminService.deleteCity(currentUser, id);
  }

  @Get('users')
  @RequireAdminPermission(AdminPermission.USERS_READ)
  listUsers(@Query() query: AdminProviderQueryDto) {
    return this.adminService.listUsers(query);
  }

  @Patch('users/:id/activate')
  @RequireAdminPermission(AdminPermission.USERS_WRITE)
  activateUser(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
  ) {
    return this.adminService.activateUser(currentUser, id);
  }

  @Patch('users/:id/disable')
  @RequireAdminPermission(AdminPermission.USERS_WRITE)
  disableUser(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
  ) {
    return this.adminService.disableUser(currentUser, id);
  }

  @Get('users/:id')
  @RequireAdminPermission(AdminPermission.USERS_READ)
  getUser(@Param('id') id: string) {
    return this.adminService.getUser(id);
  }
}
