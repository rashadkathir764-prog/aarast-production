import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../experience_v3/aarast_v3_foundations.dart';

/// نافذة حوار موحّدة لهوية اعّرست.
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
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AarastV3Space.x5,
          vertical: AarastV3Space.x6,
        ),
        titlePadding: const EdgeInsetsDirectional.fromSTEB(
          AarastV3Space.x5,
          AarastV3Space.x5,
          AarastV3Space.x5,
          AarastV3Space.x2,
        ),
        contentPadding: const EdgeInsetsDirectional.fromSTEB(
          AarastV3Space.x5,
          AarastV3Space.x1,
          AarastV3Space.x5,
          AarastV3Space.x3,
        ),
        actionsPadding: const EdgeInsetsDirectional.fromSTEB(
          AarastV3Space.x3,
          AarastV3Space.x1,
          AarastV3Space.x3,
          AarastV3Space.x3,
        ),
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
