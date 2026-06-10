import 'package:flutter/material.dart';

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
        enabled ? Icons.check_circle : Icons.lock_outline,
        size: 18,
        color: enabled ? AppTheme.deepBurgundy : AppTheme.mediumGray,
      ),
      backgroundColor: enabled
          ? AppTheme.warmGold.withAlpha(45)
          : Colors.grey.withAlpha(25),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}
