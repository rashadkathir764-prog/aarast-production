import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
  UnprocessableEntityException,
} from '@nestjs/common';
import {
  Booking,
  City,
  ConversationEventType,
  NotificationPriority,
  NotificationType,
  Prisma,
  Provider,
  ProviderCategory,
  ProviderClaimStatus,
  ProviderReviewEventKind,
  ProviderPackage,
  ProviderReview,
  ProviderService,
  ProviderServiceImage,
  ProviderStatus,
  QuoteOffer,
  QuoteOfferStatus,
  QuoteRequest,
  QuoteRequestStatus,
  ReviewStatus,
  User,
  UserStatus,
  WeddingPlan,
} from '@prisma/client';
import { AuthenticatedUser } from '../modules/identity/public/identity-session.types';
import {
  bookingToday,
  DAILY_BOOKING_CAPACITY_MAX,
  DAILY_BOOKING_CAPACITY_MIN,
  toBookingResponse,
} from '../marketplace/booking-policy';
import type { ProviderBookingMoney } from '../marketplace/provider-booking-money';
import { providerStatsWindowStart, toProviderStats } from './provider-stats';
import { toReviewIdentity } from '../shared-kernel/privacy/review-identity';
import { PhoneNormalizer } from '../shared-kernel/phone/phone-normalizer';
import { runSerializableTransaction } from '../platform/database/serializable-transaction';
import {
  optionalMoneyAmount,
  requiredMoneyAmount,
} from '../shared-kernel/money/money';
import { CONVERSATION_LIFECYCLE_PORT, type ConversationLifecyclePort } from '../modules/messaging/public/conversation-lifecycle.port';
import {
  assertQuoteRequestAnswerable,
  assertQuoteRequestTransition,
  lockQuoteOfferTransitionRows,
  lockQuoteRequestTransitionRow,
  quoteLifecycleStatus,
  quoteRequestAnswerDeadline,
} from '../marketplace/quote-lifecycle';
import { isQuoteOfferExpired } from '../marketplace/quote-offer-expiry';
import { quoteOfferCurrencyMismatch } from '../marketplace/quote-offer-currency';
import {
  quoteOfferChanges,
  quoteOfferLocked,
  quoteOfferVersionView,
  toQuoteOfferChangesJson,
} from '../modules/marketplace/public/quote-offer-versions';
import { lockMarketplaceProvider } from '../marketplace/marketplace-write-locks';
import {
  isQuoteOfferRevisionNoticeDue,
  providerRejectedRequestNotification,
  quoteOfferReceivedNotification,
  quoteOfferRevisedNotification,
  quoteOfferWithdrawnNotification,
} from '../marketplace/quote-notifications';
import * as offerStore from '../modules/marketplace/infrastructure/quote-offer-lifecycle.repository';
import {
  MEDIA_STORAGE_PORT,
  MediaStoragePort,
} from '../modules/media/public/media-storage.port';
import {
  NOTIFICATIONS_PORT,
  type NotificationsPort,
} from '../modules/notifications/public/notifications.port';
import { PrismaService } from '../platform/database/prisma.service';
import { assertWeddingPlanWritable } from '../modules/collaboration/public/collaboration-permission.port';
import {
  CATALOG_READ_PORT,
  type CatalogReadPort,
} from '../modules/catalog/public/catalog-read.port';
import {
  PROVIDER_ACCOUNT_PORT,
  type ProviderAccountPort,
} from '../modules/identity/public/provider-account.port';
import { lockUserLifecycleRowsForUpdateInTransaction } from '../modules/identity/public/user-lifecycle-lock';
import { MarketplaceRelationsService } from '../marketplace/marketplace-relations';
import { toApplicationUserContact } from '../shared-kernel/privacy/application-user-identity';
import { weddingLocationResponse } from '../modules/planning/public/wedding-location';
import { ApplyProviderDto } from './dto/apply-provider.dto';
import { CreateProviderPackageDto } from './dto/create-provider-package.dto';
import { CreateProviderServiceDto } from './dto/create-provider-service.dto';
import { CreateQuoteOfferDto } from './dto/create-quote-offer.dto';
import { UpdateProviderPackageDto } from './dto/update-provider-package.dto';
import { UpdateProviderProfileDto } from './dto/update-provider-profile.dto';
import { UpdateProviderQuoteStatusDto } from './dto/update-provider-quote-status.dto';
import { UpdateProviderServiceDto } from './dto/update-provider-service.dto';
import { UpdateQuoteOfferDto } from './dto/update-quote-offer.dto';
import { WithdrawQuoteOfferDto } from './dto/withdraw-quote-offer.dto';
import {
  CreateServiceImageDto,
  UpdateServiceImageDto,
} from './dto/upsert-service-image.dto';
import { assertProviderOperational } from '../modules/marketplace/public/provider-access-policy';
import { noticeRoutes } from '../shared-kernel/routes/notification-routes';
import {
  ownerReviewReply,
  reviewAlreadyReplied,
  reviewNotFound,
} from '../modules/marketplace/public/review-reply';
import { reviewRepliedNotification } from '../marketplace/review-notifications';
import { ReplyToReviewDto } from './dto/reply-to-review.dto';
import {
  currentProviderReviewNotes,
  isProviderAwaitingApproval,
  JOINING_SERVICE_CURRENCY,
  joiningCurrencyRequired,
  providerServiceRequired,
  toProviderLatestDecision,
  type ProviderReviewDecisionView,
} from '../modules/marketplace/public/provider-review';
import {
  findLatestProviderDecision,
  hasJoiningService,
  recordProviderReviewEvent,
} from '../modules/marketplace/infrastructure/provider-review.repository';
import { claimPhoneSpellings } from '../modules/marketplace/public/provider-claim-phone';
import type { FeaturedWindow } from '../modules/marketplace/public/featured-placement';
import { findProviderFeaturedView } from '../modules/marketplace/infrastructure/featured-period.repository';
import { ResubmitApplicationDto } from './dto/resubmit-application.dto';
import {
  lockOwnedProviderAfterUsersInTransaction,
  lockOwnedProviderForMutationInTransaction,
  lockProviderMutationUsersInTransaction,
} from './provider-mutation-locks';
import * as dashboardStore from '../modules/marketplace/infrastructure/provider-dashboard.repository';

type ProviderProfile = Provider & {
  city: City;
  primaryCategory?: ProviderCategory | null;
  /** The latest administrator decision, whose notes the profile shows (B-01). */
  latestDecision:
    | (ProviderReviewDecisionView & { id: string; createdAt: Date })
    | null;
  /** His featured placement now, else the next one booked (B-43). */
  featuredPeriod: FeaturedWindow | null;
};
type ProviderDashboardServiceRecord = ProviderService & {
  category: ProviderCategory;
  city: City | null;
  images: ProviderServiceImage[];
};
type ProviderPackageRecord = ProviderPackage & {
  service: ProviderService | null;
};
type ProviderQuoteRecord = QuoteRequest & {
  user: Pick<User, 'id' | 'name' | 'appName' | 'phone' | 'role'>;
  service?: (ProviderService & { category: ProviderCategory }) | null;
  weddingPlan?: Pick<
    WeddingPlan,
    'id' | 'title' | 'city' | 'weddingDate' | 'currency'
  > | null;
  offers?: QuoteOffer[];
  booking?: Booking | null;
  bookingMoney?: ProviderBookingMoney | null;
};
type ProviderReviewRecord = ProviderReview & {
  user: Pick<User, 'id' | 'name' | 'appName' | 'role'>;
};

@Injectable()
export class ProviderDashboardService {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(NOTIFICATIONS_PORT)
    private readonly notifications: NotificationsPort,
    @Inject(MEDIA_STORAGE_PORT)
    private readonly mediaStorage: MediaStoragePort,
    @Inject(CONVERSATION_LIFECYCLE_PORT)
    private readonly lifecycle: ConversationLifecyclePort,
    @Inject(CATALOG_READ_PORT)
    private readonly catalog: CatalogReadPort,
    @Inject(PROVIDER_ACCOUNT_PORT)
    private readonly providerAccount: ProviderAccountPort,
    private readonly relations: MarketplaceRelationsService,
  ) {}

  async apply(currentUser: AuthenticatedUser, dto: ApplyProviderDto) {
    const categoryIds = [...new Set(dto.categoryIds ?? [])];
    const primaryCategoryId = categoryIds[0];
    if (!primaryCategoryId) {
      throw new BadRequestException('categoryIds must name the category');
    }
    const businessName = this.requiredText(dto.businessName, 'businessName');
    const phone = PhoneNormalizer.normalizeRequired(dto.phone);
    const description = this.optionalText(dto.description);
    const services = this.joiningServices(dto.services);

    const provider = await runSerializableTransaction(this.prisma, async (tx) => {
      // The applicant's lifecycle row is identity's: locked for update there.
      const [actor] = await lockUserLifecycleRowsForUpdateInTransaction(tx, [
        currentUser.id,
      ]);
      if (!actor || actor.status !== UserStatus.ACTIVE) {
        throw new NotFoundException('User not found');
      }

      const existingProviders = await dashboardStore.lockExistingApplication(tx, currentUser.id);
      if (existingProviders.length > 0) {
        throw new ConflictException(
          'Provider profile already exists for this user',
        );
      }
      // A listing already waits under this phone (V1 checklist 4.18): claim
      // it rather than apply for a second provider with the same phone.
      if (
        currentUser.phone &&
        (await dashboardStore.findUnclaimedListing(
          tx,
          PhoneNormalizer.lookupVariants(currentUser.phone),
        ))
      ) {
        throw new ConflictException({
          statusCode: 409,
          code: 'PROVIDER_LISTING_CLAIMABLE',
          message: 'A provider listing already exists for this phone; claim it',
        });
      }

      await this.lockActiveCategoriesInTransaction(tx, categoryIds);
      await this.lockActiveCityInTransaction(tx, dto.cityId);

      // Eligibility and the role change are identity's decision.
      if (
        !(await this.providerAccount.promoteToProviderInTransaction(
          tx,
          currentUser.id,
        ))
      ) {
        throw new ConflictException(
          'The application identity is not eligible for a provider account',
        );
      }

      const created = await dashboardStore.createProviderApplication(tx, {
          userId: currentUser.id,
          cityId: dto.cityId,
          primaryCategoryId,
          businessName,
          phone,
          description,
          services,
      });

      return this.withProviderCatalog(tx, created);
    });

    return this.toProviderProfileResponse(provider);
  }

  /**
   * The services the provider joins with (B-10, D41): at least one, each
   * with a price above zero, before the review sees the profile.
   */
  private joiningServices(
    services: ApplyProviderDto['services'],
  ): dashboardStore.JoiningServiceFields[] {
    const priced = (services ?? []).map((service) => ({
      title: this.requiredText(service.title, 'title'),
      description: this.optionalText(service.description),
      basePrice: this.joiningPrice(service.basePrice),
      currency: this.joiningCurrency(service.currency),
    }));
    if (priced.length === 0) throw providerServiceRequired();
    return priced;
  }

  /** A joining service's price: above zero (B-10). */
  private joiningPrice(value: string | null | undefined): string {
    const basePrice = optionalMoneyAmount(value, 'basePrice');
    if (basePrice === null || Number(basePrice) <= 0) {
      throw providerServiceRequired();
    }
    return basePrice;
  }

  /** A joining service is priced in YER (D48); left out, it is YER. */
  private joiningCurrency(value: string | null | undefined): string {
    const currency = value?.trim().toUpperCase() || JOINING_SERVICE_CURRENCY;
    if (currency !== JOINING_SERVICE_CURRENCY) throw joiningCurrencyRequired();
    return currency;
  }

  private joiningServiceOnly(): ForbiddenException {
    return new ForbiddenException({
      statusCode: 403,
      code: 'PROVIDER_JOINING_SERVICE_ONLY',
      message:
        'Before approval only the joining service’s name, price and description can change',
    });
  }

  /**
   * The listing the back office made under this account's phone and nobody
   * claimed yet (V1 checklist 4.18). Every session's phone is verified by
   * OTP, so the phone is the proof of ownership.
   */
  async findClaimableListing(currentUser: AuthenticatedUser) {
    if (!currentUser.phone) return { listing: null };
    if (await dashboardStore.findProviderByUserId(this.prisma, currentUser.id)) {
      return { listing: null };
    }
    const found = await dashboardStore.findUnclaimedListing(
      this.prisma,
      PhoneNormalizer.lookupVariants(currentUser.phone),
    );
    if (!found) return { listing: null };
    // p02 names the listing's category and city («تصوير · صنعاء»).
    const [listing] = await this.relations.attachProviderCatalog(this.prisma, [found]);
    return {
      listing: {
        id: listing.id,
        businessName: listing.businessName,
        city: { id: listing.city.id, nameAr: listing.city.nameAr },
        primaryCategory: listing.primaryCategory
          ? { id: listing.primaryCategory.id, nameAr: listing.primaryCategory.nameAr }
          : null,
      },
    };
  }

  /**
   * Asks to take that listing over (B-12, D41). The phone proves the
   * account may ask; the listing becomes the account's only when an
   * administrator approves, and until then it stays unclaimed and takes no
   * requests (PROVIDER_NOT_CLAIMED).
   */
  async claimListing(currentUser: AuthenticatedUser, providerId: string) {
    const phones = claimPhoneSpellings(currentUser.phone);
    const claim = await runSerializableTransaction(this.prisma, async (tx) => {
      const [actor] = await lockUserLifecycleRowsForUpdateInTransaction(tx, [
        currentUser.id,
      ]);
      if (!actor || actor.status !== UserStatus.ACTIVE) {
        throw new NotFoundException('User not found');
      }
      if ((await dashboardStore.lockExistingApplication(tx, currentUser.id)).length > 0) {
        throw new ConflictException('Provider profile already exists for this user');
      }
      const listing = await lockMarketplaceProvider(tx, providerId, 'UPDATE');
      const claimable = await dashboardStore.findUnclaimedListing(tx, phones);
      // Not this account's to claim: reads as missing, revealing nothing.
      if (
        listing.userId !== null ||
        listing.status !== ProviderStatus.ACTIVE ||
        claimable?.id !== listing.id
      ) {
        throw new NotFoundException('Provider listing not found');
      }
      const open =
        (await dashboardStore.findPendingClaim(tx, { providerId: listing.id })) ??
        (await dashboardStore.findPendingClaim(tx, { userId: currentUser.id }));
      if (open) {
        throw new ConflictException({
          statusCode: 409,
          code: 'PROVIDER_CLAIM_PENDING',
          message: 'A claim of this listing is already waiting for review',
          claimRequestId: open.userId === currentUser.id ? open.id : undefined,
        });
      }
      return dashboardStore.createClaimRequest(tx, listing.id, currentUser.id);
    });
    return this.toClaimResponse(claim);
  }

  /** The account's latest claim of a listing and what came of it (B-12). */
  async getClaim(currentUser: AuthenticatedUser) {
    const claim = await dashboardStore.findLatestClaim(this.prisma, currentUser.id);
    return { claim: claim ? this.toClaimResponse(claim) : null };
  }

  /**
   * «أرسلت التعديل» (B-01): the provider sends the fixed profile back to
   * review. Only from NEEDS_CHANGES, with a priced service (B-10), and only
   * after the notes he read: the request names the latest decision he saw,
   * and a newer one (the team rewrote its notes meanwhile) is refused so he
   * reads it first.
   */
  async resubmitApplication(
    currentUser: AuthenticatedUser,
    dto: ResubmitApplicationDto,
  ) {
    const updated = await runSerializableTransaction(this.prisma, async (tx) => {
      const provider = await lockOwnedProviderForMutationInTransaction(
        tx,
        currentUser.id,
        'LIFECYCLE',
        'UPDATE',
      );
      if (provider.status !== ProviderStatus.NEEDS_CHANGES) {
        throw new ConflictException({
          statusCode: 409,
          code: 'PROVIDER_NOT_AWAITING_CHANGES',
          message: 'Only a profile waiting for changes can be sent back to review',
          currentStatus: provider.status,
        });
      }
      // Every decision is written under the provider's row lock held here,
      // so the latest one cannot change before this transaction ends.
      const latest = await findLatestProviderDecision(tx, provider.id);
      if ((latest?.id ?? null) !== dto.latestDecisionId) {
        throw new ConflictException({
          statusCode: 409,
          code: 'PROVIDER_REVIEW_CHANGED',
          message: 'The review team changed its notes; read them before sending',
          latestDecisionId: latest?.id ?? null,
        });
      }
      if (!(await hasJoiningService(tx, provider.id))) {
        throw providerServiceRequired();
      }
      const at = new Date();
      const resubmitted = await dashboardStore.markProviderResubmitted(
        tx,
        provider.id,
        at,
      );
      await recordProviderReviewEvent(tx, {
        providerId: provider.id,
        kind: ProviderReviewEventKind.RESUBMITTED,
        actorId: currentUser.id,
        createdAt: at,
      });
      await this.notifications.createNotificationInTransaction(tx, {
        userId: currentUser.id,
        type: NotificationType.PROVIDER_IN_REVIEW,
        priority: NotificationPriority.NORMAL,
        title: 'وصلنا تعديلك',
        body: `نراجع ملف ${resubmitted.businessName} من جديد ونبلغك هنا.`,
        entityType: 'Provider',
        entityId: provider.id,
        routeTarget: noticeRoutes.providerPortal(),
        data: { providerId: provider.id, providerStatus: ProviderStatus.PENDING },
        dedupeKey: `provider-resubmitted:${provider.id}:${at.toISOString()}`,
      });
      return this.withProviderCatalog(tx, resubmitted);
    });
    return this.toProviderProfileResponse(updated);
  }

  /**
   * «صلّح وقدّم من جديد» (B-02): a refused provider reopens the profile to
   * fix it. The refusal's reason stays the note he reads, and the fixed
   * profile goes back to review by resubmitting (B-01).
   */
  async reopenApplication(currentUser: AuthenticatedUser) {
    const updated = await runSerializableTransaction(this.prisma, async (tx) => {
      const provider = await lockOwnedProviderForMutationInTransaction(
        tx,
        currentUser.id,
        'LIFECYCLE',
        'UPDATE',
      );
      if (provider.status !== ProviderStatus.REJECTED) {
        throw new ConflictException({
          statusCode: 409,
          code: 'PROVIDER_NOT_REJECTED',
          message: 'Only a refused profile can be reopened',
          currentStatus: provider.status,
        });
      }
      const at = new Date();
      const reopened = await dashboardStore.markProviderReopened(tx, provider.id, at);
      await recordProviderReviewEvent(tx, {
        providerId: provider.id,
        kind: ProviderReviewEventKind.REOPENED,
        actorId: currentUser.id,
        createdAt: at,
      });
      return this.withProviderCatalog(tx, reopened);
    });
    return this.toProviderProfileResponse(updated);
  }

  private toClaimResponse(claim: {
    id: string;
    status: ProviderClaimStatus;
    note: string | null;
    createdAt: Date;
    decidedAt: Date | null;
    provider: { id: string; businessName: string };
  }) {
    return {
      id: claim.id,
      status: claim.status,
      note: claim.note,
      createdAt: claim.createdAt,
      decidedAt: claim.decidedAt,
      provider: { id: claim.provider.id, businessName: claim.provider.businessName },
    };
  }

  async getProfile(currentUser: AuthenticatedUser) {
    const provider = await this.findOwnedProviderProfileOrThrow(currentUser.id);
    return this.toProviderProfileResponse(provider);
  }

  async updateProfile(
    currentUser: AuthenticatedUser,
    dto: UpdateProviderProfileDto,
  ) {
    const logoUrl =
      dto.logoUrl !== undefined
        ? await this.mediaStorage.verifyPublicMediaUrl(
            currentUser,
            dto.logoUrl,
            'provider-logo',
          )
        : undefined;
    const coverUrl =
      dto.coverUrl !== undefined
        ? await this.mediaStorage.verifyPublicMediaUrl(
            currentUser,
            dto.coverUrl,
            'provider-cover',
          )
        : undefined;

    const updated = await runSerializableTransaction(this.prisma, async (tx) => {
      const provider = await lockOwnedProviderForMutationInTransaction(
        tx,
        currentUser.id,
        'PROFILE',
        'UPDATE',
      );
      if (dto.cityId !== undefined) {
        await this.lockActiveCityInTransaction(tx, dto.cityId);
      }
      const categoryChanged =
        dto.primaryCategoryId !== undefined &&
        dto.primaryCategoryId !== provider.primaryCategoryId;
      if (categoryChanged) {
        if (!isProviderAwaitingApproval(provider)) {
          throw new ConflictException({
            statusCode: 409,
            code: 'PROVIDER_CATEGORY_LOCKED',
            message: 'The category changes only before approval',
          });
        }
        await this.lockActiveCategoryInTransaction(tx, dto.primaryCategoryId!);
        await dashboardStore.moveJoiningServicesToCategory(
          tx,
          provider.id,
          dto.primaryCategoryId!,
        );
      }

      const logoChanged =
        dto.logoUrl !== undefined && logoUrl !== provider.logoUrl;
      const coverChanged =
        dto.coverUrl !== undefined && coverUrl !== provider.coverUrl;
      if (logoChanged) {
        await this.mediaStorage.scheduleTargetDeletion(
          { type: 'PROVIDER_LOGO', id: provider.id },
          tx,
        );
        if (logoUrl) {
          await this.mediaStorage.consumePublicMediaUrl(
            currentUser,
            logoUrl,
            'provider-logo',
            { type: 'PROVIDER_LOGO', id: provider.id },
            tx,
          );
        }
      }
      if (coverChanged) {
        await this.mediaStorage.scheduleTargetDeletion(
          { type: 'PROVIDER_COVER', id: provider.id },
          tx,
        );
        if (coverUrl) {
          await this.mediaStorage.consumePublicMediaUrl(
            currentUser,
            coverUrl,
            'provider-cover',
            { type: 'PROVIDER_COVER', id: provider.id },
            tx,
          );
        }
      }
      return this.withProviderCatalog(
        tx,
        await dashboardStore.updateProviderProfile(tx, provider.id, {
        ...(dto.businessName !== undefined
          ? { businessName: this.requiredText(dto.businessName, 'businessName') }
          : {}),
        ...(dto.ownerName !== undefined
          ? { ownerName: this.optionalText(dto.ownerName) }
          : {}),
        ...(dto.phone !== undefined
          ? { phone: PhoneNormalizer.normalizeRequired(dto.phone) }
          : {}),
        ...(dto.whatsapp !== undefined
          ? {
              whatsapp: PhoneNormalizer.normalizeOptional(
                dto.whatsapp,
                'whatsapp',
              ),
            }
          : {}),
        ...(dto.email !== undefined ? { email: this.optionalText(dto.email) } : {}),
        ...(dto.description !== undefined
          ? { description: this.optionalText(dto.description) }
          : {}),
        ...(dto.address !== undefined
          ? { address: this.optionalText(dto.address) }
          : {}),
        ...(dto.cityId !== undefined ? { cityId: dto.cityId } : {}),
        ...(categoryChanged ? { primaryCategoryId: dto.primaryCategoryId } : {}),
        ...(dto.latitude !== undefined
          ? { latitude: this.optionalSignedDecimal(dto.latitude, 'latitude') }
          : {}),
        ...(dto.longitude !== undefined
          ? { longitude: this.optionalSignedDecimal(dto.longitude, 'longitude') }
          : {}),
        ...(dto.logoUrl !== undefined ? { logoUrl } : {}),
        ...(dto.coverUrl !== undefined ? { coverUrl } : {}),
        ...(dto.dailyBookingCapacity !== undefined
          ? { dailyBookingCapacity: this.dailyCapacity(dto.dailyBookingCapacity) }
          : {}),
        }),
      );
    });

    return this.toProviderProfileResponse(updated);
  }

  async getSummary(currentUser: AuthenticatedUser) {
    const provider = await this.findActiveOwnedProviderOrThrow(currentUser.id);
    const [
      servicesCount,
      activeServicesCount,
      quoteRequestsCount,
      newQuoteRequestsCount,
    ] = await dashboardStore.countProviderDashboard(this.prisma, provider.id);
    const today = bookingToday();
    const [views, ...activity] = await dashboardStore.providerActivity(
      this.prisma,
      provider.id,
      providerStatsWindowStart(today),
      today,
    );

    return {
      servicesCount,
      activeServicesCount,
      quoteRequestsCount,
      newQuoteRequestsCount,
      averageRating: provider.ratingAverage.toString(),
      ratingCount: provider.ratingCount,
      stats: toProviderStats(views._sum.views, ...activity),
    };
  }

  /** His services; before approval, the one he joined with (B-10). */
  async findServices(currentUser: AuthenticatedUser) {
    const provider = await this.findServiceOwnerOrThrow(currentUser.id);
    const services = await this.relations.attachServiceCatalog(
      this.prisma,
      await dashboardStore.listOwnedServices(this.prisma, provider.id),
    );

    return services.map((service) => this.toServiceResponse(service));
  }

  async createService(
    currentUser: AuthenticatedUser,
    dto: CreateProviderServiceDto,
  ) {
    const basePrice = optionalMoneyAmount(dto.basePrice, 'basePrice');
    const service = await runSerializableTransaction(this.prisma, async (tx) => {
      const provider = await lockOwnedProviderForMutationInTransaction(
        tx,
        currentUser.id,
        'JOINING_SERVICE',
        'UPDATE',
      );
      const joining = isProviderAwaitingApproval(provider);
      if (joining) {
        // Before approval he joins with one priced service in his category,
        // its name, price and words, in YER; the others come after approval
        // (B-10, D41, D48). He adds it while he has no active priced
        // service: a profile that applied before B-10, or whose service the
        // team switched off.
        if (await hasJoiningService(tx, provider.id)) {
          throw this.joiningServiceOnly();
        }
        if (dto.priceUnit !== undefined || dto.cityId !== undefined) {
          throw this.joiningServiceOnly();
        }
        if (dto.categoryId !== provider.primaryCategoryId) {
          throw new BadRequestException(
            'categoryId must be the profile category before approval',
          );
        }
        this.joiningPrice(dto.basePrice);
      }
      const currency = joining
        ? this.joiningCurrency(dto.currency)
        : (this.optionalText(dto.currency) ?? 'YER');
      await this.lockActiveCategoryInTransaction(tx, dto.categoryId);
      if (dto.cityId) {
        await this.lockActiveCityInTransaction(tx, dto.cityId);
      }

      return this.withServiceCatalog(
        tx,
        await dashboardStore.createProviderService(tx, {
            providerId: provider.id,
            categoryId: dto.categoryId,
            title: this.requiredText(dto.title, 'title'),
            description: this.optionalText(dto.description),
            basePrice,
            priceUnit: this.optionalText(dto.priceUnit),
            currency,
            cityId: this.optionalText(dto.cityId),
        }),
      );
    });

    return this.toServiceResponse(service);
  }

  async findService(currentUser: AuthenticatedUser, id: string) {
    const service = await this.findOwnedServiceOrThrow(currentUser.id, id);
    return this.toServiceResponse(service);
  }

  async updateService(
    currentUser: AuthenticatedUser,
    id: string,
    dto: UpdateProviderServiceDto,
  ) {
    this.assertUuid(id, 'serviceId');
    const basePrice =
      dto.basePrice !== undefined
        ? optionalMoneyAmount(dto.basePrice, 'basePrice')
        : undefined;
    const service = await runSerializableTransaction(this.prisma, async (tx) => {
      const provider = await lockOwnedProviderForMutationInTransaction(
        tx,
        currentUser.id,
        'JOINING_SERVICE',
      );
      const joining = isProviderAwaitingApproval(provider);
      if (joining) {
        // Before approval only the joining service's name, price and words
        // change (B-10); its category follows the profile's and its price
        // stays in YER (D48).
        if (
          dto.categoryId !== undefined ||
          dto.cityId !== undefined ||
          dto.isActive !== undefined ||
          dto.priceUnit !== undefined
        ) {
          throw this.joiningServiceOnly();
        }
        if (dto.basePrice !== undefined) this.joiningPrice(dto.basePrice);
      }
      const currency =
        dto.currency === undefined
          ? undefined
          : joining
            ? this.joiningCurrency(dto.currency)
            : this.requiredText(dto.currency, 'currency');
      if (dto.categoryId !== undefined) {
        await this.lockActiveCategoryInTransaction(tx, dto.categoryId);
      }
      if (dto.cityId) {
        await this.lockActiveCityInTransaction(tx, dto.cityId);
      }
      await this.lockOwnedServiceInTransaction(tx, provider.id, id, 'UPDATE');

      return this.withServiceCatalog(
        tx,
        await dashboardStore.updateProviderService(tx, id, {
          ...(dto.categoryId !== undefined ? { categoryId: dto.categoryId } : {}),
          ...(dto.title !== undefined
            ? { title: this.requiredText(dto.title, 'title') }
            : {}),
          ...(dto.description !== undefined
            ? { description: this.optionalText(dto.description) }
            : {}),
          ...(dto.basePrice !== undefined
            ? { basePrice }
            : {}),
          ...(dto.priceUnit !== undefined
            ? { priceUnit: this.optionalText(dto.priceUnit) }
            : {}),
          ...(currency !== undefined ? { currency } : {}),
          ...(dto.cityId !== undefined
            ? { cityId: this.optionalText(dto.cityId) }
            : {}),
          ...(dto.isActive !== undefined ? { isActive: dto.isActive } : {}),
        }),
      );
    });

    return this.toServiceResponse(service);
  }

  async deactivateService(currentUser: AuthenticatedUser, id: string) {
    this.assertUuid(id, 'serviceId');
    const service = await runSerializableTransaction(this.prisma, async (tx) => {
      const provider = await lockOwnedProviderForMutationInTransaction(
        tx,
        currentUser.id,
        'OPERATIONAL',
      );
      await this.lockOwnedServiceInTransaction(tx, provider.id, id, 'UPDATE');
      return this.withServiceCatalog(
        tx,
        await dashboardStore.deactivateProviderService(tx, id),
      );
    });

    return this.toServiceResponse(service);
  }

  async createServiceImage(
    currentUser: AuthenticatedUser,
    serviceId: string,
    dto: CreateServiceImageDto,
  ) {
    this.assertUuid(serviceId, 'serviceId');
    const imageUrl = await this.mediaStorage.verifyPublicMediaUrl(
      currentUser,
      dto.imageUrl,
      'service-image',
    );
    if (!imageUrl) throw new BadRequestException('imageUrl is required');
    const image = await runSerializableTransaction(this.prisma, async (tx) => {
      const provider = await lockOwnedProviderForMutationInTransaction(
        tx,
        currentUser.id,
        'OPERATIONAL',
      );
      await this.lockOwnedServiceInTransaction(
        tx,
        provider.id,
        serviceId,
        'SHARE',
      );
      const created = await dashboardStore.createServiceImage(tx, {
          serviceId,
          imageUrl,
          altText: this.optionalText(dto.altText),
          sortOrder: dto.sortOrder ?? 0,
      });
      await this.mediaStorage.consumePublicMediaUrl(
        currentUser,
        imageUrl,
        'service-image',
        { type: 'SERVICE_IMAGE', id: created.id },
        tx,
      );
      return created;
    });

    return this.toImageResponse(image);
  }

  async updateServiceImage(
    currentUser: AuthenticatedUser,
    serviceId: string,
    imageId: string,
    dto: UpdateServiceImageDto,
  ) {
    this.assertUuid(serviceId, 'serviceId');
    this.assertUuid(imageId, 'imageId');
    const imageUrl =
      dto.imageUrl !== undefined
        ? await this.mediaStorage.verifyPublicMediaUrl(
            currentUser,
            dto.imageUrl,
            'service-image',
          )
        : undefined;
    if (dto.imageUrl !== undefined && !imageUrl) {
      throw new BadRequestException('imageUrl is required');
    }

    const image = await runSerializableTransaction(this.prisma, async (tx) => {
      const provider = await lockOwnedProviderForMutationInTransaction(
        tx,
        currentUser.id,
        'OPERATIONAL',
      );
      await this.lockOwnedServiceInTransaction(
        tx,
        provider.id,
        serviceId,
        'SHARE',
      );
      const existing = await this.lockOwnedServiceImageInTransaction(
        tx,
        serviceId,
        imageId,
      );
      const imageChanged =
        dto.imageUrl !== undefined && imageUrl !== existing.imageUrl;
      if (imageChanged) {
        await this.mediaStorage.scheduleTargetDeletion(
          { type: 'SERVICE_IMAGE', id: imageId },
          tx,
        );
        await this.mediaStorage.consumePublicMediaUrl(
          currentUser,
          imageUrl!,
          'service-image',
          { type: 'SERVICE_IMAGE', id: imageId },
          tx,
        );
      }
      return dashboardStore.updateServiceImage(tx, imageId, {
          ...(dto.imageUrl !== undefined ? { imageUrl: imageUrl! } : {}),
          ...(dto.altText !== undefined
            ? { altText: this.optionalText(dto.altText) }
            : {}),
          ...(dto.sortOrder !== undefined ? { sortOrder: dto.sortOrder } : {}),
      });
    });

    return this.toImageResponse(image);
  }

  async deleteServiceImage(
    currentUser: AuthenticatedUser,
    serviceId: string,
    imageId: string,
  ) {
    this.assertUuid(serviceId, 'serviceId');
    this.assertUuid(imageId, 'imageId');
    await runSerializableTransaction(this.prisma, async (tx) => {
      const provider = await lockOwnedProviderForMutationInTransaction(
        tx,
        currentUser.id,
        'OPERATIONAL',
      );
      await this.lockOwnedServiceInTransaction(
        tx,
        provider.id,
        serviceId,
        'SHARE',
      );
      await this.lockOwnedServiceImageInTransaction(tx, serviceId, imageId);
      await this.mediaStorage.scheduleTargetDeletion(
        { type: 'SERVICE_IMAGE', id: imageId },
        tx,
      );
      await dashboardStore.deleteServiceImage(tx, imageId);
    });

    return { id: imageId, deleted: true };
  }

  async findPackages(currentUser: AuthenticatedUser) {
    const provider = await this.findActiveOwnedProviderOrThrow(currentUser.id);
    const packages = await dashboardStore.listOwnedPackages(this.prisma, provider.id);

    return packages.map((providerPackage) =>
      this.toPackageResponse(providerPackage),
    );
  }

  async createPackage(
    currentUser: AuthenticatedUser,
    dto: CreateProviderPackageDto,
  ) {
    if (dto.serviceId) this.assertUuid(dto.serviceId, 'serviceId');
    const price = optionalMoneyAmount(dto.price, 'price');
    const providerPackage = await runSerializableTransaction(
      this.prisma,
      async (tx) => {
        const provider = await lockOwnedProviderForMutationInTransaction(
          tx,
          currentUser.id,
          'OPERATIONAL',
        );
        if (dto.serviceId) {
          await this.lockOwnedServiceInTransaction(
            tx,
            provider.id,
            dto.serviceId,
            'SHARE',
          );
        }

        return dashboardStore.createProviderPackage(tx, {
            providerId: provider.id,
            serviceId: this.optionalText(dto.serviceId),
            title: this.requiredText(dto.title, 'title'),
            description: this.optionalText(dto.description),
            price,
            currency: this.optionalText(dto.currency) ?? 'YER',
            ...(dto.items !== undefined
              ? { items: dto.items as Prisma.InputJsonValue }
              : {}),
        });
      },
    );

    return this.toPackageResponse(providerPackage);
  }

  async updatePackage(
    currentUser: AuthenticatedUser,
    id: string,
    dto: UpdateProviderPackageDto,
  ) {
    this.assertUuid(id, 'packageId');
    if (dto.serviceId) this.assertUuid(dto.serviceId, 'serviceId');
    const price =
      dto.price !== undefined
        ? optionalMoneyAmount(dto.price, 'price')
        : undefined;
    const providerPackage = await runSerializableTransaction(
      this.prisma,
      async (tx) => {
        const provider = await lockOwnedProviderForMutationInTransaction(
          tx,
          currentUser.id,
          'OPERATIONAL',
        );
        if (dto.serviceId) {
          await this.lockOwnedServiceInTransaction(
            tx,
            provider.id,
            dto.serviceId,
            'SHARE',
          );
        }
        await this.lockOwnedPackageInTransaction(tx, provider.id, id);

        return dashboardStore.updateProviderPackage(tx, id, {
            ...(dto.serviceId !== undefined
              ? { serviceId: this.optionalText(dto.serviceId) }
              : {}),
            ...(dto.title !== undefined
              ? { title: this.requiredText(dto.title, 'title') }
              : {}),
            ...(dto.description !== undefined
              ? { description: this.optionalText(dto.description) }
              : {}),
          ...(dto.price !== undefined
              ? { price }
              : {}),
            ...(dto.currency !== undefined
              ? { currency: this.requiredText(dto.currency, 'currency') }
              : {}),
            ...(dto.items !== undefined
              ? { items: dto.items as Prisma.InputJsonValue }
              : {}),
            ...(dto.isActive !== undefined ? { isActive: dto.isActive } : {}),
        });
      },
    );

    return this.toPackageResponse(providerPackage);
  }

  async deactivatePackage(currentUser: AuthenticatedUser, id: string) {
    this.assertUuid(id, 'packageId');
    const providerPackage = await runSerializableTransaction(
      this.prisma,
      async (tx) => {
        const provider = await lockOwnedProviderForMutationInTransaction(
          tx,
          currentUser.id,
          'OPERATIONAL',
        );
        await this.lockOwnedPackageInTransaction(tx, provider.id, id);
        return dashboardStore.deactivateProviderPackage(tx, id);
      },
    );

    return this.toPackageResponse(providerPackage);
  }

  async findQuoteRequests(currentUser: AuthenticatedUser) {
    const provider = await this.findActiveOwnedProviderOrThrow(currentUser.id);
    const quotes = await this.relations.attachDashboardQuoteRelations(
      this.prisma,
      await dashboardStore.listProviderQuoteRequests(this.prisma, provider.id),
    );

    return quotes.map((quote) => this.toQuoteResponse(quote));
  }

  async findQuoteRequest(currentUser: AuthenticatedUser, id: string) {
    const provider = await this.findActiveOwnedProviderOrThrow(currentUser.id);
    this.assertUuid(id, 'quoteRequestId');
    const quoteRow = await dashboardStore.findProviderQuoteRequest(this.prisma, id, provider.id);

    if (!quoteRow) {
      throw new NotFoundException('Quote request not found');
    }
    const [quote] = await this.relations.attachDashboardQuoteRelations(
      this.prisma,
      [quoteRow],
    );

    return this.toQuoteResponse(quote);
  }

  async updateQuoteRequestStatus(
    currentUser: AuthenticatedUser,
    id: string,
    dto: UpdateProviderQuoteStatusDto,
  ) {
    this.assertUuid(id, 'quoteRequestId');
    const quote = await runSerializableTransaction(this.prisma, async (tx) => {
      const seed = await dashboardStore.findProviderQuoteMutationSeed(tx, id);
      if (!seed) {
        throw new NotFoundException('Quote request not found');
      }
      const provider = await this.lockQuoteMutationContext(
        tx,
        currentUser.id,
        seed,
      );
      if (!(await lockQuoteRequestTransitionRow(tx, this.lifecycle, id))) {
        throw new NotFoundException('Quote request not found');
      }
      const existing = await dashboardStore.findLockedProviderQuoteRequest(tx, id, provider.id);
      if (!existing) {
        throw new NotFoundException('Quote request not found');
      }
      await this.assertQuotePlanWritable(tx, existing.weddingPlanId);
      assertQuoteRequestTransition(existing.status, dto.status, 'provider');
      if (dto.status === QuoteRequestStatus.REJECTED) {
        assertQuoteRequestAnswerable(existing);
      }

      const transition = await dashboardStore.transitionProviderQuoteRequest(
        tx, id, existing.status, dto.status,
        dto.status === QuoteRequestStatus.REJECTED ? new Date() : undefined,
      );
      if (transition.count !== 1) {
        throw new ConflictException('Quote request status changed');
      }
      const [updated] = await this.relations.attachDashboardQuoteRelations(
        tx,
        [
          await dashboardStore.requireProviderQuoteRequest(tx, id),
        ],
      );
      if (dto.status === QuoteRequestStatus.REJECTED) {
        await this.lifecycle.recordConversationEvent(tx, {
          conversationId: existing.conversationId,
          quoteRequestId: existing.id,
          actorUserId: currentUser.id,
          type: ConversationEventType.QUOTE_REQUEST_REJECTED,
          dedupeKey: `quote-request:${existing.id}:rejected`,
          data: { status: QuoteRequestStatus.REJECTED },
        });
        const recipientId =
          await this.notifications.resolveProviderUpdateRecipientInTransaction(
            tx,
            existing.weddingPlanId,
            existing.userId,
          );
        await this.notifications.createNotificationInTransaction(
          tx,
          providerRejectedRequestNotification({
            requesterId: recipientId,
            weddingPlanId: existing.weddingPlanId,
            quoteRequestId: existing.id,
            providerId: provider.id,
            providerName: provider.businessName,
          }),
        );
      }
      return updated;
    });

    return this.toQuoteResponse(quote);
  }

  async createQuoteOffer(
    currentUser: AuthenticatedUser,
    quoteRequestId: string,
    dto: CreateQuoteOfferDto,
  ) {
    this.assertUuid(quoteRequestId, 'quoteRequestId');
    const amount = this.requiredPositiveMoneyAmount(dto.amount, 'amount');
    const offer = await runSerializableTransaction(this.prisma, async (tx) => {
      const seed = await dashboardStore.findProviderQuoteMutationSeed(tx, quoteRequestId);
      if (!seed) {
        throw new NotFoundException('Quote request not found');
      }
      const provider = await this.lockQuoteMutationContext(
        tx,
        currentUser.id,
        seed,
      );
      if (!(await lockQuoteRequestTransitionRow(tx, this.lifecycle, quoteRequestId))) {
        throw new NotFoundException('Quote request not found');
      }
      const quote = await dashboardStore.findLockedProviderQuoteRequest(
        tx, quoteRequestId, provider.id,
      );
      if (!quote) {
        throw new NotFoundException('Quote request not found');
      }
      const quotePlan = await this.assertQuotePlanWritable(
        tx,
        quote.weddingPlanId,
      );
      assertQuoteRequestTransition(
        quote.status,
        QuoteRequestStatus.RESPONDED,
        'provider_offer',
      );
      assertQuoteRequestAnswerable(quote);
      const existingOffer = await dashboardStore.findExistingQuoteOffer(tx, quoteRequestId);
      if (existingOffer) {
        throw new ConflictException({
          code: 'QUOTE_OFFER_ALREADY_EXISTS',
          message: 'يوجد عرض سعر لهذا الطلب بالفعل.',
          quoteOfferId: existingOffer.id,
        });
      }
      const currency = this.quoteOfferCurrency(
        dto.currency,
        quotePlan?.currency,
      );

      const created = await dashboardStore.createQuoteOffer(tx, {
          quoteRequestId,
          providerId: provider.id,
          title: this.optionalText(dto.title),
          message: this.requiredText(dto.message, 'message'),
          amount,
          currency,
          validUntil: this.optionalDate(dto.validUntil, 'validUntil'),
      });
      // B-06: the offer as sent is its version 1.
      await offerStore.createQuoteOfferVersion(tx, {
        quoteOfferId: created.id,
        versionNo: created.currentVersionNo,
        title: created.title,
        message: created.message,
        amount: created.amount,
        currency: created.currency,
        validUntil: created.validUntil,
        changes: Prisma.DbNull,
      });

      await dashboardStore.markQuoteRequestResponded(tx, quoteRequestId);

      await this.lifecycle.recordConversationEvent(tx, {
        conversationId: quote.conversationId,
        quoteRequestId,
        quoteOfferId: created.id,
        actorUserId: currentUser.id,
        type: ConversationEventType.QUOTE_OFFER_RECEIVED,
        occurredAt: created.createdAt,
        dedupeKey: `quote-offer:${created.id}:received`,
        data: { status: QuoteOfferStatus.PENDING },
      });

      const recipientId =
        await this.notifications.resolveProviderUpdateRecipientInTransaction(
          tx,
          quote.weddingPlanId,
          quote.userId,
        );
      await this.notifications.createNotificationInTransaction(
        tx,
        quoteOfferReceivedNotification({
          requesterId: recipientId,
          weddingPlanId: quote.weddingPlanId,
          quoteRequestId,
          quoteOfferId: created.id,
          providerId: provider.id,
          providerName: provider.businessName,
        }),
      );

      return created;
    });

    return this.toQuoteOfferResponse(offer);
  }

  async updateQuoteOffer(
    currentUser: AuthenticatedUser,
    id: string,
    dto: UpdateQuoteOfferDto,
  ) {
    this.assertUuid(id, 'quoteOfferId');
    const requestedAmount =
      dto.amount !== undefined
        ? this.requiredPositiveMoneyAmount(dto.amount, 'amount')
        : undefined;
    const offer = await runSerializableTransaction(this.prisma, async (tx) => {
      const seed = await dashboardStore.findOfferMutationSeed(tx, id);
      if (!seed) {
        throw new NotFoundException('Quote offer not found');
      }
      const provider = await this.lockQuoteMutationContext(
        tx,
        currentUser.id,
        {
          providerId: seed.providerId,
          userId: seed.quoteRequest.userId,
          weddingPlanId: seed.quoteRequest.weddingPlanId,
          conversationId: seed.quoteRequest.conversationId,
        },
      );
      if (!(await lockQuoteOfferTransitionRows(tx, this.lifecycle, id))) {
        throw new NotFoundException('Quote offer not found');
      }
      const existing = await dashboardStore.findLockedProviderOffer(tx, id, provider.id);
      if (!existing) {
        throw new NotFoundException('Quote offer not found');
      }
      const offerPlan = await this.assertQuotePlanWritable(
        tx,
        existing.quoteRequest.weddingPlanId,
      );
      if (
        existing.status !== QuoteOfferStatus.PENDING ||
        existing.quoteRequest.status !== QuoteRequestStatus.RESPONDED
      ) {
        throw quoteOfferLocked(existing.status);
      }
      const amount =
        requestedAmount ??
        this.requiredPositiveMoneyAmount(
          existing.amount?.toString(),
          'amount',
        );
      const currency = this.quoteOfferCurrency(
        dto.currency ?? existing.currency,
        offerPlan?.currency,
      );
      const next = {
        title:
          dto.title !== undefined ? this.optionalText(dto.title) : existing.title,
        message:
          dto.message !== undefined
            ? this.requiredText(dto.message ?? '', 'message')
            : existing.message,
        amount,
        currency,
        validUntil:
          dto.validUntil !== undefined
            ? this.optionalDate(dto.validUntil, 'validUntil')
            : existing.validUntil,
      };
      // B-06: an edit that changes nothing (a retry) is not a new version.
      const changes = quoteOfferChanges(existing, next);
      if (changes.length === 0) return existing;

      const versionNo = existing.currentVersionNo + 1;
      const revisedAt = new Date();
      const tellCustomer = isQuoteOfferRevisionNoticeDue(
        existing.revisionNoticeAt,
        revisedAt,
      );
      const revised = await offerStore.reviseQuoteOffer(
        tx,
        id,
        existing.currentVersionNo,
        {
          ...next,
          currentVersionNo: versionNo,
          versionChanges: toQuoteOfferChangesJson(changes),
          revisedAt,
          ...(tellCustomer ? { revisionNoticeAt: revisedAt } : {}),
        },
      );
      if (revised.count !== 1) throw quoteOfferLocked(existing.status);
      await offerStore.createQuoteOfferVersion(tx, {
        quoteOfferId: id,
        versionNo,
        ...next,
        changes: toQuoteOfferChangesJson(changes),
      });
      await this.lifecycle.recordConversationEvent(tx, {
        conversationId: existing.quoteRequest.conversationId,
        quoteRequestId: existing.quoteRequestId,
        quoteOfferId: id,
        actorUserId: currentUser.id,
        type: ConversationEventType.QUOTE_OFFER_REVISED,
        occurredAt: revisedAt,
        dedupeKey: `quote-offer:${id}:revised:${versionNo}`,
        // Only the number: every reader of the plan's conversation reads its
        // events, and «ايش تغيّر» comes from the offer through its
        // money-aware view.
        data: { versionNo },
      });
      // Revisions are told once per offer per ten minutes: a provider fixing
      // his offer several times in a row tells the customer once; the
      // timeline keeps each version.
      if (tellCustomer) {
        const recipientId =
          await this.notifications.resolveProviderUpdateRecipientInTransaction(
            tx,
            existing.quoteRequest.weddingPlanId,
            existing.quoteRequest.userId,
          );
        await this.notifications.createNotificationInTransaction(
          tx,
          quoteOfferRevisedNotification({
            requesterId: recipientId,
            weddingPlanId: existing.quoteRequest.weddingPlanId,
            quoteRequestId: existing.quoteRequestId,
            quoteOfferId: id,
            versionNo,
            providerId: provider.id,
            providerName: provider.businessName,
          }),
        );
      }
      return dashboardStore.requireQuoteOffer(tx, id);
    });

    return this.toQuoteOfferResponse(offer);
  }

  /**
   * B-03: the provider takes back an offer the customer has not decided on.
   * The request waits for him again, with a new seven-day window: he sends
   * a new offer or declines. A retry of a done withdrawal returns it as is.
   */
  async withdrawQuoteOffer(
    currentUser: AuthenticatedUser,
    id: string,
    dto: WithdrawQuoteOfferDto,
  ) {
    this.assertUuid(id, 'quoteOfferId');
    const reason = this.optionalText(dto.reason);
    const quote = await runSerializableTransaction(this.prisma, async (tx) => {
      const seed = await dashboardStore.findOfferMutationSeed(tx, id);
      if (!seed) {
        throw new NotFoundException('Quote offer not found');
      }
      const provider = await this.lockQuoteMutationContext(
        tx,
        currentUser.id,
        {
          providerId: seed.providerId,
          userId: seed.quoteRequest.userId,
          weddingPlanId: seed.quoteRequest.weddingPlanId,
          conversationId: seed.quoteRequest.conversationId,
        },
      );
      if (!(await lockQuoteOfferTransitionRows(tx, this.lifecycle, id))) {
        throw new NotFoundException('Quote offer not found');
      }
      const existing = await dashboardStore.findLockedProviderOffer(tx, id, provider.id);
      if (!existing) {
        throw new NotFoundException('Quote offer not found');
      }
      if (existing.status !== QuoteOfferStatus.WITHDRAWN) {
        await this.assertQuotePlanWritable(tx, existing.quoteRequest.weddingPlanId);
        if (
          existing.status !== QuoteOfferStatus.PENDING ||
          existing.quoteRequest.status !== QuoteRequestStatus.RESPONDED
        ) {
          throw new ConflictException({
            code: 'QUOTE_OFFER_NOT_WITHDRAWABLE',
            message:
              existing.status === QuoteOfferStatus.ACCEPTED
                ? 'العرض انقبل، فما تقدر تسحبه. لو ما تقدر توفي، تكلّم معه في المحادثة.'
                : 'العرض انتهى أمره، فما فيه شي تسحبه.',
          });
        }
        assertQuoteRequestTransition(
          existing.quoteRequest.status,
          QuoteRequestStatus.VIEWED,
          'provider_withdraw',
        );
        const withdrawnAt = new Date();
        const withdrawn = await offerStore.withdrawPendingOffer(tx, id, withdrawnAt, reason);
        const reopened = await offerStore.reopenAnsweredRequest(
          tx,
          existing.quoteRequestId,
          quoteRequestAnswerDeadline(withdrawnAt),
        );
        if (withdrawn.count !== 1 || reopened.count !== 1) {
          throw new ConflictException('Quote offer changed concurrently; retry the request');
        }
        await this.lifecycle.recordConversationEvent(tx, {
          conversationId: existing.quoteRequest.conversationId,
          quoteRequestId: existing.quoteRequestId,
          quoteOfferId: id,
          actorUserId: currentUser.id,
          type: ConversationEventType.QUOTE_OFFER_WITHDRAWN,
          occurredAt: withdrawnAt,
          dedupeKey: `quote-offer:${id}:withdrawn`,
          data: { status: QuoteOfferStatus.WITHDRAWN, ...(reason ? { reason } : {}) },
        });
        const recipientId =
          await this.notifications.resolveProviderUpdateRecipientInTransaction(
            tx,
            existing.quoteRequest.weddingPlanId,
            existing.quoteRequest.userId,
          );
        await this.notifications.createNotificationInTransaction(
          tx,
          quoteOfferWithdrawnNotification({
            requesterId: recipientId,
            weddingPlanId: existing.quoteRequest.weddingPlanId,
            quoteRequestId: existing.quoteRequestId,
            quoteOfferId: id,
            providerId: provider.id,
            providerName: provider.businessName,
          }),
        );
      }
      const [updated] = await this.relations.attachDashboardQuoteRelations(tx, [
        await dashboardStore.requireProviderQuoteRequest(tx, existing.quoteRequestId),
      ]);
      return updated;
    });

    return this.toQuoteResponse(quote);
  }

  async findReviews(currentUser: AuthenticatedUser) {
    const provider = await this.findActiveOwnedProviderOrThrow(currentUser.id);
    const reviews = await this.relations.attachReviewUsers(
      this.prisma,
      await dashboardStore.listProviderReviews(this.prisma, provider.id),
    );

    return reviews.map((review) => this.toReviewResponse(review));
  }

  /**
   * B-09 (p27): his one reply to a review of his. Once only (409
   * `REVIEW_ALREADY_REPLIED`, decided by the conditional write so two sends
   * at once cannot both land); the reviewer is told and reads it on his page.
   * A review the team hid takes no reply (404, as he cannot answer what
   * customers do not see).
   */
  async replyToReview(
    currentUser: AuthenticatedUser,
    reviewId: string,
    dto: ReplyToReviewDto,
  ) {
    const body = dto.body.trim();
    if (!body) throw new BadRequestException('body must not be empty');
    const review = await runSerializableTransaction(this.prisma, async (tx) => {
      const provider = await lockOwnedProviderForMutationInTransaction(
        tx,
        currentUser.id,
        'OPERATIONAL',
      );
      const current = await dashboardStore.findProviderReview(tx, reviewId, provider.id);
      if (!current || current.status !== ReviewStatus.PUBLISHED) {
        throw reviewNotFound();
      }
      if (current.replyBody !== null) throw reviewAlreadyReplied();
      const at = new Date();
      const written = await dashboardStore.writeReviewReply(tx, reviewId, provider.id, body, at);
      if (written.count !== 1) throw reviewAlreadyReplied();
      await this.notifications.createNotificationInTransaction(
        tx,
        reviewRepliedNotification({
          reviewerId: current.userId,
          providerId: provider.id,
          providerName: provider.businessName,
          reviewId,
        }),
      );
      const [replied] = await this.relations.attachReviewUsers(tx, [
        (await dashboardStore.findProviderReview(tx, reviewId, provider.id))!,
      ]);
      return replied!;
    });
    return this.toReviewResponse(review);
  }

  private async lockQuoteMutationContext(
    tx: Prisma.TransactionClient,
    actorUserId: string,
    seed: {
      providerId: string;
      userId: string;
      weddingPlanId: string | null;
      conversationId: string;
    },
  ): Promise<Provider> {
    const preliminaryProvider = await dashboardStore.findPreliminaryProvider(tx, actorUserId);
    if (!preliminaryProvider || preliminaryProvider.id !== seed.providerId) {
      throw new NotFoundException('Quote request not found');
    }

    await lockProviderMutationUsersInTransaction(
      tx,
      [actorUserId, seed.userId],
      actorUserId,
    );

    if (seed.weddingPlanId) {
      // The plan row is planning's: locked for share and read there.
      const plans = await this.relations.plans.lockPlanRowForShareInTransaction(
        tx,
        seed.weddingPlanId,
      );
      if (plans.length !== 1) {
        throw new NotFoundException('Quote request not found');
      }
      const plan = await this.relations.plans.getPlan(tx, seed.weddingPlanId);
      if (!plan) {
        throw new NotFoundException('Quote request not found');
      }
      assertWeddingPlanWritable(plan);
    }

    const provider = await lockOwnedProviderAfterUsersInTransaction(
      tx,
      actorUserId,
      'OPERATIONAL',
      'SHARE',
      seed.providerId,
    );

    // The conversation row is messaging's: locked for share there.
    if (
      !(await this.lifecycle.lockConversationForShareInTransaction(
        tx,
        seed.conversationId,
      ))
    ) {
      throw new NotFoundException('Quote request not found');
    }
    return provider;
  }

  /** A quote's plan (planning's row) must still be writable; null for a plan-less quote. */
  private async assertQuotePlanWritable(
    tx: Prisma.TransactionClient,
    weddingPlanId: string | null,
  ): Promise<WeddingPlan | null> {
    if (!weddingPlanId) return null;
    const plan = await this.relations.plans.getPlan(tx, weddingPlanId);
    if (plan) assertWeddingPlanWritable(plan);
    return plan;
  }

  private async lockActiveCategoriesInTransaction(
    tx: Prisma.TransactionClient,
    categoryIds: readonly string[],
  ): Promise<void> {
    const uniqueIds = [...new Set(categoryIds)].sort();
    for (const categoryId of uniqueIds) {
      this.assertUuid(categoryId, 'categoryId');
    }
    if (uniqueIds.length === 0) return;

    // The category rows are catalog's: locked for share and confirmed
    // active there.
    if (
      !(await this.catalog.lockActiveCategoriesForShareInTransaction(
        tx,
        uniqueIds,
      ))
    ) {
      throw new BadRequestException(
        'categoryIds must reference active categories',
      );
    }
  }

  private async lockActiveCategoryInTransaction(
    tx: Prisma.TransactionClient,
    categoryId: string,
  ): Promise<void> {
    try {
      await this.lockActiveCategoriesInTransaction(tx, [categoryId]);
    } catch (error) {
      if (error instanceof BadRequestException) {
        throw new BadRequestException(
          'categoryId must reference an active category',
        );
      }
      throw error;
    }
  }

  private async lockActiveCityInTransaction(
    tx: Prisma.TransactionClient,
    cityId: string,
  ): Promise<void> {
    this.assertUuid(cityId, 'cityId');
    // The city row is catalog's: locked for share and confirmed active there.
    const city = await this.catalog.lockActiveCityForShareInTransaction(
      tx,
      cityId,
    );
    if (!city) {
      throw new BadRequestException('cityId must reference an active city');
    }
  }

  private async lockOwnedServiceInTransaction(
    tx: Prisma.TransactionClient,
    providerId: string,
    serviceId: string,
    mode: 'SHARE' | 'UPDATE',
  ): Promise<ProviderDashboardServiceRecord> {
    const rows = await dashboardStore.lockOwnedServiceRow(tx, providerId, serviceId, mode);
    if (rows.length !== 1) {
      throw new NotFoundException('Provider service not found');
    }
    const service = await dashboardStore.findOwnedServiceAfterLock(tx, serviceId);
    if (!service || service.providerId !== providerId) {
      throw new NotFoundException('Provider service not found');
    }
    return this.withServiceCatalog(tx, service);
  }

  private async lockOwnedServiceImageInTransaction(
    tx: Prisma.TransactionClient,
    serviceId: string,
    imageId: string,
  ): Promise<ProviderServiceImage> {
    const rows = await dashboardStore.lockOwnedImageRow(tx, serviceId, imageId);
    if (rows.length !== 1) {
      throw new NotFoundException('Service image not found');
    }
    const image = await dashboardStore.findOwnedImageAfterLock(tx, imageId);
    if (!image || image.serviceId !== serviceId) {
      throw new NotFoundException('Service image not found');
    }
    return image;
  }

  private async lockOwnedPackageInTransaction(
    tx: Prisma.TransactionClient,
    providerId: string,
    packageId: string,
  ): Promise<void> {
    const rows = await dashboardStore.lockOwnedPackageRow(tx, providerId, packageId);
    if (rows.length !== 1) {
      throw new NotFoundException('Provider package not found');
    }
  }

  private async findOwnedProviderOrThrow(userId: string): Promise<Provider> {
    const provider = await dashboardStore.findProviderByUserId(this.prisma, userId);
    if (!provider) {
      throw new NotFoundException('Provider profile not found');
    }
    return provider;
  }

  /** An approved provider, or one waiting for approval reading the service he joined with (B-10). */
  private async findServiceOwnerOrThrow(userId: string): Promise<Provider> {
    const provider = await this.findOwnedProviderOrThrow(userId);
    if (!isProviderAwaitingApproval(provider)) assertProviderOperational(provider);
    return provider;
  }

  private async findActiveOwnedProviderOrThrow(
    userId: string,
  ): Promise<Provider> {
    const provider = await this.findOwnedProviderOrThrow(userId);
    assertProviderOperational(provider);
    return provider;
  }

  private async findOwnedProviderProfileOrThrow(
    userId: string,
  ): Promise<ProviderProfile> {
    const provider = await dashboardStore.findProviderByUserId(this.prisma, userId);
    if (!provider) {
      throw new NotFoundException('Provider profile not found');
    }
    return this.withProviderCatalog(this.prisma, provider);
  }

  private async findOwnedServiceOrThrow(
    userId: string,
    serviceId: string,
  ): Promise<ProviderDashboardServiceRecord> {
    this.assertUuid(serviceId, 'serviceId');
    // Before approval it is the service he joined with (B-10).
    const provider = await this.findServiceOwnerOrThrow(userId);
    const service = await dashboardStore.findOwnedService(this.prisma, serviceId, provider.id);

    if (!service) {
      throw new NotFoundException('Provider service not found');
    }

    return this.withServiceCatalog(this.prisma, service);
  }

  private async findOwnedPackageOrThrow(
    userId: string,
    packageId: string,
  ): Promise<ProviderPackage> {
    this.assertUuid(packageId, 'packageId');
    const provider = await this.findActiveOwnedProviderOrThrow(userId);
    const providerPackage = await dashboardStore.findOwnedPackage(this.prisma, packageId, provider.id);
    if (!providerPackage) {
      throw new NotFoundException('Provider package not found');
    }
    return providerPackage;
  }

  // The catalog rows a provider profile and its services show are
  // catalog's; the requester and the plan a quote shows are identity's and
  // planning's. They are attached through the marketplace relations
  // service after the own-table read.
  private async withProviderCatalog(
    client: Prisma.TransactionClient,
    provider: Provider,
  ): Promise<ProviderProfile> {
    const [[profile], latestDecision, featuredPeriod] = await Promise.all([
      this.relations.attachProviderCatalog(client, [provider]),
      findLatestProviderDecision(client, provider.id),
      findProviderFeaturedView(client, provider.id, new Date()),
    ]);
    return { ...profile, latestDecision, featuredPeriod };
  }

  private async withServiceCatalog<
    T extends ProviderService & { images: ProviderServiceImage[] },
  >(
    client: Prisma.TransactionClient,
    service: T,
  ): Promise<ProviderDashboardServiceRecord> {
    const [record] = await this.relations.attachServiceCatalog(client, [
      service,
    ]);
    return record;
  }

  private serviceInclude() {
    return {
      images: { orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }] },
    } satisfies Prisma.ProviderServiceInclude;
  }

  private quoteInclude() {
    return {
      service: true,
      offers: { orderBy: { createdAt: 'desc' } },
    } satisfies Prisma.QuoteRequestInclude;
  }

  private requiredText(value: string, field: string): string {
    const trimmed = value.trim();
    if (!trimmed) {
      throw new BadRequestException(`${field} must not be empty`);
    }
    return trimmed;
  }

  private requiredPositiveMoneyAmount(value: unknown, field: string): string {
    const amount = requiredMoneyAmount(value, field);
    if (Number(amount) <= 0) {
      throw new BadRequestException(`${field} must be greater than zero`);
    }
    return amount;
  }

  private quoteOfferCurrency(
    requested: string | null | undefined,
    weddingPlanCurrency?: string | null,
  ): string {
    const currency = (requested?.trim() || weddingPlanCurrency || 'YER')
      .toUpperCase();
    if (!/^[A-Z]{3}$/.test(currency)) {
      throw new BadRequestException(
        'currency must be a three-letter ISO code',
      );
    }
    if (
      weddingPlanCurrency &&
      currency !== weddingPlanCurrency.toUpperCase()
    ) {
      throw quoteOfferCurrencyMismatch(weddingPlanCurrency, 'provider');
    }
    return currency;
  }

  private optionalText(value: string | null | undefined): string | null {
    if (value === undefined || value === null) return null;
    const trimmed = value.trim();
    return trimmed || null;
  }

  private optionalSignedDecimal(
    value: string | null | undefined,
    field: string,
  ): string | null {
    if (value === undefined || value === null) return null;
    const normalized = value.trim();
    if (!normalized) return null;
    if (!/^-?\d+(\.\d+)?$/.test(normalized)) {
      throw new BadRequestException(`${field} must be a valid decimal value`);
    }
    return normalized;
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

  private assertUuid(value: string, field: string): void {
    const uuidPattern =
      /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
    if (!uuidPattern.test(value)) {
      throw new BadRequestException(`${field} must be a valid UUID`);
    }
  }

  /** B-20: the validation pipe checks it too; this is the service's own guard. */
  private dailyCapacity(value: number): number {
    if (
      !Number.isInteger(value) ||
      value < DAILY_BOOKING_CAPACITY_MIN ||
      value > DAILY_BOOKING_CAPACITY_MAX
    ) {
      throw new BadRequestException({
        statusCode: 400,
        code: 'PROVIDER_DAILY_CAPACITY_RANGE',
        message: 'dailyBookingCapacity is a whole number from 1 to 20',
      });
    }
    return value;
  }

  private toProviderProfileResponse(provider: ProviderProfile) {
    return {
      id: provider.id,
      userId: provider.userId,
      cityId: provider.cityId,
      city: this.toCityResponse(provider.city),
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
      ...currentProviderReviewNotes(provider.status, provider.latestDecision),
      // The decision he reads now; «أرسلت التعديل» names it (B-01).
      latestDecision: toProviderLatestDecision(provider.latestDecision),
      resubmittedAt: provider.resubmittedAt,
      resubmitCount: provider.resubmitCount,
      reopenedAt: provider.reopenedAt,
      reviewedAt: provider.reviewedAt,
      reviewedById: provider.reviewedById,
      verifiedAt: provider.verifiedAt,
      // B-43: the placement the back office recorded after he paid outside
      // the app; `active` is false while it waits for its start.
      featured: provider.featuredPeriod
        ? {
            startsAt: provider.featuredPeriod.startsAt,
            endsAt: provider.featuredPeriod.endsAt,
            active: provider.featuredPeriod.startsAt.getTime() <= Date.now(),
          }
        : null,
      ratingAverage: provider.ratingAverage.toString(),
      ratingCount: provider.ratingCount,
      // B-20: confirmed bookings he takes on one day.
      dailyBookingCapacity: provider.dailyBookingCapacity,
      createdAt: provider.createdAt,
      updatedAt: provider.updatedAt,
    };
  }

  private toCityResponse(city: City) {
    return {
      id: city.id,
      nameAr: city.nameAr,
      nameEn: city.nameEn,
      countryCode: city.countryCode,
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
      showForGroom: category.showForGroom,
      showForBride: category.showForBride,
      sortOrder: category.sortOrder,
    };
  }

  private toServiceResponse(service: ProviderDashboardServiceRecord) {
    return {
      id: service.id,
      providerId: service.providerId,
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
      images: service.images.map((image) => this.toImageResponse(image)),
      createdAt: service.createdAt,
      updatedAt: service.updatedAt,
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

  private toPackageResponse(providerPackage: ProviderPackageRecord) {
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

  private toQuoteResponse(quote: ProviderQuoteRecord) {
    // B-08: the customer's phone and budget reach the provider only when he
    // shared them with the request.
    const contact = toApplicationUserContact(quote.user);
    return {
      id: quote.id,
      userId: quote.userId,
      user: { ...contact, phone: quote.shareContact ? contact.phone : null },
      weddingPlanId: quote.weddingPlanId,
      weddingPlan: quote.weddingPlan ?? null,
      providerId: quote.providerId,
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
      guestCount: quote.guestCount,
      contactName: quote.contactName,
      contactPhone: quote.shareContact ? quote.contactPhone : null,
      contactNormalizedPhone: quote.shareContact
        ? quote.contactNormalizedPhone
        : null,
      message: quote.message,
      budgetMin: quote.shareBudget ? (quote.budgetMin?.toString() ?? null) : null,
      budgetMax: quote.shareBudget ? (quote.budgetMax?.toString() ?? null) : null,
      shareBudget: quote.shareBudget,
      shareContact: quote.shareContact,
      status: quote.status,
      lifecycleStatus: quoteLifecycleStatus(quote.status),
      offers: quote.offers?.map((offer) => this.toQuoteOfferResponse(offer)) ?? [],
      // B-18 (p22, p25): the customer's agreed, paid and left on this
      // booking's item, three totals only; null without an agreement.
      booking: quote.booking
        ? { ...toBookingResponse(quote.booking), money: quote.bookingMoney ?? null }
        : null,
      acceptedAt: quote.acceptedAt,
      rejectedAt: quote.rejectedAt,
      cancelledAt: quote.cancelledAt,
      // B-04: the provider answers before this; EXPIRED after.
      expiresAt: quote.expiresAt,
      expiredAt: quote.expiredAt,
      createdAt: quote.createdAt,
      updatedAt: quote.updatedAt,
    };
  }

  private toReviewResponse(review: ProviderReviewRecord) {
    return {
      id: review.id,
      userId: review.userId,
      user: toReviewIdentity(review.user),
      providerId: review.providerId,
      rating: review.rating,
      comment: review.comment,
      status: review.status,
      // B-09: his reply in any state (the team may have hidden it).
      reply: ownerReviewReply(review),
      createdAt: review.createdAt,
      updatedAt: review.updatedAt,
    };
  }

  private toQuoteOfferResponse(offer: QuoteOffer) {
    const isExpired = isQuoteOfferExpired(offer);
    return {
      id: offer.id,
      quoteRequestId: offer.quoteRequestId,
      providerId: offer.providerId,
      title: offer.title,
      message: offer.message,
      amount: offer.amount?.toString() ?? null,
      currency: offer.currency,
      validUntil: offer.validUntil,
      status: offer.status,
      isExpired,
      isActionable: offer.status === QuoteOfferStatus.PENDING && !isExpired,
      // B-06 version and «ايش تغيّر», B-03 withdrawal: his own offer, in full.
      ...quoteOfferVersionView(offer, true),
      createdAt: offer.createdAt,
      updatedAt: offer.updatedAt,
    };
  }
}
