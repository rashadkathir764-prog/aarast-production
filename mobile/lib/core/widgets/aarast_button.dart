import 'package:flutter/material.dart';

import '../experience_v3/aarast_v3_foundations.dart';
import '../theme/app_theme.dart';

enum AarastButtonVariant { primary, secondary, ghost, danger }

class AarastButton extends StatelessWidget {
  const AarastButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AarastButtonVariant.primary,
    this.isLoading = false,
    this.expand = true,
    this.compact = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AarastButtonVariant variant;
  final bool isLoading;
  final bool expand;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final content = _AarastButtonContent(
      label: label,
      icon: icon,
      isLoading: isLoading,
    );

    final button = switch (variant) {
      AarastButtonVariant.primary => ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          minimumSize: Size.fromHeight(compact ? 48 : 52),
          backgroundColor: AarastV3Color.primary,
          foregroundColor: AarastV3Color.onPrimary,
          disabledBackgroundColor: AarastV3Color.lineStrong,
          disabledForegroundColor: Colors.white70,
          tapTargetSize: compact ? MaterialTapTargetSize.shrinkWrap : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              compact ? AarastV3Radius.surface : AarastV3Radius.control,
            ),
          ),
        ),
        child: content,
      ),
      AarastButtonVariant.secondary => OutlinedButton(
        onPressed: enabled ? onPressed : null,
        child: content,
      ),
      AarastButtonVariant.ghost => TextButton(
        onPressed: enabled ? onPressed : null,
        child: content,
      ),
      AarastButtonVariant.danger => ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          minimumSize: Size.fromHeight(compact ? 48 : 52),
          backgroundColor: AppTheme.danger,
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white70,
          tapTargetSize: compact ? MaterialTapTargetSize.shrinkWrap : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              compact ? AarastV3Radius.surface : AarastV3Radius.control,
            ),
          ),
        ),
        child: content,
      ),
    };

    final accessibleButton = isLoading
        ? Semantics(
            container: true,
            excludeSemantics: true,
            button: true,
            enabled: false,
            label: label,
            value: 'جارٍ التنفيذ',
            liveRegion: true,
            child: button,
          )
        : button;

    return expand
        ? SizedBox(width: double.infinity, child: accessibleButton)
        : accessibleButton;
  }
}

class _AarastButtonContent extends StatelessWidget {
  const _AarastButtonContent({
    required this.label,
    required this.isLoading,
    this.icon,
  });

  final String label;
  final bool isLoading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox.square(
        dimension: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    );

    if (icon == null) return text;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Flexible(child: text),
      ],
    );
  }
}
