import {
  BadRequestException,
  ConflictException,
  NotFoundException,
  UnprocessableEntityException,
} from '@nestjs/common';
import {
  NotificationPriority,
  NotificationType,
  ProviderStatus,
} from '@prisma/client';
import { AuthenticatedUser } from '../modules/identity/public/identity-session.types';
import {
  arabicDayLabel,
  FEATURED_PERIOD_MAX_DAYS,
  featuredEndAfter,
  featuredLastDay,
  featuredPeriodState,
  yemenDayOf,
  yemenDayStart,
} from '../modules/marketplace/public/featured-placement';
import { PROVIDER_PORTAL_ROUTE } from '../modules/marketplace/public/provider-access-policy';
import type {
  AdminFeaturedPeriodRow,
  AdminFeaturedPeriodState,
} from '../modules/marketplace/public/marketplace-admin.port';
import type { NotificationsPort } from '../modules/notifications/public/notifications.port';
import { runSerializableTransaction } from '../platform/database/serializable-transaction';
import { PrismaService } from '../platform/database/prisma.service';
import type { AdminOwners } from './admin-owners';
import { lockProviderReviewAccountsInTransaction } from './admin-provider-review-lock';
import { toAdminFeaturedPeriodResponse } from './admin.presenter';
import type {
  AdminEndFeaturedPeriodDto,
  AdminFeaturedPeriodQueryDto,
  AdminGrantFeaturedPeriodDto,
} from './dto/admin-featured-period.dto';

const PROVIDER_NOT_FOUND = 'Provider not found';
const PERIOD_NOT_FOUND = 'Featured period not found';
const DAY_MS = 24 * 60 * 60 * 1000;
const STATES: readonly AdminFeaturedPeriodState[] = ['CURRENT', 'ACTIVE', 'SCHEDULED', 'FINISHED'];

export interface AdminFeaturedPlacementsDependencies {
  prisma: PrismaService;
  owners: AdminOwners;
  /** The notifications port the back office service was given. */
  notifications: NotificationsPort;
}

/**
 * Featured placement (B-43, D41): the provider pays the owner outside the
 * app and an administrator who may write providers records the period here.
 * Nothing about money is kept. Every write is in the admin audit log (the
 * audit interceptor) and the provider is told when it starts and when it
 * stops early; the hourly job tells him a week before the end and at the end.
 */
export class AdminFeaturedPlacements {
  private readonly prisma: PrismaService;
  private readonly owners: AdminOwners;
  private readonly notifications: NotificationsPort;

  constructor(dependencies: AdminFeaturedPlacementsDependencies) {
    this.prisma = dependencies.prisma;
    this.owners = dependencies.owners;
    this.notifications = dependencies.notifications;
  }

  async list(
    query: AdminFeaturedPeriodQueryDto,
    pagination: { page: number; limit: number; skip: number },
  ) {
    const now = new Date();
    const state = this.parseState(query.state);
    const providerId = query.providerId?.trim() || null;
    const { total, items } = await this.prisma.$transaction(async (tx) => {
      const listing = await this.owners.marketplace.listFeaturedPeriods(
        tx,
        { state, providerId },
        { skip: pagination.skip, take: pagination.limit },
        now,
      );
      return {
        total: listing.total,
        items: await this.owners.attachFeaturedPeriods(tx, listing.items),
      };
    });
    return {
      items: items.map((item) => toAdminFeaturedPeriodResponse(item, now)),
      page: pagination.page,
      limit: pagination.limit,
      total,
      totalPages: Math.ceil(total / pagination.limit),
    };
  }

  /** a17's cards: free and featured among the providers customers see, and what ends this week. */
  async summary() {
    const now = new Date();
    const weekEnd = new Date(now.getTime() + 7 * DAY_MS);
    const counts = await this.prisma.$transaction((tx) =>
      this.owners.marketplace.getFeaturedSummary(tx, now, weekEnd),
    );
    return {
      listedProviders: counts.listedProviders,
      featured: counts.featured,
      free: counts.listedProviders - counts.featured,
      endingThisWeek: counts.endingSoon,
    };
  }

  async grant(
    currentUser: AuthenticatedUser,
    providerId: string,
    dto: AdminGrantFeaturedPeriodDto,
  ) {
    const note = dto.note?.trim() || null;
    const period = await runSerializableTransaction(this.prisma, async (tx) => {
      const now = new Date();
      const { startsAt, endsAt } = this.periodFrom(dto, now);
      const seed = await this.owners.marketplace.findProviderAccount(tx, providerId);
      if (!seed) throw new NotFoundException(PROVIDER_NOT_FOUND);
      if (seed.userId === currentUser.id) {
        throw new BadRequestException('Administrators cannot feature their own listing');
      }
      await lockProviderReviewAccountsInTransaction(
        tx,
        this.owners,
        currentUser,
        seed.userId,
        PROVIDER_NOT_FOUND,
      );
      const listing = await this.owners.marketplace.lockProviderForUpdateInTransaction(
        tx,
        providerId,
      );
      if (!listing || listing.userId !== seed.userId) {
        throw new NotFoundException(PROVIDER_NOT_FOUND);
      }
      if (listing.status !== ProviderStatus.ACTIVE) {
        throw new ConflictException({
          statusCode: 409,
          code: 'FEATURED_PROVIDER_NOT_ACTIVE',
          message: 'Only an active provider can be featured',
        });
      }
      // A listing nobody claimed takes no requests (D41): featuring it
      // would send customers to a dead end.
      if (listing.userId === null) {
        throw new ConflictException({
          statusCode: 409,
          code: 'FEATURED_PROVIDER_UNCLAIMED',
          message: 'A listing its owner has not claimed cannot be featured',
        });
      }
      const overlap = await this.owners.marketplace.findOverlappingFeaturedPeriod(
        tx,
        providerId,
        startsAt,
        endsAt,
      );
      if (overlap) {
        throw new ConflictException({
          statusCode: 409,
          code: 'FEATURED_PERIOD_OVERLAP',
          message: 'The provider already has a placement in these days',
          startsOn: yemenDayOf(overlap.startsAt),
          lastDay: featuredLastDay(overlap.endsAt),
        });
      }
      const created = await this.owners.marketplace.createFeaturedPeriodInTransaction(tx, {
        providerId,
        startsAt,
        endsAt,
        note,
        grantedById: currentUser.id,
      });
      await this.notifyProvider(tx, listing.userId, created, 'granted', now);
      return (await this.owners.attachFeaturedPeriods(tx, [created]))[0]!;
    });
    return toAdminFeaturedPeriodResponse(period, new Date());
  }

  /** Stops a placement now, or cancels one that has not started. */
  async end(
    currentUser: AuthenticatedUser,
    periodId: string,
    dto: AdminEndFeaturedPeriodDto,
  ) {
    const note = dto.note?.trim() || null;
    const period = await runSerializableTransaction(this.prisma, async (tx) => {
      const now = new Date();
      // The administrator first, as every provider review write locks.
      await lockProviderReviewAccountsInTransaction(
        tx,
        this.owners,
        currentUser,
        null,
        PERIOD_NOT_FOUND,
      );
      const seed = await this.owners.marketplace.lockFeaturedPeriodForUpdateInTransaction(
        tx,
        periodId,
      );
      if (!seed) throw new NotFoundException(PERIOD_NOT_FOUND);
      const state = featuredPeriodState(seed, now);
      if (state === 'ENDED' || state === 'EXPIRED') {
        throw new ConflictException({
          statusCode: 409,
          code: 'FEATURED_PERIOD_FINISHED',
          message: 'The placement is already over',
        });
      }
      const ended = await this.owners.marketplace.endFeaturedPeriodInTransaction(
        tx,
        periodId,
        { endedAt: now, endedById: currentUser.id, endNote: note },
      );
      if (!ended) {
        throw new ConflictException({
          statusCode: 409,
          code: 'FEATURED_PERIOD_FINISHED',
          message: 'The placement is already over',
        });
      }
      if (ended.provider.userId) {
        await this.notifyProvider(
          tx,
          ended.provider.userId,
          ended,
          state === 'SCHEDULED' ? 'cancelled' : 'stopped',
          now,
        );
      }
      return (await this.owners.attachFeaturedPeriods(tx, [ended]))[0]!;
    });
    return toAdminFeaturedPeriodResponse(period, new Date());
  }

  /**
   * The period from the days the administrator chose. It starts now, or on
   * a later day; it covers whole days up to and including `endsOn`.
   */
  private periodFrom(dto: AdminGrantFeaturedPeriodDto, now: Date) {
    const endsAt = featuredEndAfter(dto.endsOn);
    if (!endsAt) throw this.invalidPeriod('FEATURED_PERIOD_INVALID', 'endsOn is not a day');
    let startsAt = now;
    if (dto.startsOn && dto.startsOn !== yemenDayOf(now)) {
      const day = yemenDayStart(dto.startsOn);
      if (!day) throw this.invalidPeriod('FEATURED_PERIOD_INVALID', 'startsOn is not a day');
      // Recorded placements are never back-dated: before this moment the
      // provider was not ranked first, so the record does not say he was.
      if (day.getTime() < now.getTime()) {
        throw this.invalidPeriod('FEATURED_PERIOD_START_PAST', 'A placement cannot start in the past');
      }
      startsAt = day;
    }
    if (endsAt.getTime() <= startsAt.getTime()) {
      throw this.invalidPeriod('FEATURED_PERIOD_INVALID', 'The last day comes before the start');
    }
    if (endsAt.getTime() - startsAt.getTime() > FEATURED_PERIOD_MAX_DAYS * DAY_MS) {
      throw this.invalidPeriod(
        'FEATURED_PERIOD_TOO_LONG',
        `A placement covers at most ${FEATURED_PERIOD_MAX_DAYS} days`,
      );
    }
    return { startsAt, endsAt };
  }

  private invalidPeriod(code: string, message: string) {
    return new UnprocessableEntityException({ statusCode: 422, code, message });
  }

  private parseState(value?: string): AdminFeaturedPeriodState | null {
    const normalized = value?.trim().toUpperCase();
    if (!normalized) return 'CURRENT';
    if (normalized === 'ALL') return null;
    if ((STATES as readonly string[]).includes(normalized)) {
      return normalized as AdminFeaturedPeriodState;
    }
    throw new BadRequestException('featured period state is not supported');
  }

  private async notifyProvider(
    tx: Parameters<NotificationsPort['createNotificationInTransaction']>[0],
    userId: string,
    period: AdminFeaturedPeriodRow,
    event: 'granted' | 'stopped' | 'cancelled',
    now: Date,
  ) {
    const from = arabicDayLabel(yemenDayOf(period.startsAt));
    const until = arabicDayLabel(featuredLastDay(period.endsAt));
    const startsLater = period.startsAt.getTime() > now.getTime();
    const message = {
      granted: {
        title: startsLater ? 'ظهورك المميز محجوز' : 'تفعّل ظهورك المميز',
        body: startsLater
          ? `يبدأ ${from} ويستمر لين ${until}. ملفك يطلع أول في قسمك ومدينتك، وعليه علامة «مميز».`
          : `من اليوم لين ${until} ملفك يطلع أول في قسمك ومدينتك، وعليه علامة «مميز».`,
      },
      stopped: {
        title: 'وقّفنا ظهورك المميز',
        body: period.endNote ?? 'من اليوم ملفك يظهر عادي. لو عندك سؤال كلّم فريق اعّرست.',
      },
      cancelled: {
        title: 'لغينا ظهورك المميز',
        body: period.endNote ?? `الظهور اللي كان يبدأ ${from} انلغى. لو عندك سؤال كلّم فريق اعّرست.`,
      },
    }[event];
    await this.notifications.createNotificationInTransaction(tx, {
      userId,
      type: NotificationType.GENERAL,
      priority: NotificationPriority.NORMAL,
      title: message.title,
      body: message.body,
      entityType: 'ProviderFeaturedPeriod',
      entityId: period.id,
      routeTarget: PROVIDER_PORTAL_ROUTE,
      data: {
        providerId: period.providerId,
        featuredPeriodId: period.id,
        featuredEvent: event,
        recipientAudience: 'PROVIDER',
      },
      dedupeKey: `featured-period:${period.id}:${event}`,
    });
  }
}
