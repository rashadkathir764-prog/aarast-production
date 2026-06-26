import 'package:flutter/material.dart';

import '../../../core/routing/app_router.dart';
import 'royal_home_chrome.dart';

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
  bool refreshDashboardOnExpense = false,
  required Future<void> Function(String route, {bool refreshDashboard}) openRoute,
}) {
  return [
    RoyalHomeAction(
      icon: Icons.account_balance_wallet_outlined,
      label: 'إضافة مصروف',
      onTap: () => openRoute(
        AppRouter.createExpense(planId),
        refreshDashboard: refreshDashboardOnExpense,
      ),
    ),
    RoyalHomeAction(
      icon: Icons.check_circle_outline_rounded,
      label: 'إضافة مهمة',
      onTap: () => openRoute(AppRouter.createTask(planId)),
    ),
    RoyalHomeAction(
      icon: Icons.group_add_outlined,
      label: 'إضافة ضيف',
      onTap: () => openRoute(AppRouter.guestList(planId)),
    ),
    RoyalHomeAction(
      icon: Icons.attach_money_rounded,
      label: 'إضافة دين',
      onTap: () => openRoute(AppRouter.createDebt(planId)),
    ),
    RoyalHomeAction(
      icon: Icons.request_quote_outlined,
      label: 'طلب عرض سعر',
      onTap: () => openRoute(AppRouter.providerMarketplace),
    ),
  ];
}
