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
  // D105: the budget is held against the expected cost (agreements and
  // what is still an estimate), as «البنود» and «يحتاج انتباهك» say it.
  final left = summary.expected?.budgetLeft ?? summary.budget.remaining;
  final over = moneyValue(left) < 0;
  if (over && short) return 'فوق الميزانية، وفلوسك ما تغطي اتفاقاتك';
  if (short) return 'فلوسك ما تغطي اتفاقاتك';
  if (over) return 'فوق الميزانية';
  // Neutral like «فوق الميزانية»: a participant who reads the money is not
  // the owner of this budget (RA-MO-11).
  return 'في حدود الميزانية';
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
