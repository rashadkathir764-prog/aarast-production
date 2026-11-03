part of 'aarast_dashboard_view.dart';

// b02 «المال» on the home: the plan's soft fill, «المال» with the eye that
// hides the amounts, the gap on the reading side and what is left to pay,
// in hand and promised on the far side, the four-part bar under them.
// Every number is a server field (C2): the gap is the server's shortfall,
// which already counts what was promised, so it reads «ومع الموعود ناقصك»,
// and the design's «ناقصك» without the promises and «وإذا وصل الموعود»
// wait for the server formula. «حط 450 ألف كل شهر» is dropped (b02 row).
// Every far-side line writes its figure one way, with its unit («3 مليون»,
// «250 ألف», «0 ر.ي»), never the design's bare «5.4» beside a full figure
// (V-01). Before the money in is known, the agreed line of a groom's plan
// says the mahr is inside it, on its own short line: «اتفقت على 3 مليون»
// then «مع المهر» (D79).

/// The owner's funding from the money section (`GET P/money-summary`):
/// what is in hand, what is promised and the server's shortfall.
class DashboardHomeFunding {
  const DashboardHomeFunding({
    required this.inHand,
    required this.pledged,
    required this.shortfall,
    required this.sourcesCount,
  });

  final double inHand;
  final double pledged;

  /// Agreements not covered by any source, promises counted; null once
  /// covered or before any source.
  final double? shortfall;
  final int sourcesCount;

  /// The server knows the money in only once a source is recorded.
  bool get isKnown => sourcesCount > 0 || shortfall != null;
}

class _DashboardMoneyCard extends StatefulWidget {
  const _DashboardMoneyCard({
    required this.summary,
    required this.funding,
    required this.onTap,
    this.mahr,
    this.amountsHidden = false,
    this.onToggleAmounts,
  });

  final DashboardSummary summary;
  final DashboardHomeFunding? funding;
  final VoidCallback onTap;

  /// D79: the groom's recorded mahr is inside the agreed total, so its line
  /// reads «اتفقت على X مع المهر». Null (or the bride's) adds nothing.
  final DashboardHomeMahr? mahr;

  /// G17: the phone's switch; with [onToggleAmounts] the eye flips it.
  final bool amountsHidden;
  final VoidCallback? onToggleAmounts;

  @override
  State<_DashboardMoneyCard> createState() => _DashboardMoneyCardState();
}

class _DashboardMoneyCardState extends State<_DashboardMoneyCard> {
  /// Used only where the phone has no preferences (a test or a preview).
  bool _localHidden = false;

  void _toggleAmounts() {
    final toggle = widget.onToggleAmounts;
    if (toggle != null) {
      toggle();
    } else {
      setState(() => _localHidden = !_localHidden);
    }
  }

  @override
  Widget build(BuildContext context) {
    final amountsHidden = widget.onToggleAmounts != null
        ? widget.amountsHidden
        : _localHidden;
    final summary = widget.summary;
    final currency = summary.currency;
    final agreed = dashboardAmount(summary.confirmedCostForDisplay) ?? 0;
    final paid = dashboardAmount(summary.paidForDisplay) ?? 0;
    final unpaid = agreed - paid;
    final left =
        dashboardAmount(summary.outstandingForDisplay) ??
        (unpaid < 0 ? 0.0 : unpaid);
    final funding = widget.funding;
    final known = funding != null && funding.isKnown;
    final gap = known ? funding.shortfall : null;
    final covered = known && (gap == null || gap <= 0);

    String amount(double value) =>
        amountsHidden ? '••••' : _money(value, currency);
    String figure(double value) =>
        amountsHidden ? '••••' : _figure(value, currency);

    // D59: the owner reads what is left to them; anyone else reads it as
    // the owner's, and what others paid for the owner is said as theirs.
    final leftLabel = context.ownerDid(
      'باقي تدفع',
      'باقي تدفعين',
      groom: 'باقي على العريس',
      bride: 'باقي على العروسة',
    );
    final paidByOthers =
        dashboardAmount(summary.moneySummary.paidByOthers) ?? 0;
    final paidByOwner =
        dashboardAmount(summary.moneySummary.paidByOwner) ??
        (paid - paidByOthers);
    final mahr = widget.mahr;
    final withMahr =
        mahr != null &&
        mahr.recorded &&
        mahr.side == MahrHomeSide.pays &&
        mahr.total > 0;

    final Widget lead;
    if (known && !covered) {
      lead = _MoneyLead(
        label: 'ومع الموعود ناقصك',
        value: amount(gap!),
        color: AarastV3Color.danger,
      );
    } else if (covered) {
      lead = Text(
        'فلوسك والموعود يغطون اتفاقاتك',
        key: const ValueKey('dashboard-money-covered'),
        style: JourneyType.of(
          JourneyType.lead,
          weight: JourneyType.bold,
          color: AarastV3Color.mint,
        ),
      );
    } else if (agreed <= 0) {
      lead = Text(
        context.say(
          'لسا ما سجلت اتفاقات. أول ما تتفق مع مزود، سجّله ونحسب لك الباقي.',
          'لسا ما سجلتِ اتفاقات. أول ما تتفقين مع مزود، سجّليه ونحسب لك الباقي.',
        ),
        style: JourneyType.of(
          JourneyType.bodySmall,
          color: AarastV3Color.textMuted,
        ),
      );
    } else {
      lead = _MoneyLead(
        label: leftLabel,
        value: amount(left),
        color: AarastV3Color.ink,
      );
    }

    final side = <Widget>[
      if (known) ...[
        _SideFigure('$leftLabel ${figure(left)}', AarastV3Color.ink),
        _SideFigure('معك ${figure(funding.inHand)}', context.accent.primary),
        if (funding.pledged > 0)
          _SideFigure('موعود ${figure(funding.pledged)}', AarastV3Color.lilac),
      ] else if (agreed > 0) ...[
        _SideFigure(
          '${context.ownerDid('اتفقت على', 'اتفقتِ على', groom: 'اتفق العريس على', bride: 'اتفقت العروسة على')} ${figure(agreed)}',
          AarastV3Color.ink,
        ),
        // D79, on its own short line: the side column is narrow, and the
        // figure's line never wraps around the words.
        if (withMahr) const _SideFigure('مع المهر', AarastV3Color.textMuted),
        if (paidByOwner > 0 || paidByOthers <= 0)
          _SideFigure(
            '${context.ownerDid('دفعت', 'دفعتِ', groom: 'العريس دفع', bride: 'العروسة دفعت')} ${figure(paidByOwner)}',
            context.accent.primary,
          ),
        if (paidByOthers > 0)
          _SideFigure(
            'دفع ${context.ownerDid('عنك', 'عنك', groom: 'عنه', bride: 'عنها')} ${figure(paidByOthers)}',
            context.accent.primaryDark,
          ),
      ],
    ];

    final pieces = known
        ? [
            (paid, context.accent.primary),
            (funding.inHand, context.accent.primaryMid),
            (funding.pledged, AarastV3Color.lilac.withValues(alpha: 0.5)),
            (gap ?? 0, AarastV3Color.danger),
          ]
        : [(paid, context.accent.primary), (left, context.accent.primaryMid)];

    return Semantics(
      key: const ValueKey('aarast-dashboard-money-card'),
      container: true,
      button: true,
      label: amountsHidden
          ? 'المال، المبالغ مخفية مؤقتًا'
          : [
              'المال',
              if (known && !covered)
                'ومع الموعود ناقصك ${_money(gap!, currency)}',
              if (covered) 'فلوسك والموعود يغطون اتفاقاتك',
              if (agreed > 0) '$leftLabel ${_money(left, currency)}',
              if (known) 'معك ${_money(funding.inHand, currency)}',
              if (known && funding.pledged > 0)
                'موعود ${_money(funding.pledged, currency)}',
            ].join('، '),
      child: AarastPressable(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(AarastV3Radius.feature),
        child: JourneyBox(
          color: context.accent.primarySoft,
          radius: 24,
          padding: const EdgeInsets.all(AarastV3Space.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    LucideIcons.wallet,
                    size: 17,
                    color: context.accent.primary,
                  ),
                  const SizedBox(width: AarastV3Space.x1),
                  Expanded(
                    child: Text(
                      'المال',
                      style: JourneyType.of(
                        JourneyType.bodySmall,
                        weight: JourneyType.bold,
                        color: context.accent.primary,
                      ),
                    ),
                  ),
                  // b02 draws a bare eye; the tap area is wider than it.
                  Semantics(
                    button: true,
                    label: amountsHidden ? 'إظهار المبالغ' : 'إخفاء المبالغ',
                    excludeSemantics: true,
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkResponse(
                        key: const ValueKey('dashboard-money-privacy-toggle'),
                        onTap: _toggleAmounts,
                        radius: 20,
                        child: SizedBox(
                          width: AarastV3Space.x10,
                          height: 28,
                          child: Icon(
                            amountsHidden
                                ? LucideIcons.eye
                                : LucideIcons.eyeOff,
                            color: AarastV3Color.textMuted,
                            size: 17,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AarastV3Space.x1),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(flex: 3, child: lead),
                  if (side.isNotEmpty) ...[
                    const SizedBox(width: AarastV3Space.x3),
                    Flexible(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: side,
                      ),
                    ),
                  ],
                ],
              ),
              if (pieces.any((piece) => piece.$1 > 0)) ...[
                const SizedBox(height: AarastV3Space.x3),
                _MoneySplitBar(pieces: pieces),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// «ومع الموعود ناقصك» over its 28 figure.
class _MoneyLead extends StatelessWidget {
  const _MoneyLead({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              JourneyType.amount,
              weight: JourneyType.bold,
              color: color,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

/// One line of the far column: «باقي تدفع 5.4 مليون», «معك 2.9 مليون»,
/// «موعود 250 ألف» (V-01: every line with its unit, see [_figure]).
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

/// b02's far column (V-01): every line the same way, the short figure with
/// its unit («3 مليون», «250 ألف», «0 ر.ي»), its unit kept on its line. The
/// design's bare «5.4» is dropped: beside a full figure it read as another
/// unit («اتفقت على 3» over «دفعت 250,000 ر.ي»).
String _figure(double value, String currency) {
  return compactMoneyFigure(value, currencyCode: currency);
}
