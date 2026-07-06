import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';

class PermissionChip extends StatelessWidget {
  const PermissionChip({required this.label, required this.enabled, super.key});

  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      avatar: Icon(
        enabled ? LucideIcons.checkCircle : LucideIcons.lock,
        size: 18,
        color: enabled ? AppTheme.deepBurgundy : AppTheme.mediumGray,
      ),
      backgroundColor: enabled
          ? AppTheme.warmGold.withValues(alpha: 0.1)
          : AppTheme.border.withAlpha(120),
      side: BorderSide(color: enabled ? AppTheme.gold2 : AppTheme.border),
      visualDensity: VisualDensity.compact,
    );
  }
}
