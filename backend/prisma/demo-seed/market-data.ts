// The marketplace side of the demo: providers, what customers asked them and
// what they answered. Names and numbers come from the groom, bride, provider
// and admin prototypes.
import {
  BookingStatus,
  ProviderReviewEventKind,
  ProviderReviewField,
  ProviderStatus,
  QuoteOfferStatus,
  QuoteRequestStatus,
} from '@prisma/client';
import type { DemoAccountKey } from './accounts';
import { day, demoUuid, hoursAgo, inDays } from './support';

/**
 * One step of a provider's review history (B-01, B-02), `daysAgo` before the
 * seed runs. Administrator steps are Nadia's (operations); RESUBMITTED and
 * REOPENED are the provider's own.
 */
export interface ReviewStepSpec {
  kind: ProviderReviewEventKind;
  daysAgo: number;
  notes?: Array<{ field: ProviderReviewField; note: string }>;
}

export interface ServiceSpec {
  /** Fixed id (only for the studio, whose service rows already exist locally). */
  id?: string;
  key: string;
  title: string;
  description: string;
  price: number;
  unit: 'event' | 'package';
  packageItems?: string[];
}

export interface ProviderSpec {
  key: string;
  /** Fixed id (only for the studio, taken over from the earlier ad-hoc rows). */
  id?: string;
  owner?: DemoAccountKey;
  city: string;
  categorySlug: string;
  businessName: string;
  ownerName: string;
  phone: string;
  description: string;
  address: string;
  status: ProviderStatus;
  /**
   * The review history, oldest first. Without it, an owned provider that
   * was decided has one approval 30 days ago; a listing nobody claimed has
   * none.
   */
  review?: ReviewStepSpec[];
  verified?: boolean;
  /**
   * A featured placement the back office recorded (B-43): its first and
   * last day as offsets from today, and the note. `told` marks the end
   * notice as sent (a placement that already ended).
   */
  featured?: { firstDay: number; lastDay: number; note: string; told?: boolean };
  /** B-20: confirmed bookings he takes on one day (1 without it). */
  dailyBookingCapacity?: number;
  services: ServiceSpec[];
}

export const providerId = (spec: Pick<ProviderSpec, 'key' | 'id'>): string =>
  spec.id ?? demoUuid(`provider:${spec.key}`);
export const serviceId = (provider: ProviderSpec, service: ServiceSpec): string =>
  service.id ?? demoUuid(`service:${provider.key}:${service.key}`);
export const requestId = (key: string): string => demoUuid(`request:${key}`);
export const offerId = (key: string): string => demoUuid(`offer:${key}`);

export const STUDIO_ID = 'f0300000-0000-4000-8000-000000000001';

export const PROVIDERS: readonly ProviderSpec[] = [
  {
    key: 'studio',
    id: STUDIO_ID,
    owner: 'providerStudio',
    city: 'صنعاء',
    categorySlug: 'photography',
    businessName: 'استوديو ضوء صنعاء',
    ownerName: 'علي الشامي',
    phone: '+967777000201',
    description: 'استوديو تصوير أعراس بثلاثة فرق رجال وفريق مصوّرات لحفلات النساء. تسليم الصور والفيلم خلال 30 يوم.',
    address: 'شارع الزبيري، صنعاء',
    status: ProviderStatus.ACTIVE,
    verified: true,
    // a17: its month ended ten days ago and he was told.
    featured: { firstDay: -40, lastDay: -11, note: 'حوالة الكريمي · شهر', told: true },
    services: [
      {
        id: 'f0300000-0000-4000-8000-000000000011',
        key: 'photos',
        title: 'صور فقط',
        description: 'مصور واحد وتغطية كاملة لليلة الزفة.',
        price: 350_000,
        unit: 'package',
        packageItems: ['مصور واحد', '300 صورة معدّلة'],
      },
      {
        id: 'f0300000-0000-4000-8000-000000000012',
        key: 'photos-video',
        title: 'صور وفيديو',
        description: 'مصورين اثنين مع فيلم وألبوم مطبوع.',
        price: 550_000,
        unit: 'package',
        packageItems: ['مصورين', '300 صورة', 'فيلم 10 دقائق', 'ألبوم مطبوع'],
      },
    ],
  },
  {
    key: 'hall',
    owner: 'providerHall',
    city: 'صنعاء',
    categorySlug: 'wedding-halls',
    businessName: 'قاعة سبأ',
    ownerName: 'أمجد الحيمي',
    phone: '+967777000202',
    description: 'قاعة أفراح تتسع 150 ضيف مع تجهيزات الصوت والإضاءة.',
    address: 'شارع الستين، صنعاء',
    status: ProviderStatus.ACTIVE,
    verified: true,
    // a17: featured now, for three months.
    featured: { firstDay: -24, lastDay: 66, note: 'كاش · 3 شهور' },
    services: [
      {
        key: 'hall',
        title: 'حجز قاعة زفاف',
        description: 'قاعة رئيسية تتسع 150 ضيف.',
        price: 2_000_000,
        unit: 'event',
        packageItems: ['القاعة', 'الصوت والإضاءة', 'تنسيق الطاولات'],
      },
    ],
  },
  {
    key: 'hospitality',
    // A provider who confirmed bookings has an account (D60: no booked
    // provider reads «غير مفعّل» in «استكشف»).
    owner: 'providerHospitality',
    city: 'صنعاء',
    // The production catalog's «وجبات» (migration 20260729050000).
    categorySlug: 'catering',
    businessName: 'ضيافة الأصالة',
    ownerName: 'عبدالرحمن الأصبحي',
    phone: '+967777000501',
    description: 'ضيافة وعشاء للأعراس بالمأكولات اليمنية.',
    address: 'حدة، صنعاء',
    status: ProviderStatus.ACTIVE,
    // B-20: two kitchens, so Mohammed's and Salma's nights of 21 January
    // are both confirmed (and the day is full).
    dailyBookingCapacity: 2,
    services: [
      {
        key: 'dinner',
        title: 'ضيافة وعشاء',
        description: 'عشاء وضيافة لـ 150 ضيف.',
        price: 1_600_000,
        unit: 'event',
        packageItems: ['العشاء', 'الضيافة', 'الخدمة'],
      },
    ],
  },
  {
    key: 'lens',
    city: 'صنعاء',
    categorySlug: 'photography',
    businessName: 'عدسة سبأ',
    ownerName: 'نبيل المقطري',
    phone: '+967777000502',
    description: 'تصوير وفيلم أعراس.',
    address: 'السبعين، صنعاء',
    status: ProviderStatus.ACTIVE,
    services: [
      {
        key: 'photos',
        title: 'مصور واحد',
        description: 'مصور واحد وفيلم قصير.',
        price: 480_000,
        unit: 'package',
        packageItems: ['مصور واحد', 'فيلم 5 دقائق'],
      },
    ],
  },
  {
    key: 'qat1',
    city: 'صنعاء',
    categorySlug: 'qat',
    businessName: 'مقوّت أبو حسن',
    ownerName: 'أبو حسن',
    phone: '+967777000503',
    description: 'قات المقيل للأعراس بالكمية.',
    address: 'سوق الملح، صنعاء',
    status: ProviderStatus.ACTIVE,
    services: [
      { key: 'qat', title: 'قات المقيل', description: 'قات للمقيل والسمرة.', price: 900_000, unit: 'event' },
    ],
  },
  {
    key: 'qat2',
    city: 'صنعاء',
    categorySlug: 'qat',
    businessName: 'قات الريان',
    ownerName: 'ياسين الريان',
    phone: '+967777000504',
    description: 'قات مختار للأعراس.',
    address: 'شعوب، صنعاء',
    status: ProviderStatus.ACTIVE,
    services: [
      { key: 'qat', title: 'قات المقيل', description: 'قات للمقيل والسمرة.', price: 950_000, unit: 'event' },
    ],
  },
  {
    key: 'yasmine',
    owner: 'providerYasmine',
    city: 'صنعاء',
    categorySlug: 'wedding-halls',
    businessName: 'صالة الياسمين',
    ownerName: 'هدى المتوكل',
    phone: '+967777000505',
    description: 'صالة نسائية تتسع 150 ضيفة.',
    address: 'شارع حدة، صنعاء',
    status: ProviderStatus.ACTIVE,
    services: [
      { key: 'hall', title: 'حجز الصالة', description: 'صالة نسائية رئيسية.', price: 2_000_000, unit: 'event' },
    ],
  },
  {
    key: 'harah',
    city: 'صنعاء',
    categorySlug: 'photography',
    businessName: 'مصور الحارة',
    ownerName: 'مصور الحارة',
    phone: '+967777000506',
    description: 'ملف بلا حساب أضافته الإدارة.',
    address: 'صنعاء',
    status: ProviderStatus.ACTIVE,
    services: [
      { key: 'photos', title: 'تصوير حفلات', description: 'تصوير حفلات الحارة.', price: 250_000, unit: 'package' },
    ],
  },
  // G40: f02 draws these under «فنانين وفرق» (groom) and «مزينات ونقاشات»
  // (bride); the search from «الفنان والفرقة» and «المزينة والنقاشة» finds
  // them. «صالون لمسة» is left out: a salon's offer files under the
  // makeup-and-hair item, not the نقاشة's.
  {
    key: 'afrah',
    owner: 'providerAfrah',
    city: 'صنعاء',
    categorySlug: 'mabra',
    businessName: 'فرقة الأفراح',
    ownerName: 'عبده الوصابي',
    phone: '+967777000207',
    description: 'فرقة برع وزفة للأعراس في صنعاء.',
    address: 'حدة، صنعاء',
    status: ProviderStatus.ACTIVE,
    verified: true,
    services: [
      { key: 'bara', title: 'فرقة برع', description: 'برع الزفة من البيت لين القاعة.', price: 350_000, unit: 'event' },
      { key: 'full', title: 'فرقة كاملة', description: 'برع وطبل ومزمار للّيلة كلها.', price: 450_000, unit: 'event' },
    ],
  },
  {
    key: 'ayman',
    city: 'صنعاء',
    categorySlug: 'male-singer',
    businessName: 'الفنان أيمن القاضي',
    ownerName: 'أيمن القاضي',
    phone: '+967777000507',
    description: 'فنان أعراس صنعاني.',
    address: 'الأصبحي، صنعاء',
    status: ProviderStatus.ACTIVE,
    services: [
      { key: 'night', title: 'سهرة العرس', description: 'فنان مع عازفين.', price: 500_000, unit: 'event' },
      { key: 'full', title: 'السهرة والزفة', description: 'السهرة وزفة العريس.', price: 700_000, unit: 'event' },
    ],
  },
  {
    key: 'ummFahd',
    owner: 'providerUmmFahd',
    city: 'صنعاء',
    categorySlug: 'henna',
    businessName: 'المزينة أم فهد',
    ownerName: 'أم فهد',
    phone: '+967777000208',
    description: 'مزينة ونقاشة للعروسة في البيت.',
    address: 'الأصبحي، صنعاء',
    status: ProviderStatus.ACTIVE,
    services: [
      { key: 'naqsh', title: 'نقش الحناء', description: 'نقش الحناء لليلة النقش.', price: 500_000, unit: 'event' },
      { key: 'full', title: 'النقش والتزيين', description: 'النقش وتزيين العروسة يوم العرس.', price: 700_000, unit: 'event' },
    ],
  },
  {
    key: 'suspended',
    city: 'عدن',
    categorySlug: 'photography',
    businessName: 'مصور س',
    ownerName: 'سامي',
    phone: '+967777000507',
    description: 'مزود موقوف بعد بلاغات تأخير تسليم.',
    address: 'كريتر، عدن',
    status: ProviderStatus.SUSPENDED,
    review: [
      {
        kind: ProviderReviewEventKind.SUSPENDED,
        daysAgo: 30,
        notes: [{ field: ProviderReviewField.GENERAL, note: 'أُوقف بعد 3 بلاغات تأخير تسليم.' }],
      },
    ],
    services: [
      { key: 'photos', title: 'تصوير أعراس', description: 'تصوير أعراس في عدن.', price: 300_000, unit: 'package' },
    ],
  },
  {
    key: 'pending',
    owner: 'providerPending',
    city: 'ذمار',
    categorySlug: 'mabra',
    businessName: 'فرقة الأمجاد للبرع',
    ownerName: 'صالح العزي',
    phone: '+967777000203',
    description: 'فرقة برع للأعراس، عرس واحد في الفترة.',
    address: 'ذمار',
    status: ProviderStatus.PENDING,
    services: [
      { key: 'bara', title: 'برع الزفة', description: 'فرقة من ثمانية.', price: 400_000, unit: 'event' },
    ],
  },
  {
    key: 'needsChanges',
    owner: 'providerNeedsChanges',
    city: 'صنعاء',
    categorySlug: 'clothing',
    businessName: 'محلات الأناقة',
    ownerName: 'منصور الحداد',
    phone: '+967777000204',
    description: 'بيع وتفصيل ملابس العريس.',
    address: 'باب اليمن، صنعاء',
    status: ProviderStatus.NEEDS_CHANGES,
    // a04/p09: a note on two fields, written yesterday.
    review: [
      {
        kind: ProviderReviewEventKind.CHANGES_REQUESTED,
        daysAgo: 1,
        notes: [
          { field: ProviderReviewField.DESCRIPTION, note: 'اكتب وش تبيع بالضبط: تفصيل أو جاهز، وللعريس بس أو للأهل كمان.' },
          { field: ProviderReviewField.SERVICE, note: 'اكتب ايش يشمل سعر الثوب: القماش والتفصيل والتسليم.' },
        ],
      },
    ],
    services: [
      { key: 'thawb', title: 'ثوب أبيض', description: 'تفصيل ثوب أبيض.', price: 45_000, unit: 'package' },
    ],
  },
  {
    key: 'resubmitted',
    owner: 'providerResubmitted',
    city: 'صنعاء',
    categorySlug: 'mabra',
    businessName: 'فرقة النجوم للمزمار',
    ownerName: 'فارس الوصابي',
    phone: '+967777000206',
    description: 'مزمار وطبل للأعراس في صنعاء.',
    address: 'شارع الزبيري، صنعاء',
    status: ProviderStatus.PENDING,
    // a03 «أُعيد إرسالها»: asked for changes 2 days ago, fixed and sent today.
    review: [
      {
        kind: ProviderReviewEventKind.CHANGES_REQUESTED,
        daysAgo: 2,
        notes: [
          { field: ProviderReviewField.BUSINESS_NAME, note: 'اكتب الاسم اللي يعرفك فيه الناس.' },
          { field: ProviderReviewField.SERVICE, note: 'حدد سعر الليلة بدل «حسب الطلب».' },
        ],
      },
      { kind: ProviderReviewEventKind.RESUBMITTED, daysAgo: 0 },
    ],
    services: [
      { key: 'mizmar', title: 'مزمار الليلة', description: 'مزمار وطبلين من العصر لين الزفة.', price: 150_000, unit: 'event' },
    ],
  },
  {
    key: 'rejected',
    owner: 'providerRejected',
    city: 'عدن',
    categorySlug: 'hair-styling',
    businessName: 'كوافيرة أم ريان',
    ownerName: 'أم ريان',
    phone: '+967777000205',
    description: 'كوافيرة من البيت.',
    address: 'المنصورة، عدن',
    status: ProviderStatus.REJECTED,
    // p11: refused with a reason she can fix; «قدّم من جديد» reopens it (B-02).
    review: [
      {
        kind: ProviderReviewEventKind.REJECTED,
        daysAgo: 3,
        notes: [{ field: ProviderReviewField.GENERAL, note: 'ما وضّحتي وين تشتغلين ولا ايش تشمل التسريحة. وضّحيها وقدّمي من جديد.' }],
      },
    ],
    services: [
      { key: 'hair', title: 'تسريحة عروس', description: 'تسريحة عروس.', price: 60_000, unit: 'package' },
    ],
  },
];

export interface MessageSpec {
  from: 'customer' | 'provider';
  body: string;
  at: Date;
  /** Provider messages the customer has not opened yet. */
  unread?: boolean;
}

export interface RequestSpec {
  key: string;
  provider: string;
  customer: DemoAccountKey;
  /** The customer's plan (plan conversation) or none (account conversation). */
  plan?: 'groom' | 'bride';
  /**
   * A plan has one conversation per provider: a later request to the same
   * provider names the earlier request (seeded first) whose conversation it joins.
   */
  conversationOf?: string;
  status: QuoteRequestStatus;
  eventDate: Date;
  guestCount?: number;
  message: string;
  createdAt: Date;
  /** B-08: what the customer chose to show the provider (nothing by default). */
  budget?: { min: number; max: number };
  shareBudget?: boolean;
  shareContact?: boolean;
  /** B-04: when the hourly job ended it, for a request nobody answered (EXPIRED). */
  expiredAt?: Date;
  offer?: {
    title: string;
    message: string;
    amount: number;
    validUntil: Date;
    status: QuoteOfferStatus;
    /** B-06: version 1 as first sent, when the offer above is version 2. */
    firstVersion?: { title?: string; message?: string; amount?: number; revisedAt: Date };
    /** B-03: when the provider took it back (status WITHDRAWN). */
    withdrawnAt?: Date;
  };
  booking?: { date: Date; status: BookingStatus; note?: string };
  messages?: MessageSpec[];
}

const WEDDING_DAY = day('2027-01-21');

export const REQUESTS: readonly RequestSpec[] = [
  // ---------------------------------------------------------------- groom
  {
    key: 'hall',
    provider: 'hall',
    customer: 'groom',
    plan: 'groom',
    status: QuoteRequestStatus.ACCEPTED,
    eventDate: WEDDING_DAY,
    guestCount: 150,
    message: 'نشتي نحجز القاعة يوم 21 يناير لـ 150 ضيف.',
    createdAt: day('2026-08-28'),
    offer: {
      title: 'حجز قاعة زفاف',
      message: 'القاعة مع الصوت والإضاءة وتنسيق الطاولات.',
      amount: 2_000_000,
      validUntil: day('2026-09-12'),
      status: QuoteOfferStatus.ACCEPTED,
    },
    booking: { date: WEDDING_DAY, status: BookingStatus.CONFIRMED },
    messages: [
      { from: 'customer', body: 'السلام عليكم، نشتي نحجز القاعة يوم 21 يناير لـ 150 ضيف', at: day('2026-08-28') },
      { from: 'provider', body: 'وعليكم السلام، تم تثبيت الحجز ليلة الخميس 21 يناير.', at: day('2026-09-10') },
      { from: 'provider', body: 'نأكد عدد المقاعد قبل شهر', at: hoursAgo(30), unread: true },
    ],
  },
  {
    key: 'hospitality',
    provider: 'hospitality',
    customer: 'groom',
    plan: 'groom',
    status: QuoteRequestStatus.ACCEPTED,
    eventDate: WEDDING_DAY,
    guestCount: 150,
    message: 'نشتي ضيافة وعشاء ليلة 21 يناير.',
    createdAt: day('2026-08-05'),
    offer: {
      title: 'ضيافة وعشاء',
      message: 'عشاء وضيافة لـ 150 ضيف.',
      amount: 1_600_000,
      validUntil: day('2026-08-20'),
      status: QuoteOfferStatus.ACCEPTED,
    },
    booking: { date: WEDDING_DAY, status: BookingStatus.CONFIRMED },
  },
  {
    key: 'lens',
    provider: 'lens',
    customer: 'groom',
    plan: 'groom',
    status: QuoteRequestStatus.RESPONDED,
    eventDate: WEDDING_DAY,
    guestCount: 124,
    message: 'نشتي تصوير زفاف يوم 21 يناير.',
    createdAt: inDays(-4),
    offer: {
      title: 'مصور واحد',
      message: 'مصور واحد · فيلم 5 دقائق.',
      amount: 480_000,
      validUntil: inDays(10),
      status: QuoteOfferStatus.PENDING,
    },
  },
  {
    key: 'studio',
    provider: 'studio',
    customer: 'groom',
    plan: 'groom',
    status: QuoteRequestStatus.RESPONDED,
    eventDate: WEDDING_DAY,
    guestCount: 124,
    message: 'نشتي تصوير زفاف يوم 21 يناير في قاعة سبأ.',
    createdAt: inDays(-5),
    offer: {
      title: 'صور وفيديو',
      message: 'مصورين · فيلم 10 دقائق · ألبوم مطبوع.',
      amount: 550_000,
      validUntil: inDays(8),
      status: QuoteOfferStatus.PENDING,
      // f06: «نسخة 2 · أضافوا الألبوم بنفس السعر» (B-06).
      firstVersion: { message: 'مصورين · فيلم 10 دقائق.', revisedAt: hoursAgo(100) },
    },
    messages: [
      { from: 'customer', body: 'السلام عليكم، نشتي تصوير زفاف يوم 21 يناير في قاعة سبأ', at: hoursAgo(120) },
      { from: 'provider', body: 'وعليكم السلام، مبروك مقدمًا. اليوم فاضي عندنا، أرسلنا لك العرض', at: hoursAgo(119) },
      { from: 'customer', body: 'ممكن تضيفون تصوير جوي؟', at: hoursAgo(118), },
    ],
  },
  {
    key: 'qat1',
    provider: 'qat1',
    customer: 'groom',
    plan: 'groom',
    status: QuoteRequestStatus.SENT,
    eventDate: WEDDING_DAY,
    message: 'نشتي قات للمقيل يوم 21 يناير.',
    createdAt: inDays(-1),
  },
  {
    key: 'qat2',
    provider: 'qat2',
    customer: 'groom',
    plan: 'groom',
    status: QuoteRequestStatus.SENT,
    eventDate: WEDDING_DAY,
    message: 'نشتي قات للمقيل يوم 21 يناير.',
    createdAt: inDays(-1),
  },
  // x09 «انتهى بدون رد» (B-04): the hall never answered about the samra night.
  {
    key: 'hallSamra',
    provider: 'hall',
    customer: 'groom',
    plan: 'groom',
    conversationOf: 'hall',
    status: QuoteRequestStatus.EXPIRED,
    eventDate: day('2027-01-20'),
    guestCount: 80,
    message: 'نشتي القاعة للسمرة ليلة 20 يناير.',
    createdAt: inDays(-9),
    expiredAt: inDays(-2),
  },
  // ---------------------------------------------------------------- bride
  {
    key: 'yasmine',
    provider: 'yasmine',
    customer: 'bride',
    plan: 'bride',
    status: QuoteRequestStatus.ACCEPTED,
    eventDate: WEDDING_DAY,
    guestCount: 150,
    message: 'نشتي نحجز الصالة يوم 21 يناير.',
    createdAt: day('2026-08-28'),
    offer: {
      title: 'حجز الصالة',
      message: 'الصالة مع التجهيزات.',
      amount: 2_000_000,
      validUntil: day('2026-09-12'),
      status: QuoteOfferStatus.ACCEPTED,
    },
    booking: { date: WEDDING_DAY, status: BookingStatus.CONFIRMED },
  },
  {
    key: 'hospitalityBride',
    provider: 'hospitality',
    customer: 'bride',
    plan: 'bride',
    status: QuoteRequestStatus.ACCEPTED,
    eventDate: WEDDING_DAY,
    guestCount: 150,
    message: 'نشتي ضيافة وعشاء ليلة 21 يناير.',
    createdAt: day('2026-08-05'),
    offer: {
      title: 'ضيافة وعشاء',
      message: 'عشاء وضيافة لـ 150 ضيفة.',
      amount: 1_600_000,
      validUntil: day('2026-08-20'),
      status: QuoteOfferStatus.ACCEPTED,
    },
    // An accepted offer is «اخترت · اطلبي الحجز» until the provider
    // confirms (D60); the hospitality takes two weddings a day (B-20).
    booking: { date: WEDDING_DAY, status: BookingStatus.CONFIRMED },
  },
  {
    key: 'studioBride',
    provider: 'studio',
    customer: 'bride',
    plan: 'bride',
    status: QuoteRequestStatus.SENT,
    eventDate: WEDDING_DAY,
    guestCount: 124,
    message: 'نشتي مصورات لحفلة النساء يوم 21 يناير (فريق نساء).',
    createdAt: hoursAgo(10),
  },
  // x09 «سحب عرضه» (B-03): the studio sent an offer for the henna night and
  // took it back; the request waits for its answer again.
  {
    key: 'studioHenna',
    provider: 'studio',
    customer: 'bride',
    plan: 'bride',
    conversationOf: 'studioBride',
    status: QuoteRequestStatus.VIEWED,
    eventDate: day('2027-01-19'),
    guestCount: 60,
    message: 'نشتي مصورة لليلة الحناء 19 يناير.',
    createdAt: hoursAgo(40),
    offer: {
      title: 'تصوير ليلة الحناء',
      message: 'مصورة · 200 صورة معدّلة.',
      amount: 300_000,
      validUntil: inDays(9),
      status: QuoteOfferStatus.WITHDRAWN,
      withdrawnAt: hoursAgo(6),
    },
  },
  // ------------------------------------------------- other customers (studio)
  {
    key: 'adel',
    provider: 'studio',
    customer: 'customerAdel',
    status: QuoteRequestStatus.RESPONDED,
    eventDate: day('2027-01-20'),
    guestCount: 100,
    message: 'نشتي تصوير السمرة يوم الأربعاء 20 يناير.',
    createdAt: inDays(-12),
    // B-08: Adel shared his budget and his phone with the request.
    budget: { min: 300_000, max: 400_000 },
    shareBudget: true,
    shareContact: true,
    offer: {
      title: 'صور فقط',
      message: 'مصور واحد · 300 صورة معدّلة.',
      amount: 350_000,
      validUntil: inDays(-2),
      status: QuoteOfferStatus.PENDING,
    },
  },
  {
    key: 'fahd',
    provider: 'studio',
    customer: 'customerFahd',
    status: QuoteRequestStatus.ACCEPTED,
    eventDate: day('2027-02-04'),
    guestCount: 120,
    message: 'نشتي تصوير الزفة يوم الخميس 4 فبراير.',
    createdAt: inDays(-20),
    offer: {
      title: 'صور وفيديو',
      message: 'مصورين · فيلم 10 دقائق · ألبوم مطبوع.',
      amount: 550_000,
      validUntil: inDays(-8),
      status: QuoteOfferStatus.ACCEPTED,
    },
    booking: { date: day('2027-02-04'), status: BookingStatus.CONFIRMED },
  },
  {
    key: 'khaled',
    provider: 'studio',
    customer: 'customerKhaled',
    status: QuoteRequestStatus.ACCEPTED,
    eventDate: day('2026-09-17'),
    guestCount: 110,
    message: 'نشتي تصوير الزفة يوم 17 سبتمبر.',
    createdAt: day('2026-08-01'),
    offer: {
      title: 'صور وفيديو',
      message: 'مصورين · فيلم 10 دقائق · ألبوم مطبوع.',
      amount: 550_000,
      validUntil: day('2026-08-15'),
      status: QuoteOfferStatus.ACCEPTED,
    },
    booking: { date: day('2026-09-17'), status: BookingStatus.CONFIRMED },
  },
  // p20 «طلب يحيى انتهى بدون رد» (B-04): seven days without the studio's answer.
  {
    key: 'yahya',
    provider: 'studio',
    customer: 'customerYahya',
    status: QuoteRequestStatus.EXPIRED,
    eventDate: day('2027-02-11'),
    guestCount: 90,
    message: 'نشتي تصوير الزفة يوم الخميس 11 فبراير.',
    createdAt: inDays(-10),
    expiredAt: inDays(-3),
  },
];

/** The 4-star review the past customer left the studio (the groom's rating text in the designs). */
export const STUDIO_REVIEW = {
  customer: 'customerKhaled' as DemoAccountKey,
  rating: 4,
  comment: 'الفيلم وصل بعد أسبوعين بالضبط',
  /** p27's reply, once (B-09). */
  reply: 'شكرًا يا خالد، ونعتذر عن التأخير. ضغط الموسم، وعدّلنا طريقة التسليم.',
};

/** Days the studio closed on its calendar (January 2027, as drawn in p28). */
export const STUDIO_BLOCKED_DAYS = ['2027-01-10', '2027-01-11'];

/**
 * Claims of a listing the back office made (B-12), by the account that
 * signed in with the listing's phone. «عدسة سبأ»'s owner has an account and
 * no claim yet, so the claim can be walked from the start.
 */
export interface ClaimSpec {
  provider: string;
  claimant: DemoAccountKey;
  daysAgo: number;
}

export const CLAIMS: readonly ClaimSpec[] = [
  // a07, p08: «مصور الحارة» waits for the review team since yesterday.
  { provider: 'harah', claimant: 'claimantHarah', daysAgo: 1 },
];
