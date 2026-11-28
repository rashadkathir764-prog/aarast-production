import '../../../core/experience_v3/aarast_v3.dart' show ReaderVoice;
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
/// separate real signals on each product surface. Its words are Sana'ani, in
/// the reader's form (`ReaderVoice`, Q-35 (أ)).
WeddingPlanStageState resolveWeddingPlanStage(
  DateTime? weddingDate, {
  DateTime? now,
}) {
  if (weddingDate == null) {
    return WeddingPlanStageState(
      stage: WeddingPlanStage.foundation,
      daysUntilWedding: null,
      label: 'بداية الترتيب',
      compactLabel: 'البداية',
      headline: ReaderVoice.say('ثبّت أساس الخطة', 'ثبّتي أساس الخطة'),
      guidance: ReaderVoice.say(
        'حدّد الموعد والميزانية، وبعدها ابدأ بالمهام والضيوف.',
        'حدّدي الموعد والميزانية، وبعدها ابدئي بالمهام والضيوف.',
      ),
    );
  }

  // D11: counted from today in Sana'a, as the server counts (RA-MO-20).
  final days = daysUntilPlanDay(weddingDate, now: now);

  if (days < 0) {
    return WeddingPlanStageState(
      stage: WeddingPlanStage.wrapUp,
      daysUntilWedding: days,
      label: 'قفلة الخطة',
      compactLabel: 'ما بعد العرس',
      headline: ReaderVoice.say(
        'اقفل اللي باقي على راحتك',
        'اقفلي اللي باقي على راحتك',
      ),
      guidance: ReaderVoice.say(
        'راجع اللي عليك والمهام المفتوحة، وما نحسبها خلصت وهي ما خلصت.',
        'راجعي اللي عليك والمهام المفتوحة، وما نحسبها خلصت وهي ما خلصت.',
      ),
    );
  }
  if (days == 0) {
    return const WeddingPlanStageState(
      stage: WeddingPlanStage.weddingDay,
      daysUntilWedding: 0,
      label: 'يوم العرس',
      compactLabel: 'اليوم الكبير',
      headline: 'كل اللي يهمك اليوم قدامك',
      guidance: 'الوقت والمكان والمهام الحرجة وأرقام التواصل في مكان واحد.',
    );
  }
  if (days <= weddingWeekDays) {
    return WeddingPlanStageState(
      stage: WeddingPlanStage.finalWeek,
      daysUntilWedding: days,
      label: 'الأسبوع الأخير',
      compactLabel: 'الأسبوع الأخير',
      headline: ReaderVoice.say(
        'ركّز على التأكيدات الأخيرة',
        'ركّزي على التأكيدات الأخيرة',
      ),
      guidance: ReaderVoice.say(
        'تابع المهام الحرجة وردود الضيوف والمزودين بس.',
        'تابعي المهام الحرجة وردود الضيوف والمزودين بس.',
      ),
    );
  }
  if (days <= 30) {
    return WeddingPlanStageState(
      stage: WeddingPlanStage.finalMonth,
      daysUntilWedding: days,
      label: 'الشهر الأخير',
      compactLabel: 'قبل العرس',
      headline: ReaderVoice.say(
        'ثبّت القرارات المفتوحة',
        'ثبّتي القرارات المفتوحة',
      ),
      guidance: ReaderVoice.say(
        'كمّل ردود الضيوف والمزودين وراجع الدفعات الجاية.',
        'كمّلي ردود الضيوف والمزودين وراجعي الدفعات الجاية.',
      ),
    );
  }
  if (days <= 120) {
    return WeddingPlanStageState(
      stage: WeddingPlanStage.planning,
      daysUntilWedding: days,
      label: 'مرحلة الترتيب',
      compactLabel: 'التخطيط',
      headline: ReaderVoice.say(
        'احسم القرارات الكبيرة',
        'احسمي القرارات الكبيرة',
      ),
      guidance: ReaderVoice.say(
        'رتّب الأولويات قبل لا تصير القرارات مستعجلة.',
        'رتّبي الأولويات قبل لا تصير القرارات مستعجلة.',
      ),
    );
  }
  return WeddingPlanStageState(
    stage: WeddingPlanStage.foundation,
    daysUntilWedding: days,
    label: 'بداية الترتيب',
    compactLabel: 'البداية',
    headline: ReaderVoice.say('ابنِ الخطة على مهل', 'ابني الخطة على مهل'),
    guidance: ReaderVoice.say(
      'ثبّت الأساس، وبعدها وزّع المهام والضيوف والمزودين شوية شوية.',
      'ثبّتي الأساس، وبعدها وزّعي المهام والضيوف والمزودين شوية شوية.',
    ),
  );
}
