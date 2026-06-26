import 'guest_onboarding_draft.dart';

class AarastPersonaCopy {
  const AarastPersonaCopy({
    required this.isKnown,
    required this.label,
    required this.identityLabel,
    required this.dashboardHeadline,
    required this.dashboardSupport,
    required this.locationTitle,
    required this.weddingDateTitle,
    required this.calendarSubtitle,
    required this.prioritiesTitle,
    required this.prioritiesDescription,
    required this.budgetDescription,
    required this.categoriesDescription,
    required this.nextBudgetAction,
    required this.nextDateAction,
    required this.nextCategoriesAction,
  });

  final bool isKnown;
  final String label;
  final String identityLabel;
  final String dashboardHeadline;
  final String dashboardSupport;
  final String locationTitle;
  final String weddingDateTitle;
  final String calendarSubtitle;
  final String prioritiesTitle;
  final String prioritiesDescription;
  final String budgetDescription;
  final String categoriesDescription;
  final String nextBudgetAction;
  final String nextDateAction;
  final String nextCategoriesAction;
}

const _neutralCopy = AarastPersonaCopy(
  isKnown: false,
  label: 'صاحب الخطة',
  identityLabel: 'الدور غير محدد',
  dashboardHeadline: 'خلّينا نرتب الخطة خطوة بخطوة',
  dashboardSupport: 'ابدأ من الخطوة الأوضح الآن ثم أكمل التفاصيل بهدوء.',
  locationTitle: 'أين سيكون الزفاف؟',
  weddingDateTitle: 'متى موعد الزفاف؟',
  calendarSubtitle: 'حدد اليوم المناسب لك',
  prioritiesTitle: 'ما أهم ما تريد ترتيبه؟',
  prioritiesDescription: 'هذه الأولويات ستساعد لوحة البداية المحلية لاحقًا.',
  budgetDescription: 'أدخل مبلغًا تقديريًا أو اختر تخطي هذه الخطوة الآن.',
  categoriesDescription:
      'اختر تصنيفات أولية حتى لا تبدأ صفحة المال فارغة لاحقًا.',
  nextBudgetAction: 'أضف ميزانية تقريبية',
  nextDateAction: 'حدد تاريخ الزفاف',
  nextCategoriesAction: 'راجع التصنيفات المقترحة',
);

const _groomCopy = AarastPersonaCopy(
  isKnown: true,
  label: 'العريس',
  identityLabel: 'الدور: العريس',
  dashboardHeadline: 'جاهز نرتب عرسك؟',
  dashboardSupport: 'خلّينا نجهز خطتك خطوة بخطوة.',
  locationTitle: 'أين سيكون عرسك؟',
  weddingDateTitle: 'متى موعد عرسك؟',
  calendarSubtitle: 'حدد اليوم المناسب لك',
  prioritiesTitle: 'ما أهم ما تريد ترتيبه؟',
  prioritiesDescription: 'اختياراتك تساعدنا نرتب أولويات الخطة لك.',
  budgetDescription: 'أضف ميزانية تقريبية أو اتركها لاحقًا من شاشة المال.',
  categoriesDescription: 'اختر تصنيفات بداية تساعدك تفتح صفحة المال بوضوح.',
  nextBudgetAction: 'أضف ميزانية تقريبية',
  nextDateAction: 'حدد تاريخ العرس',
  nextCategoriesAction: 'راجع تصنيفات البداية',
);

const _brideCopy = AarastPersonaCopy(
  isKnown: true,
  label: 'العروسة',
  identityLabel: 'الدور: العروسة',
  dashboardHeadline: 'جاهز نرتب عرسك؟',
  dashboardSupport: 'خلّينا نجهز خطتك خطوة بخطوة.',
  locationTitle: 'أين سيكون عرسك؟',
  weddingDateTitle: 'متى موعد عرسك؟',
  calendarSubtitle: 'حدد اليوم المناسب لك',
  prioritiesTitle: 'ما أهم ما تريد ترتيبه؟',
  prioritiesDescription: 'اختياراتك تساعدنا نرتب أولويات الخطة لك.',
  budgetDescription: 'أضف ميزانية تقريبية أو اتركها لاحقًا من شاشة المال.',
  categoriesDescription:
      'اختر تصنيفات بداية تساعدك على فتح صفحة المال بوضوح.',
  nextBudgetAction: 'أضف ميزانية تقريبية',
  nextDateAction: 'حدد تاريخ العرس',
  nextCategoriesAction: 'راجع تصنيفات البداية',
);

const _helperCopy = AarastPersonaCopy(
  isKnown: true,
  label: 'مساعد / مساهم',
  identityLabel: 'الدور: مساعد / مساهم',
  dashboardHeadline: 'خلّينا نساعدك تنظم الخطة',
  dashboardSupport: 'تابع المهام والمشاركات بسهولة.',
  locationTitle: 'أين ستكون خطة الزفاف؟',
  weddingDateTitle: 'متى موعد الزفاف؟',
  calendarSubtitle: 'ساعد في تحديد اليوم المناسب',
  prioritiesTitle: 'ما الذي ستساعد فيه؟',
  prioritiesDescription: 'اختر الجوانب التي تريد متابعتها مع أصحاب الخطة.',
  budgetDescription: 'أدخل ميزانية تقريبية إن كانت متوفرة، أو اتركها لاحقًا.',
  categoriesDescription: 'اختر تصنيفات بداية تساعد أصحاب الخطة لاحقًا.',
  nextBudgetAction: 'ساعد في ضبط الميزانية',
  nextDateAction: 'تابع تحديد موعد الزفاف',
  nextCategoriesAction: 'راجع تصنيفات البداية',
);

AarastPersonaCopy personaCopyForGuest(GuestPersona? persona) {
  return switch (persona) {
    GuestPersona.groom => _groomCopy,
    GuestPersona.bride => _brideCopy,
    GuestPersona.helper => _helperCopy,
    null => _neutralCopy,
  };
}

AarastPersonaCopy personaCopyForBackend(String? persona) {
  final normalized = persona?.trim().toUpperCase();
  return switch (normalized) {
    'GROOM' => _groomCopy,
    'BRIDE' => _brideCopy,
    'HELPER' => _helperCopy,
    _ => _neutralCopy,
  };
}

String appRoleLabel(GuestOnboardingPath? path) {
  return switch (path) {
    GuestOnboardingPath.provider => 'مسار: مزود خدمة',
    GuestOnboardingPath.weddingUser => 'مسار: أرتب زفافي',
    null => 'مسار الاستخدام غير محدد',
  };
}
