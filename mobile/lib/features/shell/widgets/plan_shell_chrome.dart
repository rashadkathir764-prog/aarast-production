import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../core/experience_v3/aarast_journey.dart';
import '../../../core/theme/app_theme.dart';
import 'aarast_plan_chrome.dart';
import 'plan_quick_add.dart';
import 'plan_quick_add_sheet.dart';

/// The plan's tabs around one tab's page (b02, c01, d01, e01, f01), with the
/// floating «+» the owner asked to keep (D33) when [onQuickAdd] is given. It
/// takes the tab's colour and name («إضافة مهمة»، «إضافة ضيف»), hides while
/// the keyboard is open, and folds to its icon while the page scrolls down.
class PlanShellChrome extends StatefulWidget {
  const PlanShellChrome({
    required this.body,
    required this.activeIndex,
    required this.onTabSelected,
    this.topStatus,
    this.onQuickAdd,
    this.onQuickAddLongPress,
    this.backgroundColor = AppTheme.canvas,
    super.key,
  });

  final Widget body;
  final int activeIndex;
  final ValueChanged<int> onTabSelected;
  final Widget? topStatus;

  /// The «+»; null when the tab shows none.
  final VoidCallback? onQuickAdd;

  /// Repeats the last choice used on the plan.
  final VoidCallback? onQuickAddLongPress;
  final Color backgroundColor;

  @override
  State<PlanShellChrome> createState() => _PlanShellChromeState();
}

class _PlanShellChromeState extends State<PlanShellChrome> {
  bool _quickAddExpanded = true;

  bool _handleUserScroll(UserScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final expand = switch (notification.direction) {
      ScrollDirection.forward => true,
      ScrollDirection.reverse => false,
      ScrollDirection.idle =>
        notification.metrics.pixels <= 12 ? true : _quickAddExpanded,
    };
    if (_quickAddExpanded != expand) {
      setState(() => _quickAddExpanded = expand);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final quickAdd = widget.onQuickAdd;
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final section = JourneySection
        .values[widget.activeIndex.clamp(0, JourneySection.values.length - 1)];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: widget.backgroundColor,
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
              ?widget.topStatus,
              Expanded(
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: NotificationListener<UserScrollNotification>(
                    onNotification: _handleUserScroll,
                    child: widget.body,
                  ),
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: quickAdd != null && !keyboardVisible
            ? PlanQuickAddButton(
                color: section.color,
                icon: planQuickAddIconForTab(widget.activeIndex),
                label: planQuickAddLabelForTab(widget.activeIndex),
                expanded: _quickAddExpanded,
                onPressed: quickAdd,
                onLongPress: widget.onQuickAddLongPress,
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: AarastPlanNavigationBar.plan(
          activeIndex: widget.activeIndex,
          onSelected: widget.onTabSelected,
        ),
      ),
    );
  }
}
