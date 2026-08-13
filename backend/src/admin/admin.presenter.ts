import type {
  City,
  Notification,
  Provider,
  ProviderCategory,
  ProviderPackage,
  ProviderReview,
  ProviderService,
  ProviderServiceImage,
  QuoteRequestStatus,
  User,
} from '@prisma/client';
import { toReviewIdentity } from '../shared-kernel/privacy/review-identity';
import {
  maskPhone,
  toAdminNotificationPrivacyView,
} from '../shared-kernel/privacy/admin-notification-privacy';

export type SafeAdminUser = Pick<
  User,
  | 'id'
  | 'name'
  | 'phone'
  | 'email'
  | 'role'
  | 'status'
  | 'avatarUrl'
  | 'createdAt'
  | 'updatedAt'
>;

export type AdminCityRecord = City & {
  _count?: { providers: number; services: number };
};

export type AdminCategoryRecord = ProviderCategory & {
  _count?: { providers: number; services: number };
};

export type AdminServiceRecord = ProviderService & {
  category: ProviderCategory;
  city: City | null;
  images: ProviderServiceImage[];
};

export type AdminPackageRecord = ProviderPackage & {
  service: ProviderService | null;
};

export type AdminProviderRecord = Provider & {
  user?: SafeAdminUser | null;
  reviewedBy?: SafeAdminUser | null;
  city?: City | null;
  primaryCategory?: ProviderCategory | null;
  services?: AdminServiceRecord[];
  packages?: AdminPackageRecord[];
  _count?: {
    services: number;
    packages: number;
    quoteRequests: number;
    reviews: number;
  };
};

export type AdminUserRecord = SafeAdminUser & {
  providerProfile?: (Provider & {
    city?: City | null;
    primaryCategory?: ProviderCategory | null;
  }) | null;
};

export type AdminServiceWithDetails = ProviderService & {
  provider: Provider & {
    city?: City | null;
    primaryCategory?: ProviderCategory | null;
  };
  category: ProviderCategory;
  city: City | null;
  images: ProviderServiceImage[];
};

export type AdminReviewWithDetails = ProviderReview & {
  user: Pick<User, 'id' | 'name' | 'appName' | 'role'>;
  provider: Provider & {
    city?: City | null;
    primaryCategory?: ProviderCategory | null;
  };
};

export type AdminNotificationWithDetails = Notification & {
  user: Pick<User, 'id' | 'name' | 'phone'>;
  weddingPlan?: { id: string; title: string; city: string | null } | null;
};

export interface AdminUserReport {
  total: number;
  active: number;
  disabled: number;
  admins: number;
  providers: number;
  regularUsers: number;
}

export interface AdminProviderReport {
  total: number;
  pending: number;
  active: number;
  needsChanges: number;
  suspended: number;
  rejected: number;
  featured: number;
}

export interface AdminServiceReport {
  total: number;
  active: number;
  disabled: number;
  featured: number;
}

export interface AdminReviewReport {
  total: number;
  published: number;
  hidden: number;
  pending: number;
  averageRating: string;
}

export interface AdminQuoteReport {
  total: number;
  byStatus: { status: QuoteRequestStatus; count: number }[];
}

export interface AdminNotificationReport {
  total: number;
  unread: number;
  archived: number;
  high: number;
  urgent: number;
}

export function toAdminUserReport(input: {
  total: number;
  active: number;
  disabled: number;
  admins: number;
  providers: number;
}): AdminUserReport {
  return {
    ...input,
    regularUsers: input.total - input.admins - input.providers,
  };
}

export function toAdminReviewReport(input: {
  total: number;
  published: number;
  hidden: number;
  pending: number;
  averageRating: number | null;
}): AdminReviewReport {
  return {
    total: input.total,
    published: input.published,
    hidden: input.hidden,
    pending: input.pending,
    averageRating: (input.averageRating ?? 0).toFixed(2),
  };
}

export function toAdminQuoteReport(
  statuses: { status: QuoteRequestStatus; count: number }[],
): AdminQuoteReport {
  return {
    total: statuses.reduce((sum, item) => sum + item.count, 0),
    byStatus: statuses,
  };
}

export function toAdminReportsOverviewResponse(input: {
  generatedAt: Date;
  from: Date | null;
  to: Date | null;
  users: AdminUserReport;
  providers: AdminProviderReport;
  services: AdminServiceReport;
  reviews: AdminReviewReport;
  quotes: AdminQuoteReport;
  notifications: AdminNotificationReport;
  cities: number;
  categories: number;
  weddingPlans: number;
}) {
  return {
    generatedAt: input.generatedAt,
    range: {
      from: input.from,
      to: input.to,
    },
    users: input.users,
    providers: input.providers,
    services: input.services,
    reviews: input.reviews,
    quotes: input.quotes,
    notifications: input.notifications,
    catalog: {
      cities: input.cities,
      categories: input.categories,
    },
    weddingPlans: {
      total: input.weddingPlans,
    },
    source: 'admin_operational_database',
    paymentOrDepositDataIncluded: false,
  };
}

export function toCityResponse(city: AdminCityRecord) {
  return {
    id: city.id,
    nameAr: city.nameAr,
    nameEn: city.nameEn,
    countryCode: city.countryCode,
    isActive: city.isActive,
    sortOrder: city.sortOrder,
    createdAt: city.createdAt,
    updatedAt: city.updatedAt,
    providersCount: city._count?.providers ?? 0,
    servicesCount: city._count?.services ?? 0,
  };
}

export function toCategoryResponse(category: AdminCategoryRecord) {
  return {
    id: category.id,
    nameAr: category.nameAr,
    nameEn: category.nameEn,
    slug: category.slug,
    icon: category.icon,
    showForGroom: category.showForGroom,
    showForBride: category.showForBride,
    isActive: category.isActive,
    sortOrder: category.sortOrder,
    createdAt: category.createdAt,
    updatedAt: category.updatedAt,
    providersCount: category._count?.providers ?? 0,
    servicesCount: category._count?.services ?? 0,
  };
}

export function toProviderResponse(provider: AdminProviderRecord) {
  return {
    id: provider.id,
    userId: provider.userId,
    user: provider.user ? toSafeUser(provider.user) : null,
    cityId: provider.cityId,
    city: provider.city ? toCityResponse(provider.city) : null,
    primaryCategoryId: provider.primaryCategoryId,
    primaryCategory: provider.primaryCategory
      ? toCategoryResponse(provider.primaryCategory)
      : null,
    businessName: provider.businessName,
    ownerName: provider.ownerName,
    phone: provider.phone,
    whatsapp: provider.whatsapp,
    email: provider.email,
    description: provider.description,
    address: provider.address,
    logoUrl: provider.logoUrl,
    coverUrl: provider.coverUrl,
    status: provider.status,
    reviewNote: provider.reviewNote,
    reviewedAt: provider.reviewedAt,
    reviewedBy: provider.reviewedBy
      ? toSafeUser(provider.reviewedBy)
      : null,
    isFeatured: provider.isFeatured,
    ratingAverage: provider.ratingAverage.toString(),
    ratingCount: provider.ratingCount,
    servicesCount: provider._count?.services ?? provider.services?.length ?? 0,
    packagesCount: provider._count?.packages ?? provider.packages?.length ?? 0,
    quoteRequestsCount: provider._count?.quoteRequests ?? 0,
    reviewsCount: provider._count?.reviews ?? 0,
    services: provider.services?.map((service) => ({
      id: service.id,
      title: service.title,
      description: service.description,
      category: toCategoryResponse(service.category),
      city: service.city ? toCityResponse(service.city) : null,
      basePrice: service.basePrice?.toString() ?? null,
      priceUnit: service.priceUnit,
      currency: service.currency,
      isActive: service.isActive,
      isFeatured: service.isFeatured,
      images: service.images.map((image) => ({
        id: image.id,
        imageUrl: image.imageUrl,
        altText: image.altText,
        sortOrder: image.sortOrder,
        createdAt: image.createdAt,
      })),
      createdAt: service.createdAt,
      updatedAt: service.updatedAt,
    })),
    packages: provider.packages?.map((providerPackage) => ({
      id: providerPackage.id,
      title: providerPackage.title,
      description: providerPackage.description,
      price: providerPackage.price?.toString() ?? null,
      currency: providerPackage.currency,
      items: providerPackage.items,
      isActive: providerPackage.isActive,
      service: providerPackage.service
        ? { id: providerPackage.service.id, title: providerPackage.service.title }
        : null,
      createdAt: providerPackage.createdAt,
      updatedAt: providerPackage.updatedAt,
    })),
    createdAt: provider.createdAt,
    updatedAt: provider.updatedAt,
  };
}

export function toAdminServiceResponse(service: AdminServiceWithDetails) {
  return {
    id: service.id,
    providerId: service.providerId,
    provider: toProviderSummary(service.provider),
    categoryId: service.categoryId,
    category: toCategoryResponse(service.category),
    title: service.title,
    description: service.description,
    basePrice: service.basePrice?.toString() ?? null,
    priceUnit: service.priceUnit,
    currency: service.currency,
    cityId: service.cityId,
    city: service.city ? toCityResponse(service.city) : null,
    isActive: service.isActive,
    isFeatured: service.isFeatured,
    images: service.images.map((image) => ({
      id: image.id,
      serviceId: image.serviceId,
      imageUrl: image.imageUrl,
      altText: image.altText,
      sortOrder: image.sortOrder,
      createdAt: image.createdAt,
    })),
    createdAt: service.createdAt,
    updatedAt: service.updatedAt,
  };
}

export function toAdminReviewResponse(review: AdminReviewWithDetails) {
  return {
    id: review.id,
    userId: review.userId,
    user: toReviewIdentity(review.user),
    providerId: review.providerId,
    provider: toProviderSummary(review.provider),
    rating: review.rating,
    comment: review.comment,
    status: review.status,
    createdAt: review.createdAt,
    updatedAt: review.updatedAt,
  };
}

export function toAdminNotificationResponse(
  notification: AdminNotificationWithDetails,
) {
  const privacy = toAdminNotificationPrivacyView(notification);
  return {
    id: notification.id,
    userId: notification.userId,
    user: {
      id: notification.user.id,
      name: notification.user.name,
      phoneMasked: maskPhone(notification.user.phone),
    },
    weddingPlanId: notification.weddingPlanId,
    weddingPlan: privacy.financialDetailsRedacted
      ? null
      : (notification.weddingPlan ?? null),
    type: notification.type,
    priority: notification.priority,
    title: privacy.title,
    body: privacy.body,
    entityType: privacy.entityType,
    entityId: privacy.entityId,
    routeTarget: privacy.routeTarget,
    data: privacy.data,
    financialDetailsRedacted: privacy.financialDetailsRedacted,
    readAt: notification.readAt,
    archivedAt: notification.archivedAt,
    createdAt: notification.createdAt,
    updatedAt: notification.updatedAt,
  };
}

export function toProviderSummary(
  provider: Provider & {
    city?: City | null;
    primaryCategory?: ProviderCategory | null;
  },
) {
  return {
    id: provider.id,
    businessName: provider.businessName,
    phone: provider.phone,
    whatsapp: provider.whatsapp,
    logoUrl: provider.logoUrl,
    status: provider.status,
    ratingAverage: provider.ratingAverage.toString(),
    ratingCount: provider.ratingCount,
    city: provider.city ? toCityResponse(provider.city) : null,
    primaryCategory: provider.primaryCategory
      ? toCategoryResponse(provider.primaryCategory)
      : null,
  };
}

export function toUserResponse(user: AdminUserRecord) {
  return {
    ...toSafeUser(user),
    provider: user.providerProfile
      ? {
          id: user.providerProfile.id,
          businessName: user.providerProfile.businessName,
          status: user.providerProfile.status,
          city: user.providerProfile.city
            ? toCityResponse(user.providerProfile.city)
            : null,
          primaryCategory: user.providerProfile.primaryCategory
            ? toCategoryResponse(user.providerProfile.primaryCategory)
            : null,
        }
      : null,
  };
}

export function toSafeUser(user: SafeAdminUser) {
  return {
    id: user.id,
    name: user.name,
    phone: user.phone,
    email: user.email,
    role: user.role,
    status: user.status,
    avatarUrl: user.avatarUrl,
    createdAt: user.createdAt,
    updatedAt: user.updatedAt,
  };
}
