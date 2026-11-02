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
    this.dimension = 18,
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
        strokeWidth: 2,
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DecoratedBox(
        decoration: AppTheme.screenDecoration(),
        child: Center(
          child: AarastSkeletonPulse(
            child: Container(
              width: 164,
              padding: const EdgeInsets.all(AarastV3Space.x4),
              decoration: AppTheme.surfaceDecoration(
                color: AppTheme.surfaceRaised.withValues(alpha: 0.6),
                radius: AppTheme.radiusXl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox.square(
                    dimension: AarastV3Space.x6,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                  if (label != null) ...[
                    const SizedBox(height: AarastV3Space.x3),
                    Text(
                      label!,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
