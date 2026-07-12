import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/aarast_design_tokens.dart';
import '../../../../core/theme/aarast_motion.dart';
import '../../../../core/utils/currency_label.dart';
import '../../models/dashboard_summary.dart';
import 'smart_dashboard_models.dart';

class AarastMoneyGlanceCard extends StatelessWidget {
  const AarastMoneyGlanceCard({
    required this.summary,
    required this.onOpenMoney,
    super.key,
  });

  final DashboardSummary summary;
  final VoidCallback onOpenMoney;

  @override
  Widget build(BuildContext context) {
    final total = parseAmount(summary.totalBudgetForDisplay);
    final spent = parseAmount(summary.spentTotalForDisplay) ?? 0;
    final commitments = parseAmount(summary.commitmentTotalForDisplay) ?? 0;
    final reportedRemaining = parseAmount(summary.remainingBudgetForDisplay);
    final hasBudget = total != null && total > 0;
    final confirmed = reportedRemaining != null && hasBudget
        ? total - reportedRemaining
        : spent + commitments;
    final remaining = reportedRemaining ?? (hasBudget ? total - confirmed : 0);
    final usedRatio = hasBudget ? (confirmed / total).clamp(0.0, 1.0) : 0.0;
    final currencyLabel = currencyLabelAr(summary.currency);
    final nearLimit = usedRatio >= 0.85;
    final reduceMotion = AarastMotion.reduceMotion(context);
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenMoney,
        borderRadius: BorderRadius.circular(AarastDesignTokens.radiusLg),
        child: Ink(
          decoration: BoxDecoration(
            color: AarastDesignTokens.surface,
            borderRadius: BorderRadius.circular(AarastDesignTokens.radiusLg),
            // لمسة ذهبية تميز أهم كرت تشغيلي عن بقية الأسطح.
            border: Border.all(
              color: AarastDesignTokens.gold.withValues(alpha: 0.4),
            ),
            boxShadow: [
              BoxShadow(
                color: AarastDesignTokens.gold.withValues(alpha: 0.1),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AarastDesignTokens.goldSoft,
                      borderRadius: BorderRadius.circular(
                        AarastDesignTokens.radiusSm,
                      ),
                    ),
                    child: const Icon(
                      LucideIcons.wallet,
                      color: AarastDesignTokens.gold,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'الميزانية',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AarastDesignTokens.title,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(
                    LucideIcons.chevronLeft,
                    size: 20,
                    color: AarastDesignTokens.muted.withValues(alpha: 0.7),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (!hasBudget)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AarastDesignTokens.goldSoft.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(
                      AarastDesignTokens.radiusSm,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.flag,
                        size: 16,
                        color: AarastDesignTokens.warning,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'حدد ميزانيتك العامة حتى نتابع معك كل ريال بهدوء.',
                          style: textTheme.labelMedium?.copyWith(
                            color: AarastDesignTokens.ink,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                Row(
                  children: [
                    _MoneyFigure(
                      label: 'المخصص',
                      value: formatAmount(total),
                      currencyLabel: currencyLabel,
                      color: AarastDesignTokens.ink,
                    ),
                    _MoneyFigure(
                      label: 'المؤكد',
                      value: formatAmount(confirmed),
                      currencyLabel: currencyLabel,
                      color: AarastDesignTokens.burgundy,
                    ),
                    _MoneyFigure(
                      label: 'المتبقي',
                      value: formatAmount(remaining),
                      currencyLabel: currencyLabel,
                      color: remaining < 0
                          ? AarastDesignTokens.danger
                          : AarastDesignTokens.success,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: usedRatio),
                    duration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 1100),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 7,
                      backgroundColor: AarastDesignTokens.border.withValues(
                        alpha: 0.6,
                      ),
                      valueColor: AlwaysStoppedAnimation(
                        nearLimit
                            ? AarastDesignTokens.warning
                            : AarastDesignTokens.gold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  nearLimit
                      ? 'مستخدم ${(usedRatio * 100).round()}% — اقتربت من حد الميزانية، فراجع البنود قبل أي دفعة جديدة.'
                      : 'مستخدم ${(usedRatio * 100).round()}% من الميزانية',
                  style: textTheme.labelSmall?.copyWith(
                    color: nearLimit
                        ? AarastDesignTokens.warning
                        : AarastDesignTokens.muted,
                    fontWeight: FontWeight.w700,
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

class _MoneyFigure extends StatelessWidget {
  const _MoneyFigure({
    required this.label,
    required this.value,
    required this.currencyLabel,
    required this.color,
  });

  final String label;
  final String value;
  final String currencyLabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: AarastDesignTokens.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text.rich(
              TextSpan(
                text: value,
                style: textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
                children: [
                  TextSpan(
                    text: ' $currencyLabel',
                    style: textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
