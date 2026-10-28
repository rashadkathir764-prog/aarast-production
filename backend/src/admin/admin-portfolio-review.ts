import {
  BadRequestException,
  ConflictException,
  NotFoundException,
  UnprocessableEntityException,
} from '@nestjs/common';
import {
  NotificationPriority,
  NotificationType,
  PortfolioItemStatus,
} from '@prisma/client';
import { AuthenticatedUser } from '../modules/identity/public/identity-session.types';
import type { AdminPortfolioRow } from '../modules/marketplace/public/marketplace-admin.port';
import {
  PORTFOLIO_REJECTION_REASON_MAX_LENGTH,
} from '../modules/marketplace/public/provider-portfolio';
import type { NotificationsPort } from '../modules/notifications/public/notifications.port';
import { runSerializableTransaction } from '../platform/database/serializable-transaction';
import { PrismaService } from '../platform/database/prisma.service';
import { noticeRoutes } from '../shared-kernel/routes/notification-routes';
import type { AdminOwners } from './admin-owners';
import type {
  AdminPortfolioDecisionDto,
  AdminPortfolioQueryDto,
} from './dto/admin-portfolio.dto';

const STATUSES: readonly PortfolioItemStatus[] = [
  PortfolioItemStatus.PENDING,
  PortfolioItemStatus.APPROVED,
  PortfolioItemStatus.REJECTED,
];

export interface AdminPortfolioReviewDependencies {
  prisma: PrismaService;
  owners: AdminOwners;
  notifications: NotificationsPort;
}

export function toAdminPortfolioResponse(row: AdminPortfolioRow) {
  return {
    id: row.id,
    imageUrl: row.status === PortfolioItemStatus.REJECTED ? null : row.imageUrl,
    album: row.album,
    forWomen: row.forWomen,
    noFaces: row.noFaces,
    status: row.status,
    rejectionReason: row.rejectionReason,
    reviewedAt: row.reviewedAt,
    createdAt: row.createdAt,
    provider: {
      id: row.provider.id,
      businessName: row.provider.businessName,
      status: row.provider.status,
    },
  };
}

/** The sentence the provider reads (the portal speaks to the business in the masculine, D55). */
export function portfolioDecisionNotice(row: AdminPortfolioRow) {
  const where = row.album ? `في «${row.album}»` : 'في معرض الشغل';
  if (row.status === PortfolioItemStatus.APPROVED) {
    return {
      title: 'انقبلت صورة من معرضك',
      body: `صورتك ${where} تظهر الحين ${row.forWomen ? 'للعرائس' : 'للعرسان'}.`,
    };
  }
  return {
    title: 'ما قبلنا صورة من معرضك',
    body: `صورتك ${where} ما تظهر. السبب: ${row.rejectionReason ?? ''}`,
  };
}

/**
 * n07 (B-16, D62): the moderation team approves or refuses every new
 * portfolio photo, the oldest first. A women's-album photo is approved only
 * when the reviewer confirms it shows no faces. A refusal carries its reason
 * and the photo's image is deleted (the media cleanup); the provider is told
 * either way, the notice opening p37. Every decision is in the admin audit
 * log (the audit interceptor).
 */
export class AdminPortfolioReview {
  constructor(private readonly deps: AdminPortfolioReviewDependencies) {}

  async list(
    query: AdminPortfolioQueryDto,
    pagination: { page: number; limit: number; skip: number },
  ) {
    const status = (query.status ?? PortfolioItemStatus.PENDING) as PortfolioItemStatus;
    if (!STATUSES.includes(status)) {
      throw new BadRequestException('status must be PENDING, APPROVED or REJECTED');
    }
    const listing = await this.deps.prisma.$transaction((tx) =>
      this.deps.owners.marketplace.listPortfolioForReview(tx, status, {
        skip: pagination.skip,
        take: pagination.limit,
      }),
    );
    return {
      items: listing.items.map(toAdminPortfolioResponse),
      page: pagination.page,
      limit: pagination.limit,
      total: listing.total,
      totalPages: Math.ceil(listing.total / pagination.limit),
    };
  }

  async decide(currentUser: AuthenticatedUser, id: string, dto: AdminPortfolioDecisionDto) {
    const approve = dto.decision === 'APPROVE';
    const reason = dto.reason?.trim() || null;
    if (!approve && !reason) {
      throw new BadRequestException('A refusal needs its reason');
    }
    if (reason && reason.length > PORTFOLIO_REJECTION_REASON_MAX_LENGTH) {
      throw new BadRequestException(
        `The reason has at most ${PORTFOLIO_REJECTION_REASON_MAX_LENGTH} characters`,
      );
    }
    const decided = await runSerializableTransaction(this.deps.prisma, async (tx) => {
      const current = await this.deps.owners.marketplace.lockPortfolioItemInTransaction(tx, id);
      if (!current) throw new NotFoundException('Portfolio photo not found');
      if (current.status !== PortfolioItemStatus.PENDING) {
        throw new ConflictException({
          code: 'PORTFOLIO_ITEM_ALREADY_DECIDED',
          message: 'This photo was already decided',
        });
      }
      if (approve && current.forWomen && dto.noFacesChecked !== true) {
        throw new UnprocessableEntityException({
          code: 'PORTFOLIO_NO_FACES_NOT_CHECKED',
          message: 'A women\'s-album photo is approved only after checking it shows no faces',
        });
      }
      const row = await this.deps.owners.marketplace.decidePortfolioItemInTransaction(tx, id, {
        status: approve ? 'APPROVED' : 'REJECTED',
        reason: approve ? null : reason,
        reviewedAt: new Date(),
        reviewedById: currentUser.id,
      });
      if (!row) {
        throw new ConflictException({
          code: 'PORTFOLIO_ITEM_ALREADY_DECIDED',
          message: 'This photo was already decided',
        });
      }
      if (!approve) {
        await this.deps.owners.media.scheduleTargetDeletion({ type: 'PORTFOLIO_ITEM', id: row.id }, tx);
      }
      if (row.provider.userId) {
        const notice = portfolioDecisionNotice(row);
        await this.deps.notifications.createNotificationInTransaction(tx, {
          userId: row.provider.userId,
          type: NotificationType.PORTFOLIO_REVIEWED,
          priority: NotificationPriority.NORMAL,
          title: notice.title,
          body: notice.body,
          entityType: 'PortfolioItem',
          entityId: row.id,
          routeTarget: noticeRoutes.providerPortfolio(),
          data: {
            providerId: row.provider.id,
            portfolioItemId: row.id,
            decision: row.status,
            recipientAudience: 'PROVIDER',
          },
          // A kept photo whose album changed is reviewed again: one notice per decision.
          dedupeKey: `portfolio-item:${row.id}:${row.status}:${row.reviewedAt?.getTime() ?? 0}`,
        });
      }
      return row;
    });
    return toAdminPortfolioResponse(decided);
  }
}
