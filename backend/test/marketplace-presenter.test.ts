import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { BadRequestException } from "@nestjs/common";
import { Prisma } from "@prisma/client";
import {
  MarketplacePresenter,
  MarketplaceQuery,
} from "../src/marketplace/marketplace.presenter";

test("marketplace pagination is bounded and rejects invalid values", () => {
  assert.deepEqual(MarketplaceQuery.parsePagination(), {
    page: 1,
    limit: 20,
    skip: 0,
  });
  assert.deepEqual(MarketplaceQuery.parsePagination("3", "500"), {
    page: 3,
    limit: 100,
    skip: 200,
  });
  assert.throws(
    () => MarketplaceQuery.parsePagination("0", "20"),
    BadRequestException,
  );
  assert.throws(
    () => MarketplaceQuery.parsePagination("1.5", "20"),
    BadRequestException,
  );
});

test("provider and service filters keep canonical active-only constraints", () => {
  const providers = MarketplaceQuery.providerSearch({
    page: "2",
    limit: "10",
    cityId: "17f8d6f4-18ee-4b57-b732-2c21a2bd0d92",
    categoryId: "27f8d6f4-18ee-4b57-b732-2c21a2bd0d92",
    featured: "true",
    search: " قاعة ",
  });
  assert.equal(providers.pagination.skip, 10);
  assert.ok(Array.isArray(providers.where.AND));
  const providerWhere = JSON.stringify(providers.where);
  assert.match(providerWhere, /ACTIVE/);
  assert.match(providerWhere, /قاعة/);
  assert.match(providerWhere, /services/);
  assert.match(providerWhere, /title/);
  assert.match(providerWhere, /description/);

  const services = MarketplaceQuery.serviceSearch({
    minPrice: "100",
    maxPrice: "500",
    search: " تصوير ",
  });
  assert.equal(services.where.isActive, true);
  assert.deepEqual(services.where.basePrice, { gte: "100", lte: "500" });
  assert.match(JSON.stringify(services.where), /تصوير/);
});

test("provider list response keeps category and active service summary", () => {
  const category = {
    id: "category-1",
    nameAr: "التصوير",
    nameEn: "Photography",
    slug: "photography",
    icon: null,
    isActive: true,
    sortOrder: 1,
  };
  const response = MarketplacePresenter.toProviderListResponse({
    id: "provider-1",
    cityId: null,
    primaryCategoryId: category.id,
    businessName: "استديو وعد",
    ownerName: "وعد",
    phone: null,
    whatsapp: null,
    email: null,
    description: null,
    address: null,
    latitude: null,
    longitude: null,
    logoUrl: null,
    coverUrl: null,
    status: "ACTIVE",
    isFeatured: false,
    ratingAverage: new Prisma.Decimal("0"),
    ratingCount: 0,
    createdAt: new Date("2026-07-25T00:00:00.000Z"),
    updatedAt: new Date("2026-07-25T00:00:00.000Z"),
    city: null,
    primaryCategory: category,
    servicePreviews: [
      {
        title: "تصوير فوتوغرافي",
        basePrice: new Prisma.Decimal("250000"),
        currency: "YER",
        category,
      },
      {
        title: "فيديو الزفاف",
        basePrice: new Prisma.Decimal("400000"),
        currency: "YER",
        category,
      },
    ],
  } as never);

  assert.equal(response.primaryCategory?.nameAr, "التصوير");
  assert.deepEqual(response.serviceSummary, {
    activeCount: 2,
    titles: ["تصوير فوتوغرافي", "فيديو الزفاف"],
    categories: [
      {
        id: "category-1",
        nameAr: "التصوير",
        nameEn: "Photography",
        slug: "photography",
        icon: null,
        isActive: true,
        sortOrder: 1,
      },
    ],
    minPrice: "250000",
    maxPrice: "400000",
    currency: "YER",
  });
});

test("marketplace service keeps Prisma orchestration outside pure presenters", () => {
  const service = readFileSync(
    "src/marketplace/marketplace.service.ts",
    "utf8",
  );
  const presenter = readFileSync(
    "src/marketplace/marketplace.presenter.ts",
    "utf8",
  );
  const contracts = readFileSync(
    "src/marketplace/marketplace.contracts.ts",
    "utf8",
  );

  assert.ok(service.split("\n").length <= 950);
  assert.match(service, /MarketplacePresenter\.toQuoteResponse/);
  assert.match(service, /this\.prisma\.\$transaction/);
  assert.doesNotMatch(service, /private toQuoteResponse/);
  assert.doesNotMatch(service, /private parsePagination/);

  assert.ok(presenter.split("\n").length <= 600);
  for (const forbidden of [
    "PrismaService",
    "NotificationsService",
    "PermissionService",
    "this.prisma",
    "this.notifications",
  ]) {
    assert.equal(presenter.includes(forbidden), false, forbidden);
  }
  assert.ok(contracts.split("\n").length <= 120);
});

test("marketplace reference catalog is installed by an idempotent migration", () => {
  const migration = readFileSync(
    "prisma/migrations/20260714100000_seed_provider_reference_catalog/migration.sql",
    "utf8",
  );

  assert.match(migration, /INSERT INTO "City"/);
  assert.match(
    migration,
    /ON CONFLICT \("nameAr", "countryCode"\) DO NOTHING/,
  );
  for (const city of ["صنعاء", "عدن", "تعز", "إب", "الحديدة", "المكلا"]) {
    assert.ok(migration.includes(city), city);
  }

  assert.match(migration, /INSERT INTO "ProviderCategory"/);
  assert.match(migration, /ON CONFLICT \("slug"\) DO NOTHING/);
  for (const slug of [
    "wedding-halls",
    "photography",
    "catering",
    "stage-decor",
    "dresses",
    "sound-lighting",
  ]) {
    assert.ok(migration.includes(slug), slug);
  }

  assert.doesNotMatch(migration, /\bDELETE\b/i);
  assert.doesNotMatch(migration, /\bUPDATE\b/i);
});
