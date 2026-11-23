part of 'money_overview_screen.dart';

// D114 on «الملخص»: the budget in four figures (the budget, what is left of
// it or how far over it the expected cost is, what was agreed, what was
// paid), and the groom's mahr in its place: part of what was agreed when the
// budget holds it, a short line when it is on its own. The same cells as the
// home's money card. Rashad 2026-11-17: they sit in «الصورة كاملة» on paper,
// not in the green card, which says only what is on him and whether his
// money covers it.

/// The groom's mahr as these lines read it; null on a bride's plan (hers is
/// money coming in) or before it is recorded.
MoneyMahrSummary? _mahrPaid(MoneySummary summary) {
  final mahr = summary.mahr;
  if (mahr == null || mahr.side != MahrSide.pays) return null;
  return moneyValue(mahr.total) > 0 ? mahr : null;
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
        // Read together and added up (RA-MO-168): a figure the tenths of a
        // million would round is written whole.
        _exactFigure(context, value, currency).replaceAll(' ', ' ');
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
    final cells = [
      for (final cell in moneyBudgetCells(
        context,
        budget: moneyValue(budget.total),
        budgetLeft: budget.remaining == null
            ? null
            : moneyValue(budget.remaining),
        over: overBy != null,
        overBy: overBy,
        agreed: moneyValue(costs.total),
        paidByOwner: moneyValue(costs.paidByOwner),
        paidByOthers: moneyValue(costs.paidByOthers),
        mahrInside: inside ? moneyValue(mahr.total) : null,
        figure: money,
      ))
        (
          label: cell.label.endsWith('بـ')
              ? cell.label.substring(0, cell.label.length - 2).trimRight()
              : cell.label,
          figure: cell.value == null ? null : money(cell.value),
          note: cell.note,
          danger: cell.danger,
        ),
    ];
    // Two by two, each label over its figure: half the height of a line
    // each, and a figure never wraps away from its label.
    Widget cell(({String label, String? figure, String? note, bool danger}) c) {
      final colour = c.danger ? AarastV3Color.danger : AarastV3Color.ink;
      return MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              c.label,
              style: JourneyType.of(
                JourneyType.small,
                color: c.danger
                    ? AarastV3Color.danger
                    : AarastV3Color.textMuted,
              ),
            ),
            if (c.figure case final figure?)
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  figure,
                  style: JourneyType.of(
                    JourneyType.body,
                    weight: JourneyType.bold,
                    color: colour,
                  ),
                ),
              ),
            if (c.note case final note?)
              Text(
                note,
                style: JourneyType.of(
                  JourneyType.caption,
                  color: AarastV3Color.textMuted,
                ),
              ),
          ],
        ),
      );
    }

    final rows = <Widget>[];
    for (var index = 0; index < cells.length; index += 2) {
      if (index > 0) rows.add(const SizedBox(height: AarastV3Space.x3));
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
        // What is left of the mahr is in the green card; here only where it
        // is counted.
        if (mahr != null && !inside && hasBudget) ...[
          const SizedBox(height: AarastV3Space.x3),
          Text(
            'المهر ${money(mahr.total)}، برّا الميزانية',
            key: const ValueKey('money-share-mahr-line'),
            style: JourneyType.of(
              JourneyType.small,
              color: AarastV3Color.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}
