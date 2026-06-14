import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/debt.dart';
import '../models/debt_summary.dart';
import '../models/installment.dart';
import '../providers/debt_installment_provider.dart';

class DebtInstallmentScreen extends StatefulWidget {
  const DebtInstallmentScreen({required this.weddingPlanId, super.key});

  final String weddingPlanId;

  @override
  State<DebtInstallmentScreen> createState() => _DebtInstallmentScreenState();
}

class _DebtInstallmentScreenState extends State<DebtInstallmentScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DebtInstallmentProvider>().loadDebts(widget.weddingPlanId);
    });
  }

  @override
  void didUpdateWidget(covariant DebtInstallmentScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weddingPlanId != widget.weddingPlanId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<DebtInstallmentProvider>().loadDebts(widget.weddingPlanId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DebtInstallmentProvider>();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.dBg,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _goBack,
                          icon: const Icon(Icons.arrow_forward_rounded),
                          tooltip: 'رجوع',
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'الديون والأقساط',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: AppTheme.dMaroonDeep,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                              Text(
                                'تابعي الالتزامات القادمة بوضوح',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: AppTheme.dInkSoft,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: () => context.push(
                            AppRouter.createDebt(widget.weddingPlanId),
                          ),
                          icon: const Icon(Icons.add_rounded),
                          tooltip: 'إضافة دين',
                          style: IconButton.styleFrom(
                            backgroundColor: AppTheme.dMaroon,
                            foregroundColor: Colors.white,
                            side: BorderSide.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      color: AppTheme.dMaroon,
                      onRefresh: () => provider.loadDebts(widget.weddingPlanId),
                      child: _DebtInstallmentContent(
                        provider: provider,
                        weddingPlanId: widget.weddingPlanId,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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

class _DebtInstallmentContent extends StatelessWidget {
  const _DebtInstallmentContent({
    required this.provider,
    required this.weddingPlanId,
  });

  final DebtInstallmentProvider provider;
  final String weddingPlanId;

  @override
  Widget build(BuildContext context) {
    if (provider.isLoading && provider.debts.isEmpty) {
      return const _DebtLoadingState();
    }

    if (provider.errorMessage != null && provider.debts.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 56, 20, 120),
        children: [
          AarastEmptyState(
            title: 'تعذر تحميل الديون',
            message: provider.errorMessage!,
            icon: Icons.error_outline_rounded,
            action: ElevatedButton.icon(
              onPressed: () => provider.loadDebts(weddingPlanId),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 124),
      children: [
        if (provider.errorMessage != null) ...[
          _InlineError(message: provider.errorMessage!),
          const SizedBox(height: 14),
        ],
        _DebtHero(summary: provider.summary),
        const SizedBox(height: 20),
        const AarastSectionHeader(
          title: 'الأقساط المستحقة',
          icon: Icons.event_available_rounded,
        ),
        const SizedBox(height: 12),
        _DueInstallmentsPreview(installments: provider.dueInstallments),
        const SizedBox(height: 20),
        AarastSectionHeader(
          title: 'قائمة الديون',
          icon: Icons.account_balance_wallet_outlined,
          actionLabel: 'إضافة',
          onAction: () => context.push(AppRouter.createDebt(weddingPlanId)),
        ),
        const SizedBox(height: 12),
        if (provider.debts.isEmpty)
          AarastEmptyState(
            title: 'لا توجد ديون بعد',
            message: 'سجلي الالتزامات أو الدفعات المؤجلة لتبقى الصورة واضحة.',
            icon: Icons.receipt_long_outlined,
            action: ElevatedButton.icon(
              onPressed: () =>
                  context.push(AppRouter.createDebt(weddingPlanId)),
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة دين'),
            ),
          )
        else
          for (final debt in provider.debts) ...[
            _DebtCard(
              debt: debt,
              onTap: () {
                provider.selectDebt(debt);
                context.push(AppRouter.debtDetails(debt.id));
              },
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _DebtHero extends StatelessWidget {
  const _DebtHero({required this.summary});

  final DebtSummary summary;

  @override
  Widget build(BuildContext context) {
    final total = _moneyValue(summary.totalDebt);
    final paid = _moneyValue(summary.totalPaid);
    final remaining = _moneyValue(summary.remainingDebt);
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
                  color: Colors.white.withAlpha(28),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: Colors.white.withAlpha(36)),
                ),
                child: const Icon(
                  Icons.payments_outlined,
                  color: AppTheme.dGold,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ملخص الالتزامات',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'المتبقي من إجمالي الديون',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withAlpha(205),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _MoneyText(
                remaining,
                color: Colors.white,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.black.withAlpha(35),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.dGold),
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth < 330
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _HeroDebtMetric(
                    width: itemWidth,
                    label: 'إجمالي الدين',
                    value: total,
                    icon: Icons.account_balance_rounded,
                  ),
                  _HeroDebtMetric(
                    width: itemWidth,
                    label: 'المدفوع',
                    value: paid,
                    icon: Icons.check_circle_outline_rounded,
                  ),
                  _HeroDebtCount(
                    width: itemWidth,
                    label: 'مفتوحة',
                    value: summary.countOpen + summary.countPartiallyPaid,
                    icon: Icons.pending_actions_rounded,
                  ),
                  _HeroDebtCount(
                    width: itemWidth,
                    label: 'مغلقة',
                    value: summary.countPaid + summary.countCancelled,
                    icon: Icons.done_all_rounded,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HeroDebtMetric extends StatelessWidget {
  const _HeroDebtMetric({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
  });

  final double width;
  final String label;
  final num value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _HeroMetricFrame(
      width: width,
      label: label,
      icon: icon,
      child: _MoneyText(
        value,
        color: Colors.white,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _HeroDebtCount extends StatelessWidget {
  const _HeroDebtCount({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
  });

  final double width;
  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _HeroMetricFrame(
      width: width,
      label: label,
      icon: icon,
      child: Text(
        value.toString(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _HeroMetricFrame extends StatelessWidget {
  const _HeroMetricFrame({
    required this.width,
    required this.label,
    required this.icon,
    required this.child,
  });

  final double width;
  final String label;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(22),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: Colors.white.withAlpha(30)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.dGold, size: 18),
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
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}

class _DueInstallmentsPreview extends StatelessWidget {
  const _DueInstallmentsPreview({required this.installments});

  final List<Installment> installments;

  @override
  Widget build(BuildContext context) {
    if (installments.isEmpty) {
      return const AarastEmptyState(
        title: 'لا توجد أقساط مستحقة حالياً',
        message: 'عند وجود قسط قريب سيظهر هنا بشكل واضح.',
        icon: Icons.event_available_rounded,
      );
    }

    return Column(
      children: [
        for (final installment in installments.take(4)) ...[
          _InstallmentCard(installment: installment),
          const SizedBox(height: 10),
        ],
        if (installments.length > 4)
          AarastStatusPill(
            label: '+${installments.length - 4} أقساط أخرى',
            color: AppTheme.dMaroon,
            icon: Icons.more_horiz_rounded,
          ),
      ],
    );
  }
}

class _DebtCard extends StatelessWidget {
  const _DebtCard({required this.debt, required this.onTap});

  final Debt debt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _debtStatusColor(debt.status);
    final remaining = _moneyValue(debt.remainingAmount);
    final total = _moneyValue(debt.totalAmount);
    final progress = total <= 0 ? 0.0 : 1 - (remaining / total);

    return AarastCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      border: Border.all(color: color.withAlpha(38)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Stack(
          children: [
            PositionedDirectional(
              top: 0,
              bottom: 0,
              start: 0,
              child: Container(width: 4, color: color),
            ),
            Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color.withAlpha(20),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMd,
                          ),
                        ),
                        child: Icon(Icons.receipt_long_outlined, color: color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              debt.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: AppTheme.dInk,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              debt.creditorName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppTheme.dInkSoft,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      AarastStatusPill(
                        label: _debtStatusLabel(debt.status),
                        color: color,
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 7,
                      backgroundColor: AppTheme.dLine,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  const SizedBox(height: 11),
                  Row(
                    children: [
                      Expanded(
                        child: _MiniAmount(
                          label: 'المتبقي',
                          value: remaining,
                          color: AppTheme.dMaroonDeep,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MiniAmount(
                          label: 'المدفوع',
                          value: _moneyValue(debt.paidAmount),
                          color: AppTheme.dGreen,
                        ),
                      ),
                      if (debt.dueDate != null) ...[
                        const SizedBox(width: 8),
                        Expanded(child: _MiniDate(date: debt.dueDate!)),
                      ],
                    ],
                  ),
                  if (debt.hasNote) ...[
                    const SizedBox(height: 10),
                    Text(
                      debt.note!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.dInkSoft,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InstallmentCard extends StatelessWidget {
  const _InstallmentCard({required this.installment});

  final Installment installment;

  @override
  Widget build(BuildContext context) {
    final color = _installmentStatusColor(installment.status);
    return AarastCard(
      padding: const EdgeInsets.all(14),
      border: Border.all(color: color.withAlpha(38)),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Icon(Icons.payments_outlined, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MoneyText(
                  _moneyValue(installment.amount),
                  color: AppTheme.dInk,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.dInk,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
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
                        label: _shortDate(installment.dueDate!),
                        color: AppTheme.dGoldDeep,
                        icon: Icons.calendar_month_rounded,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniAmount extends StatelessWidget {
  const _MiniAmount({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final num value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.dBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.dInkSoft,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          _MoneyText(
            value,
            color: color,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniDate extends StatelessWidget {
  const _MiniDate({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.dBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الاستحقاق',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.dInkSoft,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _shortDate(date),
            textDirection: TextDirection.ltr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppTheme.dGoldDeep,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DebtLoadingState extends StatelessWidget {
  const _DebtLoadingState();

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
        _SkeletonBox(height: 132),
        SizedBox(height: 10),
        _SkeletonBox(height: 132),
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
        color: AppTheme.dCard2,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.dLine),
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
        color: AppTheme.danger.withAlpha(18),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.danger.withAlpha(45)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.danger),
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

class _MoneyText extends StatelessWidget {
  const _MoneyText(this.value, {required this.color, this.style});

  final num value;
  final Color color;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(
      '${_formatMoney(value)} ر.ي',
      textDirection: TextDirection.ltr,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style:
          style ??
          Theme.of(context).textTheme.titleSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
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
    'PAID' => AppTheme.dGreen,
    'CANCELLED' => AppTheme.dMuted,
    'PARTIALLY_PAID' => AppTheme.dGoldDeep,
    _ => AppTheme.dMaroon,
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
    'PAID' => AppTheme.dGreen,
    'OVERDUE' => AppTheme.danger,
    'CANCELLED' => AppTheme.dMuted,
    _ => AppTheme.dGoldDeep,
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
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
