import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/money_formatters.dart';
import '../models/wedding_cost.dart';
import '../providers/finance_provider.dart';
import 'payment_schedule_sheet.dart';

/// What the plan's «+» asks of an agreement (D33): a payment that was paid
/// (c07 «تسجيل دفعة») or a payment date to remember (the c07 date sheet).
enum MoneyCostActionIntent { payment, schedule }

/// The answer of [showMoneyCostActionPicker]: the agreement picked, or a new
/// agreement first because none can take the payment yet.
class MoneyCostActionSelection {
  const MoneyCostActionSelection.cost(WeddingCost this.cost)
    : createCost = false;

  const MoneyCostActionSelection.createCost() : cost = null, createCost = true;

  final WeddingCost? cost;
  final bool createCost;
}

/// Agreements a payment or a payment date can go on: not cancelled and with
/// money still unpaid.
List<WeddingCost> moneyCostsOpenForAction(Iterable<WeddingCost> costs) => [
  for (final cost in costs)
    if (!cost.isCancelled && moneyValue(cost.remainingAmount) > 0) cost,
];

/// Which agreement the payment or the date is for, in a journey sheet. With
/// no open agreement it says why and offers «إضافة اتفاق».
Future<MoneyCostActionSelection?> showMoneyCostActionPicker(
  BuildContext context, {
  required MoneyCostActionIntent intent,
  required List<WeddingCost> costs,
  required String currency,
  bool hideAmounts = false,
}) {
  final open = moneyCostsOpenForAction(costs);
  return showJourneySheet<MoneyCostActionSelection>(
    context: context,
    useRootNavigator: true,
    builder: (sheetContext) => JourneySheetBody(
      title: intent == MoneyCostActionIntent.payment
          ? 'الدفعة على أي اتفاق؟'
          : 'موعد الدفع لأي اتفاق؟',
      subtitle: open.isEmpty ? null : 'نعرض الاتفاقات اللي باقي عليها مبلغ.',
      children: [
        if (open.isEmpty)
          JourneyListState(
            key: const ValueKey('money-cost-action-empty'),
            phase: JourneyListPhase.empty,
            section: JourneySection.money,
            emptyIcon: LucideIcons.receipt,
            emptyTitle: context.say('سجّل اتفاق أول', 'سجّلي اتفاق أول'),
            emptyMessage: intent == MoneyCostActionIntent.payment
                ? 'الدفعة تنسجل على اتفاق، عشان تبقى أرقامك صادقة.'
                : 'موعد الدفع ينربط باتفاق ومبلغ واضحين.',
            emptyAction: 'إضافة اتفاق',
            onEmptyAction: () => Navigator.of(
              sheetContext,
            ).pop(const MoneyCostActionSelection.createCost()),
          )
        else
          JourneyList(
            children: [
              for (final cost in open)
                JourneyListRow(
                  key: ValueKey('money-cost-action-${cost.id}'),
                  icon: LucideIcons.receipt,
                  color: context.accent.primary,
                  soft: context.accent.primarySoft,
                  title: cost.title,
                  subtitle: hideAmounts
                      ? 'باقي عليه مبلغ'
                      : 'باقي ${compactMoneyParts(moneyValue(cost.remainingAmount), currencyCode: currency).plainText}',
                  trailing: const Icon(
                    LucideIcons.chevronLeft,
                    size: 20,
                    color: AarastV3Color.textMuted,
                  ),
                  onTap: () => Navigator.of(
                    sheetContext,
                  ).pop(MoneyCostActionSelection.cost(cost)),
                ),
            ],
          ),
      ],
    ),
  );
}

/// The plan's «+» → «تسجيل دفعة» or «إضافة موعد دفع»: loads the plan's
/// money when it is not loaded yet, asks for the agreement, then opens the
/// c07 payment form or the payment date sheet on it, or the new agreement
/// form when there is none. Returns true when the plan's money changed.
Future<bool> openMoneyCostAction(
  BuildContext context, {
  required String planId,
  required MoneyCostActionIntent intent,
}) async {
  final finance = context.read<FinanceProvider>();
  if (finance.loadedPlanId != planId || !finance.hasLoadedMoney) {
    await finance.loadMoney(planId);
  }
  if (!context.mounted) return false;
  final selection = await showMoneyCostActionPicker(
    context,
    intent: intent,
    costs: finance.costs,
    currency: finance.summary.currency,
    hideAmounts: finance.amountsHidden,
  );
  if (!context.mounted || selection == null) return false;

  final cost = selection.cost;
  final bool changed;
  if (cost == null) {
    changed =
        await context.push<bool>(AppRouter.moneyCostCreate(planId)) == true;
  } else if (intent == MoneyCostActionIntent.payment) {
    // A date waiting on the agreement takes the payment, so its reminder
    // stops; the free form is for an agreement with no date.
    await finance.loadCostDetails(cost.id);
    if (!context.mounted) return false;
    final next = finance.nextPendingSchedule(cost.id);
    changed =
        await context.push<bool>(
          next == null
              ? AppRouter.moneyPaymentCreate(planId, cost.id)
              : AppRouter.moneySchedulePay(planId, cost.id, next.id),
          extra: next,
        ) ==
        true;
  } else {
    changed = await showPaymentScheduleSheet(
      context,
      cost: cost,
      currency: finance.summary.currency,
    );
  }
  if (changed && context.mounted) await finance.loadMoney(planId);
  return changed;
}
