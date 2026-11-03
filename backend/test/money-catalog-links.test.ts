import "reflect-metadata";

import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";
import { Prisma } from "@prisma/client";
import { moneyStarterDefaults } from "../src/catalogs/reference-catalog.defaults";
import { ReferenceCatalogService } from "../src/catalogs/reference-catalog.service";
import { CatalogAdminService } from "../src/modules/catalog/infrastructure/catalog-admin.service";
import { CatalogReadService } from "../src/modules/catalog/infrastructure/catalog-read.service";
import {
  budgetItemForProviderCategory,
  budgetItemForService,
  findLogicalBudgetCategory,
  normalizeBudgetCategoryName,
  OTHER_BUDGET_CATEGORY_NAME,
  type BudgetItemProviderLink,
  type MoneyCatalogLinks,
} from "../src/modules/finance/domain/cost-category-matching";
import { FinancePortService } from "../src/modules/finance/infrastructure/finance-port.service";
import {
  budgetItemSearchCategories,
  providerCategoryBudgetItem,
  type SearchableProviderCategory,
} from "../src/modules/finance/public/provider-category-budget-item";
import { buildMoneySummaryInTransaction } from "../src/money/money-summary.service";

// D73: a plan's money item is linked to provider categories explicitly, on
// its money catalog item (`metadata.providerCategorySlugs`), tied by exact
// normalized name. The explicit link comes first in both directions («ابحث»
// and an accepted offer's item); an item with no link keeps the words.

type Persona = "GROOM" | "BRIDE" | "NEUTRAL";

const migrationsRoot = join(__dirname, "..", "prisma", "migrations");

/** The production catalog with its slugs: the last `WITH desired` row per slug. */
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
          id: `id-${row[1]}`,
          slug: row[1],
          nameAr: row[2],
          showForGroom: row[3] === "true",
          showForBride: row[4] === "true",
        });
      }
    }
  }
  return [...bySlug.values()];
}

const categories = productionCategories();

/** The defaults as the catalog read port serves them. */
const defaultCatalog: BudgetItemProviderLink[] = moneyStarterDefaults.map((item) => ({
  nameAr: item.nameAr,
  showForGroom: item.showForGroom,
  showForBride: item.showForBride,
  providerCategorySlugs: (item.metadata?.providerCategorySlugs as string[] | undefined) ?? [],
}));

function item(id: string, name: string) {
  return { id, name, normalizedName: normalizeBudgetCategoryName(name) };
}

const other = item("other", OTHER_BUDGET_CATEGORY_NAME);

/** A new plan's wedding items (mahr aside, C1), then the «أخرى» acceptance adds. */
function planItems(persona: Persona) {
  return [
    ...moneyStarterDefaults
      .filter((entry) => entry.metadata?.persona === persona)
      .filter((entry) => !entry.key.endsWith("-mahr"))
      .map((entry) => item(entry.key, entry.nameAr)),
    other,
  ];
}

function link(
  nameAr: string,
  providerCategorySlugs: string[],
  audience: { showForGroom: boolean; showForBride: boolean } = {
    showForGroom: true,
    showForBride: false,
  },
): BudgetItemProviderLink {
  return { nameAr, providerCategorySlugs, ...audience };
}

const groomCatalog = (...items: BudgetItemProviderLink[]): MoneyCatalogLinks => ({
  planPersona: "GROOM",
  items,
});

test("the production catalog is read whole, with its slugs", () => {
  assert.equal(categories.length, 39);
});

test("the defaults' links name only production categories", () => {
  const slugs = new Set(categories.map((category) => category.slug));
  for (const entry of defaultCatalog) {
    for (const slug of entry.providerCategorySlugs) {
      assert.ok(slugs.has(slug), `${entry.nameAr}: ${slug}`);
    }
  }
});

for (const persona of ["GROOM", "BRIDE", "NEUTRAL"] as const) {
  test(`${persona}: a new environment's links file every category where the words did`, () => {
    const items = planItems(persona);
    const catalog = {
      planPersona: persona === "NEUTRAL" ? null : persona,
      items: defaultCatalog,
    };
    for (const category of categories) {
      assert.equal(
        budgetItemForProviderCategory(items, category.nameAr, {
          providerCategorySlug: category.slug,
          catalog,
        })?.id,
        budgetItemForProviderCategory(items, category.nameAr)?.id,
        `«${category.nameAr}» (${category.slug}) in a ${persona} plan`,
      );
    }
    assert.deepEqual(
      budgetItemSearchCategories(items, categories, persona, defaultCatalog),
      budgetItemSearchCategories(items, categories, persona),
    );
  });
}

test("an item with an explicit link holds exactly its categories, both ways", () => {
  const items = [item("hall", "قاعة أو مخدرة الرجال"), item("photo", "التصوير والفيديو"), other];
  const providers: SearchableProviderCategory[] = [
    { id: "c-photo", slug: "photography", nameAr: "تصوير", showForGroom: true, showForBride: true },
    { id: "c-edit", slug: "video-editing", nameAr: "مونتاج", showForGroom: true, showForBride: true },
    { id: "c-hall", slug: "wedding-halls", nameAr: "قاعات", showForGroom: true, showForBride: true },
  ];
  const catalog = [link("التصوير والفيديو", ["video-editing"])];

  // «ابحث»: the linked item searches its one category, not the words' one.
  const byItem = budgetItemSearchCategories(items, providers, "GROOM", catalog);
  assert.deepEqual(byItem.get("photo"), ["c-edit"]);
  // The hall has no link: its words still find it.
  assert.deepEqual(byItem.get("hall"), ["c-hall"]);
  // «تصوير» names the linked item's words, but its link does not list it.
  assert.deepEqual(byItem.get("other"), ["c-photo"]);

  // An accepted offer files under the same items.
  const explicit = (slug: string) => ({
    providerCategorySlug: slug,
    catalog: groomCatalog(...catalog),
  });
  assert.equal(findLogicalBudgetCategory(items, "مونتاج", explicit("video-editing"))?.id, "photo");
  assert.equal(findLogicalBudgetCategory(items, "تصوير", explicit("photography")), null);
  assert.equal(budgetItemForProviderCategory(items, "تصوير", explicit("photography"))?.id, "other");
  assert.equal(findLogicalBudgetCategory(items, "قاعات", explicit("wedding-halls"))?.id, "hall");
});

test("an item with no link, or a link the owner left empty, keeps the words", () => {
  const items = [item("photo", "التصوير والفيديو"), item("mine", "تصوير خطوبتي"), other];
  const providers: SearchableProviderCategory[] = [
    { id: "c-photo", slug: "photography", nameAr: "تصوير", showForGroom: true, showForBride: true },
  ];
  const before = budgetItemSearchCategories(items, providers, "GROOM");
  assert.deepEqual(
    budgetItemSearchCategories(items, providers, "GROOM", [link("التصوير والفيديو", [])]),
    before,
  );
  assert.deepEqual(before.get("photo"), ["c-photo"]);
  // Once the catalog item is linked elsewhere, the user's own item takes the words.
  const linked = budgetItemSearchCategories(items, providers, "GROOM", [
    link("التصوير والفيديو", ["video-editing"]),
  ]);
  assert.deepEqual(linked.get("photo"), []);
  assert.deepEqual(linked.get("mine"), ["c-photo"]);
});

test("a new admin item no word names links once the owner sets its slugs", () => {
  const cleaning: SearchableProviderCategory = {
    id: "c-clean",
    slug: "cleaning",
    nameAr: "خدمات التنظيف",
    showForGroom: true,
    showForBride: true,
  };
  const items = [item("hall", "قاعة أو مخدرة الرجال"), item("after", "ترتيب البيت بعد العرس"), other];

  // Today: no word names it, so no «ابحث» and its offers land in «أخرى».
  const unlinked = [link("ترتيب البيت بعد العرس", [])];
  assert.deepEqual(budgetItemSearchCategories(items, [cleaning], "GROOM", unlinked).get("after"), []);
  assert.equal(
    budgetItemForProviderCategory(items, cleaning.nameAr, {
      providerCategorySlug: cleaning.slug,
      catalog: groomCatalog(...unlinked),
    })?.id,
    "other",
  );
  assert.equal(providerCategoryBudgetItem(["ترتيب البيت بعد العرس"], cleaning.nameAr), null);

  // The owner links it in «الكتالوجات».
  const linked = [link("ترتيب البيت بعد العرس", ["cleaning"])];
  assert.deepEqual(budgetItemSearchCategories(items, [cleaning], "GROOM", linked).get("after"), ["c-clean"]);
  assert.equal(
    budgetItemForProviderCategory(items, cleaning.nameAr, {
      providerCategorySlug: cleaning.slug,
      catalog: groomCatalog(...linked),
    })?.id,
    "after",
  );
  // The admin's «أخرى» hint says so too.
  assert.equal(
    providerCategoryBudgetItem(["ترتيب البيت بعد العرس"], cleaning.nameAr, {
      providerCategorySlug: cleaning.slug,
      catalog: groomCatalog(...linked),
    }),
    "ترتيب البيت بعد العرس",
  );
});

test("a plan reads the links of the catalog items its persona was offered", () => {
  const items = [item("audio", "الصوت والزفة"), item("artist", "الفنانة والزفة"), other];
  const singer = { slug: "female-singer", name: "فنانات" };
  const catalog = [
    link("الصوت والزفة", ["sound-lighting"], { showForGroom: false, showForBride: true }),
    link("الفنانة والزفة", ["female-singer"], { showForGroom: false, showForBride: true }),
    // The same name offered to a plan without a persona, linked otherwise.
    link("الصوت والزفة", ["sound-lighting", "female-singer"], { showForGroom: false, showForBride: false }),
  ];
  const landing = (planPersona: string | null) =>
    findLogicalBudgetCategory(items, singer.name, {
      providerCategorySlug: singer.slug,
      catalog: { planPersona, items: catalog },
    })?.id;
  assert.equal(landing("BRIDE"), "artist");
  assert.equal(landing(null), "audio");
  assert.equal(landing("HELPER"), "audio");
  // A groom's plan was offered none of them: the words file it.
  assert.equal(landing("GROOM"), findLogicalBudgetCategory(items, singer.name)?.id);
});

test("the catalog serves each published money item with its slugs and audience", async () => {
  const revision = (
    no: number,
    nameAr: string,
    metadata: Record<string, unknown> | null,
    extra: Partial<{ isActive: boolean; sortOrder: number; showForGroom: boolean; showForBride: boolean }> = {},
  ) => ({
    revision: no,
    nameAr,
    isActive: true,
    sortOrder: 0,
    showForGroom: true,
    showForBride: false,
    metadata,
    ...extra,
  });
  let query: unknown;
  const client = {
    referenceCatalog: {
      findUnique: async (args: unknown) => {
        query = args;
        return {
          isActive: true,
          items: [
            {
              publishedRevision: 2,
              revisions: [
                revision(1, "قديم", { persona: "GROOM", providerCategorySlugs: ["old"] }),
                revision(2, "التصوير", { persona: "GROOM", providerCategorySlugs: ["photography", " photography ", "photo-session"] }, { sortOrder: 20 }),
              ],
            },
            { publishedRevision: 1, revisions: [revision(1, "القاعة", { persona: "GROOM" }, { sortOrder: 10 })] },
            { publishedRevision: 1, revisions: [revision(1, "معطّل", { persona: "BRIDE" }, { isActive: false })] },
            { publishedRevision: 1, revisions: [revision(1, "بند جديد", { providerCategorySlugs: "cleaning" }, { sortOrder: 30, showForBride: true })] },
          ],
        };
      },
    },
  };
  assert.deepEqual(await new CatalogReadService().listMoneyCatalogItems(client as never), [
    { nameAr: "القاعة", persona: "GROOM", showForGroom: true, showForBride: false, providerCategorySlugs: [] },
    { nameAr: "التصوير", persona: "GROOM", showForGroom: true, showForBride: false, providerCategorySlugs: ["photography", "photo-session"] },
    { nameAr: "بند جديد", persona: null, showForGroom: true, showForBride: true, providerCategorySlugs: [] },
  ]);
  assert.deepEqual(query, {
    where: { key: "money.starter.categories" },
    include: { items: { where: { publishedRevision: { gt: 0 } }, include: { revisions: true } } },
  });
  // The back office's starter items are the same rows with a persona.
  assert.deepEqual(
    (await new CatalogAdminService().listStarterBudgetItems(client as never)).map((entry) => entry.nameAr),
    ["القاعة", "التصوير"],
  );
});

test("a starter task waits on the item its service's offers file under (R4, D73)", () => {
  const henna = { nameAr: "النقش والحناء", slug: "henna" };
  const items = [item("naqsh", "النقش"), item("night", "ليلة الحناء"), other];

  assert.equal(budgetItemForService(items, "النقش", [henna], groomCatalog())?.id, "naqsh");
  // The owner links the category elsewhere: the task follows its offers.
  assert.equal(
    budgetItemForService(items, "النقش", [henna], groomCatalog(link("ليلة الحناء", ["henna"])))?.id,
    "night",
  );
  // No directory category names it: the plan's items by their words.
  assert.equal(budgetItemForService(items, "النقش", [], groomCatalog())?.id, "naqsh");
  // A task never waits on «أخرى».
  assert.equal(budgetItemForService([other], "النقش", [henna], groomCatalog()), null);
});

test("the catalog refuses a slug no provider category has", async () => {
  const service = new ReferenceCatalogService({} as any, {} as any) as any;
  const tx = {
    providerCategory: {
      findMany: async () => [{ slug: "photography" }],
    },
  };
  await service.assertKnownProviderCategorySlugs(tx, { providerCategorySlugs: ["photography"] });
  await service.assertKnownProviderCategorySlugs(tx, { persona: "GROOM" });
  await service.assertKnownProviderCategorySlugs(tx, undefined);
  await assert.rejects(
    service.assertKnownProviderCategorySlugs(tx, { providerCategorySlugs: ["photography", "typo"] }),
    /Unknown provider category: typo/,
  );
});

test("the catalog refuses a link that is not a list of slugs", () => {
  const service = new ReferenceCatalogService({} as any, {} as any) as any;
  const accepted = service.metadataInput({ persona: "GROOM", providerCategorySlugs: ["photography"] });
  assert.deepEqual(accepted, { persona: "GROOM", providerCategorySlugs: ["photography"] });
  assert.deepEqual(service.metadataInput({ persona: "GROOM" }), { persona: "GROOM" });
  for (const bad of ["photography", [""], [7], Array.from({ length: 51 }, (_, i) => `s${i}`)]) {
    assert.throws(
      () => service.metadataInput({ providerCategorySlugs: bad }),
      /providerCategorySlugs must be a list of slugs/,
    );
  }
});

test("acceptance files an offer under the item linked to its category", async () => {
  const created: unknown[] = [];
  const tx = {
    budgetCategory: {
      findMany: async () => [item("hall", "قاعة أو مخدرة الرجال"), item("after", "ترتيب البيت بعد العرس")],
      upsert: async () => assert.fail("a linked offer never reaches «أخرى»"),
    },
    weddingCost: {
      create: async (args: { data: unknown }) => {
        created.push(args.data);
        return { id: "cost-1" };
      },
    },
  } as unknown as Prisma.TransactionClient;
  const catalog = Object.assign(new CatalogReadService(), {
    listMoneyCatalogItems: async () => [
      { ...link("ترتيب البيت بعد العرس", ["cleaning"]), persona: "GROOM" as const, providerCategorySlugs: ["cleaning"] },
    ],
  });
  await new FinancePortService(catalog).createCostFromAcceptedOffer(tx, {
    weddingPlanId: "plan-1",
    providerId: "provider-1",
    quoteOfferId: "offer-1",
    title: "تنظيف",
    amount: new Prisma.Decimal("100"),
    providerCategoryName: "خدمات التنظيف",
    providerCategorySlug: "cleaning",
    planPersona: "GROOM",
  });
  assert.equal((created[0] as { budgetCategoryId: string }).budgetCategoryId, "after");
});

test("the money summary searches a linked item by its link", async () => {
  const row = (id: string, name: string) => ({
    ...item(id, name),
    weddingPlanId: "plan-1",
    allocatedAmount: null,
  });
  const all = [row("hall", "قاعة أو مخدرة الرجال"), row("after", "ترتيب البيت بعد العرس")];
  const tx = {
    budgetCategory: { findMany: async () => all },
    weddingCost: { findMany: async () => [] },
    costPayment: { findMany: async () => [] },
    paymentSchedule: { findMany: async () => [] },
  };
  const plans: any = {
    getPlan: async () => ({ id: "plan-1", estimatedBudget: null, currency: "YER", persona: "GROOM" }),
  };
  const catalog: any = {
    listActiveCategories: async () => [
      { id: "c-clean", slug: "cleaning", nameAr: "خدمات التنظيف", showForGroom: true, showForBride: true },
      { id: "c-hall", slug: "wedding-halls", nameAr: "قاعات", showForGroom: true, showForBride: true },
    ],
    listMoneyCatalogItems: async () => [
      { ...link("ترتيب البيت بعد العرس", ["cleaning"]), persona: "GROOM" },
    ],
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
    { costIds: [], categoryIds: ["hall", "after"] },
  );
  assert.deepEqual(
    summary.categories.map((entry) => [entry.categoryId, entry.providerCategoryIds]),
    [
      ["hall", ["c-hall"]],
      ["after", ["c-clean"]],
    ],
  );
});
