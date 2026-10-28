import {
  Booking,
  City,
  FavoriteProvider,
  PlanProviderLink,
  Prisma,
  Provider,
  ProviderCategory,
  ProviderPackage,
  ProviderReview,
  ProviderService,
  ProviderServiceImage,
  ProviderStatus,
  QuoteOffer,
  QuoteRequest,
  User,
  WeddingPlan,
} from "@prisma/client";
import type { ActiveFeaturedPeriodWhere, FeaturedWindow } from "../modules/marketplace/public/featured-placement";

// The search and access filters name marketplace's own columns and relations
// exactly (the ownership scan proves a declared shape; a generated Prisma
// input type admits every key and is never a proof).
type TextMatch = { contains: string; mode: "insensitive" };
export interface ProviderSearchWhere {
  AND: Array<
    | { status: ProviderStatus } | { services: { some: { isActive: boolean } } }
    | { cityId: string }
    | { userId: { not: null } } | { featuredPeriods: { some: ActiveFeaturedPeriodWhere } } | { OR: Array<{ userId: null } | { featuredPeriods: { none: ActiveFeaturedPeriodWhere } }> }
    | { OR: Array<{ primaryCategoryId: { in: string[] } } | { services: { some: { categoryId: { in: string[] }; isActive: boolean } } }> }
    | { OR: Array<{ businessName: TextMatch } | { ownerName: TextMatch } | { description: TextMatch } | { address: TextMatch } | { services: { some: { isActive: boolean; OR: Array<{ title: TextMatch } | { description: TextMatch }> } } }> }
  >;
}
export interface ServiceSearchWhere {
  isActive: true;
  providerId?: string;
  categoryId?: string;
  basePrice?: { gte?: string; lte?: string };
  AND: Array<
    | { provider: { status: ProviderStatus } }
    | { OR: Array<{ cityId: string } | { cityId: null; provider: { cityId: string } }> }
    | { OR: Array<{ title: TextMatch } | { description: TextMatch } | { provider: { businessName: TextMatch } }> }
  >;
}
/** A user's own quotes: plan-less, in an owned plan, or created in a plan the user still manages providers for. */
export interface MyQuoteAccessWhere {
  id?: string;
  userId: string;
  OR: [
    { weddingPlanId: null },
    { weddingPlanId: { in: string[] } },
    { id: { in: string[] }; weddingPlanId: { in: string[] } },
  ];
}

export interface MarketplacePagination {
  page: number;
  limit: number;
  skip: number;
}

export interface PaginatedResponse<T> {
  items: T[];
  page: number;
  limit: number;
  total: number;
  totalPages: number;
}

export type ProviderWithCity = Provider & {
  city: City;
  primaryCategory?: ProviderCategory | null;
};

export type ServiceWithDetails = ProviderService & {
  provider: ProviderWithCity;
  category: ProviderCategory;
  city: City | null;
  images: ProviderServiceImage[];
};

export type PackageWithService = ProviderPackage & {
  service?: ProviderService | null;
};

export type ReviewWithUser = ProviderReview & {
  user: Pick<User, "id" | "name" | "appName" | "role" | "reviewFirstNameOnly">;
};

/** A provider read with its active featured period (B-43): «مميز» is read from it. */
export type ProviderWithFeature = Provider & { featuredPeriods: FeaturedWindow[] };

export type FavoriteWithProvider = FavoriteProvider & {
  provider: ProviderWithCity & ProviderWithFeature;
};

export type QuoteWithRelations = QuoteRequest & {
  provider: ProviderWithCity;
  service?: (ProviderService & { category: ProviderCategory }) | null;
  city?: City | null;
  weddingPlan?: Pick<
    WeddingPlan,
    "id" | "title" | "city" | "weddingDate"
  > | null;
  offers?: (QuoteOffer & { weddingCosts: { id: string }[] })[];
  providerLinks?: PlanProviderLink[];
  booking?: Booking | null;
};

// Contact, budget, and offer amounts are exposed only when the caller has the
// matching plan permission. A read-only member sees non-private quote context.
export type QuoteVisibility = { budget: boolean; contact: boolean };

export const FULL_QUOTE_VISIBILITY: QuoteVisibility = {
  budget: true,
  contact: true,
};

// The quote row with marketplace's own relations only; the catalog, plan
// and cost rows are attached afterwards by MarketplaceRelationsService.
export const MARKETPLACE_QUOTE_INCLUDE = {
  provider: true,
  service: true,
  offers: { orderBy: { createdAt: "desc" } },
  providerLinks: true,
  booking: { include: { changes: true } },
} satisfies Prisma.QuoteRequestInclude;

export type QuoteRow = Prisma.QuoteRequestGetPayload<{
  include: typeof MARKETPLACE_QUOTE_INCLUDE;
}>;
