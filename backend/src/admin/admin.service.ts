import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
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
import {
  AdminPermission,
  hasAdminPermission,
} from '../common/admin/admin-permissions';
import { runSerializableTransaction } from '../common/prisma/serializable-transaction';
import {
  enqueueConversationAccessRevoked,
  enqueueUserSessionsRevoked,
} from '../outbox/realtime-revocation';
import { PrismaService } from '../prisma/prisma.service';
import { ConversationRealtimePublisher } from '../conversations/conversation-realtime.publisher';
import { NotificationsService } from '../notifications/notifications.service';
import { AdminMutationExecutor } from './admin-mutation-executor';
import { switchProviderStatusNotification } from './provider-status-notification';
import {
  assertProviderAdminAction,
  ProviderAdminAction,
  providerApplicationDefaultStatuses,
  providerDirectoryDefaultStatuses,
} from './provider-admin-lifecycle';
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
import {
  authorizeAdminUserStatusChange,
  revokePendingInvitesIssuedByUserInTransaction,
} from './admin-user-status';

interface Pagination {
  page: number;
  limit: number;
  skip: number;
}

@Injectable()
export class AdminService {
  private readonly mutations: AdminMutationExecutor;

  constructor(
    private readonly prisma: PrismaService,
    private readonly realtime: ConversationRealtimePublisher,
    private readonly notifications: NotificationsService,
  ) {
    this.mutations = new AdminMutationExecutor(prisma);
  }

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
    return this.listProvidersByDefaultStatuses(
      query,
      providerApplicationDefaultStatuses,
    );
  }

  async getProviderApplication(id: string) {
    return this.getProvider(id);
  }

  async listProviders(query: AdminProviderQueryDto) {
    return this.listProvidersByDefaultStatuses(
      query,
      providerDirectoryDefaultStatuses,
    );
  }

  private async listProvidersByDefaultStatuses(
    query: AdminProviderQueryDto,
    defaultStatuses: readonly ProviderStatus[],
  ) {
    const pagination = this.parsePagination(query.page, query.limit);
    const where = this.providerWhere(query, defaultStatuses);
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

  async createService(
    currentUser: AuthenticatedUser,
    dto: AdminServiceDto,
  ) {
    return this.mutations.createService(currentUser, dto);
  }

  async updateService(
    currentUser: AuthenticatedUser,
    id: string,
    dto: AdminServiceDto,
  ) {
    return this.mutations.updateService(currentUser, id, dto);
  }

  async deleteService(currentUser: AuthenticatedUser, id: string) {
    return this.mutations.deleteService(currentUser, id);
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

  async updateReviewStatus(
    currentUser: AuthenticatedUser,
    id: string,
    dto: AdminReviewStatusDto,
  ) {
    return this.mutations.updateReviewStatus(currentUser, id, dto);
  }

  async hideReview(currentUser: AuthenticatedUser, id: string) {
    return this.mutations.hideReview(currentUser, id);
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

  async updateConversationReportStatus(
    currentUser: AuthenticatedUser,
    id: string,
    dto: AdminConversationReportStatusDto,
  ) {
    return this.mutations.updateConversationReportStatus(
      currentUser,
      id,
      dto,
    );
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

  async markNotificationRead(currentUser: AuthenticatedUser, id: string) {
    return this.mutations.markNotificationRead(currentUser, id);
  }

  async archiveNotification(currentUser: AuthenticatedUser, id: string) {
    return this.mutations.archiveNotification(currentUser, id);
  }

  async deleteNotification(currentUser: AuthenticatedUser, id: string) {
    return this.mutations.deleteNotification(currentUser, id);
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
    return this.reviewProvider(
      currentUser,
      id,
      'APPROVE',
      ProviderStatus.ACTIVE,
      null,
    );
  }

  async rejectProvider(currentUser: AuthenticatedUser, id: string, dto: AdminReviewActionDto) {
    return this.reviewProvider(
      currentUser,
      id,
      'REJECT',
      ProviderStatus.REJECTED,
      this.optionalText(dto.reason),
    );
  }

  async requestProviderChanges(currentUser: AuthenticatedUser, id: string, dto: AdminReviewActionDto) {
    const note = this.requiredText(dto.note, 'note');
    return this.reviewProvider(
      currentUser,
      id,
      'REQUEST_CHANGES',
      ProviderStatus.NEEDS_CHANGES,
      note,
    );
  }

  async suspendProvider(currentUser: AuthenticatedUser, id: string, dto: AdminReviewActionDto) {
    return this.reviewProvider(
      currentUser,
      id,
      'SUSPEND',
      ProviderStatus.SUSPENDED,
      this.optionalText(dto.reason),
    );
  }

  async activateProvider(currentUser: AuthenticatedUser, id: string) {
    return this.reviewProvider(
      currentUser,
      id,
      'ACTIVATE',
      ProviderStatus.ACTIVE,
      null,
    );
  }

  async listCategories() {
    const categories = await this.prisma.providerCategory.findMany({
      orderBy: [{ sortOrder: 'asc' }, { nameAr: 'asc' }],
      include: { _count: { select: { providers: true, services: true } } },
    });

    return categories.map((category) => toCategoryResponse(category));
  }

  async createCategory(
    currentUser: AuthenticatedUser,
    dto: AdminCategoryDto,
  ) {
    return this.mutations.createCategory(currentUser, dto);
  }

  async updateCategory(
    currentUser: AuthenticatedUser,
    id: string,
    dto: AdminCategoryDto,
  ) {
    return this.mutations.updateCategory(currentUser, id, dto);
  }

  async deleteCategory(currentUser: AuthenticatedUser, id: string) {
    return this.mutations.deleteCategory(currentUser, id);
  }

  async listCities() {
    const cities = await this.prisma.city.findMany({
      orderBy: [{ sortOrder: 'asc' }, { nameAr: 'asc' }],
      include: { _count: { select: { providers: true, services: true } } },
    });

    return cities.map((city) => toCityResponse(city));
  }

  async createCity(currentUser: AuthenticatedUser, dto: AdminCityDto) {
    return this.mutations.createCity(currentUser, dto);
  }

  async updateCity(
    currentUser: AuthenticatedUser,
    id: string,
    dto: AdminCityDto,
  ) {
    return this.mutations.updateCity(currentUser, id, dto);
  }

  async deleteCity(currentUser: AuthenticatedUser, id: string) {
    return this.mutations.deleteCity(currentUser, id);
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
      await revokePendingInvitesIssuedByUserInTransaction(tx, target.id, now);
      await tx.refreshToken.updateMany({
        where: { userId: target.id, revokedAt: null },
        data: { revokedAt: now },
      });
      await enqueueUserSessionsRevoked(tx, target.id);
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
    action: ProviderAdminAction,
    status: ProviderStatus,
    reviewNote: string | null,
  ) {
    const result = await runSerializableTransaction(this.prisma, async (tx) => {
      const seed = await tx.provider.findUnique({
        where: { id },
        select: { userId: true },
      });
      if (!seed) {
        throw new NotFoundException('Provider application not found');
      }
      if (seed.userId === currentUser.id) {
        throw new BadRequestException('Provider owners cannot review their own application');
      }

      await this.lockProviderReviewUsersInTransaction(
        tx,
        currentUser,
        seed.userId,
      );
      await this.lockProviderReviewRowInTransaction(tx, id, seed.userId);
      const currentProvider = await tx.provider.findUnique({
        where: { id },
        select: { status: true },
      });
      if (!currentProvider) {
        throw new NotFoundException('Provider application not found');
      }
      assertProviderAdminAction(action, currentProvider.status);
      const reviewedAt = new Date();

      const updated = await tx.provider.update({
        where: { id },
        data: {
          status,
          reviewNote,
          reviewedAt,
          reviewedById: currentUser.id,
        },
        include: this.providerDetailInclude(),
      });

      if (updated.userId && status === ProviderStatus.ACTIVE) {
        let promoted = await tx.user.updateMany({
          where: {
            id: updated.userId,
            status: UserStatus.ACTIVE,
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
              status: UserStatus.ACTIVE,
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

      const revokedConversationIds =
        updated.userId && status !== ProviderStatus.ACTIVE
          ? (
              await tx.conversation.findMany({
                where: { providerId: updated.id },
                orderBy: { id: 'asc' },
                select: { id: true },
              })
            ).map((conversation) => conversation.id)
          : [];
      if (updated.userId) {
        await enqueueConversationAccessRevoked(
          tx,
          updated.userId,
          revokedConversationIds,
        );
        const notification = switchProviderStatusNotification(
          updated.businessName,
          status,
          reviewNote?.trim() || null,
        );
        await this.notifications.createNotificationInTransaction(tx, {
          userId: updated.userId,
          type: NotificationType.GENERAL,
          priority:
            status === ProviderStatus.REJECTED ||
            status === ProviderStatus.SUSPENDED
              ? NotificationPriority.HIGH
              : NotificationPriority.NORMAL,
          title: notification.title,
          body: notification.body,
          entityType: 'Provider',
          entityId: updated.id,
          routeTarget: '/provider/dashboard',
          data: {
            providerId: updated.id,
            providerStatus: status,
            reviewNote,
          },
          dedupeKey: `provider-status:${updated.id}:${status}:${reviewedAt.toISOString()}`,
        });
      }

      return { provider: updated, revokedConversationIds };
    });
    const { provider, revokedConversationIds } = result;

    if (provider.userId && revokedConversationIds.length > 0) {
      this.realtime.revokeConversationAccess(
        provider.userId,
        revokedConversationIds,
      );
    }

    return toProviderResponse(provider);
  }

  private async lockProviderReviewUsersInTransaction(
    tx: Prisma.TransactionClient,
    currentUser: AuthenticatedUser,
    providerOwnerUserId: string | null,
  ): Promise<void> {
    const userIds = [...new Set(
      [currentUser.id, providerOwnerUserId].filter(
        (userId): userId is string => Boolean(userId),
      ),
    )].sort();
    const users = await tx.$queryRaw<
      Array<{
        id: string;
        role: UserRole;
        adminRole: AdminRole | null;
        status: UserStatus;
      }>
    >(
      Prisma.sql`
        SELECT "id", "role", "adminRole", "status"
        FROM "User"
        WHERE "id" IN (${Prisma.join(userIds)})
        ORDER BY "id" ASC
        FOR UPDATE
      `,
    );
    if (users.length !== userIds.length) {
      throw new NotFoundException('Provider application not found');
    }
    const actor = users.find((user) => user.id === currentUser.id);
    if (
      !actor ||
      actor.role !== UserRole.ADMIN ||
      actor.status !== UserStatus.ACTIVE ||
      !hasAdminPermission(actor.adminRole, AdminPermission.PROVIDERS_WRITE)
    ) {
      throw new ForbiddenException('Admin permission is required');
    }
  }

  private async lockProviderReviewRowInTransaction(
    tx: Prisma.TransactionClient,
    providerId: string,
    expectedOwnerUserId: string | null,
  ): Promise<void> {
    const rows = await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`
        SELECT "id"
        FROM "Provider"
        WHERE "id" = ${providerId}
        FOR UPDATE
      `,
    );
    if (rows.length !== 1) {
      throw new NotFoundException('Provider application not found');
    }
    const provider = await tx.provider.findUnique({
      where: { id: providerId },
      select: { userId: true },
    });
    if (!provider || provider.userId !== expectedOwnerUserId) {
      throw new NotFoundException('Provider application not found');
    }
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

  private async findUserOrThrow(id: string) {
    const user = await this.prisma.user.findUnique({ where: { id } });
    if (!user) throw new NotFoundException('User not found');
    return user;
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

  private providerWhere(
    query: AdminProviderQueryDto,
    defaultStatuses: readonly ProviderStatus[],
  ): Prisma.ProviderWhereInput {
    const and: Prisma.ProviderWhereInput[] = [];
    const status = this.parseProviderStatus(query.status);
    if (status) {
      and.push({ status });
    } else {
      and.push({ status: { in: [...defaultStatuses] } });
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
