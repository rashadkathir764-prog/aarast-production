import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/forms/aarast_form_success.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/pop_or_go.dart';
import '../../../core/utils/amount_words.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/utils/money_formatters.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../data/finance_local_data_source.dart';
import '../models/wedding_cost.dart';
import '../providers/finance_provider.dart';
import '../widgets/cost_receipts_section.dart';
import '../widgets/money_input_formatter.dart';
import '../widgets/money_widgets.dart' show shownMoney;
import '../widgets/payment_entry_form.dart';
import '../widgets/due_date_sheets.dart';
import '../../wedding_plans/wedding_plans_api.dart'
    show DashboardSummaryProvider;

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
    final currency = provider.summary.currency;

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
        emptyAction: context.say('ارجع', 'ارجعي'),
        onEmptyAction: () =>
            context.popOrGo(AppRouter.money(widget.weddingPlanId)),
      );
    } else if (paymentRefusal(context, provider, cost) case final refusal?) {
      body = JourneyNote(text: refusal, icon: LucideIcons.info);
    } else {
      return paymentEntryFrame(
        context,
        planId: widget.weddingPlanId,
        cost: cost,
        currency: currency,
        child: PaymentEntryForm(
          cost: cost,
          currency: currency,
          draftScope:
              'cost-payment:${widget.weddingPlanId}:${widget.costId}:new',
          onSave: (entry) async {
            final finance = context.read<FinanceProvider>();
            final result = await finance.recordPayment(
              cost: cost,
              amount: entry.amount!,
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
      planId: widget.weddingPlanId,
      cost: cost,
      currency: currency,
      child: ListView(padding: AarastV3Density.pageInsets, children: [body]),
    );
  }
}

/// c06 for a scheduled payment: it starts at what the date asks for; less
/// is part of it and more pays it with the rest on the agreement (D106).
/// «عدّل الموعد» changes the date's amount or day in its sheet.
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

  /// D106 «اتفقتوا على موعد ثاني؟».
  Future<void> _move(PaymentSchedule schedule, WeddingCost cost) async {
    final provider = context.read<FinanceProvider>();
    final summary = context.read<DashboardSummaryProvider?>()?.summary;
    final wedding = summary?.planId == widget.weddingPlanId
        ? summary?.weddingDate
        : null;
    final moved = await showJourneySheet<bool>(
      context: context,
      builder: (_) => MoveDueDateSheet(
        title: cost.title,
        dueDate: schedule.dueDate,
        firstDue: schedule.rescheduledFrom,
        party: cost.partyLabel,
        weddingDate: wedding,
        onSave: (day) => _saved(
          provider.moveSchedule(schedule: schedule, cost: cost, dueDate: day),
          'ما انحفظ الموعد',
        ),
      ),
    );
    if (moved == true && mounted) {
      AarastToast.showSuccess(context, provider.savedMessage('تغيّر الموعد'));
    }
  }

  /// D106: the date's own reminder day.
  Future<void> _remind(PaymentSchedule schedule, WeddingCost cost) async {
    final provider = context.read<FinanceProvider>();
    final saved = await showJourneySheet<bool>(
      context: context,
      builder: (_) => DueReminderSheet(
        title: cost.title,
        dueDate: schedule.dueDate,
        remindAt: schedule.remindAt,
        onSave: (day) => _saved(
          provider.setScheduleReminder(
            schedule: schedule,
            cost: cost,
            remindAt: day,
          ),
          'ما انحفظ التذكير',
        ),
      ),
    );
    if (saved == true && mounted) {
      AarastToast.showSuccess(context, provider.savedMessage('انحفظ التذكير'));
    }
  }

  /// A write's answer; its reason said when it failed.
  Future<bool> _saved(Future<bool> write, String failed) async {
    final ok = await write;
    if (!ok && mounted) {
      AarastToast.showError(
        context,
        context.read<FinanceProvider>().errorMessage ?? failed,
      );
    }
    return ok;
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
    } else if (provider.loadErrorMessage != null && schedule == null) {
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
        emptyAction: context.say('ارجع', 'ارجعي'),
        onEmptyAction: () =>
            context.popOrGo(AppRouter.money(widget.weddingPlanId)),
      );
    } else if (paymentRefusal(context, provider, cost) case final refusal?) {
      body = JourneyNote(text: refusal, icon: LucideIcons.info);
    } else if (!schedule.isPending) {
      body = const JourneyNote(
        text: 'هذا الموعد ما ينتظر دفع.',
        icon: LucideIcons.info,
      );
    } else {
      return paymentEntryFrame(
        context,
        planId: widget.weddingPlanId,
        cost: cost,
        currency: currency,
        child: PaymentEntryForm(
          cost: cost,
          currency: currency,
          draftScope:
              'pay-schedule:${widget.weddingPlanId}:${widget.costId}:${widget.scheduleId}',
          // RA-BE-53: it starts at what the date asks for now; D106: less
          // or more is what was paid.
          dueAmount: schedule.dueAmount,
          dueLine: [
            'المتفق في موعد ${formatArabicDayMonth(schedule.dueDate)}',
            if (schedule.rescheduledFrom case final first?)
              'كانت ${formatArabicDayMonth(first)}',
            if (schedule.remindAt case final remind?)
              'نذكّرك ${formatArabicDayMonth(remind)}',
          ].join(' · '),
          // D106: the date's own actions, beside paying it.
          dateActions: [
            JourneyTextAction(
              key: const ValueKey('payment-move'),
              label: 'اتفقتوا على موعد ثاني؟',
              icon: LucideIcons.calendarClock,
              color: context.accent.primary,
              onPressed: () => _move(schedule, cost),
            ),
            JourneyTextAction(
              key: const ValueKey('payment-remind'),
              label: 'التذكير',
              icon: LucideIcons.bell,
              color: context.accent.primary,
              onPressed: () => _remind(schedule, cost),
            ),
            JourneyTextAction(
              key: const ValueKey('payment-open-cost'),
              label: context.say('افتح الاتفاق', 'افتحي الاتفاق'),
              icon: LucideIcons.arrowUpRight,
              color: AarastV3Color.textMuted,
              onPressed: () => context.push(
                AppRouter.moneyCostDetails(widget.weddingPlanId, cost.id),
              ),
            ),
          ],
          onSave: (entry) async {
            final finance = context.read<FinanceProvider>();
            final result = await finance.paySchedule(
              schedule: schedule,
              cost: cost,
              paidAt: entry.paidAt,
              method: entry.method,
              note: entry.note,
              amount: entry.amount,
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
      planId: widget.weddingPlanId,
      cost: cost,
      currency: currency,
      child: ListView(padding: AarastV3Density.pageInsets, children: [body]),
    );
  }
}

/// Why no payment can be recorded on [cost] here, or null when one can.
String? paymentRefusal(
  BuildContext context,
  FinanceProvider provider,
  WeddingCost cost,
) {
  if (!provider.canManageMoney) return 'تسجيل الدفعات لمدير المال.';
  if (cost.isCancelled) return 'هذا الاتفاق ملغي، ما تنسجل عليه دفعات.';
  if (cost.isPaid || moneyValue(cost.remainingAmount) <= 0) {
    // D59: «عليك» is the owner's; a helper reads whose it is.
    final left = context.ownerDid(
      'ما بقي عليك شي',
      'ما بقي عليك شي',
      groom: 'ما بقي عليه شي',
      bride: 'ما بقي عليها شي',
    );
    return 'هذا الاتفاق خالص، $left.';
  }
  return null;
}

/// The screen around c06: «دفعة القاعة», who it is with and what is left.
Widget paymentEntryFrame(
  BuildContext context, {
  required String planId,
  required WeddingCost? cost,
  required String currency,
  required Widget child,
}) {
  final left = cost == null
      ? null
      : shownMoney(
          context,
          compactMoneyParts(
            moneyValue(cost.remainingAmount),
            currencyCode: currency,
          ).plainText,
        );
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
            title: cost == null ? 'تسجيل دفعة' : 'دفعة ${cost.title}',
            subtitle: cost == null
                ? null
                : [
                    ?cost.partyLabel,
                    // J1-17: whose the rest is, as «الملخص» says it.
                    if (moneyValue(cost.remainingAmount) > 0)
                      '${context.ownerDid('باقي عليك', 'باقي عليك', groom: 'باقي عليه', bride: 'باقي عليها')} $left',
                  ].join(' · '),
            onBack: () => context.popOrGo(AppRouter.money(planId)),
          ),
        ),
        Expanded(child: child),
      ],
    ),
  );
}
