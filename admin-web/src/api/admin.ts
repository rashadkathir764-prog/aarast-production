import { apiRequest } from './client';
import { AdminUser } from './auth';

export type Paginated<T> = {
  items: T[];
  page: number;
  limit: number;
  total: number;
  totalPages: number;
};

export type AdminAuditPhase = 'ATTEMPT' | 'SUCCEEDED' | 'FAILED';

export type AdminAuditLog = {
  id: string;
  eventId: string;
  actorUserId: string;
  actorAdminRole: 'SUPER_ADMIN' | 'OPERATIONS' | 'MODERATOR' | 'SUPPORT';
  action: string;
  method: string;
  route: string;
  targetId: string | null;
  phase: AdminAuditPhase;
  statusCode: number | null;
  errorType: string | null;
  requestId: string | null;
  createdAt: string;
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

export type ProviderReference = {
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

export type ProviderReview = {
  id: string;
  userId: string;
  user: {
    id: string;
    name: string;
  };
  providerId: string;
  provider?: ProviderReference;
  rating: number;
  comment: string | null;
  status: string;
  createdAt: string;
  updatedAt: string;
};

export type AdminNotification = {
  id: string;
  userId: string;
  user?: {
    id: string;
    name: string;
    phoneMasked: string | null;
  };
  weddingPlanId: string | null;
  weddingPlan?: { id: string; title: string; city: string | null } | null;
  type: string;
  priority: string;
  title: string;
  body: string;
  entityType: string | null;
  entityId: string | null;
  routeTarget: string | null;
  data: unknown;
  financialDetailsRedacted: boolean;
  readAt: string | null;
  archivedAt: string | null;
  createdAt: string;
  updatedAt: string;
};

export type ConversationReport = {
  id: string;
  conversationId: string;
  reason: string;
  status: 'OPEN' | 'REVIEWED' | 'DISMISSED';
  createdAt: string;
  updatedAt: string;
  reporter: {
    id: string;
    name: string;
    phone: string | null;
    avatarUrl: string | null;
  };
  conversation: {
    provider: { id: string; businessName: string };
    quoteRequests: Array<{ id: string }>;
  };
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

export type AdminReport = {
  generatedAt: string;
  range: { from: string | null; to: string | null };
  users: {
    total: number;
    active: number;
    disabled: number;
    admins: number;
    providers: number;
    regularUsers: number;
  };
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
    averageRating: string;
  };
  quotes: {
    total: number;
    byStatus: Array<{ status: string; count: number }>;
  };
  notifications: {
    total: number;
    unread: number;
    archived: number;
    high: number;
    urgent: number;
  };
  catalog: {
    cities: number;
    categories: number;
  };
  weddingPlans: {
    total: number;
  };
  source: string;
  paymentOrDepositDataIncluded: boolean;
};

export type QueryParams = {
  status?: string;
  providerId?: string;
  cityId?: string;
  categoryId?: string;
  search?: string;
  page?: number;
  limit?: number;
  type?: string;
  priority?: string;
  unreadOnly?: boolean;
  from?: string;
  to?: string;
  action?: string;
  actorUserId?: string;
  phase?: AdminAuditPhase;
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

export function getStats() {
  return apiRequest<AdminStats>('/admin/dashboard/stats');
}

export function getReportOverview(params: QueryParams = {}) {
  return apiRequest<AdminReport>(`/admin/reports/overview${toQuery(params)}`);
}

export function getAdminAuditLogs(params: QueryParams = {}) {
  return apiRequest<Paginated<AdminAuditLog>>(
    `/admin/audit-logs${toQuery(params)}`,
  );
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

export function getServices(params: QueryParams = {}) {
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

export function getReviews(params: QueryParams = {}) {
  return apiRequest<Paginated<ProviderReview>>(
    `/admin/reviews${toQuery(params)}`,
  );
}

export function updateReviewStatus(id: string, status: string) {
  return apiRequest<ProviderReview>(`/admin/reviews/${id}/status`, {
    method: 'PATCH',
    body: { status },
  });
}

export function hideReview(id: string) {
  return apiRequest<ProviderReview & { deleted?: boolean }>(
    `/admin/reviews/${id}`,
    { method: 'DELETE' },
  );
}

export function getConversationReports(params: QueryParams = {}) {
  return apiRequest<Paginated<ConversationReport>>(
    `/admin/conversation-reports${toQuery(params)}`,
  );
}

export function updateConversationReportStatus(
  id: string,
  status: ConversationReport['status'],
) {
  return apiRequest<ConversationReport>(
    `/admin/conversation-reports/${id}/status`,
    { method: 'PATCH', body: { status } },
  );
}

export function getAdminNotifications(params: QueryParams = {}) {
  return apiRequest<Paginated<AdminNotification>>(
    `/admin/notifications${toQuery(params)}`,
  );
}

export function getAdminUnreadNotificationCount() {
  return apiRequest<{ count: number }>('/admin/notifications/unread-count');
}

export function markAdminNotificationRead(id: string) {
  return apiRequest<AdminNotification>(`/admin/notifications/${id}/read`, {
    method: 'PATCH',
    body: {},
  });
}

export function archiveAdminNotification(id: string) {
  return apiRequest<AdminNotification>(`/admin/notifications/${id}/archive`, {
    method: 'PATCH',
    body: {},
  });
}

export function deleteAdminNotification(id: string) {
  return apiRequest<{ id: string; deleted: true }>(
    `/admin/notifications/${id}`,
    { method: 'DELETE' },
  );
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

export function getUser(id: string) {
  return apiRequest<AdminUser & { provider?: ProviderApplication | null }>(
    `/admin/users/${id}`,
  );
}

export function activateUser(id: string) {
  return apiRequest<AdminUser & { provider?: ProviderApplication | null }>(
    `/admin/users/${id}/activate`,
    { method: 'PATCH', body: {} },
  );
}

export function disableUser(id: string) {
  return apiRequest<AdminUser & { provider?: ProviderApplication | null }>(
    `/admin/users/${id}/disable`,
    { method: 'PATCH', body: {} },
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
