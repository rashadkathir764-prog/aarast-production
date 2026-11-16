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
    // The home's money card says these same cells: one writer for both.
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
        paidByOwner: paidByOwner,
        paidByOthers: paidByOthers,
        mahrInside: inside ? moneyValue(mahr.total) : null,
        figure: money,
      ))
        (
          label: cell.label,
          figure: cell.value == null ? null : money(cell.value),
          note: cell.note,
          danger: cell.danger,
        ),
    ];
    // One line per figure, its label at the start and its figure at the
    // end (Rashad, 2026-11-17): two columns at large text set each label
    // over its figure, and the card took two thirds of the screen.
    Widget cell(({String label, String? figure, String? note, bool danger}) c) {
      final strong = JourneyType.of(
        JourneyType.bodySmall,
        weight: JourneyType.bold,
        color: c.danger ? AarastV3Color.dangerSoft : onColour,
      );
      final label = c.label.endsWith('بـ')
          ? c.label.substring(0, c.label.length - 2).trimRight()
          : c.label;
      return MergeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: c.danger
                        ? strong
                        : JourneyType.of(JourneyType.bodySmall, color: soft),
                  ),
                  if (c.note case final note?)
                    Text(
                      note,
                      style: JourneyType.of(JourneyType.small, color: soft),
                    ),
                ],
              ),
            ),
            if (c.figure case final figure?) ...[
              const SizedBox(width: AarastV3Space.x3),
              // Whole on its line; at the largest text it shrinks to fit
              // rather than run off the card.
              Expanded(
                flex: 2,
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(figure, style: strong),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    final rows = <Widget>[
      for (final (index, c) in cells.indexed) ...[
        if (index > 0) const SizedBox(height: AarastV3Space.x2),
        cell(c),
      ],
    ];
    return Column(
      key: const ValueKey('money-share-budget'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...rows,
        if (mahr != null && !inside) ...[
          const SizedBox(height: AarastV3Space.x2),
          Text(
            mahrOnItsOwnWords(
              context,
              total: moneyValue(mahr.total),
              settled: moneyValue(mahr.settled),
              left: moneyValue(mahr.remaining),
              hasBudget: hasBudget,
              figure: money,
            ),
            key: const ValueKey('money-share-mahr-line'),
            style: JourneyType.of(JourneyType.small, color: soft, height: 1.6),
          ),
        ],
      ],
    );
  }
}
