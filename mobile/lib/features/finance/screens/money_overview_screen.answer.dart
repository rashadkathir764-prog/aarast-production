part of 'money_overview_screen.dart';

// D102 «الملخص» (the approved money concept, V3.1, 2026-11-09). Three things
// that are never added together: what is on the owner (his share, the mahr
// with it), what is left on the wedding (everyone's share), and the loans he
// returns. Then whether his money covers what is on him, in time (D103),
// worked out by the server (C2). In the order a groom asks: is anything
// late? how much is on me, and do I have it? what comes next? what is
// waiting for me? what will the whole wedding cost?

String _figure(BuildContext context, Object? value, String currency) =>
    keepCurrencyOnLine(_amount(context, value, currency));

String _dayWords(DateTime day) => formatArabicDayMonth(day);

/// «بعد 5 أيام», «بكرة», «اليوم», «متأخرة 3 أيام».
String _whenWords(DateTime day) {
  final days = daysUntilPlanDay(day);
  if (days < 0) return 'متأخرة ${arabicDays(-days)}';
  if (days == 0) return 'اليوم';
  if (days == 1) return 'بكرة';
  return 'بعد ${arabicDays(days)}';
}

String _payerOf(BuildContext context, MoneyObligation line) {
  final profile = context.journeyProfile;
  if (line.ownerMoney) {
    return profile.readerIsOwner
        ? context.say('عليك', 'عليكِ')
        : 'على ${context.planWord('العريس', 'العروسة')}';
  }
  final label = payerLabel(
    line.payer,
    line.payerName,
    bridePlan: profile.isBride,
    owner: profile.readerIsOwner,
  );
  return 'على $label';
}

/// The wedding's dues (loans apart, D102), in date order.
List<MoneyObligation> _weddingDues(MoneySummary summary) => [
  for (final line in summary.obligations)
    if (line.kind == MoneyObligationKind.due) line,
];

/// 1. The one loud card: a wedding due that is late.
class _LateDueCard extends StatelessWidget {
  const _LateDueCard({
    required this.line,
    required this.others,
    required this.currency,
    required this.onPay,
    required this.onMove,
  });

  final MoneyObligation line;
  final int others;
  final String currency;
  final VoidCallback? onPay;
  final VoidCallback? onMove;

  @override
  Widget build(BuildContext context) {
    final due = line.dueDate!;
    return JourneyBox(
      key: const ValueKey('money-late-due'),
      color: AarastV3Color.dangerSoft,
      borderColor: AarastV3Color.danger.withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.alertCircle,
                size: 16,
                color: AarastV3Color.danger,
              ),
              const SizedBox(width: AarastV3Space.x1),
              Flexible(
                child: Text(
                  '${_whenWords(due)}${others > 0 ? ' · و${arabicCount(others, one: 'وحدة غيرها', two: 'ثنتين غيرها', few: 'غيرها', many: 'غيرها')}' : ''}',
                  style: JourneyType.of(
                    JourneyType.small,
                    weight: JourneyType.bold,
                    color: AarastV3Color.danger,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AarastV3Space.x2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.title,
                      style: JourneyType.of(
                        JourneyType.title,
                        weight: JourneyType.bold,
                      ),
                    ),
                    const SizedBox(height: AarastV3Space.x1),
                    Text(
                      [
                        ?line.note,
                        'موعدها ${formatArabicWeekdayDayMonth(due)}',
                        _payerOf(context, line),
                      ].join(' · '),
                      style: JourneyType.of(
                        JourneyType.small,
                        color: AarastV3Color.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AarastV3Space.x2),
              // Half the width at most: a long figure or a large font wraps
              // it, never pushes the name off the card.
              Flexible(
                child: Text(
                  _figure(context, line.amount, currency),
                  textAlign: TextAlign.end,
                  style: JourneyType.of(
                    JourneyType.figure,
                    weight: JourneyType.bold,
                  ),
                ),
              ),
            ],
          ),
          if (onPay != null || onMove != null) ...[
            const SizedBox(height: AarastV3Space.x3),
            Wrap(
              spacing: AarastV3Space.x2,
              runSpacing: AarastV3Space.x2,
              children: [
                if (onPay case final onPay?)
                  JourneyButton(
                    key: const ValueKey('money-late-pay'),
                    label: context.say('سجّل الدفعة', 'سجّلي الدفعة'),
                    onPressed: onPay,
                    background: AarastV3Color.danger,
                  ),
                if (onMove case final onMove?)
                  JourneyButton.outline(
                    key: const ValueKey('money-late-move'),
                    label: context.say(
                      'اتفقتوا على موعد ثاني؟',
                      'اتفقتوا على موعد ثاني؟',
                    ),
                    onPressed: onMove,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 2. What is on the owner (D102), and whether the money covers it (D103).
/// A reader who is not the owner reads what is left on the wedding, by whom.
class _ShareHero extends StatelessWidget {
  const _ShareHero({
    required this.summary,
    required this.onHowCounted,
    required this.onSources,
  });

  final MoneySummary summary;
  final VoidCallback onHowCounted;
  final VoidCallback? onSources;

  @override
  Widget build(BuildContext context) {
    final profile = context.journeyProfile;
    final currency = summary.currency;
    final outstanding = summary.outstanding;
    final onColour = AarastV3Color.onPrimary;
    final soft = context.accent.onPrimaryMuted;
    final owner = profile.readerIsOwner;
    final lead = owner
        ? (outstanding?.owner ?? summary.costs.outstanding)
        : (outstanding?.total ?? summary.costs.outstanding);
    // D79: the groom's mahr is its own part of the lead. Beside his
    // agreements, each with its figure; when it is all of it, said
    // without the lead's figure twice; with no mahr, the lead says it all.
    final ownerMahr = moneyValue(outstanding?.ownerMahr);
    final ownerAgreements = moneyValue(outstanding?.owner) - ownerMahr;
    final chips = <String>[
      if (owner && outstanding != null) ...[
        if (ownerMahr > 0 && ownerAgreements > 0) ...[
          'باقي المهر ${_figure(context, outstanding.ownerMahr, currency)}',
          'اتفاقاتك ${_figure(context, ownerAgreements, currency)}',
        ] else if (ownerMahr > 0)
          'كله باقي المهر',
      ] else
        for (final group in summary.payers)
          if (moneyValue(group.outstanding) > 0)
            '${group.ownerMoney ? 'على ${profile.plan('العريس', 'العروسة')}' : 'على ${payerLabel(group.payer, group.payerName, bridePlan: profile.isBride, owner: false)}'} ${_figure(context, group.outstanding, currency)}',
    ];
    final coverage = summary.coverage;
    return JourneyBox(
      key: const ValueKey('money-share-hero'),
      color: context.accent.primary,
      radius: AarastV3Radius.feature,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            owner
                ? context.say('عليك من العرس', 'عليكِ من العرس')
                : 'باقي على العرس',
            style: JourneyType.of(JourneyType.detail, color: soft),
          ),
          const SizedBox(height: AarastV3Space.x1),
          Text(
            _figure(context, lead, currency),
            key: const ValueKey('money-share-figure'),
            style: JourneyType.of(
              JourneyType.headline,
              weight: JourneyType.bold,
              color: onColour,
            ),
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: AarastV3Space.x2),
            Wrap(
              spacing: AarastV3Space.x3,
              runSpacing: AarastV3Space.x1,
              children: [
                for (final chip in chips)
                  Text(
                    chip,
                    style: JourneyType.of(JourneyType.small, color: soft),
                  ),
              ],
            ),
          ],
          if (owner) ...[
            const SizedBox(height: AarastV3Space.x3),
            Divider(height: 1, color: soft.withValues(alpha: 0.3)),
            const SizedBox(height: AarastV3Space.x3),
            if (coverage == null)
              _CoverWords(
                key: const ValueKey('money-cover-unknown'),
                ok: false,
                main: context.say(
                  'ما نقدر نقول تكفي فلوسك ولا لا: ما سجلت من وين فلوسك',
                  'ما نقدر نقول تكفي فلوسك ولا لا: ما سجلتِ من وين فلوسك',
                ),
                sub: '',
                onTap: onSources,
              )
            else
              Builder(
                builder: (context) {
                  final words = moneyCoverWords(
                    context,
                    coverage,
                    (value) => _figure(context, value, summary.currency),
                  );
                  return _CoverWords(
                    key: const ValueKey('money-cover'),
                    ok: words.ok,
                    main: words.main,
                    sub: words.sub,
                    howCounted: onHowCounted,
                  );
                },
              ),
          ],
        ],
      ),
    );
  }
}

class _CoverWords extends StatelessWidget {
  const _CoverWords({
    required this.ok,
    required this.main,
    required this.sub,
    this.howCounted,
    this.onTap,
    super.key,
  });

  final bool ok;
  final String main;
  final String sub;
  final VoidCallback? howCounted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final onColour = AarastV3Color.onPrimary;
    final soft = context.accent.onPrimaryMuted;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              ok ? LucideIcons.checkCircle2 : LucideIcons.alertCircle,
              size: 18,
              color: onColour,
            ),
            const SizedBox(width: AarastV3Space.x2),
            Expanded(
              child: Text(
                main,
                style: JourneyType.of(
                  JourneyType.body,
                  weight: JourneyType.bold,
                  color: onColour,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
        if (sub.isNotEmpty) ...[
          const SizedBox(height: AarastV3Space.x1),
          Text(
            sub,
            style: JourneyType.of(JourneyType.small, color: soft, height: 1.6),
          ),
        ],
        if (howCounted case final howCounted?)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: JourneyTextAction(
              key: const ValueKey('money-how-counted'),
              label: 'كيف حسبناها؟',
              onPressed: howCounted,
              color: onColour,
            ),
          ),
      ],
    );
    if (onTap == null) return body;
    // No ink: money sits inside the home's tab, with no Material above it.
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: body,
      ),
    );
  }
}

/// 3. The first days: three steps, until all three are done.
class _FirstSteps extends StatelessWidget {
  const _FirstSteps({
    required this.estimated,
    required this.sourced,
    required this.agreed,
    required this.onItems,
    required this.onSources,
    required this.onAgreement,
  });

  final bool estimated;
  final bool sourced;
  final bool agreed;
  final VoidCallback onItems;
  final VoidCallback onSources;
  final VoidCallback onAgreement;

  @override
  Widget build(BuildContext context) {
    final steps = [
      (
        done: estimated,
        title: context.say('قدّر تكلفة البنود', 'قدّري تكلفة البنود'),
        sub: 'رقم تقريبي يكفي، ونقارنه بميزانيتك',
        action: 'افتح البنود',
        onTap: onItems,
      ),
      (
        done: sourced,
        title: context.say('سجّل من وين فلوسك', 'سجّلي من وين فلوسك'),
        sub: 'مدخرات، دعم الأهل، سلفة، أو وعد',
        action: context.say('سجّل فلوس', 'سجّلي فلوس'),
        onTap: onSources,
      ),
      (
        done: agreed,
        title: context.say('سجّل أول اتفاق', 'سجّلي أول اتفاق'),
        sub: 'القاعة غالبًا أول شي يتفقوا عليه',
        action: context.say('سجّل اتفاق', 'سجّلي اتفاق'),
        onTap: onAgreement,
      ),
    ];
    return Column(
      key: const ValueKey('money-first-steps'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const JourneySectionTitle('ثلاث خطوات وترتب فلوس عرسك'),
        JourneyList(
          children: [
            for (final (index, step) in steps.indexed)
              JourneyListRow(
                key: ValueKey('money-first-step-$index'),
                icon: step.done ? LucideIcons.check : LucideIcons.circle,
                color: step.done ? AarastV3Color.mint : context.accent.primary,
                soft: step.done
                    ? AarastV3Color.mintSoft
                    : context.accent.primarySoft,
                title: step.title,
                subtitle: step.done ? 'تم' : step.sub,
                trailing: step.done
                    ? null
                    : Text(
                        step.action,
                        style: JourneyType.of(
                          JourneyType.small,
                          weight: JourneyType.bold,
                          color: context.accent.primary,
                        ),
                      ),
                onTap: step.done ? null : step.onTap,
              ),
          ],
        ),
      ],
    );
  }
}

/// 4. The wedding's coming dues, each saying whose it is.
class _ComingDues extends StatelessWidget {
  const _ComingDues({
    required this.lines,
    required this.currency,
    required this.onAll,
    required this.onOpen,
  });

  final List<MoneyObligation> lines;
  final String currency;
  final VoidCallback onAll;
  final void Function(MoneyObligation line) onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('money-coming-dues'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JourneySectionTitle(
          'دفعات العرس الجاية',
          action: 'كلها',
          onAction: onAll,
        ),
        JourneyList(
          children: [
            for (final line in lines)
              JourneyListRow(
                key: ValueKey('money-coming-due-${line.id}'),
                icon: LucideIcons.calendarClock,
                color: daysUntilPlanDay(line.dueDate!) <= 7
                    ? AarastV3Color.amber
                    : context.accent.primary,
                soft: daysUntilPlanDay(line.dueDate!) <= 7
                    ? AarastV3Color.amberSoft
                    : context.accent.primarySoft,
                title: line.title,
                subtitleMaxLines: 2,
                subtitle: [
                  _whenWords(line.dueDate!),
                  if (line.isPartlyPaid)
                    'اندفع ${_figure(context, line.paidTowards, currency)} من ${_figure(context, line.scheduledAmount, currency)}'
                  else
                    ?line.note,
                  _payerOf(context, line),
                ].join(' · '),
                trailing: Text(
                  _figure(context, line.amount, currency),
                  style: JourneyType.of(
                    JourneyType.body,
                    weight: JourneyType.bold,
                  ),
                ),
                onTap: () => onOpen(line),
              ),
          ],
        ),
      ],
    );
  }
}

/// 5. What needs the owner, apart from paying.
class _NeedsAttention extends StatefulWidget {
  const _NeedsAttention({required this.items});

  final List<
    ({
      String key,
      IconData icon,
      Color color,
      Color soft,
      String title,
      String sub,
      VoidCallback? onTap,
    })
  >
  items;

  @override
  State<_NeedsAttention> createState() => _NeedsAttentionState();
}

class _NeedsAttentionState extends State<_NeedsAttention> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final shown = _all ? widget.items : widget.items.take(3).toList();
    return Column(
      key: const ValueKey('money-needs-attention'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JourneySectionTitle(
          context.say('يحتاج انتباهك', 'يحتاج انتباهكِ'),
          action: widget.items.length > 3
              ? (_all ? 'أقل' : 'الكل (${widget.items.length})')
              : null,
          onAction: widget.items.length > 3
              ? () => setState(() => _all = !_all)
              : null,
        ),
        JourneyList(
          children: [
            for (final item in shown)
              JourneyListRow(
                key: ValueKey('money-attention-${item.key}'),
                icon: item.icon,
                color: item.color,
                soft: item.soft,
                title: item.title,
                subtitleMaxLines: 2,
                subtitle: item.sub,
                onTap: item.onTap,
              ),
          ],
        ),
      ],
    );
  }
}

/// 6. The whole picture: three things, three rows, one figure each.
class _WholePicture extends StatelessWidget {
  const _WholePicture({
    required this.summary,
    required this.onPayments,
    required this.onSources,
    required this.onItems,
  });

  final MoneySummary summary;
  final VoidCallback onPayments;
  final VoidCallback? onSources;
  final VoidCallback onItems;

  @override
  Widget build(BuildContext context) {
    final currency = summary.currency;
    final profile = context.journeyProfile;
    final outstanding = summary.outstanding;
    final expected = summary.expected;
    String money(Object? value) => _figure(context, value, currency);
    final others = [
      for (final group in summary.payers)
        if (!group.ownerMoney && moneyValue(group.outstanding) > 0)
          'على ${payerLabel(group.payer, group.payerName, bridePlan: profile.isBride, owner: profile.readerIsOwner)} ${money(group.outstanding)}',
    ];
    final total = outstanding?.total ?? summary.costs.outstanding;
    final loanLeft = moneyValue(summary.funding?.loanOutstanding);
    final repayments = [
      for (final line in summary.obligations)
        if (line.kind == MoneyObligationKind.loanRepayment &&
            line.dueDate != null)
          line.dueDate!,
    ];
    final unknown = expected?.wedding.unknownCount ?? 0;
    final completeness = unknown > 0
        ? '${arabicCount(unknown, one: 'بند واحد', two: 'بندين', few: 'بنود', many: 'بند')} بدون تقدير'
        : 'حسب بنودك';
    Widget end(String figure, [String? under]) => Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          figure,
          style: JourneyType.of(JourneyType.body, weight: JourneyType.bold),
        ),
        if (under case final under?)
          Text(
            under,
            style: JourneyType.of(
              JourneyType.caption,
              color: AarastV3Color.textMuted,
            ),
          ),
      ],
    );
    return Column(
      key: const ValueKey('money-whole-picture'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const JourneySectionTitle('الصورة كاملة'),
        JourneyList(
          children: [
            JourneyListRow(
              key: const ValueKey('money-whole-left'),
              icon: LucideIcons.fileSignature,
              color: context.accent.primary,
              soft: context.accent.primarySoft,
              title: 'باقي على العرس كله',
              // Who it is on; all of it on him is said, not its figure
              // again (the row's own figure, and the card's above).
              subtitleMaxLines: 2,
              subtitle: moneyValue(total) <= 0
                  ? 'ما في اتفاقات عليها باقي'
                  : others.isEmpty && profile.readerIsOwner
                  ? context.say('كله عليك', 'كله عليكِ')
                  : [
                      if (outstanding != null &&
                          profile.readerIsOwner &&
                          moneyValue(outstanding.owner) > 0)
                        '${context.say('عليك', 'عليكِ')} ${money(outstanding.owner)}',
                      ...others,
                    ].join(' · '),
              trailing: end(money(total)),
              onTap: onPayments,
            ),
            if (loanLeft > 0)
              JourneyListRow(
                key: const ValueKey('money-whole-loans'),
                icon: LucideIcons.coins,
                color: AarastV3Color.lilac,
                soft: AarastV3Color.lilacSoft,
                title: 'سلف ترجعها',
                subtitleMaxLines: 2,
                // The owner's debt, said to the reader as «الدفعات» says it.
                subtitle:
                    '${context.ownerDid('دين عليك', 'دين عليكِ', groom: 'دين على العريس', bride: 'دين على العروسة')}، ${repayments.isEmpty ? 'بدون مواعيد سداد' : 'من ${_dayWords(repayments.first)} لين ${_dayWords(repayments.last)}'}',
                trailing: end(money(loanLeft)),
                onTap: onSources,
              ),
            JourneyListRow(
              key: const ValueKey('money-whole-cost'),
              icon: LucideIcons.tag,
              color: AarastV3Color.amber,
              soft: AarastV3Color.amberSoft,
              title: 'تكلفة العرس المسجّلة',
              subtitleMaxLines: 2,
              subtitle: [
                summary.budget.total == null
                    ? context.say('ما حطيت ميزانية', 'ما حطيتِ ميزانية')
                    : 'الميزانية ${money(summary.budget.total)} لبنود العرس',
                completeness,
              ].join(' · '),
              trailing: expected == null
                  ? end(money(summary.costs.total))
                  : end(
                      money(expected.total),
                      unknown > 0 ? 'مو نهائية' : 'لين الحين',
                    ),
              onTap: onItems,
            ),
          ],
        ),
      ],
    );
  }
}

/// «كيف حسبناها؟»: from what he holds, line by line on its day (D103).
class _HowWeCountedSheet extends StatelessWidget {
  const _HowWeCountedSheet({required this.summary, required this.coverage});

  final MoneySummary summary;
  final MoneyCoverage coverage;

  @override
  Widget build(BuildContext context) {
    final currency = summary.currency;
    String money(Object? value) => _figure(context, value, currency);
    final words = moneyCoverWords(
      context,
      coverage,
      (value) => _figure(context, value, summary.currency),
    );
    final profile = context.journeyProfile;
    final others = [
      for (final group in summary.payers)
        if (!group.ownerMoney && moneyValue(group.outstanding) > 0)
          '${payerLabel(group.payer, group.payerName, bridePlan: profile.isBride, owner: profile.readerIsOwner)} (${money(group.outstanding)})',
    ];
    final estimates = moneyValue(coverage.estimatesLeft);
    String kindWord(MoneyCoverageStep step) => switch (step.kind) {
      MoneyCoverageStepKind.pledge => 'موعود يوصل',
      MoneyCoverageStepKind.loanRepayment ||
      MoneyCoverageStepKind.loanUnplanned => 'سداد دين',
      MoneyCoverageStepKind.mahr => 'المهر',
      _ => 'دفعة اتفاق',
    };
    return JourneySheetBody(
      title: 'كيف حسبناها؟',
      subtitle: 'بدأنا من اللي معك الحين، ومشينا على اللي عليك بمواعيده.',
      children: [
        JourneyBox(
          color: AarastV3Color.paperQuiet,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'معك الحين',
                  style: JourneyType.of(JourneyType.body),
                ),
              ),
              Flexible(
                child: Text(
                  money(coverage.cash),
                  textAlign: TextAlign.end,
                  style: JourneyType.of(
                    JourneyType.figure,
                    weight: JourneyType.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AarastV3Space.x3),
        JourneyList(
          children: [
            for (final (index, step) in coverage.steps.indexed)
              JourneyListRow(
                key: ValueKey('money-counted-step-$index'),
                icon: step.inflow
                    ? LucideIcons.arrowDownLeft
                    : LucideIcons.arrowUpRight,
                color: moneyValue(step.balance) < 0
                    ? AarastV3Color.danger
                    : step.inflow
                    ? AarastV3Color.mint
                    : context.accent.primary,
                soft: moneyValue(step.balance) < 0
                    ? AarastV3Color.dangerSoft
                    : step.inflow
                    ? AarastV3Color.mintSoft
                    : context.accent.primarySoft,
                title: step.title,
                subtitle: [
                  step.date == null ? 'بدون موعد' : _dayWords(step.date!),
                  kindWord(step),
                  if (step.late) 'متأخرة، حسبناها اليوم',
                ].join(' · '),
                trailing: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${step.inflow ? '+' : '−'}${money(step.amount)}',
                      style: JourneyType.of(
                        JourneyType.body,
                        weight: JourneyType.bold,
                        color: step.inflow
                            ? AarastV3Color.mint
                            : AarastV3Color.ink,
                      ),
                    ),
                    Text(
                      'يبقى ${money(step.balance)}',
                      style: JourneyType.of(
                        JourneyType.caption,
                        color: moneyValue(step.balance) < 0
                            ? AarastV3Color.danger
                            : AarastV3Color.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: AarastV3Space.x3),
        JourneyNote(
          icon: words.ok ? LucideIcons.checkCircle2 : LucideIcons.alertCircle,
          color: words.ok ? AarastV3Color.mint : AarastV3Color.danger,
          soft: words.ok ? AarastV3Color.mintSoft : AarastV3Color.dangerSoft,
          text: [words.main, if (words.sub.isNotEmpty) words.sub].join('\n'),
        ),
        const SizedBox(height: AarastV3Space.x3),
        Text(
          'ايش ما حسبناه:',
          style: JourneyType.of(JourneyType.detail, weight: JourneyType.bold),
        ),
        const SizedBox(height: AarastV3Space.x1),
        for (final line in [
          if (others.isNotEmpty) 'اللي على ${others.join(' و')}، لأنه مو عليك.',
          for (final pledge in coverage.pledgesIgnored)
            'وعد ${pledge.sourceName} (${money(pledge.amount)})، لأنه ${pledge.leftOut == MoneyPledgeLeftOut.late ? 'تأخر عن موعده' : 'ما له موعد'}.',
          if (estimates > 0)
            'التقديرات، لأنها مو اتفاقات. ${moneyIfEstimatesWords(context, coverage, money)}',
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: AarastV3Space.x1),
            child: Text(
              '• $line',
              style: JourneyType.of(
                JourneyType.small,
                color: AarastV3Color.textMuted,
                height: 1.6,
              ),
            ),
          ),
      ],
    );
  }
}
