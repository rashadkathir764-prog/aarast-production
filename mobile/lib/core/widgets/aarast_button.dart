import 'package:flutter/material.dart';

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
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AarastButtonVariant variant;
  final bool isLoading;
  final bool expand;

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
        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
        child: content,
      ),
    };

    return expand ? SizedBox(width: double.infinity, child: button) : button;
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
