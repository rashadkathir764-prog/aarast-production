import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";
import { moneyStarterDefaults } from "../src/catalogs/reference-catalog.defaults";
import {
  budgetItemForProviderCategory,
  normalizeBudgetCategoryName,
  OTHER_BUDGET_CATEGORY_NAME,
} from "../src/modules/finance/domain/cost-category-matching";
import {
  budgetItemSearchCategories,
  providerCategoryShownTo,
  type SearchableProviderCategory,
} from "../src/modules/finance/public/provider-category-budget-item";
import { MarketplaceQuery } from "../src/marketplace/marketplace.presenter";
import { buildMoneySummaryInTransaction } from "../src/money/money-summary.service";

// G40: «ابحث» on a budget item searches the directory categories whose
// accepted offers land in that item, by acceptance's own rule. Every
// production category (the migrations' final catalog) a plan's persona sees
// is reachable from exactly the item it lands in, and from no other.

type Persona = "GROOM" | "BRIDE" | "NEUTRAL";

const migrationsRoot = join(__dirname, "..", "prisma", "migrations");

/** The production catalog: the last `WITH desired` rows per slug. */
function productionCategories(): SearchableProviderCategory[] {
  const bySlug = new Map<string, SearchableProviderCategory>();
  const dirs = readdirSync(migrationsRoot, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort();
  for (const dir of dirs) {
    const sql = readFileSync(join(migrationsRoot, dir, "migration.sql"), "utf8");
    for (const statement of sql.split(";")) {
      if (!/WITH desired/u.test(statement)) continue;
      if (!statement.includes('"ProviderCategory"')) continue;
      for (const row of statement.matchAll(
        /\('([a-z-]+)',\s*'([^']+)',\s*'[^']*',\s*'[^']*',\s*(true|false),\s*(true|false),\s*\d+\)/gu,
      )) {
        bySlug.set(row[1], {
          id: row[1],
          nameAr: row[2],
          showForGroom: row[3] === "true",
          showForBride: row[4] === "true",
        });
      }
    }
  }
  return [...bySlug.values()];
}

/** A new plan's wedding items, in their order, then the «أخرى» acceptance adds. */
function planItems(persona: Persona) {
  const items = moneyStarterDefaults
    .filter((item) => item.metadata?.persona === persona)
    // The mahr is its own item, outside the wedding money (C1).
    .filter((item) => !item.key.endsWith("-mahr"))
    .map((item) => ({
      id: item.key,
      name: item.nameAr,
      normalizedName: normalizeBudgetCategoryName(item.nameAr),
    }));
  return [
    ...items,
    {
      id: "other",
      name: OTHER_BUDGET_CATEGORY_NAME,
      normalizedName: normalizeBudgetCategoryName(OTHER_BUDGET_CATEGORY_NAME),
    },
  ];
}

const categories = productionCategories();

test("the production catalog is read whole", () => {
  assert.equal(categories.length, 39);
  assert.ok(categories.some((category) => category.id === "mabra"));
});

for (const persona of ["GROOM", "BRIDE", "NEUTRAL"] as const) {
  test(`${persona}: every category it sees is searched from exactly its landing item`, () => {
    const items = planItems(persona);
    const byItem = budgetItemSearchCategories(items, categories, persona);
    assert.deepEqual([...byItem.keys()], items.map((item) => item.id));
    for (const category of categories) {
      const holders = [...byItem.entries()]
        .filter(([, ids]) => ids.includes(category.id))
        .map(([id]) => id);
      if (!providerCategoryShownTo(category, persona)) {
        assert.deepEqual(holders, [], `${category.id} is hidden from ${persona}`);
        continue;
      }
      const landing = budgetItemForProviderCategory(items, category.nameAr);
      assert.ok(landing, `${category.id} lands somewhere in a ${persona} plan`);
      assert.deepEqual(
        holders,
        [landing.id],
        `«${category.nameAr}» (${category.id}) in a ${persona} plan`,
      );
    }
  });
}

test("the walk's cases: the groom's artists, the bride's incense and henna", () => {
  const groom = budgetItemSearchCategories(
    planItems("GROOM"),
    categories,
    "GROOM",
  );
  assert.deepEqual(groom.get("groom-artist"), [
    "male-singer",
    "male-vocalist",
    "mizmar-folk-band",
    "mabra",
  ]);
  const demoBride = [
    "الصالة",
    "التصوير",
    "البخور",
    "المزينة والنقاشة",
    "فستان الزفة",
  ].map((name) => ({
    id: name,
    name,
    normalizedName: normalizeBudgetCategoryName(name),
  }));
  const bride = budgetItemSearchCategories(demoBride, categories, "BRIDE");
  assert.deepEqual(bride.get("البخور"), ["perfumes"]);
  assert.deepEqual(bride.get("المزينة والنقاشة"), ["henna"]);
  assert.ok(bride.get("فستان الزفة")?.includes("dresses"));
  // An item no category lands in has no search: no «ابحث».
  const lone = [{ id: "x", name: "الصبحية", normalizedName: "الصبحية" }];
  assert.deepEqual(
    budgetItemSearchCategories(lone, categories, "BRIDE").get("x"),
    [],
  );
});

test("the money summary carries each item's categories, read over the whole plan", async () => {
  const item = (id: string, name: string) => ({
    id,
    weddingPlanId: "plan-1",
    name,
    normalizedName: normalizeBudgetCategoryName(name),
    allocatedAmount: null,
  });
  const all = [
    item("hall", "قاعة أو مخدرة الرجال"),
    item("artist", "الفنان والفرقة"),
    item("suit", "بدلة العريس"),
  ];
  const tx = {
    budgetCategory: {
      // The contributor's rows are only the artist; the search reads all.
      findMany: async ({ select }: { select?: unknown }) =>
        select ? all : [all[1]],
    },
    weddingCost: { findMany: async () => [] },
    costPayment: { findMany: async () => [] },
    paymentSchedule: { findMany: async () => [] },
  };
  const plans: any = {
    getPlan: async () => ({
      id: "plan-1",
      estimatedBudget: null,
      currency: "YER",
      persona: "GROOM",
    }),
  };
  const catalog: any = {
    listActiveCategories: async () =>
      categories.map((category) => ({ ...category, isActive: true })),
  };
  const summary = await buildMoneySummaryInTransaction(
    tx as any,
    { canViewMoney: () => true, canManageMoney: () => true } as any,
    plans,
    catalog,
    {
      plan: { id: "plan-1", ownerUserId: "owner-1" },
      isOwner: false,
      sharedMember: { userId: "helper-1" },
    } as any,
    { costIds: [], categoryIds: ["artist"] },
  );
  assert.deepEqual(
    summary.categories.map((row) => [row.categoryId, row.providerCategoryIds]),
    [["artist", ["male-singer", "male-vocalist", "mizmar-folk-band", "mabra"]]],
  );
});

test("the directory takes several categories, or one, never both", () => {
  const a = "11111111-1111-4111-8111-111111111111";
  const b = "22222222-2222-4222-8222-222222222222";
  const where = (query: Record<string, string>) =>
    MarketplaceQuery.providerSearch(query, new Date()).where.AND;
  const many = where({ categoryIds: `${a}, ${b},${a}` });
  assert.ok(
    many.some(
      (condition) =>
        JSON.stringify(condition) ===
        JSON.stringify({
          OR: [
            { primaryCategoryId: { in: [a, b] } },
            { services: { some: { categoryId: { in: [a, b] }, isActive: true } } },
          ],
        }),
    ),
  );
  const one = where({ categoryId: a });
  assert.ok(
    one.some((condition) => JSON.stringify(condition).includes(`"in":["${a}"]`)),
  );
  assert.throws(() => where({ categoryId: a, categoryIds: b }), /not both/);
  assert.throws(() => where({ categoryIds: "nope" }), /categoryIds/);
  assert.throws(
    () =>
      where({
        categoryIds: Array.from(
          { length: 51 },
          (_, i) => `00000000-0000-4000-8000-${String(i).padStart(12, "0")}`,
        ).join(","),
      }),
    /at most 50/,
  );
});
