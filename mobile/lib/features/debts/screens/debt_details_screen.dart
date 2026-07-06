import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/phone/phone_number_utils.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../wedding_plans/providers/wedding_plans_provider.dart';
import '../models/debt.dart';
import '../models/installment.dart';
import '../providers/debt_installment_provider.dart';

class DebtDetailsScreen extends StatefulWidget {
  const DebtDetailsScreen({required this.debtId, super.key});

  final String debtId;

  @override
  State<DebtDetailsScreen> createState() => _DebtDetailsScreenState();
}

class _DebtDetailsScreenState extends State<DebtDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<DebtInstallmentProvider>().loadDebtDetails(widget.debtId);
    });
  }

  @override
  void didUpdateWidget(covariant DebtDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.debtId != widget.debtId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<DebtInstallmentProvider>().loadDebtDetails(widget.debtId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DebtInstallmentProvider>();

    return AarastScreenFrame(
      maxWidth: 520,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
            child: Row(
              children: [
                IconButton(
                  onPressed: _goBack,
                  icon: const Icon(LucideIcons.arrowRight),
                  tooltip: 'رجوع',
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تفاصيل الدين',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.burgundyDeep,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'الأقساط والمبالغ المرتبطة بهذا الالتزام',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () =>
                      context.push(AppRouter.createInstallment(widget.debtId)),
                  icon: const Icon(LucideIcons.plus),
                  tooltip: 'إضافة قسط',
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.burgundy,
                    foregroundColor: Colors.white,
                    side: BorderSide.none,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppTheme.burgundy,
              onRefresh: () => provider.loadDebtDetails(widget.debtId),
              child: _DebtDetailsContent(
                provider: provider,
                debtId: widget.debtId,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRouter.home);
  }
}

class _DebtDetailsContent extends StatelessWidget {
  const _DebtDetailsContent({required this.provider, required this.debtId});

  final DebtInstallmentProvider provider;
  final String debtId;

  @override
  Widget build(BuildContext context) {
    if (provider.isLoading && provider.installments.isEmpty) {
      return const _DetailsLoadingState();
    }

    final debt = provider.selectedDebt;
    final currencyLabel = _planCurrencyLabel(context, debt?.weddingPlanId);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 124),
      children: [
        if (provider.errorMessage != null) ...[
          _InlineError(message: provider.errorMessage!),
          const SizedBox(height: 14),
        ],
        if (debt == null)
          const _MissingDebtContextCard()
        else
          _DebtOverviewCard(debt: debt, currencyLabel: currencyLabel),
        const SizedBox(height: 20),
        AarastSectionHeader(
          title: 'الأقساط',
          icon: LucideIcons.wallet,
          actionLabel: 'إضافة',
          onAction: () => context.push(AppRouter.createInstallment(debtId)),
        ),
        const SizedBox(height: 12),
        if (provider.installments.isEmpty)
          AarastEmptyState(
            title: 'لا توجد أقساط لهذا الدين',
            message: 'أضف أول قسط لتتضح مواعيد السداد والمتابعة.',
            icon: LucideIcons.calendarDays,
            action: ElevatedButton.icon(
              onPressed: () =>
                  context.push(AppRouter.createInstallment(debtId)),
              icon: const Icon(LucideIcons.plus),
              label: const Text('إضافة قسط'),
            ),
          )
        else
          for (final installment in provider.installments) ...[
            _InstallmentDetailCard(
              installment: installment,
              currencyLabel: currencyLabel,
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _DebtOverviewCard extends StatelessWidget {
  const _DebtOverviewCard({required this.debt, required this.currencyLabel});

  final Debt debt;
  final String currencyLabel;

  @override
  Widget build(BuildContext context) {
    final color = _debtStatusColor(debt.status);
    final total = _moneyValue(debt.totalAmount);
    final paid = _moneyValue(debt.paidAmount);
    final remaining = _moneyValue(debt.remainingAmount);
    final progress = total <= 0 ? 0.0 : paid / total;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.heroDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: Colors.white.withAlpha(36)),
                ),
                child: const Icon(
                  LucideIcons.receipt,
                  color: AppTheme.gold,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      debt.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      debt.creditorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withAlpha(205),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (debt.creditorPhone?.trim().isNotEmpty == true)
                      Text(
                        PhoneNumberUtils.display(debt.creditorPhone) ??
                            debt.creditorPhone!.trim(),
                        textDirection: TextDirection.ltr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withAlpha(190),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              AarastStatusPill(
                label: _debtStatusLabel(debt.status),
                color: Colors.white,
                backgroundColor: color.withAlpha(100),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppTheme.border,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.gold),
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth < 330
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _HeroAmount(
                    width: width,
                    label: 'الإجمالي',
                    value: total,
                    currencyLabel: currencyLabel,
                  ),
                  _HeroAmount(
                    width: width,
                    label: 'المدفوع',
                    value: paid,
                    currencyLabel: currencyLabel,
                  ),
                  _HeroAmount(
                    width: width,
                    label: 'المتبقي',
                    value: remaining,
                    currencyLabel: currencyLabel,
                  ),
                  _HeroLabel(
                    width: width,
                    label: 'الاستحقاق',
                    value: debt.dueDate == null
                        ? 'غير محدد'
                        : _shortDate(debt.dueDate!),
                    icon: LucideIcons.calendarDays,
                  ),
                ],
              );
            },
          ),
          if (debt.hasNote) ...[
            const SizedBox(height: 14),
            Text(
              debt.note!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.6),
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroAmount extends StatelessWidget {
  const _HeroAmount({
    required this.width,
    required this.label,
    required this.value,
    required this.currencyLabel,
  });

  final double width;
  final String label;
  final num value;
  final String currencyLabel;

  @override
  Widget build(BuildContext context) {
    return _HeroLabel(
      width: width,
      label: label,
      value: '${_formatMoney(value)} $currencyLabel',
      icon: LucideIcons.wallet,
    );
  }
}

class _HeroLabel extends StatelessWidget {
  const _HeroLabel({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
  });

  final double width;
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: Colors.white.withAlpha(30)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.gold, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white.withAlpha(190),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                value,
                textDirection: TextDirection.ltr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InstallmentDetailCard extends StatelessWidget {
  const _InstallmentDetailCard({
    required this.installment,
    required this.currencyLabel,
  });

  final Installment installment;
  final String currencyLabel;

  @override
  Widget build(BuildContext context) {
    final color = _installmentStatusColor(installment.status);

    return AarastCard(
      padding: const EdgeInsets.all(14),
      border: Border.all(color: color.withValues(alpha: 0.1)),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Icon(LucideIcons.wallet, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_formatMoney(_moneyValue(installment.amount))} $currencyLabel',
                  textDirection: TextDirection.ltr,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 7,
                  runSpacing: 6,
                  children: [
                    AarastStatusPill(
                      label: _installmentStatusLabel(installment.status),
                      color: color,
                    ),
                    if (installment.dueDate != null)
                      AarastStatusPill(
                        label: 'استحقاق ${_shortDate(installment.dueDate!)}',
                        color: AppTheme.gold,
                        icon: LucideIcons.calendarCheck,
                      ),
                    if (installment.paidAt != null)
                      AarastStatusPill(
                        label: 'دفع ${_shortDate(installment.paidAt!)}',
                        color: AppTheme.success,
                        icon: LucideIcons.checkCircle,
                      ),
                  ],
                ),
                if (installment.hasNote) ...[
                  const SizedBox(height: 8),
                  Text(
                    installment.note!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _planCurrencyLabel(BuildContext context, String? weddingPlanId) {
  final plans = context.watch<WeddingPlansProvider?>();
  for (final plan in plans?.plans ?? const []) {
    if (plan.id == weddingPlanId) return currencyLabelAr(plan.currency);
  }
  return currencyLabelAr(null);
}

class _MissingDebtContextCard extends StatelessWidget {
  const _MissingDebtContextCard();

  @override
  Widget build(BuildContext context) {
    return const AarastEmptyState(
      title: 'بيانات الدين غير مكتملة',
      message:
          'يمكن عرض الأقساط هنا، ولرؤية بيانات الدين كاملة افتح الدين من القائمة.',
      icon: LucideIcons.info,
    );
  }
}

class _DetailsLoadingState extends StatelessWidget {
  const _DetailsLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 120),
      children: const [
        _SkeletonBox(height: 236),
        SizedBox(height: 20),
        _SkeletonBox(height: 92),
        SizedBox(height: 10),
        _SkeletonBox(height: 92),
      ],
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

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

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

num _moneyValue(String value) =>
    num.tryParse(value.replaceAll(',', '').trim()) ?? 0;

String _formatMoney(num value) {
  final rounded = value.round();
  final negative = rounded < 0;
  final digits = rounded.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '${negative ? '-' : ''}$buffer';
}

Color _debtStatusColor(String status) {
  return switch (status) {
    'PAID' => AppTheme.success,
    'CANCELLED' => AppTheme.muted,
    'PARTIALLY_PAID' => AppTheme.gold,
    _ => AppTheme.burgundy,
  };
}

String _debtStatusLabel(String status) {
  return switch (status) {
    'PARTIALLY_PAID' => 'مدفوع جزئياً',
    'PAID' => 'مدفوع',
    'CANCELLED' => 'ملغي',
    _ => 'مفتوح',
  };
}

Color _installmentStatusColor(String status) {
  return switch (status) {
    'PAID' => AppTheme.success,
    'OVERDUE' => AppTheme.danger,
    'CANCELLED' => AppTheme.muted,
    _ => AppTheme.gold,
  };
}

String _installmentStatusLabel(String status) {
  return switch (status) {
    'PAID' => 'مدفوع',
    'OVERDUE' => 'متأخر',
    'CANCELLED' => 'ملغي',
    _ => 'قيد الانتظار',
  };
}

String _shortDate(DateTime date) {
  return formatArabicCompactDate(date);
}
