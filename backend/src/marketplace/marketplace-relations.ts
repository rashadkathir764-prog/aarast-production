import { Inject, Injectable } from "@nestjs/common";
import type {
  City,
  Prisma,
  Provider,
  ProviderCategory,
  ProviderReview,
  ProviderService,
  QuoteOffer,
  QuoteRequest,
} from "@prisma/client";
import {
  CATALOG_READ_PORT,
  type CatalogReadPort,
} from "../modules/catalog/public/catalog-read.port";
import {
  FINANCE_PORT,
  type FinancePort,
} from "../modules/finance/public/finance.port";
import {
  USER_READ_PORT,
  type UserReadPort,
} from "../modules/identity/public/user-read.port";
import {
  PLAN_READ_PORT,
  type PlanReadPort,
} from "../modules/planning/public/plan-read.port";
import type {
  QuoteRow,
  QuoteWithRelations,
  ReviewWithUser,
} from "./marketplace.contracts";

type WithCatalog<T> = T & {
  city: City;
  primaryCategory: ProviderCategory | null;
};

type ServicePreview = Pick<ProviderService, "title" | "basePrice" | "currency">;
type ProviderListRow = Provider & {
  services: Array<ServicePreview & { categoryId: string }>;
};
type ProviderListEntry = WithCatalog<Provider> & {
  servicePreviews: Array<ServicePreview & { category: ProviderCategory }>;
};

// Marketplace rows point at catalog's city and category, planning's plan,
// identity's user and finance's cost. Those rows used to arrive through
// Prisma includes on marketplace's own queries; they are read through their
// owners' ports on the client the caller is working with and attached
// exactly where the includes put them, so the presenters see the same shape.
@Injectable()
export class MarketplaceRelationsService {
  constructor(
    @Inject(CATALOG_READ_PORT) private readonly catalog: CatalogReadPort,
    @Inject(PLAN_READ_PORT) readonly plans: PlanReadPort,
    @Inject(USER_READ_PORT) private readonly users: UserReadPort,
    @Inject(FINANCE_PORT) private readonly finance: FinancePort,
  ) {}

  async attachProviderCatalog<
    T extends Pick<Provider, "id" | "cityId" | "primaryCategoryId">,
  >(client: Prisma.TransactionClient, providers: T[]): Promise<Array<WithCatalog<T>>> {
    const { cities, categories } = await this.catalogFor(client, providers, []);
    return providers.map((provider) => this.withProviderCatalog(provider, cities, categories));
  }

  /** Providers of the public list with their catalog rows and the category of each service preview. */
  async attachProviderListCatalog(
    client: Prisma.TransactionClient,
    providers: ProviderListRow[],
  ): Promise<ProviderListEntry[]> {
    const { cities, categories } = await this.catalogFor(
      client,
      providers,
      providers.flatMap((provider) => provider.services),
    );
    return providers.map(({ services, ...provider }) => ({
      ...this.withProviderCatalog(provider, cities, categories),
      servicePreviews: services.map(({ categoryId, ...service }) => ({
        ...service,
        category: this.required(categories.get(categoryId), "Provider category"),
      })),
    }));
  }

  async attachFavoriteProviders<T extends { provider: Provider }>(
    client: Prisma.TransactionClient,
    favorites: T[],
  ): Promise<Array<T & { provider: WithCatalog<Provider> }>> {
    const providers = await this.attachProviderCatalog(
      client,
      favorites.map((favorite) => favorite.provider),
    );
    return favorites.map((favorite, index) => ({
      ...favorite,
      provider: providers[index],
    }));
  }

  async attachServiceDetails<
    T extends ProviderService & { provider: Provider },
  >(
    client: Prisma.TransactionClient,
    services: T[],
  ): Promise<
    Array<
      T & {
        provider: WithCatalog<T["provider"]>;
        category: ProviderCategory;
        city: City | null;
      }
    >
  > {
    const { cities, categories } = await this.catalogFor(
      client,
      services.flatMap((service) => [service.provider, service]),
      services,
    );
    return services.map((service) => ({
      ...service,
      provider: this.withProviderCatalog(service.provider, cities, categories),
      category: this.required(categories.get(service.categoryId), "Provider category"),
      city: service.cityId ? (cities.get(service.cityId) ?? null) : null,
    }));
  }

  async attachQuoteRelations<T extends QuoteRow>(
    client: Prisma.TransactionClient,
    quotes: T[],
  ): Promise<Array<T & QuoteWithRelations>> {
    const { cities, categories } = await this.catalogFor(
      client,
      quotes.flatMap((quote) => [quote.provider, quote]),
      quotes.flatMap((quote) => (quote.service ? [quote.service] : [])),
    );
    const plans = new Map(
      (
        await this.plans.getPlans(
          client,
          unique(quotes.flatMap((quote) => (quote.weddingPlanId ? [quote.weddingPlanId] : []))),
        )
      ).map((plan) => [plan.id, plan]),
    );
    const costsByOffer = new Map(
      (
        await this.finance.listCostsForOffers(
          client,
          quotes.flatMap((quote) => quote.offers.map((offer) => offer.id)),
        )
      ).map((cost) => [cost.quoteOfferId, { id: cost.id }]),
    );
    return quotes.map((quote) => {
      const plan = quote.weddingPlanId ? plans.get(quote.weddingPlanId) : undefined;
      return {
        ...quote,
        provider: this.withProviderCatalog(quote.provider, cities, categories),
        service: quote.service
          ? {
              ...quote.service,
              category: this.required(categories.get(quote.service.categoryId), "Provider category"),
            }
          : null,
        city: quote.cityId ? (cities.get(quote.cityId) ?? null) : null,
        weddingPlan: plan
          ? { id: plan.id, title: plan.title, city: plan.city, weddingDate: plan.weddingDate }
          : null,
        offers: quote.offers.map((offer) => ({
          ...offer,
          weddingCosts: costsByOffer.has(offer.id) ? [costsByOffer.get(offer.id)!] : [],
        })),
      };
    });
  }

  async attachQuoteRelation<T extends QuoteRow>(
    client: Prisma.TransactionClient,
    quote: T,
  ): Promise<T & QuoteWithRelations> {
    const [hydrated] = await this.attachQuoteRelations(client, [quote]);
    return hydrated;
  }

  /** An offer with the plan currency and the service category its acceptance reads. */
  async attachOfferContext<
    T extends QuoteOffer & {
      quoteRequest: QuoteRequest & { service: ProviderService | null };
    },
  >(
    client: Prisma.TransactionClient,
    offer: T,
  ): Promise<
    T & {
      quoteRequest: T["quoteRequest"] & {
        weddingPlan: { id: string; currency: string } | null;
        service: (ProviderService & { category: ProviderCategory }) | null;
      };
    }
  > {
    const plan = offer.quoteRequest.weddingPlanId
      ? await this.plans.getPlan(client, offer.quoteRequest.weddingPlanId)
      : null;
    const service = offer.quoteRequest.service;
    const category = service
      ? this.required(
          (await this.catalog.getCategories(client, [service.categoryId]))[0],
          "Provider category",
        )
      : null;
    return {
      ...offer,
      quoteRequest: {
        ...offer.quoteRequest,
        weddingPlan: plan ? { id: plan.id, currency: plan.currency } : null,
        service: service && category ? { ...service, category } : null,
      },
    };
  }

  async attachReviewUsers<T extends ProviderReview>(
    client: Prisma.TransactionClient,
    reviews: T[],
  ): Promise<Array<T & ReviewWithUser>> {
    const users = new Map(
      (
        await this.users.getAppIdentities(
          client,
          unique(reviews.map((review) => review.userId)),
        )
      ).map((user) => [user.id, user]),
    );
    return reviews.map((review) => ({
      ...review,
      user: this.required(users.get(review.userId), "Review user"),
    }));
  }

  private async catalogFor(
    client: Prisma.TransactionClient,
    located: ReadonlyArray<{ cityId: string | null; primaryCategoryId?: string | null }>,
    categorized: ReadonlyArray<{ categoryId: string }>,
  ): Promise<{ cities: Map<string, City>; categories: Map<string, ProviderCategory> }> {
    const cityIds = unique(located.flatMap((row) => (row.cityId ? [row.cityId] : [])));
    const categoryIds = unique([
      ...located.flatMap((row) => (row.primaryCategoryId ? [row.primaryCategoryId] : [])),
      ...categorized.map((row) => row.categoryId),
    ]);
    const cities = new Map(
      (await this.catalog.getCities(client, cityIds)).map((city) => [city.id, city]),
    );
    const categories = new Map(
      (await this.catalog.getCategories(client, categoryIds)).map((category) => [
        category.id,
        category,
      ]),
    );
    return { cities, categories };
  }

  private withProviderCatalog<T extends Pick<Provider, "cityId" | "primaryCategoryId">>(
    provider: T,
    cities: Map<string, City>,
    categories: Map<string, ProviderCategory>,
  ): WithCatalog<T> {
    return {
      ...provider,
      city: this.required(cities.get(provider.cityId), "Provider city"),
      primaryCategory: provider.primaryCategoryId
        ? (categories.get(provider.primaryCategoryId) ?? null)
        : null,
    };
  }

  private required<T>(value: T | undefined, label: string): T {
    // A required relation (the FK is NOT NULL) is missing only when the
    // owner's row disappeared between the two statements.
    if (value === undefined) throw new Error(`${label} not found`);
    return value;
  }
}

function unique(ids: readonly string[]): string[] {
  return [...new Set(ids)];
}
