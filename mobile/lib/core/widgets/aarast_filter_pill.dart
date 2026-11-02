import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../experience_v3/aarast_v3_foundations.dart';

/// شريحة الفلترة الموحدة عبر كل التبويبات (المهام/الضيوف/المزودين/المال).
///
/// المحدد = لون صلب ونص أبيض؛ غير المحدد = خلفية ناعمة
/// (`softColor`) بنص ملون، أو سطح أبيض بحدود عند تركها الافتراضية.
class AarastFilterPill extends StatelessWidget {
  const AarastFilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.color = AppTheme.brand,
    this.softColor = AppTheme.surfaceRaised,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color color;
  final Color softColor;

  @override
  Widget build(BuildContext context) {
    final onSurface = softColor == AppTheme.surfaceRaised;
    final disabled = onTap == null;
    final foreground = selected
        ? Colors.white
        : disabled
        ? AppTheme.textDisabled
        : onSurface
        ? AppTheme.textPrimary
        : color;
    final borderColor = selected
        ? color
        : onSurface
        ? AppTheme.border
        : color.withValues(alpha: .28);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        child: AnimatedContainer(
          duration: AppTheme.motionFast,
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          padding: AarastV3Density.chipInsets,
          decoration: BoxDecoration(
            color: selected ? color : softColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 15,
                  color: selected
                      ? Colors.white
                      : onSurface
                      ? AppTheme.brand
                      : color,
                ),
                const SizedBox(width: AarastV3Space.x1),
              ],
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// صف اختيار مفرد من شرائح — بديل الهوية للقوائم المنسدلة الثابتة.
class AarastChoicePillRow<T> extends StatelessWidget {
  const AarastChoicePillRow({
    required this.value,
    required this.options,
    required this.onChanged,
    super.key,
  });

  final T value;
  final List<(T, String)> options;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (option, label) in options)
          AarastFilterPill(
            key: ValueKey('choice-pill-$option'),
            label: label,
            selected: option == value,
            onTap: onChanged == null ? null : () => onChanged!(option),
          ),
      ],
    );
  }
}
