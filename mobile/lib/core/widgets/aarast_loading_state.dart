import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/aarast_motion.dart';
import '../experience_v3/aarast_v3_foundations.dart';

class AarastLoadingState extends StatelessWidget {
  const AarastLoadingState({this.rows = 4, this.height = 86, super.key});

  final int rows;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: rows,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppTheme.gapMd),
      itemBuilder: (context, index) {
        return AarastSkeletonPulse(
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: AppTheme.surfaceRaised.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: AppTheme.border),
            ),
          ),
        );
      },
    );
  }
}

/// سبنر صغير موحّد لأزرار الأيقونات والمواضع الضيقة — الشاشات لا تبني
/// CircularProgressIndicator مباشرة؛ سبنر الأزرار النصية عبر
/// AarastButton.isLoading وهذا للأيقونية.
class AarastInlineSpinner extends StatelessWidget {
  const AarastInlineSpinner({
    this.dimension = AarastV3Icon.md,
    this.color = AppTheme.brand,
    super.key,
  });

  final double dimension;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: dimension,
      child: CircularProgressIndicator(
        strokeWidth: AarastV3Size.lineStrong,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

class AarastScreenLoading extends StatelessWidget {
  const AarastScreenLoading({this.label, super.key});

  final String? label;

  @override
  Widget build(BuildContext context) {
    // Critique ط3: one loading look for a whole screen, the plan gate's own:
    // the kit's spinner in the plan's colour on the canvas. The pulsing card
    // around a Material ring was a second look.
    return Directionality(
      textDirection: TextDirection.rtl,
      child: ColoredBox(
        color: AarastV3Color.canvas,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AarastInlineSpinner(
                dimension: AarastV3Icon.xl,
                color: AarastV3Color.primary,
              ),
              if (label != null) ...[
                const SizedBox(height: AarastV3Space.x3),
                Text(
                  label!,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AarastV3Color.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
