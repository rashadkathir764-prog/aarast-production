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

/// «موزّع» and «احتياط» (or how far the shares went over), as w19 draws
/// them: a 12.5 muted label over a 20 bold figure. Pressing it changes the
/// budget itself.
class _ReserveBox extends StatelessWidget {
  const _ReserveBox({
    required this.allocated,
    required this.reserve,
    required this.over,
    required this.onTap,
  });

  final String allocated;

  /// Null while there is no budget to compare with.
  final String? reserve;
  final bool over;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget cell(String label, String value, Color color) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: JourneyType.of(
              JourneyType.label,
              color: AarastV3Color.textMuted,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              style: JourneyType.of(
                JourneyType.pageTitle,
                weight: JourneyType.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
    final reserve = this.reserve;
    return AarastPressable(
      key: const ValueKey('money-budget-reserve'),
      onTap: onTap,
      semanticLabel: [
        'موزّع $allocated',
        if (reserve == null)
          context.say('حدد ميزانية عرسك', 'حددي ميزانية عرسك')
        else
          '${over ? 'زايد عن الميزانية' : 'احتياط'} $reserve',
      ].join('، '),
      borderRadius: BorderRadius.circular(22),
      child: JourneyBox(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            cell('موزّع', allocated, AarastV3Color.ink),
            const SizedBox(width: 12),
            if (reserve == null)
              cell(
                'احتياط',
                context.say('حدد الميزانية', 'حددي الميزانية'),
                context.accent.primary,
              )
            else
              cell(
                over ? 'زايد عن الميزانية' : 'احتياط',
                reserve,
                over ? AarastV3Color.danger : context.accent.primary,
              ),
          ],
        ),
      ),
    );
  }
}

/// An item as w19 draws it: its name and share on one line, the bar of its
/// part of the budget under them. A share below what is already agreed
/// turns red and says so. Pressing it changes the share.
class _AllocationRow extends StatelessWidget {
  const _AllocationRow({
    required this.row,
    required this.total,
    required this.currency,
    required this.onTap,
    super.key,
  });

  final _CategoryDraft row;
  final num total;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final typed = row.amount.text.trim().isNotEmpty;
    final share = moneyValue(row.amount.text);
    final agreed = moneyValue(row.confirmedCost);
    final short = typed && share < agreed;
    final color = short ? AarastV3Color.danger : context.accent.primary;
    final value = typed
        ? compactMoneyParts(share, currencyCode: currency).plainText
        : 'بدون';
    return AarastPressable(
      key: ValueKey('money-budget-category-${row.id}'),
      onTap: onTap,
      semanticLabel: '${row.name}، $value',
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.name,
                    style: JourneyType.of(
                      JourneyType.body,
                      weight: JourneyType.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  value,
                  style: JourneyType.of(
                    JourneyType.body,
                    weight: JourneyType.bold,
                    color: short
                        ? AarastV3Color.danger
                        : typed
                        ? AarastV3Color.ink
                        : AarastV3Color.textFaint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            JourneyBar(
              value: total <= 0
                  ? 0
                  : (share / total).clamp(0.0, 1.0).toDouble(),
              color: color,
              height: 8,
            ),
            if (short)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${context.say('اتفقت', 'اتفقتِ')} عليه بـ ${compactMoneyParts(agreed, currencyCode: currency).plainText}',
                  style: JourneyType.of(
                    JourneyType.small,
                    weight: JourneyType.bold,
                    color: AarastV3Color.danger,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
