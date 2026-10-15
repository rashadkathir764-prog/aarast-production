import assert from "node:assert/strict";
import { test } from "node:test";
import { Prisma } from "@prisma/client";
import {
  average,
  groupPrices,
  percent,
} from "../src/admin/admin-success-report";

// The back office's success indicators and price report (V1 checklist 4.21).

const row = (providerId: string, price: string, overrides: Record<string, string> = {}) => ({
  providerId,
  cityId: "sanaa",
  categoryId: "halls",
  currency: "YER",
  basePrice: new Prisma.Decimal(price),
  ...overrides,
});

test("a price group needs three different providers", () => {
  assert.deepEqual(
    groupPrices([row("p1", "100"), row("p1", "200"), row("p2", "300")]),
    [],
  );
});

test("a price group reports min, median and max", () => {
  assert.deepEqual(
    groupPrices([row("p1", "400"), row("p2", "100"), row("p3", "300"), row("p3", "200")]),
    [
      {
        cityId: "sanaa",
        categoryId: "halls",
        currency: "YER",
        providers: 3,
        services: 4,
        min: "100.00",
        median: "250.00",
        max: "400.00",
      },
    ],
  );
});

test("currencies and cities are never mixed", () => {
  const groups = groupPrices([
    row("p1", "100"),
    row("p2", "100"),
    row("p3", "100", { currency: "SAR" }),
    row("p4", "100", { cityId: "aden" }),
  ]);
  assert.deepEqual(groups, []);
});

test("rates read as whole percents and averages to one decimal", () => {
  assert.equal(percent(1, 3), 33);
  assert.equal(percent(0, 0), null);
  assert.equal(average(10, 4), 2.5);
  assert.equal(average(1, 0), null);
});
