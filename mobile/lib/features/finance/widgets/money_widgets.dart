import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/money_formatters.dart';
import '../models/wedding_cost.dart';

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
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: AppTheme.iconMd, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          MoneyAmountText(amount: amount, currency: currency, color: color),
        ],
      ),
    );
  }
}

/// صف تكلفة نحيف: أيقونة مصبوغة بالحالة + عنوان + سطر ميتا + المبلغ.
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
    final leading = Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: status.background,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Icon(
        cost.providerId == null ? LucideIcons.receipt : LucideIcons.store,
        size: 18,
        color: status.color,
      ),
    );
    final metaParts = [?categoryName, ?cost.partyLabel].join(' · ');

    return AarastCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      radius: AppTheme.radiusMd,
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
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
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text.rich(
                  TextSpan(
                    children: [
                      if (metaParts.isNotEmpty)
                        TextSpan(text: '$metaParts · '),
                      TextSpan(
                        text: status.label,
                        style: TextStyle(
                          color: status.color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: AppTheme.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: MoneyAmountText(
              amount: cost.totalAmount,
              currency: currency,
              style: Theme.of(context).textTheme.labelLarge,
              color: cost.isCancelled ? AppTheme.muted : AppTheme.ink,
              textAlign: TextAlign.end,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            LucideIcons.chevronLeft,
            size: 16,
            color: AppTheme.disabled,
          ),
        ],
      ),
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
    this.costTitle,
    super.key,
  });

  final PaymentSchedule schedule;
  final String currency;
  final VoidCallback onTap;
  final String? costTitle;

  @override
  Widget build(BuildContext context) {
    final color = schedule.isOverdue
        ? AppTheme.danger
        : schedule.isPaid
        ? AppTheme.success
        : AppTheme.goldDeep;
    return AarastCard(
      onTap: onTap,
      border: Border.all(color: color.withValues(alpha: .24)),
      child: Row(
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
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  schedule.isOverdue
                      ? 'متأخر · ${formatArabicCompactDate(schedule.dueDate)}'
                      : formatArabicCompactDate(schedule.dueDate),
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
    );
  }
}

/// حالة التكلفة كهوية موحدة: نص ولون وخلفية تُستهلك في الشارة والصفوف.
({String label, Color color, Color background}) moneyStatusMeta(
  String status,
) {
  return switch (status) {
    'PAID' => (
      label: 'مكتملة',
      color: AppTheme.success,
      background: AppTheme.successSoft,
    ),
    'PARTIALLY_PAID' => (
      label: 'مدفوعة جزئيًا',
      color: AppTheme.warning,
      background: AppTheme.warningSoft,
    ),
    'CANCELLED' => (
      label: 'ملغاة',
      color: AppTheme.muted,
      background: AppTheme.empty,
    ),
    _ => (
      label: 'مفتوحة',
      color: AppTheme.burgundy,
      background: AppTheme.burgundySoft,
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
