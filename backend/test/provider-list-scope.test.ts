import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { Prisma } from "@prisma/client";
import {
  countProvidersByCategory,
  readProviderDirectory,
  readProviderDirectoryPage,
} from "../src/marketplace/provider-directory";
import {
  cardPhotoUrl,
  lowestRialPrice,
  matchedCategoryId,
  pricedOffersInScope,
  providerCategoryIdsOf,
} from "../src/marketplace/provider-list-scope";
import {
  NEWCOMER_LIFT,
  newcomerLift,
  orderProviders,
  profileCompleteness,
  type RankSignals,
} from "../src/marketplace/provider-ranking";

// The 2026-11-26 review of the providers' list (docs/project/REFINEMENT_SPEC.md
// 2.7, docs/project/PROVIDER_RANKING.md): the price inside the asked
// category, the unrated after the rated, a smaller newcomer lift, a profile
// read from its work and a price, the card's photo, and the chips' counts
// equal to what each chip lists.

const NOW = new Date("2026-11-26T10:00:00.000Z");
const daysAgo = (days: number) => new Date(NOW.getTime() - days * 86_400_000);

const HALL = "11111111-1111-4111-8111-111111111111";
const PHOTO = "22222222-2222-4222-8222-222222222222";
const MUSIC = "33333333-3333-4333-8333-333333333333";
const SANAA = "44444444-4444-4444-8444-444444444444";

const yer = (value: string) => new Prisma.Decimal(value);

// ── The price and the category inside the asked scope ──────────────────────

const hallThatPhotographs = {
  primaryCategoryId: HALL,
  services: [
    { categoryId: PHOTO, basePrice: yer("300000"), currency: "YER", priceUpdatedAt: daysAgo(2) },
    { categoryId: HALL, basePrice: yer("2000000"), currency: "YER", priceUpdatedAt: daysAgo(9) },
  ],
  packages: [
    { price: yer("1500000"), currency: "YER", service: null },
    { price: yer("250000"), currency: "YER", service: { categoryId: PHOTO } },
  ],
};

test("under «تصوير» a hall that photographs is priced by his photography and its packages only", () => {
  const offers = pricedOffersInScope(hallThatPhotographs, [PHOTO]);
  assert.deepEqual(offers.map((offer) => offer.price.toString()).sort(), ["250000", "300000"]);
  assert.equal(lowestRialPrice(offers), 250000);
  // A package with no service is his main kind's: the hall's.
  assert.deepEqual(
    pricedOffersInScope(hallThatPhotographs, [HALL]).map((offer) => offer.price.toString()).sort(),
    ["1500000", "2000000"],
  );
  // No category asked: everything he priced.
  assert.equal(pricedOffersInScope(hallThatPhotographs, null).length, 4);
  assert.equal(lowestRialPrice(pricedOffersInScope(hallThatPhotographs, [MUSIC])), null);
});

test("a price in another currency is never the lowest rial price", () => {
  assert.equal(
    lowestRialPrice([
      { price: yer("100"), currency: "SAR", priceUpdatedAt: null },
      { price: yer("90000"), currency: "YER", priceUpdatedAt: null },
    ]),
    90000,
  );
});

test("the matched category is his main one when asked, else his newest service's, and nothing without a filter", () => {
  assert.equal(matchedCategoryId(hallThatPhotographs, [PHOTO]), PHOTO);
  assert.equal(matchedCategoryId(hallThatPhotographs, [HALL, PHOTO]), HALL);
  assert.equal(matchedCategoryId(hallThatPhotographs, null), null);
  assert.deepEqual(providerCategoryIdsOf(hallThatPhotographs).sort(), [HALL, PHOTO].sort());
});

// ── The order ──────────────────────────────────────────────────────────────

const row = (id: string, over: Partial<RankSignals> = {}) => ({
  id,
  claimed: true,
  verified: true,
  featuredNow: false,
  createdAt: daysAgo(400),
  ratingAverage: 0,
  ratingCount: 0,
  profile: 1,
  response: null,
  lowestPriceYer: null,
  ...over,
});

test("«الأعلى تقييمًا»: whoever has no review comes after every rated provider, however low they are rated", () => {
  const ids = orderProviders(
    [
      row("unrated-new", { createdAt: daysAgo(1) }),
      row("low", { ratingAverage: 2, ratingCount: 3 }),
      row("high", { ratingAverage: 4.9, ratingCount: 40 }),
      row("unrated-old"),
      row("unclaimed-rated", { claimed: false, ratingAverage: 5, ratingCount: 20 }),
    ],
    "rating",
    NOW,
  ).map((r) => r.id);
  // The smoothed average still orders the rated; the unrated keep «الأنسب»'s
  // order (the newer first); an unclaimed listing stays last (D41).
  assert.deepEqual(ids, ["high", "low", "unrated-new", "unrated-old", "unclaimed-rated"]);
});

test("the newcomer lift is at most 0.05 and fades out", () => {
  assert.equal(NEWCOMER_LIFT, 0.05);
  assert.equal(newcomerLift(NOW, NOW), 0.05);
  assert.ok(newcomerLift(daysAgo(15), NOW) < 0.05);
  assert.equal(newcomerLift(daysAgo(30), NOW), 0);
});

test("the profile counts five approved work photos and a published price, not a logo or a cover", () => {
  const base = { description: "d", address: "a", whatsapp: "w", socialLinks: null };
  assert.equal(profileCompleteness({ ...base, approvedPhotos: 5, hasPublishedPrice: true }), 1);
  assert.equal(profileCompleteness({ ...base, approvedPhotos: 4, hasPublishedPrice: true }), 0.8);
  assert.equal(profileCompleteness({ ...base, approvedPhotos: 9, hasPublishedPrice: false }), 0.8);
});

// ── The card's photo ───────────────────────────────────────────────────────

test("the card's photo is his first work photo, else the cover's small copy, else the cover", () => {
  assert.equal(
    cardPhotoUrl({ portfolioItems: [{ imageUrl: "work.jpg" }], coverThumbUrl: "cover-480.webp", coverUrl: "cover.jpg" }),
    "work.jpg",
  );
  assert.equal(cardPhotoUrl({ portfolioItems: [], coverThumbUrl: "cover-480.webp", coverUrl: "cover.jpg" }), "cover-480.webp");
  assert.equal(cardPhotoUrl({ portfolioItems: [], coverThumbUrl: null, coverUrl: "cover.jpg" }), "cover.jpg");
  assert.equal(cardPhotoUrl({ portfolioItems: [], coverThumbUrl: null, coverUrl: null }), null);
});

// ── A small database the list's own queries run against ────────────────────

type Row = Record<string, any>;

function provider(id: string, over: Row = {}): Row {
  return {
    id,
    userId: `user-${id}`,
    cityId: SANAA,
    primaryCategoryId: HALL,
    status: "ACTIVE",
    ownerLeavingAt: null,
    verifiedAt: daysAgo(100),
    ratingAverage: yer("0"),
    ratingCount: 0,
    createdAt: daysAgo(400),
    description: null,
    address: null,
    whatsapp: null,
    socialLinks: null,
    coverUrl: null,
    coverThumbUrl: null,
    featuredPeriods: [],
    services: [],
    packages: [],
    portfolio: [],
    ...over,
  };
}

const service = (categoryId: string, price: string | null, isActive = true) => ({
  title: `service ${categoryId.slice(0, 4)}`,
  categoryId,
  basePrice: price === null ? null : yer(price),
  currency: "YER",
  priceUpdatedAt: null,
  isActive,
});

/** Evaluates the list's where (status, services.some, OR, `in`/`notIn`, equality). */
function matches(row: Row, condition: Row): boolean {
  return Object.entries(condition).every(([key, value]) => {
    if (key === "AND") return (value as Row[]).every((part) => matches(row, part));
    if (key === "OR") return (value as Row[]).some((part) => matches(row, part));
    if (key === "services") return row.services.some((s: Row) => matches(s, value.some));
    if (value !== null && typeof value === "object" && "in" in value) return value.in.includes(row[key]);
    if (value !== null && typeof value === "object" && "notIn" in value) return !value.notIn.includes(row[key]);
    return row[key] === value;
  });
}

/** What the repository reads of a row: active services, the packages, the photos as asked. */
function shaped(row: Row, args: Row): Row {
  const photos = args.include?.portfolioItems;
  return {
    ...row,
    services: row.services.filter((s: Row) => s.isActive),
    portfolioItems: photos
      ? row.portfolio.filter((p: Row) => p.status === "APPROVED" && p.forWomen === photos.where.forWomen).slice(0, 1)
      : undefined,
    _count: { portfolioItems: row.portfolio.filter((p: Row) => p.status === "APPROVED").length },
  };
}

function fakeDatabase(rows: Row[]) {
  const reads: Row[] = [];
  const client: any = {
    $queryRaw: async () => [],
    $transaction: async (work: (tx: unknown) => unknown) => work(client),
    provider: {
      findMany: async (args: Row) => {
        reads.push(args);
        return rows.filter((row) => matches(row, args.where)).map((row) => shaped(row, args));
      },
    },
  };
  return { client, reads };
}

// The list's listing rule: approved, an active service, not leaving.
const directory = [
  provider("hall-a", { services: [service(HALL, "2000000")] }),
  provider("hall-photo", {
    services: [service(PHOTO, "300000"), service(HALL, "1800000")],
    packages: [{ price: yer("250000"), currency: "YER", service: { categoryId: PHOTO } }],
  }),
  provider("photographer", { primaryCategoryId: PHOTO, services: [service(PHOTO, "500000")] }),
  provider("photographer-cheap", { primaryCategoryId: PHOTO, services: [service(PHOTO, "200000")] }),
  // His music service is off: he is no musician to the list or the chips.
  provider("band-off", { primaryCategoryId: HALL, services: [service(HALL, null), service(MUSIC, "1", false)] }),
  provider("no-service", { primaryCategoryId: MUSIC, services: [service(MUSIC, "100", false)] }),
  provider("leaving", { primaryCategoryId: PHOTO, ownerLeavingAt: daysAgo(1), services: [service(PHOTO, "1")] }),
];

test("each chip's count is exactly the providers its category lists", async () => {
  const { client } = fakeDatabase(directory);
  const counts = await countProvidersByCategory(client, {}, NOW);
  assert.equal(counts.total, 5);
  for (const categoryId of [HALL, PHOTO, MUSIC]) {
    const page = await readProviderDirectoryPage(client, { categoryId, limit: "100" }, NOW);
    const counted = counts.categories.find((c) => c.categoryId === categoryId)?.count ?? 0;
    assert.equal(page.total, counted, `category ${categoryId}`);
    assert.equal(page.rows.length, counted, `category ${categoryId} rows`);
  }
  assert.equal(counts.categories.find((c) => c.categoryId === MUSIC), undefined, "an inactive service files nobody");
});

test("«الأقل سعرًا» under «تصوير» orders by photography prices and packages, not by the hall's", async () => {
  const { client } = fakeDatabase(directory);
  const page = await readProviderDirectoryPage(client, { categoryId: PHOTO, sort: "price" }, NOW);
  assert.equal(page.sort, "price");
  // hall-photo's photography package (250,000) is below the photographer at
  // 500,000; his hall price (1,800,000) is not read under «تصوير».
  assert.deepEqual(page.rows.map((r: Row) => r.id), ["photographer-cheap", "hall-photo", "photographer"]);
});

test("without a category the list is not ordered by price, and says so", async () => {
  const { client } = fakeDatabase(directory);
  const page = await readProviderDirectoryPage(client, { sort: "price" }, NOW);
  assert.equal(page.sort, "best");
});

// The catalog rows of the response, as MarketplaceRelationsService attaches them.
const categoryRow = (id: string) => ({
  id, nameAr: id === PHOTO ? "تصوير" : id === HALL ? "قاعات" : "فرق", nameEn: null, slug: id,
  icon: null, showForGroom: true, showForBride: true, isActive: true, sortOrder: 1,
});
const relations: any = {
  attachProviderListCatalog: async (_client: unknown, rows: Row[]) =>
    rows.map(({ services, ...row }) => ({
      ...row,
      city: null,
      primaryCategory: row.primaryCategoryId ? categoryRow(row.primaryCategoryId) : null,
      servicePreviews: services.map((s: Row) => ({ ...s, category: categoryRow(s.categoryId) })),
    })),
};

test("each row carries its price, its matched kind and its photo inside the asked category", async () => {
  const rows = directory.map((row) =>
    row.id === "hall-photo"
      ? {
          ...row,
          coverUrl: "cover.jpg",
          coverThumbUrl: "cover-480.webp",
          portfolio: [
            { imageUrl: "women.jpg", status: "APPROVED", forWomen: true },
            { imageUrl: "waiting.jpg", status: "PENDING", forWomen: false },
            { imageUrl: "work.jpg", status: "APPROVED", forWomen: false },
          ],
        }
      : row,
  );
  const { client, reads } = fakeDatabase(rows);
  const answer = await readProviderDirectory(client, relations, { categoryId: PHOTO }, NOW);
  const hall = answer.items.find((item: Row) => item.id === "hall-photo")!;
  assert.equal(hall.matchedCategory?.id, PHOTO, "found under «تصوير», not his hall kind");
  assert.equal(hall.serviceSummary.minPrice, "250000");
  assert.equal(hall.serviceSummary.maxPrice, "300000");
  assert.equal(hall.cardPhotoUrl, "work.jpg", "the women's album and a photo under review are never on a card");
  const pageRead = reads.find((args) => args.include)!;
  assert.deepEqual(pageRead.include.portfolioItems.where, { status: "APPROVED", forWomen: false });
  assert.equal("packages" in hall || "portfolioItems" in hall, false, "the raw rows stay out of the answer");
  const photographer = answer.items.find((item: Row) => item.id === "photographer")!;
  assert.equal(photographer.matchedCategory?.id, PHOTO);
  assert.equal(photographer.cardPhotoUrl, null);
  assert.equal(answer.sort, "best");
  assert.equal(answer.hideBusyApplied, false);
});

test("«أخفِ المشغولين» on a day already past is not applied, and the answer says so", async () => {
  const { client } = fakeDatabase(directory);
  const past = await readProviderDirectory(client, relations, { eventDate: "2026-01-01", hideBusy: "true" }, NOW);
  assert.equal(past.hideBusyApplied, false);
  assert.equal(past.total, 5, "nobody is hidden for a day that has passed");
});

test("«أخفِ المشغولين» on a coming day leaves out the busy and says it was applied", async () => {
  const { client } = fakeDatabase(directory);
  client.providerBlockedDate = {
    findMany: async ({ where }: Row) =>
      where.providerId.in.filter((id: string) => id === "hall-a").map((providerId: string) => ({ providerId })),
  };
  client.booking = { groupBy: async () => [] };
  const realFindMany = client.provider.findMany;
  client.provider.findMany = async (args: Row) =>
    args.select?.dailyBookingCapacity
      ? args.where.id.in.map((id: string) => ({ id, dailyBookingCapacity: 1 }))
      : realFindMany(args);
  const answer = await readProviderDirectory(client, relations, { eventDate: "2027-02-18", hideBusy: "true" }, NOW);
  assert.equal(answer.hideBusyApplied, true);
  assert.equal(answer.total, 4);
  assert.equal(answer.items.some((item: Row) => item.id === "hall-a"), false);
});
