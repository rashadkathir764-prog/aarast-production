/**
 * D129 (docs/project/LANGUAGE.md): the words on a phone's lock screen, one
 * catalog. Generic by rule (RA-BE-186/187): never a name, an amount or a
 * reason; the details are in the app. A customer's lock screen may be the
 * groom's or the bride's, so its lines carry no gendered imperative (B5);
 * a provider's keep the neutral voice providers are spoken to in (D70).
 * Each line ends by saying where the rest is.
 */

export interface PushCopy {
  title: string;
  body: string;
}

const inApp = 'والتفاصيل في اعّرست.';

export const PUSH_COPY = {
  taskAssigned: { title: 'مهمة جديدة', body: `أُسندت إليك مهمة جديدة، ${inApp}` },
  /** [when] is `reminderWhenWords` («اليوم», «غدًا», «بعد أسبوع»). */
  taskDueSoon: (when: string | null): PushCopy => ({
    title: 'تذكير بمهمة',
    body:
      when === null
        ? `اقترب موعد إحدى مهامك، ${inApp}`
        : `موعد إحدى مهامك ${when}، ${inApp}`,
  }),
  taskOverdue: { title: 'مهمة متأخرة', body: `فات موعد إحدى مهامك، ${inApp}` },
  chatMessage: { title: 'رسالة جديدة', body: 'وصلتك رسالة في اعّرست.' },
  weddingDay: { title: 'اليوم عرسك', body: 'ألف مبروك، وبرنامج اليوم في اعّرست.' },
  weddingNear: { title: 'عرسك يقترب', body: 'ما بقي قبله تجده في اعّرست.' },
  offerReceived: { title: 'وصلك عرض', body: `وصلك عرض سعر جديد، ${inApp}` },
  offerRevised: { title: 'عُدّل عرض', body: 'وصلت نسخة جديدة من عرض، وما تغيّر فيها في اعّرست.' },
  requestExpiringForProvider: {
    title: 'طلب ينتهي غدًا',
    body: 'طلب لم يُرد عليه بعد ينتهي غدًا، والرد عليه في اعّرست.',
  },
  bookingRequested: { title: 'طلب حجز جديد', body: `وصلك طلب حجز، ${inApp}` },
  paymentDueSoon: { title: 'دفعة يقترب موعدها', body: `اقترب موعد إحدى الدفعات، ${inApp}` },
  paymentOverdue: { title: 'دفعة متأخرة', body: `فات موعد إحدى الدفعات، ${inApp}` },
  loanDueSoon: { title: 'سداد يقترب موعده', body: `اقترب موعد سداد، ${inApp}` },
  loanOverdue: { title: 'سداد متأخر', body: `فات موعد سداد، ${inApp}` },
  budgetItemExceeded: {
    title: 'بند تجاوز المخصص له',
    body: `تجاوز أحد بنود الميزانية ما خُصص له، ${inApp}`,
  },
  promisedToday: { title: 'مال موعود اليوم', body: `اليوم موعد مال موعود، ${inApp}` },
  promisedTomorrow: { title: 'مال موعود غدًا', body: `غدًا موعد مال موعود، ${inApp}` },
  bookingUpdated: { title: 'جديد على حجز', body: `تغيّر شيء في أحد الحجوزات، ${inApp}` },
  requestForProvider: {
    title: 'وصلك طلب جديد',
    body: 'يمكن الرد عليه بعرض أو الاعتذار عنه في اعّرست.',
  },
  offerAcceptedForProvider: { title: 'قُبل عرضك', body: 'التفاصيل في اعّرست.' },
  offerDeclinedForProvider: { title: 'لم يُقبل عرضك', body: 'التفاصيل في اعّرست.' },
  offerWithdrawn: { title: 'سُحب عرض', body: `سحب أحد المزوّدين عرضه، ${inApp}` },
  requestExpired: {
    title: 'انتهى طلب دون رد',
    body: `انتهت مدة أحد الطلبات دون رد، ${inApp}`,
  },
  requestDeclined: { title: 'اعتذار عن طلب', body: `اعتذر أحد المزوّدين عن طلب، ${inApp}` },
  planInvitation: {
    title: 'دعوة إلى خطة عرس',
    body: `وصلتك دعوة للمشاركة في خطة، ${inApp}`,
  },
  invitationAccepted: {
    title: 'قُبلت الدعوة',
    body: `انضم مشارك جديد إلى الخطة، ${inApp}`,
  },
  reviewReceived: { title: 'تقييم جديد', body: `وصل تقييم جديد على ملفك، ${inApp}` },
  guestReplies: { title: 'ردود جديدة', body: `وصلت ردود جديدة على دعوتك، ${inApp}` },
  providerApproved: {
    title: 'اعتُمد ملفك',
    body: `صار ملفك ظاهرًا للعرسان، ${inApp}`,
  },
  providerRejected: { title: 'لم يُعتمد ملفك', body: 'التفاصيل في اعّرست.' },
  providerNeedsChanges: {
    title: 'ملاحظة على ملفك',
    body: 'يحتاج ملفك تعديلًا، والملاحظة في اعّرست.',
  },
  providerSuspended: {
    title: 'أُوقف ملفك',
    body: `ملفك لا يظهر للعرسان الآن، ${inApp}`,
  },
  claimRefused: { title: 'لم يُقبل استلام الملف', body: 'السبب في اعّرست.' },
  claimAccepted: { title: 'قُبل استلامك للملف', body: 'صار الملف لك، ويمكن إكماله في اعّرست.' },
  portfolioPhotoRefused: { title: 'لم تُقبل صورة من معرضك', body: 'السبب في اعّرست.' },
  portfolioPhotoAccepted: { title: 'قُبلت صورة من معرضك', body: 'التفاصيل في اعّرست.' },
  reportClosed: { title: 'رُوجع بلاغك', body: 'ما تم فيه تجده في اعّرست.' },
} as const;
