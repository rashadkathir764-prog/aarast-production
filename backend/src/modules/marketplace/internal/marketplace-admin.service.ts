import { Injectable } from '@nestjs/common';
import { Prisma, type Provider, ProviderStatus, ReviewStatus } from '@prisma/client';
import type {
  AdminListedProviderFields,
  AdminListing,
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
import { MarketplaceAdminRepository } from '../infrastructure/marketplace-admin.repository';

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
  ): Promise<{ userId: string | null; status: ProviderStatus } | null> {
    return this.repository.lockProviderForUpdateInTransaction(tx, providerId);
  }

  async recordProviderReviewInTransaction(
    tx: Prisma.TransactionClient,
    providerId: string,
    decision: ProviderReviewDecision,
  ): Promise<AdminProviderDetailRow> {
    return this.repository.recordProviderReviewInTransaction(tx, providerId, decision);
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
}
