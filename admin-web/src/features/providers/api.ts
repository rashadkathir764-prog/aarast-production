import type { AdminUser } from '../auth/api';
import { apiRequest } from '../../platform/api/client';
import { type Paginated, toQuery } from '../../platform/api/query';

export type CityProjection = {
  id: string;
  nameAr: string;
  nameEn: string | null;
  countryCode: string;
  isActive: boolean;
  sortOrder: number;
  providersCount?: number;
  servicesCount?: number;
};

export type ProviderCategoryProjection = {
  id: string;
  nameAr: string;
  nameEn: string | null;
  slug: string;
  icon: string | null;
  showForGroom: boolean;
  showForBride: boolean;
  isActive: boolean;
  sortOrder: number;
  providersCount?: number;
  servicesCount?: number;
};

export type ProviderServiceProjection = {
  id: string;
  providerId?: string;
  provider?: ProviderReference;
  categoryId?: string;
  title: string;
  description: string | null;
  basePrice: string | null;
  priceUnit: string | null;
  currency: string;
  cityId?: string | null;
  isActive: boolean;
  category?: ProviderCategoryProjection;
  city?: CityProjection | null;
  images?: Array<{ id: string; serviceId: string; imageUrl: string; altText: string | null; sortOrder: number; createdAt: string }>;
  createdAt?: string;
  updatedAt?: string;
};

export type ProviderPackageProjection = {
  id: string;
  title: string;
  description: string | null;
  price: string | null;
  currency: string;
  items: unknown;
  isActive: boolean;
  service?: { id: string; title: string } | null;
};

export type ProviderReference = {
  id: string;
  businessName: string;
  phone: string;
  whatsapp: string | null;
  logoUrl: string | null;
  status: string;
  ratingAverage: string;
  ratingCount: number;
  city?: CityProjection | null;
  primaryCategory?: ProviderCategoryProjection | null;
};

export type ProviderApplication = {
  id: string;
  userId: string | null;
  user: AdminUser | null;
  cityId: string;
  city: CityProjection | null;
  primaryCategoryId: string | null;
  primaryCategory: ProviderCategoryProjection | null;
  businessName: string;
  ownerName: string | null;
  phone: string;
  whatsapp: string | null;
  email: string | null;
  description: string | null;
  address: string | null;
  logoUrl: string | null;
  coverUrl: string | null;
  status: string;
  /** The current decision's note about the whole profile (B-01). */
  reviewNote: string | null;
  /** The current decision's note on each field to fix (B-01). */
  fieldNotes: ProviderFieldNote[];
  /** The latest administrator decision; null when none was taken. */
  latestDecision: { id: string; kind: ProviderReviewEvent['kind']; at: string } | null;
  /** When the provider last sent the profile back after changes, and how often (B-01). */
  resubmittedAt: string | null;
  resubmitCount: number;
  /** When a refused provider last reopened the profile (B-02). */
  reopenedAt: string | null;
  reviewedAt: string | null;
  reviewedBy: AdminUser | null;
  /** When an admin checked the provider's documents; null when not verified. */
  verifiedAt: string | null;
  /** Featured now: a recorded placement covers this moment (B-43). */
  isFeatured: boolean;
  /** When that placement ends; null when not featured. */
  featuredUntil: string | null;
  ratingAverage: string;
  ratingCount: number;
  servicesCount: number;
  packagesCount: number;
  quoteRequestsCount: number;
  reviewsCount: number;
  services?: ProviderServiceProjection[];
  packages?: ProviderPackageProjection[];
  createdAt: string;
  updatedAt: string;
};

/** The fields a review note can point at (B-01). */
export type ProviderReviewField =
  | 'BUSINESS_NAME'
  | 'CATEGORY'
  | 'CITY'
  | 'DESCRIPTION'
  | 'SERVICE';

export type ProviderFieldNote = { field: ProviderReviewField; note: string };

/** One step of the review (B-01, B-02), oldest first. */
export type ProviderReviewEvent = {
  id: string;
  kind:
    | 'CHANGES_REQUESTED'
    | 'REJECTED'
    | 'APPROVED'
    | 'SUSPENDED'
    | 'ACTIVATED'
    | 'RESUBMITTED'
    | 'REOPENED';
  at: string;
  actor: { id: string; name: string } | null;
  notes: Array<{ field: ProviderReviewField | 'GENERAL'; note: string }>;
};

export type ProviderReviewHistory = {
  providerId: string;
  appliedAt: string;
  events: ProviderReviewEvent[];
};

/**
 * A profile sent back for review came from a refusal (B-02) when the
 * decision before the send was the refusal; a reopened refusal the team
 * then asked to change came from changes (B-01), like any other.
 */
export function sentBackAfterRefusal(
  provider: Pick<ProviderApplication, 'latestDecision'>,
): boolean {
  return provider.latestDecision?.kind === 'REJECTED';
}

export type ProviderQueryParams = {
  status?: string;
  cityId?: string;
  categoryId?: string;
  search?: string;
  /** Only the profiles sent back after changes (`true`), or the others (`false`). */
  resubmitted?: boolean;
  page?: number;
  limit?: number;
};

export function getProviderApplications(
  params?: ProviderQueryParams,
): Promise<Paginated<ProviderApplication>> {
  return apiRequest<Paginated<ProviderApplication>>(
    `/admin/providers/applications${toQuery(params ?? {})}`,
  );
}

export function getProviderApplication(id: string): Promise<ProviderApplication> {
  return apiRequest<ProviderApplication>(`/admin/providers/applications/${id}`);
}

export function getProviders(
  params?: ProviderQueryParams,
): Promise<Paginated<ProviderApplication>> {
  return apiRequest<Paginated<ProviderApplication>>(
    `/admin/providers${toQuery(params ?? {})}`,
  );
}

/** A provider listed before its owner has an account (V1 checklist 4.18). */
export type ListedProviderInput = {
  businessName: string;
  phone: string;
  whatsapp: string | null;
  cityId: string;
  categoryId: string;
  address: string | null;
  description: string | null;
};

export function createListedProvider(
  input: ListedProviderInput,
): Promise<ProviderApplication> {
  return apiRequest<ProviderApplication>('/admin/providers', {
    method: 'POST',
    body: input,
  });
}

export function getProvider(id: string): Promise<ProviderApplication> {
  return apiRequest<ProviderApplication>(`/admin/providers/${id}`);
}

export function approveProvider(id: string): Promise<ProviderApplication> {
  return apiRequest<ProviderApplication>(`/admin/providers/${id}/approve`, {
    method: 'PATCH',
    body: {},
  });
}

export function rejectProvider(
  id: string,
  reason: string,
): Promise<ProviderApplication> {
  return apiRequest<ProviderApplication>(`/admin/providers/${id}/reject`, {
    method: 'PATCH',
    body: { reason },
  });
}

/** «اطلب تعديل» (B-01): a note about the whole profile, one per field, or both. */
export function requestProviderChanges(
  id: string,
  changes: { note?: string; fieldNotes: ProviderFieldNote[] },
): Promise<ProviderApplication> {
  return apiRequest<ProviderApplication>(
    `/admin/providers/${id}/request-changes`,
    {
      method: 'PATCH',
      body: {
        ...(changes.note ? { note: changes.note } : {}),
        fieldNotes: changes.fieldNotes,
      },
    },
  );
}

export function getProviderReviewHistory(id: string): Promise<ProviderReviewHistory> {
  return apiRequest<ProviderReviewHistory>(`/admin/providers/${id}/review-history`);
}

/** A claim of a listing the back office made (B-12). */
export type ProviderClaimRequest = {
  id: string;
  status: 'PENDING' | 'APPROVED' | 'REJECTED';
  note: string | null;
  createdAt: string;
  decidedAt: string | null;
  provider: ProviderReference;
  claimant: { id: string; name: string; phone: string | null } | null;
  decidedBy: { id: string; name: string } | null;
};

export function getProviderClaims(params?: {
  status?: ProviderClaimRequest['status'];
  page?: number;
  limit?: number;
}): Promise<Paginated<ProviderClaimRequest>> {
  return apiRequest<Paginated<ProviderClaimRequest>>(
    `/admin/provider-claims${toQuery(params ?? {})}`,
  );
}

export function approveProviderClaim(id: string): Promise<ProviderClaimRequest> {
  return apiRequest<ProviderClaimRequest>(`/admin/provider-claims/${id}/approve`, {
    method: 'POST',
    body: {},
  });
}

export function rejectProviderClaim(id: string, note: string): Promise<ProviderClaimRequest> {
  return apiRequest<ProviderClaimRequest>(`/admin/provider-claims/${id}/reject`, {
    method: 'POST',
    body: { note },
  });
}

export function suspendProvider(
  id: string,
  reason: string,
): Promise<ProviderApplication> {
  return apiRequest<ProviderApplication>(`/admin/providers/${id}/suspend`, {
    method: 'PATCH',
    body: { reason },
  });
}

export function activateProvider(id: string): Promise<ProviderApplication> {
  return apiRequest<ProviderApplication>(`/admin/providers/${id}/activate`, {
    method: 'PATCH',
    body: {},
  });
}

export function setProviderVerified(
  id: string,
  verified: boolean,
): Promise<ProviderApplication> {
  return apiRequest<ProviderApplication>(
    `/admin/providers/${id}/${verified ? 'verify' : 'unverify'}`,
    { method: 'PATCH', body: {} },
  );
}

/**
 * A featured placement (B-43): the provider paid outside the app and an
 * administrator recorded its days. Days are Yemen calendar days; `lastDay`
 * is the last one covered. No amount is kept.
 */
export type FeaturedPeriod = {
  id: string;
  state: 'ACTIVE' | 'SCHEDULED' | 'EXPIRED' | 'ENDED';
  /**
   * The placement rule holds for the provider now (in the customers' list:
   * active, with an active service, claimed); a running placement without
   * it ranks and badges nothing.
   */
  providerShown: boolean;
  startsAt: string;
  endsAt: string;
  startsOn: string;
  lastDay: string;
  /** How he paid outside the app, as the administrator wrote it. */
  note: string | null;
  createdAt: string;
  grantedBy: { id: string; name: string } | null;
  endedAt: string | null;
  endedBy: { id: string; name: string } | null;
  endNote: string | null;
  startNoticeAt: string | null;
  endingNoticeAt: string | null;
  endNoticeAt: string | null;
  provider: ProviderReference;
};

/** CURRENT: active or booked; FINISHED: over or ended early. */
export type FeaturedPeriodList = 'CURRENT' | 'ACTIVE' | 'SCHEDULED' | 'FINISHED' | 'ALL';

export type FeaturedSummary = {
  /** Active providers with an active service: the ones customers see. */
  listedProviders: number;
  /** Of those, featured now by the placement rule (claimed, a period running). */
  featured: number;
  free: number;
  endingThisWeek: number;
};

export function getFeaturedPeriods(params?: {
  state?: FeaturedPeriodList;
  providerId?: string;
  page?: number;
  limit?: number;
}): Promise<Paginated<FeaturedPeriod>> {
  return apiRequest<Paginated<FeaturedPeriod>>(
    `/admin/featured-periods${toQuery(params ?? {})}`,
  );
}

export function getFeaturedSummary(): Promise<FeaturedSummary> {
  return apiRequest<FeaturedSummary>('/admin/featured-periods/summary');
}

export function grantFeaturedPeriod(
  providerId: string,
  input: { endsOn: string; startsOn?: string; note?: string },
): Promise<FeaturedPeriod> {
  return apiRequest<FeaturedPeriod>(`/admin/providers/${providerId}/featured-periods`, {
    method: 'POST',
    body: input,
  });
}

export function endFeaturedPeriod(id: string, note?: string): Promise<FeaturedPeriod> {
  return apiRequest<FeaturedPeriod>(`/admin/featured-periods/${id}/end`, {
    method: 'POST',
    body: note ? { note } : {},
  });
}
