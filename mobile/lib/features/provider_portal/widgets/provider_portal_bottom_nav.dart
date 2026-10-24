import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../shell/shell_api.dart'
    show AarastNavigationItem, AarastPlanNavigationBar;

/// Provider navigation uses the same interaction grammar as the plan shell;
/// only its destinations and capability surface differ.
class ProviderPortalBottomNav extends StatelessWidget {
  const ProviderPortalBottomNav({
    required this.activeIndex,
    required this.onSelected,
    this.unreadMessages = 0,
    this.waitingRequests = 0,
    super.key,
  });

  final int activeIndex;
  final ValueChanged<int> onSelected;
  final int unreadMessages;

  /// The requests waiting for his answer (p13, p15).
  final int waitingRequests;

  @override
  Widget build(BuildContext context) {
    return AarastPlanNavigationBar(
      items: [
        const AarastNavigationItem(icon: LucideIcons.home, label: 'الرئيسية'),
        AarastNavigationItem(
          icon: LucideIcons.inbox,
          label: 'الطلبات',
          badge: waitingRequests,
        ),
        // p28: the calendar takes the third place, as drawn; the services
        // open from «ملفي».
        const AarastNavigationItem(
          icon: LucideIcons.calendarDays,
          label: 'التقويم',
        ),
        AarastNavigationItem(
          icon: LucideIcons.messageCircle,
          label: 'الرسائل',
          badge: unreadMessages,
        ),
        const AarastNavigationItem(icon: LucideIcons.store, label: 'ملفي'),
      ],
      activeIndex: activeIndex,
      onSelected: onSelected,
    );
  }
}
