import 'wedding_plan_stage.dart';

enum WeddingStageDomain { tasks, guests, money, providers }

class WeddingStageDomainGuidance {
  const WeddingStageDomainGuidance({
    required this.label,
    required this.message,
  });

  final String label;
  final String message;
}

/// يحوّل المرحلة الحقيقية إلى توجيه صغير خاص بالتبويب.
///
/// لا يستخدم أرقامًا ولا يدّعي جاهزية؛ الأرقام تبقى من مزودي البيانات داخل
/// كل تبويب. دوره فقط ترتيب انتباه المستخدم وفق قرب الموعد.
WeddingStageDomainGuidance resolveWeddingStageDomainGuidance(
  WeddingPlanStageState stage,
  WeddingStageDomain domain,
) {
  return switch ((stage.stage, domain)) {
    (WeddingPlanStage.foundation, WeddingStageDomain.tasks) =>
      const WeddingStageDomainGuidance(
        label: 'ثبّت الأساس',
        message: 'ابدأ بالقرارات الكبيرة وضع موعدًا لكل مهمة مهمة.',
      ),
    (WeddingPlanStage.foundation, WeddingStageDomain.guests) =>
      const WeddingStageDomainGuidance(
        label: 'قائمة مبدئية',
        message: 'اجمع الأسماء أولًا، ويمكنك استكمال الردود والهواتف لاحقًا.',
      ),
    (WeddingPlanStage.foundation, WeddingStageDomain.money) =>
      const WeddingStageDomainGuidance(
        label: 'سقف واضح',
        message: 'حدّد الميزانية قبل أن تتكاثر الالتزامات.',
      ),
    (WeddingPlanStage.foundation, WeddingStageDomain.providers) =>
      const WeddingStageDomainGuidance(
        label: 'استكشف بهدوء',
        message: 'قارن الخيارات واحفظ المناسب قبل طلب عرض سعر.',
      ),
    (WeddingPlanStage.planning, WeddingStageDomain.tasks) =>
      const WeddingStageDomainGuidance(
        label: 'القرارات الكبيرة',
        message: 'قدّم المهام المرتبطة بالمكان والمزوّدين والميزانية.',
      ),
    (WeddingPlanStage.planning, WeddingStageDomain.guests) =>
      const WeddingStageDomainGuidance(
        label: 'نظّف القائمة',
        message: 'أكمل البيانات الناقصة قبل بدء التأكيدات النهائية.',
      ),
    (WeddingPlanStage.planning, WeddingStageDomain.money) =>
      const WeddingStageDomainGuidance(
        label: 'راقب الالتزامات',
        message: 'سجّل الاتفاقات ومواعيد الدفع فور حدوثها.',
      ),
    (WeddingPlanStage.planning, WeddingStageDomain.providers) =>
      const WeddingStageDomainGuidance(
        label: 'احسم المقارنة',
        message: 'راجع المحفوظين واطلب عروضًا للخيارات الأقرب.',
      ),
    (WeddingPlanStage.finalMonth, WeddingStageDomain.tasks) =>
      const WeddingStageDomainGuidance(
        label: 'أغلق المفتوح',
        message: 'المتأخر واليوم أهم من إضافة قائمة جديدة.',
      ),
    (WeddingPlanStage.finalMonth, WeddingStageDomain.guests) =>
      const WeddingStageDomainGuidance(
        label: 'ثبّت الردود',
        message: 'ابدأ بمن لم يحسم حضوره أو ما زالت بياناته ناقصة.',
      ),
    (WeddingPlanStage.finalMonth, WeddingStageDomain.money) =>
      const WeddingStageDomainGuidance(
        label: 'راجع القادم',
        message: 'قدّم موعد الدفع الأقرب وراجع الباقي قبل الاستحقاق.',
      ),
    (WeddingPlanStage.finalMonth, WeddingStageDomain.providers) =>
      const WeddingStageDomainGuidance(
        label: 'ثبّت العروض',
        message: 'راجع العروض المفتوحة والمحادثات قبل اكتشاف خيارات جديدة.',
      ),
    (WeddingPlanStage.finalWeek, WeddingStageDomain.tasks) ||
    (
      WeddingPlanStage.weddingDay,
      WeddingStageDomain.tasks,
    ) => const WeddingStageDomainGuidance(
      label: 'الحرج فقط',
      message: 'ركّز على الآن واليوم، واترك غير الضروري لما بعد الحدث.',
    ),
    (WeddingPlanStage.finalWeek, WeddingStageDomain.guests) ||
    (
      WeddingPlanStage.weddingDay,
      WeddingStageDomain.guests,
    ) => const WeddingStageDomainGuidance(
      label: 'التأكيدات فقط',
      message: 'عالج الردود والبيانات التي تؤثر فعليًا على الحضور.',
    ),
    (WeddingPlanStage.finalWeek, WeddingStageDomain.money) ||
    (
      WeddingPlanStage.weddingDay,
      WeddingStageDomain.money,
    ) => const WeddingStageDomainGuidance(
      label: 'الدفعات القريبة',
      message: 'اعرض المستحق والقريب واترك التحليل التفصيلي لوقت أهدأ.',
    ),
    (WeddingPlanStage.finalWeek, WeddingStageDomain.providers) ||
    (
      WeddingPlanStage.weddingDay,
      WeddingStageDomain.providers,
    ) => const WeddingStageDomainGuidance(
      label: 'التواصل المباشر',
      message: 'قدّم العروض والمحادثات الحالية قبل البحث عن مزوّد جديد.',
    ),
    (WeddingPlanStage.wrapUp, WeddingStageDomain.tasks) =>
      const WeddingStageDomainGuidance(
        label: 'إغلاق هادئ',
        message: 'راجع المفتوح وأغلق ما انتهى دون اختراع إنجازات.',
      ),
    (WeddingPlanStage.wrapUp, WeddingStageDomain.guests) =>
      const WeddingStageDomainGuidance(
        label: 'السجل النهائي',
        message: 'احتفظ بالقائمة كما حدثت وعدّل الأخطاء فقط.',
      ),
    (WeddingPlanStage.wrapUp, WeddingStageDomain.money) =>
      const WeddingStageDomainGuidance(
        label: 'أغلق الالتزامات',
        message: 'راجع الباقي والمدفوع وسجّل التسويات الحقيقية.',
      ),
    (WeddingPlanStage.wrapUp, WeddingStageDomain.providers) =>
      const WeddingStageDomainGuidance(
        label: 'راجع ما تم',
        message: 'ارجع للمحادثات والعروض القائمة بدل فتح طلبات جديدة.',
      ),
  };
}
