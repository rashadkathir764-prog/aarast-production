import 'package:flutter/material.dart';

import '../../../core/config/app_feature_flags.dart';
import '../../wedding_plans/models/plan_summary_readiness.dart';
import 'user_rebuild_dashboard_summary_adapter.dart';
import 'user_rebuild_money_tab.dart';
import 'user_rebuild_navigation_item.dart';
import 'user_rebuild_placeholder_tab.dart';
import 'user_rebuild_tab.dart';

class UserRebuildShell extends StatefulWidget {
  const UserRebuildShell({
    super.key,
    this.initialTab = UserRebuildTab.home,
    this.featureFlags = AppFeatureFlags.defaults,
    this.planSummaryReadiness = const PlanSummaryReadiness.empty(),
  });

  final UserRebuildTab initialTab;
  final AppFeatureFlags featureFlags;
  final PlanSummaryReadiness planSummaryReadiness;

  @override
  State<UserRebuildShell> createState() => _UserRebuildShellState();
}

class _UserRebuildShellState extends State<UserRebuildShell> {
  late UserRebuildTab _selectedTab;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    final items = UserRebuildTab.values
        .map(UserRebuildNavigationItem.fromTab)
        .toList(growable: false);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: IndexedStack(
          index: UserRebuildTab.values.indexOf(_selectedTab),
          children: UserRebuildTab.values.map(_buildTabContent).toList(),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: UserRebuildTab.values.indexOf(_selectedTab),
          type: BottomNavigationBarType.fixed,
          onTap: (index) {
            setState(() {
              _selectedTab = UserRebuildTab.values[index];
            });
          },
          items: items
              .map((item) => item.toBottomNavigationBarItem())
              .toList(growable: false),
        ),
      ),
    );
  }

  Widget _buildTabContent(UserRebuildTab tab) {
    return switch (tab) {
      UserRebuildTab.home => UserRebuildDashboardSummaryAdapter(
        featureFlags: widget.featureFlags,
        readiness: widget.planSummaryReadiness,
      ),
      UserRebuildTab.money => const UserRebuildMoneyTab(),
      _ => UserRebuildPlaceholderTab.fromTab(tab),
    };
  }
}
