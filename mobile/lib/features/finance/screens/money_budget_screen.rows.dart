part of 'money_budget_screen.dart';

/// One item's share while it is being edited.
class _CategoryDraft {
  _CategoryDraft({
    this.id,
    required this.name,
    required String? amount,
    this.confirmedCost = '0',
  }) : key = id ?? 'draft-${DateTime.now().microsecondsSinceEpoch}',
       amount = TextEditingController(text: formatMoneyInputValue(amount));

  final String key;
  final String? id;
  final String name;

  /// What is already agreed on the item: a share below it is flagged.
  final String confirmedCost;
  final TextEditingController amount;

  void dispose() => amount.dispose();
}

/// «موزّع» and «احتياط» (or how far the shares went over).
class _ReserveBox extends StatelessWidget {
  const _ReserveBox({
    required this.allocated,
    required this.reserve,
    required this.over,
  });

  final String allocated;

  /// Null while there is no budget to compare with.
  final String? reserve;
  final bool over;

  @override
  Widget build(BuildContext context) {
    Widget cell(String label, String value, Color color) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: JourneyType.of(
              JourneyType.small,
              color: AarastV3Color.textMuted,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              style: JourneyType.of(
                JourneyType.title,
                weight: JourneyType.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
    return JourneyBox(
      key: const ValueKey('money-budget-reserve'),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          cell('موزّع', allocated, AarastV3Color.ink),
          if (reserve != null) ...[
            const SizedBox(width: 12),
            cell(
              over ? 'زايد عن الميزانية' : 'احتياط',
              reserve!,
              over ? AarastV3Color.danger : AarastV3Color.primary,
            ),
          ],
        ],
      ),
    );
  }
}

/// An item's name, its share typed in place, and how much of the budget
/// that is. A share below what is already agreed turns red.
class _AllocationRow extends StatelessWidget {
  const _AllocationRow({
    required this.row,
    required this.total,
    required this.currency,
    required this.onChanged,
    required this.onOpen,
    super.key,
  });

  final _CategoryDraft row;
  final num total;
  final String currency;
  final VoidCallback onChanged;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final share = moneyValue(row.amount.text);
    final agreed = moneyValue(row.confirmedCost);
    final short = row.amount.text.trim().isNotEmpty && share < agreed;
    final color = short ? AarastV3Color.danger : AarastV3Color.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'افتح ${row.name}',
                  onTap: row.id == null ? null : onOpen,
                  excludeSemantics: true,
                  child: AarastPressable(
                    key: ValueKey('money-budget-category-${row.id}'),
                    onTap: row.id == null ? () {} : onOpen,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        row.name,
                        style: JourneyType.of(
                          JourneyType.body,
                          weight: JourneyType.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 132,
                child: TextField(
                  key: ValueKey('money-budget-share-${row.key}'),
                  controller: row.amount,
                  keyboardType: TextInputType.number,
                  inputFormatters: [MoneyInputFormatter()],
                  textAlign: TextAlign.end,
                  textDirection: TextDirection.ltr,
                  style: JourneyType.of(
                    JourneyType.body,
                    weight: JourneyType.bold,
                    color: short ? AarastV3Color.danger : AarastV3Color.ink,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'بدون',
                    suffixText: currencyLabelAr(currency),
                    filled: true,
                    fillColor: AarastV3Color.canvas,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (_) => onChanged(),
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          JourneyBar(
            value: total <= 0 ? 0 : (share / total).clamp(0.0, 1.0).toDouble(),
            color: color,
          ),
          if (short)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'اتفقت عليه بـ ${compactMoneyParts(agreed, currencyCode: currency).plainText}',
                style: JourneyType.of(
                  JourneyType.small,
                  weight: JourneyType.bold,
                  color: AarastV3Color.danger,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
