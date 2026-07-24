import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  AdminRole,
  AppRole,
  ConversationReportStatus,
  NotificationPriority,
  NotificationType,
  Prisma,
  ProviderStatus,
  QuoteRequestStatus,
  ReviewStatus,
  UserRole,
  UserStatus,
} from '@prisma/client';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { runSerializableTransaction } from '../common/prisma/serializable-transaction';
import { requiredMoneyAmount } from '../common/validation/money';
import { PrismaService } from '../prisma/prisma.service';
import { ConversationRealtimePublisher } from '../conversations/conversation-realtime.publisher';
import { AdminCategoryDto, AdminCityDto } from './dto/admin-catalog.dto';
import { AdminNotificationQueryDto } from './dto/admin-notification.dto';
import {
  toAdminNotificationResponse,
  toAdminQuoteReport,
  toAdminReportsOverviewResponse,
  toAdminReviewResponse,
  toAdminReviewReport,
  toAdminServiceResponse,
  toAdminUserReport,
  toCategoryResponse,
  toCityResponse,
  toProviderResponse,
  toUserResponse,
} from './admin.presenter';
import { AdminProviderQueryDto } from './dto/admin-provider-query.dto';
import { AdminReportQueryDto } from './dto/admin-report.dto';
import { AdminReviewQueryDto, AdminReviewStatusDto } from './dto/admin-review.dto';
import { AdminReviewActionDto } from './dto/admin-review-action.dto';
import { AdminServiceDto, AdminServiceQueryDto } from './dto/admin-service.dto';
import { AdminConversationReportQueryDto, AdminConversationReportStatusDto } from './dto/admin-conversation-report.dto';
import { authorizeAdminUserStatusChange } from './admin-user-status';

interface Pagination {
  page: number;
  limit: number;
  skip: number;
}

@Injectable()
export class AdminService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly realtime: ConversationRealtimePublisher,
  ) {}

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
      this.prisma.provider.count({
        where: { status: ProviderStatus.REJECTED },
      }),
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
      providers.map((provider) => toProviderResponse(provider)),
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

    return toProviderResponse(provider);
  }

  async listServices(query: AdminServiceQueryDto) {
    const pagination = this.parsePagination(query.page, query.limit);
    const where = this.serviceWhere(query);
    const [total, services] = await this.prisma.$transaction([
      this.prisma.providerService.count({ where }),
      this.prisma.providerService.findMany({
        where,
        include: this.adminServiceInclude(),
        orderBy: [{ isFeatured: 'desc' }, { createdAt: 'desc' }],
        skip: pagination.skip,
        take: pagination.limit,
      }),
    ]);

    return this.paginate(
      services.map((service) => toAdminServiceResponse(service)),
      total,
      pagination,
    );
  }

  async createService(dto: AdminServiceDto) {
    const providerId = this.requiredText(dto.providerId, 'providerId');
    const categoryId = this.requiredText(dto.categoryId, 'categoryId');
    await this.findProviderOrThrow(providerId);
    await this.findCategoryOrThrow(categoryId);
    if (dto.cityId) await this.findCityOrThrow(dto.cityId);

    const service = await this.prisma.providerService.create({
      data: {
        providerId,
        categoryId,
        title: this.requiredText(dto.title, 'title'),
        description: this.optionalText(dto.description),
        basePrice: this.optionalDecimal(dto.basePrice, 'basePrice'),
        priceUnit: this.optionalText(dto.priceUnit),
        currency: this.optionalText(dto.currency) ?? 'YER',
        cityId: this.optionalText(dto.cityId),
        isActive: dto.isActive ?? true,
        isFeatured: dto.isFeatured ?? false,
      },
      include: this.adminServiceInclude(),
    });

    return toAdminServiceResponse(service);
  }

  async updateService(id: string, dto: AdminServiceDto) {
    const existing = await this.findServiceOrThrow(id);
    if (dto.providerId !== undefined) {
      const providerId = this.requiredText(dto.providerId, 'providerId');
      if (providerId !== existing.providerId) {
        throw new BadRequestException('providerId cannot be changed after a service is created');
      }
    }
    if (dto.categoryId !== undefined) {
      await this.findCategoryOrThrow(this.requiredText(dto.categoryId, 'categoryId'));
    }
    if (dto.cityId) await this.findCityOrThrow(dto.cityId);

    const service = await this.prisma.providerService.update({
      where: { id },
      data: {
        ...(dto.categoryId !== undefined ? { categoryId: this.requiredText(dto.categoryId, 'categoryId') } : {}),
        ...(dto.title !== undefined ? { title: this.requiredText(dto.title, 'title') } : {}),
        ...(dto.description !== undefined ? { description: this.optionalText(dto.description) } : {}),
        ...(dto.basePrice !== undefined ? { basePrice: this.optionalDecimal(dto.basePrice, 'basePrice') } : {}),
        ...(dto.priceUnit !== undefined ? { priceUnit: this.optionalText(dto.priceUnit) } : {}),
        ...(dto.currency !== undefined ? { currency: this.requiredText(dto.currency, 'currency') } : {}),
        ...(dto.cityId !== undefined ? { cityId: this.optionalText(dto.cityId) } : {}),
        ...(dto.isActive !== undefined ? { isActive: dto.isActive } : {}),
        ...(dto.isFeatured !== undefined ? { isFeatured: dto.isFeatured } : {}),
      },
      include: this.adminServiceInclude(),
    });

    return toAdminServiceResponse(service);
  }

  async deleteService(id: string) {
    await this.findServiceOrThrow(id);
    const service = await this.prisma.providerService.update({
      where: { id },
      data: { isActive: false, isFeatured: false },
      include: this.adminServiceInclude(),
    });

    return { ...toAdminServiceResponse(service), deleted: false };
  }

  async listReviews(query: AdminReviewQueryDto) {
    const pagination = this.parsePagination(query.page, query.limit);
    const where = this.reviewWhere(query);
    const [total, reviews] = await this.prisma.$transaction([
      this.prisma.providerReview.count({ where }),
      this.prisma.providerReview.findMany({
        where,
        include: this.adminReviewInclude(),
        orderBy: { createdAt: 'desc' },
        skip: pagination.skip,
        take: pagination.limit,
      }),
    ]);

    return this.paginate(
      reviews.map((review) => toAdminReviewResponse(review)),
      total,
      pagination,
    );
  }

  async updateReviewStatus(id: string, dto: AdminReviewStatusDto) {
    const existing = await this.findReviewOrThrow(id);
    const status = this.parseReviewStatus(dto.status);
    const review = await this.prisma.providerReview.update({
      where: { id },
      data: { status },
      include: this.adminReviewInclude(),
    });
    await this.recalculateProviderRating(existing.providerId);
    return toAdminReviewResponse(review);
  }

  async hideReview(id: string) {
    const existing = await this.findReviewOrThrow(id);
    const review = await this.prisma.providerReview.update({
      where: { id },
      data: { status: ReviewStatus.HIDDEN },
      include: this.adminReviewInclude(),
    });
    await this.recalculateProviderRating(existing.providerId);
    return { ...toAdminReviewResponse(review), deleted: false };
  }

  async listConversationReports(query: AdminConversationReportQueryDto) {
    const pagination = this.parsePagination(query.page, query.limit);
    const where: Prisma.ConversationReportWhereInput = query.status
      ? { status: this.parseConversationReportStatus(query.status) }
      : {};
    const [total, reports] = await this.prisma.$transaction([
      this.prisma.conversationReport.count({ where }),
      this.prisma.conversationReport.findMany({
        where,
        select: {
          id: true,
          conversationId: true,
          reason: true,
          status: true,
          createdAt: true,
          updatedAt: true,
          reporter: {
            select: { id: true, name: true, phone: true, avatarUrl: true },
          },
          conversation: {
            select: {
              provider: { select: { id: true, businessName: true } },
              quoteRequests: {
                orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
                take: 1,
                select: { id: true },
              },
            },
          },
        },
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        skip: pagination.skip,
        take: pagination.limit,
      }),
    ]);
    return this.paginate(reports, total, pagination);
  }

  async updateConversationReportStatus(id: string, dto: AdminConversationReportStatusDto) {
    const existing = await this.prisma.conversationReport.findUnique({
      where: { id },
      select: { id: true },
    });
    if (!existing) throw new NotFoundException('Conversation report not found');
    return this.prisma.conversationReport.update({
      where: { id },
      data: { status: this.parseConversationReportStatus(dto.status) },
      select: {
        id: true,
        conversationId: true,
        reason: true,
        status: true,
        createdAt: true,
        updatedAt: true,
      },
    });
  }

  async listNotifications(query: AdminNotificationQueryDto) {
    const pagination = this.parsePagination(query.page, query.limit);
    const where = this.notificationWhere(query);
    const [total, notifications] = await this.prisma.$transaction([
      this.prisma.notification.count({ where }),
      this.prisma.notification.findMany({
        where,
        include: this.adminNotificationInclude(),
        orderBy: { createdAt: 'desc' },
        skip: pagination.skip,
        take: pagination.limit,
      }),
    ]);

    return this.paginate(
      notifications.map((notification) => toAdminNotificationResponse(notification)),
      total,
      pagination,
    );
  }

  async getUnreadNotificationsCount() {
    const count = await this.prisma.notification.count({
      where: { readAt: null, archivedAt: null },
    });
    return { count };
  }

  async markNotificationRead(id: string) {
    await this.findNotificationOrThrow(id);
    const notification = await this.prisma.notification.update({
      where: { id },
      data: { readAt: new Date() },
      include: this.adminNotificationInclude(),
    });
    return toAdminNotificationResponse(notification);
  }

  async archiveNotification(id: string) {
    const existing = await this.findNotificationOrThrow(id);
    const now = new Date();
    const notification = await this.prisma.notification.update({
      where: { id },
      data: {
        archivedAt: now,
        readAt: existing.readAt ?? now,
      },
      include: this.adminNotificationInclude(),
    });
    return toAdminNotificationResponse(notification);
  }

  async deleteNotification(id: string) {
    await this.findNotificationOrThrow(id);
    await this.prisma.notification.delete({ where: { id } });
    return { id, deleted: true };
  }

  async getReportsOverview(query: AdminReportQueryDto) {
    const range = this.parseDateRange(query.from, query.to);
    const createdAt = range.where;
    const [users, providers, services, reviews, quotes, notifications, weddingPlans, cities, categories] =
      await Promise.all([
        this.getUserReport(createdAt),
        this.getProviderReport(createdAt),
        this.getServiceReport(createdAt),
        this.getReviewReport(createdAt),
        this.getQuoteReport(createdAt),
        this.getNotificationReport(createdAt),
        this.prisma.weddingPlan.count({ where: { createdAt } }),
        this.prisma.city.count(),
        this.prisma.providerCategory.count(),
      ]);

    return toAdminReportsOverviewResponse({
      generatedAt: new Date(),
      from: range.from,
      to: range.to,
      users,
      providers,
      services,
      reviews,
      quotes,
      notifications,
      cities,
      categories,
      weddingPlans,
    });
  }

  async approveProvider(currentUser: AuthenticatedUser, id: string) {
    return this.reviewProvider(currentUser, id, ProviderStatus.ACTIVE, null);
  }

  async rejectProvider(currentUser: AuthenticatedUser, id: string, dto: AdminReviewActionDto) {
    return this.reviewProvider(currentUser, id, ProviderStatus.REJECTED, this.optionalText(dto.reason));
  }

  async requestProviderChanges(currentUser: AuthenticatedUser, id: string, dto: AdminReviewActionDto) {
    const note = this.requiredText(dto.note, 'note');
    return this.reviewProvider(currentUser, id, ProviderStatus.NEEDS_CHANGES, note);
  }

  async suspendProvider(currentUser: AuthenticatedUser, id: string, dto: AdminReviewActionDto) {
    return this.reviewProvider(currentUser, id, ProviderStatus.SUSPENDED, this.optionalText(dto.reason));
  }

  async activateProvider(currentUser: AuthenticatedUser, id: string) {
    return this.reviewProvider(currentUser, id, ProviderStatus.ACTIVE, null);
  }

  async listCategories() {
    const categories = await this.prisma.providerCategory.findMany({
      orderBy: [{ sortOrder: 'asc' }, { nameAr: 'asc' }],
      include: { _count: { select: { providers: true, services: true } } },
    });

    return categories.map((category) => toCategoryResponse(category));
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

    return toCategoryResponse(category);
  }

  async updateCategory(id: string, dto: AdminCategoryDto) {
    await this.findCategoryOrThrow(id);
    const category = await this.prisma.providerCategory.update({
      where: { id },
      data: {
        ...(dto.nameAr !== undefined ? { nameAr: this.requiredText(dto.nameAr, 'nameAr') } : {}),
        ...(dto.nameEn !== undefined ? { nameEn: this.optionalText(dto.nameEn) } : {}),
        ...(dto.slug !== undefined ? { slug: this.toSlug(dto.slug) } : {}),
        ...(dto.icon !== undefined ? { icon: this.optionalText(dto.icon) } : {}),
        ...(dto.isActive !== undefined ? { isActive: dto.isActive } : {}),
        ...(dto.sortOrder !== undefined ? { sortOrder: dto.sortOrder } : {}),
      },
      include: { _count: { select: { providers: true, services: true } } },
    });

    return toCategoryResponse(category);
  }

  async deleteCategory(id: string) {
    await this.findCategoryOrThrow(id);
    const category = await this.prisma.providerCategory.update({
      where: { id },
      data: { isActive: false },
      include: { _count: { select: { providers: true, services: true } } },
    });

    return { ...toCategoryResponse(category), deleted: false };
  }

  async listCities() {
    const cities = await this.prisma.city.findMany({
      orderBy: [{ sortOrder: 'asc' }, { nameAr: 'asc' }],
      include: { _count: { select: { providers: true, services: true } } },
    });

    return cities.map((city) => toCityResponse(city));
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

    return toCityResponse(city);
  }

  async updateCity(id: string, dto: AdminCityDto) {
    await this.findCityOrThrow(id);
    const city = await this.prisma.city.update({
      where: { id },
      data: {
        ...(dto.nameAr !== undefined ? { nameAr: this.requiredText(dto.nameAr, 'nameAr') } : {}),
        ...(dto.nameEn !== undefined ? { nameEn: this.optionalText(dto.nameEn) } : {}),
        ...(dto.countryCode !== undefined ? { countryCode: this.optionalText(dto.countryCode) ?? 'YE' } : {}),
        ...(dto.isActive !== undefined ? { isActive: dto.isActive } : {}),
        ...(dto.sortOrder !== undefined ? { sortOrder: dto.sortOrder } : {}),
      },
      include: { _count: { select: { providers: true, services: true } } },
    });

    return toCityResponse(city);
  }

  async deleteCity(id: string) {
    await this.findCityOrThrow(id);
    const city = await this.prisma.city.update({
      where: { id },
      data: { isActive: false },
      include: { _count: { select: { providers: true, services: true } } },
    });

    return { ...toCityResponse(city), deleted: false };
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
      users.map((user) => toUserResponse(user)),
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

    return toUserResponse(user);
  }

  async activateUser(currentUser: AuthenticatedUser, id: string) {
    const user = await runSerializableTransaction(this.prisma, async (tx) => {
      const target = await authorizeAdminUserStatusChange(
        tx,
        currentUser,
        id,
      );
      return tx.user.update({
        where: { id: target.id },
        data: { status: UserStatus.ACTIVE },
        select: this.userSelect(true),
      });
    });
    return toUserResponse(user);
  }

  async disableUser(currentUser: AuthenticatedUser, id: string) {
    if (currentUser.id === id) {
      throw new BadRequestException('Admins cannot disable their own account');
    }
    const now = new Date();
    const user = await runSerializableTransaction(this.prisma, async (tx) => {
      const target = await authorizeAdminUserStatusChange(
        tx,
        currentUser,
        id,
      );
      if (
        target.role === UserRole.ADMIN &&
        target.adminRole === AdminRole.SUPER_ADMIN &&
        target.status === UserStatus.ACTIVE
      ) {
        const activeSuperAdmins = await tx.user.count({
          where: {
            role: UserRole.ADMIN,
            adminRole: AdminRole.SUPER_ADMIN,
            status: UserStatus.ACTIVE,
          },
        });
        if (activeSuperAdmins <= 1) {
          throw new ConflictException(
            'The last active super administrator cannot be disabled',
          );
        }
      }

      const updated = await tx.user.update({
        where: { id: target.id },
        data: { status: UserStatus.DISABLED },
        select: this.userSelect(true),
      });
      await tx.refreshToken.updateMany({
        where: { userId: target.id, revokedAt: null },
        data: { revokedAt: now },
      });
      return updated;
    });
    // Sessions were just revoked; sever any live realtime channel the now
    // disabled account still holds open.
    this.realtime.disconnectUser(id);
    return toUserResponse(user);
  }

  private async reviewProvider(
    currentUser: AuthenticatedUser,
    id: string,
    status: ProviderStatus,
    reviewNote: string | null,
  ) {
    const provider = await this.prisma.$transaction(async (tx) => {
      const existing = await tx.provider.findUnique({ where: { id }, select: { userId: true } });
      if (!existing) {
        throw new NotFoundException('Provider application not found');
      }
      if (existing.userId === currentUser.id) {
        throw new BadRequestException('Provider owners cannot review their own application');
      }

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
        let promoted = await tx.user.updateMany({
          where: {
            id: updated.userId,
            role: { in: [UserRole.USER, UserRole.PROVIDER] },
          },
          data: {
            role: UserRole.PROVIDER,
            appRole: AppRole.PROVIDER,
          },
        });
        if (promoted.count === 0) {
          promoted = await tx.user.updateMany({
            where: {
              id: updated.userId,
              role: UserRole.ADMIN,
              appPasswordHash: { not: null },
            },
            data: { appRole: AppRole.PROVIDER },
          });
        }
        if (promoted.count !== 1) {
          throw new BadRequestException(
            'The application identity is not eligible for provider approval',
          );
        }
      }

      return updated;
    });

    return toProviderResponse(provider);
  }

  private serviceWhere(query: AdminServiceQueryDto): Prisma.ProviderServiceWhereInput {
    const and: Prisma.ProviderServiceWhereInput[] = [];
    const status = query.status?.trim().toUpperCase();
    if (status === 'ACTIVE') and.push({ isActive: true });
    if (status === 'DISABLED' || status === 'INACTIVE') {
      and.push({ isActive: false });
    }
    if (status === 'FEATURED') and.push({ isFeatured: true });
    if (status && !['ACTIVE', 'DISABLED', 'INACTIVE', 'FEATURED'].includes(status)) {
      throw new BadRequestException('service status is not supported');
    }
    if (query.providerId) and.push({ providerId: query.providerId });
    if (query.categoryId) and.push({ categoryId: query.categoryId });
    if (query.cityId) {
      and.push({
        OR: [{ cityId: query.cityId }, { cityId: null, provider: { cityId: query.cityId } }],
      });
    }
    const search = this.optionalText(query.search);
    if (search) {
      and.push({
        OR: [
          { title: { contains: search, mode: 'insensitive' } },
          { description: { contains: search, mode: 'insensitive' } },
          {
            provider: {
              businessName: { contains: search, mode: 'insensitive' },
            },
          },
          { provider: { phone: { contains: search, mode: 'insensitive' } } },
        ],
      });
    }
    return and.length ? { AND: and } : {};
  }

  private reviewWhere(query: AdminReviewQueryDto): Prisma.ProviderReviewWhereInput {
    const and: Prisma.ProviderReviewWhereInput[] = [];
    if (query.status) and.push({ status: this.parseReviewStatus(query.status) });
    if (query.providerId) and.push({ providerId: query.providerId });
    const search = this.optionalText(query.search);
    if (search) {
      and.push({
        OR: [
          { comment: { contains: search, mode: 'insensitive' } },
          { user: { name: { contains: search, mode: 'insensitive' } } },
          {
            provider: {
              businessName: { contains: search, mode: 'insensitive' },
            },
          },
        ],
      });
    }
    return and.length ? { AND: and } : {};
  }

  private notificationWhere(query: AdminNotificationQueryDto): Prisma.NotificationWhereInput {
    const and: Prisma.NotificationWhereInput[] = [];
    if (query.type) and.push({ type: this.parseNotificationType(query.type) });
    if (query.priority) {
      and.push({ priority: this.parseNotificationPriority(query.priority) });
    }
    if (this.optionalBoolean(query.unreadOnly, 'unreadOnly') === true) {
      and.push({ readAt: null });
    }
    const search = this.optionalText(query.search);
    if (search) {
      and.push({
        OR: [
          { title: { contains: search, mode: 'insensitive' } },
          { entityType: { contains: search, mode: 'insensitive' } },
          { user: { name: { contains: search, mode: 'insensitive' } } },
        ],
      });
    }
    return and.length ? { AND: and } : {};
  }

  private adminServiceInclude() {
    return {
      provider: { include: { city: true, primaryCategory: true } },
      category: true,
      city: true,
      images: { orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }] },
    } satisfies Prisma.ProviderServiceInclude;
  }

  private adminReviewInclude() {
    return {
      user: {
        select: { id: true, name: true, appName: true, role: true },
      },
      provider: { include: { city: true, primaryCategory: true } },
    } satisfies Prisma.ProviderReviewInclude;
  }

  private adminNotificationInclude() {
    return {
      user: { select: { id: true, name: true, phone: true } },
      weddingPlan: { select: { id: true, title: true, city: true } },
    } satisfies Prisma.NotificationInclude;
  }

  private async findProviderOrThrow(id: string) {
    const provider = await this.prisma.provider.findUnique({ where: { id } });
    if (!provider) throw new NotFoundException('Provider not found');
    return provider;
  }

  private async findServiceOrThrow(id: string) {
    const service = await this.prisma.providerService.findUnique({
      where: { id },
    });
    if (!service) throw new NotFoundException('Provider service not found');
    return service;
  }

  private async findReviewOrThrow(id: string) {
    const review = await this.prisma.providerReview.findUnique({
      where: { id },
    });
    if (!review) throw new NotFoundException('Review not found');
    return review;
  }

  private async findNotificationOrThrow(id: string) {
    const notification = await this.prisma.notification.findUnique({
      where: { id },
    });
    if (!notification) throw new NotFoundException('Notification not found');
    return notification;
  }

  private async findUserOrThrow(id: string) {
    const user = await this.prisma.user.findUnique({ where: { id } });
    if (!user) throw new NotFoundException('User not found');
    return user;
  }

  private async recalculateProviderRating(providerId: string) {
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

  private async getUserReport(createdAt?: Prisma.DateTimeFilter) {
    const [total, active, disabled, admins, providers] = await Promise.all([
      this.prisma.user.count({ where: { createdAt } }),
      this.prisma.user.count({
        where: { createdAt, status: UserStatus.ACTIVE },
      }),
      this.prisma.user.count({
        where: { createdAt, status: UserStatus.DISABLED },
      }),
      this.prisma.user.count({ where: { createdAt, role: UserRole.ADMIN } }),
      this.prisma.user.count({ where: { createdAt, role: UserRole.PROVIDER } }),
    ]);
    return toAdminUserReport({ total, active, disabled, admins, providers });
  }

  private async getProviderReport(createdAt?: Prisma.DateTimeFilter) {
    const [total, pending, active, needsChanges, suspended, rejected, featured] = await Promise.all([
      this.prisma.provider.count({ where: { createdAt } }),
      this.prisma.provider.count({
        where: { createdAt, status: ProviderStatus.PENDING },
      }),
      this.prisma.provider.count({
        where: { createdAt, status: ProviderStatus.ACTIVE },
      }),
      this.prisma.provider.count({
        where: { createdAt, status: ProviderStatus.NEEDS_CHANGES },
      }),
      this.prisma.provider.count({
        where: { createdAt, status: ProviderStatus.SUSPENDED },
      }),
      this.prisma.provider.count({
        where: { createdAt, status: ProviderStatus.REJECTED },
      }),
      this.prisma.provider.count({ where: { createdAt, isFeatured: true } }),
    ]);
    return {
      total,
      pending,
      active,
      needsChanges,
      suspended,
      rejected,
      featured,
    };
  }

  private async getServiceReport(createdAt?: Prisma.DateTimeFilter) {
    const [total, active, disabled, featured] = await Promise.all([
      this.prisma.providerService.count({ where: { createdAt } }),
      this.prisma.providerService.count({
        where: { createdAt, isActive: true },
      }),
      this.prisma.providerService.count({
        where: { createdAt, isActive: false },
      }),
      this.prisma.providerService.count({
        where: { createdAt, isFeatured: true },
      }),
    ]);
    return { total, active, disabled, featured };
  }

  private async getReviewReport(createdAt?: Prisma.DateTimeFilter) {
    const [total, published, hidden, pending, average] = await Promise.all([
      this.prisma.providerReview.count({ where: { createdAt } }),
      this.prisma.providerReview.count({
        where: { createdAt, status: ReviewStatus.PUBLISHED },
      }),
      this.prisma.providerReview.count({
        where: { createdAt, status: ReviewStatus.HIDDEN },
      }),
      this.prisma.providerReview.count({
        where: { createdAt, status: ReviewStatus.PENDING },
      }),
      this.prisma.providerReview.aggregate({
        where: { createdAt },
        _avg: { rating: true },
      }),
    ]);
    return toAdminReviewReport({
      total,
      published,
      hidden,
      pending,
      averageRating: average._avg.rating,
    });
  }

  private async getQuoteReport(createdAt?: Prisma.DateTimeFilter) {
    const statuses = await Promise.all(
      Object.values(QuoteRequestStatus).map(async (status) => ({
        status,
        count: await this.prisma.quoteRequest.count({
          where: { createdAt, status },
        }),
      })),
    );
    return toAdminQuoteReport(statuses);
  }

  private async getNotificationReport(createdAt?: Prisma.DateTimeFilter) {
    const [total, unread, archived, high, urgent] = await Promise.all([
      this.prisma.notification.count({ where: { createdAt } }),
      this.prisma.notification.count({
        where: { createdAt, readAt: null, archivedAt: null },
      }),
      this.prisma.notification.count({
        where: { createdAt, archivedAt: { not: null } },
      }),
      this.prisma.notification.count({
        where: { createdAt, priority: NotificationPriority.HIGH },
      }),
      this.prisma.notification.count({
        where: { createdAt, priority: NotificationPriority.URGENT },
      }),
    ]);
    return { total, unread, archived, high, urgent };
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
        OR: [{ primaryCategoryId: query.categoryId }, { services: { some: { categoryId: query.categoryId } } }],
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

  private parseReviewStatus(value: string): ReviewStatus {
    const normalized = this.requiredText(value, 'status').toUpperCase();
    if (normalized in ReviewStatus) {
      return ReviewStatus[normalized as keyof typeof ReviewStatus];
    }
    throw new BadRequestException('review status is not supported');
  }

  private parseConversationReportStatus(value: string): ConversationReportStatus {
    const normalized = this.requiredText(value, 'status').toUpperCase();
    if (normalized in ConversationReportStatus) {
      return ConversationReportStatus[normalized as keyof typeof ConversationReportStatus];
    }
    throw new BadRequestException('conversation report status is not supported');
  }

  private parseNotificationType(value: string): NotificationType {
    const normalized = this.requiredText(value, 'type').toUpperCase();
    if (normalized in NotificationType) {
      return NotificationType[normalized as keyof typeof NotificationType];
    }
    throw new BadRequestException('notification type is not supported');
  }

  private parseNotificationPriority(value: string): NotificationPriority {
    const normalized = this.requiredText(value, 'priority').toUpperCase();
    if (normalized in NotificationPriority) {
      return NotificationPriority[normalized as keyof typeof NotificationPriority];
    }
    throw new BadRequestException('notification priority is not supported');
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

  private optionalDecimal(value: string | null | undefined, field: string): string | null {
    if (value === undefined || value === null) return null;
    const normalized = value.trim();
    if (!normalized) return null;
    return requiredMoneyAmount(normalized, field);
  }

  private optionalBoolean(value: string | null | undefined, field: string): boolean | null {
    if (value === undefined || value === null || value.trim() === '') return null;
    const normalized = value.trim().toLowerCase();
    if (normalized === 'true') return true;
    if (normalized === 'false') return false;
    throw new BadRequestException(`${field} must be true or false`);
  }

  private parseDateRange(from?: string, to?: string) {
    const fromDate = this.optionalDate(from, 'from');
    const toDate = this.optionalDate(to, 'to');
    if (fromDate && toDate && fromDate > toDate) {
      throw new BadRequestException('from must be before to');
    }
    const where =
      fromDate || toDate
        ? {
            ...(fromDate ? { gte: fromDate } : {}),
            ...(toDate ? { lte: toDate } : {}),
          }
        : undefined;
    return { from: fromDate, to: toDate, where };
  }

  private optionalDate(value: string | null | undefined, field: string): Date | null {
    if (value === undefined || value === null) return null;
    const trimmed = value.trim();
    if (!trimmed) return null;
    const date = new Date(trimmed);
    if (Number.isNaN(date.getTime())) {
      throw new BadRequestException(`${field} must be a valid date`);
    }
    return date;
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
}
