import {
  BadRequestException,
  ConflictException,
  NotFoundException,
} from '@nestjs/common';
import {
  NotificationPriority,
  NotificationType,
  Prisma,
  type ProviderClaimRequest,
  ProviderClaimStatus,
  ProviderStatus,
  UserStatus,
} from '@prisma/client';
import { AuthenticatedUser } from '../modules/identity/public/identity-session.types';
import { claimPhoneMatchesListing } from '../modules/marketplace/public/provider-claim-phone';
import type { NotificationsPort } from '../modules/notifications/public/notifications.port';
import { runSerializableTransaction } from '../platform/database/serializable-transaction';
import { PrismaService } from '../platform/database/prisma.service';
import type { AdminOwners } from './admin-owners';
import { lockProviderReviewAccountsInTransaction } from './admin-provider-review-lock';
import { toAdminClaimRequestResponse } from './admin.presenter';

const CLAIM_NOT_FOUND = 'Provider claim not found';

/**
 * The review of a claim of a listing the back office made (B-12): approving
 * hands the listing to the account that proved its phone, refusing tells it
 * why. Only an administrator links a listing to an account.
 */
export interface AdminProviderClaimsDependencies {
  prisma: PrismaService;
  owners: AdminOwners;
  /** The notifications port the back office service was given. */
  notifications: NotificationsPort;
}

export class AdminProviderClaims {
  private readonly prisma: PrismaService;
  private readonly owners: AdminOwners;
  private readonly notifications: NotificationsPort;

  constructor(dependencies: AdminProviderClaimsDependencies) {
    this.prisma = dependencies.prisma;
    this.owners = dependencies.owners;
    this.notifications = dependencies.notifications;
  }

  async approve(currentUser: AuthenticatedUser, id: string) {
    const claim = await runSerializableTransaction(this.prisma, async (tx) => {
      const { current, claimant } = await this.lockPendingClaim(tx, currentUser, id);
      const listing =
        await this.owners.marketplace.lockProviderForUpdateInTransaction(
          tx,
          current.providerId,
        );
      if (!listing) throw new NotFoundException(CLAIM_NOT_FOUND);
      if (listing.userId !== null || listing.status !== ProviderStatus.ACTIVE) {
        throw new ConflictException({
          statusCode: 409,
          code: 'PROVIDER_CLAIM_LISTING_TAKEN',
          message: 'The listing is no longer waiting for its owner',
        });
      }
      if (claimant?.status !== UserStatus.ACTIVE) {
        throw new ConflictException({
          statusCode: 409,
          code: 'PROVIDER_CLAIM_ACCOUNT_INACTIVE',
          message: 'The claiming account is not active',
        });
      }
      // The phone proved the claim when it was sent; the account row is
      // locked above, so the phone read here is the one that would own the
      // listing. A changed phone no longer proves it.
      const account = await this.owners.accounts.getAccount(tx, current.userId);
      if (!claimPhoneMatchesListing(account?.phone, listing.phone)) {
        throw new ConflictException({
          statusCode: 409,
          code: 'PROVIDER_CLAIM_PHONE_CHANGED',
          message: "The claiming account's phone no longer matches the listing",
        });
      }
      const owned = await this.owners.marketplace.getAccountProviders(tx, [
        current.userId,
      ]);
      if (owned.length > 0) {
        throw new ConflictException({
          statusCode: 409,
          code: 'PROVIDER_CLAIM_ACCOUNT_HAS_PROVIDER',
          message: 'The claiming account already has a provider profile',
        });
      }
      if (
        !(await this.owners.providerAccounts.promoteToProviderInTransaction(
          tx,
          current.userId,
        ))
      ) {
        throw new ConflictException(
          'The claiming identity is not eligible for a provider account',
        );
      }
      await this.owners.marketplace.linkClaimedListingInTransaction(
        tx,
        current.providerId,
        current.userId,
      );
      const decided = await this.owners.marketplace.decideClaimRequestInTransaction(
        tx,
        id,
        {
          status: ProviderClaimStatus.APPROVED,
          note: null,
          decidedAt: new Date(),
          decidedById: currentUser.id,
        },
      );
      await this.notifications.createNotificationInTransaction(tx, {
        userId: current.userId,
        type: NotificationType.GENERAL,
        priority: NotificationPriority.NORMAL,
        title: 'انقبل استلامك للملف',
        body: `صار ملف ${decided.provider.businessName} لك. كمّل ملفك وابدأ استقبل طلبات العرسان.`,
        entityType: 'Provider',
        entityId: current.providerId,
        routeTarget: '/provider/dashboard',
        data: {
          providerId: current.providerId,
          claimRequestId: id,
          claimStatus: ProviderClaimStatus.APPROVED,
        },
        dedupeKey: `provider-claim:${id}:${ProviderClaimStatus.APPROVED}`,
      });
      return (await this.owners.attachClaimRequests(tx, [decided]))[0]!;
    });
    return toAdminClaimRequestResponse(claim);
  }

  async reject(currentUser: AuthenticatedUser, id: string, note: string) {
    const claim = await runSerializableTransaction(this.prisma, async (tx) => {
      const { current } = await this.lockPendingClaim(tx, currentUser, id);
      const decided = await this.owners.marketplace.decideClaimRequestInTransaction(
        tx,
        id,
        {
          status: ProviderClaimStatus.REJECTED,
          note,
          decidedAt: new Date(),
          decidedById: currentUser.id,
        },
      );
      await this.notifications.createNotificationInTransaction(tx, {
        userId: current.userId,
        type: NotificationType.GENERAL,
        priority: NotificationPriority.HIGH,
        title: 'ما قبلنا الاستلام',
        body: note,
        entityType: 'ProviderClaimRequest',
        entityId: id,
        routeTarget: '/provider/apply',
        data: {
          providerId: current.providerId,
          claimRequestId: id,
          claimStatus: ProviderClaimStatus.REJECTED,
        },
        dedupeKey: `provider-claim:${id}:${ProviderClaimStatus.REJECTED}`,
      });
      return (await this.owners.attachClaimRequests(tx, [decided]))[0]!;
    });
    return toAdminClaimRequestResponse(claim);
  }

  /** Locks the administrator, the claimant and the claim, which must still wait. */
  private async lockPendingClaim(
    tx: Prisma.TransactionClient,
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<{
    current: ProviderClaimRequest;
    claimant: Awaited<ReturnType<typeof lockProviderReviewAccountsInTransaction>>;
  }> {
    const parties = await this.owners.marketplace.findClaimRequestParties(tx, id);
    if (!parties) throw new NotFoundException(CLAIM_NOT_FOUND);
    if (parties.userId === currentUser.id) {
      throw new BadRequestException('Administrators cannot review their own claim');
    }
    const claimant = await lockProviderReviewAccountsInTransaction(
      tx,
      this.owners,
      currentUser,
      parties.userId,
      CLAIM_NOT_FOUND,
    );
    const current =
      await this.owners.marketplace.lockClaimRequestForUpdateInTransaction(tx, id);
    if (!current || current.userId !== parties.userId) {
      throw new NotFoundException(CLAIM_NOT_FOUND);
    }
    if (current.status !== ProviderClaimStatus.PENDING) {
      throw new ConflictException({
        statusCode: 409,
        code: 'PROVIDER_CLAIM_NOT_PENDING',
        message: 'The claim was already decided',
      });
    }
    return { current, claimant };
  }
}
