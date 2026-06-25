import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { ApplyProviderDto } from './dto/apply-provider.dto';
import { CreateProviderPackageDto } from './dto/create-provider-package.dto';
import { CreateProviderServiceDto } from './dto/create-provider-service.dto';
import { CreateQuoteOfferDto } from './dto/create-quote-offer.dto';
import { UpdateProviderPackageDto } from './dto/update-provider-package.dto';
import { UpdateProviderProfileDto } from './dto/update-provider-profile.dto';
import { UpdateProviderQuoteStatusDto } from './dto/update-provider-quote-status.dto';
import { UpdateProviderServiceDto } from './dto/update-provider-service.dto';
import { UpdateQuoteOfferDto } from './dto/update-quote-offer.dto';
import {
  CreateServiceImageDto,
  UpdateServiceImageDto,
} from './dto/upsert-service-image.dto';
import { ProviderDashboardService } from './provider-dashboard.service';

@Controller('provider')
@UseGuards(JwtAuthGuard)
export class ProviderApplicationController {
  constructor(
    private readonly providerDashboardService: ProviderDashboardService,
  ) {}

  @Post('apply')
  apply(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Body() dto: ApplyProviderDto,
  ) {
    return this.providerDashboardService.apply(currentUser, dto);
  }
}

@Controller('provider/me')
@UseGuards(JwtAuthGuard)
export class ProviderDashboardController {
  constructor(
    private readonly providerDashboardService: ProviderDashboardService,
  ) {}

  @Get('profile')
  getProfile(@CurrentUser() currentUser: AuthenticatedUser) {
    return this.providerDashboardService.getProfile(currentUser);
  }

  @Patch('profile')
  updateProfile(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Body() dto: UpdateProviderProfileDto,
  ) {
    return this.providerDashboardService.updateProfile(currentUser, dto);
  }

  @Get('summary')
  getSummary(@CurrentUser() currentUser: AuthenticatedUser) {
    return this.providerDashboardService.getSummary(currentUser);
  }

  @Get('services')
  findServices(@CurrentUser() currentUser: AuthenticatedUser) {
    return this.providerDashboardService.findServices(currentUser);
  }

  @Post('services')
  createService(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Body() dto: CreateProviderServiceDto,
  ) {
    return this.providerDashboardService.createService(currentUser, dto);
  }

  @Post('services/:id/images')
  createServiceImage(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: CreateServiceImageDto,
  ) {
    return this.providerDashboardService.createServiceImage(
      currentUser,
      id,
      dto,
    );
  }

  @Patch('services/:serviceId/images/:imageId')
  updateServiceImage(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('serviceId') serviceId: string,
    @Param('imageId') imageId: string,
    @Body() dto: UpdateServiceImageDto,
  ) {
    return this.providerDashboardService.updateServiceImage(
      currentUser,
      serviceId,
      imageId,
      dto,
    );
  }

  @Delete('services/:serviceId/images/:imageId')
  deleteServiceImage(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('serviceId') serviceId: string,
    @Param('imageId') imageId: string,
  ) {
    return this.providerDashboardService.deleteServiceImage(
      currentUser,
      serviceId,
      imageId,
    );
  }

  @Get('services/:id')
  findService(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
  ) {
    return this.providerDashboardService.findService(currentUser, id);
  }

  @Patch('services/:id')
  updateService(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: UpdateProviderServiceDto,
  ) {
    return this.providerDashboardService.updateService(currentUser, id, dto);
  }

  @Delete('services/:id')
  deactivateService(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
  ) {
    return this.providerDashboardService.deactivateService(currentUser, id);
  }

  @Get('packages')
  findPackages(@CurrentUser() currentUser: AuthenticatedUser) {
    return this.providerDashboardService.findPackages(currentUser);
  }

  @Post('packages')
  createPackage(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Body() dto: CreateProviderPackageDto,
  ) {
    return this.providerDashboardService.createPackage(currentUser, dto);
  }

  @Patch('packages/:id')
  updatePackage(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: UpdateProviderPackageDto,
  ) {
    return this.providerDashboardService.updatePackage(currentUser, id, dto);
  }

  @Delete('packages/:id')
  deactivatePackage(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
  ) {
    return this.providerDashboardService.deactivatePackage(currentUser, id);
  }

  @Get('quote-requests')
  findQuoteRequests(@CurrentUser() currentUser: AuthenticatedUser) {
    return this.providerDashboardService.findQuoteRequests(currentUser);
  }

  @Get('quote-requests/:id')
  findQuoteRequest(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
  ) {
    return this.providerDashboardService.findQuoteRequest(currentUser, id);
  }

  @Patch('quote-requests/:id/status')
  updateQuoteRequestStatus(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: UpdateProviderQuoteStatusDto,
  ) {
    return this.providerDashboardService.updateQuoteRequestStatus(
      currentUser,
      id,
      dto,
    );
  }

  @Post('quote-requests/:id/offers')
  createQuoteOffer(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: CreateQuoteOfferDto,
  ) {
    return this.providerDashboardService.createQuoteOffer(currentUser, id, dto);
  }

  @Get('reviews')
  findReviews(@CurrentUser() currentUser: AuthenticatedUser) {
    return this.providerDashboardService.findReviews(currentUser);
  }
}

@Controller('api/v1/provider')
@UseGuards(JwtAuthGuard)
export class ApiV1ProviderController {
  constructor(
    private readonly providerDashboardService: ProviderDashboardService,
  ) {}

  @Get('me')
  getMe(@CurrentUser() currentUser: AuthenticatedUser) {
    return this.providerDashboardService.getProfile(currentUser);
  }

  @Post('profile')
  createProfile(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Body() dto: ApplyProviderDto,
  ) {
    return this.providerDashboardService.apply(currentUser, dto);
  }

  @Patch('profile')
  updateProfile(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Body() dto: UpdateProviderProfileDto,
  ) {
    return this.providerDashboardService.updateProfile(currentUser, dto);
  }

  @Post('services')
  createService(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Body() dto: CreateProviderServiceDto,
  ) {
    return this.providerDashboardService.createService(currentUser, dto);
  }

  @Patch('services/:id')
  updateService(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: UpdateProviderServiceDto,
  ) {
    return this.providerDashboardService.updateService(currentUser, id, dto);
  }

  @Delete('services/:id')
  deactivateService(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
  ) {
    return this.providerDashboardService.deactivateService(currentUser, id);
  }

  @Get('quote-requests')
  findQuoteRequests(@CurrentUser() currentUser: AuthenticatedUser) {
    return this.providerDashboardService.findQuoteRequests(currentUser);
  }

  @Get('quote-requests/:id')
  findQuoteRequest(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
  ) {
    return this.providerDashboardService.findQuoteRequest(currentUser, id);
  }

  @Post('quote-requests/:id/offers')
  createQuoteOffer(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: CreateQuoteOfferDto,
  ) {
    return this.providerDashboardService.createQuoteOffer(currentUser, id, dto);
  }

  @Patch('quote-offers/:id')
  updateQuoteOffer(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: UpdateQuoteOfferDto,
  ) {
    return this.providerDashboardService.updateQuoteOffer(currentUser, id, dto);
  }
}
