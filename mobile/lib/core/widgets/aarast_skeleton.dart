import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/aarast_motion.dart';
import '../theme/app_theme.dart';

/// الهيكل العظمي الموحّد — نفس لغة V3 لكل الشاشات:
/// لؤلؤي، بأشكال الواجهة الحقيقية، مع shimmer يحترم تقليل الحركة.
///
/// الشاشات لا تبني CircularProgressIndicator لحالة تحميل الجسم أبداً —
/// إما skeleton من هنا أو AarastScreenLoading للانتقالات القصيرة.
class AarastSkeleton extends StatelessWidget {
  const AarastSkeleton({
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 24),
    this.inline = false,
    super.key,
  });

  /// قائمة بطاقات: ترويسة + صفوف متساوية — للقوائم (إشعارات، مشاركة، طلبات).
  factory AarastSkeleton.list({
    int rows = 6,
    double rowHeight = 84,
    bool withHeader = true,
    bool inline = false,
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(20, 16, 20, 24),
    Key? key,
  }) {
    return AarastSkeleton(
      key: key,
      padding: padding,
      inline: inline,
      children: [
        if (withHeader) ...[
          block(width: 150, height: 22, radius: 8),
          const SizedBox(height: 6),
          block(width: 220, height: 13, radius: 6),
          const SizedBox(height: 18),
        ],
        for (var i = 0; i < rows; i++) ...[
          block(height: rowHeight, radius: AppTheme.radiusLg),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  /// نموذج: حقول بعناوينها + زر أساسي — لشاشات الإدخال والإعدادات.
  factory AarastSkeleton.form({
    int fields = 4,
    bool withButton = true,
    bool inline = false,
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(20, 16, 20, 24),
    Key? key,
  }) {
    return AarastSkeleton(
      key: key,
      padding: padding,
      inline: inline,
      children: [
        for (var i = 0; i < fields; i++) ...[
          block(width: 110, height: 13, radius: 6),
          const SizedBox(height: 8),
          block(height: 54, radius: AppTheme.radiusLg),
          const SizedBox(height: 16),
        ],
        if (withButton) ...[
          const SizedBox(height: 8),
          block(height: 54, radius: AppTheme.radiusLg),
        ],
      ],
    );
  }

  /// صفحة غنية: بطل + صف مؤشرات + بطاقات — للوحات والمراكز.
  factory AarastSkeleton.page({
    double heroHeight = 168,
    int tiles = 3,
    int cards = 2,
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(20, 16, 20, 24),
    Key? key,
  }) {
    return AarastSkeleton(
      key: key,
      padding: padding,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  block(width: 130, height: 13, radius: 6),
                  const SizedBox(height: 8),
                  block(width: 90, height: 24, radius: 8),
                ],
              ),
            ),
            block(width: 44, height: 44, radius: 22),
          ],
        ),
        const SizedBox(height: 18),
        block(height: heroHeight, radius: AppTheme.radiusXl),
        if (tiles > 0) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              for (var i = 0; i < tiles; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: block(height: 96)),
              ],
            ],
          ),
        ],
        for (var i = 0; i < cards; i++) ...[
          const SizedBox(height: 14),
          block(height: 140, radius: AppTheme.radiusLg),
        ],
      ],
    );
  }

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  /// عند true يُبنى كعمود غير قابل للتمرير — للاستخدام داخل ListView قائمة.
  final bool inline;

  /// اللبنة الأساسية — نفس لون وشفافية هيكل V3.
  static Widget block({
    double? width,
    required double height,
    double radius = 16,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.border.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = inline
        ? Padding(
            padding: padding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          )
        : ListView(
            padding: padding,
            physics: const NeverScrollableScrollPhysics(),
            children: children,
          );

    if (AarastMotion.reduceMotion(context)) return content;

    return content
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(
          duration: 1400.ms,
          color: AppTheme.canvas.withValues(alpha: 0.9),
        );
  }
}
