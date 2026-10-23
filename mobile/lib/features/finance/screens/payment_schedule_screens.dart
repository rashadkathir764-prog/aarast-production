import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/forms/aarast_form_success.dart';
import '../../../core/forms/aarast_form_draft_binding.dart';
import '../../../core/forms/aarast_form_draft_store.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/wedding_cost.dart';
import '../providers/finance_provider.dart';
import '../widgets/money_input_formatter.dart';
import '../widgets/money_widgets.dart';
import '../widgets/payment_entry_form.dart';
import 'cost_payment_screens.dart' show paymentEntryFrame, paymentRefusal;

class PaymentSchedulesScreen extends StatefulWidget {
  const PaymentSchedulesScreen({
    required this.weddingPlanId,
    this.costId,
    super.key,
  });

  final String weddingPlanId;
  final String? costId;

  @override
  State<PaymentSchedulesScreen> createState() => _PaymentSchedulesScreenState();
}

class _PaymentSchedulesScreenState extends State<PaymentSchedulesScreen> {
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
    if (mounted && provider.canViewMoney && widget.costId != null) {
      await provider.loadCostDetails(widget.costId!);
    }
    if (mounted) setState(() => _isLoadingDetails = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final cost = widget.costId == null
        ? null
        : provider.costById(widget.costId!);
    final schedules = widget.costId == null
        ? provider.dueSchedules
        : provider.schedulesForCost(widget.costId!);
    final scheduleGroups = aarastTemporalGroups(
      schedules,
      (schedule) => aarastDeadlineSection(
        dueDate: schedule.dueDate,
        completed: schedule.isPaid || schedule.isCancelled,
      ),
    );

    return MoneySubpageScaffold(
      title: 'مواعيد الدفع',
      subtitle: cost?.title ?? 'المواعيد القادمة والمتأخرة في خطتك.',
      showBack: true,
      onBack: () => context.pop(),
      actions: [
        if (cost != null &&
            provider.canManageMoney &&
            !cost.isCancelled &&
            moneyValue(cost.remainingAmount) > 0)
          IconButton(
            onPressed: () => _createSchedule(cost),
            icon: const Icon(LucideIcons.calendarPlus),
            tooltip: 'إضافة موعد',
          ),
      ],
      child: RefreshIndicator(
        color: AppTheme.brand,
        onRefresh: () => _load(refreshMoney: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            if (provider.errorMessage != null && schedules.isNotEmpty) ...[
              MoneyMessageBanner(message: provider.errorMessage!, error: true),
              const SizedBox(height: 12),
            ],
            if (_isLoadingDetails && schedules.isEmpty)
              const AarastScreenLoading(label: 'جاري تحميل المواعيد')
            else if (provider.errorMessage != null && schedules.isEmpty)
              AarastErrorState(
                title: 'تعذر تحميل مواعيد الدفع',
                message: provider.errorMessage!,
                onRetry: () => _load(refreshMoney: true),
              )
            else if (widget.costId != null && cost == null)
              const AarastEmptyState(
                icon: LucideIcons.receipt,
                title: 'التكلفة غير موجودة',
                message: 'لا يمكن عرض مواعيد تكلفة غير موجودة.',
              )
            else if (schedules.isEmpty)
              AarastEmptyState(
                icon: LucideIcons.calendarClock,
                title: 'لا توجد مواعيد دفع',
                message: 'أضف موعدًا فقط عندما تعرف مبلغ الجزء وموعده.',
                action:
                    provider.canManageMoney &&
                        cost != null &&
                        !cost.isCancelled &&
                        moneyValue(cost.remainingAmount) > 0
                    ? OutlinedButton.icon(
                        onPressed: () => _createSchedule(cost),
                        icon: const Icon(LucideIcons.calendarPlus),
                        label: const Text('إضافة موعد'),
                      )
                    : null,
              )
            else ...[
              _ScheduleCounts(schedules: schedules),
              const SizedBox(height: 14),
              for (final group in scheduleGroups.entries) ...[
                AarastSectionHeader(
                  title:
                      '${_scheduleSectionTitle(group.key)} · ${group.value.length}',
                  icon: _scheduleSectionIcon(group.key),
                ),
                const SizedBox(height: 10),
                for (final schedule in group.value) ...[
                  _scheduleCard(provider, schedule, cost?.title),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 4),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _createSchedule(WeddingCost cost) async {
    final changed = await context.push<bool>(
      AppRouter.moneyScheduleCreate(widget.weddingPlanId, cost.id),
      extra: cost,
    );
    if (changed == true && mounted) await _load(refreshMoney: true);
  }

  Future<void> _openSchedule(PaymentSchedule schedule) async {
    final costId = schedule.costId;
    final changed = await context.push<bool>(
      AppRouter.moneyScheduleDetails(widget.weddingPlanId, costId, schedule.id),
      extra: schedule,
    );
    if (changed == true && mounted) await _load(refreshMoney: true);
  }

  WeddingCost? _payableCost(
    FinanceProvider provider,
    PaymentSchedule schedule,
  ) {
    final cost = provider.costById(schedule.costId);
    return provider.canManageMoney &&
            schedule.isPending &&
            cost != null &&
            !cost.isCancelled
        ? cost
        : null;
  }

  Widget _scheduleCard(
    FinanceProvider provider,
    PaymentSchedule schedule,
    String? costTitle,
  ) {
    final payable = _payableCost(provider, schedule);
    return ScheduleCard(
      schedule: schedule,
      currency: provider.summary.currency,
      costTitle: costTitle,
      onTap: () => _openSchedule(schedule),
      onPay: payable == null ? null : () => _pay(schedule, payable),
    );
  }

  Future<void> _pay(PaymentSchedule schedule, WeddingCost cost) async {
    final changed = await context.push<bool>(
      AppRouter.moneySchedulePay(widget.weddingPlanId, cost.id, schedule.id),
      extra: schedule,
    );
    if (changed == true && mounted) await _load(refreshMoney: true);
  }
}

String _scheduleSectionTitle(AarastTemporalSection section) {
  return section.label;
}

IconData _scheduleSectionIcon(AarastTemporalSection section) {
  return switch (section) {
    AarastTemporalSection.now => LucideIcons.alertTriangle,
    AarastTemporalSection.today => LucideIcons.sun,
    AarastTemporalSection.week => LucideIcons.calendarDays,
    AarastTemporalSection.later => LucideIcons.calendarClock,
    AarastTemporalSection.completed => LucideIcons.checkCircle,
  };
}

class PaymentScheduleDetailsScreen extends StatefulWidget {
  const PaymentScheduleDetailsScreen({
    required this.weddingPlanId,
    required this.costId,
    required this.scheduleId,
    super.key,
  });

  final String weddingPlanId;
  final String costId;
  final String scheduleId;

  @override
  State<PaymentScheduleDetailsScreen> createState() =>
      _PaymentScheduleDetailsScreenState();
}

class _PaymentScheduleDetailsScreenState
    extends State<PaymentScheduleDetailsScreen> {
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
    if (mounted && provider.canViewMoney) {
      await provider.loadCostDetails(widget.costId);
    }
    if (mounted) setState(() => _isLoadingDetails = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final cost = provider.costById(widget.costId);
    final schedule = provider.scheduleById(widget.scheduleId);
    final payment = schedule == null
        ? null
        : _paymentForSchedule(provider, schedule.id);

    return MoneySubpageScaffold(
      title: 'تفاصيل موعد الدفع',
      subtitle: cost?.title ?? schedule?.costTitle ?? 'موعد مرتبط بتكلفة.',
      showBack: true,
      onBack: () => context.pop(),
      child: RefreshIndicator(
        color: AppTheme.brand,
        onRefresh: () => _load(refreshMoney: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            if (provider.errorMessage != null && schedule != null) ...[
              MoneyMessageBanner(message: provider.errorMessage!, error: true),
              const SizedBox(height: 12),
            ],
            if (_isLoadingDetails && schedule == null)
              const AarastScreenLoading(label: 'جاري تحميل موعد الدفع')
            else if (provider.errorMessage != null && schedule == null)
              AarastErrorState(
                title: 'تعذر تحميل موعد الدفع',
                message: provider.errorMessage!,
                onRetry: () => _load(refreshMoney: true),
              )
            else if (schedule == null)
              const AarastEmptyState(
                icon: LucideIcons.calendarX,
                title: 'الموعد غير موجود',
                message: 'ربما حُذف أو لا ينتمي إلى التكلفة الحالية.',
              )
            else ...[
              _ScheduleHero(
                schedule: schedule,
                currency: provider.summary.currency,
              ),
              const SizedBox(height: 14),
              if (schedule.note != null)
                AarastCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AarastSectionHeader(
                        title: 'ملاحظة الموعد',
                        icon: LucideIcons.fileText,
                      ),
                      const SizedBox(height: 10),
                      Text(schedule.note!),
                    ],
                  ),
                ),
              if (schedule.note != null) const SizedBox(height: 14),
              if (schedule.isOverdue && schedule.isPending)
                const MoneyMessageBanner(
                  message:
                      'هذا الموعد متأخر. سجّل الدفع إذا تم، أو عدّل التاريخ ليعكس الاتفاق الحالي.',
                  error: true,
                ),
              if (schedule.isOverdue && schedule.isPending)
                const SizedBox(height: 14),
              if (schedule.isPaid && payment != null)
                OutlinedButton.icon(
                  onPressed: () => context.push(
                    AppRouter.moneyPaymentDetails(
                      widget.weddingPlanId,
                      payment.id,
                      costId: widget.costId,
                    ),
                  ),
                  icon: const Icon(LucideIcons.banknote),
                  label: const Text('فتح الدفعة المسجلة'),
                ),
              if (schedule.isPaid && payment != null)
                const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: cost == null
                    ? null
                    : () => context.push(
                        AppRouter.moneyCostDetails(
                          widget.weddingPlanId,
                          widget.costId,
                        ),
                      ),
                icon: const Icon(LucideIcons.receipt),
                label: const Text('فتح التكلفة المرتبطة'),
              ),
              if (provider.canManageMoney &&
                  cost != null &&
                  schedule.isPending &&
                  !cost.isCancelled) ...[
                const SizedBox(height: 14),
                _ScheduleActions(
                  submitting: provider.isSubmitting,
                  onPay: () => _pay(schedule, cost),
                  onEdit: () => _edit(schedule, cost),
                  onCancel: () => _cancel(schedule, cost),
                  onDelete: () => _delete(schedule, cost),
                ),
              ] else ...[
                const SizedBox(height: 14),
                MoneyMessageBanner(message: _statusMessage(provider, schedule)),
              ],
            ],
          ],
        ),
      ),
    );
  }

  CostPayment? _paymentForSchedule(
    FinanceProvider provider,
    String scheduleId,
  ) {
    for (final payment in provider.paymentsForCost(widget.costId)) {
      if (payment.paymentScheduleId == scheduleId && !payment.isReversal) {
        return payment;
      }
    }
    return null;
  }

  String _statusMessage(FinanceProvider provider, PaymentSchedule schedule) {
    if (!provider.canManageMoney) return 'هذا الموعد متاح للعرض فقط.';
    if (schedule.isPaid) return 'تم دفع هذا الموعد، وسجله محفوظ.';
    if (schedule.isCancelled) return 'هذا الموعد ملغي، وسجله محفوظ.';
    return 'لا تتوفر إجراءات لهذا الموعد حاليًا.';
  }

  Future<void> _pay(PaymentSchedule schedule, WeddingCost cost) async {
    final changed = await context.push<bool>(
      AppRouter.moneySchedulePay(
        widget.weddingPlanId,
        widget.costId,
        schedule.id,
      ),
      extra: schedule,
    );
    if (changed == true && mounted) await _load(refreshMoney: true);
  }

  Future<void> _edit(PaymentSchedule schedule, WeddingCost cost) async {
    final changed = await context.push<bool>(
      AppRouter.moneyScheduleEdit(
        widget.weddingPlanId,
        widget.costId,
        schedule.id,
      ),
      extra: schedule,
    );
    if (changed == true && mounted) await _load(refreshMoney: true);
  }

  Future<void> _cancel(PaymentSchedule schedule, WeddingCost cost) async {
    final confirmed = await _confirm(
      title: 'إلغاء موعد الدفع؟',
      message:
          'سيبقى الموعد في السجل بحالة ملغي، ولن يحجز مبلغًا من غير المدفوع.',
      action: 'إلغاء الموعد',
      danger: false,
    );
    if (confirmed != true || !mounted) return;
    final ok = await context.read<FinanceProvider>().cancelSchedule(
      schedule: schedule,
      cost: cost,
    );
    if (ok && mounted) {
      AarastToast.showSuccess(
        context,
        context.read<FinanceProvider>().savedMessage('تم إلغاء موعد الدفع.'),
      );
      await _load(refreshMoney: true);
    }
  }

  Future<void> _delete(PaymentSchedule schedule, WeddingCost cost) async {
    final confirmed = await _confirm(
      title: 'حذف موعد الدفع؟',
      message:
          'استخدم الحذف إذا أُضيف الموعد بالخطأ. لن يبقى له سجل بعد الحذف.',
      action: 'حذف نهائي',
      danger: true,
    );
    if (confirmed != true || !mounted) return;
    final ok = await context.read<FinanceProvider>().deleteSchedule(
      schedule: schedule,
      cost: cost,
    );
    if (!mounted || !ok) return;
    AarastToast.showSuccess(
      context,
      context.read<FinanceProvider>().savedMessage('تم حذف موعد الدفع.'),
    );
    context.pop(true);
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String action,
    required bool danger,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AarastDialog(
        icon: Icon(
          danger ? LucideIcons.alertTriangle : LucideIcons.calendarX,
          color: danger ? AppTheme.danger : AppTheme.warning,
        ),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('رجوع'),
          ),
          AarastButton(
            label: action,
            expand: false,
            variant: danger
                ? AarastButtonVariant.danger
                : AarastButtonVariant.primary,
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );
  }
}

class PaymentScheduleFormScreen extends StatefulWidget {
  const PaymentScheduleFormScreen({
    required this.weddingPlanId,
    required this.costId,
    this.scheduleId,
    super.key,
  });

  final String weddingPlanId;
  final String costId;
  final String? scheduleId;

  @override
  State<PaymentScheduleFormScreen> createState() =>
      _PaymentScheduleFormScreenState();
}

class _PaymentScheduleFormScreenState extends State<PaymentScheduleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime? _dueDate;
  bool _isLoadingDetails = true;
  String? _initializedScheduleId;
  AarastFormDraftBinding? _draft;

  bool get _editing => widget.scheduleId != null;

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
    if (!mounted) return;
    _initialize(provider.scheduleById(widget.scheduleId ?? ''));
    setState(() => _isLoadingDetails = false);
  }

  void _initialize(PaymentSchedule? schedule) {
    if (schedule == null || _initializedScheduleId == schedule.id) return;
    _initializedScheduleId = schedule.id;
    _amountController.text = formatMoneyInputValue(schedule.amount);
    _noteController.text = schedule.note ?? '';
    _dueDate = schedule.dueDate;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final cost = provider.costById(widget.costId);
    final schedule = provider.scheduleById(widget.scheduleId ?? '');
    _initialize(schedule);
    final available = cost == null ? 0 : moneyValue(cost.remainingAmount);
    final canSubmit =
        cost != null &&
        provider.canManageMoney &&
        !cost.isCancelled &&
        !cost.isPaid &&
        (!_editing || schedule?.isPending == true) &&
        available > 0;

    return MoneySubpageScaffold(
      title: _editing ? 'تعديل موعد الدفع' : 'إضافة موعد دفع',
      subtitle: cost?.title ?? 'حدد المبلغ والموعد فقط.',
      showBack: true,
      onBack: () => context.pop(),
      bottomNavigationBar: canSubmit
          ? AarastV3FormActionBar(
              label: _editing ? 'حفظ التعديل' : 'إضافة الموعد',
              icon: LucideIcons.check,
              loading: provider.isSubmitting,
              onPressed: () => _submit(cost, schedule),
            )
          : null,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          if (provider.errorMessage != null &&
              cost != null &&
              (!_editing || schedule != null)) ...[
            MoneyMessageBanner(message: provider.errorMessage!, error: true),
            const SizedBox(height: 12),
          ],
          if (_isLoadingDetails && cost == null)
            const AarastScreenLoading(label: 'جاري تجهيز الموعد')
          else if (provider.errorMessage != null &&
              (cost == null || (_editing && schedule == null)))
            AarastErrorState(
              title: 'تعذر تحميل موعد الدفع',
              message: provider.errorMessage!,
              onRetry: _load,
            )
          else if (cost == null || (_editing && schedule == null))
            const AarastEmptyState(
              icon: LucideIcons.calendarX,
              title: 'تعذر فتح الموعد',
              message: 'التكلفة أو الموعد غير موجود.',
            )
          else if (!provider.canManageMoney)
            const MoneyMessageBanner(
              message: 'لا تملك صلاحية إدارة مواعيد الدفع.',
              error: true,
            )
          else if (cost.isCancelled || cost.isPaid)
            const MoneyMessageBanner(
              message: 'لا يمكن إضافة أو تعديل موعد لهذه التكلفة.',
              error: true,
            )
          else if (_editing && !schedule!.isPending)
            const MoneyMessageBanner(
              message: 'يمكن تعديل الموعد المعلّق فقط.',
              error: true,
            )
          else ...[
            AarastV3FocusPrompt(
              question: _editing
                  ? 'ما الموعد الصحيح لهذه الدفعة؟'
                  : 'متى تتوقع دفع المبلغ التالي؟',
              supportingText:
                  'حدد المبلغ والتاريخ فقط، وأضف الملاحظة عند الحاجة.',
              icon: LucideIcons.calendarClock,
            ),
            if (_draft != null) ...[
              const SizedBox(height: 8),
              AarastV3DraftStatusLine(status: _draft!.status),
            ],
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(
                border: Border.symmetric(
                  horizontal: BorderSide(color: AppTheme.border),
                ),
              ),
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
                  const SizedBox(height: 5),
                  MoneyAmountText(
                    amount: available,
                    currency: provider.summary.currency,
                    color: AppTheme.brand,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Form(
              key: _formKey,
              child: MoneySectionCard(
                title: 'بيانات الموعد',
                subtitle: 'المبلغ المتوقع وتاريخ التذكير فقط.',
                icon: LucideIcons.calendarClock,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      key: const Key('payment-schedule-amount'),
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [MoneyInputFormatter()],
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'مبلغ الموعد',
                        prefixIcon: const Icon(LucideIcons.badgeDollarSign),
                        suffixText: currencyLabelAr(provider.summary.currency),
                      ),
                      validator: (value) => _validateAmount(value, available),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      key: const Key('payment-schedule-date'),
                      onPressed: () => _pickDueDate(schedule),
                      icon: const Icon(LucideIcons.calendarDays),
                      label: Text(
                        _dueDate == null
                            ? 'اختر تاريخ الدفع'
                            : 'موعد الدفع: ${formatArabicCompactDate(_dueDate!)}',
                      ),
                    ),
                    if (_dueDate == null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'تاريخ الدفع مطلوب.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.danger,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    MoneyDisclosureCard(
                      title: 'إضافة ملاحظة',
                      subtitle: 'يمكن تخطيه',
                      icon: LucideIcons.fileText,
                      initiallyExpanded: _noteController.text.isNotEmpty,
                      child: TextFormField(
                        controller: _noteController,
                        minLines: 2,
                        maxLines: 3,
                        maxLength: 1000,
                        decoration: const InputDecoration(
                          labelText: 'ملاحظة الموعد',
                          prefixIcon: Icon(LucideIcons.fileText),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
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

  Future<void> _pickDueDate(PaymentSchedule? schedule) async {
    releaseFieldFocus();
    final now = DateTime.now();
    final initial = _dueDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: _editing
          ? DateTime(2020)
          : DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 10),
      locale: const Locale('ar'),
    );
    if (picked != null && mounted) {
      setState(() => _dueDate = picked);
      _draft?.changed();
    }
  }

  Future<void> _submit(WeddingCost cost, PaymentSchedule? schedule) async {
    setState(() {});
    if (!_formKey.currentState!.validate() || _dueDate == null) return;
    final provider = context.read<FinanceProvider>();
    final amount = _amountController.text.replaceAll(',', '').trim();
    final note = _noteController.text.trim();
    final ok = schedule == null
        ? await provider.createSchedule(
                cost: cost,
                amount: amount,
                dueDate: _dueDate!,
                note: note,
              ) !=
              null
        : await provider.updateSchedule(
            schedule: schedule,
            cost: cost,
            amount: amount,
            dueDate: _dueDate!,
            note: note,
          );
    if (ok && mounted) {
      await _draft?.clear();
      if (!mounted) return;
      AarastFormSuccess.show(
        context,
        message: context.read<FinanceProvider>().savedMessage(
          schedule == null ? 'تمت إضافة موعد الدفع.' : 'تم حفظ موعد الدفع.',
        ),
      );
      context.pop(true);
    }
  }

  void _configureDraft() {
    if (_draft != null) return;
    final scheduleId = widget.scheduleId ?? 'new';
    _draft = AarastFormDraftBinding(
      store: context.read<AarastFormDraftStore?>(),
      scope:
          'payment-schedule:${widget.weddingPlanId}:${widget.costId}:$scheduleId',
      fields: {'amount': _amountController, 'note': _noteController},
      readExtras: () => {'dueDate': _dueDate?.toIso8601String()},
      restoreExtras: (data) {
        if (!mounted) return;
        final restored = DateTime.tryParse(data['dueDate']?.toString() ?? '');
        if (restored != null) setState(() => _dueDate = restored);
      },
      onStatusChanged: () {
        if (mounted) setState(() {});
      },
    );
    unawaited(_draft!.restore());
  }
}

class PayPaymentScheduleScreen extends StatefulWidget {
  const PayPaymentScheduleScreen({
    required this.weddingPlanId,
    required this.costId,
    required this.scheduleId,
    super.key,
  });

  final String weddingPlanId;
  final String costId;
  final String scheduleId;

  @override
  State<PayPaymentScheduleScreen> createState() =>
      _PayPaymentScheduleScreenState();
}

class _PayPaymentScheduleScreenState extends State<PayPaymentScheduleScreen> {
  bool _isLoadingDetails = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
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
    final schedule = provider.scheduleById(widget.scheduleId);
    final currency = provider.summary.currency;

    final Widget body;
    if (_isLoadingDetails && schedule == null) {
      body = const JourneyListState(
        phase: JourneyListPhase.loading,
        section: JourneySection.money,
      );
    } else if (provider.errorMessage != null && schedule == null) {
      body = JourneyListState(
        phase: JourneyListPhase.error,
        section: JourneySection.money,
        onRetry: _load,
      );
    } else if (cost == null || schedule == null) {
      body = JourneyListState(
        phase: JourneyListPhase.empty,
        section: JourneySection.money,
        emptyIcon: LucideIcons.calendarX,
        emptyTitle: 'هذا الموعد ما عاد موجود',
        emptyAction: 'ارجع',
        onEmptyAction: () => context.pop(),
      );
    } else if (paymentRefusal(provider, cost) case final refusal?) {
      body = JourneyNote(text: refusal, icon: LucideIcons.info);
    } else if (!schedule.isPending) {
      body = const JourneyNote(
        text: 'هذا الموعد ما ينتظر دفع.',
        icon: LucideIcons.info,
      );
    } else {
      return paymentEntryFrame(
        context,
        cost: cost,
        currency: currency,
        child: PaymentEntryForm(
          cost: cost,
          currency: currency,
          draftScope:
              'pay-schedule:${widget.weddingPlanId}:${widget.costId}:${widget.scheduleId}',
          fixedAmount: schedule.amount,
          fixedLine: 'المتفق في موعد ${formatArabicDayMonth(schedule.dueDate)}',
          fixedAction: () => context.push(
            AppRouter.moneyScheduleEdit(
              widget.weddingPlanId,
              cost.id,
              schedule.id,
            ),
          ),
          onSave: (entry) async {
            final finance = context.read<FinanceProvider>();
            final result = await finance.paySchedule(
              schedule: schedule,
              cost: cost,
              paidAt: entry.paidAt,
              method: entry.method,
              note: entry.note,
            );
            if (result != null && context.mounted) {
              AarastFormSuccess.show(
                context,
                message: finance.savedMessage('انحفظت الدفعة'),
              );
            }
            return result;
          },
        ),
      );
    }
    return paymentEntryFrame(
      context,
      cost: cost,
      currency: currency,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [body],
      ),
    );
  }
}

class _ScheduleCounts extends StatelessWidget {
  const _ScheduleCounts({required this.schedules});

  final List<PaymentSchedule> schedules;

  @override
  Widget build(BuildContext context) {
    final pending = schedules.where((item) => item.isPending).length;
    final overdue = schedules
        .where((item) => item.isOverdue && item.isPending)
        .length;
    final paid = schedules.where((item) => item.isPaid).length;
    return AarastCard(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          AarastStatusPill(
            label: '$pending معلّق',
            icon: LucideIcons.clock3,
            color: AppTheme.warning,
          ),
          if (overdue > 0)
            AarastStatusPill(
              label: '$overdue متأخر',
              icon: LucideIcons.alertTriangle,
              color: AppTheme.danger,
            ),
          AarastStatusPill(
            label: '$paid مدفوع',
            icon: LucideIcons.checkCircle,
            color: AppTheme.success,
          ),
        ],
      ),
    );
  }
}

class _ScheduleHero extends StatelessWidget {
  const _ScheduleHero({required this.schedule, required this.currency});

  final PaymentSchedule schedule;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final color = schedule.isPaid
        ? AppTheme.success
        : schedule.isCancelled
        ? AppTheme.textSecondary
        : schedule.isOverdue
        ? AppTheme.danger
        : AppTheme.warning;
    final label = schedule.isPaid
        ? 'مدفوع'
        : schedule.isCancelled
        ? 'ملغي'
        : schedule.isOverdue
        ? 'متأخر'
        : 'قادم';
    return MoneyRecordHero(
      icon: LucideIcons.calendarClock,
      label: 'موعد الدفع',
      amount: schedule.amount,
      currency: currency,
      supportingText: schedule.paidAt == null
          ? formatArabicDate(schedule.dueDate)
          : '${formatArabicDate(schedule.dueDate)} · دُفع في ${formatArabicCompactDate(schedule.paidAt!)}',
      statusLabel: label,
      statusColor: color,
      amountColor: schedule.isOverdue ? AppTheme.danger : AppTheme.textPrimary,
    );
  }
}

class _ScheduleActions extends StatelessWidget {
  const _ScheduleActions({
    required this.submitting,
    required this.onPay,
    required this.onEdit,
    required this.onCancel,
    required this.onDelete,
  });

  final bool submitting;
  final VoidCallback onPay;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return MoneySectionCard(
      title: 'إدارة الموعد',
      subtitle: 'سجّل الدفع أو حدّث الموعد من مكانه.',
      icon: LucideIcons.settings2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AarastButton(
            label: 'تسجيل دفع الموعد',
            icon: LucideIcons.banknote,
            onPressed: submitting ? null : onPay,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: submitting ? null : onEdit,
                icon: const Icon(LucideIcons.pencil),
                label: const Text('تعديل'),
              ),
              OutlinedButton.icon(
                onPressed: submitting ? null : onCancel,
                icon: const Icon(LucideIcons.circleSlash2),
                label: const Text('إلغاء وحفظ السجل'),
              ),
              OutlinedButton.icon(
                onPressed: submitting ? null : onDelete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.danger,
                ),
                icon: const Icon(LucideIcons.trash2),
                label: const Text('حذف نهائي'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
