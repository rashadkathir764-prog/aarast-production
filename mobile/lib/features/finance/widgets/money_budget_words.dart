import 'package:flutter/widgets.dart';

import '../../../core/experience_v3/aarast_v3.dart';

// D114: the budget's figures and the groom's mahr in its place, said by one
// writer for the home's money card and for «الملخص». They were written
// twice and came apart: with no budget typed the home still said the mahr
// was «برّا الميزانية», of a budget that is not there.

/// One of the figures: its label, its amount (null where the words say it
/// all, «فوق الميزانية» without how far), and a line under it. [joined]:
/// the label ends in «بـ» and the amount follows it without a space.
typedef MoneyBudgetCell = ({
  String label,
  num? value,
  String? note,
  bool danger,
  bool joined,
});

/// The budget and what is left of it (or how far over it the expected cost
/// is), then what was agreed and what was paid, in the reader's words (D59).
/// [mahrInside]: the groom's mahr inside what he agreed, said under it
/// (D79); [mahrInBudget]: whether the budget holds it (D114). A mahr outside
/// the budget is said so on its line, or «اتفقت على 2 مليون منها المهر 2
/// مليون» over a budget still all free read as wrong arithmetic. [figure]
/// writes the amounts inside a line under a figure.
List<MoneyBudgetCell> moneyBudgetCells(
  BuildContext context, {
  required num budget,
  required num? budgetLeft,
  required bool over,
  required num? overBy,
  required num agreed,
  required num paidByOwner,
  required num paidByOthers,
  required num? mahrInside,
  required String Function(num) figure,
  bool mahrInBudget = true,
}) {
  final mahrNote = mahrInside == null
      ? null
      : budget > 0 && !mahrInBudget
      ? 'منها المهر ${figure(mahrInside)}، برّا الميزانية'
      : 'منها المهر ${figure(mahrInside)}';
  final paidFor = context.ownerDid('عنك', 'عنك', groom: 'عنه', bride: 'عنها');
  return [
    if (budget > 0) ...[
      (
        label: 'الميزانية',
        value: budget,
        note: null,
        danger: false,
        joined: false,
      ),
      if (over)
        // D105: over the budget by the expected cost, as «البنود» says it.
        (
          label: overBy == null ? 'فوق الميزانية' : 'فوق الميزانية بـ',
          value: overBy,
          note: null,
          danger: true,
          joined: true,
        )
      else if (budgetLeft != null)
        // What of the budget nothing is set against yet. «باقي» is what is
        // left to pay on the same card: one word for one meaning.
        (
          label: 'فاضي منها',
          value: budgetLeft,
          note: null,
          danger: false,
          joined: false,
        ),
    ],
    (
      label: context.ownerDid(
        'اتفقت على',
        'اتفقتِ على',
        groom: 'اتفق العريس على',
        bride: 'اتفقت العروسة على',
      ),
      value: agreed,
      note: mahrNote,
      danger: false,
      joined: false,
    ),
    if (paidByOwner > 0 || paidByOthers <= 0)
      (
        label: context.ownerDid(
          'دفعت',
          'دفعتِ',
          groom: 'العريس دفع',
          bride: 'العروسة دفعت',
        ),
        value: paidByOwner,
        note: paidByOthers > 0 ? 'ودفع $paidFor ${figure(paidByOthers)}' : null,
        danger: false,
        joined: false,
      )
    else
      (
        label: 'دفع $paidFor',
        value: paidByOthers,
        note: null,
        danger: false,
        joined: false,
      ),
  ];
}

/// The groom's mahr on its own line when the budget does not hold it:
/// «المهر 2 مليون، برّا الميزانية. سلّمت 500 ألف وباقي 1.5 مليون.» With no
/// budget typed there is nothing for it to be outside of: «المهر 2 مليون.»
String mahrOnItsOwnWords(
  BuildContext context, {
  required num total,
  required num settled,
  required num left,
  required bool hasBudget,
  required String Function(num) figure,
}) {
  final where = hasBudget
      ? 'المهر ${figure(total)}، برّا الميزانية.'
      : 'المهر ${figure(total)}.';
  if (settled <= 0) {
    return '$where ${context.ownerDid('ما سلّمت منه شي بعد', 'ما سلّمتِ منه شي بعد', groom: 'العريس ما سلّم منه شي بعد', bride: 'العروسة ما سلّمت منه شي بعد')}.';
  }
  final handed = context.ownerDid(
    'سلّمت',
    'سلّمتِ',
    groom: 'العريس سلّم',
    bride: 'العروسة سلّمت',
  );
  if (left <= 0) return '$where $handed كله.';
  return '$where $handed ${figure(settled)} وباقي ${figure(left)}.';
}
