import 'package:flutter/material.dart';

import '../../../core/routing/app_router.dart';
import 'royal_home_chrome.dart';

enum QuickAddContext { dashboard, money, tasks, guests, providers }

/// Canonical quick-add actions for any active wedding plan.
///
/// Used by:
/// - [MainShell] floating "+" button (the production bottom-nav shell).
/// - [LocalGuestDashboardScreen] floating "+" button (guest draft plan).
///
/// Keep this list aligned with the navigation blueprint so every duplicate
/// shortcut opens the same canonical flow with the same Arabic label.
List<RoyalHomeAction> buildCanonicalQuickAddActions(
  BuildContext context, {
  required String planId,
  QuickAddContext contextOrder = QuickAddContext.dashboard,
  bool refreshDashboardOnExpense = false,
  VoidCallback? onRequestQuote,
  required Future<void> Function(String route, {bool refreshDashboard})
  openRoute,
}) {
  final expense = RoyalHomeAction(
    icon: Icons.account_balance_wallet_outlined,
    label: 'إضافة مصروف',
    onTap: () => openRoute(
      AppRouter.createExpense(planId),
      refreshDashboard: refreshDashboardOnExpense,
    ),
  );
  final task = RoyalHomeAction(
    icon: Icons.check_circle_outline_rounded,
    label: 'إضافة مهمة',
    onTap: () => openRoute(AppRouter.createTask(planId)),
  );
  final guest = RoyalHomeAction(
    icon: Icons.group_add_outlined,
    label: 'إضافة ضيف',
    onTap: () => openRoute(AppRouter.guestListAdd(planId)),
  );
  final debt = RoyalHomeAction(
    icon: Icons.attach_money_rounded,
    label: 'إضافة دين/قسط',
    onTap: () => openRoute(AppRouter.createDebt(planId)),
  );
  final quote = RoyalHomeAction(
    icon: Icons.request_quote_outlined,
    label: 'طلب عرض سعر',
    onTap: onRequestQuote ?? () => openRoute(AppRouter.planProviders(planId)),
  );
  final category = RoyalHomeAction(
    icon: Icons.create_new_folder_outlined,
    label: 'إضافة تصنيف',
    onTap: () => openRoute(AppRouter.createBudgetCategory(planId)),
  );

  return switch (contextOrder) {
    QuickAddContext.money => [expense, debt, category],
    QuickAddContext.tasks => [task, expense, guest, debt, quote],
    QuickAddContext.guests => [guest, task, expense, debt, quote],
    QuickAddContext.providers => [quote, expense, task, guest, debt],
    QuickAddContext.dashboard => [expense, task, guest, debt, quote],
  };
}
