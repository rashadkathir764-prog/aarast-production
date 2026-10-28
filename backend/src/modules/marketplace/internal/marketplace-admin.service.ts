import { Injectable } from '@nestjs/common';
import {
  Prisma,
  type Provider,
  type ProviderClaimRequest,
  ProviderStatus,
  ReviewStatus,
} from '@prisma/client';
import type {
  AdminActiveFeaturedPeriod,
  AdminClaimRequestFilter,
  AdminClaimRequestRow,
  AdminFeaturedPeriodFilter,
  AdminFeaturedPeriodRow,
  AdminFeaturedSummary,
  FeaturedPeriodEndFields,
  FeaturedPeriodGrantFields,
  AdminListedProviderFields,
  AdminListing,
  AdminProviderReviewEvent,
  ProviderClaimDecision,
  AdminMarketplaceSuccessCounts,
  AdminMarketplaceCounters,
  AdminMarketplaceReport,
  AdminPage,
  AdminProviderDetailRow,
  AdminProviderFilter,
  AdminProviderRow,
  AdminReviewFilter,
  AdminReviewRow,
  AdminServiceChanges,
  AdminServiceFields,
  AdminServiceFilter,
  AdminServiceRow,
  CatalogUsage,
  MarketplaceAdminPort,
  ProviderReviewDecision,
  ProviderVerification,
} from '../public/marketplace-admin.port';
import type { PricedService } from '../public/market-prices';
import type {
  AdminBookingFilter,
  AdminBookingRow,
} from '../public/marketplace-admin.port';
import type { CreateNotificationInput } from '../../notifications/public/notifications.port';
import { MarketplaceAdminRepository } from '../infrastructure/marketplace-admin.repository';
import type { PortfolioItemStatus } from '@prisma/client';
import type {
  AdminPortfolioDecision,
  AdminPortfolioRow,
} from '../public/marketplace-admin.port';

@Injectable()
export class MarketplaceAdminService implements MarketplaceAdminPort {
  private readonly repository = new MarketplaceAdminRepository();

  async getCounters(
    client: Prisma.TransactionClient,
  ): Promise<AdminMarketplaceCounters> {
    return this.repository.getCounters(client);
  }

  async getReport(
    client: Prisma.TransactionClient,
    createdAt?: { gte?: Date; lte?: Date },
  ): Promise<AdminMarketplaceReport> {
    return this.repository.getReport(client, createdAt);
  }

  async listProviders(
    client: Prisma.TransactionClient,
    filter: AdminProviderFilter,
    page: AdminPage,
  ): Promise<AdminListing<AdminProviderRow>> {
    return this.repository.listProviders(client, filter, page);
  }

  async getProvider(
    client: Prisma.TransactionClient,
    providerId: string,
  ): Promise<AdminProviderDetailRow | null> {
    return this.repository.getProvider(client, providerId);
  }

  async getAccountProviders(
    client: Prisma.TransactionClient,
    userIds: readonly string[],
  ): Promise<Provider[]> {
    return this.repository.getAccountProviders(client, userIds);
  }

  async findProviderAccount(
    client: Prisma.TransactionClient,
    providerId: string,
  ): Promise<{ userId: string | null } | null> {
    return this.repository.findProviderAccount(client, providerId);
  }

  async lockProviderForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    providerId: string,
  ): Promise<{ userId: string | null; status: ProviderStatus; phone: string } | null> {
    return this.repository.lockProviderForUpdateInTransaction(tx, providerId);
  }

  async hasJoiningService(
    client: Prisma.TransactionClient,
    providerId: string,
  ): Promise<boolean> {
    return this.repository.hasJoiningService(client, providerId);
  }

  async settleBookingsOnSuspensionInTransaction(
    tx: Prisma.TransactionClient,
    providerId: string,
    suspendedAt: Date,
  ): Promise<CreateNotificationInput[]> {
    return this.repository.settleBookingsOnSuspensionInTransaction(
      tx,
      providerId,
      suspendedAt,
    );
  }

  async listBookings(
    client: Prisma.TransactionClient,
    filter: AdminBookingFilter,
    page: AdminPage,
  ): Promise<AdminListing<AdminBookingRow>> {
    return this.repository.listBookings(client, filter, page);
  }

  async getBooking(
    client: Prisma.TransactionClient,
    id: string,
  ): Promise<AdminBookingRow | null> {
    return this.repository.getBooking(client, id);
  }

  async listPortfolioForReview(
    client: Prisma.TransactionClient,
    status: PortfolioItemStatus,
    page: AdminPage,
  ): Promise<AdminListing<AdminPortfolioRow>> {
    return this.repository.listPortfolioForReview(client, status, page);
  }

  async lockPortfolioItemInTransaction(
    tx: Prisma.TransactionClient,
    id: string,
  ): Promise<AdminPortfolioRow | null> {
    return this.repository.lockPortfolioItemInTransaction(tx, id);
  }

  async decidePortfolioItemInTransaction(
    tx: Prisma.TransactionClient,
    id: string,
    decision: AdminPortfolioDecision,
  ): Promise<AdminPortfolioRow | null> {
    return this.repository.decidePortfolioItemInTransaction(tx, id, decision);
  }

  async recordProviderReviewInTransaction(
    tx: Prisma.TransactionClient,
    providerId: string,
    decision: ProviderReviewDecision,
  ): Promise<AdminProviderDetailRow> {
    return this.repository.recordProviderReviewInTransaction(tx, providerId, decision);
  }

  async listProviderReviewEvents(
    client: Prisma.TransactionClient,
    providerId: string,
  ): Promise<AdminProviderReviewEvent[]> {
    return this.repository.listProviderReviewEvents(client, providerId);
  }

  async listClaimRequests(
    client: Prisma.TransactionClient,
    filter: AdminClaimRequestFilter,
    page: AdminPage,
  ): Promise<AdminListing<AdminClaimRequestRow>> {
    return this.repository.listClaimRequests(client, filter, page);
  }

  async findClaimRequestParties(
    client: Prisma.TransactionClient,
    claimId: string,
  ): Promise<{ userId: string; providerId: string } | null> {
    return this.repository.findClaimRequestParties(client, claimId);
  }

  async lockClaimRequestForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    claimId: string,
  ): Promise<ProviderClaimRequest | null> {
    return this.repository.lockClaimRequestForUpdateInTransaction(tx, claimId);
  }

  async decideClaimRequestInTransaction(
    tx: Prisma.TransactionClient,
    claimId: string,
    decision: ProviderClaimDecision,
  ): Promise<AdminClaimRequestRow> {
    return this.repository.decideClaimRequestInTransaction(tx, claimId, decision);
  }

  async linkClaimedListingInTransaction(
    tx: Prisma.TransactionClient,
    providerId: string,
    userId: string,
  ): Promise<void> {
    return this.repository.linkClaimedListingInTransaction(tx, providerId, userId);
  }

  async recordProviderVerificationInTransaction(
    tx: Prisma.TransactionClient,
    providerId: string,
    verification: ProviderVerification,
  ): Promise<AdminProviderDetailRow> {
    return this.repository.recordProviderVerificationInTransaction(
      tx,
      providerId,
      verification,
    );
  }

  async getSuccessCounts(
    client: Prisma.TransactionClient,
    since: Date,
  ): Promise<AdminMarketplaceSuccessCounts> {
    return this.repository.getSuccessCounts(client, since);
  }

  async listPricedServices(client: Prisma.TransactionClient): Promise<PricedService[]> {
    return this.repository.listPricedServices(client);
  }

  async hasProviderWithPhone(
    client: Prisma.TransactionClient,
    phones: readonly string[],
  ): Promise<boolean> {
    return this.repository.hasProviderWithPhone(client, phones);
  }

  async createListedProviderInTransaction(
    tx: Prisma.TransactionClient,
    fields: AdminListedProviderFields,
  ): Promise<AdminProviderDetailRow> {
    return this.repository.createListedProviderInTransaction(tx, fields);
  }

  async lockProviderForShareInTransaction(
    tx: Prisma.TransactionClient,
    providerId: string,
  ): Promise<boolean> {
    return this.repository.lockProviderForShareInTransaction(tx, providerId);
  }

  async listServices(
    client: Prisma.TransactionClient,
    filter: AdminServiceFilter,
    page: AdminPage,
  ): Promise<AdminListing<AdminServiceRow>> {
    return this.repository.listServices(client, filter, page);
  }

  async findServiceProviderId(
    client: Prisma.TransactionClient,
    serviceId: string,
  ): Promise<string | null> {
    return this.repository.findServiceProviderId(client, serviceId);
  }

  async lockServiceForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    serviceId: string,
    providerId: string,
  ): Promise<boolean> {
    return this.repository.lockServiceForUpdateInTransaction(tx, serviceId, providerId);
  }

  async createServiceInTransaction(
    tx: Prisma.TransactionClient,
    fields: AdminServiceFields,
  ): Promise<AdminServiceRow> {
    return this.repository.createServiceInTransaction(tx, fields);
  }

  async updateServiceInTransaction(
    tx: Prisma.TransactionClient,
    serviceId: string,
    changes: AdminServiceChanges,
  ): Promise<AdminServiceRow> {
    return this.repository.updateServiceInTransaction(tx, serviceId, changes);
  }

  async listReviews(
    client: Prisma.TransactionClient,
    filter: AdminReviewFilter,
    page: AdminPage,
  ): Promise<AdminListing<AdminReviewRow>> {
    return this.repository.listReviews(client, filter, page);
  }

  async findReviewProviderId(
    client: Prisma.TransactionClient,
    reviewId: string,
  ): Promise<string | null> {
    return this.repository.findReviewProviderId(client, reviewId);
  }

  async lockReviewForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    reviewId: string,
    providerId: string,
  ): Promise<boolean> {
    return this.repository.lockReviewForUpdateInTransaction(tx, reviewId, providerId);
  }

  async setReviewStatusInTransaction(
    tx: Prisma.TransactionClient,
    reviewId: string,
    status: ReviewStatus,
  ): Promise<AdminReviewRow> {
    return this.repository.setReviewStatusInTransaction(tx, reviewId, status);
  }

  async setReviewReplyStatusInTransaction(
    tx: Prisma.TransactionClient,
    reviewId: string,
    status: ReviewStatus,
  ): Promise<AdminReviewRow | null> {
    return this.repository.setReviewReplyStatusInTransaction(tx, reviewId, status);
  }

  async countCategoryUsage(
    client: Prisma.TransactionClient,
    categoryIds: readonly string[],
  ): Promise<CatalogUsage[]> {
    return this.repository.countCategoryUsage(client, categoryIds);
  }

  async countCityUsage(
    client: Prisma.TransactionClient,
    cityIds: readonly string[],
  ): Promise<CatalogUsage[]> {
    return this.repository.countCityUsage(client, cityIds);
  }

  async listFeaturedPeriods(
    client: Prisma.TransactionClient,
    filter: AdminFeaturedPeriodFilter,
    page: AdminPage,
    now: Date,
  ): Promise<AdminListing<AdminFeaturedPeriodRow>> {
    return this.repository.listFeaturedPeriods(client, filter, page, now);
  }

  async getFeaturedSummary(
    client: Prisma.TransactionClient,
    now: Date,
    weekEnd: Date,
  ): Promise<AdminFeaturedSummary> {
    return this.repository.getFeaturedSummary(client, now, weekEnd);
  }

  async listFeaturedShownProviderIds(
    client: Prisma.TransactionClient,
    providerIds: readonly string[],
  ): Promise<string[]> {
    return this.repository.listFeaturedShownProviderIds(client, providerIds);
  }

  async listActiveFeaturedPeriods(
    client: Prisma.TransactionClient,
    providerIds: readonly string[],
    now: Date,
  ): Promise<AdminActiveFeaturedPeriod[]> {
    return this.repository.listActiveFeaturedPeriods(client, providerIds, now);
  }

  async findOverlappingFeaturedPeriod(
    tx: Prisma.TransactionClient,
    providerId: string,
    startsAt: Date,
    endsAt: Date,
  ): Promise<{ id: string; startsAt: Date; endsAt: Date } | null> {
    return this.repository.findOverlappingFeaturedPeriod(tx, providerId, startsAt, endsAt);
  }

  async createFeaturedPeriodInTransaction(
    tx: Prisma.TransactionClient,
    fields: FeaturedPeriodGrantFields,
  ): Promise<AdminFeaturedPeriodRow> {
    return this.repository.createFeaturedPeriodInTransaction(tx, fields);
  }

  async lockFeaturedPeriodForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    periodId: string,
  ): Promise<AdminFeaturedPeriodRow | null> {
    return this.repository.lockFeaturedPeriodForUpdateInTransaction(tx, periodId);
  }

  async endFeaturedPeriodInTransaction(
    tx: Prisma.TransactionClient,
    periodId: string,
    fields: FeaturedPeriodEndFields,
  ): Promise<AdminFeaturedPeriodRow | null> {
    return this.repository.endFeaturedPeriodInTransaction(tx, periodId, fields);
  }
}
