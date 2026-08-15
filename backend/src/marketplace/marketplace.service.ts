import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import {
  City,
  FavoriteProvider,
  Prisma,
  Provider,
  ProviderCategory,
  ProviderPackage,
  ProviderReview,
  ProviderService,
  ProviderServiceImage,
  ProviderStatus,
  PlanProviderLink,
  QuoteOffer,
  QuoteRequest,
  ReviewStatus,
  User,
  WeddingPlan,
} from "@prisma/client";
import { AuthenticatedUser } from "../modules/identity/public/identity-session.types";
import { ContributionHistoryService } from "../contribution-history/contribution-history.service";
import { PhoneNormalizer } from "../shared-kernel/phone/phone-normalizer";
import { runSerializableTransaction } from "../platform/database/serializable-transaction";
import { NotificationsService } from "../notifications/notifications.service";
import { PrismaService } from "../platform/database/prisma.service";
import {
  livePlanAuthorizationWhere,
  PermissionService,
} from "../sharing/permission.service";
import { normalizeWeddingLocationInput } from "../wedding-plans/wedding-location";
import { toWeddingCostResponse } from "../wedding-costs/wedding-cost.presenter";
import { CreatePlanQuoteRequestDto } from "./dto/create-plan-quote-request.dto";
import { CreateProviderReviewDto } from "./dto/create-provider-review.dto";
import { CreateQuoteRequestDto } from "./dto/create-quote-request.dto";
import { ListProvidersQueryDto } from "./dto/list-providers-query.dto";
import { ListServicesQueryDto } from "./dto/list-services-query.dto";
import { UpdateProviderReviewDto } from "./dto/update-provider-review.dto";
import { quoteLifecycleStatus } from "./quote-lifecycle";
import { rejectQuoteOfferInTransaction } from "./quote-offer-rejection";
import { createQuoteRequestInTransaction } from "./quote-request-creation";
import { cancelQuoteRequestInTransaction } from "./quote-request-cancellation";
import { runProviderReviewMutation } from "./provider-review-rating";
import {
  assertMarketplaceProviderActive,
  assertProviderAccountUnchanged,
  lockMarketplaceMutationUsers,
  lockMarketplaceProvider,
} from "./marketplace-write-locks";

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
import { YemenAdministrativePresenter } from "./yemen-administrative.presenter";
import { acceptQuoteOfferInTransaction } from "./quote-offer-acceptance";
import {
  assertProviderSectionLive,
  buildMyQuoteAccessWhere,
  findAccessiblePlanQuoteRequest,
  findContributorProviderQuoteIds,
  quoteVisibilityForPlan,
} from "./marketplace-contributor-quote-scope";

export type { PaginatedResponse } from "./marketplace.contracts";

@Injectable()
export class MarketplaceService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly permissions: PermissionService,
    private readonly notifications: NotificationsService,
    private readonly contributionHistory?: ContributionHistoryService,
  ) {}

  async findCities() {
    const cities = await this.prisma.city.findMany({
      where: { isActive: true },
      orderBy: [{ sortOrder: "asc" }, { nameAr: "asc" }],
    });

    return cities.map((city) => MarketplacePresenter.toCityResponse(city));
  }

  async findGovernorates() {
    const governorates = await this.prisma.governorate.findMany({
      where: { isActive: true },
      orderBy: [{ sortOrder: "asc" }, { nameAr: "asc" }],
      include: {
        _count: {
          select: {
            districts: { where: { isActive: true } },
          },
        },
      },
    });

    return governorates.map((governorate) =>
      YemenAdministrativePresenter.toGovernorateResponse(governorate),
    );
  }

  async findGovernorateDistricts(governorateId: string) {
    const governorate = await this.prisma.governorate.findFirst({
      where: { id: governorateId, isActive: true },
      select: { id: true },
    });
    if (!governorate) {
      throw new NotFoundException({
        statusCode: 404,
        code: "GOVERNORATE_NOT_FOUND",
        message: "Governorate not found",
      });
    }
    const districts = await this.prisma.district.findMany({
      where: { governorateId, isActive: true },
      orderBy: [{ sortOrder: "asc" }, { nameAr: "asc" }],
    });

    return districts.map((district) =>
      YemenAdministrativePresenter.toDistrictResponse(district),
    );
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
        include: {
          city: true,
          primaryCategory: true,
          services: {
            where: { isActive: true }, orderBy: [{ isFeatured: "desc" }, { createdAt: "desc" }],
            select: { title: true, basePrice: true, currency: true, category: true },
          },
        },
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
      providers.map(({ services, ...provider }) =>
        MarketplacePresenter.toProviderListResponse({
          ...provider,
          servicePreviews: services,
        }),
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
      include: {
        user: {
          select: { id: true, name: true, appName: true, role: true },
        },
      },
      orderBy: { createdAt: "desc" },
    });

    return reviews.map((review) =>
      MarketplacePresenter.toReviewResponse(review),
    );
  }

  async favoriteProvider(currentUser: AuthenticatedUser, providerId: string) {
    MarketplaceQuery.assertUuid(providerId, "providerId");
    const favorite = await runSerializableTransaction(
      this.prisma,
      async (tx) => {
        const providerSeed = await tx.provider.findUnique({
          where: { id: providerId },
          select: { userId: true },
        });
        const lockedUserIds = await lockMarketplaceMutationUsers(
          tx,
          currentUser.id,
          [providerSeed?.userId],
        );
        const provider = await lockMarketplaceProvider(tx, providerId);
        assertProviderAccountUnchanged(
          provider,
          providerSeed?.userId ?? null,
          lockedUserIds,
        );
        assertMarketplaceProviderActive(provider);
        return tx.favoriteProvider.upsert({
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
          include: {
            provider: { include: { city: true, primaryCategory: true } },
          },
        });
      },
    );

    return MarketplacePresenter.toFavoriteResponse(favorite);
  }

  async unfavoriteProvider(currentUser: AuthenticatedUser, providerId: string) {
    MarketplaceQuery.assertUuid(providerId, "providerId");
    await runSerializableTransaction(this.prisma, async (tx) => {
      await lockMarketplaceMutationUsers(tx, currentUser.id);
      await tx.favoriteProvider.deleteMany({
        where: {
          userId: currentUser.id,
          providerId,
        },
      });
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
    const weddingPlanId = dto.weddingPlanId ?? null;
    const serviceId = dto.serviceId ?? null;
    const cityId = dto.cityId ?? null;
    const eventDate = MarketplaceQuery.optionalDate(dto.eventDate, "eventDate");

    const quote = await createQuoteRequestInTransaction(
      this.prisma,
      this.notifications,
      {
        requesterId: currentUser.id,
        data: {
          userId: currentUser.id,
          providerId,
          weddingPlanId,
          serviceId,
          eventDate,
          location: location ?? Prisma.JsonNull,
          cityId,
          guestCount: dto.guestCount ?? null,
          contactName,
          contactPhone,
          contactNormalizedPhone,
          message: MarketplaceQuery.optionalText(dto.message),
          budgetMin,
          budgetMax,
        },
      },
      {
        currentUser,
        permissions: this.permissions,
        history: this.contributionHistory,
      },
    );

    return MarketplacePresenter.toQuoteResponse(quote);
  }

  async createPlanQuoteRequest(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    dto: CreatePlanQuoteRequestDto,
  ) {
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
    assertProviderSectionLive(context, this.permissions);
    const quoteIds = context.isOwner
      ? null
      : await findContributorProviderQuoteIds(
          this.prisma,
          weddingPlanId,
          currentUser.id,
        );
    const quotes = await this.prisma.quoteRequest.findMany({
      where: {
        weddingPlanId,
        weddingPlan: {
          is: livePlanAuthorizationWhere(
            context,
            currentUser.id,
            [
              "canManageProviders",
              ...(this.permissions.canViewMoney(context)
                ? (["canViewMoney"] as const)
                : []),
            ],
          ),
        },
        ...(quoteIds ? { id: { in: quoteIds } } : {}),
      },
      include: MARKETPLACE_QUOTE_INCLUDE,
      orderBy: { createdAt: "desc" },
    });

    return quotes.map((quote) =>
      MarketplacePresenter.toQuoteResponse(
        quote,
        quoteVisibilityForPlan(
          context,
          this.permissions,
          currentUser.id,
          quote,
        ),
      ),
    );
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
    MarketplaceQuery.assertUuid(id, "quoteRequestId");
    const result = await cancelQuoteRequestInTransaction(
      this.prisma,
      this.permissions,
      currentUser,
      id,
      "PLAN_OR_REQUESTER",
      this.contributionHistory,
    );

    return MarketplacePresenter.toQuoteResponse(
      result.quote,
      result.visibility,
    );
  }

  async acceptQuoteOffer(currentUser: AuthenticatedUser, id: string) {
    const offer = await this.findAccessibleQuoteOfferOrThrow(currentUser, id);
    if (!offer.quoteRequest.weddingPlanId) {
      throw new BadRequestException(
        "Quote offer is not linked to a wedding plan",
      );
    }
    const weddingPlanId = offer.quoteRequest.weddingPlanId;
    // Fail-fast API preflight. The authoritative check is repeated under
    // User -> Plan -> SharedMember locks in the transaction.
    await this.permissions.assertProviderManageable(weddingPlanId, currentUser);
    await this.permissions.assertMoneyManageable(weddingPlanId, currentUser);
    const result = await acceptQuoteOfferInTransaction(
      this.prisma,
      this.permissions,
      this.notifications,
      {
        id,
        weddingPlanId,
        currentUser,
        actorUserId: currentUser.id,
      },
      this.contributionHistory,
    );

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
      weddingCost: toWeddingCostResponse(result.cost),
      automaticCostCreated: true,
      costSuggestion: {
        suggestedAction: "VIEW_COST",
        availableActions: ["VIEW_COST"],
        automaticCostCreated: true,
        costId: result.cost.id,
        quotedAmount: result.offer.amount?.toString() ?? null,
        currency: result.offer.currency ?? null,
        providerId: offer.providerId,
        providerName: result.offer.provider.businessName,
        category: result.offer.quoteRequest.service?.category.nameAr ?? null,
        planProviderLinkId: result.link.id,
        quoteRequestId: offer.quoteRequestId,
        quoteOfferId: offer.id,
      },
      nextActions: ["viewCost", "viewAcceptedProvider"],
    };
  }

  async rejectQuoteOffer(currentUser: AuthenticatedUser, id: string) {
    await this.findAccessibleQuoteOfferOrThrow(currentUser, id);

    const rejected = await rejectQuoteOfferInTransaction(
      this.prisma,
      this.permissions,
      this.notifications,
      { id, currentUser },
      this.contributionHistory,
    );

    return MarketplacePresenter.toQuoteOfferResponse(rejected);
  }

  async findMyQuoteRequests(currentUser: AuthenticatedUser) {
    const quotes = await runSerializableTransaction(this.prisma, async (tx) =>
      tx.quoteRequest.findMany({
        where: await buildMyQuoteAccessWhere(tx, currentUser.id),
        include: MARKETPLACE_QUOTE_INCLUDE,
        orderBy: { createdAt: "desc" },
      }),
    );

    return quotes.map((quote) => MarketplacePresenter.toQuoteResponse(quote));
  }

  async findMyQuoteRequest(currentUser: AuthenticatedUser, id: string) {
    MarketplaceQuery.assertUuid(id, "quoteRequestId");
    const quote = await runSerializableTransaction(this.prisma, async (tx) =>
      tx.quoteRequest.findFirst({
        where: await buildMyQuoteAccessWhere(tx, currentUser.id, id),
        include: MARKETPLACE_QUOTE_INCLUDE,
      }),
    );

    if (!quote) {
      throw new NotFoundException("Quote request not found");
    }

    return MarketplacePresenter.toQuoteResponse(quote);
  }

  async cancelMyQuoteRequest(currentUser: AuthenticatedUser, id: string) {
    MarketplaceQuery.assertUuid(id, "quoteRequestId");
    const result = await cancelQuoteRequestInTransaction(
      this.prisma,
      this.permissions,
      currentUser,
      id,
      "REQUESTER_ONLY",
      this.contributionHistory,
    );
    return MarketplacePresenter.toQuoteResponse(result.quote);
  }

  async createReview(
    currentUser: AuthenticatedUser,
    providerId: string,
    dto: CreateProviderReviewDto,
  ) {
    MarketplaceQuery.assertUuid(providerId, "providerId");
    return runProviderReviewMutation(
      this.prisma,
      providerId,
      async (tx) => {
        const provider = await tx.provider.findUnique({
          where: { id: providerId },
        });
        if (!provider || provider.status !== ProviderStatus.ACTIVE) {
          throw new NotFoundException("Provider not found");
        }
        if (provider.userId === currentUser.id) {
          throw new BadRequestException(
            "Provider owners cannot review their own profile",
          );
        }

        const existing = await tx.providerReview.findUnique({
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

        const review = await tx.providerReview.create({
          data: {
            userId: currentUser.id,
            providerId,
            rating: dto.rating,
            comment: MarketplaceQuery.optionalText(dto.comment),
          },
          include: {
            user: {
              select: { id: true, name: true, appName: true, role: true },
            },
          },
        });
        return MarketplacePresenter.toReviewResponse(review);
      },
    );
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

    return runProviderReviewMutation(
      this.prisma,
      existing.providerId,
      async (tx) => {
        const current = await tx.providerReview.findFirst({
          where: { id, userId: currentUser.id },
        });
        if (!current) {
          throw new NotFoundException("Review not found");
        }
        const review = await tx.providerReview.update({
          where: { id },
          data: {
            ...(dto.rating !== undefined ? { rating: dto.rating } : {}),
            ...(dto.comment !== undefined
              ? { comment: MarketplaceQuery.optionalText(dto.comment) }
              : {}),
          },
          include: {
            user: {
              select: { id: true, name: true, appName: true, role: true },
            },
          },
        });
        return MarketplacePresenter.toReviewResponse(review);
      },
    );
  }

  async deleteReview(currentUser: AuthenticatedUser, id: string) {
    MarketplaceQuery.assertUuid(id, "reviewId");
    const existing = await this.prisma.providerReview.findFirst({
      where: { id, userId: currentUser.id },
    });

    if (!existing) {
      throw new NotFoundException("Review not found");
    }

    return runProviderReviewMutation(
      this.prisma,
      existing.providerId,
      async (tx) => {
        const current = await tx.providerReview.findFirst({
          where: { id, userId: currentUser.id },
        });
        if (!current) {
          throw new NotFoundException("Review not found");
        }
        await tx.providerReview.delete({ where: { id } });
        return { id, deleted: true };
      },
    );
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

  private async findAccessibleQuoteRequestOrThrow(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<{ quote: QuoteWithRelations; visibility: QuoteVisibility }> {
    MarketplaceQuery.assertUuid(id, "quoteRequestId");
    const quoteSeed = await this.prisma.quoteRequest.findUnique({
      where: { id },
      select: { id: true, weddingPlanId: true },
    });
    if (!quoteSeed) {
      throw new NotFoundException("Quote request not found");
    }

    if (quoteSeed.weddingPlanId) {
      const context = await this.permissions.assertPlanReadable(
        quoteSeed.weddingPlanId,
        currentUser,
      );
      assertProviderSectionLive(context, this.permissions);
      const quote = await findAccessiblePlanQuoteRequest(
        this.prisma,
        context,
        this.permissions,
        currentUser.id,
        quoteSeed.id,
        quoteSeed.weddingPlanId,
      );
      return {
        quote,
        visibility: quoteVisibilityForPlan(
          context,
          this.permissions,
          currentUser.id,
          quote,
        ),
      };
    }

    const quote = await this.prisma.quoteRequest.findFirst({
      where: {
        id: quoteSeed.id,
        userId: currentUser.id,
        weddingPlanId: null,
      },
      include: MARKETPLACE_QUOTE_INCLUDE,
    });
    if (!quote) {
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
      const context = await this.permissions.assertPlanReadable(
        offer.quoteRequest.weddingPlanId,
        currentUser,
      );
      assertProviderSectionLive(context, this.permissions);
      if (
        !context.isOwner &&
        !(await findContributorProviderQuoteIds(
          this.prisma,
          offer.quoteRequest.weddingPlanId,
          currentUser.id,
        )).includes(offer.quoteRequestId)
      ) {
        throw new NotFoundException("Quote offer not found");
      }
    } else if (offer.quoteRequest.userId !== currentUser.id) {
      throw new NotFoundException("Quote offer not found");
    }

    return offer;
  }

}
