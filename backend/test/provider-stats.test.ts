import assert from "node:assert/strict";
import { test } from "node:test";
import {
  offerAcceptanceRate,
  providerStatsWindowStart,
  toProviderStats,
} from "../src/provider-dashboard/provider-stats";

// The provider's own reach (V1 checklist 4.19).

test("the stats window is the last 30 calendar days including today", () => {
  const today = new Date("2026-10-15T00:00:00Z");
  assert.equal(providerStatsWindowStart(today).toISOString(), "2026-09-16T00:00:00.000Z");
});

test("the acceptance rate counts only offers customers decided on", () => {
  assert.equal(offerAcceptanceRate(0, 0), null);
  assert.equal(offerAcceptanceRate(1, 3), 33);
  assert.equal(offerAcceptanceRate(2, 3), 67);
  assert.equal(offerAcceptanceRate(4, 4), 100);
});

test("a provider without views reads zero, not null", () => {
  assert.deepEqual(toProviderStats(null, 2, 1, 2, 1, 0), {
    windowDays: 30,
    profileViews: 0,
    quoteRequests: 2,
    offersAccepted: 1,
    offersDecided: 2,
    acceptanceRate: 50,
    upcomingBookings: 1,
    completedBookings: 0,
  });
});
