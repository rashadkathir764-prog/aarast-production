import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/utils/auth_action_guard.dart';
import '../models/financial_commitment.dart';
import '../providers/finance_provider.dart';
import '../widgets/yemeni_money_text.dart';

class FinancialCommitmentDetailsScreen extends StatefulWidget {
  const FinancialCommitmentDetailsScreen({
    required this.weddingPlanId,
    required this.commitmentId,
    super.key,
  });

  final String weddingPlanId;
  final String commitmentId;

  @override
  State<FinancialCommitmentDetailsScreen> createState() =>
      _FinancialCommitmentDetailsScreenState();
}

class _FinancialCommitmentDetailsScreenState
    extends State<FinancialCommitmentDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<FinanceProvider>().loadFinance(widget.weddingPlanId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final commitment = _findCommitment(provider.financialCommitments);
    final payments = provider.financialPaymentRecords
        .where(
          (payment) => payment.financialCommitmentId == widget.commitmentId,
        )
        .toList();
    final installments = provider.dueFinancialInstallments
        .where(
          (installment) =>
              installment.financialCommitmentId == widget.commitmentId &&
              !installment.isPaid,
        )
        .toList();

    return AarastScreenFrame(
      maxWidth: 520,
      child: RefreshIndicator(
        color: AppTheme.burgundy,
        onRefresh: () =>
            context.read<FinanceProvider>().loadFinance(widget.weddingPlanId),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 132),
          children: [
            _Header(title: 'تفاصيل المستحق', onBack: _goBack),
            const SizedBox(height: 14),
            if (provider.isLoading && commitment == null)
              const _Skeleton(height: 220)
            else if (commitment == null)
              const AarastEmptyState(
                title: 'المستحق غير موجود',
                message: 'ربما تم حذفه أو لم يتم تحميل البيانات بعد.',
                icon: LucideIcons.wallet,
              )
            else ...[
              _CommitmentHero(
                commitment: commitment,
                currencyCode: provider.moneySummary.currency,
              ),
              const SizedBox(height: 14),
              if (provider.canManageFinancialRecords) ...[
                _PrimaryActions(
                  onRecordPayment: _moneyValue(commitment.remainingAmount) <= 0
                      ? null
                      : () => _openRecordPayment(commitment),
                  onEdit: () => _openEdit(commitment),
                  onDelete: () => _confirmDelete(provider, commitment),
                  busy: provider.isSubmitting,
                ),
                const SizedBox(height: 18),
              ],
              _InfoCard(commitment: commitment),
              const SizedBox(height: 18),
              AarastSectionHeader(
                title: 'سجلات الدفعات',
                icon: LucideIcons.banknote,
              ),
              const SizedBox(height: 10),
              if (payments.isEmpty)
                const _QuietEmpty(message: 'لا توجد دفعات لهذا المستحق بعد.')
              else
                for (final payment in payments) ...[
                  _PaymentTile(
                    payment: payment,
                    currencyCode: provider.moneySummary.currency,
                    onTap: () => context.push(
                      AppRouter.financialPaymentRecordDetails(
                        widget.weddingPlanId,
                        payment.id,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              const SizedBox(height: 8),
              AarastSectionHeader(
                title: 'الأقساط القريبة',
                icon: LucideIcons.calendarCheck,
              ),
              const SizedBox(height: 10),
              if (installments.isEmpty)
                const _QuietEmpty(message: 'لا توجد أقساط قريبة لهذا المستحق.')
              else
                for (final installment in installments) ...[
                  _InstallmentTile(
                    installment: installment,
                    currencyCode: provider.moneySummary.currency,
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          ],
        ),
      ),
    );
  }

  FinancialCommitment? _findCommitment(List<FinancialCommitment> commitments) {
    for (final commitment in commitments) {
      if (commitment.id == widget.commitmentId) return commitment;
    }
    return null;
  }

  Future<void> _openRecordPayment(FinancialCommitment commitment) async {
    final changed = await context.push<bool>(
      AppRouter.recordPayment(widget.weddingPlanId),
      extra: commitment.id,
    );
    if (changed == true && mounted) {
      await context.read<FinanceProvider>().loadFinance(widget.weddingPlanId);
    }
  }

  Future<void> _openEdit(FinancialCommitment commitment) async {
    final changed = await context.push<bool>(
      AppRouter.editFinancialCommitment(widget.weddingPlanId, commitment.id),
      extra: commitment,
    );
    if (changed == true && mounted) {
      await context.read<FinanceProvider>().loadFinance(widget.weddingPlanId);
    }
  }

  Future<void> _confirmDelete(
    FinanceProvider provider,
    FinancialCommitment commitment,
  ) async {
    if (await AuthActionGuard.blockCloudSubmitForNonLocalPlanning(
      context,
      weddingPlanId: widget.weddingPlanId,
    )) {
      return;
    }
    if (!mounted) return;

    final confirmed = await showAarastBottomSheet<bool>(
      context: context,
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _SheetHandle(),
                  const SizedBox(height: 18),
                  const Icon(
                    LucideIcons.trash2,
                    color: AppTheme.danger,
                    size: 42,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'حذف المستحق؟',
                    style: Theme.of(sheetContext).textTheme.titleLarge
                        ?.copyWith(
                          color: AppTheme.ink,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'سيتم حذف "${commitment.title}" وسجلاته المرتبطة إذا سمح الخادم بذلك.',
                    textAlign: TextAlign.center,
                    style: Theme.of(sheetContext).textTheme.bodyMedium
                        ?.copyWith(
                          color: AppTheme.muted,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              Navigator.of(sheetContext).pop(false),
                          child: const Text('إلغاء'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.of(sheetContext).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.danger,
                          ),
                          icon: const Icon(LucideIcons.trash2),
                          label: const Text('حذف'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (confirmed != true || !mounted) return;

    final ok = await provider.deleteFinancialCommitment(
      weddingPlanId: widget.weddingPlanId,
      commitment: commitment,
    );
    if (!mounted) return;
    if (ok) {
      AarastToast.showSuccess(context, 'تم حذف المستحق');
      _goBack(changed: true);
    } else {
      AarastToast.showError(
        context,
        provider.errorMessage ?? 'تعذر حذف المستحق.',
      );
    }
  }

  void _goBack({bool changed = false}) {
    if (context.canPop()) {
      context.pop(changed);
      return;
    }
    context.go(AppRouter.financialPayables(widget.weddingPlanId));
  }
}

class _CommitmentHero extends StatelessWidget {
  const _CommitmentHero({required this.commitment, required this.currencyCode});

  final FinancialCommitment commitment;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final remaining = _moneyValue(commitment.remainingAmount);
    final paid = _moneyValue(commitment.paidAmount);
    final total = _moneyValue(commitment.totalAmount);
    final ratio = total <= 0 ? 0.0 : (paid / total).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(18),
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
                  color: Colors.white.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                child: const Icon(
                  LucideIcons.wallet,
                  color: AppTheme.gold,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      commitment.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _sourceLabel(commitment),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: .75),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: .16),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.gold),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _HeroBox(
                label: 'الباقي',
                value: remaining,
                danger: remaining > 0,
                currencyCode: currencyCode,
              ),
              const SizedBox(width: 10),
              _HeroBox(
                label: 'المدفوع',
                value: paid,
                currencyCode: currencyCode,
              ),
              const SizedBox(width: 10),
              _HeroBox(
                label: 'الإجمالي',
                value: total,
                currencyCode: currencyCode,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroBox extends StatelessWidget {
  const _HeroBox({
    required this.label,
    required this.value,
    required this.currencyCode,
    this.danger = false,
  });

  final String label;
  final num value;
  final String currencyCode;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: .72),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            YemeniMoneyText(
              value,
              currencyCode: currencyCode,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: danger ? AppTheme.gold : Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryActions extends StatelessWidget {
  const _PrimaryActions({
    required this.onRecordPayment,
    required this.onEdit,
    required this.onDelete,
    required this.busy,
  });

  final VoidCallback? onRecordPayment;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _ActionChipButton(
          label: 'تسجيل دفعة',
          icon: LucideIcons.banknote,
          onTap: onRecordPayment,
        ),
        _ActionChipButton(
          label: 'تعديل',
          icon: LucideIcons.pencil,
          onTap: busy ? null : onEdit,
        ),
        _ActionChipButton(
          label: 'حذف',
          icon: LucideIcons.trash2,
          danger: true,
          onTap: busy ? null : onDelete,
        ),
      ],
    );
  }
}

class _ActionChipButton extends StatelessWidget {
  const _ActionChipButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: danger ? AppTheme.danger : AppTheme.burgundy,
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.commitment});

  final FinancialCommitment commitment;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _InfoRow(label: 'الطرف', value: commitment.partyName),
          _InfoRow(label: 'رقم التواصل', value: commitment.partyPhone),
          _InfoRow(
            label: 'تاريخ الاتفاق',
            value: commitment.agreementDate == null
                ? null
                : formatArabicCompactDate(commitment.agreementDate!),
          ),
          _InfoRow(
            label: 'تاريخ الاستحقاق',
            value: commitment.dueDate == null
                ? null
                : formatArabicCompactDate(commitment.dueDate!),
          ),
          _InfoRow(label: 'ملاحظة', value: commitment.note, last: true),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.last = false});

  final String label;
  final String? value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final shown = value?.trim().isNotEmpty == true ? value!.trim() : 'غير محدد';
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 12),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.muted,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              shown,
              textAlign: TextAlign.left,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.payment,
    required this.currencyCode,
    required this.onTap,
  });

  final FinancialPaymentRecord payment;
  final String currencyCode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _TapTile(
      onTap: onTap,
      icon: LucideIcons.banknote,
      color: AppTheme.success,
      title: payment.title.trim().isEmpty ? 'دفعة مالية' : payment.title,
      subtitle: formatArabicCompactDate(payment.paidAt),
      amount: payment.amount,
      currencyCode: currencyCode,
    );
  }
}

class _InstallmentTile extends StatelessWidget {
  const _InstallmentTile({
    required this.installment,
    required this.currencyCode,
  });

  final FinancialInstallment installment;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    return _TapTile(
      onTap: () {},
      icon: LucideIcons.calendarCheck,
      color: AppTheme.gold,
      title: 'قسط قريب',
      subtitle: installment.dueDate == null
          ? 'بدون تاريخ'
          : formatArabicCompactDate(installment.dueDate!),
      amount: installment.amount,
      currencyCode: currencyCode,
      showChevron: false,
    );
  }
}

class _TapTile extends StatelessWidget {
  const _TapTile({
    required this.onTap,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.currencyCode,
    this.showChevron = true,
  });

  final VoidCallback onTap;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String amount;
  final String currencyCode;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: showChevron ? onTap : null,
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
              Icon(icon, color: color),
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
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              YemeniMoneyText(
                _moneyValue(amount),
                currencyCode: currencyCode,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (showChevron) ...[
                const SizedBox(width: 6),
                const Icon(LucideIcons.chevronLeft, color: AppTheme.muted),
              ],
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
          icon: const Icon(LucideIcons.arrowRight),
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

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 5,
        decoration: BoxDecoration(
          color: AppTheme.border,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

String _sourceLabel(FinancialCommitment commitment) {
  if (commitment.isProviderLinked) return 'مورد / تكلفة خدمة';
  if (commitment.isManualPayable) return 'مستحق عليك';
  return 'مستحق مالي';
}

num _moneyValue(String value) =>
    num.tryParse(value.replaceAll(',', '').trim()) ?? 0;
