import { apiRequest } from './client';
import { AdminUser } from './auth';

export type Paginated<T> = {
  items: T[];
  page: number;
  limit: number;
  total: number;
  totalPages: number;
};

export type City = {
  id: string;
  nameAr: string;
  nameEn: string | null;
  countryCode: string;
  isActive: boolean;
  sortOrder: number;
  providersCount?: number;
  servicesCount?: number;
};

export type ProviderCategory = {
  id: string;
  nameAr: string;
  nameEn: string | null;
  slug: string;
  icon: string | null;
  isActive: boolean;
  sortOrder: number;
  providersCount?: number;
  servicesCount?: number;
};

export type ProviderService = {
  id: string;
  title: string;
  description: string | null;
  basePrice: string | null;
  priceUnit: string | null;
  currency: string;
  isActive: boolean;
  category?: ProviderCategory;
  city?: City | null;
};

export type ProviderPackage = {
  id: string;
  title: string;
  description: string | null;
  price: string | null;
  currency: string;
  items: unknown;
  isActive: boolean;
  service?: { id: string; title: string } | null;
};

export type ProviderApplication = {
  id: string;
  userId: string | null;
  user: AdminUser | null;
  cityId: string;
  city: City | null;
  primaryCategoryId: string | null;
  primaryCategory: ProviderCategory | null;
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
  isFeatured: boolean;
  ratingAverage: string;
  ratingCount: number;
  servicesCount: number;
  packagesCount: number;
  quoteRequestsCount: number;
  reviewsCount: number;
  services?: ProviderService[];
  packages?: ProviderPackage[];
  createdAt: string;
  updatedAt: string;
};

export type AdminStats = {
  totalUsers: number;
  totalProviders: number;
  pendingProviders: number;
  approvedProviders: number;
  rejectedProviders: number;
  needsChangesProviders: number;
  suspendedProviders: number;
  totalQuoteRequests: number;
  totalWeddingPlans: number;
  totalCities: number;
  totalProviderCategories: number;
};

export type QueryParams = {
  status?: string;
  cityId?: string;
  categoryId?: string;
  search?: string;
  page?: number;
  limit?: number;
};

export type CatalogPayload = {
  nameAr: string;
  nameEn?: string | null;
  slug?: string | null;
  icon?: string | null;
  countryCode?: string | null;
  isActive?: boolean;
  sortOrder?: number;
};

export function getStats() {
  return apiRequest<AdminStats>('/admin/dashboard/stats');
}

export function getProviderApplications(params: QueryParams = {}) {
  return apiRequest<Paginated<ProviderApplication>>(
    `/admin/providers/applications${toQuery(params)}`,
  );
}

export function getProviderApplication(id: string) {
  return apiRequest<ProviderApplication>(
    `/admin/providers/applications/${id}`,
  );
}

export function getProviders(params: QueryParams = {}) {
  return apiRequest<Paginated<ProviderApplication>>(
    `/admin/providers${toQuery(params)}`,
  );
}

export function getProvider(id: string) {
  return apiRequest<ProviderApplication>(`/admin/providers/${id}`);
}

export function approveProvider(id: string) {
  return apiRequest<ProviderApplication>(`/admin/providers/${id}/approve`, {
    method: 'PATCH',
    body: {},
  });
}

export function rejectProvider(id: string, reason: string) {
  return apiRequest<ProviderApplication>(`/admin/providers/${id}/reject`, {
    method: 'PATCH',
    body: { reason },
  });
}

export function requestProviderChanges(id: string, note: string) {
  return apiRequest<ProviderApplication>(
    `/admin/providers/${id}/request-changes`,
    {
      method: 'PATCH',
      body: { note },
    },
  );
}

export function suspendProvider(id: string, reason: string) {
  return apiRequest<ProviderApplication>(`/admin/providers/${id}/suspend`, {
    method: 'PATCH',
    body: { reason },
  });
}

export function activateProvider(id: string) {
  return apiRequest<ProviderApplication>(`/admin/providers/${id}/activate`, {
    method: 'PATCH',
    body: {},
  });
}

export function getCategories() {
  return apiRequest<ProviderCategory[]>('/admin/provider-categories');
}

export function createCategory(payload: CatalogPayload) {
  return apiRequest<ProviderCategory>('/admin/provider-categories', {
    method: 'POST',
    body: payload,
  });
}

export function updateCategory(id: string, payload: CatalogPayload) {
  return apiRequest<ProviderCategory>(`/admin/provider-categories/${id}`, {
    method: 'PATCH',
    body: payload,
  });
}

export function deleteCategory(id: string) {
  return apiRequest<ProviderCategory>(`/admin/provider-categories/${id}`, {
    method: 'DELETE',
  });
}

export function getCities() {
  return apiRequest<City[]>('/admin/cities');
}

export function createCity(payload: CatalogPayload) {
  return apiRequest<City>('/admin/cities', {
    method: 'POST',
    body: payload,
  });
}

export function updateCity(id: string, payload: CatalogPayload) {
  return apiRequest<City>(`/admin/cities/${id}`, {
    method: 'PATCH',
    body: payload,
  });
}

export function deleteCity(id: string) {
  return apiRequest<City>(`/admin/cities/${id}`, {
    method: 'DELETE',
  });
}

export function getUsers(params: QueryParams = {}) {
  return apiRequest<Paginated<AdminUser & { provider?: ProviderApplication }>>(
    `/admin/users${toQuery(params)}`,
  );
}

function toQuery(params: QueryParams) {
  const searchParams = new URLSearchParams();
  Object.entries(params).forEach(([key, value]) => {
    if (value !== undefined && value !== null && value !== '') {
      searchParams.set(key, String(value));
    }
  });
  const query = searchParams.toString();
  return query ? `?${query}` : '';
}
