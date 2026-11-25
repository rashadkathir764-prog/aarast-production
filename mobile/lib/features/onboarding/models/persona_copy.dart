import '../../../core/experience_v3/aarast_v3.dart' show ReaderVoice;
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

// Batch 5 (Q-35 (أ)): Sana'ani, in the reader's form. The groom's copy is
// his and the bride's hers; who has not said, and a helper, are spoken to in
// the form the app knows for them (`ReaderVoice`).

AarastPersonaCopy get _neutralCopy => AarastPersonaCopy(
  isKnown: false,
  label: 'صاحب الخطة',
  identityLabel: 'الدور ما تحدد',
  dashboardHeadline: 'خلّينا نرتب الخطة خطوة خطوة',
  dashboardSupport: ReaderVoice.say(
    'ابدأ من الأوضح الحين، وكمّل التفاصيل على راحتك.',
    'ابدئي من الأوضح الحين، وكمّلي التفاصيل على راحتك.',
  ),
  locationTitle: 'فين العرس؟',
  weddingDateTitle: 'متى العرس؟',
  calendarSubtitle: ReaderVoice.say(
    'اختر اليوم اللي يناسبك',
    'اختاري اليوم اللي يناسبك',
  ),
  prioritiesTitle: ReaderVoice.say(
    'ايش أهم شي تشتي ترتبه؟',
    'ايش أهم شي تشتين ترتبينه؟',
  ),
  prioritiesDescription: 'اختياراتك تساعدنا نرتب لك الخطة.',
  budgetDescription: ReaderVoice.say(
    'اكتب مبلغ تقريبي، أو تخطّى هذي الخطوة الحين.',
    'اكتبي مبلغ تقريبي، أو تخطّي هذي الخطوة الحين.',
  ),
  categoriesDescription: ReaderVoice.say(
    'اختر بنود البداية عشان ما تفتح صفحة المال فاضية.',
    'اختاري بنود البداية عشان ما تفتحين صفحة المال فاضية.',
  ),
  nextBudgetAction: ReaderVoice.say(
    'أضف ميزانية تقريبية',
    'أضيفي ميزانية تقريبية',
  ),
  nextDateAction: ReaderVoice.say('حدد موعد العرس', 'حددي موعد العرس'),
  nextCategoriesAction: ReaderVoice.say(
    'راجع البنود المقترحة',
    'راجعي البنود المقترحة',
  ),
);

const _groomCopy = AarastPersonaCopy(
  isKnown: true,
  label: 'العريس',
  identityLabel: 'الدور: العريس',
  dashboardHeadline: 'جاهز نرتب عرسك؟',
  dashboardSupport: 'خلّينا نجهز خطتك خطوة خطوة.',
  locationTitle: 'فين عرسك؟',
  weddingDateTitle: 'متى عرسك؟',
  calendarSubtitle: 'اختر اليوم اللي يناسبك',
  prioritiesTitle: 'ايش أهم شي تشتي ترتبه؟',
  prioritiesDescription: 'اختياراتك تساعدنا نرتب لك الخطة.',
  budgetDescription: 'أضف ميزانية تقريبية، أو خلّها بعدين من المال.',
  categoriesDescription: 'اختر بنود البداية عشان تفتح صفحة المال وهي واضحة.',
  nextBudgetAction: 'أضف ميزانية تقريبية',
  nextDateAction: 'حدد موعد العرس',
  nextCategoriesAction: 'راجع بنود البداية',
);

const _brideCopy = AarastPersonaCopy(
  isKnown: true,
  label: 'العروسة',
  identityLabel: 'الدور: العروسة',
  dashboardHeadline: 'جاهزة نرتب عرسك؟',
  dashboardSupport: 'خلّينا نجهز خطتك خطوة خطوة.',
  locationTitle: 'فين عرسك؟',
  weddingDateTitle: 'متى عرسك؟',
  calendarSubtitle: 'اختاري اليوم اللي يناسبك',
  prioritiesTitle: 'ايش أهم شي تشتين ترتبينه؟',
  prioritiesDescription: 'اختياراتك تساعدنا نرتب لك الخطة.',
  budgetDescription: 'أضيفي ميزانية تقريبية، أو خلّيها بعدين من المال.',
  categoriesDescription:
      'اختاري بنود البداية عشان تفتحين صفحة المال وهي واضحة.',
  nextBudgetAction: 'أضيفي ميزانية تقريبية',
  nextDateAction: 'حددي موعد العرس',
  nextCategoriesAction: 'راجعي بنود البداية',
);

AarastPersonaCopy get _helperCopy => AarastPersonaCopy(
  isKnown: true,
  label: ReaderVoice.say('مساعد', 'مساعدة'),
  identityLabel: ReaderVoice.say('الدور: مساعد', 'الدور: مساعدة'),
  dashboardHeadline: ReaderVoice.say(
    'خلّينا نساعدك ترتب الخطة',
    'خلّينا نساعدك ترتبين الخطة',
  ),
  dashboardSupport: ReaderVoice.say(
    'تابع المهام والمشاركين بسهولة.',
    'تابعي المهام والمشاركين بسهولة.',
  ),
  locationTitle: 'فين العرس؟',
  weddingDateTitle: 'متى العرس؟',
  calendarSubtitle: ReaderVoice.say(
    'ساعد في اختيار اليوم',
    'ساعدي في اختيار اليوم',
  ),
  prioritiesTitle: ReaderVoice.say(
    'في ايش تشتي تساعد؟',
    'في ايش تشتين تساعدين؟',
  ),
  prioritiesDescription: ReaderVoice.say(
    'اختر اللي تشتي تتابعه مع أصحاب الخطة.',
    'اختاري اللي تشتين تتابعينه مع أصحاب الخطة.',
  ),
  budgetDescription: ReaderVoice.say(
    'اكتب ميزانية تقريبية لو معك، أو خلّها بعدين.',
    'اكتبي ميزانية تقريبية لو معك، أو خلّيها بعدين.',
  ),
  categoriesDescription: ReaderVoice.say(
    'اختر بنود البداية اللي تساعد أصحاب الخطة.',
    'اختاري بنود البداية اللي تساعد أصحاب الخطة.',
  ),
  nextBudgetAction: ReaderVoice.say(
    'ساعد في الميزانية',
    'ساعدي في الميزانية',
  ),
  nextDateAction: ReaderVoice.say('تابع موعد العرس', 'تابعي موعد العرس'),
  nextCategoriesAction: ReaderVoice.say(
    'راجع بنود البداية',
    'راجعي بنود البداية',
  ),
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
    GuestOnboardingPath.weddingUser => 'مسار: أرتب عرسي',
    null => 'المسار ما تحدد',
  };
}
