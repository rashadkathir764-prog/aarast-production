export const OTHER_BUDGET_CATEGORY_NAME = "أخرى";

/** The words that name the wedding venue (C24). */
const VENUE_WORDS = ["صالة", "صالات", "قاعة", "قاعات", "hall", "venue"];

/**
 * Where an accepted offer's cost lands (G38). A provider category's name
 * picks one topic (the first with a `provider` word that starts one of the
 * name's words); the topic's `budget` words then pick the plan's item the
 * same way, best word first. Words are matched whole from their start, with
 * «و» and «ال» set aside, never inside another word («قات» is not in
 * «الاتفاقات»). A topic with no
 * budget words is a category no starter item covers: its cost goes to «أخرى»
 * on purpose. Every category a migration wrote is pinned to its item by
 * `test/cost-category-matching.test.ts`, which reads them from the
 * migrations. A category an administrator creates or renames at run time is
 * not in a migration: the admin categories page shows the item it lands in
 * (`providerCategoryBudgetItem`, this same matcher) and warns when it is
 * «أخرى», since a name the topics do not know falls there silently.
 */
interface BudgetTopic {
  readonly provider: readonly string[];
  readonly budget: readonly string[];
}

const BUDGET_TOPICS: readonly BudgetTopic[] = [
  {
    provider: [...VENUE_WORDS, "مخدرة"],
    budget: [
      "قاعة",
      "قاعات",
      "صالة",
      "صالات",
      "مخدرة",
      "مكان",
      "hall",
      "venue",
    ],
  },
  {
    provider: ["تصوير", "مصور", "فيديو", "كاميرا", "photo", "video"],
    budget: ["تصوير", "مصور", "فيديو", "photo", "video"],
  },
  // Meals, drinks, water and the fridges that keep them are the hosting.
  {
    provider: [
      "وجبات",
      "وجبة",
      "غداء",
      "عشاء",
      "ضيافة",
      "بوفيه",
      "تموين",
      "طبخ",
      "ببس",
      "مشروبات",
      "ماء",
      "مياه",
      "ثلاج",
      "cater",
      "meal",
      "drink",
      "water",
    ],
    budget: ["ضيافة", "وليمة", "طعام", "غداء", "عشاء", "بوفيه", "cater"],
  },
  // The qat for the maqyal: an accepted offer from a مقوّت files under it.
  { provider: ["قات", "مقوت", "مقوّت", "qat"], budget: ["قات", "مقيل"] },
  {
    provider: ["كوشة", "ديكور", "زينة", "ورد", "decor", "flower"],
    budget: ["كوشة", "ديكور", "decor"],
  },
  {
    provider: ["صوت", "إضاءة", "sound", "audio", "lighting"],
    budget: ["صوت", "إضاءة"],
  },
  {
    provider: [
      "فنان",
      "منشد",
      "فرقة",
      "مزمار",
      "مبرع",
      "مراقص",
      "رقص",
      "ديجي",
      "ترفيه",
      "dj",
      "music",
      "singer",
      "band",
    ],
    budget: ["فنان", "فرقة", "زفة"],
  },
  { provider: ["زفة", "procession"], budget: ["زفة"] },
  { provider: ["سيارة", "سيارات", "car"], budget: ["سيارة", "مواصلات"] },
  { provider: ["فستان", "فساتين", "dress"], budget: ["فستان", "ملابس"] },
  {
    provider: ["ملبوسات", "ملابس", "أزياء", "بدلة", "clothing"],
    budget: ["ملابس", "بدلة", "كسوة"],
  },
  {
    provider: ["مكياج", "تجميل", "makeup", "beauty"],
    budget: ["مكياج", "تجميل", "عناية"],
  },
  {
    provider: ["كوافير", "صالون", "شعر", "hair", "salon"],
    budget: ["شعر", "كوافير", "مكياج", "عناية"],
  },
  // «المزينة والنقاشة» names the نقاشة herself, not the نقش (G40).
  {
    provider: ["نقاش", "نقش", "حناء", "henna"],
    budget: ["نقش", "حناء", "نقاش"],
  },
  { provider: ["ذهب", "شبكة", "gold"], budget: ["ذهب", "شبكة"] },
  // G11: the home, the apartment and the honeymoon (G10's categories).
  {
    provider: ["أثاث", "مفروشات", "furniture"],
    budget: ["منزل", "أثاث", "جهاز"],
  },
  {
    provider: ["شقق", "شقة", "عقارات", "عقار", "apartment"],
    budget: ["سكن", "إيجار", "منزل"],
  },
  {
    provider: ["سفر", "سياحة", "عسل", "travel", "honeymoon"],
    budget: ["عسل", "سفر"],
  },
  { provider: ["إكسسوار", "accessor"], budget: ["إكسسوار"] },
  { provider: ["عطور", "عطر", "بخور", "perfume"], budget: ["عطور", "بخور"] },
  { provider: ["دعوات", "دعوة", "كروت", "invitation"], budget: ["دعوات"] },
  {
    provider: ["توزيعات", "هدايا", "علاقيات", "دعاية", "giveaway", "gift"],
    budget: ["توزيعات", "هدايا"],
  },
  { provider: ["حلاقة", "حلاق", "barber"], budget: ["حلاقة", "عناية"] },
  // Entry security and the قريح have no starter item: «أخرى» on purpose.
  // Security precedes coordination, whose word «تنظيم» its name shares.
  { provider: ["أمن", "security"], budget: [] },
  { provider: ["قريح"], budget: [] },
  { provider: ["تنسيق", "تنظيم", "coordinat"], budget: ["تنسيق"] },
];

/**
 * C24: a budget category that names the wedding venue (قاعة، صالة، venue).
 * A cost in it is a recorded venue agreement.
 */
export function isVenueBudgetCategoryName(name: string): boolean {
  const source = normalizeForLogicalMatch(name);
  if (!source) return false;
  return VENUE_WORDS.some((keyword) =>
    source.includes(normalizeForLogicalMatch(keyword)),
  );
}

export interface BudgetCategoryCandidate {
  id: string;
  name: string;
  normalizedName: string;
}

export function normalizeBudgetCategoryName(value: string): string {
  return value.trim().replace(/\s+/gu, " ").toLocaleLowerCase("ar");
}

/**
 * The plan's item for a provider category, or null for «أخرى». Among items
 * that share the best word, the first in `categories` wins, so the caller
 * passes them in a stable order.
 */
export function findLogicalBudgetCategory<T extends BudgetCategoryCandidate>(
  categories: readonly T[],
  providerCategoryName: string | null | undefined,
): T | null {
  const source = normalizeForLogicalMatch(providerCategoryName ?? "");
  if (!source) return null;

  const exact = categories.find(
    (category) => normalizeForLogicalMatch(category.normalizedName) === source,
  );
  if (exact) return exact;

  const sourceWords = wordStems(source);
  const topic = BUDGET_TOPICS.find((candidate) =>
    candidate.provider.some((keyword) => hasWord(sourceWords, keyword)),
  );
  if (!topic) return null;

  const candidates = categories.map((category) => ({
    category,
    words: wordStems(
      normalizeForLogicalMatch(`${category.name} ${category.normalizedName}`),
    ),
  }));
  for (const keyword of topic.budget) {
    const match = candidates.find(({ words }) => hasWord(words, keyword));
    if (match) return match.category;
  }
  return null;
}

/**
 * The plan's item an accepted offer of this provider category is filed
 * under: its topic's item, else the plan's «أخرى» (null when the plan has
 * no «أخرى» yet; acceptance then creates it).
 */
export function budgetItemForProviderCategory<T extends BudgetCategoryCandidate>(
  categories: readonly T[],
  providerCategoryName: string | null | undefined,
): T | null {
  return (
    findLogicalBudgetCategory(categories, providerCategoryName) ??
    findOtherBudgetCategory(categories)
  );
}

/**
 * G40: the provider categories each item is searched by, read from the very
 * rule that files an accepted offer (`budgetItemForProviderCategory`), so
 * «ابحث» on an item lists exactly the providers whose offers land in it.
 * Every item is a key, in the plan's order; one no category lands in has an
 * empty list (no «ابحث»). A category appears under one item at most.
 */
export function providerCategoryIdsByBudgetItem<
  T extends BudgetCategoryCandidate,
>(
  categories: readonly T[],
  providerCategories: ReadonlyArray<{ id: string; nameAr: string }>,
): Map<string, string[]> {
  const byItem = new Map<string, string[]>(
    categories.map((category) => [category.id, []]),
  );
  for (const providerCategory of providerCategories) {
    const item = budgetItemForProviderCategory(
      categories,
      providerCategory.nameAr,
    );
    if (item) byItem.get(item.id)?.push(providerCategory.id);
  }
  return byItem;
}

/** Each word with its «و», «ال», «بال» or «لل» set aside as well. */
function wordStems(normalized: string): string[] {
  return normalized.split(" ").flatMap((word) => {
    const stems = [word];
    for (const prefix of ["وال", "بال", "لل", "ال", "و"]) {
      if (word.startsWith(prefix) && word.length - prefix.length >= 2) {
        stems.push(word.slice(prefix.length));
      }
    }
    return stems;
  });
}

function hasWord(stems: readonly string[], keyword: string): boolean {
  const word = normalizeForLogicalMatch(keyword);
  return stems.some((stem) => stem.startsWith(word));
}

export function findOtherBudgetCategory<T extends BudgetCategoryCandidate>(
  categories: readonly T[],
): T | null {
  const target = normalizeForLogicalMatch(OTHER_BUDGET_CATEGORY_NAME);
  return (
    categories.find(
      (category) =>
        normalizeForLogicalMatch(category.normalizedName) === target,
    ) ?? null
  );
}

function normalizeForLogicalMatch(value: string): string {
  return value
    .toLocaleLowerCase("ar")
    .replace(/[أإآ]/gu, "ا")
    .replace(/ى/gu, "ي")
    .replace(/ة/gu, "ه")
    .replace(/[ً-ٟ]/gu, "")
    .replace(/[^a-z0-9ء-ي]+/gu, " ")
    .trim();
}
