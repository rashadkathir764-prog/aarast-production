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
    return profile.say('ما سجلت اتفاقات بعد', 'ما سجلتِ اتفاقات بعد');
  }
  return 'ماشية';
}

class _MoneySummaryCard extends StatelessWidget {
  const _MoneySummaryCard({required this.summary});

  final MoneySummary summary;

  @override
  Widget build(BuildContext context) {
    final currency = summary.currency;
    final funding = summary.funding;
    final agreed = _amount(context, summary.costs.total, currency);
    final paid = _amount(context, summary.costs.paid, currency);
    final left = _amount(context, summary.costs.outstanding, currency);
    final hasAgreements = summary.costs.count > 0;

    // c01: a 17 sentence (1.7 apart) in a box padded 20, then the 34 gap.
    final strong = JourneyType.of(JourneyType.lead, weight: JourneyType.bold);
    final plain = JourneyType.of(
      JourneyType.lead,
      color: AarastV3Color.textMuted,
      height: 1.7,
    );

    return JourneyBox(
      key: const ValueKey('money-dashboard-hero'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(
              style: plain,
              children: hasAgreements
                  ? [
                      TextSpan(text: context.say('اتفقت على ', 'اتفقتِ على ')),
                      TextSpan(text: agreed, style: strong),
                      TextSpan(
                        text: context.say('، دفعت منها ', '، دفعتِ منها '),
                      ),
                      TextSpan(
                        text: paid,
                        style: strong.copyWith(color: AarastV3Color.mint),
                      ),
                      const TextSpan(text: '. باقي عليك '),
                      TextSpan(text: left, style: strong),
                      const TextSpan(text: '.'),
                      // «معك» only once a source is recorded; before that
                      // the server knows nothing about the money in.
                      if (funding != null &&
                          (funding.sourcesCount > 0 ||
                              funding.shortfall != null)) ...[
                        const TextSpan(text: ' معك '),
                        TextSpan(
                          text: _amount(
                            context,
                            funding.availableCash,
                            currency,
                          ),
                          style: strong.copyWith(color: context.accent.primary),
                        ),
                        if (moneyValue(funding.pledged) > 0) ...[
                          const TextSpan(text: '، وموعود لك '),
                          TextSpan(
                            text: _amount(context, funding.pledged, currency),
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
            const SizedBox(height: 12),
            _ShortfallLine(funding: funding, currency: currency),
            if (funding.sourcesCount > 0 || funding.shortfall != null) ...[
              const SizedBox(height: 14),
              _FundingSplit(
                paid: moneyValue(summary.costs.paid),
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
                      ? '${context.say('سلّمت', 'سلّمتِ')} ${_amount(context, mahr.settled, currency)}'
                      : 'وصلك ${_amount(context, mahr.settled, currency)}',
                  ratio: ratio(mahr.settled, mahr.total),
                  onTap: onMahr,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SplitCard(
                  key: const ValueKey('money-wedding-card'),
                  icon: LucideIcons.building2,
                  label: 'عرسك',
                  amount: _amount(context, weddingTotal, currency),
                  line:
                      '${context.say('دفعت', 'دفعتِ')} ${_amount(context, summary.budget.paid, currency)}',
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
        borderRadius: BorderRadius.circular(22),
        child: JourneyBox(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 18, color: context.accent.primary),
                  const SizedBox(width: 6),
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
              const SizedBox(height: 10),
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
              const SizedBox(height: 10),
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

/// c01's four-part bar and its legend: paid, in hand, promised and the
/// server's shortfall (C2: the gap left once everything else is counted).
class _FundingSplit extends StatelessWidget {
  const _FundingSplit({
    required this.paid,
    required this.inHand,
    required this.pledged,
    required this.gap,
  });

  final num paid;
  final num inHand;
  final num pledged;
  final num gap;

  @override
  Widget build(BuildContext context) {
    final pieces = [
      (paid, context.accent.primary, context.say('دفعت', 'دفعتِ')),
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
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              height: 10,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var index = 0; index < pieces.length; index++) ...[
                    if (index > 0) const SizedBox(width: 3),
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
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              for (final piece in pieces)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox.square(
                      dimension: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: piece.$2,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
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
          const SizedBox(width: 8),
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
          padding: const EdgeInsets.only(bottom: 6),
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
        padding: const EdgeInsets.all(18),
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
            const SizedBox(height: 4),
            Text(
              'رقم تقريبي يكفي، ونقول لك كم باقي منه وأي بند فات حده.',
              style: JourneyType.of(
                JourneyType.body,
                color: AarastV3Color.textMuted,
              ),
            ),
            if (canManage) ...[
              const SizedBox(height: 14),
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
      padding: const EdgeInsets.all(18),
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
          const SizedBox(height: 10),
          JourneyBar(
            value: ratio,
            color: over ? AarastV3Color.danger : context.accent.primary,
          ),
          const SizedBox(height: 8),
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
