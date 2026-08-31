import { apiRequest } from '../../platform/api/client';
import { type Paginated, toQuery } from '../../platform/api/query';

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
  showForGroom: boolean;
  showForBride: boolean;
  isActive: boolean;
  sortOrder: number;
  providersCount?: number;
  servicesCount?: number;
};

export type ProviderService = {
  id: string;
  providerId?: string;
  provider?: {
    id: string;
    businessName: string;
    phone: string;
    whatsapp: string | null;
    logoUrl: string | null;
    status: string;
    ratingAverage: string;
    ratingCount: number;
    city?: City | null;
    primaryCategory?: ProviderCategory | null;
  };
  categoryId?: string;
  title: string;
  description: string | null;
  basePrice: string | null;
  priceUnit: string | null;
  currency: string;
  cityId?: string | null;
  isActive: boolean;
  isFeatured?: boolean;
  category?: ProviderCategory;
  city?: City | null;
  images?: Array<{
    id: string;
    serviceId: string;
    imageUrl: string;
    altText: string | null;
    sortOrder: number;
    createdAt: string;
  }>;
  createdAt?: string;
  updatedAt?: string;
};

type ServiceQueryParams = {
  status?: string;
  providerId?: string;
  cityId?: string;
  categoryId?: string;
  search?: string;
  page?: number;
  limit?: number;
};

export type ServicePayload = {
  providerId?: string;
  categoryId?: string;
  title?: string;
  description?: string | null;
  basePrice?: string | null;
  priceUnit?: string | null;
  currency?: string;
  cityId?: string | null;
  isActive?: boolean;
  isFeatured?: boolean;
};

export type CatalogPayload = {
  nameAr: string;
  nameEn?: string | null;
  slug?: string | null;
  icon?: string | null;
  showForGroom?: boolean;
  showForBride?: boolean;
  countryCode?: string | null;
  isActive?: boolean;
  sortOrder?: number;
};

export type ReferenceCatalogSummary = {
  id: string;
  key: string;
  nameAr: string;
  description: string | null;
  version: number;
  isActive: boolean;
  itemsCount: number;
  publishedCount: number;
  pendingCount: number;
  updatedAt: string;
};

export type ReferenceCatalogRevision = {
  revision: number;
  groupKey: string | null;
  groupNameAr: string | null;
  groupSubtitleAr: string | null;
  nameAr: string;
  nameEn: string | null;
  icon: string | null;
  sortOrder: number;
  showForGroom: boolean;
  showForBride: boolean;
  showForCustomer: boolean;
  showForProvider: boolean;
  isRecommended: boolean;
  isActive: boolean;
  metadata: Record<string, unknown> | null;
  createdAt: string;
};

export type ReferenceCatalogItem = {
  id: string;
  key: string;
  currentRevision: number;
  publishedRevision: number;
  hasUnpublishedChanges: boolean;
  current: ReferenceCatalogRevision;
  published: ReferenceCatalogRevision | null;
  revisions: Array<{
    revision: number;
    nameAr: string;
    isActive: boolean;
    createdAt: string;
  }>;
  createdAt: string;
  updatedAt: string;
};

export type ReferenceCatalog = Omit<
  ReferenceCatalogSummary,
  'itemsCount' | 'publishedCount' | 'pendingCount'
> & {
  items: ReferenceCatalogItem[];
};

export type ReferenceCatalogItemPayload = {
  key?: string;
  nameAr?: string;
  nameEn?: string | null;
  groupKey?: string | null;
  groupNameAr?: string | null;
  groupSubtitleAr?: string | null;
  icon?: string | null;
  sortOrder?: number;
  showForGroom?: boolean;
  showForBride?: boolean;
  showForCustomer?: boolean;
  showForProvider?: boolean;
  isRecommended?: boolean;
  isActive?: boolean;
  metadata?: Record<string, string | number | boolean | null> | null;
};

export type Governorate = {
  id: string;
  code: string;
  nameAr: string;
  nameEn: string;
  latitude: number | null;
  longitude: number | null;
  isActive: boolean;
  sortOrder: number;
  _count?: { districts: number };
};

export type District = Omit<Governorate, '_count'> & {
  governorateId: string;
  _count?: { localities: number };
};

export type AdministrativeLocalityType =
  | 'AREA'
  | 'ISOLATION'
  | 'NEIGHBORHOOD'
  | 'ZONE';

export type AdministrativeLocality = Omit<
  Governorate,
  'nameEn' | '_count'
> & {
  districtId: string;
  parentId: string | null;
  type: AdministrativeLocalityType;
  nameEn: string | null;
};

export type AdministrativeLocationPayload = {
  code?: string;
  nameAr?: string;
  nameEn?: string | null;
  latitude?: number | null;
  longitude?: number | null;
  isActive?: boolean;
  sortOrder?: number;
  governorateId?: string;
  districtId?: string;
  parentId?: string | null;
  type?: AdministrativeLocalityType;
};

export function getServices(params: ServiceQueryParams = {}) {
  return apiRequest<Paginated<ProviderService>>(
    `/admin/services${toQuery(params)}`,
  );
}

export function createService(payload: ServicePayload) {
  return apiRequest<ProviderService>('/admin/services', {
    method: 'POST',
    body: payload,
  });
}

export function updateService(id: string, payload: ServicePayload) {
  return apiRequest<ProviderService>(`/admin/services/${id}`, {
    method: 'PATCH',
    body: payload,
  });
}

export function deleteService(id: string) {
  return apiRequest<ProviderService & { deleted?: boolean }>(
    `/admin/services/${id}`,
    { method: 'DELETE' },
  );
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

export function getReferenceCatalogs() {
  return apiRequest<ReferenceCatalogSummary[]>('/admin/reference-catalogs');
}

export function getReferenceCatalog(key: string) {
  return apiRequest<ReferenceCatalog>(
    `/admin/reference-catalogs/${encodeURIComponent(key)}`,
  );
}

export function createReferenceCatalogItem(
  catalogKey: string,
  payload: ReferenceCatalogItemPayload,
) {
  return apiRequest<ReferenceCatalogItem>(
    `/admin/reference-catalogs/${encodeURIComponent(catalogKey)}/items`,
    { method: 'POST', body: payload },
  );
}

export function updateReferenceCatalogItem(
  catalogKey: string,
  id: string,
  payload: ReferenceCatalogItemPayload,
) {
  return apiRequest<ReferenceCatalogItem>(
    `/admin/reference-catalogs/${encodeURIComponent(catalogKey)}/items/${id}`,
    { method: 'PATCH', body: payload },
  );
}

export function publishReferenceCatalogItem(
  catalogKey: string,
  id: string,
  revision?: number,
) {
  return apiRequest<ReferenceCatalogItem>(
    `/admin/reference-catalogs/${encodeURIComponent(catalogKey)}/items/${id}/publish`,
    { method: 'POST', body: revision ? { revision } : {} },
  );
}

export function disableReferenceCatalogItem(catalogKey: string, id: string) {
  return apiRequest<ReferenceCatalogItem>(
    `/admin/reference-catalogs/${encodeURIComponent(catalogKey)}/items/${id}`,
    { method: 'DELETE' },
  );
}

export function getGovernorates() {
  return apiRequest<Governorate[]>('/admin/governorates');
}

export function createGovernorate(payload: AdministrativeLocationPayload) {
  return apiRequest<Governorate>('/admin/governorates', {
    method: 'POST',
    body: payload,
  });
}

export function updateGovernorate(
  id: string,
  payload: AdministrativeLocationPayload,
) {
  return apiRequest<Governorate>(`/admin/governorates/${id}`, {
    method: 'PATCH',
    body: payload,
  });
}

export function disableGovernorate(id: string) {
  return apiRequest<Governorate>(`/admin/governorates/${id}`, {
    method: 'DELETE',
  });
}

export function getDistricts(governorateId: string) {
  return apiRequest<District[]>(
    `/admin/governorates/${governorateId}/districts`,
  );
}

export function createDistrict(
  governorateId: string,
  payload: AdministrativeLocationPayload,
) {
  return apiRequest<District>(
    `/admin/governorates/${governorateId}/districts`,
    { method: 'POST', body: payload },
  );
}

export function updateDistrict(
  id: string,
  payload: AdministrativeLocationPayload,
) {
  return apiRequest<District>(`/admin/districts/${id}`, {
    method: 'PATCH',
    body: payload,
  });
}

export function disableDistrict(id: string) {
  return apiRequest<District>(`/admin/districts/${id}`, { method: 'DELETE' });
}

export function getLocalities(districtId: string) {
  return apiRequest<AdministrativeLocality[]>(
    `/admin/districts/${districtId}/localities`,
  );
}

export function createLocality(
  districtId: string,
  payload: AdministrativeLocationPayload,
) {
  return apiRequest<AdministrativeLocality>(
    `/admin/districts/${districtId}/localities`,
    { method: 'POST', body: payload },
  );
}

export function updateLocality(
  id: string,
  payload: AdministrativeLocationPayload,
) {
  return apiRequest<AdministrativeLocality>(`/admin/localities/${id}`, {
    method: 'PATCH',
    body: payload,
  });
}

export function disableLocality(id: string) {
  return apiRequest<AdministrativeLocality>(`/admin/localities/${id}`, {
    method: 'DELETE',
  });
}
