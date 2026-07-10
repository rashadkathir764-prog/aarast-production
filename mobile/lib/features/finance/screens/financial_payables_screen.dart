import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../sharing/models/shared_member.dart';
import '../models/financial_commitment.dart';
import '../models/money_summary.dart';
import '../providers/finance_provider.dart';
import '../widgets/yemeni_money_text.dart';

class FinancialPayablesScreen extends StatefulWidget {
  const FinancialPayablesScreen({
    required this.weddingPlanId,
    this.sharedMember,
    super.key,
  });

  final String weddingPlanId;
  final SharedMember? sharedMember;

  @override
  State<FinancialPayablesScreen> createState() =>
      _FinancialPayablesScreenState();
}

class _FinancialPayablesScreenState extends State<FinancialPayablesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final commitments = provider.financialCommitments
        .where((commitment) => !commitment.isCancelled)
        .toList();
    final payments = provider.financialPaymentRecords;
    final installments = provider.dueFinancialInstallments
        .where((installment) => !installment.isPaid)
        .toList();

    return AarastScreenFrame(
      maxWidth: 520,
      child: RefreshIndicator(
        color: AppTheme.burgundy,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 132),
          children: [
            _Header(title: 'الدفعات والمستحقات', onBack: _goBack),
            const SizedBox(height: 14),
            _PayablesHero(summary: provider.moneySummary),
            const SizedBox(height: 18),
            AarastSectionHeader(
              title: 'المستحقات',
              icon: Icons.account_balance_wallet_outlined,
              actionLabel: 'إضافة مستحق',
              onAction: _openCreateCommitment,
            ),
            const SizedBox(height: 10),
            if (provider.isLoading && commitments.isEmpty)
              const _Skeleton(height: 160)
            else if (commitments.isEmpty)
              const AarastEmptyState(
                title: 'لا توجد مستحقات بعد',
                message: 'أضف تكلفة متفق عليها أو مستحق عليك ليظهر هنا.',
                icon: Icons.account_balance_wallet_outlined,
              )
            else
              for (final commitment in commitments) ...[
                _CommitmentCard(
                  commitment: commitment,
                  onTap: () => context.push(
                    AppRouter.financialCommitmentDetails(
                      widget.weddingPlanId,
                      commitment.id,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            const SizedBox(height: 12),
            AarastSectionHeader(
              title: 'الأقساط القريبة',
              icon: Icons.event_available_outlined,
            ),
            const SizedBox(height: 10),
            if (installments.isEmpty)
              const _QuietEmpty(message: 'لا توجد أقساط قريبة الآن.')
            else
              for (final installment in installments) ...[
                _InstallmentCard(
                  installment: installment,
                  title: _commitmentTitle(commitments, installment),
                ),
                const SizedBox(height: 10),
              ],
            const SizedBox(height: 12),
            AarastSectionHeader(
              title: 'سجلات الدفعات',
              icon: Icons.payments_outlined,
              actionLabel: payments.isEmpty ? null : 'تسجيل دفعة',
              onAction: payments.isEmpty ? null : _openRecordPayment,
            ),
            const SizedBox(height: 10),
            if (payments.isEmpty)
              const _QuietEmpty(message: 'لم تسجل أي دفعة بعد.')
            else
              for (final payment in payments) ...[
                _PaymentCard(
                  payment: payment,
                  commitmentTitle: _paymentCommitmentTitle(
                    commitments,
                    payment,
                  ),
                  onTap: () => context.push(
                    AppRouter.financialPaymentRecordDetails(
                      widget.weddingPlanId,
                      payment.id,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }

  Future<void> _load() {
    return context.read<FinanceProvider>().loadFinance(
      widget.weddingPlanId,
      canReadBudget:
          widget.sharedMember == null || widget.sharedMember!.canReadBudget,
      canReadExpenses:
          widget.sharedMember == null || widget.sharedMember!.canReadExpenses,
    );
  }

  void _openCreateCommitment() {
    unawaited(
      _pushAndReload(AppRouter.createFinancialCommitment(widget.weddingPlanId)),
    );
  }

  void _openRecordPayment() {
    unawaited(_pushAndReload(AppRouter.recordPayment(widget.weddingPlanId)));
  }

  Future<void> _pushAndReload(String route) async {
    final changed = await context.push<bool>(route);
    if (changed == true && mounted) await _load();
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRouter.finance(widget.weddingPlanId));
  }
}

class _PayablesHero extends StatelessWidget {
  const _PayablesHero({required this.summary});

  final MoneySummary summary;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      padding: const EdgeInsets.all(16),
      color: AppTheme.surface,
      border: Border.all(color: AppTheme.border),
      child: Row(
        children: [
          _HeroMetric(
            label: 'عليك',
            value: summary.outstandingTotal ?? summary.debtRemaining ?? '0',
            color: AppTheme.danger,
          ),
          const SizedBox(width: 10),
          _HeroMetric(
            label: 'دفعت',
            value: summary.paidTotal ?? '0',
            color: AppTheme.success,
          ),
          const SizedBox(width: 10),
          _HeroMetric(
            label: 'مستحقات',
            value: (summary.commitmentsCount ?? 0).toString(),
            color: AppTheme.gold,
            money: false,
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.value,
    required this.color,
    this.money = true,
  });

  final String label;
  final String value;
  final Color color;
  final bool money;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.muted,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            money
                ? YemeniMoneyText(
                    _moneyValue(value),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                : Text(
                    value,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _CommitmentCard extends StatelessWidget {
  const _CommitmentCard({required this.commitment, required this.onTap});

  final FinancialCommitment commitment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final remaining = _moneyValue(commitment.remainingAmount);
    final color = remaining <= 0 ? AppTheme.success : AppTheme.gold;
    return _TapCard(
      onTap: onTap,
      icon: Icons.handshake_outlined,
      color: color,
      title: commitment.title,
      subtitle: _sourceLabel(commitment),
      trailing: YemeniMoneyText(
        _moneyValue(commitment.remainingAmount),
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: remaining <= 0 ? AppTheme.success : AppTheme.danger,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.payment,
    required this.commitmentTitle,
    required this.onTap,
  });

  final FinancialPaymentRecord payment;
  final String commitmentTitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = payment.isReversal ? AppTheme.danger : AppTheme.success;
    return _TapCard(
      onTap: onTap,
      icon: payment.isReversal ? Icons.undo_rounded : Icons.payments_outlined,
      color: color,
      title: payment.title.trim().isEmpty ? 'دفعة مالية' : payment.title,
      subtitle: '$commitmentTitle · ${formatArabicCompactDate(payment.paidAt)}',
      trailing: YemeniMoneyText(
        _moneyValue(payment.signedAmount),
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InstallmentCard extends StatelessWidget {
  const _InstallmentCard({required this.installment, required this.title});

  final FinancialInstallment installment;
  final String title;

  @override
  Widget build(BuildContext context) {
    return _TapCard(
      onTap: () => context.push(
        AppRouter.financialCommitmentDetails(
          installment.weddingPlanId,
          installment.financialCommitmentId,
        ),
      ),
      icon: Icons.event_available_outlined,
      color: AppTheme.gold,
      title: title,
      subtitle: installment.dueDate == null
          ? 'بدون تاريخ'
          : formatArabicCompactDate(installment.dueDate!),
      trailing: YemeniMoneyText(
        _moneyValue(installment.amount),
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: AppTheme.gold,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TapCard extends StatelessWidget {
  const _TapCard({
    required this.onTap,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final VoidCallback onTap;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Icon(icon, color: color),
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
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
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
              const SizedBox(width: 10),
              trailing,
              const SizedBox(width: 6),
              const Icon(Icons.chevron_left_rounded, color: AppTheme.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          tooltip: 'رجوع',
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppTheme.burgundyDeep,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _QuietEmpty extends StatelessWidget {
  const _QuietEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      padding: const EdgeInsets.all(16),
      color: AppTheme.ivory,
      border: Border.all(color: AppTheme.border),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppTheme.muted,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.height});

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

String _commitmentTitle(
  List<FinancialCommitment> commitments,
  FinancialInstallment installment,
) {
  for (final commitment in commitments) {
    if (commitment.id == installment.financialCommitmentId) {
      return commitment.title;
    }
  }
  return 'قسط مالي';
}

String _paymentCommitmentTitle(
  List<FinancialCommitment> commitments,
  FinancialPaymentRecord payment,
) {
  for (final commitment in commitments) {
    if (commitment.id == payment.financialCommitmentId) {
      return commitment.title;
    }
  }
  return 'مستحق مالي';
}

String _sourceLabel(FinancialCommitment commitment) {
  if (commitment.isProviderLinked) return 'مورد / تكلفة خدمة';
  if (commitment.isManualDebt) return 'مستحق عليك';
  return 'مستحق مالي';
}

num _moneyValue(String value) =>
    num.tryParse(value.replaceAll(',', '').trim()) ?? 0;
