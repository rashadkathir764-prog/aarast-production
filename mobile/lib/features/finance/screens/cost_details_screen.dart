import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/phone/phone_number_utils.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/utils/money_formatters.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/wedding_cost.dart';
import '../providers/finance_provider.dart';
import '../data/finance_local_data_source.dart';
import '../widgets/cost_receipts_section.dart';
import '../widgets/money_input_formatter.dart';

part 'cost_details_screen.parts.dart';

class CostDetailsScreen extends StatefulWidget {
  const CostDetailsScreen({
    required this.weddingPlanId,
    required this.costId,
    super.key,
  });

  final String weddingPlanId;
  final String costId;

  @override
  State<CostDetailsScreen> createState() => _CostDetailsScreenState();
}

class _CostDetailsScreenState extends State<CostDetailsScreen> {
  bool _isLoadingDetails = true;
  final _scrollController = ScrollController();
  final _paymentsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load({bool refreshMoney = false}) async {
    if (!mounted) return;
    setState(() => _isLoadingDetails = true);
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
    final currency = provider.summary.currency;
    final canManage = provider.canManageMoney;

    final Widget body;
    if (_isLoadingDetails && cost == null) {
      body = const JourneyListState(
        phase: JourneyListPhase.loading,
        section: JourneySection.money,
      );
    } else if (provider.errorMessage != null && cost == null) {
      body = JourneyListState(
        phase: JourneyListPhase.error,
        section: JourneySection.money,
        onRetry: _load,
      );
    } else if (cost == null) {
      body = JourneyListState(
        phase: JourneyListPhase.empty,
        section: JourneySection.money,
        emptyIcon: LucideIcons.receipt,
        emptyTitle: 'هذا الاتفاق ما عاد موجود',
        emptyAction: 'ارجع للبنود',
        onEmptyAction: _goBack,
      );
    } else {
      body = _details(context, provider, cost, currency, canManage);
    }

    final payAction = cost == null ? null : _payAction(provider, cost);
    return AarastScreenFrame(
      maxWidth: 600,
      backgroundColor: AarastV3Color.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: JourneySubHeader(
              title: cost?.title ?? 'تفاصيل الاتفاق',
              subtitle: cost?.partyLabel,
              onBack: _goBack,
              trailing: cost != null && canManage && !cost.isCancelled
                  ? _CostMoreMenu(
                      canCancel: !cost.hasActivePayments,
                      disabled: provider.isSubmitting,
                      onEdit: () => _editCost(cost),
                      onCancel: () => _confirmCancel(cost),
                    )
                  : null,
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AarastV3Color.primary,
              onRefresh: () => _load(refreshMoney: true),
              child: ListView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [body],
              ),
            ),
          ),
          if (payAction != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: JourneyButton(
                key: const ValueKey('money-cost-primary-action'),
                label: payAction.$1,
                expand: true,
                large: true,
                onPressed: payAction.$2,
              ),
            ),
        ],
      ),
    );
  }

  /// The one main action: pay the next scheduled payment by its name, or
  /// record a payment; none once the agreement is paid or cancelled.
  (String, VoidCallback)? _payAction(
    FinanceProvider provider,
    WeddingCost cost,
  ) {
    if (!provider.canManageMoney ||
        cost.isCancelled ||
        moneyValue(cost.remainingAmount) <= 0) {
      return null;
    }
    final pending =
        provider
            .schedulesForCost(cost.id)
            .where((schedule) => schedule.isPending)
            .toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    if (pending.isEmpty) {
      return ('سجّل دفعة', () => _openRecordPayment(cost));
    }
    final paidCount = provider
        .paymentsForCost(cost.id)
        .where((payment) => !payment.isReversal && !payment.isReversed)
        .length;
    final next = pending.first;
    return (
      'سجّل الدفعة ${_ordinal(paidCount)}',
      () => _paySchedule(cost, next),
    );
  }

  Widget _details(
    BuildContext context,
    FinanceProvider provider,
    WeddingCost cost,
    String currency,
    bool canManage,
  ) {
    final now = DateTime.now();
    final payments =
        provider
            .paymentsForCost(cost.id)
            .where((payment) => !payment.isReversal)
            .toList()
          ..sort((a, b) => a.paidAt.compareTo(b.paidAt));
    final pending =
        provider
            .schedulesForCost(cost.id)
            .where((schedule) => schedule.isPending)
            .toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    var number = 0;
    final entries = <_TimelineEntry>[
      for (final payment in payments)
        _TimelineEntry(
          title: payment.isReversed
              ? 'دفعة انعكست'
              : 'الدفعة ${_ordinal(number++)}',
          line: [
            formatArabicDayMonth(payment.paidAt),
            if ((payment.method ?? '').trim().isNotEmpty)
              payment.method!.trim(),
          ].join(' · '),
          amount: payment.amount,
          state: payment.isReversed ? _EntryState.reversed : _EntryState.done,
          onTap: () => context.push(
            AppRouter.moneyPaymentDetails(
              widget.weddingPlanId,
              payment.id,
              costId: cost.id,
            ),
          ),
        ),
      for (var index = 0; index < pending.length; index++)
        _TimelineEntry(
          title: (pending[index].note ?? '').trim().isNotEmpty
              ? pending[index].note!.trim()
              : 'الدفعة ${_ordinal(number++)}',
          line: _dueLine(pending[index], now),
          amount: pending[index].amount,
          state: index == 0 ? _EntryState.current : _EntryState.later,
          onTap: () => context.push(
            AppRouter.moneyScheduleDetails(
              widget.weddingPlanId,
              cost.id,
              pending[index].id,
            ),
          ),
        ),
    ];
    final canSchedule =
        canManage && !cost.isCancelled && moneyValue(cost.remainingAmount) > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (provider.errorMessage != null) ...[
          JourneyListNotice(offline: false, onRetry: _load),
          const SizedBox(height: 12),
        ],
        _CostAgreementCard(cost: cost, currency: currency),
        // V1 checklist 4.10: a private cost can join the shared plan.
        if (cost.isPrivate) ...[
          const SizedBox(height: 12),
          JourneyNote(
            key: const ValueKey('cost-private-banner'),
            text: 'تكلفة خاصة بك: لا يراها شريكك ولا تدخل في أرقامه.',
            icon: LucideIcons.lock,
          ),
          if (canManage)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: JourneyTextAction(
                key: const ValueKey('cost-share-with-plan'),
                label: 'مشاركتها مع الخطة',
                icon: LucideIcons.users,
                color: AarastV3Color.primary,
                onPressed: () => _shareWithPlan(cost),
              ),
            ),
        ],
        if (!canManage) ...[
          const SizedBox(height: 12),
          const JourneyNote(
            text:
                'هذه التفاصيل للعرض فقط. إجراءات التعديل والدفع متاحة لمدير المال.',
            icon: LucideIcons.eye,
          ),
        ],
        const SizedBox(height: 8),
        KeyedSubtree(
          key: _paymentsKey,
          child: JourneySectionTitle(
            'جدول الدفعات',
            action: canSchedule ? 'أضف موعد' : null,
            onAction: canSchedule ? () => _openScheduleCreate(cost) : null,
          ),
        ),
        if (entries.isEmpty)
          const JourneyListState(
            phase: JourneyListPhase.empty,
            section: JourneySection.money,
            emptyIcon: LucideIcons.calendarPlus,
            emptyTitle: 'ما في دفعات ولا مواعيد بعد',
          )
        else
          _PaymentTimeline(entries: entries, currency: currency),
        // V1 checklist 4.4: receipts live on the server (an account's plan),
        // never in a guest's local plan.
        if (!FinanceLocalDataSource.isLocalGuestPlanId(
          widget.weddingPlanId,
        )) ...[
          const SizedBox(height: 18),
          CostReceiptsSection(
            key: ValueKey('cost-receipts-${cost.id}'),
            costId: cost.id,
            canManage: canManage,
          ),
        ],
        const SizedBox(height: 8),
        const JourneySectionTitle('التفاصيل'),
        _CostFacts(
          cost: cost,
          categoryName:
              provider.categoryById(cost.budgetCategoryId)?.name ??
              cost.categoryName,
        ),
      ],
    );
  }

  String _dueLine(PaymentSchedule schedule, DateTime now) {
    final date = formatArabicDayMonth(schedule.dueDate);
    if (schedule.isOverdueAt(now)) return 'متأخرة · $date';
    final days = DateUtils.dateOnly(
      schedule.dueDate,
    ).difference(DateUtils.dateOnly(now)).inDays;
    if (days <= 0) return 'اليوم · $date';
    if (days == 1) return 'بكرة · $date';
    if (days <= 30) {
      return 'بعد ${arabicCount(days, one: 'يوم', two: 'يومين', few: 'أيام', many: 'يوم')} · $date';
    }
    return date;
  }

  Future<void> _paySchedule(WeddingCost cost, PaymentSchedule schedule) async {
    final changed = await context.push<bool>(
      AppRouter.moneySchedulePay(widget.weddingPlanId, cost.id, schedule.id),
      extra: schedule,
    );
    if (changed == true && mounted) await _load(refreshMoney: true);
  }

  /// Makes a private cost the shared plan's (it cannot become private again).
  Future<void> _shareWithPlan(WeddingCost cost) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AarastDialog(
        title: const Text('مشاركة التكلفة مع الخطة؟'),
        content: const Text(
          'سيراها شريكك وتدخل في أرقام الخطة. لا يمكن إرجاعها خاصة بعد ذلك.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('مشاركة'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final provider = context.read<FinanceProvider>();
    final ok = await provider.updateCost(
      cost: cost,
      budgetCategoryId: cost.budgetCategoryId,
      title: cost.title,
      totalAmount: cost.totalAmount,
      providerId: cost.providerId,
      quoteOfferId: cost.quoteOfferId,
      partyName: cost.providerId == null ? cost.partyName : null,
      partyPhone: cost.providerId == null ? cost.partyPhone : null,
      payer: cost.payer,
      payerName: cost.payerName,
      agreementDate: cost.agreementDate,
      note: cost.note,
      shareWithPlan: true,
    );
    if (!mounted) return;
    if (ok) {
      AarastToast.showSuccess(context, 'صارت التكلفة مشتركة مع الخطة.');
      await _load(refreshMoney: true);
    } else {
      AarastToast.showError(
        context,
        provider.errorMessage ?? 'تعذر مشاركة التكلفة.',
      );
    }
  }

  Future<void> _editCost(WeddingCost cost) async {
    final changed = await context.push<bool>(
      AppRouter.moneyCostEdit(widget.weddingPlanId, cost.id),
      extra: cost,
    );
    if (changed == true && mounted) await _load(refreshMoney: true);
  }

  Future<void> _openRecordPayment(WeddingCost cost) async {
    final changed = await context.push<bool>(
      AppRouter.moneyPaymentCreate(widget.weddingPlanId, cost.id),
      extra: cost,
    );
    if (changed == true && mounted) await _load(refreshMoney: true);
  }

  Future<void> _openScheduleCreate(WeddingCost cost) async {
    final changed = await context.push<bool>(
      AppRouter.moneyScheduleCreate(widget.weddingPlanId, cost.id),
      extra: cost,
    );
    if (changed == true && mounted) await _load(refreshMoney: true);
  }

  Future<void> _confirmCancel(WeddingCost cost) async {
    final confirmed = await _confirmAction(
      title: 'إلغاء التكلفة؟',
      message:
          'ستخرج من الإجماليات وتُلغى مواعيد الدفع المفتوحة، بينما يبقى السجل محفوظًا للرجوع إليه.',
      actionLabel: 'إلغاء التكلفة',
      danger: true,
    );
    if (confirmed != true || !mounted) return;
    final provider = context.read<FinanceProvider>();
    final ok = await provider.cancelCost(cost);
    if (!mounted) return;
    if (ok) {
      AarastToast.showSuccess(
        context,
        provider.savedMessage('تم إلغاء التكلفة.'),
      );
      await _load(refreshMoney: true);
    }
  }

  Future<bool?> _confirmAction({
    required String title,
    required String message,
    required String actionLabel,
    required bool danger,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AarastDialog(
        icon: Icon(
          danger ? LucideIcons.alertTriangle : LucideIcons.info,
          color: danger ? AppTheme.danger : AppTheme.brand,
        ),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('رجوع'),
          ),
          AarastButton(
            label: actionLabel,
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

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRouter.moneyCosts(widget.weddingPlanId));
    }
  }
}
