import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from "@nestjs/common";
import { Throttle } from "@nestjs/throttler";
import { AuthenticatedUser } from "../modules/identity/public/identity-session.types";
import { CurrentUser } from "../modules/identity/public/current-user.decorator";
import { JwtAuthGuard } from "../modules/identity/public/jwt-auth.guard";
import { AcceptQuoteOfferDto } from "./dto/accept-quote-offer.dto";
import { CreatePlanQuoteRequestDto } from "./dto/create-plan-quote-request.dto";
import { CreateProviderReviewDto } from "./dto/create-provider-review.dto";
import { CreateQuoteRequestDto } from "./dto/create-quote-request.dto";
import { ListProvidersQueryDto } from "./dto/list-providers-query.dto";
import { ListServicesQueryDto } from "./dto/list-services-query.dto";
import { UpdateProviderReviewDto } from "./dto/update-provider-review.dto";
import { MarketplaceService } from "./marketplace.service";
import { RejectQuoteOfferDto } from "./dto/reject-quote-offer.dto";

@Controller("api/v1/cities")
export class CitiesController {
  constructor(private readonly marketplaceService: MarketplaceService) {}

  @Get()
  findCities() {
    return this.marketplaceService.findCities();
  }
}

@Controller("api/v1/governorates")
export class GovernoratesController {
  constructor(private readonly marketplaceService: MarketplaceService) {}

  @Get()
  findGovernorates() {
    return this.marketplaceService.findGovernorates();
  }

  @Get(":id/districts")
  findDistricts(@Param("id") id: string) {
    return this.marketplaceService.findGovernorateDistricts(id);
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

  // B-16 (f03): approved photos only; the women's album for a bride only, so
  // the reader must be known.
  @Get(":id/portfolio")
  @UseGuards(JwtAuthGuard)
  findProviderPortfolio(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
  ) {
    return this.marketplaceService.findProviderPortfolio(currentUser, id);
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

  // Public like the page itself; the app calls it when a customer opens the
  // page (not the provider's own preview). Throttled per client.
  @Post(":id/views")
  @HttpCode(200)
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  recordProviderView(@Param("id") id: string) {
    return this.marketplaceService.recordProviderView(id);
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
    @Body() dto: AcceptQuoteOfferDto,
  ) {
    return this.marketplaceService.acceptQuoteOffer(
      currentUser,
      id,
      dto.versionNo,
    );
  }

  @Patch(":id/reject")
  rejectOffer(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
    @Body() dto: RejectQuoteOfferDto = {},
  ) {
    return this.marketplaceService.rejectQuoteOffer(currentUser, id, dto);
  }
}
