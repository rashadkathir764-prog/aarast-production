import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  AdminRole,
  ConversationReportStatus,
  NotificationPriority,
  Prisma,
  ProviderClaimStatus,
  ProviderReviewEventKind,
  ProviderReviewField,
  ProviderStatus,
  ReviewStatus,
  UserRole,
  UserStatus,
} from '@prisma/client';
import {
  providerServiceRequired,
  type ProviderFieldNote,
} from '../modules/marketplace/public/provider-review';
import { AdminProviderClaims } from './admin-provider-claims';
import { AdminFeaturedPlacements } from './admin-featured-placements';
import { lockProviderReviewAccountsInTransaction } from './admin-provider-review-lock';
import {
  AdminEndFeaturedPeriodDto,
  AdminFeaturedPeriodQueryDto,
  AdminGrantFeaturedPeriodDto,
} from './dto/admin-featured-period.dto';
import {
  AdminClaimDecisionDto,
  AdminClaimRequestQueryDto,
} from './dto/admin-claim-request.dto';
import { AdminRequestChangesDto } from './dto/admin-request-changes.dto';
import { AuthenticatedUser } from '../modules/identity/public/identity-session.types';
import {
  AdminPermission,
  hasAdminPermission,
} from '../modules/backoffice/domain/admin-permissions';
import { runSerializableTransaction } from '../platform/database/serializable-transaction';
import {
  enqueueConversationAccessRevoked,
  enqueueUserSessionsRevoked,
} from '../platform/outbox/realtime-revocation';
import { PrismaService } from '../platform/database/prisma.service';
import { MESSAGING_REALTIME_PORT, type MessagingRealtimePort } from '../modules/messaging/public/messaging-realtime.port';
import { NOTIFICATIONS_PORT, type NotificationsPort } from '../modules/notifications/public/notifications.port';
import type {
  AdminServiceFilter,
  AdminTextSearch,
} from '../modules/marketplace/public/marketplace-admin.port';
import type { AccountSearchField } from '../modules/identity/public/identity-admin.port';
import { AdminMutationExecutor } from './admin-mutation-executor';
import { AdminOwners } from './admin-owners';
import { switchProviderStatusNotification } from './provider-status-notification';
import { noticeRoutes } from '../shared-kernel/routes/notification-routes';
import {
  assertProviderAdminAction,
  ProviderAdminAction,
  providerApplicationDefaultStatuses,
  providerDirectoryDefaultStatuses,
} from './provider-admin-lifecycle';
import { AdminCategoryDto, AdminCityDto } from './dto/admin-catalog.dto';
import {
  toAdminClaimRequestResponse,
  toAdminQuoteReport,
  toAdminReportsOverviewResponse,
  toAdminReviewResponse,
  toAdminReviewReport,
  toAdminServiceResponse,
  toAdminUserReport,
  toCategoryAdminResponse,
  toCityResponse,
  toProviderResponse,
  toProviderReviewHistoryResponse,
  toUserResponse,
} from './admin.presenter';
import { AdminProviderQueryDto } from './dto/admin-provider-query.dto';
import { AdminReportQueryDto } from './dto/admin-report.dto';
import { AdminReviewQueryDto, AdminReviewStatusDto } from './dto/admin-review.dto';
import { AdminReviewActionDto } from './dto/admin-review-action.dto';
import {
  ACTIVE_USERS_WINDOW_DAYS,
  CONVERSION_WINDOW_DAYS,
  average,
  daysAgo,
  groupSpending,
  percent,
  SPENDING_MIN_PLANS,
  type SpendingRow,
} from './admin-success-report';
import { groupPrices } from '../modules/marketplace/public/market-prices';
import { AdminListedProviderDto } from './dto/admin-listed-provider.dto';
import { AdminServiceDto, AdminServiceQueryDto } from './dto/admin-service.dto';
import { AdminConversationReportQueryDto, AdminConversationReportStatusDto } from './dto/admin-conversation-report.dto';
import { authorizeAdminUserStatusChange } from './admin-user-status';
import { adminBookingFilter, toAdminBookingResponse } from './admin-bookings';
import type { AdminBookingQueryDto } from './dto/admin-booking.dto';

interface Pagination {
  page: number;
  limit: number;
  skip: number;
}

@Injectable()
export class AdminService {
  private readonly mutations: AdminMutationExecutor;
  private readonly claims: AdminProviderClaims;
  private readonly featured: AdminFeaturedPlacements;

  constructor(
    private readonly prisma: PrismaService,
    @Inject(MESSAGING_REALTIME_PORT)
    private readonly realtime: MessagingRealtimePort,
    @Inject(NOTIFICATIONS_PORT) private readonly notifications: NotificationsPort,
    private readonly owners: AdminOwners,
  ) {
    this.mutations = new AdminMutationExecutor(prisma, owners);
    this.claims = new AdminProviderClaims({ prisma, owners, notifications });
    this.featured = new AdminFeaturedPlacements({ prisma, owners, notifications });
  }

  // B-43: featured placement, recorded by hand after the provider paid
  // outside the app.
  async listFeaturedPeriods(query: AdminFeaturedPeriodQueryDto) {
    return this.featured.list(query, this.parsePagination(query.page, query.limit));
  }

  async getFeaturedSummary() {
    return this.featured.summary();
  }

  async grantFeaturedPeriod(
    currentUser: AuthenticatedUser,
    providerId: string,
    dto: AdminGrantFeaturedPeriodDto,
  ) {
    return this.featured.grant(currentUser, providerId, dto);
  }

  async endFeaturedPeriod(
    currentUser: AuthenticatedUser,
    periodId: string,
    dto: AdminEndFeaturedPeriodDto,
  ) {
    return this.featured.end(currentUser, periodId, dto);
  }

  async getDashboardStats() {
    // One transaction, as the single batch of counters it replaces.
    const [
      totalUsers,
      marketplace,
      totalWeddingPlans,
      totalCities,
      totalProviderCategories,
    ] = await this.prisma.$transaction(async (tx) =>
      Promise.all([
        this.owners.accounts.countAccounts(tx),
        this.owners.marketplace.getCounters(tx),
        this.owners.plans.countPlans(tx),
        this.owners.catalog.countCities(tx, { isActive: true }),
        this.owners.catalog.countCategories(tx),
      ]),
    );

    return {
      totalUsers,
      totalProviders: marketplace.totalProviders,
      pendingProviders: marketplace.pendingProviders,
      approvedProviders: marketplace.approvedProviders,
      rejectedProviders: marketplace.rejectedProviders,
      needsChangesProviders: marketplace.needsChangesProviders,
      suspendedProviders: marketplace.suspendedProviders,
      resubmittedProviders: marketplace.resubmittedProviders,
      pendingClaims: marketplace.pendingClaims,
      totalQuoteRequests: marketplace.totalQuoteRequests,
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
    const status = this.parseProviderStatus(query.status);
    const searchText = this.optionalText(query.search);
    const resubmitted = this.optionalBoolean(query.resubmitted, 'resubmitted');
    // «أُعيد إرسالها» narrows the profiles waiting for review (B-01).
    if (resubmitted !== null && status !== null && status !== ProviderStatus.PENDING) {
      throw new BadRequestException('resubmitted narrows PENDING profiles only');
    }
    const { total, providers } = await this.prisma.$transaction(async (tx) => {
      const search = await this.textSearch(tx, searchText, ['name', 'phone']);
      const listing = await this.owners.marketplace.listProviders(
        tx,
        {
          statuses: status ? [status] : defaultStatuses,
          cityId: query.cityId || null,
          categoryId: query.categoryId || null,
          search,
          resubmitted,
        },
        { skip: pagination.skip, take: pagination.limit },
      );
      return {
        total: listing.total,
        providers: await this.owners.attachProviders(tx, listing.items),
      };
    });

    return this.paginate(
      providers.map((provider) => toProviderResponse(provider)),
      total,
      pagination,
    );
  }

  async getProvider(id: string) {
    const provider = await this.prisma.$transaction(async (tx) => {
      const row = await this.owners.marketplace.getProvider(tx, id);
      return row ? this.owners.attachProviderDetail(tx, row) : null;
    });

    if (!provider) {
      throw new NotFoundException('Provider application not found');
    }

    return toProviderResponse(provider);
  }

  async listServices(query: AdminServiceQueryDto) {
    const pagination = this.parsePagination(query.page, query.limit);
    const filter = this.serviceFilter(query);
    const { total, services } = await this.prisma.$transaction(async (tx) => {
      const listing = await this.owners.marketplace.listServices(tx, filter, {
        skip: pagination.skip,
        take: pagination.limit,
      });
      return {
        total: listing.total,
        services: await this.owners.attachServices(tx, listing.items),
      };
    });

    return this.paginate(
      services.map((service) => toAdminServiceResponse(service)),
      total,
      pagination,
    );
  }

  async createListedProvider(
    currentUser: AuthenticatedUser,
    dto: AdminListedProviderDto,
  ) {
    return this.mutations.createListedProvider(currentUser, dto);
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

  /** a12 (B-40): bookings, read only, newest day first. */
  async listBookings(query: AdminBookingQueryDto) {
    const pagination = this.parsePagination(query.page, query.limit);
    const filter = adminBookingFilter(query);
    const listing = await this.prisma.$transaction((tx) =>
      this.owners.marketplace.listBookings(tx, filter, {
        skip: pagination.skip,
        take: pagination.limit,
      }),
    );
    return this.paginate(
      listing.items.map((booking) => toAdminBookingResponse(booking)),
      listing.total,
      pagination,
    );
  }

  async getBooking(id: string) {
    const booking = await this.prisma.$transaction((tx) =>
      this.owners.marketplace.getBooking(tx, id),
    );
    if (!booking) throw new NotFoundException('Booking not found');
    return toAdminBookingResponse(booking);
  }

  async listReviews(query: AdminReviewQueryDto) {
    const pagination = this.parsePagination(query.page, query.limit);
    const status = query.status ? this.parseReviewStatus(query.status) : null;
    const searchText = this.optionalText(query.search);
    const { total, reviews } = await this.prisma.$transaction(async (tx) => {
      const search = await this.textSearch(tx, searchText, ['name']);
      const listing = await this.owners.marketplace.listReviews(
        tx,
        {
          ...(status ? { status } : {}),
          ...(query.providerId ? { providerId: query.providerId } : {}),
          ...(search ? { search } : {}),
        },
        { skip: pagination.skip, take: pagination.limit },
      );
      return {
        total: listing.total,
        reviews: await this.owners.attachReviews(tx, listing.items),
      };
    });

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

  async updateReviewReplyStatus(
    currentUser: AuthenticatedUser,
    id: string,
    dto: AdminReviewStatusDto,
  ) {
    return this.mutations.updateReviewReplyStatus(currentUser, id, dto);
  }

  async hideReview(currentUser: AuthenticatedUser, id: string) {
    return this.mutations.hideReview(currentUser, id);
  }

  async listConversationReports(query: AdminConversationReportQueryDto) {
    const pagination = this.parsePagination(query.page, query.limit);
    const status = query.status
      ? this.parseConversationReportStatus(query.status)
      : null;
    const { total, reports } = await this.prisma.$transaction(async (tx) => {
      const listing = await this.owners.messaging.listConversationReports(
        tx,
        status,
        { skip: pagination.skip, take: pagination.limit },
      );
      return {
        total: listing.total,
        reports: await this.owners.attachConversationReports(tx, listing.items),
      };
    });
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

  /**
   * The success indicators and the market price report (V1 checklist
   * 4.21): weekly active accounts, costs recorded per plan, quote requests
   * that became confirmed bookings, providers customers can see, and price
   * ranges by city and category (only groups priced by several providers).
   */
  async getSuccessReport() {
    const now = new Date();
    const [activeAccounts, totalAccounts, costs, marketplace, priced, spending] =
      await this.prisma.$transaction(async (tx) =>
        Promise.all([
          this.owners.accounts.countActiveAccountsSince(
            tx,
            daysAgo(now, ACTIVE_USERS_WINDOW_DAYS),
          ),
          this.owners.accounts.countAccounts(tx),
          this.owners.finance.countRecordedCosts(tx),
          this.owners.marketplace.getSuccessCounts(
            tx,
            daysAgo(now, CONVERSION_WINDOW_DAYS),
          ),
          this.owners.marketplace.listPricedServices(tx),
          this.spendingRows(tx),
        ]),
      );
    const groups = groupPrices(priced);
    const { cities, categories } = await this.owners.catalogNames(
      this.prisma,
      groups.map((group) => group.cityId),
      groups.map((group) => group.categoryId),
    );
    return {
      generatedAt: now,
      activeUsers: {
        windowDays: ACTIVE_USERS_WINDOW_DAYS,
        active: activeAccounts,
        total: totalAccounts,
      },
      costs: {
        recorded: costs.costs,
        plansWithCosts: costs.plans,
        perPlan: average(costs.costs, costs.plans),
      },
      conversion: {
        windowDays: CONVERSION_WINDOW_DAYS,
        quoteRequests: marketplace.quoteRequests,
        confirmedBookings: marketplace.confirmedBookings,
        rate: percent(marketplace.confirmedBookings, marketplace.quoteRequests),
      },
      visibleProviders: marketplace.visibleProviders,
      prices: groups.map((group) => ({
        ...group,
        cityName: cities.get(group.cityId) ?? null,
        categoryName: categories.get(group.categoryId) ?? null,
      })),
      // G41: what plans really agreed, anonymous (groups of 5 plans or more).
      spending: {
        minPlans: SPENDING_MIN_PLANS,
        groups: groupSpending(spending),
      },
    };
  }

  /** G41: finance's agreed totals per item, with each plan's city and currency. */
  private async spendingRows(tx: Prisma.TransactionClient): Promise<SpendingRow[]> {
    const samples = await this.owners.finance.listSpendingSamples(tx);
    if (samples.length === 0) return [];
    const plans = await this.owners.plans.getPlans(tx, [
      ...new Set(samples.map((sample) => sample.weddingPlanId)),
    ]);
    const byId = new Map(plans.map((plan) => [plan.id, plan]));
    return samples.flatMap((sample) => {
      const plan = byId.get(sample.weddingPlanId);
      return plan
        ? [
            {
              weddingPlanId: sample.weddingPlanId,
              itemName: sample.itemName,
              city: plan.city,
              currency: plan.currency,
              total: sample.total.toString(),
            },
          ]
        : [];
    });
  }

  async getReportsOverview(query: AdminReportQueryDto) {
    const range = this.parseDateRange(query.from, query.to);
    const createdAt = range.where;
    const [users, marketplace, notifications, weddingPlans, cities, categories] =
      await Promise.all([
        this.owners.accounts.getAccountCounts(this.prisma, createdAt),
        this.owners.marketplace.getReport(this.prisma, createdAt),
        this.owners.notifications.getReport(this.prisma, createdAt),
        this.owners.plans.countPlans(this.prisma, createdAt),
        this.owners.catalog.countCities(this.prisma),
        this.owners.catalog.countCategories(this.prisma),
      ]);

    return toAdminReportsOverviewResponse({
      generatedAt: new Date(),
      from: range.from,
      to: range.to,
      users: toAdminUserReport(users),
      providers: marketplace.providers,
      services: marketplace.services,
      reviews: toAdminReviewReport(marketplace.reviews),
      quotes: toAdminQuoteReport(marketplace.quotes),
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
      ProviderReviewEventKind.APPROVED,
      [],
    );
  }

  async rejectProvider(currentUser: AuthenticatedUser, id: string, dto: AdminReviewActionDto) {
    return this.reviewProvider(
      currentUser,
      id,
      'REJECT',
      ProviderStatus.REJECTED,
      ProviderReviewEventKind.REJECTED,
      this.generalNote(dto.reason),
    );
  }

  /**
   * «اطلب تعديل» (B-01): a note about the whole profile, one per field to
   * fix, or both. Allowed again while the provider is still fixing, so the
   * team can rewrite its notes; the newest decision's notes are the ones the
   * provider reads.
   */
  async requestProviderChanges(
    currentUser: AuthenticatedUser,
    id: string,
    dto: AdminRequestChangesDto,
  ) {
    const notes: ProviderFieldNote[] = [...this.generalNote(dto.note)];
    const seen = new Set<string>();
    for (const fieldNote of dto.fieldNotes ?? []) {
      if (seen.has(fieldNote.field)) {
        throw new BadRequestException('fieldNotes must name each field once');
      }
      seen.add(fieldNote.field);
      notes.push({
        field: ProviderReviewField[fieldNote.field],
        note: this.requiredText(fieldNote.note, 'fieldNotes.note'),
      });
    }
    if (notes.length === 0) {
      throw new BadRequestException('note or fieldNotes must not be empty');
    }
    return this.reviewProvider(
      currentUser,
      id,
      'REQUEST_CHANGES',
      ProviderStatus.NEEDS_CHANGES,
      ProviderReviewEventKind.CHANGES_REQUESTED,
      notes,
    );
  }

  async suspendProvider(currentUser: AuthenticatedUser, id: string, dto: AdminReviewActionDto) {
    return this.reviewProvider(
      currentUser,
      id,
      'SUSPEND',
      ProviderStatus.SUSPENDED,
      ProviderReviewEventKind.SUSPENDED,
      this.generalNote(dto.reason),
    );
  }

  async activateProvider(currentUser: AuthenticatedUser, id: string) {
    return this.reviewProvider(
      currentUser,
      id,
      'ACTIVATE',
      ProviderStatus.ACTIVE,
      ProviderReviewEventKind.ACTIVATED,
      [],
    );
  }

  /** When the provider applied and every review step since (B-01, B-02). */
  async getProviderReviewHistory(id: string) {
    const history = await this.prisma.$transaction(async (tx) => {
      const provider = await this.owners.marketplace.getProvider(tx, id);
      if (!provider) return null;
      const events = await this.owners.attachReviewEvents(
        tx,
        await this.owners.marketplace.listProviderReviewEvents(tx, id),
      );
      return { provider, events };
    });
    if (!history) {
      throw new NotFoundException('Provider application not found');
    }
    return toProviderReviewHistoryResponse(history.provider, history.events);
  }

  async listClaimRequests(query: AdminClaimRequestQueryDto) {
    const pagination = this.parsePagination(query.page, query.limit);
    const status = this.parseClaimStatus(query.status);
    const { total, claims } = await this.prisma.$transaction(async (tx) => {
      const listing = await this.owners.marketplace.listClaimRequests(
        tx,
        { status },
        { skip: pagination.skip, take: pagination.limit },
      );
      return {
        total: listing.total,
        claims: await this.owners.attachClaimRequests(tx, listing.items),
      };
    });
    return this.paginate(
      claims.map((claim) => toAdminClaimRequestResponse(claim)),
      total,
      pagination,
    );
  }

  async approveClaimRequest(currentUser: AuthenticatedUser, id: string) {
    return this.claims.approve(currentUser, id);
  }

  async rejectClaimRequest(
    currentUser: AuthenticatedUser,
    id: string,
    dto: AdminClaimDecisionDto,
  ) {
    return this.claims.reject(
      currentUser,
      id,
      this.requiredText(dto.note, 'note'),
    );
  }

  /**
   * Marks (or unmarks) that an admin checked the provider's documents. Only an
   * ACTIVE listing can be verified; the badge is cleared freely.
   */
  async setProviderVerified(
    currentUser: AuthenticatedUser,
    id: string,
    verified: boolean,
  ) {
    const provider = await runSerializableTransaction(this.prisma, async (tx) => {
      const seed = await this.owners.marketplace.findProviderAccount(tx, id);
      if (!seed) {
        throw new NotFoundException('Provider not found');
      }
      if (seed.userId === currentUser.id) {
        throw new BadRequestException('Provider owners cannot verify their own listing');
      }
      await this.lockProviderReviewUsersInTransaction(tx, currentUser, seed.userId);
      const current =
        await this.owners.marketplace.lockProviderForUpdateInTransaction(tx, id);
      if (!current || current.userId !== seed.userId) {
        throw new NotFoundException('Provider not found');
      }
      if (verified && current.status !== ProviderStatus.ACTIVE) {
        throw new ConflictException('Only an active provider can be verified');
      }
      const updated =
        await this.owners.marketplace.recordProviderVerificationInTransaction(
          tx,
          id,
          verified
            ? { verifiedAt: new Date(), verifiedById: currentUser.id }
            : { verifiedAt: null, verifiedById: null },
        );
      return this.owners.attachProviderDetail(tx, updated);
    });
    return toProviderResponse(provider);
  }

  async listCategories() {
    const { categories, starterItems } = await this.prisma.$transaction(
      async (tx) => ({
        categories: await this.owners.attachCategories(
          tx,
          await this.owners.catalog.listCategories(tx),
        ),
        starterItems: await this.owners.catalog.listStarterBudgetItems(tx),
      }),
    );

    return categories.map((category) => toCategoryAdminResponse(category, starterItems));
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
    const cities = await this.prisma.$transaction(async (tx) =>
      this.owners.attachCities(tx, await this.owners.catalog.listCities(tx)),
    );

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
    const { total, users } = await this.prisma.$transaction(async (tx) => {
      const listing = await this.owners.accounts.listAccounts(tx, search, {
        skip: pagination.skip,
        take: pagination.limit,
      });
      return {
        total: listing.total,
        users: await this.owners.attachAccounts(tx, listing.items),
      };
    });

    return this.paginate(
      users.map((user) => toUserResponse(user)),
      total,
      pagination,
    );
  }

  async getUser(id: string) {
    const user = await this.prisma.$transaction(async (tx) => {
      const account = await this.owners.accounts.getAccount(tx, id);
      return account
        ? (await this.owners.attachAccounts(tx, [account]))[0]!
        : null;
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
        this.owners.accounts,
        currentUser,
        id,
      );
      const updated = await this.owners.accounts.setAccountStatusInTransaction(
        tx,
        target.id,
        UserStatus.ACTIVE,
      );
      return (await this.owners.attachAccounts(tx, [updated]))[0]!;
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
        this.owners.accounts,
        currentUser,
        id,
      );
      if (
        target.role === UserRole.ADMIN &&
        target.adminRole === AdminRole.SUPER_ADMIN &&
        target.status === UserStatus.ACTIVE
      ) {
        const activeSuperAdmins =
          await this.owners.accounts.countActiveSuperAdminsInTransaction(tx);
        if (activeSuperAdmins <= 1) {
          throw new ConflictException(
            'The last active super administrator cannot be disabled',
          );
        }
      }

      const updated = await this.owners.accounts.setAccountStatusInTransaction(
        tx,
        target.id,
        UserStatus.DISABLED,
      );
      await this.owners.collaboration.revokeLiveInvitesIssuedByUserInTransaction(
        tx,
        target.id,
        now,
      );
      await this.owners.accounts.revokeRefreshTokensInTransaction(
        tx,
        target.id,
        now,
      );
      await enqueueUserSessionsRevoked(tx, target.id);
      return (await this.owners.attachAccounts(tx, [updated]))[0]!;
    });
    // Sessions were just revoked; sever any live realtime channel the now
    // disabled account still holds open.
    this.realtime.disconnectUser(id);
    return toUserResponse(user);
  }

  /** The note about the whole profile, when the text has one. */
  private generalNote(text: string | null | undefined): ProviderFieldNote[] {
    const note = this.optionalText(text);
    return note ? [{ field: ProviderReviewField.GENERAL, note }] : [];
  }

  private parseClaimStatus(value?: string): ProviderClaimStatus | null {
    const normalized = value?.trim().toUpperCase();
    if (!normalized) return null;
    if (normalized in ProviderClaimStatus) {
      return ProviderClaimStatus[normalized as keyof typeof ProviderClaimStatus];
    }
    throw new BadRequestException('claim status is not supported');
  }

  private async reviewProvider(
    currentUser: AuthenticatedUser,
    id: string,
    action: ProviderAdminAction,
    status: ProviderStatus,
    kind: ProviderReviewEventKind,
    notes: readonly ProviderFieldNote[],
  ) {
    const reviewNote =
      notes.find((note) => note.field === ProviderReviewField.GENERAL)?.note ??
      null;
    const result = await runSerializableTransaction(this.prisma, async (tx) => {
      const seed = await this.owners.marketplace.findProviderAccount(tx, id);
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
      const currentProvider =
        await this.owners.marketplace.lockProviderForUpdateInTransaction(tx, id);
      if (!currentProvider || currentProvider.userId !== seed.userId) {
        throw new NotFoundException('Provider application not found');
      }
      assertProviderAdminAction(action, currentProvider.status);
      // D41 (B-10): a profile is approved only with an active priced
      // service, the same rule resubmitting reads.
      if (
        action === 'APPROVE' &&
        !(await this.owners.marketplace.hasJoiningService(tx, id))
      ) {
        throw providerServiceRequired();
      }
      const reviewedAt = new Date();

      const updated = await this.owners.marketplace.recordProviderReviewInTransaction(
        tx,
        id,
        {
          status,
          kind,
          notes,
          reviewedAt,
          reviewedById: currentUser.id,
        },
      );

      if (
        updated.userId &&
        status === ProviderStatus.ACTIVE &&
        !(await this.owners.providerAccounts.promoteToProviderInTransaction(
          tx,
          updated.userId,
        ))
      ) {
        throw new BadRequestException(
          'The application identity is not eligible for provider approval',
        );
      }

      // B-42: a suspension ends his open booking requests and keeps the
      // confirmed bookings; every customer concerned is told which.
      if (status === ProviderStatus.SUSPENDED) {
        const notices =
          await this.owners.marketplace.settleBookingsOnSuspensionInTransaction(
            tx,
            id,
            reviewedAt,
          );
        for (const notice of notices) {
          await this.notifications.createNotificationInTransaction(tx, notice);
        }
      }

      const revokedConversationIds =
        updated.userId && status !== ProviderStatus.ACTIVE
          ? await this.owners.messaging.listProviderConversationIds(
              tx,
              updated.id,
            )
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
          reviewNote,
        );
        await this.notifications.createNotificationInTransaction(tx, {
          userId: updated.userId,
          type: notification.type,
          priority:
            status === ProviderStatus.REJECTED ||
            status === ProviderStatus.SUSPENDED
              ? NotificationPriority.HIGH
              : NotificationPriority.NORMAL,
          title: notification.title,
          body: notification.body,
          entityType: 'Provider',
          entityId: updated.id,
          routeTarget: noticeRoutes.providerPortal(),
          data: {
            providerId: updated.id,
            providerStatus: status,
            reviewNote,
          },
          dedupeKey: `provider-status:${updated.id}:${status}:${reviewedAt.toISOString()}`,
        });
      }

      return {
        provider: await this.owners.attachProviderDetail(tx, updated),
        revokedConversationIds,
      };
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
    await lockProviderReviewAccountsInTransaction(
      tx,
      this.owners,
      currentUser,
      providerOwnerUserId,
      'Provider application not found',
    );
  }

  /** The accounts identity matches for a search text; null without one. */
  private async textSearch(
    tx: Prisma.TransactionClient,
    text: string | null,
    fields: readonly AccountSearchField[],
  ): Promise<AdminTextSearch | null> {
    if (!text) return null;
    return {
      text,
      userIds: await this.owners.accounts.searchAccountIds(tx, text, fields),
    };
  }

  private serviceFilter(query: AdminServiceQueryDto): AdminServiceFilter {
    const status = query.status?.trim().toUpperCase();
    // A service is never «featured» on its own: placement is the provider's (B-43).
    if (status && !['ACTIVE', 'DISABLED', 'INACTIVE'].includes(status)) {
      throw new BadRequestException('service status is not supported');
    }
    const search = this.optionalText(query.search);
    return {
      ...(status === 'ACTIVE' ? { isActive: true } : {}),
      ...(status === 'DISABLED' || status === 'INACTIVE' ? { isActive: false } : {}),
      ...(query.providerId ? { providerId: query.providerId } : {}),
      ...(query.categoryId ? { categoryId: query.categoryId } : {}),
      ...(query.cityId ? { cityId: query.cityId } : {}),
      ...(search ? { search } : {}),
    };
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
