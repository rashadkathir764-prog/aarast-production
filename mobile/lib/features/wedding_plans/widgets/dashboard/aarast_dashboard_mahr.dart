part of 'aarast_dashboard_view.dart';

/// A fixed dimension of this layout, not a spacing step (D74).
const _mahrShareWidth = 56.0;

// The mahr on the home (a06, C1): b01's second step and b02's agreement
// card. Every number is the server's (the money section's `mahr`); the card
// leaves the home once the mahr is complete (y08: «نخفي بطاقة المهر من
// الرئيسية، وتلقاها في المال»).

enum MahrHomeSide { pays, receives }

/// The plan's mahr as the home reads it: [recorded] is false when the plan
/// (a groom's or a bride's) has no mahr yet, so b01's step stays to take.
class DashboardHomeMahr {
  const DashboardHomeMahr({
    required this.side,
    required this.recorded,
    this.total = 0,
    this.settled = 0,
    this.nextDueAt,
    this.complete = false,
  });

  /// A groom's or a bride's plan without its mahr yet.
  const DashboardHomeMahr.notRecorded(this.side)
    : recorded = false,
      total = 0,
      settled = 0,
      nextDueAt = null,
      complete = false;

  final MahrHomeSide side;
  final bool recorded;
  final double total;

  /// Handed over (the groom) or received (the bride).
  final double settled;
  final DateTime? nextDueAt;
  final bool complete;
}

/// «3 مليون», «500,000»: an amount in a home line, without the currency.
String mahrHomeWords(double amount) {
  final parts = compactMoneyParts(amount, currencyCode: 'YER');
  final unit = parts.millionUnit;
  return unit == null ? parts.number : '${parts.number} $unit';
}

/// «2» of «سلّمت 2 من 3 مليون»: the number alone.
String mahrHomeNumber(double amount) =>
    compactMoneyParts(amount, currencyCode: 'YER').number;

/// What was handed over, as [mahrHomeNumber] says it, unless that reads as
/// the whole while some is left: 2,960,000 of 3 million read «سلّمت 3 من 3
/// مليون», as if done. Then it is rounded down, never up: «2.9».
String mahrSettledNumber(double settled, double total) {
  final short = mahrHomeNumber(settled);
  if (settled >= total || short != mahrHomeNumber(total)) return short;
  final step = total >= 1000000 ? 100000 : 1000;
  return mahrHomeNumber((settled / step).floor() * step.toDouble());
}

bool _fitsOneLine(
  BuildContext context,
  String text,
  TextStyle style,
  BoxConstraints box,
) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout(maxWidth: box.maxWidth);
  final fits = !painter.didExceedMaxLines;
  painter.dispose();
  return fits;
}

/// b02 «الاتفاق مع أهل العروسة · سلّمت 2 من 3 مليون · الباقي 15 نوفمبر»,
/// or the bride's «الاتفاق مع العريس · استلمتِ 2 من 3 مليون».
class _MahrAgreementCard extends StatelessWidget {
  const _MahrAgreementCard({
    required this.mahr,
    required this.onTap,
    this.hidden = false,
  });

  final DashboardHomeMahr mahr;
  final VoidCallback onTap;

  /// «أخفِ المبالغ»: the mahr is an amount like the others. The card used
  /// to show it, and its bar the share handed over, beside a money card
  /// reading «••••» (RA-MO-136).
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final pays = mahr.side == MahrHomeSide.pays;
    final due = mahr.nextDueAt;
    final verb = pays
        ? context.say('سلّمت', 'سلّمتِ')
        : context.say('استلمت', 'استلمتِ');
    final settled = hidden
        ? '$verb ••••'
        : '$verb ${mahrSettledNumber(mahr.settled, mahr.total)} '
              'من ${mahrHomeWords(mahr.total)}';
    final rest = due == null ? null : 'الباقي ${formatArabicDayMonth(due)}';
    final line = rest == null ? settled : '$settled · $rest';
    final lineStyle = JourneyType.of(
      JourneyType.body,
      weight: JourneyType.bold,
    );
    final label = pays ? 'الاتفاق مع أهل العروسة' : 'الاتفاق مع العريس';
    final ratio = mahr.total <= 0
        ? 0.0
        : (mahr.settled / mahr.total).clamp(0.0, 1.0).toDouble();
    return Semantics(
      button: true,
      label: '$label، $line',
      onTap: onTap,
      excludeSemantics: true,
      child: AarastPressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AarastV3Radius.card),
        child: JourneyBox(
          key: const ValueKey('aarast-dashboard-mahr-card'),
          padding: const EdgeInsets.all(AarastV3Space.x3),
          child: Row(
            children: [
              JourneyIconTile(
                icon: LucideIcons.heartHandshake,
                color: context.accent.primary,
                soft: context.accent.primarySoft,
              ),
              const SizedBox(width: AarastV3Space.x3),
              Expanded(
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
                    // One line where it fits; where it does not, each
                    // half takes its own line, so the «·» never dangles
                    // at a line's end (RA-MO-130).
                    LayoutBuilder(
                      builder: (context, box) {
                        if (rest == null ||
                            _fitsOneLine(context, line, lineStyle, box)) {
                          return Text(line, style: lineStyle);
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(settled, style: lineStyle),
                            Text(rest, style: lineStyle),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              if (!hidden) ...[
                const SizedBox(width: AarastV3Space.x3),
                SizedBox(
                  width: _mahrShareWidth,
                  child: JourneyBar(
                    value: ratio,
                    color: context.accent.primary,
                    height: 6,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
