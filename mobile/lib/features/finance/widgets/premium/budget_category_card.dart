import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/aarast_design_tokens.dart';
import '../../../../core/theme/aarast_motion.dart';
import '../../models/money_formatters.dart';
import '../../models/money_summary.dart';

double _money(String? raw) {
  if (raw == null) return 0;
  final cleaned = raw.replaceAll(RegExp(r'[^0-9.\-]'), '');
  return double.tryParse(cleaned) ?? 0;
}

IconData categoryIcon(String name) {
  if (name.contains('قاعة') || name.contains('صالة')) {
    return LucideIcons.building2;
  }
  if (name.contains('تصوير')) return LucideIcons.camera;
  if (name.contains('كوشة')) return LucideIcons.flower2;
  if (name.contains('ضيافة') ||
      name.contains('طعام') ||
      name.contains('غداء') ||
      name.contains('عشاء')) {
    return LucideIcons.utensils;
  }
  if (name.contains('فنان') || name.contains('موسيق')) {
    return LucideIcons.music;
  }
  if (name.contains('لبس') ||
      name.contains('ملابس') ||
      name.contains('أزياء')) {
    return LucideIcons.shirt;
  }
  if (name.contains('سيار') || name.contains('موكب')) {
    return LucideIcons.car;
  }
  return LucideIcons.tag;
}

/// بطاقة بند الميزانية — صف واحد نظيف بشريط تقدم حي وعمود لوني للحالة.
/// بديل صناديق-الأرقام المتراصة: كل ما تحتاجه في نظرة، والتفاصيل بنقرة.
class BudgetCategoryCard extends StatelessWidget {
  const BudgetCategoryCard({
    required this.row,
    required this.onOpenDetails,
    super.key,
  });

  final MoneyCategorySummary row;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final allocated = _money(row.allocated);
    final spent = _money(row.confirmedCost ?? row.spent);
    final remaining = _money(row.budgetRemaining ?? row.remaining);
    final hasBudget = allocated > 0;
    final ratio = hasBudget ? (spent / allocated).clamp(0.0, 1.0) : 0.0;
    final isOver = row.overBudget == true || (hasBudget && spent > allocated);
    final nearLimit = hasBudget && ratio >= 0.85 && !isOver;
    final reduceMotion = AarastMotion.reduceMotion(context);

    final accent = isOver
        ? AarastDesignTokens.danger
        : nearLimit
        ? AarastDesignTokens.warning
        : AarastDesignTokens.gold;

    final stateLabel = !hasBudget
        ? 'حدد ميزانية البند'
        : isOver
        ? 'تجاوز بـ ${formatCompactYemeniMoney(spent - allocated)}'
        : 'متبقي ${formatCompactYemeniMoney(remaining)}';
    final stateColor = !hasBudget
        ? AarastDesignTokens.muted
        : isOver
        ? AarastDesignTokens.danger
        : AarastDesignTokens.success;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenDetails,
        borderRadius: BorderRadius.circular(AarastDesignTokens.radiusLg),
        child: Ink(
          decoration: BoxDecoration(
            color: AarastDesignTokens.surface,
            borderRadius: BorderRadius.circular(AarastDesignTokens.radiusLg),
            border: Border.all(color: AarastDesignTokens.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AarastDesignTokens.radiusLg),
            child: Stack(
              children: [
                PositionedDirectional(
                  start: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 4, color: accent),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(18, 14, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AarastDesignTokens.goldSoft,
                              borderRadius: BorderRadius.circular(
                                AarastDesignTokens.radiusSm,
                              ),
                            ),
                            child: Icon(
                              categoryIcon(row.name),
                              color: AarastDesignTokens.gold,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  row.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AarastDesignTokens.ink,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  stateLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: stateColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                formatCompactYemeniMoney(spent),
                                textDirection: TextDirection.ltr,
                                style: TextStyle(
                                  color: isOver
                                      ? AarastDesignTokens.danger
                                      : AarastDesignTokens.ink,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'IBMPlexSansArabic',
                                ),
                              ),
                              Text(
                                hasBudget
                                    ? 'من ${formatCompactYemeniMoney(allocated)}'
                                    : 'غير محدد',
                                textDirection: TextDirection.ltr,
                                style: const TextStyle(
                                  color: AarastDesignTokens.muted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.chevron_left_rounded,
                            color: AarastDesignTokens.muted,
                            size: 20,
                          ),
                        ],
                      ),
                      if (hasBudget) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: ratio),
                            duration: reduceMotion
                                ? Duration.zero
                                : const Duration(milliseconds: 900),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, _) =>
                                LinearProgressIndicator(
                                  value: value,
                                  minHeight: 6,
                                  backgroundColor: AarastDesignTokens.border
                                      .withValues(alpha: 0.6),
                                  valueColor: AlwaysStoppedAnimation(accent),
                                ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// شارة صغيرة تُبني قائمة البنود بدخول متدرج هادئ.
Widget staggeredBudgetCard(Widget card, int index, bool reduceMotion) {
  if (reduceMotion) return card;
  return card
      .animate()
      .fadeIn(delay: (50 * index).ms, duration: 360.ms)
      .slideY(
        begin: 0.08,
        end: 0,
        delay: (50 * index).ms,
        duration: 360.ms,
        curve: Curves.easeOutCubic,
      );
}
