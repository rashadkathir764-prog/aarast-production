// What the two plans hold, taken from the prototypes: the groom's «عرس محمد»
// (mobile/test/prototype/v3) and the bride's «عرس سلمى» (the same screens with
// her words, mobile/test/prototype/bride_profile). Amounts are in Yemeni rial.
import {
  BudgetCategoryKind,
  CostPayer,
  FundingSourceKind,
  FundingSourceStatus,
  GuestSide,
  SharedMemberRole,
  WeddingPersona,
  WeddingTaskPriority,
} from '@prisma/client';
import type { DemoAccountKey } from './accounts';
import { day, inDays } from './support';

export interface PaymentSpec {
  key: string;
  amount: number;
  paidAt: Date;
  method: string;
  note?: string;
  /** The schedule this payment settled, when it settled one. */
  scheduleKey?: string;
}

export interface ScheduleSpec {
  key: string;
  amount: number;
  dueDate: Date;
  paid: boolean;
  note: string;
}

export interface CostSpec {
  key: string;
  title: string;
  /** A marketplace provider (with an accepted offer) or an outside party. */
  providerKey?: string;
  offerKey?: string;
  partyName?: string;
  /** The agreed amount when it is not the item's allocation (the mahr). */
  total?: number;
  /** Who pays it (G14). */
  payer?: CostPayer;
  payerName?: string;
  agreementDate: Date;
  payments: PaymentSpec[];
  schedules: ScheduleSpec[];
}

export interface ItemSpec {
  key: string;
  name: string;
  allocated: number;
  /** MAHR is the groom's mahr item, outside the budget (C1): no allocation. */
  kind?: BudgetCategoryKind;
  /** Items still without an agreement (not booked yet) have no cost. */
  cost?: CostSpec;
}

export interface FundingSpec {
  key: string;
  kind: FundingSourceKind;
  sourceName: string;
  amount: number;
  status: FundingSourceStatus;
  receivedAt?: Date;
  /** A pledge's expected day (the rest of the mahr). */
  expectedAt?: Date;
  note: string;
  repayments?: Array<{ key: string; amount: number; dueDate: Date; note: string }>;
}

export interface TaskSpec {
  key: string;
  title: string;
  done: boolean;
  dueDate: Date;
  assignee?: DemoAccountKey;
  responsibleName?: string;
  description?: string;
  priority?: WeddingTaskPriority;
  checklist?: Array<{ title: string; done: boolean }>;
  /** The helper who created it (feeds their contribution history). */
  createdByMember?: DemoAccountKey;
  /** R4: the item it waits on, by the item's key. */
  linkedItem?: string;
  /** R4: the payment it waits on, by its agreement's and its schedule's keys. */
  linkedPayment?: { cost: string; schedule: string };
}

export interface GuestGroupSpec {
  key: string;
  name: string;
  side: GuestSide;
  total: number;
  confirmed: number;
  /** Of the rest, how many have not answered yet (the others declined). */
  pending: number;
  /** Names that come from the designs go first. */
  firstNames: readonly string[];
  surnames: readonly string[];
  featured?: Array<{ name: string; companions?: number; attendance?: 'CONFIRMED' | 'DECLINED' | 'PENDING' }>;
}

export interface MemberSpec {
  account: DemoAccountKey;
  role: SharedMemberRole;
  canViewMoney: boolean;
  canEditPlan: boolean;
  canManageTasks: boolean;
  canManageGuests: boolean;
  canManageProviders: boolean;
  canInviteMembers: boolean;
  canManageMoney: boolean;
}

export interface PlanSpec {
  key: 'groom' | 'bride';
  owner: DemoAccountKey;
  persona: WeddingPersona;
  title: string;
  weddingDate: Date;
  budget: number;
  items: ItemSpec[];
  funding: FundingSpec[];
  tasks: TaskSpec[];
  guestGroups: GuestGroupSpec[];
  members: MemberSpec[];
  /** Providers (marketplace keys) the plan holds a conversation with. */
  conversations: string[];
}

const WEDDING_DAY = '2027-01-21';

/** The designs' money, word for word, once per persona (only the labels differ). */
function moneyItems(words: {
  hall: string;
  hallProvider: string;
  /** Marketplace key of the hall provider and of its accepted request. */
  hallKey: string;
  qat: string;
  artist: string;
  outfit: string;
  lunchParty: string;
  /** G14 (w20): who pays each item: the owner, or the family named here. */
  owner: CostPayer;
  family: string;
}): ItemSpec[] {
  return [
    {
      key: 'hall',
      name: words.hall,
      allocated: 2_000_000,
      cost: {
        key: 'hall',
        title: words.hallProvider,
        providerKey: words.hallKey,
        offerKey: words.hallKey,
        payer: CostPayer.FAMILY,
        payerName: words.family,
        agreementDate: day('2026-09-10'),
        payments: [
          {
            key: 'hall-deposit',
            amount: 500_000,
            paidAt: day('2026-09-10'),
            method: 'نقدًا',
            note: 'العربون',
            scheduleKey: 'hall-s1',
          },
        ],
        schedules: [
          { key: 'hall-s1', amount: 500_000, dueDate: day('2026-09-10'), paid: true, note: 'العربون' },
          { key: 'hall-s2', amount: 500_000, dueDate: inDays(5), paid: false, note: 'الدفعة الثانية' },
          { key: 'hall-s3', amount: 1_000_000, dueDate: day(WEDDING_DAY), paid: false, note: 'الباقي يوم العرس' },
        ],
      },
    },
    {
      key: 'hospitality',
      name: 'الضيافة والعشاء',
      allocated: 1_600_000,
      cost: {
        key: 'hospitality',
        title: 'ضيافة الأصالة',
        providerKey: 'hospitality',
        offerKey: 'hospitality',
        payer: words.owner,
        agreementDate: day('2026-08-15'),
        payments: [
          { key: 'hosp-deposit', amount: 1_100_000, paidAt: day('2026-08-15'), method: 'نقدًا', note: 'العربون الأول' },
        ],
        schedules: [
          { key: 'hosp-s1', amount: 400_000, dueDate: day('2026-12-20'), paid: false, note: 'العربون الثاني' },
          { key: 'hosp-s2', amount: 100_000, dueDate: day(WEDDING_DAY), paid: false, note: 'الباقي يوم العرس' },
        ],
      },
    },
    { key: 'qat', name: words.qat, allocated: 1_000_000 },
    {
      key: 'lunch',
      name: 'الغداء',
      allocated: 1_000_000,
      cost: {
        key: 'lunch',
        title: 'غداء العرس',
        partyName: words.lunchParty,
        payer: CostPayer.FAMILY,
        payerName: words.family,
        agreementDate: day('2026-10-01'),
        payments: [
          { key: 'lunch-deposit', amount: 800_000, paidAt: day('2026-10-01'), method: 'نقدًا', note: 'دفعة الغداء' },
        ],
        schedules: [],
      },
    },
    { key: 'photo', name: 'التصوير', allocated: 600_000 },
    { key: 'artist', name: words.artist, allocated: 500_000 },
    {
      key: 'outfit',
      name: words.outfit,
      allocated: 300_000,
      cost: {
        key: 'outfit',
        title: words.outfit,
        partyName: 'الخياط',
        payer: words.owner,
        agreementDate: day('2026-09-30'),
        payments: [
          { key: 'outfit-deposit', amount: 200_000, paidAt: day('2026-09-30'), method: 'نقدًا', note: 'الدفعة الأولى' },
        ],
        schedules: [
          { key: 'outfit-s1', amount: 100_000, dueDate: day('2026-12-01'), paid: false, note: 'الباقي' },
        ],
      },
    },
  ];
}

/** a06 and c02 (groom): 3 million, 2 handed over on the engagement day, the rest on the contract day. */
const MAHR_TOTAL = 3_000_000;
const MAHR_HANDED = 2_000_000;
/** The contract day, the same day as the «سلّم باقي المهر» task. */
const mahrRestDay = () => inDays(21);

/** The groom's mahr (C1): his agreement with the bride's family, outside the budget. */
function groomMahrItem(): ItemSpec {
  return {
    key: 'mahr',
    name: 'المهر',
    allocated: 0,
    kind: BudgetCategoryKind.MAHR,
    cost: {
      key: 'mahr',
      title: 'المهر',
      partyName: 'أهل العروسة',
      total: MAHR_TOTAL,
      payer: CostPayer.GROOM,
      agreementDate: day('2026-08-01'),
      payments: [
        { key: 'mahr-engagement', amount: MAHR_HANDED, paidAt: day('2026-08-01'), method: 'نقدًا', note: 'يوم الخطوبة' },
      ],
      schedules: [
        { key: 'mahr-rest', amount: MAHR_TOTAL - MAHR_HANDED, dueDate: mahrRestDay(), paid: false, note: 'الباقي يوم العقد' },
      ],
    },
  };
}

/** The bride's mahr (C1): money coming in (c05), received and the rest pledged. */
function brideMahrFunding(): FundingSpec[] {
  return [
    {
      key: 'mahr',
      kind: FundingSourceKind.MAHR,
      sourceName: 'المهر من العريس',
      amount: MAHR_HANDED,
      status: FundingSourceStatus.RECEIVED,
      receivedAt: day('2026-08-01'),
      note: 'استلمه الوالد يوم الخطوبة · للتجهيز',
    },
    {
      key: 'mahr-rest',
      kind: FundingSourceKind.MAHR,
      sourceName: 'باقي المهر',
      amount: MAHR_TOTAL - MAHR_HANDED,
      status: FundingSourceStatus.PLEDGED,
      expectedAt: mahrRestDay(),
      note: 'يوصلك يوم العقد',
    },
  ];
}

function funding(words: {
  father: string;
  friend: string;
  /** c05: the groom's «مدخراتي» is 4.5 million; the bride's 900 thousand. */
  savings: number;
  /** c05: the groom's father gives 2.4 million; the bride's mother 1 million. */
  family: number;
}): FundingSpec[] {
  return [
    {
      key: 'savings',
      kind: FundingSourceKind.SAVINGS,
      sourceName: 'مدخراتي',
      amount: words.savings,
      status: FundingSourceStatus.RECEIVED,
      receivedAt: day('2026-08-01'),
      note: 'من راتبي',
    },
    {
      key: 'father',
      kind: FundingSourceKind.FAMILY_SUPPORT,
      sourceName: words.father,
      amount: words.family,
      status: FundingSourceStatus.RECEIVED,
      receivedAt: day('2026-08-20'),
      note: 'هدية',
    },
    {
      key: 'loan',
      kind: FundingSourceKind.LOAN,
      sourceName: 'خالي أحمد',
      amount: 600_000,
      status: FundingSourceStatus.RECEIVED,
      receivedAt: day('2026-09-05'),
      note: 'أرده 4 أقساط بعد العرس',
      repayments: [
        { key: 'r1', amount: 150_000, dueDate: day('2027-02-01'), note: 'القسط الأول' },
        { key: 'r2', amount: 150_000, dueDate: day('2027-03-01'), note: 'القسط الثاني' },
        { key: 'r3', amount: 150_000, dueDate: day('2027-04-01'), note: 'القسط الثالث' },
        { key: 'r4', amount: 150_000, dueDate: day('2027-05-01'), note: 'القسط الرابع' },
      ],
    },
    {
      key: 'friend',
      // A promise of money, not a loan with a repayment plan yet.
      kind: FundingSourceKind.OTHER,
      sourceName: words.friend,
      amount: 1_200_000,
      status: FundingSourceStatus.PLEDGED,
      note: 'وعد قبل العرس · دين',
    },
  ];
}

const MALE_FIRST = [
  'أحمد', 'علي', 'هاني', 'عبدالله', 'خالد', 'ياسر', 'يحيى', 'ناصر', 'سعيد', 'فهد',
  'منصور', 'جمال', 'وليد', 'نبيل', 'حسين', 'إبراهيم', 'عمر', 'زيد', 'رامي', 'طارق',
  'بدر', 'حمزة', 'مازن', 'ماجد', 'عدنان', 'فيصل', 'رشدي', 'أنس', 'ثابت', 'مروان',
] as const;
const FEMALE_FIRST = [
  'أسماء', 'علياء', 'هناء', 'عبير', 'يسرى', 'أمل', 'مها', 'نوال', 'سمر', 'رنا',
  'ريم', 'هدى', 'لمى', 'إيمان', 'بشرى', 'ابتسام', 'وفاء', 'سلوى', 'جميلة', 'مريم',
  'خديجة', 'زينب', 'فاطمة', 'رقية', 'سعدى', 'نجلاء', 'أروى', 'شيماء', 'منى', 'نسرين',
] as const;

export const GROOM_PLAN: PlanSpec = {
  key: 'groom',
  owner: 'groom',
  persona: WeddingPersona.GROOM,
  title: 'عرس محمد',
  weddingDate: day(WEDDING_DAY),
  budget: 7_000_000,
  items: [
    groomMahrItem(),
    ...moneyItems({
      hall: 'القاعة',
      hallProvider: 'قاعة سبأ',
      hallKey: 'hall',
      qat: 'القات',
      artist: 'الفنان والفرقة',
      outfit: 'بدلة العريس',
      lunchParty: 'أبو علي',
      owner: CostPayer.GROOM,
      family: 'الوالد',
    }),
  ],
  funding: funding({
    father: 'دعم الوالد',
    friend: 'صاحبي عادل',
    savings: 4_500_000,
    family: 2_400_000,
  }),
  tasks: [
    // Open: one late, three this week, four later (8 of 20 are open).
    {
      key: 'contract-date',
      title: 'حدد موعد عقد القران',
      done: false,
      dueDate: inDays(-7),
      priority: WeddingTaskPriority.HIGH,
      checklist: [
        { title: 'اتفق مع الوالد على اليوم', done: true },
        { title: 'كلّم الأمين الشرعي', done: false },
        { title: 'بلّغ أهل العروسة', done: false },
      ],
    },
    { key: 'pick-photographer', title: 'اختر المصور', done: false, dueDate: inDays(3), priority: WeddingTaskPriority.HIGH, linkedItem: 'photo' },
    { key: 'hall-payment', title: 'ادفع دفعة القاعة', done: false, dueDate: inDays(2), description: '500,000 ر.ي', priority: WeddingTaskPriority.HIGH, linkedPayment: { cost: 'hall', schedule: 'hall-s2' } },
    { key: 'lunch', title: 'رتّب الغداء', done: false, dueDate: inDays(3), assignee: 'helperSaleh', description: 'أبو علي' },
    { key: 'dowry-rest', title: 'سلّم باقي المهر', done: false, dueDate: inDays(21), description: 'لأهل العروسة', priority: WeddingTaskPriority.HIGH, linkedPayment: { cost: 'mahr', schedule: 'mahr-rest' } },
    {
      key: 'contract-papers',
      title: 'جهّز أوراق العقد',
      done: false,
      dueDate: inDays(9),
      checklist: [
        { title: 'بطاقتك الشخصية', done: true },
        { title: 'شاهدين ومعهم بطاقاتهم', done: false },
        { title: 'المهر كما اتفقتوا', done: false },
        { title: 'اللي بتسلّمه يوم العقد', done: false },
      ],
    },
    { key: 'wedding-cars', title: 'حجز سيارات الزفة', done: false, dueDate: inDays(30), responsibleName: 'الوالد' },
    {
      key: 'fireworks',
      title: 'الألعاب النارية',
      done: false,
      dueDate: day(WEDDING_DAY),
      description: 'ليلة الزفاف · قدام البيت',
    },
    // Done (12).
    { key: 'd-hall', title: 'احجز القاعة', done: true, dueDate: inDays(-60) },
    { key: 'd-budget', title: 'حدد ميزانية العرس وقسّمها على البنود', done: true, dueDate: inDays(-70) },
    { key: 'd-dowry', title: 'الاتفاق مع أهل العروسة على المهر والشرط', done: true, dueDate: inDays(-50) },
    { key: 'd-gold', title: 'شراء الشبكة والذهب', done: true, dueDate: inDays(-40), responsibleName: 'الوالد' },
    { key: 'd-guests', title: 'ابدأ قائمة الضيوف', done: true, dueDate: inDays(-45) },
    { key: 'd-hospitality', title: 'احجز ضيافة الأصالة', done: true, dueDate: inDays(-65) },
    { key: 'd-photo-offers', title: 'اطلب عروض التصوير', done: true, dueDate: inDays(-12) },
    { key: 'd-qat', title: 'اطلب القات من مقوّتين', done: true, dueDate: inDays(-5) },
    { key: 'd-suit', title: 'تفصيل بدلة العريس', done: true, dueDate: inDays(-30), assignee: 'helperSaleh', createdByMember: 'helperSaleh' },
    { key: 'd-father-day', title: 'اتفق مع الوالد على يوم العقد', done: true, dueDate: inDays(-14) },
    { key: 'd-hall-deposit', title: 'سجّل عربون القاعة', done: true, dueDate: inDays(-46) },
    { key: 'd-date', title: 'حدد موعد العرس', done: true, dueDate: inDays(-80), assignee: 'helperSaleh', createdByMember: 'helperSaleh' },
  ],
  guestGroups: [
    {
      key: 'hamdi', name: 'آل الحمدي', side: GuestSide.GROOM, total: 38, confirmed: 30, pending: 4,
      firstNames: MALE_FIRST.slice(0, 20), surnames: ['الحمدي'],
      featured: [
        { name: 'عبدالله الحمدي', companions: 1, attendance: 'CONFIRMED' },
        { name: 'خالد الحمدي', attendance: 'CONFIRMED' },
        { name: 'أحمد الحمدي', attendance: 'CONFIRMED' },
        { name: 'علي الحمدي', attendance: 'CONFIRMED' },
        { name: 'هاني الحمدي', attendance: 'CONFIRMED' },
      ],
    },
    {
      key: 'saqqaf', name: 'آل السقاف', side: GuestSide.BRIDE, total: 22, confirmed: 14, pending: 4,
      firstNames: MALE_FIRST.slice(5, 25), surnames: ['السقاف'],
    },
    {
      key: 'work', name: 'زملاء العمل', side: GuestSide.FRIEND, total: 24, confirmed: 18, pending: 3,
      firstNames: MALE_FIRST.slice(8, 28), surnames: ['المطري', 'الأكوع', 'العمري', 'الشامي'],
    },
    {
      key: 'friends', name: 'الأصحاب', side: GuestSide.FRIEND, total: 28, confirmed: 16, pending: 6,
      firstNames: MALE_FIRST, surnames: ['الأهدل', 'السنيدار', 'القاضي', 'الريمي', 'العزي'],
      featured: [
        { name: 'ياسر الأهدل', attendance: 'DECLINED' },
        { name: 'يحيى السنيدار', attendance: 'PENDING' },
        { name: 'عادل الريمي', attendance: 'CONFIRMED' },
      ],
    },
    {
      key: 'neighbours', name: 'الجيران', side: GuestSide.OTHER, total: 12, confirmed: 8, pending: 3,
      firstNames: MALE_FIRST.slice(10, 30), surnames: ['الصبري', 'الكبسي', 'الوزير'],
    },
  ],
  members: [
    {
      account: 'helperSaleh', role: SharedMemberRole.HELPER,
      canViewMoney: false, canEditPlan: false, canManageTasks: true, canManageGuests: true,
      canManageProviders: true, canInviteMembers: false, canManageMoney: false,
    },
    {
      account: 'viewerFather', role: SharedMemberRole.VIEWER,
      canViewMoney: false, canEditPlan: false, canManageTasks: false, canManageGuests: false,
      canManageProviders: false, canInviteMembers: false, canManageMoney: false,
    },
    {
      account: 'bride', role: SharedMemberRole.FAMILY,
      canViewMoney: false, canEditPlan: false, canManageTasks: true, canManageGuests: true,
      canManageProviders: false, canInviteMembers: false, canManageMoney: false,
    },
  ],
  conversations: ['hall', 'hospitality', 'lens', 'studio', 'qat1', 'qat2'],
};

export const BRIDE_PLAN: PlanSpec = {
  key: 'bride',
  owner: 'bride',
  persona: WeddingPersona.BRIDE,
  title: 'عرس سلمى',
  weddingDate: day(WEDDING_DAY),
  budget: 7_000_000,
  items: moneyItems({
    hall: 'الصالة',
    hallProvider: 'صالة الياسمين',
    hallKey: 'yasmine',
    qat: 'البخور',
    artist: 'المزينة والنقاشة',
    outfit: 'فستان الزفة',
    lunchParty: 'أم فدوى',
    owner: CostPayer.BRIDE,
    family: 'أبوي',
  }).map((item) =>
    // Her hospitality is the same caterer the groom booked.
    item.key === 'hospitality' && item.cost
      ? { ...item, cost: { ...item.cost, offerKey: 'hospitalityBride' } }
      : item,
  ),
  // c05: «وصلك 4.5 مليون» (the mahr 2, her savings 900 thousand, her
  // mother's support a million, her uncle's loan 600 thousand) and «موعود
  // لك 2.2» (the mahr's rest a million, her friend 1.2).
  funding: [
    ...brideMahrFunding(),
    ...funding({
      father: 'دعم الوالدة',
      friend: 'صاحبتي عبلة',
      savings: 900_000,
      family: 1_000_000,
    }),
  ],
  tasks: [
    {
      key: 'contract-date', title: 'حددي موعد عقد القران', done: false, dueDate: inDays(-7),
      priority: WeddingTaskPriority.HIGH,
      checklist: [
        { title: 'اتفقي مع الوالدة على اليوم', done: true },
        { title: 'كلّمي الأمين الشرعي', done: false },
        { title: 'بلّغي أهل العريس', done: false },
      ],
    },
    { key: 'pick-photographer', title: 'اختاري المصورة', done: false, dueDate: inDays(3), priority: WeddingTaskPriority.HIGH, linkedItem: 'photo' },
    { key: 'hall-payment', title: 'ادفعي دفعة الصالة', done: false, dueDate: inDays(2), description: '500,000 ر.ي', priority: WeddingTaskPriority.HIGH, linkedPayment: { cost: 'hall', schedule: 'hall-s2' } },
    { key: 'lunch', title: 'رتّبي الغداء', done: false, dueDate: inDays(3), assignee: 'helperNora', description: 'أم فدوى' },
    { key: 'dowry-rest', title: 'استلمي باقي المهر', done: false, dueDate: inDays(21), description: 'من أهل العريس' },
    {
      key: 'contract-papers', title: 'جهّزي أوراق العقد', done: false, dueDate: inDays(9),
      checklist: [
        { title: 'بطاقتك الشخصية', done: true },
        { title: 'شاهدين ومعهم بطاقاتهم', done: false },
        { title: 'بطاقة الولي', done: false },
      ],
    },
    { key: 'wedding-cars', title: 'حجز سيارة الزفة', done: false, dueDate: inDays(30), responsibleName: 'الوالدة' },
    { key: 'dress-fitting', title: 'بروفة فستان الزفة', done: false, dueDate: inDays(40), assignee: 'helperNora' },
    { key: 'd-hall', title: 'احجزي الصالة', done: true, dueDate: inDays(-60) },
    { key: 'd-budget', title: 'حددي ميزانية العرس وقسّميها على البنود', done: true, dueDate: inDays(-70) },
    { key: 'd-dowry', title: 'الاتفاق مع أهل العريس على المهر والشرط', done: true, dueDate: inDays(-50) },
    { key: 'd-gold', title: 'اختيار الشبكة والذهب', done: true, dueDate: inDays(-40), responsibleName: 'الوالدة' },
    { key: 'd-guests', title: 'ابدئي قائمة الضيفات', done: true, dueDate: inDays(-45) },
    { key: 'd-hospitality', title: 'احجزي ضيافة الأصالة', done: true, dueDate: inDays(-65) },
    { key: 'd-photo-offers', title: 'اطلبي عروض التصوير', done: true, dueDate: inDays(-12) },
    { key: 'd-incense', title: 'اطلبي البخور من العطّار', done: true, dueDate: inDays(-5) },
    { key: 'd-dress', title: 'اختاري فستان الزفة', done: true, dueDate: inDays(-30), assignee: 'helperNora', createdByMember: 'helperNora' },
    { key: 'd-mother-day', title: 'اتفقي مع الوالدة على يوم العقد', done: true, dueDate: inDays(-14) },
    { key: 'd-hall-deposit', title: 'سجّلي عربون الصالة', done: true, dueDate: inDays(-46) },
    { key: 'd-date', title: 'حددي موعد العرس', done: true, dueDate: inDays(-80), assignee: 'helperNora', createdByMember: 'helperNora' },
  ],
  guestGroups: [
    {
      key: 'saqqaf', name: 'آل السقاف', side: GuestSide.BRIDE, total: 38, confirmed: 30, pending: 4,
      firstNames: FEMALE_FIRST.slice(0, 20), surnames: ['السقاف'],
    },
    {
      key: 'hamdi', name: 'آل الحمدي', side: GuestSide.GROOM, total: 22, confirmed: 14, pending: 4,
      firstNames: FEMALE_FIRST.slice(5, 25), surnames: ['الحمدي'],
      featured: [
        { name: 'أسماء الحمدي', attendance: 'CONFIRMED' },
        { name: 'علياء الحمدي', attendance: 'CONFIRMED' },
        { name: 'هناء الحمدي', attendance: 'CONFIRMED' },
      ],
    },
    {
      key: 'work', name: 'زميلات العمل', side: GuestSide.FRIEND, total: 24, confirmed: 18, pending: 3,
      firstNames: FEMALE_FIRST.slice(8, 28), surnames: ['المطري', 'الأكوع', 'العمري', 'الشامي'],
    },
    {
      key: 'friends', name: 'الصاحبات', side: GuestSide.FRIEND, total: 28, confirmed: 16, pending: 6,
      firstNames: FEMALE_FIRST, surnames: ['الأهدل', 'السنيدار', 'القاضي', 'الريمي', 'العزي'],
      featured: [
        { name: 'يسرى الأهدل', attendance: 'DECLINED' },
        { name: 'عبير الحمدي', companions: 1, attendance: 'CONFIRMED' },
      ],
    },
    {
      key: 'neighbours', name: 'الجارات', side: GuestSide.OTHER, total: 12, confirmed: 8, pending: 3,
      firstNames: FEMALE_FIRST.slice(10, 30), surnames: ['الصبري', 'الكبسي', 'الوزير'],
    },
  ],
  members: [
    {
      account: 'helperNora', role: SharedMemberRole.HELPER,
      canViewMoney: false, canEditPlan: false, canManageTasks: true, canManageGuests: true,
      canManageProviders: true, canInviteMembers: false, canManageMoney: false,
    },
    {
      account: 'viewerMother', role: SharedMemberRole.VIEWER,
      canViewMoney: false, canEditPlan: false, canManageTasks: false, canManageGuests: false,
      canManageProviders: false, canInviteMembers: false, canManageMoney: false,
    },
    {
      account: 'groom', role: SharedMemberRole.GROOM,
      canViewMoney: true, canEditPlan: true, canManageTasks: true, canManageGuests: true,
      canManageProviders: true, canInviteMembers: false, canManageMoney: true,
    },
  ],
  conversations: ['yasmine', 'hospitalityBride', 'studioBride'],
};
