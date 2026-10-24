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
String _moneyStatusLine(MoneySummary summary) {
  final funding = summary.funding;
  if (funding != null && funding.shortfall != null) {
    return 'ماشية، بس ومع الموعود ناقصك شي';
  }
  if (!summary.hasBudget) return 'حدد ميزانيتك ونرتب لك الباقي';
  if (moneyValue(summary.budget.remaining) < 0) return 'فوق الميزانية';
  if (summary.costs.count == 0) return 'ما سجلت اتفاقات بعد';
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
                      const TextSpan(text: 'اتفقت على '),
                      TextSpan(text: agreed, style: strong),
                      const TextSpan(text: '، دفعت منها '),
                      TextSpan(
                        text: paid,
                        style: strong.copyWith(color: AarastV3Color.mint),
                      ),
                      const TextSpan(text: '. باقي عليك '),
                      TextSpan(text: left, style: strong),
                      const TextSpan(text: '.'),
                      if (funding != null) ...[
                        const TextSpan(text: ' معك '),
                        TextSpan(
                          text: _amount(
                            context,
                            funding.availableCash,
                            currency,
                          ),
                          style: strong.copyWith(color: AarastV3Color.primary),
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
                  : const [
                      TextSpan(
                        text:
                            'لسا ما سجلت اتفاقات. أول ما تتفق مع مزود، سجّله '
                            'ونحسب لك المدفوع والباقي.',
                      ),
                    ],
            ),
          ),
          if (funding != null && hasAgreements) ...[
            const SizedBox(height: 12),
            _ShortfallLine(funding: funding, currency: currency),
          ],
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
              'ما حددت ميزانية',
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
                  label: 'حط رقم',
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
            color: over ? AarastV3Color.danger : AarastV3Color.primary,
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
