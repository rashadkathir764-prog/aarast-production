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
  isFeatured?: boolean;
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
  reviewNote: string | null;
  reviewedAt: string | null;
  reviewedBy: AdminUser | null;
  /** When an admin checked the provider's documents; null when not verified. */
  verifiedAt: string | null;
  isFeatured: boolean;
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

export type ProviderQueryParams = {
  status?: string;
  cityId?: string;
  categoryId?: string;
  search?: string;
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

export function requestProviderChanges(
  id: string,
  note: string,
): Promise<ProviderApplication> {
  return apiRequest<ProviderApplication>(
    `/admin/providers/${id}/request-changes`,
    { method: 'PATCH', body: { note } },
  );
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
