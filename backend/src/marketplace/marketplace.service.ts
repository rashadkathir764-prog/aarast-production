import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
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
  QuoteRequest,
  QuoteRequestStatus,
  ReviewStatus,
  User,
  WeddingPlan,
} from '@prisma/client';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { PrismaService } from '../prisma/prisma.service';
import { PermissionService } from '../sharing/permission.service';
import { CreateProviderReviewDto } from './dto/create-provider-review.dto';
import { CreateQuoteRequestDto } from './dto/create-quote-request.dto';
import { ListProvidersQueryDto } from './dto/list-providers-query.dto';
import { ListServicesQueryDto } from './dto/list-services-query.dto';
import { UpdateProviderReviewDto } from './dto/update-provider-review.dto';

interface Pagination {
  page: number;
  limit: number;
  skip: number;
}

export interface PaginatedResponse<T> {
  items: T[];
  page: number;
  limit: number;
  total: number;
  totalPages: number;
}

type ProviderWithCity = Provider & {
  city: City;
  primaryCategory?: ProviderCategory | null;
};
type ServiceWithDetails = ProviderService & {
  provider: ProviderWithCity;
  category: ProviderCategory;
  city: City | null;
  images: ProviderServiceImage[];
};
type PackageWithService = ProviderPackage & { service?: ProviderService | null };
type ReviewWithUser = ProviderReview & {
  user: Pick<User, 'id' | 'name' | 'phone'>;
};
type FavoriteWithProvider = FavoriteProvider & {
  provider: ProviderWithCity;
};
type QuoteWithRelations = QuoteRequest & {
  provider: ProviderWithCity;
  service?: (ProviderService & { category: ProviderCategory }) | null;
  city?: City | null;
  weddingPlan?: Pick<WeddingPlan, 'id' | 'title' | 'city' | 'weddingDate'> | null;
};

@Injectable()
export class MarketplaceService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly permissions: PermissionService,
  ) {}

  async findCities() {
    const cities = await this.prisma.city.findMany({
      where: { isActive: true },
      orderBy: [{ sortOrder: 'asc' }, { nameAr: 'asc' }],
    });

    return cities.map((city) => this.toCityResponse(city));
  }

  async findCategories() {
    const categories = await this.prisma.providerCategory.findMany({
      where: { isActive: true },
      orderBy: [{ sortOrder: 'asc' }, { nameAr: 'asc' }],
    });

    return categories.map((category) => this.toCategoryResponse(category));
  }

  async findProviders(query: ListProvidersQueryDto) {
    const pagination = this.parsePagination(query.page, query.limit);
    const and: Prisma.ProviderWhereInput[] = [{ status: ProviderStatus.ACTIVE }];
    const where: Prisma.ProviderWhereInput = { AND: and };

    if (query.cityId) {
      this.assertUuid(query.cityId, 'cityId');
      and.push({ cityId: query.cityId });
    }

    if (query.categoryId) {
      this.assertUuid(query.categoryId, 'categoryId');
      and.push({
        OR: [
          { primaryCategoryId: query.categoryId },
          { services: { some: { categoryId: query.categoryId, isActive: true } } },
        ],
      });
    }

    const featured = this.optionalBoolean(query.featured, 'featured');
    if (featured !== null) {
      and.push({ isFeatured: featured });
    }

    const search = this.optionalText(query.search);
    if (search) {
      and.push({
        OR: [
          { businessName: { contains: search, mode: 'insensitive' } },
          { ownerName: { contains: search, mode: 'insensitive' } },
          { description: { contains: search, mode: 'insensitive' } },
          { address: { contains: search, mode: 'insensitive' } },
        ],
      });
    }

    const [total, providers] = await this.prisma.$transaction([
      this.prisma.provider.count({ where }),
      this.prisma.provider.findMany({
        where,
        include: { city: true, primaryCategory: true },
        orderBy: [
          { isFeatured: 'desc' },
          { ratingAverage: 'desc' },
          { createdAt: 'desc' },
        ],
        skip: pagination.skip,
        take: pagination.limit,
      }),
    ]);

    return this.paginate(
      providers.map((provider) => this.toProviderResponse(provider)),
      total,
      pagination,
    );
  }

  async findProvider(id: string) {
    this.assertUuid(id, 'providerId');
    const provider = await this.prisma.provider.findFirst({
      where: { id, status: ProviderStatus.ACTIVE },
      include: {
        city: true,
        primaryCategory: true,
        services: {
          where: { isActive: true },
          include: {
            category: true,
            images: { orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }] },
          },
          orderBy: [{ isFeatured: 'desc' }, { createdAt: 'desc' }],
        },
      },
    });

    if (!provider) {
      throw new NotFoundException('Provider not found');
    }

    return this.toProviderResponse(provider);
  }

  async findProviderServices(providerId: string) {
    await this.findActiveProviderOrThrow(providerId);
    const services = await this.prisma.providerService.findMany({
      where: { providerId, isActive: true },
      include: {
        provider: { include: { city: true, primaryCategory: true } },
        category: true,
        city: true,
        images: { orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }] },
      },
      orderBy: [{ isFeatured: 'desc' }, { createdAt: 'desc' }],
    });

    return services.map((service) => this.toServiceResponse(service));
  }

  async findServices(query: ListServicesQueryDto) {
    const pagination = this.parsePagination(query.page, query.limit);
    const and: Prisma.ProviderServiceWhereInput[] = [
      { provider: { status: ProviderStatus.ACTIVE } },
    ];
    const where: Prisma.ProviderServiceWhereInput = {
      isActive: true,
      AND: and,
    };

    if (query.providerId) {
      this.assertUuid(query.providerId, 'providerId');
      where.providerId = query.providerId;
    }

    if (query.categoryId) {
      this.assertUuid(query.categoryId, 'categoryId');
      where.categoryId = query.categoryId;
    }

    if (query.cityId) {
      this.assertUuid(query.cityId, 'cityId');
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
          { title: { contains: search, mode: 'insensitive' } },
          { description: { contains: search, mode: 'insensitive' } },
          { provider: { businessName: { contains: search, mode: 'insensitive' } } },
        ],
      });
    }

    const minPrice = this.optionalDecimal(query.minPrice, 'minPrice');
    const maxPrice = this.optionalDecimal(query.maxPrice, 'maxPrice');
    if (minPrice !== null || maxPrice !== null) {
      where.basePrice = {
        ...(minPrice !== null ? { gte: minPrice } : {}),
        ...(maxPrice !== null ? { lte: maxPrice } : {}),
      };
    }

    const [total, services] = await this.prisma.$transaction([
      this.prisma.providerService.count({ where }),
      this.prisma.providerService.findMany({
        where,
        include: {
          provider: { include: { city: true, primaryCategory: true } },
          category: true,
          city: true,
          images: { orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }] },
        },
        orderBy: [
          { isFeatured: 'desc' },
          { basePrice: 'asc' },
          { createdAt: 'desc' },
        ],
        skip: pagination.skip,
        take: pagination.limit,
      }),
    ]);

    return this.paginate(
      services.map((service) => this.toServiceResponse(service)),
      total,
      pagination,
    );
  }

  async findService(id: string) {
    this.assertUuid(id, 'serviceId');
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
        images: { orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }] },
      },
    });

    if (!service) {
      throw new NotFoundException('Service not found');
    }

    return this.toServiceResponse(service);
  }

  async findProviderPackages(providerId: string) {
    await this.findActiveProviderOrThrow(providerId);
    const packages = await this.prisma.providerPackage.findMany({
      where: { providerId, isActive: true },
      include: { service: true },
      orderBy: { createdAt: 'desc' },
    });

    return packages.map((providerPackage) =>
      this.toPackageResponse(providerPackage),
    );
  }

  async findProviderReviews(providerId: string) {
    await this.findActiveProviderOrThrow(providerId);
    const reviews = await this.prisma.providerReview.findMany({
      where: { providerId, status: ReviewStatus.PUBLISHED },
      include: { user: { select: { id: true, name: true, phone: true } } },
      orderBy: { createdAt: 'desc' },
    });

    return reviews.map((review) => this.toReviewResponse(review));
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

    return this.toFavoriteResponse(favorite);
  }

  async unfavoriteProvider(currentUser: AuthenticatedUser, providerId: string) {
    this.assertUuid(providerId, 'providerId');
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
      orderBy: { createdAt: 'desc' },
    });

    return favorites.map((favorite) => this.toFavoriteResponse(favorite));
  }

  async createQuoteRequest(
    currentUser: AuthenticatedUser,
    providerId: string,
    dto: CreateQuoteRequestDto,
  ) {
    await this.findActiveProviderOrThrow(providerId);

    if (dto.weddingPlanId) {
      await this.permissions.assertPlanReadable(dto.weddingPlanId, currentUser);
    }

    if (dto.cityId) {
      await this.findActiveCityOrThrow(dto.cityId);
    }

    if (dto.serviceId) {
      await this.findActiveProviderServiceOrThrow(dto.serviceId, providerId);
    }

    const budgetMin = this.optionalDecimal(dto.budgetMin, 'budgetMin');
    const budgetMax = this.optionalDecimal(dto.budgetMax, 'budgetMax');
    if (
      budgetMin !== null &&
      budgetMax !== null &&
      Number(budgetMin) > Number(budgetMax)
    ) {
      throw new BadRequestException('budgetMin must be less than or equal to budgetMax');
    }

    const quote = await this.prisma.quoteRequest.create({
      data: {
        userId: currentUser.id,
        providerId,
        weddingPlanId: dto.weddingPlanId ?? null,
        serviceId: dto.serviceId ?? null,
        eventDate: this.optionalDate(dto.eventDate, 'eventDate'),
        cityId: dto.cityId ?? null,
        guestCount: dto.guestCount ?? null,
        message: this.optionalText(dto.message),
        budgetMin,
        budgetMax,
      },
      include: this.quoteInclude(),
    });

    return this.toQuoteResponse(quote);
  }

  async findMyQuoteRequests(currentUser: AuthenticatedUser) {
    const quotes = await this.prisma.quoteRequest.findMany({
      where: { userId: currentUser.id },
      include: this.quoteInclude(),
      orderBy: { createdAt: 'desc' },
    });

    return quotes.map((quote) => this.toQuoteResponse(quote));
  }

  async findMyQuoteRequest(currentUser: AuthenticatedUser, id: string) {
    this.assertUuid(id, 'quoteRequestId');
    const quote = await this.prisma.quoteRequest.findFirst({
      where: { id, userId: currentUser.id },
      include: this.quoteInclude(),
    });

    if (!quote) {
      throw new NotFoundException('Quote request not found');
    }

    return this.toQuoteResponse(quote);
  }

  async cancelMyQuoteRequest(currentUser: AuthenticatedUser, id: string) {
    this.assertUuid(id, 'quoteRequestId');
    const existing = await this.prisma.quoteRequest.findFirst({
      where: { id, userId: currentUser.id },
    });

    if (!existing) {
      throw new NotFoundException('Quote request not found');
    }

    const quote = await this.prisma.quoteRequest.update({
      where: { id },
      data: { status: QuoteRequestStatus.CANCELLED },
      include: this.quoteInclude(),
    });

    return this.toQuoteResponse(quote);
  }

  async createReview(
    currentUser: AuthenticatedUser,
    providerId: string,
    dto: CreateProviderReviewDto,
  ) {
    const provider = await this.findActiveProviderOrThrow(providerId);
    if (provider.userId === currentUser.id) {
      throw new BadRequestException('Provider owners cannot review their own profile');
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
      throw new ConflictException('You already reviewed this provider');
    }

    const review = await this.prisma.providerReview.create({
      data: {
        userId: currentUser.id,
        providerId,
        rating: dto.rating,
        comment: this.optionalText(dto.comment),
      },
      include: { user: { select: { id: true, name: true, phone: true } } },
    });

    await this.recalculateProviderRating(providerId);
    return this.toReviewResponse(review);
  }

  async updateReview(
    currentUser: AuthenticatedUser,
    id: string,
    dto: UpdateProviderReviewDto,
  ) {
    this.assertUuid(id, 'reviewId');
    const existing = await this.prisma.providerReview.findFirst({
      where: { id, userId: currentUser.id },
    });

    if (!existing) {
      throw new NotFoundException('Review not found');
    }

    const review = await this.prisma.providerReview.update({
      where: { id },
      data: {
        ...(dto.rating !== undefined ? { rating: dto.rating } : {}),
        ...(dto.comment !== undefined ? { comment: this.optionalText(dto.comment) } : {}),
      },
      include: { user: { select: { id: true, name: true, phone: true } } },
    });

    await this.recalculateProviderRating(existing.providerId);
    return this.toReviewResponse(review);
  }

  async deleteReview(currentUser: AuthenticatedUser, id: string) {
    this.assertUuid(id, 'reviewId');
    const existing = await this.prisma.providerReview.findFirst({
      where: { id, userId: currentUser.id },
    });

    if (!existing) {
      throw new NotFoundException('Review not found');
    }

    await this.prisma.providerReview.delete({ where: { id } });
    await this.recalculateProviderRating(existing.providerId);
    return { id, deleted: true };
  }

  private async findActiveProviderOrThrow(
    providerId: string,
  ): Promise<Provider> {
    this.assertUuid(providerId, 'providerId');
    const provider = await this.prisma.provider.findFirst({
      where: { id: providerId, status: ProviderStatus.ACTIVE },
    });

    if (!provider) {
      throw new NotFoundException('Provider not found');
    }

    return provider;
  }

  private async findActiveProviderServiceOrThrow(
    serviceId: string,
    providerId: string,
  ): Promise<ProviderService> {
    this.assertUuid(serviceId, 'serviceId');
    const service = await this.prisma.providerService.findFirst({
      where: {
        id: serviceId,
        providerId,
        isActive: true,
        provider: { status: ProviderStatus.ACTIVE },
      },
    });

    if (!service) {
      throw new BadRequestException('serviceId must reference an active provider service');
    }

    return service;
  }

  private async findActiveCityOrThrow(cityId: string): Promise<City> {
    this.assertUuid(cityId, 'cityId');
    const city = await this.prisma.city.findFirst({
      where: { id: cityId, isActive: true },
    });

    if (!city) {
      throw new BadRequestException('cityId must reference an active city');
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
    const ratingAverage = ratingCount > 0 ? aggregate._avg.rating ?? 0 : 0;

    await this.prisma.provider.update({
      where: { id: providerId },
      data: {
        ratingAverage: ratingAverage.toFixed(2),
        ratingCount,
      },
    });
  }

  private quoteInclude() {
    return {
      provider: { include: { city: true, primaryCategory: true } },
      service: { include: { category: true } },
      city: true,
      weddingPlan: {
        select: { id: true, title: true, city: true, weddingDate: true },
      },
    } satisfies Prisma.QuoteRequestInclude;
  }

  private parsePagination(pageValue?: string, limitValue?: string): Pagination {
    const page = this.parsePositiveInteger(pageValue ?? '1', 'page');
    const limit = Math.min(this.parsePositiveInteger(limitValue ?? '20', 'limit'), 100);
    return { page, limit, skip: (page - 1) * limit };
  }

  private parsePositiveInteger(value: string, field: string): number {
    if (!/^\d+$/.test(value)) {
      throw new BadRequestException(`${field} must be a positive integer`);
    }
    const parsed = Number(value);
    if (!Number.isSafeInteger(parsed) || parsed < 1) {
      throw new BadRequestException(`${field} must be a positive integer`);
    }
    return parsed;
  }

  private optionalBoolean(value: string | undefined, field: string): boolean | null {
    if (value === undefined || value.trim() === '') return null;
    const normalized = value.trim().toLowerCase();
    if (normalized === 'true') return true;
    if (normalized === 'false') return false;
    throw new BadRequestException(`${field} must be true or false`);
  }

  private optionalText(value: string | null | undefined): string | null {
    if (value === undefined || value === null) return null;
    const trimmed = value.trim();
    return trimmed || null;
  }

  private optionalDate(value: string | null | undefined, field: string): Date | null {
    if (value === undefined || value === null) return null;
    const trimmed = value.trim();
    if (!trimmed) return null;
    const timestamp = Date.parse(trimmed);
    if (Number.isNaN(timestamp)) {
      throw new BadRequestException(`${field} must be a valid ISO date string`);
    }
    return new Date(timestamp);
  }

  private optionalDecimal(
    value: string | null | undefined,
    field: string,
  ): string | null {
    if (value === undefined || value === null) return null;
    const normalized = value.trim();
    if (!normalized) return null;
    if (!/^\d+(\.\d+)?$/.test(normalized)) {
      throw new BadRequestException(`${field} must be a valid non-negative decimal value`);
    }
    return normalized;
  }

  private assertUuid(value: string, field: string): void {
    const uuidPattern =
      /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
    if (!uuidPattern.test(value)) {
      throw new BadRequestException(`${field} must be a valid UUID`);
    }
  }

  private paginate<T>(
    items: T[],
    total: number,
    pagination: Pagination,
  ): PaginatedResponse<T> {
    return {
      items,
      page: pagination.page,
      limit: pagination.limit,
      total,
      totalPages: Math.max(Math.ceil(total / pagination.limit), 1),
    };
  }

  private toCityResponse(city: City) {
    return {
      id: city.id,
      nameAr: city.nameAr,
      nameEn: city.nameEn,
      countryCode: city.countryCode,
      isActive: city.isActive,
      sortOrder: city.sortOrder,
    };
  }

  private toCategoryResponse(category: ProviderCategory) {
    return {
      id: category.id,
      nameAr: category.nameAr,
      nameEn: category.nameEn,
      slug: category.slug,
      icon: category.icon,
      isActive: category.isActive,
      sortOrder: category.sortOrder,
    };
  }

  private toProviderResponse(
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
              images: service.images.map((image) => this.toImageResponse(image)),
            })),
          }
        : {}),
    };
  }

  private toServiceResponse(service: ServiceWithDetails) {
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

  private toProviderSummary(provider: ProviderWithCity) {
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

  private toImageResponse(image: ProviderServiceImage) {
    return {
      id: image.id,
      serviceId: image.serviceId,
      imageUrl: image.imageUrl,
      altText: image.altText,
      sortOrder: image.sortOrder,
      createdAt: image.createdAt,
    };
  }

  private toPackageResponse(providerPackage: PackageWithService) {
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

  private toFavoriteResponse(favorite: FavoriteWithProvider) {
    return {
      id: favorite.id,
      userId: favorite.userId,
      providerId: favorite.providerId,
      provider: this.toProviderResponse(favorite.provider),
      createdAt: favorite.createdAt,
    };
  }

  private toReviewResponse(review: ReviewWithUser) {
    return {
      id: review.id,
      userId: review.userId,
      user: review.user,
      providerId: review.providerId,
      rating: review.rating,
      comment: review.comment,
      status: review.status,
      createdAt: review.createdAt,
      updatedAt: review.updatedAt,
    };
  }

  private toQuoteResponse(quote: QuoteWithRelations) {
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
      cityId: quote.cityId,
      city: quote.city ? this.toCityResponse(quote.city) : null,
      guestCount: quote.guestCount,
      message: quote.message,
      budgetMin: quote.budgetMin?.toString() ?? null,
      budgetMax: quote.budgetMax?.toString() ?? null,
      status: quote.status,
      createdAt: quote.createdAt,
      updatedAt: quote.updatedAt,
    };
  }
}
