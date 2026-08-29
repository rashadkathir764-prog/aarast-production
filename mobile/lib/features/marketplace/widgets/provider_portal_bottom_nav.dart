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
    super.key,
  });

  final int activeIndex;
  final ValueChanged<int> onSelected;
  final int unreadMessages;

  @override
  Widget build(BuildContext context) {
    return AarastPlanNavigationBar(
      items: [
        const AarastNavigationItem(icon: LucideIcons.home, label: 'الرئيسية'),
        const AarastNavigationItem(
          icon: LucideIcons.mailQuestion,
          label: 'الطلبات',
        ),
        const AarastNavigationItem(
          icon: LucideIcons.sparkles,
          label: 'الخدمات',
        ),
        AarastNavigationItem(
          icon: LucideIcons.messagesSquare,
          label: 'الرسائل',
          badge: unreadMessages,
        ),
        const AarastNavigationItem(icon: LucideIcons.userCircle, label: 'ملفي'),
      ],
      activeIndex: activeIndex,
      onSelected: onSelected,
    );
  }
}
