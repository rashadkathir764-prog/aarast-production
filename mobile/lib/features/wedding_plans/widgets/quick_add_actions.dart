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
  final category = RoyalHomeAction(
    icon: Icons.create_new_folder_outlined,
    label: 'إضافة بند ميزانية',
    onTap: () => openRoute(
      AppRouter.createBudgetCategory(planId),
      refreshDashboard: refreshDashboardOnExpense,
    ),
  );
  final commitment = RoyalHomeAction(
    icon: Icons.handshake_outlined,
    label: 'حجز مورد / تكلفة خدمة',
    onTap: () => openRoute(
      AppRouter.createFinancialCommitment(
        planId,
        sourceType: 'PROVIDER_SERVICE',
      ),
      refreshDashboard: refreshDashboardOnExpense,
    ),
  );
  final payable = RoyalHomeAction(
    icon: Icons.account_balance_wallet_outlined,
    label: 'إضافة مستحق',
    onTap: () => openRoute(
      AppRouter.createFinancialCommitment(planId),
      refreshDashboard: refreshDashboardOnExpense,
    ),
  );
  final payment = RoyalHomeAction(
    icon: Icons.payments_outlined,
    label: 'تسجيل دفعة',
    onTap: () => openRoute(
      AppRouter.recordPayment(planId),
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
  final quote = RoyalHomeAction(
    icon: Icons.request_quote_outlined,
    label: 'طلب عرض سعر',
    onTap: onRequestQuote ?? () => openRoute(AppRouter.planProviders(planId)),
  );

  return switch (contextOrder) {
    QuickAddContext.money => [category, payable, payment],
    QuickAddContext.tasks => [task, payment, guest, commitment, quote],
    QuickAddContext.guests => [guest, task, payment, commitment, quote],
    QuickAddContext.providers => [quote, commitment, payment, task, guest],
    QuickAddContext.dashboard => [commitment, payment, task, guest, quote],
  };
}
