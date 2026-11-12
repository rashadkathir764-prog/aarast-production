import 'package:flutter/material.dart';

import '../../../core/experience_v3/aarast_journey.dart';
import '../../../core/experience_v3/aarast_journey_profile.dart';
import '../../../core/security/screen_protection.dart';
import '../../../core/theme/app_theme.dart';
import 'aarast_plan_chrome.dart';
import 'plan_quick_add.dart';
import 'plan_quick_add_sheet.dart';

/// The plan's tabs around one tab's page (b02, c01, d01, e01, f01), with the
/// floating «+» the owner asked to keep (D33) when [onQuickAdd] is given. It
/// takes the tab's colour and name («إضافة مهمة»، «إضافة ضيف») and hides
/// while the keyboard is open. Its word shows only where the page is short
/// enough to have nothing under the button (D112, Q-23); on the home it is
/// always the sign alone ([planQuickAddShowsLabel]).
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
  final _bodyKey = GlobalKey();

  /// Whether the page in front runs under the «+». D112 (Q-23): the «+»
  /// then is the sign alone, because a row's amount sits on the side the
  /// button floats on and its word covered it. A page short enough to have
  /// nothing under the button keeps the word.
  bool _pageRunsUnder = false;
  bool _checkScheduled = false;

  @override
  void initState() {
    super.initState();
    _scheduleCheck();
  }

  @override
  void didUpdateWidget(PlanShellChrome oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Another tab in front, or another page in the same tab.
    _scheduleCheck();
  }

  void _scheduleCheck() {
    if (_checkScheduled) return;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      if (!mounted) return;
      final runsUnder = _visiblePageScrolls();
      if (runsUnder != _pageRunsUnder) {
        setState(() => _pageRunsUnder = runsUnder);
      }
    });
  }

  /// Whether a vertical list of the page in front holds more than fits.
  /// Tabs kept alive behind it (an [IndexedStack], a held page) are not
  /// read: their length says nothing about what the button covers now.
  bool _visiblePageScrolls() {
    var scrolls = false;
    void visit(Element element) {
      if (scrolls) return;
      final widget = element.widget;
      if (widget is Visibility && !widget.visible) return;
      if (widget is Offstage && widget.offstage) return;
      if (widget is Scrollable &&
          axisDirectionToAxis(widget.axisDirection) == Axis.vertical) {
        final position =
            ((element as StatefulElement).state as ScrollableState).position;
        if (position.hasContentDimensions && position.maxScrollExtent > 0) {
          scrolls = true;
        }
        return;
      }
      element.visitChildren(visit);
    }

    _bodyKey.currentContext?.visitChildElements(visit);
    return scrolls;
  }

  bool _handleMetrics(ScrollMetricsNotification notification) {
    if (notification.metrics.axis == Axis.vertical) _scheduleCheck();
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
                  child: NotificationListener<ScrollMetricsNotification>(
                    onNotification: _handleMetrics,
                    // D112 (Q-8): the money tab is a money screen; with
                    // the lock on it takes no screenshot.
                    child: MoneyScreenShield(
                      active: section == JourneySection.money,
                      child: KeyedSubtree(key: _bodyKey, child: widget.body),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: quickAdd != null && !keyboardVisible
            ? PlanQuickAddButton(
                color: section.colorOf(context),
                icon: planQuickAddIconForTab(widget.activeIndex),
                label: planQuickAddLabelForTab(
                  widget.activeIndex,
                  context.journeyProfile,
                ),
                expanded:
                    !_pageRunsUnder &&
                    planQuickAddShowsLabel(widget.activeIndex),
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
