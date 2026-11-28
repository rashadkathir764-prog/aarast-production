part of 'aarast_dashboard_view.dart';

// b02 «المال» on the home: «المال» with the eye that hides the amounts, what
// is left to pay on the reading side and the money tab's own verdict (D102,
// D103, RA-MO-53), in hand and promised on the far side; then one bar and
// one row of two figures (D114): the budget and what is free of it, or with
// no budget what was agreed and paid. The card is one height whatever the
// plan holds (D113; Rashad 2026-11-27): the dues by month, the mahr's place
// and who paid are the money tab's. Every number is a server field (C2).
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
  });

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

    // RA-MO-334: one writer for the whole card. Its figures are read
    // together and add up (the lead, what is in hand, what was agreed and
    // paid), so each is shortened only when nothing is lost; the lead, alone
    // on its line, names its currency. The rounding writer wrote «500,000
    // ر.ي» over «500 ألف» and «1.3 مليون» over «1,250,000».
    String amount(double value) =>
        amountsHidden ? '••••' : _headlineFigure(value, currency);
    String figure(double value) =>
        amountsHidden ? '••••' : _sumFigure(value, currency);
    String sumFigure(double value) => figure(value);

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
        // D127 (Q-54): and says it is outside the budget, or «منها المهر 2
        // مليون» over a budget still all free read as wrong arithmetic.
        mahrInBudget: mahrInside,
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
    // The screen reader reads the cells as the screen writes them (sum-safe),
    // not rounded: it said «3.4 مليون» where the card showed 3,440,000.
    String spoken(double value) => _sumFigure(
      value,
      currency,
    ).replaceAll(currencyLabelAr(currency), currencySpokenLabelAr(currency));

    final ownerLeft = funding?.ownerLeft;
    final verdict = known ? funding.verdict : null;
    // D114: the owner's share, the mahr with it: never «من العرس». D59:
    // anyone else reads it as the owner's.
    // D127 (Q-53): the card's one lead figure, «الملخص»'s (D102): before the
    // money tab's read it stood as «باقي تدفع», every agreement left whoever
    // pays, and the figure changed under the reader's eyes once it came.
    final ownerLeftLabel = context.ownerDid(
      'باقي عليك',
      'باقي عليكِ',
      groom: 'باقي على العريس',
      bride: 'باقي على العروسة',
    );
    // What of it is the mahr (the groom's, which pays): on him whether the
    // budget holds it or not (D114), said under the figure.
    final mahrLeft = withMahr ? mahr.total - mahr.settled : 0.0;
    final agreedAny = agreed > 0;
    final ownerLead = ownerLeft != null && (agreedAny || ownerLeft > 0);
    String? leadMahr(String Function(double) write) =>
        ownerLead && mahrLeft > 0 ? 'منها المهر ${write(mahrLeft)}' : null;
    Widget? lead;
    var leadWords = const <String>[];
    // The title row names the lead figure where there is one, so «المال»
    // and «باقي عليك» are not two rows over one number.
    var title = 'المال';
    if (ownerLead) {
      title = ownerLeftLabel;
      // D102, D103: the owner reads what «الملخص» says; D113: its verdict is
      // a short tag beside the label (the whole sentence stood up to five
      // lines tall and changed the card's height; it stays on the money
      // tab). Hidden amounts hide the shortfall's figure with the rest.
      lead = _MoneyLead(
        label: ownerLeftLabel,
        showLabel: false,
        value: amount(ownerLeft),
        // Sum-safe, as the cells: it is read against the figure over it.
        note: leadMahr(figure),
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
      final noAgreement = context.say(
        'لسا ما سجلت اتفاقات. أول ما تتفق مع مزود، سجّله ونقول لك كم باقي.',
        'لسا ما سجلتِ اتفاقات. أول ما تتفقين مع مزود، سجّليه ونقول لك كم باقي.',
      );
      // The card's label says what this lead draws: its words are kept from
      // the screen reader with the rest (RA-MO-361).
      leadWords = [
        if (budget > 0) 'ميزانيتك ${_spoken(budget, currency)}',
        noAgreement,
      ];
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
            noAgreement,
            style: JourneyType.of(
              JourneyType.small,
              color: AarastV3Color.textMuted,
            ),
          ),
        ],
      );
    }
    // Else agreements and the owner's share not read yet (the money tab's
    // read on its way, or failed: the home says so): no lead rather than a
    // figure of another meaning (D127, Q-53); what was agreed and paid say
    // themselves below.

    final side = <Widget>[
      if (known) ...[
        _SideFigure('معك ${figure(funding.inHand)}', context.accent.primary),
        if (funding.pledged > 0)
          _SideFigure('موعود ${figure(funding.pledged)}', AarastV3Color.lilac),
      ],
    ];

    // D113, and Rashad on 2026-11-27 («لا نريده يكبر مع امتلاء البيانات»):
    // the card is one height whatever the plan holds. Under the lead it draws
    // one bar and one row of two figures, never more: the budget and what is
    // free of it (or how far over it), or with no budget what was agreed and
    // paid. The dues by month, the mahr's place and who paid are the money
    // tab's, one tap away, in the same words (D59).
    List<_MoneyCellData> rowCells(String Function(double) write) => [
      for (final cell in cells(write).take(2))
        _MoneyCellData(
          cell.label,
          cell.value,
          danger: cell.danger,
          joined: cell.joined,
        ),
    ];
    // The bar says what the row under it says, and nothing else.
    final used = budgetLeft == null
        ? agreed.clamp(0.0, budget).toDouble()
        : (budget - budgetLeft).clamp(0.0, budget).toDouble();
    final pieces = budget <= 0
        ? [(paid, context.accent.primary), (left, context.accent.primaryMid)]
        : over
        ? [(budget, AarastV3Color.danger)]
        : [
            (used, context.accent.primary),
            (budget - used, context.accent.primaryMid),
          ];

    // RA-MO-361: the card's words join the pressable's own node, the one
    // that holds its tap; a label over the pressable was a button of its own
    // without a tap. The words drawn are kept from the screen reader (the
    // label says them); the eye stays a button of its own inside the card.
    return AarastPressable(
      key: const ValueKey('aarast-dashboard-money-card'),
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(AarastV3Radius.card),
      child: Semantics(
        label: amountsHidden
            ? 'المال، المبالغ مخفية مؤقتًا'
            : [
                'المال',
                if (ownerLead) ...[
                  '$ownerLeftLabel ${_spoken(ownerLeft, currency)}',
                  ?leadMahr(spoken),
                ],
                ...leadWords,
                ?verdict?.words,
                if (known) 'معك ${_spoken(funding.inHand, currency)}',
                if (known && funding.pledged > 0)
                  'موعود ${_spoken(funding.pledged, currency)}',
                if (agreedAny)
                  for (final cell in rowCells(spoken)) cell.words(spoken),
              ].join('، '),
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
                    child: ExcludeSemantics(
                      child: Text(
                        title,
                        style: JourneyType.of(
                          JourneyType.small,
                          weight: JourneyType.bold,
                          color: AarastV3Color.textMuted,
                        ),
                      ),
                    ),
                  ),
                  // The eye with its word, in a 48 target of its own (D74):
                  // a miss around it opened the money tab instead. Its own
                  // node with its own tap (RA-MO-361): the InkResponse is
                  // hidden with its words.
                  Semantics(
                    container: true,
                    button: true,
                    label: amountsHidden ? 'إظهار المبالغ' : 'إخفاء المبالغ',
                    onTap: _toggleAmounts,
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
                                // As the money tab says it, to her too.
                                amountsHidden
                                    ? context.say('أظهر', 'أظهري')
                                    : context.say('أخفِ', 'أخفي'),
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
              if (lead != null || side.isNotEmpty)
                ExcludeSemantics(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(flex: 3, child: lead ?? const SizedBox.shrink()),
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
                ),
              // Before any agreement the lead is the budget itself, and it
              // stands alone.
              if (agreedAny) ...[
                if (pieces.any((piece) => piece.$1 > 0)) ...[
                  const SizedBox(height: AarastV3Space.x2),
                  _MoneySplitBar(pieces: pieces),
                ],
                const SizedBox(height: AarastV3Space.x2),
                ExcludeSemantics(
                  child: _MoneyFigures(
                    cells: rowCells(sumFigure),
                    figure: sumFigure,
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
