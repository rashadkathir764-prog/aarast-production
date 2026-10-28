import * as core from "../modules/marketplace/infrastructure/marketplace-core.repository";
import { hasCompletedBookingWith } from "../modules/marketplace/infrastructure/marketplace-booking.repository";
import { bookingToday } from "./booking-policy";
import { CONVERSATION_LIFECYCLE_PORT, type ConversationLifecyclePort } from "../modules/messaging/public/conversation-lifecycle.port";
import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import {
  City,
  Prisma,
  Provider,
  ProviderService,
  ProviderStatus,
  QuoteOffer,
  QuoteRequest,
  WeddingPlan,
} from "@prisma/client";
import { AuthenticatedUser } from "../modules/identity/public/identity-session.types";
import { COLLABORATION_HISTORY_PORT, type CollaborationHistoryPort as ContributionHistoryService } from "../modules/collaboration/public/collaboration-history.port";
import { PhoneNormalizer } from "../shared-kernel/phone/phone-normalizer";
import {
  runRetryableTransaction,
  runSerializableTransaction,
} from "../platform/database/serializable-transaction";
import { NOTIFICATIONS_PORT, type NotificationsPort } from "../modules/notifications/public/notifications.port";
import { PrismaService } from "../platform/database/prisma.service";
import { COLLABORATION_PERMISSION_PORT, type CollaborationPermissionPort as PermissionService, seesWholePlan } from "../modules/collaboration/public/collaboration-permission.port";
import { COLLABORATION_SCOPE_PORT, type CollaborationScopePort } from "../modules/collaboration/public/collaboration-scope.port";
import { CATALOG_READ_PORT, type CatalogReadPort } from "../modules/catalog/public/catalog-read.port";
import { MarketplaceRelationsService } from "./marketplace-relations";
import { normalizeWeddingLocationInput } from "../modules/planning/public/wedding-location";
import { toWeddingCostResponse } from "../modules/finance/public/wedding-cost.presenter";
import { CreatePlanQuoteRequestDto } from "./dto/create-plan-quote-request.dto";
import { CreateProviderReviewDto } from "./dto/create-provider-review.dto";
import { CreateQuoteRequestDto } from "./dto/create-quote-request.dto";
import { ListProvidersQueryDto } from "./dto/list-providers-query.dto";
import { ListServicesQueryDto } from "./dto/list-services-query.dto";
import { UpdateProviderReviewDto } from "./dto/update-provider-review.dto";
import { quoteLifecycleStatus } from "./quote-lifecycle";
import {
  responsivenessWindow,
  summarizeResponsiveness,
} from "./provider-responsiveness";
import { rejectQuoteOfferInTransaction } from "./quote-offer-rejection";
import { createQuoteRequestInTransaction } from "./quote-request-creation";
import { cancelQuoteRequestInTransaction } from "./quote-request-cancellation";
import { runProviderReviewMutation } from "../modules/marketplace/public/provider-review-rating";
import { reviewHasReply } from "../modules/marketplace/public/review-reply";
import { reviewReceivedProviderNotification } from "./review-notifications";
import {
  assertMarketplaceProviderActive,
  assertProviderAccountUnchanged,
  lockMarketplaceMutationUsers,
  lockMarketplaceProvider,
} from "./marketplace-write-locks";

import {
  FULL_QUOTE_VISIBILITY,
  type QuoteVisibility,
  type QuoteWithRelations,
} from "./marketplace.contracts";
import {
  MarketplacePresenter,
  MarketplaceQuery,
} from "./marketplace.presenter";
import { YemenAdministrativePresenter } from "./yemen-administrative.presenter";
import { acceptQuoteOfferInTransaction } from "./quote-offer-acceptance";
import { listApprovedPortfolio } from "../modules/marketplace/infrastructure/portfolio.repository";
import {
  isPortfolioItemVisibleTo,
  readSocialLinks,
} from "../modules/marketplace/public/provider-portfolio";
import {
  FINANCE_PORT,
  type FinancePort,
} from "../modules/finance/public/finance.port";
import {
  assertProviderSectionLive,
  buildMyQuoteAccessWhere,
  findAccessiblePlanQuoteRequest,
  findContributorProviderQuoteIds,
  type QuoteScopePorts,
  quoteVisibilityForPlan,
} from "./marketplace-contributor-quote-scope";

export type { PaginatedResponse } from "./marketplace.contracts";

@Injectable()
export class MarketplaceService {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(COLLABORATION_PERMISSION_PORT)
    private readonly permissions: PermissionService,
    @Inject(NOTIFICATIONS_PORT)
    private readonly notifications: NotificationsPort,
    @Inject(CONVERSATION_LIFECYCLE_PORT)
    private readonly lifecycle: ConversationLifecyclePort,
    @Inject(FINANCE_PORT)
    private readonly finance: FinancePort,
    @Inject(CATALOG_READ_PORT)
    private readonly catalog: CatalogReadPort,
    @Inject(COLLABORATION_SCOPE_PORT)
    private readonly scope: CollaborationScopePort,
    private readonly relations: MarketplaceRelationsService,
    @Inject(COLLABORATION_HISTORY_PORT)
    private readonly contributionHistory?: ContributionHistoryService,
  ) {}

  // The catalogs are catalog's tables, listed through its port.
  async findCities() {
    const cities = await this.catalog.listActiveCities(this.prisma);

    return cities.map((city) => MarketplacePresenter.toCityResponse(city));
  }

  async findGovernorates() {
    const governorates = await this.catalog.listActiveGovernorates(this.prisma);

    return governorates.map((governorate) =>
      YemenAdministrativePresenter.toGovernorateResponse(governorate),
    );
  }

  async findGovernorateDistricts(governorateId: string) {
    const governorate = await this.catalog.findActiveGovernorate(
      this.prisma,
      governorateId,
    );
    if (!governorate) {
      throw new NotFoundException({
        statusCode: 404,
        code: "GOVERNORATE_NOT_FOUND",
        message: "Governorate not found",
      });
    }
    const districts = await this.catalog.listActiveDistricts(
      this.prisma,
      governorateId,
    );

    return districts.map((district) =>
      YemenAdministrativePresenter.toDistrictResponse(district),
    );
  }

  async findCategories() {
    const categories = await this.catalog.listActiveCategories(this.prisma);

    return categories.map((category) =>
      MarketplacePresenter.toCategoryResponse(category),
    );
  }

  private get quoteScopePorts(): QuoteScopePorts {
    return {
      permissions: this.permissions,
      scope: this.scope,
      relations: this.relations,
    };
  }

  async findProviders(query: ListProvidersQueryDto) {
    const now = new Date();
    const { pagination, where } = MarketplaceQuery.providerSearch(query, now);
    // One snapshot for the count and both featured and regular reads (B-43).
    const [total, providerRows] = await this.prisma.$transaction(
      async (tx) => [
        await core.countActiveProviders(tx, where),
        await core.searchActiveProviders(tx, where, pagination, now),
      ] as const,
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );
    // Catalog's city and category rows are attached after the own-table read.
    const providers = await this.relations.attachProviderListCatalog(
      this.prisma,
      providerRows,
    );
    return MarketplaceQuery.paginate(
      providers.map((provider) =>
        MarketplacePresenter.toProviderListResponse(provider),
      ),
      total,
      pagination,
    );
  }

  /** A customer opened the provider's page: counted in a daily total, who viewed is not kept (V1 4.19). */
  async recordProviderView(id: string): Promise<{ recorded: true }> {
    MarketplaceQuery.assertUuid(id, "providerId");
    const day = bookingToday().toISOString().slice(0, 10);
    const counted = await core.recordProviderProfileView(this.prisma, id, day);
    if (counted === 0) throw new NotFoundException("Provider not found");
    return { recorded: true };
  }

  async findProvider(id: string) {
    MarketplaceQuery.assertUuid(id, "providerId");
    const providerRow = await core.findActiveProviderWithServices(this.prisma, id, new Date());

    if (!providerRow) {
      throw new NotFoundException("Provider not found");
    }
    const { services, ...providerOnly } = providerRow;
    const [provider] = await this.relations.attachProviderCatalog(
      this.prisma,
      [providerOnly],
    );
    const providerServices = await this.relations.attachServiceDetails(
      this.prisma,
      services.map((service) => ({ ...service, provider: providerOnly })),
    );
    const responseSample = await core.providerResponseSample(
      this.prisma,
      id,
      responsivenessWindow(new Date()),
    );

    return {
      ...MarketplacePresenter.toProviderResponse({
        ...provider,
        services: providerServices,
      }),
      responsiveness: summarizeResponsiveness(responseSample),
    };
  }

  async findProviderServices(providerId: string) {
    await this.findActiveProviderOrThrow(providerId);
    const services = await this.relations.attachServiceDetails(
      this.prisma,
      await core.listActiveProviderServices(this.prisma, providerId),
    );

    return services.map((service) =>
      MarketplacePresenter.toServiceResponse(service),
    );
  }

  async findServices(query: ListServicesQueryDto) {
    const { pagination, where } = MarketplaceQuery.serviceSearch(query);

    const [total, serviceRows] = await this.prisma.$transaction([
      core.countActiveServices(this.prisma, where),
      core.searchActiveServices(this.prisma, where, pagination),
    ]);
    const services = await this.relations.attachServiceDetails(
      this.prisma,
      serviceRows,
    );

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
    const serviceRow = await core.findActiveService(this.prisma, id);

    if (!serviceRow) {
      throw new NotFoundException("Service not found");
    }
    const [service] = await this.relations.attachServiceDetails(this.prisma, [
      serviceRow,
    ]);

    return MarketplacePresenter.toServiceResponse(service);
  }

  async findProviderPackages(providerId: string) {
    await this.findActiveProviderOrThrow(providerId);
    const packages = await core.listActiveProviderPackages(this.prisma, providerId);

    return packages.map((providerPackage) =>
      MarketplacePresenter.toPackageResponse(providerPackage),
    );
  }

  /**
   * f03 (B-16, D62): the provider's approved photos and his links. The women's
   * album «حفلات النساء» is read by a bride only (her account's persona).
   */
  async findProviderPortfolio(currentUser: AuthenticatedUser, providerId: string) {
    const provider = await this.findActiveProviderOrThrow(providerId);
    const readerIsBride = currentUser.persona === "BRIDE";
    const items = (await listApprovedPortfolio(this.prisma, provider.id)).filter((item) =>
      isPortfolioItemVisibleTo(item, readerIsBride),
    );
    return {
      items: items.map((item) => ({
        id: item.id,
        imageUrl: item.imageUrl,
        album: item.album,
        forWomen: item.forWomen,
      })),
      socialLinks: readSocialLinks(provider.socialLinks),
    };
  }

  async findProviderReviews(providerId: string) {
    await this.findActiveProviderOrThrow(providerId);
    const reviews = await this.relations.attachReviewUsers(
      this.prisma,
      await core.listPublishedProviderReviews(this.prisma, providerId),
    );

    return reviews.map((review) =>
      MarketplacePresenter.toReviewResponse(review),
    );
  }

  async favoriteProvider(currentUser: AuthenticatedUser, providerId: string) {
    MarketplaceQuery.assertUuid(providerId, "providerId");
    const favorite = await runSerializableTransaction(
      this.prisma,
      async (tx) => {
        const providerSeed = await core.findProviderAccountForFavorite(tx, providerId);
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
        return this.relations.attachFavoriteProviders(tx, [
          await core.saveFavoriteProvider(tx, currentUser.id, providerId, new Date()),
        ]);
      },
    );

    return MarketplacePresenter.toFavoriteResponse(favorite[0]);
  }

  async unfavoriteProvider(currentUser: AuthenticatedUser, providerId: string) {
    MarketplaceQuery.assertUuid(providerId, "providerId");
    await runSerializableTransaction(this.prisma, async (tx) => {
      await lockMarketplaceMutationUsers(tx, currentUser.id);
      await core.deleteFavoriteProvider(tx, currentUser.id, providerId);
    });

    return { providerId, deleted: true };
  }

  async findMyFavoriteProviders(currentUser: AuthenticatedUser) {
    const favorites = await this.relations.attachFavoriteProviders(
      this.prisma,
      await core.listMyActiveFavoriteProviders(this.prisma, currentUser.id, new Date()),
    );

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
      this.lifecycle,
      this.notifications,
      this.relations,
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
          // B-08: nothing is shared unless the customer says so.
          shareBudget: dto.shareBudget === true,
          shareContact: dto.shareContact === true,
        },
      },
      {
        currentUser,
        permissions: this.permissions,
        catalog: this.catalog,
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
    const quoteIds = seesWholePlan(context)
      ? null
      : await findContributorProviderQuoteIds(
          this.prisma,
          this.scope,
          weddingPlanId,
          currentUser.id,
        );
    // The final read re-checks current ownership/membership and the
    // provider (and money) permission through the owners and applies the
    // result to the quote table itself, in one snapshot with the read.
    const quotes = await runRetryableTransaction(
      this.prisma,
      async (tx) => {
        const liveFilter = await this.permissions.liveAuthorizationFilter(
          tx,
          context,
          currentUser.id,
          [
            "canManageProviders",
            ...(this.permissions.canViewMoney(context)
              ? (["canViewMoney"] as const)
              : []),
          ],
        );
        return this.relations.attachQuoteRelations(
          tx,
          await core.listPlanQuoteRequests(tx, weddingPlanId, quoteIds, liveFilter),
        );
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );

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
      this.lifecycle,
      this.permissions,
      this.scope,
      this.relations,
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

  async acceptQuoteOffer(
    currentUser: AuthenticatedUser,
    id: string,
    versionNo?: number,
  ) {
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
      this.lifecycle,
      this.permissions,
      this.notifications,
      this.finance,
      this.relations,
      {
        id,
        weddingPlanId,
        currentUser,
        actorUserId: currentUser.id,
        versionNo,
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
      weddingCost: toWeddingCostResponse(
        result.cost,
        result.offer.provider.businessName,
      ),
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

  async rejectQuoteOffer(
    currentUser: AuthenticatedUser,
    id: string,
    dto: { reason?: string; message?: string } = {},
  ) {
    await this.findAccessibleQuoteOfferOrThrow(currentUser, id);

    const rejected = await rejectQuoteOfferInTransaction(
      this.prisma,
      this.lifecycle,
      this.permissions,
      this.notifications,
      this.relations,
      {
        id,
        currentUser,
        reason: dto.reason ?? null,
        message: dto.message?.trim() ? dto.message.trim() : null,
      },
      this.contributionHistory,
    );

    return MarketplacePresenter.toQuoteOfferResponse(rejected);
  }

  async findMyQuoteRequests(currentUser: AuthenticatedUser) {
    const quotes = await runSerializableTransaction(this.prisma, async (tx) =>
      this.relations.attachQuoteRelations(
        tx,
        await core.listMyQuoteRequests(tx, await buildMyQuoteAccessWhere(tx, this.quoteScopePorts, currentUser.id)),
      ),
    );

    return quotes.map((quote) => MarketplacePresenter.toQuoteResponse(quote));
  }

  async findMyQuoteRequest(currentUser: AuthenticatedUser, id: string) {
    MarketplaceQuery.assertUuid(id, "quoteRequestId");
    const quote = await runSerializableTransaction(this.prisma, async (tx) => {
      const row = await core.findMyQuoteRequest(tx, await buildMyQuoteAccessWhere(tx, this.quoteScopePorts, currentUser.id, id));
      return row ? this.relations.attachQuoteRelation(tx, row) : null;
    });

    if (!quote) {
      throw new NotFoundException("Quote request not found");
    }

    return MarketplacePresenter.toQuoteResponse(quote);
  }

  async cancelMyQuoteRequest(currentUser: AuthenticatedUser, id: string) {
    MarketplaceQuery.assertUuid(id, "quoteRequestId");
    const result = await cancelQuoteRequestInTransaction(
      this.prisma,
      this.lifecycle,
      this.permissions,
      this.scope,
      this.relations,
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
        const provider = await core.findProviderForReview(tx, providerId);
        if (!provider || provider.status !== ProviderStatus.ACTIVE) {
          throw new NotFoundException("Provider not found");
        }
        if (provider.userId === currentUser.id) {
          throw new BadRequestException(
            "Provider owners cannot review their own profile",
          );
        }

        const existing = await core.findExistingProviderReview(tx, currentUser.id, providerId);
        if (existing) {
          throw new ConflictException("You already reviewed this provider");
        }
        // F10: only a customer whose confirmed booking's day has passed reviews.
        if (!(await hasCompletedBookingWith(tx, currentUser.id, providerId, bookingToday()))) {
          throw new ForbiddenException({ statusCode: 403, code: "REVIEW_REQUIRES_COMPLETED_BOOKING", message: "Review after a completed booking" });
        }

        const [review] = await this.relations.attachReviewUsers(tx, [
          await core.createProviderReview(tx, currentUser.id, providerId, dto.rating, MarketplaceQuery.optionalText(dto.comment)),
        ]);
        // B-09: the provider hears of it (p42) and opens it to reply (p27).
        if (provider.userId) {
          await this.notifications.createNotificationInTransaction(
            tx,
            reviewReceivedProviderNotification({
              providerUserId: provider.userId,
              providerId,
              reviewId: review.id,
              rating: review.rating,
              reviewerName: currentUser.name ?? null,
            }),
          );
        }
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
    const existing = await core.findReviewForUser(this.prisma, id, currentUser.id);

    if (!existing) {
      throw new NotFoundException("Review not found");
    }

    return runProviderReviewMutation(
      this.prisma,
      existing.providerId,
      async (tx) => {
        const current = await core.findReviewForUser(tx, id, currentUser.id);
        if (!current) {
          throw new NotFoundException("Review not found");
        }
        // B-09: a reply answers these words; they stay as answered.
        if (current.replyBody !== null) throw reviewHasReply();
        const [review] = await this.relations.attachReviewUsers(tx, [
          await core.updateProviderReview(tx, id, { ...(dto.rating !== undefined ? { rating: dto.rating } : {}), ...(dto.comment !== undefined ? { comment: MarketplaceQuery.optionalText(dto.comment) } : {}) }),
        ]);
        return MarketplacePresenter.toReviewResponse(review);
      },
    );
  }

  async deleteReview(currentUser: AuthenticatedUser, id: string) {
    MarketplaceQuery.assertUuid(id, "reviewId");
    const existing = await core.findReviewForUser(this.prisma, id, currentUser.id);

    if (!existing) {
      throw new NotFoundException("Review not found");
    }

    return runProviderReviewMutation(
      this.prisma,
      existing.providerId,
      async (tx) => {
        const current = await core.findReviewForUser(tx, id, currentUser.id);
        if (!current) {
          throw new NotFoundException("Review not found");
        }
        await core.deleteProviderReview(tx, id);
        return { id, deleted: true };
      },
    );
  }

  private async findActiveProviderOrThrow(
    providerId: string,
  ): Promise<Provider> {
    MarketplaceQuery.assertUuid(providerId, "providerId");
    const provider = await core.findActiveProvider(this.prisma, providerId);

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
    const service = await core.findActiveServiceForProvider(this.prisma, serviceId, providerId);

    if (!service) {
      throw new BadRequestException(
        "serviceId must reference an active provider service",
      );
    }

    return service;
  }

  private async findActiveCityOrThrow(cityId: string): Promise<City> {
    MarketplaceQuery.assertUuid(cityId, "cityId");
    const city = await this.catalog.findActiveCity(this.prisma, cityId);

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
    const quoteSeed = await core.findQuoteRequestSeed(this.prisma, id);
    if (!quoteSeed) {
      throw new NotFoundException("Quote request not found");
    }

    if (quoteSeed.weddingPlanId) {
      const context = await this.permissions.assertPlanReadable(
        quoteSeed.weddingPlanId,
        currentUser,
      );
      assertProviderSectionLive(context, this.permissions);
      // The helper re-checks live access and reads the quote in one snapshot.
      const planId = quoteSeed.weddingPlanId;
      const quote = await runRetryableTransaction(
        this.prisma,
        (tx) =>
          findAccessiblePlanQuoteRequest(
            tx,
            this.quoteScopePorts,
            context,
            currentUser.id,
            quoteSeed.id,
            planId,
          ),
        { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
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

    const quoteRow = await core.findPersonalQuoteRequest(this.prisma, quoteSeed.id, currentUser.id);
    if (!quoteRow) {
      throw new NotFoundException("Quote request not found");
    }
    const quote = await this.relations.attachQuoteRelation(this.prisma, quoteRow);

    return { quote, visibility: FULL_QUOTE_VISIBILITY };
  }

  private async findAccessibleQuoteOfferOrThrow(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<QuoteOffer & { quoteRequest: QuoteRequest }> {
    MarketplaceQuery.assertUuid(id, "quoteOfferId");
    const offer = await core.findQuoteOfferWithRequest(this.prisma, id);
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
        !seesWholePlan(context) &&
        !(await findContributorProviderQuoteIds(
          this.prisma,
          this.scope,
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
