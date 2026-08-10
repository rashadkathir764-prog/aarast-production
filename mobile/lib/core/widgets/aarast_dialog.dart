import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// نافذة حوار موحّدة لهوية أعّرست.
///
/// تبقي سلوك Material المجرّب مع لوحة المفاتيح وإمكانية الوصول، بينما تمنع
/// الشاشات من إنشاء حوارات بألوان ومسافات وأشكال مختلفة.
class AarastDialog extends StatelessWidget {
  const AarastDialog({
    required this.title,
    required this.content,
    this.actions = const [],
    this.icon,
    this.scrollable = true,
    super.key,
  });

  final Widget title;
  final Widget content;
  final List<Widget> actions;
  final Widget? icon;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppTheme.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shadowColor: AppTheme.inkSurface.withValues(alpha: 0.18),
        elevation: 12,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        titlePadding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 8),
        contentPadding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 12),
        actionsPadding: const EdgeInsetsDirectional.fromSTEB(12, 4, 12, 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusOverlay),
          side: const BorderSide(color: AppTheme.border),
        ),
        titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppTheme.textPrimary,
          height: 1.5,
        ),
        icon: icon,
        title: title,
        content: content,
        actions: actions,
        scrollable: scrollable,
      ),
    );
  }
}
