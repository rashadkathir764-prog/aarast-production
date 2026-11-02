import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'aarast_pressable.dart';
import '../experience_v3/aarast_v3_foundations.dart';

/// A contained grouping only when background separation improves comprehension.
/// Most page sections should use [AarastSection] instead of nesting surfaces.
class AarastSurface extends StatelessWidget {
  const AarastSurface({
    required this.child,
    this.padding = const EdgeInsets.all(AarastV3Space.x4),
    this.margin = EdgeInsets.zero,
    this.color = AppTheme.surfaceRaised,
    this.radius = AppTheme.radiusSurface,
    this.borderColor = AppTheme.borderStrong,
    this.elevated = false,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color color;
  final double radius;
  final Color borderColor;
  final bool elevated;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final content = AnimatedContainer(
      duration: AppTheme.motionFast,
      curve: AppTheme.motionCurve,
      width: double.infinity,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
        border: Border.all(
          color: elevated ? AppTheme.borderStrong : borderColor,
          width: elevated ? 1.5 : 1,
        ),
      ),
      child: child,
    );

    if (onTap == null) return content;

    return AarastPressable(
      onTap: onTap!,
      borderRadius: borderRadius,
      clip: true,
      child: content,
    );
  }
}

/// A logical page grouping with no automatic card, shadow, or fill.
class AarastSection extends StatelessWidget {
  const AarastSection({
    required this.child,
    this.title,
    this.description,
    this.action,
    this.spacing = AppTheme.space12,
    super.key,
  });

  final Widget child;
  final String? title;
  final String? description;
  final Widget? action;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final hasHeading = title != null || description != null || action != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasHeading) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null)
                      Text(
                        title!,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    if (description != null) ...[
                      const SizedBox(height: AppTheme.space4),
                      Text(
                        description!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (action != null) ...[
                const SizedBox(width: AppTheme.space12),
                action!,
              ],
            ],
          ),
          SizedBox(height: spacing),
        ],
        child,
      ],
    );
  }
}
