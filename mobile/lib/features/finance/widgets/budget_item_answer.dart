import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/l10n/aarast_text.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../data/finance_api.dart';

/// D72: the owner's answer to an essential money item with no agreement,
/// «لا أحتاجه» (`NOT_NEEDED`) or «لاحقًا» (`LATER`), sent to the server and
/// said in a toast. True when the answer was saved; the caller reads the
/// plan again.
///
/// LATER keeps the item out of the home's suggestions for a week; no notice
/// is sent (RA-MO-63). NOT_NEEDED keeps it out until it is taken back on
/// the item's own screen, where a null [choice] clears the answer.
Future<bool> answerBudgetItem(
  BuildContext context, {
  required String weddingPlanId,
  required String categoryId,
  required String? choice,
}) async {
  final text = context.text;
  final gender = context.gender;
  try {
    await context.read<FinanceApi>().setBudgetItemSuggestion(
      weddingPlanId: weddingPlanId,
      categoryId: categoryId,
      choice: choice,
    );
  } on ApiException catch (error) {
    if (context.mounted) {
      AarastToast.showError(
        context,
        error.isNetworkFailure
            ? error.message
            : text.budgetItemAnswerFailed(gender),
      );
    }
    return false;
  } on Object {
    if (context.mounted) {
      AarastToast.showError(context, text.budgetItemAnswerFailed(gender));
    }
    return false;
  }
  if (context.mounted) {
    AarastToast.showSuccess(context, switch (choice) {
      'LATER' => text.budgetItemLaterDone,
      'NOT_NEEDED' => text.budgetItemNotNeededDone(gender),
      _ => text.budgetItemTakenBack,
    });
  }
  return true;
}

/// D72 on a money item's own screen, while nothing is agreed on it: the two
/// answers to an essential item, or, once answered, what the answer did and
/// the way to take it back.
class BudgetItemAnswer extends StatefulWidget {
  const BudgetItemAnswer({
    required this.weddingPlanId,
    required this.categoryId,
    required this.answer,
    required this.onSaved,
    super.key,
  });

  final String weddingPlanId;
  final String categoryId;

  /// The answer that keeps it out of the home's suggestions now
  /// (`NOT_NEEDED`, or `LATER` inside its week); null: the two answers are
  /// offered.
  final String? answer;

  /// After a saved answer: the screen reads the money again.
  final Future<void> Function() onSaved;

  @override
  State<BudgetItemAnswer> createState() => _BudgetItemAnswerState();
}

class _BudgetItemAnswerState extends State<BudgetItemAnswer> {
  bool _busy = false;

  Future<void> _send(String? choice) async {
    // RA-MO-158: a second tap while the first is on its way sends nothing.
    if (_busy) return;
    setState(() => _busy = true);
    final saved = await answerBudgetItem(
      context,
      weddingPlanId: widget.weddingPlanId,
      categoryId: widget.categoryId,
      choice: choice,
    );
    if (saved) await widget.onSaved();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final gender = context.gender;
    final answer = widget.answer;
    if (answer != null) {
      return JourneyBox(
        key: const ValueKey('item-essential-answered'),
        borderColor: AarastV3Color.line,
        borderWidth: AarastV3Space.hair,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              // Said of the item, not «قلتَ…»: the answer is the plan's, and
              // the partner who manages the money reads it too.
              answer == 'LATER'
                  ? text.budgetItemAnsweredLater
                  : text.budgetItemAnsweredNotNeeded,
              style: JourneyType.of(
                JourneyType.body,
                color: AarastV3Color.textMuted,
                height: AarastV3Line.normal,
              ),
            ),
            JourneyTextAction(
              key: const ValueKey('item-essential-take-back'),
              label: text.budgetItemTakeBack(gender),
              color: context.accent.primary,
              onPressed: _busy ? null : () => _send(null),
            ),
          ],
        ),
      );
    }
    return Column(
      key: const ValueKey('item-essential-answers'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JourneySectionTitle(text.budgetItemQuestion(gender)),
        Row(
          children: [
            Expanded(
              child: JourneyButton.outline(
                key: const ValueKey('item-essential-later'),
                label: text.budgetItemLater,
                expand: true,
                onPressed: _busy ? null : () => _send('LATER'),
              ),
            ),
            const SizedBox(width: AarastV3Space.x3),
            Expanded(
              child: JourneyButton.outline(
                key: const ValueKey('item-essential-not-needed'),
                label: text.budgetItemNotNeeded,
                expand: true,
                onPressed: _busy ? null : () => _send('NOT_NEEDED'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
