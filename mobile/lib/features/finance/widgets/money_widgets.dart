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
        tooltip: hidden ? 'أظهر المبالغ' : 'أخفِ المبالغ',
        onPressed: context.read<FinanceProvider>().toggleAmountsVisibility,
      ),
    );
  }
}
