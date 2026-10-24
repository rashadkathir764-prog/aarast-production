import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'aarast_plan_chrome.dart';

/// The plan's tabs around one tab's page (b02, c01, d01, e01, f01). Each tab
/// adds its own things from its header («+» on the tasks and the guests), so
/// the shell carries no floating add button: the design draws none.
class PlanShellChrome extends StatelessWidget {
  const PlanShellChrome({
    required this.body,
    required this.activeIndex,
    required this.onTabSelected,
    this.topStatus,
    this.backgroundColor = AppTheme.canvas,
    super.key,
  });

  final Widget body;
  final int activeIndex;
  final ValueChanged<int> onTabSelected;
  final Widget? topStatus;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: backgroundColor,
        // The navigation surface is intentionally opaque. Letting the body
        // extend underneath it makes list rows and separators remain visible
        // behind the tabs on Android, and also reduces the usable height while
        // the keyboard is open.
        extendBody: false,
        // Every tab names itself in its own header (b02, c01, d01, e01, f01),
        // so the shell adds no title of its own. It still owns the status
        // bar inset, which it takes away from the tab below it.
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              ?topStatus,
              Expanded(
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: body,
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: AarastPlanNavigationBar.plan(
          activeIndex: activeIndex,
          onSelected: onTabSelected,
        ),
      ),
    );
  }
}
