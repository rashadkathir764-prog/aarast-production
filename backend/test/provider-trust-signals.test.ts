import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { BadRequestException, ConflictException } from "@nestjs/common";
import {
  AdminRole,
  Prisma,
  ProviderStatus,
  UserRole,
  UserStatus,
} from "@prisma/client";
import { adminService } from "./support/owner-ports";
import {
  priceStampForNewService,
  priceStampForServiceUpdate,
} from "../src/modules/marketplace/infrastructure/service-price-stamp";
import {
  responsivenessWindow,
  summarizeResponsiveness,
} from "../src/marketplace/provider-responsiveness";
import { MarketplacePresenter } from "../src/marketplace/marketplace.presenter";

// Trust signals on a provider card: the admin "verified" badge, the date the
// price last changed, and how quickly the provider usually answers.

const reviewer = { id: "reviewer-admin", role: UserRole.ADMIN, adminMfa: true } as any;

function verificationPrisma(status: ProviderStatus, ownerId = "provider-owner") {
  const writes: any[] = [];
  const now = new Date();
  const tx = {
    $queryRaw: async (query: any) => {
      const text = query.strings?.join("") ?? String(query);
      if (text.includes('FROM "User"')) {
        return [
          { id: ownerId, role: UserRole.PROVIDER, adminRole: null, status: UserStatus.ACTIVE },
          { id: "reviewer-admin", role: UserRole.ADMIN, adminRole: AdminRole.OPERATIONS, status: UserStatus.ACTIVE },
        ]
          .filter((user, index, all) => all.findIndex((u) => u.id === user.id) === index)
          .sort((left, right) => left.id.localeCompare(right.id));
      }
      if (text.includes('FROM "Provider"')) return [{ id: "provider-1" }];
      throw new Error(`Unexpected lock: ${text}`);
    },
    // No featured placement on record (B-43).
    providerFeaturedPeriod: { findMany: async () => [] },
    portfolioItem: { findMany: async () => [] },
    provider: {
      findUnique: async () => ({ userId: ownerId, status }),
      update: async ({ data }: any) => {
        writes.push(data);
        return {
          id: "provider-1",
          userId: ownerId,
          cityId: "city-1",
          primaryCategoryId: null,
          businessName: "Hall",
          ownerName: null,
          phone: "+967777123456",
          whatsapp: null,
          email: null,
          description: null,
          address: null,
          logoUrl: null,
          coverUrl: null,
          status,
          resubmittedAt: null,
          resubmitCount: 0,
          reopenedAt: null,
          reviewedAt: null,
          reviewedById: null,
          verifiedAt: data.verifiedAt,
          verifiedById: data.verifiedById,
          ratingAverage: 0,
          ratingCount: 0,
          _count: { services: 0, packages: 0, quoteRequests: 0, reviews: 0 },
          services: [],
          packages: [],
          createdAt: now,
          updatedAt: now,
        };
      },
    },
    city: {
      findMany: async () => [
        { id: "city-1", nameAr: "صنعاء", nameEn: null, countryCode: "YE", sortOrder: 0, isActive: true },
      ],
    },
  };
  return {
    writes,
    prisma: { $transaction: async (operation: any) => operation(tx) } as any,
  };
}

function service(prisma: any) {
  return adminService(
    prisma,
    { disconnectUser: () => undefined } as any,
    { createNotificationInTransaction: async () => null } as any,
  );
}

test("an admin verifies an active provider and can clear the badge", async () => {
  const { prisma, writes } = verificationPrisma(ProviderStatus.ACTIVE);

  const verified = await service(prisma).setProviderVerified(reviewer, "provider-1", true);
  assert.ok(writes[0].verifiedAt instanceof Date);
  assert.equal(writes[0].verifiedById, "reviewer-admin");
  assert.equal(verified.verifiedAt, writes[0].verifiedAt);

  const cleared = await service(prisma).setProviderVerified(reviewer, "provider-1", false);
  assert.deepEqual(writes[1], { verifiedAt: null, verifiedById: null });
  assert.equal(cleared.verifiedAt, null);
});

test("only an active provider can be verified", async () => {
  for (const status of [
    ProviderStatus.PENDING,
    ProviderStatus.NEEDS_CHANGES,
    ProviderStatus.SUSPENDED,
    ProviderStatus.REJECTED,
  ]) {
    const { prisma, writes } = verificationPrisma(status);
    await assert.rejects(
      service(prisma).setProviderVerified(reviewer, "provider-1", true),
      ConflictException,
    );
    assert.equal(writes.length, 0);
  }
});

test("a provider owner cannot verify their own listing", async () => {
  const { prisma, writes } = verificationPrisma(ProviderStatus.ACTIVE, "reviewer-admin");
  await assert.rejects(
    service(prisma).setProviderVerified(reviewer, "provider-1", true),
    BadRequestException,
  );
  assert.equal(writes.length, 0);
});

function stampClient(current: { basePrice: string | null; currency: string }) {
  let reads = 0;
  return {
    get reads() {
      return reads;
    },
    client: {
      providerService: {
        findUnique: async () => {
          reads += 1;
          return {
            basePrice: current.basePrice === null ? null : new Prisma.Decimal(current.basePrice),
            currency: current.currency,
          };
        },
      },
    } as any,
  };
}

test("a new service is price-stamped only when it has a price", () => {
  assert.ok(priceStampForNewService("1000") instanceof Date);
  assert.equal(priceStampForNewService(null), null);
});

test("the price stamp moves only when the price itself changes", async () => {
  const priced = { basePrice: "150000", currency: "YER" };

  const untouched = stampClient(priced);
  assert.deepEqual(await priceStampForServiceUpdate(untouched.client, "s", {}), {});
  assert.equal(untouched.reads, 0);

  assert.deepEqual(
    await priceStampForServiceUpdate(stampClient(priced).client, "s", { basePrice: "150000.00" }),
    {},
  );

  const raised = await priceStampForServiceUpdate(stampClient(priced).client, "s", { basePrice: "175000" });
  assert.ok((raised as any).priceUpdatedAt instanceof Date);

  const recurrenced = await priceStampForServiceUpdate(stampClient(priced).client, "s", { currency: "SAR" });
  assert.ok((recurrenced as any).priceUpdatedAt instanceof Date);

  assert.deepEqual(
    await priceStampForServiceUpdate(stampClient(priced).client, "s", { basePrice: null }),
    { priceUpdatedAt: null },
  );

  const firstPrice = await priceStampForServiceUpdate(
    stampClient({ basePrice: null, currency: "YER" }).client,
    "s",
    { basePrice: "90000" },
  );
  assert.ok((firstPrice as any).priceUpdatedAt instanceof Date);
});

test("responsiveness says nothing until there are enough requests", () => {
  assert.equal(summarizeResponsiveness({ requests: 2, answered: 2, medianMinutes: 30 }), null);
  assert.deepEqual(summarizeResponsiveness({ requests: 4, answered: 3, medianMinutes: 30 }), {
    sampleSize: 4,
    answeredPercent: 75,
    typicalResponseHours: 1,
  });
  assert.deepEqual(summarizeResponsiveness({ requests: 5, answered: 5, medianMinutes: 181 }), {
    sampleSize: 5,
    answeredPercent: 100,
    typicalResponseHours: 4,
  });
  assert.deepEqual(summarizeResponsiveness({ requests: 3, answered: 0, medianMinutes: null }), {
    sampleSize: 3,
    answeredPercent: 0,
    typicalResponseHours: null,
  });
});

test("responsiveness gives unanswered requests a grace period", () => {
  const now = new Date("2026-10-11T12:00:00.000Z");
  const window = responsivenessWindow(now);
  assert.equal(window.settledBefore.toISOString(), "2026-10-09T12:00:00.000Z");
  assert.equal(window.since.toISOString(), "2026-04-14T12:00:00.000Z");
});

test("the provider list shows when its prices last changed", () => {
  const now = new Date("2026-10-11T00:00:00.000Z");
  const category = { id: "cat-1", nameAr: "قاعات", nameEn: null, slug: "halls", icon: null, showForGroom: true, showForBride: true, isActive: true, sortOrder: 0 } as any;
  const response = MarketplacePresenter.toProviderListResponse({
    id: "provider-1",
    cityId: "city-1",
    primaryCategoryId: null,
    businessName: "Hall",
    ownerName: null,
    phone: "+967777123456",
    whatsapp: null,
    email: null,
    description: null,
    address: null,
    latitude: null,
    longitude: null,
    logoUrl: null,
    coverUrl: null,
    status: ProviderStatus.ACTIVE,
    verifiedAt: now,
    featuredPeriods: [],
    ratingAverage: new Prisma.Decimal(0),
    ratingCount: 0,
    createdAt: now,
    updatedAt: now,
    servicePreviews: [
      { title: "A", basePrice: new Prisma.Decimal(1), currency: "YER", priceUpdatedAt: new Date("2026-09-01T00:00:00.000Z"), category },
      { title: "B", basePrice: new Prisma.Decimal(2), currency: "YER", priceUpdatedAt: new Date("2026-10-01T00:00:00.000Z"), category },
      { title: "C", basePrice: null, currency: "YER", priceUpdatedAt: null, category },
    ],
  } as any);

  assert.equal(response.verifiedAt, now);
  assert.equal(
    response.serviceSummary.pricesUpdatedAt?.toISOString(),
    "2026-10-01T00:00:00.000Z",
  );
});
