part of 'money_overview_screen.dart';

// D114 on «الملخص»: under what is on the owner and whether his money covers
// it, the rest of the picture in four figures (the budget, what is left of
// it or how far over it the expected cost is, what was agreed, what was
// paid), and the groom's mahr in its place: part of what was agreed when the
// budget holds it, its own line when it is on its own. The same words as the
// home's money card.

/// The groom's mahr as these lines read it; null on a bride's plan (hers is
/// money coming in) or before it is recorded.
MoneyMahrSummary? _mahrPaid(MoneySummary summary) {
  final mahr = summary.mahr;
  if (mahr == null || mahr.side != MahrSide.pays) return null;
  return moneyValue(mahr.total) > 0 ? mahr : null;
}

/// «المهر 2 مليون، برّا الميزانية. سلّمت 500 ألف وباقي 1.5 مليون.»
String _mahrOutsideWords(
  BuildContext context,
  MoneyMahrSummary mahr, {
  required bool hasBudget,
  required String Function(Object?) money,
}) {
  final total = moneyValue(mahr.total);
  final settled = moneyValue(mahr.settled);
  final left = moneyValue(mahr.remaining);
  final where = hasBudget
      ? 'المهر ${money(total)}، برّا الميزانية.'
      : 'المهر ${money(total)}.';
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
  return '$where $handed ${money(settled)} وباقي ${money(left)}.';
}

class _BudgetFigures extends StatelessWidget {
  const _BudgetFigures({required this.summary});

  final MoneySummary summary;

  @override
  Widget build(BuildContext context) {
    final currency = summary.currency;
    // Each figure whole on its line: «1.5» was left at a line's end with
    // «مليون ر.ي» under it.
    String money(Object? value) =>
        _figure(context, value, currency).replaceAll(' ', ' ');
    final onColour = AarastV3Color.onPrimary;
    final soft = context.accent.onPrimaryMuted;
    final budget = summary.budget;
    final hasBudget = moneyValue(budget.total) > 0;
    final mahr = _mahrPaid(summary);
    final inside = mahr != null && budget.includesMahr;
    // D105: over the budget by the expected cost, as «البنود» says it.
    final budgetLeft = summary.expected?.budgetLeft;
    final overBy = budgetLeft != null && moneyValue(budgetLeft) < 0
        ? -moneyValue(budgetLeft)
        : null;
    final costs = summary.costs;
    final paidByOthers = moneyValue(costs.paidByOthers);
    final paidByOwner = moneyValue(costs.paidByOwner);
    final paidFor = context.ownerDid('عنك', 'عنك', groom: 'عنه', bride: 'عنها');
    final cells = <({String label, String? figure, String? note, bool danger})>[
      if (hasBudget) ...[
        (
          label: 'الميزانية',
          figure: money(budget.total),
          note: null,
          danger: false,
        ),
        if (overBy != null)
          (
            label: 'فوق الميزانية بـ',
            figure: money(overBy),
            note: null,
            danger: true,
          )
        else if (budget.remaining != null)
          (
            label: 'باقي منها',
            figure: money(budget.remaining),
            note: null,
            danger: false,
          ),
      ],
      (
        label: context.ownerDid(
          'اتفقت على',
          'اتفقتِ على',
          groom: 'اتفق العريس على',
          bride: 'اتفقت العروسة على',
        ),
        figure: money(costs.total),
        note: inside ? 'منها المهر ${money(mahr.total)}' : null,
        danger: false,
      ),
      if (paidByOwner > 0 || paidByOthers <= 0)
        (
          label: context.ownerDid(
            'دفعت',
            'دفعتِ',
            groom: 'العريس دفع',
            bride: 'العروسة دفعت',
          ),
          figure: money(paidByOwner),
          note: paidByOthers > 0
              ? 'ودفع $paidFor ${money(paidByOthers)}'
              : null,
          danger: false,
        )
      else
        (
          label: 'دفع $paidFor',
          figure: money(paidByOthers),
          note: null,
          danger: false,
        ),
    ];
    Widget cell(({String label, String? figure, String? note, bool danger}) c) {
      final strong = JourneyType.of(
        JourneyType.bodySmall,
        weight: JourneyType.bold,
        color: c.danger ? AarastV3Color.dangerSoft : onColour,
      );
      return MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: c.label.endsWith('بـ') ? c.label : '${c.label} ',
                    style: c.danger
                        ? strong
                        : JourneyType.of(JourneyType.bodySmall, color: soft),
                  ),
                  if (c.figure case final figure?)
                    TextSpan(text: figure, style: strong),
                ],
              ),
            ),
            if (c.note case final note?)
              Text(note, style: JourneyType.of(JourneyType.small, color: soft)),
          ],
        ),
      );
    }

    final rows = <Widget>[];
    for (var index = 0; index < cells.length; index += 2) {
      if (index > 0) rows.add(const SizedBox(height: AarastV3Space.x2));
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cell(cells[index])),
            const SizedBox(width: AarastV3Space.x3),
            Expanded(
              child: index + 1 < cells.length
                  ? cell(cells[index + 1])
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
    }
    return Column(
      key: const ValueKey('money-share-budget'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...rows,
        if (mahr != null && !inside) ...[
          const SizedBox(height: AarastV3Space.x2),
          Text(
            _mahrOutsideWords(
              context,
              mahr,
              hasBudget: hasBudget,
              money: money,
            ),
            key: const ValueKey('money-share-mahr-line'),
            style: JourneyType.of(JourneyType.small, color: soft, height: 1.6),
          ),
        ],
      ],
    );
  }
}
