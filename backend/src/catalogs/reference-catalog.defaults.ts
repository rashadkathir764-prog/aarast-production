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
      // Appended items keep the existing sort orders unchanged.
      ['groom-kiswa', 'الكسوة', 'shirt', true],
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
      ['groom-qat', 'القات والمقيل', 'leaf', true],
      ['groom-artist', 'الفنان والفرقة', 'music-2'],
      ['groom-sacrifice', 'الذبائح', 'utensils'],
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
      ['groom-honeymoon', 'شهر العسل', 'plane', true],
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
      ['bride-naqsh', 'النقش', 'flower-2', true],
      ['bride-artist', 'الفنانة والزفة', 'music-2'],
      ['bride-subhia', 'الصبحية', 'cake-slice'],
    ],
  },
  {
    key: 'bride-life',
    nameAr: 'التجهيز والبداية الجديدة',
    subtitleAr: 'بنود البيت والمصاريف المشتركة بعد المناسبة.',
    persona: 'BRIDE',
    items: [
      ['bride-trousseau', 'جهاز العروسة', 'package-open', true],
      ['bride-home', 'تجهيز المنزل', 'home', true],
      ['bride-room', 'تجهيز غرفة العروسة', 'bed-double'],
      ['bride-honeymoon', 'شهر العسل', 'plane', true],
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
      ['neutral-qat', 'القات والمقيل', 'leaf'],
      // Hidden from every starter list: the mahr is its own section (C1).
      ['neutral-mahr', 'المهر والذهب', 'gem'],
      // G12: the gold on its own, so a plan without a persona still has it.
      ['neutral-gold', 'الذهب والشبكة', 'gem'],
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
      ['neutral-honeymoon', 'شهر العسل', 'plane', true],
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

export const TASK_STARTER_CATALOG_KEY = 'tasks.starter';

type TaskGroupSeed = {
  key: string;
  nameAr: string;
  subtitleAr: string;
  /** SHARED and FAMILY tasks are offered to both the groom and the bride. */
  persona: 'GROOM' | 'BRIDE' | 'SHARED' | 'FAMILY';
  items: Array<
    [key: string, titleAr: string, icon: string, daysBefore: number, recommended?: boolean]
  >;
};

// Suggested tasks for a new plan. `daysBefore` places the due date that many
// days before the wedding date (the app clamps a past date to today).
const taskGroups: TaskGroupSeed[] = [
  {
    key: 'shared-tasks',
    nameAr: 'مهام مشتركة',
    subtitleAr: 'الأساسيات التي يتفق عليها الطرفان.',
    persona: 'SHARED',
    items: [
      ['task-shared-date', 'تحديد موعد العرس', 'sparkles', 300, true],
      ['task-shared-budget', 'تحديد الميزانية وتوزيعها على البنود', 'shield-check', 300, true],
      ['task-shared-photo', 'حجز المصور', 'camera', 120],
      ['task-shared-home', 'تجهيز الشقة والأثاث', 'home', 120],
      ['task-shared-guests', 'إعداد قائمة المعازيم', 'users', 90, true],
      ['task-shared-contract', 'تجهيز أوراق عقد القران', 'file-check', 60, true],
      ['task-shared-honeymoon', 'ترتيب شهر العسل', 'plane', 60],
      ['task-shared-invites', 'توزيع الدعوات', 'mail', 30, true],
    ],
  },
  {
    key: 'groom-tasks',
    nameAr: 'مهام العريس',
    subtitleAr: 'الاتفاقات ومناسبة الرجال.',
    persona: 'GROOM',
    items: [
      ['task-groom-mahr', 'الاتفاق مع أهل العروسة على المهر والشرط', 'users', 270, true],
      ['task-groom-gold', 'شراء الشبكة والذهب', 'gem', 180, true],
      ['task-groom-venue', 'حجز قاعة أو مخدرة الرجال', 'building-2', 180, true],
      ['task-groom-kiswa', 'تجهيز الكسوة', 'shirt', 120, true],
      ['task-groom-artist', 'الاتفاق مع الفنان والفرقة', 'music-2', 120],
      ['task-groom-food', 'الاتفاق على الوليمة والذبائح', 'utensils', 60, true],
      ['task-groom-suit', 'تفصيل ملابس العريس', 'shirt', 60],
      ['task-groom-qat', 'ترتيب القات والمقيل', 'leaf', 14],
      ['task-groom-zaffa', 'ترتيب الزفة والسيارة', 'car', 14],
    ],
  },
  {
    key: 'bride-tasks',
    nameAr: 'مهام العروسة',
    subtitleAr: 'التجهيز ومناسبة النساء.',
    persona: 'BRIDE',
    items: [
      ['task-bride-hall', 'حجز قاعة النساء', 'building-2', 180, true],
      ['task-bride-dress', 'اختيار فستان الزفاف', 'shirt', 150, true],
      ['task-bride-coiffeur', 'حجز الكوافير', 'wand-2', 90, true],
      ['task-bride-singer', 'الاتفاق مع الفنانة أو الزفافة', 'music-2', 90],
      ['task-bride-naqsh', 'حجز النقاشة لليلة النقش والحناء', 'flower-2', 60, true],
      ['task-bride-subhia', 'تجهيز الصبحية', 'cake-slice', 14],
      // G12 (appended so the sort orders above stay): her gold and her
      // trousseau, as the groom has his gold and kiswa.
      ['task-bride-gold', 'شراء الذهب والإكسسوارات', 'gem', 150, true],
      ['task-bride-trousseau', 'تجهيز جهاز العروسة', 'package-open', 120, true],
    ],
  },
  {
    key: 'family-tasks',
    nameAr: 'مهام الأهل',
    subtitleAr: 'ما يساعد فيه الأهل والأقارب.',
    persona: 'FAMILY',
    items: [
      ['task-family-stay', 'ترتيب إقامة الضيوف القادمين من خارج المدينة', 'bed-double', 30],
      ['task-family-hosting', 'تجهيز استقبال الضيوف والضيافة', 'utensils', 14],
      ['task-family-helpers', 'توزيع مهام يوم العرس على الأقارب', 'users', 7],
    ],
  },
];

export const taskStarterDefaults: DefaultReferenceCatalogItem[] = taskGroups.flatMap(
  (group, groupIndex) =>
    group.items.map(([key, nameAr, icon, daysBefore, recommended], itemIndex) => ({
      key,
      groupKey: group.key,
      groupNameAr: group.nameAr,
      groupSubtitleAr: group.subtitleAr,
      nameAr,
      icon,
      sortOrder: (groupIndex + 1) * 100 + (itemIndex + 1) * 10,
      showForGroom: group.persona !== 'BRIDE',
      showForBride: group.persona !== 'GROOM',
      isRecommended: recommended ?? false,
      metadata: { persona: group.persona, daysBefore: String(daysBefore) },
    })),
);

export interface SystemCatalogDefinition {
  key: string;
  nameAr: string;
  description: string;
  items: readonly DefaultReferenceCatalogItem[];
}

/** The catalogs the API seeds on start; existing rows and admin edits are kept. */
export const systemCatalogs: readonly SystemCatalogDefinition[] = [
  {
    key: MONEY_STARTER_CATALOG_KEY,
    nameAr: 'تصنيفات بداية الميزانية',
    description: 'التصنيفات المقترحة للعريس والعروسة قبل تحديد الميزانية.',
    items: moneyStarterDefaults,
  },
  {
    key: TASK_STARTER_CATALOG_KEY,
    nameAr: 'قوالب المهام',
    description: 'المهام المقترحة لخطة جديدة مع موعدها قبل العرس.',
    items: taskStarterDefaults,
  },
];

export const supportedCatalogIconKeys = new Set(
  systemCatalogs.flatMap((catalog) => catalog.items.map((item) => item.icon)),
);
