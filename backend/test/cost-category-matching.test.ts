import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";
import { moneyStarterDefaults } from "../src/catalogs/reference-catalog.defaults";
import { MarketplaceRelationsService } from "../src/marketplace/marketplace-relations";
import {
  findLogicalBudgetCategory,
  normalizeBudgetCategoryName,
} from "../src/modules/finance/domain/cost-category-matching";

// G38: an accepted offer's cost lands in the plan item of its provider
// category. Every category the migrations ever wrote (its slug and each name
// it had) is read here and pinned to the starter item it fills for the
// groom's, the bride's and the shared plan; null is «أخرى», written down on
// purpose. A new category in a migration fails this test until it is placed.

type Persona = "GROOM" | "BRIDE" | "NEUTRAL";
type Expected = Record<Persona, string | null>;

const artist: Expected = {
  GROOM: "groom-artist",
  BRIDE: "bride-artist",
  NEUTRAL: "neutral-audio",
};
const hosting: Expected = {
  GROOM: "groom-food",
  BRIDE: "bride-food",
  NEUTRAL: "neutral-food",
};
const photo: Expected = {
  GROOM: "groom-photo",
  BRIDE: "bride-photo",
  NEUTRAL: "neutral-photo",
};
const decor: Expected = {
  GROOM: null,
  BRIDE: "bride-decor",
  NEUTRAL: "neutral-decor",
};
const gifts: Expected = {
  GROOM: "groom-gifts",
  BRIDE: "bride-invites",
  NEUTRAL: "neutral-invites",
};
const none: Expected = { GROOM: null, BRIDE: null, NEUTRAL: null };

const EXPECTED_BY_SLUG: Readonly<Record<string, Expected>> = {
  "wedding-halls": {
    GROOM: "groom-venue",
    BRIDE: "bride-venue",
    NEUTRAL: "neutral-venue",
  },
  photography: photo,
  "photo-session": photo,
  catering: hosting,
  "soft-drinks": hosting,
  water: hosting,
  refrigerators: hosting,
  "stage-decor": decor,
  decoration: decor,
  flowers: decor,
  dresses: {
    GROOM: "groom-clothes",
    BRIDE: "bride-dress",
    NEUTRAL: "neutral-look",
  },
  clothing: {
    GROOM: "groom-clothes",
    BRIDE: "bride-clothes",
    NEUTRAL: "neutral-look",
  },
  "sound-lighting": {
    GROOM: "groom-audio",
    BRIDE: "bride-audio",
    NEUTRAL: "neutral-audio",
  },
  lighting: {
    GROOM: "groom-audio",
    BRIDE: "bride-audio",
    NEUTRAL: "neutral-audio",
  },
  "wedding-giveaways": gifts,
  "promotional-bags": gifts,
  invitations: {
    GROOM: "groom-invites",
    BRIDE: "bride-invites",
    NEUTRAL: "neutral-invites",
  },
  "wedding-car": {
    GROOM: "groom-zaffa",
    BRIDE: "bride-transport",
    NEUTRAL: "neutral-transport",
  },
  "wedding-procession": {
    GROOM: "groom-zaffa",
    BRIDE: "bride-audio",
    NEUTRAL: "neutral-audio",
  },
  "wedding-coordination": { GROOM: null, BRIDE: null, NEUTRAL: "neutral-decor" },
  makeup: { GROOM: "groom-grooming", BRIDE: "bride-makeup", NEUTRAL: null },
  "hair-styling": {
    GROOM: "groom-grooming",
    BRIDE: "bride-makeup",
    NEUTRAL: null,
  },
  barber: { GROOM: "groom-grooming", BRIDE: "bride-care", NEUTRAL: null },
  henna: { GROOM: null, BRIDE: "bride-naqsh", NEUTRAL: null },
  gold: { GROOM: "groom-gold", BRIDE: "bride-gold", NEUTRAL: "neutral-mahr" },
  accessories: {
    GROOM: "groom-accessories",
    BRIDE: "bride-gold",
    NEUTRAL: null,
  },
  perfumes: {
    GROOM: "groom-perfume",
    BRIDE: "bride-perfume",
    NEUTRAL: null,
  },
  qat: { GROOM: "groom-qat", BRIDE: null, NEUTRAL: "neutral-qat" },
  "furniture-home": {
    GROOM: "groom-home",
    BRIDE: "bride-home",
    NEUTRAL: "neutral-home",
  },
  apartments: {
    GROOM: "groom-housing",
    BRIDE: "bride-home",
    NEUTRAL: "neutral-home",
  },
  "honeymoon-travel": {
    GROOM: "groom-honeymoon",
    BRIDE: "bride-honeymoon",
    NEUTRAL: "neutral-honeymoon",
  },
  "female-singer": artist,
  "female-vocalist": artist,
  "women-band": artist,
  "dance-troupe": artist,
  "male-singer": artist,
  "male-vocalist": artist,
  "mizmar-folk-band": artist,
  mabra: artist,
  // No starter item covers these: «أخرى» is their right place.
  qarih: none,
  "security-entry": none,
  other: none,
};

const migrationsRoot = join(__dirname, "..", "prisma", "migrations");

/** Every (slug, Arabic name) pair the migrations wrote into ProviderCategory. */
function providerCategoryNamesFromMigrations(): Array<{ slug: string; name: string }> {
  const pairs = new Map<string, { slug: string; name: string }>();
  const add = (slug: string, name: string) =>
    pairs.set(`${slug}\u0000${name}`, { slug, name });
  for (const entry of readdirSync(migrationsRoot, { withFileTypes: true })) {
    if (!entry.isDirectory()) continue;
    const sql = readFileSync(
      join(migrationsRoot, entry.name, "migration.sql"),
      "utf8",
    );
    for (const statement of sql.split(";")) {
      if (!statement.includes('"ProviderCategory"')) continue;
      if (/INSERT INTO "ProviderCategory"/u.test(statement)) {
        for (const row of statement.matchAll(
          /\('[0-9a-f-]{36}',\s*'([^']+)',\s*'[^']*',\s*'([a-z-]+)'/gu,
        )) {
          add(row[2], row[1]);
        }
      }
      const update = statement.match(
        /UPDATE "ProviderCategory"[\s\S]*"nameAr" = '([^']+)'[\s\S]*"slug" = '([a-z-]+)'/u,
      );
      if (update) add(update[2], update[1]);
      if (/WITH desired/u.test(statement)) {
        for (const row of statement.matchAll(
          /\('([a-z-]+)',\s*'([^']+)',\s*'[^']*',\s*'[^']*',\s*(?:true|false)/gu,
        )) {
          add(row[1], row[2]);
        }
      }
      // The older bootstrap used the Arabic name as its slug.
      if (/category_map/u.test(statement)) {
        for (const row of statement.matchAll(
          /\('([^'a-z]+)',\s*'([a-z-]+)'\)/gu,
        )) {
          add(row[2], row[1]);
        }
      }
    }
  }
  return [...pairs.values()];
}

function starterItems(persona: Persona) {
  return moneyStarterDefaults
    .filter((item) => item.metadata?.persona === persona)
    .map((item) => ({
      id: item.key,
      name: item.nameAr,
      normalizedName: normalizeBudgetCategoryName(item.nameAr),
    }));
}

test("the migrations' provider categories are all read and all placed", () => {
  const pairs = providerCategoryNamesFromMigrations();
  const slugs = new Set(pairs.map((pair) => pair.slug));
  // 39 slugs, some with an older name or the bootstrap's Arabic slug.
  assert.ok(pairs.length >= 45, `read only ${pairs.length} category names`);
  assert.deepEqual(
    [...slugs].sort(),
    Object.keys(EXPECTED_BY_SLUG).sort(),
    "every provider category in a migration needs its budget item here",
  );
});

test("every provider category's accepted offer lands in its budget item", () => {
  const personas: Persona[] = ["GROOM", "BRIDE", "NEUTRAL"];
  const items = Object.fromEntries(
    personas.map((persona) => [persona, starterItems(persona)]),
  ) as Record<Persona, ReturnType<typeof starterItems>>;
  for (const { slug, name } of providerCategoryNamesFromMigrations()) {
    for (const persona of personas) {
      assert.equal(
        findLogicalBudgetCategory(items[persona], name)?.id ?? null,
        EXPECTED_BY_SLUG[slug][persona],
        `«${name}» (${slug}) in a ${persona} plan`,
      );
    }
  }
});

test("the reported case: a «وجبات» offer files under the hosting, not «أخرى»", () => {
  const plan = [
    { id: "other", name: "أخرى", normalizedName: "أخرى" },
    { id: "food", name: "الوليمة والضيافة", normalizedName: "الوليمة والضيافة" },
  ];
  assert.equal(findLogicalBudgetCategory(plan, "وجبات")?.id, "food");
  assert.equal(findLogicalBudgetCategory(plan, "زينة"), null);
  assert.equal(
    findLogicalBudgetCategory(
      [...plan, { id: "decor", name: "الكوشة والديكور", normalizedName: "الكوشة والديكور" }],
      "زينة",
    )?.id,
    "decor",
  );
});

test("a request without a service files under the provider's own category", async () => {
  const catalog = {
    getCategories: async (_client: unknown, ids: string[]) =>
      ids.map((id) => ({ id, nameAr: id === "cat-meals" ? "وجبات" : "?" })),
  };
  const relations = new MarketplaceRelationsService(
    catalog as never,
    {} as never,
    {} as never,
    {} as never,
  );
  assert.equal(
    await relations.offerCategoryName({} as never, {
      quoteRequest: { service: null },
      provider: { primaryCategoryId: "cat-meals" },
    }),
    "وجبات",
  );
  assert.equal(
    await relations.offerCategoryName({} as never, {
      quoteRequest: {
        service: { category: { nameAr: "تصوير" } as never },
      },
      provider: { primaryCategoryId: "cat-meals" },
    }),
    "تصوير",
  );
  assert.equal(
    await relations.offerCategoryName({} as never, {
      quoteRequest: { service: null },
      provider: { primaryCategoryId: null },
    }),
    null,
  );
});
