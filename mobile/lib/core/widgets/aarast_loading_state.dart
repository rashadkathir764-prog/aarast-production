import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/aarast_motion.dart';

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
              color: AppTheme.dCard2.withAlpha(220),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: AppTheme.dLine),
            ),
          ),
        );
      },
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
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: AppTheme.premiumCardDecoration(
                color: AppTheme.dCard2.withAlpha(235),
                radius: AppTheme.radiusXl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox.square(
                    dimension: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                  if (label != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      label!,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppTheme.dInkSoft,
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
