import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  City,
  Prisma,
  Provider,
  ProviderCategory,
  ProviderPackage,
  ProviderService,
  ProviderServiceImage,
  ProviderStatus,
  User,
  UserRole,
} from '@prisma/client';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { PrismaService } from '../prisma/prisma.service';
import { AdminCategoryDto, AdminCityDto } from './dto/admin-catalog.dto';
import { AdminProviderQueryDto } from './dto/admin-provider-query.dto';
import { AdminReviewActionDto } from './dto/admin-review-action.dto';

interface Pagination {
  page: number;
  limit: number;
  skip: number;
}

type SafeAdminUser = Pick<
  User,
  | 'id'
  | 'name'
  | 'phone'
  | 'email'
  | 'role'
  | 'status'
  | 'avatarUrl'
  | 'createdAt'
  | 'updatedAt'
>;

type AdminServiceRecord = ProviderService & {
  category: ProviderCategory;
  city: City | null;
  images: ProviderServiceImage[];
};

type AdminPackageRecord = ProviderPackage & {
  service: ProviderService | null;
};

type AdminProviderRecord = Provider & {
  user?: SafeAdminUser | null;
  reviewedBy?: SafeAdminUser | null;
  city?: City | null;
  primaryCategory?: ProviderCategory | null;
  services?: AdminServiceRecord[];
  packages?: AdminPackageRecord[];
  _count?: {
    services: number;
    packages: number;
    quoteRequests: number;
    reviews: number;
  };
};

type AdminUserRecord = SafeAdminUser & {
  providerProfile?: (Provider & {
    city?: City | null;
    primaryCategory?: ProviderCategory | null;
  }) | null;
};

@Injectable()
export class AdminService {
  constructor(private readonly prisma: PrismaService) {}

  async getDashboardStats() {
    const [
      totalUsers,
      totalProviders,
      pendingProviders,
      approvedProviders,
      rejectedProviders,
      needsChangesProviders,
      suspendedProviders,
      totalQuoteRequests,
      totalWeddingPlans,
      totalCities,
      totalProviderCategories,
    ] = await this.prisma.$transaction([
      this.prisma.user.count(),
      this.prisma.provider.count(),
      this.prisma.provider.count({ where: { status: ProviderStatus.PENDING } }),
      this.prisma.provider.count({ where: { status: ProviderStatus.ACTIVE } }),
      this.prisma.provider.count({ where: { status: ProviderStatus.REJECTED } }),
      this.prisma.provider.count({
        where: { status: ProviderStatus.NEEDS_CHANGES },
      }),
      this.prisma.provider.count({
        where: { status: ProviderStatus.SUSPENDED },
      }),
      this.prisma.quoteRequest.count(),
      this.prisma.weddingPlan.count(),
      this.prisma.city.count(),
      this.prisma.providerCategory.count(),
    ]);

    return {
      totalUsers,
      totalProviders,
      pendingProviders,
      approvedProviders,
      rejectedProviders,
      needsChangesProviders,
      suspendedProviders,
      totalQuoteRequests,
      totalWeddingPlans,
      totalCities,
      totalProviderCategories,
    };
  }

  async listProviderApplications(query: AdminProviderQueryDto) {
    return this.listProviders(query);
  }

  async getProviderApplication(id: string) {
    return this.getProvider(id);
  }

  async listProviders(query: AdminProviderQueryDto) {
    const pagination = this.parsePagination(query.page, query.limit);
    const where = this.providerWhere(query);
    const [total, providers] = await this.prisma.$transaction([
      this.prisma.provider.count({ where }),
      this.prisma.provider.findMany({
        where,
        include: this.providerListInclude(),
        orderBy: [{ createdAt: 'desc' }],
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

  async getProvider(id: string) {
    const provider = await this.prisma.provider.findUnique({
      where: { id },
      include: this.providerDetailInclude(),
    });

    if (!provider) {
      throw new NotFoundException('Provider application not found');
    }

    return this.toProviderResponse(provider);
  }

  async approveProvider(currentUser: AuthenticatedUser, id: string) {
    return this.reviewProvider(currentUser, id, ProviderStatus.ACTIVE, null);
  }

  async rejectProvider(
    currentUser: AuthenticatedUser,
    id: string,
    dto: AdminReviewActionDto,
  ) {
    return this.reviewProvider(
      currentUser,
      id,
      ProviderStatus.REJECTED,
      this.optionalText(dto.reason),
    );
  }

  async requestProviderChanges(
    currentUser: AuthenticatedUser,
    id: string,
    dto: AdminReviewActionDto,
  ) {
    const note = this.requiredText(dto.note, 'note');
    return this.reviewProvider(currentUser, id, ProviderStatus.NEEDS_CHANGES, note);
  }

  async suspendProvider(
    currentUser: AuthenticatedUser,
    id: string,
    dto: AdminReviewActionDto,
  ) {
    return this.reviewProvider(
      currentUser,
      id,
      ProviderStatus.SUSPENDED,
      this.optionalText(dto.reason),
    );
  }

  async activateProvider(currentUser: AuthenticatedUser, id: string) {
    return this.reviewProvider(currentUser, id, ProviderStatus.ACTIVE, null);
  }

  async listCategories() {
    const categories = await this.prisma.providerCategory.findMany({
      orderBy: [{ sortOrder: 'asc' }, { nameAr: 'asc' }],
      include: { _count: { select: { providers: true, services: true } } },
    });

    return categories.map((category) => this.toCategoryResponse(category));
  }

  async createCategory(dto: AdminCategoryDto) {
    const category = await this.prisma.providerCategory.create({
      data: {
        nameAr: this.requiredText(dto.nameAr, 'nameAr'),
        nameEn: this.optionalText(dto.nameEn),
        slug: this.toSlug(dto.slug ?? dto.nameEn ?? dto.nameAr),
        icon: this.optionalText(dto.icon),
        isActive: dto.isActive ?? true,
        sortOrder: dto.sortOrder ?? 0,
      },
      include: { _count: { select: { providers: true, services: true } } },
    });

    return this.toCategoryResponse(category);
  }

  async updateCategory(id: string, dto: AdminCategoryDto) {
    await this.findCategoryOrThrow(id);
    const category = await this.prisma.providerCategory.update({
      where: { id },
      data: {
        ...(dto.nameAr !== undefined
          ? { nameAr: this.requiredText(dto.nameAr, 'nameAr') }
          : {}),
        ...(dto.nameEn !== undefined ? { nameEn: this.optionalText(dto.nameEn) } : {}),
        ...(dto.slug !== undefined ? { slug: this.toSlug(dto.slug) } : {}),
        ...(dto.icon !== undefined ? { icon: this.optionalText(dto.icon) } : {}),
        ...(dto.isActive !== undefined ? { isActive: dto.isActive } : {}),
        ...(dto.sortOrder !== undefined ? { sortOrder: dto.sortOrder } : {}),
      },
      include: { _count: { select: { providers: true, services: true } } },
    });

    return this.toCategoryResponse(category);
  }

  async deleteCategory(id: string) {
    await this.findCategoryOrThrow(id);
    const category = await this.prisma.providerCategory.update({
      where: { id },
      data: { isActive: false },
      include: { _count: { select: { providers: true, services: true } } },
    });

    return { ...this.toCategoryResponse(category), deleted: false };
  }

  async listCities() {
    const cities = await this.prisma.city.findMany({
      orderBy: [{ sortOrder: 'asc' }, { nameAr: 'asc' }],
      include: { _count: { select: { providers: true, services: true } } },
    });

    return cities.map((city) => this.toCityResponse(city));
  }

  async createCity(dto: AdminCityDto) {
    const city = await this.prisma.city.create({
      data: {
        nameAr: this.requiredText(dto.nameAr, 'nameAr'),
        nameEn: this.optionalText(dto.nameEn),
        countryCode: this.optionalText(dto.countryCode) ?? 'YE',
        isActive: dto.isActive ?? true,
        sortOrder: dto.sortOrder ?? 0,
      },
      include: { _count: { select: { providers: true, services: true } } },
    });

    return this.toCityResponse(city);
  }

  async updateCity(id: string, dto: AdminCityDto) {
    await this.findCityOrThrow(id);
    const city = await this.prisma.city.update({
      where: { id },
      data: {
        ...(dto.nameAr !== undefined
          ? { nameAr: this.requiredText(dto.nameAr, 'nameAr') }
          : {}),
        ...(dto.nameEn !== undefined ? { nameEn: this.optionalText(dto.nameEn) } : {}),
        ...(dto.countryCode !== undefined
          ? { countryCode: this.optionalText(dto.countryCode) ?? 'YE' }
          : {}),
        ...(dto.isActive !== undefined ? { isActive: dto.isActive } : {}),
        ...(dto.sortOrder !== undefined ? { sortOrder: dto.sortOrder } : {}),
      },
      include: { _count: { select: { providers: true, services: true } } },
    });

    return this.toCityResponse(city);
  }

  async deleteCity(id: string) {
    await this.findCityOrThrow(id);
    const city = await this.prisma.city.update({
      where: { id },
      data: { isActive: false },
      include: { _count: { select: { providers: true, services: true } } },
    });

    return { ...this.toCityResponse(city), deleted: false };
  }

  async listUsers(query: AdminProviderQueryDto) {
    const pagination = this.parsePagination(query.page, query.limit);
    const search = this.optionalText(query.search);
    const where: Prisma.UserWhereInput = search
      ? {
          OR: [
            { name: { contains: search, mode: 'insensitive' } },
            { phone: { contains: search, mode: 'insensitive' } },
            { email: { contains: search, mode: 'insensitive' } },
          ],
        }
      : {};

    const [total, users] = await this.prisma.$transaction([
      this.prisma.user.count({ where }),
      this.prisma.user.findMany({
        where,
        select: this.userSelect(true),
        orderBy: { createdAt: 'desc' },
        skip: pagination.skip,
        take: pagination.limit,
      }),
    ]);

    return this.paginate(
      users.map((user) => this.toUserResponse(user)),
      total,
      pagination,
    );
  }

  async getUser(id: string) {
    const user = await this.prisma.user.findUnique({
      where: { id },
      select: this.userSelect(true),
    });

    if (!user) {
      throw new NotFoundException('User not found');
    }

    return this.toUserResponse(user);
  }

  private async reviewProvider(
    currentUser: AuthenticatedUser,
    id: string,
    status: ProviderStatus,
    reviewNote: string | null,
  ) {
    const existing = await this.prisma.provider.findUnique({ where: { id } });
    if (!existing) {
      throw new NotFoundException('Provider application not found');
    }

    const provider = await this.prisma.$transaction(async (tx) => {
      const updated = await tx.provider.update({
        where: { id },
        data: {
          status,
          reviewNote,
          reviewedAt: new Date(),
          reviewedById: currentUser.id,
        },
        include: this.providerDetailInclude(),
      });

      if (updated.userId && status === ProviderStatus.ACTIVE) {
        await tx.user.update({
          where: { id: updated.userId },
          data: { role: UserRole.PROVIDER },
        });
      }

      return updated;
    });

    return this.toProviderResponse(provider);
  }

  private providerWhere(query: AdminProviderQueryDto): Prisma.ProviderWhereInput {
    const and: Prisma.ProviderWhereInput[] = [];
    const status = this.parseProviderStatus(query.status);
    if (status) {
      and.push({ status });
    }
    if (query.cityId) {
      and.push({ cityId: query.cityId });
    }
    if (query.categoryId) {
      and.push({
        OR: [
          { primaryCategoryId: query.categoryId },
          { services: { some: { categoryId: query.categoryId } } },
        ],
      });
    }
    const search = this.optionalText(query.search);
    if (search) {
      and.push({
        OR: [
          { businessName: { contains: search, mode: 'insensitive' } },
          { ownerName: { contains: search, mode: 'insensitive' } },
          { phone: { contains: search, mode: 'insensitive' } },
          { email: { contains: search, mode: 'insensitive' } },
          { user: { name: { contains: search, mode: 'insensitive' } } },
          { user: { phone: { contains: search, mode: 'insensitive' } } },
        ],
      });
    }
    return and.length ? { AND: and } : {};
  }

  private providerListInclude() {
    return {
      user: { select: this.userSelect(false) },
      reviewedBy: { select: this.userSelect(false) },
      city: true,
      primaryCategory: true,
      _count: {
        select: {
          services: true,
          packages: true,
          quoteRequests: true,
          reviews: true,
        },
      },
    } satisfies Prisma.ProviderInclude;
  }

  private providerDetailInclude() {
    return {
      ...this.providerListInclude(),
      services: {
        include: {
          category: true,
          city: true,
          images: { orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }] },
        },
        orderBy: { createdAt: 'desc' },
      },
      packages: {
        include: { service: true },
        orderBy: { createdAt: 'desc' },
      },
    } satisfies Prisma.ProviderInclude;
  }

  private userSelect(withProvider: boolean) {
    return {
      id: true,
      name: true,
      phone: true,
      email: true,
      role: true,
      status: true,
      avatarUrl: true,
      createdAt: true,
      updatedAt: true,
      ...(withProvider
        ? {
            providerProfile: {
              include: {
                city: true,
                primaryCategory: true,
              },
            },
          }
        : {}),
    } satisfies Prisma.UserSelect;
  }

  private async findCategoryOrThrow(id: string) {
    const category = await this.prisma.providerCategory.findUnique({
      where: { id },
    });
    if (!category) throw new NotFoundException('Provider category not found');
    return category;
  }

  private async findCityOrThrow(id: string) {
    const city = await this.prisma.city.findUnique({ where: { id } });
    if (!city) throw new NotFoundException('City not found');
    return city;
  }

  private parseProviderStatus(value?: string): ProviderStatus | null {
    const normalized = value?.trim().toUpperCase();
    if (!normalized) return null;
    if (normalized === 'PENDING_REVIEW') return ProviderStatus.PENDING;
    if (normalized === 'APPROVED') return ProviderStatus.ACTIVE;
    if (normalized in ProviderStatus) {
      return ProviderStatus[normalized as keyof typeof ProviderStatus];
    }
    throw new BadRequestException('status is not supported');
  }

  private parsePagination(pageValue?: string, limitValue?: string): Pagination {
    const page = this.parsePositiveInteger(pageValue ?? '1', 'page');
    const limit = Math.min(
      this.parsePositiveInteger(limitValue ?? '20', 'limit'),
      100,
    );
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

  private paginate<T>(items: T[], total: number, pagination: Pagination) {
    return {
      items,
      page: pagination.page,
      limit: pagination.limit,
      total,
      totalPages: Math.max(Math.ceil(total / pagination.limit), 1),
    };
  }

  private requiredText(value: string | null | undefined, field: string): string {
    const trimmed = value?.trim() ?? '';
    if (!trimmed) throw new BadRequestException(`${field} must not be empty`);
    return trimmed;
  }

  private optionalText(value: string | null | undefined): string | null {
    if (value === undefined || value === null) return null;
    const trimmed = value.trim();
    return trimmed || null;
  }

  private toSlug(value: string | null | undefined): string {
    const slug = this.requiredText(value, 'slug')
      .trim()
      .toLowerCase()
      .replace(/\s+/g, '-')
      .replace(/[^\p{L}\p{N}-]+/gu, '')
      .replace(/-+/g, '-')
      .replace(/^-|-$/g, '');

    if (!slug) throw new BadRequestException('slug must not be empty');
    return slug;
  }

  private toCityResponse(
    city: City & { _count?: { providers: number; services: number } },
  ) {
    return {
      id: city.id,
      nameAr: city.nameAr,
      nameEn: city.nameEn,
      countryCode: city.countryCode,
      isActive: city.isActive,
      sortOrder: city.sortOrder,
      createdAt: city.createdAt,
      updatedAt: city.updatedAt,
      providersCount: city._count?.providers ?? 0,
      servicesCount: city._count?.services ?? 0,
    };
  }

  private toCategoryResponse(
    category: ProviderCategory & {
      _count?: { providers: number; services: number };
    },
  ) {
    return {
      id: category.id,
      nameAr: category.nameAr,
      nameEn: category.nameEn,
      slug: category.slug,
      icon: category.icon,
      isActive: category.isActive,
      sortOrder: category.sortOrder,
      createdAt: category.createdAt,
      updatedAt: category.updatedAt,
      providersCount: category._count?.providers ?? 0,
      servicesCount: category._count?.services ?? 0,
    };
  }

  private toProviderResponse(provider: AdminProviderRecord) {
    return {
      id: provider.id,
      userId: provider.userId,
      user: provider.user ? this.toSafeUser(provider.user) : null,
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
      logoUrl: provider.logoUrl,
      coverUrl: provider.coverUrl,
      status: provider.status,
      reviewNote: provider.reviewNote,
      reviewedAt: provider.reviewedAt,
      reviewedBy: provider.reviewedBy
        ? this.toSafeUser(provider.reviewedBy)
        : null,
      isFeatured: provider.isFeatured,
      ratingAverage: provider.ratingAverage.toString(),
      ratingCount: provider.ratingCount,
      servicesCount: provider._count?.services ?? provider.services?.length ?? 0,
      packagesCount: provider._count?.packages ?? provider.packages?.length ?? 0,
      quoteRequestsCount: provider._count?.quoteRequests ?? 0,
      reviewsCount: provider._count?.reviews ?? 0,
      services: provider.services?.map((service) => ({
        id: service.id,
        title: service.title,
        description: service.description,
        category: this.toCategoryResponse(service.category),
        city: service.city ? this.toCityResponse(service.city) : null,
        basePrice: service.basePrice?.toString() ?? null,
        priceUnit: service.priceUnit,
        currency: service.currency,
        isActive: service.isActive,
        isFeatured: service.isFeatured,
        images: service.images.map((image) => ({
          id: image.id,
          imageUrl: image.imageUrl,
          altText: image.altText,
          sortOrder: image.sortOrder,
          createdAt: image.createdAt,
        })),
        createdAt: service.createdAt,
        updatedAt: service.updatedAt,
      })),
      packages: provider.packages?.map((providerPackage) => ({
        id: providerPackage.id,
        title: providerPackage.title,
        description: providerPackage.description,
        price: providerPackage.price?.toString() ?? null,
        currency: providerPackage.currency,
        items: providerPackage.items,
        isActive: providerPackage.isActive,
        service: providerPackage.service
          ? { id: providerPackage.service.id, title: providerPackage.service.title }
          : null,
        createdAt: providerPackage.createdAt,
        updatedAt: providerPackage.updatedAt,
      })),
      createdAt: provider.createdAt,
      updatedAt: provider.updatedAt,
    };
  }

  private toUserResponse(user: AdminUserRecord) {
    return {
      ...this.toSafeUser(user),
      provider: user.providerProfile
        ? {
            id: user.providerProfile.id,
            businessName: user.providerProfile.businessName,
            status: user.providerProfile.status,
            city: user.providerProfile.city
              ? this.toCityResponse(user.providerProfile.city)
              : null,
            primaryCategory: user.providerProfile.primaryCategory
              ? this.toCategoryResponse(user.providerProfile.primaryCategory)
              : null,
          }
        : null,
    };
  }

  private toSafeUser(user: SafeAdminUser) {
    return {
      id: user.id,
      name: user.name,
      phone: user.phone,
      email: user.email,
      role: user.role,
      status: user.status,
      avatarUrl: user.avatarUrl,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    };
  }
}
