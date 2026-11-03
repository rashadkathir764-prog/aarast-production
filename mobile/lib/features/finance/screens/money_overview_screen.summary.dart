part of 'money_overview_screen.dart';

// c01 «الملخص»: the server's numbers in one sentence, then the one figure
// that matters. Nothing is worked out on the phone (C2): «ناقصك» is the
// server's shortfall, which already counts what was pledged, so it reads
// «ومع الموعود ناقصك».

String _amount(BuildContext context, Object? value, String currency) {
  final hidden = context.select<FinanceProvider?, bool>(
    (provider) => provider?.amountsHidden ?? false,
  );
  if (hidden) return '••••';
  // Plain, not left-to-right isolated: inside Arabic text the isolated form
  // reads backwards («ر.ي مليون 2.6»).
  return compactMoneyParts(moneyValue(value), currencyCode: currency).plainText;
}

/// The status line under «المال».
String _moneyStatusLine(MoneySummary summary, JourneyProfile profile) {
  final funding = summary.funding;
  if (funding != null && funding.shortfall != null) {
    return 'ماشية، بس ومع الموعود ناقصك شي';
  }
  if (!summary.hasBudget) {
    return profile.say(
      'حدد ميزانيتك ونرتب لك الباقي',
      'حددي ميزانيتك ونرتب لك الباقي',
    );
  }
  if (moneyValue(summary.budget.remaining) < 0) return 'فوق الميزانية';
  if (summary.costs.count == 0) {
    return profile.ownerDid(
      'ما سجلت اتفاقات بعد',
      'ما سجلتِ اتفاقات بعد',
      groom: 'ما انسجلت اتفاقات بعد',
      bride: 'ما انسجلت اتفاقات بعد',
    );
  }
  return 'ماشية';
}

/// D59: what was paid, said by whose money paid it: the owner's own part
/// («دفعت 1.3»), then what others paid for the owner («دفع عنك 1.3»).
String _paidSplitLine(
  BuildContext context, {
  required String byOwner,
  required String byOthers,
  required String currency,
}) {
  final profile = context.journeyProfile;
  final ownerPaid = profile.ownerDid(
    'دفعت',
    'دفعتِ',
    groom: 'العريس دفع',
    bride: 'العروسة دفعت',
  );
  final others = moneyValue(byOthers) > 0;
  return [
    if (moneyValue(byOwner) > 0 || !others)
      '$ownerPaid ${_amount(context, byOwner, currency)}',
    if (others)
      'دفع ${profile.ownerDid('عنك', 'عنك', groom: 'عنه', bride: 'عنها')} '
          '${_amount(context, byOthers, currency)}',
  ].join(' · ');
}

class _MoneySummaryCard extends StatelessWidget {
  const _MoneySummaryCard({required this.summary});

  final MoneySummary summary;

  @override
  Widget build(BuildContext context) {
    final currency = summary.currency;
    final funding = summary.funding;
    final profile = context.journeyProfile;
    String inSentence(Object? value) =>
        keepCurrencyOnLine(_amount(context, value, currency));
    final agreed = inSentence(summary.costs.total);
    final ownPaid = inSentence(summary.costs.paidByOwner);
    final left = inSentence(summary.costs.outstanding);
    final hasAgreements = summary.costs.count > 0;
    // D59: what others paid for the owner, by payer, from the server.
    final paidForOwner = [
      for (final group in payersForOwner(summary))
        paidForOwnerPhrase(group, inSentence(group.paid), profile),
    ];

    // c01: a 17 sentence (1.7 apart) in a box padded 20, then the 34 gap.
    final strong = JourneyType.of(JourneyType.lead, weight: JourneyType.bold);
    final plain = JourneyType.of(
      JourneyType.lead,
      color: AarastV3Color.textMuted,
      height: 1.7,
    );

    return JourneyBox(
      key: const ValueKey('money-dashboard-hero'),
      padding: const EdgeInsets.all(AarastV3Space.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(
              style: plain,
              children: hasAgreements
                  ? [
                      TextSpan(
                        text: context.ownerDid(
                          'اتفقت على ',
                          'اتفقتِ على ',
                          groom: 'اتفق العريس على ',
                          bride: 'اتفقت العروسة على ',
                        ),
                      ),
                      TextSpan(text: agreed, style: strong),
                      // D79: the groom's mahr is inside that total; say so.
                      if (summary.agreedIncludesMahr)
                        const TextSpan(text: ' مع المهر'),
                      // D59: «دفعت منها» is the owner's own money; what
                      // others paid for the owner is named after it.
                      TextSpan(
                        text: context.ownerDid(
                          '، دفعت منها ',
                          '، دفعتِ منها ',
                          groom: '، دفع منها ',
                          bride: '، دفعت منها ',
                        ),
                      ),
                      TextSpan(
                        text: ownPaid,
                        style: strong.copyWith(color: AarastV3Color.mint),
                      ),
                      for (final phrase in paidForOwner)
                        TextSpan(text: '، و$phrase'),
                      TextSpan(
                        text: context.ownerDid(
                          '. باقي عليك ',
                          '. باقي عليك ',
                          groom: '. باقي عليه ',
                          bride: '. باقي عليها ',
                        ),
                      ),
                      TextSpan(text: left, style: strong),
                      const TextSpan(text: '.'),
                      // «معك» only once a source is recorded; before that
                      // the server knows nothing about the money in.
                      if (funding != null &&
                          (funding.sourcesCount > 0 ||
                              funding.shortfall != null)) ...[
                        const TextSpan(text: ' معك '),
                        TextSpan(
                          text: inSentence(funding.availableCash),
                          style: strong.copyWith(color: context.accent.primary),
                        ),
                        if (moneyValue(funding.pledged) > 0) ...[
                          const TextSpan(text: '، وموعود لك '),
                          TextSpan(
                            text: inSentence(funding.pledged),
                            style: strong.copyWith(color: AarastV3Color.lilac),
                          ),
                        ],
                        const TextSpan(text: '.'),
                      ],
                    ]
                  : [
                      TextSpan(
                        text: context.say(
                          'لسا ما سجلت اتفاقات. أول ما تتفق مع مزود، سجّله '
                              'ونحسب لك المدفوع والباقي.',
                          'لسا ما سجلتِ اتفاقات. أول ما تتفقين مع مزود، '
                              'سجّليه ونحسب لك المدفوع والباقي.',
                        ),
                      ),
                    ],
            ),
          ),
          if (funding != null && hasAgreements) ...[
            const SizedBox(height: AarastV3Space.x3),
            _ShortfallLine(funding: funding, currency: currency),
            if (funding.sourcesCount > 0 || funding.shortfall != null) ...[
              const SizedBox(height: AarastV3Space.x3),
              _FundingSplit(
                paidByOwner: moneyValue(summary.costs.paidByOwner),
                paidByOthers: moneyValue(summary.costs.paidByOthers),
                inHand: moneyValue(funding.availableCash),
                pledged: moneyValue(funding.pledged),
                gap: moneyValue(funding.shortfall),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// D59: «سجّل المهر» in c01 and c02 while a groom's or a bride's plan has
/// no mahr (a06 skipped, a plan from before a06, or its agreement deleted).
/// Not drawn: the design has the mahr always recorded; it reuses the
/// journey kit's row (design difference in the handoff).
class _RecordMahrEntry extends StatelessWidget {
  const _RecordMahrEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pays = !context.journeyProfile.isBride;
    return JourneyBox(
      key: const ValueKey('money-record-mahr'),
      padding: EdgeInsets.zero,
      child: JourneyListRow(
        icon: LucideIcons.heartHandshake,
        color: context.accent.primary,
        soft: context.accent.primarySoft,
        title: context.say('سجّل المهر', 'سجّلي المهر'),
        subtitle: pays
            ? 'اتفاقك مع أهل العروسة، برّا ميزانية العرس'
            : 'المهر يوصلك من العريس، ونحسبه من فلوسك',
        trailing: const Icon(
          LucideIcons.chevronLeft,
          size: 18,
          color: AarastV3Color.textMuted,
        ),
        onTap: onTap,
      ),
    );
  }
}

/// c01 «وين تروح الفلوس» (the groom) / «المهر وعرسك» (the bride): the
/// mahr beside the wedding, each from the server (C1, C2). The groom's mahr
/// is his agreement with the bride's family, handed over bit by bit; the
/// bride's is money coming to her. The wedding is its budget (or its
/// agreements before a budget) and what was paid of it.
class _MahrAndWeddingCards extends StatelessWidget {
  const _MahrAndWeddingCards({
    required this.summary,
    required this.mahr,
    required this.onMahr,
    required this.onWedding,
  });

  final MoneySummary summary;
  final MoneyMahrSummary mahr;
  final VoidCallback onMahr;
  final VoidCallback onWedding;

  @override
  Widget build(BuildContext context) {
    final currency = summary.currency;
    final pays = mahr.side == MahrSide.pays;
    final weddingTotal = summary.budget.total ?? summary.budget.confirmedCost;
    double ratio(String part, String? whole) {
      final total = moneyValue(whole);
      return total <= 0 ? 0 : (moneyValue(part) / total).clamp(0.0, 1.0);
    }

    return Column(
      key: const ValueKey('money-mahr-and-wedding'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JourneySectionTitle(pays ? 'وين تروح الفلوس' : 'المهر وعرسك'),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _SplitCard(
                  key: const ValueKey('money-mahr-card'),
                  icon: LucideIcons.heartHandshake,
                  label: pays ? 'الاتفاق مع أهل العروسة' : 'المهر يوصلك',
                  amount: _amount(context, mahr.total, currency),
                  line: pays
                      ? '${context.ownerDid('سلّمت', 'سلّمتِ', groom: 'العريس سلّم', bride: 'العروسة سلّمت')} ${_amount(context, mahr.settled, currency)}'
                      : 'وصلك ${_amount(context, mahr.settled, currency)}',
                  ratio: ratio(mahr.settled, mahr.total),
                  onTap: onMahr,
                ),
              ),
              const SizedBox(width: AarastV3Space.x2),
              Expanded(
                child: _SplitCard(
                  key: const ValueKey('money-wedding-card'),
                  icon: LucideIcons.building2,
                  label: 'عرسك',
                  amount: _amount(context, weddingTotal, currency),
                  line: _paidSplitLine(
                    context,
                    byOwner: summary.budget.paidByOwner,
                    byOthers: summary.budget.paidByOthers,
                    currency: currency,
                  ),
                  ratio: ratio(summary.budget.paid, weddingTotal),
                  onTap: onWedding,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SplitCard extends StatelessWidget {
  const _SplitCard({
    required this.icon,
    required this.label,
    required this.amount,
    required this.line,
    required this.ratio,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final String amount;
  final String line;
  final double ratio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label، $amount، $line',
      onTap: onTap,
      excludeSemantics: true,
      child: AarastPressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AarastV3Radius.card),
        child: JourneyBox(
          padding: const EdgeInsets.all(AarastV3Space.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 18, color: context.accent.primary),
                  const SizedBox(width: AarastV3Space.x1),
                  Expanded(
                    child: Text(
                      label,
                      style: JourneyType.of(
                        JourneyType.small,
                        weight: JourneyType.bold,
                        color: context.accent.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AarastV3Space.x2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  amount,
                  style: JourneyType.of(
                    JourneyType.title,
                    weight: JourneyType.bold,
                  ),
                ),
              ),
              Text(
                line,
                style: JourneyType.of(
                  JourneyType.small,
                  color: AarastV3Color.textMuted,
                ),
              ),
              const Spacer(),
              const SizedBox(height: AarastV3Space.x2),
              JourneyBar(
                value: ratio,
                color: context.accent.primary,
                height: 5,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// c01's bar and its legend: paid, in hand, promised and the server's
/// shortfall (C2: the gap left once everything else is counted). D59: what
/// others paid for the owner is its own piece, beside what the owner paid;
/// together they make every agreement.
class _FundingSplit extends StatelessWidget {
  const _FundingSplit({
    required this.paidByOwner,
    required this.paidByOthers,
    required this.inHand,
    required this.pledged,
    required this.gap,
  });

  final num paidByOwner;
  final num paidByOthers;
  final num inHand;
  final num pledged;
  final num gap;

  @override
  Widget build(BuildContext context) {
    final pieces = [
      (
        paidByOwner,
        context.accent.primary,
        context.ownerDid(
          'دفعت',
          'دفعتِ',
          groom: 'دفع العريس',
          bride: 'دفعت العروسة',
        ),
      ),
      (
        paidByOthers,
        context.accent.primaryDark,
        'دفع ${context.ownerDid('عنك', 'عنك', groom: 'عنه', bride: 'عنها')}',
      ),
      (inHand, context.accent.primaryMid, 'معك'),
      (pledged, AarastV3Color.lilac.withValues(alpha: 0.5), 'موعود'),
      (gap, AarastV3Color.danger, 'ناقصك'),
    ].where((piece) => piece.$1 > 0).toList(growable: false);
    if (pieces.isEmpty) return const SizedBox.shrink();
    final total = pieces.fold<num>(0, (sum, piece) => sum + piece.$1);
    return ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            key: const ValueKey('money-funding-bar'),
            borderRadius: BorderRadius.circular(AarastV3Radius.xs),
            child: SizedBox(
              height: AarastV3Space.x2,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var index = 0; index < pieces.length; index++) ...[
                    if (index > 0) const SizedBox(width: AarastV3Space.x1),
                    Expanded(
                      flex: (pieces[index].$1 / total * 1000).round().clamp(
                        1,
                        1000,
                      ),
                      child: ColoredBox(color: pieces[index].$2),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AarastV3Space.x2),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              for (final piece in pieces)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox.square(
                      dimension: AarastV3Space.x2,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: piece.$2,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: AarastV3Space.x1),
                    Text(
                      piece.$3,
                      style: JourneyType.of(
                        JourneyType.label,
                        color: AarastV3Color.textMuted,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// «ومع الموعود ناقصك 1.3 مليون», or «فلوسك تغطي اتفاقاتك».
class _ShortfallLine extends StatelessWidget {
  const _ShortfallLine({required this.funding, required this.currency});

  final MoneyFundingSummary funding;
  final String currency;

  @override
  Widget build(BuildContext context) {
    // The server leaves the shortfall empty both when the sources cover
    // the agreements and before any source exists; only the first is
    // coverage.
    if (funding.sourcesCount == 0 && funding.shortfall == null) {
      return Text(
        context.say(
          'ما سجلت من وين فلوسك بعد، فما نعرف إذا تكفي.',
          'ما سجلتِ من وين فلوسك بعد، فما نعرف إذا تكفي.',
        ),
        key: const ValueKey('money-funding-unknown'),
        style: JourneyType.of(
          JourneyType.bodySmall,
          color: AarastV3Color.textMuted,
        ),
      );
    }
    final shortfall = funding.shortfall;
    if (shortfall == null || moneyValue(shortfall) <= 0) {
      return Row(
        children: [
          const Icon(LucideIcons.checkCircle2, color: AarastV3Color.mint),
          const SizedBox(width: AarastV3Space.x2),
          Expanded(
            child: Text(
              'فلوسك والموعود يغطون اتفاقاتك',
              style: JourneyType.of(
                JourneyType.bodyLarge,
                weight: JourneyType.bold,
                color: AarastV3Color.mint,
              ),
            ),
          ),
        ],
      );
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 10,
      children: [
        Text(
          _amount(context, shortfall, currency),
          style: JourneyType.of(
            JourneyType.headline,
            weight: JourneyType.bold,
            color: AarastV3Color.danger,
            height: 1.2,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: AarastV3Space.x1),
          child: Text(
            'ومع الموعود ناقصك',
            style: JourneyType.of(
              JourneyType.bodySmall,
              weight: JourneyType.bold,
              color: AarastV3Color.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}

/// The budget: how much is left of it, how much is spoken for, and the
/// first step when there is none (x03).
class _MoneyBudgetCard extends StatelessWidget {
  const _MoneyBudgetCard({
    required this.summary,
    required this.canManage,
    required this.onBudget,
  });

  final MoneySummary summary;
  final bool canManage;
  final VoidCallback onBudget;

  @override
  Widget build(BuildContext context) {
    final currency = summary.currency;
    if (!summary.hasBudget) {
      return JourneyBox(
        padding: const EdgeInsets.all(AarastV3Space.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.say('ما حددت ميزانية', 'ما حددتِ ميزانية'),
              style: JourneyType.of(
                JourneyType.title,
                weight: JourneyType.bold,
              ),
            ),
            const SizedBox(height: AarastV3Space.x1),
            Text(
              'رقم تقريبي يكفي، ونقول لك كم باقي منه وأي بند فات حده.',
              style: JourneyType.of(
                JourneyType.body,
                color: AarastV3Color.textMuted,
              ),
            ),
            if (canManage) ...[
              const SizedBox(height: AarastV3Space.x3),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: JourneyButton(
                  key: const ValueKey('money-budget-setup'),
                  label: context.say('حط رقم', 'حطي رقم'),
                  icon: LucideIcons.wallet,
                  onPressed: onBudget,
                ),
              ),
            ],
          ],
        ),
      );
    }

    final remaining = moneyValue(summary.budget.remaining);
    final over = remaining < 0;
    final ratio = summary.confirmedRatio.clamp(0.0, 1.0).toDouble();
    final hidden = context.select<FinanceProvider?, bool>(
      (provider) => provider?.amountsHidden ?? false,
    );
    return JourneyBox(
      padding: const EdgeInsets.all(AarastV3Space.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            over ? 'فوق الميزانية' : 'المتاح من الميزانية',
            style: JourneyType.of(
              JourneyType.small,
              weight: JourneyType.bold,
              color: over ? AarastV3Color.danger : AarastV3Color.textMuted,
            ),
          ),
          Text(
            _amount(context, remaining.abs(), currency),
            style: JourneyType.of(
              JourneyType.display,
              weight: JourneyType.bold,
              color: over ? AarastV3Color.danger : AarastV3Color.ink,
            ),
          ),
          const SizedBox(height: AarastV3Space.x2),
          JourneyBar(
            value: ratio,
            color: over ? AarastV3Color.danger : context.accent.primary,
          ),
          const SizedBox(height: AarastV3Space.x2),
          Text(
            hidden
                ? 'الميزانية مخفية'
                : 'من ميزانية ${_amount(context, summary.budget.total, currency)} · '
                      'الاتفاقات ${(summary.confirmedRatio * 100).round()}% منها',
            style: JourneyType.of(
              JourneyType.small,
              color: AarastV3Color.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
