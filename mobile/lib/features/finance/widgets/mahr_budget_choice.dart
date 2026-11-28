import 'package:flutter/material.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/widgets/release_field_focus.dart';
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
    this.asksBeforeGoingOn = false,
    super.key,
  });

  final bool inside;
  final ValueChanged<bool>? onChanged;

  /// The press that would have left was stopped to show this choice: it
  /// says so, so a press that did nothing else is not taken for a save.
  final bool asksBeforeGoingOn;

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
        if (asksBeforeGoingOn) ...[
          const SizedBox(height: AarastV3Space.x1),
          Text(
            context.say(
              'اختر واحد منهم، بعدها كمّل.',
              'اختاري واحد منهم، بعدها كمّلي.',
            ),
            key: const ValueKey('mahr-budget-choice-prompt'),
            style: JourneyType.of(
              JourneyType.small,
              weight: JourneyType.bold,
              color: context.accent.primary,
            ),
          ),
        ],
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

/// Whether the choice under [key] is on screen whole: inside its scrolling
/// area and above the keyboard. Seen on a phone: typed with the keyboard
/// up, the choice sat under it and the step was left without it.
bool mahrChoiceOnScreen(GlobalKey key) {
  final context = key.currentContext;
  final box = context?.findRenderObject();
  if (context == null || box is! RenderBox || !box.attached) return false;
  final rect = box.localToGlobal(Offset.zero) & box.size;
  var bottom =
      MediaQuery.sizeOf(context).height -
      MediaQuery.viewInsetsOf(context).bottom;
  var top = 0.0;
  final scrollable = Scrollable.maybeOf(context)?.context.findRenderObject();
  if (scrollable is RenderBox && scrollable.attached) {
    final view = scrollable.localToGlobal(Offset.zero) & scrollable.size;
    top = view.top;
    if (view.bottom < bottom) bottom = view.bottom;
  }
  return rect.top >= top - 0.5 && rect.bottom <= bottom + 0.5;
}

/// Closes the keyboard and brings the choice under [key] into view, never
/// while the person types: only from the press that would leave without it.
/// A list builds what is far below lazily, so a choice not built yet is
/// reached through [near] (anything built in the same list): the list goes
/// to its end, where the choice is.
void revealMahrChoice(GlobalKey key, {GlobalKey? near}) {
  releaseFieldFocus();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final context = key.currentContext ?? near?.currentContext;
    if (context == null || !context.mounted) return;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AarastV3Motion.standard;
    if (key.currentContext == null) {
      final position = Scrollable.maybeOf(context)?.position;
      if (position == null) return;
      position.animateTo(
        position.maxScrollExtent,
        duration: duration == Duration.zero
            ? const Duration(milliseconds: 1)
            : duration,
        curve: Curves.easeOut,
      );
      return;
    }
    Scrollable.ensureVisible(
      context,
      duration: duration,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );
  });
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
        // D129: MSA, and short enough that the choice stays whole on a
        // 320 phone with the keyboard up.
        ? 'من الميزانية $total: $ofMahr للمهر، و${mahrWords(left, currency)} للعرس'
        : left == 0
        ? 'المهر $ofMahr ياخذ الميزانية كلها'
        : 'المهر $ofMahr أكثر من الميزانية بـ${mahrWords(-left, currency)}',
  );
}
