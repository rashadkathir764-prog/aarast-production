import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/money_formatters.dart';
import '../models/wedding_cost.dart';

/// الغلاف البصري الموحّد لشاشات المال الفرعية.
///
/// الترويسة هادئة ومقصودة: رجوع، سياق «المال»، عنوان الشاشة، ثم الإجراء
/// المرتبط بهذه الشاشة فقط. لا تكرر ملخص المال ولا زر الإضافة العام.
class MoneySubpageScaffold extends StatelessWidget {
  const MoneySubpageScaffold({
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.showBack = true,
    this.onBack,
    this.padding = AppTheme.screenPadding,
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showBack;
  final VoidCallback? onBack;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AarastPageScaffold(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MoneySubpageHeader(
            title: title,
            subtitle: subtitle,
            actions: actions,
            showBack: showBack,
            onBack: onBack,
          ),
          const SizedBox(height: 18),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _MoneySubpageHeader extends StatelessWidget {
  const _MoneySubpageHeader({
    required this.title,
    required this.actions,
    required this.showBack,
    this.subtitle,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showBack) ...[
              _MoneyHeaderButton(
                icon: LucideIcons.arrowRight,
                tooltip: 'رجوع',
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'المال',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.goldDeep,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppTheme.ink,
                      fontFamily: AppTheme.displayFontFamily,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.end,
                  children: actions,
                ),
              ),
            ],
          ],
        ),
        if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: EdgeInsetsDirectional.only(start: showBack ? 56 : 0),
            child: Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.muted,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MoneyHeaderButton extends StatelessWidget {
  const _MoneyHeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: 44,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            foregroundColor: AppTheme.burgundy,
            backgroundColor: AppTheme.surface,
            side: const BorderSide(color: AppTheme.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
          ),
          child: Icon(icon, size: 20),
        ),
      ),
    );
  }
}

/// مساحة قسم هادئة للنماذج والتفاصيل؛ حدودها أخف من بطاقات الداشبورد حتى
/// يبقى التركيز على الحقول والمعلومة لا على تكديس الكروت.
class MoneySectionCard extends StatelessWidget {
  const MoneySectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.goldSoft,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(icon, size: 18, color: AppTheme.goldDeep),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.muted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// ملخص سجل مالي واحد. يستخدم سطحًا فاتحًا حتى لا تنافس كل شاشة فرعية
/// بطاقة البطل الداكنة الموجودة في شاشة المال الرئيسية.
class MoneyRecordHero extends StatelessWidget {
  const MoneyRecordHero({
    required this.icon,
    required this.label,
    required this.amount,
    required this.currency,
    required this.supportingText,
    this.statusLabel,
    this.statusColor = AppTheme.goldDeep,
    this.amountColor = AppTheme.ink,
    super.key,
  });

  final IconData icon;
  final String label;
  final Object? amount;
  final String currency;
  final String supportingText;
  final String? statusLabel;
  final Color statusColor;
  final Color amountColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: AppTheme.burgundySoft.withValues(alpha: .58),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppTheme.burgundy.withValues(alpha: .14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Icon(icon, color: AppTheme.burgundy, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (statusLabel != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 112),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                      border: Border.all(
                        color: statusColor.withValues(alpha: .18),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            statusLabel!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: AppTheme.ink,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: MoneyAmountText(
              amount: amount,
              currency: currency,
              color: amountColor,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontFamily: AppTheme.displayFontFamily,
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            supportingText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class MoneyAmountText extends StatelessWidget {
  const MoneyAmountText({
    required this.amount,
    required this.currency,
    this.style,
    this.color,
    this.textAlign,
    super.key,
  });

  final Object? amount;
  final String currency;
  final TextStyle? style;
  final Color? color;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final value = moneyValue(amount);
    final parts = compactMoneyParts(value, currencyCode: currency);
    return Semantics(
      label: parts.semanticText,
      child: Text(
        parts.directionalText,
        textDirection: TextDirection.ltr,
        textAlign: textAlign,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: (style ?? Theme.of(context).textTheme.titleMedium)?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class MoneyMetricCard extends StatelessWidget {
  const MoneyMetricCard({
    required this.label,
    required this.amount,
    required this.currency,
    required this.icon,
    this.color = AppTheme.burgundy,
    super.key,
  });

  final String label;
  final Object? amount;
  final String currency;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      radius: AppTheme.radiusLg,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                MoneyAmountText(
                  amount: amount,
                  currency: currency,
                  style: Theme.of(context).textTheme.titleSmall,
                  color: color,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// بطاقة التكلفة تعرض حالة السداد والأرقام الثلاثة من السجل نفسه.
class CostCard extends StatelessWidget {
  const CostCard({
    required this.cost,
    required this.currency,
    required this.onTap,
    this.categoryName,
    super.key,
  });

  final WeddingCost cost;
  final String currency;
  final VoidCallback onTap;
  final String? categoryName;

  @override
  Widget build(BuildContext context) {
    final status = moneyStatusMeta(cost.status);
    final metaParts = [?categoryName, ?cost.partyLabel].join(' · ');

    return AarastCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
      radius: AppTheme.radiusLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: status.background,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(
                  cost.providerId == null
                      ? LucideIcons.receipt
                      : LucideIcons.store,
                  size: 18,
                  color: status.color,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cost.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: cost.isCancelled ? AppTheme.muted : AppTheme.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (metaParts.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        metaParts,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.labelSmall?.copyWith(color: AppTheme.muted),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              MoneyStatusBadge(status: cost.status),
              const SizedBox(width: 3),
              const Icon(
                LucideIcons.chevronLeft,
                size: 15,
                color: AppTheme.disabled,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: AppTheme.border),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: _CostAmountMetric(
                  label: 'الإجمالي',
                  amount: cost.totalAmount,
                  currency: currency,
                  color: cost.isCancelled ? AppTheme.muted : AppTheme.ink,
                ),
              ),
              Expanded(
                child: _CostAmountMetric(
                  label: 'المدفوع',
                  amount: cost.paidAmount,
                  currency: currency,
                  color: cost.isCancelled ? AppTheme.muted : AppTheme.success,
                ),
              ),
              Expanded(
                child: _CostAmountMetric(
                  label: 'المتبقي للدفع',
                  amount: cost.remainingAmount,
                  currency: currency,
                  color: cost.isCancelled ? AppTheme.muted : AppTheme.warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CostAmountMetric extends StatelessWidget {
  const _CostAmountMetric({
    required this.label,
    required this.amount,
    required this.currency,
    required this.color,
  });

  final String label;
  final Object? amount;
  final String currency;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppTheme.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        MoneyAmountText(
          amount: amount,
          currency: currency,
          color: color,
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ],
    );
  }
}

class PaymentCard extends StatelessWidget {
  const PaymentCard({
    required this.payment,
    required this.currency,
    required this.onTap,
    this.costTitle,
    super.key,
  });

  final CostPayment payment;
  final String currency;
  final VoidCallback onTap;
  final String? costTitle;

  @override
  Widget build(BuildContext context) {
    final reversal = payment.isReversal;
    return AarastCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      radius: AppTheme.radiusMd,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: reversal ? AppTheme.dangerSoft : AppTheme.successSoft,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(
              reversal ? LucideIcons.undo2 : LucideIcons.banknote,
              size: 16,
              color: reversal ? AppTheme.danger : AppTheme.success,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reversal
                      ? 'عكس دفعة'
                      : (costTitle ?? payment.costTitle ?? 'دفعة'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatArabicCompactDate(payment.paidAt),
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: AppTheme.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 130),
            child: MoneyAmountText(
              amount: payment.signedAmount,
              currency: currency,
              style: Theme.of(context).textTheme.labelLarge,
              color: reversal ? AppTheme.danger : AppTheme.success,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class ScheduleCard extends StatelessWidget {
  const ScheduleCard({
    required this.schedule,
    required this.currency,
    required this.onTap,
    this.onPay,
    this.costTitle,
    super.key,
  });

  final PaymentSchedule schedule;
  final String currency;
  final VoidCallback onTap;
  final VoidCallback? onPay;
  final String? costTitle;

  @override
  Widget build(BuildContext context) {
    final color = schedule.isPaid
        ? AppTheme.success
        : schedule.isCancelled
        ? AppTheme.muted
        : schedule.isOverdue
        ? AppTheme.danger
        : AppTheme.goldDeep;
    final statusLabel = schedule.isPaid
        ? 'مدفوع'
        : schedule.isCancelled
        ? 'ملغي'
        : schedule.isOverdue
        ? 'متأخر'
        : 'معلّق';
    return AarastCard(
      onTap: onTap,
      border: Border.all(color: color.withValues(alpha: .24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(LucideIcons.calendarClock, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      costTitle ?? schedule.costTitle ?? 'موعد دفع',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$statusLabel · ${formatArabicCompactDate(schedule.dueDate)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 130),
                child: MoneyAmountText(
                  amount: schedule.amount,
                  currency: currency,
                  color: color,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          if (onPay != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: onPay,
                icon: const Icon(LucideIcons.banknote, size: 16),
                label: const Text('تسجيل الدفع'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// حالة التكلفة كهوية موحدة: نص ولون وخلفية تُستهلك في الشارة والصفوف.
({String label, Color color, Color background}) moneyStatusMeta(String status) {
  return switch (status) {
    'PAID' => (
      label: 'مكتمل الدفع',
      color: AppTheme.success,
      background: AppTheme.successSoft,
    ),
    'PARTIALLY_PAID' => (
      label: 'مدفوع جزئيًا',
      color: AppTheme.warning,
      background: AppTheme.warningSoft,
    ),
    'CANCELLED' => (
      label: 'ملغي',
      color: AppTheme.muted,
      background: AppTheme.muted.withValues(alpha: .10),
    ),
    _ => (
      label: 'لم يُدفع',
      color: AppTheme.muted,
      background: AppTheme.dangerSoft,
    ),
  };
}

class MoneyStatusBadge extends StatelessWidget {
  const MoneyStatusBadge({required this.status, super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final meta = moneyStatusMeta(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: meta.background,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Text(
        meta.label,
        maxLines: 1,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: meta.color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class MoneyMessageBanner extends StatelessWidget {
  const MoneyMessageBanner({
    required this.message,
    this.error = false,
    super.key,
  });

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: error ? AppTheme.dangerSoft : AppTheme.infoSoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: (error ? AppTheme.danger : AppTheme.info).withValues(
            alpha: .3,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            error ? LucideIcons.alertCircle : LucideIcons.info,
            color: error ? AppTheme.danger : AppTheme.info,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
