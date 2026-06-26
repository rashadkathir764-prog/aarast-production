import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'aarast_ui.dart';

class AarastMetricTile extends StatelessWidget {
  const AarastMetricTile({
    required this.label,
    required this.value,
    this.icon,
    this.tone = AppTheme.dMaroon,
    this.subtitle,
    super.key,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color tone;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      padding: const EdgeInsets.all(14),
      color: AppTheme.dCard2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: tone.withAlpha(24),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Icon(icon, color: tone, size: 19),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.dInkSoft,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppTheme.dInk,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.dMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
