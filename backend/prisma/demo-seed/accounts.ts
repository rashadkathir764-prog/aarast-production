// The demo accounts. Every phone is a clearly fake number (+96777700xxxx) and
// every account shares one dev-only password chosen at seed time.
import {
  AdminRole,
  AppRole,
  OnboardingPath,
  PrismaClient,
  UserRole,
  UserStatus,
  WeddingPersona,
} from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import { demoId } from './support';

export type DemoAccountKey =
  | 'groom'
  | 'bride'
  | 'helperSaleh'
  | 'viewerFather'
  | 'helperNora'
  | 'viewerMother'
  | 'providerStudio'
  | 'providerHall'
  | 'providerPending'
  | 'providerNeedsChanges'
  | 'providerRejected'
  | 'providerResubmitted'
  | 'providerAfrah'
  | 'providerUmmFahd'
  | 'claimantHarah'
  | 'claimantLens'
  | 'customerAdel'
  | 'customerFahd'
  | 'customerKhaled'
  | 'customerYahya'
  | 'adminRashad'
  | 'adminNadia'
  | 'adminSara'
  | 'adminOmar';

/** `applicant`: signed up on the provider path and has no provider profile yet (claims wait for review, B-12). */
type AccountKind = 'owner' | 'participant' | 'provider' | 'applicant' | 'customer' | 'admin';

export interface DemoAccount {
  key: DemoAccountKey;
  name: string;
  phone: string;
  kind: AccountKind;
  /** What the account is for, in Arabic and in English (used for the printed table and docs). */
  roleAr: string;
  roleEn: string;
  persona?: WeddingPersona;
  adminRole?: AdminRole;
}

export const DEMO_ACCOUNTS: readonly DemoAccount[] = [
  { key: 'groom', name: 'محمد الحمدي', phone: '+967777000101', kind: 'owner', persona: WeddingPersona.GROOM, roleAr: 'العريس، صاحب خطة «عرس محمد»', roleEn: 'Groom, owner of the plan "عرس محمد"' },
  { key: 'bride', name: 'سلمى السقاف', phone: '+967777000102', kind: 'owner', persona: WeddingPersona.BRIDE, roleAr: 'العروسة، صاحبة خطة «عرس سلمى» ومشاركة (أهل) في خطة محمد', roleEn: 'Bride, owner of "عرس سلمى" and a family participant in Mohammed\'s plan' },
  { key: 'helperSaleh', name: 'صالح', phone: '+967777000103', kind: 'participant', persona: WeddingPersona.HELPER, roleAr: 'مساعد (أخو العريس) في خطة محمد', roleEn: 'Helper (groom\'s brother) in Mohammed\'s plan' },
  { key: 'viewerFather', name: 'الوالد', phone: '+967777000104', kind: 'participant', persona: WeddingPersona.HELPER, roleAr: 'يشوف بس (والد العريس) في خطة محمد', roleEn: 'Viewer (groom\'s father) in Mohammed\'s plan' },
  { key: 'helperNora', name: 'نورة', phone: '+967777000105', kind: 'participant', persona: WeddingPersona.HELPER, roleAr: 'مساعدة (أخت العروسة) في خطة سلمى', roleEn: 'Helper (bride\'s sister) in Salma\'s plan' },
  { key: 'viewerMother', name: 'الوالدة', phone: '+967777000106', kind: 'participant', persona: WeddingPersona.HELPER, roleAr: 'تشوف بس (والدة العروسة) في خطة سلمى', roleEn: 'Viewer (bride\'s mother) in Salma\'s plan' },
  { key: 'providerStudio', name: 'علي الشامي', phone: '+967777000201', kind: 'provider', roleAr: 'مزود نشط: استوديو ضوء صنعاء (تصوير)', roleEn: 'Active provider: Dhaw Sanaa Studio (photography)' },
  { key: 'providerHall', name: 'أمجد الحيمي', phone: '+967777000202', kind: 'provider', roleAr: 'مزود نشط: قاعة سبأ (صالات)', roleEn: 'Active provider: Saba Hall (halls)' },
  { key: 'providerPending', name: 'صالح العزي', phone: '+967777000203', kind: 'provider', roleAr: 'مزود بانتظار المراجعة: فرقة الأمجاد للبرع', roleEn: 'Pending provider: Al-Amjad Bara\' Troupe' },
  { key: 'providerNeedsChanges', name: 'منصور الحداد', phone: '+967777000204', kind: 'provider', roleAr: 'مزود «يحتاج تعديل»: محلات الأناقة', roleEn: 'Needs-changes provider: Al-Anaqa Shops' },
  { key: 'providerRejected', name: 'أم ريان', phone: '+967777000205', kind: 'provider', roleAr: 'مزود مرفوض بسبب يقدر يصلّحه: كوافيرة أم ريان («قدّم من جديد»)', roleEn: 'Rejected provider with a fixable reason: Um Rayan Salon (reopen)' },
  { key: 'providerResubmitted', name: 'فارس الوصابي', phone: '+967777000206', kind: 'provider', roleAr: 'مزود أرسل التعديل وينتظر المراجعة: فرقة النجوم للمزمار', roleEn: 'Provider who sent the fixes back: Al-Nujoom Mizmar Troupe' },
  { key: 'providerAfrah', name: 'عبده الوصابي', phone: '+967777000207', kind: 'provider', roleAr: 'مزود نشط: فرقة الأفراح (مبرع)، يلقاه العريس من «الفنان والفرقة»', roleEn: 'Active provider: Al-Afrah troupe (mabra), found from the groom\'s artist item' },
  { key: 'providerUmmFahd', name: 'أم فهد', phone: '+967777000208', kind: 'provider', roleAr: 'مزودة نشطة: المزينة أم فهد (نقاشة)، تلقاها العروسة من «المزينة والنقاشة»', roleEn: 'Active provider: Um Fahd (henna), found from the bride\'s naqsh item' },
  { key: 'claimantHarah', name: 'عبدالله الحارثي', phone: '+967777000506', kind: 'applicant', roleAr: 'طلب استلام ملف «مصور الحارة» ينتظر الإدارة', roleEn: 'Claim of the "Musawwir Al-Harah" listing waiting for review' },
  { key: 'claimantLens', name: 'نبيل المقطري', phone: '+967777000502', kind: 'applicant', roleAr: 'صاحب ملف «عدسة سبأ» بلا حساب مزود، يقدر يطلب استلامه', roleEn: 'Owner of the unclaimed "Adasat Saba" listing, free to claim it' },
  { key: 'customerAdel', name: 'عادل الريمي', phone: '+967777000301', kind: 'customer', persona: WeddingPersona.GROOM, roleAr: 'عميل: طلب من الاستوديو انتهى عرضه', roleEn: 'Customer whose studio offer expired' },
  { key: 'customerFahd', name: 'فهد العمري', phone: '+967777000302', kind: 'customer', persona: WeddingPersona.GROOM, roleAr: 'عميل: حجز مؤكد عند الاستوديو', roleEn: 'Customer with a confirmed studio booking' },
  { key: 'customerKhaled', name: 'خالد القاضي', phone: '+967777000303', kind: 'customer', persona: WeddingPersona.GROOM, roleAr: 'عميل سابق: حجز تم وتقييم 4 نجوم', roleEn: 'Past customer: completed booking and a 4-star review' },
  { key: 'customerYahya', name: 'يحيى السنيدار', phone: '+967777000304', kind: 'customer', persona: WeddingPersona.GROOM, roleAr: 'عميل: طلبه من الاستوديو انتهى بدون رد بعد 7 أيام', roleEn: 'Customer whose studio request expired unanswered after 7 days' },
  { key: 'adminRashad', name: 'رشاد', phone: '+967777000401', kind: 'admin', adminRole: AdminRole.SUPER_ADMIN, roleAr: 'مدير أعلى للوحة الإدارة', roleEn: 'Super admin (admin web)' },
  { key: 'adminNadia', name: 'نادية', phone: '+967777000402', kind: 'admin', adminRole: AdminRole.OPERATIONS, roleAr: 'تشغيل (طلبات المزودين والكتالوج)', roleEn: 'Operations (provider applications, catalog)' },
  { key: 'adminSara', name: 'سارة', phone: '+967777000403', kind: 'admin', adminRole: AdminRole.MODERATOR, roleAr: 'إشراف محتوى (التقييمات والبلاغات)', roleEn: 'Moderator (reviews, reports)' },
  { key: 'adminOmar', name: 'عمر', phone: '+967777000404', kind: 'admin', adminRole: AdminRole.SUPPORT, roleAr: 'دعم (قراءة فقط)', roleEn: 'Support (read only)' },
];

export const userId = (key: DemoAccountKey): string => demoId('user', key);

/** Creates or refreshes every demo account. Returns nothing: ids are `userId(key)`. */
export async function seedAccounts(
  prisma: PrismaClient,
  password: string,
): Promise<void> {
  const appHash = await bcrypt.hash(password, 10);
  const adminHash = await bcrypt.hash(password, 12);
  const now = new Date();

  for (const account of DEMO_ACCOUNTS) {
    const isAdmin = account.kind === 'admin';
    const isProvider = account.kind === 'provider';
    const data = {
      name: account.name,
      phone: account.phone,
      passwordHash: isAdmin ? adminHash : appHash,
      appPasswordHash: null,
      appPasswordConfiguredAt: isAdmin ? null : now,
      role: isAdmin ? UserRole.ADMIN : isProvider ? UserRole.PROVIDER : UserRole.USER,
      adminRole: account.adminRole ?? null,
      appRole: isProvider ? AppRole.PROVIDER : AppRole.WEDDING_USER,
      status: UserStatus.ACTIVE,
      phoneVerifiedAt: now,
      locale: 'ar',
      onboardingPath: isAdmin
        ? null
        : isProvider || account.kind === 'applicant'
          ? OnboardingPath.PROVIDER
          : OnboardingPath.USER,
      persona: account.persona ?? null,
      onboardingCompletedAt: isAdmin ? null : now,
    };
    await prisma.user.upsert({
      where: { id: userId(account.key) },
      create: { id: userId(account.key), ...data },
      update: data,
    });
  }
}
