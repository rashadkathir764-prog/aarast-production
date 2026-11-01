/**
 * G23 (owner-vision audit 2026-10-27), «ايش ناقص»: the six things the owner
 * named — the venue, the dress, the photos, the gold, the home and the
 * honeymoon — each read from the plan's own money items. An item booked by
 * D60's one «محجوز» is BOOKED; one with an agreement is AGREED; otherwise
 * MISSING. NONE: the plan has no item for it at all (the user removed it).
 */
export type PlanEssentialKey = 'VENUE' | 'DRESS' | 'PHOTO' | 'GOLD' | 'HOME' | 'HONEYMOON';
export type PlanEssentialStatus = 'BOOKED' | 'AGREED' | 'MISSING' | 'NONE';

export interface PlanEssential {
  key: PlanEssentialKey;
  status: PlanEssentialStatus;
  /** The plan's item it reads, when there is one. */
  budgetCategoryId: string | null;
  /**
   * The owner answered the home's suggestion of this item with «ما أحتاجها»
   * or «بعدين» (finance's rule, read from the item): off the home for now.
   */
  hidden: boolean;
}

type Persona = 'GROOM' | 'BRIDE' | 'HELPER' | null;

const WORDS: Record<PlanEssentialKey, (persona: Persona) => readonly string[]> = {
  VENUE: () => ['قاعة', 'صالة', 'مخدرة', 'مكان'],
  DRESS: (persona) =>
    persona === 'GROOM'
      ? ['بدلة', 'كسوة']
      : persona === 'BRIDE'
        ? ['فستان']
        : ['فستان', 'بدلة', 'ملابس', 'اطلالة'],
  PHOTO: () => ['تصوير', 'مصور'],
  GOLD: () => ['ذهب', 'شبكة'],
  HOME: () => ['منزل', 'سكن', 'اثاث', 'شقة'],
  HONEYMOON: () => ['عسل'],
};

const ORDER: readonly PlanEssentialKey[] = ['VENUE', 'DRESS', 'PHOTO', 'GOLD', 'HOME', 'HONEYMOON'];

function words(name: string): string[] {
  return name
    .trim()
    .toLocaleLowerCase('ar')
    .replace(/[أإآ]/g, 'ا')
    .split(/\s+/)
    .map((word) => word.replace(/^و/, '').replace(/^ال/, ''))
    .filter(Boolean);
}

export function planEssentials(input: {
  persona: Persona;
  /** The reader's money items; the mahr item never counts. */
  categories: ReadonlyArray<{
    categoryId: string;
    name: string;
    kind: string;
    costsCount: number;
    suggestionHidden?: boolean;
  }>;
  bookedCategoryIds: readonly string[];
  venueSecured: boolean;
}): PlanEssential[] {
  const booked = new Set(input.bookedCategoryIds);
  const items = input.categories
    .filter((category) => category.kind !== 'MAHR')
    .map((category) => ({ ...category, words: words(category.name) }));
  return ORDER.map((key) => {
    const wanted = WORDS[key](input.persona).map((word) => words(word)[0]);
    const matching = items.filter((item) =>
      item.words.some((word) => wanted.some((target) => word.startsWith(target))),
    );
    const bookedItem = matching.find((item) => booked.has(item.categoryId));
    const agreedItem = matching.find((item) => item.costsCount > 0);
    const first = bookedItem ?? agreedItem ?? matching[0] ?? null;
    let status: PlanEssentialStatus;
    if (bookedItem || (key === 'VENUE' && input.venueSecured && !agreedItem)) status = 'BOOKED';
    else if (agreedItem) status = 'AGREED';
    else if (matching.length > 0) status = 'MISSING';
    else status = 'NONE';
    return {
      key,
      status,
      budgetCategoryId: first?.categoryId ?? null,
      hidden: first?.suggestionHidden ?? false,
    };
  });
}
