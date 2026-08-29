import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../../core/utils/money_formatters.dart';
import '../models/wedding_cost.dart';
import '../providers/finance_provider.dart';

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
    this.bottomNavigationBar,
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showBack;
  final VoidCallback? onBack;
  final EdgeInsetsGeometry padding;
  final Widget? bottomNavigationBar;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AarastPageScaffold(
      padding: padding,
      bottomNavigationBar: bottomNavigationBar,
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
          const SizedBox(height: 12),
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
          crossAxisAlignment: CrossAxisAlignment.center,
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
                      color: AppTheme.brand,
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
                      color: AppTheme.textPrimary,
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var index = 0; index < actions.length; index++) ...[
                    actions[index],
                    if (index != actions.length - 1) const SizedBox(width: 4),
                  ],
                ],
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
                color: AppTheme.textSecondary,
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
            foregroundColor: AppTheme.brand,
            backgroundColor: AppTheme.surfaceMuted,
            side: BorderSide.none,
            shape: const CircleBorder(),
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
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: AppTheme.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: AppTheme.brand),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// Optional finance details stay collapsed until the user needs them. This
/// keeps transaction forms focused on the amount and decision being made.
class MoneyDisclosureCard extends StatelessWidget {
  const MoneyDisclosureCard({
    required this.title,
    required this.icon,
    required this.child,
    this.subtitle,
    this.initiallyExpanded = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget child;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return AarastV3Disclosure(
      title: title,
      subtitle: subtitle,
      icon: icon,
      initiallyExpanded: initiallyExpanded,
      child: child,
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
    this.statusColor = AppTheme.brand,
    this.amountColor = AppTheme.textPrimary,
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
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppTheme.brandMuted.withValues(alpha: .58),
        borderRadius: BorderRadius.circular(AppTheme.radiusSurface),
        border: Border.all(color: AppTheme.brand.withValues(alpha: .14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceRaised,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Icon(icon, color: AppTheme.brand, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.textSecondary,
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
                      color: AppTheme.surfaceRaised,
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
                                  color: AppTheme.textPrimary,
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
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: MoneyAmountText(
              amount: amount,
              currency: currency,
              color: amountColor,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontFamily: AppTheme.displayFontFamily,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            supportingText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
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
    final amountsHidden = context.select<FinanceProvider?, bool>(
      (provider) => provider?.amountsHidden ?? false,
    );
    if (amountsHidden) {
      return Semantics(
        label: 'القيمة المالية مخفية',
        child: ExcludeSemantics(
          child: Text(
            '••••',
            textDirection: TextDirection.ltr,
            textAlign: textAlign,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (style ?? Theme.of(context).textTheme.titleMedium)?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8,
            ),
          ),
        ),
      );
    }
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

class MoneyPrivacyButton extends StatelessWidget {
  const MoneyPrivacyButton({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final hidden = context.select<FinanceProvider, bool>(
      (provider) => provider.amountsHidden,
    );
    return Semantics(
      button: true,
      toggled: hidden,
      label: hidden ? 'إظهار المبالغ المالية' : 'إخفاء المبالغ المالية',
      child: IconButton(
        key: const ValueKey('money-privacy-toggle'),
        onPressed: context.read<FinanceProvider>().toggleAmountsVisibility,
        tooltip: hidden ? 'إظهار المبالغ' : 'إخفاء المبالغ',
        style: IconButton.styleFrom(
          foregroundColor: AppTheme.brand,
          backgroundColor: compact ? Colors.transparent : AppTheme.surfaceMuted,
          minimumSize: Size.square(compact ? 40 : 48),
          maximumSize: Size.square(compact ? 40 : 48),
          padding: EdgeInsets.zero,
        ),
        icon: Icon(hidden ? LucideIcons.eye : LucideIcons.eyeOff, size: 18),
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
    this.color = AppTheme.brand,
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
                    color: AppTheme.textSecondary,
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
    final remaining = moneyValue(cost.remainingAmount);
    final amountLabel = remaining > 0 ? 'غير مدفوع' : 'الإجمالي';
    final amount = remaining > 0 ? cost.remainingAmount : cost.totalAmount;

    return AarastPressable(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      child: Container(
        constraints: const BoxConstraints(minHeight: 78),
        padding: const EdgeInsets.fromLTRB(2, 10, 2, 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    cost.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: cost.isCancelled
                          ? AppTheme.textSecondary
                          : AppTheme.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    metaParts.isEmpty
                        ? status.label
                        : '$metaParts · ${status.label}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cost.isPaid
                          ? AppTheme.success
                          : AppTheme.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 112),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    amountLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  MoneyAmountText(
                    amount: amount,
                    currency: currency,
                    color: cost.isCancelled
                        ? AppTheme.textSecondary
                        : remaining > 0
                        ? AppTheme.warning
                        : AppTheme.success,
                    style: Theme.of(context).textTheme.labelMedium,
                    textAlign: TextAlign.end,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              LucideIcons.chevronLeft,
              size: 15,
              color: AppTheme.textDisabled,
            ),
          ],
        ),
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
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatArabicCompactDate(payment.paidAt),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
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
        ? AppTheme.textSecondary
        : schedule.isOverdue
        ? AppTheme.danger
        : AppTheme.brand;
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
      color: AppTheme.textSecondary,
      background: AppTheme.textSecondary.withValues(alpha: .10),
    ),
    _ => (
      label: 'لم يُدفع',
      color: AppTheme.textSecondary,
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
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
