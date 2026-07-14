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
    final leading = Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: cost.isCancelled ? AppTheme.empty : AppTheme.burgundySoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Icon(
        cost.providerId == null ? LucideIcons.receipt : LucideIcons.store,
        color: cost.isCancelled ? AppTheme.muted : AppTheme.burgundy,
      ),
    );
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          cost.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppTheme.ink,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (categoryName != null || cost.partyLabel != null) ...[
          const SizedBox(height: 4),
          Text(
            [?categoryName, ?cost.partyLabel].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
          ),
        ],
      ],
    );
    final status = MoneyStatusBadge(status: cost.status);
    return AarastCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 280;
              final identityRow = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  leading,
                  const SizedBox(width: 12),
                  Expanded(child: identity),
                  if (!narrow) ...[const SizedBox(width: 8), status],
                ],
              );
              if (!narrow) return identityRow;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  identityRow,
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: status,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _LabeledAmount(
                  label: 'الإجمالي',
                  amount: cost.totalAmount,
                  currency: currency,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LabeledAmount(
                  label: 'الباقي',
                  amount: cost.remainingAmount,
                  currency: currency,
                  color: moneyValue(cost.remainingAmount) > 0
                      ? AppTheme.warning
                      : AppTheme.success,
                ),
              ),
            ],
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
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: reversal ? AppTheme.dangerSoft : AppTheme.successSoft,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Icon(
              reversal ? LucideIcons.undo2 : LucideIcons.banknote,
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
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  formatArabicCompactDate(payment.paidAt),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
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

class MoneyStatusBadge extends StatelessWidget {
  const MoneyStatusBadge({required this.status, super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color, background) = switch (status) {
      'PAID' => ('مكتملة', AppTheme.success, AppTheme.successSoft),
      'PARTIALLY_PAID' => (
        'مدفوعة جزئيًا',
        AppTheme.warning,
        AppTheme.warningSoft,
      ),
      'CANCELLED' => ('ملغاة', AppTheme.muted, AppTheme.empty),
      _ => ('مفتوحة', AppTheme.burgundy, AppTheme.burgundySoft),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
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

class _LabeledAmount extends StatelessWidget {
  const _LabeledAmount({
    required this.label,
    required this.amount,
    required this.currency,
    this.color,
  });

  final String label;
  final Object? amount;
  final String currency;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppTheme.muted),
        ),
        const SizedBox(height: 3),
        MoneyAmountText(amount: amount, currency: currency, color: color),
      ],
    );
  }
}
