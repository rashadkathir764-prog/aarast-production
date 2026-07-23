export const OTHER_BUDGET_CATEGORY_NAME = "أخرى";

const CATEGORY_GROUPS = [
  [
    "صالة",
    "صاله",
    "صالات",
    "الصالات",
    "قاعة",
    "قاعه",
    "قاعات",
    "hall",
    "venue",
  ],
  [
    "غداء",
    "عشاء",
    "ضيافة",
    "ضيافه",
    "بوفيه",
    "تموين",
    "ماء",
    "cater",
  ],
  ["تصوير", "مصور", "فيديو", "كاميرا", "photo", "video"],
  ["كوشة", "كوشه", "ديكور", "ورد", "زفة", "زفه", "decor"],
  ["فنان", "فرقة", "فرقه", "ديجي", "dj", "music", "ترفيه"],
  ["فستان", "ازياء", "أزياء", "ملابس", "بدلة", "بدله", "dress"],
  ["صالون", "مكياج", "تجميل", "كوافير", "beauty", "salon"],
] as const;

export interface BudgetCategoryCandidate {
  id: string;
  name: string;
  normalizedName: string;
}

export function normalizeBudgetCategoryName(value: string): string {
  return value.trim().replace(/\s+/gu, " ").toLocaleLowerCase("ar");
}

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

  const group = CATEGORY_GROUPS.find((keywords) =>
    keywords.some((keyword) => source.includes(normalizeForLogicalMatch(keyword))),
  );
  if (!group) return null;

  return (
    categories.find((category) => {
      const candidate = normalizeForLogicalMatch(
        `${category.name} ${category.normalizedName}`,
      );
      return group.some((keyword) =>
        candidate.includes(normalizeForLogicalMatch(keyword)),
      );
    }) ?? null
  );
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
    .replace(/[\u064B-\u065F]/gu, "")
    .replace(/[^a-z0-9\u0621-\u064A]+/gu, " ")
    .trim();
}
