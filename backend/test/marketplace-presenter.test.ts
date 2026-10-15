import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { BadRequestException } from "@nestjs/common";
import { Prisma } from "@prisma/client";
import { readLivePrismaSchema } from './support/live-prisma-schema';
import {
  MarketplacePresenter,
  MarketplaceQuery,
} from "../src/marketplace/marketplace.presenter";
import { YemenAdministrativePresenter } from "../src/marketplace/yemen-administrative.presenter";

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

// Field test Q14: an approved provider with no service was listed as an empty
// card leading to an empty page.
test("the directory lists only providers that offer an active service", () => {
  const { where } = MarketplaceQuery.providerSearch({});
  assert.deepEqual(where.AND, [
    { status: "ACTIVE" },
    { services: { some: { isActive: true } } },
  ]);
});

test("provider list response keeps category and active service summary", () => {
  const category = {
    id: "category-1",
    nameAr: "التصوير",
    nameEn: "Photography",
    slug: "photography",
    icon: null,
    showForGroom: true,
    showForBride: true,
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
        priceUpdatedAt: new Date("2026-07-20T00:00:00.000Z"),
        category,
      },
      {
        title: "فيديو الزفاف",
        basePrice: new Prisma.Decimal("400000"),
        currency: "YER",
        priceUpdatedAt: new Date("2026-07-24T00:00:00.000Z"),
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
        showForGroom: true,
        showForBride: true,
        isActive: true,
        sortOrder: 1,
      },
    ],
    minPrice: "250000",
    maxPrice: "400000",
    currency: "YER",
    pricesUpdatedAt: new Date("2026-07-24T00:00:00.000Z"),
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

  // Growth guard. R12C Task 3 replaced five direct Messaging imports with one
  // injected lifecycle port: +1 import, +2 constructor lines, +5 call-site
  // arguments (957 lines). The ownership program then routed quote
  // acceptance's cost creation through the injected Finance port: +4 import
  // lines, +2 constructor lines, +1 call-site argument, +3 lines passing the
  // marketplace-owned provider name to the finance presenter (967 lines).
  // The ownership program then stopped the service reading catalog's,
  // planning's, identity's and finance's tables: +4 import lines, +4
  // constructor lines (catalog and scope ports, the relations service), +7
  // lines of the quote-scope port bundle, +2 call-site arguments per quote
  // script (+9), and the own-table read followed by the owner attach in
  // place of each include (+56 net across providers, services, reviews,
  // favorites, plan quotes and my quotes), against the catalog list
  // methods delegated to catalog's port (-31): 998 lines, 999 with the
  // trailing newline this split counts. The mission's exit review then made
  // each live authorization re-check share one RepeatableRead snapshot with
  // the read it guards (the single statement it had replaced did): +3
  // import lines and the transaction wrappers of the plan quote list and the
  // plan quote lookup (+13 net): 1,014 lines, 1,015 with the trailing
  // newline. The budget moves by exactly those approved deltas.
  assert.ok(service.split("\n").length <= 1015);
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
  // The contracts declare the provider/service search filters and the
  // user's quote-access filter by their exact keys (+36) so the ownership
  // scan proves their shape, and shrink the quote include to marketplace's
  // own relations (-12): 124 lines, 125 with the trailing newline. Bookings
  // (V1 checklist 4.6) add the quote's booking relation to the include, its
  // type and the Booking import (+3): 128 with the trailing newline.
  assert.ok(contracts.split("\n").length <= 128);
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

test("provider category audience migration separates groom and bride discovery", () => {
  const migration = readFileSync(
    "prisma/migrations/20260729030000_add_provider_category_audience_catalog/migration.sql",
    "utf8",
  );
  const schema = readLivePrismaSchema();
  const presenter = readFileSync(
    "src/marketplace/marketplace.presenter.ts",
    "utf8",
  );

  assert.match(schema, /showForGroom\s+Boolean\s+@default\(true\)/);
  assert.match(schema, /showForBride\s+Boolean\s+@default\(true\)/);
  assert.match(presenter, /showForGroom: category\.showForGroom/);
  assert.match(presenter, /showForBride: category\.showForBride/);

  for (const shared of ["wedding-halls", "photography", "soft-drinks"]) {
    assert.ok(migration.includes(shared), shared);
  }
  for (const bride of ["makeup", "henna", "dance-troupe"]) {
    assert.ok(migration.includes(bride), bride);
  }
  for (const groom of ["qat", "barber", "security-entry"]) {
    assert.ok(migration.includes(groom), groom);
  }

  assert.doesNotMatch(migration, /\bDELETE\b/i);
});

test("provider category reconciliation uses stable slugs and preserves references", () => {
  const migration = readFileSync(
    "prisma/migrations/20260729050000_reconcile_provider_category_catalog/migration.sql",
    "utf8",
  );

  for (const canonical of [
    "wedding-halls",
    "photography",
    "catering",
    "stage-decor",
    "dresses",
    "sound-lighting",
    "dance-troupe",
    "mizmar-folk-band",
    "refrigerators",
  ]) {
    assert.ok(migration.includes(canonical), canonical);
  }

  assert.match(migration, /WHERE category\."slug" = desired\."slug"/);
  assert.match(migration, /UPDATE "Provider" AS provider/);
  assert.match(migration, /UPDATE "ProviderService" AS service/);
  assert.match(
    migration,
    /WHERE provider\."primaryCategoryId" = legacy\.id/,
  );
  assert.match(migration, /WHERE service\."categoryId" = legacy\.id/);
  assert.match(migration, /'مراقصة', 'dance-troupe'/);
  assert.match(migration, /"isActive" = false/);
  assert.doesNotMatch(migration, /\bDELETE\b/i);
});

test("Yemen administrative catalog installs 22 governorates and 335 districts", () => {
  const migration = readFileSync(
    "prisma/migrations/20260729040000_add_yemen_administrative_catalog/migration.sql",
    "utf8",
  );
  const controller = readFileSync(
    "src/marketplace/marketplace.controller.ts",
    "utf8",
  );

  assert.equal(
    migration.match(/\('c3000000-0000-4000-8000-/g)?.length,
    22,
  );
  assert.equal(
    migration.match(/\('d4000000-0000-4000-8000-/g)?.length,
    335,
  );
  assert.match(migration, /'YE13', 'أمانة العاصمة'/);
  assert.match(migration, /OCHA Yemen \/ CSO via HDX/);
  assert.doesNotMatch(migration, /truncated|NEXT_DISTRICT_BATCH/);
  assert.match(controller, /@Controller\("api\/v1\/governorates"\)/);
  assert.match(controller, /@Get\(":id\/districts"\)/);
});

test("Yemen administrative presenters preserve stable codes and coordinates", () => {
  assert.deepEqual(
    YemenAdministrativePresenter.toGovernorateResponse({
      id: "governorate-1",
      code: "YE13",
      nameAr: "أمانة العاصمة",
      nameEn: "Sana'a City",
      latitude: 15.40928,
      longitude: 44.17555835,
      isActive: true,
      sortOrder: 10,
      createdAt: new Date(),
      updatedAt: new Date(),
      _count: { districts: 10 },
    } as never),
    {
      id: "governorate-1",
      code: "YE13",
      nameAr: "أمانة العاصمة",
      nameEn: "Sana'a City",
      latitude: 15.40928,
      longitude: 44.17555835,
      sortOrder: 10,
      districtsCount: 10,
    },
  );

  assert.deepEqual(
    YemenAdministrativePresenter.toDistrictResponse({
      id: "district-1",
      governorateId: "governorate-1",
      code: "YE1301",
      nameAr: "صنعاء القديمة",
      nameEn: "Old City",
      latitude: 15.35493,
      longitude: 44.21484244,
      isActive: true,
      sortOrder: 10,
      createdAt: new Date(),
      updatedAt: new Date(),
    }),
    {
      id: "district-1",
      governorateId: "governorate-1",
      code: "YE1301",
      nameAr: "صنعاء القديمة",
      nameEn: "Old City",
      latitude: 15.35493,
      longitude: 44.21484244,
      sortOrder: 10,
    },
  );
});
