// The marketplace side of the demo: providers, what customers asked them and
// what they answered. Names and numbers come from the groom, bride, provider
// and admin prototypes.
import {
  BookingStatus,
  ProviderStatus,
  QuoteOfferStatus,
  QuoteRequestStatus,
} from '@prisma/client';
import type { DemoAccountKey } from './accounts';
import { day, demoUuid, hoursAgo, inDays } from './support';

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
  reviewNote?: string;
  verified?: boolean;
  featured?: boolean;
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
    featured: true,
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
    featured: true,
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
    city: 'صنعاء',
    categorySlug: 'hospitality',
    businessName: 'ضيافة الأصالة',
    ownerName: 'عبدالرحمن الأصبحي',
    phone: '+967777000501',
    description: 'ضيافة وعشاء للأعراس بالمأكولات اليمنية.',
    address: 'حدة، صنعاء',
    status: ProviderStatus.ACTIVE,
    featured: true,
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
    city: 'صنعاء',
    categorySlug: 'wedding-halls',
    businessName: 'صالة الياسمين',
    ownerName: 'هدى المتوكل',
    phone: '+967777000505',
    description: 'صالة نسائية تتسع 150 ضيفة.',
    address: 'شارع حدة، صنعاء',
    status: ProviderStatus.ACTIVE,
    featured: true,
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
    reviewNote: 'أُوقف بعد 3 بلاغات تأخير تسليم.',
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
    reviewNote: 'ضيف صورة واضحة للمحل، وحدد سعر الثوب الأبيض في الخدمة.',
    services: [
      { key: 'thawb', title: 'ثوب أبيض', description: 'تفصيل ثوب أبيض.', price: 45_000, unit: 'package' },
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
    reviewNote: 'الرقم مسجل في ملف آخر. تقدر تعيد التقديم برقم مختلف.',
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
  status: QuoteRequestStatus;
  eventDate: Date;
  guestCount?: number;
  message: string;
  createdAt: Date;
  offer?: {
    title: string;
    message: string;
    amount: number;
    validUntil: Date;
    status: QuoteOfferStatus;
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
];

/** The 4-star review the past customer left the studio (the groom's rating text in the designs). */
export const STUDIO_REVIEW = {
  customer: 'customerKhaled' as DemoAccountKey,
  rating: 4,
  comment: 'الفيلم وصل بعد أسبوعين بالضبط',
};

/** Days the studio closed on its calendar (January 2027, as drawn in p28). */
export const STUDIO_BLOCKED_DAYS = ['2027-01-10', '2027-01-11'];
