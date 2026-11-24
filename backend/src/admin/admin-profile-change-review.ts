import {
  BadRequestException,
  ConflictException,
  NotFoundException,
  UnprocessableEntityException,
} from '@nestjs/common';
import {
  NotificationPriority,
  NotificationType,
  ProviderProfileChangeStatus,
} from '@prisma/client';
import { AuthenticatedUser } from '../modules/identity/public/identity-session.types';
import type { AdminProfileChangeRow } from '../modules/marketplace/public/marketplace-admin.port';
import {
  PROFILE_CHANGE_REJECTION_REASON_MAX_LENGTH,
  profileChangeDecisionNotice,
  profileChangeFields,
  profileChangeMediaTarget,
} from '../modules/marketplace/public/provider-profile-change';
import type { NotificationsPort } from '../modules/notifications/public/notifications.port';
import { runSerializableTransaction } from '../platform/database/serializable-transaction';
import { PrismaService } from '../platform/database/prisma.service';
import { noticeRoutes } from '../shared-kernel/routes/notification-routes';
import type { AdminOwners } from './admin-owners';
import { recordAdminAuditChange } from '../modules/backoffice/public/admin-audit-change';
import type {
  AdminProfileChangeDecisionDto,
  AdminProfileChangeQueryDto,
} from './dto/admin-profile-change.dto';

const STATUSES: readonly ProviderProfileChangeStatus[] = [
  ProviderProfileChangeStatus.PENDING,
  ProviderProfileChangeStatus.APPROVED,
  ProviderProfileChangeStatus.REJECTED,
  ProviderProfileChangeStatus.WITHDRAWN,
];

export interface AdminProfileChangeReviewDependencies {
  prisma: PrismaService;
  owners: AdminOwners;
  notifications: NotificationsPort;
}

type CatalogNames = { cities: Map<string, string>; categories: Map<string, string> };

/** A request as the queue shows it: what the listing shows now and what he asked for. */
export function toAdminProfileChangeResponse(row: AdminProfileChangeRow, names: CatalogNames) {
  const city = (id: string | null) => (id ? { id, nameAr: names.cities.get(id) ?? null } : null);
  const category = (id: string | null) =>
    id ? { id, nameAr: names.categories.get(id) ?? null } : null;
  // A refused or withdrawn request's images are deleted.
  const imagesKept =
    row.status === ProviderProfileChangeStatus.PENDING ||
    row.status === ProviderProfileChangeStatus.APPROVED;
  return {
    id: row.id,
    status: row.status,
    rejectionReason: row.rejectionReason,
    decidedAt: row.decidedAt,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    asked: {
      businessName: row.businessName,
      city: city(row.cityId),
      primaryCategory: category(row.primaryCategoryId),
      logoUrl: imagesKept ? row.logoUrl : null,
      coverUrl: imagesKept ? row.coverUrl : null,
      logoChanged: row.logoUrl !== null,
      coverChanged: row.coverUrl !== null,
    },
    provider: {
      id: row.provider.id,
      businessName: row.provider.businessName,
      status: row.provider.status,
      city: city(row.provider.cityId),
      primaryCategory: category(row.provider.primaryCategoryId),
      logoUrl: row.provider.logoUrl,
      coverUrl: row.provider.coverUrl,
    },
  };
}

/** The ids of what the audit keeps: codes, never the typed name (RA-AD-23). */
function auditState(row: AdminProfileChangeRow, status: ProviderProfileChangeStatus) {
  return {
    status,
    businessNameChanged: row.businessName !== null,
    logoChanged: row.logoUrl !== null,
    coverChanged: row.coverUrl !== null,
    cityId: row.cityId,
    primaryCategoryId: row.primaryCategoryId,
  };
}

/**
 * RA-BE-152 (Q-39 (أ), D124): the team approves or refuses an approved
 * provider's change of his name, logo, cover, city or category, the oldest
 * first. Approval puts the values on the listing and its new images in
 * place of the old ones (deleted); a refusal carries its reason and deletes
 * the images it held. The provider is told either way, the notice opening
 * p35; the audit log keeps the reason and the state before and after.
 */
export class AdminProfileChangeReview {
  constructor(private readonly deps: AdminProfileChangeReviewDependencies) {}

  async list(
    query: AdminProfileChangeQueryDto,
    pagination: { page: number; limit: number; skip: number },
  ) {
    const status = (query.status ?? ProviderProfileChangeStatus.PENDING) as ProviderProfileChangeStatus;
    if (!STATUSES.includes(status)) {
      throw new BadRequestException('status must be PENDING, APPROVED, REJECTED or WITHDRAWN');
    }
    const { listing, names } = await this.deps.prisma.$transaction(async (tx) => {
      const listing = await this.deps.owners.marketplace.listProfileChangesForReview(tx, status, {
        skip: pagination.skip,
        take: pagination.limit,
      });
      return { listing, names: await this.namesOf(tx, listing.items) };
    });
    return {
      items: listing.items.map((row) => toAdminProfileChangeResponse(row, names)),
      page: pagination.page,
      limit: pagination.limit,
      total: listing.total,
      totalPages: Math.ceil(listing.total / pagination.limit),
    };
  }

  async decide(currentUser: AuthenticatedUser, id: string, dto: AdminProfileChangeDecisionDto) {
    const approve = dto.decision === 'APPROVE';
    const reason = dto.reason?.trim() || null;
    if (!approve && !reason) {
      throw new BadRequestException('A refusal needs its reason');
    }
    if (reason && reason.length > PROFILE_CHANGE_REJECTION_REASON_MAX_LENGTH) {
      throw new BadRequestException(
        `The reason has at most ${PROFILE_CHANGE_REJECTION_REASON_MAX_LENGTH} characters`,
      );
    }
    const { row, names } = await runSerializableTransaction(this.deps.prisma, async (tx) => {
      const { marketplace, media } = this.deps.owners;
      const current = await marketplace.lockProfileChangeInTransaction(tx, id);
      if (!current) throw new NotFoundException('Profile change not found');
      // RA-BE-101: a team member does not decide on his own business.
      if (current.provider.userId === currentUser.id) {
        throw new BadRequestException('Administrators cannot review their own listing');
      }
      if (current.status !== ProviderProfileChangeStatus.PENDING) {
        throw this.alreadyDecided();
      }
      const fields = profileChangeFields(current);
      if (
        approve &&
        !(await this.deps.owners.lockActiveCatalogInTransaction(
          tx,
          fields.cityId,
          fields.primaryCategoryId,
        ))
      ) {
        throw new UnprocessableEntityException({
          code: 'PROFILE_CHANGE_CATALOG_INACTIVE',
          message: 'The city or category this change asks for is no longer active',
        });
      }
      for (const image of ['logo', 'cover'] as const) {
        if ((image === 'logo' ? fields.logoUrl : fields.coverUrl) === null) continue;
        const pending = profileChangeMediaTarget(current.id, image);
        if (approve) {
          await media.promoteTargetMedia(
            pending,
            { type: image === 'logo' ? 'PROVIDER_LOGO' : 'PROVIDER_COVER', id: current.provider.id },
            tx,
          );
        } else {
          await media.scheduleTargetDeletion(pending, tx);
        }
      }
      const row = await marketplace.decideProfileChangeInTransaction(tx, id, {
        status: approve ? ProviderProfileChangeStatus.APPROVED : ProviderProfileChangeStatus.REJECTED,
        reason: approve ? null : reason,
        decidedAt: new Date(),
        decidedById: currentUser.id,
      });
      if (!row) throw this.alreadyDecided();
      recordAdminAuditChange(auditState(current, current.status), auditState(row, row.status));
      if (row.provider.userId) {
        const notice = profileChangeDecisionNotice(
          fields,
          approve ? 'APPROVED' : 'REJECTED',
          row.rejectionReason,
        );
        await this.deps.notifications.createNotificationInTransaction(tx, {
          userId: row.provider.userId,
          type: NotificationType.PROVIDER_PROFILE_CHANGE_REVIEWED,
          priority: NotificationPriority.NORMAL,
          title: notice.title,
          body: notice.body,
          entityType: 'ProviderProfileChange',
          entityId: row.id,
          routeTarget: noticeRoutes.providerProfile(),
          data: {
            providerId: row.provider.id,
            profileChangeId: row.id,
            decision: row.status,
            recipientAudience: 'PROVIDER',
          },
          dedupeKey: `provider-profile-change:${row.id}:${row.status}`,
        });
      }
      return { row, names: await this.namesOf(tx, [row]) };
    });
    return toAdminProfileChangeResponse(row, names);
  }

  private namesOf(
    client: Parameters<AdminOwners['catalogNames']>[0],
    rows: readonly AdminProfileChangeRow[],
  ) {
    return this.deps.owners.catalogNames(
      client,
      rows.flatMap((row) => [row.cityId, row.provider.cityId]).filter(isId),
      rows.flatMap((row) => [row.primaryCategoryId, row.provider.primaryCategoryId]).filter(isId),
    );
  }

  private alreadyDecided() {
    return new ConflictException({
      code: 'PROFILE_CHANGE_ALREADY_DECIDED',
      message: 'This change was already decided or withdrawn',
    });
  }
}

function isId(value: string | null): value is string {
  return typeof value === 'string';
}
