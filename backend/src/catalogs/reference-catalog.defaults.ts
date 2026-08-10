export const MONEY_STARTER_CATALOG_KEY = 'money.starter.categories';

export interface DefaultReferenceCatalogItem {
  key: string;
  groupKey: string;
  groupNameAr: string;
  groupSubtitleAr: string;
  nameAr: string;
  icon: string;
  sortOrder: number;
  showForGroom: boolean;
  showForBride: boolean;
  isRecommended: boolean;
  metadata?: Record<string, string>;
}

type GroupSeed = {
  key: string;
  nameAr: string;
  subtitleAr: string;
  persona: 'GROOM' | 'BRIDE' | 'NEUTRAL';
  items: Array<[key: string, nameAr: string, icon: string, recommended?: boolean]>;
};

const groups: GroupSeed[] = [
  {
    key: 'groom-agreement',
    nameAr: 'أساسيات الزواج',
    subtitleAr: 'البنود المرتبطة بالعقد والاتفاقات.',
    persona: 'GROOM',
    items: [
      ['groom-mahr', 'المهر والاتفاقات', 'users', true],
      ['groom-gold', 'الذهب والشبكة', 'gem', true],
      ['groom-contract', 'العقد والمعاملات', 'file-check'],
    ],
  },
  {
    key: 'groom-event',
    nameAr: 'مناسبة الرجال',
    subtitleAr: 'المكان والضيافة وكل ما يحدث في يوم المناسبة.',
    persona: 'GROOM',
    items: [
      ['groom-venue', 'قاعة أو مخدرة الرجال', 'building-2', true],
      ['groom-food', 'الوليمة والضيافة', 'utensils', true],
      ['groom-photo', 'التصوير والفيديو', 'camera', true],
      ['groom-audio', 'الصوت والإضاءة', 'speaker'],
      ['groom-zaffa', 'الزفة والسيارة', 'car', true],
      ['groom-evening', 'جلسة أو سهرة العريس', 'moon-star'],
      ['groom-guest-stay', 'إقامة الضيوف', 'bed-double'],
    ],
  },
  {
    key: 'groom-look',
    nameAr: 'تجهيز العريس',
    subtitleAr: 'الإطلالة والاستعداد الشخصي.',
    persona: 'GROOM',
    items: [
      ['groom-suit', 'بدلة العريس', 'shirt', true],
      ['groom-grooming', 'الحلاقة والعناية', 'scissors', true],
      ['groom-accessories', 'الأحذية والإكسسوارات', 'watch'],
      ['groom-clothes', 'ملابس المناسبات', 'shopping-bag'],
      ['groom-perfume', 'العطور والبخور', 'spray-can'],
    ],
  },
  {
    key: 'groom-life',
    nameAr: 'البيت والبداية الجديدة',
    subtitleAr: 'ما بعد الحفل والمصاريف المشتركة.',
    persona: 'GROOM',
    items: [
      ['groom-home', 'تجهيز المنزل', 'home', true],
      ['groom-housing', 'السكن والإيجار', 'key-round'],
      ['groom-honeymoon', 'شهر العسل', 'plane'],
      ['groom-invites', 'الدعوات', 'mail'],
      ['groom-gifts', 'الهدايا والتوزيعات', 'gift'],
      ['groom-transport', 'المواصلات', 'navigation'],
      ['groom-buffer', 'مصاريف طارئة', 'shield-check', true],
    ],
  },
  {
    key: 'bride-look',
    nameAr: 'إطلالة العروسة',
    subtitleAr: 'كل ما يخص الإطلالة والاستعداد الشخصي.',
    persona: 'BRIDE',
    items: [
      ['bride-dress', 'فستان العروسة', 'sparkles', true],
      ['bride-makeup', 'المكياج والشعر', 'wand-2', true],
      ['bride-care', 'العناية والتجهيز', 'flower-2', true],
      ['bride-gold', 'الذهب والإكسسوارات', 'gem', true],
      ['bride-shoes', 'الأحذية والشنط', 'shopping-bag'],
      ['bride-clothes', 'ملابس المناسبات', 'shirt'],
      ['bride-perfume', 'العطور والبخور', 'spray-can'],
    ],
  },
  {
    key: 'bride-event',
    nameAr: 'مناسبة النساء',
    subtitleAr: 'المكان والتنسيق والضيافة في يوم المناسبة.',
    persona: 'BRIDE',
    items: [
      ['bride-venue', 'صالة أو مكان النساء', 'building-2', true],
      ['bride-decor', 'الكوشة والديكور', 'layout-grid', true],
      ['bride-photo', 'التصوير النسائي', 'camera', true],
      ['bride-food', 'الضيافة والحلويات', 'cake-slice', true],
      ['bride-audio', 'الصوت والزفة', 'music-2'],
      ['bride-invites', 'الدعوات والتوزيعات', 'mail'],
      ['bride-henna', 'ليلة الحناء', 'flower'],
    ],
  },
  {
    key: 'bride-life',
    nameAr: 'التجهيز والبداية الجديدة',
    subtitleAr: 'بنود البيت والمصاريف المشتركة بعد المناسبة.',
    persona: 'BRIDE',
    items: [
      ['bride-trousseau', 'جهاز العروسة', 'package-open', true],
      ['bride-home', 'تجهيز المنزل', 'home'],
      ['bride-room', 'تجهيز غرفة العروسة', 'bed-double'],
      ['bride-honeymoon', 'شهر العسل', 'plane'],
      ['bride-gifts', 'الهدايا', 'gift'],
      ['bride-transport', 'المواصلات', 'navigation'],
      ['bride-guest-stay', 'إقامة الضيوف', 'hotel'],
      ['bride-buffer', 'مصاريف طارئة', 'shield-check', true],
    ],
  },
  {
    key: 'neutral-event',
    nameAr: 'المناسبة',
    subtitleAr: 'أهم بنود يوم العرس.',
    persona: 'NEUTRAL',
    items: [
      ['neutral-venue', 'مكان المناسبة', 'building-2', true],
      ['neutral-food', 'الضيافة والطعام', 'utensils', true],
      ['neutral-photo', 'التصوير والفيديو', 'camera', true],
      ['neutral-decor', 'التنسيق والديكور', 'layout-grid'],
      ['neutral-audio', 'الصوت والزفة', 'music-2'],
    ],
  },
  {
    key: 'neutral-prep',
    nameAr: 'التجهيز والبداية الجديدة',
    subtitleAr: 'البنود الشخصية والمشتركة.',
    persona: 'NEUTRAL',
    items: [
      ['neutral-look', 'الملابس والتجهيز', 'shirt', true],
      ['neutral-invites', 'الدعوات والتوزيعات', 'mail'],
      ['neutral-home', 'تجهيز المنزل', 'home'],
      ['neutral-honeymoon', 'شهر العسل', 'plane'],
      ['neutral-transport', 'المواصلات', 'navigation'],
      ['neutral-buffer', 'مصاريف طارئة', 'shield-check', true],
    ],
  },
];

export const moneyStarterDefaults: DefaultReferenceCatalogItem[] = groups.flatMap(
  (group, groupIndex) =>
    group.items.map(([key, nameAr, icon, recommended], itemIndex) => ({
      key,
      groupKey: group.key,
      groupNameAr: group.nameAr,
      groupSubtitleAr: group.subtitleAr,
      nameAr,
      icon,
      sortOrder: (groupIndex + 1) * 100 + (itemIndex + 1) * 10,
      showForGroom: group.persona === 'GROOM',
      showForBride: group.persona === 'BRIDE',
      isRecommended: recommended ?? false,
      metadata: { persona: group.persona },
    })),
);

export const supportedCatalogIconKeys = new Set(
  moneyStarterDefaults.map((item) => item.icon),
);
