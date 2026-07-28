import 'package:flutter/material.dart';

import '../../account_contexts/widgets/account_context_switcher.dart';
import '../../wedding_plans/widgets/quick_add_actions.dart';
import '../../wedding_plans/widgets/royal_home_chrome.dart';

class PlanShellChrome extends StatelessWidget {
  const PlanShellChrome({
    required this.body,
    required this.activeIndex,
    required this.onTabSelected,
    required this.showQuickFab,
    this.onQuickAdd,
    this.backgroundColor = Colors.transparent,
    super.key,
  });

  final Widget body;
  final int activeIndex;
  final ValueChanged<int> onTabSelected;
  final bool showQuickFab;
  final VoidCallback? onQuickAdd;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final quickAdd = onQuickAdd;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: backgroundColor,
        extendBody: true,
        body: Column(
          children: [
            const AccountContextSwitcher(),
            Expanded(child: body),
          ],
        ),
        floatingActionButton: showQuickFab && quickAdd != null
            ? RoyalSmartFloatingActionButton(
                icon: planQuickAddIconForTab(activeIndex),
                onPressed: quickAdd,
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: RoyalDashboardBottomNav(
          activeIndex: activeIndex,
          onHome: () => onTabSelected(0),
          onMoney: () => onTabSelected(1),
          onTasks: () => onTabSelected(2),
          onGuests: () => onTabSelected(3),
          onProviders: () => onTabSelected(4),
        ),
      ),
    );
  }
}
