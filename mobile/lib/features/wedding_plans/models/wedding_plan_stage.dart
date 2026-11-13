import '../../../core/utils/plan_day.dart';

enum WeddingPlanStage {
  foundation,
  planning,
  finalMonth,
  finalWeek,
  weddingDay,
  wrapUp,
}

class WeddingPlanStageState {
  const WeddingPlanStageState({
    required this.stage,
    required this.daysUntilWedding,
    required this.label,
    required this.compactLabel,
    required this.headline,
    required this.guidance,
  });

  final WeddingPlanStage stage;
  final int? daysUntilWedding;
  final String label;
  final String compactLabel;
  final String headline;
  final String guidance;

  bool get isWeddingWindow =>
      stage == WeddingPlanStage.finalWeek ||
      stage == WeddingPlanStage.weddingDay;
}

/// Resolves one truthful product stage from the plan's real wedding date.
///
/// The engine is deliberately deterministic and offline-safe. It does not
/// invent readiness from task counts, providers, or an AI score; those remain
/// separate real signals on each product surface.
WeddingPlanStageState resolveWeddingPlanStage(
  DateTime? weddingDate, {
  DateTime? now,
}) {
  if (weddingDate == null) {
    return const WeddingPlanStageState(
      stage: WeddingPlanStage.foundation,
      daysUntilWedding: null,
      label: 'بداية التخطيط',
      compactLabel: 'البداية',
      headline: 'ثبّت أساس الخطة',
      guidance: 'حدّد الموعد والميزانية، ثم ابدأ بالمهام والضيوف.',
    );
  }

  // D11: counted from today in Sana'a, as the server counts (RA-MO-20).
  final days = daysUntilPlanDay(weddingDate, now: now);

  if (days < 0) {
    return WeddingPlanStageState(
      stage: WeddingPlanStage.wrapUp,
      daysUntilWedding: days,
      label: 'إغلاق الخطة',
      compactLabel: 'ما بعد العرس',
      headline: 'أغلق ما تبقّى بهدوء',
      guidance: 'راجع الالتزامات والمهام المفتوحة دون إنشاء حالة إنجاز وهمية.',
    );
  }
  if (days == 0) {
    return const WeddingPlanStageState(
      stage: WeddingPlanStage.weddingDay,
      daysUntilWedding: 0,
      label: 'يوم العرس',
      compactLabel: 'اليوم الكبير',
      headline: 'كل ما يهم اليوم أمامك',
      guidance: 'الوقت والموقع والمهام الحرجة وجهات الاتصال في مكان واحد.',
    );
  }
  if (days <= weddingWeekDays) {
    return WeddingPlanStageState(
      stage: WeddingPlanStage.finalWeek,
      daysUntilWedding: days,
      label: 'الأسبوع الأخير',
      compactLabel: 'الأسبوع الأخير',
      headline: 'ركّز على التأكيدات النهائية',
      guidance: 'تابع المهام الحرجة وردود الضيوف والمزوّدين فقط.',
    );
  }
  if (days <= 30) {
    return WeddingPlanStageState(
      stage: WeddingPlanStage.finalMonth,
      daysUntilWedding: days,
      label: 'الشهر الأخير',
      compactLabel: 'قبل العرس',
      headline: 'ثبّت القرارات المفتوحة',
      guidance: 'أغلق ردود الضيوف والمزوّدين وراجع الدفعات القادمة.',
    );
  }
  if (days <= 120) {
    return WeddingPlanStageState(
      stage: WeddingPlanStage.planning,
      daysUntilWedding: days,
      label: 'مرحلة التخطيط',
      compactLabel: 'التخطيط',
      headline: 'احسم القرارات الكبيرة',
      guidance: 'رتّب الأولويات قبل أن تتحول القرارات إلى أمور عاجلة.',
    );
  }
  return WeddingPlanStageState(
    stage: WeddingPlanStage.foundation,
    daysUntilWedding: days,
    label: 'بداية التخطيط',
    compactLabel: 'البداية',
    headline: 'ابنِ الخطة على مهل',
    guidance: 'ثبّت الأساس، ثم وزّع المهام والضيوف والمزوّدين تدريجيًا.',
  );
}
