import 'package:flutter/material.dart';

import 'package:lucide_icons/lucide_icons.dart';

import '../theme/aarast_motion.dart';
import '../theme/app_theme.dart';
import 'aarast_ui.dart';

/// ترويسة الميزات الموحّدة — نفس لغة «المال» و«المهام» لكل الشاشات:
/// عنوان display بخط IBM Plex + شارة حالة اختيارية + أزرار اختيارية،
/// مع دخول FadeSlide يحترم تقليل الحركة.
///
/// الشاشات لا تبني ترويسات محلية متفاوتة — إما هذه أو ترويسة
/// [AarastPageScaffold] المدمجة.
class AarastFeatureHeader extends StatelessWidget {
  const AarastFeatureHeader({
    required this.title,
    this.subtitle,
    this.statusLabel,
    this.statusColor = AppTheme.burgundy,
    this.statusIcon = LucideIcons.badgeCheck,
    this.actions = const [],
    this.showBack = false,
    this.onBack,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? statusLabel;
  final Color statusColor;
  final IconData statusIcon;
  final List<Widget> actions;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return AarastFadeSlide(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showBack) ...[
            IconButton(
              tooltip: 'رجوع',
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              icon: const Icon(LucideIcons.arrowRight),
            ),
            const SizedBox(width: AppTheme.gapSm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.headlineMedium?.copyWith(color: AppTheme.title),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (statusLabel != null) ...[
            const SizedBox(width: 10),
            AarastStatusPill(
              label: statusLabel!,
              color: statusColor,
              icon: statusIcon,
            ),
          ],
          for (final action in actions) ...[const SizedBox(width: 8), action],
        ],
      ),
    );
  }
}
