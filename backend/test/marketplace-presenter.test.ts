import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { BadRequestException } from "@nestjs/common";
import { MarketplaceQuery } from "../src/marketplace/marketplace.presenter";

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
  assert.match(JSON.stringify(providers.where), /ACTIVE/);
  assert.match(JSON.stringify(providers.where), /قاعة/);

  const services = MarketplaceQuery.serviceSearch({
    minPrice: "100",
    maxPrice: "500",
    search: " تصوير ",
  });
  assert.equal(services.where.isActive, true);
  assert.deepEqual(services.where.basePrice, { gte: "100", lte: "500" });
  assert.match(JSON.stringify(services.where), /تصوير/);
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
