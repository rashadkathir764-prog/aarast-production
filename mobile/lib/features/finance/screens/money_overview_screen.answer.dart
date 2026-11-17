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

/// RA-MO-181: [text] as the screen reader should say it, the currency by
/// its name («ريال يمني») where the screen writes «ر.ي».
String _spokenMoney(String text, String currency) =>
    text.replaceAll(currencyLabelAr(currency), currencySpokenLabelAr(currency));

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
    final soft = AarastV3Color.onPrimary.withValues(alpha: 0.78);
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
    // Rashad 2026-11-17: the home's hero, its look and size exactly
    // (JourneyPlanHero): the figure in the home's 52 point, its unit and
    // whose it is beside it, the mahr and the agreements under them, the
    // verdict as the saffron tag that opens «كيف حسبناها؟» (D113), and
    // what was paid of what was agreed as the bar.
    final hidden = context.select<FinanceProvider?, bool>(
      (provider) => provider?.amountsHidden ?? false,
    );
    final parts = compactMoneyParts(moneyValue(lead), currencyCode: currency);
    // D114: his share holds the mahr, so it is never «من العرس».
    final whose = owner ? context.say('باقي عليك', 'باقي عليكِ') : 'باقي يندفع';
    final unit = [?parts.millionUnit, parts.currency].join(' ');
    final agreed = moneyValue(summary.costs.total);
    final paid = moneyValue(summary.costs.paid);
    final Widget? tag;
    if (!owner) {
      tag = null;
    } else if (coverage == null) {
      // «لسا ما نعرف» said nothing to do; the tag is the way to know.
      tag = JourneyHeroTag(
        key: const ValueKey('money-cover-unknown'),
        label: onSources == null ? 'ما نعرف إذا تكفي' : 'تكفي فلوسك؟',
        icon: onSources == null ? null : LucideIcons.piggyBank,
        semanticLabel: context.say(
          'سجّل من وين فلوسك ونقول لك إذا تكفي',
          'سجّلي من وين فلوسك ونقول لك إذا تكفي',
        ),
        onTap: onSources,
      );
    } else {
      final verdict = moneyCoverTag(
        coverage,
        (value) => _figure(context, value, summary.currency),
      );
      tag = JourneyHeroTag(
        key: const ValueKey('money-cover'),
        label: verdict.words,
        icon: LucideIcons.info,
        semanticLabel: '${verdict.words}. كيف حسبناها؟',
        onTap: onHowCounted,
      );
    }
    return JourneyPlanHero(
      key: const ValueKey('money-share-hero'),
      figureKey: const ValueKey('money-share-figure'),
      figure: hidden ? '••••' : parts.number,
      // As the home's «يوم على عرسك» over its date: the unit beside the
      // figure, whose it is under it.
      title: hidden ? 'مخفي' : unit,
      subtitle: whose,
      semanticLabel:
          '$whose ${hidden ? 'مخفي' : _spokenMoney(_figure(context, lead, currency), currency)}'
          '${chips.isEmpty ? '' : '، ${chips.join('، ')}'}',
      tag: tag,
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (chips.isNotEmpty) ...[
            Text(
              chips.join(' · '),
              key: const ValueKey('money-share-parts'),
              // Rashad's phone 2026-11-17: in bold it spoke louder than
              // «باقي عليك» beside the figure; a detail stays under it.
              style: JourneyType.of(
                JourneyType.bodySmall,
                color: AarastV3Color.onPrimary,
              ),
            ),
            const SizedBox(height: AarastV3Space.x2),
          ],
          JourneyHeroBar(value: agreed <= 0 ? 0 : paid / agreed),
          if (agreed > 0) ...[
            const SizedBox(height: AarastV3Space.x1),
            Text(
              hidden
                  ? 'دفعت ••••'
                  : '${context.ownerDid('دفعت', 'دفعتِ', groom: 'دفع العريس', bride: 'دفعت العروسة')} ${_figure(context, paid, currency)} من ${_figure(context, agreed, currency)}',
              key: const ValueKey('money-share-paid'),
              style: JourneyType.of(JourneyType.caption, color: soft),
            ),
          ],
        ],
      ),
    );
  }
}

/// «تكفي», «تكفي بشرط الموعود» or «ينقصك X», and «كيف حسبناها؟» beside it.
class _CoverTag extends StatelessWidget {
  const _CoverTag({
    required this.tag,
    required this.howCounted,
    this.onPaper = false,
    this.linkKey = const ValueKey('money-how-counted'),
    super.key,
  });

  final MoneyCoverTag tag;
  final VoidCallback howCounted;

  /// On a paper card («من وين») rather than the summary's coloured one.
  final bool onPaper;
  final Key linkKey;

  @override
  Widget build(BuildContext context) {
    final onColour = !onPaper
        ? AarastV3Color.onPrimary
        : tag.ok && !tag.conditional
        ? AarastV3Color.mint
        : tag.ok
        ? AarastV3Color.ink
        : AarastV3Color.danger;
    // One line on a phone; at the largest text the link wraps under the tag
    // instead of running off the card.
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AarastV3Space.x2,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              tag.conditional
                  ? LucideIcons.clock
                  : tag.ok
                  ? LucideIcons.checkCircle2
                  : LucideIcons.alertCircle,
              size: 18,
              color: onColour,
            ),
            const SizedBox(width: AarastV3Space.x2),
            Flexible(
              child: Text(
                tag.words,
                style: JourneyType.of(
                  JourneyType.body,
                  weight: JourneyType.bold,
                  color: onColour,
                ),
              ),
            ),
          ],
        ),
        JourneyTextAction(
          key: linkKey,
          label: 'كيف حسبناها؟',
          onPressed: howCounted,
          color: onPaper ? context.accent.primary : onColour,
        ),
      ],
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
        action: context.say('افتح البنود', 'افتحي البنود'),
        onTap: onItems,
      ),
      // «من وين فلوسك» is the green card's own line above, so it is not a
      // step here too (Rashad 2026-11-17).
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
        const JourneySectionTitle('خطوتين وترتب فلوس عرسك'),
        JourneyList(
          children: [
            for (final (index, step) in steps.indexed)
              JourneyListRow(
                // The agreement keeps its key «-2» from the three steps.
                key: ValueKey('money-first-step-${index == 0 ? 0 : 2}'),
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
    this.all = const [],
    this.weddingDate,
    this.coverage,
  });

  final List<MoneyObligation> lines;
  final String currency;
  final VoidCallback onAll;
  final void Function(MoneyObligation line) onOpen;

  /// Every coming due, for the line over the list.
  final List<MoneyObligation> all;
  final DateTime? weddingDate;
  final MoneyCoverage? coverage;

  @override
  Widget build(BuildContext context) {
    // A due the money in hand does not reach (D103): its step leaves less
    // than nothing.
    final short = <String>{
      for (final step in coverage?.steps ?? const <MoneyCoverageStep>[])
        if (moneyValue(step.balance) < 0) step.id,
    };
    return Column(
      key: const ValueKey('money-coming-dues'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // D114: the mahr's dates are among them.
        JourneySectionTitle('الدفعات الجاية', action: 'كلها', onAction: onAll),
        if (all.length > 1) ...[
          _MoneyLine(dues: all, weddingDate: weddingDate, short: short),
          const SizedBox(height: AarastV3Space.x2),
        ],
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

/// «خط الفلوس» (Rashad 2026-11-17): from today to the wedding, each coming
/// due a dot on its day. A dot the money in hand does not reach is red, one
/// within the week saffron; the rest the plan's colour. When the money runs
/// short and how crowded the weeks are, at a glance; the list under it says
/// what each one is.
class _MoneyLine extends StatelessWidget {
  const _MoneyLine({
    required this.dues,
    required this.weddingDate,
    required this.short,
  });

  final List<MoneyObligation> dues;
  final DateTime? weddingDate;
  final Set<String> short;

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(appNow());
    final days = [
      for (final line in dues) daysUntilPlanDay(line.dueDate!).clamp(0, 9999),
    ];
    final toWedding = weddingDate == null
        ? null
        : daysUntilPlanDay(weddingDate!).clamp(0, 9999);
    final span = [
      ...days,
      ?toWedding,
      1,
    ].reduce((a, b) => a > b ? a : b).toDouble();
    final dots = [
      for (final (index, line) in dues.indexed)
        (
          at: days[index] / span,
          colour: short.contains(line.id)
              ? AarastV3Color.danger
              : days[index] <= 7
              ? AarastV3Color.amber
              : context.accent.primary,
        ),
    ];
    final anyShort = dues.any((line) => short.contains(line.id));
    final endDay = toWedding != null
        ? weddingDate!
        : today.add(Duration(days: span.round()));
    return Semantics(
      label:
          '${arabicCount(dues.length, one: 'دفعة وحدة', two: 'دفعتين', few: 'دفعات', many: 'دفعة')} من اليوم لين ${toWedding != null ? 'العرس' : _dayWords(endDay)}'
          '${anyShort ? '، وفيها دفعات ما تكفيها فلوسك' : ''}',
      excludeSemantics: true,
      child: JourneyBox(
        key: const ValueKey('money-line'),
        padding: const EdgeInsets.fromLTRB(
          AarastV3Space.x4,
          AarastV3Space.x3,
          AarastV3Space.x4,
          AarastV3Space.x3,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: AarastV3Space.x4,
              child: CustomPaint(
                painter: _MoneyLinePainter(
                  dots: dots,
                  track: AarastV3Color.line,
                  rtl: Directionality.of(context) == TextDirection.rtl,
                ),
              ),
            ),
            const SizedBox(height: AarastV3Space.x1),
            Row(
              children: [
                Text(
                  'اليوم',
                  style: JourneyType.of(
                    JourneyType.caption,
                    color: AarastV3Color.textMuted,
                  ),
                ),
                const SizedBox(width: AarastV3Space.x2),
                // The middle gives way first; nothing leaves the card.
                Expanded(
                  child: anyShort
                      ? Text(
                          'الأحمر ما تكفيه فلوسك',
                          key: const ValueKey('money-line-short'),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: JourneyType.of(
                            JourneyType.caption,
                            weight: JourneyType.bold,
                            color: AarastV3Color.danger,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(width: AarastV3Space.x2),
                Text(
                  toWedding != null ? 'العرس' : _dayWords(endDay),
                  maxLines: 1,
                  style: JourneyType.of(
                    JourneyType.caption,
                    weight: JourneyType.bold,
                    color: context.accent.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MoneyLinePainter extends CustomPainter {
  const _MoneyLinePainter({
    required this.dots,
    required this.track,
    required this.rtl,
  });

  final List<({double at, Color colour})> dots;
  final Color track;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    const radius = 5.0;
    double x(double at) {
      final along = radius + at * (size.width - radius * 2);
      return rtl ? size.width - along : along;
    }

    canvas.drawLine(
      Offset(0, mid),
      Offset(size.width, mid),
      Paint()
        ..color = track
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    // Today, where the line starts.
    canvas.drawCircle(Offset(x(0), mid), 3, Paint()..color = track);
    for (final dot in dots) {
      final centre = Offset(x(dot.at), mid);
      canvas.drawCircle(centre, radius + 2, Paint()..color = Colors.white);
      canvas.drawCircle(centre, radius, Paint()..color = dot.colour);
    }
  }

  @override
  bool shouldRepaint(_MoneyLinePainter old) =>
      old.dots != dots || old.track != track || old.rtl != rtl;
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
    // Rashad 2026-11-17: when all of it is the owner's, this row is the
    // green card's figure a second time.
    final allMine =
        profile.readerIsOwner && others.isEmpty && moneyValue(total) > 0;
    // The expected cost is what was agreed while no item has an estimate:
    // the budget's «اتفقت على» says it then.
    final estimates = moneyValue(expected?.wedding.estimateLeft);
    final loanLeft = moneyValue(summary.funding?.loanOutstanding);
    final repayments = [
      for (final line in summary.obligations)
        if (line.kind == MoneyObligationKind.loanRepayment &&
            line.dueDate != null)
          line.dueDate!,
    ];
    final unknown = expected?.wedding.unknownCount ?? 0;
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
        // D114: the budget, what is left of it, what was agreed and paid.
        if (summary.hasBudget || moneyValue(summary.costs.total) > 0) ...[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onItems,
            child: JourneyBox(
              key: const ValueKey('money-whole-budget'),
              padding: const EdgeInsets.all(AarastV3Space.x4),
              child: _BudgetFigures(summary: summary),
            ),
          ),
          const SizedBox(height: AarastV3Space.x2),
        ],
        // No rows left (all of it his, no loan, no estimate): no empty box.
        if (!allMine || loanLeft > 0 || estimates > 0)
          JourneyList(
            children: [
              if (!allMine)
                JourneyListRow(
                  key: const ValueKey('money-whole-left'),
                  icon: LucideIcons.fileSignature,
                  color: context.accent.primary,
                  soft: context.accent.primarySoft,
                  // D114: every agreement, the mahr's with them.
                  title: 'باقي على الاتفاقات كلها',
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
                  // RA-MO-71: the owner's debt, in the reader's words.
                  title: context.ownerDid(
                    'سلف ترجعها',
                    'سلف ترجعينها',
                    groom: 'سلف يرجعها العريس',
                    bride: 'سلف ترجعها العروسة',
                  ),
                  subtitleMaxLines: 2,
                  // The owner's debt, said to the reader as «الدفعات» says it.
                  subtitle:
                      '${context.ownerDid('دين عليك', 'دين عليكِ', groom: 'دين على العريس', bride: 'دين على العروسة')}، ${repayments.isEmpty ? 'بدون مواعيد سداد' : 'من ${_dayWords(repayments.first)} لين ${_dayWords(repayments.last)}'}',
                  trailing: end(money(loanLeft)),
                  onTap: onSources,
                ),
              // With estimates, what the wedding is expected to cost; without
              // any, it is «اتفقت على» above. The items without one are said
              // in «يحتاج انتباهك».
              if (estimates > 0)
                JourneyListRow(
                  key: const ValueKey('money-whole-cost'),
                  icon: LucideIcons.tag,
                  color: AarastV3Color.amber,
                  soft: AarastV3Color.amberSoft,
                  // D114: the wedding's items and the mahr.
                  title: 'التكلفة المتوقعة',
                  subtitleMaxLines: 2,
                  subtitle: 'الاتفاقات وتقديرات البنود الباقية',
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
