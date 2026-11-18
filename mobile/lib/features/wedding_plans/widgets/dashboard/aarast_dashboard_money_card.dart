part of 'aarast_dashboard_view.dart';

// b02 «المال» on the home: the plan's soft fill, «المال» with the eye that
// hides the amounts, what is left to pay on the reading side and the money
// tab's own verdict (D102, D103, RA-MO-53), in hand and promised on the far
// side, the dues strip or the bar under them; then the budget's figures
// (D114): the budget, what is left of it, what was agreed and paid, and the
// mahr in its place. Every number is a server field (C2).
// «حط 450 ألف كل شهر» is dropped (b02 row).
// Every figure is written one way, with its unit («3 مليون», «250 ألف»,
// «0 ر.ي»), never the design's bare «5.4» beside a full figure (V-01).

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

  /// D102: what is on the owner, the money tab's «باقي عليك» (his share,
  /// the mahr with it); null from a server before D102.
  final double? ownerLeft;

  /// D113: the money tab's verdict as a short tag («تكفي», «تكفي بشرط
  /// الموعود», «ينقصك X»), whether it is good news and whether it rests on
  /// promised money; null until the money in is known.
  final ({bool ok, bool conditional, String words})? verdict;

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
    this.mahrCardShown = false,
  });

  /// The home draws the mahr's own card over this one: its line is left out.
  final bool mahrCardShown;

  final DashboardSummary summary;
  final DashboardHomeFunding? funding;
  final VoidCallback onTap;

  /// D79, D114: the groom's recorded mahr is inside what he agreed. With the
  /// budget holding it, «اتفقت على» says «منها المهر»; with the mahr on its
  /// own, it has its own line. Null (or the bride's) adds nothing.
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
    String sumFigure(double value) =>
        amountsHidden ? '••••' : _sumFigure(value, currency);

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
    final mahrInside = withMahr && summary.budgetIncludesMahr;

    // D114: the budget is said once there is one, whatever was agreed.
    final budget = dashboardAmount(summary.totalBudgetForDisplay) ?? 0;
    final over = budget > 0 && summary.moneySummary.overBudget == true;
    final overBy = over
        ? dashboardAmount(
            summary.financialWarnings
                .where((warning) => warning.type == 'BUDGET_EXCEEDED')
                .firstOrNull
                ?.amount,
          )
        : null;
    final budgetLeft = dashboardAmount(summary.remainingBudgetForDisplay);
    // The budget's figures, then what was agreed and paid, and the mahr on
    // its own line: the money tab's own writer, so the two never differ.
    // [write] writes each amount, for the screen or for the screen reader.
    List<_MoneyCellData> cells(String Function(double) write) => [
      for (final cell in moneyBudgetCells(
        context,
        budget: budget,
        budgetLeft: budgetLeft,
        over: over,
        overBy: overBy,
        agreed: agreed,
        paidByOwner: paidByOwner,
        paidByOthers: paidByOthers,
        // D79: «اتفقت على» holds the mahr. Its own line says so outside the
        // budget; where the mahr's card hides that line (2026-11-17), the
        // agreed figure says it itself, or 3 million read as his agreements
        // with 1 million agreed (walks 2026-11-18).
        mahrInside: mahrInside || (withMahr && widget.mahrCardShown)
            ? mahr.total
            : null,
        figure: (value) => write(value.toDouble()),
      ))
        _MoneyCellData(
          cell.label,
          cell.value?.toDouble(),
          note: cell.note,
          danger: cell.danger,
          joined: cell.joined,
        ),
    ];
    // Where the mahr's own card stands over this one, its line here said the
    // same thing twice on one screen (Rashad 2026-11-17).
    String? mahrLine(String Function(double) write) =>
        withMahr && !mahrInside && !widget.mahrCardShown
        ? mahrOnItsOwnWords(
            context,
            total: mahr.total,
            settled: mahr.settled,
            left: mahr.total - mahr.settled,
            hasBudget: budget > 0,
            figure: (value) => write(value.toDouble()),
          )
        : null;
    String spoken(double value) => _spokenFigure(value, currency);

    final ownerLeft = funding?.ownerLeft;
    final verdict = known ? funding.verdict : null;
    // D114: the owner's share, the mahr with it: never «من العرس».
    final ownerLeftLabel = context.say('باقي عليك', 'باقي عليكِ');
    final Widget lead;
    final agreedAny = agreed > 0;
    // The title row names the lead figure where there is one, so «المال»
    // and «باقي عليك» are not two rows over one number.
    var title = 'المال';
    if (ownerLeft != null && (agreedAny || ownerLeft > 0)) {
      title = ownerLeftLabel;
      // D102, D103: the owner reads what «الملخص» says; D113: its verdict is
      // a short tag beside the label (the whole sentence stood up to five
      // lines tall and changed the card's height; it stays on the money
      // tab). Hidden amounts hide the shortfall's figure with the rest.
      lead = _MoneyLead(
        label: ownerLeftLabel,
        showLabel: false,
        value: amount(ownerLeft),
        color: AarastV3Color.ink,
        tag: verdict == null
            ? null
            : _VerdictChip(
                ok: verdict.ok,
                conditional: verdict.conditional,
                words: verdict.words,
              ),
      );
    } else if (!agreedAny) {
      // RA-MO-115: «جاهزة» promised «نقول لك كم باقي من الميزانية», and the
      // card then never named the budget that was just typed.
      lead = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (budget > 0)
            _MoneyLead(
              key: const ValueKey('aarast-money-budget-before-agreements'),
              label: 'ميزانيتك',
              value: amount(budget),
              color: AarastV3Color.ink,
            ),
          Text(
            context.say(
              'لسا ما سجلت اتفاقات. أول ما تتفق مع مزود، سجّله ونقول لك كم باقي.',
              'لسا ما سجلتِ اتفاقات. أول ما تتفقين مع مزود، سجّليه ونقول لك كم باقي.',
            ),
            style: JourneyType.of(
              JourneyType.small,
              color: AarastV3Color.textMuted,
            ),
          ),
        ],
      );
    } else {
      title = leftLabel;
      lead = _MoneyLead(
        label: leftLabel,
        showLabel: false,
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
                '$ownerLeftLabel ${_spoken(ownerLeft, currency)}'
              else if (agreedAny)
                '$leftLabel ${_spoken(left, currency)}',
              ?verdict?.words,
              if (known) 'معك ${_spoken(funding.inHand, currency)}',
              if (known && funding.pledged > 0)
                'موعود ${_spoken(funding.pledged, currency)}',
              if (agreedAny) ...[
                for (final cell in cells(spoken)) ...[
                  cell.words(spoken),
                  ?cell.note,
                ],
                ?mahrLine(spoken),
              ],
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
            AarastV3Space.x3,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    LucideIcons.wallet,
                    size: AarastV3Icon.sm,
                    color: AarastV3Color.textMuted,
                  ),
                  const SizedBox(width: AarastV3Space.x1),
                  Expanded(
                    child: Text(
                      title,
                      style: JourneyType.of(
                        JourneyType.small,
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
                                size: AarastV3Icon.sm,
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
                const SizedBox(height: AarastV3Space.x2),
                _MoneySplitBar(pieces: pieces),
                // What the bar measures: it was drawn without a word.
                if (!known && agreedAny) ...[
                  const SizedBox(height: AarastV3Space.x1),
                  Text(
                    '${context.ownerDid('دفعت', 'دفعتِ', groom: 'دفع العريس', bride: 'دفعت العروسة')} ${figure(paid)} من ${figure(agreed)}',
                    key: const ValueKey('dashboard-money-bar-caption'),
                    style: JourneyType.of(
                      JourneyType.caption,
                      color: AarastV3Color.textMuted,
                    ),
                  ),
                ],
              ],
              // Before any agreement the lead is the budget itself. No rule
              // between them: the gap says it, in less height.
              if (agreedAny) ...[
                const SizedBox(height: AarastV3Space.x2),
                ExcludeSemantics(
                  child: _MoneyFigures(
                    cells: cells(sumFigure),
                    figure: sumFigure,
                    mahrLine: mahrLine(sumFigure),
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
