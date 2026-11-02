import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../experience_v3/aarast_v3_foundations.dart';

class AarastStatusBadge extends StatelessWidget {
  const AarastStatusBadge({
    required this.label,
    this.icon,
    this.color = AppTheme.brand,
    this.backgroundColor,
    super.key,
  });

  final String label;
  final IconData? icon;
  final Color color;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AarastV3Space.x2,
        vertical: AarastV3Space.x1,
      ),
      decoration: BoxDecoration(
        color: backgroundColor ?? color.withAlpha(24),
        borderRadius: BorderRadius.circular(AarastV3Radius.pill),
        border: Border.all(color: color.withAlpha(48)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: AarastV3Space.x1),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
