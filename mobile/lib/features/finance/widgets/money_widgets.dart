import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../providers/finance_provider.dart';

/// The eye beside «المال» (c01 to c03): hides every amount on this phone
/// and shows them again. It is the same switch as «أخفِ المبالغ» in
/// «حسابي» (D23).
class MoneyPrivacyButton extends StatelessWidget {
  const MoneyPrivacyButton({super.key});

  @override
  Widget build(BuildContext context) {
    final hidden = context.select<FinanceProvider, bool>(
      (provider) => provider.amountsHidden,
    );
    return Semantics(
      toggled: hidden,
      child: JourneyRoundButton(
        key: const ValueKey('money-privacy-toggle'),
        icon: hidden ? LucideIcons.eye : LucideIcons.eyeOff,
        tooltip: hidden
            ? context.say('أظهر المبالغ', 'أظهري المبالغ')
            : context.say('أخفِ المبالغ', 'أخفي المبالغ'),
        onPressed: context.read<FinanceProvider>().toggleAmountsVisibility,
      ),
    );
  }
}

/// What an amount reads as while «أخفِ المبالغ» is on (G17).
const hiddenMoneyText = '••••';

/// G17: one rule for every money figure on screen: hidden while «أخفِ
/// المبالغ» is on, whichever screen shows it. Safe outside build (it does
/// not listen); the switch lives on other screens, which rebuild these on
/// return.
String shownMoney(BuildContext context, String text) {
  final hidden =
      Provider.of<FinanceProvider?>(context, listen: false)?.amountsHidden ??
      false;
  return hidden ? hiddenMoneyText : text;
}
