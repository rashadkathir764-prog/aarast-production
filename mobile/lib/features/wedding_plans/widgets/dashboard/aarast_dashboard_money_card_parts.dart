part of 'aarast_dashboard_view.dart';

// The pieces of b02's money card ([_DashboardMoneyCard]): its lead, the
// verdict chip, the far column, the dues strip, the bar, and the budget's
// figures under them (D114).

/// One figure of the budget's lines: «الميزانية 7 مليون», «باقي منها 5
/// مليون», with a note under it («منها المهر 2 مليون»). [joined] puts the
/// figure straight after its words («فوق الميزانية بـ300 ألف»).
class _MoneyCellData {
  const _MoneyCellData(
    this.label,
    this.value, {
    this.note,
    this.danger = false,
    this.joined = false,
  });

  final String label;

  /// Null: the words say it all («فوق الميزانية» without its amount).
  final double? value;
  final String? note;
  final bool danger;
  final bool joined;

  String words(String Function(double) figure) {
    final value = this.value;
    if (value == null) return label;
    return joined ? '$label${figure(value)}' : '$label ${figure(value)}';
  }
}

/// D114: the budget, what is left of it (or how far over it the expected
/// cost is), what was agreed and what was paid, two to a row; then the
/// mahr's own line when it is outside the budget.
class _MoneyFigures extends StatelessWidget {
  const _MoneyFigures({
    required this.cells,
    required this.figure,
    this.mahrLine,
  });

  final List<_MoneyCellData> cells;
  final String Function(double) figure;
  final String? mahrLine;

  @override
  Widget build(BuildContext context) {
    final muted = JourneyType.of(
      JourneyType.small,
      color: AarastV3Color.textMuted,
    );
    Widget cell(_MoneyCellData data) {
      final value = data.value;
      final strong = JourneyType.of(
        JourneyType.bodySmall,
        weight: JourneyType.bold,
        color: data.danger ? AarastV3Color.danger : AarastV3Color.ink,
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value == null || data.joined
                      ? data.label
                      : '${data.label} ',
                  style: data.danger
                      ? strong
                      : JourneyType.of(
                          JourneyType.bodySmall,
                          color: AarastV3Color.textMuted,
                        ),
                ),
                if (value != null) TextSpan(text: figure(value), style: strong),
              ],
            ),
          ),
          if (data.note case final note?) Text(note, style: muted),
        ],
      );
    }

    final rows = <Widget>[];
    for (var index = 0; index < cells.length; index += 2) {
      if (index > 0) rows.add(const SizedBox(height: AarastV3Space.x1));
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
      key: const ValueKey('dashboard-money-figures'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...rows,
        if (mahrLine case final line?) ...[
          const SizedBox(height: AarastV3Space.x1),
          Text(
            line,
            key: const ValueKey('dashboard-money-mahr-line'),
            style: muted,
          ),
        ],
      ],
    );
  }
}

/// «باقي عليك» over its 28 figure.
class _MoneyLead extends StatelessWidget {
  const _MoneyLead({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.tag,
    this.showLabel = true,
  });

  final String label;
  final String value;
  final Color color;

  /// False where the card's title row already says [label] (Rashad
  /// 2026-11-17: «المال» over «باقي عليك» was two rows for one name).
  final bool showLabel;

  /// D113: the verdict's short tag, on its own line right under the figure
  /// it judges: the same slot for «تكفي», «تكفي بشرط الموعود» and «ينقصك
  /// X», so the card keeps one height (beside the label it moved to a second
  /// line when the label and a longer tag did not fit together).
  final Widget? tag;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel)
          Text(
            label,
            style: JourneyType.of(
              JourneyType.bodySmall,
              color: AarastV3Color.textMuted,
            ),
          ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            value,
            key: const ValueKey('dashboard-money-lead'),
            style: JourneyType.of(
              JourneyType.headline,
              weight: JourneyType.bold,
              color: color,
              height: 1.2,
            ),
          ),
        ),
        if (tag case final tag?) ...[
          const SizedBox(height: AarastV3Space.x1),
          tag,
        ],
      ],
    );
  }
}

/// D113: the money tab's verdict as a short tag: a tick on «تكفي», a mark
/// on «ينقصك», and the attention colour without a tick on «تكفي بشرط
/// الموعود» (good news that rests on a promise).
class _VerdictChip extends StatelessWidget {
  const _VerdictChip({
    required this.ok,
    required this.words,
    this.conditional = false,
  });

  final bool ok;
  final bool conditional;
  final String words;

  @override
  Widget build(BuildContext context) {
    final (color, soft, icon) = conditional
        ? (
            AarastV3Color.brandAccentStrong,
            AarastV3Color.brandAccentSoft,
            LucideIcons.clock,
          )
        : ok
        ? (AarastV3Color.mint, AarastV3Color.mintSoft, LucideIcons.check)
        : (AarastV3Color.danger, AarastV3Color.dangerSoft, LucideIcons.x);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(AarastV3Radius.control),
      ),
      child: Padding(
        padding: AarastV3Density.tagInsets,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AarastV3Icon.sm, color: color),
            const SizedBox(width: AarastV3Space.x1),
            // One line, as D113 keeps the card's height; on the narrowest
            // screen with large text it fades inside its column instead of
            // running past it.
            Flexible(
              child: Text(
                words,
                key: const ValueKey('dashboard-money-verdict'),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
                style: JourneyType.of(
                  JourneyType.small,
                  weight: JourneyType.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One line of the far column: «معك 2.9 مليون», «موعود 250 ألف» (V-01:
/// every line with its unit, see [_figure]).
class _SideFigure extends StatelessWidget {
  const _SideFigure(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.end,
      style: JourneyType.of(
        JourneyType.bodySmall,
        weight: JourneyType.bold,
        color: color,
      ),
    );
  }
}

/// When the owner pays: one bar cut by each piece's share, what is late in
/// the warning colour and the nearest month in the plan's, and each piece
/// named under it with its figure on a line of its own (side by side they
/// were cut on a narrow phone, and the cut fell on the figure).
class _DuesStrip extends StatelessWidget {
  const _DuesStrip({
    required this.dues,
    required this.figure,
    required this.hidden,
    required this.color,
    required this.soft,
  });

  final List<DashboardHomeDue> dues;
  final String Function(double) figure;

  /// G17: with the amounts hidden the bar is cut evenly, so the pieces'
  /// widths say nothing of how the amounts compare.
  final bool hidden;
  final Color color;
  final Color soft;

  @override
  Widget build(BuildContext context) {
    final total = dues.fold<double>(0, (sum, due) => sum + due.amount);
    final nearest = dues.indexWhere((due) => !due.overdue);
    return Column(
      key: const ValueKey('dashboard-money-dues'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: SizedBox(
            height: AarastV3Space.x1,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < dues.length; index++) ...[
                  if (index > 0) const SizedBox(width: AarastV3Space.x1),
                  Expanded(
                    flex: hidden || total <= 0
                        ? 1
                        : (dues[index].amount / total * 1000).round().clamp(
                            1,
                            1000,
                          ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: dues[index].overdue
                            ? AarastV3Color.danger
                            : index == nearest
                            ? color
                            : soft,
                        borderRadius: BorderRadius.circular(AarastV3Radius.xs),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AarastV3Space.x1),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < dues.length; index++)
              Expanded(
                child: MergeSemantics(
                  // A line too long for its third (a year, millions,
                  // enlarged text) is drawn smaller, whole, like the
                  // card's own figure; it is never cut.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: index == 0
                        ? AlignmentDirectional.centerStart
                        : index == dues.length - 1
                        ? AlignmentDirectional.centerEnd
                        : Alignment.center,
                    child: Column(
                      crossAxisAlignment: index == 0
                          ? CrossAxisAlignment.start
                          : index == dues.length - 1
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.center,
                      children: [
                        Text(
                          dues[index].label,
                          style: JourneyType.of(
                            JourneyType.caption,
                            color: dues[index].overdue
                                ? AarastV3Color.danger
                                : AarastV3Color.textMuted,
                          ),
                        ),
                        Text(
                          figure(dues[index].amount),
                          key: ValueKey('dashboard-money-due-$index'),
                          style: JourneyType.of(
                            JourneyType.caption,
                            weight: JourneyType.bold,
                            color: AarastV3Color.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// The 10-high bar split by amount; empty pieces are left out.
class _MoneySplitBar extends StatelessWidget {
  const _MoneySplitBar({required this.pieces});

  final List<(double, Color)> pieces;

  @override
  Widget build(BuildContext context) {
    final shown = [
      for (final piece in pieces)
        if (piece.$1 > 0) piece,
    ];
    final total = shown.fold<double>(0, (sum, piece) => sum + piece.$1);
    return ExcludeSemantics(
      child: ClipRRect(
        key: const ValueKey('dashboard-money-bar'),
        borderRadius: BorderRadius.circular(AarastV3Radius.xs),
        child: SizedBox(
          height: AarastV3Space.x2,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < shown.length; index++) ...[
                if (index > 0) const SizedBox(width: AarastV3Space.x1),
                Expanded(
                  flex: (shown[index].$1 / total * 1000).round().clamp(1, 1000),
                  child: ColoredBox(color: shown[index].$2),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _money(double value, String currency) {
  return compactMoneyParts(value, currencyCode: currency).plainText;
}

/// RA-MO-181: what the screen reader says: the currency by its name
/// («ريال يمني»), not «ر.ي» read out letter by letter.
String _spoken(double value, String currency) {
  return compactMoneyParts(value, currencyCode: currency).semanticText;
}

/// b02's far column (V-01): every line the same way, the short figure with
/// its unit («3 مليون», «250 ألف», «0 ر.ي»), its unit kept on its line. The
/// design's bare «5.4» is dropped: beside a full figure it read as another
/// unit («اتفقت على 3» over «دفعت 250,000 ر.ي»).
String _figure(double value, String currency) {
  return compactMoneyFigure(value, currencyCode: currency);
}

/// [_figure] for the budget's figures under the line, which are read
/// together and add up: shortened only when nothing is lost (critique م2).
String _sumFigure(double value, String currency) {
  return sumSafeMoneyFigure(value, currencyCode: currency);
}

/// [_figure] as the screen reader says it: «900 ر.ي» with the currency's
/// name; «3 مليون» as it is.
String _spokenFigure(double value, String currency) {
  return _figure(
    value,
    currency,
  ).replaceAll(currencyLabelAr(currency), currencySpokenLabelAr(currency));
}
