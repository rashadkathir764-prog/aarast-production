part of 'aarast_dashboard_view.dart';

// b02 «المال» on the home: the plan's soft fill, «المال» with the eye that
// hides the amounts, what is on the owner and the money tab's own verdict on
// the reading side (D102, D103: «عليك من العرس» and «يكفي … بمواعيدها», the
// same words as «الملخص», RA-MO-53), in hand and promised on the far side,
// the four-part bar under them. Every number is a server field (C2).
// «حط 450 ألف كل شهر» is dropped (b02 row).
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
    this.ownerLeft,
    this.verdict,
    this.dues = const [],
  });

  /// D102: what falls on the owner next ([dashboardHomeDues]); empty when
  /// the server names none.
  final List<DashboardHomeDue> dues;

  /// D102: what is on the owner, the money tab's «عليك من العرس» (his
  /// share, the mahr with it); null from a server before D102.
  final double? ownerLeft;

  /// D103: the money tab's verdict, in its words, and whether it is good
  /// news; null until the money in is known.
  final ({bool ok, String words})? verdict;

  final double inHand;
  final double pledged;

  /// Agreements not covered by any source, promises counted; null once
  /// covered or before any source.
  final double? shortfall;
  final int sourcesCount;

  /// The server knows the money in only once a source is recorded.
  bool get isKnown => sourcesCount > 0 || shortfall != null;
}

/// One piece of the home's dues strip: what is late, a coming month, or
/// everything after the wedding.
class DashboardHomeDue {
  const DashboardHomeDue({
    required this.label,
    required this.amount,
    this.overdue = false,
  });

  final String label;
  final double amount;
  final bool overdue;
}

/// The pieces the strip shows at most.
const _homeDuesShown = 3;

/// D102: what falls on the owner next, named as the money tab's «الدفعات»
/// names it: what is late first, then each coming month (with its year
/// when it is not this one), and everything after the wedding as one
/// piece. The nearest [_homeDuesShown].
List<DashboardHomeDue> dashboardHomeDues({
  required double overdue,
  required List<({DateTime month, double amount})> months,
  required DateTime? weddingDate,
  required DateTime today,
}) {
  int order(DateTime day) => day.year * 12 + day.month;
  final weddingMonth = weddingDate == null ? null : order(weddingDate);
  var afterWedding = 0.0;
  final dues = <DashboardHomeDue>[
    if (overdue > 0)
      DashboardHomeDue(label: 'متأخرة', amount: overdue, overdue: true),
  ];
  for (final due in months) {
    if (due.amount <= 0) continue;
    if (weddingMonth != null && order(due.month) > weddingMonth) {
      afterWedding += due.amount;
      continue;
    }
    dues.add(
      DashboardHomeDue(
        label: arabicMonthInYear(due.month, thisYear: today.year),
        amount: due.amount,
      ),
    );
  }
  if (afterWedding > 0) {
    dues.add(DashboardHomeDue(label: 'بعد العرس', amount: afterWedding));
  }
  return dues.take(_homeDuesShown).toList(growable: false);
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

    final ownerLeft = funding?.ownerLeft;
    final verdict = known ? funding.verdict : null;
    final Widget lead;
    // D103's verdict is the money tab's whole sentence («معك 4.2 مليون يكفي
    // دفعاتك وسداد السلفة بمواعيدها لين 1 مايو، ويبقى 2 مليون»), so its chip
    // takes the card's width under the figures; beside them it stood five
    // lines tall.
    ({bool ok, String words})? verdictShown;
    if (ownerLeft != null && (agreed > 0 || ownerLeft > 0)) {
      // D102, D103: the owner reads what «الملخص» says, in its words.
      lead = _MoneyLead(
        label: context.say('عليك من العرس', 'عليكِ من العرس'),
        value: amount(ownerLeft),
        color: AarastV3Color.ink,
      );
      verdictShown = verdict;
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
        if (ownerLeft == null)
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
              if (ownerLeft != null)
                '${context.say('عليك من العرس', 'عليكِ من العرس')} ${_spoken(ownerLeft, currency)}'
              else if (agreed > 0)
                '$leftLabel ${_spoken(left, currency)}',
              ?verdict?.words,
              if (known) 'معك ${_spoken(funding.inHand, currency)}',
              if (known && funding.pledged > 0)
                'موعود ${_spoken(funding.pledged, currency)}',
            ].join('، '),
      child: AarastPressable(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(AarastV3Radius.card),
        child: JourneyBox(
          borderColor: AarastV3Color.line,
          borderWidth: AarastV3Space.hair,
          // The title row is 48 high for its switch (D74), so the card's
          // top inset is the smaller one and the row sits where it did.
          padding: const EdgeInsetsDirectional.fromSTEB(
            AarastV3Space.x4,
            AarastV3Space.x2,
            AarastV3Space.x4,
            AarastV3Space.x4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    LucideIcons.wallet,
                    size: 17,
                    color: AarastV3Color.textMuted,
                  ),
                  const SizedBox(width: AarastV3Space.x1),
                  Expanded(
                    child: Text(
                      'المال',
                      style: JourneyType.of(
                        JourneyType.bodySmall,
                        weight: JourneyType.bold,
                        color: AarastV3Color.textMuted,
                      ),
                    ),
                  ),
                  // The eye with its word, in a 48 target of its own (D74):
                  // a miss around it opened the money tab instead.
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
                        // The eye with its word: an icon alone did not say
                        // what it does.
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minWidth: AarastV3Space.x12,
                            minHeight: AarastV3Space.x12,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                amountsHidden
                                    ? LucideIcons.eye
                                    : LucideIcons.eyeOff,
                                color: context.accent.primary,
                                size: 17,
                              ),
                              const SizedBox(width: AarastV3Space.x1),
                              Text(
                                amountsHidden ? 'أظهر' : 'أخفِ',
                                style: JourneyType.of(
                                  JourneyType.small,
                                  weight: JourneyType.bold,
                                  color: context.accent.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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
              if (verdictShown != null) ...[
                const SizedBox(height: AarastV3Space.x2),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _VerdictChip(
                    ok: verdictShown.ok,
                    words: verdictShown.words,
                  ),
                ),
              ],
              if (known && funding.dues.isNotEmpty) ...[
                const SizedBox(height: AarastV3Space.x3),
                _DuesStrip(
                  dues: funding.dues,
                  figure: figure,
                  hidden: amountsHidden,
                  color: context.accent.primary,
                  soft: context.accent.primarySoft,
                ),
              ] else if (pieces.any((piece) => piece.$1 > 0)) ...[
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
              JourneyType.headline,
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

/// The money tab's verdict as a chip: a tick on the good news, a mark on
/// the bad, the words beside it.
class _VerdictChip extends StatelessWidget {
  const _VerdictChip({required this.ok, required this.words});

  final bool ok;
  final String words;

  @override
  Widget build(BuildContext context) {
    final color = ok ? AarastV3Color.mint : AarastV3Color.danger;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ok ? AarastV3Color.mintSoft : AarastV3Color.dangerSoft,
        borderRadius: BorderRadius.circular(AarastV3Radius.control),
      ),
      child: Padding(
        padding: AarastV3Density.tagInsets,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ok ? LucideIcons.check : LucideIcons.alertCircle,
              size: AarastV3Icon.sm,
              color: color,
            ),
            const SizedBox(width: AarastV3Space.x1),
            Flexible(
              child: Text(
                words,
                key: const ValueKey('dashboard-money-verdict'),
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
