import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/wedding_cost.dart';
import '../providers/finance_provider.dart';
import '../widgets/money_widgets.dart';

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

    return AarastPageScaffold(
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
        color: AppTheme.burgundy,
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
              for (final schedule in schedules) ...[
                ScheduleCard(
                  schedule: schedule,
                  currency: provider.summary.currency,
                  costTitle: cost?.title,
                  onTap: () => _openSchedule(schedule),
                ),
                const SizedBox(height: 10),
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

    return AarastPageScaffold(
      title: 'تفاصيل موعد الدفع',
      subtitle: cost?.title ?? schedule?.costTitle ?? 'موعد مرتبط بتكلفة.',
      showBack: true,
      onBack: () => context.pop(),
      child: RefreshIndicator(
        color: AppTheme.burgundy,
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
      message: 'سيبقى الموعد في السجل بحالة ملغي، ولن يحجز مبلغًا من الباقي.',
      action: 'إلغاء الموعد',
      danger: false,
    );
    if (confirmed != true || !mounted) return;
    final ok = await context.read<FinanceProvider>().cancelSchedule(
      schedule: schedule,
      cost: cost,
    );
    if (ok && mounted) await _load(refreshMoney: true);
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
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: danger
                ? ElevatedButton.styleFrom(backgroundColor: AppTheme.danger)
                : null,
            child: Text(action),
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

  bool get _editing => widget.scheduleId != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
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
    _amountController.text = schedule.amount;
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

    return AarastPageScaffold(
      title: _editing ? 'تعديل موعد الدفع' : 'إضافة موعد دفع',
      subtitle: cost?.title ?? 'حدد المبلغ والموعد فقط.',
      showBack: true,
      onBack: () => context.pop(),
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
            AarastCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'المتبقي على التكلفة',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  MoneyAmountText(
                    amount: available,
                    currency: provider.summary.currency,
                    color: AppTheme.burgundy,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Form(
              key: _formKey,
              child: AarastCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      key: const Key('payment-schedule-amount'),
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'مبلغ الموعد',
                        prefixIcon: const Icon(LucideIcons.badgeDollarSign),
                        suffixText: currencyLabelAr(provider.summary.currency),
                      ),
                      validator: (value) => _validateAmount(value, available),
                    ),
                    const SizedBox(height: 14),
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
                    const SizedBox(height: 14),
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
              label: _editing ? 'حفظ التعديل' : 'إضافة الموعد',
              icon: LucideIcons.check,
              isLoading: provider.isSubmitting,
              onPressed: available <= 0 ? null : () => _submit(cost, schedule),
            ),
          ],
        ],
      ),
    );
  }

  String? _validateAmount(String? value, num available) {
    final parsed = num.tryParse(value?.replaceAll(',', '').trim() ?? '');
    if (parsed == null || parsed <= 0) return 'أدخل مبلغًا أكبر من صفر.';
    if (parsed > available) return 'المبلغ يتجاوز الباقي على التكلفة.';
    return null;
  }

  Future<void> _pickDueDate(PaymentSchedule? schedule) async {
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
    if (picked != null && mounted) setState(() => _dueDate = picked);
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
    if (ok && mounted) context.pop(true);
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
    final schedule = provider.scheduleById(widget.scheduleId);

    return AarastPageScaffold(
      title: 'دفع الموعد',
      subtitle: cost?.title ?? 'المبلغ ثابت من موعد الدفع.',
      showBack: true,
      onBack: () => context.pop(),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          if (provider.errorMessage != null && schedule != null) ...[
            MoneyMessageBanner(message: provider.errorMessage!, error: true),
            const SizedBox(height: 12),
          ],
          if (_isLoadingDetails && schedule == null)
            const AarastScreenLoading(label: 'جاري تجهيز دفع الموعد')
          else if (provider.errorMessage != null && schedule == null)
            AarastErrorState(
              title: 'تعذر تحميل موعد الدفع',
              message: provider.errorMessage!,
              onRetry: _load,
            )
          else if (cost == null || schedule == null)
            const AarastEmptyState(
              icon: LucideIcons.calendarX,
              title: 'تعذر فتح الموعد',
              message: 'التكلفة أو موعد الدفع غير موجود.',
            )
          else if (!provider.canManageMoney)
            const MoneyMessageBanner(
              message: 'لا تملك صلاحية دفع هذا الموعد.',
              error: true,
            )
          else if (!schedule.isPending || cost.isCancelled)
            const MoneyMessageBanner(
              message: 'لا يمكن دفع هذا الموعد من حالته الحالية.',
              error: true,
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.heroDecoration(),
              child: Column(
                children: [
                  const Icon(
                    LucideIcons.calendarCheck,
                    color: AppTheme.burgundy,
                    size: 34,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'المبلغ المحدد في الموعد',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  MoneyAmountText(
                    amount: schedule.amount,
                    currency: provider.summary.currency,
                    color: AppTheme.burgundy,
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'موعده ${formatArabicCompactDate(schedule.dueDate)}',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const MoneyMessageBanner(
              message:
                  'سيُسجَّل مبلغ الموعد كاملًا. لتغيير المبلغ ارجع وعدّل الموعد قبل الدفع.',
            ),
            const SizedBox(height: 14),
            AarastCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickPaidAt,
                    icon: const Icon(LucideIcons.calendarDays),
                    label: Text(
                      'تاريخ الدفع: ${formatArabicCompactDate(_paidAt)}',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _methodController,
                    maxLength: 80,
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
            const SizedBox(height: 18),
            AarastButton(
              key: const Key('pay-schedule-submit'),
              label: 'تأكيد دفع الموعد',
              icon: LucideIcons.check,
              isLoading: provider.isSubmitting,
              onPressed: () => _submit(schedule, cost),
            ),
          ],
        ],
      ),
    );
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

  Future<void> _submit(PaymentSchedule schedule, WeddingCost cost) async {
    final payment = await context.read<FinanceProvider>().paySchedule(
      schedule: schedule,
      cost: cost,
      paidAt: _paidAt,
      method: _methodController.text.trim(),
      note: _noteController.text.trim(),
    );
    if (payment != null && mounted) context.pop(true);
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
        ? AppTheme.muted
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.heroDecoration(),
      child: Column(
        children: [
          Icon(LucideIcons.calendarClock, color: color, size: 34),
          const SizedBox(height: 10),
          AarastStatusPill(
            label: label,
            color: color,
            icon: schedule.isPaid
                ? LucideIcons.checkCircle
                : schedule.isCancelled
                ? LucideIcons.circleSlash2
                : LucideIcons.clock3,
          ),
          const SizedBox(height: 12),
          MoneyAmountText(
            amount: schedule.amount,
            currency: currency,
            color: color,
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            formatArabicDate(schedule.dueDate),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (schedule.paidAt != null) ...[
            const SizedBox(height: 5),
            Text(
              'دُفع في ${formatArabicCompactDate(schedule.paidAt!)}',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
            ),
          ],
        ],
      ),
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
    return AarastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AarastSectionHeader(
            title: 'إدارة الموعد',
            icon: LucideIcons.settings2,
          ),
          const SizedBox(height: 14),
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
