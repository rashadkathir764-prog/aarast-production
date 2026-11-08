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

/// c01 (RA-MO-40): the balance card, the money tab's one answer, on the
/// plan's colour like the loan's «باقي عليك» (c13). What is still to pay
/// as one figure; whether the money in hand and promised covers it (the
/// server's shortfall, C2), in a pill that reads on the colour; one bar of
/// what was paid of everything agreed, who paid it (D59) and the total with
/// the mahr (D79). Rashad chose it (2026-11-08) over the white report
/// whose six figures had no lead.
class _MoneySummaryCard extends StatelessWidget {
  const _MoneySummaryCard({required this.summary});

  final MoneySummary summary;

  @override
  Widget build(BuildContext context) {
    final currency = summary.currency;
    final funding = summary.funding;
    final profile = context.journeyProfile;
    final onColour = AarastV3Color.onPrimary;
    final soft = context.accent.onPrimaryMuted;
    String onLine(Object? value) =>
        keepCurrencyOnLine(_amount(context, value, currency));

    if (summary.costs.count == 0) {
      return JourneyBox(
        key: const ValueKey('money-dashboard-hero'),
        color: context.accent.primary,
        radius: AarastV3Radius.feature,
        padding: const EdgeInsets.all(AarastV3Space.x4),
        child: Text(
          context.say(
            'لسا ما سجلت اتفاقات. أول ما تتفق مع مزود، سجّله '
                'ونحسب لك المدفوع والباقي.',
            'لسا ما سجلتِ اتفاقات. أول ما تتفقين مع مزود، '
                'سجّليه ونحسب لك المدفوع والباقي.',
          ),
          style: JourneyType.of(JourneyType.lead, color: onColour, height: 1.7),
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
    final small = JourneyType.of(JourneyType.small, color: soft);

    return JourneyBox(
      key: const ValueKey('money-dashboard-hero'),
      color: context.accent.primary,
      radius: AarastV3Radius.feature,
      padding: const EdgeInsets.all(AarastV3Space.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                color: soft,
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
                  color: onColour,
                  height: 1.25,
                ),
              ),
            ),
            if (funding != null) ...[
              const SizedBox(height: AarastV3Space.x2),
              _CoverLine(funding: funding, currency: currency),
            ],
          ] else
            _CoverPill(
              key: const ValueKey('money-all-paid'),
              icon: LucideIcons.checkCircle2,
              color: AarastV3Color.mint,
              text: profile.ownerDid(
                'دفعت كل اتفاقاتك',
                'دفعتِ كل اتفاقاتك',
                groom: 'اتفاقات العريس كلها مدفوعة',
                bride: 'اتفاقات العروسة كلها مدفوعة',
              ),
            ),
          const SizedBox(height: AarastV3Space.x4),
          JourneyBar(
            key: const ValueKey('money-paid-bar'),
            value: paidRatio,
            color: onColour,
            track: soft.withValues(alpha: 0.3),
          ),
          const SizedBox(height: AarastV3Space.x2),
          Text(paidLine, key: const ValueKey('money-paid-line'), style: small),
          Text(
            agreedLine,
            key: const ValueKey('money-agreed-line'),
            style: small,
          ),
        ],
      ),
    );
  }
}

/// A verdict on the plan's colour: white, so its green or red reads.
class _CoverPill extends StatelessWidget {
  const _CoverPill({
    required this.icon,
    required this.color,
    required this.text,
    super.key,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AarastV3Density.tagInsets,
      decoration: BoxDecoration(
        color: AarastV3Color.onPrimary,
        borderRadius: BorderRadius.circular(AarastV3Radius.card),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AarastV3Space.x1),
          Flexible(
            child: Text(
              text,
              style: JourneyType.of(
                JourneyType.body,
                weight: JourneyType.bold,
                color: color,
              ),
            ),
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

/// Right under «باقي عليك تدفع»: does the money cover it? The server's
/// shortfall already counts what was promised (C2), so it is said once, in
/// a pill, with what is in hand and promised small under it. The server
/// leaves the shortfall empty both when the sources cover the agreements
/// and before any source exists; only the first is coverage.
class _CoverLine extends StatelessWidget {
  const _CoverLine({required this.funding, required this.currency});

  final MoneyFundingSummary funding;
  final String currency;

  @override
  Widget build(BuildContext context) {
    // Read in this widget's own build: «أخفِ المبالغ» is selected here.
    String onLine(Object? value) =>
        keepCurrencyOnLine(_amount(context, value, currency));
    final soft = context.accent.onPrimaryMuted;
    if (funding.sourcesCount == 0 && funding.shortfall == null) {
      return Text(
        context.say(
          'ما سجلت من وين فلوسك بعد، فما نعرف إذا تكفي.',
          'ما سجلتِ من وين فلوسك بعد، فما نعرف إذا تكفي.',
        ),
        key: const ValueKey('money-funding-unknown'),
        style: JourneyType.of(JourneyType.bodySmall, color: soft),
      );
    }
    final inHand = moneyValue(funding.availableCash) > 0;
    final promised = moneyValue(funding.pledged) > 0;
    final shortfall = funding.shortfall;
    final covered = shortfall == null || moneyValue(shortfall) <= 0;
    final means = [
      if (inHand) 'معك ${onLine(funding.availableCash)}',
      if (promised) 'موعود لك ${onLine(funding.pledged)}',
    ].join(' · ');
    return Column(
      key: ValueKey(covered ? 'money-covered' : 'money-short'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CoverPill(
          icon: covered ? LucideIcons.checkCircle2 : LucideIcons.alertCircle,
          color: covered ? AarastV3Color.mint : AarastV3Color.danger,
          text: covered
              ? (promised ? 'فلوسك والموعود يغطونه' : 'فلوسك تغطيه')
              : promised
              ? 'ناقصك ${onLine(shortfall)} حتى مع الموعود'
              : 'ناقصك ${onLine(shortfall)}',
        ),
        if (means.isNotEmpty) ...[
          const SizedBox(height: AarastV3Space.x1),
          Text(means, style: JourneyType.of(JourneyType.small, color: soft)),
        ],
      ],
    );
  }
}

/// The budget in one card (RA-MO-40): what was agreed for the wedding out
/// of it and what is left, on one bar; the first step when there is none
/// (x03). The mahr is outside it (C1); it has its own place on the home
/// and in «البنود».
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
    final budgetTotal = _amount(context, summary.budget.total, currency);
    return JourneyBox(
      key: const ValueKey('money-budget-card'),
      padding: const EdgeInsets.all(AarastV3Space.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A Wrap, not a Row: at 320 and large text «باقي» drops under
          // the budget instead of overflowing.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: AarastV3Space.x2,
            runSpacing: AarastV3Space.x1,
            children: [
              Text(
                'الميزانية $budgetTotal',
                style: JourneyType.of(
                  JourneyType.bodyLarge,
                  weight: JourneyType.bold,
                ),
              ),
              Text(
                over
                    ? 'فوقها ${_amount(context, remaining.abs(), currency)}'
                    : 'باقي ${_amount(context, remaining, currency)}',
                style: JourneyType.of(
                  JourneyType.bodyLarge,
                  weight: JourneyType.bold,
                  color: over ? AarastV3Color.danger : context.accent.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AarastV3Space.x2),
          JourneyBar(
            value: ratio,
            color: over ? AarastV3Color.danger : context.accent.primary,
          ),
          const SizedBox(height: AarastV3Space.x1),
          Text(
            '${context.ownerDid('اتفقت', 'اتفقتِ', groom: 'اتفق العريس', bride: 'اتفقت العروسة')} '
            'على ${_amount(context, summary.budget.confirmedCost, currency)} منها'
            '${over ? ' · الاتفاقات ${(summary.confirmedRatio * 100).round()}% منها' : ''}',
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
