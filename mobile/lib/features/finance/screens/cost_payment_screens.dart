import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/forms/aarast_form_draft_binding.dart';
import '../../../core/forms/aarast_form_draft_store.dart';
import '../../../core/forms/aarast_form_success.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/amount_words.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../data/finance_local_data_source.dart';
import '../models/wedding_cost.dart';
import '../providers/finance_provider.dart';
import '../widgets/cost_receipts_section.dart';
import '../widgets/money_input_formatter.dart';
import '../widgets/money_widgets.dart';

part 'cost_payment_screens.details.dart';

class RecordCostPaymentScreen extends StatefulWidget {
  const RecordCostPaymentScreen({
    required this.weddingPlanId,
    required this.costId,
    super.key,
  });

  final String weddingPlanId;
  final String costId;

  @override
  State<RecordCostPaymentScreen> createState() =>
      _RecordCostPaymentScreenState();
}

class _RecordCostPaymentScreenState extends State<RecordCostPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _methodController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _paidAt = DateTime.now();
  bool _isLoadingDetails = true;
  AarastFormDraftBinding? _draft;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _load();
      if (mounted) _configureDraft();
    });
  }

  @override
  void dispose() {
    _draft?.dispose();
    _amountController.dispose();
    _methodController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final provider = context.read<FinanceProvider>();
    if (provider.loadedPlanId != widget.weddingPlanId) {
      await provider.loadMoney(widget.weddingPlanId);
    }
    if (mounted && provider.canViewMoney) {
      await provider.loadCostDetails(widget.costId);
    }
    if (mounted) setState(() => _isLoadingDetails = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final cost = provider.costById(widget.costId);
    final currency = provider.summary.currency;
    final available = cost == null ? 0 : moneyValue(cost.remainingAmount);

    return MoneySubpageScaffold(
      title: 'تسجيل دفعة',
      subtitle: cost?.title ?? 'سجّل المبلغ الذي دُفع فعلًا.',
      showBack: true,
      onBack: () => context.pop(),
      bottomNavigationBar:
          cost != null &&
              provider.canManageMoney &&
              !cost.isCancelled &&
              !cost.isPaid &&
              available > 0
          ? AarastV3FormActionBar(
              label: 'حفظ الدفعة',
              icon: LucideIcons.check,
              loading: provider.isSubmitting,
              onPressed: () => _submit(cost),
            )
          : null,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          if (provider.errorMessage != null && cost != null) ...[
            MoneyMessageBanner(message: provider.errorMessage!, error: true),
            const SizedBox(height: 12),
          ],
          if (_isLoadingDetails && cost == null)
            const AarastScreenLoading(label: 'جاري تجهيز الدفعة')
          else if (provider.errorMessage != null && cost == null)
            AarastErrorState(
              title: 'تعذر تحميل التكلفة',
              message: provider.errorMessage!,
              onRetry: _load,
            )
          else if (cost == null)
            const AarastEmptyState(
              icon: LucideIcons.receipt,
              title: 'التكلفة غير موجودة',
              message: 'ارجع إلى قائمة التكاليف واختر تكلفة موجودة.',
            )
          else if (!provider.canManageMoney)
            const MoneyMessageBanner(
              message: 'لا تملك صلاحية تسجيل دفعات في هذه الخطة.',
              error: true,
            )
          else if (cost.isCancelled || cost.isPaid)
            MoneyMessageBanner(
              message: cost.isCancelled
                  ? 'لا يمكن تسجيل دفعة على تكلفة ملغاة.'
                  : 'هذه التكلفة مدفوعة بالكامل.',
              error: true,
            )
          else ...[
            const AarastV3FocusPrompt(
              question: 'كم دفعت فعلًا؟',
              supportingText:
                  'سجّل المبلغ وتاريخه؛ ويمكن إضافة طريقة الدفع والملاحظة عند الحاجة.',
              icon: LucideIcons.banknote,
            ),
            if (_draft != null) ...[
              const SizedBox(height: 8),
              AarastV3DraftStatusLine(status: _draft!.status),
            ],
            const SizedBox(height: 14),
            _PaymentLimitCard(cost: cost, currency: currency),
            const SizedBox(height: 14),
            if (available <= 0)
              const MoneyMessageBanner(
                message: 'لا يوجد مبلغ متبقٍ لتسجيل دفعة جديدة.',
              )
            else
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MoneySectionCard(
                      title: 'قيمة الدفعة',
                      subtitle: 'المبلغ وتاريخ حدوثه فقط.',
                      icon: LucideIcons.banknote,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            key: const Key('cost-payment-amount'),
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [MoneyInputFormatter()],
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'مبلغ الدفعة',
                              prefixIcon: const Icon(LucideIcons.banknote),
                              suffixText: currencyLabelAr(currency),
                            ),
                            validator: (value) =>
                                _validateAmount(value, available),
                          ),
                          const SizedBox(height: AppTheme.space10),
                          _DateButton(
                            label: 'تاريخ الدفع',
                            date: _paidAt,
                            onTap: _pickPaidAt,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.space10),
                    MoneyDisclosureCard(
                      title: 'تفاصيل إضافية',
                      subtitle: 'طريقة الدفع أو ملاحظة قصيرة',
                      icon: LucideIcons.fileText,
                      initiallyExpanded:
                          _methodController.text.trim().isNotEmpty ||
                          _noteController.text.trim().isNotEmpty,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _methodController,
                            maxLength: 80,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'طريقة الدفع',
                              hintText: 'نقداً، تحويل، بطاقة…',
                              prefixIcon: Icon(LucideIcons.walletCards),
                            ),
                          ),
                          const SizedBox(height: AppTheme.space8),
                          TextFormField(
                            controller: _noteController,
                            minLines: 2,
                            maxLines: 3,
                            maxLength: 1000,
                            decoration: const InputDecoration(
                              labelText: 'ملاحظة قصيرة',
                              prefixIcon: Icon(LucideIcons.fileText),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppTheme.space14),
          ],
        ],
      ),
    );
  }

  String? _validateAmount(String? value, num available) {
    final parsed = num.tryParse(value?.replaceAll(',', '').trim() ?? '');
    if (parsed == null || parsed <= 0) return 'أدخل مبلغًا أكبر من صفر.';
    if (parsed > available) {
      return 'المبلغ يتجاوز غير المدفوع على التكلفة.';
    }
    return null;
  }

  Future<void> _pickPaidAt() async {
    releaseFieldFocus();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _paidAt,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year, now.month, now.day),
      locale: const Locale('ar'),
    );
    if (picked != null && mounted) {
      setState(() => _paidAt = picked);
      _draft?.changed();
    }
  }

  Future<void> _submit(WeddingCost cost) async {
    if (!_formKey.currentState!.validate()) return;
    final result = await context.read<FinanceProvider>().recordPayment(
      cost: cost,
      amount: _amountController.text.replaceAll(',', '').trim(),
      paidAt: _paidAt,
      method: _methodController.text.trim(),
      note: _noteController.text.trim(),
    );
    if (result != null && mounted) {
      await _draft?.clear();
      if (!mounted) return;
      AarastFormSuccess.show(
        context,
        message: context.read<FinanceProvider>().savedMessage(
          'تم تسجيل الدفعة.',
        ),
      );
      context.pop(true);
    }
  }

  void _configureDraft() {
    if (_draft != null) return;
    _draft = AarastFormDraftBinding(
      store: context.read<AarastFormDraftStore?>(),
      scope: 'cost-payment:${widget.weddingPlanId}:${widget.costId}:new',
      fields: {
        'amount': _amountController,
        'method': _methodController,
        'note': _noteController,
      },
      readExtras: () => {'paidAt': _paidAt.toIso8601String()},
      restoreExtras: (data) {
        if (!mounted) return;
        final restored = DateTime.tryParse(data['paidAt']?.toString() ?? '');
        if (restored != null) setState(() => _paidAt = restored);
      },
      onStatusChanged: () {
        if (mounted) setState(() {});
      },
    );
    unawaited(_draft!.restore());
  }
}

class _PaymentLimitCard extends StatelessWidget {
  const _PaymentLimitCard({required this.cost, required this.currency});

  final WeddingCost cost;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return MoneySectionCard(
      title: 'التكلفة المرتبطة',
      subtitle: cost.title,
      icon: LucideIcons.receipt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'غير مدفوع على التكلفة',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          MoneyAmountText(
            amount: cost.remainingAmount,
            currency: currency,
            color: AppTheme.success,
          ),
        ],
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(LucideIcons.calendarDays),
      label: Text('$label: ${formatArabicCompactDate(date)}'),
    );
  }
}
