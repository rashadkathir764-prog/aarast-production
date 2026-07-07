import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/utils/auth_action_guard.dart';
import '../../wedding_plans/providers/wedding_plans_provider.dart';
import '../models/financial_commitment.dart';
import '../providers/finance_provider.dart';

class RecordPaymentScreen extends StatefulWidget {
  const RecordPaymentScreen({
    required this.weddingPlanId,
    this.initialCommitmentId,
    super.key,
  });

  final String weddingPlanId;
  final String? initialCommitmentId;

  @override
  State<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends State<RecordPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _titleController = TextEditingController();
  final _methodController = TextEditingController();
  final _noteController = TextEditingController();

  String? _commitmentId;
  DateTime? _paidAt;

  @override
  void initState() {
    super.initState();
    _commitmentId = widget.initialCommitmentId;
    _paidAt = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<FinanceProvider>().loadFinance(widget.weddingPlanId);
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _methodController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final commitments = provider.financialCommitments
        .where((commitment) => !commitment.isCancelled)
        .toList();
    final currencyLabel = _planCurrencyLabel(context, widget.weddingPlanId);

    return AarastScreenFrame(
      maxWidth: 500,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _goBack,
                    icon: const Icon(LucideIcons.arrowRight),
                    tooltip: 'رجوع',
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'تسجيل دفعة',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.burgundyDeep,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            sliver: SliverToBoxAdapter(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (commitments.isEmpty)
                      _NoCommitmentCard(weddingPlanId: widget.weddingPlanId)
                    else
                      AarastCard(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            DropdownButtonFormField<String>(
                              initialValue: _commitmentValue(commitments),
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'الالتزام المالي',
                                prefixIcon: Icon(Icons.handshake_outlined),
                              ),
                              items: [
                                for (final commitment in commitments)
                                  DropdownMenuItem(
                                    value: commitment.id,
                                    child: Text(
                                      commitment.title,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (value) {
                                setState(() => _commitmentId = value);
                              },
                              validator: (value) =>
                                  value == null ? 'اختر الالتزام' : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _amountController,
                              textAlign: TextAlign.right,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: 'مبلغ الدفعة',
                                suffixText: currencyLabel,
                                prefixIcon: const Icon(LucideIcons.receipt),
                              ),
                              validator: _requiredMoney,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _titleController,
                              textAlign: TextAlign.right,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'عنوان الدفعة',
                                prefixIcon: Icon(LucideIcons.badgeCheck),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _pickPaidAt,
                                    icon: const Icon(
                                      LucideIcons.calendarDays,
                                      size: 17,
                                    ),
                                    label: Text(_dateLabel(_paidAt)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: _methodController,
                                    textAlign: TextAlign.right,
                                    decoration: const InputDecoration(
                                      labelText: 'طريقة الدفع',
                                      prefixIcon: Icon(LucideIcons.wallet),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _noteController,
                              textAlign: TextAlign.right,
                              minLines: 2,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                labelText: 'ملاحظة',
                                prefixIcon: Icon(Icons.note_alt_outlined),
                              ),
                            ),
                            if (provider.errorMessage != null) ...[
                              const SizedBox(height: 14),
                              AarastStatusPill(
                                label: provider.errorMessage!,
                                color: AppTheme.danger,
                                icon: LucideIcons.alertCircle,
                              ),
                            ],
                          ],
                        ),
                      ),
                    const SizedBox(height: 18),
                    AarastButton(
                      label: 'حفظ الدفعة',
                      icon: LucideIcons.check,
                      isLoading: provider.isSubmitting,
                      onPressed: commitments.isEmpty ? null : _submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _commitmentValue(List<FinancialCommitment> commitments) {
    final selected = _commitmentId;
    if (selected == null) {
      return commitments.isEmpty ? null : commitments.first.id;
    }
    return commitments.any((commitment) => commitment.id == selected)
        ? selected
        : commitments.first.id;
  }

  Future<void> _pickPaidAt() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _paidAt ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      locale: const Locale('ar'),
    );
    if (picked != null) {
      setState(() => _paidAt = picked);
    }
  }

  Future<void> _submit() async {
    final commitments = context
        .read<FinanceProvider>()
        .financialCommitments
        .where((commitment) => !commitment.isCancelled)
        .toList();
    _commitmentId = _commitmentValue(commitments);
    if (!_formKey.currentState!.validate()) return;
    if (await AuthActionGuard.blockCloudSubmitForNonLocalPlanning(
      context,
      weddingPlanId: widget.weddingPlanId,
    )) {
      return;
    }
    if (!mounted) return;

    final provider = context.read<FinanceProvider>();
    final ok = await provider.createFinancialPaymentRecord(
      weddingPlanId: widget.weddingPlanId,
      commitmentId: _commitmentId!,
      amount: _amountController.text.trim(),
      title: _titleController.text.trim(),
      paidAt: _paidAt,
      method: _methodController.text.trim(),
      note: _noteController.text.trim(),
    );
    if (ok && mounted) _goBack(changed: true);
  }

  void _goBack({bool changed = false}) {
    if (context.canPop()) {
      context.pop(changed);
      return;
    }
    context.go(AppRouter.finance(widget.weddingPlanId));
  }
}

class _NoCommitmentCard extends StatelessWidget {
  const _NoCommitmentCard({required this.weddingPlanId});

  final String weddingPlanId;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.handshake_outlined,
            color: AppTheme.burgundy,
            size: 34,
          ),
          const SizedBox(height: 12),
          Text(
            'أضف التزاماً مالياً أولاً',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.title,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.push(
              AppRouter.createFinancialCommitment(weddingPlanId),
            ),
            icon: const Icon(LucideIcons.plus),
            label: const Text('إضافة التزام'),
          ),
        ],
      ),
    );
  }
}

String _dateLabel(DateTime? value) {
  if (value == null) return 'تاريخ الدفعة';
  return '${value.year}/${value.month.toString().padLeft(2, '0')}/${value.day.toString().padLeft(2, '0')}';
}

String _planCurrencyLabel(BuildContext context, String weddingPlanId) {
  final provider = context.watch<WeddingPlansProvider?>();
  for (final plan in provider?.plans ?? const []) {
    if (plan.id == weddingPlanId) return currencyLabelAr(plan.currency);
  }
  return currencyLabelAr(
    provider?.selectedPlan?.currency ?? provider?.activePlan?.currency,
  );
}

String? _requiredMoney(String? value) {
  final raw = value?.trim() ?? '';
  if (raw.isEmpty) return 'المبلغ مطلوب';
  final parsed = num.tryParse(raw);
  if (parsed == null || parsed <= 0) return 'أدخل مبلغاً صحيحاً';
  return null;
}
