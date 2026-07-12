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
import { AuthenticatedUser } from "../auth/authenticated-user.interface";
import { CurrentUser } from "../auth/current-user.decorator";
import { JwtAuthGuard } from "../auth/jwt-auth.guard";
import { CreatePlanQuoteRequestDto } from "./dto/create-plan-quote-request.dto";
import { CreateProviderReviewDto } from "./dto/create-provider-review.dto";
import { CreateQuoteRequestDto } from "./dto/create-quote-request.dto";
import { ListProvidersQueryDto } from "./dto/list-providers-query.dto";
import { ListServicesQueryDto } from "./dto/list-services-query.dto";
import { UpdateProviderReviewDto } from "./dto/update-provider-review.dto";
import { MarketplaceService } from "./marketplace.service";

@Controller("api/v1/cities")
export class CitiesController {
  constructor(private readonly marketplaceService: MarketplaceService) {}

  @Get()
  findCities() {
    return this.marketplaceService.findCities();
  }
}

@Controller("api/v1/provider-categories")
export class ProviderCategoriesController {
  constructor(private readonly marketplaceService: MarketplaceService) {}

  @Get()
  findCategories() {
    return this.marketplaceService.findCategories();
  }
}

@Controller("api/v1/providers")
export class ProvidersController {
  constructor(private readonly marketplaceService: MarketplaceService) {}

  @Get()
  findProviders(@Query() query: ListProvidersQueryDto) {
    return this.marketplaceService.findProviders(query);
  }

  @Get(":id/services")
  findProviderServices(@Param("id") id: string) {
    return this.marketplaceService.findProviderServices(id);
  }

  @Get(":id/packages")
  findProviderPackages(@Param("id") id: string) {
    return this.marketplaceService.findProviderPackages(id);
  }

  @Get(":id/reviews")
  findProviderReviews(@Param("id") id: string) {
    return this.marketplaceService.findProviderReviews(id);
  }

  @Post(":id/favorite")
  @UseGuards(JwtAuthGuard)
  favoriteProvider(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
  ) {
    return this.marketplaceService.favoriteProvider(currentUser, id);
  }

  @Delete(":id/favorite")
  @UseGuards(JwtAuthGuard)
  unfavoriteProvider(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
  ) {
    return this.marketplaceService.unfavoriteProvider(currentUser, id);
  }

  @Post(":id/quote-requests")
  @UseGuards(JwtAuthGuard)
  createQuoteRequest(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
    @Body() dto: CreateQuoteRequestDto,
  ) {
    return this.marketplaceService.createQuoteRequest(currentUser, id, dto);
  }

  @Post(":id/reviews")
  @UseGuards(JwtAuthGuard)
  createReview(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
    @Body() dto: CreateProviderReviewDto,
  ) {
    return this.marketplaceService.createReview(currentUser, id, dto);
  }

  @Get(":id")
  findProvider(@Param("id") id: string) {
    return this.marketplaceService.findProvider(id);
  }
}

@Controller("api/v1/services")
export class ServicesController {
  constructor(private readonly marketplaceService: MarketplaceService) {}

  @Get()
  findServices(@Query() query: ListServicesQueryDto) {
    return this.marketplaceService.findServices(query);
  }

  @Get(":id")
  findService(@Param("id") id: string) {
    return this.marketplaceService.findService(id);
  }
}

@Controller("api/v1/me")
@UseGuards(JwtAuthGuard)
export class MeMarketplaceController {
  constructor(private readonly marketplaceService: MarketplaceService) {}

  @Get("favorite-providers")
  findMyFavoriteProviders(@CurrentUser() currentUser: AuthenticatedUser) {
    return this.marketplaceService.findMyFavoriteProviders(currentUser);
  }

  @Get("quote-requests")
  findMyQuoteRequests(@CurrentUser() currentUser: AuthenticatedUser) {
    return this.marketplaceService.findMyQuoteRequests(currentUser);
  }

  @Get("quote-requests/:id")
  findMyQuoteRequest(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
  ) {
    return this.marketplaceService.findMyQuoteRequest(currentUser, id);
  }

  @Patch("quote-requests/:id/cancel")
  cancelMyQuoteRequest(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
  ) {
    return this.marketplaceService.cancelMyQuoteRequest(currentUser, id);
  }
}

@Controller("api/v1/reviews")
@UseGuards(JwtAuthGuard)
export class ReviewsController {
  constructor(private readonly marketplaceService: MarketplaceService) {}

  @Patch(":id")
  updateReview(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
    @Body() dto: UpdateProviderReviewDto,
  ) {
    return this.marketplaceService.updateReview(currentUser, id, dto);
  }

  @Delete(":id")
  deleteReview(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
  ) {
    return this.marketplaceService.deleteReview(currentUser, id);
  }
}

@Controller("api/v1/wedding-plans/:weddingPlanId/quote-requests")
@UseGuards(JwtAuthGuard)
export class ApiV1WeddingPlanQuoteRequestsController {
  constructor(private readonly marketplaceService: MarketplaceService) {}

  @Post()
  createQuoteRequest(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("weddingPlanId") weddingPlanId: string,
    @Body() dto: CreatePlanQuoteRequestDto,
  ) {
    return this.marketplaceService.createPlanQuoteRequest(
      currentUser,
      weddingPlanId,
      dto,
    );
  }

  @Get()
  findQuoteRequests(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("weddingPlanId") weddingPlanId: string,
  ) {
    return this.marketplaceService.findPlanQuoteRequests(
      currentUser,
      weddingPlanId,
    );
  }
}

@Controller("api/v1/quote-requests")
@UseGuards(JwtAuthGuard)
export class ApiV1QuoteRequestsController {
  constructor(private readonly marketplaceService: MarketplaceService) {}

  @Get(":id")
  findQuoteRequest(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
  ) {
    return this.marketplaceService.findQuoteRequestForCurrentUser(
      currentUser,
      id,
    );
  }

  @Patch(":id/cancel")
  cancelQuoteRequest(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
  ) {
    return this.marketplaceService.cancelQuoteRequestForCurrentUser(
      currentUser,
      id,
    );
  }
}

@Controller("api/v1/quote-offers")
@UseGuards(JwtAuthGuard)
export class ApiV1QuoteOffersController {
  constructor(private readonly marketplaceService: MarketplaceService) {}

  @Patch(":id/accept")
  acceptOffer(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
  ) {
    return this.marketplaceService.acceptQuoteOffer(currentUser, id);
  }

  @Patch(":id/reject")
  rejectOffer(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
  ) {
    return this.marketplaceService.rejectQuoteOffer(currentUser, id);
  }
}
