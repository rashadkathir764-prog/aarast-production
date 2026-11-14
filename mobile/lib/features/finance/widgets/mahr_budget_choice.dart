import 'package:flutter/material.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import 'mahr_fields.dart' show mahrWords;

/// D114: whether the groom's budget holds his mahr, asked wherever he types
/// the budget (the welcome's mahr question, «بيانات الخطة», the budget
/// sheet). Two answers, the mahr on its own first (every plan's start); each
/// says what it means in his own numbers once they are known. Never on a
/// bride's plan: her mahr is money coming in.
class MahrBudgetChoice extends StatelessWidget {
  const MahrBudgetChoice({
    required this.inside,
    required this.onChanged,
    this.budget,
    this.mahr,
    this.currency = 'YER',
    super.key,
  });

  final bool inside;
  final ValueChanged<bool>? onChanged;

  /// The budget and the mahr as typed or saved; null or zero when unknown.
  final num? budget;
  final num? mahr;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final words = mahrBudgetChoiceWords(
      budget: budget,
      mahr: mahr,
      currency: currency,
    );
    final onChanged = this.onChanged;
    return Column(
      key: const ValueKey('mahr-budget-choice'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'المهر من الميزانية؟',
          style: JourneyType.of(JourneyType.body, weight: JourneyType.bold),
        ),
        const SizedBox(height: AarastV3Space.x2),
        JourneyOption(
          key: const ValueKey('mahr-budget-outside'),
          title: 'لا، المهر لحاله',
          subtitle: words.outside,
          selected: !inside,
          onTap: onChanged == null ? null : () => onChanged(false),
        ),
        const SizedBox(height: AarastV3Space.x2),
        JourneyOption(
          key: const ValueKey('mahr-budget-inside'),
          title: 'نعم، الميزانية فيها المهر',
          subtitle: words.inside,
          selected: inside,
          onTap: onChanged == null ? null : () => onChanged(true),
        ),
      ],
    );
  }
}

/// What each answer means: in the person's numbers once the budget (and
/// the mahr) are known, else in plain words.
({String outside, String inside}) mahrBudgetChoiceWords({
  num? budget,
  num? mahr,
  String currency = 'YER',
}) {
  final hasBudget = budget != null && budget > 0;
  final hasMahr = mahr != null && mahr > 0;
  if (!hasBudget) {
    return (
      outside: 'الميزانية للعرس بس، والمهر نحسبه برّاها',
      inside: 'المهر ينحسب من الميزانية مع العرس',
    );
  }
  final total = mahrWords(budget, currency);
  if (!hasMahr) {
    return (
      outside: 'الميزانية $total كلها للعرس، والمهر برّاها',
      inside: 'المهر ينحسب من الميزانية $total',
    );
  }
  final ofMahr = mahrWords(mahr, currency);
  final left = budget - mahr;
  return (
    outside: 'الميزانية $total كلها للعرس، والمهر $ofMahr فوقها',
    inside: left > 0
        ? 'من الميزانية $total يروح $ofMahr للمهر، ويبقى للعرس ${mahrWords(left, currency)}'
        : left == 0
        ? 'المهر $ofMahr ياخذ الميزانية كلها'
        : 'المهر $ofMahr أكثر من الميزانية بـ${mahrWords(-left, currency)}',
  );
}
