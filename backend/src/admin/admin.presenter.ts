import type {
  City,
  Provider,
  ProviderCategory,
  ProviderClaimRequest,
  ProviderFeaturedPeriod,
  ProviderPackage,
  ProviderReview,
  ProviderReviewEvent,
  ProviderReviewNote,
  ProviderService,
  ProviderServiceImage,
  QuoteRequestStatus,
  User,
} from '@prisma/client';
import {
  currentProviderReviewNotes,
  sortProviderFieldNotes,
  toProviderLatestDecision,
} from '../modules/marketplace/public/provider-review';
import {
  featuredLastDay,
  featuredPeriodState,
  yemenDayOf,
} from '../modules/marketplace/public/featured-placement';
import { toModeratedReviewIdentity } from '../shared-kernel/privacy/review-identity';
import { ownerReviewReply } from '../modules/marketplace/public/review-reply';
import { providerCategoryBudgetItem } from '../modules/finance/public/provider-category-budget-item';
import type { StarterBudgetItem } from '../modules/catalog/public/catalog-admin.port';

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
  /** The latest administrator decision with its notes (at most one). */
  reviewEvents?: Array<ProviderReviewEvent & { notes: ProviderReviewNote[] }>;
  _count?: {
    services: number;
    packages: number;
    quoteRequests: number;
    reviews: number;
  };
  /** The end of the placement active now (B-43), null when not featured. */
  featuredUntil: Date | null;
};

/** A claim of a listing (B-12) as the back office shows it. */
export type AdminClaimRequestRecord = ProviderClaimRequest & {
  provider: Provider & {
    city?: City | null;
    primaryCategory?: ProviderCategory | null;
  };
  claimant: SafeAdminUser | null;
  decidedBy: SafeAdminUser | null;
};

/** One review step (B-01, B-02) with the account that took it. */
export type AdminProviderReviewEventRecord = ProviderReviewEvent & {
  notes: ProviderReviewNote[];
  actor: SafeAdminUser | null;
};

export function toAdminClaimRequestResponse(claim: AdminClaimRequestRecord) {
  return {
    id: claim.id,
    status: claim.status,
    note: claim.note,
    createdAt: claim.createdAt,
    decidedAt: claim.decidedAt,
    provider: toProviderSummary(claim.provider),
    claimant: claim.claimant
      ? {
          id: claim.claimant.id,
          name: claim.claimant.name,
          phone: claim.claimant.phone,
        }
      : null,
    decidedBy: claim.decidedBy
      ? { id: claim.decidedBy.id, name: claim.decidedBy.name }
      : null,
  };
}

/** A featured placement (B-43) with its listing and the administrators who recorded and ended it. */
export type AdminFeaturedPeriodRecord = ProviderFeaturedPeriod & {
  provider: Provider & {
    city?: City | null;
    primaryCategory?: ProviderCategory | null;
  };
  grantedBy: SafeAdminUser | null;
  endedBy: SafeAdminUser | null;
};

/**
 * `providerShown`: the placement rule holds for its provider now (listed and
 * claimed); a running period on a provider customers cannot find ranks and
 * badges nothing, and a17 says so instead of «شغّال».
 */
export function toAdminFeaturedPeriodResponse(
  period: AdminFeaturedPeriodRecord,
  now: Date,
  providerShown: boolean,
) {
  return {
    id: period.id,
    state: featuredPeriodState(period, now),
    providerShown,
    startsAt: period.startsAt,
    endsAt: period.endsAt,
    // Yemen calendar days: the first day and the last day covered.
    startsOn: yemenDayOf(period.startsAt),
    lastDay: featuredLastDay(period.endsAt),
    note: period.note,
    createdAt: period.createdAt,
    grantedBy: period.grantedBy
      ? { id: period.grantedBy.id, name: period.grantedBy.name }
      : null,
    endedAt: period.endedAt,
    endedBy: period.endedBy
      ? { id: period.endedBy.id, name: period.endedBy.name }
      : null,
    endNote: period.endNote,
    startNoticeAt: period.startNoticeAt,
    endingNoticeAt: period.endingNoticeAt,
    endNoticeAt: period.endNoticeAt,
    provider: toProviderSummary(period.provider),
  };
}

/** When the provider applied, then every review step, oldest first. */
export function toProviderReviewHistoryResponse(
  provider: Pick<Provider, 'id' | 'createdAt'>,
  events: readonly AdminProviderReviewEventRecord[],
) {
  return {
    providerId: provider.id,
    appliedAt: provider.createdAt,
    events: events.map((event) => ({
      id: event.id,
      kind: event.kind,
      at: event.createdAt,
      actor: event.actor
        ? { id: event.actor.id, name: event.actor.name }
        : null,
      notes: sortProviderFieldNotes(event.notes).map((note) => ({
        field: note.field,
        note: note.note,
      })),
    })),
  };
}

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
  /** RA-ST-05: its latest five open reports, as the listing reads them. */
  reports?: Array<{ reason: string; createdAt: Date }>;
  /** RA-ST-05: how many reports are open, all of them. */
  _count?: { reports: number };
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

/**
 * Where an accepted offer of this category is filed in a new plan of each
 * kind, by the same matcher acceptance uses: the starter item's name, or
 * null for «أخرى» (the admin page warns then). A new or renamed category
 * that no item fits is seen here, not discovered in a customer's money.
 */
function categoryBudgetItems(
  category: { nameAr: string; slug: string },
  starterItems: readonly StarterBudgetItem[],
) {
  const of = (persona: StarterBudgetItem['persona']) =>
    providerCategoryBudgetItem(
      starterItems
        .filter((item) => item.persona === persona)
        .map((item) => item.nameAr),
      category.nameAr,
      // D73: the catalog's explicit links first, read as acceptance reads
      // them for a plan of this kind.
      {
        providerCategorySlug: category.slug,
        catalog: {
          planPersona: persona === 'NEUTRAL' ? null : persona,
          items: starterItems,
        },
      },
    );
  return { groom: of('GROOM'), bride: of('BRIDE'), shared: of('NEUTRAL') };
}

/** a08's row: the category and where its accepted offers are filed. */
export function toCategoryAdminResponse(
  category: AdminCategoryRecord,
  starterItems: readonly StarterBudgetItem[],
) {
  return {
    ...toCategoryResponse(category),
    budgetItems: categoryBudgetItems(category, starterItems),
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
    ...currentProviderReviewNotes(
      provider.status,
      provider.reviewEvents?.[0] ?? null,
    ),
    // The latest decision; a profile sent back reads «كان مرفوض» or «كان
    // يحتاج تعديل» from its kind (B-01, B-02).
    latestDecision: toProviderLatestDecision(provider.reviewEvents?.[0]),
    resubmittedAt: provider.resubmittedAt,
    resubmitCount: provider.resubmitCount,
    reopenedAt: provider.reopenedAt,
    reviewedAt: provider.reviewedAt,
    reviewedBy: provider.reviewedBy
      ? toSafeUser(provider.reviewedBy)
      : null,
    verifiedAt: provider.verifiedAt,
    isFeatured: provider.featuredUntil !== null,
    featuredUntil: provider.featuredUntil,
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
    user: toModeratedReviewIdentity(review.user),
    providerId: review.providerId,
    provider: toProviderSummary(review.provider),
    rating: review.rating,
    comment: review.comment,
    status: review.status,
    // B-09: the provider's reply and whether it shows (a10).
    reply: ownerReviewReply(review),
    // RA-ST-05: its latest open reports, newest first (the reporters stay
    // unnamed), and how many are open in all.
    openReports: (review.reports ?? []).map((report) => ({
      reason: report.reason,
      createdAt: report.createdAt,
    })),
    openReportCount: review._count?.reports ?? review.reports?.length ?? 0,
    createdAt: review.createdAt,
    updatedAt: review.updatedAt,
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
