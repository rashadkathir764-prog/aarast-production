import 'package:flutter/material.dart';

import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/routing/app_router.dart';
import 'royal_home_chrome.dart';

enum QuickAddContext { dashboard, money, tasks, guests, providers }

IconData planQuickAddIconForTab(int tabIndex) {
  return switch (tabIndex) {
    1 => LucideIcons.wallet,
    2 => LucideIcons.listPlus,
    3 => LucideIcons.userPlus,
    4 => LucideIcons.store,
    _ => LucideIcons.plus,
  };
}

/// Keeps quick-add visibility identical across the production home shell and
/// the plan-scoped shell. Money shows it only at the tab root; providers never
/// shows it because its primary action lives inside the marketplace flow.
bool shouldShowPlanQuickAdd({
  required int tabIndex,
  bool isRootDestination = true,
  bool canManageMoney = false,
  bool hasConfiguredMoney = true,
}) {
  const moneyTabIndex = 1;
  const providersTabIndex = 4;
  return tabIndex != providersTabIndex &&
      (tabIndex != moneyTabIndex || canManageMoney) &&
      (tabIndex != moneyTabIndex || hasConfiguredMoney) &&
      (tabIndex != moneyTabIndex || isRootDestination);
}

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
  required bool canManageMoney,
  QuickAddContext contextOrder = QuickAddContext.dashboard,
  bool refreshDashboardOnMoney = false,
  VoidCallback? onRequestQuote,
  required Future<void> Function(String route, {bool refreshDashboard})
  openRoute,
}) {
  final cost = RoyalHomeAction(
    icon: LucideIcons.receipt,
    label: 'إضافة تكلفة',
    onTap: () => openRoute(
      AppRouter.moneyCostCreate(planId),
      refreshDashboard: refreshDashboardOnMoney,
    ),
  );
  final category = RoyalHomeAction(
    icon: LucideIcons.folderPlus,
    label: 'إضافة تصنيف',
    onTap: () => openRoute(
      AppRouter.moneyCategoryCreate(planId),
      refreshDashboard: refreshDashboardOnMoney,
    ),
  );
  final task = RoyalHomeAction(
    icon: LucideIcons.listPlus,
    label: 'إضافة مهمة',
    onTap: () => openRoute(AppRouter.createTask(planId)),
  );
  final guest = RoyalHomeAction(
    icon: LucideIcons.userPlus,
    label: 'إضافة ضيف',
    onTap: () => openRoute(AppRouter.guestListAdd(planId)),
  );
  final quote = RoyalHomeAction(
    icon: LucideIcons.filePlus2,
    label: 'طلب عرض سعر',
    onTap: onRequestQuote ?? () => openRoute(AppRouter.planProviders(planId)),
  );

  final financialActions = canManageMoney
      ? <RoyalHomeAction>[cost, category]
      : const <RoyalHomeAction>[];

  return switch (contextOrder) {
    QuickAddContext.money => financialActions,
    QuickAddContext.tasks => [task, if (canManageMoney) cost, guest, quote],
    QuickAddContext.guests => [guest, task, if (canManageMoney) cost, quote],
    QuickAddContext.providers => [quote, if (canManageMoney) cost, task, guest],
    QuickAddContext.dashboard => [if (canManageMoney) cost, task, guest, quote],
  };
}
