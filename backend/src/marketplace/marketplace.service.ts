import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import {
  City,
  FavoriteProvider,
  NotificationPriority,
  NotificationType,
  Prisma,
  Provider,
  ProviderCategory,
  ProviderPackage,
  ProviderReview,
  ProviderService,
  ProviderServiceImage,
  ProviderStatus,
  PlanProviderLink,
  PlanProviderLinkStatus,
  QuoteOffer,
  QuoteOfferStatus,
  QuoteRequest,
  QuoteRequestStatus,
  ReviewStatus,
  User,
  WeddingPlan,
} from "@prisma/client";
import { AuthenticatedUser } from "../auth/authenticated-user.interface";
import { PhoneNormalizer } from "../common/phone/phone-normalizer";
import { NotificationsService } from "../notifications/notifications.service";
import { PrismaService } from "../prisma/prisma.service";
import {
  PermissionService,
  type PlanAccessContext,
} from "../sharing/permission.service";
import { normalizeWeddingLocationInput } from "../wedding-plans/wedding-location";
import { CreatePlanQuoteRequestDto } from "./dto/create-plan-quote-request.dto";
import { CreateProviderReviewDto } from "./dto/create-provider-review.dto";
import { CreateQuoteRequestDto } from "./dto/create-quote-request.dto";
import { ListProvidersQueryDto } from "./dto/list-providers-query.dto";
import { ListServicesQueryDto } from "./dto/list-services-query.dto";
import { UpdateProviderReviewDto } from "./dto/update-provider-review.dto";
import {
  assertQuoteRequestTransition,
  quoteLifecycleStatus,
} from "./quote-lifecycle";

import {
  FULL_QUOTE_VISIBILITY,
  MARKETPLACE_QUOTE_INCLUDE,
  type QuoteVisibility,
  type QuoteWithRelations,
} from "./marketplace.contracts";
import {
  MarketplacePresenter,
  MarketplaceQuery,
} from "./marketplace.presenter";

export type { PaginatedResponse } from "./marketplace.contracts";

@Injectable()
export class MarketplaceService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly permissions: PermissionService,
    private readonly notifications: NotificationsService,
  ) {}

  async findCities() {
    const cities = await this.prisma.city.findMany({
      where: { isActive: true },
      orderBy: [{ sortOrder: "asc" }, { nameAr: "asc" }],
    });

    return cities.map((city) => MarketplacePresenter.toCityResponse(city));
  }

  async findCategories() {
    const categories = await this.prisma.providerCategory.findMany({
      where: { isActive: true },
      orderBy: [{ sortOrder: "asc" }, { nameAr: "asc" }],
    });

    return categories.map((category) =>
      MarketplacePresenter.toCategoryResponse(category),
    );
  }

  async findProviders(query: ListProvidersQueryDto) {
    const { pagination, where } = MarketplaceQuery.providerSearch(query);

    const [total, providers] = await this.prisma.$transaction([
      this.prisma.provider.count({ where }),
      this.prisma.provider.findMany({
        where,
        include: { city: true, primaryCategory: true },
        orderBy: [
          { isFeatured: "desc" },
          { ratingAverage: "desc" },
          { createdAt: "desc" },
        ],
        skip: pagination.skip,
        take: pagination.limit,
      }),
    ]);

    return MarketplaceQuery.paginate(
      providers.map((provider) =>
        MarketplacePresenter.toProviderResponse(provider),
      ),
      total,
      pagination,
    );
  }

  async findProvider(id: string) {
    MarketplaceQuery.assertUuid(id, "providerId");
    const provider = await this.prisma.provider.findFirst({
      where: { id, status: ProviderStatus.ACTIVE },
      include: {
        city: true,
        primaryCategory: true,
        services: {
          where: { isActive: true },
          include: {
            category: true,
            images: { orderBy: [{ sortOrder: "asc" }, { createdAt: "asc" }] },
          },
          orderBy: [{ isFeatured: "desc" }, { createdAt: "desc" }],
        },
      },
    });

    if (!provider) {
      throw new NotFoundException("Provider not found");
    }

    return MarketplacePresenter.toProviderResponse(provider);
  }

  async findProviderServices(providerId: string) {
    await this.findActiveProviderOrThrow(providerId);
    const services = await this.prisma.providerService.findMany({
      where: { providerId, isActive: true },
      include: {
        provider: { include: { city: true, primaryCategory: true } },
        category: true,
        city: true,
        images: { orderBy: [{ sortOrder: "asc" }, { createdAt: "asc" }] },
      },
      orderBy: [{ isFeatured: "desc" }, { createdAt: "desc" }],
    });

    return services.map((service) =>
      MarketplacePresenter.toServiceResponse(service),
    );
  }

  async findServices(query: ListServicesQueryDto) {
    const { pagination, where } = MarketplaceQuery.serviceSearch(query);

    const [total, services] = await this.prisma.$transaction([
      this.prisma.providerService.count({ where }),
      this.prisma.providerService.findMany({
        where,
        include: {
          provider: { include: { city: true, primaryCategory: true } },
          category: true,
          city: true,
          images: { orderBy: [{ sortOrder: "asc" }, { createdAt: "asc" }] },
        },
        orderBy: [
          { isFeatured: "desc" },
          { basePrice: "asc" },
          { createdAt: "desc" },
        ],
        skip: pagination.skip,
        take: pagination.limit,
      }),
    ]);

    return MarketplaceQuery.paginate(
      services.map((service) =>
        MarketplacePresenter.toServiceResponse(service),
      ),
      total,
      pagination,
    );
  }

  async findService(id: string) {
    MarketplaceQuery.assertUuid(id, "serviceId");
    const service = await this.prisma.providerService.findFirst({
      where: {
        id,
        isActive: true,
        provider: { status: ProviderStatus.ACTIVE },
      },
      include: {
        provider: { include: { city: true, primaryCategory: true } },
        category: true,
        city: true,
        images: { orderBy: [{ sortOrder: "asc" }, { createdAt: "asc" }] },
      },
    });

    if (!service) {
      throw new NotFoundException("Service not found");
    }

    return MarketplacePresenter.toServiceResponse(service);
  }

  async findProviderPackages(providerId: string) {
    await this.findActiveProviderOrThrow(providerId);
    const packages = await this.prisma.providerPackage.findMany({
      where: { providerId, isActive: true },
      include: { service: true },
      orderBy: { createdAt: "desc" },
    });

    return packages.map((providerPackage) =>
      MarketplacePresenter.toPackageResponse(providerPackage),
    );
  }

  async findProviderReviews(providerId: string) {
    await this.findActiveProviderOrThrow(providerId);
    const reviews = await this.prisma.providerReview.findMany({
      where: { providerId, status: ReviewStatus.PUBLISHED },
      include: { user: { select: { id: true, name: true } } },
      orderBy: { createdAt: "desc" },
    });

    return reviews.map((review) =>
      MarketplacePresenter.toReviewResponse(review),
    );
  }

  async favoriteProvider(currentUser: AuthenticatedUser, providerId: string) {
    await this.findActiveProviderOrThrow(providerId);
    const favorite = await this.prisma.favoriteProvider.upsert({
      where: {
        userId_providerId: {
          userId: currentUser.id,
          providerId,
        },
      },
      create: {
        userId: currentUser.id,
        providerId,
      },
      update: {},
      include: { provider: { include: { city: true, primaryCategory: true } } },
    });

    return MarketplacePresenter.toFavoriteResponse(favorite);
  }

  async unfavoriteProvider(currentUser: AuthenticatedUser, providerId: string) {
    MarketplaceQuery.assertUuid(providerId, "providerId");
    await this.prisma.favoriteProvider.deleteMany({
      where: {
        userId: currentUser.id,
        providerId,
      },
    });

    return { providerId, deleted: true };
  }

  async findMyFavoriteProviders(currentUser: AuthenticatedUser) {
    const favorites = await this.prisma.favoriteProvider.findMany({
      where: {
        userId: currentUser.id,
        provider: { status: ProviderStatus.ACTIVE },
      },
      include: { provider: { include: { city: true, primaryCategory: true } } },
      orderBy: { createdAt: "desc" },
    });

    return favorites.map((favorite) =>
      MarketplacePresenter.toFavoriteResponse(favorite),
    );
  }

  async createQuoteRequest(
    currentUser: AuthenticatedUser,
    providerId: string,
    dto: CreateQuoteRequestDto,
  ) {
    await this.findActiveProviderOrThrow(providerId);

    let plan: WeddingPlan | null = null;
    if (dto.weddingPlanId) {
      plan = (
        await this.permissions.assertProviderManageable(
          dto.weddingPlanId,
          currentUser,
        )
      ).plan;
    }

    let city: City | null = null;
    if (dto.cityId) {
      city = await this.findActiveCityOrThrow(dto.cityId);
    }

    if (dto.serviceId) {
      await this.findActiveProviderServiceOrThrow(dto.serviceId, providerId);
    }

    const budgetMin = MarketplaceQuery.optionalDecimal(
      dto.budgetMin,
      "budgetMin",
    );
    const budgetMax = MarketplaceQuery.optionalDecimal(
      dto.budgetMax,
      "budgetMax",
    );
    if (
      budgetMin !== null &&
      budgetMax !== null &&
      Number(budgetMin) > Number(budgetMax)
    ) {
      throw new BadRequestException(
        "budgetMin must be less than or equal to budgetMax",
      );
    }

    const storedPlanLocation =
      plan?.location &&
      typeof plan.location === "object" &&
      !Array.isArray(plan.location)
        ? (plan.location as Record<string, unknown>)
        : undefined;
    const location = normalizeWeddingLocationInput(
      dto.location !== undefined
        ? (dto.location ?? undefined)
        : storedPlanLocation,
      plan?.city ?? city?.nameAr ?? null,
    );
    const contactName =
      MarketplaceQuery.optionalText(dto.contactName) ?? currentUser.name.trim();
    const contactPhone =
      MarketplaceQuery.optionalText(dto.contactPhone) ?? currentUser.phone;
    const contactNormalizedPhone = PhoneNormalizer.normalizeOptional(
      contactPhone,
      "contactPhone",
    );

    const quote = await this.prisma.quoteRequest.create({
      data: {
        userId: currentUser.id,
        providerId,
        weddingPlanId: dto.weddingPlanId ?? null,
        serviceId: dto.serviceId ?? null,
        eventDate: MarketplaceQuery.optionalDate(dto.eventDate, "eventDate"),
        location: location ?? Prisma.JsonNull,
        cityId: dto.cityId ?? null,
        guestCount: dto.guestCount ?? null,
        contactName,
        contactPhone,
        contactNormalizedPhone,
        message: MarketplaceQuery.optionalText(dto.message),
        budgetMin,
        budgetMax,
      },
      include: MARKETPLACE_QUOTE_INCLUDE,
    });

    await this.notifications.createNotification({
      userId: currentUser.id,
      weddingPlanId: quote.weddingPlanId,
      type: NotificationType.QUOTE_REQUEST_SUBMITTED,
      priority: NotificationPriority.NORMAL,
      title: "تم إرسال طلب عرض السعر",
      body: `تم إرسال طلبك إلى ${quote.provider.businessName}. سنعرض الرد عند وصول عرض حقيقي من المورد.`,
      entityType: "quote_request",
      entityId: quote.id,
      routeTarget: quote.weddingPlanId
        ? `/wedding-plans/${quote.weddingPlanId}/plan-center`
        : `/providers/${quote.providerId}`,
      data: {
        quoteRequestId: quote.id,
        providerId: quote.providerId,
        weddingPlanId: quote.weddingPlanId,
      },
      dedupeKey: `${currentUser.id}:quote-submitted:${quote.id}`,
    });

    return MarketplacePresenter.toQuoteResponse(quote);
  }

  async createPlanQuoteRequest(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    dto: CreatePlanQuoteRequestDto,
  ) {
    await this.permissions.assertProviderManageable(weddingPlanId, currentUser);
    return this.createQuoteRequest(currentUser, dto.providerId, {
      ...dto,
      weddingPlanId,
    });
  }

  async findPlanQuoteRequests(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
  ) {
    const context = await this.permissions.assertPlanReadable(
      weddingPlanId,
      currentUser,
    );
    const quotes = await this.prisma.quoteRequest.findMany({
      where: { weddingPlanId },
      include: MARKETPLACE_QUOTE_INCLUDE,
      orderBy: { createdAt: "desc" },
    });

    return quotes.map((quote) =>
      MarketplacePresenter.toQuoteResponse(
        quote,
        this.quoteVisibility(context, quote, currentUser),
      ),
    );
  }

  /**
   * Contact phone and budget are only visible to members with the matching
   * permission (provider management / budget read). The member who submitted
   * the request always sees what they entered.
   */
  private quoteVisibility(
    context: PlanAccessContext,
    quote: Pick<QuoteRequest, "userId">,
    currentUser: AuthenticatedUser,
  ): QuoteVisibility {
    if (quote.userId === currentUser.id) return FULL_QUOTE_VISIBILITY;
    return {
      budget: this.permissions.canViewMoney(context),
      contact: this.permissions.canManageProviders(context),
    };
  }

  async findQuoteRequestForCurrentUser(
    currentUser: AuthenticatedUser,
    id: string,
  ) {
    const { quote, visibility } = await this.findAccessibleQuoteRequestOrThrow(
      currentUser,
      id,
    );
    return MarketplacePresenter.toQuoteResponse(quote, visibility);
  }

  async cancelQuoteRequestForCurrentUser(
    currentUser: AuthenticatedUser,
    id: string,
  ) {
    const { quote: existing } = await this.findAccessibleQuoteRequestOrThrow(
      currentUser,
      id,
    );
    let visibility: QuoteVisibility = FULL_QUOTE_VISIBILITY;
    if (existing.weddingPlanId) {
      const context = await this.permissions.assertProviderManageable(
        existing.weddingPlanId,
        currentUser,
      );
      visibility = this.quoteVisibility(context, existing, currentUser);
    }
    assertQuoteRequestTransition(
      existing.status,
      QuoteRequestStatus.CANCELLED,
      "requester",
    );
    const quote = await this.prisma.quoteRequest.update({
      where: { id: existing.id },
      data: {
        status: QuoteRequestStatus.CANCELLED,
        cancelledAt: new Date(),
      },
      include: MARKETPLACE_QUOTE_INCLUDE,
    });

    return MarketplacePresenter.toQuoteResponse(quote, visibility);
  }

  async acceptQuoteOffer(currentUser: AuthenticatedUser, id: string) {
    const offer = await this.findAccessibleQuoteOfferOrThrow(currentUser, id);
    if (!offer.quoteRequest.weddingPlanId) {
      throw new BadRequestException(
        "Quote offer is not linked to a wedding plan",
      );
    }
    if (offer.status !== QuoteOfferStatus.PENDING) {
      throw new ConflictException("Quote offer is not pending");
    }
    const weddingPlanId = offer.quoteRequest.weddingPlanId;
    await this.permissions.assertProviderManageable(weddingPlanId, currentUser);
    assertQuoteRequestTransition(
      offer.quoteRequest.status,
      QuoteRequestStatus.ACCEPTED,
      "requester",
    );
    if (offer.validUntil && offer.validUntil.getTime() < Date.now()) {
      throw new ConflictException("Quote offer has expired");
    }

    const result = await this.prisma.$transaction(async (tx) => {
      const acceptedOffer = await tx.quoteOffer.update({
        where: { id },
        data: { status: QuoteOfferStatus.ACCEPTED },
      });

      await tx.quoteOffer.updateMany({
        where: {
          quoteRequestId: offer.quoteRequestId,
          id: { not: id },
          status: QuoteOfferStatus.PENDING,
        },
        data: { status: QuoteOfferStatus.REJECTED },
      });

      await tx.quoteRequest.update({
        where: { id: offer.quoteRequestId },
        data: {
          status: QuoteRequestStatus.ACCEPTED,
          acceptedAt: new Date(),
        },
      });

      const link = await tx.planProviderLink.upsert({
        where: {
          weddingPlanId_providerId: {
            weddingPlanId,
            providerId: offer.providerId,
          },
        },
        update: {
          quoteRequestId: offer.quoteRequestId,
          quoteOfferId: offer.id,
          status: PlanProviderLinkStatus.ACTIVE,
        },
        create: {
          weddingPlanId,
          providerId: offer.providerId,
          quoteRequestId: offer.quoteRequestId,
          quoteOfferId: offer.id,
          status: PlanProviderLinkStatus.ACTIVE,
        },
      });

      return { offer: acceptedOffer, link };
    });

    await this.notifications.createNotification({
      userId: offer.quoteRequest.userId,
      weddingPlanId,
      type: NotificationType.QUOTE_ACCEPTED,
      priority: NotificationPriority.HIGH,
      title: "تم قبول عرض السعر",
      body: "أصبح المزود ضمن مزودي الخطة المقبولين. لم يتم إنشاء تكلفة أو دفعة تلقائيًا.",
      entityType: "quote_request",
      entityId: offer.quoteRequestId,
      routeTarget: `/wedding-plans/${weddingPlanId}/plan-center`,
      data: {
        quoteRequestId: offer.quoteRequestId,
        quoteOfferId: offer.id,
        providerId: offer.providerId,
      },
      dedupeKey: `${offer.quoteRequest.userId}:quote-accepted:${offer.quoteRequestId}`,
    });

    return {
      offer: MarketplacePresenter.toQuoteOfferResponse(result.offer),
      planProviderLink: {
        id: result.link.id,
        weddingPlanId: result.link.weddingPlanId,
        providerId: result.link.providerId,
        quoteRequestId: result.link.quoteRequestId,
        quoteOfferId: result.link.quoteOfferId,
        status: result.link.status,
        createdAt: result.link.createdAt,
        updatedAt: result.link.updatedAt,
      },
      automaticCostCreated: false,
      costSuggestion: {
        recommendedAction: result.offer.amount ? "CREATE_COST" : "NONE",
        message:
          "Offer acceptance links the provider to the plan only. Create a cost explicitly to track the agreed amount, payments, and payment dates.",
        quotedAmount: result.offer.amount?.toString() ?? null,
        currency: result.offer.currency ?? null,
        providerId: offer.providerId,
        planProviderLinkId: result.link.id,
        quoteRequestId: offer.quoteRequestId,
        quoteOfferId: offer.id,
      },
      nextActions: ["createCost", "createFollowUpTask", "viewAcceptedProvider"],
    };
  }

  async rejectQuoteOffer(currentUser: AuthenticatedUser, id: string) {
    const offer = await this.findAccessibleQuoteOfferOrThrow(currentUser, id);
    if (offer.status !== QuoteOfferStatus.PENDING) {
      throw new ConflictException("Quote offer is not pending");
    }
    if (offer.quoteRequest.weddingPlanId) {
      await this.permissions.assertProviderManageable(
        offer.quoteRequest.weddingPlanId,
        currentUser,
      );
    }
    assertQuoteRequestTransition(
      offer.quoteRequest.status,
      QuoteRequestStatus.REJECTED,
      "requester",
    );

    const rejected = await this.prisma.$transaction(async (tx) => {
      const updatedOffer = await tx.quoteOffer.update({
        where: { id },
        data: { status: QuoteOfferStatus.REJECTED },
      });
      await tx.quoteRequest.update({
        where: { id: offer.quoteRequestId },
        data: {
          status: QuoteRequestStatus.REJECTED,
          rejectedAt: new Date(),
        },
      });
      return updatedOffer;
    });

    await this.notifications.createNotification({
      userId: offer.quoteRequest.userId,
      weddingPlanId: offer.quoteRequest.weddingPlanId,
      type: NotificationType.QUOTE_REJECTED,
      priority: NotificationPriority.NORMAL,
      title: "تم رفض عرض السعر",
      body: "تم إغلاق عرض السعر دون إنشاء حجز أو التزام مالي.",
      entityType: "quote_request",
      entityId: offer.quoteRequestId,
      routeTarget: offer.quoteRequest.weddingPlanId
        ? `/wedding-plans/${offer.quoteRequest.weddingPlanId}/plan-center`
        : `/providers/${offer.providerId}`,
      data: {
        quoteRequestId: offer.quoteRequestId,
        quoteOfferId: offer.id,
        providerId: offer.providerId,
      },
      dedupeKey: `${offer.quoteRequest.userId}:quote-rejected:${offer.quoteRequestId}`,
    });

    return MarketplacePresenter.toQuoteOfferResponse(rejected);
  }

  async findMyQuoteRequests(currentUser: AuthenticatedUser) {
    const quotes = await this.prisma.quoteRequest.findMany({
      where: { userId: currentUser.id },
      include: MARKETPLACE_QUOTE_INCLUDE,
      orderBy: { createdAt: "desc" },
    });

    return quotes.map((quote) => MarketplacePresenter.toQuoteResponse(quote));
  }

  async findMyQuoteRequest(currentUser: AuthenticatedUser, id: string) {
    MarketplaceQuery.assertUuid(id, "quoteRequestId");
    const quote = await this.prisma.quoteRequest.findFirst({
      where: { id, userId: currentUser.id },
      include: MARKETPLACE_QUOTE_INCLUDE,
    });

    if (!quote) {
      throw new NotFoundException("Quote request not found");
    }

    return MarketplacePresenter.toQuoteResponse(quote);
  }

  async cancelMyQuoteRequest(currentUser: AuthenticatedUser, id: string) {
    MarketplaceQuery.assertUuid(id, "quoteRequestId");
    const existing = await this.prisma.quoteRequest.findFirst({
      where: { id, userId: currentUser.id },
    });

    if (!existing) {
      throw new NotFoundException("Quote request not found");
    }
    assertQuoteRequestTransition(
      existing.status,
      QuoteRequestStatus.CANCELLED,
      "requester",
    );

    const quote = await this.prisma.quoteRequest.update({
      where: { id },
      data: {
        status: QuoteRequestStatus.CANCELLED,
        cancelledAt: new Date(),
      },
      include: MARKETPLACE_QUOTE_INCLUDE,
    });

    return MarketplacePresenter.toQuoteResponse(quote);
  }

  async createReview(
    currentUser: AuthenticatedUser,
    providerId: string,
    dto: CreateProviderReviewDto,
  ) {
    const provider = await this.findActiveProviderOrThrow(providerId);
    if (provider.userId === currentUser.id) {
      throw new BadRequestException(
        "Provider owners cannot review their own profile",
      );
    }

    const existing = await this.prisma.providerReview.findUnique({
      where: {
        userId_providerId: {
          userId: currentUser.id,
          providerId,
        },
      },
    });
    if (existing) {
      throw new ConflictException("You already reviewed this provider");
    }

    const review = await this.prisma.providerReview.create({
      data: {
        userId: currentUser.id,
        providerId,
        rating: dto.rating,
        comment: MarketplaceQuery.optionalText(dto.comment),
      },
      include: { user: { select: { id: true, name: true } } },
    });

    await this.recalculateProviderRating(providerId);
    return MarketplacePresenter.toReviewResponse(review);
  }

  async updateReview(
    currentUser: AuthenticatedUser,
    id: string,
    dto: UpdateProviderReviewDto,
  ) {
    MarketplaceQuery.assertUuid(id, "reviewId");
    const existing = await this.prisma.providerReview.findFirst({
      where: { id, userId: currentUser.id },
    });

    if (!existing) {
      throw new NotFoundException("Review not found");
    }

    const review = await this.prisma.providerReview.update({
      where: { id },
      data: {
        ...(dto.rating !== undefined ? { rating: dto.rating } : {}),
        ...(dto.comment !== undefined
          ? { comment: MarketplaceQuery.optionalText(dto.comment) }
          : {}),
      },
      include: { user: { select: { id: true, name: true } } },
    });

    await this.recalculateProviderRating(existing.providerId);
    return MarketplacePresenter.toReviewResponse(review);
  }

  async deleteReview(currentUser: AuthenticatedUser, id: string) {
    MarketplaceQuery.assertUuid(id, "reviewId");
    const existing = await this.prisma.providerReview.findFirst({
      where: { id, userId: currentUser.id },
    });

    if (!existing) {
      throw new NotFoundException("Review not found");
    }

    await this.prisma.providerReview.delete({ where: { id } });
    await this.recalculateProviderRating(existing.providerId);
    return { id, deleted: true };
  }

  private async findActiveProviderOrThrow(
    providerId: string,
  ): Promise<Provider> {
    MarketplaceQuery.assertUuid(providerId, "providerId");
    const provider = await this.prisma.provider.findFirst({
      where: { id: providerId, status: ProviderStatus.ACTIVE },
    });

    if (!provider) {
      throw new NotFoundException("Provider not found");
    }

    return provider;
  }

  private async findActiveProviderServiceOrThrow(
    serviceId: string,
    providerId: string,
  ): Promise<ProviderService> {
    MarketplaceQuery.assertUuid(serviceId, "serviceId");
    const service = await this.prisma.providerService.findFirst({
      where: {
        id: serviceId,
        providerId,
        isActive: true,
        provider: { status: ProviderStatus.ACTIVE },
      },
    });

    if (!service) {
      throw new BadRequestException(
        "serviceId must reference an active provider service",
      );
    }

    return service;
  }

  private async findActiveCityOrThrow(cityId: string): Promise<City> {
    MarketplaceQuery.assertUuid(cityId, "cityId");
    const city = await this.prisma.city.findFirst({
      where: { id: cityId, isActive: true },
    });

    if (!city) {
      throw new BadRequestException("cityId must reference an active city");
    }

    return city;
  }

  private async recalculateProviderRating(providerId: string): Promise<void> {
    const aggregate = await this.prisma.providerReview.aggregate({
      where: { providerId, status: ReviewStatus.PUBLISHED },
      _avg: { rating: true },
      _count: { _all: true },
    });
    const ratingCount = aggregate._count._all;
    const ratingAverage = ratingCount > 0 ? (aggregate._avg.rating ?? 0) : 0;

    await this.prisma.provider.update({
      where: { id: providerId },
      data: {
        ratingAverage: ratingAverage.toFixed(2),
        ratingCount,
      },
    });
  }

  private async findAccessibleQuoteRequestOrThrow(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<{ quote: QuoteWithRelations; visibility: QuoteVisibility }> {
    MarketplaceQuery.assertUuid(id, "quoteRequestId");
    const quote = await this.prisma.quoteRequest.findUnique({
      where: { id },
      include: MARKETPLACE_QUOTE_INCLUDE,
    });
    if (!quote) {
      throw new NotFoundException("Quote request not found");
    }

    if (quote.weddingPlanId) {
      const context = await this.permissions.assertPlanReadable(
        quote.weddingPlanId,
        currentUser,
      );
      return {
        quote,
        visibility: this.quoteVisibility(context, quote, currentUser),
      };
    }

    if (quote.userId !== currentUser.id) {
      throw new NotFoundException("Quote request not found");
    }

    return { quote, visibility: FULL_QUOTE_VISIBILITY };
  }

  private async findAccessibleQuoteOfferOrThrow(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<QuoteOffer & { quoteRequest: QuoteRequest }> {
    MarketplaceQuery.assertUuid(id, "quoteOfferId");
    const offer = await this.prisma.quoteOffer.findUnique({
      where: { id },
      include: { quoteRequest: true },
    });
    if (!offer) {
      throw new NotFoundException("Quote offer not found");
    }

    if (offer.quoteRequest.weddingPlanId) {
      await this.permissions.assertPlanReadable(
        offer.quoteRequest.weddingPlanId,
        currentUser,
      );
    } else if (offer.quoteRequest.userId !== currentUser.id) {
      throw new NotFoundException("Quote offer not found");
    }

    return offer;
  }
}
