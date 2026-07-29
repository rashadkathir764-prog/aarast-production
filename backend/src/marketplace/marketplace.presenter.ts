import { BadRequestException } from "@nestjs/common";
import {
  City,
  PlanProviderLinkStatus,
  Provider,
  ProviderCategory,
  ProviderService,
  ProviderServiceImage,
  ProviderStatus,
  Prisma,
  QuoteOffer,
  QuoteOfferStatus,
  QuoteRequestStatus,
} from "@prisma/client";
import { isQuoteOfferExpired } from "./quote-offer-expiry";
import { toReviewIdentity } from "../common/privacy/review-identity";
import { optionalMoneyAmount } from "../common/validation/money";
import { weddingLocationResponse } from "../wedding-plans/wedding-location";
import {
  FavoriteWithProvider,
  FULL_QUOTE_VISIBILITY,
  MarketplacePagination,
  PackageWithService,
  PaginatedResponse,
  ProviderWithCity,
  QuoteVisibility,
  QuoteWithRelations,
  ReviewWithUser,
  ServiceWithDetails,
} from "./marketplace.contracts";
import { ListProvidersQueryDto } from "./dto/list-providers-query.dto";
import { ListServicesQueryDto } from "./dto/list-services-query.dto";
import { quoteLifecycleStatus } from "./quote-lifecycle";

export class MarketplaceQuery {
  private constructor() {}

  static parsePagination(
    pageValue?: string,
    limitValue?: string,
  ): MarketplacePagination {
    const page = this.parsePositiveInteger(pageValue ?? "1", "page");
    const limit = Math.min(
      this.parsePositiveInteger(limitValue ?? "20", "limit"),
      100,
    );
    return { page, limit, skip: (page - 1) * limit };
  }

  static providerSearch(query: ListProvidersQueryDto): {
    pagination: MarketplacePagination;
    where: Prisma.ProviderWhereInput;
  } {
    const pagination = this.parsePagination(query.page, query.limit);
    const and: Prisma.ProviderWhereInput[] = [
      { status: ProviderStatus.ACTIVE },
    ];
    const where: Prisma.ProviderWhereInput = { AND: and };

    if (query.cityId) {
      this.assertUuid(query.cityId, "cityId");
      and.push({ cityId: query.cityId });
    }
    if (query.categoryId) {
      this.assertUuid(query.categoryId, "categoryId");
      and.push({
        OR: [
          { primaryCategoryId: query.categoryId },
          {
            services: {
              some: { categoryId: query.categoryId, isActive: true },
            },
          },
        ],
      });
    }
    const featured = this.optionalBoolean(query.featured, "featured");
    if (featured !== null) and.push({ isFeatured: featured });
    const search = this.optionalText(query.search);
    if (search) {
      and.push({
        OR: [
          { businessName: { contains: search, mode: "insensitive" } },
          { ownerName: { contains: search, mode: "insensitive" } },
          { description: { contains: search, mode: "insensitive" } },
          { address: { contains: search, mode: "insensitive" } },
          {
            services: {
              some: {
                isActive: true,
                OR: [
                  { title: { contains: search, mode: "insensitive" } },
                  { description: { contains: search, mode: "insensitive" } },
                ],
              },
            },
          },
        ],
      });
    }
    return { pagination, where };
  }

  static serviceSearch(query: ListServicesQueryDto): {
    pagination: MarketplacePagination;
    where: Prisma.ProviderServiceWhereInput;
  } {
    const pagination = this.parsePagination(query.page, query.limit);
    const and: Prisma.ProviderServiceWhereInput[] = [
      { provider: { status: ProviderStatus.ACTIVE } },
    ];
    const where: Prisma.ProviderServiceWhereInput = {
      isActive: true,
      AND: and,
    };

    if (query.providerId) {
      this.assertUuid(query.providerId, "providerId");
      where.providerId = query.providerId;
    }
    if (query.categoryId) {
      this.assertUuid(query.categoryId, "categoryId");
      where.categoryId = query.categoryId;
    }
    if (query.cityId) {
      this.assertUuid(query.cityId, "cityId");
      and.push({
        OR: [
          { cityId: query.cityId },
          { cityId: null, provider: { cityId: query.cityId } },
        ],
      });
    }
    const search = this.optionalText(query.search);
    if (search) {
      and.push({
        OR: [
          { title: { contains: search, mode: "insensitive" } },
          { description: { contains: search, mode: "insensitive" } },
          {
            provider: {
              businessName: { contains: search, mode: "insensitive" },
            },
          },
        ],
      });
    }
    const minPrice = this.optionalDecimal(query.minPrice, "minPrice");
    const maxPrice = this.optionalDecimal(query.maxPrice, "maxPrice");
    if (minPrice !== null || maxPrice !== null) {
      where.basePrice = {
        ...(minPrice !== null ? { gte: minPrice } : {}),
        ...(maxPrice !== null ? { lte: maxPrice } : {}),
      };
    }
    return { pagination, where };
  }

  static optionalBoolean(
    value: string | undefined,
    field: string,
  ): boolean | null {
    if (value === undefined || value.trim() === "") return null;
    const normalized = value.trim().toLowerCase();
    if (normalized === "true") return true;
    if (normalized === "false") return false;
    throw new BadRequestException(`${field} must be true or false`);
  }

  static optionalText(value: string | null | undefined): string | null {
    if (value === undefined || value === null) return null;
    const trimmed = value.trim();
    return trimmed || null;
  }

  static optionalDate(
    value: string | null | undefined,
    field: string,
  ): Date | null {
    if (value === undefined || value === null) return null;
    const trimmed = value.trim();
    if (!trimmed) return null;
    const timestamp = Date.parse(trimmed);
    if (Number.isNaN(timestamp)) {
      throw new BadRequestException(`${field} must be a valid ISO date string`);
    }
    return new Date(timestamp);
  }

  static optionalDecimal(
    value: string | null | undefined,
    field: string,
  ): string | null {
    return optionalMoneyAmount(value, field);
  }

  static assertUuid(value: string, field: string): void {
    const uuidPattern =
      /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
    if (!uuidPattern.test(value)) {
      throw new BadRequestException(`${field} must be a valid UUID`);
    }
  }

  static paginate<T>(
    items: T[],
    total: number,
    pagination: MarketplacePagination,
  ): PaginatedResponse<T> {
    return {
      items,
      page: pagination.page,
      limit: pagination.limit,
      total,
      totalPages: Math.max(Math.ceil(total / pagination.limit), 1),
    };
  }

  private static parsePositiveInteger(value: string, field: string): number {
    if (!/^\d+$/.test(value)) {
      throw new BadRequestException(`${field} must be a positive integer`);
    }
    const parsed = Number(value);
    if (!Number.isSafeInteger(parsed) || parsed < 1) {
      throw new BadRequestException(`${field} must be a positive integer`);
    }
    return parsed;
  }
}

export class MarketplacePresenter {
  private constructor() {}

  static toCityResponse(city: City) {
    return {
      id: city.id,
      nameAr: city.nameAr,
      nameEn: city.nameEn,
      countryCode: city.countryCode,
      isActive: city.isActive,
      sortOrder: city.sortOrder,
    };
  }

  static toCategoryResponse(category: ProviderCategory) {
    return {
      id: category.id,
      nameAr: category.nameAr,
      nameEn: category.nameEn,
      slug: category.slug,
      icon: category.icon,
      showForGroom: category.showForGroom,
      showForBride: category.showForBride,
      isActive: category.isActive,
      sortOrder: category.sortOrder,
    };
  }

  static toProviderResponse(
    provider: Provider & {
      city?: City | null;
      primaryCategory?: ProviderCategory | null;
      services?: (ProviderService & {
        category: ProviderCategory;
        images: ProviderServiceImage[];
      })[];
    },
  ) {
    return {
      id: provider.id,
      cityId: provider.cityId,
      city: provider.city ? this.toCityResponse(provider.city) : null,
      primaryCategoryId: provider.primaryCategoryId,
      primaryCategory: provider.primaryCategory
        ? this.toCategoryResponse(provider.primaryCategory)
        : null,
      businessName: provider.businessName,
      ownerName: provider.ownerName,
      phone: provider.phone,
      whatsapp: provider.whatsapp,
      email: provider.email,
      description: provider.description,
      address: provider.address,
      latitude: provider.latitude?.toString() ?? null,
      longitude: provider.longitude?.toString() ?? null,
      logoUrl: provider.logoUrl,
      coverUrl: provider.coverUrl,
      status: provider.status,
      isFeatured: provider.isFeatured,
      ratingAverage: provider.ratingAverage.toString(),
      ratingCount: provider.ratingCount,
      createdAt: provider.createdAt,
      updatedAt: provider.updatedAt,
      ...(provider.services
        ? {
            services: provider.services.map((service) => ({
              id: service.id,
              title: service.title,
              description: service.description,
              basePrice: service.basePrice?.toString() ?? null,
              priceUnit: service.priceUnit,
              currency: service.currency,
              isFeatured: service.isFeatured,
              category: this.toCategoryResponse(service.category),
              images: service.images.map((image) =>
                this.toImageResponse(image),
              ),
            })),
          }
        : {}),
    };
  }

  static toProviderListResponse(
    provider: Provider & {
      city?: City | null;
      primaryCategory?: ProviderCategory | null;
      servicePreviews: (Pick<
        ProviderService,
        "title" | "basePrice" | "currency"
      > & {
        category: ProviderCategory;
      })[];
    },
  ) {
    const prices = provider.servicePreviews
      .map((service) => service.basePrice)
      .filter((price): price is Prisma.Decimal => price !== null);
    const currencies = new Set(
      provider.servicePreviews
        .filter((service) => service.basePrice !== null)
        .map((service) => service.currency),
    );
    const commonCurrency =
      prices.length > 0 && currencies.size === 1
        ? currencies.values().next().value
        : null;
    let minPrice: Prisma.Decimal | null = null;
    let maxPrice: Prisma.Decimal | null = null;
    if (commonCurrency) {
      for (const price of prices) {
        if (minPrice === null || price.lessThan(minPrice)) minPrice = price;
        if (maxPrice === null || price.greaterThan(maxPrice)) maxPrice = price;
      }
    }
    const categories = [
      ...new Map(
        provider.servicePreviews.map((service) => [
          service.category.id,
          service.category,
        ]),
      ).values(),
    ];

    return {
      ...this.toProviderResponse(provider),
      serviceSummary: {
        activeCount: provider.servicePreviews.length,
        titles: [
          ...new Set(
            provider.servicePreviews
              .map((service) => service.title.trim())
              .filter(Boolean),
          ),
        ],
        categories: categories.map((category) =>
          this.toCategoryResponse(category),
        ),
        minPrice: minPrice?.toString() ?? null,
        maxPrice: maxPrice?.toString() ?? null,
        currency: commonCurrency ?? null,
      },
    };
  }

  static toServiceResponse(service: ServiceWithDetails) {
    return {
      id: service.id,
      providerId: service.providerId,
      provider: this.toProviderSummary(service.provider),
      categoryId: service.categoryId,
      category: this.toCategoryResponse(service.category),
      title: service.title,
      description: service.description,
      basePrice: service.basePrice?.toString() ?? null,
      priceUnit: service.priceUnit,
      currency: service.currency,
      cityId: service.cityId,
      city: service.city ? this.toCityResponse(service.city) : null,
      isActive: service.isActive,
      isFeatured: service.isFeatured,
      images: service.images.map((image) => this.toImageResponse(image)),
      createdAt: service.createdAt,
      updatedAt: service.updatedAt,
    };
  }

  static toProviderSummary(provider: ProviderWithCity) {
    return {
      id: provider.id,
      businessName: provider.businessName,
      phone: provider.phone,
      whatsapp: provider.whatsapp,
      logoUrl: provider.logoUrl,
      status: provider.status,
      ratingAverage: provider.ratingAverage.toString(),
      ratingCount: provider.ratingCount,
      city: this.toCityResponse(provider.city),
      primaryCategory: provider.primaryCategory
        ? this.toCategoryResponse(provider.primaryCategory)
        : null,
    };
  }

  static toImageResponse(image: ProviderServiceImage) {
    return {
      id: image.id,
      serviceId: image.serviceId,
      imageUrl: image.imageUrl,
      altText: image.altText,
      sortOrder: image.sortOrder,
      createdAt: image.createdAt,
    };
  }

  static toPackageResponse(providerPackage: PackageWithService) {
    return {
      id: providerPackage.id,
      providerId: providerPackage.providerId,
      serviceId: providerPackage.serviceId,
      service: providerPackage.service
        ? {
            id: providerPackage.service.id,
            title: providerPackage.service.title,
          }
        : null,
      title: providerPackage.title,
      description: providerPackage.description,
      price: providerPackage.price?.toString() ?? null,
      currency: providerPackage.currency,
      items: providerPackage.items,
      isActive: providerPackage.isActive,
      createdAt: providerPackage.createdAt,
      updatedAt: providerPackage.updatedAt,
    };
  }

  static toFavoriteResponse(favorite: FavoriteWithProvider) {
    return {
      id: favorite.id,
      userId: favorite.userId,
      providerId: favorite.providerId,
      provider: this.toProviderResponse(favorite.provider),
      createdAt: favorite.createdAt,
    };
  }

  static toReviewResponse(review: ReviewWithUser) {
    return {
      id: review.id,
      userId: review.userId,
      user: toReviewIdentity(review.user),
      providerId: review.providerId,
      rating: review.rating,
      comment: review.comment,
      status: review.status,
      createdAt: review.createdAt,
      updatedAt: review.updatedAt,
    };
  }

  static toQuoteResponse(
    quote: QuoteWithRelations,
    visibility: QuoteVisibility = FULL_QUOTE_VISIBILITY,
  ) {
    return {
      id: quote.id,
      userId: quote.userId,
      weddingPlanId: quote.weddingPlanId,
      weddingPlan: quote.weddingPlan ?? null,
      providerId: quote.providerId,
      provider: this.toProviderSummary(quote.provider),
      serviceId: quote.serviceId,
      service: quote.service
        ? {
            id: quote.service.id,
            title: quote.service.title,
            category: this.toCategoryResponse(quote.service.category),
          }
        : null,
      eventDate: quote.eventDate,
      location: weddingLocationResponse(quote.location),
      cityId: quote.cityId,
      city: quote.city ? this.toCityResponse(quote.city) : null,
      guestCount: quote.guestCount,
      contactName: quote.contactName,
      contactPhone: visibility.contact ? quote.contactPhone : null,
      contactNormalizedPhone: visibility.contact
        ? quote.contactNormalizedPhone
        : null,
      message: quote.message,
      budgetMin: visibility.budget
        ? (quote.budgetMin?.toString() ?? null)
        : null,
      budgetMax: visibility.budget
        ? (quote.budgetMax?.toString() ?? null)
        : null,
      status: quote.status,
      lifecycleStatus: quoteLifecycleStatus(quote.status),
      offers:
        quote.offers?.map((offer) =>
          this.toQuoteOfferResponse(offer, visibility.budget),
        ) ?? [],
      acceptedPlanProvider:
        quote.providerLinks?.find(
          (link) => link.status === PlanProviderLinkStatus.ACTIVE,
        ) ?? null,
      costSuggestion: this.quoteCostSuggestion(quote, visibility.budget),
      acceptedAt: quote.acceptedAt,
      rejectedAt: quote.rejectedAt,
      cancelledAt: quote.cancelledAt,
      createdAt: quote.createdAt,
      updatedAt: quote.updatedAt,
    };
  }

  static toQuoteOfferResponse(offer: QuoteOffer, showFinancials = true) {
    const isExpired = isQuoteOfferExpired(offer);
    return {
      id: offer.id,
      quoteRequestId: offer.quoteRequestId,
      providerId: offer.providerId,
      title: offer.title,
      message: offer.message,
      amount: showFinancials ? (offer.amount?.toString() ?? null) : null,
      currency: showFinancials ? offer.currency : null,
      validUntil: offer.validUntil,
      status: offer.status,
      isExpired,
      isActionable: offer.status === QuoteOfferStatus.PENDING && !isExpired,
      createdAt: offer.createdAt,
      updatedAt: offer.updatedAt,
    };
  }

  private static quoteCostSuggestion(
    quote: QuoteWithRelations,
    showFinancials = true,
  ) {
    const acceptedOffer = showFinancials
      ? quote.offers?.find(
          (offer) => offer.status === QuoteOfferStatus.ACCEPTED,
        )
      : null;
    const isAccepted = quote.status === QuoteRequestStatus.ACCEPTED;
    const costId = acceptedOffer?.weddingCosts[0]?.id ?? null;
    const hasCost = costId !== null;
    return {
      providerId: quote.providerId,
      providerName: quote.provider.businessName,
      category:
        quote.service?.category.nameAr ??
        quote.provider.primaryCategory?.nameAr ??
        null,
      quotedAmount: acceptedOffer?.amount?.toString() ?? null,
      currency: acceptedOffer?.currency ?? null,
      suggestedAction:
        showFinancials && isAccepted && hasCost ? "VIEW_COST" : "NONE",
      availableActions:
        showFinancials && isAccepted && hasCost ? ["VIEW_COST"] : [],
      quoteOfferId: acceptedOffer?.id ?? null,
      costId,
      automaticCostCreated: hasCost,
    };
  }
}
