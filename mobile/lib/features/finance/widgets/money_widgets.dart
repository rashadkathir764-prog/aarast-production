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
    // Critique م8 (Rashad 2026-11-18): the home says «أخفِ» beside its eye
    // and the money tab had the eye alone. The eye with its word here too;
    // the share went into «⋯» to make the room.
    final word = hidden
        ? context.say('أظهر', 'أظهري')
        : context.say('أخفِ', 'أخفي');
    final toggle = context.read<FinanceProvider>().toggleAmountsVisibility;
    return Semantics(
      toggled: hidden,
      button: true,
      label: hidden
          ? context.say('أظهر المبالغ', 'أظهري المبالغ')
          : context.say('أخفِ المبالغ', 'أخفي المبالغ'),
      // RA-MO-361: the InkWell is hidden with its words; the tap is said
      // here, or a screen reader's double tap did nothing.
      onTap: toggle,
      excludeSemantics: true,
      child: Material(
        color: AarastV3Color.paper,
        shape: const StadiumBorder(),
        child: InkWell(
          key: const ValueKey('money-privacy-toggle'),
          customBorder: const StadiumBorder(),
          onTap: toggle,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AarastV3Space.x12,
              minWidth: AarastV3Space.x12,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AarastV3Space.x3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hidden ? LucideIcons.eye : LucideIcons.eyeOff,
                    size: AarastV3Icon.sm,
                    color: context.accent.primary,
                  ),
                  const SizedBox(width: AarastV3Space.x1),
                  Text(
                    word,
                    style: JourneyType.of(
                      JourneyType.small,
                      weight: JourneyType.bold,
                      color: context.accent.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// G17 for a finance screen: [FinanceProvider.shownAmount] from [context].
/// Safe outside build (it does not listen); the switch lives on other
/// screens, which rebuild these on return.
String shownMoney(BuildContext context, String text) =>
    Provider.of<FinanceProvider?>(context, listen: false)?.shownAmount(text) ??
    text;
