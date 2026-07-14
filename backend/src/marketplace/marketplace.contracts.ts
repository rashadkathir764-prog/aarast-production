import {
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
  QuoteOffer,
  QuoteRequest,
  User,
  WeddingPlan,
} from "@prisma/client";

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
  user: Pick<User, "id" | "name">;
};

export type FavoriteWithProvider = FavoriteProvider & {
  provider: ProviderWithCity;
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
};

// Contact, budget, and offer amounts are exposed only when the caller has the
// matching plan permission. A read-only member sees non-private quote context.
export type QuoteVisibility = { budget: boolean; contact: boolean };

export const FULL_QUOTE_VISIBILITY: QuoteVisibility = {
  budget: true,
  contact: true,
};

export const MARKETPLACE_QUOTE_INCLUDE = {
  provider: { include: { city: true, primaryCategory: true } },
  service: { include: { category: true } },
  city: true,
  weddingPlan: {
    select: {
      id: true,
      title: true,
      city: true,
      weddingDate: true,
    },
  },
  offers: {
    orderBy: { createdAt: "desc" },
    include: { weddingCosts: { select: { id: true } } },
  },
  providerLinks: true,
} satisfies Prisma.QuoteRequestInclude;
