import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

class FinancialPaymentRecordDetailsScreen extends StatefulWidget {
  const FinancialPaymentRecordDetailsScreen({
    required this.weddingPlanId,
    required this.paymentRecordId,
    super.key,
  });

  final String weddingPlanId;
  final String paymentRecordId;

  @override
  State<FinancialPaymentRecordDetailsScreen> createState() =>
      _FinancialPaymentRecordDetailsScreenState();
}

class _FinancialPaymentRecordDetailsScreenState
    extends State<FinancialPaymentRecordDetailsScreen> {
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
    final payment = _findPayment(provider.financialPaymentRecords);
    final commitment = payment == null
        ? null
        : _findCommitment(
            provider.financialCommitments,
            payment.financialCommitmentId,
          );

    return AarastScreenFrame(
      maxWidth: 520,
      child: RefreshIndicator(
        color: AppTheme.burgundy,
        onRefresh: () =>
            context.read<FinanceProvider>().loadFinance(widget.weddingPlanId),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 132),
          children: [
            _Header(title: 'تفاصيل الدفعة', onBack: _goBack),
            const SizedBox(height: 14),
            if (provider.isLoading && payment == null)
              const _Skeleton(height: 210)
            else if (payment == null)
              const AarastEmptyState(
                title: 'الدفعة غير موجودة',
                message: 'ربما تم حذفها أو لم يتم تحميل البيانات بعد.',
                icon: Icons.payments_outlined,
              )
            else ...[
              _PaymentHero(payment: payment),
              const SizedBox(height: 14),
              _ContextCard(payment: payment, commitment: commitment),
              const SizedBox(height: 14),
              if (commitment != null)
                OutlinedButton.icon(
                  onPressed: () => context.push(
                    AppRouter.financialCommitmentDetails(
                      widget.weddingPlanId,
                      commitment.id,
                    ),
                  ),
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  label: const Text('فتح المستحق المرتبط'),
                ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: provider.isSubmitting
                    ? null
                    : () => _confirmDelete(provider, payment),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.danger,
                ),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('حذف الدفعة'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  FinancialPaymentRecord? _findPayment(List<FinancialPaymentRecord> payments) {
    for (final payment in payments) {
      if (payment.id == widget.paymentRecordId) return payment;
    }
    return null;
  }

  FinancialCommitment? _findCommitment(
    List<FinancialCommitment> commitments,
    String id,
  ) {
    for (final commitment in commitments) {
      if (commitment.id == id) return commitment;
    }
    return null;
  }

  Future<void> _confirmDelete(
    FinanceProvider provider,
    FinancialPaymentRecord payment,
  ) async {
    if (await AuthActionGuard.blockCloudSubmitForNonLocalPlanning(
      context,
      weddingPlanId: widget.weddingPlanId,
    )) {
      return;
    }
    if (!mounted) return;

    final confirmed = await showModalBottomSheet<bool>(
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
                    Icons.delete_outline_rounded,
                    color: AppTheme.danger,
                    size: 42,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'حذف الدفعة؟',
                    style: Theme.of(sheetContext).textTheme.titleLarge
                        ?.copyWith(
                          color: AppTheme.ink,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'سيتم إنقاص هذه الدفعة من المدفوع في المستحق المرتبط.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
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
                          icon: const Icon(Icons.delete_outline_rounded),
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

    final ok = await provider.deleteFinancialPaymentRecord(
      weddingPlanId: widget.weddingPlanId,
      payment: payment,
    );
    if (!mounted) return;
    if (ok) {
      AarastToast.showSuccess(context, 'تم حذف الدفعة');
      _goBack(changed: true);
    } else {
      AarastToast.showError(
        context,
        provider.errorMessage ?? 'تعذر حذف الدفعة.',
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

class _PaymentHero extends StatelessWidget {
  const _PaymentHero({required this.payment});

  final FinancialPaymentRecord payment;

  @override
  Widget build(BuildContext context) {
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
                  Icons.payments_outlined,
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
                      payment.title.trim().isEmpty
                          ? 'دفعة مالية'
                          : payment.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formatArabicCompactDate(payment.paidAt),
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
          const SizedBox(height: 20),
          YemeniMoneyText(
            _moneyValue(payment.amount),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContextCard extends StatelessWidget {
  const _ContextCard({required this.payment, required this.commitment});

  final FinancialPaymentRecord payment;
  final FinancialCommitment? commitment;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _InfoRow(label: 'المستحق', value: commitment?.title),
          _InfoRow(label: 'طريقة الدفع', value: payment.method),
          _InfoRow(label: 'ملاحظة', value: payment.note, last: true),
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

num _moneyValue(String value) =>
    num.tryParse(value.replaceAll(',', '').trim()) ?? 0;
