import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/aarast_ui.dart';
import '../../models/money_formatters.dart';
import '../../models/money_summary.dart';

class FinanceOverviewHeader extends StatelessWidget {
  const FinanceOverviewHeader({
    required this.statusColor,
    required this.statusLabel,
    super.key,
  });

  final Color statusColor;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            'المال',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: AppTheme.title),
          ),
        ),
        const SizedBox(width: 10),
        AarastStatusPill(
          label: statusLabel,
          color: statusColor,
          icon: LucideIcons.badgeCheck,
        ),
      ],
    );
  }
}

class FinancialWarningsCard extends StatelessWidget {
  const FinancialWarningsCard({required this.warnings, super.key});

  final List<MoneyFinancialWarning> warnings;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      padding: const EdgeInsets.all(14),
      color: AppTheme.dangerSoft,
      border: Border.all(color: AppTheme.danger.withAlpha(32)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AarastSectionHeader(
            title: 'تنبيهات مالية',
            icon: LucideIcons.alertTriangle,
          ),
          const SizedBox(height: 10),
          for (final warning in warnings.take(4)) ...[
            Row(
              children: [
                Icon(
                  LucideIcons.alertCircle,
                  color: warning.severity == 'DANGER'
                      ? AppTheme.danger
                      : AppTheme.gold,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _warningCopy(warning),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class FinanceSectionCard extends StatelessWidget {
  const FinanceSectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.onTap,
    super.key,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = AarastCard(
      padding: EdgeInsets.zero,
      border: Border.all(color: AppTheme.border),
      color: AppTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: AppTheme.burgundy),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (onTap != null)
                  const Icon(LucideIcons.chevronLeft, color: AppTheme.muted),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: content,
      ),
    );
  }
}

class FinanceTapInlineTile extends StatelessWidget {
  const FinanceTapInlineTile({
    required this.onTap,
    required this.child,
    super.key,
  });

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(child: child),
              const SizedBox(width: 6),
              const Icon(LucideIcons.chevronLeft, color: AppTheme.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class FinanceMoneyEventTile extends StatelessWidget {
  const FinanceMoneyEventTile({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.icon,
    required this.color,
    required this.currencyCode,
    super.key,
  });

  final String title;
  final String subtitle;
  final String amount;
  final IconData icon;
  final Color color;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          formatCompactMoney(_moneyValue(amount), currencyCode: currencyCode),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class FinanceTinyEmptyText extends StatelessWidget {
  const FinanceTinyEmptyText({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      textAlign: TextAlign.right,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: AppTheme.muted,
        fontWeight: FontWeight.w700,
        height: 1.35,
      ),
    );
  }
}

class FinanceOverviewLoadingState extends StatelessWidget {
  const FinanceOverviewLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 120),
      children: const [
        _SkeletonBox(height: 226),
        SizedBox(height: 20),
        _SkeletonBox(height: 78),
        SizedBox(height: 10),
        _SkeletonBox(height: 78),
        SizedBox(height: 22),
        _SkeletonBox(height: 88),
        SizedBox(height: 10),
        _SkeletonBox(height: 88),
      ],
    );
  }
}

class FinanceOverviewAccessDeniedState extends StatelessWidget {
  const FinanceOverviewAccessDeniedState({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 120),
      children: const [
        AarastEmptyState(
          title: 'الميزانية خاصة',
          message: 'ليست لديك صلاحية عرض التفاصيل المالية.',
          icon: LucideIcons.lock,
        ),
      ],
    );
  }
}

class FinanceOverviewInlineError extends StatelessWidget {
  const FinanceOverviewInlineError({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.dangerSoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.dangerSoft),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.alertCircle, color: AppTheme.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.danger,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border),
      ),
    );
  }
}

num _moneyValue(String value) =>
    num.tryParse(value.replaceAll(',', '').trim()) ?? 0;

String _warningCopy(MoneyFinancialWarning warning) {
  return switch (warning.type) {
    'BUDGET_EXCEEDED' => 'ميزانيتك تجاوزت الحد',
    'CATEGORY_EXCEEDED' => 'تصنيف في الميزانية تجاوز المخصص',
    'INSTALLMENT_OVERDUE' => 'دفعة متأخرة تحتاج متابعة',
    'INSTALLMENT_DUE_SOON' => 'دفعة قادمة تحتاج متابعة',
    'EXPENSE_WITHOUT_CATEGORY' => 'مصروف بدون تصنيف يحتاج ترتيب',
    _ =>
      warning.message.trim().isEmpty
          ? 'تنبيه مالي يحتاج متابعة'
          : warning.message,
  };
}
