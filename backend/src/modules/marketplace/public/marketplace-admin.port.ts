import type {
  Prisma,
  Provider,
  ProviderClaimRequest,
  ProviderClaimStatus,
  ProviderFeaturedPeriod,
  ProviderPackage,
  ProviderReview,
  ProviderReviewEvent,
  ProviderReviewEventKind,
  ProviderReviewNote,
  ProviderService,
  ProviderServiceImage,
  ProviderStatus,
  QuoteRequestStatus,
  ReviewStatus,
} from '@prisma/client';
import type { PricedService } from './market-prices';
import type { ProviderFieldNote } from './provider-review';

export const MARKETPLACE_ADMIN_PORT = Symbol('MARKETPLACE_ADMIN_PORT');

export interface AdminProviderCounts {
  services: number;
  packages: number;
  quoteRequests: number;
  reviews: number;
}

/** A review step with the notes written with it (B-01, B-02). */
export type AdminProviderReviewEvent = ProviderReviewEvent & {
  notes: ProviderReviewNote[];
};

/**
 * A provider row with its counts and its latest administrator decision
 * (at most one event), whose notes are the current ones.
 */
export type AdminProviderRow = Provider & {
  _count: AdminProviderCounts;
  reviewEvents: AdminProviderReviewEvent[];
};

/** A claim of a listing (B-12) with the listing it asks for. */
export type AdminClaimRequestRow = ProviderClaimRequest & { provider: Provider };

export interface AdminClaimRequestFilter {
  status: ProviderClaimStatus | null;
}

export interface ProviderClaimDecision {
  status: ProviderClaimStatus;
  note: string | null;
  decidedAt: Date;
  decidedById: string;
}

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
  /** True: only providers that sent the profile back after changes (B-01); false: only the others. */
  resubmitted: boolean | null;
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

/** An administrator's decision: the new status and the review step it records with its notes. */
export interface ProviderReviewDecision {
  status: ProviderStatus;
  kind: ProviderReviewEventKind;
  notes: readonly ProviderFieldNote[];
  reviewedAt: Date;
  reviewedById: string;
}

/**
 * A listing an administrator creates before the provider has an account
 * (V1 checklist 4.18): it is ACTIVE at once, and the provider claims it
 * later by signing in with the same verified phone.
 */
export interface AdminListedProviderFields {
  businessName: string;
  phone: string;
  whatsapp: string | null;
  cityId: string;
  primaryCategoryId: string;
  description: string | null;
  address: string | null;
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
  /** PENDING providers that sent the profile back after changes (B-01). */
  resubmittedProviders: number;
  /** Claims of a listing waiting for an administrator (B-12). */
  pendingClaims: number;
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

/** The marketplace's part of the success indicators (V1 checklist 4.21). */
export interface AdminMarketplaceSuccessCounts {
  /** Quote requests created since the window start. */
  quoteRequests: number;
  /** Bookings created since the window start that are confirmed (or done). */
  confirmedBookings: number;
  /** Active providers with at least one active service: the ones customers see. */
  visibleProviders: number;
}


/** A featured placement (B-43) with the provider it ranks first. */
export type AdminFeaturedPeriodRow = ProviderFeaturedPeriod & { provider: Provider };

/**
 * CURRENT: active or booked to start; ACTIVE: covers now; SCHEDULED: starts
 * later; FINISHED: reached its end or ended by an administrator.
 */
export type AdminFeaturedPeriodState = 'CURRENT' | 'ACTIVE' | 'SCHEDULED' | 'FINISHED';

export interface AdminFeaturedPeriodFilter {
  state: AdminFeaturedPeriodState | null;
  providerId: string | null;
}

export interface AdminFeaturedSummary {
  /** Active providers with an active service: the ones customers see. */
  listedProviders: number;
  /** Of those, featured now. */
  featured: number;
  /** Active placements that end within the week with nothing booked after. */
  endingSoon: number;
}

export interface AdminActiveFeaturedPeriod {
  providerId: string;
  startsAt: Date;
  endsAt: Date;
}

export interface FeaturedPeriodGrantFields {
  providerId: string;
  startsAt: Date;
  endsAt: Date;
  note: string | null;
  grantedById: string;
}

export interface FeaturedPeriodEndFields {
  endedAt: Date;
  endedById: string;
  endNote: string | null;
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
  /** Locks the provider FOR UPDATE; its account, status and phone, null when it does not exist. */
  lockProviderForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    providerId: string,
  ): Promise<{ userId: string | null; status: ProviderStatus; phone: string } | null>;
  /** The joining rule (B-10, D41): whether the provider has an active service priced above zero. */
  hasJoiningService(
    client: Prisma.TransactionClient,
    providerId: string,
  ): Promise<boolean>;
  /** Sets the status and records the decision with its notes in the review history. */
  recordProviderReviewInTransaction(
    tx: Prisma.TransactionClient,
    providerId: string,
    decision: ProviderReviewDecision,
  ): Promise<AdminProviderDetailRow>;
  /** Every review step of the provider, oldest first (B-01, B-02). */
  listProviderReviewEvents(
    client: Prisma.TransactionClient,
    providerId: string,
  ): Promise<AdminProviderReviewEvent[]>;
  /** Claims of listings (B-12), oldest first. */
  listClaimRequests(
    client: Prisma.TransactionClient,
    filter: AdminClaimRequestFilter,
    page: AdminPage,
  ): Promise<AdminListing<AdminClaimRequestRow>>;
  /** The claim's account and listing; null when it does not exist. */
  findClaimRequestParties(
    client: Prisma.TransactionClient,
    claimId: string,
  ): Promise<{ userId: string; providerId: string } | null>;
  /** Locks the claim FOR UPDATE; null when it does not exist. */
  lockClaimRequestForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    claimId: string,
  ): Promise<ProviderClaimRequest | null>;
  decideClaimRequestInTransaction(
    tx: Prisma.TransactionClient,
    claimId: string,
    decision: ProviderClaimDecision,
  ): Promise<AdminClaimRequestRow>;
  /** Hands a locked, unclaimed listing to the account an administrator approved. */
  linkClaimedListingInTransaction(
    tx: Prisma.TransactionClient,
    providerId: string,
    userId: string,
  ): Promise<void>;
  /** Records that an admin checked the provider's documents, or clears it with nulls. */
  recordProviderVerificationInTransaction(
    tx: Prisma.TransactionClient,
    providerId: string,
    verification: ProviderVerification,
  ): Promise<AdminProviderDetailRow>;
  /** Whether any provider already lists one of these spellings of a phone. */
  hasProviderWithPhone(
    client: Prisma.TransactionClient,
    phones: readonly string[],
  ): Promise<boolean>;
  /** Creates an ACTIVE provider with no account, for its owner to claim (V1 4.18). */
  createListedProviderInTransaction(
    tx: Prisma.TransactionClient,
    fields: AdminListedProviderFields,
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
  getSuccessCounts(
    client: Prisma.TransactionClient,
    since: Date,
  ): Promise<AdminMarketplaceSuccessCounts>;
  listPricedServices(client: Prisma.TransactionClient): Promise<PricedService[]>;
  countCategoryUsage(
    client: Prisma.TransactionClient,
    categoryIds: readonly string[],
  ): Promise<CatalogUsage[]>;
  countCityUsage(
    client: Prisma.TransactionClient,
    cityIds: readonly string[],
  ): Promise<CatalogUsage[]>;
  /** Featured placements (B-43), latest start first. */
  listFeaturedPeriods(
    client: Prisma.TransactionClient,
    filter: AdminFeaturedPeriodFilter,
    page: AdminPage,
    now: Date,
  ): Promise<AdminListing<AdminFeaturedPeriodRow>>;
  /** a17's counts at `now`; `endingSoon` ends before `weekEnd` with nothing booked after it. */
  getFeaturedSummary(
    client: Prisma.TransactionClient,
    now: Date,
    weekEnd: Date,
  ): Promise<AdminFeaturedSummary>;
  /** Each provider's period active at `now` (at most one per provider). */
  listActiveFeaturedPeriods(
    client: Prisma.TransactionClient,
    providerIds: readonly string[],
    now: Date,
  ): Promise<AdminActiveFeaturedPeriod[]>;
  /** A period of the provider, not ended, that overlaps [startsAt, endsAt); null when none. */
  findOverlappingFeaturedPeriod(
    tx: Prisma.TransactionClient,
    providerId: string,
    startsAt: Date,
    endsAt: Date,
  ): Promise<{ id: string; startsAt: Date; endsAt: Date } | null>;
  /** Records a placement; the caller holds the provider's row lock. */
  createFeaturedPeriodInTransaction(
    tx: Prisma.TransactionClient,
    fields: FeaturedPeriodGrantFields,
  ): Promise<AdminFeaturedPeriodRow>;
  /** Locks the period FOR UPDATE; null when it does not exist. */
  lockFeaturedPeriodForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    periodId: string,
  ): Promise<AdminFeaturedPeriodRow | null>;
  /** Ends a period nobody ended yet (the provider is told now); null when it was already ended. */
  endFeaturedPeriodInTransaction(
    tx: Prisma.TransactionClient,
    periodId: string,
    fields: FeaturedPeriodEndFields,
  ): Promise<AdminFeaturedPeriodRow | null>;
}
