import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/phone/phone_number_utils.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/app_clock.dart';
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
import '../widgets/payment_schedule_sheet.dart';

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
    } else if (provider.loadErrorMessage != null && cost == null) {
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
        emptyAction: context.say('ارجع للبنود', 'ارجعي للبنود'),
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
            padding: const EdgeInsets.fromLTRB(
              AarastV3Space.x4,
              AarastV3Space.x2,
              AarastV3Space.x2,
              0,
            ),
            child: JourneySubHeader(
              title: cost?.title ?? 'تفاصيل الاتفاق',
              subtitle: cost?.partyLabel,
              onBack: _goBack,
              trailing: cost != null && canManage && !cost.isCancelled
                  ? _CostMoreMenu(
                      disabled: provider.isSubmitting,
                      onEdit: () => _editCost(cost),
                      onRemove: () => _remove(cost),
                    )
                  : null,
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: context.accent.primary,
              onRefresh: () => _load(refreshMoney: true),
              child: ListView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AarastV3Density.pageInsets,
                children: [body],
              ),
            ),
          ),
          if (payAction != null)
            Padding(
              padding: AarastV3Density.actionInsets,
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
      return (
        context.say('سجّل دفعة', 'سجّلي دفعة'),
        () => _openRecordPayment(cost),
      );
    }
    final paidCount = provider
        .paymentsForCost(cost.id)
        .where((payment) => !payment.isReversal && !payment.isReversed)
        .length;
    final next = pending.first;
    return (
      '${context.say('سجّل', 'سجّلي')} الدفعة ${arabicOrdinal(paidCount)}',
      () => _paySchedule(cost, next),
    );
  }

  /// How much the pending dates ask beyond what is left; null if not over.
  static double? _scheduledOver(
    List<PaymentSchedule> pending,
    WeddingCost cost,
  ) {
    final scheduled = pending.fold<double>(
      0,
      (sum, schedule) => sum + moneyValue(schedule.amount),
    );
    final over = scheduled - moneyValue(cost.remainingAmount);
    return over > 0.009 ? over : null;
  }

  Widget _details(
    BuildContext context,
    FinanceProvider provider,
    WeddingCost cost,
    String currency,
    bool canManage,
  ) {
    final now = appNow();
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
              : 'الدفعة ${arabicOrdinal(number++)}',
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
              : 'الدفعة ${arabicOrdinal(number++)}',
          line: _dueLine(pending[index], now),
          amount: pending[index].amount,
          state: index == 0 ? _EntryState.current : _EntryState.later,
          // A date still to pay changes or goes in its sheet.
          onTap: canManage && !cost.isCancelled
              ? () => _openSchedule(cost, currency, pending[index])
              : null,
        ),
    ];
    final canSchedule =
        canManage && !cost.isCancelled && moneyValue(cost.remainingAmount) > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (provider.loadErrorMessage != null) ...[
          JourneyListNotice(offline: false, onRetry: _load),
          const SizedBox(height: AarastV3Space.x3),
        ],
        _CostAgreementCard(cost: cost, currency: currency),
        // V1 checklist 4.10: a private cost can join the shared plan.
        if (cost.isPrivate) ...[
          const SizedBox(height: AarastV3Space.x3),
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
                color: context.accent.primary,
                onPressed: () => _shareWithPlan(cost),
              ),
            ),
        ],
        if (!canManage) ...[
          const SizedBox(height: AarastV3Space.x3),
          const JourneyNote(
            text:
                'هذه التفاصيل للعرض فقط. إجراءات التعديل والدفع متاحة لمدير المال.',
            icon: LucideIcons.eye,
          ),
        ],
        const SizedBox(height: AarastV3Space.x2),
        KeyedSubtree(
          key: _paymentsKey,
          child: JourneySectionTitle(
            'جدول الدفعات',
            action: canSchedule ? context.say('أضف موعد', 'أضيفي موعد') : null,
            onAction: canSchedule
                ? () => _openSchedule(cost, currency, null)
                : null,
          ),
        ),
        if (entries.isEmpty)
          // An empty state says what to do, with the header's own action.
          JourneyListState(
            key: const ValueKey('cost-schedules-empty'),
            phase: JourneyListPhase.empty,
            section: JourneySection.money,
            emptyIcon: LucideIcons.calendarPlus,
            emptyTitle: 'ما في دفعات ولا مواعيد بعد',
            emptyAction: canSchedule
                ? context.say('أضف موعد', 'أضيفي موعد')
                : null,
            onEmptyAction: canSchedule
                ? () => _openSchedule(cost, currency, null)
                : null,
          )
        else
          _PaymentTimeline(entries: entries, currency: currency),
        // G32: the dates are reminders, each capped by what is left; say so
        // when together they ask for more than is left to pay.
        if (_scheduledOver(pending, cost) case final over? when over > 0) ...[
          const SizedBox(height: AarastV3Space.x2),
          JourneyNote(
            key: const ValueKey('cost-schedules-over-remaining'),
            text:
                'مواعيد الدفع مجموعها أكثر من الباقي بـ '
                '${_plainAmount(context, over, currency)}. '
                '${context.say('عدّل', 'عدّلي')} المواعيد لين تساوي الباقي.',
            icon: LucideIcons.alertTriangle,
            color: AarastV3Color.danger,
            soft: AarastV3Color.dangerSoft,
          ),
        ],
        // V1 checklist 4.4: receipts live on the server (an account's plan),
        // never in a guest's local plan.
        if (!FinanceLocalDataSource.isLocalGuestPlanId(
          widget.weddingPlanId,
        )) ...[
          const SizedBox(height: AarastV3Space.x4),
          CostReceiptsSection(
            key: ValueKey('cost-receipts-${cost.id}'),
            costId: cost.id,
            canManage: canManage,
          ),
        ],
        const SizedBox(height: AarastV3Space.x2),
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
    final confirmed = await showJourneySheet<bool>(
      context: context,
      builder: (sheetContext) => JourneySheetBody(
        title: context.say('تشاركها مع الخطة؟', 'تشاركينها مع الخطة؟'),
        subtitle: 'بيشوفها شريكك وتدخل في أرقام الخطة، وما ترجع خاصة بعدها.',
        children: [
          JourneyButton(
            key: const ValueKey('cost-share-confirm'),
            label: context.say('شاركها', 'شاركيها'),
            expand: true,
            large: true,
            onPressed: () => Navigator.of(sheetContext).pop(true),
          ),
          const SizedBox(height: AarastV3Space.x2),
          JourneyButton.quiet(
            label: 'رجوع',
            expand: true,
            onPressed: () => Navigator.of(sheetContext).pop(false),
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

  Future<void> _openSchedule(
    WeddingCost cost,
    String currency,
    PaymentSchedule? schedule,
  ) async {
    final changed = await showPaymentScheduleSheet(
      context,
      cost: cost,
      currency: currency,
      schedule: schedule,
    );
    if (changed && mounted) await _load(refreshMoney: true);
  }

  /// w23: an agreement with payments stays (the record must stay true), so
  /// the way out is reversing a wrong payment first. One without payments
  /// is cancelled (kept, its dates cancelled) or deleted.
  Future<void> _remove(WeddingCost cost) async {
    final provider = context.read<FinanceProvider>();
    final active =
        provider
            .paymentsForCost(cost.id)
            .where((payment) => !payment.isReversal && !payment.isReversed)
            .toList()
          ..sort((a, b) => b.paidAt.compareTo(a.paidAt));
    final choice = await showJourneySheet<_RemoveCostChoice>(
      context: context,
      builder: (_) => _RemoveCostSheet(
        title: cost.title,
        paid: active.isEmpty
            ? null
            : provider.shownAmount(
                compactMoneyParts(
                  moneyValue(cost.paidAmount),
                  currencyCode: provider.summary.currency,
                ).plainText,
              ),
      ),
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case _RemoveCostChoice.reverseFirst:
        await context.push(
          AppRouter.moneyPaymentDetails(
            widget.weddingPlanId,
            active.first.id,
            costId: cost.id,
          ),
        );
        if (mounted) await _load(refreshMoney: true);
      case _RemoveCostChoice.cancel:
        if (await provider.cancelCost(cost) && mounted) {
          AarastToast.showSuccess(
            context,
            provider.savedMessage('انلغى الاتفاق'),
          );
          await _load(refreshMoney: true);
        }
      case _RemoveCostChoice.delete:
        if (await provider.deleteCost(cost) && mounted) {
          AarastToast.showSuccess(
            context,
            provider.savedMessage('انحذف الاتفاق'),
          );
          _goBack();
          return;
        }
    }
    if (mounted && provider.errorMessage != null) {
      AarastToast.showError(context, provider.errorMessage!);
    }
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRouter.money(widget.weddingPlanId));
    }
  }
}
