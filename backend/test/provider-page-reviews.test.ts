import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { BadRequestException } from "@nestjs/common";
import { plainToInstance } from "class-transformer";
import { validateSync } from "class-validator";
import { ListProviderReviewsQueryDto } from "../src/marketplace/dto/list-provider-reviews-query.dto";
import { MarketplaceQuery } from "../src/marketplace/marketplace.presenter";
import { askedAvailabilityDay } from "../src/marketplace/provider-day-availability";
import {
  readProviderReviewPage,
  reviewSummary,
  REVIEWS_PAGE_MAX,
} from "../src/marketplace/provider-review-page";
import { marketplaceService } from "./support/owner-ports";

// The 2026-11-26 review of a provider's page: it says what is known of the
// plan's day as the list does, and its reviews come a page at a time with
// the summary of them all.

const NOW = new Date("2026-11-26T10:00:00.000Z");
const PROVIDER = "55555555-5555-4555-8555-555555555555";

test("the page's day is read exactly as the list's: a malformed one is a 400, a past one asks nothing", () => {
  assert.equal(askedAvailabilityDay(undefined, NOW), null);
  assert.equal(askedAvailabilityDay(" ", NOW), null);
  assert.equal(
    askedAvailabilityDay("2027-02-18", NOW)?.toISOString(),
    "2027-02-18T00:00:00.000Z",
  );
  assert.equal(askedAvailabilityDay("2026-01-01", NOW), null);
  assert.throws(() => askedAvailabilityDay("2027-02-30", NOW), BadRequestException);
  assert.equal(
    MarketplaceQuery.providerSearch({ eventDate: "2027-02-18" }, NOW).availabilityDay?.toISOString(),
    askedAvailabilityDay("2027-02-18", NOW)?.toISOString(),
  );
});

function detailsDatabase(options: { closed?: boolean; confirmed?: number; capacity?: number }) {
  const providerRow = {
    id: PROVIDER, userId: "owner", cityId: "c1", primaryCategoryId: null, businessName: "قاعة الريان",
    ownerName: null, phone: "777", whatsapp: null, email: null, description: null, address: null,
    latitude: null, longitude: null, logoUrl: null, coverUrl: null, logoThumbUrl: null,
    logoMediumUrl: null, coverThumbUrl: null, coverMediumUrl: null, status: "ACTIVE",
    verifiedAt: null, ratingAverage: { toString: () => "0" }, ratingCount: 0,
    createdAt: NOW, updatedAt: NOW, featuredPeriods: [], services: [],
    city: { id: "c1", nameAr: "صنعاء", nameEn: null, countryCode: "YE", isActive: true, sortOrder: 1 },
  };
  const asked: string[] = [];
  return {
    asked,
    prisma: {
      $queryRaw: async () => [],
      provider: {
        findFirst: async () => providerRow,
        findMany: async ({ where }: any) =>
          where.id.in.map((id: string) => ({ id, dailyBookingCapacity: options.capacity ?? 1 })),
      },
      providerBlockedDate: {
        findMany: async ({ where }: any) => {
          asked.push(where.date.toISOString());
          return options.closed ? [{ providerId: PROVIDER }] : [];
        },
      },
      booking: {
        groupBy: async () =>
          options.confirmed ? [{ providerId: PROVIDER, _count: { _all: options.confirmed } }] : [],
      },
    },
  };
}

const service = (prisma: unknown) =>
  marketplaceService(prisma, {}, {}, {}, {} as any);

test("the provider's page says CLOSED or FULL for the asked day, with the list's proof, and nothing else", async () => {
  const closed = detailsDatabase({ closed: true });
  const page = await service(closed.prisma).findProvider(PROVIDER, { eventDate: "2027-02-18" });
  assert.equal(page.dayStatus, "CLOSED");
  assert.deepEqual(closed.asked, ["2027-02-18T00:00:00.000Z"]);

  const full = await service(detailsDatabase({ confirmed: 2, capacity: 2 }).prisma)
    .findProvider(PROVIDER, { eventDate: "2027-02-18" });
  assert.equal(full.dayStatus, "FULL");

  const open = await service(detailsDatabase({ confirmed: 1, capacity: 2 }).prisma)
    .findProvider(PROVIDER, { eventDate: "2027-02-18" });
  assert.equal(open.dayStatus, null, "a seat left is no proof he is free: nothing is said");

  const noDay = detailsDatabase({ closed: true });
  assert.equal((await service(noDay.prisma).findProvider(PROVIDER)).dayStatus, null);
  assert.deepEqual(noDay.asked, [], "no day asked, the calendar is not read");

  const past = detailsDatabase({ closed: true });
  assert.equal((await service(past.prisma).findProvider(PROVIDER, { eventDate: "2026-01-01" })).dayStatus, null);

  await assert.rejects(
    service(detailsDatabase({}).prisma).findProvider(PROVIDER, { eventDate: "tomorrow" }),
    BadRequestException,
  );
});

// ── Reviews ────────────────────────────────────────────────────────────────

test("the summary counts every published review by its stars and averages them", () => {
  assert.deepEqual(
    reviewSummary([
      { rating: 5, count: 6 },
      { rating: 4, count: 3 },
      { rating: 1, count: 1 },
    ]),
    { average: 4.3, count: 10, distribution: { 1: 1, 2: 0, 3: 0, 4: 3, 5: 6 } },
  );
  assert.deepEqual(reviewSummary([]), {
    average: null,
    count: 0,
    distribution: { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 },
  });
  assert.equal(reviewSummary([{ rating: 5, count: 2 }, { rating: 4, count: 1 }]).average, 4.67);
});

test("the reviews' page and limit are bounded by the form", () => {
  const errors = (query: object) =>
    validateSync(plainToInstance(ListProviderReviewsQueryDto, query)).length;
  assert.equal(errors({}), 0);
  assert.equal(errors({ page: "2", limit: "20" }), 0);
  assert.ok(errors({ page: "-1" }) > 0);
  assert.ok(errors({ limit: "1e3" }) > 0);
  assert.ok(errors({ page: "1".repeat(7) }) > 0);
});

function reviewsDatabase(total: number) {
  const reviews = Array.from({ length: total }, (_, index) => ({
    id: `r${String(index).padStart(3, "0")}`,
    userId: `u${index}`,
    providerId: PROVIDER,
    rating: index % 2 === 0 ? 5 : 4,
    comment: null,
    status: "PUBLISHED",
    replyBody: null,
    repliedAt: null,
    replyStatus: null,
    createdAt: new Date(NOW.getTime() - index * 60_000),
    updatedAt: NOW,
  }));
  const reads: any[] = [];
  const client: any = {
    $transaction: async (work: (tx: unknown) => unknown) => work(client),
    providerReview: {
      findMany: async (args: any) => {
        reads.push(args);
        return reviews.slice(args.skip, args.skip + args.take);
      },
      groupBy: async () => [
        { rating: 5, _count: { _all: reviews.filter((r) => r.rating === 5).length } },
        { rating: 4, _count: { _all: reviews.filter((r) => r.rating === 4).length } },
      ],
    },
  };
  const relations: any = {
    attachReviewUsers: async (_tx: unknown, rows: any[]) =>
      rows.map((row) => ({ ...row, user: { id: row.userId, name: "سعيد علي", appName: null, role: "USER", reviewFirstNameOnly: true } })),
  };
  return { client, relations, reads };
}

test("reviews come a page at a time, newest first, with the summary of them all", async () => {
  const { client, relations, reads } = reviewsDatabase(23);
  const first = await readProviderReviewPage(client, relations, PROVIDER, { page: "1", limit: "10" });
  assert.equal(first.items.length, 10);
  assert.equal(first.total, 23);
  assert.equal(first.totalPages, 3);
  assert.deepEqual(first.summary.distribution, { 1: 0, 2: 0, 3: 0, 4: 11, 5: 12 });
  assert.deepEqual(reads[0].orderBy, [{ createdAt: "desc" }, { id: "asc" }]);
  assert.equal(reads[0].where.status, "PUBLISHED");
  const last = await readProviderReviewPage(client, relations, PROVIDER, { page: "3", limit: "10" });
  assert.equal(last.items.length, 3);
  const capped = await readProviderReviewPage(client, relations, PROVIDER, { limit: "500" });
  assert.equal(capped.limit, REVIEWS_PAGE_MAX);
  const defaulted = await readProviderReviewPage(client, relations, PROVIDER, { page: "1" });
  assert.equal(defaulted.limit, 10);
});
