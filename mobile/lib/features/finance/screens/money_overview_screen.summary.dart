part of 'money_overview_screen.dart';

// c01 «الملخص» (RA-MO-40): the one figure that matters first («باقي عليك
// تدفع») and whether the money covers it, then the next payment to make,
// then where the money goes. Nothing is worked out on the phone (C2):
// «ناقصك» is the server's shortfall, which already counts what was
// pledged.

String _amount(BuildContext context, Object? value, String currency) {
  final hidden = context.select<FinanceProvider?, bool>(
    (provider) => provider?.amountsHidden ?? false,
  );
  if (hidden) return '••••';
  // Plain, not left-to-right isolated: inside Arabic text the isolated form
  // reads backwards («ر.ي مليون 2.6»).
  return compactMoneyParts(moneyValue(value), currencyCode: currency).plainText;
}

/// At most this many payers are named in c01's sentence; the rest are
/// counted, and w20 «مين دفع ايش» lists every one of them.
const _maxNamedPayers = 2;

/// The status line under «المال»: one true state, never a reassurance the
/// server did not work out, and never the shortfall's figure (that figure is
/// the card's own 28-point lead, see [_ShortfallLine], so saying it here
/// would be the same number twice at opposite weights).
///
/// Being over the budget is said even when the money is also short: the two
/// are different facts, and the over-budget one used to be dropped in
/// silence because the shortfall was checked first.
String _moneyStatusLine(MoneySummary summary, JourneyProfile profile) {
  if (!summary.hasBudget) {
    return profile.say(
      'حدد ميزانيتك ونرتب لك الباقي',
      'حددي ميزانيتك ونرتب لك الباقي',
    );
  }
  if (summary.costs.count == 0) {
    return profile.ownerDid(
      'ما سجلت اتفاقات بعد',
      'ما سجلتِ اتفاقات بعد',
      groom: 'ما انسجلت اتفاقات بعد',
      bride: 'ما انسجلت اتفاقات بعد',
    );
  }
  final funding = summary.funding;
  final short = funding != null && funding.shortfall != null;
  final over = moneyValue(summary.budget.remaining) < 0;
  if (over && short) return 'فوق الميزانية، وفلوسك ما تغطي اتفاقاتك';
  if (short) return 'فلوسك ما تغطي اتفاقاتك';
  if (over) return 'فوق الميزانية';
  // Neutral like «فوق الميزانية»: a participant who reads the money is not
  // the owner of this budget (RA-MO-11).
  return 'في حدود الميزانية';
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

/// c01 (RA-MO-40): one answer first. The reader opens money to learn what is
/// still to pay and whether the money covers it, so the card leads with
/// that one figure, says right under it whether the money in hand and
/// promised covers it (the server's shortfall, C2), then one bar of what
/// was paid of everything agreed, and who paid it (D59). It replaces a
/// sentence of six figures at one weight and a four-colour bar that put
/// what was spent beside what is in hand.
class _MoneySummaryCard extends StatelessWidget {
  const _MoneySummaryCard({required this.summary});

  final MoneySummary summary;

  @override
  Widget build(BuildContext context) {
    final currency = summary.currency;
    final funding = summary.funding;
    final profile = context.journeyProfile;
    String onLine(Object? value) =>
        keepCurrencyOnLine(_amount(context, value, currency));

    if (summary.costs.count == 0) {
      return JourneyBox(
        key: const ValueKey('money-dashboard-hero'),
        padding: const EdgeInsets.all(AarastV3Space.x4),
        child: Text(
          context.say(
            'لسا ما سجلت اتفاقات. أول ما تتفق مع مزود، سجّله '
                'ونحسب لك المدفوع والباقي.',
            'لسا ما سجلتِ اتفاقات. أول ما تتفقين مع مزود، '
                'سجّليه ونحسب لك المدفوع والباقي.',
          ),
          style: JourneyType.of(
            JourneyType.lead,
            color: AarastV3Color.textMuted,
            height: 1.7,
          ),
        ),
      );
    }

    final left = moneyValue(summary.costs.outstanding);
    final total = moneyValue(summary.costs.total);
    final paidRatio = total <= 0
        ? 0.0
        : (moneyValue(summary.costs.paid) / total).clamp(0.0, 1.0).toDouble();
    // D59: the owner's own payments, then who paid for the owner. At most
    // two payers are named; the rest are counted, and «مين دفع ايش» (w20)
    // lists them all.
    final payers = payersForOwner(summary);
    final othersPaid = moneyValue(summary.costs.paidByOthers) > 0;
    final forOwner = profile.ownerDid(
      'عنك',
      'عنك',
      groom: 'عنه',
      bride: 'عنها',
    );
    final paidLine = [
      if (moneyValue(summary.costs.paidByOwner) > 0 || !othersPaid)
        '${profile.ownerDid('دفعت', 'دفعتِ', groom: 'العريس دفع', bride: 'العروسة دفعت')} '
            '${onLine(summary.costs.paidByOwner)}',
      if (payers.isNotEmpty) ...[
        for (final group in payers.take(_maxNamedPayers))
          paidForOwnerPhrase(group, onLine(group.paid), profile),
        if (payers.length > _maxNamedPayers)
          'دفع $forOwner '
              // Payers are people: «اثنين» (RA-MO-12), not «ثنتين».
              '${arabicCount(payers.length - _maxNamedPayers, one: 'واحد', two: 'اثنين', few: 'غيرهم', many: 'غيرهم')} كذلك',
      ] else if (othersPaid)
        // Paid for the owner by people the server did not name.
        'دفع $forOwner ${onLine(summary.costs.paidByOthers)}',
    ].join(' · ');
    final agreedLine =
        'الاتفاقات كلها ${onLine(summary.costs.total)}'
        // D79: the groom's mahr is inside that total; say so.
        '${summary.agreedIncludesMahr ? '، مع المهر' : ''}';
    final muted = JourneyType.of(
      JourneyType.small,
      color: AarastV3Color.textMuted,
    );

    return JourneyBox(
      key: const ValueKey('money-dashboard-hero'),
      padding: const EdgeInsets.all(AarastV3Space.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (left > 0) ...[
            Text(
              profile.ownerDid(
                'باقي عليك تدفع',
                'باقي عليك تدفعين',
                groom: 'باقي على العريس',
                bride: 'باقي على العروسة',
              ),
              style: JourneyType.of(
                JourneyType.bodySmall,
                weight: JourneyType.bold,
                color: AarastV3Color.textMuted,
              ),
            ),
            FittedBox(
              key: const ValueKey('money-left-to-pay'),
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                _amount(context, summary.costs.outstanding, currency),
                style: JourneyType.of(
                  JourneyType.count,
                  weight: JourneyType.bold,
                  height: 1.25,
                ),
              ),
            ),
            if (funding != null) ...[
              const SizedBox(height: AarastV3Space.x1),
              _CoverLine(funding: funding, currency: currency),
            ],
          ] else
            Row(
              key: const ValueKey('money-all-paid'),
              children: [
                const Icon(LucideIcons.checkCircle2, color: AarastV3Color.mint),
                const SizedBox(width: AarastV3Space.x2),
                Expanded(
                  child: Text(
                    profile.ownerDid(
                      'دفعت كل اتفاقاتك',
                      'دفعتِ كل اتفاقاتك',
                      groom: 'اتفاقات العريس كلها مدفوعة',
                      bride: 'اتفاقات العروسة كلها مدفوعة',
                    ),
                    style: JourneyType.of(
                      JourneyType.title,
                      weight: JourneyType.bold,
                      color: AarastV3Color.mint,
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: AarastV3Space.x3),
          JourneyBar(
            key: const ValueKey('money-paid-bar'),
            value: paidRatio,
            color: context.accent.primary,
          ),
          const SizedBox(height: AarastV3Space.x2),
          Text(paidLine, key: const ValueKey('money-paid-line'), style: muted),
          Text(
            agreedLine,
            key: const ValueKey('money-agreed-line'),
            style: muted,
          ),
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
/// bride's is money coming to her. The wedding is what was agreed for it
/// against its budget, and what is left of the budget (RA-MO-40: «عرسك 7
/// مليون» read as 7 agreed when it was the budget, and the budget card
/// under it said the same budget again). Before a budget, what was paid.
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
    double ratio(String part, String? whole) {
      final total = moneyValue(whole);
      return total <= 0 ? 0 : (moneyValue(part) / total).clamp(0.0, 1.0);
    }

    final budget = summary.budget;
    final left = moneyValue(budget.remaining);
    final over = summary.hasBudget && left < 0;
    final weddingLine = !summary.hasBudget
        ? _paidSplitLine(
            context,
            byOwner: budget.paidByOwner,
            byOthers: budget.paidByOthers,
            currency: currency,
          )
        : over
        ? 'فوق ميزانية ${_amount(context, budget.total, currency)} '
              'بـ ${_amount(context, left.abs(), currency)}'
        : 'من ميزانية ${_amount(context, budget.total, currency)} · '
              'باقي منها ${_amount(context, left, currency)}';

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
                  label: 'اتفاقات عرسك',
                  amount: _amount(context, budget.confirmedCost, currency),
                  line: weddingLine,
                  lineColor: over ? AarastV3Color.danger : null,
                  ratio: summary.hasBudget
                      ? ratio(budget.confirmedCost, budget.total)
                      : ratio(budget.paid, budget.confirmedCost),
                  barColor: over ? AarastV3Color.danger : null,
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
    this.lineColor,
    this.barColor,
    super.key,
  });

  final IconData icon;
  final String label;
  final String amount;
  final String line;
  final double ratio;
  final VoidCallback onTap;

  /// Red when the line says something is over (the wedding over budget).
  final Color? lineColor;
  final Color? barColor;

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
                  color: lineColor ?? AarastV3Color.textMuted,
                ),
              ),
              const Spacer(),
              const SizedBox(height: AarastV3Space.x2),
              JourneyBar(
                value: ratio,
                color: barColor ?? context.accent.primary,
                height: 5,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Right under «باقي عليك تدفع»: does the money cover it? The server's
/// shortfall already counts what was promised (C2), so it is said once,
/// with what is in hand and promised beside it. The server leaves the
/// shortfall empty both when the sources cover the agreements and before
/// any source exists; only the first is coverage.
class _CoverLine extends StatelessWidget {
  const _CoverLine({required this.funding, required this.currency});

  final MoneyFundingSummary funding;
  final String currency;

  @override
  Widget build(BuildContext context) {
    // Read in this widget's own build: «أخفِ المبالغ» is selected here.
    String onLine(Object? value) =>
        keepCurrencyOnLine(_amount(context, value, currency));
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
    final inHand = moneyValue(funding.availableCash) > 0;
    final promised = moneyValue(funding.pledged) > 0;
    final shortfall = funding.shortfall;
    // What is in hand and promised, small under the verdict in both cases:
    // the verdict stays one short line (RA-MO-40: the figures inside it
    // made «يغطونه» fall alone onto a second line).
    final means = [
      if (inHand) 'معك ${onLine(funding.availableCash)}',
      if (promised) 'موعود لك ${onLine(funding.pledged)}',
    ].join(' · ');
    final meansStyle = JourneyType.of(
      JourneyType.small,
      color: AarastV3Color.textMuted,
    );
    if (shortfall == null || moneyValue(shortfall) <= 0) {
      return Row(
        key: const ValueKey('money-covered'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            LucideIcons.checkCircle2,
            size: 20,
            color: AarastV3Color.mint,
          ),
          const SizedBox(width: AarastV3Space.x2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  promised ? 'فلوسك والموعود يغطونه' : 'فلوسك تغطيه',
                  style: JourneyType.of(
                    JourneyType.bodyLarge,
                    weight: JourneyType.bold,
                    color: AarastV3Color.mint,
                  ),
                ),
                if (means.isNotEmpty) Text(means, style: meansStyle),
              ],
            ),
          ),
        ],
      );
    }
    return Column(
      key: const ValueKey('money-short'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          promised
              ? 'ناقصك ${onLine(shortfall)} حتى مع الموعود'
              : 'ناقصك ${onLine(shortfall)}',
          style: JourneyType.of(
            JourneyType.bodyLarge,
            weight: JourneyType.bold,
            color: AarastV3Color.danger,
          ),
        ),
        if (means.isNotEmpty) Text(means, style: meansStyle),
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
            // The share is drawn by the bar above, so repeating it as a
            // percentage says one thing twice. It is kept only when the
            // agreements are over the budget: there the bar is pinned full
            // and the percentage is the only place that says how far over.
            hidden
                ? 'الميزانية مخفية'
                : over
                ? 'من ميزانية ${_amount(context, summary.budget.total, currency)} · '
                      'الاتفاقات ${(summary.confirmedRatio * 100).round()}% منها'
                : 'من ميزانية ${_amount(context, summary.budget.total, currency)}',
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
