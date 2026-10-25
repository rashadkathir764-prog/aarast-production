import { Inject, Injectable } from '@nestjs/common';
import type {
  City,
  Prisma,
  ProviderCategory,
} from '@prisma/client';
import {
  CATALOG_ADMIN_PORT,
  type CatalogAdminPort,
} from '../modules/catalog/public/catalog-admin.port';
import {
  CATALOG_READ_PORT,
  type CatalogReadPort,
} from '../modules/catalog/public/catalog-read.port';
import {
  COLLABORATION_PERMISSION_PORT,
  type CollaborationPermissionPort,
} from '../modules/collaboration/public/collaboration-permission.port';
import {
  FINANCE_PORT,
  type FinancePort,
} from '../modules/finance/public/finance.port';
import {
  type AdminAccountRow,
  IDENTITY_ADMIN_PORT,
  type IdentityAdminPort,
} from '../modules/identity/public/identity-admin.port';
import {
  PROVIDER_ACCOUNT_PORT,
  type ProviderAccountPort,
} from '../modules/identity/public/provider-account.port';
import {
  USER_READ_PORT,
  type UserReadPort,
} from '../modules/identity/public/user-read.port';
import {
  type AdminClaimRequestRow,
  type AdminFeaturedPeriodRow,
  type AdminProviderDetailRow,
  type AdminProviderReviewEvent,
  type AdminProviderRow,
  type AdminReviewRow,
  type AdminServiceRow,
  MARKETPLACE_ADMIN_PORT,
  type MarketplaceAdminPort,
} from '../modules/marketplace/public/marketplace-admin.port';
import {
  PROVIDER_READ_PORT,
  type ProviderReadPort,
} from '../modules/marketplace/public/provider-read.port';
import {
  QUOTE_READ_PORT,
  type QuoteReadPort,
} from '../modules/marketplace/public/quote-read.port';
import {
  type AdminConversationReportRow,
  MESSAGING_ADMIN_PORT,
  type MessagingAdminPort,
} from '../modules/messaging/public/messaging-admin.port';
import {
  NOTIFICATIONS_ADMIN_PORT,
  type NotificationsAdminPort,
} from '../modules/notifications/public/notifications-admin.port';
import {
  PLAN_READ_PORT,
  type PlanReadPort,
} from '../modules/planning/public/plan-read.port';
import type {
  AdminCategoryRecord,
  AdminCityRecord,
  AdminClaimRequestRecord,
  AdminFeaturedPeriodRecord,
  AdminProviderRecord,
  AdminProviderReviewEventRecord,
  AdminReviewWithDetails,
  AdminServiceWithDetails,
  AdminUserRecord,
  SafeAdminUser,
} from './admin.presenter';

type Client = Prisma.TransactionClient;

/** A conversation report as the back office lists it. */
export interface AdminConversationReportView {
  id: string;
  conversationId: string;
  reason: string;
  status: AdminConversationReportRow['status'];
  createdAt: Date;
  updatedAt: Date;
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
}

/**
 * The back office owns no table but its audit log. Every other row it
 * shows or changes belongs to an owner and is reached through that owner's
 * port, held here; the attach methods put the owners' rows the presenters
 * render (catalog entries, accounts, plans, providers) next to the rows an
 * owner returned, on the same client.
 */
@Injectable()
export class AdminOwners {
  constructor(
    @Inject(IDENTITY_ADMIN_PORT) readonly accounts: IdentityAdminPort,
    @Inject(PROVIDER_ACCOUNT_PORT) readonly providerAccounts: ProviderAccountPort,
    @Inject(USER_READ_PORT) private readonly users: UserReadPort,
    @Inject(CATALOG_ADMIN_PORT) readonly catalog: CatalogAdminPort,
    @Inject(CATALOG_READ_PORT) private readonly catalogRead: CatalogReadPort,
    @Inject(MARKETPLACE_ADMIN_PORT) readonly marketplace: MarketplaceAdminPort,
    @Inject(PROVIDER_READ_PORT) private readonly providerRead: ProviderReadPort,
    @Inject(QUOTE_READ_PORT) private readonly quotes: QuoteReadPort,
    @Inject(MESSAGING_ADMIN_PORT) readonly messaging: MessagingAdminPort,
    @Inject(NOTIFICATIONS_ADMIN_PORT) readonly notifications: NotificationsAdminPort,
    @Inject(PLAN_READ_PORT) readonly plans: PlanReadPort,
    @Inject(COLLABORATION_PERMISSION_PORT)
    readonly collaboration: CollaborationPermissionPort,
    // The success indicators count recorded costs (V1 checklist 4.21).
    @Inject(FINANCE_PORT) readonly finance: FinancePort,
  ) {}

  async attachProviders(
    client: Client,
    rows: readonly AdminProviderRow[],
  ): Promise<AdminProviderRecord[]> {
    const [accounts, cities, categories, featured] = await Promise.all([
      this.accountMap(
        client,
        rows.flatMap((row) => [row.userId, row.reviewedById]),
      ),
      this.cityMap(client, rows.map((row) => row.cityId)),
      this.categoryMap(client, rows.map((row) => row.primaryCategoryId)),
      this.marketplace.listActiveFeaturedPeriods(
        client,
        rows.map((row) => row.id),
        new Date(),
      ),
    ]);
    const featuredUntil = new Map(
      featured.map((period) => [period.providerId, period.endsAt]),
    );
    return rows.map((row) => ({
      ...row,
      featuredUntil: featuredUntil.get(row.id) ?? null,
      user: row.userId ? (accounts.get(row.userId) ?? null) : null,
      reviewedBy: row.reviewedById
        ? (accounts.get(row.reviewedById) ?? null)
        : null,
      city: required(cities, row.cityId, 'City'),
      primaryCategory: row.primaryCategoryId
        ? required(categories, row.primaryCategoryId, 'Provider category')
        : null,
    }));
  }

  /** A claim's listing (with its city and category) and the accounts that asked and decided (B-12). */
  async attachClaimRequests(
    client: Client,
    rows: readonly AdminClaimRequestRow[],
  ): Promise<AdminClaimRequestRecord[]> {
    const [accounts, cities, categories] = await Promise.all([
      this.accountMap(
        client,
        rows.flatMap((row) => [row.userId, row.decidedById]),
      ),
      this.cityMap(client, rows.map((row) => row.provider.cityId)),
      this.categoryMap(client, rows.map((row) => row.provider.primaryCategoryId)),
    ]);
    return rows.map((row) => ({
      ...row,
      claimant: accounts.get(row.userId) ?? null,
      decidedBy: row.decidedById ? (accounts.get(row.decidedById) ?? null) : null,
      provider: {
        ...row.provider,
        city: required(cities, row.provider.cityId, 'City'),
        primaryCategory: row.provider.primaryCategoryId
          ? required(categories, row.provider.primaryCategoryId, 'Provider category')
          : null,
      },
    }));
  }

  /** A placement's listing (with its city and category) and who recorded and ended it (B-43). */
  async attachFeaturedPeriods(
    client: Client,
    rows: readonly AdminFeaturedPeriodRow[],
  ): Promise<AdminFeaturedPeriodRecord[]> {
    const [accounts, cities, categories] = await Promise.all([
      this.accountMap(
        client,
        rows.flatMap((row) => [row.grantedById, row.endedById]),
      ),
      this.cityMap(client, rows.map((row) => row.provider.cityId)),
      this.categoryMap(client, rows.map((row) => row.provider.primaryCategoryId)),
    ]);
    return rows.map((row) => ({
      ...row,
      grantedBy: accounts.get(row.grantedById) ?? null,
      endedBy: row.endedById ? (accounts.get(row.endedById) ?? null) : null,
      provider: {
        ...row.provider,
        city: required(cities, row.provider.cityId, 'City'),
        primaryCategory: row.provider.primaryCategoryId
          ? required(categories, row.provider.primaryCategoryId, 'Provider category')
          : null,
      },
    }));
  }

  /** The accounts that took these review steps (B-01, B-02). */
  async attachReviewEvents(
    client: Client,
    events: readonly AdminProviderReviewEvent[],
  ): Promise<AdminProviderReviewEventRecord[]> {
    const accounts = await this.accountMap(
      client,
      events.map((event) => event.actorId),
    );
    return events.map((event) => ({
      ...event,
      actor: event.actorId ? (accounts.get(event.actorId) ?? null) : null,
    }));
  }

  async attachProviderDetail(
    client: Client,
    row: AdminProviderDetailRow,
  ): Promise<AdminProviderRecord> {
    const [[provider], cities, categories] = await Promise.all([
      this.attachProviders(client, [row]),
      this.cityMap(client, row.services.map((service) => service.cityId)),
      this.categoryMap(client, row.services.map((service) => service.categoryId)),
    ]);
    return {
      ...provider!,
      services: row.services.map((service) => ({
        ...service,
        category: required(categories, service.categoryId, 'Provider category'),
        city: service.cityId ? required(cities, service.cityId, 'City') : null,
      })),
      packages: row.packages,
    };
  }

  async attachServices(
    client: Client,
    rows: readonly AdminServiceRow[],
  ): Promise<AdminServiceWithDetails[]> {
    const [cities, categories] = await Promise.all([
      this.cityMap(
        client,
        rows.flatMap((row) => [row.cityId, row.provider.cityId]),
      ),
      this.categoryMap(
        client,
        rows.flatMap((row) => [row.categoryId, row.provider.primaryCategoryId]),
      ),
    ]);
    return rows.map((row) => ({
      ...row,
      provider: {
        ...row.provider,
        city: required(cities, row.provider.cityId, 'City'),
        primaryCategory: row.provider.primaryCategoryId
          ? required(categories, row.provider.primaryCategoryId, 'Provider category')
          : null,
      },
      category: required(categories, row.categoryId, 'Provider category'),
      city: row.cityId ? required(cities, row.cityId, 'City') : null,
    }));
  }

  async attachReviews(
    client: Client,
    rows: readonly AdminReviewRow[],
  ): Promise<AdminReviewWithDetails[]> {
    const [reviewers, cities, categories] = await Promise.all([
      this.users.getAppIdentities(client, unique(rows.map((row) => row.userId))),
      this.cityMap(client, rows.map((row) => row.provider.cityId)),
      this.categoryMap(client, rows.map((row) => row.provider.primaryCategoryId)),
    ]);
    const reviewerById = new Map(reviewers.map((user) => [user.id, user]));
    return rows.map((row) => {
      const reviewer = required(reviewerById, row.userId, 'Reviewer');
      return {
        ...row,
        user: {
          id: reviewer.id,
          name: reviewer.name,
          appName: reviewer.appName,
          role: reviewer.role,
        },
        provider: {
          ...row.provider,
          city: required(cities, row.provider.cityId, 'City'),
          primaryCategory: row.provider.primaryCategoryId
            ? required(categories, row.provider.primaryCategoryId, 'Provider category')
            : null,
        },
      };
    });
  }

  async attachCategories(
    client: Client,
    rows: readonly ProviderCategory[],
  ): Promise<AdminCategoryRecord[]> {
    const usage = await this.marketplace.countCategoryUsage(
      client,
      rows.map((row) => row.id),
    );
    const usageById = new Map(usage.map((entry) => [entry.id, entry]));
    return rows.map((row) => ({
      ...row,
      _count: {
        providers: usageById.get(row.id)?.providers ?? 0,
        services: usageById.get(row.id)?.services ?? 0,
      },
    }));
  }

  async attachCities(
    client: Client,
    rows: readonly City[],
  ): Promise<AdminCityRecord[]> {
    const usage = await this.marketplace.countCityUsage(
      client,
      rows.map((row) => row.id),
    );
    const usageById = new Map(usage.map((entry) => [entry.id, entry]));
    return rows.map((row) => ({
      ...row,
      _count: {
        providers: usageById.get(row.id)?.providers ?? 0,
        services: usageById.get(row.id)?.services ?? 0,
      },
    }));
  }

  async attachAccounts(
    client: Client,
    rows: readonly AdminAccountRow[],
  ): Promise<AdminUserRecord[]> {
    const profiles = await this.marketplace.getAccountProviders(
      client,
      rows.map((row) => row.id),
    );
    const [cities, categories] = await Promise.all([
      this.cityMap(client, profiles.map((profile) => profile.cityId)),
      this.categoryMap(client, profiles.map((profile) => profile.primaryCategoryId)),
    ]);
    const profileByUserId = new Map(
      profiles.map((profile) => [profile.userId, profile]),
    );
    return rows.map((row) => {
      const profile = profileByUserId.get(row.id);
      return {
        ...row,
        providerProfile: profile
          ? {
              ...profile,
              city: required(cities, profile.cityId, 'City'),
              primaryCategory: profile.primaryCategoryId
                ? required(categories, profile.primaryCategoryId, 'Provider category')
                : null,
            }
          : null,
      };
    });
  }

  async attachConversationReports(
    client: Client,
    rows: readonly AdminConversationReportRow[],
  ): Promise<AdminConversationReportView[]> {
    const [reporters, providers, latestQuotes] = await Promise.all([
      this.users.getAppIdentities(
        client,
        unique(rows.map((row) => row.reporterUserId)),
      ),
      this.providerRead.getProviders(
        client,
        unique(rows.map((row) => row.conversation.providerId)),
      ),
      this.quotes.getLatestConversationQuoteRequests(
        client,
        unique(rows.map((row) => row.conversationId)),
      ),
    ]);
    const reporterById = new Map(reporters.map((user) => [user.id, user]));
    const providerById = new Map(providers.map((provider) => [provider.id, provider]));
    const latestQuoteByConversation = new Map(
      latestQuotes.map((quote) => [quote.conversationId, quote.id]),
    );
    return rows.map((row) => {
      const reporter = required(reporterById, row.reporterUserId, 'Reporter');
      const provider = required(providerById, row.conversation.providerId, 'Provider');
      const latestQuoteId = latestQuoteByConversation.get(row.conversationId);
      return {
        id: row.id,
        conversationId: row.conversationId,
        reason: row.reason,
        status: row.status,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        reporter: {
          id: reporter.id,
          name: reporter.name,
          phone: reporter.phone,
          avatarUrl: reporter.avatarUrl,
        },
        conversation: {
          provider: { id: provider.id, businessName: provider.businessName },
          quoteRequests: latestQuoteId ? [{ id: latestQuoteId }] : [],
        },
      };
    });
  }

  private async accountMap(
    client: Client,
    ids: ReadonlyArray<string | null>,
  ): Promise<Map<string, SafeAdminUser>> {
    const accounts = await this.accounts.getAccounts(client, unique(ids));
    return new Map(accounts.map((account) => [account.id, account]));
  }

  /** The Arabic names of these cities and categories, for a report. */
  async catalogNames(
    client: Client,
    cityIds: readonly string[],
    categoryIds: readonly string[],
  ): Promise<{ cities: Map<string, string>; categories: Map<string, string> }> {
    const [cities, categories] = await Promise.all([
      this.cityMap(client, cityIds),
      this.categoryMap(client, categoryIds),
    ]);
    return {
      cities: new Map([...cities].map(([id, city]) => [id, city.nameAr])),
      categories: new Map(
        [...categories].map(([id, category]) => [id, category.nameAr]),
      ),
    };
  }

  private async cityMap(
    client: Client,
    ids: ReadonlyArray<string | null>,
  ): Promise<Map<string, City>> {
    const cities = await this.catalogRead.getCities(client, unique(ids));
    return new Map(cities.map((city) => [city.id, city]));
  }

  private async categoryMap(
    client: Client,
    ids: ReadonlyArray<string | null>,
  ): Promise<Map<string, ProviderCategory>> {
    const categories = await this.catalogRead.getCategories(client, unique(ids));
    return new Map(categories.map((category) => [category.id, category]));
  }
}

function unique(ids: ReadonlyArray<string | null>): string[] {
  return [...new Set(ids.filter((id): id is string => Boolean(id)))];
}

/** A row another owner guarantees by a foreign key; its absence is a broken invariant, not a user error. */
function required<T>(rows: ReadonlyMap<string, T>, id: string, label: string): T {
  const row = rows.get(id);
  if (!row) throw new Error(`${label} ${id} referenced by the back office read is missing`);
  return row;
}
