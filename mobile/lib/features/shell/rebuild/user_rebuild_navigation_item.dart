import 'package:flutter/material.dart';

import 'user_rebuild_tab.dart';

class UserRebuildNavigationItem {
  const UserRebuildNavigationItem({
    required this.tab,
    required this.label,
    required this.icon,
    required this.semanticPurpose,
    required this.requiresCurrentPlan,
  });

  factory UserRebuildNavigationItem.fromTab(UserRebuildTab tab) {
    return UserRebuildNavigationItem(
      tab: tab,
      label: tab.label,
      icon: tab.icon,
      semanticPurpose: tab.semanticPurpose,
      requiresCurrentPlan: tab.requiresCurrentPlan,
    );
  }

  final UserRebuildTab tab;
  final String label;
  final IconData icon;
  final String semanticPurpose;
  final bool requiresCurrentPlan;

  BottomNavigationBarItem toBottomNavigationBarItem() {
    return BottomNavigationBarItem(icon: Icon(icon), label: label);
  }
}
