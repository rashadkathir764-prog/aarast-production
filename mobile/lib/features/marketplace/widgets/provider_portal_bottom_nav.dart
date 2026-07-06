import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';

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

  static const _items = [
    (LucideIcons.home, 'الرئيسية'),
    (LucideIcons.mailQuestion, 'الطلبات'),
    (LucideIcons.sparkles, 'الخدمات'),
    (LucideIcons.messagesSquare, 'الرسائل'),
    (LucideIcons.userCircle, 'ملفي'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom + 14;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SizedBox(
        height: bottom + 82,
        child: Padding(
          padding: EdgeInsets.fromLTRB(18, 0, 18, bottom),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.ink.withValues(alpha: 0.08),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated.withValues(alpha: 0.92),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      for (var index = 0; index < _items.length; index++)
                        Expanded(
                          child: _ProviderNavItem(
                            icon: _items[index].$1,
                            label: _items[index].$2,
                            active: activeIndex == index,
                            badge: index == 3 ? unreadMessages : 0,
                            onTap: () => onSelected(index),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProviderNavItem extends StatelessWidget {
  const _ProviderNavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.badge,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppTheme.burgundy : AppTheme.muted;
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: active
                ? AppTheme.burgundy.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, size: 21, color: color),
                  if (badge > 0)
                    PositionedDirectional(
                      start: -9,
                      top: -8,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 17),
                        height: 17,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: const BoxDecoration(
                          color: AppTheme.danger,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          badge > 9 ? '9+' : '$badge',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 10.5,
                  fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
