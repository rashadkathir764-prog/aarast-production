import { gendered, type GenderedText } from '../voice/address-form';
import { countedWords } from '../voice/count-words';
import type { PlanWord } from '../voice/plan-word';

/**
 * D129 (docs/project/LANGUAGE.md): every word the home's next steps say, one
 * catalog. They speak to the reader in both forms (B5), name what follows
 * the plan's side by `planWord` (the bride's guests are «الضيفات», her place
 * «الصالة»), and give the reason from the data only (LANGUAGE §4.2: «لم
 * يؤكد المصور بعد، والعرس بعد 6 أيام»). An amount is never in the words: it
 * is the step's data, so «أخفِ المبالغ» can hide it. A day passes in as
 * `whenWords` («اليوم», «غدًا», «بعد 5 أيام») or `dayCountWords` («يوم
 * واحد», «يومين», «5 أيام»); a name the user wrote passes in untouched
 * (LANGUAGE §4.9).
 */

/** Offers that arrived, after «وصلك». */
const OFFERS = {
  one: 'عرض سعر',
  two: 'عرضان',
  few: 'عروض',
  many: 'عرضًا',
  other: 'عرض',
} as const;

/** One offer, two (the dual), or more: each line its own words. */
function byOffers<T>(count: number, one: T, two: T, more: T): T {
  return count === 1 ? one : count === 2 ? two : more;
}

export const NEXT_STEP_COPY = {
  payment: {
    /** [days] is `dayCountWords` of how late it is. */
    overdue: (days: string): string => `دفعة متأخرة منذ ${days}`,
    /** [when] is `whenWords` of its day: «دفعة تستحق غدًا». */
    due: (when: string): string => `دفعة تستحق ${when}`,
    /** To a reader who may record the payment. */
    record: gendered('سجّل الدفعة', 'سجّلي الدفعة'),
    /** To a reader who only reads the money. */
    open: gendered('افتح الدفعة', 'افتحي الدفعة'),
  },
  task: {
    /** [days] is `dayCountWords` of how late it is. */
    overdue: (days: string): string => `متأخرة منذ ${days}`,
    /** [when] is `whenWords` of its day: «موعدها اليوم». */
    due: (when: string): string => `موعدها ${when}`,
    open: gendered('افتح المهمة', 'افتحي المهمة'),
  },
  bookingUnconfirmed: {
    /** [provider] is the provider's own name, never touched (LANGUAGE §4.9). */
    title: (provider: string): string => `لم يؤكد ${provider} الحجز بعد`,
    /** [weddingWhen] is `whenWords` («اليوم», «غدًا», «بعد 5 أيام»). */
    reason: (weddingWhen: string): GenderedText =>
      gendered(
        `العرس ${weddingWhen}. تواصل معه ليؤكد، أو ابحث عن بديل.`,
        `العرس ${weddingWhen}. تواصلي معه ليؤكد، أو ابحثي عن بديل.`,
      ),
    action: gendered('تابع الحجز', 'تابعي الحجز'),
  },
  quotesReceived: {
    /** «وصلك عرض سعر», «وصلك عرضان», «وصلك 3 عروض», «وصلك 11 عرضًا». */
    title: (count: number): string => `وصلك ${countedWords(count, OFFERS)}`,
    reason: (count: number): GenderedText =>
      byOffers(
        count,
        gendered(
          'اطّلع عليه قبل أن تنتهي مدته.',
          'اطّلعي عليه قبل أن تنتهي مدته.',
        ),
        gendered(
          'قارن بينهما قبل أن تنتهي مدتهما.',
          'قارني بينهما قبل أن تنتهي مدتهما.',
        ),
        gendered(
          'قارن بينها قبل أن تنتهي مدتها.',
          'قارني بينها قبل أن تنتهي مدتها.',
        ),
      ),
    action: (count: number): GenderedText =>
      byOffers(
        count,
        gendered('افتح العرض', 'افتحي العرض'),
        gendered('قارن العرضين', 'قارني العرضين'),
        gendered('قارن العروض', 'قارني العروض'),
      ),
  },
  setDate: {
    title: gendered('حدد موعد العرس', 'حددي موعد العرس'),
    reason: 'به نرتب المهام والدفعات على أيامها.',
    action: gendered('حدد الموعد', 'حددي الموعد'),
  },
  /** It opens the plan's details, where the field is «مدينة العرس» (RA-MO-155). */
  setLocation: {
    title: gendered('حدد مدينة العرس', 'حددي مدينة العرس'),
    reason: 'لنعرض لك المزوّدين في مدينتك، وتصلهم طلباتك واضحة.',
    action: gendered('حدد المدينة', 'حددي المدينة'),
  },
  setBudget: {
    title: gendered('حدد ميزانية الخطة', 'حددي ميزانية الخطة'),
    reason: gendered(
      'رقم تقريبي يكفي، وبه تعرف ما يمكنك إنفاقه على كل بند.',
      'رقم تقريبي يكفي، وبه تعرفين ما يمكنك إنفاقه على كل بند.',
    ),
    action: gendered('حدد الميزانية', 'حددي الميزانية'),
  },
  recordMahr: {
    /** To both families' side, as the mahr is agreed between them. */
    title: 'هل اتفقتم على المهر؟',
    /** D114: the groom chose to count the mahr in his budget. */
    reasonInsideBudget: gendered(
      'نحسبه من ميزانيتك كما اخترت.',
      'نحسبه من ميزانيتك كما اخترتِ.',
    ),
    reasonOutsideBudget: 'نحسبه وحده، خارج ميزانية العرس.',
    action: gendered('سجّل المهر', 'سجّلي المهر'),
  },
  addFirstCost: {
    title: gendered('سجّل أول اتفاق', 'سجّلي أول اتفاق'),
    reason: {
      groom: 'القاعة أو الذهب أو الكسوة: بأول رقم يتضح الباقي.',
      bride: 'الصالة أو الذهب أو الفستان: بأول رقم يتضح الباقي.',
    } satisfies PlanWord<string>,
    action: gendered('أضف اتفاقًا', 'أضيفي اتفاقًا'),
  },
  addGuests: {
    /** The verb follows the reader, the guests the plan (D55). */
    title: {
      groom: gendered('ابدأ قائمة الضيوف', 'ابدئي قائمة الضيوف'),
      bride: gendered('ابدأ قائمة الضيفات', 'ابدئي قائمة الضيفات'),
    } satisfies PlanWord<GenderedText>,
    reason: {
      groom: 'العدد يحدد حجم القاعة وتكلفة الضيافة.',
      bride: 'العدد يحدد حجم الصالة وتكلفة الضيافة.',
    } satisfies PlanWord<string>,
    action: {
      groom: gendered('أضف أول ضيف', 'أضيفي أول ضيف'),
      bride: gendered('أضف أول ضيفة', 'أضيفي أول ضيفة'),
    } satisfies PlanWord<GenderedText>,
  },
  requestQuote: {
    title: gendered('اطلب أول عرض سعر', 'اطلبي أول عرض سعر'),
    reason: 'الليالي تُحجز مبكرًا، والعرض يعطيك سعرًا حقيقيًا بدل التخمين.',
    /** It opens the plan's directory (LANGUAGE §3: «الدليل»). */
    action: gendered('افتح الدليل', 'افتحي الدليل'),
  },
  missingEssential: {
    /** [item] is the plan's own item name, or `essentialNames`'. */
    title: (item: string): GenderedText =>
      gendered(`لم تتفق على ${item} بعد`, `لم تتفقي على ${item} بعد`),
    reason: gendered(
      'اطلب عروضًا من المزوّدين، أو سجّل اتفاقك إن اتفقت.',
      'اطلبي عروضًا من المزوّدين، أو سجّلي اتفاقك إن اتفقتِ.',
    ),
    action: gendered('اعرض المزوّدين', 'اعرضي المزوّدين'),
  },
  /** G23's essentials by name, when the plan's item has none. */
  essentialNames: {
    VENUE: { groom: 'القاعة', bride: 'الصالة' } satisfies PlanWord<string>,
    DRESS: { groom: 'البدلة والكسوة', bride: 'الفستان' } satisfies PlanWord<string>,
    PHOTO: 'التصوير',
    GOLD: 'الذهب والشبكة',
    HOME: 'الشقة وتجهيز المنزل',
    HONEYMOON: 'شهر العسل',
  },
  debtUndated: {
    title: 'مبلغ متبقٍّ بلا موعد',
    /** To a reader who may record the money. */
    reasonToPlan: gendered(
      'حدد موعدًا لدفعه كي لا يُنسى.',
      'حددي موعدًا لدفعه كي لا يُنسى.',
    ),
    /** To a reader who only reads the money. */
    reasonToRead: 'من اتفاقات لم تُحدد لها دفعات.',
    plan: gendered('رتّب الدفع', 'رتّبي الدفع'),
    read: gendered('اعرض المال', 'اعرضي المال'),
  },
  loanOutstanding: {
    title: 'سُلفة لم تُسدَّد بعد',
    /** [when] is `whenWords` of the nearest planned repayment. */
    nextRepayment: (when: string): string => `أقرب سداد ${when}`,
    /** [days] is `dayCountWords` of how late it is («يومين», «5 أيام»). */
    lateRepayment: (days: string): string => `فات موعد السداد منذ ${days}`,
    noPlan: gendered('حدد متى ستسددها.', 'حددي متى ستسددينها.'),
    action: gendered('اعرض السُّلفة', 'اعرضي السُّلفة'),
  },
  rateProviders: {
    title: gendered(
      'قيّم المزوّدين الذين عملت معهم',
      'قيّمي المزوّدين الذين عملتِ معهم',
    ),
    reason: 'رأيك يساعد من يأتي بعدك على الاختيار.',
    action: gendered('قيّم', 'قيّمي'),
  },
} as const;
