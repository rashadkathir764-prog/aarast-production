import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/wedding_cost.dart';
import '../providers/finance_provider.dart';
import '../widgets/money_widgets.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
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

    return AarastPageScaffold(
      title: 'تسجيل دفعة',
      subtitle: cost?.title ?? 'سجّل المبلغ الذي دُفع فعلًا.',
      showBack: true,
      onBack: () => context.pop(),
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
            _PaymentLimitCard(cost: cost, currency: currency),
            const SizedBox(height: 14),
            if (available <= 0)
              const MoneyMessageBanner(
                message: 'لا يوجد مبلغ متبقٍ لتسجيل دفعة جديدة.',
              )
            else
              Form(
                key: _formKey,
                child: AarastCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        key: const Key('cost-payment-amount'),
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'مبلغ الدفعة',
                          prefixIcon: const Icon(LucideIcons.banknote),
                          suffixText: currencyLabelAr(currency),
                        ),
                        validator: (value) => _validateAmount(value, available),
                      ),
                      const SizedBox(height: 14),
                      _DateButton(
                        label: 'تاريخ الدفع',
                        date: _paidAt,
                        onTap: _pickPaidAt,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _methodController,
                        maxLength: 80,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'طريقة الدفع (اختياري)',
                          hintText: 'نقدًا، تحويل، بطاقة…',
                          prefixIcon: Icon(LucideIcons.walletCards),
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: _noteController,
                        minLines: 2,
                        maxLines: 4,
                        maxLength: 1000,
                        decoration: const InputDecoration(
                          labelText: 'ملاحظة (اختياري)',
                          prefixIcon: Icon(LucideIcons.fileText),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 18),
            AarastButton(
              label: 'حفظ الدفعة',
              icon: LucideIcons.check,
              isLoading: provider.isSubmitting,
              onPressed: available <= 0 ? null : () => _submit(cost),
            ),
          ],
        ],
      ),
    );
  }

  String? _validateAmount(String? value, num available) {
    final parsed = num.tryParse(value?.replaceAll(',', '').trim() ?? '');
    if (parsed == null || parsed <= 0) return 'أدخل مبلغًا أكبر من صفر.';
    if (parsed > available) {
      return 'المبلغ يتجاوز الباقي على التكلفة.';
    }
    return null;
  }

  Future<void> _pickPaidAt() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _paidAt,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year, now.month, now.day),
      locale: const Locale('ar'),
    );
    if (picked != null && mounted) setState(() => _paidAt = picked);
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
    if (result != null && mounted) context.pop(true);
  }
}

class CostPaymentDetailsScreen extends StatefulWidget {
  const CostPaymentDetailsScreen({
    required this.weddingPlanId,
    this.costId,
    required this.paymentId,
    super.key,
  });

  final String weddingPlanId;
  final String? costId;
  final String paymentId;

  @override
  State<CostPaymentDetailsScreen> createState() =>
      _CostPaymentDetailsScreenState();
}

class _CostPaymentDetailsScreenState extends State<CostPaymentDetailsScreen> {
  bool _isLoadingDetails = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({bool refreshMoney = false}) async {
    final provider = context.read<FinanceProvider>();
    if (refreshMoney || provider.loadedPlanId != widget.weddingPlanId) {
      await provider.loadMoney(widget.weddingPlanId);
    }
    final costId =
        widget.costId ?? provider.paymentById(widget.paymentId)?.costId;
    if (mounted && provider.canViewMoney && costId != null) {
      await provider.loadCostDetails(costId);
    }
    if (mounted) setState(() => _isLoadingDetails = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final payment = provider.paymentById(widget.paymentId);
    final costId = widget.costId ?? payment?.costId;
    final cost = costId == null ? null : provider.costById(costId);
    final currency = provider.summary.currency;

    return AarastPageScaffold(
      title: 'تفاصيل الدفعة',
      subtitle: cost?.title ?? payment?.costTitle ?? 'سجل مالي محفوظ.',
      showBack: true,
      onBack: () => context.pop(),
      child: RefreshIndicator(
        color: AppTheme.burgundy,
        onRefresh: () => _load(refreshMoney: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            if (provider.errorMessage != null && payment != null) ...[
              MoneyMessageBanner(message: provider.errorMessage!, error: true),
              const SizedBox(height: 12),
            ],
            if (_isLoadingDetails && payment == null)
              const AarastScreenLoading(label: 'جاري تحميل الدفعة')
            else if (provider.errorMessage != null && payment == null)
              AarastErrorState(
                title: 'تعذر تحميل الدفعة',
                message: provider.errorMessage!,
                onRetry: () => _load(refreshMoney: true),
              )
            else if (payment == null)
              const AarastEmptyState(
                icon: LucideIcons.banknote,
                title: 'الدفعة غير موجودة',
                message: 'ربما لا تنتمي هذه الدفعة إلى التكلفة الحالية.',
              )
            else ...[
              _PaymentHero(payment: payment, currency: currency),
              const SizedBox(height: 14),
              _PaymentInformation(payment: payment),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: cost == null
                    ? null
                    : () => context.push(
                        AppRouter.moneyCostDetails(
                          widget.weddingPlanId,
                          cost.id,
                        ),
                      ),
                icon: const Icon(LucideIcons.receipt),
                label: const Text('فتح التكلفة المرتبطة'),
              ),
              const SizedBox(height: 10),
              if (provider.canManageMoney &&
                  cost != null &&
                  payment.reversible &&
                  !payment.isReversal &&
                  !payment.isReversed)
                AarastButton(
                  label: 'عكس الدفعة',
                  icon: LucideIcons.undo2,
                  variant: AarastButtonVariant.danger,
                  isLoading: provider.isSubmitting,
                  onPressed: () => _reverse(payment, cost),
                )
              else
                MoneyMessageBanner(message: _ledgerMessage(provider, payment)),
            ],
          ],
        ),
      ),
    );
  }

  String _ledgerMessage(FinanceProvider provider, CostPayment payment) {
    if (!provider.canManageMoney) {
      return 'يمكنك عرض الدفعة، ولا تملك صلاحية تعديل السجل المالي.';
    }
    if (payment.isReversal) return 'هذا قيد عكس مستقل ومحفوظ للمراجعة.';
    if (payment.isReversed) return 'تم عكس هذه الدفعة وبقي سجلها محفوظًا.';
    return 'هذه الدفعة غير قابلة للعكس من حالتها الحالية.';
  }

  Future<void> _reverse(CostPayment payment, WeddingCost cost) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _ReversalReasonDialog(),
    );
    if (reason == null || !mounted) return;
    final ok = await context.read<FinanceProvider>().reversePayment(
      payment: payment,
      cost: cost,
      reason: reason,
    );
    if (!mounted || !ok) return;
    AarastToast.showSuccess(context, 'تم تسجيل عكس الدفعة مع حفظ السجل.');
    await _load(refreshMoney: true);
  }
}

class _PaymentLimitCard extends StatelessWidget {
  const _PaymentLimitCard({required this.cost, required this.currency});

  final WeddingCost cost;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            cost.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppTheme.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'الباقي على التكلفة',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.muted,
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

class _PaymentHero extends StatelessWidget {
  const _PaymentHero({required this.payment, required this.currency});

  final CostPayment payment;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final color = payment.isReversal ? AppTheme.danger : AppTheme.success;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.heroDecoration(),
      child: Column(
        children: [
          Icon(
            payment.isReversal ? LucideIcons.undo2 : LucideIcons.banknote,
            color: color,
            size: 34,
          ),
          const SizedBox(height: 10),
          Text(
            payment.isReversal ? 'قيد عكس' : 'دفعة مسجلة',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          MoneyAmountText(
            amount: payment.signedAmount,
            currency: currency,
            color: color,
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            formatArabicDate(payment.paidAt),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentInformation extends StatelessWidget {
  const _PaymentInformation({required this.payment});

  final CostPayment payment;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AarastSectionHeader(
            title: 'بيانات الدفعة',
            icon: LucideIcons.listChecks,
          ),
          const SizedBox(height: 10),
          _PaymentInfoLine(
            label: 'الحالة',
            value: payment.isReversal
                ? 'قيد عكس'
                : payment.isReversed
                ? 'تم عكسها'
                : 'مسجلة',
          ),
          if (payment.method != null)
            _PaymentInfoLine(label: 'طريقة الدفع', value: payment.method!),
          if (payment.paymentScheduleId != null)
            const _PaymentInfoLine(label: 'المصدر', value: 'موعد دفع مجدول'),
          if (payment.note != null)
            _PaymentInfoLine(label: 'الملاحظة', value: payment.note!),
        ],
      ),
    );
  }
}

class _PaymentInfoLine extends StatelessWidget {
  const _PaymentInfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 94,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.muted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReversalReasonDialog extends StatefulWidget {
  const _ReversalReasonDialog();

  @override
  State<_ReversalReasonDialog> createState() => _ReversalReasonDialogState();
}

class _ReversalReasonDialogState extends State<_ReversalReasonDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AarastDialog(
      icon: const Icon(LucideIcons.undo2, color: AppTheme.danger),
      title: const Text('عكس الدفعة؟'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'سيُنشأ قيد عكس مستقل، ولن تُحذف الدفعة الأصلية من السجل.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 1000,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'سبب العكس',
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('رجوع'),
        ),
        ElevatedButton(
          onPressed: () {
            final reason = _controller.text.trim();
            if (reason.isEmpty) {
              setState(() => _error = 'اكتب سبب عكس الدفعة.');
              return;
            }
            Navigator.pop(context, reason);
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
          child: const Text('تسجيل العكس'),
        ),
      ],
    );
  }
}
