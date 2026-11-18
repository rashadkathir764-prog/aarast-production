import 'package:flutter/material.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/utils/arabic_count.dart';

/// Rashad 2026-11-17: the tasks' hero, the home's own look and size
/// (JourneyPlanHero). The open tasks as the big figure, how many are done
/// under it, the late ones as its saffron tag and the share done as the
/// bar. The owner's tasks tab and a participant's (2026-11-18: «كل
/// المسارات») give it their own counts.
class TaskProgressHero extends StatelessWidget {
  const TaskProgressHero({
    required this.open,
    required this.done,
    required this.total,
    this.late = 0,
    super.key,
  });

  /// Still to do, done, and all of them (the cancelled left out).
  final int open;
  final int done;
  final int total;

  /// Past their date and not done; 0 hides the tag.
  final int late;

  @override
  Widget build(BuildContext context) {
    // One and two are said in their word, without the figure, as the home
    // says «يومين على عرسك».
    final word = switch (open) {
      0 => 'ما فيه مهام باقية',
      1 => 'مهمة وحدة باقية',
      2 => 'مهمتين باقية',
      _ => arabicCountWord(
        open,
        one: 'مهمة باقية',
        two: 'مهمتين باقية',
        few: 'مهام باقية',
        many: 'مهمة باقية',
      ),
    };
    final lateLabel = late == 0
        ? null
        : arabicCount(
            late,
            one: 'واحدة متأخرة',
            two: 'ثنتين متأخرة',
            few: 'متأخرة',
            many: 'متأخرة',
          );
    return JourneyPlanHero(
      key: const ValueKey('tasks-hero'),
      figure: open > 2 ? '$open' : null,
      title: word,
      subtitle: 'خلصت $done من ${taskCountLabel(total)}',
      tag: lateLabel == null
          ? null
          : JourneyHeroTag(
              key: const ValueKey('tasks-hero-late'),
              label: lateLabel,
            ),
      semanticLabel:
          '${open == 0 ? word : '${taskCountLabel(open)} باقية'}، خلصت $done من $total',
      footer: JourneyHeroBar(value: total == 0 ? 0 : done / total),
    );
  }
}

/// «مهمة وحدة», «مهمتين», «5 مهام», «12 مهمة».
String taskCountLabel(int count) => arabicCount(
  count,
  one: 'مهمة وحدة',
  two: 'مهمتين',
  few: 'مهام',
  many: 'مهمة',
);
