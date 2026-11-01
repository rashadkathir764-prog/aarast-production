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
import '../widgets/payment_schedule_sheet.dart';

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
    } else if (paymentRefusal(provider, cost) case final refusal?) {
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
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [body],
      ),
    );
  }
}

/// c06 for a scheduled payment: its agreed amount is paid in full, and
/// «عدّل الموعد» changes the date's amount or day in its sheet first.
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
        planId: widget.weddingPlanId,
        cost: cost,
        currency: currency,
        child: PaymentEntryForm(
          cost: cost,
          currency: currency,
          draftScope:
              'pay-schedule:${widget.weddingPlanId}:${widget.costId}:${widget.scheduleId}',
          fixedAmount: schedule.amount,
          fixedLine: 'المتفق في موعد ${formatArabicDayMonth(schedule.dueDate)}',
          fixedAction: () => showPaymentScheduleSheet(
            context,
            cost: cost,
            currency: currency,
            schedule: schedule,
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
      planId: widget.weddingPlanId,
      cost: cost,
      currency: currency,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [body],
      ),
    );
  }
}

/// Why no payment can be recorded on [cost] here, or null when one can.
String? paymentRefusal(FinanceProvider provider, WeddingCost cost) {
  if (!provider.canManageMoney) return 'تسجيل الدفعات لمدير المال.';
  if (cost.isCancelled) return 'هذا الاتفاق ملغي، ما تنسجل عليه دفعات.';
  if (cost.isPaid || moneyValue(cost.remainingAmount) <= 0) {
    return 'هذا الاتفاق خالص، ما بقي عليك شي.';
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
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: JourneySubHeader(
            title: cost == null ? 'تسجيل دفعة' : 'دفعة ${cost.title}',
            subtitle: cost == null
                ? null
                : [
                    ?cost.partyLabel,
                    if (moneyValue(cost.remainingAmount) > 0) 'باقي عليك $left',
                  ].join(' · '),
            onBack: () => context.popOrGo(AppRouter.money(planId)),
          ),
        ),
        Expanded(child: child),
      ],
    ),
  );
}
