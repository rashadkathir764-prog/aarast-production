import type {
  Prisma,
  Provider,
  ProviderPackage,
  ProviderReview,
  ProviderService,
  ProviderServiceImage,
  ProviderStatus,
  QuoteRequestStatus,
  ReviewStatus,
} from '@prisma/client';

export const MARKETPLACE_ADMIN_PORT = Symbol('MARKETPLACE_ADMIN_PORT');

export interface AdminProviderCounts {
  services: number;
  packages: number;
  quoteRequests: number;
  reviews: number;
}

export type AdminProviderRow = Provider & { _count: AdminProviderCounts };

export type AdminProviderServiceRow = ProviderService & {
  images: ProviderServiceImage[];
};

export type AdminProviderDetailRow = AdminProviderRow & {
  services: AdminProviderServiceRow[];
  packages: Array<ProviderPackage & { service: ProviderService | null }>;
};

export type AdminServiceRow = ProviderService & {
  provider: Provider;
  images: ProviderServiceImage[];
};

export type AdminReviewRow = ProviderReview & { provider: Provider };

export interface AdminPage {
  skip: number;
  take: number;
}

export interface AdminListing<T> {
  total: number;
  items: T[];
}

/**
 * A back-office text search: `text` is matched against marketplace's own
 * columns, `userIds` are the accounts identity matched for the same text
 * (the provider's or reviewer's account).
 */
export interface AdminTextSearch {
  text: string;
  userIds: readonly string[];
}

export interface AdminProviderFilter {
  statuses: readonly ProviderStatus[];
  cityId: string | null;
  /** The primary category, or any service's category. */
  categoryId: string | null;
  search: AdminTextSearch | null;
}

export interface AdminServiceFilter {
  isActive?: boolean;
  isFeatured?: boolean;
  providerId?: string;
  categoryId?: string;
  /** The service's own city, or the provider's when the service has none. */
  cityId?: string;
  search?: string;
}

export interface AdminReviewFilter {
  status?: ReviewStatus;
  providerId?: string;
  search?: AdminTextSearch;
}

export interface AdminServiceFields {
  providerId: string;
  categoryId: string;
  title: string;
  description: string | null;
  basePrice: string | null;
  priceUnit: string | null;
  currency: string;
  cityId: string | null;
  isActive: boolean;
  isFeatured: boolean;
}

export type AdminServiceChanges = Partial<Omit<AdminServiceFields, 'providerId'>>;

export interface ProviderReviewDecision {
  status: ProviderStatus;
  reviewNote: string | null;
  reviewedAt: Date;
  reviewedById: string;
}

export interface ProviderVerification {
  verifiedAt: Date | null;
  verifiedById: string | null;
}

export interface AdminMarketplaceCounters {
  totalProviders: number;
  pendingProviders: number;
  approvedProviders: number;
  rejectedProviders: number;
  needsChangesProviders: number;
  suspendedProviders: number;
  totalQuoteRequests: number;
}

export interface AdminMarketplaceReport {
  providers: {
    total: number;
    pending: number;
    active: number;
    needsChanges: number;
    suspended: number;
    rejected: number;
    featured: number;
  };
  services: {
    total: number;
    active: number;
    disabled: number;
    featured: number;
  };
  reviews: {
    total: number;
    published: number;
    hidden: number;
    pending: number;
    averageRating: number | null;
  };
  quotes: Array<{ status: QuoteRequestStatus; count: number }>;
}

/** How many providers and services reference a catalog entry. */
export interface CatalogUsage {
  id: string;
  providers: number;
  services: number;
}

// Marketplace owns providers, their services, packages and reviews, and the
// quote requests. The back office lists, reviews and moderates them through
// this port on the client it passes (its authorized serializable
// transaction, or the shared Prisma service); the catalog entries and the
// accounts the rows reference are attached by the back office from their
// owners.
export interface MarketplaceAdminPort {
  getCounters(client: Prisma.TransactionClient): Promise<AdminMarketplaceCounters>;
  getReport(
    client: Prisma.TransactionClient,
    createdAt?: { gte?: Date; lte?: Date },
  ): Promise<AdminMarketplaceReport>;
  /** Newest first. */
  listProviders(
    client: Prisma.TransactionClient,
    filter: AdminProviderFilter,
    page: AdminPage,
  ): Promise<AdminListing<AdminProviderRow>>;
  getProvider(
    client: Prisma.TransactionClient,
    providerId: string,
  ): Promise<AdminProviderDetailRow | null>;
  /** The providers the accounts own (an account owns at most one). */
  getAccountProviders(
    client: Prisma.TransactionClient,
    userIds: readonly string[],
  ): Promise<Provider[]>;
  /** The provider's account; null when the provider does not exist. */
  findProviderAccount(
    client: Prisma.TransactionClient,
    providerId: string,
  ): Promise<{ userId: string | null } | null>;
  /** Locks the provider FOR UPDATE; its account and status, null when it does not exist. */
  lockProviderForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    providerId: string,
  ): Promise<{ userId: string | null; status: ProviderStatus } | null>;
  recordProviderReviewInTransaction(
    tx: Prisma.TransactionClient,
    providerId: string,
    decision: ProviderReviewDecision,
  ): Promise<AdminProviderDetailRow>;
  /** Records that an admin checked the provider's documents, or clears it with nulls. */
  recordProviderVerificationInTransaction(
    tx: Prisma.TransactionClient,
    providerId: string,
    verification: ProviderVerification,
  ): Promise<AdminProviderDetailRow>;
  /** Locks the provider FOR SHARE; false when it does not exist. */
  lockProviderForShareInTransaction(
    tx: Prisma.TransactionClient,
    providerId: string,
  ): Promise<boolean>;
  /** Featured first, then newest. */
  listServices(
    client: Prisma.TransactionClient,
    filter: AdminServiceFilter,
    page: AdminPage,
  ): Promise<AdminListing<AdminServiceRow>>;
  findServiceProviderId(
    client: Prisma.TransactionClient,
    serviceId: string,
  ): Promise<string | null>;
  /** Locks the service FOR UPDATE; false unless it exists under the provider. */
  lockServiceForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    serviceId: string,
    providerId: string,
  ): Promise<boolean>;
  createServiceInTransaction(
    tx: Prisma.TransactionClient,
    fields: AdminServiceFields,
  ): Promise<AdminServiceRow>;
  updateServiceInTransaction(
    tx: Prisma.TransactionClient,
    serviceId: string,
    changes: AdminServiceChanges,
  ): Promise<AdminServiceRow>;
  /** Newest first. */
  listReviews(
    client: Prisma.TransactionClient,
    filter: AdminReviewFilter,
    page: AdminPage,
  ): Promise<AdminListing<AdminReviewRow>>;
  findReviewProviderId(
    client: Prisma.TransactionClient,
    reviewId: string,
  ): Promise<string | null>;
  /**
   * Locks the review FOR UPDATE; false unless it exists under the provider.
   * The moderator takes the provider's rating lock
   * (`provider-review-rating.ts`) first and refreshes the rating after the
   * status change.
   */
  lockReviewForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    reviewId: string,
    providerId: string,
  ): Promise<boolean>;
  setReviewStatusInTransaction(
    tx: Prisma.TransactionClient,
    reviewId: string,
    status: ReviewStatus,
  ): Promise<AdminReviewRow>;
  countCategoryUsage(
    client: Prisma.TransactionClient,
    categoryIds: readonly string[],
  ): Promise<CatalogUsage[]>;
  countCityUsage(
    client: Prisma.TransactionClient,
    cityIds: readonly string[],
  ): Promise<CatalogUsage[]>;
}
