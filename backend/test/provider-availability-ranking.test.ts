import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { Prisma } from "@prisma/client";
import { listProvidersUnavailableOn } from "../src/modules/marketplace/infrastructure/marketplace-booking.repository";
import { searchActiveProviders } from "../src/modules/marketplace/infrastructure/marketplace-core.repository";
import {
  providerDayUnavailable,
  requestedBookableDay,
} from "../src/marketplace/provider-day-availability";
import { MarketplaceQuery } from "../src/marketplace/marketplace.presenter";
import {
  NEWCOMER_DAYS,
  profileCompleteness,
  rankProviders,
  smoothedRating,
  type RankSignals,
} from "../src/marketplace/provider-ranking";

// RA-BE-150 and RA-BE-154 (Q-36): «free that day» is one reading, over every
// confirmed booking; RA-BE-151 (Q-36): the list order buries no new provider.

const DAY = new Date("2027-02-18T00:00:00.000Z");

function fakeTx(options: { closed?: string[]; confirmed?: Record<string, number>; capacity?: Record<string, number> }) {
  const closed = new Set(options.closed ?? []);
  const confirmed = options.confirmed ?? {};
  const capacity = options.capacity ?? {};
  return {
    providerBlockedDate: {
      findUnique: async ({ where }: any) => (closed.has(where.providerId_date.providerId) ? { id: "x" } : null),
      findMany: async ({ where }: any) =>
        where.providerId.in.filter((id: string) => closed.has(id)).map((providerId: string) => ({ providerId })),
    },
    booking: {
      count: async ({ where }: any) => confirmed[where.providerId] ?? 0,
      groupBy: async ({ where }: any) =>
        where.providerId.in
          .filter((id: string) => (confirmed[id] ?? 0) > 0)
          .map((providerId: string) => ({ providerId, _count: { _all: confirmed[providerId] } })),
    },
    provider: {
      findUnique: async ({ where }: any) => ({ dailyBookingCapacity: capacity[where.id] ?? 1 }),
      findMany: async ({ where }: any) =>
        where.id.in.map((id: string) => ({ id, dailyBookingCapacity: capacity[id] ?? 1 })),
    },
  } as any;
}

test("a day he closed, or filled with his daily number, is unavailable; one seat left is not", async () => {
  const tx = fakeTx({ closed: ["closed"], confirmed: { full: 2, room: 2 }, capacity: { full: 2, room: 3 } });
  assert.equal(await providerDayUnavailable(tx, "closed", DAY), "CLOSED");
  assert.equal(await providerDayUnavailable(tx, "full", DAY), "FULL");
  assert.equal(await providerDayUnavailable(tx, "room", DAY), null);
  assert.equal(await providerDayUnavailable(tx, "nobody", DAY), null, "one seat a day by default and none taken: free");
  // RA-BE-154: every confirmed booking is a seat taken, whoever asked for it.
  assert.equal(await providerDayUnavailable(fakeTx({ confirmed: { p: 3 }, capacity: { p: 3 } }), "p", DAY), "FULL");
  assert.equal(await providerDayUnavailable(fakeTx({ confirmed: { p: 3 }, capacity: { p: 4 } }), "p", DAY), null);
});

test("the list asks the same two questions of a page of providers at once", async () => {
  const tx = fakeTx({ closed: ["closed"], confirmed: { full: 2, room: 2, one: 1 }, capacity: { full: 2, room: 3 } });
  const unavailable = await listProvidersUnavailableOn(tx, ["closed", "full", "room", "one", "free"], DAY);
  assert.deepEqual([...unavailable].sort(), ["closed", "full", "one"]);
  assert.equal((await listProvidersUnavailableOn(tx, [], DAY)).size, 0);
});

test("only a day that can still be booked asks anything of the calendar", () => {
  const now = new Date("2026-11-24T10:00:00.000Z");
  assert.equal(requestedBookableDay(null, now), null);
  assert.equal(requestedBookableDay(new Date("2026-11-20T00:00:00.000Z"), now), null);
  assert.equal(requestedBookableDay(new Date("2027-02-18T09:30:00.000Z"), now)?.toISOString(), DAY.toISOString());
});

test("the list's day is read from eventDate; a malformed one is a 400, a past one asks nothing", () => {
  const now = new Date("2026-11-24T10:00:00.000Z");
  assert.equal(MarketplaceQuery.providerSearch({}, now).availabilityDay, null);
  assert.equal(
    MarketplaceQuery.providerSearch({ eventDate: "2027-02-18" }, now).availabilityDay?.toISOString(),
    DAY.toISOString(),
  );
  assert.equal(MarketplaceQuery.providerSearch({ eventDate: "2026-01-01" }, now).availabilityDay, null);
  assert.throws(() => MarketplaceQuery.providerSearch({ eventDate: "soon" }, now), /eventDate/);
});

// ── RA-BE-151: the order ───────────────────────────────────────────────────

const NOW = new Date("2026-11-24T10:00:00.000Z");
const daysAgo = (days: number) => new Date(NOW.getTime() - days * 86_400_000);
const row = (id: string, over: Partial<RankSignals> = {}): RankSignals => ({
  id,
  claimed: true,
  verified: true,
  featuredNow: false,
  createdAt: daysAgo(400),
  ratingAverage: 0,
  ratingCount: 0,
  profile: 1,
  response: null,
  ...over,
});
const order = (rows: RankSignals[]) => rankProviders(rows, NOW).map((r) => r.id);

test("one 5-star review no longer beats 63 reviews averaging 4.8", () => {
  assert.ok(smoothedRating(4.8, 63) > smoothedRating(5, 1));
  assert.deepEqual(
    order([
      row("one-review", { ratingAverage: 5, ratingCount: 1 }),
      row("sixty-three", { ratingAverage: 4.8, ratingCount: 63 }),
    ]),
    ["sixty-three", "one-review"],
  );
});

test("a new provider with a full profile is not buried under an old one with no reviews, and the lift ends", () => {
  assert.deepEqual(
    order([row("old", { createdAt: daysAgo(400) }), row("new", { createdAt: daysAgo(3) })]),
    ["new", "old"],
  );
  assert.deepEqual(
    order([row("old", { createdAt: daysAgo(400) }), row("aged", { createdAt: daysAgo(NEWCOMER_DAYS + 1) })]),
    ["aged", "old"],
    "after the lift only the newer-first tie-break is left",
  );
});

test("a fuller profile and a faster answer rank higher, all else equal", () => {
  const bare = profileCompleteness({ logoUrl: null, coverUrl: null, description: null, address: null, whatsapp: null, socialLinks: null });
  const full = profileCompleteness({ logoUrl: "l", coverUrl: "c", description: "d", address: "a", whatsapp: null, socialLinks: { tiktok: "x" } });
  assert.equal(bare, 0);
  assert.equal(full, 1);
  assert.deepEqual(order([row("bare", { profile: bare }), row("full", { profile: full })]), ["full", "bare"]);
  const reply = (hours: number, percent: number) => ({ sampleSize: 10, answeredPercent: percent, typicalResponseHours: hours });
  assert.deepEqual(
    order([row("slow", { response: reply(30, 60) }), row("fast", { response: reply(1, 95) })]),
    ["fast", "slow"],
  );
});

test("featured first, then claimed listings, then unclaimed ones, however well an unclaimed one scores", () => {
  assert.deepEqual(
    order([
      row("unclaimed", { claimed: false, ratingAverage: 5, ratingCount: 200 }),
      row("plain", { ratingAverage: 3, ratingCount: 4 }),
      row("featured", { featuredNow: true, ratingAverage: 2, ratingCount: 4 }),
    ]),
    ["featured", "plain", "unclaimed"],
  );
});

// Q-73 (أ), D127: a provider whose documents were never checked (no
// verifiedAt) comes after the checked ones; inside each band the order is
// today's: featured, claimed, unclaimed, then the score.
test("Q-73: unverified providers come after verified ones, each band in today's order", () => {
  assert.deepEqual(
    order([
      row("unverified-featured", { verified: false, featuredNow: true, ratingAverage: 5, ratingCount: 200 }),
      row("unverified-claimed", { verified: false, ratingAverage: 5, ratingCount: 100 }),
      row("verified-unclaimed", { claimed: false }),
      row("verified-plain", { ratingAverage: 3, ratingCount: 4 }),
      row("verified-featured", { featuredNow: true, ratingAverage: 2, ratingCount: 4 }),
      row("unverified-unclaimed", { verified: false, claimed: false }),
    ]),
    [
      "verified-featured",
      "verified-plain",
      "verified-unclaimed",
      "unverified-featured",
      "unverified-claimed",
      "unverified-unclaimed",
    ],
  );
});

test("Q-73: the list reads verifiedAt, so an unchecked provider ranks below a checked one", async () => {
  const candidates = [
    { id: "unchecked", userId: "u1", verifiedAt: null, ratingAverage: new Prisma.Decimal("5"), ratingCount: 99, createdAt: daysAgo(400), logoUrl: "l", coverUrl: "c", description: "d", address: "a", whatsapp: "w", socialLinks: null, featuredPeriods: [] },
    { id: "checked", userId: "u2", verifiedAt: daysAgo(10), ratingAverage: new Prisma.Decimal("3"), ratingCount: 2, createdAt: daysAgo(400), logoUrl: null, coverUrl: null, description: null, address: null, whatsapp: null, socialLinks: null, featuredPeriods: [] },
  ];
  let selected: any = null;
  const client: any = {
    $queryRaw: async () => [],
    provider: {
      findMany: async (args: any) => {
        if (args.where.id) {
          return args.where.id.in.map((id: string) => ({ id, featuredPeriods: [] }));
        }
        selected = args.select;
        return candidates;
      },
    },
  };
  const page = await searchActiveProviders(client, { AND: [] } as any, { page: 1, limit: 10, skip: 0 }, NOW);
  assert.equal(selected.verifiedAt, true);
  assert.deepEqual(page.rows.map((r: any) => r.id), ["checked", "unchecked"]);
});

test("equal scores are ordered by age and then id, so a page never repeats or skips", () => {
  const same = daysAgo(400);
  assert.deepEqual(order([row("b", { createdAt: same }), row("a", { createdAt: same }), row("c", { createdAt: daysAgo(500) })]), ["a", "b", "c"]);
});

test("the list is cut after ranking: the page holds the ranked rows, only they are read whole", async () => {
  const candidates = [
    { id: "p1", userId: "u1", ratingAverage: new Prisma.Decimal("5"), ratingCount: 1, createdAt: daysAgo(400), logoUrl: "l", coverUrl: "c", description: "d", address: "a", whatsapp: "w", socialLinks: null, featuredPeriods: [] },
    { id: "p2", userId: "u2", ratingAverage: new Prisma.Decimal("4.8"), ratingCount: 63, createdAt: daysAgo(400), logoUrl: "l", coverUrl: "c", description: "d", address: "a", whatsapp: "w", socialLinks: null, featuredPeriods: [] },
    { id: "p3", userId: "u3", ratingAverage: new Prisma.Decimal("0"), ratingCount: 0, createdAt: daysAgo(400), logoUrl: "l", coverUrl: "c", description: "d", address: "a", whatsapp: "w", socialLinks: null, featuredPeriods: [{ startsAt: NOW, endsAt: NOW }] },
    { id: "p4", userId: null, ratingAverage: new Prisma.Decimal("5"), ratingCount: 99, createdAt: daysAgo(400), logoUrl: "l", coverUrl: "c", description: "d", address: "a", whatsapp: "w", socialLinks: null, featuredPeriods: [{ startsAt: NOW, endsAt: NOW }] },
  ];
  const wholeReads: string[][] = [];
  const client: any = {
    $queryRaw: async () => [],
    provider: {
      findMany: async (args: any) => {
        if (args.where.id) {
          wholeReads.push(args.where.id.in);
          // The database answers in no particular order.
          return [...args.where.id.in].reverse().map((id: string) => ({ id, featuredPeriods: candidates.find((c) => c.id === id)!.featuredPeriods }));
        }
        return candidates;
      },
    },
  };
  const page = async (skip: number, limit: number) =>
    (await searchActiveProviders(client, { AND: [] } as any, { page: 1, limit, skip }, NOW)).rows.map((r: any) => [r.id, r.featuredPeriods.length]);
  assert.deepEqual(await page(0, 2), [["p3", 1], ["p2", 0]]);
  assert.deepEqual(await page(2, 2), [["p1", 0], ["p4", 0]], "an unclaimed listing is last and never badged");
  assert.deepEqual(await page(4, 2), []);
  assert.deepEqual(wholeReads, [["p3", "p2"], ["p1", "p4"]]);
});
