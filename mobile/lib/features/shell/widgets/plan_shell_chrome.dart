import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../core/experience_v3/aarast_journey.dart';
import '../../../core/theme/app_theme.dart';
import '../../wedding_plans/wedding_plans_api.dart'
    show planQuickAddIconForTab, planQuickAddLabelForTab;
import 'aarast_plan_chrome.dart';

class PlanShellChrome extends StatefulWidget {
  const PlanShellChrome({
    required this.body,
    required this.activeIndex,
    required this.onTabSelected,
    required this.showQuickFab,
    this.topStatus,
    this.onQuickAdd,
    this.onQuickAddLongPress,
    this.backgroundColor = AppTheme.canvas,
    super.key,
  });

  final Widget body;
  final int activeIndex;
  final ValueChanged<int> onTabSelected;
  final bool showQuickFab;
  final Widget? topStatus;
  final VoidCallback? onQuickAdd;
  final VoidCallback? onQuickAddLongPress;
  final Color backgroundColor;

  @override
  State<PlanShellChrome> createState() => _PlanShellChromeState();
}

class _PlanShellChromeState extends State<PlanShellChrome> {
  bool _quickActionExpanded = true;

  bool _handleUserScroll(UserScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final shouldExpand = switch (notification.direction) {
      ScrollDirection.forward => true,
      ScrollDirection.reverse => false,
      ScrollDirection.idle =>
        notification.metrics.pixels <= 12 ? true : _quickActionExpanded,
    };
    if (_quickActionExpanded != shouldExpand) {
      setState(() => _quickActionExpanded = shouldExpand);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final quickAdd = widget.onQuickAdd;
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
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
              if (widget.topStatus != null) widget.topStatus!,
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
        floatingActionButton:
            widget.showQuickFab && quickAdd != null && !keyboardVisible
            ? AarastQuickActionButton(
                color: JourneySection
                    .values[widget.activeIndex.clamp(
                      0,
                      JourneySection.values.length - 1,
                    )]
                    .color,
                icon: planQuickAddIconForTab(widget.activeIndex),
                label: planQuickAddLabelForTab(widget.activeIndex),
                expanded: _quickActionExpanded,
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
